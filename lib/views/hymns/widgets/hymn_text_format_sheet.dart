import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/theme_service.dart';

class HymnTextFormatSheet extends StatelessWidget {
  const HymnTextFormatSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const HymnTextFormatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final currentMultiplier = themeService.fontSizeMultiplier;
        final currentAlign = themeService.hymnTextAlign;
        final currentFont = themeService.fontFamily;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_format, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Ajustes de Texto',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        themeService.setFontSizeMultiplier(1.0);
                        themeService.setHymnTextAlign(TextAlign.center);
                        themeService.setFontFamily(AppConstants.fontHymnSerif);
                      },
                      child: const Text('Padrão'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tamanho da Fonte
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tamanho da Fonte',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    Text(
                      '${(currentMultiplier * 100).round()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'Diminuir fonte',
                      onPressed: currentMultiplier > 0.8
                          ? () => themeService.setFontSizeMultiplier(currentMultiplier - 0.1)
                          : null,
                    ),
                    Expanded(
                      child: Slider(
                        value: currentMultiplier,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: '${(currentMultiplier * 100).round()}%',
                        onChanged: (val) => themeService.setFontSizeMultiplier(val),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Aumentar fonte',
                      onPressed: currentMultiplier < 1.6
                          ? () => themeService.setFontSizeMultiplier(currentMultiplier + 0.1)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Alinhamento do Texto
                const Text(
                  'Alinhamento',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SegmentedButton<TextAlign>(
                  segments: const [
                    ButtonSegment<TextAlign>(
                      value: TextAlign.left,
                      icon: Icon(Icons.format_align_left, size: 18),
                      label: Text('Esquerda'),
                    ),
                    ButtonSegment<TextAlign>(
                      value: TextAlign.center,
                      icon: Icon(Icons.format_align_center, size: 18),
                      label: Text('Centro'),
                    ),
                    ButtonSegment<TextAlign>(
                      value: TextAlign.justify,
                      icon: Icon(Icons.format_align_justify, size: 18),
                      label: Text('Justificado'),
                    ),
                  ],
                  selected: {currentAlign},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      themeService.setHymnTextAlign(set.first);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Família da Fonte
                const Text(
                  'Família Tipográfica',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFontChip(
                      context,
                      label: 'Serif (Hinos)',
                      fontFamily: AppConstants.fontHymnSerif,
                      isSelected: currentFont == AppConstants.fontHymnSerif,
                    ),
                    _buildFontChip(
                      context,
                      label: 'Sans (Padrão)',
                      fontFamily: AppConstants.fontAppSans,
                      isSelected: currentFont == AppConstants.fontAppSans,
                    ),
                    _buildFontChip(
                      context,
                      label: 'Montserrat',
                      fontFamily: AppConstants.fontMontserrat,
                      isSelected: currentFont == AppConstants.fontMontserrat,
                    ),
                    _buildFontChip(
                      context,
                      label: 'OpenDyslexic',
                      fontFamily: AppConstants.fontOpenDyslexic,
                      isSelected: currentFont == AppConstants.fontOpenDyslexic,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontChip(
    BuildContext context, {
    required String label,
    required String fontFamily,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ThemeService().setFontFamily(fontFamily);
        }
      },
    );
  }
}
