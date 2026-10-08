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
        self.gamification_banner: ft.Container | None = None
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
                        content=ft.ElevatedButton(
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

    def _render_verse_content(self, ref_label: str, preview_text: str, cat_label: str) -> None:
        """Renderiza o conteúdo formatado do versículo da meditação no container do card."""
        if not self.verse_container:
            return
        if len(preview_text) > 130:
            preview_text = preview_text[:127] + "..."

        palette = self.theme_engine.get_current_palette()
        accent = palette.primary
        text_primary = palette.text_primary
        text_secondary = palette.text_secondary

        self.verse_container.content = ft.Column(
            controls=[
                ft.Row(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.FORMAT_QUOTE, size=18, color=accent),
                                ft.Text(
                                    ref_label,
                                    weight=ft.FontWeight.BOLD,
                                    size=13,
                                    color=accent,
                                ),
                                ft.Container(
                                    content=ft.Text(
                                        cat_label,
                                        size=10,
                                        weight=ft.FontWeight.BOLD,
                                        color=accent,
                                    ),
                                    bgcolor=ft.Colors.with_opacity(0.12, accent),
                                    border_radius=6,
                                    padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                                ),
                            ],
                            spacing=6,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Row(
                            controls=[
                                ft.Text("Ler meditação", size=11, color=accent, weight=ft.FontWeight.W_600),
                                ft.Icon(ft.Icons.ARROW_FORWARD_IOS, size=11, color=accent),
                            ],
                            spacing=3,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                ),
                ft.Text(
                    f'"{preview_text}"',
                    size=12,
                    italic=True,
                    color=text_secondary,
                ),
            ],
            spacing=6,
        )
        self.verse_container.visible = True

    def _update_verse_card(self, dev: Any, category: str) -> None:
        """Renderiza o conteúdo do versículo da meditação no container do card e persiste preview."""
        if not self.verse_container or not dev or not getattr(dev, "verse_text", None):
            return
        preview_text = dev.verse_text.strip()
        ref_label = getattr(dev, "verse_reference", "") or getattr(dev, "title", "")
        cat_label = category.capitalize()

        self._render_verse_content(ref_label, preview_text, cat_label)
        if self.page:
            asyncio.create_task(self._persist_verse_preview(ref_label, preview_text, cat_label))

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

    async def _load_header_data(self) -> None:
        """Carrega a saudação personalizada e o versículo do dia de forma estritamente offline-first."""
        if not self.page:
            return

        now = datetime.now()
        today_iso = now.date().isoformat()
        hour = now.hour

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
        last_date = await storage_get(self.page, "greeting_last_date", default="")
        last_idx = await storage_get(self.page, "greeting_last_index", default=None)

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
            # 3.1 Exibe imediatamente o último preview em cache rápido do storage
            cached_preview = await storage_get(self.page, "cached_verse_preview")
            cached_ref = await storage_get(self.page, "cached_verse_ref")
            cached_cat = await storage_get(self.page, "cached_verse_cat", default="Jovem")
            if cached_preview and cached_ref:
                self._render_verse_content(cached_ref, cached_preview, cached_cat)

            pref_cat = await storage_get(self.page, "preferred_devotional_category", default="jovem")
            category = str(pref_cat).lower() if pref_cat in ("jovem", "diario", "mulher") else "jovem"

            # Consulta PRIMEIRO estritamente no cache local SQLite (sem bloquear a UI com rede)
            dev = await self.devotional_service.get_cached_devotional(today_iso, category=category)
            if dev and getattr(dev, "verse_text", None):
                self._update_verse_card(dev, category)
            elif not cached_preview:
                # Se ainda não houver para hoje no banco local e nem preview, exibe a mais recente em cache
                try:
                    recents = await self.devotional_service.repository.get_recent(limit=1, category=category)
                    if recents and recents[0].verse_text:
                        self._update_verse_card(recents[0], category)
                    else:
                        self._set_verse_card_placeholder()
                except Exception:
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
                if self.banner_weekly_dots:
                    self._update_weekly_dots(weekly)
                if self.meditacao_subtitle_text and streak > 0:
                    self.meditacao_subtitle_text.value = f"🔥 {streak} dia(s) em sequência • Devocional Diário"
            except Exception:
                pass

        # 5. Atualiza subtítulo do card da Escola Sabatina com a categoria padrão
        if self.escola_sabatina_subtitle_text and self.page:
            try:
                ss_type = await storage_get(self.page, "preferred_ss_category")
                if not ss_type:
                    ss_type = await storage_get(self.page, "preferred_ss_type", default="adultos")
                ss_name = "Jovens" if str(ss_type).lower() == "jovens" else "Adultos"
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

    def _build_edition_card(
        self,
        page: ft.Page,
        title: str,
        subtitle: str,
        description: str,
        badge_text: str,
        icon: ft.IconData,
        badge_color: str,
        route: str,
        text_primary: str,
        text_secondary: str,
        custom_subtitle_ref: ft.Text | None = None,
    ) -> ft.Container:
        """Constrói um card interativo com estética adaptada ao tema ativo."""
        dec = get_card_decoration(self.theme_engine)
        is_glass = self.theme_engine.theme_style == ThemeModeType.LIQUID_GLASS
        is_dark = self.theme_engine.is_dark
        glass_palette = self.theme_engine.get_current_palette()

        if is_glass:
            icon_container = ft.Container(
                content=ft.Icon(icon, size=28, color=badge_color),
                gradient=ft.LinearGradient(
                    begin=ft.Alignment.TOP_LEFT,
                    end=ft.Alignment.BOTTOM_RIGHT,
                    colors=[
                        ft.Colors.with_opacity(0.85, glass_palette.surface_container_high),
                        ft.Colors.with_opacity(0.40, glass_palette.surface),
                    ],
                ),
                border=ft.Border.all(
                    1.0,
                    ft.Colors.with_opacity(0.35 if not is_dark else 0.20, glass_palette.primary),
                ),
                border_radius=14,
                padding=ft.Padding.all(12),
            )
            badge_container = ft.Container(
                content=ft.Text(
                    badge_text,
                    size=10,
                    weight=ft.FontWeight.BOLD,
                    color=badge_color,
                ),
                bgcolor=ft.Colors.with_opacity(0.18, badge_color),
                border=ft.Border.all(1.0, ft.Colors.with_opacity(0.35, badge_color)),
                border_radius=8,
                padding=ft.Padding.symmetric(horizontal=8, vertical=3),
            )
        else:
            icon_container = ft.Container(
                content=ft.Icon(icon, size=28, color=badge_color),
                bgcolor=ft.Colors.with_opacity(0.12, badge_color),
                border_radius=12,
                padding=ft.Padding.all(12),
            )
            badge_container = ft.Container(
                content=ft.Text(
                    badge_text,
                    size=10,
                    weight=ft.FontWeight.BOLD,
                    color=badge_color,
                ),
                bgcolor=ft.Colors.with_opacity(0.12, badge_color),
                border_radius=6,
                padding=ft.Padding.symmetric(horizontal=8, vertical=3),
            )

        subtitle_control = custom_subtitle_ref or ft.Text(
            subtitle,
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            icon_container,
                            ft.Column(
                                controls=[
                                    ft.Row(
                                        controls=[
                                            ft.Text(
                                                title,
                                                size=18,
                                                weight=ft.FontWeight.BOLD,
                                                color=text_primary,
                                            ),
                                            badge_container,
                                        ],
                                        spacing=8,
                                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                    ),
                                    subtitle_control,
                                ],
                                spacing=2,
                                expand=True,
                            ),
                            ft.Icon(
                                ft.Icons.ARROW_FORWARD_IOS,
                                size=16,
                                color=text_secondary,
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Container(
                        content=ft.Text(
                            description,
                            size=12,
                            color=text_secondary,
                        ),
                        padding=ft.Padding.only(top=8),
                    ),
                ],
                spacing=0,
            ),
            bgcolor=dec.get("bgcolor"),
            gradient=dec.get("gradient"),
            border=dec.get("border"),
            border_radius=dec.get("border_radius", 16),
            shadow=dec.get("shadow"),
            blur=dec.get("blur"),
            padding=ft.Padding.all(16),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, route)),
        )

    def _update_weekly_dots(self, weekly: list[bool]) -> None:
        """Atualiza visualmente os indicadores de dias da semana (Dom a Sáb)."""
        if not self.banner_weekly_dots:
            return
        palette = self.theme_engine.get_current_palette()
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
                            bgcolor=palette.primary if done else ft.Colors.with_opacity(0.18, palette.text_muted),
                            border=ft.Border.all(
                                1.5,
                                palette.primary if is_today else ft.Colors.TRANSPARENT,
                            ),
                        ),
                        ft.Text(
                            labels[i],
                            size=8,
                            weight=ft.FontWeight.BOLD if is_today else ft.FontWeight.NORMAL,
                            color=palette.primary if is_today else palette.text_secondary,
                        ),
                    ],
                    spacing=2,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                )
            )
        self.banner_weekly_dots.controls = dots

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

        # Banner de Gamificação Sleek (Ofensiva 🔥 + XP ⭐ + Indicadores Dominicais a Sabáticos)
        self.banner_streak_text = ft.Text(
            "0 dias seguidos",
            size=13,
            weight=ft.FontWeight.BOLD,
            color=palette.text_primary,
        )
        self.banner_xp_text = ft.Text(
            "0 XP",
            size=13,
            weight=ft.FontWeight.BOLD,
            color=palette.text_primary,
        )
        self.banner_weekly_dots = ft.Row(
            spacing=6,
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        )
        self._update_weekly_dots([False] * 7)

        self.gamification_banner = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Row(
                                controls=[
                                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=20, color=ft.Colors.ORANGE_ACCENT_400),
                                    self.banner_streak_text,
                                ],
                                spacing=4,
                                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            ft.Row(
                                controls=[
                                    ft.Icon(ft.Icons.STAR_ROUNDED, size=20, color=ft.Colors.AMBER_400),
                                    self.banner_xp_text,
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
                            ft.Text("Progresso da Semana", size=11, color=palette.text_secondary, weight=ft.FontWeight.W_500),
                            self.banner_weekly_dots,
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                ],
                spacing=6,
            ),
            bgcolor=palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
            border_radius=16,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.18, palette.primary)),
            padding=ft.Padding.symmetric(horizontal=14, vertical=10),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, "/escola-sabatina")),
            tooltip="Toque para abrir a Escola Sabatina e manter a sua ofensiva",
        )

        # Card do versículo do dia (inicializado com layout de leitura amigável instantâneo)
        self.verse_container = ft.Container(
            content=ft.Row(
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
            ),
            bgcolor=palette.surface_container_high if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
            border_radius=14,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.20, palette.primary)),
            padding=ft.Padding.all(14),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, "/meditacoes")),
            tooltip="Toque para abrir a meditação completa de hoje",
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
                ],
                spacing=12,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            ft.Container(height=2),
            self.gamification_banner,
            ft.Container(height=2),
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
        hinarios_badge_color = palette.primary
        biblia_badge_color = palette.primary
        meditacao_badge_color = palette.primary
        ss_badge_color = palette.primary

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

        card_hinarios = self._build_edition_card(
            page=page,
            title="Hinários",
            subtitle="Novo e Tradicional • Letras e Áudios",
            description="Edição Atual (2022) e Clássica (1996) com alternância rápida e busca inteligente.",
            badge_text="2022 & 1996",
            icon=ft.Icons.LIBRARY_MUSIC,
            badge_color=hinarios_badge_color,
            route="/novo",
            text_primary=text_primary,
            text_secondary=text_secondary,
        )

        installed_bibles = self.content_manager.get_installed_bible_ids()
        has_biblia = len(installed_bibles) > 0
        bibles_summary = ", ".join(installed_bibles[:4]) if installed_bibles else "ARA, NVI..."

        card_biblia = self._build_edition_card(
            page=page,
            title="Bíblia Sagrada",
            subtitle=f"{bibles_summary} • 66 Livros"
            if has_biblia
            else "Nenhuma tradução instalada • Baixe para ler",
            description="Leitura completa das Escrituras Sagradas com navegação rápida por livro e capítulo.",
            badge_text="BÍBLIA" if has_biblia else "BAIXAR TRADUÇÃO",
            icon=ft.Icons.AUTO_STORIES,
            badge_color=biblia_badge_color,
            route="/biblia" if has_biblia else ROUTE_DOWNLOADS,
            text_primary=text_primary,
            text_secondary=text_secondary,
        )

        quick_actions = ft.Container(
            content=ft.Row(
                controls=[
                    ft.OutlinedButton(
                        "Agente de Cultos",
                        icon=ft.Icons.SMART_TOY_OUTLINED,
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=12),
                            color=text_primary,
                        ),
                        on_click=lambda e: asyncio.create_task(
                            self._navigate(page, "/agente")
                        ),
                        expand=True,
                    ),
                    ft.OutlinedButton(
                        "Downloads",
                        icon=ft.Icons.DOWNLOAD_OUTLINED,
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=12),
                            color=text_primary,
                        ),
                        on_click=lambda e: asyncio.create_task(
                            self._navigate(page, ROUTE_DOWNLOADS)
                        ),
                        expand=True,
                    ),
                ],
                spacing=10,
            ),
            padding=ft.Padding.only(top=10),
        )

        self.meditacao_subtitle_text = ft.Text(
            "Devocional Jovem • Mensagens Diárias",
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        card_meditacao = self._build_edition_card(
            page=page,
            title="Meditação Diária",
            subtitle="Devocional Jovem • Mensagens Diárias",
            description="Leitura diária offline-first, versículos-chave com acesso direto à Bíblia e histórico.",
            badge_text="DEVOCIONAL",
            icon=ft.Icons.FAVORITE_ROUNDED,
            badge_color=meditacao_badge_color,
            route="/meditacoes",
            text_primary=text_primary,
            text_secondary=text_secondary,
            custom_subtitle_ref=self.meditacao_subtitle_text,
        )

        self.escola_sabatina_subtitle_text = ft.Text(
            "Lição da Semana • Estudo Diário",
            size=13,
            color=text_secondary,
            weight=ft.FontWeight.W_500,
        )

        card_escola_sabatina = self._build_edition_card(
            page=page,
            title="Escola Sabatina",
            subtitle="Lição da Semana • Estudo Diário",
            description="Guia de estudo diário com tirinhas, textos bíblicos interativos e anotações pessoais.",
            badge_text="LIÇÃO",
            icon=ft.Icons.MENU_BOOK_ROUNDED,
            badge_color=ss_badge_color,
            route="/escola-sabatina",
            text_primary=text_primary,
            text_secondary=text_secondary,
            custom_subtitle_ref=self.escola_sabatina_subtitle_text,
        )



        content_column = ft.Column(
            controls=[
                header,
                ft.Container(height=8),
                card_hinarios,
                ft.Container(height=12),
                card_biblia,
                ft.Container(height=12),
                card_meditacao,
                ft.Container(height=12),
                card_escola_sabatina,
                ft.Container(height=16),
                quick_actions,
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            scroll=ft.ScrollMode.AUTO,
            on_scroll=lambda e: (
                asyncio.create_task(self._on_pull_refresh())
                if getattr(e, "pixels", 0.0) < -25 and not self._is_refreshing
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
