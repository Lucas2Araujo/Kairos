import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqlite3/wasm.dart';

/// Gerenciador centralizado de conexões SQLite para ambiente Flutter Web via Wasm
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  WasmSqlite3? _sqlite3;
  IndexedDbFileSystem? _fs;
  InMemoryFileSystem? _memoryFs;

  final Map<String, CommonDatabase> _openDatabases = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Inicializa o subsistema SQLite Wasm e o IndexedDbFileSystem
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('[DatabaseManager] Carregando sqlite3.wasm...');
      _sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      
      _memoryFs = InMemoryFileSystem(name: 'in-memory-vfs');
      _sqlite3!.registerVirtualFileSystem(_memoryFs!);

      try {
        _fs = await IndexedDbFileSystem.open(dbName: 'kairos_web_vfs');
        _sqlite3!.registerVirtualFileSystem(_fs!, makeDefault: true);
        debugPrint('[DatabaseManager] IndexedDbFileSystem registrado com sucesso.');
      } catch (fsError) {
        debugPrint('[DatabaseManager] IndexedDbFileSystem falhou, usando InMemoryFileSystem como default: $fsError');
        _sqlite3!.registerVirtualFileSystem(_memoryFs!, makeDefault: true);
      }
      
      _initialized = true;
    } catch (e, stack) {
      debugPrint('[DatabaseManager] Erro ao carregar Wasm SQLite: $e\n$stack');
      _initialized = true;
    }
  }

  /// Carrega os bytes do asset e grava no InMemoryFileSystem para acesso rápido e seguro
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

    final db = _sqlite3!.open(memPath, vfs: memFs.name);
    _openDatabases[dbName] = db;
    return db;
  }

  /// Garante que o banco exista e retorna uma conexão aberta
  Future<CommonDatabase> getDatabase(String dbName) async {
    if (!_initialized) {
      await initialize();
    }

    if (_openDatabases.containsKey(dbName)) {
      return _openDatabases[dbName]!;
    }

    final sqlite = _sqlite3;
    if (sqlite == null) {
      throw StateError('SQLite Wasm runtime não disponível.');
    }

    // Carrega os bytes do asset primeiro para validar integridade e tamanho esperado
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
            debugPrint('[DatabaseManager] Arquivo $dbName no VFS com tamanho divergente ($fileSize vs $expectedLength bytes).');
            isCorruptOrEmpty = true;
          } else {
            // Checa a assinatura mágica 'SQLite format 3\000' nos primeiros 16 bytes
            final header = Uint8List(16);
            probe.file.xRead(header, 0);
            final magic = String.fromCharCodes(header.take(15));
            if (magic != 'SQLite format 3') {
              debugPrint('[DatabaseManager] Arquivo $dbName no VFS corrompido (header inválido: $magic).');
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
          } catch (delErr) {
            debugPrint('[DatabaseManager] Aviso ao remover arquivo antigo/corrompido: $delErr');
          }
        }

        final opened = fs.xOpen(
          Sqlite3Filename(path),
          SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
        );
        opened.file.xTruncate(bytes.length);
        
        // Grava em blocos de 64KB para evitar sobrecarga de sincronização no IndexedDB Wasm
        const chunkSize = 64 * 1024;
        for (int offset = 0; offset < bytes.length; offset += chunkSize) {
          final end = (offset + chunkSize > bytes.length) ? bytes.length : offset + chunkSize;
          final chunk = bytes.sublist(offset, end);
          opened.file.xWrite(chunk, offset);
        }
        opened.file.xClose();
        await fs.flush();
        debugPrint('[DatabaseManager] Asset $dbName persistido com sucesso no VFS (${bytes.length} bytes).');
      }

      if (!exists || isCorruptOrEmpty) {
        debugPrint('[DatabaseManager] Copiando asset $dbName para VFS ($path)...');
        try {
          await copyAssetToVfs();
        } catch (e, st) {
          debugPrint('[DatabaseManager] Falha ao gravar asset $dbName no VFS: $e\n$st');
        }
      }

      // Tenta abrir a partir do VFS
      try {
        final db = sqlite.open(path);
        try {
          db.execute('PRAGMA journal_mode = DELETE;');
        } catch (_) {}
        _openDatabases[dbName] = db;
        return db;
      } catch (openError) {
        debugPrint('[DatabaseManager] Erro ao abrir $path do VFS: $openError. Tentando recriar uma vez...');
        try {
          await copyAssetToVfs();
          final db = sqlite.open(path);
          try {
            db.execute('PRAGMA journal_mode = DELETE;');
          } catch (_) {}
          _openDatabases[dbName] = db;
          return db;
        } catch (retryError) {
          debugPrint('[DatabaseManager] Falha persistente no VFS para $dbName ($retryError). Usando fallback InMemoryFileSystem...');
          try {
            fs.xDelete(path, 0);
          } catch (_) {}
          
          return _openFromMemoryFs(dbName, bytes);
        }
      }
    } else {
      // Fallback em memória direto caso IndexedDbFileSystem não esteja disponível
      return _openFromMemoryFs(dbName, bytes);
    }
  }

  /// Fecha todas as conexões ativas
  void dispose() {
    for (final db in _openDatabases.values) {
      db.dispose();
    }
    _openDatabases.clear();
    _initialized = false;
  }
}
