import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../core/utils/bible_extractor.dart';
import '../../core/utils/system_share_download.dart';
import '../../models/devotional.dart';
import '../../services/spiritual_focus_tracker.dart';
import '../../services/theme_service.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';
import 'pordosol_view.dart';

class DevotionalView extends StatefulWidget {
  final DevotionalController controller;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const DevotionalView({
    super.key,
    required this.controller,
    this.bibleController,
    this.onNavigateToTab,
  });

  @override
  State<DevotionalView> createState() => _DevotionalViewState();
}

class _DevotionalViewState extends State<DevotionalView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.controller.selectedCategory == 'pordosol') {
        widget.controller.selectCategory(ThemeService().defaultDevotionalCategory);
      } else if (widget.controller.currentDevotional == null) {
        widget.controller.init();
      }
    });
  }

  void _openBibleRef(String refText, [List<String>? contextRefs]) {
    final cleanRef = BibleExtractor.cleanReference(refText);
    final refs = contextRefs ??
        BibleExtractor.getContiguousReferences(
          widget.controller.currentDevotional?.content ?? '',
          cleanRef,
        );

    BibleVersePreviewModal.show(
      context,
      reference: cleanRef,
      references: refs,
      bibleController: widget.bibleController,
      onNavigateToTab: widget.onNavigateToTab,
      contextTitle: 'Meditação',
    );
  }

  String _formatDevotionalShareText(Devotional devo, {bool includeHeader = true}) {
    final buffer = StringBuffer();
    buffer.writeln(includeHeader ? '📖 ${devo.title}' : devo.title);
    if (devo.verseText.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('“${devo.verseText.trim()}”');
      if (devo.verseReference.isNotEmpty) {
        buffer.writeln('— ${devo.verseReference}');
      }
    }
    buffer.writeln();
    buffer.writeln(devo.content.trim());
    if (devo.author.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('— ${devo.author}');
    }
    buffer.writeln();
    buffer.writeln('(Compartilhado via Kairós)');
    return buffer.toString();
  }

  void _copyDevotional(Devotional devo) {
    Clipboard.setData(
      ClipboardData(text: _formatDevotionalShareText(devo, includeHeader: false)),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meditação copiada para a área de transferência! 📋'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareDevotional(Devotional devo) async {
    final text = _formatDevotionalShareText(devo);
    final shared = await SystemShareDownload.shareText(
      text: text,
      subject: devo.title,
    );
    if (!shared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meditação copiada para compartilhamento!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _openDaysModal(BuildContext context, DevotionalController ctrl) {
    final theme = Theme.of(context);
    final days = ctrl.recentDays;
    final catName = _categoryLabel(ctrl.selectedCategory);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escolher Dia • $catName',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final d = days[index];
                      final isSelected = d.year == ctrl.selectedDate.year &&
                          d.month == ctrl.selectedDate.month &&
                          d.day == ctrl.selectedDate.day;
                      final isToday = d.year == DateTime.now().year &&
                          d.month == DateTime.now().month &&
                          d.day == DateTime.now().day;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            ctrl.selectDate(d);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : (isToday
                                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                        : theme.dividerColor.withValues(alpha: 0.1)),
                                width: isToday && !isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _weekdayAbbr(d.weekday),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? theme.colorScheme.onPrimary : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${d.day}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? theme.colorScheme.onPrimary : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openExternalUrl(String url) {
    if (url.trim().isEmpty) return;
    try {
      final uri = Uri.tryParse(url.trim());
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Erro ao abrir link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller, themeService]),
      builder: (context, _) {
        final ctrl = widget.controller;
        final isGlass = themeService.isAnyGlass;
        final badgeName = _categoryLabel(ctrl.selectedCategory);

        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.volunteer_activism_outlined, size: 22),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Meditação',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: const Key('devotional_category_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeName,
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
                tooltip: 'Escolher Dia',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: () => _openDaysModal(context, ctrl),
              ),
              PopupMenuButton<String>(
                key: const Key('devotional_overflow_menu'),
                tooltip: 'Trocar Meditação',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  if (value == 'pordosol') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PorDoSolView(devotionalController: ctrl),
                      ),
                    );
                  } else {
                    ctrl.selectCategory(value);
                  }
                },
                itemBuilder: (ctx) => [
                  _buildCategoryMenuItem(
                    ctx,
                    value: 'jovem',
                    label: 'Meditação Jovens',
                    icon: Icons.bolt_rounded,
                    isSelected: ctrl.selectedCategory == 'jovem',
                  ),
                  _buildCategoryMenuItem(
                    ctx,
                    value: 'diario',
                    label: 'Meditação Adultos',
                    icon: Icons.wb_sunny_outlined,
                    isSelected: ctrl.selectedCategory == 'diario',
                  ),
                  _buildCategoryMenuItem(
                    ctx,
                    value: 'mulher',
                    label: 'Meditação da Mulher',
                    icon: Icons.spa_outlined,
                    isSelected: ctrl.selectedCategory == 'mulher',
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'pordosol',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepOrange.withValues(alpha: 0.16),
                            Colors.amber.withValues(alpha: 0.12),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wb_twilight_rounded, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Meditação do Pôr do Sol',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SpiritualFocusTracker(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ActionChip(
                          avatar: const Icon(Icons.calendar_month_outlined, size: 16),
                          label: Text(
                            '${_weekdayFullName(ctrl.selectedDate.weekday)}, ${ctrl.selectedDate.day}/${ctrl.selectedDate.month}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _openDaysModal(context, ctrl),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (ctrl.isLoading)
                        const Center(
                          key: ValueKey('loading'),
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (ctrl.errorMessage != null)
                        Center(
                          key: const ValueKey('error'),
                          child: Text(
                            ctrl.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        )
                      else if (ctrl.currentDevotional != null)
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.03),
                                end: Offset.zero,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(
                              '${ctrl.currentDevotional!.publishedAt}_${ctrl.currentDevotional!.category}_${ctrl.currentDevotional!.title}',
                            ),
                            child: _buildDevotionalCard(
                              ctrl.currentDevotional!,
                              theme,
                              themeService,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildCategoryMenuItem(
    BuildContext context, {
    required String value,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? scheme.primary : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: scheme.primary),
        ],
      ),
    );
  }

  Widget _buildDevotionalCard(Devotional devo, ThemeData theme, ThemeService themeService) {
    final multiplier = themeService.fontSizeMultiplier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          devo.title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22 * multiplier,
          ),
        ),
        if (devo.author.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            devo.author,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 20),

        Card(
          elevation: 0,
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  '“${devo.verseText.replaceAll(RegExp(r"""^[“"«'\s]+|[”"»'\s]+$"""), '').trim()}”',
                  textAlign: themeService.bibleTextAlign,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: themeService.fontFamily,
                    fontStyle: FontStyle.italic,
                    fontSize: 16 * multiplier,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: ActionChip(
                    avatar: const Icon(Icons.menu_book, size: 14),
                    label: Text(
                      devo.verseReference,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () => _openBibleRef(devo.verseReference),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SelectableText.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: themeService.fontFamily,
              fontSize: 17 * multiplier,
              height: 1.8,
            ),
            children: BibleExtractor.splitTextByBibleRefs(devo.content.trim()).map((part) {
              if (part.reference != null) {
                return TextSpan(
                  text: part.text,
                  style: TextStyle(
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
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      _openBibleRef(part.reference!);
                    },
                );
              }
              return TextSpan(text: part.text);
            }).toList(),
          ),
          textAlign: themeService.bibleTextAlign,
        ),
        const SizedBox(height: 28),

        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Compartilhar'),
              onPressed: () => _shareDevotional(devo),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Copiar Meditação'),
              onPressed: () => _copyDevotional(devo),
            ),
            if (devo.effectiveVideoUrl.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.smart_display_rounded, size: 18),
                label: const Text('Assistir Vídeo'),
                onPressed: () => _openExternalUrl(devo.effectiveVideoUrl),
              ),
            if (devo.effectiveSourceUrl.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Ver na CPB'),
                onPressed: () => _openExternalUrl(devo.effectiveSourceUrl),
              ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  String _categoryLabel(String catKey) {
    switch (catKey) {
      case 'jovem':
        return 'Jovens';
      case 'mulher':
        return 'Mulher';
      case 'diario':
      default:
        return 'Adultos';
    }
  }

  String _weekdayFullName(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Segunda-feira';
      case DateTime.tuesday:
        return 'Terça-feira';
      case DateTime.wednesday:
        return 'Quarta-feira';
      case DateTime.thursday:
        return 'Quinta-feira';
      case DateTime.friday:
        return 'Sexta-feira';
      case DateTime.saturday:
        return 'Sábado';
      case DateTime.sunday:
        return 'Domingo';
      default:
        return '';
    }
  }

  String _weekdayAbbr(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Seg';
      case DateTime.tuesday:
        return 'Ter';
      case DateTime.wednesday:
        return 'Qua';
      case DateTime.thursday:
        return 'Qui';
      case DateTime.friday:
        return 'Sex';
      case DateTime.saturday:
        return 'Sáb';
      case DateTime.sunday:
        return 'Dom';
      default:
        return '';
    }
  }
}
