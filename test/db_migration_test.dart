import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/database/database_manager.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(OperatingSystem.linux, () {
        try {
          return DynamicLibrary.open('libsqlite3.so');
        } catch (_) {
          return DynamicLibrary.open('libsqlite3.so.0');
        }
      });
    }
  });

  test('sqliteVersionMarker computes length and change counter at offset 24', () {
    final buffer = Uint8List(32);
    // Write change counter = 96 (big endian) at offset 24
    final bd = ByteData.sublistView(buffer);
    bd.setUint32(24, 96);

    expect(sqliteVersionMarker(bd), '32:96');

    // Short buffer (< 28 bytes)
    final shortBd = ByteData(10);
    expect(sqliteVersionMarker(shortBd), '10:0');
  });

  test('isValidSqliteHeader validates size and magic SQLite format 3', () {
    final validHeader = Uint8List.fromList('SQLite format 3\x00'.codeUnits);
    expect(isValidSqliteHeader(validHeader, 100), isTrue);
    expect(isValidSqliteHeader(validHeader, 99), isFalse);

    final invalidHeader = Uint8List.fromList('Not a valid db!!'.codeUnits);
    expect(isValidSqliteHeader(invalidHeader, 100), isFalse);
  });

  test('dumpUserTables returns empty map for DB without user tables', () {
    final bibleDb = sqlite3.openInMemory();
    bibleDb.execute('''
      CREATE TABLE verse (
        id INTEGER PRIMARY KEY,
        text TEXT
      );
    ''');
    bibleDb.execute("INSERT INTO verse VALUES (1, 'In the beginning');");

    final dump = dumpUserTables(bibleDb);
    bibleDb.dispose();

    expect(dump.isEmpty, isTrue);
  });

  test('dump and restore preserves favorito row across schema with added column', () {
    final oldDb = sqlite3.openInMemory();
    oldDb.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY,
        data_favoritado TEXT
      );
    ''');
    oldDb.execute("INSERT INTO favorito (hino_id, data_favoritado) VALUES (1, '2026-01-01 12:00:00');");

    final dump = dumpUserTables(oldDb);
    oldDb.dispose();

    expect(dump.containsKey('favorito'), isTrue);
    expect(dump['favorito']!.length, 1);
    expect(dump['favorito']!.first['hino_id'], 1);

    final newDb = sqlite3.openInMemory();
    newDb.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY,
        data_favoritado TEXT,
        categoria TEXT DEFAULT 'geral'
      );
    ''');

    restoreUserTables(newDb, dump);

    final result = newDb.select('SELECT * FROM favorito WHERE hino_id = 1;');
    expect(result.length, 1);
    expect(result.first['hino_id'], 1);
    expect(result.first['data_favoritado'], '2026-01-01 12:00:00');
    expect(result.first['categoria'], 'geral');

    newDb.dispose();
  });

  test('restoreUserTables gracefully skips tables missing in new schema', () {
    final dump = <String, List<Map<String, Object?>>>{
      'favorito': [
        {'hino_id': 10, 'data_favoritado': '2026-01-01'}
      ],
      'obsolete_table': [
        {'id': 1, 'data': 'test'}
      ],
    };

    final newDb = sqlite3.openInMemory();
    newDb.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY,
        data_favoritado TEXT
      );
    ''');

    // Should not throw even though 'obsolete_table' does not exist in new schema
    restoreUserTables(newDb, dump);

    final res = newDb.select('SELECT * FROM favorito WHERE hino_id = 10;');
    expect(res.length, 1);
    expect(res.first['hino_id'], 10);
    newDb.dispose();
  });

  test('restoreUserTables preserves PRAGMA foreign_keys state', () {
    final dump = <String, List<Map<String, Object?>>>{
      'favorito': [
        {'hino_id': 20, 'data_favoritado': '2026-01-01'}
      ],
    };

    // Test with foreign_keys ON
    final dbWithFk = sqlite3.openInMemory();
    dbWithFk.execute('PRAGMA foreign_keys = ON;');
    dbWithFk.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY,
        data_favoritado TEXT
      );
    ''');
    restoreUserTables(dbWithFk, dump);
    final fkOnResult = dbWithFk.select('PRAGMA foreign_keys;').first.values.first;
    expect(fkOnResult, 1);
    dbWithFk.dispose();

    // Test with foreign_keys OFF
    final dbWithoutFk = sqlite3.openInMemory();
    dbWithoutFk.execute('PRAGMA foreign_keys = OFF;');
    dbWithoutFk.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY,
        data_favoritado TEXT
      );
    ''');
    restoreUserTables(dbWithoutFk, dump);
    final fkOffResult = dbWithoutFk.select('PRAGMA foreign_keys;').first.values.first;
    expect(fkOffResult, 0);
    dbWithoutFk.dispose();
  });

  test('restoreUserTables isolates errors per table', () {
    final dump = <String, List<Map<String, Object?>>>{
      'favorito': [
        {'hino_id': 30, 'data_favoritado': '2026-01-01'}
      ],
      'preferencias': [
        {'chave': 'tema', 'valor': 'escuro'}
      ],
    };

    final newDb = sqlite3.openInMemory();
    // favorito table has a check constraint that causes insert failure
    newDb.execute('''
      CREATE TABLE favorito (
        hino_id INTEGER PRIMARY KEY CHECK (hino_id < 10),
        data_favoritado TEXT
      );
    ''');
    newDb.execute('''
      CREATE TABLE preferencias (
        chave TEXT PRIMARY KEY,
        valor TEXT
      );
    ''');

    // favorito will fail due to CHECK constraint, but preferencias should succeed
    restoreUserTables(newDb, dump);

    expect(newDb.select('SELECT * FROM favorito;').isEmpty, isTrue);
    final prefResult = newDb.select('SELECT * FROM preferencias;');
    expect(prefResult.length, 1);
    expect(prefResult.first['chave'], 'tema');
    expect(prefResult.first['valor'], 'escuro');

    newDb.dispose();
  });
}
