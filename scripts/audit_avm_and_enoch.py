#!/usr/bin/env python3
"""
audit_avm_and_enoch.py
-----------------------
Audita a integridade do banco de dados católico AVM (Bíblia Ave Maria + Livro de Enoque)
em formato .sqlite ou .sqlite.gz para compatibilidade total com Android e Web (sql.js).

Verificações realizadas:
1. Tabela 'book': 73 livros católicos (46 VT, 27 NT) + Livro de Enoque (id 99 ou 74, testament_reference_id 3).
2. Livros Deuterocanônicos: Tobias, Judite, Sabedoria, Eclesiástico/Sirácida, Baruc/Baruque, 1 e 2 Macabeus.
3. Livro de Enoque: exatamente 108 capítulos e versículos presentes.
4. Índice obrigatório de performance: idx_verse_book_chapter em verse(book_id, chapter).
5. Flag opcional --fix-journal: aplica 'PRAGMA journal_mode=DELETE; VACUUM;' para compatibilidade Web/Android.
6. Suporte a --self-test: gera um banco temporário com 73 livros + Enoque 108 capítulos para validação de ponta a ponta.

Uso:
  python3 scripts/audit_avm_and_enoch.py --path assets/AVM.sqlite
  python3 scripts/audit_avm_and_enoch.py --path build_cache/biblias/AVM.sqlite.gz --fix-journal
  python3 scripts/audit_avm_and_enoch.py --self-test
"""

import argparse
import gzip
import os
import re
import shutil
import sqlite3
import sys
import tempfile
from pathlib import Path
from typing import Dict, List, Optional, Tuple

DEUTEROCANONICAL_NAMES = [
    "tobias",
    "judite",
    "sabedoria",
    "eclesiastico",  # ou siracida
    "baruc",         # ou baruque
    "1 macabeus",
    "2 macabeus",
]


def normalize_name(text: str) -> str:
    """Normaliza nomes removendo acentos, pontuação e numerais romanos."""
    s = text.lower().strip()
    dia_map = str.maketrans(
        "àáâãäåèéêëìíîïòóôõöùúûüçñ",
        "aaaaaaeeeeiiiiooooouuuucn",
    )
    s = s.translate(dia_map)
    s = s.replace(".", "")
    s = re.sub(r"^(?:iii|3[ºo]?)\s+", "3 ", s)
    s = re.sub(r"^(?:ii|2[ºo]?)\s+", "2 ", s)
    s = re.sub(r"^(?:i|1[ºo]?)\s+", "1 ", s)
    s = re.sub(r"\bi\b", "1", s)
    s = re.sub(r"\bii\b", "2", s)
    s = re.sub(r"\biii\b", "3", s)
    return re.sub(r"\s+", " ", s).strip()


