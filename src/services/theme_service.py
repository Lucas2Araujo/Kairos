"""
Serviço centralizado de gerenciamento de temas para o aplicativo Kairós.
Suporta temas dinâmicos baseados em Material 3 Color Scheme Seeds (Violeta, Dourado,
Verde Bíblico, Azul Safira), seleção de edições (Hinário Novo e Hinário Tradicional/Antigo),
Modo de Tema (Sistema, Claro, Escuro), Modo AMOLED (True Black #000000) e Tipografia Global
com persistência assíncrona na tabela 'preferencias' do SQLite.
"""

import inspect
import json
from typing import Any, Callable

import flet as ft

from src.database.connection import DatabaseConnection
from src.theme.palette import ThemeModeType, ThemePalette, ReadingMode
from src.theme.theme_engine import COLOR_SEEDS, ThemeEngine, get_directional_page_transitions
from src.utils.font_manager import DEFAULT_FONT_FAMILY, FontManager

PREF_THEME_KEY = "theme_prefs"

EDITION_NOVO = "novo"
EDITION_ANTIGO = "antigo"

# --- Catálogo de Color Seeds Material 3 ---
COLOR_SEEDS: dict[str, dict[str, str]] = {
    "purple": {"name": "Violeta M3", "hex": "#6750A4"},
    "gold": {"name": "Dourado Sacro", "hex": "#C67D00"},
    "emerald": {"name": "Verde Bíblico", "hex": "#006D5B"},
    "sapphire": {"name": "Azul Safira", "hex": "#006399"},
}

# --- Catálogo de Fontes Tipográficas Globais ---
FONT_FAMILIES: list[str] = [
    "Montserrat",
    "Roboto",
    "Inter",
    "Merriweather",
    "OpenDyslexic",
]

# --- Paleta True Black para Telas AMOLED (Geral / Hinário Novo) ---
AMOLED_BG_COLOR = "#000000"
AMOLED_SURFACE_COLOR = "#0D0D0D"
AMOLED_SURFACE_CONTAINER = "#141414"
AMOLED_SURFACE_CONTAINER_HIGH = "#1A1A1A"
AMOLED_SURFACE_CONTAINER_HIGHEST = "#222222"
AMOLED_DIVIDER_COLOR = "#2D2D2D"

# --- Paletas Edição Antiga (1996) ---
ANTIGO_LIGHT_PRIMARY = "#5B3A29"
ANTIGO_LIGHT_BG = "#FDFBF7"
ANTIGO_LIGHT_SURFACE = "#F5EFEB"
ANTIGO_LIGHT_CONTAINER = "#EADFD8"
ANTIGO_LIGHT_CONTAINER_HIGH = "#DFD1C7"
ANTIGO_LIGHT_CONTAINER_HIGHEST = "#D4C2B5"
ANTIGO_LIGHT_ON_SURFACE = "#2C1B14"
ANTIGO_LIGHT_ON_SURFACE_VARIANT = "#5C463A"
ANTIGO_LIGHT_OUTLINE = "#D8C7BC"

ANTIGO_DARK_PRIMARY = "#E6A15C"
ANTIGO_DARK_BG = "#1A130F"
ANTIGO_DARK_SURFACE = "#251D18"
ANTIGO_DARK_CONTAINER = "#332822"
ANTIGO_DARK_CONTAINER_HIGH = "#41342C"
ANTIGO_DARK_CONTAINER_HIGHEST = "#504037"
ANTIGO_DARK_ON_SURFACE = "#F5EFEB"
ANTIGO_DARK_ON_SURFACE_VARIANT = "#D4C2B5"
ANTIGO_DARK_OUTLINE = "#4A392F"

ANTIGO_AMOLED_BG = "#000000"
ANTIGO_AMOLED_SURFACE = "#0C0907"
ANTIGO_AMOLED_CONTAINER = "#15110E"
ANTIGO_AMOLED_CONTAINER_HIGH = "#1E1814"
ANTIGO_AMOLED_CONTAINER_HIGHEST = "#2A221C"
ANTIGO_AMOLED_PRIMARY = "#E6A15C"
ANTIGO_AMOLED_OUTLINE = "#2C1742"


