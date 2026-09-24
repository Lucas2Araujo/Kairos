"""
Testes unitários e de integração para o módulo da Escola Sabatina:
1. Modelos (SSQuarterly, SSLesson, SSDay, SSUserNote)
2. Repositório SQLite (EscolaSabatinaRepository)
3. Serviço de Domínio e Cache de Imagens (EscolaSabatinaService)
4. Interceptação de Versículos e VerseDialog com Bíblia local
5. Sistema de Anotações com debounce de 500ms
6. Personalização de Fontes, Versão da Bíblia e Categoria (Adultos vs Jovens)
7. Roteamento em AppRouter e integração com SelecaoView / Settings
"""

from __future__ import annotations

import asyncio
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import flet as ft
import httpx
import pytest

from src.database.connection import DatabaseConnection
from src.models.biblia import PassagemBiblica, Versiculo
from src.models.escola_sabatina import SSDay, SSLesson, SSQuarterly, SSUserNote
from src.repositories.biblia_repository import BibliaRepository
from src.repositories.escola_sabatina_repository import EscolaSabatinaRepository
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.views.escola_sabatina_view import EscolaSabatinaView
from src.views.selecao_view import SelecaoView
from main import AppRouter, AppViews, ROUTE_ESCOLA_SABATINA


# ===========================================================================
# 1. Testes de Modelos
# ===========================================================================

def test_models_serialization_and_category_deduction():
    # Adultos
    q_adult = SSQuarterly.from_dict({
        "id": "pt-2024-03",
        "title": "O Evangelho de Marcos",
        "description": "Estudo profundo",
        "human_date": "3º Trimestre 2024",
    })
    assert q_adult.category == "adultos"
    assert q_adult.to_dict()["id"] == "pt-2024-03"

    # Jovens (detectado por 'cq')
    q_jovem = SSQuarterly.from_dict({
        "id": "pt-cq-2024-03",
        "title": "A Jornada da Fé",
        "description": "Lição Jovem",
    })
    assert q_jovem.category == "jovens"

    # Lição
    lesson = SSLesson.from_dict({
        "id": "pt-2024-03-01",
        "index": "01",
        "title": "Começo de Tudo",
    }, quarterly_id="pt-2024-03")
    assert lesson.quarterly_id == "pt-2024-03"
    assert lesson.to_dict()["title"] == "Começo de Tudo"

    # Dia
    day = SSDay.from_dict({
        "id": "pt-2024-03-01-01",
        "title": "Sábado à tarde",
        "date": "29/06/2024",
        "content": "# Introdução",
    }, lesson_id="pt-2024-03-01")
    assert day.lesson_id == "pt-2024-03-01"
    assert day.content == "# Introdução"

    # Anotação
    note = SSUserNote.from_dict({
        "day_id": "pt-2024-03-01-01",
        "note_text": "Minha reflexão",
    })
    assert note.day_id == "pt-2024-03-01-01"
    assert note.note_text == "Minha reflexão"


# ===========================================================================
# 2. Testes de Repositório (SQLite)
# ===========================================================================

@pytest.mark.asyncio
async def test_repository_crud_operations():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)

    # 1. Salvar e listar trimestres
    q1 = SSQuarterly(id="pt-2024-03", title="Lição Adultos", category="adultos")
    q2 = SSQuarterly(id="pt-cq-2024-03", title="Lição Jovens", category="jovens")
    await repo.save_quarterly(q1)
    await repo.save_quarterly(q2)

    adults = await repo.list_quarterlies(category="adultos")
    assert len(adults) == 1
    assert adults[0].id == "pt-2024-03"

    jovens = await repo.list_quarterlies(category="jovens")
    assert len(jovens) == 1
    assert jovens[0].id == "pt-cq-2024-03"

    # 2. Salvar e recuperar lição
    l1 = SSLesson(id="pt-2024-03-01", quarterly_id="pt-2024-03", index="01", title="Lição 1")
    await repo.save_lesson(l1)
    fetched_l = await repo.get_lesson("pt-2024-03-01")
    assert fetched_l is not None
    assert fetched_l.title == "Lição 1"

    # 3. Salvar e recuperar dia
    d1 = SSDay(
        id="pt-2024-03-01-01",
        lesson_id="pt-2024-03-01",
        index="01",
        title="Sábado",
        date="29/06/2024",
        content="<p>Texto do dia</p>",
    )
    await repo.save_day(d1)
    fetched_d = await repo.get_day("pt-2024-03-01-01")
    assert fetched_d is not None
    assert fetched_d.title == "Sábado"
    assert await repo.is_day_cached("pt-2024-03-01-01") is True
    assert await repo.is_lesson_cached("pt-2024-03-01") is True

    # 4. Salvar, recuperar e atualizar anotação pessoal
    assert await repo.get_note("pt-2024-03-01-01") is None
    await repo.save_note("pt-2024-03-01-01", "Primeira nota pessoal")
    assert await repo.get_note("pt-2024-03-01-01") == "Primeira nota pessoal"

    # Atualização
    await repo.save_note("pt-2024-03-01-01", "Nota editada")
    assert await repo.get_note("pt-2024-03-01-01") == "Nota editada"

    # Exclusão
    await repo.delete_note("pt-2024-03-01-01")
    assert await repo.get_note("pt-2024-03-01-01") is None


