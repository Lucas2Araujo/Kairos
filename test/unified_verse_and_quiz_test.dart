import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/quiz_controller.dart';
import 'package:kairos_web/core/utils/bible_extractor.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/views/bible/widgets/bible_verse_preview_modal.dart';
import 'package:kairos_web/views/lesson/widgets/quick_quiz_bottom_sheet.dart';

class FakeBibleRepository extends BibleRepository {
  @override
  Future<List<BibleVerse>> buscarPassagem(String refText) async {
    final clean = refText.trim();
    if (clean.contains('João 14:3')) {
      return [
        const BibleVerse(
          id: 1,
          bookId: 43,
          bookName: 'João',
          chapter: 14,
          verse: 3,
          text: 'E, quando eu for e vos preparar lugar, voltarei e vos receberei para mim mesmo.',
        ),
      ];
    }
    if (clean.contains('1 Coríntios 14:9')) {
      return [
        const BibleVerse(
          id: 2,
          bookId: 46,
          bookName: '1 Coríntios',
          chapter: 14,
          verse: 9,
          text: 'Assim, vós, se com a língua não disserdes palavra bem inteligível, como se entenderá?',
        ),
      ];
    }
    if (clean.contains('Ef 2:19 - 3:15') || clean.contains('Efésios 2:19 - 3:15')) {
      return [
        const BibleVerse(
          id: 10,
          bookId: 49,
          bookName: 'Efésios',
          chapter: 2,
          verse: 19,
          text: 'Assim que já não sois estrangeiros, nem forasteiros, mas concidadãos dos Santos.',
        ),
        const BibleVerse(
          id: 11,
          bookId: 49,
          bookName: 'Efésios',
          chapter: 3,
          verse: 1,
          text: 'Por esta causa eu, Paulo, sou o prisioneiro de Jesus Cristo por vós, os gentios.',
        ),
      ];
    }
    return [
      BibleVerse(
        id: 3,
        bookId: 1,
        bookName: clean,
        chapter: 1,
        verse: 1,
        text: 'Versículo de exemplo para $clean.',
      ),
    ];
  }
}

