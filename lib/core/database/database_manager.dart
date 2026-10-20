import 'dart:async';
import 'dart:typed_data';
import 'package:sqlite3/common.dart';

import 'database_manager_stub.dart'
    if (dart.library.js_interop) 'database_manager_web.dart'
    if (dart.library.io) 'database_manager_io.dart';

/// Tabelas de dados de usuário preservadas durante atualização de assets
const userPreservedTables = <String>[
  'favorito',
  'historico',
  'lista_culto',
  'item_lista_culto',
  'preferencias',
  'reading_log',
  'ss_user_notes',
  'ss_question_answers',
  'user_gamification',
  'user_quiz_answers',
  'user_quiz_stats',
  'notification_reminders',
  'quiz_reports',
  'ss_mind_maps',
];

/// Computa o marcador de versão (tamanho em bytes + file change counter do header SQLite a 24..27)
String sqliteVersionMarker(ByteData byteData) {
  final length = byteData.lengthInBytes;
  final changeCounter = length >= 28 ? byteData.getUint32(24) : 0;
  return '$length:$changeCounter';
}

/// Valida se o cabeçalho possui tamanho mínimo e o magic 'SQLite format 3'
bool isValidSqliteHeader(Uint8List header, int fileSize) {
  if (fileSize < 100 || header.length < 16) return false;
  return String.fromCharCodes(header.take(15)) == 'SQLite format 3';
}

/// Extrai os registros das tabelas de usuário existentes no banco antigo
Map<String, List<Map<String, Object?>>> dumpUserTables(CommonDatabase old) {
  final dump = <String, List<Map<String, Object?>>>{};
  final existingTables = old
      .select("SELECT name FROM sqlite_master WHERE type='table';")
      .map((r) => r['name'] as String)
      .toSet();

  for (final table in userPreservedTables) {
    if (!existingTables.contains(table)) continue;
    try {
      final rows = old.select('SELECT * FROM "$table";');
      if (rows.isNotEmpty) {
        dump[table] = rows.map((r) => Map<String, Object?>.from(r)).toList();
      }
    } catch (_) {}
  }
  return dump;
}

/// Restaura os dados das tabelas de usuário com interseção de colunas e INSERT OR REPLACE
void restoreUserTables(
  CommonDatabase db,
  Map<String, List<Map<String, Object?>>> dump,
) {
  if (dump.isEmpty) return;

  final existingTables = db
      .select("SELECT name FROM sqlite_master WHERE type='table';")
      .map((r) => r['name'] as String)
      .toSet();

  bool wasFkEnabled = false;
  try {
    final res = db.select('PRAGMA foreign_keys;');
    wasFkEnabled = res.isNotEmpty && res.first.values.first == 1;
    if (wasFkEnabled) {
      db.execute('PRAGMA foreign_keys = OFF;');
    }
  } catch (_) {}

  try {
    for (final entry in dump.entries) {
      final table = entry.key;
      final rows = entry.value;
      if (rows.isEmpty || !existingTables.contains(table)) continue;

      final targetCols = db
          .select('PRAGMA table_info("$table");')
          .map((r) => r['name'] as String)
          .toSet();

      final commonKeys = rows.first.keys.where(targetCols.contains).toList();
      if (commonKeys.isEmpty) continue;

      final colsSql = commonKeys.map((k) => '"$k"').join(', ');
      final placeholders = List.filled(commonKeys.length, '?').join(', ');
      final sql = 'INSERT OR REPLACE INTO "$table" ($colsSql) VALUES ($placeholders);';

      db.execute('BEGIN TRANSACTION;');
      try {
        for (final row in rows) {
          final values = commonKeys.map((k) => row[k]).toList();
          db.execute(sql, values);
        }
        db.execute('COMMIT;');
      } catch (_) {
        try {
          db.execute('ROLLBACK;');
        } catch (_) {}
      }
    }
  } finally {
    if (wasFkEnabled) {
      try {
        db.execute('PRAGMA foreign_keys = ON;');
      } catch (_) {}
    }
  }
}

/// Gerenciador unificado de conexões SQLite multiplataforma (Web e Mobile/Desktop)
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  final Map<String, Future<CommonDatabase>> _openDatabases = {};

  bool get isInitialized => true;

  Future<void> initialize() async {
    // Inicialização sob demanda implementada por plataforma
  }

  /// Garante que o banco exista e retorna uma conexão aberta
  Future<CommonDatabase> getDatabase(String dbName) {
    return _openDatabases[dbName] ??= () async {
      try {
        return await openPlatformDatabase(dbName);
      } catch (_) {
        _openDatabases.remove(dbName);
        rethrow;
      }
    }();
  }

  /// Fecha todas as conexões ativas
  void dispose() {
    for (final future in _openDatabases.values) {
      future.then((db) {
        try {
          db.dispose();
        } catch (_) {}
      }, onError: (_) {});
    }
    _openDatabases.clear();
  }
}
