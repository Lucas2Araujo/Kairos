import os
from pathlib import Path

from dotenv import load_dotenv
import flet as ft

# Carrega variáveis de ambiente de .env se existir
root_dir = Path(__file__).resolve().parent
env_file = root_dir / ".env"
if env_file.exists():
    load_dotenv(dotenv_path=env_file)

# Garante que a pasta assets exista para servir arquivos estáticos
assets_dir = root_dir / "assets"
assets_dir.mkdir(parents=True, exist_ok=True)

# Define diretório gravável de módulos padrão se não especificado
if "HINARIO_MODULES_DIR" not in os.environ:
    web_modules_dir = root_dir / "assets" / "modules"
    web_modules_dir.mkdir(parents=True, exist_ok=True)
    os.environ["HINARIO_MODULES_DIR"] = str(web_modules_dir)

from main import main

if __name__ == "__main__":
    # Configuração de porta e host para execução web
    port = int(os.environ.get("PORT", "8550"))
    host = os.environ.get("HOST", "0.0.0.0" if os.environ.get("PORT") else "127.0.0.1")
    print(f"Iniciando Kairós Web em http://{host}:{port} ...")
    ft.run(
        main,
        view=ft.AppView.WEB_BROWSER,
        assets_dir=str(assets_dir),
        host=host,
        port=port,
    )
