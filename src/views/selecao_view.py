import asyncio
from datetime import date, datetime
import random
from typing import Any, Optional

import flet as ft

from src.services.auth_service import AuthService
from src.services.content_manager import ContentManager
from src.services.devotional_service import DevotionalService
from src.services.reading_service import ReadingService
from src.services.theme_service import ThemeService
from src.services.updater_service import UpdaterService
from src.theme.glass_styles import (
    get_card_decoration,
    get_liquid_glass_background_gradient,
)
from src.theme.palette import ThemeModeType, get_palette
from src.theme.theme_engine import ThemeEngine
from src.utils.storage_manager import storage_get, storage_set
from src.views.settings_dialog import show_settings_dialog

try:
    from src.version import __version__ as APP_VERSION
except ImportError:
    APP_VERSION = "0.4.20"

ROUTE_DOWNLOADS = "/downloads"

GREETING_POOLS = {
    "manha": [
        ("Bom dia{nome}! ☀️", "Que a Palavra ilumine seu caminho hoje."),
        ("Bom dia{nome}! ☀️", "Hora de começar o dia com inspiração e fé."),
        ("Bom dia{nome}! ☀️", "Uma manhã com a Palavra renova o coração."),
    ],
    "tarde": [
        ("Boa tarde{nome}! 🌤️", "Que tal uma pausa para alimentar a alma?"),
        ("Boa tarde{nome}! 🌤️", "A Palavra é lâmpada para os seus passos."),
        ("Boa tarde{nome}! 🌤️", "Renove sua mente com a leitura de hoje."),
    ],
    "noite": [
        ("Boa noite{nome}! 🌙", "Encerre o dia refletindo na Palavra de Deus."),
        ("Boa noite{nome}! 🌙", "Uma leitura antes de descansar traz paz ao coração."),
        ("Boa noite{nome}! 🌙", "Que a paz do Senhor guarde seus pensamentos."),
    ],
}


