"""
View Principal de Meditação Diária (Devocional) - Hinário Inteligente.
Recursos:
1. Disparo em segundo plano de run_auto_cleanup() no carregamento.
2. Seletor visual de categoria (Jovem, Diário, Mulher) com persistência em storage.
3. Carrossel horizontal de chips para seleção dos últimos 7 dias com indicador de status de cache e ofensiva.
4. Card clicável do versículo-chave com fade-in, disparando o modal do versículo (show_verse_dialog).
5. Renderização fluida do texto com redimensionamento dinâmico e título em HymnSerif.
6. BottomSheet de acessibilidade: controle de tamanho E família de fonte, com persistência.
7. Botão de marcar leitura concluída integrado ao ReadingService com cálculo de streak (ofensiva).
8. Botão de copiar meditação (título + versículo + conteúdo) para área de transferência.
9. Botão de link direto para o site da CPB onde a lição está publicada.
10. Animação suave (fade + slide) ao alternar entre datas no carrossel.
"""

from __future__ import annotations

import asyncio
import uuid
from datetime import date, timedelta
from typing import Any

import flet as ft

from src.components.verse_dialog import show_verse_dialog
from src.models.devotional import Devotional
from src.services.auth_service import AuthService
from src.services.devotional_service import DevotionalService
from src.services.reading_service import ReadingService
from src.services.theme_service import ThemeService
from src.utils.storage_manager import storage_get, storage_set

# ---------------------------------------------------------------------------
# Configurações de fonte
# ---------------------------------------------------------------------------
FONT_STEP = 2
MIN_FONT_SIZE = 14
MAX_FONT_SIZE = 28
DEFAULT_CONTENT_FONT_SIZE = 16

STORAGE_KEY_FONT_SIZE = "devotional_font_size"
STORAGE_KEY_FONT_FAMILY = "devotional_font_family"
STORAGE_KEY_CATEGORY = "preferred_devotional_category"
STORAGE_KEY_DEVICE_UUID = "device_uuid"

# Fontes disponíveis no app (registradas em font_manager.py / assets/fonts/)
FONT_FAMILIES: dict[str, str | None] = {
    "Padrão (AppSans)": "AppSans",
    "Serifada (HymnSerif)": "HymnSerif",
    "Montserrat": "Montserrat",
    "OpenDyslexic": "OpenDyslexic",
    "Helvetica": "Helvetica",
}
DEFAULT_FONT_FAMILY_KEY = "Padrão (AppSans)"

VALID_CATEGORIES = ("jovem", "diario", "mulher")