def run_audit(db_path: Path, fix_journal: bool = False) -> Tuple[bool, List[str]]:
    """Executa auditoria em um arquivo SQLite já descompactado."""
    errors: List[str] = []
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()

    try:
        # 1. Checa schema básico
        tables = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()]
        if "book" not in tables:
            errors.append("Tabela 'book' ausente no banco de dados.")
        if "verse" not in tables:
            errors.append("Tabela 'verse' ausente no banco de dados.")

        if errors:
            return False, errors

        # 2. Checa livros
        books = cur.execute("SELECT id, name, testament_reference_id FROM book ORDER BY id ASC").fetchall()
        total_books = len(books)
        if total_books < 73:
            errors.append(f"Contagem insuficiente de livros: {total_books} (esperado no mínimo 73).")

        books_by_id: Dict[int, Tuple[str, int]] = {r[0]: (r[1], r[2]) for r in books}
        norm_names = {normalize_name(r[1]): r[0] for r in books}

        # 3. Checa Deuterocanônicos
        for deut in DEUTEROCANONICAL_NAMES:
            matched = False
            for n in norm_names:
                if deut in n or (deut == "eclesiastico" and "siracida" in n) or (deut == "baruc" and "baruque" in n):
                    matched = True
                    break
            if not matched:
                errors.append(f"Livro deuterocanônico '{deut}' não encontrado na tabela 'book'.")

        # 4. Checa Enoque
        enoch_row: Optional[Tuple[int, str, int]] = None
        for b_id, (b_name, b_testament) in books_by_id.items():
            if "enoque" in normalize_name(b_name) or b_id in (74, 99) and b_testament == 3:
                enoch_row = (b_id, b_name, b_testament)
                break

        if not enoch_row:
            errors.append("Livro de Enoque não encontrado na tabela 'book'.")
        else:
            enoch_id, enoch_name, enoch_testament = enoch_row
            if enoch_testament != 3:
                errors.append(f"Livro de Enoque possui testament_reference_id={enoch_testament} (esperado 3 para AP).")

            # Checa 108 capítulos de Enoque
            enoch_ch_stats = cur.execute(
                "SELECT COUNT(DISTINCT chapter), MAX(chapter), COUNT(*) FROM verse WHERE book_id = ?",
                (enoch_id,),
            ).fetchone()
            distinct_ch, max_ch, total_enoch_verses = enoch_ch_stats or (0, 0, 0)
            if max_ch != 108 or distinct_ch != 108:
                errors.append(
                    f"Livro de Enoque (book_id={enoch_id}) possui {distinct_ch} capítulos distintos com max={max_ch} (esperado 108)."
                )
            if total_enoch_verses < 108:
                errors.append(f"Livro de Enoque possui apenas {total_enoch_verses} versículos.")

        # 5. Checa índice idx_verse_book_chapter
        indexes = [r[0] for r in cur.execute("SELECT name FROM sqlite_master WHERE type='index'").fetchall()]
        if "idx_verse_book_chapter" not in indexes:
            errors.append("Índice 'idx_verse_book_chapter' não encontrado na tabela 'verse'.")

        # 6. Aplica fix-journal se solicitado
        if fix_journal:
            conn.commit()
            conn.isolation_level = None
            cur.execute("PRAGMA journal_mode=DELETE;").fetchall()
            cur.execute("VACUUM;")

        journal_mode = cur.execute("PRAGMA journal_mode;").fetchone()[0]
        if fix_journal and str(journal_mode).upper() != "DELETE":
            errors.append(f"Falha ao fixar journal_mode para DELETE (atual: {journal_mode}).")

    finally:
        conn.close()

    is_valid = len(errors) == 0
    return is_valid, errors


def audit_file(path_str: str, fix_journal: bool = False) -> bool:
    """Audita um arquivo .sqlite ou .sqlite.gz."""
    path = Path(path_str)
    if not path.exists():
        print(f"[ERRO] Arquivo não encontrado: {path}")
        return False

    is_gz = path.name.endswith(".gz")
    print(f"[AUDIT] Auditando: {path} (compactado: {is_gz}, fix-journal: {fix_journal})")

    if is_gz:
        with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False) as tmp:
            tmp_path = Path(tmp.name)
        try:
            with gzip.open(path, "rb") as gz_in, open(tmp_path, "wb") as f_out:
                shutil.copyfileobj(gz_in, f_out)

            is_valid, errors = run_audit(tmp_path, fix_journal=fix_journal)
            if is_valid and fix_journal:
                print(f"[AUDIT] Recompactando {tmp_path.name} de volta para {path}...")
                with open(tmp_path, "rb") as f_in, gzip.open(path, "wb") as gz_out:
                    shutil.copyfileobj(f_in, gz_out)
        finally:
            if tmp_path.exists():
                tmp_path.unlink()
    else:
        is_valid, errors = run_audit(path, fix_journal=fix_journal)

    if is_valid:
        print("[AUDIT] SUCESSO: Todas as validações passaram com louvor!")
        return True
    else:
        print(f"[AUDIT] FALHA: Foram encontrados {len(errors)} erro(s):")
        for err in errors:
            print(f"  - {err}")
        return False


