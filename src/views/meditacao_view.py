"""
View Principal de Meditação Diária (Devocional) - Hinário Inteligente.
Recursos:
1. Disparo em segundo plano de run_auto_cleanup() no carregamento.
2. Seletor visual de categoria (Jovem, Diário, Mulher) com persistência em storage.
3. Carrossel horizontal de chips para seleção dos últimos 7 dias com indicador de status de cache.
4. Card clicável do versículo-chave disparando o modal do versículo (show_verse_dialog).
5. Renderização fluida do texto com suporte a redimensionamento dinâmico de fonte (A+ / A- / Reset).
6. Botão na AppBar para acessar a tela de Gerenciamento de Armazenamento/Cache (/meditacoes/cache).
7. Tratamento visual de loading (ft.ProgressRing) e estado offline sem cache.
"""

from __future__ import annotations

import asyncio
from datetime import date, datetime, timedelta
from typing import Any

import flet as ft

from src.components.verse_dialog import show_verse_dialog
from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService
from src.services.theme_service import ThemeService
from src.utils.storage_manager import storage_get, storage_set

FONT_STEP = 2
MIN_FONT_SIZE = 14
MAX_FONT_SIZE = 28
DEFAULT_CONTENT_FONT_SIZE = 16

STORAGE_KEY_FONT_SIZE = "devotional_font_size"
STORAGE_KEY_CATEGORY = "preferred_devotional_category"

VALID_CATEGORIES = ("jovem", "diario", "mulher")


