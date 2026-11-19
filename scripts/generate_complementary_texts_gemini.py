"""
Gerador semanal de Textos Complementares (Domingo) da Escola Sabatina via Gemini + Supabase.
Fiel à teologia da Igreja Adventista do Sétimo Dia (Bíblia, Ellen G. White e materiais IASD).
"""

import argparse
import json
import os
import re
import sys
import time
from datetime import date, datetime, timedelta
from typing import Literal, Optional

import httpx
from dotenv import load_dotenv
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from supabase import create_client

from generate_quizzes_gemini import (
    _parse_date,
    discover_latest_gemini_models,
    resolve_active_quarterly,
)

load_dotenv()

ADVENTECH_BASE = "https://sabbath-school.adventech.io/api/v2/pt"


class ComplementaryResourceSchema(BaseModel):
    type: Literal["bible", "egw", "external"] = Field(
        description="Tipo do recurso: 'bible' para passagens bíblicas, 'egw' para livros de Ellen G. White, 'external' para outros materiais da IASD."
    )
    title: str = Field(description="Título curto do recurso (ex: 'Atos 8:26-40', 'Atos dos Apóstolos, cap. 11', 'Comentário Bíblico Adventista').")
    subtitle: str = Field(description="Breve descrição de como o recurso aprofunda o estudo da semana.")
    reference: str = Field(default="", description="Referência bíblica (ex: 'At 8:26-40') ou livro/capítulo EGW (ex: 'Atos dos Apóstolos|11').")
    url: str = Field(default="", description="URL oficial da IASD (egwwritings.org, cpb.com.br, revistaadventista.com.br, advir.com.br, biblia.com.br) quando type='external'.")


class ComplementaryTextSchema(BaseModel):
    bible_reference: str = Field(description="Texto bíblico principal da semana (ex: 'At 8:26-40').")
    summary: str = Field(description="Resumo claro, devocional e teologicamente fiel à IASD (2 a 3 parágrafos curtos) respondendo à pesquisa proposta no estudo de Domingo.")
    resources: list[ComplementaryResourceSchema] = Field(
        min_length=3,
        max_length=6,
        description="Lista de 3 a 6 recursos complementares: incluir pelo menos 1 'bible', 1 'egw' e 1 'external' de fontes adventistas.",
    )


def detect_active_quarterly(client: httpx.Client, category: str) -> str:
    """Detecta o trimestre ativo convertendo datas DD/MM/YYYY da API Adventech."""
    return resolve_active_quarterly(category, lang="pt")


def strip_html(html: str) -> str:
    text = re.sub(r"<[^>]+>", " ", html or "")
    return re.sub(r"\s+", " ", text).strip()


def find_sunday_day(days: list[dict]) -> Optional[dict]:
    for d in days:
        date_str = d.get("date", "")
        try:
            dt = datetime.strptime(date_str[:10], "%d/%m/%Y")
            if dt.weekday() == 6:  # Sunday
                return d
        except ValueError:
            pass
    return days[1] if len(days) > 1 else (days[0] if days else None)


def select_weekly_lesson(lessons: list[dict]) -> list[dict]:
    """Seleciona apenas a lição da semana atual (ou próxima, no sábado) para evitar desperdício de cota."""
    today = date.today()
    target_date = today + timedelta(days=1)

    for check_date in (target_date, today):
        for lesson in lessons:
            s = _parse_date(lesson.get("start_date", ""))
            e = _parse_date(lesson.get("end_date", ""))
            if s and e and s <= check_date <= e:
                return [lesson]

    return lessons


def generate_for_sunday(
    ai_client: genai.Client,
    lesson_title: str,
    sunday_title: str,
    sunday_content: str,
    models_to_try: list[str],
) -> ComplementaryTextSchema:
    prompt = f"""
Você é um pesquisador teológico da Igreja Adventista do Sétimo Dia (IASD).
Com base no estudo de Domingo da Lição da Escola Sabatina abaixo, elabore um resumo rico e devocional ("Textos complementares") para ajudar o estudante na pesquisa semanal.

Lição: {lesson_title}
Estudo de Domingo: {sunday_title}
Conteúdo do Domingo:
{sunday_content[:3500]}

Regras obrigatórias:
1. O conteúdo deve ser 100% fiel às doutrinas e interpretações da Igreja Adventista do Sétimo Dia.
2. Inclua no campo `resources` de 3 a 6 itens variados:
   - `bible`: passagens bíblicas-chave relacionadas ao tema (preencha `reference` com abreviação padrão, ex: `At 8:26-40`).
   - `egw`: livros e capítulos de Ellen G. White relacionados ao tema (preencha `reference` no formato `Nome do Livro|Capítulo`, ex: `Atos dos Apóstolos|11`).
   - `external`: materiais oficiais da IASD (ex: Comentário Bíblico Adventista, Revista Adventista, EGW Writings, CPB) com `url` válida e segura (https://).
3. Seja conciso, claro e edificante.
"""
    last_error: Exception | None = None
    for model_name in models_to_try:
        for attempt in range(1, 3):
            try:
                response = ai_client.models.generate_content(
                    model=model_name,
                    contents=prompt,
                    config=types.GenerateContentConfig(
                        response_mime_type="application/json",
                        response_schema=ComplementaryTextSchema,
                        temperature=0.3,
                    ),
                )
                return ComplementaryTextSchema.model_validate_json(response.text)
            except Exception as e:
                last_error = e
                err_lower = str(e).lower()
                if "404" in err_lower or "503" in err_lower or "high demand" in err_lower:
                    print(f"[WARN] Modelo {model_name} indisponível ({e}). Pulando...", file=sys.stderr)
                    break
                if ("429" in err_lower or "resource_exhausted" in err_lower or "quota" in err_lower) and attempt == 1:
                    print(f"[WARN] Rate limit em {model_name}. Aguardando 5s antes de tentar novamente...", file=sys.stderr)
                    time.sleep(5.0)
                    continue
                print(f"[WARN] Modelo {model_name} falhou ({e}). Tentando próximo...", file=sys.stderr)
                break

    raise RuntimeError(f"Todos os modelos falharam ({models_to_try}): {last_error}") from last_error


