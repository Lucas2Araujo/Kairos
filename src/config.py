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

    # Procura .env na raiz do projeto (diretório pai de src/) ou no diretório corrente
    base_dir = Path(__file__).resolve().parent.parent
    env_file = base_dir / ".env"
    if env_file.exists():
        load_dotenv(dotenv_path=env_file)
    else:
        load_dotenv()
except ImportError:
    pass

# Supabase API Settings
# SUPABASE_URL: URL do projeto Supabase (ex: https://xyz.supabase.co)
SUPABASE_URL: str = (os.getenv("SUPABASE_URL") or "").strip().rstrip("/")

# SUPABASE_ANON_KEY: Chave pública/anônima (anon key) para consumo seguro cliente
SUPABASE_ANON_KEY: str = (os.getenv("SUPABASE_ANON_KEY") or "").strip()


def is_supabase_configured() -> bool:
    """Verifica se as credenciais do Supabase estão devidamente preenchidas."""
    return bool(SUPABASE_URL and SUPABASE_ANON_KEY)

