import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../services/updater_service.dart';
import '../downloads/downloads_dialog.dart';
import '../onboarding/welcome_dialog.dart';
import 'update_dialog.dart';
import 'widgets/chromatic_color_picker_dialog.dart';
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final isDark = theme.brightness == Brightness.dark;

        Widget dialog = AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: themeService.isAnyGlass
              ? (isDark ? const Color(0xCC1E1E1E) : const Color(0xEBFFFFFF))
              : null,
          shape: themeService.isAnyGlass
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 1,
                  ),
                )
              : null,
          title: const Row(
            children: [
              Icon(Icons.settings),
              SizedBox(width: 8),
              Text('Configurações'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Aparência',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // 1. Estilo Visual
                  const Text(
                    'Estilo Visual',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<AppThemeStyle>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<AppThemeStyle>(
                        value: AppThemeStyle.materialYou,
                        icon: Icon(Icons.palette_outlined, size: 16),
                        label: Text('M3'),
                      ),
                      ButtonSegment<AppThemeStyle>(
                        value: AppThemeStyle.liquidGlass,
                        icon: Icon(Icons.water_drop_outlined, size: 16),
                        label: Text('Liquid'),
                      ),
                      ButtonSegment<AppThemeStyle>(
                        value: AppThemeStyle.appleGlass,
                        icon: Icon(Icons.blur_on_rounded, size: 16),
                        label: Text('Glass'),
                      ),
                      ButtonSegment<AppThemeStyle>(
                        value: AppThemeStyle.classicBook,
                        icon: Icon(Icons.menu_book_outlined, size: 16),
                        label: Text('Sépia'),
                      ),
                    ],
                    selected: {themeService.themeStyle},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        themeService.setThemeStyle(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. Modo de Iluminação
                  const Text(
                    'Modo de Iluminação',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18),
                        label: Text('Auto'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Claro'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Escuro'),
                      ),
                    ],
                    selected: {themeService.themeMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        themeService.setThemeMode(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 6),

                  // 3. Modo AMOLED (Preto Puro)
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.contrast, size: 20),
                    title: const Text('Modo AMOLED (Preto Puro)', style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'Fundo preto absoluto #000000 no modo escuro',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: themeService.isAmoled,
                    onChanged: (v) => themeService.setAmoled(v),
                  ),

                  // 4. Efeitos Visuais Glass (Blur, Aurora, Interativo)
                  if (themeService.isAnyGlass) ...[
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.blur_on, size: 20),
                      title: const Text('Refração e Blur em Tempo Real', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Desative para economizar bateria em aparelhos antigos', style: TextStyle(fontSize: 12)),
                      value: themeService.glassBlurEnabled,
                      onChanged: (v) => themeService.setGlassBlurEnabled(v),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.auto_awesome_motion_outlined, size: 20),
                      title: const Text('Animação dos Orbes (Aurora)', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Movimento contínuo dos orbes de fundo', style: TextStyle(fontSize: 12)),
                      value: themeService.glassAnimationEnabled,
                      onChanged: (v) => themeService.setGlassAnimationEnabled(v),
                    ),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      secondary: const Icon(Icons.touch_app_outlined, size: 20),
                      title: const Text('Orbes Interativos (Toque/Mouse)', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Reação dos orbes ao movimento do mouse ou toque', style: TextStyle(fontSize: 12)),
                      value: themeService.glassInteractiveEnabled,
                      onChanged: (v) => themeService.setGlassInteractiveEnabled(v),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Tipografia & Acessibilidade
                  Row(
                    children: [
                      const Icon(Icons.font_download_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Fonte de Leitura',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      DropdownButton<String>(
                        value: themeService.fontFamily,
                        dropdownColor: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(8),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'AppSans',
                            child: Text('AppSans (Padrão)'),
                          ),
                          DropdownMenuItem(
                            value: 'HymnSerif',
                            child: Text('HymnSerif (Clássica)'),
                          ),
                          DropdownMenuItem(
                            value: 'Montserrat',
                            child: Text('Montserrat'),
                          ),
                          DropdownMenuItem(
                            value: 'OpenDyslexic',
                            child: Text('OpenDyslexic'),
                          ),
                        ],
                        onChanged: (font) {
                          if (font != null) themeService.setFontFamily(font);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Zoom / Escala do Texto
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.format_size, size: 20),
                              SizedBox(width: 8),
                              Text('Tamanho da Fonte', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Text(
                            '${(themeService.fontSizeMultiplier * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                      Slider(
                        value: themeService.fontSizeMultiplier,
                        min: 0.8,
                        max: 1.6,
                        divisions: 8,
                        label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                        onChanged: (val) => themeService.setFontSizeMultiplier(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Escala da Interface (UI / Tablets)
                  const Text(
                    'Escala da Interface (UI / Tablets)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<double>(
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<double>(
                        value: 0.9,
                        label: Text('90%'),
                      ),
                      ButtonSegment<double>(
                        value: 1.0,
                        label: Text('100%'),
                      ),
                      ButtonSegment<double>(
                        value: 1.15,
                        label: Text('115%'),
                      ),
                      ButtonSegment<double>(
                        value: 1.3,
                        label: Text('130%'),
                      ),
                    ],
                    selected: {
                      [0.9, 1.0, 1.15, 1.3].firstWhere(
                        (v) => (v - themeService.uiScaleMultiplier).abs() < 0.01,
                        orElse: () => 1.0,
                      )
                    },
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        themeService.setUiScaleMultiplier(selection.first);
                      }
                    },
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.tablet_mac_outlined, size: 20),
                    title: const Text('Auto-ampliar em Tablets (>600px)', style: TextStyle(fontSize: 14)),
                    value: themeService.autoTabletScaling,
                    onChanged: (val) => themeService.setAutoTabletScaling(val),
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Leitura da Bíblia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Alinhamento do Texto Bíblico
                  Row(
                    children: [
                      const Icon(Icons.format_align_left, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Alinhamento',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      SegmentedButton<TextAlign>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: TextAlign.left, icon: Icon(Icons.format_align_left, size: 18), tooltip: 'Esquerda'),
                          ButtonSegment(value: TextAlign.center, icon: Icon(Icons.format_align_center, size: 18), tooltip: 'Centralizado'),
                          ButtonSegment(value: TextAlign.justify, icon: Icon(Icons.format_align_justify, size: 18), tooltip: 'Justificado'),
                        ],
                        selected: {themeService.bibleTextAlign},
                        onSelectionChanged: (selection) {
                          if (selection.isNotEmpty) {
                            themeService.setBibleTextAlign(selection.first);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Modo de Texto Corrido vs Versículo a Versículo
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.view_headline, size: 20),
                    title: const Text('Modo Texto Corrido', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Exibe a leitura em parágrafos contínuos', style: TextStyle(fontSize: 12)),
                    value: themeService.isContinuousReading,
                    onChanged: (val) => themeService.setContinuousReading(val),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => DownloadsDialog.show(context),
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text('Gerenciar Traduções e Downloads'),
                    ),
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Cores de Destaque',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Paleta de cores com o Seletor Cromático Customizado
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...ThemeService.colorSeeds.entries.map((entry) {
                        final isSelected = themeService.colorKey == entry.key;
                        final colorName = ThemeService.colorSeedNames[entry.key] ?? entry.key;
                        return Tooltip(
                          message: colorName,
                          child: InkWell(
                            onTap: () => themeService.setColorSeed(entry.key),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: entry.value.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 20, color: Colors.white)
                                  : null,
                            ),
                          ),
                        );
                      }),

                      // Botão do Círculo Cromático (usando Color(0xFFFF00FF) no lugar de magenta)
                      Tooltip(
                        message: 'Personalizado...',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            ChromaticColorPickerDialog.show(
                              context,
                              initialColor: themeService.currentColor,
                              onColorSelected: (color) => themeService.setCustomColor(color),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: themeService.colorKey == 'custom'
                                  ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                                  : Border.all(color: Colors.grey.withValues(alpha: 0.4), width: 1.5),
                              gradient: const SweepGradient(
                                colors: [
                                  Colors.red,
                                  Colors.yellow,
                                  Colors.green,
                                  Colors.cyan,
                                  Colors.blue,
                                  Color(0xFFFF00FF), // Magenta corrigido
                                  Colors.red,
                                ],
                              ),
                            ),
                            child: const Icon(Icons.colorize_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Sobre o Kairós',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<String>(
                    future: UpdaterService().getInstalledVersion(),
                    initialData: UpdaterService.defaultCurrentVersion,
                    builder: (context, snapshot) {
                      final ver = snapshot.data ?? UpdaterService.defaultCurrentVersion;
                      return Text('Versão $ver');
                    },
                  ),
                  const Text('Bíblia Sagrada, Hinário Adventista e Lições da Escola Sabatina.'),
                  const SizedBox(height: 10),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline),
                    title: const Text(
                      'Apresentação do App (Boas-Vindas)',
                      style: TextStyle(fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Rever o guia de recursos e introdução',
                      style: TextStyle(fontSize: 12),
                    ),
                    onTap: () => WelcomeDialog.show(context, force: true),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => UpdateDialog.show(context),
                      icon: const Icon(Icons.system_update_outlined, size: 18),
                      label: const Text('Verificar Atualizações (OTA)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );

        if (themeService.isAnyGlass && themeService.glassBlurEnabled) {
          final blur = themeService.isAppleGlass ? 24.0 : 16.0;
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: dialog,
          );
        }
        return dialog;
      },
    );
  }
}
