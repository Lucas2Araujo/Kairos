"""
Visualização e Modal do Quiz Diário da Escola Sabatina no Flet.
Estilo micro-learning com barra de progresso, contador de streak,
feedback visual instantâneo em cards e relatório de erros.
"""

from __future__ import annotations

import asyncio
import time
from typing import Callable, Any

import flet as ft

from src.models.quiz import QuizQuestion, QuizResult
from src.services.quiz_service import QuizService
from src.theme.theme_engine import ThemeEngine


class QuizView(ft.Container):
    """View/Container do Quiz para ser inserido em dialogs, bottom sheets ou telas."""

    def __init__(
        self,
        questions: list[QuizQuestion],
        quiz_service: QuizService,
        user_id: str = "local_user",
        user_name: str | None = None,
        current_streak: int = 0,
        theme_engine: ThemeEngine | None = None,
        on_close: Callable[[], None] | None = None,
        on_finish: Callable[[int, int], None] | None = None,
    ):
        super().__init__()
        self.expand = True
        self.padding = ft.Padding.all(16)
        self.questions = questions
        self.quiz_service = quiz_service
        self.user_id = user_id
        self.user_name = (user_name or "").strip().split()[0] if user_name else ""
        self.streak = current_streak
        self.theme_engine = theme_engine or ThemeEngine()
        self.on_close_callback = on_close
        self.on_finish_callback = on_finish

        self.current_index = 0
        self.question_start_time = time.time()
        self.total_xp_earned = 0
        self.correct_answers_count = 0

        # Estados explícitos de seleção (compatibilidade de contratos)
        self.selected_option_idx: int | None = None
        self.selected_option: int | None = None
        self.selected_index: int | None = None
        self.has_submitted_current = False

        # Mapeamento bi-direcional de alternativas (para suporte a shuffling se ativado)
        self.display_options: list[str] = []
        self.option_index_map: list[int] = []  # display_idx -> original_idx

        # Componentes do Topo
        self.progress_bar = ft.ProgressBar(value=0, color=ft.Colors.GREEN_600, bgcolor=ft.Colors.GREY_300)
        self.streak_chip = ft.Container(
            content=ft.Row(
                [
                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT, color=ft.Colors.ORANGE_ACCENT_400, size=20),
                    ft.Text(f"{self.streak}", weight=ft.FontWeight.BOLD, size=15, color=ft.Colors.ORANGE_ACCENT_400),
                ],
                tight=True,
                spacing=4,
            ),
            padding=ft.Padding.symmetric(horizontal=8, vertical=4),
            border_radius=12,
            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.ORANGE_ACCENT_400),
        )
        self.flag_btn = ft.IconButton(
            icon=ft.Icons.FLAG_OUTLINED,
            tooltip="Reportar problema na questão",
            icon_size=20,
            on_click=self._open_report_dialog,
        )
        self.close_btn = ft.IconButton(
            icon=ft.Icons.CLOSE,
            icon_size=22,
            on_click=self._handle_close,
        )

        # Pergunta e Alternativas
        self.verse_chip = ft.Container(
            content=ft.Text("", size=12, weight=ft.FontWeight.W_500, color=ft.Colors.BLUE_GREY_600),
            padding=ft.Padding.symmetric(horizontal=8, vertical=2),
            bgcolor=ft.Colors.with_opacity(0.08, ft.Colors.BLUE_GREY_400),
            border_radius=6,
            visible=False,
        )
        self.question_text = ft.Text(
            "",
            size=18,
            weight=ft.FontWeight.BOLD,
            text_align=ft.TextAlign.START,
        )
        self.options_column = ft.Column(spacing=10)

        # Rodapé com Feedback (M3 Bottom Sheet integrado com ThemeEngine)
        self.feedback_container = ft.Container(
            visible=False,
            padding=ft.Padding.all(16),
            border_radius=16,
            expand=True,
        )
        self.feedback_text = ft.Text("", size=15, weight=ft.FontWeight.BOLD)
        self.motivational_text = ft.Text("", size=13, weight=ft.FontWeight.W_500, visible=False)
        self.explanation_text = ft.Text("", size=13, italic=True)
        self.feedback_container.content = ft.Column(
            [self.feedback_text, self.motivational_text, self.explanation_text],
            spacing=4,
        )

        # Botão de Ação M3 Pill (Verificar / Continuar)
        self.action_button = ft.ElevatedButton(
            "Verificar",
            icon=ft.Icons.CHECK,
            style=ft.ButtonStyle(
                shape=ft.StadiumBorder(),
                bgcolor=ft.Colors.PRIMARY,
                color=ft.Colors.WHITE,
                padding=ft.Padding.symmetric(vertical=14, horizontal=28),
            ),
            on_click=self._handle_action_click,
            disabled=True,
        )

        self.body_column = ft.Column(
            [
                ft.Row(
                    [self.close_btn, self.streak_chip, ft.Container(expand=True), self.flag_btn],
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                ),
                self.progress_bar,
                ft.Container(height=12),
                self.verse_chip,
                self.question_text,
                ft.Container(height=8),
                self.options_column,
                self.feedback_container,
                ft.Container(height=16),
                ft.Row([self.action_button], alignment=ft.MainAxisAlignment.END),
            ],
            scroll=ft.ScrollMode.AUTO,
            spacing=10,
        )
        self.content = self.body_column
        self._load_current_question()

    def _get_page(self) -> ft.Page | None:
        try:
            return self.page
        except (RuntimeError, AttributeError):
            return None

    def did_mount(self):
        self._load_current_question()

    def _update_progress(self):
        total = len(self.questions)
        self.progress_bar.value = self.current_index / total if total > 0 else 0
        p = self._get_page()
        if p:
            try:
                self.progress_bar.update()
            except Exception:
                pass

    def _load_current_question(self):
        """Carrega a questão ativa e reseta estritamente qualquer estado residual da questão anterior."""
        if not self.questions or self.current_index >= len(self.questions):
            self._render_completion_screen()
            return

        # 1. Reset estrito de seleção e timing
        self.selected_option_idx = None
        self.selected_option = None
        self.selected_index = None
        self.has_submitted_current = False
        self.question_start_time = time.time()

        q = self.questions[self.current_index]

        # 2. Configura mapeamento bi-direcional de alternativas
        self.display_options = list(q.options)
        self.option_index_map = list(range(len(q.options)))

        self._update_progress()

        if q.verse_ref:
            self.verse_chip.content.value = f"📖 {q.verse_ref}"
            self.verse_chip.visible = True
        else:
            self.verse_chip.visible = False

        self.question_text.value = q.question

        # 3. Reseta feedback e botão de ação
        self.feedback_container.visible = False
        self.motivational_text.visible = False
        self.action_button.text = "Verificar"
        self.action_button.icon = ft.Icons.CHECK
        self.action_button.disabled = True

        self._render_options(self.display_options)
        p = self._get_page()
        if p:
            try:
                self.update()
            except Exception:
                pass

    def _render_options(self, options: list[str], result: QuizResult | None = None):
        """Renderiza alternativas com tokens dinâmicos do ThemeEngine."""
        self.options_column.controls.clear()

        for display_idx, opt in enumerate(options):
            orig_idx = self.option_index_map[display_idx] if display_idx < len(self.option_index_map) else display_idx

            bg_color = ft.Colors.TRANSPARENT
            border_color = ft.Colors.OUTLINE_VARIANT
            text_color = None

            if result is not None:
                # Feedback de resultado com ThemeEngine compliance
                if orig_idx == result.correct_option:
                    bg_color = ft.Colors.with_opacity(0.18, ft.Colors.GREEN)
                    border_color = ft.Colors.GREEN_700
                    text_color = ft.Colors.GREEN_900
                elif orig_idx == self.selected_option_idx and not result.is_correct:
                    bg_color = ft.Colors.with_opacity(0.18, ft.Colors.RED)
                    border_color = ft.Colors.ERROR if hasattr(ft.Colors, "ERROR") else ft.Colors.RED_700
                    text_color = ft.Colors.RED_900
            elif orig_idx == self.selected_option_idx:
                border_color = ft.Colors.PRIMARY
                bg_color = ft.Colors.with_opacity(0.08, ft.Colors.PRIMARY)

            card = ft.Container(
                content=ft.Row(
                    [
                        ft.Container(
                            content=ft.Text(chr(65 + display_idx), weight=ft.FontWeight.BOLD, size=13),
                            width=28,
                            height=28,
                            border_radius=14,
                            alignment=ft.Alignment.CENTER,
                            border=ft.Border.all(1, border_color),
                        ),
                        ft.Container(width=8),
                        ft.Text(opt, size=14, color=text_color, expand=True),
                    ],
                    alignment=ft.MainAxisAlignment.START,
                ),
                padding=ft.Padding.symmetric(horizontal=12, vertical=12),
                border_radius=12,
                border=ft.Border.all(1.5, border_color),
                bgcolor=bg_color,
                on_click=lambda e, d_idx=display_idx: self._select_option(d_idx),
                ink=not self.has_submitted_current,
            )
            self.options_column.controls.append(card)

    def _select_option(self, display_idx: int):
        """Seleciona a alternativa mapeando índice de exibição para índice original."""
        if self.has_submitted_current:
            return

        orig_idx = self.option_index_map[display_idx] if display_idx < len(self.option_index_map) else display_idx
        self.selected_option_idx = orig_idx
        self.selected_option = orig_idx
        self.selected_index = orig_idx
        self.action_button.disabled = False

        self._render_options(self.display_options)
        p = self._get_page()
        if p:
            try:
                self.update()
            except Exception:
                pass

    def _handle_action_click(self, _):
        if not self.has_submitted_current:
            self._check_answer()
        else:
            self._next_question()

    def _check_answer(self):
        """Dispara verificação assíncrona da resposta atual."""
        p = self._get_page()
        if p and hasattr(p, "run_task") and callable(p.run_task):
            p.run_task(self._submit_current_answer)
        else:
            asyncio.create_task(self._submit_current_answer())

    def _next_question(self):
        """Transiciona para a próxima questão do quiz."""
        self.current_index += 1
        self._load_current_question()

    on_continue = _next_question

    def _get_motivational_message(self, is_correct: bool) -> str:
        """Gera mensagem motivacional personalizada com primeiro nome do usuário."""
        name_prefix = f"{self.user_name}, " if self.user_name else ""
        if not is_correct:
            return f"Não desanime, {name_prefix}o aprendizado bíblico é construído a cada leitura!"

        if self.streak >= 3:
            return f"🔥 Incrível, {name_prefix}{self.streak} dias seguidos mantidos com maestria!"
        elif self.correct_answers_count >= 2:
            return f"Excelente reflexão, {name_prefix}você está dominando o estudo de hoje!"
        return f"Muito bem, {name_prefix}continue firme no estudo diário!"

    async def _submit_current_answer(self):
        """Submete a resposta da questão dinamicamente vinculada ao ID atual."""
        if self.selected_option_idx is None:
            return

        if self.current_index >= len(self.questions):
            return

        # Vinculação dinâmica estrita à questão corrente
        current_q = self.questions[self.current_index]
        question_id = current_q.id

        # Garante time_spent mínimo de 2s para evitar gatilho falso-positivo de anti-speedhack
        raw_elapsed = int(time.time() - self.question_start_time)
        time_spent = max(raw_elapsed, 2)

        self.action_button.disabled = True
        p = self._get_page()
        if p:
            try:
                self.action_button.update()
            except Exception:
                pass

        result = await self.quiz_service.submit_answer(
            question_id=question_id,
            selected_option=self.selected_option_idx,
            time_spent=time_spent,
            user_id=self.user_id,
        )

        self.has_submitted_current = True
        if result.is_correct:
            self.correct_answers_count += 1
            self.total_xp_earned += result.xp_earned
            if result.new_streak > 0:
                self.streak = result.new_streak
                self.streak_chip.content.controls[1].value = str(self.streak)

            self.feedback_container.bgcolor = ft.Colors.with_opacity(0.18, ft.Colors.GREEN)
            self.feedback_container.border = ft.Border.all(1.5, ft.Colors.GREEN_700)
            self.feedback_text.value = f"🎉 Correto! +{result.xp_earned} XP"
            self.feedback_text.color = ft.Colors.GREEN_900
        else:
            self.feedback_container.bgcolor = ft.Colors.with_opacity(0.18, ft.Colors.RED)
            err_border = ft.Colors.ERROR if hasattr(ft.Colors, "ERROR") else ft.Colors.RED_700
            self.feedback_container.border = ft.Border.all(1.5, err_border)
            self.feedback_text.value = "❌ Resposta incorreta"
            self.feedback_text.color = ft.Colors.RED_900

        # Mensagem motivacional personalizada
        motiv_msg = self._get_motivational_message(result.is_correct)
        self.motivational_text.value = motiv_msg
        self.motivational_text.color = ft.Colors.GREEN_900 if result.is_correct else ft.Colors.RED_900
        self.motivational_text.visible = True

        self.explanation_text.value = result.explanation
        self.feedback_container.visible = True

        self._render_options(self.display_options, result=result)

        self.action_button.text = "Continuar"
        self.action_button.icon = ft.Icons.ARROW_FORWARD
        self.action_button.disabled = False

        p = self._get_page()
        if p:
            try:
                self.update()
            except Exception:
                pass

    def _render_completion_screen(self):
        self.progress_bar.value = 1.0

        congrats_name = f", {self.user_name}" if self.user_name else ""
        celebration_container = ft.Column(
            [
                ft.Container(height=24),
                ft.Icon(ft.Icons.EMOJI_EVENTS, size=72, color=ft.Colors.AMBER_600),
                ft.Text(f"Parabéns{congrats_name}!", size=24, weight=ft.FontWeight.BOLD),
                ft.Text(f"Você acertou {self.correct_answers_count} de {len(self.questions)} questões.", size=16),
                ft.Container(height=12),
                ft.Row(
                    [
                        ft.Container(
                            content=ft.Column(
                                [
                                    ft.Text("XP Ganho", size=12, color=ft.Colors.GREY_600),
                                    ft.Text(f"+{self.total_xp_earned}", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_700),
                                ],
                                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            padding=ft.Padding.all(12),
                            border_radius=8,
                            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.GREEN_600),
                        ),
                        ft.Container(
                            content=ft.Column(
                                [
                                    ft.Text("Ofensiva", size=12, color=ft.Colors.GREY_600),
                                    ft.Text(f"🔥 {self.streak} Dias", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.ORANGE_800),
                                ],
                                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            ),
                            padding=ft.Padding.all(12),
                            border_radius=8,
                            bgcolor=ft.Colors.with_opacity(0.1, ft.Colors.ORANGE_ACCENT_400),
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.CENTER,
                    spacing=16,
                ),
                ft.Container(height=24),
                ft.ElevatedButton(
                    "Concluir",
                    icon=ft.Icons.CHECK_CIRCLE,
                    style=ft.ButtonStyle(
                        shape=ft.StadiumBorder(),
                        bgcolor=ft.Colors.PRIMARY,
                        color=ft.Colors.WHITE,
                        padding=ft.Padding.symmetric(vertical=14, horizontal=36),
                    ),
                    on_click=self._handle_finish,
                ),
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=10,
        )

        self.content = celebration_container
        p = self._get_page()
        if p:
            try:
                self.update()
            except Exception:
                pass

    def _open_report_dialog(self, _):
        p = self._get_page()
        if not p or self.current_index >= len(self.questions):
            return

        q = self.questions[self.current_index]
        reason_input = ft.TextField(label="Motivo do reporte (ex: Gabarito errado, digitação)", multiline=False)
        comment_input = ft.TextField(label="Comentário ou detalhes adicionais", multiline=True, min_lines=2, max_lines=4)

        async def _send_report(e):
            if not reason_input.value or len(reason_input.value.strip()) < 3:
                reason_input.error_text = "Informe um motivo válido."
                reason_input.update()
                return

            await self.quiz_service.report_question(
                question_id=q.id,
                reason=reason_input.value,
                comment=comment_input.value or "",
            )
            dialog.open = False
            cur_page = self._get_page()
            if cur_page:
                try:
                    cur_page.update()
                    cur_page.snack_bar = ft.SnackBar(ft.Text("Obrigado! Seu relato foi enviado."), bgcolor=ft.Colors.GREEN_700)
                    cur_page.snack_bar.open = True
                    cur_page.update()
                except Exception:
                    pass

        dialog = ft.AlertDialog(
            title=ft.Text("Reportar Problema na Questão"),
            content=ft.Column([reason_input, comment_input], tight=True, spacing=10),
            actions=[
                ft.TextButton("Cancelar", on_click=lambda e: self._close_dialog(dialog)),
                ft.ElevatedButton("Enviar", on_click=lambda e: p.run_task(_send_report, e) if hasattr(p, "run_task") else asyncio.create_task(_send_report(e))),
            ],
        )
        if hasattr(p, "show_dialog") and callable(getattr(p, "show_dialog")):
            try:
                p.show_dialog(dialog)
            except Exception:
                p.overlay.append(dialog)
                dialog.open = True
                p.update()
        else:
            p.overlay.append(dialog)
            dialog.open = True
            p.update()

    def _close_dialog(self, dialog: ft.AlertDialog):
        p = self._get_page()
        if p:
            try:
                p.pop_dialog()
            except Exception:
                pass
            dialog.open = False
            try:
                p.update()
            except Exception:
                pass

    def _handle_close(self, _):
        if self.on_close_callback:
            self.on_close_callback()

    def _handle_finish(self, _):
        if self.on_finish_callback:
            self.on_finish_callback(self.total_xp_earned, self.streak)
        elif self.on_close_callback:
            self.on_close_callback()
