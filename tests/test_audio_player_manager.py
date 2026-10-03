import sys
from unittest.mock import MagicMock, patch
import pytest
import flet as ft

from src.services.audio_player_manager import AudioPlayerManager, is_running_on_android, is_desktop


def test_is_running_on_android_false_on_standard_linux():
    with patch.dict("os.environ", {}, clear=True):
        if hasattr(sys, "getandroidapilevel"):
            delattr(sys, "getandroidapilevel")
        assert is_running_on_android() is False


def test_ensure_audio_control_never_adds_audio_to_overlay():
    """Garante que flet_audio.Audio NUNCA seja colocado em page.overlay."""
    manager = AudioPlayerManager()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.overlay = []
    mock_page.services = []

    # Simula ambiente Android (não-desktop)
    with patch.object(manager, "use_desktop_backend", False):
        audio_ctrl = manager.ensure_audio_control(mock_page)

        # page.overlay NUNCA deve conter Audio
        for ctrl in mock_page.overlay:
            assert getattr(ctrl, "_Control__type", None) != "Audio"
            assert type(ctrl).__name__ != "Audio"

        # Deve conter apenas o mini_player_container
        assert manager.mini_player_container in mock_page.overlay

        # Audio deve estar em page.services
        assert audio_ctrl in mock_page.services


def test_ensure_audio_control_prunes_residual_audio_from_overlay():
    """Se por acaso houver algum Audio no overlay, ensure_audio_control deve limpá-lo."""
    manager = AudioPlayerManager()
    mock_page = MagicMock(spec=ft.Page)
    
    # Cria mock que se passa por Audio
    fake_audio = MagicMock()
    fake_audio._Control__type = "Audio"
    
    mock_page.overlay = [fake_audio]
    mock_page.services = []

    with patch.object(manager, "use_desktop_backend", True):
        manager.ensure_audio_control(mock_page)

        # fake_audio deve ter sido expurgado do overlay
        assert fake_audio not in mock_page.overlay
