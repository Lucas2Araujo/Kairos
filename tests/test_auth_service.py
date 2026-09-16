"""
Testes unitários para o módulo src/config/supabase_clients.py e src/services/auth_service.py.
Cobre os fluxos de autenticação multiplataforma (Android, Desktop e Web).
"""

from unittest.mock import AsyncMock, MagicMock, patch
import flet as ft
import pytest

from src.config.supabase_clients import get_auth_client, get_devotional_client
from src.services.auth_service import (
    DEFAULT_DESKTOP_REDIRECT_URI,
    STORAGE_KEY_ACCESS_TOKEN,
    STORAGE_KEY_REFRESH_TOKEN,
    AuthService,
)


def test_supabase_clients_validation_error():
    """Valida se lança ValueError quando as variáveis obrigatórias não estão configuradas."""
    with patch("src.config.supabase_clients.DEVOTIONAL_SUPABASE_URL", ""):
        with patch("src.config.supabase_clients.create_client", MagicMock()):
            with pytest.raises(ValueError, match="DEVOTIONAL_SUPABASE_URL"):
                get_devotional_client()

    with patch("src.config.supabase_clients.AUTH_SUPABASE_URL", ""):
        with patch("src.config.supabase_clients.create_client", MagicMock()):
            with pytest.raises(ValueError, match="AUTH_SUPABASE_URL"):
                get_auth_client()


def test_supabase_clients_creation_success():
    """Valida a instanciação bem-sucedida dos clientes quando as credenciais existem."""
    mock_create = MagicMock()
    with patch("src.config.supabase_clients.DEVOTIONAL_SUPABASE_URL", "https://devo.supabase.co"):
        with patch("src.config.supabase_clients.DEVOTIONAL_SUPABASE_ANON_KEY", "devo-anon-key"):
            with patch("src.config.supabase_clients.create_client", mock_create):
                get_devotional_client()
                mock_create.assert_called_with("https://devo.supabase.co", "devo-anon-key")

    mock_create.reset_mock()
    with patch("src.config.supabase_clients.AUTH_SUPABASE_URL", "https://auth.supabase.co"):
        with patch("src.config.supabase_clients.AUTH_SUPABASE_ANON_KEY", "auth-anon-key"):
            with patch("src.config.supabase_clients.create_client", mock_create):
                get_auth_client()
                mock_create.assert_called_with("https://auth.supabase.co", "auth-anon-key")


def test_auth_service_platform_redirect_uri():
    """Valida a determinação correta da Redirect URI para cada plataforma."""
    service = AuthService()

    # 1. Android / Mobile
    mock_page_android = MagicMock(spec=ft.Page)
    mock_page_android.web = False
    mock_page_android.platform = ft.PagePlatform.ANDROID
    assert service.get_redirect_uri(mock_page_android) == "nhaapp://login-callback"
    assert service.is_desktop_platform(mock_page_android) is False

    # 2. Desktop (Linux)
    mock_page_desktop = MagicMock(spec=ft.Page)
    mock_page_desktop.web = False
    mock_page_desktop.platform = ft.PagePlatform.LINUX
    assert service.get_redirect_uri(mock_page_desktop) == DEFAULT_DESKTOP_REDIRECT_URI
    assert service.is_desktop_platform(mock_page_desktop) is True

    # 3. Web
    mock_page_web = MagicMock(spec=ft.Page)
    mock_page_web.web = True
    mock_page_web.url = "https://meuhinario.app/subpath"
    assert service.get_redirect_uri(mock_page_web) == "https://meuhinario.app/"
    assert service.is_desktop_platform(mock_page_web) is False


