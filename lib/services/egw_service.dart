import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/database/database_manager.dart';
import '../models/egw_models.dart';

/// Serviço gerenciador de livros e capítulos do Espírito de Profecia (Ellen G. White)
/// com suporte a sincronização online, parsing estruturado de parágrafos,
/// cache SQLite local instantâneo e downloads offline em lote.
class EgwService {
  static final EgwService _instance = EgwService._internal();
  factory EgwService() => _instance;
  EgwService._internal();

  static const String _booksTable = 'egw_books_cache';
  static const String _chaptersTable = 'egw_chapters_cache';

  /// Catálogo padrão completo de 79 obras únicas de Ellen G. White em português.
  /// Contém 28 IDs numéricos oficiais pré-verificados e 51 IDs com resolução dinâmica.
  static const List<Map<String, String>> defaultCatalog = [
    // --- Série Conflito dos Séculos (5 Obras Canônicas) ---
    {
      'id': '1815',
      'title': 'Patriarcas e Profetas',
      'abbr': 'PP',
      'desc': 'A história do conflito entre o bem e o mal desde a criação do mundo até o reinado de Davi.',
    },
    {
      'id': '1816',
      'title': 'Profetas e Reis',
      'abbr': 'PR',
      'desc': 'A história desde o reinado de Salomão até o cativeiro de Israel e os profetas do Antigo Testamento.',
    },
    {
      'id': '1813',
      'title': 'O Desejado de Todas as Nações',
      'abbr': 'DTN',
      'desc': 'A obra-prima sobre a vida, ministério, morte e ressurreição de Jesus Cristo.',
    },
    {
      'id': '1806',
      'title': 'Atos dos Apóstolos',
      'abbr': 'AA',
      'desc': 'O nascimento da igreja cristã, o Pentecostes e a pregação dos primeiros apóstolos.',
    },
    {
      'id': '11125',
      'title': 'O Grande Conflito',
      'abbr': 'GC',
      'desc': 'O desenrolar da batalha cósmica entre Cristo e Satanás até a Nova Terra.',
    },

    // --- Clássicos Devocionais e Vida Prática (IDs Numéricos Pré-verificados) ---
    {
      'id': '11121',
      'title': 'Caminho a Cristo',
      'abbr': 'CC',
      'desc': 'Guia essencial para a fé prática, o arrependimento, a oração e a comunhão com Jesus.',
    },
    {
      'id': '1931',
      'title': 'Parábolas de Jesus',
      'abbr': 'PJ',
      'desc': 'Lições espirituais profundas extraídas das parábolas contadas pelo Salvador.',
    },
    {
      'id': '1956',
      'title': 'O Maior Discurso de Cristo',
      'abbr': 'MDC',
      'desc': 'Meditações sobre o Sermão da Montanha e os princípios do Reino Celestial.',
    },
    {
      'id': '1951',
      'title': 'Mensagens aos Jovens',
      'abbr': 'MJ',
      'desc': 'Instruções e princípios fundamentais para a juventude cristã em tempos desafiadores.',
    },
    {
      'id': '1948',
      'title': 'Educação',
      'abbr': 'ED',
      'desc': 'O desenvolvimento harmônico do físico, intelectual e espiritual.',
    },
    {
      'id': '1955',
      'title': 'O Lar Adventista',
      'abbr': 'LA',
      'desc': 'Princípios para a construção de famílias felizes, amorosas e consagradas.',
    },
    {
      'id': '1957',
      'title': 'Primeiros Escritos',
      'abbr': 'PE',
      'desc': 'As primeiras visões e relatos da pioneira sobre o movimento adventista.',
    },
    {
      'id': '1949',
      'title': 'História da Redenção',
      'abbr': 'HR',
      'desc': 'Visão panorâmica e condensada do plano da salvação desde a queda de Lúcifer.',
    },
    {
      'id': '11255',
      'title': 'A Ciência do Bom Viver',
      'abbr': 'CBV',
      'desc': 'Princípios de saúde, restauração física, mental e serviço ao próximo.',
    },
    {
      'id': '1729',
      'title': 'Eventos Finais',
      'abbr': 'EF',
      'desc': 'Orientações sobre os acontecimentos escatológicos antes da volta de Jesus.',
    },
    {
      'id': '1727',
      'title': 'Vida de Jesus',
      'abbr': 'VJ',
      'desc': 'Relato acessível e envolvente da vida de Cristo especialmente para crianças e jovens.',
    },
    {
      'id': '1818',
      'title': 'Serviço Cristão',
      'abbr': 'SC',
      'desc': 'Capacitação prática para o evangelismo e o testemunho diário.',
    },
    {
      'id': '1810',
      'title': 'Conselhos sobre Mordomia',
      'abbr': 'CM',
      'desc': 'O uso sábio dos dons, do tempo, dos talentos e dos recursos confiados por Deus.',
    },
    {
      'id': '1724',
      'title': 'Conselhos sobre a Escola Sabatina',
      'abbr': 'CES',
      'desc': 'Princípios para o ensino, liderança e dinamismo da Escola Sabatina.',
    },
    {
      'id': '11093',
      'title': 'Conselhos sobre o Regime Alimentar',
      'abbr': 'CRA',
      'desc': 'Instruções fundamentais para a alimentação equilibrada e o cuidado do corpo.',
    },
    {
      'id': '1945',
      'title': 'Beneficência Social',
      'abbr': 'BS',
      'desc': 'O ministério de compaixão em favor dos necessitados, órfãos e desvalidos.',
    },
    {
      'id': '1726',
      'title': 'Fé e Obras',
      'abbr': 'FO',
      'desc': 'A harmonia entre a justificação pela fé e a obediência genuína.',
    },
    {
      'id': '11246',
      'title': 'Mensagens Escolhidas, vol. 1',
      'abbr': '1ME',
      'desc': 'Coletânea temática com declarações sobre inspiração, salvação e vida cristã.',
    },
    {
      'id': '11098',
      'title': 'Mensagens Escolhidas, vol. 2',
      'abbr': '2ME',
      'desc': 'Orientações sobre fanatismo, práticas médicas e organização eclesiástica.',
    },
    {
      'id': '11097',
      'title': 'Mensagens Escolhidas, vol. 3',
      'abbr': '3ME',
      'desc': 'Instruções sobre liderança, relacionamentos e fidelidade profética.',
    },
    {
      'id': '1947',
      'title': 'Conselhos sobre Educação',
      'abbr': 'CE',
      'desc': 'Princípios essenciais para mestres e alunos na busca da sabedoria celestial.',
    },
    {
      'id': '1819',
      'title': 'Testemunhos para a Igreja, vol. 1',
      'abbr': '1TI',
      'desc': 'As primeiras mensagens proféticas e exortações direcionadas à igreja remanescente.',
    },
    {
      'id': '1592',
      'title': 'Testemunhos para a Igreja, vol. 9',
      'abbr': '9TI',
      'desc': 'Conselhos solenes finais sobre consagração pessoal, grandes cidades e o encerramento da obra.',
    },

    // --- Obras e Volumes Adicionais do Catálogo Oficial PT (Resolução Dinâmica) ---
    {
      'id': 'pt_mensagens_tres_anjos',
      'title': 'As Mensagens dos Três Anjos',
      'abbr': 'MTA',
      'desc': 'As mensagens proféticas cruciais de Apocalipse 14 proclamadas ao mundo.',
    },
    {
      'id': 'pt_conselhos_para_a_igreja',
      'title': 'Conselhos para a Igreja',
      'abbr': 'CI',
      'desc': 'Seleção abrangente de diretrizes e conselhos para a igreja contemporânea.',
    },
    {
      'id': 'pt_conselhos_aos_idosos',
      'title': 'Conselhos aos Idosos',
      'abbr': 'CAI',
      'desc': 'Conforto, sabedoria e orientações para a terceira idade.',
    },
    {
      'id': 'pt_cartas_jovens_namorados',
      'title': 'Cartas a Jovens Namorados',
      'abbr': 'CJN',
      'desc': 'Conselhos afetuosos e práticos sobre amor, namoro e casamento cristão.',
    },
    {
      'id': 'pt_como_lidar_emocoes',
      'title': 'Como Lidar com as Emoções',
      'abbr': 'CLE',
      'desc': 'Diretrizes para o equilíbrio psicológico, autocontrole e saúde emocional.',
    },
    {
      'id': 'pt_conselhos_professores_pais_estudantes',
      'title': 'Conselhos aos Professores, Pais e Estudantes',
      'abbr': 'CPPE',
      'desc': 'Fundamentos da verdadeira pedagogia cristã na escola e no lar.',
    },
    {
      'id': 'pt_cristo_seu_santuario',
      'title': 'Cristo em Seu Santuário',
      'abbr': 'CS',
      'desc': 'O ministério sacerdotal de Cristo e a doutrina bíblica do santuário.',
    },
    {
      'id': 'pt_conselhos_sobre_saude',
      'title': 'Conselhos sobre Saúde',
      'abbr': 'CSS',
      'desc': 'Princípios de higiene, prevenção e tratamentos naturais para o bem-estar.',
    },
    {
      'id': 'pt_evangelismo',
      'title': 'Evangelismo',
      'abbr': 'EV',
      'desc': 'Métodos bíblicos e estratégias para a proclamação das boas-novas da salvação.',
    },
    {
      'id': 'pt_filhas_de_deus',
      'title': 'Filhas de Deus',
      'abbr': 'FD',
      'desc': 'A vocação, influência e ministério transformador das mulheres na causa de Deus.',
    },
    {
      'id': 'pt_foi_por_voce',
      'title': 'Foi por Você',
      'abbr': 'FPV',
      'desc': 'Mensagens tocantes sobre o infinito amor e sacrifício de Jesus na cruz.',
    },
    {
      'id': 'pt_fundamentos_educacao_crista',
      'title': 'Fundamentos da Educação Cristã',
      'abbr': 'FEC',
      'desc': 'Princípios essenciais para a formação acadêmica e do caráter.',
    },
    {
      'id': 'pt_fundamentos_lar_cristao',
      'title': 'Fundamentos do Lar Cristão',
      'abbr': 'FLC',
      'desc': 'Orientações fundamentais para o fortalecimento dos lares e famílias.',
    },
    {
      'id': 'pt_a_grande_esperanca',
      'title': 'A Grande Esperança',
      'abbr': 'GE',
      'desc': 'Versão condensada e missionária dos grandes temas do conflito cósmico.',
    },
    {
      'id': 'pt_igreja_remanescente',
      'title': 'A Igreja Remanescente',
      'abbr': 'IR',
      'desc': 'A identidade, missão e triunfo final do povo remanescente de Deus.',
    },
    {
      'id': 'pt_licoes_vida_neemias',
      'title': 'Lições da Vida de Neemias',
      'abbr': 'LVN',
      'desc': 'Liderança, coragem espiritual e reconstrução sob a bênção divina.',
    },
    {
      'id': 'pt_lideranca_crista',
      'title': 'Liderança Cristã',
      'abbr': 'LC',
      'desc': 'Qualidades essenciais, integridade e humildade na condução da obra de Deus.',
    },
    {
      'id': 'pt_mente_carater_1',
      'title': 'Mente, Caráter e Personalidade, vol. 1',
      'abbr': '1MCP',
      'desc': 'Estudo aprofundado sobre a mente humana, psicologia e relações interpessoais.',
    },
    {
      'id': 'pt_mente_carater_2',
      'title': 'Mente, Caráter e Personalidade, vol. 2',
      'abbr': '2MCP',
      'desc': 'A continuidade do estudo das faculdades mentais, sentimentos e caráter cristão.',
    },
    {
      'id': 'pt_mensageiros_esperanca',
      'title': 'Mensageiros da Esperança',
      'abbr': 'MEsp',
      'desc': 'Chamado aos crentes para espalhar a luz da esperança em um mundo em trevas.',
    },
    {
      'id': 'pt_ministerio_cidades',
      'title': 'Ministério para as Cidades',
      'abbr': 'MC',
      'desc': 'Estratégias e urgência para alcançar os grandes centros urbanos.',
    },
    {
      'id': 'pt_musica_influencia',
      'title': 'Música — Sua Influência na Vida do Cristão',
      'abbr': 'MU',
      'desc': 'O papel sagrado da música no louvor, adoração e desenvolvimento espiritual.',
    },
    {
      'id': 'pt_medicina_salvacao',
      'title': 'Medicina e Salvação',
      'abbr': 'MS',
      'desc': 'A união entre a obra médico-missionária e a proclamação do evangelho.',
    },
    {
      'id': 'pt_no_deserto_tentacao',
      'title': 'No Deserto da Tentação',
      'abbr': 'NDT',
      'desc': 'A vitória de Cristo sobre as tentações no deserto e lições para vencer o pecado.',
    },
    {
      'id': 'pt_colportor_evangelista',
      'title': 'O Colportor Evangelista',
      'abbr': 'CEv',
      'desc': 'A importância e a nobreza da distribuição da literatura da verdade presente.',
    },
    {
      'id': 'pt_orientacao_crianca',
      'title': 'Orientação da Criança',
      'abbr': 'OC',
      'desc': 'Princípios divinos para educar e conduzir os filhos a Cristo.',
    },
    {
      'id': 'pt_obreiros_evangelicos',
      'title': 'Obreiros Evangélicos',
      'abbr': 'OE',
      'desc': 'Conselhos vitais para pastores, evangelistas e obreiros da causa divina.',
    },
    {
      'id': 'pt_o_outro_poder',
      'title': 'O Outro Poder',
      'abbr': 'OP',
      'desc': 'O ministério da imprensa e a influência do poder da palavra impressa.',
    },
    {
      'id': 'pt_reavivamento_resultados',
      'title': 'Reavivamento e Seus Resultados',
      'abbr': 'RR',
      'desc': 'O verdadeiro despertamento espiritual e seus frutos duradouros na igreja.',
    },
    {
      'id': 'pt_reavivamento_verdadeiro',
      'title': 'Reavivamento Verdadeiro',
      'abbr': 'RV',
      'desc': 'O maior e mais urgente de todos os nossos deveres: o reavivamento da piedade.',
    },
    {
      'id': 'pt_so_para_jovens',
      'title': 'Só para Jovens',
      'abbr': 'SPJ',
      'desc': 'Mensagens diretas, dinâmicas e inspiradoras para a mocidade.',
    },
    {
      'id': 'pt_santificacao',
      'title': 'Santificação',
      'abbr': 'SA',
      'desc': 'A natureza progressiva da santificação bíblica e a perfeição em Cristo.',
    },
    {
      'id': 'pt_ser_mae',
      'title': 'Ser Mãe — O Que É?',
      'abbr': 'SM',
      'desc': 'A bênção, os desafios e a sublime recompensa da maternidade cristã.',
    },
    {
      'id': 'pt_testemunhos_igreja_2',
      'title': 'Testemunhos para a Igreja, vol. 2',
      'abbr': '2TI',
      'desc': 'Mensagens pastorais sobre a consagração e advertências à igreja.',
    },
    {
      'id': 'pt_testemunhos_igreja_3',
      'title': 'Testemunhos para a Igreja, vol. 3',
      'abbr': '3TI',
      'desc': 'Orientações sobre fidelidade, zelo missionário e pureza moral.',
    },
    {
      'id': 'pt_testemunhos_igreja_4',
      'title': 'Testemunhos para a Igreja, vol. 4',
      'abbr': '4TI',
      'desc': 'Conselhos sobre liderança, instituições e desenvolvimento do caráter.',
    },
    {
      'id': 'pt_testemunhos_igreja_5',
      'title': 'Testemunhos para a Igreja, vol. 5',
      'abbr': '5TI',
      'desc': 'Instruções para enfrentar as crises finais e perseverar na fé bíblica.',
    },
    {
      'id': 'pt_testemunhos_igreja_6',
      'title': 'Testemunhos para a Igreja, vol. 6',
      'abbr': '6TI',
      'desc': 'A preparação da igreja para a crise final e o trabalho educacional e médico.',
    },
    {
      'id': 'pt_testemunhos_igreja_7',
      'title': 'Testemunhos para a Igreja, vol. 7',
      'abbr': '7TI',
      'desc': 'O estabelecimento de centros de influência, publicações e sanitários.',
    },
    {
      'id': 'pt_testemunhos_igreja_8',
      'title': 'Testemunhos para a Igreja, vol. 8',
      'abbr': '8TI',
      'desc': 'Alertas cruciais contra o panteísmo, falsas teorias e o poder do Espírito Santo.',
    },
    {
      'id': 'pt_conduta_sexual',
      'title': 'Testemunho sobre Conduta Sexual, Adultério e Divórcio',
      'abbr': 'TCS',
      'desc': 'Orientações morais claras sobre pureza, fidelidade e integridade matrimonial.',
    },
    {
      'id': 'pt_temperanca',
      'title': 'Temperança',
      'abbr': 'TE',
      'desc': 'O domínio próprio, a vitória sobre vícios e o equilíbrio em todas as áreas da vida.',
    },
    {
      'id': 'pt_testemunhos_ministros',
      'title': 'Testemunhos para Ministros e Obreiros Evangélicos',
      'abbr': 'TM',
      'desc': 'Mensagens solenes de alerta, reforma e encorajamento aos líderes ministeriais.',
    },
    {
      'id': 'pt_testemunhos_seletos_1',
      'title': 'Testemunhos Seletos, vol. 1',
      'abbr': '1TS',
      'desc': 'Antologia dos primeiros testemunhos sobre a caminhada e fidelidade do remanescente.',
    },
    {
      'id': 'pt_testemunhos_seletos_2',
      'title': 'Testemunhos Seletos, vol. 2',
      'abbr': '2TS',
      'desc': 'Seleção de instruções práticas sobre vida comunitária, saúde e dons do Espírito.',
    },
    {
      'id': 'pt_testemunhos_seletos_3',
      'title': 'Testemunhos Seletos, vol. 3',
      'abbr': '3TS',
      'desc': 'Coletânea de advertências finais e instruções para a igreja triunfante.',
    },
    {
      'id': 'pt_convite_diferenca',
      'title': 'Um Convite à Diferença',
      'abbr': 'UCD',
      'desc': 'O chamado cristão para uma vida distinta de integridade e propósito divino.',
    },
    {
      'id': 'pt_verdade_anjos',
      'title': 'A Verdade sobre os Anjos',
      'abbr': 'VA',
      'desc': 'A atuação invisível dos anjos celestiais na história humana e na salvação.',
    },
    {
      'id': 'pt_vida_no_campo',
      'title': 'Vida no Campo',
      'abbr': 'VC',
      'desc': 'As bênçãos do ambiente rural para a formação do caráter e a preservação da família.',
    },
    {
      'id': 'pt_vida_e_ensinos',
      'title': 'Vida e Ensinos',
      'abbr': 'VE',
      'desc': 'Esboço biográfico e a rica trajetória espiritual da pioneira Ellen G. White.',
    },
    {
      'id': 'pt_visoes_do_ceu',
      'title': 'Visões do Céu',
      'abbr': 'VCE',
      'desc': 'As sublimes descrições proféticas da Nova Jerusalém e da eternidade com Cristo.',
    },
  ];

