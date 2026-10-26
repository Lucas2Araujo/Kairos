import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/avatar_config.dart';
import 'classroom_service.dart';

enum FlameType { none, halfFlame, fullFlame }

enum LampMascotState { morningIdle, eveningSleepy, halfFlame, fullFlame }

/// Serviço de gamificação 2.0 offline-first: "A Lamparina das 10 Virgens & O Azeite",
/// com 4 missões diárias, dois níveis de ofensiva (Meia Ofensiva vs. Chama Completa)
/// e meta diária de Tempo com Deus.
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _kStreakKey = 'gamification_current_streak';
  static const String _kFullFlameStreakKey = 'gamification_full_flame_streak';
  static const String _kTotalXpKey = 'gamification_total_xp';
  static const String _kLastDateKey = 'gamification_last_reading_date';
  static const String _kActivityDatesKey = 'gamification_activity_dates';
  static const String _kDailyGoalMinutesKey = 'gamification_daily_goal_minutes';
  static const String _kDailyXpPrefix = 'gamification_daily_xp_';
  static const String _kDailyActionsPrefix = 'gamification_daily_actions_';
  static const String _kDailyFocusSecondsPrefix = 'gamification_focus_seconds_';
  static const String _kTotalChaptersKey = 'gamification_total_chapters_read';
  static const String _kEarlyMorningKey = 'gamification_early_morning_count';
  static const String _kTotalQuizzesKey = 'gamification_total_quizzes_count';
  static const String _kUnlockedTrophiesKey = 'gamification_unlocked_trophies';
  static const String _kAvatarConfigKey = 'gamification_avatar_config';
  static const String _kUseCustomAvatarKey = 'gamification_use_custom_avatar';

  static const int lampCapacity = 100;

  int _currentStreak = 0;
  int _fullFlameStreak = 0;
  int _totalXp = 0; // Reservatório total de gotas de azeite
  int _todayXp = 0; // Gotas de azeite coletadas hoje
  int _dailyGoalMinutes = 15; // Meta padrão: 15 min (5, 10, 15, 30)
  int _todayFocusSeconds = 0; // Segundos acumulados hoje nas telas de estudo
  String? _lastReadingDate;
  Set<String> _activityDates = {};
  List<bool> _weeklyActivity = List.filled(7, false);
  bool _hasReadToday = false;
  bool _isInitialized = false;

  Set<String> _todayActions = {};
  Set<String> _unlockedTrophies = {};

  // Avatar modular
  AvatarConfig _avatarConfig = const AvatarConfig();
  bool _useCustomAvatar = true;

  // Estatísticas para Troféus
  int _totalChaptersRead = 0;
  int _earlyMorningCount = 0;
  int _totalQuizzesCount = 0;

  // Propriedades reativas
  int get currentStreak => _currentStreak;
  int get fullFlameStreak => _fullFlameStreak;
  int get totalXp => _totalXp;
  int get todayXp => _todayXp;
  int get dailyGoalMinutes => _dailyGoalMinutes;
  int get todayFocusSeconds => _todayFocusSeconds;
  int get todayFocusMinutes => _todayFocusSeconds ~/ 60;
  bool get isDailyGoalReached => mission1TimeWithGod;

  int get totalOilDrops => _totalXp;
  int get todayOilDrops => _todayXp;
  bool get isLampFull => _todayXp >= lampCapacity;
  double get lampPercentage => (_todayXp / lampCapacity).clamp(0.0, 1.0);

  // Status das 4 Missões Diárias (Sprint 4)
  // M1: Tempo com Deus (atingir a meta de minutos)
  bool get mission1TimeWithGod => _todayFocusSeconds >= (_dailyGoalMinutes * 60);

  // M2: Palavra Viva (leitura bíblica ou plano)
  bool get mission2LivingWord => _todayActions.contains('bible');

  // M3: Pão Diário (meditação ou lição)
  bool get mission3DailyBread =>
      _todayActions.contains('lesson') || _todayActions.contains('devotional');

  // M4: Desafio da Lição (Quiz do Dia)
  bool get mission4LessonQuiz => _todayActions.contains('quiz');

  /// Total de missões cumpridas no dia de hoje (0 a 4)
  int get completedMissionsCount {
    int count = 0;
    if (mission1TimeWithGod) count++;
    if (mission2LivingWord) count++;
    if (mission3DailyBread) count++;
    if (mission4LessonQuiz) count++;
    return count;
  }

  /// Meia Ofensiva: 1 ou 2 missões cumpridas (mantém o streak vivo)
  bool get isHalfStreakActive => completedMissionsCount >= 1;

  /// Ofensiva Completa: >= 3 missões cumpridas E OBRIGATÓRIO incluir o Quiz (M4)
  bool get isFullFlameActive => completedMissionsCount >= 3 && mission4LessonQuiz;

  /// Multiplicador de azeite (1.5x quando a Chama Completa estiver ativa)
  double get azeiteMultiplier => isFullFlameActive ? 1.5 : 1.0;

  /// Tipo de chama atual da ofensiva
  FlameType get streakFlameType {
    if (isFullFlameActive) return FlameType.fullFlame;
    if (isHalfStreakActive) return FlameType.halfFlame;
    return FlameType.none;
  }

  /// Estado visual reativo da Lamparina Kairós
  LampMascotState get lampMascotState {
    return evaluateMascotState();
  }

  /// Avalia o estado do mascote (permite injetar a hora para testes determinísticos)
  LampMascotState evaluateMascotState({int? currentHour}) {
    if (isFullFlameActive) return LampMascotState.fullFlame;
    if (isHalfStreakActive) return LampMascotState.halfFlame;

    final hour = currentHour ?? DateTime.now().hour;
    if (hour < 12) {
      return LampMascotState.morningIdle;
    } else {
      return LampMascotState.eveningSleepy;
    }
  }

  // Pilares legados
  bool get hasBibleToday => mission2LivingWord;
  bool get hasLessonToday => _todayActions.contains('lesson');
  bool get hasDevotionalToday => _todayActions.contains('devotional');

  Set<String> get activityDates => Set.unmodifiable(_activityDates);
  List<bool> get weeklyActivity => List.unmodifiable(_weeklyActivity);
  Set<String> get unlockedTrophies => Set.unmodifiable(_unlockedTrophies);
  bool get hasReadToday => _hasReadToday;
  bool get isInitialized => _isInitialized;

  // Avatar
  AvatarConfig get avatarConfig => _avatarConfig;
  bool get useCustomAvatar => _useCustomAvatar;

  // Estatísticas para a tela de conquistas
  int get totalChaptersRead => _totalChaptersRead;
  int get earlyMorningCount => _earlyMorningCount;
  int get totalQuizzesCount => _totalQuizzesCount;
  int get completedChaptersCount => _totalChaptersRead;
  int get completedQuizzesCount => _totalQuizzesCount;

  bool get trophyMorningSentinel => _unlockedTrophies.contains('sentinela_manha');
  bool get trophyPrudentVirgin7Days => _unlockedTrophies.contains('virgem_prudente');
  bool get trophyLessonMaster => _unlockedTrophies.contains('mestre_escola_sabatina');
  bool get trophyBerean => _unlockedTrophies.contains('bereano');

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static List<bool> _calculateWeeklyActivity(Set<String> activityDates, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sundayOffset = today.weekday % 7; // Sunday = 0, Monday = 1...
    final sunday = DateTime(today.year, today.month, today.day - sundayOffset);
    final result = <bool>[];
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sunday.year, sunday.month, sunday.day + i);
      result.add(activityDates.contains(_formatDate(day)));
    }
    return result;
  }

  /// Inicializa o estado a partir do SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt(_kStreakKey) ?? 0;
    _fullFlameStreak = prefs.getInt(_kFullFlameStreakKey) ?? 0;
    _totalXp = prefs.getInt(_kTotalXpKey) ?? 0;
    _dailyGoalMinutes = prefs.getInt(_kDailyGoalMinutesKey) ?? 15;
    _lastReadingDate = prefs.getString(_kLastDateKey);
    final savedDates = prefs.getStringList(_kActivityDatesKey) ?? [];
    _activityDates = savedDates.toSet();

    _totalChaptersRead = prefs.getInt(_kTotalChaptersKey) ?? 0;
    _earlyMorningCount = prefs.getInt(_kEarlyMorningKey) ?? 0;
    _totalQuizzesCount = prefs.getInt(_kTotalQuizzesKey) ?? 0;
    final savedTrophies = prefs.getStringList(_kUnlockedTrophiesKey) ?? [];
    _unlockedTrophies = savedTrophies.toSet();

    final avatarJson = prefs.getString(_kAvatarConfigKey);
    if (avatarJson != null) {
      _avatarConfig = AvatarConfig.fromJson(avatarJson);
    }
    _useCustomAvatar = prefs.getBool(_kUseCustomAvatarKey) ?? true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = _formatDate(yesterday);

    _todayXp = prefs.getInt('$_kDailyXpPrefix$todayStr') ?? 0;
    _todayFocusSeconds = prefs.getInt('$_kDailyFocusSecondsPrefix$todayStr') ?? 0;
    final savedActions = prefs.getStringList('$_kDailyActionsPrefix$todayStr') ?? [];
    _todayActions = savedActions.toSet();

    if (_lastReadingDate == todayStr) {
      _hasReadToday = true;
    } else {
      _hasReadToday = false;
      // Se a última leitura foi há mais de 1 dia, o streak expirou
      if (_lastReadingDate != null && _lastReadingDate != yesterdayStr) {
        _currentStreak = 0;
        _fullFlameStreak = 0;
      }
    }

    _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);
    _checkTrophies();
    _isInitialized = true;
    notifyListeners();
  }

  /// Atualiza a meta de minutos diários de Tempo com Deus
  Future<void> setDailyGoalMinutes(int minutes) async {
    if (minutes <= 0) return;
    _dailyGoalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyGoalMinutesKey, minutes);
    notifyListeners();
  }

  /// Adiciona segundos de foco de estudo ativo (chamado pelo SpiritualFocusTracker)
  Future<void> addFocusSeconds(int seconds) async {
    if (seconds <= 0) return;
    if (!_isInitialized) await init();

    final prevMission1 = mission1TimeWithGod;
    _todayFocusSeconds += seconds;

    // Se atingiu a meta de Tempo com Deus agora
    if (!prevMission1 && mission1TimeWithGod) {
      await _recordSpiritualAction('time_with_god', 30);
    }

    final todayStr = _formatDate(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kDailyFocusSecondsPrefix$todayStr', _todayFocusSeconds);

    notifyListeners();
  }

  /// Alias de addFocusSeconds para conveniência
  Future<void> addFocusTime({required int seconds}) => addFocusSeconds(seconds);

  /// Atualiza o Avatar Customizado
  Future<void> updateAvatarConfig(AvatarConfig config) async {
    _avatarConfig = config;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarConfigKey, config.toJson());
    notifyListeners();
  }

  /// Alterna entre Avatar Kairós e Foto do Google
  Future<void> setUseCustomAvatar(bool use) async {
    _useCustomAvatar = use;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseCustomAvatarKey, use);
    notifyListeners();
  }

  /// Registra uma leitura genérica (mantido para compatibilidade total).
  /// No mesmo dia, apenas a primeira leitura genérica pontua gotas de azeite.
  Future<void> recordReading({required String category}) async {
    if (!_isInitialized) await init();
    // Mapeia categoria para a chave de missão correspondente
    String mappedKey = category;
    if (category == 'biblia') mappedKey = 'bible';
    if (category == 'licao' || category == 'escola_sabatina') mappedKey = 'lesson';

    // Se já pontuou hoje através de leitura genérica, não soma XP novamente
    final alreadyReadToday = _todayActions.contains('generic_reading');
    await _recordSpiritualAction('generic_reading', alreadyReadToday ? 0 : 10);
    // Marca a ação específica para efeitos de missões da lamparina
    _todayActions.add(mappedKey);
    _todayActions.add(category);
  }

  /// Conclui o dia de leitura bíblica do plano (+40 gotas de azeite)
  Future<void> recordReadingPlanCompletion() async {
    _totalChaptersRead += 1;
    await _recordSpiritualAction('bible', 40);
  }

  /// Conclui leitura de um capítulo avulso da Bíblia
  Future<void> recordChapterRead() async {
    _totalChaptersRead += 1;
    await _recordSpiritualAction('bible', 40);
  }

  /// Alias para teste / legibilidade
  Future<void> recordBibleChapterRead() => recordChapterRead();

  /// Conclui estudo da Lição da Escola Sabatina (+30 gotas de azeite)
  Future<void> recordSabbathSchoolStudy() async {
    await _recordSpiritualAction('lesson', 30);
  }

  /// Conclui Meditação Diária (+30 gotas de azeite)
  Future<void> recordDevotionalReading() async {
    final hour = DateTime.now().hour;
    if (hour < 8) {
      _earlyMorningCount += 1;
    }
    await _recordSpiritualAction('devotional', 30);
  }

  /// Alias para teste / legibilidade
  Future<void> recordDevotionalRead() => recordDevotionalReading();

  /// Conclui Quiz Bíblico (+10 gotas de azeite) — Missão 4 obrigatória para Chama Completa
  Future<void> recordQuizCompletion() async {
    _totalQuizzesCount += 1;
    await _recordSpiritualAction('quiz', 10);
  }

  /// Alias para teste / legibilidade
  Future<void> recordLessonQuizCompleted() => recordQuizCompletion();

  /// Abastece a lamparina com gotas de azeite e registra ação
  Future<void> _recordSpiritualAction(String actionKey, int baseDrops) async {
    if (!_isInitialized) await init();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = _formatDate(yesterday);

    final finalDrops = (baseDrops * azeiteMultiplier).round();

    // Se essa ação ainda não pontuou hoje, adiciona as gotas
    if (!_todayActions.contains(actionKey)) {
      _todayActions.add(actionKey);
      _totalXp += finalDrops;
      _todayXp += finalDrops;
    }

    if (_lastReadingDate == todayStr) {
      _activityDates.add(todayStr);
      _hasReadToday = true;
      _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);
      if (isFullFlameActive && _fullFlameStreak == 0) {
        _fullFlameStreak = 1;
      }
      _checkTrophies();
      await _persist();
      notifyListeners();
      return;
    }

    // Primeira leitura do dia: atualiza ou incrementa o streak
    if (_lastReadingDate == yesterdayStr) {
      _currentStreak += 1;
      if (isFullFlameActive) {
        _fullFlameStreak += 1;
      }
    } else {
      _currentStreak = 1;
      _fullFlameStreak = isFullFlameActive ? 1 : 0;
    }

    _lastReadingDate = todayStr;
    _activityDates.add(todayStr);
    _hasReadToday = true;
    _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);

    _checkTrophies();
    await _persist();
    notifyListeners();
  }

  /// Adiciona gotas de azeite arbitrariamente (ou XP).
  Future<void> addOilDrops(int amount, {String? source}) async {
    if (!_isInitialized) await init();
    if (amount <= 0) return;
    final finalAmount = (amount * azeiteMultiplier).round();
    _totalXp += finalAmount;
    _todayXp += finalAmount;
    if (source != null) _todayActions.add(source);
    _checkTrophies();
    await _persist();
    notifyListeners();
  }

  /// Alias de addOilDrops para compatibilidade retroativa
  Future<void> addXp(int amount) => addOilDrops(amount);

  /// Verifica e desbloqueia troféus da Sprint 4
  void _checkTrophies() {
    // 1. Sentinela da Manhã: Meditação feita antes das 8h
    if (_earlyMorningCount >= 1) {
      _unlockedTrophies.add('sentinela_manha');
    }
    // 2. Virgem Prudente: 7 dias de Chama Completa consecutivos
    if (_fullFlameStreak >= 7) {
      _unlockedTrophies.add('virgem_prudente');
    }
    // 3. Mestre da Escola Sabatina: 5 quizzes completados
    if (_totalQuizzesCount >= 5) {
      _unlockedTrophies.add('mestre_escola_sabatina');
    }
    // 4. Bereano: 30 capítulos bíblicos lidos
    if (_totalChaptersRead >= 30) {
      _unlockedTrophies.add('bereano');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStreakKey, _currentStreak);
      await prefs.setInt(_kFullFlameStreakKey, _fullFlameStreak);
      await prefs.setInt(_kTotalXpKey, _totalXp);
      final todayStr = _formatDate(DateTime.now());
      await prefs.setInt('$_kDailyXpPrefix$todayStr', _todayXp);
      await prefs.setInt('$_kDailyFocusSecondsPrefix$todayStr', _todayFocusSeconds);
      await prefs.setStringList('$_kDailyActionsPrefix$todayStr', _todayActions.toList());
      if (_lastReadingDate != null) {
        await prefs.setString(_kLastDateKey, _lastReadingDate!);
      } else {
        await prefs.remove(_kLastDateKey);
      }
      await prefs.setStringList(_kActivityDatesKey, _activityDates.toList());
      await prefs.setInt(_kTotalChaptersKey, _totalChaptersRead);
      await prefs.setInt(_kEarlyMorningKey, _earlyMorningCount);
      await prefs.setInt(_kTotalQuizzesKey, _totalQuizzesCount);
      await prefs.setStringList(_kUnlockedTrophiesKey, _unlockedTrophies.toList());
      await prefs.setString(_kAvatarConfigKey, _avatarConfig.toJson());
      await prefs.setBool(_kUseCustomAvatarKey, _useCustomAvatar);

      // Sincroniza silenciosamente em background com a turma Kairós (member_activity_logs)
      ClassroomService().syncCurrentActivitySilently();
    } catch (e) {
      debugPrint('[GamificationService] Erro ao persistir dados: $e');
    }
  }

  /// Reseta todos os dados e histórico de gamificação (usado para testes).
  Future<void> resetForTesting() async {
    _currentStreak = 0;
    _fullFlameStreak = 0;
    _totalXp = 0;
    _todayXp = 0;
    _todayFocusSeconds = 0;
    _dailyGoalMinutes = 15;
    _totalChaptersRead = 0;
    _earlyMorningCount = 0;
    _totalQuizzesCount = 0;
    _todayActions.clear();
    _unlockedTrophies.clear();
    _lastReadingDate = null;
    _activityDates.clear();
    _weeklyActivity = List.filled(7, false);
    _hasReadToday = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStreakKey);
      await prefs.remove(_kFullFlameStreakKey);
      await prefs.remove(_kTotalXpKey);
      await prefs.remove(_kLastDateKey);
      await prefs.remove(_kActivityDatesKey);
      await prefs.remove(_kDailyGoalMinutesKey);
      await prefs.remove(_kTotalChaptersKey);
      await prefs.remove(_kEarlyMorningKey);
      await prefs.remove(_kTotalQuizzesKey);
      await prefs.remove(_kUnlockedTrophiesKey);
      final todayStr = _formatDate(DateTime.now());
      await prefs.remove('$_kDailyXpPrefix$todayStr');
      await prefs.remove('$_kDailyActionsPrefix$todayStr');
      await prefs.remove('$_kDailyFocusSecondsPrefix$todayStr');
    } catch (_) {}

    notifyListeners();
  }
}
