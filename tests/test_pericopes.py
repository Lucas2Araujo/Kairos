import pytest
import sqlite3
from pathlib import Path
from unittest.mock import MagicMock
import asyncio
import flet as ft

from scripts.ingest_pericopes import init_pericopes_db, populate_pericopes
from src.database.connection import DatabaseConnection
from src.models.pericope import Pericope
from src.repositories.biblia_repository import BibliaRepository
from src.repositories.pericope_repository import PericopeRepository
from src.services.theme_service import ThemeService
from src.views.biblia_view import BibliaView


def test_pericope_dto():
    p = Pericope(book_id=1, chapter=1, verse=1, title="A Criação dos Céus e da Terra")
    assert p.book_id == 1
    assert p.chapter == 1
    assert p.verse == 1
    assert p.title == "A Criação dos Céus e da Terra"


@pytest.mark.asyncio
async def test_pericope_ingestion_and_repository(tmp_path: Path):
    db_file = tmp_path / "test_pericopes.sqlite"
    sample_data = [
        (1, 1, 1, "A Criação dos Céus e da Terra"),
        (1, 1, 3, "O Primeiro Dia: A Luz"),
        (1, 2, 1, "O Descanso de Deus"),
        (43, 1, 1, "O Verbo Eterno"),
    ]
    inserted = populate_pericopes(db_file, sample_data)
    assert inserted == 4

    # Verifica plano de execução para garantir uso do índice
    conn = sqlite3.connect(str(db_file))
    cur = conn.execute(
        "EXPLAIN QUERY PLAN SELECT verse, title FROM pericope WHERE book_id = 1 AND chapter = 1 ORDER BY verse ASC;"
    )
    plan_rows = cur.fetchall()
    plan_str = " ".join(str(r) for r in plan_rows)
    assert "USING INDEX idx_pericope_chapter" in plan_str
    conn.close()

    # Testa o repositório
    db_conn = DatabaseConnection(db_path=str(db_file), read_only=True)
    repo = PericopeRepository(db_connection=db_conn)

    # 1. Capítulo com perícopes (Gênesis 1)
    gen_1 = await repo.get_pericopes_map(1, 1)
    assert len(gen_1) == 2
    assert gen_1[1] == "A Criação dos Céus e da Terra"
    assert gen_1[3] == "O Primeiro Dia: A Luz"

    # 2. Capítulo com 1 perícope (Gênesis 2)
    gen_2 = await repo.get_pericopes_map(1, 2)
    assert len(gen_2) == 1
    assert gen_2[1] == "O Descanso de Deus"

    # 3. Capítulo sem perícopes cadastradas
    gen_3 = await repo.get_pericopes_map(1, 3)
    assert gen_3 == {}

    # 4. Parâmetros inválidos
    assert await repo.get_pericopes_map(0, 1) == {}
    assert await repo.get_pericopes_map(67, 1) == {}
    assert await repo.get_pericopes_map(1, 0) == {}

    await repo.close()


