import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_verse.dart';
import '../../services/content_manager.dart';
import '../../services/theme_service.dart';
import '../downloads/downloads_dialog.dart';
import 'widgets/study_bottom_sheet.dart';

class BibleReaderView extends StatefulWidget {
  final BibleController controller;
  final VoidCallback? onBackToPrevious;

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

  static const List<Color> _highlightColors = [
    Color(0xFFFFEB3B), // Amarelo
    Color(0xFFA5D6A7), // Verde
    Color(0xFF90CAF9), // Azul
    Color(0xFFF48FB1), // Rosa
    Color(0xFFFFCC80), // Laranja
  ];

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

        return Scaffold(
          appBar: _selectedVerses.isNotEmpty
              ? _buildSelectionAppBar(ctrl)
              : _buildStandardAppBar(ctrl),
          body: _buildBody(ctrl, themeService),
          bottomSheet: _selectedVerses.isNotEmpty ? _buildSelectionActionSheet(ctrl) : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildStandardAppBar(BibleController ctrl) {
    return AppBar(
      leading: widget.onBackToPrevious != null
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Voltar à tela anterior',
              onPressed: widget.onBackToPrevious,
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ctrl.books.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<BibleBook>(
                value: ctrl.selectedBook,
                dropdownColor: Theme.of(context).cardTheme.color,
                items: ctrl.books.map((book) {
                  return DropdownMenuItem(
                    value: book,
                    child: Text(
                      book.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                onChanged: (book) {
                  if (book != null) {
                    _clearSelection();
                    ctrl.selectBook(book);
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
          if (ctrl.selectedBook != null)
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: ctrl.selectedChapter,
                dropdownColor: Theme.of(context).cardTheme.color,
                items: List.generate(
                  ctrl.selectedBook!.chaptersCount,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text('Capítulo ${index + 1}'),
                  ),
                ),
                onChanged: (chapter) {
                  if (chapter != null) {
                    _clearSelection();
                    ctrl.selectChapter(chapter);
                  }
                },
              ),
            ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: ctrl.activeVersion,
              dropdownColor: Theme.of(context).cardTheme.color,
              items: [
                ...ContentManager().bibleModules.map((mod) {
                  return DropdownMenuItem<String>(
                    value: mod.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mod.id,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (!mod.isInstalled) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                if (ContentManager().bibleModules.isEmpty)
                  DropdownMenuItem<String>(
                    value: ctrl.activeVersion,
                    child: Text(
                      ctrl.activeVersion,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                const DropdownMenuItem<String>(
                  value: '__manage_downloads__',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_for_offline_outlined, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Gerenciar Traduções...',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (ver) {
                if (ver == '__manage_downloads__') {
                  DownloadsDialog.show(context);
                } else if (ver != null) {
                  _clearSelection();
                  ctrl.selectVersion(ver);
                }
              },
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            ThemeService().isContinuousReading ? Icons.view_agenda : Icons.view_headline,
          ),
          tooltip: ThemeService().isContinuousReading
              ? 'Alternar para lista de versículos'
              : 'Alternar para texto corrido',
          onPressed: () {
            ThemeService().setContinuousReading(!ThemeService().isContinuousReading);
          },
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BibleController ctrl) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancelar seleção',
        onPressed: _clearSelection,
      ),
      title: Text(
        '${_selectedVerses.length} selecionado(s)',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copiar versículo(s)',
          onPressed: () => _copySelectedVerses(ctrl),
        ),
      ],
    );
  }

  Widget _buildSelectionActionSheet(BibleController ctrl) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    BibleVerse? singleSelectedVerse;
    if (_selectedVerses.length == 1) {
      final vNum = _selectedVerses.keys.first;
      final match = ctrl.verses.where((v) => v.verse == vNum);
      if (match.isNotEmpty) singleSelectedVerse = match.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            ..._highlightColors.map((color) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: InkWell(
                  onTap: () => _applyHighlightColor(color, ctrl),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            IconButton(
              icon: const Icon(Icons.format_color_reset, size: 22),
              tooltip: 'Remover marcação',
              onPressed: () => _removeHighlight(ctrl),
            ),
            const Spacer(),
            if (singleSelectedVerse != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  final v = singleSelectedVerse!;
                  _clearSelection();
                  StudyBottomSheet.show(context, ctrl, v);
                },
                icon: const Icon(Icons.menu_book, size: 16),
                label: const Text('Estudo'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: () => _copySelectedVerses(ctrl),
              icon: const Icon(Icons.content_copy, size: 18),
              label: const Text('Copiar'),
            ),
          ],
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
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
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

    final Widget content = ctrl.verses.isEmpty
        ? const Center(
            child: Text('Nenhum versículo encontrado para este capítulo.'),
          )
        : (themeService.isContinuousReading
            ? _buildContinuousReadingView(ctrl, themeService)
            : _buildVerseListView(ctrl, themeService));

    if (ctrl.studyContextRefs.isNotEmpty) {
      return Column(
        children: [
          _buildContextBar(ctrl),
          Expanded(child: content),
        ],
      );
    }

    return content;
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
        left: 16,
        right: 16,
        top: 20,
        bottom: _selectedVerses.isNotEmpty ? 80 : 24,
      ),
      itemCount: ctrl.verses.length,
      itemBuilder: (context, index) {
        final verse = ctrl.verses[index];
        final pericopeTitle = pericopeMap[verse.verse];
        final isSelected = _selectedVerses.containsKey(verse.verse);
        final highlightHex = ctrl.chapterHighlights[verse.verse];
        final highlightColor = _parseHighlightColor(highlightHex);

        return Column(
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
                      : (highlightColor != null
                          ? highlightColor.withValues(alpha: 0.25)
                          : Colors.transparent),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.12)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${verse.verse}',
                        style: TextStyle(
                          fontSize: 12 * multiplier,
                          fontWeight: FontWeight.bold,
                          color: isSelected || highlightColor != null
                              ? Colors.black87
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        verse.text,
                        textAlign: textAlign,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: baseFontSize,
                          height: 1.6,
                        ),
                      ),
                    ),
                    if (_selectedVerses.isEmpty)
                      IconButton(
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
        bottom: _selectedVerses.isNotEmpty ? 80 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: ctrl.verses.expand<InlineSpan>((verse) {
                final pericopeTitle = pericopeMap[verse.verse];
                final isSelected = _selectedVerses.containsKey(verse.verse);
                final highlightHex = ctrl.chapterHighlights[verse.verse];
                final highlightColor = _parseHighlightColor(highlightHex);

                final List<InlineSpan> spans = [];

                if (pericopeTitle != null) {
                  spans.add(
                    TextSpan(
                      text: '\n\n$pericopeTitle\n\n',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 17.0 * multiplier,
                        height: 1.8,
                      ),
                    ),
                  );
                }

                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: () => _toggleVerseSelection(verse),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4, left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (highlightColor ?? theme.colorScheme.primary.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${verse.verse}',
                          style: TextStyle(
                            fontSize: 11 * multiplier,
                            fontWeight: FontWeight.bold,
                            color: isSelected || highlightColor != null
                                ? Colors.black87
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                );

                spans.add(
                  TextSpan(
                    text: '${verse.text} ',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: baseFontSize,
                      height: 1.7,
                      backgroundColor: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                          : (highlightColor != null
                              ? highlightColor.withValues(alpha: 0.28)
                              : Colors.transparent),
                    ),
                  ),
                );

                return spans;
              }).toList(),
            ),
            textAlign: textAlign,
          ),
        ],
      ),
    );
  }
}