class MeditacaoView:
    """
    Controlador e construtor da tela principal de Meditação Diária com suporte
    a ofensiva de leitura e animações suaves.
    """

    def __init__(
        self,
        devotional_service: DevotionalService,
        theme_service: ThemeService | None = None,
        reading_service: ReadingService | None = None,
        auth_service: AuthService | None = None,
        category: str = "jovem",
    ):
        self.devotional_service = devotional_service
        self.theme_service = theme_service
        self.reading_service = reading_service
        self.auth_service = auth_service
        self.category = category.lower() if category.lower() in VALID_CATEGORIES else "jovem"
        self.selected_date: date = date.today()
        self.current_devotional: Devotional | None = None
        self.is_loading: bool = False
        self.font_size: int = DEFAULT_CONTENT_FONT_SIZE
        self.font_family_key: str = DEFAULT_FONT_FAMILY_KEY
        self.page: ft.Page | None = None
        self.cached_dates: set[str] = set()
        self.read_dates: set[str] = set()
        self.current_streak: int = 0

        # Controles reativos
        self.category_selector: ft.SegmentedButton | None = None
        self.content_container: ft.Column | None = None
        self.animated_content_wrapper: ft.Container | None = None
        self.date_chips_row: ft.Row | None = None

        # SnackBar singleton reutilizável
        self._snackbar: ft.SnackBar | None = None

    # -----------------------------------------------------------------------
    # Helpers
    # -----------------------------------------------------------------------

    @property
    def _current_font_family(self) -> str | None:
        """Retorna o valor de font_family para uso nos ft.Text do conteúdo."""
        return FONT_FAMILIES.get(self.font_family_key)

    def _show_snackbar(self, msg: str) -> None:
        """Exibe um SnackBar reutilizável evitando acúmulo no overlay."""
        if not self.page:
            return
        if self._snackbar is None:
            self._snackbar = ft.SnackBar(content=ft.Text(msg))
            self.page.overlay.append(self._snackbar)
        else:
            self._snackbar.content = ft.Text(msg)
        self._snackbar.open = True
        self.page.update()

    async def _get_device_or_user_id(self) -> str:
        """Retorna o ID do usuário (se autenticado) ou o UUID do dispositivo persistido."""
        if self.auth_service:
            user = self.auth_service.get_current_user()
            if user and getattr(user, "id", None):
                return str(user.id)

        if self.page:
            val = await storage_get(self.page, STORAGE_KEY_DEVICE_UUID)
            if val:
                return str(val)
            new_uuid = str(uuid.uuid4())
            await storage_set(self.page, STORAGE_KEY_DEVICE_UUID, new_uuid)
            return new_uuid

        return str(uuid.uuid4())

    # -----------------------------------------------------------------------
    # Persistência de preferências
    # -----------------------------------------------------------------------

    async def _load_preferences(self) -> None:
        """Carrega preferências salvas no storage (fonte, família e categoria)."""
        if not self.page:
            return

        # 1. Tamanho da fonte
        try:
            val_font = await storage_get(self.page, STORAGE_KEY_FONT_SIZE)
            if val_font is not None:
                self.font_size = max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, int(val_font)))
        except Exception:
            self.font_size = DEFAULT_CONTENT_FONT_SIZE

        # 2. Família de fonte
        try:
            val_family = await storage_get(self.page, STORAGE_KEY_FONT_FAMILY)
            if val_family and str(val_family) in FONT_FAMILIES:
                self.font_family_key = str(val_family)
        except Exception:
            pass

        # 3. Categoria preferida
        try:
            val_cat = await storage_get(self.page, STORAGE_KEY_CATEGORY)
            if val_cat and str(val_cat).lower() in VALID_CATEGORIES:
                self.category = str(val_cat).lower()
        except Exception:
            pass

    async def _save_text_preferences(self) -> None:
        """Salva tamanho e família de fonte no storage."""
        if not self.page:
            return
        try:
            await storage_set(self.page, STORAGE_KEY_FONT_SIZE, self.font_size)
            await storage_set(self.page, STORAGE_KEY_FONT_FAMILY, self.font_family_key)
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

    # -----------------------------------------------------------------------
    # Controles de fonte
    # -----------------------------------------------------------------------

    def _change_font_size(self, delta: int) -> None:
        """Aumenta ou diminui dinamicamente o tamanho da fonte."""
        new_size = self.font_size + delta
        if MIN_FONT_SIZE <= new_size <= MAX_FONT_SIZE:
            self.font_size = new_size
            if self.page:
                self.page.run_task(self._save_text_preferences)
            self._update_rendered_content()

    def _reset_font_size(self) -> None:
        """Restaura o tamanho padrão da fonte."""
        self.font_size = DEFAULT_CONTENT_FONT_SIZE
        if self.page:
            self.page.run_task(self._save_text_preferences)
        self._update_rendered_content()

    def _set_font_family(self, key: str) -> None:
        """Aplica a família de fonte selecionada e persiste."""
        if key in FONT_FAMILIES:
            self.font_family_key = key
            if self.page:
                self.page.run_task(self._save_text_preferences)
            self._update_rendered_content()

    # -----------------------------------------------------------------------
    # BottomSheet de Acessibilidade
    # -----------------------------------------------------------------------

    def _show_accessibility_bottom_sheet(self) -> None:
        """Abre o BottomSheet com controles de tamanho e família de fonte."""
        if not self.page:
            return

        font_size_text = ft.Text(
            f"{self.font_size}pt",
            weight=ft.FontWeight.BOLD,
            size=16,
        )

        def _decrease(e):
            new_size = self.font_size - FONT_STEP
            if new_size >= MIN_FONT_SIZE:
                self.font_size = new_size
                font_size_text.value = f"{self.font_size}pt"
                self.page.run_task(self._save_text_preferences)
                self._update_rendered_content()
                try:
                    bs.update()
                except Exception:
                    pass

        def _increase(e):
            new_size = self.font_size + FONT_STEP
            if new_size <= MAX_FONT_SIZE:
                self.font_size = new_size
                font_size_text.value = f"{self.font_size}pt"
                self.page.run_task(self._save_text_preferences)
                self._update_rendered_content()
                try:
                    bs.update()
                except Exception:
                    pass

        def _reset(e):
            self.font_size = DEFAULT_CONTENT_FONT_SIZE
            font_size_text.value = f"{self.font_size}pt"
            self.page.run_task(self._save_text_preferences)
            self._update_rendered_content()
            try:
                bs.update()
            except Exception:
                pass

        def _on_font_change(e):
            selected_key = e.control.value
            if selected_key in FONT_FAMILIES:
                self._set_font_family(selected_key)

        font_radio_group = ft.RadioGroup(
            content=ft.Column(
                controls=[
                    ft.Radio(
                        value=key,
                        label=key,
                    )
                    for key in FONT_FAMILIES
                ],
                spacing=4,
            ),
            value=self.font_family_key,
            on_change=_on_font_change,
        )

        bs = ft.BottomSheet(
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        # Cabeçalho
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.ACCESSIBILITY_NEW_ROUNDED, color=ft.Colors.PRIMARY),
                                ft.Text(
                                    "Acessibilidade de Texto",
                                    weight=ft.FontWeight.BOLD,
                                    size=18,
                                    expand=True,
                                ),
                                ft.IconButton(
                                    ft.Icons.CLOSE,
                                    tooltip="Fechar",
                                    on_click=lambda ev: self.page.pop_dialog(),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1),
                        # Controle de tamanho
                        ft.Text(
                            "Tamanho da Letra",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        ft.Row(
                            controls=[
                                ft.IconButton(
                                    ft.Icons.TEXT_DECREASE,
                                    icon_size=22,
                                    tooltip="Diminuir (A-)",
                                    on_click=_decrease,
                                ),
                                font_size_text,
                                ft.IconButton(
                                    ft.Icons.TEXT_INCREASE,
                                    icon_size=22,
                                    tooltip="Aumentar (A+)",
                                    on_click=_increase,
                                ),
                                ft.Container(expand=True),
                                ft.TextButton(
                                    "Restaurar padrão",
                                    icon=ft.Icons.REFRESH,
                                    on_click=_reset,
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=4,
                        ),
                        ft.Divider(height=1),
                        # Família de fonte
                        ft.Text(
                            "Família de Fonte",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        font_radio_group,
                    ],
                    spacing=10,
                    tight=True,
                    scroll=ft.ScrollMode.AUTO,
                ),
                padding=ft.Padding.only(left=20, top=16, right=20, bottom=40),
            ),
        )

        try:
            self.page.show_dialog(bs)
        except Exception:
            self.page.overlay.append(bs)
            bs.open = True
            self.page.update()

    # -----------------------------------------------------------------------
    # Ofensiva e Leitura Concluída
    # -----------------------------------------------------------------------

    async def _update_reading_status(self) -> None:
        """Consulta streak atual e histórico de leitura se ReadingService disponível."""
        if not self.reading_service:
            return
        try:
            self.current_streak = await self.reading_service.get_current_streak()
            self.read_dates = await self.reading_service.get_recent_read_dates(14)
        except Exception:
            pass

    async def _on_mark_as_read(self) -> None:
        """Registra a meditação aberta como lida e recalcula a ofensiva."""
        if not self.reading_service or not self.page:
            return
        device_id = await self._get_device_or_user_id()
        target_str = self.selected_date.isoformat()
        await self.reading_service.mark_as_read(target_str, self.category, device_id)
        await self._update_reading_status()

        streak_msg = f"🔥 Sequência: {self.current_streak} dia(s) consecutivos!" if self.current_streak > 0 else "Ótima leitura!"
        self._show_snackbar(f"Meditação concluída! {streak_msg}")
        self._update_rendered_content()

    # -----------------------------------------------------------------------
    # Copiar meditação
    # -----------------------------------------------------------------------

    async def _copy_devotional(self) -> None:
        """Copia o texto completo da meditação atual para a área de transferência."""
        dev = self.current_devotional
        if not dev:
            return

        parts: list[str] = [dev.title]

        if dev.verse_text and dev.verse_reference:
            parts.append(f'"{dev.verse_text}"\n— {dev.verse_reference}')
        elif dev.verse_text:
            parts.append(f'"{dev.verse_text}"')

        if dev.content:
            parts.append(dev.content)

        if dev.author:
            parts.append(f"— {dev.author}")

        if dev.source_url:
            parts.append(f"\nFonte: {dev.source_url}")

        texto_final = "\n\n".join(parts)

        try:
            if self.page:
                await self.page.set_clipboard_async(texto_final)
        except Exception:
            try:
                self.page.set_clipboard(texto_final)
            except Exception:
                pass

        self._show_snackbar("Meditação copiada! Cole onde quiser compartilhar 📋")

    # -----------------------------------------------------------------------
    # Abrir site da CPB
    # -----------------------------------------------------------------------

    async def _open_cpb_site(self) -> None:
        """Abre o link da CPB no navegador externo."""
        dev = self.current_devotional
        if not dev or not dev.source_url:
            self._show_snackbar("Link do site não disponível para esta meditação.")
            return
        try:
            await ft.UrlLauncher().launch_url(dev.source_url)
        except Exception:
            self._show_snackbar("Não foi possível abrir o link da CPB.")

    # -----------------------------------------------------------------------
    # Builders de UI
    # -----------------------------------------------------------------------

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
        """Manipula alteração de categoria com feedback animado."""
        if not e.control.selected:
            return
        selected_cat = list(e.control.selected)[0].lower()
        if selected_cat not in VALID_CATEGORIES or selected_cat == self.category:
            return

        self.category = selected_cat
        await self._save_category_preference()

        if self.animated_content_wrapper:
            self.animated_content_wrapper.opacity = 0.0
            self.animated_content_wrapper.offset = ft.Offset(0, 0.03)
            try:
                self.animated_content_wrapper.update()
            except Exception:
                pass

        self.is_loading = True
        self._update_rendered_content()
        await self._load_devotional_for_selected_date()

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

    def _build_day_chip(
        self,
        day_target: date,
        is_selected: bool,
        is_cached: bool,
        is_read: bool,
    ) -> ft.Container:
        """Constrói um chip de dia para o carrossel com badge de leitura e streak."""
        dia_label, sub_label = self._format_day_chip_label(day_target)
        is_today = day_target == date.today()

        label_controls: list[ft.Control] = [
            ft.Text(
                dia_label,
                size=12,
                weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.W_500,
                color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
            )
        ]

        # Badge de streak no chip Hoje se houver ofensiva ativa
        if is_today and self.current_streak > 0:
            label_controls.append(
                ft.Container(
                    content=ft.Text(
                        f"🔥{self.current_streak}",
                        size=9,
                        weight=ft.FontWeight.BOLD,
                        color=ft.Colors.ORANGE_900,
                    ),
                    bgcolor=ft.Colors.AMBER_200,
                    border_radius=4,
                    padding=ft.Padding.symmetric(horizontal=3, vertical=0),
                )
            )

        # Ícone de leitura concluída ou cache
        if is_read:
            status_icon = ft.Icon(
                ft.Icons.CHECK_CIRCLE,
                size=11,
                color=ft.Colors.GREEN_600,
                tooltip="Leitura concluída",
            )
        elif is_cached:
            status_icon = ft.Icon(
                ft.Icons.CHECK_CIRCLE_OUTLINE,
                size=11,
                color=ft.Colors.GREEN_400,
                tooltip="Salva offline",
            )
        else:
            status_icon = ft.Icon(
                ft.Icons.RADIO_BUTTON_UNCHECKED,
                size=11,
                color=ft.Colors.OUTLINE_VARIANT,
                tooltip="Não baixada",
            )

        label_controls.append(status_icon)

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=label_controls,
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

    def _build_date_carousel(self) -> ft.Container:
        """Constrói o carrossel horizontal com os últimos 7 dias."""
        today = date.today()
        chips = [
            self._build_day_chip(
                day_target=today - timedelta(days=i),
                is_selected=(today - timedelta(days=i)) == self.selected_date,
                is_cached=(today - timedelta(days=i)).isoformat() in self.cached_dates,
                is_read=(today - timedelta(days=i)).isoformat() in self.read_dates,
            )
            for i in range(7)
        ]

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
        """Manipula seleção de um dia no carrossel com animação suave de transição."""
        if self.selected_date == target_date and self.current_devotional:
            return

        # Animação de saída: fade-out e leve deslocamento
        if self.animated_content_wrapper:
            self.animated_content_wrapper.opacity = 0.0
            self.animated_content_wrapper.offset = ft.Offset(0, 0.03)
            try:
                self.animated_content_wrapper.update()
            except Exception:
                pass

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
        """Carrega a meditação (offline-first: Cache → Nuvem → Salva no Cache)."""
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
        await self._update_reading_status()

        self.is_loading = False
        self._update_rendered_content()

    def _show_verse_modal(self, e=None) -> None:
        """Abre o diálogo de versículo com parser e atalho para a Bíblia."""
        if not self.page or not self.current_devotional:
            return
        dev = self.current_devotional
        if not dev.verse_text or not dev.verse_reference:
            return
        show_verse_dialog(
            page=self.page,
            verse_text=dev.verse_text,
            verse_reference=dev.verse_reference,
        )

    # -----------------------------------------------------------------------
    # Renderização principal
    # -----------------------------------------------------------------------

    def _update_rendered_content(self) -> None:
        """Re-renderiza a área de conteúdo da meditação e reativa a animação suave."""
        if not self.content_container or not self.page:
            return

        # Sincroniza estado visual do seletor de categoria
        if self.category_selector and self.category_selector.selected != [self.category]:
            self.category_selector.selected = [self.category]

        # Atualiza chips do carrossel
        today = date.today()
        if self.date_chips_row:
            self.date_chips_row.controls = [
                self._build_day_chip(
                    day_target=today - timedelta(days=i),
                    is_selected=(today - timedelta(days=i)) == self.selected_date,
                    is_cached=(today - timedelta(days=i)).isoformat() in self.cached_dates,
                    is_read=(today - timedelta(days=i)).isoformat() in self.read_dates,
                )
                for i in range(7)
            ]

        # --- Estado: Carregando ---
        if self.is_loading:
            self.content_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.ProgressRing(),
                            ft.Text(
                                f"Carregando meditação ({self.category.capitalize()})...",
                                size=14,
                                italic=True,
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=12,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(40),
                )
            ]
            if self.animated_content_wrapper:
                self.animated_content_wrapper.opacity = 1.0
                self.animated_content_wrapper.offset = ft.Offset(0, 0)
            self.page.update()
            return

        # --- Estado: Sem dados / offline ---
        if not self.current_devotional:
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
            if self.animated_content_wrapper:
                self.animated_content_wrapper.opacity = 1.0
                self.animated_content_wrapper.offset = ft.Offset(0, 0)
            self.page.update()
            return

        # --- Estado: Meditação carregada ---
        dev = self.current_devotional
        font_fam = self._current_font_family
        has_verse = bool(dev.verse_text and dev.verse_reference)

        # Card do Versículo-Chave com animação suave de fade
        if has_verse:
            verse_card_inner = ft.Card(
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
                                        font_family=font_fam,
                                    ),
                                    ft.Icon(ft.Icons.OPEN_IN_NEW, size=16, color=ft.Colors.PRIMARY),
                                ],
                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            ),
                            ft.Text(
                                f'"{dev.verse_text.strip()}"',
                                size=self.font_size,
                                italic=True,
                                font_family=font_fam,
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
            verse_card = ft.Container(
                content=verse_card_inner,
                opacity=1.0,
                animate_opacity=ft.Animation(300, ft.AnimationCurve.EASE_IN_OUT),
            )
        else:
            # Placeholder discreto quando não há versículo disponível
            verse_card = ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.FORMAT_QUOTE, size=16, color=ft.Colors.OUTLINE),
                        ft.Text(
                            "Texto bíblico não disponível para esta meditação.",
                            size=13,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                            italic=True,
                        ),
                    ],
                    spacing=8,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                border_radius=12,
                padding=ft.Padding.symmetric(horizontal=14, vertical=10),
                opacity=0.7,
            )

        # Barra de controle de fonte com botão de acessibilidade
        font_family_label = self.font_family_key.split(" ")[0]  # ex: "Padrão", "Serifada"
        font_bar = ft.Row(
            controls=[
                ft.Text(
                    f"Fonte: {self.font_size}pt · {font_family_label}",
                    size=12,
                    weight=ft.FontWeight.W_500,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.IconButton(
                    icon=ft.Icons.TEXT_FIELDS_ROUNDED,
                    tooltip="Acessibilidade de Texto (tamanho e família)",
                    icon_size=20,
                    on_click=lambda e: self._show_accessibility_bottom_sheet(),
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )

        # Parágrafos do corpo do texto
        paragraphs = [p.strip() for p in dev.content.split("\n\n") if p.strip()]
        text_controls: list[ft.Control] = [
            ft.Text(
                p,
                size=self.font_size,
                selectable=True,
                font_family=font_fam,
            )
            for p in paragraphs
        ]

        # Rodapé de autoria
        if dev.author:
            text_controls.append(
                ft.Container(
                    content=ft.Text(
                        f"— {dev.author}",
                        size=self.font_size - 1,
                        weight=ft.FontWeight.BOLD,
                        italic=True,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                        font_family=font_fam,
                    ),
                    alignment=ft.Alignment.CENTER_RIGHT,
                    padding=ft.Padding.only(top=10, bottom=6),
                )
            )

        # Botão de leitura concluída / Ofensiva
        is_current_day_read = self.selected_date.isoformat() in self.read_dates
        if is_current_day_read:
            btn_read = ft.FilledTonalButton(
                f"Lida hoje 🔥 ({self.current_streak}d)" if self.selected_date == date.today() else "Leitura concluída ✓",
                icon=ft.Icons.CHECK_CIRCLE,
                disabled=True,
                tooltip="Você já marcou a leitura desta meditação",
            )
        else:
            btn_read = ft.FilledButton(
                "Marcar como lida",
                icon=ft.Icons.CHECK_CIRCLE_OUTLINE,
                tooltip="Confirmar conclusão da leitura e manter sua ofensiva ativa",
                on_click=lambda e: self.page.run_task(self._on_mark_as_read) if self.page else None,
            )

        # Seção de ações do rodapé (Marcar Lida + Copiar + Link CPB)
        action_footer = ft.Container(
            content=ft.Row(
                controls=[
                    btn_read,
                    ft.OutlinedButton(
                        "Copiar",
                        icon=ft.Icons.CONTENT_COPY_ROUNDED,
                        tooltip="Copiar título, versículo e texto para a área de transferência",
                        on_click=lambda e: self.page.run_task(self._copy_devotional) if self.page else None,
                    ),
                    ft.FilledTonalButton(
                        "Ver na CPB",
                        icon=ft.Icons.OPEN_IN_NEW_ROUNDED,
                        tooltip="Abrir a lição original no site da CPB",
                        on_click=lambda e: self.page.run_task(self._open_cpb_site) if self.page else None,
                        visible=bool(dev.source_url),
                    ),
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=10,
                wrap=True,
            ),
            padding=ft.Padding.symmetric(vertical=12),
        )

        # Título da meditação com fonte editorial clássica fixa HymnSerif
        title_control = ft.Text(
            dev.title,
            size=22,
            weight=ft.FontWeight.BOLD,
            color=ft.Colors.ON_SURFACE,
            font_family="HymnSerif",
        )

        self.content_container.controls = [
            title_control,
            ft.Container(height=2),
            verse_card,
            ft.Container(height=4),
            font_bar,
            ft.Divider(height=1),
            ft.Container(height=4),
            ft.Column(controls=text_controls, spacing=14),
            ft.Divider(height=1),
            action_footer,
            ft.Container(height=24),
        ]

        # Animação de entrada suave
        if self.animated_content_wrapper:
            self.animated_content_wrapper.opacity = 1.0
            self.animated_content_wrapper.offset = ft.Offset(0, 0)

        self.page.update()

    # -----------------------------------------------------------------------
    # Build da View
    # -----------------------------------------------------------------------

    async def build(self, page: ft.Page) -> ft.View:
        """Constrói a View da tela de Meditação Diária."""
        self.page = page
        page.title = "Meditação Diária - Hinário Inteligente"

        await self._load_preferences()
        await self._update_reading_status()

        # Garbage Collector em background (purga registros > 7 dias se toggle ativo)
        async def _background_cleanup_task():
            try:
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

        # Container animado que envolve o conteúdo para transição suave de data
        self.animated_content_wrapper = ft.Container(
            content=self.content_container,
            opacity=1.0,
            animate_opacity=ft.Animation(220, ft.AnimationCurve.EASE_IN_OUT),
            offset=ft.Offset(0, 0),
            animate_offset=ft.Animation(240, ft.AnimationCurve.EASE_OUT_CUBIC),
            expand=True,
        )

        # Inicia carregamento da meditação do dia corrente
        page.run_task(self._load_devotional_for_selected_date)

        streak_badge = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=18, color=ft.Colors.AMBER_600),
                    ft.Text(f"{self.current_streak}", weight=ft.FontWeight.BOLD, size=13),
                ],
                spacing=2,
            ),
            padding=ft.Padding.symmetric(horizontal=8, vertical=4),
            border_radius=8,
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            tooltip=f"Ofensiva de leitura: {self.current_streak} dia(s) consecutivos",
            visible=self.current_streak > 0,
        )

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
                    streak_badge,
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
                                content=self.animated_content_wrapper,
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