@pytest.mark.asyncio
async def test_biblia_view_pericopes_rendering():
    """Valida a injeção não invasiva dos títulos de seção no leitor bíblico."""
    db_conn = DatabaseConnection(db_path=":memory:", read_only=False)
    conn = await db_conn.get_connection()
    await conn.execute("CREATE TABLE IF NOT EXISTS preferencias (chave TEXT PRIMARY KEY, valor TEXT);")
    await conn.execute("CREATE TABLE book (id INTEGER PRIMARY KEY, name VARCHAR(50));")
    await conn.execute("CREATE TABLE verse (id INTEGER PRIMARY KEY, book_id INTEGER, chapter INTEGER, verse INTEGER, text TEXT);")
    await conn.execute("INSERT INTO book VALUES (1, 'Gênesis');")
    await conn.execute("INSERT INTO verse VALUES (1, 1, 1, 1, 'No princípio criou Deus os céus e a terra.');")
    await conn.execute("INSERT INTO verse VALUES (2, 1, 1, 2, 'E a terra era sem forma e vazia.');")
    await conn.execute("INSERT INTO verse VALUES (3, 1, 1, 3, 'E disse Deus: Haja luz.');")
    await conn.commit()

    # Banco de perícopes em memória
    p_conn = DatabaseConnection(db_path=":memory:", read_only=False)
    p_raw = await p_conn.get_connection()
    await p_raw.execute("""
        CREATE TABLE pericope (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            title TEXT NOT NULL
        );
    """)
    await p_raw.execute("INSERT INTO pericope VALUES (1, 1, 1, 1, 'A Criação dos Céus e da Terra');")
    await p_raw.execute("INSERT INTO pericope VALUES (2, 1, 1, 3, 'O Primeiro Dia: A Luz');")
    await p_raw.commit()

    repo = BibliaRepository(db_conn)
    pericope_repo = PericopeRepository(db_connection=p_conn)
    theme_service = ThemeService(db_conn)
    view_instance = BibliaView(
        repo,
        theme_service=theme_service,
        pericope_repository=pericope_repo,
    )

    mock_page = MagicMock(spec=ft.Page)
    mock_page.update = MagicMock()

    await view_instance.build(mock_page, initial_book_id=1, initial_chapter=1)
    if view_instance._load_task:
        await view_instance._load_task
    await asyncio.sleep(0.1)

    # Verifica se os versículos e cabeçalhos foram injetados na ordem correta
    controls = view_instance.verses_list.controls
    # controls[0] é o cabeçalho do capítulo
    # controls[1] deve ser o título da perícope do versículo 1
    # controls[2] deve ser o GestureDetector do versículo 1
    # controls[3] deve ser o GestureDetector do versículo 2 (sem perícope)
    # controls[4] deve ser o título da perícope do versículo 3
    # controls[5] deve ser o GestureDetector do versículo 3

    assert len(controls) == 4
    # controls[0] é o cabeçalho do capítulo
    # controls[1] deve ser o GestureDetector do versículo 1 com a perícope embutida
    assert isinstance(controls[1], ft.GestureDetector)
    assert controls[1].key == "v_1"
    v1_container = controls[1].content
    assert isinstance(v1_container, ft.Container)
    assert v1_container is view_instance._verse_containers[1]
    v1_col = v1_container.content
    assert isinstance(v1_col, ft.Column)
    assert "A Criação dos Céus e da Terra" in v1_col.controls[0].content.controls[1].value

    # controls[2] deve ser o GestureDetector do versículo 2 (sem perícope)
    assert isinstance(controls[2], ft.GestureDetector)
    assert controls[2].key == "v_2"
    assert controls[2].content is view_instance._verse_containers[2]
    assert isinstance(controls[2].content.content, ft.Row)

    # controls[3] deve ser o GestureDetector do versículo 3 com a perícope embutida
    assert isinstance(controls[3], ft.GestureDetector)
    assert controls[3].key == "v_3"
    v3_container = controls[3].content
    assert isinstance(v3_container, ft.Container)
    assert v3_container is view_instance._verse_containers[3]
    v3_col = v3_container.content
    assert isinstance(v3_col, ft.Column)
    assert "O Primeiro Dia: A Luz" in v3_col.controls[0].content.controls[1].value

    # Garante que as chaves dos versículos e mapa _verse_containers continuam íntegros
    assert 1 in view_instance._verse_containers
    assert 2 in view_instance._verse_containers
    assert 3 in view_instance._verse_containers

    # Limpeza
    if view_instance._load_task and not view_instance._load_task.done():
        view_instance._load_task.cancel()
        try:
            await view_instance._load_task
        except asyncio.CancelledError:
            pass
    if view_instance._save_pref_task and not view_instance._save_pref_task.done():
        view_instance._save_pref_task.cancel()
        try:
            await view_instance._save_pref_task
        except asyncio.CancelledError:
            pass
    await asyncio.sleep(0.05)

    await view_instance.close()
    await pericope_repo.close()
    await repo.close()
    await db_conn.close()
    await p_conn.close()
    await asyncio.sleep(0.05)
