# Task: Public Domain Bible Commentaries (Comentários Bíblicos em Domínio Público)

## Status: STAGE 2 - IMPLEMENTED

### Active Skills & Guardrails
- `superpowers`, `planning-with-files`, `trailofbits`, `ponytail`, `caveman`.

---

## 1. Architecture & Storage Plan
- **Database:** `assets/commentaries.sqlite`
- **Tables:**
  - `authors`:
    - `id INTEGER PRIMARY KEY AUTOINCREMENT`
    - `slug TEXT UNIQUE NOT NULL`
    - `name TEXT NOT NULL`
    - `short_name TEXT`
    - `description TEXT`
    - `is_public_domain INTEGER NOT NULL DEFAULT 1`
  - `commentaries`:
    - `id INTEGER PRIMARY KEY AUTOINCREMENT`
    - `author_id INTEGER NOT NULL REFERENCES authors(id)`
    - `book_id INTEGER NOT NULL`
    - `chapter INTEGER NOT NULL`
    - `verse_start INTEGER NOT NULL`
    - `verse_end INTEGER NOT NULL`
    - `title TEXT`
    - `content TEXT NOT NULL`
    - `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- **Indices:**
  - `idx_comm_lookup ON commentaries (book_id, chapter, verse_start, verse_end)`
  - `idx_comm_author ON commentaries (author_id, book_id, chapter)`

## 2. Ingestion & Security Strategy (trailofbits)
- All external content ingested via parameterized SQL queries (`?`).
- Markdown text sanitized and trimmed; zero raw HTML execution.
- Content retrieved asynchronously via `aiosqlite` with strict connection pooling.
- Range coverage matching: `WHERE book_id = ? AND chapter = ? AND verse_start <= ? AND verse_end >= ?`.

## 3. UI/UX Flow (Flet & Material 3)
- Action button `ft.Icons.COMMENT_OUTLINED` added to selection appbar in `src/views/biblia_view.py`.
- Opens lazy-loaded `ft.BottomSheet` with commentary text, author chips/selector, and verse citation.
- Zero memory bloat: commentaries are queried strictly on demand when user requests.

## 4. Verification & TDD Plan
- Unit tests in `tests/test_commentaries.py`:
  - Author retrieval
  - Single-verse commentary lookup
  - Verse-range commentary lookup
  - Empty fallback handling
  - SQL injection safety
