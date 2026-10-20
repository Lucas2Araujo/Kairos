import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../core/utils/bible_extractor.dart';
import '../../models/devotional.dart';
import '../../services/theme_service.dart';
import '../lesson/widgets/verse_dialog.dart';

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
    widget.controller.init();
  }

  void _openBibleRef(String refText, [List<String>? contextRefs]) {
    VerseDialog.show(
      context,
      reference: refText,
      bibleController: widget.bibleController,
      onNavigateToTab: widget.onNavigateToTab,
      contextTitle: 'Meditação',
      contextReferences: contextRefs,
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

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Meditação Diária',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Categorias em Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCategoryChip('jovem', 'Jovens', Icons.bolt),
                        const SizedBox(width: 8),
                        _buildCategoryChip('diario', 'Adultos', Icons.wb_sunny_outlined),
                        const SizedBox(width: 8),
                        _buildCategoryChip('mulher', 'Mulher', Icons.spa_outlined),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Carrossel de 7 Dias
                    _buildDaysCarousel(ctrl),
                    const SizedBox(height: 20),

                    // Conteúdo Devocional
                    if (ctrl.isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (ctrl.errorMessage != null)
                      Center(
                        child: Text(
                          ctrl.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else if (ctrl.currentDevotional != null)
                      _buildDevotionalCard(ctrl.currentDevotional!, theme, themeService),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String catKey, String label, IconData icon) {
    final isSelected = widget.controller.selectedCategory == catKey;
    final theme = Theme.of(context);

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => widget.controller.selectCategory(catKey),
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

  Widget _buildDaysCarousel(DevotionalController ctrl) {
    final days = ctrl.recentDays;
    final theme = Theme.of(context);

    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final d = days[index];
          final isSelected = d.year == ctrl.selectedDate.year &&
              d.month == ctrl.selectedDate.month &&
              d.day == ctrl.selectedDate.day;

          final weekDayName = _weekdayAbbr(d.weekday);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ctrl.selectDate(d),
              child: Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? null
                      : Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekDayName,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${d.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDevotionalCard(Devotional devo, ThemeData theme, ThemeService themeService) {
    final multiplier = themeService.fontSizeMultiplier;
    final allRefs = BibleExtractor.extractAllBibleRefs('${devo.verseReference}\n${devo.content}');

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
                  '“${devo.verseText}”',
                  style: theme.textTheme.bodyLarge?.copyWith(
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
                    onPressed: () => _openBibleRef(devo.verseReference, allRefs),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Ações Rápidas (Copiar, Ver na CPB, Assistir Vídeo)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.content_copy_rounded, size: 18),
              label: const Text('Copiar Meditação'),
              onPressed: () => _copyDevotional(devo),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Ver na CPB'),
              onPressed: () => _openExternalUrl(devo.effectiveSourceUrl),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.smart_display_rounded, size: 18, color: Colors.redAccent),
              label: const Text('Assistir Vídeo'),
              onPressed: () => _openExternalUrl(devo.effectiveVideoUrl),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Texto da Meditação com Referências Clicáveis
        SelectableText.rich(
          TextSpan(
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: 17 * multiplier,
              height: 1.8,
            ),
            children: BibleExtractor.splitTextByBibleRefs(devo.content.trim()).map((part) {
              if (part.reference != null) {
                return TextSpan(
                  text: part.text,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      _openBibleRef(part.reference!, allRefs);
                    },
                );
              }
              return TextSpan(text: part.text);
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
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
