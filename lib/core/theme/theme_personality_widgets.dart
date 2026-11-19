import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../services/theme_service.dart';

/// Sub-variantes visuais do tema ASCII Vintage.
enum AsciiThemeVariant {
  /// Terminal CRT clássico em fósforo verde (ou matricial esverdeado no modo claro).
  greenPhosphor,

  /// Terminal retrô em fósforo âmbar (ou formulário creme âmbar no modo claro).
  amberCrt,

  /// Formulário contínuo matricial monocromático de alto contraste.
  matrixPaper,

  /// Terminal ASCII adaptativo que herda a cor de destaque escolhida pelo usuário.
  dynamicColor,
}

/// Sub-variantes visuais do tema Apple Glass.
enum AppleGlassVariant {
  /// Orbes análogos harmônicos com superfície translúcida suave.
  harmonic,

  /// Variante herdada do antigo Liquid Glass com orbe ciano e gradiente diagonal.
  liquid,
}

/// Sub-variantes visuais do tema Livro Sépia.
enum SepiaBookVariant {
  /// Sépia clássico quente com contraste editorial tradicional.
  classicSepia,

  /// Pergaminho editorial marfim herdado do tema Pergaminho.
  editorialParchment,
}

/// Geração óptica utilizada pelo tema Real Glass (Apple Liquid Glass).
enum RealGlassEra {
  /// Óptica calibrada do iOS 27 com refração paraxial e frost ponderado por luminância.
  ios27,

  /// Óptica clássica do iOS 26 com borda direcional pronunciada.
  ios26,
}

/// Papéis de parede estáticos de alta refração para o tema Real Glass.
enum RealGlassWallpaper {
  /// Gradiente floral luminoso estilo iOS 27 Bloom.
  ios27Bloom,

  /// Tons profundos oceânicos e ciano estilo Cupertino Ocean.
  cupertinoOcean,

  /// Pôr do sol quente em camadas estilo Sequoia Sunset.
  sequoiaSunset,

  /// Malha dinâmica derivada da cor de destaque ativa.
  dynamicMesh,
}

/// Papel de parede estático de alta refração para destacar as lentes do Real Glass.
class RealGlassWallpaperBackground extends StatelessWidget {
  /// Preset de papel de parede selecionado.
  final RealGlassWallpaper wallpaper;

  /// Indica se o modo escuro está ativo.
  final bool isDark;

  /// Cor de destaque usada no modo de malha dinâmica.
  final Color seedColor;

  /// Cria o fundo estático de alta refração para o tema Real Glass.
  const RealGlassWallpaperBackground({
    super.key,
    required this.wallpaper,
    required this.isDark,
    required this.seedColor,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _resolveColors();

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.baseColors,
            stops: const [0.0, 0.48, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -90,
              left: -70,
              width: 380,
              height: 380,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.orbA.withValues(alpha: isDark ? 0.55 : 0.45),
                      palette.orbA.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 150,
              right: -85,
              width: 360,
              height: 360,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.orbB.withValues(alpha: isDark ? 0.50 : 0.42),
                      palette.orbB.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -110,
              left: 30,
              width: 420,
              height: 420,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.orbC.withValues(alpha: isDark ? 0.42 : 0.35),
                      palette.orbC.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _WallpaperColors _resolveColors() {
    switch (wallpaper) {
      case RealGlassWallpaper.ios27Bloom:
        return isDark
            ? const _WallpaperColors(
                baseColors: [Color(0xFF060B1E), Color(0xFF101D3E), Color(0xFF1E133A)],
                orbA: Color(0xFF38BDF8),
                orbB: Color(0xFFA855F7),
                orbC: Color(0xFF0EA5E9),
              )
            : const _WallpaperColors(
                baseColors: [Color(0xFFE0F2FE), Color(0xFFEDE9FE), Color(0xFFFCE7F3)],
                orbA: Color(0xFF38BDF8),
                orbB: Color(0xFFC084FC),
                orbC: Color(0xFFF472B6),
              );
      case RealGlassWallpaper.cupertinoOcean:
        return isDark
            ? const _WallpaperColors(
                baseColors: [Color(0xFF020B16), Color(0xFF07233B), Color(0xFF0B3954)],
                orbA: Color(0xFF06B6D4),
                orbB: Color(0xFF3B82F6),
                orbC: Color(0xFF14B8A6),
              )
            : const _WallpaperColors(
                baseColors: [Color(0xFFE0F7FA), Color(0xFFD6ECFF), Color(0xFFC7E9FB)],
                orbA: Color(0xFF0EA5E9),
                orbB: Color(0xFF14B8A6),
                orbC: Color(0xFF2563EB),
              );
      case RealGlassWallpaper.sequoiaSunset:
        return isDark
            ? const _WallpaperColors(
                baseColors: [Color(0xFF1A0B18), Color(0xFF2E1426), Color(0xFF191C36)],
                orbA: Color(0xFFF97316),
                orbB: Color(0xFFEC4899),
                orbC: Color(0xFF8B5CF6),
              )
            : const _WallpaperColors(
                baseColors: [Color(0xFFFFEDD5), Color(0xFFFDE2E4), Color(0xFFE8EAFE)],
                orbA: Color(0xFFFB923C),
                orbB: Color(0xFFF43F5E),
                orbC: Color(0xFF8B5CF6),
              );
      case RealGlassWallpaper.dynamicMesh:
        final hsl = HSLColor.fromColor(seedColor);
        final analogA = hsl.withHue((hsl.hue + 40) % 360).toColor();
        final analogB = hsl.withHue((hsl.hue - 45 + 360) % 360).toColor();
        return isDark
            ? _WallpaperColors(
                baseColors: [
                  const Color(0xFF050814),
                  Color.alphaBlend(seedColor.withValues(alpha: 0.24), const Color(0xFF0B1120)),
                  Color.alphaBlend(analogA.withValues(alpha: 0.18), const Color(0xFF0F172A)),
                ],
                orbA: seedColor,
                orbB: analogA,
                orbC: analogB,
              )
            : _WallpaperColors(
                baseColors: [
                  Color.alphaBlend(seedColor.withValues(alpha: 0.14), const Color(0xFFF8FAFC)),
                  Color.alphaBlend(analogA.withValues(alpha: 0.14), const Color(0xFFF1F5F9)),
                  Color.alphaBlend(analogB.withValues(alpha: 0.12), const Color(0xFFE2E8F0)),
                ],
                orbA: seedColor,
                orbB: analogA,
                orbC: analogB,
              );
    }
  }
}

class _WallpaperColors {
  final List<Color> baseColors;
  final Color orbA;
  final Color orbB;
  final Color orbC;

  const _WallpaperColors({
    required this.baseColors,
    required this.orbA,
    required this.orbB,
    required this.orbC,
  });
}

/// Fundo estático de papel editorial para o tema Livro Sépia.
class SepiaPaperBackground extends StatelessWidget {
  /// Sub-variante ativa do tema Livro Sépia.
  final SepiaBookVariant variant;

  /// Indica se o modo escuro está ativo.
  final bool isDark;

  /// Cria um fundo estático com tonalidade de papel literário.
  const SepiaPaperBackground({
    super.key,
    required this.variant,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> colors;
    final Color vignetteColor;

    if (variant == SepiaBookVariant.editorialParchment) {
      colors = isDark
          ? const [Color(0xFF1A1510), Color(0xFF17130F), Color(0xFF14100C)]
          : const [Color(0xFFFCF9F2), Color(0xFFFAF6EE), Color(0xFFF4EDE0)];
      vignetteColor = isDark ? const Color(0xFF0C0906) : const Color(0xFFD9CCB4);
    } else {
      colors = isDark
          ? const [Color(0xFF1E1915), Color(0xFF1A1613), Color(0xFF14110E)]
          : const [Color(0xFFFAF6EE), Color(0xFFF5ECD7), Color(0xFFEDE0C4)];
      vignetteColor = isDark ? const Color(0xFF0A0806) : const Color(0xFFCBB692);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [
              Colors.transparent,
              vignetteColor.withValues(alpha: isDark ? 0.35 : 0.22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fundo gradiente estático com feixes luminosos clássicos do Android 4.0 Ice Cream Sandwich (Holo).
class HoloRetroBackground extends StatelessWidget {
  /// Indica se o modo escuro está ativo.
  final bool isDark;

  /// Cria o fundo gradiente vertical característico do Android 4.0 Holo com feixes azuis.
  const HoloRetroBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF000000), Color(0xFF071220), Color(0xFF10243B)]
                  : const [Color(0xFFF3F3F3), Color(0xFFECEFF3), Color(0xFFE2E9F0)],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _HoloPhaseBeamPainter(isDark: isDark),
          ),
        ),
      ],
    );
  }
}

class _HoloPhaseBeamPainter extends CustomPainter {
  final bool isDark;

  const _HoloPhaseBeamPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const holo = Color(0xFF33B5E5);
    final beamPaint = Paint()
      ..color = holo.withValues(alpha: isDark ? 0.08 : 0.06)
      ..style = PaintingStyle.fill;

    // Feixes diagonais suaves estilo Android 4.0 Phase Beam
    final beam1 = Path()
      ..moveTo(0, size.height * 0.12)
      ..lineTo(size.width * 0.65, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(0, size.height * 0.34)
      ..close();
    canvas.drawPath(beam1, beamPaint);

    final beam2 = Path()
      ..moveTo(size.width * 0.25, size.height)
      ..lineTo(size.width, size.height * 0.38)
      ..lineTo(size.width, size.height * 0.56)
      ..lineTo(size.width * 0.48, size.height)
      ..close();
    canvas.drawPath(beam2, beamPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          holo.withValues(alpha: isDark ? 0.14 : 0.08),
          holo.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.82, size.height * 0.18),
          radius: size.shortestSide * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.shortestSide * 0.55,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HoloPhaseBeamPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Barra de título azul estilo janela clássica do Windows 95 com controles `[_ □ X]`.
class Win95WindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título exibido na barra azul da janela.
  final String title;

  /// Widget opcional à esquerda do título (ex.: avatar de perfil).
  final Widget? leading;

  /// Botões de ação exibidos na barra de ferramentas da janela.
  final List<Widget>? actions;

  /// Callback opcional acionado ao tocar no botão fechar/minimizar decorativo.
  final VoidCallback? onWindowClose;

  /// Cria uma barra de título clássica estilo Windows 95.
  const Win95WindowTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.onWindowClose,
  });

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frameBg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
    final lightBevel = isDark ? const Color(0xFF606060) : const Color(0xFFFFFFFF);
    final darkBevel = isDark ? const Color(0xFF121212) : const Color(0xFF808080);

    return Container(
      decoration: BoxDecoration(
        color: frameBg,
        border: Border(
          bottom: BorderSide(color: darkBevel, width: 2),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF000080), Color(0xFF1084D0)],
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 4),
                ] else
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Win95PixelIcon(type: Win95PixelIconType.bibleBook, size: 18),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (actions != null)
                  ...actions!.map(
                    (action) => Theme(
                      data: Theme.of(context).copyWith(
                        iconTheme: const IconThemeData(color: Colors.white, size: 20),
                      ),
                      child: action,
                    ),
                  ),
                if (onWindowClose != null) ...[
                  const SizedBox(width: 4),
                  _Win95ControlGlyph(
                    glyph: 'X',
                    frameBg: frameBg,
                    lightBevel: lightBevel,
                    darkBevel: darkBevel,
                    onTap: onWindowClose,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Win95ControlGlyph extends StatelessWidget {
  final String glyph;
  final Color frameBg;
  final Color lightBevel;
  final Color darkBevel;
  final VoidCallback? onTap;

  const _Win95ControlGlyph({
    required this.glyph,
    required this.frameBg,
    required this.lightBevel,
    required this.darkBevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = frameBg.computeLuminance() > 0.35 ? Colors.black : Colors.white;
    final box = Container(
      width: 24,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: frameBg,
        border: Border(
          top: BorderSide(color: lightBevel, width: 1.5),
          left: BorderSide(color: lightBevel, width: 1.5),
          right: BorderSide(color: darkBevel, width: 1.5),
          bottom: BorderSide(color: darkBevel, width: 1.5),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          glyph,
          maxLines: 1,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );

    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: 'Fechar',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: box,
        ),
      ),
    );
  }
}

/// Campo branco afundado com chanfro 3D invertido clássico do Windows 95.
class Win95SunkenField extends StatelessWidget {
  /// Conteúdo interno do campo afundado.
  final Widget child;

  /// Preenchimento interno opcional.
  final EdgeInsetsGeometry? padding;

  /// Callback de toque opcional.
  final VoidCallback? onTap;

  /// Cria um campo com aparência afundada de caixa de texto do Windows 95.
  const Win95SunkenField({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final darkBorder = isDark ? const Color(0xFF0A0A0A) : const Color(0xFF808080);
    final lightBorder = isDark ? const Color(0xFF5A5A5A) : const Color(0xFFFFFFFF);

    Widget content = padding != null ? Padding(padding: padding!, child: child) : child;
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: content),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.zero,
        border: Border(
          top: BorderSide(color: darkBorder, width: 2),
          left: BorderSide(color: darkBorder, width: 2),
          right: BorderSide(color: lightBorder, width: 2),
          bottom: BorderSide(color: lightBorder, width: 2),
        ),
      ),
      child: content,
    );
  }
}

