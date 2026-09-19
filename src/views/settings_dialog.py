"""
Modal de Configurações, Temas e Sobre o Aplicativo.
Oferece interface Material 3 com duas abas dedicadas:
1. Aba "Sobre o App":
   - Informações do projeto (nome, versão, descrição)
   - Botão de acesso ao repositório GitHub (https://github.com/Lucas2Araujo/Kairos)
   - Botão para verificação de atualizações
2. Aba "Aparência":
   - Modo de Tema: Claro, Escuro, Padrão do Sistema (Automático)
   - Modo Telas AMOLED com dependência condicional (ativo apenas no modo escuro)
   - Sementes de Cor M3: Violeta M3, Dourado Sacro, Verde Bíblico, Azul Safira
   - Tipografia Global: Roboto, Montserrat, Inter, Merriweather, OpenDyslexic
"""

import asyncio
import inspect
from typing import Any, cast
import weakref

import flet as ft

from src.services.auth_service import AuthService
from src.services.theme_service import COLOR_SEEDS, FONT_FAMILIES, ThemeService
from src.services.updater_service import UpdaterService
from src.utils.storage_manager import storage_get, storage_set

try:
    from src.version import __version__ as APP_VERSION
except ImportError:
    APP_VERSION = "0.2.2"


def ensure_page_dialogs(page: ft.Page | None) -> None:
    """
    Garante que os contêineres internos _dialogs e _overlay do Flet estejam
    corretamente vinculados à Page através de weakref, contornando a limitação
    de inicialização do Flet onde 'self.page' falha em _dialogs.update().
    """
    if not page:
        return
    dialogs = getattr(page, "_dialogs", None)
    if dialogs is not None and getattr(dialogs, "parent", None) is None:
        try:
            setattr(dialogs, "_parent", weakref.ref(page))
        except Exception:
            pass
    overlay = getattr(page, "_overlay", None)
    if overlay is not None and getattr(overlay, "parent", None) is None:
        try:
            setattr(overlay, "_parent", weakref.ref(page))
        except Exception:
            pass


