import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/database/database_manager.dart';
import '../core/database/database_manager_io.dart'
    if (dart.library.js_interop) '../core/database/database_manager_web.dart';
import '../models/egw_models.dart';

/// Serviço gerenciador de livros e capítulos do Espírito de Profecia (Ellen G. White)
/// com suporte a pacotes pré-processados no Cloudflare R2, resolução dinâmica pelo
/// portal oficial (`m.egwwritings.org`), parsing estruturado de parágrafos e cache SQLite.
class EgwService {
  static final EgwService _instance = EgwService._internal();
  factory EgwService() => _instance;
  EgwService._internal();

  static const String _booksTable = 'egw_books_cache';
  static const String _chaptersTable = 'egw_chapters_cache';
  static const String _officialPtFolderUrl = 'https://m.egwwritings.org/pt/folders/245';

  /// Mapa estático de IDs numéricos oficiais já verificados para livros que ainda
  /// utilizam identificador textual (`pt_...`) no catálogo local.
  static const Map<String, String> preResolvedNumericIds = {
    'pt_evangelismo': '115',
    'pt_orientacao_crianca': '1505',
    'pt_obreiros_evangelicos': '72',
  };

  Map<String, dynamic>? _cachedR2Manifest;
  DateTime? _manifestFetchedAt;

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

  /// Carrega (com cache de sessão) o manifesto de pacotes EGW hospedado no Cloudflare R2.
  Future<Map<String, dynamic>?> _fetchR2Manifest({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedR2Manifest != null &&
        _manifestFetchedAt != null &&
        now.difference(_manifestFetchedAt!).inMinutes < 30) {
      return _cachedR2Manifest;
    }
    try {
      final url = Uri.parse('${AppConfig.r2AudioBaseUrl}/egw/egw_manifest.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final decoded = json.decode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          _cachedR2Manifest = decoded;
          _manifestFetchedAt = now;
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Manifesto R2 indisponível no momento: $e');
    }
    return _cachedR2Manifest;
  }

  /// Realiza GET textual no portal EGW com cadeia multi-proxy CORS quando executando na Web.
  Future<http.Response?> _fetchEgwHttp(
    String targetUrl, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (!kIsWeb) {
      const headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) KairosApp/1.0',
        'Accept-Language': 'pt-BR,pt;q=0.9',
      };
      try {
        final directResp = await http
            .get(Uri.parse(targetUrl), headers: headers)
            .timeout(timeout);
        if (directResp.statusCode == 200 && directResp.bodyBytes.isNotEmpty) {
          return directResp;
        }
      } catch (e) {
        debugPrint('[EgwService] Erro HTTP direto em $targetUrl: $e');
      }
      return null;
    }

    // Na Web (localhost ou GitHub Pages), requisições diretas a m.egwwritings.org
    // são bloqueadas por CORS. Tenta cadeia resiliente de proxies públicos sem
    // headers customizados para evitar preflight OPTIONS.
    final encodedUrl = Uri.encodeComponent(targetUrl);
    final proxyCandidates = <({String url, bool isJsonWrapper})>[
      (url: 'https://api.codetabs.com/v1/proxy?quest=$encodedUrl', isJsonWrapper: false),
      (url: 'https://corsproxy.io/?url=$encodedUrl', isJsonWrapper: false),
      (url: 'https://api.allorigins.win/get?url=$encodedUrl', isJsonWrapper: true),
      (url: 'https://api.allorigins.win/raw?url=$encodedUrl', isJsonWrapper: false),
    ];

