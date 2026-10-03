from unittest.mock import AsyncMock, MagicMock
import flet as ft
import pytest

from src.database.connection import DatabaseConnection
from src.services.theme_service import ThemeService
from src.views.selecao_view import SelecaoView


@pytest.mark.asyncio
async def test_selecao_view_build():
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    view = selecao_view.build(mock_page)

    assert isinstance(view, ft.View)
    assert view.route == "/"
    assert view.appbar is not None
    assert len(view.controls) > 0
    assert isinstance(view.controls[0], ft.SafeArea)


@pytest.mark.asyncio
async def test_selecao_view_navigation():
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.push_route = AsyncMock()

    await selecao_view._navigate(mock_page, "/novo")
    mock_page.push_route.assert_called_once_with("/novo")

    mock_page.push_route.reset_mock()
    await selecao_view._navigate(mock_page, "/antigo")
    mock_page.push_route.assert_called_once_with("/antigo")


def test_selecao_view_about_dialog():
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.show_dialog = MagicMock()

    selecao_view._show_about_dialog(mock_page)
    mock_page.show_dialog.assert_called_once()


def test_selecao_view_conditional_module_badges():
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)

    mock_cm = MagicMock()
    # Caso 1: Módulos NÃO instalados
    mock_cm.is_module_installed.return_value = False
    mock_cm.has_any_bible_installed.return_value = False
    mock_cm.get_installed_bible_ids.return_value = []

    selecao_uninstalled = SelecaoView(
        theme_service=theme_service, content_manager=mock_cm
    )
    mock_page = MagicMock(spec=ft.Page)
    view_uninstalled = selecao_uninstalled.build(mock_page)
    assert isinstance(view_uninstalled, ft.View)

    # Caso 2: Módulos INSTALADOS
    mock_cm.is_module_installed.return_value = True
    mock_cm.has_any_bible_installed.return_value = True
    mock_cm.get_installed_bible_ids.return_value = ["ARA", "NVI"]

    selecao_installed = SelecaoView(
        theme_service=theme_service, content_manager=mock_cm
    )
    view_installed = selecao_installed.build(mock_page)
    assert isinstance(view_installed, ft.View)


@pytest.mark.asyncio
async def test_selecao_view_contrast_no_grey_400():
    """Garante que nenhum texto na SelecaoView utilize GREY_400 estático."""
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    view = selecao_view.build(mock_page)

    # Função recursiva para inspecionar todos os controles
    def check_no_grey_400(ctrl):
        if isinstance(ctrl, ft.Text):
            assert ctrl.color != ft.Colors.GREY_400, f"Texto '{ctrl.value}' usa GREY_400 (baixo contraste)!"
        content = getattr(ctrl, "content", None)
        if content:
            check_no_grey_400(content)
        controls = getattr(ctrl, "controls", None)
        if controls:
            for child in controls:
                check_no_grey_400(child)

    for ctrl in view.controls:
        check_no_grey_400(ctrl)


@pytest.mark.asyncio
async def test_selecao_view_liquid_glass_adaptation():
    """Valida a aplicação de gradiente ambiente fluido e cartões vítreos na SelecaoView."""
    from src.theme.palette import ThemeModeType
    from src.theme.theme_engine import ThemeEngine

    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    engine = ThemeEngine(db_conn)
    engine.theme_style = ThemeModeType.LIQUID_GLASS
    engine.is_dark = False

    selecao = SelecaoView(theme_service=theme_service, theme_engine=engine)
    mock_page = MagicMock(spec=ft.Page)
    view = selecao.build(mock_page)

    # O container raiz dentro de SafeArea deve possuir o gradiente fluido
    safe_area = view.controls[0]
    root_container = safe_area.content
    assert root_container.gradient is not None
    assert isinstance(root_container.gradient, ft.LinearGradient)

    # O primeiro cartão de edição (Hinários unificado) deve possuir gradiente e borda vítrea
    content_col = root_container.content
    # header = 0, spacer = 1, card_hinarios = 2
    card_hinarios = content_col.controls[2]
    assert card_hinarios.gradient is not None
    assert card_hinarios.border is not None
    assert card_hinarios.border_radius == 20


