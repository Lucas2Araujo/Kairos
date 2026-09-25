from dataclasses import dataclass
from typing import Optional


@dataclass
class CommentaryAuthor:
    """Representa um autor de comentário bíblico."""

    id: int
    slug: str
    name: str
    short_name: Optional[str] = None
    description: Optional[str] = None
    is_public_domain: bool = True


@dataclass
class CommentaryItem:
    """Representa uma anotação ou comentário exegético/devocional."""

    id: int
    author_id: int
    author_name: str
    author_slug: str
    book_id: int
    chapter: int
    verse_start: int
    verse_end: int
    title: Optional[str]
    content: str

    @property
    def range_display(self) -> str:
        """Formata o intervalo de versículos coberto pelo comentário."""
        if self.verse_start == self.verse_end:
            return f"v. {self.verse_start}"
        return f"vv. {self.verse_start}-{self.verse_end}"
