#!/usr/bin/env python3
"""
upload_bibles_r2.py
-------------------
Baixa as versões bíblicas listadas em assets/manifest.json, gera o banco
AVM.sqlite.gz (Bíblia Ave Maria Católica + Livro de Enoque) no schema do app
e faz upload para a pasta `biblias/` do bucket Cloudflare R2.

Uso:
  # Apenas gerar/baixar localmente em build_cache/biblias/:
  .venv/bin/python3 scripts/upload_bibles_r2.py

  # Gerar/baixar e subir para o Cloudflare R2 (lê .env / .env.r2):
  .venv/bin/python3 scripts/upload_bibles_r2.py --upload
"""

import argparse
import gzip
import json
import os
import re
import sqlite3
import sys
import urllib.request
from pathlib import Path

try:
    import boto3
    from botocore.config import Config
    HAS_BOTO3 = True
except ImportError:
    HAS_BOTO3 = False


def load_env_file(env_path: Path) -> None:
    if not env_path.exists():
        return
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("export "):
                line = line[len("export "):].strip()
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                if key and key not in os.environ:
                    os.environ[key] = val


def get_s3_client():
    endpoint_url = os.environ.get("R2_ENDPOINT_URL")
    access_key = os.environ.get("R2_ACCESS_KEY_ID")
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY")
    if not (endpoint_url and access_key and secret_key):
        return None
    if not HAS_BOTO3:
        print("[AVISO] boto3 não instalado. Execute: pip install boto3", file=sys.stderr)
        return None
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
    )


