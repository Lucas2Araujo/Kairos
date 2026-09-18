"""
Serviço de Autenticação Supabase via OAuth (Google) com suporte multiplataforma:
1. Android (APK): Deep Link com esquema customizado (ex: nhaapp://login-callback)
2. Desktop (Linux, Windows, macOS): Servidor HTTP local temporário (http://localhost:8000/callback)
   com ponte HTML/JavaScript para conversão de URL fragment (#) em query parameters (?)
3. Web (Navegador): Redirecionamento direto com captura de rota via Flet

URLs que devem estar configuradas no Supabase Console (Authentication -> URL Configuration -> Redirect URLs):
- nhaapp://login-callback
- http://localhost:8000/callback
- http://localhost:8550 (ou seu domínio de produção Web)
"""

from __future__ import annotations

import asyncio
from http.server import BaseHTTPRequestHandler, HTTPServer
import inspect
import logging
import threading
import urllib.parse
from typing import Any, Callable

import flet as ft

if not hasattr(ft, "WebPopupType"):
    class WebPopupType:
        EXTERNAL = "external"
        IN_APP = "in_app"

    setattr(ft, "WebPopupType", WebPopupType)

from src.config import AUTH_REDIRECT_URI, is_auth_supabase_configured
from src.config.supabase_clients import auth_client as default_auth_client, get_auth_client
from src.utils.storage_manager import storage_get, storage_set

logger = logging.getLogger(__name__)

STORAGE_KEY_ACCESS_TOKEN = "supabase_auth_access_token"
STORAGE_KEY_REFRESH_TOKEN = "supabase_auth_refresh_token"

DEFAULT_DESKTOP_CALLBACK_PORT = 8000
DEFAULT_DESKTOP_REDIRECT_URI = f"http://localhost:{DEFAULT_DESKTOP_CALLBACK_PORT}/callback"
CONTENT_TYPE_HTML_UTF8 = "text/html; charset=utf-8"

