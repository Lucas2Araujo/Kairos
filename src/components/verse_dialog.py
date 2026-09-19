"""
Componente Modal de Exibição de Versículo Bíblico em Destaque.
Apresenta um diálogo temático com o texto bíblico, suporte a múltiplos textos correlatos,
seletor embutido de versão bíblica e atalho direto para leitura na Bíblia integrada do app.
"""

from __future__ import annotations

import asyncio
import re
import urllib.parse
from typing import Any, Callable, NamedTuple

import flet as ft


class ParsedVerseRef(NamedTuple):
    livro: str
    capitulo: int
    versiculo: int


def parse_verse_reference(ref_str: str | None) -> ParsedVerseRef:
    """
    Parser regex tolerante a falhas para extrair livro, capítulo e versículo
    a partir de múltiplos formatos de citação bíblica:
    - "1Pe 1:20" -> livro='1Pe', capitulo=1, versiculo=20
    - "Jo 3:16-17" -> livro='Jo', capitulo=3, versiculo=16
    - "Salmos 23:1" -> livro='Salmos', capitulo=23, versiculo=1
    - "1 Coríntios 13:4" -> livro='1 Coríntios', capitulo=13, versiculo=4
    - "Gênesis 1" -> livro='Gênesis', capitulo=1, versiculo=1
    """
    if not ref_str or not ref_str.strip():
        return ParsedVerseRef(livro="Salmos", capitulo=1, versiculo=1)

    clean_ref = ref_str.strip().strip("()[]{}.,;")

    # Padrão flexível: [Prefixo 1-3 opcional + Nome do Livro] + [Capítulo] + [: versículo opcional]
    pattern = r"^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?:\s*[:,\.]\s*(\d+))?"
    match = re.search(pattern, clean_ref)

    if match:
        livro = match.group(1).strip()
        capitulo = int(match.group(2))
        versiculo = int(match.group(3)) if match.group(3) else 1
        return ParsedVerseRef(livro=livro, capitulo=capitulo, versiculo=versiculo)

    # Fallback se for apenas números ou texto livre
    numbers = re.findall(r"\d+", clean_ref)
    words = re.findall(r"[A-Za-zÀ-ÿ]+", clean_ref)
    livro = " ".join(words) if words else "Salmos"
    capitulo = int(numbers[0]) if len(numbers) >= 1 else 1
    versiculo = int(numbers[1]) if len(numbers) >= 2 else 1

    return ParsedVerseRef(livro=livro, capitulo=capitulo, versiculo=versiculo)


