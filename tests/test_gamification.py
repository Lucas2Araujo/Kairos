"""Testes para src/utils/gamification."""
import pytest
from datetime import date, timedelta
from src.utils.gamification import calculate_streak, calculate_weekly_activity


class TestCalculateStreak:
    """Testes para cálculo de ofensiva unificada."""

    def test_empty_set_returns_zero(self):
        assert calculate_streak(set(), date(2024, 6, 15)) == 0

    def test_only_today(self):
        ref = date(2024, 6, 15)
        assert calculate_streak({ref.isoformat()}, ref) == 1

    def test_only_yesterday_keeps_streak(self):
        ref = date(2024, 6, 15)
        yesterday = (ref - timedelta(days=1)).isoformat()
        assert calculate_streak({yesterday}, ref) == 1

    def test_three_consecutive(self):
        ref = date(2024, 6, 15)
        dates = {(ref - timedelta(days=i)).isoformat() for i in range(3)}
        assert calculate_streak(dates, ref) == 3

    def test_gap_resets(self):
        ref = date(2024, 6, 15)
        dates = {
            ref.isoformat(),
            (ref - timedelta(days=3)).isoformat(),
        }
        assert calculate_streak(dates, ref) == 1

    @pytest.mark.parametrize(
        "days_back, expected",
        [(0, 1), (1, 2), (2, 3), (6, 7)],
    )
    def test_parametrized_streaks(self, days_back, expected):
        ref = date(2024, 6, 15)
        dates = {(ref - timedelta(days=i)).isoformat() for i in range(days_back + 1)}
        assert calculate_streak(dates, ref) == expected


class TestCalculateWeeklyActivity:
    """Testes para mapa semanal de atividade."""

    def test_length_is_seven(self):
        assert len(calculate_weekly_activity(set(), date(2024, 6, 15))) == 7

    def test_all_false_when_empty(self):
        assert not any(calculate_weekly_activity(set(), date(2024, 6, 15)))

    def test_active_day_marked(self):
        ref = date(2024, 6, 15)
        result = calculate_weekly_activity({ref.isoformat()}, ref)
        assert any(result)
        assert result.count(True) == 1
