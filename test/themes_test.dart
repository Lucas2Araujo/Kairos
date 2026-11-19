import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/controllers/devotional_controller.dart';
import 'package:kairos_web/controllers/hymn_controller.dart';
import 'package:kairos_web/core/theme/retro_pixel_font_loader.dart';
import 'package:kairos_web/core/utils/youtube_url_parser.dart';
import 'package:kairos_web/models/devotional.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/gamification/monthly_streak_view.dart';
import 'package:kairos_web/views/home/home_view.dart';
import 'package:kairos_web/views/home/widgets/daily_missions_bottom_sheet.dart';
import 'package:kairos_web/views/home/widgets/daily_verse_card.dart';
import 'package:kairos_web/views/settings/settings_dialog.dart';
import 'package:kairos_web/widgets/youtube_player/kairos_youtube_window.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();
    service.setFontFamily('AppSans');
    service.setFontSizeMultiplier(1.0);
    await service.setThemeStyle(AppThemeStyle.materialYou);
    await service.setFloatingNavBar(true);
    await service.setSimplifiedHomeMode(false);
    await service.setDailyVerseCardStyle(DailyVerseCardStyle.auto);
  });

  test('Consolida temas em 8 estilos incluindo ascii, appleGlass, realGlass, holoRetro e win95', () async {
    expect(AppThemeStyle.values.length, 8);
    expect(
      AppThemeStyle.values,
      containsAll([
        AppThemeStyle.materialYou,
        AppThemeStyle.appleGlass,
        AppThemeStyle.realGlass,
        AppThemeStyle.classicBook,
        AppThemeStyle.zen,
        AppThemeStyle.holoRetro,
        AppThemeStyle.win95,
        AppThemeStyle.ascii,
      ]),
    );

    final service = ThemeService();
    expect(service.floatingNavBar, isTrue);
    await service.setFloatingNavBar(false);
    expect(service.floatingNavBar, isFalse);

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

    await service.setThemeStyle(AppThemeStyle.ascii);
    expect(service.isAscii, isTrue);
    expect(service.hasGlobalBackgroundShell, isTrue);
    expect(service.fontFamily, 'RetroPixel');
    expect(
      service.darkTheme.cardTheme.shape,
      isA<RoundedRectangleBorder>().having(
        (s) => s.borderRadius,
        'borderRadius',
        BorderRadius.zero,
      ),
    );
  });

  test('Migra temas legados liquidGlass, classicBookNew, aurora e oledVivid sem perda', () async {
    SharedPreferences.setMockInitialValues({'theme_style': 'liquidGlass'});
    final service = ThemeService();
    await service.init();
    expect(service.themeStyle, AppThemeStyle.appleGlass);
    expect(service.appleGlassVariant, AppleGlassVariant.liquid);

    SharedPreferences.setMockInitialValues({'theme_style': 'classicBookNew'});
    await service.init();
    expect(service.themeStyle, AppThemeStyle.classicBook);
    expect(service.sepiaBookVariant, SepiaBookVariant.editorialParchment);

    SharedPreferences.setMockInitialValues({'theme_style': 'aurora'});
    await service.init();
    expect(service.themeStyle, AppThemeStyle.appleGlass);

    SharedPreferences.setMockInitialValues({'theme_style': 'oledVivid'});
    await service.init();
    expect(service.themeStyle, AppThemeStyle.materialYou);
    expect(service.themeMode, ThemeMode.dark);
    expect(service.isAmoled, isTrue);
  });

  test('Personalidade dos temas: travas de cor, variantes ASCII, fontes padrão e preservação OpenDyslexic', () async {
    final service = ThemeService();

    await service.setThemeStyle(AppThemeStyle.classicBook);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'HymnSerif');
    expect(service.supportsAmoled, isFalse);

    await service.setThemeStyle(AppThemeStyle.zen);
    expect(service.locksAccentColor, isTrue);
    expect(service.fontFamily, 'Montserrat');

    await service.setThemeStyle(AppThemeStyle.ascii);
    await service.setAsciiVariant(AsciiThemeVariant.greenPhosphor);
    expect(service.locksAccentColor, isTrue);
    await service.setAsciiVariant(AsciiThemeVariant.dynamicColor);
    expect(service.locksAccentColor, isFalse);
    expect(service.fontFamily, 'RetroPixel');

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

  testWidgets('Win95 SettingsDialog exibe somente o botão [X] clássico sem duplicar botão de fechar',
      (tester) async {
    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.win95);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: const SettingsDialog(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('X'), findsOneWidget);
    expect(find.text('_'), findsNothing);
    expect(find.text('□'), findsNothing);
    expect(find.byIcon(Icons.close_sharp), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ASCII Vintage + KairosQuickNavBar (flutuante e fixa) renderizam sem overflow em 320px + TextScaler 2.0',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.ascii);

    const items = [
      Win95TaskbarItem(label: 'Início', icon: Icons.home_outlined),
      Win95TaskbarItem(label: 'Bíblia', icon: Icons.book_outlined),
      Win95TaskbarItem(label: 'Hinário', icon: Icons.music_note_outlined),
      Win95TaskbarItem(label: 'Meditação', icon: Icons.volunteer_activism_outlined),
      Win95TaskbarItem(label: 'Lição', icon: Icons.school_outlined),
      Win95TaskbarItem(label: 'Quizzes', icon: Icons.quiz_outlined),
    ];

    for (final isFloating in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: service.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              appBar: AsciiWindowTitleBar(title: 'KAIROS ASCII', onWindowClose: () {}),
              body: const AsciiBoxSurface(
                label: 'MODULO',
                padding: EdgeInsets.all(12),
                child: Text('Conteúdo de leitura em terminal vintage'),
              ),
              bottomNavigationBar: KairosQuickNavBar(
                items: items,
                selectedIndex: 1,
                onSelectTab: (_) {},
                floating: isFloating,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

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

    expect(find.byType(AsciiSwitch), findsWidgets);
    expect(find.text('ASCII Vintage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('RetroPixelFontLoader gera TTF SFNT válido com tabelas obrigatórias e carrega pesos Regular/Bold',
      () async {
    final regularBytes = RetroPixelFontLoader.buildTtfBytes(
      familyName: 'PixelMono',
      bold: false,
    );
    final boldBytes = RetroPixelFontLoader.buildTtfBytes(
      familyName: 'PixelMono',
      bold: true,
    );

    expect(regularBytes.length, greaterThan(2048));
    expect(boldBytes.length, greaterThan(2048));

    final bd = ByteData.sublistView(regularBytes);
    expect(bd.getUint32(0, Endian.big), 0x00010000);
    final numTables = bd.getUint16(4, Endian.big);
    expect(numTables, 10);

    final tags = <String>[];
    for (int i = 0; i < numTables; i++) {
      final offset = 12 + i * 16;
      tags.add(String.fromCharCodes(regularBytes.sublist(offset, offset + 4)));
    }
    expect(
      tags,
      equals(const ['OS/2', 'cmap', 'glyf', 'head', 'hhea', 'hmtx', 'loca', 'maxp', 'name', 'post']),
    );

    await RetroPixelFontLoader.ensureLoaded();
  });

  test('ThemeService persiste simplifiedHomeMode (com aumento de fonte) e DailyVerseCardStyle',
      () async {
    final service = ThemeService();
    expect(service.simplifiedHomeMode, isFalse);
    expect(service.dailyVerseCardStyle, DailyVerseCardStyle.auto);

    await service.setThemeStyle(AppThemeStyle.ascii);
    expect(service.useSlimDailyVerseCard, isTrue);

    await service.setDailyVerseCardStyle(DailyVerseCardStyle.backgroundImage);
    expect(service.useSlimDailyVerseCard, isFalse);

    await service.setSimplifiedHomeMode(true);
    expect(service.simplifiedHomeMode, isTrue);
    expect(service.fontSizeMultiplier, greaterThanOrEqualTo(1.25));

    await service.init();
    expect(service.simplifiedHomeMode, isTrue);
    expect(service.dailyVerseCardStyle, DailyVerseCardStyle.backgroundImage);

    await service.setSimplifiedHomeMode(false);
    expect(service.simplifiedHomeMode, isFalse);
    expect(service.fontSizeMultiplier, 1.0);
  });

  testWidgets('HomeView exibe os 8 módulos no tema ASCII e apenas 4 botões grandes no Modo Simplificado',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.ascii);

    final bibleCtrl = BibleController();
    final hymnCtrl = HymnController();
    final devoCtrl = DevotionalController()
      ..currentDevotional = const Devotional(
        publishedAt: '2026-11-18',
        title: 'Luz no Caminho',
        verseText: 'Lâmpada para os meus pés é a tua palavra.',
        verseReference: 'Salmos 119:105',
        content: '<p>Reflexão diária completa para o layout em duas colunas do desktop.</p>',
      );
    addTearDown(() {
      bibleCtrl.dispose();
      hymnCtrl.dispose();
      devoCtrl.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: HomeView(
          bibleController: bibleCtrl,
          hymnController: hymnCtrl,
          devotionalController: devoCtrl,
          onNavigateToTab: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Garante que os 8 botões de módulo aparecem no tema ASCII (e não caixa de busca duplicada)
    expect(find.text('+--[ MODULOS PRINCIPAIS ]--+'), findsOneWidget);
    expect(find.text('BÍBLIA SAGRADA'), findsOneWidget);
    expect(find.text('QUIZZES'), findsOneWidget);
    expect(find.text('[ LER MEDITACAO > ]'), findsOneWidget);
    expect(find.text('[ ABRIR BIBLIA ]'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ativa o Modo Simplificado (Idosos) em tela estreita com TextScaler 1.6
    tester.view.physicalSize = const Size(360, 780);
    await service.setThemeStyle(AppThemeStyle.materialYou);
    await service.setSimplifiedHomeMode(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: HomeView(
            bibleController: bibleCtrl,
            hymnController: hymnCtrl,
            devotionalController: devoCtrl,
            onNavigateToTab: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bíblia'), findsOneWidget);
    expect(find.text('Hinário'), findsOneWidget);
    expect(find.text('Lição'), findsOneWidget);
    expect(find.text('Devocional'), findsOneWidget);
    expect(find.byType(DailyVerseCard), findsNothing);
    expect(find.text('Quizzes'), findsNothing);
    expect(find.text('Planos de Leitura'), findsNothing);
    expect(tester.takeException(), isNull);

    // Garante que no desktop horizontal o Modo Simplificado também oculta o DailyVerseCard
    tester.view.physicalSize = const Size(1280, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: service.lightTheme,
        home: HomeView(
          bibleController: bibleCtrl,
          hymnController: hymnCtrl,
          devotionalController: devoCtrl,
          onNavigateToTab: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DailyVerseCard), findsNothing);
    expect(find.text('Bíblia'), findsOneWidget);
    expect(find.text('Devocional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DailyVerseCard renderiza modo compacto só texto e versão expandida desktop sem overflow',
      (tester) async {
    final service = ThemeService();
    final bibleCtrl = BibleController();
    final devoCtrl = DevotionalController()
      ..currentDevotional = const Devotional(
        publishedAt: '2026-11-18',
        title: 'A Esperança Viva',
        verseText: 'Porque nenhum de nós vive para si mesmo.',
        verseReference: 'Romanos 14:7',
        content: 'Conteúdo devocional de exemplo para validar prévia na coluna desktop.',
      );
    addTearDown(() {
      bibleCtrl.dispose();
      devoCtrl.dispose();
    });

    for (final style in const [DailyVerseCardStyle.slimTextOnly, DailyVerseCardStyle.backgroundImage]) {
      await service.setDailyVerseCardStyle(style);
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: service.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DailyVerseCard(
                  bibleController: bibleCtrl,
                  devotionalController: devoCtrl,
                  onNavigateToTab: (_) {},
                  isGlass: false,
                  isDesktopExpanded: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(960, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: service.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DailyVerseCard(
                bibleController: bibleCtrl,
                devotionalController: devoCtrl,
                onNavigateToTab: (_) {},
                isGlass: false,
                isDesktopExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A Esperança Viva'), findsOneWidget);
      expect(find.text('Abrir na Bíblia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
  });

  test('YoutubeUrlParser extrai videoId de todos os formatos do YouTube e rejeita links externos', () {
    expect(
      YoutubeUrlParser.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      YoutubeUrlParser.extractVideoId('https://youtu.be/dQw4w9WgXcQ?t=42'),
      'dQw4w9WgXcQ',
    );
    expect(
      YoutubeUrlParser.extractVideoId('https://m.youtube.com/shorts/AbCdEf12345'),
      'AbCdEf12345',
    );
    expect(
      YoutubeUrlParser.extractVideoId('https://www.youtube.com/live/XyZ98765432'),
      'XyZ98765432',
    );
    expect(
      YoutubeUrlParser.extractVideoId('https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      YoutubeUrlParser.isYoutubeUrl('https://igrejas.adventistas.org/'),
      isFalse,
    );
  });

  testWidgets('KairosYoutubeWindow abre modal Teatro, alterna para mini-janela PiP e fecha sem erro',
      (tester) async {
    addTearDown(KairosYoutubeWindow.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => KairosYoutubeWindow.show(
                  context,
                  url: 'https://youtu.be/dQw4w9WgXcQ',
                  title: 'Hino 1 - Exemplo',
                ),
                child: const Text('Abrir Vídeo Teste'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir Vídeo Teste'));
    await tester.pumpAndSettle();

    expect(KairosYoutubeWindow.isOpen, isTrue);
    expect(find.text('Hino 1 - Exemplo'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('yt_window_pip_toggle')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Alterna para Modo Mini-Janela Flutuante (PiP)
    await tester.tap(find.byKey(const Key('yt_window_pip_toggle')));
    await tester.pumpAndSettle();

    expect(KairosYoutubeWindow.isOpen, isTrue);
    expect(find.byKey(const Key('yt_window_close')), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Fecha a janela
    await tester.tap(find.byKey(const Key('yt_window_close')));
    await tester.pumpAndSettle();

    expect(KairosYoutubeWindow.isOpen, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MonthlyStreakView 1280x800 mantem calendario compacto e DailyMissionsBottomSheet ASCII renderiza sem overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final service = ThemeService();
    await service.setThemeStyle(AppThemeStyle.ascii);

    await tester.pumpWidget(
      MaterialApp(
        theme: service.darkTheme,
        home: const MonthlyStreakView(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ofensiva & Conquistas'), findsOneWidget);
    expect(find.text('CRITERIOS DA OFENSIVA'), findsOneWidget);
    final dayCellSize = tester.getSize(
      find.ancestor(of: find.text('1').first, matching: find.byType(Container)).first,
    );
    expect(dayCellSize.height, lessThanOrEqualTo(60.0));
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpWidget(
      MaterialApp(
        theme: service.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: DailyMissionsBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RESERVA DE AZEITE & MISSOES'), findsOneWidget);
    expect(find.text('STATUS DA LAMPARINA'), findsOneWidget);
    expect(find.text('[ VER CALENDARIO DO MES & CONQUISTAS ]'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