/// Item de destino exibido na barra de tarefas ou menu Iniciar do tema Windows 95.
class Win95TaskbarItem {
  /// Rótulo curto da janela/aba.
  final String label;

  /// Ícone da janela/aba.
  final IconData icon;

  /// Ícone pixel art opcional para o modo Windows 95.
  final Win95PixelIconType? pixelIcon;

  /// Cria um item para a barra de tarefas Windows 95.
  const Win95TaskbarItem({
    required this.label,
    required this.icon,
    this.pixelIcon,
  });
}

/// Barra de tarefas clássica do Windows 95 com botão Iniciar, abas 3D e relógio.
class Win95TaskbarNavigation extends StatelessWidget {
  /// Lista de abas exibidas como botões na barra de tarefas.
  final List<Win95TaskbarItem> items;

  /// Índice da aba atualmente ativa.
  final int selectedIndex;

  /// Callback acionado ao tocar em uma aba.
  final ValueChanged<int> onSelectTab;

  /// Callback acionado para abrir busca global a partir do Menu Iniciar.
  final VoidCallback? onOpenSearch;

  /// Callback acionado para abrir perfil a partir do Menu Iniciar.
  final VoidCallback? onOpenProfile;

  /// Callback acionado para abrir configurações a partir do Menu Iniciar.
  final VoidCallback? onOpenSettings;

  /// Exibe a barra como cápsula/janela flutuante quando verdadeira.
  final bool floating;

