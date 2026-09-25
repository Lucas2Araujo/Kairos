import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
import flet as ft

from src.database.connection import DatabaseConnection
from src.models.hino import Hino
from src.repositories.hino_repository import HinoRepository
from src.services.media_service import MediaService
from src.services.theme_service import ThemeService
from src.views.settings_dialog import SettingsDialogController


@pytest.fixture
def in_memory_db():
    conn = DatabaseConnection(":memory:")
    yield conn


@pytest.mark.asyncio
async def test_settings_dialog_audio_tab_rendering(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)
    mock_media_service = MagicMock(spec=MediaService)
    mock_media_service.get_audio_storage_usage.return_value = {
        "audio_novo": 1024 * 1024 * 5,
        "audio_antigo": 1024 * 1024 * 2,
    }

    controller = SettingsDialogController(
        page=mock_page,
        theme_service=theme_service,
        media_service=mock_media_service,
        initial_tab="audio",
    )
    bs = controller.build_bottom_sheet()

    assert bs is not None
    assert controller.active_tab == "audio"
    assert controller.audio_container is not None
    assert controller.audio_container.visible is True
    assert controller.bg_play_switch is not None
    assert controller.audio_mode_radio is not None
    assert controller.audio_mode_radio.value == "intervalo"
    assert controller.audio_range_start is not None
    assert controller.audio_range_end is not None
    assert controller.audio_download_btn is not None


@pytest.mark.asyncio
async def test_settings_dialog_audio_mode_change(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)

    controller = SettingsDialogController(
        page=mock_page,
        theme_service=theme_service,
        initial_tab="audio",
    )
    controller.build_bottom_sheet()

    assert controller.range_inputs_row.visible is True

    controller.audio_mode_radio.value = "atual"
    controller._on_audio_mode_change(MagicMock())
    assert controller.range_inputs_row.visible is False

    controller.audio_mode_radio.value = "intervalo"
    controller._on_audio_mode_change(MagicMock())
    assert controller.range_inputs_row.visible is True


@pytest.mark.asyncio
async def test_settings_dialog_bg_play_toggle(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)

    controller = SettingsDialogController(
        page=mock_page,
        theme_service=theme_service,
        initial_tab="audio",
    )
    controller.build_bottom_sheet()

    with patch.object(controller.audio_manager, "set_background_play", new_callable=AsyncMock) as mock_set:
        await controller._on_bg_play_toggle(False)
        mock_set.assert_awaited_once_with(False, mock_page)


@pytest.mark.asyncio
async def test_settings_dialog_clear_audio_cache(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)
    mock_media_service = MagicMock(spec=MediaService)
    mock_media_service.clear_audio_downloads.return_value = 5
    mock_media_service.get_audio_storage_usage.return_value = {
        "audio_novo": 0,
        "audio_antigo": 0,
    }

    controller = SettingsDialogController(
        page=mock_page,
        theme_service=theme_service,
        media_service=mock_media_service,
        initial_tab="audio",
    )
    controller.build_bottom_sheet()

    await controller._clear_audio_cache()
    mock_media_service.clear_audio_downloads.assert_called_once()
    assert "5 arquivos excluídos" in controller.audio_progress_text.value


@pytest.mark.asyncio
async def test_settings_dialog_batch_download_success(in_memory_db):
    theme_service = ThemeService(in_memory_db)
    mock_page = MagicMock(spec=ft.Page)
    mock_media_service = MagicMock(spec=MediaService)
    mock_media_service.download_audio_batch = AsyncMock(return_value={
        "completed": 2,
        "skipped": 0,
        "failed": 0,
        "cancelled": False,
        "total": 2,
    })
    mock_media_service.get_audio_storage_usage.return_value = {
        "audio_novo": 1024 * 1024 * 3,
        "audio_antigo": 0,
    }

    mock_repo = MagicMock(spec=HinoRepository)
    mock_repo.get_all_complete = AsyncMock(return_value=[
        Hino(id=1, numero="1", titulo="Hino 1", link_video="https://youtube.com/watch?v=abc"),
        Hino(id=2, numero="2", titulo="Hino 2", link_video="https://youtube.com/watch?v=def"),
    ])

    controller = SettingsDialogController(
        page=mock_page,
        theme_service=theme_service,
        media_service=mock_media_service,
        hino_repository=mock_repo,
        initial_tab="audio",
    )
    controller.build_bottom_sheet()
    controller.audio_mode_radio.value = "atual"

    await controller._start_audio_batch_download()

    mock_media_service.download_audio_batch.assert_awaited_once()
    assert "2 novos baixados" in controller.audio_progress_text.value
