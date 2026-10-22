import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

enum AppThemeStyle { materialYou, liquidGlass, appleGlass, classicBook }

class KairosPalette {
  final String name;
  final bool isDark;
  final bool isGlass;
  final double blurSigma;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderColor;

  const KairosPalette({
    required this.name,
    required this.isDark,
    required this.isGlass,
    required this.blurSigma,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderColor,
  });

  static const KairosPalette materialYouLight = KairosPalette(
    name: 'Material You Claro',
    isDark: false,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFFFCF8FD),
    surface: Color(0xFFF8F2F8),
    surfaceContainer: Color(0xFFEFE8EF),
    surfaceContainerHigh: Color(0xFFE8E1E8),
    primary: Color(0xFF6750A4),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1C1B1F),
    textSecondary: Color(0xFF49454F),
    textMuted: Color(0xFF655E6F),
    borderColor: Colors.transparent,
  );

  static const KairosPalette materialYouDark = KairosPalette(
    name: 'Material You Escuro',
    isDark: true,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFF141218),
    surface: Color(0xFF1D1B20),
    surfaceContainer: Color(0xFF211F26),
    surfaceContainerHigh: Color(0xFF2B2930),
    primary: Color(0xFFD0BCFF),
    onPrimary: Color(0xFF381E72),
    textPrimary: Color(0xFFE6E1E5),
    textSecondary: Color(0xFFCAC4D0),
    textMuted: Color(0xFF938F99),
    borderColor: Colors.transparent,
  );

  static const KairosPalette liquidGlassLight = KairosPalette(
    name: 'Liquid Glass Claro',
    isDark: false,
    isGlass: true,
    blurSigma: 20.0,
    background: Color(0xFFF4F8FC),
    surface: Color(0xD1FFFFFF), // white 0.82
    surfaceContainer: Color(0xD9E2E8F0), // #E2E8F0 0.85
    surfaceContainerHigh: Color(0xD9CBD5E1), // #CBD5E1 0.85
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF475569),
    borderColor: Color(0xBFFFFFFF), // white 0.75
  );

  static const KairosPalette liquidGlassDark = KairosPalette(
    name: 'Liquid Glass Escuro',
    isDark: true,
    isGlass: true,
    blurSigma: 20.0,
    background: Color(0xFF060911),
    surface: Color(0xBF1E293B), // #1E293B 0.75
    surfaceContainer: Color(0xCC131C2E), // #131C2E 0.80
    surfaceContainerHigh: Color(0xCC1E2C44), // #1E2C44 0.80
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF090D16),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    borderColor: Color(0x3D94A3B8), // #94A3B8 0.24
  );

  static const KairosPalette classicBookLight = KairosPalette(
    name: 'Classic Book Claro',
    isDark: false,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFFF9F6F0),
    surface: Color(0xFFEFE9DE),
    surfaceContainer: Color(0xFFE5DDD0),
    surfaceContainerHigh: Color(0xFFDDD3C3),
    primary: Color(0xFF795548),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF241C14),
    textSecondary: Color(0xFF4E342E),
    textMuted: Color(0xFF6D4C41),
    borderColor: Color(0xFFD7CCC8),
  );

  static const KairosPalette classicBookDark = KairosPalette(
    name: 'Classic Book Escuro',
    isDark: true,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFF1A1613),
    surface: Color(0xFF241E18),
    surfaceContainer: Color(0xFF2E2620),
    surfaceContainerHigh: Color(0xFF382F27),
    primary: Color(0xFFD7CCC8),
    onPrimary: Color(0xFF1A1613),
    textPrimary: Color(0xFFEFE6DC),
    textSecondary: Color(0xFFD7CCC8),
    textMuted: Color(0xFFA1887F),
    borderColor: Color(0xFF3E3228),
  );

  static const KairosPalette antigoLight = KairosPalette(
    name: 'Antigo Claro',
    isDark: false,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFFFDFBF7),
    surface: Color(0xFFF5EFEB),
    surfaceContainer: Color(0xFFEADFD8),
    surfaceContainerHigh: Color(0xFFDFD1C7),
    primary: Color(0xFF5B3A29),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF2C1B14),
    textSecondary: Color(0xFF5C463A),
    textMuted: Color(0xFF5C463A),
    borderColor: Color(0xFFD8C7BC),
  );

  static const KairosPalette antigoDark = KairosPalette(
    name: 'Antigo Escuro',
    isDark: true,
    isGlass: false,
    blurSigma: 0.0,
    background: Color(0xFF1A130F),
    surface: Color(0xFF251D18),
    surfaceContainer: Color(0xFF332822),
    surfaceContainerHigh: Color(0xFF41342C),
    primary: Color(0xFFE6A15C),
    onPrimary: Color(0xFF1A130F),
    textPrimary: Color(0xFFF5EFEB),
    textSecondary: Color(0xFFD4C2B5),
    textMuted: Color(0xFFD4C2B5),
    borderColor: Color(0xFF4A392F),
  );
}

