import 'package:flutter/material.dart';
import 'core/database/database_manager.dart';
import 'services/theme_service.dart';
import 'views/navigation/main_navigation_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialização assíncrona do runtime Wasm SQLite e IndexedDB
  await DatabaseManager().initialize();

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
          debugShowCheckedModeBanner: false,
          home: const MainNavigationView(),
        );
      },
    );
  }
}

