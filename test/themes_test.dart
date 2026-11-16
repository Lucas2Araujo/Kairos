import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    service.setFontFamily('AppSans');
    await service.setThemeStyle(AppThemeStyle.materialYou);
  });

  test('Consolida temas em 9 estilos com appleGlass, realGlass, holoRetro e win95', () async {
    expect(AppThemeStyle.values.length, 9);
    expect(
      AppThemeStyle.values,
      containsAll([
        AppThemeStyle.materialYou,
        AppThemeStyle.appleGlass,
        AppThemeStyle.realGlass,
        AppThemeStyle.classicBook,
        AppThemeStyle.aurora,
        AppThemeStyle.oledVivid,
        AppThemeStyle.zen,
        AppThemeStyle.holoRetro,
        AppThemeStyle.win95,
      ]),
    );

    final service = ThemeService();

    await service.setThemeStyle(AppThemeStyle.appleGlass);
    await service.setAppleGlassVariant(AppleGlassVariant.liquid);
    expect(service.isAnyGlass, isTrue);
    expect(service.isLiquidGlass, isTrue);

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

  test('Migra temas legados liquidGlass e classicBookNew para sub-variantes', () async {
    SharedPreferences.setMockInitialValues({'theme_style': 'liquidGlass'});
    final service = ThemeService();
    await service.init();
    expect(service.themeStyle, AppThemeStyle.appleGlass);
    expect(service.appleGlassVariant, AppleGlassVariant.liquid);

    SharedPreferences.setMockInitialValues({'theme_style': 'classicBookNew'});
    await service.init();
    expect(service.themeStyle, AppThemeStyle.classicBook);
    expect(service.sepiaBookVariant, SepiaBookVariant.editorialParchment);
  });

  test('Personalidade dos temas: travas de cor/modo escuro, fontes padrão e preservação OpenDyslexic', () async {
    final service = ThemeService();

    await service.setThemeStyle(AppThemeStyle.classicBook);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'HymnSerif');
    expect(service.supportsAmoled, isFalse);

    await service.setThemeStyle(AppThemeStyle.zen);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'Montserrat');

    await service.setThemeStyle(AppThemeStyle.oledVivid);
    expect(service.locksDarkMode, isTrue);
    expect(service.themeMode, ThemeMode.dark);
    expect(service.locksAccentColor, isFalse);

    await service.setThemeStyle(AppThemeStyle.holoRetro);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'DroidSans');

    await service.setThemeStyle(AppThemeStyle.win95);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'PixelMono');

    // OpenDyslexic deve ser preservada por acessibilidade ao trocar de tema
    service.setFontFamily('OpenDyslexic');
    await service.setThemeStyle(AppThemeStyle.classicBook);
    expect(service.fontFamily, 'OpenDyslexic');
  });

  test('Real Glass persiste geração iOS 26/27 e presets de papel de parede', () async {
    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.realGlass);
    await service.setRealGlassEra(RealGlassEra.ios26);
    await service.setRealGlassWallpaper(RealGlassWallpaper.cupertinoOcean);

    await service.init();
    expect(service.themeStyle, AppThemeStyle.realGlass);
    expect(service.realGlassEra, RealGlassEra.ios26);
    expect(service.realGlassWallpaper, RealGlassWallpaper.cupertinoOcean);
  });

  testWidgets('Win95WindowTitleBar e Win95TaskbarNavigation renderizam sem overflow em 320px + TextScaler 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const items = [
      Win95TaskbarItem(label: 'Início', icon: Icons.home_outlined),
      Win95TaskbarItem(label: 'Bíblia', icon: Icons.book_outlined),
      Win95TaskbarItem(label: 'Hinário', icon: Icons.music_note_outlined),
      Win95TaskbarItem(label: 'Meditação', icon: Icons.volunteer_activism_outlined),
      Win95TaskbarItem(label: 'Lição', icon: Icons.school_outlined),
      Win95TaskbarItem(label: 'Quizzes', icon: Icons.quiz_outlined),
    ];
    int selected = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              appBar: const Win95WindowTitleBar(title: 'Kairós 95 - Estudo Bíblico.exe'),
              body: const Padding(
                padding: EdgeInsets.all(12),
                child: Win95SunkenField(
                  padding: EdgeInsets.all(10),
                  child: Text('Pesquisar...'),
                ),
              ),
              bottomNavigationBar: Win95TaskbarNavigation(
                items: items,
                selectedIndex: selected,
                onSelectTab: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Iniciar'), findsOneWidget);
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    expect(find.text('Kairós 95'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HoloRetroActionBar e HoloRetroTabBar renderizam sem overflow em 320px + TextScaler 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const items = [
      Win95TaskbarItem(label: 'Início', icon: Icons.home_outlined),
      Win95TaskbarItem(label: 'Bíblia', icon: Icons.book_outlined),
      Win95TaskbarItem(label: 'Hinário', icon: Icons.music_note_outlined),
      Win95TaskbarItem(label: 'Meditação', icon: Icons.volunteer_activism_outlined),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            appBar: const HoloRetroActionBar(title: 'Kairós'),
            body: const HoloRetroBackground(isDark: true),
            bottomNavigationBar: HoloRetroTabBar(
              items: items,
              selectedIndex: 1,
              onSelectTab: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsDialog expõe sub-opções contextuais para Real Glass, Apple Glass e Livro Sépia',
      (tester) async {
    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.realGlass);

    await tester.pumpWidget(
      LiquidGlassWidgets.wrap(
        brightnessResolver: Theme.maybeBrightnessOf,
        child: MaterialApp(
          theme: service.lightTheme,
          home: const SettingsDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Motor Óptico Apple'), findsOneWidget);
    expect(find.text('Papel de Parede (Refração)'), findsOneWidget);
    expect(find.text('iOS 27 Bloom'), findsOneWidget);
    expect(find.byType(GlassSegmentedControl), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Win95 pixel art, desktop background e Painel de Controle renderizam sem overflow em 320px + TextScaler 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.win95);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Stack(
            children: [
              const Positioned.fill(child: Win95DesktopBackground(isDark: false)),
              Wrap(
                children: Win95PixelIconType.values
                    .map((t) => Win95PixelIcon(type: t, size: 28))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: SettingsDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Painel de Controle - Kairós 95'), findsOneWidget);
    expect(find.byType(Win95CheckboxTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Holo ICS switches, brackets, section headers e SettingsDialog renderizam sem overflow em 320px + TextScaler 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.holoRetro);

    bool sw = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: service.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HoloSectionHeader(title: 'Wireless & Networks'),
                  HoloSwitch(
                    value: sw,
                    onChanged: (v) => setState(() => sw = v),
                  ),
                  const HoloBracketField(
                    child: Text('10 minutes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(HoloSwitch));
    await tester.pumpAndSettle();
    expect(sw, isFalse);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: SettingsDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings • Configurações'), findsOneWidget);
    expect(find.byType(HoloSwitch), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
