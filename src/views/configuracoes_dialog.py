from __future__ import annotations

# Módulo canônico em Português
from src.views.settings_dialog import (
    SettingsDialogController,
    close_all_dialogs,
    ensure_page_dialogs,
    show_about_dialog,
    show_profile_dialog,
    show_settings_dialog,
)

# Aliases em Português
ConfiguracoesDialogController = SettingsDialogController
exibir_dialogo_configuracoes = show_settings_dialog
exibir_dialogo_perfil = show_profile_dialog
exibir_dialogo_sobre = show_about_dialog
fechar_todos_dialogos = close_all_dialogs

__all__ = [
    "SettingsDialogController",
    "ConfiguracoesDialogController",
    "show_settings_dialog",
    "exibir_dialogo_configuracoes",
    "show_profile_dialog",
    "exibir_dialogo_perfil",
    "show_about_dialog",
    "exibir_dialogo_sobre",
    "close_all_dialogs",
    "fechar_todos_dialogos",
    "ensure_page_dialogs",
]

