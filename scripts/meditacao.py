import os
import re
from datetime import date
import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client

SUPABASE_URL = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8",
}

MESES = {
    1: "jan", 2: "fev", 3: "mar", 4: "abr", 5: "mai", 6: "jun",
    7: "jul", 8: "ago", 9: "set", 10: "out", 11: "nov", 12: "dez"
}

def get_today_devotional_url() -> tuple[str, date]:
    """Varre o agregador e encontra o botão correspondente à data de hoje."""
    archive_url = "https://mais.cpb.com.br/devocional-jovem-ano/"
    print(f"Consultando página agregadora: {archive_url}")
    resp = requests.get(archive_url, headers=HEADERS, timeout=15)
    
    if resp.status_code != 200:
        raise ValueError(f"Erro HTTP {resp.status_code} ao abrir o agregador.")

    soup = BeautifulSoup(resp.text, "html.parser")
    today = date.today()
    mes_abrev = MESES[today.month]
    
    # Padrões possíveis: "15/set" ou "05/set"
    date_pattern_1 = f"{today.day}/{mes_abrev}".lower()
    date_pattern_2 = f"{today.day:02d}/{mes_abrev}".lower()

    meditation_links = []

    for a in soup.find_all("a", href=True):
        href = a["href"]
        text = a.get_text(strip=True).lower()
        
        if "/meditacao/" in href and not href.endswith("/meditacao/"):
            meditation_links.append((text, href))
            # Se o texto do botão contiver a data de hoje (ex: 'Ter 15/set')
            if date_pattern_1 in text or date_pattern_2 in text:
                print(f"Encontrado botão para hoje ('{a.get_text(strip=True)}'): {href}")
                return href, today

    # Fallback: Se não achar o botão do dia exato, pega o último botão disponível
    if meditation_links:
        last_text, last_href = meditation_links[-1]
        print(f"Aviso: Data exata ({date_pattern_2}) não encontrada. Usando o mais recente ('{last_text}'): {last_href}")
        return last_href, today

    raise ValueError("Nenhum link de meditação encontrado na página.")

def parse_devotional_page(url: str, pub_date: date) -> dict:
    print(f"Baixando devocional: {url}")
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.encoding = "utf-8"
    soup = BeautifulSoup(resp.text, "html.parser")

    # 1. Título correto (via tag title para evitar pegar 'Lições')
    title = "Meditação Jovem"
    if soup.title and soup.title.string:
        clean_title = soup.title.string.split("|")[-1].strip()
        if clean_title:
            title = clean_title

    # 2. Área do conteúdo
    article = soup.find("article") or soup.find("div", class_=re.compile(r"content|post|entry")) or soup.body
    paragraphs = [p.get_text(strip=True) for p in article.find_all("p") if p.get_text(strip=True)]

    verse_text = ""
    verse_reference = ""
    author = ""
    body = []

    for p in paragraphs:
        # Padrão bíblico para o versículo-chave (Ex: Jr 29:11, 1Pe 1:20)
        ref_match = re.search(r"([1-3]?\s?[A-Za-zÀ-ÿ]{2,}\s+\d+:\d+(?:-\d+)?)", p)
        if not verse_text and ref_match:
            verse_reference = ref_match.group(1)
            verse_text = p.replace(verse_reference, "").strip(' "“”.')
        else:
            body.append(p)

    if body and len(body[-1].split()) <= 4 and not body[-1].endswith("."):
        author = body.pop()

    return {
        "published_at": pub_date.isoformat(),
        "title": title,
        "verse_text": verse_text,
        "verse_reference": verse_reference,
        "content": "\n\n".join(body),
        "author": author,
        "source_url": url,
    }

def main():
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY não configuradas.")

    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

    post_url, pub_date = get_today_devotional_url()
    data = parse_devotional_page(post_url, pub_date)

    print(f"Pronto: '{data['title']}' | Ref: {data['verse_reference']} | Data: {data['published_at']}")

    supabase.table("daily_devotionals").upsert(data, on_conflict="published_at").execute()
    print("Salvo com sucesso no Supabase!")

if __name__ == "__main__":
    main()