class AppTheme {
  static ThemeData get darkTheme => ThemeService().darkTheme;
  static ThemeData get lightTheme => ThemeService().lightTheme;

  static double relativeLuminance(Color c) => c.computeLuminance();

  static double contrastRatio(Color fg, Color bg) {
    final lumFg = relativeLuminance(fg);
    final lumBg = relativeLuminance(bg);
    final l1 = math.max(lumFg, lumBg);
    final l2 = math.min(lumFg, lumBg);
    return (l1 + 0.05) / (l2 + 0.05);
  }

  static bool isWcagAAA(Color fg, Color bg, {bool isLargeText = false}) {
    final ratio = contrastRatio(fg, bg);
    final threshold = isLargeText ? 4.5 : 7.0;
    return ratio >= threshold;
  }

  static Color adaptiveTextColor(
    Color bg, {
    Color light = Colors.white,
    Color dark = const Color(0xFF141218),
  }) {
    final crLight = contrastRatio(light, bg);
    final crDark = contrastRatio(dark, bg);
    return crLight >= crDark ? light : dark;
  }
}

class LiquidGlassBackground extends StatelessWidget {
  final Widget child;

  const LiquidGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        if (!themeService.isLiquidGlass) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isAmoled = themeService.isAmoled;
        final primaryColor = themeService.currentColor;

        List<Color> bgColors;
        if (isDark && isAmoled) {
          bgColors = const [Color(0xFF000000), Color(0xFF04070F), Color(0xFF070D19)];
        } else if (isDark) {
          bgColors = const [Color(0xFF060911), Color(0xFF0B1220), Color(0xFF0F1E36)];
        } else {
          bgColors = const [Color(0xFFF8FAFC), Color(0xFFEEF2F6), Color(0xFFE0F2FE)];
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: bgColors,
                  stops: const [0.0, 0.50, 1.0],
                ),
              ),
            ),
            IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: -60,
                    left: -50,
                    width: 340,
                    height: 340,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            primaryColor.withValues(alpha: isDark ? 0.24 : 0.18),
                            primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 220,
                    right: -80,
                    width: 380,
                    height: 380,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF0284C7).withValues(alpha: isDark ? 0.28 : 0.20),
                            const Color(0xFF0284C7).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -60,
                    left: 60,
                    width: 360,
                    height: 360,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            primaryColor.withValues(alpha: isDark ? 0.20 : 0.14),
                            primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}
class GlobalThemeBackgroundShell extends StatelessWidget {
  final Widget child;

  const GlobalThemeBackgroundShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        if (themeService.isLiquidGlass) {
          return LiquidGlassBackground(child: child);
        }

        if (themeService.isAppleGlass) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final seed = themeService.currentColor;
          final hsl = HSLColor.fromColor(seed);
          final analogPlus35 = hsl.withHue((hsl.hue + 35) % 360).toColor();
          final analogMinus35 = hsl.withHue((hsl.hue - 35 + 360) % 360).toColor();

          final baseBg = isDark
              ? (themeService.isAmoled ? Colors.black : const Color(0xFF0B0F19))
              : const Color(0xFFF1F5F9);

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: baseBg),
              IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: -90,
                      left: -70,
                      width: 420,
                      height: 420,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              seed.withValues(alpha: isDark ? 0.32 : 0.22),
                              seed.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 180,
                      right: -90,
                      width: 400,
                      height: 400,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              analogPlus35.withValues(alpha: isDark ? 0.26 : 0.18),
                              analogPlus35.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -100,
                      left: 40,
                      width: 440,
                      height: 440,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              analogMinus35.withValues(alpha: isDark ? 0.24 : 0.16),
                              analogMinus35.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              child,
            ],
          );
        }

        // Temas sem vidro (materialYou, classicBook, etc.)
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: child,
        );
      },
    );
  }
}