    for (final candidate in proxyCandidates) {
      try {
        final resp = await http.get(Uri.parse(candidate.url)).timeout(timeout);
        if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
          continue;
        }
        if (candidate.isJsonWrapper) {
          final decoded = json.decode(utf8.decode(resp.bodyBytes));
          if (decoded is Map && decoded['contents'] is String) {
            final contents = decoded['contents'] as String;
            if (contents.trim().isNotEmpty) {
              return http.Response.bytes(
                utf8.encode(contents),
                200,
                headers: const {'content-type': 'text/html; charset=utf-8'},
              );
            }
          }
          continue;
        }
        return resp;
      } catch (e) {
        debugPrint('[EgwService] Proxy CORS indisponível (${candidate.url}): $e');
      }
    }

    return null;
  }

  /// Normaliza texto em português (sem acentos/pontuação) para comparar títulos entre catálogo e site.
  static String _normalizeTitleForMatch(String input) {
    const replacements = {
      'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
      'ç': 'c', 'ñ': 'n',
    };
    final lower = input.toLowerCase();
    final sb = StringBuffer();
    for (int i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final mapped = replacements[ch] ?? ch;
      if (RegExp(r'[a-z0-9\s]').hasMatch(mapped)) {
        sb.write(mapped);
      } else {
        sb.write(' ');
      }
    }
    return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Resolve e persiste no SQLite o ID numérico oficial para um livro cujo ID é textual (`pt_...`).
  Future<String?> _resolveNumericBookIdOnline(String bookId, String bookTitle) async {
    // 1. Mapa estático pré-verificado
    final preResolved = preResolvedNumericIds[bookId];
    if (preResolved != null && preResolved.isNotEmpty) {
      await _persistResolvedBookId(bookId, preResolved);
      return preResolved;
    }

    // 2. Manifesto R2 (aliases e correspondência por título)
    final manifest = await _fetchR2Manifest();
    if (manifest != null) {
      final aliases = manifest['aliases'];
      if (aliases is Map && aliases[bookId] != null) {
        final aliasId = aliases[bookId].toString();
        if (RegExp(r'^\d+$').hasMatch(aliasId)) {
          await _persistResolvedBookId(bookId, aliasId);
          return aliasId;
        }
      }
      final booksMap = manifest['books'];
      if (booksMap is Map && bookTitle.isNotEmpty) {
        final normTarget = _normalizeTitleForMatch(bookTitle);
        for (final entry in booksMap.entries) {
          final val = entry.value;
          if (val is Map &&
              _normalizeTitleForMatch((val['title'] ?? '').toString()) == normTarget) {
            final foundId = entry.key.toString();
            if (RegExp(r'^\d+$').hasMatch(foundId)) {
              await _persistResolvedBookId(bookId, foundId);
              return foundId;
            }
          }
        }
      }
    }

    // 3. Busca direta na árvore oficial em português (/pt/folders/245) e fallback /pt/search
    try {
      final folderResp = await _fetchEgwHttp(
        _officialPtFolderUrl,
        timeout: const Duration(seconds: 10),
      );
      if (folderResp != null && folderResp.body.isNotEmpty && bookTitle.isNotEmpty) {
        final normTarget = _normalizeTitleForMatch(bookTitle);
        final linkMatches = RegExp(
          r"""<a\b[^>]*href=["'](?:https?://m\.egwwritings\.org)?/pt/book/(\d+)(?:/toc)?[^"']*["'][^>]*>(.*?)</a>""",
          caseSensitive: false,
          dotAll: true,
        ).allMatches(folderResp.body);

        for (final m in linkMatches) {
          final candidateId = m.group(1) ?? '';
          final candidateTitle = _normalizeTitleForMatch(_cleanHtmlText(m.group(2) ?? ''));
          if (candidateId.isNotEmpty &&
              candidateTitle.isNotEmpty &&
              (candidateTitle == normTarget ||
                  (normTarget.length >= 8 && candidateTitle.contains(normTarget)))) {
            await _persistResolvedBookId(bookId, candidateId);
            return candidateId;
          }
        }
      }

      final queryUrl =
          'https://m.egwwritings.org/pt/search?q=${Uri.encodeComponent(bookTitle)}';
      final resp = await _fetchEgwHttp(queryUrl, timeout: const Duration(seconds: 8));
      if (resp != null) {
        final resolvedId = extractNumericBookIdFromHtml(resp.body);
        if (resolvedId != null && resolvedId.isNotEmpty) {
          await _persistResolvedBookId(bookId, resolvedId);
          return resolvedId;
        }
      }
    } catch (e) {
      debugPrint('[EgwService] Falha ao resolver ID numérico online para $bookId ($bookTitle): $e');
    }
    return null;
  }

  Future<void> _persistResolvedBookId(String bookId, String resolvedId) async {
    try {
      final coverUrl = 'https://media4.egwwritings.org/covers/${resolvedId}_r.jpg';
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        UPDATE $_booksTable 
        SET resolved_id = ?, cover_url = ?, updated_at = ? 
        WHERE id = ?;
      ''', [resolvedId, coverUrl, DateTime.now().millisecondsSinceEpoch, bookId]);
    } catch (e) {
      debugPrint('[EgwService] Erro ao persistir resolved_id de $bookId: $e');
    }
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
          final existingResolved = row['resolved_id']?.toString();
          final fallbackPreResolved = preResolvedNumericIds[id];
          if ((existingResolved == null || existingResolved.isEmpty) &&
              fallbackPreResolved != null) {
            row['resolved_id'] = fallbackPreResolved;
            row['cover_url'] ??=
                'https://media4.egwwritings.org/covers/${fallbackPreResolved}_r.jpg';
          }
          books.add(EgwBook.fromMap(row, downloaded: downloadedCount));
        } else {
          final initialResolved = preResolvedNumericIds[id];
          final initialCover = initialResolved != null
              ? 'https://media4.egwwritings.org/covers/${initialResolved}_r.jpg'
              : null;
          // Insere catálogo padrão inicial
          final book = EgwBook(
            id: id,
            title: item['title']!,
            abbreviation: item['abbr']!,
            description: item['desc']!,
            coverUrl: initialCover,
            resolvedId: initialResolved,
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
        : (preResolvedNumericIds[bookId] ?? bookId);

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

    // 3. Tenta sumário via pacote R2 quando disponível (rápido e livre de CORS no Web)
    final r2Package = await _tryFetchR2BookJson(bookId, effectiveId);
    if (r2Package != null) {
      await _persistR2PackageChapters(bookId, r2Package);
      final rawToc = r2Package['toc'];
      if (rawToc is List && rawToc.isNotEmpty) {
        final headers = rawToc
            .whereType<Map>()
            .map(
              (m) => EgwChapterHeader(
                bookId: bookId,
                chapterId: (m['chapterId'] ?? '').toString(),
                chapterIndex: (m['chapterIndex'] as int?) ?? 0,
                title: (m['title'] ?? '').toString(),
              ),
            )
            .where((h) => h.chapterId.isNotEmpty)
            .toList();
        if (headers.isNotEmpty) {
          return headers;
        }
      }
    }

    // 4. Busca online do TOC oficial de m.egwwritings.org
    try {
      final primaryUrl = 'https://m.egwwritings.org/pt/book/$effectiveId/toc';
      var resp = await _fetchEgwHttp(primaryUrl, timeout: const Duration(seconds: 10));
      List<EgwChapterHeader> headers = resp != null
          ? parseTocHtml(effectiveId, resp.body, catalogBookId: bookId)
          : [];

      if (headers.isEmpty) {
        resp = await _fetchEgwHttp(
          'https://m.egwwritings.org/pt/book/$effectiveId',
          timeout: const Duration(seconds: 10),
        );
        if (resp != null) {
          headers = parseTocHtml(effectiveId, resp.body, catalogBookId: bookId);
        }
      }

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
    String effectiveId = preResolvedNumericIds[bookId] ?? bookId;
    if (!RegExp(r'^\d+$').hasMatch(effectiveId)) {
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

    // 2. Tenta carregar do pacote pré-empacotado no Cloudflare R2 (livre de CORS no Web)
    final r2Package = await _tryFetchR2BookJson(bookId, effectiveId);
    if (r2Package != null) {
      final chapters = await _persistR2PackageChapters(bookId, r2Package);
      for (final chap in chapters) {
        if (chap.chapterId == chapterId) {
          return chap;
        }
      }
    }

    // 3. Busca online de m.egwwritings.org (com cadeia multi-proxy CORS no Web)
    try {
      final remotePath = '$effectiveId.$chapterId';
      final url = 'https://m.egwwritings.org/pt/book/$remotePath';
      final resp = await _fetchEgwHttp(url, timeout: const Duration(seconds: 12));

      if (resp != null && resp.statusCode == 200) {
        final chapter = parseChapterHtml(
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

  /// Persiste em transação única os capítulos de um pacote R2 para [bookId].
  Future<List<EgwChapter>> _persistR2PackageChapters(
    String bookId,
    Map<String, dynamic> r2Package, {
    void Function(int current, int total)? onProgress,
  }) async {
    final parsedChapters = parseR2BookPackageMap(r2Package, localBookId: bookId);
    if (parsedChapters.isEmpty) return const [];

    final expectedTotal = (r2Package['total_chapters'] as int?) ?? parsedChapters.length;
    final total = parsedChapters.length;
    final isComplete = evaluateDownloadCompleteness(
      cachedChapterCount: total,
      expectedTotalChapters: expectedTotal,
      flaggedDownloaded: true,
    );

    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final now = DateTime.now().millisecondsSinceEpoch;
      db.execute('BEGIN TRANSACTION;');
      try {
        for (int i = 0; i < total; i++) {
          final chap = parsedChapters[i];
          db.execute('''
            INSERT OR REPLACE INTO $_chaptersTable (
              id, book_id, chapter_id, chapter_index, title, content_json, cached_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?);
          ''', [
            chap.id,
            chap.bookId,
            chap.chapterId,
            chap.chapterIndex,
            chap.title,
            chap.toJson(),
            now,
          ]);
          if (i % 10 == 0 || i == total - 1) {
            onProgress?.call(i + 1, total);
          }
        }
        db.execute('''
          UPDATE $_booksTable 
          SET is_downloaded = ?, total_chapters = ?, updated_at = ? 
          WHERE id = ?;
        ''', [isComplete ? 1 : 0, expectedTotal > 0 ? expectedTotal : total, now, bookId]);
        db.execute('COMMIT;');
      } catch (e) {
        try {
          db.execute('ROLLBACK;');
        } catch (_) {}
        debugPrint('[EgwService] Erro ao persistir pacote R2 de $bookId: $e');
      }
    } catch (e) {
      debugPrint('[EgwService] Banco indisponível ao persistir pacote R2 de $bookId: $e');
    }

    return parsedChapters;
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

  /// Interpreta um pacote JSON pré-empacotado (proveniente do Cloudflare R2) remapeando
  /// os capítulos para a chave local [localBookId] do catálogo do aplicativo.
  @visibleForTesting
  static List<EgwChapter> parseR2BookPackageMap(
    Map<String, dynamic> packageMap, {
    required String localBookId,
  }) {
    final rawChapters = packageMap['chapters'] as List? ?? [];
    final chapters = <EgwChapter>[];
    for (int i = 0; i < rawChapters.length; i++) {
      final raw = rawChapters[i];
      if (raw is! Map) continue;
      final chapter = EgwChapter.fromMap(Map<String, dynamic>.from(raw));
      if (chapter.chapterId.isEmpty || chapter.paragraphs.isEmpty) continue;
      chapters.add(
        EgwChapter(
          id: '$localBookId.${chapter.chapterId}',
          bookId: localBookId,
          chapterId: chapter.chapterId,
          chapterIndex: chapter.chapterIndex > 0 ? chapter.chapterIndex : (i + 1),
          title: chapter.title,
          paragraphs: chapter.paragraphs,
        ),
      );
    }
    return chapters;
  }

  /// Tenta baixar o pacote `.json.gz` pronto do livro no Cloudflare R2.
  Future<Map<String, dynamic>?> _tryFetchR2BookJson(
    String bookId,
    String effectiveNumericId,
  ) async {
    final candidateUrls = <String>[];
    final manifest = await _fetchR2Manifest();
    if (manifest != null && manifest['books'] is Map) {
      final bookEntry = (manifest['books'] as Map)[effectiveNumericId];
      if (bookEntry is Map && bookEntry['package_path'] != null) {
        final pkgPath = bookEntry['package_path'].toString().replaceFirst(RegExp(r'^/+'), '');
        if (pkgPath.isNotEmpty) {
          candidateUrls.add('${AppConfig.r2AudioBaseUrl}/$pkgPath');
        }
      }
    }

    if (RegExp(r'^\d+$').hasMatch(effectiveNumericId)) {
      final stdUrl = '${AppConfig.r2AudioBaseUrl}/egw/books/$effectiveNumericId.json.gz';
      if (!candidateUrls.contains(stdUrl)) candidateUrls.add(stdUrl);
    }
    if (bookId != effectiveNumericId) {
      final slugUrl = '${AppConfig.r2AudioBaseUrl}/egw/books/$bookId.json.gz';
      if (!candidateUrls.contains(slugUrl)) candidateUrls.add(slugUrl);
    }

    for (final url in candidateUrls) {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final bytes = resp.bodyBytes;
          final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
          final rawBytes = isGzip
              ? await decompressGzip(Uint8List.fromList(bytes))
              : bytes;
          final decoded = json.decode(utf8.decode(rawBytes));
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        }
      } catch (e) {
        debugPrint('[EgwService] Pacote R2 indisponível em $url: $e');
      }
    }
    return null;
  }

  /// Baixa todos os capítulos do livro [bookId] em lote para visualização offline.
  ///
  /// Prioriza o download em arquivo único compactado `.json.gz` do Cloudflare R2
  /// e utiliza o scraping em lotes paralelos do portal `m.egwwritings.org` como
  /// fallback quando o livro ainda não estiver espelhado no bucket.
  Future<void> downloadBook(
    String bookId, {
    void Function(int current, int total)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    await _ensureTablesCreated();

    final db = await DatabaseManager().getDatabase('hinario.db');

    // Tenta resolver o ID numérico e baixar pacote instantâneo do Cloudflare R2 primeiro.
    String effectiveNumericId = preResolvedNumericIds[bookId] ?? bookId;
    if (!RegExp(r'^\d+$').hasMatch(effectiveNumericId)) {
      String title = bookId;
      try {
        final rows = db.select(
          'SELECT title, resolved_id FROM $_booksTable WHERE id = ? LIMIT 1;',
          [bookId],
        );
        if (rows.isNotEmpty) {
          final res = rows.first['resolved_id']?.toString();
          if (res != null && RegExp(r'^\d+$').hasMatch(res)) {
            effectiveNumericId = res;
          }
          final dbTitle = rows.first['title']?.toString() ?? '';
          if (dbTitle.isNotEmpty) title = dbTitle;
        }
      } catch (_) {}

      if (!RegExp(r'^\d+$').hasMatch(effectiveNumericId)) {
        final resolved = await _resolveNumericBookIdOnline(bookId, title);
        if (resolved != null) effectiveNumericId = resolved;
      }
    }

    if (shouldCancel?.call() == true) return;

    final r2Package = await _tryFetchR2BookJson(bookId, effectiveNumericId);
    if (r2Package != null) {
      final parsedChapters = await _persistR2PackageChapters(
        bookId,
        r2Package,
        onProgress: onProgress,
      );
      final expectedTotal = (r2Package['total_chapters'] as int?) ?? parsedChapters.length;
      if (parsedChapters.isNotEmpty &&
          evaluateDownloadCompleteness(
            cachedChapterCount: parsedChapters.length,
            expectedTotalChapters: expectedTotal,
            flaggedDownloaded: true,
          )) {
        return;
      }
    }

    // Fallback: scraping direto capítulo a capítulo em lotes paralelos controlados.
    final toc = await getTableOfContents(bookId, forceRefresh: true);
    if (toc.isEmpty) {
      throw StateError(
        'Não foi possível localizar o sumário desta obra no acervo EGW.',
      );
    }

    final total = toc.length;
    int current = 0;

    db.execute('''
      UPDATE $_booksTable 
      SET total_chapters = ?, updated_at = ? 
      WHERE id = ?;
    ''', [total, DateTime.now().millisecondsSinceEpoch, bookId]);

    // Aproveita capítulos já baixados anteriormente caso seja uma retomada.
    final alreadyCachedIds = <String>{};
    try {
      final cachedRows = db.select(
        'SELECT chapter_id FROM $_chaptersTable WHERE book_id = ? AND LENGTH(TRIM(content_json)) > 0;',
        [bookId],
      );
      for (final row in cachedRows) {
        final cId = (row['chapter_id'] ?? '').toString();
        if (cId.isNotEmpty) alreadyCachedIds.add(cId);
      }
    } catch (_) {}

    final pendingHeaders = <EgwChapterHeader>[];
    for (final header in toc) {
      if (alreadyCachedIds.contains(header.chapterId)) {
        current++;
      } else {
        pendingHeaders.add(header);
      }
    }
    if (current > 0) {
      onProgress?.call(current, total);
    }

    const batchSize = 4;
    for (int i = 0; i < pendingHeaders.length; i += batchSize) {
      if (shouldCancel?.call() == true) {
        debugPrint('[EgwService] Download cancelado pelo usuário.');
        return;
      }
      final chunk = pendingHeaders.sublist(
        i,
        (i + batchSize > pendingHeaders.length) ? pendingHeaders.length : i + batchSize,
      );
      await Future.wait(
        chunk.map(
          (header) => getChapter(
            bookId,
            header.chapterId,
            chapterIndex: header.chapterIndex,
            fallbackTitle: header.title,
          ),
        ),
      );
      current += chunk.length;
      onProgress?.call(current > total ? total : current, total);
      await Future.delayed(const Duration(milliseconds: 90));
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

  /// Extrai o sumário HTML (`<a href="/pt/book/<id>.<chapterId>">`) independente da ordem de atributos.
  @visibleForTesting
  static List<EgwChapterHeader> parseTocHtml(
    String effectiveBookId,
    String html, {
    String? catalogBookId,
  }) {
    final List<EgwChapterHeader> list = [];
    final escapedId = RegExp.escape(effectiveBookId);
    final finalBookId = catalogBookId ?? effectiveBookId;
    final seenChapterIds = <String>{};

    // Estratégia robusta: qualquer link para `/pt/book/<id>.<chapterId>` (com ou sem `<li id="l...">`).
    final linkRegex = RegExp(
      '<a\\b[^>]*href=["\'](?:https?://m\\.egwwritings\\.org)?/pt/book/$escapedId\\.(\\d+(?:\\.\\d+)?)["\'][^>]*>(.*?)<\\/a>',
      caseSensitive: false,
      dotAll: true,
    );

    int index = 1;
    for (final match in linkRegex.allMatches(html)) {
      final chapterId = match.group(1) ?? '';
      final rawTitle = match.group(2) ?? '';
      final cleanTitle = _cleanHtmlText(rawTitle);
      final lower = cleanTitle.toLowerCase();

      if (chapterId.isNotEmpty &&
          cleanTitle.isNotEmpty &&
          !seenChapterIds.contains(chapterId) &&
          lower != 'ler' &&
          lower != 'read' &&
          lower != 'início' &&
          lower != 'inicio' &&
          lower != 'sumário' &&
          lower != 'sumario') {
        seenChapterIds.add(chapterId);
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

  static String _extractAttribute(String attrs, String attrName) {
    final regex = RegExp(
      '\\b${RegExp.escape(attrName)}\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\'|([^\\s>]+))',
      caseSensitive: false,
    );
    final match = regex.firstMatch(attrs);
    if (match == null) return '';
    return _cleanHtmlText(
      match.group(1) ?? match.group(2) ?? match.group(3) ?? '',
    );
  }

  /// Extrai título e parágrafos de uma página HTML do EGW independente da ordem dos atributos.
  @visibleForTesting
  static EgwChapter? parseChapterHtml({
    required String bookId,
    required String chapterId,
    required int chapterIndex,
    required String htmlBody,
    String? fallbackTitle,
  }) {
    // 1. Extração do Título
    String title = fallbackTitle ?? 'Capítulo $chapterIndex';
    final headerMatch = RegExp(
      r'<h[1-3]\b[^>]*\begw_content_wrapper\b[^>]*>(.*?)</h[1-3]>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(htmlBody);

    if (headerMatch != null) {
      final headerInner = headerMatch.group(1) ?? '';
      final spanMatch = RegExp(
        r'<span\b[^>]*\begw_content\b[^>]*>(.*?)</span>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(headerInner);
      final extracted = _cleanHtmlText(spanMatch?.group(1) ?? headerInner);
      if (extracted.isNotEmpty) {
        title = extracted;
      }
    }

    // 2. Extração dos Parágrafos (independente da ordem dos atributos ou tag p/div/blockquote/h4)
    final List<EgwParagraph> paragraphs = [];
    final blockRegex = RegExp(
      r'<(p|div|blockquote|h[4-6])\b([^>]*)>(.*?)</\1>',
      dotAll: true,
      caseSensitive: false,
    );
    int autoId = 1;

    for (final m in blockRegex.allMatches(htmlBody)) {
      final attrs = m.group(2) ?? '';
      if (!attrs.contains('egw_content_wrapper') && !attrs.contains('data-refcode')) {
        continue;
      }
      final inner = m.group(3) ?? '';
      final pId = _extractAttribute(attrs, 'id');
      final effectiveParaId = pId.isNotEmpty ? pId : '${chapterId}_${autoId++}';
      final refcode = _extractAttribute(attrs, 'data-refcode');

      final contentSpanMatch = RegExp(
        r'<span\b[^>]*\begw_content\b[^>]*>(.*?)</span>',
        dotAll: true,
        caseSensitive: false,
      ).firstMatch(inner);

      final rawContent = contentSpanMatch != null ? (contentSpanMatch.group(1) ?? '') : inner;
      final cleanText = _cleanHtmlText(rawContent);

      if (cleanText.isNotEmpty) {
        paragraphs.add(
          EgwParagraph(
            id: effectiveParaId,
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

    var clean = raw
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ')
        .replaceAll(
          RegExp(r"""<sup[^>]*class=["'][^"']*footnote[^"']*["'][^>]*>.*?</sup>""", caseSensitive: false, dotAll: true),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    clean = clean
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
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

    // Decodifica entidades numéricas decimais comuns (ex.: &#8220;)
    clean = clean.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return m.group(0) ?? '';
    });

    // Converte múltiplos espaços em um só e faz trim
    return clean.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
