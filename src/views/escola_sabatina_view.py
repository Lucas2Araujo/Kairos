"""
View Principal da Escola Sabatina - Kairós.
Recursos:
1. Leitor completo com ft.Markdown com auto_follow_links=False.
2. Interceptação de links bíblicos (bible://... ou citações) com exibição do VerseDialog
   e consulta ao banco SQLite local da Bíblia (BibliaRepository).
3. Download e cache local de tirinhas e imagens (substituição de URLs por arquivos locais).
4. Sistema de anotações pessoais por dia com auto-save debounce de 500ms no on_change e SQLite.
5. Personalização avançada idêntica à MeditacaoView:
   - Tamanho de fonte (A-, A+, padrão)
   - Famílias de fonte (AppSans, HymnSerif, Montserrat, OpenDyslexic, Helvetica)
   - Seletor de versão da Bíblia (ARA, NVI, KJA, NTLH, AS21)
6. Seletor de Lição (Adultos vs Jovens) com persistência em storage.
"""

from __future__ import annotations

import asyncio
import inspect
import logging
import re
import urllib.parse
from datetime import date
from typing import Any

import flet as ft

logger = logging.getLogger(__name__)

from src.components.verse_dialog import parse_verse_reference, show_verse_dialog
from src.models.escola_sabatina import SSDay, SSLesson, SSQuarterly
from src.repositories.biblia_repository import BibliaRepository
from src.services.escola_sabatina_service import EscolaSabatinaService
from src.services.quiz_service import QuizService
from src.services.theme_service import ThemeService
from src.theme.palette import create_empty_state_container
from src.utils.storage_manager import storage_get, storage_set
from src.views.components.mind_map_studio import MindMapStudio
from src.views.quiz_view import QuizView

# ---------------------------------------------------------------------------
# Configurações de fonte e chaves de storage
# ---------------------------------------------------------------------------
FONT_STEP = 2
MIN_FONT_SIZE = 14
MAX_FONT_SIZE = 28
DEFAULT_CONTENT_FONT_SIZE = 16

STORAGE_KEY_SS_FONT_SIZE = "ss_font_size"
STORAGE_KEY_SS_FONT_FAMILY = "ss_font_family"
STORAGE_KEY_BIBLE_VERSION = "preferred_bible_version"
STORAGE_KEY_SS_TYPE = "preferred_ss_type"
STORAGE_KEY_SS_CATEGORY = "preferred_ss_category"
STORAGE_KEY_SELECTED_QUARTERLY_ID = "escola_sabatina_selected_quarterly_id"

FONT_FAMILIES: dict[str, str | None] = {
    "Helvetica (Padrão)": "Helvetica",
    "Montserrat (Moderna)": "Montserrat",
    "AppSans (Sem Serifa)": "AppSans",
    "HymnSerif (Serifada)": "HymnSerif",
    "OpenDyslexic (Acessível)": "OpenDyslexic",
}
DEFAULT_FONT_FAMILY_KEY = "Helvetica (Padrão)"

BIBLE_REF_LINK_PATTERN = re.compile(
    r"^(?:bible://)?([1-3]?\s*[A-Za-zÀ-ÿ]+)\.?\s*(\d+)(?:\s*[:\.]\s*(\d+))?",
    re.IGNORECASE,
)



def _parse_ss_date(d_str: str) -> date | None:
    """Converte strings de data da API Adventech (DD/MM/YYYY ou YYYY-MM-DD) para date."""
    if not d_str:
        return None
    d_str = d_str.strip()
    for sep in ("/", "-"):
        if sep in d_str:
            parts = d_str.split(sep)
            if len(parts) == 3:
                try:
                    if len(parts[0]) == 4:
                        return date(int(parts[0]), int(parts[1]), int(parts[2]))
                    elif len(parts[2]) == 4:
                        return date(int(parts[2]), int(parts[1]), int(parts[0]))
                except Exception:
                    pass
    return None


