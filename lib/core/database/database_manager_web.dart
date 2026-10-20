import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/wasm.dart';

import 'database_manager.dart';

WasmSqlite3? _sqlite3;
IndexedDbFileSystem? _fs;
InMemoryFileSystem? _memoryFs;
Future<void>? _initFuture;

Future<void> _initWasm() {
  return _initFuture ??= () async {
    try {
      debugPrint('[DatabaseManagerWeb] Carregando sqlite3.wasm...');
      _sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      _memoryFs = InMemoryFileSystem(name: 'in-memory-vfs');
      _sqlite3!.registerVirtualFileSystem(_memoryFs!);

      try {
        _fs = await IndexedDbFileSystem.open(dbName: 'kairos_web_vfs');
        _sqlite3!.registerVirtualFileSystem(_fs!, makeDefault: true);
        debugPrint('[DatabaseManagerWeb] IndexedDbFileSystem registrado com sucesso.');
      } catch (fsError) {
        debugPrint('[DatabaseManagerWeb] IndexedDbFileSystem falhou, usando InMemoryFileSystem: $fsError');
        _sqlite3!.registerVirtualFileSystem(_memoryFs!, makeDefault: true);
      }
    } catch (e, stack) {
      debugPrint('[DatabaseManagerWeb] Erro ao carregar Wasm SQLite: $e\n$stack');
    }
  }();
}

CommonDatabase _openFromMemoryFs(String dbName, Uint8List bytes) {
  final memFs = _memoryFs ?? InMemoryFileSystem(name: 'fallback-mem');
  final memPath = '/$dbName';
  if (memFs.xAccess(memPath, 0) != 0) {
    try {
      memFs.xDelete(memPath, 0);
    } catch (_) {}
  }
  final opened = memFs.xOpen(
    Sqlite3Filename(memPath),
    SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
  );
  opened.file.xTruncate(bytes.length);
  opened.file.xWrite(bytes, 0);
  opened.file.xClose();
  return _sqlite3!.open(memPath, vfs: memFs.name);
}

Future<CommonDatabase> openPlatformDatabase(String dbName) async {
  await _initWasm();
  final sqlite = _sqlite3;
  if (sqlite == null) {
    throw StateError('SQLite Wasm runtime não disponível.');
  }

  final byteData = await rootBundle.load('assets/$dbName');
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  final expectedMarker = sqliteVersionMarker(byteData);

  final fs = _fs;
  final path = '/$dbName';
  final verPath = '/$dbName.ver';

  if (fs != null) {
    final exists = fs.xAccess(path, 0) != 0;
    bool isCorruptOrEmpty = false;
    if (exists) {
      try {
        final probe = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY);
        try {
          final fileSize = probe.file.xFileSize();
          if (fileSize < 100) {
            isCorruptOrEmpty = true;
          } else {
            final header = Uint8List(16);
            probe.file.xRead(header, 0);
            if (!isValidSqliteHeader(header, fileSize)) {
              isCorruptOrEmpty = true;
            }
          }
        } finally {
          probe.file.xClose();
        }
      } catch (_) {
        isCorruptOrEmpty = true;
      }
    }

    String? readMarker() {
      if (fs.xAccess(verPath, 0) == 0) return null;
      try {
        final probe = fs.xOpen(Sqlite3Filename(verPath), SqlFlag.SQLITE_OPEN_READONLY);
        try {
          final sz = probe.file.xFileSize();
          if (sz <= 0) return null;
          final data = Uint8List(sz);
          probe.file.xRead(data, 0);
          return String.fromCharCodes(data).trim();
        } finally {
          probe.file.xClose();
        }
      } catch (_) {
        return null;
      }
    }

    Future<void> writeMarker() async {
      if (fs.xAccess(verPath, 0) != 0) {
        try {
          fs.xDelete(verPath, 0);
        } catch (_) {}
      }
      final opened = fs.xOpen(
        Sqlite3Filename(verPath),
        SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
      );
      try {
        final data = Uint8List.fromList(expectedMarker.codeUnits);
        opened.file.xTruncate(data.length);
        opened.file.xWrite(data, 0);
      } finally {
        opened.file.xClose();
      }
      await fs.flush();
    }

    Future<void> copyAssetToVfs() async {
      if (fs.xAccess(path, 0) != 0) {
        try {
          fs.xDelete(path, 0);
        } catch (_) {}
      }
      final opened = fs.xOpen(
        Sqlite3Filename(path),
        SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
      );
      try {
        opened.file.xTruncate(bytes.length);
        const chunkSize = 64 * 1024;
        for (int offset = 0; offset < bytes.length; offset += chunkSize) {
          final end = (offset + chunkSize > bytes.length) ? bytes.length : offset + chunkSize;
          final chunk = bytes.sublist(offset, end);
          opened.file.xWrite(chunk, offset);
        }
      } finally {
        opened.file.xClose();
      }
      await writeMarker();
    }

    bool shouldCopy = false;
    bool preserveUser = false;

    if (!exists || isCorruptOrEmpty) {
      shouldCopy = true;
    } else {
      final savedMarker = readMarker();
      if (savedMarker == null) {
        // Upgrade de versão antiga sem .ver: escreve marcador sem recopiar
        await writeMarker();
      } else if (savedMarker != expectedMarker) {
        debugPrint('[DatabaseManagerWeb] Asset alterado para $dbName ($savedMarker vs $expectedMarker). Atualizando...');
        shouldCopy = true;
        preserveUser = true;
      }
    }

    if (shouldCopy) {
      Map<String, List<Map<String, Object?>>>? dump;
      if (preserveUser) {
        try {
          final oldDb = sqlite.open(path);
          try {
            dump = dumpUserTables(oldDb);
          } finally {
            oldDb.dispose();
          }
        } catch (e) {
          debugPrint('[DatabaseManagerWeb] Erro ao extrair dados de usuário: $e');
          final db = sqlite.open(path);
          try {
            db.execute('PRAGMA journal_mode = DELETE;');
          } catch (_) {}
          return db;
        }
      }

      try {
        await copyAssetToVfs();
      } catch (e) {
        debugPrint('[DatabaseManagerWeb] Erro ao gravar asset: $e');
      }

      try {
        final db = sqlite.open(path);
        try {
          db.execute('PRAGMA journal_mode = DELETE;');
        } catch (_) {}
        if (dump != null && dump.isNotEmpty) {
          try {
            restoreUserTables(db, dump);
          } catch (e) {
            debugPrint('[DatabaseManagerWeb] Erro ao restaurar dados de usuário: $e');
          }
        }
        return db;
      } catch (_) {
        return _openFromMemoryFs(dbName, bytes);
      }
    }

    try {
      final db = sqlite.open(path);
      try {
        db.execute('PRAGMA journal_mode = DELETE;');
      } catch (_) {}
      return db;
    } catch (_) {
      try {
        await copyAssetToVfs();
        final db = sqlite.open(path);
        try {
          db.execute('PRAGMA journal_mode = DELETE;');
        } catch (_) {}
        return db;
      } catch (_) {
        return _openFromMemoryFs(dbName, bytes);
      }
    }
  } else {
    return _openFromMemoryFs(dbName, bytes);
  }
}
