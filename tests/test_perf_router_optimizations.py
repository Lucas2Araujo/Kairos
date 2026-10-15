import pytest
import flet as ft
from unittest.mock import MagicMock, AsyncMock

from main import AppRouter, AppViews


@pytest.fixture
def mock_page():
    page = MagicMock(spec=ft.Page)
    page.route = "/"
    page.views = []
    page.overlay = []
    page.update = MagicMock()
    page.push_route = AsyncMock()
    return page


def _create_router(page):
    return AppRouter(
        page=page,
        connections=(),
        views=AppViews(),
        content_manager=MagicMock(),
        media_service=MagicMock(),
        theme_service=MagicMock(),
        ctx_novo=MagicMock(),
        ctx_antigo=MagicMock(),
        biblia_repository=MagicMock(),
        comparativo_repository=MagicMock(),
    )


def test_persistent_nav_bar_is_singleton(mock_page):
    """Garante que _build_persistent_nav_bar reutiliza a mesma instância e apenas atualiza o índice."""
    router = _create_router(mock_page)

    bar1 = router._build_persistent_nav_bar("/biblia")
    assert bar1.selected_index == 0
    assert router._persistent_nav_bar is bar1

    bar2 = router._build_persistent_nav_bar("/novo")
    assert bar2.selected_index == 1
    assert bar2 is bar1

    bar3 = router._build_persistent_nav_bar("/")
    assert bar3.selected_index == 2
    assert bar3 is bar1


def test_snackbars_encapsulation(mock_page):
    """Garante que snackbars são atributos de instância e não globais."""
    router = _create_router(mock_page)

    assert router._route_warning_snackbar is None
    router.show_route_warning("Aviso de teste")
    assert router._route_warning_snackbar is not None
    assert router._route_warning_snackbar in mock_page.overlay
    assert router._route_warning_snackbar.open is True

    assert router._auth_feedback_snackbar is None
    router.show_feedback_snackbar("Sucesso!", bgcolor=ft.Colors.GREEN_700)
    assert router._auth_feedback_snackbar is not None
    assert router._auth_feedback_snackbar in mock_page.overlay
    assert router._auth_feedback_snackbar.open is True


@pytest.mark.asyncio
async def test_route_change_preserves_query_on_refresh(mock_page):
    """Garante que ao chamar route_change(None) (como no refresh_views) a query string é preservada."""
    router = _create_router(mock_page)
    mock_selecao_view = MagicMock()
    mock_view = ft.View(route="/")
    mock_view.bottom_appbar = None
    mock_selecao_view.build.return_value = mock_view
    router._selecao_view = mock_selecao_view

    # Simula navegação com evento de rota contendo query params
    event = MagicMock()
    event.route = "/biblia?livro=1&cap=5"
    mock_page.route = "/biblia?livro=1&cap=5"
    router._render_biblia_route = AsyncMock()
    await router.route_change(event)

    assert router.current_tracked_route[0] == "/biblia?livro=1&cap=5"

    # Ao navegar com ?, page.route é sanitizado para /biblia
    assert mock_page.route == "/biblia"
    
    # Executa route_change(None) simulando refresh_views()
    await router.route_change(None)

    # Verifica se a rota passada para renderização manteve a query param original
    assert router._render_biblia_route.call_count == 2
    last_call = router._render_biblia_route.call_args[0]
    called_route_base, called_route, _ = last_call
    assert called_route_base == "/biblia"
    assert "livro=1&cap=5" in called_route
