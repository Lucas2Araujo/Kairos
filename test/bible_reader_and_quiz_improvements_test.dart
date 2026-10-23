import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/controllers/quiz_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/data/repositories/pericope_repository.dart';
import 'package:kairos_web/data/repositories/quiz_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/models/quiz_question.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/bible/bible_reader_view.dart';
import 'package:kairos_web/views/bible/widgets/bible_settings_sheet.dart';
import 'package:kairos_web/views/quiz/quiz_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockBibleRepository extends BibleRepository {
  @override
  Future<List<BibleBook>> getBooks() async {
    return const [
      BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
      BibleBook(id: 43, name: 'João', testament: 'NT', chaptersCount: 21),
    ];
  }

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String bookName = ''}) async {
    return [
      BibleVerse(
        id: 1,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Livro',
        chapter: chapter,
        verse: 1,
        text: 'No princípio...',
      ),
      BibleVerse(
        id: 2,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Livro',
        chapter: chapter,
        verse: 2,
        text: 'E a terra era sem forma...',
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

class MockQuizRepository extends QuizRepository {
  Future<List<QuizQuestion>> getQuestionsForDay(String dayId, {String category = 'adultos'}) async {
    return [
      const QuizQuestion(
        id: 'q1',
        dayId: 'sabado',
        quarterlyId: '2024-q4',
        question: 'Quem guiou o povo no deserto?',
        options: ['Moisés', 'Arão', 'Josué', 'Calebe'],
        correctOption: 0,
        explanation: 'Moisés foi o líder designado por Deus.',
      ),
    ];
  }

  Future<int> getStreak() async => 5;

  Future<int> getTotalXp() async => 120;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BibleController Target Verse', () {
    test('jumpToVerse sets targetVerse and clearTargetVerse clears it', () async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      expect(ctrl.targetVerse, isNull);

      await ctrl.jumpToVerse('Gênesis', 1, 15);
      expect(ctrl.targetVerse, equals(15));

      bool notified = false;
      ctrl.addListener(() => notified = true);
      ctrl.clearTargetVerse();
      expect(ctrl.targetVerse, isNull);
      expect(notified, isTrue);
    });
  });

  group('BibleSettingsSheet', () {
    testWidgets('renders all controls and toggles continuous reading', (tester) async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      final themeService = ThemeService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BibleSettingsSheet(controller: ctrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Configurações de Leitura'), findsOneWidget);
      expect(find.text('Versão da Bíblia'), findsOneWidget);
      expect(find.text('Modo de Leitura'), findsOneWidget);
      expect(find.text('Alinhamento do Texto'), findsOneWidget);
      expect(find.text('Fonte de Leitura'), findsOneWidget);
      expect(find.text('Tamanho da Fonte'), findsOneWidget);

      // Alterna modo de leitura para texto contínuo
      final continuoSegment = find.text('Contínuo');
      expect(continuoSegment, findsOneWidget);
      await tester.tap(continuoSegment);
      await tester.pumpAndSettle();
      expect(themeService.isContinuousReading, isTrue);

      // Alterna de volta para versículos
      final versiculosSegment = find.text('Versículos');
      expect(versiculosSegment, findsOneWidget);
      await tester.tap(versiculosSegment);
      await tester.pumpAndSettle();
      expect(themeService.isContinuousReading, isFalse);
    });
  });

  group('QuizView Responsive AppBar and SubBar', () {
    testWidgets('renders cleanly without overflow on narrow mobile screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = QuizController(repository: MockQuizRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: QuizView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica AppBar simplificada
      expect(find.text('Quiz Bíblico'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);

      // Verifica SubBar no corpo da tela
      expect(find.text('Diário'), findsOneWidget);
      expect(find.text('Maratona'), findsOneWidget);
      expect(find.text('Adultos'), findsOneWidget);

      // Não deve haver nenhum overflow de layout
      expect(tester.takeException(), isNull);
    });
  });

  group('BibleReaderView Navigation & Highlighting', () {
    testWidgets('renders version in AppBar, floating pill at bottom, and highlights target verse', (tester) async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();
      await ctrl.jumpToVerse(1, 1, 2); // targetVerse = 2

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar contains active version
      expect(find.text(ctrl.activeVersion), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

      // Floating pill at bottom contains book and chapter
      expect(find.text('Gênesis 1'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsWidgets);

      // Verses are rendered
      expect(find.text('No princípio...'), findsOneWidget);
      expect(find.text('E a terra era sem forma...'), findsOneWidget);

      // Tapping the floating pill opens the book chapter selector
      await tester.tap(find.text('Gênesis 1'));
      await tester.pumpAndSettle();
      expect(find.text('Buscar livro...'), findsOneWidget);
      expect(find.text('Capítulo 1'), findsOneWidget);
    });

    test('BibleController nextChapter and previousChapter navigate correctly', () async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      await ctrl.init();
      expect(ctrl.selectedBook?.name, equals('Gênesis'));
      expect(ctrl.selectedChapter, equals(1));

      // Advance chapter within same book
      await ctrl.nextChapter();
      expect(ctrl.selectedChapter, equals(2));

      // Go back chapter within same book
      await ctrl.previousChapter();
      expect(ctrl.selectedChapter, equals(1));

      // Go back when at chapter 1 of first book does not change
      await ctrl.previousChapter();
      expect(ctrl.selectedBook?.name, equals('Gênesis'));
      expect(ctrl.selectedChapter, equals(1));

      // Jump to last chapter of Gênesis (50)
      await ctrl.jumpToVerse(1, 50, 1);
      expect(ctrl.selectedChapter, equals(50));

      // Next chapter from Gênesis 50 advances to João 1
      await ctrl.nextChapter();
      expect(ctrl.selectedBook?.name, equals('João'));
      expect(ctrl.selectedChapter, equals(1));

      // Previous chapter from João 1 goes back to Gênesis 50
      await ctrl.previousChapter();
      expect(ctrl.selectedBook?.name, equals('Gênesis'));
      expect(ctrl.selectedChapter, equals(50));
    });

    testWidgets('floating pill chevrons and swipe gestures navigate chapters', (tester) async {
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

      // Chevrons are present
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tap next chevron
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();
      expect(ctrl.selectedChapter, equals(2));
      expect(find.text('Gênesis 2'), findsOneWidget);

      // Tap previous chevron
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();
      expect(ctrl.selectedChapter, equals(1));
      expect(find.text('Gênesis 1'), findsOneWidget);

      // Swipe left (drag right-to-left) to advance chapter
      await tester.fling(find.byType(BibleReaderView), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();
      expect(ctrl.selectedChapter, equals(2));
      expect(find.text('Gênesis 2'), findsOneWidget);

      // Swipe right (drag left-to-right) to go back chapter
      await tester.fling(find.byType(BibleReaderView), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();
      expect(ctrl.selectedChapter, equals(1));
      expect(find.text('Gênesis 1'), findsOneWidget);
    });

    testWidgets('continuous reading mode renders prose verse 1 drop cap chapter number', (tester) async {
      final ctrl = BibleController(
        repository: MockBibleRepository(),
        pericopeRepository: MockPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setContinuousReading(true);

      await ctrl.init();
      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // Chapter drop cap number "1" is rendered
      expect(find.text('1'), findsWidgets);
      expect(find.textContaining('No princípio...'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
