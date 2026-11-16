import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/data/repositories/commentary_repository.dart';
import 'package:kairos_web/data/repositories/cross_reference_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/egw_models.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/bible/widgets/study_bottom_sheet.dart';
import 'package:kairos_web/views/downloads/downloads_dialog.dart';
import 'package:kairos_web/views/egw/widgets/egw_book_cover.dart';
import 'package:kairos_web/views/home/widgets/daily_missions_bottom_sheet.dart';
import 'package:kairos_web/views/profile/profile_dialog.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';
import 'package:kairos_web/widgets/kairos_reader_gesture_layer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _A11yFakeCommentaryRepository extends CommentaryRepository {
  final List<Commentary> items;
  _A11yFakeCommentaryRepository(this.items);

  @override
  Future<List<Commentary>> getCommentariesForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async =>
      items;
}

class _A11yFakeCrossReferenceRepository extends CrossReferenceRepository {
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService().init();
    await GamificationService().resetForTesting();
  });

  Widget wrapTightA11y(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('DownloadsDialog uses single close IconButton without Concluir',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DownloadsDialog()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.text('Concluir'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KairosReaderGestureLayer respects gesturesEnabled flag',
      (WidgetTester tester) async {
    var nextCalls = 0;

    await ThemeService().setGesturesEnabled(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KairosReaderGestureLayer(
            onNextChapter: () => nextCalls++,
            child: const SizedBox.expand(
              child: ColoredBox(color: Colors.transparent),
            ),
          ),
        ),
      ),
    );

    await tester.fling(
      find.byType(KairosReaderGestureLayer),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    expect(nextCalls, 0);

    await ThemeService().setGesturesEnabled(true);
    await ThemeService().setGestureSwipeChapters(true);
    await tester.pump();

    await tester.fling(
      find.byType(KairosReaderGestureLayer),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    expect(nextCalls, 1);

    await ThemeService().setGesturesEnabled(false);
  });

  group('Tight screen (320x640) & TextScaler 2.0 overflow guards', () {
    void configureTightViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('SettingsDialog renders without overflow at 320x640 @ 2.0x',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      await tester.pumpWidget(wrapTightA11y(const SettingsDialog()));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileDialog renders without overflow at 320x640 @ 2.0x',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      await tester.pumpWidget(wrapTightA11y(const ProfileDialog()));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(ProfileDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DownloadsDialog renders without overflow at 320x640 @ 2.0x',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      await tester.pumpWidget(wrapTightA11y(const DownloadsDialog()));
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(DownloadsDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('EgwBookCover renders without overflow at 320x640 @ 2.0x',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      final book = EgwBook(
        id: '1815',
        title: 'Patriarcas e Profetas',
        abbreviation: 'PP',
      );
      await tester.pumpWidget(
        wrapTightA11y(
          EgwBookCover(
            book: book,
            useModernCover: true,
            width: 140,
            height: 210,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(EgwBookCover), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('StudyBottomSheet renders without overflow at 320x640 @ 2.0x',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      final ctrl = BibleController(
        commentaryRepository: _A11yFakeCommentaryRepository(const [
          Commentary(
            id: 1,
            bookId: 1,
            chapter: 1,
            verseStart: 1,
            verseEnd: 1,
            author: 'Matthew Henry (PT-BR)',
            text: 'Comentário expositivo para teste de acessibilidade.',
          ),
          Commentary(
            id: 2,
            bookId: 1,
            chapter: 1,
            verseStart: 1,
            verseEnd: 1,
            author: 'Notas EGW / Comentário Adventista',
            text: 'Reflexão complementar para teste de escala.',
          ),
        ]),
        crossRefRepository: _A11yFakeCrossReferenceRepository(),
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
        wrapTightA11y(StudyBottomSheet(controller: ctrl, verse: verse)),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(StudyBottomSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'DailyMissionsBottomSheet renders without overflow at 320x640 @ 2.0x and displays accurate mission rewards',
        (WidgetTester tester) async {
      configureTightViewport(tester);
      final g = GamificationService();
      await g.init();
      await g.addFocusSeconds(g.dailyGoalMinutes * 60);
      await g.recordChapterRead();
      await g.recordSabbathSchoolStudy();
      await g.recordQuizCompletion();

      await tester.pumpWidget(
        wrapTightA11y(const DailyMissionsBottomSheet()),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(DailyMissionsBottomSheet), findsOneWidget);
      expect(find.text('+25 gotas'), findsNothing);
      expect(find.text('+30 gotas'), findsNWidgets(2));
      expect(find.text('+40 gotas'), findsOneWidget);
      expect(find.text('+10 gotas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
