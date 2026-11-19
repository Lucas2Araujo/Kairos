#!/usr/bin/env python3
"""Sincronizador de livros de Ellen G. White em português (m.egwwritings.org -> R2).

Descobre recursivamente o acervo oficial a partir de:
  https://m.egwwritings.org/pt/folders/245
e resolve os livros do catálogo padrão do Kairós (`lib/services/egw_service.dart`),
gerando pacotes compactados individuais `books/<numeric_id>.json.gz` e o índice
`egw_manifest.json` prontos para envio ao Cloudflare R2.
"""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import gzip
import hashlib
import html as html_lib
from html.parser import HTMLParser
import http.cookiejar
import json
import os
from pathlib import Path
import random
import re
import shutil
import sys
import time
from typing import Any
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_FOLDER_URL = "https://m.egwwritings.org/pt/folders/245"
BASE_URL = "https://m.egwwritings.org"

# IDs numéricos conhecidos que anteriormente usavam slugs `pt_...` no app.
PRE_RESOLVED_NUMERIC_IDS: dict[str, str] = {
    "pt_evangelismo": "115",
    "pt_orientacao_crianca": "1505",
    "pt_obreiros_evangelicos": "72",
}

USER_AGENT = (
    "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
)


def normalize_text(value: str) -> str:
    """Remove acentos, pontuação e espaços extras para comparação de títulos."""
    decomposed = unicodedata.normalize("NFKD", value or "")
    ascii_only = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    lowered = ascii_only.lower()
    cleaned = re.sub(r"[^a-z0-9\s]", " ", lowered)
    return re.sub(r"\s+", " ", cleaned).strip()


def clean_html_text(raw_html: str) -> str:
    """Remove tags HTML, preserva espaçamento e decodifica entidades HTML."""
    if not raw_html:
        return ""
    no_scripts = re.sub(
        r"<(script|style)[^>]*>.*?</\1>", " ", raw_html, flags=re.IGNORECASE | re.DOTALL
    )
    # Remove marcadores internos de número de página/rodapé quando isolados em sup.
    no_sup = re.sub(r"<sup[^>]*class=[\"'][^\"']*footnote[^\"']*[\"'][^>]*>.*?</sup>", " ", no_scripts, flags=re.IGNORECASE | re.DOTALL)
    no_tags = re.sub(r"<[^>]+>", " ", no_sup)
    unescaped = html_lib.unescape(no_tags)
    return re.sub(r"\s+", " ", unescaped).strip()


class EgwHttpClient:
    """Cliente HTTP simples baseado na stdlib com cookies, retries e backoff."""

    def __init__(self, timeout: float = 25.0, min_delay: float = 0.25) -> None:
        self.timeout = timeout
        self.min_delay = min_delay
        self._jar = http.cookiejar.CookieJar()
        self._opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self._jar)
        )

    def fetch_text(self, url: str, retries: int = 3) -> str:
        last_error: Exception | None = None
        for attempt in range(retries):
            if attempt > 0:
                backoff = (2 ** attempt) + random.uniform(0.2, 0.9)
                time.sleep(backoff)
            elif self.min_delay > 0:
                time.sleep(self.min_delay * random.uniform(0.6, 1.3))

            req = urllib.request.Request(
                url,
                headers={
                    "User-Agent": USER_AGENT,
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.5",
                },
            )
            try:
                with self._opener.open(req, timeout=self.timeout) as resp:
                    status = getattr(resp, "status", 200)
                    raw_bytes = resp.read()
                    if status == 429 or status >= 500:
                        last_error = RuntimeError(f"HTTP {status} em {url}")
                        continue
                    charset = resp.headers.get_content_charset() or "utf-8"
                    return raw_bytes.decode(charset, errors="replace")
            except urllib.error.HTTPError as exc:
                last_error = exc
                if exc.code in (403, 404):
                    break
            except Exception as exc:
                last_error = exc
        raise RuntimeError(f"Falha ao buscar {url}: {last_error}")


