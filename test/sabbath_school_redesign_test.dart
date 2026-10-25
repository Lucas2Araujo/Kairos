import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/sabbath_school_controller.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/views/lesson/widgets/lesson_selection_sheet.dart';
import 'package:kairos_web/views/lesson/widgets/quarterly_catalog_dialog.dart';

class _FakeSabbathSchoolController extends ChangeNotifier implements SabbathSchoolController {
  @override
  String category = 'jovens';

  @override
  String quarterlyType = 'jovens';

  @override
  List<SSQuarterly> quarterlies = [
    const SSQuarterly(
      id: '2026-04-cq',
      title: 'Profetas do NT',
      category: 'jovens',
    ),
  ];

  @override
  SSQuarterly? selectedQuarterly = const SSQuarterly(
    id: '2026-04-cq',
    title: 'Profetas do NT',
    category: 'jovens',
  );

  @override
  List<SSLesson> lessons = [
    const SSLesson(
      id: '2026-04-cq-01',
      title: 'O Criador fala',
      index: '1',
      quarterlyId: '2026-04-cq',
      cover: 'https://example.com/cover1.png',
    ),
    const SSLesson(
      id: '2026-04-cq-02',
      title: 'O chamado do profeta',
      index: '2',
      quarterlyId: '2026-04-cq',
      cover: 'https://example.com/cover2.png',
    ),
  ];

  @override
  SSLesson? selectedLesson = const SSLesson(
    id: '2026-04-cq-01',
    title: 'O Criador fala',
    index: '1',
    quarterlyId: '2026-04-cq',
  );

  @override
  List<SSDay> days = [];

  @override
  SSDay? selectedDay;

  @override
  String currentNote = '';

  @override
  double fontSize = 16.0;

  @override
  bool isLoading = false;

  @override
  String? errorMessage;

  bool selectLessonCalled = false;
  SSLesson? lastSelectedLesson;

  @override
  Future<void> selectLesson(SSLesson lesson) async {
    selectLessonCalled = true;
    lastSelectedLesson = lesson;
    selectedLesson = lesson;
    notifyListeners();
  }

  @override
  Future<void> selectQuarterly(SSQuarterly quarterly) async {
    selectedQuarterly = quarterly;
    notifyListeners();
  }

  @override
  Future<void> setCategory(String newCategory) async {
    category = newCategory;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('LessonSelectionSheet renders lessons list and selects item', (tester) async {
    final fakeCtrl = _FakeSabbathSchoolController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => LessonSelectionSheet.show(ctx, fakeCtrl),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Selecionar Lição da Semana'), findsOneWidget);
    expect(find.text('O Criador fala'), findsOneWidget);
    expect(find.text('O chamado do profeta'), findsOneWidget);

    await tester.tap(find.text('O chamado do profeta'));
    await tester.pumpAndSettle();

    expect(fakeCtrl.selectLessonCalled, isTrue);
    expect(fakeCtrl.lastSelectedLesson?.id, equals('2026-04-cq-02'));
  });

  testWidgets('QuarterlyCatalogDialog renders streaming headers and sections', (tester) async {
    final fakeCtrl = _FakeSabbathSchoolController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => QuarterlyCatalogDialog.show(ctx, fakeCtrl),
              child: const Text('Open Catalog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Catalog'));
    await tester.pump();

    expect(find.text('Catálogo de Lições'), findsOneWidget);
    expect(find.text('Escolha o trimestre para estudo'), findsOneWidget);
  });
}