# ===========================================================================
# 3. Testes do Serviço e Cache Local de Imagens
# ===========================================================================

@pytest.mark.asyncio
async def test_service_image_extraction_and_cache(tmp_path: Path):
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)

    # Simula cliente HTTP que retorna imagem fake
    async def fake_handler(request: httpx.Request):
        if "tirinha.png" in request.url.path:
            return httpx.Response(200, content=b"\x89PNGfake_image_bytes")
        if "ilustracao.jpg" in request.url.path:
            return httpx.Response(200, content=b"\xff\xd8fake_jpg_bytes")
        return httpx.Response(404)

    transport = httpx.MockTransport(fake_handler)
    client = httpx.AsyncClient(transport=transport)

    service = EscolaSabatinaService(
        repository=repo,
        http_client=client,
        cache_dir=tmp_path,
    )

    # 1. Extração de URLs em HTML e Markdown
    content_sample = """
    # Estudo de Domingo
    Aqui está a tirinha da lição:
    <img src="https://adventech.io/images/tirinha.png" alt="Tirinha">
    E outra ilustração:
    ![Ilustração](https://adventech.io/images/ilustracao.jpg)
    """
    urls = service.extract_image_urls(content_sample)
    assert len(urls) == 2
    assert "https://adventech.io/images/tirinha.png" in urls
    assert "https://adventech.io/images/ilustracao.jpg" in urls

    # 2. Processamento e download com substituição de URLs por caminhos locais
    processed = await service.process_and_cache_images(content_sample)
    assert "https://adventech.io/images/tirinha.png" not in processed
    assert "https://adventech.io/images/ilustracao.jpg" not in processed
    assert "ss_img_" in processed
    assert (tmp_path / "escola_sabatina" / "images").exists()

    # 3. Normalização para sintaxe nativa Markdown
    normalized = service.normalize_markdown_images(processed)
    assert "<img" not in normalized
    assert "![imagem](" in normalized


@pytest.mark.asyncio
async def test_download_week_lesson_and_quarter_offline(tmp_path: Path):
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)

    # Mock completo da API Adventech
    async def adventech_mock(request: httpx.Request):
        url = str(request.url)
        if url.endswith("/quarterlies/pt-2024-03/index.json"):
            return httpx.Response(200, json={
                "quarterly": {"id": "pt-2024-03", "title": "Marcos"},
                "lessons": [{"id": "pt-2024-03-01", "title": "Lição 1", "index": "01"}],
            })
        if url.endswith("/lessons/pt-2024-03-01/index.json"):
            return httpx.Response(200, json={
                "lesson": {"id": "pt-2024-03-01", "title": "Lição 1"},
                "days": [
                    {
                        "id": "pt-2024-03-01-01",
                        "title": "Sábado à Tarde",
                        "date": "29/06/2024",
                        "index": "01",
                        "read_path": "pt/2024-03/01/01/read",
                    },
                    {
                        "id": "pt-2024-03-01-02",
                        "title": "Domingo",
                        "date": "30/06/2024",
                        "index": "02",
                        "read_path": "pt/2024-03/01/02/read",
                    },
                ],
            })
        if "read/index.json" in url:
            return httpx.Response(200, json={
                "content": "<p>Leitura com <img src='https://adventech.io/strip.png'></p>"
            })
        if "strip.png" in url:
            return httpx.Response(200, content=b"fake_strip_image")
        return httpx.Response(404)

    client = httpx.AsyncClient(transport=httpx.MockTransport(adventech_mock))
    service = EscolaSabatinaService(repository=repo, http_client=client, cache_dir=tmp_path)

    progress_events: list[tuple[float, str]] = []
    def on_progress(p, msg):
        progress_events.append((p, msg))

    # Executa download da semana
    success = await service.download_week_lesson(
        quarterly_id="pt-2024-03",
        lesson_id="pt-2024-03-01",
        lang="pt",
        progress_callback=on_progress,
    )
    assert success is True
    assert len(progress_events) >= 2

    # Verifica persistência offline no SQLite
    day1 = await repo.get_day("pt-2024-03-01-01")
    assert day1 is not None
    assert "https://adventech.io/strip.png" not in day1.content
    assert "ss_img_" in day1.content

    # Executa download do trimestre inteiro
    quarter_success = await service.download_entire_quarter(
        quarterly_id="pt-2024-03",
        lang="pt",
    )
    assert quarter_success is True


