import sqlite3
import shutil
from pathlib import Path

# Mapeamento canônico e inspirador para todos os 150 Salmos
PSALMS_PERICOPES: dict[int, str] = {
    1: "O Homem Bem-Aventurado e a Árvore Frutífera",
    2: "O Reinado Triunfante do Ungido do Senhor",
    3: "Oração Matutina de Confiança nas Perseguições",
    4: "Oração Noturna de Paz e Descanso Seguro",
    5: "Súplica pela Proteção e Justiça de Deus pela Manhã",
    6: "Súplica Penitencial e Pedido de Misericórdia",
    7: "O Refúgio na Justiça Divina contra os Caluniadores",
    8: "A Glória Excelsa de Deus na Criação",
    9: "Ação de Graças pela Justiça e Juízo de Deus",
    10: "Clamor pelo Socorro aos Oprimidos e Desamparados",
    11: "A Confiança no Senhor quando os Fundamentos Tremem",
    12: "O Socorro de Deus contra a Falsidade dos Homens",
    13: "Da Aflição e Aparente Esquecimento ao Cântico de Salvação",
    14: "A Loucura da Incredulidade e a Salvação de Sião",
    15: "Quem Habitará no Santo Monte do Senhor?",
    16: "A Herança Eterna e a Esperança da Ressurreição",
    17: "Oração de um Justo por Livramento e Proteção",
    18: "O Cântico de Vitória de Davi: O Senhor é Meu Rochedo",
    19: "Os Céus Proclamam a Glória de Deus e a Lei Perfeita",
    20: "Oração pela Vitória do Rei nas Batalhas",
    21: "Ação de Graças pelas Bênçãos e Conquistas do Rei",
    22: "O Clamor do Servo Sofredor e a Promessa de Louvor",
    23: "O Senhor é o Meu Pastor, Nada Me Faltará",
    24: "O Rei da Glória Entra pelas Portas Eternas",
    25: "Oração por Orientação, Perdão e Proteção",
    26: "Apelo à Integridade Diante do Exame de Deus",
    27: "O Senhor é a Minha Luz e a Minha Salvação",
    28: "Súplica por Resposta e Bênção para o Povo de Deus",
    29: "A Majestosa e Poderosa Voz do Senhor nas Tempestades",
    30: "Ação de Graças pela Restauração: O Choro Dura uma Noite",
    31: "Nas Tuas Mãos Entrego o Meu Espírito: Refúgio na Provação",
    32: "A Bem-Aventurança do Perdão e da Confissão Sincera",
    33: "O Cântico de Louvor ao Criador Soberano",
    34: "O Louvor Contínuo e o Anjo que Acampa ao Redor",
    35: "Oração contra Inimigos Injustos: Pleiteia Minha Causa",
    36: "A Maldade do Ímpio e a Excelência da Graça Divina",
    37: "Confia no Senhor e Pratica o Bem: A Prosperidade dos Mansos",
    38: "Oração Penitencial em Grande Angústia e Fraqueza",
    39: "A Brevidade da Vida Humana e a Esperança no Senhor",
    40: "Esperei com Paciência no Senhor: Obediência e Redenção",
    41: "Bem-Aventurado o que Cuida do Pobre: Consolo na Doença",
    42: "Como a Corça Suspira pelas Correntes das Águas: Sede de Deus",
    43: "Envia a Tua Luz e a Tua Verdade: Esperança em Deus",
    44: "Clamor do Povo em Época de Tribulação Nacional",
    45: "O Cântico Real das Bodas do Rei Ungido",
    46: "Deus é o Nosso Refúgio e Fortaleza",
    47: "O Grande Rei sobre Toda a Terra: Aplaudi com Júbilo",
    48: "A Grandeza de Sião, a Cidade do Nosso Deus",
    49: "A Insuficiência das Riquezas Diante da Morte",
    50: "Deus Julga o Seu Povo: O Verdadeiro Culto do Coração",
    51: "A Súplica Penitencial por um Coração Puro",
    52: "A Futilidade do Homem Malicioso e a Oliveira Verdejante",
    53: "A Insensatez dos que Negam a Deus",
    54: "Oração por Livramento pelo Poder do Nome do Senhor",
    55: "Oração na Traição de um Amigo: Entrega o Teu Fardo ao Senhor",
    56: "Em Deus Ponho a Minha Confiança: As Lágrimas no Teu Odre",
    57: "Refúgio à Sombra das Tuas Asas até Passarem as Calamidades",
    58: "Repreensão aos Juízes Injustos e Apelo à Justiça Divina",
    59: "Oração contra Inimigos Noturnos: Deus é Minha Alta Torre",
    60: "Oração Nacional Após a Derrota: Com Deus Faremos Proezas",
    61: "Leva-me à Rocha que é Mais Alta do que Eu",
    62: "Somente em Deus a Minha Alma Descansa Silenciosa",
    63: "A Tua Graça é Melhor do que a Vida: Sede de Deus no Deserto",
    64: "Proteção contra as Conspirações Secretas e Línguas Venenosas",
    65: "A Generosidade de Deus na Criação e na Abundância da Colheita",
    66: "Aclamai a Deus com Alegria: O Testemunho das Suas Maravilhas",
    67: "Que Todos os Povos Te Louvem: A Bênção para as Nações",
    68: "Levanta-te, ó Deus: O Triunfo e a Carruagem do Senhor",
    69: "Súplica nas Águas Profundas da Humilhação",
    70: "Apressa-te, ó Deus, em Me Socorrer",
    71: "A Oração do Idoso por Sustento e Perseverança",
    72: "O Reino de Paz e Justiça do Messias para Sempre",
    73: "A Crise da Fé Diante da Prosperidade dos Ímpios e a Resolução no Santuário",
    74: "Lamento pela Destruição do Santuário e Clamor pela Aliança",
    75: "Deus é o Juiz Supremo que Abate e Exalta",
    76: "A Majestade Gloriosa do Deus de Jacó em Sião",
    77: "Consolo na Recordação dos Feitos Históricos do Senhor",
    78: "Lições da História de Israel: A Fidelidade de Deus e a Rebeldia do Povo",
    79: "Lamento sobre as Ruínas de Jerusalém e Oração por Compaixão",
    80: "Ouve, ó Pastor de Israel: Restaura a Tua Vinha",
    81: "Cântico de Louvor na Festa e Advertência à Fidelidade",
    82: "Deus Julga os Deuses e Governantes da Terra",
    83: "Oração contra a Conspiração das Nações Inimigas",
    84: "Quão Amáveis são os Teus Tabernáculos: O Anseio pela Casa de Deus",
    85: "Restauração, Misericórdia e Verdade que se Encontram",
    86: "Inclina os Teus Ouvidos: Oração de Humildade e Súplica",
    87: "A Glória de Sião como Mãe de Todos os Povos",
    88: "Clamor das Profundezas da Escuridão e da Dor Solitária",
    89: "A Aliança Eterna com Davi e o Lamento pelo Trono Abalado",
    90: "De Geração em Geração: A Oração de Moisés sobre a Eternidade de Deus",
    91: "O Abrigo Inabalável do Onipotente",
    92: "Cântico para o Dia de Sábado: O Justo Florescerá como a Palmeira",
    93: "O Senhor Reina Revestido de Majestade",
    94: "Deus das Vinganças: Consolo Diante dos Opressores",
    95: "Vinde, Cantemos ao Senhor: Adoração e Alerta contra o Coração Endurecido",
    96: "Cantai ao Senhor um Cântico Novo: A Chegada do Juiz da Terra",
    97: "O Senhor Reina, Regozije-se a Terra: Fogo e Luz para o Justo",
    98: "Cantai com Harpa e Trombetas a Vitória da Salvação",
    99: "O Senhor Reina Tremendo e Santo sobre os Querubins",
    100: "Celebrai com Júbilo ao Senhor, Todas as Terras",
    101: "O Voto de Integridade e Pureza na Casa e no Governo",
    102: "Oração do Aflito: O Senhor Permanece Imutável para Sempre",
    103: "Bendize, ó Minha Alma, ao Senhor e Lembra-te de seus Benefícios",
    104: "A Providência e Sabedoria de Deus Manifestadas na Natureza",
    105: "A Fidelidade do Senhor na Aliança desde Abraão até Canaã",
    106: "A Graça Paciente de Deus Diante das Recaídas de Israel",
    107: "Rendei Graças ao Senhor: O Libertador dos Perdidos, Famintos e Náufragos",
    108: "Firme está o Meu Coração: Triunfo e Louvor ao Deus Altíssimo",
    109: "Oração contra o Adversário Impiedoso e Ingrato",
    110: "Disse o Senhor ao Meu Senhor: O Rei e Sacerdote Eterno",
    111: "Grandes são as Obras do Senhor: O Princípio da Sabedoria",
    112: "A Prosperidade e a Paz do Homem que Teme ao Senhor",
    113: "Do Nascente ao Poente Louvado seja o Nome do Senhor",
    114: "Quando Israel Saiu do Egito: A Terra Tremeu Diante de Deus",
    115: "Não a Nós, Senhor, mas ao Teu Nome dá Glória: A Ilusão dos Ídolos",
    116: "Amo o Senhor porque Ele Ouve a Minha Súplica: O Cálice da Salvação",
    117: "Louvai ao Senhor Todas as Nações: A Fidelidade Eterna",
    118: "A Sua Misericórdia Dura para Sempre: A Pedra que os Construtores Rejeitaram",
    119: "Lâmpada para os Meus Pés é a Tua Palavra",
    120: "Cântico de Romagem: Livramento das Línguas Enganosas",
    121: "Elevo os Meus Olhos para os Montes: De Onde Me Virá o Socorro?",
    122: "Alegrei-me quando Me Disseram: Vamos à Casa do Senhor",
    123: "Como os Olhos dos Servos: Olhos Fixos no Senhor por Misericórdia",
    124: "Se Não Fora o Senhor que Esteve ao Nosso Lado",
    125: "Os que Confiam no Senhor são como o Monte Sião",
    126: "Quando o Senhor Restaurou Sião: Os que Semeiam em Lágrimas Ceifarão com Alegria",
    127: "Se o Senhor Não Edificar a Casa: A Herança dos Filhos",
    128: "A Bem-Aventurança da Família que Teme ao Senhor",
    129: "Muitas Vezes Me Angustiaram desde a Minha Mocidade",
    130: "Das Profundezas Clamo a Ti, Senhor: No Senhor Há Redenção",
    131: "O Coração Humilde e Sereno como Criança Desmamada",
    132: "A Morada de Deus em Sião e a Promessa da Descendência de Davi",
    133: "Oh! Quão Bom e Quão Suave é que os Irmãos Vivam em União",
    134: "Bendizei ao Senhor Vós Todos os Servos no Seu Templo",
    135: "Louvai o Nome do Senhor: Soberano sobre Todas as Nações",
    136: "A Sua Misericórdia Dura para Sempre: O Grande Hino de Gratidão",
    137: "Junto aos Rios da Babilônia: A Saudade de Sião no Cativeiro",
    138: "Render-Te-ei Graças de Todo o Coração: O Senhor Aperfeiçoará o que Me Concerne",
    139: "Senhor, Tu Me Sondas e Me Conheces",
    140: "Livra-me dos Homens Violentos e das Suas Tramas",
    141: "Suba a Minha Oração como Incenso Diante de Ti",
    142: "O Clamor na Caverna: Tu és o Meu Refúgio e a Minha Porção",
    143: "Ouve a Minha Oração: Ensina-me a Fazer a Tua Vontade",
    144: "Bendito seja o Senhor Minha Rocha: O Povo cujo Deus é o Senhor",
    145: "Exaltação à Grandeza e Bondade Inesgotáveis do Senhor",
    146: "Não Confieis em Príncipes: O Senhor Faz Justiça aos Oprimidos",
    147: "Ele Edifica Jerusalém e Cura os de Coração Quebrantado",
    148: "Louvem ao Senhor os Céus, as Alturas e Toda a Criação",
    149: "Cantai ao Senhor um Cântico Novo: A Glória de Todos os Santos",
    150: "Tudo o que Tem Fôlego Louve ao Senhor",
}


