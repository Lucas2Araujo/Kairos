"""
Testes unitários para a nova tela de Seleção de Lição Trimestral (TrimestresView).
1. Inicialização e montagem da view com capa e dados dos trimestres.
2. Alternância entre categorias Adultos e Jovens.
3. Seleção de trimestre e disparo de callback com redirecionamento de rota.
4. Roteamento em AppRouter para a rota /escola-sabatina/trimestres.
"""

from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import flet as ft
import pytest

from src.models.escola_sabatina import SSQuarterly
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.views.trimestres_view import TrimestresView
from main import AppRouter, AppViews, ROUTE_ESCOLA_SABATINA_TRIMESTRES


@pytest.fixture
def mock_quarterlies():
    return [
        SSQuarterly(
            id="2026-03-cq",
            title="Resgate: As cenas finais da vida de Cristo",
            description="Estudo sobre os momentos finais de Jesus.",
            human_date="Julho · Agosto · Setembro 2026",
            cover="https://example.com/cover1.png",
            category="jovens",
        ),
        SSQuarterly(
            id="2026-02-cq",
            title="Fortaleça seu relacionamento com Deus",
            description="Crescendo em comunhão.",
            human_date="Abril · Maio · Junho 2026",
            cover="https://example.com/cover2.png",
            category="jovens",
        ),
    ]


@pytest.mark.asyncio
async def test_trimestres_view_build_and_cards(mock_quarterlies):
    service = MagicMock(spec=EscolaSabatinaService)
    service.get_quarterlies = AsyncMock(return_value=mock_quarterlies)

    callback_mock = MagicMock()
    view = TrimestresView(
        service=service,
        category="jovens",
        on_quarterly_selected=callback_mock,
    )

    mock_page = MagicMock(spec=ft.Page)
    mock_page.width = 600
    mock_page.route = "/escola-sabatina/trimestres"
    mock_page.update = MagicMock()
    mock_page.run_task = MagicMock(side_effect=lambda fn, *args: asyncio.create_task(fn(*args)))

    flet_view = view.build(mock_page)

    assert isinstance(flet_view, ft.View)
    assert flet_view.route == "/escola-sabatina/trimestres"
    assert flet_view.appbar is not None
    assert flet_view.appbar.title.value == "Lições Trimestrais"

    # Carrega dados
    await view.load_quarterlies()
    assert len(view.quarterlies) == 2
    assert view.grid_container is not None

    # Verifica se os cards foram criados
    assert len(view.grid_container.controls) > 0


@pytest.mark.asyncio
async def test_trimestres_view_selection_and_callback(mock_quarterlies):
    service = MagicMock(spec=EscolaSabatinaService)
    service.get_quarterlies = AsyncMock(return_value=mock_quarterlies)

    callback_called_with = []

    async def _callback(qid: str):
        callback_called_with.append(qid)

    view = TrimestresView(
        service=service,
        category="jovens",
        on_quarterly_selected=_callback,
    )

    mock_page = MagicMock(spec=ft.Page)
    mock_page.width = 600
    mock_page.push_route = AsyncMock()
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    view.page = mock_page

    await view._select_quarterly(mock_quarterlies[0])

    assert callback_called_with == ["2026-03-cq"]
    assert mock_page.push_route.called
    assert mock_page.push_route.call_args[0][0] == "/escola-sabatina"


@pytest.mark.asyncio
async def test_trimestres_view_category_toggle(mock_quarterlies):
    service = MagicMock(spec=EscolaSabatinaService)
    service.get_quarterlies = AsyncMock(return_value=mock_quarterlies)

    view = TrimestresView(service=service, category="adultos")
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    view.page = mock_page
    view.grid_container = ft.Column()

    await view._on_category_change("jovens")
    assert view.category == "jovens"
    assert service.get_quarterlies.called
    set_calls = [c[0] for c in mock_page.client_storage.set_async.call_args_list]
    assert any("preferred_ss_type" in c and "jovens" in c for c in set_calls)
    assert any("preferred_ss_category" in c and "jovens" in c for c in set_calls)


@pytest.mark.asyncio
async def test_select_quarterly_starts_at_first_lesson():
    from src.models.escola_sabatina import SSLesson, SSDay
    from src.views.escola_sabatina_view import EscolaSabatinaView

    service = MagicMock(spec=EscolaSabatinaService)
    lessons = [
        SSLesson(id="01", quarterly_id="2026-01-cq", index="1", title="Lição 1", start_date="01/01/2026", end_date="07/01/2026"),
        SSLesson(id="02", quarterly_id="2026-01-cq", index="2", title="Lição 2", start_date="08/01/2026", end_date="14/01/2026"),
        SSLesson(id="13", quarterly_id="2026-01-cq", index="13", title="Lição 13", start_date="20/03/2026", end_date="27/03/2026"),
    ]
    service.get_quarterlies = AsyncMock(return_value=[
        SSQuarterly(id="2026-01-cq", title="Apologética", category="jovens")
    ])
    service.get_lessons = AsyncMock(return_value=lessons)
    service.get_lesson_days = AsyncMock(return_value=[
        SSDay(id="d1", lesson_id="01", title="Dia 1", date="01/01/2026")
    ])
    service.get_note = AsyncMock(return_value="")

    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    mock_page.update = MagicMock()
    view.page = mock_page

    await view.select_quarterly_by_id("2026-01-cq", start_at_first_lesson=True)

    # Verifica que iniciou na Lição 1 e não na última lição passada
    assert view.current_lesson is not None
    assert view.current_lesson.id == "01"


@pytest.mark.asyncio
async def test_trimestres_view_netflix_carousel_sections(mock_quarterlies):
    """Valida a renderização estilo Netflix das seções em carrossel para Adultos e Jovens."""
    service = MagicMock(spec=EscolaSabatinaService)
    service.get_quarterlies = AsyncMock(side_effect=lambda lang, category, force_refresh: (
        [mock_quarterlies[0]] if category == "adultos" else [mock_quarterlies[1]]
    ))

    view = TrimestresView(service=service, category="adultos")
    mock_page = MagicMock(spec=ft.Page)
    mock_page.update = MagicMock()
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    view.page = mock_page
    view.grid_container = ft.Column()

    await view.load_quarterlies(force_refresh=False)
    assert len(view.adultos_quarterlies) == 1
    assert len(view.jovens_quarterlies) == 1

    # Testa a geração do card em proporção ~1:1.4
    card = view._build_carousel_card(mock_quarterlies[0])
    assert isinstance(card, ft.Container)
    # Acessa a imagem na Stack do card
    stack = card.content.controls[0]
    img = stack.controls[0]
    assert isinstance(img, ft.Image)
    assert img.width == 120
    assert img.height == 168
    assert abs((img.height / img.width) - 1.4) < 0.05


