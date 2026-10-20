import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/quiz_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../bible/bible_reader_view.dart';
import '../devotional/devotional_view.dart';
import '../home/home_view.dart';
import '../hymns/hymn_list_view.dart';
import '../lesson/sabbath_school_view.dart';
import '../profile/profile_dialog.dart';
import '../quiz/quiz_view.dart';
import '../search/global_search_view.dart';
import '../settings/settings_dialog.dart';
import '../../services/auth_service.dart';

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
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
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
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: _buildAnimatedStack(screens),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: _buildAnimatedStack(screens),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
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
          ),
        );
      },
    );
  }
}