class ThemeService:
    """
    Controlador de tema do aplicativo.
    Gerencia a ativação do modo AMOLED, seleção de sementes Material 3,
    modo de tema (Sistema, Claro, Escuro) e tipografia global.
    """

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self.theme_engine = ThemeEngine(db_connection)
        self.theme_style: ThemeModeType = ThemeModeType.MATERIAL_YOU
        self.is_amoled: bool = False
        self.current_edition: str = EDITION_NOVO
        self.current_seed: str = "purple"
        self.theme_mode: str = "system"
        self.font_family: str = "Roboto"
        self._loaded: bool = False
        self._listeners: list[Callable[[], Any]] = []

    def add_listener(self, listener: Callable[[], Any]) -> None:
        """Registra um callback para ser notificado em mudanças de tema."""
        if listener not in self._listeners:
            self._listeners.append(listener)

    def remove_listener(self, listener: Callable[[], Any]) -> None:
        """Remove um callback de notificação de tema."""
        if listener in self._listeners:
            self._listeners.remove(listener)

    async def _notify_listeners(self) -> None:
        """Notifica todos os observadores cadastrados sobre a alteração de tema."""
        for listener in self._listeners.copy():
            try:
                res = listener()
                if inspect.iscoroutine(res):
                    await res
            except Exception:
                pass

    def _sync_to_engine(self) -> None:
        self.theme_engine.theme_style = self.theme_style
        self.theme_engine.theme_mode = self.theme_mode
        self.theme_engine.is_amoled = self.is_amoled
        self.theme_engine.current_seed = self.current_seed
        self.theme_engine.font_family = self.font_family
        self.theme_engine.current_edition = self.current_edition
        if self.theme_mode == "light":
            self.theme_engine.is_dark = False
        elif self.theme_mode == "dark":
            self.theme_engine.is_dark = True
        else:  # "system"
            if self.is_amoled:
                self.theme_engine.is_dark = True
            # Preserva self.theme_engine.is_dark resolvido por _resolve_is_dark(page)

    def get_current_palette(self) -> ThemePalette:
        """Retorna a paleta de cores correspondente ao tema ativo."""
        self._sync_to_engine()
        return self.theme_engine.get_current_palette()

    async def load_preferences(self, page: ft.Page | None = None) -> bool:
        """
        Carrega as preferências de tema do client_storage (rápido) e do banco SQLite.
        Garante sincronização imediata sem sobrescrever com valores padrão.
        """
        if self._loaded and not page:
            return self.is_amoled

        # 1. Se page for fornecida, carrega imediatamente do client_storage
        if page:
            try:
                await self.theme_engine.load_preferences(page)
                self.theme_style = self.theme_engine.theme_style
                self.theme_mode = self.theme_engine.theme_mode
                self.is_amoled = self.theme_engine.is_amoled
                self.current_seed = self.theme_engine.current_seed
                self.font_family = self.theme_engine.font_family
                self.current_edition = self.theme_engine.current_edition
            except Exception:
                pass

        # 2. Tenta carregar/completar do banco de dados SQLite
        try:
            conn = await self.db_connection.get_connection()
            async with conn.execute(
                "SELECT valor FROM preferencias WHERE chave = ?", (PREF_THEME_KEY,)
            ) as cursor:
                row = await cursor.fetchone()
            if row and row[0]:
                data = json.loads(row[0])
                style_str = data.get("theme_style")
                if style_str:
                    try:
                        self.theme_style = ThemeModeType(style_str)
                    except ValueError:
                        pass
                self.is_amoled = bool(data.get("is_amoled", self.is_amoled))
                self.current_edition = str(data.get("edition", self.current_edition))
                seed = str(data.get("seed", self.current_seed))
                self.current_seed = seed if seed in COLOR_SEEDS else self.current_seed
                mode = str(data.get("theme_mode", self.theme_mode)).lower()
                self.theme_mode = (
                    mode if mode in ("system", "light", "dark") else self.theme_mode
                )
                font = str(data.get("font_family", self.font_family))
                self.font_family = font if font in FONT_FAMILIES else self.font_family
        except Exception:
            pass

        self._sync_to_engine()
        self._loaded = True
        return self.is_amoled

    async def save_preferences(
        self,
        is_amoled: bool | None = None,
        edition: str | None = None,
        seed: str | None = None,
        theme_mode: str | None = None,
        font_family: str | None = None,
        theme_style: ThemeModeType | str | None = None,
    ) -> None:
        """Salva as preferências de tema no banco de dados SQLite."""
        if is_amoled is not None:
            self.is_amoled = is_amoled
        if edition is not None:
            self.current_edition = edition
        if seed is not None and seed in COLOR_SEEDS:
            self.current_seed = seed
        if theme_mode is not None and theme_mode.lower() in ("system", "light", "dark"):
            self.theme_mode = theme_mode.lower()
        if font_family is not None and font_family in FONT_FAMILIES:
            self.font_family = font_family
        if theme_style is not None:
            if isinstance(theme_style, str):
                try:
                    self.theme_style = ThemeModeType(theme_style.lower())
                except ValueError:
                    pass
            else:
                self.theme_style = theme_style

        self._sync_to_engine()

        try:
            conn = await self.db_connection.get_connection()
            prefs_json = json.dumps(
                {
                    "theme_style": self.theme_style.value,
                    "is_amoled": self.is_amoled,
                    "edition": self.current_edition,
                    "seed": self.current_seed,
                    "theme_mode": self.theme_mode,
                    "font_family": self.font_family,
                }
            )
            await conn.execute(
                "INSERT OR REPLACE INTO preferencias (chave, valor) VALUES (?, ?)",
                (PREF_THEME_KEY, prefs_json),
            )
            await conn.commit()
        except Exception:
            try:
                conn = await self.db_connection.get_connection()
                await conn.rollback()
            except Exception:
                pass

    async def set_theme_style(
        self, style: ThemeModeType | str, page: ft.Page | None = None
    ) -> None:
        """Define o estilo de tema (Material You, Liquid Glass, Classic Book) e atualiza."""
        if isinstance(style, str):
            try:
                resolved_style = ThemeModeType(style.lower())
            except ValueError:
                return
        else:
            resolved_style = style

        self.theme_style = resolved_style
        # Classic Book é um sub-tema de leitura do modo claro
        if self.theme_style == ThemeModeType.CLASSIC_BOOK and self.theme_mode == "dark":
            self.theme_mode = "light"

        await self.save_preferences(
            theme_style=self.theme_style,
            theme_mode=self.theme_mode,
        )
        if page:
            self.apply_theme(page)
            page.update()
        await self._notify_listeners()

    async def set_seed(self, seed_key: str, page: ft.Page | None = None) -> None:
        """Define a cor seed M3 ativa, persiste e atualiza o tema."""
        if seed_key in COLOR_SEEDS:
            self.current_seed = seed_key
            await self.save_preferences(seed=seed_key)
            if page:
                self.apply_theme(page)
                page.update()
            await self._notify_listeners()

    async def set_theme_mode(self, mode: str, page: ft.Page | None = None) -> None:
        """Define o modo de tema ('system', 'light', 'dark'), persiste e atualiza o tema."""
        mode_normalized = mode.lower()
        if mode_normalized in ("system", "light", "dark"):
            self.theme_mode = mode_normalized
            # Se o usuário escolher 'dark', o modo escuro tem precedência absoluta sobre Sépia (Classic Book)
            if mode_normalized == "dark" and self.theme_style == ThemeModeType.CLASSIC_BOOK:
                self.theme_style = ThemeModeType.MATERIAL_YOU

            if page:
                self.theme_engine._resolve_is_dark(page)
            self._sync_to_engine()
            await self.save_preferences(
                theme_mode=mode_normalized,
                theme_style=self.theme_style,
            )
            if page:
                self.apply_theme(page)
                page.update()
            await self._notify_listeners()

    async def set_font_family(
        self, font_family: str, page: ft.Page | None = None
    ) -> None:
        """Define a família tipográfica global, persiste e atualiza o tema."""
        if font_family in FONT_FAMILIES:
            self.font_family = font_family
            await self.save_preferences(font_family=font_family)
            if page:
                self.apply_theme(page)
                page.update()
            await self._notify_listeners()

    async def toggle_amoled(
        self, page: ft.Page, enabled: bool, edition: str | None = None
    ) -> None:
        """Alterna o modo AMOLED, persiste no banco e atualiza a interface."""
        self.is_amoled = enabled
        if edition:
            self.current_edition = edition
        await self.save_preferences(is_amoled=enabled, edition=edition)
        self.apply_theme(page, edition=edition)
        page.update()
        await self._notify_listeners()

    async def set_glass_blur_enabled(
        self, enabled: bool, page: ft.Page | None = None
    ) -> None:
        """Ativa ou desativa o desfoque de fundo (Backdrop Blur) do Liquid Glass."""
        await self.theme_engine.set_glass_blur_enabled(enabled, page)
        await self._notify_listeners()

    def get_current_reading_mode(self) -> str:
        """
        Retorna o modo de leitura atual:
        'escuro', 'sepia' (Classic Book no tema claro) ou 'claro'.
        O modo escuro tem precedência absoluta sobre o sépia para evitar texto escuro sobre fundo escuro.
        """
        if self.theme_mode == "dark" or (self.theme_mode == "system" and self.theme_engine.is_dark):
            return "escuro"
        if self.theme_style == ThemeModeType.CLASSIC_BOOK:
            return "sepia"
        return "claro"

    async def set_reading_mode(
        self, mode: str, page: ft.Page | None = None
    ) -> None:
        """
        Configura rapidamente um dos três modos ergonômicos de leitura:
        - 'claro': Material You claro
        - 'escuro': Material You escuro
        - 'sepia': Classic Book sépia confortável
        """
        mode_norm = mode.lower().strip()
        if mode_norm == "sepia":
            self.theme_style = ThemeModeType.CLASSIC_BOOK
            self.theme_mode = "light"
            self.is_amoled = False
        elif mode_norm == "escuro":
            self.theme_style = ThemeModeType.MATERIAL_YOU
            self.theme_mode = "dark"
        else:  # "claro"
            self.theme_style = ThemeModeType.MATERIAL_YOU
            self.theme_mode = "light"
            self.is_amoled = False

        self._sync_to_engine()
        await self.save_preferences(
            theme_style=self.theme_style,
            theme_mode=self.theme_mode,
            is_amoled=self.is_amoled,
        )
        if page:
            self.apply_theme(page)
            page.update()
        await self._notify_listeners()

    def get_accent_color(self, edition: str = EDITION_NOVO) -> str:
        """Retorna a cor de destaque principal de acordo com a edição e a seed M3 ativa."""
        if edition == EDITION_ANTIGO:
            return ANTIGO_DARK_PRIMARY
        return COLOR_SEEDS.get(self.current_seed, COLOR_SEEDS["purple"])["hex"]

    def _resolve_theme_mode_and_bg(self, page: ft.Page) -> None:
        """Configura o theme_mode e bgcolor básico da página."""
        if self.theme_mode == "light":
            page.theme_mode = ft.ThemeMode.LIGHT
            page.bgcolor = None
        elif self.theme_mode == "dark":
            page.theme_mode = ft.ThemeMode.DARK
            page.bgcolor = AMOLED_BG_COLOR if self.is_amoled else None
        else:  # "system"
            if self.is_amoled:
                page.theme_mode = ft.ThemeMode.DARK
                page.bgcolor = AMOLED_BG_COLOR
            else:
                page.theme_mode = ft.ThemeMode.SYSTEM
                page.bgcolor = None

    def _apply_antigo_theme(
        self, page: ft.Page, seed_hex: str, transitions: ft.PageTransitionsTheme
    ) -> None:
        """Aplica estilos específicos do Hinário Antigo."""
        if self.is_amoled and page.theme_mode == ft.ThemeMode.DARK:
            page.bgcolor = ANTIGO_AMOLED_BG
            amoled_scheme = ft.ColorScheme(
                surface=ANTIGO_AMOLED_BG,
                surface_dim=ANTIGO_AMOLED_BG,
                surface_bright=ANTIGO_AMOLED_CONTAINER_HIGHEST,
                surface_container_lowest=ANTIGO_AMOLED_BG,
                surface_container_low=ANTIGO_AMOLED_SURFACE,
                surface_container=ANTIGO_AMOLED_CONTAINER,
                surface_container_high=ANTIGO_AMOLED_CONTAINER_HIGH,
                surface_container_highest=ANTIGO_AMOLED_CONTAINER_HIGHEST,
                on_surface=ft.Colors.WHITE,
                on_surface_variant=ANTIGO_DARK_ON_SURFACE_VARIANT,
                primary=ANTIGO_AMOLED_PRIMARY,
                on_primary=ft.Colors.BLACK,
                outline=ANTIGO_AMOLED_OUTLINE,
            )
            page.dark_theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
                color_scheme=amoled_scheme,
                system_overlay_style=ft.SystemOverlayStyle(
                    status_bar_color=ANTIGO_AMOLED_BG,
                    system_navigation_bar_color=ANTIGO_AMOLED_BG,
                ),
            )
            page.theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
            )
            return

        antigo_light_scheme = ft.ColorScheme(
            surface=ANTIGO_LIGHT_BG,
            surface_dim=ANTIGO_LIGHT_SURFACE,
            surface_bright=ANTIGO_LIGHT_CONTAINER,
            surface_container_lowest=ANTIGO_LIGHT_BG,
            surface_container_low=ANTIGO_LIGHT_SURFACE,
            surface_container=ANTIGO_LIGHT_CONTAINER,
            surface_container_high=ANTIGO_LIGHT_CONTAINER_HIGH,
            surface_container_highest=ANTIGO_LIGHT_CONTAINER_HIGHEST,
            on_surface=ANTIGO_LIGHT_ON_SURFACE,
            on_surface_variant=ANTIGO_LIGHT_ON_SURFACE_VARIANT,
            primary=ANTIGO_LIGHT_PRIMARY,
            on_primary=ft.Colors.WHITE,
            outline=ANTIGO_LIGHT_OUTLINE,
        )

        antigo_dark_scheme = ft.ColorScheme(
            surface=ANTIGO_DARK_BG,
            surface_dim=ANTIGO_DARK_SURFACE,
            surface_bright=ANTIGO_DARK_CONTAINER_HIGHEST,
            surface_container_lowest=ANTIGO_DARK_BG,
            surface_container_low=ANTIGO_DARK_SURFACE,
            surface_container=ANTIGO_DARK_CONTAINER,
            surface_container_high=ANTIGO_DARK_CONTAINER_HIGH,
            surface_container_highest=ANTIGO_DARK_CONTAINER_HIGHEST,
            on_surface=ANTIGO_DARK_ON_SURFACE,
            on_surface_variant=ANTIGO_DARK_ON_SURFACE_VARIANT,
            primary=ANTIGO_DARK_PRIMARY,
            on_primary=ft.Colors.BLACK,
            outline=ANTIGO_DARK_OUTLINE,
        )

        page.theme = ft.Theme(
            color_scheme_seed=seed_hex,
            use_material3=True,
            font_family=self.font_family,
            page_transitions=transitions,
            color_scheme=antigo_light_scheme,
        )
        page.dark_theme = ft.Theme(
            color_scheme_seed=seed_hex,
            use_material3=True,
            font_family=self.font_family,
            page_transitions=transitions,
            color_scheme=antigo_dark_scheme,
            system_overlay_style=ft.SystemOverlayStyle(
                status_bar_color=ANTIGO_DARK_BG,
                system_navigation_bar_color=ANTIGO_DARK_BG,
            ),
        )

    def _apply_novo_theme(
        self, page: ft.Page, seed_hex: str, transitions: ft.PageTransitionsTheme
    ) -> None:
        """Aplica estilos da Edição Hinário Novo (Seed M3 Unificada)."""
        if self.is_amoled and page.theme_mode == ft.ThemeMode.DARK:
            page.bgcolor = AMOLED_BG_COLOR
            amoled_color_scheme = ft.ColorScheme(
                surface=AMOLED_BG_COLOR,
                surface_dim=AMOLED_BG_COLOR,
                surface_bright=AMOLED_SURFACE_CONTAINER_HIGHEST,
                surface_container_lowest=AMOLED_BG_COLOR,
                surface_container_low=AMOLED_SURFACE_COLOR,
                surface_container=AMOLED_SURFACE_CONTAINER,
                surface_container_high=AMOLED_SURFACE_CONTAINER_HIGH,
                surface_container_highest=AMOLED_SURFACE_CONTAINER_HIGHEST,
                on_surface=ft.Colors.WHITE,
                on_surface_variant=ft.Colors.GREY_400,
                primary=seed_hex,
                on_primary=ft.Colors.BLACK,
                outline=AMOLED_DIVIDER_COLOR,
            )

            page.dark_theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
                color_scheme=amoled_color_scheme,
                system_overlay_style=ft.SystemOverlayStyle(
                    status_bar_color=AMOLED_BG_COLOR,
                    system_navigation_bar_color=AMOLED_BG_COLOR,
                ),
            )
            page.theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
            )
        else:
            page.theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
            )
            page.dark_theme = ft.Theme(
                color_scheme_seed=seed_hex,
                use_material3=True,
                font_family=self.font_family,
                page_transitions=transitions,
            )

    def apply_theme(self, page: ft.Page, edition: str | None = None) -> None:
        """
        Aplica o tema configurado à página do Flet.
        Configura fontes globais, seed M3, tema claro/escuro e suporte a AMOLED.
        """
        if not page:
            return

        self.theme_engine._resolve_is_dark(page)
        self._sync_to_engine()
        active_edition = edition or self.current_edition

        if active_edition == EDITION_ANTIGO and self.theme_style == ThemeModeType.MATERIAL_YOU:
            seed_hex = COLOR_SEEDS.get(self.current_seed, COLOR_SEEDS["purple"])["hex"]
            transitions = get_directional_page_transitions()
            FontManager.register_fonts(page)
            self._resolve_theme_mode_and_bg(page)
            self._apply_antigo_theme(page, seed_hex, transitions)
        else:
            self.theme_engine.apply_theme(page, edition=active_edition)
            # Para manter compatibilidade com contratos onde a página base é gerenciada
            # pelo Flet (bgcolor None quando não AMOLED), resolvemos o bgcolor na página:
            if not self.is_amoled:
                page.bgcolor = None
                if self.theme_mode == "system":
                    page.theme_mode = ft.ThemeMode.SYSTEM



