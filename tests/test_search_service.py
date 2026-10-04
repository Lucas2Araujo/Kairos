import aiosqlite
import pytest

from src.database.connection import DatabaseConnection
from src.services.search_service import (
    SearchContentType,
    SearchResultItem,
    SearchResultsPage,
    SearchService,
)


@pytest.fixture
async def setup_test_db(tmp_path):
    """Cria banco de dados temporário com tabelas FTS5 e dados de teste correspondentes ao schema real."""
    db_file = tmp_path / "test_search.db"

    # Cria tabelas FTS5
    async with aiosqlite.connect(str(db_file)) as db:
        await db.execute(
            """
            CREATE TABLE IF NOT EXISTS hino (
                id INTEGER PRIMARY KEY,
                numero TEXT,
                titulo TEXT,
                categoria TEXT,
                subcategoria TEXT
            );
            """
        )
        await db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS hino_fts USING fts5(
                numero,
                titulo,
                letra,
                categoria,
                subcategoria,
                texto_base,
                autor_letra,
                autor_musica,
                temas,
                textos,
                tokenize='unicode61 remove_diacritics 2'
            );
            """
        )
        await db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS biblia_fts USING fts5(
                book_id UNINDEXED,
                book_name,
                chapter UNINDEXED,
                verse UNINDEXED,
                verse_reference,
                text,
                tokenize='unicode61 remove_diacritics 2'
            );
            """
        )
        await db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS meditacao_fts USING fts5(
                published_at UNINDEXED,
                category UNINDEXED,
                title,
                verse_text,
                verse_reference,
                content,
                author,
                tokenize='unicode61 remove_diacritics 2'
            );
            """
        )
        await db.execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS licao_fts USING fts5(
                day_id UNINDEXED,
                lesson_id UNINDEXED,
                lesson_title,
                day_title,
                date UNINDEXED,
                content,
                tokenize='unicode61 remove_diacritics 2'
            );
            """
        )

        # Inserção de dados de hinos
        await db.execute(
            "INSERT INTO hino (id, numero, titulo, categoria, subcategoria) VALUES (?, ?, ?, ?, ?)",
            (1, "1", "Cantai ao Senhor", "Louvor", "Adoração"),
        )
        await db.execute(
            "INSERT INTO hino (id, numero, titulo, categoria, subcategoria) VALUES (?, ?, ?, ?, ?)",
            (2, "2", "O Senhor é Meu Pastor", "Salmos", "Confiança"),
        )
        await db.execute(
            "INSERT INTO hino_fts (rowid, numero, titulo, letra, categoria, subcategoria, texto_base, autor_letra, autor_musica, temas, textos) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (1, "1", "Cantai ao Senhor", "Cantai ao Senhor um cantico novo terra inteira", "Louvor", "Adoração", "", "", "", "", ""),
        )
        await db.execute(
            "INSERT INTO hino_fts (rowid, numero, titulo, letra, categoria, subcategoria, texto_base, autor_letra, autor_musica, temas, textos) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (2, "2", "O Senhor é Meu Pastor", "O Senhor é meu pastor e nada me faltara", "Salmos", "Confiança", "", "", "", "", ""),
        )

        # Inserção de versículos bíblicos
        await db.execute(
            "INSERT INTO biblia_fts (rowid, book_id, book_name, chapter, verse, verse_reference, text) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (1, 19, "Salmos", 23, 1, "Salmos 23:1", "O SENHOR é o meu pastor; nada me faltará."),
        )
        await db.execute(
            "INSERT INTO biblia_fts (rowid, book_id, book_name, chapter, verse, verse_reference, text) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (2, 43, "João", 3, 16, "João 3:16", "Porque Deus amou ao mundo de tal maneira que deu o seu Filho unigênito."),
        )

        # Inserção de meditação
        await db.execute(
            "INSERT INTO meditacao_fts (rowid, published_at, category, title, verse_text, verse_reference, content, author) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (1, "2026-03-30", "adultos", "Renovação Diária", "O Senhor é meu pastor", "Salmos 23:1", "Deus renova nossas forças a cada amanhecer Senhor da vida.", "Autor Devocional"),
        )

        # Inserção de lição
        await db.execute(
            "INSERT INTO licao_fts (rowid, day_id, lesson_id, lesson_title, day_title, date, content) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (1, "day-1", "lesson-1", "A Criação do Mundo", "Primeiro Dia", "2026-01-01", "No princípio criou Deus os céus e a terra e viu que era bom Senhor."),
        )

        await db.commit()

    return DatabaseConnection(db_path=str(db_file))