@pytest.mark.asyncio
async def test_auth_service_initiate_google_login_mobile():
    """Verifica se initiate_google_login dispara oauth com deep link no Android."""
    mock_auth_client = MagicMock()
    mock_auth_res = MagicMock()
    mock_auth_res.url = "https://accounts.google.com/o/oauth2/v2/auth?client_id=123"
    mock_auth_client.auth.sign_in_with_oauth.return_value = mock_auth_res

    mock_page = MagicMock(spec=ft.Page)
    mock_page.web = False
    mock_page.platform = ft.PagePlatform.ANDROID
    mock_page.launch_url = MagicMock()

    service = AuthService(auth_client=mock_auth_client)

    with patch("src.services.auth_service.is_auth_supabase_configured", return_value=True):
        res = await service.initiate_google_login(mock_page)

    assert res is True
    mock_auth_client.auth.sign_in_with_oauth.assert_called_once_with(
        {
            "provider": "google",
            "options": {"redirect_to": "nhaapp://login-callback"},
        }
    )
    mock_page.launch_url.assert_called_once_with(
        "https://accounts.google.com/o/oauth2/v2/auth?client_id=123"
    )


@pytest.mark.asyncio
async def test_auth_service_initiate_google_login_desktop():
    """Verifica se initiate_google_login no Desktop inicia o servidor local e usa porta 8000."""
    mock_auth_client = MagicMock()
    mock_auth_res = MagicMock()
    mock_auth_res.url = "https://accounts.google.com/o/oauth2/v2/auth?client_id=desktop"
    mock_auth_client.auth.sign_in_with_oauth.return_value = mock_auth_res

    mock_page = MagicMock(spec=ft.Page)
    mock_page.web = False
    mock_page.platform = ft.PagePlatform.LINUX
    mock_page.launch_url = MagicMock()

    service = AuthService(auth_client=mock_auth_client)

    with patch("src.services.auth_service.is_auth_supabase_configured", return_value=True):
        with patch.object(service, "_start_desktop_oauth_server") as mock_start_server:
            res = await service.initiate_google_login(mock_page)

            assert res is True
            mock_start_server.assert_called_once_with(mock_page, None)
            mock_auth_client.auth.sign_in_with_oauth.assert_called_once_with(
                {
                    "provider": "google",
                    "options": {"redirect_to": DEFAULT_DESKTOP_REDIRECT_URI},
                }
            )


@pytest.mark.asyncio
async def test_auth_service_handle_auth_callback_fragment():
    """Verifica o parsing de token em fragmento (#) de deep link e armazenamento no storage."""
    mock_auth_client = MagicMock()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()

    service = AuthService(auth_client=mock_auth_client)

    callback_url = "nhaapp://login-callback#access_token=test_access_token_123&refresh_token=test_refresh_token_456&token_type=bearer"
    success = await service.handle_auth_callback(callback_url, mock_page)

    assert success is True
    mock_auth_client.auth.set_session.assert_called_once_with(
        "test_access_token_123", "test_refresh_token_456"
    )


@pytest.mark.asyncio
async def test_auth_service_handle_auth_callback_query():
    """Verifica o parsing de token em query string (?) e armazenamento no storage."""
    mock_auth_client = MagicMock()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()

    service = AuthService(auth_client=mock_auth_client)

    callback_url = "/login-callback?access_token=token_query_abc&refresh_token=token_query_xyz"
    success = await service.handle_auth_callback(callback_url, mock_page)

    assert success is True
    mock_auth_client.auth.set_session.assert_called_once_with(
        "token_query_abc", "token_query_xyz"
    )


@pytest.mark.asyncio
async def test_auth_service_restore_session():
    """Verifica se restaura sessão a partir dos tokens salvos no storage."""
    mock_auth_client = MagicMock()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.get_async = AsyncMock(
        side_effect=lambda key: "saved_acc" if key == STORAGE_KEY_ACCESS_TOKEN else "saved_ref"
    )

    service = AuthService(auth_client=mock_auth_client)
    restored = await service.restore_session(mock_page)

    assert restored is True
    mock_auth_client.auth.set_session.assert_called_once_with("saved_acc", "saved_ref")


@pytest.mark.asyncio
async def test_auth_service_logout():
    """Verifica se logout desloga no Supabase e limpa o storage."""
    mock_auth_client = MagicMock()
    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.remove_async = AsyncMock()

    service = AuthService(auth_client=mock_auth_client)
    await service.logout(mock_page)

    mock_auth_client.auth.sign_out.assert_called_once()