def update_database(db_path: Path):
    if not db_path.exists():
        print(f"Banco não encontrado: {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    count_updated = 0
    for chapter, title in PSALMS_PERICOPES.items():
        cursor.execute(
            """
            UPDATE pericope
            SET title = ?
            WHERE book_id = 19 AND chapter = ? AND verse = 1
            """,
            (title, chapter),
        )
        if cursor.rowcount == 0:
            cursor.execute(
                """
                INSERT INTO pericope (book_id, chapter, verse, title)
                VALUES (19, ?, 1, ?)
                """,
                (chapter, title),
            )
        count_updated += 1

    conn.commit()
    conn.close()
    print(f"Atualizados {count_updated} salmos em {db_path}")


def main():
    root = Path(__file__).resolve().parent.parent
    main_db = root / "assets" / "pericopes.sqlite"
    update_database(main_db)

    # Copia/atualiza para cópias do flutter web se existirem
    web_assets_candidates = [
        root / "kairos_web" / "build" / "web" / "assets" / "assets" / "pericopes.sqlite",
        root / "kairos_web" / "build" / "unit_test_assets" / "assets" / "pericopes.sqlite",
        root / "kairos_web" / "build" / "flutter_assets" / "assets" / "pericopes.sqlite",
    ]
    for cand in web_assets_candidates:
        if cand.parent.exists():
            shutil.copy2(main_db, cand)
            print(f"Copiado para {cand}")


if __name__ == "__main__":
    main()
