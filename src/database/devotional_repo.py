from __future__ import annotations

# Re-export limpo para retrocompatibilidade
from src.repositories.meditacao_repository import (
    DevotionalRepository,
    MeditacaoRepository,
)

__all__ = ["DevotionalRepository", "MeditacaoRepository"]

