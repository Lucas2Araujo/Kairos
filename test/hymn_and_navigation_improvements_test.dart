import 'dart:ffi' hide Size;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/hymn_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/data/repositories/hymn_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/bible/widgets/bible_verse_preview_modal.dart';
import 'package:kairos_web/views/hymns/hymn_list_view.dart';
import 'package:kairos_web/views/navigation/main_navigation_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

class _FakeHymnRepository extends HymnRepository {
  List<Hymn> allHymns = [];
  List<Hymn> favoriteHymns = [];
  List<Hymn> recentHymns = [];
  Map<String, List<Hymn>> categoryHymns = {};
  Map<String, List<Hymn>> themeHymns = {};

  @override
  Future<List<Hymn>> getAll() async => List.of(allHymns);

  @override
  Future<List<Hymn>> getFavorites() async => List.of(favoriteHymns);

  @override
  Future<List<Hymn>> getRecent({int limit = 50}) async => List.of(recentHymns);

  @override
  Future<List<Hymn>> getByCategory(String category) async =>
      List.of(categoryHymns[category] ?? []);

  @override
  Future<List<Hymn>> getByTheme(String theme) async =>
      List.of(themeHymns[theme] ?? []);

  @override
  Future<List<String>> getCategories() async => categoryHymns.keys.toList();

  @override
  Future<List<String>> getThemes() async => themeHymns.keys.toList();
}

