"""Testes unitários para o módulo de configuração src/config.py."""

import os
from unittest import mock
import importlib
import pytest


def test_config_with_env_variables(monkeypatch):
    """Verifica se config lê corretamente variáveis definidas no os.environ."""
    monkeypatch.setenv("SUPABASE_URL", "https://xyzcompany.supabase.co/")
    monkeypatch.setenv("SUPABASE_ANON_KEY", "secret-anon-key-12345")

    import src.config as config
    importlib.reload(config)

    assert config.SUPABASE_URL == "https://xyzcompany.supabase.co"
    assert config.SUPABASE_ANON_KEY == "secret-anon-key-12345"
    assert config.is_supabase_configured() is True


def test_config_empty_env(monkeypatch):
    """Verifica comportamento padrão caso variáveis não estejam configuradas."""
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    with mock.patch("dotenv.load_dotenv", return_value=None):
        import src.config as config
        importlib.reload(config)

    assert config.SUPABASE_URL == ""
    assert config.SUPABASE_ANON_KEY == ""
    assert config.is_supabase_configured() is False


def test_config_loads_dotenv(tmp_path, monkeypatch):
    """Verifica se carrega variáveis a partir de um arquivo .env quando presente."""
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    fake_env = tmp_path / ".env"
    fake_env.write_text(
        "SUPABASE_URL=https://custom.supabase.co\nSUPABASE_ANON_KEY=custom-key\n",
        encoding="utf-8",
    )

    with mock.patch("src.config.Path") as mock_path:
        mock_path.return_value.resolve.return_value.parent.parent = tmp_path
        # Simula o efeito de load_dotenv populando os.environ
        def fake_load_dotenv(dotenv_path=None):
            os.environ["SUPABASE_URL"] = "https://custom.supabase.co"
            os.environ["SUPABASE_ANON_KEY"] = "custom-key"

        with mock.patch("dotenv.load_dotenv", side_effect=fake_load_dotenv):
            import src.config as config
            importlib.reload(config)

    assert config.SUPABASE_URL == "https://custom.supabase.co"
    assert config.SUPABASE_ANON_KEY == "custom-key"
    assert config.is_supabase_configured() is True

