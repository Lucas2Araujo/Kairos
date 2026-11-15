#!/usr/bin/env python3
"""
generate_pericopes_and_commentaries.py
--------------------------------------
Gera e atualiza de forma determinística os bancos SQLite:
- assets/pericopes.sqlite (66 livros canônicos + subtítulos internos + Apócrifos 67..73 + 1 Enoque 74)
- assets/commentaries.sqlite (autores em PT-BR: Matthew Henry, Notas EGW / Comentário Adventista e Jamieson-Fausset-Brown)

Ambos os bancos são finalizados com `PRAGMA journal_mode=DELETE; VACUUM;` para
compatibilidade integral entre Android (sqflite/FFI) e Web (sql.js / IndexedDB).
"""

import json
import shutil
import sqlite3
from pathlib import Path
from typing import Dict, List, Tuple


# Subtítulos internos (verse > 1) e complementos estratégicos
INTERNAL_PERICOPES: List[Tuple[int, int, int, str]] = [
    (1, 1, 26, "A Criação do Homem à Imagem de Deus"),
    (1, 2, 1, "O Descanso do Sétimo Dia e o Sábado"),
    (1, 2, 8, "O Jardim do Éden"),
    (1, 3, 15, "A Promessa do Redentor (Protoevangelho)"),
    (2, 20, 1, "Os Dez Mandamentos"),
    (2, 20, 8, "O Mandamento do Sábado"),
    (19, 23, 4, "A Segurança no Vale da Sombra"),
    (19, 91, 9, "Proteção Angelical para os Fiéis"),
    (23, 53, 4, "O Servo Sofredor Carrega Nossas Dores"),
    (27, 2, 44, "O Reino Eterno de Deus"),
    (27, 7, 9, "O Julgamento Diante do Ancião de Dias"),
    (27, 7, 13, "O Filho do Homem Recebe o Reino"),
    (40, 5, 1, "As Bem-Aventuranças"),
    (40, 5, 13, "O Sal da Terra e a Luz do Mundo"),
    (40, 5, 17, "Jesus e a Permanência da Lei"),
    (40, 6, 9, "A Oração do Pai-Nosso"),
    (40, 6, 25, "A Confiança no Cuidado do Pai"),
    (40, 24, 3, "Os Sinais da Volta de Cristo"),
    (40, 28, 18, "A Grande Comissão"),
    (43, 1, 1, "O Verbo Eterno Feito Carne"),
    (43, 1, 29, "O Cordeiro de Deus que Tira o Pecado"),
    (43, 3, 1, "O Diálogo com Nicodemos"),
    (43, 3, 16, "O Amor Incondicional de Deus"),
    (43, 14, 1, "A Promessa das Moradas Celestiais"),
    (43, 14, 15, "A Promessa do Espírito Consolador"),
    (45, 8, 1, "Vida no Espírito sem Condenação"),
    (45, 8, 28, "Todas as Coisas Cooperam para o Bem"),
    (45, 8, 31, "Mais que Vencedores em Cristo"),
    (46, 13, 1, "A Excelência Suprema do Amor"),
    (49, 2, 8, "Salvos pela Graça Mediante a Fé"),
    (49, 6, 10, "A Armadura Completa de Deus"),
    (58, 11, 1, "A Natureza e os Heróis da Fé"),
    (66, 14, 6, "A Primeira Mensagem Angélica: O Evangelho Eterno"),
    (66, 14, 8, "A Segunda Mensagem Angélica"),
    (66, 14, 9, "A Terceira Mensagem Angélica e a Paciência dos Santos"),
    (66, 21, 1, "Um Novo Céu e uma Nova Terra"),
    (66, 21, 3, "Deus Habitará com os Seus e Enxugará Toda Lágrima"),
]

