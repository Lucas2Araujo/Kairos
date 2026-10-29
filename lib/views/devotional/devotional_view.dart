import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../core/utils/bible_extractor.dart';
import '../../models/devotional.dart';
import '../../services/spiritual_focus_tracker.dart';
import '../../services/theme_service.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';

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
      if (mounted && widget.controller.currentDevotional == null) {
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

  void _copyDevotional(Devotional devo) {
    final buffer = StringBuffer();
    buffer.writeln(devo.title);
    buffer.writeln();
    if (devo.verseText.isNotEmpty) {
      buffer.writeln('"${devo.verseText}"');
      if (devo.verseReference.isNotEmpty) {
        buffer.writeln('— ${devo.verseReference}');
      }
      buffer.writeln();
    }
    buffer.writeln(devo.content.trim());
    if (devo.author.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('— ${devo.author}');
    }
    if (devo.sourceUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Fonte: ${devo.sourceUrl}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meditação copiada para a área de transferência! 📋'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareDevotional(Devotional devo) {
    final buffer = StringBuffer();
    buffer.writeln('📖 ${devo.title}');
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

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meditação copiada para compartilhamento!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
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

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Meditação Diária',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SpiritualFocusTracker(
            child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Categorias em Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCategoryChip('jovem', 'Jovens', Icons.bolt, ctrl),
                          const SizedBox(width: 8),
                          _buildCategoryChip('diario', 'Adultos', Icons.wb_sunny_outlined, ctrl),
                          const SizedBox(width: 8),
                          _buildCategoryChip('mulher', 'Mulher', Icons.spa_outlined, ctrl),
                          const SizedBox(width: 8),
                          _buildCategoryChip('pordosol', 'Pôr do Sol', Icons.wb_twilight_rounded, ctrl),
                        ],
                      ),
                    ),
                    if (ctrl.selectedCategory != 'pordosol') ...[
                      const SizedBox(height: 10),
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
                    ],
                    const SizedBox(height: 16),

                    // Conteúdo Devocional
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
                          key: ValueKey('${ctrl.currentDevotional!.publishedAt}_${ctrl.currentDevotional!.category}_${ctrl.currentDevotional!.title}'),
                          child: _buildDevotionalCard(ctrl.currentDevotional!, theme, themeService),
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

  Widget _buildCategoryChip(String catKey, String label, IconData icon, DevotionalController ctrl) {
    final isSelected = ctrl.selectedCategory == catKey;
    final theme = Theme.of(context);

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) {
        if (isSelected && catKey != 'pordosol') {
          _openDaysModal(context, ctrl);
        } else {
          ctrl.selectCategory(catKey);
        }
      },
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
      ),
      label: Text(label),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        color: isSelected ? theme.colorScheme.onPrimary : null,
      ),
    );
  }

  Widget _buildDevotionalCard(Devotional devo, ThemeData theme, ThemeService themeService) {
    final multiplier = themeService.fontSizeMultiplier;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Título e Autor
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

        // Card do Versículo-Chave com Link para a Bíblia
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

        // Texto da Meditação com Referências Clicáveis
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

        // Ações no final do texto (Compartilhar, Copiar, Assistir Vídeo, Ver na CPB)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
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
      case 'pordosol':
        return 'Pôr do Sol';
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
