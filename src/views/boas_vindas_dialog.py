from __future__ import annotations

# Módulo canônico em Português
from src.views.welcome_dialog import (
    STORAGE_KEY_ONBOARDING_COMPLETED,
    WelcomeDialogController,
    is_onboarding_completed,
    show_welcome_dialog,
)

# Aliases em Português
BoasVindasDialogController = WelcomeDialogController
exibir_dialogo_boas_vindas = show_welcome_dialog

__all__ = [
    "WelcomeDialogController",
    "BoasVindasDialogController",
    "show_welcome_dialog",
    "exibir_dialogo_boas_vindas",
    "is_onboarding_completed",
    "STORAGE_KEY_ONBOARDING_COMPLETED",
]