# ===========================================================================
# 4. Testes de Interceptação de Versículos com VerseDialog
# ===========================================================================

@pytest.mark.asyncio
async def test_bible_link_extraction_and_verse_dialog():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)
    service = EscolaSabatinaService(repo)

    mock_biblia = MagicMock(spec=BibliaRepository)
    mock_passagem = PassagemBiblica(
        referencia="João 3:16",
        livro="João",
        capitulo=3,
        versiculos=[Versiculo(livro="João", capitulo=3, numero=16, texto="Porque Deus amou o mundo...")],
    )
    mock_biblia.buscar_passagem = AsyncMock(return_value=mock_passagem)

    view = EscolaSabatinaView(service=service, biblia_repository=mock_biblia)

    # 1. Extração de múltiplos formatos de bible://
    assert view._extract_bible_reference("bible://Jo3:16") == ("Jo", 3, 16)
    assert view._extract_bible_reference("bible://1Pe1:20") == ("1Pe", 1, 20)
    assert view._extract_bible_reference("bible://1Cor13:4-7") == ("1Cor", 13, 4)
    assert view._extract_bible_reference("bible://Mat.5.3") == ("Mat", 5, 3)
    assert view._extract_bible_reference("bible://João+3:16") == ("João", 3, 16)
    assert view._extract_bible_reference("https://site.com") is None

    # 2. Exibição do VerseDialog flutuante
    mock_page = MagicMock(spec=ft.Page)
    mock_page.open = MagicMock()
    mock_page.go = MagicMock()
    view.page = mock_page
    view.bible_version = "NVI"

    await view._show_floating_verse_dialog("João", 3, 16)
    mock_biblia.buscar_passagem.assert_called_once_with("João 3:16", versao="NVI")
    mock_page.open.assert_called_once()


# ===========================================================================
# 5. Testes de Anotações Pessoais com Debounce de 500ms
# ===========================================================================

@pytest.mark.asyncio
async def test_personal_notes_auto_save_with_debounce():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)
    service = EscolaSabatinaService(repo)

    # Cria dia no banco
    d = SSDay(id="day-test-1", lesson_id="lesson-1", title="Dia Teste", date="01/01/2025", content="Texto")
    await repo.save_day(d)

    view = EscolaSabatinaView(service=service)
    view.current_day = d
    view.note_status_text = ft.Text("")

    # Simula evento on_change
    mock_event = MagicMock()
    mock_event.control.value = "Pensamento rápido 1"
    view._on_note_change(mock_event)

    assert view.note_status_text.value == "Salvando..."
    first_task = view._note_debounce_task

    # Digita novamente antes de 500ms
    mock_event.control.value = "Pensamento final consolidado"
    view._on_note_change(mock_event)

    # Primeira tarefa deve ter sido cancelada
    assert first_task.cancelling() or first_task.cancelled()

    # Aguarda o debounce de 500ms
    await asyncio.sleep(0.6)

    # Verifica se foi salvo no SQLite
    saved_note = await repo.get_note("day-test-1")
    assert saved_note == "Pensamento final consolidado"
    assert view.note_status_text.value == "Salvo ✓"


# ===========================================================================
# 6. Testes de Personalização (Fontes, Bíblia, Categoria Adultos/Jovens)
# ===========================================================================

