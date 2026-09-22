"""
Diálogo de Atualização Automática para Flet.
Exibe informações da nova versão, notas da release formatadas em Markdown,
identificação de arquitetura de CPU, barra de progresso em tempo real,
validação de integridade e disparo da instalação do pacote .apk ou fallback no navegador.
"""

import asyncio
import contextlib
import logging
import os
import platform
import subprocess
import threading
from typing import Any

import flet as ft

from src.services.updater_service import UpdaterService

logger = logging.getLogger(__name__)


MIME_TYPE_APK = "application/vnd.android.package-archive"

# Atributo interno no page para armazenar services persistentes
_SHARE_ATTR = "_kairos_share_service"
_URL_LAUNCHER_ATTR = "_kairos_url_launcher"


def _get_share_service(page: ft.Page) -> ft.Share:
    """
    Retorna uma instância de ft.Share associada à página.
    Mantém referência no objeto page para reutilização.
    """
    existing = getattr(page, _SHARE_ATTR, None)
    if existing is not None:
        return existing

    service = ft.Share()
    if hasattr(page, "services") and isinstance(page.services, list):
        if service not in page.services:
            page.services.append(service)
    elif hasattr(page, "_services") and hasattr(page._services, "register_service"):
        page._services.register_service(service)

    with contextlib.suppress(Exception):
        page.update()

    setattr(page, _SHARE_ATTR, service)
    return service


def _get_url_launcher(page: ft.Page) -> ft.UrlLauncher:
    """
    Retorna uma instância de ft.UrlLauncher associada à página.
    Mantém referência no objeto page para reutilização.
    """
    existing = getattr(page, _URL_LAUNCHER_ATTR, None)
    if existing is not None:
        return existing

    service = ft.UrlLauncher()
    if hasattr(page, "services") and isinstance(page.services, list):
        if service not in page.services:
            page.services.append(service)
    elif hasattr(page, "_services") and hasattr(page._services, "register_service"):
        page._services.register_service(service)

    with contextlib.suppress(Exception):
        page.update()

    setattr(page, _URL_LAUNCHER_ATTR, service)
    return service


def _sync_open_path(path: str) -> bool:
    """Executa a chamada nativa de abertura de pasta/arquivo no Desktop."""
    plat = platform.system().lower()
    try:
        if "linux" in plat:
            subprocess.Popen(["xdg-open", path])
            return True
        elif "windows" in plat:
            if hasattr(os, "startfile"):
                os.startfile(path)
            else:
                subprocess.Popen(["explorer", path])
            return True
        elif "darwin" in plat:
            subprocess.Popen(["open", path])
            return True
    except Exception as ex:
        logger.debug(f"Falha ao abrir caminho nativo no Desktop: {ex}")
    return False


async def open_in_browser(url: str, page: ft.Page | None = None) -> None:
    """Abre a URL especificada no navegador padrão do dispositivo."""
    if not url:
        return

    # 1. Tenta usar o método direto da página (Flet)
    if page:
        try:
            if hasattr(page, "launch_url"):
                await page.launch_url(url)
                return
            launcher = _get_url_launcher(page)
            await launcher.launch_url(url)
            return
        except Exception as ex:
            logger.debug(f"Falha ao usar launcher da página: {ex}")

    # 2. Tenta instanciar ft.UrlLauncher diretamente
    try:
        launcher = ft.UrlLauncher()
        await launcher.launch_url(url)
        return
    except Exception:
        pass

    # 3. Fallback no Desktop via SO
    with contextlib.suppress(Exception):
        await asyncio.to_thread(_sync_open_path, url)


