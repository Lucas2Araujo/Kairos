import 'package:flutter/foundation.dart';
import '../data/repositories/quiz_repository.dart';
import '../models/quiz_question.dart';
import '../services/classroom_service.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';

class QuizController extends ChangeNotifier {
  final QuizRepository _repository;

  QuizController({QuizRepository? repository})
      : _repository = repository ?? QuizRepository();

  List<QuizQuestion> _allQuestions = [];
  List<QuizQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedOption;
  bool _hasSubmitted = false;
  QuizResult? _lastResult;

  int _score = 0;
  int _streak = 0;
  int _totalXp = 0;
  bool _isCompleted = false;
  bool _isLoading = false;
  bool _isViewingHub = false;

  String _currentCategory = 'adultos';
  String _quizMode = 'diario'; // 'diario' ou 'maratona'
  String _selectedDayId = 'd1';

  static const List<Map<String, String>> dayDefinitions = [
    {'id': 'd1', 'title': 'Sábado'},
    {'id': 'd2', 'title': 'Domingo'},
    {'id': 'd3', 'title': 'Segunda'},
    {'id': 'd4', 'title': 'Terça'},
    {'id': 'd5', 'title': 'Quarta'},
    {'id': 'd6', 'title': 'Quinta'},
    {'id': 'd7', 'title': 'Sexta'},
  ];

  String get currentCategory => _currentCategory;
  String get quizMode => _quizMode;
  List<QuizQuestion> get questions => _questions;
  String get selectedDayId => _selectedDayId;
  String get todayDayId => _getDefaultDayId();
  bool get isTodayLesson => _selectedDayId == _getDefaultDayId();
  bool get isRevisionAvailable => !isTodayLesson;
  bool get isRevisionMode => _quizMode == 'revisao';
  bool get isViewingHub => _isViewingHub;
  int get currentIndex => _currentIndex;
  QuizQuestion? get currentQuestion =>
      _questions.isNotEmpty && _currentIndex < _questions.length
          ? _questions[_currentIndex]
          : null;
  int? get selectedOption => _selectedOption;
  bool get hasSubmitted => _hasSubmitted;
  QuizResult? get lastResult => _lastResult;
  int get score => _score;
  int get streak => _streak;
  int get totalXp => _totalXp;
  bool get isCompleted => _isCompleted;
  bool get isLoading => _isLoading;
  double get progress =>
      _questions.isEmpty ? 0.0 : ((_currentIndex + 1) / _questions.length);

  int get todayQuestionsCount {
    final tId = _getDefaultDayId();
    return _allQuestions.where((q) => q.dayId == tId).length;
  }

  int get revisionQuestionsCount {
    final todayNum = int.tryParse(_getDefaultDayId().replaceAll(RegExp(r'\D'), '')) ?? 1;
    return _allQuestions.where((q) {
      final qNum = int.tryParse(q.dayId.replaceAll(RegExp(r'\D'), '')) ?? 1;
      return qNum >= 1 && qNum <= todayNum;
    }).length;
  }

  String get todayDayTitle {
    final tId = _getDefaultDayId();
    for (final d in dayDefinitions) {
      if (d['id'] == tId) return d['title'] ?? 'Hoje';
    }
    return 'Hoje';
  }

  Future<void> init({String? category, String? dayId, String? mode, bool showHub = false}) async {
    final themeCategory = ThemeService().defaultSabbathSchoolCategory;
    if (category != null) {
      _currentCategory = category;
    } else if (themeCategory.isNotEmpty) {
      _currentCategory = themeCategory;
    }
    if (mode != null) {
      _quizMode = mode;
    }
    _isViewingHub = showHub;
    _isLoading = true;
    notifyListeners();

    _allQuestions = await _repository.getQuestions(category: _currentCategory);
    
    _selectedDayId = dayId ?? _getDefaultDayId();
    _applyFilter();
    
    _isLoading = false;
    notifyListeners();
  }