@pytest.mark.asyncio
async def test_customization_and_category_switching():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)
    service = EscolaSabatinaService(repo)

    # Dados prévios
    q_adult = SSQuarterly(id="q-adult", title="Adultos", category="adultos")
    q_jovem = SSQuarterly(id="q-jovem", title="Jovens", category="jovens")
    await repo.save_quarterly(q_adult)
    await repo.save_quarterly(q_jovem)

    l_adult = SSLesson(id="l-adult-1", quarterly_id="q-adult", title="Lição Adulto 1")
    l_jovem = SSLesson(id="l-jovem-1", quarterly_id="q-jovem", title="Lição Jovem 1")
    await repo.save_lesson(l_adult)
    await repo.save_lesson(l_jovem)

    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.update = MagicMock()
    mock_page.run_task = MagicMock(side_effect=lambda fn, *args: asyncio.create_task(fn(*args)))

    view.build(mock_page)
    await view._load_initial_data()

    # Categoria padrão: Adultos
    assert view.category == "adultos"
    assert view.current_quarterly.id == "q-adult"

    # Alterna para Jovens
    await view._on_category_change("jovens")
    assert view.category == "jovens"
    assert view.current_quarterly.id == "q-jovem"

    # Personalização de fontes e versão bíblica
    view.font_size = 20
    view.font_family_key = "Montserrat"
    view.bible_version = "NVI"
    await view._save_preferences()

    mock_page.client_storage.set_async.assert_any_call("ss_font_size", 20)
    mock_page.client_storage.set_async.assert_any_call("ss_font_family", "Montserrat")
    mock_page.client_storage.set_async.assert_any_call("preferred_bible_version", "NVI")


# ===========================================================================
# 7. Testes de Roteamento e Hub Inicial
# ===========================================================================

@pytest.mark.asyncio
async def test_router_and_selecao_view_integration():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)
    service = EscolaSabatinaService(repo)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.route = ROUTE_ESCOLA_SABATINA
    mock_page.views = []
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value="jovens")
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.update = MagicMock()
    mock_page.run_task = MagicMock(side_effect=lambda fn, *args: None)

    # 1. SelecaoView possui card da Escola Sabatina
    mock_theme_service = MagicMock()
    mock_theme_service.apply_theme = MagicMock()
    selecao_view = SelecaoView(theme_service=mock_theme_service)
    view_selecao = selecao_view.build(mock_page)
    assert selecao_view.escola_sabatina_subtitle_text is not None
    assert "Lição" in selecao_view.escola_sabatina_subtitle_text.value

    # 2. AppRouter despacha para EscolaSabatinaView
    router = AppRouter(
        page=mock_page,
        connections=(db_conn,),
        escola_sabatina_service=service,
        escola_sabatina_repo=repo,
    )

    await router.route_change(None)
    assert len(mock_page.views) == 2
    assert mock_page.views[-1].route == ROUTE_ESCOLA_SABATINA


# ===========================================================================
# 8. Testes Específicos de Tipografia e Formatação de Versículos
# ===========================================================================

@pytest.mark.asyncio
async def test_font_size_and_family_reactivity():
    db_conn = DatabaseConnection(db_path=":memory:")
    repo = EscolaSabatinaRepository(db_conn)
    service = EscolaSabatinaService(repo)

    d = SSDay(
        id="day-test-font",
        lesson_id="lesson-font",
        title="Estudo de Teste",
        date="15/09/2026",
        content="# Título\n\nTexto do estudo com [Lc 24](bible://Lucas 24).",
    )
    await repo.save_day(d)

    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.update = MagicMock()
    mock_page.run_task = MagicMock(side_effect=lambda fn, *args: asyncio.create_task(fn(*args)))

    view.build(mock_page)
    view.days = [d]
    view.current_day = d
    view._update_rendered_content()

    def get_md_ctrl() -> ft.Markdown:
        for c in view.content_container.controls:
            if isinstance(c, ft.Container) and isinstance(c.content, ft.Markdown):
                return c.content
        raise AssertionError("Markdown control not found in content_container")

    # 1. Verifica MarkdownStyleSheet inicial
    md_ctrl = get_md_ctrl()
    assert md_ctrl.md_style_sheet is not None
    assert md_ctrl.md_style_sheet.p_text_style.size == 16

    # 2. Aumentar fonte
    view._change_font_size(4)
    assert view.font_size == 20
    assert get_md_ctrl().md_style_sheet.p_text_style.size == 20

    # 3. Alterar família de fonte
    view._set_font_family("HymnSerif")
    assert view._current_font_family == "HymnSerif"
    assert get_md_ctrl().md_style_sheet.p_text_style.font_family == "HymnSerif"


    # 4. Diminuir e Restaurar
    view._change_font_size(-2)
    assert view.font_size == 18
    assert get_md_ctrl().md_style_sheet.p_text_style.size == 18
    view._reset_font_size()
    assert view.font_size == 16
    assert get_md_ctrl().md_style_sheet.p_text_style.size == 16



