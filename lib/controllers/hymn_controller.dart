import 'package:flutter/foundation.dart';
import '../data/repositories/hymn_repository.dart';
import '../models/hymn.dart';

class HymnController extends ChangeNotifier {
  final HymnRepository _repository;

  HymnController({HymnRepository? repository})
      : _repository = repository ?? HymnRepository();

  List<Hymn> _hymns = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String _searchQuery = '';
  String _edition = 'novo'; // 'novo' ou 'antigo'
  bool _isLoading = false;
  String? _errorMessage;

  List<Hymn> get hymns => _hymns;
  List<String> get categories => _categories;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  String get edition => _edition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Retorna textos bíblicos relacionados a um hino
  Future<List<String>> getRelatedBibleTexts(int hinoId) async {
    return await _repository.getRelatedBibleTexts(hinoId);
  }

  Future<void> switchEdition(String newEdition) async {
    if (_edition == newEdition) return;
    _edition = newEdition;
    _repository.setDatabase(newEdition == 'antigo' ? 'hinario_antigo.db' : 'hinario.db');
    _selectedCategory = null;
    _searchQuery = '';
    await init();
  }

  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getAll(),
        _repository.getCategories(),
      ]);
      _hymns = results[0] as List<Hymn>;
      _categories = results[1] as List<String>;
    } catch (e) {
      _errorMessage = 'Falha ao carregar hinário: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (query.trim().isEmpty) {
        if (_selectedCategory != null) {
          _hymns = await _repository.getByCategory(_selectedCategory!);
        } else {
          _hymns = await _repository.getAll();
        }
      } else {
        _selectedCategory = null;
        _hymns = await _repository.search(query);
      }
    } catch (e) {
      _errorMessage = 'Erro na busca de hinos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(String? category) async {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _searchQuery = '';
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (category == null) {
        _hymns = await _repository.getAll();
      } else {
        _hymns = await _repository.getByCategory(category);
      }
    } catch (e) {
      _errorMessage = 'Erro ao filtrar por categoria: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
