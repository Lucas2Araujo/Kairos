"""Funções puras de cálculo de gamificação e ofensiva (streak)."""
from __future__ import annotations

from datetime import date, timedelta


def calculate_streak(activity_dates: set[str], reference_date: date | None = None) -> int:
    """Calcula a ofensiva (dias consecutivos) a partir de um conjunto de datas ISO.
    
    Regras:
    - Se completou hoje, conta hoje e volta dia a dia.
    - Se não completou hoje mas completou ontem, a ofensiva continua.
    - Se não completou hoje nem ontem, streak = 0.
    """
    today = reference_date or date.today()
    yesterday = today - timedelta(days=1)
    today_iso = today.isoformat()
    yesterday_iso = yesterday.isoformat()

    if today_iso not in activity_dates and yesterday_iso not in activity_dates:
        return 0

    start = today if today_iso in activity_dates else yesterday
    streak = 0
    check = start
    while check.isoformat() in activity_dates:
        streak += 1
        check -= timedelta(days=1)
    return streak


def calculate_weekly_activity(
    activity_dates: set[str], reference_date: date | None = None
) -> list[bool]:
    """Retorna lista de 7 bools (Dom-Sáb) indicando atividade na semana corrente."""
    today = reference_date or date.today()
    sunday = today - timedelta(days=(today.weekday() + 1) % 7)
    return [(sunday + timedelta(days=i)).isoformat() in activity_dates for i in range(7)]
