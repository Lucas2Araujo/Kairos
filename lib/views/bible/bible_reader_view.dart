import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_verse.dart';
import '../../services/content_manager.dart';
import '../../services/theme_service.dart';
import 'widgets/bible_immersive_view.dart';
import 'widgets/bible_settings_sheet.dart';
import 'widgets/book_chapter_selector_sheet.dart';
import 'widgets/study_bottom_sheet.dart';

class BibleReaderView extends StatefulWidget {
  final BibleController controller;
  final VoidCallback? onBackToPrevious;

  static const Set<int> poeticBookIds = {18, 19, 20, 21, 22, 25};
  static bool isPoeticBook(int? bookId) => bookId != null && poeticBookIds.contains(bookId);

  static List<({String text, bool isIndent, double indent})> parsePoeticLines(String text) {
    List<String> rawLines;
    if (text.contains('\n')) {
      rawLines = text.split('\n');
    } else {
      final formatted = text
          .replaceAllMapped(RegExp(r'([;:])\s+'), (m) => '${m[1]}\n')
          .replaceAllMapped(
            RegExp(r',\s+(?=(?:mas|porque|pois)\s+)', caseSensitive: false),
            (m) => ',\n',
          );
      rawLines = formatted.split('\n');
    }
    final clean = rawLines.map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (clean.isEmpty) return [(text: text.trim(), isIndent: false, indent: 0.0)];
    return [
      for (int i = 0; i < clean.length; i++)
        (text: clean[i], isIndent: i > 0, indent: i > 0 ? 16.0 : 0.0),
    ];
  }

