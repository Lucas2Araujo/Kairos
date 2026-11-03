import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/devotional_controller.dart';
import 'package:kairos_web/controllers/sabbath_school_controller.dart';
import 'package:kairos_web/core/utils/xlsx_builder.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';
import 'package:kairos_web/models/avatar_config.dart';
import 'package:kairos_web/models/devotional.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/services/classroom_service.dart';
import 'package:kairos_web/services/devotional_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/classroom/classroom_view.dart';
import 'package:kairos_web/views/devotional/devotional_view.dart';
import 'package:kairos_web/views/devotional/meditacao_destaque_view.dart';
import 'package:kairos_web/views/devotional/pordosol_view.dart';
import 'package:kairos_web/views/gamification/monthly_streak_view.dart';
import 'package:kairos_web/views/lesson/widgets/lesson_selection_sheet.dart';
import 'package:kairos_web/views/navigation/main_navigation_view.dart';
import 'package:kairos_web/views/profile/avatar_builder_modal.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubDevotionalService extends DevotionalService {
  @override
  Future<Devotional> getDevotional(String dateStr, {String category = 'jovem'}) async {
    return Devotional(
      publishedAt: dateStr,
      title: 'Título $category',
      author: 'Autor Kairós',
      verseReference: 'Salmos 119:105',
      verseText: 'Lâmpada para os meus pés é a tua palavra.',
      content: 'Reflexão para $category em Salmos 119:105.',
      category: category,
    );
  }
}

class _StubSabbathSchoolService extends SabbathSchoolService {
  @override
  Future<List<SSQuarterly>> getQuarterlies({String category = 'adultos'}) async => [
        SSQuarterly(
          id: '2026-01-cq',
          title: 'Apologética',
          category: category,
        ),
      ];

  @override
  Future<List<SSLesson>> getLessons(String quarterlyId) async => const [
        SSLesson(
          id: '2026-01-cq-01',
          title: 'Razão da Esperança',
          index: '1',
          quarterlyId: '2026-01-cq',
        ),
      ];

