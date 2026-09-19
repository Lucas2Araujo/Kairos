import os
import sqlite3
import threading
from pathlib import Path
from unittest.mock import patch

import pytest

from src.database.connection import (
    DatabaseConnection,
    _AsyncSqliteCompatConnection,
    _AsyncSqliteCompatCursor,
)
from src.repositories.hino_repository import HinoRepository


def test_resolve_db_path_memory():
    """Valida que :memory: é mantido inalterado."""
    db_conn = DatabaseConnection(db_path=":memory:")
    assert db_conn.db_path == ":memory:"


def test_resolve_db_path_default():
    """Valida que o caminho padrão resolve para o arquivo em disco existente."""
    db_conn = DatabaseConnection()
    assert db_conn.db_path.endswith("hinario.db")
    assert os.path.isabs(db_conn.db_path)
    assert os.path.exists(db_conn.db_path)


def test_resolve_db_path_env_variable(monkeypatch, tmp_path):
    """Valida que variável de ambiente de banco tem prioridade se o arquivo existir."""
    dummy_db = tmp_path / "env_hinario.db"
    dummy_db.write_text("dummy content")

    monkeypatch.setenv("HINARIO_DB_PATH", str(dummy_db))
    resolved = DatabaseConnection._resolve_db_path("hinario.db")
    assert resolved == str(dummy_db)


def test_resolve_db_path_android_copy(monkeypatch, tmp_path):
    """Valida a cópia para o diretório gravável do usuário quando em ambiente Android."""
    files_dir = tmp_path / "android_files"
    files_dir.mkdir()

    monkeypatch.setenv("FILES_DIR", str(files_dir))
    monkeypatch.setenv("ANDROID_ARGUMENT", "1")

    resolved = DatabaseConnection._resolve_db_path("hinario.db")

    expected_file = files_dir / "hinario.db"
    assert resolved == str(expected_file)
    assert expected_file.exists()


@pytest.mark.asyncio
async def test_real_db_connection_and_hino_table():
    """Valida que a conexão com o banco real resolvida pelo DatabaseConnection encontra a tabela hino."""
    db_conn = DatabaseConnection()
    try:
        repo = HinoRepository(db_conn)
        hinos = await repo.get_all()
        assert isinstance(hinos, list)
        assert len(hinos) > 0
    finally:
        await db_conn.close()


@pytest.mark.asyncio
async def test_read_only_connection_does_not_initialize_tables():
    """Valida que bancos abertos com read_only=True não tentam criar tabelas nem FTS."""
    db_conn = DatabaseConnection(db_path=":memory:", read_only=True)
    try:
        conn = await db_conn.get_connection()
        async with conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table';"
        ) as cursor:
            tables = [row[0] for row in await cursor.fetchall()]
        assert "hino_fts" not in tables
        assert "preferencias" not in tables
    finally:
        await db_conn.close()


@pytest.mark.asyncio
async def test_non_hymnal_db_does_not_create_hino_fts():
    """Valida que um banco sem tabela hino não cria hino_fts mesmo com read_only=False."""
    db_conn = DatabaseConnection(db_path=":memory:", read_only=False)
    try:
        conn = await db_conn.get_connection()
        async with conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table';"
        ) as cursor:
            tables = [row[0] for row in await cursor.fetchall()]
        assert "hino_fts" not in tables
        assert "preferencias" in tables
    finally:
        await db_conn.close()


@pytest.mark.asyncio
async def test_busy_timeout_pragma_applied():
    """Valida que PRAGMA busy_timeout = 30000 foi aplicado com sucesso na conexão."""
    db_conn = DatabaseConnection(db_path=":memory:")
    try:
        conn = await db_conn.get_connection()
        async with conn.execute("PRAGMA busy_timeout;") as cursor:
            row = await cursor.fetchone()
            assert row is not None
            assert row[0] == 30000
    finally:
        await db_conn.close()


@pytest.mark.asyncio
async def test_concurrent_get_connection():
    """Valida que múltiplas chamadas simultâneas a get_connection retornam com segurança a mesma conexão."""
    import asyncio

    db_conn = DatabaseConnection(db_path=":memory:")
    try:
        conns = await asyncio.gather(*[db_conn.get_connection() for _ in range(10)])
        assert len(conns) == 10
        # Todas as referências devem ser idênticas à mesma conexão
        for c in conns:
            assert c is conns[0]
    finally:
        await db_conn.close()


@pytest.mark.asyncio
async def test_async_sqlite_compat_connection_thread_pool():
    """Valida que _AsyncSqliteCompatConnection e cursor executam chamadas de I/O em thread pool."""
    main_thread = threading.get_ident()

    raw_conn = sqlite3.connect(":memory:", check_same_thread=False)
    raw_conn.create_function("get_thread_id", 0, threading.get_ident)

    conn = _AsyncSqliteCompatConnection(raw_conn)
    try:
        await conn.execute("CREATE TABLE items (id INT, name TEXT);")
        await conn.executemany("INSERT INTO items VALUES (?, ?);", [(1, "Item A"), (2, "Item B")])
        await conn.commit()

        # Test context manager
        async with conn.execute("SELECT id, name FROM items ORDER BY id;") as cursor:
            rows = await cursor.fetchall()
            assert len(rows) == 2
            assert rows[0][1] == "Item A"

        # Test fetchone
        cur = await conn.execute("SELECT name FROM items WHERE id = ?;", (2,))
        row = await cur.fetchone()
        assert row is not None
        assert row[0] == "Item B"

        # Test async iteration
        collected = []
        async for r in await conn.execute("SELECT id FROM items;"):
            collected.append(r[0])
        assert collected == [1, 2]

        # Ensure execution was dispatched to background worker thread(s)
        cur_thread = await conn.execute("SELECT get_thread_id();")
        row_thread = await cur_thread.fetchone()
        assert row_thread is not None
        assert row_thread[0] != main_thread, "I/O deve ter rodado em thread separada da UI"
    finally:
        await conn.close()


