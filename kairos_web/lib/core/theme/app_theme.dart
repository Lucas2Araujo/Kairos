import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121212),
      primaryColor: const Color(0xFF4CAF50),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4CAF50),
        secondary: Color(0xFF81C784),
        surface: Color(0xFF1E1E1E),
      ),
      fontFamily: AppConstants.fontAppSans,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      primaryColor: const Color(0xFF2E7D32),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2E7D32),
        secondary: Color(0xFF388E3C),
        surface: Colors.white,
      ),
      fontFamily: AppConstants.fontAppSans,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
