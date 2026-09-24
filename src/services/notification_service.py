"""
Serviço de Agendamento e Notificações Locais / Lembretes de Estudo.
Suporta lembretes diários para Escola Sabatina, Devocional, Leitura Bíblica
e o lembrete especial de sexta-feira às 16:00 para preparação do Sábado com Hinos (290 a 299).
"""

from __future__ import annotations

import asyncio
import json
import logging
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

logger = logging.getLogger(__name__)

ROUTE_SABADO_HINOS = "/hinario?filtro=sabado"


class NotificationReminderConfig(BaseModel):
    """Configuração de um lembrete/notificação."""
    model_config = ConfigDict(frozen=False)

    id: str
    title: str
    body: str
    time: str  # formato "HH:MM", ex: "16:00"
    enabled: bool = True
    days_of_week: list[int] = Field(default_factory=list)  # [4] = Sexta-feira. Vazio = todos os dias.
    payload_route: str = "/"
    last_dispatched_date: str | None = None


DEFAULT_REMINDERS: list[NotificationReminderConfig] = [
    NotificationReminderConfig(
        id="escola_sabatina",
        title="Escola Sabatina",
        body="Momento de estudar a lição diária da Escola Sabatina.",
        time="08:00",
        enabled=True,
        days_of_week=[],
        payload_route="/escola-sabatina",
    ),
    NotificationReminderConfig(
        id="devocional",
        title="Meditação Diária",
        body="Comece seu dia inspirado pela comunhão na Meditação Matinal.",
        time="07:00",
        enabled=True,
        days_of_week=[],
        payload_route="/meditacao",
    ),
    NotificationReminderConfig(
        id="biblia",
        title="Leitura Bíblica",
        body="Separe um tempo precioso de leitura da Palavra de Deus hoje.",
        time="20:00",
        enabled=True,
        days_of_week=[],
        payload_route="/biblia",
    ),
    NotificationReminderConfig(
        id="por_do_sol_sexta",
        title="Preparação para o Sábado",
        body="Vamos nos preparar para o sábado cantando hinos ao Senhor? Clique aqui para começarmos!",
        time="16:00",
        enabled=True,
        days_of_week=[4],  # 4 = Sexta-feira
        payload_route=ROUTE_SABADO_HINOS,
    ),
]


class NotificationService:
    """Gerencia lembretes e agendamentos locais para estudo e pôr do sol."""

    def __init__(self, db_path: str | None = None):
        if db_path is None:
            from src.database.connection import DatabaseConnection
            self.db_path = DatabaseConnection._resolve_db_path("hinario.db")
        else:
            self.db_path = db_path
        self._initialized = False

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    async def init_db(self) -> None:
        """Inicializa a tabela de lembretes e semeia configurações padrão se vazia."""
        def _sync_init():
            with self._get_connection() as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS notification_reminders (
                        id TEXT PRIMARY KEY,
                        title TEXT NOT NULL,
                        body TEXT NOT NULL,
                        time TEXT NOT NULL,
                        enabled INTEGER NOT NULL DEFAULT 1,
                        days_of_week TEXT NOT NULL DEFAULT '[]',
                        payload_route TEXT NOT NULL DEFAULT '/',
                        last_dispatched_date TEXT
                    )
                """)
                conn.commit()

                cur = conn.execute("SELECT COUNT(*) FROM notification_reminders")
                count = cur.fetchone()[0]
                if count == 0:
                    for r in DEFAULT_REMINDERS:
                        conn.execute("""
                            INSERT INTO notification_reminders (
                                id, title, body, time, enabled, days_of_week, payload_route, last_dispatched_date
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """, (
                            r.id,
                            r.title,
                            r.body,
                            r.time,
                            1 if r.enabled else 0,
                            json.dumps(r.days_of_week),
                            r.payload_route,
                            None
                        ))
                    conn.commit()

        await asyncio.to_thread(_sync_init)
        self._initialized = True

    async def get_reminders(self) -> list[NotificationReminderConfig]:
        """Retorna todos os lembretes configurados."""
        if not self._initialized:
            await self.init_db()

        def _sync_get():
            with self._get_connection() as conn:
                cur = conn.execute("SELECT * FROM notification_reminders ORDER BY time ASC")
                rows = cur.fetchall()
                result = []
                for row in rows:
                    days = json.loads(row["days_of_week"]) if row["days_of_week"] else []
                    result.append(
                        NotificationReminderConfig(
                            id=row["id"],
                            title=row["title"],
                            body=row["body"],
                            time=row["time"],
                            enabled=bool(row["enabled"]),
                            days_of_week=days,
                            payload_route=row["payload_route"],
                            last_dispatched_date=row["last_dispatched_date"],
                        )
                    )
                return result

        return await asyncio.to_thread(_sync_get)

    async def update_reminder(self, reminder: NotificationReminderConfig) -> bool:
        """Atualiza a configuração de um lembrete existente."""
        if not self._initialized:
            await self.init_db()

        def _sync_update():
            with self._get_connection() as conn:
                conn.execute("""
                    UPDATE notification_reminders
                    SET title = ?, body = ?, time = ?, enabled = ?, days_of_week = ?, payload_route = ?, last_dispatched_date = ?
                    WHERE id = ?
                """, (
                    reminder.title,
                    reminder.body,
                    reminder.time,
                    1 if reminder.enabled else 0,
                    json.dumps(reminder.days_of_week),
                    reminder.payload_route,
                    reminder.last_dispatched_date,
                    reminder.id
                ))
                conn.commit()
            return True

        return await asyncio.to_thread(_sync_update)

    async def check_due_reminders(
        self, current_dt: datetime | None = None
    ) -> list[NotificationReminderConfig]:
        """
        Verifica quais lembretes estão no momento de envio (due).
        Garante idempotência (máximo 1 disparo por dia civil para cada lembrete).
        """
        if not self._initialized:
            await self.init_db()

        now = current_dt or datetime.now()
        today_str = now.strftime("%Y-%m-%d")
        current_time_str = now.strftime("%H:%M")
        weekday = now.weekday()  # 0 = Monday, ..., 4 = Friday, 6 = Sunday

        reminders = await self.get_reminders()
        due: list[NotificationReminderConfig] = []

        for r in reminders:
            if not r.enabled:
                continue

            # Se restrito a certos dias da semana (ex: [4] para sexta-feira)
            if r.days_of_week and weekday not in r.days_of_week:
                continue

            # Idempotência: não enviar duas vezes no mesmo dia
            if r.last_dispatched_date == today_str:
                continue

            # Verifica se já atingiu o horário estipulado
            if current_time_str >= r.time:
                r.last_dispatched_date = today_str
                await self.update_reminder(r)
                due.append(r)

        return due