def main() -> None:
    parser = argparse.ArgumentParser(description="Gera Textos Complementares (Domingo) da Escola Sabatina.")
    parser.add_argument("--category", choices=["jovens", "adultos"], required=True)
    parser.add_argument("--quarterly", default="")
    parser.add_argument("--lesson", default="")
    parser.add_argument("--all-lessons", action="store_true", help="Processa todas as lições do trimestre.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true", help="Sobrescreve registros já existentes no Supabase.")
    args = parser.parse_args()

    gemini_key = os.getenv("GEMINI_API_KEY")
    if not gemini_key:
        print("Erro: GEMINI_API_KEY não definida.", file=sys.stderr)
        sys.exit(1)

    ai_client = genai.Client(api_key=gemini_key)
    models_to_try = discover_latest_gemini_models(ai_client)
    print(f"Modelos candidatos (ordem de prioridade): {models_to_try[:6]}")
    sb_client = None
    if not args.dry_run:
        sb_url = os.getenv("SUPABASE_URL") or os.getenv("AUTH_SUPABASE_URL")
        sb_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("LOGIN_SERVICE_KEY_SUPABASE")
        if not sb_url or not sb_key:
            print("Erro: SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY não definidas.", file=sys.stderr)
            sys.exit(1)
        sb_client = create_client(sb_url, sb_key)

    with httpx.Client() as http:
        qid = args.quarterly or detect_active_quarterly(http, args.category)
        print(f"Trimestre selecionado ({args.category}): {qid}")

        lessons_resp = http.get(f"{ADVENTECH_BASE}/quarterlies/{qid}/lessons/index.json", timeout=20)
        lessons_resp.raise_for_status()
        lessons = lessons_resp.json()

        if not args.lesson and not args.all_lessons:
            lessons = select_weekly_lesson(lessons)
            if len(lessons) == 1:
                print(f"Lição da semana selecionada automaticamente: {lessons[0].get('id')} - {lessons[0].get('title')}")

        for idx, lesson in enumerate(lessons):
            lesson_id = lesson.get("id", "")
            lesson_num_match = re.search(r"(\d+)$", lesson_id)
            lesson_num = int(lesson_num_match.group(1)) if lesson_num_match else 0

            if args.lesson and str(lesson_num) != str(args.lesson).lstrip("0"):
                continue

            days_resp = http.get(f"{ADVENTECH_BASE}/quarterlies/{qid}/lessons/{lesson_id}/days/index.json", timeout=20)
            days_resp.raise_for_status()
            days = days_resp.json()

            sunday = find_sunday_day(days)
            if not sunday:
                continue

            day_id = sunday.get("id", "")
            lesson_day_id = f"{qid}-{lesson_id}-{day_id}"

            if not args.dry_run and not args.force:
                existing = (
                    sb_client.table("lesson_complementary_texts")
                    .select("lesson_day_id")
                    .eq("lesson_day_id", lesson_day_id)
                    .limit(1)
                    .execute()
                )
                if existing.data:
                    print(f"[SKIP] Já existe: {lesson_day_id}")
                    continue

            read_resp = http.get(
                f"{ADVENTECH_BASE}/quarterlies/{qid}/lessons/{lesson_id}/days/{day_id}/read/index.json",
                timeout=20,
            )
            read_resp.raise_for_status()
            read_data = read_resp.json()

            sunday_content = strip_html(read_data.get("content", ""))
            result = generate_for_sunday(
                ai_client=ai_client,
                lesson_title=lesson.get("title", ""),
                sunday_title=sunday.get("title", ""),
                sunday_content=sunday_content,
                models_to_try=models_to_try,
            )

            payload = {
                "lesson_day_id": lesson_day_id,
                "quarterly_id": qid,
                "lesson_num": lesson_num,
                "bible_reference": result.bible_reference,
                "summary": result.summary,
                "resources": [r.model_dump() for r in result.resources],
            }

            if args.dry_run:
                print(f"[DRY-RUN] Lição {lesson_num} ({payload['lesson_day_id']}):")
                print(json.dumps(payload, ensure_ascii=False, indent=2))
            else:
                sb_client.table("lesson_complementary_texts").upsert(
                    payload, on_conflict="lesson_day_id"
                ).execute()
                print(f"[OK] Persistido: {payload['lesson_day_id']}")

            if idx + 1 < len(lessons):
                time.sleep(3.0)


if __name__ == "__main__":
    main()
