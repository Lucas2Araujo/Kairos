import pytest
from pathlib import Path
from src.services.wallpaper_service import WallpaperService, _WALLPAPERS_DIR, NATURE_WALLPAPERS


def test_wallpaper_service_initialization(tmp_path):
    custom_dir = tmp_path / "custom_wp"
    srv = WallpaperService(cache_dir=custom_dir)
    assert srv.cache_dir == custom_dir
    assert custom_dir.exists()


def test_wallpaper_service_default_dir():
    srv = WallpaperService()
    assert srv.cache_dir == _WALLPAPERS_DIR


def test_wallpaper_service_daily_rotation():
    srv = WallpaperService()
    url1 = srv.get_daily_wallpaper_url(day_offset=0)
    url2 = srv.get_daily_wallpaper_url(day_offset=1)
    assert url1 in NATURE_WALLPAPERS
    assert url2 in NATURE_WALLPAPERS
    assert url1 != url2
