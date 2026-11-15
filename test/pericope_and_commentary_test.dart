import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/data/repositories/commentary_repository.dart';
import 'package:kairos_web/data/repositories/cross_reference_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/views/bible/widgets/study_bottom_sheet.dart';

class _FakeCommentaryRepository extends CommentaryRepository {
  final List<Commentary> items;
  _FakeCommentaryRepository(this.items);

  @override
  Future<List<Commentary>> getCommentariesForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async =>
      items;
}

class _FakeCrossReferenceRepository extends CrossReferenceRepository {
  @override
  Future<List<CrossReference>> getCrossReferences(
    int bookId,
    int chapter,
    int verse, {
    Map<int, String>? bookNames,
  }) async =>
      const [];
}

void main() {
  test('Pericope.fromMap e Commentary.fromMap decodificam registros com author_name e intervalo de versos', () {
    final pericope = Pericope.fromMap({
      'id': 1,
      'book_id': 1,
      'chapter': 1,
      'verse': 1,
      'title': 'A Criação',
    });
    expect(pericope.title, 'A Criação');

    final commentary = Commentary.fromMap({
      'id': 10,
      'book_id': 43,
      'chapter': 3,
      'verse_start': 16,
      'verse_end': 17,
      'title': 'O Amor de Deus',
      'content': 'Explicação expositiva...',
      'author_name': 'Matthew Henry (PT-BR)',
    });
    expect(commentary.authorName, 'Matthew Henry (PT-BR)');
    expect(commentary.verseEnd, 17);
  });

  testWidgets('StudyBottomSheet exibe chips de autores e filtra comentários por autor', (tester) async {
    final ctrl = BibleController(
      commentaryRepository: _FakeCommentaryRepository(const [
        Commentary(
          id: 1,
          bookId: 1,
          chapter: 1,
          verseStart: 1,
          verseEnd: 1,
          author: 'Matthew Henry',
          text: 'Comentário clássico de Matthew Henry.',
        ),
        Commentary(
          id: 2,
          bookId: 1,
          chapter: 1,
          verseStart: 1,
          verseEnd: 1,
          author: 'Ellen G. White',
          text: 'Reflexão espiritual em Patriarcas e Profetas.',
        ),
      ]),
      crossRefRepository: _FakeCrossReferenceRepository(),
    );

    const verse = BibleVerse(
      id: 1,
      bookId: 1,
      bookName: 'Gênesis',
      chapter: 1,
      verse: 1,
      text: 'No princípio criou Deus os céus e a terra.',
    );

    await ctrl.loadStudyDataForVerse(verse);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudyBottomSheet(controller: ctrl, verse: verse),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Vai para a aba Comentários
    await tester.tap(find.text('Comentários Expositivos'));
    await tester.pumpAndSettle();

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Comentário clássico de Matthew Henry.'), findsOneWidget);
    expect(find.text('Reflexão espiritual em Patriarcas e Profetas.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Ellen G. White'));
    await tester.pumpAndSettle();

    expect(find.text('Comentário clássico de Matthew Henry.'), findsNothing);
    expect(find.text('Reflexão espiritual em Patriarcas e Profetas.'), findsOneWidget);
  });
}
