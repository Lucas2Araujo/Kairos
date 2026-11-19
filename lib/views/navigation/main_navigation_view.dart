import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/quiz_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../controllers/tutorial_controller.dart';
import '../onboarding/preferences_wizard_view.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/kairos_logo_icon.dart';
import '../../widgets/tutorial_spotlight_overlay.dart';
import '../bible/bible_reader_view.dart';
import '../classroom/classroom_view.dart';
import '../devotional/devotional_view.dart';
import '../home/home_view.dart';
import '../hymns/hymn_list_view.dart';
import '../lesson/sabbath_school_view.dart';
import '../onboarding/welcome_dialog.dart';
import '../profile/avatar_builder_modal.dart';
import '../profile/profile_dialog.dart';
import '../quiz/quiz_view.dart';
import '../search/global_search_view.dart';
import '../settings/settings_dialog.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  int? _previousIndex;
  DateTime? _lastBackPressTime;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  double _slideDirection = 1.0;

  late final BibleController _bibleController;
  late final HymnController _hymnController;
  late final DevotionalController _devotionalController;
  late final QuizController _quizController;
  late final SabbathSchoolController _sabbathSchoolController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1.0,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _bibleController = BibleController();
    _hymnController = HymnController();
    _devotionalController = DevotionalController();
    _quizController = QuizController();
    _sabbathSchoolController = SabbathSchoolController();

    _bibleController.init();
    _devotionalController.init();

    TutorialController().onNavigateToTab = _navigateToTab;
    TutorialController().onOpenPreferencesWizard = () {
      if (mounted) {
        PreferencesWizardView.show(context);
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WelcomeDialog.show(context);
      if (kIsWeb) {
        try {
          final params = AuthService.extractParamsFromUri(Uri.base);
          final joinCode = params['join'];
          if (joinCode != null && joinCode.trim().isNotEmpty && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClassroomView(initialCode: joinCode.trim()),
              ),
            );
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _bibleController.dispose();
    _hymnController.dispose();
    _devotionalController.dispose();
    _quizController.dispose();
    _sabbathSchoolController.dispose();
    super.dispose();
  }

  void _changeTab(int newIndex) {
    if (newIndex == _currentIndex) return;
    setState(() {
      _slideDirection = newIndex > _currentIndex ? 1.0 : -1.0;
      _currentIndex = newIndex;
    });
    _animController.forward(from: 0.0);
  }

  void _navigateToTab(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _previousIndex = _currentIndex;
      _slideDirection = index > _currentIndex ? 1.0 : -1.0;
      _currentIndex = index;
    });
    _animController.forward(from: 0.0);
  }

  void _returnToPreviousTab() {
    if (_previousIndex != null) {
      final target = _previousIndex!;
      setState(() {
        _slideDirection = target > _currentIndex ? 1.0 : -1.0;
        _currentIndex = target;
        _previousIndex = null;
      });
      _animController.forward(from: 0.0);
    }
  }

  void _handleBackNavigation() {
    if (_currentIndex != 0) {
      if (_currentIndex == 2) {
        final dynamic hc = _hymnController;
        bool hasFilter = false;
        try {
          hasFilter = hc.hasActiveCategoryOrTheme == true;
        } catch (_) {
          hasFilter = _hymnController.selectedCategory != null;
        }
        if (hasFilter) {
          try {
            hc.clearCategoryOrThemeFilter();
          } catch (_) {
            _hymnController.selectCategory(null);
          }
          return;
        }
      }
      _changeTab(0);
      return;
    }

    final now = DateTime.now();
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
    } else {
      _lastBackPressTime = now;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volte novamente para sair do app'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  final GlobalKey _stackKey = GlobalKey();

  Widget _buildAnimatedStack(List<Widget> screens) {
    return KeyedSubtree(
      key: _stackKey,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: FractionalTranslation(
              translation: Offset(_slideDirection * 0.035 * (1.0 - _fadeAnimation.value), 0.0),
              child: child,
            ),
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
    );
  }

  static const List<Win95TaskbarItem> _retroNavItems = [
    Win95TaskbarItem(
      label: 'Início',
      icon: Icons.home_outlined,
      pixelIcon: Win95PixelIconType.computer,
    ),
    Win95TaskbarItem(
      label: 'Bíblia',
      icon: Icons.book_outlined,
      pixelIcon: Win95PixelIconType.bibleBook,
    ),
    Win95TaskbarItem(
      label: 'Hinário',
      icon: Icons.music_note_outlined,
      pixelIcon: Win95PixelIconType.hymnalMusic,
    ),
    Win95TaskbarItem(
      label: 'Meditação',
      icon: Icons.volunteer_activism_outlined,
      pixelIcon: Win95PixelIconType.notepad,
    ),
    Win95TaskbarItem(
      label: 'Lição',
      icon: Icons.school_outlined,
      pixelIcon: Win95PixelIconType.sabbathSchool,
    ),
    Win95TaskbarItem(
      label: 'Quizzes',
      icon: Icons.quiz_outlined,
      pixelIcon: Win95PixelIconType.quizGame,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isGlass = themeService.hasAtmosphericBackground;
        final hasGlobalBg = themeService.hasGlobalBackgroundShell;
        final bool isSimplified = themeService.simplifiedHomeMode;
        final List<Win95TaskbarItem> visibleNavItems = isSimplified
            ? _retroNavItems.sublist(0, 5)
            : _retroNavItems;
        final int activeTabIndex = (isSimplified && _currentIndex >= 5) ? 0 : _currentIndex;
        if (isSimplified && _currentIndex >= 5) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _currentIndex >= 5) {
              setState(() => _currentIndex = 0);
            }
          });
        }
        final double blur = (themeService.isAnyGlass && themeService.glassBlurEnabled)
            ? (themeService.isAppleGlass ? 24.0 : 20.0)
            : 0.0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return TutorialSpotlightOverlay(
          child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleBackNavigation();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 720;

            final screens = [
              HomeView(
                bibleController: _bibleController,
                hymnController: _hymnController,
                devotionalController: _devotionalController,
                sabbathSchoolController: _sabbathSchoolController,
                onNavigateToTab: _navigateToTab,
              ),
              BibleReaderView(
                controller: _bibleController,
                onBackToPrevious: _previousIndex != null ? _returnToPreviousTab : null,
              ),
              HymnListView(
                controller: _hymnController,
                bibleController: _bibleController,
                onNavigateToTab: _navigateToTab,
              ),
              DevotionalView(
                controller: _devotionalController,
                bibleController: _bibleController,
                onNavigateToTab: _navigateToTab,
              ),
              SabbathSchoolView(
                controller: _sabbathSchoolController,
                bibleController: _bibleController,
                onNavigateToTab: _navigateToTab,
              ),
              QuizView(controller: _quizController),
            ];

            if (isDesktop) {
              if (_currentIndex == 0) {
                return Scaffold(
                  backgroundColor: hasGlobalBg ? Colors.transparent : null,
                  body: _buildAnimatedStack(screens),
                );
              }

              final isRight = themeService.isTabletNavRight;
              final isCollapsible = themeService.isTabletNavCollapsible;
              final isCollapsed = isCollapsible && themeService.isTabletNavCollapsed;

              Widget rail = LayoutBuilder(
                builder: (context, constraints) {
                  const railDestinations = [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Início', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.book_outlined),
                      selectedIcon: Icon(Icons.book),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Bíblia', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.music_note_outlined),
                      selectedIcon: Icon(Icons.music_note),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Hinário', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.volunteer_activism_outlined),
                      selectedIcon: Icon(Icons.volunteer_activism),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Meditação', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Lição', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.quiz_outlined),
                      selectedIcon: Icon(Icons.quiz),
                      label: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('Quizzes', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ];

                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: NavigationRail(
                          minWidth: 108,
                          backgroundColor: isGlass ? Colors.transparent : null,
                          selectedIndex: activeTabIndex,
                          onDestinationSelected: _changeTab,
                          labelType: NavigationRailLabelType.all,
                          leading: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCollapsible)
                                  IconButton(
                                    icon: Icon(
                                      isRight ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    tooltip: 'Recolher Barra',
                                    onPressed: () => themeService.setTabletNavCollapsed(true),
                                  ),
                                KairosLogoIcon(
                                  size: 32,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                          destinations: isSimplified
                              ? railDestinations.sublist(0, 5)
                              : railDestinations,
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            tooltip: 'Busca Global',
                            onPressed: () {
                              GlobalSearchView.show(
                                context,
                                bibleController: _bibleController,
                                hymnController: _hymnController,
                                devotionalController: _devotionalController,
                                sabbathSchoolController: _sabbathSchoolController,
                                onNavigateToTab: _navigateToTab,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            tooltip: 'Perfil e Conta',
                            onPressed: () => ProfileDialog.show(context),
                            icon: AnimatedBuilder(
                              animation: Listenable.merge([AuthService(), GamificationService()]),
                              builder: (context, _) {
                                final auth = AuthService();
                                final gamification = GamificationService();
                                final user = auth.currentUser;
                                if (!gamification.useCustomAvatar &&
                                    auth.isAuthenticated &&
                                    user != null &&
                                    user.avatarUrl.isNotEmpty) {
                                  return CircleAvatar(
                                    radius: 13,
                                    backgroundImage: NetworkImage(user.avatarUrl),
                                    onBackgroundImageError: (_, __) {},
                                  );
                                }
                                return AvatarCustomWidget(
                                  config: gamification.avatarConfig,
                                  size: 28,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined),
                            tooltip: 'Configurações e Temas',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => const SettingsDialog(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
                      ),
                    ),
                  );
                },
              );

              if (isGlass) {
                Widget railBox = Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.45),
                    border: Border(
                      right: !isRight
                          ? BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.6),
                              width: 1.0,
                            )
                          : BorderSide.none,
                      left: isRight
                          ? BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.6),
                              width: 1.0,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: rail,
                );
                if (blur > 0.0) {
                  railBox = ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: railBox,
                    ),
                  );
                }
                rail = railBox;
              }

              final Widget animatedRail = AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isCollapsed ? 0 : 108,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 108,
                    maxWidth: 108,
                    alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
                    child: rail,
                  ),
                ),
              );

              Widget contentStack = _buildAnimatedStack(screens);

              if (isCollapsible) {
                contentStack = Stack(
                  children: [
                    contentStack,
                    if (isCollapsed)
                      Positioned(
                        top: 14,
                        left: isRight ? null : 10,
                        right: isRight ? 10 : null,
                        child: Material(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                          shape: const CircleBorder(),
                          elevation: 3,
                          child: IconButton(
                            icon: Icon(
                              isRight ? Icons.menu_open_rounded : Icons.menu_rounded,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: 'Abrir Barra de Atalhos',
                            onPressed: () => themeService.setTabletNavCollapsed(false),
                          ),
                        ),
                      ),
                  ],
                );
              }

              final tabletBody = GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  if (!isCollapsible) return;
                  final velocity = details.primaryVelocity ?? 0.0;
                  if (isRight) {
                    if (velocity < -200) {
                      themeService.setTabletNavCollapsed(false);
                    } else if (velocity > 200) {
                      themeService.setTabletNavCollapsed(true);
                    }
                  } else {
                    if (velocity > 200) {
                      themeService.setTabletNavCollapsed(false);
                    } else if (velocity < -200) {
                      themeService.setTabletNavCollapsed(true);
                    }
                  }
                },
                child: Row(
                  children: isRight
                      ? [
                          Expanded(child: contentStack),
                          if (!isGlass && !isCollapsed) const VerticalDivider(thickness: 1, width: 1),
                          animatedRail,
                        ]
                      : [
                          animatedRail,
                          if (!isGlass && !isCollapsed) const VerticalDivider(thickness: 1, width: 1),
                          Expanded(child: contentStack),
                        ],
                ),
              );

              return Scaffold(
                backgroundColor: hasGlobalBg ? Colors.transparent : null,
                body: tabletBody,
              );
            }

            if (_currentIndex == 0 && !themeService.isWin95) {
              return Scaffold(
                backgroundColor: hasGlobalBg ? Colors.transparent : null,
                body: _buildAnimatedStack(screens),
              );
            }

            final navBar = KairosQuickNavBar(
              items: visibleNavItems,
              selectedIndex: activeTabIndex,
              onSelectTab: _changeTab,
              floating: themeService.floatingNavBar,
              onOpenSearch: () {
                GlobalSearchView.show(
                  context,
                  bibleController: _bibleController,
                  hymnController: _hymnController,
                  devotionalController: _devotionalController,
                  sabbathSchoolController: _sabbathSchoolController,
                  onNavigateToTab: _navigateToTab,
                );
              },
              onOpenProfile: () => ProfileDialog.show(context),
              onOpenSettings: () {
                showDialog(
                  context: context,
                  builder: (_) => const SettingsDialog(),
                );
              },
            );

            return Scaffold(
              backgroundColor: hasGlobalBg ? Colors.transparent : null,
              extendBody: themeService.floatingNavBar,
              body: _buildAnimatedStack(screens),
              bottomNavigationBar: navBar,
            );
          },
        ),
      ),
    );
      },
    );
  }
}
