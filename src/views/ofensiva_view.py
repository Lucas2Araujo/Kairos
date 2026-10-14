from __future__ import annotations

import asyncio
import calendar
from datetime import date
from typing import Any
import flet as ft

from src.services.reading_service import ReadingService
from src.services.theme_service import ThemeService
from src.theme.theme_engine import ThemeEngine


class OfensivaView:
    """Tela de ofensiva com calendário mensal e estatísticas de leitura."""

    def __init__(
        self,
        reading_service: ReadingService | None = None,
        theme_service: ThemeService | None = None,
        theme_engine: ThemeEngine | None = None,
    ):
        self.reading_service = reading_service
        self.theme_service = theme_service
        self.theme_engine = (
            theme_engine
            or getattr(theme_service, "theme_engine", None)
            or ThemeEngine()
        )
        today = date.today()
        self.current_year = today.year
        self.current_month = today.month

        self.streak_text: ft.Text | None = None
        self.best_streak_text: ft.Text | None = None
        self.total_days_text: ft.Text | None = None
        self.month_label: ft.Text | None = None
        self.calendar_grid: ft.Column | None = None
        self.activity_dates: set[str] = set()

    async def _load_data(self, page: ft.Page) -> None:
        if not self.reading_service:
            return

        dates, stats = await asyncio.gather(
            self.reading_service.get_all_activity_dates(),
            self.reading_service.get_unified_user_stats(),
        )
        self.activity_dates = dates

        if self.streak_text:
            self.streak_text.value = f"{stats.get('current_streak', 0)} dias"
        if self.best_streak_text:
            self.best_streak_text.value = f"{stats.get('best_streak', 0)} dias"
        if self.total_days_text:
            self.total_days_text.value = f"{len(dates)} dias"

        self._render_month_grid()
        try:
            page.update()
        except Exception:
            pass

    def _render_month_grid(self) -> None:
        if not self.calendar_grid:
            return

        palette = self.theme_engine.get_current_palette()
        accent = palette.primary
        month_names = [
            "", "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
            "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
        ]
        if self.month_label:
            self.month_label.value = f"{month_names[self.current_month]} {self.current_year}"

        today = date.today()
        cal = calendar.monthcalendar(self.current_year, self.current_month)

        rows: list[ft.Control] = []
        for week in cal:
            week_controls: list[ft.Control] = []
            for day in week:
                if day == 0:
                    week_controls.append(ft.Container(expand=True))
                    continue

                day_iso = f"{self.current_year:04d}-{self.current_month:02d}-{day:02d}"
                has_read = day_iso in self.activity_dates
                is_today = (self.current_year == today.year and self.current_month == today.month and day == today.day)

                cell_content = ft.Column(
                    controls=[
                        ft.Icon(
                            ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED if has_read else ft.Icons.CIRCLE,
                            size=14 if has_read else 4,
                            color=ft.Colors.ORANGE_ACCENT_400 if has_read else ft.Colors.TRANSPARENT,
                        ),
                        ft.Text(
                            str(day),
                            size=12,
                            weight=ft.FontWeight.BOLD if is_today or has_read else ft.FontWeight.NORMAL,
                            color=palette.text_primary if (has_read or is_today) else palette.text_secondary,
                        ),
                    ],
                    spacing=2,
                    alignment=ft.MainAxisAlignment.CENTER,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                )

                week_controls.append(
                    ft.Container(
                        content=cell_content,
                        height=42,
                        border_radius=10,
                        bgcolor=ft.Colors.with_opacity(0.15, accent) if has_read else (
                            palette.surface_container_high if not is_today else ft.Colors.TRANSPARENT
                        ),
                        border=ft.Border.all(1.5, accent if is_today else ft.Colors.TRANSPARENT),
                        alignment=ft.Alignment.CENTER,
                        expand=True,
                    )
                )

            rows.append(ft.Row(controls=week_controls, spacing=6))

        self.calendar_grid.controls = rows

    def _change_month(self, offset: int, page: ft.Page) -> None:
        self.current_month += offset
        if self.current_month < 1:
            self.current_month = 12
            self.current_year -= 1
        elif self.current_month > 12:
            self.current_month = 1
            self.current_year += 1

        self._render_month_grid()
        try:
            page.update()
        except Exception:
            pass

    def build(self, page: ft.Page) -> ft.View:
        palette = self.theme_engine.get_current_palette()
        accent = palette.primary

        self.streak_text = ft.Text("0 dias", size=24, weight=ft.FontWeight.BOLD, color=palette.text_primary)
        self.best_streak_text = ft.Text("0 dias", size=14, weight=ft.FontWeight.BOLD, color=palette.text_primary)
        self.total_days_text = ft.Text("0 dias", size=14, weight=ft.FontWeight.BOLD, color=palette.text_primary)
        self.month_label = ft.Text("", size=16, weight=ft.FontWeight.BOLD, color=palette.text_primary)
        self.calendar_grid = ft.Column(spacing=6)

        header_card = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=36, color=ft.Colors.ORANGE_ACCENT_400),
                            ft.Column(
                                controls=[
                                    ft.Text("OFENSIVA ATUAL", size=11, weight=ft.FontWeight.BOLD, color=palette.text_secondary),
                                    self.streak_text,
                                ],
                                spacing=2,
                            ),
                        ],
                        spacing=12,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    ft.Divider(height=16, color=ft.Colors.with_opacity(0.1, palette.text_secondary)),
                    ft.Row(
                        controls=[
                            ft.Column(
                                controls=[
                                    ft.Text("🏆 Recorde", size=11, color=palette.text_secondary),
                                    self.best_streak_text,
                                ],
                                spacing=2,
                            ),
                            ft.Column(
                                controls=[
                                    ft.Text("📅 Total Lido", size=11, color=palette.text_secondary),
                                    self.total_days_text,
                                ],
                                spacing=2,
                            ),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_AROUND,
                    ),
                ],
                spacing=8,
            ),
            bgcolor=palette.surface_container_high,
            border_radius=16,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.18, accent)),
            padding=ft.Padding.all(16),
        )

        weekday_labels = ["D", "S", "T", "Q", "Q", "S", "S"]
        weekday_row = ft.Row(
            controls=[
                ft.Container(
                    content=ft.Text(d, size=11, weight=ft.FontWeight.BOLD, color=palette.text_secondary),
                    alignment=ft.Alignment.CENTER,
                    expand=True,
                )
                for d in weekday_labels
            ],
            spacing=6,
        )

        calendar_card = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Row(
                        controls=[
                            ft.IconButton(ft.Icons.CHEVRON_LEFT, on_click=lambda e: self._change_month(-1, page)),
                            self.month_label,
                            ft.IconButton(ft.Icons.CHEVRON_RIGHT, on_click=lambda e: self._change_month(1, page)),
                        ],
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    ),
                    weekday_row,
                    ft.Container(height=4),
                    self.calendar_grid,
                ],
                spacing=8,
            ),
            bgcolor=palette.surface_container_high,
            border_radius=16,
            border=ft.Border.all(1.0, ft.Colors.with_opacity(0.12, palette.text_secondary)),
            padding=ft.Padding.all(16),
        )

        content = ft.Column(
            controls=[
                header_card,
                ft.Container(height=8),
                calendar_card,
            ],
            spacing=8,
            scroll=ft.ScrollMode.AUTO,
        )

        self._render_month_grid()
        page.run_task(self._load_data, page)

        return ft.View(
            route="/ofensiva",
            bgcolor=palette.background,
            appbar=ft.AppBar(
                leading=ft.IconButton(
                    ft.Icons.ARROW_BACK,
                    on_click=lambda e: asyncio.create_task(page.push_route("/")),
                ),
                title=ft.Text("Progresso e Ofensiva", weight=ft.FontWeight.BOLD),
                center_title=True,
                bgcolor=palette.surface,
            ),
            controls=[
                ft.SafeArea(
                    content=ft.Container(content=content, padding=ft.Padding.all(16)),
                    expand=True,
                )
            ],
        )

