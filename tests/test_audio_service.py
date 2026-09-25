import os
from unittest.mock import patch
import pytest

from src.services.media_service import MediaService, path_to_file_uri


@pytest.mark.asyncio
async def test_audio_paths_and_status(tmp_path):
    download_dir = str(tmp_path)
    service = MediaService(download_dir=download_dir)

    novo_path = service.get_local_audio_path(10, edition="novo")
    antigo_path = service.get_local_audio_path(10, edition="antigo")

    assert service.AUDIO_NOVO_SUBDIR in novo_path
    assert service.AUDIO_ANTIGO_SUBDIR in antigo_path
    assert novo_path != antigo_path

    assert service.is_audio_downloaded(10, edition="novo") is False
    assert service.is_audio_downloaded(10, edition="antigo") is False
    assert service.get_audio_file_uri(10, edition="novo") is None

    # Cria arquivo dummy
    os.makedirs(os.path.dirname(novo_path), exist_ok=True)
    with open(novo_path, "w") as f:
        f.write("audio m4a content")

    assert service.is_audio_downloaded(10, edition="novo") is True
    assert service.is_audio_downloaded(10, edition="antigo") is False

    uri = service.get_audio_file_uri(10, edition="novo")
    assert uri is not None
    assert uri.startswith("file://")
    assert "hino_10.m4a" in uri

    # Testa deleção
    assert service.delete_audio(10, edition="novo") is True
    assert service.is_audio_downloaded(10, edition="novo") is False


@pytest.mark.asyncio
async def test_download_audio_mocked(tmp_path):
    download_dir = str(tmp_path)
    service = MediaService(download_dir=download_dir)

    novo_path = service.get_local_audio_path(42, edition="novo")
    os.makedirs(os.path.dirname(novo_path), exist_ok=True)

    with patch("yt_dlp.YoutubeDL") as MockYDL:
        instance = MockYDL.return_value.__enter__.return_value

        def _fake_download(urls):
            with open(novo_path, "w") as f:
                f.write("dummy audio stream")

        instance.download.side_effect = _fake_download

        res = await service.download_audio(42, "https://www.youtube.com/watch?v=abc", edition="novo")
        assert res is not None
        assert os.path.isfile(res)

    assert service.is_audio_downloaded(42, edition="novo") is True


@pytest.mark.asyncio
async def test_audio_storage_and_cleanup(tmp_path):
    download_dir = str(tmp_path)
    service = MediaService(download_dir=download_dir)

    novo_path = service.get_local_audio_path(1, edition="novo")
    antigo_path = service.get_local_audio_path(1, edition="antigo")

    os.makedirs(os.path.dirname(novo_path), exist_ok=True)
    os.makedirs(os.path.dirname(antigo_path), exist_ok=True)

    with open(novo_path, "w") as f:
        f.write("x" * 1024)
    with open(antigo_path, "w") as f:
        f.write("y" * 2048)

    usage = service.get_audio_storage_usage()
    assert usage["audio_novo"] == 1024
    assert usage["audio_antigo"] == 2048

    # Limpa apenas antigo
    removed = service.clear_audio_downloads(edition="antigo")
    assert removed == 1
    assert service.is_audio_downloaded(1, edition="novo") is True
    assert service.is_audio_downloaded(1, edition="antigo") is False

    # Limpa tudo
    removed_all = service.clear_audio_downloads()
    assert removed_all == 1
    assert service.is_audio_downloaded(1, edition="novo") is False
