import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/study_models.dart';

class PericopeRepository {
  final DatabaseManager _dbManager;

  PericopeRepository({DatabaseManager? dbManager})
      : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbPericopes);
  }

  /// Retorna as perícopes de um determinado livro e capítulo ordenadas por versículo
  Future<List<Pericope>> getPericopes(int bookId, int chapter) async {
    final db = await _getDb();
    final ResultSet results = db.select(
      '''
      SELECT id, book_id, chapter, verse, title
      FROM pericope
      WHERE book_id = ? AND chapter = ?
      ORDER BY verse ASC
      ''',
      [bookId, chapter],
    );

    return results.map((row) => Pericope.fromMap(row)).toList();
  }
}
