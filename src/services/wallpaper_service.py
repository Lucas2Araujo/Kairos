"""
Serviço de imagens dinâmicas e rotativas de natureza para meditação e cards diários.
Oferece cache local de imagens em alta resolução e rotação sem repetição frequente.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime
from pathlib import Path
import urllib.request

logger = logging.getLogger(__name__)

# Diretório padrão de wallpapers cacheados no disco local
try:
    from src.database.connection import DatabaseConnection
    _WALLPAPERS_DIR = DatabaseConnection._get_user_data_dir() / "wallpapers"
except Exception:
    _WALLPAPERS_DIR = Path.home() / ".config" / "kairos" / "wallpapers"

# Pool curado de 30 wallpapers de natureza em alta definição (Unsplash)
# Foco em campos abertos, montanhas, árvores, névoa matinal e horizontes serenos
NATURE_WALLPAPERS = [
    "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1426604966848-d7adac402bff?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1473448912268-2022ce9509d8?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1472214103451-9374bd1c798e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1418065460487-3e41a6c84dc5?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1511497584788-87676104235f?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1508739773434-c26b3d09e071?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1497436072909-60f360e1d4b1?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1502082553048-f009c37129b9?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1518495973542-4542c06a5843?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1433086966358-54859d0ed716?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1475924156734-496f6cac6ec1?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1505765050516-f72dcac9c60e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1513836279014-a89f7a76ae86?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1470770841072-f978cf4d019e?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1600&q=80",
    "https://images.unsplash.com/photo-1439853949127-fa647821eea0?auto=format&fit=crop&w=1600&q=80",
]


class WallpaperService:
    """Gerencia a resolução e o cache local dos papéis de parede de natureza."""

    _instance: WallpaperService | None = None

    def __init__(self, cache_dir: Path | None = None):
        self.cache_dir = cache_dir or _WALLPAPERS_DIR
        try:
            self.cache_dir.mkdir(parents=True, exist_ok=True)
        except Exception as exc:
            logger.debug(f"Falha ao criar diretório de wallpapers: {exc}")

    @classmethod
    def get_instance(cls) -> WallpaperService:
        if cls._instance is None:
            cls._instance = WallpaperService()
        return cls._instance

    def get_daily_wallpaper_url(self, day_offset: int = 0) -> str:
        """Retorna a URL remota curada para a data (evitando repetição frequente)."""
        day_of_year = datetime.now().timetuple().tm_yday + day_offset
        idx = day_of_year % len(NATURE_WALLPAPERS)
        return NATURE_WALLPAPERS[idx]

    def get_cached_file_path(self, day_offset: int = 0) -> Path:
        """Retorna o caminho local onde o wallpaper de hoje deve ser armazenado."""
        day_of_year = datetime.now().timetuple().tm_yday + day_offset
        idx = day_of_year % len(NATURE_WALLPAPERS)
        return self.cache_dir / f"nature_wp_{idx:02d}.jpg"

    def get_daily_wallpaper(self, day_offset: int = 0) -> str:
        """
        Retorna o caminho do arquivo local se já baixado;
        caso contrário, retorna a URL e dispara o download em background.
        """
        local_path = self.get_cached_file_path(day_offset)
        if local_path.exists() and local_path.stat().st_size > 1024:
            return str(local_path)

        remote_url = self.get_daily_wallpaper_url(day_offset)

        # Dispara download em segundo plano para as próximas vezes
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self.download_wallpaper_bg(remote_url, local_path))
        except RuntimeError:
            pass

        return remote_url

    async def download_wallpaper_bg(self, url: str, target_path: Path) -> None:
        """Baixa a imagem em threadpool assíncrona sem travar a interface."""
        if target_path.exists() and target_path.stat().st_size > 1024:
            return

        def _do_download():
            try:
                req = urllib.request.Request(
                    url,
                    headers={"User-Agent": "KairosApp/1.0 (Christian Devotional)"},
                )
                with urllib.request.urlopen(req, timeout=12) as response:
                    data = response.read()
                    if data and len(data) > 1024:
                        temp_file = target_path.with_suffix(".tmp")
                        with open(temp_file, "wb") as f:
                            f.write(data)
                        temp_file.replace(target_path)
            except Exception as e:
                logger.debug(f"Download de wallpaper falhou ({url}): {e}")

        await asyncio.to_thread(_do_download)

    async def preload_weekly_wallpapers(self) -> None:
        """Pré-carrega o lote da semana (próximos 7 dias) em background."""
        for offset in range(7):
            local_path = self.get_cached_file_path(offset)
            if not local_path.exists():
                url = self.get_daily_wallpaper_url(offset)
                await self.download_wallpaper_bg(url, local_path)