def test_bible_link_url_encoding_and_formatting():
    # 1. Normalização de links com espaços no destino
    raw_text = "Leia: [Lc 24](bible://Lucas 24) e ([Lc 24:5, 6](bible://Lucas 24:5))."
    normalized = EscolaSabatinaService.normalize_bible_links(raw_text)
    assert "bible://Lucas%2024" in normalized
    assert "bible://Lucas%2024%3A5" in normalized
    assert " " not in normalized.split("bible://")[1].split(")")[0]

    # 2. Conversão de HTML com múltiplas referências
    html_raw = '<p>Conferir <a class="verse" verse="Matt281">Mt 28:1-20; Mc 16:1-20; Jo 20:1-31</a> no texto.</p>'
    md = EscolaSabatinaService.html_to_markdown(html_raw)
    assert "[Mt 28:1-20](bible://Mt%2028%3A1-20)" in md
    assert "[Mc 16:1-20](bible://Mc%2016%3A1-20)" in md
    assert "[Jo 20:1-31](bible://Jo%2020%3A1-31)" in md

    # 3. Extração de capítulo completo (versículo = 0)
    view = EscolaSabatinaView(service=MagicMock())
    ref_chap = view._extract_bible_reference("bible://Lucas%2024")
    assert ref_chap == ("Lucas", 24, 0)

    # 4. Extração com versículo específico
    ref_verse = view._extract_bible_reference("bible://Lucas%2024%3A5")
    assert ref_verse == ("Lucas", 24, 5)


def test_day_bible_refs_extraction_and_order():
    """Valida extração de todas as referências bíblicas da lição do dia em ordem de aparição e sem duplicatas."""
    content = """
    Como as passagens acrescentam informações a [Lucas 24](bible://Lucas%2024)?
    Compare relatos: [Mt 28:1-20](bible://Mt%2028%3A1-20); [Mc 16:1-20](bible://Mc%2016%3A1-20); [Jo 20:1-31](bible://Jo%2020%3A1-31).
    E ainda: [Lucas 24](bible://Lucas%2024) novamente.
    Significado: [Sl 16:10, 11; At 4:33](bible://Sl%2016%3A10%2C%2011%3B%20At%204%3A33).
    """
    view = EscolaSabatinaView(service=MagicMock())
    view.current_day = SSDay(
        id="04",
        lesson_id="12",
        index="4",
        title="comPARE",
        date="2026-09-17",
        content=content,
    )

    refs = view._get_all_day_bible_refs()
    expected = ["Lucas 24", "Mt 28:1-20", "Mc 16:1-20", "Jo 20:1-31", "Sl 16:10, 11", "At 4:33"]
    assert refs == expected


def test_find_bible_reference_group_consecutive():
    """Valida que clicar em qualquer texto de uma sequência correlata retorna todos os textos do grupo."""
    content = """
    Compare relatos paralelos: [Mt 28:1-20](bible://Mt%2028%3A1-20); [Mc 16:1-20](bible://Mc%2016%3A1-20); [Jo 20:1-31](bible://Jo%2020%3A1-31).
    Outro texto isolado: [Lucas 24](bible://Lucas%2024).
    Grupo em link único: [Sl 16:10, 11; At 4:33](bible://Sl%2016%3A10%2C%2011%3B%20At%204%3A33).
    """
    view = EscolaSabatinaView(service=MagicMock())
    view.current_day = SSDay(
        id="04",
        lesson_id="12",
        index="4",
        title="comPARE",
        date="2026-09-17",
        content=content,
    )

    # 1. Clicando no segundo texto do grupo (Mc 16:1-20)
    grp_mc = view._find_bible_reference_group("bible://Mc%2016%3A1-20")
    assert grp_mc == ["Mt 28:1-20", "Mc 16:1-20", "Jo 20:1-31"]

    # 2. Clicando no primeiro texto do grupo (Mt 28:1-20)
    grp_mt = view._find_bible_reference_group("bible://Mt%2028%3A1-20")
    assert grp_mt == ["Mt 28:1-20", "Mc 16:1-20", "Jo 20:1-31"]

    # 3. Clicando em texto isolado (Lucas 24)
    grp_iso = view._find_bible_reference_group("bible://Lucas%2024")
    assert grp_iso == ["Lucas 24"]

    # 4. Clicando em grupo codificado em link único com ';'
    grp_single_link = view._find_bible_reference_group("bible://Sl%2016%3A10%2C%2011%3B%20At%204%3A33")
    assert grp_single_link == ["Sl 16:10, 11", "At 4:33"]


