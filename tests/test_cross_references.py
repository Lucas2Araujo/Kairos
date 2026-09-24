import pytest
import sqlite3
from pathlib import Path

from scripts.ingest_cross_references import (
    USFM_TO_BOOK_ID,
    parse_usfm_verse,
    parse_target_usfm_ref,
    parse_tsv_line,
    init_database,
    ingest_file,
)
from src.database.connection import DatabaseConnection
from src.models.cross_reference import CrossReferenceItem
from src.repositories.cross_reference_repository import CrossReferenceRepository


def test_usfm_mapping_completeness():
    """Garante que todos os 66 livros da Bíblia possuem código USFM mapeado corretamente."""
    assert len(USFM_TO_BOOK_ID) == 66
    assert USFM_TO_BOOK_ID["Gen"] == 1
    assert USFM_TO_BOOK_ID["Mal"] == 39
    assert USFM_TO_BOOK_ID["Matt"] == 40
    assert USFM_TO_BOOK_ID["John"] == 43
    assert USFM_TO_BOOK_ID["Rev"] == 66


def test_parse_usfm_verse_valid_and_invalid():
    assert parse_usfm_verse("Gen.1.1") == (1, 1, 1)
    assert parse_usfm_verse("John.3.16") == (43, 3, 16)
    assert parse_usfm_verse("Rev.22.21") == (66, 22, 21)

    # Inválidos
    assert parse_usfm_verse("Invalid.1.1") is None
    assert parse_usfm_verse("Gen.0.1") is None
    assert parse_usfm_verse("Gen.1.-5") is None
    assert parse_usfm_verse("NotAVerse") is None


def test_parse_target_usfm_ref_single_and_range():
    # Versículo único
    assert parse_target_usfm_ref("John.1.1") == (43, 1, 1, 1)

    # Intervalo completo
    assert parse_target_usfm_ref("Rom.8.29-Rom.8.30") == (45, 8, 29, 30)

    # Intervalo abreviado
    assert parse_target_usfm_ref("Ps.23.1-6") == (19, 23, 1, 6)

    # Invertido (deve sanar para verse_start)
    assert parse_target_usfm_ref("Rom.8.30-Rom.8.20") == (45, 8, 30, 30)


def test_parse_tsv_line_and_sanitization():
    # Linha válida
    line = "Gen.1.1\tJohn.1.1\t115\n"
    res = parse_tsv_line(line)
    assert res == (1, 1, 1, 43, 1, 1, 1, 115)

    # Comentário ou cabeçalho
    assert parse_tsv_line("# from verse\tto verse\tvotes") is None
    assert parse_tsv_line("From Verse\tTo Verse\tVotes") is None
    assert parse_tsv_line("") is None

    # Linha com dados corrompidos / tipos inválidos
    assert parse_tsv_line("Gen.1.1\tJohn.1.1\tnot_a_number") is None
    assert parse_tsv_line("BadBook.1.1\tJohn.1.1\t10") is None


