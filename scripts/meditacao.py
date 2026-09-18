import os
import re
import sys
from datetime import date
import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

DEVOTIONAL_SUPABASE_URL = (
    os.environ.get("DEVOTIONAL_SUPABASE_URL")
    or os.environ.get("SUPABASE_URL")
    or ""
).rstrip("/")
DEVOTIONAL_SUPABASE_KEY = (
    os.environ.get("DEVOTIONAL_SUPABASE_SERVICE_ROLE_KEY")
    or os.environ.get("DEVOTIONAL_SUPABASE_KEY")
    or os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8",
}

MESES = {
    1: "jan", 2: "fev", 3: "mar", 4: "abr", 5: "mai", 6: "jun",
    7: "jul", 8: "ago", 9: "set", 10: "out", 11: "nov", 12: "dez"
}

CATEGORIAS = {
    "jovem": "https://mais.cpb.com.br/devocional-jovem-ano/",
    "diario": "https://mais.cpb.com.br/devocional-diario-ano/",
    "mulher": "https://mais.cpb.com.br/devocional-mulher-ano/",
}

# ---------------------------------------------------------------------------
# Regex de referência bíblica — cobre formatos como:
#   "Tiago 3:16, 17"   "Gálatas 5:19, 20"   "Is 14:14"   "Jo 3:16–18"
#   "(1 João 4:7, 8)"  "2 Samuel 21:10"     "Sl 23:1"
# Grupo 1 → referência dentro de parênteses
# Grupo 2 → referência sem parênteses
# ---------------------------------------------------------------------------
_BOOK = r"[1-3]?\s?[A-Za-zÀ-ÿ]{2,}(?:\s[A-Za-zÀ-ÿ]+)*"
_VERSES = r"\d+:\d+(?:[–\-]\d+)?(?:\s*[,;]\s*\d+)*"
_REF_CORE = rf"(?:{_BOOK})\s+(?:{_VERSES}|\d+)"

VERSE_END_REGEX = re.compile(
    rf"(?:\(\s*({_REF_CORE})\s*\)|({_REF_CORE}))\.?\s*$",
    re.IGNORECASE,
)