@pytest.mark.asyncio
async def test_floating_verse_dialog_grouped_and_version_selector():
    """Valida abertura de modal com múltiplos textos correlatos e seletor de versões."""
    mock_biblia_repo = MagicMock(spec=BibliaRepository)
    mock_biblia_repo.get_available_versions.return_value = ["ARA", "NVI", "KJA"]

    from src.models.biblia import PassagemBiblica, Versiculo

    async def mock_buscar_passagem(ref, versao="ARA"):
        return PassagemBiblica(
            referencia=ref,
            livro=ref.split()[0],
            capitulo=1,
            versiculos=[Versiculo(livro=ref.split()[0], capitulo=1, numero=1, texto=f"Texto de {ref} em {versao}")],
        )

    mock_biblia_repo.buscar_passagem = AsyncMock(side_effect=mock_buscar_passagem)

    view = EscolaSabatinaView(service=MagicMock(), biblia_repository=mock_biblia_repo)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.overlay = []
    mock_page.open = MagicMock()
    mock_page.show_dialog = MagicMock()
    view.page = mock_page

    view.current_day = SSDay(
        id="04",
        lesson_id="12",
        index="4",
        title="comPARE",
        date="2026-09-17",
        content="[Mt 28:1-20](bible://Mt%2028%3A1-20); [Mc 16:1-20](bible://Mc%2016%3A1-20)",
    )

    # Abre o diálogo com a lista correlata
    await view._show_floating_verse_dialog(["Mt 28:1-20", "Mc 16:1-20"])

    assert mock_page.open.call_count >= 1 or mock_page.show_dialog.call_count >= 1 or len(mock_page.overlay) >= 1
    # Verifica que buscou os dois textos
    assert mock_biblia_repo.buscar_passagem.call_count == 2


def test_escola_sabatina_navigation_to_bible_with_context_bar():
    """Valida a montagem da URL para a Bíblia com referências da Escola Sabatina e a barra de contexto."""
    import urllib.parse
    from main import _parse_bible_route_query
    from src.views.biblia_view import make_devotional_context_bar, ReferenciaRelacionada

    all_refs = ["Lucas 24", "Mt 28:1-20", "Mc 16:1-20", "Jo 20:1-31"]
    refs_param = urllib.parse.quote("|".join(all_refs))
    origem_param = urllib.parse.quote("Escola Sabatina")
    route = f"/biblia?livro=Lucas&cap=24&ver=1&versao=ARA&refs={refs_param}&origem={origem_param}"

    livro, cap, ver, hino_id, med_refs = _parse_bible_route_query(route)
    assert livro == "Lucas"
    assert cap == 24
    assert ver == 1
    assert med_refs == all_refs

    # Barra de contexto da Escola Sabatina
    on_select_ref = MagicMock()
    refs_objs = [
        ReferenciaRelacionada(texto_formatado=r, livro="Lucas", capitulo=24, versiculo=1)
        for r in med_refs
    ]
    bar = make_devotional_context_bar(refs_objs, on_select_ref, titulo="Escola Sabatina")
    assert isinstance(bar, ft.Container)
    # Verifica que o título está correto
    title_texts = [
        ctrl.value
        for ctrl in bar.content.controls
        if isinstance(ctrl, ft.Text) and "Textos da Escola Sabatina:" in ctrl.value
    ]
    assert len(title_texts) == 1
    # Verifica ícone da Escola Sabatina
    icons = [
        ctrl
        for ctrl in bar.content.controls
        if isinstance(ctrl, ft.Icon)
        and (getattr(ctrl, "icon", None) == ft.Icons.SCHOOL_ROUNDED or getattr(ctrl, "name", None) == ft.Icons.SCHOOL_ROUNDED)
    ]
    assert len(icons) == 1


# ===========================================================================
# 9. Testes de Card da Lição, Bottom Sheet de 13 Lições e Download Trimestre
# ===========================================================================

def test_current_lesson_card_rendering_and_bottom_sheet():
    """Valida a renderização do card da lição atual e o bottom sheet de 13 lições."""
    service = MagicMock(spec=EscolaSabatinaService)
    view = EscolaSabatinaView(service=service)

    mock_page = MagicMock(spec=ft.Page)
    mock_page.overlay = []
    mock_page.show_dialog = MagicMock()
    view.page = mock_page

    # Quando não há lição selecionada
    empty_card = view._build_current_lesson_card()
    assert empty_card.visible is False

    # Define trimestre e lições
    q = SSQuarterly(id="pt-2024-03", title="Evangelho de Marcos", category="adultos")
    lessons = [
        SSLesson(
            id=f"pt-2024-03-{i:02d}",
            quarterly_id="pt-2024-03",
            index=f"{i:02d}",
            title=f"Lição {i}",
            start_date="01/07/2024",
            end_date="07/07/2024",
        )
        for i in range(1, 14)
    ]
    view.current_quarterly = q
    view.lessons = lessons
    view.current_lesson = lessons[0]

    # Card da lição
    card = view._build_current_lesson_card()
    assert card.visible is not False
    # Verifica que tem bordas arredondadas e estilo M3
    assert card.border_radius == 14

    # Abre bottom sheet com todas as lições
    view._show_all_lessons_bottom_sheet()
    assert mock_page.show_dialog.call_count == 1 or len(mock_page.overlay) >= 1


