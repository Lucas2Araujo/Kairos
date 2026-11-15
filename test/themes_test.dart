import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService().init();
  });

  test('Preserva Liquid Glass e Apple Glass e adiciona realGlass, holoRetro e win95', () async {
    expect(
      AppThemeStyle.values,
      containsAll([
        AppThemeStyle.liquidGlass,
        AppThemeStyle.appleGlass,
        AppThemeStyle.realGlass,
        AppThemeStyle.holoRetro,
        AppThemeStyle.win95,
      ]),
    );

    final service = ThemeService();

    await service.setThemeStyle(AppThemeStyle.liquidGlass);
    expect(service.isAnyGlass, isTrue);

    await service.setThemeStyle(AppThemeStyle.appleGlass);
    expect(service.isAnyGlass, isTrue);

    await service.setThemeStyle(AppThemeStyle.realGlass);
    expect(service.isAnyGlass, isTrue);
    expect(service.lightTheme.scaffoldBackgroundColor, Colors.transparent);

    await service.setThemeStyle(AppThemeStyle.holoRetro);
    final holoDark = service.getPalette(Brightness.dark);
    expect(holoDark.primary, const Color(0xFF33B5E5));
    expect(
      service.darkTheme.cardTheme.shape,
      isA<RoundedRectangleBorder>().having(
        (s) => s.borderRadius,
        'borderRadius',
        BorderRadius.zero,
      ),
    );

    await service.setThemeStyle(AppThemeStyle.win95);
    final win95Light = service.getPalette(Brightness.light);
    expect(win95Light.background, const Color(0xFF008080));
    expect(win95Light.surface, const Color(0xFFC0C0C0));
    expect(win95Light.primary, const Color(0xFF000080));
    expect(
      service.lightTheme.appBarTheme.backgroundColor,
      const Color(0xFF000080),
    );
  });
}
