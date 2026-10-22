import 'package:sqlite3/common.dart';
import '../models/hymn.dart';

/// Item litúrgico recomendado para o culto
class CultRecommendation {
  final String section;
  final Hymn hymn;
  final int order;

  const CultRecommendation({
    required this.section,
    required this.hymn,
    required this.order,
  });
}

/// Modelo de lista de culto salva
class CultListModel {
  final int id;
  final String temaGerador;
  final String dataCriacao;
  final List<Hymn> hymns;

  const CultListModel({
    required this.id,
    required this.temaGerador,
    required this.dataCriacao,
    this.hymns = const [],
  });
}

/// Recomendador litúrgico local e determinístico para cultos
class CultListRecommender {
  /// As 5 seções litúrgicas padrão na ordem do culto
  static const List<String> sections = [
    'Introito',
    'Oração Pastoral',
    'Hino do Sermão',
    'Ofertório',
    'Despedida',
  ];

  /// Gera recomendações de hinos por seção litúrgica com base determinística no tema.
  static List<CultRecommendation> recommend({
    required CommonDatabase db,
    String theme = '',
  }) {
    final cleanTheme = theme.trim();
    final seed = _computeSeed(cleanTheme);

    final introitos = _getHymnsBySubcategory(db, 'Introito');
    final oracoes = _getHymnsBySubcategory(db, 'Oração Pastoral');
    final ofertorios = _getHymnsBySubcategory(db, 'Ofertório');
    final despedidas = _getHymnsBySubcategory(db, 'Despedida');
    final sermaos = _getSermonHymns(db, cleanTheme);

    final recommendations = <CultRecommendation>[];

    if (introitos.isNotEmpty) {
      recommendations.add(CultRecommendation(
        section: 'Introito',
        hymn: introitos[seed % introitos.length],
        order: 1,
      ));
    }

    if (oracoes.isNotEmpty) {
      recommendations.add(CultRecommendation(
        section: 'Oração Pastoral',
        hymn: oracoes[(seed + 3) % oracoes.length],
        order: 2,
      ));
    }

    if (sermaos.isNotEmpty) {
      recommendations.add(CultRecommendation(
        section: 'Hino do Sermão',
        hymn: sermaos[(seed + 7) % sermaos.length],
        order: 3,
      ));
    }

    if (ofertorios.isNotEmpty) {
      recommendations.add(CultRecommendation(
        section: 'Ofertório',
        hymn: ofertorios[(seed + 11) % ofertorios.length],
        order: 4,
      ));
    }

    if (despedidas.isNotEmpty) {
      recommendations.add(CultRecommendation(
        section: 'Despedida',
        hymn: despedidas[(seed + 17) % despedidas.length],
        order: 5,
      ));
    }

    return recommendations;
  }

  static int _computeSeed(String text) {
    if (text.isEmpty) return 42;
    return text.toLowerCase().codeUnits.fold(0, (acc, c) => (acc * 31 + c) & 0x7FFFFFFF);
  }

  static List<Hymn> _getHymnsBySubcategory(CommonDatabase db, String subcat) {
    try {
      final ResultSet res = db.select('''
        SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
        FROM hino
        WHERE subcategoria = ?
        ORDER BY CAST(numero AS INTEGER) ASC;
      ''', [subcat]);
      if (res.isNotEmpty) {
        return res.map((r) => Hymn.fromMap(Map<String, dynamic>.from(r))).toList();
      }
    } catch (_) {}

    // Fallback gracioso
    return _getFallbackHymns(db);
  }

