"""
Script de automação para extrair lições da Escola Sabatina (Adventech API)
e gerar quizzes diários estruturados via Google Gemini API (google-genai).
Realiza upsert idempotente no Supabase utilizando LOGIN_SERVICE_KEY_SUPABASE.

Uso:
    python scripts/generate_quizzes_gemini.py --category jovens --dry-run
    python scripts/generate_quizzes_gemini.py --quarterly 2026-03-cq --category jovens --lesson 13
"""

from __future__ import annotations

import argparse
from html import unescape
import json
import logging
import os
import re
import sys
import time
import uuid
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from google.genai import types
import httpx
from pydantic import BaseModel, Field

# Carregar variáveis de ambiente locais se existirem
try:
    from dotenv import load_dotenv
    base_dir = Path(__file__).resolve().parent.parent
    load_dotenv(base_dir / ".env")
except ImportError:
    pass

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("quiz_generator")

ADVENTECH_API_BASE = "https://sabbath-school.adventech.io/api/v2"


class GeneratedQuestionItem(BaseModel):
    question: str = Field(..., description="Pergunta clara e objetiva sobre o conteúdo do dia.")
    options: list[str] = Field(..., min_length=4, max_length=4, description="Exatamente 4 opções de resposta.")
    correct_option: int = Field(..., ge=0, le=3, description="Índice da resposta correta (0 a 3).")
    explanation: str = Field(..., description="Explicação detalhada de por que a opção está correta.")
    verse_ref: str | None = Field(default=None, description="Referência bíblica principal relacionada (ex: João 3:16).")


class DailyQuestionsResponse(BaseModel):
    questions: list[GeneratedQuestionItem] = Field(..., min_length=2, max_length=3)


def normalize_category(category: str) -> str:
    """Normaliza o input CLI para as categorias suportadas no domínio."""
    cat = (category or "").strip().lower()
    if cat in ("jovens", "jovem"):
        return "jovens"
    if cat in ("adultos", "adulto"):
        return "adultos"
    raise ValueError(f"Categoria inválida: '{category}'. Use 'jovens' ou 'adultos'.")


def db_category(domain_category: str) -> str:
    """Mapeia categoria do domínio para o valor aceito pela check constraint do Supabase."""
    return "jovem" if domain_category == "jovens" else "adultos"


def strip_html_tags(html_text: str) -> str:
    """Remove marcações HTML e decodifica entidades para economizar tokens."""
    if not html_text:
        return ""
    text = re.sub(r"<[^>]+>", " ", html_text)
    text = unescape(text)
    return re.sub(r"\s+", " ", text).strip()


