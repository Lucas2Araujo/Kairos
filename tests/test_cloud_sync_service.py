from unittest.mock import AsyncMock, MagicMock
import pytest

from src.database.connection import DatabaseConnection
from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.services.auth_service import AuthService
from src.services.cloud_sync_service import CloudSyncService


@pytest.fixture
def mock_auth_service():
    service = MagicMock(spec=AuthService)
    user_mock = MagicMock()
    user_mock.id = "12345678-1234-1234-1234-123456789abc"
    user_mock.email = "usuario@teste.com"
    user_mock.user_metadata = {"full_name": "Usuário Teste", "avatar_url": "https://avatar.com/img.png"}
    service.get_current_user.return_value = user_mock

    client_mock = MagicMock()
    service.auth_client = client_mock
    return service


@pytest.mark.asyncio
async def test_cloud_sync_unauthenticated():
    auth_service = MagicMock(spec=AuthService)
    auth_service.get_current_user.return_value = None

    sync_service = CloudSyncService(auth_service=auth_service)

    assert await sync_service.sync_profile() is False
    assert await sync_service.push_favorite("hymn", 10) is False
    assert await sync_service.pull_favorites() == []
    assert await sync_service.push_history("hymn", 10) is False
    assert await sync_service.push_verse_highlight("GEN", 1, 1) is False


@pytest.mark.asyncio
async def test_cloud_sync_profile(mock_auth_service):
    sync_service = CloudSyncService(auth_service=mock_auth_service)
    client_mock = mock_auth_service.auth_client
    table_mock = MagicMock()
    client_mock.table.return_value = table_mock

    res = await sync_service.sync_profile()
    assert res is True
    client_mock.table.assert_called_with("profiles")
    table_mock.upsert.assert_called_once()
    args, kwargs = table_mock.upsert.call_args
    assert args[0]["id"] == "12345678-1234-1234-1234-123456789abc"
    assert args[0]["full_name"] == "Usuário Teste"
    assert kwargs.get("on_conflict") == "id"


@pytest.mark.asyncio
async def test_cloud_sync_push_favorite(mock_auth_service):
    sync_service = CloudSyncService(auth_service=mock_auth_service)
    client_mock = mock_auth_service.auth_client
    table_mock = MagicMock()
    client_mock.table.return_value = table_mock

    res = await sync_service.push_favorite("hymn", 42, is_deleted=False)
    assert res is True
    client_mock.table.assert_called_with("user_favorites")
    table_mock.upsert.assert_called_once()
    args, kwargs = table_mock.upsert.call_args
    assert args[0]["item_id"] == "42"
    assert args[0]["item_type"] == "hymn"
    assert args[0]["is_deleted"] is False
    assert kwargs.get("on_conflict") == "user_id,item_type,item_id"


@pytest.mark.asyncio
async def test_cloud_sync_pull_favorites(mock_auth_service, in_memory_db):
    fav_repo = FavoritoRepository(in_memory_db)
    sync_service = CloudSyncService(auth_service=mock_auth_service, fav_repo_novo=fav_repo)

    client_mock = mock_auth_service.auth_client
    table_mock = MagicMock()
    client_mock.table.return_value = table_mock

    query_mock = MagicMock()
    table_mock.select.return_value = query_mock
    query_mock.eq.return_value = query_mock
    exec_res = MagicMock()
    exec_res.data = [
        {"item_type": "hymn", "item_id": "1", "is_deleted": False},
        {"item_type": "hymn", "item_id": "2", "is_deleted": True},
    ]
    query_mock.execute.return_value = exec_res

    # Pré-popula favorito 2 no banco local para testar a remoção
    await fav_repo.add_favorito(2)
    assert await fav_repo.is_favorito(2) is True

    pulled = await sync_service.pull_favorites()
    assert len(pulled) == 2

    # Hino 1 deve ter sido adicionado e hino 2 removido
    assert await fav_repo.is_favorito(1) is True
    assert await fav_repo.is_favorito(2) is False


@pytest.mark.asyncio
async def test_cloud_sync_push_history(mock_auth_service):
    sync_service = CloudSyncService(auth_service=mock_auth_service)
    client_mock = mock_auth_service.auth_client
    table_mock = MagicMock()
    client_mock.table.return_value = table_mock

    res = await sync_service.push_history("devotional", "2026-09-22", title="Meditação Jovem")
    assert res is True
    client_mock.table.assert_called_with("reading_history")
    table_mock.insert.assert_called_once()
    args, _ = table_mock.insert.call_args
    assert args[0]["item_type"] == "devotional"
    assert args[0]["item_id"] == "2026-09-22"
    assert args[0]["title"] == "Meditação Jovem"


@pytest.mark.asyncio
async def test_cloud_sync_push_verse_highlight(mock_auth_service):
    sync_service = CloudSyncService(auth_service=mock_auth_service)
    client_mock = mock_auth_service.auth_client
    table_mock = MagicMock()
    client_mock.table.return_value = table_mock

    res = await sync_service.push_verse_highlight("JHN", 3, 16, color="#4CAF50", note="Amor de Deus")
    assert res is True
    client_mock.table.assert_called_with("verse_highlights")
    table_mock.upsert.assert_called_once()
    args, kwargs = table_mock.upsert.call_args
    assert args[0]["book_id"] == "JHN"
    assert args[0]["chapter"] == 3
    assert args[0]["verse"] == 16
    assert args[0]["color"] == "#4CAF50"
    assert args[0]["note"] == "Amor de Deus"
    assert kwargs.get("on_conflict") == "user_id,book_id,chapter,verse"


@pytest.mark.asyncio
async def test_cloud_sync_repository_callbacks(mock_auth_service, in_memory_db):
    fav_repo = FavoritoRepository(in_memory_db)
    hist_repo = HistoricoRepository(in_memory_db)

    sync_service = CloudSyncService(
        auth_service=mock_auth_service,
        fav_repo_novo=fav_repo,
        hist_repo_novo=hist_repo,
    )

    sync_service.push_favorite = AsyncMock()
    sync_service.push_history = AsyncMock()

    fav_repo.on_change_sync_callback = sync_service.push_favorite
    hist_repo.on_access_sync_callback = sync_service.push_history

    await fav_repo.add_favorito(100)
    sync_service.push_favorite.assert_called_with("hymn", 100, False)

    await fav_repo.remove_favorito(100)
    sync_service.push_favorite.assert_called_with("hymn", 100, True)

    await hist_repo.add_acesso(100, "Castelo Forte")
    sync_service.push_history.assert_called_with("hymn", 100, "Castelo Forte")