class SettingsDialogController:
    """Controlador do Modal em Abas de Configurações, Temas e Sobre."""

    def __init__(
        self,
        page: ft.Page | None,
        theme_service: ThemeService,
        updater_service: UpdaterService | None = None,
        auth_service: AuthService | None = None,
        edition: str | None = None,
        on_check_updates: Any | None = None,
        initial_tab: str = "sobre",
    ):
        self.page = page
        self.theme_service = theme_service
        self.updater_service = updater_service
        self.auth_service = auth_service or AuthService()
        self.edition = edition
        self.on_check_updates = on_check_updates
        self.active_tab = initial_tab
        self.bottom_sheet: ft.BottomSheet | None = None

        # Controles da navegação em abas
        self.tab_selector: ft.SegmentedButton | None = None
        self.sobre_container: ft.Container | None = None
        self.about_actions: ft.Row | None = None
        self.aparencia_container: ft.Container | None = None
        self.amoled_tile: ft.Container | None = None
        self.aparencia_font_container: ft.Container | None = None
        self.conta_container: ft.Container | None = None
        self.meditacao_container: ft.Container | None = None
        self.escola_sabatina_container: ft.Container | None = None

        # Controles reativos da aba Aparência
        self.theme_style_segmented: ft.SegmentedButton | None = None
        self.glass_blur_switch: ft.Switch | None = None
        self.glass_blur_tile: ft.Container | None = None
        self.theme_mode_segmented: ft.SegmentedButton | None = None
        self.seed_chips_row: ft.Row | None = None
        self.amoled_switch: ft.Switch | None = None
        self.amoled_subtitle: ft.Text | None = None
        self.font_dropdown: ft.Dropdown | None = None
        self.is_logging_in: bool = False

    def _close_dialog(self, _e=None) -> None:
        if self.page:
            try:
                self.page.pop_dialog()
            except Exception:
                pass
        if self.bottom_sheet:
            self.bottom_sheet.open = False
            try:
                self.bottom_sheet.update()
            except Exception:
                pass

    def _on_tab_change(self, e: Any) -> None:
        selected_set = getattr(e.control, "selected", None)
        if selected_set:
            self.active_tab = next(iter(selected_set))
            self._update_tab_visibility()
            if self.bottom_sheet:
                try:
                    self.bottom_sheet.update()
                except Exception:
                    if self.page:
                        self.page.update()
            elif self.page:
                self.page.update()

    def _update_tab_visibility(self) -> None:
        is_sobre = self.active_tab == "sobre"
        is_aparencia = self.active_tab == "aparencia"
        is_conta = self.active_tab == "conta"

        if self.sobre_container:
            self.sobre_container.visible = is_sobre
        if self.meditacao_container:
            self.meditacao_container.visible = is_sobre
        if self.escola_sabatina_container:
            self.escola_sabatina_container.visible = is_sobre
        if self.about_actions:
            self.about_actions.visible = is_sobre
        if self.aparencia_container:
            self.aparencia_container.visible = is_aparencia
        if self.amoled_tile:
            self.amoled_tile.visible = is_aparencia
        if self.aparencia_font_container:
            self.aparencia_font_container.visible = is_aparencia
        if self.conta_container:
            self.conta_container.visible = is_conta
        if self.tab_selector:
            self.tab_selector.selected = [self.active_tab]

    async def _on_theme_mode_change(self, e: Any) -> None:
        selected_set = getattr(e.control, "selected", None)
        if selected_set:
            mode = next(iter(selected_set))
            await self.theme_service.set_theme_mode(mode, self.page)
            self._update_controls_state()

    async def _on_theme_style_change(self, e) -> None:
        selected = getattr(e.control, "selected", None)
        if selected:
            val = next(iter(selected))
            if hasattr(self.theme_service, "set_theme_style"):
                await self.theme_service.set_theme_style(val, self.page)
            self._update_controls_state()

    async def _on_glass_blur_toggle(self, enabled: bool) -> None:
        if hasattr(self.theme_service, "set_glass_blur_enabled"):
            await self.theme_service.set_glass_blur_enabled(enabled, self.page)
        elif hasattr(self.theme_service, "theme_engine"):
            await self.theme_service.theme_engine.set_glass_blur_enabled(enabled, self.page)
        self._update_controls_state()

    async def _on_seed_select(self, seed_key: str) -> None:
        await self.theme_service.set_seed(seed_key, self.page)
        self._update_controls_state()

    async def _on_amoled_toggle(self, enabled: bool) -> None:
        if self.theme_service.theme_mode == "light":
            if self.amoled_switch:
                self.amoled_switch.value = False
            return
        if not self.page:
            return
        await self.theme_service.toggle_amoled(
            self.page, enabled, edition=self.edition
        )
        self._update_controls_state()

    async def _on_font_change(self, font_family: str) -> None:
        if font_family:
            await self.theme_service.set_font_family(font_family, self.page)
            self._update_controls_state()

    def _update_controls_state(self) -> None:
        """Atualiza os controles visuais dentro da aba de Aparência."""
        if self.theme_style_segmented and hasattr(self.theme_service, "theme_style"):
            style_val = getattr(self.theme_service.theme_style, "value", str(self.theme_service.theme_style))
            self.theme_style_segmented.selected = [style_val]
        if self.glass_blur_switch:
            engine = getattr(self.theme_service, "theme_engine", None)
            self.glass_blur_switch.value = getattr(engine, "glass_blur_enabled", True) if engine else True
        if self.glass_blur_tile and hasattr(self.theme_service, "theme_style"):
            style_val = getattr(self.theme_service.theme_style, "value", str(self.theme_service.theme_style))
            self.glass_blur_tile.visible = (style_val == "liquid_glass")
        if self.theme_mode_segmented:
            self.theme_mode_segmented.selected = [self.theme_service.theme_mode]
        if self.amoled_switch:
            self.amoled_switch.value = self.theme_service.is_amoled
        if self.font_dropdown:
            self.font_dropdown.value = self.theme_service.font_family
        if self.seed_chips_row:
            self.seed_chips_row.controls = cast(list[ft.Control], self._build_seed_chips())
        self._update_amoled_state()
        if self.bottom_sheet:
            try:
                self.bottom_sheet.update()
            except Exception:
                if self.page:
                    self.page.update()
        elif self.page:
            self.page.update()

    def _update_amoled_state(self) -> None:
        """Gerencia a dependência condicional do switch AMOLED conforme o modo de tema."""
        is_light = self.theme_service.theme_mode == "light"
        if self.amoled_switch:
            if is_light:
                self.amoled_switch.disabled = True
                self.amoled_switch.value = False
            else:
                self.amoled_switch.disabled = False
                self.amoled_switch.value = self.theme_service.is_amoled

        if self.amoled_subtitle:
            if is_light:
                self.amoled_subtitle.value = (
                    "Disponível apenas quando o modo escuro estiver ativo."
                )
            else:
                self.amoled_subtitle.value = (
                    "Preto puro (#000000) e economia em telas OLED"
                )

    def _build_seed_chips(self) -> list[ft.Control]:
        chips: list[ft.Control] = []
        current_seed = self.theme_service.current_seed

        for key, info in COLOR_SEEDS.items():
            is_active = key == current_seed
            chip_color = info["hex"]
            chip_name = info["name"]

            chip = ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Container(
                            width=26,
                            height=26,
                            border_radius=13,
                            bgcolor=chip_color,
                            alignment=ft.Alignment.CENTER,
                            border=ft.Border.all(
                                2,
                                ft.Colors.PRIMARY
                                if is_active
                                else ft.Colors.TRANSPARENT,
                            ),
                        ),
                        ft.Text(
                            chip_name,
                            size=10,
                            weight=ft.FontWeight.BOLD
                            if is_active
                            else ft.FontWeight.NORMAL,
                            color=ft.Colors.PRIMARY
                            if is_active
                            else ft.Colors.ON_SURFACE_VARIANT,
                            text_align=ft.TextAlign.CENTER,
                            no_wrap=True,
                        ),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=4,
                ),
                padding=ft.Padding.symmetric(horizontal=8, vertical=6),
                border_radius=12,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST
                if is_active
                else ft.Colors.SURFACE_CONTAINER_LOW,
                border=ft.Border.all(
                    1.5 if is_active else 1,
                    ft.Colors.PRIMARY if is_active else ft.Colors.OUTLINE_VARIANT,
                ),
                ink=True,
                on_click=lambda _e, k=key: asyncio.create_task(self._on_seed_select(k)),
            )
            chips.append(chip)
        return chips

    def build_bottom_sheet(self) -> ft.BottomSheet:
        # 1. Header com título e botão Fechar
        header = ft.Row(
            controls=[
                ft.Row(
                    controls=[
                        ft.Icon(
                            ft.Icons.INFO_OUTLINE,
                            size=20,
                            color=ft.Colors.PRIMARY,
                        ),
                        ft.Text(
                            "Configurações e Sobre",
                            weight=ft.FontWeight.BOLD,
                            size=17,
                        ),
                    ],
                    spacing=8,
                ),
                ft.IconButton(
                    ft.Icons.CLOSE,
                    tooltip="Fechar",
                    on_click=self._close_dialog,
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        )

        # 2. Seletor de Abas (SegmentedButton)
        self.tab_selector = ft.SegmentedButton(
            segments=[
                ft.Segment(
                    value="sobre",
                    label=ft.Text("Sobre", size=12),
                    icon=ft.Icon(ft.Icons.INFO_OUTLINE, size=16),
                ),
                ft.Segment(
                    value="aparencia",
                    label=ft.Text("Aparência", size=12),
                    icon=ft.Icon(ft.Icons.PALETTE_OUTLINED, size=16),
                ),
                ft.Segment(
                    value="conta",
                    label=ft.Text("Conta", size=12),
                    icon=ft.Icon(ft.Icons.ACCOUNT_CIRCLE_OUTLINED, size=16),
                ),
            ],
            selected=[self.active_tab],
            allow_multiple_selection=False,
            on_change=self._on_tab_change,
        )

        # 3. Conteúdo da Aba SOBRE
        about_card = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Container(
                                content=ft.Icon(
                                    ft.Icons.LIBRARY_MUSIC,
                                    size=28,
                                    color=ft.Colors.PRIMARY,
                                ),
                                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                                border_radius=10,
                                padding=ft.Padding.all(8),
                            ),
                            ft.Column(
                                controls=[
                                    ft.Text(
                                        "Kairós",
                                        weight=ft.FontWeight.BOLD,
                                        size=15,
                                    ),
                                    ft.Text(
                                        f"Versão {APP_VERSION}",
                                        size=12,
                                        color=ft.Colors.PRIMARY,
                                        weight=ft.FontWeight.W_600,
                                    ),
                                ],
                                spacing=2,
                            ),
                        ],
                        spacing=10,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Text(
                        "Kairós — Tempo de qualidade com Deus. Aplicação cristã moderna com busca inteligente, letras oficiais, bíblia integrada, "
                        "comparação entre hinários (2022 e 1996), meditação diária, áudios offline e agente litúrgico de cultos.",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                    ft.TextButton(
                        "Exibir tela de boas-vindas novamente (Testes)",
                        icon=ft.Icons.AUTO_AWESOME,
                        on_click=lambda _e: self._trigger_show_welcome(),
                    ),
                ],
                spacing=8,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=10,
            padding=ft.Padding.all(12),
        )

        self.about_actions = ft.Row(
            controls=[
                ft.OutlinedButton(
                    "GitHub do Projeto",
                    icon=ft.Icons.CODE,
                    url="https://github.com/Lucas2Araujo/Kairos",
                    on_click=lambda _e: asyncio.create_task(
                        self._open_url("https://github.com/Lucas2Araujo/Kairos")
                    ),
                    expand=True,
                ),
                ft.FilledTonalButton(
                    "Verificar Atualizações",
                    icon=ft.Icons.SYSTEM_UPDATE_ALT,
                    on_click=lambda _e: asyncio.create_task(
                        self._trigger_check_updates()
                    ),
                    expand=True,
                ),
            ],
            spacing=10,
            visible=(self.active_tab == "sobre"),
        )

        self.sobre_container = ft.Container(
            content=about_card,
            visible=(self.active_tab == "sobre"),
        )

        self.meditacao_container = ft.Container(
            content=self._build_devotional_settings_card(),
            visible=(self.active_tab == "sobre"),
        )

        self.escola_sabatina_container = ft.Container(
            content=self._build_escola_sabatina_settings_card(),
            visible=(self.active_tab == "sobre"),
        )

        # 3.1 Conteúdo da Aba CONTA (Autenticação Google / Supabase)
        self.conta_container = ft.Container(
            content=self._build_account_view(),
            visible=(self.active_tab == "conta"),
        )

        # 4. Conteúdo da Aba APARÊNCIA
        # 4.0 Seletor de Estilo de Tema (Theme Engine)
        current_style = getattr(self.theme_service, "theme_style", None)
        current_style_val = (
            current_style.value
            if hasattr(current_style, "value")
            else str(current_style or "material_you")
        )
        self.theme_style_segmented = ft.SegmentedButton(
            segments=[
                ft.Segment(
                    value="material_you",
                    label=ft.Text("Material You", size=10),
                    icon=ft.Icon(ft.Icons.AUTO_AWESOME_OUTLINED, size=14),
                ),
                ft.Segment(
                    value="liquid_glass",
                    label=ft.Text("Liquid Glass", size=10),
                    icon=ft.Icon(ft.Icons.BLUR_ON, size=14),
                ),
                ft.Segment(
                    value="classic_book",
                    label=ft.Text("Classic Book", size=10),
                    icon=ft.Icon(ft.Icons.MENU_BOOK, size=14),
                ),
            ],
            selected=[current_style_val],
            allow_multiple_selection=False,
            on_change=lambda e: asyncio.create_task(self._on_theme_style_change(e)),
        )

        # 4.0.1 Modo Desempenho / Desfoque Liquid Glass
        engine = getattr(self.theme_service, "theme_engine", None)
        blur_enabled = getattr(engine, "glass_blur_enabled", True) if engine else True

        self.glass_blur_switch = ft.Switch(
            value=blur_enabled,
            on_change=lambda e: asyncio.create_task(
                self._on_glass_blur_toggle(e.control.value)
            ),
        )
        self.glass_blur_tile = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.BLUR_ON, size=20, color=ft.Colors.PRIMARY),
                    ft.Column(
                        controls=[
                            ft.Text(
                                "Desfoque Vítreo Avançado",
                                size=13,
                                weight=ft.FontWeight.W_500,
                            ),
                            ft.Text(
                                "Desative se notar lentidão no aparelho",
                                size=11,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                            ),
                        ],
                        spacing=1,
                        expand=True,
                    ),
                    self.glass_blur_switch,
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            padding=ft.Padding.symmetric(vertical=4),
            visible=(current_style_val == "liquid_glass"),
        )

        # 4.1 Seletor de Modo de Tema
        self.theme_mode_segmented = ft.SegmentedButton(
            segments=[
                ft.Segment(
                    value="light",
                    label=ft.Text("Claro", size=12),
                    icon=ft.Icon(ft.Icons.LIGHT_MODE_OUTLINED, size=16),
                ),
                ft.Segment(
                    value="dark",
                    label=ft.Text("Escuro", size=12),
                    icon=ft.Icon(ft.Icons.DARK_MODE_OUTLINED, size=16),
                ),
                ft.Segment(
                    value="system",
                    label=ft.Text("Sistema", size=12),
                    icon=ft.Icon(ft.Icons.BRIGHTNESS_AUTO, size=16),
                ),
            ],
            selected=[self.theme_service.theme_mode],
            allow_multiple_selection=False,
            on_change=lambda e: asyncio.create_task(self._on_theme_mode_change(e)),
        )

        # 4.2 Seletor de Seeds M3
        self.seed_chips_row = ft.Row(
            controls=self._build_seed_chips(),
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            spacing=6,
        )

        # 4.3 Switch AMOLED com dependência condicional
        self.amoled_subtitle = ft.Text(
            "Preto puro (#000000) e economia em telas OLED",
            size=11,
            color=ft.Colors.ON_SURFACE_VARIANT,
        )
        self.amoled_switch = ft.Switch(
            value=self.theme_service.is_amoled,
            on_change=lambda ev: asyncio.create_task(
                self._on_amoled_toggle(ev.control.value)
            ),
        )
        self._update_amoled_state()

        self.amoled_tile = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(
                                ft.Icons.DARK_MODE_OUTLINED,
                                size=22,
                                color=ft.Colors.AMBER_300,
                            ),
                            ft.Column(
                                controls=[
                                    ft.Text(
                                        "Modo Telas AMOLED",
                                        weight=ft.FontWeight.BOLD,
                                        size=13,
                                    ),
                                    ft.Text(
                                        "Preto puro (#000000) e máxima economia em telas OLED",
                                        size=11,
                                        color=ft.Colors.ON_SURFACE_VARIANT,
                                    ),
                                    self.amoled_subtitle,
                                ],
                                spacing=1,
                            ),
                        ],
                        spacing=10,
                        expand=True,
                    ),
                    self.amoled_switch,
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=10,
            padding=ft.Padding.symmetric(horizontal=12, vertical=8),
            visible=(self.active_tab == "aparencia"),
        )

        # 4.4 Seletor de Fonte
        self.font_dropdown = ft.Dropdown(
            options=[
                ft.dropdown.Option(
                    key=f,
                    text=(
                        f"{f} (Padrão M3)"
                        if f == "Roboto"
                        else (
                            f"{f} (Acessibilidade)"
                            if f == "OpenDyslexic"
                            else f
                        )
                    ),
                )
                for f in FONT_FAMILIES
            ],
            value=self.theme_service.font_family,
            dense=True,
            border_radius=10,
            content_padding=ft.Padding.symmetric(horizontal=12, vertical=8),
            on_select=lambda ev: asyncio.create_task(
                self._on_font_change(ev.control.value)
            ),
        )

        self.aparencia_container = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Text(
                        "Estilo Visual (Theme Engine)",
                        size=13,
                        weight=ft.FontWeight.BOLD,
                        color=ft.Colors.PRIMARY,
                    ),
                    self.theme_style_segmented,
                    self.glass_blur_tile,
                    ft.Container(height=4),
                    ft.Text(
                        "Modo de Tema",
                        size=13,
                        weight=ft.FontWeight.BOLD,
                        color=ft.Colors.PRIMARY,
                    ),
                    self.theme_mode_segmented,
                    ft.Container(height=4),
                    ft.Text(
                        "Paleta Harmônica (Material 3 Seed)",
                        size=13,
                        weight=ft.FontWeight.BOLD,
                        color=ft.Colors.PRIMARY,
                    ),
                    self.seed_chips_row,
                ],
                spacing=8,
            ),
            visible=(self.active_tab == "aparencia"),
        )

        self.aparencia_font_container = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.TEXT_FIELDS, size=18, color=ft.Colors.PRIMARY),
                            ft.Text(
                                "Tipografia Global do App",
                                size=13,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.PRIMARY,
                            ),
                        ],
                        spacing=6,
                    ),
                    self.font_dropdown,
                ],
                spacing=8,
            ),
            visible=(self.active_tab == "aparencia"),
        )

        # Montagem Principal do Conteúdo
        content_column = ft.Column(
            controls=[
                header,
                ft.Divider(height=1),
                self.tab_selector,
                ft.Container(height=6),
                self.sobre_container,
                self.meditacao_container,
                self.escola_sabatina_container,
                self.about_actions,
                self.conta_container,
                self.aparencia_container,
                self.amoled_tile,
                self.aparencia_font_container,
            ],
            scroll=ft.ScrollMode.AUTO,
            tight=True,
            spacing=8,
        )

        self.bottom_sheet = ft.BottomSheet(
            scrollable=True,
            show_drag_handle=True,
            use_safe_area=True,
            maintain_bottom_view_insets_padding=True,
            content=ft.Container(
                content=content_column,
                padding=ft.Padding.only(left=20, top=10, right=20, bottom=30),
            ),
        )
        return self.bottom_sheet

    def _build_devotional_settings_card(self) -> ft.Container:
        """Card com configurações dedicadas à Meditação Diária (categoria preferida e auto-cleanup)."""
        cat_segmented = ft.SegmentedButton(
            segments=[
                ft.Segment(value="jovem", label=ft.Text("Jovem", size=11)),
                ft.Segment(value="diario", label=ft.Text("Diário", size=11)),
                ft.Segment(value="mulher", label=ft.Text("Mulher", size=11)),
            ],
            selected=["jovem"],
            allow_multiple_selection=False,
        )

        cleanup_switch = ft.Switch(value=True)

        async def _load_devotional_settings():
            if not self.page:
                return
            try:
                saved_cat = await storage_get(self.page, "preferred_devotional_category", default="jovem")
                if saved_cat in ("jovem", "diario", "mulher"):
                    cat_segmented.selected = [saved_cat]
                saved_cleanup = await storage_get(self.page, "devotional_auto_cleanup_7d", default=True)
                cleanup_switch.value = bool(saved_cleanup)
                if self.bottom_sheet:
                    try:
                        self.bottom_sheet.update()
                    except Exception:
                        if self.page:
                            self.page.update()
                elif self.page:
                    self.page.update()
            except Exception:
                pass

        # Agenda carga assíncrona de preferências caso haja event loop em execução
        if self.page:
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(_load_devotional_settings())
            except RuntimeError:
                pass

        def _on_cat_change(e: ft.ControlEvent):
            if e.control.selected:
                selected_val = next(iter(e.control.selected))
                if self.page:
                    self.page.run_task(storage_set, self.page, "preferred_devotional_category", selected_val)

        def _on_cleanup_change(e: ft.ControlEvent):
            if self.page:
                self.page.run_task(storage_set, self.page, "devotional_auto_cleanup_7d", e.control.value)

        cat_segmented.on_change = _on_cat_change
        cleanup_switch.on_change = _on_cleanup_change

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.FAVORITE_ROUNDED, size=20, color=ft.Colors.PRIMARY),
                            ft.Text(
                                "Meditação Diária",
                                weight=ft.FontWeight.BOLD,
                                size=14,
                                color=ft.Colors.PRIMARY,
                            ),
                        ],
                        spacing=8,
                    ),
                    ft.Text(
                        "Devocional padrão em destaque:",
                        size=12,
                        weight=ft.FontWeight.W_500,
                        color=ft.Colors.ON_SURFACE,
                    ),
                    cat_segmented,
                    ft.Divider(height=1),
                    ft.Row(
                        controls=[
                            ft.Column(
                                controls=[
                                    ft.Text("Limpeza automática (> 7 dias)", size=12, weight=ft.FontWeight.BOLD),
                                    ft.Text("Remove automaticamente do cache offline meditações antigas", size=10, color=ft.Colors.ON_SURFACE_VARIANT),
                                ],
                                spacing=1,
                                expand=True,
                            ),
                            cleanup_switch,
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    ),
                ],
                spacing=8,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=10,
            padding=ft.Padding.all(12),
        )

    def _build_escola_sabatina_settings_card(self) -> ft.Container:
        """Card com configurações dedicadas à Escola Sabatina (Lição padrão: Adultos vs Jovens)."""
        ss_segmented = ft.SegmentedButton(
            segments=[
                ft.Segment(value="adultos", label=ft.Text("Adultos", size=11)),
                ft.Segment(value="jovens", label=ft.Text("Jovens", size=11)),
            ],
            selected=["adultos"],
            allow_multiple_selection=False,
        )

        async def _load_ss_settings():
            if not self.page:
                return
            try:
                saved_type = await storage_get(self.page, "preferred_ss_type", default="adultos")
                if saved_type in ("adultos", "jovens"):
                    ss_segmented.selected = [saved_type]
                if self.bottom_sheet:
                    try:
                        self.bottom_sheet.update()
                    except Exception:
                        if self.page:
                            self.page.update()
                elif self.page:
                    self.page.update()
            except Exception:
                pass

        if self.page:
            try:
                loop = asyncio.get_running_loop()
                loop.create_task(_load_ss_settings())
            except RuntimeError:
                pass

        def _on_ss_type_change(e: ft.ControlEvent):
            if e.control.selected:
                selected_val = next(iter(e.control.selected))
                if self.page:
                    self.page.run_task(storage_set, self.page, "preferred_ss_type", selected_val)

        ss_segmented.on_change = _on_ss_type_change

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.MENU_BOOK_ROUNDED, size=20, color=ft.Colors.PRIMARY),
                            ft.Text(
                                "Escola Sabatina",
                                weight=ft.FontWeight.BOLD,
                                size=14,
                                color=ft.Colors.PRIMARY,
                            ),
                        ],
                        spacing=8,
                    ),
                    ft.Text(
                        "Lição padrão em destaque:",
                        size=12,
                        weight=ft.FontWeight.W_500,
                        color=ft.Colors.ON_SURFACE,
                    ),
                    ss_segmented,
                ],
                spacing=8,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=10,
            padding=ft.Padding.all(12),
        )

    async def _open_url(self, url: str) -> None:
        try:
            await ft.UrlLauncher().launch_url(url)
        except Exception:
            pass

    async def _trigger_check_updates(self) -> None:
        if self.on_check_updates and callable(self.on_check_updates):
            if inspect.iscoroutinefunction(self.on_check_updates):
                await self.on_check_updates()
            else:
                self.on_check_updates()
        elif self.updater_service and self.page:
            from src.views.update_dialog import show_update_dialog

            try:
                update_info = await self.updater_service.check_for_updates()
                if update_info and (
                    update_info.get("update_available") or update_info.get("has_update")
                ):
                    # Fecha o diálogo de configurações para dar foco total ao diálogo de atualização
                    self._close_dialog()
                    show_update_dialog(self.page, update_info, self.updater_service)
                elif update_info and update_info.get("error"):
                    self._show_snack(f"Erro ao verificar atualizações: {update_info['error']}")
                else:
                    self._show_snack("Você já está na versão mais recente!")
            except Exception as ex:
                self._show_snack(f"Não foi possível verificar atualizações: {ex}")

    def _show_snack(self, message: str) -> None:
        if not self.page:
            return
        snack = ft.SnackBar(
            content=ft.Text(message, color=ft.Colors.WHITE, size=13),
            duration=3500,
            behavior=ft.SnackBarBehavior.FLOATING,
        )
        try:
            if hasattr(self.page, "overlay") and snack not in self.page.overlay:
                self.page.overlay.append(snack)
            snack.open = True
            if hasattr(self.page, "open"):
                self.page.open(snack)
            elif hasattr(self.page, "show_snack_bar"):
                self.page.show_snack_bar(snack)
            self.page.update()
        except Exception:
            pass

    def _trigger_show_welcome(self) -> None:
        """Fecha o modal de configurações e abre o modal de boas-vindas."""
        self._close_dialog()
        if self.page:
            from src.views.welcome_dialog import show_welcome_dialog

            show_welcome_dialog(
                page=self.page,
                theme_service=self.theme_service,
                auth_service=self.auth_service,
            )

    async def _on_google_login(self) -> None:
        """Inicia autenticação Google com atualização reativa da interface."""
        if not self.page:
            return

        self.is_logging_in = True
        if self.conta_container:
            self.conta_container.content = self._build_account_view()
            try:
                self.conta_container.update()
            except Exception:
                if self.page:
                    self.page.update()
        elif self.page:
            self.page.update()

        def _on_login_success() -> None:
            self.is_logging_in = False
            if self.conta_container:
                self.conta_container.content = self._build_account_view()
                try:
                    self.conta_container.update()
                except Exception:
                    if self.page:
                        self.page.update()
            elif self.page:
                self.page.update()

        try:
            success = await self.auth_service.initiate_google_login(
                self.page, on_success=_on_login_success
            )
            if not success:
                self.is_logging_in = False
                self._show_snack("Falha ao iniciar autenticação com o Google.")
                if self.conta_container:
                    self.conta_container.content = self._build_account_view()
                    try:
                        self.conta_container.update()
                    except Exception:
                        if self.page:
                            self.page.update()
                elif self.page:
                    self.page.update()
        except Exception as ex:
            self.is_logging_in = False
            self._show_snack(f"Erro ao conectar: {ex}")
            if self.conta_container:
                self.conta_container.content = self._build_account_view()
                try:
                    self.conta_container.update()
                except Exception:
                    if self.page:
                        self.page.update()
            elif self.page:
                self.page.update()

    async def _on_logout(self) -> None:
        """Encerra a sessão do usuário."""
        if not self.page:
            return
        await self.auth_service.logout(self.page)
        self._show_snack("Sessão desconectada com sucesso.")
        if self.conta_container:
            self.conta_container.content = self._build_account_view()
            try:
                self.conta_container.update()
            except Exception:
                if self.page:
                    self.page.update()
        elif self.page:
            self.page.update()

    def _build_account_view(self) -> ft.Column:
        """Gera a interface completa da aba 'Conta' com estado de login e botões."""
        user = self.auth_service.get_current_user()
        is_logged = user is not None

        if is_logged:
            email = getattr(user, "email", "Usuário Conectado")
            content_controls = [
                ft.Row(
                    controls=[
                        ft.CircleAvatar(
                            content=ft.Icon(ft.Icons.PERSON, color=ft.Colors.PRIMARY),
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                            radius=24,
                        ),
                        ft.Column(
                            controls=[
                                ft.Text("Conta Ativa", weight=ft.FontWeight.BOLD, size=15),
                                ft.Text(email, size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            spacing=2,
                        ),
                    ],
                    spacing=12,
                ),
                ft.Container(height=4),
                ft.Text(
                    "Sincronização de favoritos, histórico e dados habilitada na nuvem.",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Container(height=8),
                ft.OutlinedButton(
                    "Desconectar da Conta",
                    icon=ft.Icons.LOGOUT,
                    style=ft.ButtonStyle(
                        color=ft.Colors.RED_400,
                        shape=ft.RoundedRectangleBorder(radius=10),
                    ),
                    on_click=lambda _e: asyncio.create_task(self._on_logout()),
                ),
            ]
        else:
            login_btn = (
                ft.Row(
                    controls=[
                        ft.ProgressRing(width=20, height=20, stroke_width=2.5),
                        ft.Text("Iniciando login...", size=13),
                    ],
                    spacing=10,
                )
                if self.is_logging_in
                else ft.FilledButton(
                    "Entrar com o Google",
                    icon=ft.Icons.G_MOBILEDATA,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=10),
                    ),
                    on_click=lambda _e: asyncio.create_task(self._on_google_login()),
                )
            )

            content_controls = [
                ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Icon(ft.Icons.CLOUD_OFF_OUTLINED, color=ft.Colors.PRIMARY, size=26),
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                            border_radius=10,
                            padding=ft.Padding.all(8),
                        ),
                        ft.Column(
                            controls=[
                                ft.Text("Nenhuma Conta Conectada", weight=ft.FontWeight.BOLD, size=15),
                                ft.Text("Seus dados estão salvos apenas localmente", size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            spacing=2,
                        ),
                    ],
                    spacing=12,
                ),
                ft.Container(height=4),
                ft.Text(
                    "Faça login com sua Conta Google para sincronizar seus favoritos, histórico e preferências com o servidor.",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Container(height=8),
                login_btn,
                ft.Container(height=2),
                ft.OutlinedButton(
                    "Abrir Diálogo de Boas-vindas / Apresentação",
                    icon=ft.Icons.AUTO_AWESOME,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=10),
                    ),
                    on_click=lambda _e: self._trigger_show_welcome(),
                ),
            ]

        account_card = ft.Container(
            content=ft.Column(controls=content_controls, spacing=8),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=12,
            padding=ft.Padding.all(16),
        )

        return ft.Column(
            controls=[
                ft.Text(
                    "Gerenciamento de Conta & Nuvem",
                    size=13,
                    weight=ft.FontWeight.BOLD,
                    color=ft.Colors.PRIMARY,
                ),
                account_card,
            ],
            spacing=8,
        )


def show_settings_dialog(
    page: ft.Page,
    theme_service: ThemeService,
    updater_service: UpdaterService | None = None,
    auth_service: AuthService | None = None,
    edition: str | None = None,
    on_check_updates: Any | None = None,
    initial_tab: str = "sobre",
) -> None:
    """Abre o modal unificado de configurações e temas."""
    if not page:
        return
    ensure_page_dialogs(page)
    controller = SettingsDialogController(
        page=page,
        theme_service=theme_service,
        updater_service=updater_service,
        auth_service=auth_service,
        edition=edition,
        on_check_updates=on_check_updates,
        initial_tab=initial_tab,
    )
    bs = controller.build_bottom_sheet()
    try:
        page.show_dialog(bs)
    except Exception as ex:
        import logging

        logging.getLogger("flet").warning(
            "Primeira tentativa de show_dialog falhou (%s), reaplicando vínculos...", ex
        )
        try:
            ensure_page_dialogs(page)
            page.show_dialog(bs)
        except Exception:
            logging.getLogger("flet").exception("Erro ao exibir modal de configurações:")
