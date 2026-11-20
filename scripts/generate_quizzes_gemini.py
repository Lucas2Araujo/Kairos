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
    question: str = Field(
        ...,
        max_length=150,
        description="Pergunta dinâmica, direta e engajante no estilo Kahoot (máximo 120 a 140 caracteres), sem enunciados longos ou rebuscados."
    )
    options: list[str] = Field(
        ...,
        min_length=4,
        max_length=4,
        description="Exatamente 4 opções enxutas e objetivas (máximo 50 a 60 caracteres cada), fáceis de ler rapidamente no celular."
    )
    correct_option: int = Field(..., ge=0, le=3, description="Índice da resposta correta (0 a 3).")
    explanation: str = Field(
        ...,
        max_length=400,
        description="Explicação concisa e pedagógica (2 a 3 frases) justificando a resposta correta de forma clara, calorosa e edificante."
    )
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
    """Inicializa cliente google-genai a partir de GEMINI_API_KEY com suporte a v1beta."""
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("Variável de ambiente GEMINI_API_KEY não configurada.")
    try:
        from google import genai
        from google.genai import types
        return genai.Client(
            api_key=api_key,
            http_options=types.HttpOptions(api_version="v1beta"),
        )
    except ImportError:
        raise RuntimeError("Pacote 'google-genai' não instalado. Instale com: pip install google-genai")


