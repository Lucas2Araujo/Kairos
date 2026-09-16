"""
Utilitário de armazenamento resiliente de preferências do cliente.
Compatível com diferentes versões do Flet (page.client_storage, SharedPreferences ou in-memory fallback).
"""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)

_IN_MEMORY_STORAGE: dict[str, Any] = {}


async def storage_get(page: Any | None, key: str, default: Any = None) -> Any:
    """Obtém um valor do armazenamento local de forma resiliente."""
    if not page:
        return _IN_MEMORY_STORAGE.get(key, default)

    # 1. Tenta page.client_storage (Flet < 0.80 ou wrappers)
    if hasattr(page, "client_storage") and page.client_storage is not None:
        try:
            if hasattr(page.client_storage, "get_async"):
                val = await page.client_storage.get_async(key)
                return val if val is not None else default
            if hasattr(page.client_storage, "get"):
                val = page.client_storage.get(key)
                return val if val is not None else default
        except Exception as e:
            logger.debug(f"Erro ao ler de page.client_storage: {e}")

    # 2. Tenta SharedPreferences / page.shared_preferences (Flet 0.80+)
    try:
        sp = getattr(page, "shared_preferences", None)
        if sp is None and hasattr(page, "services"):
            sp = getattr(page.services, "shared_preferences", None)
        if sp and hasattr(sp, "get"):
            val = await sp.get(key)
            return val if val is not None else default
    except Exception as e:
        logger.debug(f"Erro ao ler de shared_preferences: {e}")

    return _IN_MEMORY_STORAGE.get(key, default)


async def storage_set(page: Any | None, key: str, value: Any) -> None:
    """Salva um valor no armazenamento local de forma resiliente."""
    _IN_MEMORY_STORAGE[key] = value

    if not page:
        return

    # 1. Tenta page.client_storage
    if hasattr(page, "client_storage") and page.client_storage is not None:
        try:
            if hasattr(page.client_storage, "set_async"):
                await page.client_storage.set_async(key, value)
                return
            if hasattr(page.client_storage, "set"):
                page.client_storage.set(key, value)
                return
        except Exception as e:
            logger.debug(f"Erro ao gravar em page.client_storage: {e}")

    # 2. Tenta SharedPreferences
    try:
        sp = getattr(page, "shared_preferences", None)
        if sp is None and hasattr(page, "services"):
            sp = getattr(page.services, "shared_preferences", None)
        if sp and hasattr(sp, "set"):
            await sp.set(key, value)
    except Exception as e:
        logger.debug(f"Erro ao gravar em shared_preferences: {e}")

