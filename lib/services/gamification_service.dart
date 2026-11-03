import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/avatar_config.dart';
import 'auth_service.dart';
import 'classroom_service.dart';
import 'notification_service.dart';
import 'theme_service.dart';

enum FlameType { none, halfFlame, fullFlame }

enum LampMascotState { morningIdle, eveningSleepy, halfFlame, fullFlame }

enum AchievementCategory {
  streak,
  bible,
  sabbathSchool,
  oilAndPraise,
  community,
}

extension AchievementCategoryInfo on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.streak:
        return 'Ofensiva';
      case AchievementCategory.bible:
        return 'Bíblia & Devoção';
      case AchievementCategory.sabbathSchool:
        return 'Escola Sabatina';
      case AchievementCategory.oilAndPraise:
        return 'Azeite & Louvor';
      case AchievementCategory.community:
        return 'Comunidade';
    }
  }

  IconData get icon {
    switch (this) {
      case AchievementCategory.streak:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.bible:
        return Icons.menu_book_rounded;
      case AchievementCategory.sabbathSchool:
        return Icons.school_rounded;
      case AchievementCategory.oilAndPraise:
        return Icons.opacity_rounded;
      case AchievementCategory.community:
        return Icons.groups_rounded;
    }
  }
}

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final AchievementCategory category;
  final IconData icon;
  final Color color;
  final int current;
  final int target;
  final String? rewardLabel;
  final bool isUnlocked;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.current,
    required this.target,
    required this.isUnlocked,
    this.rewardLabel,
  });

  double get progress => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
}