async def open_download_folder(file_or_dir_path: str, page: ft.Page | None = None) -> bool:
    """
    Abre o gerenciador de arquivos/pasta do arquivo APK baixado com fallback seguro:
    1. Desktop: xdg-open / explorer / open
    2. Android: Tenta abrir a visualização de downloads do sistema operacional
    3. Fallback garantido: copia o caminho para a área de transferência e exibe SnackBar
    """
    if not file_or_dir_path:
        return False

    abs_path = os.path.abspath(file_or_dir_path)
    target_dir = abs_path if os.path.isdir(abs_path) else os.path.dirname(abs_path)
    opened = False

    # 1. No Desktop, aciona o explorador de arquivos nativo
    if not UpdaterService.is_android():
        if target_dir and os.path.exists(target_dir):
            opened = await asyncio.to_thread(_sync_open_path, target_dir)
            if opened:
                return True

    # 2. No Android, tenta abrir a tela do gerenciador de downloads
    if UpdaterService.is_android() and page:
        download_uris = [
            "content://downloads/all_downloads",
            "content://downloads/my_downloads",
        ]
        for uri in download_uris:
            try:
                if hasattr(page, "launch_url"):
                    await page.launch_url(uri)
                else:
                    launcher = _get_url_launcher(page)
                    await launcher.launch_url(uri)
                opened = True
                break
            except Exception as ex:
                logger.debug(f"Tentativa de abrir URI {uri} falhou: {ex}")

    # 3. Fallback Resiliente: copia o caminho para o clipboard e notifica o usuário via SnackBar
    if page:
        try:
            if hasattr(page, "set_clipboard"):
                page.set_clipboard(abs_path)
            elif hasattr(page, "clipboard") and hasattr(page.clipboard, "set_data"):
                await page.clipboard.set_data(abs_path)

            filename = os.path.basename(abs_path)
            snack_msg = (
                f"Arquivo salvo em: {target_dir}\n"
                f"Caminho do {filename} copiado para a área de transferência!"
            )
            if hasattr(page, "show_snack_bar"):
                page.show_snack_bar(ft.SnackBar(content=ft.Text(snack_msg), duration=5000))
            elif hasattr(page, "open"):
                page.open(ft.SnackBar(content=ft.Text(snack_msg), duration=5000))
        except Exception as ex:
            logger.debug(f"Fallback de SnackBar/clipboard falhou: {ex}")

    return opened


async def trigger_apk_installation(
    apk_path: str,
    fallback_url: str | None = None,
    page: ft.Page | None = None,
) -> bool:
    """
    Dispara a instalação do arquivo .apk com arquitetura resiliente de fallback:
    - Desktop: Abre o arquivo diretamente pelo SO (xdg-open / open / explorer).
    - Android:
      Nível 1: Tenta abrir via folha de compartilhamento/ações caso o SO suporte.
      Nível 2 (Fallback): Se a chamada local falhar ou não iniciar, abre o link
              direto no navegador do Android, onde o navegador aciona o PackageInstaller.
    """
    file_exists = bool(apk_path and os.path.exists(apk_path))
    abs_path = os.path.abspath(apk_path) if file_exists else ""

    # Se o arquivo não existe, vai direto para o download no navegador
    if not file_exists:
        if fallback_url:
            await open_in_browser(fallback_url, page)
        return False

    # Desktop: Tenta abrir o arquivo diretamente no SO (Linux/macOS/Windows)
    if not UpdaterService.is_android():
        return await asyncio.to_thread(_sync_open_path, abs_path)

    # Android Nível 1: Tenta compartilhar/enviar arquivo para o sistema
    if page:
        try:
            share = _get_share_service(page)
            await share.share_files(
                [
                    ft.ShareFile(
                        path=abs_path,
                        mime_type=MIME_TYPE_APK,
                        name=os.path.basename(abs_path),
                    )
                ],
                title="Instalar Atualização",
                subject="Instalação do Kairós",
            )
            return True
        except Exception as ex:
            logger.warning(f"Share sheet falhou para instalação do APK: {ex}")

    # Android Nível 2 (Fallback): Abre no navegador para download e instalação assistida
    if fallback_url:
        try:
            await open_in_browser(fallback_url, page)
            return True
        except Exception as ex:
            logger.warning(f"Fallback no navegador falhou: {ex}")

    return False