@pytest.mark.asyncio
async def test_wal_resilience_locked_vs_corrupt(tmp_path):
    """
    Valida que erros transitórios de contenção ('database is locked') NÃO disparam quarentena de WAL,
    mas corrupção real ('database disk image is malformed') isola o arquivo adequadamente.
    """
    db_file = tmp_path / "test_app.db"
    wal_file = tmp_path / "test_app.db-wal"
    shm_file = tmp_path / "test_app.db-shm"

    # Cria os arquivos simulados
    db_file.write_text("dummy database content")
    wal_file.write_text("dummy wal content")
    shm_file.write_text("dummy shm content")

    db_conn = DatabaseConnection(db_path=str(db_file))

    # 1. Simular erro de Lock / Concorrência
    with patch("sqlite3.connect", side_effect=sqlite3.OperationalError("database is locked")):
        is_corrupted = await db_conn._is_wal_corrupted()
        assert is_corrupted is False, "Lock transitório nunca deve ser tratado como corrupção de WAL"

        # Executa recuperação: WAL NÃO deve ser quarentenado
        await db_conn._recover_stale_wal_if_needed()
        assert wal_file.exists(), "WAL file deve ser preservado em caso de contenção de lock"
        assert not Path(f"{db_file}-wal.corrupt").exists(), "Nenhum arquivo .corrupt deve ser gerado por lock"

    # 2. Simular erro de Corrupção Real
    with patch("sqlite3.connect", side_effect=sqlite3.DatabaseError("database disk image is malformed")):
        is_corrupted = await db_conn._is_wal_corrupted()
        assert is_corrupted is True, "Database malformed deve ser diagnosticado como corrupção real"

        # Executa recuperação: WAL DEVE ser quarentenado
        await db_conn._recover_stale_wal_if_needed()
        assert not wal_file.exists(), "WAL corrompido deve ser movido para quarentena"
        corrupt_backup = Path(f"{db_file}-wal.corrupt")
        assert corrupt_backup.exists(), "Arquivo .corrupt deve ser gerado para quarentena do WAL"
        assert corrupt_backup.read_text() == "dummy wal content"


@pytest.mark.asyncio
async def test_copy_seed_file_async(tmp_path):
    """Valida a cópia assíncrona não-bloqueante de arquivo de seed."""
    seed_file = tmp_path / "seed.db"
    dest_file = tmp_path / "destination.db"
    seed_file.write_bytes(b"SQLite seed database content")

    await DatabaseConnection._copy_seed_file(seed_file, dest_file)

    assert dest_file.exists()
    assert dest_file.read_bytes() == b"SQLite seed database content"


def test_prepare_user_data_copy_outdated_sync(monkeypatch, tmp_path):
    """Valida que quando um banco antigo não tem link_video, ele é atualizado com a semente preservando favoritos."""
    user_dir = tmp_path / "user_dir"
    user_dir.mkdir()
    monkeypatch.setattr(DatabaseConnection, "_get_user_data_dir", lambda: user_dir)

    target_db = user_dir / "hinario_antigo.db"
    seed_db = tmp_path / "seed_antigo.db"

    # Cria target desatualizado com favorito do usuário
    conn_t = sqlite3.connect(target_db)
    conn_t.execute("CREATE TABLE hino (id INTEGER PRIMARY KEY, numero TEXT, titulo TEXT, link_video TEXT);")
    conn_t.execute("INSERT INTO hino (numero, titulo, link_video) VALUES ('1', 'Sem Link', '');")
    conn_t.execute("CREATE TABLE favorito (hino_id INTEGER PRIMARY KEY, data_favoritado DATETIME);")
    conn_t.execute("INSERT INTO favorito (hino_id, data_favoritado) VALUES (1, '2026-01-01 10:00:00');")
    conn_t.commit()
    conn_t.close()

    # Cria seed atualizado com link
    conn_s = sqlite3.connect(seed_db)
    conn_s.execute("CREATE TABLE hino (id INTEGER PRIMARY KEY, numero TEXT, titulo TEXT, link_video TEXT);")
    conn_s.execute("INSERT INTO hino (numero, titulo, link_video) VALUES ('1', 'Com Link', 'https://youtube.com/watch?v=abc');")
    conn_s.execute("CREATE TABLE favorito (hino_id INTEGER PRIMARY KEY, data_favoritado DATETIME);")
    conn_s.commit()
    conn_s.close()

    assert DatabaseConnection._is_database_outdated(target_db, seed_db, "hinario_antigo.db") is True

    result_path = DatabaseConnection._prepare_user_data_copy(seed_db, "hinario_antigo.db")
    assert result_path == target_db

    # Verifica se os links foram atualizados E os favoritos preservados
    conn_res = sqlite3.connect(target_db)
    hino_row = conn_res.execute("SELECT numero, link_video FROM hino WHERE numero = '1'").fetchone()
    fav_row = conn_res.execute("SELECT hino_id FROM favorito WHERE hino_id = 1").fetchone()
    conn_res.close()

    assert hino_row[1] == "https://youtube.com/watch?v=abc"
    assert fav_row is not None and fav_row[0] == 1


