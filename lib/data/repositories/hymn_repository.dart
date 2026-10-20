import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/hymn.dart';

class HymnRepository {
  final DatabaseManager _dbManager;
  String _currentDbName;

  HymnRepository({DatabaseManager? dbManager, String dbName = AppConstants.dbHymns})
      : _dbManager = dbManager ?? DatabaseManager(),
        _currentDbName = dbName;

  String get currentDbName => _currentDbName;

  void setDatabase(String dbName) {
    _currentDbName = dbName;
  }

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(_currentDbName);
  }

  /// Retorna todos os hinos ordenados por número
  Future<List<Hymn>> getAll() async {
    final db = await _getDb();
    final ResultSet results = db.select('''
      SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
      FROM hino
      ORDER BY CAST(numero AS INTEGER) ASC, numero ASC
    ''');
    return results.map((row) => Hymn.fromMap(row)).toList();
  }

  /// Retorna hino por ID
  Future<Hymn?> getById(int id) async {
    final db = await _getDb();
    final ResultSet results = db.select(
      'SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video FROM hino WHERE id = ?',
      [id],
    );
    if (results.isEmpty) return null;
    return Hymn.fromMap(results.first);
  }

  /// Retorna hino por número exato
  Future<Hymn?> getByNumero(String numero) async {
    final db = await _getDb();
    final cleanNum = numero.trim();
    final ResultSet results = db.select(
      'SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores FROM hino WHERE numero = ? LIMIT 1',
      [cleanNum],
    );
    if (results.isEmpty) return null;
    return Hymn.fromMap(results.first);
  }

  /// Busca rápida por número, título, letra ou categoria
  Future<List<Hymn>> search(String query) async {
    final term = query.trim();
    if (term.isEmpty) return getAll();

    final db = await _getDb();

    // Se termo for numérico, prioriza busca por número
    if (int.tryParse(term) != null) {
      final ResultSet numResults = db.select('''
        SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores
        FROM hino
        WHERE numero = ? OR numero LIKE ?
        ORDER BY CASE WHEN numero = ? THEN 0 ELSE 1 END, CAST(numero AS INTEGER) ASC
        LIMIT 50
      ''', [term, '$term%', term]);

      if (numResults.isNotEmpty) {
        return numResults.map((row) => Hymn.fromMap(row)).toList();
      }
    }

    // Busca acelerada via FTS5 se disponível
    try {
      // Remove caracteres especiais de sintaxe FTS para evitar erros de query
      final cleanMatch = term.replaceAll(RegExp(r'["\*\^]'), '').trim();
      if (cleanMatch.isNotEmpty) {
        final ResultSet ftsResults = db.select('''
          SELECT h.id, h.numero, h.titulo, h.letra, h.autor_letra, h.autor_musica, h.texto_base, h.categoria, h.subcategoria, h.autores
          FROM hino_fts f
          JOIN hino h ON h.rowid = f.rowid
          WHERE hino_fts MATCH ?
          ORDER BY rank
          LIMIT 100
        ''', ['$cleanMatch*']);

        if (ftsResults.isNotEmpty) {
          return ftsResults.map((row) => Hymn.fromMap(row)).toList();
        }
      }
    } catch (_) {
      // Fallback para LIKE se FTS não encontrar ou não estiver disponível
    }

    // Busca textual ampla com fallback LIKE
    final pattern = '%$term%';
    final ResultSet results = db.select('''
      SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
      FROM hino
      WHERE titulo LIKE ? OR letra LIKE ? OR categoria LIKE ? OR subcategoria LIKE ?
      ORDER BY 
        CASE 
          WHEN LOWER(titulo) LIKE LOWER(?) THEN 1 
          WHEN LOWER(categoria) LIKE LOWER(?) THEN 2 
          ELSE 3 
        END,
        CAST(numero AS INTEGER) ASC
      LIMIT 100
    ''', [pattern, pattern, pattern, pattern, pattern, pattern]);

    return results.map((row) => Hymn.fromMap(row)).toList();
  }

  /// Retorna lista de categorias únicas
  Future<List<String>> getCategories() async {
    final db = await _getDb();
    final ResultSet results = db.select('''
      SELECT DISTINCT categoria
      FROM hino
      WHERE categoria IS NOT NULL AND categoria != ''
      ORDER BY categoria ASC
    ''');
    return results.map((row) => row['categoria'] as String).toList();
  }

  /// Filtra hinos por categoria
  Future<List<Hymn>> getByCategory(String category) async {
    final db = await _getDb();
    final ResultSet results = db.select('''
      SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
      FROM hino
      WHERE categoria = ?
      ORDER BY CAST(numero AS INTEGER) ASC
    ''', [category]);
    return results.map((row) => Hymn.fromMap(row)).toList();
  }

  /// Retorna lista de textos bíblicos correlacionados ao hino
  Future<List<String>> getRelatedBibleTexts(int hinoId) async {
    final db = await _getDb();
    try {
      final ResultSet results = db.select('''
        SELECT t.referencia
        FROM hino_texto ht
        JOIN texto_biblico t ON t.id = ht.texto_id
        WHERE ht.hino_id = ?
        ORDER BY t.id ASC
      ''', [hinoId]);
      return results.map((row) => row['referencia'] as String).toList();
    } catch (_) {
      return [];
    }
  }
}
