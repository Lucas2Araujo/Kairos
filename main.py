import asyncio
import inspect
import urllib.parse
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import flet as ft

# Registrar plugins do Flet 0.23+ globalmente na raiz
try:
    import flet_video
except ImportError:
    pass

from src.database.connection import DatabaseConnection
from src.database.devotional_repo import DevotionalRepository
from src.repositories.biblia_repository import BibliaRepository
from src.repositories.comparativo_repository import ComparativoRepository
from src.repositories.culto_repository import CultoRepository
from src.repositories.favorito_repository import FavoritoRepository
from src.repositories.hino_repository import HinoRepository
from src.repositories.historico_repository import HistoricoRepository
from src.services.agente_service import AgenteService
from src.services.content_manager import ContentManager
from src.services.auth_service import AuthService
from src.services.devotional_service import DevotionalService
from src.services.reading_service import ReadingService
from src.services.media_service import MediaService
from src.services.cloud_sync_service import CloudSyncService
from src.services.theme_service import EDITION_ANTIGO, EDITION_NOVO, ThemeService
from src.services.updater_service import UpdaterService
from src.theme import ThemeEngine
from src.utils.font_manager import DEFAULT_FONT_FAMILY, FontManager
from src.views.agente_view import AgenteView
from src.views.biblia_view import BibliaView
from src.views.download_manager_view import DownloadManagerView
from src.views.downloads_view import DownloadsView
from src.repositories.escola_sabatina_repository import EscolaSabatinaRepository
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.services.quiz_service import QuizService
from src.views.escola_sabatina_view import EscolaSabatinaView
from src.views.gerenciar_cache_view import GerenciarCacheView
from src.views.hino_view import HinoView
from src.views.home_view import HinosView, HomeView
from src.views.meditacao_view import MeditacaoView
from src.views.selecao_view import SelecaoView
from src.views.settings_dialog import ensure_page_dialogs
from src.views.trimestres_view import TrimestresView
from src.views.update_dialog import show_update_dialog
from src.views.welcome_dialog import is_onboarding_completed, show_welcome_dialog

try:
    from src.version import __version__ as APP_VERSION
except ImportError:
    APP_VERSION = "0.2.2"

ROUTE_SELECAO = "/"
ROUTE_NOVO = "/novo"
ROUTE_ANTIGO = "/antigo"
ROUTE_AGENTE = "/agente"
ROUTE_DOWNLOADS = "/downloads"
ROUTE_BIBLIA = "/biblia"
ROUTE_MEDITACOES = "/meditacoes"
ROUTE_MEDITACOES_CACHE = "/meditacoes/cache"
ROUTE_ESCOLA_SABATINA = "/escola-sabatina"
ROUTE_ESCOLA_SABATINA_TRIMESTRES = "/escola-sabatina/trimestres"

_background_tasks: set[asyncio.Task] = set()


@dataclass
class EditionContext:
    """Encapsula os repositórios e a lista em cache de IDs para uma edição do hinário."""
    hino_repo: HinoRepository
    fav_repo: FavoritoRepository
    hist_repo: HistoricoRepository
    hino_ids: list[int] = field(default_factory=list)


async def _get_hino_ids(
    hino_repository: HinoRepository, hino_ids_ordered: list[int]
) -> list[int]:
    """Carrega a lista ordenada de IDs de hinos (uma vez, lazy)."""
    if not hino_ids_ordered:
        all_hinos = await hino_repository.get_all()
        hino_ids_ordered.extend([h.id for h in all_hinos if h.id is not None])
    return hino_ids_ordered


def _set_window_icon_if_exists(page: ft.Page, asset_icon: Path) -> None:
    """Define o ícone da janela se o arquivo existir."""
    if asset_icon.exists():
        try:
            page.window.icon = str(asset_icon)
        except Exception:
            pass


def _setup_assets_and_theme(
    page: ft.Page, theme_service: ThemeService | None = None
) -> None:
    """Configura título, ícones, fontes e tema da aplicação."""
    is_web = getattr(page, "web", False)
    suffix = " (Web)" if is_web else ""
    page.title = f"Kairós v{APP_VERSION}{suffix}"

    root_dir = Path(__file__).resolve().parent
    asset_icon = root_dir / "assets" / "icon.ico"
    _set_window_icon_if_exists(page, asset_icon)

    FontManager.register_fonts(page)

    if theme_service:
        theme_service.apply_theme(page)
    else:
        page.theme_mode = ft.ThemeMode.SYSTEM
        page.theme = ft.Theme(
            font_family=DEFAULT_FONT_FAMILY,
            page_transitions=ft.PageTransitionsTheme(
                android=ft.PageTransitionTheme.CUPERTINO,
                ios=ft.PageTransitionTheme.CUPERTINO,
                linux=ft.PageTransitionTheme.CUPERTINO,
                macos=ft.PageTransitionTheme.CUPERTINO,
                windows=ft.PageTransitionTheme.CUPERTINO,
            ),
        )


def _build_loading_view(progress_val: float | None = None) -> ft.View:
    """
    Constrói a tela splash com fundo preto absoluto e o ícone centralizado do app.
    """
    return ft.View(
        route="/loading",
        bgcolor=ft.Colors.BLACK,
        padding=0,
        controls=[
            ft.SafeArea(
                maintain_bottom_view_padding=True,
                content=ft.Container(
                    content=ft.Image(
                        src="/icon.png",
                        width=128,
                        height=128,
                        fit=ft.BoxFit.CONTAIN,
                    ),
                    alignment=ft.Alignment.CENTER,
                    expand=True,
                ),
                expand=True,
            ),
        ],
    )


