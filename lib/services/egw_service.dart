import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/database/database_manager.dart';
import '../models/egw_models.dart';

/// Serviço gerenciador de livros e capítulos do Espírito de Profecia (Ellen G. White)
/// com suporte a sincronização online, parsing estruturado de parágrafos,
/// cache SQLite local instantâneo e downloads offline em lote.
class EgwService {
  static final EgwService _instance = EgwService._internal();
  factory EgwService() => _instance;
  EgwService._internal();

  static const String _booksTable = 'egw_books_cache';
  static const String _chaptersTable = 'egw_chapters_cache';

  /// Catálogo padrão de livros conhecidos com seus IDs oficiais no EGW Writings
  static const List<Map<String, String>> defaultCatalog = [
    // Série Conflito dos Séculos
    {
      'id': '1815',
      'title': 'Patriarcas e Profetas',
      'abbr': 'PP',
      'desc': 'A história do conflito entre o bem e o mal desde a criação do mundo até o reinado de Davi.',
    },
    {
      'id': '1816',
      'title': 'Profetas e Reis',
      'abbr': 'PR',
      'desc': 'A história desde o reinado de Salomão até o cativeiro de Israel e os profetas do Antigo Testamento.',
    },
    {
      'id': '1813',
      'title': 'O Desejado de Todas as Nações',
      'abbr': 'DTN',
      'desc': 'A obra-prima sobre a vida, ministério, morte e ressurreição de Jesus Cristo.',
    },
    {
      'id': '1806',
      'title': 'Atos dos Apóstolos',
      'abbr': 'AA',
      'desc': 'O nascimento da igreja cristã, o Pentecostes e a pregação dos primeiros apóstolos.',
    },
    {
      'id': '11125',
      'title': 'O Grande Conflito',
      'abbr': 'GC',
      'desc': 'O desenrolar da batalha cósmica entre Cristo e Satanás até a Nova Terra.',
    },

    // Clássicos Devocionais e Vida Prática
    {
      'id': '11121',
      'title': 'Caminho a Cristo',
      'abbr': 'CC',
      'desc': 'Guia essencial para a fé prática, o arrependimento, a oração e a comunhão com Jesus.',
    },
    {
      'id': '1931',
      'title': 'Parábolas de Jesus',
      'abbr': 'PJ',
      'desc': 'Lições espirituais profundas extraídas das parábolas contadas pelo Salvador.',
    },
    {
      'id': '1956',
      'title': 'O Maior Discurso de Cristo',
      'abbr': 'MDC',
      'desc': 'Meditações sobre o Sermão da Montanha e os princípios do Reino Celestial.',
    },
    {
      'id': '1951',
      'title': 'Mensagens aos Jovens',
      'abbr': 'MJ',
      'desc': 'Instruções e princípios fundamentais para a juventude cristã em tempos desafiadores.',
    },
    {
      'id': '1948',
      'title': 'Educação',
      'abbr': 'ED',
      'desc': 'O desenvolvimento harmônico do físico, intelectual e espiritual.',
    },
    {
      'id': '1955',
      'title': 'O Lar Adventista',
      'abbr': 'LA',
      'desc': 'Princípios para a construção de famílias felizes, amorosas e consagradas.',
    },
    {
      'id': '1957',
      'title': 'Primeiros Escritos',
      'abbr': 'PE',
      'desc': 'As primeiras visões e relatos da pioneira sobre o movimento adventista.',
    },
    {
      'id': '1949',
      'title': 'História da Redenção',
      'abbr': 'HR',
      'desc': 'Visão panorâmica e condensada do plano da salvação desde a queda de Lúcifer.',
    },
    {
      'id': '11255',
      'title': 'A Ciência do Bom Viver',
      'abbr': 'CBV',
      'desc': 'Princípios de saúde, restauração física, mental e serviço ao próximo.',
    },
    {
      'id': '1729',
      'title': 'Eventos Finais',
      'abbr': 'EF',
      'desc': 'Orientações sobre os acontecimentos escatológicos antes da volta de Jesus.',
    },
    {
      'id': '1727',
      'title': 'Vida de Jesus',
      'abbr': 'VJ',
      'desc': 'Relato acessível e envolvente da vida de Cristo especialmente para crianças e jovens.',
    },
    {
      'id': '1818',
      'title': 'Serviço Cristão',
      'abbr': 'SC',
      'desc': 'Capacitação prática para o evangelismo e o testemunho diário.',
    },
    {
      'id': '1810',
      'title': 'Conselhos sobre Mordomia',
      'abbr': 'CM',
      'desc': 'O uso sábio dos dons, do tempo, dos talentos e dos recursos confiados por Deus.',
    },
    {
      'id': '1724',
      'title': 'Conselhos sobre a Escola Sabatina',
      'abbr': 'CES',
      'desc': 'Princípios para o ensino, liderança e dinamismo da Escola Sabatina.',
    },
    {
      'id': '11093',
      'title': 'Conselhos sobre Regime Alimentar',
      'abbr': 'CRA',
      'desc': 'Instruções fundamentais para a alimentação equilibrada e o cuidado do corpo.',
    },
    {
      'id': '1945',
      'title': 'Beneficência Social',
      'abbr': 'BS',
      'desc': 'O ministério de compaixão em favor dos necessitados, órfãos e desvalidos.',
    },
    {
      'id': '1726',
      'title': 'Fé e Obras',
      'abbr': 'FO',
      'desc': 'A harmonia entre a justificação pela fé e a obediência genuína.',
    },
    {
      'id': '11246',
      'title': 'Mensagens Escolhidas, vol. 1',
      'abbr': '1ME',
      'desc': 'Coletânea temática com declarações sobre inspiração, salvação e vida cristã.',
    },
    {
      'id': '11098',
      'title': 'Mensagens Escolhidas, vol. 2',
      'abbr': '2ME',
      'desc': 'Orientações sobre fanatismo, práticas médicas e organização eclesiástica.',
    },
    {
      'id': '11097',
      'title': 'Mensagens Escolhidas, vol. 3',
      'abbr': '3ME',
      'desc': 'Instruções sobre liderança, relacionamentos e fidelidade profética.',
    },
  ];