def sanitize_text(text: str) -> str:
    """Limpa pontuação órfã, parênteses vazios e normaliza espaçamento."""
    text = re.sub(r"\(\s*[,;.-]?\s*\)", "", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def capitalize_sentence(text: str) -> str:
    """Garante que a primeira letra do texto seja maiúscula."""
    if not text:
        return text
    return text[0].upper() + text[1:]


def clean_element_text(tag) -> str:
    """Extrai texto com espaçamento correto entre tags filhas (evita palavras coladas)."""
    raw = tag.get_text(separator=" ", strip=True)
    return capitalize_sentence(sanitize_text(raw))


def _try_extract_verse(text: str) -> tuple[str, str] | None:
    """
    Testa se o texto termina com uma referência bíblica.
    Retorna (verse_text, verse_reference) ou None se não houver match.
    """
    match = VERSE_END_REGEX.search(text)
    if not match:
        return None
    reference = (match.group(1) or match.group(2)).strip()
    raw_verse = text[: match.start()].strip(' \""".()')
    verse_text = capitalize_sentence(sanitize_text(raw_verse))
    if not verse_text:
        return None
    return verse_text, reference


def _remove_drop_cap_spans(el) -> None:
    """
    Remove spans de letra capitulada (drop cap) como <span class="s1">L</span>
    emendando a letra diretamente no texto do elemento pai, evitando "L íderes..." → "Líderes...".
    """
    for span in el.find_all("span", class_=re.compile(r"^s\d+$")):
        letter = span.get_text(strip=True)
        span.replace_with(letter)


def get_today_devotional_url(archive_url: str) -> tuple[str, date]:
    """Varre o agregador semanal e encontra o link do dia."""
    resp = requests.get(archive_url, headers=HEADERS, timeout=15)
    if resp.status_code != 200:
        raise ValueError(f"Erro {resp.status_code} ao abrir {archive_url}")

    soup = BeautifulSoup(resp.text, "html.parser")
    today = date.today()
    mes_abrev = MESES[today.month]

    pattern_1 = f"{today.day}/{mes_abrev}".lower()
    pattern_2 = f"{today.day:02d}/{mes_abrev}".lower()

    links = []
    for a in soup.find_all("a", href=True):
        href = a["href"]
        text = a.get_text(strip=True).lower()
        if "/meditacao/" in href and not href.endswith("/meditacao/"):
            links.append((text, href))
            if pattern_1 in text or pattern_2 in text:
                return href, today

    if links:
        return links[-1][1], today

    raise ValueError(f"Nenhum link encontrado em {archive_url}")


def parse_devotional_page(url: str, pub_date: date) -> dict:
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.encoding = "utf-8"
    soup = BeautifulSoup(resp.text, "html.parser")

    # ------------------------------------------------------------------
    # 1. Título
    #    O site usa: <title>CPB mais | Veneno para as relações afetivas</title>
    #    O título real está na ÚLTIMA parte do split por "|".
    # ------------------------------------------------------------------
    title = "Meditação Diária"
    if soup.title and soup.title.string:
        parts = [p.strip() for p in soup.title.string.split("|") if p.strip()]
        if len(parts) >= 2:
            title = parts[-1]
        elif parts:
            title = parts[0]

    # Sobrescreve com o título do DOM se disponível (mais confiável)
    title_div = soup.find("div", class_="titleMeditacao")
    if title_div:
        t = clean_element_text(title_div)
        if t:
            title = t

    # ------------------------------------------------------------------
    # 2. Versículo-chave
    #    O site CPB tem uma div específica: class="descriptionText versoBiblico"
    #    Exemplo: "Ora, as obras da carne... Gálatas 5:19, 20"
    # ------------------------------------------------------------------
    verse_text = ""
    verse_reference = ""

    verso_div = soup.find("div", class_="versoBiblico")
    if verso_div:
        verso_raw = sanitize_text(verso_div.get_text(separator=" ", strip=True))
        if verso_raw:
            result = _try_extract_verse(verso_raw)
            if result:
                verse_text, verse_reference = result
            else:
                # Texto sem referência detectável — preserva o texto inteiro
                verse_text = capitalize_sentence(verso_raw)

    # ------------------------------------------------------------------
    # 3. Corpo do texto
    #    Container específico: <div class="conteudoMeditacao">
    #    Fallback: <article> → <main> → <body>
    # ------------------------------------------------------------------
    content_div = soup.find("div", class_="conteudoMeditacao")
    container = content_div or soup.find("article") or soup.find("main") or soup.body

    body_paragraphs: list[str] = []
    seen: set[str] = set()

    for el in container.find_all(["p", "blockquote", "h2", "h3"]):
        # Corrige letra capitulada: <span class="s1">L</span>íderes → Líderes
        _remove_drop_cap_spans(el)

        txt = clean_element_text(el)
        if not txt or len(txt) < 4:
            continue
        # Filtra metadados de navegação do site
        if re.search(r"^(segunda|terça|quarta|quinta|sexta|sábado|domingo)[-\s]feira", txt, re.I):
            continue
        if re.search(r"^\d{1,2}\s+de\s+[a-z]+", txt, re.I):
            continue
        if txt == title:
            continue
        # Evita duplicatas
        key = txt[:120]
        if key in seen:
            continue
        seen.add(key)
        body_paragraphs.append(txt)

    # ------------------------------------------------------------------
    # 4. Fallback de versículo: se não achamos via div.versoBiblico,
    #    testa os primeiros 5 parágrafos do corpo.
    # ------------------------------------------------------------------
    if not verse_text:
        remaining: list[str] = []
        for i, text in enumerate(body_paragraphs):
            if not verse_text and i < 5:
                result = _try_extract_verse(text)
                if result:
                    verse_text, verse_reference = result
                    continue
            remaining.append(text)
        body_paragraphs = remaining

    # ------------------------------------------------------------------
    # 5. Remove do corpo parágrafos que duplicam o versículo
    # ------------------------------------------------------------------
    if verse_text:
        body_paragraphs = [
            p for p in body_paragraphs
            if not (verse_text[:40] in p and len(p) < len(verse_text) + 60)
        ]

    # ------------------------------------------------------------------
    # 6. Autor no rodapé (bloco curto sem ponto final)
    # ------------------------------------------------------------------
    author = ""
    if body_paragraphs and len(body_paragraphs[-1].split()) <= 4 and not body_paragraphs[-1].endswith("."):
        author = body_paragraphs.pop()

    return {
        "published_at": pub_date.isoformat(),
        "title": title,
        "verse_text": verse_text,
        "verse_reference": verse_reference,
        "content": "\n\n".join(body_paragraphs),
        "author": author,
        "source_url": url,
    }


def main(dry_run: bool = False) -> None:
    """
    Processa e salva as meditações do dia de todas as categorias.

    Args:
        dry_run: Se True, imprime os dados sem salvar no Supabase.
                 Ative passando --dry-run na linha de comando.
    """
    if not dry_run and (not DEVOTIONAL_SUPABASE_URL or not DEVOTIONAL_SUPABASE_KEY):
        raise ValueError(
            "URL do Supabase (DEVOTIONAL_SUPABASE_URL ou SUPABASE_URL) ou "
            "Service Role Key ausentes.\n"
            "Para testar sem credenciais, use: python meditacao.py --dry-run"
        )

    supabase: Client | None = None
    if not dry_run:
        supabase = create_client(DEVOTIONAL_SUPABASE_URL, DEVOTIONAL_SUPABASE_KEY)

    for categoria, archive_url in CATEGORIAS.items():
        try:
            print(f"\n--- Processando categoria: {categoria.upper()} ---")
            post_url, pub_date = get_today_devotional_url(archive_url)
            data = parse_devotional_page(post_url, pub_date)
            data["category"] = categoria

            print(f"  Título     : {data['title']}")
            print(f"  Referência : {data['verse_reference'] or '(não encontrada)'}")
            verse_preview = (data["verse_text"][:80] + "...") if len(data["verse_text"]) > 80 else data["verse_text"]
            print(f"  Versículo  : {verse_preview or '(não encontrado)'}")
            print(f"  Autor      : {data['author'] or '(sem autor detectado)'}")
            print(f"  Parágrafos : {len(data['content'].split(chr(10)*2))}")
            print(f"  URL        : {post_url}")

            if dry_run:
                print("  [DRY-RUN] Dados NÃO foram salvos no Supabase.")
            else:
                supabase.table("daily_devotionals").upsert(
                    data, on_conflict="published_at,category"
                ).execute()
                print(f"  ✓ Salvo com sucesso: {categoria}")

        except Exception as err:
            print(f"  ✗ Erro na categoria '{categoria}': {err}")


if __name__ == "__main__":
    is_dry_run = "--dry-run" in sys.argv
    if is_dry_run:
        print("=== MODO DRY-RUN: nenhum dado será salvo no Supabase ===")
    main(dry_run=is_dry_run)