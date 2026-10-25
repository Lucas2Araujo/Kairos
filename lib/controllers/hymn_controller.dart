import 'package:flutter/foundation.dart';
import '../data/repositories/hymn_repository.dart';
import '../models/hymn.dart';

enum HymnTabFilter { todos, favoritos, recentes, explorar }
enum HymnSortMode { numAsc, numDesc, titleAsc, titleDesc }

class HymnController extends ChangeNotifier {
  static HymnController? instance;

  final HymnRepository _repository;

  HymnController({HymnRepository? repository})
      : _repository = repository ?? HymnRepository() {
    instance = this;
  }

  List<Hymn> _hymns = [];
  List<String> _categories = [];
  List<String> _themes = [];
  String? _selectedCategory;
  String? _selectedTheme;
  Hymn? _originHymn;
  String _searchQuery = '';
  String _edition = 'novo'; // 'novo' ou 'antigo'
  bool _isLoading = false;
  String? _errorMessage;
  HymnTabFilter _tabFilter = HymnTabFilter.todos;
  HymnSortMode _sortMode = HymnSortMode.numAsc;

  List<Hymn> get hymns => _hymns;
  List<String> get categories => _categories;
  List<String> get themes => _themes;
  String? get selectedCategory => _selectedCategory;
  String? get selectedTheme => _selectedTheme;
  Hymn? get originHymn => _originHymn;
  bool get hasActiveCategoryOrTheme => _selectedCategory != null || _selectedTheme != null;
  String get searchQuery => _searchQuery;
  String get edition => _edition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  HymnTabFilter get tabFilter => _tabFilter;
  HymnSortMode get sortMode => _sortMode;

  /// Retorna textos bíblicos relacionados a um hino
  Future<List<String>> getRelatedBibleTexts(int hinoId) async {
    return await _repository.getRelatedBibleTexts(hinoId);
  }

  int _compareHymnNumber(String a, String b) {
    final intA = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
    final intB = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (intA != intB) return intA.compareTo(intB);
    return a.compareTo(b);
  }

