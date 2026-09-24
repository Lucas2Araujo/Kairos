import pytest
import uuid
from datetime import datetime
from unittest.mock import MagicMock
from src.services.notification_service import (
    NotificationService,
    NotificationReminderConfig,
    ROUTE_SABADO_HINOS,
)
from src.repositories.hino_repository import HinoRepository
from src.database.connection import DatabaseConnection


@pytest.fixture
def test_db_path(tmp_path):
    unique_id = uuid.uuid4().hex[:8]
    db_file = tmp_path / f"test_notifications_{unique_id}.db"
    return str(db_file)


@pytest.mark.asyncio
async def test_notification_service_initialization_and_seeds(test_db_path):
    srv = NotificationService(db_path=test_db_path)
    reminders = await srv.get_reminders()

    assert len(reminders) == 4
    reminder_ids = [r.id for r in reminders]
    assert "escola_sabatina" in reminder_ids
    assert "devocional" in reminder_ids
    assert "biblia" in reminder_ids
    assert "por_do_sol_sexta" in reminder_ids

    # Verifica lembrete de pôr do sol na sexta
    sunset = next(r for r in reminders if r.id == "por_do_sol_sexta")
    assert sunset.time == "16:00"
    assert sunset.days_of_week == [4]
    assert sunset.payload_route == ROUTE_SABADO_HINOS
    assert "hinos" in sunset.body.lower()


@pytest.mark.asyncio
async def test_update_reminder(test_db_path):
    srv = NotificationService(db_path=test_db_path)
    reminders = await srv.get_reminders()
    sunset = next(r for r in reminders if r.id == "por_do_sol_sexta")

    sunset.time = "16:30"
    sunset.enabled = False
    await srv.update_reminder(sunset)

    updated = await srv.get_reminders()
    u_sunset = next(r for r in updated if r.id == "por_do_sol_sexta")
    assert u_sunset.time == "16:30"
    assert u_sunset.enabled is False


@pytest.mark.asyncio
async def test_sunset_reminder_due_logic(test_db_path):
    srv = NotificationService(db_path=test_db_path)

    # Sexta-feira às 15:59 -> Não deve disparar
    friday_1559 = datetime(2026, 9, 25, 15, 59)  # 2026-09-25 é sexta-feira (weekday=4)
    due_early = await srv.check_due_reminders(current_dt=friday_1559)
    assert not any(r.id == "por_do_sol_sexta" for r in due_early)

    # Sexta-feira às 16:00 -> Deve disparar
    friday_1600 = datetime(2026, 9, 25, 16, 0)
    due_on_time = await srv.check_due_reminders(current_dt=friday_1600)
    assert any(r.id == "por_do_sol_sexta" for r in due_on_time)

    # Sábado às 16:00 -> Não deve disparar lembrete de sexta
    saturday_1600 = datetime(2026, 9, 26, 16, 0)
    due_saturday = await srv.check_due_reminders(current_dt=saturday_1600)
    assert not any(r.id == "por_do_sol_sexta" for r in due_saturday)


@pytest.mark.asyncio
async def test_prevent_duplicate_dispatch_on_same_day(test_db_path):
    srv = NotificationService(db_path=test_db_path)
    friday_1605 = datetime(2026, 9, 25, 16, 5)

    # 1ª checagem dispara
    due1 = await srv.check_due_reminders(current_dt=friday_1605)
    assert any(r.id == "por_do_sol_sexta" for r in due1)

    # 2ª checagem no mesmo dia não deve disparar novamente
    friday_1610 = datetime(2026, 9, 25, 16, 10)
    due2 = await srv.check_due_reminders(current_dt=friday_1610)
    assert not any(r.id == "por_do_sol_sexta" for r in due2)


def test_deep_link_route_parsing():
    from main import _parse_route_query
    parsed = _parse_route_query("/hinario?filtro=sabado")
    assert parsed.route_base == "/novo"
    assert parsed.initial_filtro == "sabado"
    # Compatibilidade com desempacotamento legado (5 itens)
    r_base, q, cat, tema, from_hino = parsed
    assert r_base == "/novo"
    assert q == ""


@pytest.mark.asyncio
async def test_sabado_hinos_repository_query(test_db_path):
    db_conn = DatabaseConnection(db_path=test_db_path)
    conn = await db_conn.get_connection()
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS hino (
            id INTEGER PRIMARY KEY,
            numero TEXT NOT NULL,
            titulo TEXT NOT NULL,
            letra TEXT,
            audio_url TEXT
        );
    """)
    # Inserir hinos dentro e fora da faixa 290-299
    await conn.execute("INSERT INTO hino (id, numero, titulo) VALUES (1, '10', 'Hino 10');")
    await conn.execute("INSERT INTO hino (id, numero, titulo) VALUES (2, '290', 'Guarda o Sábado');")
    await conn.execute("INSERT INTO hino (id, numero, titulo) VALUES (3, '295', 'Santo Dia');")
    await conn.execute("INSERT INTO hino (id, numero, titulo) VALUES (4, '299', 'Fim de Sábado');")
    await conn.execute("INSERT INTO hino (id, numero, titulo) VALUES (5, '300', 'Hino 300');")
    await conn.commit()

    repo = HinoRepository(db_conn)
    sabado_hinos = await repo.get_sabado_hinos()

    assert len(sabado_hinos) == 3
    numeros = [h.numero for h in sabado_hinos]
    assert numeros == ["290", "295", "299"]

