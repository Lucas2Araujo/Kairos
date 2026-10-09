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

  /// Mapeamento de abreviações e nomes dos 66 livros para seus IDs canônicos (1 a 66)
  static final Map<String, int> _bookAliases = _initBookAliases();

  static Map<String, int> _initBookAliases() {
    final map = <String, int>{
      'gn': 1, 'gen': 1, 'genesis': 1, 'gênesis': 1,
      'ex': 2, 'exo': 2, 'exodo': 2, 'êxodo': 2,
      'lv': 3, 'lev': 3, 'levitico': 3, 'levítico': 3,
      'nm': 4, 'num': 4, 'numeros': 4, 'números': 4,
      'dt': 5, 'deu': 5, 'deut': 5, 'deuteronomio': 5, 'deuteronômio': 5,
      'js': 6, 'jos': 6, 'josue': 6, 'josué': 6,
      'jz': 7, 'juiz': 7, 'juizes': 7, 'juízes': 7,
      'rt': 8, 'rut': 8, 'rute': 8,
      '1sm': 9, '1 sm': 9, '1sam': 9, '1 sam': 9, '1samuel': 9, '1 samuel': 9, 'i samuel': 9,
      '2sm': 10, '2 sm': 10, '2sam': 10, '2 sam': 10, '2samuel': 10, '2 samuel': 10, 'ii samuel': 10,
      '1rs': 11, '1 rs': 11, '1reis': 11, '1 reis': 11, 'i reis': 11,
      '2rs': 12, '2 rs': 12, '2reis': 12, '2 reis': 12, 'ii reis': 12,
      '1cr': 13, '1 cr': 13, '1cronicas': 13, '1 crônicas': 13, '1 cronicas': 13, 'i cronicas': 13,
      '2cr': 14, '2 cr': 14, '2cronicas': 14, '2 crônicas': 14, '2 cronicas': 14, 'ii cronicas': 14,
      'ed': 15, 'esd': 15, 'esdras': 15,
      'ne': 16, 'nee': 16, 'neemias': 16,
      'et': 17, 'est': 17, 'ester': 17,
      'jb': 18, 'job': 18, 'jó': 18,
      'sl': 19, 'sal': 19, 'salmo': 19, 'salmos': 19,
      'pv': 20, 'prv': 20, 'proverbios': 20, 'provérbios': 20,
      'ec': 21, 'ecl': 21, 'eclesiastes': 21,
      'ct': 22, 'cant': 22, 'cantares': 22, 'cânticos': 22,
      'is': 23, 'isa': 23, 'isaias': 23, 'isaías': 23,
      'jr': 24, 'jer': 24, 'jeremias': 24,
      'lm': 25, 'lam': 25, 'lamentacoes': 25, 'lamentações': 25,
      'ez': 26, 'eze': 26, 'ezequiel': 26,
      'dn': 27, 'dan': 27, 'daniel': 27,
      'os': 28, 'ose': 28, 'oseias': 28, 'oséias': 28,
      'jl': 29, 'joe': 29, 'joel': 29,
      'am': 30, 'amo': 30, 'amos': 30, 'amós': 30,
      'ob': 31, 'oba': 31, 'obadias': 31,
      'jn': 32, 'jon': 32, 'jonas': 32,
      'mq': 33, 'miq': 33, 'miqueias': 33, 'miquéias': 33,
      'na': 34, 'nau': 34, 'naum': 34,
      'hc': 35, 'hab': 35, 'habacuque': 35,
      'sf': 36, 'sof': 36, 'sofonias': 36,
      'ag': 37, 'age': 37, 'ageu': 37,
      'zc': 38, 'zac': 38, 'zacarias': 38,
      'ml': 39, 'mal': 39, 'malaquias': 39,
      'mt': 40, 'mat': 40, 'mateus': 40,
      'mc': 41, 'mar': 41, 'marcos': 41,
      'lc': 42, 'luc': 42, 'lucas': 42,
      'jo': 43, 'joao': 43, 'joão': 43,
      'at': 44, 'ato': 44, 'atos': 44,
      'rm': 45, 'rom': 45, 'romanos': 45,
      '1co': 46, '1 co': 46, '1cor': 46, '1 cor': 46, '1corintios': 46, '1 coríntios': 46, 'i corintios': 46,
      '2co': 47, '2 co': 47, '2cor': 47, '2 cor': 47, '2corintios': 47, '2 coríntios': 47, 'ii corintios': 47,
      'gl': 48, 'gal': 48, 'galatas': 48, 'gálatas': 48,
      'ef': 49, 'efe': 49, 'efesios': 49, 'efésios': 49,
      'fp': 50, 'fil': 50, 'filipenses': 50,
      'cl': 51, 'col': 51, 'colossenses': 51,
      '1ts': 52, '1 ts': 52, '1tes': 52, '1 tes': 52, '1tessalonicenses': 52, '1 tessalonicenses': 52, 'i tes': 52,
      '2ts': 53, '2 ts': 53, '2tes': 53, '2 tes': 53, '2tessalonicenses': 53, '2 tessalonicenses': 53, 'ii tes': 53,
      '1tm': 54, '1 tm': 54, '1tim': 54, '1 tim': 54, '1timoteo': 54, '1 timóteo': 54, 'i tim': 54,
      '2tm': 55, '2 tm': 55, '2tim': 55, '2 tim': 55, '2timoteo': 55, '2 timóteo': 55, 'ii tim': 55,
      'tt': 56, 'tit': 56, 'tito': 56,
      'fm': 57, 'flm': 57, 'filemon': 57, 'filemom': 57,
      'hb': 58, 'heb': 58, 'hebreus': 58,
      'tg': 59, 'tia': 59, 'tiago': 59,
      '1pe': 60, '1 pe': 60, '1ped': 60, '1 ped': 60, '1pedro': 60, '1 pedro': 60, '1p': 60, 'i pedro': 60,
      '2pe': 61, '2 pe': 61, '2ped': 61, '2 ped': 61, '2pedro': 61, '2 pedro': 61, '2p': 61, 'ii pedro': 61,
      '1jo': 62, '1 jo': 62, '1joao': 62, '1 joão': 62, 'i joao': 62,
      '2jo': 63, '2 jo': 63, '2joao': 63, '2 joão': 63, 'ii joao': 63,
      '3jo': 64, '3 jo': 64, '3joao': 64, '3 joão': 64, 'iii joao': 64,
      'jd': 65, 'jud': 65, 'judas': 65,
      'ap': 66, 'apoc': 66, 'apocalipse': 66, 'revelacao': 66, 'revelação': 66,
    };
    return map;
  }

  static String _normalize(String text) {
    var s = text.toLowerCase().trim();
    const withDia = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
    const withoutDia = 'aaaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    return s;
  }

  /// Resolve o ID do livro bíblico a partir do nome ou abreviação
  static int? resolveBookId(String bookName) {
    final norm = _normalize(bookName).replaceAll(RegExp(r'\s+'), ' ');
    if (_bookAliases.containsKey(norm)) return _bookAliases[norm];

    // Tenta sem espaço para prefixos numéricos (ex: "1jo" -> 62)
    final noSpaces = norm.replaceAll(' ', '');
    if (_bookAliases.containsKey(noSpaces)) return _bookAliases[noSpaces];

    return null;
  }

  /// Busca versículos de uma passagem bíblica textual (ex: "Is 6", "Ap 12:17", "Jo 3:16-17", "Sl 23:1-3")
  Future<List<BibleVerse>> buscarPassagem(String refText) async {
    final cleanRef = refText.trim().replaceAll(RegExp(r'^[\[\(\{"\\]+|[\]\)\}"\\]+$'), '');
    final match = RegExp(
      r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?:\s*[:,\.]\s*(\d+)(?:\s*[-–]\s*(\d+))?)?',
    ).firstMatch(cleanRef);

    if (match == null) return [];

    final rawBook = match.group(1) ?? '';
    final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
    final startVerse = match.group(3) != null ? int.tryParse(match.group(3)!) : null;
    final endVerse = match.group(4) != null ? int.tryParse(match.group(4)!) : startVerse;

    final bookId = resolveBookId(rawBook);
    if (bookId == null) return [];

    final db = await _getDb();
    final List<Object?> params = [bookId, chapter];
    String query = '''
      SELECT v.id, v.book_id, b.name as book_name, v.chapter, v.verse, v.text
      FROM verse v
      JOIN book b ON b.id = v.book_id
      WHERE v.book_id = ? AND v.chapter = ?
    ''';

    if (startVerse != null && endVerse != null) {
      query += ' AND v.verse >= ? AND v.verse <= ?';
      params.add(startVerse);
      params.add(endVerse);
    } else if (startVerse != null) {
      query += ' AND v.verse = ?';
      params.add(startVerse);
    }

    query += ' ORDER BY v.verse ASC';

    try {
      final ResultSet results = db.select(query, params);
      return results.map((row) {
        return BibleVerse(
          id: row['id'] as int,
          bookId: row['book_id'] as int,
          bookName: row['book_name'] as String? ?? rawBook,
          chapter: row['chapter'] as int,
          verse: row['verse'] as int,
          text: row['text'] as String,
        );
      }).toList();
    } catch (e) {
      return [];
    }
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
