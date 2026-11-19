import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../controllers/tutorial_controller.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../classroom/classroom_view.dart';
import '../egw/egw_books_view.dart';
import '../plans/reading_plans_view.dart';
import '../profile/avatar_builder_modal.dart';
import '../profile/profile_dialog.dart';
import '../search/global_search_view.dart';
import '../settings/settings_dialog.dart';
import 'widgets/daily_missions_bottom_sheet.dart';
import 'widgets/daily_verse_card.dart';

class HomeView extends StatefulWidget {
  final BibleController bibleController;
  final HymnController hymnController;
  final DevotionalController devotionalController;
  final SabbathSchoolController? sabbathSchoolController;
  final void Function(int tabIndex) onNavigateToTab;

  const HomeView({
    super.key,
    required this.bibleController,
    required this.hymnController,
    required this.devotionalController,
    this.sabbathSchoolController,
    required this.onNavigateToTab,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _block1Anim;
  late final Animation<double> _block2Anim;
  late final Animation<double> _block3Anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _block1Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
    );
    _block2Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
    );
    _block3Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Retorna título e subtítulo da acolhida dinâmica conforme o período do dia e o usuário logado
  (String title, String subtitle) _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final user = AuthService().currentUser;
    final name = (user?.displayName != null && user!.displayName.trim().isNotEmpty)
        ? ', ${user.displayName.trim()}'
        : '';

    final seed = now.day + now.hour;

