import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/database/database_manager.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';

void main() {
  test('DatabaseManager.userPreservedTables inclui ss_highlights', () {
    expect(DatabaseManager.userPreservedTables.contains('ss_highlights'), isTrue);
  });

  test('SabbathSchoolService salva, recupera, remove e mescla destaques por dayId', () async {
    final ss = SabbathSchoolService();
    const dayId = 'test_day_1';

    await ss.saveHighlight(dayId, 0, '#FFF59D');
    await ss.saveHighlight(dayId, 2, '#A5D6A7');

    var highlights = await ss.getHighlights(dayId);
    expect(highlights[0], '#FFF59D');
    expect(highlights[2], '#A5D6A7');

    await ss.removeHighlight(dayId, 0);
    highlights = await ss.getHighlights(dayId);
    expect(highlights.containsKey(0), isFalse);
    expect(highlights[2], '#A5D6A7');

    await ss.importHighlightsWithMerge([
      {
        'day_id': dayId,
        'paragraph_index': 2,
        'color_hex': '#90CAF9',
        'updated_at': '2099-01-01T00:00:00.000Z',
      },
      {
        'day_id': dayId,
        'paragraph_index': 5,
        'color_hex': '#CE93D8',
        'updated_at': '2026-01-01T00:00:00.000Z',
      },
    ]);

    highlights = await ss.getHighlights(dayId);
    expect(highlights[2], '#90CAF9');
    expect(highlights[5], '#CE93D8');
  });
}
