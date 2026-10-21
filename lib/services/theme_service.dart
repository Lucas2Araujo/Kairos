import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppVisualTheme { system, light, dark, amoled, sepia }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    init();
  }

  static const PageTransitionsTheme _cupertinoTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    },
  );

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
  bool _isSepia = false;
  String _fontFamily = 'AppSans';
  double _fontSizeMultiplier = 1.0;
  TextAlign _bibleTextAlign = TextAlign.left;
  TextAlign _hymnTextAlign = TextAlign.center;
  bool _isContinuousReading = false;
  String _defaultDevotionalCategory = 'jovem';
  String _defaultSabbathSchoolCategory = 'adultos';

  ThemeMode get themeMode => _themeMode;
  String get colorKey => _colorKey;
  bool get isAmoled => _isAmoled;
  bool get isSepia => _isSepia;
  String get fontFamily => _fontFamily;
  double get fontSizeMultiplier => _fontSizeMultiplier;
  TextAlign get bibleTextAlign => _bibleTextAlign;
  TextAlign get hymnTextAlign => _hymnTextAlign;
  bool get isContinuousReading => _isContinuousReading;
  String get defaultDevotionalCategory => _defaultDevotionalCategory;
  String get defaultSabbathSchoolCategory => _defaultSabbathSchoolCategory;
  Color get currentColor => colorSeeds[_colorKey] ?? const Color(0xFF006D5B);

  String get activeThemePreset {
    if (_isSepia) return 'sepia';
    if (_isAmoled && _themeMode == ThemeMode.dark) return 'amoled';
    switch (_themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode && !_isSepia) return;
    _themeMode = mode;
    _isSepia = false;
    if (mode != ThemeMode.dark) _isAmoled = false;
    _savePrefs();
    notifyListeners();
  }

  void setSepia(bool sepia) {
    if (_isSepia == sepia) return;
    _isSepia = sepia;
    if (sepia) {
      _isAmoled = false;
      _themeMode = ThemeMode.light;
    }
    _savePrefs();
    notifyListeners();
  }

  void setAmoled(bool amoled) {
    if (_isAmoled == amoled) return;
    _isAmoled = amoled;
    if (amoled) {
      _isSepia = false;
      _themeMode = ThemeMode.dark;
    }
    _savePrefs();
    notifyListeners();
  }

  void setThemePreset(String preset) {
    switch (preset) {
      case 'sepia':
        setSepia(true);
        break;
      case 'amoled':
        setAmoled(true);
        break;
      case 'light':
        setThemeMode(ThemeMode.light);
        break;
      case 'dark':
        setThemeMode(ThemeMode.dark);
        break;
      case 'system':
      default:
        setThemeMode(ThemeMode.system);
        break;
    }
  }

  void setColorSeed(String key) {
    if (!colorSeeds.containsKey(key) || _colorKey == key) return;
    _colorKey = key;
    _savePrefs();
    notifyListeners();
  }

  void setFontFamily(String font) {
    if (_fontFamily == font) return;
    _fontFamily = font;
    _savePrefs();
    notifyListeners();
  }

  void setFontSizeMultiplier(double multiplier) {
    if (_fontSizeMultiplier == multiplier) return;
    _fontSizeMultiplier = multiplier.clamp(0.8, 1.6);
    _savePrefs();
    notifyListeners();
  }

  void setBibleTextAlign(TextAlign align) {
    if (_bibleTextAlign == align) return;
    _bibleTextAlign = align;
    _savePrefs();
    notifyListeners();
  }

  void setHymnTextAlign(TextAlign align) {
    if (_hymnTextAlign == align) return;
    _hymnTextAlign = align;
    _savePrefs();
    notifyListeners();
  }

  void setContinuousReading(bool continuous) {
    if (_isContinuousReading == continuous) return;
    _isContinuousReading = continuous;
    _savePrefs();
    notifyListeners();
  }

  void setDefaultDevotionalCategory(String category) {
    if (!const {'diario', 'jovem', 'mulher'}.contains(category)) return;
    if (_defaultDevotionalCategory == category) return;
    _defaultDevotionalCategory = category;
    _savePrefs();
    notifyListeners();
  }

  void setDefaultSabbathSchoolCategory(String category) {
    if (!const {'adultos', 'jovens'}.contains(category)) return;
    if (_defaultSabbathSchoolCategory == category) return;
    _defaultSabbathSchoolCategory = category;
    _savePrefs();
    notifyListeners();
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString('theme_mode');
      if (modeStr != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => ThemeMode.system,
        );
      }
      _isAmoled = prefs.getBool('is_amoled') ?? _isAmoled;
      _isSepia = prefs.getBool('is_sepia') ?? _isSepia;
      _colorKey = prefs.getString('color_key') ?? _colorKey;
      _fontFamily = prefs.getString('font_family') ?? _fontFamily;
      _fontSizeMultiplier = prefs.getDouble('font_size_multiplier') ?? _fontSizeMultiplier;
      final alignStr = prefs.getString('bible_text_align');
      if (alignStr != null) {
        _bibleTextAlign = TextAlign.values.firstWhere(
          (a) => a.name == alignStr,
          orElse: () => TextAlign.left,
        );
      }
      final hymnAlignStr = prefs.getString('hymn_text_align');
      if (hymnAlignStr != null) {
        _hymnTextAlign = TextAlign.values.firstWhere(
          (a) => a.name == hymnAlignStr,
          orElse: () => TextAlign.center,
        );
      }
      _isContinuousReading = prefs.getBool('is_continuous_reading') ?? _isContinuousReading;
      _defaultDevotionalCategory = prefs.getString('default_devo_category') ?? _defaultDevotionalCategory;
      _defaultSabbathSchoolCategory = prefs.getString('default_ss_category') ?? _defaultSabbathSchoolCategory;
      notifyListeners();
    } catch (e) {
      debugPrint('ThemeService init error: $e');
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', _themeMode.name);
      await prefs.setBool('is_amoled', _isAmoled);
      await prefs.setBool('is_sepia', _isSepia);
      await prefs.setString('color_key', _colorKey);
      await prefs.setString('font_family', _fontFamily);
      await prefs.setDouble('font_size_multiplier', _fontSizeMultiplier);
      await prefs.setString('bible_text_align', _bibleTextAlign.name);
      await prefs.setString('hymn_text_align', _hymnTextAlign.name);
      await prefs.setBool('is_continuous_reading', _isContinuousReading);
      await prefs.setString('default_devo_category', _defaultDevotionalCategory);
      await prefs.setString('default_ss_category', _defaultSabbathSchoolCategory);
    } catch (e) {
      debugPrint('ThemeService save error: $e');
    }
  }

  ThemeData get sepiaTheme {
    const bg = Color(0xFFF5ECD7);
    const surface = Color(0xFFEFE2C6);
    const text = Color(0xFF2C1E14);
    const primary = Color(0xFF8B5A2B);

    const scheme = ColorScheme.light(
      primary: primary,
      onPrimary: Colors.white,
      secondary: primary,
      surface: surface,
      onSurface: text,
      surfaceContainer: surface,
      surfaceContainerHighest: surface,
    );

    final sepiaTextTheme = ThemeData.light().textTheme.apply(
      bodyColor: text,
      displayColor: text,
      fontFamily: _fontFamily,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      colorScheme: scheme,
      pageTransitionsTheme: _cupertinoTransitions,
      scaffoldBackgroundColor: bg,
      textTheme: sepiaTextTheme,
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
      ),
    );
  }

  ThemeData get lightTheme {
    if (_isSepia) return sepiaTheme;

    final scheme = ColorScheme.fromSeed(
      seedColor: currentColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      colorScheme: scheme,
      pageTransitionsTheme: _cupertinoTransitions,
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
        pageTransitionsTheme: _cupertinoTransitions,
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
      pageTransitionsTheme: _cupertinoTransitions,
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
