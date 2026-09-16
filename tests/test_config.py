"""Testes unitários para o módulo de configuração src/config.py."""

import os
from unittest import mock
import importlib
import pytest


def test_config_with_devotional_env_variables(monkeypatch):
    """Verifica se config lê corretamente DEVOTIONAL_SUPABASE_*."""
    monkeypatch.setenv("DEVOTIONAL_SUPABASE_URL", "https://devotional.supabase.co/")
    monkeypatch.setenv("DEVOTIONAL_SUPABASE_ANON_KEY", "devotional-anon-key-999")
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    with mock.patch("dotenv.load_dotenv", return_value=None):
        import src.config as config
        importlib.reload(config)

    assert config.DEVOTIONAL_SUPABASE_URL == "https://devotional.supabase.co"
    assert config.DEVOTIONAL_SUPABASE_ANON_KEY == "devotional-anon-key-999"
    assert config.SUPABASE_URL == "https://devotional.supabase.co"
    assert config.SUPABASE_ANON_KEY == "devotional-anon-key-999"
    assert config.is_supabase_configured() is True


def test_config_with_legacy_env_variables(monkeypatch):
    """Verifica se config mantém fallback para SUPABASE_URL e SUPABASE_ANON_KEY antigos."""
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_URL", raising=False)
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_ANON_KEY", raising=False)
    monkeypatch.setenv("SUPABASE_URL", "https://xyzcompany.supabase.co/")
    monkeypatch.setenv("SUPABASE_ANON_KEY", "secret-anon-key-12345")

    with mock.patch("dotenv.load_dotenv", return_value=None):
        import src.config as config
        importlib.reload(config)

    assert config.DEVOTIONAL_SUPABASE_URL == "https://xyzcompany.supabase.co"
    assert config.DEVOTIONAL_SUPABASE_ANON_KEY == "secret-anon-key-12345"
    assert config.SUPABASE_URL == "https://xyzcompany.supabase.co"
    assert config.SUPABASE_ANON_KEY == "secret-anon-key-12345"
    assert config.is_supabase_configured() is True


def test_config_empty_env(monkeypatch):
    """Verifica comportamento padrão caso variáveis não estejam configuradas."""
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_URL", raising=False)
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_ANON_KEY", raising=False)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    with mock.patch("dotenv.load_dotenv", return_value=None):
        import src.config as config
        importlib.reload(config)

    assert config.DEVOTIONAL_SUPABASE_URL == ""
    assert config.DEVOTIONAL_SUPABASE_ANON_KEY == ""
    assert config.SUPABASE_URL == ""
    assert config.SUPABASE_ANON_KEY == ""
    assert config.is_supabase_configured() is False


def test_config_loads_dotenv(tmp_path, monkeypatch):
    """Verifica se carrega variáveis a partir de um arquivo .env quando presente."""
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_URL", raising=False)
    monkeypatch.delenv("DEVOTIONAL_SUPABASE_ANON_KEY", raising=False)
    monkeypatch.delenv("SUPABASE_URL", raising=False)
    monkeypatch.delenv("SUPABASE_ANON_KEY", raising=False)

    fake_env = tmp_path / ".env"
    fake_env.write_text(
        "DEVOTIONAL_SUPABASE_URL=https://custom.supabase.co\nDEVOTIONAL_SUPABASE_ANON_KEY=custom-key\n",
        encoding="utf-8",
    )

    with mock.patch("src.config.Path") as mock_path:
        mock_path.return_value.resolve.return_value.parent.parent = tmp_path
        # Simula o efeito de load_dotenv populando os.environ
        def fake_load_dotenv(dotenv_path=None):
            os.environ["DEVOTIONAL_SUPABASE_URL"] = "https://custom.supabase.co"
            os.environ["DEVOTIONAL_SUPABASE_ANON_KEY"] = "custom-key"

        with mock.patch("dotenv.load_dotenv", side_effect=fake_load_dotenv):
            import src.config as config
            importlib.reload(config)

    assert config.DEVOTIONAL_SUPABASE_URL == "https://custom.supabase.co"
    assert config.DEVOTIONAL_SUPABASE_ANON_KEY == "custom-key"
    assert config.is_supabase_configured() is True