@pytest.mark.asyncio
async def test_selecao_view_unified_hinarios_card():
    """Valida a consolidação dos hinários em um único card com badge '2022 & 1996' e rota /novo."""
    import asyncio
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao = SelecaoView(theme_service=theme_service)
    mock_page = MagicMock(spec=ft.Page)
    view = selecao.build(mock_page)

    safe_area = view.controls[0]
    content_col = safe_area.content.content

    all_texts = []

    def collect_texts(ctrl):
        if isinstance(ctrl, ft.Text):
            all_texts.append(ctrl.value)
        content = getattr(ctrl, "content", None)
        if content:
            collect_texts(content)
        controls = getattr(ctrl, "controls", None)
        if controls:
            for child in controls:
                collect_texts(child)

    collect_texts(content_col)

    assert "Hinários" in all_texts
    assert "2022 & 1996" in all_texts
    assert "Novo e Tradicional • Letras e Áudios" in all_texts
    assert "Hinário Novo" not in all_texts
    assert "Hinário Tradicional" not in all_texts

    card_hinarios = content_col.controls[2]
    assert isinstance(card_hinarios, ft.Container)
    mock_page.push_route = AsyncMock()
    card_hinarios.on_click(None)
    await asyncio.sleep(0.01)
    mock_page.push_route.assert_called_once_with("/novo")


@pytest.mark.asyncio
async def test_selecao_view_verse_card_initial_state_has_no_spinner():
    """Garante que o card de meditação nasce sem spinner (ProgressRing) e com layout amigável instantâneo."""
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    view = selecao_view.build(mock_page)

    assert selecao_view.verse_container is not None
    verse_content = selecao_view.verse_container.content
    assert isinstance(verse_content, ft.Row)

    # Verifica que NÃO há ProgressRing no card inicial
    progress_rings = [c for c in verse_content.controls if isinstance(c, ft.ProgressRing)]
    assert len(progress_rings) == 0

    # Verifica que possui o ícone e texto amigável de leitura imediata
    icons = [
        c for c in verse_content.controls
        if isinstance(c, ft.Icon) and (getattr(c, "name", None) == ft.Icons.AUTO_STORIES or getattr(c, "icon", None) == ft.Icons.AUTO_STORIES)
    ]
    assert len(icons) == 1


@pytest.mark.asyncio
async def test_selecao_view_header_has_no_embedded_search_container():
    """Garante que a barra de pesquisa rápida embutida foi removida do corpo do cabeçalho."""
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    view = selecao_view.build(mock_page)

    safe_area = view.controls[0]
    content_col = safe_area.content.content
    header_container = content_col.controls[0]
    header_col = header_container.content

    # Coleta todos os textos dentro do cabeçalho
    header_texts = []
    def collect_texts(ctrl):
        if isinstance(ctrl, ft.Text):
            header_texts.append(ctrl.value)
        content = getattr(ctrl, "content", None)
        if content:
            collect_texts(content)
        controls = getattr(ctrl, "controls", None)
        if controls:
            for child in controls:
                collect_texts(child)

    collect_texts(header_col)
    assert not any("Pesquisa rápida no app" in (t or "") for t in header_texts)


@pytest.mark.asyncio
async def test_selecao_view_navegar_para_biblia():
    """Garante que _navegar_para_biblia fecha o modal e navega com a rota formatada."""
    db_conn = DatabaseConnection(db_path=":memory:")
    theme_service = ThemeService(db_conn)
    selecao_view = SelecaoView(theme_service=theme_service)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.pop_dialog = MagicMock()
    mock_page.push_route = AsyncMock()
    selecao_view.page = mock_page

    await selecao_view._navegar_para_biblia("João", 3, 16)
    mock_page.pop_dialog.assert_called_once()
    mock_page.push_route.assert_called_once_with("/biblia?livro=Jo%C3%A3o&cap=3&ver=16")


@pytest.mark.asyncio
async def test_selecao_view_search_with_injected_repos():
    """Verifica que a busca global utiliza os repositórios injetados de hino e bíblia."""
    mock_hino_repo = MagicMock()
    mock_hino = MagicMock()
    mock_hino.numero = "10"
    mock_hino.titulo = "Louvor ao Senhor"
    mock_hino_repo.search = AsyncMock(return_value=[mock_hino])

    mock_biblia_repo = MagicMock()
    mock_biblia_repo.pesquisar_texto = AsyncMock(return_value=[
        {"book_name": "Salmos", "chapter": 23, "verse": 1, "text": "O Senhor é meu pastor"}
    ])

    selecao_view = SelecaoView(
        hino_repository=mock_hino_repo,
        biblia_repository=mock_biblia_repo,
    )
    mock_page = MagicMock(spec=ft.Page)
    mock_page.show_dialog = MagicMock()
    selecao_view.page = mock_page

    selecao_view._abrir_pesquisa_global()
    mock_page.show_dialog.assert_called_once()
    bs = mock_page.show_dialog.call_args[0][0]
    assert isinstance(bs, ft.BottomSheet)





