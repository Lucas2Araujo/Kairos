
# Task: Implement Bible Pericope / Section Headings (Títulos de Seção / Perícopes)

## Checklist & Progress
- [x] **Stage 1: Audit & Planning**
  - [x] Audit database schemas and storage location
  - [x] Evaluate open-source Portuguese pericope dataset strategy
  - [x] Design non-intrusive UI injection architecture for `biblia_view.py`
  - [x] Complete `task_pericopes.md` spec and test strategy
- [x] **Stage 2: Implementation & Tests**
  - [x] 1. Canonical Pericope dataset and ingestion script (`scripts/ingest_pericopes.py` / `assets/pericopes.sqlite`)
  - [x] 2. Model DTO (`Pericope`) & Repository (`PericopeRepository`)
  - [x] 3. Non-intrusive lookup and injection in `BibliaView._render_verses()`
  - [x] 4. Unit and UI tests (`tests/test_pericopes.py`) (48/48 suite tests passing)

---

## 1. Storage Strategy & Architecture

### Table Schema & Location
- **Target**: Dedicated SQLite database `assets/pericopes.sqlite` (or `pericopes` table with fallback in `hinario.db`).
  - *Recommendation*: Dedicated `assets/pericopes.sqlite` (~150-250KB) to ensure zero lock contention with `hinario.db` or Bible translation databases (`ARA.sqlite`).
- **Table Definition**:
  ```sql
  CREATE TABLE IF NOT EXISTS pericope (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      book_id INTEGER NOT NULL,
      chapter INTEGER NOT NULL,
      verse INTEGER NOT NULL,
      title TEXT NOT NULL
  );
  ```
- **Indices**:
  ```sql
  CREATE INDEX IF NOT EXISTS idx_pericope_chapter 
  ON pericope (book_id, chapter, verse ASC);
  ```

### Portuguese Dataset Source Strategy
- Standard open Portuguese section titles derived from canonical public-domain Brazilian Bible pericope divisions (BLIVRE USFM section markers `\s` / Almeida standard divisions).
- ~2,500 section headings covering all 66 books (from "A Criação dos Céus e da Terra" in Gn 1:1 to "O Triunfo Final" in Ap 22).
- Keyed strictly by `(book_id, chapter, verse)` where `book_id` is an integer 1..66.

---

## 2. Reader Integration in `biblia_view.py`

### Non-Intrusive In-Memory Lookup
1. During `_carregar_capitulo(book_id, chapter)`:
   - Asynchronously query `PericopeRepository.get_pericopes_for_chapter(book_id, chapter)` -> returns `{verse: title}` dict.
   - Store in `self._current_pericopes: dict[int, str]`.
2. Inside `_render_verses()`:
   - Loop over verses: `for v in self.current_passagem.versiculos:`
   - Before appending the `ft.GestureDetector(verse_row)`:
     - Check `if v.numero in self._current_pericopes:`
     - Inject a distinct, elegant M3 section heading control:
       ```python
       ft.Container(
           content=ft.Text(
               self._current_pericopes[v.numero],
               size=15,
               weight=ft.FontWeight.BOLD,
               color=accent_color,
           ),
           padding=ft.Padding.only(top=16, bottom=6, left=8, right=8),
       )
       ```
3. **Safety & Zero Regression Guarantees**:
   - Verse indexing remains unaffected: each verse retains key `f"v_{v.numero}"` and `_verse_containers[v.numero]` mapping.
   - Gesture handling (tap/long-press/multi-selection) remains 100% attached to `ft.GestureDetector` on the verse row.
   - Selection highlighting and single-verse surgical updates (`_update_single_verse_ui`) operate without touching section header widgets.
   - Smooth auto-scrolling (`_calculate_verse_offset`) stays accurate.

---

## 3. Test Strategy Outline

1. **Unit Tests (`tests/test_pericopes.py`)**:
   - Verify dataset ingestion and schema indexing.
   - Verify `get_pericopes_for_chapter(book_id, chapter)` returns ordered titles with parameterized queries.
   - Verify boundary conditions (chapters with zero pericopes, single-chapter books).
2. **UI Integration Tests**:
   - Verify section headers render above appropriate verses in `BibliaView`.
   - Verify verse selection mode does not select or mutate section headers.
   - Verify multi-verse selection and bookmarks behave identically with headers present.
