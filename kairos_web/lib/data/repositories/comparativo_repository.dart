import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';

class ComparativoItem {
  final int id;
  final String numeroNovo;
  final String numeroAntigo;
  final String tituloNovo;
  final String tituloAntigo;
  final String categoriaNova;
  final String categoriaAntiga;
  final String statusComparacao;
  final bool modificado;
  final double similaridadePct;
  final String? diffTexto;
  final String? diffJson;
  final String? resumoAlteracoes;

  const ComparativoItem({
    required this.id,
    required this.numeroNovo,
    required this.numeroAntigo,
    required this.tituloNovo,
    required this.tituloAntigo,
    required this.categoriaNova,
    required this.categoriaAntiga,
    required this.statusComparacao,
    required this.modificado,
    required this.similaridadePct,
    this.diffTexto,
    this.diffJson,
    this.resumoAlteracoes,
  });

  factory ComparativoItem.fromMap(Map<String, dynamic> map) {
    return ComparativoItem(
      id: map['id'] as int? ?? 0,
      numeroNovo: (map['numero_novo'] ?? '').toString(),
      numeroAntigo: (map['numero_antigo'] ?? '').toString(),
      tituloNovo: (map['titulo_novo'] ?? '').toString(),
      tituloAntigo: (map['titulo_antigo'] ?? '').toString(),
      categoriaNova: (map['categoria_nova'] ?? '').toString(),
      categoriaAntiga: (map['categoria_antiga'] ?? '').toString(),
      statusComparacao: (map['status_comparacao'] ?? '').toString(),
      modificado: (map['modificado'] as int? ?? 0) == 1,
      similaridadePct: (map['similaridade_pct'] as num? ?? 0.0).toDouble(),
      diffTexto: map['diff_texto'] as String?,
      diffJson: map['diff_json'] as String?,
      resumoAlteracoes: map['resumo_alteracoes'] as String?,
    );
  }
}

class ComparativoRepository {
  final DatabaseManager _dbManager;

  ComparativoRepository({DatabaseManager? dbManager})
      : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbHymnsComparativo);
  }

  /// Retorna comparação de hino por número novo (ex: '1', '10') ou antigo
  Future<ComparativoItem?> getByNumero(String numero, {bool isNovo = true}) async {
    final db = await _getDb();
    final col = isNovo ? 'numero_novo' : 'numero_antigo';
    final ResultSet results = db.select(
      '''
      SELECT id, numero_novo, numero_antigo, titulo_novo, titulo_antigo,
             categoria_nova, categoria_antiga, status_comparacao, modificado,
             similaridade_pct, diff_texto, diff_json, resumo_alteracoes
      FROM comparativo_hinos
      WHERE $col = ?
      LIMIT 1
      ''',
      [numero.trim()],
    );

    if (results.isEmpty) return null;
    return ComparativoItem.fromMap(results.first);
  }
}
