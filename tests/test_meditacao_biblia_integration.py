"""
Testes unitários para o fluxo de integração Meditação ⇄ Bíblia Sagrada:
1. Utilitário bible_extractor: extração, parsing e fragmentação de texto.
2. Navegação de MeditacaoView para Bíblia com referências em destaque.
3. Parser de rotas em main.py com suporte a med_refs / refs.
4. Renderização e funcionamento da barra de contexto de meditação na BibliaView.
"""

from __future__ import annotations

import asyncio
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch
import urllib.parse
import flet as ft
import pytest

from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService
from src.utils.bible_extractor import (
    BibleRefMatch,
    extract_all_bible_refs,
    find_bible_references,
    split_text_by_bible_refs,
)
from src.views.biblia_view import BibliaView, make_devotional_context_bar
from src.views.meditacao_view import MeditacaoView
from main import _parse_bible_route_query


class TestBibleExtractor:
    def test_find_bible_references_standard(self):
        text = "Lemos em Rm 8:28 que todas as coisas cooperam para o bem. Veja também João 3:16 e 1Co 13:4-7."
        matches = find_bible_references(text)
        refs = [m.raw_text for m in matches]
        assert "Rm 8:28" in refs
        assert "João 3:16" in refs
        assert "1Co 13:4-7" in refs

    def test_find_bible_references_ignores_false_positives(self):
        text = "No capítulo 1:12 do relatório, página 2:10, temos estatísticas."
        matches = find_bible_references(text)
        assert len(matches) == 0

    def test_extract_all_bible_refs_deduplication(self):
        text = "Primeiro vemos Gl 5:22 e mais adiante novamente Gl 5:22 junto a Ef 2:8."
        refs = extract_all_bible_refs(text)
        assert refs == ["Gl 5:22", "Ef 2:8"]

    def test_split_text_by_bible_refs(self):
        text = "Início Rm 8:28 meio Jo 3:16 fim"
        segments = split_text_by_bible_refs(text)
        assert len(segments) == 5
        assert segments[0] == ("Início ", None)
        assert segments[1] == ("Rm 8:28", "Rm 8:28")
        assert segments[2] == (" meio ", None)
        assert segments[3] == ("Jo 3:16", "Jo 3:16")
        assert segments[4] == (" fim", None)