def download_file(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "KairosR2Sync/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp, open(dest, "wb") as out:
        out.write(resp.read())


def fetch_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "KairosR2Sync/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read().decode("utf-8-sig", errors="replace")


def build_avm_sqlite_gz(dest_gz: Path) -> None:
    """Constrói AVM.sqlite.gz a partir do JSON da Bíblia Ave Maria + 1 Enoque."""
    print("[AVM] Baixando JSON da Bíblia Ave Maria...")
    avm_urls = [
        "https://raw.githubusercontent.com/fidalgobr/bibliaAveMariaJSON/main/bibliaAveMaria.json",
        "https://raw.githubusercontent.com/fidalgobr/bibliaAveMariaJSON/master/bibliaAveMaria.json",
    ]
    data = None
    for url in avm_urls:
        try:
            data = json.loads(fetch_text(url))
            break
        except Exception as e:
            print(f"[AVM] Falha em {url}: {e}")

    if data is None:
        raise RuntimeError("Não foi possível baixar o JSON da Bíblia Ave Maria.")

    db_path = dest_gz.with_suffix("")  # AVM.sqlite
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute(
        "CREATE TABLE book (id INTEGER PRIMARY KEY, name TEXT NOT NULL, testament_reference_id INTEGER NOT NULL)"
    )
    cur.execute(
        "CREATE TABLE verse (id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER NOT NULL, chapter INTEGER NOT NULL, verse INTEGER NOT NULL, text TEXT NOT NULL)"
    )

    def insert_books(books_list, testament_ref: int, start_id: int) -> int:
        book_id = start_id
        for b in books_list:
            name = b.get("nome") or b.get("name") or f"Livro {book_id}"
            cur.execute(
                "INSERT INTO book (id, name, testament_reference_id) VALUES (?, ?, ?)",
                (book_id, name, testament_ref),
            )
            chapters = b.get("capitulos") or b.get("chapters") or []
            for ch_idx, ch in enumerate(chapters, start=1):
                if isinstance(ch, dict):
                    ch_num = int(ch.get("capitulo", ch_idx))
                    verses = ch.get("versiculos") or []
                    for v_idx, v in enumerate(verses, start=1):
                        if isinstance(v, dict):
                            v_num = int(v.get("versiculo", v_idx))
                            v_text = str(v.get("texto", "")).strip()
                        else:
                            v_num = v_idx
                            v_text = str(v).strip()
                        if v_text:
                            cur.execute(
                                "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
                                (book_id, ch_num, v_num, v_text),
                            )
                elif isinstance(ch, list):
                    for v_idx, v_text in enumerate(ch, start=1):
                        txt = str(v_text).strip()
                        if txt:
                            cur.execute(
                                "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
                                (book_id, ch_idx, v_idx, txt),
                            )
            book_id += 1
        return book_id

    if isinstance(data, dict):
        next_id = 1
        if "antigoTestamento" in data:
            next_id = insert_books(data["antigoTestamento"], 1, next_id)
        if "novoTestamento" in data:
            next_id = insert_books(data["novoTestamento"], 2, next_id)
    elif isinstance(data, list):
        # Formato lista sequencial (ex: 46 VT + 27 NT = 73 livros católicos)
        for idx, b in enumerate(data, start=1):
            testament_ref = 1 if idx <= 46 else 2
            insert_books([b], testament_ref, idx)

    # Adiciona Livro de Enoque (ID 99, testament_reference_id 3)
    try:
        print("[AVM] Baixando texto do Livro de Enoque (Internet Archive)...")
        enoch_txt = fetch_text(
            "https://archive.org/download/primeiro-livro-de-enoque/primeiro-livro-de-enoque_djvu.txt"
        )
        chapters = re.split(r"(?:CAP[ÍI]TULO|Cap[íi]tulo)\s+(\d+)", enoch_txt)
        if len(chapters) > 3:
            cur.execute(
                "INSERT INTO book (id, name, testament_reference_id) VALUES (?, ?, ?)",
                (99, "Livro de Enoque", 3),
            )
            for i in range(1, len(chapters) - 1, 2):
                ch_num = int(chapters[i])
                body = chapters[i + 1].strip()
                paras = [p.strip() for p in re.split(r"\n\s*\n", body) if p.strip()]
                for v_idx, p in enumerate(paras, start=1):
                    clean_p = re.sub(r"\s+", " ", p)
                    cur.execute(
                        "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
                        (99, ch_num, v_idx, clean_p),
                    )
            print("[AVM] Livro de Enoque adicionado ao banco AVM.")
    except Exception as e:
        print(f"[AVM] Aviso: não foi possível incluir Livro de Enoque: {e}")

    cur.execute("CREATE INDEX idx_verse_book_chapter ON verse(book_id, chapter)")
    conn.commit()
    conn.close()

    with open(db_path, "rb") as f_in, gzip.open(dest_gz, "wb", compresslevel=9) as f_out:
        f_out.writelines(f_in)
    db_path.unlink()
    print(f"[AVM] Gerado com sucesso: {dest_gz} ({dest_gz.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Sincroniza Bíblias do manifest.json com o Cloudflare R2.")
    parser.add_argument("--upload", action="store_true", help="Faz upload dos arquivos para o bucket R2.")
    args = parser.parse_args()

    root_dir = Path(__file__).resolve().parent.parent
    load_env_file(root_dir / ".env.r2")
    load_env_file(root_dir / ".env")

    manifest_path = root_dir / "assets" / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))

    cache_dir = root_dir / "build_cache" / "biblias"
    cache_dir.mkdir(parents=True, exist_ok=True)

    s3 = get_s3_client() if args.upload else None
    bucket = os.environ.get("R2_BUCKET_NAME", "kairos-hinario-audio")
    if args.upload and s3 is None:
        sys.exit("Erro: configure R2_ENDPOINT_URL, R2_ACCESS_KEY_ID e R2_SECRET_ACCESS_KEY.")

    for mod in manifest.get("modules", []):
        mod_id = mod.get("id", "")
        file_name = mod.get("file", "")
        url = mod.get("url", "")
        if not file_name.endswith(".sqlite.gz"):
            continue

        dest = cache_dir / file_name
        if not dest.exists():
            if mod_id == "AVM":
                build_avm_sqlite_gz(dest)
            else:
                print(f"[{mod_id}] Baixando {url}...")
                download_file(url, dest)
        else:
            print(f"[{mod_id}] Já em cache: {dest.name}")

        if args.upload and s3 is not None:
            s3_key = f"biblias/{file_name}"
            print(f"[{mod_id}] Enviando para r2://{bucket}/{s3_key}...")
            s3.upload_file(
                str(dest),
                bucket,
                s3_key,
                ExtraArgs={"ContentType": "application/gzip"},
            )

    print("Concluído!")


if __name__ == "__main__":
    main()