@pytest.mark.asyncio
async def test_download_entire_quarter_ui_flow():
    """Valida o fluxo de download do trimestre completo pela UI."""
    service = MagicMock(spec=EscolaSabatinaService)
    service.download_entire_quarter = AsyncMock(return_value=True)

    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.overlay = []
    mock_page.update = MagicMock()
    view.page = mock_page

    view.current_quarterly = SSQuarterly(id="pt-2024-03", title="Marcos")
    view.download_progress_bar = ft.ProgressBar(visible=False)

    await view._download_entire_quarter()
    service.download_entire_quarter.assert_called_once()
    call_args = service.download_entire_quarter.call_args
    assert call_args[0][0] == "pt-2024-03"
    assert call_args[1]["lang"] == "pt"
    assert callable(call_args[1]["progress_callback"])
    assert len(mock_page.overlay) >= 1  # SnackBar exibido


@pytest.mark.asyncio
async def test_escola_sabatina_sepia_reading_mode():
    """Valida aplicação de cores sépia na renderização do Markdown da Escola Sabatina."""
    service = MagicMock(spec=EscolaSabatinaService)
    mock_theme = MagicMock()
    mock_theme.get_current_reading_mode.return_value = "sepia"

    view = EscolaSabatinaView(service=service, theme_service=mock_theme)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    mock_page.client_storage.set_async = AsyncMock()
    mock_page.update = MagicMock()
    mock_page.run_task = MagicMock(side_effect=lambda fn, *args: asyncio.create_task(fn(*args)))

    view.build(mock_page)

    d = SSDay(
        id="day-sepia",
        lesson_id="lesson-1",
        title="Estudo Sépia",
        date="16/09/2026",
        content="Texto da lição em modo sépia",
    )
    view.days = [d]
    view.current_day = d
    view._update_rendered_content()

    def get_md_ctrl() -> ft.Markdown:
        for c in view.content_container.controls:
            if isinstance(c, ft.Container) and isinstance(c.content, ft.Markdown):
                return c.content
        raise AssertionError("Markdown control not found")

    md_ctrl = get_md_ctrl()
    # Em conformidade com Material 3, usa cor semântica ON_SURFACE para manter alto contraste
    # dinâmico tanto em modo claro, sépia ou escuro sem cores hardcoded
    assert md_ctrl.md_style_sheet.p_text_style.color == ft.Colors.ON_SURFACE
    assert md_ctrl.selectable is True


@pytest.mark.asyncio
async def test_escola_sabatina_composite_bible_reference_propagation():
    """Valida propagação automática do livro canônico em referências compostas (ex: Ap 7:4-8; 14:1)."""
    html_input = '<p>Leiam o texto de <a class="verse" verse="rev7:4">Ap 7:4-8; 14:1</a> com atenção.</p>'
    md = EscolaSabatinaService.html_to_markdown(html_input)

    # Garante que 'Ap' foi propagado para '14:1'
    assert "[Ap 7:4-8](bible://Ap%207%3A4-8)" in md
    assert "[14:1](bible://Ap%2014%3A1)" in md

    # Testa agrupamento na view
    service = MagicMock(spec=EscolaSabatinaService)
    view = EscolaSabatinaView(service=service)
    view._get_current_day_markdown = MagicMock(return_value=md)

    grp1 = view._find_bible_reference_group("Ap 7:4-8")
    assert len(grp1) == 2
    assert grp1[0] == "Ap 7:4-8"
    assert grp1[1] == "Ap 14:1"

    grp2 = view._find_bible_reference_group("14:1")
    assert len(grp2) == 2
    assert grp2[0] == "Ap 7:4-8"
    assert grp2[1] == "Ap 14:1"