def parse_dart_default_catalog(egw_service_path: Path) -> list[dict[str, str]]:
    """Extrai o catálogo padrão (`defaultCatalog`) de `lib/services/egw_service.dart`."""
    if not egw_service_path.exists():
        return []
    content = egw_service_path.read_text(encoding="utf-8")
    start_marker = "defaultCatalog = ["
    start_idx = content.find(start_marker)
    if start_idx < 0:
        return []
    end_idx = content.find("];", start_idx)
    if end_idx < 0:
        return []
    block = content[start_idx:end_idx]

    entries: list[dict[str, str]] = []
    obj_pattern = re.compile(r"\{([^{}]+)\}", re.DOTALL)
    kv_pattern = re.compile(
        r"['\"](id|title|abbr|desc|cpb_cover)['\"]\s*:\s*(['\"])(.*?)\2",
        re.DOTALL,
    )
    for match in obj_pattern.finditer(block):
        item: dict[str, str] = {}
        for kv in kv_pattern.finditer(match.group(1)):
            key = kv.group(1)
            val = kv.group(3).replace("\\'", "'").replace('\\"', '"').strip()
            item[key] = val
        if item.get("id") and item.get("title"):
            entries.append(item)
    return entries


def extract_folder_links_and_books(
    page_html: str,
) -> tuple[list[str], dict[str, str]]:
    """Extrai subpastas (`/pt/folders/<id>`) e livros (`/pt/book/<id>`) de uma pasta HTML."""
    subfolders: list[str] = []
    seen_folders: set[str] = set()
    books: dict[str, str] = {}

    # Links para subpastas (ex.: /pt/folders/245, /pt/folders/1024?page=2)
    folder_regex = re.compile(
        r"""<a\b[^>]*href=["'](?:https?://m\.egwwritings\.org)?(/pt/folders/\d+(?:\?[^"']*)?)["'][^>]*>""",
        re.IGNORECASE,
    )
    for m in folder_regex.finditer(page_html):
        path = html_lib.unescape(m.group(1))
        full_url = f"{BASE_URL}{path}"
        if full_url not in seen_folders:
            seen_folders.add(full_url)
            subfolders.append(full_url)

    # Links para livros (ex.: /pt/book/1815 ou /pt/book/1815/toc)
    book_regex = re.compile(
        r"""<a\b[^>]*href=["'](?:https?://m\.egwwritings\.org)?/pt/book/(\d+)(?:/toc|\.\d+)?(?:[?#][^"']*)?["'][^>]*>(.*?)</a>""",
        re.IGNORECASE | re.DOTALL,
    )
    for m in book_regex.finditer(page_html):
        book_id = m.group(1).strip()
        raw_label = clean_html_text(m.group(2))
        if not book_id or not raw_label:
            continue
        # Evita sobrescrever título completo com rótulos curtos tipo "Ler" ou "Índice".
        lowered = raw_label.lower()
        if lowered in {"ler", "read", "índice", "indice", "toc", "abrir"}:
            continue
        existing = books.get(book_id, "")
        if len(raw_label) > len(existing):
            books[book_id] = raw_label

    return subfolders, books


def crawl_folders_recursive(
    client: EgwHttpClient, root_url: str, max_folders: int = 80
) -> dict[str, dict[str, str]]:
    """Navega recursivamente na árvore de pastas em português e retorna `{id: {id, title}}`."""
    queue: list[str] = [root_url]
    visited: set[str] = set()
    discovered: dict[str, dict[str, str]] = {}

    while queue and len(visited) < max_folders:
        current = queue.pop(0)
        if current in visited:
            continue
        visited.add(current)
        try:
            page_html = client.fetch_text(current)
        except Exception as exc:
            print(f"[EGW] Aviso ao ler pasta {current}: {exc}", file=sys.stderr)
            continue

        subfolders, page_books = extract_folder_links_and_books(page_html)
        for bid, title in page_books.items():
            prev = discovered.get(bid)
            if prev is None or len(title) > len(prev["title"]):
                discovered[bid] = {
                    "id": bid,
                    "title": title,
                    "folder_url": current,
                }

        for sub in subfolders:
            if sub not in visited and sub not in queue:
                queue.append(sub)

    print(
        f"[EGW] Pastas visitadas: {len(visited)} | Livros encontrados na árvore: {len(discovered)}"
    )
    return discovered


def resolve_book_id_via_search(
    client: EgwHttpClient, title: str
) -> str | None:
    """Resolve o ID numérico via busca oficial do m.egwwritings.org."""
    encoded = urllib.parse.quote(title)
    search_url = f"{BASE_URL}/pt/search?q={encoded}"
    try:
        search_html = client.fetch_text(search_url)
    except Exception:
        return None
    m = re.search(r"/pt/book/(\d+)", search_html)
    return m.group(1) if m else None


