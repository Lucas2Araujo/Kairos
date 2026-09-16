"""
Testes unitários e de integração local para a Camada de Dados e Serviço de Meditação Diária (Sprint 2).
Valida:
- Persistência e CRUD em SQLite (cached_devotionals)
- Padrão Offline-First (Cache -> Nuvem -> Salva no Cache)
- Garbage Collector / Limpeza automática de registros antigos (> 7 dias)
- Exclusão seletiva e individual por data
"""

from __future__ import annotations

from datetime import date, timedelta
from unittest.mock import AsyncMock, MagicMock
import httpx
import pytest

from src.database.connection import DatabaseConnection
from src.database.devotional_repo import DevotionalRepository
from src.models.devotional import Devotional
from src.services.devotional_service import DevotionalService


@pytest.fixture
def devotional_sample() -> Devotional:
    return Devotional(
        published_at="2026-09-16",
        title="O Deus da Esperança",
        verse_text="Ora, o Deus de esperança vos encha de todo o gozo e paz...",
        verse_reference="Rm 15:13",
        content="Texto completo da meditação do dia com reflexão inspiradora.",
        author="Ellen G. White",
        source_url="https://mais.cpb.com.br/meditacao/o-deus-da-esperanca",
    )


@pytest.mark.asyncio
async def test_devotional_repo_crud_and_upsert(in_memory_db: DatabaseConnection, devotional_sample: Devotional):
    repo = DevotionalRepository(in_memory_db)

    # 1. Busca inexistente
    item = await repo.get_by_date("2026-09-16")
    assert item is None

    # 2. Salvar (Insert)
    saved = await repo.save(devotional_sample)
    assert saved is True

    # 3. Recuperar
    loaded = await repo.get_by_date("2026-09-16")
    assert loaded is not None
    assert loaded.title == "O Deus da Esperança"
    assert loaded.verse_reference == "Rm 15:13"
    assert loaded.author == "Ellen G. White"
    assert loaded.cached_at is not None

    # 4. Upsert (Atualização do mesmo dia)
    updated_sample = Devotional(
        published_at="2026-09-16",
        title="O Deus da Esperança - Título Atualizado",
        verse_text=devotional_sample.verse_text,
        verse_reference=devotional_sample.verse_reference,
        content="Novo conteúdo atualizado",
        author="Ellen G. White",
        source_url=devotional_sample.source_url,
    )
    saved_again = await repo.save(updated_sample)
    assert saved_again is True

    reloaded = await repo.get_by_date("2026-09-16")
    assert reloaded is not None
    assert reloaded.title == "O Deus da Esperança - Título Atualizado"
    assert reloaded.content == "Novo conteúdo atualizado"


@pytest.mark.asyncio
async def test_devotional_repo_get_recent_and_all(in_memory_db: DatabaseConnection):
    repo = DevotionalRepository(in_memory_db)

    today = date(2026, 9, 16)
    for i in range(10):
        d_date = (today - timedelta(days=i)).isoformat()
        dev = Devotional(
            published_at=d_date,
            title=f"Meditação Dia {i}",
            verse_text="Versículo",
            verse_reference="Salmo 23:1",
            content=f"Conteúdo {i}",
        )
        await repo.save(dev)

    # get_recent limitado a 7
    recent = await repo.get_recent(limit=7)
    assert len(recent) == 7
    assert recent[0].published_at == "2026-09-16"
    assert recent[1].published_at == "2026-09-15"

    # get_all_cached
    all_cached = await repo.get_all_cached()
    assert len(all_cached) == 10


@pytest.mark.asyncio
async def test_devotional_repo_deletion_and_garbage_collector(in_memory_db: DatabaseConnection):
    repo = DevotionalRepository(in_memory_db)

    today = date.today()
    # Cria uma recente (hoje)
    dev_today = Devotional(
        published_at=today.isoformat(),
        title="Meditação Hoje",
        verse_text="V1",
        verse_reference="Ref 1",
        content="Conteúdo",
    )
    # Cria uma de 3 dias atrás
    dev_3d = Devotional(
        published_at=(today - timedelta(days=3)).isoformat(),
        title="Meditação 3 dias atrás",
        verse_text="V2",
        verse_reference="Ref 2",
        content="Conteúdo",
    )
    # Cria uma de 10 dias atrás (antiga)
    dev_10d = Devotional(
        published_at=(today - timedelta(days=10)).isoformat(),
        title="Meditação 10 dias atrás",
        verse_text="V3",
        verse_reference="Ref 3",
        content="Conteúdo antigo",
    )
    # Cria uma de 20 dias atrás (muito antiga)
    dev_20d = Devotional(
        published_at=(today - timedelta(days=20)).isoformat(),
        title="Meditação 20 dias atrás",
        verse_text="V4",
        verse_reference="Ref 4",
        content="Conteúdo muito antigo",
    )

    await repo.save(dev_today)
    await repo.save(dev_3d)
    await repo.save(dev_10d)
    await repo.save(dev_20d)

    assert len(await repo.get_all_cached()) == 4

    # Exclusão individual
    deleted_single = await repo.delete_by_date(dev_3d.published_at)
    assert deleted_single is True
    assert await repo.get_by_date(dev_3d.published_at) is None
    assert len(await repo.get_all_cached()) == 3

    # Garbage collector: deletar com mais de 7 dias (deve remover 10d e 20d)
    purged_count = await repo.delete_older_than(days=7)
    assert purged_count == 2

    # Apenas dev_today deve sobrar
    remaining = await repo.get_all_cached()
    assert len(remaining) == 1
    assert remaining[0].published_at == dev_today.published_at

    # Limpar todo o cache
    cleared = await repo.clear_all()
    assert cleared == 1
    assert len(await repo.get_all_cached()) == 0


