import asyncio
from unittest.mock import AsyncMock, MagicMock

import flet as ft
import pytest

from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.hino_repository import HinoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.views.home_view import HomeView


@pytest.mark.asyncio
async def test_home_view_build(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    view = await home_view_obj.build(mock_page)
    assert isinstance(view, ft.View)
    assert view.route == "/novo"
    assert view.bgcolor == ft.Colors.SURFACE
    assert len(view.controls) > 0
    assert isinstance(view.controls[0], ft.SafeArea)
    assert view.controls[0].maintain_bottom_view_padding is True
    assert home_view_obj.list_container is not None
    assert home_view_obj.explore_container is not None
    assert home_view_obj.main_content_container is not None
    assert home_view_obj.list_container.visible is True
    assert home_view_obj.explore_container.visible is False
    assert home_view_obj.filter_bar is not None
    assert home_view_obj.filter_bar.show_selected_icon is False
    # Check that segments have text labels without cluttering icons
    for seg in home_view_obj.filter_bar.segments:
        assert seg.icon is None
        assert isinstance(seg.label, ft.Text)


@pytest.mark.asyncio
async def test_home_view_build_antigo_edition(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo, edition="antigo")
    mock_page = MagicMock(spec=ft.Page)

    view = await home_view_obj.build(mock_page)
    assert isinstance(view, ft.View)
    assert view.route == "/antigo"
    assert "Hinário Tradicional" in mock_page.title


@pytest.mark.asyncio
async def test_home_view_tab_switch(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    await home_view_obj.build(mock_page)

    # Simula seleção da aba "Explorar"
    mock_event = MagicMock()
    mock_event.control.selected = ["explorar"]
    await home_view_obj._on_filter_select(mock_event)

    assert home_view_obj.explore_container.visible is True
    assert home_view_obj.list_container.visible is False

    # Simula retorno para a aba "Todos"
    mock_event.control.selected = ["todos"]
    await home_view_obj._on_filter_select(mock_event)

    assert home_view_obj.list_container.visible is True
    assert home_view_obj.explore_container.visible is False


@pytest.mark.asyncio
async def test_home_view_tile_click_triggers_navigation(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.push_route = MagicMock()

    await home_view_obj.build(mock_page)

    # Simula renderização de um hino fictício
    from src.models.hino import Hino

    hino_sample = Hino(id=1, numero="1", titulo="Test Hymn")
    home_view_obj._render_hino_tiles([hino_sample])

    # Dispara o evento on_click do ListTile gerado
    assert home_view_obj.list_container is not None
    tile = home_view_obj.list_container.controls[0]
    assert isinstance(tile, ft.ListTile)
    mock_event = MagicMock(spec=ft.ControlEvent)
    on_click_handler = tile.on_click
    assert callable(on_click_handler)
    on_click_handler(mock_event)  # type: ignore


@pytest.mark.asyncio
async def test_home_view_search_persistence_and_clear(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    # Simula busca de usuário
    mock_event = MagicMock()
    mock_event.control.value = "Santo"
    home_view_obj._on_search_change(mock_event)
    assert home_view_obj.current_search == "Santo"
    assert home_view_obj.search_field is not None
    assert home_view_obj.search_field.suffix is not None

    # Simula reconstrução da view ao voltar do hino
    view = await home_view_obj.build(mock_page)
    assert home_view_obj.current_search == "Santo"
    assert home_view_obj.search_field is not None
    assert home_view_obj.search_field.value == "Santo"


@pytest.mark.asyncio
async def test_home_view_sorting_modes(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    hinos = await hino_repo.get_all()

    # num_asc (default)
    sorted_asc = home_view_obj._sort_hinos(hinos)
    assert sorted_asc[0].numero == "1"

    # num_desc
    home_view_obj.current_sort = "num_desc"
    sorted_desc = home_view_obj._sort_hinos(hinos)
    assert sorted_desc[0].numero == "3"

    # title_asc
    home_view_obj.current_sort = "title_asc"
    sorted_title_asc = home_view_obj._sort_hinos(hinos)
    assert sorted_title_asc[0].titulo.startswith(
        "Ó"
    )  # Ó Adorai o Senhor vem antes de O Deus...
    assert sorted_title_asc[1].titulo.startswith("O")
    assert sorted_title_asc[2].titulo.startswith("Santo")

    # title_desc
    home_view_obj.current_sort = "title_desc"
    sorted_title_desc = home_view_obj._sort_hinos(hinos)
    assert sorted_title_desc[0].titulo.startswith("Santo")
    assert sorted_title_desc[1].titulo.startswith("O")
    assert sorted_title_desc[2].titulo.startswith("Ó")

    # Validação de parse_hino_number e format_hino_number para 587_A / 587_B
    from src.views.home_view import format_hino_number, parse_hino_number

    assert parse_hino_number("587") == 587.0
    assert parse_hino_number("587_A") == 587.1
    assert parse_hino_number("587_B") == 587.2
    assert parse_hino_number("588") == 588.0

    assert format_hino_number("587_A") == "587A"
    assert format_hino_number("587_B") == "587B"

    from src.models.hino import Hino

    hino_587 = Hino(id=587, numero="587", titulo="Hino 587")
    hino_587a = Hino(id=588, numero="587_A", titulo="Hino 587A")
    hino_587b = Hino(id=589, numero="587_B", titulo="Hino 587B")
    hino_588 = Hino(id=590, numero="588", titulo="Hino 588")

    sample_list = [hino_587a, hino_588, hino_587, hino_587b]

    home_view_obj.current_sort = "num_asc"
    sorted_sample_asc = home_view_obj._sort_hinos(sample_list)
    assert [h.numero for h in sorted_sample_asc] == ["587", "587_A", "587_B", "588"]

    home_view_obj.current_sort = "num_desc"
    sorted_sample_desc = home_view_obj._sort_hinos(sample_list)
    assert [h.numero for h in sorted_sample_desc] == ["588", "587_B", "587_A", "587"]


@pytest.mark.asyncio
async def test_home_view_category_filter(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    assert home_view_obj.filter_bar is not None
    assert home_view_obj.filter_bar.allow_empty_selection is True
    assert home_view_obj.active_filter_banner is not None
    assert home_view_obj.active_filter_banner.visible is False

    # Filtra por categoria
    await home_view_obj._filter_by_categoria("Adoração")
    assert home_view_obj.current_filter == "categoria"
    assert home_view_obj.active_category == "Adoração"
    assert home_view_obj.filter_bar.selected == ["explorar"]
    assert home_view_obj.active_filter_banner.visible is True

    # Clicar para voltar ao Explorar limpa a categoria e mostra o explore_container
    await home_view_obj._return_to_explore()
    assert home_view_obj.current_filter == "explorar"
    assert home_view_obj.active_category is None
    assert home_view_obj.active_filter_banner.visible is False
    assert home_view_obj.explore_container.visible is True
    assert home_view_obj.list_container.visible is False


@pytest.mark.asyncio
async def test_home_view_theme_filter_and_clear(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    # Filtra por tema
    await home_view_obj._filter_by_tema("Louvor")
    assert home_view_obj.current_filter == "tema"
    assert home_view_obj.active_tema == "Louvor"
    assert home_view_obj.filter_bar.selected == ["explorar"]
    assert home_view_obj.active_filter_banner.visible is True

    # Limpar filtro volta para Todos
    await home_view_obj._clear_category_or_theme_filter()
    assert home_view_obj.current_filter == "todos"
    assert home_view_obj.active_tema is None
    assert home_view_obj.active_filter_banner.visible is False
    assert home_view_obj.filter_bar.selected == ["todos"]


@pytest.mark.asyncio
async def test_home_view_recentes_tab_shows_only_clicked_hinos(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    # 1. Antes de qualquer hino ser acessado, a aba recentes deve estar vazia
    mock_event = MagicMock()
    mock_event.control.selected = ["recentes"]
    await home_view_obj._on_filter_select(mock_event)
    assert home_view_obj.current_filter == "recentes"
    # Apenas o container de estado vazio
    assert len(home_view_obj.list_container.controls) == 1
    assert home_view_obj.sort_button.visible is False

    # 2. Registrar acesso a múltiplos hinos em ordem não sequencial: hino 3, depois 1, depois 2
    await hist_repo.add_acesso(3)
    await asyncio.sleep(0.01)
    await hist_repo.add_acesso(1)
    await asyncio.sleep(0.01)
    await hist_repo.add_acesso(2)

    # 3. Recarregar aba recentes mesmo com ordenação em num_asc ou title_asc
    home_view_obj.current_sort = "num_asc"
    await home_view_obj._on_filter_select(mock_event)
    assert len(home_view_obj.list_container.controls) == 3
    # A ordem deve ser estritamente cronológica decrescente: 2 (mais recente), 1, 3 (mais antigo)
    tiles = home_view_obj.list_container.controls
    assert "Ó Adorai o Senhor" in tiles[0].title.value  # hino 2
    assert "Santo, Santo, Santo!" in tiles[1].title.value  # hino 1
    assert "O Deus Eterno Reina" in tiles[2].title.value  # hino 3
    assert home_view_obj.sort_button.visible is False

    # 4. Digitar na busca com a aba recentes aberta deve redirecionar para busca global (todos)
    mock_search_event = MagicMock()
    mock_search_event.control.value = "Santo"
    home_view_obj._on_search_change(mock_search_event)
    assert home_view_obj.current_filter == "todos"
    assert home_view_obj.filter_bar.selected == ["todos"]
    assert home_view_obj.sort_button.visible is True


@pytest.mark.asyncio
async def test_home_view_category_search_and_tab_switch(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    await home_view_obj.build(mock_page)

    # 1. Filtra por categoria Adoração
    await home_view_obj._filter_by_categoria("Adoração")
    assert home_view_obj.current_filter == "categoria"
    assert home_view_obj.active_category == "Adoração"
    assert home_view_obj.active_filter_banner.visible is True
    assert home_view_obj.sort_button.visible is True

    # 2. Busca termo dentro da categoria
    mock_search = MagicMock()
    mock_search.control.value = "Santo"
    home_view_obj._on_search_change(mock_search)
    assert home_view_obj.current_filter == "categoria"
    assert home_view_obj.active_category == "Adoração"
    assert home_view_obj.current_search == "Santo"

    # 3. Troca de aba para "Explorar" limpa a categoria e mostra as seções
    mock_tab_event = MagicMock()
    mock_tab_event.control.selected = ["explorar"]
    await home_view_obj._on_filter_select(mock_tab_event)
    assert home_view_obj.current_filter == "explorar"
    assert home_view_obj.active_category is None
    assert home_view_obj.active_filter_banner.visible is False
    assert home_view_obj.sort_button.visible is False

    # 4. Troca de aba para "Todos"
    mock_tab_event.control.selected = ["todos"]
    await home_view_obj._on_filter_select(mock_tab_event)
    assert home_view_obj.current_filter == "todos"
    assert home_view_obj.active_category is None
    assert home_view_obj.sort_button.visible is True


@pytest.mark.asyncio
async def test_home_view_show_about_dialog(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.show_dialog = MagicMock()
    mock_page.run_task = MagicMock()

    await home_view_obj.build(mock_page)

    home_view_obj._show_about_dialog()
    mock_page.show_dialog.assert_called_once()
    bs = mock_page.show_dialog.call_args[0][0]
    assert isinstance(bs, ft.BottomSheet)
    assert bs.scrollable is True
    assert bs.show_drag_handle is True
    assert bs.use_safe_area is True
    assert bs.maintain_bottom_view_insets_padding is True
    assert bs.content is not None

    # Verifica se os componentes do diálogo estão presentes
    dialog_col = bs.content.content
    assert isinstance(dialog_col, ft.Column)
    assert dialog_col.scroll == ft.ScrollMode.AUTO

    # Encontra o container com o botão do GitHub e o switch AMOLED
    github_button_found = False
    amoled_switch_found = False
    for control in dialog_col.controls:
        if isinstance(control, ft.Row):
            for sub in control.controls:
                if isinstance(
                    sub, ft.OutlinedButton
                ) and "github.com/Lucas2Araujo/Kairos" in (sub.url or ""):
                    github_button_found = True
        elif isinstance(control, ft.Container) and isinstance(control.content, ft.Row):
            for sub in control.content.controls:
                if isinstance(sub, ft.Switch):
                    amoled_switch_found = True
    assert github_button_found is True
    assert amoled_switch_found is True


@pytest.mark.asyncio
async def test_home_view_open_url(in_memory_db):
    from unittest.mock import AsyncMock, patch

    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    await home_view_obj.build(mock_page)

    with patch("flet.UrlLauncher.launch_url", new_callable=AsyncMock) as mock_launch:
        await home_view_obj._open_url("https://github.com/Lucas2Araujo/Kairos")
        mock_launch.assert_called_once_with("https://github.com/Lucas2Araujo/Kairos")


@pytest.mark.asyncio
async def test_home_view_amoled_toggle(in_memory_db):
    from src.services.theme_service import ThemeService

    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)
    theme_service = ThemeService(in_memory_db)

    home_view_obj = HomeView(
        hino_repo, fav_repo, hist_repo, theme_service=theme_service
    )
    mock_page = MagicMock(spec=ft.Page)
    await home_view_obj.build(mock_page)

    await home_view_obj._on_amoled_toggle(True)
    assert theme_service.is_amoled is True
    assert mock_page.theme_mode == ft.ThemeMode.DARK

    await home_view_obj._on_amoled_toggle(False)
    assert theme_service.is_amoled is False
    assert mock_page.theme_mode == ft.ThemeMode.SYSTEM


@pytest.mark.asyncio
async def test_home_view_cached_view_retention(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)

    view1 = await home_view_obj.build(mock_page)
    assert home_view_obj._cached_view is view1

    # Quando chamada novamente sem nova busca, deve retornar a mesma instância preservando scroll e listas
    view2 = await home_view_obj.build(mock_page)
    assert view2 is view1


@pytest.mark.asyncio
async def test_home_view_origin_hino_banner_navigation(in_memory_db):
    from unittest.mock import AsyncMock

    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.push_route = AsyncMock()


    # Constrói a HomeView com filtro de categoria e hino de origem (Hino 42)
    view = await home_view_obj.build(
        mock_page,
        initial_categoria="Adoração",
        origin_hino_id=42,
    )
    assert home_view_obj.current_filter == "categoria"
    assert home_view_obj.active_category == "Adoração"
    assert home_view_obj.origin_hino_id == 42
    assert home_view_obj.active_filter_banner.visible is True

    # Verifica se o botão do banner exibe "Voltar para o hino"
    banner_row = home_view_obj.active_filter_banner.content.content
    assert isinstance(banner_row, ft.Row)
    back_to_hino_btn = banner_row.controls[2]
    assert isinstance(back_to_hino_btn, ft.TextButton)
    assert back_to_hino_btn.content.value == "Voltar para o hino"

    # Testa o clique no botão "Voltar para o hino"
    await home_view_obj._navigate_back_to_hino()
    mock_page.push_route.assert_called_once_with("/novo/hino/42")

    # Testa limpeza do filtro
    await home_view_obj._clear_category_or_theme_filter()
    assert home_view_obj.origin_hino_id is None
    assert home_view_obj.active_category is None
    assert home_view_obj.current_filter == "todos"


def test_parse_route_query_main():
    from main import _parse_route_query

    # Categoria com hino de origem
    r_base, q, cat, tema, from_hino = _parse_route_query(
        "/novo?categoria=Adora%C3%A7%C3%A3o&from_hino=42"
    )
    assert r_base == "/novo"
    assert q == ""
    assert cat == "Adoração"
    assert tema is None
    assert from_hino == 42

    # Tema com hino de origem
    r_base, q, cat, tema, from_hino = _parse_route_query(
        "/novo?tema=Gratid%C3%A3o&from_hino=10"
    )
    assert r_base == "/novo"
    assert q == ""
    assert cat is None
    assert tema == "Gratidão"
    assert from_hino == 10

    # Busca geral
    r_base, q, cat, tema, from_hino = _parse_route_query("/novo?q=Cristo")
    assert r_base == "/novo"
    assert q == "Cristo"
    assert cat is None
    assert tema is None
    assert from_hino is None

    # Rota simples sem query
    r_base, q, cat, tema, from_hino = _parse_route_query("/antigo")
    assert r_base == "/antigo"
    assert q == ""
    assert cat is None
    assert tema is None
    assert from_hino is None


def test_hinos_view_alias_and_export():
    from src.views import HinosView
    from src.views.home_view import HinosView as HinosViewFromHome

    assert HinosView is HomeView
    assert HinosViewFromHome is HomeView


@pytest.mark.asyncio
async def test_home_view_navigation_and_tabs_layout(in_memory_db):
    from unittest.mock import AsyncMock

    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo, edition="novo")
    mock_page = MagicMock(spec=ft.Page)
    mock_page.push_route = AsyncMock()

    view = await home_view_obj.build(mock_page)

    # 1. Verifica que edition_selector foi removido da HomeView
    assert not hasattr(home_view_obj, "edition_selector")

    # 2. Verifica presença, expansão e alinhamento responsivo da barra de abas (filter_bar)
    assert home_view_obj.filter_bar is not None
    assert isinstance(home_view_obj.filter_bar, ft.SegmentedButton)
    assert home_view_obj.filter_bar.expand is True

    # Verifica se filter_bar está contido em um ft.Row para preencher a largura da tela
    safe_area = view.controls[0]
    main_column = safe_area.content.content
    filter_bar_container = main_column.controls[2]  # controls: search_row, filter_banner, filter_bar_row, list
    assert isinstance(filter_bar_container, ft.Container)
    assert isinstance(filter_bar_container.content, ft.Row)
    assert home_view_obj.filter_bar in filter_bar_container.content.controls

    # 3. Testa botão de retorno da AppBar para a raiz "/"
    assert view.appbar.leading is not None
    assert view.appbar.leading.icon == ft.Icons.ARROW_BACK
    await home_view_obj._navigate("/")
    mock_page.push_route.assert_called_with("/")


@pytest.mark.asyncio
async def test_home_view_switch_edition_in_place(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo, edition="novo")
    mock_page = MagicMock(spec=ft.Page)
    await home_view_obj.build(mock_page)

    await home_view_obj.switch_edition("antigo")
    assert home_view_obj.edition == "antigo"
    assert "Hinário Tradicional" in mock_page.title

    await home_view_obj.switch_edition("novo")
    assert home_view_obj.edition == "novo"
    assert "Hinário Novo" in mock_page.title


@pytest.mark.asyncio
async def test_home_view_m3_card_styling(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    await home_view_obj.build(mock_page)

    from src.models.hino import Hino

    sample = Hino(id=10, numero="10", titulo="M3 Styled Hymn")
    home_view_obj._render_hino_tiles([sample])

    assert len(home_view_obj.list_container.controls) == 1
    tile = home_view_obj.list_container.controls[0]
    assert isinstance(tile, ft.ListTile)
    assert tile.bgcolor == ft.Colors.SURFACE_CONTAINER_LOW
    assert isinstance(tile.shape, ft.RoundedRectangleBorder)
    assert tile.shape.radius == 12
    assert tile.title.value == "M3 Styled Hymn"


@pytest.mark.asyncio
async def test_home_view_infinite_scroll(in_memory_db):
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.update = MagicMock()
    await home_view_obj.build(mock_page)

    from src.models.hino import Hino

    # Cria lista com 100 hinos
    many_hinos = [Hino(id=i, numero=str(i), titulo=f"Hino {i}") for i in range(1, 101)]

    home_view_obj._render_hino_tiles(many_hinos)

    # 1. Deve renderizar apenas o lote inicial (40 itens)
    assert len(home_view_obj.list_container.controls) == 40
    assert home_view_obj._rendered_count == 40
    assert len(home_view_obj._filtered_hinos) == 100

    # 2. Simula evento de rolagem que NÃO atinge o limiar de 200px do final
    scroll_event_middle = MagicMock()
    scroll_event_middle.pixels = 300.0
    scroll_event_middle.max_scroll_extent = 1000.0
    home_view_obj._on_scroll(scroll_event_middle)
    assert len(home_view_obj.list_container.controls) == 40

    # 3. Simula evento de rolagem próximo ao final (pixels >= 800 para max_extent=1000)
    scroll_event_near_bottom = MagicMock()
    scroll_event_near_bottom.pixels = 850.0
    scroll_event_near_bottom.max_scroll_extent = 1000.0
    home_view_obj._on_scroll(scroll_event_near_bottom)

    # Segundo lote de 40 itens carregado (totalizando 80)
    assert len(home_view_obj.list_container.controls) == 80
    assert home_view_obj._rendered_count == 80

    # 4. Rola até o final novamente para carregar os últimos 20 itens
    home_view_obj._on_scroll(scroll_event_near_bottom)
    assert len(home_view_obj.list_container.controls) == 100
    assert home_view_obj._rendered_count == 100

    # 5. Mais rolagens não devem adicionar itens além do total
    home_view_obj._on_scroll(scroll_event_near_bottom)
    assert len(home_view_obj.list_container.controls) == 100


@pytest.mark.asyncio
async def test_home_view_appbar_edition_dropdown_and_actions(in_memory_db):
    """Valida o dropdown interativo de edição na AppBar e a remoção do botão de meditação."""
    import asyncio
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    # 1. Testando na edição 'novo'
    home_novo = HomeView(hino_repo, fav_repo, hist_repo, edition="novo")
    mock_page = MagicMock(spec=ft.Page)
    mock_page.push_route = AsyncMock()
    view_novo = await home_novo.build(mock_page)

    # Verifica título como PopupMenuButton
    appbar = view_novo.appbar
    assert isinstance(appbar.title, ft.PopupMenuButton)
    popup_btn = appbar.title
    assert popup_btn.tooltip == "Alternar Edição do Hinário"
    assert len(popup_btn.items) == 2

    item_novo = popup_btn.items[0]
    item_antigo = popup_btn.items[1]
    assert item_novo.content.value == "Hinário Novo (2022)"
    assert item_novo.icon == ft.Icons.CHECK
    assert item_antigo.content.value == "Hinário Tradicional (1996)"
    assert item_antigo.icon == ft.Icons.MENU_BOOK

    # Clicar na edição já ativa (novo) não deve disparar push_route
    item_novo.on_click(None)
    await asyncio.sleep(0.01)
    mock_page.push_route.assert_not_called()

    # Clicar na edição inativa (antigo) deve disparar push_route("/antigo")
    item_antigo.on_click(None)
    await asyncio.sleep(0.01)
    mock_page.push_route.assert_called_once_with("/antigo")

    # 2. Testando na edição 'antigo'
    mock_page.push_route.reset_mock()
    home_antigo = HomeView(hino_repo, fav_repo, hist_repo, edition="antigo")
    view_antigo = await home_antigo.build(mock_page)
    popup_btn_antigo = view_antigo.appbar.title
    item_novo_2 = popup_btn_antigo.items[0]
    item_antigo_2 = popup_btn_antigo.items[1]

    assert item_novo_2.icon == ft.Icons.MUSIC_NOTE
    assert item_antigo_2.icon == ft.Icons.CHECK

    # Clicar em novo navega para /novo
    item_novo_2.on_click(None)
    await asyncio.sleep(0.01)
    mock_page.push_route.assert_called_once_with("/novo")

    # 3. Verifica actions do AppBar: NÃO deve conter botão de meditação
    action_tooltips = [act.tooltip for act in appbar.actions if hasattr(act, "tooltip")]
    action_icons = [act.icon for act in appbar.actions if hasattr(act, "icon")]
    assert "Meditação Diária" not in action_tooltips
    assert ft.Icons.FAVORITE_BORDER_ROUNDED not in action_icons
    # Confirma que configurações e downloads continuam presentes
    assert "Configurações e Temas" in action_tooltips
    assert "Gerenciar Downloads" in action_tooltips

@pytest.mark.asyncio
async def test_home_view_build_with_initial_filtro_sabado(in_memory_db):
    """Verifica que HomeView.build aceita initial_filtro e filtra hinos de sábado (290 a 299)."""
    hino_repo = HinoRepository(in_memory_db)
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    # Inserir alguns hinos no in_memory_db, incluindo um entre 290 e 299
    conn = await in_memory_db.get_connection()
    await conn.execute("INSERT OR IGNORE INTO hino (id, numero, titulo) VALUES (295, '295', 'Hino de Sábado');")
    await conn.execute("INSERT OR IGNORE INTO hino (id, numero, titulo) VALUES (1, '1', 'Hino Geral');")
    await conn.commit()

    home_view_obj = HomeView(hino_repo, fav_repo, hist_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.update = MagicMock()

    view = await home_view_obj.build(
        mock_page,
        initial_filtro="sabado",
        extra_param="ignorado_com_sucesso",
    )
    assert view is not None
    assert home_view_obj.current_filter == "sabado"
    assert home_view_obj.active_filter_banner.visible is True




