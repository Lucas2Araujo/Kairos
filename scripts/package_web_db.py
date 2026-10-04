import sqlite3
import shutil
from pathlib import Path

def main():
    root = Path(__file__).resolve().parent.parent
    src_db = root / "src" / "database" / "data" / "hinario.db"
    if not src_db.exists():
        src_db = root / "assets" / "hinario.db"
    if not src_db.exists():
        raise FileNotFoundError(f"Source database not found at {src_db}")

    dest_db = root / "kairos_web" / "assets" / "hinario.db"
    dest_db.parent.mkdir(parents=True, exist_ok=True)

    print(f"1. Copying {src_db} to {dest_db}...")
    shutil.copy2(src_db, dest_db)

    print("2. Running PRAGMA wal_checkpoint(TRUNCATE), PRAGMA journal_mode=DELETE, VACUUM...")
    conn = sqlite3.connect(dest_db)
    cur = conn.cursor()
    cur.execute("PRAGMA wal_checkpoint(TRUNCATE);")

    # A web só usa hino_fts: remove índices de busca não usados (e seus triggers)
    # da cópia web para reduzir o download. O banco do desktop não é alterado.
    unused_fts = ("biblia_fts", "meditacao_fts", "licao_fts")
    triggers = cur.execute("SELECT name, sql FROM sqlite_master WHERE type='trigger';").fetchall()
    for name, sql in triggers:
        if any(t in (sql or "") for t in unused_fts):
            cur.execute(f'DROP TRIGGER IF EXISTS "{name}";')
    for table in unused_fts:
        cur.execute(f'DROP TABLE IF EXISTS "{table}";')

    mode = cur.execute("PRAGMA journal_mode=DELETE;").fetchone()[0]
    cur.execute("VACUUM;")
    conn.commit()

    print("3. Asserting DELETE journal mode...")
    cur.execute("PRAGMA journal_mode;")
    final_mode = cur.fetchone()[0]
    conn.close()

    assert final_mode.lower() == "delete", f"Expected DELETE journal mode, got {final_mode}"
    print(f"SUCCESS: Resulting database at {dest_db} is verified in DELETE journal mode ({final_mode}).")

if __name__ == "__main__":
    main()