  const BibleReaderView({
    super.key,
    required this.controller,
    this.onBackToPrevious,
  });

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  final Map<int, String> _selectedVerses = {};
  final Map<String, GlobalKey> _verseKeys = {};
  bool _controlsVisible = true;

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
  }

  GlobalKey _verseKey(int verse, [int? bookId, int? chapter]) {
    final b = bookId ?? widget.controller.selectedBook?.id ?? 0;
    final c = chapter ?? widget.controller.selectedChapter;
    return _verseKeys.putIfAbsent('$b:$c:$verse', () => GlobalKey());
  }
  int? _lastScrolledTargetVerse;
  int? _lastScrolledChapter;
  int? _lastScrolledBookId;
  int? _currentBookId;
  int? _currentChapter;

  static const List<Color> _highlightColors = [
    Color(0xFFFFEB3B), // Amarelo
    Color(0xFFA5D6A7), // Verde
    Color(0xFF90CAF9), // Azul
    Color(0xFFF48FB1), // Rosa
    Color(0xFFFFCC80), // Laranja
  ];

  static const Set<int> _poeticBookIds = BibleReaderView.poeticBookIds;
  bool _isPoeticBook(int? bookId) => bookId != null && _poeticBookIds.contains(bookId);
  List<({String text, bool isIndent, double indent})> parsePoeticLines(String text) =>
      BibleReaderView.parsePoeticLines(text);

  static Color? _parseHighlightColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var clean = hex.replaceAll('#', '');
    if (clean.length == 6) clean = 'FF$clean';
    final val = int.tryParse(clean, radix: 16);
    return val != null ? Color(val) : null;
  }

  static String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  void _toggleVerseSelection(BibleVerse verse) {
    setState(() {
      if (_selectedVerses.containsKey(verse.verse)) {
        _selectedVerses.remove(verse.verse);
      } else {
        _selectedVerses[verse.verse] = verse.text;
        _controlsVisible = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedVerses.clear();
    });
  }

  String _formatSelectedCitation(BibleController ctrl) {
    if (_selectedVerses.isEmpty || ctrl.selectedBook == null) return '';
    final sortedKeys = _selectedVerses.keys.toList()..sort();
    final bookName = ctrl.selectedBook!.name;
    final chapter = ctrl.selectedChapter;

    final List<String> ranges = [];
    int start = sortedKeys[0];
    int prev = sortedKeys[0];
    for (int i = 1; i < sortedKeys.length; i++) {
      int curr = sortedKeys[i];
      if (curr == prev + 1) {
        prev = curr;
      } else {
        ranges.add(start == prev ? '$start' : '$start-$prev');
        start = curr;
        prev = curr;
      }
    }
    ranges.add(start == prev ? '$start' : '$start-$prev');
    final rangeStr = ranges.join(', ');

    final bool isSequential = sortedKeys.length > 1 &&
        sortedKeys.last - sortedKeys.first == sortedKeys.length - 1;

    String body;
    if (sortedKeys.length == 1) {
      body = _selectedVerses[sortedKeys.first]!.trim();
    } else if (isSequential) {
      body = sortedKeys.map((k) => _selectedVerses[k]!.trim()).join(' ');
    } else {
      body = sortedKeys.map((k) => '$k ${_selectedVerses[k]!.trim()}').join('\n');
    }

    return '"$body"\n— $bookName $chapter:$rangeStr (${ctrl.activeVersion})';
  }

  void _copySelectedVerses(BibleController ctrl) {
    final citation = _formatSelectedCitation(ctrl);
    if (citation.isEmpty) return;
    Clipboard.setData(ClipboardData(text: citation));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_selectedVerses.length} versículo(s) copiado(s)!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    _clearSelection();
  }

  Future<void> _applyHighlightColor(Color color, BibleController ctrl) async {
    final hex = _colorToHex(color);
    final verses = _selectedVerses.keys.toList();
    await ctrl.setVerseHighlight(verses, hex);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${verses.length} versículo(s) destacado(s)!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _clearSelection();
  }

  Future<void> _removeHighlight(BibleController ctrl) async {
    final verses = _selectedVerses.keys.toList();
    await ctrl.removeVerseHighlights(verses);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destaque removido dos versículos selecionados.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final contentManager = ContentManager();

    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, themeService, contentManager]),
      builder: (context, _) {
        final ctrl = widget.controller;
        if (_currentBookId != ctrl.selectedBook?.id || _currentChapter != ctrl.selectedChapter) {
          _currentBookId = ctrl.selectedBook?.id;
          _currentChapter = ctrl.selectedChapter;
          _verseKeys.clear();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final targetKey = '${ctrl.selectedBook?.id ?? 0}:${ctrl.selectedChapter}:${ctrl.targetVerse}';
          if (ctrl.targetVerse != null && _verseKeys.containsKey(targetKey)) {
            final shouldScroll = _lastScrolledTargetVerse != ctrl.targetVerse ||
                _lastScrolledChapter != ctrl.selectedChapter ||
                _lastScrolledBookId != ctrl.selectedBook?.id;
            if (shouldScroll) {
              _lastScrolledTargetVerse = ctrl.targetVerse;
              _lastScrolledChapter = ctrl.selectedChapter;
              _lastScrolledBookId = ctrl.selectedBook?.id;
              final ctx = _verseKeys[targetKey]!.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  alignment: 0.15,
                );
              }
            }
          }
        });

        return Scaffold(
          appBar: (themeService.isImmersiveReading && !_controlsVisible)
              ? null
              : _buildStandardAppBar(ctrl),
          body: _buildBody(ctrl, themeService),
        );
      },
    );
  }

  PreferredSizeWidget _buildStandardAppBar(BibleController ctrl) {
    final theme = Theme.of(context);
    return AppBar(
      centerTitle: true,
      leading: widget.onBackToPrevious != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar à tela anterior',
              onPressed: widget.onBackToPrevious,
            )
          : null,
      title: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => BibleSettingsSheet.show(context, ctrl),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ctrl.activeVersion,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Configurações de Leitura',
          onPressed: () => BibleSettingsSheet.show(context, ctrl),
        ),
      ],
    );
  }

  Widget _buildSelectionActionSheet(BibleController ctrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final activeHex = _selectedVerses.keys
        .map((v) => ctrl.chapterHighlights[v])
        .cast<String?>()
        .firstWhere((h) => h != null, orElse: () => null);

    final sortedKeys = _selectedVerses.keys.toList()..sort();
    final firstVerseNum = sortedKeys.isNotEmpty ? sortedKeys.first : null;
    BibleVerse? firstSelectedVerse;
    if (firstVerseNum != null) {
      for (final v in ctrl.verses) {
        if (v.verse == firstVerseNum) {
          firstSelectedVerse = v;
          break;
        }
      }
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              elevation: 8,
              shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.18),
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bloco 1: Cabeçalho do Pop-up
                    Row(
                      children: [
                        Icon(
                          Icons.format_quote_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedVerses.length == 1
                                ? '${ctrl.selectedBook?.name ?? ''} ${ctrl.selectedChapter}:${_selectedVerses.keys.first}'
                                : '${_selectedVerses.length} versículos selecionados',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Cancelar seleção',
                          visualDensity: VisualDensity.compact,
                          onPressed: _clearSelection,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bloco 2: Paleta de Cores Ampliada (38x38 px)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ..._highlightColors.map((color) {
                          final isColorActive = activeHex != null &&
                              activeHex.toUpperCase() ==
                                  _colorToHex(color).toUpperCase();
                          return Tooltip(
                            message: 'Destacar',
                            child: InkWell(
                              onTap: () => _applyHighlightColor(color, ctrl),
                              borderRadius: BorderRadius.circular(19),
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isColorActive
                                        ? theme.colorScheme.onSurface
                                        : Colors.white.withValues(alpha: 0.85),
                                    width: isColorActive ? 2.5 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(
                                          alpha: isColorActive ? 0.6 : 0.35),
                                      blurRadius: isColorActive ? 6 : 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: isColorActive
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 20,
                                        color: Colors.black87,
                                      )
                                    : null,
                              ),
                            ),
                          );
                        }),
                        Tooltip(
                          message: 'Remover destaque',
                          child: InkWell(
                            onTap: () => _removeHighlight(ctrl),
                            borderRadius: BorderRadius.circular(19),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.format_color_reset_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Bloco 3: Botões de Ação Harmônicos lado a lado
                    Row(
                      children: [
                        if (firstSelectedVerse != null) ...[
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                final v = firstSelectedVerse!;
                                _clearSelection();
                                StudyBottomSheet.show(context, ctrl, v);
                              },
                              icon: const Icon(Icons.menu_book_rounded, size: 18),
                              label: const Text(
                                'Estudo',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => _copySelectedVerses(ctrl),
                            icon: const Icon(Icons.content_copy_rounded, size: 18),
                            label: const Text(
                              'Copiar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContextBar(BibleController ctrl) {
    final theme = Theme.of(context);

    void onChipTap(String ref) {
      final match = RegExp(r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::(\d+))?').firstMatch(ref.trim());
      if (match != null) {
        final book = match.group(1) ?? '';
        final ch = int.tryParse(match.group(2) ?? '1') ?? 1;
        final v = int.tryParse(match.group(3) ?? '1') ?? 1;
        _clearSelection();
        ctrl.jumpToVerse(book, ch, v);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bookmark_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '${ctrl.studyContextTitle ?? "Estudo"}:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ctrl.studyContextRefs.map((ref) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        ref,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => onChipTap(ref),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Fechar contexto',
            visualDensity: VisualDensity.compact,
            onPressed: () => ctrl.clearStudyContext(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BibleController ctrl, ThemeService themeService) {
    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (ctrl.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
              const SizedBox(height: 12),
              Text(
                ctrl.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ctrl.init(),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final Widget rawContent = ctrl.verses.isEmpty
        ? const Center(
            key: ValueKey('empty_chapter'),
            child: Text('Nenhum versículo encontrado para este capítulo.'),
          )
        : KeyedSubtree(
            key: ValueKey('${ctrl.activeVersion}_${ctrl.selectedBook?.id}_${ctrl.selectedChapter}_${themeService.readingMode.name}'),
            child: themeService.isImmersiveReading
                ? BibleImmersiveView(
                    controller: ctrl,
                    themeService: themeService,
                    onToggleControls: _toggleControls,
                    onSelectVerse: _toggleVerseSelection,
                    isVerseSelected: (verse) => _selectedVerses.containsKey(verse.verse),
                  )
                : (themeService.isContinuousReading
                    ? _buildContinuousReadingView(ctrl, themeService)
                    : _buildVerseListView(ctrl, themeService)),
          );

    final Widget animatedContent = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.02),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: rawContent,
    );

    final mainLayout = Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: ctrl.studyContextRefs.isNotEmpty
                ? KeyedSubtree(
                    key: const ValueKey('context_bar_active'),
                    child: _buildContextBar(ctrl),
                  )
                : const SizedBox.shrink(key: ValueKey('context_bar_none')),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity;
              if (velocity == null) return;
              if (velocity < -300) {
                HapticFeedback.lightImpact();
                ctrl.nextChapter();
              } else if (velocity > 300) {
                HapticFeedback.lightImpact();
                ctrl.previousChapter();
              }
            },
            child: animatedContent,
          ),
        ),
      ],
    );

    return Stack(
      children: [
        mainLayout,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.2),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: (themeService.isImmersiveReading && !_controlsVisible && _selectedVerses.isEmpty)
                ? const SizedBox.shrink(key: ValueKey('controls_hidden'))
                : (_selectedVerses.isNotEmpty
                    ? KeyedSubtree(
                        key: const ValueKey('selection_sheet_active'),
                        child: _buildSelectionActionSheet(ctrl),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('floating_pill_active'),
                        child: _buildFloatingBookChapterPill(ctrl),
                      )),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingBookChapterPill(BibleController ctrl) {
    final theme = Theme.of(context);
    final bookName = ctrl.selectedBook?.name ?? '';
    final chapter = ctrl.selectedChapter;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Center(
          child: Material(
            elevation: 6,
            shape: const StadiumBorder(),
            color: theme.colorScheme.surfaceContainerHigh,
            shadowColor: Colors.black.withValues(alpha: 0.25),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  iconSize: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  tooltip: 'Capítulo anterior',
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ctrl.previousChapter();
                  },
                ),
                InkWell(
                  onTap: () => _abrirSeletorLivroCapitulo(ctrl),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$bookName $chapter',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  iconSize: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  tooltip: 'Próximo capítulo',
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ctrl.nextChapter();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _abrirSeletorLivroCapitulo(BibleController ctrl) {
    _clearSelection();
    BookChapterSelectorSheet.show(context, ctrl);
  }

  Widget _buildVerseListView(BibleController ctrl, ThemeService themeService) {
    final theme = Theme.of(context);
    final multiplier = themeService.fontSizeMultiplier;
    final baseFontSize = 18.0 * multiplier;
    final textAlign = themeService.bibleTextAlign;

    final Map<int, String> pericopeMap = {
      for (final p in ctrl.pericopes) p.verse: p.title,
    };

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 20,
        bottom: _selectedVerses.isNotEmpty ? 170 : 88,
      ),
      itemCount: ctrl.verses.length,
      itemBuilder: (context, index) {
        final verse = ctrl.verses[index];
        final pericopeTitle = pericopeMap[verse.verse];
        final isSelected = _selectedVerses.containsKey(verse.verse);
        final isTarget = ctrl.targetVerse == verse.verse;
        final highlightHex = ctrl.chapterHighlights[verse.verse];
        final highlightColor = _parseHighlightColor(highlightHex);
        final verseKey = _verseKey(verse.verse, verse.bookId, verse.chapter);

        return Column(
          key: verseKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pericopeTitle != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Text(
                  pericopeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 16.0 * multiplier,
                  ),
                ),
              ),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _toggleVerseSelection(verse),
              onLongPress: () => _toggleVerseSelection(verse),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : (isTarget
                          ? theme.colorScheme.primary.withValues(alpha: 0.14)
                          : (highlightColor != null
                              ? highlightColor.withValues(alpha: 0.25)
                              : Colors.transparent)),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : (isTarget
                          ? Border.all(
                              color: theme.colorScheme.primary.withValues(alpha: 0.6),
                              width: 1.5,
                            )
                          : null),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isTarget)
                      Container(
                        width: 4,
                        height: 22,
                        margin: const EdgeInsets.only(top: 3, right: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    Container(
                      margin: EdgeInsets.only(top: 4 * multiplier, right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected || isTarget
                            ? theme.colorScheme.primary
                            : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${verse.verse}',
                        style: TextStyle(
                          fontSize: 12 * multiplier,
                          fontWeight: FontWeight.bold,
                          color: isSelected || isTarget || highlightColor != null
                              ? (isTarget && !isSelected ? theme.colorScheme.onPrimary : Colors.black87)
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isPoeticBook(ctrl.selectedBook?.id)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: parsePoeticLines(verse.text).map((line) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                    left: line.isIndent ? 16.0 : 0.0,
                                    bottom: 2.0,
                                  ),
                                  child: Text(
                                    line.text,
                                    textAlign: textAlign,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontFamily: themeService.fontFamily,
                                      fontSize: baseFontSize,
                                      height: 1.6,
                                    ),
                                  ),
                                );
                              }).toList(),
                            )
                          : Text(
                              verse.text,
                              textAlign: textAlign,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontFamily: themeService.fontFamily,
                                fontSize: baseFontSize,
                                height: 1.6,
                              ),
                            ),
                    ),
                    if (_selectedVerses.isEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.menu_book_outlined, size: 18),
                        tooltip: 'Estudo do Versículo',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => StudyBottomSheet.show(context, ctrl, verse),
                      ),
                    if (_selectedVerses.isNotEmpty)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleVerseSelection(verse),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContinuousReadingView(BibleController ctrl, ThemeService themeService) {
    if (_isPoeticBook(ctrl.selectedBook?.id)) {
      return _buildPoeticContinuousReadingView(ctrl, themeService);
    }

    final theme = Theme.of(context);
    final multiplier = themeService.fontSizeMultiplier;
    final baseFontSize = 18.0 * multiplier;
    final textAlign = themeService.bibleTextAlign;

    final Map<int, String> pericopeMap = {
      for (final p in ctrl.pericopes) p.verse: p.title,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: _selectedVerses.isNotEmpty ? 170 : 88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: ctrl.verses.expand<InlineSpan>((verse) {
                final pericopeTitle = pericopeMap[verse.verse];
                final isSelected = _selectedVerses.containsKey(verse.verse);
                final isTarget = ctrl.targetVerse == verse.verse;
                final highlightHex = ctrl.chapterHighlights[verse.verse];
                final highlightColor = _parseHighlightColor(highlightHex);
                final verseKey = _verseKey(verse.verse, verse.bookId, verse.chapter);

                final List<InlineSpan> spans = [];

                if (pericopeTitle != null) {
                  spans.add(
                    TextSpan(
                      text: '${verse.verse == 1 ? '' : '\n\n'}$pericopeTitle\n',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 17.0 * multiplier,
                        height: 1.8,
                      ),
                    ),
                  );
                }

                if (verse.verse == 1) {
                  spans.add(
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        key: verseKey,
                        onTap: () => _toggleVerseSelection(verse),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6.0, left: 2.0),
                          child: Text(
                            '${ctrl.selectedChapter}',
                            style: TextStyle(
                              fontFamily: themeService.fontFamily,
                              fontSize: 34.0 * multiplier,
                              fontWeight: FontWeight.bold,
                              height: 0.95,
                              color: isSelected || isTarget
                                  ? theme.colorScheme.primary
                                  : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.88)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  spans.add(
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: GestureDetector(
                        key: verseKey,
                        onTap: () => _toggleVerseSelection(verse),
                        child: Container(
                          margin: const EdgeInsets.only(right: 4, left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected || isTarget
                                ? theme.colorScheme.primary
                                : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${verse.verse}',
                            style: TextStyle(
                              fontSize: 11 * multiplier,
                              fontWeight: FontWeight.bold,
                              color: isSelected || isTarget || highlightColor != null
                                  ? (isTarget && !isSelected ? theme.colorScheme.onPrimary : Colors.black87)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                spans.add(
                  TextSpan(
                    text: '${verse.text} ',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: themeService.fontFamily,
                      fontSize: baseFontSize,
                      height: 1.7,
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : (isTarget
                              ? theme.colorScheme.primary.withValues(alpha: 0.16)
                              : (highlightColor != null
                                  ? highlightColor.withValues(alpha: 0.28)
                                  : Colors.transparent)),
                    ),
                  ),
                );

                return spans;
              }).toList(),
            ),
            textAlign: textAlign,
            strutStyle: StrutStyle(
              fontFamily: themeService.fontFamily,
              fontSize: baseFontSize,
              height: 1.7,
              forceStrutHeight: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoeticContinuousReadingView(BibleController ctrl, ThemeService themeService) {
    final theme = Theme.of(context);
    final multiplier = themeService.fontSizeMultiplier;
    final baseFontSize = 18.0 * multiplier;
    final textAlign = themeService.bibleTextAlign;

    final Map<int, String> pericopeMap = {
      for (final p in ctrl.pericopes) p.verse: p.title,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: _selectedVerses.isNotEmpty ? 170 : 88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final verse in ctrl.verses) ...[
            if (pericopeMap[verse.verse] != null)
              Padding(
                padding: EdgeInsets.only(
                  top: verse.verse == 1 ? 0.0 : 20.0,
                  bottom: 12.0,
                ),
                child: Text(
                  pericopeMap[verse.verse]!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 17.0 * multiplier,
                    height: 1.4,
                  ),
                ),
              ),
            _buildPoeticVerseStanza(verse, ctrl, themeService, baseFontSize, textAlign, multiplier),
          ],
        ],
      ),
    );
  }

  Widget _buildPoeticVerseStanza(
    BibleVerse verse,
    BibleController ctrl,
    ThemeService themeService,
    double baseFontSize,
    TextAlign textAlign,
    double multiplier,
  ) {
    final theme = Theme.of(context);
    final isSelected = _selectedVerses.containsKey(verse.verse);
    final isTarget = ctrl.targetVerse == verse.verse;
    final highlightHex = ctrl.chapterHighlights[verse.verse];
    final highlightColor = _parseHighlightColor(highlightHex);
    final verseKey = _verseKey(verse.verse, verse.bookId, verse.chapter);
    final lines = parsePoeticLines(verse.text);

    final verseTextStyle = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: themeService.fontFamily,
      fontSize: baseFontSize,
      height: 1.6,
    );

    Widget content;
    if (verse.verse == 1) {
      // Versículo 1: Drop Cap com o número do capítulo
      final sideLines = lines.length <= 2 ? lines : lines.sublist(0, 2);
      final belowLines = lines.length <= 2
          ? <({String text, bool isIndent, double indent})>[]
          : lines.sublist(2);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTarget)
                Container(
                  width: 4,
                  height: 42 * multiplier,
                  margin: const EdgeInsets.only(top: 2, right: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0, top: 1.0),
                child: Text(
                  '${ctrl.selectedChapter}',
                  style: TextStyle(
                    fontFamily: themeService.fontFamily,
                    fontSize: 44.0 * multiplier,
                    fontWeight: FontWeight.bold,
                    height: 0.95,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < sideLines.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          left: sideLines[i].isIndent ? 16.0 : 0.0,
                          bottom: 3.0,
                        ),
                        child: Text(
                          sideLines[i].text,
                          textAlign: textAlign,
                          style: verseTextStyle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (belowLines.isNotEmpty)
            for (int i = 0; i < belowLines.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  left: belowLines[i].isIndent ? 16.0 : 0.0,
                  top: 3.0,
                  bottom: 3.0,
                ),
                child: Text(
                  belowLines[i].text,
                  textAlign: textAlign,
                  style: verseTextStyle,
                ),
              ),
        ],
      );
    } else {
      // Versículos > 1: badge miniatura de versículo na linha 0, com stichs subsequentes recuados
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTarget)
            Container(
              width: 4,
              height: 22,
              margin: const EdgeInsets.only(top: 3, right: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Container(
            margin: EdgeInsets.only(top: 3.0 * multiplier, right: 8.0),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected || isTarget
                  ? theme.colorScheme.primary
                  : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${verse.verse}',
              style: TextStyle(
                fontSize: 11 * multiplier,
                fontWeight: FontWeight.bold,
                color: isSelected || isTarget || highlightColor != null
                    ? (isTarget && !isSelected ? theme.colorScheme.onPrimary : Colors.black87)
                    : theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lines.first.text,
                  textAlign: textAlign,
                  style: verseTextStyle,
                ),
                for (int i = 1; i < lines.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      left: lines[i].isIndent ? 16.0 : 0.0,
                      top: 3.0,
                    ),
                    child: Text(
                      lines[i].text,
                      textAlign: textAlign,
                      style: verseTextStyle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      key: verseKey,
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleVerseSelection(verse),
        onLongPress: () => _toggleVerseSelection(verse),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : (isTarget
                    ? theme.colorScheme.primary.withValues(alpha: 0.14)
                    : (highlightColor != null
                        ? highlightColor.withValues(alpha: 0.25)
                        : Colors.transparent)),
            border: isSelected
                ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                : (isTarget
                    ? Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        width: 1.5,
                      )
                    : null),
          ),
          child: content,
        ),
      ),
    );
  }
}