def match_discovered_book_by_title(
    target_title: str, discovered_by_id: dict[str, dict[str, str]]
) -> str | None:
    """Encontra melhor correspondência de título dentre os livros descobertos em folders/245."""
    target_norm = normalize_text(target_title)
    if not target_norm:
        return None

    # 1. Igualdade exata normalizada
    for bid, info in discovered_by_id.items():
        if normalize_text(info["title"]) == target_norm:
            return bid

    # 2. Substring forte (ex.: subtítulo ou código no título do site)
    for bid, info in discovered_by_id.items():
        site_norm = normalize_text(info["title"])
        if len(target_norm) >= 6 and (
            target_norm in site_norm or site_norm in target_norm
        ):
            return bid

    # 3. Sobreposição de tokens relevantes
    stop_words = {"a", "o", "as", "os", "de", "da", "do", "das", "dos", "e", "em", "para", "na", "no", "um", "uma"}
    target_tokens = {w for w in target_norm.split() if w not in stop_words}
    if not target_tokens:
        return None

    best_id: str | None = None
    best_score = 0.0
    for bid, info in discovered_by_id.items():
        site_tokens = {
            w for w in normalize_text(info["title"]).split() if w not in stop_words
        }
        if not site_tokens:
            continue
        overlap = len(target_tokens & site_tokens)
        union = len(target_tokens | site_tokens)
        score = overlap / union if union else 0.0
        if score >= 0.72 and score > best_score:
            best_score = score
            best_id = bid
    return best_id


def parse_toc_html(numeric_id: str, toc_html: str) -> list[dict[str, Any]]:
    """Extrai o sumário (`EgwChapterHeader`) independente da ordem dos atributos HTML."""
    escaped = re.escape(numeric_id)
    chapters: list[dict[str, Any]] = []
    seen_ids: set[str] = set()

    # Estratégia 1: links diretos `/pt/book/<id>.<chapterId>` (com ou sem `<li id="l.<id>.<chapterId>">`)
    link_regex = re.compile(
        rf"""<a\b[^>]*href=["'](?:https?://m\.egwwritings\.org)?/pt/book/{escaped}\.(\d+(?:\.\d+)?)["'][^>]*>(.*?)</a>""",
        re.IGNORECASE | re.DOTALL,
    )
    idx = 1
    for m in link_regex.finditer(toc_html):
        chapter_id = m.group(1).strip()
        raw_title = clean_html_text(m.group(2))
        if not chapter_id or not raw_title or chapter_id in seen_ids:
            continue
        if raw_title.lower() in {"ler", "read", "início", "inicio", "capa", "sumário", "sumario"}:
            continue
        seen_ids.add(chapter_id)
        chapters.append(
            {
                "bookId": numeric_id,
                "chapterId": chapter_id,
                "chapterIndex": idx,
                "title": raw_title,
            }
        )
        idx += 1

    # Estratégia 2 (fallback): links de seção `/pt/book/<id>/<sectionId>` se o livro não usa `.paraId`
    if not chapters:
        sec_regex = re.compile(
            rf"""<a\b[^>]*href=["'](?:https?://m\.egwwritings\.org)?/pt/book/{escaped}/(\d+)["'][^>]*>(.*?)</a>""",
            re.IGNORECASE | re.DOTALL,
        )
        for m in sec_regex.finditer(toc_html):
            chapter_id = m.group(1).strip()
            raw_title = clean_html_text(m.group(2))
            if not chapter_id or not raw_title or chapter_id in seen_ids:
                continue
            seen_ids.add(chapter_id)
            chapters.append(
                {
                    "bookId": numeric_id,
                    "chapterId": chapter_id,
                    "chapterIndex": idx,
                    "title": raw_title,
                }
            )
            idx += 1

    return chapters


def _extract_attr(attrs_text: str, attr_name: str) -> str:
    m = re.search(
        rf"""\b{re.escape(attr_name)}\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))""",
        attrs_text,
        re.IGNORECASE,
    )
    if not m:
        return ""
    return html_lib.unescape(m.group(1) or m.group(2) or m.group(3) or "").strip()