def get_supabase_admin_client():
    """Inicializa cliente Supabase utilizando AUTH_SUPABASE_URL e LOGIN_SERVICE_KEY_SUPABASE / SUPABASE_SERVICE_ROLE_KEY."""
    url = (
        os.getenv("AUTH_SUPABASE_URL")
        or os.getenv("SUPABASE_URL")
        or "https://cjlqpvdkvuuopgjhidud.supabase.co"
    )
    service_role_key = (
        os.getenv("LOGIN_SERVICE_KEY_SUPABASE")
        or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("DEVOTIONAL_SUPABASE_SERVICE_ROLE_KEY")
    )

    if not url or not service_role_key:
        raise ValueError(
            "Variáveis AUTH_SUPABASE_URL (ou SUPABASE_URL) e LOGIN_SERVICE_KEY_SUPABASE "
            "(ou SUPABASE_SERVICE_ROLE_KEY) são obrigatórias para a persistência no Supabase."
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


_EXCLUDED_MODEL_TOKENS = ("tts", "image", "audio", "live", "computer-use", "robotics", "embedding", "aqa")
_PREFERRED_FLASH_MODELS = [
    "gemini-2.5-flash",
    "gemini-2.5-flash-lite",
    "gemini-2.0-flash",
    "gemini-2.0-flash-lite",
    "gemini-flash-latest",
    "gemini-flash-lite-latest",
]


def _parse_gemini_version(model_name: str) -> tuple[int, int]:
    """Extrai (major, minor) de nomes como 'gemini-4-hydrogen', 'gemini-3.8-flash' ou 'gemini-2.5-flash-lite'."""
    match = re.search(r"gemini-(\d+)(?:\.(\d+))?", model_name)
    if not match:
        return (0, 0)
    return (int(match.group(1)), int(match.group(2) or 0))


def _tier_priority(model_name: str) -> int:
    """Prioriza modelos rápidos/econômicos (hydrogen, flash, lite) dentro da mesma versão."""
    if "hydrogen" in model_name or ("flash" in model_name and "lite" not in model_name):
        return 3
    if "lite" in model_name:
        return 2
    if "pro" not in model_name and "ultra" not in model_name:
        return 1
    return 0


def _is_low_quota_or_experimental(model_name: str) -> bool:
    """Identifica modelos com cota muito restrita ou zero no Free Tier (pro/ultra/exp/preview/thinking)."""
    lower = model_name.lower()
    return any(tok in lower for tok in ("pro", "ultra", "exp", "preview", "thinking"))


def discover_latest_gemini_models(gemini_client) -> list[str]:
    """Descobre dinamicamente os modelos Gemini priorizando modelos Flash estáveis com alta cota gratuita."""
    stable_discovered: list[str] = []
    fallback_experimental: list[str] = []

    try:
        for m in gemini_client.models.list():
            name = (getattr(m, "name", "") or "").removeprefix("models/")
            actions = getattr(m, "supported_actions", None) or []
            if "generateContent" not in actions:
                continue
            if not name.startswith("gemini-"):
                continue
            if any(tok in name for tok in _EXCLUDED_MODEL_TOKENS):
                continue
            if name in _PREFERRED_FLASH_MODELS:
                continue
            if _is_low_quota_or_experimental(name):
                fallback_experimental.append(name)
            else:
                stable_discovered.append(name)

        def sort_key(n: str):
            return (
                _parse_gemini_version(n),
                "preview" not in n and "exp" not in n,
                _tier_priority(n),
            )

        stable_discovered.sort(key=sort_key, reverse=True)
        fallback_experimental.sort(key=sort_key, reverse=True)
    except Exception as e:
        logger.warning(f"Não foi possível listar modelos dinamicamente ({e}). Usando lista estável padrão.")

    seen: set[str] = set()
    ordered: list[str] = []
    for name in [*_PREFERRED_FLASH_MODELS, *stable_discovered, *fallback_experimental]:
        if name and name not in seen:
            seen.add(name)
            ordered.append(name)
    return ordered


def generate_questions_for_day(
    gemini_client,
    day_title: str,
    content: str,
    target_model: str | None = None,
    max_retries: int = 3,
    models_to_try: list[str] | None = None,
) -> list[GeneratedQuestionItem]:
    """Gera quizzes estruturados com failover dinâmico entre modelos em caso de indisponibilidade."""
    clean_content = strip_html_tags(content)[:8000]

    system_instruction = (
        "Você é um criador de quizzes interativos bíblicos da Escola Sabatina no estilo dinâmico e envolvente do Kahoot.\n"
        "Sua missão é criar 3 perguntas de múltipla escolha para o dia da lição, balanceadas em três níveis de dificuldade:\n\n"
        "1. Pergunta 1 (Fácil): Foco no conceito central ou fato bíblico direto do dia, com pergunta e opções muito simples.\n"
        "2. Pergunta 2 (Média): Aplicação prática para a vida cristã ou reflexão sobre o tema do estudo.\n"
        "3. Pergunta 3 (Desafiadora): Detalhe histórico, teológico ou o significado de termos bíblicos originais (grego, hebraico ou aramaico), "
        "somente se esses termos forem expressamente mencionados e explicados no texto da lição.\n\n"
        "Diretrizes de Formatação Estilo Kahoot:\n"
        "- Linguagem leve, moderna, descomplicada e ágil. Evite jargões densos, frases longas ou enunciados cansativos.\n"
        "- As perguntas devem ser diretas ao ponto (máximo de 120 a 140 caracteres).\n"
        "- Cada pergunta DEVE ter exatamente 4 opções de resposta bem enxutas (máximo 50 a 60 caracteres cada).\n"
        "- Apenas uma opção é correta, indicada pelo índice 'correct_option' (0, 1, 2 ou 3).\n"
        "- 'explanation': Forneça uma explicação concisa e edificante (2 a 3 frases claras) justificando o acerto de forma calorosa e pedagógica.\n"
        "- 'verse_ref': Inclua a referência bíblica chave da resposta (ex: 'Efésios 2:8')."
    )

    user_prompt = f"Título do Dia: {day_title}\n\nConteúdo da Lição:\n\"\"\"{clean_content}\"\"\""

    config = types.GenerateContentConfig(
        system_instruction=system_instruction,
        response_mime_type="application/json",
        response_schema=DailyQuestionsResponse,
        temperature=0.3,
    )

    # Cadeia de modelos descoberta dinamicamente (Flash estáveis primeiro)
    base_models = models_to_try if models_to_try is not None else discover_latest_gemini_models(gemini_client)
    raw_models = ([target_model] if target_model else []) + list(base_models)
    seen = set()
    models_to_try = []
    for m in raw_models:
        if m and m not in seen:
            seen.add(m)
            models_to_try.append(m)

    for model_name in models_to_try:
        delay = 6.0
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
                err_lower = err_str.lower()
                latency = time.time() - start_time

                # 404 (modelo inválido) ou 503 (serviço sobrecarregado do Google):
                # Pula direto para o próximo modelo da fila sem queimar tempo de espera
                if "404" in err_str:
                    logger.warning(f"Modelo {model_name} indisponível (404). Alternando para o próximo...")
                    break
                elif "503" in err_str or "high demand" in err_lower:
                    logger.warning(
                        f"Modelo {model_name} com sobrecarga/503. Alternando imediatamente para o próximo modelo..."
                    )
                    break

                # 429: Rate limit ou esgotamento diário de cota
                elif "429" in err_str or "resource_exhausted" in err_lower or "quota exceeded" in err_lower:
                    is_daily_exhausted = (
                        "per_day" in err_lower
                        or "perday" in err_lower
                        or ("quota exceeded" in err_lower and attempt >= 2)
                    )
                    if is_daily_exhausted or attempt == max_retries:
                        logger.warning(
                            f"Cota esgotada/429 no modelo {model_name} (tentativa {attempt}/{max_retries}). "
                            "Alternando para o próximo modelo..."
                        )
                        break
                    logger.warning(
                        f"Rate limit de cota (429) no modelo {model_name} na tentativa {attempt}/{max_retries}. "
                        f"Esperando {delay:.1f}s..."
                    )
                    time.sleep(delay)
                    delay *= 2.0
                else:
                    logger.error(f"Erro ao processar dia '{day_title}' com {model_name} após {latency:.2f}s: {e}")
                    if attempt == max_retries:
                        break
                    time.sleep(delay)
                    delay *= 1.5

    logger.critical(f"Falha definitiva: nenhum modelo disponível conseguiu processar o dia '{day_title}'.")
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


def delete_day_questions_supabase(
    supabase,
    quarterly_id: str,
    lesson_id: str,
    day_id: str,
    db_cat: str,
    retries: int = 3,
) -> int:
    """Remove questões existentes de um dia específico antes de substituí-las."""
    if not supabase:
        return 0

    for attempt in range(1, retries + 1):
        try:
            resp = (
                supabase.table("ss_questions")
                .delete()
                .eq("quarterly_id", quarterly_id)
                .eq("lesson_id", lesson_id)
                .eq("day_id", day_id)
                .eq("category", db_cat)
                .execute()
            )
            deleted_count = len(resp.data or [])
            if deleted_count > 0:
                logger.info(
                    f"✓ Removidas {deleted_count} questões antigas de [{quarterly_id} | L{lesson_id} | D{day_id} | {db_cat}]."
                )
            return deleted_count
        except Exception as e:
            logger.warning(f"Tentativa {attempt}/{retries} de delete falhou: {e}")
            if attempt == retries:
                logger.error(f"✗ Falha definitiva ao deletar questões antigas no Supabase: {e}")
                raise
            time.sleep(2.0 * attempt)
    return 0


def existing_day_questions_count(
    supabase,
    quarterly_id: str,
    lesson_id: str,
    day_id: str,
    db_cat: str,
) -> int:
    """Consulta quantas questões já existem no Supabase para evitar regerar dias salvos."""
    if not supabase:
        return 0
    try:
        resp = (
            supabase.table("ss_questions")
            .select("id")
            .eq("quarterly_id", quarterly_id)
            .eq("lesson_id", lesson_id)
            .eq("day_id", day_id)
            .eq("category", db_cat)
            .limit(5)
            .execute()
        )
        return len(resp.data or [])
    except Exception as e:
        logger.warning(f"Não foi possível checar cache existente para {quarterly_id}/{lesson_id}/{day_id}: {e}")
        return 0


def main():
    parser = argparse.ArgumentParser(description="Gerador de Quizzes da Escola Sabatina com Gemini IA")
    parser.add_argument("--quarterly", default=None, help="Ex: 2026-03-cq (opcional, detectado automaticamente)")
    parser.add_argument("--category", default="adultos", help="Categorias: 'jovens' ou 'adultos'")
    parser.add_argument("--lesson", default=None, help="ID específico da lição (opcional, ex: '13')")
    parser.add_argument("--limit-days", type=int, default=None, help="Limita o número de dias para testes rápidos")
    parser.add_argument("--all-lessons", action="store_true", help="Processa todas as lições do trimestre")
    parser.add_argument("--force", action="store_true", help="Regera dias mesmo se já houver questões no Supabase")
    parser.add_argument("--dry-run", action="store_true", help="Apenas gera sem salvar no Supabase")
    args = parser.parse_args()

    norm_category = normalize_category(args.category)
    db_cat = db_category(norm_category)

    quarterly_id = args.quarterly or resolve_active_quarterly(norm_category)
    logger.info(f"Iniciando gerador | Trimestre: {quarterly_id} | Categoria: {norm_category} (db: {db_cat}) | Dry-run: {args.dry_run}")

    gemini_client = get_gemini_client()
    models_to_try = discover_latest_gemini_models(gemini_client)
    logger.info(f"Modelos Gemini em ordem de prioridade: {models_to_try[:6]}")
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
    elif not args.all_lessons:
        today = date.today()
        target_date = today + timedelta(days=1)
        matched_lessons: list[dict[str, Any]] = []
        seen_ids: set[str] = set()

        # Prioriza lição de amanhã/próxima semana (sábado 17h BRT -> semana entrando) e a lição atual
        for check_date in (target_date, today):
            for l in lessons:
                s = _parse_date(l.get("start_date", ""))
                e = _parse_date(l.get("end_date", ""))
                lid = str(l.get("id", ""))
                if s and e and s <= check_date <= e and lid not in seen_ids:
                    matched_lessons.append(l)
                    seen_ids.add(lid)
                    break

        if matched_lessons:
            lessons = [matched_lessons[0]]
            chosen = matched_lessons[0]
            logger.info(
                f"Lição da semana selecionada automaticamente: {chosen.get('id')} - '{chosen.get('title')}' "
                f"[{chosen.get('start_date')} -> {chosen.get('end_date')}]"
            )
        else:
            if args.force:
                logger.error(
                    "Nenhuma lição específica casou com a data atual/próxima. "
                    "Abortando --force para evitar substituição acidental do trimestre inteiro; "
                    "informe --lesson ou --all-lessons."
                )
                sys.exit(1)
            logger.info("Nenhuma lição específica casou com a data atual/próxima. Processando todas as lições.")

    total_generated = 0
    total_skipped = 0
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

            if not args.dry_run and not args.force:
                existing_count = existing_day_questions_count(
                    supabase, quarterly_id, lesson_id, day_id, db_cat
                )
                if existing_count >= 2:
                    logger.info(
                        f"[SKIP] [{quarterly_id} | L{lesson_id} | D{day_id}] já possui {existing_count} questões."
                    )
                    total_skipped += 1
                    continue

            try:
                content = fetch_day_content(read_path)
                if not content or len(content.strip()) < 50:
                    logger.warning(f"Conteúdo vazio ou insuficiente para dia {day_id} ({day_title}). Pulando.")
                    continue

                logger.info(f"→ Extraindo Quiz [{quarterly_id} | L{lesson_id} | D{day_id}] '{day_title}'...")
                questions = generate_questions_for_day(
                    gemini_client,
                    day_title,
                    content,
                    models_to_try=models_to_try,
                )

                if not questions:
                    logger.warning(f"Nenhuma pergunta retornada para o dia {day_id}.")
                    continue

                day_payload = []
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
                    day_payload.append(payload_item)
                    if args.dry_run and len(dry_run_samples) < 3:
                        dry_run_samples.append(payload_item)
                    total_generated += 1

                days_processed += 1

                if not args.dry_run:
                    if args.force:
                        delete_day_questions_supabase(
                            supabase, quarterly_id, lesson_id, day_id, db_cat
                        )
                        upsert_questions_supabase(supabase, day_payload)
                    else:
                        all_questions_payload.extend(day_payload)
                        if len(all_questions_payload) >= 20:
                            upsert_questions_supabase(supabase, all_questions_payload)
                            all_questions_payload.clear()

                # Pausa entre dias para respeitar limite de 15 RPM no nível gratuito do Gemini
                time.sleep(4.0)

            except Exception as e:
                logger.error(f"Falha ao processar dia {day_id}: {e}")

        if args.limit_days and days_processed >= args.limit_days:
            break

    if all_questions_payload and not args.dry_run:
        upsert_questions_supabase(supabase, all_questions_payload)
        all_questions_payload.clear()

    if total_generated == 0 and total_skipped == 0:
        logger.critical(
            f"[FALHA CRÍTICA] Nenhuma pergunta foi gerada para o trimestre '{quarterly_id}' "
            f"(Lições analisadas: {len(lessons)}). Abortando com código de erro 1."
        )
        sys.exit(1)

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
        logger.info(
            f"[EXECUÇÃO CONCLUÍDA] Geradas: {total_generated} | Já existentes (puladas): {total_skipped}."
        )


if __name__ == "__main__":
    main()
