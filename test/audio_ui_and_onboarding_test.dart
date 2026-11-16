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

      // Tela cheia de boas-vindas
      expect(find.text('Bem-vindo ao Kairós'), findsOneWidget);
      expect(find.text('Guia Rápido (Principais telas)'), findsOneWidget);
      expect(find.text('Guia Detalhado (Funções específicas)'), findsOneWidget);
      expect(find.text('Pular introdução'), findsOneWidget);

      // Pular introdução conclui o onboarding
      await tester.tap(find.text('Pular introdução'));
      await tester.pumpAndSettle();

      // Verify screen is closed and preference is stored
      expect(find.text('Bem-vindo ao Kairós'), findsNothing);
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