class EscolaSabatinaView:
    """Controlador e interface da Escola Sabatina no Kairós."""

    def __init__(
        self,
        service: EscolaSabatinaService,
        biblia_repository: BibliaRepository | None = None,
        theme_service: ThemeService | None = None,
        category: str = "adultos",
        quiz_service: QuizService | None = None,
        supabase_client: Any = None,
    ):
        self.service = service
        self.biblia_repository = biblia_repository or BibliaRepository()
        self.theme_service = theme_service
        self.category = category if category in ("adultos", "jovens") else "adultos"
        self.supabase_client = supabase_client
        
        self.font_size: int = DEFAULT_CONTENT_FONT_SIZE
        self.font_family_key: str = DEFAULT_FONT_FAMILY_KEY
        self.bible_version: str = "ARA"
        self.page: ft.Page | None = None

        # Dados em exibição
        self.quarterlies: list[SSQuarterly] = []
        self.current_quarterly: SSQuarterly | None = None
        self.selected_quarterly_id: str | None = None
        self.lessons: list[SSLesson] = []
        self.current_lesson: SSLesson | None = None
        self.days: list[SSDay] = []
        self.current_day: SSDay | None = None

        self.is_loading: bool = False
        self._note_debounce_task: asyncio.Task | None = None

        # Gamificação e Quizzes
        self.quiz_service = quiz_service or QuizService(supabase_client=supabase_client)
        self.user_streak: int = 0
        self.streak_chip: ft.Container | None = None

        # Controles reativos
        self.content_container: ft.Column | None = None
        self.category_segmented: ft.SegmentedButton | None = None
        self.days_row: ft.Row | None = None
        self.note_field: ft.TextField | None = None
        self.note_status_text: ft.Text | None = None
        self.lesson_dropdown: ft.Dropdown | None = None
        self.lesson_card: ft.Container | None = None
        self.download_progress_bar: ft.ProgressBar | None = None
        self._snackbar: ft.SnackBar | None = None

        # Perguntas Interativas e Mapa Mental (Rede Semântica)
        self.question_answers: dict[str, str] = {}
        self.current_mind_map: dict[str, Any] | None = None
        self._q_debounce_tasks: dict[str, asyncio.Task] = {}

    @property
    def _current_font_family(self) -> str | None:
        return FONT_FAMILIES.get(self.font_family_key)

    def _show_snackbar(self, msg: str) -> None:
        if not self.page:
            return
        if self._snackbar is None:
            self._snackbar = ft.SnackBar(content=ft.Text(msg))
            self.page.overlay.append(self._snackbar)
        else:
            self._snackbar.content = ft.Text(msg)
        self._snackbar.open = True
        self.page.update()

    # -----------------------------------------------------------------------
    # Preferências (Fontes, Bíblia e Tipo de Lição)
    # -----------------------------------------------------------------------

    async def _load_preferences(self) -> None:
        if not self.page:
            return

        try:
            val_font = await storage_get(self.page, STORAGE_KEY_SS_FONT_SIZE)
            if val_font is not None:
                self.font_size = max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, int(val_font)))
        except Exception:
            self.font_size = DEFAULT_CONTENT_FONT_SIZE

        try:
            val_family = await storage_get(self.page, STORAGE_KEY_SS_FONT_FAMILY)
            if val_family and str(val_family) in FONT_FAMILIES:
                self.font_family_key = str(val_family)
        except Exception:
            pass

        try:
            val_bible = await storage_get(self.page, STORAGE_KEY_BIBLE_VERSION)
            if val_bible:
                self.bible_version = str(val_bible).upper()
        except Exception:
            self.bible_version = "ARA"

        try:
            val_cat = await storage_get(self.page, STORAGE_KEY_SS_CATEGORY)
            if not val_cat:
                val_cat = await storage_get(self.page, STORAGE_KEY_SS_TYPE)
            if val_cat in ("adultos", "jovens"):
                self.category = val_cat
        except Exception:
            pass

        try:
            val_qid = await storage_get(self.page, STORAGE_KEY_SELECTED_QUARTERLY_ID)
            self.selected_quarterly_id = str(val_qid) if val_qid else None
        except Exception:
            self.selected_quarterly_id = None

    async def _save_preferences(self) -> None:
        if not self.page:
            return
        try:
            await storage_set(self.page, STORAGE_KEY_SS_FONT_SIZE, self.font_size)
            await storage_set(self.page, STORAGE_KEY_SS_FONT_FAMILY, self.font_family_key)
            await storage_set(self.page, STORAGE_KEY_BIBLE_VERSION, self.bible_version)
            await storage_set(self.page, STORAGE_KEY_SS_CATEGORY, self.category)
            await storage_set(self.page, STORAGE_KEY_SS_TYPE, self.category)
            if self.current_quarterly:
                await storage_set(self.page, STORAGE_KEY_SELECTED_QUARTERLY_ID, self.current_quarterly.id)
        except Exception:
            pass

    # -----------------------------------------------------------------------
    # Controles de Fonte e Bíblia
    # -----------------------------------------------------------------------

    def _change_font_size(self, delta: int) -> None:
        """Aumenta ou diminui dinamicamente o tamanho da fonte."""
        new_size = self.font_size + delta
        if MIN_FONT_SIZE <= new_size <= MAX_FONT_SIZE:
            self.font_size = new_size
            if self.page:
                self.page.run_task(self._save_preferences)
            self._update_rendered_content()

    def _reset_font_size(self) -> None:
        """Restaura o tamanho padrão da fonte."""
        self.font_size = DEFAULT_CONTENT_FONT_SIZE
        if self.page:
            self.page.run_task(self._save_preferences)
        self._update_rendered_content()

    def _set_font_family(self, key: str) -> None:
        """Aplica a família de fonte selecionada e persiste."""
        matched_key = None
        if key in FONT_FAMILIES:
            matched_key = key
        else:
            for k, val in FONT_FAMILIES.items():
                if val == key:
                    matched_key = k
                    break

        if matched_key:
            self.font_family_key = matched_key
            if self.page:
                self.page.run_task(self._save_preferences)
            self._update_rendered_content()


    def _set_bible_version(self, version: str) -> None:
        """Aplica a versão da Bíblia selecionada e persiste."""
        if version:
            self.bible_version = str(version).upper()
            if self.page:
                self.page.run_task(self._save_preferences)
            self._update_rendered_content()

    # -----------------------------------------------------------------------
    # Bottom Sheet de Acessibilidade e Personalização
    # -----------------------------------------------------------------------

    def _show_accessibility_bottom_sheet(self) -> None:
        if not self.page:
            return

        font_size_text = ft.Text(
            f"{self.font_size} pt",
            size=15,
            weight=ft.FontWeight.BOLD,
            width=50,
            text_align=ft.TextAlign.CENTER,
        )

        def _update_font_size(new_size: int):
            self.font_size = max(MIN_FONT_SIZE, min(MAX_FONT_SIZE, new_size))
            font_size_text.value = f"{self.font_size} pt"
            if self.page:
                self.page.run_task(self._save_preferences)
            self._update_rendered_content()
            try:
                bs.update()
            except Exception:
                pass

        def _decrease(e):
            _update_font_size(self.font_size - FONT_STEP)

        def _increase(e):
            _update_font_size(self.font_size + FONT_STEP)

        def _reset(e):
            _update_font_size(DEFAULT_CONTENT_FONT_SIZE)

        def _on_font_change(e):
            if e.control.value and e.control.value in FONT_FAMILIES:
                self._set_font_family(e.control.value)
                try:
                    bs.update()
                except Exception:
                    pass

        def _on_bible_change(e):
            if e.control.value:
                self._set_bible_version(e.control.value)
                try:
                    bs.update()
                except Exception:
                    pass

        font_radio_group = ft.RadioGroup(
            content=ft.Column(
                controls=[
                    ft.Radio(value=key, label=key)
                    for key in FONT_FAMILIES
                ],
                spacing=4,
            ),
            value=self.font_family_key,
            on_change=_on_font_change,
        )

        versions = BibliaRepository.get_available_versions_with_names() if BibliaRepository else []
        if not versions:
            versions = [("ARA", "Almeida Revista e Atualizada")]

        bible_dropdown = ft.Dropdown(
            options=[
                ft.dropdown.Option(key=code, text=f"{code} - {name}")
                for code, name in versions
            ],
            value=self.bible_version,
            text_size=13,
            dense=True,
            on_select=_on_bible_change,
        )

        def _on_reading_mode_change(mode: str):
            if self.theme_service and self.page:
                asyncio.create_task(self.theme_service.set_reading_mode(mode, self.page))
                self._update_rendered_content()

        current_reading_mode = (
            self.theme_service.get_current_reading_mode()
            if self.theme_service
            else "claro"
        )
        reading_mode_selector = ft.SegmentedButton(
            segments=[
                ft.Segment(value="claro", label=ft.Text("Claro", size=12), icon=ft.Icons.LIGHT_MODE_OUTLINED),
                ft.Segment(value="escuro", label=ft.Text("Escuro", size=12), icon=ft.Icons.DARK_MODE_OUTLINED),
                ft.Segment(value="sepia", label=ft.Text("Sépia", size=12), icon=ft.Icons.AUTO_STORIES_OUTLINED),
            ],
            selected=[current_reading_mode],
            allow_multiple_selection=False,
            on_change=lambda ev: _on_reading_mode_change(next(iter(ev.control.selected))),
        )

        bs = ft.BottomSheet(
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.ACCESSIBILITY_NEW_ROUNDED, color=ft.Colors.PRIMARY),
                                ft.Text(
                                    "Acessibilidade e Texto",
                                    weight=ft.FontWeight.BOLD,
                                    size=18,
                                    expand=True,
                                ),
                                ft.IconButton(
                                    ft.Icons.CLOSE,
                                    tooltip="Fechar",
                                    on_click=lambda ev: self.page.pop_dialog(),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1),
                        ft.Text(
                            "Modo de Leitura",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        reading_mode_selector,
                        ft.Divider(height=1),
                        ft.Text(
                            "Tamanho da Letra",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        ft.Row(
                            controls=[
                                ft.IconButton(
                                    ft.Icons.TEXT_DECREASE,
                                    icon_size=22,
                                    tooltip="Diminuir (A-)",
                                    on_click=_decrease,
                                ),
                                font_size_text,
                                ft.IconButton(
                                    ft.Icons.TEXT_INCREASE,
                                    icon_size=22,
                                    tooltip="Aumentar (A+)",
                                    on_click=_increase,
                                ),
                                ft.Container(expand=True),
                                ft.TextButton(
                                    "Restaurar padrão",
                                    icon=ft.Icons.REFRESH,
                                    on_click=_reset,
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=4,
                        ),
                        ft.Divider(height=1),
                        ft.Text(
                            "Família de Fonte",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        font_radio_group,
                        ft.Divider(height=1),
                        ft.Text(
                            "Versão da Bíblia (Passagens e Versículos)",
                            weight=ft.FontWeight.W_600,
                            size=14,
                            color=ft.Colors.ON_SURFACE_VARIANT,
                        ),
                        bible_dropdown,
                    ],
                    spacing=10,
                    tight=True,
                    scroll=ft.ScrollMode.AUTO,
                ),
                padding=ft.Padding.only(left=20, top=16, right=20, bottom=40),
            ),
        )

        try:
            self.page.show_dialog(bs)
        except Exception:
            self.page.overlay.append(bs)
            bs.open = True
            self.page.update()

    # -----------------------------------------------------------------------
    # Interceptação de Versículos com VerseDialog e SQLite
    # -----------------------------------------------------------------------

    def _get_current_day_markdown(self) -> str:
        """Retorna o conteúdo do dia atual normalizado em Markdown com links bible://."""
        if not self.current_day or not self.current_day.content:
            return ""
        raw_text = self.current_day.content or ""
        md = EscolaSabatinaService.html_to_markdown(raw_text)
        return EscolaSabatinaService.normalize_bible_links(md)

    def _get_all_day_bible_refs(self) -> list[str]:
        """
        Extrai todas as referências bíblicas presentes no conteúdo do dia atual,
        em ordem de aparição no texto, sem duplicatas, para alimentar a barra de contexto da Bíblia.
        """
        content = self._get_current_day_markdown()
        if not content:
            return []

        refs: list[str] = []
        seen = set()

        for m in re.finditer(r'\[([^\]]+)\]\(bible://([^)]+)\)', content):
            lbl = m.group(1).strip()
            raw_t = urllib.parse.unquote(m.group(2)).strip()

            candidates: list[str] = []
            if ";" in raw_t:
                candidates.extend([p.strip() for p in raw_t.split(";") if p.strip()])
            elif ";" in lbl:
                candidates.extend([p.strip() for p in lbl.split(";") if p.strip()])
            else:
                candidates.append(raw_t if raw_t else lbl)

            for cand in candidates:
                cand_clean = cand.strip().strip("()[]{}.,")
                if not cand_clean:
                    continue
                norm = cand_clean.lower()
                if norm not in seen:
                    seen.add(norm)
                    refs.append(cand_clean)

        return refs

    def _find_bible_reference_group(self, clicked_url_or_ref: str) -> list[str]:
        """
        Identifica se a referência clicada pertence a um conjunto de textos correlatos
        consecutivos (ex: separados por ponto-e-vírgula como Mt 28:1-20; Mc 16:1-20; Jo 20:1-31).
        Retorna a lista completa dos textos do grupo ou [clicked_url_or_ref] caso seja isolado.
        """
        clean = urllib.parse.unquote(clicked_url_or_ref).strip()
        if clean.startswith("bible://"):
            clean = clean[8:].strip()

        def _propagate_books(ref_items: list[str]) -> list[str]:
            res: list[str] = []
            last_b = ""
            for it in ref_items:
                it_clean = it.strip()
                m_b = re.match(r"^([1-3]?\s*[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)?)\s+\d+", it_clean)
                if m_b:
                    last_b = m_b.group(1).strip()
                    res.append(it_clean)
                elif re.match(r"^\d+", it_clean) and last_b:
                    res.append(f"{last_b} {it_clean}")
                else:
                    res.append(it_clean)
            return res

        # Caso 1: o próprio link já contém múltiplos textos separados por ';'
        if ";" in clean:
            parts = [p.strip() for p in clean.split(";") if p.strip()]
            if len(parts) > 1:
                return _propagate_books(parts)

        content = self._get_current_day_markdown()
        if not content:
            return [clean]

        # Caso 2: Procura blocos contíguos de links bíblicos separados por ';' ou ','
        link_pattern = re.compile(r'\[([^\]]+)\]\(bible://([^)]+)\)')
        matches = list(link_pattern.finditer(content))
        if not matches:
            return [clean]

        groups: list[list[re.Match]] = []
        current_group: list[re.Match] = [matches[0]]
        for i in range(1, len(matches)):
            prev = current_group[-1]
            curr = matches[i]
            between = content[prev.end():curr.start()]
            if re.fullmatch(r'[\s;,\(\)\.\/]*', between) and (';' in between or ',' in between):
                current_group.append(curr)
            else:
                groups.append(current_group)
                current_group = [curr]
        groups.append(current_group)

        # Identifica se 'clean' pertence a algum grupo com mais de 1 link
        norm_clean = clean.lower().replace(" ", "")
        for grp in groups:
            if len(grp) < 2:
                continue
            grp_refs: list[str] = []
            matched = False
            for m in grp:
                lbl = m.group(1).strip()
                raw_t = urllib.parse.unquote(m.group(2)).strip()
                target_str = raw_t if raw_t else lbl
                sub_refs = [
                    s.strip()
                    for s in target_str.split(";")
                    if s.strip()
                ]
                for s in sub_refs:
                    grp_refs.append(s)
                    norm_s = s.lower().replace(" ", "")
                    if norm_clean == norm_s or norm_clean in norm_s or norm_s in norm_clean:
                        matched = True

            if matched:
                return _propagate_books(grp_refs)

        return [clean]

    def _extract_bible_reference(self, link_url: str) -> tuple[str, int, int] | None:
        """
        Extrai livro, capítulo e versículo a partir do link clicado no Markdown:
        Suporta esquemas como 'bible://Jo3:16', 'bible://1Pe1:20', 'bible://Lucas%2024',
        'bible://1Cor13:4', 'bible://Mat.5.3' ou referências convencionais.
        Retorna (livro, capitulo, versiculo), onde versiculo=0 indica leitura do capítulo completo.
        """
        if not link_url:
            return None

        clean = link_url.strip()
        clean = urllib.parse.unquote(clean)
        clean = clean.replace("+", " ")

        match = BIBLE_REF_LINK_PATTERN.search(clean)
        if match:
            livro = match.group(1).strip()
            capitulo = int(match.group(2))
            versiculo = int(match.group(3)) if match.group(3) else 0
            return livro, capitulo, versiculo

        # Fallback usando parse_verse_reference
        if clean.startswith("bible://"):
            ref_part = clean[8:].strip()
            parsed = parse_verse_reference(ref_part)
            if parsed and parsed.livro:
                has_ver = (":" in ref_part or "." in ref_part)
                return parsed.livro, parsed.capitulo, (parsed.versiculo if has_ver else 0)

        return None

    def _on_tap_link(self, e: Any) -> None:
        """
        Manipulador de toque em links no componente ft.Markdown.
        Intercepta referências bíblicas (bible://...) e abre o VerseDialog flutuante.
        """
        url = getattr(e, "data", "") or ""
        if not url and isinstance(e, str):
            url = e
        if not url:
            return

        logger.info("Escola Sabatina - Link clicado: %s", url)
        if url.startswith("bible://") or self._extract_bible_reference(url):
            refs = self._find_bible_reference_group(url)
            if self.page:
                if hasattr(self.page, "run_task"):
                    self.page.run_task(self._show_floating_verse_dialog, refs)
                else:
                    asyncio.create_task(self._show_floating_verse_dialog(refs))
        else:
            # Link web comum (http:// ou https://)
            if url.startswith("http://") or url.startswith("https://"):
                try:
                    if self.page:
                        self.page.launch_url(url)
                except Exception:
                    pass

    async def _show_floating_verse_dialog(
        self,
        target_refs: list[str] | str,
        capitulo: int | None = None,
        versiculo: int | None = None,
    ) -> None:
        """Consulta o texto bíblico no SQLite local e exibe o VerseDialog contextual."""
        if not self.page:
            return

        # Compatibilidade com chamadas legadas com 3 argumentos: (livro, capitulo, versiculo)
        if isinstance(target_refs, str) and capitulo is not None:
            v_str = f":{versiculo}" if versiculo and versiculo > 0 else ""
            refs_list = [f"{target_refs} {capitulo}{v_str}"]
        elif isinstance(target_refs, str):
            refs_list = self._find_bible_reference_group(target_refs)
        else:
            refs_list = list(target_refs)

        if not refs_list:
            return

        # Normaliza referências consecutivas que omitem o livro (ex: ['Ap 7:4-8', '14:1'])
        normalized_refs: list[str] = []
        last_book_name = ""
        for r in refs_list:
            r_clean = r.strip()
            if r_clean.startswith("bible://"):
                r_clean = urllib.parse.unquote(r_clean[8:]).strip()
            m_book = re.match(r"^([1-3]?\s*[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)?)\s+\d+", r_clean)
            if m_book:
                last_book_name = m_book.group(1).strip()
                normalized_refs.append(r_clean)
            elif re.match(r"^\d+", r_clean) and last_book_name:
                normalized_refs.append(f"{last_book_name} {r_clean}")
            else:
                normalized_refs.append(r_clean)
        refs_list = normalized_refs

        passages: list[dict[str, Any]] = []
        for ref_str in refs_list:
            clean_ref = ref_str.strip()
            disp_ref = clean_ref
            verse_text = "Texto bíblico não disponível para esta versão."
            livro = ""
            cap = 1
            ver = 1

            try:
                passagem = await self.biblia_repository.buscar_passagem(
                    clean_ref, versao=self.bible_version
                )
                if passagem and passagem.versiculos:
                    disp_ref = passagem.referencia or clean_ref
                    verse_text = passagem.texto_formatado or passagem.versiculos[0].texto
                    livro = passagem.livro
                    cap = passagem.capitulo
                    ver = passagem.versiculos[0].numero if passagem.versiculos else 1
                else:
                    parsed = parse_verse_reference(clean_ref)
                    livro = parsed.livro
                    cap = parsed.capitulo
                    ver = parsed.versiculo
            except Exception:
                logger.exception("Erro ao buscar passagem bíblica: %s (%s)", clean_ref, self.bible_version)
                parsed = parse_verse_reference(clean_ref)
                livro = parsed.livro
                cap = parsed.capitulo
                ver = parsed.versiculo

            passages.append({
                "ref_label": clean_ref,
                "canonical_ref": disp_ref,
                "text": verse_text,
                "livro": livro,
                "capitulo": cap,
                "versiculo": ver,
            })

        async def _fetch_passage_text_for_dialog(ref_query: str, ver_key: str) -> str:
            try:
                p = await self.biblia_repository.buscar_passagem(ref_query, versao=ver_key)
                if p and p.versiculos:
                    return p.texto_formatado or p.versiculos[0].texto
            except Exception:
                pass
            return "Texto bíblico não disponível para esta versão."

        def _on_ler_completo(l: str, c: int, v: int):
            target_v = v if v > 0 else 1
            all_day_refs = self._get_all_day_bible_refs()
            refs_param = urllib.parse.quote("|".join(all_day_refs)) if all_day_refs else ""
            origem_param = urllib.parse.quote("Escola Sabatina")
            route = (
                f"/biblia?livro={urllib.parse.quote(l)}&cap={c}&ver={target_v}"
                f"&versao={self.bible_version}&refs={refs_param}&origem={origem_param}"
            )
            go_fn = getattr(self.page, "go", None)
            if callable(go_fn):
                go_fn(route)
            elif hasattr(self.page, "push_route"):
                asyncio.create_task(self.page.push_route(route))

        available_versions = self.biblia_repository.get_available_versions()

        show_verse_dialog(
            page=self.page,
            passages=passages,
            available_versions=available_versions,
            current_version=self.bible_version,
            on_version_change=self._set_bible_version,
            fetch_passage_text=_fetch_passage_text_for_dialog,
            on_read_full_chapter=_on_ler_completo,
        )


    # -----------------------------------------------------------------------
    # Sistema de Anotações Pessoais com Debounce de 500ms
    # -----------------------------------------------------------------------

    def _on_note_change(self, e: Any) -> None:
        """Trata digitação no campo de anotações com debounce de 500ms."""
        text = e.control.value if e and hasattr(e, "control") else ""
        if self._note_debounce_task and not self._note_debounce_task.done():
            self._note_debounce_task.cancel()

        self._set_note_status("Salvando...", ft.Colors.ON_SURFACE_VARIANT)
        self._note_debounce_task = asyncio.create_task(self._debounce_save_note(text))

    async def _debounce_save_note(self, text: str) -> None:
        """Aguarda 500ms sem nova digitação antes de persistir no SQLite."""
        try:
            await asyncio.sleep(0.5)
            await self._save_current_note(text)
        except asyncio.CancelledError:
            pass

    async def _save_current_note(self, text: str) -> None:
        """Persiste a anotação no banco SQLite e exibe confirmação visual sutil."""
        if not self.current_day:
            return
        try:
            await self.service.save_note(self.current_day.id, text)
            self._set_note_status("Salvo ✓", ft.Colors.PRIMARY)
        except Exception:
            self._set_note_status("Erro ao salvar", ft.Colors.ERROR)

    def _set_note_status(self, text: str, color: str) -> None:
        if self.note_status_text:
            self.note_status_text.value = text
            self.note_status_text.color = color
            try:
                self.note_status_text.update()
            except Exception:
                pass

    # -----------------------------------------------------------------------
    # Carregamento de Dados (Offline-First e Sincronização com Data Atual)
    # -----------------------------------------------------------------------

    def _find_current_quarterly(self, quarterlies: list[SSQuarterly]) -> SSQuarterly | None:
        """Determina o trimestre ativo correspondente à data de hoje."""
        if not quarterlies:
            return None
        today = date.today()
        for q in quarterlies:
            s = _parse_ss_date(q.start_date)
            e = _parse_ss_date(q.end_date)
            if s and e and s <= today <= e:
                return q
        for q in quarterlies:
            s = _parse_ss_date(q.start_date)
            if s and s <= today:
                return q
        return quarterlies[0]

    def _find_current_lesson(self, lessons: list[SSLesson]) -> SSLesson | None:
        """Determina a lição da semana atual com base na data de hoje."""
        if not lessons:
            return None
        today = date.today()
        for l in lessons:
            s = _parse_ss_date(l.start_date)
            e = _parse_ss_date(l.end_date)
            if s and e and s <= today <= e:
                return l
        # Se não houver intervalo exato, escolhe a lição mais recente anterior a hoje
        matching_past = [
            l for l in lessons
            if _parse_ss_date(l.start_date) and _parse_ss_date(l.start_date) <= today
        ]
        if matching_past:
            return matching_past[-1]
        return lessons[0]

    def _find_current_day(self, days: list[SSDay]) -> SSDay:
        """Determina o dia de estudo correspondente a hoje (ou o mais próximo da data atual)."""
        if not days:
            return None
        today = date.today()
        # 1. Correspondência exata da data de hoje
        for d in days:
            d_date = _parse_ss_date(d.date)
            if d_date and d_date == today:
                return d

        # 2. Se hoje não coincidir exatamente, escolhe o dia cronologicamente mais próximo de hoje
        day_diffs = []
        for d in days:
            d_date = _parse_ss_date(d.date)
            if d_date:
                day_diffs.append((abs((d_date - today).days), d))
        if day_diffs:
            day_diffs.sort(key=lambda x: x[0])
            return day_diffs[0][1]

        return days[0]

    async def _load_initial_data(self) -> None:
        """Carrega trimestres e lições iniciais, selecionando a lição da semana atual."""
        self.is_loading = True
        self._update_rendered_content()

        await self._load_preferences()

        try:
            # 1. Busca trimestres da categoria selecionada (Adultos ou Jovens)
            self.quarterlies = await self.service.get_quarterlies(
                lang="pt", category=self.category, force_refresh=False
            )
            if self.quarterlies:
                # Prioriza trimestre explicitamente selecionado pelo usuário se existir
                matched_q = None
                if self.selected_quarterly_id:
                    for q in self.quarterlies:
                        if q.id == self.selected_quarterly_id:
                            matched_q = q
                            break
                self.current_quarterly = matched_q or self._find_current_quarterly(self.quarterlies)
                self.lessons = await self.service.get_lessons(
                    self.current_quarterly.id, lang="pt", force_refresh=False
                )
                if self.lessons:
                    # Se foi uma seleção manual de trimestre ou um trimestre fora do período de hoje,
                    # inicia na 1ª lição (Lição 1)
                    is_custom_selection = getattr(self, "_start_at_first_lesson", False)
                    if is_custom_selection:
                        self.current_lesson = self.lessons[0]
                        self._start_at_first_lesson = False
                    else:
                        # Verifica se hoje está dentro do trimestre
                        today = date.today()
                        has_current_week = any(
                            _parse_ss_date(l.start_date) and _parse_ss_date(l.end_date) and
                            _parse_ss_date(l.start_date) <= today <= _parse_ss_date(l.end_date)
                            for l in self.lessons
                        )
                        if has_current_week:
                            self.current_lesson = self._find_current_lesson(self.lessons)
                        else:
                            # Trimestre passado ou futuro: inicia na Lição 1
                            self.current_lesson = self.lessons[0]

                    self.days = await self.service.get_lesson_days(
                        self.current_lesson.id,
                        quarterly_id=self.current_quarterly.id,
                        lang="pt",
                        force_refresh=False,
                    )
                    if self.days:
                        target_day = self._find_current_day(self.days)
                        await self._select_day(target_day)
        except Exception:
            logger.exception("Erro ao carregar dados da Escola Sabatina.")
        finally:
            self.is_loading = False
            self._update_rendered_content()

        # Carregar estatísticas de gamificação/ofensiva em background
        try:
            stats = await self.quiz_service.get_user_stats()
            self.user_streak = stats.current_streak
            if self.streak_chip and self.streak_chip.content:
                self.streak_chip.content.controls[1].value = f"🔥 {self.user_streak} dias"
                if self.page:
                    self.streak_chip.update()
        except Exception:
            pass

    async def select_quarterly_by_id(self, quarterly_id: str, start_at_first_lesson: bool = True) -> None:
        """Seleciona programaticamente um trimestre pelo seu ID e recarrega os estudos iniciando na 1ª lição."""
        self.selected_quarterly_id = quarterly_id
        self._start_at_first_lesson = start_at_first_lesson
        if self.page:
            await storage_set(self.page, STORAGE_KEY_SELECTED_QUARTERLY_ID, quarterly_id)
        await self._load_initial_data()

    async def _on_category_change(self, new_category: str) -> None:
        """Alterna entre Adultos e Jovens mantendo a semana atual em foco."""
        if self.category == new_category and self.quarterlies:
            return

        self.category = new_category
        await self._save_preferences()

        # Imediatamente reseta o estado em memória para evitar dados misturados / travados
        self.current_quarterly = None
        self.lessons = []
        self.current_lesson = None
        self.days = []
        self.current_day = None

        self.is_loading = True
        self._update_rendered_content()

        try:
            self.quarterlies = await self.service.get_quarterlies(
                lang="pt", category=self.category, force_refresh=False
            )
            if self.quarterlies:
                self.current_quarterly = self._find_current_quarterly(self.quarterlies)
                self.lessons = await self.service.get_lessons(
                    self.current_quarterly.id, lang="pt", force_refresh=False
                )
                if self.lessons:
                    self.current_lesson = self._find_current_lesson(self.lessons)
                    self.days = await self.service.get_lesson_days(
                        self.current_lesson.id,
                        quarterly_id=self.current_quarterly.id,
                        lang="pt",
                        force_refresh=False,
                    )
                    if self.days:
                        target_day = self._find_current_day(self.days)
                        await self._select_day(target_day)
        except Exception:
            logger.exception("Erro ao alternar categoria da Escola Sabatina.")
        finally:
            self.is_loading = False
            self._update_rendered_content()

    async def _on_lesson_change(self, lesson_id: str) -> None:
        """Alterna a lição selecionada no dropdown."""
        found = [l for l in self.lessons if l.id == lesson_id]
        if not found or not self.current_quarterly:
            return

        self.current_lesson = found[0]
        self.is_loading = True
        self._update_rendered_content()

        self.days = await self.service.get_lesson_days(
            self.current_lesson.id,
            quarterly_id=self.current_quarterly.id,
            lang="pt",
            force_refresh=False,
        )
        if self.days:
            target_day = self._find_current_day(self.days)
            await self._select_day(target_day)
        else:
            self.current_day = None

        self.is_loading = False
        self._update_rendered_content()

    async def _select_day(self, target_day: SSDay) -> None:
        """Seleciona um dia de estudo, carrega conteúdo processado e nota pessoal."""
        if not target_day.content:
            full_day = await self.service.get_day_content(
                target_day.id,
                read_path=target_day.read_path,
                lang="pt",
                force_refresh=False,
            )
            if full_day:
                target_day = full_day
                for idx, d in enumerate(self.days):
                    if d.id == target_day.id:
                        self.days[idx] = full_day
                        break

        self.current_day = target_day

        # Carrega anotação salva do SQLite para o dia
        saved_note = await self.service.get_note(target_day.id)
        if self.note_field:
            self.note_field.value = saved_note or ""
        self._set_note_status("", ft.Colors.TRANSPARENT)

        # Carrega respostas das perguntas interativas e mapa mental salvos
        try:
            self.question_answers = await self.service.get_question_answers(target_day.id)
        except Exception:
            self.question_answers = {}

        try:
            self.current_mind_map = await self.service.get_mind_map(target_day.id)
        except Exception:
            self.current_mind_map = None

        self._update_rendered_content()

    # -----------------------------------------------------------------------
    # Download Offline
    # -----------------------------------------------------------------------

    async def _download_current_week(self) -> None:
        """Baixa a lição da semana atual com todas as imagens para leitura offline."""
        if not self.current_quarterly or not self.current_lesson:
            return

        if self.download_progress_bar:
            self.download_progress_bar.visible = True
            self.download_progress_bar.value = None
            self.page.update()

        def _progress(val: float, msg: str):
            if self.download_progress_bar:
                self.download_progress_bar.value = val
                try:
                    self.download_progress_bar.update()
                except Exception:
                    pass

        success = await self.service.download_week_lesson(
            self.current_quarterly.id,
            self.current_lesson.id,
            lang="pt",
            progress_callback=_progress,
        )

        if self.download_progress_bar:
            self.download_progress_bar.visible = False
            self.page.update()

        if success:
            self._show_snackbar("Lição da semana salva offline com imagens!")
            # Recarrega o dia atual com as imagens em cache
            if self.current_day:
                await self._select_day(self.current_day)
        else:
            self._show_snackbar("Não foi possível baixar a lição. Verifique a conexão.")

    async def _download_entire_quarter(self) -> None:
        """Baixa todas as lições e dias do trimestre atual com imagens para uso 100% offline."""
        if not self.current_quarterly:
            return

        if self.download_progress_bar:
            self.download_progress_bar.visible = True
            self.download_progress_bar.value = None
            self.page.update()

        def _progress(val: float, msg: str):
            if self.download_progress_bar:
                self.download_progress_bar.value = val
                try:
                    self.download_progress_bar.update()
                except Exception:
                    pass

        success = await self.service.download_entire_quarter(
            self.current_quarterly.id,
            lang="pt",
            progress_callback=_progress,
        )

        if self.download_progress_bar:
            self.download_progress_bar.visible = False
            self.page.update()

        if success:
            self._show_snackbar("Trimestre completo salvo para leitura offline!")
            if self.current_day:
                await self._select_day(self.current_day)
        else:
            self._show_snackbar("Não foi possível baixar o trimestre completo. Verifique sua conexão.")

    def _build_current_lesson_card(self) -> ft.Container:
        """Constrói o card moderno e ergonômico da lição atual em substituição ao Dropdown técnico."""
        if not self.current_lesson:
            return ft.Container(visible=False)

        index_str = self.current_lesson.index or ""
        clean_num = ""
        if index_str:
            m = re.search(r"(\d+)$", index_str)
            clean_num = str(int(m.group(1))) if m else index_str

        # Obtém o nome real da lição do trimestre dinamicamente da API/modelo (ex: 'Resgate')
        quarterly_name = ""
        if self.current_quarterly and self.current_quarterly.title:
            quarterly_name = self.current_quarterly.title.split(":")[0].strip()

        if quarterly_name:
            index_label = f"{quarterly_name} • Lição {clean_num}" if clean_num else quarterly_name
        elif clean_num:
            index_label = f"Lição {clean_num}"
        else:
            index_label = "Lição Atual"

        date_label = (
            f"{self.current_lesson.start_date} a {self.current_lesson.end_date}"
            if self.current_lesson.start_date
            else ""
        )

        return ft.Container(
            content=ft.Row(
                controls=[
                    ft.Container(
                        content=ft.Text(
                            index_label,
                            weight=ft.FontWeight.BOLD,
                            size=12,
                            color=ft.Colors.ON_PRIMARY_CONTAINER,
                        ),
                        bgcolor=ft.Colors.PRIMARY_CONTAINER,
                        padding=ft.Padding.symmetric(horizontal=10, vertical=6),
                        border_radius=8,
                    ),
                    ft.Column(
                        controls=[
                            ft.Text(
                                self.current_lesson.title or "Sem título",
                                weight=ft.FontWeight.BOLD,
                                size=13,
                                color=ft.Colors.ON_SURFACE,
                                max_lines=1,
                                overflow=ft.TextOverflow.ELLIPSIS,
                            ),
                            ft.Text(
                                date_label,
                                size=11,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                max_lines=1,
                            ),
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    ft.FilledTonalButton(
                        "13 Lições",
                        icon=ft.Icons.UNFOLD_MORE_ROUNDED,
                        tooltip="Ver todas as lições do trimestre",
                        on_click=lambda e: self._show_all_lessons_bottom_sheet(),
                    ),
                ],
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=10,
            ),
            bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=14,
            padding=ft.Padding.symmetric(horizontal=12, vertical=8),
            border=ft.Border.all(1, ft.Colors.OUTLINE_VARIANT),
            ink=True,
            on_click=lambda e: self._show_all_lessons_bottom_sheet(),
        )

    def _show_all_lessons_bottom_sheet(self) -> None:
        """Exibe modal estilo Bottom Sheet com as 13 lições do trimestre de forma limpa e amigável."""
        if not self.page or not self.lessons:
            return

        quarterly_title = (
            self.current_quarterly.title
            if self.current_quarterly
            else "Lições do Trimestre"
        )

        def _select_lesson_and_close(lid: str):
            try:
                self.page.pop_dialog()
            except Exception:
                pass
            self.page.run_task(self._on_lesson_change, lid)

        lesson_items: list[ft.Control] = []
        for idx, l in enumerate(self.lessons):
            is_selected = self.current_lesson and self.current_lesson.id == l.id
            raw_idx = l.index or str(idx + 1)
            m = re.search(r"(\d+)$", raw_idx)
            idx_str = str(int(m.group(1))) if m else raw_idx
            date_range = f"{l.start_date} a {l.end_date}" if l.start_date else ""

            item = ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Text(
                                idx_str,
                                weight=ft.FontWeight.BOLD,
                                size=13,
                                color=ft.Colors.ON_PRIMARY_CONTAINER if is_selected else ft.Colors.ON_SURFACE_VARIANT,
                            ),
                            width=32,
                            height=32,
                            border_radius=8,
                            bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGH,
                            alignment=ft.Alignment.CENTER,
                        ),
                        ft.Column(
                            controls=[
                                ft.Text(
                                    l.title or f"Lição {idx_str}",
                                    weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.W_500,
                                    size=13,
                                    color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                                    max_lines=1,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                                ft.Text(
                                    date_range,
                                    size=11,
                                    color=ft.Colors.ON_SURFACE_VARIANT,
                                ),
                            ],
                            spacing=2,
                            expand=True,
                        ),
                        ft.Icon(
                            ft.Icons.CHECK_CIRCLE_ROUNDED if is_selected else ft.Icons.CHEVRON_RIGHT_ROUNDED,
                            color=ft.Colors.PRIMARY if is_selected else ft.Colors.OUTLINE_VARIANT,
                            size=20,
                        ),
                    ],
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=12,
                ),
                bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_LOW,
                border_radius=10,
                padding=ft.Padding.symmetric(horizontal=12, vertical=10),
                ink=True,
                on_click=lambda e, lid=l.id: _select_lesson_and_close(lid),
            )
            lesson_items.append(item)

        bs = ft.BottomSheet(
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Row(
                            controls=[
                                ft.Icon(ft.Icons.AUTO_STORIES_ROUNDED, color=ft.Colors.PRIMARY, size=22),
                                ft.Text(
                                    quarterly_title,
                                    weight=ft.FontWeight.BOLD,
                                    size=16,
                                    expand=True,
                                    max_lines=1,
                                    overflow=ft.TextOverflow.ELLIPSIS,
                                ),
                                ft.IconButton(
                                    ft.Icons.CLOSE,
                                    tooltip="Fechar",
                                    on_click=lambda ev: self.page.pop_dialog(),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.START,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1),
                        ft.Row(
                            controls=[
                                ft.OutlinedButton(
                                    "Todas as Lições Trimestrais",
                                    icon=ft.Icons.COLLECTIONS_BOOKMARK_ROUNDED,
                                    tooltip="Ver capas e temas de outros trimestres",
                                    on_click=lambda e: (
                                        self.page.pop_dialog(),
                                        asyncio.create_task(self.page.push_route("/escola-sabatina/trimestres")),
                                    ),
                                ),
                                ft.OutlinedButton(
                                    "Baixar Trimestre",
                                    icon=ft.Icons.DOWNLOAD_FOR_OFFLINE_ROUNDED,
                                    tooltip="Salvar todas as lições e dias para leitura offline",
                                    on_click=lambda e: (
                                        self.page.pop_dialog(),
                                        self.page.run_task(self._download_entire_quarter),
                                    ),
                                ),
                            ],
                            alignment=ft.MainAxisAlignment.CENTER,
                            spacing=8,
                            wrap=True,
                        ),
                        ft.Container(
                            content=ft.Column(
                                controls=lesson_items,
                                spacing=6,
                                scroll=ft.ScrollMode.AUTO,
                            ),
                            height=360,
                        ),
                    ],
                    spacing=10,
                    tight=True,
                ),
                padding=ft.Padding.only(left=16, top=16, right=16, bottom=32),
            ),
        )

        try:
            self.page.show_dialog(bs)
        except Exception:
            self.page.overlay.append(bs)
            bs.open = True
            self.page.update()

    # -----------------------------------------------------------------------
    # Renderização da Interface (UI)
    # -----------------------------------------------------------------------

    def _build_day_chip(self, day: SSDay, is_selected: bool) -> ft.Container:
        """Constrói o chip de um dia da semana."""
        title_text = day.title or f"Dia {day.index}"
        # Abreviar se for muito longo
        if len(title_text) > 16:
            title_text = title_text[:14] + "…"

        date_text = day.date
        return ft.Container(
            key=f"day_chip_{day.id}",
            content=ft.Column(
                controls=[
                    ft.Text(
                        title_text,
                        size=11,
                        weight=ft.FontWeight.BOLD if is_selected else ft.FontWeight.W_500,
                        color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE,
                    ),
                    ft.Text(
                        date_text,
                        size=9,
                        color=ft.Colors.PRIMARY if is_selected else ft.Colors.ON_SURFACE_VARIANT,
                    ),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=1,
            ),
            bgcolor=ft.Colors.PRIMARY_CONTAINER if is_selected else ft.Colors.SURFACE_CONTAINER_HIGHEST,
            border_radius=10,
            padding=ft.Padding.symmetric(horizontal=10, vertical=6),
            border=ft.Border.all(
                1.5,
                ft.Colors.PRIMARY if is_selected else ft.Colors.TRANSPARENT,
            ),
            ink=True,
            on_click=lambda e, d=day: self.page.run_task(self._select_day, d),
        )

    def _show_image_dialog(self, image_url: str) -> None:
        """Exibe a tirinha ou ilustração em diálogo modal ampliado."""
        if not self.page:
            return

        dialog = ft.AlertDialog(
            title=ft.Text("Tirinha / Ilustração", weight=ft.FontWeight.BOLD, size=16),
            content=ft.Container(
                content=ft.Image(
                    src=image_url,
                    fit=ft.BoxFit.CONTAIN,
                    border_radius=8,
                ),
                width=650,
                height=480,
                alignment=ft.Alignment.CENTER,
            ),
            actions=[
                ft.TextButton("Fechar", on_click=lambda e: self.page.pop_dialog()),
            ],
            actions_alignment=ft.MainAxisAlignment.END,
        )
        try:
            self.page.show_dialog(dialog)
        except Exception:
            self.page.overlay.append(dialog)
            dialog.open = True
            self.page.update()

    def _build_videos_section(self) -> ft.Container:
        if not self.current_lesson:
            return ft.Container(visible=False)

        try:
            lesson_title = self.current_lesson.title or "Lição"
            day_title = self.current_day.title if self.current_day else None
            videos = self.service.get_lesson_videos(
                lesson_title=lesson_title,
                day_title=day_title,
                category=self.category,
            )

            v_dia = videos["video_do_dia"]
            v_sem = videos["resumo_semana"]

            def _launch(url: str):
                if not self.page:
                    return
                try:
                    res = self.page.launch_url(url)
                    if asyncio.iscoroutine(res):
                        asyncio.create_task(res)
                except Exception:
                    pass

            def _make_tile(item: dict[str, str], icon: ft.IconData) -> ft.Container:
                return ft.Container(
                    content=ft.Row(
                        controls=[
                            ft.Container(
                                content=ft.Icon(icon, size=24, color=ft.Colors.PRIMARY),
                                bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
                                border_radius=8,
                                padding=ft.Padding.all(8),
                            ),
                            ft.Column(
                                controls=[
                                    ft.Row(
                                        controls=[
                                            ft.Text(item["title"], size=13, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
                                            ft.Container(
                                                content=ft.Text(item["badge"], size=10, weight=ft.FontWeight.BOLD, color=ft.Colors.PRIMARY),
                                                bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
                                                border_radius=4,
                                                padding=ft.Padding.symmetric(horizontal=6, vertical=2),
                                            ),
                                        ],
                                        spacing=6,
                                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                    ),
                                    ft.Text(item["subtitle"], size=11, color=ft.Colors.ON_SURFACE_VARIANT, max_lines=1, overflow=ft.TextOverflow.ELLIPSIS),
                                ],
                                spacing=2,
                                expand=True,
                            ),
                            ft.IconButton(
                                icon=ft.Icons.OPEN_IN_NEW_ROUNDED,
                                icon_size=18,
                                tooltip="Assistir no YouTube",
                                on_click=lambda e, u=item["url"]: _launch(u),
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=10,
                    ),
                    padding=ft.Padding.symmetric(horizontal=10, vertical=8),
                    border_radius=10,
                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGH,
                    ink=True,
                    on_click=lambda e, u=item["url"]: _launch(u),
                )

            podcast_icon = getattr(ft.Icons, "PODCASTS_ROUNDED", getattr(ft.Icons, "PODCASTS", ft.Icons.RADIO))

            return ft.Container(
                content=ft.ExpansionTile(
                    leading=ft.Icon(ft.Icons.SMART_DISPLAY_ROUNDED, color=ft.Colors.RED_ACCENT_700),
                    title=ft.Text("Vídeos da Lição", size=14, weight=ft.FontWeight.BOLD),
                    subtitle=ft.Text("Vídeo do Dia & Resumo da Semana", size=11, color=ft.Colors.ON_SURFACE_VARIANT),
                    expanded=False,
                    controls=[
                        ft.Container(
                            content=ft.Column(
                                controls=[
                                    _make_tile(v_dia, ft.Icons.PLAY_CIRCLE_FILL_ROUNDED),
                                    _make_tile(v_sem, podcast_icon),
                                ],
                                spacing=8,
                            ),
                            padding=ft.Padding.only(left=8, right=8, bottom=12, top=4),
                        )
                    ],
                ),
                border=ft.Border.all(1, ft.Colors.with_opacity(0.15, ft.Colors.OUTLINE)),
                border_radius=14,
                bgcolor=ft.Colors.SURFACE_CONTAINER_LOW,
            )
        except Exception:
            logger.exception("Erro ao construir seção de vídeos da lição")
            return ft.Container(visible=False)

    def _update_rendered_content(self) -> None:
        """Atualiza a renderização dos controles da tela."""
        if not self.content_container or not self.page:
            return

        # Sincroniza seletor de categoria
        if self.category_segmented:
            self.category_segmented.selected = [self.category]

        # Sincroniza card da lição atual
        if self.lesson_card:
            new_card = self._build_current_lesson_card()
            self.lesson_card.content = new_card.content
            self.lesson_card.visible = new_card.visible
            try:
                self.lesson_card.update()
            except Exception:
                pass

        # Sincroniza dropdown de lições (compatibilidade)
        if self.lesson_dropdown:
            self.lesson_dropdown.options = [
                ft.dropdown.Option(
                    key=l.id,
                    text=f"Lição {l.index or (idx + 1)}: {l.title} ({l.start_date[:5]} a {l.end_date[:5]})",
                )
                for idx, l in enumerate(self.lessons)
            ]
            self.lesson_dropdown.value = self.current_lesson.id if self.current_lesson else None
            try:
                self.lesson_dropdown.update()
            except Exception:
                pass

        # Estado de carregamento
        if self.is_loading:
            self.content_container.controls = [
                ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.ProgressRing(),
                            ft.Text("Carregando lição da Escola Sabatina...", size=14, italic=True),
                        ],
                        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=12,
                    ),
                    alignment=ft.Alignment.CENTER,
                    padding=ft.Padding.all(40),
                )
            ]
            self.page.update()
            return

        # Estado sem conteúdo
        if not self.current_day:
            self.content_container.controls = [
                create_empty_state_container(
                    icon=ft.Icons.MENU_BOOK_ROUNDED,
                    title="Nenhuma lição disponível offline",
                    message="Conecte-se à internet para baixar os estudos da Escola Sabatina.",
                    action_button=ft.FilledButton(
                        "Recarregar",
                        icon=ft.Icons.REFRESH,
                        on_click=lambda e: self.page.run_task(self._load_initial_data),
                    ),
                )
            ]
            self.page.update()
            return

        font_fam = self._current_font_family

        # 1. Carrossel de dias
        day_chips = [
            self._build_day_chip(day=d, is_selected=(self.current_day and d.id == self.current_day.id))
            for d in self.days
        ]
        self.days_row = ft.Row(
            controls=day_chips,
            scroll=ft.ScrollMode.AUTO,
            spacing=8,
        )

        # 2. Cabeçalho do dia
        self.streak_chip = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT, size=15, color=ft.Colors.ORANGE_ACCENT_400),
                    ft.Text(f"🔥 {self.user_streak} dias", size=12, weight=ft.FontWeight.BOLD, color=ft.Colors.ORANGE_ACCENT_400),
                ],
                tight=True,
                spacing=2,
            ),
            padding=ft.Padding.symmetric(horizontal=8, vertical=2),
            bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.ORANGE_ACCENT_400),
            border_radius=8,
        )

        day_header = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Text(
                                self.current_day.title,
                                size=20,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.PRIMARY,
                                font_family=font_fam,
                                expand=True,
                            ),
                            self.streak_chip,
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.CALENDAR_TODAY, size=14, color=ft.Colors.ON_SURFACE_VARIANT),
                            ft.Text(
                                self.current_day.date,
                                size=12,
                                color=ft.Colors.ON_SURFACE_VARIANT,
                                weight=ft.FontWeight.W_500,
                            ),
                            ft.Container(expand=True),
                            ft.Text(
                                f"Bíblia: {self.bible_version}",
                                size=11,
                                color=ft.Colors.PRIMARY,
                                weight=ft.FontWeight.BOLD,
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.START,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=4,
                    ),
                ],
                spacing=4,
            ),
            padding=ft.Padding.symmetric(vertical=4),
        )

        # 2.1 Barra de controle de fonte, compartilhamento e versão bíblica
        font_family_label = self.font_family_key.split(" ")[0]
        font_bar = ft.Row(
            controls=[
                ft.Text(
                    f"Fonte: {self.font_size}pt · {font_family_label} · Bíblia: {self.bible_version}",
                    size=12,
                    weight=ft.FontWeight.W_500,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                ),
                ft.Row(
                    controls=[
                        ft.IconButton(
                            icon=ft.Icons.SHARE_ROUNDED,
                            icon_size=18,
                            tooltip="Copiar / Compartilhar Estudo do Dia",
                            on_click=lambda e: (
                                self.page.run_task(self._copy_day_study)
                                if self.page and hasattr(self.page, "run_task")
                                else asyncio.create_task(self._copy_day_study())
                            ),
                        ),
                        ft.IconButton(
                            icon=ft.Icons.TEXT_DECREASE,
                            icon_size=18,
                            tooltip="Diminuir fonte (A-)",
                            on_click=lambda e: self._change_font_size(-FONT_STEP),
                        ),
                        ft.IconButton(
                            icon=ft.Icons.TEXT_INCREASE,
                            icon_size=18,
                            tooltip="Aumentar fonte (A+)",
                            on_click=lambda e: self._change_font_size(FONT_STEP),
                        ),
                    ],
                    spacing=0,
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )

        # 3. Tirinha ou imagem do dia (destacada no início, especialmente no domingo)
        image_urls = self.service.extract_image_urls(self.current_day.content or "")
        tirinha_controls: list[ft.Control] = []
        if image_urls:
            img_src = image_urls[0]
            tirinha_card = ft.Card(
                elevation=2,
                content=ft.Container(
                    content=ft.Column(
                        controls=[
                            ft.Row(
                                controls=[
                                    ft.Icon(ft.Icons.IMAGE_ROUNDED, size=18, color=ft.Colors.PRIMARY),
                                    ft.Text(
                                        "Tirinha / Ilustração da Lição",
                                        weight=ft.FontWeight.BOLD,
                                        size=13,
                                        color=ft.Colors.PRIMARY,
                                    ),
                                    ft.Container(expand=True),
                                    ft.IconButton(
                                        ft.Icons.FULLSCREEN,
                                        tooltip="Visualizar ampliado",
                                        icon_size=18,
                                        on_click=lambda e, u=img_src: self._show_image_dialog(u),
                                    ),
                                ],
                                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            ),
                            ft.Image(
                                src=img_src,
                                fit=ft.BoxFit.CONTAIN,
                                border_radius=10,
                                error_content=ft.Container(
                                    content=ft.Text("Imagem indisponível offline", size=11, italic=True),
                                    padding=ft.Padding.all(8),
                                ),
                            ),
                        ],
                        spacing=6,
                    ),
                    padding=ft.Padding.all(12),
                    border_radius=12,
                ),
            )
            tirinha_controls.append(tirinha_card)
            tirinha_controls.append(ft.Container(height=8))

        # 4. Conteúdo Markdown com imagens e links interativos
        raw_text = self.current_day.content or ""
        normalized_content = self.service.html_to_markdown(raw_text)
        normalized_content = self.service.normalize_bible_links(normalized_content)
        # Remove markdown de imagem duplicada para imagens já exibidas no tirinha_card
        if image_urls:
            for u in image_urls:
                normalized_content = re.sub(rf'!\[[^\]]*\]\({re.escape(u)}\)', '', normalized_content)
        normalized_content = normalized_content.strip()

        # Extrai perguntas estruturadas e seção da rede semântica
        interactive_data = self.service.extract_interactive_elements(normalized_content)
        main_md_text = interactive_data["main_content"]
        extracted_questions = interactive_data["questions"]
        semantic_net = interactive_data["semantic_network"]

        # Cores semânticas M3 que se adaptam automaticamente a Claro, Sépia e Escuro
        md_style = ft.MarkdownStyleSheet(
            p_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, color=ft.Colors.ON_SURFACE),
            h1_text_style=ft.TextStyle(size=self.font_size + 8, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.PRIMARY),
            h2_text_style=ft.TextStyle(size=self.font_size + 6, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.PRIMARY),
            h3_text_style=ft.TextStyle(size=self.font_size + 4, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
            h4_text_style=ft.TextStyle(size=self.font_size + 2, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
            h5_text_style=ft.TextStyle(size=self.font_size + 1, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
            h6_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_SURFACE),
            blockquote_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, italic=True, color=ft.Colors.ON_SURFACE_VARIANT),
            a_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, color=ft.Colors.PRIMARY, weight=ft.FontWeight.BOLD, decoration=ft.TextDecoration.UNDERLINE),
            list_bullet_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, color=ft.Colors.ON_SURFACE),
            table_body_text_style=ft.TextStyle(size=self.font_size, font_family=font_fam, color=ft.Colors.ON_SURFACE),
            code_text_style=ft.TextStyle(size=max(12, self.font_size - 1)),
        )

        markdown_reader = ft.Markdown(
            value=main_md_text,
            selectable=True,
            auto_follow_links=False,
            extension_set=ft.MarkdownExtensionSet.GITHUB_WEB,
            md_style_sheet=md_style,
            on_tap_link=self._on_tap_link,
            fit_content=True,
        )

        # Constrói cards de perguntas de discussão / reflexão com campos de resposta
        questions_controls: list[ft.Control] = []
        if extracted_questions:
            questions_controls.append(
                ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.FORUM_ROUNDED, color=ft.Colors.PRIMARY, size=22),
                        ft.Text(
                            "Discuta em Classe & Pense",
                            weight=ft.FontWeight.BOLD,
                            size=16,
                            color=ft.Colors.PRIMARY,
                        ),
                    ],
                    spacing=8,
                )
            )

            for q in extracted_questions:
                q_id = q["id"]
                q_prompt = q["prompt"]
                q_items = q["items"]
                saved_ans = self.question_answers.get(q_id, "")

                prompt_md_reader = ft.Markdown(
                    value=q_prompt,
                    selectable=True,
                    auto_follow_links=False,
                    extension_set=ft.MarkdownExtensionSet.GITHUB_WEB,
                    md_style_sheet=ft.MarkdownStyleSheet(
                        p_text_style=ft.TextStyle(size=self.font_size + 1, font_family=font_fam, weight=ft.FontWeight.W_600, color=ft.Colors.ON_SURFACE),
                        a_text_style=ft.TextStyle(size=self.font_size + 1, font_family=font_fam, color=ft.Colors.PRIMARY, weight=ft.FontWeight.BOLD, decoration=ft.TextDecoration.UNDERLINE),
                    ),
                    on_tap_link=self._on_tap_link,
                    fit_content=True,
                )

                card_children = [prompt_md_reader]
                if q_items:
                    items_md = "\n".join([f"- {it}" for it in q_items])
                    q_md_reader = ft.Markdown(
                        value=items_md,
                        selectable=True,
                        auto_follow_links=False,
                        extension_set=ft.MarkdownExtensionSet.GITHUB_WEB,
                        md_style_sheet=md_style,
                        on_tap_link=self._on_tap_link,
                        fit_content=True,
                    )
                    card_children.append(q_md_reader)

                ans_field = ft.TextField(
                    hint_text="Sua resposta ou reflexão...",
                    value=saved_ans,
                    multiline=True,
                    min_lines=1,
                    max_lines=4,
                    text_size=max(12, self.font_size - 1),
                    border_radius=8,
                    content_padding=ft.Padding.symmetric(horizontal=10, vertical=8),
                    on_change=lambda e, qid=q_id, qtext=q_prompt: self._on_question_answer_change(
                        qid, qtext, e.control.value
                    ),
                )

                card_children.extend([
                    ft.Container(height=4),
                    ans_field,
                ])

                q_card = ft.Container(
                    content=ft.Column(
                        controls=card_children,
                        spacing=6,
                    ),
                    padding=ft.Padding.all(14),
                    border_radius=12,
                    bgcolor=ft.Colors.with_opacity(0.04, ft.Colors.ON_SURFACE),
                    border=ft.Border.all(1, ft.Colors.with_opacity(0.15, ft.Colors.OUTLINE)),
                )
                questions_controls.append(q_card)
                questions_controls.append(ft.Container(height=8))

        # Constrói Card da Rede Semântica / Mapa Mental (se detectado ou quarta-feira)
        semantic_card = None
        has_semantic = semantic_net["detected"] or (self.current_day and "quarta" in (self.current_day.title or "").lower())
        if has_semantic:
            root_concept = semantic_net.get("root_word") or "Palavra da Semana"
            has_saved_map = bool(
                self.current_mind_map and (
                    self.current_mind_map.get("nodes") or self.current_mind_map.get("root_word")
                )
            )
            if self.current_mind_map and self.current_mind_map.get("root_word"):
                root_concept = self.current_mind_map["root_word"]

            btn_label = "Visualizar o seu mapa mental" if has_saved_map else "Criar Mapa Mental"
            btn_icon = ft.Icons.VISIBILITY_ROUNDED if has_saved_map else ft.Icons.AUTO_AWESOME_ROUNDED
            card_subtitle = (
                f"Você já tem {len(self.current_mind_map.get('nodes', []))} ideia(s) conectada(s). Clique para ver ou editar!"
                if has_saved_map
                else "Crie e compartilhe o mapa mental das suas ideias e associações!"
            )

            semantic_card = ft.Container(
                content=ft.Row(
                    controls=[
                        ft.Container(
                            content=ft.Icon(ft.Icons.HUB_ROUNDED, size=28, color=ft.Colors.WHITE),
                            width=48,
                            height=48,
                            border_radius=12,
                            bgcolor=ft.Colors.PRIMARY,
                            alignment=ft.Alignment.CENTER,
                        ),
                        ft.Column(
                            controls=[
                                ft.Row(
                                    controls=[
                                        ft.Text("Rede Semântica da Semana", weight=ft.FontWeight.BOLD, size=15),
                                        ft.Container(
                                            content=ft.Text(
                                                f"Conceito: {root_concept}",
                                                size=11,
                                                weight=ft.FontWeight.BOLD,
                                                color=ft.Colors.PRIMARY,
                                            ),
                                            bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
                                            padding=ft.Padding.symmetric(horizontal=8, vertical=2),
                                            border_radius=8,
                                        ),
                                    ],
                                    spacing=8,
                                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                ),
                                ft.Text(
                                    card_subtitle,
                                    size=12,
                                    color=ft.Colors.ON_SURFACE_VARIANT,
                                ),
                            ],
                            spacing=2,
                            expand=True,
                        ),
                        ft.FilledButton(
                            btn_label,
                            icon=btn_icon,
                            on_click=lambda e, rw=root_concept: self._open_mind_map_modal(rw),
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=12,
                ),
                padding=ft.Padding.all(14),
                border_radius=14,
                bgcolor=ft.Colors.with_opacity(0.08, ft.Colors.PRIMARY),
                border=ft.Border.all(1, ft.Colors.with_opacity(0.2, ft.Colors.PRIMARY)),
            )

        # 5. Seção "Minhas Anotações"
        if self.note_field is None:
            self.note_field = ft.TextField(
                multiline=True,
                min_lines=3,
                max_lines=8,
                hint_text="Escreva suas reflexões e respostas...",
                text_size=self.font_size,
                border_radius=12,
                on_change=self._on_note_change,
            )
        else:
            self.note_field.text_size = self.font_size
            self.note_field.text_style = ft.TextStyle(font_family=font_fam)

        if self.note_status_text is None:
            self.note_status_text = ft.Text(
                "",
                size=12,
                weight=ft.FontWeight.W_500,
            )

        notes_section = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Divider(height=24),
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.EDIT_NOTE_ROUNDED, color=ft.Colors.PRIMARY, size=22),
                            ft.Text(
                                "Minhas Anotações",
                                size=16,
                                weight=ft.FontWeight.BOLD,
                                color=ft.Colors.PRIMARY,
                                expand=True,
                            ),
                            self.note_status_text,
                            ft.IconButton(
                                ft.Icons.SAVE_ROUNDED,
                                tooltip="Salvar agora",
                                icon_size=20,
                                on_click=lambda e: self.page.run_task(
                                    self._save_current_note, self.note_field.value or ""
                                ),
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.START,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        spacing=6,
                    ),
                    self.note_field,
                ],
                spacing=8,
            ),
            padding=ft.Padding.only(top=10, bottom=30),
        )

        # 6. Card de Ação do Quiz Diário da Lição
        quiz_card = ft.Container(
            content=ft.Row(
                controls=[
                    ft.Container(
                        content=ft.Icon(ft.Icons.PSYCHOLOGY_ALT, size=28, color=ft.Colors.WHITE),
                        width=46,
                        height=46,
                        border_radius=12,
                        bgcolor=ft.Colors.PRIMARY,
                        alignment=ft.Alignment.CENTER,
                    ),
                    ft.Column(
                        controls=[
                            ft.Text("Quiz Diário da Lição", weight=ft.FontWeight.BOLD, size=15),
                            ft.Text("Teste seus conhecimentos e mantenha sua ofensiva!", size=12, color=ft.Colors.ON_SURFACE_VARIANT),
                        ],
                        spacing=2,
                        expand=True,
                    ),
                    ft.FilledButton(
                        "Iniciar",
                        icon=ft.Icons.PLAY_ARROW_ROUNDED,
                        on_click=lambda e: self.page.run_task(self._open_quiz_modal),
                    ),
                ],
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=12,
            ),
            padding=ft.Padding.all(14),
            border_radius=14,
            bgcolor=ft.Colors.with_opacity(0.08, ft.Colors.PRIMARY),
            border=ft.Border.all(1, ft.Colors.with_opacity(0.2, ft.Colors.PRIMARY)),
        )

        videos_section = self._build_videos_section()

        self.content_container.controls = [
            self.days_row,
            ft.Divider(height=8),
            day_header,
            font_bar,
            ft.Divider(height=8),
            *tirinha_controls,
            videos_section,
            ft.Container(height=4),
            ft.Container(
                content=markdown_reader,
                padding=ft.Padding.symmetric(vertical=8),
            ),
            *questions_controls,
            *( [semantic_card, ft.Container(height=8)] if semantic_card else [] ),
            quiz_card,
            notes_section,
        ]
        self.page.update()

        # Rola horizontalmente os chips para centralizar o dia atual
        if self.days_row and self.current_day:
            try:
                self.days_row.scroll_to(key=f"day_chip_{self.current_day.id}", duration=300)
            except Exception:
                pass

    async def _open_quiz_modal(self) -> None:
        """Abre o modal de Quiz interativo para o dia selecionado com layout responsivo para Desktop."""
        if not self.page or not self.current_day:
            return

        logger.info(f"[EscolaSabatinaView] Solicitando quiz: dia='{self.current_day.id}', categoria='{self.category}'")
        questions = await self.quiz_service.get_daily_quiz(
            day_id=self.current_day.id,
            category=self.category,
        )

        if not questions:
            self._show_snackbar("Nenhum quiz disponível para este dia no momento.")
            return

        dialog = ft.AlertDialog(
            modal=True,
            content_padding=ft.Padding.all(0),
        )

        def _close_modal():
            if self.page:
                try:
                    self.page.pop_dialog()
                except Exception:
                    pass
            dialog.open = False
            if self.page:
                self.page.update()

        def _on_finish(xp: int, streak: int):
            self.user_streak = streak
            if self.streak_chip and self.streak_chip.content:
                self.streak_chip.content.controls[1].value = f"🔥 {self.user_streak} dias"
                try:
                    self.streak_chip.update()
                except Exception:
                    pass
            _close_modal()
            self._show_snackbar(f"Parabéns! +{xp} XP ganhos e ofensiva de {streak} dias mantida!")

        quiz_container = QuizView(
            questions=questions,
            quiz_service=self.quiz_service,
            user_id="local_user",
            current_streak=self.user_streak,
            on_close=_close_modal,
            on_finish=_on_finish,
        )
        dialog.content = ft.Container(
            content=quiz_container,
            width=540,
            height=620,
        )

        from src.views.settings_dialog import ensure_page_dialogs
        ensure_page_dialogs(self.page)

        opened = False
        if hasattr(self.page, "show_dialog") and callable(getattr(self.page, "show_dialog")):
            try:
                self.page.show_dialog(dialog)
                opened = True
            except Exception as e:
                logger.warning(f"[EscolaSabatinaView] show_dialog falhou ({e}), tentando fallback...")

        if not opened:
            try:
                self.page.overlay.append(dialog)
                dialog.open = True
                self.page.update()
            except Exception as e:
                logger.error(f"[EscolaSabatinaView] Erro ao exibir modal de quiz: {e}")

    def _on_question_answer_change(self, question_id: str, question_text: str, answer_text: str) -> None:
        """Trata digitação de resposta em uma pergunta individual com debounce de 500ms."""
        self.question_answers[question_id] = answer_text

        # Cancela debounce anterior se existir
        if question_id in self._q_debounce_tasks and not self._q_debounce_tasks[question_id].done():
            self._q_debounce_tasks[question_id].cancel()

        self._q_debounce_tasks[question_id] = asyncio.create_task(
            self._debounce_save_question(question_id, question_text, answer_text)
        )

    async def _debounce_save_question(self, question_id: str, question_text: str, answer_text: str) -> None:
        try:
            await asyncio.sleep(0.5)
            if self.current_day:
                await self.service.save_question_answer(
                    answer_id=question_id,
                    day_id=self.current_day.id,
                    question_text=question_text,
                    answer_text=answer_text,
                )
        except asyncio.CancelledError:
            pass
        except Exception:
            logger.exception(f"Erro ao salvar resposta da pergunta {question_id}")

    def _open_mind_map_modal(self, root_word: str) -> None:
        """Abre o Estúdio Interativo de Mapas Mentais (Rede Semântica) em modal expandido."""
        if not self.page or not self.current_day:
            return

        initial_nodes = []
        if self.current_mind_map and self.current_mind_map.get("nodes"):
            initial_nodes = self.current_mind_map["nodes"]

        dialog = ft.AlertDialog(
            modal=True,
            content_padding=ft.Padding.all(0),
        )

        def _close_modal():
            if self.page:
                try:
                    self.page.pop_dialog()
                except Exception:
                    pass
            dialog.open = False
            if self.page:
                self.page.update()
            # Atualiza o card da lição para exibir "Visualizar o seu mapa mental"
            self._update_rendered_content()

        async def _save_mind_map(saved_root: str, nodes: list[dict[str, Any]]):
            if not self.current_day:
                return
            self.current_mind_map = {"root_word": saved_root, "nodes": nodes}
            await self.service.save_mind_map(self.current_day.id, saved_root, nodes)

        studio = MindMapStudio(
            root_word=root_word,
            initial_nodes=initial_nodes,
            on_save=_save_mind_map,
            on_close=_close_modal,
            on_show_snackbar=self._show_snackbar,
        )

        dialog.content = ft.Container(
            content=studio,
            width=680,
            height=660,
        )

        from src.views.settings_dialog import ensure_page_dialogs
        ensure_page_dialogs(self.page)

        opened = False
        if hasattr(self.page, "show_dialog") and callable(getattr(self.page, "show_dialog")):
            try:
                self.page.show_dialog(dialog)
                opened = True
            except Exception as e:
                logger.warning(f"[EscolaSabatinaView] show_dialog mind_map falhou ({e}), tentando fallback...")

        if not opened:
            try:
                self.page.overlay.append(dialog)
                dialog.open = True
                self.page.update()
            except Exception as e:
                logger.error(f"[EscolaSabatinaView] Erro ao exibir modal de mapa mental: {e}")

    async def _copy_day_study(self) -> None:
        """Copia o estudo do dia devidamente formatado para a área de transferência."""
        if not self.current_day:
            self._show_snackbar("Nenhum conteúdo disponível para copiar.")
            return

        parts: list[str] = []
        if self.current_quarterly and self.current_quarterly.title:
            parts.append(f"📘 {self.current_quarterly.title}")

        lesson_title = ""
        if self.current_lesson and self.current_lesson.title:
            lesson_title = self.current_lesson.title
        if lesson_title:
            parts.append(f"📖 {lesson_title}")

        day_title = self.current_day.title or "Estudo do Dia"
        day_date = self.current_day.date or ""
        date_info = f" ({day_date})" if day_date else ""
        parts.append(f"📅 {day_title}{date_info}")
        parts.append("—" * 20)

        raw_content = self.current_day.content or ""
        md_content = self.service.html_to_markdown(raw_content)
        # Remove tags de imagem ![...](...)
        clean_text = re.sub(r"!\[[^\]]*\]\([^)]+\)", "", md_content)
        # Transforma links de bíblia [Texto](bible://...) em apenas Texto
        clean_text = re.sub(r"\[([^\]]+)\]\(bible://[^)]+\)", r"\1", clean_text)
        # Remove outros links markdown [Texto](url) -> Texto
        clean_text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", clean_text)
        # Remove marcadores de cabeçalho (ex: ## Título -> Título)
        clean_text = re.sub(r"#{1,6}\s*", "", clean_text)
        # Remove quebras de linha excessivas
        clean_text = re.sub(r"\n{3,}", "\n\n", clean_text).strip()

        if clean_text:
            parts.append(clean_text)

        parts.append("—" * 20)
        parts.append("✨ Compartilhado via Kairós")

        final_text = "\n\n".join(parts)

        try:
            if self.page and getattr(self.page, "clipboard", None):
                res = self.page.clipboard.set(final_text)
                if inspect.iscoroutine(res):
                    await res
            elif self.page and hasattr(self.page, "set_clipboard_async"):
                await self.page.set_clipboard_async(final_text)
            elif self.page and hasattr(self.page, "set_clipboard"):
                self.page.set_clipboard(final_text)
        except Exception:
            pass

        self._show_snackbar("Estudo copiado para a área de transferência! 📋")


    # -----------------------------------------------------------------------
    # Método build (ft.View)
    # -----------------------------------------------------------------------

    def build(self, page: ft.Page) -> ft.View:
        self.page = page

        # Configuração da barra de progresso de download
        self.download_progress_bar = ft.ProgressBar(visible=False, height=3)

        # Dropdown de lições do trimestre (mantido oculto para compatibilidade retroativa)
        lesson_options = [
            ft.dropdown.Option(key=l.id, text=f"Lição {l.index}: {l.title}")
            for l in self.lessons
        ]
        self.lesson_dropdown = ft.Dropdown(
            options=lesson_options,
            value=self.current_lesson.id if self.current_lesson else None,
            text_size=12,
            dense=True,
            expand=True,
            visible=False,
            on_select=lambda e: self.page.run_task(self._on_lesson_change, e.control.value),
        )

        # Card moderno da lição da semana
        self.lesson_card = self._build_current_lesson_card()

        download_menu = ft.PopupMenuButton(
            icon=ft.Icons.DOWNLOAD_ROUNDED,
            tooltip="Opções de Download Offline",
            items=[
                ft.PopupMenuItem(
                    "Baixar lição da semana",
                    icon=ft.Icons.DOWNLOAD_ROUNDED,
                    on_click=lambda e: self.page.run_task(self._download_current_week),
                ),
                ft.PopupMenuItem(
                    "Baixar trimestre completo",
                    icon=ft.Icons.DOWNLOAD_FOR_OFFLINE_ROUNDED,
                    on_click=lambda e: self.page.run_task(self._download_entire_quarter),
                ),
            ],
        )

        top_bar = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Container(expand=True),
                            download_menu,
                            ft.IconButton(
                                ft.Icons.TEXT_FIELDS_ROUNDED,
                                tooltip="Acessibilidade e Bíblia (fonte, tamanho, versão)",
                                on_click=lambda e: self._show_accessibility_bottom_sheet(),
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.END,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    self.lesson_card,
                    self.download_progress_bar,
                ],
                spacing=8,
            ),
            padding=ft.Padding.symmetric(horizontal=16, vertical=6),
        )

        self.content_container = ft.Column(
            controls=[],
            scroll=ft.ScrollMode.AUTO,
            expand=True,
            spacing=4,
        )

        # Largura máxima responsiva centralizada de 680px para leitura ergonômica
        p_width = getattr(page, "width", None)
        content_width = min(p_width, 680) if isinstance(p_width, (int, float)) and p_width > 0 else None

        centered_container = ft.Container(
            content=ft.Column(
                controls=[
                    top_bar,
                    ft.Container(
                        content=self.content_container,
                        padding=ft.Padding.symmetric(horizontal=16),
                        expand=True,
                    ),
                ],
                spacing=0,
                expand=True,
            ),
            width=content_width,
            alignment=ft.Alignment.TOP_CENTER,
            expand=True,
        )

        root_view = ft.View(
            route="/escola-sabatina",
            appbar=ft.AppBar(
                title=ft.Text("Escola Sabatina", weight=ft.FontWeight.BOLD),
                center_title=True,
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    on_click=lambda e: asyncio.create_task(page.push_route("/")),
                ),
                actions=[
                    ft.IconButton(
                        ft.Icons.COLLECTIONS_BOOKMARK_ROUNDED,
                        tooltip="Lições Trimestrais (Ver capas e temas)",
                        on_click=lambda e: asyncio.create_task(page.push_route("/escola-sabatina/trimestres")),
                    ),
                    ft.IconButton(
                        ft.Icons.REFRESH,
                        tooltip="Recarregar lição",
                        on_click=lambda e: self.page.run_task(self._load_initial_data),
                    ),
                ],
            ),
            controls=[
                ft.SafeArea(
                    maintain_bottom_view_padding=True,
                    content=ft.Container(
                        content=centered_container,
                        alignment=ft.Alignment.TOP_CENTER,
                        expand=True,
                    ),
                    expand=True,
                )
            ],
        )

        # Inicia carga de dados assíncrona
        page.run_task(self._load_initial_data)

        return root_view
