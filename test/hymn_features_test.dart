import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/constants/app_constants.dart';
import 'package:kairos_web/core/database/database_manager.dart';
import 'package:kairos_web/data/repositories/hymn_repository.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/hymns/hymn_detail_view.dart';
import 'package:kairos_web/views/hymns/widgets/hymn_info_dialog.dart';
import 'package:kairos_web/views/hymns/widgets/hymn_text_format_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/common.dart';
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

  group('HymnRepository Database Features', () {
    late Database inMemoryDb;
    late DatabaseManager dbManager;
    late HymnRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      inMemoryDb = sqlite3.openInMemory();
      inMemoryDb.execute('''
        CREATE TABLE hino (
          id INTEGER PRIMARY KEY,
          numero TEXT NOT NULL,
          titulo TEXT NOT NULL,
          letra TEXT,
          autor_letra TEXT,
          autor_musica TEXT,
          texto_base TEXT,
          categoria TEXT,
          subcategoria TEXT,
          autores TEXT,
          link_video TEXT
        );
        CREATE TABLE favorito (
          hino_id INTEGER PRIMARY KEY,
          data_favoritado DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY (hino_id) REFERENCES hino(id) ON DELETE CASCADE
        );
        CREATE TABLE tema (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL UNIQUE
        );
        CREATE TABLE hino_tema (
          hino_id INTEGER NOT NULL,
          tema_id INTEGER NOT NULL,
          PRIMARY KEY (hino_id, tema_id)
        );
        CREATE TABLE texto_biblico (
          id INTEGER PRIMARY KEY,
          referencia TEXT NOT NULL
        );
        CREATE TABLE hino_texto (
          hino_id INTEGER NOT NULL,
          texto_id INTEGER NOT NULL,
          PRIMARY KEY (hino_id, texto_id)
        );
      ''');

      // Inserir hinos de teste
      inMemoryDb.execute('''
        INSERT INTO hino (id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, link_video)
        VALUES 
          (1, '1', 'Santo, Santo, Santo', 'Santo! Santo! Santo! Deus onipotente!', 'Reginald Heber', 'John B. Dykes', 'Apocalipse 4:8', 'Adoração', 'https://youtu.be/test1'),
          (2, '2', 'Ó Adorai o Senhor', 'Ó adorai o Senhor na beleza da santidade', 'Edwin Hatch', 'Robert Lowry', 'Salmo 96:9', 'Adoração', NULL),
          (587, '587A', 'Chegou a Hora A', 'Letra A', 'Autor A', 'Musica A', 'Salmo 100', 'Louvor', NULL),
          (588, '587B', 'Chegou a Hora B', 'Letra B', 'Autor B', 'Musica B', 'Salmo 101', 'Louvor', NULL),
          (600, '600', 'Em Paz Eu Vou', 'Em paz eu vou, viver com Deus', 'Autor Fim', 'Musica Fim', 'Números 6:24-26', 'Despedida', 'https://youtu.be/test600');
      ''');

      // Inserir temas
      inMemoryDb.execute('''
        INSERT INTO tema (id, nome) VALUES (1, 'Adoração e Louvor'), (2, 'Sábado e Criação');
        INSERT INTO hino_tema (hino_id, tema_id) VALUES (1, 1), (1, 2);
      ''');

      // Mock database manager
      dbManager = _MockDbManager(inMemoryDb);
      repo = HymnRepository(dbManager: dbManager);
    });

    tearDown(() {
      inMemoryDb.dispose();
    });

    test('isFavorite returns correct initial status', () async {
      expect(await repo.isFavorite(1), isFalse);
    });

    test('toggleFavorite toggles favorite status correctly', () async {
      final added = await repo.toggleFavorite(1);
      expect(added, isTrue);
      expect(await repo.isFavorite(1), isTrue);

      final removed = await repo.toggleFavorite(1);
      expect(removed, isFalse);
      expect(await repo.isFavorite(1), isFalse);
    });

    test('getRelatedThemes returns ordered list of theme names', () async {
      final themes = await repo.getRelatedThemes(1);
      expect(themes, ['Adoração e Louvor', 'Sábado e Criação']);

      final emptyThemes = await repo.getRelatedThemes(2);
      expect(emptyThemes, isEmpty);
    });

    test('getMaxHymnNumber returns highest numerical hymn', () async {
      final maxNum = await repo.getMaxHymnNumber();
      expect(maxNum, 600);
    });

    test('getByNumero retrieves hymn correctly with video link', () async {
      final hymn = await repo.getByNumero('1');
      expect(hymn, isNotNull);
      expect(hymn!.titulo, 'Santo, Santo, Santo');
      expect(hymn.linkVideo, 'https://youtu.be/test1');

      final hymnA = await repo.getByNumero('587');
      expect(hymnA, isNotNull);
      expect(hymnA!.numero, '587A');
    });

    test('getNextHymn and getPreviousHymn navigate sequence including suffix numbers', () async {
      final nextFrom1 = await repo.getNextHymn('1');
      expect(nextFrom1?.numero, '2');

      final nextFrom587A = await repo.getNextHymn('587A');
      expect(nextFrom587A?.numero, '587B');

      final prevFrom587B = await repo.getPreviousHymn('587B');
      expect(prevFrom587B?.numero, '587A');

      final nextFrom600 = await repo.getNextHymn('600');
      expect(nextFrom600, isNull);

      final prevFrom1 = await repo.getPreviousHymn('1');
      expect(prevFrom1, isNull);
    });
  });

  group('ThemeService Hymn Text Settings', () {
    test('hymn text alignment and font size update correctly and persist', () async {
      SharedPreferences.setMockInitialValues({});
      final themeService = ThemeService();
      await themeService.init();

      expect(themeService.hymnTextAlign, TextAlign.center);
      themeService.setHymnTextAlign(TextAlign.left);
      expect(themeService.hymnTextAlign, TextAlign.left);

      themeService.setFontFamily(AppConstants.fontMontserrat);
      expect(themeService.fontFamily, AppConstants.fontMontserrat);

      themeService.setFontSizeMultiplier(1.4);
      expect(themeService.fontSizeMultiplier, 1.4);
    });
  });

  group('Hymn Detail Widgets Test', () {
    const testHymn = Hymn(
      id: 1,
      numero: '1',
      titulo: 'Santo, Santo, Santo!',
      letra: 'Santo! Santo! Santo! Deus onipotente!\nCedo de manhã cantaremos Teu louvor.',
      autorLetra: 'Reginald Heber',
      autorMusica: 'John B. Dykes',
      textoBase: 'Apocalipse 4:8',
      categoria: 'Adoração e Louvor',
      linkVideo: 'https://youtube.com/watch?v=test',
    );

    testWidgets('HymnInfoDialog displays hymn data and sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HymnInfoDialog(
              hymn: testHymn,
              relatedTexts: const ['Salmos 99:5'],
              relatedThemes: const ['Santidade', 'Trindade'],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Santo, Santo, Santo!'), findsOneWidget);
      expect(find.text('Adoração e Louvor'), findsOneWidget);
      expect(find.textContaining('Reginald Heber'), findsOneWidget);
      expect(find.textContaining('John B. Dykes'), findsOneWidget);
      expect(find.text('Apocalipse 4:8'), findsOneWidget);
      expect(find.text('Salmos 99:5'), findsOneWidget);
      expect(find.text('Santidade'), findsOneWidget);
      expect(find.text('Trindade'), findsOneWidget);
    });

    testWidgets('HymnTextFormatSheet renders controls and alters ThemeService', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final themeService = ThemeService();
      await themeService.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HymnTextFormatSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ajustes de Texto'), findsOneWidget);
      expect(find.text('Tamanho da Fonte'), findsOneWidget);
      expect(find.text('Alinhamento'), findsOneWidget);
      expect(find.text('Família Tipográfica'), findsOneWidget);

      // Tap Esquerda
      await tester.tap(find.text('Esquerda'));
      await tester.pumpAndSettle();
      expect(themeService.hymnTextAlign, TextAlign.left);

      // Tap Padrão reset button
      await tester.tap(find.text('Padrão'));
      await tester.pumpAndSettle();
      expect(themeService.hymnTextAlign, TextAlign.center);
    });

    testWidgets('HymnDetailView displays top nav, base text button, and bottom bar', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await ThemeService().init();

      await tester.pumpWidget(
        const MaterialApp(
          home: HymnDetailView(hymn: testHymn),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Hino 1'), findsOneWidget);

      // Navigation chevrons exist
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Info action button exists
      expect(find.byIcon(Icons.info_outline), findsOneWidget);

      // Highlighted Texto Base button exists below title
      expect(find.text('Texto Base: Apocalipse 4:8'), findsOneWidget);

      // Lyrics exist
      expect(find.textContaining('Santo! Santo! Santo!'), findsOneWidget);

      // 3 bottom bar buttons exist
      expect(find.text('Texto'), findsOneWidget);
      expect(find.text('Áudio'), findsOneWidget);
      expect(find.text('Vídeo'), findsOneWidget);

      // Toggle audio player
      await tester.tap(find.text('Áudio'));
      await tester.pumpAndSettle();
      expect(find.text('Ocultar'), findsOneWidget);
      expect(find.byIcon(Icons.headphones), findsWidgets);
    });
  });
}

class _MockDbManager implements DatabaseManager {
  final Database _db;
  _MockDbManager(this._db);

  @override
  Future<CommonDatabase> getDatabase(String dbName) async => _db;

  @override
  Future<void> copyDatabaseFromAssets(String dbName) async {}

  @override
  Future<void> checkAndUpdateDatabase(String dbName) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
