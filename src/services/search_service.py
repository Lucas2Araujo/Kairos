"""
src/services/search_service.py

Unified global search service across Hymns, Bible, Devotionals, and Sabbath School.
Powered by SQLite FTS5 BM25 scoring with fallback tiers:
1. Exact full-phrase match
2. All-terms AND match
3. Term prefix match

Detects available FTS5 tables dynamically so missing tables do not crash.
Provides top unified results for the search bottom sheet with type icons and labels,
as well as pagination/lazy loading support (limit, offset, optional type_filter).
"""

from __future__ import annotations

import logging
import re
import sqlite3
import urllib.parse
from dataclasses import dataclass
from enum import Enum
from typing import Any

from src.database.connection import DatabaseConnection

logger = logging.getLogger(__name__)


class SearchContentType(str, Enum):
    HINO = "hino"
    BIBLIA = "biblia"
    MEDITACAO = "meditacao"
    LICAO = "licao"


@dataclass
class SearchResultItem:
    id: str
    content_type: SearchContentType
    title: str
    subtitle: str
    route: str
    score: float
    icon_name: str
    type_label: str
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "content_type": self.content_type.value,
            "title": self.title,
            "subtitle": self.subtitle,
            "route": self.route,
            "score": self.score,
            "icon_name": self.icon_name,
            "type_label": self.type_label,
            "metadata": self.metadata,
        }


@dataclass
class SearchResultsPage:
    items: list[SearchResultItem]
    total_count: int
    offset: int
    limit: int
    has_more: bool
    counts_by_type: dict[str, int]


