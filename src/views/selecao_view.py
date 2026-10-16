import asyncio
from datetime import date, datetime
import random
from typing import Any
import urllib.parse

import flet as ft

from src.services.auth_service import AuthService
from src.services.content_manager import ContentManager
from src.services.devotional_service import DevotionalService
from src.services.reading_service import ReadingService
from src.services.search_service import SearchResultItem, SearchService
from src.services.theme_service import ThemeService
from src.services.updater_service import UpdaterService

from src.theme.glass_styles import (
    get_card_decoration,
    get_liquid_glass_background_gradient,
)
from src.theme.palette import ThemeModeType
from src.theme.theme_engine import ThemeEngine
from src.utils.storage_manager import storage_get, storage_set
from src.views.settings_dialog import (
    close_all_dialogs,
    ensure_page_dialogs,
    show_settings_dialog,
    show_profile_dialog,
    show_about_dialog,
)

try:
    from src.version import __version__ as APP_VERSION
except ImportError:
    APP_VERSION = "0.4.20"

ROUTE_DOWNLOADS = "/downloads"

GREETING_BOM_DIA = "Bom dia{nome}! ☀️"
GREETING_BOA_TARDE = "Boa tarde{nome}! 🌤️"
GREETING_BOA_NOITE = "Boa noite{nome}! 🌙"

GREETING_POOLS = {
    "manha": [
        (GREETING_BOM_DIA, "Que a Palavra ilumine seu caminho hoje."),
        (GREETING_BOM_DIA, "Hora de começar o dia com inspiração e fé."),
        (GREETING_BOM_DIA, "Uma manhã com a Palavra renova o coração."),
    ],
    "tarde": [
        (GREETING_BOA_TARDE, "Que tal uma pausa para alimentar a alma?"),
        (GREETING_BOA_TARDE, "A Palavra é lâmpada para os seus passos."),
        (GREETING_BOA_TARDE, "Renove sua mente com a leitura de hoje."),
    ],
    "noite": [
        (GREETING_BOA_NOITE, "Encerre o dia refletindo na Palavra de Deus."),
        (GREETING_BOA_NOITE, "Uma leitura antes de descansar traz paz ao coração."),
        (GREETING_BOA_NOITE, "Que a paz do Senhor guarde seus pensamentos."),
    ],
}


