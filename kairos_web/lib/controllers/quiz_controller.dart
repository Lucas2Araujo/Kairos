import 'package:flutter/foundation.dart';
import '../data/repositories/quiz_repository.dart';
import '../models/quiz_question.dart';

class QuizController extends ChangeNotifier {
  final QuizRepository _repository;

  QuizController({QuizRepository? repository})
      : _repository = repository ?? QuizRepository();

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

  String _currentCategory = 'adultos';

  String get currentCategory => _currentCategory;
  List<QuizQuestion> get questions => _questions;
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
      _questions.isEmpty ? 0.0 : (_currentIndex / _questions.length);

  Future<void> init({String? category}) async {
    if (category != null) {
      _currentCategory = category;
    }
    _isLoading = true;
    notifyListeners();

    _questions = await _repository.getQuestions(category: _currentCategory);
    _currentIndex = 0;
    _selectedOption = null;
    _hasSubmitted = false;
    _lastResult = null;
    _score = 0;
    _totalXp = 0;
    _streak = 0;
    _isCompleted = false;
    _isLoading = false;
    notifyListeners();
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
    }
    notifyListeners();
  }

  void restart() {
    _currentIndex = 0;
    _selectedOption = null;
    _hasSubmitted = false;
    _lastResult = null;
    _score = 0;
    _isCompleted = false;
    notifyListeners();
  }
}
