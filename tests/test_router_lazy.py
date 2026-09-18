from unittest.mock import AsyncMock, MagicMock
import flet as ft
import pytest

from main import AppRouter, AppViews


@pytest.mark.asyncio
async def test_app_router_caches_selecao_view():
    mock_page = MagicMock(spec=ft.Page)
    mock_page.route = "/"
    mock_page.views = []

    mock_selecao_view = MagicMock()
    built_view = ft.View(route="/")
    mock_selecao_view.build.return_value = built_view

    views = AppViews(selecao_view=mock_selecao_view)

    router = AppRouter(
        page=mock_page,
        connections=(),
        views=views,
        content_manager=MagicMock(),
        media_service=MagicMock(),
        theme_service=MagicMock(),
        ctx_novo=MagicMock(),
        ctx_antigo=MagicMock(),
        biblia_repository=MagicMock(),
        comparativo_repository=MagicMock(),
    )

    # 1. Primeira navegação: constrói e armazena em cache
    await router.route_change()
    assert mock_selecao_view.build.call_count == 1
    assert router._cached_selecao_view is built_view

    # 2. Segunda navegação para "/": reaproveita a view do cache sem chamar build() novamente
    await router.route_change()
    assert mock_selecao_view.build.call_count == 1
    assert router.page.views[0] is built_view

    # 3. refresh_views() invalida o cache
    await router.refresh_views()
    # Ao invalidar, route_change é chamado internamente e reconstrói
    assert mock_selecao_view.build.call_count == 2


@pytest.mark.asyncio
async def test_app_router_lazy_instantiation_of_secondary_views():
    mock_page = MagicMock(spec=ft.Page)
    mock_page.route = "/"
    mock_page.views = []

    mock_selecao_view = MagicMock()
    mock_selecao_view.build.return_value = ft.View(route="/")

    mock_ctx_novo = MagicMock()
    mock_ctx_antigo = MagicMock()

    views = AppViews(selecao_view=mock_selecao_view)

    router = AppRouter(
        page=mock_page,
        connections=(),
        views=views,
        content_manager=MagicMock(),
        media_service=MagicMock(),
        theme_service=MagicMock(),
        ctx_novo=mock_ctx_novo,
        ctx_antigo=mock_ctx_antigo,
        biblia_repository=MagicMock(),
        comparativo_repository=MagicMock(),
    )

    # Na rota raiz "/", as views secundárias não devem ser instanciadas
    await router.route_change()
    assert router._home_novo is None
    assert router._home_antigo is None
    assert router._agente_view is None
    assert router._downloads_view is None
    assert router._biblia_view is None
    assert router._meditacao_view is None
    assert router._gerenciar_cache_view is None

    # Acesso à property instancia sob demanda
    hinos_novo = router.home_novo
    assert hinos_novo is not None
    assert router._home_novo is hinos_novo

    # Acesso repetido reaproveita a mesma instância
    assert router.home_novo is hinos_novo

