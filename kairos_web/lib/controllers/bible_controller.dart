import 'package:flutter/material.dart';
import '../data/repositories/bible_repository.dart';
import '../data/repositories/commentary_repository.dart';
import '../data/repositories/cross_reference_repository.dart';
import '../data/repositories/pericope_repository.dart';
import '../models/bible_verse.dart';
import '../models/study_models.dart';

class BibleController extends ChangeNotifier {
  final BibleRepository _repository;
  final PericopeRepository _pericopeRepository;
  final CrossReferenceRepository _crossRefRepository;
  final CommentaryRepository _commentaryRepository;

  BibleController({
    BibleRepository? repository,
    PericopeRepository? pericopeRepository,
    CrossReferenceRepository? crossRefRepository,
    CommentaryRepository? commentaryRepository,
  })  : _repository = repository ?? BibleRepository(),
        _pericopeRepository = pericopeRepository ?? PericopeRepository(),
        _crossRefRepository = crossRefRepository ?? CrossReferenceRepository(),
        _commentaryRepository = commentaryRepository ?? CommentaryRepository();

  List<BibleBook> _books = [];
  List<BibleVerse> _verses = [];
  List<Pericope> _pericopes = [];
  BibleBook? _selectedBook;
  int _selectedChapter = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Estados de Estudo Bíblico
  BibleVerse? _selectedVerseForStudy;
  List<CrossReference> _selectedVerseCrossReferences = [];
  List<Commentary> _selectedVerseCommentaries = [];
  bool _isLoadingStudyData = false;

  List<BibleBook> get books => _books;
  List<BibleVerse> get verses => _verses;
  List<Pericope> get pericopes => _pericopes;
  BibleBook? get selectedBook => _selectedBook;
  int get selectedChapter => _selectedChapter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  BibleVerse? get selectedVerseForStudy => _selectedVerseForStudy;
  List<CrossReference> get selectedVerseCrossReferences => _selectedVerseCrossReferences;
  List<Commentary> get selectedVerseCommentaries => _selectedVerseCommentaries;
  bool get isLoadingStudyData => _isLoadingStudyData;

  Map<int, String> get _bookNameMap {
    return {for (final b in _books) b.id: b.name};
  }

  /// Inicializa e carrega lista de livros e o primeiro capítulo do Gênesis
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _books = await _repository.getBooks();
      if (_books.isNotEmpty) {
        _selectedBook = _books.first;
        _selectedChapter = 1;
        await _loadVersesAndPericopes();
      }
    } catch (e) {
      _errorMessage = 'Falha ao carregar livros da Bíblia: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Seleciona outro livro
  Future<void> selectBook(BibleBook book) async {
    if (_selectedBook?.id == book.id) return;
    _selectedBook = book;
    _selectedChapter = 1;
    await _loadVersesAndPericopes();
  }

  /// Altera o capítulo do livro atual
  Future<void> selectChapter(int chapter) async {
    if (_selectedChapter == chapter) return;
    _selectedChapter = chapter;
    await _loadVersesAndPericopes();
  }

  /// Salta diretamente para um livro/capítulo/versículo específico
  Future<void> jumpToVerse(dynamic bookIdOrName, int chapter, [int verse = 1]) async {
    if (_books.isEmpty) {
      _books = await _repository.getBooks();
    }

    BibleBook? targetBook;
    if (bookIdOrName is int) {
      targetBook = _books.firstWhere(
        (b) => b.id == bookIdOrName,
        orElse: () => _books.first,
      );
    } else {
      final nameStr = bookIdOrName.toString().trim();
      final resolvedId = BibleRepository.resolveBookId(nameStr);
      if (resolvedId != null) {
        targetBook = _books.firstWhere(
          (b) => b.id == resolvedId,
          orElse: () => _books.first,
        );
      } else {
        final lower = nameStr.toLowerCase();
        targetBook = _books.firstWhere(
          (b) => b.name.toLowerCase() == lower || b.name.toLowerCase().startsWith(lower),
          orElse: () => _books.first,
        );
      }
    }

    _selectedBook = targetBook;
    _selectedChapter = chapter.clamp(1, targetBook.chaptersCount);
    await _loadVersesAndPericopes();
  }

  /// Carrega versículos e perícopes correspondentes
  Future<void> _loadVersesAndPericopes() async {
    if (_selectedBook == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getVerses(_selectedBook!.id, _selectedChapter, bookName: _selectedBook!.name),
        _pericopeRepository.getPericopes(_selectedBook!.id, _selectedChapter),
      ]);
      _verses = results[0] as List<BibleVerse>;
      _pericopes = results[1] as List<Pericope>;
    } catch (e) {
      _errorMessage = 'Erro ao carregar versículos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Abre versículo para estudo bíblico (carrega referências cruzadas e comentários)
  Future<void> loadStudyDataForVerse(BibleVerse verse) async {
    _selectedVerseForStudy = verse;
    _isLoadingStudyData = true;
    _selectedVerseCrossReferences = [];
    _selectedVerseCommentaries = [];
    notifyListeners();

    try {
      final results = await Future.wait([
        _crossRefRepository.getCrossReferences(
          verse.bookId,
          verse.chapter,
          verse.verse,
          bookNames: _bookNameMap,
        ),
        _commentaryRepository.getCommentariesForVerse(
          verse.bookId,
          verse.chapter,
          verse.verse,
        ),
      ]);
      _selectedVerseCrossReferences = results[0] as List<CrossReference>;
      _selectedVerseCommentaries = results[1] as List<Commentary>;
    } catch (e) {
      debugPrint('Erro ao carregar dados de estudo bíblico: $e');
    } finally {
      _isLoadingStudyData = false;
      notifyListeners();
    }
  }

  void clearStudySelection() {
    _selectedVerseForStudy = null;
    _selectedVerseCrossReferences = [];
    _selectedVerseCommentaries = [];
    notifyListeners();
  }
}
