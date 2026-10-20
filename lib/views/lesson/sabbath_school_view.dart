import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../data/repositories/bible_repository.dart';
import '../../models/sabbath_school_models.dart';
import 'widgets/quarterly_selection_dialog.dart';
import 'widgets/verse_dialog.dart';

class SabbathSchoolView extends StatefulWidget {
  final SabbathSchoolController controller;
  final BibleRepository? bibleRepository;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const SabbathSchoolView({
    super.key,
    required this.controller,
    this.bibleRepository,
    this.bibleController,
    this.onNavigateToTab,
  });

  @override
  State<SabbathSchoolView> createState() => _SabbathSchoolViewState();
}

class _SabbathSchoolViewState extends State<SabbathSchoolView> {
  final TextEditingController _noteTextController = TextEditingController();
  String? _lastLoadedDayId;

  @override
  void initState() {
    super.initState();
    widget.controller.init().then((_) {
      if (mounted) {
        _syncNoteText(widget.controller);
      }
    });
  }

  void _syncNoteText(SabbathSchoolController ctrl) {
    final currentDayId = ctrl.selectedDay?.id;
    if (_lastLoadedDayId != currentDayId) {
      _lastLoadedDayId = currentDayId;
      _noteTextController.text = ctrl.currentNote;
    }
  }

