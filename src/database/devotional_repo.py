from __future__ import annotations

import aiosqlite
from typing import Sequence

from src.database.connection import DatabaseConnection
from src.models.devotional import Devotional


class DevotionalRepository:
    """
    Repositório assíncrono para persistência e cache local de meditações diárias.
    Manipula a tabela 'cached_devotionals' em SQLite usando DatabaseConnection.
    Suporta múltiplos tipos de devocional através da coluna 'category'.
    """

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self._table_initialized = False

    async def _ensure_table(self, conn: aiosqlite.Connection) -> None:
        """Garante a existência da tabela cached_devotionals com chave primária composta (published_at, category)."""
        if self._table_initialized:
            return

        # Verifica se a tabela já existe
        table_exists = False
        async with conn.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='cached_devotionals';") as cursor:
            row = await cursor.fetchone()
            if row and row[0]:
                table_exists = True
                existing_sql = row[0]

        if not table_exists:
            await conn.execute("""
                CREATE TABLE cached_devotionals (
                    published_at TEXT NOT NULL,
                    title TEXT NOT NULL,
                    verse_text TEXT NOT NULL,
                    verse_reference TEXT NOT NULL,
                    content TEXT NOT NULL,
                    category TEXT NOT NULL DEFAULT 'jovem',
                    author TEXT DEFAULT '',
                    source_url TEXT DEFAULT '',
                    cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (published_at, category)
                );
            """)
        else:
            # Migração caso a tabela existente não tenha a chave composta (published_at, category)
            if "PRIMARY KEY (published_at, category)" not in existing_sql and "PRIMARY KEY(published_at, category)" not in existing_sql and "PRIMARY KEY(published_at,category)" not in existing_sql:
                await conn.execute("""
                    CREATE TABLE cached_devotionals_v2 (
                        published_at TEXT NOT NULL,
                        title TEXT NOT NULL,
                        verse_text TEXT NOT NULL,
                        verse_reference TEXT NOT NULL,
                        content TEXT NOT NULL,
                        category TEXT NOT NULL DEFAULT 'jovem',
                        author TEXT DEFAULT '',
                        source_url TEXT DEFAULT '',
                        cached_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        PRIMARY KEY (published_at, category)
                    );
                """)
                # Verifica se 'category' existia na tabela anterior
                async with conn.execute("PRAGMA table_info(cached_devotionals);") as cur:
                    cols = [r[1] for r in await cur.fetchall()]

                category_col = "COALESCE(category, 'jovem')" if "category" in cols else "'jovem'"
                author_col = "COALESCE(author, '')" if "author" in cols else "''"
                source_col = "COALESCE(source_url, '')" if "source_url" in cols else "''"
                cached_at_col = "COALESCE(cached_at, CURRENT_TIMESTAMP)" if "cached_at" in cols else "CURRENT_TIMESTAMP"

                await conn.execute(f"""
                    INSERT OR IGNORE INTO cached_devotionals_v2 (
                        published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                    ) SELECT published_at, title, verse_text, verse_reference, content, {category_col}, {author_col}, {source_col}, {cached_at_col}
                    FROM cached_devotionals;
                """)
                await conn.execute("DROP TABLE cached_devotionals;")
                await conn.execute("ALTER TABLE cached_devotionals_v2 RENAME TO cached_devotionals;")

        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_devotionals_published_at 
            ON cached_devotionals(published_at DESC);
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_devotionals_category 
            ON cached_devotionals(category, published_at DESC);
        """)
        await conn.commit()
        self._table_initialized = True

    @staticmethod
    def _row_to_devotional(row: aiosqlite.Row) -> Devotional:
        """Mapeia uma linha do SQLite para a entidade Devotional."""
        keys = row.keys() if hasattr(row, "keys") else []
        return Devotional(
            published_at=row["published_at"],
            title=row["title"],
            verse_text=row["verse_text"],
            verse_reference=row["verse_reference"],
            content=row["content"],
            category=row["category"] if "category" in keys and row["category"] else "jovem",
            author=row["author"] or "",
            source_url=row["source_url"] or "",
            cached_at=str(row["cached_at"]) if row["cached_at"] else None,
        )

    async def get_by_date(self, published_at: str, category: str = "jovem") -> Devotional | None:
        """Recupera uma meditação do cache pela data de publicação (YYYY-MM-DD) e categoria."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        async with conn.execute(
            """
            SELECT published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
            FROM cached_devotionals
            WHERE published_at = ? AND category = ?
            LIMIT 1;
            """,
            (published_at.strip(), category.lower()),
        ) as cursor:
            row = await cursor.fetchone()
            if row:
                return self._row_to_devotional(row)
        return None

    async def save(self, devotional: Devotional) -> bool:
        """Salva ou atualiza (upsert) uma meditação diária no cache local por (published_at, category)."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        try:
            await conn.execute(
                """
                INSERT INTO cached_devotionals (
                    published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
                ON CONFLICT(published_at, category) DO UPDATE SET
                    title = excluded.title,
                    verse_text = excluded.verse_text,
                    verse_reference = excluded.verse_reference,
                    content = excluded.content,
                    author = excluded.author,
                    source_url = excluded.source_url,
                    cached_at = datetime('now');
                """,
                (
                    devotional.published_at.strip(),
                    devotional.title.strip(),
                    devotional.verse_text.strip(),
                    devotional.verse_reference.strip(),
                    devotional.content.strip(),
                    (devotional.category or "jovem").strip().lower(),
                    devotional.author.strip(),
                    devotional.source_url.strip(),
                ),
            )
            await conn.commit()
            return True
        except Exception:
            try:
                await conn.rollback()
            except Exception:
                pass
            return False

    async def get_recent(self, limit: int = 7, category: str = "jovem") -> list[Devotional]:
        """Retorna as meditações em cache mais recentes de uma categoria ordenadas por data decrescente."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        if category:
            query = """
                SELECT published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                FROM cached_devotionals
                WHERE category = ?
                ORDER BY published_at DESC
                LIMIT ?;
            """
            params: tuple = (category.lower(), limit)
        else:
            query = """
                SELECT published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                FROM cached_devotionals
                ORDER BY published_at DESC
                LIMIT ?;
            """
            params = (limit,)

        async with conn.execute(query, params) as cursor:
            rows = await cursor.fetchall()
            return [self._row_to_devotional(r) for r in rows]

    async def get_all_cached(self, category: str | None = None) -> list[Devotional]:
        """Retorna todas as meditações salvas localmente, opcionalmente filtradas por categoria."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        if category:
            query = """
                SELECT published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                FROM cached_devotionals
                WHERE category = ?
                ORDER BY published_at DESC;
            """
            params: tuple = (category.lower(),)
        else:
            query = """
                SELECT published_at, title, verse_text, verse_reference, content, category, author, source_url, cached_at
                FROM cached_devotionals
                ORDER BY published_at DESC;
            """
            params = ()

        async with conn.execute(query, params) as cursor:
            rows = await cursor.fetchall()
            return [self._row_to_devotional(r) for r in rows]

    async def delete_by_date(self, published_at: str, category: str = "jovem") -> bool:
        """Remove uma meditação específica do cache pela sua data e categoria."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        try:
            cursor = await conn.execute(
                "DELETE FROM cached_devotionals WHERE published_at = ? AND category = ?;",
                (published_at.strip(), category.lower()),
            )
            changes = cursor.rowcount
            await cursor.close()
            await conn.commit()
            return changes > 0
        except Exception:
            try:
                await conn.rollback()
            except Exception:
                pass
            return False

    async def delete_older_than(self, days: int = 7, category: str | None = None) -> int:
        """
        Remove do cache meditações com data de publicação anterior a X dias.
        Opcionalmente filtra por categoria ou purga de todas.
        Usa cálculo relativo SQLite: DATE('now', '-X days').
        Retorna a quantidade de registros expurgados.
        """
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        modifier = f"-{int(days)} days"
        try:
            if category:
                cursor = await conn.execute(
                    "DELETE FROM cached_devotionals WHERE published_at < DATE('now', ?) AND category = ?;",
                    (modifier, category.lower()),
                )
            else:
                cursor = await conn.execute(
                    "DELETE FROM cached_devotionals WHERE published_at < DATE('now', ?);",
                    (modifier,),
                )
            deleted_count = cursor.rowcount
            await cursor.close()
            await conn.commit()
            return deleted_count
        except Exception:
            try:
                await conn.rollback()
            except Exception:
                pass
            return 0

    async def clear_all(self, category: str | None = None) -> int:
        """Limpa completamente as meditações armazenadas no cache (todas ou de uma categoria)."""
        conn = await self.db_connection.get_connection()
        await self._ensure_table(conn)

        try:
            if category:
                cursor = await conn.execute("DELETE FROM cached_devotionals WHERE category = ?;", (category.lower(),))
            else:
                cursor = await conn.execute("DELETE FROM cached_devotionals;")
            count = cursor.rowcount
            await cursor.close()
            await conn.commit()
            return count
        except Exception:
            try:
                await conn.rollback()
            except Exception:
                pass
            return 0
