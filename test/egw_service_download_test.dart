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

  test('parseTocHtml e parseChapterHtml são resilientes à ordem dos atributos HTML', () {
    const tocHtml = '''
      <ul>
        <li class="toc-row" id="l.1505.12">
          <a title="Abrir" href="/pt/book/1505.12"><span>O Lar e a Escola</span></a>
        </li>
        <li>
          <a href="/pt/book/1505.45">Deveres dos Pais</a>
        </li>
        <li>
          <a href="/pt/book/1505.12">Ler</a>
        </li>
      </ul>
    ''';

    final toc = EgwService.parseTocHtml(
      '1505',
      tocHtml,
      catalogBookId: 'pt_orientacao_crianca',
    );
    expect(toc.length, 2);
    expect(toc[0].bookId, 'pt_orientacao_crianca');
    expect(toc[0].chapterId, '12');
    expect(toc[0].title, 'O Lar e a Escola');
    expect(toc[1].chapterId, '45');

    const chapHtml = '''
      <h2 data-level="1" class="egw_content_wrapper title"><span class="egw_content">Capítulo 1</span></h2>
      <p data-refcode="OC 10.1" id="p10" class="egw_content_wrapper">
        <span class="egw_content">Primeiro parágrafo fiel.</span>
      </p>
      <div class="egw_content_wrapper" id="p11" data-refcode="OC 10.2">
        Segundo parágrafo em bloco div.
      </div>
    ''';

    final chapter = EgwService.parseChapterHtml(
      bookId: 'pt_orientacao_crianca',
      chapterId: '12',
      chapterIndex: 1,
      htmlBody: chapHtml,
    );
    expect(chapter, isNotNull);
    expect(chapter!.title, 'Capítulo 1');
    expect(chapter.paragraphs.length, 2);
    expect(chapter.paragraphs[0].refcode, 'OC 10.1');
    expect(chapter.paragraphs[0].text, 'Primeiro parágrafo fiel.');
    expect(chapter.paragraphs[1].id, 'p11');
    expect(chapter.paragraphs[1].text, 'Segundo parágrafo em bloco div.');
  });

  test('parseR2BookPackageMap remapeia capítulos para o ID local e preResolvedNumericIds cobre slugs críticos', () {
    expect(EgwService.preResolvedNumericIds['pt_evangelismo'], '115');
    expect(EgwService.preResolvedNumericIds['pt_orientacao_crianca'], '1505');
    expect(EgwService.preResolvedNumericIds['pt_obreiros_evangelicos'], '72');

    final chapters = EgwService.parseR2BookPackageMap(
      {
        'book_id': '1505',
        'chapters': [
          {
            'id': '1505.12',
            'bookId': '1505',
            'chapterId': '12',
            'chapterIndex': 1,
            'title': 'Introdução',
            'paragraphs': [
              {'id': '12', 'refcode': 'OC 9.1', 'text': 'Conteúdo pronto do R2.'},
            ],
          },
        ],
      },
      localBookId: 'pt_orientacao_crianca',
    );
    expect(chapters.length, 1);
    expect(chapters.first.id, 'pt_orientacao_crianca.12');
    expect(chapters.first.bookId, 'pt_orientacao_crianca');
    expect(chapters.first.paragraphs.first.text, 'Conteúdo pronto do R2.');
  });
}
