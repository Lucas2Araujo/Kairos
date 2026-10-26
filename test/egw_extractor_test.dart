import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/utils/egw_extractor.dart';
import 'package:kairos_web/views/lesson/widgets/egw_citation_sheet.dart';

void main() {
  group('EgwExtractor Tests', () {
    test('extracts standard citation with author, book, edition and page', () {
      const text =
          '“Por meio da mesma fé, podemos receber cura espiritual.” (Ef 2:1; Ellen G. White, O Desejado de Todas as Nações [CPB, 2021], p. 152, 153)';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, 1);
      final c = citations.first;
      expect(c.bookTitle, 'O Desejado de Todas as Nações');
      expect(c.bookId, '1813');
      expect(c.details, 'p. 152, 153');
      expect(c.quote, '“Por meio da mesma fé, podemos receber cura espiritual.”');
      expect(c.webUrl, 'https://m.egwwritings.org/pt/book/1813.0');
      expect(c.coverUrl, 'https://media4.egwwritings.org/covers/1813_s.jpg');
    });

    test('extracts short citation with only book and page', () {
      const text =
          '“Jesus rejeitou a acusação de blasfêmia.” (O Desejado de Todas as Nações, p. 157)';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, 1);
      final c = citations.first;
      expect(c.bookTitle, 'O Desejado de Todas as Nações');
      expect(c.bookId, '1813');
      expect(c.details, 'p. 157');
      expect(c.quote, '“Jesus rejeitou a acusação de blasfêmia.”');
    });

    test('extracts citation with HTML tags around book title', () {
      const text =
          'Texto de apoio (Ellen G. White, <em>O Desejado de Todas as Nações</em> [CPB, 2021], p. 194)';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, 1);
      final c = citations.first;
      expect(c.bookTitle, 'O Desejado de Todas as Nações');
      expect(c.bookId, '1813');
      expect(c.details, 'p. 194');
    });

    test('extracts citation with chapter notation and other books', () {
      const text = 'Estudo avançado (Patriarcas e Profetas, cap. 12)';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, 1);
      final c = citations.first;
      expect(c.bookTitle, 'Patriarcas e Profetas');
      expect(c.bookId, '1815');
      expect(c.details, 'cap. 12');
    });

    test('splits text into plain segments and citations correctly', () {
      const text =
          'Início da frase “Citação” (Caminho a Cristo, p. 15) final da frase.';
      final segments = EgwExtractor.splitTextByEgwCitations(text);

      expect(segments.length, 3);
      expect(segments[0].isCitation, false);
      expect(segments[0].text, 'Início da frase “Citação” (');
      expect(segments[1].isCitation, true);
      expect(segments[1].citation?.bookTitle, 'Caminho a Cristo');
      expect(segments[1].citation?.bookId, '11121');
      expect(segments[2].isCitation, false);
      expect(segments[2].text, ') final da frase.');
    });

    testWidgets('EgwCitationSheet renders book details and action buttons', (tester) async {
      const citation = EgwCitation(
        bookTitle: 'O Desejado de Todas as Nações',
        bookId: '1813',
        details: 'p. 152, 153',
        quote: '“Por meio da mesma fé, podemos receber cura espiritual.”',
        rawText: '(Ellen G. White, O Desejado de Todas as Nações [CPB, 2021], p. 152, 153)',
        startIndex: 0,
        endIndex: 70,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EgwCitationSheet(citation: citation),
          ),
        ),
      );

      expect(find.text('Espírito de Profecia'), findsOneWidget);
      expect(find.text('O Desejado de Todas as Nações'), findsOneWidget);
      expect(find.text('Ellen G. White • p. 152, 153'), findsOneWidget);
      expect(find.text('“Por meio da mesma fé, podemos receber cura espiritual.”'), findsOneWidget);
      expect(find.text('Ler no EGW Writings'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
    });
  });
}
