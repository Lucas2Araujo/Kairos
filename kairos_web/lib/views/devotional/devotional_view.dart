import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../models/devotional.dart';
import '../../services/theme_service.dart';

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

  void _openBibleRef(String refText) {
    if (widget.bibleController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abrindo versículo: $refText')),
      );
      return;
    }

    final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?').firstMatch(refText.trim());
    if (match != null) {
      final bookName = match.group(1) ?? '';
      final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
      final verse = int.tryParse(match.group(3) ?? '1') ?? 1;
      widget.bibleController!.jumpToVerse(bookName, chapter, verse);
      widget.onNavigateToTab?.call(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navegado para $refText no Leitor Bíblico')),
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
                    onPressed: () => _openBibleRef(devo.verseReference),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Texto da Meditação
        SelectableText(
          devo.content.trim(),
          style: theme.textTheme.bodyLarge?.copyWith(
            fontSize: 17 * multiplier,
            height: 1.8,
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
