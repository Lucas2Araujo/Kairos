import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/core/config/app_config.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/services/content_manager.dart';
import 'package:kairos_web/views/bible/widgets/book_chapter_selector_sheet.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

class _FakeBibleController extends BibleController {
  final List<BibleBook> _mockBooks;
  _FakeBibleController(this._mockBooks);

  @override
  List<BibleBook> get books => _mockBooks;

  @override
  BibleBook? get selectedBook => _mockBooks.firstOrNull;
}

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

  group('BibleRepository.resolveBookIdByAlias', () {
    test('resolves deuterocanonical apocrypha books and Enoch', () {
      expect(BibleRepository.resolveBookIdByAlias('1 Macabeus'), 72);
      expect(BibleRepository.resolveBookIdByAlias('I Macabeus'), 72);
      expect(BibleRepository.resolveBookIdByAlias('1º Macabeus'), 72);
      expect(BibleRepository.resolveBookIdByAlias('1 mc'), 72);
      expect(BibleRepository.resolveBookIdByAlias('1mc'), 72);
      expect(BibleRepository.resolveBookIdByAlias('2 Macabeus'), 73);
      expect(BibleRepository.resolveBookIdByAlias('II Macabeus'), 73);
      expect(BibleRepository.resolveBookIdByAlias('2º Macabeus'), 73);
      expect(BibleRepository.resolveBookIdByAlias('2 mc'), 73);
      expect(BibleRepository.resolveBookIdByAlias('2mc'), 73);
      expect(BibleRepository.resolveBookIdByAlias('Sabedoria'), 69);
      expect(BibleRepository.resolveBookIdByAlias('Eclesiástico'), 70);
      expect(BibleRepository.resolveBookIdByAlias('Sirácida'), 70);
      expect(BibleRepository.resolveBookIdByAlias('Tobias'), 67);
      expect(BibleRepository.resolveBookIdByAlias('Judite'), 68);
      expect(BibleRepository.resolveBookIdByAlias('Baruc'), 71);
      expect(BibleRepository.resolveBookIdByAlias('Baruque'), 71);
      expect(BibleRepository.resolveBookIdByAlias('1 Enoque'), 74);
      expect(BibleRepository.resolveBookIdByAlias('Enoque'), 74);
      expect(BibleRepository.resolveBookIdByAlias('Livro de Enoque'), 74);
    });

    test('normalizes Roman numerals and diacritics for canonical books', () {
      expect(BibleRepository.resolveBookIdByAlias('I Samuel'), 9);
      expect(BibleRepository.resolveBookIdByAlias('II Samuel'), 10);
      expect(BibleRepository.resolveBookIdByAlias('I Reis'), 11);
      expect(BibleRepository.resolveBookIdByAlias('II Reis'), 12);
      expect(BibleRepository.resolveBookIdByAlias('I Crônicas'), 13);
      expect(BibleRepository.resolveBookIdByAlias('II Crônicas'), 14);
      expect(BibleRepository.resolveBookIdByAlias('I Coríntios'), 46);
      expect(BibleRepository.resolveBookIdByAlias('II Coríntios'), 47);
      expect(BibleRepository.resolveBookIdByAlias('I Tessalonicenses'), 52);
      expect(BibleRepository.resolveBookIdByAlias('II Tessalonicenses'), 53);
      expect(BibleRepository.resolveBookIdByAlias('I Timóteo'), 54);
      expect(BibleRepository.resolveBookIdByAlias('II Timóteo'), 55);
      expect(BibleRepository.resolveBookIdByAlias('I Pedro'), 60);
      expect(BibleRepository.resolveBookIdByAlias('II Pedro'), 61);
      expect(BibleRepository.resolveBookIdByAlias('1 pe'), 60);
      expect(BibleRepository.resolveBookIdByAlias('1jo'), 62);
      expect(BibleRepository.resolveBookIdByAlias('1 jo'), 62);
      expect(BibleRepository.resolveBookIdByAlias('I João'), 62);
      expect(BibleRepository.resolveBookIdByAlias('II João'), 63);
      expect(BibleRepository.resolveBookIdByAlias('III João'), 64);
      expect(BibleRepository.resolveBookIdByAlias('Gênesis'), 1);
      expect(BibleRepository.resolveBookIdByAlias('Apocalipse'), 66);
    });

    test('disambiguates Jó (18) and Jo (43)', () {
      expect(BibleRepository.resolveBookIdByAlias('Jó'), 18);
      expect(BibleRepository.resolveBookIdByAlias('jó'), 18);
      expect(BibleRepository.resolveBookIdByAlias('Jo'), 43);
      expect(BibleRepository.resolveBookIdByAlias('jo'), 43);
      expect(BibleRepository.resolveBookIdByAlias('João'), 43);
    });

    test('maintains backwards compatibility with resolveBookId', () {
      expect(BibleRepository.resolveBookId('1 Macabeus'), 72);
      expect(BibleRepository.resolveBookId('Livro de Enoque'), 74);
      expect(BibleRepository.resolveBookId('Jo 3:16'), isNull);
    });

    test('dynamic resolution in Catholic DB maps spaced aliases to actual Catholic IDs', () async {
      final db = sqlite3.openInMemory();
      try {
        db.execute('''
          CREATE TABLE book (id INTEGER PRIMARY KEY, name TEXT NOT NULL, testament_reference_id INTEGER NOT NULL);
        ''');
        // In Catholic AVM order: 1 Macabeus is id 20, Judas is id 72, Apocalipse is id 73, Enoque is id 99
        // Also Jó is id 22, João is id 50
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (20, '1 Macabeus', 1)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (21, '2 Macabeus', 1)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (22, 'Jó', 1)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (50, 'João', 2)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (69, '1 João', 2)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (72, 'Judas', 2)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (73, 'Apocalipse', 2)");
        db.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (99, 'Livro de Enoque', 3)");

        final repo = BibleRepository();
        // Should resolve to Catholic ID 20, NOT protestant fallback 72 (Judas)!
        expect(await repo.resolveBookIdInDb(db, '1 mc'), 20);
        expect(await repo.resolveBookIdInDb(db, '1mc'), 20);
        expect(await repo.resolveBookIdInDb(db, 'i macabeus'), 20);
        expect(await repo.resolveBookIdInDb(db, '2 mc'), 21);
        expect(await repo.resolveBookIdInDb(db, '1 jo'), 69);
        expect(await repo.resolveBookIdInDb(db, 'judas'), 72);
        expect(await repo.resolveBookIdInDb(db, 'apocalipse'), 73);
        expect(await repo.resolveBookIdInDb(db, 'enoque'), 99);
        expect(await repo.resolveBookIdInDb(db, '1 enoque'), 99);

        // Disambiguation between Jó (22) and Jo (50) in Catholic DB
        expect(await repo.resolveBookIdInDb(db, 'Jo'), 50);
        expect(await repo.resolveBookIdInDb(db, 'jo'), 50);
        expect(await repo.resolveBookIdInDb(db, 'Jó'), 22);
        expect(await repo.resolveBookIdInDb(db, 'jó'), 22);
      } finally {
        db.dispose();
      }
    });
  });

  group('BookChapterSelectorSheet.matchesFilter', () {
    const enoch99 = BibleBook(
      id: 99,
      name: 'Livro de Enoque',
      testament: 'AP',
      chaptersCount: 108,
    );
    const enoch74 = BibleBook(
      id: 74,
      name: '1 Enoque',
      testament: 'AP',
      chaptersCount: 108,
    );
    const macabeus23 = BibleBook(
      id: 23,
      name: 'I Macabeus',
      testament: 'VT',
      chaptersCount: 16,
    );
    const romanos45 = BibleBook(
      id: 45,
      name: 'Romanos',
      testament: 'NT',
      chaptersCount: 16,
    );
    const eclesiastico70 = BibleBook(
      id: 70,
      name: 'Eclesiástico',
      testament: 'AP',
      chaptersCount: 51,
    );
    const genesis1 = BibleBook(
      id: 1,
      name: 'Gênesis',
      testament: 'VT',
      chaptersCount: 50,
    );
    // Catholic AVM NT books with id > 66
    const pedro67 = BibleBook(
      id: 67,
      name: '1 Pedro',
      testament: 'NT',
      chaptersCount: 5,
    );
    const apocalipse73 = BibleBook(
      id: 73,
      name: 'Apocalipse',
      testament: 'NT',
      chaptersCount: 22,
    );

    test('properly classifies Catholic NT books with id > 66 as canonical NT and not apocrypha', () {
      // 1 Pedro (id 67 in AVM NT)
      expect(BookChapterSelectorSheet.isApocryphalBook(pedro67), isFalse);
      expect(
        BookChapterSelectorSheet.matchesFilter(book: pedro67, filter: 'NT', query: ''),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: pedro67, filter: 'AP', query: ''),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: pedro67, filter: 'VT', query: ''),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: pedro67, filter: 'TODOS', query: ''),
        isTrue,
      );

      // Apocalipse (id 73 in AVM NT)
      expect(BookChapterSelectorSheet.isApocryphalBook(apocalipse73), isFalse);
      expect(
        BookChapterSelectorSheet.matchesFilter(book: apocalipse73, filter: 'NT', query: ''),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: apocalipse73, filter: 'AP', query: ''),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: apocalipse73, filter: 'VT', query: ''),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(book: apocalipse73, filter: 'TODOS', query: ''),
        isTrue,
      );
    });

    test('hides Enoch in TODOS when query is empty, but shows in search', () {
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch99,
          filter: 'TODOS',
          query: '',
        ),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch74,
          filter: 'TODOS',
          query: '   ',
        ),
        isFalse,
      );

      // Active search query in TODOS finds Enoch
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch99,
          filter: 'TODOS',
          query: 'enoque',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch74,
          filter: 'TODOS',
          query: '1 enoque',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch99,
          filter: 'TODOS',
          query: 'livro de enoque',
        ),
        isTrue,
      );
    });

    test('AP filter includes all apocrypha books and Enoch', () {
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch99,
          filter: 'AP',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch74,
          filter: 'AP',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: macabeus23,
          filter: 'AP',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: eclesiastico70,
          filter: 'AP',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: romanos45,
          filter: 'AP',
          query: '',
        ),
        isFalse,
      );
    });

    test('VT and NT filters exclude apocrypha and include canonical books', () {
      // VT
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: genesis1,
          filter: 'VT',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: macabeus23,
          filter: 'VT',
          query: '',
        ),
        isFalse,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: enoch99,
          filter: 'VT',
          query: '',
        ),
        isFalse,
      );

      // NT
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: romanos45,
          filter: 'NT',
          query: '',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: macabeus23,
          filter: 'NT',
          query: '',
        ),
        isFalse,
      );
    });

    test('matches query with diacritic and Roman numeral normalization', () {
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: macabeus23,
          filter: 'TODOS',
          query: '1 macabeus',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: macabeus23,
          filter: 'TODOS',
          query: 'i macabeus',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: eclesiastico70,
          filter: 'TODOS',
          query: 'eclesiastico',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: eclesiastico70,
          filter: 'TODOS',
          query: 'siracida',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: romanos45,
          filter: 'TODOS',
          query: 'rom',
        ),
        isTrue,
      );
      expect(
        BookChapterSelectorSheet.matchesFilter(
          book: romanos45,
          filter: 'TODOS',
          query: 'mateus',
        ),
        isFalse,
      );
    });
  });

  group('BookChapterSelectorSheet Widget Tests', () {
    testWidgets('shows "Nenhum livro encontrado." when AP is selected and search yields no results with apocrypha installed', (tester) async {
      final controller = _FakeBibleController([
        const BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
        const BibleBook(id: 20, name: '1 Macabeus', testament: 'VT', chaptersCount: 16),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookChapterSelectorSheet(controller: controller),
          ),
        ),
      );

      // Select 'Apócrifos' ChoiceChip
      await tester.tap(find.text('Apócrifos'));
      await tester.pumpAndSettle();

      // 1 Macabeus should be visible
      expect(find.text('1 Macabeus'), findsOneWidget);

      // Enter search query that doesn't match
      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pumpAndSettle();

      // Should render 'Nenhum livro encontrado.' and NOT 'Baixar Bíblia Ave Maria (AVM)'
      expect(find.text('Nenhum livro encontrado.'), findsOneWidget);
      expect(find.text('Baixar Bíblia Ave Maria (AVM)'), findsNothing);
    });

    testWidgets('shows "Baixar Bíblia Ave Maria (AVM)" when AP is selected and no apocrypha books exist', (tester) async {
      final controller = _FakeBibleController([
        const BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
        const BibleBook(id: 40, name: 'Mateus', testament: 'NT', chaptersCount: 28),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookChapterSelectorSheet(controller: controller),
          ),
        ),
      );

      // Select 'Apócrifos' ChoiceChip
      await tester.tap(find.text('Apócrifos'));
      await tester.pumpAndSettle();

      // Should render download CTA
      expect(find.text('Baixar Bíblia Ave Maria (AVM)'), findsOneWidget);
    });
  });

  group('ContentManager Web/IO fallback URLs', () {
    test('buildFallbackUrls puts R2 first on Web and rawUrl first on IO', () {
      const file = 'AVM.sqlite.gz';
      const rawUrl = 'https://downloads.hinario.app/biblias/AVM.sqlite.gz';
      final expectedR2 = '${AppConfig.r2AudioBaseUrl}/biblias/$file';

      final webUrls = ContentManager.buildFallbackUrls(
        file: file,
        rawUrl: rawUrl,
        isWeb: true,
      );
      expect(webUrls.first, expectedR2);
      expect(webUrls, contains(rawUrl));
      expect(webUrls.length, 2);

      final ioUrls = ContentManager.buildFallbackUrls(
        file: file,
        rawUrl: rawUrl,
        isWeb: false,
      );
      expect(ioUrls.first, rawUrl);
      expect(ioUrls, contains(expectedR2));
      expect(ioUrls.length, 2);
    });

    test('buildFallbackUrls deduplicates identical URLs', () {
      const file = 'ARA.sqlite.gz';
      final r2Url = '${AppConfig.r2AudioBaseUrl}/biblias/$file';

      final urls = ContentManager.buildFallbackUrls(
        file: file,
        rawUrl: r2Url,
        isWeb: true,
      );
      expect(urls.length, 1);
      expect(urls.first, r2Url);
    });

    test('BibleModuleInfo holds immutable fallbackUrls', () {
      final module = BibleModuleInfo(
        id: 'AVM',
        name: 'Bíblia Ave Maria',
        file: 'AVM.sqlite.gz',
        sizeBytes: 1000,
        url: 'https://primary.example.com',
        fallbackUrls: const ['https://primary.example.com', 'https://secondary.example.com'],
      );

      expect(module.fallbackUrls.length, 2);
      expect(module.fallbackUrls.first, 'https://primary.example.com');
      expect(module.fallbackUrls.last, 'https://secondary.example.com');
      expect(() => module.fallbackUrls.add('https://third.example.com'), throwsUnsupportedError);
    });
  });
}