  static List<Hymn> _getSermonHymns(CommonDatabase db, String theme) {
    if (theme.isNotEmpty) {
      try {
        final pattern = '%$theme%';
        final ResultSet res = db.select('''
          SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
          FROM hino
          WHERE categoria LIKE ? OR subcategoria LIKE ? OR titulo LIKE ?
          ORDER BY 
            CASE 
              WHEN subcategoria LIKE ? THEN 1
              WHEN categoria LIKE ? THEN 2
              ELSE 3
            END,
            CAST(numero AS INTEGER) ASC
          LIMIT 30;
        ''', [pattern, pattern, pattern, pattern, pattern]);

        if (res.isNotEmpty) {
          return res.map((r) => Hymn.fromMap(Map<String, dynamic>.from(r))).toList();
        }
      } catch (_) {}
    }

    // Fallback para introdução ao sermão ou categorias centrais
    try {
      final ResultSet res = db.select('''
        SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
        FROM hino
        WHERE subcategoria = 'Introdução ao Sermão' 
           OR categoria LIKE '%Cristo%' 
           OR categoria LIKE '%Salvação%'
        ORDER BY CAST(numero AS INTEGER) ASC
        LIMIT 30;
      ''');
      if (res.isNotEmpty) {
        return res.map((r) => Hymn.fromMap(Map<String, dynamic>.from(r))).toList();
      }
    } catch (_) {}

    return _getFallbackHymns(db);
  }

  static List<Hymn> _getFallbackHymns(CommonDatabase db) {
    try {
      final ResultSet res = db.select('''
        SELECT id, numero, titulo, letra, autor_letra, autor_musica, texto_base, categoria, subcategoria, autores, link_video
        FROM hino
        ORDER BY id ASC
        LIMIT 10;
      ''');
      return res.map((r) => Hymn.fromMap(Map<String, dynamic>.from(r))).toList();
    } catch (_) {
      return [];
    }
  }

  // --- Operações de Persistência no SQLite ---

  static void ensureTables(CommonDatabase db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS lista_culto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tema_gerador TEXT,
        data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS item_lista_culto (
        lista_id INTEGER NOT NULL,
        hino_id INTEGER NOT NULL,
        ordem_execucao INTEGER NOT NULL,
        PRIMARY KEY (lista_id, hino_id)
      );
    ''');
  }

  static List<CultListModel> getLists(CommonDatabase db) {
    ensureTables(db);
    final ResultSet res = db.select('''
      SELECT id, tema_gerador, data_criacao
      FROM lista_culto
      ORDER BY id DESC;
    ''');
    final lists = <CultListModel>[];
    for (final row in res) {
      final listId = row['id'] as int;
      final hymnsRes = db.select('''
        SELECT h.id, h.numero, h.titulo, h.letra, h.autor_letra, h.autor_musica, h.texto_base, h.categoria, h.subcategoria, h.autores, h.link_video
        FROM item_lista_culto i
        JOIN hino h ON h.id = i.hino_id
        WHERE i.lista_id = ?
        ORDER BY i.ordem_execucao ASC;
      ''', [listId]);
      final hymns = hymnsRes.map((r) => Hymn.fromMap(Map<String, dynamic>.from(r))).toList();
      lists.add(CultListModel(
        id: listId,
        temaGerador: (row['tema_gerador'] ?? 'Culto de Louvor').toString(),
        dataCriacao: (row['data_criacao'] ?? '').toString(),
        hymns: hymns,
      ));
    }
    return lists;
  }

  static int createList(CommonDatabase db, {required String tema, required List<int> hymnIds}) {
    ensureTables(db);
    final cleanTema = tema.trim().isEmpty ? 'Culto de Louvor' : tema.trim();
    db.execute(
      'INSERT INTO lista_culto (tema_gerador, data_criacao) VALUES (?, CURRENT_TIMESTAMP);',
      [cleanTema],
    );
    final idRes = db.select('SELECT last_insert_rowid() as id;');
    final listId = idRes.first['id'] as int;

    for (int i = 0; i < hymnIds.length; i++) {
      db.execute(
        'INSERT OR REPLACE INTO item_lista_culto (lista_id, hino_id, ordem_execucao) VALUES (?, ?, ?);',
        [listId, hymnIds[i], i + 1],
      );
    }
    return listId;
  }

  static void deleteList(CommonDatabase db, int listId) {
    ensureTables(db);
    db.execute('DELETE FROM item_lista_culto WHERE lista_id = ?;', [listId]);
    db.execute('DELETE FROM lista_culto WHERE id = ?;', [listId]);
  }
}
