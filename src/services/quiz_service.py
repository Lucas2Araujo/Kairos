from __future__ import annotations

import asyncio
import json
import logging
import sqlite3
from datetime import datetime, date, timezone

from src.utils.gamification import calculate_streak, calculate_weekly_activity
from typing import Any

from src.models.quiz import (
    QuizQuestion,
    QuizQuestionInternal,
    QuizResult,
    QuizReport,
    UserQuizStats,
)

logger = logging.getLogger(__name__)


def normalize_quiz_category(category: str) -> tuple[str, str]:
    """Retorna tupla (domain_category, db_category) para compatibilidade entre SQLite e Supabase.
    - domain_category: 'jovens' ou 'adultos'
    - db_category: 'jovem' ou 'adultos'
    """
    cat = (category or "").strip().lower()
    if cat in ("jovens", "jovem"):
        return ("jovens", "jovem")
    return ("adultos", "adultos")


def generate_dev_mock_questions(day_id: str, category: str = "adultos") -> list[QuizQuestionInternal]:
    """Gera questões de teste para visualização em modo de desenvolvimento."""
    domain_cat, _ = normalize_quiz_category(category)
    cat_label = "Jovens" if domain_cat == "jovens" else "Adultos"
    return [
        QuizQuestionInternal(
            id=f"dev_mock_{day_id}_1",
            day_id=day_id,
            quarterly_id="dev_quarterly",
            category=domain_cat,
            question=f"[DEV {cat_label}] Qual o tema central e objetivo de reflexão para o estudo do dia {day_id}?",
            options=[
                "Aprofundar a compreensão das Escrituras e aplicar a fé à rotina diária.",
                "Realizar leituras teóricas sem conexão com o crescimento espiritual prático.",
                "Memorizar apenas genealogias históricas sem reflexão ética.",
                "Substituir o estudo individual por conclusões puramente humanas.",
            ],
            correct_option=0,
            explanation="O estudo bíblico da Escola Sabatina busca conectar as revelações das Escrituras com a transformação e maturidade do caráter.",
            verse_ref="2 Timóteo 3:16-17",
        ),
        QuizQuestionInternal(
            id=f"dev_mock_{day_id}_2",
            day_id=day_id,
            quarterly_id="dev_quarterly",
            category=domain_cat,
            question=f"[DEV {cat_label}] Como o cristão deve responder aos desafios apresentados na lição?",
            options=[
                "Com apatia e distanciamento das necessidades comunitárias.",
                "Com oração fervorosa, busca ao Espírito Santo e testemunho ativo.",
                "Buscando soluções unicamente individuais sem discernimento bíblico.",
                "Ignorando os conselhos proféticos em tempos de incerteza.",
            ],
            correct_option=1,
            explanation="A perseverança na fé cristã fundamenta-se na comunhão viva com Deus e no testemunho compassivo aos semelhantes.",
            verse_ref="Tiago 1:5",
        ),
    ]