def get_gemini_client():
    """Inicializa cliente google-genai a partir de GEMINI_API_KEY."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("Variável de ambiente GEMINI_API_KEY não configurada.")
    try:
        from google import genai
        return genai.Client(api_key=api_key)
    except ImportError:
        raise RuntimeError("Pacote 'google-genai' não instalado. Instale com: pip install google-genai")


def get_supabase_admin_client():
    """Inicializa cliente Supabase utilizando estritamente AUTH_SUPABASE_URL e LOGIN_SERVICE_KEY_SUPABASE."""
    url = os.getenv("AUTH_SUPABASE_URL") or os.getenv("SUPABASE_URL")
    service_role_key = os.getenv("LOGIN_SERVICE_KEY_SUPABASE")

    if not url or not service_role_key:
        raise ValueError(
            "Variáveis AUTH_SUPABASE_URL e LOGIN_SERVICE_KEY_SUPABASE são obrigatórias "
            "para a persistência no Supabase."
        )

    try:
        from supabase import create_client
        return create_client(url, service_role_key)
    except ImportError:
        raise RuntimeError("Pacote 'supabase' não instalado. Instale com: pip install supabase")


def fetch_all_quarterlies(lang: str = "pt") -> list[dict[str, Any]]:
    """Busca a lista de todos os trimestres na Adventech API."""
    url = f"{ADVENTECH_API_BASE}/{lang}/quarterlies/index.json"
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url)
        resp.raise_for_status()
        return resp.json()


def _parse_date(d_str: str) -> date | None:
    """Converte datas nos formatos DD/MM/YYYY ou YYYY-MM-DD para date."""
    if not d_str:
        return None
    d_str = str(d_str).strip()
    for sep in ("/", "-"):
        if sep in d_str:
            parts = d_str.split(sep)
            if len(parts) == 3:
                try:
                    if len(parts[0]) == 4:
                        return date(int(parts[0]), int(parts[1]), int(parts[2]))
                    elif len(parts[2]) == 4:
                        return date(int(parts[2]), int(parts[1]), int(parts[0]))
                except Exception:
                    pass
    return None


def resolve_active_quarterly(category: str, lang: str = "pt") -> str:
    """Detecta automaticamente o trimestre ativo para a categoria na data atual."""
    quarterlies = fetch_all_quarterlies(lang=lang)
    today = date.today()
    target_group = "Lição Jovens" if category == "jovens" else "Lição Adultos"

    for q in quarterlies:
        group_name = q.get("quarterly_group", {}).get("name", "")
        if target_group.lower() in group_name.lower():
            s = _parse_date(q.get("start_date", ""))
            e = _parse_date(q.get("end_date", ""))
            if s and e and s <= today <= e:
                logger.info(f"Trimestre ativo identificado: {q['id']} ({q.get('title')}) [{q.get('start_date')} -> {q.get('end_date')}]")
                return q["id"]

    for q in quarterlies:
        group_name = q.get("quarterly_group", {}).get("name", "")
        if target_group.lower() in group_name.lower():
            logger.info(f"Trimestre mais recente identificado: {q['id']} ({q.get('title')})")
            return q["id"]

    fallback = "2026-03-cq" if category == "jovens" else "2026-03"
    logger.info(f"Usando fallback padrão para trimestre: {fallback}")
    return fallback


def fetch_quarterly_lessons(quarterly_id: str, lang: str = "pt") -> list[dict[str, Any]]:
    """Busca o índice do trimestre na Adventech API."""
    url = f"{ADVENTECH_API_BASE}/{lang}/quarterlies/{quarterly_id}/index.json"
    logger.info(f"Buscando lições em: {url}")
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url)
        resp.raise_for_status()
        data = resp.json()
        return data.get("lessons", [])


def fetch_lesson_days(quarterly_id: str, lesson_id: str, lang: str = "pt") -> list[dict[str, Any]]:
    """Busca os dias de uma lição na Adventech API."""
    url = f"{ADVENTECH_API_BASE}/{lang}/quarterlies/{quarterly_id}/lessons/{lesson_id}/index.json"
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url)
        resp.raise_for_status()
        data = resp.json()
        return data.get("days", [])


def fetch_day_content(read_path: str) -> str:
    """Busca o conteúdo completo de estudo de um dia."""
    url = f"{ADVENTECH_API_BASE}/{read_path}/index.json"
    with httpx.Client(timeout=30.0) as client:
        resp = client.get(url)
        resp.raise_for_status()
        data = resp.json()
        return data.get("content", "") or ""


def generate_questions_for_day(
    gemini_client,
    day_title: str,
    content: str,
    target_model: str = "gemini-2.5-flash",
    max_retries: int = 3,
) -> list[GeneratedQuestionItem]:
    """Usa o Gemini com Structured Outputs para criar perguntas sem disparar warnings de AFC."""
    clean_content = strip_html_tags(content)[:8000]

    system_instruction = (
        "Você é um teólogo e educador especialista na Escola Sabatina.\n"
        "Crie de 2 a 3 perguntas de múltipla escolha para testar o entendimento dos estudantes sobre a lição.\n"
        "Diretrizes obrigatórias:\n"
        "1. Gere perguntas fiéis ao texto e que estimulem reflexão e aprendizado.\n"
        "2. Cada pergunta DEVE ter exatamente 4 opções de resposta.\n"
        "3. Indique o índice da resposta correta (0, 1, 2 ou 3) no campo 'correct_option'.\n"
        "4. Forneça uma explicação concisa e edificante do motivo da resposta correta.\n"
        "5. Se houver citação bíblica importante associada, preencha o campo 'verse_ref'."
    )

    user_prompt = f"Título do Dia: {day_title}\n\nConteúdo da Lição:\n\"\"\"{clean_content}\"\"\""

    config = types.GenerateContentConfig(
        system_instruction=system_instruction,
        response_mime_type="application/json",
        response_schema=DailyQuestionsResponse,
        function_calling_config=types.FunctionCallingConfig(
            mode=types.FunctionCallingMode.NONE
        ),
        temperature=0.3,
    )

    models_to_try = [target_model, "gemini-2.5-flash-lite"]

    for model_name in models_to_try:
        delay = 2.0
        for attempt in range(1, max_retries + 1):
            start_time = time.time()
            try:
                response = gemini_client.models.generate_content(
                    model=model_name,
                    contents=user_prompt,
                    config=config,
                )
                latency = time.time() - start_time
                parsed = json.loads(response.text)
                validated = DailyQuestionsResponse(**parsed)
                logger.info(
                    f"✓ Gemini ({model_name}) gerou {len(validated.questions)} perguntas em {latency:.2f}s."
                )
                return validated.questions

            except Exception as e:
                err_str = str(e)
                latency = time.time() - start_time
                if "429" in err_str or "503" in err_str or "high demand" in err_str.lower():
                    logger.warning(
                        f"Rate limit / sobrecarga ({model_name}) na tentativa {attempt}/{max_retries}. Esperando {delay:.1f}s... Erro: {err_str[:80]}"
                    )
                    time.sleep(delay)
                    delay *= 2.0
                elif "404" in err_str:
                    logger.warning(f"Modelo {model_name} indisponível (404). Alternando modelo...")
                    break
                else:
                    logger.error(f"Erro ao processar dia '{day_title}' com {model_name} após {latency:.2f}s: {e}")
                    if attempt == max_retries:
                        break
                    time.sleep(delay)
                    delay *= 1.5

    return []


def upsert_questions_supabase(supabase, questions_data: list[dict[str, Any]], retries: int = 3) -> bool:
    """Executa upsert idempotente no Supabase com política de retentativas para instabilidades de rede."""
    if not supabase or not questions_data:
        return False

    for attempt in range(1, retries + 1):
        try:
            supabase.table("ss_questions").upsert(
                questions_data,
                on_conflict="id"
            ).execute()
            logger.info(f"✓ Upsert de {len(questions_data)} questões no Supabase concluído.")
            return True
        except Exception as e:
            logger.warning(f"Tentativa {attempt}/{retries} de upsert falhou: {e}")
            if attempt == retries:
                logger.error(f"✗ Falha definitiva no upsert do Supabase: {e}")
                raise
            time.sleep(2.0 * attempt)
    return False


def main():
    parser = argparse.ArgumentParser(description="Gerador de Quizzes da Escola Sabatina com Gemini IA")
    parser.add_argument("--quarterly", default=None, help="Ex: 2026-03-cq (opcional, detectado automaticamente)")
    parser.add_argument("--category", default="adultos", help="Categorias: 'jovens' ou 'adultos'")
    parser.add_argument("--lesson", default=None, help="ID específico da lição (opcional, ex: '13')")
    parser.add_argument("--limit-days", type=int, default=None, help="Limita o número de dias para testes rápidos")
    parser.add_argument("--dry-run", action="store_true", help="Apenas gera sem salvar no Supabase")
    args = parser.parse_args()

    norm_category = normalize_category(args.category)
    db_cat = db_category(norm_category)

    quarterly_id = args.quarterly or resolve_active_quarterly(norm_category)
    logger.info(f"Iniciando gerador | Trimestre: {quarterly_id} | Categoria: {norm_category} (db: {db_cat}) | Dry-run: {args.dry_run}")

    gemini_client = get_gemini_client()
    supabase = None if args.dry_run else get_supabase_admin_client()

    lessons = fetch_quarterly_lessons(quarterly_id)
    logger.info(f"Encontradas {len(lessons)} lições no trimestre {quarterly_id}.")

    if args.lesson:
        target_lesson = str(args.lesson).strip()
        lessons = [
            l for l in lessons
            if str(l.get("id")).strip() == target_lesson
            or str(l.get("id")).strip().lstrip("0") == target_lesson.lstrip("0")
        ]
        if not lessons:
            logger.error(f"Lição {args.lesson} não encontrada no trimestre {quarterly_id}.")
            sys.exit(1)
    else:
        target_date = date.today() + timedelta(days=1)
        matched_lesson = None
        for l in lessons:
            s = _parse_date(l.get("start_date", ""))
            e = _parse_date(l.get("end_date", ""))
            if s and e and s <= target_date <= e:
                matched_lesson = l
                break

        if not matched_lesson:
            for l in lessons:
                s = _parse_date(l.get("start_date", ""))
                e = _parse_date(l.get("end_date", ""))
                if s and e and s <= date.today() <= e:
                    matched_lesson = l
                    break

        if matched_lesson:
            lessons = [matched_lesson]
            logger.info(f"Lição da semana selecionada automaticamente: {matched_lesson.get('id')} - '{matched_lesson.get('title')}' [{matched_lesson.get('start_date')} -> {matched_lesson.get('end_date')}]")
        else:
            logger.info("Nenhuma lição específica casou com a data atual/próxima. Processando todas as lições.")

    total_generated = 0
    days_processed = 0
    all_questions_payload = []
    dry_run_samples = []

    for lesson in lessons:
        lesson_id = str(lesson.get("id"))
        lesson_title = lesson.get("title", "")
        days = fetch_lesson_days(quarterly_id, lesson_id)
        logger.info(f"Processando Lição {lesson_id} - '{lesson_title}' ({len(days)} dias)...")

        for day in days:
            if args.limit_days and days_processed >= args.limit_days:
                break

            day_id = str(day.get("id"))
            day_title = day.get("title", "")
            read_path = day.get("read_path") or f"pt/quarterlies/{quarterly_id}/lessons/{lesson_id}/days/{day_id}"

            try:
                content = fetch_day_content(read_path)
                if not content or len(content.strip()) < 50:
                    logger.warning(f"Conteúdo vazio ou insuficiente para dia {day_id} ({day_title}). Pulando.")
                    continue

                logger.info(f"→ Extraindo Quiz [{quarterly_id} | L{lesson_id} | D{day_id}] '{day_title}'...")
                questions = generate_questions_for_day(gemini_client, day_title, content)

                if not questions:
                    logger.warning(f"Nenhuma pergunta retornada para o dia {day_id}.")
                    continue

                for q in questions:
                    q_uuid = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{quarterly_id}_{day_id}_{q.question.strip()}"))
                    payload_item = {
                        "id": q_uuid,
                        "lesson_id": lesson_id,
                        "day_id": day_id,
                        "quarterly_id": quarterly_id,
                        "category": db_cat,
                        "question": q.question,
                        "options": q.options,
                        "correct_option": q.correct_option,
                        "explanation": q.explanation,
                        "verse_ref": q.verse_ref,
                        "created_at": datetime.now(timezone.utc).isoformat(),
                    }
                    all_questions_payload.append(payload_item)
                    if args.dry_run and len(dry_run_samples) < 3:
                        dry_run_samples.append(payload_item)
                    total_generated += 1

                days_processed += 1

                if len(all_questions_payload) >= 20 and not args.dry_run:
                    upsert_questions_supabase(supabase, all_questions_payload)
                    all_questions_payload.clear()

            except Exception as e:
                logger.error(f"Falha ao processar dia {day_id}: {e}")

        if args.limit_days and days_processed >= args.limit_days:
            break

    if all_questions_payload and not args.dry_run:
        upsert_questions_supabase(supabase, all_questions_payload)
        all_questions_payload.clear()

    if args.dry_run:
        logger.info(f"[DRY-RUN CONCLUÍDO] Total de perguntas geradas: {total_generated}. Zero mutações no banco.")
        for idx, sample_q in enumerate(dry_run_samples, 1):
            logger.info(f"Amostra #{idx}:")
            logger.info(f"  Pergunta: {sample_q['question']}")
            logger.info(f"  Opções: {sample_q['options']}")
            logger.info(f"  Gabarito: {sample_q['correct_option']} -> {sample_q['options'][sample_q['correct_option']]}")
            logger.info(f"  Explicação: {sample_q['explanation']}")
            logger.info(f"  Ref Bíblica: {sample_q['verse_ref']}")
    else:
        logger.info(f"[EXECUÇÃO CONCLUÍDA] Total de perguntas persistidas: {total_generated}.")


if __name__ == "__main__":
    main()
