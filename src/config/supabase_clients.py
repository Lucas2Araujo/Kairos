"""
Módulo de inicialização e exportação dos clientes independentes do Supabase.

Dois ambientes distintos:
1. devotional_client: Conecta à instância de Devocionais (conteúdo público, tabela daily_devotionals).
2. auth_client: Conecta à instância de Usuários/Autenticação (OAuth Google, dados do usuário).
"""

from __future__ import annotations

import logging
from typing import Any

from src.config import (
    AUTH_SUPABASE_ANON_KEY,
    AUTH_SUPABASE_URL,
    DEVOTIONAL_SUPABASE_ANON_KEY,
    DEVOTIONAL_SUPABASE_URL,
)

logger = logging.getLogger(__name__)

try:
    from supabase import Client, create_client
except ImportError:
    Client = Any  # type: ignore[misc,assignment]
    create_client = None  # type: ignore[assignment]


def get_devotional_client() -> Client:
    """Inicializa e retorna o cliente Supabase para o ambiente de Devocionais.

    Raises:
        RuntimeError: Se a biblioteca supabase não estiver instalada.
        ValueError: Se DEVOTIONAL_SUPABASE_URL ou DEVOTIONAL_SUPABASE_ANON_KEY não estiverem configuradas.
    """
    if create_client is None:
        raise RuntimeError(
            "Biblioteca 'supabase' não está instalada no ambiente. Instale com: pip install supabase"
        )
    if not DEVOTIONAL_SUPABASE_URL or not DEVOTIONAL_SUPABASE_ANON_KEY:
        raise ValueError(
            "Configurações ausentes para Devocionais: DEVOTIONAL_SUPABASE_URL e DEVOTIONAL_SUPABASE_ANON_KEY são obrigatórias."
        )
    return create_client(DEVOTIONAL_SUPABASE_URL, DEVOTIONAL_SUPABASE_ANON_KEY)


def get_auth_client() -> Client:
    """Inicializa e retorna o cliente Supabase para o ambiente de Usuários e Autenticação.

    Raises:
        RuntimeError: Se a biblioteca supabase não estiver instalada.
        ValueError: Se AUTH_SUPABASE_URL ou AUTH_SUPABASE_ANON_KEY não estiverem configuradas.
    """
    if create_client is None:
        raise RuntimeError(
            "Biblioteca 'supabase' não está instalada no ambiente. Instale com: pip install supabase"
        )
    if not AUTH_SUPABASE_URL or not AUTH_SUPABASE_ANON_KEY:
        raise ValueError(
            "Configurações ausentes para Autenticação: AUTH_SUPABASE_URL e AUTH_SUPABASE_ANON_KEY são obrigatórias."
        )
    return create_client(AUTH_SUPABASE_URL, AUTH_SUPABASE_ANON_KEY)


# Instâncias lazy/seguras caso as variáveis já estejam presentes no ambiente
devotional_client: Client | None = None
auth_client: Client | None = None

if create_client is not None:
    try:
        if DEVOTIONAL_SUPABASE_URL and DEVOTIONAL_SUPABASE_ANON_KEY:
            devotional_client = get_devotional_client()
    except Exception as e:
        logger.warning(f"Não foi possível inicializar devotional_client imediatamente: {e}")

    try:
        if AUTH_SUPABASE_URL and AUTH_SUPABASE_ANON_KEY:
            auth_client = get_auth_client()
    except Exception as e:
        logger.warning(f"Não foi possível inicializar auth_client imediatamente: {e}")

