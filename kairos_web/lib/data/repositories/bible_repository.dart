import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/bible_verse.dart';

class BibleRepository {
  final DatabaseManager _dbManager;

  BibleRepository({DatabaseManager? dbManager})
      : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbBible);
  }

  /// Retorna lista de livros bíblicos disponíveis com contagem de capítulos calculada
  Future<List<BibleBook>> getBooks() async {
    final db = await _getDb();
    
    // Consulta os livros da tabela real 'book'
    final ResultSet bookRows = db.select(
      'SELECT id, name, testament_reference_id FROM book ORDER BY id ASC',
    );

    // Mapeia os capítulos máximos de cada livro em uma única query
    final ResultSet chapterRows = db.select(
      'SELECT book_id, max(chapter) as total_capitulos FROM verse GROUP BY book_id',
    );

    final Map<int, int> chapterCounts = {};
    for (final row in chapterRows) {
      chapterCounts[row['book_id'] as int] = row['total_capitulos'] as int? ?? 1;
    }

    return bookRows.map((row) {
      final bookId = row['id'] as int;
      final testamentRef = row['testament_reference_id'] as int? ?? 1;
      return BibleBook(
        id: bookId,
        name: row['name'] as String,
        testament: testamentRef == 1 ? 'VT' : 'NT',
        chaptersCount: chapterCounts[bookId] ?? 1,
      );
    }).toList();
  }

  /// Retorna todos os versículos de um capítulo específico da tabela 'verse'
  Future<List<BibleVerse>> getVerses(int bookId, int chapter, {String bookName = ''}) async {
    final db = await _getDb();
    final ResultSet results = db.select(
      '''
      SELECT v.id, v.book_id, b.name as book_name, v.chapter, v.verse, v.text
      FROM verse v
      JOIN book b ON b.id = v.book_id
      WHERE v.book_id = ? AND v.chapter = ?
      ORDER BY v.verse ASC
      ''',
      [bookId, chapter],
    );

    return results.map((row) {
      return BibleVerse(
        id: row['id'] as int,
        bookId: row['book_id'] as int,
        bookName: row['book_name'] as String? ?? bookName,
        chapter: row['chapter'] as int,
        verse: row['verse'] as int,
        text: row['text'] as String,
      );
    }).toList();
  }

  /// Busca textual simples por palavra-chave nos versículos
  Future<List<BibleVerse>> searchVerses(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];

    final db = await _getDb();
    final cleanQuery = '%${query.trim()}%';
    final ResultSet results = db.select(
      '''
      SELECT v.id, v.book_id, b.name as book_name, v.chapter, v.verse, v.text
      FROM verse v
      JOIN book b ON b.id = v.book_id
      WHERE v.text LIKE ?
      ORDER BY v.book_id ASC, v.chapter ASC, v.verse ASC
      LIMIT ?
      ''',
      [cleanQuery, limit],
    );

    return results.map((row) {
      return BibleVerse(
        id: row['id'] as int,
        bookId: row['book_id'] as int,
        bookName: row['book_name'] as String? ?? '',
        chapter: row['chapter'] as int,
        verse: row['verse'] as int,
        text: row['text'] as String,
      );
    }).toList();
  }
}