  /// Cria a barra de tarefas clássica estilo Windows 95.
  const Win95TaskbarNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectTab,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onOpenSettings,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
    final pressedBg = isDark ? const Color(0xFF3E3E3E) : const Color(0xFFE0E0E0);
    final lightBevel = isDark ? const Color(0xFF606060) : const Color(0xFFFFFFFF);
    final darkBevel = isDark ? const Color(0xFF121212) : const Color(0xFF808080);
    final textColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF000000);

    final now = DateTime.now();
    final clockText =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final barContent = Container(
      decoration: BoxDecoration(
        color: barBg,
        border: floating
            ? Border(
                top: BorderSide(color: lightBevel, width: 2),
                left: BorderSide(color: lightBevel, width: 2),
                right: BorderSide(color: darkBevel, width: 2),
                bottom: BorderSide(color: darkBevel, width: 2),
              )
            : Border(
                top: BorderSide(color: lightBevel, width: 2),
              ),
        boxShadow: floating
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(2, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Botão Iniciar clássico
              InkWell(
                onTap: () => Win95StartMenuDialog.show(
                  context,
                  items: items,
                  onSelectTab: onSelectTab,
                  onOpenSearch: onOpenSearch,
                  onOpenProfile: onOpenProfile,
                  onOpenSettings: onOpenSettings,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40, maxWidth: 116),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: barBg,
                    border: Border(
                      top: BorderSide(color: lightBevel, width: 2),
                      left: BorderSide(color: lightBevel, width: 2),
                      right: BorderSide(color: darkBevel, width: 2),
                      bottom: BorderSide(color: darkBevel, width: 2),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Win95PixelFlagIcon(),
                        const SizedBox(width: 6),
                        Text(
                          'Iniciar',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(width: 2, height: 28, color: darkBevel),
              const SizedBox(width: 4),
              // Abas em botões 3D roláveis horizontalmente para evitar overflow em 320dp
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final isSelected = i == selectedIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () => onSelectTab(i),
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 40,
                              minWidth: 56,
                              maxWidth: 118,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? pressedBg : barBg,
                              border: Border(
                                top: BorderSide(
                                  color: isSelected ? darkBevel : lightBevel,
                                  width: 2,
                                ),
                                left: BorderSide(
                                  color: isSelected ? darkBevel : lightBevel,
                                  width: 2,
                                ),
                                right: BorderSide(
                                  color: isSelected ? lightBevel : darkBevel,
                                  width: 2,
                                ),
                                bottom: BorderSide(
                                  color: isSelected ? lightBevel : darkBevel,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.pixelIcon != null)
                                  Win95PixelIcon(type: item.pixelIcon!, size: 15)
                                else
                                  Icon(item.icon, size: 15, color: textColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Bandeja do sistema com relógio afundado
              Container(
                constraints: const BoxConstraints(minHeight: 38, maxWidth: 74),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: barBg,
                  border: Border(
                    top: BorderSide(color: darkBevel, width: 1.5),
                    left: BorderSide(color: darkBevel, width: 1.5),
                    right: BorderSide(color: lightBevel, width: 1.5),
                    bottom: BorderSide(color: lightBevel, width: 1.5),
                  ),
                ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      clockText,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    if (floating) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: barContent,
        ),
      );
    }

    return ColoredBox(
      color: barBg,
      child: SafeArea(
        top: false,
        child: barContent,
      ),
    );
  }
}

class _Win95PixelFlagIcon extends StatelessWidget {
  const _Win95PixelFlagIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 14,
      height: 14,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: Color(0xFFF25022))),
                SizedBox(width: 1),
                Expanded(child: ColoredBox(color: Color(0xFF7FBA00))),
              ],
            ),
          ),
          SizedBox(height: 1),
          Expanded(
            child: Row(
              children: [
                Expanded(child: ColoredBox(color: Color(0xFF00A4EF))),
                SizedBox(width: 1),
                Expanded(child: ColoredBox(color: Color(0xFFFFB900))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo clássico estilo Menu Iniciar do Windows 95 com barra lateral azul vertical.
class Win95StartMenuDialog extends StatelessWidget {
  /// Destinos principais do menu.
  final List<Win95TaskbarItem> items;

  /// Callback para trocar de aba.
  final ValueChanged<int> onSelectTab;

  /// Callback opcional de busca global.
  final VoidCallback? onOpenSearch;

  /// Callback opcional de perfil.
  final VoidCallback? onOpenProfile;

  /// Callback opcional de configurações.
  final VoidCallback? onOpenSettings;

  /// Cria o Menu Iniciar estilo Windows 95.
  const Win95StartMenuDialog({
    super.key,
    required this.items,
    required this.onSelectTab,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onOpenSettings,
  });

  /// Abre o Menu Iniciar alinhado à base esquerda da tela.
  static Future<void> show(
    BuildContext context, {
    required List<Win95TaskbarItem> items,
    required ValueChanged<int> onSelectTab,
    VoidCallback? onOpenSearch,
    VoidCallback? onOpenProfile,
    VoidCallback? onOpenSettings,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (_) => Win95StartMenuDialog(
        items: items,
        onSelectTab: onSelectTab,
        onOpenSearch: onOpenSearch,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
    final lightBevel = isDark ? const Color(0xFF606060) : const Color(0xFFFFFFFF);
    final darkBevel = isDark ? const Color(0xFF121212) : const Color(0xFF808080);
    final textColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF000000);

    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 16, bottom: 58),
        child: Material(
          color: bg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, maxHeight: 420),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: lightBevel, width: 2),
                  left: BorderSide(color: lightBevel, width: 2),
                  right: BorderSide(color: darkBevel, width: 2),
                  bottom: BorderSide(color: darkBevel, width: 2),
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 28,
                      color: const Color(0xFF000080),
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          'Kairós 95',
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...List.generate(items.length, (i) {
                              final item = items[i];
                              return ListTile(
                                dense: true,
                                leading: item.pixelIcon != null
                                    ? Win95PixelIcon(type: item.pixelIcon!, size: 18)
                                    : Icon(item.icon, size: 18, color: textColor),
                                title: Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onSelectTab(i);
                                },
                              );
                            }),
                            Divider(height: 6, thickness: 1, color: darkBevel),
                            if (onOpenSearch != null)
                              ListTile(
                                dense: true,
                                leading: const Win95PixelIcon(
                                  type: Win95PixelIconType.searchMagnifier,
                                  size: 18,
                                ),
                                title: Text(
                                  'Pesquisar...',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onOpenSearch!();
                                },
                              ),
                            if (onOpenProfile != null)
                              ListTile(
                                dense: true,
                                leading: const Win95PixelIcon(
                                  type: Win95PixelIconType.computer,
                                  size: 18,
                                ),
                                title: Text(
                                  'Perfil e Conta',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onOpenProfile!();
                                },
                              ),
                            if (onOpenSettings != null)
                              ListTile(
                                dense: true,
                                leading: const Win95PixelIcon(
                                  type: Win95PixelIconType.controlPanel,
                                  size: 18,
                                ),
                                title: Text(
                                  'Painel de Controle',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: textColor, fontSize: 13),
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  onOpenSettings!();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ActionBar clássica do Android 4.0 ICS com textura carbon-fiber e linha `#33B5E5` de 2px.
class HoloRetroActionBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título exibido na barra superior Holo.
  final String title;

  /// Botão ou avatar inicial opcional.
  final Widget? leading;

  /// Ações exibidas na extremidade direita da barra.
  final List<Widget>? actions;

  /// Cria uma ActionBar no estilo Android 4.0 Ice Cream Sandwich.
  const HoloRetroActionBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF14181E) : const Color(0xFFEAEAEA);
    final fg = isDark ? const Color(0xFFF3F3F3) : const Color(0xFF1A1A1A);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFF33B5E5), width: 2.0),
        ),
      ),
      child: CustomPaint(
        painter: HoloCarbonPinstripePainter(isDark: isDark),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 54,
            child: Row(
              children: [
                if (leading != null) leading!,
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter de listras diagonais finas estilo ActionBar carbon-fiber do Android 4.0 ICS.
class HoloCarbonPinstripePainter extends CustomPainter {
  /// Indica se o tema escuro está ativo.
  final bool isDark;

  /// Cria o padrão diagonal discreto característico das barras ICS.
  const HoloCarbonPinstripePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.045)
          : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 6.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HoloCarbonPinstripePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Ícone clássico de sliders ciano do menu Settings do Android 4.0 ICS.
class HoloSettingsIcon extends StatelessWidget {
  /// Tamanho lateral do ícone em pixels lógicos.
  final double size;

  /// Cria o ícone clássico de ajustes estilo Ice Cream Sandwich.
  const HoloSettingsIcon({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2730),
        border: Border.all(color: const Color(0xFF33B5E5), width: 1.2),
      ),
      child: CustomPaint(painter: _HoloSettingsIconPainter()),
    );
  }
}

class _HoloSettingsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 2.0;
    final knob = Paint()..color = const Color(0xFF33B5E5);

    final rows = [0.28, 0.50, 0.72];
    final knobs = [0.68, 0.34, 0.72];
    for (int i = 0; i < 3; i++) {
      final y = size.height * rows[i];
      canvas.drawLine(
        Offset(size.width * 0.18, y),
        Offset(size.width * 0.82, y),
        track,
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(size.width * knobs[i], y),
          width: size.width * 0.18,
          height: size.height * 0.16,
        ),
        knob,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cabeçalho de seção em CAIXA ALTA `#33B5E5` com linha horizontal completa do Android 4.0 ICS.
class HoloSectionHeader extends StatelessWidget {
  /// Texto do cabeçalho (exibido em letras maiúsculas).
  final String title;

  /// Cria um cabeçalho de seção estilo Android 4.0 Settings.
  const HoloSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF33B5E5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 1.5,
          color: const Color(0xFF33B5E5),
        ),
      ],
    );
  }
}

/// Switch retangular chanfrado `[ OFF / ON ]` autêntico do Android 4.0 Ice Cream Sandwich.
class HoloSwitch extends StatelessWidget {
  /// Estado ligado ou desligado.
  final bool value;

  /// Callback de alteração ao tocar no switch.
  final ValueChanged<bool> onChanged;

  /// Rótulo de acessibilidade opcional.
  final String? semanticLabel;

