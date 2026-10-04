#!/usr/bin/env python3
"""
scripts/build_search_index.py

Idempotently generates and populates FTS5 virtual tables and synchronization triggers
for biblia_fts, meditacao_fts, and licao_fts across the application SQLite database(s).
Designed as an extractable modular script, running directly against hinario.db.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from pathlib import Path

# Paths configuration
DEFAULT_DB_CANDIDATES = [
    Path("src/database/data/hinario.db"),
    Path("assets/hinario.db"),
]

BIBLE_CANDIDATES = [
    Path("src/database/data/ARA.sqlite"),
    Path("src/database/data/biblias/ARA.sqlite"),
    Path("assets/ARA.sqlite"),
    Path("assets/biblias/ARA.sqlite"),
]


def resolve_db_path(explicit_path: str | None = None) -> Path:
    """Resolves target database path from arg, env var, or existing candidates."""
    if explicit_path:
        p = Path(explicit_path)
        if p.exists():
            return p.resolve()
        return p

    env_path = os.environ.get("HINARIO_DB_PATH") or os.environ.get("DB_PATH")
    if env_path and Path(env_path).exists():
        return Path(env_path).resolve()

    for cand in DEFAULT_DB_CANDIDATES:
        if cand.exists():
            return cand.resolve()

    return DEFAULT_DB_CANDIDATES[0].resolve()


def find_bible_source_path() -> Path | None:
    """Finds an existing Bible SQLite database containing the verse and book tables."""
    for cand in BIBLE_CANDIDATES:
        if cand.exists() and cand.stat().st_size > 0:
            return cand.resolve()
    return None


def setup_fts_indexes(db_path: Path, bible_source_path: Path | None = None) -> dict[str, int]:
    """
    Creates virtual tables and triggers idempotently, and populates data.
    Returns counts of indexed items per table.
    """
    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}")

    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    counts: dict[str, int] = {"biblia": 0, "meditacao": 0, "licao": 0}

    try:
        # Enable WAL mode for high performance
        conn.execute("PRAGMA journal_mode = WAL;")
        conn.execute("PRAGMA synchronous = NORMAL;")

        # -------------------------------------------------------------
        # 1. biblia_fts
        # -------------------------------------------------------------
        conn.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS biblia_fts USING fts5(
                book_id UNINDEXED,
                book_name,
                chapter UNINDEXED,
                verse UNINDEXED,
                verse_reference,
                text,
                tokenize="unicode61 remove_diacritics 2"
            );
        """)

        # Populate biblia_fts if empty
        row = conn.execute("SELECT COUNT(*) FROM biblia_fts;").fetchone()
        biblia_count = row[0] if row else 0

        if biblia_count == 0:
            # Check if verse table is already present in this DB or in external Bible DB
            has_local_verse = conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='verse';"
            ).fetchone()

            if has_local_verse:
                conn.execute("""
                    INSERT INTO biblia_fts(rowid, book_id, book_name, chapter, verse, verse_reference, text)
                    SELECT 
                        v.id,
                        v.book_id,
                        COALESCE(b.name, ''),
                        v.chapter,
                        v.verse,
                        COALESCE(b.name, '') || ' ' || v.chapter || ':' || v.verse,
                        COALESCE(v.text, '')
                    FROM verse v
                    LEFT JOIN book b ON v.book_id = b.id;
                """)
                conn.commit()
            elif bible_source_path and bible_source_path.exists():
                # Attach external Bible database (e.g. ARA.sqlite)
                bible_path_str = str(bible_source_path.resolve())
                conn.execute("ATTACH DATABASE ? AS bible_src;", (bible_path_str,))
                try:
                    conn.execute("""
                        INSERT INTO biblia_fts(rowid, book_id, book_name, chapter, verse, verse_reference, text)
                        SELECT 
                            v.id,
                            v.book_id,
                            COALESCE(b.name, ''),
                            v.chapter,
                            v.verse,
                            COALESCE(b.name, '') || ' ' || v.chapter || ':' || v.verse,
                            COALESCE(v.text, '')
                        FROM bible_src.verse v
                        LEFT JOIN bible_src.book b ON v.book_id = b.id;
                    """)
                    conn.commit()
                finally:
                    conn.execute("DETACH DATABASE bible_src;")

            row = conn.execute("SELECT COUNT(*) FROM biblia_fts;").fetchone()
            counts["biblia"] = row[0] if row else 0
        else:
            counts["biblia"] = biblia_count

        # -------------------------------------------------------------
        # 2. meditacao_fts
        # -------------------------------------------------------------
        conn.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS meditacao_fts USING fts5(
                published_at UNINDEXED,
                category UNINDEXED,
                title,
                verse_text,
                verse_reference,
                content,
                author,
                tokenize="unicode61 remove_diacritics 2"
            );
        """)

        # Drop existing triggers if present to ensure clean idempotency
        conn.execute("DROP TRIGGER IF EXISTS trg_meditacao_ai;")
        conn.execute("DROP TRIGGER IF EXISTS trg_meditacao_ad;")
        conn.execute("DROP TRIGGER IF EXISTS trg_meditacao_au;")

        # Create triggers on cached_devotionals if the base table exists
        has_devotionals = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='cached_devotionals';"
        ).fetchone()

        if has_devotionals:
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_meditacao_ai AFTER INSERT ON cached_devotionals BEGIN
                    INSERT INTO meditacao_fts(rowid, published_at, category, title, verse_text, verse_reference, content, author)
                    VALUES (new.rowid, new.published_at, new.category, new.title, new.verse_text, new.verse_reference, new.content, new.author);
                END;
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_meditacao_ad AFTER DELETE ON cached_devotionals BEGIN
                    DELETE FROM meditacao_fts WHERE rowid = old.rowid;
                END;
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_meditacao_au AFTER UPDATE ON cached_devotionals BEGIN
                    DELETE FROM meditacao_fts WHERE rowid = old.rowid;
                    INSERT INTO meditacao_fts(rowid, published_at, category, title, verse_text, verse_reference, content, author)
                    VALUES (new.rowid, new.published_at, new.category, new.title, new.verse_text, new.verse_reference, new.content, new.author);
                END;
            """)

            # Populate if empty
            row = conn.execute("SELECT COUNT(*) FROM meditacao_fts;").fetchone()
            med_count = row[0] if row else 0
            if med_count == 0:
                conn.execute("""
                    INSERT INTO meditacao_fts(rowid, published_at, category, title, verse_text, verse_reference, content, author)
                    SELECT 
                        rowid,
                        published_at,
                        category,
                        COALESCE(title, ''),
                        COALESCE(verse_text, ''),
                        COALESCE(verse_reference, ''),
                        COALESCE(content, ''),
                        COALESCE(author, '')
                    FROM cached_devotionals;
                """)
                conn.commit()

        row = conn.execute("SELECT COUNT(*) FROM meditacao_fts;").fetchone()
        counts["meditacao"] = row[0] if row else 0

        # -------------------------------------------------------------
        # 3. licao_fts (Sabbath School Days + Lessons)
        # -------------------------------------------------------------
        conn.execute("""
            CREATE VIRTUAL TABLE IF NOT EXISTS licao_fts USING fts5(
                day_id UNINDEXED,
                lesson_id UNINDEXED,
                lesson_title,
                day_title,
                date UNINDEXED,
                content,
                tokenize="unicode61 remove_diacritics 2"
            );
        """)

        conn.execute("DROP TRIGGER IF EXISTS trg_licao_day_ai;")
        conn.execute("DROP TRIGGER IF EXISTS trg_licao_day_ad;")
        conn.execute("DROP TRIGGER IF EXISTS trg_licao_day_au;")

        has_ss_days = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name='ss_days';"
        ).fetchone()

        if has_ss_days:
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_licao_day_ai AFTER INSERT ON ss_days BEGIN
                    INSERT INTO licao_fts(rowid, day_id, lesson_id, lesson_title, day_title, date, content)
                    SELECT 
                        new.rowid,
                        new.id,
                        new.lesson_id,
                        COALESCE((SELECT title FROM ss_lessons WHERE id = new.lesson_id), ''),
                        new.title,
                        new.date,
                        new.content;
                END;
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_licao_day_ad AFTER DELETE ON ss_days BEGIN
                    DELETE FROM licao_fts WHERE rowid = old.rowid;
                END;
            """)
            conn.execute("""
                CREATE TRIGGER IF NOT EXISTS trg_licao_day_au AFTER UPDATE ON ss_days BEGIN
                    DELETE FROM licao_fts WHERE rowid = old.rowid;
                    INSERT INTO licao_fts(rowid, day_id, lesson_id, lesson_title, day_title, date, content)
                    SELECT 
                        new.rowid,
                        new.id,
                        new.lesson_id,
                        COALESCE((SELECT title FROM ss_lessons WHERE id = new.lesson_id), ''),
                        new.title,
                        new.date,
                        new.content;
                END;
            """)

            row = conn.execute("SELECT COUNT(*) FROM licao_fts;").fetchone()
            licao_count = row[0] if row else 0
            if licao_count == 0:
                conn.execute("""
                    INSERT INTO licao_fts(rowid, day_id, lesson_id, lesson_title, day_title, date, content)
                    SELECT 
                        d.rowid,
                        d.id,
                        d.lesson_id,
                        COALESCE(l.title, ''),
                        COALESCE(d.title, ''),
                        COALESCE(d.date, ''),
                        COALESCE(d.content, '')
                    FROM ss_days d
                    LEFT JOIN ss_lessons l ON d.lesson_id = l.id;
                """)
                conn.commit()

        row = conn.execute("SELECT COUNT(*) FROM licao_fts;").fetchone()
        counts["licao"] = row[0] if row else 0

        # Run integrity-check
        for table in ("biblia_fts", "meditacao_fts", "licao_fts"):
            try:
                conn.execute(f"INSERT INTO {table}({table}) VALUES('integrity-check');")
            except sqlite3.OperationalError:
                pass

        conn.commit()
    finally:
        conn.close()

    return counts


def main() -> int:
    parser = argparse.ArgumentParser(description="Build and populate FTS5 search indexes for Kairós.")
    parser.add_argument("--db", type=str, help="Path to hinario.db SQLite file", default=None)
    parser.add_argument("--bible", type=str, help="Path to ARA.sqlite Bible database file", default=None)
    parser.add_argument("--all-targets", action="store_true", help="Build indexes on both assets/ and src/ databases")
    args = parser.parse_args()

    bible_path = Path(args.bible) if args.bible else find_bible_source_path()
    targets: list[Path] = []

    if args.all_targets:
        targets = [p for p in DEFAULT_DB_CANDIDATES if p.exists()]
    elif args.db:
        targets = [Path(args.db)]
    else:
        targets = [resolve_db_path()]

    print(f"[*] Bible source database: {bible_path}")
    for target in targets:
        print(f"[*] Building search indexes for: {target}")
        res = setup_fts_indexes(target, bible_source_path=bible_path)
        print(f"    [+] biblia_fts: {res['biblia']} entries")
        print(f"    [+] meditacao_fts: {res['meditacao']} entries")
        print(f"    [+] licao_fts: {res['licao']} entries")

    print("[*] Search index build completed successfully.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
