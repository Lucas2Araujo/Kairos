import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../core/utils/bible_extractor.dart';
import '../../data/repositories/bible_repository.dart';
import '../../data/services/sabbath_school_service.dart';
import '../../models/sabbath_school_models.dart';
import '../../services/theme_service.dart';
import 'tirinha_view.dart';
import 'mind_map_studio_view.dart';
import 'widgets/quarterly_catalog_dialog.dart';
import 'widgets/lesson_selection_sheet.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';
import 'widgets/quick_quiz_bottom_sheet.dart';

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

  static bool _isWednesday(String dateStr) {
    if (dateStr.isEmpty) return false;
    final parts = dateStr.trim().split('/');
    if (parts.length >= 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        return DateTime(y, m, d).weekday == DateTime.wednesday;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.init().then((_) {
          if (mounted) {
            _syncNoteText(widget.controller);
          }
        });
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
    final themeService = ThemeService();
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, themeService]),
      builder: (context, _) {
        final ctrl = widget.controller;
        _syncNoteText(ctrl);

        final theme = Theme.of(context);
        final isMobile = MediaQuery.of(context).size.width < 600;

        return Scaffold(
          appBar: AppBar(
            titleSpacing: isMobile ? 8 : 16,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Escola Sabatina',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ctrl.category == 'jovens' ? 'Jovens' : 'Adultos',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.movie_filter_outlined),
                tooltip: 'Catálogo de Trimestres',
                onPressed: () => QuarterlyCatalogDialog.show(context, ctrl),
              ),
              if (ctrl.selectedDay != null &&
                  ctrl.category == 'jovens' &&
                  _isWednesday(ctrl.selectedDay!.date))
                IconButton(
                  icon: const Icon(Icons.hub_outlined),
                  tooltip: 'Mapa Mental',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MindMapStudioView(day: ctrl.selectedDay!),
                      ),
                    );
                  },
                ),
              if (!isMobile) ...[
                IconButton(
                  icon: const Icon(Icons.text_decrease),
                  tooltip: 'Diminuir fonte',
                  onPressed: () => themeService.setFontSizeMultiplier(themeService.fontSizeMultiplier - 0.1),
                ),
                Center(
                  child: Text(
                    '${(themeService.fontSizeMultiplier * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.text_increase),
                  tooltip: 'Aumentar fonte',
                  onPressed: () => themeService.setFontSizeMultiplier(themeService.fontSizeMultiplier + 0.1),
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
                        _buildAnimatedReaderContent(ctrl),
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
              onTap: () => QuarterlyCatalogDialog.show(context, ctrl),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        ctrl.selectedQuarterly!.title,
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
                OutlinedButton.icon(
                  onPressed: () => LessonSelectionSheet.show(context, ctrl),
                  icon: const Icon(Icons.format_list_numbered, size: 16),
                  label: Text('Lição ${lesson.index}', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      child: _buildAnimatedReaderContent(ctrl),
    );
  }

  Widget _buildAnimatedReaderContent(SabbathSchoolController ctrl) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('${ctrl.category}_${ctrl.selectedQuarterly?.id}_${ctrl.selectedLesson?.id}_${ctrl.selectedDay?.id}'),
        child: _buildReaderContent(ctrl),
      ),
    );
  }

  static const Map<String, String> _bundledTirinhaAssets = {
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-01-cq/lessons/01/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_a04823ed2c9c399e.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-01-cq/lessons/09/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_609dafe4ac998105.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-01-cq/lessons/13/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_c998db113a16cae6.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/01/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_0063d80dc4d08efa.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/02/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_ad8181ffbf953e43.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/03/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_6fcb81ad82c5c26b.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/04/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_ef2d095ac85c7c81.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/05/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_613d1233c4add52f.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/06/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_69172764f8b7cc42.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/07/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_0e094db2a6ee261e.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/08/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_f67bde5cf5b37f67.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/09/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_63273b24fd3bf5ac.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/10/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_781a6fe96a42747e.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/11/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_82c39d6008ea2303.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/12/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_4ce948c2dd2c843b.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-03-cq/lessons/13/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_a3687acc8347d80d.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-04-cq/lessons/01/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_73521f12b0be2517.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-04-cq/lessons/02/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_6891be153570733a.png',
    'https://sabbath-school.adventech.io/api/v2/pt/quarterlies/2026-04-cq/lessons/03/days/image.png':
        'assets/cache/escola_sabatina/images/ss_img_255c14c2d75ed5f2.png',
  };

  Widget _buildReaderContent(SabbathSchoolController ctrl) {
    final day = ctrl.selectedDay!;
    final isFirstDay = ctrl.days.isNotEmpty &&
        (ctrl.days.first.id == day.id ||
            day.id.endsWith('-01') ||
            day.date == ctrl.days.first.date);
    final showTirinhas = ctrl.category == 'jovens' && isFirstDay;
    final themeService = ThemeService();
    final effectiveFontSize = 17.0 * themeService.fontSizeMultiplier;

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
                  fontFamily: themeService.fontFamily,
                  fontSize: effectiveFontSize + 4,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (ctrl.category == 'jovens' && _isWednesday(day.date))
              IconButton(
                icon: const Icon(Icons.hub_outlined),
                tooltip: 'Mapa Mental da Lição',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MindMapStudioView(day: day),
                    ),
                  );
                },
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
        ..._parseMarkdownBlocks(
          day.content,
          effectiveFontSize,
          context,
          showImages: showTirinhas,
          dayId: day.id,
        ),
        const SizedBox(height: 28),
        _buildChallengeCard(context, ctrl, day),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChallengeCard(BuildContext context, SabbathSchoolController ctrl, SSDay day) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  color: theme.colorScheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hora do Desafio!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bora fixar o conteúdo da lição de hoje?',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Responder Quiz'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                QuickQuizBottomSheet.show(
                  context,
                  category: ctrl.category,
                  dayId: day.id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _parseMarkdownBlocks(
    String text,
    double fontSize,
    BuildContext context, {
    bool showImages = true,
    String? dayId,
  }) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');
    final theme = Theme.of(context);
    final themeService = ThemeService();

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        i++;
        continue;
      }

      // 1. Imagens markdown ![alt](src) — exclusivo da lição dos Jovens (tirinhas)
      final imgMatch = RegExp(r'^!\[(.*?)\]\((.*?)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
        if (showImages) {
          final alt = imgMatch.group(1) ?? '';
          final src = imgMatch.group(2) ?? '';
          widgets.add(_buildImageBlock(src, alt, theme));
        } else {
          // Na lição dos adultos, remove também a linha vazia adjacente para não deixar espaço sobrando
          if (widgets.isNotEmpty && widgets.last is SizedBox) {
            widgets.removeLast();
          }
        }
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
        while (i < lines.length && (lines[i].trim().startsWith('>') || (lines[i].trim().isEmpty && quoteLines.isNotEmpty))) {
          final qLine = lines[i].trim();
          if (qLine.startsWith('>')) {
            final cleaned = qLine.replaceFirst(RegExp(r'^>\s*'), '');
            if (cleaned.isNotEmpty) {
              quoteLines.add(cleaned);
            }
          } else {
            break;
          }
          i++;
        }
        final quoteText = quoteLines.join(' ').trim();
        if (quoteText.isNotEmpty) {
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
                textAlign: themeService.bibleTextAlign,
                style: TextStyle(
                  fontFamily: themeService.fontFamily,
                  fontSize: fontSize,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          );
        }
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
          // Detecta pergunta de reflexão com crase `pergunta?` ou no fim do texto sob trecho especial
          final isReflectionQuestion = dayId != null &&
              paraText.trim().startsWith('`') &&
              paraText.trim().endsWith('`') &&
              paraText.contains('?');

          if (isReflectionQuestion) {
            final cleanQuestion = paraText.trim().replaceAll('`', '').trim();
            widgets.add(
              _LessonQuestionCard(
                dayId: dayId,
                questionText: cleanQuestion,
                fontSize: fontSize,
                onTapVerse: _showVersePopup,
              ),
            );
          } else {
            widgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildFormattedParagraph(paraText, fontSize, theme),
              ),
            );
          }
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
    cleanSrc = cleanSrc.replaceAll(RegExp(r'/days/\d+/image\.png'), '/days/image.png');

    final bundledAsset = _bundledTirinhaAssets[cleanSrc];
    final effectiveSrc = bundledAsset ?? cleanSrc;
    final isNetwork = bundledAsset == null &&
        (effectiveSrc.startsWith('http://') || effectiveSrc.startsWith('https://'));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showImageZoomDialog(effectiveSrc, isNetwork, alt),
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
                      effectiveSrc,
                      fit: BoxFit.contain,
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(alt, theme),
                    )
                  : Image.asset(
                      effectiveSrc,
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
    TirinhaView.show(context, imageSrc: src, isNetwork: isNetwork, title: alt);
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
    final cleanRef = BibleExtractor.cleanReference(bibleReference);
    final content = widget.controller.selectedDay?.content ?? '';
    final contiguousRefs = BibleExtractor.getContiguousReferences(content, cleanRef);

    final dayTitle = widget.controller.selectedDay?.title;
    final title = (dayTitle != null && dayTitle.isNotEmpty)
        ? 'Lição ($dayTitle)'
        : 'Escola Sabatina';

    BibleVersePreviewModal.show(
      context,
      reference: cleanRef,
      references: contiguousRefs,
      bibleRepository: widget.bibleRepository,
      bibleController: widget.bibleController,
      onNavigateToTab: widget.onNavigateToTab,
      contextTitle: title,
    );
  }

  Widget _buildFormattedParagraph(String text, double fontSize, ThemeData theme) {
    final themeService = ThemeService();
    final List<InlineSpan> spans = [];
    final pattern = RegExp(r'(\[([^\]]+)\]\(([^)]+)\)|\*\*[^*]+\*\*|\*[^*]+\*)');
    int lastMatchEnd = 0;

    final bibleLinkStyle = TextStyle(
      shadows: [
        Shadow(
          color: theme.colorScheme.primary,
          offset: const Offset(0, -2.5),
        ),
      ],
      color: Colors.transparent,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.55),
      decorationThickness: 1.5,
    );

    void addPlainTextSpans(String rawSegment) {
      final parts = BibleExtractor.splitTextByBibleRefs(rawSegment);
      for (final p in parts) {
        if (p.reference != null) {
          spans.add(
            TextSpan(
              text: p.text,
              style: bibleLinkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  _showVersePopup(p.reference!);
                },
            ),
          );
        } else {
          spans.add(TextSpan(text: p.text));
        }
      }
    }

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        addPlainTextSpans(text.substring(lastMatchEnd, match.start));
      }

      final fullMatch = match.group(0)!;
      final linkText = match.group(2);
      final linkUrl = match.group(3);

      if (linkText != null && linkUrl != null) {
        final cleanUrl = Uri.decodeComponent(linkUrl.replaceFirst('bible://', '').trim());
        spans.add(
          TextSpan(
            text: linkText,
            style: bibleLinkStyle,
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
      addPlainTextSpans(text.substring(lastMatchEnd));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: themeService.fontFamily,
          fontSize: fontSize,
          height: 1.6,
          color: theme.colorScheme.onSurface,
        ),
        children: spans,
      ),
      textAlign: themeService.bibleTextAlign,
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

class _LessonQuestionCard extends StatefulWidget {
  final String dayId;
  final String questionText;
  final double fontSize;
  final void Function(String reference)? onTapVerse;

  const _LessonQuestionCard({
    required this.dayId,
    required this.questionText,
    required this.fontSize,
    this.onTapVerse,
  });

  @override
  State<_LessonQuestionCard> createState() => _LessonQuestionCardState();
}

class _LessonQuestionCardState extends State<_LessonQuestionCard> {
  final TextEditingController _controller = TextEditingController();
  final SabbathSchoolService _service = SabbathSchoolService();

  @override
  void initState() {
    super.initState();
    _service.getQuestionAnswer(widget.dayId, widget.questionText).then((ans) {
      if (mounted) {
        _controller.text = ans;
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LessonQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dayId != widget.dayId || oldWidget.questionText != widget.questionText) {
      _service.getQuestionAnswer(widget.dayId, widget.questionText).then((ans) {
        if (mounted) {
          _controller.text = ans;
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildQuestionRichText(ThemeData theme) {
    final themeService = ThemeService();
    final List<InlineSpan> spans = [];
    final text = widget.questionText;
    final pattern = RegExp(r'(\[([^\]]+)\]\(([^)]+)\)|\*\*[^*]+\*\*|\*[^*]+\*)');
    int lastMatchEnd = 0;

    final bibleLinkStyle = TextStyle(
      shadows: [
        Shadow(
          color: theme.colorScheme.primary,
          offset: const Offset(0, -2.5),
        ),
      ],
      color: Colors.transparent,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary.withValues(alpha: 0.55),
      decorationThickness: 1.5,
    );

    void addPlainTextSpans(String rawSegment) {
      final parts = BibleExtractor.splitTextByBibleRefs(rawSegment);
      for (final p in parts) {
        if (p.reference != null) {
          spans.add(
            TextSpan(
              text: p.text,
              style: bibleLinkStyle,
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  widget.onTapVerse?.call(p.reference!);
                },
            ),
          );
        } else {
          spans.add(TextSpan(text: p.text));
        }
      }
    }

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        addPlainTextSpans(text.substring(lastMatchEnd, match.start));
      }

      final fullMatch = match.group(0)!;
      final linkText = match.group(2);
      final linkUrl = match.group(3);

      if (linkText != null && linkUrl != null) {
        final cleanUrl = Uri.decodeComponent(linkUrl.replaceFirst('bible://', '').trim());
        spans.add(
          TextSpan(
            text: linkText,
            style: bibleLinkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                widget.onTapVerse?.call(cleanUrl.isNotEmpty ? cleanUrl : linkText);
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
      addPlainTextSpans(text.substring(lastMatchEnd));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontFamily: themeService.fontFamily,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
        children: spans,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.help_outline_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuestionRichText(theme),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Digite aqui sua resposta ou reflexão...',
              hintStyle: TextStyle(
                fontSize: widget.fontSize - 2,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
            ),
            style: TextStyle(fontSize: widget.fontSize - 1),
            onChanged: (val) {
              _service.saveQuestionAnswer(widget.dayId, widget.questionText, val);
            },
          ),
        ],
      ),
    );
  }
}
