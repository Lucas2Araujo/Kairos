import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/controllers/devotional_controller.dart';
import 'package:kairos_web/controllers/quiz_controller.dart';
import 'package:kairos_web/controllers/sabbath_school_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/data/repositories/pericope_repository.dart';
import 'package:kairos_web/data/repositories/quiz_repository.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/devotional.dart';
import 'package:kairos_web/models/study_models.dart';
import 'package:kairos_web/models/quiz_question.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/services/auth_service.dart';
import 'package:kairos_web/services/devotional_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeQuizRepository extends QuizRepository {
  final List<QuizQuestion> _questions;
  _FakeQuizRepository(this._questions);

  @override
  Future<List<QuizQuestion>> getQuestions({String category = 'adultos'}) async {
    return _questions;
  }
}

class _FakeDevotionalService extends DevotionalService {
  final Devotional devotionalToReturn;
  _FakeDevotionalService({required this.devotionalToReturn});

  @override
  Future<Devotional> getDevotional(String dateStr, {String category = 'jovem'}) async {
    return devotionalToReturn;
  }
}

class _FakeSabbathSchoolService extends SabbathSchoolService {
  @override
  Future<String> getNote(String dayId) async => 'Note for $dayId';

  @override
  Future<SSDay?> getDayContent(String dayId, {String? lessonId, String? readPath}) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
  });

  group('GamificationService - Sunday Start & addXp', () {
    test('weeklyActivity starts on Sunday (index 0 = Sunday, index 6 = Saturday)', () async {
      final service = GamificationService();
      await service.init();

      // Today's Sunday-based index is weekday % 7
      // DateTime.sunday = 7 -> 7 % 7 = 0
      // DateTime.monday = 1 -> 1 % 7 = 1
      // DateTime.saturday = 6 -> 6 % 7 = 6
      final todayWeekday = DateTime.now().weekday;
      final expectedTodayIndex = todayWeekday % 7;

      await service.recordReading(category: 'biblia');

      expect(service.hasReadToday, isTrue);
      expect(service.weeklyActivity[expectedTodayIndex], isTrue);
      expect(service.weeklyActivity.length, equals(7));
    });

    test('addXp increments totalXp and persists to storage', () async {
      final service = GamificationService();
      await service.init();
      expect(service.totalXp, equals(0));

      await service.addXp(50);
      expect(service.totalXp, equals(50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('gamification_total_xp'), equals(50));

      // Ignores zero and negative amounts
      await service.addXp(0);
      expect(service.totalXp, equals(50));

      await service.addXp(-20);
      expect(service.totalXp, equals(50));

      // Additional positive XP adds up
      await service.addXp(30);
      expect(service.totalXp, equals(80));
    });
  });

  group('Gamification Triggers in Controllers', () {
    test('QuizController triggers recordReading and addXp when completed', () async {
      final questions = [
        const QuizQuestion(
          id: 'q1',
          dayId: 'd1',
          quarterlyId: '2026-q1',
          question: 'Pergunta 1',
          options: ['A', 'B'],
          correctOption: 0,
          explanation: 'Exp',
        ),
      ];

      final quizCtrl = QuizController(repository: _FakeQuizRepository(questions));
      await quizCtrl.init(mode: 'maratona');

      expect(quizCtrl.questions.length, equals(1));
      expect(quizCtrl.currentIndex, equals(0));

      // Select correct answer
      quizCtrl.selectOption(0);
      quizCtrl.submitAnswer();
      expect(quizCtrl.score, equals(1));
      expect(quizCtrl.totalXp, equals(10));

      final gamification = GamificationService();
      expect(gamification.hasReadToday, isFalse);

      // Finish quiz by calling nextQuestion on last question
      quizCtrl.nextQuestion();
      expect(quizCtrl.isCompleted, isTrue);

      // Wait a microtask for async trigger
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(gamification.hasReadToday, isTrue);
      // recordReading grants 10 XP + addXp(_totalXp = 10) = 20 XP
      expect(gamification.totalXp, equals(20));
    });

    test('DevotionalController triggers recordReading when devotional is loaded', () async {
      const fakeDevotional = Devotional(
        publishedAt: '2026-10-22',
        title: 'Maná Matinal',
        verseReference: 'Salmos 23:1',
        verseText: 'O Senhor é meu pastor',
        content: 'Reflexão diária',
        category: 'jovem',
      );

      final devoCtrl = DevotionalController(
        service: _FakeDevotionalService(devotionalToReturn: fakeDevotional),
      );

      final gamification = GamificationService();
      expect(gamification.hasReadToday, isFalse);

      await devoCtrl.loadDevotional();

      expect(devoCtrl.currentDevotional, isNotNull);
      expect(gamification.hasReadToday, isTrue);
      expect(gamification.totalXp, equals(10));
    });

    test('SabbathSchoolController triggers recordReading on selectDay', () async {
      final ssCtrl = SabbathSchoolController(service: _FakeSabbathSchoolService());
      const day = SSDay(
        id: '2026-q1-01-d1',
        lessonId: '2026-q1-01',
        title: 'Sábado',
        date: '2026-10-22',
      );

      final gamification = GamificationService();
      expect(gamification.hasReadToday, isFalse);

      await ssCtrl.selectDay(day);

      expect(gamification.hasReadToday, isTrue);
      expect(gamification.totalXp, equals(10));
    });
  });

  group('AuthService Tests', () {
    test('extractAccessTokenFromUri parses query parameter correctly', () {
      final uri = Uri.parse('https://example.com/callback?access_token=test-query-token-123&token_type=bearer');
      final token = AuthService.extractAccessTokenFromUri(uri);
      expect(token, equals('test-query-token-123'));
    });

    test('extractAccessTokenFromUri parses fragment correctly', () {
      final uri = Uri.parse('nhaapp://login-callback#access_token=test-fragment-token-456&token_type=bearer');
      final token = AuthService.extractAccessTokenFromUri(uri);
      expect(token, equals('test-fragment-token-456'));
    });

    test('extractAccessTokenFromUri parses fragment with slash correctly', () {
      final uri = Uri.parse('nhaapp://login-callback/#access_token=test-slash-token-789&token_type=bearer');
      final token = AuthService.extractAccessTokenFromUri(uri);
      expect(token, equals('test-slash-token-789'));
    });

    test('extractAccessTokenFromUri returns null when token is missing', () {
      final uri = Uri.parse('nhaapp://login-callback#error=access_denied');
      final token = AuthService.extractAccessTokenFromUri(uri);
      expect(token, isNull);
    });

    test('extractParamsFromUri parses both access_token and refresh_token from fragment', () {
      final uri = Uri.parse('nhaapp://login-callback#access_token=acc123&refresh_token=ref456&token_type=bearer');
      final params = AuthService.extractParamsFromUri(uri);
      expect(params['access_token'], equals('acc123'));
      expect(params['refresh_token'], equals('ref456'));
    });

    test('extractParamsFromUri parses authorization code for PKCE or Code flow', () {
      final uri = Uri.parse('kairosapp://login-callback?code=code-xyz-987');
      final params = AuthService.extractParamsFromUri(uri);
      expect(params['code'], equals('code-xyz-987'));
    });

    test('signOut clears token and user in memory and prefs', () async {
      final auth = AuthService();
      await auth.signOut();
      expect(auth.currentUser, isNull);
      expect(auth.accessToken, isNull);
      expect(auth.refreshToken, isNull);
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('User Preferences & Controller Stability Tests', () {
    test('ThemeService normalizes jovens to jovem for Devotional category and persists', () async {
      final theme = ThemeService();
      await theme.init();
      await theme.setDefaultDevotionalCategory('mulher');
      await theme.setDefaultDevotionalCategory('jovens');
      expect(theme.defaultDevotionalCategory, equals('jovem'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('default_devo_category'), equals('jovem'));
    });

    test('ThemeService normalizes jovem to jovens for Sabbath School category and persists', () async {
      final theme = ThemeService();
      await theme.init();
      await theme.setDefaultSabbathSchoolCategory('adultos');
      await theme.setDefaultSabbathSchoolCategory('jovem');
      expect(theme.defaultSabbathSchoolCategory, equals('jovens'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('default_ss_category'), equals('jovens'));
    });

    test('DevotionalController does not reset selectedCategory upon visual theme changes', () async {
      final theme = ThemeService();
      await theme.init();
      theme.setDefaultDevotionalCategory('jovem');

      const devo = Devotional(
        publishedAt: '2026-10-28',
        title: 'Título Diário',
        verseText: 'Texto',
        verseReference: 'Ref',
        author: 'Autor',
        content: 'Conteúdo',
      );
      final ctrl = DevotionalController(service: _FakeDevotionalService(devotionalToReturn: devo));
      expect(ctrl.selectedCategory, equals('jovem'));

      // User switches to reading 'diario'
      await ctrl.selectCategory('diario');
      expect(ctrl.selectedCategory, equals('diario'));

      // User changes unrelated visual settings in SettingsDialog
      theme.setColorSeed('purple');
      theme.setThemePreset('sepia');
      theme.setFontSizeMultiplier(1.2);

      // Category MUST remain 'diario', NOT reset to default 'jovem'!
      expect(ctrl.selectedCategory, equals('diario'));

      // Only changing the actual default category updates the controller
      await theme.setDefaultDevotionalCategory('mulher');
      expect(ctrl.selectedCategory, equals('mulher'));

      ctrl.dispose();
    });

    test('SabbathSchoolController does not reset category upon visual theme changes', () async {
      final theme = ThemeService();
      await theme.init();
      await theme.setDefaultSabbathSchoolCategory('adultos');

      final ctrl = SabbathSchoolController(service: _FakeSabbathSchoolService());
      expect(ctrl.category, equals('adultos'));

      // User switches to reading 'jovens'
      ctrl.setCategory('jovens');
      expect(ctrl.category, equals('jovens'));

      // User changes visual settings
      theme.setColorSeed('gold');
      theme.setFontFamily('Montserrat');
      theme.setContinuousReading(true);

      // Category MUST remain 'jovens', NOT reset to 'adultos'!
      expect(ctrl.category, equals('jovens'));

      // Changing actual default updates controller
      await theme.setDefaultSabbathSchoolCategory('jovens');
      expect(ctrl.category, equals('jovens'));
      await theme.setDefaultSabbathSchoolCategory('adultos');
      expect(ctrl.category, equals('adultos'));

      ctrl.dispose();
    });

    test('ThemeService correctly saves seed color and clears custom color', () async {
      final theme = ThemeService();
      await theme.init();

      await theme.setCustomColor(const Color(0xFF123456));
      expect(theme.colorKey, equals('custom'));
      expect(theme.currentColor, equals(const Color(0xFF123456)));

      // Switching to standard seed color clears custom color value and persists
      await theme.setColorSeed('sapphire');
      expect(theme.colorKey, equals('sapphire'));
      expect(theme.currentColor, equals(ThemeService.colorSeeds['sapphire']));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('color_key'), equals('sapphire'));
      expect(prefs.getInt('custom_color_val'), isNull);
    });

    test('ThemeService preserves themeStyle without legacy is_sepia overriding', () async {
      final theme = ThemeService();
      await theme.setThemeStyle(AppThemeStyle.appleGlass);
      expect(theme.themeStyle, equals(AppThemeStyle.appleGlass));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_style'), equals('appleGlass'));

      // Re-initialize theme to simulate app restart
      await theme.init();
      expect(theme.themeStyle, equals(AppThemeStyle.appleGlass));
    });

    test('BibleController saves and restores last read position', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bible_last_book_id', 43); // João
      await prefs.setInt('bible_last_chapter', 3);

      final ctrl = BibleController(
        repository: _FakeBibleRepository(),
        pericopeRepository: _FakePericopeRepository(),
      );
      await ctrl.init();

      expect(ctrl.selectedBook?.id, equals(43));
      expect(ctrl.selectedChapter, equals(3));
      expect(ctrl.lastReadReference, equals('João 3'));

      // User changes to another chapter
      await ctrl.selectChapter(4);
      expect(prefs.getInt('bible_last_chapter'), equals(4));
      expect(ctrl.lastReadReference, equals('João 4'));
    });
  });
}

class _FakePericopeRepository extends PericopeRepository {
  @override
  Future<List<Pericope>> getPericopes(int bookId, int chapter) async => [];
}

class _FakeBibleRepository extends BibleRepository {
  @override
  Future<List<BibleBook>> getBooks() async => [
    const BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
    const BibleBook(id: 43, name: 'João', testament: 'NT', chaptersCount: 21),
  ];

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String bookName = ''}) async => [
    BibleVerse(id: 1, bookId: bookId, bookName: bookName, chapter: chapter, verse: 1, text: 'No princípio era o Verbo.'),
  ];

  @override
  Future<Map<int, String>> getChapterHighlights(int bookId, int chapter) async => {};
}
