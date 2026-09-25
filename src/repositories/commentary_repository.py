import asyncio
import os
from pathlib import Path
from typing import Any, Optional

from src.database.connection import DatabaseConnection
from src.models.commentary import CommentaryAuthor, CommentaryItem


class CommentaryRepository:
    """
    Repositório assíncrono para comentários bíblicos em domínio público.
    Opera estritamente em modo leitura com consultas parametrizadas (?) e tratamento seguro.
    """

    DEFAULT_DB_FILE = "commentaries.sqlite"

    def __init__(
        self,
        db_connection: DatabaseConnection | None = None,
        db_path: str | None = None,
    ):
        self._custom_conn = db_connection
        self._db_path = db_path or self.DEFAULT_DB_FILE
        self._connection: DatabaseConnection | None = db_connection

    @staticmethod
    def _candidate_dirs() -> list[Path]:
        """Localiza diretórios potenciais para o banco de comentários."""
        src_dir = Path(__file__).resolve().parent.parent
        root_dir = src_dir.parent
        user_dir = DatabaseConnection._get_user_data_dir()

        return [
            root_dir / "assets",
            user_dir / "modules",
            root_dir / "assets" / "modules",
            src_dir / "assets",
            user_dir,
            root_dir,
        ]

    def _resolve_db_connection(self) -> DatabaseConnection:
        if self._connection is not None:
            return self._connection

        p = Path(self._db_path)
        if p.exists():
            self._connection = DatabaseConnection(db_path=str(p), read_only=True)
            return self._connection

        for candidate_dir in self._candidate_dirs():
            candidate_file = candidate_dir / self.DEFAULT_DB_FILE
            if candidate_file.exists():
                self._connection = DatabaseConnection(
                    db_path=str(candidate_file), read_only=True
                )
                return self._connection

        self._connection = DatabaseConnection(
            db_path=self._db_path, read_only=True
        )
        return self._connection

    async def has_commentaries_db(self) -> bool:
        """Verifica se o banco de comentários está presente no ambiente."""
        if self._custom_conn is not None:
            return True
        for candidate_dir in self._candidate_dirs():
            if (candidate_dir / self.DEFAULT_DB_FILE).exists():
                return True
        return False

    async def get_authors(self) -> list[CommentaryAuthor]:
        """Lista todos os autores cadastrados."""
        conn_mgr = self._resolve_db_connection()
        query = """
            SELECT id, slug, name, short_name, description, is_public_domain
            FROM authors
            ORDER BY name ASC;
        """
        authors: list[CommentaryAuthor] = []
        try:
            conn = await conn_mgr.get_connection()
            async with conn.execute(query) as cursor:
                rows = await cursor.fetchall()
            for r in rows:
                authors.append(
                    CommentaryAuthor(
                        id=int(r["id"]),
                        slug=str(r["slug"]),
                        name=str(r["name"]),
                        short_name=str(r["short_name"]) if r["short_name"] else None,
                        description=str(r["description"]) if r["description"] else None,
                        is_public_domain=bool(r["is_public_domain"]),
                    )
                )
        except Exception:
            pass
        return authors

    async def get_available_authors(self) -> list[CommentaryAuthor]:
        """Alias para compatibilidade com a UI."""
        return await self.get_authors()

    async def get_commentaries_for_verse(
        self,
        book_id: int,
        chapter: int,
        verse: int,
        author_slug: str | None = None,
        author_id: int | None = None,
    ) -> list[CommentaryItem]:
        """
        Consulta comentários para um versículo específico, permitindo filtrar por slug ou ID de autor.
        """
        if not (1 <= book_id <= 66) or chapter < 1 or verse < 1:
            return []

        conditions = [
            "c.book_id = ?",
            "c.chapter = ?",
            "c.verse_start <= ?",
            "c.verse_end >= ?",
        ]
        params: list[Any] = [book_id, chapter, verse, verse]

        if author_slug:
            conditions.append("a.slug = ?")
            params.append(author_slug)
        elif author_id is not None:
            conditions.append("c.author_id = ?")
            params.append(author_id)

        where_clause = " AND ".join(conditions)
        query = f"""
            SELECT c.id, c.author_id, a.name as author_name, a.slug as author_slug,
                   c.book_id, c.chapter, c.verse_start, c.verse_end, c.title, c.content
            FROM commentaries c
            JOIN authors a ON a.id = c.author_id
            WHERE {where_clause}
            ORDER BY a.name ASC, c.verse_start ASC;
        """

        conn_mgr = self._resolve_db_connection()
        items: list[CommentaryItem] = []
        try:
            conn = await conn_mgr.get_connection()
            async with conn.execute(query, params) as cursor:
                rows = await cursor.fetchall()

            for r in rows:
                items.append(
                    CommentaryItem(
                        id=int(r["id"]),
                        author_id=int(r["author_id"]),
                        author_name=str(r["author_name"]),
                        author_slug=str(r["author_slug"]),
                        book_id=int(r["book_id"]),
                        chapter=int(r["chapter"]),
                        verse_start=int(r["verse_start"]),
                        verse_end=int(r["verse_end"]),
                        title=str(r["title"]) if r["title"] else None,
                        content=str(r["content"]).strip(),
                    )
                )
        except Exception:
            pass
        return items

    async def get_commentaries(
        self,
        book_id: int,
        chapter: int,
        verse: int,
        author_id: int | None = None,
    ) -> list[CommentaryItem]:
        """
        Consulta comentários bíblicos abrangendo um versículo específico.
        Suporta cobertura de intervalos (ex: versículo 1 a 4).
        """
        return await self.get_commentaries_for_verse(
            book_id=book_id,
            chapter=chapter,
            verse=verse,
            author_id=author_id,
        )

    async def get_commentaries_for_verses(
        self,
        book_id: int,
        chapter: int,
        verses: list[int],
        author_id: int | None = None,
    ) -> dict[int, list[CommentaryItem]]:
        """
        Consulta comentários em lote para uma lista de versículos (máx 10 versículos por chamada).
        """
        if not (1 <= book_id <= 66) or chapter < 1 or not verses:
            return {}

        sanitized_verses = sorted({int(v) for v in verses if v >= 1})[:10]
        results_map: dict[int, list[CommentaryItem]] = {v: [] for v in sanitized_verses}

        tasks = [
            self.get_commentaries(book_id, chapter, v, author_id=author_id)
            for v in sanitized_verses
        ]
        batch_results = await asyncio.gather(*tasks, return_exceptions=True)

        for v, res in zip(sanitized_verses, batch_results):
            if isinstance(res, list):
                results_map[v] = res

        return results_map
