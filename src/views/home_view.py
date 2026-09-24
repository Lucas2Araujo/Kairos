import asyncio
import re
from typing import Any
import unicodedata

import flet as ft

from src.models.hino import Hino
from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.hino_repository import HinoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.services.theme_service import ThemeService
from src.services.updater_service import UpdaterService
from src.theme import ThemeEngine, ThemeModeType
from src.theme.palette import create_empty_state_container
from src.views.settings_dialog import show_settings_dialog
from src.views.update_dialog import show_update_dialog

try:
    from src.version import __version__ as APP_VERSION
except ImportError:
    APP_VERSION = "0.4.20"


def parse_hino_number(numero: str) -> float:
    """
    Converte o número do hino (ex: '587', '587_A', '587A', '587_B', '587.1', '587.2')
    para um número float comparável para ordenação numérica precisa.
    """
    if not numero:
        return 0.0

    clean = numero.strip()
    match = re.match(r"^(\d+)(?:[._-]?([A-Za-z0-9]+))?", clean)
    if match:
        main_num = float(match.group(1))
        sub = match.group(2)
        if sub:
            if sub.isdigit():
                return main_num + (float(sub) / 10.0)
            else:
                sub_val = (ord(sub[0].upper()) - ord("A") + 1) / 10.0
                return main_num + sub_val
        return main_num
    try:
        return float(clean)
    except ValueError:
        return 0.0


def format_hino_number(numero: str) -> str:
    """Formata '587_A' -> '587A' e '587_B' -> '587B' para exibição na UI."""
    if not numero:
        return ""
    return numero.replace("_", "").strip()


def strip_accents(s: str) -> str:
    return unicodedata.normalize("NFKD", s).encode("ASCII", "ignore").decode("utf-8")


TOOLTIP_LIMPAR_BUSCA = "Limpar busca"