  void startDailyQuiz() {
    _selectedDayId = _getDefaultDayId();
    _quizMode = 'diario';
    _isViewingHub = false;
    _applyFilter();
    notifyListeners();
  }

  void startRevisionQuiz() {
    _quizMode = 'revisao';
    _isViewingHub = false;
    _applyFilter();
    notifyListeners();
  }

  void returnToHub() {
    _isViewingHub = true;
    _resetQuizState();
    notifyListeners();
  }

  String _getDefaultDayId() {
    // Mapeia DateTime.weekday para d1..d7 (Sábado=d1, Domingo=d2, ...)
    final weekday = DateTime.now().weekday;
    switch (weekday) {
      case DateTime.saturday:
        return 'd1';
      case DateTime.sunday:
        return 'd2';
      case DateTime.monday:
        return 'd3';
      case DateTime.tuesday:
        return 'd4';
      case DateTime.wednesday:
        return 'd5';
      case DateTime.thursday:
        return 'd6';
      case DateTime.friday:
        return 'd7';
      default:
        return 'd1';
    }
  }

  void _applyFilter() {
    if (_quizMode == 'maratona') {
      _questions = List.from(_allQuestions);
    } else if (_quizMode == 'revisao') {
      // Reúne todas as questões da semana desde d1 até o dia atual da semana
      final todayNum = int.tryParse(_getDefaultDayId().replaceAll(RegExp(r'\D'), '')) ?? 1;
      _questions = _allQuestions.where((q) {
        final qNum = int.tryParse(q.dayId.replaceAll(RegExp(r'\D'), '')) ?? 1;
        return qNum >= 1 && qNum <= todayNum;
      }).toList();
    } else {
      // Quiz do Dia: estritamente as perguntas cadastradas para o dia selecionado (sem acumular)
      _questions = _allQuestions.where((q) => q.dayId == _selectedDayId).toList();
    }
    _resetQuizState();
  }

  void setMode(String mode) {
    if (_quizMode == mode) return;
    _quizMode = mode;
    _applyFilter();
    notifyListeners();
  }

  void selectDay(String dayId) {
    if (_selectedDayId == dayId && _quizMode == 'diario') return;
    _selectedDayId = dayId;
    _quizMode = 'diario';
    _applyFilter();
    notifyListeners();
  }

  void _resetQuizState() {
    _currentIndex = 0;
    _selectedOption = null;
    _hasSubmitted = false;
    _lastResult = null;
    _score = 0;
    _isCompleted = false;
  }

  Future<void> selectCategory(String category) async {
    if (_currentCategory == category && _questions.isNotEmpty) return;
    await init(category: category);
  }

  void selectOption(int optionIndex) {
    if (_hasSubmitted || _isCompleted) return;
    _selectedOption = optionIndex;
    notifyListeners();
  }

  void submitAnswer() {
    if (_selectedOption == null || _hasSubmitted || currentQuestion == null) return;

    final q = currentQuestion!;
    final isCorrect = _selectedOption == q.correctOption;

    if (isCorrect) {
      _score++;
      _streak++;
      _totalXp += 10;
    } else {
      _streak = 0;
    }

    _lastResult = QuizResult(
      isCorrect: isCorrect,
      correctOption: q.correctOption,
      explanation: q.explanation,
      xpEarned: isCorrect ? 10 : 0,
      newStreak: _streak,
    );

    _hasSubmitted = true;
    notifyListeners();
  }

  void nextQuestion() {
    if (!_hasSubmitted) return;

    if (_currentIndex + 1 < _questions.length) {
      _currentIndex++;
      _selectedOption = null;
      _hasSubmitted = false;
      _lastResult = null;
    } else {
      _isCompleted = true;
      GamificationService().recordQuizCompletion();
      if (_totalXp > 0) {
        GamificationService().addXp(_totalXp);
      }
      ClassroomService().syncCurrentActivitySilently(
        quizScore: _score,
        didQuiz: true,
      );
    }
    notifyListeners();
  }

  void restart() {
    _resetQuizState();
    notifyListeners();
  }
}
