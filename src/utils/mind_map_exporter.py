"""
Utilitário para geração e exportação de mapas mentais em formato PNG de alta fidelidade
em Python puro (sem dependência do Pillow ou bibliotecas nativas de compilação C).
Renderiza nós centrais, ramos com conexões geométricas, texto com fonte bitmap limpa
e marca d'água elegante 'Kairós — Escola Sabatina'.
"""

from __future__ import annotations

import math
import struct
import zlib
from typing import Any


# Mapa de fonte bitmap simplificada 5x7 para caracteres ASCII legíveis
FONT_5X7: dict[str, list[int]] = {
    ' ': [0, 0, 0, 0, 0],
    'A': [0x7E, 0x11, 0x11, 0x11, 0x7E],
    'B': [0x7F, 0x49, 0x49, 0x49, 0x36],
    'C': [0x3E, 0x41, 0x41, 0x41, 0x22],
    'D': [0x7F, 0x41, 0x41, 0x22, 0x1C],
    'E': [0x7F, 0x49, 0x49, 0x49, 0x41],
    'F': [0x7F, 0x09, 0x09, 0x09, 0x01],
    'G': [0x3E, 0x41, 0x49, 0x49, 0x7A],
    'H': [0x7F, 0x08, 0x08, 0x08, 0x7F],
    'I': [0x00, 0x41, 0x7F, 0x41, 0x00],
    'J': [0x20, 0x40, 0x41, 0x3F, 0x01],
    'K': [0x7F, 0x08, 0x14, 0x22, 0x41],
    'L': [0x7F, 0x40, 0x40, 0x40, 0x40],
    'M': [0x7F, 0x02, 0x0C, 0x02, 0x7F],
    'N': [0x7F, 0x04, 0x08, 0x10, 0x7F],
    'O': [0x3E, 0x41, 0x41, 0x41, 0x3E],
    'P': [0x7F, 0x09, 0x09, 0x09, 0x06],
    'Q': [0x3E, 0x41, 0x51, 0x21, 0x5E],
    'R': [0x7F, 0x09, 0x19, 0x29, 0x46],
    'S': [0x46, 0x49, 0x49, 0x49, 0x31],
    'T': [0x01, 0x01, 0x7F, 0x01, 0x01],
    'U': [0x3F, 0x40, 0x40, 0x40, 0x3F],
    'V': [0x1F, 0x20, 0x40, 0x20, 0x1F],
    'W': [0x7F, 0x20, 0x18, 0x20, 0x7F],
    'X': [0x63, 0x14, 0x08, 0x14, 0x63],
    'Y': [0x07, 0x08, 0x70, 0x08, 0x07],
    'Z': [0x61, 0x51, 0x49, 0x45, 0x43],
    '0': [0x3E, 0x51, 0x49, 0x45, 0x3E],
    '1': [0x00, 0x42, 0x7F, 0x40, 0x00],
    '2': [0x42, 0x61, 0x51, 0x49, 0x46],
    '3': [0x21, 0x41, 0x45, 0x4B, 0x31],
    '4': [0x18, 0x14, 0x12, 0x7F, 0x10],
    '5': [0x27, 0x45, 0x45, 0x45, 0x39],
    '6': [0x3C, 0x4A, 0x49, 0x49, 0x30],
    '7': [0x01, 0x71, 0x09, 0x05, 0x03],
    '8': [0x36, 0x49, 0x49, 0x49, 0x36],
    '9': [0x06, 0x49, 0x49, 0x29, 0x1E],
    '-': [0x08, 0x08, 0x08, 0x08, 0x08],
    ':': [0x00, 0x36, 0x36, 0x00, 0x00],
    '.': [0x00, 0x60, 0x60, 0x00, 0x00],
    '!': [0x00, 0x00, 0x5F, 0x00, 0x00],
    '?': [0x02, 0x01, 0x51, 0x09, 0x06],
    '(': [0x00, 0x1C, 0x22, 0x41, 0x00],
    ')': [0x00, 0x41, 0x22, 0x1C, 0x00],
}


def _normalize_char(ch: str) -> str:
    """Substitui caracteres acentuados comuns por ASCII correspondente."""
    c = ch.upper()
    accents = {
        'Á': 'A', 'À': 'A', 'Ã': 'A', 'Â': 'A', 'Ä': 'A',
        'É': 'E', 'È': 'E', 'Ê': 'E', 'Ë': 'E',
        'Í': 'I', 'Ì': 'I', 'Î': 'I', 'Ï': 'I',
        'Ó': 'O', 'Ò': 'O', 'Õ': 'O', 'Ô': 'O', 'Ö': 'O',
        'Ú': 'U', 'Ù': 'U', 'Û': 'U', 'Ü': 'U',
        'Ç': 'C',
    }
    return accents.get(c, c if c in FONT_5X7 else '?')


