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
import '../quiz/quiz_view.dart';
import '../settings/settings_dialog.dart';

class MainNavigationView extends StatefulWidget {
  const MainNavigationView({super.key});

  @override
  State<MainNavigationView> createState() => _MainNavigationViewState();
}

class _MainNavigationViewState extends State<MainNavigationView> {
  int _currentIndex = 0;
  int? _previousIndex;

  late final BibleController _bibleController;
  late final HymnController _hymnController;
  late final DevotionalController _devotionalController;
  late final QuizController _quizController;
  late final SabbathSchoolController _sabbathSchoolController;

  @override
  void initState() {
    super.initState();
    _bibleController = BibleController();
    _hymnController = HymnController();
    _devotionalController = DevotionalController();
    _quizController = QuizController();
    _sabbathSchoolController = SabbathSchoolController();
  }

  @override
  void dispose() {
    _bibleController.dispose();
    _hymnController.dispose();
    _devotionalController.dispose();
    _quizController.dispose();
    _sabbathSchoolController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
  }

  void _returnToPreviousTab() {
    if (_previousIndex != null) {
      setState(() {
        _currentIndex = _previousIndex!;
        _previousIndex = null;
      });
    }
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
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
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
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Configurações e Temas',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const SettingsDialog(),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
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
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
              },
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