  @override
  Future<List<SSDay>> getLessonDays(String lessonId, {String? quarterlyId}) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'has_seen_welcome': true,
    });
    await GamificationService().resetForTesting();
    ClassroomService().setTestClassroom(null, members: [], logs: []);
    final theme = ThemeService();
    await theme.setThemeStyle(AppThemeStyle.materialYou);
    await theme.setGlassAnimationEnabled(false);
    theme.setFontSizeMultiplier(1.0);
    theme.setUiScaleMultiplier(1.0);
  });

  group('1. MainNavigationView & HomeView Navigation Overhaul', () {
    testWidgets('hides NavigationBar on Home and shows it on sub-views including Quizzes card',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: MainNavigationView(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));

      // Home (index 0): NavigationBar and NavigationRail are hidden
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Quizzes'), findsOneWidget);

      // Tap Quizzes card on HomeView -> navigates to sub-view (index 5) and reveals NavigationBar
      await tester.ensureVisible(find.text('Quizzes'));
      await tester.tap(find.text('Quizzes'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Início'), findsOneWidget);
      expect(find.widgetWithText(NavigationDestination, 'Quizzes'), findsOneWidget);
    });
  });

  group('2 & 3. Classroom UI, Diagnostics & OpenXML .xlsx Report', () {
    test('XlsxBuilder and ClassroomService.generateExcelXlsxReport produce valid ZIP OpenXML workbook',
        () {
      const member = ClassroomMember(
        id: 'm1',
        classroomId: 'c1',
        userId: 'u1',
        studentName: 'Ana Clara',
        avatarConfig: AvatarConfig(
          unlockedTrophies: ['primeiro_passo', 'bereano'],
          featuredBadgeId: 'bereano',
        ),
      );
      final stats = [
        const StudentStatsItem(
          member: member,
          totalMinutes: 95,
          lessonsStudiedDays: 5,
          totalQuizzes: 4,
          totalScore: 40,
          totalXp: 320,
          currentFlame: FlameType.fullFlame,
          isFullStreakActive: true,
          completedTasksLabels: ['Lição (5d)', 'Quiz (4x)', 'Tempo com Deus (95 min)'],
          improvementPoints: ['Manter regularidade até 7 dias'],
        ),
      ];

      final bytes = ClassroomService.generateExcelXlsxReport(
        classroomName: 'Jovens Kairós',
        periodLabel: 'Semana Atual',
        stats: stats,
      );

      expect(bytes.length, greaterThan(300));
      // ZIP Local File Header signature: PK\x03\x04
      expect(bytes.sublist(0, 4), equals([0x50, 0x4B, 0x03, 0x04]));

      final asciiDump = latin1.decode(bytes);
      expect(asciiDump, contains('[Content_Types].xml'));
      expect(asciiDump, contains('xl/workbook.xml'));
      expect(asciiDump, contains('xl/worksheets/sheet1.xml'));
      expect(XlsxBuilder.mimeType, contains('spreadsheetml.sheet'));
    });

    test('calculateStudentStats computes completedTasksLabels and actionable improvementPoints',
        () {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final service = ClassroomService();
      service.setTestClassroom(
        const Classroom(
          id: 'c1',
          code: 'ABC123',
          name: 'Classe Esperança',
          churchName: 'IASD Central',
          teacherId: 'teacher1',
        ),
        members: const [
          ClassroomMember(
            id: 'm1',
            classroomId: 'c1',
            userId: 'u_active',
            studentName: 'Pedro Ativo',
            avatarConfig: AvatarConfig(unlockedTrophies: ['primeiro_passo']),
          ),
          ClassroomMember(
            id: 'm2',
            classroomId: 'c1',
            userId: 'u_low',
            studentName: 'João Iniciante',
            avatarConfig: AvatarConfig(),
          ),
        ],
        logs: [
          MemberActivityLog(
            userId: 'u_active',
            activityDate: todayStr,
            minutesWithGod: 30,
            missionsCompleted: 4,
            didDailyQuiz: true,
            quizScore: 10,
            streakType: 'full',
            totalXp: 150,
          ),
        ],
      );

      final now = DateTime.now();
      final stats = service.calculateStudentStats(
        startDate: now.subtract(const Duration(days: 6)),
        endDate: now.add(const Duration(days: 1)),
      );

      expect(stats.length, equals(2));
      final pedro = stats.firstWhere((s) => s.member.userId == 'u_active');
      final joao = stats.firstWhere((s) => s.member.userId == 'u_low');

      expect(pedro.completedTasksLabels, isNotEmpty);
      expect(pedro.unlockedBadgesCount, equals(1));
      expect(joao.improvementPoints, isNotEmpty);
    });

    testWidgets('ClassroomView hides class code from header and exposes actions in overflow menu',
        (tester) async {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      ClassroomService().setTestClassroom(
        const Classroom(
          id: 'c99',
          code: 'SEC999',
          name: 'Classe Sábado Feliz',
          churchName: 'IASD Jardim',
          teacherId: 't99',
        ),
        members: const [
          ClassroomMember(
            id: 'm1',
            classroomId: 'c99',
            userId: 'u1',
            studentName: 'Rebeca Souza',
            avatarConfig: AvatarConfig(
              outfitIndex: 2,
              unlockedTrophies: ['primeiro_passo'],
              featuredBadgeId: 'primeiro_passo',
            ),
          ),
        ],
        logs: [
          MemberActivityLog(
            userId: 'u1',
            activityDate: todayStr,
            minutesWithGod: 20,
            missionsCompleted: 3,
            didDailyQuiz: true,
            quizScore: 10,
            streakType: 'full',
            totalXp: 120,
          ),
        ],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ClassroomView(),
        ),
      );
      await tester.pumpAndSettle();

      // Class name and student are visible, while invite code SEC999 is hidden from main UI
      expect(find.text('Classe Sábado Feliz'), findsOneWidget);
      expect(find.text('Rebeca Souza'), findsOneWidget);
      expect(find.textContaining('SEC999'), findsNothing);

      // Overflow menu (⋮) opens clean options including Excel/CSV download and Invite
      final overflowBtn = find.byKey(const Key('classroom_overflow_menu'));
      expect(overflowBtn, findsOneWidget);
      await tester.tap(overflowBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Código & Convite'), findsOneWidget);
      expect(find.textContaining('Baixar Pontuações'), findsOneWidget);
    });
  });

  group('4, 5 & 6. Avatar 2.0, Categorized Achievements & Unlock Callback', () {
    test('AvatarConfig 2.0 serializes new customization fields and preserves legacy compatibility',
        () {
      const config = AvatarConfig(
        skinToneIndex: 3,
        faceShapeIndex: 2,
        hairStyleIndex: 6,
        hairColorIndex: 2,
        eyeColorIndex: 3,
        expressionIndex: 4,
        facialHairIndex: 2,
        glassesIndex: 3,
        outfitIndex: 5,
        outfitColorIndex: 4,
        accessoryIndex: 4,
        backgroundColorIndex: 7,
        unlockedTrophies: ['primeiro_passo', 'bereano'],
        featuredBadgeId: 'bereano',
      );

      final parsed = AvatarConfig.fromJson(config.toJson());
      expect(parsed.faceShapeIndex, 2);
      expect(parsed.hairStyleIndex, 6);
      expect(parsed.eyeColorIndex, 3);
      expect(parsed.facialHairIndex, 2);
      expect(parsed.outfitIndex, 5);
      expect(parsed.outfitColorIndex, 4);
      expect(parsed.accessoryIndex, 4);
      expect(parsed.backgroundColorIndex, 7);
      expect(parsed.unlockedTrophies, containsAll(['primeiro_passo', 'bereano']));
      expect(parsed.featuredBadgeId, 'bereano');

      // Legacy payload without 2.0 fields falls back safely
      final legacy = AvatarConfig.fromJson('{"s":1,"h":2}');
      expect(legacy.skinToneIndex, 1);
      expect(legacy.hairStyleIndex, 2);
      expect(legacy.outfitIndex, 0);
    });

    test('GamificationService exposes 5 achievement categories and triggers onAchievementUnlocked',
        () async {
      final g = GamificationService();
      final unlockedEvents = <AchievementDefinition>[];
      g.onAchievementUnlocked = unlockedEvents.add;

      expect(g.allAchievements.length, greaterThanOrEqualTo(15));
      final categories = g.allAchievements.map((a) => a.category).toSet();
      expect(categories.length, equals(AchievementCategory.values.length));

      await g.recordReading(category: 'biblia');

      expect(g.isTrophyUnlocked('primeiro_passo'), isTrue);
      expect(unlockedEvents.any((a) => a.id == 'primeiro_passo'), isTrue);
    });

    testWidgets('AvatarBuilderModal and MonthlyStreakView render without errors', (tester) async {
      await GamificationService().recordReading(category: 'biblia');

      await tester.pumpWidget(
        const MaterialApp(
          home: MonthlyStreakView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Primeiro Passo'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarBuilderModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarCustomWidget), findsWidgets);
    });
  });

  group('7 & 10. Devotional Header Badge, 3-Dots Menu & Destaque Clean Download', () {
    testWidgets('DevotionalView shows category badge in AppBar and switches via 3-dots menu',
        (tester) async {
      await ThemeService().setDefaultDevotionalCategory('jovem');
      final ctrl = DevotionalController(service: _StubDevotionalService());
      await ctrl.loadDevotional();

      await tester.pumpWidget(
        MaterialApp(
          home: DevotionalView(controller: ctrl),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Meditação'), findsOneWidget);
      expect(find.byKey(const Key('devotional_category_badge')), findsOneWidget);
      expect(find.text('Jovens'), findsOneWidget);

      // Open 3-dots menu -> switch to Mulher and verify Por do Sol option exists
      await tester.tap(find.byKey(const Key('devotional_overflow_menu')));
      await tester.pumpAndSettle();

      expect(find.text('Meditação do Pôr do Sol'), findsOneWidget);
      await tester.tap(find.text('Meditação da Mulher'));
      await tester.pumpAndSettle();

      expect(ctrl.selectedCategory, equals('mulher'));
      expect(find.text('Mulher'), findsOneWidget);

      // Open 3-dots menu -> navigate to PorDoSolView
      await tester.tap(find.byKey(const Key('devotional_overflow_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Meditação do Pôr do Sol'));
      await tester.pumpAndSettle();

      expect(find.byType(PorDoSolView), findsOneWidget);
    });

    testWidgets('MeditacaoDestaqueView exposes Baixar button and exports clean verse artwork',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeditacaoDestaqueView(
              fallbackVerse: 'O Senhor é o meu pastor; nada me faltará.',
              fallbackReference: 'Salmos 23:1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final downloadBtn = find.byKey(const Key('destaque_download_button'));
      expect(downloadBtn, findsOneWidget);
      expect(find.text('Baixar'), findsOneWidget);
    });
  });

  group('8. Youth LessonSelectionSheet Tirinha Preview', () {
    testWidgets('shows reduced-opacity weekly tirinha strip for jovens and hides it for adultos',
        (tester) async {
      final ctrl = SabbathSchoolController(service: _StubSabbathSchoolService());
      await ctrl.setCategory('jovens');
      await ctrl.init();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonSelectionSheet(controller: ctrl),
          ),
        ),
      );
      await tester.pump();

      final tirinhaFinder = find.byKey(const Key('youth_tirinha_preview_2026-01-cq-01'));
      expect(tirinhaFinder, findsOneWidget);
      final opacityWidget = tester.widget<Opacity>(tirinhaFinder);
      expect(opacityWidget.opacity, closeTo(0.34, 0.05));

      // Switch to adultos -> tirinha strip should not appear
      await ctrl.setCategory('adultos');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonSelectionSheet(controller: ctrl),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('youth_tirinha_preview_2026-01-cq-01')), findsNothing);
    });
  });

  group('9. Strict Responsiveness (320x640 + TextScaler 1.4x) & Categorized SettingsDialog', () {
    testWidgets('SettingsDialog renders all 4 categorized tabs without overflow on 320dp screen',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.4),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SettingsDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tabKey in const [
        Key('settings_tab_leitura'),
        Key('settings_tab_conteudo'),
        Key('settings_tab_sistema'),
        Key('settings_tab_aparencia'),
      ]) {
        await tester.ensureVisible(find.byKey(tabKey));
        await tester.tap(find.byKey(tabKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('ClassroomView renders cleanly without overflow on 320dp screen with 1.3x text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      ClassroomService().setTestClassroom(
        const Classroom(
          id: 'c320',
          code: 'SM320X',
          name: 'Classe Compacta de Jovens e Universitários',
          churchName: 'IASD Central Metropolitana',
          teacherId: 't1',
        ),
        members: const [
          ClassroomMember(
            id: 'm1',
            classroomId: 'c320',
            userId: 'u1',
            studentName: 'Gabriel Henrique Nascimento',
            avatarConfig: AvatarConfig(unlockedTrophies: ['primeiro_passo']),
          ),
        ],
        logs: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const ClassroomView(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
