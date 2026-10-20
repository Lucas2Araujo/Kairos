import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as ffi;

Future<CommonDatabase> openPlatformDatabase(String dbName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(appDir.path, dbName);
  final file = File(dbPath);

  final byteData = await rootBundle.load('assets/$dbName');
  final expectedLength = byteData.lengthInBytes;

  bool shouldCopy = false;
  if (!await file.exists()) {
    shouldCopy = true;
  } else {
    final curLength = await file.length();
    if (curLength != expectedLength) {
      debugPrint('[DatabaseManagerIO] Tamanho divergente para $dbName ($curLength vs $expectedLength). Atualizando cópia...');
      shouldCopy = true;
    }
  }

  if (shouldCopy) {
    debugPrint('[DatabaseManagerIO] Extraindo asset $dbName para $dbPath...');
    await file.parent.create(recursive: true);
    final buffer = byteData.buffer;
    await file.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );
  }

  final db = ffi.sqlite3.open(dbPath);
  try {
    db.execute('PRAGMA journal_mode = WAL;');
  } catch (_) {}
  return db;
}