class TestMeditacaoBibliaNavigation:
    @pytest.fixture
    def mock_devotional_service(self):
        service = MagicMock(spec=DevotionalService)
        service.run_auto_cleanup = AsyncMock(return_value=0)
        service.get_devotional = AsyncMock()
        return service

    @pytest.fixture
    def mock_page(self):
        page = MagicMock(spec=ft.Page)
        page.client_storage = MagicMock()
        page.client_storage.get_async = AsyncMock(return_value=None)
        page.client_storage.set_async = AsyncMock()
        page.go = MagicMock()
        page.update = MagicMock()
        page.views = []
        page.route = "/meditacoes"
        page.run_task = MagicMock(side_effect=lambda fn, *args: asyncio.create_task(fn(*args)))
        return page

    @pytest.mark.asyncio
    async def test_verse_card_direct_navigation_to_bible(self, mock_devotional_service, mock_page):
        """Valida que clicar no card do versículo abre o VerseDialog e permite navegar para a Bíblia."""
        today = date.today()
        dev = Devotional(
            published_at=today.isoformat(),
            title="Amor Eterno",
            verse_text="Porque Deus amou o mundo de tal maneira...",
            verse_reference="João 3:16",
            content="Conforme Rm 8:28 nos lembra, Deus age em tudo.",
            category="jovem",
        )
        mock_devotional_service.get_devotional.return_value = dev

        view = MeditacaoView(devotional_service=mock_devotional_service)
        await view.build(mock_page)
        await view._load_devotional_for_selected_date()

        # O container content_container deve ter o verse_card no índice 2
        verse_container = view.content_container.controls[2]
        verse_card_inner = verse_container.content
        card_content = verse_card_inner.content

        # Dispara o on_click do card e valida abertura do popup VerseDialog
        assert card_content.on_click is not None
        with patch("src.views.meditacao_view.show_verse_dialog") as mock_dialog:
            card_content.on_click(MagicMock())
            # Permite que a task assíncrona execute
            await asyncio.sleep(0.01)
            assert mock_dialog.called
            call_kwargs = mock_dialog.call_args[1]
            assert call_kwargs["page"] == mock_page
            assert len(call_kwargs["passages"]) == 1
            assert call_kwargs["passages"][0]["canonical_ref"] == "João 3:16"

            # Ao acionar 'on_read_full_chapter', navega diretamente para /biblia com parâmetros e refs
            on_ler = call_kwargs["on_read_full_chapter"]
            on_ler("João", 3, 16)
            mock_page.go.assert_called_once()
            called_route = mock_page.go.call_args[0][0]
            assert called_route.startswith("/biblia?")
            assert "livro=Jo%C3%A3o" in called_route or "livro=Joao" in called_route or "livro=Jo" in called_route
            assert "cap=3" in called_route
            assert "ver=16" in called_route
            assert "refs=" in called_route
            assert urllib.parse.quote("João 3:16") in called_route or "Jo" in called_route
            assert urllib.parse.quote("Rm 8:28") in called_route or "Rm" in called_route

    @pytest.mark.asyncio
    async def test_in_text_bible_reference_spans(self, mock_devotional_service, mock_page):
        """Valida que citações no meio do texto geram TextSpan abrindo VerseDialog."""
        today = date.today()
        dev = Devotional(
            published_at=today.isoformat(),
            title="Cuidado Divino",
            verse_text="O Senhor é o meu pastor.",
            verse_reference="Salmos 23:1",
            content="Leia Rm 8:28 para entender mais sobre providência.",
            category="jovem",
        )
        mock_devotional_service.get_devotional.return_value = dev

        view = MeditacaoView(devotional_service=mock_devotional_service)
        await view.build(mock_page)
        await view._load_devotional_for_selected_date()

        # O container de textos está no índice 7 (Column de text_controls)
        text_column = view.content_container.controls[7]
        paragraph_text = text_column.controls[0]
        assert hasattr(paragraph_text, "spans")
        assert paragraph_text.spans is not None
        assert len(paragraph_text.spans) >= 2

        # Encontra o span correspondente a Rm 8:28
        ref_span = next(s for s in paragraph_text.spans if s.text == "Rm 8:28")
        assert ref_span.on_click is not None

        # Clica no span e verifica que abre o VerseDialog
        with patch("src.views.meditacao_view.show_verse_dialog") as mock_dialog:
            ref_span.on_click(MagicMock())
            await asyncio.sleep(0.01)
            assert mock_dialog.called
            call_kwargs = mock_dialog.call_args[1]
            assert len(call_kwargs["passages"]) == 1
            assert call_kwargs["passages"][0]["canonical_ref"] == "Rm 8:28"

            # Acionando 'on_read_full_chapter', navega para a Bíblia
            on_ler = call_kwargs["on_read_full_chapter"]
            on_ler("Rm", 8, 28)
            mock_page.go.assert_called_once()
            called_route = mock_page.go.call_args[0][0]
            assert "livro=Rm" in called_route or "livro=Romanos" in called_route
            assert "cap=8" in called_route
            assert "ver=28" in called_route


class TestBibleRouteParsing:
    def test_parse_bible_route_with_meditation_refs(self):
        route = "/biblia?livro=G%C3%A1latas&cap=5&ver=19&refs=G%C3%A1latas%205%3A19%7CRm%208%3A28"
        livro, cap, ver, hino_id, med_refs = _parse_bible_route_query(route)
        assert livro == "Gálatas"
        assert cap == 5
        assert ver == 19
        assert hino_id is None
        assert med_refs == ["Gálatas 5:19", "Rm 8:28"]


class TestBibliaViewContextBar:
    def test_make_devotional_context_bar_structure(self):
        from src.views.biblia_view import ReferenciaRelacionada

        refs = [
            ReferenciaRelacionada(texto_formatado="Gálatas 5:19", livro="Gálatas", capitulo=5, versiculo=19),
            ReferenciaRelacionada(texto_formatado="Rm 8:28", livro="Romanos", capitulo=8, versiculo=28),
        ]
        callback_mock = MagicMock()
        bar = make_devotional_context_bar(refs, callback_mock, titulo="Meditação")

        assert isinstance(bar, ft.Container)
        row = bar.content
        assert isinstance(row, ft.Row)
        # Deve ter o ícone, o texto "Textos da Meditação:" e a lista de chips
        assert any(isinstance(c, ft.Text) and "Textos da Meditação:" in c.value for c in row.controls)

        # Dispara clique no primeiro chip
        chips_row = next(c for c in row.controls if isinstance(c, ft.Row))
        first_chip = chips_row.controls[0]
        first_chip.on_click(MagicMock())
        callback_mock.assert_called_once_with("Gálatas", 5, 19)

