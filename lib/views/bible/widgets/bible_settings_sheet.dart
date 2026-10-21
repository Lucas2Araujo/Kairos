import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../services/content_manager.dart';
import '../../../services/theme_service.dart';
import '../../downloads/downloads_dialog.dart';

class BibleSettingsSheet extends StatelessWidget {
  final BibleController controller;

  const BibleSettingsSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, BibleController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BibleSettingsSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final contentManager = ContentManager();

    return AnimatedBuilder(
      animation: Listenable.merge([controller, themeService, contentManager]),
      builder: (context, _) {
        final installedVersions = contentManager.installedBibleVersions;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Barra de arraste
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Cabeçalho
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Configurações de Leitura',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Fechar',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Conteúdo
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Tradução / Versão Ativa
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_stories_outlined, size: 18, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Versão da Bíblia',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                DownloadsDialog.show(context);
                              },
                              icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                              label: const Text('Gerenciar', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            ...installedVersions.map((ver) {
                              final isSelected = controller.activeVersion == ver;
                              return ChoiceChip(
                                label: Text(
                                  ver,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) controller.selectVersion(ver);
                                },
                              );
                            }),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text('Mais versões'),
                              onPressed: () {
                                DownloadsDialog.show(context);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // 2. Modo de Leitura
                        const Text(
                          'Modo de Leitura',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('Versículos'),
                              icon: Icon(Icons.format_list_numbered, size: 18),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('Texto Contínuo'),
                              icon: Icon(Icons.menu_book, size: 18),
                            ),
                          ],
                          selected: {themeService.isContinuousReading},
                          onSelectionChanged: (set) => themeService.setContinuousReading(set.first),
                        ),
                        const SizedBox(height: 20),

                        // 3. Alinhamento de Texto
                        const Text(
                          'Alinhamento do Texto',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<TextAlign>(
                          segments: const [
                            ButtonSegment(
                              value: TextAlign.left,
                              icon: Icon(Icons.format_align_left, size: 18),
                              label: Text('Esquerda'),
                            ),
                            ButtonSegment(
                              value: TextAlign.center,
                              icon: Icon(Icons.format_align_center, size: 18),
                              label: Text('Centro'),
                            ),
                            ButtonSegment(
                              value: TextAlign.justify,
                              icon: Icon(Icons.format_align_justify, size: 18),
                              label: Text('Justificado'),
                            ),
                          ],
                          selected: {themeService.bibleTextAlign},
                          onSelectionChanged: (set) => themeService.setBibleTextAlign(set.first),
                        ),
                        const SizedBox(height: 20),

                        // 4. Família da Fonte
                        const Text(
                          'Fonte de Leitura',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: themeService.fontFamily,
                              items: const [
                                DropdownMenuItem(
                                  value: 'AppSans',
                                  child: Text('AppSans (Padrão)', style: TextStyle(fontFamily: 'AppSans')),
                                ),
                                DropdownMenuItem(
                                  value: 'HymnSerif',
                                  child: Text('HymnSerif (Clássica)', style: TextStyle(fontFamily: 'HymnSerif')),
                                ),
                                DropdownMenuItem(
                                  value: 'Montserrat',
                                  child: Text('Montserrat (Moderna)', style: TextStyle(fontFamily: 'Montserrat')),
                                ),
                                DropdownMenuItem(
                                  value: 'OpenDyslexic',
                                  child: Text('OpenDyslexic (Acessível)', style: TextStyle(fontFamily: 'OpenDyslexic')),
                                ),
                              ],
                              onChanged: (font) {
                                if (font != null) themeService.setFontFamily(font);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 5. Tamanho da Fonte
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tamanho da Fonte',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '${(themeService.fontSizeMultiplier * 100).round()}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.format_size, size: 18),
                            Expanded(
                              child: Slider(
                                value: themeService.fontSizeMultiplier,
                                min: 0.8,
                                max: 1.6,
                                divisions: 8,
                                label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                                onChanged: (val) => themeService.setFontSizeMultiplier(val),
                              ),
                            ),
                            const Icon(Icons.format_size, size: 26),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
