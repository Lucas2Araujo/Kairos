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

  static DateTime? _parseDate(String dStr) {
    if (dStr.isEmpty) return null;
    final clean = dStr.trim();
    for (final sep in ['/', '-']) {
      if (clean.contains(sep)) {
        final parts = clean.split(sep);
        if (parts.length == 3) {
          try {
            if (parts[0].length == 4) {
              return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            } else if (parts[2].length == 4) {
              return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  SSQuarterly _findCurrentQuarterly(List<SSQuarterly> list) {
    final now = DateTime.now();
    for (final q in list) {
      final s = _parseDate(q.startDate);
      final e = _parseDate(q.endDate);
      if (s != null && e != null && !now.isBefore(s) && !now.isAfter(e)) {
        return q;
      }
    }
    for (final q in list) {
      final s = _parseDate(q.startDate);
      if (s != null && !now.isBefore(s)) {
        return q;
      }
    }
    return list.first;
  }

  SSLesson _findCurrentLesson(List<SSLesson> list) {
    final now = DateTime.now();
    for (final l in list) {
      final s = _parseDate(l.startDate);
      final e = _parseDate(l.endDate);
      if (s != null && e != null && !now.isBefore(s) && !now.isAfter(e)) {
        return l;
      }
    }
    final past = list.where((l) {
      final s = _parseDate(l.startDate);
      return s != null && !now.isBefore(s);
    }).toList();
    if (past.isNotEmpty) {
      return past.last;
    }
    return list.first;
  }

  SSDay _findCurrentDay(List<SSDay> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final d in list) {
      final dt = _parseDate(d.date);
      if (dt != null) {
        final dOnly = DateTime(dt.year, dt.month, dt.day);
        if (dOnly.isAtSameMomentAs(today)) return d;
      }
    }
    final diffs = <MapEntry<int, SSDay>>[];
    for (final d in list) {
      final dt = _parseDate(d.date);
      if (dt != null) {
        final dOnly = DateTime(dt.year, dt.month, dt.day);
        diffs.add(MapEntry(dOnly.difference(today).inDays.abs(), d));
      }
    }
    if (diffs.isNotEmpty) {
      diffs.sort((a, b) => a.key.compareTo(b.key));
      return diffs.first.value;
    }
    return list.first;
  }

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _quarterlies = await _service.getQuarterlies(category: _category);
      if (_quarterlies.isNotEmpty) {
        _selectedQuarterly = _findCurrentQuarterly(_quarterlies);
        _lessons = await _service.getLessons(_selectedQuarterly!.id);
        if (_lessons.isNotEmpty) {
          _selectedLesson = _findCurrentLesson(_lessons);
          _days = await _service.getLessonDays(_selectedLesson!.id, quarterlyId: _selectedQuarterly!.id);
          if (_days.isNotEmpty) {
            _selectedDay = _findCurrentDay(_days);
            await _loadDayContent(_selectedDay!);
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
        _selectedLesson = _findCurrentLesson(_lessons);
        _days = await _service.getLessonDays(_selectedLesson!.id, quarterlyId: quarterly.id);
        _selectedDay = _days.isNotEmpty ? _findCurrentDay(_days) : null;
        if (_selectedDay != null) {
          await _loadDayContent(_selectedDay!);
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
      _days = await _service.getLessonDays(lesson.id, quarterlyId: lesson.quarterlyId);
      _selectedDay = _days.isNotEmpty ? _findCurrentDay(_days) : null;
      if (_selectedDay != null) {
        await _loadDayContent(_selectedDay!);
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
    if (_selectedDay?.id == day.id && _selectedDay?.content.isNotEmpty == true) return;
    _selectedDay = day;
    _currentNote = await _service.getNote(day.id);
    notifyListeners();

    await _loadDayContent(day);
    notifyListeners();
  }

  Future<void> _loadDayContent(SSDay day) async {
    if (day.content.isNotEmpty) return;
    try {
      final fullDay = await _service.getDayContent(
        day.id,
        lessonId: day.lessonId,
        readPath: day.readPath,
      );
      if (fullDay != null && fullDay.content.isNotEmpty) {
        if (_selectedDay?.id == day.id) {
          _selectedDay = fullDay;
        }
        final idx = _days.indexWhere((d) => d.id == day.id);
        if (idx != -1) {
          _days[idx] = fullDay;
        }
      }
    } catch (e) {
      debugPrint('[SabbathSchoolController] Erro ao carregar conteúdo do dia: $e');
    }
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
