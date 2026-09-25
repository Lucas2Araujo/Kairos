"""
Gerenciador global de reprodução de áudio para o Kairós.
Em desktop Linux com flavor light (sem libaudioplayers_linux_plugin.so / sem libmpv.so.2),
utiliza ffplay em subprocesso não-bloqueante evitando o erro 'Unknown control: Audio'.
No Android ou plataformas suportadas, utiliza o widget nativo flet_audio.Audio.
Mantém sincronia completa do estado (play/pause/seek/stop), slider e mini-player.
"""

import asyncio
import inspect
import logging
import os
import shutil
import subprocess
import sys
import time
import urllib.parse
from collections.abc import Callable
from typing import Any

import flet as ft

try:
    from flet_audio import (
        Audio,
        AudioDurationChangeEvent,
        AudioPositionChangeEvent,
        AudioState,
        AudioStateChangeEvent,
    )
except ImportError:
    Audio = Any  # type: ignore[misc, assignment]
    AudioDurationChangeEvent = Any  # type: ignore[misc, assignment]
    AudioPositionChangeEvent = Any  # type: ignore[misc, assignment]
    AudioStateChangeEvent = Any  # type: ignore[misc, assignment]

    class AudioState:  # type: ignore[no-redef]
        STOPPED = "stopped"
        PLAYING = "playing"
        PAUSED = "paused"
        COMPLETED = "completed"

logger = logging.getLogger(__name__)

STORAGE_KEY_BACKGROUND_PLAY = "pref_audio_background_play"


def is_running_on_android() -> bool:
    """Detecta se o aplicativo está rodando em ambiente Android."""
    if hasattr(sys, "getandroidapilevel"):
        return True
    if os.environ.get("ANDROID_ROOT") or os.environ.get("ANDROID_BOOTLOGO"):
        return True
    return False


def is_desktop_linux() -> bool:
    """Verifica se está executando no Linux desktop (onde o flavor light não tem libaudioplayers)."""
    return sys.platform.startswith("linux") and not is_running_on_android()


