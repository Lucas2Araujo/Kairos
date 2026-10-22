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

    testWidgets('renders icon, title with ShaderMask and subtitle with FadeTransition', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashView(
            minDuration: Duration(milliseconds: 100),
          ),
        ),
      );

      // Verify Auto Stories Icon with size 64
      final iconFinder = find.byIcon(Icons.auto_stories);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.size, 64);

      // Verify "Kairós" text with bold and letterSpacing 4.0
      final titleFinder = find.text('Kairós');
      expect(titleFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.fontWeight, FontWeight.bold);
      expect(textWidget.style?.letterSpacing, 4.0);

      // Verify ShaderMask exists for the shimmer effect
      expect(find.byType(ShaderMask), findsOneWidget);

      // Verify Subtitle text
      expect(find.text('Adoração, Comunhão e Estudo'), findsOneWidget);

      // Verify FadeTransition exists for the subtitle
      expect(find.byType(FadeTransition), findsWidgets);

      // Advance animation slightly to verify shimmer tickers
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