# Capítulos e títulos temáticos para Deuterocanônicos (67..73) e 1 Enoque (74)
APOCRYPHA_AND_ENOCH_BOOKS: Dict[int, Tuple[str, int, Dict[int, str]]] = {
    67: (
        "Tobias",
        14,
        {
            1: "A Piedade e Exílio de Tobit em Nínive",
            2: "As Obras de Misericórdia e a Cegueira de Tobit",
            3: "As Orações de Tobit e de Sara",
            4: "Os Conselhos Paternos de Tobit a Tobias",
            5: "O Anjo Rafael Como Guia na Jornada",
            6: "A Viagem ao Tigre e o Peixe Prodigioso",
            7: "A Chegada à Casa de Raguel e o Casamento",
            8: "A Oração dos Noivos e a Libertação",
            9: "O Resgate do Depósito em Ragés",
            10: "A Espera dos Pais e a Partida dos Recém-Casados",
            11: "O Retorno e a Cura da Cegueira de Tobit",
            12: "A Revelação do Anjo Rafael e o Louvor",
            13: "O Cântico de Ação de Graças de Tobit",
            14: "As Últimas Recomendações e a Morte em Paz",
        },
    ),
    68: (
        "Judite",
        16,
        {
            1: "A Campanha Militar de Nabucodonosor",
            2: "A Expedição de Holofernes Contra o Ocidente",
            3: "A Submissão das Nações ao Exército Assírio",
            4: "A Preparação e Súplica de Israel em Betúlia",
            5: "O Discurso de Aquior Sobre a História de Israel",
            6: "A Ira de Holofernes e a Acolhida de Aquior",
            7: "O Cerco de Betúlia e a Falta de Água",
            8: "A Fé Corajosa de Judite Diante dos Anciãos",
            9: "A Oração Fervorosa de Judite por Livramento",
            10: "A Saída de Judite ao Acampamento Inimigo",
            11: "O Diálogo de Judite com Holofernes",
            12: "Os Dias no Acampamento e o Banquete",
            13: "A Vitória de Judite e o Retorno a Betúlia",
            14: "A Conversão de Aquior e a Estratégia de Ataque",
            15: "A Derrota dos Assírios e a Celebração em Jerusalém",
            16: "O Hino Triunfal de Judite ao Senhor",
        },
    ),
    69: (
        "Sabedoria",
        19,
        {
            1: "A Retidão do Coração e a Busca da Sabedoria",
            2: "Os Raciocínios dos Ímpios Contra o Justo",
            3: "A Esperança Imortal das Almas dos Justos",
            4: "A Virtude Mais Valiosa que Longa Idade",
            5: "O Juízo Final e a Recompensa dos Fiéis",
            6: "Exortação aos Governantes a Buscar a Sabedoria",
            7: "A Origem e os Atributos da Sabedoria Divina",
            8: "Os Frutos e o Valor Inestimável da Sabedoria",
            9: "A Oração de Salomão Pedindo Sabedoria",
            10: "A Sabedoria Guiando os Patriarcas e Moisés",
            11: "A Sabedoria no Êxodo e a Misericórdia Divina",
            12: "A Paciência e a Justiça Soberana de Deus",
            13: "A Insensatez da Idolatria Diante da Criação",
            14: "A Origem dos Ídolos e Suas Consequências",
            15: "A Fidelidade de Israel em Contraste aos Ídolos",
            16: "A Providência Divina no Deserto: O Maná",
            17: "As Trevas no Egito e a Luz para o Povo",
            18: "A Noite da Libertação Pascal",
            19: "A Travessia do Mar Vermelho e o Cântico Final",
        },
    ),
    70: (
        "Eclesiástico",
        51,
        {
            1: "A Origem Divina da Sabedoria e o Temor do Senhor",
            2: "A Perseverança na Provação e Confiança em Deus",
            3: "A Honra aos Pais e a Humildade Verdadeira",
            4: "A Compaixão pelos Pobres e a Coragem pela Verdade",
            5: "A Prudência no Falar e Contra a Presunção",
            6: "A Verdadeira Amizade e o Jugo da Sabedoria",
            7: "Deveres Morais, Familiares e Religiosos",
            8: "A Prudência no Convívio com os Outros",
            9: "Conselhos Sobre a Família e Companhias",
            10: "A Humildade dos Governantes e o Orgulho",
            11: "Não Julgar Pelas Aparências e Confiar em Deus",
            14: "A Felicidade do Justo e a Brevidade da Vida",
            15: "A Liberdade Humana e a Escolha do Bem",
            17: "A Criação do Homem e a Grandeza da Misericórdia",
            24: "O Elogio da Sabedoria Habitando em Sião",
            38: "A Honra ao Médico e o Valor do Trabalho",
            42: "A Glória de Deus Manifestada na Natureza",
            43: "A Majestade dos Astros e das Obras da Criação",
            44: "Elogio dos Antepassados Fiéis na História",
            50: "O Sumo Sacerdote Simão e a Bênção Final",
            51: "Oração de Agradecimento e Convite à Sabedoria",
        },
    ),
    71: (
        "Baruc",
        6,
        {
            1: "A Leitura do Livro na Babilônia e a Oração Penitencial",
            2: "Confissão dos Pecados e Súplica pela Promessa",
            3: "A Oração pela Restauração e a Fonte da Sabedoria",
            4: "O Retorno aos Mandamentos e o Consolo de Sião",
            5: "A Alegria da Jerusalém Restaurada",
            6: "A Carta de Jeremias Contra os Ídolos",
        },
    ),
    72: (
        "1 Macabeus",
        16,
        {
            1: "A Conquista de Alexandre e a Profanação do Templo",
            2: "O Zelo de Matatias e o Início da Resistência",
            3: "As Primeiras Vitórias de Judas Macabeu",
            4: "A Purificação e Rededicação do Templo (Hanucá)",
            5: "As Campanhas de Libertação nas Regiões Vizinhas",
            6: "A Morte de Antíoco IV e a Batalha de Bet-Zur",
            7: "As Vitórias Sobre Báquides e Nicanor",
            8: "A Aliança Diplomática com Roma",
            9: "A Morte Heroica de Judas e a Liderança de Jônatas",
            10: "A Ascensão Política de Jônatas em Israel",
            11: "As Alianças e Batalhas de Jônatas",
            12: "A Renovação dos Tratados e a Prisão de Jônatas",
            13: "A Liderança de Simão e a Independência da Judeia",
            14: "A Paz e Prosperidade sob o Governo de Simão",
            15: "A Carta de Roma em Favor dos Judeus",
            16: "O Governo de João Hircano e o Desfecho",
        },
    ),
    73: (
        "2 Macabeus",
        15,
        {
            1: "Cartas aos Judeus do Egito Sobre a Dedicação",
            2: "O Fogo Sagrado e o Propósito da Obra Histórica",
            3: "A Proteção Milagrosa do Tesouro do Templo",
            4: "As Intrigas pelo Sumo Sacerdócio em Jerusalém",
            5: "O Saque do Templo por Antíoco Epífanes",
            6: "O Martírio Exemplar do Ancião Eleazar",
            7: "O Testemunho da Mãe e dos Sete Irmãos Mártires",
            8: "A Reorganização do Exército de Judas Macabeu",
            9: "O Fim Trágico de Antíoco Epífanes",
            10: "A Purificação do Santuário e Novas Vitórias",
            11: "A Vitória em Bet-Zur e os Tratados de Paz",
            12: "As Campanhas de Judas e a Oração pelos Caídos",
            13: "A Defesa da Cidade Contra Antíoco V",
            14: "A Traição de Alcimo e a Ameaça de Nicanor",
            15: "A Visão de Judas e o Triunfo Sobre Nicanor",
        },
    ),
    74: (
        "1 Enoque",
        108,
        {
            1: "A Bênção de Enoque e a Vinda do Santo Juiz",
            2: "A Ordem Imutável dos Céus e das Estações",
            6: "A Queda dos Vigilantes no Monte Hermom",
            9: "A Intercessão dos Arcanjos Diante do Altíssimo",
            10: "O Decreto do Dilúvio e a Restauração da Terra",
            14: "A Visão do Trono Celestial e do Santuário de Fogo",
            17: "As Viagens Cósmicas e os Tesouros da Luz",
            22: "Os Lugares de Reserva das Almas Até o Juízo",
            25: "A Árvore da Vida e o Monte do Senhor",
            37: "Introdução ao Livro das Parábolas",
            46: "A Visão do Ancião de Dias e do Filho do Homem",
            48: "A Fonte da Justiça e o Nome do Messias",
            51: "A Ressurreição e a Transformação dos Eleitos",
            62: "O Triunfo Final do Eleito Sobre os Reis da Terra",
            69: "O Juramento Secreto da Criação",
            71: "A Ascensão de Enoque ao Céu dos Céus",
            72: "O Livro das Luminárias Celestiais: O Sol",
            83: "O Livro dos Sonhos: A Visão do Dilúvio",
            85: "O Apocalipse dos Animais: De Adão à Redenção",
            91: "A Epístola de Enoque e o Apocalipse das Semanas",
            104: "A Promessa de Alegria e Luz para os Justos",
            108: "O Livro Final de Consolo para a Geração Fiel",
        },
    ),
}


