import os
import re
from datetime import date
import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,application/json,*/*;q=0.8",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
}

def clean_html_text(raw_html: str) -> str:
    soup = BeautifulSoup(raw_html, "html.parser")
    return soup.get_text(separator="\n", strip=True)

def fetch_from_wp_api() -> dict | None:
    """Tenta obter a meditação mais recente via WP REST API."""
    api_url = "https://mais.cpb.com.br/wp-json/wp/v2/meditacao?per_page=1&order=desc&orderby=date"
    try:
        print(f"Tentando API do WordPress: {api_url}")
        resp = requests.get(api_url, headers=HEADERS, timeout=15)
        print(f"Status da API: {resp.status_code}")
        
        if resp.status_code == 200:
            posts = resp.json()
            if posts and isinstance(posts, list):
                post = posts[0]
                title = clean_html_text(post.get("title", {}).get("rendered", ""))
                content_html = post.get("content", {}).get("rendered", "")
                link = post.get("link", "")
                
                return parse_content_payload(title, content_html, link)
    except Exception as e:
        print(f"Falha ao consultar WP REST API: {e}")
    return None

def fetch_from_archive_page() -> str:
    """Fallback: obtém o link do dia a partir da página do devocional jovem."""
    archive_url = "https://mais.cpb.com.br/devocional-jovem-ano/"
    print(f"Consultando página agregadora: {archive_url}")
    resp = requests.get(archive_url, headers=HEADERS, timeout=15)
    print(f"Status do agregador: {resp.status_code}")

    if resp.status_code != 200:
        raise ValueError(f"Servidor retornou erro {resp.status_code} para {archive_url}. Resposta: {resp.text[:300]}")

    soup = BeautifulSoup(resp.text, "html.parser")
    # Procura o primeiro link que aponta para /meditacao/
    for a in soup.find_all("a", href=True):
        href = a["href"]
        if "/meditacao/" in href and not href.endswith("/meditacao/"):
            return href

    raise ValueError("Nenhum link de meditação encontrado em /devocional-jovem-ano/")

def parse_content_payload(title: str, content_html: str, source_url: str) -> dict:
    soup = BeautifulSoup(content_html, "html.parser")
    paragraphs = [p.get_text(strip=True) for p in soup.find_all("p") if p.get_text(strip=True)]

    verse_text = ""
    verse_reference = ""
    author = ""
    body = []

    for p in paragraphs:
        ref_match = re.search(r"([1-3]?\s?[A-Za-zÀ-ÿ]+ \d+:\d+(?:-\d+)?)", p)
        if not verse_text and ref_match:
            verse_reference = ref_match.group(1)
            verse_text = p.replace(verse_reference, "").strip(' "“”.')
        else:
            body.append(p)

    if body and len(body[-1].split()) <= 4 and not body[-1].endswith("."):
        author = body.pop()

    return {
        "published_at": date.today().isoformat(),
        "title": title,
        "verse_text": verse_text,
        "verse_reference": verse_reference,
        "content": "\n\n".join(body),
        "author": author,
        "source_url": source_url,
    }

def fetch_and_parse_html(url: str) -> dict:
    print(f"Baixando HTML da página: {url}")
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.encoding = "utf-8"
    soup = BeautifulSoup(resp.text, "html.parser")

    title_tag = soup.find("h1") or soup.find("title")
    title = title_tag.get_text(strip=True).replace("CPB mais |", "").strip() if title_tag else "Sem Título"

    article = soup.find("article") or soup.find("div", class_=re.compile(r"content|post|entry")) or soup.body
    return parse_content_payload(title, str(article), url)

def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY ausentes no ambiente.")

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    # 1. Tenta API do WordPress
    data = fetch_from_wp_api()

    # 2. Se a API não responder, faz scraping pelo agregador do ano
    if not data:
        print("API indisponível ou vazia. Recorrendo ao agregador web...")
        post_url = fetch_from_archive_page()
        print(f"Link identificado: {post_url}")
        data = fetch_and_parse_html(post_url)

    print(f"Devocional pronto: '{data['title']}' | Versículo: {data['verse_reference']}")

    # 3. Salva no Supabase via Upsert pela data
    supabase.table("daily_devotionals").upsert(data, on_conflict="published_at").execute()
    print("Salvo com sucesso no Supabase!")

if __name__ == "__main__":
    main()
