import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/study_models.dart';

class CommentaryRepository {
  final DatabaseManager _dbManager;

  CommentaryRepository({DatabaseManager? dbManager})
      : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbCommentaries);
  }

  /// Retorna comentários expositivos que cobrem o versículo especificado
  Future<List<Commentary>> getCommentariesForVerse(
    int bookId,
    int chapter,
    int verse,
  ) async {
    final db = await _getDb();
    final ResultSet results = db.select(
      '''
      SELECT c.id, c.book_id, c.chapter, c.verse_start, c.verse_end,
             c.title, c.content, a.name as author_name
      FROM commentaries c
      JOIN authors a ON a.id = c.author_id
      WHERE c.book_id = ?
        AND c.chapter = ?
        AND ? BETWEEN c.verse_start AND c.verse_end
      ORDER BY a.name ASC, c.id ASC
      ''',
      [bookId, chapter, verse],
    );

    return results.map((row) => Commentary.fromMap(row)).toList();
  }
}