class QuizService:
    """Serviço de gerenciamento de Quizzes e Gamificação.
    Suporta operação online via Supabase (v_ss_questions_public) e fallback offline via SQLite local.
    Implementa travas de segurança (anti-speedhack, sanitização de reports)
    e proteção contra vazamento do gabarito para o frontend.
    """

    def __init__(self, db_path: str | None = None, supabase_client: Any = None):
        if db_path is None:
            from src.database.connection import DatabaseConnection
            self.db_path = DatabaseConnection._resolve_db_path("hinario.db")
        else:
            self.db_path = db_path
        self._supabase = supabase_client
        self._initialized = False

    def _get_connection(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    async def init_db(self) -> None:
        """Cria as tabelas locais no SQLite se não existirem."""
        def _sync_init():
            with self._get_connection() as conn:
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS ss_questions_cache (
                        id TEXT PRIMARY KEY,
                        day_id TEXT NOT NULL,
                        quarterly_id TEXT NOT NULL,
                        category TEXT NOT NULL,
                        question TEXT NOT NULL,
                        options_json TEXT NOT NULL,
                        correct_option INTEGER NOT NULL,
                        explanation TEXT,
                        verse_ref TEXT,
                        created_at TEXT
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS user_quiz_answers (
                        question_id TEXT NOT NULL,
                        user_id TEXT NOT NULL,
                        selected_option INTEGER NOT NULL,
                        is_correct INTEGER NOT NULL,
                        time_spent INTEGER NOT NULL,
                        created_at TEXT NOT NULL,
                        PRIMARY KEY (question_id, user_id)
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS user_quiz_stats (
                        user_id TEXT PRIMARY KEY,
                        xp INTEGER DEFAULT 0,
                        current_streak INTEGER DEFAULT 0,
                        best_streak INTEGER DEFAULT 0,
                        last_quiz_date TEXT
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS quiz_reports (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        question_id TEXT NOT NULL,
                        reason TEXT NOT NULL,
                        comment TEXT,
                        created_at TEXT NOT NULL
                    )
                """)
                conn.execute("""
                    CREATE TABLE IF NOT EXISTS user_gamification (
                        user_id TEXT PRIMARY KEY,
                        total_xp INTEGER DEFAULT 0,
                        current_streak INTEGER DEFAULT 0,
                        best_streak INTEGER DEFAULT 0,
                        last_activity_date TEXT,
                        last_devotional_xp_date TEXT
                    )
                """)
                conn.commit()

        await asyncio.to_thread(_sync_init)
        self._initialized = True

    async def save_question_to_cache(self, question: QuizQuestionInternal) -> None:
        """Salva ou atualiza uma pergunta no cache local (idempotente)."""
        if not self._initialized:
            await self.init_db()

        domain_cat, _ = normalize_quiz_category(question.category)

        def _sync_save():
            with self._get_connection() as conn:
                conn.execute("""
                    INSERT INTO ss_questions_cache (
                        id, day_id, quarterly_id, category, question,
                        options_json, correct_option, explanation, verse_ref, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        question=excluded.question,
                        options_json=excluded.options_json,
                        correct_option=excluded.correct_option,
                        explanation=excluded.explanation,
                        verse_ref=excluded.verse_ref
                """, (
                    question.id,
                    question.day_id,
                    question.quarterly_id,
                    domain_cat,
                    question.question,
                    json.dumps(question.options, ensure_ascii=False),
                    question.correct_option,
                    question.explanation,
                    question.verse_ref,
                    question.created_at or datetime.now(timezone.utc).isoformat(),
                ))
                conn.commit()

        await asyncio.to_thread(_sync_save)

    async def get_daily_quiz(self, day_id: str, category: str = "adultos") -> list[QuizQuestion]:
        """Obtém as perguntas do dia com diagnóstico verbose e seed de fallback no desenvolvimento.
        1. Consulta Supabase na view pública `v_ss_questions_public` (segura, sem gabarito).
        2. Fallback para cache local SQLite (`ss_questions_cache`).
        3. Se ainda vazio em ambiente de desenvolvimento, gera seed mock rico para validação visual imediata.
        """
        if not self._initialized:
            await self.init_db()

        domain_cat, db_cat = normalize_quiz_category(category)
        logger.info(f"[QuizService] get_daily_quiz: day_id='{day_id}', category='{category}' (domain='{domain_cat}', db='{db_cat}')")

        # 1. Tentar Supabase online na view v_ss_questions_public
        if self._supabase:
            target_url = getattr(self._supabase, "supabase_url", "unknown_url")
            logger.info(f"[QuizService] Consultando Supabase em: {target_url} (tabela: v_ss_questions_public)")
            try:
                def _do_fetch():
                    return self._supabase.table("v_ss_questions_public")\
                        .select("id, day_id, quarterly_id, category, question, options, verse_ref, created_at")\
                        .eq("day_id", str(day_id))\
                        .in_("category", [domain_cat, db_cat])\
                        .execute()

                res = await asyncio.wait_for(asyncio.to_thread(_do_fetch), timeout=5.0)
                if res.data:
                    logger.info(f"[QuizService] ✓ Supabase retornou {len(res.data)} perguntas públicas.")
                    return [QuizQuestion(**item) for item in res.data]
                logger.warning(f"[QuizService] Supabase retornou 0 perguntas para day_id='{day_id}', category='{domain_cat}'.")
            except Exception as e:
                logger.info(f"[QuizService] Falha/Timeout na consulta online ao Supabase ({e}). Usando fallback local.")

        # 2. Fallback offline SQLite local
        logger.info(f"[QuizService] Verificando cache SQLite local (ss_questions_cache)...")
        def _sync_get():
            with self._get_connection() as conn:
                cursor = conn.execute("""
                    SELECT id, day_id, quarterly_id, category, question, options_json, verse_ref, created_at
                    FROM ss_questions_cache
                    WHERE day_id = ? AND category IN (?, ?)
                """, (str(day_id), domain_cat, db_cat))
                rows = cursor.fetchall()
                results = []
                for r in rows:
                    results.append(QuizQuestion(
                        id=r["id"],
                        day_id=r["day_id"],
                        quarterly_id=r["quarterly_id"],
                        category=r["category"],
                        question=r["question"],
                        options=json.loads(r["options_json"]),
                        verse_ref=r["verse_ref"],
                        created_at=r["created_at"],
                    ))
                return results

        cached_questions = await asyncio.to_thread(_sync_get)
        if cached_questions:
            logger.info(f"[QuizService] ✓ Cache SQLite retornou {len(cached_questions)} perguntas.")
            return cached_questions

        # 3. Seed Mock para desenvolvimento (evita tela em branco no teste visual do desktop)
        logger.info(f"[QuizService] ⚠️ Sem perguntas no Supabase ou Cache Local. Injetando dev mock para teste visual...")
        mock_questions = generate_dev_mock_questions(day_id=str(day_id), category=domain_cat)
        for mq in mock_questions:
            await self.save_question_to_cache(mq)

        logger.info(f"[QuizService] ✓ {len(mock_questions)} perguntas mock semeadas com sucesso no cache local.")
        return [mq.to_public() for mq in mock_questions]

    async def has_user_answered(self, question_id: str, user_id: str) -> bool:
        """Verifica se o usuário já respondeu a esta pergunta."""
        if not self._initialized:
            await self.init_db()

        def _sync_check():
            with self._get_connection() as conn:
                cur = conn.execute(
                    "SELECT 1 FROM user_quiz_answers WHERE question_id = ? AND user_id = ?",
                    (question_id, user_id)
                )
                return cur.fetchone() is not None

        return await asyncio.to_thread(_sync_check)

    async def submit_answer(
        self,
        question_id: str,
        selected_option: int,
        time_spent: int,
        user_id: str = "local_user"
    ) -> QuizResult:
        """Submete resposta da pergunta com:
        - Proteção Anti-Speedhack (< 2 segundos).
        - Execução de RPC 'submit_quiz_answer' no Supabase se autenticado.
        - Fallback com cálculo de XP e ofensiva (streak) no SQLite offline.
        """
        if not self._initialized:
            await self.init_db()

        logger.info(f"[QuizService] submit_answer: question_id='{question_id}', option={selected_option}, time_spent={time_spent}s, user='{user_id}'")

        # Trava Anti-Speedhack
        if time_spent < 2:
            logger.warning("[QuizService] Trava Anti-Speedhack ativada (< 2s).")
            return QuizResult(
                is_correct=False,
                correct_option=-1,
                explanation="Tempo insuficiente para leitura consciente da questão (mínimo 2s).",
                xp_earned=0,
                new_streak=0,
                message="Resposta muito rápida (possível speedhack detectado)."
            )

        # 1. Tentar RPC Supabase se disponível e autenticado
        if self._supabase:
            try:
                def _do_rpc():
                    return self._supabase.rpc("submit_quiz_answer", {
                        "p_question_id": question_id,
                        "p_selected_option": selected_option,
                        "p_time_spent": time_spent,
                    }).execute()

                rpc_res = await asyncio.wait_for(asyncio.to_thread(_do_rpc), timeout=5.0)
                if rpc_res.data:
                    logger.info("[QuizService] ✓ Resposta processada via RPC Supabase com sucesso.")
                    return QuizResult(**rpc_res.data)
            except Exception as e:
                logger.info(f"[QuizService] RPC online indisponível ou timeout ({e}). Processando validação offline no SQLite.")

        # 2. Validação Offline no SQLite
        def _sync_submit():
            with self._get_connection() as conn:
                cur = conn.execute(
                    "SELECT correct_option, explanation FROM ss_questions_cache WHERE id = ?",
                    (question_id,)
                )
                q_row = cur.fetchone()
                if not q_row:
                    logger.warning(f"[QuizService] Questão '{question_id}' não encontrada no cache SQLite.")
                    return QuizResult(
                        is_correct=False,
                        correct_option=-1,
                        explanation="",
                        message="Questão não encontrada no cache local."
                    )

                correct_option = q_row["correct_option"]
                explanation = q_row["explanation"] or ""
                is_correct = (selected_option == correct_option)

                cur_ans = conn.execute(
                    "SELECT 1 FROM user_quiz_answers WHERE question_id = ? AND user_id = ?",
                    (question_id, user_id)
                )
                already_answered = (cur_ans.fetchone() is not None)

                xp_earned = 0
                new_streak = 0

                if not already_answered:
                    conn.execute("""
                        INSERT INTO user_quiz_answers (
                            question_id, user_id, selected_option, is_correct, time_spent, created_at
                        ) VALUES (?, ?, ?, ?, ?, ?)
                    """, (
                        question_id, user_id, selected_option, 1 if is_correct else 0,
                        time_spent, datetime.now(timezone.utc).isoformat()
                    ))

                    if is_correct:
                        xp_earned = 10
                        cur_stats = conn.execute(
                            "SELECT xp, current_streak, best_streak, last_quiz_date FROM user_quiz_stats WHERE user_id = ?",
                            (user_id,)
                        )
                        stats_row = cur_stats.fetchone()
                        today_str = date.today().isoformat()

                        if stats_row:
                            current_xp = stats_row["xp"] + xp_earned
                            last_date = stats_row["last_quiz_date"]
                            curr_streak = stats_row["current_streak"]
                            best_strk = stats_row["best_streak"]

                            if last_date == today_str:
                                new_streak = curr_streak
                            else:
                                new_streak = curr_streak + 1
                                if new_streak > best_strk:
                                    best_strk = new_streak

                            conn.execute("""
                                UPDATE user_quiz_stats
                                SET xp = ?, current_streak = ?, best_streak = ?, last_quiz_date = ?
                                WHERE user_id = ?
                            """, (current_xp, new_streak, best_strk, today_str, user_id))
                        else:
                            new_streak = 1
                            conn.execute("""
                                INSERT INTO user_quiz_stats (user_id, xp, current_streak, best_streak, last_quiz_date)
                                VALUES (?, ?, 1, 1, ?)
                            """, (user_id, xp_earned, today_str))
                else:
                    cur_stats = conn.execute(
                        "SELECT current_streak FROM user_quiz_stats WHERE user_id = ?",
                        (user_id,)
                    )
                    st = cur_stats.fetchone()
                    new_streak = st["current_streak"] if st else 0

                conn.commit()
                logger.info(f"[QuizService] ✓ Validação offline concluída. Correto: {is_correct}, XP: {xp_earned}, Streak: {new_streak}")
                return QuizResult(
                    is_correct=is_correct,
                    correct_option=correct_option,
                    explanation=explanation,
                    xp_earned=xp_earned,
                    new_streak=new_streak,
                    already_answered=already_answered,
                    message="Acertou!" if is_correct else "Não foi dessa vez."
                )

        return await asyncio.to_thread(_sync_submit)

    async def report_question(self, question_id: str, reason: str, comment: str = "") -> bool:
        """Sanitiza e salva reporte de erro da questão."""
        if not self._initialized:
            await self.init_db()

        report = QuizReport(question_id=question_id, reason=reason, comment=comment)

        if self._supabase:
            try:
                def _do_insert_report():
                    return self._supabase.table("quiz_reports").insert({
                        "question_id": report.question_id,
                        "reason": report.reason,
                        "comment": report.comment,
                    }).execute()

                await asyncio.wait_for(asyncio.to_thread(_do_insert_report), timeout=5.0)
                logger.info("[QuizService] ✓ Denúncia enviada ao Supabase.")
                return True
            except Exception as e:
                logger.warning(f"[QuizService] Erro ou timeout ao enviar denúncia ao Supabase, salvando localmente: {e}")

        def _sync_report():
            with self._get_connection() as conn:
                conn.execute("""
                    INSERT INTO quiz_reports (question_id, reason, comment, created_at)
                    VALUES (?, ?, ?, ?)
                """, (
                    report.question_id,
                    report.reason,
                    report.comment,
                    datetime.now(timezone.utc).isoformat()
                ))
                conn.commit()
            return True

        return await asyncio.to_thread(_sync_report)

    async def get_user_stats(self, user_id: str = "local_user") -> UserQuizStats:
        """Retorna estatísticas de pontuação, XP e streak do usuário."""
        if not self._initialized:
            await self.init_db()

        if self._supabase:
            try:
                def _do_fetch_stats():
                    return self._supabase.table("user_quiz_stats").select("*").eq("user_id", user_id).single().execute()

                res = await asyncio.wait_for(asyncio.to_thread(_do_fetch_stats), timeout=5.0)
                if res.data:
                    return UserQuizStats(**res.data)
            except Exception as exc:
                logger.debug("Falha ao buscar stats do Supabase: %s", exc)

        def _sync_stats():
            with self._get_connection() as conn:
                cur = conn.execute(
                    "SELECT user_id, xp, current_streak, best_streak, last_quiz_date FROM user_quiz_stats WHERE user_id = ?",
                    (user_id,)
                )
                row = cur.fetchone()
                if row:
                    return UserQuizStats(
                        user_id=row["user_id"],
                        xp=row["xp"],
                        current_streak=row["current_streak"],
                        best_streak=row["best_streak"],
                        last_quiz_date=row["last_quiz_date"],
                    )
                return UserQuizStats(user_id=user_id, xp=0, current_streak=0, best_streak=0)

        return await asyncio.to_thread(_sync_stats)

    async def get_unified_user_stats(
        self,
        user_id: str = "local_user",
        device_id: str | None = None,
    ) -> dict[str, Any]:
        """
        Retorna estatísticas unificadas de gamificação:
        {
            "total_xp": int,
            "current_streak": int,
            "completed_today": bool
        }
        """
        if not self._initialized:
            await self.init_db()

        def _sync_unified():
            with self._get_connection() as conn:
                today = date.today()
                today_iso = today.isoformat()

                all_dates: set[str] = set()

                # 1. Datas de quiz
                cur = conn.execute(
                    "SELECT DISTINCT substr(created_at, 1, 10) FROM user_quiz_answers WHERE user_id = ?",
                    (user_id,)
                )
                for r in cur.fetchall():
                    if r and r[0]:
                        all_dates.add(str(r[0]))

                cur_q = conn.execute(
                    "SELECT last_quiz_date FROM user_quiz_stats WHERE user_id = ? AND last_quiz_date IS NOT NULL",
                    (user_id,)
                )
                r_q = cur_q.fetchone()
                if r_q and r_q[0]:
                    all_dates.add(str(r_q[0]))

                # 2. Datas de leitura devocional (se tabela reading_log existir)
                try:
                    cur_r = conn.execute("SELECT DISTINCT date FROM reading_log")
                    for r in cur_r.fetchall():
                        if r and r[0]:
                            all_dates.add(str(r[0]))
                except sqlite3.OperationalError:
                    pass  # reading_log table may not exist

                completed_today = today_iso in all_dates

                # Cálculo de ofensiva unificada
                streak = calculate_streak(all_dates, today)

                # Busca total de XP
                total_xp = 0
                cur_gam = conn.execute("SELECT total_xp FROM user_gamification WHERE user_id = ?", (user_id,))
                r_gam = cur_gam.fetchone()
                if r_gam and r_gam[0] is not None:
                    total_xp = int(r_gam[0])

                cur_st = conn.execute("SELECT xp FROM user_quiz_stats WHERE user_id = ?", (user_id,))
                r_st = cur_st.fetchone()
                if r_st and r_st[0] is not None:
                    total_xp = max(total_xp, int(r_st[0]))

                weekly_activity = calculate_weekly_activity(all_dates, today)

                return {
                    "total_xp": total_xp,
                    "current_streak": streak,
                    "completed_today": completed_today,
                    "weekly_activity": weekly_activity,
                }

        return await asyncio.to_thread(_sync_unified)
