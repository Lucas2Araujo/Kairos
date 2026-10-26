import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/views/splash/splash_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashView Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders morphing CustomPaint, title and subtitle with animation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashView(
            minDuration: Duration(milliseconds: 100),
          ),
        ),
      );

      // Verify CustomPaint exists for the morphing animation
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify "Kairós" text with bold/w800
      final titleFinder = find.text('Kairós');
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.fontWeight, FontWeight.w800);
      expect(textWidget.style?.letterSpacing, -1.0);

      // Verify Subtitle text
      final subtitleFinder = find.text('Adoração, Comunhão e Estudo');
      expect(subtitleFinder, findsOneWidget);
      final subtitleWidget = tester.widget<Text>(subtitleFinder);
      expect(subtitleWidget.style?.fontWeight, FontWeight.w500);

      // Advance animation slightly to verify tickers
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Kairós'), findsOneWidget);

      // Let timer expire and finish
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('transitions via FadeTransition to target destination after bootstrap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashView(
            minDuration: const Duration(milliseconds: 50),
            homeBuilder: () => const Scaffold(body: Text('TargetDestinationView')),
          ),
        ),
      );

      expect(find.byType(SplashView), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('TargetDestinationView'), findsOneWidget);
      expect(find.byType(FadeTransition), findsWidgets);
    });
  });
}