class AppleGlassBackground extends StatelessWidget {
  final Widget child;

  const AppleGlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GlobalThemeBackgroundShell(child: child);
  }
}

class AppleGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  const AppleGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seed = themeService.currentColor;
    final r = BorderRadius.circular(borderRadius);

    Widget innerContent = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null) {
      innerContent = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: innerContent,
        ),
      );
    }

    final glassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              Color.alphaBlend(seed.withValues(alpha: 0.12), Colors.white).withValues(alpha: 0.22),
              Colors.white.withValues(alpha: 0.10),
            ]
          : [
              Colors.white.withValues(alpha: 0.72),
              Color.alphaBlend(seed.withValues(alpha: 0.05), Colors.white).withValues(alpha: 0.54),
            ],
    );

    final rimBorder = Border.all(
      width: 1.2,
      color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.85),
    );

    final boxShadow = BoxShadow(
      color: isDark ? Colors.black.withValues(alpha: 0.45) : const Color(0xFF0F172A).withValues(alpha: 0.06),
      blurRadius: 28,
      offset: const Offset(0, 10),
    );

    Widget surfaceBox = Container(
      decoration: BoxDecoration(
        color: color,
        gradient: color == null ? glassGradient : null,
        borderRadius: r,
        border: rimBorder,
      ),
      child: innerContent,
    );

    if (themeService.glassBlurEnabled) {
      surfaceBox = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: surfaceBox,
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [boxShadow],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: surfaceBox,
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = BorderRadius.circular(borderRadius);

    Widget innerContent = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: child,
    );

    if (onTap != null) {
      innerContent = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: innerContent,
        ),
      );
    }

    if (themeService.isLiquidGlass) {
      final isAmoled = themeService.isAmoled && isDark;
      List<Color> gradientColors;
      if (!isDark) {
        final tintedEnd = Color.alphaBlend(
          themeService.currentColor.withValues(alpha: 0.05),
          const Color(0xFFF1F5F9),
        );
        gradientColors = [
          Colors.white.withValues(alpha: 0.86),
          tintedEnd.withValues(alpha: 0.56),
        ];
      } else if (isAmoled) {
        gradientColors = [
          const Color(0xFF121824).withValues(alpha: 0.68),
          const Color(0xFF070A10).withValues(alpha: 0.42),
        ];
      } else {
        gradientColors = [
          const Color(0xFF1E293B).withValues(alpha: 0.72),
          const Color(0xFF0F172A).withValues(alpha: 0.45),
        ];
      }

      final rimBorder = Border.all(
        width: 1.2,
        color: isDark
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.85),
      );

      final boxShadow = BoxShadow(
        color: isDark
            ? Colors.black.withValues(alpha: 0.40)
            : const Color(0xFF0F172A).withValues(alpha: 0.08),
        blurRadius: isDark ? 24 : 20,
        offset: Offset(0, isDark ? 10 : 8),
      );

      Widget surfaceBox = Container(
        decoration: BoxDecoration(
          color: color,
          gradient: color == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                )
              : null,
          borderRadius: r,
          border: rimBorder,
        ),
        child: innerContent,
      );

      if (themeService.glassBlurEnabled) {
        surfaceBox = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: surfaceBox,
        );
      }

      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [boxShadow],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: surfaceBox,
        ),
      );
    }
    if (themeService.isAppleGlass) {
      return AppleGlassCard(
        padding: padding,
        margin: margin,
        borderRadius: borderRadius,
        onTap: onTap,
        color: color,
        child: child,
      );
    }
    
    if (themeService.isClassicBook) {
      final palette = themeService.getPalette(isDark: isDark);
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: color ?? palette.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.borderColor, width: 1.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: innerContent,
        ),
      );
    }

    // Material You
    final surfaceColor = color ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: innerContent,
      ),
    );
  }
}

class KidsHymnStyles {
  static bool isKidsHymn(Object? numero) {
    if (numero == null) return false;
    final match = RegExp(r'^(\d+)').firstMatch(numero.toString().trim());
    if (match == null) return false;
    final val = int.tryParse(match.group(1)!);
    if (val == null) return false;
    return val >= 508 && val <= 557;
  }

