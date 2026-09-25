import asyncio
import aiosqlite
import pytest
from src.database.connection import DatabaseConnection
from src.repositories.commentary_repository import CommentaryRepository


@pytest.fixture
async def commentary_test_db(tmp_path):
    db_file = tmp_path / "commentaries.sqlite"
    async with aiosqlite.connect(str(db_file)) as db:
        await db.execute("""
            CREATE TABLE authors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                slug TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                short_name TEXT,
                description TEXT,
                is_public_domain INTEGER NOT NULL DEFAULT 1
            );
        """)
        await db.execute("""
            CREATE TABLE commentaries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                author_id INTEGER NOT NULL REFERENCES authors(id),
                book_id INTEGER NOT NULL,
                chapter INTEGER NOT NULL,
                verse_start INTEGER NOT NULL,
                verse_end INTEGER NOT NULL,
                title TEXT,
                content TEXT NOT NULL
            );
        """)
        await db.execute("""
            INSERT INTO authors (id, slug, name, short_name, description, is_public_domain)
            VALUES (1, 'matthew-henry', 'Matthew Henry', 'M. Henry', 'Comentário Expositivo', 1);
        """)
        await db.execute("""
            INSERT INTO authors (id, slug, name, short_name, description, is_public_domain)
            VALUES (2, 'john-wesley', 'John Wesley', 'J. Wesley', 'Notas Explicativas', 1);
        """)
        # Comentário para versículo único (Gn 1:1)
        await db.execute("""
            INSERT INTO commentaries (author_id, book_id, chapter, verse_start, verse_end, title, content)
            VALUES (1, 1, 1, 1, 1, 'A Criação', 'No princípio Deus formou tudo do nada.');
        """)
        # Comentário que abrange intervalo de versículos (Gn 1:1-3)
        await db.execute("""
            INSERT INTO commentaries (author_id, book_id, chapter, verse_start, verse_end, title, content)
            VALUES (2, 1, 1, 1, 3, 'Os Três Primeiros Versos', 'A obra inicial da criação e da luz.');
        """)
        await db.commit()

    conn_mgr = DatabaseConnection(db_path=str(db_file), read_only=True)
    yield conn_mgr
    await conn_mgr.close()


@pytest.mark.asyncio
async def test_get_authors(commentary_test_db):
    repo = CommentaryRepository(db_connection=commentary_test_db)
    authors = await repo.get_authors()
    assert len(authors) == 2
    names = [a.name for a in authors]
    assert "Matthew Henry" in names
    assert "John Wesley" in names


@pytest.mark.asyncio
async def test_get_commentaries_exact_and_range(commentary_test_db):
    repo = CommentaryRepository(db_connection=commentary_test_db)

    # Versículo 1 deve retornar tanto Matthew Henry (1:1) quanto Wesley (1:1-3)
    v1_comms = await repo.get_commentaries(book_id=1, chapter=1, verse=1)
    assert len(v1_comms) == 2

    # Versículo 2 deve retornar apenas Wesley (1:1-3) pelo range coverage
    v2_comms = await repo.get_commentaries(book_id=1, chapter=1, verse=2)
    assert len(v2_comms) == 1
    assert v2_comms[0].author_name == "John Wesley"
    assert v2_comms[0].range_display == "vv. 1-3"

    # Versículo 4 não deve retornar nenhum
    v4_comms = await repo.get_commentaries(book_id=1, chapter=1, verse=4)
    assert len(v4_comms) == 0


@pytest.mark.asyncio
async def test_get_commentaries_filter_by_author(commentary_test_db):
    repo = CommentaryRepository(db_connection=commentary_test_db)
    comms = await repo.get_commentaries(book_id=1, chapter=1, verse=1, author_id=1)
    assert len(comms) == 1
    assert comms[0].author_slug == "matthew-henry"


@pytest.mark.asyncio
async def test_get_commentaries_for_verses_batch(commentary_test_db):
    repo = CommentaryRepository(db_connection=commentary_test_db)
    res_map = await repo.get_commentaries_for_verses(book_id=1, chapter=1, verses=[1, 2, 5])
    assert 1 in res_map
    assert 2 in res_map
    assert 5 in res_map
    assert len(res_map[1]) == 2
    assert len(res_map[2]) == 1
    assert len(res_map[5]) == 0
