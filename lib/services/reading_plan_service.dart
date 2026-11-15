import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_manager.dart';
import '../models/reading_plan_models.dart';
import 'gamification_service.dart';
import 'notification_service.dart';

/// Motor offline-first de gerenciamento de Planos de Leitura Bíblica
class ReadingPlanService extends ChangeNotifier {
  static final ReadingPlanService _instance = ReadingPlanService._internal();
  factory ReadingPlanService() => _instance;
  ReadingPlanService._internal();

  static const String _kPlansPrefPrefix = 'user_reading_plan_';

  final List<ReadingPlan> _catalog = NativeReadingPlans.getPlans();
  final Map<String, UserPlanProgress> _userProgress = {};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  List<ReadingPlan> get allPlans => List.unmodifiable(_catalog);

  /// Lista de planos atualmente em andamento
  List<({ReadingPlan plan, UserPlanProgress progress})> get activePlans {
    final list = <({ReadingPlan plan, UserPlanProgress progress})>[];
    for (final plan in _catalog) {
      final prog = _userProgress[plan.id];
      if (prog != null && prog.isActive) {
        list.add((plan: plan, progress: prog));
      }
    }
    return list;
  }

  /// Retorna o plano marcado como principal (ou o primeiro ativo, ou null)
  ({ReadingPlan plan, UserPlanProgress progress})? get primaryPlan {
    final actives = activePlans;
    if (actives.isEmpty) return null;
    return actives.firstWhere(
      (item) => item.progress.isPrimary,
      orElse: () => actives.first,
    );
  }

  /// Retorna se um plano está ativo
  bool isPlanActive(String planId) => _userProgress[planId]?.isActive ?? false;

  /// Busca o plano pelo ID
  ReadingPlan? getPlanById(String planId) {
    try {
      return _catalog.firstWhere((p) => p.id == planId);
    } catch (_) {
      return null;
    }
  }

  /// Busca o progresso do usuário para um plano específico
  UserPlanProgress? getProgress(String planId) => _userProgress[planId];