class UpdateDialog:
    """Controlador do diálogo modal de atualização do aplicativo."""

    def __init__(
        self,
        page: ft.Page,
        update_info: dict[str, Any],
        updater_service: UpdaterService,
        on_dismiss: Any | None = None,
    ):
        self.page = page
        self.update_info = update_info
        self.updater_service = updater_service
        self.on_dismiss = on_dismiss

        self.latest_version: str = update_info.get("latest_version", "Nova Versão")
        self.current_version: str = update_info.get("current_version", "")
        self.release_notes: str = update_info.get("release_notes", "").strip()
        self.download_url: str | None = update_info.get(
            "download_url"
        ) or update_info.get("html_url")
        self.html_url: str | None = update_info.get("html_url") or self.download_url
        self.asset_name: str | None = update_info.get("asset_name")
        self.asset_size: int | None = update_info.get("asset_size")
        self.expected_sha256: str | None = update_info.get("expected_sha256")
        self.detected_arch: str = update_info.get(
            "detected_arch", UpdaterService.get_device_architecture()
        )

        self.download_task: asyncio.Task | None = None
        self._dialog_task: asyncio.Task | None = None
        self._cancel_event: threading.Event | None = None
        self.dialog: ft.AlertDialog | None = None
        self._is_closed: bool = False

        self.progress_bar = ft.ProgressBar(value=0, visible=False, expand=True)
        self.status_text = ft.Text("", size=12, italic=True, visible=False)
        self.actions_row = ft.Row(
            controls=[], alignment=ft.MainAxisAlignment.END, spacing=8
        )
        self.is_web = getattr(page, "web", False)
        self.btn_cancel = ft.TextButton("Agora não", on_click=self._close_dialog)
        if self.is_web:
            self.btn_update = ft.FilledButton(
                "Ver no GitHub",
                icon=ft.Icons.OPEN_IN_NEW,
                on_click=lambda _e: asyncio.create_task(
                    open_in_browser(self.html_url or "https://github.com/Lucas2Araujo/Kairos/releases", self.page)
                ),
            )
        else:
            self.btn_update = ft.FilledButton(
                "Atualizar Agora",
                icon=ft.Icons.DOWNLOAD,
                on_click=self._on_click_iniciar_download,
            )
        self.actions_row.controls = [self.btn_cancel, self.btn_update]

    def _close_dialog(self, _e=None) -> None:
        """Fecha o diálogo e cancela qualquer download em andamento."""
        if self._is_closed:
            return
        self._is_closed = True
        self._cancelar_download_silencioso()
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
        if self.on_dismiss and callable(self.on_dismiss):
            self.on_dismiss()

    def _on_dialog_dismissed(self, _e=None) -> None:
        """Chamado quando o diálogo é dispensado (ex: clicando fora do modal)."""
        if self._is_closed:
            return
        self._is_closed = True
        self._cancelar_download_silencioso()
        if self.on_dismiss and callable(self.on_dismiss):
            self.on_dismiss()

    def _cancelar_download_silencioso(self) -> None:
        """Cancela as tarefas de download sem disparar re-render da UI."""
        if self._cancel_event:
            self._cancel_event.set()
        if self.download_task and not self.download_task.done():
            self.download_task.cancel()
        if self._dialog_task and not self._dialog_task.done():
            self._dialog_task.cancel()

    def _cancelar_download(self, _e=None) -> None:
        """Cancela o download ativo e reverte o estado do diálogo para permitir nova tentativa."""
        self._cancelar_download_silencioso()
        self.download_task = None
        self._dialog_task = None
        self._cancel_event = None
        self.progress_bar.visible = False
        self.progress_bar.value = 0
        self.status_text.value = "Download cancelado."
        self.status_text.color = ft.Colors.AMBER_400
        self.status_text.visible = True
        self.actions_row.controls = [self.btn_cancel, self.btn_update]
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    def _on_click_iniciar_download(self, _e=None) -> None:
        self._cancelar_download_silencioso()
        self.download_task = None
        self._dialog_task = asyncio.create_task(self._iniciar_download())

    def _on_progress(self, progress_ratio: float, downloaded: int, total: int) -> None:
        self.progress_bar.value = progress_ratio
        if total > 0:
            mb_down = downloaded / (1024 * 1024)
            mb_total = total / (1024 * 1024)
            pct = int(progress_ratio * 100)
            self.status_text.value = (
                f"Baixando: {pct}% ({mb_down:.1f} MB / {mb_total:.1f} MB)"
            )
        else:
            mb_down = downloaded / (1024 * 1024)
            self.status_text.value = f"Baixando: {mb_down:.1f} MB"
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    async def _acionar_instalacao(self, saved_apk_path: str) -> None:
        """Tenta acionar o instalador nativo do sistema para o APK baixado ou fallback no navegador."""
        self.status_text.value = "Abrindo instalador de pacotes..."
        self.status_text.color = ft.Colors.BLUE_200
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

        success = await trigger_apk_installation(
            apk_path=saved_apk_path,
            fallback_url=self.download_url or self.html_url,
            page=self.page,
        )
        if success:
            self.status_text.value = (
                "Instalador/Navegador iniciado! Conclua a atualização na tela do sistema."
            )
            self.status_text.color = ft.Colors.GREEN_400
        else:
            filename = os.path.basename(saved_apk_path)
            self.status_text.value = (
                f"APK pronto ({filename}). Abra na pasta de downloads ou toque em 'Compartilhar'."
            )
            self.status_text.color = ft.Colors.AMBER_300
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    async def _compartilhar_apk(self, saved_apk_path: str) -> None:
        """Abre a folha de compartilhamento/ações nativa para o arquivo APK sob comando do usuário."""
        try:
            abs_path = os.path.abspath(saved_apk_path)
            share = _get_share_service(self.page)
            await share.share_files(
                [
                    ft.ShareFile(
                        path=abs_path,
                        mime_type=MIME_TYPE_APK,
                        name=os.path.basename(abs_path),
                    )
                ],
                title="Instalar Kairós",
                subject="Instalação de Atualização",
            )
        except Exception as ex:
            logger.warning(f"Compartilhamento do APK falhou: {ex}")
            # Fallback: tenta abrir a URL no navegador
            with contextlib.suppress(Exception):
                await open_in_browser(
                    f"file://{os.path.abspath(saved_apk_path)}", self.page
                )

    def _handle_download_success(self, saved_apk_path: str) -> None:
        self.progress_bar.value = 1.0
        self.progress_bar.visible = True
        filename = os.path.basename(saved_apk_path)
        dir_name = os.path.dirname(saved_apk_path)
        self.status_text.value = (
            f"✓ Download concluído com sucesso!\n"
            f"Salvo em: {dir_name}/\n"
            f"Arquivo: {filename}"
        )
        self.status_text.color = ft.Colors.GREEN_400

        # Botões pós-download responsivos sem largura fixa
        self.actions_row.controls = [
            ft.Column(
                controls=[
                    ft.FilledButton(
                        "Instalar Atualização",
                        icon=ft.Icons.INSTALL_MOBILE,
                        expand=True,
                        on_click=lambda ev: asyncio.create_task(
                            self._acionar_instalacao(saved_apk_path)
                        ),
                    ),
                    ft.FilledTonalButton(
                        "Abrir Pasta do APK",
                        icon=ft.Icons.FOLDER_OPEN,
                        expand=True,
                        on_click=lambda ev: asyncio.create_task(
                            open_download_folder(saved_apk_path, self.page)
                        ),
                    ),
                    ft.Row(
                        controls=[
                            ft.OutlinedButton(
                                "Compartilhar",
                                icon=ft.Icons.SHARE,
                                expand=True,
                                on_click=lambda ev: asyncio.create_task(
                                    self._compartilhar_apk(saved_apk_path)
                                ),
                            ),
                            ft.TextButton("Fechar", on_click=self._close_dialog),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    ),
                ],
                spacing=8,
                tight=True,
                expand=True,
            )
        ]
        # Garante que o actions_row se expanda horizontalmente para conter os botões
        self.actions_row.expand = True
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    def _handle_download_cancelled(self) -> None:
        self.status_text.value = "Download cancelado."
        self.status_text.color = ft.Colors.AMBER_400
        self.progress_bar.visible = False
        self.progress_bar.value = 0
        self.actions_row.controls = [self.btn_cancel, self.btn_update]
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    def _handle_download_error(self, err: Exception) -> None:
        self.status_text.value = f"Falha no download: {err}"
        self.status_text.color = ft.Colors.RED_400
        self.progress_bar.visible = False
        self.actions_row.controls = [
            ft.TextButton("Fechar", on_click=self._close_dialog),
            ft.OutlinedButton(
                "Tentar Novamente",
                icon=ft.Icons.REFRESH,
                on_click=self._on_click_iniciar_download,
            ),
            ft.FilledButton(
                "Baixar no Navegador",
                icon=ft.Icons.OPEN_IN_BROWSER,
                on_click=lambda ev: asyncio.create_task(
                    open_in_browser(self.download_url or self.html_url or "", self.page)
                ),
            ),
        ]
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    async def _iniciar_download(self) -> None:
        if not self.download_url:
            self.status_text.value = "URL de download indisponível."
            self.status_text.color = ft.Colors.RED_400
            self.status_text.visible = True
            self.actions_row.controls = [
                ft.TextButton("Fechar", on_click=self._close_dialog),
                ft.FilledButton(
                    "Abrir GitHub",
                    icon=ft.Icons.OPEN_IN_BROWSER,
                    on_click=lambda ev: asyncio.create_task(
                        open_in_browser(self.html_url or "", self.page)
                    ),
                ),
            ]
            if self.page:
                try:
                    self.page.update()
                except Exception:
                    pass
            return

        self.progress_bar.visible = True
        self.progress_bar.value = None
        self.status_text.visible = True
        self.status_text.value = "Iniciando download do APK compatível..."
        self.status_text.color = ft.Colors.BLUE_200

        self.actions_row.controls = [
            ft.TextButton("Cancelar", on_click=self._cancelar_download)
        ]
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

        self._cancel_event = threading.Event()

        try:
            self.download_task = asyncio.create_task(
                self.updater_service.download_apk(
                    download_url=self.download_url,
                    on_progress=self._on_progress,
                    filename=self.asset_name,
                    expected_size=self.asset_size,
                    expected_sha256=self.expected_sha256,
                    cancel_event=self._cancel_event,
                )
            )
            saved_apk_path = await self.download_task
            # Exibe o sucesso e opções para o usuário (NUNCA dispara share automaticamente)
            self._handle_download_success(saved_apk_path)
        except asyncio.CancelledError:
            self._handle_download_cancelled()
            raise
        except Exception as err:
            self._handle_download_error(err)

    def _build_version_card(self) -> ft.Container:
        arch_label = UpdaterService.format_architecture_label(self.detected_arch)

        info_items: list[ft.Control] = [
            ft.Container(
                content=ft.Text(
                    f"CPU: {arch_label}",
                    size=11,
                    weight=ft.FontWeight.W_500,
                    color=ft.Colors.BLUE_300,
                ),
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
                padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                border_radius=6,
            )
        ]

        if self.asset_size and self.asset_size > 0:
            size_mb = self.asset_size / (1024 * 1024)
            info_items.append(
                ft.Container(
                    content=ft.Text(
                        f"{size_mb:.1f} MB",
                        size=11,
                        weight=ft.FontWeight.W_500,
                        color=ft.Colors.GREY_300,
                    ),
                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
                    padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                    border_radius=6,
                )
            )

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Column(
                                controls=[
                                    ft.Text(
                                        "Versão Atual",
                                        size=11,
                                        color=ft.Colors.GREY_400,
                                    ),
                                    ft.Text(
                                        f"v{self.current_version}",
                                        weight=ft.FontWeight.BOLD,
                                        size=14,
                                    ),
                                ],
                                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            ft.Icon(
                                ft.Icons.ARROW_FORWARD,
                                size=18,
                                color=ft.Colors.BLUE_400,
                            ),
                            ft.Column(
                                controls=[
                                    ft.Text(
                                        "Nova Versão",
                                        size=11,
                                        color=ft.Colors.GREEN_400,
                                    ),
                                    ft.Text(
                                        f"v{self.latest_version}",
                                        weight=ft.FontWeight.BOLD,
                                        size=14,
                                        color=ft.Colors.GREEN_400,
                                    ),
                                ],
                                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_AROUND,
                    ),
                    ft.Row(
                        controls=info_items,
                        alignment=ft.MainAxisAlignment.CENTER,
                        spacing=8,
                    ),
                ],
                spacing=8,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=8,
            padding=ft.Padding.all(12),
        )

    def _build_notes_container(self) -> ft.Container:
        notes_content = (
            self.release_notes
            if self.release_notes
            else "Esta atualização inclui correções de bugs, melhorias de desempenho e novas funcionalidades."
        )
        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Markdown(
                        notes_content,
                        selectable=True,
                        extension_set=ft.MarkdownExtensionSet.GITHUB_WEB,
                    )
                ],
                scroll=ft.ScrollMode.AUTO,
            ),
            height=160,
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            border_radius=8,
            padding=ft.Padding.all(10),
        )

    def build_dialog(self) -> ft.AlertDialog:
        self.dialog = ft.AlertDialog(
            modal=False,
            on_dismiss=self._on_dialog_dismissed,
            title=ft.Row(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.SYSTEM_UPDATE, color=ft.Colors.BLUE_400, size=26),
                            ft.Text(
                                "Atualização Disponível", weight=ft.FontWeight.BOLD, size=17
                            ),
                        ],
                        spacing=8,
                        alignment=ft.MainAxisAlignment.START,
                    ),
                    ft.IconButton(
                        icon=ft.Icons.CLOSE,
                        icon_size=20,
                        tooltip="Fechar",
                        on_click=self._close_dialog,
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        self._build_version_card(),
                        ft.Text("Novidades:", weight=ft.FontWeight.BOLD, size=13),
                        self._build_notes_container(),
                        self.progress_bar,
                        self.status_text,
                    ],
                    tight=True,
                    spacing=10,
                ),
                width=360,
            ),
            actions=[self.actions_row],
        )
        return self.dialog

    def show(self) -> None:
        dialog = self.build_dialog()
        try:
            self.page.show_dialog(dialog)
        except Exception:
            if hasattr(self.page, "open"):
                self.page.open(dialog)


def show_update_dialog(
    page: ft.Page,
    update_info: dict[str, Any],
    updater_service: UpdaterService,
    on_dismiss: Any | None = None,
) -> None:
    """
    Renderiza e abre o ft.AlertDialog informando a nova versão e permitindo
    o download com barra de progresso.
    """
    dialog_controller = UpdateDialog(page, update_info, updater_service, on_dismiss)
    dialog_controller.show()
