import pytest
from unittest.mock import MagicMock
import flet as ft
from src.views.welcome_dialog import (
    WelcomeDialogController,
    show_welcome_dialog,
    is_onboarding_completed,
    set_onboarding_completed,
)
from src.services.theme_service import ThemeService


@pytest.mark.asyncio
async def test_welcome_dialog_build(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)

    controller = WelcomeDialogController(
        page=mock_page,
        theme_service=theme_service,
        auth_service=None,
    )
    bs = controller.build_bottom_sheet()

    assert isinstance(bs, ft.BottomSheet)


@pytest.mark.asyncio
async def test_welcome_dialog_finish_and_dismiss(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = MagicMock()

    completed_called = False

    def on_done():
        nonlocal completed_called
        completed_called = True

    controller = WelcomeDialogController(
        page=mock_page,
        theme_service=theme_service,
        auth_service=None,
        on_complete=on_done,
    )
    bs = controller.build_bottom_sheet()

    await controller._on_finish()
    assert bs.open is False
    assert completed_called is True


def test_show_welcome_dialog_helper(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)

    show_welcome_dialog(
        page=mock_page,
        theme_service=theme_service,
        auth_service=None,
    )

    mock_page.show_dialog.assert_called_once()


@pytest.mark.asyncio
async def test_onboarding_completed_persistence_sqlite_and_storage(in_memory_db, monkeypatch):
    """Testa que a flag de onboarding concluído é lida e gravada tanto no client_storage quanto no SQLite."""
    from unittest.mock import patch

    mock_page = MagicMock(spec=ft.Page)
    storage_data = {}

    async def mock_get(key):
        return storage_data.get(key)

    async def mock_set(key, val):
        storage_data[key] = val

    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = mock_get
    mock_page.client_storage.set_async = mock_set

    # Patch DatabaseConnection em welcome_dialog para retornar in_memory_db
    with patch("src.database.connection.DatabaseConnection", return_value=in_memory_db):
        # 1. Inicialmente não concluído
        assert await is_onboarding_completed(mock_page) is False

        # 2. Concluir onboarding
        await set_onboarding_completed(mock_page, True)
        assert await is_onboarding_completed(mock_page) is True
        assert storage_data.get("onboarding_completed") is True

        # Verifica tabela preferencias do SQLite
        conn = await in_memory_db.get_connection()
        async with conn.execute(
            "SELECT valor FROM preferencias WHERE chave = 'onboarding_completed'"
        ) as cur:
            row = await cur.fetchone()
        assert row is not None
        assert row[0] == "true"

        # 3. Limpar client_storage (simulando nova sessão ou cache limpo) -> deve recuperar do SQLite
        storage_data.clear()
        assert await is_onboarding_completed(mock_page) is True
        # E sincronizar de volta no storage
        assert storage_data.get("onboarding_completed") is True

        # 4. Redefinir para False
        await set_onboarding_completed(mock_page, False)
        storage_data.clear()
        assert await is_onboarding_completed(mock_page) is False

