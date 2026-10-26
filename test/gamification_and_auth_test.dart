import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/devotional_controller.dart';
import 'package:kairos_web/controllers/quiz_controller.dart';
import 'package:kairos_web/controllers/sabbath_school_controller.dart';
import 'package:kairos_web/data/repositories/quiz_repository.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';
import 'package:kairos_web/models/devotional.dart';
import 'package:kairos_web/models/quiz_question.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/services/auth_service.dart';
import 'package:kairos_web/services/devotional_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
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

    test('signOut clears token and user in memory and prefs', () async {
      final auth = AuthService();
      await auth.signOut();
      expect(auth.currentUser, isNull);
      expect(auth.accessToken, isNull);
      expect(auth.isAuthenticated, isFalse);
    });
  });
}
