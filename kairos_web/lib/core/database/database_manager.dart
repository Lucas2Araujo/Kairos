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

  final Map<String, CommonDatabase> _openDatabases = {};
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Inicializa o subsistema SQLite Wasm e o IndexedDbFileSystem
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('[DatabaseManager] Carregando sqlite3.wasm...');
      _sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
      
      try {
        _fs = await IndexedDbFileSystem.open(dbName: 'kairos_web_vfs');
        _sqlite3!.registerVirtualFileSystem(_fs!, makeDefault: true);
        debugPrint('[DatabaseManager] IndexedDbFileSystem registrado com sucesso.');
      } catch (fsError) {
        debugPrint('[DatabaseManager] IndexedDbFileSystem falhou, usando VFS padrão/memória: $fsError');
      }
      
      _initialized = true;
    } catch (e, stack) {
      debugPrint('[DatabaseManager] Erro ao carregar Wasm SQLite: $e\n$stack');
      _initialized = true;
    }
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

    final fs = _fs;
    final path = '/$dbName';

    if (fs != null) {
      final exists = fs.xAccess(path, 0) != 0;
      
      // Valida se o arquivo existe e possui o cabeçalho válido do SQLite
      bool isCorruptOrEmpty = false;
      if (exists) {
        try {
          final probe = fs.xOpen(Sqlite3Filename(path), SqlFlag.SQLITE_OPEN_READONLY);
          final fileSize = probe.file.xFileSize();
          if (fileSize < 512) {
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

      if (!exists || isCorruptOrEmpty) {
        debugPrint('[DatabaseManager] Copiando asset $dbName para VFS ($path)...');
        try {
          final byteData = await rootBundle.load('assets/$dbName');
          // É essencial passar offsetInBytes e lengthInBytes para obter a fatia exata dos bytes
          final bytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          
          if (isCorruptOrEmpty && exists) {
            try {
              fs.xDelete(path, 0);
            } catch (delErr) {
              debugPrint('[DatabaseManager] Aviso ao remover corrompido: $delErr');
            }
          }
          
          final opened = fs.xOpen(
            Sqlite3Filename(path),
            SqlFlag.SQLITE_OPEN_CREATE | SqlFlag.SQLITE_OPEN_READWRITE,
          );
          opened.file.xTruncate(bytes.length);
          opened.file.xWrite(bytes, 0);
          opened.file.xClose();
          await fs.flush();
          debugPrint('[DatabaseManager] Asset $dbName persistido com sucesso (${bytes.length} bytes).');
        } catch (e, st) {
          debugPrint('[DatabaseManager] Falha crítica ao gravar asset $dbName: $e\n$st');
          rethrow;
        }
      }

      try {
        final db = sqlite.open(path);
        // Garante compatibilidade Web: desativa WAL no VFS IndexedDB
        db.execute('PRAGMA journal_mode = DELETE;');
        _openDatabases[dbName] = db;
        return db;
      } catch (openError) {
        // Se ainda assim o SQLite rejeitar, remove o arquivo inválido do VFS para a próxima tentativa
        debugPrint('[DatabaseManager] Erro ao abrir $path: $openError. Limpando arquivo...');
        try {
          fs.xDelete(path, 0);
        } catch (_) {}
        rethrow;
      }
    } else {
      // Fallback em memória
      final db = sqlite.openInMemory();
      _openDatabases[dbName] = db;
      return db;
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
