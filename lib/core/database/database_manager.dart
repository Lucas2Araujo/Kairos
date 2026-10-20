import 'dart:async';
import 'package:sqlite3/common.dart';

import 'database_manager_stub.dart'
    if (dart.library.js_interop) 'database_manager_web.dart'
    if (dart.library.io) 'database_manager_io.dart';

/// Gerenciador unificado de conexões SQLite multiplataforma (Web e Mobile/Desktop)
class DatabaseManager {
  static final DatabaseManager _instance = DatabaseManager._internal();
  factory DatabaseManager() => _instance;
  DatabaseManager._internal();

  final Map<String, CommonDatabase> _openDatabases = {};

  bool get isInitialized => true;

  Future<void> initialize() async {
    // Inicialização sob demanda implementada por plataforma
  }

  /// Garante que o banco exista e retorna uma conexão aberta
  Future<CommonDatabase> getDatabase(String dbName) async {
    if (_openDatabases.containsKey(dbName)) {
      return _openDatabases[dbName]!;
    }

    final db = await openPlatformDatabase(dbName);
    _openDatabases[dbName] = db;
    return db;
  }

  /// Fecha todas as conexões ativas
  void dispose() {
    for (final db in _openDatabases.values) {
      db.dispose();
    }
    _openDatabases.clear();
  }
}
