import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/models/reading_plan_models.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/notification_service.dart';
import 'package:kairos_web/services/reading_plan_service.dart';
import 'package:kairos_web/views/home/widgets/active_plan_banner.dart';
import 'package:kairos_web/views/bible/widgets/reading_plan_floating_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
    await ReadingPlanService().resetForTesting();
  });

  group('NativeReadingPlans Catalog & Generator Tests', () {
    test('Catalog contains exactly 6 native plans with expected metadata', () {
      final plans = NativeReadingPlans.getPlans();
      expect(plans.length, 6);

      final ids = plans.map((p) => p.id).toSet();
      expect(ids.contains('rpsp'), isTrue);
      expect(ids.contains('ano_biblico'), isTrue);
      expect(ids.contains('proverbios_31'), isTrue);
      expect(ids.contains('vida_jesus_40'), isTrue);
      expect(ids.contains('conflito_esperanca'), isTrue);
      expect(ids.contains('paz_ansiedade_14'), isTrue);
    });

    test('RPSP has exactly 1189 chapters, 1 per day', () {
      final rpsp = NativeReadingPlans.getPlans().firstWhere((p) => p.id == 'rpsp');
      expect(rpsp.daysCount, 1189);
      expect(rpsp.days.length, 1189);

      // Day 1 is Genesis 1
      expect(rpsp.days.first.chapters.first.bookName, 'Gênesis');
      expect(rpsp.days.first.chapters.first.chapter, 1);

      // Day 1189 is Revelation 22
      expect(rpsp.days.last.chapters.first.bookName, 'Apocalipse');
      expect(rpsp.days.last.chapters.first.chapter, 22);
    });

    test('Ano Bíblico has exactly 365 days and covers all 1189 chapters', () {
      final anoBiblico =
          NativeReadingPlans.getPlans().firstWhere((p) => p.id == 'ano_biblico');
      expect(anoBiblico.daysCount, 365);
      expect(anoBiblico.days.length, 365);

      int totalChapters = 0;
      for (final day in anoBiblico.days) {
        totalChapters += day.chapters.length;
        expect(day.chapters.length >= 3 && day.chapters.length <= 4, isTrue);
      }
      expect(totalChapters, 1189);
    });

    test('Proverbios 31 has 31 days with 1 chapter of Proverbs per day', () {
      final pv =
          NativeReadingPlans.getPlans().firstWhere((p) => p.id == 'proverbios_31');
      expect(pv.daysCount, 31);
      for (int i = 0; i < 31; i++) {
        expect(pv.days[i].chapters.first.bookId, 20);
        expect(pv.days[i].chapters.first.chapter, i + 1);
      }
    });

    test('ReadingPlanDay readingSummary formats ranges cleanly', () {
      const daySingle = ReadingPlanDay(
        dayIndex: 1,
        title: 'Dia 1',
        chapters: [
          ReadingPlanChapterRef(
              bookId: 1, bookName: 'Gênesis', abbrev: 'Gn', chapter: 1),
        ],
      );
      expect(daySingle.readingSummary, 'Gênesis 1');

      const dayRange = ReadingPlanDay(
        dayIndex: 12,
        title: 'Dia 12',
        chapters: [
          ReadingPlanChapterRef(
              bookId: 1, bookName: 'Gênesis', abbrev: 'Gn', chapter: 34),
          ReadingPlanChapterRef(
              bookId: 1, bookName: 'Gênesis', abbrev: 'Gn', chapter: 35),
          ReadingPlanChapterRef(
              bookId: 1, bookName: 'Gênesis', abbrev: 'Gn', chapter: 36),
        ],
      );
      expect(dayRange.readingSummary, 'Gênesis 34-36');
    });
  });

  group('ReadingPlanService Multi-Plan & Progress Logic', () {
    test('Activating multiple plans assigns primary to the first one or explicit isPrimary', () async {
      final service = ReadingPlanService();
      await service.init();

      expect(service.activePlans.isEmpty, isTrue);
      expect(service.primaryPlan, isNull);

      // Ativa primeiro plano: deve se tornar automaticamente principal
      await service.activatePlan('rpsp');
      expect(service.activePlans.length, 1);
      expect(service.primaryPlan?.plan.id, 'rpsp');
      expect(service.primaryPlan?.progress.isPrimary, isTrue);

      // Ativa segundo plano sem isPrimary
      await service.activatePlan('ano_biblico');
      expect(service.activePlans.length, 2);
      expect(service.primaryPlan?.plan.id, 'rpsp'); // RPSP continua principal

      // Promove ano_biblico a principal
      await service.setPrimaryPlan('ano_biblico');
      expect(service.primaryPlan?.plan.id, 'ano_biblico');
      expect(service.getProgress('rpsp')?.isPrimary, isFalse);
      expect(service.getProgress('ano_biblico')?.isPrimary, isTrue);

      // Desativa ano_biblico: o outro plano ativo (rpsp) deve ser promovido a principal
      await service.deactivatePlan('ano_biblico');
      expect(service.activePlans.length, 1);
      expect(service.primaryPlan?.plan.id, 'rpsp');
    });

    test('Granular chapter completion and day completion auto-advances and awards oil drops', () async {
      final service = ReadingPlanService();
      final gamification = GamificationService();
      await service.init();
      await gamification.init();

      expect(gamification.todayOilDrops, 0);

      // Ativa Provérbios 31 (1 capítulo por dia)
      await service.activatePlan('proverbios_31');
      final todayStatus = service.getTodayStatus('proverbios_31');
      expect(todayStatus?.currentDayIndex, 1);
      expect(todayStatus?.isDayCompleted, isFalse);

      // Marca o capítulo de hoje (Pv 1: bookId 20, chapter 1)
      await service.toggleChapterCompletion('proverbios_31', 1, '20:1');

      // Como era o único capítulo do dia, o dia foi concluído automaticamente
      final updatedStatus = service.getTodayStatus('proverbios_31');
      expect(updatedStatus?.isDayCompleted, isTrue);

      // E abasteceu a lamparina com +40 gotas de azeite!
      expect(gamification.todayOilDrops, 40);
      expect(gamification.hasBibleToday, isTrue);
    });

    test('Manual completeDay marks all chapters and adds 40 oil drops', () async {
      final service = ReadingPlanService();
      final gamification = GamificationService();
      await service.init();
      await gamification.init();

      await service.activatePlan('paz_ansiedade_14');
      await service.completeDay('paz_ansiedade_14', 1);

      final status = service.getTodayStatus('paz_ansiedade_14');
      expect(status?.isDayCompleted, isTrue);
      expect(gamification.todayOilDrops, 40);
      expect(gamification.currentStreak, 1);
    });
  });

  group('GamificationService - Azeite na Lamparina', () {
    test('100 drops fills the lamp and lights the flame', () async {
      final gamification = GamificationService();
      await gamification.init();

      expect(gamification.isLampFull, isFalse);
      expect(gamification.lampPercentage, 0.0);

      // 1. Leitura Bíblica (+40 gotas)
      await gamification.recordReadingPlanCompletion();
      expect(gamification.todayOilDrops, 40);
      expect(gamification.isLampFull, isFalse);
      expect(gamification.lampPercentage, 0.4);

      // 2. Lição da Escola Sabatina (+30 gotas)
      await gamification.recordSabbathSchoolStudy();
      expect(gamification.todayOilDrops, 70);
      expect(gamification.lampPercentage, 0.7);

      // 3. Meditação Diária (+30 gotas)
      await gamification.recordDevotionalReading();
      expect(gamification.todayOilDrops, 100);
      expect(gamification.isLampFull, isTrue);
      expect(gamification.lampPercentage, 1.0);
    });
  });

  group('NotificationService local reminders schedule/cancel', () {
    test('Schedules daily reminder and friday sunset without throwing', () {
      final notif = NotificationService();
      expect(() => notif.scheduleDailyReminder(
            id: 'test_rem',
            time: '07:30',
            title: 'Lembrete Teste',
            message: 'Mensagem de teste',
            route: '/biblia',
          ), returnsNormally);

      expect(() => notif.scheduleFridaySunsetReminder(time: '16:30'), returnsNormally);
      expect(() => notif.cancelReminder('test_rem'), returnsNormally);
    });
  });

  group('ActivePlanBanner & Floating Pill Widgets', () {
    testWidgets('ActivePlanBanner displays invitation when no active plan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivePlanBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plano de Estudo Bíblico'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
    });

    testWidgets('ActivePlanBanner displays primary active plan and expands chapters', (tester) async {
      final service = ReadingPlanService();
      await service.init();
      await service.activatePlan('proverbios_31');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivePlanBanner(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sabedoria Diária'), findsOneWidget);
      expect(find.text('Ler'), findsOneWidget);

      // Clica para expandir o card
      await tester.tap(find.text('Sabedoria Diária'));
      await tester.pumpAndSettle();

      expect(find.text('Ver Todos os Planos'), findsOneWidget);
      expect(find.text('Concluir Dia'), findsOneWidget);
    });

    testWidgets('ReadingPlanFloatingPill renders when primary plan is active', (tester) async {
      final service = ReadingPlanService();
      await service.init();
      await service.activatePlan('proverbios_31');

      final ctrl = BibleController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingPlanFloatingPill(controller: ctrl),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Sabedoria Diária'), findsOneWidget);
    });
  });
}
