import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import '../../core/utils/in_app_link_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/notification_service.dart';
import '../../services/solar_service.dart';
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

        final isWin95 = themeService.isWin95;
        final isHolo = themeService.isHoloRetro;
        final isAscii = themeService.isAscii;

        final Widget headerWidget;
        if (isWin95) {
          headerWidget = Win95WindowTitleBar(
            title: 'Painel de Controle - Kairós 95',
            leading: const Win95PixelIcon(
              type: Win95PixelIconType.controlPanel,
              size: 18,
            ),
            onWindowClose: () => Navigator.of(context).pop(),
          );
        } else if (isAscii) {
          headerWidget = AsciiWindowTitleBar(
            title: 'PAINEL DE CONFIGURACOES',
            onWindowClose: () => Navigator.of(context).pop(),
          );
        } else if (isHolo) {
          headerWidget = DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14181E) : const Color(0xFFEAEAEA),
              border: const Border(
                bottom: BorderSide(color: Color(0xFF33B5E5), width: 2.0),
              ),
            ),
            child: CustomPaint(
              painter: HoloCarbonPinstripePainter(isDark: isDark),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    const HoloSettingsIcon(size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Settings • Configurações',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fechar',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_sharp, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          headerWidget = Padding(
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
          );
        }

        Widget dialogContent = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: mediaQuery.size.width >= 760 ? 700.0 : 560.0,
            maxHeight: maxDialogHeight,
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headerWidget,
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  dividerColor: isHolo
                      ? const Color(0xFF33B5E5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.35),
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
              ],
            ),
          ),
        );

        if (isWin95) {
          dialogContent = Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF606060) : Colors.white,
                  width: 2,
                ),
                left: BorderSide(
                  color: isDark ? const Color(0xFF606060) : Colors.white,
                  width: 2,
                ),
                right: BorderSide(
                  color: isDark ? const Color(0xFF121212) : const Color(0xFF808080),
                  width: 2,
                ),
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF121212) : const Color(0xFF808080),
                  width: 2,
                ),
              ),
            ),
            child: dialogContent,
          );
        }

        Widget dialog = Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          backgroundColor: themeService.isAnyGlass
              ? (isDark ? const Color(0xD91A1D24) : const Color(0xF0FFFFFF))
              : (isHolo
                  ? (isDark ? const Color(0xFF0E141C) : const Color(0xFFF3F3F3))
                  : colorScheme.surface),
          surfaceTintColor: (themeService.isAnyGlass || isHolo || isWin95 || isAscii)
              ? Colors.transparent
              : colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: (isWin95 || isHolo || isAscii)
                ? BorderRadius.zero
                : BorderRadius.circular(24),
            side: themeService.isAnyGlass
                ? BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.65),
                  )
                : isHolo
                    ? const BorderSide(color: Color(0xFF33B5E5), width: 1.5)
                    : isAscii
                        ? BorderSide(color: colorScheme.primary, width: 1.5)
                        : isWin95
                            ? BorderSide.none
                            : BorderSide(
                                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                              ),
          ),
          clipBehavior: Clip.antiAlias,
          child: dialogContent,
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
    final ts = ThemeService();

    if (ts.isHoloRetro) {
      final dividerColor = theme.brightness == Brightness.dark
          ? const Color(0xFF233040)
          : const Color(0xFFD0D7DE);
      final spacedChildren = <Widget>[];
      for (int i = 0; i < children.length; i++) {
        spacedChildren.add(children[i]);
        if (i < children.length - 1 && children[i] is _RetroSwitchTile) {
          spacedChildren.add(Divider(height: 1, thickness: 1, color: dividerColor));
        }
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HoloSectionHeader(title: title),
            const SizedBox(height: 10),
            ...spacedChildren,
          ],
        ),
      );
    }

    if (ts.isWin95) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Win95BevelBox(
          padding: const EdgeInsets.all(12),
          color: colorScheme.surface,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 17, color: colorScheme.onSurface),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '[ $title ]',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        ),
      );
    }

    if (ts.isAscii) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AsciiBoxSurface(
          label: title,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );
    }

    final isRealGlass = ts.isRealGlass;

    final content = Padding(
      padding: const EdgeInsets.all(14),
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

    if (isRealGlass) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassContainer.card(
          surfaceStyle: GlassSurfaceStyle.solid,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
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
    super.key,
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

class _RetroSwitchTile extends StatelessWidget {
  final ThemeService themeService;
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _RetroSwitchTile({
    required this.themeService,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (themeService.isRealGlass) {
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, size: 20),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: GlassSwitch(
          useOwnLayer: false,
          value: value,
          onChanged: onChanged,
          semanticLabel: title,
        ),
        onTap: onChanged != null ? () => onChanged!(!value) : null,
      );
    }

    if (themeService.isHoloRetro) {
      return Opacity(
        opacity: onChanged == null ? 0.5 : 1.0,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 20, color: const Color(0xFF33B5E5)),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: HoloSwitch(
            value: value,
            onChanged: onChanged ?? (_) {},
            semanticLabel: title,
          ),
          onTap: onChanged != null ? () => onChanged!(!value) : null,
        ),
      );
    }

    if (themeService.isWin95) {
      return Opacity(
        opacity: onChanged == null ? 0.5 : 1.0,
        child: Win95CheckboxTile(
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: onChanged ?? (_) {},
        ),
      );
    }

    if (themeService.isAscii) {
      return Opacity(
        opacity: onChanged == null ? 0.5 : 1.0,
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: subtitle != null ? Text(subtitle!) : null,
          trailing: AsciiSwitch(
            value: value,
            onChanged: onChanged ?? (_) {},
          ),
          onTap: onChanged != null ? () => onChanged!(!value) : null,
        ),
      );
    }

    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, size: 20),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  final ThemeService themeService;

  const _AppearanceTab({required this.themeService});

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return _RetroSwitchTile(
      themeService: themeService,
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    );
  }

  String _lockedAccentMessage() {
    if (themeService.isZen) {
      return 'O modo Zen utiliza uma paleta neutra fixa para foco total na leitura.';
    }
    if (themeService.isClassicBook) {
      return 'O tema Livro Sépia trava a paleta em tons editoriais quentes para preservar a atmosfera de leitura clássica.';
    }
    if (themeService.isHoloRetro) {
      return 'O tema Retrô Android 4.0 (Holo) utiliza exclusivamente o azul elétrico #33B5E5 fiel ao Ice Cream Sandwich.';
    }
    if (themeService.isAscii) {
      return 'Esta variante ASCII utiliza paleta fixa de fósforo/formulário. Selecione "Cor Dinâmica" acima para liberar as cores personalizadas.';
    }
    return 'O tema Clássico Windows 95 mantém suas cores originais (#008080 e #000080) travadas por fidelidade retrô.';
  }

  static const List<_ThemeCardSpec> _themeSpecs = [
    _ThemeCardSpec(
      style: AppThemeStyle.materialYou,
      label: 'Material You',
      bgPreview: Color(0xFFEDF2F7),
      accentPreview: Color(0xFF10B981),
      badge: 'M3',
      square: false,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.appleGlass,
      label: 'Apple Glass',
      bgPreview: Color(0xFF0F172A),
      accentPreview: Color(0xFF38BDF8),
      badge: 'GL',
      square: false,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.realGlass,
      label: 'Real Glass (Apple)',
      bgPreview: Color(0xFF1E293B),
      accentPreview: Color(0xFF7DD3FC),
      badge: 'i27',
      square: false,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.classicBook,
      label: 'Livro Sépia',
      bgPreview: Color(0xFFF5ECD7),
      accentPreview: Color(0xFF8B5A2B),
      badge: 'Aa',
      square: false,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.zen,
      label: 'Zen',
      bgPreview: Color(0xFFF4F4F5),
      accentPreview: Color(0xFF3F3F46),
      badge: '00',
      square: false,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.holoRetro,
      label: 'Retrô Android 4.0 (Holo)',
      bgPreview: Color(0xFF0B1118),
      accentPreview: Color(0xFF33B5E5),
      badge: '4.0',
      square: true,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.win95,
      label: 'Clássico Windows 95',
      bgPreview: Color(0xFF008080),
      accentPreview: Color(0xFF000080),
      badge: '95',
      square: true,
    ),
    _ThemeCardSpec(
      style: AppThemeStyle.ascii,
      label: 'ASCII Vintage',
      bgPreview: Color(0xFF060B06),
      accentPreview: Color(0xFF39FF6E),
      badge: '>_',
      square: true,
    ),
  ];

  Widget _buildLightingCard(BuildContext context, ThemeData theme) {
    return _SettingsGroupCard(
      title: 'Iluminação & Presença',
      icon: Icons.brightness_6_outlined,
      children: [
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
        if (themeService.supportsAmoled) ...[
          const SizedBox(height: 6),
          _buildToggleRow(
            icon: Icons.contrast_rounded,
            title: 'Modo AMOLED (Preto Puro)',
            subtitle: 'Fundo preto absoluto #000000 no escuro',
            value: themeService.isAmoled,
            onChanged: themeService.setAmoled,
          ),
        ],
        const SizedBox(height: 6),
        _buildToggleRow(
          icon: Icons.layers_outlined,
          title: 'Maior presença do tema',
          subtitle: 'Estende o tema a cabeçalhos, citações e buscas',
          value: themeService.richThemeSurfaces,
          onChanged: (v) => themeService.setRichThemeSurfaces(v),
        ),
      ],
    );
  }

  Widget _buildAccentColorsCard(BuildContext context, ThemeData theme) {
    return _SettingsGroupCard(
      title: 'Cores de Destaque',
      icon: Icons.color_lens_outlined,
      children: [
        if (themeService.locksAccentColor)
          Text(
            _lockedAccentMessage(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 10,
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
                            color: entry.value.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
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
                    width: 36,
                    height: 36,
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
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 540;
          final cols = isWide ? 4 : 2;
          const gap = 8.0;
          final tileWidth = ((constraints.maxWidth - 32 - gap * (cols - 1)) / cols)
              .clamp(88.0, 260.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsGroupCard(
                title: 'Tema & Personalidade Visual',
                icon: Icons.auto_awesome_outlined,
                children: [
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: _themeSpecs.map((spec) {
                      final isSelected = themeService.themeStyle == spec.style;
                      return _ThemePreviewTile(
                        width: tileWidth,
                        spec: spec,
                        isSelected: isSelected,
                        onTap: () => themeService.setThemeStyle(spec.style),
                      );
                    }).toList(),
                  ),
                  if (themeService.isAscii) ...[
                    const Divider(height: 20),
                    const _SettingLabel(
                      label: 'Fósforo & Papel ASCII',
                      helper: 'Alterne entre monitor CRT verde, âmbar, formulário contínuo ou sua cor ativa.',
                    ),
                    _OptionChipGroup<AsciiThemeVariant>(
                      selectedValue: themeService.asciiVariant,
                      options: const [
                        _ChipOption(
                          value: AsciiThemeVariant.greenPhosphor,
                          label: 'Fósforo Verde',
                          icon: Icons.terminal_rounded,
                        ),
                        _ChipOption(
                          value: AsciiThemeVariant.amberCrt,
                          label: 'CRT Âmbar',
                          icon: Icons.monitor_outlined,
                        ),
                        _ChipOption(
                          value: AsciiThemeVariant.matrixPaper,
                          label: 'Formulário',
                          icon: Icons.receipt_long_outlined,
                        ),
                        _ChipOption(
                          value: AsciiThemeVariant.dynamicColor,
                          label: 'Cor Dinâmica',
                          icon: Icons.palette_outlined,
                        ),
                      ],
                      onSelected: (v) => themeService.setAsciiVariant(v),
                    ),
                  ],
                  if (themeService.isAppleGlass) ...[
                    const Divider(height: 20),
                    const _SettingLabel(
                      label: 'Variante Apple Glass',
                      helper: 'Alterne entre o brilho harmônico clássico e o visual Liquid Ciano.',
                    ),
                    _OptionChipGroup<AppleGlassVariant>(
                      selectedValue: themeService.appleGlassVariant,
                      options: const [
                        _ChipOption(
                          value: AppleGlassVariant.harmonic,
                          label: 'Harmônico (Apple)',
                          icon: Icons.auto_awesome_outlined,
                        ),
                        _ChipOption(
                          value: AppleGlassVariant.liquid,
                          label: 'Ciano Diagonal (Liquid)',
                          icon: Icons.water_drop_outlined,
                        ),
                      ],
                      onSelected: (v) => themeService.setAppleGlassVariant(v),
                    ),
                    const SizedBox(height: 8),
                    _buildToggleRow(
                      icon: Icons.auto_awesome_motion_outlined,
                      title: 'Animação dos Orbes (Aurora)',
                      subtitle: 'Movimento contínuo dos orbes de fundo',
                      value: themeService.glassAnimationEnabled,
                      onChanged: (v) => themeService.setGlassAnimationEnabled(v),
                    ),
                    _buildToggleRow(
                      icon: Icons.touch_app_outlined,
                      title: 'Orbes Interativos (Toque/Mouse)',
                      subtitle: 'Reação dos orbes ao movimento do mouse ou toque',
                      value: themeService.glassInteractiveEnabled,
                      onChanged: (v) => themeService.setGlassInteractiveEnabled(v),
                    ),
                    _buildToggleRow(
                      icon: Icons.blur_on_rounded,
                      title: 'Blur em Tempo Real',
                      subtitle: 'Desfoque real nos cards (pesado em celulares simples)',
                      value: themeService.glassBlurEnabled,
                      onChanged: themeService.setGlassBlurEnabled,
                    ),
                  ],
                  if (themeService.isClassicBook) ...[
                    const Divider(height: 20),
                    const _SettingLabel(
                      label: 'Papel & Tipografia Editorial',
                      helper: 'Escolha entre o tom sépia quente ou o marfim editorial do Pergaminho.',
                    ),
                    _OptionChipGroup<SepiaBookVariant>(
                      selectedValue: themeService.sepiaBookVariant,
                      options: const [
                        _ChipOption(
                          value: SepiaBookVariant.classicSepia,
                          label: 'Sépia Clássico (Quente)',
                          icon: Icons.menu_book_outlined,
                        ),
                        _ChipOption(
                          value: SepiaBookVariant.editorialParchment,
                          label: 'Pergaminho Editorial (Marfim)',
                          icon: Icons.auto_stories_outlined,
                        ),
                      ],
                      onSelected: (v) => themeService.setSepiaBookVariant(v),
                    ),
                  ],
                  if (themeService.isRealGlass) ...[
                    const Divider(height: 20),
                    const _SettingLabel(
                      label: 'Motor Óptico Apple',
                      helper: 'Alterna entre a refração paraxial do iOS 27 e a borda direcional do iOS 26.',
                    ),
                    GlassSegmentedControl(
                      useOwnLayer: false,
                      segments: const [
                        GlassSegment(label: 'iOS 27'),
                        GlassSegment(label: 'iOS 26'),
                      ],
                      selectedIndex: themeService.realGlassEra == RealGlassEra.ios27 ? 0 : 1,
                      onSegmentSelected: (index) => themeService.setRealGlassEra(
                        index == 0 ? RealGlassEra.ios27 : RealGlassEra.ios26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const _SettingLabel(
                      label: 'Papel de Parede (Refração)',
                      helper: 'Fundo estático de alto contraste para destacar o vidro líquido.',
                    ),
                    _OptionChipGroup<RealGlassWallpaper>(
                      selectedValue: themeService.realGlassWallpaper,
                      options: const [
                        _ChipOption(
                          value: RealGlassWallpaper.ios27Bloom,
                          label: 'iOS 27 Bloom',
                          icon: Icons.flare_rounded,
                        ),
                        _ChipOption(
                          value: RealGlassWallpaper.cupertinoOcean,
                          label: 'Cupertino Ocean',
                          icon: Icons.waves_rounded,
                        ),
                        _ChipOption(
                          value: RealGlassWallpaper.sequoiaSunset,
                          label: 'Sequoia Sunset',
                          icon: Icons.wb_sunny_outlined,
                        ),
                        _ChipOption(
                          value: RealGlassWallpaper.dynamicMesh,
                          label: 'Malha Dinâmica',
                          icon: Icons.gradient_rounded,
                        ),
                      ],
                      onSelected: (w) => themeService.setRealGlassWallpaper(w),
                    ),
                  ],
                ],
              ),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLightingCard(context, theme)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildAccentColorsCard(context, theme)),
                  ],
                )
              else ...[
                _buildLightingCard(context, theme),
                _buildAccentColorsCard(context, theme),
              ],
              _SettingsGroupCard(
                title: 'Tela Inicial & Navegação',
                icon: Icons.space_dashboard_outlined,
                children: [
                  _buildToggleRow(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Modo Simplificado (Foco em Idosos)',
                    subtitle: 'Exibe apenas Bíblia, Hinário, Lição e Devocional com botões grandes e letras ampliadas',
                    value: themeService.simplifiedHomeMode,
                    onChanged: (v) => themeService.setSimplifiedHomeMode(v),
                  ),
                  const SizedBox(height: 6),
                  _buildToggleRow(
                    icon: Icons.dock_rounded,
                    title: 'Barra de Navegação Flutuante',
                    subtitle: 'Exibe a barra inferior como cápsula flutuante em todos os temas',
                    value: themeService.floatingNavBar,
                    onChanged: themeService.setFloatingNavBar,
                  ),
                  const SizedBox(height: 6),
                  _buildToggleRow(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Devocional Diário na Tela Inicial',
                    subtitle: 'Exibe a mensagem do devocional e versículo do dia na tela inicial',
                    value: themeService.showHomeDevotionalBanner,
                    onChanged: themeService.setShowHomeDevotionalBanner,
                  ),
                  if (themeService.showHomeDevotionalBanner) ...[
                    const SizedBox(height: 12),
                    const _SettingLabel(
                      label: 'Estilo do Versículo do Dia',
                      helper: 'Use o modo compacto sem imagem ou permita que o tema escolha automaticamente.',
                    ),
                    _OptionChipGroup<DailyVerseCardStyle>(
                      selectedValue: themeService.dailyVerseCardStyle,
                      options: const [
                        _ChipOption(
                          value: DailyVerseCardStyle.auto,
                          label: 'Automático pelo Tema',
                          icon: Icons.auto_awesome_outlined,
                        ),
                        _ChipOption(
                          value: DailyVerseCardStyle.slimTextOnly,
                          label: 'Compacto (Só Texto)',
                          icon: Icons.short_text_rounded,
                        ),
                        _ChipOption(
                          value: DailyVerseCardStyle.backgroundImage,
                          label: 'Com Imagem',
                          icon: Icons.image_outlined,
                        ),
                      ],
                      onSelected: themeService.setDailyVerseCardStyle,
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _SettingLabel(
                    label: 'Barra de Progresso do Vídeo',
                    helper: 'Escolha se a barra de progresso do Kairós fica fixa abaixo do vídeo ou flutuante com auto-ocultar.',
                  ),
                  _OptionChipGroup<VideoProgressBarMode>(
                    selectedValue: themeService.videoProgressBarMode,
                    options: const [
                      _ChipOption(
                        value: VideoProgressBarMode.fixedBelow,
                        label: 'Fixa abaixo',
                        icon: Icons.view_agenda_outlined,
                      ),
                      _ChipOption(
                        value: VideoProgressBarMode.floatingAutoHide,
                        label: 'Flutuante (auto-ocultar)',
                        icon: Icons.layers_outlined,
                      ),
                    ],
                    onSelected: themeService.setVideoProgressBarMode,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemeCardSpec {
  final AppThemeStyle style;
  final String label;
  final Color bgPreview;
  final Color accentPreview;
  final String badge;
  final bool square;

  const _ThemeCardSpec({
    required this.style,
    required this.label,
    required this.bgPreview,
    required this.accentPreview,
    required this.badge,
    required this.square,
  });
}

class _ThemePreviewTile extends StatelessWidget {
  final double width;
  final _ThemeCardSpec spec;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreviewTile({
    required this.width,
    required this.spec,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = spec.square ? BorderRadius.zero : BorderRadius.circular(14);
    final isDarkPreview = spec.bgPreview.computeLuminance() < 0.35;

    return SizedBox(
      width: width,
      child: Material(
        color: isSelected
            ? cs.primaryContainer.withValues(alpha: 0.65)
            : cs.surfaceContainerHighest.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: isSelected
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: spec.bgPreview,
                    borderRadius: spec.square
                        ? BorderRadius.zero
                        : BorderRadius.circular(9),
                    border: Border.all(
                      color: spec.accentPreview.withValues(alpha: 0.75),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            spec.badge,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: spec.style == AppThemeStyle.ascii
                                  ? 'RetroPixel'
                                  : (spec.style == AppThemeStyle.win95
                                      ? 'PixelMono'
                                      : null),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDarkPreview
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: spec.accentPreview,
                          shape: spec.square
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        spec.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? cs.onPrimaryContainer
                                  : cs.onSurface,
                            ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                  _ChipOption(value: 'DroidSans', label: 'Droid Sans (Holo)'),
                  _ChipOption(value: 'RetroPixel', label: 'Pixel SNES (ASCII)'),
                  _ChipOption(value: 'PixelMono', label: 'Pixel Mono (Win95)'),
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
              if (themeService.isRealGlass)
                GlassSlider(
                  useOwnLayer: false,
                  value: themeService.fontSizeMultiplier,
                  min: 0.8,
                  max: 1.6,
                  divisions: 8,
                  label: '${(themeService.fontSizeMultiplier * 100).round()}%',
                  onChanged: themeService.setFontSizeMultiplier,
                )
              else
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
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.tablet_mac_outlined,
                title: 'Auto-ampliar em Tablets (>600px)',
                value: themeService.autoTabletScaling,
                onChanged: themeService.setAutoTabletScaling,
              ),
              const SizedBox(height: 10),
              const _SettingLabel(label: 'Posição da Barra em Tablets'),
              _OptionChipGroup<String>(
                selectedValue: themeService.tabletNavPosition,
                options: const [
                  _ChipOption(
                    value: 'left',
                    label: 'Esquerda',
                    icon: Icons.align_horizontal_left_rounded,
                  ),
                  _ChipOption(
                    value: 'right',
                    label: 'Direita (Destro)',
                    icon: Icons.align_horizontal_right_rounded,
                  ),
                ],
                onSelected: themeService.setTabletNavPosition,
              ),
              const SizedBox(height: 10),
              const _SettingLabel(label: 'Comportamento da Barra em Tablets'),
              _OptionChipGroup<String>(
                selectedValue: themeService.tabletNavMode,
                options: const [
                  _ChipOption(
                    value: 'fixed',
                    label: 'Fixa',
                    icon: Icons.view_sidebar_outlined,
                  ),
                  _ChipOption(
                    value: 'collapsible',
                    label: 'Retrátil (Gestos)',
                    icon: Icons.swipe_outlined,
                  ),
                ],
                onSelected: themeService.setTabletNavMode,
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
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.view_headline_rounded,
                title: 'Modo Texto Corrido',
                subtitle: 'Exibe a leitura em parágrafos contínuos',
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
          _SettingsGroupCard(
            title: 'Espírito de Profecia',
            icon: Icons.auto_stories_outlined,
            children: [
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.menu_book_rounded,
                title: 'Capa Nova (CPB) no Espírito de Profecia',
                subtitle:
                    'Alterna entre capas modernas ilustradas e o estilo clássico',
                value: themeService.egwUseModernCovers,
                onChanged: themeService.setEgwUseModernCovers,
              ),
            ],
          ),
          _SettingsGroupCard(
            title: 'Gestos de Navegação e Leitura',
            icon: Icons.touch_app_outlined,
            children: [
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.gesture_rounded,
                title: 'Ativar Gestos Inteligentes',
                subtitle:
                    'Desative para restaurar rolagem 100% tradicional sem gestos extras',
                value: themeService.gesturesEnabled,
                onChanged: themeService.setGesturesEnabled,
              ),
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.swipe_rounded,
                title: 'Deslizar para trocar capítulos/dias',
                value: themeService.gestureSwipeChapters,
                onChanged: themeService.gesturesEnabled
                    ? themeService.setGestureSwipeChapters
                    : null,
              ),
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.pinch_rounded,
                title: 'Pinça com 2 dedos para zoom de fonte',
                value: themeService.gesturePinchFont,
                onChanged: themeService.gesturesEnabled
                    ? themeService.setGesturePinchFont
                    : null,
              ),
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.highlight_alt_rounded,
                title: 'Duplo-toque rápido para destaque',
                value: themeService.gestureDoubleTapHighlight,
                onChanged: themeService.gesturesEnabled
                    ? themeService.setGestureDoubleTapHighlight
                    : null,
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
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.calendar_view_week_rounded,
                title: 'Expandir dias da lição por padrão',
                subtitle:
                    'Exibe os dias da semana na Escola Sabatina automaticamente',
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
              _RetroSwitchTile(
                themeService: themeService,
                icon: Icons.emoji_events_outlined,
                title: 'Alertas de Conquistas e Avatar',
                subtitle:
                    'Exibe avisos ao desbloquear insígnias, roupas ou acessórios',
                value: themeService.achievementNotificationsEnabled,
                onChanged: (enabled) async {
                  await themeService.setAchievementNotificationsEnabled(enabled);
                  if (enabled) {
                    await NotificationService().requestPermission();
                  }
                },
              ),
              _SunsetReminderControls(themeService: themeService),
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
              const SizedBox(height: 8),
              _SingleLineActionButton(
                key: const Key('settings_github_repo_btn'),
                icon: Icons.code_rounded,
                label: 'Repositório no GitHub',
                onPressed: () => InAppLinkLauncher.openUrl(
                  'https://github.com/Lucas2Araujo/Kairos',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SunsetReminderControls extends StatefulWidget {
  final ThemeService themeService;

  const _SunsetReminderControls({required this.themeService});

  @override
  State<_SunsetReminderControls> createState() =>
      _SunsetReminderControlsState();
}

class _SunsetReminderControlsState extends State<_SunsetReminderControls> {
  SolarCity _selectedCity = SolarService.defaultCity;

  @override
  void initState() {
    super.initState();
    _loadCity();
  }

  Future<void> _loadCity() async {
    final city = await SolarService.getSavedCity();
    if (!mounted) return;
    setState(() => _selectedCity = city);
  }

  Future<void> _pickCity() async {
    final picked = await showDialog<SolarCity>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Localização do Pôr do Sol'),
          content: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: SolarService.predefinedCities.length,
                itemBuilder: (_, index) {
                  final city = SolarService.predefinedCities[index];
                  final isSelected = city.name == _selectedCity.name &&
                      city.state == _selectedCity.state;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isSelected
                          ? Theme.of(dialogCtx).colorScheme.primary
                          : null,
                    ),
                    title: Text(city.displayName),
                    onTap: () => Navigator.of(dialogCtx).pop(city),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        );
      },
    );

    if (picked == null) return;
    await SolarService.saveCity(picked);
    if (!mounted) return;
    setState(() => _selectedCity = picked);

    if (widget.themeService.sunsetReminderEnabled) {
      final sunset = await NotificationService()
          .scheduleFridaySunsetReminderForCity(city: picked);
      if (mounted) {
        final formatted = SolarService.formatTime(sunset);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notificação de Feliz Sábado atualizada para $formatted (${picked.displayName}).',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fridaySunset = SolarService.getFridaySunset(city: _selectedCity);
    final formattedSunset = SolarService.formatTime(fridaySunset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RetroSwitchTile(
          themeService: widget.themeService,
          icon: Icons.wb_twilight_rounded,
          title: 'Notificação de Feliz Sábado',
          subtitle:
              'Na sexta-feira às $formattedSunset (${_selectedCity.displayName})',
          value: widget.themeService.sunsetReminderEnabled,
          onChanged: (enabled) async {
            await widget.themeService.setSunsetReminderEnabled(enabled);
            if (enabled) {
              await NotificationService().requestPermission();
              await NotificationService()
                  .scheduleFridaySunsetReminderForCity(city: _selectedCity);
            } else {
              NotificationService().cancelReminder('rem_sunset');
            }
          },
        ),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.location_on_outlined, size: 20),
          title: const Text('Cidade do Pôr do Sol'),
          subtitle: Text('${_selectedCity.displayName} • Sexta às $formattedSunset'),
          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: _pickCity,
        ),
      ],
    );
  }
}
