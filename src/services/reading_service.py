from __future__ import annotations

import asyncio
import logging
import sqlite3
from datetime import date, timedelta

from src.utils.gamification import calculate_streak, calculate_weekly_activity
from typing import Any

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
    Serviço modular para registro de leitura concluída, unificação de ofensiva (streak)
    e concessão de XP devocional diário (+10 XP strictly once/day).
    Persistência local offline-first (SQLite) e sincronização assíncrona opcional com Supabase.
    """

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self._schema_initialized = False

    async def ensure_schema(self) -> None:
        """Garante a existência das tabelas reading_log e user_gamification no banco local."""
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
            CREATE TABLE IF NOT EXISTS user_gamification (
                user_id TEXT PRIMARY KEY,
                total_xp INTEGER DEFAULT 0,
                current_streak INTEGER DEFAULT 0,
                best_streak INTEGER DEFAULT 0,
                last_activity_date TEXT,
                last_devotional_xp_date TEXT
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
        user_id: str = "local_user",
    ) -> bool:
        """
        Registra uma leitura como concluída para uma data e categoria específicas.
        Aplica a regra de gamificação: +10 XP para leitura devocional estritamente UMA vez por dia do calendário.
        Atualiza o streak unificado (leitura devocional + quiz).
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

        today_str = date.today().isoformat()
        cur = await conn.execute(
            "SELECT total_xp, current_streak, best_streak, last_devotional_xp_date FROM user_gamification WHERE user_id = ?",
            (user_id,)
        )
        row = await cur.fetchone()

        awarded_xp = False
        if not row:
            await conn.execute(
                """
                INSERT INTO user_gamification (user_id, total_xp, current_streak, best_streak, last_activity_date, last_devotional_xp_date)
                VALUES (?, 10, 1, 1, ?, ?);
                """,
                (user_id, today_str, today_str),
            )
            awarded_xp = True
        else:
            total_xp = row[0] or 0
            last_dev_date = row[3]
            if last_dev_date != today_str:
                total_xp += 10
                await conn.execute(
                    """
                    UPDATE user_gamification
                    SET total_xp = ?, last_devotional_xp_date = ?, last_activity_date = ?
                    WHERE user_id = ?;
                    """,
                    (total_xp, today_str, today_str, user_id),
                )
                awarded_xp = True

        if awarded_xp:
            try:
                cur_q = await conn.execute(
                    "SELECT xp FROM user_quiz_stats WHERE user_id = ?",
                    (user_id,)
                )
                q_row = await cur_q.fetchone()
                if q_row:
                    await conn.execute(
                        "UPDATE user_quiz_stats SET xp = xp + 10 WHERE user_id = ?",
                        (user_id,)
                    )
                else:
                    await conn.execute(
                        "INSERT OR IGNORE INTO user_quiz_stats (user_id, xp, current_streak, best_streak, last_quiz_date) VALUES (?, 10, 1, 1, ?)",
                        (user_id, today_str)
                    )
            except sqlite3.OperationalError:
                pass  # user_quiz_stats table may not exist

        await conn.commit()

        # Recalcula e persiste a ofensiva unificada
        streak = await self.get_current_streak(user_id=user_id)
        await conn.execute(
            """
            UPDATE user_gamification
            SET current_streak = ?,
                best_streak = MAX(best_streak, ?)
            WHERE user_id = ?;
            """,
            (streak, streak, user_id),
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

    async def get_all_activity_dates(self, user_id: str = "local_user") -> set[str]:
        """Obtém conjunto unificado de datas com atividade (leitura devocional OU quiz concluído)."""
        await self.ensure_schema()
        conn = await self.db_connection.get_connection()
        dates: set[str] = set()

        async with conn.execute("SELECT DISTINCT date FROM reading_log;") as cur:
            rows = await cur.fetchall()
            for r in rows:
                if r and r[0]:
                    dates.add(str(r[0]))

        try:
            async with conn.execute(
                "SELECT DISTINCT substr(created_at, 1, 10) FROM user_quiz_answers WHERE user_id = ?;",
                (user_id,)
            ) as cur:
                rows = await cur.fetchall()
                for r in rows:
                    if r and r[0]:
                        dates.add(str(r[0]))
        except sqlite3.OperationalError:
            pass

        try:
            async with conn.execute(
                "SELECT last_quiz_date FROM user_quiz_stats WHERE user_id = ? AND last_quiz_date IS NOT NULL;",
                (user_id,)
            ) as cur:
                r = await cur.fetchone()
                if r and r[0]:
                    dates.add(str(r[0]))
        except sqlite3.OperationalError:
            pass

        return dates

    async def get_current_streak(self, user_id: str = "local_user") -> int:
        """
        Calcula a ofensiva unificada (dias consecutivos lidos ou com quiz respondido).
        Regra:
        - Se completou hoje, conta hoje e volta dia a dia consecutivo.
        - Se ainda não completou hoje, mas completou ontem, a ofensiva permanece ativa (conta de ontem para trás).
        - Se não completou hoje nem ontem, a ofensiva é 0.
        """
        await self.ensure_schema()
        all_dates = await self.get_all_activity_dates(user_id=user_id)
        return calculate_streak(all_dates)

    async def get_total_read_days(self) -> int:
        """Retorna o número total de dias distintos com leituras realizadas."""
        await self.ensure_schema()
        conn = await self.db_connection.get_connection()
        async with conn.execute("SELECT COUNT(DISTINCT date) FROM reading_log;") as cur:
            row = await cur.fetchone()
            return int(row[0]) if row and row[0] is not None else 0

    async def get_unified_user_stats(
        self,
        user_id: str = "local_user",
        device_id: str | None = None,
    ) -> dict[str, Any]:
        """
        Retorna estatísticas unificadas de gamificação:
        {
            "total_xp": int,
            "current_streak": int,
            "completed_today": bool
        }
        """
        await self.ensure_schema()
        today_iso = date.today().isoformat()

        all_dates = await self.get_all_activity_dates(user_id=user_id)
        completed_today = today_iso in all_dates
        streak = await self.get_current_streak(user_id=user_id)

        conn = await self.db_connection.get_connection()
        total_xp = 0

        async with conn.execute(
            "SELECT total_xp FROM user_gamification WHERE user_id = ?;",
            (user_id,)
        ) as cur:
            row = await cur.fetchone()
            if row and row[0] is not None:
                total_xp = int(row[0])

        try:
            async with conn.execute(
                "SELECT xp FROM user_quiz_stats WHERE user_id = ?;",
                (user_id,)
            ) as cur:
                q_row = await cur.fetchone()
                if q_row and q_row[0] is not None:
                    total_xp = max(total_xp, int(q_row[0]))
        except sqlite3.OperationalError:
            pass

        weekly_activity = calculate_weekly_activity(all_dates)

        return {
            "total_xp": total_xp,
            "current_streak": streak,
            "completed_today": completed_today,
            "weekly_activity": weekly_activity,
        }

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

            await asyncio.wait_for(asyncio.to_thread(_do_upsert), timeout=5.0)
            logger.info("ReadingService: %d registros sincronizados com Supabase.", len(records))
        except Exception as ex:
            logger.debug("Falha na sincronização do Supabase reading_streaks (ignorado em offline): %s", ex)
