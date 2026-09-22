import os
from pathlib import Path
import main
import web
from src.services.content_manager import ContentManager


def test_web_module_imports():
    assert hasattr(web, "main")
    assert web.main is main.main
    assert "HINARIO_MODULES_DIR" in os.environ
    assert Path(os.environ["HINARIO_MODULES_DIR"]).exists()


def test_web_content_manager_modules_resolution():
    manager = ContentManager()
    assert manager.modules_dir.exists()
    # Verifica que o diretório gravável de módulos é consistente com o ambiente web
    assert str(manager.modules_dir) == os.environ["HINARIO_MODULES_DIR"]