_build_splash_view = _build_loading_view



class ParsedRouteQuery(tuple):
    """Tupla de 5 elementos compatível com desempacotamento legado (r_base, q, cat, tema, from_hino)
    com atributos adicionais para filtros estendidos (ex: initial_filtro, filtro)."""

    def __new__(
        cls,
        route_base: str,
        initial_search: str,
        initial_categoria: str | None,
        initial_tema: str | None,
        from_hino: int | None,
        initial_filtro: str | None = None,
    ):
        instance = super().__new__(
            cls, (route_base, initial_search, initial_categoria, initial_tema, from_hino)
        )
        instance.route_base = route_base
        instance.initial_search = initial_search
        instance.initial_categoria = initial_categoria
        instance.initial_tema = initial_tema
        instance.from_hino = from_hino
        instance.initial_filtro = initial_filtro
        instance.filtro = initial_filtro
        return instance


def _parse_route_query(route: str) -> ParsedRouteQuery:
    """Extrai a rota base e os parâmetros de query da URL, retornando tupla compatível de 5 itens com metadados."""
    if "?" not in route:
        base = route or "/"
        if base == "/hinario":
            base = ROUTE_NOVO
        return ParsedRouteQuery(base, "", None, None, None, None)
    parts = route.split("?", 1)
    route_base = parts[0] or "/"
    if route_base == "/hinario":
        route_base = ROUTE_NOVO
    query_str = parts[1]
    initial_search = ""
    initial_categoria = None
    initial_tema = None
    from_hino = None
    initial_filtro = None
    for param in query_str.split("&"):
        if param.startswith("q="):
            initial_search = urllib.parse.unquote(param[2:])
        elif param.startswith("categoria="):
            initial_categoria = urllib.parse.unquote(param[10:])
        elif param.startswith("tema="):
            initial_tema = urllib.parse.unquote(param[5:])
        elif param.startswith("from_hino="):
            val = param[10:]
            if val.isdigit():
                from_hino = int(val)
        elif param.startswith("filtro="):
            initial_filtro = urllib.parse.unquote(param[7:])
    return ParsedRouteQuery(
        route_base, initial_search, initial_categoria, initial_tema, from_hino, initial_filtro
    )


def _parse_bible_route_query(
    route: str,
) -> tuple[str | None, int | None, int | None, int | None, list[str] | None]:
    """Extrai parâmetros específicos da rota bíblica (?livro=...&cap=...&ver=...&hino_id=...&meditacao_refs=...)."""
    if "?" not in route:
        return None, None, None, None, None
    query = urllib.parse.parse_qs(urllib.parse.urlsplit(route).query)
    livro = query.get("livro", [None])[0]
    if livro:
        livro = urllib.parse.unquote(livro)
    cap_val = query.get("cap", [None])[0] or query.get("capitulo", [None])[0]
    ver_val = query.get("ver", [None])[0] or query.get("versiculo", [None])[0]
    cap = int(cap_val) if cap_val and cap_val.isdigit() else None
    ver = int(ver_val) if ver_val and ver_val.isdigit() else None
    hino_id = (
        int(query.get("hino_id")[0])
        if "hino_id" in query and query["hino_id"][0].isdigit()
        else None
    )
    med_refs_raw = query.get("meditacao_refs", query.get("refs", [None]))[0]
    med_refs = None
    if med_refs_raw:
        med_refs = [r.strip() for r in urllib.parse.unquote(med_refs_raw).split("|") if r.strip()]
    return livro, cap, ver, hino_id, med_refs



async def _render_home_route(
    page: ft.Page,
    route_base: str,
    initial_search: str,
    initial_categoria: str | None,
    initial_tema: str | None,
    origin_hino_id: int | None,
    view_cache: dict[str, ft.View],
    home_novo_instance: HomeView | None,
    home_antigo_instance: HomeView | None,
    target_views: list[ft.View],
    initial_filtro: str | None = None,
) -> None:
    """Renderiza a HomeView do Hinário Novo (/novo) ou Hinário Antigo (/antigo)."""
    if (
        route_base == ROUTE_NOVO
        or route_base.startswith(f"{ROUTE_NOVO}/")
        or route_base.startswith("/hino/")
        or route_base == "/hinario"
    ):
        if home_novo_instance is not None:
            view_cache[ROUTE_NOVO] = await home_novo_instance.build(
                page,
                initial_search=initial_search,
                initial_categoria=initial_categoria,
                initial_tema=initial_tema,
                initial_filtro=initial_filtro,
                origin_hino_id=origin_hino_id,
            )
            target_views.append(view_cache[ROUTE_NOVO])
    elif route_base == ROUTE_ANTIGO or route_base.startswith(f"{ROUTE_ANTIGO}/"):
        if home_antigo_instance is not None:
            view_cache[ROUTE_ANTIGO] = await home_antigo_instance.build(
                page,
                initial_search=initial_search,
                initial_categoria=initial_categoria,
                initial_tema=initial_tema,
                initial_filtro=initial_filtro,
                origin_hino_id=origin_hino_id,
            )
            target_views.append(view_cache[ROUTE_ANTIGO])