class _FakeBibleRepository extends BibleRepository {
  @override
  Future<List<BibleVerse>> buscarPassagem(String refText) async {
    final clean = refText.trim();
    return [
      BibleVerse(
        id: 1,
        bookId: 1,
        bookName: clean,
        chapter: 1,
        verse: 1,
        text: 'Versículo de teste para $clean.',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'has_seen_welcome': true,
    });
    final theme = ThemeService();
    theme.setThemeStyle(AppThemeStyle.materialYou);
    theme.setGlassAnimationEnabled(false);
  });

  group('ThemeService UI Scaling and Transitions', () {
    test('effectiveUiScale respects tablet width and manual scale multiplier', () {
      final theme = ThemeService();
      theme.setAutoTabletScaling(true);
      theme.setUiScaleMultiplier(1.0);

      // Width < 600px uses standard multiplier 1.0
      expect(theme.effectiveUiScale(390), equals(1.0));
      expect(theme.effectiveUiScale(599), equals(1.0));

      // Tablet width >= 600px with default multiplier scales to 1.15
      expect(theme.effectiveUiScale(600), equals(1.15));
      expect(theme.effectiveUiScale(1024), equals(1.15));

      // When user configures manual multiplier, manual takes precedence
      theme.setUiScaleMultiplier(1.25);
      expect(theme.effectiveUiScale(390), equals(1.25));
      expect(theme.effectiveUiScale(800), equals(1.25));

      // When autoTabletScaling is disabled, manual multiplier is used even on tablets
      theme.setAutoTabletScaling(false);
      theme.setUiScaleMultiplier(1.0);
      expect(theme.effectiveUiScale(800), equals(1.0));

      // Reset
      theme.setAutoTabletScaling(true);
      theme.setUiScaleMultiplier(1.0);
    });

    testWidgets('GlassFadeSlideTransitionsBuilder builds slide and fade animation transitions',
        (tester) async {
      const builder = GlassFadeSlideTransitionsBuilder();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              const anim = AlwaysStoppedAnimation<double>(0.5);
              const secAnim = AlwaysStoppedAnimation<double>(0.0);
              return builder.buildTransitions(
                PageRouteBuilder(pageBuilder: (_, __, ___) => const SizedBox()),
                context,
                anim,
                secAnim,
                const Text('Transition Child'),
              );
            },
          ),
        ),
      );

      expect(find.byType(SlideTransition), findsOneWidget);
      expect(find.byType(FadeTransition), findsNWidgets(2));
      expect(find.text('Transition Child'), findsOneWidget);
    });
  });

  group('HymnController Sorting, Tabs and OriginHymn', () {
    late _FakeHymnRepository fakeRepo;
    late Hymn hymn1;
    late Hymn hymn2;
    late Hymn hymn10;
    late Hymn hymn20;

    setUp(() {
      hymn1 = const Hymn(id: 1, numero: '1', titulo: 'Ó Deus de Amor', letra: 'L1');
      hymn2 = const Hymn(id: 2, numero: '2', titulo: 'Água Viva', letra: 'L2');
      hymn10 = const Hymn(id: 3, numero: '10', titulo: 'Zelo Cristão', letra: 'L3');
      hymn20 = const Hymn(id: 4, numero: '20', titulo: 'A Deus Demos Glória', letra: 'L4');

      fakeRepo = _FakeHymnRepository();
      fakeRepo.allHymns = [hymn10, hymn1, hymn20, hymn2];
      fakeRepo.favoriteHymns = [hymn2, hymn10];
      fakeRepo.recentHymns = [hymn20, hymn1];
      fakeRepo.themeHymns['Louvor'] = [hymn1, hymn20];
    });

    test('sorts hymns by numAsc, numDesc, titleAsc, and titleDesc', () async {
      final controller = HymnController(repository: fakeRepo);
      await controller.init();

      // numAsc: 1, 2, 10, 20
      controller.setSortMode(HymnSortMode.numAsc);
      expect(controller.hymns.map((h) => h.numero).toList(), equals(['1', '2', '10', '20']));

      // numDesc: 20, 10, 2, 1
      controller.setSortMode(HymnSortMode.numDesc);
      expect(controller.hymns.map((h) => h.numero).toList(), equals(['20', '10', '2', '1']));

      // titleAsc (normalized accents): A Deus Demos Glória, Água Viva, Ó Deus de Amor, Zelo Cristão
      controller.setSortMode(HymnSortMode.titleAsc);
      expect(controller.hymns.map((h) => h.titulo).toList(),
          equals(['A Deus Demos Glória', 'Água Viva', 'Ó Deus de Amor', 'Zelo Cristão']));

      // titleDesc
      controller.setSortMode(HymnSortMode.titleDesc);
      expect(controller.hymns.map((h) => h.titulo).toList(),
          equals(['Zelo Cristão', 'Ó Deus de Amor', 'Água Viva', 'A Deus Demos Glória']));
    });

    test('tab filtering updates list between todos, favoritos, recentes and explorar', () async {
      final controller = HymnController(repository: fakeRepo);
      await controller.init();

      expect(controller.tabFilter, equals(HymnTabFilter.todos));
      expect(controller.hymns.length, equals(4));

      await controller.setTabFilter(HymnTabFilter.favoritos);
      expect(controller.tabFilter, equals(HymnTabFilter.favoritos));
      expect(controller.hymns.map((h) => h.numero).toSet(), equals({'2', '10'}));

      await controller.setTabFilter(HymnTabFilter.recentes);
      expect(controller.tabFilter, equals(HymnTabFilter.recentes));
      expect(controller.hymns.map((h) => h.numero).toSet(), equals({'20', '1'}));

      await controller.setTabFilter(HymnTabFilter.explorar);
      expect(controller.tabFilter, equals(HymnTabFilter.explorar));
      expect(controller.hymns.isEmpty, isTrue);
    });

    test('smart back banner tracks originHymn and resets properly', () async {
      final controller = HymnController(repository: fakeRepo);
      await controller.init();

      // Filter by theme originating from hymn1
      await controller.filterByCategoryOrTheme(theme: 'Louvor', fromHymn: hymn1);
      expect(controller.tabFilter, equals(HymnTabFilter.explorar));
      expect(controller.selectedTheme, equals('Louvor'));
      expect(controller.originHymn, equals(hymn1));
      expect(controller.hasActiveCategoryOrTheme, isTrue);
      expect(controller.hymns.map((h) => h.numero).toSet(), equals({'1', '20'}));

      // Return to explore clears originHymn and category/theme
      await controller.returnToExplore();
      expect(controller.originHymn, isNull);
      expect(controller.selectedTheme, isNull);
      expect(controller.hasActiveCategoryOrTheme, isFalse);
      expect(controller.tabFilter, equals(HymnTabFilter.explorar));

      // Filter again with originHymn then clear filter to return to todos
      await controller.filterByCategoryOrTheme(theme: 'Louvor', fromHymn: hymn2);
      expect(controller.originHymn, equals(hymn2));

      await controller.clearCategoryOrThemeFilter();
      expect(controller.originHymn, isNull);
      expect(controller.selectedTheme, isNull);
      expect(controller.tabFilter, equals(HymnTabFilter.todos));
      expect(controller.hymns.length, equals(4));
    });
  });

  group('BibleVersePreviewModal multi-passage chips and zoom', () {
    testWidgets('renders multi-passage chips with (Base) marker, switches passage and zooms font size',
        (tester) async {
      final fakeRepo = _FakeBibleRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    BibleVersePreviewModal.show(
                      context,
                      reference: 'Salmos 23:1',
                      baseReference: 'Salmos 23:1',
                      references: ['Salmos 23:1', 'João 3:16'],
                      bibleRepository: fakeRepo,
                    );
                  },
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Modal'));
      await tester.pumpAndSettle();

      expect(find.byType(BibleVersePreviewModal), findsOneWidget);

      // Multi-passage chips: base passage marked with ✦ ... (Base)
      expect(find.text('✦ Salmos 23:1 (Base)'), findsOneWidget);
      expect(find.text('João 3:16'), findsOneWidget);

      // Initial active passage text
      expect(find.textContaining('Versículo de teste para Salmos 23:1'), findsOneWidget);

      // Switch chip to João 3:16
      await tester.tap(find.text('João 3:16'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Versículo de teste para João 3:16'), findsOneWidget);

      // Initial font size indicator (e.g. 16pt)
      expect(find.text('16pt'), findsOneWidget);

      // Zoom + increases font size
      await tester.tap(find.byTooltip('Aumentar texto'));
      await tester.pumpAndSettle();
      expect(find.text('18pt'), findsOneWidget);

      // Zoom - decreases font size
      await tester.tap(find.byTooltip('Diminuir texto'));
      await tester.pumpAndSettle();
      expect(find.text('16pt'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(BibleVersePreviewModal), findsNothing);
    });
  });

  group('MainNavigationView Back Button Behavior', () {
    testWidgets('switches from tab != 0 to tab 0, and shows snackbar on first back at tab 0',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Starts at Tab 0 (Início)
      expect(find.text('Início'), findsWidgets);

      // Navigate to Tab 1 (Bíblia) using NavigationDestination
      await tester.tap(find.widgetWithText(NavigationDestination, 'Bíblia'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      // Trigger back button while on tab 1
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));

      // Should return to Tab 0 without closing app or showing exit snackbar yet
      expect(find.text('Volte novamente para sair do app'), findsNothing);

      // Trigger back button at Tab 0
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));

      // Exit warning snackbar should be displayed
      expect(find.text('Volte novamente para sair do app'), findsOneWidget);
    });
  });

  group('Hymn Edition and Kids Hymn Support', () {
    test('KidsHymnStyles correctly identifies kids hymns on hinário antigo (455-468) and novo (508-557)', () {
      expect(KidsHymnStyles.isKidsHymn(455, edition: 'antigo'), isTrue);
      expect(KidsHymnStyles.isKidsHymn('460', edition: 'antigo'), isTrue);
      expect(KidsHymnStyles.isKidsHymn(468, edition: 'antigo'), isTrue);
      expect(KidsHymnStyles.isKidsHymn(454, edition: 'antigo'), isFalse);
      expect(KidsHymnStyles.isKidsHymn(469, edition: 'antigo'), isFalse);
      expect(KidsHymnStyles.isKidsHymn(510, edition: 'antigo'), isFalse);
      expect(KidsHymnStyles.isKidsHymn(510, edition: 'novo'), isTrue);
      expect(KidsHymnStyles.isKidsHymn('520', edition: 'antigo'), isFalse);
      expect(KidsHymnStyles.isKidsHymn('520', edition: 'novo'), isTrue);
    });

    testWidgets('HymnListView renders unified edition dropdown header and settings button',
        (tester) async {
      final fakeRepo = _FakeHymnRepository();
      final controller = HymnController(repository: fakeRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: HymnListView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Unified header title and year badge
      expect(find.text('Hinário Novo'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);

      // Settings button is present in AppBar actions
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Playlist button is removed
      expect(find.byIcon(Icons.playlist_play_rounded), findsNothing);

      // Tap header to switch edition
      await tester.tap(find.text('Hinário Novo'));
      await tester.pumpAndSettle();

      expect(find.text('Hinário Tradicional (1996)'), findsOneWidget);
      await tester.tap(find.text('Hinário Tradicional (1996)'));
      await tester.pumpAndSettle();

      expect(controller.edition, equals('antigo'));
      expect(find.text('Hinário Tradicional'), findsOneWidget);
      expect(find.text('1996'), findsOneWidget);
    });
  });
}