def show_verse_dialog(
    page: ft.Page,
    verse_text: str = "",
    verse_reference: str = "",
    on_read_full_chapter: Callable[[str, int, int], Any] | None = None,
    passages: list[dict[str, Any]] | None = None,
    available_versions: list[str] | None = None,
    current_version: str | None = None,
    on_version_change: Callable[[str], Any] | None = None,
    fetch_passage_text: Callable[[str, str], Any] | None = None,
) -> ft.AlertDialog:
    """
    Exibe um ft.AlertDialog temático com o versículo ou grupo de passagens bíblicas.
    Recursos:
    - Suporte a passagem única ou lista de textos seguidos (grupo de versículos).
    - Seletor compacto de versão bíblica no cabeçalho com atualização dinâmica em tempo real.
    - Rolagem suave para múltiplos textos e capítulos longos.
    - Botão de leitura completa para cada texto e para o conjunto.
    - Compatível com Flet 0.86+ (page.show_dialog / page.pop_dialog) e fallbacks.
    """
    parsed = parse_verse_reference(verse_reference)

    # Normaliza lista de passagens
    passages_list: list[dict[str, Any]] = []
    if passages:
        passages_list = [dict(p) for p in passages]
    else:
        disp_ref = (
            verse_reference.strip()
            if verse_reference
            else f"{parsed.livro} {parsed.capitulo}:{parsed.versiculo}"
        )
        passages_list = [
            {
                "ref_label": disp_ref,
                "canonical_ref": disp_ref,
                "text": verse_text or "Texto bíblico não disponível.",
                "livro": parsed.livro,
                "capitulo": parsed.capitulo,
                "versiculo": parsed.versiculo,
            }
        ]

    active_ver = (current_version or "ARA").strip().upper()
    avail_versions = available_versions or ["ARA", "NVI", "KJA", "NTLH", "AS21"]
    if active_ver not in avail_versions:
        avail_versions = [active_ver] + [v for v in avail_versions if v != active_ver]

    def _dismiss_dialog():
        closed = False
        if hasattr(page, "pop_dialog") and callable(getattr(page, "pop_dialog")):
            try:
                page.pop_dialog()
                closed = True
            except Exception:
                pass
        if not closed and hasattr(page, "close") and callable(getattr(page, "close")):
            try:
                page.close(dialog)
                closed = True
            except Exception:
                pass
        if not closed:
            try:
                dialog.open = False
                page.update()
            except Exception:
                pass

    def _on_navigate_passage(item: dict[str, Any]):
        _dismiss_dialog()
        livro_target = item.get("livro") or parsed.livro
        cap_target = item.get("capitulo") or parsed.capitulo
        ver_target = item.get("versiculo") or parsed.versiculo

        if on_read_full_chapter and callable(on_read_full_chapter):
            on_read_full_chapter(livro_target, cap_target, ver_target)
        else:
            livro_encoded = urllib.parse.quote(str(livro_target))
            ver_suffix = f"&versao={active_ver}" if current_version else ""
            route = (
                f"/biblia?livro={livro_encoded}&capitulo={cap_target}&versiculo={ver_target}"
                f"{ver_suffix}"
            )
            go_fn = getattr(page, "go", None)
            if callable(go_fn):
                go_fn(route)
            elif hasattr(page, "push_route"):
                asyncio.create_task(page.push_route(route))

    def _on_ler_capitulo(e):
        first_item = passages_list[0] if passages_list else {"livro": parsed.livro, "capitulo": parsed.capitulo, "versiculo": parsed.versiculo}
        _on_navigate_passage(first_item)

    def _on_fechar(e):
        _dismiss_dialog()

    passages_column = ft.Column(
        controls=[],
        spacing=10,
        tight=True,
        scroll=ft.ScrollMode.AUTO,
    )

    def _build_passages_ui():
        if len(passages_list) == 1:
            p = passages_list[0]
            ref_title = p.get("canonical_ref", "") or p.get("ref_label", "")
            passages_column.controls = [
                ft.Container(
                    content=ft.Text(
                        f'"{p.get("text", "").strip()}"',
                        size=15,
                        italic=True,
                        weight=ft.FontWeight.W_400,
                        selectable=True,
                    ),
                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                    border_radius=12,
                    padding=ft.Padding.all(16),
                    border=ft.Border(left=ft.BorderSide(4, ft.Colors.PRIMARY)),
                ),
                ft.Container(height=4),
                ft.Text(
                    f"Referência: {ref_title} ({active_ver})",
                    size=12,
                    color=ft.Colors.ON_SURFACE_VARIANT,
                    weight=ft.FontWeight.W_500,
                ),
            ]
        else:
            cards = []
            for p in passages_list:
                ref_title = p.get("canonical_ref", "") or p.get("ref_label", "")
                cards.append(
                    ft.Container(
                        content=ft.Column(
                            controls=[
                                ft.Row(
                                    controls=[
                                        ft.Row(
                                            controls=[
                                                ft.Icon(
                                                    ft.Icons.BOOKMARK_ROUNDED,
                                                    size=15,
                                                    color=ft.Colors.PRIMARY,
                                                ),
                                                ft.Text(
                                                    f"{ref_title} ({active_ver})",
                                                    weight=ft.FontWeight.BOLD,
                                                    size=13,
                                                    color=ft.Colors.PRIMARY,
                                                ),
                                            ],
                                            spacing=6,
                                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                        ),
                                        ft.IconButton(
                                            icon=ft.Icons.OPEN_IN_NEW_ROUNDED,
                                            tooltip=f"Ler {ref_title} na Bíblia",
                                            icon_size=16,
                                            on_click=lambda e, target_p=p: _on_navigate_passage(target_p),
                                        ),
                                    ],
                                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                                ),
                                ft.Container(
                                    content=ft.Text(
                                        f'"{p.get("text", "").strip()}"',
                                        size=14,
                                        italic=True,
                                        weight=ft.FontWeight.W_400,
                                        selectable=True,
                                    ),
                                    bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                                    border_radius=10,
                                    padding=ft.Padding.all(12),
                                    border=ft.Border(
                                        left=ft.BorderSide(3, ft.Colors.PRIMARY)
                                    ),
                                ),
                            ],
                            spacing=4,
                            tight=True,
                        ),
                        margin=ft.Margin.only(bottom=6),
                    )
                )
            passages_column.controls = cards

    _build_passages_ui()

    async def _handle_version_change(new_ver: str):
        nonlocal active_ver
        if not new_ver or new_ver == active_ver:
            return
        active_ver = new_ver

        if on_version_change and callable(on_version_change):
            try:
                res = on_version_change(new_ver)
                if asyncio.iscoroutine(res):
                    await res
            except Exception:
                pass

        if fetch_passage_text and callable(fetch_passage_text):
            for p in passages_list:
                ref_key = p.get("ref_label") or p.get("canonical_ref") or ""
                try:
                    res = fetch_passage_text(ref_key, new_ver)
                    new_txt = await res if asyncio.iscoroutine(res) else res
                    if new_txt:
                        p["text"] = new_txt
                except Exception:
                    pass

        _build_passages_ui()
        try:
            page.update()
        except Exception:
            pass

    def _on_version_dropdown_change(e):
        val = e.control.value if e and hasattr(e, "control") else ""
        if not val:
            return
        if hasattr(page, "run_task") and callable(getattr(page, "run_task")):
            page.run_task(_handle_version_change, val)
        else:
            asyncio.create_task(_handle_version_change(val))

    version_dropdown = ft.Dropdown(
        options=[ft.dropdown.Option(key=v, text=v) for v in avail_versions],
        value=active_ver,
        text_size=11,
        dense=True,
        width=88,
        content_padding=ft.Padding.symmetric(horizontal=8, vertical=2),
        on_select=_on_version_dropdown_change,
    )

    is_group = len(passages_list) > 1
    main_title = (
        f"Textos Bíblicos ({len(passages_list)})"
        if is_group
        else (passages_list[0].get("canonical_ref") or verse_reference or "Texto Bíblico")
    )

    dialog = ft.AlertDialog(
        modal=True,
        title=ft.Row(
            controls=[
                ft.Row(
                    controls=[
                        ft.Icon(ft.Icons.MENU_BOOK_ROUNDED, color=ft.Colors.PRIMARY, size=20),
                        ft.Text(
                            main_title,
                            weight=ft.FontWeight.BOLD,
                            size=16,
                            color=ft.Colors.PRIMARY,
                            overflow=ft.TextOverflow.ELLIPSIS,
                            max_lines=1,
                        ),
                    ],
                    spacing=6,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    expand=True,
                ),
                version_dropdown,
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        ),
        content=ft.Container(
            content=passages_column,
            width=380,
            height=360 if is_group else None,
        ),
        actions=[
            ft.TextButton(
                "Fechar",
                on_click=_on_fechar,
            ),
            ft.FilledButton(
                "Ler na Bíblia" if is_group else "Ler Capítulo Completo",
                icon=ft.Icons.AUTO_STORIES,
                on_click=_on_ler_capitulo,
            ),
        ],
        actions_alignment=ft.MainAxisAlignment.END,
    )

    opened = False
    # Suporta mock_page.open em testes legados se especificado
    if hasattr(page, "open") and callable(getattr(page, "open")):
        try:
            page.open(dialog)
            opened = True
        except (AttributeError, TypeError):
            pass
        except Exception:
            pass

    if not opened and hasattr(page, "show_dialog") and callable(getattr(page, "show_dialog")):
        try:
            page.show_dialog(dialog)
            opened = True
        except Exception:
            pass

    if not opened:
        try:
            page.dialog = dialog
            dialog.open = True
            page.update()
        except Exception:
            pass

    return dialog
