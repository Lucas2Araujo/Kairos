import json
import re
import subprocess
import sys
import urllib.request
import sqlite3

MONTHS_MAP = {
    "JANEIRO": "01",
    "FEVEREIRO": "02",
    "MARÇO": "03",
    "ABRIL": "04",
    "MAIO": "05",
    "JUNHO": "06",
    "JULHO": "07",
    "AGOSTO": "08",
    "SETEMBRO": "09",
    "OUTUBRO": "10",
    "NOVEMBRO": "11",
    "DEZEMBRO": "12",
}

def fetch_meditations(year: int) -> list[dict]:
    # 1. Busca dinâmica na API oficial de downloads da DSA
    api_url = f"https://downloads.adventistas.org/pt/wp-json/wp/v2/posts?search=P%C3%B4r+do+Sol+{year}"
    req = urllib.request.Request(api_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        posts = json.load(resp)

    pdf_url = None
    for post in posts:
        title = post.get("title", {}).get("rendered", "")
        if "medita" not in title.lower() and len(posts) > 1:
            continue
        for item in post.get("acf", {}).get("downloads", []):
            if item.get("format") == "PDF" and any(k in item.get("name", "").lower() for k in ["livro", "livreto", "medita"]):
                pdf_url = item.get("link")
                break
        if pdf_url:
            break

    if not pdf_url:
        for post in posts:
            for item in post.get("acf", {}).get("downloads", []):
                if item.get("format") == "PDF":
                    pdf_url = item.get("link")
                    break
            if pdf_url:
                break

    if not pdf_url:
        raise ValueError(f"Livro de meditações para o ano {year} não encontrado na API.")

    print(f"Baixando PDF oficial de {year}: {pdf_url}")
    # 2. Download direto para a memória
    pdf_req = urllib.request.Request(pdf_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(pdf_req) as resp:
        pdf_bytes = resp.read()

    # 3. Extração com preservação de layout (pdftotext -layout) para identificar parágrafos e quebras reais
    proc = subprocess.run(["pdftotext", "-layout", "-", "-"], input=pdf_bytes, capture_output=True, check=True)
    pages = proc.stdout.decode("utf-8", errors="ignore").split("\x0c")

    # 4. Estruturação das meditações semanais
    months_pattern = r"(?:JANEIRO|FEVEREIRO|MARÇO|ABRIL|MAIO|JUNHO|JULHO|AGOSTO|SETEMBRO|OUTUBRO|NOVEMBRO|DEZEMBRO)"
    date_regex = re.compile(rf"(\d{{1,2}})\s*(?:\n+)?\s*DE\s+({months_pattern})", re.IGNORECASE)
    verse_ref_pattern = re.compile(
        r"((?:(?:[1-3]|I{1,3})\s*)?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)?\s+\d+\s*[:.]\s*\d+(?:[-–—]\d+)?)\s*$",
        re.IGNORECASE,
    )
    footer_line_re = re.compile(
        r"(?:Medita[çc][ãa]o\s+Por\s+do\s+Sol|\d{1,2}/\d{1,2}/\d{4}|\bP[0-9]+\b|^\s*\d+\s*$)",
        re.IGNORECASE,
    )

    meditations = []
    for page in pages:
        match = date_regex.search(page)
        if not match:
            continue

        day_num = int(match.group(1))
        month_name = match.group(2).upper().strip()
        month_num = MONTHS_MAP.get(month_name, "01")
        published_at = f"{year}-{month_num}-{day_num:02d}"

        raw_lines = page[match.end():].splitlines()
        clean_lines = [l for l in raw_lines if not footer_line_re.search(l) and l.strip()]

        if len(clean_lines) < 3:
            continue

        # Localiza o versículo e a referência bíblica
        ref_idx = -1
        verse_ref = ""
        for idx, l in enumerate(clean_lines[:10]):
            rm = verse_ref_pattern.search(l)
            if rm:
                ref_idx = idx
                verse_ref = rm.group(1).strip()
                break

        if ref_idx != -1:
            header_lines = [l.strip() for l in clean_lines[:ref_idx] if l.strip()]
            title_parts = []
            verse_parts = []
            for hl in header_lines:
                if hl.isupper() or not title_parts:
                    title_parts.append(hl)
                else:
                    verse_parts.append(hl)

            title = " ".join(title_parts).strip().title()

            last_vline = clean_lines[ref_idx].strip()
            v_text_end = last_vline.rfind(verse_ref)
            if v_text_end > 0:
                verse_parts.append(last_vline[:v_text_end].strip())
            verse_text = " ".join(verse_parts).strip()

            body_lines = clean_lines[ref_idx + 1:]
        else:
            title = clean_lines[0].strip().title()
            verse_text = clean_lines[1].strip()
            verse_ref = ""
            body_lines = clean_lines[2:]

        # Detecta capitular (drop cap)
        drop_cap = ""
        content_start = 0
        for idx, l in enumerate(body_lines[:6]):
            st = l.strip()
            if len(st) == 1 and st.isalpha():
                drop_cap = st
                content_start = idx + 1
                break

        filtered_content = body_lines[content_start:]

        # Reconstrói os parágrafos reais unindo quebras de linha duras do PDF
        paragraphs = []
        curr_p = []
        for l in filtered_content:
            # Indentação de 3 a 7 espaços na margem esquerda ou 'Agora reflita:' indica novo parágrafo
            is_p_start = bool(re.match(r"^[ ]{3,7}\S", l)) or l.strip().startswith("Agora reflita:")
            if is_p_start and curr_p:
                paragraphs.append(" ".join(curr_p).strip())
                curr_p = [l.strip()]
            else:
                st = l.strip()
                # Junta hifens de fim de linha (ex: "frequen-" + "tar" -> "frequentar")
                if curr_p and curr_p[-1].endswith("-") and not curr_p[-1].endswith("--"):
                    curr_p[-1] = curr_p[-1][:-1] + st
                elif curr_p:
                    curr_p.append(st)
                else:
                    curr_p.append(st)

        if curr_p:
            paragraphs.append(" ".join(curr_p).strip())

        if drop_cap and paragraphs:
            paragraphs[0] = drop_cap + paragraphs[0]

        # Junta os parágrafos com duas quebras de linha (padrão de todas as outras meditações)
        content = "\n\n".join(paragraphs)

        meditations.append({
            "published_at": published_at,
            "title": title,
            "verse_text": verse_text,
            "verse_reference": verse_ref,
            "content": content,
            "category": "pordosol",
            "author": "Pôr do Sol - DSA",
            "source_url": "https://downloads.adventistas.org/pt/materiais/meditacao-por-do-sol/",
        })

    return meditations

def populate_database(meditations: list[dict], db_path: str = "assets/hinario.db"):
    if not meditations:
        return 0

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    count = 0
    for m in meditations:
        cursor.execute(
            """
            INSERT INTO cached_devotionals (
                published_at, title, verse_text, verse_reference, content, category, author, source_url
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(published_at, category) DO UPDATE SET
                title = excluded.title,
                verse_text = excluded.verse_text,
                verse_reference = excluded.verse_reference,
                content = excluded.content,
                author = excluded.author,
                source_url = excluded.source_url;
            """,
            (
                m["published_at"],
                m["title"],
                m["verse_text"],
                m["verse_reference"],
                m["content"],
                m["category"],
                m["author"],
                m["source_url"],
            ),
        )
        count += 1

    conn.commit()
    conn.close()
    return count

if __name__ == "__main__":
    target_year = int(sys.argv[1]) if len(sys.argv) > 1 else 2026
    print(f"Buscando meditações para {target_year}...")
    results = fetch_meditations(target_year)
    out_file = f"meditacoes_{target_year}.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f"Sucesso! {len(results)} meditações salvas em {out_file}.")

    # Popula automaticamente no banco SQLite local do app
    inserted = populate_database(results)
    print(f"Banco local assets/hinario.db populado com {inserted} meditações do Pôr do Sol!")
