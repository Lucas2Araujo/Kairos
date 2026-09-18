"""
Modal / Dialog de Boas-vindas (Welcome Flow / Onboarding) - Kairós.

Exibido automaticamente na primeira inicialização do app quando o usuário não possui dados,
ou manualmente através do botão "Exibir diálogo de boas-vindas novamente" no modal de configurações.

Permite:
1. Conhecer os principais recursos do app (Hinários 2022/1996, Bíblia, Meditação Diária, Offline).
2. Experimentar ou configurar o tema visual (Material You, Liquid Glass, Modo Escuro/Claro).
3. Realizar o primeiro Login com Google (OAuth) para sincronização na nuvem.
4. Concluir e começar a usar o aplicativo, persistindo a flag de onboarding concluído.
"""

from __future__ import annotations

import asyncio
import inspect
import logging
from typing import Any, Callable

import flet as ft

from src.services.auth_service import AuthService
from src.services.theme_service import ThemeService
from src.utils.storage_manager import storage_get, storage_set

logger = logging.getLogger(__name__)

STORAGE_KEY_ONBOARDING_COMPLETED = "onboarding_completed"


async def is_onboarding_completed(page: ft.Page) -> bool:
    """Verifica se o usuário já passou pelo fluxo de boas-vindas."""
    val = await storage_get(page, STORAGE_KEY_ONBOARDING_COMPLETED, default=False)
    return bool(val)


async def set_onboarding_completed(page: ft.Page, completed: bool = True) -> None:
    """Define se o onboarding já foi realizado pelo usuário."""
    await storage_set(page, STORAGE_KEY_ONBOARDING_COMPLETED, completed)


