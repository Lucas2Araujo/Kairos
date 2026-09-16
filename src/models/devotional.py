from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Devotional:
    """
    Data Transfer Object (DTO) representando uma meditação/devocional diária.
    Imutável para integridade em operações assíncronas e de cache.
    Suporta múltiplos tipos de devocionais (ex: 'jovem', 'mulher', 'adulto').
    """

    published_at: str  # Formato ISO (YYYY-MM-DD)
    title: str
    verse_text: str
    verse_reference: str
    content: str
    category: str = "jovem"  # Tipo/Categoria de devocional (ex: 'jovem', 'adultos', 'mulher')
    author: str = ""
    source_url: str = ""
    cached_at: str | None = None

    @classmethod
    def from_dict(cls, data: dict) -> Devotional:
        """Instancia a partir de dicionário (da API Supabase ou do banco SQLite)."""
        return cls(
            published_at=str(data.get("published_at", "")).strip(),
            title=str(data.get("title", "")).strip(),
            verse_text=str(data.get("verse_text", "")).strip(),
            verse_reference=str(data.get("verse_reference", "")).strip(),
            content=str(data.get("content", "")).strip(),
            category=str(data.get("category", "") or "jovem").strip().lower(),
            author=str(data.get("author", "") or "").strip(),
            source_url=str(data.get("source_url", "") or "").strip(),
            cached_at=data.get("cached_at"),
        )

    def to_dict(self) -> dict:
        """Serializa em dicionário para persistência ou manipulação."""
        return {
            "published_at": self.published_at,
            "title": self.title,
            "verse_text": self.verse_text,
            "verse_reference": self.verse_reference,
            "content": self.content,
            "category": self.category,
            "author": self.author,
            "source_url": self.source_url,
            "cached_at": self.cached_at or datetime.utcnow().isoformat(),
        }
