import 'package:flutter/material.dart';
import 'core/database/database_manager.dart';
import 'services/auth_service.dart';
import 'services/content_manager.dart';
import 'services/theme_service.dart';
import 'views/navigation/main_navigation_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização assíncrona em background (lazy/non-blocking)
  DatabaseManager().initialize();
  AuthService().init();
  ContentManager().init();
  ThemeService().init();

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
          home: const MainNavigationView(),
        );
      },
    );
  }
}

