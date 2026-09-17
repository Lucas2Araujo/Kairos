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
        "https://accounts.google.com/o/oauth2/v2/auth?client_id=123",
        web_popup_type=ft.WebPopupType.EXTERNAL,
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
async def test_auth_service_handle_auth_callback_code():
    """Verifica a troca de código de autorização (PKCE) por sessão via exchange_code_for_session."""
    mock_auth_client = MagicMock()
    mock_session = MagicMock()
    mock_session.access_token = "pkce_access_token_123"
    mock_session.refresh_token = "pkce_refresh_token_456"

    mock_res = MagicMock()
    mock_res.session = mock_session
    mock_auth_client.auth.exchange_code_for_session.return_value = mock_res

    mock_page = MagicMock(spec=ft.Page)
    mock_page.client_storage = MagicMock()
    mock_page.client_storage.set_async = AsyncMock()

    service = AuthService(auth_client=mock_auth_client)

    callback_url = "/login-callback?code=test_auth_code_pkce"
    success = await service.handle_auth_callback(callback_url, mock_page)

    assert success is True
    mock_auth_client.auth.exchange_code_for_session.assert_called_once_with(
        {"auth_code": "test_auth_code_pkce"}
    )
    mock_auth_client.auth.set_session.assert_called_once_with(
        "pkce_access_token_123", "pkce_refresh_token_456"
    )


def test_desktop_oauth_handler_code_and_tokens():
    """Verifica se _DesktopOAuthHandler despacha code e tokens corretamente."""
    from io import BytesIO
    from src.services.auth_service import _DesktopOAuthHandler

    mock_server = MagicMock()
    mock_server.on_code_received = MagicMock()
    mock_server.on_tokens_received = MagicMock()

    # 1. Requisição com code=...
    handler = _DesktopOAuthHandler.__new__(_DesktopOAuthHandler)
    handler.server = mock_server
    handler.path = "/callback?code=sample_pkce_code"
    handler.rfile = BytesIO()
    handler.wfile = BytesIO()
    handler.send_response = MagicMock()
    handler.send_header = MagicMock()
    handler.end_headers = MagicMock()

    handler.do_GET()
    mock_server.on_code_received.assert_called_once_with("sample_pkce_code")
    mock_server.on_tokens_received.assert_not_called()

    # 2. Requisição com access_token e refresh_token
    mock_server.reset_mock()
    handler.path = "/callback?access_token=acc1&refresh_token=ref2"
    handler.wfile = BytesIO()

    handler.do_GET()
    mock_server.on_tokens_received.assert_called_once_with("acc1", "ref2")
    mock_server.on_code_received.assert_not_called()


def test_desktop_oauth_server_on_code_received():
    """Verifica se _DesktopOAuthServer.on_code_received troca código via Supabase."""
    from src.services.auth_service import _DesktopOAuthServer

    mock_auth_client = MagicMock()
    mock_session = MagicMock()
    mock_session.access_token = "srv_acc"
    mock_session.refresh_token = "srv_ref"
    mock_res = MagicMock(session=mock_session)
    mock_auth_client.auth.exchange_code_for_session.return_value = mock_res

    mock_on_success = MagicMock()
    server = _DesktopOAuthServer.__new__(_DesktopOAuthServer)
    server.auth_client = mock_auth_client
    server.on_success_callback = mock_on_success
    server.on_code_received_callback = None
    server.is_completed = False
    server.shutdown_server = MagicMock()

    server.on_code_received("server_code_xyz")

    mock_auth_client.auth.exchange_code_for_session.assert_called_once_with(
        {"auth_code": "server_code_xyz"}
    )
    mock_on_success.assert_called_once_with("srv_acc", "srv_ref")


@pytest.mark.asyncio
async def test_app_router_route_change_with_code():
    """Verifica se AppRouter intercepta rota com code= e redireciona para /."""
    from main import AppRouter

    mock_page = MagicMock(spec=ft.Page)
    mock_page.views = []
    mock_page.route = "/?code=pkce_query_code"
    mock_auth_service = MagicMock()
    mock_auth_service.handle_auth_callback = AsyncMock(return_value=True)

    mock_views = MagicMock()
    mock_views.selecao_view.build.return_value = MagicMock(spec=ft.View)
    mock_content_manager = MagicMock()
    mock_content_manager.is_module_installed.return_value = True

    router = AppRouter(
        page=mock_page,
        connections=(),
        views=mock_views,
        content_manager=mock_content_manager,
        media_service=MagicMock(),
        theme_service=MagicMock(),
        ctx_novo=MagicMock(),
        ctx_antigo=MagicMock(),
        biblia_repository=MagicMock(),
        comparativo_repository=MagicMock(),
        auth_service=mock_auth_service,
    )

    await router.route_change()

    mock_auth_service.handle_auth_callback.assert_called_once_with(
        "/?code=pkce_query_code", mock_page
    )
    assert mock_page.route == "/"


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


@pytest.mark.asyncio
async def test_main_web_initialization_with_code():
    """Verifica se main() detecta page.web e page.query['code'] e conclui o login antes de carregar a UI."""
    from main import main as app_main

    mock_page = MagicMock(spec=ft.Page)
    mock_page.web = True
    mock_page.query = {"code": "web_pkce_code_123"}
    mock_page.route = "/"
    mock_page.views = []

    mock_theme_service = MagicMock()
    mock_theme_service.theme_engine.load_preferences = AsyncMock()
    mock_theme_service.load_preferences = AsyncMock()

    with patch("main.AuthService") as mock_auth_cls, \
         patch("main.DatabaseConnection"), \
         patch("main.ThemeService", return_value=mock_theme_service), \
         patch("main._setup_assets_and_theme"), \
         patch("main.ensure_page_dialogs"), \
         patch("main.AppRouter") as mock_router_cls, \
         patch("main.is_onboarding_completed", return_value=True), \
         patch("main._check_updates_background"):

        mock_auth_inst = MagicMock()
        mock_auth_inst.handle_auth_callback = AsyncMock(return_value=True)
        mock_auth_inst.restore_session = AsyncMock(return_value=True)
        mock_auth_cls.return_value = mock_auth_inst

        mock_router_inst = MagicMock()
        mock_router_inst.route_change = AsyncMock()
        mock_router_cls.return_value = mock_router_inst

        await app_main(mock_page)

        mock_auth_inst.handle_auth_callback.assert_called_once_with(
            "/?code=web_pkce_code_123", mock_page
        )


