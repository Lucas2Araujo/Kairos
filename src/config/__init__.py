"""Módulo centralizado de configuração do aplicativo.

Lê variáveis de ambiente do sistema com fallback para arquivo .env local.
Exporta as credenciais necessárias para acesso aos serviços externos (Supabase).
"""

from __future__ import annotations

import os
from pathlib import Path

# Tenta carregar BUILD_ENV injetado no build se disponível
try:
    from src.config._build_env import BUILD_ENV
except ImportError:
    BUILD_ENV = {}

# Carrega arquivo .env local se python-dotenv estiver instalado e o arquivo existir
try:
    from dotenv import load_dotenv

    # Procura .env na raiz do projeto (diretório pai de src/), em assets/ ou no diretório de dados
    base_dir = Path(__file__).resolve().parent.parent.parent
    config_dir = Path(__file__).resolve().parent
    candidate_paths = [
        base_dir / ".env",
        base_dir / "assets" / ".env",
        config_dir / ".env",
        Path("assets/.env").resolve(),
        Path(".env").resolve(),
    ]
    for env_var in (
        "FILES_DIR",
        "ANDROID_PRIVATE",
        "FLET_APP_STORAGE_DATA",
        "SERIOUS_PYTHON_APP",
        "SERIOUS_PYTHON_APP_DIR",
        "FLET_APP_STORAGE_TEMP",
    ):
        val = os.environ.get(env_var)
        if val:
            candidate_paths.append(Path(val) / ".env")
            candidate_paths.append(Path(val) / "assets" / ".env")
            candidate_paths.append(Path(val) / "src" / "config" / ".env")

    loaded = False
    for candidate in candidate_paths:
        if candidate.is_file():
            load_dotenv(dotenv_path=candidate)
            loaded = True
            break
    if not loaded:
        load_dotenv()
except ImportError:
    pass

# Supabase 1: Devocionais (Conteúdo Público)
DEVOTIONAL_SUPABASE_URL: str = (
    os.getenv("DEVOTIONAL_SUPABASE_URL")
    or os.getenv("SUPABASE_URL")
    or BUILD_ENV.get("DEVOTIONAL_SUPABASE_URL")
    or BUILD_ENV.get("SUPABASE_URL")
    or ""
).strip().rstrip("/")

DEVOTIONAL_SUPABASE_ANON_KEY: str = (
    os.getenv("DEVOTIONAL_SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or BUILD_ENV.get("DEVOTIONAL_SUPABASE_ANON_KEY")
    or BUILD_ENV.get("SUPABASE_ANON_KEY")
    or ""
).strip()

# Supabase 2: Usuários e Autenticação (OAuth / Sincronização)
# Fallback automático para DEVOTIONAL_SUPABASE_* caso usem o mesmo projeto Supabase
AUTH_SUPABASE_URL: str = (
    os.getenv("AUTH_SUPABASE_URL")
    or os.getenv("DEVOTIONAL_SUPABASE_URL")
    or os.getenv("SUPABASE_URL")
    or BUILD_ENV.get("AUTH_SUPABASE_URL")
    or BUILD_ENV.get("DEVOTIONAL_SUPABASE_URL")
    or BUILD_ENV.get("SUPABASE_URL")
    or ""
).strip().rstrip("/")

AUTH_SUPABASE_ANON_KEY: str = (
    os.getenv("AUTH_SUPABASE_ANON_KEY")
    or os.getenv("DEVOTIONAL_SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or BUILD_ENV.get("AUTH_SUPABASE_ANON_KEY")
    or BUILD_ENV.get("DEVOTIONAL_SUPABASE_ANON_KEY")
    or BUILD_ENV.get("SUPABASE_ANON_KEY")
    or ""
).strip()

AUTH_REDIRECT_URI: str = (
    os.getenv("AUTH_REDIRECT_URI")
    or BUILD_ENV.get("AUTH_REDIRECT_URI")
    or "nhaapp://login-callback"
).strip()

# Aliases para compatibilidade retroativa
SUPABASE_URL: str = DEVOTIONAL_SUPABASE_URL
SUPABASE_ANON_KEY: str = DEVOTIONAL_SUPABASE_ANON_KEY


def is_supabase_configured() -> bool:
    """Verifica se as credenciais do Supabase de Devocionais estão devidamente preenchidas."""
    return bool(DEVOTIONAL_SUPABASE_URL and DEVOTIONAL_SUPABASE_ANON_KEY)


def is_auth_supabase_configured() -> bool:
    """Verifica se as credenciais do Supabase de Autenticação estão devidamente preenchidas."""
    return bool(AUTH_SUPABASE_URL and AUTH_SUPABASE_ANON_KEY)

