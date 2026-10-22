import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as ffi;

import '../../services/content_manager.dart';
import 'database_manager.dart';

final Map<String, CommonDatabase> _openedDbs = {};

void closePlatformDatabase(String dbName) {
  final db = _openedDbs.remove(dbName);
  try {
    db?.dispose();
  } catch (_) {}
}

Future<bool> isDbFileInstalled(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(appDir.path, dbName));
  if (!await file.exists()) return false;
  return (await file.length()) >= 100;
}

Future<void> saveDbFileBytes(String dbName, Uint8List bytes) async {
  final appDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(appDir.path, dbName));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<void> deleteDbFile(String dbName) async {
  closePlatformDatabase(dbName);
  final appDir = await getApplicationDocumentsDirectory();
  final file = File(p.join(appDir.path, dbName));
  if (await file.exists()) {
    try { await file.delete(); } catch (_) {}
  }
  for (final ext in ['-wal', '-shm', '.ver']) {
    final extra = File('${file.path}$ext');
    if (await extra.exists()) {
      try { await extra.delete(); } catch (_) {}
    }
  }
}

Future<Uint8List> decompressGzip(Uint8List gzBytes) async {
  return Uint8List.fromList(gzip.decode(gzBytes));
}

Future<CommonDatabase> openPlatformDatabase(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDir.path, dbName);
  final file = File(dbPath);
  final verFile = File('$dbPath.ver');

  ByteData? byteData;
  try {
    byteData = await rootBundle.load('assets/$dbName');
  } catch (_) {
    byteData = null;
  }

  if (byteData == null) {
    // Banco não empacotado em assets (ex: versão bíblica baixada sob demanda)
    final exists = await file.exists();
    final len = exists ? await file.length() : 0;
    if (!exists || len < 100) {
      final moduleId = dbName.replaceAll('.sqlite', '').replaceAll('.db', '');
      await ContentManager().downloadModule(moduleId);
    }
    final db = ffi.sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    _openedDbs[dbName] = db;
    return db;
  }

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
        _openedDbs[dbName] = db;
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
    _openedDbs[dbName] = db;
    return db;
  }

  try {
    final db = ffi.sqlite3.open(dbPath);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } catch (_) {}
    _openedDbs[dbName] = db;
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
    _openedDbs[dbName] = db;
    return db;
  }
}
