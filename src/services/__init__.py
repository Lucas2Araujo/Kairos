"""
Módulo de serviços de negócios do Kairós.
Exporta serviços canônicos e aliases em Português/Inglês para retrocompatibilidade total.
"""

from .agente_service import AgenteService
from .audio_player_manager import AudioPlayerManager
from .auth_service import AuthService
from .cloud_sync_service import CloudSyncService
from .content_manager import ContentManager
from .devotional_service import DevotionalService
from .escola_sabatina_service import EscolaSabatinaService
from .hino_recommender import HinoRecommender
from .media_service import MediaService
from .notification_service import NotificationReminderConfig, NotificationService
from .quiz_service import QuizService
from .reading_service import ReadingService
from .search_service import (
    SearchContentType,
    SearchResultItem,
    SearchResultsPage,
    SearchService,
)
from .theme_service import ThemeService
from .updater_service import UpdaterService
from .wallpaper_service import WallpaperService

# Aliases em Português
AutenticacaoService = AuthService
SincronizacaoNuvemService = CloudSyncService
GerenciadorConteudo = ContentManager
MeditacaoService = DevotionalService
RecomendadorHinos = HinoRecommender
NotificacaoService = NotificationService
LeituraService = ReadingService
BuscaService = SearchService
TemaService = ThemeService
AtualizadorService = UpdaterService
PapelDeParedeService = WallpaperService

__all__ = [
    # Serviços canônicos / existentes
    "AgenteService",
    "AudioPlayerManager",
    "AuthService",
    "AutenticacaoService",
    "CloudSyncService",
    "SincronizacaoNuvemService",
    "ContentManager",
    "GerenciadorConteudo",
    "DevotionalService",
    "MeditacaoService",
    "EscolaSabatinaService",
    "HinoRecommender",
    "RecomendadorHinos",
    "MediaService",
    "NotificationReminderConfig",
    "NotificationService",
    "NotificacaoService",
    "QuizService",
    "ReadingService",
    "LeituraService",
    "SearchContentType",
    "SearchResultItem",
    "SearchResultsPage",
    "SearchService",
    "BuscaService",
    "ThemeService",
    "TemaService",
    "UpdaterService",
    "AtualizadorService",
    "WallpaperService",
    "PapelDeParedeService",
]
