import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/egw_models.dart';
import 'package:kairos_web/services/egw_service.dart';

void main() {
  test('isBookDownloaded / evaluateDownloadCompleteness retorna false quando apenas 1 capitulo online foi salvo em livro multi-capitulo', () {
    final service = EgwService();
    expect(
      service.evaluateDownloadCompleteness(
        cachedChapterCount: 1,
        expectedTotalChapters: 42,
        flaggedDownloaded: true,
      ),
      isFalse,
    );
    expect(
      service.evaluateDownloadCompleteness(
        cachedChapterCount: 1,
        expectedTotalChapters: 0,
        flaggedDownloaded: true,
      ),
      isFalse,
    );
    expect(
      service.evaluateDownloadCompleteness(
        cachedChapterCount: 42,
        expectedTotalChapters: 42,
        flaggedDownloaded: true,
      ),
      isTrue,
    );
    expect(
      service.evaluateDownloadCompleteness(
        cachedChapterCount: 1,
        expectedTotalChapters: 1,
        flaggedDownloaded: true,
      ),
      isTrue,
    );
  });

  test('shouldBypassTocCache retorna true quando forceRefresh == true ou cache parcial de leitura online', () {
    final service = EgwService();
    expect(
      service.shouldBypassTocCache(
        forceRefresh: true,
        cachedHeadersCount: 42,
        knownTotalChapters: 42,
      ),
      isTrue,
    );
    expect(
      service.shouldBypassTocCache(
        forceRefresh: false,
        cachedHeadersCount: 1,
        knownTotalChapters: 0,
      ),
      isTrue,
    );
    expect(
      service.shouldBypassTocCache(
        forceRefresh: false,
        cachedHeadersCount: 1,
        knownTotalChapters: 42,
      ),
      isTrue,
    );
    expect(
      service.shouldBypassTocCache(
        forceRefresh: false,
        cachedHeadersCount: 42,
        knownTotalChapters: 42,
      ),
      isFalse,
    );
  });

  test('EgwBook.fromMap nao marca livro como isDownloaded quando downloaded < total_chapters', () {
    final partialBook = EgwBook.fromMap(
      {
        'id': '1815',
        'title': 'Patriarcas e Profetas',
        'abbreviation': 'PP',
        'total_chapters': 73,
        'is_downloaded': 1,
      },
      downloaded: 1,
    );
    expect(partialBook.isDownloaded, isFalse);

    final completeBook = EgwBook.fromMap(
      {
        'id': '1815',
        'title': 'Patriarcas e Profetas',
        'abbreviation': 'PP',
        'total_chapters': 73,
        'is_downloaded': 1,
      },
      downloaded: 73,
    );
    expect(completeBook.isDownloaded, isTrue);
  });
}
