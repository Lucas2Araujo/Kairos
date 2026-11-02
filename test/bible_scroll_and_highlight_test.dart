import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBibleRepo extends BibleRepository {
  @override
  Future<List<BibleBook>> getBooks({String? testament}) async {
    return [
      const BibleBook(id: 1, name: 'Gênesis', testament: 'VT', chaptersCount: 50),
      const BibleBook(id: 40, name: 'Mateus', testament: 'NT', chaptersCount: 28),
    ];
  }

  @override
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String? bookName}) async {
    return List.generate(
      15,
      (i) => BibleVerse(
        id: i + 1,
        bookId: bookId,
        bookName: bookName ?? 'Gênesis',
        chapter: chapter,
        verse: i + 1,
        text: 'Versículo ${i + 1}',
      ),
    );
  }

  @override
  Future<Map<int, String>> getChapterHighlights(int bookId, int chapter) async {
    return {
      2: '#FFFFEB3B',
      5: '#90CAF9',
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('GamificationService resetForTesting', () {
    test('resetForTesting executes without errors', () async {
      final gamification = GamificationService();
      await gamification.resetForTesting();
      expect(gamification.totalXp, 0);
      expect(gamification.currentStreak, 0);
    });
  });

  group('BibleController Multiple Verses & Target Range', () {
    test('jumpToVerse sets single verse target correctly', () async {
      final controller = BibleController(repository: _FakeBibleRepo());
      await controller.jumpToVerse('Gn', 1, 3);

      expect(controller.targetVerse, equals(3));
      expect(controller.targetVerses, equals({3}));
    });

    test('jumpToVerse sets multiple verses range correctly (e.g. Gn 15:4-9)', () async {
      final controller = BibleController(repository: _FakeBibleRepo());
      await controller.jumpToVerse('Gn', 15, 4, {4, 5, 6, 7, 8, 9});

      expect(controller.targetVerse, equals(4));
      expect(controller.targetVerses, equals({4, 5, 6, 7, 8, 9}));
      expect(controller.targetVerses.contains(4), isTrue);
      expect(controller.targetVerses.contains(7), isTrue);
      expect(controller.targetVerses.contains(9), isTrue);
      expect(controller.targetVerses.contains(10), isFalse);

      controller.clearTargetVerse();
      expect(controller.targetVerse, isNull);
      expect(controller.targetVerses.isEmpty, isTrue);
    });
  });

  group('ThemeService Bible Scroll Animation Duration', () {
    test('has default duration of 500ms and clamps between 150ms and 1500ms', () {
      final themeService = ThemeService();
      expect(themeService.bibleScrollDurationMs, equals(500));

      themeService.setBibleScrollDurationMs(800);
      expect(themeService.bibleScrollDurationMs, equals(800));

      themeService.setBibleScrollDurationMs(50);
      expect(themeService.bibleScrollDurationMs, equals(150));

      themeService.setBibleScrollDurationMs(2000);
      expect(themeService.bibleScrollDurationMs, equals(1500));
    });
  });

  group('Regex Range Extraction for Passages (Gn 15:4-9)', () {
    test('extracts start and end verses from range reference', () {
      const targetRef = 'Gn 15:4-9';
      final match = RegExp(
        r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::\s*(\d+)(?:\s*[-–—]\s*(\d+))?)?',
      ).firstMatch(targetRef.trim());

      expect(match, isNotNull);
      expect(match!.group(1), equals('Gn'));
      expect(match.group(2), equals('15'));
      expect(match.group(3), equals('4'));
      expect(match.group(4), equals('9'));

      final startV = int.parse(match.group(3)!);
      final endV = int.parse(match.group(4)!);
      final range = {for (int i = startV; i <= endV; i++) i};

      expect(range, equals({4, 5, 6, 7, 8, 9}));
    });
  });
}
