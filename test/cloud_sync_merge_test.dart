import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/reading_plan_models.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/reading_plan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
    await ReadingPlanService().resetForTesting();
  });

  test('GamificationService.mergeActivityDates preserva união sem perder dias locais nem remotos', () {
    final merged = GamificationService.mergeActivityDates(
      {'2026-11-10', '2026-11-12'},
      {'2026-11-11', '2026-11-12', '2026-11-13'},
    );
    expect(merged, {'2026-11-10', '2026-11-11', '2026-11-12', '2026-11-13'});
  });

  test('GamificationService.mergeCloudMetadata mescla atividade, troféus e contadores máximos', () async {
    final g = GamificationService();
    await g.addOilDrops(50);

    final changed = await g.mergeCloudMetadata({
      'gamification_activity_dates': ['2026-11-01', '2026-11-02'],
      'gamification_unlocked_trophies': ['first_flame', 'streak_7'],
      'gamification_total_xp': 220,
      'gamification_total_chapters_read': 15,
      'gamification_early_morning_count': 4,
      'gamification_total_quizzes_count': 9,
    });

    expect(changed, isTrue);
    expect(g.activityDates.containsAll({'2026-11-01', '2026-11-02'}), isTrue);
    expect(g.unlockedTrophies.containsAll({'first_flame', 'streak_7'}), isTrue);
    expect(g.totalXp, 220);
    expect(g.totalChaptersRead, 15);
    expect(g.earlyMorningCount, 4);
    expect(g.totalQuizzesCount, 9);
  });

  test('ReadingPlanService.mergeCloudPlans une capítulos, dias e usa data inicial mais antiga', () async {
    final svc = ReadingPlanService();
    final planId = svc.allPlans.first.id;
    await svc.activatePlan(planId, isPrimary: true);
    await svc.toggleChapterCompletion(planId, 1, '1:1');

    final remoteMap = UserPlanProgress(
      planId: planId,
      isActive: true,
      isPrimary: false,
      startedAt: DateTime(2025, 1, 1),
      completedDays: const {1, 2},
      currentDayCompletedChapters: const {'1:2', 'egw:PP:2'},
      reminderTime: '08:00',
    ).toMap();

    await svc.mergeCloudPlans([remoteMap]);

    final merged = svc.getProgress(planId)!;
    expect(merged.startedAt, DateTime(2025, 1, 1));
    expect(merged.completedDays.containsAll({1, 2}), isTrue);
    expect(merged.completedChapterKeys.containsAll({'1:1', '1:2', 'egw:PP:2'}), isTrue);
  });
}
