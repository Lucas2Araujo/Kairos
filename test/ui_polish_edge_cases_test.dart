import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UI Polish, Theme Synergy & Edge Cases', () {
    test('ThemeService defaults: glassBlurEnabled e richThemeSurfaces iniciam false', () {
      final ts = ThemeService();
      expect(ts.glassBlurEnabled, isFalse);
      expect(ts.richThemeSurfaces, isFalse);
    });

    test('Todos os 8 estilos geram lightTheme e darkTheme válidos e getPalette consistente', () async {
      final ts = ThemeService();
      for (final style in AppThemeStyle.values) {
        await ts.setThemeStyle(style);
        expect(ts.lightTheme.colorScheme, isNotNull);
        expect(ts.darkTheme.colorScheme, isNotNull);
        expect(ts.getPalette(false).name, isNotEmpty);
        expect(ts.getPalette(true).name, isNotEmpty);
      }
      await ts.setThemeStyle(AppThemeStyle.appleGlass);
      expect(ts.hasAtmosphericBackground, isTrue);
      await ts.setThemeStyle(AppThemeStyle.ascii);
      expect(ts.hasGlobalBackgroundShell, isTrue);
      await ts.setThemeStyle(AppThemeStyle.materialYou);
    });

    testWidgets('Modo Zen oculta seletor de cores e SettingsDialog sem overflow em 320px + TextScaler 1.6',
        (tester) async {
      final ts = ThemeService();
      await ts.setThemeStyle(AppThemeStyle.zen);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: ts.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: SettingsDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('O modo Zen utiliza uma paleta neutra fixa para foco total na leitura.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('GlassSurface + KairosInteractiveCard respeitam alvos >= 48dp e TextScaler 1.8 em 320dp e 1280dp',
        (tester) async {
      final ts = ThemeService();
      await ts.setThemeStyle(AppThemeStyle.ascii);

      for (final size in const [Size(320, 640), Size(1280, 800)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: ts.darkTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: Scaffold(
                body: Center(
                  child: KairosInteractiveCard(
                    onTap: () {},
                    child: GlassSurface(
                      onTap: () {},
                      padding: const EdgeInsets.all(16),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_stories_rounded),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Espírito de Profecia',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      addTearDown(tester.view.resetPhysicalSize);
      await ts.setThemeStyle(AppThemeStyle.materialYou);
    });
  });
}