class HomeView:
    """
    Interface da Home do Kairós.
    Funcionalidades:
    - Lista rolável virtualizada (ft.ListView) com 601 hinos
    - Busca full-text via FTS5 (letra, temas, categorias, textos bíblicos)
    - Abas: Todos | Favoritos | Recentes | Explorar (categorias/temas)
    - Loading state com ProgressRing no primeiro carregamento
    - Empty states ilustrados para Favoritos/Recentes vazios
    - Modal "Sobre o App" com informações da versão e Toggle AMOLED
    - Suporte a temas dinâmicos (Sistema / AMOLED)
    Segue as diretrizes do Flet 0.85+.
    """

    def __init__(
        self,
        hino_repository: HinoRepository,
        favorito_repository: FavoritoRepository,
        historico_repository: HistoricoRepository,
        updater_service: UpdaterService | None = None,
        theme_service: ThemeService | None = None,
        edition: str = "novo",
        novo_hino_repo: HinoRepository | None = None,
        novo_fav_repo: FavoritoRepository | None = None,
        novo_hist_repo: HistoricoRepository | None = None,
        antigo_hino_repo: HinoRepository | None = None,
        antigo_fav_repo: FavoritoRepository | None = None,
        antigo_hist_repo: HistoricoRepository | None = None,
        theme_engine: ThemeEngine | None = None,
    ):
        self.hino_repository = hino_repository
        self.favorito_repository = favorito_repository
        self.historico_repository = historico_repository
        self.updater_service = updater_service or UpdaterService()
        self.theme_service = theme_service or ThemeService(
            hino_repository.db_connection
        )
        self.theme_engine = (
            theme_engine
            or getattr(self.theme_service, "theme_engine", None)
            or ThemeEngine()
        )
        self.edition: str = edition

        if novo_hino_repo and novo_fav_repo and novo_hist_repo:
            self._novo_repos = (novo_hino_repo, novo_fav_repo, novo_hist_repo)
        elif edition == "novo":
            self._novo_repos = (hino_repository, favorito_repository, historico_repository)
        else:
            self._novo_repos = None

        if antigo_hino_repo and antigo_fav_repo and antigo_hist_repo:
            self._antigo_repos = (antigo_hino_repo, antigo_fav_repo, antigo_hist_repo)
        elif edition == "antigo":
            self._antigo_repos = (hino_repository, favorito_repository, historico_repository)
        else:
            self._antigo_repos = None

        self._search_task: asyncio.Task | None = None
        self._sort_task: asyncio.Task | None = None
        self._filtered_hinos: list[Hino] = []
        self._rendered_count: int = 0
        self._page_size: int = 40
        self._is_loading_more: bool = False
        self.current_filter: str = "todos"
        self.current_search: str = ""
        self.current_sort: str = "num_asc"
        self.active_category: str | None = None
        self.active_tema: str | None = None
        self.origin_hino_id: int | None = None
        self.page: ft.Page | None = None
        self.list_container: ft.ListView | None = None
        self.explore_container: ft.Column | None = None
        self.search_field: ft.TextField | None = None
        self.sort_button: ft.PopupMenuButton | None = None
        self.filter_bar: ft.SegmentedButton | None = None
        self.active_filter_banner: ft.Container | None = None
        self._explore_sections_cached: list[ft.Control] | None = None
        self._cached_view: ft.View | None = None

    async def build(
        self,
        page: ft.Page,
        initial_search: str = "",
        initial_categoria: str | None = None,
        initial_tema: str | None = None,
        origin_hino_id: int | None = None,
        initial_filtro: str | None = None,
        **kwargs: Any,
    ) -> ft.View:
        self.page = page
        edition_title = (
            "Hinário Novo" if self.edition == "novo" else "Hinário Tradicional"
        )
        self.page.title = f"{edition_title} - v{APP_VERSION}"

        if self.theme_service:
            self.theme_service.apply_theme(page, edition=self.edition)

        # Se já tivermos a view construída, aplicamos o filtro recebido ou retornamos o cache
        if self._cached_view is not None:
            if initial_filtro:
                await self._filter_by_filtro(initial_filtro)
                return self._cached_view
            elif initial_categoria:
                await self._filter_by_categoria(
                    initial_categoria, origin_hino_id=origin_hino_id
                )
                return self._cached_view
            elif initial_tema:
                await self._filter_by_tema(initial_tema, origin_hino_id=origin_hino_id)
                return self._cached_view
            elif initial_search:
                self.origin_hino_id = None
                self.current_search = initial_search
                if self.search_field:
                    self.search_field.value = initial_search
                    self.search_field.suffix = ft.IconButton(
                        ft.Icons.CLEAR,
                        on_click=self._clear_search,
                        tooltip=TOOLTIP_LIMPAR_BUSCA,
                        icon_size=18,
                    )
                self.current_filter = "todos"
                if self.filter_bar:
                    self.filter_bar.selected = ["todos"]
                self._show_content_view("list")
                await self._load_current_filter_data(initial_search)
                return self._cached_view
            return self._cached_view

        if initial_filtro:
            self.current_filter = initial_filtro
            self.active_category = None
            self.active_tema = None
            self.origin_hino_id = None
        elif initial_categoria:
            self.current_filter = "categoria"
            self.active_category = initial_categoria
            self.active_tema = None
            self.origin_hino_id = origin_hino_id
        elif initial_tema:
            self.current_filter = "tema"
            self.active_tema = initial_tema
            self.active_category = None
            self.origin_hino_id = origin_hino_id
        elif initial_search:
            self.current_search = initial_search
            self.current_filter = "todos"
            self.origin_hino_id = None

        self.list_container = ft.ListView(
            controls=[],
            expand=True,
            spacing=2,
            padding=ft.Padding.symmetric(horizontal=12, vertical=6),
            visible=True,
            on_scroll=self._on_scroll,
        )

        self.explore_container = ft.Column(
            controls=[],
            scroll=ft.ScrollMode.AUTO,
            expand=True,
            spacing=10,
            visible=False,
        )

        # Loading state inicial
        self.list_container.controls = [
            ft.Container(
                content=ft.Column(
                    controls=[
                        ft.ProgressRing(),
                        ft.Text("Carregando hinos...", size=14, italic=True),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=10,
                ),
                alignment=ft.Alignment.CENTER,
                padding=ft.Padding.all(40),
            )
        ]

        self.active_filter_banner = ft.Container(
            visible=False,
            padding=ft.Padding.symmetric(horizontal=16, vertical=2),
        )

        self.search_field = ft.TextField(
            hint_text="Pesquisar hinos, letra, temas...",
            prefix_icon=ft.Icons.SEARCH,
            suffix=(
                ft.IconButton(
                    ft.Icons.CLEAR,
                    on_click=self._clear_search,
                    tooltip=TOOLTIP_LIMPAR_BUSCA,
                    icon_size=18,
                )
                if self.current_search
                else None
            ),
            on_change=self._on_search_change,
            border_radius=12,
            expand=True,
            content_padding=ft.Padding.symmetric(vertical=12, horizontal=16),
            dense=True,
        )

        self.sort_button = ft.PopupMenuButton(
            icon=ft.Icons.SORT,
            tooltip="Modo de Ordenação",
            items=self._build_sort_menu_items(),
        )

        selected_segment = (
            "explorar"
            if self.current_filter in ("categoria", "tema")
            else self.current_filter
        )
        self.filter_bar = ft.SegmentedButton(
            selected=(
                [selected_segment]
                if selected_segment in ("todos", "favoritos", "recentes", "explorar")
                else []
            ),
            allow_empty_selection=True,
            show_selected_icon=False,
            segments=[
                ft.Segment(value="todos", label=ft.Text("Todos", size=13)),
                ft.Segment(value="favoritos", label=ft.Text("Favoritos", size=13)),
                ft.Segment(value="recentes", label=ft.Text("Recentes", size=13)),
                ft.Segment(value="explorar", label=ft.Text("Explorar", size=13)),
            ],
            on_change=self._on_filter_select,
            expand=True,
        )

        await self._load_current_filter_data(self.current_search)


        self.main_content_container = ft.Container(
            content=ft.Column(
                controls=[
                    self.list_container,
                    self.explore_container,
                ],
                expand=True,
            ),
            expand=True,
            padding=ft.Padding.symmetric(horizontal=4, vertical=4),
        )

        palette = self.theme_engine.get_current_palette()
        badge_year = "2022" if self.edition == "novo" else "1996"
        if self.edition == "novo":
            badge_color = (
                self.theme_service.get_accent_color()
                if self.theme_service
                else palette.primary
            )
        else:
            badge_color = palette.primary

        is_material = self.theme_engine.theme_style == ThemeModeType.MATERIAL_YOU

        edition_selector = ft.PopupMenuButton(
            content=ft.Row(
                controls=[
                    ft.Text(edition_title, weight=ft.FontWeight.BOLD, color=palette.text_primary),
                    ft.Container(
                        content=ft.Text(
                            badge_year,
                            size=11,
                            color=badge_color,
                            weight=ft.FontWeight.BOLD,
                        ),
                        bgcolor=palette.surface_container_high,
                        border_radius=4,
                        padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                    ),
                    ft.Icon(
                        ft.Icons.KEYBOARD_ARROW_DOWN_ROUNDED,
                        size=18,
                        color=palette.text_secondary,
                    ),
                ],
                spacing=6,
                alignment=ft.MainAxisAlignment.CENTER,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                tight=True,
            ),
            items=[
                ft.PopupMenuItem(
                    content=ft.Text("Hinário Novo (2022)"),
                    icon=ft.Icons.CHECK if self.edition == "novo" else ft.Icons.MUSIC_NOTE,
                    on_click=lambda e: self._on_edition_select("novo"),
                ),
                ft.PopupMenuItem(
                    content=ft.Text("Hinário Tradicional (1996)"),
                    icon=ft.Icons.CHECK if self.edition == "antigo" else ft.Icons.MENU_BOOK,
                    on_click=lambda e: self._on_edition_select("antigo"),
                ),
            ],
            tooltip="Alternar Edição do Hinário",
        )

        self._cached_view = ft.View(
            route=f"/{self.edition}",
            bgcolor=ft.Colors.SURFACE if is_material else palette.background,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    tooltip="Voltar ao Menu Principal",
                    on_click=lambda e: asyncio.create_task(self._navigate("/")),
                ),
                title=edition_selector,
                center_title=True,
                bgcolor=palette.surface,
                actions=[
                    self._build_action_button(
                        ft.Icons.SETTINGS_OUTLINED,
                        "Configurações e Temas",
                        self._show_about_dialog,
                    ),
                    self._build_action_button(
                        ft.Icons.DOWNLOAD_FOR_OFFLINE_OUTLINED,
                        "Gerenciar Downloads",
                        lambda e: asyncio.create_task(self._navigate("/downloads")),
                    ),
                ],
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Container(
                        content=ft.Column(
                            controls=[
                                ft.Container(
                                    content=ft.Row(
                                        controls=[
                                            self.search_field,
                                            self.sort_button,
                                        ],
                                        spacing=8,
                                    ),
                                    padding=ft.Padding.symmetric(horizontal=12, vertical=4),
                                ),
                                self.active_filter_banner,
                                ft.Container(
                                    content=ft.Row(
                                        controls=[self.filter_bar],
                                    ),
                                    padding=ft.Padding.symmetric(horizontal=12, vertical=4),
                                ),
                                self.main_content_container,
                            ],
                            expand=True,
                        ),
                        expand=True,
                    ),
                    expand=True,
                ),
            ],
        )
        return self._cached_view

    @staticmethod
    def _build_action_button(icon: Any, tooltip: str, on_click: Any) -> ft.IconButton:
        return ft.IconButton(
            icon=icon,
            tooltip=tooltip,
            on_click=on_click,
        )

    async def switch_edition(self, new_edition: str):
        """Alterna a edição de hinos assincronamente e recarrega os dados."""
        if new_edition not in ("novo", "antigo"):
            return
        self.edition = new_edition
        if new_edition == "novo" and self._novo_repos:
            self.hino_repository, self.favorito_repository, self.historico_repository = self._novo_repos
        elif new_edition == "antigo" and self._antigo_repos:
            self.hino_repository, self.favorito_repository, self.historico_repository = self._antigo_repos

        edition_title = (
            "Hinário Novo" if self.edition == "novo" else "Hinário Tradicional"
        )
        if self.page:
            self.page.title = f"{edition_title} - v{APP_VERSION}"
            if self.theme_service:
                self.theme_service.apply_theme(self.page, edition=self.edition)

        self._cached_view = None
        await self._load_current_filter_data(self.current_search)
        if self.page:
            try:
                self.page.update()
            except Exception:
                pass

    async def _navigate(self, route_path: str):
        if self.page:
            await self.page.push_route(route_path)

    def _on_edition_select(self, target_edition: str) -> None:
        """Navega para a edição selecionada caso não seja a atual, preservando lazy loading."""
        if self.edition != target_edition:
            asyncio.create_task(self._navigate(f"/{target_edition}"))

    async def _open_url(self, url: str):
        """Abre uma URL externa no navegador padrão ou app nativo."""
        try:
            await ft.UrlLauncher().launch_url(url)
        except Exception:
            pass

    def _show_about_dialog(self, e=None):
        if not self.page:
            return

        show_settings_dialog(
            page=self.page,
            theme_service=self.theme_service,
            updater_service=self.updater_service,
            edition=self.edition,
            on_check_updates=self._check_updates_manual,
        )

    async def _on_amoled_toggle(self, enabled: bool) -> None:
        """Manipula a alternância do Modo AMOLED."""
        if self.theme_service and self.page:
            await self.theme_service.toggle_amoled(
                self.page, enabled, edition=self.edition
            )

    def _show_snack(self, message: str, duration: int = 3000) -> None:
        """Exibe um SnackBar de forma segura compatível com o Flet."""
        if not self.page:
            return
        snack = ft.SnackBar(ft.Text(message), duration=duration)
        try:
            if hasattr(self.page, "open"):
                self.page.open(snack)
            elif hasattr(self.page, "show_snack_bar"):
                self.page.show_snack_bar(snack)
        except Exception:
            pass

    async def _check_updates_manual(self):
        """Verifica manualmente por atualizações a partir do modal Sobre."""
        if not self.page or not self.updater_service:
            return

        self._show_snack("Buscando atualizações no GitHub...", duration=2000)

        update_info = await self.updater_service.check_for_updates()
        if update_info.get("update_available"):
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            show_update_dialog(self.page, update_info, self.updater_service)
        else:
            err = update_info.get("error")
            msg = (
                f"Você já está na versão mais recente (v{APP_VERSION})!"
                if not err
                else f"Não foi possível verificar atualizações: {err}"
            )
            self._show_snack(msg, duration=3000)

    def _create_empty_state_control(self) -> ft.Container:
        if self.current_filter == "favoritos":
            icon = ft.Icons.FAVORITE_BORDER
            msg = "Nenhum hino favorito ainda."
            hint = "Toque no ❤️ na tela do hino para salvar seus favoritos!"
        elif self.current_filter == "recentes":
            icon = ft.Icons.HISTORY
            msg = "Nenhum hino acessado recentemente."
            hint = "Seus hinos acessados aparecerão aqui automaticamente."
        else:
            icon = ft.Icons.SEARCH_OFF
            msg = "Nenhum hino encontrado."
            hint = "Tente buscar por outro termo, número ou trecho da letra."

        return create_empty_state_container(
            icon=icon,
            title=msg,
            message=hint,
        )

    def _resolve_num_color(self) -> str:
        if self.edition == "novo":
            return (
                self.theme_service.get_accent_color()
                if self.theme_service
                else ft.Colors.PRIMARY
            )
        if self.theme_service and self.theme_service.is_amoled:
            return ft.Colors.PRIMARY
        return ft.Colors.TERTIARY

    def _create_hino_tile(self, hino: Hino, num_color: str) -> ft.Control:
        palette = self.theme_engine.get_current_palette()
        is_material = self.theme_engine.theme_style == ThemeModeType.MATERIAL_YOU
        return ft.ListTile(
            leading=ft.Container(
                content=ft.Text(
                    format_hino_number(hino.numero),
                    weight=ft.FontWeight.BOLD,
                    size=13,
                    color=num_color,
                ),
                width=52,
                height=36,
                border_radius=8,
                bgcolor=palette.surface_container_high,
                alignment=ft.Alignment.CENTER,
            ),
            title=ft.Text(
                hino.titulo,
                weight=ft.FontWeight.W_500,
                size=15,
                color=palette.text_primary,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_LOW if is_material else palette.surface,
            shape=ft.RoundedRectangleBorder(radius=12),
            hover_color=palette.surface_container_high,
            content_padding=ft.Padding.symmetric(horizontal=12, vertical=4),
            on_click=lambda e=None, h_id=hino.id: asyncio.create_task(
                self._navigate(f"/{self.edition}/hino/{h_id}")
            ),
        )

    def _render_hino_tiles(self, hinos: list[Hino]):
        if not self.list_container:
            return

        seen_ids = set()
        unique_hinos = []
        for h in hinos:
            if h.id is not None and h.id not in seen_ids:
                seen_ids.add(h.id)
                unique_hinos.append(h)

        self._filtered_hinos = unique_hinos
        self._rendered_count = 0
        self._is_loading_more = False

        if not unique_hinos:
            self.list_container.controls = [self._create_empty_state_control()]
            return

        accent_color = (
            self.theme_service.get_accent_color(self.edition)
            if self.theme_service
            else self.theme_engine.get_accent_color(self.edition)
        )
        initial_hinos = unique_hinos[: self._page_size]
        self.list_container.controls = [
            self._create_hino_tile(hino, accent_color) for hino in initial_hinos
        ]
        self._rendered_count = len(initial_hinos)

    def _on_scroll(self, e: ft.OnScrollEvent):
        """Detecta aproximação do final da lista e dispara carregamento do próximo lote."""
        if self._is_loading_more or not self.list_container:
            return
        if self._rendered_count >= len(self._filtered_hinos):
            return

        max_extent = getattr(e, "max_scroll_extent", 0.0) or 0.0
        pixels = getattr(e, "pixels", 0.0) or 0.0
        if max_extent > 0 and pixels >= max_extent - 200:
            self._load_next_chunk()

    def _load_next_chunk(self):
        """Carrega e anexa cirurgicamente a próxima página de hinos na ListView."""
        if self._is_loading_more or not self.list_container:
            return
        if self._rendered_count >= len(self._filtered_hinos):
            return

        self._is_loading_more = True
        try:
            accent_color = (
                self.theme_service.get_accent_color(self.edition)
                if self.theme_service
                else self.theme_engine.get_accent_color(self.edition)
            )
            next_batch = self._filtered_hinos[
                self._rendered_count : self._rendered_count + self._page_size
            ]
            if next_batch:
                new_tiles = [
                    self._create_hino_tile(hino, accent_color) for hino in next_batch
                ]
                self.list_container.controls.extend(new_tiles)
                self._rendered_count += len(new_tiles)
                try:
                    self.list_container.update()
                except Exception:
                    if self.page:
                        self.page.update()
        finally:
            self._is_loading_more = False

    def _build_explore_section(
        self,
        title: str,
        items: list[str],
        icon: ft.IconData,
        icon_color: str,
        on_item_click,
    ) -> ft.Container:
        palette = self.theme_engine.get_current_palette()
        chips: list[ft.Control] = [
            ft.Chip(
                label=ft.Text(item, size=12, color=palette.text_primary),
                leading=ft.Icon(icon, size=16, color=icon_color),
                bgcolor=palette.surface_container,
                on_click=lambda e=None, val=item: asyncio.create_task(
                    on_item_click(val)
                ),
            )
            for item in items
        ]
        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Text(title, weight=ft.FontWeight.BOLD, size=16, color=palette.text_primary),
                    ft.Row(controls=chips, wrap=True, spacing=6, run_spacing=6),
                ],
                spacing=8,
            ),
            padding=ft.Padding.symmetric(horizontal=16, vertical=8),
        )

    def _create_explore_empty_state(self) -> ft.Container:
        palette = self.theme_engine.get_current_palette()
        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Icon(ft.Icons.EXPLORE_OFF, size=48, color=palette.text_secondary),
                    ft.Text(
                        "Nenhuma categoria ou tema disponível.",
                        size=14,
                        color=palette.text_secondary,
                        italic=True,
                    ),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=8,
            ),
            alignment=ft.Alignment.CENTER,
            padding=ft.Padding.all(30),
        )

    async def _load_explore_data(self):
        """Carrega categorias e temas para a aba Explorar."""
        if not self.explore_container:
            return

        if self._explore_sections_cached:
            self.explore_container.controls = list(self._explore_sections_cached)
            if self.page:
                self.page.update()
            return

        self.explore_container.controls = [
            ft.Container(
                content=ft.ProgressRing(),
                alignment=ft.Alignment.CENTER,
                padding=ft.Padding.all(30),
            )
        ]
        if self.page:
            self.page.update()

        categorias = await self.hino_repository.get_categorias()
        temas = await self.hino_repository.get_temas()

        sections = []
        if categorias:
            sections.append(
                self._build_explore_section(
                    "📂 Categorias",
                    categorias,
                    ft.Icons.FOLDER_OUTLINED,
                    (
                        self.theme_service.get_accent_color()
                        if self.theme_service
                        else ft.Colors.PRIMARY
                    ),
                    self._filter_by_categoria,
                )
            )

        if temas:
            sections.append(
                self._build_explore_section(
                    "🏷️ Temas",
                    temas,
                    ft.Icons.LABEL_OUTLINED,
                    ft.Colors.TERTIARY,
                    self._filter_by_tema,
                )
            )

        if not sections:
            sections.append(self._create_explore_empty_state())

        self._explore_sections_cached = sections
        self.explore_container.controls = list(sections)
        if self.page:
            self.page.update()

    def _sort_hinos(self, hinos: list[Hino]) -> list[Hino]:
        """Ordena os hinos de acordo com o modo ativo em self.current_sort."""
        if not hinos:
            return []

        if self.current_sort == "num_desc":
            return sorted(
                hinos, key=lambda h: parse_hino_number(h.numero), reverse=True
            )
        elif self.current_sort == "title_asc":
            return sorted(hinos, key=lambda h: strip_accents(h.titulo.lower()))
        elif self.current_sort == "title_desc":
            return sorted(
                hinos, key=lambda h: strip_accents(h.titulo.lower()), reverse=True
            )
        else:  # "num_asc" (padrão)

            return sorted(hinos, key=lambda h: parse_hino_number(h.numero))

    def _build_sort_menu_items(self) -> list[ft.PopupMenuItem]:
        return [
            ft.PopupMenuItem(
                content=ft.Text("Número (Crescente 1 → N)"),
                icon=ft.Icons.ARROW_UPWARD,
                checked=self.current_sort == "num_asc",
                on_click=lambda e: self._on_sort_change("num_asc"),
            ),
            ft.PopupMenuItem(
                content=ft.Text("Número (Decrescente N → 1)"),
                icon=ft.Icons.ARROW_DOWNWARD,
                checked=self.current_sort == "num_desc",
                on_click=lambda e: self._on_sort_change("num_desc"),
            ),
            ft.PopupMenuItem(
                content=ft.Text("Título (A → Z)"),
                icon=ft.Icons.SORT_BY_ALPHA,
                checked=self.current_sort == "title_asc",
                on_click=lambda e: self._on_sort_change("title_asc"),
            ),
            ft.PopupMenuItem(
                content=ft.Text("Título (Z → A)"),
                icon=ft.Icons.SORT_BY_ALPHA,
                checked=self.current_sort == "title_desc",
                on_click=lambda e: self._on_sort_change("title_desc"),
            ),
        ]

    def _on_sort_change(self, new_sort: str):
        self.current_sort = new_sort
        if self.sort_button:
            self.sort_button.items = self._build_sort_menu_items()
        if self._sort_task and not self._sort_task.done():
            self._sort_task.cancel()
        self._sort_task = asyncio.create_task(self._execute_sort_update())

    async def _execute_sort_update(self):
        await self._load_current_filter_data(self.current_search)
        if self.page:
            self.page.update()

    def _build_banner_content(
        self,
        icon: Any,
        color: Any,
        text: str,
        btn_label: str,
        btn_action: Any,
        clear_tooltip: str,
    ) -> ft.Container:
        return ft.Container(
            bgcolor=ft.Colors.SURFACE_CONTAINER,
            border_radius=8,
            padding=ft.Padding.symmetric(horizontal=12, vertical=6),
            content=ft.Row(
                controls=[
                    ft.Icon(icon, size=18, color=color),
                    ft.Text(text, weight=ft.FontWeight.W_500, size=13, color=ft.Colors.ON_SURFACE, expand=True),
                    ft.TextButton(
                        content=ft.Text(btn_label),
                        icon=ft.Icons.ARROW_BACK,
                        on_click=btn_action,
                    ),
                    ft.IconButton(
                        icon=ft.Icons.CLOSE,
                        tooltip=clear_tooltip,
                        icon_size=18,
                        on_click=lambda e: asyncio.create_task(
                            self._clear_category_or_theme_filter()
                        ),
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
        )

    def _update_filter_banner(self, count: int = 0):
        """Atualiza a exibição do banner de filtro ativo (Categoria, Tema ou Especial)."""
        if not self.active_filter_banner:
            return

        is_categoria = self.current_filter == "categoria" and self.active_category
        is_tema = self.current_filter == "tema" and self.active_tema
        is_sabado = self.current_filter == "sabado"

        if not (is_categoria or is_tema or is_sabado):
            self.active_filter_banner.visible = False
            self.active_filter_banner.content = None
            return

        self.active_filter_banner.visible = True
        btn_label = "Voltar para o hino" if self.origin_hino_id else (
            "Explorar Categorias"
            if is_categoria
            else ("Explorar Temas" if is_tema else "Ver Todos")
        )
        btn_action = (
            (lambda e: asyncio.create_task(self._navigate_back_to_hino()))
            if self.origin_hino_id
            else (
                (lambda e: asyncio.create_task(self._return_to_explore()))
                if (is_categoria or is_tema)
                else (lambda e: asyncio.create_task(self._clear_category_or_theme_filter()))
            )
        )

        if is_categoria:
            icon = ft.Icons.FOLDER
            color = (
                self.theme_service.get_accent_color()
                if self.theme_service
                else ft.Colors.PRIMARY
            )
            text = f"Categoria: {self.active_category} ({count} hinos)"
            clear_tooltip = "Limpar filtro de categoria"
        elif is_tema:
            icon = ft.Icons.LABEL
            color = ft.Colors.TERTIARY
            text = f"Tema: {self.active_tema} ({count} hinos)"
            clear_tooltip = "Limpar filtro de tema"
        else:
            icon = ft.Icons.WB_SUNNY_OUTLINED
            color = ft.Colors.AMBER
            text = f"Hinos de Sábado ({count} hinos)"
            clear_tooltip = "Limpar filtro de sábado"

        self.active_filter_banner.content = self._build_banner_content(
            icon=icon,
            color=color,
            text=text,
            btn_label=btn_label,
            btn_action=btn_action,
            clear_tooltip=clear_tooltip,
        )

    async def _navigate_back_to_hino(self) -> None:
        """Navega de volta para o hino de onde o filtro se originou."""
        if self.page and self.origin_hino_id:
            hino_id = self.origin_hino_id
            await self.page.push_route(f"/{self.edition}/hino/{hino_id}")

    def _show_content_view(self, mode: str):
        """Alterna a visibilidade entre a listagem de hinos e o painel de exploração."""
        if not self.list_container or not self.explore_container:
            return
        if mode == "explorar":
            self.list_container.visible = False
            self.explore_container.visible = True
        else:
            self.list_container.visible = True
            self.explore_container.visible = False

    def _reset_search_state(self) -> None:
        """Limpa o campo de busca e o estado de pesquisa."""
        self.current_search = ""
        if self.search_field:
            self.search_field.value = ""
            self.search_field.suffix = None

    def _reset_filter_banner(self) -> None:
        """Oculta e limpa os filtros de categoria/tema."""
        self.active_category = None
        self.active_tema = None
        self.origin_hino_id = None
        if self.active_filter_banner:
            self.active_filter_banner.visible = False

    def _handle_empty_filter_selection(self) -> None:
        """Restaura o filtro quando ocorre desseleção acidental de aba."""
        if self.current_filter in ("categoria", "tema"):
            return
        valid_filters = ("todos", "favoritos", "recentes", "explorar")
        fallback = (
            self.current_filter if self.current_filter in valid_filters else "todos"
        )
        if self.filter_bar:
            self.filter_bar.selected = [fallback]
        if self.page:
            self.page.update()

    async def _return_to_explore(self):
        """Retorna para a visão geral de exploração de categorias e temas."""
        self._reset_filter_banner()
        self._reset_search_state()
        self.current_filter = "explorar"
        if self.filter_bar:
            self.filter_bar.selected = ["explorar"]
        if self.sort_button:
            self.sort_button.visible = False
        self._show_content_view("explorar")
        await self._load_explore_data()
        if self.page:
            self.page.update()

    async def _clear_category_or_theme_filter(self):
        """Limpa o filtro ativo de categoria/tema e volta para todos os hinos."""
        self._reset_filter_banner()
        self._reset_search_state()
        self.current_filter = "todos"
        if self.filter_bar:
            self.filter_bar.selected = ["todos"]
        if self.sort_button:
            self.sort_button.visible = True
        self._show_content_view("list")
        await self._load_current_filter_data("")
        if self.page:
            self.page.update()

    async def _filter_by_categoria(self, cat: str, origin_hino_id: int | None = None):
        """Filtra hinos por categoria e volta para lista."""
        self._reset_search_state()
        self.current_filter = "categoria"
        self.active_category = cat
        self.active_tema = None
        self.origin_hino_id = origin_hino_id
        if self.filter_bar:
            self.filter_bar.selected = ["explorar"]
        if self.sort_button:
            self.sort_button.visible = True
        self._show_content_view("list")

        await self._load_current_filter_data("")
        if self.page:
            self.page.update()

    async def _filter_by_tema(self, tema: str, origin_hino_id: int | None = None):
        """Filtra hinos por tema e volta para lista."""
        self._reset_search_state()
        self.current_filter = "tema"
        self.active_tema = tema
        self.active_category = None
        self.origin_hino_id = origin_hino_id
        if self.filter_bar:
            self.filter_bar.selected = ["explorar"]
        if self.sort_button:
            self.sort_button.visible = True
        self._show_content_view("list")

        await self._load_current_filter_data("")
        if self.page:
            self.page.update()

    async def _filter_by_filtro(self, filtro: str):
        """Filtra hinos por filtro especial (ex: 'sabado') e volta para lista."""
        self._reset_search_state()
        self.current_filter = filtro
        self.active_category = None
        self.active_tema = None
        self.origin_hino_id = None
        if self.filter_bar:
            selected_segment = (
                "explorar"
                if self.current_filter in ("categoria", "tema")
                else self.current_filter
            )
            self.filter_bar.selected = (
                [selected_segment]
                if selected_segment in ("todos", "favoritos", "recentes", "explorar")
                else []
            )
        if self.sort_button:
            self.sort_button.visible = True
        self._show_content_view("list")

        await self._load_current_filter_data("")
        if self.page:
            self.page.update()

    @staticmethod
    def _filter_by_text(hinos: list[Hino], search_term: str) -> list[Hino]:
        """Filtra lista em memória por termo de busca no número ou título."""
        if not search_term or not search_term.strip():
            return hinos
        term = search_term.lower().strip()
        return [
            h for h in hinos if term in h.numero.lower() or term in h.titulo.lower()
        ]

    async def _fetch_hinos_by_filter(
        self, search_term: str
    ) -> tuple[list[Hino], bool, int]:
        """Obtém hinos conforme o filtro ativo retornando (hinos, deve_ordenar, banner_count)."""
        if self.current_filter == "categoria" and self.active_category:
            hinos = await self.hino_repository.search_by_categoria(self.active_category)
            filtered = self._filter_by_text(hinos, search_term)
            return filtered, True, len(filtered)

        if self.current_filter == "tema" and self.active_tema:
            hinos = await self.hino_repository.search_by_tema(self.active_tema)
            filtered = self._filter_by_text(hinos, search_term)
            return filtered, True, len(filtered)

        if self.current_filter == "sabado":
            hinos = await self.hino_repository.get_sabado_hinos()
            filtered = self._filter_by_text(hinos, search_term)
            return filtered, True, len(filtered)

        if self.current_filter == "favoritos":
            hinos = await self._fetch_filtered_favoritos(search_term)
            return hinos, True, 0

        if self.current_filter == "recentes":
            hinos = await self._fetch_filtered_recentes(search_term)
            # Na aba Recentes, preserva estritamente a ordem cronológica
            return hinos, False, 0

        hinos = await self.hino_repository.search(search_term)
        return hinos, True, 0

    async def _load_current_filter_data(self, search_term: str = ""):
        hinos, should_sort, banner_count = await self._fetch_hinos_by_filter(
            search_term
        )
        self._update_filter_banner(banner_count)

        sorted_hinos = self._sort_hinos(hinos) if should_sort else hinos

        if self.sort_button:
            self.sort_button.visible = self.current_filter not in (
                "recentes",
                "explorar",
            )

        self._render_hino_tiles(sorted_hinos)

    async def _fetch_filtered_favoritos(self, search_term: str) -> list[Hino]:
        hinos = await self.favorito_repository.get_favoritos()
        return self._filter_by_text(hinos, search_term)

    async def _fetch_filtered_recentes(self, search_term: str) -> list[Hino]:
        hinos = await self.historico_repository.get_recentes()
        return self._filter_by_text(hinos, search_term)

    async def _execute_search(self, term: str, debounce: float = 0.25):
        if debounce > 0:
            await asyncio.sleep(debounce)
        await self._load_current_filter_data(term)
        if self.page:
            try:
                if self.list_container:
                    self.list_container.update()
                if self.active_filter_banner:
                    self.active_filter_banner.update()
            except Exception:
                self.page.update()

    def _clear_search(self, e=None):
        self.current_search = ""
        if self.search_field:
            self.search_field.value = ""
            self.search_field.suffix = None
        if self._search_task and not self._search_task.done():
            self._search_task.cancel()
        self._search_task = asyncio.create_task(self._execute_search("", debounce=0.0))

    def _on_search_change(self, e):
        term = e.control.value or ""
        self.current_search = term
        if term and self.current_filter in ("favoritos", "recentes", "explorar"):
            self.current_filter = "todos"
            self.active_category = None
            self.active_tema = None
            if self.active_filter_banner:
                self.active_filter_banner.visible = False
            if self.filter_bar:
                self.filter_bar.selected = ["todos"]
            if self.sort_button:
                self.sort_button.visible = True
            self._show_content_view("list")

        if self.search_field:
            self.search_field.value = term
            self.search_field.suffix = (
                ft.IconButton(
                    ft.Icons.CLEAR,
                    on_click=self._clear_search,
                    tooltip="Limpar busca",
                    icon_size=18,
                )
                if term
                else None
            )

        if self._search_task and not self._search_task.done():
            self._search_task.cancel()

        clean = term.strip()
        is_numeric = bool(clean and re.match(r"^\d+[A-Za-z]?$", clean))
        debounce_time = 0.0 if is_numeric or not clean else 0.25

        self._search_task = asyncio.create_task(
            self._execute_search(term, debounce=debounce_time)
        )

    async def _on_filter_select(self, e):
        selected = e.control.selected
        if not selected:
            self._handle_empty_filter_selection()
            return

        self._reset_search_state()

        if "explorar" in selected:
            await self._return_to_explore()
            return

        self._reset_filter_banner()
        self._show_content_view("list")

        filter_map = {"favoritos": "favoritos", "recentes": "recentes"}
        self.current_filter = next(
            (filter_map[k] for k in filter_map if k in selected), "todos"
        )

        await self._load_current_filter_data("")
        if self.page:
            self.page.update()


# Alias oficial da Sprint 3 para a visualização da lista de hinos
HinosView = HomeView


def create_gamification_banner(
    page: ft.Page,
    streak: int = 0,
    total_xp: int = 0,
    weekly_activity: list[bool] | None = None,
    on_click: Any = None,
) -> ft.Container:
    """Cria o banner de gamificação oficial com Streak, XP e progresso semanal."""
    from datetime import date
    weekly = weekly_activity or [False] * 7
    today_idx = (date.today().weekday() + 1) % 7
    labels = ["D", "S", "T", "Q", "Q", "S", "S"]
    dots = []
    for i in range(7):
        done = weekly[i] if i < len(weekly) else False
        is_today = (i == today_idx)
        dots.append(
            ft.Column(
                controls=[
                    ft.Container(
                        width=10,
                        height=10,
                        border_radius=5,
                        bgcolor=ft.Colors.PRIMARY if done else ft.Colors.with_opacity(0.18, ft.Colors.OUTLINE),
                        border=ft.Border.all(
                            1.5,
                            ft.Colors.PRIMARY if is_today else ft.Colors.TRANSPARENT,
                        ),
                    ),
                    ft.Text(
                        labels[i],
                        size=8,
                        weight=ft.FontWeight.BOLD if is_today else ft.FontWeight.NORMAL,
                        color=ft.Colors.PRIMARY if is_today else ft.Colors.ON_SURFACE_VARIANT,
                    ),
                ],
                spacing=2,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            )
        )

    click_handler = on_click or (lambda e: asyncio.create_task(page.push_route("/escola-sabatina")))

    return ft.Container(
        content=ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=20, color=ft.Colors.ORANGE_ACCENT_400),
                                ft.Text(f"{streak} dias seguidos" if streak != 1 else "1 dia seguido", size=13, weight=ft.FontWeight.BOLD),
                            ],
                            spacing=4,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.STAR_ROUNDED, size=20, color=ft.Colors.AMBER_400),
                                ft.Text(f"{total_xp} XP", size=13, weight=ft.FontWeight.BOLD),
                            ],
                            spacing=4,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                ft.Row(
                    controls=[
                        ft.Text("Progresso da Semana", size=11, weight=ft.FontWeight.W_500, color=ft.Colors.ON_SURFACE_VARIANT),
                        ft.Row(controls=dots, spacing=6, tight=True),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
            ],
            spacing=6,
        ),
        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
        border_radius=16,
        border=ft.Border.all(1.0, ft.Colors.with_opacity(0.18, ft.Colors.PRIMARY)),
        padding=ft.Padding.symmetric(horizontal=14, vertical=10),
        ink=True,
        on_click=click_handler,
    )