class _EgwChapterHtmlParser(HTMLParser):
    """Parser HTML tolerante a aninhamento de <div>/<span> para páginas de m.egwwritings.org."""

    _BLOCK_TAGS = {"p", "div", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6"}

    def __init__(self, chapter_id: str) -> None:
        super().__init__(convert_charrefs=True)
        self.chapter_id = chapter_id
        self.title: str = ""
        self.paragraphs: list[dict[str, str]] = []
        self._seen_keys: set[tuple[str, str]] = set()
        self._auto_idx: int = 1

        self._capturing_tag: str | None = None
        self._capturing_depth: int = 0
        self._capturing_is_heading: bool = False
        self._capturing_id: str = ""
        self._capturing_refcode: str = ""
        self._all_text_parts: list[str] = []
        self._egw_content_parts: list[str] = []
        self._in_egw_content_depth: int = 0
        self._skip_depth: int = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag_l = tag.lower()
        attr_map = {k.lower(): (v or "") for k, v in attrs}
        cls = attr_map.get("class", "")

        if self._skip_depth > 0:
            self._skip_depth += 1
            return

        if tag_l in {"script", "style"} or (tag_l == "sup" and "footnote" in cls.lower()):
            self._skip_depth = 1
            return

        if self._capturing_tag is not None:
            if tag_l == self._capturing_tag:
                self._capturing_depth += 1
            if self._in_egw_content_depth > 0:
                if tag_l == "span":
                    self._in_egw_content_depth += 1
            elif tag_l == "span" and "egw_content" in cls.split():
                self._in_egw_content_depth = 1
            return

        if tag_l in self._BLOCK_TAGS:
            is_egw_block = "egw_content_wrapper" in cls or "data-refcode" in attr_map
            if is_egw_block:
                self._capturing_tag = tag_l
                self._capturing_depth = 1
                self._capturing_is_heading = tag_l in {"h1", "h2", "h3"}
                self._capturing_id = attr_map.get("id", "").strip()
                self._capturing_refcode = attr_map.get("data-refcode", "").strip()
                self._all_text_parts = []
                self._egw_content_parts = []
                self._in_egw_content_depth = 0

    def handle_endtag(self, tag: str) -> None:
        tag_l = tag.lower()
        if self._skip_depth > 0:
            self._skip_depth -= 1
            return

        if self._capturing_tag is None:
            return

        if self._in_egw_content_depth > 0 and tag_l == "span":
            self._in_egw_content_depth -= 1

        if tag_l == self._capturing_tag:
            self._capturing_depth -= 1
            if self._capturing_depth <= 0:
                raw = "".join(
                    self._egw_content_parts if self._egw_content_parts else self._all_text_parts
                )
                clean_text = re.sub(r"\s+", " ", raw).strip()
                if clean_text:
                    if self._capturing_is_heading and not self.title:
                        self.title = clean_text
                    elif not self._capturing_is_heading:
                        p_id = self._capturing_id or f"{self.chapter_id}_{self._auto_idx}"
                        dedup_key = (p_id, clean_text[:60])
                        if dedup_key not in self._seen_keys:
                            self._seen_keys.add(dedup_key)
                            self.paragraphs.append(
                                {
                                    "id": p_id,
                                    "refcode": self._capturing_refcode,
                                    "text": clean_text,
                                }
                            )
                            self._auto_idx += 1

                self._capturing_tag = None
                self._capturing_depth = 0
                self._in_egw_content_depth = 0

    def handle_data(self, data: str) -> None:
        if self._skip_depth > 0 or self._capturing_tag is None:
            return
        self._all_text_parts.append(data)
        if self._in_egw_content_depth > 0:
            self._egw_content_parts.append(data)


def parse_chapter_html(
    book_id: str,
    chapter_id: str,
    chapter_index: int,
    html_body: str,
    fallback_title: str,
) -> dict[str, Any]:
    """Extrai título e parágrafos (`EgwChapter`) com parser HTML seguro a tags aninhadas."""
    parser = _EgwChapterHtmlParser(chapter_id)
    parser.feed(html_body)
    parser.close()

    title = parser.title or fallback_title.strip() or f"Capítulo {chapter_index}"
    paragraphs = parser.paragraphs

    # Fallback: caso o HTML use apenas `<span class="egw_content">` sem wrapper externo.
    if not paragraphs:
        auto_idx = 1
        for m in re.finditer(
            r"""<span\b[^>]*class=["'][^"']*\begw_content\b[^"']*["'][^>]*>(.*?)</span>""",
            html_body,
            re.IGNORECASE | re.DOTALL,
        ):
            clean_text = clean_html_text(m.group(1))
            if clean_text and clean_text != title:
                paragraphs.append(
                    {
                        "id": f"{chapter_id}_{auto_idx}",
                        "refcode": "",
                        "text": clean_text,
                    }
                )
                auto_idx += 1

    return {
        "id": f"{book_id}.{chapter_id}",
        "bookId": book_id,
        "chapterId": chapter_id,
        "chapterIndex": chapter_index,
        "title": title,
        "paragraphs": paragraphs,
    }


def scrape_full_book(
    client: EgwHttpClient,
    numeric_id: str,
    meta: dict[str, Any],
    workers: int = 4,
) -> dict[str, Any] | None:
    """Baixa sumário e todos os capítulos de um livro para empacotamento R2."""
    toc_url = f"{BASE_URL}/pt/book/{numeric_id}/toc"
    toc_html = client.fetch_text(toc_url)
    toc_items = parse_toc_html(numeric_id, toc_html)

    if not toc_items:
        # Alguns livros abrem o TOC direto na URL raiz `/pt/book/<id>`.
        alt_html = client.fetch_text(f"{BASE_URL}/pt/book/{numeric_id}")
        toc_items = parse_toc_html(numeric_id, alt_html)

    if not toc_items:
        print(
            f"[EGW] Aviso: sumário vazio para livro {numeric_id} ({meta.get('title', '')}).",
            file=sys.stderr,
        )
        return None

    chapters_by_index: dict[int, dict[str, Any]] = {}

    def _fetch_one(header: dict[str, Any]) -> tuple[int, dict[str, Any] | None]:
        chap_id = str(header["chapterId"])
        chap_idx = int(header["chapterIndex"])
        chap_url = (
            f"{BASE_URL}/pt/book/{numeric_id}/{chap_id}"
            if "/" in chap_id
            else f"{BASE_URL}/pt/book/{numeric_id}.{chap_id}"
        )
        try:
            body_html = client.fetch_text(chap_url)
            parsed = parse_chapter_html(
                book_id=numeric_id,
                chapter_id=chap_id,
                chapter_index=chap_idx,
                html_body=body_html,
                fallback_title=str(header["title"]),
            )
            return chap_idx, parsed
        except Exception as exc:
            print(
                f"[EGW] Erro no capítulo {numeric_id}.{chap_id}: {exc}",
                file=sys.stderr,
            )
            return chap_idx, None

    with ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        futures = [pool.submit(_fetch_one, item) for item in toc_items]
        for fut in as_completed(futures):
            idx, chap = fut.result()
            if chap is not None and chap.get("paragraphs"):
                chapters_by_index[idx] = chap

    ordered_chapters = [
        chapters_by_index[idx] for idx in sorted(chapters_by_index.keys())
    ]
    if not ordered_chapters:
        print(
            f"[EGW] Nenhum capítulo com parágrafos extraído para {numeric_id}.",
            file=sys.stderr,
        )
        return None

    total_paragraphs = sum(len(c.get("paragraphs", [])) for c in ordered_chapters)
    return {
        "schema_version": 1,
        "book_id": numeric_id,
        "catalog_ids": meta.get("catalog_ids", [numeric_id]),
        "title": meta.get("title", ""),
        "abbreviation": meta.get("abbr", ""),
        "description": meta.get("desc", ""),
        "source_url": toc_url,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total_chapters": len(toc_items),
        "scraped_chapters": len(ordered_chapters),
        "paragraphs_count": total_paragraphs,
        "toc": toc_items,
        "chapters": ordered_chapters,
    }


def write_gzip_package(output_path: Path, payload: dict[str, Any]) -> tuple[int, str]:
    """Salva o JSON compactado com Gzip e retorna `(size_bytes, sha256)`."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    raw_bytes = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )
    compressed = gzip.compress(raw_bytes, compresslevel=9, mtime=0)
    output_path.write_bytes(compressed)
    digest = hashlib.sha256(compressed).hexdigest()
    return len(compressed), digest


def load_env_file(env_path: Path) -> None:
    """Carrega variáveis de ambiente de .env.r2 ou .env locais, se existirem."""
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


def upload_directory_to_r2(
    output_dir: Path, r2_prefix: str, files_to_upload: list[Path]
) -> None:
    """Envia pacotes `.json.gz` e `egw_manifest.json` para o Cloudflare R2 via S3 API."""
    try:
        import boto3  # type: ignore
        from botocore.config import Config  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "Dependência 'boto3' ausente. Instale com `pip install boto3` para usar --upload-r2."
        ) from exc

    account_id = os.environ.get("R2_ACCOUNT_ID", "").strip()
    endpoint_url = os.environ.get("R2_ENDPOINT_URL", "").strip() or (
        f"https://{account_id}.r2.cloudflarestorage.com" if account_id else ""
    )
    access_key = (
        os.environ.get("R2_ACCESS_KEY_ID") or os.environ.get("AWS_ACCESS_KEY_ID") or ""
    ).strip()
    secret_key = (
        os.environ.get("R2_SECRET_ACCESS_KEY")
        or os.environ.get("AWS_SECRET_ACCESS_KEY")
        or ""
    ).strip()
    bucket = (
        os.environ.get("R2_BUCKET_NAME")
        or os.environ.get("R2_BUCKET")
        or "kairos-hinario-audio"
    ).strip()

    if not endpoint_url or not access_key or not secret_key or not bucket:
        raise RuntimeError(
            "Variáveis R2 incompletas. Defina R2_ENDPOINT_URL (ou R2_ACCOUNT_ID), "
            "R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY e R2_BUCKET_NAME."
        )

    s3 = boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name="auto",
        config=Config(signature_version="s3v4"),
    )

    clean_prefix = r2_prefix.strip("/")
    for local_file in files_to_upload:
        rel = local_file.relative_to(output_dir).as_posix()
        key = f"{clean_prefix}/{rel}" if clean_prefix else rel
        if local_file.name.endswith(".json.gz"):
            content_type = "application/gzip"
            cache_control = "public, max-age=604800"
        elif local_file.name.endswith(".json"):
            content_type = "application/json; charset=utf-8"
            cache_control = "public, max-age=1800"
        else:
            content_type = "application/octet-stream"
            cache_control = "public, max-age=3600"

        print(f"[R2] Uploading s3://{bucket}/{key} ({local_file.stat().st_size} bytes)...")
        s3.upload_file(
            str(local_file),
            bucket,
            key,
            ExtraArgs={
                "ContentType": content_type,
                "CacheControl": cache_control,
            },
        )


def build_sync_plan(
    client: EgwHttpClient,
    catalog: list[dict[str, str]],
    discovered_by_id: dict[str, dict[str, str]],
    include_extra_folder_books: bool = True,
) -> tuple[dict[str, dict[str, Any]], dict[str, str]]:
    """Cruza o catálogo do app com a árvore do site para produzir mapa de livros + aliases."""
    targets: dict[str, dict[str, Any]] = {}
    aliases: dict[str, str] = {}

    for entry in catalog:
        raw_id = entry["id"]
        title = entry["title"]
        resolved_id: str | None = None

        if raw_id.isdigit():
            resolved_id = raw_id
        elif raw_id in PRE_RESOLVED_NUMERIC_IDS:
            resolved_id = PRE_RESOLVED_NUMERIC_IDS[raw_id]
        else:
            resolved_id = match_discovered_book_by_title(title, discovered_by_id)
            if resolved_id is None:
                resolved_id = resolve_book_id_via_search(client, title)

        if not resolved_id:
            print(
                f"[EGW] Não foi possível resolver ID numérico para '{raw_id}' ({title}).",
                file=sys.stderr,
            )
            continue

        if raw_id != resolved_id:
            aliases[raw_id] = resolved_id

        existing = targets.get(resolved_id)
        if existing is None:
            targets[resolved_id] = {
                "id": resolved_id,
                "catalog_ids": [raw_id] if raw_id == resolved_id else [resolved_id, raw_id],
                "title": title,
                "abbr": entry.get("abbr", ""),
                "desc": entry.get("desc", ""),
                "in_default_catalog": True,
            }
        elif raw_id not in existing["catalog_ids"]:
            existing["catalog_ids"].append(raw_id)

    if include_extra_folder_books:
        for bid, info in discovered_by_id.items():
            if bid not in targets:
                site_title = info["title"]
                abbr_guess = "".join(
                    w[0].upper() for w in normalize_text(site_title).split()[:4] if w
                )
                targets[bid] = {
                    "id": bid,
                    "catalog_ids": [bid],
                    "title": site_title,
                    "abbr": abbr_guess[:5] or "EGW",
                    "desc": "Obra do Espírito de Profecia em português (egwwritings.org).",
                    "in_default_catalog": False,
                }

    return targets, aliases


def main(argv: list[str] | None = None) -> int:
    repo_root = Path(__file__).resolve().parent.parent
    load_env_file(repo_root / ".env.r2")
    load_env_file(repo_root / ".env")
    default_catalog_path = repo_root / "lib" / "services" / "egw_service.dart"

    parser = argparse.ArgumentParser(
        description="Baixa e empacota livros EGW (pt) para o Cloudflare R2."
    )
    parser.add_argument("--folder-url", default=DEFAULT_FOLDER_URL)
    parser.add_argument("--catalog-dart", type=Path, default=default_catalog_path)
    parser.add_argument("--output-dir", type=Path, default=Path("dist/egw"))
    parser.add_argument("--r2-prefix", default="egw")
    parser.add_argument("--upload-r2", "--upload", dest="upload_r2", action="store_true")
    parser.add_argument(
        "--upload-only",
        action="store_true",
        help="Envia todos os pacotes já gerados em --output-dir diretamente para o R2 sem refazer o scraping.",
    )
    parser.add_argument(
        "--clean-local",
        action="store_true",
        help="Remove o diretório --output-dir localmente após upload concluído com sucesso.",
    )
    parser.add_argument(
        "--book",
        default="",
        help="Lista separada por vírgula de IDs (numéricos ou slugs pt_...) para sincronizar.",
    )
    parser.add_argument("--max-books", type=int, default=0)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--skip-existing", action="store_true")
    parser.add_argument(
        "--existing-manifest-url",
        default="",
        help="URL pública de um egw_manifest.json já publicado para evitar re-scraping completo.",
    )
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--no-extra-folder-books", action="store_true")
    args = parser.parse_args(argv)

    if args.upload_only:
        if not args.output_dir.exists():
            print(f"[EGW] Diretório local não encontrado: {args.output_dir}", file=sys.stderr)
            return 1
        local_files = sorted(
            [
                p
                for p in args.output_dir.rglob("*")
                if p.is_file() and (p.name.endswith(".json.gz") or p.name.endswith(".json"))
            ]
        )
        if not local_files:
            print(f"[EGW] Nenhum arquivo .json ou .json.gz encontrado em {args.output_dir}.", file=sys.stderr)
            return 1
        print(f"[EGW] Enviando {len(local_files)} arquivos locais de {args.output_dir} para R2 ({args.r2_prefix}/)...")
        upload_directory_to_r2(
            output_dir=args.output_dir,
            r2_prefix=args.r2_prefix,
            files_to_upload=local_files,
        )
        print(f"[EGW] Upload concluído com sucesso ({len(local_files)} arquivos).")
        if args.clean_local:
            shutil.rmtree(args.output_dir)
            print(f"[EGW] Diretório local removido: {args.output_dir}")
        return 0

    client = EgwHttpClient()
    catalog = parse_dart_default_catalog(args.catalog_dart)
    print(f"[EGW] Catálogo Dart carregado: {len(catalog)} entradas")

    discovered_by_id = crawl_folders_recursive(client, args.folder_url)
    targets, aliases = build_sync_plan(
        client=client,
        catalog=catalog,
        discovered_by_id=discovered_by_id,
        include_extra_folder_books=not args.no_extra_folder_books,
    )

    if args.book.strip():
        requested = {x.strip() for x in args.book.split(",") if x.strip()}
        filtered_ids: set[str] = set()
        for req in requested:
            if req in targets:
                filtered_ids.add(req)
            elif req in aliases and aliases[req] in targets:
                filtered_ids.add(aliases[req])
            elif req.isdigit():
                filtered_ids.add(req)
                targets.setdefault(
                    req,
                    {
                        "id": req,
                        "catalog_ids": [req],
                        "title": f"Livro EGW #{req}",
                        "abbr": "EGW",
                        "desc": "",
                        "in_default_catalog": False,
                    },
                )
        targets = {k: v for k, v in targets.items() if k in filtered_ids}

    manifest_path = args.output_dir / "egw_manifest.json"
    existing_manifest: dict[str, Any] = {}
    remote_loaded = False
    if manifest_path.exists():
        try:
            existing_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except Exception:
            existing_manifest = {}
    elif args.existing_manifest_url.strip():
        try:
            raw_remote = client.fetch_text(args.existing_manifest_url.strip(), retries=2)
            existing_manifest = json.loads(raw_remote)
            remote_loaded = isinstance(existing_manifest, dict) and bool(
                existing_manifest.get("books")
            )
            if remote_loaded:
                print(
                    f"[EGW] Manifesto remoto carregado ({len(existing_manifest['books'])} livros)."
                )
        except Exception as exc:
            print(f"[EGW] Aviso ao ler manifesto remoto: {exc}", file=sys.stderr)

    manifest_books: dict[str, Any] = dict(existing_manifest.get("books", {}))
    changed_files: list[Path] = []
    ordered_ids = sorted(
        targets.keys(),
        key=lambda k: (0 if targets[k]["in_default_catalog"] else 1, int(k) if k.isdigit() else 999999),
    )
    if args.max_books > 0:
        ordered_ids = ordered_ids[: args.max_books]

    processed = 0
    succeeded = 0
    failed = 0

    for numeric_id in ordered_ids:
        meta = targets[numeric_id]
        pkg_rel = f"books/{numeric_id}.json.gz"
        pkg_path = args.output_dir / pkg_rel
        r2_pkg_path = f"{args.r2_prefix.strip('/')}/{pkg_rel}" if args.r2_prefix.strip("/") else pkg_rel

        existing_entry = manifest_books.get(numeric_id, {})
        existing_complete = (
            isinstance(existing_entry, dict)
            and int(existing_entry.get("scraped_chapters", 0) or 0)
            >= max(1, int(existing_entry.get("total_chapters", 0) or 0))
            and int(existing_entry.get("paragraphs_count", 0) or 0) > 0
        )
        local_complete = pkg_path.exists() and pkg_path.stat().st_size > 256 and numeric_id in manifest_books

        if args.skip_existing and not args.force and (local_complete or (remote_loaded and existing_complete)):
            print(f"[EGW] Pulando {numeric_id} ({meta['title']}): pacote já publicado/completo.")
            succeeded += 1
            processed += 1
            continue

        processed += 1
        print(f"[EGW] ({processed}/{len(ordered_ids)}) Sincronizando #{numeric_id} - {meta['title']}...")
        try:
            package_data = scrape_full_book(
                client=client,
                numeric_id=numeric_id,
                meta=meta,
                workers=args.workers,
            )
            if package_data is None:
                failed += 1
                continue

            size_bytes, sha256 = write_gzip_package(pkg_path, package_data)
            manifest_books[numeric_id] = {
                "id": numeric_id,
                "catalog_ids": meta["catalog_ids"],
                "title": package_data["title"],
                "abbr": package_data["abbreviation"],
                "description": package_data["description"],
                "in_default_catalog": meta["in_default_catalog"],
                "total_chapters": package_data["total_chapters"],
                "scraped_chapters": package_data["scraped_chapters"],
                "paragraphs_count": package_data["paragraphs_count"],
                "package_path": r2_pkg_path,
                "size_bytes": size_bytes,
                "sha256": sha256,
                "updated_at": package_data["generated_at"],
            }
            changed_files.append(pkg_path)
            succeeded += 1
            print(
                f"      OK: {package_data['scraped_chapters']}/{package_data['total_chapters']} capítulos, "
                f"{size_bytes} bytes (.json.gz)"
            )
        except Exception as exc:
            failed += 1
            print(f"[EGW] Falha em #{numeric_id}: {exc}", file=sys.stderr)

    merged_aliases = dict(existing_manifest.get("aliases", {}))
    merged_aliases.update(aliases)

    manifest_payload = {
        "version": 1,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "source": args.folder_url,
        "total_books": len(manifest_books),
        "aliases": merged_aliases,
        "books": manifest_books,
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest_payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    changed_files.append(manifest_path)

    print(
        f"[EGW] Finalizado: {succeeded} sucesso(s), {failed} falha(s). "
        f"Manifest em {manifest_path} ({len(manifest_books)} livros)."
    )

    if args.upload_r2:
        upload_directory_to_r2(
            output_dir=args.output_dir,
            r2_prefix=args.r2_prefix,
            files_to_upload=changed_files,
        )
        if args.clean_local and args.output_dir.exists():
            shutil.rmtree(args.output_dir)
            print(f"[EGW] Diretório local removido: {args.output_dir}")

    return 0 if succeeded > 0 or not ordered_ids else 1


if __name__ == "__main__":
    raise SystemExit(main())
