"""
View / Painel de Gerenciamento de Armazenamento e Cache de Meditações.
Permite:
1. Ativar/Desativar exclusão automática com mais de 7 dias (persistido no client_storage).
2. Ver total de meditações salvas localmente.
3. Limpeza total do cache com diálogo de confirmação.
4. Listagem itemizada das meditações em cache com exclusão individual e atualização reativa.
"""

from __future__ import annotations

from datetime import datetime

import flet as ft

from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService
from src.utils.storage_manager import storage_get, storage_set

STORAGE_KEY_AUTO_CLEANUP = "devotional_auto_cleanup_7d"


class GerenciarCacheView:
    """
    Controlador e construtor da tela de Gerenciamento de Armazenamento de Meditações.
    """

    def __init__(self, devotional_service: DevotionalService):
        self.devotional_service = devotional_service
        self.page: ft.Page | None = None
        self.cached_items: list[Devotional] = []
        self.auto_cleanup_enabled: bool = True

        # Componentes UI
        self.stats_text: ft.Text | None = None
        self.cleanup_switch: ft.Switch | None = None
        self.list_column: ft.Column | None = None
        self.loading_ring: ft.ProgressRing | None = None
        self.clear_all_button: ft.FilledTonalButton | None = None

    async def _load_preferences(self) -> None:
        """Lê preferências com suporte resiliente a storage."""
        if not self.page:
            return
        val = await storage_get(self.page, STORAGE_KEY_AUTO_CLEANUP)
        if val is None:
            self.auto_cleanup_enabled = True
            await storage_set(self.page, STORAGE_KEY_AUTO_CLEANUP, True)
        else:
            self.auto_cleanup_enabled = bool(val)

    async def _on_toggle_cleanup(self, e: ft.ControlEvent) -> None:
        """Persiste alteração do toggle de limpeza automática."""
        self.auto_cleanup_enabled = bool(e.control.value)
        if self.page:
            await storage_set(
                self.page, STORAGE_KEY_AUTO_CLEANUP, self.auto_cleanup_enabled
            )
            self._show_snack(
                "Limpeza automática "
                + ("ativada (> 7 dias)" if self.auto_cleanup_enabled else "desativada")
            )

    def _show_snack(self, message: str) -> None:
        if not self.page:
            return
        snack = ft.SnackBar(ft.Text(message), duration=2500)
        try:
            self.page.open(snack)
        except Exception:
            self.page.overlay.append(snack)
            snack.open = True
            self.page.update()

    async def _load_cached_devotionals(self) -> None:
        """Carrega do SQLite a lista de devocionais salvas."""
        self.cached_items = await self.devotional_service.get_all_cached_devotionals()
        self._update_ui_state()

    def _update_ui_state(self) -> None:
        """Atualiza a lista visual e os contadores numéricos."""
        count = len(self.cached_items)
        if self.stats_text:
            self.stats_text.value = f"{count} meditaç{'ão salva' if count == 1 else 'ões salvas'} localmente"

        if self.clear_all_button:
            self.clear_all_button.disabled = count == 0

        if not self.list_column:
            return

        if count == 0:
            self.list_column.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Icon(ft.Icons.STORAGE_ROUNDED, size=48, color=ft.Colors.OUTLINE),
                            ft.Text(
                                "Nenhuma meditação em cache no momento.",
                                size=14,
                                color=ft.Colors.OUTLINE,
                                italic=True,
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=8,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(32),
                )
            ]
        else:
            tiles: list[ft.Control] = []
            for item in self.cached_items:
                tiles.append(self._build_devotional_tile(item))
            self.list_column.controls = tiles

        if self.page:
            self.page.update()

    def _build_devotional_tile(self, item: Devotional) -> ft.Card:
        """Gera o cartão de um item com botão de exclusão individual."""
        # Formata data de exibição (YYYY-MM-DD para DD/MM/YYYY)
        data_fmt = item.published_at
        try:
            dt = datetime.strptime(item.published_at, "%Y-%m-%d")
            data_fmt = dt.strftime("%d/%m/%Y")
        except Exception:
            pass

        return ft.Card(
            elevation=1,
            content=ft.Container(
                content=ft.ListTile(
                    leading=ft.Container(
                        content=ft.Icon(ft.Icons.BOOKMARK_ADDED, color=ft.Colors.PRIMARY, size=22),
                        padding=ft.Padding.all(6),
                        border_radius=8,
                        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                    ),
                    title=ft.Text(
                        item.title,
                        weight=ft.FontWeight.W_600,
                        size=14,
                        max_lines=1,
                        overflow=ft.TextOverflow.ELLIPSIS,
                    ),
                    subtitle=ft.Text(
                        f"Data: {data_fmt} • {item.category.capitalize()} • {item.verse_reference}",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                    trailing=ft.IconButton(
                        icon=ft.Icons.DELETE_OUTLINE,
                        tooltip="Remover esta meditação do cache",
                        icon_color=ft.Colors.ERROR,
                        on_click=lambda e, d=item: self._confirm_delete_single(d),
                    ),
                ),
                padding=ft.Padding.symmetric(horizontal=4, vertical=2),
            ),
        )

    def _confirm_delete_single(self, item: Devotional) -> None:
        """Diálogo de confirmação para exclusão individual."""
        if not self.page:
            return

        def _fechar(e):
            try:
                self.page.close(dlg)
            except Exception:
                dlg.open = False
                self.page.update()

        def _confirmar(e):
            _fechar(e)
            if self.page:
                self.page.run_task(self._delete_single, item.published_at, item.category)

        dlg = ft.AlertDialog(
            title=ft.Text("Excluir Meditação"),
            content=ft.Text(f"Deseja remover do armazenamento local a meditação '{item.title}' ({item.category.capitalize()})?"),
            actions=[
                ft.TextButton("Cancelar", on_click=_fechar),
                ft.FilledButton("Excluir", style=ft.ButtonStyle(bgcolor=ft.Colors.ERROR), on_click=_confirmar),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        try:
            self.page.open(dlg)
        except Exception:
            self.page.dialog = dlg
            dlg.open = True
            self.page.update()

    async def _delete_single(self, published_at: str, category: str = "jovem") -> None:
        """Executa exclusão e recarrega."""
        await self.devotional_service.delete_devotional(published_at, category=category)
        self._show_snack("Meditação removida do cache local.")
        await self._load_cached_devotionals()

    def _confirm_clear_all(self, e) -> None:
        """Diálogo de confirmação para limpar todo o cache."""
        if not self.page:
            return

        def _fechar(ev):
            try:
                self.page.close(dlg)
            except Exception:
                dlg.open = False
                self.page.update()

        def _confirmar(ev):
            _fechar(ev)
            if self.page:
                self.page.run_task(self._clear_all_cache)

        dlg = ft.AlertDialog(
            title=ft.Text("Limpar Todo o Cache"),
            content=ft.Text("Tem certeza que deseja apagar todas as meditações salvas localmente?"),
            actions=[
                ft.TextButton("Cancelar", on_click=_fechar),
                ft.FilledButton("Limpar Tudo", style=ft.ButtonStyle(bgcolor=ft.Colors.ERROR), on_click=_confirmar),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        try:
            self.page.open(dlg)
        except Exception:
            self.page.dialog = dlg
            dlg.open = True
            self.page.update()

    async def _clear_all_cache(self) -> None:
        """Executa a limpeza total de cache."""
        count = await self.devotional_service.clear_all_cache()
        self._show_snack(f"Cache limpo: {count} meditações removidas.")
        await self._load_cached_devotionals()

    async def build(self, page: ft.Page) -> ft.View:
        """Constrói a View da tela de Gerenciamento de Armazenamento."""
        self.page = page
        page.title = "Gerenciamento de Armazenamento - Meditações"

        await self._load_preferences()

        self.stats_text = ft.Text(
            "Carregando informações...",
            weight=ft.FontWeight.W_600,
            size=14,
            color=ft.Colors.ON_SURFACE,
        )

        self.cleanup_switch = ft.Switch(
            value=self.auto_cleanup_enabled,
            on_change=lambda e: page.run_task(self._on_toggle_cleanup, e),
        )

        self.clear_all_button = ft.FilledTonalButton(
            "Limpar Todo o Cache",
            icon=ft.Icons.DELETE_SWEEP,
            style=ft.ButtonStyle(color=ft.Colors.ERROR),
            on_click=self._confirm_clear_all,
            disabled=True,
        )

        self.list_column = ft.Column(
            controls=[
                ft.Container(
                    content=ft.ProgressRing(),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(20),
                )
            ],
            spacing=8,
        )

        # Card de Configuração e Estatísticas
        header_card = ft.Card(
            elevation=2,
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.CLEANING_SERVICES, color=ft.Colors.PRIMARY, size=24),
                                ft.Column(
                                    controls=[
                                        ft.Text(
                                            "Limpeza Automática de Registros",
                                            weight=ft.FontWeight.BOLD,
                                            size=14,
                                        ),
                                        ft.Text(
                                            "Excluir meditações com mais de 7 dias automaticamente",
                                            size=12,
                                            color=ft.Colors.ON_SURFACE_VARIANT,
                                        ),
                                    ],
                                    spacing=2,
                                    expand=True,
                                ),
                                self.cleanup_switch,
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1),
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.STORAGE, size=18, color=ft.Colors.PRIMARY),
                                self.stats_text,
                                ft.Container(expand=True),
                                self.clear_all_button,
                            ],
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            wrap=True,
                        ),
                    ],
                    spacing=12,
                ),
                padding=ft.Padding.all(14),
            ),
        )

        # Dispara carregamento das meditações em segundo plano
        page.run_task(self._load_cached_devotionals)

        content = ft.Column(
            controls=[
                header_card,
                ft.Container(height=4),
                ft.Text(
                    "Meditações Armazenadas em Disco",
                    size=15,
                    weight=ft.FontWeight.BOLD,
                    color=ft.Colors.PRIMARY,
                ),
                self.list_column,
            ],
            scroll=ft.ScrollMode.AUTO,
            spacing=10,
            expand=True,
        )

        return ft.View(
            route="/meditacoes/cache",
            bgcolor=ft.Colors.SURFACE,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    on_click=lambda e: page.go("/meditacoes"),
                ),
                title=ft.Text("Gerenciar Armazenamento", weight=ft.FontWeight.BOLD),
                center_title=True,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Container(
                        content=content,
                        padding=ft.Padding.all(12),
                        expand=True,
                    ),
                    expand=True,
                )
            ],
        )

