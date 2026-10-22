import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/utils/bible_extractor.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/views/bible/widgets/bible_verse_preview_modal.dart';

class TestMockBibleRepository extends BibleRepository {
  @override
  Future<List<BibleVerse>> buscarPassagem(String refText) async {
    final clean = BibleExtractor.cleanReference(refText);
    return [
      BibleVerse(
        id: clean.hashCode,
        bookId: 1,
        bookName: clean.split(' ').first,
        chapter: 1,
        verse: 1,
        text: 'Texto bíblico para a passagem: $clean',
      ),
    ];
  }
}

void main() {
  group('BibleExtractor Ponytail Requirements', () {
    test('1. Leia Mateus 16:13-16, Marcos 8:27-29, e Lucas 9:18-20 markdown grouping', () {
      const text =
          '1. Leia [Mateus 16:13-16](bible://Mateus%2016%3A13-16); [Marcos 8:27-29](bible://Marcos%208%3A27-29); [e Lucas 9:18-20](bible://e%20Lucas%209%3A18-20).';

      final expected = ['Mateus 16:13-16', 'Marcos 8:27-29', 'Lucas 9:18-20'];

      expect(BibleExtractor.getContiguousReferences(text, 'Mateus 16:13-16'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Marcos 8:27-29'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Lucas 9:18-20'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'e Lucas 9:18-20'), equals(expected));
    });

    test('prometido ([Mc 6:14, 15]... [Jo 6:14]... [7:40]...) markdown grouping for any query', () {
      const text =
          'prometido ([Mc 6:14, 15](bible://Mc%206%3A14%2C%2015); [Jo 6:14](bible://Jo%206%3A14); [7:40](bible://Jo%207%3A40)).';

      final expected = ['Mc 6:14, 15', 'Jo 6:14', 'Jo 7:40'];

      expect(BibleExtractor.getContiguousReferences(text, 'Mc 6:14, 15'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Jo 6:14'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Jo 7:40'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, '7:40'), equals(expected));
    });

    test('prometido (Mc 6:14, 15; Jo 6:14; 7:40). plain text inherits lastBook for 7:40', () {
      const text = 'prometido (Mc 6:14, 15; Jo 6:14; 7:40).';

      final expected = ['Mc 6:14, 15', 'Jo 6:14', 'Jo 7:40'];

      expect(BibleExtractor.getContiguousReferences(text, 'Mc 6:14, 15'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Jo 6:14'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Jo 7:40'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, '7:40'), equals(expected));
    });

    test('inherits lastBook for Romanos 12:1-2; 13:1-7', () {
      const text = 'Estudo em Romanos 12:1-2; 13:1-7 com a igreja.';

      final expected = ['Romanos 12:1-2', 'Romanos 13:1-7'];

      expect(BibleExtractor.getContiguousReferences(text, 'Romanos 12:1-2'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Romanos 13:1-7'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, '13:1-7'), equals(expected));
    });

    test('inherits lastBook for chained references with conjunction: Romanos 8:28; 12:1-2 e 14:10', () {
      const text = 'Romanos 8:28; 12:1-2 e 14:10';

      final expected = ['Romanos 8:28', 'Romanos 12:1-2', 'Romanos 14:10'];

      expect(BibleExtractor.getContiguousReferences(text, 'Romanos 8:28'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Romanos 12:1-2'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, '12:1-2'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, 'Romanos 14:10'), equals(expected));
      expect(BibleExtractor.getContiguousReferences(text, '14:10'), equals(expected));
    });

    test('does not inherit lastBook across sentence boundary', () {
      const text = 'Estude Jo 3:16. O horário da reunião é 7:40.';

      final refs = BibleExtractor.extractAllBibleRefs(text);
      expect(refs, equals(['Jo 3:16']));
    });

    test('cleanReference sanitizes surrounding brackets, quotes, and conjunctions', () {
      expect(BibleExtractor.cleanReference('[Mateus 16:13-16]'), equals('Mateus 16:13-16'));
      expect(BibleExtractor.cleanReference('(Mc 6:14, 15)'), equals('Mc 6:14, 15'));
      expect(BibleExtractor.cleanReference('e Lucas 9:18-20'), equals('Lucas 9:18-20'));
      expect(BibleExtractor.cleanReference('ou Romanos 12:1'), equals('Romanos 12:1'));
      expect(BibleExtractor.cleanReference('& Ef 2:19'), equals('Ef 2:19'));
    });
  });

  group('Sabbath School Verse Popup Modal Integration', () {
    testWidgets('BibleVersePreviewModal receives contiguous references and displays all of them',
        (tester) async {
      final repo = TestMockBibleRepository();
      const content =
          '1. Leia [Mateus 16:13-16](bible://Mateus%2016%3A13-16); [Marcos 8:27-29](bible://Marcos%208%3A27-29); [e Lucas 9:18-20](bible://e%20Lucas%209%3A18-20).';

      // Simula exatamente o comportamento de _showVersePopup no SabbathSchoolView
      const clickedRef = 'Mateus 16:13-16';
      final cleanRef = BibleExtractor.cleanReference(clickedRef);
      final contiguous = BibleExtractor.getContiguousReferences(content, cleanRef);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      BibleVersePreviewModal.show(
                        context,
                        reference: cleanRef,
                        references: contiguous,
                        bibleRepository: repo,
                        contextTitle: 'Lição da Escola Sabatina',
                      );
                    },
                    child: const Text('Abrir Passagem'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir Passagem'));
      await tester.pumpAndSettle();

      // Verifica que o modal foi exibido
      expect(find.byType(BibleVersePreviewModal), findsOneWidget);

      // O cabeçalho deve exibir Mateus 16:13-16 (+2) porque são 3 referências
      expect(find.text('Mateus 16:13-16 (+2)'), findsOneWidget);

      // Verifica que todos os 3 versículos mockados foram carregados e exibidos
      expect(find.textContaining('Texto bíblico para a passagem: Mateus 16:13-16'), findsOneWidget);
      expect(find.textContaining('Texto bíblico para a passagem: Marcos 8:27-29'), findsOneWidget);
      expect(find.textContaining('Texto bíblico para a passagem: Lucas 9:18-20'), findsOneWidget);

      // Fecha o diálogo
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(BibleVersePreviewModal), findsNothing);
    });
  });
}