AUTHORS: List[Tuple[str, str, str, str]] = [
    (
        "matthew-henry",
        "Matthew Henry (PT-BR)",
        "M. Henry",
        "Comentário Devocional e Expositivo clássico das Escrituras em português (Domínio Público).",
    ),
    (
        "notas-egw",
        "Notas EGW / Comentário Adventista",
        "Notas EGW",
        "Sínteses temáticas inspiradas na hermenêutica bíblica adventista e no Grande Conflito.",
    ),
    (
        "jamieson-fausset-brown",
        "Jamieson-Fausset-Brown (PT-BR)",
        "JFB",
        "Comentário Crítico e Explicativo verso a verso adaptado para o estudo bíblico em português.",
    ),
]


# (author_slug, book_id, chapter, verse_start, verse_end, title, content)
COMMENTARIES: List[Tuple[str, int, int, int, int, str, str]] = [
    # Gênesis 1:1-3 (todos os 3 autores para facilitar testes e uso real)
    (
        "matthew-henry",
        1,
        1,
        1,
        3,
        "A Criação pelo Verbo Eterno",
        "No princípio Deus criou os céus e a terra a partir do nada, demonstrando soberania absoluta sobre o tempo, o espaço e a matéria. Onde havia vazio e trevas, o Espírito de Deus pairava como penhor de vida, e a Palavra criadora trouxe ordem, beleza e luz instantânea.",
    ),
    (
        "notas-egw",
        1,
        1,
        1,
        3,
        "Semanas Literais e Soberania Criadora",
        "O relato de Gênesis estabelece o fundamento de toda a teologia bíblica: o Deus Criador não dependeu de matéria preexistente, mas chamou o universo à existência pelo poder de Sua Palavra. A luz do primeiro dia prepara o cenário para a semana literal que culmina no memorial do sábado.",
    ),
    (
        "jamieson-fausset-brown",
        1,
        1,
        1,
        3,
        "Ex Nihilo e a Ação Trinitária",
        "O verbo hebraico 'bara' empregado no versículo 1 denota criação originária exclusiva de Deus. A presença conjunta de Deus (Elohim), do Espírito (Ruach) e da Palavra falada antecipa a cooperação plena da Divindade na obra criadora e redentora.",
    ),
    # Gênesis 1:26-27
    (
        "matthew-henry",
        1,
        1,
        26,
        27,
        "A Imagem Divina no Ser Humano",
        "Após preparar a habitação terrestre com perfeição, Deus realiza conselho solene para formar a coroa da criação. Ser feito à imagem de Deus implica capacidade moral, racionalidade, comunhão espiritual e mordomia fiel sobre toda a terra.",
    ),
    (
        "notas-egw",
        1,
        1,
        26,
        28,
        "Dignidade Original e Mordomia",
        "Adão e Eva refletiam tanto na aparência física quanto na pureza de caráter a semelhança do Criador. O domínio confiado à humanidade não é tirania, mas cuidado amoroso da criação sob a autoridade divina.",
    ),
    # Gênesis 2:1-3
    (
        "notas-egw",
        1,
        2,
        1,
        3,
        "O Sábado como Memorial do Éden",
        "Antes mesmo da entrada do pecado, Deus descansou, abençoou e santificou o sétimo dia. Assim como o matrimônio, o sábado é uma instituição edênica perpétua destinada a recordar que pertencemos ao Criador e nele encontramos repouso.",
    ),
    (
        "matthew-henry",
        1,
        2,
        1,
        3,
        "A Santificação do Sétimo Dia",
        "O descanso divino não decorre de fadiga, mas da contemplação satisfeita de uma obra perfeita. Ao separar o sétimo dia como santo, Deus oferece ao ser humano um santuário no tempo para adoração e renovação espiritual.",
    ),
    # Gênesis 3:15
    (
        "matthew-henry",
        1,
        3,
        15,
        15,
        "O Primeiro Anúncio do Evangelho",
        "Ainda no juízo após a queda, brilha a graça soberana. A promessa da semente da mulher aponta diretamente para Cristo, que suportaria o ferimento na cruz para esmagar definitivamente o império do mal.",
    ),
    (
        "notas-egw",
        1,
        3,
        15,
        15,
        "O Início do Grande Conflito",
        "A inimizade colocada por Deus entre a serpente e a mulher não é um sentimento natural humano, mas graça infundida que capacita o pecador a resistir a Satanás. Toda a história da redenção desdobra essa vitória prometida no Calvário.",
    ),
    # Êxodo 20:8-11
    (
        "notas-egw",
        2,
        20,
        8,
        11,
        "O Selo da Lei Moral",
        "No coração do Decálogo repousa o quarto mandamento, único que identifica quem é o Legislador (o Criador dos céus e da terra), Seu título e o território de Seu domínio. O 'Lembra-te' confirma que o sábado já era conhecido antes do Sinai.",
    ),
    (
        "matthew-henry",
        2,
        20,
        8,
        11,
        "Repouso Sagrado para Toda a Casa",
        "Seis dias pertencem ao labor honesto; o sétimo é consagrado ao Senhor. O preceito protege não apenas o chefe da família, mas filhos, servos, estrangeiros e animais, revelando a compaixão social e espiritual de Deus.",
    ),
    # Salmos 23:1-6
    (
        "matthew-henry",
        19,
        23,
        1,
        3,
        "O Cuidado Suficiente do Pastor",
        "Quem tem o Senhor como Pastor nada temerá quanto às provisões essenciais da alma e do corpo. Ele conduz a pastos verdejantes da Palavra e a águas tranquilas da graça, refrigerando o coração cansado.",
    ),
    (
        "notas-egw",
        19,
        23,
        1,
        6,
        "Segurança nas Veredas da Justiça",
        "Mesmo atravessando vales escuros de provação, o crente não caminha sozinho. A vara e o cajado simbolizam proteção e direção amorosa, culminando na certeza de habitar para sempre na casa do Senhor.",
    ),
    (
        "jamieson-fausset-brown",
        19,
        23,
        4,
        6,
        "Da Pastagem ao Banquete Real",
        "A metáfora evolui do pastor no campo (v. 1-4) para o anfitrião generoso no palácio (v. 5-6). A bondade e a misericórdia de Deus não apenas acompanham o peregrino, mas o seguem ativamente todos os dias da vida.",
    ),
    # Salmos 91:1-2
    (
        "matthew-henry",
        19,
        91,
        1,
        2,
        "O Abrigo no Esconderijo do Altíssimo",
        "Habitar no abrigo do Altíssimo não é visita ocasional em momentos de crise, mas comunhão constante de fé. Quem faz do Senhor seu refúgio descansa sob a sombra protetora do Todo-Poderoso.",
    ),
    (
        "notas-egw",
        19,
        91,
        1,
        4,
        "Confiança na Tempestade Final",
        "As promessas do Salmo 91 fortalecem o povo de Deus em tempos de angústia. Sob as asas do Onipotente, a verdade divina torna-se escudo e broquel contra os enganos e temores do último tempo.",
    ),
    # Provérbios 3:5-6
    (
        "matthew-henry",
        20,
        3,
        5,
        6,
        "Entrega Integral da Sabedoria Humana",
        "Confiar no Senhor de todo o coração exige renunciar à autossuficiência do próprio entendimento. Quando reconhecemos a Deus em todos os nossos caminhos — grandes ou cotidianos — Ele endireita nossas veredas.",
    ),
    (
        "jamieson-fausset-brown",
        20,
        3,
        5,
        6,
        "Direção Segura em Cada Decisão",
        "O termo hebraico para 'confiar' expressa apoiar-se com todo o peso. A promessa de veredas aplainadas garante que Deus remove os obstáculos morais e conduz o fiel ao propósito seguro.",
    ),
    # Isaías 53:4-5
    (
        "matthew-henry",
        23,
        53,
        4,
        6,
        "O Sacrifício Vicário do Servo",
        "Sete séculos antes de Belém, Isaías retrata o Calvário com clareza impressionante. Cristo não sofreu por culpa própria, mas levou nossas enfermidades e foi traspassado pelas nossas transgressões para nos conceder paz.",
    ),
    (
        "notas-egw",
        23,
        53,
        4,
        6,
        "O Cordeiro Substituto",
        "Nas pisaduras de Cristo reside a única cura para a lepra do pecado. Todo o sistema de sacrifícios do santuário terrestre convergia para este momento em que o Inocente assumiu a condenação do culpado.",
    ),
    # Daniel 2:44
    (
        "notas-egw",
        27,
        2,
        44,
        44,
        "O Reino da Pedra Não Cortada por Mãos",
        "Após a sucessão dos impérios mundiais — Babilônia, Medo-Pérsia, Grécia, Roma e os reinos divididos da Europa — o próprio Deus estabelecerá um reino eterno e indestrutível na segunda vinda de Cristo.",
    ),
    (
        "jamieson-fausset-brown",
        27,
        2,
        44,
        45,
        "A Soberania da Profecia Histórica",
        "O contraste entre o esplendor decrescente dos metais da estátua e a pedra cortada sem auxílio humano revela que a consumação do reino divino não brota de esforços políticos humanos, mas de intervenção sobrenatural.",
    ),
    # Daniel 7:13-14
    (
        "notas-egw",
        27,
        7,
        13,
        14,
        "O Filho do Homem Diante do Ancião de Dias",
        "Esta cena descreve o juízo investigativo celestial iniciado no santuário celeste antes do retorno glorioso de Cristo à terra. O Filho do Homem recebe o domínio eterno diante das cortes angelicais.",
    ),
    # Mateus 5:3-12
    (
        "matthew-henry",
        40,
        5,
        3,
        12,
        "O Caráter dos Cidadãos do Reino",
        "As Bem-Aventuranças invertem os valores do mundo: Jesus declara felizes os humildes de espírito, os mansos, os que têm fome de justiça e os pacificadores. A verdadeira alegria nasce da graça interior, não de posses externas.",
    ),
    (
        "notas-egw",
        40,
        5,
        3,
        12,
        "A Escada das Virtudes Cristãs",
        "Pobreza de espírito é o primeiro degrau: reconhecer nossa total necessidade de Cristo abre a porta para o arrependimento, a mansidão e o coração puro que contemplará a Deus.",
    ),
    # Mateus 28:18-20
    (
        "matthew-henry",
        40,
        28,
        18,
        20,
        "Autoridade Universal e Presença Perpétua",
        "A missão evangelística apoia-se em duas garantias inabaláveis: toda autoridade pertence ao Cristo ressurreto, e Sua presença real acompanha os discípulos até a consumação dos séculos.",
    ),
    (
        "notas-egw",
        40,
        28,
        18,
        20,
        "O Mandato Missionário da Igreja",
        "Fazer discípulos de todas as nações envolve pregar o evangelho, batizar e ensinar a guardar tudo quanto Jesus ordenou — sem negligenciar nenhum dos mandamentos divinos.",
    ),
    # João 1:1-14
    (
        "matthew-henry",
        43,
        1,
        1,
        3,
        "A Eternidade e Divindade do Verbo",
        "Antes que o mundo existisse, o Verbo já era — eterno como Deus, distinto em pessoa ('estava com Deus') e idêntico em natureza ('era Deus'). Nada veio à existência fora de Sua agência criadora.",
    ),
    (
        "jamieson-fausset-brown",
        43,
        1,
        1,
        14,
        "O Verbo Tabernaculou Entre Nós",
        "No versículo 14, o verbo grego 'eskenosen' literalmente significa 'armou Sua tenda' entre nós, evocando o tabernáculo do deserto onde a glória Shekinah habitava no meio de Israel, agora manifesta plenamente em Jesus.",
    ),
    (
        "notas-egw",
        43,
        1,
        14,
        14,
        "A Encarnação do Filho de Deus",
        "Ao unir a natureza divina à natureza humana, Cristo tornou-se a ponte viva entre o Céu e a terra, revelando o caráter amoroso do Pai em termos que a humanidade caída pudesse compreender.",
    ),
    # João 3:16-17
    (
        "matthew-henry",
        43,
        3,
        16,
        17,
        "A Medida Infinita do Amor Divino",
        "Aqui está o resumo áureo de toda a Escritura: a origem da salvação é o amor do Pai; a dádiva é o Filho Unigênito; o alcance é todo aquele que crê; e o propósito não é condenar, mas conceder vida eterna.",
    ),
    (
        "notas-egw",
        43,
        3,
        16,
        17,
        "O Dom Inefável do Céu",
        "Ao entregar Seu Filho, o Céu derramou todo o seu tesouro numa única dádiva. Esse amor transforma o coração rebelde, tornando a obediência não um fardo legalista, mas resposta grata à graça.",
    ),
    (
        "jamieson-fausset-brown",
        43,
        3,
        16,
        17,
        "O Advérbio 'De Tal Maneira'",
        "O termo grego 'houtos' enfatiza tanto a intensidade quanto o modo singular do amor divino: Deus amou um mundo hostil a ponto de entregar o Seu único Filho para resgatá-lo da perdição.",
    ),
    # Romanos 8:28-39
    (
        "matthew-henry",
        45,
        8,
        28,
        39,
        "A Cadeia Inquebrável da Graça",
        "Embora nem todo evento isolado seja bom em si, a providência do Pai tece todas as circunstâncias para o bem eterno daqueles que O amam. Nada na criação, na vida ou na morte pode romper o amor de Deus em Cristo.",
    ),
    (
        "jamieson-fausset-brown",
        45,
        8,
        31,
        39,
        "O Clímax Triunfal da Epístola",
        "Paulo encerra a primeira grande seção de Romanos com perguntas retóricas invencíveis: se Deus entregou o próprio Filho por nós, certamente nos dará tudo o mais que for necessário até a glória final.",
    ),
    # Efésios 2:8-10
    (
        "matthew-henry",
        49,
        2,
        8,
        10,
        "Graça Como Raiz e Boas Obras Como Fruto",
        "A salvação é inteiramente pela graça mediante a fé — até a própria fé é dom divino, excluindo qualquer vanglória. Somos feitura de Deus, recriados em Cristo justamente para andar em boas obras.",
    ),
    (
        "notas-egw",
        49,
        2,
        8,
        10,
        "Justificação e Santificação em Harmonia",
        "Nenhum mérito humano compra o perdão; recebemos a justiça de Cristo pela fé. Contudo, a fé genuína nunca permanece inerte: ela produz frutos de amor e conformidade à lei de Deus.",
    ),
    # Filipenses 4:6-7
    (
        "matthew-henry",
        50,
        4,
        6,
        7,
        "O Antídoto Contra a Ansiedade",
        "Em vez de ceder à preocupação estéril, o crente leva toda petição a Deus com oração e ações de graças. A resposta imediata nem sempre é a mudança do cenário, mas uma paz sobrenatural que guarda mente e coração como sentinela.",
    ),
    # Hebreus 11:1
    (
        "matthew-henry",
        58,
        11,
        1,
        1,
        "A Substância do Invisível",
        "A fé não é credulidade cega, mas certeza fundamentada na fidelidade de Deus. Ela torna presentes no coração as promessas futuras e permite contemplar o Deus invisível com mais nitidez do que os olhos carnais veem o visível.",
    ),
    (
        "jamieson-fausset-brown",
        58,
        11,
        1,
        2,
        "Fé Como Título de Posse",
        "No grego koiné, 'hypostasis' era usado em documentos jurídicos para designar a escritura de posse garantida. Pela fé, os patriarcas receberam o testemunho divino mesmo antes de ver o cumprimento pleno.",
    ),
    # Apocalipse 14:6-12
    (
        "notas-egw",
        66,
        14,
        6,
        12,
        "A Tríplice Mensagem Angélica",
        "No clímax da história terrestre, Deus envia três mensagens solenes: proclamar o evangelho eterno e adorar o Criador porque chegou a hora do Seu juízo (v. 6-7), denunciar a confusão espiritual de Babilônia (v. 8) e convocar à fidelidade que une os mandamentos de Deus e a fé de Jesus (v. 12).",
    ),
    (
        "matthew-henry",
        66,
        14,
        6,
        7,
        "O Evangelho Eterno a Toda Nação",
        "O anjo voa pelo meio do céu para que nenhuma tribo, língua ou povo fique sem ouvir o chamado ao temor de Deus e à adoração exclusiva do Criador dos céus, da terra, do mar e das fontes das águas.",
    ),
    (
        "jamieson-fausset-brown",
        66,
        14,
        12,
        12,
        "Perseverança dos Santos no Fim",
        "A paciência perseverante dos fiéis nos momentos de provação final se sustenta por dois pilares inseparáveis: a observância leal dos preceitos divinos e a confiança contínua em Jesus Cristo.",
    ),
    # Apocalipse 21:1-4
    (
        "matthew-henry",
        66,
        21,
        1,
        4,
        "A Restauração Definitiva do Universo",
        "O livro das revelações culmina não em destruição, mas em criação renovada. A Nova Jerusalém desce do céu como noiva adornada, e o próprio Deus enxuga dos olhos de Seus filhos cada vestígio de lágrima, dor e morte.",
    ),
    (
        "notas-egw",
        66,
        21,
        1,
        4,
        "O Lar Eterno dos Remidos",
        "O grande conflito terminou; o pecado e os pecadores não existem mais. Todo o universo está purificado, e uma única pulsação de harmonia e alegria vibra através da imensidão eterna na comunhão direta com o Criador.",
    ),
]


