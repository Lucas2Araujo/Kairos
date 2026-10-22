import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';
import '../core/database/database_manager.dart';

enum SearchContentType {
  hino,
  biblia,
  meditacao,
  licao,
}

class SearchResultItem {
  final String id;
  final SearchContentType contentType;
  final String title;
  final String subtitle;
  final double score;
  final Map<String, dynamic> metadata;

  const SearchResultItem({
    required this.id,
    required this.contentType,
    required this.title,
    required this.subtitle,
    required this.score,
    required this.metadata,
  });
}

class SearchResultsPage {
  final List<SearchResultItem> items;
  final Map<SearchContentType, int> countsByType;
  final int totalCount;

  const SearchResultsPage({
    required this.items,
    required this.countsByType,
    required this.totalCount,
  });

  static const empty = SearchResultsPage(
    items: [],
    countsByType: {},
    totalCount: 0,
  );
}

class _QueryTier {
  final String ftsExpression;
  final double boost;
  const _QueryTier(this.ftsExpression, this.boost);
}

class SearchService {
  static final SearchService _instance = SearchService._internal();
  factory SearchService() => _instance;
  SearchService._internal();

  final DatabaseManager _dbManager = DatabaseManager();
  bool _tablesEnsured = false;

  Future<void> _ensureTables(CommonDatabase db) async {
    if (_tablesEnsured) return;
    _tablesEnsured = true;

    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS verse_highlights (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          color TEXT NOT NULL,
          updated_at TEXT,
          PRIMARY KEY (book_id, chapter, verse)
        );
      ''');
    } catch (e) {
      debugPrint('[SearchService] Erro ao verificar verse_highlights: $e');
    }
  }

  List<String> _extractTokens(String query) {
    return query
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  List<_QueryTier> _buildTiers(List<String> tokens) {
    if (tokens.isEmpty) return const [];
    if (tokens.length == 1) {
      final t = tokens.first;
      return [
        _QueryTier('"$t"', -50.0),
        _QueryTier('"$t"*', 0.0),
      ];
    }
    final phrase = tokens.map((t) => '"$t"').join(' ');
    final andTokens = tokens.map((t) => '"$t"').join(' AND ');
    final prefixTokens = tokens.map((t) => '"$t"*').join(' AND ');
    return [
      _QueryTier(phrase, -50.0),
      _QueryTier(andTokens, -25.0),
      _QueryTier(prefixTokens, 0.0),
    ];
  }

  String _cleanSnippet(String raw, [int maxLength = 160]) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxLength) return clean;
    return '${clean.substring(0, maxLength)}...';
  }

  Future<SearchResultsPage> search(
    String query, {
    SearchContentType? typeFilter,
    int limit = 50,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return SearchResultsPage.empty;
    }

    final tokens = _extractTokens(cleanQuery);
    if (tokens.isEmpty) {
      return SearchResultsPage.empty;
    }

    final db = await _dbManager.getDatabase('hinario.db');
    await _ensureTables(db);

    final tiers = _buildTiers(tokens);
    final resultsMap = <String, SearchResultItem>{};

    // 1. Caso numérico: busca direta por número do hino
    final numVal = int.tryParse(cleanQuery);
    if (numVal != null) {
      try {
        final rows = db.select(
          'SELECT id, numero, titulo, letra, categoria FROM hino WHERE numero = ? LIMIT 1;',
          [numVal],
        );
        if (rows.isNotEmpty) {
          final r = rows.first;
          final id = r['id'].toString();
          final numero = r['numero'].toString();
          final titulo = r['titulo'] as String? ?? '';
          final letra = r['letra'] as String? ?? '';
          final categoria = r['categoria'] as String? ?? '';

          resultsMap['${SearchContentType.hino.name}:$id'] = SearchResultItem(
            id: id,
            contentType: SearchContentType.hino,
            title: 'Hino $numero - $titulo',
            subtitle: _cleanSnippet(letra),
            score: -1000.0,
            metadata: {
              'id': r['id'],
              'numero': numero,
              'titulo': titulo,
              'categoria': categoria,
            },
          );
        }
      } catch (e) {
        debugPrint('[SearchService] Erro na busca direta de hino: $e');
      }
    }

    // 2. hino_fts
    for (final tier in tiers) {
      try {
        final rows = db.select(
          'SELECT rowid, numero, titulo, letra, categoria, bm25(hino_fts) as rank FROM hino_fts WHERE hino_fts MATCH ? ORDER BY rank ASC LIMIT ?;',
          [tier.ftsExpression, limit],
        );
        for (final r in rows) {
          final id = r['rowid'].toString();
          final key = '${SearchContentType.hino.name}:$id';
          final rank = (r['rank'] as num?)?.toDouble() ?? 0.0;
          final score = rank + tier.boost;
          if (!resultsMap.containsKey(key) || score < resultsMap[key]!.score) {
            final numero = r['numero'].toString();
            final titulo = r['titulo'] as String? ?? '';
            final letra = r['letra'] as String? ?? '';
            final categoria = r['categoria'] as String? ?? '';

            resultsMap[key] = SearchResultItem(
              id: id,
              contentType: SearchContentType.hino,
              title: 'Hino $numero - $titulo',
              subtitle: _cleanSnippet(letra),
              score: score,
              metadata: {
                'rowid': r['rowid'],
                'numero': numero,
                'titulo': titulo,
                'categoria': categoria,
              },
            );
          }
        }
      } catch (e) {
        debugPrint('[SearchService] Erro hino_fts: $e');
      }
    }

    // 3. biblia_fts
    for (final tier in tiers) {
      try {
        final rows = db.select(
          'SELECT rowid, book_id, book_name, chapter, verse, verse_reference, text, bm25(biblia_fts) as rank FROM biblia_fts WHERE biblia_fts MATCH ? ORDER BY rank ASC LIMIT ?;',
          [tier.ftsExpression, limit],
        );
        for (final r in rows) {
          final id = r['rowid'].toString();
          final key = '${SearchContentType.biblia.name}:$id';
          final rank = (r['rank'] as num?)?.toDouble() ?? 0.0;
          final score = rank + tier.boost;
          if (!resultsMap.containsKey(key) || score < resultsMap[key]!.score) {
            final verseRef = r['verse_reference'] as String? ?? '';
            final text = r['text'] as String? ?? '';

            resultsMap[key] = SearchResultItem(
              id: id,
              contentType: SearchContentType.biblia,
              title: verseRef,
              subtitle: text,
              score: score,
              metadata: {
                'rowid': r['rowid'],
                'book_id': r['book_id'],
                'book_name': r['book_name'],
                'chapter': r['chapter'],
                'verse': r['verse'],
                'verse_reference': verseRef,
                'text': text,
              },
            );
          }
        }
      } catch (e) {
        debugPrint('[SearchService] Erro biblia_fts: $e');
      }
    }

    // 4. meditacao_fts
    for (final tier in tiers) {
      try {
        final rows = db.select(
          'SELECT rowid, published_at, category, title, verse_text, verse_reference, content, author, bm25(meditacao_fts) as rank FROM meditacao_fts WHERE meditacao_fts MATCH ? ORDER BY rank ASC LIMIT ?;',
          [tier.ftsExpression, limit],
        );
        for (final r in rows) {
          final id = r['rowid'].toString();
          final key = '${SearchContentType.meditacao.name}:$id';
          final rank = (r['rank'] as num?)?.toDouble() ?? 0.0;
          final score = rank + tier.boost;
          if (!resultsMap.containsKey(key) || score < resultsMap[key]!.score) {
            final title = r['title'] as String? ?? '';
            final category = r['category'] as String? ?? '';
            final date = r['published_at'] as String? ?? '';
            final content = r['content'] as String? ?? '';
            final author = r['author'] as String? ?? '';
            final verseText = r['verse_text'] as String? ?? '';
            final verseRef = r['verse_reference'] as String? ?? '';

            final categoryLabel = category.isNotEmpty
                ? '${category[0].toUpperCase()}${category.substring(1)}'
                : '';
            final displayTitle = categoryLabel.isNotEmpty ? '$title ($categoryLabel)' : title;
            final subtitle = _cleanSnippet(content.isNotEmpty ? content : verseText);

            resultsMap[key] = SearchResultItem(
              id: id,
              contentType: SearchContentType.meditacao,
              title: displayTitle,
              subtitle: subtitle,
              score: score,
              metadata: {
                'rowid': r['rowid'],
                'published_at': date,
                'category': category,
                'title': title,
                'author': author,
                'verse_text': verseText,
                'verse_reference': verseRef,
                'content': content,
              },
            );
          }
        }
      } catch (e) {
        debugPrint('[SearchService] Erro meditacao_fts: $e');
      }
    }

    // 5. licao_fts
    for (final tier in tiers) {
      try {
        final rows = db.select(
          'SELECT rowid, day_id, lesson_id, lesson_title, day_title, date, content, bm25(licao_fts) as rank FROM licao_fts WHERE licao_fts MATCH ? ORDER BY rank ASC LIMIT ?;',
          [tier.ftsExpression, limit],
        );
        for (final r in rows) {
          final id = r['rowid'].toString();
          final key = '${SearchContentType.licao.name}:$id';
          final rank = (r['rank'] as num?)?.toDouble() ?? 0.0;
          final score = rank + tier.boost;
          if (!resultsMap.containsKey(key) || score < resultsMap[key]!.score) {
            final dayTitle = r['day_title'] as String? ?? '';
            final lessonTitle = r['lesson_title'] as String? ?? '';
            final content = r['content'] as String? ?? '';

            final displayTitle = lessonTitle.isNotEmpty
                ? '$dayTitle ($lessonTitle)'
                : dayTitle;
            final subtitle = _cleanSnippet(content);

            resultsMap[key] = SearchResultItem(
              id: id,
              contentType: SearchContentType.licao,
              title: displayTitle,
              subtitle: subtitle,
              score: score,
              metadata: {
                'rowid': r['rowid'],
                'day_id': r['day_id'],
                'lesson_id': r['lesson_id'],
                'lesson_title': lessonTitle,
                'day_title': dayTitle,
                'date': r['date'],
                'content': content,
              },
            );
          }
        }
      } catch (e) {
        debugPrint('[SearchService] Erro licao_fts: $e');
      }
    }

    final allItems = resultsMap.values.toList()..sort((a, b) => a.score.compareTo(b.score));

    final counts = <SearchContentType, int>{};
    for (final item in allItems) {
      counts[item.contentType] = (counts[item.contentType] ?? 0) + 1;
    }

    final filtered = typeFilter == null
        ? allItems
        : allItems.where((i) => i.contentType == typeFilter).toList();

    return SearchResultsPage(
      items: filtered.take(limit).toList(),
      countsByType: counts,
      totalCount: allItems.length,
    );
  }
}
