import asyncio
import logging
import os
import re
import sys
from collections.abc import Callable
from typing import Any, cast
from urllib.parse import quote as url_quote

logger = logging.getLogger(__name__)

try:
    import yt_dlp
except ImportError:
    yt_dlp = None  # type: ignore


# Qualidade de vídeo
QUALITY_SD = "sd"
QUALITY_HD = "hd"

# Formatos do yt-dlp otimizados para Android (prioriza containers nativos mp4/m4a)
_YDL_FORMAT_VIDEO_SD = (
    "bestvideo[height<=480][ext=mp4]+bestaudio[ext=m4a]"
    "/best[height<=480][ext=mp4]"
    "/best[height<=480]"
    "/best"
)
_YDL_FORMAT_VIDEO_HD = (
    "bestvideo[height<=720][ext=mp4]+bestaudio[ext=m4a]"
    "/best[height<=720][ext=mp4]"
    "/best[height<=720]"
    "/best"
)
_YDL_FORMAT_AUDIO = (
    "bestaudio[ext=m4a]"
    "/bestaudio"
    "/best[ext=mp4]"
    "/best"
)

# Configuração robusta para evitar HTTP 403: o YouTube bloqueia clientes padrão sem token/JS
_YDL_DEFAULT_EXTRACTOR_ARGS = {
    "youtube": {
        "player_client": ["android", "web"],
    }
}


async def _run_sync_or_thread(func, *args, **kwargs):
    """Executa a função em thread ou síncrona se o ambiente não suportar threads (WebAssembly/Pyodide)."""
    try:
        return await asyncio.to_thread(func, *args, **kwargs)
    except RuntimeError:
        return func(*args, **kwargs)


def _resolve_download_root(download_dir: str) -> str:
    """Resolve o diretório raiz de downloads respeitando variáveis de ambiente Android/Flet."""
    if not os.path.isabs(download_dir):
        base = os.environ.get("FLET_APP_STORAGE_DATA") or os.environ.get("FILES_DIR")
        if base:
            download_dir = os.path.join(base, download_dir)
    try:
        os.makedirs(download_dir, exist_ok=True)
    except OSError:
        pass
    return download_dir


def path_to_file_uri(filepath: str) -> str:
    """
    Converte um caminho absoluto do sistema de arquivos para uma URI ``file://``
    válida e compatível com Flutter/Android (Video).

    Exemplo:
        /data/user/0/app/files/downloads/video_sd/hino_1.mp4
        → file:///data/user/0/app/files/downloads/video_sd/hino_1.mp4
    """
    filepath = os.path.abspath(filepath)
    # No Windows, caminhos usam barras invertidas
    if sys.platform == "win32":
        filepath = filepath.replace("\\", "/")
    # url_quote preserva / e :
    return "file://" + url_quote(filepath, safe="/:")


