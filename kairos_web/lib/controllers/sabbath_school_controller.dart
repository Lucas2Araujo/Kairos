import 'package:flutter/material.dart';
import '../../data/services/sabbath_school_service.dart';
import '../../models/sabbath_school_models.dart';

class SabbathSchoolController extends ChangeNotifier {
  final SabbathSchoolService _service;

  SabbathSchoolController({SabbathSchoolService? service})
      : _service = service ?? SabbathSchoolService();

  String _category = 'adultos';
  List<SSQuarterly> _quarterlies = [];
  SSQuarterly? _selectedQuarterly;
  List<SSLesson> _lessons = [];
  SSLesson? _selectedLesson;
  List<SSDay> _days = [];
  SSDay? _selectedDay;
  String _currentNote = '';
  double _fontSize = 16.0;
  bool _isLoading = false;
  String? _errorMessage;

  String get category => _category;
  List<SSQuarterly> get quarterlies => _quarterlies;
  SSQuarterly? get selectedQuarterly => _selectedQuarterly;
  List<SSLesson> get lessons => _lessons;
  SSLesson? get selectedLesson => _selectedLesson;
  List<SSDay> get days => _days;
  SSDay? get selectedDay => _selectedDay;
  String get currentNote => _currentNote;
  double get fontSize => _fontSize;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _quarterlies = await _service.getQuarterlies(category: _category);
      if (_quarterlies.isNotEmpty) {
        _selectedQuarterly = _quarterlies.first;
        _lessons = await _service.getLessons(_selectedQuarterly!.id);
        if (_lessons.isNotEmpty) {
          _selectedLesson = _lessons.first;
          _days = await _service.getLessonDays(_selectedLesson!.id);
          if (_days.isNotEmpty) {
            _selectedDay = _days.first;
            _currentNote = await _service.getNote(_selectedDay!.id);
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Falha ao carregar lição da Escola Sabatina: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setCategory(String newCategory) async {
    if (_category == newCategory) return;
    _category = newCategory;
    await init();
  }

  Future<void> selectQuarterly(SSQuarterly quarterly) async {
    if (_selectedQuarterly?.id == quarterly.id) return;
    _selectedQuarterly = quarterly;
    _isLoading = true;
    notifyListeners();

    try {
      _lessons = await _service.getLessons(quarterly.id);
      if (_lessons.isNotEmpty) {
        _selectedLesson = _lessons.first;
        _days = await _service.getLessonDays(_selectedLesson!.id);
        _selectedDay = _days.isNotEmpty ? _days.first : null;
        if (_selectedDay != null) {
          _currentNote = await _service.getNote(_selectedDay!.id);
        }
      } else {
        _selectedLesson = null;
        _days = [];
        _selectedDay = null;
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar trimestre: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectLesson(SSLesson lesson) async {
    if (_selectedLesson?.id == lesson.id) return;
    _selectedLesson = lesson;
    _isLoading = true;
    notifyListeners();

    try {
      _days = await _service.getLessonDays(lesson.id);
      _selectedDay = _days.isNotEmpty ? _days.first : null;
      if (_selectedDay != null) {
        _currentNote = await _service.getNote(_selectedDay!.id);
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar lição: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectDay(SSDay day) async {
    if (_selectedDay?.id == day.id) return;
    _selectedDay = day;
    _currentNote = await _service.getNote(day.id);
    notifyListeners();
  }

  Future<void> updateNote(String note) async {
    _currentNote = note;
    if (_selectedDay != null) {
      await _service.saveNote(_selectedDay!.id, note);
    }
    notifyListeners();
  }

  void changeFontSize(double delta) {
    final newSize = _fontSize + delta;
    if (newSize >= 12.0 && newSize <= 28.0) {
      _fontSize = newSize;
      notifyListeners();
    }
  }
}
