from __future__ import annotations

import re
from dataclasses import asdict, dataclass
from typing import Any


@dataclass
class SSQuarterly:
    """Representa um trimestre da Escola Sabatina (ex: 3º Trimestre 2024)."""

    id: str
    title: str
    description: str = ""
    human_date: str = ""
    start_date: str = ""
    end_date: str = ""
    cover: str = ""
    category: str = "adultos"  # "adultos" ou "jovens"

    @classmethod
    def from_dict(cls, data: dict[str, Any], default_category: str = "adultos") -> SSQuarterly:
        qid = str(data.get("id") or "")
        title = str(data.get("title") or "")
        
        # Dedução da categoria com base no id ou título
        category = default_category
        lid = qid.lower()
        ltitle = title.lower()
        if "cq" in lid or "jovem" in ltitle or "jovens" in lid:
            category = "jovens"
        elif "portugal" not in ltitle and "-pt" not in lid:
            category = "adultos"

        return cls(
            id=qid,
            title=title,
            description=str(data.get("description") or ""),
            human_date=str(data.get("human_date") or ""),
            start_date=str(data.get("start_date") or ""),
            end_date=str(data.get("end_date") or ""),
            cover=str(data.get("cover") or ""),
            category=data.get("category") or category,
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SSLesson:
    """Representa uma lição semanal da Escola Sabatina."""

    id: str
    quarterly_id: str
    index: str = ""
    title: str = ""
    start_date: str = ""
    end_date: str = ""
    cover: str = ""
    path: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any], quarterly_id: str = "") -> SSLesson:
        raw_index = str(data.get("index") or "").strip()
        raw_id = str(data.get("id") or "").strip()
        clean_idx = raw_index
        if raw_id.isdigit():
            clean_idx = str(int(raw_id))
        elif "-" in raw_index:
            m = re.search(r"(\d+)$", raw_index)
            if m:
                clean_idx = str(int(m.group(1)))
        elif raw_index.isdigit():
            clean_idx = str(int(raw_index))

        return cls(
            id=raw_id,
            quarterly_id=str(data.get("quarterly_id") or quarterly_id),
            index=clean_idx or raw_index,
            title=str(data.get("title") or ""),
            start_date=str(data.get("start_date") or ""),
            end_date=str(data.get("end_date") or ""),
            cover=str(data.get("cover") or ""),
            path=str(data.get("path") or ""),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SSDay:
    """Representa o estudo diário de uma lição (ex: Domingo, Segunda...)."""

    id: str
    lesson_id: str
    index: str = ""
    title: str = ""
    date: str = ""
    content: str = ""
    read_path: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any], lesson_id: str = "") -> SSDay:
        return cls(
            id=str(data.get("id") or ""),
            lesson_id=str(data.get("lesson_id") or lesson_id),
            index=str(data.get("index") or ""),
            title=str(data.get("title") or ""),
            date=str(data.get("date") or ""),
            content=str(data.get("content") or ""),
            read_path=str(data.get("read_path") or ""),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class SSUserNote:
    """Representa uma anotação pessoal feita pelo usuário em um dia de estudo."""

    day_id: str
    note_text: str
    updated_at: str = ""

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> SSUserNote:
        return cls(
            day_id=str(data.get("day_id") or ""),
            note_text=str(data.get("note_text") or ""),
            updated_at=str(data.get("updated_at") or ""),
        )

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

