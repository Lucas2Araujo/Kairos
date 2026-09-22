from __future__ import annotations

import asyncio
import logging
import os
from datetime import date, timedelta
from typing import Any

import aiosqlite

from src.config import (
    AUTH_SUPABASE_ANON_KEY,
    AUTH_SUPABASE_URL,
    DEVOTIONAL_SUPABASE_ANON_KEY,
    DEVOTIONAL_SUPABASE_URL,
)
from src.database.connection import DatabaseConnection

logger = logging.getLogger(__name__)

SUPABASE_URL = AUTH_SUPABASE_URL or DEVOTIONAL_SUPABASE_URL
SUPABASE_KEY = AUTH_SUPABASE_ANON_KEY or DEVOTIONAL_SUPABASE_ANON_KEY


class ReadingService:
    """
    Serviço modular para registro de leitura concluída e cálculo de ofensiva (streak).
    Persistência local offline-first (SQLite) e sincronização assíncrona opcional com Supabase.
    """

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self._schema_initialized = False

    async def ensure_schema(self) -> None:
        """Garante a existência da tabela reading_log no banco local."""
        if self._schema_initialized:
            return

        conn = await self.db_connection.get_connection()
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS reading_log (
                date TEXT NOT NULL,
                category TEXT NOT NULL,
                marked_at TEXT DEFAULT (datetime('now')),
                PRIMARY KEY (date, category)
            );
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_reading_log_date
            ON reading_log(date DESC);
        """)
        await conn.commit()
        self._schema_initialized = True

    async def mark_as_read(
        self,
        target_date: str,
        category: str,
        device_id: str | None = None,
    ) -> bool:
        """
        Registra uma leitura como concluída para uma data e categoria específicas.
        Retorna True se foi inserida ou já existia.
        """
        await self.ensure_schema()
        conn = await self.db_connection.get_connection()
        await conn.execute(
            """
            INSERT OR IGNORE INTO reading_log (date, category)
            VALUES (?, ?);
            """,
            (target_date, category.lower()),
        )
        await conn.commit()

        if device_id:
            asyncio.create_task(self.sync_to_supabase(device_id))

        return True

    async def is_read(self, target_date: str, category: str | None = None) -> bool:
        """Verifica se há leitura registrada para a data (em qualquer categoria ou numa específica)."""
        await self.ensure_schema()
        conn = await self.db_connection.get_connection()
        if category:
            query = "SELECT 1 FROM reading_log WHERE date = ? AND category = ? LIMIT 1;"
            params = (target_date, category.lower())
        else:
            query = "SELECT 1 FROM reading_log WHERE date = ? LIMIT 1;"
            params = (target_date,)

        async with conn.execute(query, params) as cur:
            row = await cur.fetchone()
            return row is not None

    async def get_recent_read_dates(self, days: int = 14) -> set[str]:
        """Retorna conjunto de datas (ISO 'YYYY-MM-DD') com leituras concluídas nos últimos N dias."""
        await self.ensure_schema()
        start_date = (date.today() - timedelta(days=days)).isoformat()
        conn = await self.db_connection.get_connection()
        async with conn.execute(
            "SELECT DISTINCT date FROM reading_log WHERE date >= ? ORDER BY date DESC;",
            (start_date,),
        ) as cur:
            rows = await cur.fetchall()
            return {row[0] for row in rows if row and row[0]}

    async def get_current_streak(self) -> int:
        """
        Calcula a ofensiva atual (dias consecutivos lidos).
        Regra:
        - Se leu hoje, conta hoje e volta dia a dia consecutivo.
        - Se ainda não leu hoje, mas leu ontem, a ofensiva permanece ativa (conta de ontem para trás).
        - Se não leu hoje nem ontem, a ofensiva é 0.
        """
        await self.ensure_schema()
        today = date.today()
        yesterday = today - timedelta(days=1)

        read_today = await self.is_read(today.isoformat())
        read_yesterday = await self.is_read(yesterday.isoformat())

        if not read_today and not read_yesterday:
            return 0

        # Ponto de partida para contagem consecutiva
        current_day = today if read_today else yesterday
        streak = 0

        conn = await self.db_connection.get_connection()
        async with conn.execute("SELECT DISTINCT date FROM reading_log ORDER BY date DESC;") as cur:
            rows = await cur.fetchall()
            all_read_dates = {row[0] for row in rows if row and row[0]}

        check_date = current_day
        while check_date.isoformat() in all_read_dates:
            streak += 1
            check_date -= timedelta(days=1)

        return streak

    async def get_total_read_days(self) -> int:
        """Retorna o número total de dias distintos com leituras realizadas."""
        await self.ensure_schema()
        conn = await self.db_connection.get_connection()
        async with conn.execute("SELECT COUNT(DISTINCT date) FROM reading_log;") as cur:
            row = await cur.fetchone()
            return int(row[0]) if row and row[0] is not None else 0

    async def sync_to_supabase(self, device_id: str) -> None:
        """Sincroniza leituras locais para o Supabase em segundo plano de forma resiliente e não-bloqueante."""
        if not SUPABASE_URL or not SUPABASE_KEY or not device_id:
            return

        try:
            await self.ensure_schema()
            conn = await self.db_connection.get_connection()
            async with conn.execute("SELECT date, category, marked_at FROM reading_log;") as cur:
                rows = await cur.fetchall()

            if not rows:
                return

            records = [
                {
                    "device_id": str(device_id),
                    "user_id": str(device_id) if "-" in str(device_id) and len(str(device_id)) == 36 else None,
                    "date": row[0],
                    "category": row[1],
                    "marked_at": row[2] or date.today().isoformat(),
                }
                for row in rows
            ]

            def _do_upsert():
                from supabase import create_client
                supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
                supabase.table("reading_streaks").upsert(
                    records,
                    on_conflict="device_id,date,category",
                ).execute()

            await asyncio.to_thread(_do_upsert)
            logger.info("ReadingService: %d registros sincronizados com Supabase.", len(records))
        except Exception as ex:
            logger.debug("Falha na sincronização do Supabase reading_streaks (ignorado em offline): %s", ex)

