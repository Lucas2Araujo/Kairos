"""
Serviço de Autenticação Supabase via OAuth (Google) com Deep Link para Android / Flet.

Fluxo:
1. `initiate_google_login(page)`: Chama `auth_client.auth.sign_in_with_oauth()` apontando para `AUTH_REDIRECT_URI`
   e lança o navegador via `page.launch_url()`.
2. `handle_auth_callback(route, page)`: Intercepta a rota/URL de retorno (ex: nhaapp://login-callback#access_token=... ou ?access_token=...),
   extrai tokens, executa `auth_client.auth.set_session()` e persiste no `page.client_storage`.
3. `restore_session(page)`: Restaura sessão salva no storage ao inicializar o app.
4. `logout(page)`: Encerra sessão remota e remove os dados locais do storage.
"""

from __future__ import annotations

import inspect
import logging
import urllib.parse
from typing import Any, Callable

import flet as ft

from src.config import AUTH_REDIRECT_URI, is_auth_supabase_configured
from src.config.supabase_clients import get_auth_client
from src.utils.storage_manager import storage_get, storage_set

logger = logging.getLogger(__name__)

STORAGE_KEY_ACCESS_TOKEN = "supabase_auth_access_token"
STORAGE_KEY_REFRESH_TOKEN = "supabase_auth_refresh_token"


class AuthService:
    """Serviço responsável por gerenciar a autenticação e sessão com o Supabase de Usuários."""

    def __init__(
        self,
        auth_client: Any | None = None,
        redirect_uri: str = AUTH_REDIRECT_URI,
    ) -> None:
        self._auth_client = auth_client
        self.redirect_uri = redirect_uri
        self._auth_listeners: list[Callable[[Any | None], None]] = []

    @property
    def auth_client(self) -> Any:
        """Obtém ou inicializa dinamicamente o auth_client."""
        if self._auth_client is None:
            self._auth_client = get_auth_client()
        return self._auth_client

    def add_listener(self, listener: Callable[[Any | None], None]) -> None:
        """Adiciona callback chamado em login/logout."""
        if listener not in self._auth_listeners:
            self._auth_listeners.append(listener)

    def _notify_listeners(self, user: Any | None) -> None:
        for cb in self._auth_listeners:
            try:
                cb(user)
            except Exception as e:
                logger.error(f"Erro ao notificar listener de auth: {e}")

    def get_current_user(self) -> Any | None:
        """Retorna o usuário atual da sessão se autenticado."""
        try:
            client = self.auth_client
            if client and hasattr(client, "auth"):
                return client.auth.get_user()
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

    async def initiate_google_login(self, page: ft.Page) -> bool:
        """Inicia o fluxo de autenticação via Google OAuth abrindo o navegador do dispositivo.

        Retorna True se a URL foi lançada com sucesso.
        """
        if not is_auth_supabase_configured():
            logger.error("AUTH_SUPABASE_URL ou AUTH_SUPABASE_ANON_KEY não estão configuradas.")
            return False

        try:
            client = self.auth_client
            # Executa sign_in_with_oauth
            res = client.auth.sign_in_with_oauth(
                {
                    "provider": "google",
                    "options": {
                        "redirect_to": self.redirect_uri,
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
                return False

            logger.info(f"Redirecionando para login Google OAuth: {auth_url}")
            try:
                await ft.UrlLauncher().launch_url(auth_url)
            except Exception:
                if hasattr(page, "launch_url"):
                    res_launch = page.launch_url(auth_url)
                    if inspect.iscoroutine(res_launch):
                        await res_launch
            return True
        except Exception as err:
            logger.error(f"Falha ao iniciar autenticação Google: {err}")
            return False

    async def handle_auth_callback(self, route: str, page: ft.Page) -> bool:
        """Processa a URL do Deep Link de callback da autenticação.

        Exemplos de URL tratadas:
        - nhaapp://login-callback#access_token=...&refresh_token=...&token_type=bearer
        - /login-callback#access_token=...&refresh_token=...
        - /login-callback?access_token=...&refresh_token=...
        """
        if not route:
            return False

        # Verifica se corresponde à rota de callback
        is_callback = (
            "login-callback" in route
            or route.startswith("nhaapp://")
            or "access_token" in route
        )
        if not is_callback:
            return False

        tokens = self._extract_tokens_from_url(route)
        access_token = tokens.get("access_token")
        refresh_token = tokens.get("refresh_token")

        if not access_token or not refresh_token:
            logger.warning(f"Callback detectado, porém tokens ausentes na rota: {route}")
            return False

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

        except Exception as err:
            logger.error(f"Erro ao registrar sessão no Supabase Auth: {err}")
            return False

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

        # 1. Fragmentos (comum no OAuth implicit flow com #access_token=...)
        if parsed.fragment:
            frag_params = urllib.parse.parse_qs(parsed.fragment)
            for k, v in frag_params.items():
                if v:
                    params[k] = v[0]

        # 2. Query params (?access_token=...)
        if parsed.query:
            query_params = urllib.parse.parse_qs(parsed.query)
            for k, v in query_params.items():
                if v and k not in params:
                    params[k] = v[0]

        # 3. Fallback: caso a URL venha como string pura contendo '#' ou '?' sem esquema padrão
        if "access_token=" in raw_url and "access_token" not in params:
            parts = raw_url.replace("#", "&").replace("?", "&").split("&")
            for part in parts:
                if "=" in part:
                    k, v = part.split("=", 1)
                    if k in ("access_token", "refresh_token", "token_type", "expires_in"):
                        params[k] = urllib.parse.unquote(v)

        return params

