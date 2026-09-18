import asyncio
from unittest.mock import AsyncMock, MagicMock

import flet as ft
import pytest

from src.repositories.culto_repository import CultoRepository
from src.repositories.hino_repository import HinoRepository
from src.services.agente_service import AgenteService
from src.views.agente_view import AgenteView


def test_agente_view_build(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    culto_repo = CultoRepository(in_memory_db)
    agente_service = AgenteService(hino_repo)

    agente_view_obj = AgenteView(agente_service, culto_repo)
    mock_page = MagicMock(spec=ft.Page)

    view = agente_view_obj.build(mock_page)
    assert isinstance(view, ft.View)
    assert view.route == "/agente"
    assert len(view.controls) > 0
    assert isinstance(view.controls[0], ft.SafeArea)
    assert view.controls[0].maintain_bottom_view_padding is True
    assert agente_view_obj.tab_bar.show_selected_icon is False


@pytest.mark.asyncio
async def test_agente_view_busca_hino_debounce_and_cancel(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    hino_repo.search = AsyncMock(return_value=[])
    culto_repo = CultoRepository(in_memory_db)
    agente_service = AgenteService(hino_repo)
    agente_view_obj = AgenteView(agente_service, culto_repo)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.show_dialog = MagicMock()
    mock_page.pop_dialog = MagicMock()

    on_selected_mock = MagicMock()
    agente_view_obj._abrir_dialogo_busca_hino(mock_page, on_selected=on_selected_mock)

    assert mock_page.show_dialog.called
    dlg = mock_page.show_dialog.call_args[0][0]
    txt_busca = dlg.content.content.controls[0]

    # Simula digitação rápida de 4 caracteres ("D", "De", "Deu", "Deus")
    for val in ["D", "De", "Deu", "Deus"]:
        event = MagicMock()
        event.control.value = val
        txt_busca.on_change(event)
        await asyncio.sleep(0.05)  # 50ms interval < 250ms debounce

    # Aguarda o debounce de 250ms completar
    await asyncio.sleep(0.35)

    # hino_repo.search só deve ter sido chamado 1 vez com o termo final "Deus"
    assert hino_repo.search.call_count == 1
    hino_repo.search.assert_called_once_with("Deus")