  static Widget buildBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE58F),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wb_sunny_rounded, size: 18, color: Color(0xFFB85D19)),
          SizedBox(width: 6),
          Text(
            'Hino Infantil',
            style: TextStyle(
              color: Color(0xFF6E3300),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 6),
          Icon(Icons.star_rounded, size: 16, color: Color(0xFFD97706)),
        ],
      ),
    );
  }

  static String resolveVerseTitle(String estrofe, int index) {
    final lines = estrofe.trim().split('\n');
    final firstLine = lines.isEmpty ? '' : lines.first.trim().toLowerCase();
    if (firstLine.startsWith('coro') || firstLine.startsWith('refrão')) {
      return 'Coro ☀️';
    }
    final displayIndex = index <= 0 ? 1 : index;
    return 'Estrofe $displayIndex';
  }

  static Widget buildVerseCard({
    required String estrofe,
    required int index,
    required BuildContext context,
  }) {
    final themeService = ThemeService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOdd = index % 2 != 0;
    final title = resolveVerseTitle(estrofe, index);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _resolveTitleColor(context, themeService, isDark, isOdd),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          estrofe,
          textAlign: themeService.hymnTextAlign,
          style: TextStyle(
            fontSize: 18 * themeService.fontSizeMultiplier,
            fontWeight: FontWeight.w500,
            color: _resolveTextColor(context, themeService, isDark, isOdd),
            height: 1.5,
            fontFamily: themeService.fontFamily,
          ),
        ),
      ],
    );

    if (themeService.isAnyGlass) {
      Gradient gradient;
      Color borderColor;
      List<BoxShadow> shadows;

      if (!isDark) {
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOdd
              ? const [Color(0xCCFFF3E0), Color(0x8CFFE0B2)]
              : const [Color(0xCCE0F2F1), Color(0x8CE8F5E9)],
        );
        borderColor = Colors.white.withValues(alpha: 0.70);
        shadows = [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ];
      } else {
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOdd
              ? const [Color(0xB33E2723), Color(0x66271612)]
              : const [Color(0xB3004D40), Color(0x66002D26)],
        );
        borderColor = Colors.white.withValues(alpha: 0.24);
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ];
      }

      Widget cardBox = Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: content,
      );

      if (themeService.glassBlurEnabled) {
        cardBox = BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: cardBox,
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: cardBox,
        ),
      );
    }

    if (themeService.isClassicBook) {
      Color bgColor;
      Color borderColor;
      if (!isDark) {
        bgColor = isOdd ? const Color(0xFFFFF8EB) : const Color(0xFFEAF7EE);
        borderColor = isOdd ? const Color(0xFFF5E5C9) : const Color(0xFFCDECD6);
      } else {
        bgColor = isOdd ? const Color(0xFF2A1F18) : const Color(0xFF162822);
        borderColor = isOdd ? const Color(0xFF4A3525) : const Color(0xFF234A3C);
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(32),
        ),
        child: content,
      );
    }

    // Material You
    final cs = Theme.of(context).colorScheme;
    final surfaceColor = isOdd ? cs.tertiaryContainer : cs.secondaryContainer;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: content,
    );
  }

  static Color _resolveTitleColor(
    BuildContext context,
    ThemeService themeService,
    bool isDark,
    bool isOdd,
  ) {
    if (themeService.isAnyGlass) {
      if (!isDark) {
        return isOdd ? const Color(0xFF8B2500) : const Color(0xFF06544E);
      } else {
        return isOdd ? const Color(0xFFFDBA74) : const Color(0xFF5EEAD4);
      }
    }
    if (themeService.isClassicBook) {
      if (!isDark) {
        return isOdd ? const Color(0xFF823400) : const Color(0xFF064E52);
      } else {
        return isOdd ? const Color(0xFFFFB74D) : const Color(0xFF80CBC4);
      }
    }
    final cs = Theme.of(context).colorScheme;
    return isOdd ? cs.onTertiaryContainer : cs.onSecondaryContainer;
  }

  static Color _resolveTextColor(
    BuildContext context,
    ThemeService themeService,
    bool isDark,
    bool isOdd,
  ) {
    if (themeService.isAnyGlass) {
      return isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    }
    if (themeService.isClassicBook) {
      if (!isDark) {
        return const Color(0xFF1C1B1F);
      } else {
        return isOdd ? const Color(0xFFFFF3E0) : const Color(0xFFE0F2F1);
      }
    }
    final cs = Theme.of(context).colorScheme;
    return isOdd ? cs.onTertiaryContainer : cs.onSecondaryContainer;
  }
}
