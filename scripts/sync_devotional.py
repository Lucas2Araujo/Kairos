import os
import re
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

def sanitize_text(text: str) -> str:
    """Limpa pontuação órfã, parênteses vazios e normaliza espaçamento."""
    # Remove parênteses vazios ou com pontuação solta residual: (), ( ), (, )
    text = re.sub(r"\(\s*[,;.-]?\s*\)", "", text)
    # Remove espaço antes de pontuação (ex: 'palavra .' -> 'palavra.')
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    # Normaliza múltiplos espaços
    text = re.sub(r"\s+", " ", text)
    return text.strip()

def clean_element_text(tag) -> str:
    """Extrai texto com espaçamento correto entre tags filhas (evita palavras coladas)."""
    raw = tag.get_text(separator=" ", strip=True)
    return sanitize_text(raw)

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

    # 1. Título Limpo
    title = "Meditação Diária"
    if soup.title and soup.title.string:
        t = soup.title.string.split("|")[-1].strip()
        if t:
            title = t

    # 2. Container do post
    container = (
        soup.find("article")
        or soup.find("main")
        or soup.find("div", class_=re.compile(r"post|content|entry|singular", re.I))
        or soup.body
    )

    # 3. Coleta blocos de texto
    raw_blocks = container.find_all(["p", "blockquote", "h2", "h3", "em"])
    all_texts = []
    seen = set()

    for el in raw_blocks:
        txt = clean_element_text(el)
        if not txt or txt in seen or len(txt) < 4:
            continue
        if re.search(r"^(segunda|terça|quarta|quinta|sexta|sábado|domingo)-feira", txt, re.I):
            continue
        if re.search(r"^\d{1,2}\s+de\s+[a-z]+", txt, re.I):
            continue
        if txt == title:
            continue

        seen.add(txt)
        all_texts.append(txt)

    verse_text = ""
    verse_reference = ""
    body_paragraphs = []

    # Regex que abrange:
    # 1. Referência entre parênteses: "... texto. (2 Samuel 21:10)" -> engloba os parênteses
    # 2. Referência sem parênteses:   "... texto. 2 Samuel 21:10"
    verse_end_regex = re.compile(
        r"(?:\(\s*([1-3]?\s?[A-Za-zÀ-ÿ]{2,}\s+\d+:\d+(?:[–\-]\d+)?(?:\s*,\s*\d+)?)\s*\)|([1-3]?\s?[A-Za-zÀ-ÿ]{2,}\s+\d+:\d+(?:[–\-]\d+)?(?:\s*,\s*\d+)?))\.?\s*$"
    )

    for i, text in enumerate(all_texts):
        # Apenas os primeiros blocos no topo são candidatos a versículo-chave
        if not verse_text and i < 3:
            match = verse_end_regex.search(text)
            if match:
                verse_reference = (match.group(1) or match.group(2)).strip()
                # Remove o trecho casado (incluindo parênteses se houver) e limpa as bordas
                raw_verse = text[:match.start()].strip(' "“”.()')
                verse_text = sanitize_text(raw_verse)
                continue

        body_paragraphs.append(sanitize_text(text))

    # Autor no rodapé
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

def main():
    if not DEVOTIONAL_SUPABASE_URL or not DEVOTIONAL_SUPABASE_KEY:
        raise ValueError("DEVOTIONAL_SUPABASE_URL ou DEVOTIONAL_SUPABASE_SERVICE_ROLE_KEY ausentes.")

    supabase: Client = create_client(DEVOTIONAL_SUPABASE_URL, DEVOTIONAL_SUPABASE_KEY)

    for categoria, archive_url in CATEGORIAS.items():
        try:
            print(f"\n--- Processando categoria: {categoria.upper()} ---")
            post_url, pub_date = get_today_devotional_url(archive_url)
            data = parse_devotional_page(post_url, pub_date)
            data["category"] = categoria

            print(f"Título: {data['title']}")
            print(f"Versículo ({data['verse_reference']}): {data['verse_text'][:60]}...")

            supabase.table("daily_devotionals").upsert(
                data, on_conflict="published_at,category"
            ).execute()
            print(f"Salvo com sucesso: {categoria}")

        except Exception as err:
            print(f"Erro na categoria '{categoria}': {err}")

if __name__ == "__main__":
    main()