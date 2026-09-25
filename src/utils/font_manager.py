"""
Gerenciador de tipografia e fontes locais/dinâmicas para o aplicativo Kairós.
Configura Montserrat como fonte padrão e oferece suporte ao carregamento em tempo de execução
de fontes adicionais baixadas localmente.
"""

from pathlib import Path
import flet as ft

DEFAULT_FONT_FAMILY = "Helvetica"

INITIAL_FONTS: dict[str, str] = {
    "Montserrat": "fonts/Montserrat-Regular.ttf",
    "Montserrat-Regular": "fonts/Montserrat-Regular.ttf",
    "AppSans": "fonts/AppSans-Regular.ttf",
    "AppSans-Bold": "fonts/AppSans-SemiBold.ttf",
    "HymnSerif": "fonts/HymnSerif-Regular.ttf",
    "HymnSerif-Bold": "fonts/HymnSerif-Bold.ttf",
    "OpenDyslexic": "fonts/OpenDyslexic-Regular.otf",
    "OpenDyslexic-Bold": "fonts/OpenDyslexic-Bold.otf",
    "Helvetica": "fonts/Helvetica-World-Regular.ttf",
}


class FontManager:
    """Controlador central de fontes do aplicativo."""

    @staticmethod
    def get_initial_fonts() -> dict[str, str]:
        """Retorna o dicionário de fontes empacotadas estaticamente na aplicação."""
        return dict(INITIAL_FONTS)

    @staticmethod
    def register_fonts(page: ft.Page) -> None:
        """
        Registra com segurança o catálogo de fontes padrão na página.
        Preserva fontes previamente cadastradas e evita reatribuições desnecessárias.
        """
        if not page:
            return

        current_fonts = getattr(page, "fonts", None)
        if current_fonts is not None and all(
            k in current_fonts and current_fonts[k] == v
            for k, v in INITIAL_FONTS.items()
        ):
            return

        merged_fonts = dict(INITIAL_FONTS)
        if current_fonts:
            merged_fonts.update(current_fonts)
        page.fonts = merged_fonts

    @staticmethod
    def register_downloaded_fonts(
        page: ft.Page, storage_dir: str | Path
    ) -> list[str]:
        """
        Varre o diretório fornecido procurando arquivos .ttf e .otf salvos localmente
        (ex: Central de Downloads) e registra as fontes dinamicamente em page.fonts.

        Retorna a lista de nomes de famílias tipográficas registradas com sucesso.
        """
        registered: list[str] = []
        if not page:
            return registered

        dir_path = Path(storage_dir)
        if not dir_path.exists() or not dir_path.is_dir():
            return registered

        current_fonts = getattr(page, "fonts", None) or {}

        for font_file in sorted(dir_path.iterdir()):
            if font_file.is_file() and font_file.suffix.lower() in (".ttf", ".otf"):
                family_name = font_file.stem
                font_path = str(font_file.resolve())
                current_fonts[family_name] = font_path
                registered.append(family_name)

        page.fonts = current_fonts
        return registered