void main() {
  group('BibleExtractor.getContiguousReferences', () {
    test('groups contiguous references separated by comma correctly', () {
      const text =
          'O apóstolo escreveu em João 14:3, 1 Coríntios 14:9, Efésios 4:11-13 sobre as promessas. Mais adiante cita Romanos 8:28.';

      final refs = BibleExtractor.getContiguousReferences(text, '1 Coríntios 14:9');
      expect(refs, equals(['João 14:3', '1 Coríntios 14:9', 'Efésios 4:11-13']));
    });

    test('groups contiguous references separated by semicolon and "e"', () {
      const text =
          'Conforme lemos em João 14:3; 1 Coríntios 14:9 e Efésios 4:11-13, a esperança é viva.';

      final refs = BibleExtractor.getContiguousReferences(text, 'João 14:3');
      expect(refs, equals(['João 14:3', '1 Coríntios 14:9', 'Efésios 4:11-13']));

      final refsLast = BibleExtractor.getContiguousReferences(text, 'Efésios 4:11-13');
      expect(refsLast, equals(['João 14:3', '1 Coríntios 14:9', 'Efésios 4:11-13']));
    });

    test('isolates references separated by sentences and explanations', () {
      const text =
          'Leia com atenção João 14:3. Paulo também discute o mesmo princípio em Romanos 8:28.';

      final refs1 = BibleExtractor.getContiguousReferences(text, 'João 14:3');
      expect(refs1, equals(['João 14:3']));

      final refs2 = BibleExtractor.getContiguousReferences(text, 'Romanos 8:28');
      expect(refs2, equals(['Romanos 8:28']));
    });

    test('isolates references separated by double newlines (paragraphs)', () {
      const text = 'João 14:3\n\n1 Coríntios 14:9';

      final refs = BibleExtractor.getContiguousReferences(text, 'João 14:3');
      expect(refs, equals(['João 14:3']));
    });

    test('falls back gracefully to targetRef if not found in text', () {
      const text = 'Um texto sem referências bíblicas.';
      final refs = BibleExtractor.getContiguousReferences(text, 'Salmos 23:1');
      expect(refs, equals(['Salmos 23:1']));
    });

    test('groups cross-chapter references like Ef 2:19 - 3:15 with "e Lucas 12:15"', () {
      const text =
          'Leia com devoção Ef 2:19 - 3:15 e Lucas 12:15 para a sua reflexão.';

      final refs = BibleExtractor.getContiguousReferences(text, 'Ef 2:19 - 3:15');
      expect(refs, equals(['Ef 2:19 - 3:15', 'Lucas 12:15']));

      final refsLast = BibleExtractor.getContiguousReferences(text, 'e Lucas 12:15');
      expect(refsLast, equals(['Ef 2:19 - 3:15', 'Lucas 12:15']));

      final refsDirect = BibleExtractor.getContiguousReferences(text, 'Lucas 12:15');
      expect(refsDirect, equals(['Ef 2:19 - 3:15', 'Lucas 12:15']));
    });

    test('groups contiguous references wrapped in markdown links and clean prefixes', () {
      const text =
          'Vejamos [Ef 2:19 - 3:15](bible://Ef%202:19-3:15) e [Lucas 12:15](bible://e%20Lucas%2012:15) na lição.';

      final refsFromEf = BibleExtractor.getContiguousReferences(text, 'Ef 2:19 - 3:15');
      expect(refsFromEf, equals(['Ef 2:19 - 3:15', 'Lucas 12:15']));

      final refsFromUrl = BibleExtractor.getContiguousReferences(text, 'e Lucas 12:15');
      expect(refsFromUrl, equals(['Ef 2:19 - 3:15', 'Lucas 12:15']));
    });

    test('handles whole chapter range like Ef 2 - 3', () {
      const text = 'Estude Ef 2 - 3 e Rm 8 hoje.';
      final refs = BibleExtractor.getContiguousReferences(text, 'Ef 2 - 3');
      expect(refs, equals(['Ef 2 - 3', 'Rm 8']));
    });
  });

  group('BibleVersePreviewModal Widget Tests', () {
    testWidgets('renders title, multiple contiguous passages, version selector and action buttons',
        (tester) async {
      final fakeRepo = FakeBibleRepository();

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
                        reference: 'João 14:3',
                        references: ['João 14:3', '1 Coríntios 14:9'],
                        bibleRepository: fakeRepo,
                      );
                    },
                    child: const Text('Abrir Preview'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir Preview'));
      await tester.pumpAndSettle();

      // Verifica presença do modal e cabeçalho
      expect(find.byType(BibleVersePreviewModal), findsOneWidget);
      expect(find.text('João 14:3, 1 Coríntios 14:9'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);

      // Verifica passagens renderizadas sequencialmente
      expect(find.textContaining('E, quando eu for e vos preparar lugar'), findsOneWidget);
      expect(find.textContaining('Assim, vós, se com a língua'), findsOneWidget);

      // Testa botão copiar
      await tester.tap(find.text('Copiar'));
      await tester.pump();
      expect(find.text('Passagem bíblica copiada!'), findsOneWidget);

      // Fecha o diálogo
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(BibleVersePreviewModal), findsNothing);
    });

    testWidgets('renders chapter divider badge when passage spans multiple chapters',
        (tester) async {
      final fakeRepo = FakeBibleRepository();

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
                        reference: 'Ef 2:19 - 3:15',
                        bibleRepository: fakeRepo,
                      );
                    },
                    child: const Text('Abrir Multi-Capítulo'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir Multi-Capítulo'));
      await tester.pumpAndSettle();

      expect(find.byType(BibleVersePreviewModal), findsOneWidget);
      expect(find.text('Capítulo 3'), findsOneWidget);
      expect(find.textContaining('Assim que já não sois estrangeiros'), findsOneWidget);
      expect(find.textContaining('Por esta causa eu, Paulo'), findsOneWidget);
    });
  });

  group('QuickQuizBottomSheet Widget Tests', () {
    testWidgets('renders daily quiz, handles option selection and displays instant explanation feedback',
        (tester) async {
      final quizController = QuizController();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      QuickQuizBottomSheet.show(
                        context,
                        category: 'adultos',
                        dayId: 'd1',
                        quizController: quizController,
                      );
                    },
                    child: const Text('Iniciar Desafio'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Iniciar Desafio'));
      await tester.pumpAndSettle();

      // Verifica cabeçalho e elementos
      expect(find.byType(QuickQuizBottomSheet), findsOneWidget);
      expect(find.text('Desafio da Lição'), findsOneWidget);
      expect(find.text('Verificar Resposta'), findsOneWidget);

      // Verifica se a pergunta do dia d1 de adultos é exibida
      expect(
        find.text('No princípio, o que Deus criou conforme o relato de Gênesis 1:1?'),
        findsOneWidget,
      );

      // Seleciona a opção correta (A: "Os céus e a terra")
      final optionA = find.text('Os céus e a terra');
      expect(optionA, findsOneWidget);
      await tester.tap(optionA);
      await tester.pumpAndSettle();

      // Submete a resposta
      await tester.tap(find.text('Verificar Resposta'));
      await tester.pumpAndSettle();

      // Verifica feedback positivo e explicação imediata
      expect(find.textContaining('Correto! (+10 XP)'), findsOneWidget);
      expect(
        find.textContaining('Gênesis 1:1 declara categoricamente'),
        findsOneWidget,
      );

      // Verifica botão avançar
      expect(find.text('Concluir Desafio'), findsOneWidget);
    });
  });
}
