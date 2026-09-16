import pytest
from unittest.mock import AsyncMock, MagicMock

from src.database.connection import DatabaseConnection
from src.models.biblia import PassagemBiblica, Versiculo
from src.models.culto import ItemLiturgico, PlanoCulto, TipoItemLiturgico
from src.models.hino import Hino
from src.repositories.biblia_repository import BibliaRepository
from src.repositories.culto_repository import CultoRepository
from src.repositories.hino_repository import HinoRepository
from src.services.agente_service import AgenteService
from src.services.hino_recommender import HinoRecommender, MatchReason, ScoredHino


@pytest.mark.asyncio
async def test_item_liturgico_polimorfismo():
    """Testa a criação e integridade polimórfica dos itens litúrgicos."""
    hino = Hino(id=1, numero="10", titulo="Grandioso És Tu", fonte="atual")
    item_hino = ItemLiturgico(
        ordem=1,
        tipo=TipoItemLiturgico.HINO,
        titulo_bloco="Louvor Inicial",
        descricao_momento="Momento de louvor",
        conteudo=hino,
        metadados={"fonte": "atual"},
    )
    assert item_hino.tipo == TipoItemLiturgico.HINO
    assert item_hino.conteudo.titulo == "Grandioso És Tu"

    item_oracao = ItemLiturgico(
        ordem=2,
        tipo=TipoItemLiturgico.ORACAO,
        titulo_bloco="Oração Pastoral",
        descricao_momento="Intercessão comunitária",
        conteudo="Clamor pelos enfermos",
        metadados={"foco": "intercessao"},
    )
    assert item_oracao.tipo == TipoItemLiturgico.ORACAO
    assert isinstance(item_oracao.conteudo, str)

    passagem = PassagemBiblica(
        referencia="Salmo 23:1-3",
        livro="Salmos",
        capitulo=23,
        versiculos=[Versiculo(livro="Salmos", capitulo=23, numero=1, texto="O Senhor é o meu pastor")],
    )
    item_leitura = ItemLiturgico(
        ordem=3,
        tipo=TipoItemLiturgico.LEITURA_BIBLICA,
        titulo_bloco="Leitura da Palavra",
        descricao_momento="Salmo 23",
        conteudo=passagem,
    )
    assert item_leitura.tipo == TipoItemLiturgico.LEITURA_BIBLICA
    assert item_leitura.conteudo.referencia == "Salmo 23:1-3"


@pytest.mark.asyncio
async def test_templates_liturgicos(in_memory_db: DatabaseConnection):
    """Testa a geração de ordens de culto nos diferentes templates litúrgicos."""
    hino_repo = HinoRepository(in_memory_db)
    agente = AgenteService(hino_repo)

    # Template Geral
    res_geral = await agente.sugerir_playlist_culto(
        "Fé e Santidade", num_hinos=4, template="geral"
    )
    assert res_geral["template"] == "geral"
    tipos_geral = [it.tipo for it in res_geral["itens"]]
    assert TipoItemLiturgico.ORACAO in tipos_geral
    assert TipoItemLiturgico.HINO in tipos_geral
    assert TipoItemLiturgico.PREGACAO in tipos_geral
    assert TipoItemLiturgico.LEITURA_BIBLICA in tipos_geral

    # Template Oração
    res_oracao = await agente.sugerir_playlist_culto(
        "Clamor e Intercessão", num_hinos=4, template="oracao"
    )
    assert res_oracao["template"] == "oracao"
    tipos_oracao = [it.tipo for it in res_oracao["itens"]]
    assert TipoItemLiturgico.ORACAO in tipos_oracao
    assert TipoItemLiturgico.HINO in tipos_oracao
    # Oração de invocação e intercessão pastoral contextual
    oracoes_titulos = [it.titulo_bloco for it in res_oracao["itens"] if it.tipo == TipoItemLiturgico.ORACAO]
    assert any("Invocação" in t for t in oracoes_titulos)
    assert any("Intercessão" in t for t in oracoes_titulos)

    # Template Santa Ceia
    res_ceia = await agente.sugerir_playlist_culto(
        "Comunhão e Sacrifício", num_hinos=4, template="santa_ceia"
    )
    assert res_ceia["template"] == "santa_ceia"
    leituras_titulos = [it.titulo_bloco for it in res_ceia["itens"] if it.tipo == TipoItemLiturgico.LEITURA_BIBLICA]
    assert any("Instituição" in t for t in leituras_titulos)


