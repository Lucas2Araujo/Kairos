"""
src/views/busca_resultados_view.py

Tela completa de resultados da busca unificada (/busca?q={query}).
Suporta:
- Paginação / Infinite scrolling (lazy loading com limit e offset)
- Filtragem por abas/seções de tipos de conteúdo (Todos, Hinos, Bíblia, Meditação, Lição) com contadores
- Identificação visual imediata (ícones e cores por tipo de conteúdo)
- Campo de pesquisa ativo com busca em tempo real / re-pesquisa
"""

from __future__ import annotations

import asyncio
import logging
import urllib.parse
from typing import Any

import flet as ft

from src.services.search_service import SearchContentType, SearchResultItem, SearchService
from src.services.theme_service import ThemeService
from src.theme.glass_styles import get_liquid_glass_background_gradient
from src.theme.palette import ThemeModeType, ThemePalette, get_palette

logger = logging.getLogger(__name__)

PAGE_SIZE = 20


class BuscaResultadosView:
    """
    View responsável por exibir resultados paginados e agrupados da pesquisa global.
    """

    def __init__(
        self,
        search_service: SearchService,
        theme_service: ThemeService | None = None,
    ):
        self.search_service = search_service
        self.theme_service = theme_service

        self.page: ft.Page | None = None
        self.query: str = ""
        self.current_tab: str = "todos"  # "todos", "hino", "biblia", "meditacao", "licao"
        self.current_offset: int = 0
        self.is_loading: bool = False
        self.has_more: bool = True
        self.items: list[SearchResultItem] = []
        self.counts_by_type: dict[str, int] = {t.value: 0 for t in SearchContentType}
        self.total_count: int = 0

        # UI controls
        self.search_field: ft.TextField | None = None
        self.tabs_row: ft.Row | None = None
        self.list_view: ft.ListView | None = None
        self.loading_indicator: ft.ProgressRing | None = None
        self.load_more_btn: ft.OutlinedButton | None = None
        self.empty_state_container: ft.Container | None = None
        self.stats_text: ft.Text | None = None

    def _get_palette(self) -> ThemePalette:
        if self.theme_service and hasattr(self.theme_service, "theme_engine"):
            return self.theme_service.theme_engine.get_current_palette()
        return get_palette(is_dark=False)

    def _get_icon_for_type(self, icon_name: str) -> ft.Icons:
        if icon_name == "music_note":
            return ft.Icons.MUSIC_NOTE
        elif icon_name == "menu_book":
            return ft.Icons.MENU_BOOK
        elif icon_name == "favorite_outline":
            return ft.Icons.FAVORITE_BORDER
        elif icon_name == "school":
            return ft.Icons.SCHOOL
        return ft.Icons.SEARCH

    def _get_badge_color_for_type(self, ctype: SearchContentType, palette: ThemePalette) -> str:
        if ctype == SearchContentType.HINO:
            return palette.primary
        elif ctype == SearchContentType.BIBLIA:
            return "#3B82F6"  # Blue
        elif ctype == SearchContentType.MEDITACAO:
            return "#EC4899"  # Rose
        elif ctype == SearchContentType.LICAO:
            return "#10B981"  # Emerald
        return palette.primary

    async def _navigate_to_item(self, route: str) -> None:
        if not self.page:
            return
        if hasattr(self.page, "push_route"):
            await self.page.push_route(route)
        elif hasattr(self.page, "go"):
            self.page.go(route)

    def _build_result_card(self, item: SearchResultItem, palette: ThemePalette) -> ft.Control:
        accent = self._get_badge_color_for_type(item.content_type, palette)
        icon_glyph = self._get_icon_for_type(item.icon_name)

        return ft.Container(
            content=ft.ListTile(
                leading=ft.Container(
                    content=ft.Icon(icon_glyph, size=18, color=accent),
                    bgcolor=ft.Colors.with_opacity(0.12, accent),
                    padding=ft.Padding.all(10),
                    border_radius=8,
                    alignment=ft.Alignment.CENTER,
                    width=42,
                    height=42,
                ),
                title=ft.Row(
                    controls=[
                        ft.Text(
                            item.title,
                            size=14,
                            weight=ft.FontWeight.BOLD,
                            color=palette.text_primary,
                            expand=True,
                        ),
                        ft.Container(
                            content=ft.Text(
                                item.type_label.upper(),
                                size=9,
                                weight=ft.FontWeight.BOLD,
                                color=accent,
                            ),
                            bgcolor=ft.Colors.with_opacity(0.12, accent),
                            padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                            border_radius=4,
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                ),
                subtitle=ft.Text(
                    item.subtitle,
                    size=12,
                    color=palette.text_secondary,
                    max_lines=3,
                    overflow=ft.TextOverflow.ELLIPSIS,
                ),
                trailing=ft.Icon(ft.Icons.CHEVRON_RIGHT, size=18, color=palette.text_secondary),
                on_click=lambda e, r=item.route: asyncio.create_task(self._navigate_to_item(r)),
            ),
            bgcolor=palette.surface_container_high,
            border_radius=12,
            padding=ft.Padding.symmetric(vertical=4, horizontal=2),
        )

    def _update_tabs_ui(self, palette: ThemePalette) -> None:
        if not self.tabs_row:
            return

        tab_defs = [
            ("todos", "Todos", self.total_count),
            ("hino", "Hinos", self.counts_by_type.get("hino", 0)),
            ("biblia", "Bíblia", self.counts_by_type.get("biblia", 0)),
            ("meditacao", "Meditação", self.counts_by_type.get("meditacao", 0)),
            ("licao", "Lição", self.counts_by_type.get("licao", 0)),
        ]

        chips: list[ft.Control] = []
        for key, label, count in tab_defs:
            is_selected = self.current_tab == key
            count_str = f" ({count})" if count > 0 else ""
            chip = ft.Container(
                content=ft.Text(
                    f"{label}{count_str}",
                    size=12,
                    weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.NORMAL,
                    color=palette.surface if is_selected else palette.text_primary,
                ),
                bgcolor=palette.primary if is_selected else palette.surface_container_high,
                padding=ft.Padding.symmetric(horizontal=12, vertical=6),
                border_radius=16,
                ink=True,
                on_click=lambda e, k=key: asyncio.create_task(self._on_tab_clicked(k)),
            )
            chips.append(chip)

        self.tabs_row.controls = chips

    async def _on_tab_clicked(self, tab_key: str) -> None:
        if self.current_tab == tab_key:
            return
        self.current_tab = tab_key
        self.current_offset = 0
        self.items = []
        self.has_more = True
        await self._load_results(reset=True)

    async def _load_results(self, reset: bool = False) -> None:
        if self.is_loading:
            return

        self.is_loading = True
        palette = self._get_palette()

        if self.loading_indicator:
            self.loading_indicator.visible = True
        if self.load_more_btn:
            self.load_more_btn.visible = False
        if self.page:
            self.page.update()

        type_filter = None if self.current_tab == "todos" else self.current_tab

        try:
            results_page = await self.search_service.search(
                query=self.query,
                limit=PAGE_SIZE,
                offset=self.current_offset,
                type_filter=type_filter,
            )

            if reset:
                self.items = results_page.items
                if self.current_tab == "todos":
                    self.counts_by_type = results_page.counts_by_type
                    self.total_count = results_page.total_count
            else:
                self.items.extend(results_page.items)

            self.current_offset += len(results_page.items)
            self.has_more = results_page.has_more

        except Exception as exc:
            logger.exception("Erro ao carregar resultados de busca: %s", exc)
            self.has_more = False

        self.is_loading = False

        # Atualiza a UI
        if self.loading_indicator:
            self.loading_indicator.visible = False

        self._update_tabs_ui(palette)

        if self.stats_text:
            display_count = self.total_count if self.current_tab == "todos" else self.counts_by_type.get(self.current_tab, 0)
            self.stats_text.value = f"{display_count} resultado(s) para \"{self.query}\""
            self.stats_text.visible = bool(self.query)

        if self.list_view:
            if not self.items:
                self.list_view.visible = False
                if self.empty_state_container:
                    self.empty_state_container.visible = True
            else:
                cards = [self._build_result_card(item, palette) for item in self.items]
                self.list_view.controls = cards
                self.list_view.visible = True
                if self.empty_state_container:
                    self.empty_state_container.visible = False

        if self.load_more_btn:
            self.load_more_btn.visible = self.has_more and len(self.items) > 0

        if self.page:
            self.page.update()

    async def _on_search_submitted(self, new_query: str) -> None:
        clean = new_query.strip()
        if clean == self.query:
            return
        self.query = clean
        self.current_offset = 0
        self.items = []
        self.has_more = True
        await self._load_results(reset=True)

    async def build(self, page: ft.Page, initial_query: str = "") -> ft.View:
        self.page = page
        self.query = initial_query.strip()
        self.current_offset = 0
        self.current_tab = "todos"
        self.items = []
        self.has_more = True

        palette = self._get_palette()
        is_glass = (
            self.theme_service
            and hasattr(self.theme_service, "theme_engine")
            and getattr(self.theme_service.theme_engine, "theme_style", None) == ThemeModeType.LIQUID_GLASS
        )
        is_dark = (
            self.theme_service.theme_engine.is_dark
            if self.theme_service and hasattr(self.theme_service, "theme_engine")
            else False
        )

        self.search_field = ft.TextField(
            value=self.query,
            hint_text="Buscar em hinos, bíblia, meditações e lições...",
            prefix_icon=ft.Icons.SEARCH,
            dense=True,
            border_radius=12,
            expand=True,
            on_submit=lambda e: asyncio.create_task(self._on_search_submitted(e.control.value or "")),
        )

        self.tabs_row = ft.Row(
            controls=[],
            scroll=ft.ScrollMode.AUTO,
            spacing=8,
        )

        self.stats_text = ft.Text(
            f"Buscando \"{self.query}\"...",
            size=12,
            color=palette.text_secondary,
            visible=bool(self.query),
        )

        self.list_view = ft.ListView(
            controls=[],
            spacing=8,
            expand=True,
            padding=ft.Padding.only(top=4, bottom=16),
        )

        self.loading_indicator = ft.ProgressRing(width=28, height=28, color=palette.primary, visible=False)

        self.load_more_btn = ft.OutlinedButton(
            text="Carregar mais resultados",
            icon=ft.Icons.EXPAND_MORE,
            visible=False,
            on_click=lambda e: asyncio.create_task(self._load_results(reset=False)),
        )

        self.empty_state_container = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Icon(ft.Icons.SEARCH_OFF, size=48, color=palette.text_secondary),
                    ft.Text("Nenhum resultado encontrado", size=15, weight=ft.FontWeight.BOLD, color=palette.text_primary),
                    ft.Text("Tente buscar por outras palavras, números de hinos ou referências bíblicas.", size=12, color=palette.text_secondary),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=8,
            ),
            alignment=ft.Alignment.CENTER,
            expand=True,
            visible=False,
            padding=ft.Padding.all(32),
        )

        self._update_tabs_ui(palette)

        root_content = ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        self.search_field,
                        ft.IconButton(
                            ft.Icons.SEARCH,
                            tooltip="Pesquisar",
                            on_click=lambda e: asyncio.create_task(
                                self._on_search_submitted(self.search_field.value or "")
                            ),
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                ),
                self.tabs_row,
                ft.Row(
                    controls=[
                        self.stats_text,
                        ft.Container(expand=True),
                        self.loading_indicator,
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                ),
                ft.Divider(height=1),
                ft.Container(
                    content=ft.Stack(
                        controls=[
                            self.list_view,
                            self.empty_state_container,
                        ],
                        expand=True,
                    ),
                    expand=True,
                ),
                ft.Container(
                    content=self.load_more_btn,
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.only(top=6, bottom=12),
                ),
            ],
            spacing=10,
            expand=True,
        )

        root_container = ft.Container(
            content=root_content,
            padding=ft.Padding.symmetric(horizontal=16, vertical=10),
            gradient=(
                get_liquid_glass_background_gradient(is_dark)
                if is_glass
                else None
            ),
            expand=True,
        )

        # Dispara busca inicial em segundo plano se houver query
        if self.query:
            page.run_task(lambda: self._load_results(reset=True))

        return ft.View(
            route="/busca",
            bgcolor=palette.background,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    tooltip="Voltar",
                    on_click=lambda e: asyncio.create_task(page.push_route("/"))
                    if hasattr(page, "push_route")
                    else (getattr(page, "go", lambda r: None)("/")),
                ),
                title=ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.SEARCH, size=20, color=palette.primary),
                        ft.Text("Resultados da Busca", weight=ft.FontWeight.BOLD, size=18),
                    ],
                    spacing=8,
                    tight=True,
                ),
                bgcolor=palette.surface,
                center_title=False,
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=root_container,
                    expand=True,
                )
            ],
        )
