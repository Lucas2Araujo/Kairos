from __future__ import annotations

# Re-export para retrocompatibilidade total
from src.views.hinario_view import (
    APP_VERSION,
    HinarioView,
    HinosView,
    HomeView,
    format_hino_number,
    parse_hino_number,
    strip_accents,
)

__all__ = [
    "HomeView",
    "HinosView",
    "HinarioView",
    "APP_VERSION",
    "parse_hino_number",
    "format_hino_number",
    "strip_accents",
]

