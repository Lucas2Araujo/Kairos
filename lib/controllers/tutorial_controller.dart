import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TutorialMode { none, quick, detailed }

class TutorialStep {
  final String id;
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final int? targetTabIndex;

  const TutorialStep({
    required this.id,
    required this.title,
    required this.description,
    this.targetKey,
    this.targetTabIndex,
  });
}

/// Controlador global do tutorial guiado interativo (Coachmarks / Spotlight).
class TutorialController extends ChangeNotifier {
  static final TutorialController _instance = TutorialController._internal();
  factory TutorialController() => _instance;
  TutorialController._internal();

  static const String _prefCompletedKey = 'kairos_tutorial_completed_v2';

  TutorialMode _mode = TutorialMode.none;
  int _currentIndex = 0;
  List<TutorialStep> _steps = const [];
  final Map<String, GlobalKey> _registeredKeys = {};

  void Function(int tabIndex)? onNavigateToTab;
  VoidCallback? onOpenPreferencesWizard;

  TutorialMode get mode => _mode;
  bool get isActive => _mode != TutorialMode.none && _steps.isNotEmpty && _currentIndex < _steps.length;
  int get currentIndex => _currentIndex;
  int get totalSteps => _steps.length;
  TutorialStep? get currentStep => isActive ? _steps[_currentIndex] : null;

  GlobalKey registerKey(String id) {
    return _registeredKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tutorial_$id'));
  }

  GlobalKey? getKey(String id) => _registeredKeys[id];

  Future<bool> hasCompletedTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefCompletedKey) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefCompletedKey, true);
  }

  void startTutorial(TutorialMode mode) {
    if (mode == TutorialMode.none) {
      skipTutorial();
      return;
    }

    _mode = mode;
    _currentIndex = 0;

    final quickSteps = [
      TutorialStep(
        id: 'home_search',
        title: 'Busca Global',
        description: 'Pesquise rapidamente versículos, hinos, lições e livros em um só lugar.',
        targetKey: _registeredKeys['home_search'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_daily_verse',
        title: 'Versículo & Meditação do Dia',
        description: 'Toque aqui para abrir a meditação completa de hoje e registrar sua leitura.',
        targetKey: _registeredKeys['home_daily_verse'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_bible',
        title: 'Bíblia Sagrada',
        description: 'Aqui você lê traduções, compara versículos, acessa comentários e referências cruzadas.',
        targetTabIndex: 1,
      ),
      TutorialStep(
        id: 'home_lesson',
        title: 'Escola Sabatina',
        description: 'Estude a lição diária com citações interativas da Bíblia e do Espírito de Profecia.',
        targetTabIndex: 4,
      ),
    ];

    final detailedExtras = [
      TutorialStep(
        id: 'home_hymns',
        title: 'Hinário Adventista',
        description: 'Ouça áudios oficiais, instrumentais e compare letras de 1996 e 2022.',
        targetTabIndex: 2,
      ),
      TutorialStep(
        id: 'home_meditation',
        title: 'Meditação Diária',
        description: 'Leia a meditação matinal de hoje e acompanhe o pôr do sol da sua região.',
        targetTabIndex: 3,
      ),
      TutorialStep(
        id: 'home_quizzes',
        title: 'Quizzes & Desafios',
        description: 'Teste seus conhecimentos bíblicos e ganhe gotas de azeite.',
        targetTabIndex: 5,
      ),
    ];

    _steps = mode == TutorialMode.quick ? quickSteps : [...quickSteps, ...detailedExtras];
    _navigateToCurrentStepTab();
    notifyListeners();
  }

  void _navigateToCurrentStepTab() {
    final tab = currentStep?.targetTabIndex;
    if (tab != null) {
      onNavigateToTab?.call(tab);
    }
  }

  void nextStep() {
    if (!isActive) return;
    if (_currentIndex + 1 < _steps.length) {
      _currentIndex++;
      _navigateToCurrentStepTab();
      notifyListeners();
    } else {
      completeTutorial();
    }
  }

  void skipTutorial() {
    _mode = TutorialMode.none;
    _steps = const [];
    _currentIndex = 0;
    markCompleted();
    notifyListeners();
  }

  void completeTutorial() {
    _mode = TutorialMode.none;
    _steps = const [];
    _currentIndex = 0;
    markCompleted();
    notifyListeners();
    onOpenPreferencesWizard?.call();
  }
}
