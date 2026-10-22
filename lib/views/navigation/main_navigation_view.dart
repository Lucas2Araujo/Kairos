import 'dart:ui';
import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/quiz_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../bible/bible_reader_view.dart';
import '../devotional/devotional_view.dart';
import '../home/home_view.dart';
import '../hymns/hymn_list_view.dart';
import '../lesson/sabbath_school_view.dart';
import '../onboarding/welcome_dialog.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WelcomeDialog.show(context);
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

  Widget _buildAnimatedStack(List<Widget> screens) {
    return AnimatedBuilder(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isGlass = themeService.isAnyGlass;
        final double blur = themeService.glassBlurEnabled
            ? (themeService.isAppleGlass ? 24.0 : 20.0)
            : 0.0;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return LayoutBuilder(
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
              Widget rail = NavigationRail(
                backgroundColor: isGlass ? Colors.transparent : null,
                selectedIndex: _currentIndex,
                onDestinationSelected: _changeTab,
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Icon(
                    Icons.auto_stories,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Início'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.book_outlined),
                    selectedIcon: Icon(Icons.book),
                    label: Text('Bíblia'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.music_note_outlined),
                    selectedIcon: Icon(Icons.music_note),
                    label: Text('Hinário'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.volunteer_activism_outlined),
                    selectedIcon: Icon(Icons.volunteer_activism),
                    label: Text('Meditação'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school),
                    label: Text('Lição'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.quiz_outlined),
                    selectedIcon: Icon(Icons.quiz),
                    label: Text('Quizzes'),
                  ),
                ],
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
                              animation: AuthService(),
                              builder: (context, _) {
                                final auth = AuthService();
                                final user = auth.currentUser;
                                if (auth.isAuthenticated) {
                                  if (user != null && user.avatarUrl.isNotEmpty) {
                                    return CircleAvatar(
                                      radius: 13,
                                      backgroundImage: NetworkImage(user.avatarUrl),
                                      onBackgroundImageError: (_, __) {},
                                    );
                                  }
                                  return const Icon(Icons.account_circle);
                                }
                                return const Icon(Icons.account_circle_outlined);
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
              );

              if (isGlass) {
                rail = ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.45),
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: rail,
                    ),
                  ),
                );
              }

              return Scaffold(
                backgroundColor: isGlass ? Colors.transparent : null,
                body: Row(
                  children: [
                    rail,
                    if (!isGlass) const VerticalDivider(thickness: 1, width: 1),
                    Expanded(
                      child: _buildAnimatedStack(screens),
                    ),
                  ],
                ),
              );
            }

            Widget navBar = NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: isGlass ? Colors.transparent : null,
                indicatorColor: isGlass
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                    : null,
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    );
                  }
                  return const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  );
                }),
              ),
              child: NavigationBar(
                height: 65,
                backgroundColor: isGlass ? Colors.transparent : null,
                elevation: isGlass ? 0 : null,
                selectedIndex: _currentIndex,
                onDestinationSelected: _changeTab,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Início',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.book_outlined),
                    selectedIcon: Icon(Icons.book),
                    label: 'Bíblia',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.music_note_outlined),
                    selectedIcon: Icon(Icons.music_note),
                    label: 'Hinário',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.volunteer_activism_outlined),
                    selectedIcon: Icon(Icons.volunteer_activism),
                    label: 'Meditação',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.school_outlined),
                    selectedIcon: Icon(Icons.school),
                    label: 'Lição',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.quiz_outlined),
                    selectedIcon: Icon(Icons.quiz),
                    label: 'Quizzes',
                  ),
                ],
              ),
            );

            if (isGlass) {
              navBar = ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.55),
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.7),
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: navBar,
                  ),
                ),
              );
            }

            return Scaffold(
              backgroundColor: isGlass ? Colors.transparent : null,
              body: _buildAnimatedStack(screens),
              bottomNavigationBar: navBar,
            );
          },
        );
      },
    );
  }
}
