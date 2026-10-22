import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/data/repositories/pericope_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/bible/bible_reader_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPoeticBibleRepository extends BibleRepository {
  @override
  Future<List<BibleBook>> getBooks() async {
    return const [
      BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
      BibleBook(id: 18, name: 'Jó', testament: 'VT', chaptersCount: 42),
      BibleBook(id: 19, name: 'Salmos', testament: 'VT', chaptersCount: 150),
      BibleBook(id: 20, name: 'Provérbios', testament: 'VT', chaptersCount: 31),
      BibleBook(id: 21, name: 'Eclesiastes', testament: 'VT', chaptersCount: 12),
      BibleBook(id: 22, name: 'Cânticos', testament: 'VT', chaptersCount: 8),
      BibleBook(id: 25, name: 'Lamentações', testament: 'VT', chaptersCount: 5),
    ];
  }

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String bookName = ''}) async {
    if (bookId == 19 && chapter == 23) {
      return [
        const BibleVerse(
          id: 1,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 23,
          verse: 1,
          text: 'O SENHOR é o meu pastor; nada me faltará.',
        ),
        const BibleVerse(
          id: 2,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 23,
          verse: 2,
          text: 'Deitar-me faz em verdes pastos, guia-me mansamente a águas tranqüilas.',
        ),
        const BibleVerse(
          id: 3,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 23,
          verse: 3,
          text: 'Refrigera a minha alma; guia-me pelas veredas da justiça, por amor do seu nome.',
        ),
        const BibleVerse(
          id: 4,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 23,
          verse: 4,
          text: 'Ainda que eu andasse pelo vale da sombra da morte, não temeria mal algum, porque tu estás comigo; a tua vara e o teu cajado me consolam.',
        ),
      ];
    }

    if (bookId == 19 && chapter == 115) {
      return [
        const BibleVerse(
          id: 10,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 115,
          verse: 1,
          text: 'Não a nós, SENHOR, não a nós, mas ao teu nome dá glória, por amor da tua misericórdia e da tua fidelidade.',
        ),
        const BibleVerse(
          id: 11,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 115,
          verse: 2,
          text: 'Por que diriam as nações: Onde está o Deus deles?',
        ),
        const BibleVerse(
          id: 12,
          bookId: 19,
          bookName: 'Salmos',
          chapter: 115,
          verse: 5,
          text: 'Têm boca e não falam; têm olhos e não veem;',
        ),
      ];
    }

    // Default prose book (Gênesis)
    return [
      BibleVerse(
        id: 100,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Gênesis',
        chapter: chapter,
        verse: 1,
        text: 'No princípio, criou Deus os céus e a terra.',
      ),
      BibleVerse(
        id: 101,
        bookId: bookId,
        bookName: bookName.isNotEmpty ? bookName : 'Gênesis',
        chapter: chapter,
        verse: 2,
        text: 'A terra, porém, estava sem forma e vazia.',
      ),
    ];
  }

  @override
  Future<Map<int, String>> getChapterHighlights(int bookId, int chapter) async => {};
}

class MockPoeticPericopeRepository extends PericopeRepository {
  @override
  Future<List<Pericope>> getPericopes(int bookId, int chapter) async {
    if (bookId == 19 && chapter == 23) {
      return [
        const Pericope(id: 1, bookId: 19, chapter: 23, verse: 1, title: 'O Bom Pastor'),
      ];
    }
    return [];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Poetic Books Configuration & Stich Parsing', () {
    test('isPoeticBook identifies poetic books correctly', () {
      expect(BibleReaderView.isPoeticBook(18), isTrue); // Jó
      expect(BibleReaderView.isPoeticBook(19), isTrue); // Salmos
      expect(BibleReaderView.isPoeticBook(20), isTrue); // Provérbios
      expect(BibleReaderView.isPoeticBook(21), isTrue); // Eclesiastes
      expect(BibleReaderView.isPoeticBook(22), isTrue); // Cânticos
      expect(BibleReaderView.isPoeticBook(25), isTrue); // Lamentações

      expect(BibleReaderView.isPoeticBook(1), isFalse); // Gênesis
      expect(BibleReaderView.isPoeticBook(40), isFalse); // Mateus
      expect(BibleReaderView.isPoeticBook(43), isFalse); // João
      expect(BibleReaderView.isPoeticBook(null), isFalse);
    });

    test('parsePoeticLines splits Psalm 23:1 at semicolon with indentation on second hemistich', () {
      final lines = BibleReaderView.parsePoeticLines('O SENHOR é o meu pastor; nada me faltará.');
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('O SENHOR é o meu pastor;'));
      expect(lines[0].isIndent, isFalse);
      expect(lines[0].indent, equals(0.0));

      expect(lines[1].text, equals('nada me faltará.'));
      expect(lines[1].isIndent, isTrue);
      expect(lines[1].indent, equals(16.0));
    });

