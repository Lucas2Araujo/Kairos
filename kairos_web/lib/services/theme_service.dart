import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Color Seeds Material 3
  static const Map<String, Color> colorSeeds = {
    'emerald': Color(0xFF006D5B), // Verde Bíblico
    'purple': Color(0xFF6750A4),  // Violeta M3
    'gold': Color(0xFFC67D00),    // Dourado Sacro
    'sapphire': Color(0xFF006399),// Azul Safira
    'rose': Color(0xFF9C4D6E),    // Rosa Suave
  };

  ThemeMode _themeMode = ThemeMode.system;
  String _colorKey = 'emerald';
  bool _isAmoled = false;
  String _fontFamily = 'AppSans';
  double _fontSizeMultiplier = 1.0;

  ThemeMode get themeMode => _themeMode;
  String get colorKey => _colorKey;
  bool get isAmoled => _isAmoled;
  String get fontFamily => _fontFamily;
  double get fontSizeMultiplier => _fontSizeMultiplier;
  Color get currentColor => colorSeeds[_colorKey] ?? const Color(0xFF006D5B);

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setColorSeed(String key) {
    if (!colorSeeds.containsKey(key) || _colorKey == key) return;
    _colorKey = key;
    notifyListeners();
  }

  void setAmoled(bool amoled) {
    if (_isAmoled == amoled) return;
    _isAmoled = amoled;
    notifyListeners();
  }

  void setFontFamily(String font) {
    if (_fontFamily == font) return;
    _fontFamily = font;
    notifyListeners();
  }

  void setFontSizeMultiplier(double multiplier) {
    if (_fontSizeMultiplier == multiplier) return;
    _fontSizeMultiplier = multiplier.clamp(0.8, 1.6);
    notifyListeners();
  }

  ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: currentColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      cardTheme: CardThemeData(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }

  ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: currentColor,
      brightness: Brightness.dark,
    );

    if (_isAmoled) {
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme.copyWith(
          surface: Colors.black,
          surfaceContainer: const Color(0xFF0D0D0D),
          surfaceContainerHigh: const Color(0xFF141414),
          surfaceContainerHighest: const Color(0xFF1E1E1E),
        ),
        scaffoldBackgroundColor: Colors.black,
        cardTheme: CardThemeData(
          color: const Color(0xFF0D0D0D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF222222), width: 1),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      );
    }

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
