import 'package:flutter/material.dart';
import 'services/theme_service.dart';
import 'views/splash/splash_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeService().init();
  runApp(const KairosWebApp());
}

class KairosWebApp extends StatelessWidget {
  const KairosWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Kairós',
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.themeMode,
          themeAnimationDuration: const Duration(milliseconds: 250),
          themeAnimationCurve: Curves.easeOutCubic,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                themeService.effectiveUiScale(MediaQuery.sizeOf(context).width),
              ),
            ),
            child: GlobalThemeBackgroundShell(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const SplashView(),
        );
      },
    );
  }
}
