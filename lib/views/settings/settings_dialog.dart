import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/notification_service.dart';
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

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final mediaQuery = MediaQuery.of(context);
        final maxDialogHeight =
            (mediaQuery.size.height - mediaQuery.viewPadding.vertical - 32)
                .clamp(280.0, 720.0);

        Widget dialog = Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          backgroundColor: themeService.isAnyGlass
              ? (isDark ? const Color(0xD91A1D24) : const Color(0xF0FFFFFF))
              : colorScheme.surface,
          surfaceTintColor:
              themeService.isAnyGlass ? Colors.transparent : colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: themeService.isAnyGlass
                ? BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.65),
                  )
                : BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: maxDialogHeight,
            ),
            child: DefaultTabController(
              length: 4,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            size: 20,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Configurações',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fechar',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    tabs: const [
                      Tab(
                        key: Key('settings_tab_aparencia'),
                        child: _SingleLineTabLabel(
                          icon: Icons.palette_outlined,
                          label: 'Aparência',
                        ),
                      ),
                      Tab(
                        key: Key('settings_tab_leitura'),
                        child: _SingleLineTabLabel(
                          icon: Icons.menu_book_outlined,
                          label: 'Leitura',
                        ),
                      ),
                      Tab(
                        key: Key('settings_tab_conteudo'),
                        child: _SingleLineTabLabel(
                          icon: Icons.auto_stories_outlined,
                          label: 'Conteúdo',
                        ),
                      ),
                      Tab(
                        key: Key('settings_tab_sistema'),
                        child: _SingleLineTabLabel(
                          icon: Icons.tune_rounded,
                          label: 'Sistema',
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: TabBarView(
                      children: [
                        _AppearanceTab(themeService: themeService),
                        _ReadingTab(themeService: themeService),
                        _ContentTab(themeService: themeService),
                        _SystemTab(themeService: themeService),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Fechar',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _SingleLineTabLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SingleLineTabLabel({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 6),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SettingsGroupCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsGroupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  final String label;
  final String? helper;

  const _SettingLabel({
    required this.label,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const _ChipOption({
    required this.value,
    required this.label,
    this.icon,
  });
}

class _OptionChipGroup<T> extends StatelessWidget {
  final T selectedValue;
  final List<_ChipOption<T>> options;
  final ValueChanged<T> onSelected;

  const _OptionChipGroup({
    required this.selectedValue,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt.value == selectedValue;
        return ChoiceChip(
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          avatar: opt.icon != null
              ? Icon(
                  opt.icon,
                  size: 16,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                )
              : null,
          label: Text(
            opt.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
          selected: isSelected,
          onSelected: (_) => onSelected(opt.value),
        );
      }).toList(),
    );
  }
}

class _SingleLineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SingleLineActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  final ThemeService themeService;

  const _AppearanceTab({required this.themeService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsGroupCard(
            title: 'Estilo & Iluminação',
            icon: Icons.auto_awesome_outlined,
            children: [
              const _SettingLabel(label: 'Estilo Visual'),
              _OptionChipGroup<AppThemeStyle>(
                selectedValue: themeService.themeStyle,
                options: const [
                  _ChipOption(
                    value: AppThemeStyle.materialYou,
                    label: 'Material You',
                    icon: Icons.palette_outlined,
                  ),
                  _ChipOption(
                    value: AppThemeStyle.liquidGlass,
                    label: 'Liquid Glass',
                    icon: Icons.water_drop_outlined,
                  ),
                  _ChipOption(
                    value: AppThemeStyle.appleGlass,
                    label: 'Apple Glass',
                    icon: Icons.blur_on_rounded,
                  ),
                  _ChipOption(
                    value: AppThemeStyle.classicBook,
                    label: 'Livro Sépia',
                    icon: Icons.menu_book_outlined,
                  ),
                ],
                onSelected: (style) => themeService.setThemeStyle(style),
              ),
              const SizedBox(height: 14),
              const _SettingLabel(label: 'Modo de Iluminação'),
              _OptionChipGroup<ThemeMode>(
                selectedValue: themeService.themeMode,
                options: const [
                  _ChipOption(
                    value: ThemeMode.system,
                    label: 'Automático',
                    icon: Icons.brightness_auto_rounded,
                  ),
                  _ChipOption(
                    value: ThemeMode.light,
                    label: 'Claro',
                    icon: Icons.light_mode_outlined,
                  ),
                  _ChipOption(
                    value: ThemeMode.dark,
                    label: 'Escuro',
                    icon: Icons.dark_mode_outlined,
                  ),
                ],
                onSelected: (mode) => themeService.setThemeMode(mode),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.contrast_rounded, size: 20),
                title: const Text('Modo AMOLED (Preto Puro)'),
                subtitle: const Text('Fundo preto absoluto #000000 no modo escuro'),
                value: themeService.isAmoled,
                onChanged: themeService.setAmoled,
              ),
              if (themeService.isAnyGlass) ...[
                const Divider(height: 16),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.blur_on, size: 20),
                  title: const Text('Refração e Blur em Tempo Real'),
                  subtitle: const Text(
                    'Desative para economizar bateria em aparelhos antigos',
                  ),
                  value: themeService.glassBlurEnabled,
                  onChanged: themeService.setGlassBlurEnabled,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.auto_awesome_motion_outlined, size: 20),
                  title: const Text('Animação dos Orbes (Aurora)'),
                  subtitle: const Text('Movimento contínuo dos orbes de fundo'),
                  value: themeService.glassAnimationEnabled,
                  onChanged: (v) => themeService.setGlassAnimationEnabled(v),
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.touch_app_outlined, size: 20),
                  title: const Text('Orbes Interativos (Toque/Mouse)'),
                  subtitle: const Text(
                    'Reação dos orbes ao movimento do mouse ou toque',
                  ),
                  value: themeService.glassInteractiveEnabled,
                  onChanged: (v) => themeService.setGlassInteractiveEnabled(v),
                ),
              ],
            ],
          ),
          _SettingsGroupCard(
            title: 'Cores de Destaque',
            icon: Icons.color_lens_outlined,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ...ThemeService.colorSeeds.entries.map((entry) {
                    final isSelected = themeService.colorKey == entry.key;
                    final colorName =
                        ThemeService.colorSeedNames[entry.key] ?? entry.key;
                    return Tooltip(
                      message: colorName,
                      child: InkWell(
                        onTap: () => themeService.setColorSeed(entry.key),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 38,
                          height: 38,
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
                  Tooltip(
                    message: 'Personalizado...',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        ChromaticColorPickerDialog.show(
                          context,
                          initialColor: themeService.currentColor,
                          onColorSelected: (color) =>
                              themeService.setCustomColor(color),
                        );
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: themeService.colorKey == 'custom'
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: Colors.grey.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                          gradient: const SweepGradient(
                            colors: [
                              Colors.red,
                              Colors.yellow,
                              Colors.green,
                              Colors.cyan,
                              Colors.blue,
                              Color(0xFFFF00FF),
                              Colors.red,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.colorize_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingTab extends StatelessWidget {
  final ThemeService themeService;

  const _ReadingTab({required this.themeService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedUiScale = const [0.9, 1.0, 1.15, 1.3].firstWhere(
      (v) => (v - themeService.uiScaleMultiplier).abs() < 0.01,
      orElse: () => 1.0,
    );
    final selectedScrollMs =
        const [250, 500, 800, 1200].contains(themeService.bibleScrollDurationMs)
            ? themeService.bibleScrollDurationMs
            : 500;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsGroupCard(
            title: 'Tipografia & Escala',
            icon: Icons.text_fields_rounded,
            children: [
              const _SettingLabel(label: 'Fonte de Leitura'),
              _OptionChipGroup<String>(
                selectedValue: themeService.fontFamily,
                options: const [
                  _ChipOption(value: 'AppSans', label: 'AppSans'),
                  _ChipOption(value: 'HymnSerif', label: 'Clássica'),
                  _ChipOption(value: 'Montserrat', label: 'Montserrat'),
                  _ChipOption(value: 'OpenDyslexic', label: 'OpenDyslexic'),
                ],
                onSelected: themeService.setFontFamily,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tamanho da Fonte',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${(themeService.fontSizeMultiplier * 100).round()}%',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: themeService.fontSizeMultiplier,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                onChanged: themeService.setFontSizeMultiplier,
              ),
              const _SettingLabel(label: 'Escala da Interface'),
              _OptionChipGroup<double>(
                selectedValue: selectedUiScale,
                options: const [
                  _ChipOption(value: 0.9, label: '90%'),
                  _ChipOption(value: 1.0, label: '100%'),
                  _ChipOption(value: 1.15, label: '115%'),
                  _ChipOption(value: 1.3, label: '130%'),
                ],
                onSelected: themeService.setUiScaleMultiplier,
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.tablet_mac_outlined, size: 20),
                title: const Text('Auto-ampliar em Tablets (>600px)'),
                value: themeService.autoTabletScaling,
                onChanged: themeService.setAutoTabletScaling,
              ),
            ],
          ),
          _SettingsGroupCard(
            title: 'Leitura Bíblica & Offline',
            icon: Icons.chrome_reader_mode_outlined,
            children: [
              const _SettingLabel(label: 'Alinhamento do Texto'),
              _OptionChipGroup<TextAlign>(
                selectedValue: themeService.bibleTextAlign,
                options: const [
                  _ChipOption(
                    value: TextAlign.left,
                    label: 'Esquerda',
                    icon: Icons.format_align_left,
                  ),
                  _ChipOption(
                    value: TextAlign.center,
                    label: 'Centro',
                    icon: Icons.format_align_center,
                  ),
                  _ChipOption(
                    value: TextAlign.justify,
                    label: 'Justificado',
                    icon: Icons.format_align_justify,
                  ),
                ],
                onSelected: themeService.setBibleTextAlign,
              ),
              const SizedBox(height: 14),
              const _SettingLabel(label: 'Velocidade do Scroll na Bíblia'),
              _OptionChipGroup<int>(
                selectedValue: selectedScrollMs,
                options: const [
                  _ChipOption(value: 250, label: '250ms', icon: Icons.flash_on_outlined),
                  _ChipOption(value: 500, label: '500ms', icon: Icons.play_arrow_outlined),
                  _ChipOption(
                    value: 800,
                    label: '800ms',
                    icon: Icons.motion_photos_on_outlined,
                  ),
                  _ChipOption(
                    value: 1200,
                    label: '1.2s',
                    icon: Icons.slow_motion_video_outlined,
                  ),
                ],
                onSelected: themeService.setBibleScrollDurationMs,
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.view_headline_rounded, size: 20),
                title: const Text('Modo Texto Corrido'),
                subtitle: const Text('Exibe a leitura em parágrafos contínuos'),
                value: themeService.isContinuousReading,
                onChanged: themeService.setContinuousReading,
              ),
              const SizedBox(height: 8),
              _SingleLineActionButton(
                icon: Icons.cloud_download_outlined,
                label: 'Gerenciar Traduções e Downloads',
                onPressed: () => DownloadsDialog.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentTab extends StatelessWidget {
  final ThemeService themeService;

  const _ContentTab({required this.themeService});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsGroupCard(
            title: 'Comunhão & Metas',
            icon: Icons.local_fire_department_outlined,
            children: [
              const _SettingLabel(
                label: 'Meta Diária de Tempo com Deus',
                helper: 'Tempo diário em oração, Bíblia, hinário ou estudo:',
              ),
              ListenableBuilder(
                listenable: GamificationService(),
                builder: (context, _) {
                  final gamification = GamificationService();
                  return _OptionChipGroup<int>(
                    selectedValue: gamification.dailyGoalMinutes,
                    options: const [
                      _ChipOption(value: 5, label: '5 min', icon: Icons.schedule_rounded),
                      _ChipOption(value: 10, label: '10 min', icon: Icons.schedule_rounded),
                      _ChipOption(value: 15, label: '15 min', icon: Icons.schedule_rounded),
                      _ChipOption(value: 30, label: '30 min', icon: Icons.schedule_rounded),
                    ],
                    onSelected: gamification.setDailyGoalMinutes,
                  );
                },
              ),
            ],
          ),
          _SettingsGroupCard(
            title: 'Preferências de Estudo',
            icon: Icons.bookmarks_outlined,
            children: [
              const _SettingLabel(
                label: 'Devocional Padrão',
                helper: 'Selecionado automaticamente na Tela Inicial e em Meditações:',
              ),
              _OptionChipGroup<String>(
                selectedValue: themeService.defaultDevotionalCategory,
                options: const [
                  _ChipOption(
                    value: 'diario',
                    label: 'Adultos',
                    icon: Icons.wb_sunny_outlined,
                  ),
                  _ChipOption(
                    value: 'jovem',
                    label: 'Jovens',
                    icon: Icons.bolt_outlined,
                  ),
                  _ChipOption(
                    value: 'mulher',
                    label: 'Mulher',
                    icon: Icons.spa_outlined,
                  ),
                ],
                onSelected: (cat) {
                  themeService.setDefaultDevotionalCategory(cat);
                  AuthService().syncPreferencesToCloud(devotionalCategory: cat);
                },
              ),
              const SizedBox(height: 14),
              const _SettingLabel(label: 'Lição Padrão da Escola Sabatina'),
              _OptionChipGroup<String>(
                selectedValue: themeService.defaultSabbathSchoolCategory,
                options: const [
                  _ChipOption(
                    value: 'adultos',
                    label: 'Adultos',
                    icon: Icons.school_outlined,
                  ),
                  _ChipOption(
                    value: 'jovens',
                    label: 'Jovens',
                    icon: Icons.groups_outlined,
                  ),
                ],
                onSelected: (cat) {
                  themeService.setDefaultSabbathSchoolCategory(cat);
                  AuthService().syncPreferencesToCloud(sabbathSchoolCategory: cat);
                },
              ),
              const SizedBox(height: 14),
              const _SettingLabel(label: 'Pesquisa na Tela Inicial'),
              _OptionChipGroup<HomeSearchPlacement>(
                selectedValue: themeService.homeSearchPlacement,
                options: const [
                  _ChipOption(
                    value: HomeSearchPlacement.capsuleBody,
                    label: 'No corpo',
                    icon: Icons.search_rounded,
                  ),
                  _ChipOption(
                    value: HomeSearchPlacement.topBarIcon,
                    label: 'No topo',
                    icon: Icons.saved_search_rounded,
                  ),
                  _ChipOption(
                    value: HomeSearchPlacement.none,
                    label: 'Ocultar',
                    icon: Icons.search_off_rounded,
                  ),
                ],
                onSelected: themeService.setHomeSearchPlacement,
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.calendar_view_week_rounded, size: 20),
                title: const Text('Expandir dias da lição por padrão'),
                subtitle: const Text(
                  'Exibe os dias da semana na Escola Sabatina automaticamente',
                ),
                value: themeService.sabbathSchoolExpandDaysByDefault,
                onChanged: themeService.setSabbathSchoolExpandDaysByDefault,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemTab extends StatelessWidget {
  final ThemeService themeService;

  const _SystemTab({required this.themeService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SettingsGroupCard(
            title: 'Notificações & Lembretes',
            icon: Icons.notifications_active_outlined,
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.emoji_events_outlined, size: 20),
                title: const Text('Alertas de Conquistas e Avatar'),
                subtitle: const Text(
                  'Exibe avisos ao desbloquear insígnias, roupas ou acessórios',
                ),
                value: themeService.achievementNotificationsEnabled,
                onChanged: (enabled) async {
                  await themeService.setAchievementNotificationsEnabled(enabled);
                  if (enabled) {
                    await NotificationService().requestPermission();
                  }
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.wb_twilight_rounded, size: 20),
                title: const Text('Lembrete do Pôr do Sol (Sexta)'),
                subtitle: const Text(
                  'Aviso de preparação para o Sábado na sexta-feira à tarde',
                ),
                value: themeService.sunsetReminderEnabled,
                onChanged: (enabled) async {
                  await themeService.setSunsetReminderEnabled(enabled);
                  if (enabled) {
                    await NotificationService().requestPermission();
                    NotificationService().scheduleFridaySunsetReminder();
                  } else {
                    NotificationService().cancelReminder('rem_sunset');
                  }
                },
              ),
            ],
          ),
          _SettingsGroupCard(
            title: 'Inicialização & Sobre o Kairós',
            icon: Icons.info_outline_rounded,
            children: [
              const _SettingLabel(label: 'Duração da Abertura'),
              _OptionChipGroup<String>(
                selectedValue: themeService.splashSpeedMode,
                options: const [
                  _ChipOption(
                    value: 'rapido',
                    label: '1.5s',
                    icon: Icons.bolt_outlined,
                  ),
                  _ChipOption(
                    value: 'normal',
                    label: '2.8s',
                    icon: Icons.timer_outlined,
                  ),
                  _ChipOption(
                    value: 'estendido',
                    label: '4.0s',
                    icon: Icons.hourglass_bottom_outlined,
                  ),
                ],
                onSelected: themeService.setSplashSpeedMode,
              ),
              const SizedBox(height: 10),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('Apresentação do App (Boas-Vindas)'),
                subtitle: const Text('Rever o guia de recursos e introdução'),
                onTap: () => WelcomeDialog.show(context, force: true),
              ),
              const Divider(height: 16),
              FutureBuilder<String>(
                future: UpdaterService().getInstalledVersion(),
                initialData: UpdaterService.defaultCurrentVersion,
                builder: (context, snapshot) {
                  final ver = snapshot.data ?? UpdaterService.defaultCurrentVersion;
                  return Text(
                    'Kairós • Versão $ver',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                'Bíblia Sagrada, Hinário Adventista, Meditações e Escola Sabatina.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _SingleLineActionButton(
                icon: Icons.system_update_outlined,
                label: 'Verificar Atualizações (OTA)',
                onPressed: () => UpdateDialog.show(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
