from dataclasses import dataclass


@dataclass(frozen=True)
class Pericope:
    """
    DTO imutável representando um título de seção / perícope bíblica.
    """

    book_id: int
    chapter: int
    verse: int
    title: str
