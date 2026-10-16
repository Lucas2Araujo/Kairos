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


def test_detect_audio_mime_type(tmp_path):
    from src.services.local_audio_server import detect_audio_mime_type

    # MP4 / M4A ftyp
    m4a_file = tmp_path / "test.m4a"
    m4a_file.write_bytes(b"\x00\x00\x00\x20ftypM4A \x00\x00\x00\x00")
    assert detect_audio_mime_type(str(m4a_file)) == "audio/mp4"

    # WebM magic bytes
    webm_file = tmp_path / "test.webm"
    webm_file.write_bytes(b"\x1a\x45\xdf\xa3\x9f\x42\x86\x81")
    assert detect_audio_mime_type(str(webm_file)) == "audio/webm"

    # MP3 ID3
    mp3_file = tmp_path / "test.mp3"
    mp3_file.write_bytes(b"ID3\x04\x00\x00\x00\x00\x00\x00")
    assert detect_audio_mime_type(str(mp3_file)) == "audio/mpeg"


def test_local_audio_server_serve_local_file_with_range(tmp_path):
    import urllib.request
    from src.services.local_audio_server import LocalAudioServer

    test_file = tmp_path / "hino_sample.m4a"
    test_data = b"0123456789abcdefghijklmnopqrstuvwxyz" * 10
    test_file.write_bytes(test_data)

    server = LocalAudioServer()
    server.start()
    try:
        url = server.register_local_file(str(test_file))
        assert "http://127.0.0.1:" in url
        assert "/local/" in url

        # 1. Requisição completa (200 OK)
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as resp:
            assert resp.status == 200
            assert resp.headers.get("Accept-Ranges") == "bytes"
            content = resp.read()
            assert content == test_data

        # 2. Requisição parcial com Range (206 Partial Content)
        req_range = urllib.request.Request(url, headers={"Range": "bytes=0-9"})
        with urllib.request.urlopen(req_range) as resp:
            assert resp.status == 206
            assert resp.headers.get("Content-Range") == f"bytes 0-9/{len(test_data)}"
            partial_data = resp.read()
            assert partial_data == test_data[0:10]
    finally:
        server.stop()


def test_local_audio_server_stream_proxy_with_headers():
    import urllib.request
    from unittest.mock import MagicMock
    from src.services.local_audio_server import LocalAudioServer

    server = LocalAudioServer()
    server.start()
    try:
        remote_url = "https://example.com/videoplayback?id=123"
        fake_headers = {"User-Agent": "Mozilla/5.0 Android", "Cookie": "FOO=BAR"}

        proxy_url = server.register_stream(remote_url, headers=fake_headers)
        real_urlopen = urllib.request.urlopen

        # Mock urllib.request.urlopen apenas para a requisição de saída do servidor proxy
        with patch("src.services.local_audio_server.urllib.request.urlopen") as mock_proxy_urlopen:
            fake_resp = MagicMock()
            fake_resp.status = 200
            fake_resp.getcode.return_value = 200
            fake_resp.headers = {"Content-Type": "audio/mp4", "Content-Length": "12"}
            fake_resp.read.side_effect = [b"audio chunks", b""]
            mock_proxy_urlopen.return_value.__enter__.return_value = fake_resp

            req = urllib.request.Request(proxy_url, headers={"Range": "bytes=10-20"})
            with real_urlopen(req) as resp:
                assert resp.status == 200
                assert resp.read() == b"audio chunks"

            # Valida se a requisição remota recebeu o User-Agent, Cookie e o Range repassado
            call_args = mock_proxy_urlopen.call_args
            assert call_args is not None
            out_req = call_args[0][0]
            assert out_req.full_url == remote_url
            assert out_req.headers.get("User-agent") == "Mozilla/5.0 Android"
            assert out_req.headers.get("Cookie") == "FOO=BAR"
            assert out_req.headers.get("Range") == "bytes=10-20"
    finally:
        server.stop()


@pytest.mark.asyncio
async def test_play_hino_local_file_bypasses_local_server(tmp_path):
    """Verifica que arquivo de áudio local existente é passado diretamente para o flet_audio nativo sem usar servidor HTTP."""
    test_audio = tmp_path / "hino_1.m4a"
    test_audio.write_bytes(b"dummy audio data")

    manager = AudioPlayerManager()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.overlay = []
    mock_page.services = []

    with patch.object(manager, "use_desktop_backend", False):
        mock_audio = MagicMock()
        mock_audio.play = MagicMock()
        manager.audio_control = mock_audio

        success = await manager.play_hino(
            page=mock_page,
            hino_id=1,
            numero="1",
            titulo="Santo, Santo, Santo",
            audio_url_or_path=str(test_audio),
        )

        assert success is True
        # src deve ser o caminho limpo do arquivo, e NÃO http://127.0.0.1
        assert mock_audio.src == str(test_audio)
        assert not str(mock_audio.src).startswith("http://127.0.0.1")
        mock_audio.play.assert_called_once()

