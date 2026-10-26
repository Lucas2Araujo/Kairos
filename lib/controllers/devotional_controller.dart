import 'package:flutter/material.dart';
import '../models/devotional.dart';
import '../services/devotional_service.dart';
import '../services/gamification_service.dart';
import '../services/theme_service.dart';

class DevotionalController extends ChangeNotifier {
  final DevotionalService _service;

  DevotionalController({DevotionalService? service})
      : _service = service ?? DevotionalService() {
    _selectedCategory = ThemeService().defaultDevotionalCategory;
    ThemeService().addListener(_onThemeChanged);
  }

  String _selectedCategory = 'jovem'; // 'jovem', 'diario', 'mulher'
  DateTime _selectedDate = DateTime.now();
  Devotional? _currentDevotional;
  bool _isLoading = false;
  String? _errorMessage;

  String get selectedCategory => _selectedCategory;
  DateTime get selectedDate => _selectedDate;
  Devotional? get currentDevotional => _currentDevotional;
  set currentDevotional(Devotional? value) {
    _currentDevotional = value;
    notifyListeners();
  }
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _onThemeChanged() {
    final defaultCat = ThemeService().defaultDevotionalCategory;
    if (_selectedCategory != defaultCat) {
      _selectedCategory = defaultCat;
      loadDevotional();
    }
  }

  @override
  void dispose() {
    ThemeService().removeListener(_onThemeChanged);
    super.dispose();
  }

  /// Retorna os últimos 7 dias (incluindo hoje)
  List<DateTime> get recentDays {
    final now = DateTime.now();
    return List.generate(7, (index) {
      return now.subtract(Duration(days: 6 - index));
    });
  }

  String get formattedSelectedDate {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> init() async {
    _selectedCategory = ThemeService().defaultDevotionalCategory;
    await loadDevotional();
  }

  Future<void> selectCategory(String category) async {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    await loadDevotional();
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;
    await loadDevotional();
  }

  Future<void> loadDevotional({String? date, String? category}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetDate = date ?? formattedSelectedDate;
      final targetCat = category ?? _selectedCategory;
      _currentDevotional = await _service.getDevotional(
        targetDate,
        category: targetCat,
      );
      if (_currentDevotional != null) {
        GamificationService().recordReading(category: 'devotional');
      }
    } catch (e) {
      _errorMessage = 'Falha ao carregar meditação diária: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
