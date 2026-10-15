"""
Módulo de views da interface gráfica (Flet) do Kairós.
Exporta views e dialogs canônicos em Português e aliases legados em Inglês.
"""

from .agente_view import AgenteView
from .atualizacao_dialog import (
    AtualizacaoDialog,
    UpdateDialog,
    exibir_dialogo_atualizacao,
    show_update_dialog,
)
from .biblia_view import BibliaView
from .boas_vindas_dialog import (
    BoasVindasDialogController,
    WelcomeDialogController,
    exibir_dialogo_boas_vindas,
    is_onboarding_completed,
    show_welcome_dialog,
)
from .busca_resultados_view import BuscaResultadosView
from .configuracoes_dialog import (
    ConfiguracoesDialogController,
    SettingsDialogController,
    close_all_dialogs,
    ensure_page_dialogs,
    exibir_dialogo_configuracoes,
    exibir_dialogo_perfil,
    exibir_dialogo_sobre,
    fechar_todos_dialogos,
    show_about_dialog,
    show_profile_dialog,
    show_settings_dialog,
)
from .downloads_view import DownloadsView
from .escola_sabatina_view import EscolaSabatinaView
from .gerenciar_cache_view import GerenciarCacheView
from .hinario_view import HinarioView, HinosView, HomeView
from .hino_view import HinoView
from .meditacao_destaque_view import MeditacaoDestaqueView
from .meditacao_view import MeditacaoView
from .ofensiva_view import OfensivaView
from .quiz_view import QuizView
from .selecao_view import SelecaoView
from .tirinha_view import TirinhaView
from .trimestres_view import TrimestresView

__all__ = [
    # Views principais
    "AgenteView",
    "BibliaView",
    "BuscaResultadosView",
    "DownloadsView",
    "EscolaSabatinaView",
    "GerenciarCacheView",
    "HinoView",
    "HinarioView",
    "HinosView",
    "HomeView",
    "MeditacaoDestaqueView",
    "MeditacaoView",
    "OfensivaView",
    "QuizView",
    "SelecaoView",
    "TirinhaView",
    "TrimestresView",
    # Diálogos e Controladores
    "ConfiguracoesDialogController",
    "SettingsDialogController",
    "show_settings_dialog",
    "exibir_dialogo_configuracoes",
    "show_profile_dialog",
    "exibir_dialogo_perfil",
    "show_about_dialog",
    "exibir_dialogo_sobre",
    "close_all_dialogs",
    "fechar_todos_dialogos",
    "ensure_page_dialogs",
    "AtualizacaoDialog",
    "UpdateDialog",
    "show_update_dialog",
    "exibir_dialogo_atualizacao",
    "WelcomeDialogController",
    "BoasVindasDialogController",
    "show_welcome_dialog",
    "exibir_dialogo_boas_vindas",
    "is_onboarding_completed",
]
