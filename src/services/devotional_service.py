from __future__ import annotations

import logging
from datetime import date
from typing import Callable

import httpx
import json

from src.config import SUPABASE_ANON_KEY, SUPABASE_URL
from src.database.devotional_repo import DevotionalRepository
from src.models.devotional import Devotional

logger = logging.getLogger(__name__)


class DevotionalService:
    """
    Serviço offline-first de Meditação Diária (Devocional).
    - Prioriza a leitura do cache local SQLite.
    - Em caso de miss no cache ou atualização, consulta a tabela pública 'daily_devotionals' do Supabase via REST / chave anônima.
    - Salva imediatamente a resposta no cache local.
    - Suporta múltiplos tipos de devocional através do parâmetro `category` (default: 'jovem').
    - Executa o Coletor de Lixo (Garbage Collector) para retenção controlada de registros (> 7 dias).
    """

    DEFAULT_RETENTION_DAYS = 7
    AUTO_CLEANUP_KEY = "devotional_auto_cleanup"

    def __init__(
        self,
        repository: DevotionalRepository,
        supabase_url: str | None = None,
        supabase_anon_key: str | None = None,
        http_client: httpx.AsyncClient | None = None,
    ):
        self.repository = repository
        self.supabase_url = (
            (supabase_url if supabase_url is not None else SUPABASE_URL) or ""
        ).rstrip("/")
        self.supabase_anon_key = (
            supabase_anon_key if supabase_anon_key is not None else SUPABASE_ANON_KEY
        ) or ""
        self._http_client = http_client

    def _get_headers(self) -> dict[str, str]:
        """Gera os headers de autenticação pública anônima para a API REST do Supabase (PostgREST)."""
        return {
            "apikey": self.supabase_anon_key,
            "Authorization": f"Bearer {self.supabase_anon_key}",
            "Accept": "application/json",
            "Content-Type": "application/json",
        }

    async def fetch_from_cloud(
        self, target_date: str, category: str = "jovem"
    ) -> Devotional | None:
        """
        Consulta a tabela daily_devotionals no Supabase para a data especificada (YYYY-MM-DD)
        e categoria (ex: 'jovem').
        """
        if not self.supabase_url or not self.supabase_anon_key:
            logger.warning(
                "Credenciais do Supabase não configuradas. Consulta à nuvem ignorada."
            )
            return None

        endpoint = f"{self.supabase_url}/rest/v1/daily_devotionals"
        params = {
            "published_at": f"eq.{target_date.strip()}",
            "category": f"eq.{category.strip().lower()}",
            "select": "*",
            "limit": "1",
        }

        try:
            if self._http_client:
                response = await self._http_client.get(
                    endpoint, params=params, headers=self._get_headers(), timeout=10.0
                )
            else:
                async with httpx.AsyncClient(timeout=10.0) as client:
                    response = await client.get(
                        endpoint, params=params, headers=self._get_headers()
                    )

            if response.status_code == 200:
                data = response.json()
                if isinstance(data, list) and len(data) > 0:
                    item_data = data[0]
                    if "category" not in item_data or not item_data["category"]:
                        item_data["category"] = category
                    return Devotional.from_dict(item_data)
            else:
                logger.warning(
                    f"Erro ao buscar devocional no Supabase ({response.status_code}): {response.text}"
                )
        except (httpx.HTTPError, json.JSONDecodeError, KeyError) as exc:
            logger.warning("Falha de conexão ao buscar devocional na nuvem: %s", exc)

        return None

    async def get_devotional(
        self,
        target_date: str | date | None = None,
        category: str = "jovem",
        force_refresh: bool = False,
    ) -> Devotional | None:
        """
        Padrão Offline-First:
        1. Se não for force_refresh, tenta ler do cache local SQLite.
        2. Se encontrado no cache, retorna imediatamente.
        3. Se não houver no cache ou force_refresh=True, busca na nuvem (Supabase).
        4. Ao receber dados da nuvem, salva imediatamente no SQLite para acessos offline futuros.
        5. Se a nuvem falhar e houver cache antigo, retorna o cache existente.
        """
        if target_date is None:
            date_str = date.today().isoformat()
        elif isinstance(target_date, date):
            date_str = target_date.isoformat()
        else:
            date_str = target_date.strip()

        cached: Devotional | None = None
        if not force_refresh:
            cached = await self.repository.get_by_date(date_str, category=category)
            if cached:
                return cached

        # Busca na Nuvem
        cloud_devotional = await self.fetch_from_cloud(date_str, category=category)
        if cloud_devotional:
            await self.repository.save(cloud_devotional)
            return cloud_devotional

        # Fallback para cache se a busca na nuvem falhar mesmo com force_refresh
        if not cached:
            cached = await self.repository.get_by_date(date_str, category=category)
        return cached

    async def get_cached_devotional(
        self,
        target_date: str | date | None = None,
        category: str = "jovem",
    ) -> Devotional | None:
        """
        Lê estritamente do cache local SQLite sem realizar requisições de rede.
        Garante carregamento instantâneo offline-first.
        """
        if target_date is None:
            date_str = date.today().isoformat()
        elif isinstance(target_date, date):
            date_str = target_date.isoformat()
        else:
            date_str = target_date.strip()

        return await self.repository.get_by_date(date_str, category=category)

    async def sync_devotional(
        self,
        target_date: str | date | None = None,
        category: str = "jovem",
    ) -> Devotional | None:
        """
        Sincroniza um devocional específico com a nuvem (Supabase) em segundo plano,
        persistindo o resultado no SQLite local.
        """
        if target_date is None:
            date_str = date.today().isoformat()
        elif isinstance(target_date, date):
            date_str = target_date.isoformat()
        else:
            date_str = target_date.strip()

        cloud_devotional = await self.fetch_from_cloud(date_str, category=category)
        if cloud_devotional:
            await self.repository.save(cloud_devotional)
        return cloud_devotional

    async def get_recent_devotionals(
        self, limit: int = 7, category: str = "jovem"
    ) -> list[Devotional]:
        """Retorna as meditações recentes salvas no cache local para a categoria."""
        return await self.repository.get_recent(limit=limit, category=category)

    async def get_all_cached_devotionals(
        self, category: str | None = None
    ) -> list[Devotional]:
        """Retorna todas as meditações salvas no cache local."""
        return await self.repository.get_all_cached(category=category)

    async def delete_devotional(self, published_at: str, category: str = "jovem") -> bool:
        """Exclui individualmente uma meditação por data e categoria."""
        return await self.repository.delete_by_date(published_at, category=category)

    async def clear_all_cache(self, category: str | None = None) -> int:
        """Limpa o cache de meditações (todas ou de uma categoria)."""
        return await self.repository.clear_all(category=category)

    async def run_auto_cleanup(
        self,
        get_toggle_state: Callable[[], bool | None] | None = None,
        retention_days: int = DEFAULT_RETENTION_DAYS,
    ) -> int:
        """
        Executa a purga automática de registros anteriores a X dias (> 7 dias por padrão),
        desde que o toggle de limpeza automática esteja habilitado.
        Por padrão, assume habilitado (True) caso não seja fornecida função verificadora.
        """
        enabled = True
        if get_toggle_state is not None:
            state = get_toggle_state()
            enabled = state if state is not None else True

        if not enabled:
            return 0

        purged = await self.repository.delete_older_than(days=retention_days)
        if purged > 0:
            logger.info(
                f"[DevotionalService] Limpeza automática: {purged} meditações antigas removidas."
            )
        return purged