class WelcomeDialogController:
    """Controlador do diálogo/modal de boas-vindas com personalização e autenticação inicial."""

    def __init__(
        self,
        page: ft.Page,
        theme_service: ThemeService,
        auth_service: AuthService | None = None,
        on_complete: Callable[[], Any] | None = None,
    ):
        self.page = page
        self.theme_service = theme_service
        self.auth_service = auth_service or AuthService()
        self.on_complete = on_complete
        self.dialog: ft.BottomSheet | None = None
        self.selected_category: str = "jovem"

        # Controles reativos de Auth
        self.auth_status_column: ft.Column | None = None

    def _close_dialog(self) -> None:
        if self.dialog:
            self.dialog.open = False
            try:
                self.dialog.update()
            except Exception:
                pass
        try:
            if hasattr(self.page, "pop_dialog"):
                self.page.pop_dialog()
        except Exception:
            pass

    async def _on_finish(self, _e=None) -> None:
        """Conclui o onboarding e fecha o modal."""
        await set_onboarding_completed(self.page, True)
        try:
            await storage_set(self.page, "preferred_devotional_category", self.selected_category)
        except Exception:
            pass
        self._close_dialog()
        if self.on_complete:
            if inspect.iscoroutinefunction(self.on_complete):
                await self.on_complete()
            else:
                self.on_complete()

    async def _trigger_google_login(self, _e=None) -> None:
        """Dispara o fluxo de login com Google OAuth."""
        success = await self.auth_service.initiate_google_login(self.page)
        if not success:
            snack = ft.SnackBar(
                content=ft.Text("Não foi possível abrir o login do Google no momento."),
                bgcolor=ft.Colors.RED_800,
            )
            if hasattr(self.page, "overlay"):
                self.page.overlay.append(snack)
            snack.open = True
            try:
                self.page.update()
            except Exception:
                pass

    def _build_auth_section(self) -> ft.Container:
        """Gera o card de convite ao login com Google no onboarding."""
        user = self.auth_service.get_current_user()
        is_logged = user is not None

        if is_logged:
            email = getattr(user, "email", "Usuário Autenticado")
            card_content = ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.CHECK_CIRCLE, color=ft.Colors.GREEN_600, size=24),
                            ft.Column(
                                controls=[
                                    ft.Text("Conta Conectada!", weight=ft.FontWeight.BOLD, size=14),
                                    ft.Text(email, size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                                ],
                                spacing=2,
                            ),
                        ],
                        spacing=10,
                    ),
                    ft.Text(
                        "Seus dados e preferências já estão sincronizados.",
                        size=11,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                ],
                spacing=8,
            )
        else:
            card_content = ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.CLOUD_SYNC_OUTLINED, color=ft.Colors.PRIMARY, size=24),
                            ft.Text(
                                "Sincronização na Nuvem",
                                weight=ft.FontWeight.BOLD,
                                size=14,
                                color=ft.Colors.PRIMARY,
                            ),
                        ],
                        spacing=8,
                    ),
                    ft.Text(
                        "Faça login com sua conta Google para salvar seus favoritos, anotações e histórico entre dispositivos.",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                    ft.FilledTonalButton(
                        "Entrar com o Google",
                        icon=ft.Icons.G_MOBILEDATA,
                        style=ft.ButtonStyle(
                            shape=ft.RoundedRectangleBorder(radius=10),
                        ),
                        on_click=lambda _e: asyncio.create_task(self._trigger_google_login()),
                    ),
                ],
                spacing=10,
            )

        return ft.Container(
            content=card_content,
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            border_radius=12,
            padding=ft.Padding.all(14),
        )

    def _build_features_overview(self) -> ft.Column:
        """Lista os 4 pilares do aplicativo."""
        items = [
            (
                ft.Icons.LIBRARY_MUSIC,
                "Dois Hinários Integrados",
                "Alterne facilmente entre o Hinário Novo (2022) e o Tradicional (1996) com letras completas.",
            ),
            (
                ft.Icons.MENU_BOOK,
                "Bíblia Sagrada & Versículos",
                "Consulte versículos de apoio com um clique sem sair da letra do hino.",
            ),
            (
                ft.Icons.AUTO_AWESOME,
                "Agente de Culto Inteligente",
                "Planeje cultos e recepções com sugestões litúrgicas automáticas de hinos.",
            ),
            (
                ft.Icons.WIFI_OFF,
                "Offline-First",
                "Acesse hinos, meditações diárias e áudios baixados mesmo sem internet.",
            ),
        ]

        controls: list[ft.Control] = []
        for icon, title, desc in items:
            controls.append(
                ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Icon(icon, size=22, color=ft.Colors.PRIMARY),
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                            border_radius=10,
                            padding=ft.Padding.all(8),
                        ),
                        ft.Column(
                            controls=[
                                ft.Text(title, weight=ft.FontWeight.BOLD, size=13),
                                ft.Text(desc, size=11, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            spacing=2,
                            expand=True,
                        ),
                    ],
                    spacing=12,
                    vertical_alignment=ft.CrossAxisAlignment.START,
                )
            )
        return ft.Column(controls=controls, spacing=12)

    def _build_devotional_preference_section(self) -> ft.Container:
        """Card interativo para selecionar o devocional diário preferido."""
        def _on_cat_change(e: ft.ControlEvent):
            if e.control.value:
                self.selected_category = str(e.control.value)

        radio_group = ft.RadioGroup(
            content=ft.Row(
                controls=[
                    ft.Radio(value="jovem", label="Jovem"),
                    ft.Radio(value="diario", label="Diário"),
                    ft.Radio(value="mulher", label="Mulher"),
                ],
                spacing=10,
                alignment=ft.MainAxisAlignment.START,
            ),
            value=self.selected_category,
            on_change=_on_cat_change,
        )

        return ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.FAVORITE_ROUNDED, color=ft.Colors.PRIMARY, size=20),
                            ft.Text(
                                "Meditação Diária de Preferência",
                                weight=ft.FontWeight.BOLD,
                                size=13,
                                color=ft.Colors.PRIMARY,
                            ),
                        ],
                        spacing=8,
                    ),
                    ft.Text(
                        "Qual devocional você prefere receber em destaque diariamente?",
                        size=11,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                    ),
                    radio_group,
                ],
                spacing=6,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
            border_radius=12,
            padding=ft.Padding.all(12),
        )

    def build_bottom_sheet(self) -> ft.BottomSheet:
        """Monta o BottomSheet moderno de boas-vindas."""
        header = ft.Row(
            controls=[
                ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Icon(ft.Icons.AUTO_AWESOME, color=ft.Colors.PRIMARY, size=24),
                            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                            border_radius=10,
                            padding=ft.Padding.all(6),
                        ),
                        ft.Column(
                            controls=[
                                ft.Text("Bem-vindo ao Kairós!", weight=ft.FontWeight.BOLD, size=18),
                                ft.Text("Tempo de qualidade com Deus — Seu companheiro diário de adoração, comunhão e louvor", size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                            ],
                            spacing=1,
                        ),
                    ],
                    spacing=10,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                ),
                ft.IconButton(
                    ft.Icons.CLOSE,
                    tooltip="Fechar",
                    on_click=lambda _e: asyncio.create_task(self._on_finish()),
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        )

        content = ft.Column(
            controls=[
                header,
                ft.Divider(height=1),
                ft.Container(height=4),
                self._build_features_overview(),
                ft.Container(height=6),
                self._build_devotional_preference_section(),
                ft.Container(height=6),
                self._build_auth_section(),
                ft.Container(height=10),
                ft.FilledButton(
                    "Começar a Usar o Aplicativo",
                    icon=ft.Icons.ARROW_FORWARD,
                    style=ft.ButtonStyle(
                        shape=ft.RoundedRectangleBorder(radius=12),
                    ),
                    on_click=lambda _e: asyncio.create_task(self._on_finish()),
                    width=400,
                ),
            ],
            spacing=10,
            scroll=ft.ScrollMode.AUTO,
            tight=True,
        )

        self.dialog = ft.BottomSheet(
            scrollable=True,
            show_drag_handle=True,
            use_safe_area=True,
            maintain_bottom_view_insets_padding=True,
            content=ft.Container(
                content=content,
                padding=ft.Padding.only(left=20, top=10, right=20, bottom=30),
            ),
        )
        return self.dialog


def show_welcome_dialog(
    page: ft.Page,
    theme_service: ThemeService,
    auth_service: AuthService | None = None,
    on_complete: Callable[[], Any] | None = None,
) -> None:
    """Exibe o diálogo de boas-vindas na tela."""
    if not page:
        return
    controller = WelcomeDialogController(
        page=page,
        theme_service=theme_service,
        auth_service=auth_service,
        on_complete=on_complete,
    )
    dialog = controller.build_bottom_sheet()
    try:
        page.show_dialog(dialog)
    except Exception as ex:
        logger.warning(f"Erro ao exibir modal de boas-vindas: {ex}")
