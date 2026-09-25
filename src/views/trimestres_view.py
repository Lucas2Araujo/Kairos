"""
View de Seleção de Lição Trimestral da Escola Sabatina - Kairós.

Exibe todas as lições trimestrais disponíveis (Adultos e Jovens) em cards
elegantes com capa em alta resolução, título oficial da lição, período humano
(datas) e indicação do trimestre atualmente em estudo.
Permite selecionar qualquer trimestre para estudo e leitura na EscolaSabatinaView.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Callable

import flet as ft

from src.models.escola_sabatina import SSQuarterly
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.services.theme_service import ThemeService
from src.utils.storage_manager import storage_get, storage_set

logger = logging.getLogger(__name__)

STORAGE_KEY_SS_TYPE = "preferred_ss_type"
STORAGE_KEY_SS_CATEGORY = "preferred_ss_category"
STORAGE_KEY_SELECTED_QUARTERLY_ID = "escola_sabatina_selected_quarterly_id"


class TrimestresView:
    """
    Controlador e construtor da tela de Seleção da Lição Trimestral.
    Apresenta a galeria de lições da Escola Sabatina com capas e títulos.
    """

    def __init__(
        self,
        service: EscolaSabatinaService,
        theme_service: ThemeService | None = None,
        category: str = "adultos",
        on_quarterly_selected: Callable[[str], None] | None = None,
    ):
        self.service = service
        self.theme_service = theme_service
        self.category = category if category in ("adultos", "jovens") else "adultos"
        self.on_quarterly_selected = on_quarterly_selected

        self.page: ft.Page | None = None
        self.quarterlies: list[SSQuarterly] = []
        self.adultos_quarterlies: list[SSQuarterly] = []
        self.jovens_quarterlies: list[SSQuarterly] = []
        self.active_quarterly_id: str | None = None
        self.is_loading: bool = False

        # Controles UI
        self.grid_container: ft.Column | None = None
        self.category_segmented: ft.SegmentedButton | None = None
        self.progress_ring: ft.ProgressRing | None = None

    async def _load_preferences(self) -> None:
        """Carrega categoria e trimestre ativo do client_storage."""
        if not self.page:
            return
        try:
            val_cat = await storage_get(self.page, STORAGE_KEY_SS_TYPE)
            if val_cat in ("adultos", "jovens"):
                self.category = val_cat
        except Exception:
            pass

        try:
            val_qid = await storage_get(self.page, STORAGE_KEY_SELECTED_QUARTERLY_ID)
            if val_qid:
                self.active_quarterly_id = str(val_qid)
        except Exception:
            pass

    async def load_quarterlies(self, force_refresh: bool = False) -> None:
        """Busca trimestres no SQLite ou API da Adventech e atualiza a grade."""
        self.is_loading = True
        self._update_ui()

        try:
            self.adultos_quarterlies = await self.service.get_quarterlies(
                lang="pt", category="adultos", force_refresh=force_refresh
            )
            self.jovens_quarterlies = await self.service.get_quarterlies(
                lang="pt", category="jovens", force_refresh=force_refresh
            )
            self.quarterlies = self.jovens_quarterlies if self.category == "jovens" else self.adultos_quarterlies
        except Exception:
            logger.exception("Erro ao carregar trimestres para exibição.")
            self.adultos_quarterlies = []
            self.jovens_quarterlies = []
            self.quarterlies = []
        finally:
            self.is_loading = False
            self._update_ui()

    async def _on_category_change(self, new_category: str) -> None:
        """Alterna visualização entre lições de Adultos e Jovens."""
        if self.category == new_category:
            return
        self.category = new_category
        if self.page:
            await storage_set(self.page, STORAGE_KEY_SS_TYPE, self.category)
            await storage_set(self.page, STORAGE_KEY_SS_CATEGORY, self.category)
        await self.load_quarterlies(force_refresh=False)

    async def _select_quarterly(self, quarterly: SSQuarterly) -> None:
        """Define o trimestre escolhido, persiste e navega de volta à lição."""
        self.active_quarterly_id = quarterly.id
        if self.page:
            await storage_set(self.page, STORAGE_KEY_SELECTED_QUARTERLY_ID, quarterly.id)
            await storage_set(self.page, STORAGE_KEY_SS_TYPE, quarterly.category)
            await storage_set(self.page, STORAGE_KEY_SS_CATEGORY, quarterly.category)

        if self.on_quarterly_selected:
            try:
                res = self.on_quarterly_selected(quarterly.id)
                if asyncio.iscoroutine(res):
                    await res
            except Exception:
                logger.exception("Erro no callback on_quarterly_selected")

        if self.page:
            try:
                # Retorna para a tela principal da Escola Sabatina
                await self.page.push_route("/escola-sabatina")
            except Exception:
                self.page.go("/escola-sabatina")

    def _build_quarterly_card(self, q: SSQuarterly, p_width: float | None = None) -> ft.Container:
        """Constrói o card individual de um trimestre com capa em destaque e título."""
        is_selected = (self.active_quarterly_id == q.id)
        short_title = q.title.split(":")[0].strip() if q.title else "Lição da Escola Sabatina"

        # Badge de seleção ou status
        badges: list[ft.Control] = []
        if is_selected:
            badges.append(
                ft.Container(
                    content=ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.CHECK_CIRCLE_ROUNDED, size=14, color=ft.Colors.ON_PRIMARY),
                            ft.Text("Atual em Estudo", size=11, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_PRIMARY),
                        ],
                        spacing=4,
                    ),
                    bgcolor=ft.Colors.PRIMARY,
                    border_radius=6,
                    padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                )
            )

        # Imagem de capa com fallback elegante
        cover_url = q.cover or ""
        cover_image = ft.Image(
            src=cover_url,
            width=100,
            height=130,
            fit=ft.BoxFit.COVER,
            border_radius=8,
            error_content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Icon(ft.Icons.MENU_BOOK_ROUNDED, size=36, color=ft.Colors.PRIMARY),
                        ft.Text("Lição", size=11, color=ft.Colors.ON_SURFACE_VARIANT),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=4,
                ),
                width=100,
                height=130,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
                border_radius=8,
                alignment=ft.Alignment.CENTER,
            ),
        )

        card_content = ft.Container(
            content=ft.Row(
                controls=[
                    cover_image,
                    ft.Column(
                        controls=[
                            *badges,
                            ft.Text(
                                short_title,
                                size=16,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                                max_lines=2,
                                overflow=ft.TextOverflow.ELLIPSIS,
                            ),
                            ft.Text(
                                q.human_date or "",
                                size=12,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                weight=ft.FontWeight.W_500,
                            ),
                            ft.Text(
                                q.description or "",
                                size=12,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                max_lines=2,
                                overflow=ft.TextOverflow.ELLIPSIS,
                            ),
                            ft.Row(
                                controls=[
                                    ft.FilledTonalButton(
                                        "Estudar Trimestre" if not is_selected else "Continuar Estudo",
                                        icon=ft.Icons.AUTO_STORIES_ROUNDED if not is_selected else ft.Icons.PLAY_ARROW_ROUNDED,
                                        on_click=lambda e, quarterly=q: self.page.run_task(
                                            self._select_quarterly, quarterly
                                        ),
                                    ),
                                ],
                                alignment=ft.MainAxisAlignment.START,
                            ),
                        ],
                        spacing=6,
                        expand=True,
                        alignment=ft.MainAxisAlignment.CENTER,
                    ),
                ],
                spacing=14,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border=(
                ft.Border.all(2, ft.Colors.PRIMARY)
                if is_selected
                else ft.Border.all(1, ft.Colors.OUTLINE_VARIANT)
            ),
            border_radius=14,
            padding=ft.Padding.all(12),
            ink=True,
            on_click=lambda e, quarterly=q: self.page.run_task(self._select_quarterly, quarterly),
        )

        return card_content

    def _build_carousel_card(self, q: SSQuarterly) -> ft.Container:
        """Constrói card de capa vertical estilo livro (aspect ratio ~1:1.4) para a galeria Netflix/Adventech."""
        is_selected = (self.active_quarterly_id == q.id)
        short_title = q.title.split(":")[0].strip() if q.title else "Lição"

        cover_img = ft.Image(
            src=q.cover or "",
            width=120,
            height=168,
            fit=ft.BoxFit.COVER,
            border_radius=10,
            error_content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Icon(ft.Icons.MENU_BOOK_ROUNDED, size=32, color=ft.Colors.PRIMARY),
                        ft.Text("Sem Capa", size=10, color=ft.Colors.ON_SURFACE_VARIANT),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=4,
                ),
                width=120,
                height=168,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
                border_radius=10,
                alignment=ft.Alignment.CENTER,
            ),
        )

        badge_selected = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.CHECK_CIRCLE_ROUNDED, size=11, color=ft.Colors.ON_PRIMARY),
                    ft.Text("Atual", size=10, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_PRIMARY),
                ],
                spacing=2,
                tight=True,
            ),
            bgcolor=ft.Colors.PRIMARY,
            border_radius=6,
            padding=ft.Padding.symmetric(horizontal=6, vertical=2),
            visible=is_selected,
        )

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Stack(
                        controls=[
                            cover_img,
                            ft.Container(
                                content=badge_selected,
                                top=6,
                                right=6,
                            ),
                        ],
                    ),
                    ft.Container(
                        content=ft.Column(
                            controls=[
                                ft.Text(
                                    short_title,
                                    size=12,
                                    weight=ft.FontWeight.BOLD,
                                    color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                                    max_lines=2,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                                ft.Text(
                                    q.human_date or "",
                                    size=10,
                                    color=ft.Colors.ON_SURFACE_VARIANT,
                                    weight=ft.FontWeight.W_500,
                                    max_lines=1,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                            ],
                            spacing=2,
                        ),
                        width=120,
                        padding=ft.Padding.only(top=4),
                    ),
                ],
                spacing=4,
                horizontal_alignment=ft.CrossAxisAlignment.START,
            ),
            width=132,
            padding=ft.Padding.all(6),
            border_radius=12,
            bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border=ft.Border.all(2, ft.Colors.PRIMARY) if is_selected else ft.Border.all(1, ft.Colors.OUTLINE_VARIANT),
            ink=True,
            on_click=lambda e, quarterly=q: self.page.run_task(self._select_quarterly, quarterly),
            tooltip=f"{q.title}\n{q.human_date or ''}\nToque para estudar este trimestre",
        )

    def _update_ui(self) -> None:
        """Atualiza os controles visuais com as galerias carrossel estilo Netflix/Adventech."""
        if not self.grid_container or not self.page:
            return

        if self.is_loading:
            self.grid_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.ProgressRing(),
                            ft.Text("Carregando lições trimestrais...", size=13, color=ft.Colors.ON_SURFACE_VARIANT),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=12,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(40),
                )
            ]
            self.page.update()
            return

        if not self.quarterlies and not self.adultos_quarterlies and not self.jovens_quarterlies:
            self.grid_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Icon(ft.Icons.AUTO_STORIES_ROUNDED, size=48, color=ft.Colors.OUTLINE),
                            ft.Text(
                                "Nenhuma lição trimestral encontrada.",
                                size=15,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.ON_SURFACE,
                            ),
                            ft.Text(
                                "Verifique sua conexão para baixar a lista de trimestres.",
                                size=13,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                            ),
                            ft.FilledButton(
                                "Tentar novamente",
                                icon=ft.Icons.REFRESH,
                                on_click=lambda e: self.page.run_task(self.load_quarterlies, True),
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=10,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(40),
                )
            ]
            self.page.update()
            return

        def _build_gallery_section(title: str, subtitle: str, q_list: list[SSQuarterly], icon: ft.IconData) -> ft.Container:
            cards = [self._build_carousel_card(q) for q in q_list]
            return ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(icon, size=20, color=ft.Colors.PRIMARY),
                                ft.Text(title, size=16, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
                                ft.Container(expand=True),
                                ft.Text(subtitle, size=11, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=6,
                        ),
                        ft.Row(
                            controls=cards,
                            scroll=ft.ScrollMode.AUTO,
                            spacing=12,
                        ),
                    ],
                    spacing=10,
                ),
                padding=ft.Padding.symmetric(vertical=8),
            )

        # Seção 1: Lição Adultos
        adultos_list = self.adultos_quarterlies if self.adultos_quarterlies else [q for q in self.quarterlies if q.category == "adultos"]
        # Seção 2: Lição Jovens (ComTexto)
        jovens_list = self.jovens_quarterlies if self.jovens_quarterlies else [q for q in self.quarterlies if q.category == "jovens"]

        section_adultos = _build_gallery_section("Lição Adultos", "Edição Geral", adultos_list, ft.Icons.MENU_BOOK_ROUNDED)
        section_jovens = _build_gallery_section("Lição Jovens (ComTexto)", "Edição Universitária / Jovem", jovens_list, ft.Icons.AUTO_STORIES_ROUNDED)

        sections = []
        if self.category == "adultos":
            sections.extend([section_adultos, ft.Divider(height=16), section_jovens])
        else:
            sections.extend([section_jovens, ft.Divider(height=16), section_adultos])

        self.grid_container.controls = [
            ft.Container(
                content=ft.Column(
                    controls=sections,
                    spacing=12,
                ),
                padding=ft.Padding.symmetric(vertical=8),
            )
        ]
        self.page.update()

    def build(self, page: ft.Page) -> ft.View:
        """Gera e retorna a visualização Flet (ft.View)."""
        self.page = page
        self.grid_container = ft.Column(
            controls=[],
            scroll=ft.ScrollMode.AUTO,
            expand=True,
            spacing=10,
        )

        # Dispara carregamento inicial
        page.run_task(self._init_and_load)

        p_width = getattr(page, "width", None)
        content_width = min(p_width, 680) if isinstance(p_width, (int, float)) and p_width > 0 else None

        centered_layout = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Container(
                        content=ft.Row(
                            controls=[
                                ft.Container(expand=True),
                                ft.IconButton(
                                    ft.Icons.REFRESH,
                                    tooltip="Recarregar trimestres online",
                                    on_click=lambda e: self.page.run_task(self.load_quarterlies, True),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.END,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        padding=ft.Padding.symmetric(horizontal=16, vertical=4),
                    ),
                    ft.Divider(height=1),
                    ft.Container(
                        content=self.grid_container,
                        padding=ft.Padding.symmetric(horizontal=16),
                        expand=True,
                    ),
                ],
                spacing=0,
                expand=True,
            ),
            width=content_width,
            alignment=ft.Alignment.TOP_CENTER,
            expand=True,
        )

        return ft.View(
            route="/escola-sabatina/trimestres",
            appbar=ft.AppBar(
                title=ft.Text("Lições Trimestrais", weight=ft.FontWeight.BOLD),
                center_title=True,
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    tooltip="Voltar para o estudo",
                    on_click=lambda e: asyncio.create_task(page.push_route("/escola-sabatina")),
                ),
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Container(
                        content=centered_layout,
                        alignment=ft.Alignment.TOP_CENTER,
                        expand=True,
                    ),
                    expand=True,
                )
            ],
        )

    async def _init_and_load(self) -> None:
        """Método de inicialização executado no carregamento da View."""
        await self._load_preferences()
        if self.category_segmented:
            self.category_segmented.selected = [self.category]
            try:
                self.category_segmented.update()
            except Exception:
                pass
        await self.load_quarterlies(force_refresh=False)
