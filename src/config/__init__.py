"""Módulo centralizado de configuração do aplicativo.

Lê variáveis de ambiente do sistema com fallback para arquivo .env local.
Exporta as credenciais necessárias para acesso aos serviços externos (Supabase).
"""

from __future__ import annotations

import os
from pathlib import Path

# Carrega arquivo .env local se python-dotenv estiver instalado e o arquivo existir
try:
    from dotenv import load_dotenv

    # Procura .env na raiz do projeto (diretório pai de src/) ou em assets/
    base_dir = Path(__file__).resolve().parent.parent.parent
    env_file = base_dir / ".env"
    assets_env = base_dir / "assets" / ".env"
    if env_file.exists():
        load_dotenv(dotenv_path=env_file)
    elif assets_env.exists():
        load_dotenv(dotenv_path=assets_env)
    else:
        load_dotenv()
except ImportError:
    pass

# Supabase 1: Devocionais (Conteúdo Público)
DEVOTIONAL_SUPABASE_URL: str = (
    os.getenv("DEVOTIONAL_SUPABASE_URL") or os.getenv("SUPABASE_URL") or ""
).strip().rstrip("/")

DEVOTIONAL_SUPABASE_ANON_KEY: str = (
    os.getenv("DEVOTIONAL_SUPABASE_ANON_KEY") or os.getenv("SUPABASE_ANON_KEY") or ""
).strip()

# Supabase 2: Usuários e Autenticação (OAuth / Sincronização)
# Fallback automático para DEVOTIONAL_SUPABASE_* caso usem o mesmo projeto Supabase
AUTH_SUPABASE_URL: str = (
    os.getenv("AUTH_SUPABASE_URL")
    or os.getenv("DEVOTIONAL_SUPABASE_URL")
    or os.getenv("SUPABASE_URL")
    or ""
).strip().rstrip("/")

AUTH_SUPABASE_ANON_KEY: str = (
    os.getenv("AUTH_SUPABASE_ANON_KEY")
    or os.getenv("DEVOTIONAL_SUPABASE_ANON_KEY")
    or os.getenv("SUPABASE_ANON_KEY")
    or ""
).strip()

AUTH_REDIRECT_URI: str = (os.getenv("AUTH_REDIRECT_URI") or "nhaapp://login-callback").strip()

# Aliases para compatibilidade retroativa
SUPABASE_URL: str = DEVOTIONAL_SUPABASE_URL
SUPABASE_ANON_KEY: str = DEVOTIONAL_SUPABASE_ANON_KEY


def is_supabase_configured() -> bool:
    """Verifica se as credenciais do Supabase de Devocionais estão devidamente preenchidas."""
    return bool(DEVOTIONAL_SUPABASE_URL and DEVOTIONAL_SUPABASE_ANON_KEY)


def is_auth_supabase_configured() -> bool:
    """Verifica se as credenciais do Supabase de Autenticação estão devidamente preenchidas."""
    return bool(AUTH_SUPABASE_URL and AUTH_SUPABASE_ANON_KEY)