  bool get _isTestEnv {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Inicializa tabela SQLite e carrega os planos do usuário
  Future<void> init() async {
    if (_isInitialized) return;

    if (_isTestEnv) {
      await _loadFromPreferences();
      _isInitialized = true;
      notifyListeners();
      return;
    }

    try {
      await _ensureTableExists();
      await _loadFromSqlite();
    } catch (e) {
      debugPrint('[ReadingPlanService] Fallback de carregamento para SharedPreferences: $e');
      await _loadFromPreferences();
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Garante que a tabela user_reading_plans existe no hinario.db
  Future<void> _ensureTableExists() async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        CREATE TABLE IF NOT EXISTS user_reading_plans (
          plan_id TEXT PRIMARY KEY,
          is_active INTEGER NOT NULL DEFAULT 0,
          is_primary INTEGER NOT NULL DEFAULT 0,
          started_at TEXT NOT NULL,
          completed_days_json TEXT NOT NULL DEFAULT '[]',
          current_chapters_json TEXT NOT NULL DEFAULT '[]',
          reminder_time TEXT
        );
      ''');
    } catch (e) {
      debugPrint('[ReadingPlanService] Erro ao criar tabela user_reading_plans: $e');
    }
  }

  Future<void> _loadFromSqlite() async {
    final db = await DatabaseManager().getDatabase('hinario.db');
    final rows = db.select('SELECT * FROM user_reading_plans;');
    _userProgress.clear();
    for (final row in rows) {
      final prog = UserPlanProgress.fromMap(Map<String, dynamic>.from(row));
      _userProgress[prog.planId] = prog;
    }
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _userProgress.clear();
    for (final plan in _catalog) {
      final jsonStr = prefs.getString('$_kPlansPrefPrefix${plan.id}');
      if (jsonStr != null) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          _userProgress[plan.id] = UserPlanProgress.fromMap(map);
        } catch (_) {}
      }
    }
  }

  Future<void> _persistPlan(UserPlanProgress progress) async {
    _userProgress[progress.planId] = progress;

    if (!_isTestEnv) {
      // 1. Tenta persistir no SQLite se disponível
      try {
        final db = await DatabaseManager().getDatabase('hinario.db');
        db.execute('''
          INSERT OR REPLACE INTO user_reading_plans (
            plan_id, is_active, is_primary, started_at, completed_days_json, current_chapters_json, reminder_time
          ) VALUES (?, ?, ?, ?, ?, ?, ?);
        ''', [
          progress.planId,
          progress.isActive ? 1 : 0,
          progress.isPrimary ? 1 : 0,
          progress.startedAt.toIso8601String(),
          jsonEncode(progress.completedDays.toList()..sort()),
          jsonEncode(progress.currentDayCompletedChapters.toList()..sort()),
          progress.reminderTime,
        ]);
      } catch (e) {
        debugPrint('[ReadingPlanService] SQLite indisponível ou em fallback: $e');
      }
    }

    // 2. Persiste espelho no SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kPlansPrefPrefix${progress.planId}',
        jsonEncode(progress.toMap()),
      );
    } catch (_) {}
  }

  /// Ativa um plano para o usuário
  Future<void> activatePlan(
    String planId, {
    bool isPrimary = false,
    String? reminderTime,
  }) async {
    final plan = getPlanById(planId);
    if (plan == null) return;

    final existing = _userProgress[planId];
    final hasAnyActive = activePlans.isNotEmpty;

    // Se é o primeiro plano ativado ou foi requisitado como principal
    final makePrimary = isPrimary || !hasAnyActive;

    if (makePrimary) {
      await _demoteAllPrimary();
    }

    final updated = (existing ??
            UserPlanProgress(
              planId: planId,
              isActive: true,
              isPrimary: makePrimary,
              startedAt: DateTime.now(),
              completedDays: {},
              currentDayCompletedChapters: {},
              reminderTime: reminderTime ?? '07:00',
            ))
        .copyWith(
      isActive: true,
      isPrimary: makePrimary,
      reminderTime: reminderTime ?? existing?.reminderTime ?? '07:00',
    );

    await _persistPlan(updated);

    // Agenda lembrete de notificação local
    if (updated.reminderTime != null) {
      NotificationService().scheduleDailyReminder(
        id: 'plan_${plan.id}',
        time: updated.reminderTime!,
        title: 'Plano de Leitura: ${plan.title}',
        message: 'Hora de se alimentar da Palavra de Deus com a leitura de hoje!',
        route: '/biblia?plano=${plan.id}',
      );
    }

    notifyListeners();
  }

  /// Define o dia atual do plano (1-based), permitindo começar da metade ou saltar para qualquer dia.
  Future<void> jumpToDay(
    String planId,
    int targetDay, {
    bool markPreviousAsCompleted = true,
  }) async {
    final plan = getPlanById(planId);
    if (plan == null) return;
    final clampedDay = targetDay.clamp(1, plan.daysCount);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Para que calculateCurrentDay resulte em clampedDay:
    // calendarDay = today.difference(startedAt).inDays + 1 = clampedDay
    // => startedAt = today - (clampedDay - 1) dias
    final newStartedAt = today.subtract(Duration(days: clampedDay - 1));

    final existing = _userProgress[planId];
    final hasAnyActive = activePlans.isNotEmpty;
    final makePrimary = existing?.isPrimary ?? !hasAnyActive;

    if (makePrimary) {
      await _demoteAllPrimary();
    }

    Set<int> newCompletedDays;
    if (markPreviousAsCompleted) {
      newCompletedDays = {for (int i = 1; i < clampedDay; i++) i};
    } else {
      newCompletedDays = existing != null
          ? Set<int>.from(existing.completedDays.where((d) => d < clampedDay))
          : <int>{};
    }

    final updated = (existing ??
            UserPlanProgress(
              planId: planId,
              isActive: true,
              isPrimary: makePrimary,
              startedAt: newStartedAt,
              completedDays: newCompletedDays,
              currentDayCompletedChapters: {},
            ))
        .copyWith(
      isActive: true,
      isPrimary: makePrimary,
      startedAt: newStartedAt,
      completedDays: newCompletedDays,
      currentDayCompletedChapters: {},
    );

    await _persistPlan(updated);

    if (updated.reminderTime != null) {
      NotificationService().scheduleDailyReminder(
        id: 'plan_${plan.id}',
        time: updated.reminderTime!,
        title: 'Plano de Leitura: ${plan.title}',
        message: 'Hora de se alimentar da Palavra de Deus com a leitura de hoje!',
        route: '/biblia?plano=${plan.id}',
      );
    }

    notifyListeners();
  }

  /// Desativa um plano
  Future<void> deactivatePlan(String planId) async {
    final existing = _userProgress[planId];
    if (existing == null) return;

    final wasPrimary = existing.isPrimary;
    final updated = existing.copyWith(isActive: false, isPrimary: false);
    await _persistPlan(updated);

    NotificationService().cancelReminder('plan_$planId');

    // Se era o plano principal e ainda temos outros ativos, promove outro a principal
    if (wasPrimary) {
      final remaining = activePlans;
      if (remaining.isNotEmpty) {
        await setPrimaryPlan(remaining.first.plan.id);
      }
    }

    notifyListeners();
  }

  /// Define um plano como o Principal para exibição no Banner da Home
  Future<void> setPrimaryPlan(String planId) async {
    final target = _userProgress[planId];
    if (target == null || !target.isActive) return;

    await _demoteAllPrimary();
    final updated = target.copyWith(isPrimary: true);
    await _persistPlan(updated);
    notifyListeners();
  }

  Future<void> _demoteAllPrimary() async {
    for (final entry in _userProgress.entries) {
      if (entry.value.isPrimary) {
        final demoted = entry.value.copyWith(isPrimary: false);
        await _persistPlan(demoted);
      }
    }
  }

  /// Altera o horário do lembrete diário de um plano
  Future<void> setReminderTime(String planId, String? time) async {
    final prog = _userProgress[planId];
    if (prog == null) return;

    final updated = prog.copyWith(reminderTime: time);
    await _persistPlan(updated);

    if (time != null && prog.isActive) {
      final plan = getPlanById(planId);
      NotificationService().scheduleDailyReminder(
        id: 'plan_$planId',
        time: time,
        title: 'Plano de Leitura: ${plan?.title ?? ''}',
        message: 'Hora de ler o capítulo de hoje!',
        route: '/biblia?plano=$planId',
      );
    } else {
      NotificationService().cancelReminder('plan_$planId');
    }

    notifyListeners();
  }

  /// Alterna a conclusão de um capítulo individual no dia atual
  Future<void> toggleChapterCompletion(
    String planId,
    int dayIndex,
    String chapterKey, // ex: "1:34" (bookId:chapter)
  ) async {
    final prog = _userProgress[planId];
    final plan = getPlanById(planId);
    if (prog == null || plan == null) return;

    final currentChapters = Set<String>.from(prog.currentDayCompletedChapters);
    if (currentChapters.contains(chapterKey)) {
      currentChapters.remove(chapterKey);
    } else {
      currentChapters.add(chapterKey);
    }

    // Se todos os capítulos do dia foram marcados, conclui o dia automaticamente!
    final dayObj = plan.getDay(dayIndex);
    final allDone = dayObj != null &&
        dayObj.chapters.every((c) => currentChapters.contains('${c.bookId}:${c.chapter}'));

    final completedDays = Set<int>.from(prog.completedDays);
    if (allDone) {
      completedDays.add(dayIndex);
      // Abastece a lamparina no GamificationService (+40 gotas)
      await GamificationService().recordReadingPlanCompletion();
    } else {
      completedDays.remove(dayIndex);
    }

    final updated = prog.copyWith(
      currentDayCompletedChapters: currentChapters,
      completedDays: completedDays,
    );

    await _persistPlan(updated);
    notifyListeners();
  }

  /// Conclui a Etapa 2 (capítulo do Espírito de Profecia) de um dia de plano, de forma idempotente (+25 gotas).
  Future<void> completeEgwMissionStep(
    String planId,
    int dayIndex,
    EgwPlanMissionRef mission,
  ) async {
    final prog = _userProgress[planId];
    if (prog == null) return;
    if (prog.currentDayCompletedChapters.contains(mission.stepKey)) return;

    final updatedChapters = Set<String>.from(prog.currentDayCompletedChapters)
      ..add(mission.stepKey);
    final updated = prog.copyWith(currentDayCompletedChapters: updatedChapters);

    await _persistPlan(updated);
    await GamificationService().addOilDrops(25, source: 'egw_plan_mission');
    notifyListeners();
  }

  /// Conclui o dia completo do plano manualmente (botão "Concluir Leitura do Dia")
  Future<void> completeDay(String planId, int dayIndex) async {
    final prog = _userProgress[planId];
    final plan = getPlanById(planId);
    if (prog == null || plan == null) return;

    final completedDays = Set<int>.from(prog.completedDays)..add(dayIndex);
    final currentChapters = Set<String>.from(prog.currentDayCompletedChapters);

    // Marca todos os capítulos do dia
    final dayObj = plan.getDay(dayIndex);
    if (dayObj != null) {
      for (final ch in dayObj.chapters) {
        currentChapters.add('${ch.bookId}:${ch.chapter}');
      }
    }

    final updated = prog.copyWith(
      completedDays: completedDays,
      currentDayCompletedChapters: currentChapters,
    );

    await _persistPlan(updated);

    // Abastece a Lamparina com +40 gotas de azeite e acende/mantém a chama da ofensiva
    await GamificationService().recordReadingPlanCompletion();

    notifyListeners();
  }

  /// Avança dinamicamente o plano até o dia indicado e marca todos os dias intermediários e o dia alvo como concluídos.
  /// Usado quando o usuário lê capítulos à frente do dia do calendário.
  Future<void> advanceAndCompleteUpToDay(String planId, int targetDay) async {
    final plan = getPlanById(planId);
    final prog = _userProgress[planId];
    if (plan == null || prog == null) return;

    final clampedDay = targetDay.clamp(1, plan.daysCount);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newStartedAt = today.subtract(Duration(days: clampedDay - 1));

    final currentDay = prog.calculateCurrentDay(plan.daysCount);
    final completedDays = Set<int>.from(prog.completedDays);
    final currentChapters = Set<String>.from(prog.currentDayCompletedChapters);

    // Marca todos os dias intermediários e o dia alvo como concluídos
    final startMark = currentDay < clampedDay ? currentDay : 1;
    for (int d = startMark; d <= clampedDay; d++) {
      completedDays.add(d);
      final dayObj = plan.getDay(d);
      if (dayObj != null) {
        for (final ch in dayObj.chapters) {
          currentChapters.add('${ch.bookId}:${ch.chapter}');
        }
      }
    }

    final updated = prog.copyWith(
      startedAt: newStartedAt,
      completedDays: completedDays,
      currentDayCompletedChapters: currentChapters,
    );

    await _persistPlan(updated);

    // Abastece a lamparina no GamificationService (+40 gotas)
    await GamificationService().recordReadingPlanCompletion();

    notifyListeners();
  }

  /// Verifica se um capítulo específico está marcado como lido no progresso
  bool isChapterCompleted(String planId, String chapterKey) {
    final prog = _userProgress[planId];
    if (prog == null) return false;
    return prog.currentDayCompletedChapters.contains(chapterKey);
  }

  /// Retorna as informações do dia atual para exibição na Home / Pílula
  ({
    int currentDayIndex,
    ReadingPlanDay? day,
    bool isDayCompleted,
    int totalChapters,
    int completedChapters,
  })? getTodayStatus(String planId) {
    final plan = getPlanById(planId);
    final prog = _userProgress[planId];
    if (plan == null || prog == null || !prog.isActive) return null;

    final dayIdx = prog.calculateCurrentDay(plan.daysCount);
    final day = plan.getDay(dayIdx);
    final isDayCompleted = prog.completedDays.contains(dayIdx);

    int compCount = 0;
    if (day != null) {
      for (final ch in day.chapters) {
        if (prog.currentDayCompletedChapters.contains('${ch.bookId}:${ch.chapter}')) {
          compCount++;
        }
      }
    }

    return (
      currentDayIndex: dayIdx,
      day: day,
      isDayCompleted: isDayCompleted,
      totalChapters: day?.chapters.length ?? 0,
      completedChapters: compCount,
    );
  }

  /// Exporta todos os planos do usuário para sincronização com a nuvem.
  List<Map<String, dynamic>> exportPlansForCloud() {
    return _userProgress.values.map((p) => p.toMap()).toList();
  }

  /// Mescla progresso de planos vindos da nuvem fazendo união de dias e capítulos lidos.
  Future<void> mergeCloudPlans(List<dynamic> cloudPlans) async {
    if (cloudPlans.isEmpty) return;
    if (!_isInitialized && !_isTestEnv) {
      await init();
    }
    bool changed = false;

    for (final raw in cloudPlans) {
      if (raw is! Map) continue;
      try {
        final remote = UserPlanProgress.fromMap(Map<String, dynamic>.from(raw));
        final local = _userProgress[remote.planId];
        if (local == null) {
          await _persistPlan(remote);
          changed = true;
          continue;
        }

        final mergedDays = <int>{...local.completedDays, ...remote.completedDays};
        final mergedChapters = <String>{
          ...local.currentDayCompletedChapters,
          ...remote.currentDayCompletedChapters,
        };
        final earliestStart = local.startedAt.isBefore(remote.startedAt)
            ? local.startedAt
            : remote.startedAt;

        final merged = local.copyWith(
          isActive: local.isActive || remote.isActive,
          isPrimary: local.isPrimary || remote.isPrimary,
          startedAt: earliestStart,
          completedDays: mergedDays,
          currentDayCompletedChapters: mergedChapters,
          reminderTime: local.reminderTime ?? remote.reminderTime,
        );

        if (mergedDays.length != local.completedDays.length ||
            mergedChapters.length != local.currentDayCompletedChapters.length ||
            earliestStart != local.startedAt ||
            merged.isActive != local.isActive) {
          await _persistPlan(merged);
          changed = true;
        }
      } catch (e) {
        debugPrint('[ReadingPlanService] Erro ao mesclar plano remoto: $e');
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Limpa e reseta dados para testes
  Future<void> resetForTesting() async {
    _userProgress.clear();
    if (!_isTestEnv) {
      try {
        final db = await DatabaseManager().getDatabase('hinario.db');
        db.execute('DELETE FROM user_reading_plans;');
      } catch (_) {}
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final p in _catalog) {
        await prefs.remove('$_kPlansPrefPrefix${p.id}');
      }
    } catch (_) {}
    notifyListeners();
  }
}
