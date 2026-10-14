"""
Utilitário de armazenamento resiliente de preferências do cliente.
Compatível com diferentes versões do Flet (page.client_storage, SharedPreferences,
arquivo JSON local persistente e in-memory fallback).
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)

# Diretório padrão para armazenamento de preferências persistentes locais
_CONFIG_DIR = Path.home() / ".config" / "kairos"
_PREFS_FILE = _CONFIG_DIR / "preferences.json"

_IN_MEMORY_STORAGE: dict[str, Any] = {}
_FILE_LOADED = False


def _ensure_file_loaded() -> None:
    """Carrega as preferências salvas no arquivo JSON local na memória uma única vez."""
    global _FILE_LOADED
    if _FILE_LOADED:
        return
    _FILE_LOADED = True
    try:
        if _PREFS_FILE.exists():
            with open(_PREFS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, dict):
                    _IN_MEMORY_STORAGE.update(data)
    except Exception as exc:
        logger.debug(f"Falha ao carregar preferências locais de {_PREFS_FILE}: {exc}")


def _save_to_local_file() -> None:
    """Grava as preferências em disco de forma síncrona e segura."""
    try:
        _CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        with open(_PREFS_FILE, "w", encoding="utf-8") as f:
            json.dump(_IN_MEMORY_STORAGE, f, ensure_ascii=False, indent=2)
    except Exception as exc:
        logger.debug(f"Falha ao persistir preferências em disco: {exc}")


def storage_get_sync(key: str, default: Any = None) -> Any:
    """Obtém um valor do armazenamento local de forma síncrona e instantânea."""
    _ensure_file_loaded()
    return _IN_MEMORY_STORAGE.get(key, default)


def storage_set_sync(key: str, value: Any) -> None:
    """Grava um valor no armazenamento local de forma síncrona e instantânea."""
    _ensure_file_loaded()
    _IN_MEMORY_STORAGE[key] = value
    _save_to_local_file()


async def storage_get(page: Any | None, key: str, default: Any = None) -> Any:
    """Obtém um valor do armazenamento local de forma resiliente."""
    _ensure_file_loaded()

    if not page:
        return _IN_MEMORY_STORAGE.get(key, default)

    # 1. Tenta page.client_storage (Flet < 0.80 ou wrappers)
    if hasattr(page, "client_storage") and page.client_storage is not None:
        try:
            if hasattr(page.client_storage, "get_async"):
                val = await page.client_storage.get_async(key)
                if val is not None:
                    _IN_MEMORY_STORAGE[key] = val
                    return val
            if hasattr(page.client_storage, "get"):
                val = page.client_storage.get(key)
                if val is not None:
                    _IN_MEMORY_STORAGE[key] = val
                    return val
        except Exception as e:
            logger.debug(f"Erro ao ler de page.client_storage: {e}")

    # 2. Tenta SharedPreferences / page.shared_preferences (Flet 0.80+)
    try:
        sp = getattr(page, "shared_preferences", None)
        if sp is None and hasattr(page, "services"):
            sp = getattr(page.services, "shared_preferences", None)
        if sp and hasattr(sp, "get"):
            val = await sp.get(key)
            if val is not None:
                _IN_MEMORY_STORAGE[key] = val
                return val
    except Exception as e:
        logger.debug(f"Erro ao ler de shared_preferences: {e}")

    return _IN_MEMORY_STORAGE.get(key, default)


async def storage_set(page: Any | None, key: str, value: Any) -> None:
    """Salva um valor no armazenamento local de forma resiliente."""
    _ensure_file_loaded()
    _IN_MEMORY_STORAGE[key] = value
    _save_to_local_file()

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