@pytest.mark.asyncio
async def test_multiplos_hinarios_e_fonte(in_memory_db: DatabaseConnection):
    """Testa o suporte e metadados de fonte entre hinário atual e hinário antigo."""
    hino_atual = Hino(id=1, numero="1", titulo="Hino Novo", texto_base="Salmo 1", fonte="atual")
    hino_antigo = Hino(id=101, numero="1A", titulo="Hino Antigo", texto_base="Salmo 2", fonte="antigo")

    mock_hino_repo = AsyncMock(spec=HinoRepository)
    mock_hino_repo.search = AsyncMock(side_effect=lambda term, fonte="atual": [hino_antigo] if fonte == "antigo" else [hino_atual])
    mock_hino_repo.get_all = AsyncMock(side_effect=lambda fonte="atual": [hino_antigo] if fonte == "antigo" else [hino_atual])
    mock_hino_repo.get_all_complete = AsyncMock(side_effect=lambda fonte="atual": [hino_antigo] if fonte == "antigo" else [hino_atual])
    mock_hino_repo.get_metadados_relacionados = AsyncMock(return_value={"temas": ["Adoração"]})

    agente = AgenteService(hino_repository=mock_hino_repo)

    # Busca apenas no Hinário Atual
    res_atual = await agente.sugerir_playlist_culto("Louvor", num_hinos=4, fonte="atual")
    assert all(getattr(h, "fonte", "atual") == "atual" for h in res_atual["hinos"])

    # Busca em Ambos
    mock_hino_repo.search = AsyncMock(return_value=[hino_atual, hino_antigo])
    mock_hino_repo.get_all_complete = AsyncMock(return_value=[hino_atual, hino_antigo])
    agente_ambos = AgenteService(hino_repository=mock_hino_repo)
    res_ambos = await agente_ambos.sugerir_playlist_culto("Louvor", num_hinos=4, fonte="ambos")
    fontes = {getattr(h, "fonte", "atual") for h in res_ambos["hinos"]}
    assert "antigo" in fontes or "atual" in fontes


@pytest.mark.asyncio
async def test_leitura_biblica_automatica(in_memory_db: DatabaseConnection):
    """Testa a integração automática de leitura bíblica usando o texto_base dos hinos."""
    hino_repo = HinoRepository(in_memory_db)

    # Mock do repositório bíblico com passagem real
    mock_biblia = AsyncMock(spec=BibliaRepository)
    mock_passagem = PassagemBiblica(
        referencia="Apocalipse 4:8",
        livro="Apocalipse",
        capitulo=4,
        versiculos=[Versiculo(livro="Apocalipse", capitulo=4, numero=8, texto="Santo, Santo, Santo é o Senhor Deus")],
    )
    mock_biblia.buscar_passagem = AsyncMock(return_value=mock_passagem)

    agente = AgenteService(hino_repository=hino_repo, biblia_repository=mock_biblia)

    resultado = await agente.sugerir_playlist_culto("Santo e Majestade", num_hinos=4, template="geral")
    leituras = [it for it in resultado["itens"] if it.tipo == TipoItemLiturgico.LEITURA_BIBLICA]
    assert len(leituras) > 0

    # Verifica se a passagem resolvida foi injetada no conteúdo
    primeira_leitura = leituras[0]
    assert isinstance(primeira_leitura.conteudo, PassagemBiblica)
    assert primeira_leitura.conteudo.referencia == "Apocalipse 4:8"
    assert "Santo, Santo, Santo" in primeira_leitura.conteudo.texto_formatado


def test_scored_hino_justificativa_com_fonte():
    """Testa a geração de justificativa no ScoredHino distinguindo Hinário Antigo e Atual."""
    h_atual = Hino(id=1, numero="10", titulo="Hino Novo", fonte="atual")
    scored_atual = ScoredHino(
        hino=h_atual,
        score_total=10,
        reasons=[MatchReason(campo="Título", termo="novo", pontos=10, detalhe="Hino Novo")],
    )
    assert "[Hinário Antigo]" not in scored_atual.justificativa_legivel

    h_antigo = Hino(id=2, numero="10A", titulo="Hino Tradicional", fonte="antigo")
    scored_antigo = ScoredHino(
        hino=h_antigo,
        score_total=10,
        reasons=[MatchReason(campo="Título", termo="tradicional", pontos=10, detalhe="Hino Tradicional")],
    )
    assert "[Hinário Antigo]" in scored_antigo.justificativa_legivel