SUCCESS_HTML = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Login Conclu\u00eddo</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #121212;
            color: #ffffff;
            text-align: center;
        }
        .card {
            background-color: #1e1e1e;
            padding: 40px;
            border-radius: 16px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            max-width: 420px;
        }
        h2 { color: #4caf50; margin-top: 0; }
        p { color: #cccccc; line-height: 1.5; font-size: 15px; }
    </style>
</head>
<body>
    <div class="card">
        <h2>Autentica\u00e7\u00e3o Conclu\u00edda!</h2>
        <p>Login com Google realizado com sucesso no aplicativo Hin\u00e1rio Adventista.</p>
        <p>Voc\u00ea j\u00e1 pode fechar esta janela do navegador e retornar ao app.</p>
    </div>
</body>
</html>"""

BRIDGE_HTML = """<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Conectando ao Hin\u00e1rio...</title>
    <script>
        window.onload = function() {
            var hash = window.location.hash;
            if (hash && hash.length > 1) {
                // Redireciona com fragmento convertido em query params
                window.location.href = window.location.pathname + "?" + hash.substring(1);
            } else {
                var search = window.location.search;
                if (!search) {
                    document.getElementById("status").innerText = "Aguardando resposta de autentica\u00e7\u00e3o...";
                }
            }
        };
    </script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            background-color: #121212;
            color: #ffffff;
            text-align: center;
        }
        .spinner {
            border: 4px solid #333333;
            border-top: 4px solid #7c4dff;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div>
        <div class="spinner"></div>
        <h3 id="status">Finalizando conex\u00e3o com o aplicativo...</h3>
    </div>
</body>
</html>"""


class _DesktopOAuthHandler(BaseHTTPRequestHandler):
    """Handler HTTP local temporário para interceptar o callback OAuth no Desktop."""

    server: Any  # Subclasse BaseServer com _DesktopOAuthServer em tempo de execução

    def log_message(self, format: str, *args: Any) -> None:
        """Suprime logs padrão de requisições HTTP para manter o console limpo."""
        logger.debug("Desktop OAuth Server: " + format % args)

    def do_GET(self) -> None:
        parsed_url = urllib.parse.urlparse(self.path)
        if parsed_url.path != "/callback":
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b"Not Found")
            return

        query_params = urllib.parse.parse_qs(parsed_url.query)
        code = query_params.get("code", [None])[0]
        access_token = query_params.get("access_token", [None])[0]
        refresh_token = query_params.get("refresh_token", [None])[0]

        if code:
            # Fluxo PKCE moderno do Supabase: código de autorização recebido via query param
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_HTML_UTF8)
            self.end_headers()
            self.wfile.write(SUCCESS_HTML.encode("utf-8"))
            self.server.on_code_received(code)
        elif access_token and refresh_token:
            # Fluxo legado com tokens diretos via query parameters
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_HTML_UTF8)
            self.end_headers()
            self.wfile.write(SUCCESS_HTML.encode("utf-8"))
            self.server.on_tokens_received(access_token, refresh_token)
        else:
            # Ponte JS: Supabase OAuth pode retornar tokens no fragment (#access_token=...),
            # o qual o browser não envia no HTTP request. O script abaixo converte fragment para query params.
            self.send_response(200)
            self.send_header("Content-Type", CONTENT_TYPE_HTML_UTF8)
            self.end_headers()
            self.wfile.write(BRIDGE_HTML.encode("utf-8"))


class _DesktopOAuthServer(HTTPServer):
    """Servidor HTTP temporário em thread background para fluxo Desktop."""

    def __init__(
        self,
        server_address: tuple[str, int],
        on_success_callback: Callable[[str, str], None],
        auth_client: Any | None = None,
        on_code_received_callback: Callable[[str], None] | None = None,
    ):
        super().__init__(server_address, _DesktopOAuthHandler)
        self.on_success_callback = on_success_callback
        self.auth_client = auth_client
        self.on_code_received_callback = on_code_received_callback
        self.is_completed = False

    def on_code_received(self, code: str) -> None:
        """Recebe o authorization code (PKCE), troca pela sessão no Supabase e persiste tokens."""
        self.is_completed = True
        try:
            if self.on_code_received_callback:
                self.on_code_received_callback(code)
            elif self.auth_client and hasattr(self.auth_client, "auth"):
                res = self.auth_client.auth.exchange_code_for_session({"auth_code": code})
                session = getattr(res, "session", None)
                if session is None and isinstance(res, dict):
                    session = res.get("session")

                access_token = getattr(session, "access_token", None) or (
                    session.get("access_token") if isinstance(session, dict) else None
                )
                refresh_token = getattr(session, "refresh_token", None) or (
                    session.get("refresh_token") if isinstance(session, dict) else None
                )

                if access_token and refresh_token:
                    self.on_success_callback(access_token, refresh_token)
                else:
                    logger.error(f"Tokens ausentes na resposta de exchange_code_for_session: {res}")
            else:
                logger.error("auth_client não configurado no _DesktopOAuthServer para troca de código.")
        except Exception:
            logger.exception("Erro ao processar callback de code no Desktop")
        finally:
            threading.Thread(target=self.shutdown_server, daemon=True).start()

    def on_tokens_received(self, access_token: str, refresh_token: str) -> None:
        self.is_completed = True
        try:
            self.on_success_callback(access_token, refresh_token)
        except Exception:
            logger.exception("Erro ao processar callback de tokens no Desktop")
        finally:
            # Encerra o servidor em thread separada para não bloquear a resposta HTTP atual
            threading.Thread(target=self.shutdown_server, daemon=True).start()

    def shutdown_server(self) -> None:
        try:
            self.shutdown()
            self.server_close()
            logger.info("Servidor OAuth Desktop encerrado com sucesso.")
        except Exception as e:
            logger.debug(f"Exceção ao encerrar servidor OAuth Desktop: {e}")


class AuthService:
    """Serviço responsável por gerenciar a autenticação e sessão com o Supabase de Usuários.

    Suporta Android (Deep Link nhaapp://login-callback), Desktop (loopback HTTP local :8000)
    e Web (redirecionamento para rota da aplicação).
    """

    def __init__(
        self,
        auth_client: Any | None = None,
        redirect_uri: str | None = None,
    ) -> None:
        self._auth_client = auth_client
        self._custom_redirect_uri = redirect_uri
        self._auth_listeners: list[Callable[[Any | None], None]] = []
        self._desktop_server: _DesktopOAuthServer | None = None
        self._desktop_thread: threading.Thread | None = None

    @property
    def auth_client(self) -> Any:
        """Obtém ou inicializa dinamicamente o auth_client."""
        if self._auth_client is not None:
            return self._auth_client
        if default_auth_client is not None:
            self._auth_client = default_auth_client
            return self._auth_client
        self._auth_client = get_auth_client()
        return self._auth_client

    def get_redirect_uri(self, page: ft.Page | None = None) -> str:
        """Determina a URL de redirecionamento apropriada com base na plataforma atual."""
        if self._custom_redirect_uri:
            return self._custom_redirect_uri

        if page is not None:
            # 1. Plataforma Web
            if getattr(page, "web", False):
                page_url = getattr(page, "url", None)
                if page_url:
                    parsed = urllib.parse.urlparse(page_url)
                    origin = f"{parsed.scheme}://{parsed.netloc}"
                    return f"{origin}/"
                return "http://localhost:8550/"

            # 2. Plataforma Mobile (Android / iOS)
            platform = getattr(page, "platform", None)
            is_mobile = platform in (
                getattr(ft.PagePlatform, "ANDROID", "android"),
                getattr(ft.PagePlatform, "IOS", "ios"),
                getattr(ft.PagePlatform, "ANDROID_TV", "android_tv"),
            ) or str(platform).lower() in ("android", "ios")
            if is_mobile:
                return AUTH_REDIRECT_URI or "nhaapp://login-callback"

            # 3. Plataforma Desktop (Linux / Windows / macOS)
            return DEFAULT_DESKTOP_REDIRECT_URI

        # Fallback genérico caso a página não seja fornecida
        return AUTH_REDIRECT_URI or "nhaapp://login-callback"

    def is_desktop_platform(self, page: ft.Page) -> bool:
        """Identifica se a plataforma em execução é Desktop nativo (Linux, Windows, macOS)."""
        if getattr(page, "web", False):
            return False
        platform = getattr(page, "platform", None)
        is_mobile = platform in (
            getattr(ft.PagePlatform, "ANDROID", "android"),
            getattr(ft.PagePlatform, "IOS", "ios"),
            getattr(ft.PagePlatform, "ANDROID_TV", "android_tv"),
        ) or str(platform).lower() in ("android", "ios")
        return not is_mobile

    def add_listener(self, listener: Callable[[Any | None], None]) -> None:
        """Adiciona callback chamado em login/logout."""
        if listener not in self._auth_listeners:
            self._auth_listeners.append(listener)

    def _notify_listeners(self, user: Any | None) -> None:
        for cb in self._auth_listeners:
            try:
                cb(user)
            except Exception:
                logger.exception("Erro ao notificar listener de auth")

    def get_current_user(self) -> Any | None:
        """Retorna o usuário atual da sessão se autenticado via leitura em memória da sessão local."""
        try:
            client = self.auth_client
            if client and hasattr(client, "auth"):
                session = client.auth.get_session()
                if session is not None:
                    if hasattr(session, "user") and session.user is not None:
                        return session.user
                    if isinstance(session, dict) and "user" in session:
                        return session["user"]
                    return session
        except Exception as e:
            logger.debug(f"Nenhum usuário autenticado: {e}")
        return None

    def is_authenticated(self) -> bool:
        """Verifica se há sessão ativa no Supabase."""
        try:
            client = self.auth_client
            if client and hasattr(client, "auth"):
                session = client.auth.get_session()
                return session is not None
        except Exception:
            pass
        return False

    async def initiate_google_login(
        self,
        page: ft.Page,
        on_success: Callable[[], Any] | None = None,
    ) -> bool:
        """Inicia o fluxo de autenticação via Google OAuth abrindo o navegador.

        Suporta Android (Deep Link), Desktop (servidor local HTTP na porta 8000) e Web.
        """
        if not is_auth_supabase_configured():
            logger.error("AUTH_SUPABASE_URL ou AUTH_SUPABASE_ANON_KEY não estão configuradas.")
            return False

        redirect_uri = self.get_redirect_uri(page)
        is_desktop = self.is_desktop_platform(page)

        # Se for Desktop, inicializa o servidor HTTP local temporário para receber o callback
        if is_desktop:
            self._start_desktop_oauth_server(page, on_success)

        try:
            client = self.auth_client
            res = client.auth.sign_in_with_oauth(
                {
                    "provider": "google",
                    "options": {
                        "redirect_to": redirect_uri,
                    },
                }
            )

            auth_url: str | None = None
            if hasattr(res, "url") and res.url:
                auth_url = res.url
            elif isinstance(res, dict) and "url" in res:
                auth_url = res["url"]

            if not auth_url:
                logger.error(f"Resposta inválida de sign_in_with_oauth: {res}")
                if is_desktop:
                    self._stop_desktop_oauth_server()
                return False

            logger.info(f"Redirecionando para login Google OAuth (Redirect: {redirect_uri}): {auth_url}")
            launch_fn = getattr(page, "launch_url", None)
            if callable(launch_fn):
                try:
                    res_launch = launch_fn(auth_url, **{"web_popup_type": ft.WebPopupType.EXTERNAL})
                except TypeError:
                    res_launch = launch_fn(auth_url)
                if inspect.iscoroutine(res_launch):
                    await res_launch
            else:
                try:
                    await ft.UrlLauncher().launch_url(auth_url)
                except Exception:
                    pass
            return True
        except Exception:
            logger.exception("Falha ao iniciar autenticação Google")
            if is_desktop:
                self._stop_desktop_oauth_server()
            return False

    def _start_desktop_oauth_server(
        self,
        page: ft.Page,
        on_success: Callable[[], Any] | None = None,
    ) -> None:
        """Inicia o servidor HTTP local temporário em uma thread em background."""
        self._stop_desktop_oauth_server()

        # Captura o loop assíncrono corrente do Flet
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.new_event_loop()

        def _on_tokens(access_token: str, refresh_token: str) -> None:
            async def _apply() -> None:
                success = await self._apply_session(access_token, refresh_token, page)
                if success:
                    if on_success:
                        try:
                            res = on_success()
                            if inspect.iscoroutine(res):
                                await res
                        except Exception:
                            logger.exception("Erro ao executar on_success após login Desktop")
                    # Exibe notificação no aplicativo
                    self._show_login_feedback(page, True)
                else:
                    self._show_login_feedback(page, False)

            asyncio.run_coroutine_threadsafe(_apply(), loop)

        try:
            server_address = ("127.0.0.1", DEFAULT_DESKTOP_CALLBACK_PORT)
            self._desktop_server = _DesktopOAuthServer(
                server_address,
                _on_tokens,
                auth_client=self.auth_client,
            )
            self._desktop_thread = threading.Thread(
                target=self._desktop_server.serve_forever,
                daemon=True,
                name="DesktopOAuthServerThread",
            )
            self._desktop_thread.start()
            logger.info(f"Servidor OAuth Desktop iniciado em http://127.0.0.1:{DEFAULT_DESKTOP_CALLBACK_PORT}/callback")

            # Timeout de segurança para fechar o servidor se o usuário cancelar ou demorar mais de 120s
            def _timeout_watcher():
                import time
                time.sleep(120)
                if self._desktop_server and not self._desktop_server.is_completed:
                    logger.debug("Desktop OAuth Server expirou por timeout (120s).")
                    self._stop_desktop_oauth_server()

            threading.Thread(target=_timeout_watcher, daemon=True).start()

        except Exception as e:
            logger.warning(f"Não foi possível iniciar o servidor OAuth local na porta {DEFAULT_DESKTOP_CALLBACK_PORT}: {e}")

    def _stop_desktop_oauth_server(self) -> None:
        """Encerra com segurança o servidor HTTP local."""
        if self._desktop_server:
            try:
                self._desktop_server.shutdown_server()
            except Exception:
                pass
            self._desktop_server = None
        self._desktop_thread = None

    def _show_login_feedback(self, page: ft.Page, success: bool) -> None:
        """Exibe SnackBar informativo na interface gráfica do Flet."""
        try:
            snack = ft.SnackBar(
                content=ft.Row(
                    controls=[
                        ft.Icon(
                            ft.Icons.CHECK_CIRCLE if success else ft.Icons.ERROR_OUTLINE,
                            color=ft.Colors.WHITE,
                        ),
                        ft.Text(
                            "Login com Google realizado com sucesso!"
                            if success
                            else "Não foi possível autenticar com o Google.",
                            color=ft.Colors.WHITE,
                        ),
                    ],
                    spacing=10,
                ),
                bgcolor=ft.Colors.GREEN_700 if success else ft.Colors.RED_800,
                duration=3500,
            )
            if hasattr(page, "open"):
                page.open(snack)
            elif hasattr(page, "show_snack_bar"):
                page.show_snack_bar(snack)
        except Exception as ex:
            logger.debug(f"Não foi possível exibir SnackBar de feedback: {ex}")

    async def _apply_session(
        self,
        access_token: str,
        refresh_token: str,
        page: ft.Page,
    ) -> bool:
        """Registra os tokens no Supabase Auth e persiste no storage local do dispositivo."""
        try:
            client = self.auth_client
            client.auth.set_session(access_token, refresh_token)

            # Persiste tokens localmente via storage resiliente
            await storage_set(page, STORAGE_KEY_ACCESS_TOKEN, access_token)
            await storage_set(page, STORAGE_KEY_REFRESH_TOKEN, refresh_token)

            # Grava também diretamente no page.client_storage se existir
            if hasattr(page, "client_storage") and page.client_storage is not None:
                try:
                    if hasattr(page.client_storage, "set_async"):
                        await page.client_storage.set_async(STORAGE_KEY_ACCESS_TOKEN, access_token)
                        await page.client_storage.set_async(STORAGE_KEY_REFRESH_TOKEN, refresh_token)
                    elif hasattr(page.client_storage, "set"):
                        page.client_storage.set(STORAGE_KEY_ACCESS_TOKEN, access_token)
                        page.client_storage.set(STORAGE_KEY_REFRESH_TOKEN, refresh_token)
                except Exception as e:
                    logger.debug(f"Erro ao salvar em page.client_storage: {e}")

            user = self.get_current_user()
            self._notify_listeners(user)
            logger.info("Autenticação Google concluída com sucesso e tokens persistidos.")
            return True

        except Exception:
            logger.exception("Erro ao registrar sessão no Supabase Auth")
            return False

    async def handle_auth_callback(self, route: str, page: ft.Page) -> bool:
        """Processa a URL do Deep Link ou rota Web de callback da autenticação.

        Exemplos de rotas/URLs tratadas:
        - nhaapp://login-callback?code=...
        - nhaapp://login-callback#access_token=...&refresh_token=...&token_type=bearer
        - /login-callback?code=...
        - /login-callback#access_token=...&refresh_token=...
        - /?code=...
        - /?access_token=...&refresh_token=...
        - /#access_token=...&refresh_token=...
        """
        if not route:
            return False

        # Verifica se corresponde à rota de callback ou contém tokens/code OAuth
        is_callback = (
            "login-callback" in route
            or route.startswith("nhaapp://")
            or "access_token=" in route
            or "code=" in route
        )
        if not is_callback:
            return False

        tokens = self._extract_tokens_from_url(route)
        code = tokens.get("code")
        if code:
            try:
                client = self.auth_client
                res = client.auth.exchange_code_for_session({"auth_code": code})
                session = getattr(res, "session", None)
                if session is None and isinstance(res, dict):
                    session = res.get("session")

                access_token = getattr(session, "access_token", None) or (
                    session.get("access_token") if isinstance(session, dict) else None
                )
                refresh_token = getattr(session, "refresh_token", None) or (
                    session.get("refresh_token") if isinstance(session, dict) else None
                )

                if access_token and refresh_token:
                    return await self._apply_session(access_token, refresh_token, page)
                logger.error(f"Tokens ausentes na resposta de exchange_code_for_session: {res}")
                return False
            except Exception:
                logger.exception("Erro ao trocar código por sessão no callback")
                return False

        access_token = tokens.get("access_token")
        refresh_token = tokens.get("refresh_token")

        if not access_token or not refresh_token:
            logger.warning(f"Callback detectado, porém tokens ou código ausentes na rota: {route}")
            return False

        return await self._apply_session(access_token, refresh_token, page)

    async def restore_session(self, page: ft.Page) -> bool:
        """Restaura tokens salvos no storage local e reconecta a sessão no Supabase Auth."""
        try:
            access_token = None
            refresh_token = None

            # Tenta primeiramente de page.client_storage se disponível
            if hasattr(page, "client_storage") and page.client_storage is not None:
                try:
                    if hasattr(page.client_storage, "get_async"):
                        access_token = await page.client_storage.get_async(STORAGE_KEY_ACCESS_TOKEN)
                        refresh_token = await page.client_storage.get_async(STORAGE_KEY_REFRESH_TOKEN)
                    elif hasattr(page.client_storage, "get"):
                        access_token = page.client_storage.get(STORAGE_KEY_ACCESS_TOKEN)
                        refresh_token = page.client_storage.get(STORAGE_KEY_REFRESH_TOKEN)
                except Exception:
                    pass

            if not access_token or not refresh_token:
                access_token = await storage_get(page, STORAGE_KEY_ACCESS_TOKEN)
                refresh_token = await storage_get(page, STORAGE_KEY_REFRESH_TOKEN)

            if not access_token or not refresh_token:
                logger.debug("Nenhum token salvo encontrado para restauração de sessão.")
                return False

            client = self.auth_client
            client.auth.set_session(str(access_token), str(refresh_token))
            user = self.get_current_user()
            self._notify_listeners(user)
            logger.info("Sessão do usuário restaurada com sucesso.")
            return True

        except Exception as err:
            logger.warning(f"Falha ao restaurar sessão anterior: {err}")
            return False

    async def logout(self, page: ft.Page) -> None:
        """Encerra a sessão ativa e remove credenciais salvas."""
        try:
            client = self.auth_client
            if client and hasattr(client, "auth"):
                client.auth.sign_out()
        except Exception as err:
            logger.warning(f"Erro ao fazer sign_out no Supabase Auth: {err}")

        # Limpa do storage_manager
        await storage_set(page, STORAGE_KEY_ACCESS_TOKEN, None)
        await storage_set(page, STORAGE_KEY_REFRESH_TOKEN, None)

        # Limpa do page.client_storage
        if hasattr(page, "client_storage") and page.client_storage is not None:
            try:
                for key in (STORAGE_KEY_ACCESS_TOKEN, STORAGE_KEY_REFRESH_TOKEN):
                    if hasattr(page.client_storage, "remove_async"):
                        await page.client_storage.remove_async(key)
                    elif hasattr(page.client_storage, "remove"):
                        page.client_storage.remove(key)
            except Exception as e:
                logger.debug(f"Erro ao limpar page.client_storage: {e}")

        self._notify_listeners(None)
        logger.info("Logout executado e storage limpo.")

    @staticmethod
    def _extract_tokens_from_url(raw_url: str) -> dict[str, str]:
        """Extrai pares chave-valor de fragmentos (#) ou query parameters (?) de uma URL."""
        parsed = urllib.parse.urlparse(raw_url)
        params: dict[str, str] = {}

        # 1. Fragmentos (comum no OAuth implicit flow com #access_token=... ou #code=...)
        if parsed.fragment:
            frag_params = urllib.parse.parse_qs(parsed.fragment)
            for k, v in frag_params.items():
                if v:
                    params[k] = v[0]

        # 2. Query params (?access_token=... ou ?code=...)
        if parsed.query:
            query_params = urllib.parse.parse_qs(parsed.query)
            for k, v in query_params.items():
                if v and k not in params:
                    params[k] = v[0]

        # 3. Fallback: caso a URL venha como string pura contendo '#' ou '?' sem esquema padrão
        if ("access_token=" in raw_url or "code=" in raw_url) and not params:
            parts = raw_url.replace("#", "&").replace("?", "&").split("&")
            for part in parts:
                if "=" in part:
                    k, v = part.split("=", 1)
                    if k in ("access_token", "refresh_token", "token_type", "expires_in", "code"):
                        params[k] = urllib.parse.unquote(v)

        return params