def generate_mind_map_png(
    root_word: str,
    nodes: list[dict[str, Any]],
    width: int = 1200,
    height: int = 800,
) -> bytes:
    """
    Gera os bytes de um arquivo PNG com layout elegante do mapa mental.
    """
    pixels = bytearray(width * height * 3)

    # 1. Fundo Gradiente Suave Noturno (Slate profundo para Indigo escuro)
    for y in range(height):
        ratio = y / height
        r = int(16 + ratio * 14)
        g = int(20 + ratio * 16)
        b = int(32 + ratio * 28)
        offset = y * width * 3
        for x in range(width):
            idx = offset + x * 3
            pixels[idx] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b

    def set_pixel(x: int, y: int, color: tuple[int, int, int]) -> None:
        if 0 <= x < width and 0 <= y < height:
            idx = (y * width + x) * 3
            pixels[idx] = color[0]
            pixels[idx + 1] = color[1]
            pixels[idx + 2] = color[2]

    def draw_line(x0: int, y0: int, x1: int, y1: int, color: tuple[int, int, int], thickness: int = 2) -> None:
        dx = abs(x1 - x0)
        dy = abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx - dy
        while True:
            for tx in range(-thickness // 2, thickness // 2 + 1):
                for ty in range(-thickness // 2, thickness // 2 + 1):
                    set_pixel(x0 + tx, y0 + ty, color)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 > -dy:
                err -= dy
                x0 += sx
            if e2 < dx:
                err += dx
                y0 += sy

    def draw_rounded_rect(
        cx: int,
        cy: int,
        rw: int,
        rh: int,
        fill_color: tuple[int, int, int],
        border_color: tuple[int, int, int],
    ) -> None:
        x1 = cx - rw // 2
        x2 = cx + rw // 2
        y1 = cy - rh // 2
        y2 = cy + rh // 2
        for y in range(y1, y2 + 1):
            for x in range(x1, x2 + 1):
                is_border = (x <= x1 + 1 or x >= x2 - 1 or y <= y1 + 1 or y >= y2 - 1)
                set_pixel(x, y, border_color if is_border else fill_color)

    def draw_text(
        text: str,
        cx: int,
        cy: int,
        color: tuple[int, int, int],
        scale: int = 2,
    ) -> None:
        norm_chars = [_normalize_char(ch) for ch in text[:28]]
        total_width = len(norm_chars) * (6 * scale) - (1 * scale)
        start_x = cx - total_width // 2
        start_y = cy - (7 * scale) // 2

        curr_x = start_x
        for ch in norm_chars:
            bitmap = FONT_5X7.get(ch, FONT_5X7['?'])
            for col_idx, col_bits in enumerate(bitmap):
                for row_idx in range(7):
                    if (col_bits >> row_idx) & 1:
                        for sx in range(scale):
                            for sy in range(scale):
                                set_pixel(curr_x + col_idx * scale + sx, start_y + row_idx * scale + sy, color)
            curr_x += 6 * scale

    cx, cy = width // 2, height // 2
    n = len(nodes)
    radius_x = min(420, width // 2 - 120)
    radius_y = min(260, height // 2 - 100)

    # Esquema de Cores Material 3
    primary_fill = (99, 102, 241)        # Indigo
    primary_border = (199, 210, 254)
    line_color = (100, 116, 139)          # Slate
    node_fill = (30, 41, 59)             # Slate Escuro
    node_border = (56, 189, 248)         # Cyan/Azul
    text_color = (248, 250, 252)

    # 1. Calcular posições dos nós satélites
    node_positions: list[tuple[int, int, str]] = []
    for i, node in enumerate(nodes):
        angle = (2 * math.pi * i) / max(1, n) - (math.pi / 2)
        nx = int(cx + radius_x * math.cos(angle))
        ny = int(cy + radius_y * math.sin(angle))
        node_positions.append((nx, ny, str(node.get("text", "Ideia"))))

    # 2. Traçar linhas conectoras radiais
    for nx, ny, _ in node_positions:
        draw_line(cx, cy, nx, ny, line_color, thickness=3)

    # 3. Desenhar nós satélites
    for nx, ny, text in node_positions:
        draw_rounded_rect(nx, ny, 190, 60, node_fill, node_border)
        draw_text(text, nx, ny, text_color, scale=2)

    # 4. Desenhar nó raiz central
    draw_rounded_rect(cx, cy, 240, 75, primary_fill, primary_border)
    draw_text(root_word or "REDE SEMANTICA", cx, cy, (255, 255, 255), scale=3)

    # 5. Marca d'água / Rodapé
    draw_text("KAIROS - ESCOLA SABATINA", width // 2, height - 35, (148, 163, 184), scale=2)

    # 6. Codificação estruturada de PNG
    header = b'\x89PNG\r\n\x1a\n'

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    raw_rows = []
    for y in range(height):
        offset = y * width * 3
        raw_rows.append(b'\x00' + bytes(pixels[offset : offset + width * 3]))
    idat = chunk(b'IDAT', zlib.compress(b''.join(raw_rows), level=6))
    iend = chunk(b'IEND', b'')

    return header + ihdr + idat + iend