@pytest.mark.asyncio
async def test_search_service_detect_available_tables(setup_test_db):
    conn = setup_test_db
    service = SearchService(conn)
    tables = await service.detect_available_tables()
    assert "hino_fts" in tables
    assert "biblia_fts" in tables
    assert "meditacao_fts" in tables
    assert "licao_fts" in tables


@pytest.mark.asyncio
async def test_search_service_missing_tables_fallback(tmp_path):
    """Garante que SearchService lida graciosamente com banco vazio sem tabelas FTS5."""
    empty_db = tmp_path / "empty.db"
    conn = DatabaseConnection(db_path=str(empty_db))
    async with aiosqlite.connect(str(empty_db)) as db:
        await db.execute("CREATE TABLE foo (id INT)")
        await db.commit()

    service = SearchService(conn)
    tables = await service.detect_available_tables()
    assert tables == set()

    top_items, top_total = await service.get_top_unified("teste", limit=5)
    assert top_items == []
    assert top_total == 0

    page_results = await service.search("teste", limit=10, offset=0)
    assert page_results.items == []
    assert page_results.total_count == 0


def test_search_service_sanitize_tokens():
    tokens = SearchService._sanitize_tokens("  João * 3:16 \"amor\" OR 'teste' !@#$%  ")
    assert "João" in tokens or "joão" in [t.lower() for t in tokens]
    assert "3" in tokens
    assert "16" in tokens
    assert "amor" in tokens
    assert "*" not in tokens
    assert '"' not in tokens


def test_search_service_build_fts_query_tiers():
    tiers = SearchService._build_fts_query_tiers("Senhor meu pastor")
    assert len(tiers) == 3
    # Tier 1: exact phrase com aspas
    assert tiers[0][0] == '"Senhor" "meu" "pastor"'
    assert tiers[0][1] == -50.0
    # Tier 2: AND
    assert tiers[1][0] == '"Senhor" AND "meu" AND "pastor"'
    assert tiers[1][1] == -25.0
    # Tier 3: prefix
    assert tiers[2][0] == '"Senhor"* AND "meu"* AND "pastor"*'
    assert tiers[2][1] == 0.0


@pytest.mark.asyncio
async def test_search_service_number_direct_match(setup_test_db):
    """Verifica que número de hino retorna o hino correspondente com prioridade."""
    conn = setup_test_db
    service = SearchService(conn)

    page = await service.search("2", limit=5)
    assert len(page.items) >= 1
    first = page.items[0]
    assert first.content_type == SearchContentType.HINO
    assert first.metadata.get("numero") == "2"


@pytest.mark.asyncio
async def test_search_service_top_unified(setup_test_db):
    """Testa get_top_unified retornando no máximo 5 itens e a contagem total."""
    conn = setup_test_db
    service = SearchService(conn)

    items, total = await service.get_top_unified("Senhor", limit=5)
    assert len(items) <= 5
    assert total >= len(items)
    types_found = {item.content_type for item in items}
    assert SearchContentType.HINO in types_found or SearchContentType.BIBLIA in types_found


@pytest.mark.asyncio
async def test_search_service_pagination(setup_test_db):
    """Testa busca paginada com limites e contagem total."""
    conn = setup_test_db
    service = SearchService(conn)

    page1 = await service.search("Senhor", limit=2, offset=0)
    assert len(page1.items) <= 2
    assert page1.limit == 2
    assert page1.offset == 0
    assert page1.total_count >= 2

    page2 = await service.search("Senhor", limit=2, offset=2)
    assert page2.offset == 2


@pytest.mark.asyncio
async def test_search_service_type_filter(setup_test_db):
    """Testa busca filtrando apenas Bíblia."""
    conn = setup_test_db
    service = SearchService(conn)

    page = await service.search(
        "pastor",
        limit=10,
        offset=0,
        type_filter=SearchContentType.BIBLIA,
    )
    for item in page.items:
        assert item.content_type == SearchContentType.BIBLIA
    assert any("Salmos" in item.title for item in page.items)


@pytest.mark.asyncio
async def test_search_service_counts_by_type(setup_test_db):
    """Testa a agregação de contagens por categoria no resultado de busca."""
    conn = setup_test_db
    service = SearchService(conn)

    page = await service.search("Senhor")
    counts = page.counts_by_type
    assert SearchContentType.HINO.value in counts
    assert SearchContentType.BIBLIA.value in counts
    assert counts[SearchContentType.HINO.value] > 0