def format_time_ms(ms: int) -> str:
    """Converte milissegundos em formato mm:ss."""
    if ms <= 0:
        return "00:00"
    total_seconds = int(ms // 1000)
    minutes = total_seconds // 60
    seconds = total_seconds % 60
    return f"{minutes:02d}:{seconds:02d}"


def normalize_media_path(target: str) -> str:
    """Normaliza file:// para caminho do sistema local se for arquivo."""
    if target.startswith("file://"):
        return urllib.parse.unquote(urllib.parse.urlparse(target).path)
    return target


class AudioPlayerManager:
    """Singleton/Gerenciador central de reprodução de áudio."""

    _instance: "AudioPlayerManager | None" = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if getattr(self, "_initialized", False):
            return
        self._initialized = True

        self.audio_control: Audio | None = None
        self.page: ft.Page | None = None

        self.current_hino_id: int | None = None
        self.current_edition: str = "novo"
        self.current_title: str = ""
        self.current_number: str = ""
        self.current_src: str = ""

        self.is_playing: bool = False
        self.is_loading: bool = False
        self.position_ms: int = 0
        self.duration_ms: int = 0

        self.background_play_enabled: bool = True
        self._listeners: set[Callable[[], None]] = set()

        # Mini player global container em page.overlay
        self.mini_player_container: ft.Container | None = None
        self.mini_player_title: ft.Text | None = None
        self.mini_player_btn: ft.IconButton | None = None
        self.active_view_hino_id: int | None = None

        # Suporte Desktop Linux (ffplay fallback sem libmpv / flet-desktop-light)
        self.use_desktop_backend: bool = is_desktop_linux()
        self._proc: subprocess.Popen | None = None
        self._timer_task: asyncio.Task | None = None
        self._last_tick_time: float = 0.0

    def add_listener(self, callback: Callable[[], None]) -> None:
        self._listeners.add(callback)

    def remove_listener(self, callback: Callable[[], None]) -> None:
        self._listeners.discard(callback)

    def _notify_listeners(self) -> None:
        for cb in list(self._listeners):
            try:
                cb()
            except Exception:
                pass
        self._update_mini_player()

    async def load_preferences(self, page: ft.Page | None = None) -> bool:
        target_page = page or self.page
        if target_page and hasattr(target_page, "client_storage"):
            try:
                val = await target_page.client_storage.get_async(STORAGE_KEY_BACKGROUND_PLAY)
                if val is not None:
                    self.background_play_enabled = bool(val)
            except Exception:
                pass
        return self.background_play_enabled

    async def set_background_play(self, enabled: bool, page: ft.Page | None = None) -> None:
        self.background_play_enabled = enabled
        target_page = page or self.page
        if target_page and hasattr(target_page, "client_storage"):
            try:
                await target_page.client_storage.set_async(STORAGE_KEY_BACKGROUND_PLAY, enabled)
            except Exception:
                pass

    @property
    def background_playback_enabled(self) -> bool:
        return self.background_play_enabled

    def set_background_playback(self, enabled: bool) -> None:
        self.background_play_enabled = enabled

    def ensure_audio_control(self, page: ft.Page) -> Audio | None:
        """
        Garante que os controles visuais estejam no overlay.
        No Linux Desktop, NÃO anexa flet_audio.Audio ao overlay para evitar o erro 'Unknown control: Audio'.
        No Android, anexa o Audio normalmente.
        """
        self.page = page
        self._ensure_mini_player_in_overlay(page)

        if self.use_desktop_backend:
            return None

        if self.audio_control is None:
            self.audio_control = Audio(
                autoplay=False,
                on_position_change=self._on_position_change,
                on_duration_change=self._on_duration_change,
                on_state_change=self._on_state_change,
            )
            page.overlay.append(self.audio_control)
            page.update()
        elif self.audio_control not in page.overlay:
            page.overlay.append(self.audio_control)
            page.update()
        return self.audio_control

    def _ensure_mini_player_in_overlay(self, page: ft.Page) -> None:
        """Adiciona o mini-player discreto ao overlay se ainda não estiver presente."""
        if self.mini_player_container is None:
            self.mini_player_title = ft.Text(
                "",
                size=12,
                weight=ft.FontWeight.W_600,
                max_lines=1,
                overflow=ft.TextOverflow.ELLIPSIS,
                expand=True,
            )
            self.mini_player_btn = ft.IconButton(
                icon=ft.Icons.PLAY_ARROW_ROUNDED,
                icon_size=20,
                on_click=lambda e: self.toggle_play_pause(),
            )
            close_btn = ft.IconButton(
                icon=ft.Icons.CLOSE_ROUNDED,
                icon_size=18,
                tooltip="Parar áudio",
                on_click=lambda e: self.stop(),
            )
            self.mini_player_container = ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.MUSIC_NOTE_ROUNDED, size=18, color=ft.Colors.PRIMARY),
                        self.mini_player_title,
                        self.mini_player_btn,
                        close_btn,
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=6,
                ),
                bottom=20,
                left=20,
                right=20,
                bgcolor=ft.Colors.with_opacity(0.92, ft.Colors.SURFACE_CONTAINER_HIGHEST),
                blur=ft.Blur(10, 10, ft.BlurTileMode.CLAMP),
                border=ft.Border.all(1, ft.Colors.with_opacity(0.2, ft.Colors.OUTLINE)),
                border_radius=16,
                padding=ft.Padding.symmetric(horizontal=12, vertical=6),
                shadow=ft.BoxShadow(blur_radius=12, spread_radius=1, color=ft.Colors.with_opacity(0.25, ft.Colors.BLACK)),
                visible=False,
            )
            page.overlay.append(self.mini_player_container)
        elif self.mini_player_container not in page.overlay:
            page.overlay.append(self.mini_player_container)

    def _update_mini_player(self) -> None:
        """Atualiza a visibilidade e dados do mini-player de acordo com a rota/tela ativa."""
        if not self.mini_player_container or not self.page:
            return

        should_show = (
            self.is_playing
            and self.background_play_enabled
            and self.active_view_hino_id != self.current_hino_id
        )

        self.mini_player_container.visible = should_show
        if should_show and self.mini_player_title and self.mini_player_btn:
            self.mini_player_title.value = f"Hino {self.current_number}: {self.current_title}"
            self.mini_player_btn.icon = ft.Icons.PAUSE_ROUNDED if self.is_playing else ft.Icons.PLAY_ARROW_ROUNDED

        try:
            self.mini_player_container.update()
        except Exception:
            pass

    def set_active_view_hino(self, hino_id: int | None) -> None:
        """Informa qual hino está sendo visualizado na tela atual."""
        self.active_view_hino_id = hino_id
        self._update_mini_player()

    def on_view_popped(self) -> None:
        """Chamado quando a tela do hino é fechada."""
        self.active_view_hino_id = None
        if not self.background_play_enabled and self.is_playing:
            self.stop()
        else:
            self._update_mini_player()

    def _on_position_change(self, e: AudioPositionChangeEvent) -> None:
        pos = getattr(e, "position", None)
        if pos is None and hasattr(e, "data"):
            try:
                pos = int(e.data)
            except (ValueError, TypeError):
                pos = 0
        if isinstance(pos, (int, float)):
            self.position_ms = int(pos)
            self._notify_listeners()

    def _on_duration_change(self, e: AudioDurationChangeEvent) -> None:
        dur = getattr(e, "duration", None)
        if dur is not None and hasattr(dur, "in_milliseconds"):
            self.duration_ms = int(dur.in_milliseconds)
        elif hasattr(e, "data"):
            try:
                self.duration_ms = int(e.data)
            except (ValueError, TypeError):
                pass
        self._notify_listeners()

    def _on_state_change(self, e: AudioStateChangeEvent) -> None:
        state = getattr(e, "state", None)
        if state == AudioState.PLAYING:
            self.is_playing = True
            self.is_loading = False
        elif state in (AudioState.PAUSED, AudioState.STOPPED):
            self.is_playing = False
            self.is_loading = False
        elif state == AudioState.COMPLETED:
            self.is_playing = False
            self.is_loading = False
            self.position_ms = self.duration_ms
        self._notify_listeners()

    # ── Desktop Linux Subprocess Engine ──────────────────────────────

    def _kill_proc(self) -> None:
        if self._proc:
            try:
                self._proc.terminate()
            except Exception:
                pass
            self._proc = None

    def _cancel_timer(self) -> None:
        if self._timer_task and not self._timer_task.done():
            self._timer_task.cancel()
        self._timer_task = None

    async def _progress_loop(self) -> None:
        """Loop assíncrono para atualizar tempo e status no modo Desktop Linux."""
        try:
            while self.is_playing:
                await asyncio.sleep(0.5)
                now = time.time()
                elapsed_ms = int((now - self._last_tick_time) * 1000)
                self._last_tick_time = now
                self.position_ms += elapsed_ms

                if self._proc and self._proc.poll() is not None:
                    # ffplay terminou
                    self.is_playing = False
                    if self.duration_ms > 0:
                        self.position_ms = self.duration_ms
                    self._notify_listeners()
                    break

                if self.duration_ms > 0 and self.position_ms >= self.duration_ms:
                    self.position_ms = self.duration_ms
                    self.is_playing = False
                    self._kill_proc()
                    self._notify_listeners()
                    break

                self._notify_listeners()
        except asyncio.CancelledError:
            pass

    def _probe_duration(self, clean_src: str) -> None:
        """Tenta obter a duração exata do arquivo/stream via ffprobe."""
        if not shutil.which("ffprobe"):
            return
        try:
            cmd = [
                "ffprobe",
                "-v", "error",
                "-show_entries", "format=duration",
                "-of", "default=noprint_wrappers=1:nokey=1",
                clean_src,
            ]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            val = res.stdout.strip()
            if val:
                sec = float(val)
                if sec > 0:
                    self.duration_ms = int(sec * 1000)
        except Exception:
            pass

    def _start_ffplay_process(self, clean_src: str, start_sec: float = 0.0) -> bool:
        if not shutil.which("ffplay"):
            logger.warning("ffplay não encontrado no sistema.")
            return False

        self._kill_proc()
        cmd = ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet"]
        if start_sec > 0:
            cmd.extend(["-ss", f"{start_sec:.2f}"])
        cmd.append(clean_src)

        try:
            self._proc = subprocess.Popen(
                cmd,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return True
        except Exception as exc:
            logger.error("Erro ao iniciar ffplay: %s", exc)
            return False

    # ── Métodos Públicos de Reprodução ────────────────────────────────

    async def play_hino(
        self,
        page: ft.Page,
        hino_id: int,
        numero: str,
        titulo: str,
        audio_url_or_path: str,
        edition: str = "novo",
    ) -> bool:
        """Inicia reprodução do hino com URL de streaming ou arquivo local."""
        self.ensure_audio_control(page)
        await self.load_preferences(page)

        self.current_hino_id = hino_id
        self.current_number = numero
        self.current_title = titulo
        self.current_edition = edition
        self.current_src = audio_url_or_path
        self.position_ms = 0
        self.duration_ms = 0
        self.is_loading = True
        self._notify_listeners()

        clean_src = normalize_media_path(audio_url_or_path)

        if self.use_desktop_backend:
            self._cancel_timer()
            self._probe_duration(clean_src)
            ok = self._start_ffplay_process(clean_src, 0.0)
            self.is_loading = False
            if ok:
                self.is_playing = True
                self._last_tick_time = time.time()
                self._timer_task = asyncio.create_task(self._progress_loop())
                self._notify_listeners()
                return True
            else:
                self.is_playing = False
                self._notify_listeners()
                return False

        # Android / plataformas padrão com Audio nativo
        if self.audio_control:
            self.audio_control.src = audio_url_or_path
            self.audio_control.update()
            try:
                res = self.audio_control.play()
                if inspect.iscoroutine(res):
                    await res
                self.is_playing = True
                return True
            except Exception as exc:
                logger.debug("Erro ao iniciar áudio nativo: %s", exc)
                self.is_playing = False
                return False
            finally:
                self.is_loading = False
                self._notify_listeners()
        return False

    def toggle_play_pause(self) -> None:
        if self.is_playing:
            self.pause()
        else:
            self.resume()

    def pause(self) -> None:
        if not self.is_playing:
            return

        if self.use_desktop_backend:
            self._cancel_timer()
            self._kill_proc()
            self.is_playing = False
            self._notify_listeners()
            return

        if self.audio_control:
            try:
                res = self.audio_control.pause()
                if inspect.iscoroutine(res):
                    asyncio.create_task(res)
            except Exception:
                pass
            self.is_playing = False
            self._notify_listeners()

    def resume(self) -> None:
        if self.is_playing:
            return

        if self.use_desktop_backend:
            clean_src = normalize_media_path(self.current_src)
            if clean_src:
                start_sec = max(0.0, self.position_ms / 1000.0)
                ok = self._start_ffplay_process(clean_src, start_sec)
                if ok:
                    self.is_playing = True
                    self._last_tick_time = time.time()
                    self._timer_task = asyncio.create_task(self._progress_loop())
                    self._notify_listeners()
            return

        if self.audio_control:
            try:
                res = self.audio_control.resume()
                if inspect.iscoroutine(res):
                    asyncio.create_task(res)
            except Exception:
                pass
            self.is_playing = True
            self._notify_listeners()

    def seek(self, position_ms: int) -> None:
        self.position_ms = max(0, position_ms)

        if self.use_desktop_backend:
            if self.is_playing:
                clean_src = normalize_media_path(self.current_src)
                self._cancel_timer()
                self._start_ffplay_process(clean_src, self.position_ms / 1000.0)
                self._last_tick_time = time.time()
                self._timer_task = asyncio.create_task(self._progress_loop())
            self._notify_listeners()
            return

        if self.audio_control:
            try:
                res = self.audio_control.seek(ft.Duration(milliseconds=self.position_ms))
                if inspect.iscoroutine(res):
                    asyncio.create_task(res)
            except Exception:
                pass
            self._notify_listeners()

    def stop(self) -> None:
        if self.use_desktop_backend:
            self._cancel_timer()
            self._kill_proc()
        elif self.audio_control:
            try:
                res = self.audio_control.pause()
                if inspect.iscoroutine(res):
                    asyncio.create_task(res)
            except Exception:
                pass

        self.is_playing = False
        self.is_loading = False
        self.position_ms = 0
        self.duration_ms = 0
        self.current_hino_id = None
        self._notify_listeners()
