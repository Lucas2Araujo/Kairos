# Task: Implement Cross-References (OpenBible dataset) into Kairós Bible Module

## Checklist & Progress
- [x] **Stage 1: Read-Only Audit & Architectural Discovery**
  - [x] 1. Bible Storage & Schema Audit
  - [x] 2. Flet UI & Reader Event Flow Inspection
  - [x] 3. OpenBible Dataset Normalization & Schema Design
  - [x] 4. Architectural Spec & Plan Review
- [x] **Plan Update: Multi-Verse Support & Localization Hardening**
  - [x] Multi-verse selection (`len(selected_verses) >= 1`, max cap 10)
  - [x] Flet UI adaptive grouping: `ft.SegmentedButton` (<= 4 verses) vs `ft.ExpansionTile` (> 4 verses)
  - [x] Localization: zero English slugs exposed to user, mapped 100% to canonical PT-BR
- [x] **Stage 2: Implementation (TDD, Architecture & UI)**
  - [x] 1. Ingestion script with full USFM -> Book ID (1..66) mapping (`scripts/ingest_cross_references.py`)
  - [x] 2. Cross-Reference DTOs & Model (`src/models/cross_reference.py`)
  - [x] 3. Repository with batch parameterized `IN (?, ...)` queries (`src/repositories/cross_reference_repository.py`)
  - [x] 4. Unit tests: parser, multi-verse queries, caps, deduplication, latency benchmarks (`tests/test_cross_references.py`)
  - [x] 5. Flet UI Integration in `src/views/biblia_view.py`:
    - Selection AppBar button enabled for `1 <= len(selected_verses) <= 10`
    - Modal BottomSheet with adaptive grouping (`ft.SegmentedButton` / `ft.ExpansionTile`)
    - Verse badge headers and PT-BR localized citations
    - "Ler no contexto" fast navigation
  - [x] 6. End-to-end verification and regression tests run (All 39 biblia tests passing)

---

## 1. Architectural Architecture & Design Decisions

### Storage Architecture
- Dedicated SQLite database: `assets/cross_references.sqlite` (fallback to module directories).
- **Table Definition**:
  ```sql
  CREATE TABLE IF NOT EXISTS cross_reference (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_book_id INTEGER NOT NULL,
      from_chapter INTEGER NOT NULL,
      from_verse INTEGER NOT NULL,
      to_book_id INTEGER NOT NULL,
      to_chapter INTEGER NOT NULL,
      to_verse_start INTEGER NOT NULL,
      to_verse_end INTEGER NOT NULL,
      votes INTEGER NOT NULL DEFAULT 0
  );
  ```
- **Indices**:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_cross_ref_source 
  ON cross_reference (from_book_id, from_chapter, from_verse, votes DESC);

  CREATE INDEX IF NOT EXISTS idx_cross_ref_target
  ON cross_reference (to_book_id, to_chapter, to_verse_start);
  ```

### Localization Guarantee (Trail of Bits & Caveman)
- Ingestion converts all OpenBible USFM abbreviations (`Gen`, `Matt`, `Song`, `Rev`) directly into integer `book_id` (1..66).
- No English slugs stored in SQLite.
- UI resolves `book_id` via `BibliaRepository._get_book_names(versao)` or canonical fallback map (e.g. `1` -> `"Gênesis"`).
- Verse text resolved from user's active Bible translation (`ARA`, `NVI`, etc.).
- **Zero raw English abbreviations exposed to the user.**

### Multi-Verse Query & DoS Defense
- **Method**: `get_cross_references_for_verses(book_id: int, chapter: int, verses: list[int], limit_per_verse: int = 20)`
- **Cap**: `verses = sorted(list(verses))[:10]` (hard cap of 10 verses to prevent DoS and UI freeze).
- **SQL**:
  ```sql
  SELECT from_verse, to_book_id, to_chapter, to_verse_start, to_verse_end, votes
  FROM cross_reference
  WHERE from_book_id = ? AND from_chapter = ? AND from_verse IN (?, ?, ...)
  ORDER BY from_verse ASC, votes DESC;
  ```
- Uses strictly parameterized queries (`?`).

### Flet UI Component Lifecycle (BottomSheet)
- **Selection AppBar Trigger**:
  - Visible when `1 <= len(self.selected_verses) <= 10`.
  - Icon: `ft.Icons.ALT_ROUTE`.
  - Tooltip: `"Referências Cruzadas ({count})"`.
- **Adaptive Layout**:
  - When selected count == 1: Direct list of reference cards.
  - When 2 <= count <= 4: `ft.Tabs` (one tab per verse with verse number badge).
  - When count > 4 (up to 10): `ft.ExpansionTile` accordion (one expandable tile per verse with verse number badge).
- **Actions**:
  - "Ler no contexto" -> sets book, chapter, triggers smooth scroll to target verse.
  - "Copiar" -> copies canonical reference + preview text.

---

## 2. Test & Verification Plan
- Unit parser test: Validates USFM conversion and edge-case syntax.
- Multi-verse test: Queries 1 to 10 verses simultaneously, verifies grouping and sorting by votes.
- Benchmark: Sub-10ms query execution across 10 verses with index scan.
- Regression: Full Bible test suite pass (`pytest -k "biblia"`).