/// Serviço de gamificação 2.0 offline-first: "A Lamparina das 10 Virgens & O Azeite",
/// com 4 missões diárias, dois níveis de ofensiva, conquistas categorizadas com
/// recompensas de Avatar, integração com Turmas e alertas de desbloqueio.
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

  /// Callback opcional conectado pela camada de UI (ex: AchievementUnlockBanner)
  void Function(AchievementDefinition achievement)? onAchievementUnlocked;

  int _currentStreak = 0;
  int _fullFlameStreak = 0;
  int _totalXp = 0;
  int _todayXp = 0;
  int _dailyGoalMinutes = 15;
  int _todayFocusSeconds = 0;
  String? _lastReadingDate;
  Set<String> _activityDates = {};
  List<bool> _weeklyActivity = List.filled(7, false);
  bool _hasReadToday = false;
  bool _isInitialized = false;

  Set<String> _todayActions = {};
  Set<String> _unlockedTrophies = {};

  AvatarConfig _avatarConfig = const AvatarConfig();
  bool _useCustomAvatar = true;

  int _totalChaptersRead = 0;
  int _earlyMorningCount = 0;
  int _totalQuizzesCount = 0;

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

  bool get mission1TimeWithGod => _todayFocusSeconds >= (_dailyGoalMinutes * 60);
  bool get mission2LivingWord => _todayActions.contains('bible');
  bool get mission3DailyBread =>
      _todayActions.contains('lesson') || _todayActions.contains('devotional');
  bool get mission4LessonQuiz => _todayActions.contains('quiz');

  int get completedMissionsCount {
    int count = 0;
    if (mission1TimeWithGod) count++;
    if (mission2LivingWord) count++;
    if (mission3DailyBread) count++;
    if (mission4LessonQuiz) count++;
    return count;
  }

  bool get isHalfStreakActive => completedMissionsCount >= 1;
  bool get isFullFlameActive => completedMissionsCount >= 3 && mission4LessonQuiz;
  double get azeiteMultiplier => isFullFlameActive ? 1.5 : 1.0;

  FlameType get streakFlameType {
    if (isFullFlameActive) return FlameType.fullFlame;
    if (isHalfStreakActive) return FlameType.halfFlame;
    return FlameType.none;
  }

  LampMascotState get lampMascotState => evaluateMascotState();

  LampMascotState evaluateMascotState({int? currentHour}) {
    if (isFullFlameActive) return LampMascotState.fullFlame;
    if (isHalfStreakActive) return LampMascotState.halfFlame;

    final hour = currentHour ?? DateTime.now().hour;
    return hour < 12 ? LampMascotState.morningIdle : LampMascotState.eveningSleepy;
  }

  bool get hasBibleToday => mission2LivingWord;
  bool get hasLessonToday => _todayActions.contains('lesson');
  bool get hasDevotionalToday => _todayActions.contains('devotional');
  Set<String> get todayActions => Set.unmodifiable(_todayActions);

  Set<String> get activityDates => Set.unmodifiable(_activityDates);
  List<bool> get weeklyActivity => List.unmodifiable(_weeklyActivity);
  Set<String> get unlockedTrophies => Set.unmodifiable(_unlockedTrophies);
  bool get hasReadToday => _hasReadToday;
  bool get isInitialized => _isInitialized;

  AvatarConfig get avatarConfig =>
      _avatarConfig.copyWith(unlockedTrophies: _unlockedTrophies.toList()..sort());
  bool get useCustomAvatar => _useCustomAvatar;

  int get totalChaptersRead => _totalChaptersRead;
  int get earlyMorningCount => _earlyMorningCount;
  int get totalQuizzesCount => _totalQuizzesCount;
  int get completedChaptersCount => _totalChaptersRead;
  int get completedQuizzesCount => _totalQuizzesCount;

  bool get trophyMorningSentinel => _unlockedTrophies.contains('sentinela_manha');
  bool get trophyPrudentVirgin7Days => _unlockedTrophies.contains('virgem_prudente');
  bool get trophyLessonMaster => _unlockedTrophies.contains('mestre_escola_sabatina');
  bool get trophyBerean => _unlockedTrophies.contains('bereano');

  bool isTrophyUnlocked(String id) => _unlockedTrophies.contains(id);

  /// Catálogo completo de conquistas categorizadas com progresso e recompensas de Avatar
  List<AchievementDefinition> get allAchievements {
    final hasClass = ClassroomService().currentClassroom != null ||
        _unlockedTrophies.contains('membro_turma');
    final hasCommunityFlame = _unlockedTrophies.contains('chama_comunidade') ||
        (hasClass && isFullFlameActive);
    final hasTop3 = _unlockedTrophies.contains('destaque_turma');

    int clampTarget(int val, int target, String id) {
      if (_unlockedTrophies.contains(id)) return target;
      return val > target ? target : val;
    }

    bool unlocked(String id, bool cond) => _unlockedTrophies.contains(id) || cond;

    final activeDays = _activityDates.isNotEmpty || _currentStreak >= 1 ? 1 : 0;

    return [
      // 1. Ofensiva
      AchievementDefinition(
        id: 'primeiro_passo',
        title: 'Primeiro Passo',
        description: 'Faça sua primeira leitura devocional ou estudo.',
        category: AchievementCategory.streak,
        icon: Icons.flag_rounded,
        color: Colors.amber,
        current: clampTarget(activeDays, 1, 'primeiro_passo'),
        target: 1,
        rewardLabel: 'Acessório: Aura Dourada',
        isUnlocked: unlocked('primeiro_passo', activeDays >= 1),
      ),
      AchievementDefinition(
        id: 'triplice_alianca',
        title: 'Tríplice Aliança',
        description: 'Mantenha 3 dias consecutivos de ofensiva.',
        category: AchievementCategory.streak,
        icon: Icons.local_fire_department_rounded,
        color: Colors.deepOrange,
        current: clampTarget(_currentStreak, 3, 'triplice_alianca'),
        target: 3,
        isUnlocked: unlocked('triplice_alianca', _currentStreak >= 3),
      ),
      AchievementDefinition(
        id: 'semana_vitoria',
        title: 'Semana de Vitória',
        description: 'Alcance 7 dias consecutivos de ofensiva.',
        category: AchievementCategory.streak,
        icon: Icons.workspace_premium_rounded,
        color: Colors.purpleAccent,
        current: clampTarget(_currentStreak, 7, 'semana_vitoria'),
        target: 7,
        rewardLabel: 'Acessório: Coroa da Vitória',
        isUnlocked: unlocked('semana_vitoria', _currentStreak >= 7),
      ),
      AchievementDefinition(
        id: 'virgem_prudente',
        title: 'Virgem Prudente',
        description: 'Mantenha 7 dias seguidos de Chama Completa.',
        category: AchievementCategory.streak,
        icon: Icons.light_mode_rounded,
        color: Colors.amber.shade700,
        current: clampTarget(_fullFlameStreak, 7, 'virgem_prudente'),
        target: 7,
        rewardLabel: 'Roupa: Manto de Luz Dourada',
        isUnlocked: unlocked('virgem_prudente', _fullFlameStreak >= 7),
      ),
      AchievementDefinition(
        id: 'constancia_mensal',
        title: 'Constância Mensal',
        description: 'Alcance 30 dias de comunhão ininterrupta.',
        category: AchievementCategory.streak,
        icon: Icons.military_tech_rounded,
        color: Colors.teal,
        current: clampTarget(_currentStreak, 30, 'constancia_mensal'),
        target: 30,
        isUnlocked: unlocked('constancia_mensal', _currentStreak >= 30),
      ),

      // 2. Bíblia & Devoção
      AchievementDefinition(
        id: 'sentinela_manha',
        title: 'Sentinela da Manhã',
        description: 'Faça sua meditação matinal antes das 8h.',
        category: AchievementCategory.bible,
        icon: Icons.wb_twilight_rounded,
        color: Colors.orangeAccent,
        current: clampTarget(_earlyMorningCount, 1, 'sentinela_manha'),
        target: 1,
        rewardLabel: 'Acessório: Auréola Sentinela',
        isUnlocked: unlocked('sentinela_manha', _earlyMorningCount >= 1),
      ),
      AchievementDefinition(
        id: 'leitor_dedicado',
        title: 'Leitor Dedicado',
        description: 'Conclua a leitura de 10 capítulos da Bíblia.',
        category: AchievementCategory.bible,
        icon: Icons.auto_stories_rounded,
        color: Colors.indigoAccent,
        current: clampTarget(_totalChaptersRead, 10, 'leitor_dedicado'),
        target: 10,
        isUnlocked: unlocked('leitor_dedicado', _totalChaptersRead >= 10),
      ),
      AchievementDefinition(
        id: 'bereano',
        title: 'Bereano da Palavra',
        description: 'Examine as Escrituras lendo 30 capítulos bíblicos.',
        category: AchievementCategory.bible,
        icon: Icons.menu_book_rounded,
        color: Colors.teal,
        current: clampTarget(_totalChaptersRead, 30, 'bereano'),
        target: 30,
        rewardLabel: 'Roupa: Túnica Bereana',
        isUnlocked: unlocked('bereano', _totalChaptersRead >= 30),
      ),

      // 3. Escola Sabatina & Quiz
      AchievementDefinition(
        id: 'primeiro_quiz',
        title: 'Desafiante da Lição',
        description: 'Conclua seu primeiro Quiz da Escola Sabatina.',
        category: AchievementCategory.sabbathSchool,
        icon: Icons.quiz_rounded,
        color: Colors.blueAccent,
        current: clampTarget(_totalQuizzesCount, 1, 'primeiro_quiz'),
        target: 1,
        isUnlocked: unlocked('primeiro_quiz', _totalQuizzesCount >= 1),
      ),
      AchievementDefinition(
        id: 'mestre_escola_sabatina',
        title: 'Mestre da Escola Sabatina',
        description: 'Conclua o Quiz da Lição em 5 dias.',
        category: AchievementCategory.sabbathSchool,
        icon: Icons.school_rounded,
        color: Colors.deepPurpleAccent,
        current: clampTarget(_totalQuizzesCount, 5, 'mestre_escola_sabatina'),
        target: 5,
        rewardLabel: 'Roupa: Traje Mestre Sabatino',
        isUnlocked: unlocked('mestre_escola_sabatina', _totalQuizzesCount >= 5),
      ),
      AchievementDefinition(
        id: 'sabio_trimestre',
        title: 'Sábio do Trimestre',
        description: 'Acumule 15 quizzes concluídos ao longo do trimestre.',
        category: AchievementCategory.sabbathSchool,
        icon: Icons.psychology_rounded,
        color: Colors.cyan.shade700,
        current: clampTarget(_totalQuizzesCount, 15, 'sabio_trimestre'),
        target: 15,
        isUnlocked: unlocked('sabio_trimestre', _totalQuizzesCount >= 15),
      ),

      // 4. Azeite & Louvor
      AchievementDefinition(
        id: 'iniciante_saber',
        title: 'Iniciante do Saber',
        description: 'Acumule suas primeiras 50 gotas de azeite (XP).',
        category: AchievementCategory.oilAndPraise,
        icon: Icons.bolt_rounded,
        color: Colors.amber,
        current: clampTarget(_totalXp, 50, 'iniciante_saber'),
        target: 50,
        isUnlocked: unlocked('iniciante_saber', _totalXp >= 50),
      ),
      AchievementDefinition(
        id: 'lamparina_cheia',
        title: 'Lamparina Transbordando',
        description: 'Encha 100% da lamparina (100 gotas) em um único dia.',
        category: AchievementCategory.oilAndPraise,
        icon: Icons.lightbulb_rounded,
        color: Colors.orange,
        current: clampTarget(_todayXp, 100, 'lamparina_cheia'),
        target: 100,
        isUnlocked: unlocked('lamparina_cheia', _todayXp >= 100),
      ),
      AchievementDefinition(
        id: 'explorador_biblico',
        title: 'Explorador Bíblico',
        description: 'Acumule 200 XP em estudos, leituras e quizzes.',
        category: AchievementCategory.oilAndPraise,
        icon: Icons.explore_rounded,
        color: Colors.blueAccent,
        current: clampTarget(_totalXp, 200, 'explorador_biblico'),
        target: 200,
        rewardLabel: 'Fundo: Aurora Celestial',
        isUnlocked: unlocked('explorador_biblico', _totalXp >= 200),
      ),
      AchievementDefinition(
        id: 'mestre_palavra',
        title: 'Mestre da Palavra',
        description: 'Atinja o marco memorável de 500 XP acumulados.',
        category: AchievementCategory.oilAndPraise,
        icon: Icons.diamond_rounded,
        color: Colors.indigoAccent,
        current: clampTarget(_totalXp, 500, 'mestre_palavra'),
        target: 500,
        rewardLabel: 'Fundo: Pôr do Sol Dourado',
        isUnlocked: unlocked('mestre_palavra', _totalXp >= 500),
      ),

      // 5. Comunidade & Turma
      AchievementDefinition(
        id: 'membro_turma',
        title: 'Membro da Comunidade',
        description: 'Entre ou crie uma Turma / Pequeno Grupo no Kairós.',
        category: AchievementCategory.community,
        icon: Icons.groups_rounded,
        color: Colors.deepPurple,
        current: hasClass ? 1 : 0,
        target: 1,
        rewardLabel: 'Roupa: Jaqueta da Comunidade',
        isUnlocked: hasClass,
      ),
      AchievementDefinition(
        id: 'chama_comunidade',
        title: 'Chama da Comunidade',
        description: 'Atinja a Chama Completa participando de uma Turma.',
        category: AchievementCategory.community,
        icon: Icons.whatshot_rounded,
        color: Colors.deepOrangeAccent,
        current: hasCommunityFlame ? 1 : 0,
        target: 1,
        rewardLabel: 'Acessório: Insígnia da Turma',
        isUnlocked: hasCommunityFlame,
      ),
      AchievementDefinition(
        id: 'destaque_turma',
        title: 'Destaque da Classe',
        description: 'Alcance o Top 3 de pontuação no mural da sua Turma.',
        category: AchievementCategory.community,
        icon: Icons.emoji_events_rounded,
        color: Colors.amber.shade800,
        current: hasTop3 ? 1 : 0,
        target: 1,
        isUnlocked: hasTop3,
      ),
    ];
  }

  AchievementDefinition? getAchievementById(String id) {
    for (final a in allAchievements) {
      if (a.id == id) return a;
    }
    return null;
  }

  static String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  static List<bool> _calculateWeeklyActivity(Set<String> activityDates, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sundayOffset = today.weekday % 7;
    final sunday = DateTime(today.year, today.month, today.day - sundayOffset);
    final result = <bool>[];
    for (int i = 0; i < 7; i++) {
      final day = DateTime(sunday.year, sunday.month, sunday.day + i);
      result.add(activityDates.contains(_formatDate(day)));
    }
    return result;
  }

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
      _unlockedTrophies.addAll(_avatarConfig.unlockedTrophies);
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
      if (_lastReadingDate != null && _lastReadingDate != yesterdayStr) {
        _currentStreak = 0;
        _fullFlameStreak = 0;
      }
    }

    _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);
    _checkTrophies(notifyNew: false);
    _isInitialized = true;
    notifyListeners();

    syncWithCloud();
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    if (minutes <= 0) return;
    _dailyGoalMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyGoalMinutesKey, minutes);
    notifyListeners();
  }

  Future<void> addFocusSeconds(int seconds) async {
    if (seconds <= 0) return;
    if (!_isInitialized) await init();

    final prevMission1 = mission1TimeWithGod;
    _todayFocusSeconds += seconds;

    if (!prevMission1 && mission1TimeWithGod) {
      await _recordSpiritualAction('time_with_god', 30);
    }

    final todayStr = _formatDate(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_kDailyFocusSecondsPrefix$todayStr', _todayFocusSeconds);

    notifyListeners();
  }

  Future<void> addFocusTime({required int seconds}) => addFocusSeconds(seconds);

  Future<void> updateAvatarConfig(AvatarConfig config) async {
    _avatarConfig = config.copyWith(unlockedTrophies: _unlockedTrophies.toList()..sort());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAvatarConfigKey, _avatarConfig.toJson());
    notifyListeners();
    ClassroomService().syncMemberAvatarSilently();
  }

  Future<void> setUseCustomAvatar(bool use) async {
    _useCustomAvatar = use;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseCustomAvatarKey, use);
    notifyListeners();
  }

  /// Desbloqueia uma conquista contextual da comunidade/turma (ex: entrar na turma, Top 3)
  Future<void> unlockCommunityAchievement(String trophyId) async {
    if (_unlockedTrophies.contains(trophyId)) return;
    _unlockedTrophies.add(trophyId);
    final def = getAchievementById(trophyId);
    if (def != null) {
      _emitUnlockAlert(def);
    }
    await _persistLocallyOnly();
    ClassroomService().syncMemberAvatarSilently();
    notifyListeners();
  }

  Future<void> recordReading({required String category}) async {
    if (!_isInitialized) await init();
    String mappedKey = category;
    if (category == 'biblia') mappedKey = 'bible';
    if (category == 'licao' || category == 'escola_sabatina') mappedKey = 'lesson';

    _todayActions.add(mappedKey);
    _todayActions.add(category);

    final alreadyReadToday = _todayActions.contains('generic_reading');
    await _recordSpiritualAction('generic_reading', alreadyReadToday ? 0 : 10);
  }

  Future<void> recordReadingPlanCompletion() async {
    _totalChaptersRead += 1;
    await _recordSpiritualAction('bible', 40);
  }

  Future<void> recordChapterRead() async {
    _totalChaptersRead += 1;
    await _recordSpiritualAction('bible', 40);
  }

  Future<void> recordBibleChapterRead() => recordChapterRead();

  Future<void> recordSabbathSchoolStudy() async {
    await _recordSpiritualAction('lesson', 30);
  }

  Future<void> recordDevotionalReading() async {
    final hour = DateTime.now().hour;
    if (hour < 8) {
      _earlyMorningCount += 1;
    }
    await _recordSpiritualAction('devotional', 30);
  }

  Future<void> recordDevotionalRead() => recordDevotionalReading();

  Future<void> recordQuizCompletion() async {
    _totalQuizzesCount += 1;
    await _recordSpiritualAction('quiz', 10);
  }

  Future<void> recordLessonQuizCompleted() => recordQuizCompletion();

  Future<void> _recordSpiritualAction(String actionKey, int baseDrops) async {
    if (!_isInitialized) await init();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = _formatDate(yesterday);

    final finalDrops = (baseDrops * azeiteMultiplier).round();

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
      _checkTrophies(notifyNew: true);
      await _persist();
      notifyListeners();
      return;
    }

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

    _checkTrophies(notifyNew: true);
    await _persist();
    notifyListeners();
  }

  Future<void> addOilDrops(int amount, {String? source}) async {
    if (!_isInitialized) await init();
    if (amount <= 0) return;
    final finalAmount = (amount * azeiteMultiplier).round();
    _totalXp += finalAmount;
    _todayXp += finalAmount;
    if (source != null) _todayActions.add(source);
    _checkTrophies(notifyNew: true);
    await _persist();
    notifyListeners();
  }

  Future<void> addXp(int amount) => addOilDrops(amount);

  void _checkTrophies({required bool notifyNew}) {
    final newlyUnlocked = <AchievementDefinition>[];

    for (final def in allAchievements) {
      if (def.isUnlocked && !_unlockedTrophies.contains(def.id)) {
        _unlockedTrophies.add(def.id);
        newlyUnlocked.add(def);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      _avatarConfig = _avatarConfig.copyWith(
        unlockedTrophies: _unlockedTrophies.toList()..sort(),
      );
      if (notifyNew) {
        for (final def in newlyUnlocked) {
          _emitUnlockAlert(def);
        }
        ClassroomService().syncMemberAvatarSilently();
      }
    }
  }

  void _emitUnlockAlert(AchievementDefinition def) {
    try {
      if (ThemeService().achievementNotificationsEnabled) {
        final rewardSuffix = def.rewardLabel != null ? ' • 🎁 ${def.rewardLabel}' : '';
        NotificationService().showInstantNotification(
          id: 'trophy_${def.id}',
          title: '🏆 Conquista Desbloqueada: ${def.title}!',
          message: '${def.description}$rewardSuffix',
        );
      }
      onAchievementUnlocked?.call(def);
    } catch (e) {
      debugPrint('[GamificationService] Aviso ao notificar conquista: $e');
    }
  }

  Future<void> _persistLocallyOnly() async {
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
    await prefs.setString(_kAvatarConfigKey, avatarConfig.toJson());
    await prefs.setBool(_kUseCustomAvatarKey, _useCustomAvatar);
  }

  Future<void> _persist() async {
    try {
      await _persistLocallyOnly();
      ClassroomService().syncCurrentActivitySilently();
      AuthService().syncPreferencesToCloud();
    } catch (e) {
      debugPrint('[GamificationService] Erro ao persistir dados: $e');
    }
  }

  Future<void> syncWithCloud({bool force = false}) async {
    final user = AuthService().currentUser;
    if (user == null) return;
    if (!_isInitialized) await init();

    bool hasChanged = false;
    final todayStr = _formatDate(DateTime.now());

    try {
      final remoteLog = await ClassroomService().fetchTodayUserActivity();
      if (remoteLog != null) {
        if (remoteLog.didDailyQuiz && !_todayActions.contains('quiz')) {
          _todayActions.add('quiz');
          if (_totalQuizzesCount < 1) {
            _totalQuizzesCount = 1;
          }
          hasChanged = true;
        }
        if (remoteLog.minutesWithGod > 0) {
          final remoteSeconds = remoteLog.minutesWithGod * 60;
          if (remoteSeconds > _todayFocusSeconds) {
            _todayFocusSeconds = remoteSeconds;
            hasChanged = true;
          }
        }
        if (remoteLog.totalXp > _totalXp) {
          _totalXp = remoteLog.totalXp;
          hasChanged = true;
        }
      }

      final meta = user.rawMetadata;
      final savedMetaDate = meta['gamification_today_date']?.toString();
      if (savedMetaDate == todayStr) {
        final rawActions = meta['gamification_today_actions'];
        if (rawActions is List) {
          for (final a in rawActions) {
            final strA = a.toString();
            if (_todayActions.add(strA)) {
              hasChanged = true;
            }
          }
        }
        final remoteFocusSec = (meta['gamification_focus_seconds'] as num?)?.toInt() ?? 0;
        if (remoteFocusSec > _todayFocusSeconds) {
          _todayFocusSeconds = remoteFocusSec;
          hasChanged = true;
        }
      }

      final remoteTotalXp = (meta['gamification_total_xp'] as num?)?.toInt() ?? 0;
      if (remoteTotalXp > _totalXp) {
        _totalXp = remoteTotalXp;
        hasChanged = true;
      }

      final remoteStreak = (meta['gamification_streak'] as num?)?.toInt() ?? 0;
      if (remoteStreak > _currentStreak) {
        _currentStreak = remoteStreak;
        hasChanged = true;
      }

      final remoteFullStreak = (meta['gamification_full_flame_streak'] as num?)?.toInt() ?? 0;
      if (remoteFullStreak > _fullFlameStreak) {
        _fullFlameStreak = remoteFullStreak;
        hasChanged = true;
      }

      if (hasChanged) {
        _activityDates.add(todayStr);
        _hasReadToday = true;
        _weeklyActivity = _calculateWeeklyActivity(_activityDates, DateTime.now());
        _checkTrophies(notifyNew: false);
        await _persistLocallyOnly();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[GamificationService] Aviso ao sincronizar com a nuvem: $e');
    }
  }

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
    _avatarConfig = const AvatarConfig();
    _useCustomAvatar = true;
    onAchievementUnlocked = null;
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
      await prefs.remove(_kAvatarConfigKey);
      final todayStr = _formatDate(DateTime.now());
      await prefs.remove('$_kDailyXpPrefix$todayStr');
      await prefs.remove('$_kDailyActionsPrefix$todayStr');
      await prefs.remove('$_kDailyFocusSecondsPrefix$todayStr');
    } catch (_) {}

    notifyListeners();
  }
}
