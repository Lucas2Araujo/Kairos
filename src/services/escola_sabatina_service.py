from __future__ import annotations

import asyncio
import hashlib
import logging
import os
import re
import urllib.parse
from pathlib import Path
from typing import Any, Callable

import httpx

from src.database.connection import DatabaseConnection
from src.models.escola_sabatina import SSDay, SSLesson, SSQuarterly
from src.repositories.escola_sabatina_repository import EscolaSabatinaRepository
from src.utils.bible_extractor import find_bible_references


logger = logging.getLogger(__name__)

ADVENTECH_API_BASE = "https://sabbath-school.adventech.io/api/v2"

# Regex para identificar imagens em HTML (<img ... src="..." ...>) e Markdown (![alt](url))
HTML_IMG_PATTERN = re.compile(r'<img\b[^>]*?\bsrc=["\']([^"\']+)["\']', re.IGNORECASE)
MD_IMG_PATTERN = re.compile(r'!\[([^\]]*)\]\(([^)\s]+)(?:\s+["\'][^"\']*["\'])?\)')

BIBLE_BOOK_MAP_EN_PT: dict[str, str] = {
    "genesis": "Gênesis",
    "exodus": "Êxodo",
    "leviticus": "Levítico",
    "numbers": "Números",
    "deuteronomy": "Deuteronômio",
    "joshua": "Josué",
    "judges": "Juízes",
    "ruth": "Rute",
    "1samuel": "1 Samuel",
    "2samuel": "2 Samuel",
    "1kings": "1 Reis",
    "2kings": "2 Reis",
    "1chronicles": "1 Crônicas",
    "2chronicles": "2 Crônicas",
    "ezra": "Esdras",
    "nehemiah": "Neemias",
    "esther": "Ester",
    "job": "Jó",
    "psalms": "Salmos",
    "psalm": "Salmos",
    "proverbs": "Provérbios",
    "ecclesiastes": "Eclesiastes",
    "songofsolomon": "Cantares",
    "songofsongs": "Cantares",
    "isaiah": "Isaías",
    "jeremiah": "Jeremias",
    "lamentations": "Lamentações",
    "ezekiel": "Ezequiel",
    "daniel": "Daniel",
    "hosea": "Oseias",
    "joel": "Joel",
    "amos": "Amós",
    "obadiah": "Obadias",
    "jonah": "Jonas",
    "micah": "Miqueias",
    "nahum": "Naum",
    "habakkuk": "Habacuque",
    "zephaniah": "Sofonias",
    "haggai": "Ageu",
    "zechariah": "Zacarias",
    "malachi": "Malaquias",
    "matthew": "Mateus",
    "mark": "Marcos",
    "luke": "Lucas",
    "john": "João",
    "acts": "Atos",
    "romans": "Romanos",
    "1corinthians": "1 Coríntios",
    "2corinthians": "2 Coríntios",
    "galatians": "Gálatas",
    "ephesians": "Efésios",
    "philippians": "Filipenses",
    "colossians": "Colossenses",
    "1thessalonians": "1 Tessalonicenses",
    "2thessalonians": "2 Tessalonicenses",
    "1timothy": "1 Timóteo",
    "2timothy": "2 Timóteo",
    "titus": "Tito",
    "philemon": "Filemom",
    "hebrews": "Hebreus",
    "james": "Tiago",
    "1peter": "1 Pedro",
    "2peter": "2 Pedro",
    "1john": "1 João",
    "2john": "2 João",
    "3john": "3 João",
    "jude": "Judas",
    "revelation": "Apocalipse",
}