class SelecaoView:
    """
    Tela inicial (Hub de Entrada) do aplicativo Kairós.
    Apresenta uma interface moderna e acolhedora com saudação personalizada,
    card do versículo do dia, e acesso aos hinários, bíblia e ferramentas.
    """

    def __init__(
        self,
        theme_service: ThemeService | None = None,
        updater_service: UpdaterService | None = None,
        content_manager: ContentManager | None = None,
        theme_engine: ThemeEngine | None = None,
        auth_service: AuthService | None = None,
        devotional_service: DevotionalService | None = None,
        reading_service: ReadingService | None = None,
        hino_repository: Any | None = None,
        biblia_repository: Any | None = None,
        search_service: SearchService | None = None,
    ):
        self.theme_service = theme_service
        self.updater_service = updater_service or UpdaterService()
        self.content_manager = content_manager or ContentManager()
        self.auth_service = auth_service or AuthService()
        self.devotional_service = devotional_service
        self.reading_service = reading_service
        self.hino_repository = hino_repository
        self.biblia_repository = biblia_repository
        self.search_service = search_service

        self.theme_engine = (
            theme_engine
            or getattr(theme_service, "theme_engine", None)
            or ThemeEngine()
        )
        self.page: ft.Page | None = None

        # Controles reativos do cabeçalho
        self.greeting_title: ft.Text | None = None
        self.greeting_subtitle: ft.Text | None = None
        self.greeting_icon_box: ft.Container | None = None
        self.greeting_icon_glyph: ft.Icon | None = None
        self.verse_container: ft.Container | None = None
        self.meditacao_subtitle_text: ft.Text | None = None
        self.escola_sabatina_subtitle_text: ft.Text | None = None
        self.gamification_banner: ft.Row | ft.Container | None = None
        self.banner_streak_text: ft.Text | None = None
        self.banner_xp_text: ft.Text | None = None
        self.banner_weekly_dots: ft.Row | None = None
        self._sync_triggered: bool = False
        self.refresh_indicator: ft.Container | None = None
        self._is_refreshing: bool = False

    async def _navigate(self, page: ft.Page, route: str) -> None:
        await page.push_route(route)


    def _abrir_pesquisa_global(self) -> None:
        """Abre modal BottomSheet para pesquisa rápida e unificada em todo o app."""
        if not self.page:
            return

        palette = self.theme_engine.get_current_palette()
        accent = palette.primary
        t_prim = palette.text_primary
        t_sec = palette.text_secondary
        s_bg = palette.surface
        s_high = palette.surface_container_high

        search_input = ft.TextField(
            hint_text="Pesquisar hinos, passagens bíblicas ou temas...",
            prefix_icon=ft.Icons.SEARCH,
            dense=True,
            border_radius=12,
            autofocus=True,
            expand=True,
        )

        results_list = ft.ListView(
            controls=[],
            spacing=8,
            expand=True,
        )

        feedback_container = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Icon(ft.Icons.SEARCH, size=40, color=t_sec),
                    ft.Text("Digite o que procura (ex: 12, Santo, João 3:16)", size=13, color=t_sec),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=8,
            ),
            alignment=ft.Alignment.CENTER,
            expand=True,
        )

        async def _do_search(q: str):
            q_clean = q.strip()
            if not q_clean:
                results_list.controls.clear()
                results_list.visible = False
                feedback_container.visible = True
                if self.page:
                    self.page.update()
                return

            feedback_container.content = ft.Column(
                controls=[
                    ft.ProgressRing(width=28, height=28, color=accent),
                    ft.Text("Buscando em todo o app...", size=12, color=t_sec),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=8,
            )
            feedback_container.visible = True
            results_list.visible = False
            if self.page:
                self.page.update()

            cards: list[ft.Control] = []
            total_matches = 0

            # 1. Utiliza SearchService se disponível
            if self.search_service:
                try:
                    top_items, total_matches = await self.search_service.get_top_unified(q_clean, limit=5)
                    for item in top_items:
                        # Seleciona o ícone apropriado
                        icon_glyph = ft.Icons.SEARCH
                        if item.icon_name == "music_note":
                            icon_glyph = ft.Icons.MUSIC_NOTE
                        elif item.icon_name == "menu_book":
                            icon_glyph = ft.Icons.MENU_BOOK
                        elif item.icon_name == "favorite_outline":
                            icon_glyph = ft.Icons.FAVORITE_BORDER
                        elif item.icon_name == "school":
                            icon_glyph = ft.Icons.SCHOOL

                        cards.append(
                            ft.Container(
                                content=ft.ListTile(
                                    leading=ft.Container(
                                        content=ft.Row(
                                            controls=[
                                                ft.Icon(icon_glyph, size=14, color=accent),
                                                ft.Text(
                                                    item.type_label.upper(),
                                                    size=10,
                                                    weight=ft.FontWeight.BOLD,
                                                    color=accent,
                                                ),
                                            ],
                                            spacing=4,
                                            tight=True,
                                            alignment=ft.MainAxisAlignment.CENTER,
                                        ),
                                        bgcolor=s_high,
                                        padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                                        border_radius=6,
                                    ),
                                    title=ft.Text(item.title, size=13, weight=ft.FontWeight.BOLD, color=t_prim),
                                    subtitle=ft.Text(
                                        item.subtitle,
                                        size=11,
                                        color=t_sec,
                                        max_lines=2,
                                        overflow=ft.TextOverflow.ELLIPSIS,
                                    ),
                                    trailing=ft.Icon(ft.Icons.CHEVRON_RIGHT, size=16, color=t_sec),
                                    on_click=lambda e, target_route=item.route: asyncio.create_task(
                                        self._navegar_para_rota_com_dialog_pop(target_route)
                                    ),
                                ),
                                bgcolor=s_high,
                                border_radius=10,
                            )
                        )
                except Exception as exc:
                    logger.debug("Falha na busca via SearchService: %s", exc)

            # Fallback retrocompatível se SearchService não estiver injetado ou não retornar resultados
            if not cards:
                # 1. Busca Hinos Fallback
                if self.hino_repository:
                    try:
                        hinos = await self.hino_repository.search(q_clean)
                        if hinos:
                            cards.append(
                                ft.Container(
                                    content=ft.Text(f"HINOS ({len(hinos[:5])})", size=11, weight=ft.FontWeight.BOLD, color=accent),
                                    padding=ft.Padding.only(top=6, bottom=2),
                                )
                            )
                            for h in hinos[:5]:
                                cards.append(
                                    ft.Container(
                                        content=ft.ListTile(
                                            leading=ft.Container(
                                                content=ft.Text(str(h.numero), size=12, weight=ft.FontWeight.BOLD, color=accent),
                                                bgcolor=s_high,
                                                padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                                                border_radius=6,
                                            ),
                                            title=ft.Text(h.titulo, size=13, weight=ft.FontWeight.BOLD, color=t_prim),
                                            trailing=ft.Icon(ft.Icons.CHEVRON_RIGHT, size=16, color=t_sec),
                                            on_click=lambda e, h_id=h.id: asyncio.create_task(self._navegar_para_hino(h_id)),
                                        ),
                                        bgcolor=s_high,
                                        border_radius=10,
                                    )
                                )
                    except Exception:
                        pass

                # 2. Busca Bíblia Fallback
                if self.biblia_repository:
                    try:
                        versiculos = await self.biblia_repository.pesquisar_texto(q_clean, limit=5)
                        if versiculos:
                            cards.append(
                                ft.Container(
                                    content=ft.Text(f"BÍBLIA ({len(versiculos)})", size=11, weight=ft.FontWeight.BOLD, color=accent),
                                    padding=ft.Padding.only(top=10, bottom=2),
                                )
                            )
                            for v in versiculos:
                                bname = v.get("book_name", "")
                                ch = v.get("chapter", 1)
                                vn = v.get("verse", 1)
                                txt = v.get("text", "")
                                cards.append(
                                    ft.Container(
                                        content=ft.ListTile(
                                            title=ft.Text(f"{bname} {ch}:{vn}", size=13, weight=ft.FontWeight.BOLD, color=t_prim),
                                            subtitle=ft.Text(txt, size=12, color=t_sec, max_lines=2, overflow=ft.TextOverflow.ELLIPSIS),
                                            trailing=ft.Icon(ft.Icons.CHEVRON_RIGHT, size=16, color=t_sec),
                                            on_click=lambda e, bn=bname, c=ch, ver=vn: asyncio.create_task(self._navegar_para_biblia(bn, c, ver)),
                                        ),
                                        bgcolor=s_high,
                                        border_radius=10,
                                    )
                                )
                    except Exception:
                        pass

            if not cards:
                feedback_container.content = ft.Column(
                    controls=[
                        ft.Icon(ft.Icons.SEARCH_OFF, size=36, color=t_sec),
                        ft.Text(f"Nenhum resultado encontrado para '{q_clean}'", size=13, color=t_sec),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    alignment=ft.MainAxisAlignment.CENTER,
                    spacing=8,
                )
                feedback_container.visible = True
                results_list.visible = False
            else:
                feedback_container.visible = False
                # Botão 'Ver todos (N)' se houver resultados
                ver_todos_count = total_matches if total_matches > 0 else len(cards)
                cards.append(
                    ft.Container(
                        content=ft.Button(
                            content=ft.Text(f"Ver todos ({ver_todos_count})"),
                            icon=ft.Icons.SEARCH_ROUNDED,
                            style=ft.ButtonStyle(
                                shape=ft.RoundedRectangleBorder(radius=10),
                            ),
                            on_click=lambda e, q_val=q_clean: asyncio.create_task(
                                self._navegar_para_todos_resultados(q_val)
                            ),
                        ),
                        alignment=ft.Alignment.CENTER,
                        padding=ft.Padding.only(top=10, bottom=6),
                    )
                )
                results_list.controls = cards
                results_list.visible = True

            if self.page:
                self.page.update()


        search_input.on_submit = lambda e: asyncio.create_task(_do_search(e.control.value))

        bs = ft.BottomSheet(
            scrollable=True,
            show_drag_handle=True,
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                search_input,
                                ft.IconButton(
                                    ft.Icons.SEARCH,
                                    tooltip="Buscar",
                                    on_click=lambda e: asyncio.create_task(_do_search(search_input.value or "")),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        ),
                        ft.Divider(height=1),
                        feedback_container,
                        results_list,
                    ],
                    spacing=10,
                    expand=True,
                ),
                padding=ft.Padding.only(left=16, top=12, right=16, bottom=24),
                height=520,
            ),
        )

        ensure_page_dialogs(self.page)
        close_all_dialogs(self.page)
        self.page.show_dialog(bs)

    async def _navegar_para_rota_com_dialog_pop(self, target_route: str) -> None:
        """Fecha o bottom sheet e navega para a rota especificada."""
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            await self._navigate(self.page, target_route)

    async def _navegar_para_todos_resultados(self, query: str) -> None:
        """Fecha o bottom sheet e navega para /busca?q={query}."""
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            q_enc = urllib.parse.quote(query.strip())
            await self._navigate(self.page, f"/busca?q={q_enc}")

    async def _navegar_para_hino(self, hino_id: int) -> None:
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            await self._navigate(self.page, f"/novo/hino/{hino_id}")

    async def _navegar_para_biblia(self, livro: str, capitulo: int, versiculo: int) -> None:
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            livro_encoded = urllib.parse.quote(str(livro))
            await self._navigate(self.page, f"/biblia?livro={livro_encoded}&cap={capitulo}&ver={versiculo}")


    def _show_profile_dialog(self, page: ft.Page | None = None, e=None):
        """Abre o modal dedicado de Perfil, Conta, Conteúdo/Widgets e Aparência."""
        target_page = page if isinstance(page, ft.Page) else self.page
        if not target_page:
            return
        close_all_dialogs(target_page)
        show_profile_dialog(
            page=target_page,
            theme_service=self.theme_service,
            auth_service=self.auth_service,
            media_service=None,
            hino_repository=self.hino_repository,
        )

    def _show_about_dialog(self, page: ft.Page | None = None, e=None):
        """Abre o modal de Informações Sobre o App e Atualizações."""
        target_page = page if isinstance(page, ft.Page) else self.page
        if not target_page:
            return
        close_all_dialogs(target_page)
        show_about_dialog(
            page=target_page,
            theme_service=self.theme_service,
            updater_service=self.updater_service,
        )

    async def _on_pull_refresh(self, e=None) -> None:
        """Executa a atualização manual puxada (pull-to-refresh) na tela inicial."""
        if self._is_refreshing:
            return
        self._is_refreshing = True
        if self.refresh_indicator:
            self.refresh_indicator.visible = True
            try:
                self.refresh_indicator.update()
            except Exception:
                pass

        try:
            self._sync_triggered = False
            await self._load_header_data()
        finally:
            self._is_refreshing = False
            if self.refresh_indicator:
                self.refresh_indicator.visible = False
                try:
                    self.refresh_indicator.update()
                except Exception:
                    pass

    def _get_daily_nature_image(self) -> str:
        """Retorna a foto curada de natureza do dia via WallpaperService sincronizado."""
        from src.services.wallpaper_service import WallpaperService
        return WallpaperService.get_instance().get_daily_wallpaper()

    def _build_verse_card_content(self, ref_label: str, preview_text: str, cat_label: str) -> ft.Control:
        """Constrói o widget de miniatura AndBible (quadrado ou panorâmico) com foto cobrindo 100% de ponta a ponta."""
        from src.utils.storage_manager import storage_get_sync

        card_format = storage_get_sync("meditacao_card_format", "quadrado")
        is_quadrado = (card_format != "panoramico")
        card_height = 270 if is_quadrado else 154

        if len(preview_text) > 160:
            preview_text = preview_text[:157] + "..."

        img_url = self._get_daily_nature_image()

        if is_quadrado:
            # Layout Quadrado / Editorial estilo YouVersion / AndBible
            text_column = ft.Column(
                controls=[
                    # Header: Tag do versículo e categoria
                    ft.Row(
                        controls=[
                            ft.Row(
                                controls=[
                                    ft.Icon(ft.Icons.AUTO_AWESOME_ROUNDED, size=14, color=ft.Colors.WHITE_70),
                                    ft.Text("VERSÍCULO DO DIA", size=10, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE_70),
                                ],
                                spacing=5,
                                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            ft.Container(
                                content=ft.Text(cat_label.upper(), size=9, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                                bgcolor=ft.Colors.with_opacity(0.35, ft.Colors.BLACK),
                                padding=ft.Padding.symmetric(horizontal=8, vertical=3),
                                border_radius=6,
                                border=ft.Border.all(0.8, ft.Colors.with_opacity(0.35, ft.Colors.WHITE)),
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Container(expand=True),
                    # Corpo: Texto serifa imponente com aspas
                    ft.Text(
                        f'"{preview_text}"',
                        font_family="HymnSerif",
                        size=15,
                        color=ft.Colors.WHITE,
                        text_align=ft.TextAlign.CENTER,
                        max_lines=5,
                        overflow=ft.TextOverflow.ELLIPSIS,
                    ),
                    ft.Container(height=6),
                    # Referência bíblica destacada
                    ft.Text(
                        ref_label,
                        size=13,
                        weight=ft.FontWeight.BOLD,
                        color=ft.Colors.WHITE,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    ft.Container(expand=True),
                    # Footer: Call to action
                    ft.Row(
                        controls=[
                            ft.Text("Toque para ler a meditação completa", size=10, color=ft.Colors.WHITE_70),
                            ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, size=10, color=ft.Colors.WHITE_70),
                        ],
                        spacing=4,
                        alignment=ft.MainAxisAlignment.CENTER,
                    ),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=4,
                expand=True,
            )
        else:
            # Layout Panorâmico com crop total de ponta a ponta
            text_column = ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Row(
                                controls=[
                                    ft.Icon(ft.Icons.AUTO_AWESOME_ROUNDED, size=13, color=ft.Colors.WHITE_70),
                                    ft.Text("VERSÍCULO DO DIA", size=10, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE_70),
                                ],
                                spacing=4,
                                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            ft.Container(
                                content=ft.Text(cat_label.upper(), size=9, weight=ft.FontWeight.BOLD, color=ft.Colors.WHITE),
                                bgcolor=ft.Colors.with_opacity(0.35, ft.Colors.BLACK),
                                padding=ft.Padding.symmetric(horizontal=8, vertical=3),
                                border_radius=6,
                                border=ft.Border.all(0.8, ft.Colors.with_opacity(0.35, ft.Colors.WHITE)),
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Container(expand=True),
                    ft.Text(
                        f'"{preview_text}"',
                        font_family="HymnSerif",
                        size=13,
                        color=ft.Colors.WHITE,
                        max_lines=3,
                        overflow=ft.TextOverflow.ELLIPSIS,
                    ),
                    ft.Container(height=3),
                    ft.Row(
                        controls=[
                            ft.Text(
                                ref_label,
                                size=12,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.WHITE,
                            ),
                            ft.Row(
                                controls=[
                                    ft.Text("Ler meditação", size=10, color=ft.Colors.WHITE_70),
                                    ft.Icon(ft.Icons.ARROW_FORWARD_IOS_ROUNDED, size=10, color=ft.Colors.WHITE_70),
                                ],
                                spacing=2,
                                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                ],
                spacing=2,
                expand=True,
            )

        return ft.Stack(
            controls=[
                # Camada 1: Gradiente base de natureza (renderização instantânea)
                ft.Container(
                    gradient=ft.LinearGradient(
                        begin=ft.Alignment.TOP_LEFT,
                        end=ft.Alignment.BOTTOM_RIGHT,
                        colors=["#1B382B", "#0E1C15", "#142534"],
                    ),
                    border_radius=18,
                    left=0,
                    top=0,
                    right=0,
                    bottom=0,
                ),
                # Camada 2: Imagem cobrindo 100% de ponta a ponta
                ft.Image(
                    src=img_url,
                    fit=ft.BoxFit.COVER,
                    border_radius=18,
                    left=0,
                    top=0,
                    right=0,
                    bottom=0,
                ),
                # Camada 3: Scrim degradê para contraste editorial
                ft.Container(
                    gradient=ft.LinearGradient(
                        begin=ft.Alignment.TOP_CENTER,
                        end=ft.Alignment.BOTTOM_CENTER,
                        colors=[
                            ft.Colors.with_opacity(0.42, ft.Colors.BLACK),
                            ft.Colors.with_opacity(0.18, ft.Colors.BLACK),
                            ft.Colors.with_opacity(0.80, ft.Colors.BLACK),
                        ],
                    ),
                    border_radius=18,
                    left=0,
                    top=0,
                    right=0,
                    bottom=0,
                ),
                # Camada 4: Conteúdo textual perfeitamente posicionado
                ft.Container(
                    content=text_column,
                    padding=ft.Padding.all(18 if is_quadrado else 14),
                    left=0,
                    top=0,
                    right=0,
                    bottom=0,
                ),
            ],
            height=card_height,
        )

    def _render_verse_content(self, ref_label: str, preview_text: str, cat_label: str) -> None:
        """Renderiza o conteúdo formatado do versículo em estilo miniatura AndBible / YouVersion com foto de fundo."""
        if not self.verse_container:
            return

        self._cached_ref_str = ref_label
        self._cached_preview_str = preview_text
        self._cached_cat_str = cat_label

        self.verse_container.content = self._build_verse_card_content(ref_label, preview_text, cat_label)
        self.verse_container.padding = 0
        self.verse_container.bgcolor = ft.Colors.TRANSPARENT
        self.verse_container.border = None
        self.verse_container.visible = True
        try:
            self.verse_container.update()
        except Exception:
            pass

    def refresh_verse_card(self) -> None:
        """Força a reconstrução imediata do card de versículo com o formato e dados configurados."""
        if not self.verse_container:
            return
        from src.utils.storage_manager import storage_get_sync

        ref_label = getattr(self, "_cached_ref_str", None) or storage_get_sync("cached_verse_ref")
        preview_text = getattr(self, "_cached_preview_str", None) or storage_get_sync("cached_verse_preview")
        cat_label = getattr(self, "_cached_cat_str", None) or storage_get_sync("cached_verse_cat", "Jovem")

        if ref_label and preview_text:
            self._render_verse_content(ref_label, preview_text, cat_label)
        elif self.devotional_service and self.page:
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(self._load_header_data())
            except RuntimeError:
                pass

    def _update_verse_card(self, dev: Any, category: str) -> None:
        """Renderiza o conteúdo do versículo da meditação no container do card e persiste preview."""
        if not self.verse_container or not dev or not getattr(dev, "verse_text", None):
            return
        preview_text = dev.verse_text.strip()
        ref_label = getattr(dev, "verse_reference", "") or getattr(dev, "title", "")
        cat_label = category.capitalize()

        self._render_verse_content(ref_label, preview_text, cat_label)
        if self.page:
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(self._persist_verse_preview(ref_label, preview_text, cat_label))
            except RuntimeError:
                pass

    async def _persist_verse_preview(self, ref_label: str, preview_text: str, cat_label: str) -> None:
        """Persiste em cache rápido de chave-valor para renderização instantânea no próximo início."""
        try:
            await storage_set(self.page, "cached_verse_ref", ref_label)
            await storage_set(self.page, "cached_verse_preview", preview_text)
            await storage_set(self.page, "cached_verse_cat", cat_label)
        except Exception:
            pass

    def _set_verse_card_placeholder(self) -> None:
        """Define mensagem amigável no card quando não há versículo cacheado para a data."""
        if not self.verse_container:
            return
        # Se temos versículo em memória cacheada, mantemos a exibição em vez de voltar ao placeholder
        if getattr(self, "_cached_ref_str", None) and getattr(self, "_cached_preview_str", None):
            self._render_verse_content(self._cached_ref_str, self._cached_preview_str, getattr(self, "_cached_cat_str", "Jovem"))
            return

        palette = self.theme_engine.get_current_palette()
        self.verse_container.content = ft.Row(
            controls=[
                ft.Icon(ft.Icons.AUTO_STORIES, size=18, color=palette.primary),
                ft.Text(
                    "Meditação Diária • Toque para ler o devocional de hoje",
                    size=12,
                    italic=True,
                    color=palette.text_secondary,
                ),
            ],
            spacing=8,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )
        self.verse_container.visible = True
        try:
            self.verse_container.update()
        except Exception:
            pass

    async def _abrir_destaque_meditacao(self) -> None:
        """Abre o destaque da meditação no estilo configurado: AndBible (tela cheia) ou Glassmorphism (modal)."""
        if not self.page:
            return

        style = await storage_get(self.page, "meditacao_visual_style", default="andbible")
        if style == "glass":
            self._mostrar_modal_glass_versiculo()
        else:
            await self._navigate(self.page, "/meditacao/destaque")

    def _mostrar_modal_glass_versiculo(self) -> None:
        """Abre BottomSheet com estética Glassmorphism para o versículo do dia."""
        if not self.page:
            return

        palette = self.theme_engine.get_current_palette()
        accent = palette.primary

        ref_text = getattr(self, "_cached_ref_str", None) or "Salmos 119:105"
        verse_text = getattr(self, "_cached_preview_str", None) or "Lâmpada para os meus pés é a tua palavra e, luz para os meus caminhos."
        cat_text = (getattr(self, "_cached_cat_str", None) or "JOVEM").upper()

        bs = ft.BottomSheet(
            maintain_bottom_view_insets_padding=True,
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Container(
                            width=36,
                            height=4,
                            border_radius=2,
                            bgcolor=ft.Colors.with_opacity(0.3, ft.Colors.WHITE),
                            alignment=ft.Alignment.CENTER,
                        ),
                        ft.Container(height=10),
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.AUTO_AWESOME_ROUNDED, size=20, color=accent),
                                ft.Text(cat_text, size=11, weight=ft.FontWeight.BOLD, color=accent),
                            ],
                            spacing=6,
                            alignment=ft.MainAxisAlignment.CENTER,
                        ),
                        ft.Text(
                            ref_text,
                            size=18,
                            weight=ft.FontWeight.BOLD,
                            text_align=ft.TextAlign.CENTER,
                            color=palette.text_primary,
                        ),
                        ft.Divider(height=16, color=ft.Colors.with_opacity(0.12, accent)),
                        ft.Text(
                            verse_text,
                            size=16,
                            italic=True,
                            text_align=ft.TextAlign.CENTER,
                            color=palette.text_primary,
                        ),
                        ft.Container(height=16),
                        ft.FilledButton(
                            "Ler Meditação Completa",
                            icon=ft.Icons.AUTO_STORIES_ROUNDED,
                            style=ft.ButtonStyle(
                                bgcolor=accent,
                                color=ft.Colors.WHITE,
                                shape=ft.RoundedRectangleBorder(radius=12),
                            ),
                            on_click=lambda e: asyncio.create_task(self._navegar_para_rota_com_dialog_pop("/meditacoes")),
                        ),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    tight=True,
                    spacing=8,
                ),
                padding=ft.Padding.symmetric(horizontal=24, vertical=20),
                bgcolor=ft.Colors.with_opacity(0.85, palette.surface_container_high),
                blur=ft.Blur(16, 16, ft.BlurTileMode.CLAMP),
                border=ft.Border(top=ft.BorderSide(1.0, ft.Colors.with_opacity(0.2, accent))),
                border_radius=ft.BorderRadius(top_left=24, top_right=24, bottom_left=0, bottom_right=0),
            ),
        )

        ensure_page_dialogs(self.page)
        close_all_dialogs(self.page)
        self.page.show_dialog(bs)

    async def _load_header_data(self) -> None:
        """Carrega a saudação personalizada e o versículo do dia de forma estritamente offline-first."""
        if not self.page:
            return

        now = datetime.now()
        today_iso = now.date().isoformat()
        hour = now.hour

        # Se já foi carregado nesta sessão para hoje, garante que o card está renderizado e evita queries pesadas
        if getattr(self, "_header_loaded_date", None) == today_iso and not getattr(self, "_is_refreshing", False):
            if getattr(self, "_cached_ref_str", None) and getattr(self, "_cached_preview_str", None):
                self._render_verse_content(self._cached_ref_str, self._cached_preview_str, getattr(self, "_cached_cat_str", "Jovem"))
            return
        self._header_loaded_date = today_iso

        if 5 <= hour < 12:
            periodo = "manha"
        elif 12 <= hour < 18:
            periodo = "tarde"
        else:
            periodo = "noite"

        # 1. Determina primeiro nome (se logado)
        user_name_suffix = ""
        user = self.auth_service.get_current_user() if self.auth_service else None
        if user:
            display_name = getattr(user, "display_name", "") or ""
            email = getattr(user, "email", "") or ""
            if display_name:
                first_name = display_name.strip().split()[0]
                user_name_suffix = f", {first_name}"
            elif email:
                first_name = email.split("@")[0].capitalize()
                user_name_suffix = f", {first_name}"

        # 2. Rotação anti-repetição por dia
        pool = GREETING_POOLS[periodo]
        last_date, last_idx = await asyncio.gather(
            storage_get(self.page, "greeting_last_date", default=""),
            storage_get(self.page, "greeting_last_index", default=None),
        )

        if last_date == today_iso and last_idx is not None and 0 <= int(last_idx) < len(pool):
            chosen_idx = int(last_idx)
        else:
            available_indices = [i for i in range(len(pool)) if i != last_idx]
            chosen_idx = random.choice(available_indices if available_indices else [0])
            await storage_set(self.page, "greeting_last_date", today_iso)
            await storage_set(self.page, "greeting_last_index", chosen_idx)

        title_template, subtitle_text = pool[chosen_idx]
        formatted_title = title_template.format(nome=user_name_suffix)

        if self.greeting_title:
            self.greeting_title.value = formatted_title
        if self.greeting_subtitle:
            self.greeting_subtitle.value = subtitle_text

        # 3. Carrega o versículo da meditação de hoje estritamente offline-first
        if self.devotional_service and self.verse_container:
            # 3.1 Consulta as chaves de storage em paralelo para acelerar o arranque
            (
                cached_preview,
                cached_ref,
                cached_cat_raw,
                pref_cat_raw,
            ) = await asyncio.gather(
                storage_get(self.page, "cached_verse_preview"),
                storage_get(self.page, "cached_verse_ref"),
                storage_get(self.page, "cached_verse_cat", default="Jovem"),
                storage_get(self.page, "preferred_devotional_category", default="jovem"),
            )
            cached_cat = cached_cat_raw or "Jovem"
            if cached_preview and cached_ref:
                self._render_verse_content(cached_ref, cached_preview, cached_cat)

            category = str(pref_cat_raw).lower() if pref_cat_raw in ("jovem", "diario", "mulher") else "jovem"

            # Consulta PRIMEIRO estritamente no cache local SQLite (sem bloquear a UI com rede)
            dev = await self.devotional_service.get_cached_devotional(today_iso, category=category)
            if dev and getattr(dev, "verse_text", None):
                self._update_verse_card(dev, category)
            else:
                # Se ainda não houver para hoje no banco local com essa categoria, tenta qualquer categoria ou a mais recente
                try:
                    recents = await self.devotional_service.repository.get_recent(limit=1, category=category)
                    if not recents:
                        recents = await self.devotional_service.repository.get_recent(limit=1)
                    if recents and recents[0].verse_text:
                        self._update_verse_card(recents[0], getattr(recents[0], "category", category))
                    elif not cached_preview:
                        self._set_verse_card_placeholder()
                except Exception:
                    if not cached_preview:
                        self._set_verse_card_placeholder()


            # Dispara sincronização remota em segundo plano apenas UMA VEZ na abertura do app
            if not self._sync_triggered:
                self._sync_triggered = True

                async def _sync_devotional_bg():
                    try:
                        await asyncio.sleep(3)
                        if self.devotional_service is None:
                            return
                        cloud_dev = await self.devotional_service.sync_devotional(today_iso, category=category)
                        if cloud_dev and getattr(cloud_dev, "verse_text", None) and self.verse_container and self.page:
                            self._update_verse_card(cloud_dev, category)
                            try:
                                self.verse_container.update()
                            except Exception:
                                pass
                    except Exception:
                        pass

                asyncio.create_task(_sync_devotional_bg())

        # 4. Atualiza estatísticas unificadas de gamificação no banner
        if self.reading_service:
            try:
                stats = await self.reading_service.get_unified_user_stats()
                streak = stats.get("current_streak", 0)
                total_xp = stats.get("total_xp", 0)
                weekly = stats.get("weekly_activity", [False] * 7)

                if self.banner_streak_text:
                    self.banner_streak_text.value = f"{streak} dias seguidos" if streak != 1 else "1 dia seguido"
                if self.banner_xp_text:
                    self.banner_xp_text.value = f"{total_xp} XP"
                if self.meditacao_subtitle_text and streak > 0:
                    self.meditacao_subtitle_text.value = f"🔥 {streak} dia(s) em sequência • Devocional Diário"
            except Exception:
                pass

        # 5. Atualiza subtítulo do card da Escola Sabatina com a categoria padrão
        if self.escola_sabatina_subtitle_text and self.page:
            try:
                ss_cat, ss_type = await asyncio.gather(
                    storage_get(self.page, "preferred_ss_category"),
                    storage_get(self.page, "preferred_ss_type", default="adultos"),
                )
                effective_ss = ss_cat or ss_type or "adultos"
                ss_name = "Jovens" if str(effective_ss).lower() == "jovens" else "Adultos"
                self.escola_sabatina_subtitle_text.value = f"Lição de {ss_name} • Estudo Diário"
            except Exception:
                pass

        # Atualizações cirúrgicas de controles
        updated_any = False
        for ctrl in (
            self.greeting_title,
            self.greeting_subtitle,
            self.gamification_banner,
            self.verse_container,
            self.meditacao_subtitle_text,
            self.escola_sabatina_subtitle_text,
        ):
            if ctrl:
                try:
                    ctrl.update()
                    updated_any = True
                except Exception:
                    pass

        if not updated_any and self.page:
            try:
                self.page.update()
            except Exception:
                pass

    def _build_action_grid_tile(
        self,
        page: ft.Page,
        title: str,
        subtitle: str,
        icon: ft.IconData,
        color: str,
        route: str,
        text_primary: str,
        text_secondary: str,
        badge_text: str | None = None,
        custom_subtitle_ref: ft.Text | None = None,
    ) -> ft.Container:
        """Constrói um card elegante em estilo grid (2 colunas) com layout horizontal harmonioso."""
        dec = get_card_decoration(self.theme_engine)

        icon_box = ft.Container(
            content=ft.Icon(icon, size=24, color=color),
            bgcolor=ft.Colors.with_opacity(0.18, color),
            border_radius=11,
            width=42,
            height=42,
            alignment=ft.Alignment.CENTER,
        )

        subtitle_control = custom_subtitle_ref or ft.Text(
            subtitle,
            size=11,
            color=text_secondary,
            max_lines=1,
            overflow=ft.TextOverflow.ELLIPSIS,
        )

        card_row = ft.Row(
            controls=[
                icon_box,
                ft.Column(
                    controls=[
                        ft.Text(
                            title,
                            size=13.5,
                            weight=ft.FontWeight.BOLD,
                            color=text_primary,
                            max_lines=1,
                            overflow=ft.TextOverflow.ELLIPSIS,
                        ),
                        subtitle_control,
                    ],
                    spacing=2,
                    alignment=ft.MainAxisAlignment.CENTER,
                    horizontal_alignment=ft.CrossAxisAlignment.START,
                    expand=True,
                ),
            ],
            spacing=10,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )

        if badge_text:
            badge_control = ft.Container(
                content=ft.Text(badge_text, size=8, weight=ft.FontWeight.BOLD, color=color),
                bgcolor=ft.Colors.with_opacity(0.15, color),
                border_radius=5,
                padding=ft.Padding.symmetric(horizontal=5, vertical=2),
            )
            card_content = ft.Stack(
                controls=[
                    card_row,
                    ft.Container(
                        content=badge_control,
                        top=-4,
                        right=-2,
                    ),
                ],
            )
        else:
            card_content = card_row

        return ft.Container(
            content=card_content,
            bgcolor=dec.get("bgcolor"),
            gradient=dec.get("gradient"),
            border=dec.get("border"),
            border_radius=dec.get("border_radius", 14),
            shadow=dec.get("shadow"),
            blur=dec.get("blur"),
            padding=ft.Padding.only(left=12, top=12, right=10, bottom=12),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, route)),
            expand=True,
        )

    def _build_personalized_header(self, page: ft.Page, palette: Any, is_glass: bool) -> ft.Container:
        """Constrói cabeçalho acolhedor com saudação diária, banner de gamificação e card de versículo em destaque."""
        text_primary = palette.text_primary
        text_secondary = palette.text_secondary

        self.greeting_title = ft.Text(
            "Olá! Que bom ter você aqui.",
            size=22,
            weight=ft.FontWeight.BOLD,
            color=text_primary,
        )
        self.greeting_subtitle = ft.Text(
            "Hora de ler e renovar sua mente com a Palavra?",
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        self.banner_streak_text = ft.Text(
            "0 dias",
            size=11,
            weight=ft.FontWeight.BOLD,
            color=palette.text_primary,
        )
        self.banner_xp_text = ft.Text(
            "0 XP",
            size=11,
            weight=ft.FontWeight.BOLD,
            color=palette.text_primary,
        )

        chip_streak = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=15, color=ft.Colors.ORANGE_ACCENT_400),
                    self.banner_streak_text,
                ],
                spacing=3,
                tight=True,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
            border_radius=12,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.18, palette.primary)),
            padding=ft.Padding.symmetric(horizontal=8, vertical=4),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, "/ofensiva")),
            tooltip="Ver calendário e histórico de ofensiva",
        )

        chip_xp = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.STAR_ROUNDED, size=15, color=ft.Colors.AMBER_400),
                    self.banner_xp_text,
                ],
                spacing=3,
                tight=True,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
            border_radius=12,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.18, palette.primary)),
            padding=ft.Padding.symmetric(horizontal=8, vertical=4),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, "/escola-sabatina?abrir_quiz=true")),
            tooltip="Toque para responder o Quiz diário e ganhar XP",
        )

        self.gamification_banner = ft.Row(
            controls=[chip_streak, chip_xp],
            spacing=6,
            tight=True,
        )

        # Card do versículo do dia (inicializado como miniatura AndBible instantânea se houver cache)
        from src.utils.storage_manager import storage_get_sync

        cached_ref = getattr(self, "_cached_ref_str", None) or storage_get_sync("cached_verse_ref")
        cached_preview = getattr(self, "_cached_preview_str", None) or storage_get_sync("cached_verse_preview")
        cached_cat = getattr(self, "_cached_cat_str", None) or storage_get_sync("cached_verse_cat", "Jovem")

        if cached_ref and cached_preview:
            self._cached_ref_str = cached_ref
            self._cached_preview_str = cached_preview
            self._cached_cat_str = cached_cat
            initial_content = self._build_verse_card_content(cached_ref, cached_preview, cached_cat)
            container_padding = 0
            container_bg = ft.Colors.TRANSPARENT
            container_border = None
        else:
            initial_content = ft.Row(
                controls=[
                    ft.Icon(ft.Icons.AUTO_STORIES, size=18, color=palette.primary),
                    ft.Text(
                        "Meditação Diária • Toque para ler o devocional de hoje",
                        size=12,
                        italic=True,
                        color=text_secondary,
                    ),
                ],
                spacing=8,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            )
            container_padding = ft.Padding.all(14)
            container_bg = palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface)
            container_border = ft.Border.all(1.0, ft.Colors.with_opacity(0.20, palette.primary))

        self.verse_container = ft.Container(
            content=initial_content,
            bgcolor=container_bg,
            border_radius=16,
            border=container_border,
            padding=container_padding,
            ink=True,
            on_click=lambda e: asyncio.create_task(self._abrir_destaque_meditacao()),
            tooltip="Toque para abrir a meditação em destaque",
            visible=True,
        )

        self.greeting_icon_glyph = ft.Icon(
            ft.Icons.AUTO_AWESOME_ROUNDED,
            size=24,
            color=palette.primary,
        )
        self.greeting_icon_box = ft.Container(
            content=self.greeting_icon_glyph,
            bgcolor=ft.Colors.with_opacity(0.15, palette.primary) if is_glass else palette.surface_container_high,
            border_radius=12,
            padding=ft.Padding.all(10),
        )

        controls_list: list[ft.Control] = []
        if self.refresh_indicator:
            controls_list.append(self.refresh_indicator)
        controls_list.extend([
            ft.Row(
                controls=[
                    self.greeting_icon_box,
                    ft.Column(
                        controls=[
                            self.greeting_title,
                            self.greeting_subtitle,
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    self.gamification_banner,
                ],
                spacing=10,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            ft.Container(height=4),
            self.verse_container,
        ])

        return ft.Container(
            content=ft.Column(
                controls=controls_list,
                spacing=6,
            ),
            padding=ft.Padding.only(top=6, bottom=14),
        )

    def build(self, page: ft.Page) -> ft.View:
        self.page = page

        # Aplica o tema configurado se necessário (ex: retorno de outra rota com edição distinta)
        if getattr(page, "theme", None) is None or self.theme_service.current_edition != "novo":
            self.theme_service.apply_theme(page, edition="novo")

        palette = self.theme_engine.get_current_palette()
        is_glass = self.theme_engine.theme_style == ThemeModeType.LIQUID_GLASS
        text_primary = palette.text_primary
        text_secondary = palette.text_secondary

        # Micro-indicador de Pull-to-Refresh
        self.refresh_indicator = ft.Container(
            content=ft.Row(
                controls=[
                    ft.ProgressRing(width=16, height=16, stroke_width=2.2, color=palette.primary),
                    ft.Text("Atualizando devocionais e métricas...", size=11, color=palette.primary),
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=8,
            ),
            padding=ft.Padding.symmetric(vertical=6),
            visible=False,
        )

        # Cabeçalho Personalizado com Versículo
        header = self._build_personalized_header(page, palette, is_glass)

        installed_bibles = self.content_manager.get_installed_bible_ids()
        has_biblia = len(installed_bibles) > 0
        bibles_summary = ", ".join(installed_bibles[:4]) if installed_bibles else "ARA, NVI..."

        def _build_action_pill(title: str, icon: ft.IconData, route: str) -> ft.Container:
            return ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Icon(icon, size=18, color=palette.primary),
                        ft.Text(title, size=12, weight=ft.FontWeight.W_600, color=text_primary),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    spacing=8,
                ),
                bgcolor=palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
                border=ft.Border.all(1.0, ft.Colors.with_opacity(0.16, palette.primary)),
                border_radius=12,
                padding=ft.Padding.symmetric(vertical=10, horizontal=14),
                ink=True,
                on_click=lambda e: asyncio.create_task(self._navigate(page, route)),
                expand=True,
            )

        quick_actions = ft.Container(
            content=ft.Row(
                controls=[
                    _build_action_pill("Agente de Cultos", ft.Icons.SMART_TOY_OUTLINED, "/agente"),
                    _build_action_pill("Downloads", ft.Icons.DOWNLOAD_OUTLINED, ROUTE_DOWNLOADS),
                ],
                spacing=10,
            ),
            padding=ft.Padding.only(top=8),
        )

        self.meditacao_subtitle_text = ft.Text(
            "Devocional Jovem • Mensagens Diárias",
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        self.escola_sabatina_subtitle_text = ft.Text(
            "Lição da Semana • Estudo Diário",
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        # ── Seção Acesso Rápido (Grid 2x2 com a cor de destaque do tema ativo) ──
        accent_color = palette.primary

        tile_biblia = self._build_action_grid_tile(
            page=page,
            title="Bíblia",
            subtitle=f"{bibles_summary} • 66 Livros" if has_biblia and len(bibles_summary) <= 12 else ("66 Livros" if has_biblia else "Baixar tradução"),
            icon=ft.Icons.MENU_BOOK_ROUNDED,
            color=accent_color,
            route="/biblia" if has_biblia else ROUTE_DOWNLOADS,
            text_primary=text_primary,
            text_secondary=text_secondary,
            badge_text="LIVROS" if has_biblia else "BAIXAR",
        )

        tile_hinario = self._build_action_grid_tile(
            page=page,
            title="Hinários",
            subtitle="Letras e áudios",
            icon=ft.Icons.MUSIC_NOTE_ROUNDED,
            color=accent_color,
            route="/novo",
            text_primary=text_primary,
            text_secondary=text_secondary,
            badge_text="2022/96",
        )

        self.meditacao_subtitle_text = ft.Text(
            "Devocional de hoje",
            size=11,
            color=text_secondary,
            max_lines=1,
            overflow=ft.TextOverflow.ELLIPSIS,
        )

        tile_meditacao = self._build_action_grid_tile(
            page=page,
            title="Meditação",
            subtitle="Devocional de hoje",
            icon=ft.Icons.VOLUNTEER_ACTIVISM_ROUNDED,
            color=accent_color,
            route="/meditacoes",
            text_primary=text_primary,
            text_secondary=text_secondary,
            badge_text="DIÁRIA",
            custom_subtitle_ref=self.meditacao_subtitle_text,
        )

        self.escola_sabatina_subtitle_text = ft.Text(
            "Lição da Semana • Estudo Diário",
            size=11,
            color=text_secondary,
            max_lines=1,
            overflow=ft.TextOverflow.ELLIPSIS,
        )

        tile_escola_sabatina = self._build_action_grid_tile(
            page=page,
            title="Escola Sabatina",
            subtitle="Estudo diário da lição",
            icon=ft.Icons.SCHOOL_ROUNDED,
            color=accent_color,
            route="/escola-sabatina",
            text_primary=text_primary,
            text_secondary=text_secondary,
            badge_text="LIÇÃO",
            custom_subtitle_ref=self.escola_sabatina_subtitle_text,
        )

        acesso_rapido_section = ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        ft.Text(
                            "Acesso Rápido",
                            size=16,
                            weight=ft.FontWeight.BOLD,
                            color=text_primary,
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.START,
                ),
                ft.Container(height=4),
                ft.Row(
                    controls=[tile_biblia, tile_hinario],
                    spacing=12,
                ),
                ft.Row(
                    controls=[tile_meditacao, tile_escola_sabatina],
                    spacing=12,
                ),
            ],
            spacing=8,
        )

        content_column = ft.Column(
            controls=[
                header,
                ft.Container(height=6),
                acesso_rapido_section,
                ft.Container(height=14),
                quick_actions,
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            scroll=ft.ScrollMode.AUTO,
            on_scroll=lambda e: (
                asyncio.create_task(self._on_pull_refresh())
                if ((e.pixels is not None and e.pixels < -70) or (getattr(e, "overscroll", None) is not None and e.overscroll < -70)) and not self._is_refreshing
                else None
            ),
            spacing=0,
            expand=True,
        )

        root_container = ft.Container(
            content=content_column,
            padding=ft.Padding.symmetric(horizontal=16, vertical=10),
            alignment=ft.Alignment.TOP_CENTER,
            gradient=(
                get_liquid_glass_background_gradient(self.theme_engine.is_dark)
                if is_glass
                else None
            ),
            expand=True,
        )

        appbar_bg = palette.surface

        # Carrega dados do cabeçalho em segundo plano sem bloquear a renderização
        page.run_task(self._load_header_data)

        return ft.View(
            route="/",
            bgcolor=palette.background,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    icon=ft.Icons.ACCOUNT_CIRCLE_OUTLINED,
                    icon_color=text_primary,
                    tooltip="Perfil & Preferências",
                    on_click=lambda e: self._show_profile_dialog(getattr(e, "page", None) or page),
                ),
                center_title=True,
                bgcolor=appbar_bg,
                actions=[
                    ft.IconButton(
                        icon=ft.Icons.SEARCH,
                        icon_color=text_primary,
                        tooltip="Pesquisa Geral no App",
                        on_click=lambda e: self._abrir_pesquisa_global(),
                    ),
                    ft.IconButton(
                        icon=ft.Icons.INFO_OUTLINE,
                        icon_color=text_primary,
                        tooltip="Sobre o App e Atualizações",
                        on_click=lambda e: self._show_about_dialog(getattr(e, "page", None) or page),
                    ),
                ],
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=root_container,
                    expand=True,
                )
            ],
        )
