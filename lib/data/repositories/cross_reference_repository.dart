import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/study_models.dart';

class CrossReferenceRepository {
  final DatabaseManager _dbManager;

  CrossReferenceRepository({DatabaseManager? dbManager})
      : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbCrossReferences);
  }

  /// Retorna referências cruzadas para um versículo específico ordenadas por votos
  Future<List<CrossReference>> getCrossReferences(
    int bookId,
    int chapter,
    int verse, {
    Map<int, String>? bookNames,
  }) async {
    final db = await _getDb();
    final ResultSet results = db.select(
      '''
      SELECT id, from_book_id, from_chapter, from_verse,
             to_book_id, to_chapter, to_verse_start, to_verse_end, votes
      FROM cross_reference
      WHERE from_book_id = ? AND from_chapter = ? AND from_verse = ?
      ORDER BY votes DESC
      LIMIT 50
      ''',
      [bookId, chapter, verse],
    );

    return results.map((row) {
      final toBookId = row['to_book_id'] as int;
      final bookName = bookNames?[toBookId];
      return CrossReference.fromMap(row, targetBookName: bookName);
    }).toList();
  }
}