  @override
  void dispose() {
    _noteTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        _syncNoteText(ctrl);

        final isMobile = MediaQuery.of(context).size.width < 600;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: isMobile ? 8 : 16,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  const Icon(Icons.school_outlined, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Escola Sabatina',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                ],
                // Seletor de categoria (Adultos / Jovens)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'adultos', label: Text('Adultos')),
                    ButtonSegment(value: 'jovens', label: Text('Jovens')),
                  ],
                  selected: {ctrl.category},
                  onSelectionChanged: (Set<String> newSelection) {
                    ctrl.setCategory(newSelection.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Escolher Trimestre',
                onPressed: () => QuarterlySelectionDialog.show(context, ctrl),
              ),
              if (!isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  tooltip: 'Diminuir fonte',
                  onPressed: () => ctrl.changeFontSize(-1.0),
                ),
                Center(
                  child: Text(
                    '${ctrl.fontSize.toInt()}pt',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  tooltip: 'Aumentar fonte',
                  onPressed: () => ctrl.changeFontSize(1.0),
                ),
              ],
              const SizedBox(width: 8),
            ],
          ),
          body: _buildBody(ctrl),
        );
      },
    );
  }

  Widget _buildBody(SabbathSchoolController ctrl) {
    if (ctrl.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
              Text(ctrl.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ctrl.init(),
                child: const Text('Recarregar'),
              ),
            ],
          ),
        ),
      );
    }

    if (ctrl.selectedLesson == null || ctrl.selectedDay == null) {
      return const Center(child: Text('Nenhuma lição encontrada.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Column(
          children: [
            _buildLessonHeader(ctrl),
            _buildDaysCarousel(ctrl),
            const Divider(height: 1),
            Expanded(
              child: isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildReader(ctrl),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          flex: 2,
                          child: _buildNotesSection(ctrl),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildReaderContent(ctrl),
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildNotesCard(ctrl),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLessonHeader(SabbathSchoolController ctrl) {
    final lesson = ctrl.selectedLesson!;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ctrl.selectedQuarterly != null)
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => QuarterlySelectionDialog.show(context, ctrl),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${ctrl.selectedQuarterly!.title} (${ctrl.selectedQuarterly!.humanDate})',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lição ${lesson.index} • ${lesson.title}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lesson.startDate.isNotEmpty && lesson.endDate.isNotEmpty)
                      Text(
                        '${lesson.startDate} a ${lesson.endDate}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (ctrl.lessons.length > 1) ...[
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<SSLesson>(
                    value: ctrl.selectedLesson,
                    isDense: true,
                    items: ctrl.lessons.map((l) {
                      return DropdownMenuItem(
                        value: l,
                        child: Text(
                          'Lição ${l.index}',
                          style: TextStyle(fontSize: isMobile ? 13 : 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (l) {
                      if (l != null) ctrl.selectLesson(l);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDaysCarousel(SabbathSchoolController ctrl) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: ctrl.days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = ctrl.days[index];
          final isSelected = day.id == ctrl.selectedDay?.id;

          return ChoiceChip(
            label: Text(day.title),
            selected: isSelected,
            onSelected: (_) => ctrl.selectDay(day),
          );
        },
      ),
    );
  }

  Widget _buildReader(SabbathSchoolController ctrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: _buildReaderContent(ctrl),
    );
  }

  Widget _buildReaderContent(SabbathSchoolController ctrl) {
    final day = ctrl.selectedDay!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                day.title,
                style: TextStyle(
                  fontSize: ctrl.fontSize + 4,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (day.date.isNotEmpty)
              Chip(
                label: Text(
                  day.date,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 16),
        ..._parseMarkdownBlocks(day.content, ctrl.fontSize, context),
      ],
    );
  }

  List<Widget> _parseMarkdownBlocks(String text, double fontSize, BuildContext context) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');
    final theme = Theme.of(context);

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        i++;
        continue;
      }

      // 1. Imagens markdown ![alt](src)
      final imgMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
        final alt = imgMatch.group(1) ?? '';
        final src = imgMatch.group(2) ?? '';
        widgets.add(_buildImageBlock(src, alt, theme));
        i++;
        continue;
      }

      // 2. Títulos (#, ##, ###, ####)
      final headingMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final titleText = headingMatch.group(2)!.trim();
        final headingSize = switch (level) {
          1 => fontSize + 6,
          2 => fontSize + 4,
          3 => fontSize + 3,
          _ => fontSize + 1,
        };
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: level <= 2 ? 20 : 14, bottom: 8),
            child: Text(
              titleText,
              style: TextStyle(
                fontSize: headingSize,
                fontWeight: FontWeight.bold,
                color: level <= 3 ? theme.colorScheme.primary : theme.colorScheme.secondary,
              ),
            ),
          ),
        );
        i++;
        continue;
      }

      // 3. Listas
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final itemText = trimmed.substring(2).trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                Expanded(
                  child: _buildFormattedParagraph(itemText, fontSize, theme),
                ),
              ],
            ),
          ),
        );
        i++;
        continue;
      }

      // 4. Blockquotes (> Citação)
      if (trimmed.startsWith('> ') || trimmed == '>') {
        final List<String> quoteLines = [];
        while (i < lines.length && (lines[i].trim().startsWith('>') || lines[i].trim().isEmpty && quoteLines.isNotEmpty)) {
          final qLine = lines[i].trim();
          if (qLine.startsWith('>')) {
            quoteLines.add(qLine.replaceFirst(RegExp(r'^>\s*'), ''));
          } else {
            break;
          }
          i++;
        }
        final quoteText = quoteLines.join(' ');
        widgets.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 4,
                ),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: SelectableText(
              quoteText.replaceAll('*', '').replaceAll('"', ''),
              style: TextStyle(
                fontSize: fontSize,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        );
      } else {
        // 5. Parágrafo comum
        final List<String> paraLines = [];
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !lines[i].trim().startsWith('#') &&
            !lines[i].trim().startsWith('>') &&
            !RegExp(r'^!\[(.*?)\]\((.*?)\)$').hasMatch(lines[i].trim())) {
          paraLines.add(lines[i].trim());
          i++;
        }
        final paraText = paraLines.join(' ');
        if (paraText.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFormattedParagraph(paraText, fontSize, theme),
            ),
          );
        }
      }
    }

    return widgets;
  }

  Widget _buildImageBlock(String src, String alt, ThemeData theme) {
    String cleanSrc = src.trim();
    if (cleanSrc.contains('/assets/cache/')) {
      cleanSrc = cleanSrc.substring(cleanSrc.indexOf('assets/cache/'));
    }

    final isNetwork = cleanSrc.startsWith('http://') || cleanSrc.startsWith('https://');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showImageZoomDialog(cleanSrc, isNetwork, alt),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              isNetwork
                  ? Image.network(
                      cleanSrc,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(alt, theme),
                    )
                  : Image.asset(
                      cleanSrc,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(alt, theme),
                    ),
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Clique para ampliar',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageZoomDialog(String src, bool isNetwork, String alt) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isNetwork
                    ? Image.network(src, fit: BoxFit.contain)
                    : Image.asset(src, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(String alt, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            alt.isNotEmpty ? alt : 'Ilustração da Lição',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showVersePopup(String bibleReference) {
    VerseDialog.show(
      context,
      reference: bibleReference,
      bibleRepository: widget.bibleRepository,
      bibleController: widget.bibleController,
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  Widget _buildFormattedParagraph(String text, double fontSize, ThemeData theme) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'(\[([^\]]+)\]\(([^)]+)\)|\*\*[^*]+\*\*|\*[^*]+\*)');
    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(text: text.substring(lastMatchEnd, match.start)),
        );
      }

      final fullMatch = match.group(0)!;
      final linkText = match.group(2);
      final linkUrl = match.group(3);

      if (linkText != null && linkUrl != null) {
        final cleanUrl = Uri.decodeComponent(linkUrl.replaceFirst('bible://', '').trim());
        spans.add(
          TextSpan(
            text: linkText,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
              decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showVersePopup(cleanUrl.isNotEmpty ? cleanUrl : linkText);
              },
          ),
        );
      } else if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        spans.add(
          TextSpan(
            text: fullMatch.substring(2, fullMatch.length - 2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        spans.add(
          TextSpan(
            text: fullMatch.substring(1, fullMatch.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
        children: spans,
      ),
    );
  }

  Widget _buildNotesSection(SabbathSchoolController ctrl) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: _buildNotesCard(ctrl),
    );
  }

  Widget _buildNotesCard(SabbathSchoolController ctrl) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Anotações do Dia',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteTextController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Escreva suas reflexões pessoais deste estudo...',
                border: OutlineInputBorder(),
              ),
              onChanged: (text) => ctrl.updateNote(text),
            ),
          ],
        ),
      ),
    );
  }
}
