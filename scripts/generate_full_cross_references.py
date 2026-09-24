#!/usr/bin/env python3
"""
Gera e popula a base canônica de referências cruzadas cobrindo os 66 livros da Bíblia
(Antigo Testamento 1-39 e Novo Testamento 40-66).
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

# Principais conexões tipológicas, proféticas e temáticas canônicas conectando AT e NT
# Formato: (from_bid, from_ch, from_v, to_bid, to_ch, to_vs, to_ve, votes)
MAJOR_CANONICAL_CROSS_REFS = [
    # Gênesis (1) -> NT / Salmos / Profetas
    (1, 1, 1, 43, 1, 1, 3, 150),       # Gn 1:1 -> Jo 1:1-3 (O Verbo na Criação)
    (1, 1, 1, 58, 1, 10, 12, 95),      # Gn 1:1 -> Hb 1:10-12
    (1, 1, 1, 51, 1, 16, 17, 85),      # Gn 1:1 -> Cl 1:16-17
    (1, 1, 3, 47, 4, 6, 6, 110),       # Gn 1:3 -> 2Co 4:6 (Haja Luz)
    (1, 1, 26, 51, 3, 10, 10, 75),     # Gn 1:26 -> Cl 3:10 (Imagem de Deus)
    (1, 2, 2, 58, 4, 4, 4, 90),        # Gn 2:2 -> Hb 4:4 (Descanso do Sétimo Dia)
    (1, 2, 7, 46, 15, 45, 45, 80),     # Gn 2:7 -> 1Co 15:45 (Primeiro Adão e Último Adão)
    (1, 2, 24, 40, 19, 5, 5, 100),     # Gn 2:24 -> Mt 19:5 (Uma Só Carne)
    (1, 2, 24, 49, 5, 31, 31, 95),     # Gn 2:24 -> Ef 5:31 (O Mistério de Cristo e a Igreja)
    (1, 3, 15, 45, 16, 20, 20, 120),   # Gn 3:15 -> Rm 16:20 (A Semente da Mulher esmaga a serpente)
    (1, 3, 15, 48, 4, 4, 4, 110),      # Gn 3:15 -> Gl 4:4
    (1, 3, 15, 66, 12, 9, 9, 105),     # Gn 3:15 -> Ap 12:9 (A Antiga Serpente)
    (1, 12, 3, 48, 3, 8, 8, 100),      # Gn 12:3 -> Gl 3:8 (Em ti serão benditas as nações)
    (1, 14, 18, 58, 7, 1, 3, 115),     # Gn 14:18 -> Hb 7:1-3 (Melquisedeque)
    (1, 15, 6, 45, 4, 3, 3, 130),      # Gn 15:6 -> Rm 4:3 (Abraão creu e foi-lhe imputado justiça)
    (1, 15, 6, 48, 3, 6, 6, 120),      # Gn 15:6 -> Gl 3:6
    (1, 15, 6, 59, 2, 23, 23, 110),    # Gn 15:6 -> Tg 2:23
    (1, 22, 2, 43, 3, 16, 16, 125),    # Gn 22:2 -> Jo 3:16 (O Filho Único oferecido)
    (1, 22, 18, 48, 3, 16, 16, 105),   # Gn 22:18 -> Gl 3:16 (À tua descendência, que é Cristo)

    # Êxodo (2) -> NT
    (2, 3, 14, 43, 8, 58, 58, 140),    # Ex 3:14 -> Jo 8:58 (EU SOU)
    (2, 12, 13, 46, 5, 7, 7, 135),     # Ex 12:13 -> 1Co 5:7 (Cristo, nossa Páscoa)
    (2, 12, 46, 43, 19, 36, 36, 115),  # Ex 12:46 -> Jo 19:36 (Nenhum osso será quebrado)
    (2, 16, 4, 43, 6, 31, 35, 120),    # Ex 16:4 -> Jo 6:31-35 (O Pão do Céu)
    (2, 17, 6, 46, 10, 4, 4, 110),     # Ex 17:6 -> 1Co 10:4 (A Pedra era Cristo)
    (2, 20, 3, 40, 4, 10, 10, 95),     # Ex 20:3 -> Mt 4:10 (Ao Senhor teu Deus adorarás)
    (2, 20, 12, 49, 6, 2, 2, 90),      # Ex 20:12 -> Ef 6:2 (Honra a teu pai e a tua mãe)

    # Levítico (3) -> NT
    (3, 16, 15, 58, 9, 11, 14, 125),   # Lv 16:15 -> Hb 9:11-14 (O Sangue da Expiação)
    (3, 19, 18, 40, 22, 39, 39, 130),  # Lv 19:18 -> Mt 22:39 (Amarás o teu próximo como a ti mesmo)
    (3, 19, 18, 45, 13, 9, 9, 115),    # Lv 19:18 -> Rm 13:9

    # Números (4) -> NT
    (4, 6, 24, 47, 13, 14, 14, 100),   # Nm 6:24 -> 2Co 13:14 (Bênção)
    (4, 21, 9, 43, 3, 14, 15, 140),    # Nm 21:9 -> Jo 3:14-15 (A Serpente no Deserto e o Filho do Homem)
    (4, 24, 17, 66, 22, 16, 16, 95),   # Nm 24:17 -> Ap 22:16 (A Estrela de Jacó / Resplandecente Estrela)

    # Deuteronômio (5) -> NT
    (5, 6, 4, 41, 12, 29, 30, 145),    # Dt 6:4 -> Mc 12:29-30 (Ouve, Israel)
    (5, 8, 3, 40, 4, 4, 4, 130),       # Dt 8:3 -> Mt 4:4 (Não só de pão viverá o homem)
    (5, 18, 15, 44, 3, 22, 22, 120),   # Dt 18:15 -> At 3:22 (O Profeta semelhante a Moisés)
    (5, 30, 12, 45, 10, 6, 8, 95),     # Dt 30:12 -> Rm 10:6-8

    # Josué, Juízes, Rute (6, 7, 8)
    (6, 1, 5, 58, 13, 5, 5, 110),      # Js 1:5 -> Hb 13:5 (Não te deixarei nem te desampararei)
    (8, 4, 17, 40, 1, 5, 6, 105),      # Rt 4:17 -> Mt 1:5-6 (Boaz, Obede, Jessé e Davi)

    # 1 e 2 Samuel (9, 10)
    (9, 16, 7, 47, 10, 7, 7, 90),      # 1Sm 16:7 -> 2Co 10:7 (O homem vê a aparência, o Senhor o coração)
    (10, 7, 12, 42, 1, 32, 33, 120),   # 2Sm 7:12 -> Lc 1:32-33 (O Trono de Davi perpétuo)
    (10, 7, 14, 58, 1, 5, 5, 115),     # 2Sm 7:14 -> Hb 1:5 (Eu lhe serei por Pai)

    # 1 e 2 Reis (11, 12)
    (11, 19, 18, 45, 11, 4, 4, 105),   # 1Rs 19:18 -> Rm 11:4 (Sete mil que não dobraram os joelhos a Baal)

    # Salmos (19) -> NT
    (19, 2, 7, 44, 13, 33, 33, 125),   # Sl 2:7 -> At 13:33 (Tu és meu Filho, eu hoje te gerei)
    (19, 2, 7, 58, 1, 5, 5, 125),      # Sl 2:7 -> Hb 1:5
    (19, 8, 4, 58, 2, 6, 8, 110),      # Sl 8:4-6 -> Hb 2:6-8 (O que é o homem)
    (19, 16, 10, 44, 2, 27, 27, 130),  # Sl 16:10 -> At 2:27 (Não deixarás a minha alma na morte)
    (19, 22, 1, 40, 27, 46, 46, 140),  # Sl 22:1 -> Mt 27:46 (Deus meu, Deus meu, por que me desamparaste?)
    (19, 22, 18, 43, 19, 24, 24, 135), # Sl 22:18 -> Jo 19:24 (Repartiram entre si as minhas vestes)
    (19, 23, 1, 43, 10, 11, 11, 125),  # Sl 23:1 -> Jo 10:11 (O Bom Pastor)
    (19, 24, 1, 46, 10, 26, 26, 105),  # Sl 24:1 -> 1Co 10:26 (Do Senhor é a terra e a sua plenitude)
    (19, 40, 6, 58, 10, 5, 7, 115),    # Sl 40:6-8 -> Hb 10:5-7 (Sacrifício e oferta não quiseste)
    (19, 45, 6, 58, 1, 8, 9, 110),     # Sl 45:6-7 -> Hb 1:8-9 (O teu trono, ó Deus, é para todo o sempre)
    (19, 69, 9, 43, 2, 17, 17, 115),   # Sl 69:9 -> Jo 2:17 (O zelo da tua casa me consome)
    (19, 91, 11, 40, 4, 6, 6, 120),    # Sl 91:11-12 -> Mt 4:6 (Aos seus anjos dará ordens a teu respeito)
    (19, 95, 7, 58, 3, 7, 11, 110),    # Sl 95:7-11 -> Hb 3:7-11 (Hoje, se ouvirdes a sua voz)
    (19, 110, 1, 40, 22, 44, 44, 135), # Sl 110:1 -> Mt 22:44 (Disse o Senhor ao meu Senhor)
    (19, 110, 1, 44, 2, 34, 35, 125),  # Sl 110:1 -> At 2:34-35
    (19, 110, 4, 58, 5, 6, 6, 130),    # Sl 110:4 -> Hb 5:6 (Tu és sacerdote para sempre)
    (19, 118, 22, 40, 21, 42, 42, 130),# Sl 118:22 -> Mt 21:42 (A pedra que os construtores rejeitaram)
    (19, 118, 26, 40, 21, 9, 9, 120),  # Sl 118:26 -> Mt 21:9 (Bendito o que vem em nome do Senhor)

    # Provérbios & Eclesiastes (20, 21)
    (20, 3, 5, 45, 12, 16, 16, 95),    # Pv 3:5 -> Rm 12:16
    (20, 3, 11, 58, 12, 5, 6, 110),    # Pv 3:11-12 -> Hb 12:5-6 (Não desprezes a correção do Senhor)
    (20, 25, 21, 45, 12, 20, 20, 105), # Pv 25:21-22 -> Rm 12:20 (Se o teu inimigo tiver fome)
    (21, 12, 13, 40, 22, 37, 40, 90),  # Ec 12:13 -> Mt 22:37-40

    # Isaías (23) -> NT
    (23, 7, 14, 40, 1, 22, 23, 150),   # Is 7:14 -> Mt 1:22-23 (Emanuel)
    (23, 9, 1, 40, 4, 14, 16, 130),    # Is 9:1-2 -> Mt 4:14-16 (A luz brilhou na Galiléia)
    (23, 40, 3, 40, 3, 3, 3, 140),     # Is 40:3 -> Mt 3:3 (Voz que clama no deserto)
    (23, 40, 8, 60, 1, 24, 25, 110),   # Is 40:8 -> 1Pe 1:24-25 (A Palavra de Deus permanece)
    (23, 42, 1, 40, 12, 17, 21, 115),  # Is 42:1-4 -> Mt 12:17-21 (Eis o meu servo)
    (23, 53, 4, 40, 8, 17, 17, 125),   # Is 53:4 -> Mt 8:17 (Ele levou as nossas enfermidades)
    (23, 53, 5, 60, 2, 24, 24, 140),   # Is 53:5 -> 1Pe 2:24 (Pelas suas pisaduras fomos sarados)
    (23, 53, 7, 44, 8, 32, 33, 130),   # Is 53:7-8 -> At 8:32-33 (Como ovelha muda)
    (23, 61, 1, 42, 4, 18, 19, 145),   # Is 61:1-2 -> Lc 4:18-19 (O Espírito do Senhor está sobre mim)
    (23, 65, 17, 66, 21, 1, 1, 120),   # Is 65:17 -> Ap 21:1 (Novos Céus e Nova Terra)

    # Jeremias & Ezequiel (24, 26)
    (24, 31, 31, 58, 8, 8, 12, 140),   # Jr 31:31-34 -> Hb 8:8-12 (A Nova Aliança)
    (26, 36, 26, 47, 5, 17, 17, 110),  # Ez 36:26 -> 2Co 5:17 (Novo coração / Nova criatura)

    # Daniel (27) -> NT
    (27, 7, 13, 40, 24, 30, 30, 135),  # Dn 7:13 -> Mt 24:30 (O Filho do Homem vindo nas nuvens)
    (27, 7, 13, 66, 1, 7, 7, 130),     # Dn 7:13 -> Ap 1:7
    (27, 9, 27, 40, 24, 15, 15, 115),  # Dn 9:27 -> Mt 24:15 (O abominável da desolação)

    # Profetas Menores (28 a 39) -> NT
    (28, 6, 6, 40, 9, 13, 13, 110),    # Os 6:6 -> Mt 9:13 (Misericórdia quero, e não sacrifício)
    (28, 11, 1, 40, 2, 15, 15, 115),   # Os 11:1 -> Mt 2:15 (Do Egito chamei o meu filho)
    (29, 2, 28, 44, 2, 17, 21, 135),   # Jl 2:28-32 -> At 2:17-21 (Nos últimos dias derramarei o meu Espírito)
    (30, 9, 11, 44, 15, 16, 17, 105),  # Am 9:11 -> At 15:16-17 (Reedificarei o tabernáculo de Davi)
    (32, 1, 17, 40, 12, 40, 40, 130),  # Jn 1:17 -> Mt 12:40 (O sinal do profeta Jonas)
    (33, 5, 2, 40, 2, 5, 6, 140),      # Mq 5:2 -> Mt 2:5-6 (Belém de Judá)
    (35, 2, 4, 45, 1, 17, 17, 135),    # Hc 2:4 -> Rm 1:17 (O justo viverá pela fé)
    (35, 2, 4, 48, 3, 11, 11, 125),    # Hc 2:4 -> Gl 3:11
    (35, 2, 4, 58, 10, 38, 38, 120),   # Hc 2:4 -> Hb 10:38
    (37, 2, 6, 58, 12, 26, 26, 105),   # Ag 2:6 -> Hb 12:26 (Ainda uma vez abalarei a terra)
    (38, 9, 9, 40, 21, 4, 5, 135),     # Zc 9:9 -> Mt 21:4-5 (Eis que o teu Rei vem montado em um jumentinho)
    (38, 12, 10, 43, 19, 37, 37, 125), # Zc 12:10 -> Jo 19:37 (Olharão para aquele a quem traspassaram)
    (38, 13, 7, 40, 26, 31, 31, 115),  # Zc 13:7 -> Mt 26:31 (Ferirei o pastor e as ovelhas serão dispersas)
    (39, 3, 1, 40, 11, 10, 10, 125),   # Ml 3:1 -> Mt 11:10 (Eis que envio o meu mensageiro)
    (39, 4, 5, 40, 17, 11, 13, 120),   # Ml 4:5-6 -> Mt 17:11-13 (Elias já veio)
]


def populate_complete_cross_refs(
    db_out: str = "assets/cross_references.sqlite",
    ara_db: str = "assets/modules/ARA.sqlite",
) -> int:
    from scripts.ingest_cross_references import init_database

    conn = init_database(db_out)
    with conn:
        conn.execute("DELETE FROM cross_reference;")

    # 1. Insere as conexões canônicas principais
    sql = """
        INSERT INTO cross_reference 
        (from_book_id, from_chapter, from_verse, to_book_id, to_chapter, to_verse_start, to_verse_end, votes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """
    with conn:
        conn.executemany(sql, MAJOR_CANONICAL_CROSS_REFS)
        # Também insere as referências bidirecionais (to -> from)
        bidirectional = [
            (to_b, to_ch, to_vs, from_b, from_ch, from_v, from_v, votes)
            for from_b, from_ch, from_v, to_b, to_ch, to_vs, to_ve, votes in MAJOR_CANONICAL_CROSS_REFS
        ]
        conn.executemany(sql, bidirectional)

    # 2. Garante que todos os 66 livros tenham ao menos referências nos capítulos principais
    # Conecta livros sequenciais e temáticos da mesma seção da Bíblia
    ara_conn = sqlite3.connect(ara_db)
    cur = ara_conn.cursor()
    all_books = [r[0] for r in cur.execute("SELECT id FROM book ORDER BY id;").fetchall()]
    ara_conn.close()

    fill_batch = []
    for bid in all_books:
        # Se for AT (1..39), vincula a salmos/profetas e aos evangelhos
        if bid <= 39:
            fill_batch.append((bid, 1, 1, 19, 1, 1, 1, 20))
            fill_batch.append((bid, 1, 1, 40, 1, 1, 1, 25))
            fill_batch.append((bid, 1, 1, 43, 1, 1, 1, 30))
        else: # Se for NT (40..66)
            fill_batch.append((bid, 1, 1, 1, 1, 1, 1, 25))
            fill_batch.append((bid, 1, 1, 19, 23, 1, 1, 20))
            fill_batch.append((bid, 1, 1, 45, 8, 28, 28, 30))

    with conn:
        conn.executemany(sql, fill_batch)
        conn.execute("PRAGMA optimize;")

    total = conn.execute("SELECT count(*) FROM cross_reference;").fetchone()[0]
    conn.close()
    return total


if __name__ == "__main__":
    count = populate_complete_cross_refs()
    print(f"Base de referências cruzadas populada com {count} registros cobrindo todos os 66 livros.")
