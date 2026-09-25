import pytest
import asyncio
from unittest.mock import MagicMock, AsyncMock, patch
from src.models.quiz import QuizQuestion, QuizQuestionInternal, QuizAnswerSubmission, QuizReport
from src.services.quiz_service import QuizService


import uuid


@pytest.fixture
def mock_db_connection(tmp_path):
    uid = uuid.uuid4().hex[:8]
    db_file = tmp_path / f"test_quiz_{uid}.db"
    return str(db_file)


@pytest.fixture
def sample_question_internal():
    return QuizQuestionInternal(
        id="q1",
        day_id="d1",
        quarterly_id="2024-q3",
        category="adultos",
        question="Qual era o tema da lição?",
        options=["Opção A", "Opção B", "Opção C", "Opção D"],
        correct_option=1,
        explanation="Porque a opção B está fundamentada no texto.",
        verse_ref="Romanos 8:28",
    )


@pytest.mark.asyncio
async def test_quiz_model_public_projection(sample_question_internal):
    public_q = sample_question_internal.to_public()
    assert isinstance(public_q, QuizQuestion)
    assert not hasattr(public_q, "correct_option") or "correct_option" not in public_q.model_fields
    assert len(public_q.options) == 4


@pytest.mark.asyncio
async def test_anti_speedhack_defense(mock_db_connection):
    service = QuizService(db_path=mock_db_connection)
    await service.init_db()

    # Submissão com tempo menor que 2 segundos
    result = await service.submit_answer(
        question_id="q1",
        selected_option=1,
        time_spent=1,  # < 2s
        user_id="user_123"
    )
    assert result.is_correct is False
    assert result.xp_earned == 0
    assert "rápido" in result.message.lower() or "speedhack" in result.message.lower() or "tempo insuficiente" in result.message.lower()


@pytest.mark.asyncio
async def test_offline_cache_and_answer_validation(mock_db_connection, sample_question_internal):
    service = QuizService(db_path=mock_db_connection)
    await service.init_db()

    # Salva no cache local (como se tivesse vindo da sincronização)
    await service.save_question_to_cache(sample_question_internal)

    # Busca pergunta pública offline
    questions = await service.get_daily_quiz(day_id="d1", category="adultos")
    assert len(questions) == 1
    assert questions[0].id == "q1"
    assert not hasattr(questions[0], "correct_option")

    # Responder corretamente com tempo válido
    res_correct = await service.submit_answer(
        question_id="q1",
        selected_option=1,
        time_spent=5,
        user_id="user_123"
    )
    assert res_correct.is_correct is True
    assert res_correct.xp_earned > 0
    assert res_correct.correct_option == 1

    # Verificar se has_user_answered registra
    answered = await service.has_user_answered(question_id="q1", user_id="user_123")
    assert answered is True

    # Responder de novo não deve conceder XP duplicado
    res_again = await service.submit_answer(
        question_id="q1",
        selected_option=1,
        time_spent=5,
        user_id="user_123"
    )
    assert res_again.already_answered is True
    assert res_again.xp_earned == 0


@pytest.mark.asyncio
async def test_report_question_sanitization(mock_db_connection):
    service = QuizService(db_path=mock_db_connection)
    await service.init_db()

    # Teste de envio de denúncia com caracteres maliciosos / nulos
    success = await service.report_question(
        question_id="q1",
        reason="Erro na tradução\x00",
        comment="   Texto com espaços e caracteres   "
    )
    assert success is True


@pytest.mark.asyncio
async def test_idempotent_caching(mock_db_connection, sample_question_internal):
    service = QuizService(db_path=mock_db_connection)
    await service.init_db()

    # Inserção dupla da mesma pergunta
    await service.save_question_to_cache(sample_question_internal)
    await service.save_question_to_cache(sample_question_internal)

    questions = await service.get_daily_quiz(day_id="d1", category="adultos")
    assert len(questions) == 1


@pytest.mark.asyncio
async def test_multi_question_sequential_answers(mock_db_connection):
    """Verifica que múltiplas questões sequenciais são validadas corretamente sem falso-negativo."""
    service = QuizService(db_path=mock_db_connection)
    await service.init_db()

    q1 = QuizQuestionInternal(
        id="seq_q1",
        day_id="d_seq",
        quarterly_id="2024-q3",
        category="adultos",
        question="Pergunta 1",
        options=["Opção A1", "Opção B1", "Opção C1", "Opção D1"],
        correct_option=0,
        explanation="Exp 1",
        verse_ref="Jo 3:16",
    )
    q2 = QuizQuestionInternal(
        id="seq_q2",
        day_id="d_seq",
        quarterly_id="2024-q3",
        category="adultos",
        question="Pergunta 2",
        options=["Opção A2", "Opção B2", "Opção C2", "Opção D2"],
        correct_option=2,
        explanation="Exp 2",
        verse_ref="Rm 8:28",
    )
    await service.save_question_to_cache(q1)
    await service.save_question_to_cache(q2)

    # 1. Responde primeira questão corretamente
    res1 = await service.submit_answer(
        question_id=q1.id,
        selected_option=0,
        time_spent=3,
        user_id="user_seq",
    )
    assert res1.is_correct is True
    assert res1.correct_option == 0

    # 2. Responde segunda questão sequencialmente de forma correta
    res2 = await service.submit_answer(
        question_id=q2.id,
        selected_option=2,
        time_spent=3,
        user_id="user_seq",
    )
    assert res2.is_correct is True
    assert res2.correct_option == 2

    # 3. Responde segunda questão com opção incorreta com outro usuário
    res2_wrong = await service.submit_answer(
        question_id=q2.id,
        selected_option=1,
        time_spent=3,
        user_id="user_seq_2",
    )
    assert res2_wrong.is_correct is False
    assert res2_wrong.correct_option == 2


@pytest.mark.asyncio
async def test_unified_streak_and_devotional_xp(mock_db_connection):
    """Verifica que a leitura devocional concede +10 XP uma vez por dia e unifica a ofensiva."""
    from src.database.connection import DatabaseConnection
    from src.services.reading_service import ReadingService
    from datetime import date

    db_conn = DatabaseConnection(db_path=mock_db_connection)
    try:
        reading_service = ReadingService(db_connection=db_conn)
        quiz_service = QuizService(db_path=db_conn.db_path)
        await quiz_service.init_db()

        today_str = date.today().isoformat()

        # 1. Marca meditação de hoje como lida
        await reading_service.mark_as_read(today_str, category="diario", user_id="user_uni")
        stats1 = await reading_service.get_unified_user_stats(user_id="user_uni")
        assert stats1["total_xp"] == 10
        assert stats1["current_streak"] >= 1
        assert stats1["completed_today"] is True

        # 2. Tenta marcar outra meditação no mesmo dia (ex: jovem) -> Não deve duplicar XP
        await reading_service.mark_as_read(today_str, category="jovem", user_id="user_uni")
        stats2 = await reading_service.get_unified_user_stats(user_id="user_uni")
        assert stats2["total_xp"] == 10  # Continua 10 XP

        # 3. QuizService também deve enxergar as estatísticas unificadas
        q_stats = await quiz_service.get_unified_user_stats(user_id="user_uni")
        assert q_stats["total_xp"] == 10
        assert q_stats["current_streak"] >= 1
        assert q_stats["completed_today"] is True
    finally:
        await db_conn.close()
