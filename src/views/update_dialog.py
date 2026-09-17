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


async def open_in_browser(url: str) -> None:
    """Abre a URL especificada no navegador padrão do dispositivo."""
    if not url:
        return
    try:
        await ft.UrlLauncher().launch_url(url)
    except Exception:
        pass


async def open_download_folder(file_or_dir_path: str, page: ft.Page | None = None) -> bool:
    """Abre o gerenciador de arquivos/pasta do arquivo APK baixado."""
    if not file_or_dir_path:
        return False
    target_dir = file_or_dir_path if os.path.isdir(file_or_dir_path) else os.path.dirname(file_or_dir_path)
    if not target_dir or not os.path.exists(target_dir):
        return False

    # 1. Android: Tenta acionar o DownloadManager ou intent nativa de pasta
    if UpdaterService.is_android():
        try:
            import jnius

            jnius.attach_thread()
            from jnius import autoclass

            activity_class = os.getenv(
                "MAIN_ACTIVITY_HOST_CLASS_NAME",
                "com.flet.serious_python_android.PythonActivity",
            )
            activity = None
            for cls_name in (
                activity_class,
                "com.flet.serious_python.PythonActivity",
                "org.kivy.android.PythonActivity",
            ):
                try:
                    activity_host = autoclass(cls_name)
                    activity = getattr(activity_host, "mActivity", None)
                    if activity:
                        break
                except Exception:
                    pass

            if activity:
                Intent = autoclass("android.content.Intent")
                DownloadManager = autoclass("android.app.DownloadManager")
                intent = Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return True
        except Exception as ex:
            logger.warning(f"Falha ao abrir pasta de downloads via JNI no Android: {ex}")

    # 2. Desktop: Linux (xdg-open), Windows (explorer / os.startfile), macOS (open)
    plat = platform.system().lower()
    try:
        if "linux" in plat:
            subprocess.Popen(["xdg-open", target_dir])
            return True
        elif "windows" in plat:
            if hasattr(os, "startfile"):
                os.startfile(target_dir)
            else:
                subprocess.Popen(["explorer", target_dir])
            return True
        elif "darwin" in plat:
            subprocess.Popen(["open", target_dir])
            return True
    except Exception as ex:
        logger.debug(f"Falha ao abrir pasta nativa no Desktop: {ex}")

    # 3. Fallback via UrlLauncher local file://
    try:
        local_uri = f"file://{os.path.abspath(target_dir)}"
        await ft.UrlLauncher().launch_url(local_uri)
        return True
    except Exception:
        pass

    return False


async def trigger_apk_installation(
    apk_path: str,
    fallback_url: str | None = None,
    page: ft.Page | None = None,
) -> bool:
    """
    Dispara a instalação do arquivo .apk no Android via PackageInstaller / FileProvider / Intent.
    Retorna True se o instalador nativo do sistema foi acionado com sucesso.
    NUNCA dispara a tela de compartilhamento automaticamente.
    """
    if not apk_path or not os.path.exists(apk_path):
        if fallback_url:
            await open_in_browser(fallback_url)
        return False

    abs_path = os.path.abspath(apk_path)

    # 1. Tenta via Serious Python / PyJNIus no Android nativo
    if UpdaterService.is_android():
        try:
            import jnius

            jnius.attach_thread()
            from jnius import autoclass

            activity_class = os.getenv(
                "MAIN_ACTIVITY_HOST_CLASS_NAME",
                "com.flet.serious_python_android.PythonActivity",
            )
            activity = None
            for cls_name in (
                activity_class,
                "com.flet.serious_python.PythonActivity",
                "org.kivy.android.PythonActivity",
            ):
                try:
                    activity_host = autoclass(cls_name)
                    activity = getattr(activity_host, "mActivity", None)
                    if activity:
                        break
                except Exception:
                    pass

            if activity:
                Intent = autoclass("android.content.Intent")
                Uri = autoclass("android.net.Uri")
                File = autoclass("java.io.File")
                FileProvider = autoclass("androidx.core.content.FileProvider")

                context = activity.getApplicationContext()
                file_obj = File(abs_path)

                try:
                    package_name = context.getPackageName()
                    content_uri = FileProvider.getUriForFile(
                        context, f"{package_name}.fileprovider", file_obj
                    )
                except Exception:
                    content_uri = Uri.fromFile(file_obj)

                intent = Intent(Intent.ACTION_VIEW)
                intent.setDataAndType(content_uri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                activity.startActivity(intent)
                return True
        except Exception as ex:
            logger.warning(f"Tentativa de acionar PackageInstaller via JNI falhou: {ex}")

    # 2. Desktop: Tenta abrir o arquivo diretamente no SO (Linux/macOS/Windows)
    try:
        plat = platform.system().lower()
        if "linux" in plat or "darwin" in plat:
            local_uri = f"file://{abs_path}"
            await ft.UrlLauncher().launch_url(local_uri)
            return True
        elif "windows" in plat and hasattr(os, "startfile"):
            os.startfile(abs_path)
            return True
    except Exception:
        pass

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
        self.btn_cancel = ft.TextButton("Agora não", on_click=self._close_dialog)
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
        """Tenta acionar o instalador nativo do sistema para o APK baixado."""
        self.status_text.value = "Abrindo instalador de pacotes..."
        self.status_text.color = ft.Colors.BLUE_200
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

        success = await trigger_apk_installation(
            apk_path=saved_apk_path,
            page=self.page,
        )
        if success:
            self.status_text.value = (
                "Instalador iniciado! Conclua a atualização na tela do sistema."
            )
            self.status_text.color = ft.Colors.GREEN_400
        else:
            filename = os.path.basename(saved_apk_path)
            self.status_text.value = (
                f"APK pronto ({filename}). Toque em 'Abrir Pasta' para acessar o arquivo ou "
                "'Compartilhar' para enviar ao instalador."
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
            share_service = ft.Share()
            if hasattr(self.page, "_services"):
                with contextlib.suppress(Exception):
                    self.page._services.register_service(share_service)
            elif hasattr(self.page, "overlay") and share_service not in self.page.overlay:
                self.page.overlay.append(share_service)
                self.page.update()

            await share_service.share_files(
                [
                    ft.ShareFile(
                        path=abs_path,
                        mime_type="application/vnd.android.package-archive",
                        name=os.path.basename(abs_path),
                    )
                ],
                title="Instalar Hinário",
                subject="Instalação de Atualização",
            )
        except Exception:
            with contextlib.suppress(Exception):
                await ft.UrlLauncher().launch_url(
                    f"file://{os.path.abspath(saved_apk_path)}"
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

        # Disposição vertical / empilhada responsiva para nunca estourar o card nem ficar inacessível
        self.actions_row.controls = [
            ft.Column(
                controls=[
                    ft.FilledButton(
                        "Instalar Atualização",
                        icon=ft.Icons.INSTALL_MOBILE,
                        width=340,
                        on_click=lambda ev: asyncio.create_task(
                            self._acionar_instalacao(saved_apk_path)
                        ),
                    ),
                    ft.FilledTonalButton(
                        "Abrir Pasta do APK",
                        icon=ft.Icons.FOLDER_OPEN,
                        width=340,
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
                        width=340,
                    ),
                ],
                spacing=8,
                tight=True,
            )
        ]
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
                    open_in_browser(self.download_url or self.html_url or "")
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
                        open_in_browser(self.html_url or "")
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