class SelecaoView:
    """
    Tela inicial (Hub de Entrada) do aplicativo Hinário Inteligente.
    Apresenta uma interface moderna e acolhedora com saudação personalizada,
    card do versículo do dia, e acesso aos hinários, bíblia e ferramentas.
    """

    def __init__(
        self,
        theme_service: ThemeService,
        updater_service: UpdaterService | None = None,
        content_manager: ContentManager | None = None,
        theme_engine: ThemeEngine | None = None,
        auth_service: AuthService | None = None,
        devotional_service: DevotionalService | None = None,
        reading_service: ReadingService | None = None,
    ):
        self.theme_service = theme_service
        self.updater_service = updater_service or UpdaterService()
        self.content_manager = content_manager or ContentManager()
        self.auth_service = auth_service or AuthService()
        self.devotional_service = devotional_service
        self.reading_service = reading_service
        self.theme_engine = (
            theme_engine
            or getattr(theme_service, "theme_engine", None)
            or ThemeEngine()
        )
        self.page: ft.Page | None = None

        # Controles reativos do cabeçalho
        self.greeting_title: ft.Text | None = None
        self.greeting_subtitle: ft.Text | None = None
        self.verse_container: ft.Container | None = None
        self.meditacao_subtitle_text: ft.Text | None = None

    async def _navigate(self, page: ft.Page, route: str) -> None:
        await page.push_route(route)

    def _show_about_dialog(self, page: ft.Page | None = None, e=None):
        """Abre o modal de Configurações, Temas e Sobre o App."""
        target_page = page if isinstance(page, ft.Page) else self.page
        if not target_page:
            return
        show_settings_dialog(
            page=target_page,
            theme_service=self.theme_service,
            updater_service=self.updater_service,
            auth_service=self.auth_service,
            edition="novo",
        )

    async def _load_header_data(self) -> None:
        """Carrega a saudação personalizada e o versículo do dia assincronamente."""
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

        # 3. Carrega o versículo da meditação de hoje
        if self.devotional_service and self.verse_container:
            pref_cat = await storage_get(self.page, "preferred_devotional_category", default="jovem")
            category = str(pref_cat).lower() if pref_cat in ("jovem", "diario", "mulher") else "jovem"

            dev = await self.devotional_service.get_devotional(today_iso, category=category)
            if dev and dev.verse_text:
                preview_text = dev.verse_text.strip()
                if len(preview_text) > 130:
                    preview_text = preview_text[:127] + "..."

                ref_label = dev.verse_reference or dev.title
                cat_label = category.capitalize()

                self.verse_container.content = ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Row(
                                    controls=[
                                        ft.Icon(ft.Icons.FORMAT_QUOTE, size=18, color=ft.Colors.PRIMARY),
                                        ft.Text(
                                            ref_label,
                                            weight=ft.FontWeight.BOLD,
                                            size=13,
                                            color=ft.Colors.PRIMARY,
                                        ),
                                        ft.Container(
                                            content=ft.Text(
                                                cat_label,
                                                size=10,
                                                weight=ft.FontWeight.BOLD,
                                                color=ft.Colors.PRIMARY,
                                            ),
                                            bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
                                            border_radius=6,
                                            padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                                        ),
                                    ],
                                    spacing=6,
                                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                ),
                                ft.Row(
                                    controls=[
                                        ft.Text("Ler meditação", size=11, color=ft.Colors.PRIMARY, weight=ft.FontWeight.W_600),
                                        ft.Icon(ft.Icons.ARROW_FORWARD_IOS, size=11, color=ft.Colors.PRIMARY),
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
                            color=ft.Colors.ON_SURFACE,
                        ),
                    ],
                    spacing=6,
                )
                self.verse_container.visible = True

        # 4. Atualiza subtítulo do card de meditação com a streak (se houver)
        if self.reading_service and self.meditacao_subtitle_text:
            try:
                streak = await self.reading_service.get_current_streak()
                if streak > 0:
                    self.meditacao_subtitle_text.value = f"🔥 {streak} dia(s) em sequência • Devocional Diário"
            except Exception:
                pass

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

        if is_glass:
            icon_container = ft.Container(
                content=ft.Icon(icon, size=28, color=badge_color),
                gradient=ft.LinearGradient(
                    begin=ft.Alignment.TOP_LEFT,
                    end=ft.Alignment.BOTTOM_RIGHT,
                    colors=[
                        ft.Colors.with_opacity(0.85, "#FFFFFF" if not is_dark else "#334155"),
                        ft.Colors.with_opacity(0.40, "#F1F5F9" if not is_dark else "#1E293B"),
                    ],
                ),
                border=ft.Border.all(
                    1.0,
                    ft.Colors.with_opacity(0.60 if not is_dark else 0.20, ft.Colors.WHITE),
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
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
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
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
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

    def _build_personalized_header(self, page: ft.Page, palette: Any, is_glass: bool) -> ft.Container:
        """Constrói cabeçalho acolhedor com saudação diária e card de versículo em destaque."""
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

        # Card do versículo do dia (preenchido assincronamente)
        self.verse_container = ft.Container(
            content=ft.Row(
                controls=[
                    ft.ProgressRing(width=16, height=16, stroke_width=2),
                    ft.Text("Buscando a meditação do dia...", size=12, italic=True, color=text_secondary),
                ],
                spacing=8,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST if not is_glass else ft.Colors.with_opacity(0.40, palette.surface),
            border_radius=14,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.20, ft.Colors.PRIMARY)),
            padding=ft.Padding.all(14),
            ink=True,
            on_click=lambda e: asyncio.create_task(self._navigate(page, "/meditacoes")),
            tooltip="Toque para abrir a meditação completa de hoje",
            visible=True,
        )

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Container(
                                content=ft.Icon(
                                    ft.Icons.AUTO_AWESOME_ROUNDED,
                                    size=24,
                                    color=palette.primary,
                                ),
                                bgcolor=ft.Colors.with_opacity(0.15, palette.primary) if is_glass else palette.surface_container_high,
                                border_radius=12,
                                padding=ft.Padding.all(10),
                            ),
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
                    ft.Container(height=4),
                    self.verse_container,
                ],
                spacing=8,
            ),
            padding=ft.Padding.only(top=6, bottom=14),
        )

    def build(self, page: ft.Page) -> ft.View:
        self.page = page

        # Aplica o tema configurado
        self.theme_service.apply_theme(page, edition="novo")

        palette = self.theme_engine.get_current_palette()
        is_glass = self.theme_engine.theme_style == ThemeModeType.LIQUID_GLASS
        text_primary = palette.text_primary
        text_secondary = palette.text_secondary
        novo_badge_color = palette.primary
        antigo_badge_color = palette.primary if not is_glass else "#F59E0B"
        biblia_badge_color = palette.primary if not is_glass else "#10B981"

        # Cabeçalho Personalizado com Versículo
        header = self._build_personalized_header(page, palette, is_glass)

        card_novo = self._build_edition_card(
            page=page,
            title="Hinário Novo",
            subtitle="Edição Atual (2022) • 601 Hinos",
            description="Busca inteligente, letras oficiais, novos arranjos e referências bíblicas.",
            badge_text="NOVO",
            icon=ft.Icons.AUTO_AWESOME,
            badge_color=novo_badge_color,
            route="/novo",
            text_primary=text_primary,
            text_secondary=text_secondary,
        )

        has_antigo = self.content_manager.is_module_installed("hinario_antigo")
        card_antigo = self._build_edition_card(
            page=page,
            title="Hinário Tradicional",
            subtitle="Edição Clássica (1996) • 613 Hinos"
            if has_antigo
            else "Módulo adicional • Baixar para ler",
            description="Todas as poesias tradicionais com comparativo automático da nova edição.",
            badge_text="CLÁSSICO" if has_antigo else "BAIXAR",
            icon=ft.Icons.MENU_BOOK,
            badge_color=antigo_badge_color,
            route="/antigo" if has_antigo else ROUTE_DOWNLOADS,
            text_primary=text_primary,
            text_secondary=text_secondary,
        )

        has_biblia = self.content_manager.has_any_bible_installed()
        installed_bibles = self.content_manager.get_installed_bible_ids()
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

        meditacao_badge_color = palette.primary if not is_glass else "#EC4899"
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

        content_column = ft.Column(
            controls=[
                header,
                ft.Container(height=8),
                card_novo,
                ft.Container(height=12),
                card_antigo,
                ft.Container(height=12),
                card_biblia,
                ft.Container(height=12),
                card_meditacao,
                ft.Container(height=16),
                quick_actions,
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            scroll=ft.ScrollMode.AUTO,
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
                title=ft.Text(
                    "Hinário Inteligente",
                    weight=ft.FontWeight.BOLD,
                    color=text_primary,
                ),
                center_title=True,
                bgcolor=appbar_bg,
                actions=[
                    ft.IconButton(
                        icon=ft.Icons.INFO_OUTLINE,
                        icon_color=text_primary,
                        tooltip="Sobre o App e Configurações",
                        on_click=lambda e: self._show_about_dialog(page),
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
