#!/usr/bin/env python3
"""
Remove extractors não utilizados do yt-dlp mantendo suporte a YouTube e GenericIE.
Reduz drasticamente o tamanho do APK Android e os arquivos compactados no asset zip.
"""

from __future__ import annotations

import glob
import os
import shutil
import sys
from pathlib import Path

KEEP_EXTRACTORS = {
    "__init__.py",
    "_extractors.py",
    "extractors.py",
    "lazy_extractors.py",
    "common.py",
    "commonmistakes.py",
    "commonprotocols.py",
    "generic.py",
    "youtube.py",
    "afreecatv.py",
    "openload.py",
    "adobepass.py",
}

STUB_EXTRACTORS_PY = """# flake8: noqa: F401
# Módulo gerado automaticamente para strip de extractors no empacotamento Android
from .commonprotocols import *
from .generic import GenericIE
from .youtube import *
"""


def strip_yt_dlp_in_dir(extractor_dir: Path) -> int:
    if not extractor_dir.exists() or not extractor_dir.is_dir():
        return 0

    removed = 0
    for file_path in extractor_dir.glob("*.py"):
        if file_path.name not in KEEP_EXTRACTORS:
            try:
                file_path.unlink()
                removed += 1
            except OSError:
                pass

    # Atualiza _extractors.py com imports limpos
    extractors_stub_path = extractor_dir / "_extractors.py"
    try:
        extractors_stub_path.write_text(STUB_EXTRACTORS_PY, encoding="utf-8")
    except OSError as err:
        print(f"⚠️ Erro ao atualizar _extractors.py em {extractor_dir}: {err}")

    # Remove __pycache__ desatualizado
    pycache = extractor_dir / "__pycache__"
    if pycache.exists() and pycache.is_dir():
        shutil.rmtree(pycache, ignore_errors=True)

    return removed


def main() -> None:
    targets: list[Path] = []
    if len(sys.argv) > 1:
        for arg in sys.argv[1:]:
            targets.append(Path(arg))
    else:
        # Busca automática em diretórios comuns de build
        base_paths = [
            Path("build/site-packages"),
            Path("build/python-app"),
        ]
        for base in base_paths:
            if base.exists():
                for found in base.glob("**/yt_dlp/extractor"):
                    targets.append(found)

    if not targets:
        print("ℹ️ Nenhum diretório yt_dlp/extractor encontrado para strip.")
        return

    total_removed = 0
    for t in targets:
        extractor_path = t if t.name == "extractor" else t / "yt_dlp" / "extractor"
        removed = strip_yt_dlp_in_dir(extractor_path)
        total_removed += removed
        print(f"✂️ {removed} extratores removidos de {extractor_path}")

    print(f"✅ Strip concluído: total de {total_removed} arquivos removidos do yt-dlp.")


if __name__ == "__main__":
    main()

