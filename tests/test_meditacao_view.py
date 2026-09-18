"""
Testes unitários para a Sprint 4:
- View Principal de Meditação Diária (src/views/meditacao_view.py)
- Integração de rotas em main.py
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock
import flet as ft
import pytest

from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService
from src.views.meditacao_view import (
    DEFAULT_CONTENT_FONT_SIZE,
    FONT_STEP,
    MAX_FONT_SIZE,
    MIN_FONT_SIZE,
    MeditacaoView,
)


@pytest.fixture
def mock_devotional_service():
    service = MagicMock(spec=DevotionalService)
    service.run_auto_cleanup = AsyncMock(return_value=1)
    service.get_devotional_for_date = AsyncMock()
    return service


@pytest.fixture
def mock_page():
    page = MagicMock(spec=ft.Page)
    page.client_storage = MagicMock()
    page.client_storage.get_async = AsyncMock(return_value=None)
    page.client_storage.set_async = AsyncMock()
    page.go = MagicMock()
    page.update = MagicMock()
    page.views = []
    page.route = "/meditacoes"
    page.run_task = MagicMock(side_effect=lambda fn, *args: None)
    return page


@pytest.mark.asyncio
async def test_meditacao_view_build_and_render_devotional(mock_devotional_service, mock_page):
    """Testa a construção da MeditacaoView com devocional carregado com sucesso."""
    today = date.today()
    dev = Devotional(
        published_at=today.isoformat(),
        title="Luz no Caminho",
        verse_text="Lâmpada para os meus pés é a tua palavra e luz para o meu caminho.",
        verse_reference="Salmos 119:105",
        content="Texto da meditação de hoje...",
        category="jovem",
    )
    mock_devotional_service.get_devotional.return_value = dev

    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    built_view = await view_instance.build(mock_page)

    assert isinstance(built_view, ft.View)
    assert built_view.route == "/meditacoes"
    assert built_view.appbar is not None

    # Executa o carregamento diretamente
    await view_instance._load_devotional_for_selected_date()
    assert view_instance.current_devotional == dev
    mock_devotional_service.get_devotional.assert_called_with(
        target_date=today.isoformat(),
        category="jovem",
        force_refresh=False,
    )


@pytest.mark.asyncio
async def test_meditacao_view_font_resizing(mock_devotional_service, mock_page):
    """Testa ajuste de fonte dinâmico (A+, A-, Reset) e limites."""
    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    await view_instance.build(mock_page)

    initial_size = view_instance.font_size
    assert initial_size == DEFAULT_CONTENT_FONT_SIZE

    # Aumenta fonte
    view_instance._change_font_size(FONT_STEP)
    assert view_instance.font_size == initial_size + FONT_STEP

    # Reset
    view_instance._reset_font_size()
    assert view_instance.font_size == DEFAULT_CONTENT_FONT_SIZE

    # Diminui abaixo do mínimo
    for _ in range(10):
        view_instance._change_font_size(-FONT_STEP)
    assert view_instance.font_size == MIN_FONT_SIZE

    # Aumenta acima do máximo
    for _ in range(20):
        view_instance._change_font_size(FONT_STEP)
    assert view_instance.font_size == MAX_FONT_SIZE


@pytest.mark.asyncio
async def test_meditacao_view_date_switch(mock_devotional_service, mock_page):
    """Testa a seleção de outro dia no carrossel de 7 dias."""
    yesterday = date.today() - timedelta(days=1)
    dev_yesterday = Devotional(
        published_at=yesterday.isoformat(),
        title="Ontem",
        verse_text="No princípio era o Verbo.",
        verse_reference="João 1:1",
        content="Texto de ontem...",
        category="jovem",
    )
    mock_devotional_service.get_devotional.return_value = dev_yesterday

    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    await view_instance.build(mock_page)

    view_instance._on_select_date(yesterday)
    assert view_instance.selected_date == yesterday

    await view_instance._load_devotional_for_selected_date()
    assert view_instance.current_devotional == dev_yesterday
    mock_devotional_service.get_devotional.assert_called_with(
        target_date=yesterday.isoformat(),
        category="jovem",
        force_refresh=False,
    )


@pytest.mark.asyncio
async def test_meditacao_view_offline_empty_state(mock_devotional_service, mock_page):
    """Testa o estado visual quando não há devocional e está offline."""
    mock_devotional_service.get_devotional.return_value = None

    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    await view_instance.build(mock_page)
    await view_instance._load_devotional_for_selected_date()

    assert view_instance.current_devotional is None
    # Verifica que o container de conteúdo renderizou a mensagem amigável
    container = view_instance.content_container.controls[0]
    inner_col = container.content
    texts = [c.value for c in inner_col.controls if isinstance(c, ft.Text)]
    assert any("indisponível" in t for t in texts)
    assert any("sem conexão" in t for t in texts)


@pytest.mark.asyncio
async def test_meditacao_view_category_switch(mock_devotional_service, mock_page):
    """Testa alternância de categoria entre jovem, diario e mulher."""
    dev_mulher = Devotional(
        published_at=date.today().isoformat(),
        title="Meditação Mulher Hoje",
        verse_text="Versículo Mulher",
        verse_reference="Pv 31:10",
        content="Conteúdo inspirador para mulheres.",
        category="mulher",
    )
    mock_devotional_service.get_devotional = AsyncMock(return_value=dev_mulher)

    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    await view_instance.build(mock_page)

    assert view_instance.category == "jovem"

    # Simula evento de troca de categoria no SegmentedButton
    e = MagicMock()
    e.control.selected = {"mulher"}
    await view_instance._on_change_category(e)

    assert view_instance.category == "mulher"
    assert view_instance.current_devotional == dev_mulher
    mock_devotional_service.get_devotional.assert_called_with(
        target_date=date.today().isoformat(),
        category="mulher",
        force_refresh=False,
    )


def test_meditacao_view_extract_drop_cap():
    """Testa a extração de letra capitular corrigindo artefatos de espaço."""
    # Cenário clássico reportado: primeira letra separada por espaço
    letter, rem = MeditacaoView._extract_drop_cap("L íderes da religião judaica tiveram ciúme.")
    assert letter == "L"
    assert rem.startswith("íderes da religião")

    # Cenário com palavra de uma só letra: "A experiência..."
    letter, rem = MeditacaoView._extract_drop_cap("A experiência de Lázaro deveria ter fortalecido.")
    assert letter == "A"
    assert rem.startswith("experiência de Lázaro")

    # Cenário com palavra comum sem espaço inicial
    letter, rem = MeditacaoView._extract_drop_cap("Líderes da religião judaica.")
    assert letter == "L"
    assert rem.startswith("íderes da religião")

    # Cenário com aspas de abertura
    letter, rem = MeditacaoView._extract_drop_cap("“No princípio criou Deus os céus.”")
    assert letter == "“N"
    assert rem.startswith("o princípio")

    # Cenário sem letra alfabética
    letter, rem = MeditacaoView._extract_drop_cap("123 números no início.")
    assert letter == ""
    assert rem == "123 números no início."


@pytest.mark.asyncio
async def test_meditacao_view_drop_cap_rendering_and_copy(mock_devotional_service, mock_page):
    """Testa a renderização visual da letra capitular e a cópia limpa para área de transferência."""
    dev = Devotional(
        published_at=date.today().isoformat(),
        title="Veneno para as relações afetivas – 2",
        verse_text="Ora, as obras da carne são conhecidas...",
        verse_reference="Gálatas 5:19, 20",
        content="L íderes da religião judaica tiveram ciúme de Jesus.\n\nAlém disso, os líderes religiosos não conseguiam...",
        category="jovem",
    )
    mock_devotional_service.get_devotional = AsyncMock(return_value=dev)

    view_instance = MeditacaoView(devotional_service=mock_devotional_service)
    await view_instance.build(mock_page)
    await view_instance._load_devotional_for_selected_date()

    # O container de texto fica em content_container.controls[7]
    text_column = view_instance.content_container.controls[7]
    assert len(text_column.controls) >= 2

    # Primeiro parágrafo deve ser uma Row estilizada com a Letra Capitular (Drop Cap)
    first_p_row = text_column.controls[0]
    assert isinstance(first_p_row, ft.Row)

    # Filho esquerdo: Container com a letra "L" estilizada em HymnSerif e cor primária
    drop_cap_container = first_p_row.controls[0]
    assert isinstance(drop_cap_container, ft.Container)
    drop_text = drop_cap_container.content
    assert isinstance(drop_text, ft.Text)
    assert drop_text.value == "L"
    assert drop_text.font_family == "HymnSerif"
    assert drop_text.color == ft.Colors.PRIMARY
    assert drop_text.size >= 44

    # Filho direito: Texto remanescente sem o espaço incorreto
    text_container = first_p_row.controls[1]
    assert isinstance(text_container, ft.Container)
    para_text = text_container.content
    assert isinstance(para_text, ft.Text)
    assert para_text.value.startswith("íderes da religião judaica")

    # Segundo parágrafo não deve ter Drop Cap, deve ser um ft.Text normal
    second_p = text_column.controls[1]
    assert isinstance(second_p, ft.Text)
    assert second_p.value.startswith("Além disso, os líderes")

    # Testa a cópia para a área de transferência: o texto deve ser higienizado (Líderes e não L íderes)
    await view_instance._copy_devotional()
    mock_page.clipboard.set.assert_called_once()
    copied_text = mock_page.clipboard.set.call_args[0][0]
    assert "Líderes da religião judaica" in copied_text
    assert "L íderes da religião" not in copied_text
