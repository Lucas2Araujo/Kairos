from __future__ import annotations

import asyncio
from datetime import datetime
import io
import os
from pathlib import Path
from typing import Any
import urllib.request
import flet as ft

from PIL import Image, ImageDraw, ImageFont

from src.services.devotional_service import DevotionalService
from src.services.theme_service import ThemeService
from src.theme.theme_engine import ThemeEngine
from src.utils.storage_manager import storage_get, storage_set


class MeditacaoDestaqueView:
    """Tela intermediária imersiva do texto bíblico diário com fundo dinâmico e estilo editorial AndBible."""

    def __init__(
        self,
        devotional_service: DevotionalService | None = None,
        theme_service: ThemeService | None = None,
        theme_engine: ThemeEngine | None = None,
    ):
        self.devotional_service = devotional_service
        self.theme_service = theme_service
        self.theme_engine = (
            theme_engine
            or getattr(theme_service, "theme_engine", None)
            or ThemeEngine()
        )
        self.verse_text_ref: ft.Text | None = None
        self.ref_text_ref: ft.Text | None = None
        self.category_badge: ft.Text | None = None
        self.text_block_column: ft.Column | None = None
        self.text_container: ft.Container | None = None
        self.btn_fav_icon: ft.Icon | None = None
        self.btn_fav_text: ft.Text | None = None

        self._current_text: str = ""
        self._current_ref: str = ""
        self._current_cat: str = "Jovem"
        self._current_img_url: str = ""
        self._is_favorited: bool = False

    def _get_daily_nature_image(self) -> str:
        """Retorna a foto curada de paisagem natural via WallpaperService sincronizado."""
        from src.services.wallpaper_service import WallpaperService
        return WallpaperService.get_instance().get_daily_wallpaper()

    def _resolve_alignment(self, pref: str) -> tuple[ft.TextAlign, ft.CrossAxisAlignment, ft.Alignment]:
        """Calcula alinhamento baseado na preferência ou dia/imagem."""
        if pref == "aleatorio":
            day = datetime.now().day
            modes = ["left", "center", "right"]
            pref = modes[day % len(modes)]

        if pref == "right":
            return ft.TextAlign.RIGHT, ft.CrossAxisAlignment.END, ft.Alignment.CENTER_RIGHT
        elif pref == "center":
            return ft.TextAlign.CENTER, ft.CrossAxisAlignment.CENTER, ft.Alignment.CENTER
        else:
            return ft.TextAlign.LEFT, ft.CrossAxisAlignment.START, ft.Alignment.CENTER_LEFT

    async def _load_devotional_data(self, page: ft.Page) -> None:
        today_iso = datetime.now().date().isoformat()
        cached_ref, cached_text, cached_cat, align_pref = await asyncio.gather(
            storage_get(page, "cached_verse_ref", default=""),
            storage_get(page, "cached_verse_preview", default=""),
            storage_get(page, "cached_verse_cat", default="Jovem"),
            storage_get(page, "meditacao_text_alignment", default="aleatorio"),
        )

        ref = cached_ref
        text = cached_text
        cat = cached_cat or "Jovem"

        if (not text or not ref) and self.devotional_service:
            try:
                dev = await self.devotional_service.get_devotional(today_iso, category=cat.lower())
                if dev and dev.verse_text:
                    text = dev.verse_text.strip()
                    ref = dev.verse_reference or dev.title
            except Exception:
                pass

        if not text:
            text = "Aquietai-vos e sabei que eu sou Deus; sou exaltado entre as nações, sou exaltado na terra."
            ref = "Salmos 46:10"

        self._current_text = text
        self._current_ref = ref
        self._current_cat = cat

        # Alinhamento
        txt_align, cross_align, cont_align = self._resolve_alignment(align_pref or "aleatorio")

        if self.verse_text_ref:
            self.verse_text_ref.value = text
            self.verse_text_ref.text_align = txt_align
        if self.ref_text_ref:
            self.ref_text_ref.value = ref
            self.ref_text_ref.text_align = txt_align
        if self.category_badge:
            self.category_badge.value = "VERSÍCULO DO DIA"
            self.category_badge.text_align = txt_align
        if self.text_block_column:
            self.text_block_column.horizontal_alignment = cross_align
        if self.text_container:
            self.text_container.alignment = cont_align

        # Carregar estado de favorito
        favs = await storage_get(page, "meditacao_favoritos", default=[])
        if isinstance(favs, list):
            self._is_favorited = any(f.get("ref") == ref for f in favs if isinstance(f, dict))
            self._update_fav_ui()

        try:
            page.update()
        except Exception:
            pass

    def _update_fav_ui(self) -> None:
        if self.btn_fav_icon:
            self.btn_fav_icon.name = ft.Icons.FAVORITE if self._is_favorited else ft.Icons.FAVORITE_BORDER
            self.btn_fav_icon.color = ft.Colors.RED_400 if self._is_favorited else ft.Colors.WHITE
        if self.btn_fav_text:
            self.btn_fav_text.value = "Favorito" if self._is_favorited else "Favoritar"

    async def _toggle_favorito(self, page: ft.Page) -> None:
        self._is_favorited = not self._is_favorited
        self._update_fav_ui()
        page.update()

        favs = await storage_get(page, "meditacao_favoritos", default=[])
        if not isinstance(favs, list):
            favs = []

        if self._is_favorited:
            favs.append({
                "ref": self._current_ref,
                "text": self._current_text,
                "date": datetime.now().date().isoformat(),
                "cat": self._current_cat,
            })
            self._show_snackbar(page, "Versículo salvo nos favoritos ❤️")
        else:
            favs = [f for f in favs if isinstance(f, dict) and f.get("ref") != self._current_ref]
            self._show_snackbar(page, "Removido dos favoritos")

        await storage_set(page, "meditacao_favoritos", favs)

    def _show_snackbar(self, page: ft.Page, message: str) -> None:
        try:
            sb = ft.SnackBar(
                content=ft.Text(message, color=ft.Colors.WHITE),
                bgcolor=ft.Colors.GREY_900,
                duration=3000,
            )
            page.overlay.append(sb)
            sb.open = True
            page.update()
        except Exception:
            pass

    async def _copy_to_clipboard(self, page: ft.Page) -> None:
        share_content = f'"{self._current_text}"\n— {self._current_ref}\n\nKairós Hinário & Meditação'
        try:
            if getattr(page, "clipboard", None):
                res = page.clipboard.set(share_content)
                if asyncio.iscoroutine(res):
                    await res
            elif hasattr(page, "set_clipboard_async"):
                await page.set_clipboard_async(share_content)
            elif hasattr(page, "set_clipboard"):
                page.set_clipboard(share_content)
        except Exception:
            pass
        self._show_snackbar(page, "Versículo copiado com sucesso! 📋")

    def _generate_and_save_image(self, page: ft.Page) -> None:
        """Gera a imagem com o versículo sobreposto e salva em Downloads."""
        try:
            # 1. Baixar imagem de fundo ou criar gradiente de fallback
            img = None
            try:
                req = urllib.request.Request(
                    self._current_img_url,
                    headers={"User-Agent": "Mozilla/5.0 (Hinario-Kairos/1.0)"},
                )
                with urllib.request.urlopen(req, timeout=8) as resp:
                    img_data = resp.read()
                    img = Image.open(io.BytesIO(img_data)).convert("RGBA")
            except Exception:
                pass

            if img is None:
                img = Image.new("RGBA", (1080, 1920), (35, 45, 55, 255))
            else:
                img = img.resize((1080, 1920), Image.Resampling.LANCZOS)

            # 2. Aplicar escurecimento (scrim overlay para contraste)
            overlay = Image.new("RGBA", img.size, (0, 0, 0, 100))
            img = Image.alpha_composite(img, overlay)

            draw = ImageDraw.Draw(img)

            # 3. Fontes
            font_path = Path("/home/loko/Documentos/ufMA/Hinário_App/assets/fonts/HymnSerif-Regular.ttf")
            bold_font_path = Path("/home/loko/Documentos/ufMA/Hinário_App/assets/fonts/HymnSerif-Bold.ttf")

            verse_font = ImageFont.truetype(str(font_path), 46) if font_path.exists() else ImageFont.load_default()
            header_font = ImageFont.truetype(str(bold_font_path), 26) if bold_font_path.exists() else ImageFont.load_default()
            ref_font = ImageFont.truetype(str(bold_font_path), 36) if bold_font_path.exists() else ImageFont.load_default()

            # Quebrar texto em linhas
            words = self._current_text.split()
            lines = []
            curr_line = []
            for w in words:
                curr_line.append(w)
                bbox = draw.textbbox((0, 0), " ".join(curr_line), font=verse_font)
                if bbox[2] - bbox[0] > 900:
                    curr_line.pop()
                    if curr_line:
                        lines.append(" ".join(curr_line))
                    curr_line = [w]
            if curr_line:
                lines.append(" ".join(curr_line))

            # Renderizar textos com sombra
            y = 750
            # Header
            draw.text((92, y - 2), "VERSÍCULO DO DIA", font=header_font, fill=(0, 0, 0, 180))
            draw.text((90, y), "VERSÍCULO DO DIA", font=header_font, fill=(230, 230, 230, 255))
            y += 60

            # Linhas do versículo
            for line in lines:
                draw.text((92, y + 2), line, font=verse_font, fill=(0, 0, 0, 200))
                draw.text((90, y), line, font=verse_font, fill=(255, 255, 255, 255))
                y += 64

            # Referência
            y += 24
            draw.text((92, y + 2), self._current_ref, font=ref_font, fill=(0, 0, 0, 200))
            draw.text((90, y), self._current_ref, font=ref_font, fill=(255, 255, 255, 255))

            # Rodapé sutil com a marca
            draw.text((90, 1820), "Kairós • Hinário & Meditação", font=header_font, fill=(200, 200, 200, 200))

            # 4. Salvar na pasta Downloads
            downloads_dir = Path.home() / "Downloads"
            if not downloads_dir.exists():
                downloads_dir = Path.home()

            filename = f"Versiculo_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
            dest_path = downloads_dir / filename
            img.convert("RGB").save(str(dest_path), format="PNG", quality=95)

            self._show_snackbar(page, f"Imagem salva em Downloads: {filename} 🖼️")
        except Exception as e:
            self._show_snackbar(page, f"Erro ao gerar imagem: {e}")

    def _open_share_dialog(self, page: ft.Page) -> None:
        """Abre modal com opções de compartilhamento (copiar texto ou baixar imagem)."""
        bs: ft.BottomSheet | None = None

        def _handle_copy(e: ft.ControlEvent) -> None:
            if bs:
                bs.open = False
                page.update()
            asyncio.create_task(self._copy_to_clipboard(page))

        def _handle_download(e: ft.ControlEvent) -> None:
            if bs:
                bs.open = False
                page.update()
            self._generate_and_save_image(page)

        bs = ft.BottomSheet(
            content=ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Container(
                            content=ft.Container(
                                width=40,
                                height=4,
                                bgcolor=ft.Colors.GREY_600,
                                border_radius=2,
                            ),
                            alignment=ft.Alignment.CENTER,
                            padding=ft.Padding.only(bottom=8),
                        ),
                        ft.Text(
                            "Compartilhar Versículo",
                            size=16,
                            weight=ft.FontWeight.BOLD,
                            color=ft.Colors.WHITE,
                        ),
                        ft.Text(
                            self._current_ref,
                            size=13,
                            color=ft.Colors.WHITE_70,
                        ),
                        ft.Divider(color=ft.Colors.WHITE_24, height=16),
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.CONTENT_COPY, color=ft.Colors.WHITE),
                            title=ft.Text("Copiar Texto Formatado", color=ft.Colors.WHITE),
                            subtitle=ft.Text("Para colar no WhatsApp, Instagram ou anotações", size=11, color=ft.Colors.WHITE_60),
                            on_click=_handle_copy,
                        ),
                        ft.ListTile(
                            leading=ft.Icon(ft.Icons.IMAGE_OUTLINED, color=ft.Colors.LIGHT_BLUE_300),
                            title=ft.Text("Baixar Imagem com o Versículo", color=ft.Colors.WHITE),
                            subtitle=ft.Text("Salva imagem em alta definição pronta para Stories", size=11, color=ft.Colors.WHITE_60),
                            on_click=_handle_download,
                        ),
                        ft.Container(height=12),
                    ],
                    tight=True,
                    spacing=6,
                ),
                bgcolor=ft.Colors.GREY_900,
                border_radius=ft.BorderRadius(top_left=24, top_right=24, bottom_left=0, bottom_right=0),
                padding=ft.Padding.symmetric(horizontal=18, vertical=16),
            ),
        )
        page.overlay.append(bs)
        bs.open = True
        page.update()

    def build(self, page: ft.Page) -> ft.View:
        self._current_img_url = self._get_daily_nature_image()

        self.category_badge = ft.Text(
            "VERSÍCULO DO DIA",
            size=12,
            weight=ft.FontWeight.BOLD,
            color=ft.Colors.WHITE_70,
        )
        self.ref_text_ref = ft.Text(
            "Carregando passagem...",
            size=18,
            weight=ft.FontWeight.BOLD,
            color=ft.Colors.WHITE,
        )
        self.verse_text_ref = ft.Text(
            "\"Aquietai-vos e sabei que eu sou Deus.\"",
            font_family="HymnSerif",
            size=24,
            weight=ft.FontWeight.NORMAL,
            text_align=ft.TextAlign.LEFT,
            color=ft.Colors.WHITE,
        )

        self.text_block_column = ft.Column(
            controls=[
                self.category_badge,
                ft.Container(height=2),
                self.ref_text_ref,
                ft.Container(height=12),
                self.verse_text_ref,
            ],
            spacing=4,
            horizontal_alignment=ft.CrossAxisAlignment.START,
            tight=True,
        )

        self.text_container = ft.Container(
            content=self.text_block_column,
            alignment=ft.Alignment.CENTER_LEFT,
            padding=ft.Padding.symmetric(horizontal=28, vertical=20),
        )

        # Botões de Ação na base (estilo YouVersion / AndBible)
        self.btn_fav_icon = ft.Icon(ft.Icons.FAVORITE_BORDER, size=22, color=ft.Colors.WHITE)
        self.btn_fav_text = ft.Text("Favoritar", size=11, color=ft.Colors.WHITE)

        btn_fav = ft.Container(
            content=ft.Column(
                controls=[
                    self.btn_fav_icon,
                    self.btn_fav_text,
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            padding=ft.Padding.symmetric(horizontal=12, vertical=8),
            ink=True,
            border_radius=12,
            on_click=lambda e: asyncio.create_task(self._toggle_favorito(page)),
        )

        btn_share = ft.Container(
            content=ft.Column(
                controls=[
                    ft.Icon(ft.Icons.SHARE_OUTLINED, size=22, color=ft.Colors.WHITE),
                    ft.Text("Compartilhar", size=11, color=ft.Colors.WHITE),
                ],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            padding=ft.Padding.symmetric(horizontal=12, vertical=8),
            ink=True,
            border_radius=12,
            on_click=lambda e: self._open_share_dialog(page),
        )

        btn_read = ft.FilledButton(
            "Ler Meditação",
            icon=ft.Icons.MENU_BOOK_ROUNDED,
            style=ft.ButtonStyle(
                color=ft.Colors.WHITE,
                bgcolor=ft.Colors.with_opacity(0.35, ft.Colors.BLACK),
                shape=ft.RoundedRectangleBorder(radius=20),
                side=ft.BorderSide(1.0, ft.Colors.with_opacity(0.35, ft.Colors.WHITE)),
                padding=ft.Padding.symmetric(horizontal=20, vertical=14),
            ),
            on_click=lambda e: asyncio.create_task(page.push_route("/meditacoes")),
        )

        bottom_bar = ft.Container(
            content=ft.Row(
                controls=[
                    btn_fav,
                    btn_share,
                    ft.Container(expand=True),
                    btn_read,
                ],
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            ),
            padding=ft.Padding.symmetric(horizontal=20, vertical=12),
        )

        top_bar = ft.Row(
            controls=[
                ft.IconButton(
                    icon=ft.Icons.CLOSE,
                    icon_color=ft.Colors.WHITE,
                    tooltip="Fechar",
                    on_click=lambda e: asyncio.create_task(page.push_route("/")),
                ),
            ],
            alignment=ft.MainAxisAlignment.START,
        )

        content = ft.Column(
            controls=[
                top_bar,
                ft.Container(expand=True),
                self.text_container,
                ft.Container(expand=True),
                bottom_bar,
            ],
            horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
            expand=True,
        )

        # Fundo de natureza com imagem e scrim gradiente protetor
        bg_image = ft.Image(
            src=self._current_img_url,
            fit=ft.BoxFit.COVER,
            expand=True,
            width=float("inf"),
            height=float("inf"),
        )

        # Scrim com degradê vertical sutil para garantir legibilidade editorial
        scrim_overlay = ft.Container(
            gradient=ft.LinearGradient(
                begin=ft.Alignment.TOP_CENTER,
                end=ft.Alignment.BOTTOM_CENTER,
                colors=[
                    ft.Colors.with_opacity(0.40, ft.Colors.BLACK),
                    ft.Colors.with_opacity(0.15, ft.Colors.BLACK),
                    ft.Colors.with_opacity(0.70, ft.Colors.BLACK),
                ],
            ),
            expand=True,
        )

        root_stack = ft.Stack(
            controls=[
                bg_image,
                scrim_overlay,
                ft.SafeArea(content=content, expand=True),
            ],
            expand=True,
        )

        page.run_task(self._load_devotional_data, page)

        return ft.View(
            route="/meditacao/destaque",
            padding=0,
            controls=[root_stack],
        )
