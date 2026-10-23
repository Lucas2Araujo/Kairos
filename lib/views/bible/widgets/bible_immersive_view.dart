import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/bible_controller.dart';
import '../../../models/bible_verse.dart';
import '../../../services/theme_service.dart';
import '../bible_reader_view.dart';

/// Representa um capítulo carregado no modo imersivo
class LoadedChapter {
  final int bookId;
  final String bookName;
  final int chapter;
  final List<BibleVerse> verses;

  const LoadedChapter({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verses,
  });
}

/// Modo de Leitura: Livro Imersivo
///
/// Apresenta o texto contínuo como um livro ou Kindle:
/// - Tipografia generosa e confortável (sem números de versículos visíveis)
/// - Scroll infinito contínuo que pré-carrega os próximos capítulos
/// - Divisores discretos entre capítulos e livros
/// - Toque simples na tela alterna a visibilidade dos controles
/// - Toque longo em qualquer parágrafo de versículo seleciona para grifo/estudo
class BibleImmersiveView extends StatefulWidget {
  final BibleController controller;
  final ThemeService themeService;
  final VoidCallback onToggleControls;
  final ValueChanged<BibleVerse> onSelectVerse;
  final bool Function(BibleVerse verse)? isVerseSelected;

  const BibleImmersiveView({
    super.key,
    required this.controller,
    required this.themeService,
    required this.onToggleControls,
    required this.onSelectVerse,
    this.isVerseSelected,
  });

  @override
  State<BibleImmersiveView> createState() => _BibleImmersiveViewState();
}

class _BibleImmersiveViewState extends State<BibleImmersiveView> {
  final ScrollController _scrollController = ScrollController();
  final List<LoadedChapter> _loadedChapters = [];
  bool _isLoadingNext = false;
  bool _hasReachedEnd = false;

  int? _initialBookId;
  int? _initialChapter;
  String? _initialVersion;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initChapters();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _initChapters() {
    final ctrl = widget.controller;
    _initialBookId = ctrl.selectedBook?.id;
    _initialChapter = ctrl.selectedChapter;
    _initialVersion = ctrl.activeVersion;

    _loadedChapters.clear();
    _hasReachedEnd = false;

    if (ctrl.verses.isNotEmpty && ctrl.selectedBook != null) {
      _loadedChapters.add(LoadedChapter(
        bookId: ctrl.selectedBook!.id,
        bookName: ctrl.selectedBook!.name,
        chapter: ctrl.selectedChapter,
        verses: List<BibleVerse>.from(ctrl.verses),
      ));
    }
  }

  @override
  void didUpdateWidget(covariant BibleImmersiveView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ctrl = widget.controller;
    if (ctrl.selectedBook?.id != _initialBookId ||
        ctrl.selectedChapter != _initialChapter ||
        ctrl.activeVersion != _initialVersion) {
      _initChapters();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    } else if (_loadedChapters.isEmpty && ctrl.verses.isNotEmpty && ctrl.selectedBook != null) {
      setState(() {
        _initChapters();
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0 && currentScroll >= maxScroll * 0.85) {
      _loadNextChapter();
    }
  }

  Future<void> _loadNextChapter() async {
    if (_isLoadingNext || _hasReachedEnd || _loadedChapters.isEmpty) return;
    _isLoadingNext = true;

    try {
      final last = _loadedChapters.last;
      final ctrl = widget.controller;
      final books = ctrl.books;

      int nextBookId = last.bookId;
      String nextBookName = last.bookName;
      int nextChapter = last.chapter + 1;

      final currentBook = books.firstWhere(
        (b) => b.id == last.bookId,
        orElse: () => ctrl.selectedBook ?? BibleBook(
          id: last.bookId,
          name: last.bookName,
          testament: 'VT',
          chaptersCount: 50,
        ),
      );

      if (nextChapter > currentBook.chaptersCount) {
        final bookIndex = books.indexWhere((b) => b.id == last.bookId);
        if (bookIndex != -1 && bookIndex + 1 < books.length) {
          final nextBook = books[bookIndex + 1];
          nextBookId = nextBook.id;
          nextBookName = nextBook.name;
          nextChapter = 1;
        } else {
          _hasReachedEnd = true;
          _isLoadingNext = false;
          return;
        }
      }

      final newVerses = await ctrl.repository.getVerses(
        nextBookId,
        nextChapter,
        bookName: nextBookName,
      );

      if (mounted) {
        if (newVerses.isNotEmpty) {
          setState(() {
            _loadedChapters.add(LoadedChapter(
              bookId: nextBookId,
              bookName: nextBookName,
              chapter: nextChapter,
              verses: newVerses,
            ));
          });
        } else {
          _hasReachedEnd = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading next chapter in immersive mode: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingNext = false;
        });
      }
    }
  }

  static Color? _parseHighlightColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadedChapters.isEmpty && widget.controller.verses.isNotEmpty && widget.controller.selectedBook != null) {
      _initChapters();
    }

    if (_loadedChapters.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final theme = Theme.of(context);
    final multiplier = widget.themeService.fontSizeMultiplier;
    final baseFontSize = 18.0 * multiplier;
    final textAlign = widget.themeService.bibleTextAlign;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onToggleControls,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        itemCount: _loadedChapters.length + (_isLoadingNext ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _loadedChapters.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final chapter = _loadedChapters[index];
          final isPoetic = BibleReaderView.isPoeticBook(chapter.bookId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Separador ou Cabeçalho de Capítulo
              if (index == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                  child: Column(
                    children: [
                      Text(
                        chapter.bookName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFamily: widget.themeService.fontFamily,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Capítulo ${chapter.chapter}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: widget.themeService.fontFamily,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          '— ${chapter.bookName} ${chapter.chapter} —',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily: widget.themeService.fontFamily,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                          thickness: 1,
                        ),
                      ),
                    ],
                  ),
                ),

              // Versículos do capítulo renderizados em formato de livro limpo (sem números de versículos)
              ...chapter.verses.map((verse) {
                final isSelected = widget.isVerseSelected?.call(verse) ?? false;
                final highlightHex = (chapter.chapter == widget.controller.selectedChapter &&
                        chapter.bookId == widget.controller.selectedBook?.id)
                    ? widget.controller.chapterHighlights[verse.verse]
                    : null;
                final highlightColor = _parseHighlightColor(highlightHex);

                final bgColor = isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.25)
                    : highlightColor?.withValues(alpha: 0.28);

                final textStyle = theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: widget.themeService.fontFamily,
                  fontSize: baseFontSize,
                  height: 1.75,
                  backgroundColor: bgColor,
                );

                Widget verseWidget;
                if (isPoetic) {
                  final stichs = BibleReaderView.parsePoeticLines(verse.text);
                  verseWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: stichs.map((s) {
                      return Padding(
                        padding: EdgeInsets.only(left: s.indent),
                        child: Text(
                          s.text,
                          textAlign: textAlign,
                          style: textStyle,
                        ),
                      );
                    }).toList(),
                  );
                } else {
                  verseWidget = Text(
                    verse.text,
                    textAlign: textAlign,
                    style: textStyle,
                  );
                }

                return GestureDetector(
                  key: ValueKey('immersive_verse_${verse.bookId}_${verse.chapter}_${verse.verse}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onToggleControls,
                  onLongPress: () {
                    HapticFeedback.lightImpact();
                    widget.onSelectVerse(verse);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: verseWidget,
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