  /// Garante a existência das tabelas no SQLite
  Future<void> _ensureTablesCreated() async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        CREATE TABLE IF NOT EXISTS $_booksTable (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          abbreviation TEXT,
          cover_url TEXT,
          description TEXT,
          total_chapters INTEGER DEFAULT 0,
          is_downloaded INTEGER DEFAULT 0,
          updated_at INTEGER
        );
      ''');

      db.execute('''
        CREATE TABLE IF NOT EXISTS $_chaptersTable (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          chapter_id TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          title TEXT NOT NULL,
          content_json TEXT NOT NULL,
          cached_at INTEGER NOT NULL
        );
      ''');

      db.execute('''
        CREATE INDEX IF NOT EXISTS idx_egw_chapters_book 
        ON $_chaptersTable (book_id);
      ''');
    } catch (e) {
      debugPrint('[EgwService] Erro ao criar tabelas: $e');
    }
  }

  /// Retorna a lista de livros disponíveis com status de cache/download
  Future<List<EgwBook>> getBooks() async {
    await _ensureTablesCreated();

    try {
      final db = await DatabaseManager().getDatabase('hinario.db');

      // Mapeia contagem de capítulos baixados por livro
      final chapterCounts = <String, int>{};
      final countRows = db.select(
        'SELECT book_id, COUNT(*) as qtd FROM $_chaptersTable GROUP BY book_id;',
      );
      for (final r in countRows) {
        final bId = (r['book_id'] ?? '').toString();
        final count = (r['qtd'] as int?) ?? 0;
        chapterCounts[bId] = count;
      }

      // Consulta livros salvos no banco
      final bookRows = db.select('SELECT * FROM $_booksTable;');
      final dbBooksMap = <String, Map<String, dynamic>>{};
      for (final r in bookRows) {
        final bId = (r['id'] ?? '').toString();
        dbBooksMap[bId] = Map<String, dynamic>.from(r);
      }

      final List<EgwBook> books = [];

      for (final item in defaultCatalog) {
        final id = item['id']!;
        final downloadedCount = chapterCounts[id] ?? 0;

        if (dbBooksMap.containsKey(id)) {
          final row = dbBooksMap[id]!;
          books.add(EgwBook.fromMap(row, downloaded: downloadedCount));
        } else {
          // Insere catálogo padrão inicial
          final book = EgwBook(
            id: id,
            title: item['title']!,
            abbreviation: item['abbr']!,
            description: item['desc']!,
            downloadedChapters: downloadedCount,
          );
          db.execute('''
            INSERT OR IGNORE INTO $_booksTable (
              id, title, abbreviation, cover_url, description, total_chapters, is_downloaded, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
          ''', [
            book.id,
            book.title,
            book.abbreviation,
            book.coverUrl,
            book.description,
            0,
            0,
            DateTime.now().millisecondsSinceEpoch,
          ]);
          books.add(book);
        }
      }

      return books;
    } catch (e) {
      debugPrint('[EgwService] Erro ao listar livros: $e');
      return defaultCatalog.map((item) {
        return EgwBook(
          id: item['id']!,
          title: item['title']!,
          abbreviation: item['abbr']!,
          description: item['desc']!,
        );
      }).toList();
    }
  }

  /// Busca o sumário (lista de capítulos) de um livro
  Future<List<EgwChapterHeader>> getTableOfContents(String bookId) async {
    await _ensureTablesCreated();

    // 1. Tenta carregar capítulos já baixados em ordem
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select('''
        SELECT chapter_id, chapter_index, title 
        FROM $_chaptersTable 
        WHERE book_id = ? 
        ORDER BY chapter_index ASC;
      ''', [bookId]);

      if (rows.isNotEmpty) {
        final cachedHeaders = rows.map((r) {
          return EgwChapterHeader(
            bookId: bookId,
            chapterId: (r['chapter_id'] ?? '').toString(),
            chapterIndex: (r['chapter_index'] as int?) ?? 0,
            title: (r['title'] ?? '').toString(),
          );
        }).toList();

        // Se já tiver uma quantidade razoável em cache, retorna
        if (cachedHeaders.length >= 10 || cachedHeaders.isNotEmpty) {
          return cachedHeaders;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao consultar sumário local: $e');
    }

    // 2. Busca online do TOC oficial de m.egwwritings.org
    try {
      final url = Uri.parse('https://m.egwwritings.org/pt/book/$bookId/toc');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final headers = _parseTocHtml(bookId, resp.body);
        if (headers.isNotEmpty) {
          // Atualiza total de capítulos na tabela de livros
          final db = await DatabaseManager().getDatabase('hinario.db');
          db.execute('''
            UPDATE $_booksTable 
            SET total_chapters = ?, updated_at = ? 
            WHERE id = ?;
          ''', [headers.length, DateTime.now().millisecondsSinceEpoch, bookId]);
          return headers;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao buscar sumário online: $e');
    }

    return [];
  }

  /// Busca o conteúdo completo de um capítulo
  Future<EgwChapter?> getChapter(
    String bookId,
    String chapterId, {
    int? chapterIndex,
    String? fallbackTitle,
  }) async {
    await _ensureTablesCreated();
    final fullId = '$bookId.$chapterId';

    // 1. Tenta carregar do cache SQLite
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select(
        'SELECT content_json FROM $_chaptersTable WHERE id = ? LIMIT 1;',
        [fullId],
      );
      if (rows.isNotEmpty) {
        final jsonStr = rows.first['content_json'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          return EgwChapter.fromJson(jsonStr);
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao carregar capítulo do cache: $e');
    }

    // 2. Busca online de m.egwwritings.org
    try {
      final url = Uri.parse('https://m.egwwritings.org/pt/book/$fullId');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final chapter = _parseChapterHtml(
          bookId: bookId,
          chapterId: chapterId,
          chapterIndex: chapterIndex ?? 1,
          htmlBody: resp.body,
          fallbackTitle: fallbackTitle,
        );

        if (chapter != null && chapter.paragraphs.isNotEmpty) {
          // Salva no cache SQLite local
          await _saveChapterToCache(chapter);
          return chapter;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao buscar capítulo online: $e');
    }

    return null;
  }

  /// Salva um capítulo no cache SQLite
  Future<void> _saveChapterToCache(EgwChapter chapter) async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        INSERT OR REPLACE INTO $_chaptersTable (
          id, book_id, chapter_id, chapter_index, title, content_json, cached_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
      ''', [
        chapter.id,
        chapter.bookId,
        chapter.chapterId,
        chapter.chapterIndex,
        chapter.title,
        chapter.toJson(),
        DateTime.now().millisecondsSinceEpoch,
      ]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao salvar capítulo em cache: $e');
    }
  }

  /// Baixa todos os capítulos do livro em lote para visualização offline
  Future<void> downloadBook(
    String bookId, {
    void Function(int current, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    await _ensureTablesCreated();

    final toc = await getTableOfContents(bookId);
    if (toc.isEmpty) return;

    final total = toc.length;
    int current = 0;

    for (final header in toc) {
      if (shouldCancel?.call() == true) {
        debugPrint('[EgwService] Download cancelado pelo usuário.');
        return;
      }

      await getChapter(
        bookId,
        header.chapterId,
        chapterIndex: header.chapterIndex,
        fallbackTitle: header.title,
      );

      current++;
      onProgress?.call(current, total);

      // Pequena pausa (60ms) para não sobrecarregar
      await Future.delayed(const Duration(milliseconds: 60));
    }

    // Marca como baixado
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        UPDATE $_booksTable 
        SET is_downloaded = 1, total_chapters = ?, updated_at = ? 
        WHERE id = ?;
      ''', [total, DateTime.now().millisecondsSinceEpoch, bookId]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao atualizar status de download: $e');
    }
  }

  /// Remove os capítulos baixados do livro
  Future<void> deleteBookDownload(String bookId) async {
    await _ensureTablesCreated();
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('DELETE FROM $_chaptersTable WHERE book_id = ?;', [bookId]);
      db.execute('''
        UPDATE $_booksTable 
        SET is_downloaded = 0, updated_at = ? 
        WHERE id = ?;
      ''', [DateTime.now().millisecondsSinceEpoch, bookId]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao excluir livro: $e');
    }
  }

  /// Checa se um livro está 100% baixado
  Future<bool> isBookDownloaded(String bookId) async {
    await _ensureTablesCreated();
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select(
        'SELECT total_chapters, is_downloaded FROM $_booksTable WHERE id = ? LIMIT 1;',
        [bookId],
      );
      if (rows.isNotEmpty) {
        final isDown = (rows.first['is_downloaded'] as int? ?? 0) == 1;
        if (isDown) return true;
        final total = (rows.first['total_chapters'] as int? ?? 0);
        if (total > 0) {
          final countRows = db.select(
            'SELECT COUNT(*) as qtd FROM $_chaptersTable WHERE book_id = ?;',
            [bookId],
          );
          final downloaded = countRows.first['qtd'] as int? ?? 0;
          return downloaded >= total;
        }
      }
    } catch (_) {}
    return false;
  }

  // --- MÉTODOS DE PARSER HTML PURO EM DART ---

  static List<EgwChapterHeader> _parseTocHtml(String bookId, String html) {
    final List<EgwChapterHeader> list = [];
    final escapedId = RegExp.escape(bookId);
    final regex = RegExp(
      '<li[^>]+id=["\']l\\.$escapedId\\.(\\d+)["\'][^>]*>\\s*<a[^>]+href=["\']/pt/book/$escapedId\\.(\\d+)["\'][^>]*>(.*?)<\\/a>',
      caseSensitive: false,
    );

    int index = 1;
    for (final match in regex.allMatches(html)) {
      final chapterId = match.group(1) ?? match.group(2) ?? '';
      final rawTitle = match.group(3) ?? '';
      final cleanTitle = _cleanHtmlText(rawTitle);

      if (chapterId.isNotEmpty && cleanTitle.isNotEmpty) {
        list.add(
          EgwChapterHeader(
            bookId: bookId,
            chapterId: chapterId,
            chapterIndex: index++,
            title: cleanTitle,
          ),
        );
      }
    }
    return list;
  }

  static EgwChapter? _parseChapterHtml({
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required String htmlBody,
    String? fallbackTitle,
  }) {
    // 1. Extração do Título
    String title = fallbackTitle ?? 'Capítulo $chapterIndex';
    final headerMatch = RegExp(
      r'<h[1-3][^>]*class=["'\''][^"'\'']*egw_content_wrapper[^"'\'']*["'\''][^>]*>.*?<span[^>]*class=["'\''][^"'\'']*egw_content[^"'\'']*["'\''][^>]*>(.*?)</span>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(htmlBody);

    if (headerMatch != null) {
      final extracted = _cleanHtmlText(headerMatch.group(1) ?? '');
      if (extracted.isNotEmpty) {
        title = extracted;
      }
    }

    // 2. Extração dos Parágrafos
    final List<EgwParagraph> paragraphs = [];
    final paraRegex = RegExp(
      r'<p[^>]*class=["'\''][^"'\'']*egw_content_wrapper[^"'\'']*["'\''][^>]*id=["'\''](\d+)["'\''][^>]*data-refcode=["'\'']([^"'\'']*)["'\''][^>]*>(.*?)</p>',
      dotAll: true,
      caseSensitive: false,
    );

    for (final m in paraRegex.allMatches(htmlBody)) {
      final pId = m.group(1) ?? '';
      final refcode = m.group(2)?.trim() ?? '';
      final inner = m.group(3) ?? '';

      // Tenta achar o span egw_content
      final contentSpanMatch = RegExp(
        r'<span[^>]*class=["'\''][^"'\'']*egw_content[^"'\'']*["'\''][^>]*>(.*?)</span>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(inner);

      final rawContent = contentSpanMatch != null ? (contentSpanMatch.group(1) ?? '') : inner;
      final cleanText = _cleanHtmlText(rawContent);

      if (cleanText.isNotEmpty) {
        paragraphs.add(
          EgwParagraph(
            id: pId,
            refcode: refcode,
            text: cleanText,
          ),
        );
      }
    }

    return EgwChapter(
      id: '$bookId.$chapterId',
      bookId: bookId,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      title: title,
      paragraphs: paragraphs,
    );
  }

  /// Limpa tags HTML e converte entidades comuns
  static String _cleanHtmlText(String raw) {
    if (raw.isEmpty) return '';

    var clean = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    clean = clean
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’');

    // Converte múltiplos espaços em um só e faz trim
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
