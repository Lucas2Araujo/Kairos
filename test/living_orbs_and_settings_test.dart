import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Living Orbs & Settings Tests', () {
    test('ThemeService defaults and persistence for glassAnimationEnabled and glassInteractiveEnabled', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('glass_animation_enabled', false);
      await prefs.setBool('glass_interactive_enabled', true);

      final service = ThemeService();
      await service.init();

      expect(service.glassAnimationEnabled, isFalse);
      expect(service.glassInteractiveEnabled, isTrue);

      var notified = false;
      service.addListener(() {
        notified = true;
      });

      await service.setGlassAnimationEnabled(true);
      expect(service.glassAnimationEnabled, isTrue);
      expect(notified, isTrue);

      notified = false;
      await service.setGlassInteractiveEnabled(false);
      expect(service.glassInteractiveEnabled, isFalse);
      expect(notified, isTrue);

      expect(prefs.getBool('glass_animation_enabled'), isTrue);
      expect(prefs.getBool('glass_interactive_enabled'), isFalse);
    });

    testWidgets('GlobalThemeBackgroundShell renders and responds to pointer events', (tester) async {
      final service = ThemeService();
      service.setThemeStyle(AppThemeStyle.appleGlass);
      await service.setGlassAnimationEnabled(true);
      await service.setGlassInteractiveEnabled(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalThemeBackgroundShell(
            child: Scaffold(
              body: Center(child: Text('Shell Active')),
            ),
          ),
        ),
      );

      expect(find.text('Shell Active'), findsOneWidget);

      // Advance animation timer
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));

      // Simulate pointer hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(100, 100));
      await tester.pump();
      await gesture.moveTo(const Offset(300, 400));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.removePointer();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Shell Active'), findsOneWidget);
    });

    testWidgets('GlobalThemeBackgroundShell renders statically when glassAnimationEnabled is false', (tester) async {
      final service = ThemeService();
      service.setThemeStyle(AppThemeStyle.appleGlass);
      await service.setGlassAnimationEnabled(false);
      await service.setGlassInteractiveEnabled(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalThemeBackgroundShell(
            child: Scaffold(
              body: Center(child: Text('Static Shell')),
            ),
          ),
        ),
      );

      expect(find.text('Static Shell'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Static Shell'), findsOneWidget);
    });

    testWidgets('SettingsDialog exposes orb animation and interactivity switches', (tester) async {
      final service = ThemeService();
      service.setThemeStyle(AppThemeStyle.appleGlass);
      await service.setGlassAnimationEnabled(true);
      await service.setGlassInteractiveEnabled(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showDialog(
                  context: ctx,
                  builder: (_) => const SettingsDialog(),
                ),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Animação dos Orbes (Aurora)'), findsOneWidget);
      expect(find.text('Orbes Interativos (Toque/Mouse)'), findsOneWidget);

      // Toggle interactivity switch
      final interactiveSwitch = find.ancestor(
        of: find.text('Orbes Interativos (Toque/Mouse)'),
        matching: find.byType(SwitchListTile),
      );
      expect(interactiveSwitch, findsOneWidget);

      await tester.ensureVisible(interactiveSwitch);
      await tester.pumpAndSettle();
      await tester.tap(interactiveSwitch);
      await tester.pumpAndSettle();

      expect(service.glassInteractiveEnabled, isTrue);
    });
  });
}
