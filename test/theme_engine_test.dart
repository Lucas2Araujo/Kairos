import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kairos_web/services/theme_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThemeService().setEdition('novo');
  });

  group('Theme Engine & Accessibility Tests', () {
    test('WCAG contrast math: relativeLuminance, contrastRatio, isWcagAAA, and adaptiveTextColor', () {
      // 1. Relative luminance boundaries
      expect(AppTheme.relativeLuminance(Colors.black), closeTo(0.0, 0.01));
      expect(AppTheme.relativeLuminance(Colors.white), closeTo(1.0, 0.01));

      // 2. Contrast ratio between black and white is exactly 21.0
      final blackWhiteRatio = AppTheme.contrastRatio(Colors.black, Colors.white);
      expect(blackWhiteRatio, closeTo(21.0, 0.05));

      // 3. isWcagAAA validation (>= 7.0 for normal text, >= 4.5 for large text)
      expect(AppTheme.isWcagAAA(Colors.black, Colors.white), isTrue);
      expect(AppTheme.isWcagAAA(Colors.black, Colors.white, isLargeText: true), isTrue);
      expect(AppTheme.isWcagAAA(const Color(0xFF777777), const Color(0xFF888888)), isFalse);

      // 4. adaptiveTextColor picks white on dark #060911 and dark #141218 on light #F4F8FC
      const darkBg = Color(0xFF060911);
      const lightBg = Color(0xFFF4F8FC);
      expect(AppTheme.adaptiveTextColor(darkBg), equals(Colors.white));
      expect(AppTheme.adaptiveTextColor(lightBg), equals(const Color(0xFF141218)));
    });

    test('Theme styles, amoled mode, and antigo edition support', () {
      final service = ThemeService();

      // Material You style
      service.setThemeStyle(AppThemeStyle.materialYou);
      expect(service.isLiquidGlass, isFalse);
      expect(service.isClassicBook, isFalse);

      // Liquid Glass style (scaffoldBackgroundColor should be transparent)
      service.setThemeStyle(AppThemeStyle.liquidGlass);
      expect(service.isLiquidGlass, isTrue);
      expect(service.lightTheme.scaffoldBackgroundColor, equals(Colors.transparent));
      expect(service.darkTheme.scaffoldBackgroundColor, equals(Colors.transparent));

      // Apple Glass style (scaffoldBackgroundColor should be transparent & high contrast text)
      service.setThemeStyle(AppThemeStyle.appleGlass);
      expect(service.isAppleGlass, isTrue);
      expect(service.isAnyGlass, isTrue);
      expect(service.lightTheme.scaffoldBackgroundColor, equals(Colors.transparent));
      expect(service.darkTheme.scaffoldBackgroundColor, equals(Colors.transparent));
      expect(service.lightTheme.textTheme.bodyLarge?.color, equals(const Color(0xFF0F172A)));
      expect(service.darkTheme.textTheme.bodyLarge?.color, equals(const Color(0xFFF8FAFC)));

      // Classic Book style
      service.setThemeStyle(AppThemeStyle.classicBook);
      expect(service.isClassicBook, isTrue);
      expect(service.isLiquidGlass, isFalse);

      // AMOLED dark mode (scaffoldBackgroundColor should be black)
      service.setThemeMode(ThemeMode.dark);
      service.setAmoled(true);
      expect(service.isAmoled, isTrue);
      expect(service.darkTheme.scaffoldBackgroundColor, equals(Colors.black));

      // Antigo hymnal edition
      service.setEdition('antigo');
      expect(service.currentEdition, equals('antigo'));
    });

    test('All 6 color seeds and custom color update currentColor in ThemeService', () {
      final service = ThemeService();
      const expectedSeeds = [
        'emerald',
        'purple',
        'gold',
        'sapphire',
        'peach',
        'rose',
      ];
      expect(ThemeService.colorSeeds.containsKey('lavender'), isFalse);

      for (final seed in expectedSeeds) {
        service.setColorSeed(seed);
        expect(ThemeService.colorSeeds.containsKey(seed), isTrue,
            reason: 'colorSeeds should define seed: $seed');
        expect(service.currentColor, equals(ThemeService.colorSeeds[seed]),
            reason: 'currentColor should match palette seed: $seed');
      }

      const custom = Color(0xFF123456);
      service.setCustomColor(custom);
      expect(service.colorKey, equals('custom'));
      expect(service.currentColor, equals(custom));
    });

    test('KidsHymnStyles identifies kids hymns and formats verse titles', () {
      // Positive cases: 508, '530', '557', '508A'
      expect(KidsHymnStyles.isKidsHymn(508), isTrue);
      expect(KidsHymnStyles.isKidsHymn('530'), isTrue);
      expect(KidsHymnStyles.isKidsHymn('557'), isTrue);
      expect(KidsHymnStyles.isKidsHymn('508A'), isTrue);

      // Negative cases: 1, 507, 558, 600, null
      expect(KidsHymnStyles.isKidsHymn(1), isFalse);
      expect(KidsHymnStyles.isKidsHymn(507), isFalse);
      expect(KidsHymnStyles.isKidsHymn(558), isFalse);
      expect(KidsHymnStyles.isKidsHymn(600), isFalse);
      expect(KidsHymnStyles.isKidsHymn(null), isFalse);

      // Edition antigo disables kids style even within range (508..557)
      expect(KidsHymnStyles.isKidsHymn(510, edition: 'antigo'), isFalse);
      expect(KidsHymnStyles.isKidsHymn(510, edition: 'novo'), isTrue);

      // resolveVerseTitle distinguishes 'Coro ☀️' vs 'Estrofe 1'
      expect(KidsHymnStyles.resolveVerseTitle('Coro', 0), equals('Coro ☀️'));
      expect(KidsHymnStyles.resolveVerseTitle('Vinde meninos, vinde a Jesus', 0), equals('Estrofe 1'));
    });

    test('KairosPalette exposes required static light and dark palettes', () {
      expect(KairosPalette.materialYouLight, isNotNull);
      expect(KairosPalette.materialYouDark, isNotNull);
      expect(KairosPalette.liquidGlassLight, isNotNull);
      expect(KairosPalette.liquidGlassDark, isNotNull);
      expect(KairosPalette.classicBookLight, isNotNull);
      expect(KairosPalette.classicBookDark, isNotNull);
      expect(KairosPalette.antigoLight, isNotNull);
      expect(KairosPalette.antigoDark, isNotNull);
    });

    testWidgets('ThemeService propagates theme updates across widget tree', (tester) async {
      final service = ThemeService();
      service.setThemeStyle(AppThemeStyle.materialYou);

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            return MaterialApp(
              theme: service.lightTheme,
              darkTheme: service.darkTheme,
              themeMode: ThemeMode.light,
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => Text(
                    'Theme Engine Active',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('Theme Engine Active'), findsOneWidget);
    });
  });
}
