from __future__ import annotations

from typing import Any
from pydantic import BaseModel, Field, field_validator


class QuizQuestion(BaseModel):
    """Modelo público de pergunta entregue ao cliente mobile.
    Nunca expõe a resposta correta para evitar trapaças/inspeção de tráfego.
    """
    id: str
    day_id: str
    quarterly_id: str
    category: str = "adultos"
    question: str
    options: list[str] = Field(..., min_length=4, max_length=4)
    verse_ref: str | None = None
    created_at: str | None = None

    @field_validator("options")
    @classmethod
    def validate_options_count(cls, v: list[str]) -> list[str]:
        if len(v) != 4:
            raise ValueError("Cada pergunta deve conter exatamente 4 alternativas.")
        for opt in v:
            if not opt.strip():
                raise ValueError("Nenhuma alternativa pode ser vazia.")
        return v


class QuizQuestionInternal(QuizQuestion):
    """Modelo interno para geração de IA e backend/scripts de carga."""
    correct_option: int = Field(..., ge=0, le=3)
    explanation: str

    def to_public(self) -> QuizQuestion:
        return QuizQuestion(
            id=self.id,
            day_id=self.day_id,
            quarterly_id=self.quarterly_id,
            category=self.category,
            question=self.question,
            options=self.options,
            verse_ref=self.verse_ref,
            created_at=self.created_at,
        )


class QuizAnswerSubmission(BaseModel):
    """Submissão de resposta pelo usuário."""
    question_id: str
    selected_option: int = Field(..., ge=0, le=3)
    time_spent: int = Field(..., description="Tempo em segundos gastos para responder.")


class QuizResult(BaseModel):
    """Resultado retornado ao cliente após submeter resposta."""
    is_correct: bool
    correct_option: int
    explanation: str
    xp_earned: int = 0
    new_streak: int = 0
    already_answered: bool = False
    message: str = ""


class QuizReport(BaseModel):
    """Denúncia ou relato de erro em questão."""
    question_id: str
    reason: str = Field(..., min_length=3, max_length=100)
    comment: str = Field(default="", max_length=500)

    @field_validator("reason", "comment")
    @classmethod
    def sanitize_text(cls, v: str) -> str:
        # Sanitização básica contra injection ou lixo
        cleaned = v.strip().replace("\x00", "")
        return cleaned


class UserQuizStats(BaseModel):
    """Estatísticas e gamificação do usuário."""
    user_id: str
    xp: int = 0
    current_streak: int = 0
    best_streak: int = 0
    last_quiz_date: str | None = None

