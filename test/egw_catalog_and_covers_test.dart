import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/egw_models.dart';
import 'package:kairos_web/services/egw_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/egw/widgets/egw_book_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EgwService - Catálogo Completo PT (~79 obras)', () {
    test('defaultCatalog deve conter exatamente 79 obras únicas sem duplicatas de ID ou título', () {
      const catalog = EgwService.defaultCatalog;
      expect(catalog.length, equals(79));

      final ids = <String>{};
      final titles = <String>{};

      for (final item in catalog) {
        final id = item['id'];
        final title = item['title'];
        final abbr = item['abbr'];
        final desc = item['desc'];

        expect(id, isNotNull);
        expect(id!.isNotEmpty, isTrue);
        expect(title, isNotNull);
        expect(title!.isNotEmpty, isTrue);
        expect(abbr, isNotNull);
        expect(abbr!.isNotEmpty, isTrue);
        expect(desc, isNotNull);

        expect(ids.add(id), isTrue, reason: 'ID duplicado no catálogo: $id ($title)');
        expect(titles.add(title.toLowerCase()), isTrue, reason: 'Título duplicado no catálogo: $title');
      }
    });

    test('deve conter obras chave pré-verificadas e novos volumes em português', () {
      const catalog = EgwService.defaultCatalog;
      final titles = catalog.map((e) => e['title']!).toSet();

      // Pré-verificados
      expect(titles, contains('Patriarcas e Profetas'));
      expect(titles, contains('O Grande Conflito'));
      expect(titles, contains('O Desejado de Todas as Nações'));
      expect(titles, contains('Vida de Jesus'));
      expect(titles, contains('Testemunhos para a Igreja, vol. 1'));
      expect(titles, contains('Testemunhos para a Igreja, vol. 9'));

      // Novos volumes adicionados
      expect(titles, contains('As Mensagens dos Três Anjos'));
      expect(titles, contains('Conselhos para a Igreja'));
      expect(titles, contains('Mente, Caráter e Personalidade, vol. 1'));
      expect(titles, contains('Mente, Caráter e Personalidade, vol. 2'));
      expect(titles, contains('Testemunhos Seletos, vol. 1'));
      expect(titles, contains('Testemunhos Seletos, vol. 2'));
      expect(titles, contains('Testemunhos Seletos, vol. 3'));
      expect(titles, contains('Santificação'));
      expect(titles, contains('Temperança'));
    });

    test('extractNumericBookIdFromHtml extrai corretamente IDs numéricos de HTML de busca', () {
      const sampleHtml = '''
        <div class="result-item">
          <a href="/pt/book/1816.0" class="book-title">Profetas e Reis</a>
          <p>História do Antigo Testamento</p>
        </div>
      ''';
      final extracted = EgwService.extractNumericBookIdFromHtml(sampleHtml);
      expect(extracted, equals('1816'));

      const fallbackHtml = '''
        <li class="item"><a href="/pt/book/11125/toc">O Grande Conflito</a></li>
      ''';
      expect(EgwService.extractNumericBookIdFromHtml(fallbackHtml), equals('11125'));

      const emptyHtml = '<div>Nenhum resultado encontrado</div>';
      expect(EgwService.extractNumericBookIdFromHtml(emptyHtml), isNull);
    });

    test('EgwBook lida com ID numérico e não-numérico sem gerar URLs 404', () {
      final numericBook = EgwBook(
        id: '1815',
        title: 'Patriarcas e Profetas',
        abbreviation: 'PP',
      );
      expect(numericBook.coverUrl, equals('https://media4.egwwritings.org/covers/1815_r.jpg'));

      final slugBook = EgwBook(
        id: 'pt_mensagens_tres_anjos',
        title: 'As Mensagens dos Três Anjos',
        abbreviation: 'MTA',
      );
      expect(slugBook.coverUrl, isEmpty);

      final resolvedSlugBook = EgwBook(
        id: 'pt_mensagens_tres_anjos',
        title: 'As Mensagens dos Três Anjos',
        abbreviation: 'MTA',
        resolvedId: '13500',
      );
      expect(resolvedSlugBook.coverUrl, equals('https://media4.egwwritings.org/covers/13500_r.jpg'));
    });
  });

  group('EgwCpbCoverPainter - Monograma & Paleta de Cores', () {
    test('extractMonogram extrai 2 letras maiúsculas consistentes', () {
      expect(EgwCpbCoverPainter.extractMonogram('O Grande Conflito'), equals('GC'));
      expect(EgwCpbCoverPainter.extractMonogram('Educação'), equals('ED'));
      expect(EgwCpbCoverPainter.extractMonogram('Patriarcas e Profetas'), equals('PP'));
      expect(EgwCpbCoverPainter.extractMonogram('Santificação'), equals('SA'));
      expect(EgwCpbCoverPainter.extractMonogram('Êxodo'), equals('EX'));
      expect(EgwCpbCoverPainter.extractMonogram('O Desejado de Todas as Nações', abbreviation: 'DTN'), equals('DT'));
      expect(EgwCpbCoverPainter.extractMonogram('Testemunhos para a Igreja, vol. 1', abbreviation: '1TI'), equals('TI'));
    });

    test('Cores estáticas oficiais CPB Light e Dark correspondem às referências', () {
      expect(EgwCpbCoverPainter.lightBackground, equals(const Color(0xFF8E8880)));
      expect(EgwCpbCoverPainter.lightAccent, equals(const Color(0xFF4D3D2E)));
      expect(EgwCpbCoverPainter.darkBackground, equals(const Color(0xFF58595B)));
      expect(EgwCpbCoverPainter.darkAccent, equals(const Color(0xFFC5A680)));
      expect(EgwCpbCoverPainter.neutralWhite, equals(const Color(0xFFF5F3EF)));
    });
  });

  group('ThemeService - egwUseModernCovers', () {
    test('alterna e persiste egwUseModernCovers notificando listeners', () async {
      SharedPreferences.setMockInitialValues({'egw_use_modern_covers': false});
      final service = ThemeService();
      await service.init();

      expect(service.egwUseModernCovers, isFalse);

      bool notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      await service.setEgwUseModernCovers(true);
      expect(service.egwUseModernCovers, isTrue);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('egw_use_modern_covers'), isTrue);

      service.removeListener(listener);
    });
  });

  group('EgwBookCover - Widget Tests', () {
    testWidgets('renderiza capa moderna CPB em modo Light e Dark sem overflow', (tester) async {
      final book = EgwBook(
        id: '11125',
        title: 'O Grande Conflito',
        abbreviation: 'GC',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: 200,
                child: EgwBookCover(
                  book: book,
                  useModernCover: true,
                  forceDark: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EgwBookCover), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Dark mode test
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: 200,
                child: EgwBookCover(
                  book: book,
                  useModernCover: true,
                  forceDark: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EgwBookCover), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renderiza livro com ID slug no modo clássico caindo para painter de fallback sem erro', (tester) async {
      final slugBook = EgwBook(
        id: 'pt_mensagens_tres_anjos',
        title: 'As Mensagens dos Três Anjos',
        abbreviation: 'MTA',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: 200,
                child: EgwBookCover(
                  book: slugBook,
                  useModernCover: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EgwBookCover), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renderiza capa moderna sem dimensões em container irrestrito sem lançar exceção', (tester) async {
      final book = EgwBook(
        id: '1948',
        title: 'Educação',
        abbreviation: 'ED',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnconstrainedBox(
              child: EgwBookCover(
                book: book,
                useModernCover: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EgwBookCover), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