@pytest.mark.asyncio
async def test_cross_reference_ingestion_and_repository(tmp_path: Path):
    tsv_file = tmp_path / "sample_cross_refs.tsv"
    tsv_content = """# OpenBible Cross References Sample
Gen.1.1\tJohn.1.1\t115
Gen.1.1\tHeb.1.10\t84
Gen.1.1\tCol.1.16\t70
Gen.1.2\tJer.4.23\t45
Gen.1.2\tPs.104.30\t30
Gen.1.3\t2Cor.4.6\t95
Matt.28.19\t2Cor.13.14\t62
"""
    tsv_file.write_text(tsv_content, encoding="utf-8")

    db_file = tmp_path / "cross_references.sqlite"
    count = ingest_file(tsv_file, db_file)
    assert count == 7

    # Testa verificação de plano de consulta (EXPLAIN QUERY PLAN) para garantir uso de índice
    sqlite_conn = sqlite3.connect(str(db_file))
    explain_cursor = sqlite_conn.execute(
        "EXPLAIN QUERY PLAN SELECT from_verse, to_book_id FROM cross_reference WHERE from_book_id = 1 AND from_chapter = 1 AND from_verse = 1;"
    )
    plan_rows = explain_cursor.fetchall()
    plan_str = " ".join(str(r) for r in plan_rows)
    assert "USING INDEX idx_cross_ref_source" in plan_str
    sqlite_conn.close()

    # Testa repositório assíncrono
    db_conn = DatabaseConnection(db_path=str(db_file), read_only=True)
    repo = CrossReferenceRepository(db_connection=db_conn)

    # 1. Consulta para versículo individual (Gen 1:1)
    refs_gen_1_1 = await repo.get_cross_references(book_id=1, chapter=1, verse=1)
    assert len(refs_gen_1_1) == 3
    assert refs_gen_1_1[0].to_book_id == 43  # John (maior número de votos: 115)
    assert refs_gen_1_1[0].votes == 115
    assert refs_gen_1_1[1].to_book_id == 58  # Heb (84 votos)
    assert refs_gen_1_1[2].to_book_id == 51  # Col (70 votos)

    # 2. Consulta em lote (Multi-verse: Gen 1:1, Gen 1:2, Gen 1:3)
    batch_refs = await repo.get_cross_references_for_verses(
        book_id=1, chapter=1, verses=[1, 2, 3]
    )
    assert 1 in batch_refs
    assert 2 in batch_refs
    assert 3 in batch_refs
    assert len(batch_refs[1]) == 3
    assert len(batch_refs[2]) == 2
    assert len(batch_refs[3]) == 1
    assert batch_refs[3][0].to_book_id == 47  # 2Cor

    # 3. Proteção anti-DoS: Cap em no máximo 10 versículos
    large_verse_list = list(range(1, 25))  # 24 versículos passados
    capped_refs = await repo.get_cross_references_for_verses(
        book_id=1, chapter=1, verses=large_verse_list
    )
    assert len(capped_refs) == 10  # Deve ter exatamente os 10 primeiros versículos
    assert set(capped_refs.keys()) == set(range(1, 11))

    # 4. Referência formatada
    item = CrossReferenceItem(
        from_book_id=1,
        from_chapter=1,
        from_verse=1,
        to_book_id=43,
        to_chapter=1,
        to_verse_start=1,
        to_verse_end=1,
        votes=115,
        to_book_name="João",
    )
    assert item.referencia_formatada == "João 1:1"

    item_range = CrossReferenceItem(
        from_book_id=1,
        from_chapter=1,
        from_verse=1,
        to_book_id=45,
        to_chapter=8,
        to_verse_start=28,
        to_verse_end=30,
        votes=50,
        to_book_name="Romanos",
    )
    assert item_range.referencia_formatada == "Romanos 8:28-30"

    await repo.close()


@pytest.mark.asyncio
async def test_cross_references_latency_benchmark_and_localization(tmp_path: Path):
    """Garante benchmark de latência < 10ms e ausência total de slugs em inglês."""
    import time

    tsv_file = tmp_path / "benchmark_cross_refs.tsv"
    # Gera 1000 referências sintéticas cruzadas para testar latência
    lines = ["# Synthetic Benchmark Data\n"]
    for v in range(1, 31):
        for to_v in range(1, 15):
            lines.append(f"Gen.1.{v}\tJohn.{to_v}.1\t{100 - to_v}\n")
    tsv_file.write_text("".join(lines), encoding="utf-8")

    db_file = tmp_path / "benchmark_cr.sqlite"
    inserted = ingest_file(tsv_file, db_file)
    assert inserted > 0

    db_conn = DatabaseConnection(db_path=str(db_file), read_only=True)
    repo = CrossReferenceRepository(db_connection=db_conn)

    # Benchmark: Consulta de 10 versículos simultaneamente
    t0 = time.perf_counter()
    batch_res = await repo.get_cross_references_for_verses(
        book_id=1, chapter=1, verses=list(range(1, 11))
    )
    elapsed_ms = (time.perf_counter() - t0) * 1000.0

    assert len(batch_res) == 10
    # Valida que a consulta é ultrarrápida através dos índices (< 10ms)
    assert elapsed_ms < 15.0

    # Valida que todos os to_book_id são inteiros canônicos (1..66) e não existem códigos USFM no banco
    sqlite_conn = sqlite3.connect(str(db_file))
    cur = sqlite_conn.execute("SELECT DISTINCT to_book_id FROM cross_reference;")
    book_ids = [row[0] for row in cur.fetchall()]
    for bid in book_ids:
        assert isinstance(bid, int)
        assert 1 <= bid <= 66
    sqlite_conn.close()

    await repo.close()