    if (hour >= 5 && hour < 12) {
      // Manhã (5h - 11h59)
      const subtitles = [
        'Que tal passar um tempo com Deus nessa manhã?',
        'Que a Palavra ilumine seus passos hoje.',
        'Uma manhã com a Palavra renova o coração.',
      ];
      return ('Bom dia$name! ☀️', subtitles[seed % subtitles.length]);
    } else if (hour >= 12 && hour < 18) {
      // Tarde (12h - 17h59)
      const subtitles = [
        'Que tal uma pausa para alimentar a alma?',
        'A Palavra é lâmpada para os seus passos.',
        'Renove sua mente com a leitura de hoje.',
      ];
      return ('Boa tarde$name! 🌤️', subtitles[seed % subtitles.length]);
    } else {
      // Noite (18h - 4h59)
      const subtitles = [
        'Encerre o dia refletindo na Palavra de Deus.',
        'Uma leitura antes de descansar traz paz ao coração.',
        'Que a paz do Senhor guarde seus pensamentos.',
      ];
      return ('Boa noite$name! 🌙', subtitles[seed % subtitles.length]);
    }
  }

  /// Formata a categoria da lição da escola sabatina para exibição no badge
  static String _formatSabbathSchoolBadge(String? category) {
    final cat = (category ?? '').trim().toLowerCase();
    if (cat.startsWith('jov')) {
      return 'JOVENS';
    }
    return 'ADULTOS';
  }

  void _openGlobalSearch(BuildContext context) {
    GlobalSearchView.show(
      context,
      bibleController: widget.bibleController,
      hymnController: widget.hymnController,
      devotionalController: widget.devotionalController,
      sabbathSchoolController:
          widget.sabbathSchoolController ?? SabbathSchoolController(),
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: Listenable.merge([themeService, AuthService(), GamificationService()]),
      builder: (context, _) {
        final isGlass = themeService.hasAtmosphericBackground;
        final hasGlobalBg = themeService.hasGlobalBackgroundShell;
        final multiplier = themeService.fontSizeMultiplier;
        final greeting = _getGreeting();

        final Widget avatarWidget = Builder(
          builder: (context) {
            final auth = AuthService();
            final gamification = GamificationService();
            final user = auth.currentUser;
            if (!gamification.useCustomAvatar &&
                auth.isAuthenticated &&
                user != null &&
                user.avatarUrl.isNotEmpty) {
              return CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(user.avatarUrl),
                onBackgroundImageError: (_, __) {},
              );
            }
            return AvatarCustomWidget(
              config: gamification.avatarConfig,
              size: 30,
            );
          },
        );

        final Widget profileButton = IconButton(
          tooltip: 'Perfil e Conta',
          onPressed: () => ProfileDialog.show(context),
          icon: avatarWidget,
        );

        final bool showTopSearch =
            themeService.homeSearchPlacement == HomeSearchPlacement.topBarIcon;
        final Widget searchButton = IconButton(
          icon: themeService.isAscii
              ? const SnesPixelIcon(type: SnesPixelIconType.search, size: 18)
              : const Icon(Icons.search_rounded),
          tooltip: 'Busca Global',
          onPressed: () => _openGlobalSearch(context),
        );
        final bool isSimplified = themeService.simplifiedHomeMode;
        final Widget simplifiedModeButton = IconButton(
          icon: Icon(
            Icons.accessibility_new_rounded,
            color: isSimplified ? theme.colorScheme.primary : null,
          ),
          tooltip: isSimplified
              ? 'Desativar Modo Simplificado'
              : 'Modo Simplificado (Leitura Fácil)',
          onPressed: () => themeService.setSimplifiedHomeMode(!isSimplified),
        );
        final Widget settingsButton = IconButton(
          icon: themeService.isAscii
              ? const SnesPixelIcon(type: SnesPixelIconType.gear, size: 18)
              : const Icon(Icons.settings_outlined),
          tooltip: 'Configurações e Temas',
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const SettingsDialog(),
            );
          },
        );

        final PreferredSizeWidget appBar;
        if (themeService.isRealGlass) {
          appBar = GlassAppBar(
            toolbarHeight: 52,
            title: const Text('Kairós'),
            leading: GlassIconButton(
              icon: avatarWidget,
              size: 44,
              semanticLabel: 'Perfil e Conta',
              onPressed: () => ProfileDialog.show(context),
            ),
            actions: [
              GlassIconButton(
                icon: Icon(
                  Icons.accessibility_new_rounded,
                  color: isSimplified ? theme.colorScheme.primary : null,
                ),
                size: 44,
                semanticLabel: isSimplified
                    ? 'Desativar Modo Simplificado'
                    : 'Modo Simplificado (Leitura Fácil)',
                onPressed: () => themeService.setSimplifiedHomeMode(!isSimplified),
              ),
              if (showTopSearch)
                GlassIconButton(
                  icon: const Icon(CupertinoIcons.search),
                  size: 44,
                  semanticLabel: 'Busca Global',
                  onPressed: () => _openGlobalSearch(context),
                ),
              GlassIconButton(
                icon: const Icon(CupertinoIcons.gear_alt),
                size: 44,
                semanticLabel: 'Configurações e Temas',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  );
                },
              ),
            ],
          );
        } else if (themeService.isAscii) {
          appBar = AsciiWindowTitleBar(
            title: 'KAIROS TERMINAL v4',
            leading: profileButton,
            actions: [
              simplifiedModeButton,
              if (showTopSearch) searchButton,
              settingsButton,
            ],
          );
        } else if (themeService.isWin95) {
          appBar = Win95WindowTitleBar(
            title: 'Kairós 95 - Estudo Bíblico.exe',
            leading: profileButton,
            actions: [
              simplifiedModeButton,
              if (showTopSearch) searchButton,
              settingsButton,
            ],
          );
        } else if (themeService.isHoloRetro) {
          appBar = HoloRetroActionBar(
            title: 'Kairós',
            leading: profileButton,
            actions: [
              simplifiedModeButton,
              if (showTopSearch) searchButton,
              settingsButton,
              const SizedBox(width: 4),
            ],
          );
        } else {
          appBar = AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            leading: profileButton,
            actions: [
              simplifiedModeButton,
              if (showTopSearch) searchButton,
              settingsButton,
              const SizedBox(width: 4),
            ],
          );
        }

        return Scaffold(
          backgroundColor: hasGlobalBg ? Colors.transparent : null,
          appBar: appBar,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 960;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 20,
                  vertical: 20,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 1140 : 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // B. Header de Boas-Vindas & Gamificação (Parábola das Dez Virgens)
                        _buildAnimatedSection(
                          animation: _block1Anim,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Lado Esquerdo: Saudação contextual + Subtítulo devocional rotativo
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting.$1,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22 * multiplier,
                                        color: themeService.isWin95 ? Colors.white : null,
                                        shadows: themeService.isWin95
                                            ? const [
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(1, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      greeting.$2,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: themeService.isWin95
                                            ? Colors.white.withValues(alpha: 0.92)
                                            : theme.textTheme.bodySmall?.color,
                                        fontSize: 13 * multiplier,
                                        shadows: themeService.isWin95
                                            ? const [
                                                Shadow(
                                                  color: Colors.black,
                                                  offset: Offset(1, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSimplified) ...[
                                const SizedBox(width: 10),
                                // Lado Direito: Lamparina & Gotas de Azeite (XP)
                                KeyedSubtree(
                                  key: TutorialController().registerKey('home_gamification'),
                                  child: _buildGamificationHeaderPill(context, theme, isGlass),
                                ),
                              ],
                            ],
                          ),
                        ),

                        if (isDesktop) ...[
                          if (!isSimplified &&
                              themeService.homeSearchPlacement == HomeSearchPlacement.capsuleBody) ...[
                            const SizedBox(height: 18),
                            _buildAnimatedSection(
                              animation: _block1Anim,
                              child: KeyedSubtree(
                                key: TutorialController().registerKey('home_search'),
                                child: _buildSearchCapsule(context, theme, isGlass),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          if (isSimplified)
                            _buildAnimatedSection(
                              animation: _block3Anim,
                              child: _buildActionGrid(context, theme, isGlass, themeService, multiplier),
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _buildAnimatedSection(
                                    animation: _block2Anim,
                                    child: KeyedSubtree(
                                      key: TutorialController().registerKey('home_daily_verse'),
                                      child: DailyVerseCard(
                                        bibleController: widget.bibleController,
                                        onNavigateToTab: widget.onNavigateToTab,
                                        devotionalController: widget.devotionalController,
                                        isGlass: isGlass,
                                        isDesktopExpanded: true,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                Expanded(
                                  flex: 5,
                                  child: _buildAnimatedSection(
                                    animation: _block3Anim,
                                    child: _buildActionGrid(context, theme, isGlass, themeService, multiplier),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                        ] else ...[
                          // C. Barra de Busca Global (Cápsula no corpo da tela)
                          if (!isSimplified &&
                              themeService.homeSearchPlacement == HomeSearchPlacement.capsuleBody) ...[
                            const SizedBox(height: 16),
                            _buildAnimatedSection(
                              animation: _block1Anim,
                              child: KeyedSubtree(
                                key: TutorialController().registerKey('home_search'),
                                child: _buildSearchCapsule(context, theme, isGlass),
                              ),
                            ),
                          ],

                          if (!isSimplified) ...[
                            const SizedBox(height: 20),

                            // D. Banner Dinâmico: Meditação Diária & Pôr do Sol
                            _buildAnimatedSection(
                              animation: _block2Anim,
                              child: KeyedSubtree(
                                key: TutorialController().registerKey('home_daily_verse'),
                                child: DailyVerseCard(
                                  bibleController: widget.bibleController,
                                  onNavigateToTab: widget.onNavigateToTab,
                                  devotionalController: widget.devotionalController,
                                  isGlass: isGlass,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),

                          // E. Grid de Ações / Módulos Principais (3 Linhas x 2 Colunas)
                          _buildAnimatedSection(
                            animation: _block3Anim,
                            child: _buildActionGrid(context, theme, isGlass, themeService, multiplier),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Pílula compacta de Gamificação no Header (Lamparina/Ofensiva + Gotas de Azeite)
  Widget _buildGamificationHeaderPill(BuildContext context, ThemeData theme, bool isGlass) {
    final service = GamificationService();
    final streak = service.currentStreak;
    final isFull = service.isFullFlameActive;
    final isHalf = service.isHalfStreakActive;
    final isLit = isFull || isHalf;

    final themeService = ThemeService();
    final flameColor = isLit ? Colors.amber.shade700 : Colors.grey;

    if (themeService.isWin95) {
      return Semantics(
        button: true,
        excludeSemantics: true,
        label:
            'Ofensiva de $streak dias e ${service.todayOilDrops} gotas de azeite. Toque para abrir as missões diárias.',
        child: Tooltip(
          message: 'Missões Diárias e Ofensiva',
          child: Win95BevelBox(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            onTap: () => DailyMissionsBottomSheet.show(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Win95PixelIcon(type: Win95PixelIconType.flameLamp, size: 16),
                const SizedBox(width: 5),
                Text(
                  '$streak | ${service.todayOilDrops}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (themeService.isAscii) {
      return Semantics(
        button: true,
        excludeSemantics: true,
        label:
            'Ofensiva de $streak dias e ${service.todayOilDrops} gotas de azeite. Toque para abrir as missões diárias.',
        child: Tooltip(
          message: 'Missões Diárias e Ofensiva',
          child: AsciiBoxSurface(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            onTap: () => DailyMissionsBottomSheet.show(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SnesPixelIcon(
                  type: SnesPixelIconType.lamp,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '[$streak D | ${service.todayOilDrops} GT]',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'RetroPixel',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (themeService.isHoloRetro) {
      return Semantics(
        button: true,
        excludeSemantics: true,
        label:
            'Ofensiva de $streak dias e ${service.todayOilDrops} gotas de azeite. Toque para abrir as missões diárias.',
        child: Tooltip(
          message: 'Missões Diárias e Ofensiva',
          child: InkWell(
            onTap: () => DailyMissionsBottomSheet.show(context),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: const Border(
                  top: BorderSide(color: Color(0xFF33B5E5), width: 1.0),
                  left: BorderSide(color: Color(0xFF33B5E5), width: 1.0),
                  right: BorderSide(color: Color(0xFF33B5E5), width: 1.0),
                  bottom: BorderSide(color: Color(0xFF33B5E5), width: 3.0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLit ? Icons.local_fire_department_sharp : Icons.local_fire_department_outlined,
                    color: isLit ? const Color(0xFF33B5E5) : Colors.grey,
                    size: 17,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$streak',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: const Color(0xFF33B5E5)),
                  const SizedBox(width: 8),
                  Icon(
                    service.isLampFull ? Icons.lightbulb_sharp : Icons.opacity_sharp,
                    color: const Color(0xFF33B5E5),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${service.todayOilDrops}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Ofensiva de $streak dias e ${service.todayOilDrops} gotas de azeite. Toque para abrir as missões diárias.',
      child: Tooltip(
        message: 'Missões Diárias e Ofensiva',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => DailyMissionsBottomSheet.show(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isLit
                  ? Colors.amber.withValues(alpha: 0.14)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLit
                    ? Colors.amber.withValues(alpha: 0.45)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lamparina / Fogo da Ofensiva
                Icon(
                  isLit ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
                  color: flameColor,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),

                // Linha divisora discreta
                Container(
                  width: 1,
                  height: 14,
                  color: theme.dividerColor.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 8),

                // Gota de Azeite (XP)
                Icon(
                  service.isLampFull ? Icons.lightbulb_rounded : Icons.opacity_rounded,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${service.todayOilDrops}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Campo de busca em formato cápsula/pílula no corpo da Home
  Widget _buildSearchCapsule(BuildContext context, ThemeData theme, bool isGlass) {
    final themeService = ThemeService();
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pesquisar na Bíblia, hinários, lições...',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );

    if (themeService.isAscii) {
      return AsciiBoxSurface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: () => _openGlobalSearch(context),
        child: Row(
          children: [
            SnesPixelIcon(
              type: SnesPixelIconType.search,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '>_',
              style: TextStyle(
                fontFamily: 'RetroPixel',
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'PESQUISAR NA BIBLIA, HINARIOS, LICOES...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'RetroPixel',
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (themeService.isWin95) {
      return Win95SunkenField(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: () => _openGlobalSearch(context),
        child: Row(
          children: [
            const Win95PixelIcon(type: Win95PixelIconType.searchMagnifier, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                r'C:\KAIROS> Pesquisar na Bíblia, hinários..._',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (themeService.isHoloRetro) {
      return HoloBracketField(
        onTap: () => _openGlobalSearch(context),
        child: Row(
          children: [
            const Icon(Icons.search_sharp, color: Color(0xFF33B5E5), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pesquisar na Bíblia, hinários, lições...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (themeService.richThemeSurfaces || themeService.isRealGlass) {
      return KairosInteractiveCard(
        onTap: () => _openGlobalSearch(context),
        child: GlassSurface(
          borderRadius: 24,
          padding: EdgeInsets.zero,
          onTap: () => _openGlobalSearch(context),
          child: inner,
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openGlobalSearch(context),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isGlass ? 0.3 : 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
        child: inner,
      ),
    );
  }

  /// Grid de Módulos Principais (Modo Simplificado Idosos, Desktop Win95, Grid ICS ou Cards 2 Colunas)
  Widget _buildActionGrid(
    BuildContext context,
    ThemeData theme,
    bool isGlass,
    ThemeService themeService,
    double multiplier,
  ) {
    if (themeService.simplifiedHomeMode) {
      return _buildSeniorSimplifiedGrid(context, theme, isGlass, themeService, multiplier);
    }

    if (themeService.isWin95) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            r'[ C:\KAIROS\MÓDULOS\*.* ]',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14 * multiplier,
              shadows: const [
                Shadow(color: Colors.black, offset: Offset(1, 1)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final desktopTiles = <Widget>[
                ListenableBuilder(
                  listenable: widget.bibleController,
                  builder: (context, _) {
                    final version = widget.bibleController.activeVersion.trim().isNotEmpty
                        ? widget.bibleController.activeVersion.trim().toUpperCase()
                        : 'ARA';
                    return Win95DesktopIconTile(
                      iconType: Win95PixelIconType.bibleBook,
                      title: 'Bíblia Sagrada',
                      badgeText: version,
                      onTap: () => widget.onNavigateToTab(1),
                    );
                  },
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.readingPlan,
                  title: 'Planos',
                  badgeText: 'TXT',
                  onTap: () => ReadingPlansView.show(
                    context,
                    bibleController: widget.bibleController,
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.hymnalMusic,
                  title: 'Hinários',
                  badgeText: 'WAV',
                  onTap: () => widget.onNavigateToTab(2),
                ),
                ListenableBuilder(
                  listenable: Listenable.merge([
                    if (widget.sabbathSchoolController != null) widget.sabbathSchoolController!,
                    themeService,
                  ]),
                  builder: (context, _) {
                    final rawCat = widget.sabbathSchoolController?.quarterlyType ??
                        themeService.defaultSabbathSchoolCategory;
                    final badge = _formatSabbathSchoolBadge(rawCat);
                    return Win95DesktopIconTile(
                      iconType: Win95PixelIconType.sabbathSchool,
                      title: 'Lição ES',
                      badgeText: badge == 'JOVENS' ? 'JOV' : 'ADT',
                      onTap: () => widget.onNavigateToTab(4),
                    );
                  },
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.churchMap,
                  title: 'Igrejas',
                  badgeText: 'MAP',
                  onTap: () async {
                    final uri = Uri.parse('https://igrejas.adventistas.org/');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.classroom,
                  title: 'Turmas',
                  badgeText: 'LAN',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ClassroomView(),
                      ),
                    );
                  },
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.quizGame,
                  title: 'Quizzes',
                  badgeText: 'EXE',
                  onTap: () => widget.onNavigateToTab(5),
                ),
                Win95DesktopIconTile(
                  iconType: Win95PixelIconType.egwScroll,
                  title: 'Profecia EGW',
                  badgeText: 'DOC',
                  onTap: () => EgwBooksView.navigateTo(context),
                ),
              ];

              final columns = constraints.maxWidth >= 500
                  ? 4
                  : (constraints.maxWidth >= 280 ? 3 : 2);
              final rows = <Widget>[];
              for (int i = 0; i < desktopTiles.length; i += columns) {
                final rowChildren = <Widget>[];
                for (int col = 0; col < columns; col++) {
                  final idx = i + col;
                  rowChildren.add(
                    Expanded(
                      child: idx < desktopTiles.length
                          ? desktopTiles[idx]
                          : const SizedBox.shrink(),
                    ),
                  );
                }
                rows.add(
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: rowChildren,
                  ),
                );
                if (i + columns < desktopTiles.length) {
                  rows.add(const SizedBox(height: 8));
                }
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              );
            },
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (themeService.isHoloRetro)
          const HoloSectionHeader(title: 'Módulos Principais')
        else if (themeService.isAscii)
          Text(
            '+--[ MODULOS PRINCIPAIS ]--+',
            style: TextStyle(
              fontFamily: 'RetroPixel',
              fontWeight: FontWeight.bold,
              fontSize: 14 * multiplier,
              color: theme.colorScheme.primary,
            ),
          )
        else
          Text(
            'Módulos Principais',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16 * multiplier,
            ),
          ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final tiles = <Widget>[
              ListenableBuilder(
                listenable: widget.bibleController,
                builder: (context, _) {
                  final version = widget.bibleController.activeVersion.trim().isNotEmpty
                      ? widget.bibleController.activeVersion.trim().toUpperCase()
                      : 'ARA';
                  final lastRead = widget.bibleController.lastReadReference;
                  return _buildActionTile(
                    context,
                    icon: Icons.menu_book_rounded,
                    pixelIcon: SnesPixelIconType.bible,
                    title: 'Bíblia Sagrada',
                    subtitle: 'Continuar: $lastRead',
                    badgeText: version,
                    color: theme.colorScheme.primary,
                    onTap: () => widget.onNavigateToTab(1),
                    isGlass: isGlass,
                  );
                },
              ),
              KeyedSubtree(
                key: TutorialController().registerKey('home_reading_plans_action'),
                child: _buildActionTile(
                  context,
                  icon: Icons.auto_stories_rounded,
                  pixelIcon: SnesPixelIconType.trophy,
                  title: 'Planos de Leitura',
                  subtitle: 'Jornadas & Metas',
                  badgeText: 'ESTUDO',
                  color: Colors.indigoAccent,
                  onTap: () => ReadingPlansView.show(
                    context,
                    bibleController: widget.bibleController,
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                  isGlass: isGlass,
                ),
              ),
              _buildActionTile(
                context,
                icon: Icons.music_note_rounded,
                pixelIcon: SnesPixelIconType.harp,
                title: 'Hinários',
                subtitle: 'Letras e áudios',
                badgeText: '2022 / 1996',
                color: theme.colorScheme.secondary,
                onTap: () => widget.onNavigateToTab(2),
                isGlass: isGlass,
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  if (widget.sabbathSchoolController != null) widget.sabbathSchoolController!,
                  themeService,
                ]),
                builder: (context, _) {
                  final rawCat = widget.sabbathSchoolController?.quarterlyType ??
                      themeService.defaultSabbathSchoolCategory;
                  final badge = _formatSabbathSchoolBadge(rawCat);
                  return _buildActionTile(
                    context,
                    icon: Icons.school_rounded,
                    pixelIcon: SnesPixelIconType.scroll,
                    title: 'Escola Sabatina',
                    subtitle: 'Estudo diário da lição',
                    badgeText: badge,
                    color: theme.colorScheme.primary,
                    onTap: () => widget.onNavigateToTab(4),
                    isGlass: isGlass,
                  );
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.church_rounded,
                pixelIcon: SnesPixelIconType.church,
                title: 'Encontre uma Igreja',
                subtitle: 'Templos próximos',
                badgeText: 'MAPA',
                color: Colors.teal,
                onTap: () async {
                  final uri = Uri.parse('https://igrejas.adventistas.org/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                isGlass: isGlass,
              ),
              KeyedSubtree(
                key: TutorialController().registerKey('home_classroom_action'),
                child: _buildActionTile(
                  context,
                  icon: Icons.groups_rounded,
                  pixelIcon: SnesPixelIconType.people,
                  title: 'Turmas / Classes',
                  subtitle: 'Comunidade & estudos',
                  badgeText: 'CLASSE',
                  color: Colors.deepPurpleAccent,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ClassroomView(),
                      ),
                    );
                  },
                  isGlass: isGlass,
                ),
              ),
              _buildActionTile(
                context,
                icon: Icons.quiz_rounded,
                pixelIcon: SnesPixelIconType.quiz,
                title: 'Quizzes',
                subtitle: 'Desafios bíblicos e da lição',
                badgeText: 'DESAFIO',
                color: Colors.amber.shade800,
                onTap: () => widget.onNavigateToTab(5),
                isGlass: isGlass,
              ),
              KeyedSubtree(
                key: TutorialController().registerKey('home_egw_action'),
                child: _buildActionTile(
                  context,
                  icon: Icons.auto_stories_rounded,
                  pixelIcon: SnesPixelIconType.feather,
                  title: 'Espírito de Profecia',
                  subtitle: 'Livros de Ellen G. White',
                  badgeText: 'EGW',
                  color: Colors.orange.shade800,
                  onTap: () => EgwBooksView.navigateTo(context),
                  isGlass: isGlass,
                ),
              ),
            ];

            if (constraints.maxWidth < 340) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    tiles[i],
                    if (i < tiles.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return Column(
              children: [
                for (int i = 0; i < tiles.length; i += 2) ...[
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: tiles[i]),
                        const SizedBox(width: 12),
                        Expanded(child: tiles[i + 1]),
                      ],
                    ),
                  ),
                  if (i + 2 < tiles.length) const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Grade simplificada de acesso direto (Bíblia, Hinário, Lição e Devocional) focada em idosos.
  Widget _buildSeniorSimplifiedGrid(
    BuildContext context,
    ThemeData theme,
    bool isGlass,
    ThemeService themeService,
    double multiplier,
  ) {
    final items = [
      (
        icon: Icons.menu_book_rounded,
        title: 'Bíblia',
        subtitle: 'Ler a Palavra (${widget.bibleController.activeVersion.toUpperCase()})',
        color: theme.colorScheme.primary,
        tab: 1,
      ),
      (
        icon: Icons.music_note_rounded,
        title: 'Hinário',
        subtitle: 'Cantar e ouvir hinos',
        color: theme.colorScheme.secondary,
        tab: 2,
      ),
      (
        icon: Icons.school_rounded,
        title: 'Lição',
        subtitle: 'Escola Sabatina de hoje',
        color: theme.colorScheme.primary,
        tab: 4,
      ),
      (
        icon: Icons.volunteer_activism_rounded,
        title: 'Devocional',
        subtitle: 'Meditação diária',
        color: Colors.amber.shade800,
        tab: 3,
      ),
    ];

    Widget buildSeniorCard(({
      IconData icon,
      String title,
      String subtitle,
      Color color,
      int tab,
    }) item) {
      final accent = resolveModuleAccent(context, item.color);
      final content = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 96),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: (themeService.isAscii || themeService.isWin95 || themeService.isHoloRetro)
                      ? BorderRadius.zero
                      : BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
                ),
                child: themeService.isAscii
                    ? SnesPixelIcon(
                        type: SnesPixelIcon.fromIconData(item.icon),
                        size: 32,
                        color: accent,
                      )
                    : Icon(item.icon, color: accent, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20 * multiplier,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 13.5 * multiplier,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 20,
                color: accent,
              ),
            ],
          ),
        ),
      );

      if (themeService.isAscii) {
        return AsciiBoxSurface(
          doubleBorder: true,
          padding: EdgeInsets.zero,
          onTap: () => widget.onNavigateToTab(item.tab),
          child: content,
        );
      }

      if (themeService.isWin95) {
        return Win95BevelBox(
          padding: EdgeInsets.zero,
          onTap: () => widget.onNavigateToTab(item.tab),
          child: Material(
            type: MaterialType.transparency,
            child: content,
          ),
        );
      }

      return KairosInteractiveCard(
        onTap: () => widget.onNavigateToTab(item.tab),
        child: GlassSurface(
          borderRadius: themeService.isHoloRetro ? 0 : 20,
          padding: EdgeInsets.zero,
          onTap: () => widget.onNavigateToTab(item.tab),
          child: content,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.accessibility_new_rounded, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                themeService.isAscii ? '+--[ ACESSO DIRETO ]--+' : 'Acesso Direto (Leitura Fácil)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 17 * multiplier,
                  color: themeService.isWin95 ? Colors.white : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 560) {
              return Column(
                children: [
                  for (int i = 0; i < items.length; i += 2) ...[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: buildSeniorCard(items[i])),
                          const SizedBox(width: 14),
                          Expanded(child: buildSeniorCard(items[i + 1])),
                        ],
                      ),
                    ),
                    if (i + 2 < items.length) const SizedBox(height: 14),
                  ],
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  buildSeniorCard(items[i]),
                  if (i < items.length - 1) const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedSection({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - animation.value) * 12),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    SnesPixelIconType? pixelIcon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isGlass,
    String? badgeText,
  }) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final effectiveColor = resolveModuleAccent(context, color);

    if (themeService.isAscii) {
      return AsciiBoxSurface(
        padding: const EdgeInsets.all(14),
        label: badgeText,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SnesPixelIcon(
              type: pixelIcon ?? SnesPixelIcon.fromIconData(icon),
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 10),
            Text(
              title.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'RetroPixel',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'RetroPixel',
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      );
    }

    if (themeService.isHoloRetro) {
      const holoBlue = Color(0xFF33B5E5);
      final isDark = theme.brightness == Brightness.dark;
      final bg = isDark ? const Color(0xFF101824) : const Color(0xFFFFFFFF);
      final border = isDark ? const Color(0xFF28374A) : const Color(0xFFCBD5E1);

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: border, width: 1.0),
                left: BorderSide(color: border, width: 1.0),
                right: BorderSide(color: border, width: 1.0),
                bottom: const BorderSide(color: holoBlue, width: 3.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: holoBlue.withValues(alpha: 0.14),
                        border: Border.all(color: holoBlue, width: 1.2),
                      ),
                      child: Icon(icon, color: holoBlue, size: 20),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: holoBlue.withValues(alpha: 0.12),
                            border: Border.all(color: holoBlue, width: 0.9),
                          ),
                          child: Text(
                            badgeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: holoBlue,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final body = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: effectiveColor.withValues(alpha: 0.15),
                child: Icon(icon, color: effectiveColor, size: 21),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: effectiveColor.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: effectiveColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );

    return KairosInteractiveCard(
      onTap: onTap,
      child: GlassSurface(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: body,
      ),
    );
  }
}
