"""
Componente Modal de Exibição de Versículo Bíblico em Destaque.
Apresenta um diálogo temático com o texto bíblico, referência e atalho direto para a leitura
do capítulo correspondente na Bíblia integrada do app (/biblia?livro=...&capitulo=...&versiculo=...).
"""

from __future__ import annotations

import re
import urllib.parse
from typing import NamedTuple

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
    verse_text: str,
    verse_reference: str,
    on_read_full_chapter: callable = None,
) -> ft.AlertDialog:
    """
    Exibe um ft.AlertDialog temático com o versículo e ação para leitura completa.
    """
    parsed = parse_verse_reference(verse_reference)

    def _on_ler_capitulo(e):
        try:
            page.close(dialog)
        except Exception:
            try:
                dialog.open = False
                page.update()
            except Exception:
                pass

        if on_read_full_chapter and callable(on_read_full_chapter):
            on_read_full_chapter(parsed.livro, parsed.capitulo, parsed.versiculo)
        else:
            livro_encoded = urllib.parse.quote(parsed.livro)
            route = f"/biblia?livro={livro_encoded}&capitulo={parsed.capitulo}&versiculo={parsed.versiculo}"
            page.go(route)

    def _on_fechar(e):
        try:
            page.close(dialog)
        except Exception:
            try:
                dialog.open = False
                page.update()
            except Exception:
                pass

    dialog = ft.AlertDialog(
        modal=True,
        title=ft.Row(
            controls=[
                ft.Icon(ft.Icons.MENU_BOOK_ROUNDED, color=ft.Colors.PRIMARY, size=24),
                ft.Text(
                    verse_reference or "Texto Bíblico",
                    weight=ft.FontWeight.BOLD,
                    size=18,
                    color=ft.Colors.PRIMARY,
                    expand=True,
                ),
            ],
            alignment=ft.MainAxisAlignment.START,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        ),
        content=ft.Container(
            content=ft.Column(
                controls=[
                    ft.Container(
                        content=ft.Text(
                            f'"{verse_text.strip()}"',
                            size=16,
                            italic=True,
                            weight=ft.FontWeight.W_400,
                        ),
                        bgcolor=ft.Colors.SURFACE_CONTAINER_HIGHEST,
                        border_radius=12,
                        padding=ft.Padding.all(16),
                        border=ft.Border(
                            left=ft.BorderSide(4, ft.Colors.PRIMARY)
                        ),
                    ),
                    ft.Container(height=4),
                    ft.Text(
                        f"Referência: {parsed.livro} {parsed.capitulo}:{parsed.versiculo}",
                        size=12,
                        color=ft.Colors.ON_SURFACE_VARIANT,
                        weight=ft.FontWeight.W_500,
                    ),
                ],
                spacing=8,
                tight=True,
            ),
            width=360,
        ),
        actions=[
            ft.TextButton(
                "Fechar",
                on_click=_on_fechar,
            ),
            ft.FilledButton(
                "Ler Capítulo Completo",
                icon=ft.Icons.AUTO_STORIES,
                on_click=_on_ler_capitulo,
            ),
        ],
        actions_alignment=ft.MainAxisAlignment.END,
    )

    try:
        page.open(dialog)
    except Exception:
        page.dialog = dialog
        dialog.open = True
        page.update()

    return dialog