class EscolaSabatinaService:
    """
    Serviço offline-first da Escola Sabatina:
    - Consulta trimestres, lições e dias da API Adventech (com fallback SQLite)
    - Download completo da semana e do trimestre
    - Download e cache local de tirinhas e imagens com substituição de URLs por caminhos locais
    - Conversão robusta de HTML para Markdown com links bíblicos interativos (bible://...)
    - Gerenciamento de anotações do usuário
    """

    def __init__(
        self,
        repository: EscolaSabatinaRepository,
        http_client: httpx.AsyncClient | None = None,
        base_url: str = ADVENTECH_API_BASE,
        cache_dir: Path | None = None,
    ):
        self.repository = repository
        self._http_client = http_client
        self.base_url = base_url.rstrip("/")
        
        if cache_dir is not None:
            self.images_dir = Path(cache_dir) / "escola_sabatina" / "images"
        else:
            assets_path = Path("assets") / "cache" / "escola_sabatina" / "images"
            try:
                assets_path.mkdir(parents=True, exist_ok=True)
                self.images_dir = assets_path.resolve()
            except Exception:
                user_data = DatabaseConnection._get_user_data_dir()
                self.images_dir = user_data / "cache" / "escola_sabatina" / "images"

        self._ensure_cache_dir()

    def _ensure_cache_dir(self) -> None:
        """Garante a criação do diretório de cache de imagens."""
        try:
            self.images_dir.mkdir(parents=True, exist_ok=True)
        except Exception:
            logger.exception("Não foi possível criar o diretório de cache de imagens: %s", self.images_dir)

    async def _get_client(self) -> httpx.AsyncClient:
        """Retorna o cliente HTTP assíncrono configurado."""
        if self._http_client is not None:
            return self._http_client
        return httpx.AsyncClient(timeout=15.0, headers={"User-Agent": "Kairos-App/1.0"})

    # -----------------------------------------------------------------------
    # Parse e Cache Local de Imagens (Tirinhas de Domingo e Ilustrações)
    # -----------------------------------------------------------------------

    def extract_image_urls(self, content: str) -> list[str]:
        """
        Analisa o conteúdo (HTML ou Markdown) e retorna a lista ordenada e única
        de URLs remotas ou caminhos locais de imagens encontrados.
        """
        if not content:
            return []

        urls: list[str] = []
        seen: set[str] = set()

        # 1. Tags HTML <img>
        for m in HTML_IMG_PATTERN.finditer(content):
            url = m.group(1).strip()
            if url.startswith("//"):
                url = "https:" + url
            if url and url not in seen:
                seen.add(url)
                urls.append(url)

        # 2. Sintaxe Markdown ![alt](url)
        for m in MD_IMG_PATTERN.finditer(content):
            url = m.group(2).strip()
            if url.startswith("//"):
                url = "https:" + url
            if url and url not in seen:
                seen.add(url)
                urls.append(url)

        return urls

    async def download_and_cache_image(self, url: str) -> str:
        """
        Baixa um arquivo de imagem para o diretório de dados locais do app.
        Retorna o caminho local absoluto do arquivo baixado (ou a URL remota original em caso de erro).
        """
        if not url:
            return ""
        if not (url.startswith("http://") or url.startswith("https://")):
            return url

        self._ensure_cache_dir()

        # Gera nome único previsível através de hash SHA-256
        url_hash = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
        parsed_path = urllib.parse.urlparse(url).path
        ext = Path(parsed_path).suffix.lower()
        if ext not in (".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"):
            ext = ".png"

        filename = f"ss_img_{url_hash}{ext}"
        local_file = self.images_dir / filename

        # Se o arquivo já existe e possui conteúdo, reaproveita
        if local_file.exists() and local_file.stat().st_size > 0:
            return local_file.as_posix()

        client = await self._get_client()
        should_close = self._http_client is None

        try:
            response = await client.get(url, follow_redirects=True)
            if response.status_code == 200 and response.content:
                local_file.write_bytes(response.content)
                logger.info("Imagem da Escola Sabatina salva em cache: %s", local_file)
                return local_file.as_posix()
            else:
                logger.warning("Falha ao baixar imagem %s: status %d", url, response.status_code)
                return url
        except Exception:
            logger.exception("Erro durante download da imagem da Escola Sabatina: %s", url)
            return url
        finally:
            if should_close:
                await client.aclose()

    @staticmethod
    def normalize_bible_links(text: str) -> str:
        """
        Garante que todos os links bible://... tenham seu destino 100% URL-encoded,
        evitando que espaços não codificados quebrem a renderização do ft.Markdown
        e apareçam como texto cru com parênteses.
        """
        if not text or "bible://" not in text:
            return text

        def _encode_url(m: re.Match) -> str:
            label = m.group(1)
            raw_ref = m.group(2)
            unquoted = urllib.parse.unquote(raw_ref).strip()
            encoded = urllib.parse.quote(unquoted)
            return f"[{label}](bible://{encoded})"

        return re.sub(r'\[([^\]]+)\]\(bible://([^)]+)\)', _encode_url, text)

    @staticmethod
    def html_to_markdown(content: str) -> str:
        """
        Converte HTML bruto da API Adventech para Markdown limpo de alta fidelidade:
        - Converte links de versículos <a class="verse" ...> em [Label](bible://Ref) com URL encoding
        - Auto-linka referências bíblicas adicionais em texto puro (ex: 'Rm 8:28')
        - Converte tags <img> e <p><img ...></p> em ![Tirinha](src)
        - Converte <h1>..<h6>, <blockquote>, <strong>, <em>, <code>, <p>, <br>
        - Remove tags residuais e decodifica entidades HTML
        """
        if not content:
            return ""

        import html as html_module

        text = content

        def _format_single_ref(verse_attr: str, verse_label: str) -> str:
            target_ref = verse_label
            # Extrai livro em inglês para traduzir para o nome canônico em português
            m_en = re.match(r"^([1-3]?[A-Za-z]+)(\d+)", verse_attr)
            if m_en:
                book_en = m_en.group(1).lower()
                chap_digits = m_en.group(2)
                book_pt = BIBLE_BOOK_MAP_EN_PT.get(book_en)
                if book_pt:
                    m_label = re.search(r"(\d+)(?:\s*[:\.]\s*(\d+))?", verse_label)
                    if m_label:
                        c = m_label.group(1)
                        v = m_label.group(2)
                        target_ref = f"{book_pt} {c}:{v}" if v else f"{book_pt} {c}"
                    else:
                        target_ref = f"{book_pt} {chap_digits}"

            return f"[{verse_label}](bible://{urllib.parse.quote(target_ref.strip())})"

        def _replace_verse(match: re.Match) -> str:
            verse_attr = match.group(1).strip()
            verse_label = match.group(2).strip()

            # Se houver múltiplas referências separadas por ponto-e-vírgula, cria links individuais
            if ";" in verse_label:
                sub_labels = [s.strip() for s in verse_label.split(";") if s.strip()]
                links = []
                last_book = ""
                m_attr = re.match(r"^([1-3]?[A-Za-z]+)", verse_attr)
                if m_attr:
                    b_en = m_attr.group(1).lower()
                    last_book = BIBLE_BOOK_MAP_EN_PT.get(b_en, "")

                for sub in sub_labels:
                    # Identifica se o sub_label começa com nome de livro (ex: 'Ap 7:4-8')
                    m_lead = re.match(r"^([1-3]?\s*[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)?)\s+(\d+)", sub)
                    if m_lead:
                        last_book = m_lead.group(1).strip()
                        target_ref = sub
                    elif re.match(r"^\d+", sub):
                        # Começa diretamente com capítulo/versículo: herda o livro anterior (ex: '14:1' -> 'Ap 14:1')
                        target_ref = f"{last_book} {sub}" if last_book else sub
                    else:
                        target_ref = sub
                    links.append(f"[{sub}](bible://{urllib.parse.quote(target_ref.strip())})")
                return "; ".join(links)

            return _format_single_ref(verse_attr, verse_label)

        text = re.sub(
            r'<a\b[^>]*?class=["\']verse["\'][^>]*?verse=["\']([^"\']*)["\'][^>]*>(.*?)</a>',
            _replace_verse,
            text,
            flags=re.IGNORECASE | re.DOTALL,
        )
        text = re.sub(
            r'<a\b[^>]*?verse=["\']([^"\']*)["\'][^>]*?class=["\']verse["\'][^>]*>(.*?)</a>',
            _replace_verse,
            text,
            flags=re.IGNORECASE | re.DOTALL,
        )

        # Imagens: <p><img ...></p> ou <img>
        def _replace_img(match: re.Match) -> str:
            src = match.group(1).strip()
            return f"\n\n![imagem]({src})\n\n"

        text = re.sub(
            r'<p>\s*<img\b[^>]*?\bsrc=["\']([^"\']+)["\'][^>]*?>\s*</p>',
            _replace_img,
            text,
            flags=re.IGNORECASE,
        )
        text = re.sub(
            r'<img\b[^>]*?\bsrc=["\']([^"\']+)["\'][^>]*?>',
            _replace_img,
            text,
            flags=re.IGNORECASE,
        )

        # Cabeçalhos
        for h in range(6, 0, -1):
            hashes = "#" * h
            text = re.sub(rf'<h{h}\b[^>]*>(.*?)</h{h}>', rf'\n\n{hashes} \1\n\n', text, flags=re.IGNORECASE | re.DOTALL)

        # Blockquotes
        text = re.sub(r'<blockquote>\s*(.*?)\s*</blockquote>', r'\n\n> \1\n\n', text, flags=re.IGNORECASE | re.DOTALL)

        # Formatação inline
        text = re.sub(r'<(?:strong|b)\b[^>]*>(.*?)</(?:strong|b)>', r'**\1**', text, flags=re.IGNORECASE | re.DOTALL)
        text = re.sub(r'<(?:em|i)\b[^>]*>(.*?)</(?:em|i)>', r'*\1*', text, flags=re.IGNORECASE | re.DOTALL)
        text = re.sub(r'<code\b[^>]*>(.*?)</code>', r'`\1`', text, flags=re.IGNORECASE | re.DOTALL)

        # Links genéricos restantes <a href="...">...</a>
        text = re.sub(r'<a\b[^>]*?href=["\']([^"\']*)["\'][^>]*>(.*?)</a>', r'[\2](\1)', text, flags=re.IGNORECASE | re.DOTALL)

        # Parágrafos e quebras de linha
        text = re.sub(r'<p\b[^>]*>(.*?)</p>', r'\n\n\1\n\n', text, flags=re.IGNORECASE | re.DOTALL)
        text = re.sub(r'<br\s*/?>', r'\n', text, flags=re.IGNORECASE)

        # Remove outras tags residuais
        text = re.sub(r'<[^>]+>', '', text)

        # Decodifica entidades HTML
        text = html_module.unescape(text)

        # Auto-linka referências bíblicas em texto corrido não envelopadas em links
        def _linkify_plain_text(t: str) -> str:
            link_pattern = re.compile(r'(!?\[[^\]]*\]\([^)]+\))')
            parts = link_pattern.split(t)
            res = []
            for idx, part in enumerate(parts):
                if idx % 2 == 1:
                    res.append(part)
                else:
                    matches = find_bible_references(part)
                    if not matches:
                        res.append(part)
                        continue
                    last_end = 0
                    for m in matches:
                        res.append(part[last_end:m.start])
                        res.append(f"[{m.raw_text}](bible://{urllib.parse.quote(m.raw_text.strip())})")
                        last_end = m.end
                    res.append(part[last_end:])
            return "".join(res)

        text = _linkify_plain_text(text)
        text = EscolaSabatinaService.normalize_bible_links(text)

        # Limpa quebras múltiplas excessivas
        text = re.sub(r'\n{3,}', '\n\n', text)
        return text.strip()


    async def process_and_cache_images(self, content: str) -> str:
        """
        Identifica todas as URLs remotas de imagens no conteúdo, efetua o download
        para o cache local, substitui as URLs remotas pelos caminhos locais no texto
        e converte para Markdown limpo.
        """
        if not content:
            return ""

        remote_urls = self.extract_image_urls(content)
        modified_content = content
        for remote_url in remote_urls:
            if remote_url.startswith("http://") or remote_url.startswith("https://"):
                local_path = await self.download_and_cache_image(remote_url)
                if local_path != remote_url:
                    modified_content = modified_content.replace(remote_url, local_path)

        return self.html_to_markdown(modified_content)

    @staticmethod
    def normalize_markdown_images(content: str) -> str:
        """Converte tags de imagens e HTML para Markdown nativo."""
        return EscolaSabatinaService.html_to_markdown(content)

    # -----------------------------------------------------------------------
    # Consulta de Trimestres e Lições
    # -----------------------------------------------------------------------

    async def get_quarterlies(
        self, lang: str = "pt", category: str = "adultos", force_refresh: bool = False
    ) -> list[SSQuarterly]:
        """
        Retorna trimestres disponíveis para o idioma e categoria ('adultos' ou 'jovens').
        Offline-first: prioriza SQLite e busca da API Adventech caso necessário.
        """
        if not force_refresh:
            cached = await self.repository.list_quarterlies(category=category)
            if cached:
                return cached

        # Busca remota na API Adventech
        url = f"{self.base_url}/{lang}/quarterlies/index.json"
        client = await self._get_client()
        should_close = self._http_client is None

        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code == 200:
                data = resp.json()
                quarterlies: list[SSQuarterly] = []
                for item in data:
                    q = SSQuarterly.from_dict(item)
                    # Filtra edições de Portugal que não interessam no momento
                    if "portugal" in q.title.lower() or "-pt" in q.id.lower():
                        continue
                    await self.repository.save_quarterly(q)
                    if q.category == category:
                        quarterlies.append(q)

                return quarterlies
        except Exception:
            logger.warning("Falha de conexão ao buscar trimestres da Escola Sabatina na nuvem.")
        finally:
            if should_close:
                await client.aclose()

        # Fallback offline
        return await self.repository.list_quarterlies(category=category)

    async def get_lessons(
        self, quarterly_id: str, lang: str = "pt", force_refresh: bool = False
    ) -> list[SSLesson]:
        """Retorna a lista de lições de um trimestre."""
        if not force_refresh:
            cached = await self.repository.list_lessons_by_quarterly(quarterly_id)
            if cached:
                return cached

        url = f"{self.base_url}/{lang}/quarterlies/{quarterly_id}/index.json"
        client = await self._get_client()
        should_close = self._http_client is None

        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code == 200:
                data = resp.json()
                lessons_data = data.get("lessons", [])
                lessons: list[SSLesson] = []
                for item in lessons_data:
                    lesson = SSLesson.from_dict(item, quarterly_id=quarterly_id)
                    await self.repository.save_lesson(lesson)
                    lessons.append(lesson)
                return lessons
        except Exception:
            logger.warning("Falha ao buscar lições do trimestre %s.", quarterly_id)
        finally:
            if should_close:
                await client.aclose()

        return await self.repository.list_lessons_by_quarterly(quarterly_id)

    async def get_lesson_days(
        self,
        lesson_id: str,
        quarterly_id: str = "",
        lang: str = "pt",
        force_refresh: bool = False,
    ) -> list[SSDay]:
        """Retorna os dias de estudo de uma lição."""
        if not force_refresh:
            cached = await self.repository.list_days_by_lesson(lesson_id)
            if cached:
                return cached

        if not quarterly_id:
            # Tenta inferir pelo lesson_id ou pelo banco
            lesson = await self.repository.get_lesson(lesson_id)
            if lesson:
                quarterly_id = lesson.quarterly_id

        url = f"{self.base_url}/{lang}/quarterlies/{quarterly_id}/lessons/{lesson_id}/index.json"
        client = await self._get_client()
        should_close = self._http_client is None

        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code == 200:
                data = resp.json()
                days_data = data.get("days", [])
                days: list[SSDay] = []
                for item in days_data:
                    day = SSDay.from_dict(item, lesson_id=lesson_id)
                    await self.repository.save_day(day)
                    days.append(day)
                return days
        except Exception:
            logger.warning("Falha ao buscar dias da lição %s.", lesson_id)
        finally:
            if should_close:
                await client.aclose()

        return await self.repository.list_days_by_lesson(lesson_id)

    async def get_day_content(
        self,
        day_id: str,
        read_path: str = "",
        lang: str = "pt",
        force_refresh: bool = False,
    ) -> SSDay | None:
        """
        Retorna o estudo de um dia específico com o conteúdo processado e imagens em cache local.
        """
        cached_day = await self.repository.get_day(day_id)
        if cached_day and cached_day.content and not force_refresh:
            if "<p>" in cached_day.content or "<a class=" in cached_day.content or "<img" in cached_day.content:
                cached_day.content = self.html_to_markdown(cached_day.content)
            return cached_day

        target_path = read_path or (cached_day.read_path if cached_day else "")
        if not target_path:
            # Constrói caminho a partir de id se possível
            target_path = f"{day_id}/read"

        target_path = target_path.strip("/")
        if not target_path.endswith("/index.json"):
            url = f"{self.base_url}/{target_path}/index.json"
        else:
            url = f"{self.base_url}/{target_path}"

        client = await self._get_client()
        should_close = self._http_client is None

        try:
            resp = await client.get(url, follow_redirects=True)
            if resp.status_code == 200:
                data = resp.json()
                raw_content = data.get("content") or ""

                # Download e cache local de todas as imagens presentes no conteúdo + Markdown
                processed_content = await self.process_and_cache_images(raw_content)

                lesson_id = cached_day.lesson_id if cached_day else ""
                day_index = cached_day.index if cached_day else str(data.get("index", ""))
                title = data.get("title") or (cached_day.title if cached_day else "")
                day_date = data.get("date") or (cached_day.date if cached_day else "")

                day = SSDay(
                    id=day_id,
                    lesson_id=lesson_id,
                    index=day_index,
                    title=title,
                    date=day_date,
                    content=processed_content,
                    read_path=target_path,
                )
                await self.repository.save_day(day)
                return day
        except Exception:
            logger.warning("Falha ao buscar conteúdo do dia %s.", day_id)
        finally:
            if should_close:
                await client.aclose()

        if cached_day and cached_day.content:
            cached_day.content = self.html_to_markdown(cached_day.content)
        return cached_day

    # -----------------------------------------------------------------------
    # Rotinas de Download Offline (Semana e Trimestre)
    # -----------------------------------------------------------------------

    async def download_week_lesson(
        self,
        quarterly_id: str,
        lesson_id: str,
        lang: str = "pt",
        progress_callback: Callable[[float, str], None] | None = None,
    ) -> bool:
        """
        Baixa o conteúdo completo de todos os dias de uma lição semanal:
        - Faz o parse do conteúdo (HTML/Markdown) identificando URLs de imagens.
        - Baixa os arquivos de imagem para o diretório de dados locais do app.
        - Substitui a URL remota pelo caminho local antes de persistir no SQLite.
        """
        try:
            if progress_callback:
                progress_callback(0.05, f"Carregando lição {lesson_id}...")

            days = await self.get_lesson_days(lesson_id, quarterly_id=quarterly_id, lang=lang, force_refresh=True)
            if not days:
                logger.warning("Nenhum dia encontrado para a lição %s.", lesson_id)
                return False

            total_days = len(days)
            for idx, day in enumerate(days):
                step_progress = 0.1 + (0.85 * (idx / total_days))
                if progress_callback:
                    progress_callback(step_progress, f"Baixando {day.title or f'Dia {idx + 1}'}...")

                # Baixa e processa imagens do dia
                await self.get_day_content(
                    day_id=day.id,
                    read_path=day.read_path,
                    lang=lang,
                    force_refresh=True,
                )

            if progress_callback:
                progress_callback(1.0, "Lição salva para leitura offline!")

            return True
        except Exception:
            logger.exception("Erro ao realizar download da lição semanal %s.", lesson_id)
            return False

    async def download_entire_quarter(
        self,
        quarterly_id: str,
        lang: str = "pt",
        progress_callback: Callable[[float, str], None] | None = None,
    ) -> bool:
        """
        Baixa todas as lições e dias de um trimestre inteiro com todas as imagens em cache.
        """
        try:
            if progress_callback:
                progress_callback(0.02, "Carregando lições do trimestre...")

            lessons = await self.get_lessons(quarterly_id, lang=lang, force_refresh=True)
            if not lessons:
                return False

            total_lessons = len(lessons)
            for idx, lesson in enumerate(lessons):
                fraction_start = idx / total_lessons
                fraction_end = (idx + 1) / total_lessons

                def _lesson_sub_progress(p: float, msg: str):
                    if progress_callback:
                        combined = fraction_start + (fraction_end - fraction_start) * p
                        progress_callback(combined, f"Lição {idx + 1}/{total_lessons}: {msg}")

                await self.download_week_lesson(
                    quarterly_id=quarterly_id,
                    lesson_id=lesson.id,
                    lang=lang,
                    progress_callback=_lesson_sub_progress,
                )

            if progress_callback:
                progress_callback(1.0, "Trimestre completo salvo para leitura offline!")

            return True
        except Exception:
            logger.exception("Erro ao realizar download do trimestre completo %s.", quarterly_id)
            return False

    # -----------------------------------------------------------------------
    # Anotações do Usuário
    # -----------------------------------------------------------------------

    async def get_note(self, day_id: str) -> str | None:
        """Recupera anotação pessoal salva para o dia."""
        return await self.repository.get_note(day_id)

    async def save_note(self, day_id: str, note_text: str) -> None:
        """Salva a anotação pessoal do dia."""
        await self.repository.save_note(day_id, note_text)

    # -----------------------------------------------------------------------
    # Vídeos da Lição (Vídeo do Dia & Resumo da Semana)
    # -----------------------------------------------------------------------

    def get_lesson_videos(
        self,
        lesson_title: str,
        day_title: str | None = None,
        category: str = "adultos",
    ) -> dict[str, dict[str, str]]:
        """
        Retorna links e metadados estruturados para os vídeos da lição:
        - video_do_dia: Comentário diário / tirinha explainer.
        - resumo_semana: Painel de discussão aprofundada (Adventismo Vivo / Código Aberto).
        """
        is_jovens = category.lower() == "jovens"
        cat_label = "Jovens" if is_jovens else "Adultos"
        clean_lesson = re.sub(r'^\d+\s*[-–.]\s*', '', lesson_title).strip()
        clean_day = re.sub(r'^\d+\s*[-–.]\s*', '', day_title or '').strip()

        day_query = f"Lição da Escola Sabatina {cat_label} {clean_lesson} {clean_day}".strip()
        panel_name = "Código Aberto" if is_jovens else "Adventismo Vivo"
        week_query = f"{panel_name} Lição {cat_label} {clean_lesson}".strip()

        url_day = f"https://www.youtube.com/results?search_query={urllib.parse.quote(day_query)}"
        url_week = f"https://www.youtube.com/results?search_query={urllib.parse.quote(week_query)}"

        return {
            "video_do_dia": {
                "title": "Vídeo do Dia",
                "subtitle": f"Comentário da Lição • {clean_day or clean_lesson}",
                "channel": f"Comentário {cat_label}",
                "url": url_day,
                "badge": "Diário",
            },
            "resumo_semana": {
                "title": "Resumo da Semana",
                "subtitle": f"Painel de discussão aprofundada ({panel_name})",
                "channel": panel_name,
                "url": url_week,
                "badge": "Semanal",
            },
        }