    test('parsePoeticLines splits Psalm 23:4 with conjunctions and semicolons', () {
      const text =
          'Ainda que eu andasse pelo vale da sombra da morte, não temeria mal algum, porque tu estás comigo; a tua vara e o teu cajado me consolam.';
      final lines = BibleReaderView.parsePoeticLines(text);
      expect(lines.length, equals(3));
      expect(lines[0].text, equals('Ainda que eu andasse pelo vale da sombra da morte, não temeria mal algum,'));
      expect(lines[0].isIndent, isFalse);

      expect(lines[1].text, equals('porque tu estás comigo;'));
      expect(lines[1].isIndent, isTrue);

      expect(lines[2].text, equals('a tua vara e o teu cajado me consolam.'));
      expect(lines[2].isIndent, isTrue);
    });

    test('parsePoeticLines splits Psalm 115:1 before "mas"', () {
      const text =
          'Não a nós, SENHOR, não a nós, mas ao teu nome dá glória, por amor da tua misericórdia e da tua fidelidade.';
      final lines = BibleReaderView.parsePoeticLines(text);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Não a nós, SENHOR, não a nós,'));
      expect(lines[0].isIndent, isFalse);

      expect(lines[1].text, equals('mas ao teu nome dá glória, por amor da tua misericórdia e da tua fidelidade.'));
      expect(lines[1].isIndent, isTrue);
    });

    test('parsePoeticLines splits Psalm 115:2 after colon', () {
      const text = 'Por que diriam as nações: Onde está o Deus deles?';
      final lines = BibleReaderView.parsePoeticLines(text);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Por que diriam as nações:'));
      expect(lines[1].text, equals('Onde está o Deus deles?'));
    });

    test('parsePoeticLines splits Psalm 115:5 after semicolon without trailing empty line', () {
      const text = 'Têm boca e não falam; têm olhos e não veem;';
      final lines = BibleReaderView.parsePoeticLines(text);
      expect(lines.length, equals(2));
      expect(lines[0].text, equals('Têm boca e não falam;'));
      expect(lines[1].text, equals('têm olhos e não veem;'));
    });

    test('parsePoeticLines handles pre-existing newline characters', () {
      const text = 'Primeira linha\nSegunda linha\nTerceira linha';
      final lines = BibleReaderView.parsePoeticLines(text);
      expect(lines.length, equals(3));
      expect(lines[0].isIndent, isFalse);
      expect(lines[1].isIndent, isTrue);
      expect(lines[2].isIndent, isTrue);
    });
  });

  group('Poetic Books Widget Rendering', () {
    testWidgets('renders Psalm 23 in Continuous Reading mode with Drop Cap and no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = BibleController(
        repository: MockPoeticBibleRepository(),
        pericopeRepository: MockPoeticPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setContinuousReading(true);

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      await ctrl.jumpToVerse(19, 23, 1);
      await tester.pumpAndSettle();

      // Pericope title is rendered
      expect(find.text('O Bom Pastor'), findsOneWidget);

      // Verse 1 Drop Cap "23" is rendered
      expect(find.text('23'), findsWidgets);
      expect(find.text('O SENHOR é o meu pastor;'), findsOneWidget);
      expect(find.text('nada me faltará.'), findsOneWidget);

      // Verse 2 badge "2" is rendered
      expect(find.text('2'), findsWidgets);

      // Tap verse 1 to toggle selection
      await tester.tap(find.text('O SENHOR é o meu pastor;'));
      await tester.pumpAndSettle();

      // Selection action sheet appears with "Copiar" and "Estudo"
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Estudo'), findsOneWidget);

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Psalm 23 in Verse List mode with stichic indentation and no overflow', (tester) async {
      final ctrl = BibleController(
        repository: MockPoeticBibleRepository(),
        pericopeRepository: MockPoeticPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setContinuousReading(false);

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      await ctrl.jumpToVerse(19, 23, 1);
      await tester.pumpAndSettle();

      // Stichs are rendered
      expect(find.text('O SENHOR é o meu pastor;'), findsOneWidget);
      expect(find.text('nada me faltará.'), findsOneWidget);

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders Psalm 115 in Continuous Reading mode cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = BibleController(
        repository: MockPoeticBibleRepository(),
        pericopeRepository: MockPoeticPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setContinuousReading(true);

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      await ctrl.jumpToVerse(19, 115, 1);
      await tester.pumpAndSettle();

      // Drop Cap "115"
      expect(find.text('115'), findsWidgets);
      expect(find.text('Não a nós, SENHOR, não a nós,'), findsOneWidget);
      expect(find.text('mas ao teu nome dá glória, por amor da tua misericórdia e da tua fidelidade.'), findsOneWidget);

      // Verify no overflow exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('prose book (Genesis) uses standard continuous reading without poetic drop cap', (tester) async {
      final ctrl = BibleController(
        repository: MockPoeticBibleRepository(),
        pericopeRepository: MockPoeticPericopeRepository(),
      );
      final themeService = ThemeService();
      themeService.setContinuousReading(true);

      await ctrl.init();
      await ctrl.jumpToVerse('Gênesis', 1, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: BibleReaderView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      // Continuous prose text span rendered
      expect(find.textContaining('No princípio, criou Deus os céus e a terra.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
