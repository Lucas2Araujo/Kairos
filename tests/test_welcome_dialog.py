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
