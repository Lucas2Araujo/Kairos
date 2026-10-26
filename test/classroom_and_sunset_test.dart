import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/avatar_config.dart';
import 'package:kairos_web/services/classroom_service.dart';
import 'package:kairos_web/services/egw_summary_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/reading_plan_service.dart';
import 'package:kairos_web/services/solar_service.dart';
import 'package:kairos_web/views/lesson/widgets/egw_summary_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
    await ReadingPlanService().resetForTesting();
  });

  group('1. ReadingPlanService Tests', () {
    test('Calculates progress, handles multiple active plans and switch primary plan', () async {
      final service = ReadingPlanService();
      await service.init();

      expect(service.activePlans, isEmpty);
      expect(service.primaryPlan, isNull);

      // Inicia o plano RPSP
      await service.activatePlan('rpsp', isPrimary: true);
      expect(service.activePlans.length, 1);
      expect(service.primaryPlan?.plan.id, 'rpsp');
      expect(service.isPlanActive('rpsp'), isTrue);

      // Inicia um segundo plano: Provérbios 31
      await service.activatePlan('proverbios_31');
      expect(service.activePlans.length, 2);
      expect(service.isPlanActive('proverbios_31'), isTrue);

      // Marca o dia 1 de Provérbios como lido
      await service.completeDay('proverbios_31', 1);
      final activePv = service.getProgress('proverbios_31')!;
      expect(activePv.completedDays.contains(1), isTrue);

      // Alterna o plano principal para Provérbios 31
      await service.setPrimaryPlan('proverbios_31');
      expect(service.primaryPlan?.plan.id, 'proverbios_31');

      // Desativa o plano RPSP
      await service.deactivatePlan('rpsp');
      expect(service.activePlans.length, 1);
      expect(service.isPlanActive('rpsp'), isFalse);
    });
  });

  group('2. GamificationService & Lamp Mascot Tests', () {
    test('Meia Ofensiva vs. Ofensiva Completa exigindo Quiz', () async {
      final g = GamificationService();
      await g.init();

      expect(g.streakFlameType, FlameType.none);
      expect(g.isHalfStreakActive, isFalse);
      expect(g.isFullFlameActive, isFalse);

      // Apenas leitura da Bíblia ativa Meia Ofensiva
      await g.recordChapterRead();
      expect(g.streakFlameType, FlameType.halfFlame);
      expect(g.isHalfStreakActive, isTrue);
      expect(g.isFullFlameActive, isFalse);

      // Leitura da Lição e Devocional mantém Meia Ofensiva
      await g.recordSabbathSchoolStudy();
      await g.recordDevotionalReading();
      expect(g.isFullFlameActive, isFalse);

      // Ao completar o Quiz da Escola Sabatina, atinge a Chama Completa!
      await g.recordQuizCompletion();
      expect(g.streakFlameType, FlameType.fullFlame);
      expect(g.isFullFlameActive, isTrue);
      expect(g.lampMascotState, LampMascotState.fullFlame);
    });

    test('Anti-AFK Timer e Estados da Lamparina', () {
      final g = GamificationService();

      // Capacidade do reservatório
      expect(GamificationService.lampCapacity, 100);

      // Estado inicial sem estudo durante o dia
      expect(g.lampMascotState, anyOf(LampMascotState.morningIdle, LampMascotState.eveningSleepy));

      // Adiciona minutos de foco espiritual
      g.addFocusSeconds(120); // 2 minutos (120 segundos)
      expect(g.todayFocusSeconds, 120);
      expect(g.todayFocusMinutes, 2);
    });
  });

  group('3. ClassroomService & Webhook Serialization Tests', () {
    test('Classroom, Member and Activity Log JSON serialization', () {
      final now = DateTime.now();
      final cr = Classroom(
        id: 'c123',
        code: 'KAI777',
        name: 'Classe Jovens Ágape',
        churchName: 'IASD Central',
        teacherId: 't456',
        webhookUrl: 'https://script.google.com/macros/s/test/exec',
        createdAt: now,
      );

      final jsonMap = cr.toJson();
      expect(jsonMap['code'], 'KAI777');
      expect(jsonMap['name'], 'Classe Jovens Ágape');

      const member = ClassroomMember(
        id: 'm1',
        classroomId: 'c123',
        userId: 'u999',
        studentName: 'Lucas Oliveira',
        avatarConfig: AvatarConfig(skinToneIndex: 2, glassesIndex: 1),
      );
      expect(member.studentName, 'Lucas Oliveira');
      expect(member.avatarConfig.skinToneIndex, 2);

      const log = MemberActivityLog(
        userId: 'u999',
        activityDate: '2026-10-25',
        minutesWithGod: 35,
        missionsCompleted: 4,
        didDailyQuiz: true,
        quizScore: 10,
        streakType: 'full',
        totalXp: 180,
      );

      final logJson = log.toJson();
      expect(logJson['streak_type'], 'full');
      expect(logJson['total_xp'], 180);
      expect(logJson['did_daily_quiz'], isTrue);
    });

    test('Excel UTF-8 BOM CSV Report Generator generates formatted valid data', () {
      const member1 = ClassroomMember(
        id: 'm1',
        classroomId: 'c1',
        userId: 'u1',
        studentName: 'Lucas Daniel',
        avatarConfig: AvatarConfig(),
      );
      const member2 = ClassroomMember(
        id: 'm2',
        classroomId: 'c1',
        userId: 'u2',
        studentName: 'Maria Silva',
        avatarConfig: AvatarConfig(),
      );

      final stats = [
        const StudentStatsItem(
          member: member1,
          totalMinutes: 120,
          lessonsStudiedDays: 6,
          totalQuizzes: 5,
          totalScore: 50,
          totalXp: 450,
          currentFlame: FlameType.fullFlame,
          isFullStreakActive: true,
        ),
        const StudentStatsItem(
          member: member2,
          totalMinutes: 45,
          lessonsStudiedDays: 3,
          totalQuizzes: 2,
          totalScore: 20,
          totalXp: 180,
          currentFlame: FlameType.halfFlame,
          isFullStreakActive: false,
        ),
      ];

      final csv = ClassroomService.generateExcelCsvReport(
        classroomName: 'Classe Jovem Kairós',
        periodLabel: 'Semana Atual',
        stats: stats,
      );

      // Verifica presença do marcador UTF-8 BOM (\uFEFF)
      expect(csv.startsWith('\uFEFF'), isTrue);
      expect(csv.contains('Classe Jovem Kairós'), isTrue);
      expect(csv.contains('Lucas Daniel'), isTrue);
      expect(csv.contains('Chama Completa'), isTrue);
      expect(csv.contains('Maria Silva'), isTrue);
      expect(csv.contains('Meia Chama'), isTrue);
    });

    test('Google Apps Script Template contains valid Apps Script handler', () {
      expect(ClassroomService.googleAppsScriptTemplate.contains('function doPost(e)'), isTrue);
      expect(ClassroomService.googleAppsScriptTemplate.contains('Relatorio_Kairos'), isTrue);
    });
  });

  group('4. Solar Calculation (NOAA) & Sunset Tests', () {
    test('Calculates sunset accurately for Brasilia and Sao Paulo', () {
      final date = DateTime(2026, 10, 25);
      final sunsetBrasilia = SolarService.calculateSunset(
        date: date,
        latitude: -15.793889,
        longitude: -47.882778,
        timezoneOffset: -3.0,
      );

      expect(sunsetBrasilia, isNotNull);
      // Pôr do sol em Brasília em outubro é por volta de 18h10 - 18h20
      expect(sunsetBrasilia!.hour, 18);
      expect(sunsetBrasilia.minute >= 0 && sunsetBrasilia.minute <= 30, isTrue);

      final fridaySunset = SolarService.getFridaySunset(referenceDate: date);
      expect(fridaySunset.weekday, DateTime.friday);
    });
  });

  group('5. EgwLessonSummary & UI Widgets Tests', () {
    testWidgets('EgwSummaryBottomSheet renders AI summary and action button', (tester) async {
      const summary = EgwLessonSummary(
        id: 's1',
        lessonDayId: '2026-q4-l04-d1',
        bookTitle: 'O Desejado de Todas as Nações',
        chapterTitle: 'Capítulo 14: Em Caná da Galileia',
        aiSummary: 'Cristo iniciou Seu ministério público revelando Sua glória e a compaixão divina pelas alegrias humanas.',
        directQuotes: [
          '“Em cada ato de Seu ministério terreno, Jesus buscava despertar o coração para a graça do Pai.”'
        ],
        sourceUrl: 'https://m.egwwritings.org/pt',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EgwSummaryBottomSheet(summary: summary),
          ),
        ),
      );

      expect(find.text('O Desejado de Todas as Nações'), findsOneWidget);
      expect(find.text('Capítulo 14: Em Caná da Galileia'), findsOneWidget);
      expect(find.textContaining('Cristo iniciou Seu ministério'), findsOneWidget);
      expect(find.textContaining('Em cada ato de Seu ministério terreno'), findsOneWidget);
      expect(find.byKey(const Key('read_original_egw_writings_button')), findsOneWidget);
    });
  });
}