@pytest.mark.asyncio
async def test_devotional_service_offline_first(in_memory_db: DatabaseConnection):
    repo = DevotionalRepository(in_memory_db)

    mock_client = MagicMock(spec=httpx.AsyncClient)
    cloud_payload = [
        {
            "published_at": "2026-09-16",
            "title": "Meditação da Nuvem",
            "verse_text": "O Senhor é o meu pastor",
            "verse_reference": "Sl 23:1",
            "content": "Conteúdo vindo da nuvem",
            "author": "Pastor Convidado",
            "source_url": "https://mais.cpb.com.br/meditacao/salmo23",
        }
    ]
    mock_response = MagicMock(spec=httpx.Response)
    mock_response.status_code = 200
    mock_response.json.return_value = cloud_payload
    mock_client.get = AsyncMock(return_value=mock_response)

    service = DevotionalService(
        repository=repo,
        supabase_url="https://fake.supabase.co",
        supabase_anon_key="fake-anon-key",
        http_client=mock_client,
    )

    # 1. Primeira consulta: Cache MISS -> Busca na nuvem -> Salva no cache
    result = await service.get_devotional("2026-09-16")
    assert result is not None
    assert result.title == "Meditação da Nuvem"
    mock_client.get.assert_called_once()

    # Confirma que foi persistido no banco SQLite
    cached_in_db = await repo.get_by_date("2026-09-16")
    assert cached_in_db is not None
    assert cached_in_db.title == "Meditação da Nuvem"

    # 2. Segunda consulta: Cache HIT -> Não deve chamar a nuvem novamente
    mock_client.get.reset_mock()
    result_hit = await service.get_devotional("2026-09-16")
    assert result_hit is not None
    assert result_hit.title == "Meditação da Nuvem"
    mock_client.get.assert_not_called()

    # 3. Forçar atualização (force_refresh=True) -> Deve chamar a nuvem
    await service.get_devotional("2026-09-16", force_refresh=True)
    mock_client.get.assert_called_once()


@pytest.mark.asyncio
async def test_devotional_service_auto_cleanup_toggle(in_memory_db: DatabaseConnection):
    repo = DevotionalRepository(in_memory_db)
    service = DevotionalService(repository=repo)

    # Insere meditação antiga
    old_date = (date.today() - timedelta(days=15)).isoformat()
    await repo.save(
        Devotional(
            published_at=old_date,
            title="Antiga",
            verse_text="V",
            verse_reference="R",
            content="C",
        )
    )
    assert len(await repo.get_all_cached()) == 1

    # Quando o toggle está desabilitado (False), não deve purgar
    purged_disabled = await service.run_auto_cleanup(get_toggle_state=lambda: False)
    assert purged_disabled == 0
    assert len(await repo.get_all_cached()) == 1

@pytest.mark.asyncio
async def test_devotional_repo_multi_category_coexistence_and_delete(in_memory_db: DatabaseConnection):
    """Testa que duas meditações na mesma data com categorias diferentes coexistem na chave primária composta."""
    repo = DevotionalRepository(in_memory_db)
    target_date = "2026-09-16"

    dev_jovem = Devotional(
        published_at=target_date,
        title="Meditação Jovem",
        verse_text="Texto Jovem",
        verse_reference="Ref Jovem",
        content="Conteúdo Jovem",
        category="jovem",
    )
    dev_mulher = Devotional(
        published_at=target_date,
        title="Meditação Mulher",
        verse_text="Texto Mulher",
        verse_reference="Ref Mulher",
        content="Conteúdo Mulher",
        category="mulher",
    )

    await repo.save(dev_jovem)
    await repo.save(dev_mulher)

    # Ambas devem existir no banco
    loaded_jovem = await repo.get_by_date(target_date, category="jovem")
    loaded_mulher = await repo.get_by_date(target_date, category="mulher")

    assert loaded_jovem is not None
    assert loaded_jovem.title == "Meditação Jovem"
    assert loaded_jovem.category == "jovem"

    assert loaded_mulher is not None
    assert loaded_mulher.title == "Meditação Mulher"
    assert loaded_mulher.category == "mulher"

    # Exclusão seletiva por categoria
    deleted = await repo.delete_by_date(target_date, category="jovem")
    assert deleted is True

    # 'jovem' foi excluída, mas 'mulher' permanece intacta
    assert await repo.get_by_date(target_date, category="jovem") is None
    assert await repo.get_by_date(target_date, category="mulher") is not None

