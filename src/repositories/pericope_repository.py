import sqlite3
from pathlib import Path

from src.database.connection import DatabaseConnection


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

    @staticmethod
    def _candidate_dirs() -> list[Path]:
        """Localiza os diretórios potenciais para o banco de perícopes."""
        src_dir = Path(__file__).resolve().parent.parent  # src
        root_dir = src_dir.parent  # project root
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

    async def get_pericopes_map(self, book_id: int, chapter: int) -> dict[int, str]:
        """
        Consulta os títulos de seções para um livro e capítulo.
        Retorna dicionário mapeando verse_number -> title.
        Retorna dicionário vazio caso o banco não exista ou não haja títulos para o capítulo.
        """
        if not (1 <= book_id <= 66) or chapter < 1:
            return {}

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
            return {}

        return pericopes

    async def close(self) -> None:
        """Encerra a conexão com o banco de perícopes."""
        if self._connection:
            try:
                await self._connection.close()
            except (sqlite3.Error, OSError):
                pass
            self._connection = None
