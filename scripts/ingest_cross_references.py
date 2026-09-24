#!/usr/bin/env python3
"""
Script de Ingestão e Normalização do Dataset de Referências Cruzadas OpenBible para o Kairós.

Lê o formato bruto TSV do OpenBible ('From Verse \\t To Verse \\t Votes'):
Exemplo:
  Gen.1.1       John.1.1        115
  Gen.1.1       Heb.1.10        84
  Matt.28.19    2Cor.13.14      62
  Rom.8.28      Rom.8.29-Rom.8.30       45

Garante:
1. Mapeamento 100% canônico de siglas USFM (Gen, Matt, Rev) para inteiros book_id (1..66).
2. Validação rigorosa de tipos e sanitização contra entradas malformadas ou corrompidas.
3. Criação de banco SQLite ('assets/cross_references.sqlite') com WAL e índices otimizados B-Tree.
4. Zero strings ou siglas em inglês salvas no banco.
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import re
import sqlite3
import sys

# Mapeamento oficial e canônico de códigos USFM / OpenBible para ID do Livro (1 a 66)
USFM_TO_BOOK_ID: dict[str, int] = {
    # Antigo Testamento (1 a 39)
    "Gen": 1,
    "Exod": 2,
    "Lev": 3,
    "Num": 4,
    "Deut": 5,
    "Josh": 6,
    "Judg": 7,
    "Ruth": 8,
    "1Sam": 9,
    "2Sam": 10,
    "1Kgs": 11,
    "2Kgs": 12,
    "1Chr": 13,
    "2Chr": 14,
    "Ezra": 15,
    "Neh": 16,
    "Esth": 17,
    "Job": 18,
    "Ps": 19,
    "Prov": 20,
    "Eccl": 21,
    "Song": 22,
    "Isa": 23,
    "Jer": 24,
    "Lam": 25,
    "Ezek": 26,
    "Dan": 27,
    "Hos": 28,
    "Joel": 29,
    "Amos": 30,
    "Obad": 31,
    "Jonah": 32,
    "Mic": 33,
    "Nah": 34,
    "Hab": 35,
    "Zeph": 36,
    "Hag": 37,
    "Zech": 38,
    "Mal": 39,
    # Novo Testamento (40 a 66)
    "Matt": 40,
    "Mark": 41,
    "Luke": 42,
    "John": 43,
    "Acts": 44,
    "Rom": 45,
    "1Cor": 46,
    "2Cor": 47,
    "Gal": 48,
    "Eph": 49,
    "Phil": 50,
    "Col": 51,
    "1Thess": 52,
    "2Thess": 53,
    "1Tim": 54,
    "2Tim": 55,
    "Titus": 56,
    "Phlm": 57,
    "Heb": 58,
    "Jas": 59,
    "1Pet": 60,
    "2Pet": 61,
    "1John": 62,
    "2John": 63,
    "3John": 64,
    "Jude": 65,
    "Rev": 66,
}


def parse_usfm_verse(verse_token: str) -> tuple[int, int, int] | None:
    """
    Interpreta token USFM como 'Gen.1.1' -> (1, 1, 1).
    Retorna None se inválido ou livro desconhecido.
    """
    token = verse_token.strip()
    parts = token.split(".")
    if len(parts) < 3:
        return None

    book_code = parts[0].strip()
    book_id = USFM_TO_BOOK_ID.get(book_code)
    if not book_id:
        return None

    try:
        chapter = int(parts[1])
        verse = int(parts[2])
    except ValueError:
        return None

    if chapter < 1 or verse < 1:
        return None

    return book_id, chapter, verse


def parse_target_usfm_ref(target_token: str) -> tuple[int, int, int, int] | None:
    """
    Interpreta o destino que pode ser versículo único ('John.1.1')
    ou intervalo ('John.1.1-John.1.3' ou 'John.1.1-3').
    Retorna: (to_book_id, to_chapter, to_verse_start, to_verse_end)
    """
    token = target_token.strip()
    if "-" in token:
        start_part, end_part = token.split("-", 1)
        start_res = parse_usfm_verse(start_part)
        if not start_res:
            return None
        to_book_id, to_chapter, to_verse_start = start_res

        # Trata o final que pode ser 'John.1.3' ou '3'
        end_part = end_part.strip()
        if "." in end_part:
            end_res = parse_usfm_verse(end_part)
            if end_res:
                to_verse_end = end_res[2]
            else:
                to_verse_end = to_verse_start
        elif end_part.isdigit():
            to_verse_end = int(end_part)
        else:
            to_verse_end = to_verse_start

        if to_verse_end < to_verse_start:
            to_verse_end = to_verse_start
        return to_book_id, to_chapter, to_verse_start, to_verse_end

    res = parse_usfm_verse(token)
    if not res:
        return None
    b_id, ch, v = res
    return b_id, ch, v, v


def parse_tsv_line(line: str) -> tuple[int, int, int, int, int, int, int, int] | None:
    """
    Valida e converte uma linha do arquivo TSV do OpenBible.
    Retorna tupla normalizada:
      (from_book_id, from_chapter, from_verse, to_book_id, to_chapter, to_verse_start, to_verse_end, votes)
    Retorna None se a linha for inválida ou comentários/cabeçalho.
    """
    line = line.strip()
    if not line or line.startswith("#"):
        return None

    parts = line.split("\t")
    if len(parts) < 3:
        # Tenta fallback para espaços múltiplos
        parts = re.split(r"\s+", line)
        if len(parts) < 3:
            return None

    from_token = parts[0].strip()
    to_token = parts[1].strip()
    votes_token = parts[2].strip()

    # Ignora cabeçalhos
    if "from" in from_token.lower() or "verse" in from_token.lower():
        return None

    from_res = parse_usfm_verse(from_token)
    if not from_res:
        return None
    from_b_id, from_ch, from_v = from_res

    to_res = parse_target_usfm_ref(to_token)
    if not to_res:
        return None
    to_b_id, to_ch, to_vs, to_ve = to_res

    try:
        votes = int(votes_token)
    except ValueError:
        return None

    return from_b_id, from_ch, from_v, to_b_id, to_ch, to_vs, to_ve, votes


def init_database(db_path: Path | str) -> sqlite3.Connection:
    """Cria tabelas e índices otimizados no banco SQLite."""
    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode = WAL;")
    conn.execute("PRAGMA synchronous = NORMAL;")

    with conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS cross_reference (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                from_book_id INTEGER NOT NULL,
                from_chapter INTEGER NOT NULL,
                from_verse INTEGER NOT NULL,
                to_book_id INTEGER NOT NULL,
                to_chapter INTEGER NOT NULL,
                to_verse_start INTEGER NOT NULL,
                to_verse_end INTEGER NOT NULL,
                votes INTEGER NOT NULL DEFAULT 0
            );
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_cross_ref_source 
            ON cross_reference (from_book_id, from_chapter, from_verse, votes DESC);
            """
        )
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_cross_ref_target 
            ON cross_reference (to_book_id, to_chapter, to_verse_start);
            """
        )
    return conn


def ingest_file(
    tsv_path: Path | str,
    db_path: Path | str,
    min_votes: int = 0,
    batch_size: int = 10000,
) -> int:
    """Processa arquivo TSV em lote e salva os dados com garantia transacional."""
    tsv_p = Path(tsv_path)
    if not tsv_p.exists():
        raise FileNotFoundError(f"Arquivo TSV não encontrado: {tsv_p}")

    conn = init_database(db_path)
    inserted = 0
    batch = []

    sql = """
        INSERT INTO cross_reference 
        (from_book_id, from_chapter, from_verse, to_book_id, to_chapter, to_verse_start, to_verse_end, votes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """

    with open(tsv_p, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            parsed = parse_tsv_line(line)
            if not parsed:
                continue
            # Filtro opcional de relevância
            if parsed[7] < min_votes:
                continue

            batch.append(parsed)
            if len(batch) >= batch_size:
                with conn:
                    conn.executemany(sql, batch)
                inserted += len(batch)
                batch.clear()

        if batch:
            with conn:
                conn.executemany(sql, batch)
            inserted += len(batch)
            batch.clear()

    conn.execute("PRAGMA optimize;")
    conn.close()
    return inserted


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingestão de Referências Cruzadas OpenBible")
    parser.add_argument("--tsv", required=True, help="Caminho para o arquivo TSV do OpenBible")
    parser.add_argument(
        "--db",
        default="assets/cross_references.sqlite",
        help="Caminho do banco SQLite de saída",
    )
    parser.add_argument("--min-votes", type=int, default=0, help="Votos mínimos para inserção")

    args = parser.parse_args()
    total = ingest_file(args.tsv, args.db, min_votes=args.min_votes)
    print(f"Ingestão concluída com sucesso! {total} referências importadas para {args.db}")
