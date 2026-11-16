import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqlite3/common.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/bible_verse.dart';
import '../../services/auth_service.dart';

class BibleRepository {
  final DatabaseManager _dbManager;
  String _activeVersion = 'ARA';

  BibleRepository({DatabaseManager? dbManager, String initialVersion = 'ARA'})
      : _dbManager = dbManager ?? DatabaseManager(),
        _activeVersion = initialVersion;

  String get activeVersion => _activeVersion;
  set activeVersion(String version) {
    if (version.isNotEmpty) {
      _activeVersion = version.toUpperCase();
    }
  }

  Future<CommonDatabase> _getDb([String? version]) async {
    final ver = (version ?? _activeVersion).toUpperCase();
    return await _dbManager.getDatabase(AppConstants.bibleDbName(ver));
  }

  /// Retorna lista de livros bíblicos disponíveis com contagem de capítulos calculada
  Future<List<BibleBook>> getBooks({String? versionId}) async {
    final db = await _getDb();

    // Consulta os livros da tabela real 'book'
    final ResultSet bookRows = db.select(
      'SELECT id, name, testament_reference_id FROM book ORDER BY id ASC',
    );

    // Mapeia os capítulos máximos de cada livro em uma única query
    final ResultSet chapterRows = (versionId != null && versionId.isNotEmpty)
        ? db.select(
            'SELECT book_id, max(chapter) as total_capitulos FROM verse WHERE version = ? GROUP BY book_id',
            [versionId],
          )
        : db.select(
            'SELECT book_id, max(chapter) as total_capitulos FROM verse GROUP BY book_id',
          );

    final Map<int, int> chapterCounts = {};
    for (final row in chapterRows) {
      chapterCounts[row['book_id'] as int] = row['total_capitulos'] as int? ?? 1;
    }

    final filteredRows = (versionId != null && versionId.isNotEmpty)
        ? bookRows.where((row) => chapterCounts.containsKey(row['id'] as int))
        : bookRows;

    return filteredRows.map((row) {
      final bookId = row['id'] as int;
      final testamentRef = row['testament_reference_id'] as int? ?? 1;
      final String testament;
      if (testamentRef == 3) {
        testament = 'AP';
      } else if (testamentRef == 2) {
        testament = 'NT';
      } else {
        testament = 'VT';
      }
      return BibleBook(
        id: bookId,
        name: row['name'] as String,
        testament: testament,
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

  /// Retorna versículos específicos de uma versão bíblica para comparação
  Future<List<BibleVerse>> getVersesByNumbers(
    int bookId,
    int chapter,
    List<int> verseNumbers, {
    String? version,
  }) async {
    if (verseNumbers.isEmpty) return [];
    final db = await _getDb(version);
    final placeholders = List.filled(verseNumbers.length, '?').join(', ');
    final ResultSet results = db.select(
      '''
      SELECT v.id, v.book_id, b.name as book_name, v.chapter, v.verse, v.text
      FROM verse v
      JOIN book b ON b.id = v.book_id
      WHERE v.book_id = ? AND v.chapter = ? AND v.verse IN ($placeholders)
      ORDER BY v.verse ASC
      ''',
      [bookId, chapter, ...verseNumbers],
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

  /// Mapeamento de abreviações e nomes dos 66 livros para seus IDs canônicos (1 a 66)
  static final Map<String, int> _bookAliases = _initBookAliases();

  static Map<String, int> _initBookAliases() {
    final map = <String, int>{
      'gn': 1, 'gen': 1, 'genesis': 1, 'gênesis': 1,
      'ex': 2, 'exo': 2, 'exodo': 2, 'êxodo': 2, 'êx': 2,
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
      // Apócrifos / Deuterocanônicos e Enoque
      'tb': 67, 'tob': 67, 'tobias': 67,
      'jdt': 68, 'judite': 68,
      'sb': 69, 'sab': 69, 'sabedoria': 69, 'sabedoria de salomao': 69, 'sabedoria de salomão': 69,
      'eclo': 70, 'sir': 70, 'eclesiastico': 70, 'eclesiástico': 70, 'siracida': 70, 'sirácida': 70,
      'br': 71, 'bar': 71, 'baruc': 71, 'baruque': 71,
      '1mc': 72, '1 mc': 72, '1mac': 72, '1 mac': 72, '1macabeus': 72, '1 macabeus': 72, 'i macabeus': 72, '1º macabeus': 72, '1o macabeus': 72, 'imc': 72, 'i mc': 72,
      '2mc': 73, '2 mc': 73, '2mac': 73, '2 mac': 73, '2macabeus': 73, '2 macabeus': 73, 'ii macabeus': 73, '2º macabeus': 73, '2o macabeus': 73, 'iimc': 73, 'ii mc': 73,
      'en': 74, 'eno': 74, 'enoq': 74, 'enoque': 74, '1 enoque': 74, '1enoque': 74, 'i enoque': 74, 'livro de enoque': 74, '1º enoque': 74, '1o enoque': 74,
    };
    return map;
  }

  /// Normaliza string de nome de livro removendo diacríticos, pontuação e convertendo numerais romanos/ordinais.
  static String normalizeBookName(String text) {
    var s = text.toLowerCase().trim();
    const withDia = 'àáâãäåèéêëìíîïòóôõöùúûüçñ';
    const withoutDia = 'aaaaaaeeeeiiiiooooouuuucn';
    for (int i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    s = s.replaceAll('.', '');
    s = s.replaceAll(RegExp(r'^(?:iii|3[ºo]?)\s+'), '3 ');
    s = s.replaceAll(RegExp(r'^(?:ii|2[ºo]?)\s+'), '2 ');
    s = s.replaceAll(RegExp(r'^(?:i|1[ºo]?)\s+'), '1 ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Resolve o ID do livro bíblico a partir do nome ou abreviação canônica.
  ///
  /// Mantém compatibilidade com chamadores legados delegando para [resolveBookIdByAlias].
  static int? resolveBookId(String bookName) => resolveBookIdByAlias(bookName);

  /// Resolve o ID do livro bíblico a partir do nome, abreviação ou alias,
  /// normalizando diacríticos e numerais romanos (I, II, III, 1º, 2º).
  static int? resolveBookIdByAlias(String bookName) {
    // 1. Tenta correspondência direta em minúsculas preservando acentos (ex: 'jó' -> 18, 'jo' -> 43)
    final rawLower = bookName.toLowerCase().trim().replaceAll('.', '');
    if (_bookAliases.containsKey(rawLower)) return _bookAliases[rawLower];

    final norm = normalizeBookName(bookName);
    if (_bookAliases.containsKey(norm)) return _bookAliases[norm];

    // Tenta sem espaço para prefixos numéricos (ex: "1jo" -> 62, "1mc" -> 72)
    final noSpaces = norm.replaceAll(' ', '');
    if (_bookAliases.containsKey(noSpaces)) return _bookAliases[noSpaces];

    return null;
  }

  /// Mapeia aliases comuns para seus nomes canônicos normalizados.
  static String? _aliasToCanonicalName(String normAlias) {
    const aliasMap = {
      'gn': 'genesis', 'gen': 'genesis',
      'ex': 'exodo', 'exo': 'exodo',
      'lv': 'levitico', 'lev': 'levitico',
      'nm': 'numeros', 'num': 'numeros',
      'dt': 'deuteronomio', 'deu': 'deuteronomio', 'deut': 'deuteronomio',
      'js': 'josue', 'jos': 'josue',
      'jz': 'juizes', 'juiz': 'juizes',
      'rt': 'rute', 'rut': 'rute',
      '1sm': '1 samuel', '1 sam': '1 samuel', '1sam': '1 samuel',
      '2sm': '2 samuel', '2 sam': '2 samuel', '2sam': '2 samuel',
      '1rs': '1 reis', '1 rs': '1 reis',
      '2rs': '2 reis', '2 rs': '2 reis',
      '1cr': '1 cronicas', '1 cr': '1 cronicas',
      '2cr': '2 cronicas', '2 cr': '2 cronicas',
      'ed': 'esdras', 'esd': 'esdras',
      'ne': 'neemias', 'nee': 'neemias',
      'et': 'ester', 'est': 'ester',
      'jb': 'jo', 'job': 'jo',
      'sl': 'salmos', 'sal': 'salmos', 'salmo': 'salmos',
      'pv': 'proverbios', 'prv': 'proverbios',
      'ec': 'eclesiastes', 'ecl': 'eclesiastes',
      'ct': 'cantares', 'cant': 'cantares',
      'is': 'isaias', 'isa': 'isaias',
      'jr': 'jeremias', 'jer': 'jeremias',
      'lm': 'lamentacoes', 'lam': 'lamentacoes',
      'ez': 'ezequiel', 'eze': 'ezequiel',
      'dn': 'daniel', 'dan': 'daniel',
      'os': 'oseias', 'ose': 'oseias',
      'jl': 'joel', 'joe': 'joel',
      'am': 'amos', 'amo': 'amos',
      'ob': 'obadias', 'oba': 'obadias',
      'jn': 'jonas', 'jon': 'jonas',
      'mq': 'miqueias', 'miq': 'miqueias',
      'na': 'naum', 'nau': 'naum',
      'hc': 'habacuque', 'hab': 'habacuque',
      'sf': 'sofonias', 'sof': 'sofonias',
      'ag': 'ageu', 'age': 'ageu',
      'zc': 'zacarias', 'zac': 'zacarias',
      'ml': 'malaquias', 'mal': 'malaquias',
      'mt': 'mateus', 'mat': 'mateus',
      'mc': 'marcos', 'mar': 'marcos',
      'lc': 'lucas', 'luc': 'lucas',
      'jo': 'joao',
      'at': 'atos', 'ato': 'atos',
      'rm': 'romanos', 'rom': 'romanos',
      '1co': '1 corintios', '1 cor': '1 corintios',
      '2co': '2 corintios', '2 cor': '2 corintios',
      'gl': 'galatas', 'gal': 'galatas',
      'ef': 'efesios', 'efe': 'efesios',
      'fp': 'filipenses', 'fil': 'filipenses',
      'cl': 'colossenses', 'col': 'colossenses',
      '1ts': '1 tessalonicenses', '1 tes': '1 tessalonicenses',
      '2ts': '2 tessalonicenses', '2 tes': '2 tessalonicenses',
      '1tm': '1 timoteo', '1 tim': '1 timoteo',
      '2tm': '2 timoteo', '2 tim': '2 timoteo',
      'tt': 'tito', 'tit': 'tito',
      'fm': 'filemom', 'flm': 'filemom', 'filemon': 'filemom',
      'hb': 'hebreus', 'heb': 'hebreus',
      'tg': 'tiago', 'tia': 'tiago',
      '1pe': '1 pedro', '1 pe': '1 pedro', '1 ped': '1 pedro', '1p': '1 pedro',
      '2pe': '2 pedro', '2 pe': '2 pedro', '2 ped': '2 pedro', '2p': '2 pedro',
      '1jo': '1 joao', '1 jo': '1 joao',
      '2jo': '2 joao', '2 jo': '2 joao',
      '3jo': '3 joao', '3 jo': '3 joao',
      'jd': 'judas', 'jud': 'judas',
      'ap': 'apocalipse', 'apoc': 'apocalipse',
      'tb': 'tobias', 'tob': 'tobias',
      'jdt': 'judite',
      'sb': 'sabedoria', 'sab': 'sabedoria',
      'eclo': 'eclesiastico', 'sir': 'siracida',
      'br': 'baruc', 'bar': 'baruc',
      '1mc': '1 macabeus', '1 mc': '1 macabeus', '1mac': '1 macabeus', 'imc': '1 macabeus',
      '2mc': '2 macabeus', '2 mc': '2 macabeus', '2mac': '2 macabeus', 'iimc': '2 macabeus',
      'en': 'enoque', 'eno': 'enoque', 'enoq': 'enoque',
    };
    final noSpaces = normAlias.replaceAll(' ', '');
    return aliasMap[normAlias] ?? aliasMap[noSpaces] ?? normAlias;
  }

  /// Resolve o ID do livro no banco de dados ativo ou através do fallback canônico.
  @visibleForTesting
  Future<int?> resolveBookIdInDb(CommonDatabase db, String rawBook) =>
      _resolveBookIdInDb(db, rawBook);

  Future<int?> _resolveBookIdInDb(CommonDatabase db, String rawBook) async {
    final rawLower = rawBook.trim().toLowerCase().replaceAll('.', '');
    final normInput = normalizeBookName(rawBook);
    final targetName = _aliasToCanonicalName(normInput) ?? normInput;
    final normNoSpaces = normInput.replaceAll(' ', '');
    final targetNoSpaces = targetName.replaceAll(' ', '');

    try {
      final ResultSet rows = db.select('SELECT id, name FROM book');
      // 1. Prioriza correspondência exata de texto original em minúsculas (ex: 'jó' -> 'Jó')
      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final rawDbLower = name.trim().toLowerCase().replaceAll('.', '');
        if (rawDbLower == rawLower) {
          return id;
        }
      }

      // 2. Busca por nome normalizado ou alias canônico
      for (final row in rows) {
        final id = row['id'] as int;
        final name = row['name'] as String;
        final rawDbLower = name.trim().toLowerCase().replaceAll('.', '');
        final normDb = normalizeBookName(name);
        final dbNoSpaces = normDb.replaceAll(' ', '');

        // Desambiguação 'jo' vs 'jó': se a consulta for 'jo' sem acento,
        // não deve casar com o livro 'Jó' (deve casar com 'João' via targetName)
        if (rawLower == 'jo' && (rawDbLower == 'jó' || normDb == 'jo')) {
          continue;
        }

        if (normDb == normInput ||
            normDb == targetName ||
            dbNoSpaces == normNoSpaces ||
            dbNoSpaces == targetNoSpaces) {
          return id;
        }

        // Sinônimos de Enoque
        if ((normInput.contains('enoque') || targetName.contains('enoque') || normNoSpaces.contains('enoque')) &&
            normDb.contains('enoque')) {
          return id;
        }

        // Sinônimo Eclesiástico <-> Sirácida
        if ((normInput == 'eclesiastico' || normInput == 'siracida' ||
             targetName == 'eclesiastico' || targetName == 'siracida') &&
            (normDb == 'eclesiastico' || normDb == 'siracida')) {
          return id;
        }

        // Sinônimo Baruc <-> Baruque
        if ((normInput == 'baruc' || normInput == 'baruque' ||
             targetName == 'baruc' || targetName == 'baruque') &&
            (normDb == 'baruc' || normDb == 'baruque')) {
          return id;
        }
      }
    } catch (_) {
      // Ignora erro no select da tabela book
    }

    return resolveBookIdByAlias(rawBook);
  }

  /// Busca versículos de uma passagem bíblica textual (ex: "Ef 2:19 - 3:15", "Ef 2 - 3", "Is 6", "Ap 12:17", "Jo 3:16-17", "Sl 23:1-3")
  Future<List<BibleVerse>> buscarPassagem(String refText) async {
    var cleanRef = refText.trim().replaceAll(RegExp(r'^[\[\(\{"\\]+|[\]\)\}"\\]+$'), '').trim();
    cleanRef = cleanRef.replaceFirst(RegExp(r'^(?:e|ou|&|e/ou)\s+', caseSensitive: false), '').trim();

    final match = RegExp(
      r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(?:'
      r'(\d+)\s*[:.]\s*(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)\s*[:.]\s*(\d+)' // 2:c1, 3:v1, 4:c2, 5:v2
      r'|'
      r'(\d+)\s*[:.]\s*(\d+(?:\s*[-–—]\s*\d+)?(?:(?:,\s*|\s+(?:e|ou|&|e/ou)\s+)\d+(?:\s*[-–—]\s*\d+)?)*)' // 6:c1, 7:verses
      r'|'
      r'(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)' // 8:c1, 9:c2
      r'|'
      r'(\d+)' // 10:c1
      r')$',
      caseSensitive: false,
    ).firstMatch(cleanRef);

    if (match == null) return [];

    final rawBook = match.group(1) ?? '';
    final db = await _getDb();
    final bookId = await _resolveBookIdInDb(db, rawBook);
    if (bookId == null) return [];

    final List<Object?> params = [bookId];
    String whereClause = 'v.book_id = ?';

    if (match.group(2) != null) {
      // Multi-capítulo com versículos (ex: Ef 2:19 - 3:15)
      final c1 = int.tryParse(match.group(2)!) ?? 1;
      final v1 = int.tryParse(match.group(3)!) ?? 1;
      final c2 = int.tryParse(match.group(4)!) ?? c1;
      final v2 = int.tryParse(match.group(5)!) ?? v1;

      if (c1 == c2) {
        whereClause += ' AND v.chapter = ? AND v.verse >= ? AND v.verse <= ?';
        params.addAll([c1, v1 < v2 ? v1 : v2, v1 > v2 ? v1 : v2]);
      } else {
        final startC = c1 < c2 ? c1 : c2;
        final startV = c1 < c2 ? v1 : v2;
        final endC = c1 < c2 ? c2 : c1;
        final endV = c1 < c2 ? v2 : v1;

        whereClause += ' AND ((v.chapter = ? AND v.verse >= ?) OR (v.chapter > ? AND v.chapter < ?) OR (v.chapter = ? AND v.verse <= ?))';
        params.addAll([startC, startV, startC, endC, endC, endV]);
      }
    } else if (match.group(6) != null) {
      // Capítulo único com versículos (ex: Jo 3:16, Sl 23:1-3, Sl 23:1, 4)
      final chapter = int.tryParse(match.group(6)!) ?? 1;
      final verseStr = match.group(7) ?? '1';
      whereClause += ' AND v.chapter = ?';
      params.add(chapter);

      final parts = verseStr.split(RegExp(r',\s*|\s+(?:e|ou|&|e/ou)\s+'));
      if (parts.length > 1) {
        final List<String> orClauses = [];
        for (final p in parts) {
          final rangeM = RegExp(r'^(\d+)(?:\s*[-–—]\s*(\d+))?').firstMatch(p.trim());
          if (rangeM != null) {
            final vStart = int.tryParse(rangeM.group(1) ?? '1') ?? 1;
            final vEnd = rangeM.group(2) != null ? int.tryParse(rangeM.group(2)!) : null;
            if (vEnd != null) {
              orClauses.add('(v.verse >= ? AND v.verse <= ?)');
              params.addAll([vStart, vEnd]);
            } else {
              orClauses.add('v.verse = ?');
              params.add(vStart);
            }
          }
        }
        if (orClauses.isNotEmpty) {
          whereClause += ' AND (${orClauses.join(' OR ')})';
        }
      } else {
        final rangeM = RegExp(r'^(\d+)(?:\s*[-–—]\s*(\d+))?').firstMatch(verseStr.trim());
        if (rangeM != null) {
          final vStart = int.tryParse(rangeM.group(1) ?? '1') ?? 1;
          final vEnd = rangeM.group(2) != null ? int.tryParse(rangeM.group(2)!) : null;
          if (vEnd != null) {
            whereClause += ' AND v.verse >= ? AND v.verse <= ?';
            params.addAll([vStart, vEnd]);
          } else {
            whereClause += ' AND v.verse = ?';
            params.add(vStart);
          }
        }
      }
    } else if (match.group(8) != null) {
      // Múltiplos capítulos inteiros (ex: Ef 2 - 3)
      final c1 = int.tryParse(match.group(8)!) ?? 1;
      final c2 = int.tryParse(match.group(9)!) ?? c1;
      final startC = c1 < c2 ? c1 : c2;
      final endC = c1 < c2 ? c2 : c1;
      whereClause += ' AND v.chapter >= ? AND v.chapter <= ?';
      params.addAll([startC, endC]);
    } else if (match.group(10) != null) {
      // Capítulo único inteiro (ex: Is 6, Sl 23)
      final chapter = int.tryParse(match.group(10)!) ?? 1;
      whereClause += ' AND v.chapter = ?';
      params.add(chapter);
    }

    final query = '''
      SELECT v.id, v.book_id, b.name as book_name, v.chapter, v.verse, v.text
      FROM verse v
      JOIN book b ON b.id = v.book_id
      WHERE $whereClause
      ORDER BY v.chapter ASC, v.verse ASC
    ''';

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

  bool _highlightsTableEnsured = false;

  void _ensureHighlightsTable(CommonDatabase db) {
    if (_highlightsTableEnsured) return;
    try {
      db.execute('''
        CREATE TABLE IF NOT EXISTS verse_highlights (
          book_id INTEGER NOT NULL,
          chapter INTEGER NOT NULL,
          verse INTEGER NOT NULL,
          color TEXT NOT NULL,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (book_id, chapter, verse)
        );
      ''');
      _highlightsTableEnsured = true;
    } catch (e) {
      debugPrint('Erro ao criar tabela verse_highlights: $e');
    }
  }

  /// Retorna os destaques de um capítulo mapeando verse -> colorHex
  Future<Map<int, String>> getChapterHighlights(int bookId, int chapter) async {
    try {
      final db = await _dbManager.getDatabase(AppConstants.dbHymns);
      _ensureHighlightsTable(db);
      final ResultSet results = db.select(
        'SELECT verse, color FROM verse_highlights WHERE book_id = ? AND chapter = ?',
        [bookId, chapter],
      );
      final Map<int, String> map = {};
      for (final row in results) {
        final v = row['verse'] as int?;
        final c = row['color'] as String?;
        if (v != null && c != null) {
          map[v] = c;
        }
      }
      return map;
    } catch (e) {
      debugPrint('Erro ao buscar destaques do capítulo: $e');
      return {};
    }
  }

  /// Salva destaque de versículo no SQLite e sincroniza na nuvem
  Future<void> saveVerseHighlight(int bookId, int chapter, int verse, String colorHex) async {
    try {
      final db = await _dbManager.getDatabase(AppConstants.dbHymns);
      _ensureHighlightsTable(db);
      db.execute(
        '''
        INSERT OR REPLACE INTO verse_highlights (book_id, chapter, verse, color, updated_at)
        VALUES (?, ?, ?, ?, datetime('now'))
        ''',
        [bookId, chapter, verse, colorHex],
      );
    } catch (e) {
      debugPrint('Erro ao salvar destaque localmente: $e');
    }

    _syncHighlightToCloud(bookId, chapter, verse, colorHex);
  }

  /// Remove destaque de versículo no SQLite e na nuvem
  Future<void> removeVerseHighlight(int bookId, int chapter, int verse) async {
    try {
      final db = await _dbManager.getDatabase(AppConstants.dbHymns);
      _ensureHighlightsTable(db);
      db.execute(
        'DELETE FROM verse_highlights WHERE book_id = ? AND chapter = ? AND verse = ?',
        [bookId, chapter, verse],
      );
    } catch (e) {
      debugPrint('Erro ao remover destaque localmente: $e');
    }

    _removeHighlightFromCloud(bookId, chapter, verse);
  }

  void _syncHighlightToCloud(int bookId, int chapter, int verse, String colorHex) {
    final auth = AuthService();
    if (!auth.isAuthenticated) return;
    final token = auth.accessToken;
    final user = auth.currentUser;
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    if (supabaseUrl.isEmpty || token == null || user == null) return;

    () async {
      try {
        final endpoint = Uri.parse('$supabaseUrl/rest/v1/verse_highlights');
        await http.post(
          endpoint,
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
          },
          body: jsonEncode({
            'user_id': user.id,
            'book_id': bookId,
            'chapter': chapter,
            'verse': verse,
            'color': colorHex,
            'updated_at': DateTime.now().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Cloud sync highlight falhou: $e');
      }
    }();
  }

  void _removeHighlightFromCloud(int bookId, int chapter, int verse) {
    final auth = AuthService();
    if (!auth.isAuthenticated) return;
    final token = auth.accessToken;
    final user = auth.currentUser;
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    if (supabaseUrl.isEmpty || token == null || user == null) return;

    () async {
      try {
        final endpoint = Uri.parse(
          '$supabaseUrl/rest/v1/verse_highlights?user_id=eq.${user.id}&book_id=eq.$bookId&chapter=eq.$chapter&verse=eq.$verse',
        );
        await http.delete(
          endpoint,
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Cloud remove highlight falhou: $e');
      }
    }();
  }

  /// Baixa destaques salvos no Supabase do usuário autenticado e os mescla no SQLite local.
  Future<void> syncHighlightsFromCloud() async {
    final auth = AuthService();
    if (!auth.isAuthenticated) return;
    final token = auth.accessToken;
    final user = auth.currentUser;
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;
    if (supabaseUrl.isEmpty || token == null || user == null) return;

    try {
      final endpoint = Uri.parse(
        '$supabaseUrl/rest/v1/verse_highlights?user_id=eq.${Uri.encodeComponent(user.id)}&select=book_id,chapter,verse,color,updated_at',
      );
      final res = await http.get(
        endpoint,
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return;
      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is! List || list.isEmpty) return;

      final db = await _dbManager.getDatabase(AppConstants.dbHymns);
      _ensureHighlightsTable(db);
      for (final item in list) {
        if (item is! Map) continue;
        final b = (item['book_id'] as num?)?.toInt();
        final c = (item['chapter'] as num?)?.toInt();
        final v = (item['verse'] as num?)?.toInt();
        final color = item['color']?.toString() ?? '';
        final updatedAt = item['updated_at']?.toString() ?? DateTime.now().toIso8601String();
        if (b != null && c != null && v != null && color.isNotEmpty) {
          db.execute(
            '''
            INSERT OR REPLACE INTO verse_highlights (book_id, chapter, verse, color, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ''',
            [b, c, v, color, updatedAt],
          );
        }
      }
    } catch (e) {
      debugPrint('[BibleRepository] Falha ao baixar destaques da nuvem: $e');
    }
  }
}
