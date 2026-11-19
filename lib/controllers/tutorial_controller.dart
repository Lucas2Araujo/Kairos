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
        id: 'home_gamification',
        title: 'Ofensiva & Azeite Diário',
        description:
            'Acompanhe sua lamparina, streak diário e missões espirituais tocando neste indicador.',
        targetKey: _registeredKeys['home_gamification'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_search',
        title: 'Busca Global Unificada',
        description:
            'Pesquise rapidamente versículos, hinos, meditações e lições em todo o acervo offline.',
        targetKey: _registeredKeys['home_search'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_daily_verse',
        title: 'Versículo & Meditação do Dia',
        description:
            'Toque aqui para abrir a meditação completa, pôr do sol do sábado ou compartilhar a imagem.',
        targetKey: _registeredKeys['home_daily_verse'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_bible',
        title: 'Bíblia Sagrada Interativa',
        description:
            'Troque de tradução (ARA, NVI, ACF...), compare versões, marque versículos e estude comentários.',
        targetKey: _registeredKeys['tab_bible_header'],
        targetTabIndex: 1,
      ),
      TutorialStep(
        id: 'home_lesson',
        title: 'Escola Sabatina Diária',
        description:
            'Estude a lição de Jovens ou Adultos com referências bíblicas, resumos EGW e notas.',
        targetKey: _registeredKeys['tab_lesson_header'],
        targetTabIndex: 4,
      ),
      TutorialStep(
        id: 'home_quizzes',
        title: 'Quizzes & Desafios',
        description:
            'Teste seus conhecimentos bíblicos e da lição semanal para manter a chama acesa.',
        targetKey: _registeredKeys['tab_quiz_hub'],
        targetTabIndex: 5,
      ),
    ];

    final detailedExtras = [
      TutorialStep(
        id: 'home_reading_plans',
        title: 'Planos de Leitura Bíblica',
        description:
            'Siga jornadas anuais ou temáticas com acompanhamento diário automático de capítulos.',
        targetKey: _registeredKeys['home_reading_plans_action'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_classroom',
        title: 'Turmas & Classes',
        description:
            'Entre ou crie uma Classe Jovem / Pequeno Grupo para estudar em comunidade.',
        targetKey: _registeredKeys['home_classroom_action'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_egw',
        title: 'Biblioteca Espírito de Profecia',
        description:
            'Leia e baixe livros completos de Ellen G. White em português para consulta offline.',
        targetKey: _registeredKeys['home_egw_action'],
        targetTabIndex: 0,
      ),
      TutorialStep(
        id: 'home_hymns',
        title: 'Hinário Adventista (2022 e 1996)',
        description:
            'Alterne entre as duas edições oficiais, reproduza áudios cantados ou playbacks offline.',
        targetKey: _registeredKeys['tab_hymns_header'],
        targetTabIndex: 2,
      ),
      TutorialStep(
        id: 'home_meditation',
        title: 'Meditação & Pôr do Sol',
        description:
            'Leia a devocional matinal, jovens ou da mulher e confira o pôr do sol para sua cidade.',
        targetKey: _registeredKeys['tab_devotional_header'],
        targetTabIndex: 3,
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

  /// Volta ao passo anterior do guia interativo.
  void previousStep() {
    if (!isActive || _currentIndex <= 0) return;
    _currentIndex--;
    _navigateToCurrentStepTab();
    notifyListeners();
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
    onNavigateToTab?.call(0);
    markCompleted();
    notifyListeners();
  }

  void completeTutorial() {
    _mode = TutorialMode.none;
    _steps = const [];
    _currentIndex = 0;
    onNavigateToTab?.call(0);
    markCompleted();
    notifyListeners();
    onOpenPreferencesWizard?.call();
  }
}
