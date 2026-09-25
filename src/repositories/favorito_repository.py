import asyncio
import inspect
import logging
import sqlite3
from collections.abc import Callable
from typing import Any

from src.database.connection import DatabaseConnection
from src.models.hino import Hino


logger = logging.getLogger(__name__)


class FavoritoRepository:
    """
    Repositório assíncrono para manipulação da tabela de Favoritos (favorito).
    Aplica o Repository Pattern com aiosqlite e queries parametrizadas.
    """

    def __init__(
        self,
        db_connection: DatabaseConnection,
        on_change_sync_callback: Callable[[str, int, bool], Any] | None = None,
    ):
        self.db_connection = db_connection
        self.on_change_sync_callback = on_change_sync_callback

    async def _safe_rollback(self) -> None:
        try:
            conn = await self.db_connection.get_connection()
            await conn.rollback()
        except sqlite3.Error:
            pass

    async def add_favorito(self, hino_id: int) -> bool:
        """Adiciona um hino aos favoritos se ainda não estiver presente com resiliência a locks."""
        query = "INSERT OR IGNORE INTO favorito (hino_id) VALUES (?)"
        max_retries = 3
        for attempt in range(max_retries):
            try:
                conn = await self.db_connection.get_connection()
                async with conn.execute(query, (hino_id,)) as cursor:
                    success = cursor.rowcount > 0
                await conn.commit()
                if success and self.on_change_sync_callback:
                    try:
                        res = self.on_change_sync_callback("hymn", hino_id, False)
                        if inspect.iscoroutine(res):
                            asyncio.create_task(res)
                    except Exception as exc:
                        logger.warning("Erro no callback de sincronização: %s", exc)
                return success
            except sqlite3.OperationalError as exc:
                await self._safe_rollback()
                is_lock = "locked" in str(exc).lower() or "busy" in str(exc).lower()
                if is_lock and attempt < max_retries - 1:
                    await asyncio.sleep(0.05 * (2 ** attempt))
                    continue
                return False
            except sqlite3.Error as exc:
                logger.warning("Erro em FavoritoRepository: %s", exc)
                await self._safe_rollback()
                return False
        return False

    async def remove_favorito(self, hino_id: int) -> bool:
        """Remove um hino dos favoritos com resiliência a locks."""
        query = "DELETE FROM favorito WHERE hino_id = ?"
        max_retries = 3
        for attempt in range(max_retries):
            try:
                conn = await self.db_connection.get_connection()
                async with conn.execute(query, (hino_id,)) as cursor:
                    success = cursor.rowcount > 0
                await conn.commit()
                if success and self.on_change_sync_callback:
                    try:
                        res = self.on_change_sync_callback("hymn", hino_id, True)
                        if inspect.iscoroutine(res):
                            asyncio.create_task(res)
                    except Exception as exc:
                        logger.warning("Erro no callback de sincronização: %s", exc)
                return success
            except sqlite3.OperationalError as exc:
                await self._safe_rollback()
                is_lock = "locked" in str(exc).lower() or "busy" in str(exc).lower()
                if is_lock and attempt < max_retries - 1:
                    await asyncio.sleep(0.05 * (2 ** attempt))
                    continue
                return False
            except sqlite3.Error as exc:
                logger.warning("Erro em FavoritoRepository: %s", exc)
                await self._safe_rollback()
                return False
        return False

    async def is_favorito(self, hino_id: int) -> bool:
        """Verifica se um hino está marcado como favorito."""
        query = "SELECT 1 FROM favorito WHERE hino_id = ?"
        try:
            conn = await self.db_connection.get_connection()
            async with conn.execute(query, (hino_id,)) as cursor:
                row = await cursor.fetchone()
                return row is not None
        except sqlite3.Error as exc:
            logger.warning("Erro em is_favorito: %s", exc)
            return False

    async def get_favoritos(self) -> list[Hino]:
        """Retorna a lista de todos os hinos favoritados pelo usuário."""
        query = """
            SELECT h.id, h.numero, h.titulo 
            FROM hino h
            INNER JOIN favorito f ON h.id = f.hino_id
            ORDER BY f.data_favoritado DESC
        """
        try:
            conn = await self.db_connection.get_connection()
            async with conn.execute(query) as cursor:
                rows = await cursor.fetchall()

            hinos: list[Hino] = []
            for row in rows:
                hinos.append(
                    Hino(id=row["id"], numero=str(row["numero"]), titulo=str(row["titulo"]))
                )

            return hinos
        except sqlite3.Error as exc:
            logger.warning("Erro em get_favoritos: %s", exc)
            return []
