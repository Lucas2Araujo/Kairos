"""View fullscreen para visualização da tirinha com zoom e download."""

from __future__ import annotations

import asyncio
import logging

import flet as ft

from src.services.escola_sabatina_service import EscolaSabatinaService

logger = logging.getLogger(__name__)


class TirinhaView:
    """Tela cheia para visualizar tirinha/ilustração com zoom e download."""

    def __init__(self, image_url: str, service: EscolaSabatinaService) -> None:
        self.image_url = image_url
        self.service = service
        self.page: ft.Page | None = None

    def build(self, page: ft.Page) -> ft.View:
        """Retorna ft.View fullscreen com InteractiveViewer e 2 botões flutuantes."""
        self.page = page

        viewer = ft.InteractiveViewer(
            content=ft.Image(
                src=self.image_url,
                fit=ft.BoxFit.CONTAIN,
                expand=True,
            ),
            min_scale=0.5,
            max_scale=8.0,
            pan_enabled=True,
            scale_enabled=True,
            expand=True,
        )

        btn_back = ft.IconButton(
            icon=ft.Icons.ARROW_BACK,
            icon_color=ft.Colors.WHITE,
            icon_size=28,
            tooltip="Voltar à lição",
            style=ft.ButtonStyle(
                bgcolor=ft.Colors.TRANSPARENT,
                overlay_color=ft.Colors.WHITE12,
            ),
            on_click=lambda e: asyncio.create_task(page.push_route("/escola-sabatina")),
        )

        btn_download = ft.IconButton(
            icon=ft.Icons.DOWNLOAD_ROUNDED,
            icon_color=ft.Colors.WHITE,
            icon_size=28,
            tooltip="Baixar tirinha",
            style=ft.ButtonStyle(
                bgcolor=ft.Colors.TRANSPARENT,
                overlay_color=ft.Colors.WHITE12,
            ),
            on_click=lambda e: page.run_task(self._download_image),
        )

        bottom_row = ft.Row(
            controls=[btn_back, ft.Container(expand=True), btn_download],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        )

        stack = ft.Stack(
            controls=[
                ft.Container(
                    content=viewer,
                    expand=True,
                    bgcolor=ft.Colors.BLACK,
                    alignment=ft.Alignment.CENTER,
                ),
                ft.Container(
                    content=bottom_row,
                    alignment=ft.Alignment.BOTTOM_CENTER,
                    bottom=16,
                    left=16,
                    right=16,
                ),
            ],
            expand=True,
        )

        return ft.View(
            route="/escola-sabatina/tirinha",
            appbar=None,
            bgcolor=ft.Colors.BLACK,
            padding=0,
            controls=[stack],
        )

    async def _download_image(self) -> None:
        """Baixa a imagem para o cache local e exibe feedback via snackbar."""
        if not self.page:
            return
        try:
            local_path = await self.service.download_and_cache_image(self.image_url)
            msg = "Tirinha salva!" if local_path and not local_path.startswith("http") else "Erro ao salvar tirinha."
        except Exception as exc:
            logger.warning("Erro ao baixar tirinha: %s", exc)
            msg = "Erro ao salvar tirinha."
        self.page.show_snack_bar(ft.SnackBar(content=ft.Text(msg), open=True))