class MeditacaoView:
    """
    Controlador e construtor da tela principal de Meditação Diária.
    """

    def __init__(
        self,
        devotional_service: DevotionalService,
        theme_service: ThemeService | None = None,
        category: str = "jovem",
    ):
        self.devotional_service = devotional_service
        self.theme_service = theme_service
        self.category = category.lower() if category.lower() in VALID_CATEGORIES else "jovem"
        self.selected_date: date = date.today()
        self.current_devotional: Devotional | None = None
        self.is_loading: bool = False
        self.font_size: int = DEFAULT_CONTENT_FONT_SIZE
        self.page: ft.Page | None = None
        self.cached_dates: set[str] = set()

        # Controles reativos
        self.category_selector: ft.SegmentedButton | None = None
        self.content_container: ft.Column | None = None
        self.date_chips_row: ft.Row | None = None
        self.font_indicator: ft.Text | None = None

    async def _load_preferences(self) -> None:
        """Carrega preferências salvas no storage (fonte e categoria)."""
        if not self.page:
            return

        # 1. Tamanho da fonte
        try:
            val_font = await storage_get(self.page, STORAGE_KEY_FONT_SIZE)
            if val_font is not None:
                self.font_size = max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, int(val_font)))
        except Exception:
            self.font_size = DEFAULT_CONTENT_FONT_SIZE

        # 2. Categoria preferida
        try:
            val_cat = await storage_get(self.page, STORAGE_KEY_CATEGORY)
            if val_cat and str(val_cat).lower() in VALID_CATEGORIES:
                self.category = str(val_cat).lower()
        except Exception:
            pass

    async def _save_font_size_preference(self) -> None:
        """Salva a preferência de tamanho de fonte."""
        if not self.page:
            return
        try:
            await storage_set(self.page, STORAGE_KEY_FONT_SIZE, self.font_size)
        except Exception:
            pass

    async def _save_category_preference(self) -> None:
        """Salva a preferência da categoria de meditação."""
        if not self.page:
            return
        try:
            await storage_set(self.page, STORAGE_KEY_CATEGORY, self.category)
        except Exception:
            pass

    def _change_font_size(self, delta: int) -> None:
        """Aumenta ou diminui dinamicamente o tamanho da fonte (A+ / A-)."""
        new_size = self.font_size + delta
        if MIN_FONT_SIZE <= new_size <= MAX_FONT_SIZE:
            self.font_size = new_size
            if self.page:
                self.page.run_task(self._save_font_size_preference)
            self._update_rendered_content()

    def _reset_font_size(self) -> None:
        """Restaura o tamanho padrão da fonte."""
        self.font_size = DEFAULT_CONTENT_FONT_SIZE
        if self.page:
            self.page.run_task(self._save_font_size_preference)
        self._update_rendered_content()

    def _format_day_chip_label(self, d: date) -> tuple[str, str]:
        """Retorna (rótulo curto, data legível) para o chip."""
        today = date.today()
        if d == today:
            dia_str = "Hoje"
        elif d == today - timedelta(days=1):
            dia_str = "Ontem"
        else:
            dias_semana = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
            dia_str = dias_semana[d.weekday()]

        meses_abrev = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        sub_str = f"{d.day}/{meses_abrev[d.month - 1]}"
        return dia_str, sub_str

    def _build_category_selector(self) -> ft.Container:
        """Constrói o seletor visual segmentado de categoria (Jovem, Diário, Mulher)."""
        self.category_selector = ft.SegmentedButton(
            segments=[
                ft.Segment(
                    value="jovem",
                    label=ft.Text("Jovem", weight=ft.FontWeight.W_600),
                    icon=ft.Icon(ft.Icons.AUTO_AWESOME_ROUNDED, size=16),
                ),
                ft.Segment(
                    value="diario",
                    label=ft.Text("Diário", weight=ft.FontWeight.W_600),
                    icon=ft.Icon(ft.Icons.CALENDAR_TODAY_ROUNDED, size=16),
                ),
                ft.Segment(
                    value="mulher",
                    label=ft.Text("Mulher", weight=ft.FontWeight.W_600),
                    icon=ft.Icon(ft.Icons.SPA_ROUNDED, size=16),
                ),
            ],
            selected=[self.category],
            allow_multiple_selection=False,
            on_change=lambda e: self.page.run_task(self._on_change_category, e) if self.page else None,
        )

        return ft.Container(
            content=ft.Row(
                controls=[self.category_selector],
                alignment=ft.MainAxisAlignment.CENTER,
            ),
            padding=ft.Padding.symmetric(horizontal=16, vertical=6),
        )

    async def _on_change_category(self, e: ft.ControlEvent) -> None:
        """Manipula alteração de categoria: persiste escolha, atualiza cache status e recarrega."""
        if not e.control.selected:
            return
        selected_cat = list(e.control.selected)[0].lower()
        if selected_cat not in VALID_CATEGORIES or selected_cat == self.category:
            return

        self.category = selected_cat
        await self._save_category_preference()

        # Exibe loading imediato no container de leitura
        self.is_loading = True
        self._update_rendered_content()

        # Recarrega a meditação e o status de cache para a nova categoria
        await self._load_devotional_for_selected_date()

    def _build_date_carousel(self) -> ft.Container:
        """Constrói o carrossel horizontal com os últimos 7 dias."""
        today = date.today()
        chips: list[ft.Control] = []

        for i in range(7):
            day_target = today - timedelta(days=i)
            is_selected = day_target == self.selected_date
            is_cached = day_target.isoformat() in self.cached_dates
            dia_label, sub_label = self._format_day_chip_label(day_target)

            chip = ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Text(
                                    dia_label,
                                    size=12,
                                    weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.W_500,
                                    color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                                ),
                                ft.Icon(
                                    ft.Icons.CHECK_CIRCLE_ROUNDED if is_cached else ft.Icons.RADIO_BUTTON_UNCHECKED_ROUNDED,
                                    size=11,
                                    color=ft.Colors.GREEN_600 if is_cached else ft.Colors.OUTLINE_VARIANT,
                                    tooltip="Salva offline" if is_cached else "Não baixada",
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.CENTER,
                            spacing=3,
                        ),
                        ft.Text(
                            sub_label,
                            size=10,
                            color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE_VARIANT,
                        ),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=1,
                ),
                bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGHEST,
                border_radius=12,
                padding=ft.Padding.symmetric(horizontal=12, vertical=6),
                border=ft.Border.all(
                    1.5,
                    ft.Colors.PRIMARY if is_selected else ft.Colors.TRANSPARENT,
                ),
                ink=True,
                on_click=lambda e, dt=day_target: self._on_select_date(dt),
            )
            chips.append(chip)

        self.date_chips_row = ft.Row(
            controls=chips,
            scroll=ft.ScrollMode.AUTO,
            spacing=8,
        )

        return ft.Container(
            content=self.date_chips_row,
            padding=ft.Padding.symmetric(horizontal=12, vertical=6),
        )

    def _on_select_date(self, target_date: date) -> None:
        """Manipula seleção de um dia no carrossel."""
        if self.selected_date == target_date and self.current_devotional:
            return
        self.selected_date = target_date
        if self.page:
            self.page.run_task(self._load_devotional_for_selected_date)

    async def _update_cached_status(self) -> None:
        """Consulta as meditações recentes salvas localmente para a categoria atual."""
        try:
            recent_cached = await self.devotional_service.get_recent_devotionals(
                limit=14, category=self.category
            )
            self.cached_dates = {d.published_at for d in recent_cached}
        except Exception:
            self.cached_dates = set()

    async def _load_devotional_for_selected_date(self, force_refresh: bool = False) -> None:
        """Carrega a meditação (offline-first: Cache -> Nuvem -> Salva no Cache)."""
        self.is_loading = True
        self._update_rendered_content()

        target_str = self.selected_date.isoformat()
        try:
            self.current_devotional = await self.devotional_service.get_devotional(
                target_date=target_str,
                category=self.category,
                force_refresh=force_refresh,
            )
        except Exception:
            self.current_devotional = None

        await self._update_cached_status()
        self.is_loading = False
        self._update_rendered_content()

    def _show_verse_modal(self, e=None) -> None:
        """Abre o diálogo de versículo com parser e atalho para a Bíblia."""
        if not self.page or not self.current_devotional:
            return
        show_verse_dialog(
            page=self.page,
            verse_text=self.current_devotional.verse_text,
            verse_reference=self.current_devotional.verse_reference,
        )

    def _update_rendered_content(self) -> None:
        """Re-renderiza a área de conteúdo da meditação e atualiza chips."""
        if not self.content_container or not self.page:
            return

        # Sincroniza estado visual do seletor de categoria
        if self.category_selector and self.category_selector.selected != [self.category]:
            self.category_selector.selected = [self.category]

        # Atualiza chips do carrossel
        today = date.today()
        if self.date_chips_row:
            new_chips = []
            for i in range(7):
                day_target = today - timedelta(days=i)
                is_selected = day_target == self.selected_date
                is_cached = day_target.isoformat() in self.cached_dates
                dia_label, sub_label = self._format_day_chip_label(day_target)
                new_chips.append(
                    ft.Container(
                        content=ft.Column(
                            controls=[
                                ft.Row(
                                    controls=[
                                        ft.Text(
                                            dia_label,
                                            size=12,
                                            weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.W_500,
                                            color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                                        ),
                                        ft.Icon(
                                            ft.Icons.CHECK_CIRCLE_ROUNDED if is_cached else ft.Icons.RADIO_BUTTON_UNCHECKED_ROUNDED,
                                            size=11,
                                            color=ft.Colors.GREEN_600 if is_cached else ft.Colors.OUTLINE_VARIANT,
                                            tooltip="Salva offline" if is_cached else "Não baixada",
                                        ),
                                    ],
                                    alignment=ft.MainAxisAlignment.CENTER,
                                    spacing=3,
                                ),
                                ft.Text(
                                    sub_label,
                                    size=10,
                                    color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE_VARIANT,
                                ),
                            ],
                            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=1,
                        ),
                        bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGHEST,
                        border_radius=12,
                        padding=ft.Padding.symmetric(horizontal=12, vertical=6),
                        border=ft.Border.all(
                            1.5,
                            ft.Colors.PRIMARY if is_selected else ft.Colors.TRANSPARENT,
                        ),
                        ink=True,
                        on_click=lambda e, dt=day_target: self._on_select_date(dt),
                    )
                )
            self.date_chips_row.controls = new_chips

        if self.is_loading:
            self.content_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.ProgressRing(),
                            ft.Text(f"Carregando meditação ({self.category.capitalize()})...", size=14, italic=True),
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

        if not self.current_devotional:
            # Estado vazio / offline sem cache
            self.content_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Icon(ft.Icons.WIFI_OFF_ROUNDED, size=54, color=ft.Colors.OUTLINE),
                            ft.Text(
                                f"Meditação ({self.category.capitalize()}) indisponível",
                                size=16,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.ON_SURFACE,
                            ),
                            ft.Text(
                                "Você está sem conexão e esta meditação ainda não foi salva em cache.",
                                size=13,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                text_align=ft.TextAlign.CENTER,
                            ),
                            ft.Container(height=8),
                            ft.FilledButton(
                                "Tentar Novamente",
                                icon=ft.Icons.REFRESH,
                                on_click=lambda e: self.page.run_task(
                                    self._load_devotional_for_selected_date, True
                                ),
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=10,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(32),
                )
            ]
            self.page.update()
            return

        # Renderiza a meditação encontrada
        dev = self.current_devotional

        # Card do Versículo-Chave (Clicável)
        verse_card = ft.Card(
            elevation=1,
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.FORMAT_QUOTE, size=20, color=ft.Colors.PRIMARY),
                                ft.Text(
                                    dev.verse_reference,
                                    weight=ft.FontWeight.BOLD,
                                    size=14,
                                    color=ft.Colors.PRIMARY,
                                    expand=True,
                                ),
                                ft.Icon(ft.Icons.OPEN_IN_NEW, size=16, color=ft.Colors.PRIMARY),
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        ),
                        ft.Text(
                            f'"{dev.verse_text.strip()}"',
                            size=self.font_size,
                            italic=True,
                        ),
                    ],
                    spacing=6,
                ),
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                border_radius=12,
                padding=ft.Padding.all(14),
                ink=True,
                on_click=self._show_verse_modal,
                tooltip="Toque para ler o versículo e abrir o capítulo completo na Bíblia",
            ),
        )

        # Barra de Controles de Acessibilidade da Fonte
        font_bar = ft.Row(
            controls=[
                ft.Text(
                    f"Fonte: {self.font_size}pt",
                    size=12,
                    weight=ft.FontWeight.W_500,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Row(
                    controls=[
                        ft.IconButton(
                            icon=ft.Icons.TEXT_DECREASE,
                            tooltip="Diminuir fonte (A-)",
                            icon_size=18,
                            on_click=lambda e: self._change_font_size(-FONT_STEP),
                        ),
                        ft.IconButton(
                            icon=ft.Icons.REFRESH,
                            tooltip="Restaurar tamanho padrão",
                            icon_size=16,
                            on_click=lambda e: self._reset_font_size(),
                        ),
                        ft.IconButton(
                            icon=ft.Icons.TEXT_INCREASE,
                            tooltip="Aumentar fonte (A+)",
                            icon_size=18,
                            on_click=lambda e: self._change_font_size(FONT_STEP),
                        ),
                    ],
                    spacing=0,
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )

        # Corpo do texto com parágrafos separados
        paragraphs = [p.strip() for p in dev.content.split("\n\n") if p.strip()]
        text_controls: list[ft.Control] = [
            ft.Text(
                p,
                size=self.font_size,
                selectable=True,
            )
            for p in paragraphs
        ]

        # Rodapé de Autoria se disponível
        if dev.author:
            text_controls.append(
                ft.Container(
                    content=ft.Text(
                        f"— {dev.author}",
                        size=self.font_size - 1,
                        weight=ft.FontWeight.BOLD,
                        italic=True,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                    alignment=ft.Alignment.CENTER_RIGHT,
                    padding=ft.Padding.only(top=10, bottom=6),
                )
            )

        self.content_container.controls = [
            ft.Text(
                dev.title,
                size=22,
                weight=ft.FontWeight.BOLD,
                color=ft.Colors.ON_SURFACE,
            ),
            ft.Container(height=2),
            verse_card,
            ft.Container(height=4),
            font_bar,
            ft.Divider(height=1),
            ft.Container(height=4),
            ft.Column(controls=text_controls, spacing=14),
            ft.Container(height=24),
        ]
        self.page.update()

    async def build(self, page: ft.Page) -> ft.View:
        """Constrói a View da tela de Meditação Diária."""
        self.page = page
        page.title = "Meditação Diária - Hinário Inteligente"

        await self._load_preferences()

        # Dispara em segundo plano o Garbage Collector (purga de registros > 7 dias se o toggle estiver ativo)
        async def _background_cleanup_task():
            try:
                # Checa preferência do toggle
                pref = await storage_get(page, "devotional_auto_cleanup_7d")
                is_enabled = True if pref is None else bool(pref)
                if is_enabled:
                    await self.devotional_service.run_auto_cleanup()
            except Exception:
                pass

        page.run_task(_background_cleanup_task)

        category_selector_header = self._build_category_selector()
        carousel_header = self._build_date_carousel()

        self.content_container = ft.Column(
            controls=[
                ft.Container(
                    content=ft.ProgressRing(),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(40),
                )
            ],
            spacing=10,
            scroll=ft.ScrollMode.AUTO,
            expand=True,
        )

        # Inicia carregamento da meditação do dia corrente
        page.run_task(self._load_devotional_for_selected_date)

        return ft.View(
            route="/meditacoes",
            bgcolor=ft.Colors.SURFACE,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    on_click=lambda e: page.go("/"),
                ),
                title=ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.FAVORITE_ROUNDED, color=ft.Colors.PRIMARY, size=20),
                        ft.Text("Meditação Diária", weight=ft.FontWeight.BOLD),
                    ],
                    tight=True,
                    alignment=ft.MainAxisAlignment.CENTER,
                ),
                center_title=True,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                actions=[
                    ft.IconButton(
                        icon=ft.Icons.REFRESH,
                        tooltip="Atualizar da Nuvem",
                        on_click=lambda e: page.run_task(
                            self._load_devotional_for_selected_date, True
                        ),
                    ),
                    ft.IconButton(
                        icon=ft.Icons.STORAGE_ROUNDED,
                        tooltip="Gerenciar Armazenamento / Cache",
                        on_click=lambda e: page.go("/meditacoes/cache"),
                    ),
                ],
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Column(
                        controls=[
                            category_selector_header,
                            carousel_header,
                            ft.Divider(height=1),
                            ft.Container(
                                content=self.content_container,
                                padding=ft.Padding.symmetric(horizontal=16, vertical=8),
                                expand=True,
                            ),
                        ],
                        expand=True,
                        spacing=0,
                    ),
                    expand=True,
                )
            ],
        )
