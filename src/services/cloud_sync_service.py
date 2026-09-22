"""
Serviço de Sincronização em Nuvem (Supabase + Kairós).
Sincroniza de forma assíncrona e não-bloqueante:
1. Perfis de usuário (public.profiles)
2. Hinos e versículos favoritos (public.user_favorites)
3. Destaques e notas bíblicas (public.verse_highlights)
4. Histórico de leitura e acessos (public.reading_history)
5. Ofensivas e conclusão de meditações (public.reading_streaks)
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone
from typing import Any

from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.services.auth_service import AuthService

logger = logging.getLogger(__name__)


class CloudSyncService:
    """
    Controlador de sincronização em segundo plano com o Supabase.
    Aplica o padrão Offline-First: salva localmente no SQLite primeiro,
    e sincroniza com a nuvem de forma resiliente sem travar o aplicativo.
    """

    def __init__(
        self,
        auth_service: AuthService,
        fav_repo_novo: FavoritoRepository | None = None,
        fav_repo_antigo: FavoritoRepository | None = None,
        hist_repo_novo: HistoricoRepository | None = None,
        hist_repo_antigo: HistoricoRepository | None = None,
    ):
        self.auth_service = auth_service
        self.fav_repo_novo = fav_repo_novo
        self.fav_repo_antigo = fav_repo_antigo
        self.hist_repo_novo = hist_repo_novo
        self.hist_repo_antigo = hist_repo_antigo
        self._sync_lock = asyncio.Lock()

    def _get_user_id(self) -> str | None:
        """Retorna o UUID do usuário autenticado no Supabase ou None."""
        user = self.auth_service.get_current_user()
        if user and getattr(user, "id", None):
            return str(user.id)
        return None

    # -------------------------------------------------------------------------
    # 1. Perfil do Usuário (public.profiles)
    # -------------------------------------------------------------------------

    async def sync_profile(self, user: Any = None) -> bool:
        """Atualiza/garante o perfil do usuário logado na tabela public.profiles."""
        current_user = user or self.auth_service.get_current_user()
        if not current_user or not getattr(current_user, "id", None):
            return False

        user_id = str(current_user.id)
        email = getattr(current_user, "email", "") or ""
        meta = getattr(current_user, "user_metadata", {}) or {}
        if not isinstance(meta, dict):
            meta = {}
        full_name = meta.get("full_name") or meta.get("name") or getattr(current_user, "display_name", "") or ""
        avatar_url = meta.get("avatar_url") or meta.get("picture") or ""

        def _do_sync():
            client = self.auth_service.auth_client
            client.table("profiles").upsert(
                {
                    "id": user_id,
                    "email": email,
                    "full_name": full_name,
                    "avatar_url": avatar_url,
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                },
                on_conflict="id",
            ).execute()

        try:
            await asyncio.to_thread(_do_sync)
            logger.info("CloudSyncService: Perfil sincronizado para o usuário %s.", user_id)
            return True
        except Exception as ex:
            logger.debug("CloudSyncService: Falha ao sincronizar perfil: %s", ex)
            return False

    # -------------------------------------------------------------------------
    # 2. Favoritos (public.user_favorites)
    # -------------------------------------------------------------------------

    async def push_favorite(
        self, item_type: str, item_id: str | int, is_deleted: bool = False
    ) -> bool:
        """Envia um favorito (adicionado ou removido) para o Supabase."""
        user_id = self._get_user_id()
        if not user_id:
            return False

        record = {
            "user_id": user_id,
            "item_type": str(item_type).lower(),
            "item_id": str(item_id),
            "is_deleted": bool(is_deleted),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        def _do_push():
            client = self.auth_service.auth_client
            client.table("user_favorites").upsert(
                record,
                on_conflict="user_id,item_type,item_id",
            ).execute()

        try:
            await asyncio.to_thread(_do_push)
            logger.info("CloudSyncService: Favorito (%s: %s, deleted=%s) sincronizado.", item_type, item_id, is_deleted)
            return True
        except Exception as ex:
            logger.debug("CloudSyncService: Falha ao enviar favorito para nuvem: %s", ex)
            return False

    async def pull_favorites(self) -> list[dict[str, Any]]:
        """Baixa favoritos da nuvem e mescla com os bancos SQLite locais."""
        user_id = self._get_user_id()
        if not user_id:
            return []

        def _do_pull():
            client = self.auth_service.auth_client
            res = (
                client.table("user_favorites")
                .select("item_type, item_id, is_deleted")
                .eq("user_id", user_id)
                .execute()
            )
            return getattr(res, "data", []) or []

        try:
            cloud_favs = await asyncio.to_thread(_do_pull)
            for item in cloud_favs:
                itype = item.get("item_type")
                iid = item.get("item_id")
                is_del = item.get("is_deleted", False)

                if itype == "hymn" and iid is not None:
                    try:
                        hino_num = int(iid)
                        # Aplica no repositório local do Hinário Novo
                        if self.fav_repo_novo:
                            if is_del:
                                await self.fav_repo_novo.remove_favorito(hino_num)
                            else:
                                await self.fav_repo_novo.add_favorito(hino_num)
                    except ValueError:
                        pass
            logger.info("CloudSyncService: %d favoritos baixados e mesclados.", len(cloud_favs))
            return cloud_favs
        except Exception as ex:
            logger.debug("CloudSyncService: Falha ao puxar favoritos da nuvem: %s", ex)
            return []

    # -------------------------------------------------------------------------
    # 3. Histórico de Acesso (public.reading_history)
    # -------------------------------------------------------------------------

    async def push_history(
        self, item_type: str, item_id: str | int, title: str | None = None
    ) -> bool:
        """Registra um acesso no histórico do Supabase."""
        user_id = self._get_user_id()
        if not user_id:
            return False

        record = {
            "user_id": user_id,
            "item_type": str(item_type).lower(),
            "item_id": str(item_id),
            "title": title or "",
            "accessed_at": datetime.now(timezone.utc).isoformat(),
        }

        def _do_push():
            client = self.auth_service.auth_client
            client.table("reading_history").insert(record).execute()

        try:
            await asyncio.to_thread(_do_push)
            logger.info("CloudSyncService: Histórico registrado (%s: %s).", item_type, item_id)
            return True
        except Exception as ex:
            logger.debug("CloudSyncService: Falha ao enviar histórico para nuvem: %s", ex)
            return False

    # -------------------------------------------------------------------------
    # 4. Destaques Bíblicos (public.verse_highlights)
    # -------------------------------------------------------------------------

    async def push_verse_highlight(
        self,
        book_id: str,
        chapter: int,
        verse: int,
        color: str = "#FFEB3B",
        note: str | None = None,
        is_deleted: bool = False,
    ) -> bool:
        """Salva ou atualiza marcação de versículo no Supabase."""
        user_id = self._get_user_id()
        if not user_id:
            return False

        record = {
            "user_id": user_id,
            "book_id": str(book_id).upper(),
            "chapter": int(chapter),
            "verse": int(verse),
            "color": color,
            "note": note,
            "is_deleted": bool(is_deleted),
            "updated_at": datetime.now(timezone.utc).isoformat(),
        }

        def _do_push():
            client = self.auth_service.auth_client
            client.table("verse_highlights").upsert(
                record,
                on_conflict="user_id,book_id,chapter,verse",
            ).execute()

        try:
            await asyncio.to_thread(_do_push)
            logger.info("CloudSyncService: Destaque bíblico sincronizado (%s %s:%s).", book_id, chapter, verse)
            return True
        except Exception as ex:
            logger.debug("CloudSyncService: Falha ao sincronizar destaque bíblico: %s", ex)
            return False

    # -------------------------------------------------------------------------
    # 5. Ciclo Completo ao Autenticar
    # -------------------------------------------------------------------------

    async def sync_on_login(self, user: Any) -> None:
        """Executa sincronização bidirecional completa após o login bem-sucedido."""
        async with self._sync_lock:
            try:
                # 1. Atualiza dados do perfil
                await self.sync_profile(user)

                # 2. Baixa favoritos da nuvem e mescla localmente
                await self.pull_favorites()

                # 3. Sobe favoritos locais para a nuvem se ainda não estiverem lá
                if self.fav_repo_novo:
                    local_favs = await self.fav_repo_novo.get_favoritos()
                    for fav in local_favs:
                        if getattr(fav, "id", None) is not None:
                            await self.push_favorite("hymn", fav.id, is_deleted=False)
            except Exception as ex:
                logger.debug("CloudSyncService: Erro durante sync_on_login: %s", ex)

