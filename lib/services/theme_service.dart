import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

export '../core/theme/app_theme.dart';

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
    'emerald': Color(0xFF006D5B),
    'purple': Color(0xFF6750A4),
    'gold': Color(0xFFC67D00),
    'sapphire': Color(0xFF006399),
    'lavender': Color(0xFF79558E),
    'peach': Color(0xFFB85D43),
    'rose': Color(0xFF9C4D6E),
  };

  static const Map<String, String> colorSeedNames = {
    'emerald': 'Esmeralda',
    'purple': 'Violeta',
    'gold': 'Dourado',
    'sapphire': 'Safira',
    'lavender': 'Lavanda',
    'peach': 'Pêssego',
    'rose': 'Rosa Suave',
  };

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeStyle _themeStyle = AppThemeStyle.materialYou;
  bool _glassBlurEnabled = true;
  String _currentEdition = 'novo';
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
  AppThemeStyle get themeStyle => _themeStyle;
  bool get isLiquidGlass => _themeStyle == AppThemeStyle.liquidGlass;
  bool get isClassicBook => _themeStyle == AppThemeStyle.classicBook || _isSepia;
  bool get glassBlurEnabled => _glassBlurEnabled;
  String get currentEdition => _currentEdition;
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
    if (_themeStyle == AppThemeStyle.liquidGlass) return 'glass';
    if (_isSepia || _themeStyle == AppThemeStyle.classicBook) return 'sepia';
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

  void setThemeStyle(AppThemeStyle style) {
    if (_themeStyle == style) return;
    _themeStyle = style;
    if (style == AppThemeStyle.classicBook) {
      _isSepia = false;
      _isAmoled = false;
    } else {
      _isSepia = false;
    }
    _savePrefs();
    notifyListeners();
  }

  void setGlassBlurEnabled(bool enabled) {
    if (_glassBlurEnabled == enabled) return;
    _glassBlurEnabled = enabled;
    _savePrefs();
    notifyListeners();
  }

  void setEdition(String edition) {
    if (_currentEdition == edition) return;
    _currentEdition = edition;
    _savePrefs();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode && !_isSepia && _themeStyle != AppThemeStyle.classicBook) return;
    _themeMode = mode;
    _isSepia = false;
    if (_themeStyle == AppThemeStyle.classicBook) {
      _themeStyle = AppThemeStyle.materialYou;
    }
    if (mode != ThemeMode.dark) _isAmoled = false;
    _savePrefs();
    notifyListeners();
  }

  void setSepia(bool sepia) {
    if (_isSepia == sepia) return;
    _isSepia = sepia;
    if (sepia) {
      _themeStyle = AppThemeStyle.classicBook;
      _isAmoled = false;
      _themeMode = ThemeMode.light;
    } else if (_themeStyle == AppThemeStyle.classicBook) {
      _themeStyle = AppThemeStyle.materialYou;
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
      case 'glass':
      case 'liquid_glass':
        _isSepia = false;
        _isAmoled = false;
        _themeStyle = AppThemeStyle.liquidGlass;
        _savePrefs();
        notifyListeners();
        break;
      case 'sepia':
      case 'classic':
      case 'classic_book':
        _themeStyle = AppThemeStyle.classicBook;
        setSepia(true);
        break;
      case 'amoled':
        _themeStyle = AppThemeStyle.materialYou;
        setAmoled(true);
        break;
      case 'light':
        _themeStyle = AppThemeStyle.materialYou;
        setThemeMode(ThemeMode.light);
        break;
      case 'dark':
        _themeStyle = AppThemeStyle.materialYou;
        setThemeMode(ThemeMode.dark);
        break;
      case 'system':
      default:
        _themeStyle = AppThemeStyle.materialYou;
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

  KairosPalette getPalette({required bool isDark}) {
    if (_currentEdition == 'antigo' && _themeStyle == AppThemeStyle.materialYou) {
      return isDark ? KairosPalette.antigoDark : KairosPalette.antigoLight;
    }
    switch (_themeStyle) {
      case AppThemeStyle.liquidGlass:
        return isDark ? KairosPalette.liquidGlassDark : KairosPalette.liquidGlassLight;
      case AppThemeStyle.classicBook:
        return isDark ? KairosPalette.classicBookDark : KairosPalette.classicBookLight;
      case AppThemeStyle.materialYou:
        return isDark ? KairosPalette.materialYouDark : KairosPalette.materialYouLight;
    }
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
      final styleStr = prefs.getString('theme_style');
      if (styleStr != null) {
        _themeStyle = AppThemeStyle.values.firstWhere(
          (s) => s.name == styleStr,
          orElse: () => AppThemeStyle.materialYou,
        );
      }
      _glassBlurEnabled = prefs.getBool('glass_blur_enabled') ?? _glassBlurEnabled;
      _currentEdition = prefs.getString('current_edition') ?? _currentEdition;
      _isAmoled = prefs.getBool('is_amoled') ?? _isAmoled;
      _isSepia = prefs.getBool('is_sepia') ?? _isSepia;
      if (_isSepia) {
        _themeStyle = AppThemeStyle.classicBook;
      }
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
      await prefs.setString('theme_style', _themeStyle.name);
      await prefs.setBool('glass_blur_enabled', _glassBlurEnabled);
      await prefs.setString('current_edition', _currentEdition);
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

    if (_themeStyle == AppThemeStyle.liquidGlass) {
      const palette = KairosPalette.liquidGlassLight;
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.light,
        surface: const Color(0xD1FFFFFF),
        primary: palette.primary,
        onPrimary: palette.onPrimary,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.light,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xB8F8FAFC),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xD1FFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xB8F8FAFC),
          indicatorColor: currentColor.withValues(alpha: 0.15),
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xB8F8FAFC),
          indicatorColor: currentColor.withValues(alpha: 0.15),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xD9FFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xD9FFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.75),
              width: 1.2,
            ),
          ),
        ),
      );
    }

    if (_themeStyle == AppThemeStyle.classicBook) {
      const palette = KairosPalette.classicBookLight;
      final scheme = ColorScheme.light(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainer: palette.surfaceContainer,
        surfaceContainerHigh: palette.surfaceContainerHigh,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.light,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: palette.background,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
          fontFamily: _fontFamily,
        ),
        cardTheme: CardThemeData(
          color: palette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.borderColor, width: 1.0),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          elevation: 0,
        ),
      );
    }

    if (_currentEdition == 'antigo' && _themeStyle == AppThemeStyle.materialYou) {
      const palette = KairosPalette.antigoLight;
      final scheme = ColorScheme.light(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainer: palette.surfaceContainer,
        surfaceContainerHigh: palette.surfaceContainerHigh,
        outline: palette.borderColor,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.light,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: palette.background,
        cardTheme: CardThemeData(
          color: palette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: palette.borderColor, width: 1.0),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          elevation: 0,
        ),
      );
    }

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
    if (_themeStyle == AppThemeStyle.liquidGlass) {
      const palette = KairosPalette.liquidGlassDark;
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.dark,
        surface: const Color(0xBF1E293B),
        primary: palette.primary,
        onPrimary: palette.onPrimary,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xAA0B1220),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xBF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xAA0B1220),
          indicatorColor: currentColor.withValues(alpha: 0.25),
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xAA0B1220),
          indicatorColor: currentColor.withValues(alpha: 0.25),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xCC1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xCC1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
        ),
      );
    }

    if (_isAmoled) {
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.dark,
      ).copyWith(
        surface: Colors.black,
        surfaceContainer: const Color(0xFF0D0D0D),
        surfaceContainerHigh: const Color(0xFF141414),
        surfaceContainerHighest: const Color(0xFF1E1E1E),
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
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

    if (_themeStyle == AppThemeStyle.classicBook) {
      const palette = KairosPalette.classicBookDark;
      final scheme = ColorScheme.dark(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainer: palette.surfaceContainer,
        surfaceContainerHigh: palette.surfaceContainerHigh,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: palette.background,
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: palette.textPrimary,
          displayColor: palette.textPrimary,
          fontFamily: _fontFamily,
        ),
        cardTheme: CardThemeData(
          color: palette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.borderColor, width: 1.0),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          elevation: 0,
        ),
      );
    }

    if (_currentEdition == 'antigo' && _themeStyle == AppThemeStyle.materialYou) {
      const palette = KairosPalette.antigoDark;
      final scheme = ColorScheme.dark(
        primary: palette.primary,
        onPrimary: palette.onPrimary,
        secondary: palette.primary,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        surfaceContainer: palette.surfaceContainer,
        surfaceContainerHigh: palette.surfaceContainerHigh,
        outline: palette.borderColor,
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
        pageTransitionsTheme: _cupertinoTransitions,
        scaffoldBackgroundColor: palette.background,
        cardTheme: CardThemeData(
          color: palette.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: palette.borderColor, width: 1.0),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palette.surface,
          foregroundColor: palette.textPrimary,
          elevation: 0,
        ),
      );
    }

    final scheme = ColorScheme.fromSeed(
      seedColor: currentColor,
      brightness: Brightness.dark,
    );
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