def _render_agente_route(
    page: ft.Page,
    view_cache: dict[str, ft.View],
    agente_view_instance: AgenteView | None,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota do Agente Organizador (/agente)."""
    if page.route == ROUTE_AGENTE and agente_view_instance is not None:
        if ROUTE_AGENTE not in view_cache:
            view_cache[ROUTE_AGENTE] = agente_view_instance.build(page)
        target_views.append(view_cache[ROUTE_AGENTE])


_route_warning_snackbar: ft.SnackBar | None = None
_auth_feedback_snackbar: ft.SnackBar | None = None


def _show_route_warning(page: ft.Page, message: str) -> None:
    """Exibe um aviso via SnackBar caso o usuário tente acessar um módulo não instalado."""
    global _route_warning_snackbar
    if _route_warning_snackbar is None:
        _route_warning_snackbar = ft.SnackBar(
            content=ft.Text("", color=ft.Colors.WHITE, weight=ft.FontWeight.W_500),
            bgcolor=ft.Colors.AMBER_800,
            duration=3500,
            behavior=ft.SnackBarBehavior.FLOATING,
        )
        if hasattr(page, "overlay"):
            page.overlay.append(_route_warning_snackbar)
    _route_warning_snackbar.content = ft.Text(
        message, color=ft.Colors.WHITE, weight=ft.FontWeight.W_500
    )
    _route_warning_snackbar.open = True
    try:
        page.update()
    except Exception:
        pass


def _show_feedback_snackbar(
    page: ft.Page,
    message: str,
    bgcolor: str = ft.Colors.GREEN_700,
    icon: Any = None,
) -> None:
    """Exibe feedback visual ao usuário via SnackBar (ex: sucesso no login ou erros)."""
    global _auth_feedback_snackbar
    row_controls: list[ft.Control] = []
    if icon:
        row_controls.append(ft.Icon(icon, color=ft.Colors.WHITE, size=20))
    row_controls.append(
        ft.Text(message, color=ft.Colors.WHITE, weight=ft.FontWeight.W_500)
    )

    if _auth_feedback_snackbar is None:
        _auth_feedback_snackbar = ft.SnackBar(
            content=ft.Row(row_controls, spacing=10),
            bgcolor=bgcolor,
            duration=3500,
            behavior=ft.SnackBarBehavior.FLOATING,
        )
        if hasattr(page, "overlay"):
            page.overlay.append(_auth_feedback_snackbar)
    else:
        _auth_feedback_snackbar.content = ft.Row(row_controls, spacing=10)
        _auth_feedback_snackbar.bgcolor = bgcolor

    _auth_feedback_snackbar.open = True
    try:
        page.update()
    except Exception:
        pass


def _render_downloads_route(
    page: ft.Page,
    view_cache: dict[str, ft.View],
    downloads_view_instance: DownloadsView,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota do Gerenciador de Downloads (/downloads)."""
    if page.route == ROUTE_DOWNLOADS:
        view_cache[ROUTE_DOWNLOADS] = downloads_view_instance.build(page)
        target_views.append(view_cache[ROUTE_DOWNLOADS])


async def _render_meditacao_route(
    page: ft.Page,
    route_base: str,
    meditacao_view_instance: MeditacaoView | None,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota de Meditação Diária (/meditacoes)."""
    if route_base == ROUTE_MEDITACOES and meditacao_view_instance is not None:
        view = await meditacao_view_instance.build(page)
        target_views.append(view)


async def _render_meditacoes_cache_route(
    page: ft.Page,
    route_base: str,
    cache_view_instance: GerenciarCacheView | None,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota do Gerenciador de Cache de Devocionais (/meditacoes/cache)."""
    if route_base == ROUTE_MEDITACOES_CACHE and cache_view_instance is not None:
        view = await cache_view_instance.build(page)
        target_views.append(view)


async def _render_escola_sabatina_route(
    page: ft.Page,
    route_base: str,
    escola_sabatina_view_instance: EscolaSabatinaView | None,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota da Escola Sabatina (/escola-sabatina)."""
    if route_base == ROUTE_ESCOLA_SABATINA and escola_sabatina_view_instance is not None:
        view = escola_sabatina_view_instance.build(page)
        if inspect.isawaitable(view):
            view = await view
        target_views.append(view)


async def _render_trimestres_route(
    page: ft.Page,
    route_base: str,
    trimestres_view_instance: TrimestresView | None,
    target_views: list[ft.View],
) -> None:
    """Renderiza a rota de seleção de trimestres da Escola Sabatina (/escola-sabatina/trimestres)."""
    if route_base == ROUTE_ESCOLA_SABATINA_TRIMESTRES and trimestres_view_instance is not None:
        view = trimestres_view_instance.build(page)
        if inspect.isawaitable(view):
            view = await view
        target_views.append(view)


async def _render_hino_route(
    page: ft.Page,
    route_base: str,
    ctx_novo: EditionContext | None,
    ctx_antigo: EditionContext | None,
    media_service: MediaService | None,
    biblia_repository: BibliaRepository | None,
    target_views: list[ft.View],
    comparativo_repository: ComparativoRepository | None = None,
    theme_service: ThemeService | None = None,
) -> None:
    """Renderiza a rota detalhada do hino (/novo/hino/{id}, /antigo/hino/{id} ou /hino/{id})."""
    if not route_base.startswith(("/antigo/hino/", "/novo/hino/", "/hino/")):
        return

    is_antigo = route_base.startswith("/antigo/hino/")
    active_ctx = ctx_antigo if is_antigo else ctx_novo
    edition = EDITION_ANTIGO if is_antigo else EDITION_NOVO

    if active_ctx is None:
        return

    try:
        hino_id = int(route_base.split("/")[-1])
        await _get_hino_ids(active_ctx.hino_repo, active_ctx.hino_ids)
        antigo_repo = ctx_antigo.hino_repo if ctx_antigo else None
        novo_repo = ctx_novo.hino_repo if ctx_novo else None
        hino_view_instance = HinoView(
            hino_id,
            active_ctx.hino_repo,
            active_ctx.fav_repo,
            active_ctx.hist_repo,
            media_service,
            hino_ids_list=active_ctx.hino_ids,
            biblia_repository=biblia_repository,
            comparativo_repository=comparativo_repository,
            antigo_repository=antigo_repo,
            novo_repository=novo_repo,
            edition=edition,
            theme_service=theme_service,
        )
        built_view = await hino_view_instance.build(page)
        target_views.append(built_view)
    except ValueError:
        pass


async def _check_updates_background(page: ft.Page, updater_service: UpdaterService):
    """Verifica atualizações em segundo plano sem bloquear a inicialização do app."""
    try:
        if getattr(page, "web", False):
            return
        # Aguarda a estabilização completa da UI inicial
        await asyncio.sleep(5.0)
        update_info = await updater_service.check_for_updates()
        if update_info.get("update_available") and (
            update_info.get("download_url") or update_info.get("html_url")
        ):
            show_update_dialog(page, update_info, updater_service)
    except Exception:
        pass


@dataclass
class AppViews:
    """Encapsula as instâncias de visualizações principais da aplicação."""
    selecao_view: SelecaoView | None = None
    home_novo: HinosView | None = None
    home_antigo: HinosView | None = None
    agente_view: AgenteView | None = None
    downloads_view: DownloadsView | None = None
    biblia_view: BibliaView | None = None
    meditacao_view: MeditacaoView | None = None
    gerenciar_cache_view: GerenciarCacheView | None = None
    escola_sabatina_view: EscolaSabatinaView | None = None
    trimestres_view: TrimestresView | None = None


class AppRouter:
    """Controlador de rotas, histórico de navegação e ciclo de vida de conexões da aplicação."""

    def __init__(
        self,
        page: ft.Page,
        connections: tuple[DatabaseConnection, ...],
        views: AppViews | None = None,
        content_manager: ContentManager | None = None,
        media_service: MediaService | None = None,
        theme_service: ThemeService | None = None,
        ctx_novo: EditionContext | None = None,
        ctx_antigo: EditionContext | None = None,
        biblia_repository: BibliaRepository | None = None,
        comparativo_repository: ComparativoRepository | None = None,
        auth_service: AuthService | None = None,
        updater_service: UpdaterService | None = None,
        devotional_service: DevotionalService | None = None,
        reading_service: ReadingService | None = None,
        culto_repository: CultoRepository | None = None,
        agente_service: AgenteService | None = None,
        escola_sabatina_service: EscolaSabatinaService | None = None,
        escola_sabatina_repo: EscolaSabatinaRepository | None = None,
    ):
        self.page = page
        self.connections = connections
        self.views = views or AppViews()
        self.content_manager = content_manager or ContentManager()
        self.media_service = media_service
        self.theme_service = theme_service
        self.ctx_novo = ctx_novo
        self.ctx_antigo = ctx_antigo
        self.biblia_repository = biblia_repository
        self.comparativo_repository = comparativo_repository
        self.auth_service = auth_service or AuthService()
        self.updater_service = updater_service
        self.devotional_service = devotional_service
        self.reading_service = reading_service
        self.culto_repository = culto_repository
        self.agente_service = agente_service
        self.escola_sabatina_service = escola_sabatina_service
        self.escola_sabatina_repo = escola_sabatina_repo

        # Instâncias de views (injetadas ou lazy factories)
        self._selecao_view = getattr(self.views, "selecao_view", None)
        self._home_novo = getattr(self.views, "home_novo", None)
        self._home_antigo = getattr(self.views, "home_antigo", None)
        self._agente_view = getattr(self.views, "agente_view", None)
        self._downloads_view = getattr(self.views, "downloads_view", None)
        self._biblia_view = getattr(self.views, "biblia_view", None)
        self._meditacao_view = getattr(self.views, "meditacao_view", None)
        self._gerenciar_cache_view = getattr(self.views, "gerenciar_cache_view", None)
        self._escola_sabatina_view = getattr(self.views, "escola_sabatina_view", None)
        self._trimestres_view = getattr(self.views, "trimestres_view", None)

        self._cached_selecao_view: ft.View | None = None
        self.view_cache: dict[str, ft.View] = {}
        self.navigation_history: list[str] = []
        self.current_tracked_route: list[str] = [page.route or "/"]
        self.is_popping: bool = False

    @property
    def selecao_view(self) -> SelecaoView:
        if self._selecao_view is None:
            theme_srv = self.theme_service
            if theme_srv is None:
                db_conn = self.connections[0] if self.connections else None
                if db_conn is not None:
                    theme_srv = ThemeService(db_conn)
            self._selecao_view = SelecaoView(
                theme_service=theme_srv,
                updater_service=self.updater_service,
                content_manager=self.content_manager,
                auth_service=self.auth_service,
                devotional_service=self.devotional_service,
                reading_service=self.reading_service,
            )
        return self._selecao_view

    @selecao_view.setter
    def selecao_view(self, val: SelecaoView | None) -> None:
        self._selecao_view = val
        self._cached_selecao_view = None

    @property
    def home_novo(self) -> HinosView | None:
        if self._home_novo is None and self.ctx_novo:
            antigo_repo = self.ctx_antigo.hino_repo if self.ctx_antigo else None
            antigo_fav = self.ctx_antigo.fav_repo if self.ctx_antigo else None
            antigo_hist = self.ctx_antigo.hist_repo if self.ctx_antigo else None
            self._home_novo = HinosView(
                self.ctx_novo.hino_repo,
                self.ctx_novo.fav_repo,
                self.ctx_novo.hist_repo,
                updater_service=self.updater_service,
                theme_service=self.theme_service,
                edition=EDITION_NOVO,
                antigo_hino_repo=antigo_repo,
                antigo_fav_repo=antigo_fav,
                antigo_hist_repo=antigo_hist,
            )
        return self._home_novo

    @home_novo.setter
    def home_novo(self, val: HinosView | None) -> None:
        self._home_novo = val

    @property
    def home_antigo(self) -> HinosView | None:
        if self._home_antigo is None and self.ctx_antigo:
            novo_repo = self.ctx_novo.hino_repo if self.ctx_novo else None
            novo_fav = self.ctx_novo.fav_repo if self.ctx_novo else None
            novo_hist = self.ctx_novo.hist_repo if self.ctx_novo else None
            self._home_antigo = HinosView(
                self.ctx_antigo.hino_repo,
                self.ctx_antigo.fav_repo,
                self.ctx_antigo.hist_repo,
                updater_service=self.updater_service,
                theme_service=self.theme_service,
                edition=EDITION_ANTIGO,
                novo_hino_repo=novo_repo,
                novo_fav_repo=novo_fav,
                novo_hist_repo=novo_hist,
            )
        return self._home_antigo

    @home_antigo.setter
    def home_antigo(self, val: HinosView | None) -> None:
        self._home_antigo = val

    @property
    def agente_view(self) -> AgenteView | None:
        if self._agente_view is None and self.agente_service is not None and self.culto_repository is not None:
            self._agente_view = AgenteView(self.agente_service, self.culto_repository)
        return self._agente_view

    @agente_view.setter
    def agente_view(self, val: AgenteView | None) -> None:
        self._agente_view = val

    @property
    def downloads_view(self) -> DownloadsView:
        if self._downloads_view is None:
            self._downloads_view = DownloadsView(
                content_manager=self.content_manager,
                media_service=self.media_service,
                theme_service=self.theme_service,
            )
        return self._downloads_view

    @downloads_view.setter
    def downloads_view(self, val: DownloadsView | None) -> None:
        self._downloads_view = val

    @property
    def biblia_view(self) -> BibliaView | None:
        if self._biblia_view is None and self.biblia_repository is not None:
            novo_repo = self.ctx_novo.hino_repo if self.ctx_novo else None
            antigo_repo = self.ctx_antigo.hino_repo if self.ctx_antigo else None
            self._biblia_view = BibliaView(
                self.biblia_repository,
                theme_service=self.theme_service,
                hino_repository=novo_repo,
                antigo_hino_repo=antigo_repo,
            )
        return self._biblia_view

    @biblia_view.setter
    def biblia_view(self, val: BibliaView | None) -> None:
        self._biblia_view = val

    @property
    def meditacao_view(self) -> MeditacaoView | None:
        if self._meditacao_view is None and self.devotional_service is not None:
            self._meditacao_view = MeditacaoView(
                devotional_service=self.devotional_service,
                theme_service=self.theme_service,
                reading_service=self.reading_service,
                auth_service=self.auth_service,
                biblia_repository=self.biblia_repository,
            )
        return self._meditacao_view

    @meditacao_view.setter
    def meditacao_view(self, val: MeditacaoView | None) -> None:
        self._meditacao_view = val

    @property
    def gerenciar_cache_view(self) -> GerenciarCacheView | None:
        if self._gerenciar_cache_view is None and self.devotional_service is not None:
            self._gerenciar_cache_view = GerenciarCacheView(
                devotional_service=self.devotional_service,
            )
        return self._gerenciar_cache_view

    @gerenciar_cache_view.setter
    def gerenciar_cache_view(self, val: GerenciarCacheView | None) -> None:
        self._gerenciar_cache_view = val

    @property
    def escola_sabatina_view(self) -> EscolaSabatinaView | None:
        if self._escola_sabatina_view is None:
            service = self.escola_sabatina_service
            if service is None and self.escola_sabatina_repo is not None:
                service = EscolaSabatinaService(self.escola_sabatina_repo)
            elif service is None and self.connections:
                repo = EscolaSabatinaRepository(self.connections[0])
                service = EscolaSabatinaService(repo)
            if service is not None:
                # Compartilhar db_path se disponível nas conexões
                db_path = None
                if self.connections:
                    try:
                        db_path = getattr(self.connections[0], "db_path", None)
                    except Exception:
                        db_path = None

                from src.config.supabase_clients import auth_client
                self._escola_sabatina_view = EscolaSabatinaView(
                    service=service,
                    biblia_repository=self.biblia_repository,
                    theme_service=self.theme_service,
                    quiz_service=QuizService(db_path=db_path, supabase_client=auth_client) if db_path else None,
                    supabase_client=auth_client,
                )
        return self._escola_sabatina_view

    @escola_sabatina_view.setter
    def escola_sabatina_view(self, val: EscolaSabatinaView | None) -> None:
        self._escola_sabatina_view = val

    @property
    def trimestres_view(self) -> TrimestresView | None:
        if self._trimestres_view is None:
            service = self.escola_sabatina_service
            if service is None and self.escola_sabatina_repo is not None:
                service = EscolaSabatinaService(self.escola_sabatina_repo)
            elif service is None and self.connections:
                repo = EscolaSabatinaRepository(self.connections[0])
                service = EscolaSabatinaService(repo)
            if service is not None:
                # Callback para que ao selecionar na tela de trimestres, notifique a EscolaSabatinaView
                async def _on_select(qid: str):
                    if self._escola_sabatina_view is not None:
                        await self._escola_sabatina_view.select_quarterly_by_id(qid)

                self._trimestres_view = TrimestresView(
                    service=service,
                    theme_service=self.theme_service,
                    on_quarterly_selected=_on_select,
                )
        return self._trimestres_view

    @trimestres_view.setter
    def trimestres_view(self, val: TrimestresView | None) -> None:
        self._trimestres_view = val

    async def refresh_views(self) -> None:
        """Limpa caches de visualizações e reconstrói a rota atual com o tema atualizado."""
        self._cached_selecao_view = None
        self.view_cache.clear()
        if self._home_novo:
            self._home_novo._cached_view = None
        if self._home_antigo:
            self._home_antigo._cached_view = None
        await self.route_change(None)

    def _check_missing_module_redirects(self, route_base: str) -> str:
        """Verifica se módulos opcionais dependentes estão instalados, redirecionando para downloads se necessário."""
        if route_base == ROUTE_ANTIGO or route_base.startswith(f"{ROUTE_ANTIGO}/"):
            if not self.content_manager.is_module_installed("hinario_antigo"):
                _show_route_warning(
                    self.page,
                    "O Hinário Tradicional (1996) precisa ser baixado na tela de módulos.",
                )
                self.page.route = ROUTE_DOWNLOADS
                return ROUTE_DOWNLOADS

        if route_base == ROUTE_BIBLIA or route_base.startswith(f"{ROUTE_BIBLIA}/"):
            if not self.content_manager.has_any_bible_installed():
                _show_route_warning(
                    self.page,
                    "Nenhuma tradução completa instalada. Baixe uma versão da Bíblia.",
                )
                self.page.route = ROUTE_DOWNLOADS
                return ROUTE_DOWNLOADS

        return route_base

    async def _render_biblia_route(
        self, route_base: str, route: str, new_views: list[ft.View]
    ) -> None:
        """Renderiza a rota da Bíblia Sagrada (/biblia ou /biblia/{book_id}/{chapter})."""
        if not (route_base == ROUTE_BIBLIA or route_base.startswith(f"{ROUTE_BIBLIA}/")):
            return

        initial_book_id = None
        initial_chapter = None
        parts = route_base.strip("/").split("/")
        if len(parts) >= 3 and parts[1].isdigit() and parts[2].isdigit():
            initial_book_id = int(parts[1])
            initial_chapter = int(parts[2])
        elif len(parts) >= 2 and parts[1].isdigit():
            initial_book_id = int(parts[1])

        livro_p, cap_p, ver_p, hino_id_p, med_refs_p = _parse_bible_route_query(route)

        # Extrai versão específica e título da barra de contexto (ex: "Escola Sabatina" ou "Meditação")
        parsed_query = urllib.parse.parse_qs(urllib.parse.urlsplit(route).query)
        versao_p = parsed_query.get("versao", parsed_query.get("version", [None]))[0]
        context_title_raw = parsed_query.get("origem", parsed_query.get("context_title", parsed_query.get("titulo", [None])))[0]
        context_title_p = urllib.parse.unquote(context_title_raw) if context_title_raw else None

        if not self.biblia_view:
            return

        self.view_cache[ROUTE_BIBLIA] = await self.biblia_view.build(
            self.page,
            initial_book_id=initial_book_id,
            initial_chapter=initial_chapter,
            initial_version=versao_p,
            livro=livro_p,
            capitulo=cap_p,
            versiculo_foco=ver_p,
            hino_origem_id=hino_id_p,
            meditacao_referencias=med_refs_p,
            context_title=context_title_p or "Meditação",
        )
        new_views.append(self.view_cache[ROUTE_BIBLIA])

    def _track_navigation(self, route: str) -> None:
        """Registra navegação na pilha de histórico preservando a rota anterior."""
        if not self.is_popping and self.current_tracked_route[0] != route:
            if (
                not self.navigation_history
                or self.navigation_history[-1] != self.current_tracked_route[0]
            ):
                self.navigation_history.append(self.current_tracked_route[0])
            self.current_tracked_route[0] = route

    async def route_change(self, e=None) -> None:
        """Manipula transições de rota construindo as visualizações empilhadas."""
        route = (e.route if (e and hasattr(e, "route") and e.route) else self.page.route) or "/"

        # Intercepta Deep Link de Callback de Autenticação OAuth (Google)
        is_auth_route = (
            "login-callback" in route
            or route.startswith("nhaapp://")
            or "access_token=" in route
            or "code=" in route
        )
        if is_auth_route:
            success = await self.auth_service.handle_auth_callback(route, self.page)
            if success:
                _show_feedback_snackbar(
                    self.page,
                    "Login com Google realizado com sucesso!",
                    bgcolor=ft.Colors.GREEN_700,
                    icon=ft.Icons.CHECK_CIRCLE,
                )
            else:
                _show_feedback_snackbar(
                    self.page,
                    "Não foi possível autenticar com o Google. Tente novamente.",
                    bgcolor=ft.Colors.RED_800,
                    icon=ft.Icons.ERROR_OUTLINE,
                )
            # Redireciona a rota para "/"
            route = "/"
            self.page.route = route

        parsed_q = _parse_route_query(route)
        (
            route_base,
            initial_search,
            initial_categoria,
            initial_tema,
            from_hino,
        ) = parsed_q
        initial_filtro = parsed_q.initial_filtro

        route_base = self._check_missing_module_redirects(route_base)
        self._track_navigation(route)

        if "?" in route:
            self.page.route = route_base

        if route_base == "/":
            is_web = getattr(self.page, "web", False)
            suffix = " (Web)" if is_web else ""
            self.page.title = f"Kairós v{APP_VERSION}{suffix}"

        if self._cached_selecao_view is None:
            self._cached_selecao_view = self.selecao_view.build(self.page)
        new_views: list[ft.View] = [self._cached_selecao_view]

        if route_base in (ROUTE_NOVO, ROUTE_ANTIGO, "/hinario"):
            effective_route_base = ROUTE_NOVO if route_base == "/hinario" else route_base
            await _render_home_route(
                self.page,
                effective_route_base,
                initial_search,
                initial_categoria,
                initial_tema,
                from_hino,
                self.view_cache,
                self.home_novo,
                self.home_antigo,
                new_views,
                initial_filtro=initial_filtro,
            )
        elif route_base == ROUTE_AGENTE:
            _render_agente_route(self.page, self.view_cache, self.agente_view, new_views)
        elif route_base == ROUTE_DOWNLOADS:
            _render_downloads_route(self.page, self.view_cache, self.downloads_view, new_views)
        elif route_base == ROUTE_BIBLIA or route_base.startswith(f"{ROUTE_BIBLIA}/"):
            await self._render_biblia_route(route_base, route, new_views)
        elif route_base == ROUTE_MEDITACOES:
            await _render_meditacao_route(self.page, route_base, self.meditacao_view, new_views)
        elif route_base == ROUTE_MEDITACOES_CACHE:
            await _render_meditacoes_cache_route(
                self.page, route_base, self.gerenciar_cache_view, new_views
            )
        elif route_base == ROUTE_ESCOLA_SABATINA:
            await _render_escola_sabatina_route(
                self.page, route_base, self.escola_sabatina_view, new_views
            )
        elif route_base == ROUTE_ESCOLA_SABATINA_TRIMESTRES:
            await _render_trimestres_route(
                self.page, route_base, self.trimestres_view, new_views
            )

        active_comp_repo = (
            self.comparativo_repository
            if self.content_manager.is_module_installed("hinario_comparativo")
            else None
        )
        await _render_hino_route(
            self.page,
            route_base,
            self.ctx_novo,
            self.ctx_antigo,
            self.media_service,
            self.biblia_repository,
            new_views,
            comparativo_repository=active_comp_repo,
            theme_service=self.theme_service,
        )

        self.page.views.clear()
        self.page.views.extend(new_views)
        self.page.update()

    async def view_pop(self, e: ft.ViewPopEvent | None = None) -> None:
        """Gerencia o desempilhamento de rotas e retorno de modais/telas."""
        try:
            if hasattr(self.page, "pop_dialog") and self.page.pop_dialog():
                return
        except Exception:
            pass

        if self.navigation_history:
            prev_route = self.navigation_history.pop()
            self.is_popping = True
            self.current_tracked_route[0] = prev_route
            try:
                await self.page.push_route(prev_route)
            finally:
                self.is_popping = False
        elif len(self.page.views) > 1:
            self.page.views.pop()
            top_view = self.page.views[-1]
            self.page.route = top_view.route
            await self.route_change(None)
        else:
            await self.page.push_route("/")

    async def on_disconnect(self, _e=None) -> None:
        """Encerra graciosamente todas as conexões SQLite ativas."""
        for conn in self.connections:
            try:
                await conn.close()
            except Exception:
                pass


async def main(page: ft.Page):
    """
    Ponto de entrada assíncrono do aplicativo Kairós em Flet.
    Inicializa conexões SQLite (Hinário Novo, Hinário Antigo, Bíblia e Comparativo),
    restaura preferências e gerencia rotas dinâmicas com suporte a ambos os hinários.
    """
    auth_service = AuthService()

    # Tratamento de Inicialização Web para OAuth Google (PKCE)
    if getattr(page, "web", False):
        code_val = None
        if hasattr(page, "query") and page.query is not None:
            try:
                code_val = page.query.get("code")
            except Exception:
                code_val = None
        if not code_val and getattr(page, "url", None):
            try:
                parsed_q = urllib.parse.parse_qs(urllib.parse.urlparse(page.url).query)
                code_val = parsed_q.get("code", [None])[0]
            except Exception:
                pass

        if code_val:
            await auth_service.handle_auth_callback(f"/?code={code_val}", page)

    ensure_page_dialogs(page)
    db_connection = DatabaseConnection(db_path="hinario.db")
    antigo_connection = DatabaseConnection(db_path="hinario_antigo.db")
    biblia_connection = DatabaseConnection(db_path="ARA.sqlite", read_only=True)
    comparativo_connection = DatabaseConnection(
        db_path="hinario_comparativo.db", read_only=True
    )

    theme_service = ThemeService(db_connection)
    # 1. Carrega preferências completas (client_storage + SQLite) ANTES de aplicar o tema
    await theme_service.load_preferences(page)
    _setup_assets_and_theme(page, theme_service)

    # Repositórios Hinário Novo
    hino_repository = HinoRepository(
        db_connection=db_connection, db_antigo_connection=antigo_connection
    )
    favorito_repository = FavoritoRepository(db_connection)
    historico_repository = HistoricoRepository(db_connection)
    culto_repository = CultoRepository(db_connection)

    # Repositórios Hinário Antigo
    antigo_hino_repo = HinoRepository(antigo_connection)
    antigo_fav_repo = FavoritoRepository(antigo_connection)
    antigo_hist_repo = HistoricoRepository(antigo_connection)

    # Contextos estruturados por Edição
    ctx_novo = EditionContext(
        hino_repo=hino_repository,
        fav_repo=favorito_repository,
        hist_repo=historico_repository,
    )
    ctx_antigo = EditionContext(
        hino_repo=antigo_hino_repo,
        fav_repo=antigo_fav_repo,
        hist_repo=antigo_hist_repo,
    )

    # Bíblia & Comparativo
    biblia_repository = BibliaRepository(biblia_connection)
    comparativo_repository = ComparativoRepository(comparativo_connection)

    media_service = MediaService(download_dir="downloads")
    content_manager = ContentManager()
    agente_service = AgenteService(
        hino_repository=hino_repository,
        biblia_repository=biblia_repository,
        content_manager=content_manager,
    )
    updater_service = UpdaterService()
    devotional_repository = DevotionalRepository(db_connection)
    devotional_service = DevotionalService(devotional_repository)
    reading_service = ReadingService(db_connection)
    escola_sabatina_repo = EscolaSabatinaRepository(db_connection)
    escola_sabatina_service = EscolaSabatinaService(repository=escola_sabatina_repo)

    selecao_view_instance = SelecaoView(
        theme_service=theme_service,
        updater_service=updater_service,
        content_manager=content_manager,
        auth_service=auth_service,
        devotional_service=devotional_service,
        reading_service=reading_service,
    )

    # Serviço de Sincronização em Nuvem (Supabase)
    cloud_sync_service = CloudSyncService(
        auth_service=auth_service,
        fav_repo_novo=favorito_repository,
        fav_repo_antigo=antigo_fav_repo,
        hist_repo_novo=historico_repository,
        hist_repo_antigo=antigo_hist_repo,
    )
    favorito_repository.on_change_sync_callback = cloud_sync_service.push_favorite
    antigo_fav_repo.on_change_sync_callback = cloud_sync_service.push_favorite
    historico_repository.on_access_sync_callback = cloud_sync_service.push_history
    antigo_hist_repo.on_access_sync_callback = cloud_sync_service.push_history

    def _on_user_authenticated(user):
        if user:
            task = asyncio.create_task(cloud_sync_service.sync_on_login(user))
            _background_tasks.add(task)
            task.add_done_callback(_background_tasks.discard)

    auth_service.add_listener(_on_user_authenticated)

    router = AppRouter(
        page=page,
        connections=(
            db_connection,
            antigo_connection,
            biblia_connection,
            comparativo_connection,
        ),
        views=AppViews(selecao_view=selecao_view_instance),
        content_manager=content_manager,
        media_service=media_service,
        theme_service=theme_service,
        ctx_novo=ctx_novo,
        ctx_antigo=ctx_antigo,
        biblia_repository=biblia_repository,
        comparativo_repository=comparativo_repository,
        auth_service=auth_service,
        updater_service=updater_service,
        devotional_service=devotional_service,
        reading_service=reading_service,
        culto_repository=culto_repository,
        agente_service=agente_service,
        escola_sabatina_service=escola_sabatina_service,
        escola_sabatina_repo=escola_sabatina_repo,
    )

    # Restaura sessão prévia de autenticação caso persistida e dispara sincronização
    async def _restore_and_sync():
        success = await auth_service.restore_session(page)
        if success:
            u = auth_service.get_current_user()
            if u:
                await cloud_sync_service.sync_on_login(u)

    restore_task = asyncio.create_task(_restore_and_sync())
    _background_tasks.add(restore_task)
    restore_task.add_done_callback(_background_tasks.discard)

    page.on_route_change = router.route_change
    page.on_view_pop = router.view_pop
    page.on_disconnect = router.on_disconnect

    theme_service.add_listener(router.refresh_views)

    async def _on_platform_brightness_change(e: ft.PlatformBrightnessChangeEvent):
        if theme_service.theme_mode == "system":
            theme_service.theme_engine._resolve_is_dark(page)
            theme_service.apply_theme(page)
            await router.refresh_views()

    page.on_platform_brightness_change = _on_platform_brightness_change

    if not page.route or page.route == "/loading":
        page.route = "/"

    # 3. Transiciona para a rota inicial (Seleção de Hinários)
    await router.route_change(None)

    # 4. Dispara a verificação assíncrona de atualizações em segundo plano
    update_task = asyncio.create_task(_check_updates_background(page, updater_service))
    _background_tasks.add(update_task)
    update_task.add_done_callback(_background_tasks.discard)

    # 5. Exibe diálogo de boas-vindas se for a primeira vez do usuário sem dados
    async def _check_welcome():
        await asyncio.sleep(0.6)
        if not await is_onboarding_completed(page):
            show_welcome_dialog(page, theme_service, auth_service)

    welcome_task = asyncio.create_task(_check_welcome())
    _background_tasks.add(welcome_task)
    welcome_task.add_done_callback(_background_tasks.discard)


if __name__ == "__main__":
    ft.run(main, assets_dir="assets")
