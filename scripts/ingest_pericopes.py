#!/usr/bin/env python3
"""
Script de Ingestão e Geração da Base de Perícopes / Títulos de Seção para o Kairós.

Cria o banco 'assets/pericopes.sqlite' com as perícopes canônicas da Bíblia em português.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sqlite3
from typing import Sequence

# Amostra canônica curada de perícopes representativas para o Antigo e Novo Testamento
# (Formato: book_id, chapter, verse, title)
CANONICAL_PERICOPES_DATA: list[tuple[int, int, int, str]] = [
    # Gênesis (1)
    (1, 1, 1, "A Criação dos Céus e da Terra"),
    (1, 1, 3, "O Primeiro Dia: A Luz"),
    (1, 1, 6, "O Segundo Dia: O Firmamento"),
    (1, 1, 9, "O Terceiro Dia: A Terra Seca e a Vegetação"),
    (1, 1, 14, "O Quarto Dia: Os Luminares"),
    (1, 1, 20, "O Quinto Dia: Os Animais Aquáticos e as Aves"),
    (1, 1, 24, "O Sexto Dia: Os Animais Terrestres e o Homem"),
    (1, 2, 1, "O Sétimo Dia: O Descanso de Deus"),
    (1, 2, 4, "O Jardim do Éden"),
    (1, 2, 18, "A Criação da Mulher"),
    (1, 3, 1, "A Queda do Homem"),
    (1, 3, 14, "A Sentença e a Promessa da Redenção"),
    (1, 4, 1, "Caim e Abel"),
    (1, 6, 1, "A Corrupção da Humanidade"),
    (1, 6, 9, "Noé e a Arca"),
    (1, 7, 1, "O Dilúvio"),
    (1, 9, 1, "A Aliança de Deus com Noé"),
    (1, 11, 1, "A Torre de Babel"),
    (1, 12, 1, "O Chamado de Abrão"),
    (1, 15, 1, "A Aliança de Deus com Abrão"),
    (1, 22, 1, "O Sacrifício de Isaque"),
    # Êxodo (2)
    (2, 1, 1, "Os Israelitas no Egito"),
    (2, 2, 1, "O Nascimento e a Juventude de Moisés"),
    (2, 3, 1, "Moisés e a Sarça Ardente"),
    (2, 12, 1, "A Instituição da Páscoa"),
    (2, 14, 1, "A Passagem pelo Mar Vermelho"),
    (2, 20, 1, "Os Dez Mandamentos"),
    # Salmos (19)
    (19, 1, 1, "A Felicidade dos Justos e o Fim dos Ímpios"),
    (19, 23, 1, "O Senhor é o Meu Pastor"),
    (19, 46, 1, "Deus, o Nosso Refúgio"),
    (19, 91, 1, "A Segurança daquele que Confia no Senhor"),
    (19, 100, 1, "Exortação a Louvar a Deus"),
    (19, 103, 1, "Louvor pela Misericórdia de Deus"),
    (19, 119, 1, "A Excelência da Lei de Deus"),
    (19, 121, 1, "O Socorro do Senhor"),
    (19, 139, 1, "A Onipresença e Onisciência de Deus"),
    (19, 150, 1, "Exortação Universal ao Louvor"),
    # Isaías (23)
    (23, 7, 14, "O Sinal de Emanuel"),
    (23, 9, 1, "O Nascimento e o Reino do Príncipe da Paz"),
    (23, 40, 1, "Consolação para o Povo de Deus"),
    (23, 53, 1, "O Servo Sofredor"),
    # Mateus (40)
    (40, 1, 1, "A Genealogia de Jesus Cristo"),
    (40, 1, 18, "O Nascimento de Jesus"),
    (40, 2, 1, "A Visita dos Magos"),
    (40, 3, 1, "A Pregação de João Batista"),
    (40, 3, 13, "O Batismo de Jesus"),
    (40, 4, 1, "A Tentação de Jesus"),
    (40, 5, 1, "O Sermão do Monte: As Bem-aventuranças"),
    (40, 5, 13, "O Sal da Terra e a Luz do Mundo"),
    (40, 6, 9, "A Oração do Pai-Nosso"),
    (40, 6, 25, "A Ansiedade e o Cuidado de Deus"),
    (40, 7, 1, "O Não Julgar"),
    (40, 7, 24, "Os Dois Fundamentos"),
    (40, 13, 1, "A Parábola do Semeador"),
    (40, 13, 24, "A Parábola do Trigo e do Joio"),
    (40, 28, 1, "A Ressurreição de Jesus"),
    (40, 28, 16, "A Grande Comissão"),
    # João (43)
    (43, 1, 1, "O Verbo Eterno"),
    (43, 1, 19, "O Testemunho de João Batista"),
    (43, 2, 1, "O Primeiro Milagre: As Bodas de Caná"),
    (43, 3, 1, "A Conversa com Nicodemos"),
    (43, 4, 1, "A Mulher Samaritana"),
    (43, 10, 1, "O Bom Pastor"),
    (43, 11, 1, "A Morte e Ressurreição de Lázaro"),
    (43, 14, 1, "O Caminho, a Verdade e a Vida"),
    (43, 15, 1, "A Videira Verdadeira"),
    # Romanos (45)
    (45, 1, 1, "A Saudação e o Evangelho do Poder de Deus"),
    (45, 3, 21, "A Justiça de Deus Mediante a Fé"),
    (45, 8, 1, "A Vida no Espírito"),
    (45, 8, 28, "Mais que Vencedores em Cristo"),
    (45, 12, 1, "O Culto Racional e a Nova Vida"),
    # 1 Coríntios (46)
    (46, 13, 1, "A Excelência do Amor"),
    (46, 15, 1, "A Ressurreição dos Mortos"),
    # Apocalipse (66)
    (66, 1, 1, "A Revelação de Jesus Cristo"),
    (66, 21, 1, "O Novo Céu e a Nova Terra"),
    (66, 22, 1, "O Rio da Água da Vida e a Vinda de Jesus"),
]


def init_pericopes_db(db_path: Path | str) -> sqlite3.Connection:
    """Cria tabela e índice otimizado para perícopes."""
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")

    with conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS pericope (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book_id INTEGER NOT NULL,
                chapter INTEGER NOT NULL,
                verse INTEGER NOT NULL,
                title TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_pericope_chapter 
            ON pericope (book_id, chapter, verse ASC);
            """
        )
    return conn


def populate_pericopes(
    db_path: Path | str, data: Sequence[tuple[int, int, int, str]]
) -> int:
    """Popula o banco SQLite com a lista de perícopes."""
    conn = init_pericopes_db(db_path)
    sql = "INSERT INTO pericope (book_id, chapter, verse, title) VALUES (?, ?, ?, ?);"
    with conn:
        conn.executemany(sql, data)
    conn.execute("PRAGMA optimize;")
    conn.close()
    return len(data)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingestão de Perícopes Bíblicas")
    parser.add_argument(
        "--db",
        default="assets/pericopes.sqlite",
        help="Caminho do banco SQLite de saída",
    )
    args = parser.parse_args()
    total = populate_pericopes(args.db, CANONICAL_PERICOPES_DATA)
    print(f"Sucesso: {total} perícopes salvas em {args.db}")
