import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/bible_controller.dart';
import '../../../models/bible_verse.dart';
import '../../../models/study_models.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';
import '../../../widgets/kairos_reader_gesture_layer.dart';
import '../bible_reader_view.dart';

/// Representa um capítulo carregado no modo imersivo
class LoadedChapter {
  final int bookId;
  final String bookName;
  final int chapter;
  final List<BibleVerse> verses;
  /// Perícopes (subtítulos literários) associadas aos versículos deste capítulo.
  final List<Pericope> pericopes;

  const LoadedChapter({
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verses,
    this.pericopes = const [],
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
  static const Key _centerKey = ValueKey('immersive_center_sliver');
  final ScrollController _scrollController = ScrollController();
  final List<LoadedChapter> _previousChapters = [];
  final List<LoadedChapter> _loadedChapters = [];
  final Map<int, GlobalKey> _immersiveVerseKeys = {};
  bool _isLoadingNext = false;
  bool _isLoadingPrevious = false;
  bool _hasReachedEnd = false;
  bool _hasReachedStart = false;

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

    _previousChapters.clear();
    _loadedChapters.clear();
    _immersiveVerseKeys.clear();
    _hasReachedEnd = false;
    _hasReachedStart = false;

    if (ctrl.verses.isNotEmpty && ctrl.selectedBook != null) {
      _loadedChapters.add(LoadedChapter(
        bookId: ctrl.selectedBook!.id,
        bookName: ctrl.selectedBook!.name,
        chapter: ctrl.selectedChapter,
        verses: List<BibleVerse>.from(ctrl.verses),
        pericopes: List<Pericope>.from(ctrl.pericopes),
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
    final pos = _scrollController.position;
    if (pos.maxScrollExtent > 0 && pos.pixels >= pos.maxScrollExtent - 300) {
      _loadNextChapter();
    }
    if (pos.pixels <= pos.minScrollExtent + 250) {
      _loadPreviousChapter();
    }
  }

  Future<void> _loadPreviousChapter() async {
    if (_isLoadingPrevious || _hasReachedStart || _loadedChapters.isEmpty) return;
    _isLoadingPrevious = true;

    try {
      final first = _previousChapters.isNotEmpty
          ? _previousChapters.last
          : _loadedChapters.first;
      final ctrl = widget.controller;
      final books = ctrl.books;

      int prevBookId = first.bookId;
      String prevBookName = first.bookName;
      int prevChapter = first.chapter - 1;

      if (prevChapter < 1) {
        final bookIndex = books.indexWhere((b) => b.id == first.bookId);
        if (bookIndex > 0) {
          final prevBook = books[bookIndex - 1];
          prevBookId = prevBook.id;
          prevBookName = prevBook.name;
          prevChapter = prevBook.chaptersCount;
        } else {
          _hasReachedStart = true;
          _isLoadingPrevious = false;
          return;
        }
      }

      final newVerses = await ctrl.repository.getVerses(
        prevBookId,
        prevChapter,
        bookName: prevBookName,
      );
      final newPericopes = await ctrl.pericopeRepository.getPericopes(
        prevBookId,
        prevChapter,
      );

      if (mounted) {
        if (newVerses.isNotEmpty) {
          setState(() {
            _previousChapters.add(LoadedChapter(
              bookId: prevBookId,
              bookName: prevBookName,
              chapter: prevChapter,
              verses: newVerses,
              pericopes: newPericopes,
            ));
          });
        } else {
          _hasReachedStart = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading previous chapter in immersive mode: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPrevious = false;
        });
      }
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
      final newPericopes = await ctrl.pericopeRepository.getPericopes(
        nextBookId,
        nextChapter,
      );

      if (mounted) {
        if (newVerses.isNotEmpty) {
          setState(() {
            _loadedChapters.add(LoadedChapter(
              bookId: nextBookId,
              bookName: nextBookName,
              chapter: nextChapter,
              verses: newVerses,
              pericopes: newPericopes,
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = widget.controller.targetVerse;
      if (target != null && _immersiveVerseKeys.containsKey(target)) {
        final ctx = _immersiveVerseKeys[target]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: Duration(milliseconds: widget.themeService.bibleScrollDurationMs),
            curve: Curves.easeInOutCubic,
            alignment: 0.15,
          );
        }
      }
    });

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return KairosReaderGestureLayer(
          onNextChapter: () {
            HapticFeedback.lightImpact();
            widget.controller.nextChapter();
          },
          onPreviousChapter: () {
            HapticFeedback.lightImpact();
            widget.controller.previousChapter();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: widget.onToggleControls,
            child: CustomScrollView(
              controller: _scrollController,
              center: _centerKey,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_previousChapters.isNotEmpty || _isLoadingPrevious)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _previousChapters.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final chapter = _previousChapters[index];
                          return _buildChapterContent(
                            context,
                            theme: theme,
                            chapter: chapter,
                            isFirstLoaded: false,
                            baseFontSize: baseFontSize,
                            textAlign: textAlign,
                          );
                        },
                        childCount: _previousChapters.length + (_isLoadingPrevious ? 1 : 0),
                      ),
                    ),
                  ),
                SliverPadding(
                  key: _centerKey,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
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
                        return _buildChapterContent(
                          context,
                          theme: theme,
                          chapter: chapter,
                          isFirstLoaded: index == 0,
                          baseFontSize: baseFontSize,
                          textAlign: textAlign,
                        );
                      },
                      childCount: _loadedChapters.length + (_isLoadingNext ? 1 : 0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChapterContent(
    BuildContext context, {
    required ThemeData theme,
    required LoadedChapter chapter,
    required bool isFirstLoaded,
    required double baseFontSize,
    required TextAlign textAlign,
  }) {
    final isPoetic = BibleReaderView.isPoeticBook(chapter.bookId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Separador ou Cabeçalho de Capítulo
        if (isFirstLoaded)
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
                  ...chapter.verses.expand<Widget>((verse) {
                    Pericope? pericope;
                    for (final p in chapter.pericopes) {
                      if (p.verse == verse.verse) {
                        pericope = p;
                        break;
                      }
                    }
                    final isSelected = widget.isVerseSelected?.call(verse) ?? false;
                    final isTarget = (chapter.chapter == widget.controller.selectedChapter &&
                            chapter.bookId == widget.controller.selectedBook?.id) &&
                        (widget.controller.targetVerses.contains(verse.verse) ||
                            widget.controller.targetVerse == verse.verse);
                    final highlightHex = (chapter.chapter == widget.controller.selectedChapter &&
                            chapter.bookId == widget.controller.selectedBook?.id)
                        ? widget.controller.chapterHighlights[verse.verse]
                        : null;
                    final highlightColor = _parseHighlightColor(highlightHex);

                    final bgColor = isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.25)
                        : (isTarget
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : highlightColor?.withValues(alpha: 0.28));

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

                    final isTargetChapter = chapter.chapter == widget.controller.selectedChapter &&
                        chapter.bookId == widget.controller.selectedBook?.id;
                    final scrollKey = isTargetChapter
                        ? _immersiveVerseKeys.putIfAbsent(verse.verse, () => GlobalKey())
                        : null;

                    return [
                      if (pericope != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 18.0, bottom: 8.0),
                          child: Semantics(
                            header: true,
                            child: Text(
                              pericope.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontFamily: widget.themeService.fontFamily,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: baseFontSize * 0.98,
                              ),
                            ),
                          ),
                        ),
                      KeyedSubtree(
                        key: ValueKey('immersive_verse_${verse.bookId}_${verse.chapter}_${verse.verse}'),
                        child: Container(
                          key: scrollKey,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onSelectVerse(verse);
                            },
                            onLongPress: () {
                              HapticFeedback.lightImpact();
                              widget.onSelectVerse(verse);
                            },
                            onDoubleTap: (widget.themeService.gesturesEnabled &&
                                    widget.themeService.gestureDoubleTapHighlight)
                                ? () async {
                                    HapticFeedback.selectionClick();
                                    if (widget.controller.chapterHighlights
                                        .containsKey(verse.verse)) {
                                      await widget.controller
                                          .removeVerseHighlights([verse.verse]);
                                    } else {
                                      await widget.controller
                                          .setVerseHighlight([verse.verse], '#FFEB3B');
                                    }
                                  }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: verseWidget,
                            ),
                          ),
                        ),
                      ),
                    ];
                  }),
                  Semantics(
                    container: true,
                    label:
                        'Conclusão de leitura de ${chapter.bookName} capítulo ${chapter.chapter}',
                    child: Container(
                      margin: const EdgeInsets.only(top: 28, bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fim de ${chapter.bookName} ${chapter.chapter}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton.icon(
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              GamificationService().mission2LivingWord
                                  ? 'Concluído hoje ✓'
                                  : 'Capítulo Lido! (+40 gotas)',
                            ),
                            onPressed: GamificationService().mission2LivingWord
                                ? null
                                : () async {
                                    await GamificationService().recordChapterRead();
                                    if (context.mounted) {
                                      setState(() {});
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
  }
}
