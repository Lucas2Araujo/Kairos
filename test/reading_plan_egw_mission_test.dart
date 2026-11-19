import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/reading_plan_models.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/reading_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
    await ReadingPlanService().resetForTesting();
  });

  test('ReadingPlanDay.parseEgwMission extrai livro e capítulo exato ou deriva da sugestão', () {
    const dayWithNote = ReadingPlanDay(
      dayNumber: 1,
      title: 'A Criação',
      chapters: [ReadingPlanChapterRef(bookId: 1, bookName: 'Gênesis', chapter: 1)],
      egwNote: 'Patriarcas e Profetas (PP), cap. 2',
    );
    final mission = dayWithNote.parseEgwMission();
    expect(mission, isNotNull);
    expect(mission!.bookCode, 'PP');
    expect(mission.bookId, '1815');
    expect(mission.chapterNumber, 2);

    const dayFallback = ReadingPlanDay(
      dayNumber: 3,
      title: 'A Queda',
      chapters: [ReadingPlanChapterRef(bookId: 1, bookName: 'Gênesis', chapter: 3)],
    );
    final derived = dayFallback.parseEgwMission();
    expect(derived, isNotNull);
    expect(derived!.bookCode, 'PP');
    expect(derived.chapterNumber, 3);
  });

  test('completeEgwMissionStep é idempotente e concede +25 gotas de azeite na conclusão', () async {
    final planService = ReadingPlanService();
    final gamification = GamificationService();
    final firstPlan = planService.allPlans.first;

    await planService.activatePlan(firstPlan.id, isPrimary: true);
    final initialXp = gamification.totalXp;

    const mission = EgwPlanMissionRef(
      bookCode: 'PP',
      bookTitle: 'Patriarcas e Profetas',
      chapterNumber: 2,
    );

    await planService.completeEgwMissionStep(firstPlan.id, 1, mission);
    expect(gamification.totalXp, initialXp + 25);
    expect(
      planService.getProgress(firstPlan.id)!.completedChapterKeys.contains('egw:PP:2'),
      isTrue,
    );

    // Chamar novamente não deve duplicar recompensa
    await planService.completeEgwMissionStep(firstPlan.id, 1, mission);
    expect(gamification.totalXp, initialXp + 25);
  });
}