def _finalize_sqlite(db_path: Path) -> None:
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute("PRAGMA wal_checkpoint(TRUNCATE);")
    cur.execute("PRAGMA journal_mode=DELETE;")
    cur.execute("VACUUM;")
    conn.commit()
    mode = cur.execute("PRAGMA journal_mode;").fetchone()[0]
    conn.close()
    assert str(mode).lower() == "delete", f"Expected DELETE journal_mode on {db_path}, got {mode}"


def _replicate_to_build_dirs(src_path: Path, filename: str, root: Path) -> None:
    candidates = [
        root / "build" / "unit_test_assets" / "assets" / filename,
        root / "build" / "flutter_assets" / "assets" / filename,
        root / "build" / "web" / "assets" / "assets" / filename,
    ]
    for dest in candidates:
        if dest.parent.exists():
            shutil.copy2(src_path, dest)


def generate_pericopes(root: Path) -> int:
    db_path = root / "assets" / "pericopes.sqlite"
    existing_canonical: Dict[Tuple[int, int, int], str] = {}

    if db_path.exists():
        try:
            old_conn = sqlite3.connect(str(db_path))
            for bid, ch, verse, title in old_conn.execute(
                "SELECT book_id, chapter, verse, title FROM pericope WHERE book_id <= 66"
            ).fetchall():
                existing_canonical[(int(bid), int(ch), int(verse))] = str(title)
            old_conn.close()
        except sqlite3.Error:
            existing_canonical = {}

    # Sobrescreve/complementa com os JSONs curados em scripts/data/
    for json_name in (
        "pericopes_penta_hist.json",
        "pericopes_poet_prof.json",
        "pericopes_nt.json",
    ):
        json_path = root / "scripts" / "data" / json_name
        if json_path.exists():
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
            for key, title in data.items():
                bid_str, ch_str = key.split(":")
                existing_canonical[(int(bid_str), int(ch_str), 1)] = str(title)

    # Garante subtítulos internos
    for bid, ch, verse, title in INTERNAL_PERICOPES:
        existing_canonical[(bid, ch, verse)] = title

    # Gera títulos para Deuterocanônicos (67..73) e 1 Enoque (74)
    for bid, (book_name, total_ch, custom_titles) in APOCRYPHA_AND_ENOCH_BOOKS.items():
        for ch in range(1, total_ch + 1):
            existing_canonical[(bid, ch, 1)] = custom_titles.get(
                ch, f"{book_name} — Capítulo {ch}"
            )

    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE pericope (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            title TEXT NOT NULL
        );
        """
    )
    cur.execute("CREATE INDEX idx_pericope_book_chap ON pericope(book_id, chapter);")

    ordered_rows = [
        (bid, ch, v, existing_canonical[(bid, ch, v)])
        for (bid, ch, v) in sorted(existing_canonical.keys())
    ]
    cur.executemany(
        "INSERT INTO pericope (book_id, chapter, verse, title) VALUES (?, ?, ?, ?)",
        ordered_rows,
    )
    conn.commit()
    total = cur.execute("SELECT COUNT(*) FROM pericope").fetchone()[0]
    conn.close()

    _finalize_sqlite(db_path)
    _replicate_to_build_dirs(db_path, "pericopes.sqlite", root)
    return int(total)


def generate_commentaries(root: Path) -> Tuple[int, int]:
    db_path = root / "assets" / "commentaries.sqlite"
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE authors (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            slug TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            short_name TEXT,
            description TEXT,
            is_public_domain INTEGER NOT NULL DEFAULT 1
        );
        """
    )
    cur.execute(
        """
        CREATE TABLE commentaries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author_id INTEGER NOT NULL REFERENCES authors(id),
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse_start INTEGER NOT NULL,
            verse_end INTEGER NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        """
    )
    cur.execute(
        "CREATE INDEX idx_commentaries_lookup ON commentaries(book_id, chapter, verse_start, verse_end);"
    )

    author_ids: Dict[str, int] = {}
    for slug, name, short_name, desc in AUTHORS:
        cur.execute(
            """
            INSERT INTO authors (slug, name, short_name, description, is_public_domain)
            VALUES (?, ?, ?, ?, 1)
            """,
            (slug, name, short_name, desc),
        )
        author_ids[slug] = int(cur.lastrowid)

    for slug, book_id, chapter, v_start, v_end, title, content in COMMENTARIES:
        cur.execute(
            """
            INSERT INTO commentaries (author_id, book_id, chapter, verse_start, verse_end, title, content)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (author_ids[slug], book_id, chapter, v_start, v_end, title, content),
        )

    conn.commit()
    authors_count = cur.execute("SELECT COUNT(*) FROM authors").fetchone()[0]
    commentaries_count = cur.execute("SELECT COUNT(*) FROM commentaries").fetchone()[0]
    conn.close()

    _finalize_sqlite(db_path)
    _replicate_to_build_dirs(db_path, "commentaries.sqlite", root)
    return int(authors_count), int(commentaries_count)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    pericope_count = generate_pericopes(root)
    authors_count, commentaries_count = generate_commentaries(root)
    print(
        f"OK: pericopes.sqlite={pericope_count} registros; "
        f"commentaries.sqlite={authors_count} autores, {commentaries_count} comentários."
    )


if __name__ == "__main__":
    main()
