import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/wasm.dart';

WasmSqlite3? _sqlite3;
IndexedDbFileSystem? _fs;
InMemoryFileSystem? _memoryFs;
bool _initialized = false;

Future<void> _initWasm() async {
  if (_initialized) return;
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
    _initialized = true;
  } catch (e, stack) {
    debugPrint('[DatabaseManagerWeb] Erro ao carregar Wasm SQLite: $e\n$stack');
    _initialized = true;
  }
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
  if (!_initialized) {
    await _initWasm();
  }
  final sqlite = _sqlite3;
  if (sqlite == null) {
    throw StateError('SQLite Wasm runtime não disponível.');
  }

  final byteData = await rootBundle.load('assets/$dbName');
  final expectedLength = byteData.lengthInBytes;
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );

  final fs = _fs;
  final path = '/$dbName';

  if (fs != null) {
    final exists = fs.xAccess(path, 0) != 0;
    bool isCorruptOrEmpty = false;
    if (exists) {
      try {
        final probe = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY);
        final fileSize = probe.file.xFileSize();
        if (fileSize != expectedLength) {
          isCorruptOrEmpty = true;
        } else {
          final header = Uint8List(16);
          probe.file.xRead(header, 0);
          final magic = String.fromCharCodes(header.take(15));
          if (magic != 'SQLite format 3') {
            isCorruptOrEmpty = true;
          }
        }
        probe.file.xClose();
      } catch (_) {
        isCorruptOrEmpty = true;
      }
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
      opened.file.xTruncate(bytes.length);
      const chunkSize = 64 * 1024;
      for (int offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize > bytes.length) ? bytes.length : offset + chunkSize;
        final chunk = bytes.sublist(offset, end);
        opened.file.xWrite(chunk, offset);
      }
      opened.file.xClose();
      await fs.flush();
    }

    if (!exists || isCorruptOrEmpty) {
      try {
        await copyAssetToVfs();
      } catch (e) {
        debugPrint('[DatabaseManagerWeb] Erro ao gravar asset: $e');
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
