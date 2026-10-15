import json
import shutil
import sqlite3
from pathlib import Path


def update_all_pericopes():
    root = Path(__file__).resolve().parent.parent
    db_path = root / "assets" / "pericopes.sqlite"

    json_files = [
        root / "scripts" / "data" / "pericopes_penta_hist.json",
        root / "scripts" / "data" / "pericopes_poet_prof.json",
        root / "scripts" / "data" / "pericopes_nt.json",
    ]

    all_pericopes = {}
    for jf in json_files:
        with open(jf, "r", encoding="utf-8") as f:
            data = json.load(f)
            all_pericopes.update(data)

    print(f"Total de perícopes carregadas dos JSONs: {len(all_pericopes)}")

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    updated = 0
    inserted = 0

    for key, title in all_pericopes.items():
        bid_str, ch_str = key.split(":")
        book_id = int(bid_str)
        chapter = int(ch_str)

        cur.execute(
            """
            UPDATE pericope
            SET title = ?
            WHERE book_id = ? AND chapter = ? AND verse = 1
            """,
            (title, book_id, chapter),
        )
        if cur.rowcount > 0:
            updated += 1
        else:
            cur.execute(
                """
                INSERT INTO pericope (book_id, chapter, verse, title)
                VALUES (?, ?, 1, ?)
                """,
                (book_id, chapter, title),
            )
            inserted += 1

    conn.commit()
    conn.close()

    print(f"Concluído em {db_path}: {updated} atualizados, {inserted} inseridos.")

    # Replicar para as pastas de build do web se existirem
    web_candidates = [
        root / "kairos_web" / "build" / "web" / "assets" / "assets" / "pericopes.sqlite",
        root / "kairos_web" / "build" / "unit_test_assets" / "assets" / "pericopes.sqlite",
        root / "kairos_web" / "build" / "flutter_assets" / "assets" / "pericopes.sqlite",
    ]
    for cand in web_candidates:
        if cand.parent.exists():
            shutil.copy2(db_path, cand)
            print(f"Copiado para {cand}")


if __name__ == "__main__":
    update_all_pericopes()
