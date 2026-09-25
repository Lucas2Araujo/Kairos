from __future__ import annotations

import re
from typing import NamedTuple

from src.repositories.biblia_repository import (
    _NORMALIZED_ALIASES,
    _normalize_text,
)


class BibleRefMatch(NamedTuple):
    start: int
    end: int
    raw_text: str
    livro: str
    capitulo: int
    versiculo: int


# Expressão regular para capturar referências bíblicas:
# Grupo 1: Nome do livro (opcionalmente precedido de 1, 2, 3 ou I, II, III)
# Grupo 2: Capítulo
# Grupo 3: Versículo(s) (ex: "16", "1-3", "19, 20", "11, 13", "4-7")
BIBLE_REF_PATTERN = re.compile(
    r"\b((?:[1-3]|I{1,3})\s?[A-Za-zÀ-ÿ]+|[A-Za-zÀ-ÿ]{2,})\s+(\d+)\s*[:\.]\s*(\d+(?:\s*[-–—]\s*\d+)?(?:,\s*\d+)*)\b",
    re.IGNORECASE,
)


def _is_valid_bible_book(book_name: str) -> bool:
    """Verifica se o nome ou abreviação corresponde a um livro bíblico canônico."""
    if not book_name:
        return False
    norm = _normalize_text(book_name.strip())
    # Trata numerais romanos (I, II, III -> 1, 2, 3)
    norm = re.sub(r"^i{1,3}\s*", lambda m: f"{len(m.group(0).strip())} ", norm).strip()
    return norm in _NORMALIZED_ALIASES


def find_bible_references(text: str) -> list[BibleRefMatch]:
    """
    Encontra todas as citações bíblicas válidas presentes em um texto.
    Descarta falsos positivos onde a palavra anterior não é um livro bíblico.
    """
    if not text:
        return []

    matches: list[BibleRefMatch] = []
    for m in BIBLE_REF_PATTERN.finditer(text):
        book_raw = m.group(1).strip()
        if _is_valid_bible_book(book_raw):
            cap_str = m.group(2)
            ver_str = m.group(3)
            try:
                cap = int(cap_str)
                # Pega o primeiro versículo se for intervalo (ex: "1-3" -> 1, "19, 20" -> 19)
                first_ver = int(re.split(r"[-–—,]", ver_str)[0].strip())
                matches.append(
                    BibleRefMatch(
                        start=m.start(),
                        end=m.end(),
                        raw_text=m.group(0).strip(),
                        livro=book_raw,
                        capitulo=cap,
                        versiculo=first_ver,
                    )
                )
            except (ValueError, IndexError):
                continue

    return matches


def extract_all_bible_refs(text: str) -> list[str]:
    """Retorna lista única e ordenada de strings de referências bíblicas encontradas no texto."""
    matches = find_bible_references(text)
    seen: set[str] = set()
    result: list[str] = []
    for m in matches:
        clean = m.raw_text
        if clean not in seen:
            seen.add(clean)
            result.append(clean)
    return result


def split_text_by_bible_refs(text: str) -> list[tuple[str, str | None]]:
    """
    Divide um parágrafo em segmentos de texto comum e citações bíblicas clicáveis.
    Retorna lista de tuplas: (fragmento_texto, referencia_ou_None).
    """
    matches = find_bible_references(text)
    if not matches:
        return [(text, None)]

    segments: list[tuple[str, str | None]] = []
    last_idx = 0

    for m in matches:
        if m.start > last_idx:
            segments.append((text[last_idx : m.start], None))
        segments.append((m.raw_text, m.raw_text))
        last_idx = m.end

    if last_idx < len(text):
        segments.append((text[last_idx:], None))

    return segments