class MediaService:
    """
    Serviço assíncrono seguro para gerenciamento de mídias e vídeos do Hinário.

    Responsabilidades:
    - Download de vídeo em SD (480p) e HD (720p / melhor disponível) via yt-dlp
    - Verificação de status de downloads de vídeos por qualidade
    - Conversão de caminhos locais para URIs ``file://`` compatíveis com Flutter
    - Geração de URLs YouTube Embed para reprodução online via WebView
    - Download em lote de vídeos com callback de progresso e cancelamento
    """

    # ── Subdiretórios de mídia ────────────────────────────────────────
    VIDEO_SD_SUBDIR = "video_sd"
    VIDEO_HD_SUBDIR = "video_hd"
    AUDIO_NOVO_SUBDIR = "audio_novo"
    AUDIO_ANTIGO_SUBDIR = "audio_antigo"

    def __init__(self, download_dir: str = "downloads"):
        self.download_dir = _resolve_download_root(download_dir)
        # Cria subdiretórios organizados
        for subdir in (
            self.VIDEO_SD_SUBDIR,
            self.VIDEO_HD_SUBDIR,
            self.AUDIO_NOVO_SUBDIR,
            self.AUDIO_ANTIGO_SUBDIR,
        ):
            os.makedirs(os.path.join(self.download_dir, subdir), exist_ok=True)

    # ── Sanitização ───────────────────────────────────────────────────

    def _sanitize_url(self, url: str | None) -> str:
        """Sanitiza URLs para evitar injeção de parâmetros e comandos."""
        if not url:
            return ""
        url = url.strip()
        if not re.match(r"^https?://[^\s\"']+$", url, re.IGNORECASE):
            raise ValueError("URL de mídia inválida ou insegura.")
        return url

    # ── YouTube Helpers ───────────────────────────────────────────────

    def extract_youtube_id(self, url: str | None) -> str | None:
        """Extrai o ID do vídeo do YouTube de diversos formatos de URL."""
        if not url:
            return None
        match = re.search(r"(?:v=|\/|embed\/|shorts\/)([a-zA-Z0-9_-]{11})", url)
        return match.group(1) if match else None

    def get_embed_url(self, url: str | None) -> str | None:
        """Retorna a URL formatada para exibição do vídeo embutido (embed)."""
        video_id = self.extract_youtube_id(url)
        if video_id:
            return f"https://www.youtube.com/embed/{video_id}?autoplay=1"
        return url if url and url.startswith("http") else None

    # ── Caminhos de Arquivo Local ─────────────────────────────────────

    def get_local_video_path(self, hino_id: int, quality: str = QUALITY_SD) -> str:
        """Retorna o caminho do arquivo de vídeo local."""
        subdir = self.VIDEO_HD_SUBDIR if quality == QUALITY_HD else self.VIDEO_SD_SUBDIR
        return os.path.join(self.download_dir, subdir, f"hino_{hino_id}.mp4")

    # ── Verificação de Status de Download ─────────────────────────────

    def is_video_downloaded(self, hino_id: int, quality: str = QUALITY_SD) -> bool:
        """Verifica se o vídeo do hino existe localmente na qualidade especificada."""
        path = self.get_local_video_path(hino_id, quality)
        return os.path.isfile(path)

    def get_download_status(self, hino_id: int) -> dict[str, bool]:
        """Retorna o status de download de vídeo de um hino."""
        return {
            "video_sd": self.is_video_downloaded(hino_id, QUALITY_SD),
            "video_hd": self.is_video_downloaded(hino_id, QUALITY_HD),
        }

    # ── URIs file:// para Flutter ─────────────────────────────────────

    def get_video_file_uri(self, hino_id: int, quality: str = QUALITY_SD) -> str | None:
        """Retorna a URI file:// do vídeo local, ou None se não baixado."""
        if not self.is_video_downloaded(hino_id, quality):
            return None
        return path_to_file_uri(self.get_local_video_path(hino_id, quality))

    # ── Métodos de Áudio Local ────────────────────────────────────────

    def _get_audio_subdir(self, edition: str = "novo") -> str:
        return self.AUDIO_ANTIGO_SUBDIR if edition == "antigo" else self.AUDIO_NOVO_SUBDIR

    def get_local_audio_path(self, hino_id: int, edition: str = "novo") -> str:
        """Retorna o caminho do arquivo de áudio local (M4A)."""
        subdir = self._get_audio_subdir(edition)
        return os.path.join(self.download_dir, subdir, f"hino_{hino_id}.m4a")

    def is_audio_downloaded(self, hino_id: int, edition: str = "novo") -> bool:
        """Verifica se o áudio do hino existe localmente na edição especificada."""
        path = self.get_local_audio_path(hino_id, edition)
        if os.path.isfile(path):
            return True
        subdir = self._get_audio_subdir(edition)
        dir_path = os.path.join(self.download_dir, subdir)
        if os.path.isdir(dir_path):
            prefix = f"hino_{hino_id}."
            return any(f.startswith(prefix) for f in os.listdir(dir_path))
        return False

    def get_audio_file_uri(self, hino_id: int, edition: str = "novo") -> str | None:
        """Retorna a URI file:// do áudio local, ou None se não baixado."""
        path = self.get_local_audio_path(hino_id, edition)
        if os.path.isfile(path):
            return path_to_file_uri(path)
        subdir = self._get_audio_subdir(edition)
        dir_path = os.path.join(self.download_dir, subdir)
        if os.path.isdir(dir_path):
            prefix = f"hino_{hino_id}."
            for f in os.listdir(dir_path):
                if f.startswith(prefix):
                    return path_to_file_uri(os.path.join(dir_path, f))
        return None

    def delete_audio(self, hino_id: int, edition: str = "novo") -> bool:
        """Exclui o arquivo de áudio local do hino. Retorna True se algum arquivo foi removido."""
        deleted = False
        subdir = self._get_audio_subdir(edition)
        dir_path = os.path.join(self.download_dir, subdir)
        if os.path.isdir(dir_path):
            prefix = f"hino_{hino_id}."
            for f in os.listdir(dir_path):
                if f.startswith(prefix):
                    try:
                        os.remove(os.path.join(dir_path, f))
                        deleted = True
                    except OSError:
                        pass
        return deleted

    # ── Extração de Metadados (yt-dlp) ────────────────────────────────

    async def get_stream_url(self, video_url: str | None, audio_only: bool = True) -> str | None:
        """
        Retorna a URL direta de streaming usando yt-dlp.
        Se audio_only=True, prioriza stream direto de áudio nativo (M4A/AAC).
        NOTA: URLs do YouTube expiram rapidamente e podem falhar com 403.
        Prefira get_embed_url() para reprodução online via WebView.
        """
        if not yt_dlp:
            return None
        sanitized_url = self._sanitize_url(video_url)
        if not sanitized_url:
            return None

        format_str = _YDL_FORMAT_AUDIO if audio_only else "best"
        ydl_opts: dict[str, Any] = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "format": format_str,
            "extractor_args": _YDL_DEFAULT_EXTRACTOR_ARGS,
        }

        def _extract():
            with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
                info = ydl.extract_info(sanitized_url, download=False)
                return info.get("url")

        try:
            return await _run_sync_or_thread(_extract)
        except Exception as exc:
            logger.debug("Falha ao extrair audio stream: %s", exc)
            return None

    async def get_info(self, video_url: str | None) -> dict[str, Any] | None:
        """Extrai metadados do vídeo de forma assíncrona não-bloqueante."""
        if not yt_dlp:
            return None
        sanitized_url = self._sanitize_url(video_url)
        if not sanitized_url:
            return None

        ydl_opts: dict[str, Any] = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "format": "best",
            "extractor_args": _YDL_DEFAULT_EXTRACTOR_ARGS,
        }

        def _extract():
            with yt_dlp.YoutubeDL(cast(Any, ydl_opts)) as ydl:
                info = ydl.extract_info(sanitized_url, download=False)
                return {
                    "title": info.get("title"),
                    "duration": info.get("duration"),
                    "url": info.get("url"),
                    "thumbnail": info.get("thumbnail"),
                    "video_id": self.extract_youtube_id(sanitized_url),
                }

        try:
            return await _run_sync_or_thread(_extract)
        except Exception as exc:
            logger.debug("Falha ao extrair info de video: %s", exc)
            return None

    # ── Download de Vídeo ─────────────────────────────────────────────

    @staticmethod
    def _make_progress_hook(callback: Callable[[float], None]):
        def _hook(d):
            if d.get("status") == "downloading":
                total = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
                downloaded = d.get("downloaded_bytes", 0)
                if total > 0:
                    callback(downloaded / total)

        return _hook

    async def _try_ydl_download(
        self,
        format_str: str,
        output_template: str,
        output_path: str,
        sanitized_url: str,
        progress_callback: Callable[[float], None] | None,
        merge_mp4: bool = False,
    ) -> str | None:
        ydl_opts: dict[str, Any] = {
            "format": format_str,
            "outtmpl": output_template,
            "quiet": True,
            "no_warnings": True,
            "extractor_args": _YDL_DEFAULT_EXTRACTOR_ARGS,
        }
        if merge_mp4:
            ydl_opts["merge_output_format"] = "mp4"
        if progress_callback:
            ydl_opts["progress_hooks"] = [self._make_progress_hook(progress_callback)]

        if not yt_dlp:
            return None

        def _download():
            ydl_module = cast(Any, yt_dlp)
            with ydl_module.YoutubeDL(cast(Any, ydl_opts)) as ydl:
                ydl.download([sanitized_url])
            return output_path

        try:
            result = await _run_sync_or_thread(_download)
            if os.path.isfile(result):
                return result
        except Exception as exc:
            logger.debug("Falha no download ydl: %s", exc)
            pass
        return None

    async def download_video(
        self,
        hino_id: int,
        video_url: str | None,
        quality: str = QUALITY_SD,
        progress_callback: Callable[[float], None] | None = None,
    ) -> str | None:
        """
        Realiza o download do vídeo em SD (480p) ou HD (720p / melhor disponível).
        Prioriza containers MP4 nativos para compatibilidade com Android.
        """
        if not yt_dlp:
            return None
        sanitized_url = self._sanitize_url(video_url)
        if not sanitized_url:
            return None

        subdir = self.VIDEO_HD_SUBDIR if quality == QUALITY_HD else self.VIDEO_SD_SUBDIR
        video_dir = os.path.join(self.download_dir, subdir)
        output_path = os.path.join(video_dir, f"hino_{hino_id}.mp4")
        output_template = os.path.join(video_dir, f"hino_{hino_id}.%(ext)s")
        format_str = (
            _YDL_FORMAT_VIDEO_HD if quality == QUALITY_HD else _YDL_FORMAT_VIDEO_SD
        )

        # 1. Tentativa com formato solicitado e merge para mp4
        result = await self._try_ydl_download(
            format_str, output_template, output_path, sanitized_url, progress_callback, merge_mp4=True
        )
        if result:
            return result

        # 2. Fallback: tenta formato genérico "best" como MP4
        return await self._try_ydl_download(
            "best[ext=mp4]/best", output_template, output_path, sanitized_url, progress_callback
        )

    # ── Download em Lote (Batch) ──────────────────────────────────────

    async def _download_batch_item(
        self,
        hino_info: dict[str, Any],
        quality: str,
    ) -> str:
        """Retorna 'skipped', 'completed' ou 'failed' para um item do batch."""
        hino_id = hino_info.get("id")
        link = hino_info.get("link_video", "")
        if hino_id is None or not link:
            return "skipped"

        if self.is_video_downloaded(hino_id, quality):
            return "skipped"

        try:
            result = await self.download_video(hino_id, link, quality)
            return "completed" if result else "failed"
        except (OSError, RuntimeError, ValueError) as exc:
            logger.debug("Falha no download de audio: %s", exc)
            return "failed"

    async def download_library_batch(
        self,
        hino_list: list[dict[str, Any]],
        quality: str = QUALITY_SD,
        progress_callback: Callable[[int, int, str | None], None] | None = None,
        cancel_event: asyncio.Event | None = None,
    ) -> dict[str, Any]:
        """
        Realiza o download em lote de uma lista de vídeos de hinos.

        Args:
            hino_list: Lista de dicts com 'id' e 'link_video'.
            quality: 'sd' ou 'hd'.
            progress_callback: Chamado com (completed, total, current_title).
            cancel_event: asyncio.Event que, quando setado, cancela o download.

        Returns:
            Dict com 'completed', 'failed', 'skipped', 'cancelled'.
        """
        total = len(hino_list)
        stats = {"completed": 0, "failed": 0, "skipped": 0, "cancelled": False, "total": total}

        for hino_info in hino_list:
            if cancel_event and cancel_event.is_set():
                stats["cancelled"] = True
                return stats

            status = await self._download_batch_item(hino_info, quality)
            stats[status] += 1

            if progress_callback:
                processed = stats["completed"] + stats["skipped"] + stats["failed"]
                titulo = hino_info.get("titulo", f"Hino {hino_info.get('id')}")
                progress_callback(processed, total, titulo)

        return stats

    # ── Gerenciamento de Armazenamento ────────────────────────────────

    def get_storage_usage(self) -> dict[str, int]:
        """Retorna o uso de armazenamento em bytes por categoria de vídeo."""
        usage = {"video_sd": 0, "video_hd": 0}
        for category, subdir in [
            ("video_sd", self.VIDEO_SD_SUBDIR),
            ("video_hd", self.VIDEO_HD_SUBDIR),
        ]:
            dir_path = os.path.join(self.download_dir, subdir)
            if os.path.isdir(dir_path):
                for f in os.listdir(dir_path):
                    fp = os.path.join(dir_path, f)
                    if os.path.isfile(fp):
                        usage[category] += os.path.getsize(fp)
        return usage

    def _clear_single_dir(self, dir_path: str) -> int:
        if not os.path.isdir(dir_path):
            return 0
        removed = 0
        for f in os.listdir(dir_path):
            fp = os.path.join(dir_path, f)
            if os.path.isfile(fp):
                try:
                    os.remove(fp)
                    removed += 1
                except OSError:
                    pass
        return removed

    def clear_downloads(self, media_type: str | None = None) -> int:
        """
        Remove downloads de vídeos. Se media_type for None, remove tudo.
        Retorna o número de arquivos removidos.
        """
        subdirs = {
            "video_sd": self.VIDEO_SD_SUBDIR,
            "video_hd": self.VIDEO_HD_SUBDIR,
        }
        if media_type and media_type in subdirs:
            targets = [subdirs[media_type]]
        else:
            targets = list(subdirs.values())

        count = 0
        for subdir in targets:
            dir_path = os.path.join(self.download_dir, subdir)
            count += self._clear_single_dir(dir_path)
        return count

    # ── Download de Áudio & Lote ──────────────────────────────────────

    async def download_audio(
        self,
        hino_id: int,
        audio_url: str | None,
        edition: str = "novo",
        progress_callback: Callable[[float], None] | None = None,
    ) -> str | None:
        """
        Realiza o download do áudio em container M4A nativo do YouTube (sem conversão ffmpeg).
        """
        if not yt_dlp:
            return None
        sanitized_url = self._sanitize_url(audio_url)
        if not sanitized_url:
            return None

        output_path = self.get_local_audio_path(hino_id, edition)
        output_template = os.path.splitext(output_path)[0] + ".%(ext)s"

        result = await self._try_ydl_download(
            _YDL_FORMAT_AUDIO,
            output_template,
            output_path,
            sanitized_url,
            progress_callback,
            merge_mp4=False,
        )
        if result and os.path.isfile(result):
            return result

        # Fallback caso yt-dlp salve com outra extensão
        subdir = self._get_audio_subdir(edition)
        dir_path = os.path.join(self.download_dir, subdir)
        if os.path.isdir(dir_path):
            prefix = f"hino_{hino_id}."
            for f in os.listdir(dir_path):
                if f.startswith(prefix):
                    return os.path.join(dir_path, f)
        return None

    async def _download_audio_batch_item(
        self,
        hino_info: dict[str, Any],
        edition: str,
    ) -> str:
        """Retorna 'skipped', 'completed' ou 'failed' para um item do batch de áudio."""
        hino_id = hino_info.get("id")
        link = hino_info.get("link_video", "")
        item_edition = hino_info.get("edition") or edition
        if hino_id is None or not link:
            return "skipped"

        if self.is_audio_downloaded(hino_id, item_edition):
            return "skipped"

        try:
            result = await self.download_audio(hino_id, link, item_edition)
            return "completed" if result else "failed"
        except (OSError, RuntimeError, ValueError) as exc:
            logger.debug("Falha no download de audio batch: %s", exc)
            return "failed"

    async def download_audio_batch(
        self,
        hino_list: list[dict[str, Any]],
        edition: str = "novo",
        progress_callback: Callable[[int, int, str | None], None] | None = None,
        cancel_event: asyncio.Event | None = None,
    ) -> dict[str, Any]:
        """
        Realiza o download em lote de áudio de uma lista de hinos.
        """
        total = len(hino_list)
        stats = {"completed": 0, "failed": 0, "skipped": 0, "cancelled": False, "total": total}

        for hino_info in hino_list:
            if cancel_event and cancel_event.is_set():
                stats["cancelled"] = True
                return stats

            status = await self._download_audio_batch_item(hino_info, edition)
            stats[status] += 1

            if progress_callback:
                processed = stats["completed"] + stats["skipped"] + stats["failed"]
                titulo = hino_info.get("titulo", f"Hino {hino_info.get('id')}")
                progress_callback(processed, total, titulo)

        return stats

    def get_audio_storage_usage(self) -> dict[str, int]:
        """Retorna o uso de armazenamento em bytes por categoria de áudio."""
        usage = {"audio_novo": 0, "audio_antigo": 0}
        for category, subdir in [
            ("audio_novo", self.AUDIO_NOVO_SUBDIR),
            ("audio_antigo", self.AUDIO_ANTIGO_SUBDIR),
        ]:
            dir_path = os.path.join(self.download_dir, subdir)
            if os.path.isdir(dir_path):
                for f in os.listdir(dir_path):
                    fp = os.path.join(dir_path, f)
                    if os.path.isfile(fp):
                        usage[category] += os.path.getsize(fp)
        return usage

    def clear_audio_downloads(self, edition: str | None = None) -> int:
        """Remove downloads de áudios de uma ou todas as edições."""
        if edition == "antigo":
            targets = [self.AUDIO_ANTIGO_SUBDIR]
        elif edition == "novo":
            targets = [self.AUDIO_NOVO_SUBDIR]
        else:
            targets = [self.AUDIO_NOVO_SUBDIR, self.AUDIO_ANTIGO_SUBDIR]

        count = 0
        for subdir in targets:
            dir_path = os.path.join(self.download_dir, subdir)
            count += self._clear_single_dir(dir_path)
        return count
