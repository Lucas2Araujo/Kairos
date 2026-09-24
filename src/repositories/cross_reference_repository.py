import asyncio
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

from src.database.connection import DatabaseConnection
from src.models.cross_reference import CrossReferenceItem


class CrossReferenceRepository:
    """
    Repositório assíncrono para consulta otimizada de referências cruzadas bíblicas.
    Opera estritamente em modo leitura com consultas parametrizadas (?).
    Suporta busca para versículo único e em lote (multi-versículos) com proteção contra DoS.
    """

    DEFAULT_DB_FILE = "cross_references.sqlite"

    def __init__(self, db_connection: DatabaseConnection | None = None, db_path: str | None = None):
        self._custom_conn = db_connection
        self._db_path = db_path or self.DEFAULT_DB_FILE
        self._connection: DatabaseConnection | None = db_connection

    @staticmethod
    def _candidate_dirs() -> list[Path]:
        """Localiza os diretórios potenciais para o banco de referências cruzadas."""
        src_dir = Path(__file__).resolve().parent.parent  # src
        root_dir = src_dir.parent  # project root
        user_dir = DatabaseConnection._get_user_data_dir()

        return [
            root_dir / "assets",
            user_dir / "modules",
            root_dir / "assets" / "modules",
            src_dir / "assets",
            user_dir,
            root_dir,
        ]

    def _resolve_db_connection(self) -> DatabaseConnection:
        if self._connection is not None:
            return self._connection

        # Se caminho específico absoluto ou relativo direto foi passado
        p = Path(self._db_path)
        if p.exists():
            self._connection = DatabaseConnection(db_path=str(p), read_only=True)
            return self._connection

        # Varre diretórios candidatos
        for candidate_dir in self._candidate_dirs():
            candidate_file = candidate_dir / self.DEFAULT_DB_FILE
            if candidate_file.exists():
                self._connection = DatabaseConnection(
                    db_path=str(candidate_file), read_only=True
                )
                return self._connection

        # Fallback padrão
        self._connection = DatabaseConnection(
            db_path=self._db_path, read_only=True
        )
        return self._connection

    async def has_cross_references_db(self) -> bool:
        """Verifica se a base de dados de referências cruzadas está disponível e instalada."""
        for candidate_dir in self._candidate_dirs():
            if (candidate_dir / self.DEFAULT_DB_FILE).exists():
                return True
        if self._custom_conn is not None:
            return True
        return False

    async def get_cross_references(
        self,
        book_id: int,
        chapter: int,
        verse: int,
        limit: int = 30,
    ) -> list[CrossReferenceItem]:
        """
        Consulta as referências cruzadas para um único versículo.
        Retorna ordenado pela relevância / votos de forma decrescente.
        """
        results_map = await self.get_cross_references_for_verses(
            book_id=book_id,
            chapter=chapter,
            verses=[verse],
            limit_per_verse=limit,
        )
        return results_map.get(verse, [])

    async def get_cross_references_for_verses(
        self,
        book_id: int,
        chapter: int,
        verses: list[int],
        limit_per_verse: int = 20,
    ) -> dict[int, list[CrossReferenceItem]]:
        """
        Consulta referências cruzadas em lote para múltiplos versículos (1 a 10 versículos).
        Garante consultas parametrizadas seguras (?) com proteção contra DoS.

        Args:
            book_id: ID do livro de origem (1..66).
            chapter: Capítulo do livro de origem.
            verses: Lista de versículos selecionados.
            limit_per_verse: Limite de referências por versículo.

        Returns:
            Dicionário mapeando versiculo_num -> list[CrossReferenceItem].
        """
        if not (1 <= book_id <= 66) or chapter < 1 or not verses:
            return {}

        # Trava de segurança (Anti-DoS / Trail of Bits): cap em no máximo 10 versículos
        sanitized_verses = sorted({int(v) for v in verses if v >= 1})[:10]
        if not sanitized_verses:
            return {}

        placeholders = ",".join("?" for _ in sanitized_verses)
        params: list[Any] = [book_id, chapter] + sanitized_verses

        query = f"""
            SELECT from_verse, to_book_id, to_chapter, to_verse_start, to_verse_end, votes
            FROM cross_reference
            WHERE from_book_id = ? AND from_chapter = ? AND from_verse IN ({placeholders})
            ORDER BY from_verse ASC, votes DESC;
        """

        conn_mgr = self._resolve_db_connection()
        grouped_results: dict[int, list[CrossReferenceItem]] = {v: [] for v in sanitized_verses}

        try:
            conn = await conn_mgr.get_connection()
            async with conn.execute(query, params) as cursor:
                rows = await cursor.fetchall()

            for r in rows:
                fv = int(r["from_verse"])
                # Respeita o limite por versículo para não inflar a UI
                if len(grouped_results[fv]) >= limit_per_verse:
                    continue

                item = CrossReferenceItem(
                    from_book_id=book_id,
                    from_chapter=chapter,
                    from_verse=fv,
                    to_book_id=int(r["to_book_id"]),
                    to_chapter=int(r["to_chapter"]),
                    to_verse_start=int(r["to_verse_start"]),
                    to_verse_end=int(r["to_verse_end"]),
                    votes=int(r["votes"]),
                )
                grouped_results[fv].append(item)

        except Exception:
            # Em caso de falha no banco (ex: arquivo ausente antes da migração), retorna vazio sem quebrar
            return grouped_results

        return grouped_results

    async def close(self) -> None:
        """Encerra a conexão com o banco de referências cruzadas."""
        if self._connection:
            try:
                await self._connection.close()
            except Exception:
                pass
            self._connection = None