def build_self_test_db(db_path: Path) -> None:
    """Cria um banco SQLite com 73 livros católicos + Enoque (108 capítulos)."""
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE book (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            testament_reference_id INTEGER NOT NULL
        );
        """
    )
    cur.execute(
        """
        CREATE TABLE verse (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL
        );
        """
    )

    # 46 livros VT (inclui Tobias, Judite, Sabedoria, Eclesiástico, Baruc, 1 e 2 Macabeus)
    vt_books = [
        (1, "Gênesis"), (2, "Êxodo"), (3, "Levítico"), (4, "Números"), (5, "Deuteronômio"),
        (6, "Josué"), (7, "Juízes"), (8, "Rute"), (9, "1 Samuel"), (10, "2 Samuel"),
        (11, "1 Reis"), (12, "2 Reis"), (13, "1 Crônicas"), (14, "2 Crônicas"), (15, "Esdras"),
        (16, "Neemias"), (17, "Tobias"), (18, "Judite"), (19, "Ester"), (20, "1 Macabeus"),
        (21, "2 Macabeus"), (22, "Jó"), (23, "Salmos"), (24, "Provérbios"), (25, "Eclesiastes"),
        (26, "Cântico dos Cânticos"), (27, "Sabedoria"), (28, "Eclesiástico"), (29, "Isaías"),
        (30, "Jeremias"), (31, "Lamentações"), (32, "Baruc"), (33, "Ezequiel"), (34, "Daniel"),
        (35, "Oséias"), (36, "Joel"), (37, "Amós"), (38, "Obadias"), (39, "Jonas"),
        (40, "Miquéias"), (41, "Naum"), (42, "Habacuque"), (43, "Sofonias"), (44, "Ageu"),
        (45, "Zacarias"), (46, "Malaquias"),
    ]
    for b_id, name in vt_books:
        cur.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (?, ?, ?)", (b_id, name, 1))
        cur.execute(
            "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
            (b_id, 1, 1, f"Versículo inicial de {name}"),
        )

    # 27 livros NT
    nt_books = [
        (47, "Mateus"), (48, "Marcos"), (49, "Lucas"), (50, "João"), (51, "Atos"),
        (52, "Romanos"), (53, "1 Coríntios"), (54, "2 Coríntios"), (55, "Gálatas"),
        (56, "Efésios"), (57, "Filipenses"), (58, "Colossenses"), (59, "1 Tessalonicenses"),
        (60, "2 Tessalonicenses"), (61, "1 Timóteo"), (62, "2 Timóteo"), (63, "Tito"),
        (64, "Filemom"), (65, "Hebreus"), (66, "Tiago"), (67, "1 Pedro"), (68, "2 Pedro"),
        (69, "1 João"), (70, "2 João"), (71, "3 João"), (72, "Judas"), (73, "Apocalipse"),
    ]
    for b_id, name in nt_books:
        cur.execute("INSERT INTO book (id, name, testament_reference_id) VALUES (?, ?, ?)", (b_id, name, 2))
        cur.execute(
            "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
            (b_id, 1, 1, f"Versículo inicial de {name}"),
        )

    # Livro de Enoque (id 99, testament_reference_id 3, 108 capítulos)
    cur.execute(
        "INSERT INTO book (id, name, testament_reference_id) VALUES (?, ?, ?)",
        (99, "Livro de Enoque", 3),
    )
    for ch in range(1, 109):
        cur.execute(
            "INSERT INTO verse (book_id, chapter, verse, text) VALUES (?, ?, ?, ?)",
            (99, ch, 1, f"Palavras de bênção de Enoque, capítulo {ch}."),
        )

    cur.execute("CREATE INDEX idx_verse_book_chapter ON verse(book_id, chapter)")
    conn.commit()
    conn.close()


def self_test() -> bool:
    """Executa o auto-teste completo criando banco temporário."""
    print("[SELF-TEST] Iniciando auto-teste com banco temporário...")
    with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False) as tmp:
        tmp_path = Path(tmp.name)

    gz_path = tmp_path.with_suffix(".sqlite.gz")
    try:
        build_self_test_db(tmp_path)
        is_valid, errors = run_audit(tmp_path, fix_journal=True)
        if not is_valid:
            print(f"[SELF-TEST] Falha na auditoria do banco temporário: {errors}")
            return False

        # Testa versão compactada .sqlite.gz com --fix-journal
        with open(tmp_path, "rb") as f_in, gzip.open(gz_path, "wb") as gz_out:
            shutil.copyfileobj(f_in, gz_out)

        is_gz_valid = audit_file(str(gz_path), fix_journal=True)
        if not is_gz_valid:
            print("[SELF-TEST] Falha na auditoria do arquivo .sqlite.gz.")
            return False

        print("[SELF-TEST] Todos os testes passaram com 100% de sucesso!")
        return True
    finally:
        if tmp_path.exists():
            tmp_path.unlink()
        if gz_path.exists():
            gz_path.unlink()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Auditoria do banco AVM (Ave Maria Católica + Livro de Enoque)."
    )
    parser.add_argument(
        "--path",
        type=str,
        help="Caminho do arquivo .sqlite ou .sqlite.gz para auditar.",
    )
    parser.add_argument(
        "--fix-journal",
        action="store_true",
        help="Aplica 'PRAGMA journal_mode=DELETE; VACUUM;' no banco.",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Executa o auto-teste de criação e validação com banco temporário.",
    )

    args = parser.parse_args()

    if args.self_test:
        success = self_test()
        return 0 if success else 1

    if not args.path:
        parser.print_help()
        return 1

    success = audit_file(args.path, fix_journal=args.fix_journal)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
