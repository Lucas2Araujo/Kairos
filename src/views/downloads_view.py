import asyncio
import inspect
from typing import Any

import flet as ft

from src.repositories.biblia_repository import BIBLE_VERSION_NAMES
from src.services.content_manager import ContentManager
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.services.media_service import MediaService
from src.services.theme_service import ThemeService


class DownloadsView:
    """
    Tela moderna e completa para gerenciamento de downloads no Kairós.
    Organizada em seções:
    - Seção Hinários: Hinário Antigo (1996) e Hinário Comparativo
    - Seção Bíblias: Todas as versões listadas no manifesto (ARA, NVI, NTLH, KJA, etc.)
    - Seção Escola Sabatina: Trimestres e lições salvos off-line
    - Aba Secundária: Gerenciamento e download em lote de mídias de vídeo (SD/HD)
    """

    def __init__(
        self,
        content_manager: ContentManager | None = None,
        media_service: MediaService | None = None,
        theme_service: ThemeService | None = None,
        escola_sabatina_service: EscolaSabatinaService | None = None,
    ):
        self.content_manager = content_manager or ContentManager()
        self.media_service = media_service
        self.theme_service = theme_service
        self.escola_sabatina_service = escola_sabatina_service

        self.page: ft.Page | None = None
        self.manifest_data: dict[str, Any] = {"version": 1, "modules": []}
        self.download_progress: dict[str, float] = {}
        self.downloading_ids: set[str] = set()

        # Elementos de UI reativos
        self.storage_summary_text = ft.Text("", size=13, color=ft.Colors.ON_SURFACE_VARIANT)
        self.hinarios_column = ft.Column(spacing=10)
        self.biblias_column = ft.Column(spacing=10)
        self.escola_sabatina_column = ft.Column(spacing=10)
        self.escola_sabatina_summaries: list[dict[str, Any]] = []
        self.loading_indicator = ft.ProgressRing(visible=False, width=24, height=24)
        self._snackbar: ft.SnackBar | None = None

    def _get_accent_color(self) -> str:
        if self.theme_service:
            return self.theme_service.get_accent_color("novo")
        return ft.Colors.PRIMARY

    @staticmethod
    def _format_size(size_bytes: int | float | None) -> str:
        """Formata tamanho em bytes para MB com 2 casas decimais."""
        if not size_bytes or size_bytes <= 0:
            return "Tamanho desconhecido"
        mb = size_bytes / (1024 * 1024)
        return f"{mb:.2f} MB"

    def _calculate_total_installed_storage(self) -> str:
        """Calcula o espaço total em disco utilizado pelos módulos instalados e lições."""
        modules_dir = self.content_manager.modules_dir
        total_bytes = 0
        if modules_dir.exists():
            try:
                for item in modules_dir.rglob("*"):
                    if item.is_file():
                        total_bytes += item.stat().st_size
            except Exception:
                pass

        if self.escola_sabatina_summaries:
            total_bytes += sum(
                int(s.get("estimated_size_bytes") or 0) for s in self.escola_sabatina_summaries
            )

        return f"{total_bytes / (1024 * 1024):.1f} MB utilizados em módulos e lições"

    def _refresh_storage_text(self) -> None:
        self.storage_summary_text.value = self._calculate_total_installed_storage()

    def _show_snackbar(
        self, page: ft.Page, message: str, is_error: bool = False
    ) -> None:
        """Exibe feedback visual via SnackBar sem acumular no overlay."""
        if self._snackbar is None:
            self._snackbar = ft.SnackBar(
                content=ft.Text("", color=ft.Colors.WHITE, weight=ft.FontWeight.W_500),
                duration=4000,
                behavior=ft.SnackBarBehavior.FLOATING,
            )
            if hasattr(page, "overlay"):
                page.overlay.append(self._snackbar)
        self._snackbar.content = ft.Text(
            message, color=ft.Colors.WHITE, weight=ft.FontWeight.W_500
        )
        self._snackbar.bgcolor = (
            ft.Colors.RED_700 if is_error else ft.Colors.GREEN_700
        )
        self._snackbar.open = True
        try:
            page.update()
        except Exception:
            pass

    def _get_module_title_and_subtitle(
        self, mod_id: str, mod_info: dict[str, Any]
    ) -> tuple[str, str]:
        """Retorna nome amigável e descrição formatada para o item do módulo."""
        size_str = self._format_size(mod_info.get("size_bytes"))

        if mod_id == "hinario_antigo":
            return "Hinário Tradicional (1996)", f"613 Hinos clássicos • {size_str}"
        elif mod_id == "hinario_comparativo":
            return (
                "Hinário Comparativo (1996 ↔ 2022)",
                f"Comparador estrofe a estrofe e diffs • {size_str}",
            )
        elif mod_id == "hinario":
            return "Hinário Novo (2022)", f"Embutido de fábrica (Padrão) • {size_str}"

        # É uma Bíblia
        version_full_name = BIBLE_VERSION_NAMES.get(mod_id, mod_id)
        return (
            f"{version_full_name} ({mod_id})",
            f"Tradução Completa (66 Livros) • {size_str}",
        )

    def _build_module_card(
        self, page: ft.Page, mod_info: dict[str, Any]
    ) -> ft.Container:
        """Constrói o card individual de um módulo com botões de ação e barra de progresso."""
        mod_id = str(mod_info.get("id", ""))
        is_installed = self.content_manager.is_module_installed(mod_id)
        is_downloading = mod_id in self.downloading_ids
        progress_val = self.download_progress.get(mod_id, 0.0)

        title, subtitle = self._get_module_title_and_subtitle(mod_id, mod_info)

        is_outdated = is_installed and self.content_manager.is_module_outdated(mod_id, mod_info)
        if is_installed and is_outdated:
            subtitle += " • Atualização disponível"

        # Ícone do módulo
        if mod_id in ("hinario_antigo", "hinario_comparativo", "hinario"):
            icon_data = ft.Icons.MENU_BOOK if mod_id != "hinario_comparativo" else ft.Icons.COMPARE_ARROWS
            icon_color = ft.Colors.AMBER_400
        else:
            icon_data = ft.Icons.AUTO_STORIES
            icon_color = ft.Colors.GREEN_400

        # Controles de Ação à direita
        action_controls: list[ft.Control] = []

        if is_downloading:
            action_controls.extend(
                [
                    ft.Column(
                        controls=[
                            ft.Text(
                                f"{int(progress_val * 100)}%",
                                size=11,
                                weight=ft.FontWeight.BOLD,
                                color=self._get_accent_color(),
                            ),
                            ft.ProgressBar(
                                value=progress_val,
                                width=90,
                                color=self._get_accent_color(),
                            ),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=4,
                    )
                ]
            )
        elif is_installed and is_outdated:
            action_controls.extend(
                [
                    ft.FilledButton(
                        "Atualizar",
                        icon=ft.Icons.UPDATE,
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=8),
                            bgcolor=ft.Colors.AMBER_700,
                            color=ft.Colors.WHITE,
                        ),
                        on_click=lambda e, m_info=mod_info: asyncio.create_task(
                            self._start_download_action(page, m_info)
                        ),
                    ),
                    ft.IconButton(
                        icon=ft.Icons.DELETE_OUTLINE,
                        icon_color=ft.Colors.RED_400,
                        tooltip=f"Excluir {mod_id}",
                        on_click=lambda e, m_id=mod_id: asyncio.create_task(
                            self._delete_module_action(page, m_id)
                        ),
                    ),
                ]
            )
        elif is_installed:
            action_controls.extend(
                [
                    ft.Container(
                        content=ft.Row(
                            controls=[
                                ft.Icon(
                                    ft.Icons.CHECK_CIRCLE,
                                    size=16,
                                    color=ft.Colors.GREEN_400,
                                ),
                                ft.Text(
                                    "Instalado",
                                    size=12,
                                    weight=ft.FontWeight.BOLD,
                                    color=ft.Colors.GREEN_400,
                                ),
                            ],
                            spacing=4,
                            alignment=ft.MainAxisAlignment.CENTER,
                        ),
                        padding=ft.Padding.symmetric(horizontal=8, vertical=4),
                        border_radius=8,
                        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                    ),
                    ft.IconButton(
                        icon=ft.Icons.DELETE_OUTLINE,
                        icon_color=ft.Colors.RED_400,
                        tooltip=f"Excluir {mod_id}",
                        on_click=lambda e, m_id=mod_id: asyncio.create_task(
                            self._delete_module_action(page, m_id)
                        ),
                    ),
                ]
            )
        else:
            action_controls.append(
                ft.FilledButton(
                    "Baixar",
                    icon=ft.Icons.DOWNLOAD,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=8),
                    ),
                    on_click=lambda e, m_info=mod_info: asyncio.create_task(
                        self._start_download_action(page, m_info)
                    ),
                )
            )

        return ft.Container(
            content=ft.Row(
                controls=[
                    ft.Container(
                        content=ft.Icon(icon_data, size=24, color=icon_color),
                        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                        border_radius=10,
                        padding=ft.Padding.all(10),
                    ),
                    ft.Column(
                        controls=[
                            ft.Text(title, size=15, weight=ft.FontWeight.W_600),
                            ft.Text(subtitle, size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    ft.Row(
                        controls=action_controls,
                        spacing=6,
                        alignment=ft.MainAxisAlignment.END,
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            border_radius=12,
            padding=ft.Padding.symmetric(horizontal=12, vertical=10),
        )

    async def _start_download_action(
        self, page: ft.Page, mod_info: dict[str, Any]
    ) -> None:
        """Inicia o download e descompactação de um módulo."""
        mod_id = str(mod_info.get("id", ""))
        if mod_id in self.downloading_ids:
            return

        self.downloading_ids.add(mod_id)
        self.download_progress[mod_id] = 0.0
        self._rebuild_module_lists(page)

        def _progress_callback(val: float) -> None:
            self.download_progress[mod_id] = val
            self._rebuild_module_lists(page)

        try:
            await self.content_manager.download_module(
                module_info=mod_info,
                on_progress=_progress_callback,
                page=page,
            )
            title, _ = self._get_module_title_and_subtitle(mod_id, mod_info)
            self._show_snackbar(page, f"Módulo '{title}' instalado com sucesso!")
        except asyncio.CancelledError:
            self._show_snackbar(page, f"Download de '{mod_id}' cancelado.", is_error=True)
            raise
        except Exception:
            self._show_snackbar(
                page,
                f"Erro ao baixar módulo '{mod_id}': verifique sua conexão.",
                is_error=True,
            )
        finally:
            self.downloading_ids.discard(mod_id)
            self.download_progress.pop(mod_id, None)
            self._refresh_storage_text()
            self._rebuild_module_lists(page)

    async def _delete_module_action(self, page: ft.Page, mod_id: str) -> None:
        """Exclui um módulo instalado."""
        try:
            success = await self.content_manager.delete_module(mod_id, page=page)
            if success:
                self._show_snackbar(page, f"Módulo '{mod_id}' excluído com sucesso.")
            else:
                self._show_snackbar(page, f"Módulo '{mod_id}' não encontrado.", is_error=True)
        except Exception as exc:
            self._show_snackbar(
                page, f"Erro ao excluir '{mod_id}': {exc}", is_error=True
            )
        finally:
            self._refresh_storage_text()
            self._rebuild_module_lists(page)

    def _rebuild_module_lists(self, page: ft.Page) -> None:
        """Atualiza os controles das listas de hinários e bíblias na interface."""
        modules = self.manifest_data.get("modules", [])

        hinarios_controls: list[ft.Control] = []
        biblias_controls: list[ft.Control] = []

        for m in modules:
            m_id = str(m.get("id", ""))
            # Oculta o hinário novo da lista de downloads pois ele é o padrão embutido
            if m_id == "hinario":
                continue

            card = self._build_module_card(page, m)
            if m_id in ("hinario_antigo", "hinario_comparativo"):
                hinarios_controls.append(card)
            else:
                biblias_controls.append(card)

        if not hinarios_controls:
            hinarios_controls.append(
                ft.Text("Nenhum hinário secundário disponível.", italic=True, size=13)
            )
        if not biblias_controls:
            biblias_controls.append(
                ft.Text("Nenhuma tradução bíblica disponível.", italic=True, size=13)
            )

        self.hinarios_column.controls = hinarios_controls
        self.biblias_column.controls = biblias_controls
        try:
            page.update()
        except Exception:
            pass

    async def _load_manifest_and_render(self, page: ft.Page, force_refresh: bool = False) -> None:
        """Busca o manifesto e recarrega a UI."""
        self.loading_indicator.visible = True
        try:
            page.update()
        except Exception:
            pass

        try:
            self.manifest_data = await self.content_manager.get_manifest(
                force_refresh=force_refresh
            )
        except Exception:
            pass

        if self.escola_sabatina_service and hasattr(self.escola_sabatina_service, "repository"):
            try:
                self.escola_sabatina_summaries = (
                    await self.escola_sabatina_service.repository.get_cached_quarterlies_summary()
                )
            except Exception:
                self.escola_sabatina_summaries = []

        self.loading_indicator.visible = False
        self._refresh_storage_text()
        self._rebuild_module_lists(page)
        self._rebuild_escola_sabatina_list(page)

    def _rebuild_escola_sabatina_list(self, page: ft.Page) -> None:
        """Atualiza a lista de trimestres da Escola Sabatina na interface."""
        if not self.escola_sabatina_service:
            self.escola_sabatina_column.controls = [
                ft.Text("Serviço da Escola Sabatina não inicializado.", italic=True, size=13)
            ]
            try:
                page.update()
            except Exception:
                pass
            return

        controls: list[ft.Control] = []
        if self.escola_sabatina_summaries:
            for s in self.escola_sabatina_summaries:
                controls.append(self._build_escola_sabatina_card(page, s))
        else:
            controls.append(
                ft.Container(
                    content=ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.INFO_OUTLINE, size=18, color=ft.Colors.ON_SURFACE_VARIANT),
                            ft.Text(
                                "Nenhuma lição salva no cache local. Acesse a Escola Sabatina para baixar lições.",
                                size=13,
                                italic=True,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                expand=True,
                            ),
                        ],
                        spacing=8,
                    ),
                    padding=ft.Padding.symmetric(vertical=6),
                )
            )

        self.escola_sabatina_column.controls = controls
        try:
            page.update()
        except Exception:
            pass

    def _build_escola_sabatina_card(
        self, page: ft.Page, summary: dict[str, Any]
    ) -> ft.Container:
        """Constrói o card de um trimestre da Escola Sabatina."""
        q_id = str(summary.get("quarterly_id", ""))
        q_title = str(summary.get("title", "")) or q_id
        lessons_count = int(summary.get("lessons_count", 0))
        days_count = int(summary.get("days_count", 0))
        size_bytes = int(summary.get("estimated_size_bytes", 0))

        subtitle = f"{lessons_count} de 13 lições salvas ({days_count} dias) • {self._format_size(size_bytes)}"

        action_controls: list[ft.Control] = [
            ft.IconButton(
                icon=ft.Icons.TUNE_ROUNDED,
                tooltip="Gerenciar lições deste trimestre",
                on_click=lambda e, qid=q_id, qtit=q_title: asyncio.create_task(
                    self._show_manage_quarterly_sheet(page, qid, qtit)
                ),
            ),
        ]

        if lessons_count < 13:
            action_controls.append(
                ft.FilledTonalButton(
                    "Baixar Restante",
                    icon=ft.Icons.DOWNLOAD_FOR_OFFLINE_ROUNDED,
                    tooltip="Baixar lições que faltam",
                    style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=8)),
                    on_click=lambda e, qid=q_id, qtit=q_title: asyncio.create_task(
                        self._download_entire_quarter_action(page, qid, qtit)
                    ),
                )
            )

        action_controls.append(
            ft.IconButton(
                icon=ft.Icons.DELETE_OUTLINE,
                icon_color=ft.Colors.RED_400,
                tooltip=f"Excluir lições de {q_title}",
                on_click=lambda e, qid=q_id, qtit=q_title: self._show_delete_quarterly_dialog(
                    page, qid, qtit
                ),
            )
        )

        return ft.Container(
            content=ft.Row(
                controls=[
                    ft.Container(
                        content=ft.Icon(ft.Icons.AUTO_STORIES, size=24, color=ft.Colors.AMBER_400),
                        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                        border_radius=10,
                        padding=ft.Padding.all(10),
                    ),
                    ft.Column(
                        controls=[
                            ft.Text(
                                q_title,
                                size=15,
                                weight=ft.FontWeight.W_600,
                                max_lines=1,
                                overflow=ft.TextOverflow.ELLIPSIS,
                            ),
                            ft.Text(subtitle, size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    ft.Row(
                        controls=action_controls,
                        spacing=4,
                        alignment=ft.MainAxisAlignment.END,
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            border_radius=12,
            padding=ft.Padding.symmetric(horizontal=12, vertical=10),
            ink=True,
            on_click=lambda e, qid=q_id, qtit=q_title: asyncio.create_task(
                self._show_manage_quarterly_sheet(page, qid, qtit)
            ),
        )

    def _show_delete_quarterly_dialog(self, page: ft.Page, q_id: str, q_title: str) -> None:
        """Exibe modal confirmando exclusão do trimestre com opção de manter notas."""
        def _close():
            try:
                page.pop_dialog()
            except Exception:
                pass

        async def _do_delete(keep_user_data: bool):
            _close()
            if not self.escola_sabatina_service:
                return
            try:
                await self.escola_sabatina_service.delete_quarterly_cache(
                    q_id, keep_user_data=keep_user_data
                )
                msg = (
                    f"Lições de '{q_title}' excluídas (anotações preservadas)."
                    if keep_user_data
                    else f"Lições e anotações de '{q_title}' excluídas."
                )
                self._show_snackbar(page, msg)
            except Exception as ex:
                self._show_snackbar(page, f"Erro ao excluir lições: {ex}", is_error=True)
            finally:
                await self._load_manifest_and_render(page)

        dlg = ft.AlertDialog(
            title=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.DELETE_FOREVER_ROUNDED, color=ft.Colors.RED_400),
                    ft.Text("Excluir Lições Salvas", weight=ft.FontWeight.BOLD),
                ],
                spacing=8,
            ),
            content=ft.Column(
                controls=[
                    ft.Text(f"Deseja excluir as lições baixadas de '{q_title}'?"),
                    ft.Text(
                        "Você pode optar por manter suas notas, respostas e marcações de estudo.",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                ],
                tight=True,
                spacing=6,
            ),
            actions=[
                ft.TextButton("Cancelar", on_click=lambda e: _close()),
                ft.OutlinedButton(
                    "Apagar Tudo",
                    style=ft.ButtonStyle(color=ft.Colors.RED_400),
                    on_click=lambda e: asyncio.create_task(_do_delete(keep_user_data=False)),
                ),
                ft.FilledButton(
                    "Manter Notas",
                    on_click=lambda e: asyncio.create_task(_do_delete(keep_user_data=True)),
                ),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        try:
            page.show_dialog(dlg)
        except Exception:
            page.overlay.append(dlg)
            dlg.open = True
            try:
                page.update()
            except Exception:
                pass

    def _show_delete_lesson_dialog(
        self, page: ft.Page, lesson_id: str, lesson_title: str, on_done=None
    ) -> None:
        """Exibe modal confirmando exclusão de uma única lição."""
        def _close():
            try:
                page.pop_dialog()
            except Exception:
                pass

        async def _do_delete(keep_user_data: bool):
            _close()
            if not self.escola_sabatina_service:
                return
            try:
                await self.escola_sabatina_service.delete_lesson_cache(
                    lesson_id, keep_user_data=keep_user_data
                )
                msg = (
                    f"Lição '{lesson_title}' excluída (anotações preservadas)."
                    if keep_user_data
                    else f"Lição '{lesson_title}' excluída."
                )
                self._show_snackbar(page, msg)
            except Exception as ex:
                self._show_snackbar(page, f"Erro ao excluir lição: {ex}", is_error=True)
            finally:
                if on_done:
                    await on_done()
                await self._load_manifest_and_render(page)

        dlg = ft.AlertDialog(
            title=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.DELETE_OUTLINE, color=ft.Colors.RED_400),
                    ft.Text("Excluir Lição", weight=ft.FontWeight.BOLD),
                ],
                spacing=8,
            ),
            content=ft.Column(
                controls=[
                    ft.Text(f"Deseja excluir a lição '{lesson_title}' do cache offline?"),
                    ft.Text(
                        "Deseja manter suas anotações e respostas desta lição?",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                ],
                tight=True,
                spacing=6,
            ),
            actions=[
                ft.TextButton("Cancelar", on_click=lambda e: _close()),
                ft.OutlinedButton(
                    "Apagar Tudo",
                    style=ft.ButtonStyle(color=ft.Colors.RED_400),
                    on_click=lambda e: asyncio.create_task(_do_delete(keep_user_data=False)),
                ),
                ft.FilledButton(
                    "Manter Notas",
                    on_click=lambda e: asyncio.create_task(_do_delete(keep_user_data=True)),
                ),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        try:
            page.show_dialog(dlg)
        except Exception:
            page.overlay.append(dlg)
            dlg.open = True
            try:
                page.update()
            except Exception:
                pass

    async def _show_manage_quarterly_sheet(
        self, page: ft.Page, quarterly_id: str, quarterly_title: str
    ) -> None:
        """Exibe Bottom Sheet com as lições do trimestre para gerenciar downloads individuais."""
        if not self.escola_sabatina_service:
            return

        lessons = []
        try:
            lessons = await self.escola_sabatina_service.get_lessons(quarterly_id)
        except Exception:
            pass

        if not lessons:
            self._show_snackbar(page, "Não foi possível carregar as lições deste trimestre.", is_error=True)
            return

        async def _reload_sheet():
            try:
                page.pop_dialog()
            except Exception:
                pass
            await self._show_manage_quarterly_sheet(page, quarterly_id, quarterly_title)

        lesson_rows: list[ft.Control] = []
        for idx, l in enumerate(lessons):
            if hasattr(self.escola_sabatina_service, "is_lesson_cached"):
                is_cached = await self.escola_sabatina_service.is_lesson_cached(l.id)
            elif hasattr(self.escola_sabatina_service, "is_lesson_downloaded"):
                is_cached = await self.escola_sabatina_service.is_lesson_downloaded(l.id)
            elif hasattr(self.escola_sabatina_service, "repository") and hasattr(
                self.escola_sabatina_service.repository, "is_lesson_cached"
            ):
                is_cached = await self.escola_sabatina_service.repository.is_lesson_cached(l.id)
            else:
                is_cached = False
            idx_str = str(idx + 1).zfill(2)
            title = l.title or f"Lição {idx_str}"
            date_range = f"{l.start_date} a {l.end_date}" if l.start_date else ""

            if is_cached:
                trailing = ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Row(
                                [
                                    ft.Icon(ft.Icons.CHECK_CIRCLE, size=15, color=ft.Colors.GREEN_400),
                                    ft.Text("Salva", size=11, color=ft.Colors.GREEN_400, weight=ft.FontWeight.BOLD),
                                ],
                                spacing=4,
                            ),
                            padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                            border_radius=6,
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                        ),
                        ft.IconButton(
                            icon=ft.Icons.DELETE_OUTLINE,
                            icon_color=ft.Colors.RED_400,
                            tooltip="Excluir lição",
                            on_click=lambda e, lid=l.id, ltit=title: self._show_delete_lesson_dialog(
                                page, lid, ltit, on_done=_reload_sheet
                            ),
                        ),
                    ],
                    spacing=2,
                )
            else:
                trailing = ft.FilledTonalButton(
                    "Baixar",
                    icon=ft.Icons.DOWNLOAD,
                    style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=8)),
                    on_click=lambda e, lid=l.id, ltit=title: asyncio.create_task(
                        self._download_lesson_action(page, lid, quarterly_id, ltit, on_done=_reload_sheet)
                    ),
                )

            row = ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Text(idx_str, size=12, weight=ft.FontWeight.BOLD),
                            width=28,
                            height=28,
                            border_radius=6,
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                            alignment=ft.Alignment.CENTER,
                        ),
                        ft.Column(
                            controls=[
                                ft.Text(
                                    title,
                                    size=13,
                                    weight=ft.FontWeight.W_500,
                                    max_lines=1,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                                ft.Text(date_range, size=11, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            spacing=1,
                            expand=True,
                        ),
                        trailing,
                    ],
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=8,
                ),
                bgcolor=ft.Colors.SURFACE_CONTAINER_LOW,
                border_radius=8,
                padding=ft.Padding.symmetric(horizontal=10, vertical=6),
            )
            lesson_rows.append(row)

        bs = ft.BottomSheet(
            scrollable=True,
            show_drag_handle=True,
            use_safe_area=True,
            maintain_bottom_view_insets_padding=True,
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.AUTO_STORIES_ROUNDED, color=ft.Colors.PRIMARY, size=20),
                                ft.Text(
                                    quarterly_title,
                                    weight=ft.FontWeight.BOLD,
                                    size=15,
                                    expand=True,
                                    max_lines=1,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                                ft.IconButton(
                                    ft.Icons.CLOSE,
                                    tooltip="Fechar",
                                    on_click=lambda ev: page.pop_dialog() if hasattr(page, "pop_dialog") else None,
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1),
                        ft.FilledTonalButton(
                            "Baixar Todas as Lições Deste Trimestre",
                            icon=ft.Icons.DOWNLOAD_FOR_OFFLINE_ROUNDED,
                            style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=8)),
                            on_click=lambda e: (
                                page.pop_dialog() if hasattr(page, "pop_dialog") else None,
                                asyncio.create_task(
                                    self._download_entire_quarter_action(page, quarterly_id, quarterly_title)
                                ),
                            ),
                        ),
                        ft.Container(
                            content=ft.Column(controls=lesson_rows, spacing=4, scroll=ft.ScrollMode.AUTO),
                            expand=True,
                        ),
                    ],
                    spacing=8,
                    tight=True,
                ),
                padding=ft.Padding.all(16),
            ),
        )

        try:
            page.show_dialog(bs)
        except Exception:
            page.overlay.append(bs)
            bs.open = True
            try:
                page.update()
            except Exception:
                pass

    def _show_download_progress_modal(self, page: ft.Page, title: str):
        bar = ft.ProgressBar(value=0.0, width=260)
        status = ft.Text("Preparando download...", size=12, color=ft.Colors.ON_SURFACE_VARIANT)
        dlg = ft.AlertDialog(
            modal=True,
            title=ft.Row(
                [
                    ft.Icon(ft.Icons.DOWNLOAD_ROUNDED, color=self._get_accent_color()),
                    ft.Text(title, weight=ft.FontWeight.BOLD, size=15),
                ],
                spacing=8,
            ),
            content=ft.Column(
                [status, bar],
                spacing=10,
                tight=True,
                width=280,
            ),
        )

        def update_fn(pct: float, text: str = ""):
            bar.value = max(0.0, min(1.0, pct))
            if text:
                status.value = text
            try:
                page.update()
            except Exception:
                pass

        def close_fn():
            try:
                page.pop_dialog()
            except Exception:
                dlg.open = False
                try:
                    page.update()
                except Exception:
                    pass

        try:
            page.show_dialog(dlg)
        except Exception:
            page.overlay.append(dlg)
            dlg.open = True
            try:
                page.update()
            except Exception:
                pass

        return update_fn, close_fn

    async def _download_lesson_action(
        self, page: ft.Page, lesson_id: str, quarterly_id: str, title: str, on_done=None
    ) -> None:
        if not self.escola_sabatina_service:
            return
        update_fn, close_fn = self._show_download_progress_modal(page, f"Baixando {title}")
        try:
            success = await self.escola_sabatina_service.download_week_lesson(
                quarterly_id=quarterly_id,
                lesson_id=lesson_id,
                progress_callback=lambda pct, msg: update_fn(pct, msg),
            )
            if success:
                self._show_snackbar(page, f"Lição '{title}' salva off-line!")
            else:
                self._show_snackbar(page, "Erro ao baixar lição. Verifique a conexão.", is_error=True)
        except Exception as e:
            self._show_snackbar(page, f"Falha no download: {e}", is_error=True)
        finally:
            close_fn()
            if on_done:
                await on_done()
            await self._load_manifest_and_render(page)

    async def _download_entire_quarter_action(
        self, page: ft.Page, quarterly_id: str, title: str
    ) -> None:
        if not self.escola_sabatina_service:
            return
        update_fn, close_fn = self._show_download_progress_modal(page, f"Baixando {title}")
        try:
            success = await self.escola_sabatina_service.download_entire_quarter(
                quarterly_id=quarterly_id,
                progress_callback=lambda pct, msg: update_fn(pct, msg),
            )
            if success:
                self._show_snackbar(page, f"Trimestre '{title}' salvo com sucesso!")
            else:
                self._show_snackbar(page, "Erro ao baixar trimestre.", is_error=True)
        except Exception as e:
            self._show_snackbar(page, f"Falha no download: {e}", is_error=True)
        finally:
            close_fn()
            await self._load_manifest_and_render(page)

    def build(self, page: ft.Page) -> ft.View:
        """Constrói a View do Gerenciador de Downloads."""
        self.page = page

        if self.theme_service:
            self.theme_service.apply_theme(page)

        self._refresh_storage_text()

        # Dispara carregamento assíncrono do manifesto se houver event loop ativo
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self._load_manifest_and_render(page))
        except RuntimeError:
            pass

        async def _go_back(e):
            if hasattr(page, "on_view_pop") and page.on_view_pop:
                res = page.on_view_pop(None)
                if inspect.isawaitable(res):
                    await res
            elif len(page.views) > 1:
                page.views.pop()
                top_view = page.views[-1]
                await page.push_route(top_view.route)
            else:
                await page.push_route("/")

        # Cabeçalho com estatísticas de armazenamento
        header_card = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.STORAGE, size=24, color=self._get_accent_color()),
                    ft.Column(
                        controls=[
                            ft.Text(
                                "Armazenamento de Módulos",
                                weight=ft.FontWeight.BOLD,
                                size=14,
                            ),
                            self.storage_summary_text,
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    self.loading_indicator,
                    ft.IconButton(
                        icon=ft.Icons.REFRESH,
                        tooltip="Atualizar Manifesto da Nuvem",
                        on_click=lambda e: asyncio.create_task(
                            self._load_manifest_and_render(page, force_refresh=True)
                        ),
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=12,
            padding=ft.Padding.all(14),
        )

        content_column = ft.Column(
            controls=[
                header_card,
                ft.Container(height=8),
                # Seção Hinários
                ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.LIBRARY_MUSIC, size=20, color=ft.Colors.PRIMARY),
                        ft.Text(
                            "Hinários Secundários",
                            size=16,
                            weight=ft.FontWeight.BOLD,
                        ),
                    ],
                    spacing=8,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                ft.Text(
                    "Baixe o Hinário Tradicional e o Comparativo histórico.",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Container(height=4),
                self.hinarios_column,
                ft.Container(height=16),
                # Seção Bíblias
                ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.MENU_BOOK, size=20, color=ft.Colors.SECONDARY),
                        ft.Text(
                            "Traduções da Bíblia Sagrada",
                            size=16,
                            weight=ft.FontWeight.BOLD,
                        ),
                    ],
                    spacing=8,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                ft.Text(
                    "Baixe traduções completas para leitura integral e pesquisa off-line.",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Container(height=4),
                self.biblias_column,
                ft.Container(height=16),
                # Seção Escola Sabatina
                ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.AUTO_STORIES, size=20, color=ft.Colors.AMBER_400),
                        ft.Text(
                            "Lições da Escola Sabatina",
                            size=16,
                            weight=ft.FontWeight.BOLD,
                        ),
                    ],
                    spacing=8,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                ft.Text(
                    "Gerencie e baixe lições trimestrais para estudo e leitura off-line.",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Container(height=4),
                self.escola_sabatina_column,
            ],
            scroll=ft.ScrollMode.AUTO,
            spacing=6,
            expand=True,
        )

        return ft.View(
            route="/downloads",
            bgcolor=ft.Colors.SURFACE,
            appbar=ft.AppBar(
                leading=ft.IconButton(ft.Icons.ARROW_BACK, on_click=_go_back),
                title=ft.Text("Módulos & Downloads", weight=ft.FontWeight.BOLD),
                center_title=True,
                bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Container(
                        content=content_column,
                        padding=ft.Padding.symmetric(horizontal=16, vertical=12),
                        expand=True,
                    ),
                    expand=True,
                )
            ],
        )