  String _stripAccents(String input) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÇçÌÍÎÏìíîïÙÚÛÜùúûüÿÑñ';
    const withoutDia = 'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeCcIIIIiiiiUUUUuuuuyNn';
    var str = input;
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str.toLowerCase().trim();
  }

  void _applySorting(List<Hymn> list) {
    switch (_sortMode) {
      case HymnSortMode.numAsc:
        list.sort((a, b) => _compareHymnNumber(a.numero, b.numero));
        break;
      case HymnSortMode.numDesc:
        list.sort((a, b) => _compareHymnNumber(b.numero, a.numero));
        break;
      case HymnSortMode.titleAsc:
        list.sort((a, b) => _stripAccents(a.titulo).compareTo(_stripAccents(b.titulo)));
        break;
      case HymnSortMode.titleDesc:
        list.sort((a, b) => _stripAccents(b.titulo).compareTo(_stripAccents(a.titulo)));
        break;
    }
  }

  void setSortMode(HymnSortMode mode) {
    _sortMode = mode;
    _applySorting(_hymns);
    notifyListeners();
  }

  Future<void> switchEdition(String newEdition) async {
    if (_edition == newEdition) return;
    _edition = newEdition;
    _repository.setDatabase(newEdition == 'antigo' ? 'hinario_antigo.db' : 'hinario.db');
    _selectedCategory = null;
    _selectedTheme = null;
    _originHymn = null;
    _searchQuery = '';
    _tabFilter = HymnTabFilter.todos;
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
        _repository.getThemes(),
      ]);
      _hymns = results[0] as List<Hymn>;
      _categories = results[1] as List<String>;
      _themes = results[2] as List<String>;
      _applySorting(_hymns);
    } catch (e) {
      _errorMessage = 'Falha ao carregar hinário: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTabFilter(HymnTabFilter filter) async {
    _tabFilter = filter;
    _selectedCategory = null;
    _selectedTheme = null;
    _originHymn = null;
    _searchQuery = '';
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (filter == HymnTabFilter.favoritos) {
        _hymns = await _repository.getFavorites();
        _applySorting(_hymns);
      } else if (filter == HymnTabFilter.recentes) {
        _hymns = await _repository.getRecent();
        if (_sortMode != HymnSortMode.numAsc) {
          _applySorting(_hymns);
        }
      } else if (filter == HymnTabFilter.todos) {
        _hymns = await _repository.getAll();
        _applySorting(_hymns);
      } else if (filter == HymnTabFilter.explorar) {
        _hymns = [];
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar hinos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> filterByCategoryOrTheme({String? category, String? theme, Hymn? fromHymn}) async {
    _selectedCategory = category;
    _selectedTheme = theme;
    _originHymn = fromHymn;
    _searchQuery = '';
    _tabFilter = HymnTabFilter.explorar;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (category != null) {
        _hymns = await _repository.getByCategory(category);
      } else if (theme != null) {
        _hymns = await _repository.getByTheme(theme);
      } else {
        _hymns = [];
      }
      _applySorting(_hymns);
    } catch (e) {
      _errorMessage = 'Erro ao filtrar hinos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> returnToExplore() async {
    _selectedCategory = null;
    _selectedTheme = null;
    _originHymn = null;
    _tabFilter = HymnTabFilter.explorar;
    _hymns = [];
    notifyListeners();
  }

  Future<void> clearCategoryOrThemeFilter() async {
    _selectedCategory = null;
    _selectedTheme = null;
    _originHymn = null;
    _tabFilter = HymnTabFilter.todos;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _hymns = await _repository.getAll();
      _applySorting(_hymns);
    } catch (e) {
      _errorMessage = 'Erro ao carregar hinos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrent() async {
    try {
      if (_searchQuery.trim().isNotEmpty) {
        _hymns = await _repository.search(_searchQuery);
        if (_sortMode != HymnSortMode.numAsc) {
          _applySorting(_hymns);
        }
      } else if (_selectedCategory != null) {
        _hymns = await _repository.getByCategory(_selectedCategory!);
        _applySorting(_hymns);
      } else if (_selectedTheme != null) {
        _hymns = await _repository.getByTheme(_selectedTheme!);
        _applySorting(_hymns);
      } else if (_tabFilter == HymnTabFilter.favoritos) {
        _hymns = await _repository.getFavorites();
        _applySorting(_hymns);
      } else if (_tabFilter == HymnTabFilter.recentes) {
        _hymns = await _repository.getRecent();
        if (_sortMode != HymnSortMode.numAsc) {
          _applySorting(_hymns);
        }
      } else if (_tabFilter == HymnTabFilter.explorar) {
        // Exploração limpa sem filtro
      } else {
        _hymns = await _repository.getAll();
        _applySorting(_hymns);
      }
      notifyListeners();
    } catch (_) {}
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
        } else if (_selectedTheme != null) {
          _hymns = await _repository.getByTheme(_selectedTheme!);
        } else if (_tabFilter == HymnTabFilter.favoritos) {
          _hymns = await _repository.getFavorites();
        } else if (_tabFilter == HymnTabFilter.recentes) {
          _hymns = await _repository.getRecent();
        } else if (_tabFilter == HymnTabFilter.explorar) {
          _hymns = [];
        } else {
          _hymns = await _repository.getAll();
        }
        if (!(_tabFilter == HymnTabFilter.recentes && _sortMode == HymnSortMode.numAsc)) {
          _applySorting(_hymns);
        }
      } else {
        _hymns = await _repository.search(query);
        if (_sortMode != HymnSortMode.numAsc) {
          _applySorting(_hymns);
        }
      }
    } catch (e) {
      _errorMessage = 'Erro na busca de hinos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectCategory(String? category) async {
    if (category == null) {
      await clearCategoryOrThemeFilter();
    } else {
      await filterByCategoryOrTheme(category: category);
    }
  }
}
