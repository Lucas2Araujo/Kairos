"""
Componente Estúdio de Mapas Mentais (Rede Semântica) para a Escola Sabatina no app Kairós.
Oferece:
- Visualização e edição do nó central (conceito-chave da lição)
- Adição e remoção dinâmica de ramos / nós satélites
- Renderização visual das conexões radiais usando Flet Canvas
- Exportação e download em imagem PNG de alta resolução para compartilhamento
- Persistência automática no banco de dados SQLite local
"""

from __future__ import annotations

import asyncio
import math
from pathlib import Path
import re
import sys
from typing import Any, Callable

# Garante que a raiz do projeto esteja em sys.path caso o arquivo seja executado diretamente
_project_root = Path(__file__).resolve().parent.parent.parent.parent
if str(_project_root) not in sys.path:
    sys.path.insert(0, str(_project_root))

import flet as ft
import flet.canvas as cv

from src.utils.mind_map_exporter import generate_mind_map_png


class MindMapStudio(ft.Container):
    """
    Componente interativo e responsivo para visualização, modelagem e exportação
    de mapas mentais / redes semânticas.
    """

    def __init__(
        self,
        root_word: str,
        initial_nodes: list[dict[str, Any]] | None = None,
        on_save: Callable[[str, list[dict[str, Any]]], Any] | None = None,
        on_close: Callable[[], Any] | None = None,
        on_show_snackbar: Callable[[str], Any] | None = None,
    ):
        super().__init__()
        self.root_word: str = root_word.strip() or "Palavra-Chave"
        self.nodes: list[dict[str, Any]] = list(initial_nodes or [])
        self.on_save = on_save
        self.on_close = on_close
        self.on_show_snackbar = on_show_snackbar

        self.expand = True
        self.padding = ft.Padding.all(16)
        self.border_radius = 16

        # Estado da UI
        self.input_field = ft.TextField(
            hint_text="Nova ideia ou reflexão...",
            dense=True,
            expand=True,
            border_radius=10,
            on_submit=self._add_node_from_input,
        )

        self.canvas_control = cv.Canvas(
            expand=True,
            shapes=[],
        )

        self.chips_row = ft.Row(
            wrap=True,
            spacing=8,
            run_spacing=8,
            controls=[],
        )

        self._build_ui()
        self._refresh_visualization()

    def _build_ui(self) -> None:
        """Monta a estrutura visual do modal do estúdio."""
        header = ft.Row(
            controls=[
                ft.Container(
                    content=ft.Icon(ft.Icons.HUB_ROUNDED, color=ft.Colors.PRIMARY, size=24),
                    bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
                    padding=ft.Padding.all(8),
                    border_radius=10,
                ),
                ft.Column(
                    controls=[
                        ft.Text("Rede Semântica & Mapa Mental", weight=ft.FontWeight.BOLD, size=18),
                        ft.Text(f"Conceito central: {self.root_word}", size=13, color=ft.Colors.ON_SURFACE_VARIANT),
                    ],
                    spacing=2,
                    expand=True,
                ),
                ft.IconButton(
                    icon=ft.Icons.DOWNLOAD_ROUNDED,
                    tooltip="Baixar Imagem (PNG)",
                    on_click=self._export_png,
                ),
                ft.IconButton(
                    icon=ft.Icons.SAVE_ROUNDED,
                    tooltip="Salvar Mapa Mental",
                    on_click=self._save_map,
                ),
                ft.IconButton(
                    icon=ft.Icons.CLOSE_ROUNDED,
                    tooltip="Fechar",
                    on_click=lambda e: self.on_close() if self.on_close else None,
                ),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
        )

        input_bar = ft.Container(
            content=ft.Row(
                controls=[
                    self.input_field,
                    ft.FilledButton(
                        "Adicionar",
                        icon=ft.Icons.ADD_ROUNDED,
                        on_click=self._add_node_from_input,
                    ),
                ],
                spacing=8,
            ),
            padding=ft.Padding.symmetric(vertical=8),
        )

        self.content = ft.Column(
            controls=[
                header,
                ft.Divider(height=12),
                input_bar,
                # Área de visualização gráfica
                ft.Container(
                    content=self.canvas_control,
                    height=400,
                    border_radius=14,
                    border=ft.Border.all(1, ft.Colors.OUTLINE_VARIANT),
                    bgcolor=ft.Colors.with_opacity(0.04, ft.Colors.ON_SURFACE),
                    clip_behavior=ft.ClipBehavior.HARD_EDGE,
                ),
                ft.Container(height=8),
                # Lista de Ideias em chips interativos para rápida exclusão
                ft.Text("Ideias Conectadas (clique no 'x' para remover):", size=13, weight=ft.FontWeight.BOLD),
                ft.Container(
                    content=self.chips_row,
                    padding=ft.Padding.symmetric(vertical=4),
                ),
            ],
            spacing=8,
            scroll=ft.ScrollMode.AUTO,
            expand=True,
        )

    def _refresh_visualization(self) -> None:
        """Recalcula e desenha as conexões e os nós no Canvas e na lista de chips."""
        shapes: list[cv.Shape] = []

        # Dimensões de referência do Canvas com proporção harmônica
        w, h = 660, 400
        cx, cy = w / 2, h / 2

        n = len(self.nodes)
        radius_x = 230 if n > 4 else 210
        radius_y = 140 if n > 4 else 125

        # 1. Posições dos nós satélites
        positions = []
        for i, node in enumerate(self.nodes):
            angle = (2 * math.pi * i) / max(1, n) - (math.pi / 2)
            nx = cx + radius_x * math.cos(angle)
            ny = cy + radius_y * math.sin(angle)
            positions.append((nx, ny, str(node.get("text", ""))))

        # 2. Linhas radiais com cor de destaque suave
        line_paint = ft.Paint(
            color=ft.Colors.with_opacity(0.45, ft.Colors.PRIMARY),
            stroke_width=2.5,
            style=ft.PaintingStyle.STROKE,
        )
        for nx, ny, _ in positions:
            shapes.append(cv.Line(cx, cy, nx, ny, paint=line_paint))

        # 3. Nós satélites
        for nx, ny, text in positions:
            node_paint = ft.Paint(
                color=ft.Colors.SURFACE_CONTAINER_HIGH,
                style=ft.PaintingStyle.FILL,
            )
            border_paint = ft.Paint(
                color=ft.Colors.PRIMARY,
                stroke_width=1.5,
                style=ft.PaintingStyle.STROKE,
            )
            # Retângulo com cantos arredondados para os nós
            shapes.append(cv.Rect(nx - 55, ny - 18, 110, 36, border_radius=8, paint=node_paint))
            shapes.append(cv.Rect(nx - 55, ny - 18, 110, 36, border_radius=8, paint=border_paint))

            shapes.append(
                cv.Text(
                    x=nx,
                    y=ny,
                    value=text[:15] + ("..." if len(text) > 15 else ""),
                    alignment=ft.Alignment.CENTER,
                    style=ft.TextStyle(size=11, weight=ft.FontWeight.W_600, color=ft.Colors.ON_SURFACE),
                )
            )

        # 4. Nó central (destacado e bem dimensionado)
        center_bg = ft.Paint(
            color=ft.Colors.PRIMARY,
            style=ft.PaintingStyle.FILL,
        )
        center_border = ft.Paint(
            color=ft.Colors.ON_PRIMARY,
            stroke_width=2,
            style=ft.PaintingStyle.STROKE,
        )
        shapes.append(cv.Rect(cx - 65, ny_c := (cy - 22), 130, 44, border_radius=12, paint=center_bg))
        shapes.append(cv.Rect(cx - 65, ny_c, 130, 44, border_radius=12, paint=center_border))
        shapes.append(
            cv.Text(
                x=cx,
                y=cy,
                value=self.root_word[:16],
                alignment=ft.Alignment.CENTER,
                style=ft.TextStyle(size=14, weight=ft.FontWeight.BOLD, color=ft.Colors.ON_PRIMARY),
            )
        )

        self.canvas_control.shapes = shapes

        # Atualiza a lista de chips interativos
        self.chips_row.controls = [
            ft.Chip(
                label=ft.Text(node.get("text", "")),
                on_delete=lambda e, idx=i: self._remove_node(idx),
                bgcolor=ft.Colors.with_opacity(0.12, ft.Colors.PRIMARY),
            )
            for i, node in enumerate(self.nodes)
        ]

        if not self.nodes:
            self.chips_row.controls = [
                ft.Text("Nenhuma ideia adicionada ainda. Digite acima e clique em 'Adicionar'!", size=12, italic=True, color=ft.Colors.ON_SURFACE_VARIANT)
            ]

        try:
            self.update()
        except Exception:
            pass

    def _add_node_from_input(self, e: Any = None) -> None:
        val = (self.input_field.value or "").strip()
        if not val:
            return
        self.nodes.append({"id": f"node_{len(self.nodes)+1}", "text": val})
        self.input_field.value = ""
        self._refresh_visualization()
        self._trigger_autosave()

    def _remove_node(self, index: int) -> None:
        if 0 <= index < len(self.nodes):
            self.nodes.pop(index)
            self._refresh_visualization()
            self._trigger_autosave()

    def _trigger_autosave(self) -> None:
        if self.on_save:
            res = self.on_save(self.root_word, self.nodes)
            if asyncio.iscoroutine(res):
                asyncio.create_task(res)

    def _save_map(self, e: Any = None) -> None:
        self._trigger_autosave()
        if self.on_show_snackbar:
            self.on_show_snackbar("Mapa mental salvo com sucesso!")

    def _export_png(self, e: Any = None) -> None:
        """Gera e salva o PNG do mapa mental respeitando Android, Desktop e Web."""
        try:
            png_bytes = generate_mind_map_png(
                root_word=self.root_word,
                nodes=self.nodes,
                width=1200,
                height=800,
            )

            import os
            from pathlib import Path
            import os
            import tempfile

            def _is_dir_writable(path: Path) -> bool:
                try:
                    if not path.exists():
                        path.mkdir(parents=True, exist_ok=True)
                    # Testa escrita real com arquivo temporário
                    test_file = path / f".write_test_{os.getpid()}"
                    test_file.touch()
                    test_file.unlink()
                    return True
                except Exception:
                    return False

            export_dir: Path | None = None

            # 1. Caminhos de download no Android
            android_candidates = [
                Path("/storage/emulated/0/Download"),
                Path("/sdcard/Download"),
            ]
            for cand in android_candidates:
                if cand.exists() and _is_dir_writable(cand):
                    export_dir = cand
                    break

            # 2. Diretórios de armazenamento privado/dados no Android / Flet
            if export_dir is None:
                for env in ["FLET_APP_STORAGE_DATA", "FILES_DIR", "ANDROID_PRIVATE"]:
                    val = os.environ.get(env)
                    if val:
                        p = Path(val) / "downloads"
                        if _is_dir_writable(p):
                            export_dir = p
                            break

            # 3. Diretório 'downloads' do próprio projeto / workspace (garantido no Desktop / VSCodium)
            if export_dir is None:
                project_dl = _project_root / "downloads"
                if _is_dir_writable(project_dl):
                    export_dir = project_dl

            # 4. Downloads do usuário ou Documentos do sistema operacional (Desktop)
            if export_dir is None:
                desktop_candidates = [
                    Path.home() / "Downloads",
                    Path.home() / "Download",
                    Path.home() / "Documentos",
                    Path.home() / "Documents",
                ]
                for cand in desktop_candidates:
                    if _is_dir_writable(cand):
                        export_dir = cand
                        break

            # 5. Fallback final para diretório temporário do SO
            if export_dir is None:
                tmp_dir = Path(tempfile.gettempdir())
                export_dir = tmp_dir if _is_dir_writable(tmp_dir) else Path.cwd()

            clean_name = re.sub(r'[^a-zA-Z0-9_-]', '_', self.root_word.lower().strip()) or "rede_semantica"
            target_file = export_dir / f"mapa_mental_{clean_name}.png"

            # Escreve o arquivo no disco
            target_file.write_bytes(png_bytes)

            abs_path = target_file.resolve()
            msg = f"Mapa mental salvo em: {abs_path}"
            if self.on_show_snackbar:
                self.on_show_snackbar(msg)

            # Se estiver na Web, dispara download via URL data:
            if self.page and getattr(self.page, "web", False):
                import base64
                b64_data = base64.b64encode(png_bytes).decode("ascii")
                data_uri = f"data:image/png;base64,{b64_data}"
                res = self.page.launch_url(data_uri)
                if asyncio.iscoroutine(res):
                    asyncio.create_task(res)

        except Exception as ex:
            if self.on_show_snackbar:
                self.on_show_snackbar(f"Erro ao exportar imagem: {ex}")


if __name__ == "__main__":
    def main(page: ft.Page):
        page.title = "MindMapStudio - Teste Isolado"
        page.theme_mode = ft.ThemeMode.DARK
        studio = MindMapStudio(
            root_word="FIM",
            initial_nodes=[{"id": "1", "text": "Perseverança"}, {"id": "2", "text": "Vitória"}],
            on_show_snackbar=lambda msg: page.open(ft.SnackBar(content=ft.Text(msg))),
        )
        page.add(studio)

    ft.app(target=main)
