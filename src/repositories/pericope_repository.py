import sqlite3
from pathlib import Path

from src.database.connection import DatabaseConnection
from src.repositories.commentary_repository import (
    get_auxiliary_db_candidates,
    resolve_auxiliary_db,
)


class PericopeRepository:
    """
    Repositório assíncrono para consulta otimizada de títulos de seções bíblicas (perícopes).
    Opera em modo estritamente somente leitura com consultas parametrizadas (?).
    """

    DEFAULT_DB_FILE = "pericopes.sqlite"

    def __init__(
        self,
        db_connection: DatabaseConnection | None = None,
        db_path: str | None = None,
    ):
        self._custom_conn = db_connection
        self._db_path = db_path or self.DEFAULT_DB_FILE
        self._connection: DatabaseConnection | None = db_connection
        self._cache: dict[tuple[int, int], dict[int, str]] = {}

    _candidate_dirs = staticmethod(get_auxiliary_db_candidates)

    def _resolve_db_connection(self) -> DatabaseConnection:
        if self._connection is None:
            self._connection = resolve_auxiliary_db(
                self._db_path, self.DEFAULT_DB_FILE, self._custom_conn
            )
        return self._connection

    async def get_pericopes_map(self, book_id: int, chapter: int) -> dict[int, str]:
        """
        Consulta os títulos de seções para um livro e capítulo.
        Retorna dicionário mapeando verse_number -> title.
        Retorna dicionário vazio caso o banco não exista ou não haja títulos para o capítulo.
        """
        if not (1 <= book_id <= 66) or chapter < 1:
            return {}

        cache_key = (book_id, chapter)
        if cache_key in self._cache:
            return self._cache[cache_key]

        query = """
            SELECT verse, title
            FROM pericope
            WHERE book_id = ? AND chapter = ?
            ORDER BY verse ASC;
        """

        conn_mgr = self._resolve_db_connection()
        pericopes: dict[int, str] = {}

        try:
            conn = await conn_mgr.get_connection()
            async with conn.execute(query, (book_id, chapter)) as cursor:
                rows = await cursor.fetchall()
            for r in rows:
                pericopes[int(r["verse"])] = str(r["title"]).strip()
        except sqlite3.Error:
            self._cache[cache_key] = {}
            return {}

        self._cache[cache_key] = pericopes
        return pericopes

    async def close(self) -> None:
        """Encerra a conexão com o banco de perícopes."""
        self._cache.clear()
        if self._connection:
            try:
                await self._connection.close()
            except (sqlite3.Error, OSError):
                pass
            self._connection = None
