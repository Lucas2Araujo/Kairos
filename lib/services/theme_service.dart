import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

export '../core/theme/app_theme.dart';

enum AppVisualTheme { system, light, dark, amoled, sepia }
enum BibleReadingMode { verseByVerse, continuous, immersive }
enum HomeSearchPlacement { capsuleBody, topBarIcon, none }

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal() {
    init();
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

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

  static const PageTransitionsTheme _glassTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: GlassFadeSlideTransitionsBuilder(),
      TargetPlatform.iOS: GlassFadeSlideTransitionsBuilder(),
      TargetPlatform.linux: GlassFadeSlideTransitionsBuilder(),
      TargetPlatform.macOS: GlassFadeSlideTransitionsBuilder(),
      TargetPlatform.windows: GlassFadeSlideTransitionsBuilder(),
      TargetPlatform.fuchsia: GlassFadeSlideTransitionsBuilder(),
    },
  );

  // Color Seeds Material 3
  static const Map<String, Color> colorSeeds = {
    'emerald': Color(0xFF006D5B),
    'purple': Color(0xFF6750A4),
    'gold': Color(0xFFC67D00),
    'sapphire': Color(0xFF006399),
    'peach': Color(0xFFB85D43),
    'rose': Color(0xFF9C4D6E),
  };

  static const Map<String, String> colorSeedNames = {
    'emerald': 'Esmeralda',
    'purple': 'Violeta',
    'gold': 'Dourado',
    'sapphire': 'Safira',
    'peach': 'Pêssego',
    'rose': 'Rosa Suave',
  };

  int? _customColorValue; // Armazena a cor customizada do usuário

  // Getter inteligente: se for 'custom', usa a cor selecionada
  Color get currentColor {
    if (_colorKey == 'custom' && _customColorValue != null) {
      return Color(_customColorValue!);
    }
    return colorSeeds[_colorKey] ?? const Color(0xFF6750A4);
  }

  Future<void> setCustomColor(Color color) async {
    _colorKey = 'custom';
    _customColorValue = color.toARGB32();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setColorSeed(String key) async {
    if (!colorSeeds.containsKey(key)) return;
    if (_colorKey == key && _customColorValue == null) return;
    _colorKey = key;
    _customColorValue = null;
    await _savePrefs();
    notifyListeners();
  }

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeStyle _themeStyle = AppThemeStyle.materialYou;
  bool _glassBlurEnabled = true;
  bool _glassAnimationEnabled = true;
  bool _glassInteractiveEnabled = false;
  String _currentEdition = 'novo';
  String _colorKey = 'emerald';
  bool _isAmoled = false;
  bool _isSepia = false;
  double _uiScaleMultiplier = 1.0;
  bool _autoTabletScaling = true;
  String _fontFamily = 'AppSans';
  double _fontSizeMultiplier = 1.0;
  TextAlign _bibleTextAlign = TextAlign.left;
  TextAlign _hymnTextAlign = TextAlign.center;
  BibleReadingMode _readingMode = BibleReadingMode.verseByVerse;
  String _defaultDevotionalCategory = 'jovem';
  String _defaultSabbathSchoolCategory = 'adultos';
  String _splashSpeedMode = 'normal'; // 'rapido' (1500ms), 'normal' (2800ms), 'estendido' (4000ms)

  ThemeMode get themeMode => _themeMode;
  AppThemeStyle get themeStyle => _themeStyle;
  bool get isLiquidGlass => _themeStyle == AppThemeStyle.liquidGlass;
  bool get isAppleGlass => _themeStyle == AppThemeStyle.appleGlass;
  bool get isAnyGlass => isLiquidGlass || isAppleGlass;
  bool get isClassicBook => _themeStyle == AppThemeStyle.classicBook || _isSepia;
  bool get glassBlurEnabled => _glassBlurEnabled;
  bool get glassAnimationEnabled => _glassAnimationEnabled;
  bool get glassInteractiveEnabled => _glassInteractiveEnabled;
  String get currentEdition => _currentEdition;
  String get colorKey => _colorKey;
  bool get isAmoled => _isAmoled;
  bool get isSepia => _isSepia;
  double get uiScaleMultiplier => _uiScaleMultiplier;
  bool get autoTabletScaling => _autoTabletScaling;
  String get fontFamily => _fontFamily;
  double get fontSizeMultiplier => _fontSizeMultiplier;
  TextAlign get bibleTextAlign => _bibleTextAlign;
  TextAlign get hymnTextAlign => _hymnTextAlign;
  BibleReadingMode get readingMode => _readingMode;
  bool get isContinuousReading => _readingMode == BibleReadingMode.continuous;
  bool get isImmersiveReading => _readingMode == BibleReadingMode.immersive;
  String get defaultDevotionalCategory => _defaultDevotionalCategory;
  String get defaultSabbathSchoolCategory => _defaultSabbathSchoolCategory;
  String get splashSpeedMode => _splashSpeedMode;
  int get splashDurationMs {
    switch (_splashSpeedMode) {
      case 'rapido':
        return 1500;
      case 'estendido':
        return 4000;
      case 'normal':
      default:
        return 2800;
    }
  }

  void setSplashSpeedMode(String mode) {
    if (!const {'rapido', 'normal', 'estendido'}.contains(mode)) return;
    if (_splashSpeedMode == mode) return;
    _splashSpeedMode = mode;
    _savePrefs();
    notifyListeners();
  }

  String get activeThemePreset {
    if (_themeStyle == AppThemeStyle.liquidGlass) return 'liquid_glass';
    if (_themeStyle == AppThemeStyle.appleGlass) return 'apple_glass';
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

  Future<void> setThemeStyle(AppThemeStyle style) async {
    if (_themeStyle == style) return;
    _themeStyle = style;
    if (style == AppThemeStyle.classicBook) {
      _isSepia = false;
      _isAmoled = false;
    } else {
      _isSepia = false;
    }
    await _savePrefs();
    notifyListeners();
  }

  void setGlassBlurEnabled(bool enabled) {
    if (_glassBlurEnabled == enabled) return;
    _glassBlurEnabled = enabled;
    _savePrefs();
    notifyListeners();
  }

  Future<void> setGlassAnimationEnabled(bool value) async {
    if (_glassAnimationEnabled == value) return;
    _glassAnimationEnabled = value;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setGlassInteractiveEnabled(bool value) async {
    if (_glassInteractiveEnabled == value) return;
    _glassInteractiveEnabled = value;
    await _savePrefs();
    notifyListeners();
  }

  void setEdition(String edition) {
    if (_currentEdition == edition) return;
    _currentEdition = edition;
    _savePrefs();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode && !_isSepia && _themeStyle != AppThemeStyle.classicBook) return;
    _themeMode = mode;
    _isSepia = false;
    if (_themeStyle == AppThemeStyle.classicBook) {
      _themeStyle = AppThemeStyle.materialYou;
    }
    if (mode != ThemeMode.dark) _isAmoled = false;
    await _savePrefs();
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
      case 'apple_glass':
      case 'apple':
        _isSepia = false;
        _isAmoled = false;
        _themeStyle = AppThemeStyle.appleGlass;
        _savePrefs();
        notifyListeners();
        break;
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

  double effectiveUiScale(double screenWidth) {
    if (_autoTabletScaling && screenWidth >= 600 && (_uiScaleMultiplier - 1.0).abs() < 0.01) {
      return 1.15;
    }
    return _uiScaleMultiplier;
  }

  void setUiScaleMultiplier(double val) {
    final clamped = val.clamp(0.85, 1.4);
    if (_uiScaleMultiplier == clamped) return;
    _uiScaleMultiplier = clamped;
    _savePrefs();
    notifyListeners();
  }

  void setAutoTabletScaling(bool val) {
    if (_autoTabletScaling == val) return;
    _autoTabletScaling = val;
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

  void setReadingMode(BibleReadingMode mode) {
    if (_readingMode == mode) return;
    _readingMode = mode;
    _savePrefs();
    notifyListeners();
  }

  void setContinuousReading(bool continuous) {
    setReadingMode(continuous ? BibleReadingMode.continuous : BibleReadingMode.verseByVerse);
  }

  Future<void> setDefaultDevotionalCategory(String category) async {
    final normalized = category == 'jovens' ? 'jovem' : category;
    if (!const {'diario', 'jovem', 'mulher'}.contains(normalized)) return;
    final changed = _defaultDevotionalCategory != normalized;
    _defaultDevotionalCategory = normalized;
    await _savePrefs();
    if (changed) notifyListeners();
  }

  Future<void> setDefaultSabbathSchoolCategory(String category) async {
    final normalized = category == 'jovem' ? 'jovens' : category;
    if (!const {'adultos', 'jovens'}.contains(normalized)) return;
    final changed = _defaultSabbathSchoolCategory != normalized;
    _defaultSabbathSchoolCategory = normalized;
    await _savePrefs();
    if (changed) notifyListeners();
  }

  HomeSearchPlacement _homeSearchPlacement = HomeSearchPlacement.capsuleBody;
  HomeSearchPlacement get homeSearchPlacement => _homeSearchPlacement;

  void setHomeSearchPlacement(HomeSearchPlacement placement) {
    if (_homeSearchPlacement == placement) return;
    _homeSearchPlacement = placement;
    _savePrefs();
    notifyListeners();
  }

  bool _sabbathSchoolExpandDaysByDefault = true;
  bool get sabbathSchoolExpandDaysByDefault => _sabbathSchoolExpandDaysByDefault;

  void setSabbathSchoolExpandDaysByDefault(bool expand) {
    if (_sabbathSchoolExpandDaysByDefault == expand) return;
    _sabbathSchoolExpandDaysByDefault = expand;
    _savePrefs();
    notifyListeners();
  }

  KairosPalette getPalette({required bool isDark}) {
    if (_currentEdition == 'antigo' && _themeStyle == AppThemeStyle.materialYou) {
      return isDark ? KairosPalette.antigoDark : KairosPalette.antigoLight;
    }
    switch (_themeStyle) {
      case AppThemeStyle.appleGlass:
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
        _isSepia = _themeStyle == AppThemeStyle.classicBook;
      } else {
        final legacySepia = prefs.getBool('is_sepia');
        if (legacySepia == true) {
          _themeStyle = AppThemeStyle.classicBook;
          _isSepia = true;
        }
      }
      _glassBlurEnabled = prefs.getBool('glass_blur_enabled') ?? _glassBlurEnabled;
      _glassAnimationEnabled = prefs.getBool('glass_animation_enabled') ?? _glassAnimationEnabled;
      _glassInteractiveEnabled = prefs.getBool('glass_interactive_enabled') ?? _glassInteractiveEnabled;
      _currentEdition = prefs.getString('current_edition') ?? _currentEdition;
      _isAmoled = prefs.getBool('is_amoled') ?? _isAmoled;
      _colorKey = prefs.getString('color_key') ?? _colorKey;
      _customColorValue = prefs.getInt('custom_color_val');
      _fontFamily = prefs.getString('font_family') ?? _fontFamily;
      _fontSizeMultiplier = prefs.getDouble('font_size_multiplier') ?? _fontSizeMultiplier;
      _uiScaleMultiplier = prefs.getDouble('ui_scale_multiplier') ?? _uiScaleMultiplier;
      _autoTabletScaling = prefs.getBool('auto_tablet_scaling') ?? _autoTabletScaling;
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
      final readingModeStr = prefs.getString('bible_reading_mode');
      if (readingModeStr != null) {
        _readingMode = BibleReadingMode.values.firstWhere(
          (m) => m.name == readingModeStr,
          orElse: () => BibleReadingMode.verseByVerse,
        );
      } else {
        final legacyContinuous = prefs.getBool('is_continuous_reading');
        if (legacyContinuous != null) {
          _readingMode = legacyContinuous ? BibleReadingMode.continuous : BibleReadingMode.verseByVerse;
        }
      }
      _defaultDevotionalCategory = prefs.getString('default_devo_category') ?? _defaultDevotionalCategory;
      _defaultSabbathSchoolCategory = prefs.getString('default_ss_category') ?? _defaultSabbathSchoolCategory;
      _splashSpeedMode = prefs.getString('splash_speed_mode') ?? _splashSpeedMode;
      final searchPlacementStr = prefs.getString('home_search_placement');
      if (searchPlacementStr != null) {
        _homeSearchPlacement = HomeSearchPlacement.values.firstWhere(
          (p) => p.name == searchPlacementStr,
          orElse: () => HomeSearchPlacement.capsuleBody,
        );
      }
      _sabbathSchoolExpandDaysByDefault = prefs.getBool('ss_expand_days_default') ?? _sabbathSchoolExpandDaysByDefault;
      _isInitialized = true;
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
      await prefs.setBool('glass_animation_enabled', _glassAnimationEnabled);
      await prefs.setBool('glass_interactive_enabled', _glassInteractiveEnabled);
      await prefs.setString('current_edition', _currentEdition);
      await prefs.setBool('is_amoled', _isAmoled);
      await prefs.setBool('is_sepia', _isSepia);
      await prefs.setString('color_key', _colorKey);
      if (_customColorValue != null) {
        await prefs.setInt('custom_color_val', _customColorValue!);
      } else {
        await prefs.remove('custom_color_val');
      }
      await prefs.setString('font_family', _fontFamily);
      await prefs.setDouble('font_size_multiplier', _fontSizeMultiplier);
      await prefs.setDouble('ui_scale_multiplier', _uiScaleMultiplier);
      await prefs.setBool('auto_tablet_scaling', _autoTabletScaling);
      await prefs.setString('bible_text_align', _bibleTextAlign.name);
      await prefs.setString('hymn_text_align', _hymnTextAlign.name);
      await prefs.setString('bible_reading_mode', _readingMode.name);
      await prefs.setBool('is_continuous_reading', isContinuousReading);
      await prefs.setString('default_devo_category', _defaultDevotionalCategory);
      await prefs.setString('default_ss_category', _defaultSabbathSchoolCategory);
      await prefs.setString('splash_speed_mode', _splashSpeedMode);
      await prefs.setString('home_search_placement', _homeSearchPlacement.name);
      await prefs.setBool('ss_expand_days_default', _sabbathSchoolExpandDaysByDefault);
    } catch (e) {
      debugPrint('ThemeService save error: $e');
    }
  }

  TextTheme _buildTextTheme(Brightness brightness, Color textColor) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return base.apply(
      fontFamily: _fontFamily,
      bodyColor: textColor,
      displayColor: textColor,
    );
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

    return ThemeData(
      useMaterial3: true,
      fontFamily: _fontFamily,
      brightness: Brightness.light,
      colorScheme: scheme,
      pageTransitionsTheme: _cupertinoTransitions,
      scaffoldBackgroundColor: bg,
      textTheme: _buildTextTheme(Brightness.light, text),
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
    if (_themeStyle == AppThemeStyle.appleGlass) {
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.light,
        surface: const Color(0xEBFFFFFF),
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.light,
        colorScheme: scheme,
        pageTransitionsTheme: _glassTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: _buildTextTheme(Brightness.light, const Color(0xFF0F172A)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xEBFFFFFF),
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xEBFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xEBFFFFFF),
          indicatorColor: currentColor.withValues(alpha: 0.15),
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xEBFFFFFF),
          indicatorColor: currentColor.withValues(alpha: 0.15),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xEBFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xEBFFFFFF),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
          ),
        ),
      );
    }
    if (_themeStyle == AppThemeStyle.liquidGlass) {
      const palette = KairosPalette.liquidGlassLight;
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.light,
        surface: const Color(0xD1FFFFFF),
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.light,
        colorScheme: scheme,
        pageTransitionsTheme: _glassTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: _buildTextTheme(Brightness.light, palette.textPrimary),
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
        textTheme: _buildTextTheme(Brightness.light, palette.textPrimary),
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
        textTheme: _buildTextTheme(Brightness.light, palette.textPrimary),
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
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _buildTextTheme(Brightness.light, scheme.onSurface),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }

  ThemeData get darkTheme {
    if (_themeStyle == AppThemeStyle.appleGlass) {
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.dark,
        surface: const Color(0xEB1E293B),
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
        pageTransitionsTheme: _glassTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: _buildTextTheme(Brightness.dark, const Color(0xFFF8FAFC)),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xEB1E293B),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xEB1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.2,
            ),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xEB1E293B),
          indicatorColor: currentColor.withValues(alpha: 0.25),
          elevation: 0,
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: const Color(0xEB1E293B),
          indicatorColor: currentColor.withValues(alpha: 0.25),
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xEB1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.2,
            ),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xEB1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.20),
              width: 1.2,
            ),
          ),
        ),
      );
    }
    if (_themeStyle == AppThemeStyle.liquidGlass) {
      const palette = KairosPalette.liquidGlassDark;
      final scheme = ColorScheme.fromSeed(
        seedColor: currentColor,
        brightness: Brightness.dark,
        surface: const Color(0xBF1E293B),
      );
      return ThemeData(
        useMaterial3: true,
        fontFamily: _fontFamily,
        brightness: Brightness.dark,
        colorScheme: scheme,
        pageTransitionsTheme: _glassTransitions,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: _buildTextTheme(Brightness.dark, palette.textPrimary),
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
        textTheme: _buildTextTheme(Brightness.dark, scheme.onSurface),
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
        textTheme: _buildTextTheme(Brightness.dark, palette.textPrimary),
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
        textTheme: _buildTextTheme(Brightness.dark, palette.textPrimary),
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
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _buildTextTheme(Brightness.dark, scheme.onSurface),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
    );
  }
}

class GlassFadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const GlassFadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final fadeIn = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
    );
    final slideIn = Tween<Offset>(
      begin: const Offset(0.04, 0.0),
      end: Offset.zero,
    ).animate(fadeIn);

    final fadeOut = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: slideIn,
      child: FadeTransition(
        opacity: fadeIn,
        child: FadeTransition(
          opacity: fadeOut,
          child: child,
        ),
      ),
    );
  }
}
