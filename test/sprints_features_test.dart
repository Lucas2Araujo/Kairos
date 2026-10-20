import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/database/database_manager.dart';
import 'package:kairos_web/core/utils/bible_extractor.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/services/updater_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('Sprint 1: BibleExtractor & ThemeService (Sepia)', () {
    test('BibleExtractor detects valid references and ignores false positives', () {
      const sample = 'Leia Jo 3:16, 1Co 13:4-7, Sl 23:1 e evite falsos como Teste 10:20.';
      final refs = BibleExtractor.extractAllBibleRefs(sample);

      expect(refs, ['Jo 3:16', '1Co 13:4-7', 'Sl 23:1']);

      final segments = BibleExtractor.splitTextByBibleRefs('Amor em 1Jo 4:8 sempre.');
      expect(segments.length, 3);
      expect(segments[0].text, 'Amor em ');
      expect(segments[0].reference, isNull);
      expect(segments[1].text, '1Jo 4:8');
      expect(segments[1].reference, '1Jo 4:8');
      expect(segments[2].text, ' sempre.');
      expect(segments[2].reference, isNull);
    });

    test('ThemeService switches between Light, Dark, AMOLED, and Sepia with persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final themeService = ThemeService();
      await themeService.init();

      themeService.setThemePreset('sepia');
      expect(themeService.isSepia, isTrue);
      expect(themeService.isAmoled, isFalse);
      expect(themeService.activeThemePreset, 'sepia');
      expect(themeService.lightTheme.scaffoldBackgroundColor, const Color(0xFFF5ECD7));
      expect(themeService.lightTheme.colorScheme.onSurface, const Color(0xFF2C1E14));
      expect(themeService.lightTheme.colorScheme.primary, const Color(0xFF8B5A2B));

      themeService.setThemePreset('amoled');
      expect(themeService.isAmoled, isTrue);
      expect(themeService.isSepia, isFalse);
      expect(themeService.activeThemePreset, 'amoled');
      expect(themeService.darkTheme.scaffoldBackgroundColor, Colors.black);
    });
  });

  group('Sprint 2: Whole-Verse Highlights & FTS5 Global Search', () {
    test('userPreservedTables preserves verse_highlights during DB migration', () {
      expect(userPreservedTables.contains('verse_highlights'), isTrue);

      final oldDb = sqlite3.openInMemory();
      oldDb.execute('''
        CREATE TABLE verse_highlights (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          color TEXT NOT NULL,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (book_id, chapter, verse)
        );
      ''');
      oldDb.execute("INSERT INTO verse_highlights (book_id, chapter, verse, color) VALUES (43, 3, 16, '#FFEB3B');");

      final dump = dumpUserTables(oldDb);
      oldDb.dispose();

      expect(dump.containsKey('verse_highlights'), isTrue);

      final newDb = sqlite3.openInMemory();
      newDb.execute('''
        CREATE TABLE verse_highlights (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          color TEXT NOT NULL,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (book_id, chapter, verse)
        );
      ''');
      restoreUserTables(newDb, dump);

      final rows = newDb.select('SELECT * FROM verse_highlights WHERE book_id = 43 AND chapter = 3 AND verse = 16;');
      expect(rows.length, 1);
      expect(rows.first['color'], '#FFEB3B');
      newDb.dispose();
    });

    test('assets/hinario.db has all 4 FTS5 tables and verse_highlights table populated', () {
      final db = sqlite3.open('assets/hinario.db', mode: OpenMode.readOnly);
      try {
        final tables = db
            .select("SELECT name FROM sqlite_master WHERE type='table';")
            .map((r) => r['name'] as String)
            .toSet();

        expect(tables.contains('hino_fts'), isTrue);
        expect(tables.contains('biblia_fts'), isTrue);
        expect(tables.contains('meditacao_fts'), isTrue);
        expect(tables.contains('licao_fts'), isTrue);
        expect(tables.contains('verse_highlights'), isTrue);

        final bibleMatches = db.select("SELECT verse_reference FROM biblia_fts WHERE biblia_fts MATCH '\"principio\" \"criou\"' LIMIT 5;");
        expect(bibleMatches.isNotEmpty, isTrue);
      } finally {
        db.dispose();
      }
    });
  });

  group('Sprint 3: UpdaterService version comparison', () {
    test('UpdaterService.isNewerVersion compares semantic versions accurately', () {
      expect(UpdaterService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(UpdaterService.isNewerVersion('v1.2.0', '1.1.9'), isTrue);
      expect(UpdaterService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(UpdaterService.isNewerVersion('0.9.9', '1.0.0'), isFalse);
    });
  });
}

