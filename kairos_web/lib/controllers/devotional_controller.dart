import 'package:flutter/material.dart';
import '../models/devotional.dart';
import '../services/devotional_service.dart';

class DevotionalController extends ChangeNotifier {
  final DevotionalService _service;

  DevotionalController({DevotionalService? service})
      : _service = service ?? DevotionalService();

  String _selectedCategory = 'jovem'; // 'jovem', 'diario', 'mulher'
  DateTime _selectedDate = DateTime.now();
  Devotional? _currentDevotional;
  bool _isLoading = false;
  String? _errorMessage;

  String get selectedCategory => _selectedCategory;
  DateTime get selectedDate => _selectedDate;
  Devotional? get currentDevotional => _currentDevotional;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Future<void> loadDevotional() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentDevotional = await _service.getDevotional(
        formattedSelectedDate,
        category: _selectedCategory,
      );
    } catch (e) {
      _errorMessage = 'Falha ao carregar meditação diária: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
