import 'package:flutter/material.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../models/sabbath_school_models.dart';
import 'widgets/quarterly_selection_dialog.dart';

class SabbathSchoolView extends StatefulWidget {
  final SabbathSchoolController controller;

  const SabbathSchoolView({super.key, required this.controller});

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

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 450;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.school_outlined, size: 24),
                    const SizedBox(width: 8),
                    if (!isCompact) ...[
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
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Escolher Trimestre',
                onPressed: () => QuarterlySelectionDialog.show(context, ctrl),
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(
        children: [
          Expanded(
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${ctrl.selectedQuarterly!.title} (${ctrl.selectedQuarterly!.humanDate})',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
                Text(
                  'Lição ${lesson.index} • ${lesson.title}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          if (ctrl.lessons.length > 1)
            DropdownButtonHideUnderline(
              child: DropdownButton<SSLesson>(
                value: ctrl.selectedLesson,
                items: ctrl.lessons.map((l) {
                  return DropdownMenuItem(
                    value: l,
                    child: Text('Lição ${l.index}'),
                  );
                }).toList(),
                onChanged: (l) {
                  if (l != null) ctrl.selectLesson(l);
                },
              ),
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

      if (trimmed.startsWith('#### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              trimmed.substring(5).trim(),
              style: TextStyle(
                fontSize: fontSize + 1,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        );
        i++;
      } else if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Text(
              trimmed.substring(4).trim(),
              style: TextStyle(
                fontSize: fontSize + 3,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
        i++;
      } else if (trimmed.startsWith('> ') || trimmed == '>') {
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
        // Normal paragraph with basic bold/italic inline parsing
        final List<String> paraLines = [];
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !lines[i].trim().startsWith('#') &&
            !lines[i].trim().startsWith('>')) {
          paraLines.add(lines[i].trim());
          i++;
        }
        final paraText = paraLines.join(' ');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildFormattedParagraph(paraText, fontSize, theme),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildFormattedParagraph(String text, double fontSize, ThemeData theme) {
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*)');
    int lastMatchEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(text: text.substring(lastMatchEnd, match.start)),
        );
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('**') && matchText.endsWith('**')) {
        spans.add(
          TextSpan(
            text: matchText.substring(2, matchText.length - 2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );
      } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
        spans.add(
          TextSpan(
            text: matchText.substring(1, matchText.length - 1),
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