  /// Extrai o ID numérico oficial do livro a partir do HTML de busca do portal EGW Writings.
  @visibleForTesting
  static String? extractNumericBookIdFromHtml(String html) {
    if (html.isEmpty) return null;
    final match = RegExp(r'/pt/book/(\d+)', caseSensitive: false).firstMatch(html);
    return match?.group(1);
  }

  /// Garante a existência das tabelas no SQLite com suporte a migração idempotente de colunas adicionais.
  Future<void> _ensureTablesCreated() async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        CREATE TABLE IF NOT EXISTS $_booksTable (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          abbreviation TEXT,
          cover_url TEXT,
          cpb_cover_url TEXT,
          resolved_id TEXT,
          description TEXT,
          total_chapters INTEGER DEFAULT 0,
          is_downloaded INTEGER DEFAULT 0,
          updated_at INTEGER
        );
      ''');

      // Migração idempotente para tabelas existentes
      try {
        db.execute('ALTER TABLE $_booksTable ADD COLUMN cpb_cover_url TEXT;');
      } catch (_) {}

      try {
        db.execute('ALTER TABLE $_booksTable ADD COLUMN resolved_id TEXT;');
      } catch (_) {}

      db.execute('''
        CREATE TABLE IF NOT EXISTS $_chaptersTable (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          chapter_id TEXT NOT NULL,
          chapter_index INTEGER NOT NULL,
          title TEXT NOT NULL,
          content_json TEXT NOT NULL,
          cached_at INTEGER NOT NULL
        );
      ''');

      db.execute('''
        CREATE INDEX IF NOT EXISTS idx_egw_chapters_book 
        ON $_chaptersTable (book_id);
      ''');
    } catch (e) {
      debugPrint('[EgwService] Erro ao criar tabelas: $e');
    }
  }

  /// Tenta resolver dinamicamente o ID numérico oficial da obra consultando o portal oficial EGW Writings.
  Future<String?> _resolveNumericBookIdOnline(String bookId, String bookTitle) async {
    try {
      final queryUrl = Uri.parse('https://m.egwwritings.org/pt/search?q=${Uri.encodeComponent(bookTitle)}');
      final resp = await http.get(queryUrl, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final resolvedId = extractNumericBookIdFromHtml(resp.body);
        if (resolvedId != null && resolvedId.isNotEmpty) {
          final coverUrl = 'https://media4.egwwritings.org/covers/${resolvedId}_r.jpg';
          final db = await DatabaseManager().getDatabase('hinario.db');
          db.execute('''
            UPDATE $_booksTable 
            SET resolved_id = ?, cover_url = ?, updated_at = ? 
            WHERE id = ?;
          ''', [resolvedId, coverUrl, DateTime.now().millisecondsSinceEpoch, bookId]);
          return resolvedId;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Falha ao resolver ID numérico online para $bookId ($bookTitle): $e');
    }
    return null;
  }

  /// Retorna a lista de livros disponíveis com status de cache/download
  Future<List<EgwBook>> getBooks() async {
    await _ensureTablesCreated();

    try {
      final db = await DatabaseManager().getDatabase('hinario.db');

      // Mapeia contagem de capítulos baixados por livro
      final chapterCounts = <String, int>{};
      final countRows = db.select('''
        SELECT book_id, COUNT(DISTINCT chapter_id) as qtd 
        FROM $_chaptersTable 
        WHERE LENGTH(TRIM(content_json)) > 0 
        GROUP BY book_id;
      ''');
      for (final r in countRows) {
        final bId = (r['book_id'] ?? '').toString();
        final count = (r['qtd'] as int?) ?? 0;
        chapterCounts[bId] = count;
      }

      // Consulta livros salvos no banco
      final bookRows = db.select('SELECT * FROM $_booksTable;');
      final dbBooksMap = <String, Map<String, dynamic>>{};
      for (final r in bookRows) {
        final bId = (r['id'] ?? '').toString();
        dbBooksMap[bId] = Map<String, dynamic>.from(r);
      }

      final List<EgwBook> books = [];

      for (final item in defaultCatalog) {
        final id = item['id']!;
        final downloadedCount = chapterCounts[id] ?? 0;

        if (dbBooksMap.containsKey(id)) {
          final row = dbBooksMap[id]!;
          books.add(EgwBook.fromMap(row, downloaded: downloadedCount));
        } else {
          // Insere catálogo padrão inicial
          final book = EgwBook(
            id: id,
            title: item['title']!,
            abbreviation: item['abbr']!,
            description: item['desc']!,
            downloadedChapters: downloadedCount,
          );
          db.execute('''
            INSERT OR IGNORE INTO $_booksTable (
              id, title, abbreviation, cover_url, cpb_cover_url, resolved_id, description, total_chapters, is_downloaded, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
          ''', [
            book.id,
            book.title,
            book.abbreviation,
            book.coverUrl,
            book.cpbCoverUrl,
            book.resolvedId,
            book.description,
            0,
            0,
            DateTime.now().millisecondsSinceEpoch,
          ]);
          books.add(book);
        }
      }

      return books;
    } catch (e) {
      debugPrint('[EgwService] Erro ao listar livros: $e');
      return defaultCatalog.map((item) {
        return EgwBook(
          id: item['id']!,
          title: item['title']!,
          abbreviation: item['abbr']!,
          description: item['desc']!,
        );
      }).toList();
    }
  }

  /// Determina se o cache local do sumário (TOC) deve ser ignorado para forçar busca online.
  ///
  /// Retorna `true` quando [forceRefresh] é verdadeiro, quando [cachedHeadersCount] é zero,
  /// quando o total [knownTotalChapters] é desconhecido (zero) e há apenas um capítulo em cache
  /// (típico de leitura online avulsa que salvou apenas um cabeçalho), ou quando o total conhecido
  /// de capítulos é superior à quantidade atualmente em cache ([knownTotalChapters] > [cachedHeadersCount]).
  @visibleForTesting
  bool shouldBypassTocCache({
    required bool forceRefresh,
    required int cachedHeadersCount,
    required int knownTotalChapters,
  }) {
    if (forceRefresh) return true;
    if (cachedHeadersCount == 0) return true;
    if (knownTotalChapters == 0 && cachedHeadersCount <= 1) return true;
    if (knownTotalChapters > cachedHeadersCount) return true;
    return false;
  }

  /// Avalia a completude do download de um livro com base na contagem real de capítulos salvos.
  ///
  /// Delega a validação para [EgwBook.evaluateDownloadCompleteness], assegurando que
  /// [cachedChapterCount] atinja [expectedTotalChapters] ou satisfaça [flaggedDownloaded].
  @visibleForTesting
  bool evaluateDownloadCompleteness({
    required int cachedChapterCount,
    required int expectedTotalChapters,
    required bool flaggedDownloaded,
  }) {
    return EgwBook.evaluateDownloadCompleteness(
      cachedChapterCount: cachedChapterCount,
      expectedTotalChapters: expectedTotalChapters,
      flaggedDownloaded: flaggedDownloaded,
    );
  }

  /// Busca o sumário (lista de capítulos) do livro identificado por [bookId].
  ///
  /// Quando [forceRefresh] é falso, avalia se os cabeçalhos em cache local são suficientes
  /// utilizando [shouldBypassTocCache]. Se for necessário atualizar ou se o cache for parcial,
  /// realiza a busca online no portal oficial. Caso a obra possua ID slug não-numérico,
  /// resolve dinamicamente o ID numérico correspondente antes da consulta.
  Future<List<EgwChapterHeader>> getTableOfContents(
    String bookId, {
    bool forceRefresh = false,
  }) async {
    await _ensureTablesCreated();

    List<EgwChapterHeader> cachedHeaders = [];
    int knownTotalChapters = 0;
    String bookTitle = '';
    String? resolvedId;

    // 1. Tenta carregar capítulos já baixados em ordem e consultar metadados do livro
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');

      final bookRows = db.select(
        'SELECT title, total_chapters, resolved_id FROM $_booksTable WHERE id = ? LIMIT 1;',
        [bookId],
      );
      if (bookRows.isNotEmpty) {
        final row = bookRows.first;
        bookTitle = (row['title'] ?? '').toString();
        knownTotalChapters = (row['total_chapters'] as int?) ?? 0;
        resolvedId = row['resolved_id']?.toString();
      }

      final rows = db.select('''
        SELECT chapter_id, chapter_index, title 
        FROM $_chaptersTable 
        WHERE book_id = ? 
        ORDER BY chapter_index ASC;
      ''', [bookId]);

      if (rows.isNotEmpty) {
        cachedHeaders = rows.map((r) {
          return EgwChapterHeader(
            bookId: bookId,
            chapterId: (r['chapter_id'] ?? '').toString(),
            chapterIndex: (r['chapter_index'] as int?) ?? 0,
            title: (r['title'] ?? '').toString(),
          );
        }).toList();

        final bypass = shouldBypassTocCache(
          forceRefresh: forceRefresh,
          cachedHeadersCount: cachedHeaders.length,
          knownTotalChapters: knownTotalChapters,
        );

        if (!bypass) {
          return cachedHeaders;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao consultar sumário local: $e');
    }

    // 2. Determina ID numérico efetivo para a requisição HTTP
    String effectiveId = (resolvedId != null && RegExp(r'^\d+$').hasMatch(resolvedId))
        ? resolvedId
        : bookId;

    if (!RegExp(r'^\d+$').hasMatch(effectiveId)) {
      if (bookTitle.isEmpty) {
        final item = defaultCatalog.firstWhere(
          (c) => c['id'] == bookId,
          orElse: () => {'title': bookId},
        );
        bookTitle = item['title']!;
      }
      final resolved = await _resolveNumericBookIdOnline(bookId, bookTitle);
      if (resolved != null) {
        effectiveId = resolved;
      }
    }

    // 3. Busca online do TOC oficial de m.egwwritings.org
    try {
      final url = Uri.parse('https://m.egwwritings.org/pt/book/$effectiveId/toc');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final headers = _parseTocHtml(effectiveId, resp.body, catalogBookId: bookId);
        if (headers.isNotEmpty) {
          // Atualiza total de capítulos na tabela de livros sob a chave local do catálogo
          final db = await DatabaseManager().getDatabase('hinario.db');
          db.execute('''
            UPDATE $_booksTable 
            SET total_chapters = ?, updated_at = ? 
            WHERE id = ?;
          ''', [headers.length, DateTime.now().millisecondsSinceEpoch, bookId]);
          return headers;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao buscar sumário online: $e');
    }

    // Fallback gracioso: retorna capítulos parciais em cache se busca online falhou
    if (cachedHeaders.isNotEmpty) {
      return cachedHeaders;
    }

    return [];
  }

  /// Busca o conteúdo completo de um capítulo
  Future<EgwChapter?> getChapter(
    String bookId,
    String chapterId, {
    int? chapterIndex,
    String? fallbackTitle,
  }) async {
    await _ensureTablesCreated();
    final fullId = '$bookId.$chapterId';

    // 1. Tenta carregar do cache SQLite
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select(
        'SELECT content_json FROM $_chaptersTable WHERE id = ? LIMIT 1;',
        [fullId],
      );
      if (rows.isNotEmpty) {
        final jsonStr = rows.first['content_json'] as String?;
        if (jsonStr != null && jsonStr.isNotEmpty) {
          return EgwChapter.fromJson(jsonStr);
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao carregar capítulo do cache: $e');
    }

    // Determina o ID numérico efetivo para a URL
    String effectiveId = bookId;
    if (!RegExp(r'^\d+$').hasMatch(bookId)) {
      try {
        final db = await DatabaseManager().getDatabase('hinario.db');
        final rows = db.select('SELECT title, resolved_id FROM $_booksTable WHERE id = ? LIMIT 1;', [bookId]);
        if (rows.isNotEmpty) {
          final res = rows.first['resolved_id']?.toString();
          if (res != null && RegExp(r'^\d+$').hasMatch(res)) {
            effectiveId = res;
          } else {
            final title = (rows.first['title'] ?? '').toString();
            final resolved = await _resolveNumericBookIdOnline(bookId, title);
            if (resolved != null) effectiveId = resolved;
          }
        }
      } catch (_) {}
    }

    // 2. Busca online de m.egwwritings.org
    try {
      final remotePath = '$effectiveId.$chapterId';
      final url = Uri.parse('https://m.egwwritings.org/pt/book/$remotePath');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
      }).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final chapter = _parseChapterHtml(
          bookId: bookId,
          chapterId: chapterId,
          chapterIndex: chapterIndex ?? 1,
          htmlBody: resp.body,
          fallbackTitle: fallbackTitle,
        );

        if (chapter != null && chapter.paragraphs.isNotEmpty) {
          // Salva no cache SQLite local associado à chave bookId
          await _saveChapterToCache(chapter);
          return chapter;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao buscar capítulo online: $e');
    }

    return null;
  }

  /// Salva um capítulo no cache SQLite
  Future<void> _saveChapterToCache(EgwChapter chapter) async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        INSERT OR REPLACE INTO $_chaptersTable (
          id, book_id, chapter_id, chapter_index, title, content_json, cached_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
      ''', [
        chapter.id,
        chapter.bookId,
        chapter.chapterId,
        chapter.chapterIndex,
        chapter.title,
        chapter.toJson(),
        DateTime.now().millisecondsSinceEpoch,
      ]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao salvar capítulo em cache: $e');
    }
  }

  /// Baixa todos os capítulos do livro [bookId] em lote para visualização offline.
  ///
  /// Força a atualização do sumário completo com `forceRefresh: true` para evitar
  /// truncamento decorrente de cache parcial. Notifica o progresso via [onProgress]
  /// e verifica periodicamente [shouldCancel]. Ao final, valida se a quantidade de capítulos
  /// com conteúdo real no SQLite confere com o total esperado antes de marcar como baixado.
  Future<void> downloadBook(
    String bookId, {
    void Function(int current, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    await _ensureTablesCreated();

    final toc = await getTableOfContents(bookId, forceRefresh: true);
    if (toc.isEmpty) return;

    final total = toc.length;
    int current = 0;

    final db = await DatabaseManager().getDatabase('hinario.db');
    db.execute('''
      UPDATE $_booksTable 
      SET total_chapters = ?, updated_at = ? 
      WHERE id = ?;
    ''', [total, DateTime.now().millisecondsSinceEpoch, bookId]);

    for (final header in toc) {
      if (shouldCancel?.call() == true) {
        debugPrint('[EgwService] Download cancelado pelo usuário.');
        return;
      }

      await getChapter(
        bookId,
        header.chapterId,
        chapterIndex: header.chapterIndex,
        fallbackTitle: header.title,
      );

      current++;
      onProgress?.call(current, total);

      // Pequena pausa (60ms) para não sobrecarregar
      await Future.delayed(const Duration(milliseconds: 60));
    }

    // Valida se todos os capítulos foram realmente salvos no banco local
    try {
      final countRows = db.select('''
        SELECT COUNT(DISTINCT chapter_id) as qtd 
        FROM $_chaptersTable 
        WHERE book_id = ? AND LENGTH(TRIM(content_json)) > 0;
      ''', [bookId]);
      final actualCached = countRows.first['qtd'] as int? ?? 0;
      final isComplete = evaluateDownloadCompleteness(
        cachedChapterCount: actualCached,
        expectedTotalChapters: total,
        flaggedDownloaded: true,
      );

      if (isComplete) {
        db.execute('''
          UPDATE $_booksTable 
          SET is_downloaded = 1, total_chapters = ?, updated_at = ? 
          WHERE id = ?;
        ''', [total, DateTime.now().millisecondsSinceEpoch, bookId]);
      } else {
        db.execute('''
          UPDATE $_booksTable 
          SET is_downloaded = 0, total_chapters = ?, updated_at = ? 
          WHERE id = ?;
        ''', [total, DateTime.now().millisecondsSinceEpoch, bookId]);
        debugPrint('[EgwService] Download parcial/incompleto para livro $bookId ($actualCached de $total salvos).');
        throw StateError('Download incompleto: apenas $actualCached de $total capítulos foram baixados.');
      }
    } catch (e) {
      if (e is StateError) rethrow;
      debugPrint('[EgwService] Erro ao atualizar status de download: $e');
    }
  }

  /// Remove os capítulos baixados do livro
  Future<void> deleteBookDownload(String bookId) async {
    await _ensureTablesCreated();
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('DELETE FROM $_chaptersTable WHERE book_id = ?;', [bookId]);
      db.execute('''
        UPDATE $_booksTable 
        SET is_downloaded = 0, updated_at = ? 
        WHERE id = ?;
      ''', [DateTime.now().millisecondsSinceEpoch, bookId]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao excluir livro: $e');
    }
  }

  /// Checa se o livro [bookId] está 100% baixado e íntegro para uso offline.
  ///
  /// Avalia a integridade consultando o total de capítulos e a contagem real de registros
  /// com conteúdo não vazio na tabela de capítulos via [evaluateDownloadCompleteness].
  Future<bool> isBookDownloaded(String bookId) async {
    await _ensureTablesCreated();
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select(
        'SELECT total_chapters, is_downloaded FROM $_booksTable WHERE id = ? LIMIT 1;',
        [bookId],
      );
      if (rows.isNotEmpty) {
        final flaggedDown = (rows.first['is_downloaded'] as int? ?? 0) == 1;
        final total = (rows.first['total_chapters'] as int? ?? 0);
        final countRows = db.select('''
          SELECT COUNT(DISTINCT chapter_id) as qtd 
          FROM $_chaptersTable 
          WHERE book_id = ? AND LENGTH(TRIM(content_json)) > 0;
        ''', [bookId]);
        final downloaded = countRows.first['qtd'] as int? ?? 0;
        return evaluateDownloadCompleteness(
          cachedChapterCount: downloaded,
          expectedTotalChapters: total,
          flaggedDownloaded: flaggedDown,
        );
      }
    } catch (e) {
      debugPrint('[EgwService] Erro ao checar status de download: $e');
    }
    return false;
  }

  // --- MÉTODOS DE PARSER HTML PURO EM DART ---

  static List<EgwChapterHeader> _parseTocHtml(
    String effectiveBookId,
    String html, {
    String? catalogBookId,
  }) {
    final List<EgwChapterHeader> list = [];
    final escapedId = RegExp.escape(effectiveBookId);
    final regex = RegExp(
      '<li[^>]+id=["\']l\\.$escapedId\\.(\\d+)["\'][^>]*>\\s*<a[^>]+href=["\']/pt/book/$escapedId\\.(\\d+)["\'][^>]*>(.*?)<\\/a>',
      caseSensitive: false,
    );

    final finalBookId = catalogBookId ?? effectiveBookId;
    int index = 1;
    for (final match in regex.allMatches(html)) {
      final chapterId = match.group(1) ?? match.group(2) ?? '';
      final rawTitle = match.group(3) ?? '';
      final cleanTitle = _cleanHtmlText(rawTitle);

      if (chapterId.isNotEmpty && cleanTitle.isNotEmpty) {
        list.add(
          EgwChapterHeader(
            bookId: finalBookId,
            chapterId: chapterId,
            chapterIndex: index++,
            title: cleanTitle,
          ),
        );
      }
    }
    return list;
  }

  static EgwChapter? _parseChapterHtml({
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required String htmlBody,
    String? fallbackTitle,
  }) {
    // 1. Extração do Título
    String title = fallbackTitle ?? 'Capítulo $chapterIndex';
    final headerMatch = RegExp(
      r'<h[1-3][^>]*egw_content_wrapper[^>]*>.*?<span[^>]*egw_content[^>]*>(.*?)</span>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(htmlBody);

    if (headerMatch != null) {
      final extracted = _cleanHtmlText(headerMatch.group(1) ?? '');
      if (extracted.isNotEmpty) {
        title = extracted;
      }
    }

    // 2. Extração dos Parágrafos
    final List<EgwParagraph> paragraphs = [];
    final paraRegex = RegExp(
      r'<p[^>]*egw_content_wrapper[^>]*id="?(\d+)"?[^>]*data-refcode="?([^">]*)"?[^>]*>(.*?)</p>',
      dotAll: true,
      caseSensitive: false,
    );

    for (final m in paraRegex.allMatches(htmlBody)) {
      final pId = m.group(1) ?? '';
      final refcode = m.group(2)?.trim() ?? '';
      final inner = m.group(3) ?? '';

      // Tenta achar o span egw_content
      final contentSpanMatch = RegExp(
        r'<span[^>]*egw_content[^>]*>(.*?)</span>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(inner);

      final rawContent = contentSpanMatch != null ? (contentSpanMatch.group(1) ?? '') : inner;
      final cleanText = _cleanHtmlText(rawContent);

      if (cleanText.isNotEmpty) {
        paragraphs.add(
          EgwParagraph(
            id: pId,
            refcode: refcode,
            text: cleanText,
          ),
        );
      }
    }

    return EgwChapter(
      id: '$bookId.$chapterId',
      bookId: bookId,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
      title: title,
      paragraphs: paragraphs,
    );
  }

  /// Limpa tags HTML e converte entidades comuns
  static String _cleanHtmlText(String raw) {
    if (raw.isEmpty) return '';

    var clean = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
    clean = clean
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ldquo;', '“')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rsquo;', '’');

    // Converte múltiplos espaços em um só e faz trim
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
