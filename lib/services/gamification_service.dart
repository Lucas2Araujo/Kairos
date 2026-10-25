import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Serviço de gamificação offline-first: gerencia ofensiva diária (streak),
/// XP acumulado e os 7 dias de leitura da semana (Dom-Sáb).
class GamificationService extends ChangeNotifier {
  static final GamificationService _instance = GamificationService._internal();
  factory GamificationService() => _instance;
  GamificationService._internal();

  static const String _kStreakKey = 'gamification_current_streak';
  static const String _kTotalXpKey = 'gamification_total_xp';
  static const String _kLastDateKey = 'gamification_last_reading_date';
  static const String _kActivityDatesKey = 'gamification_activity_dates';
  static const String _kDailyXpPrefix = 'gamification_daily_xp_';

  int _currentStreak = 0;
  int _totalXp = 0;
  int _todayXp = 0;
  String? _lastReadingDate;
  Set<String> _activityDates = {};
  List<bool> _weeklyActivity = List.filled(7, false);
  bool _hasReadToday = false;
  bool _isInitialized = false;

  // Propriedades reativas
  int get currentStreak => _currentStreak;
  int get totalXp => _totalXp;
  int get todayXp => _todayXp;
  Set<String> get activityDates => Set.unmodifiable(_activityDates);
  List<bool> get weeklyActivity => List.unmodifiable(_weeklyActivity);
  bool get hasReadToday => _hasReadToday;
  bool get isInitialized => _isInitialized;

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
    _totalXp = prefs.getInt(_kTotalXpKey) ?? 0;
    _lastReadingDate = prefs.getString(_kLastDateKey);
    final savedDates = prefs.getStringList(_kActivityDatesKey) ?? [];
    _activityDates = savedDates.toSet();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = _formatDate(yesterday);

    _todayXp = prefs.getInt('$_kDailyXpPrefix$todayStr') ?? 0;

    if (_lastReadingDate == todayStr) {
      _hasReadToday = true;
    } else {
      _hasReadToday = false;
      // Se a última leitura foi há mais de 1 dia (não foi nem hoje nem ontem), o streak expirou
      if (_lastReadingDate != null && _lastReadingDate != yesterdayStr) {
        _currentStreak = 0;
      }
    }

    _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);
    _isInitialized = true;
    notifyListeners();
  }

  /// Registra uma leitura para a data de hoje.
  /// Concede +10 XP e atualiza o streak se for a primeira leitura de hoje.
  Future<void> recordReading({required String category}) async {
    if (!_isInitialized) {
      await init();
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final yesterdayStr = _formatDate(yesterday);

    if (_lastReadingDate == todayStr) {
      // Já leu hoje: mantém o streak
      _activityDates.add(todayStr);
      _hasReadToday = true;
      _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);
      await _persist();
      notifyListeners();
      return;
    }

    // Primeira leitura de hoje: concede +10 XP
    _totalXp += 10;
    _todayXp += 10;

    if (_lastReadingDate == yesterdayStr) {
      _currentStreak += 1;
    } else {
      // Se nunca leu ou a última leitura foi há mais de 1 dia: reseta para 1
      _currentStreak = 1;
    }

    _lastReadingDate = todayStr;
    _activityDates.add(todayStr);
    _hasReadToday = true;
    _weeklyActivity = _calculateWeeklyActivity(_activityDates, today);

    await _persist();
    notifyListeners();
  }

  /// Adiciona XP arbitrário (ex: conclusão de quizzes ou lições).
  Future<void> addXp(int amount) async {
    if (!_isInitialized) await init();
    if (amount <= 0) return;
    _totalXp += amount;
    _todayXp += amount;
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kStreakKey, _currentStreak);
      await prefs.setInt(_kTotalXpKey, _totalXp);
      final todayStr = _formatDate(DateTime.now());
      await prefs.setInt('$_kDailyXpPrefix$todayStr', _todayXp);
      if (_lastReadingDate != null) {
        await prefs.setString(_kLastDateKey, _lastReadingDate!);
      } else {
        await prefs.remove(_kLastDateKey);
      }
      await prefs.setStringList(_kActivityDatesKey, _activityDates.toList());
    } catch (e) {
      debugPrint('[GamificationService] Erro ao persistir dados: $e');
    }
  }

  /// Reseta todos os dados e histórico de gamificação (usado para testes).
  Future<void> resetForTesting() async {
    _currentStreak = 0;
    _totalXp = 0;
    _lastReadingDate = null;
    _activityDates.clear();
    _weeklyActivity = List.filled(7, false);
    _hasReadToday = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kStreakKey);
      await prefs.remove(_kTotalXpKey);
      await prefs.remove(_kLastDateKey);
      await prefs.remove(_kActivityDatesKey);
    } catch (_) {}

    notifyListeners();
  }
}
