import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as ffi;

import 'database_manager.dart';

Future<CommonDatabase> openPlatformDatabase(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDir.path, dbName);
  final file = File(dbPath);
  final verFile = File('$dbPath.ver');

  final byteData = await rootBundle.load('assets/$dbName');
  final expectedMarker = sqliteVersionMarker(byteData);

  final exists = await file.exists();
  bool isCorruptOrEmpty = false;
  if (exists) {
    try {
      final len = await file.length();
      if (len < 100) {
        isCorruptOrEmpty = true;
      } else {
        final raf = await file.open(mode: FileMode.read);
        try {
          final header = await raf.read(16);
          if (!isValidSqliteHeader(header, len)) {
            isCorruptOrEmpty = true;
          }
        } finally {
          await raf.close();
        }
      }
    } catch (_) {
      isCorruptOrEmpty = true;
    }
  }

  bool shouldCopy = false;
  bool preserveUser = false;

  if (!exists || isCorruptOrEmpty) {
    shouldCopy = true;
  } else {
    if (!await verFile.exists()) {
      await verFile.writeAsString(expectedMarker, flush: true);
    } else {
      final savedMarker = (await verFile.readAsString()).trim();
      if (savedMarker != expectedMarker) {
        debugPrint('[DatabaseManagerIO] Asset alterado para $dbName ($savedMarker vs $expectedMarker). Atualizando...');
        shouldCopy = true;
        preserveUser = true;
      }
    }
  }

  if (shouldCopy) {
    Map<String, List<Map<String, Object?>>>? dump;
    if (preserveUser) {
      try {
        final oldDb = ffi.sqlite3.open(dbPath);
        try {
          try {
            oldDb.execute('PRAGMA wal_checkpoint(TRUNCATE);');
          } catch (_) {}
          dump = dumpUserTables(oldDb);
        } finally {
          oldDb.dispose();
        }
      } catch (e) {
        debugPrint('[DatabaseManagerIO] Erro ao extrair dados de usuário: $e');
        final db = ffi.sqlite3.open(dbPath);
        try {
          db.execute('PRAGMA journal_mode = WAL;');
        } catch (_) {}
        return db;
      }
    }

    debugPrint('[DatabaseManagerIO] Extraindo asset $dbName para $dbPath...');
    await file.parent.create(recursive: true);

    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      try { await walFile.delete(); } catch (_) {}
    }
    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      try { await shmFile.delete(); } catch (_) {}
    }

    final buffer = byteData.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
    await verFile.writeAsString(expectedMarker, flush: true);

    final db = ffi.sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}

    if (dump != null && dump.isNotEmpty) {
      try {
        restoreUserTables(db, dump);
      } catch (e) {
        debugPrint('[DatabaseManagerIO] Erro ao restaurar dados de usuário: $e');
      }
    }
    return db;
  }

  try {
    final db = ffi.sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    return db;
  } catch (_) {
    await file.parent.create(recursive: true);
    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      try { await walFile.delete(); } catch (_) {}
    }
    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      try { await shmFile.delete(); } catch (_) {}
    }
    final buffer = byteData.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
    await verFile.writeAsString(expectedMarker, flush: true);
    final db = ffi.sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    return db;
  }
}
