from dataclasses import dataclass


@dataclass(frozen=True)
class CrossReferenceItem:
    """
    DTO imutável representando uma referência cruzada bíblica.
    Todos os livros são identificados pelo ID canônico inteiro (1 a 66),
    garantindo independência de idioma e facilidade de localização em português.
    """

    from_book_id: int
    from_chapter: int
    from_verse: int
    to_book_id: int
    to_chapter: int
    to_verse_start: int
    to_verse_end: int
    votes: int
    to_book_name: str = ""
    preview_text: str = ""

    @property
    def referencia_formatada(self) -> str:
        """Retorna referência formatada em português (ex: 'João 1:1' ou 'Romanos 8:28-30')."""
        b_name = self.to_book_name or f"Livro {self.to_book_id}"
        if self.to_verse_start == self.to_verse_end or self.to_verse_end <= 0:
            return f"{b_name} {self.to_chapter}:{self.to_verse_start}"
        return f"{b_name} {self.to_chapter}:{self.to_verse_start}-{self.to_verse_end}"
