#!/usr/bin/env python3
"""
download_and_upload_r2.py
-------------------------
Script de extração em lote e upload para o Cloudflare R2 dos hinos adventistas
(Hinário Novo e Hinário Antigo).

Estrutura no Cloudflare R2:
  - novo/hino_{id}.m4a
  - antigo/hino_{id}.m4a

Uso:
  # Baixar localmente (sem upload):
  .venv/bin/python3 scripts/download_and_upload_r2.py

  # Testar apenas 2 hinos de cada hinário:
  .venv/bin/python3 scripts/download_and_upload_r2.py --limit 2

  # Fazer download e upload automático para o R2:
  export R2_BUCKET_NAME="kairos-hinario-audio"
  export R2_ENDPOINT_URL="https://<ACCOUNT_ID>.r2.cloudflarestorage.com"
  export R2_ACCESS_KEY_ID="<ACCESS_KEY_ID>"
  export R2_SECRET_ACCESS_KEY="<SECRET_ACCESS_KEY>"
  .venv/bin/python3 scripts/download_and_upload_r2.py --upload
"""

import argparse
import concurrent.futures
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

try:
    import boto3
    from botocore.config import Config
    HAS_BOTO3 = True
except ImportError:
    HAS_BOTO3 = False


def load_env_file(env_path: Path):
    """Carrega variáveis de um arquivo .env ou .env.r2 caso não estejam no ambiente."""
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


def extract_youtube_id(url: str) -> str | None:
    if not url:
        return None
    patterns = [
        r'(?:v=|\/)([0-9A-Za-z_-]{11}).*',
        r'(?:youtu\.be\/)([0-9A-Za-z_-]{11})',
        r'(?:embed\/)([0-9A-Za-z_-]{11})',
    ]
    for pattern in patterns:
        match = re.search(pattern, url)
        if match:
            return match.group(1)
    return None


def get_s3_client():
    endpoint_url = os.environ.get("R2_ENDPOINT_URL")
    access_key = os.environ.get("R2_ACCESS_KEY_ID")
    secret_key = os.environ.get("R2_SECRET_ACCESS_KEY")

    if not (endpoint_url and access_key and secret_key):
        return None

    if not HAS_BOTO3:
        print("[AVISO] boto3 não está instalado. Execute: pip install boto3", file=sys.stderr)
        return None

    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
    )


def process_hymn(hymn_info: dict, output_dir: Path, s3_client=None, bucket_name=None, upload: bool = False):
    edition = hymn_info["edition"]
    hymn_id = hymn_info["id"]
    numero = hymn_info["numero"]
    titulo = hymn_info["titulo"]
    link_video = hymn_info["link_video"]

    edition_dir = output_dir / edition
    edition_dir.mkdir(parents=True, exist_ok=True)

    dest_m4a = edition_dir / f"hino_{hymn_id}.m4a"
    s3_key = f"{edition}/hino_{hymn_id}.m4a"

    # Se o arquivo já existe localmente e é válido (> 50KB)
    downloaded = dest_m4a.exists() and dest_m4a.stat().st_size > 50000

    if not downloaded:
        video_id = extract_youtube_id(link_video)
        if not video_id:
            return {"status": "error", "id": hymn_id, "edition": edition, "msg": f"URL inválida: {link_video}"}

        yt_url = f"https://www.youtube.com/watch?v={video_id}"

        # Baixa diretamente o áudio com yt-dlp usando formato audio-only com fallback
        temp_pattern = str(edition_dir / f"temp_{hymn_id}.%(ext)s")
        ytdlp_cmd = [
            sys.executable, "-m", "yt_dlp",
            "-f", "ba[ext=m4a]/ba/b",
            "-x",
            "--audio-format", "m4a",
            "-o", temp_pattern,
            "--no-playlist",
            "--quiet",
            "--no-warnings",
            yt_url
        ]

        try:
            subprocess.run(ytdlp_cmd, check=True, capture_output=True, text=True)
            # yt-dlp gera temp_{hymn_id}.m4a
            temp_file = edition_dir / f"temp_{hymn_id}.m4a"
            if temp_file.exists():
                temp_file.replace(dest_m4a)
            else:
                # Caso a extensão gerada seja diferente, encontra e converte para m4a
                matching = list(edition_dir.glob(f"temp_{hymn_id}.*"))
                if matching:
                    subprocess.run(["ffmpeg", "-y", "-i", str(matching[0]), "-vn", "-c:a", "aac", str(dest_m4a)], check=True, capture_output=True)
                    matching[0].unlink()
                else:
                    return {"status": "error", "id": hymn_id, "edition": edition, "msg": "Arquivo temporário não encontrado após download"}
        except subprocess.CalledProcessError as e:
            for f in edition_dir.glob(f"temp_{hymn_id}.*"):
                f.unlink(missing_ok=True)
            return {"status": "error", "id": hymn_id, "edition": edition, "msg": f"yt-dlp falhou: {e.stderr.strip()[:100]}"}

    # Upload para o Cloudflare R2
    if upload and s3_client and bucket_name and dest_m4a.exists():
        try:
            s3_client.upload_file(
                str(dest_m4a),
                bucket_name,
                s3_key,
                ExtraArgs={"ContentType": "audio/mp4"}
            )
            return {"status": "ok", "id": hymn_id, "edition": edition, "numero": numero, "titulo": titulo, "uploaded": True}
        except Exception as e:
            return {"status": "error", "id": hymn_id, "edition": edition, "msg": f"Upload R2 falhou: {e}"}

    return {"status": "ok", "id": hymn_id, "edition": edition, "numero": numero, "titulo": titulo, "uploaded": False}