@pytest.mark.asyncio
async def test_escola_sabatina_copy_day_study():
    """Valida formatação e cópia do estudo do dia via clipboard."""
    service = MagicMock(spec=EscolaSabatinaService)
    service.html_to_markdown = lambda html: "Texto formatado da lição."

    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.clipboard = MagicMock()
    mock_page.clipboard.set = MagicMock()
    mock_page.overlay = []
    view.page = mock_page

    view.current_quarterly = SSQuarterly(
        id="2026-q3",
        title="O Livro do Apocalipse",
        description="",
        start_date="2026-07-01",
        end_date="2026-09-30",
    )
    view.current_lesson = SSLesson(
        id="lesson-1",
        quarterly_id="2026-q3",
        title="Lição 1: O Selo de Deus",
        start_date="2026-07-01",
        end_date="2026-07-07",
        index="01",
    )
    view.current_day = SSDay(
        id="day-1",
        lesson_id="lesson-1",
        title="O Grande Conflito",
        date="21/09/2026",
        content="<p>Texto formatado da lição.</p>",
    )

    await view._copy_day_study()

    assert mock_page.clipboard.set.called
    copied_text = mock_page.clipboard.set.call_args[0][0]
    assert "📘 O Livro do Apocalipse" in copied_text
    assert "📖 Lição 1: O Selo de Deus" in copied_text
    assert "📅 O Grande Conflito (21/09/2026)" in copied_text
    assert "Texto formatado da lição." in copied_text
    assert "✨ Compartilhado via Kairós" in copied_text


def test_escola_sabatina_font_bar_no_duplicate_accessibility_button():
    """Valida que a barra de ferramentas da lição não duplica o botão de acessibilidade (Tt)."""
    service = MagicMock(spec=EscolaSabatinaService)
    view = EscolaSabatinaView(service=service)
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(return_value=None)
    mock_page.update = MagicMock()

    view.build(mock_page)

    d = SSDay(
        id="day-1",
        lesson_id="lesson-1",
        title="Estudo",
        date="21/09/2026",
        content="Texto",
    )
    view.days = [d]
    view.current_day = d
    view._update_rendered_content()

    # font_bar é o controle de índice 3 em content_container.controls
    font_bar = view.content_container.controls[3]
    assert isinstance(font_bar, ft.Row)

    # Sub-row com os botões de ação na direita
    actions_row = font_bar.controls[1]
    assert isinstance(actions_row, ft.Row)

    # Verifica que NÃO há ft.Icons.TEXT_FIELDS_ROUNDED na font_bar (fica apenas na appbar)
    icons = [btn.icon for btn in actions_row.controls if isinstance(btn, ft.IconButton)]
    assert ft.Icons.TEXT_FIELDS_ROUNDED not in icons
    assert ft.Icons.SHARE_ROUNDED in icons
    assert ft.Icons.TEXT_DECREASE in icons
    assert ft.Icons.TEXT_INCREASE in icons


def test_escola_sabatina_today_auto_focus():
    """Valida a resolução automática de today's date para SSDay."""
    from datetime import date
    view = EscolaSabatinaView(service=MagicMock())
    today_iso = date.today().strftime("%d/%m/%Y")
    days = [
        SSDay(id="d1", lesson_id="l1", title="Dia 1", date="01/01/2026"),
        SSDay(id="d_today", lesson_id="l1", title="Dia Hoje", date=today_iso),
        SSDay(id="d3", lesson_id="l1", title="Dia 3", date="31/12/2026"),
    ]
    resolved = view._find_current_day(days)
    assert resolved is not None
    assert resolved.id == "d_today"


def test_escola_sabatina_lesson_videos_metadata():
    """Valida metadados estruturados para Vídeo do Dia e Resumo da Semana."""
    service = EscolaSabatinaService(MagicMock())
    videos = service.get_lesson_videos(
        lesson_title="01 - A Mensagem do Santuário",
        day_title="Domingo - O Cordeiro",
        category="adultos",
    )
    assert "video_do_dia" in videos
    assert "resumo_semana" in videos
    assert videos["video_do_dia"]["title"] == "Vídeo do Dia"
    assert videos["resumo_semana"]["title"] == "Resumo da Semana"
    assert "youtube.com" in videos["video_do_dia"]["url"]
    assert "Adventismo Vivo" in videos["resumo_semana"]["channel"]


@pytest.mark.asyncio
async def test_escola_sabatina_category_persistence():
    """Valida persistência e recuperação da chave preferred_ss_category."""
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(side_effect=lambda k: "jovens" if k == "preferred_ss_category" else None)
    mock_page.client_storage.set_async = AsyncMock()

    view = EscolaSabatinaView(service=MagicMock())
    view.page = mock_page
    await view._load_preferences()
    assert view.category == "jovens"

    view.category = "adultos"
    await view._save_preferences()
    set_calls = [c[0] for c in mock_page.client_storage.set_async.call_args_list]
    assert any("preferred_ss_category" in c and "adultos" in c for c in set_calls)