  /// Cria um interruptor chanfrado estilo Holo ICS.
  const HoloSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Center(
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: SizedBox(
              width: 72,
              height: 26,
              child: CustomPaint(
                painter: _HoloSwitchPainter(value: value, isDark: isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoloSwitchPainter extends CustomPainter {
  final bool value;
  final bool isDark;

  const _HoloSwitchPainter({required this.value, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final trackColor = isDark ? const Color(0xFF282C34) : const Color(0xFFD0D4DA);
    final borderColor = isDark ? const Color(0xFF424854) : const Color(0xFF9AA2AE);

    // Trilho retangular de fundo
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = trackColor,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Paralelogramo chanfrado característico do Android 4.0
    const slant = 6.0;
    final halfW = size.width * 0.54;
    final Path thumb;
    if (value) {
      final startX = size.width - halfW;
      thumb = Path()
        ..moveTo(startX + slant, 2)
        ..lineTo(size.width - 2, 2)
        ..lineTo(size.width - 2, size.height - 2)
        ..lineTo(startX, size.height - 2)
        ..close();
    } else {
      thumb = Path()
        ..moveTo(2, 2)
        ..lineTo(halfW, 2)
        ..lineTo(halfW - slant, size.height - 2)
        ..lineTo(2, size.height - 2)
        ..close();
    }

    canvas.drawPath(
      thumb,
      Paint()..color = value ? const Color(0xFF33B5E5) : const Color(0xFF606670),
    );

    // Realce superior de 1px no thumb ativo
    if (value) {
      canvas.drawLine(
        Offset(size.width - halfW + slant, 2.5),
        Offset(size.width - 2, 2.5),
        Paint()
          ..color = const Color(0xFF9BE7FF)
          ..strokeWidth = 1.0,
      );
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: value ? 'ON' : 'OFF',
        style: TextStyle(
          color: value ? Colors.white : const Color(0xFFE5E7EB),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textCenterX = value ? size.width - halfW * 0.48 : halfW * 0.46;
    textPainter.paint(
      canvas,
      Offset(
        textCenterX - textPainter.width / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _HoloSwitchPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.isDark != isDark;
}

/// Campo ou seletor com colchete inferior `#33B5E5` e triângulo no canto (`|____◢`) do Android 4.0 ICS.
class HoloBracketField extends StatelessWidget {
  /// Conteúdo interno do campo.
  final Widget child;

  /// Preenchimento interno.
  final EdgeInsetsGeometry padding;

  /// Callback de toque opcional.
  final VoidCallback? onTap;

  /// Exibe o triângulo clássico de spinner no canto inferior direito (`◢`).
  final bool showCornerTriangle;

  /// Cria um campo com sublinhado em colchete estilo Android 4.0 Holo.
  const HoloBracketField({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.onTap,
    this.showCornerTriangle = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = CustomPaint(
      painter: _HoloBracketPainter(showCornerTriangle: showCornerTriangle),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      body = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: body),
      );
    }
    return body;
  }
}

class _HoloBracketPainter extends CustomPainter {
  final bool showCornerTriangle;

  const _HoloBracketPainter({required this.showCornerTriangle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF33B5E5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    const tick = 5.0;
    final path = Path()
      ..moveTo(0.8, size.height - tick)
      ..lineTo(0.8, size.height - 0.8)
      ..lineTo(size.width - 0.8, size.height - 0.8)
      ..lineTo(size.width - 0.8, size.height - tick);
    canvas.drawPath(path, paint);

    if (showCornerTriangle) {
      final tri = Path()
        ..moveTo(size.width - 9, size.height - 1)
        ..lineTo(size.width - 1, size.height - 1)
        ..lineTo(size.width - 1, size.height - 9)
        ..close();
      canvas.drawPath(
        tri,
        Paint()..color = const Color(0xFF33B5E5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HoloBracketPainter oldDelegate) =>
      oldDelegate.showCornerTriangle != showCornerTriangle;
}

/// Fundo clássico da área de trabalho Windows 95 (`#008080`) com marca d'água pixelada.
class Win95DesktopBackground extends StatelessWidget {
  /// Indica se a variante noturna está ativa.
  final bool isDark;

  /// Cria o fundo da área de trabalho do Windows 95 com bandeira pixelada no canto.
  const Win95DesktopBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF003B3B) : const Color(0xFF008080);
    return ColoredBox(
      color: bgColor,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 22),
            child: Opacity(
              opacity: isDark ? 0.18 : 0.28,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 68,
                    height: 46,
                    child: CustomPaint(painter: _Win95WatermarkFlagPainter()),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Microsoft\nWindows 95\nKairós',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Win95WatermarkFlagPainter extends CustomPainter {
  const _Win95WatermarkFlagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()..color = Colors.white;
    final cw = size.width / 17;
    final ch = size.height / 11;

    // Rastro pixelado à esquerda da bandeira
    const trail = [
      (0, 3), (2, 2), (4, 1),
      (1, 5), (3, 4), (5, 3),
      (0, 7), (2, 6), (4, 5),
      (2, 8), (4, 7), (5, 6),
    ];
    for (final (px, py) in trail) {
      canvas.drawRect(
        Rect.fromLTWH(px * cw, py * ch, cw * 0.85, ch * 0.85),
        white,
      );
    }

    // Quatro quadrantes clássicos da bandeira Windows 95
    canvas.drawRect(Rect.fromLTWH(7 * cw, 1 * ch, 4.2 * cw, 3.8 * ch), white);
    canvas.drawRect(Rect.fromLTWH(12 * cw, 1.5 * ch, 4.2 * cw, 3.8 * ch), white);
    canvas.drawRect(Rect.fromLTWH(7 * cw, 5.6 * ch, 4.2 * cw, 3.8 * ch), white);
    canvas.drawRect(Rect.fromLTWH(12 * cw, 6.1 * ch, 4.2 * cw, 3.8 * ch), white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Tipos de ícones em pixel art 16-bit do tema Clássico Windows 95.
enum Win95PixelIconType {
  /// Monitor CRT Meu Computador.
  computer,

  /// Bíblia aberta com marcador vermelho.
  bibleBook,

  /// Calendário de plano de leitura.
  readingPlan,

  /// Nota musical dourada e pauta.
  hymnalMusic,

  /// Globo/estudo da Escola Sabatina.
  sabbathSchool,

  /// Mapa com marcador vermelho.
  churchMap,

  /// Dois computadores conectados em rede (Turmas).
  classroom,

  /// Cartas / jogo clássico (Quizzes).
  quizGame,

  /// Pasta amarela com documentos (Espírito de Profecia).
  egwScroll,

  /// Pasta amarela com ferramentas (Painel de Controle).
  controlPanel,

  /// Lupa pixelada para busca.
  searchMagnifier,

  /// Bloco de notas em espiral azul/branco.
  notepad,

  /// Lamparina/chama em pixel art.
  flameLamp,
}

/// Renderizador de ícones em pixel art 16-bit para o tema Windows 95.
class Win95PixelIcon extends StatelessWidget {
  /// Tipo de ícone pixel art a exibir.
  final Win95PixelIconType type;

  /// Dimensão quadrada do ícone em pixels lógicos.
  final double size;

  /// Cria um ícone pixel art 16-bit nítido.
  const Win95PixelIcon({
    super.key,
    required this.type,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _Win95PixelArtPainter(type: type)),
    );
  }
}

class _Win95PixelArtPainter extends CustomPainter {
  final Win95PixelIconType type;

  const _Win95PixelArtPainter({required this.type});

  static const Map<String, Color> _palette = {
    '.': Colors.transparent,
    'k': Color(0xFF000000),
    'w': Color(0xFFFFFFFF),
    's': Color(0xFFC0C0C0),
    'g': Color(0xFF808080),
    'b': Color(0xFF000080),
    'c': Color(0xFF00FFFF),
    't': Color(0xFF008080),
    'y': Color(0xFFFFFF00),
    'o': Color(0xFFDAA520),
    'r': Color(0xFFCC0000),
    'e': Color(0xFF00AA00),
    'l': Color(0xFF38BDF8),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _gridFor(type);
    final rows = grid.length;
    final cols = grid[0].length;
    final cw = size.width / cols;
    final ch = size.height / rows;
    final paint = Paint()..isAntiAlias = false;

    for (int y = 0; y < rows; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length; x++) {
        final chCode = row[x];
        final color = _palette[chCode];
        if (color == null || color == Colors.transparent) continue;
        paint.color = color;
        canvas.drawRect(
          Rect.fromLTWH(x * cw, y * ch, cw + 0.35, ch + 0.35),
          paint,
        );
      }
    }
  }

  static List<String> _gridFor(Win95PixelIconType type) {
    switch (type) {
      case Win95PixelIconType.computer:
        return const [
          '..kkkkkkkkkkkk..',
          '.kssssssssssssk.',
          '.kswbbbbbbbbbsk.',
          '.kswbccccccbbsk.',
          '.kswbccccccbbsk.',
          '.kswbcwwwwcbbsk.',
          '.kswbbbbbbbbbsk.',
          '.kssssssssssssk.',
          '..kkkkkkkkkkkk..',
          '.....kggggk.....',
          '..kkkkkkkkkkkk..',
          '.kssssssssssssk.',
          '.kswwwwwwwwwssk.',
          '.kssggggggggssk.',
          '.kkkkkkkkkkkkkk.',
          '................',
        ];
      case Win95PixelIconType.bibleBook:
        return const [
          '................',
          '.kkkkkk..kkkkkk.',
          'kwwwwwwkkwwwwwwk',
          'kwggggwkkwggggwk',
          'kwwwwwwkkwwggwwk',
          'kwggggwkkwggggwk',
          'kwwwwwwkkwwwwwwk',
          'kwggggwkrwggggwk',
          'kwwwwwwkrwwwwwwk',
          'kwggggwkrwggggwk',
          'kwwwwwwkrwwwwwwk',
          'kssssssssssssssk',
          'kbbbbbbkrbbbbbbk',
          '.kkkkkkrrkkkkkk.',
          '.......rr.......',
          '................',
        ];
      case Win95PixelIconType.readingPlan:
        return const [
          '..kk........kk..',
          '.kkkkkkkkkkkkkk.',
          '.kbbbbbbbbbbbbk.',
          '.kbwwbwwbwwbwwk.',
          '.kkkkkkkkkkkkkk.',
          '.kwwwwwwwwwwwwk.',
          '.kwggwggwggwggk.',
          '.kwwwwwwwwwwwwk.',
          '.kwrrwggwggwggk.',
          '.kwrrwwwwwwwwwk.',
          '.kwggwggwbbwggk.',
          '.kwwwwwwwwwwwwk.',
          '.kssssssssssssk.',
          '..kkkkkkkkkkkk..',
          '................',
          '................',
        ];
      case Win95PixelIconType.hymnalMusic:
        return const [
          '......kkkkkkkk..',
          '.....kbbbbbbbbk.',
          '.....kboooooobk.',
          '.....kbbbbbbbbk.',
          '.....kb.....kbk.',
          '.....kb.....kbk.',
          '.....kb.....kbk.',
          '...kkkk...kkkk..',
          '..kbbbbk.kbbbbk.',
          '.kboooobkboooobk',
          '.kboooobkboooobk',
          '..kbbbbk.kbbbbk.',
          '...kkkk...kkkk..',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.sabbathSchool:
        return const [
          '.....kkkkkk.....',
          '...kkllllllkk...',
          '..kllleeeelllk..',
          '.kllleeeeeelllk.',
          '.klleeeeeeeellk.',
          'klllleeelleeellk',
          'kllleeelllllellk',
          'kllleeeelllllllk',
          'kllllleelllllllk',
          '.klllleeeellllk.',
          '.kllllllllllllk.',
          '..kllleeeelllk..',
          '...kkllllllkk...',
          '.....kkkkkk.....',
          '..kkkkkkkkkkkk..',
          '................',
        ];
      case Win95PixelIconType.churchMap:
        return const [
          '.kkkkkkkkkkkkkk.',
          '.keeeelllllleek.',
          '.keeellrrrlleek.',
          '.keelrrrrrrllek.',
          '.keelrrwwrrllek.',
          '.keelrrrrrrllek.',
          '.keeeelrrllleek.',
          '.kyyyyelllllyyk.',
          '.keeellllllleek.',
          '.keeeeellleeeek.',
          '.keeeeellleeeek.',
          '.ksssssllsssssk.',
          '.kkkkkkkkkkkkkk.',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.classroom:
        return const [
          '.kkkkkkk........',
          '.ksssssk........',
          '.ksbbbssk.......',
          '.ksssssk.kkkk...',
          '.kkkkkkk....k...',
          '...k........k...',
          '...k..kkkkkkk...',
          '...k..ksssssk...',
          '...k..ksbbbssk..',
          '...kkkksssssk...',
          '......kkkkkkk...',
          '.........k......',
          '.....kkkkkkkk...',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.quizGame:
        return const [
          '..kkkkkkkk......',
          '.kwwwwwwwwk.....',
          '.kwrwwwwwwk.....',
          '.kwrrrkkkkkkk...',
          '.kwrwwkwwwwwwk..',
          '.kwwwwkwbbwwwk..',
          '.kwwwwkwbbbwwk..',
          '.kwwwwkwbbwwwk..',
          '.ksssskwwwwwwk..',
          '..kkkkkwwwwwwk..',
          '......kssssssk..',
          '.......kkkkkk...',
          '................',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.egwScroll:
        return const [
          '..kkkkk.........',
          '.kyyyyyk........',
          'kyyyyyyykkkkkk..',
          'kywwwwwwwwwwyk..',
          'kywggggggggwyk..',
          'kywwwwwwwwwwyk..',
          'kykkkkkkkkkkkkk.',
          'kyyyyyyyyyyyyyyk',
          'kyyyyyyyyyyyyyyk',
          'kyyyyyyyyyyyyyyk',
          'kyoooooooooooook',
          '.kkkkkkkkkkkkkk.',
          '................',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.controlPanel:
        return const [
          '..kkkkk.........',
          '.kyyyyyk........',
          'kyyyyyyykkkkkk..',
          'kyyykkkyyyyyyk..',
          'kyykgkkyyrrryk..',
          'kyyksskyyrrryk..',
          'kyyykkkyyyokkk..',
          'kyyygkyyyyokyk..',
          'kyyygkyyyyokyk..',
          'kyyygkyyyyokyk..',
          'kyoooooooooook..',
          '.kkkkkkkkkkkk...',
          '................',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.searchMagnifier:
        return const [
          '...kkkkkk.......',
          '..kcccccck......',
          '.kcwwccccck.....',
          '.kcwcccccck.....',
          '.kcccccccck.....',
          '..kcccccck......',
          '...kkkkkkk......',
          '........kggk....',
          '.........kggk...',
          '..........kork..',
          '...........kork.',
          '............kkk.',
          '................',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.notepad:
        return const [
          '..k.k.k.k.k.k...',
          '.kkkkkkkkkkkkk..',
          '.kbbbbbbbbbbbk..',
          '.kbbbbbbbbbbbk..',
          '.kwwwwwwwwwwwk..',
          '.kwgggggggggwk..',
          '.kwwwwwwwwwwwk..',
          '.kwgggggggggwk..',
          '.kwwwwwwwwwwwk..',
          '.kwgggggggggwk..',
          '.kwwwwwwwwwwwk..',
          '.ksssssssssssk..',
          '..kkkkkkkkkkk...',
          '................',
          '................',
          '................',
        ];
      case Win95PixelIconType.flameLamp:
        return const [
          '.......kk.......',
          '......krrk......',
          '.....kryyrk.....',
          '.....kryyrk.....',
          '......kyyk......',
          '....kkkkkkkk....',
          '...kooooooook...',
          '...koyyyyyyok...',
          '...koyyyyyyok...',
          '....kooooook....',
          '.....kkkkkk.....',
          '...kkkkkkkkkk...',
          '..kssssssssssk..',
          '...kkkkkkkkkk...',
          '................',
          '................',
        ];
    }
  }

  @override
  bool shouldRepaint(covariant _Win95PixelArtPainter oldDelegate) =>
      oldDelegate.type != type;
}

/// Ícone de atalho na área de trabalho do tema Windows 95.
class Win95DesktopIconTile extends StatelessWidget {
  /// Ícone pixel art exibido no topo.
  final Win95PixelIconType iconType;

  /// Título curto do atalho.
  final String title;

  /// Subtítulo ou badge opcional (ex.: `ARA`, `ADULTOS`).
  final String? badgeText;

  /// Callback de abertura ao tocar no atalho.
  final VoidCallback onTap;

  /// Cria um ícone estilo área de trabalho Windows 95/98.
  const Win95DesktopIconTile({
    super.key,
    required this.iconType,
    required this.title,
    required this.onTap,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: badgeText != null ? '$title ($badgeText)' : title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Win95PixelIcon(type: iconType, size: 38),
                    if (badgeText != null)
                      Positioned(
                        right: -6,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC0C0C0),
                            border: Border.all(color: Colors.black, width: 1),
                          ),
                          child: Text(
                            badgeText!,
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000080).withValues(alpha: 0.72),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caixa de seleção quadrada 3D afundada autêntica do Windows 95 (`[✓]`).
class Win95CheckboxTile extends StatelessWidget {
  /// Rótulo principal da opção.
  final String title;

  /// Descrição opcional exibida abaixo do título.
  final String? subtitle;

  /// Estado marcado ou desmarcado.
  final bool value;

  /// Callback ao alterar o estado.
  final ValueChanged<bool> onChanged;

  /// Cria uma opção com caixa de seleção clássica do Windows 95.
  const Win95CheckboxTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxFill = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final darkBevel = isDark ? const Color(0xFF0D0D0D) : const Color(0xFF808080);
    final lightBevel = isDark ? const Color(0xFF5A5A5A) : const Color(0xFFFFFFFF);
    final textColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF000000);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: boxFill,
                    border: Border(
                      top: BorderSide(color: darkBevel, width: 1.5),
                      left: BorderSide(color: darkBevel, width: 1.5),
                      right: BorderSide(color: lightBevel, width: 1.5),
                      bottom: BorderSide(color: lightBevel, width: 1.5),
                    ),
                  ),
                  child: value
                      ? Text(
                          '✓',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFC0C0C0) : const Color(0xFF404040),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de abas estilo Android 4.0 Holo com divisores verticais e barra `#33B5E5` de 4px.
class HoloRetroTabBar extends StatelessWidget {
  /// Abas exibidas na barra Holo.
  final List<Win95TaskbarItem> items;

  /// Índice da aba selecionada.
  final int selectedIndex;

  /// Callback de troca de aba.
  final ValueChanged<int> onSelectTab;

  /// Exibe a barra como painel flutuante com margem inferior quando verdadeira.
  final bool floating;

  /// Cria uma barra de abas estilo Android 4.0 ICS Holo.
  const HoloRetroTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectTab,
    this.floating = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101824) : const Color(0xFFF3F3F3);
    final dividerColor = isDark ? const Color(0x33FFFFFF) : const Color(0x26000000);
    final inactiveColor = isDark ? const Color(0xFFBBBBBB) : const Color(0xFF4D4D4D);
    const holoBlue = Color(0xFF33B5E5);

    final rowWidget = Row(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isSelected = i == selectedIndex;

        return Expanded(
          child: InkWell(
            onTap: () => onSelectTab(i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              decoration: BoxDecoration(
                color: isSelected
                    ? holoBlue.withValues(alpha: isDark ? 0.14 : 0.10)
                    : Colors.transparent,
                border: Border(
                  right: i < items.length - 1
                      ? BorderSide(color: dividerColor, width: 1.0)
                      : BorderSide.none,
                  bottom: BorderSide(
                    color: isSelected ? holoBlue : Colors.transparent,
                    width: 4.0,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 18,
                    color: isSelected ? holoBlue : inactiveColor,
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.3,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? holoBlue : inactiveColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    if (floating) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.96),
              border: Border.all(color: holoBlue, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: holoBlue.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: rowWidget,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: const Border(
          top: BorderSide(color: holoBlue, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: rowWidget,
      ),
    );
  }
}

/// Fundo atmosférico estático em estilo ASCII Vintage (CRT com scanlines no escuro;
/// papel formulário contínuo matricial no modo claro).
class AsciiTerminalBackground extends StatelessWidget {
  /// Variante cromática do tema ASCII.
  final AsciiThemeVariant variant;

  /// Define se o brilho atual é escuro (CRT) ou claro (papel matricial).
  final bool isDark;

  /// Cor de destaque usada na variante [AsciiThemeVariant.dynamicColor].
  final Color seedColor;

  /// Constrói o fundo de terminal/formulário contínuo sem animações contínuas pesadas.
  const AsciiTerminalBackground({
    super.key,
    required this.variant,
    required this.isDark,
    required this.seedColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseBg;
    final Color accent;
    switch (variant) {
      case AsciiThemeVariant.greenPhosphor:
        baseBg = isDark ? const Color(0xFF060B06) : const Color(0xFFF1F5EE);
        accent = isDark ? const Color(0xFF39FF6E) : const Color(0xFF0E5E24);
        break;
      case AsciiThemeVariant.amberCrt:
        baseBg = isDark ? const Color(0xFF0D0904) : const Color(0xFFF7F2E7);
        accent = isDark ? const Color(0xFFFFB000) : const Color(0xFF8A4B00);
        break;
      case AsciiThemeVariant.matrixPaper:
        baseBg = isDark ? const Color(0xFF0C1014) : const Color(0xFFF3F4EE);
        accent = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D3557);
        break;
      case AsciiThemeVariant.dynamicColor:
        baseBg = isDark ? const Color(0xFF080A0D) : const Color(0xFFF4F5F2);
        accent = seedColor;
        break;
    }

    return RepaintBoundary(
      child: ColoredBox(
        color: baseBg,
        child: CustomPaint(
          painter: _AsciiBackgroundPainter(
            isDark: isDark,
            accent: accent,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _AsciiBackgroundPainter extends CustomPainter {
  final bool isDark;
  final Color accent;

  const _AsciiBackgroundPainter({
    required this.isDark,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) {
      // Scanlines sutis de monitor CRT
      final linePaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..strokeWidth = 1.0;
      for (double y = 0; y < size.height; y += 4.0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      // Brilho fosforescente periférico discreto
      final glowPaint = Paint()
        ..color = accent.withValues(alpha: 0.04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRect(const Offset(6, 6) & Size(size.width - 12, size.height - 12), glowPaint);
    } else {
      // Listras alternadas de papel formulário contínuo ("zebra" verde/creme de impressora matricial)
      final bandPaint = Paint()..color = accent.withValues(alpha: 0.045);
      const bandHeight = 28.0;
      for (double y = 0; y < size.height; y += bandHeight * 2) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, bandHeight), bandPaint);
      }
      // Furos laterais de tração de formulário contínuo em telas mais largas
      if (size.width >= 360) {
        final holePaint = Paint()..color = accent.withValues(alpha: 0.14);
        for (double y = 16; y < size.height; y += 36) {
          canvas.drawCircle(Offset(9, y), 2.2, holePaint);
          canvas.drawCircle(Offset(size.width - 9, y), 2.2, holePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AsciiBackgroundPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.accent != accent;
}

/// Tipos de ícones em pixel-art 16-bit estilo RPG de SNES para o tema ASCII / Retrô.
enum SnesPixelIconType {
  /// Bíblia sagrada aberta com marcador.
  bible,

  /// Harpa clássica para o Hinário.
  harp,

  /// Sol radiante para Devocional / Pôr do Sol.
  sun,

  /// Pergaminho desenrolado para Escola Sabatina / Textos.
  scroll,

  /// Raio de energia / XP.
  bolt,

  /// Lamparina a óleo acesa.
  lamp,

  /// Ampulheta de tempo devocional.
  hourglass,

  /// Troféu / Cálices de Planos e Conquistas.
  trophy,

  /// Pessoas / Comunidade e Turmas.
  people,

  /// Pena clássica / Espírito de Profecia.
  feather,

  /// Lupa pixelada de pesquisa.
  search,

  /// Engrenagem pixelada de configurações.
  gear,

  /// Casa / Tela Inicial.
  home,

  /// Marca de verificação concluída.
  check,

  /// Igreja / Capela com torre.
  church,

  /// Bloco [?] de Quiz / Desafio.
  quiz,

  /// Folha de calendário mensal.
  calendar,
}

/// Sprite em matriz 12x12 pixel-art 16-bit SNES sem anti-aliasing.
class SnesPixelIcon extends StatelessWidget {
  /// Identificador do sprite exibido.
  final SnesPixelIconType type;

  /// Tamanho quadrado do ícone em pixels lógicos.
  final double size;

  /// Cor principal opcional (padrão: [ColorScheme.primary]).
  final Color? color;

  /// Cor secundária de destaque opcional (padrão: [ColorScheme.secondary]).
  final Color? accentColor;

  /// Renderiza um ícone em pixel-art SNES sem suavização.
  const SnesPixelIcon({
    super.key,
    required this.type,
    this.size = 24,
    this.color,
    this.accentColor,
  });

  /// Converte um [IconData] padrão do app para o [SnesPixelIconType] correspondente.
  static SnesPixelIconType fromIconData(IconData icon) {
    if (icon == Icons.home_outlined || icon == Icons.home_rounded || icon == Icons.home) {
      return SnesPixelIconType.home;
    }
    if (icon == Icons.book_outlined ||
        icon == Icons.menu_book_rounded ||
        icon == Icons.menu_book_outlined) {
      return SnesPixelIconType.bible;
    }
    if (icon == Icons.music_note_outlined || icon == Icons.music_note_rounded) {
      return SnesPixelIconType.harp;
    }
    if (icon == Icons.volunteer_activism_outlined ||
        icon == Icons.volunteer_activism_rounded ||
        icon == Icons.wb_sunny_rounded ||
        icon == Icons.wb_sunny_outlined) {
      return SnesPixelIconType.sun;
    }
    if (icon == Icons.school_outlined || icon == Icons.school_rounded) {
      return SnesPixelIconType.scroll;
    }
    if (icon == Icons.quiz_outlined || icon == Icons.quiz_rounded) {
      return SnesPixelIconType.quiz;
    }
    if (icon == Icons.hourglass_top_rounded) {
      return SnesPixelIconType.hourglass;
    }
    if (icon == Icons.bolt_rounded || icon == Icons.bolt_sharp || icon == Icons.bolt) {
      return SnesPixelIconType.bolt;
    }
    if (icon == Icons.groups_rounded || icon == Icons.groups_outlined) {
      return SnesPixelIconType.people;
    }
    if (icon == Icons.church_rounded) {
      return SnesPixelIconType.church;
    }
    if (icon == Icons.auto_stories_rounded || icon == Icons.auto_stories_outlined) {
      return SnesPixelIconType.feather;
    }
    if (icon == Icons.calendar_month_rounded) {
      return SnesPixelIconType.calendar;
    }
    if (icon == Icons.search_rounded || icon == Icons.search_sharp) {
      return SnesPixelIconType.search;
    }
    if (icon == Icons.settings_outlined || icon == Icons.settings) {
      return SnesPixelIconType.gear;
    }
    if (icon == Icons.emoji_events_rounded) {
      return SnesPixelIconType.trophy;
    }
    if (icon == Icons.check || icon == Icons.check_circle_rounded) {
      return SnesPixelIconType.check;
    }
    return SnesPixelIconType.lamp;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = color ?? cs.primary;
    final secondary = accentColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFD54F)
            : Color.lerp(primary, const Color(0xFFD97706), 0.55)!);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SnesPixelIconPainter(
          type: type,
          primary: primary,
          secondary: secondary,
        ),
      ),
    );
  }
}

class _SnesPixelIconPainter extends CustomPainter {
  final SnesPixelIconType type;
  final Color primary;
  final Color secondary;

  const _SnesPixelIconPainter({
    required this.type,
    required this.primary,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _gridFor(type);
    final rows = grid.length;
    final cols = grid[0].length;
    final cw = size.width / cols;
    final ch = size.height / rows;

    final highlight = Color.lerp(primary, Colors.white, 0.42)!;
    final shadow = Color.lerp(primary, Colors.black, 0.48)!;
    final paint = Paint()..isAntiAlias = false;

    for (int y = 0; y < rows; y++) {
      final row = grid[y];
      for (int x = 0; x < row.length; x++) {
        final Color? c = switch (row[x]) {
          '#' => primary,
          '+' => highlight,
          's' => shadow,
          'a' => secondary,
          _ => null,
        };
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(
          Rect.fromLTWH(x * cw, y * ch, cw + 0.3, ch + 0.3),
          paint,
        );
      }
    }
  }

  static List<String> _gridFor(SnesPixelIconType type) {
    switch (type) {
      case SnesPixelIconType.bible:
        return const [
          '............',
          '.ssss..ssss.',
          's++++ss++++s',
          's+###ss###+s',
          's+#s#ss#s#+s',
          's+###ss###+s',
          's+#s#ss#s#+s',
          's####aa####s',
          's####aa####s',
          '.ssssaaasss.',
          '.....aa.....',
          '.....a......',
        ];
      case SnesPixelIconType.harp:
        return const [
          '.....ssssss.',
          '....s++++++s',
          '...s+a#s#a+s',
          '...s+s#s#s+s',
          '...s+a#s#a+s',
          '...s+#s#s#+s',
          '..s+a#s#s#s.',
          '..s+#######s',
          '..s+#######s',
          '...s######s.',
          '..ssssssssss',
          '............',
        ];
      case SnesPixelIconType.sun:
        return const [
          '.....++.....',
          '.s...++...s.',
          '..s..ss..s..',
          '...s++++s...',
          '..s++aa++s..',
          '++s+aaaa+s++',
          '++s+aaaa+s++',
          '..s++##++s..',
          '...s####s...',
          '..s..ss..s..',
          '.s...##...s.',
          '.....##.....',
        ];
      case SnesPixelIconType.scroll:
        return const [
          '..ssssssss..',
          '.s++++++++s.',
          '.s++##+++#s.',
          '..ssssssss..',
          '..s######s..',
          '..s#ss###s..',
          '..s#ssss#s..',
          '..s######s..',
          '.s+###ss+#s.',
          '.s++++++++s.',
          '..ssssssss..',
          '............',
        ];
      case SnesPixelIconType.bolt:
        return const [
          '......ssss..',
          '.....s+++s..',
          '....s++#s...',
          '...s++#s....',
          '..s++a+ssss.',
          '.s+++aaaaa+s',
          '.ssss+aaa+s.',
          '....s+##+s..',
          '...s+##+s...',
          '..s+##s.....',
          '..s#s.......',
          '..ss........',
        ];
      case SnesPixelIconType.lamp:
        return const [
          '.....aa.....',
          '....a++a....',
          '....a++a....',
          '.....aa.....',
          '...ssssss...',
          '..s++++++s..',
          '.ss+####+s..',
          's.s+aaaa+s.s',
          'ss+######+ss',
          '..s######s..',
          '.ssssssssss.',
          '............',
        ];
      case SnesPixelIconType.hourglass:
        return const [
          '.ssssssssss.',
          '.s++++++++s.',
          '..s+####+s..',
          '..s+a##a+s..',
          '...s+aa+s...',
          '....s++s....',
          '....s++s....',
          '...s+ss+s...',
          '..s+ssss+s..',
          '..s+aaaa+s..',
          '.s++++++++s.',
          '.ssssssssss.',
        ];
      case SnesPixelIconType.trophy:
        return const [
          '.ssssssssss.',
          's+aaaaaaaa+s',
          's.s+aaaa+s.s',
          's.s+aaaa+s.s',
          '.ss+####+ss.',
          '...s####s...',
          '....s##s....',
          '....s##s....',
          '...s++++s...',
          '..s######s..',
          '..ssssssss..',
          '............',
        ];
      case SnesPixelIconType.people:
        return const [
          '..sss..sss..',
          '.s+++ss+++s.',
          '.s+#+ss+#+s.',
          '..sss..sss..',
          '.ssss..ssss.',
          's++++ss++++s',
          's+##+ss+##+s',
          's+##+ss+##+s',
          's+##+ss+##+s',
          '.s##s..s##s.',
          '.ssss..ssss.',
          '............',
        ];
      case SnesPixelIconType.feather:
        return const [
          '........sss.',
          '.......s+++s',
          '......s++a+s',
          '.....s++a##s',
          '....s++a##s.',
          '...s++a##s..',
          '..s++a##s...',
          '..s+a##s....',
          '.s+a#ss.....',
          '.s+ss.......',
          's+s.........',
          'ss..........',
        ];
      case SnesPixelIconType.search:
        return const [
          '..sssss.....',
          '.s+++++s....',
          's++###++s...',
          's+##+##+s...',
          's+#####+s...',
          '.s+++++s....',
          '..sssss+s...',
          '......s++s..',
          '.......s++s.',
          '........s++s',
          '.........sss',
          '............',
        ];
      case SnesPixelIconType.gear:
        return const [
          '....ssss....',
          '.ss.s++s.ss.',
          '.s+ss++ss+s.',
          '..s++++++s..',
          'ss++s..s++ss',
          's+++....+++s',
          's###....###s',
          'ss##s..s##ss',
          '..s######s..',
          '.s#ss##ss#s.',
          '.ss.s##s.ss.',
          '....ssss....',
        ];
      case SnesPixelIconType.home:
        return const [
          '.....ss.....',
          '....s++s....',
          '...s++++s...',
          '..s++++++s..',
          '.s++++++++s.',
          's+########+s',
          '.s+######+s.',
          '.s+##aa##+s.',
          '.s+##aa##+s.',
          '.s+##aa##+s.',
          '.ssssssssss.',
          '............',
        ];
      case SnesPixelIconType.check:
        return const [
          '............',
          '.........ss.',
          '........s++s',
          '.......s++s.',
          '.ss...s++s..',
          's++s.s++s...',
          's+++s++s....',
          '.s++++s.....',
          '..s++s......',
          '...ss.......',
          '............',
          '............',
        ];
      case SnesPixelIconType.church:
        return const [
          '.....++.....',
          '....++++....',
          '.....++.....',
          '....s++s....',
          '...s++++s...',
          '..s+####+s..',
          '.s+######+s.',
          '.s+##aa##+s.',
          '.s+##aa##+s.',
          '.s+##aa##+s.',
          '.ssssssssss.',
          '............',
        ];
      case SnesPixelIconType.quiz:
        return const [
          '.ssssssssss.',
          's++++++++++s',
          's+##aaaa##+s',
          's+#a++++a#+s',
          's+##s..sa#+s',
          's#####aa##+s',
          's####aa###+s',
          's####aa####s',
          's##########s',
          's####aa####s',
          's##########s',
          '.ssssssssss.',
        ];
      case SnesPixelIconType.calendar:
        return const [
          '..ss....ss..',
          '.s++ssss++s.',
          's+aaaaaaaa+s',
          's+aaaaaaaa+s',
          's+ssssssss+s',
          's+##+##+##+s',
          's+########+s',
          's+##+aa+##+s',
          's+########+s',
          's+##+##+##+s',
          '.ssssssssss.',
          '............',
        ];
    }
  }

  @override
  bool shouldRepaint(covariant _SnesPixelIconPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}

class _SnesPixelBoxPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final Color innerLineColor;
  final bool doubleBorder;

  const _SnesPixelBoxPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.innerLineColor,
    required this.doubleBorder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 8 || h <= 8) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
      return;
    }

    const u = 3.0; // Bloco base 3x3px SNES RPG
    final bgPaint = Paint()
      ..color = backgroundColor
      ..isAntiAlias = false;

    // Preenchimento interno respeitando cantos chanfrados 3x3
    canvas.drawRect(Rect.fromLTWH(u, u, w - u * 2, h - u * 2), bgPaint);

    final outerPaint = Paint()
      ..color = borderColor
      ..isAntiAlias = false;

    // Borda externa pixelada com cantos escalonados estilo janela RPG 16-bit
    canvas.drawRect(Rect.fromLTWH(u, 0, w - u * 2, u), outerPaint);
    canvas.drawRect(Rect.fromLTWH(u, h - u, w - u * 2, u), outerPaint);
    canvas.drawRect(Rect.fromLTWH(0, u, u, h - u * 2), outerPaint);
    canvas.drawRect(Rect.fromLTWH(w - u, u, u, h - u * 2), outerPaint);

    // Blocos internos nos 4 cantos para dar o degrau clássico de 3px
    canvas.drawRect(const Rect.fromLTWH(u, u, u, u), outerPaint);
    canvas.drawRect(Rect.fromLTWH(w - u * 2, u, u, u), outerPaint);
    canvas.drawRect(Rect.fromLTWH(u, h - u * 2, u, u), outerPaint);
    canvas.drawRect(Rect.fromLTWH(w - u * 2, h - u * 2, u, u), outerPaint);

    // Linha pixelada interna separada por 2px da moldura externa
    if (w >= 26 && h >= 26) {
      const gap = 2.0;
      const inset = u + gap;
      final innerT = doubleBorder ? 2.5 : 1.5;
      final innerPaint = Paint()
        ..color = innerLineColor
        ..isAntiAlias = false;

      canvas.drawRect(Rect.fromLTWH(inset + u * 0.5, inset, w - (inset * 2 + u), innerT), innerPaint);
      canvas.drawRect(Rect.fromLTWH(inset + u * 0.5, h - inset - innerT, w - (inset * 2 + u), innerT), innerPaint);
      canvas.drawRect(Rect.fromLTWH(inset, inset + u * 0.5, innerT, h - (inset * 2 + u)), innerPaint);
      canvas.drawRect(Rect.fromLTWH(w - inset - innerT, inset + u * 0.5, innerT, h - (inset * 2 + u)), innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SnesPixelBoxPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.innerLineColor != innerLineColor ||
      oldDelegate.doubleBorder != doubleBorder;
}

/// Superfície retangular estilo RPG 16-Bit SNES / Terminal com moldura em blocos de pixel 3x3.
class AsciiBoxSurface extends StatelessWidget {
  /// Conteúdo exibido dentro da caixa 16-bit SNES.
  final Widget child;

  /// Preenchimento interno opcional.
  final EdgeInsetsGeometry? padding;

  /// Margem externa opcional.
  final EdgeInsetsGeometry? margin;

  /// Cor explícita de fundo opcional.
  final Color? color;

  /// Rótulo opcional exibido como plaquinha pixelada sólida no topo da caixa.
  final String? label;

  /// Utiliza linha interna reforçada em caixa de destaque / janela principal.
  final bool doubleBorder;

  /// Callback de toque opcional.
  final VoidCallback? onTap;

  /// Constrói uma caixa com estética pixel-art SNES 16-bit e zero bordas suaves.
  const AsciiBoxSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.label,
    this.doubleBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = color ?? cs.surface;
    final border = cs.primary;
    final hasLabel = label != null && label!.trim().isNotEmpty;

    Widget inner = padding != null ? Padding(padding: padding!, child: child) : child;
    if (onTap != null) {
      inner = InkWell(
        borderRadius: BorderRadius.zero,
        onTap: onTap,
        child: inner,
      );
    }

    final Widget body = hasLabel
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: border,
                  border: Border(
                    bottom: BorderSide(
                      color: border.withValues(alpha: 0.35),
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  label!.trim().toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'RetroPixel',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              inner,
            ],
          )
        : inner;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: CustomPaint(
          painter: _SnesPixelBoxPainter(
            backgroundColor: bg,
            borderColor: border,
            innerLineColor: border.withValues(alpha: doubleBorder ? 0.65 : 0.32),
            doubleBorder: doubleBorder,
          ),
          child: Padding(
            padding: EdgeInsets.all(doubleBorder ? 6.0 : 4.5),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Barra superior estilo console RPG 16-Bit SNES / Terminal para o tema ASCII Vintage.
class AsciiWindowTitleBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título exibido na barra superior.
  final String title;

  /// Widget opcional à esquerda (ex.: botão voltar).
  final Widget? leading;

  /// Ações exibidas no lado direito da barra.
  final List<Widget>? actions;

  /// Callback opcional para fechar janela/modal (`[X]`).
  final VoidCallback? onWindowClose;

  /// Constrói a barra de título estilo RPG 16-bit SNES.
  const AsciiWindowTitleBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.onWindowClose,
  });

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final Widget? resolvedLeading = leading ??
        (canPop
            ? InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.primary, width: 2.0),
                  ),
                  child: Text(
                    '[<-]',
                    style: TextStyle(
                      fontFamily: 'RetroPixel',
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            : null);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.primary, width: 3.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (resolvedLeading != null) ...[
                resolvedLeading,
                const SizedBox(width: 8),
              ],
              Text(
                ':: ',
                style: TextStyle(
                  fontFamily: 'RetroPixel',
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'RetroPixel',
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (actions != null)
                ...actions!.map(
                  (action) => Theme(
                    data: Theme.of(context).copyWith(
                      iconTheme: IconThemeData(color: cs.primary, size: 20),
                    ),
                    child: action,
                  ),
                ),
              if (onWindowClose != null) ...[
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: 'Fechar',
                  child: InkWell(
                    onTap: onWindowClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        border: Border.all(color: cs.primary, width: 2.0),
                      ),
                      child: Text(
                        '[X]',
                        style: TextStyle(
                          fontFamily: 'RetroPixel',
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Interruptor booleano em estilo RPG 16-Bit / ASCII (`[ON ]` / `[OFF]`).
class AsciiSwitch extends StatelessWidget {
  /// Estado atual do interruptor.
  final bool value;

  /// Callback disparado ao alternar o valor.
  final ValueChanged<bool> onChanged;

  /// Cria um interruptor textual estilo 16-bit `[ON ]` / `[OFF]`.
  const AsciiSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value ? cs.primary : Colors.transparent,
            border: Border.all(color: cs.primary, width: 2.5),
          ),
          child: Text(
            value ? '[ON ]' : '[OFF]',
            style: TextStyle(
              fontFamily: 'RetroPixel',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: value ? cs.onPrimary : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de navegação estilo SNES 16-Bit / ASCII com suporte a modo fixo ou flutuante.
class AsciiTabBar extends StatelessWidget {
  /// Abas de navegação exibidas na barra.
  final List<Win95TaskbarItem> items;

  /// Índice selecionado atualmente.
  final int selectedIndex;

  /// Callback disparado ao selecionar uma aba.
  final ValueChanged<int> onSelectTab;

  /// Define se a barra flutua sobre o conteúdo em formato de janela RPG 16-bit.
  final bool floating;

  /// Cria uma barra de abas estilo RPG 16-bit SNES.
  const AsciiTabBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectTab,
    this.floating = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final row = Row(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isSelected = i == selectedIndex;
        final iconColor = isSelected ? cs.onPrimary : cs.primary;
        return Expanded(
          child: InkWell(
            onTap: () => onSelectTab(i),
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : Colors.transparent,
                border: Border(
                  right: i < items.length - 1
                      ? BorderSide(color: cs.primary.withValues(alpha: 0.45), width: 2.0)
                      : BorderSide.none,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SnesPixelIcon(
                    type: SnesPixelIcon.fromIconData(item.icon),
                    size: 16,
                    color: iconColor,
                    accentColor: iconColor,
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isSelected ? '[${item.label.toUpperCase()}]' : item.label.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'RetroPixel',
                        fontSize: 9.0,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );

    if (floating) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: AsciiBoxSurface(
            doubleBorder: true,
            padding: EdgeInsets.zero,
            child: row,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.primary, width: 3.0)),
      ),
      child: SafeArea(top: false, child: row),
    );
  }
}

/// Barra de navegação rápida universal adaptada a todos os 8 temas do Kairós,
/// com alternância entre estilo cápsula flutuante e barra fixa ancorada.
class KairosQuickNavBar extends StatelessWidget {
  /// Destinos exibidos na barra rápida.
  final List<Win95TaskbarItem> items;

  /// Índice da aba selecionada.
  final int selectedIndex;

  /// Callback de seleção de aba.
  final ValueChanged<int> onSelectTab;

  /// Define se a barra flutua sobre o rodapé da tela.
  final bool floating;

  /// Callbacks opcionais para integração com o Menu Iniciar do Windows 95.
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenSettings;

  /// Constrói a barra de navegação rápida respeitando o tema ativo e o modo [floating].
  const KairosQuickNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectTab,
    required this.floating,
    this.onOpenSearch,
    this.onOpenProfile,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService();

    if (ts.isWin95) {
      return Win95TaskbarNavigation(
        items: items,
        selectedIndex: selectedIndex,
        onSelectTab: onSelectTab,
        onOpenSearch: onOpenSearch,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
        floating: floating,
      );
    }

    if (ts.isAscii) {
      return AsciiTabBar(
        items: items,
        selectedIndex: selectedIndex,
        onSelectTab: onSelectTab,
        floating: floating,
      );
    }

    if (ts.isHoloRetro) {
      return HoloRetroTabBar(
        items: items,
        selectedIndex: selectedIndex,
        onSelectTab: onSelectTab,
        floating: floating,
      );
    }

    if (ts.isRealGlass) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cs = Theme.of(context).colorScheme;
      final innerRow = _buildUnifiedTabRow(
        context,
        activeColor: cs.primary,
        inactiveColor: isDark ? const Color(0xFFD0D9E8) : const Color(0xFF334155),
        activeBg: cs.primary.withValues(alpha: isDark ? 0.22 : 0.14),
        pillRadius: floating ? 24 : 16,
      );

      if (floating) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: RepaintBoundary(
              child: GlassContainer.card(
                surfaceStyle: GlassSurfaceStyle.glass,
                useOwnLayer: false,
                quality: GlassQuality.standard,
                shape: const LiquidRoundedSuperellipse(borderRadius: 28),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                clipBehavior: Clip.antiAlias,
                child: innerRow,
              ),
            ),
          ),
        );
      }

      return RepaintBoundary(
        child: GlassContainer.card(
          surfaceStyle: GlassSurfaceStyle.glass,
          useOwnLayer: false,
          quality: GlassQuality.standard,
          shape: const LiquidRoundedSuperellipse(borderRadius: 0),
          padding: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: innerRow,
            ),
          ),
        ),
      );
    }

    if (ts.isAppleGlass) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final palette = ts.getPalette(isDark);
      final cs = Theme.of(context).colorScheme;
      final row = _buildUnifiedTabRow(
        context,
        activeColor: cs.primary,
        inactiveColor: palette.textSecondary,
        activeBg: cs.primary.withValues(alpha: 0.15),
        pillRadius: floating ? 22 : 16,
      );

      Widget glassSurface = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: floating ? 0.88 : 0.94),
          borderRadius: floating ? BorderRadius.circular(28) : BorderRadius.zero,
          border: Border.all(color: palette.borderColor, width: 1.0),
          boxShadow: floating
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: row,
      );

      if (ts.glassBlurEnabled) {
        glassSurface = ClipRRect(
          borderRadius: floating ? BorderRadius.circular(28) : BorderRadius.zero,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: glassSurface,
          ),
        );
      }

      if (floating) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: glassSurface,
          ),
        );
      }
      return SafeArea(top: false, child: glassSurface);
    }

    // Material You, Classic Book e Zen
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final palette = ts.getPalette(isDark);
    final bgColor = ts.isClassicBook || ts.isZen ? palette.surface : cs.surfaceContainer;
    final borderColor = ts.isClassicBook || ts.isZen
        ? palette.borderColor
        : cs.outlineVariant.withValues(alpha: 0.55);

    final clampedScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 0.85,
      maxScaleFactor: 1.2,
    );

    final navBarWidget = MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: clampedScaler,
        padding: floating ? EdgeInsets.zero : MediaQuery.of(context).padding,
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: cs.primary.withValues(alpha: isDark ? 0.22 : 0.14),
          elevation: 0,
          height: 62,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return IconThemeData(
              size: 20,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            );
          }),
        ),
        child: NavigationBar(
          height: 62,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelectTab,
          destinations: items
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );

    if (floating) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Material(
            color: bgColor,
            elevation: isDark ? 8 : 6,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ts.isZen ? 20 : 28),
              side: BorderSide(color: borderColor, width: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: navBarWidget,
          ),
        ),
      );
    }

    return Material(
      color: bgColor,
      shape: Border(
        top: BorderSide(color: borderColor, width: 1.0),
      ),
      child: navBarWidget,
    );
  }

  Widget _buildUnifiedTabRow(
    BuildContext context, {
    required Color activeColor,
    required Color inactiveColor,
    required Color activeBg,
    required double pillRadius,
  }) {
    return Row(
      children: List.generate(items.length, (i) {
        final item = items[i];
        final isSelected = i == selectedIndex;
        return Expanded(
          child: Tooltip(
            message: item.label,
            child: InkWell(
              borderRadius: BorderRadius.circular(pillRadius),
              onTap: () => onSelectTab(i),
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(pillRadius),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Barra superior adaptativa reutilizável em qualquer tela ou subtela do aplicativo,
/// aplicando automaticamente Win95, ASCII Vintage, Holo 4.0 ou Vidro/Material 3.
class KairosAdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Título exibido na barra superior.
  final String title;

  /// Widget opcional à esquerda (padrão: botão voltar automático se houver rota anterior).
  final Widget? leading;

  /// Ações opcionais à direita.
  final List<Widget>? actions;

  /// Exibe o título centralizado nos temas Material/Glass/Sépia.
  final bool centerTitle;

  /// Botão inferior opcional (ex.: TabBar).
  final PreferredSizeWidget? bottom;

  /// Constrói uma barra superior totalmente aderente ao tema ativo no [ThemeService].
  const KairosAdaptiveAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.bottom,
  });

  @override
  Size get preferredSize {
    final baseHeight = bottom != null ? kToolbarHeight + bottom!.preferredSize.height : kToolbarHeight;
    return Size.fromHeight(baseHeight);
  }

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService();
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    if (ts.isWin95) {
      final winBar = Win95WindowTitleBar(
        title: title,
        leading: leading,
        actions: actions,
        onWindowClose: canPop ? () => Navigator.of(context).maybePop() : null,
      );
      if (bottom == null) return winBar;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [winBar, bottom!],
      );
    }

    if (ts.isAscii) {
      final asciiBar = AsciiWindowTitleBar(
        title: title,
        leading: leading,
        actions: actions,
        onWindowClose: canPop ? () => Navigator.of(context).maybePop() : null,
      );
      if (bottom == null) return asciiBar;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [asciiBar, bottom!],
      );
    }

    if (ts.isHoloRetro) {
      final cs = Theme.of(context).colorScheme;
      const holoBlue = Color(0xFF33B5E5);
      return AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        leading: leading,
        actions: actions,
        centerTitle: centerTitle,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        bottom: bottom ??
            const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: SizedBox(
                height: 2,
                child: ColoredBox(color: holoBlue),
              ),
            ),
      );
    }

    return AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: ts.hasAtmosphericBackground ? Colors.transparent : null,
      surfaceTintColor: ts.hasAtmosphericBackground ? Colors.transparent : null,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: bottom,
    );
  }
}

/// Cabeçalho adaptativo para caixas de diálogo e modais, garantindo botão de fechar
/// único no Windows 95 e identidade visual no tema ASCII Vintage e demais estilos.
class KairosAdaptiveDialogHeader extends StatelessWidget {
  /// Título exibido no topo do diálogo.
  final String title;

  /// Ícone exibido à esquerda nos temas modernos/clássicos.
  final IconData? icon;

  /// Callback de fechamento (padrão: `Navigator.maybePop`).
  final VoidCallback? onClose;

  /// Constrói um cabeçalho de diálogo consistente com todos os 8 temas.
  const KairosAdaptiveDialogHeader({
    super.key,
    required this.title,
    this.icon,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService();
    final cs = Theme.of(context).colorScheme;
    final closeAction = onClose ?? () => Navigator.of(context).maybePop();

    if (ts.isWin95) {
      return Win95WindowTitleBar(
        title: title,
        onWindowClose: closeAction,
      );
    }

    if (ts.isAscii) {
      return AsciiWindowTitleBar(
        title: title,
        onWindowClose: closeAction,
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
      decoration: ts.isHoloRetro
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF33B5E5), width: 2)),
            )
          : null,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fechar',
            onPressed: closeAction,
          ),
        ],
      ),
    );
  }
}