def load_hymns(db_path: str, edition: str, limit: int | None = None) -> list[dict]:
    if not os.path.exists(db_path):
        print(f"[ERRO] Banco {db_path} não encontrado.", file=sys.stderr)
        return []

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    query = "SELECT id, numero, titulo, link_video FROM hino WHERE link_video IS NOT NULL AND trim(link_video) != '' ORDER BY id ASC"
    if limit:
        query += f" LIMIT {limit}"

    rows = cursor.execute(query).fetchall()
    conn.close()

    hymns = []
    for r in rows:
        hymns.append({
            "id": r[0],
            "numero": r[1],
            "titulo": r[2],
            "link_video": r[3],
            "edition": edition,
        })
    return hymns


def main():
    parser = argparse.ArgumentParser(description="Extrai áudio dos hinos e envia ao Cloudflare R2.")
    parser.add_argument("--limit", type=int, default=None, help="Limita o número de hinos por hinário para testes.")
    parser.add_argument("--edition", choices=["novo", "antigo", "both"], default="both", help="Qual hinário processar.")
    parser.add_argument("--workers", type=int, default=4, help="Número de threads simultâneas.")
    parser.add_argument("--output-dir", type=str, default="downloads/r2_audio", help="Diretório de saída local.")
    parser.add_argument("--upload", action="store_true", help="Faz upload automático para o Cloudflare R2.")
    parser.add_argument("--only-missing", action="store_true", help="Processa apenas os hinos que ainda não estão no disco local.")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    output_dir = project_root / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    # Carrega automaticamente de .env.r2 ou .env se existirem
    load_env_file(project_root / ".env.r2")
    load_env_file(project_root / ".env")

    bucket_name = os.environ.get("R2_BUCKET_NAME")
    s3_client = None

    if args.upload:
        if not bucket_name:
            print("[ERRO] R2_BUCKET_NAME não definido no ambiente para upload.", file=sys.stderr)
            sys.exit(1)
        s3_client = get_s3_client()
        if not s3_client:
            print("[ERRO] Não foi possível inicializar o cliente S3 do R2. Verifique as variáveis R2_*.", file=sys.stderr)
            sys.exit(1)

    all_hymns = []
    if args.edition in ["novo", "both"]:
        novo_hymns = load_hymns(str(project_root / "assets/hinario.db"), "novo", args.limit)
        all_hymns.extend(novo_hymns)
    if args.edition in ["antigo", "both"]:
        antigo_hymns = load_hymns(str(project_root / "assets/hinario_antigo.db"), "antigo", args.limit)
        all_hymns.extend(antigo_hymns)

    if args.only_missing:
        filtered = []
        for h in all_hymns:
            dest_file = output_dir / h["edition"] / f"hino_{h['id']}.m4a"
            if not dest_file.exists() or dest_file.stat().st_size < 50000:
                filtered.append(h)
        all_hymns = filtered

    print(f"=== Processando {len(all_hymns)} hinos ({args.workers} workers) ===")
    print(f"Destino local: {output_dir}")
    if args.upload:
        print(f"Destino R2: bucket '{bucket_name}' via S3 API")

    success_count = 0
    error_count = 0

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {
            executor.submit(process_hymn, h, output_dir, s3_client, bucket_name, args.upload): h
            for h in all_hymns
        }

        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            res = future.result()
            if res["status"] == "ok":
                success_count += 1
                up_info = " [R2 Uploaded]" if res["uploaded"] else ""
                print(f"[{i}/{len(all_hymns)}] OK: ({res['edition']}) Hino {res['numero']} - {res['titulo']}{up_info}")
            else:
                error_count += 1
                print(f"[{i}/{len(all_hymns)}] FALHA: ({res['edition']}) Hino ID {res['id']}: {res['msg']}", file=sys.stderr)

    print(f"\nConcluído! Sucessos: {success_count} | Falhas: {error_count}")


if __name__ == "__main__":
    main()

