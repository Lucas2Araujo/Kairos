import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/data/repositories/pericope_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/bible/bible_reader_view.dart';
import 'package:kairos_web/views/bible/widgets/bible_immersive_view.dart';
import 'package:kairos_web/views/bible/widgets/bible_settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBibleRepository extends BibleRepository {
  @override
  Future<List<BibleBook>> getBooks() async {
    return const [
      BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
      BibleBook(id: 2, name: 'Êxodo', testament: 'VT', chaptersCount: 40),
    ];
  }

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String bookName = ''}) async {
    final prefix = bookId == 1 ? 'Gênesis $chapter' : 'Êxodo $chapter';
    return [
      BibleVerse(
        id: (chapter - 1) * 2 + 1,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Livro',
        chapter: chapter,
        verse: 1,
        text: '$prefix: No princípio criou Deus os céus e a terra.',
      ),
      BibleVerse(
        id: (chapter - 1) * 2 + 2,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Livro',
        chapter: chapter,
        verse: 2,
        text: '$prefix: E a terra era sem forma e vazia.',
      ),
    ];
  }

  @override
  Future<Map<int, String>> getChapterHighlights(int bookId, int chapter) async {
    return {};
  }
}

class MockPericopeRepository extends PericopeRepository {
  @override
  Future<List<Pericope>> getPericopes(int bookId, int chapter) async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService BibleReadingMode', () {
    test('defaults to verseByVerse and switches properly with full backward compatibility', () {
      final themeService = ThemeService();

      // Padrão
      themeService.setReadingMode(BibleReadingMode.verseByVerse);
      expect(themeService.readingMode, equals(BibleReadingMode.verseByVerse));
      expect(themeService.isContinuousReading, isFalse);
      expect(themeService.isImmersiveReading, isFalse);

      // Alterna para Imersivo
      themeService.setReadingMode(BibleReadingMode.immersive);
      expect(themeService.readingMode, equals(BibleReadingMode.immersive));
      expect(themeService.isImmersiveReading, isTrue);
      expect(themeService.isContinuousReading, isFalse);

      // Alterna para Contínuo
      themeService.setReadingMode(BibleReadingMode.continuous);
      expect(themeService.readingMode, equals(BibleReadingMode.continuous));
      expect(themeService.isContinuousReading, isTrue);
      expect(themeService.isImmersiveReading, isFalse);

      // Retrocompatibilidade com setContinuousReading
      themeService.setContinuousReading(false);
      expect(themeService.readingMode, equals(BibleReadingMode.verseByVerse));
      expect(themeService.isContinuousReading, isFalse);
      expect(themeService.isImmersiveReading, isFalse);

      themeService.setContinuousReading(true);
      expect(themeService.readingMode, equals(BibleReadingMode.continuous));
      expect(themeService.isContinuousReading, isTrue);
      expect(themeService.isImmersiveReading, isFalse);
    });
  });

  group('BibleSettingsSheet Reading Modes', () {
    testWidgets('allows selecting Versículos, Contínuo, and Imersivo', (tester) async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setReadingMode(BibleReadingMode.verseByVerse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BibleSettingsSheet(controller: ctrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Modo de Leitura'), findsOneWidget);
      expect(find.text('Versículos'), findsOneWidget);
      expect(find.text('Contínuo'), findsOneWidget);
      expect(find.text('Imersivo'), findsOneWidget);

      // Seleciona Imersivo
      await tester.tap(find.text('Imersivo'));
      await tester.pumpAndSettle();
      expect(themeService.readingMode, equals(BibleReadingMode.immersive));
      expect(themeService.isImmersiveReading, isTrue);

      // Seleciona Contínuo
      await tester.tap(find.text('Contínuo'));
      await tester.pumpAndSettle();
      expect(themeService.readingMode, equals(BibleReadingMode.continuous));
      expect(themeService.isContinuousReading, isTrue);

      // Seleciona Versículos
      await tester.tap(find.text('Versículos'));
      await tester.pumpAndSettle();
      expect(themeService.readingMode, equals(BibleReadingMode.verseByVerse));
    });
  });

  group('BibleImmersiveView & BibleReaderView', () {
    testWidgets('renders clean book text without verse badges and toggles controls on tap', (tester) async {
      final themeService = ThemeService();
      themeService.setReadingMode(BibleReadingMode.immersive);

      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica presença do BibleImmersiveView
      expect(find.byType(BibleImmersiveView), findsOneWidget);

      // O texto dos versículos deve estar visível
      expect(find.textContaining('No princípio criou Deus os céus e a terra.'), findsOneWidget);
      expect(find.textContaining('E a terra era sem forma e vazia.'), findsOneWidget);

      // No modo imersivo, NÃO deve haver badges numéricos de versículos
      // Na visualização normal ou contínua, existem widgets com o número '1' ou '2' isolado.
      // No modo imersivo, o texto é puro sem badges.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);

      // Inicialmente, os controles (AppBar e pílula flutuante) estão visíveis
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const ValueKey('floating_pill_active')), findsOneWidget);

      // Toque simples na tela alterna e esconde os controles
      await tester.tap(find.byType(BibleImmersiveView));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const ValueKey('floating_pill_active')), findsNothing);
      expect(find.byKey(const ValueKey('controls_hidden')), findsOneWidget);

      // Toque simples novamente reexibe os controles
      await tester.tap(find.byType(BibleImmersiveView));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const ValueKey('floating_pill_active')), findsOneWidget);
    });

    testWidgets('long press selects verse and opens selection action sheet', (tester) async {
      final themeService = ThemeService();
      themeService.setReadingMode(BibleReadingMode.immersive);

      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // Toque longo no versículo 1
      final verseFinder = find.byKey(const ValueKey('immersive_verse_1_1_1'));
      expect(verseFinder, findsOneWidget);

      await tester.longPress(verseFinder);
      await tester.pumpAndSettle();

      // Barra de ações de seleção deve estar visível com cores de destaque e botões de ação
      expect(find.byKey(const ValueKey('selection_sheet_active')), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
    });

    testWidgets('BibleImmersiveView renders chapter headers and separator between chapters', (tester) async {
      final themeService = ThemeService();
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BibleImmersiveView(
              controller: ctrl,
              themeService: themeService,
              onToggleControls: () {},
              onSelectVerse: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cabeçalho inicial
      expect(find.text('Gênesis'), findsOneWidget);
      expect(find.text('Capítulo 1'), findsOneWidget);
      expect(find.textContaining('Gênesis 1: No princípio'), findsOneWidget);
    });

    testWidgets('BibleImmersiveView loads next chapter when scrolled', (tester) async {
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final themeService = ThemeService();
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BibleImmersiveView(
              controller: ctrl,
              themeService: themeService,
              onToggleControls: () {},
              onSelectVerse: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Rola para baixo para acionar o carregamento do próximo capítulo
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Deve ter carregado o Capítulo 2 com o separador discreto
      expect(find.text('— Gênesis 2 —'), findsOneWidget);
      expect(find.textContaining('Gênesis 2: No princípio'), findsOneWidget);
    });
  });
}
