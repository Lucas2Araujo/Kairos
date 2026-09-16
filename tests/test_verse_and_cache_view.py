"""
Testes unitários para os componentes da Sprint 3:
- Parser de referências bíblicas e Verse Dialog (src/components/verse_dialog.py)
- View de Gerenciamento de Armazenamento/Cache (src/views/gerenciar_cache_view.py)
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock
import flet as ft
import pytest

from src.components.verse_dialog import (
    ParsedVerseRef,
    parse_verse_reference,
    show_verse_dialog,
)
from src.database.connection import DatabaseConnection
from src.database.devotional_repo import DevotionalRepository
from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService
from src.views.gerenciar_cache_view import (
    STORAGE_KEY_AUTO_CLEANUP,
    GerenciarCacheView,
)


def test_parse_verse_reference_multiple_formats():
    """Valida a extração resiliente de livro, capítulo e versículo com regex."""
    # 1. Livro com prefixo numérico
    ref1 = parse_verse_reference("1Pe 1:20")
    assert ref1.livro == "1Pe"
    assert ref1.capitulo == 1
    assert ref1.versiculo == 20

    # 2. Livro com prefixo e espaço
    ref2 = parse_verse_reference("1 Coríntios 13:4")
    assert ref2.livro == "1 Coríntios"
    assert ref2.capitulo == 13
    assert ref2.versiculo == 4

    # 3. Intervalo de versículos (deve capturar o versículo inicial)
    ref3 = parse_verse_reference("Jo 3:16-17")
    assert ref3.livro == "Jo"
    assert ref3.capitulo == 3
    assert ref3.versiculo == 16

    # 4. Formato com ponto ou vírgula
    ref4 = parse_verse_reference("Jr 29.11")
    assert ref4.livro == "Jr"
    assert ref4.capitulo == 29
    assert ref4.versiculo == 11

    # 5. Apenas livro e capítulo (default versículo 1)
    ref5 = parse_verse_reference("Gênesis 1")
    assert ref5.livro == "Gênesis"
    assert ref5.capitulo == 1
    assert ref5.versiculo == 1

    # 6. String vazia ou nula (fallback seguro)
    ref6 = parse_verse_reference("")
    assert ref6.livro == "Salmos"
    assert ref6.capitulo == 1
    assert ref6.versiculo == 1


def test_verse_dialog_rendering_and_navigation():
    """Verifica renderização do ft.AlertDialog e disparo da navegação com query params."""
    mock_page = MagicMock(spec=ft.Page)
    mock_page.go = MagicMock()
    mock_page.open = MagicMock()

    dlg = show_verse_dialog(
        page=mock_page,
        verse_text="O Senhor é o meu pastor, nada me faltará.",
        verse_reference="Sl 23:1",
    )

    assert isinstance(dlg, ft.AlertDialog)
    mock_page.open.assert_called_once()

    # Encontra o botão "Ler Capítulo Completo"
    read_button = None
    for act in dlg.actions:
        label = getattr(act, "text", None) or getattr(act, "content", None)
        if label and "Ler Capítulo" in str(label):
            read_button = act
            break

    assert read_button is not None
    # Simula clique no botão
    read_button.on_click(None)
    mock_page.go.assert_called_once_with("/biblia?livro=Sl&capitulo=23&versiculo=1")


@pytest.mark.asyncio
async def test_gerenciar_cache_view_lifecycle(in_memory_db: DatabaseConnection):
    """Valida o fluxo completo de carregamento, toggles e ações na GerenciarCacheView."""
    repo = DevotionalRepository(in_memory_db)
    service = DevotionalService(repository=repo)

    # Popula com 2 meditações
    dev1 = Devotional(
        published_at="2026-09-15",
        title="Meditação 1",
        verse_text="V1",
        verse_reference="Sl 1:1",
        content="Conteúdo 1",
    )
    dev2 = Devotional(
        published_at="2026-09-16",
        title="Meditação 2",
        verse_text="V2",
        verse_reference="Sl 2:1",
        content="Conteúdo 2",
    )
    await repo.save(dev1)
    await repo.save(dev2)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=True)
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.run_task = lambda fn, *args: None

    view_ctrl = GerenciarCacheView(devotional_service=service)
    built_view = await view_ctrl.build(mock_page)

    assert isinstance(built_view, ft.View)
    assert built_view.route == "/meditacoes/cache"

    # Carrega dados do cache
    await view_ctrl._load_cached_devotionals()
    assert len(view_ctrl.cached_items) == 2
    assert "2 meditações salvas" in view_ctrl.stats_text.value

    # Simula exclusão individual
    await view_ctrl._delete_single("2026-09-15")
    assert len(view_ctrl.cached_items) == 1
    assert "1 meditação salva" in view_ctrl.stats_text.value

    # Simula toggle de auto-cleanup
    mock_event = MagicMock(spec=ft.ControlEvent)
    mock_event.control = MagicMock()
    mock_event.control.value = False
    await view_ctrl._on_toggle_cleanup(mock_event)
    assert view_ctrl.auto_cleanup_enabled is False
    mock_page.client_storage.set_async.assert_called_with(
        STORAGE_KEY_AUTO_CLEANUP, False
    )

    # Simula limpeza total do cache
    await view_ctrl._clear_all_cache()
    assert len(view_ctrl.cached_items) == 0
    assert "0 meditações salvas" in view_ctrl.stats_text.value
