import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/hymns/widgets/hymn_audio_player_widget.dart';
import 'package:kairos_web/views/onboarding/welcome_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HymnAudioPlayerWidget and AudioService UI Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('HymnAudioPlayerWidget displays hymn number, title and player controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HymnAudioPlayerWidget(
              numero: '001',
              titulo: 'Santo, Santo, Santo',
              hymnId: 1,
            ),
          ),
        ),
      );

      expect(find.text('Hino 001 - Santo, Santo, Santo'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Áudio Oficial'), findsOneWidget);
    });

    testWidgets('HymnAudioPlayerWidget extracts hymnId from numero if hymnId is omitted', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HymnAudioPlayerWidget(
              numero: '456B',
              titulo: 'Com Fé em Deus',
            ),
          ),
        ),
      );

      expect(find.text('Hino 456B - Com Fé em Deus'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);
    });
  });

  group('WelcomeDialog Onboarding Test', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('WelcomeDialog opens, navigates through 3 pages, and completes onboarding', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => WelcomeDialog.show(context, force: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Page 1: Welcome
      expect(find.text('Bem-vindo ao Kairós'), findsOneWidget);
      expect(find.text('Bíblia Sagrada'), findsOneWidget);
      expect(find.text('Hinário Adventista'), findsOneWidget);
      expect(find.text('Meditações Diárias'), findsOneWidget);
      expect(find.text('Escola Sabatina'), findsOneWidget);

      // Advance to Page 2
      await tester.tap(find.text('Avançar'));
      await tester.pumpAndSettle();

      // Page 2: Themes
      expect(find.text('Personalize sua Experiência'), findsOneWidget);
      expect(find.text('Material You'), findsOneWidget);
      expect(find.text('Liquid Glass'), findsOneWidget);
      expect(find.text('Apple Glass'), findsOneWidget);
      expect(find.text('Livro Clássico'), findsOneWidget);

      // Select Liquid Glass theme
      final themeService = ThemeService();
      await tester.tap(find.text('Liquid Glass'));
      await tester.pumpAndSettle();
      expect(themeService.themeStyle, AppThemeStyle.liquidGlass);

      // Select Classic Book theme
      await tester.tap(find.text('Livro Clássico'));
      await tester.pumpAndSettle();
      expect(themeService.themeStyle, AppThemeStyle.classicBook);

      // Advance to Page 3 (Tempo com Deus)
      await tester.tap(find.text('Avançar'));
      await tester.pumpAndSettle();

      expect(find.text('Tempo com Deus'), findsOneWidget);
      expect(find.text('15 minutos (Recomendado)'), findsOneWidget);

      // Advance to Page 4 (Pronto para Começar)
      await tester.tap(find.text('Avançar'));
      await tester.pumpAndSettle();

      // Page 4: Ready
      expect(find.text('Pronto para Começar'), findsOneWidget);
      expect(find.text('Conectar com Conta Google'), findsOneWidget);
      expect(find.text('Começar a Usar o Kairós'), findsOneWidget);

      // Complete Onboarding
      await tester.tap(find.text('Começar a Usar o Kairós'));
      await tester.pumpAndSettle();

      // Verify dialog is closed and preference is stored
      expect(find.text('Pronto para Começar'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('WelcomeDialog.show honors force=false when already completed', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => WelcomeDialog.show(context, force: false),
                child: const Text('Check'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      // Dialog should NOT be shown
      expect(find.text('Bem-vindo ao Kairós'), findsNothing);
    });
  });
}
