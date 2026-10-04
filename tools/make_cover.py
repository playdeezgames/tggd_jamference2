#!/usr/bin/env python3
"""Draws assets/cover.png (630x500, the itch.io cover) from assets/tileset.png. Needs Pillow."""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sheet = Image.open(os.path.join(ROOT, "assets/tileset.png")).convert("RGBA")
px = sheet.load()
for y in range(sheet.height):
    for x in range(sheet.width):
        if sum(px[x, y][:3]) == 0:
            px[x, y] = (0, 0, 0, 0)  # the tileset's black is opaque; knock it out

def tile(c, r):
    return sheet.crop((13 * c + 1, 13 * r + 1, 13 * c + 13, 13 * r + 13))

W, H, S = 630, 500, 3
T = 12 * S
img = Image.new("RGBA", (W, H), (8, 8, 14, 255))

def opaque(t):
    bg = Image.new("RGBA", (12, 12), (0, 0, 0, 255))
    bg.alpha_composite(t)
    return bg.resize((T, T), Image.NEAREST)

wall, floor = opaque(tile(0, 2)), opaque(tile(15, 6))  # level 1's look
cols, rows = W // T + 1, H // T + 1
for r in range(rows):
    for c in range(cols):
        edge = c == 0 or r == 0 or c >= cols - 2 or r >= rows - 2
        img.paste(wall if edge else floor, (c * T, r * T))

# title panel
px0, py0, px1, py1 = T, T, W - T - T // 2, T + 236
img.alpha_composite(Image.new("RGBA", (px1 - px0, py1 - py0), (5, 7, 24, 235)), (px0, py0))

# decorative font for letters, plain font for symbols (same tables as src/web.odin)
FANCY = [(47, 97, "ABCDEF"), (48, 78, "GHIJKLMNOPQRSTUVWXYZabcde"), (49, 78, "fghijklmnopqrstuvwxyz")]
PLAIN = [(44, 78, "ABCDEFGHIJKLMNOPQRST12345"), (45, 78, "UVWXYZabcdefghijklmn67890"),
         (46, 78, "opqrstuvwxyz()[]{}<>+-?!^"), (47, 78, ":#_@%~$\"'&*=`|/\\.,;")]

def glyph(ch):
    for runs in (FANCY, PLAIN):
        for row, col, chars in runs:
            if ch in chars:
                return tile(col + chars.index(ch), row)

def text(s, cx, y, scale, step):
    x = cx - len(s) * step // 2
    for i, ch in enumerate(s):
        g = glyph(ch)
        if g:
            img.alpha_composite(g.resize((12 * scale, 12 * scale), Image.NEAREST), (x + i * step, y))

cx = (px0 + px1) // 2
text("ROOMBA RIGHTS", cx, py0 + 18, 4, 41)
text("OF SPLORR!!", cx, py0 + 84, 3, 36)
text("a metaphor about", cx, py0 + 148, 2, 24)
text("trying to nap.", cx, py0 + 180, 2, 24)

def sprite(c, r, x, y, s=4):
    img.alpha_composite(tile(c, r).resize((12 * s, 12 * s), Image.NEAREST), (x, y))

by = py1 + 44
sprite(21, 36, 2 * T, by)   # sofa
sprite(1, 14, 6 * T, by)    # cat
for dx, dy in ((54, -4), (68, -22), (84, -42)):  # z z z
    img.alpha_composite(glyph("z").resize((24, 24), Image.NEAREST), (6 * T + dx, by + dy))
sprite(20, 36, 10 * T, by)  # basket
sprite(57, 12, 14 * T, by)  # the vacuum
img.convert("RGB").save(os.path.join(ROOT, "assets/cover.png"))
