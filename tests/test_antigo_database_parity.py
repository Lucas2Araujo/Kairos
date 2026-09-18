import dataclasses
from unittest.mock import AsyncMock, MagicMock, patch

import flet as ft
import pytest

from src.database.connection import DatabaseConnection
from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.hino_repository import HinoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.views.hino_view import HinoView


@pytest.mark.asyncio
async def test_antigo_database_parity_structure():
    """Valida paridade estrutural, contagens e preenchimento de vídeos entre Novo e Antigo."""
    conn_novo = DatabaseConnection(db_path="hinario.db")
    conn_antigo = DatabaseConnection(db_path="hinario_antigo.db")

    try:
        repo_novo = HinoRepository(conn_novo)
        repo_antigo = HinoRepository(conn_antigo)

        hinos_novo = await repo_novo.get_all()
        hinos_antigo = await repo_antigo.get_all()

        assert len(hinos_novo) == 601
        assert len(hinos_antigo) == 613

        # Hino 1 em ambos deve ter título e link de vídeo válido do YouTube
        h1_novo = await repo_novo.get_by_id(1)
        assert h1_novo is not None
        assert h1_novo.titulo == "Santo, Santo, Santo!"
        assert h1_novo.link_video and "youtube.com" in h1_novo.link_video

        h1_antigo = await repo_antigo.get_by_id(1)
        assert h1_antigo is not None
        assert h1_antigo.titulo == "Ó Deus de Amor"
        assert h1_antigo.link_video == "https://www.youtube.com/watch?v=ZpmWPU-tbKA"

        # Validar que todos os 613 hinos do Antigo possuem link_video preenchido
        c_antigo = await conn_antigo.get_connection()
        async with c_antigo.execute(
            "SELECT count(*) FROM hino WHERE link_video IS NOT NULL AND link_video != ''"
        ) as cur:
            cnt_videos = (await cur.fetchone())[0]
        assert cnt_videos == 613

        # Validar metadados relacionais (temas e textos bíblicos) no Antigo
        meta_antigo = await repo_antigo.get_metadados_relacionados(1)
        assert "temas" in meta_antigo and len(meta_antigo["temas"]) > 0
        assert "textos_biblicos" in meta_antigo and len(meta_antigo["textos_biblicos"]) > 0

        # Validar busca FTS5 em ambos
        busca_novo = await repo_novo.search("Deus")
        busca_antigo = await repo_antigo.search("Deus")
        assert len(busca_novo) > 0
        assert len(busca_antigo) > 0
    finally:
        await conn_novo.close()
        await conn_antigo.close()


@pytest.mark.asyncio
async def test_hino_view_youtube_button_antigo_edition():
    """Valida que o botão de YouTube no Hinário Antigo fica habilitado e redireciona corretamente."""
    conn_antigo = DatabaseConnection(db_path="hinario_antigo.db")
    try:
        repo = HinoRepository(conn_antigo)
        fav = FavoritoRepository(conn_antigo)
        hist = HistoricoRepository(conn_antigo)

        view_obj = HinoView(1, repo, fav, hist, edition="antigo")
        mock_page = MagicMock(spec=ft.Page)
        mock_page.overlay = []
        mock_page.services = []

        await view_obj.build(mock_page)

        # Botão deve estar habilitado com ícone vermelho
        assert view_obj.youtube_btn is not None
        assert view_obj.youtube_btn.disabled is False
        assert view_obj.youtube_btn.icon_color == ft.Colors.RED_400
        assert view_obj.youtube_btn.tooltip == "Assistir no YouTube (Link Externo)"

        # Teste de redirecionamento via UrlLauncher
        with patch("flet.UrlLauncher.launch_url", new_callable=AsyncMock) as mock_launch:
            await view_obj._open_youtube_link(mock_page, view_obj.current_hino)
            mock_launch.assert_called_once_with(
                "https://www.youtube.com/watch?v=ZpmWPU-tbKA"
            )
    finally:
        await conn_antigo.close()


@pytest.mark.asyncio
async def test_hino_view_youtube_fallback_to_webbrowser():
    """Valida o fallback para o navegador nativo (webbrowser) caso o launcher Flet falhe."""
    conn_antigo = DatabaseConnection(db_path="hinario_antigo.db")
    try:
        repo = HinoRepository(conn_antigo)
        fav = FavoritoRepository(conn_antigo)
        hist = HistoricoRepository(conn_antigo)

        view_obj = HinoView(1, repo, fav, hist, edition="antigo")
        mock_page = MagicMock(spec=ft.Page)
        mock_page.overlay = []
        mock_page.services = []

        await view_obj.build(mock_page)

        with (
            patch("flet.UrlLauncher.launch_url", side_effect=RuntimeError("Flet launcher unavailable")),
            patch("webbrowser.open", return_value=True) as mock_browser_open,
        ):
            await view_obj._open_youtube_link(mock_page, view_obj.current_hino)
            mock_browser_open.assert_called_once_with(
                "https://www.youtube.com/watch?v=ZpmWPU-tbKA"
            )
    finally:
        await conn_antigo.close()

