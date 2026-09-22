from __future__ import annotations

import logging
import re
from typing import Any, Sequence
import aiosqlite

from src.database.connection import DatabaseConnection
from src.models.escola_sabatina import (
    SSDay,
    SSLesson,
    SSQuarterly,
    SSUserNote,
)

logger = logging.getLogger(__name__)


class EscolaSabatinaRepository:
    """
    Repositório assíncrono para persistência e cache local de lições, trimestres,
    dias de estudo e anotações pessoais do usuário da Escola Sabatina.
    """

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self._table_initialized = False

    async def _ensure_tables(self, conn: aiosqlite.Connection) -> None:
        """Garante a existência das tabelas de trimestres, lições, dias e anotações."""
        if self._table_initialized:
            return

        await conn.execute("""
            CREATE TABLE IF NOT EXISTS ss_quarterlies (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                description TEXT DEFAULT '',
                human_date TEXT DEFAULT '',
                start_date TEXT DEFAULT '',
                end_date TEXT DEFAULT '',
                cover TEXT DEFAULT '',
                category TEXT DEFAULT 'adultos'
            );
        """)

        await conn.execute("""
            CREATE TABLE IF NOT EXISTS ss_lessons (
                id TEXT PRIMARY KEY,
                quarterly_id TEXT NOT NULL,
                lesson_index TEXT DEFAULT '',
                title TEXT NOT NULL,
                start_date TEXT DEFAULT '',
                end_date TEXT DEFAULT '',
                cover TEXT DEFAULT '',
                path TEXT DEFAULT '',
                FOREIGN KEY (quarterly_id) REFERENCES ss_quarterlies(id)
            );
        """)

        await conn.execute("""
            CREATE TABLE IF NOT EXISTS ss_days (
                id TEXT PRIMARY KEY,
                lesson_id TEXT NOT NULL,
                day_index TEXT DEFAULT '',
                title TEXT NOT NULL,
                date TEXT NOT NULL,
                content TEXT NOT NULL,
                read_path TEXT DEFAULT '',
                FOREIGN KEY (lesson_id) REFERENCES ss_lessons(id)
            );
        """)

        # Tabela estritamente conforme especificação
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS ss_user_notes (
                day_id TEXT PRIMARY KEY,
                note_text TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (day_id) REFERENCES ss_days(id)
            );
        """)

        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_ss_lessons_quarterly 
            ON ss_lessons(quarterly_id);
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_ss_days_lesson 
            ON ss_days(lesson_id);
        """)
        await conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_ss_days_date 
            ON ss_days(date);
        """)

        await conn.commit()
        self._table_initialized = True

    # -----------------------------------------------------------------------
    # Trimestres (Quarterlies)
    # -----------------------------------------------------------------------

    async def save_quarterly(self, quarterly: SSQuarterly | dict[str, Any]) -> None:
        """Salva ou atualiza um trimestre no banco SQLite."""
        q = quarterly if isinstance(quarterly, SSQuarterly) else SSQuarterly.from_dict(quarterly)
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        await conn.execute(
            """
            INSERT INTO ss_quarterlies (id, title, description, human_date, start_date, end_date, cover, category)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title=excluded.title,
                description=excluded.description,
                human_date=excluded.human_date,
                start_date=excluded.start_date,
                end_date=excluded.end_date,
                cover=excluded.cover,
                category=excluded.category;
            """,
            (q.id, q.title, q.description, q.human_date, q.start_date, q.end_date, q.cover, q.category),
        )
        await conn.commit()

    async def get_quarterly(self, quarterly_id: str) -> SSQuarterly | None:
        """Recupera um trimestre por ID."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT id, title, description, human_date, start_date, end_date, cover, category FROM ss_quarterlies WHERE id = ?;",
            (quarterly_id,),
        ) as cur:
            row = await cur.fetchone()
            if not row:
                return None
            return SSQuarterly(
                id=row[0],
                title=row[1],
                description=row[2],
                human_date=row[3],
                start_date=row[4],
                end_date=row[5],
                cover=row[6],
                category=row[7] or "adultos",
            )

    async def list_quarterlies(self, category: str | None = None) -> list[SSQuarterly]:
        """Lista os trimestres salvos, com filtro opcional por categoria ('adultos' ou 'jovens')."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        query = "SELECT id, title, description, human_date, start_date, end_date, cover, category FROM ss_quarterlies"
        params: list[Any] = []
        if category:
            query += " WHERE category = ?"
            params.append(category)
        query += " ORDER BY id DESC;"

        async with conn.execute(query, params) as cur:
            rows = await cur.fetchall()
            return [
                SSQuarterly(
                    id=r[0],
                    title=r[1],
                    description=r[2],
                    human_date=r[3],
                    start_date=r[4],
                    end_date=r[5],
                    cover=r[6],
                    category=r[7] or "adultos",
                )
                for r in rows
            ]

    # -----------------------------------------------------------------------
    # Lições Semanais (Lessons)
    # -----------------------------------------------------------------------

    async def save_lesson(self, lesson: SSLesson | dict[str, Any]) -> None:
        """Salva ou atualiza uma lição semanal no banco SQLite."""
        l = lesson if isinstance(lesson, SSLesson) else SSLesson.from_dict(lesson)
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        await conn.execute(
            """
            INSERT INTO ss_lessons (id, quarterly_id, lesson_index, title, start_date, end_date, cover, path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                quarterly_id=excluded.quarterly_id,
                lesson_index=excluded.lesson_index,
                title=excluded.title,
                start_date=excluded.start_date,
                end_date=excluded.end_date,
                cover=excluded.cover,
                path=excluded.path;
            """,
            (l.id, l.quarterly_id, l.index, l.title, l.start_date, l.end_date, l.cover, l.path),
        )
        await conn.commit()

    async def get_lesson(self, lesson_id: str) -> SSLesson | None:
        """Recupera uma lição semanal por ID."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT id, quarterly_id, lesson_index, title, start_date, end_date, cover, path FROM ss_lessons WHERE id = ?;",
            (lesson_id,),
        ) as cur:
            row = await cur.fetchone()
            if not row:
                return None
            return SSLesson(
                id=row[0],
                quarterly_id=row[1],
                index=row[2],
                title=row[3],
                start_date=row[4],
                end_date=row[5],
                cover=row[6],
                path=row[7],
            )

    async def list_lessons_by_quarterly(self, quarterly_id: str) -> list[SSLesson]:
        """Lista todas as lições de um trimestre ordenadas numericamente."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            """
            SELECT id, quarterly_id, lesson_index, title, start_date, end_date, cover, path 
            FROM ss_lessons 
            WHERE quarterly_id = ? 
            ORDER BY 
                CASE WHEN CAST(lesson_index AS INTEGER) > 0 THEN CAST(lesson_index AS INTEGER)
                     WHEN CAST(id AS INTEGER) > 0 THEN CAST(id AS INTEGER)
                     ELSE 9999 END ASC,
                id ASC;
            """,
            (quarterly_id,),
        ) as cur:
            rows = await cur.fetchall()
            lessons = [
                SSLesson(
                    id=r[0],
                    quarterly_id=r[1],
                    index=r[2],
                    title=r[3],
                    start_date=r[4],
                    end_date=r[5],
                    cover=r[6],
                    path=r[7],
                )
                for r in rows
            ]

            def _sort_key(l: SSLesson) -> int:
                idx_str = l.index or l.id or "999"
                m = re.search(r"(\d+)$", idx_str)
                return int(m.group(1)) if m else 999

            lessons.sort(key=_sort_key)
            return lessons

    # -----------------------------------------------------------------------
    # Dias de Estudo (Days)
    # -----------------------------------------------------------------------

    async def save_day(self, day: SSDay | dict[str, Any]) -> None:
        """Salva ou atualiza o estudo diário de uma lição."""
        d = day if isinstance(day, SSDay) else SSDay.from_dict(day)
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        await conn.execute(
            """
            INSERT INTO ss_days (id, lesson_id, day_index, title, date, content, read_path)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                lesson_id=excluded.lesson_id,
                day_index=excluded.day_index,
                title=excluded.title,
                date=excluded.date,
                content=excluded.content,
                read_path=excluded.read_path;
            """,
            (d.id, d.lesson_id, d.index, d.title, d.date, d.content, d.read_path),
        )
        await conn.commit()

    async def get_day(self, day_id: str) -> SSDay | None:
        """Recupera um dia de estudo por ID."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT id, lesson_id, day_index, title, date, content, read_path FROM ss_days WHERE id = ?;",
            (day_id,),
        ) as cur:
            row = await cur.fetchone()
            if not row:
                return None
            return SSDay(
                id=row[0],
                lesson_id=row[1],
                index=row[2],
                title=row[3],
                date=row[4],
                content=row[5],
                read_path=row[6],
            )

    async def list_days_by_lesson(self, lesson_id: str) -> list[SSDay]:
        """Lista os dias de estudo de uma lição."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT id, lesson_id, day_index, title, date, content, read_path FROM ss_days WHERE lesson_id = ? ORDER BY day_index ASC, id ASC;",
            (lesson_id,),
        ) as cur:
            rows = await cur.fetchall()
            return [
                SSDay(
                    id=r[0],
                    lesson_id=r[1],
                    index=r[2],
                    title=r[3],
                    date=r[4],
                    content=r[5],
                    read_path=r[6],
                )
                for r in rows
            ]

    # -----------------------------------------------------------------------
    # Anotações Pessoais (User Notes)
    # -----------------------------------------------------------------------

    async def get_note(self, day_id: str) -> str | None:
        """Recupera a anotação salva para o dia especificado."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT note_text FROM ss_user_notes WHERE day_id = ?;",
            (day_id,),
        ) as cur:
            row = await cur.fetchone()
            if row and row[0] is not None:
                return row[0]
            return None

    async def save_note(self, day_id: str, note_text: str) -> None:
        """Salva ou atualiza a anotação do dia no SQLite."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        await conn.execute(
            """
            INSERT INTO ss_user_notes (day_id, note_text, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(day_id) DO UPDATE SET
                note_text = excluded.note_text,
                updated_at = CURRENT_TIMESTAMP;
            """,
            (day_id, note_text),
        )
        await conn.commit()

    async def delete_note(self, day_id: str) -> None:
        """Exclui a anotação do dia especificado."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        await conn.execute(
            "DELETE FROM ss_user_notes WHERE day_id = ?;",
            (day_id,),
        )
        await conn.commit()

    # -----------------------------------------------------------------------
    # Status de Cache
    # -----------------------------------------------------------------------

    async def is_day_cached(self, day_id: str) -> bool:
        """Verifica se o conteúdo de um dia já foi baixado e persistido."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT 1 FROM ss_days WHERE id = ? AND content != '' LIMIT 1;",
            (day_id,),
        ) as cur:
            return (await cur.fetchone()) is not None

    async def is_lesson_cached(self, lesson_id: str) -> bool:
        """Verifica se todos os dias de uma lição foram salvos (espera-se pelo menos 1 dia salvo)."""
        conn = await self.db_connection.get_connection()
        await self._ensure_tables(conn)

        async with conn.execute(
            "SELECT COUNT(*) FROM ss_days WHERE lesson_id = ? AND content != '';",
            (lesson_id,),
        ) as cur:
            row = await cur.fetchone()
            return bool(row and row[0] >= 1)