class SearchService:
    """
    Motor de busca global multi-entidade do Kairós.
    Busca em:
      - Hinos (hino_fts)
      - Bíblia Sagrada (biblia_fts)
      - Meditações Diárias (meditacao_fts)
      - Escola Sabatina (licao_fts)
    """

    TYPE_LABELS = {
        SearchContentType.HINO: "Hino",
        SearchContentType.BIBLIA: "Bíblia",
        SearchContentType.MEDITACAO: "Meditação",
        SearchContentType.LICAO: "Lição",
    }

    TYPE_ICONS = {
        SearchContentType.HINO: "music_note",
        SearchContentType.BIBLIA: "menu_book",
        SearchContentType.MEDITACAO: "favorite_outline",
        SearchContentType.LICAO: "school",
    }

    def __init__(self, db_connection: DatabaseConnection):
        self.db_connection = db_connection
        self._available_tables: set[str] | None = None

    async def detect_available_tables(self, force_refresh: bool = False) -> set[str]:
        """Detecta dinamicamente quais tabelas virtuais FTS5 estão disponíveis no banco."""
        if self._available_tables is not None and not force_refresh:
            return self._available_tables

        detected: set[str] = set()
        expected = {"hino_fts", "biblia_fts", "meditacao_fts", "licao_fts"}
        try:
            conn = await self.db_connection.get_connection()
            async with conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('hino_fts', 'biblia_fts', 'meditacao_fts', 'licao_fts');"
            ) as cursor:
                rows = await cursor.fetchall()
                for r in rows:
                    name = r[0] if isinstance(r, (list, tuple)) else r["name"]
                    if name in expected:
                        detected.add(name)
        except Exception as exc:
            logger.warning("Erro ao detectar tabelas FTS5: %s", exc)

        self._available_tables = detected
        return detected

    @staticmethod
    def _sanitize_tokens(query: str) -> list[str]:
        """Higieniza a consulta retornando tokens alfanuméricos limpos."""
        cleaned = re.sub(r'[^\w\s]', ' ', query)
        tokens = [t.strip() for t in cleaned.split() if len(t.strip()) > 0]
        return tokens

    @classmethod
    def _build_fts_query_tiers(cls, raw_query: str) -> list[tuple[str, float]]:
        """
        Gera as 3 expressões de busca FTS5 em ordem de prioridade:
        1. Frase exata (full-phrase match) -> menor penalidade (-50.0 boost)
        2. Todos os termos AND (all-terms AND) -> menor penalidade (-25.0 boost)
        3. Prefixos dos termos (term prefix) -> sem boost adicional (0.0)
        """
        q = raw_query.strip()
        tokens = cls._sanitize_tokens(q)
        if not tokens:
            return []

        tiers: list[tuple[str, float]] = []

        # 1. Exact phrase (somente se tiver 1 ou mais tokens)
        phrase_escaped = ' '.join(f'"{t}"' for t in tokens)
        tiers.append((phrase_escaped, -50.0))

        # 2. All-terms AND (se tiver mais de 1 termo)
        if len(tokens) > 1:
            and_expr = ' AND '.join(f'"{t}"' for t in tokens)
            tiers.append((and_expr, -25.0))

        # 3. Term prefix match (cada token com *)
        prefix_expr = ' AND '.join(f'"{t}"*' for t in tokens)
        tiers.append((prefix_expr, 0.0))

        return tiers

    async def _search_hinos(
        self,
        conn: Any,
        tiers: list[tuple[str, float]],
        clean_num: str | None,
        max_rows: int,
    ) -> list[SearchResultItem]:
        results: dict[str, SearchResultItem] = {}

        # 1. Busca por número exato ou prefixo caso numérico
        if clean_num:
            try:
                sql_num = """
                    SELECT id, numero, titulo, categoria, subcategoria
                    FROM hino
                    WHERE numero = ? OR numero LIKE ?
                    ORDER BY CASE WHEN numero = ? THEN 0 ELSE 1 END, CAST(numero AS INTEGER) ASC
                    LIMIT ?;
                """
                async with conn.execute(sql_num, (clean_num, f"{clean_num}%", clean_num, max_rows)) as cursor:
                    rows = await cursor.fetchall()
                    for r in rows:
                        hid = str(r["id"])
                        num = str(r["numero"])
                        tit = str(r["titulo"])
                        cat = str(r["categoria"] or "")
                        sub = str(r["subcategoria"] or "")
                        sub_text = f"Hino {num} • {cat}" if cat else f"Hino {num}"
                        if sub:
                            sub_text += f" - {sub}"
                        score = -100.0 if num == clean_num else -80.0
                        results[hid] = SearchResultItem(
                            id=f"hino_{hid}",
                            content_type=SearchContentType.HINO,
                            title=f"{num}. {tit}",
                            subtitle=sub_text,
                            route=f"/novo?hino={num}",
                            score=score,
                            icon_name=self.TYPE_ICONS[SearchContentType.HINO],
                            type_label=self.TYPE_LABELS[SearchContentType.HINO],
                            metadata={"numero": num, "id": hid, "titulo": tit},
                        )
            except Exception as exc:
                logger.debug("Falha na busca direta de número de hino: %s", exc)

        # 2. Busca FTS5
        sql_fts = """
            SELECT rowid, numero, titulo, categoria, subcategoria, bm25(hino_fts) as rank
            FROM hino_fts
            WHERE hino_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?;
        """
        for fts_expr, tier_boost in tiers:
            if len(results) >= max_rows:
                break
            try:
                async with conn.execute(sql_fts, (fts_expr, max_rows)) as cursor:
                    rows = await cursor.fetchall()
                    for r in rows:
                        hid = str(r["rowid"])
                        item_key = f"hino_{hid}"
                        if item_key in results:
                            continue
                        num = str(r["numero"])
                        tit = str(r["titulo"])
                        cat = str(r["categoria"] or "")
                        sub = str(r["subcategoria"] or "")
                        sub_text = f"Hino {num} • {cat}" if cat else f"Hino {num}"
                        if sub:
                            sub_text += f" - {sub}"
                        raw_rank = float(r["rank"])
                        effective_score = raw_rank + tier_boost
                        results[item_key] = SearchResultItem(
                            id=item_key,
                            content_type=SearchContentType.HINO,
                            title=f"{num}. {tit}",
                            subtitle=sub_text,
                            route=f"/novo?hino={num}",
                            score=effective_score,
                            icon_name=self.TYPE_ICONS[SearchContentType.HINO],
                            type_label=self.TYPE_LABELS[SearchContentType.HINO],
                            metadata={"numero": num, "id": hid, "titulo": tit},
                        )
            except Exception as exc:
                logger.debug("Falha na query hino_fts (%s): %s", fts_expr, exc)

        return list(results.values())

    async def _search_biblia(
        self,
        conn: Any,
        tiers: list[tuple[str, float]],
        max_rows: int,
    ) -> list[SearchResultItem]:
        results: dict[str, SearchResultItem] = {}

        sql_fts = """
            SELECT rowid, book_id, book_name, chapter, verse, verse_reference, text, bm25(biblia_fts) as rank
            FROM biblia_fts
            WHERE biblia_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?;
        """
        for fts_expr, tier_boost in tiers:
            if len(results) >= max_rows:
                break
            try:
                async with conn.execute(sql_fts, (fts_expr, max_rows)) as cursor:
                    rows = await cursor.fetchall()
                    for r in rows:
                        vid = str(r["rowid"])
                        item_key = f"biblia_{vid}"
                        if item_key in results:
                            continue
                        bname = str(r["book_name"])
                        ch = int(r["chapter"])
                        vn = int(r["verse"])
                        ref = str(r["verse_reference"]) or f"{bname} {ch}:{vn}"
                        txt = str(r["text"])
                        raw_rank = float(r["rank"])
                        effective_score = raw_rank + tier_boost

                        route_bname = urllib.parse.quote(bname)
                        route = f"/biblia?livro={route_bname}&cap={ch}&ver={vn}"

                        results[item_key] = SearchResultItem(
                            id=item_key,
                            content_type=SearchContentType.BIBLIA,
                            title=ref,
                            subtitle=txt,
                            route=route,
                            score=effective_score,
                            icon_name=self.TYPE_ICONS[SearchContentType.BIBLIA],
                            type_label=self.TYPE_LABELS[SearchContentType.BIBLIA],
                            metadata={
                                "book_id": r["book_id"],
                                "book_name": bname,
                                "chapter": ch,
                                "verse": vn,
                                "text": txt,
                            },
                        )
            except Exception as exc:
                logger.debug("Falha na query biblia_fts (%s): %s", fts_expr, exc)

        return list(results.values())

    async def _search_meditacao(
        self,
        conn: Any,
        tiers: list[tuple[str, float]],
        max_rows: int,
    ) -> list[SearchResultItem]:
        results: dict[str, SearchResultItem] = {}

        sql_fts = """
            SELECT rowid, published_at, category, title, verse_text, verse_reference, content, author, bm25(meditacao_fts) as rank
            FROM meditacao_fts
            WHERE meditacao_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?;
        """
        for fts_expr, tier_boost in tiers:
            if len(results) >= max_rows:
                break
            try:
                async with conn.execute(sql_fts, (fts_expr, max_rows)) as cursor:
                    rows = await cursor.fetchall()
                    for r in rows:
                        mid = str(r["rowid"])
                        item_key = f"med_{mid}"
                        if item_key in results:
                            continue
                        pub_date = str(r["published_at"])
                        cat = str(r["category"] or "jovem").capitalize()
                        title = str(r["title"])
                        vref = str(r["verse_reference"] or "")
                        content = str(r["content"] or "")
                        snippet = vref if vref else (content[:120].strip() + ("..." if len(content) > 120 else ""))
                        subtitle = f"{pub_date} • {cat}"
                        if snippet:
                            subtitle += f" — {snippet}"

                        raw_rank = float(r["rank"])
                        effective_score = raw_rank + tier_boost

                        route = f"/meditacoes?data={pub_date}"

                        results[item_key] = SearchResultItem(
                            id=item_key,
                            content_type=SearchContentType.MEDITACAO,
                            title=title,
                            subtitle=subtitle,
                            route=route,
                            score=effective_score,
                            icon_name=self.TYPE_ICONS[SearchContentType.MEDITACAO],
                            type_label=self.TYPE_LABELS[SearchContentType.MEDITACAO],
                            metadata={
                                "published_at": pub_date,
                                "category": r["category"],
                                "title": title,
                                "verse_reference": vref,
                            },
                        )
            except Exception as exc:
                logger.debug("Falha na query meditacao_fts (%s): %s", fts_expr, exc)

        return list(results.values())

    async def _search_licao(
        self,
        conn: Any,
        tiers: list[tuple[str, float]],
        max_rows: int,
    ) -> list[SearchResultItem]:
        results: dict[str, SearchResultItem] = {}

        sql_fts = """
            SELECT rowid, day_id, lesson_id, lesson_title, day_title, date, content, bm25(licao_fts) as rank
            FROM licao_fts
            WHERE licao_fts MATCH ?
            ORDER BY rank ASC
            LIMIT ?;
        """
        for fts_expr, tier_boost in tiers:
            if len(results) >= max_rows:
                break
            try:
                async with conn.execute(sql_fts, (fts_expr, max_rows)) as cursor:
                    rows = await cursor.fetchall()
                    for r in rows:
                        lid = str(r["rowid"])
                        item_key = f"licao_{lid}"
                        if item_key in results:
                            continue
                        day_id = str(r["day_id"])
                        lesson_id = str(r["lesson_id"])
                        lesson_title = str(r["lesson_title"] or "")
                        day_title = str(r["day_title"] or "")
                        date_str = str(r["date"] or "")
                        content = str(r["content"] or "")

                        main_title = f"{day_title} - {lesson_title}" if lesson_title else day_title
                        clean_content = re.sub(r'[#*`!\[\]\(\)]', ' ', content)
                        clean_content = ' '.join(clean_content.split())
                        snippet = clean_content[:110] + ("..." if len(clean_content) > 110 else "")
                        subtitle = f"{date_str} • {snippet}" if date_str else snippet

                        raw_rank = float(r["rank"])
                        effective_score = raw_rank + tier_boost

                        route = f"/escola-sabatina?lesson={lesson_id}&day={day_id}"

                        results[item_key] = SearchResultItem(
                            id=item_key,
                            content_type=SearchContentType.LICAO,
                            title=main_title,
                            subtitle=subtitle,
                            route=route,
                            score=effective_score,
                            icon_name=self.TYPE_ICONS[SearchContentType.LICAO],
                            type_label=self.TYPE_LABELS[SearchContentType.LICAO],
                            metadata={
                                "day_id": day_id,
                                "lesson_id": lesson_id,
                                "lesson_title": lesson_title,
                                "day_title": day_title,
                                "date": date_str,
                            },
                        )
            except Exception as exc:
                logger.debug("Falha na query licao_fts (%s): %s", fts_expr, exc)

        return list(results.values())

    async def search(
        self,
        query: str,
        limit: int = 50,
        offset: int = 0,
        type_filter: SearchContentType | str | None = None,
    ) -> SearchResultsPage:
        """
        Executa pesquisa FTS5 unificada por ranking BM25 e estratificação de precisão.
        """
        q_clean = query.strip()
        if not q_clean:
            return SearchResultsPage(
                items=[],
                total_count=0,
                offset=offset,
                limit=limit,
                has_more=False,
                counts_by_type={t.value: 0 for t in SearchContentType},
            )

        available_tables = await self.detect_available_tables()
        tiers = self._build_fts_query_tiers(q_clean)
        num_clean = q_clean if (q_clean.isdigit() or re.match(r'^\d+[a-zA-Z]?$', q_clean)) else None

        conn = await self.db_connection.get_connection()
        collected_items: list[SearchResultItem] = []

        # Determina quais tipos pesquisar com base em type_filter
        if isinstance(type_filter, str):
            try:
                type_filter = SearchContentType(type_filter.lower())
            except ValueError:
                type_filter = None

        search_all = type_filter is None

        # Coleta de cada categoria permitida
        # Hinos
        if (search_all or type_filter == SearchContentType.HINO) and "hino_fts" in available_tables:
            hino_items = await self._search_hinos(conn, tiers, num_clean, max_rows=150)
            collected_items.extend(hino_items)

        # Bíblia
        if (search_all or type_filter == SearchContentType.BIBLIA) and "biblia_fts" in available_tables:
            biblia_items = await self._search_biblia(conn, tiers, max_rows=150)
            collected_items.extend(biblia_items)

        # Meditação
        if (search_all or type_filter == SearchContentType.MEDITACAO) and "meditacao_fts" in available_tables:
            med_items = await self._search_meditacao(conn, tiers, max_rows=100)
            collected_items.extend(med_items)

        # Escola Sabatina
        if (search_all or type_filter == SearchContentType.LICAO) and "licao_fts" in available_tables:
            licao_items = await self._search_licao(conn, tiers, max_rows=100)
            collected_items.extend(licao_items)

        # Calcula contagens por tipo antes da paginação
        counts_by_type: dict[str, int] = {t.value: 0 for t in SearchContentType}
        for item in collected_items:
            counts_by_type[item.content_type.value] += 1

        # Ordena unificadamente por score BM25 (menor é mais relevante no SQLite FTS5)
        collected_items.sort(key=lambda x: x.score)

        total_count = len(collected_items)
        paged_items = collected_items[offset : offset + limit]
        has_more = (offset + limit) < total_count

        return SearchResultsPage(
            items=paged_items,
            total_count=total_count,
            offset=offset,
            limit=limit,
            has_more=has_more,
            counts_by_type=counts_by_type,
        )

    async def get_top_unified(self, query: str, limit: int = 5) -> tuple[list[SearchResultItem], int]:
        """
        Retorna até `limit` itens unificados mais relevantes para exibição no BottomSheet,
        juntamente com a contagem total de resultados disponíveis no app.
        """
        page = await self.search(query=query, limit=limit, offset=0, type_filter=None)
        return page.items, page.total_count
