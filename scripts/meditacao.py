import os
import re
from datetime import date
import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

def get_today_devotional_url() -> str:
    """Obtém a URL do devocional de hoje via redirecionamento ou link da página de salto."""
    hub_url = "https://mais.cpb.com.br/meditacao-jovem-hoje/"
    resp = requests.get(hub_url, headers=HEADERS, allow_redirects=True, timeout=15)
    
    # Se redirecionou diretamente para o post
    if "/meditacao/" in resp.url and resp.url != hub_url:
        return resp.url

    # Fallback: extrai do link na página intermediária
    soup = BeautifulSoup(resp.text, "html.parser")
    for a in soup.find_all("a", href=True):
        if "/meditacao/" in a["href"]:
            return a["href"]

    raise ValueError("Não foi possível localizar o link do devocional do dia.")

def parse_devotional(url: str) -> dict:
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.encoding = "utf-8"
    soup = BeautifulSoup(resp.text, "html.parser")

    # 1. Título
    title_tag = soup.find("h1") or soup.find("title")
    title = title_tag.get_text(strip=True).replace("CPB mais |", "").strip() if title_tag else "Sem Título"

    # 2. Conteúdo principal
    # Procura a tag principal do texto (article, main ou container de texto)
    article = soup.find("article") or soup.find("div", class_=re.compile(r"content|post|entry"))
    if not article:
        article = soup.body

    paragraphs = [p.get_text(strip=True) for p in article.find_all("p") if p.get_text(strip=True)]

    # 3. Extração de versículo e corpo
    verse_text = ""
    verse_reference = ""
    author = ""
    body_paragraphs = []

    for i, p in enumerate(paragraphs):
        # Geralmente os primeiros parágrafos contêm o texto bíblico com referência (Ex: Mateus 5:39)
        ref_match = re.search(r"([1-3]?\s?[A-Za-zÀ-ÿ]+ \d+:\d+(?:-\d+)?)", p)
        if not verse_text and ref_match:
            verse_reference = ref_match.group(1)
            verse_text = p.replace(verse_reference, "").strip(' "“”.')
        else:
            body_paragraphs.append(p)

    if body_paragraphs:
        # Frequentemente o autor é a última linha curta
        last_line = body_paragraphs[-1]
        if len(last_line.split()) <= 4 and not last_line.endswith("."):
            author = body_paragraphs.pop()

    content = "\n\n".join(body_paragraphs)

    return {
        "published_at": date.today().isoformat(),
        "title": title,
        "verse_text": verse_text,
        "verse_reference": verse_reference,
        "content": content,
        "author": author,
        "source_url": url,
    }

def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("Variáveis de ambiente do Supabase não configuradas.")

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    print("Obtendo devocional do dia...")
    url = get_today_devotional_url()
    print(f"URL encontrada: {url}")

    data = parse_devotional(url)
    print(f"Devocional processado: {data['title']} ({data['published_at']})")

    # Upsert no Supabase usando a constraint de published_at
    res = supabase.table("daily_devotionals").upsert(data, on_conflict="published_at").execute()
    print("Salvo com sucesso no Supabase!")

if __name__ == "__main__":
    main()