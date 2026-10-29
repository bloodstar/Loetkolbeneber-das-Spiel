"""Generate the non-pixel Battle Balls tilesets.

The in-game tile grid stays at 36 px. Every PNG below is drawn at 4x and
downsampled with Lanczos, so the result is smooth at native size while keeping
the exact same collision/layout grid as the old 18 px textures.

Run from the project root:
    python tools/generate_tilesets.py
Optional contact sheet:
    python tools/generate_tilesets.py --preview
"""

from __future__ import annotations

import math
import random
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "tilesets"

TILE = 36
SS = 4
SIZE = TILE * SS
CENTER = TILE * 0.5


def u(value: float) -> int:
    return int(round(value * SS))


def box(values) -> list[int]:
    return [u(v) for v in values]


def rgba(color, alpha: float | None = None):
    if alpha is None:
        return color
    return (color[0], color[1], color[2], int(round(color[3] * alpha if len(color) > 3 else alpha)))


def canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))


def draw_of(img: Image.Image) -> ImageDraw.ImageDraw:
    return ImageDraw.Draw(img)


def vertical_gradient(img: Image.Image, top, bottom, y0: float = 0.0, y1: float = TILE):
    px = img.load()
    ys, ye = max(0, int(y0 * SS)), min(SIZE, int(y1 * SS))
    for y in range(ys, ye):
        t = 0.0 if y1 <= y0 else (y / SS - y0) / (y1 - y0)
        t = max(0.0, min(1.0, t))
        color = tuple(int(top[i] * (1.0 - t) + bottom[i] * t) for i in range(4))
        for x in range(SIZE):
            px[x, y] = color


def rounded(d: ImageDraw.ImageDraw, rect, radius: float, fill=None, outline=None, width: float = 1.0):
    d.rounded_rectangle(box(rect), radius=u(radius), fill=fill, outline=outline, width=max(1, u(width)))


def rect(d: ImageDraw.ImageDraw, rect_, fill, outline=None, width: float = 1.0):
    d.rectangle(box(rect_), fill=fill, outline=outline, width=max(1, u(width)))


def line(d: ImageDraw.ImageDraw, points, fill, width: float = 1.0):
    d.line([(u(x), u(y)) for x, y in points], fill=fill, width=max(1, u(width)), joint="curve")


def ellipse(d: ImageDraw.ImageDraw, rect_, fill=None, outline=None, width: float = 1.0):
    d.ellipse(box(rect_), fill=fill, outline=outline, width=max(1, u(width)))


def polygon(d: ImageDraw.ImageDraw, points, fill=None, outline=None, width: float = 1.0):
    d.polygon([(u(x), u(y)) for x, y in points], fill=fill, outline=outline, width=max(1, u(width)))


def wrapped_ellipse(d: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, fill):
    for dx in (-TILE, 0, TILE):
        for dy in (-TILE, 0, TILE):
            ellipse(d, (cx + dx - rx, cy + dy - ry, cx + dx + rx, cy + dy + ry), fill=fill)


def wrapped_line(d: ImageDraw.ImageDraw, points, fill, width: float = 1.0):
    for dx in (-TILE, 0, TILE):
        for dy in (-TILE, 0, TILE):
            line(d, [(x + dx, y + dy) for x, y in points], fill, width)


def add_noise(img: Image.Image, seed: int, colors, count: int = 40, inset: float = 2.0):
    rng = random.Random(seed)
    d = draw_of(img)
    for _ in range(count):
        x = rng.uniform(inset, TILE - inset)
        y = rng.uniform(inset, TILE - inset)
        r = rng.uniform(0.35, 1.3)
        wrapped_ellipse(d, x, y, r, r * rng.uniform(0.45, 1.0), rng.choice(colors))


def save(img: Image.Image, theme: str, name: str) -> None:
    folder = OUT / theme
    folder.mkdir(parents=True, exist_ok=True)
    img.resize((TILE, TILE), Image.Resampling.LANCZOS).save(folder / name)


def sparkle(d: ImageDraw.ImageDraw, x: float, y: float, size: float, color):
    line(d, [(x - size, y), (x + size, y)], color, 0.8)
    line(d, [(x, y - size), (x, y + size)], color, 0.8)


def crack(d: ImageDraw.ImageDraw, points, color, width: float = 1.0):
    line(d, points, color, width)
    for x, y in points[1:-1]:
        line(d, [(x, y), (x + 2.6, y + 1.6)], color, width * 0.65)


# ---------------------------------------------------------------------------
# Ground top tiles


def storybook_ground_top(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (84, 60, 45, 255), (42, 30, 24, 255), 7, 36)
    d = draw_of(img)

    # Soil strata and stones stay inside the cell so neighbouring variants blend.
    for y, color in ((17, (106, 76, 55, 130)), (27, (55, 39, 29, 130))):
        line(d, [(0, y), (TILE, y + 0.4)], color, 1.0)
    add_noise(img, 100 + variant, [(125, 88, 61, 130), (61, 42, 32, 180), (91, 63, 46, 150)], 34, 3)

    rocks = [
        [(4, 30, 9, 3), (24, 22, 8, 2.5), (14, 33, 7, 2)],
        [(2, 22, 8, 2.5), (19, 31, 10, 3), (29, 23, 5, 2)],
        [(7, 24, 6, 2), (16, 28, 9, 3), (26, 34, 7, 2)],
    ][variant]
    for cx, cy, rx, ry in rocks:
        ellipse(d, (cx - rx, cy - ry, cx + rx, cy + ry), fill=(75, 51, 37, 210), outline=(35, 24, 18, 180), width=0.5)
        ellipse(d, (cx - rx * 0.7, cy - ry * 0.75, cx + rx * 0.25, cy - ry * 0.1), fill=(109, 76, 55, 80))

    # Root lines.
    line(d, [(-1, 15 + variant), (8, 18), (16, 16), (26, 20), (37, 17)], (99, 64, 40, 210), 1.1)
    line(d, [(-1, 15 + variant), (8, 18), (16, 16), (26, 20), (37, 17)], (155, 100, 59, 75), 0.4)

    # Ruhige Grasnarbe: eine durchlaufende Welle statt einzelner, wie
    # Buchstaben wirkender Halme. Details kommen aus den Deko-Sprites.
    rect(d, (0, 0, TILE, 8.4), (55, 112, 66, 255))
    rect(d, (0, 0, TILE, 2.6), (112, 180, 91, 255))
    rect(d, (0, 2.2, TILE, 5.0), (80, 151, 78, 255))
    wave = [(x * 2.0, 7.8 + math.sin(x * math.tau / 9.0) * 1.05) for x in range(19)]
    grass_poly = [(-1.0, 11.2)] + wave + [(TILE + 1.0, 11.2)]
    polygon(d, grass_poly, fill=(44, 98, 60, 255))
    wave2 = [(x * 2.0, 8.9 + math.sin(x * math.tau / 9.0 + 0.6) * 0.75) for x in range(19)]
    line(d, wave2, (34, 82, 50, 150), 0.65)
    line(d, [(0, 1.0), (TILE, 1.0)], (168, 221, 128, 130), 0.65)
    add_noise(img, 140 + variant, [(122, 185, 101, 65), (48, 100, 61, 55)], 16, 1.2)
    if variant == 1:
        for cx, color in ((7.5, (239, 192, 94, 255)), (28.0, (239, 144, 163, 255))):
            ellipse(d, (cx - 0.9, 3.3, cx + 0.9, 5.1), fill=color)
    if variant == 2:
        ellipse(d, (24.0, 8.7, 30.0, 10.4), fill=(53, 119, 65, 190))
    return img


def neon_ground_top(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (12, 22, 39, 255), (5, 9, 17, 255))
    d = draw_of(img)
    rect(d, (0, 0, TILE, 5.8), (6, 12, 22, 255))
    rect(d, (0, 0, TILE, 1.9), (96, 242, 255, 255))
    rect(d, (0, 1.9, TILE, 4.8), (42, 172, 205, 255))
    line(d, [(0, 5.8), (TILE, 5.8)], (7, 21, 36, 255), 1.0)
    line(d, [(0, 1.0), (TILE, 1.0)], (201, 255, 255, 210), 0.65)

    # Recessed service panel.
    rounded(d, (1.0, 8.0, TILE - 1.0, TILE - 1.0), 1.4, fill=(10, 18, 31, 255), outline=(26, 47, 69, 255), width=0.7)
    for x in (5.5, 18.0, 30.5):
        line(d, [(x, 10.2), (x, 34.2)], (21, 41, 61, 190), 0.6)
    line(d, [(1.4, 23.0), (TILE - 1.4, 23.0)], (28, 51, 76, 180), 0.5)

    if variant == 0:
        line(d, [(2.0, 29.0), (9.0, 29.0), (12.0, 26.0), (22.0, 26.0)], (245, 54, 188, 200), 0.9)
        for x in (3.5, 18.0, 32.5):
            ellipse(d, (x - 0.8, 12.5, x + 0.8, 14.1), fill=(80, 235, 255, 220))
    elif variant == 1:
        line(d, [(11.0, 12.0), (11.0, 17.0), (16.0, 17.0), (16.0, 22.0)], (70, 223, 250, 180), 0.8)
        ellipse(d, (25.1, 29.1, 27.1, 31.1), fill=(250, 74, 197, 230))
    else:
        line(d, [(2.0, 30.0), (8.0, 30.0), (10.0, 28.0)], (250, 74, 197, 180), 0.8)
        line(d, [(24.0, 14.0), (29.0, 14.0), (32.0, 11.5)], (80, 235, 255, 170), 0.75)
    add_noise(img, 220 + variant, [(72, 224, 247, 70), (245, 53, 187, 55), (128, 165, 196, 80)], 18, 3.0)
    return img


def wool_ground_top(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (220, 137, 169, 255), (174, 94, 130, 255), 6, 36)
    d = draw_of(img)

    # Woven base: the diagonal pattern continues across tile boundaries.
    for offset in range(-2, 6):
        x0 = offset * 9.0
        line(d, [(x0, 36), (x0 + 36, 0)], (197, 112, 145, 90), 0.7)
        line(d, [(x0 + 3.0, 36), (x0 + 39, 0)], (239, 165, 190, 45), 0.55)

    # Puffy crown with a fixed stitch rhythm.
    rect(d, (0, 2.0, TILE, 8.0), (238, 205, 218, 255))
    for cx in (1.5, 10.5, 19.5, 28.5, 37.5):
        ellipse(d, (cx - 5.1, 0.2, cx + 5.1, 10.2), fill=(246, 224, 232, 255))
        ellipse(d, (cx - 4.3, 1.4, cx + 1.2, 7.4), fill=(255, 242, 247, 255))
    for x in (2.5, 12.0, 21.5, 31.0):
        line(d, [(x, 9.5), (x + 3.7, 9.5)], (144, 75, 103, 205), 0.65)
    line(d, [(0, 6.6), (TILE, 6.6)], (161, 87, 116, 120), 0.55)

    # Little knitted loops.
    loops = [
        [(5, 22), (7, 19), (9, 22), (7, 25)],
        [(22, 29), (24, 26), (26, 29), (24, 32)],
        [(31, 16), (33, 13), (35, 16), (33, 19)],
    ] if variant == 0 else [
        [(8, 29), (10, 26), (12, 29), (10, 32)],
        [(27, 20), (29, 17), (31, 20), (29, 23)],
        [(16, 15), (18, 12), (20, 15), (18, 18)],
    ] if variant == 1 else [
        [(4, 16), (6, 13), (8, 16), (6, 19)],
        [(18, 24), (20, 21), (22, 24), (20, 27)],
        [(30, 30), (32, 27), (34, 30), (32, 33)],
    ]
    for points in loops:
        line(d, points, (226, 145, 174, 160), 0.8)
    if variant == 2:
        ellipse(d, (15.2, 18.3, 20.8, 23.8), fill=(246, 204, 218, 255), outline=(139, 73, 99, 180), width=0.5)
        for x, y in ((16.7, 20.0), (19.2, 20.0), (16.7, 22.2), (19.2, 22.2)):
            ellipse(d, (x - 0.45, y - 0.45, x + 0.45, y + 0.45), fill=(126, 63, 88, 220))
    return img


def frost_ground_top(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (102, 185, 219, 255), (37, 108, 145, 255), 7, 36)
    d = draw_of(img)
    rect(d, (0, 0, TILE, 9.0), (221, 247, 255, 255))
    for cx in (1.5, 10.5, 19.5, 28.5, 37.5):
        ellipse(d, (cx - 5.2, -0.4, cx + 5.2, 10.6), fill=(237, 251, 255, 255))
        ellipse(d, (cx - 3.8, 0.2, cx + 1.8, 6.0), fill=(255, 255, 255, 255))
    line(d, [(0, 9.3), (TILE, 9.3)], (90, 161, 195, 220), 0.9)
    line(d, [(0, 1.0), (TILE, 1.0)], (255, 255, 255, 180), 0.6)

    cracks = [
        [(2, 18), (8, 22), (13, 20), (18, 27), (25, 25), (29, 31), (35, 29)],
        [(1, 27), (7, 23), (11, 26), (17, 20), (23, 22), (28, 17), (35, 19)],
        [(3, 13), (9, 16), (13, 13), (21, 18), (27, 14), (34, 16)],
    ][variant]
    crack(d, cracks, (26, 83, 121, 150), 0.8)
    crack(d, [(x + 0.7, y + 0.5) for x, y in cracks], (198, 239, 250, 90), 0.35)
    add_noise(img, 430 + variant, [(206, 245, 255, 80), (55, 136, 171, 65)], 20, 2.5)
    return img


# ---------------------------------------------------------------------------
# Fill tiles


def storybook_fill(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (83, 57, 42, 255), (35, 25, 20, 255))
    d = draw_of(img)
    for y, color in ((8, (103, 70, 50, 140)), (18, (55, 38, 29, 160)), (29, (84, 56, 40, 120))):
        line(d, [(0, y), (TILE, y + 0.5)], color, 0.8)
    add_noise(img, 510 + variant, [(118, 81, 57, 130), (57, 39, 29, 180), (97, 67, 48, 130)], 45, 2.0)
    roots = [
        [(-1, 7), (8, 11), (15, 9), (23, 14), (37, 12)],
        [(-1, 25), (6, 22), (12, 27), (21, 24), (37, 29)],
        [(-1, 16), (7, 19), (14, 16), (22, 21), (37, 18)],
    ][variant]
    line(d, roots, (105, 68, 43, 210), 1.23)
    line(d, roots, (153, 100, 60, 68), 0.42)
    for cx, cy in ((8, 31), (27, 8), (30, 24)):
        ellipse(d, (cx - 2.0, cy - 1.4, cx + 2.0, cy + 1.4), fill=(59, 41, 30, 180))
    return img


def neon_fill(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (12, 21, 37, 255), (5, 9, 16, 255))
    d = draw_of(img)
    rounded(d, (0.5, 0.5, TILE - 0.5, TILE - 0.5), 1.0, fill=(11, 19, 32, 255), outline=(24, 43, 64, 255), width=0.55)
    line(d, [(18, 2.0), (18, 34.0)], (23, 44, 67, 180), 0.55)
    line(d, [(2.0, 18), (34.0, 18)], (23, 44, 67, 180), 0.55)
    for x, y in ((2.7, 2.7), (33.3, 2.7), (2.7, 33.3), (33.3, 33.3)):
        ellipse(d, (x - 0.55, y - 0.55, x + 0.55, y + 0.55), fill=(85, 126, 157, 150))
    if variant == 0:
        line(d, [(21, 18), (21, 25), (28, 25), (28, 30)], (49, 214, 243, 120), 0.6)
    elif variant == 1:
        line(d, [(8, 18), (8, 13), (13, 13)], (245, 59, 192, 105), 0.6)
    else:
        ellipse(d, (25.0, 25.0, 31.0, 31.0), outline=(51, 210, 241, 95), width=0.6)
    add_noise(img, 620 + variant, [(62, 190, 218, 45), (224, 60, 181, 35), (115, 150, 181, 45)], 16, 2.0)
    return img


def wool_fill(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (202, 121, 153, 255), (149, 76, 108, 255))
    d = draw_of(img)
    for offset in range(-2, 6):
        x0 = offset * 9.0
        line(d, [(x0, 36), (x0 + 36, 0)], (225, 143, 174, 70), 0.65)
        line(d, [(x0 + 3.0, 36), (x0 + 39, 0)], (166, 84, 119, 70), 0.55)
    for x in (2.0, 20.0):
        line(d, [(x, 18.0), (x + 10.0, 18.0)], (238, 194, 211, 105), 0.65)
    loops = [
        [(4, 8), (6, 5), (8, 8), (6, 11)],
        [(25, 26), (27, 23), (29, 26), (27, 29)],
    ] if variant == 0 else [
        [(16, 29), (18, 26), (20, 29), (18, 32)],
        [(31, 12), (33, 9), (35, 12), (33, 15)],
    ] if variant == 1 else [
        [(10, 14), (12, 11), (14, 14), (12, 17)],
        [(21, 20), (23, 17), (25, 20), (23, 23)],
    ]
    for points in loops:
        line(d, points, (232, 150, 179, 125), 0.8)
    add_noise(img, 720 + variant, [(236, 157, 183, 50), (145, 72, 101, 60)], 22, 2.0)
    return img


def frost_fill(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (82, 158, 194, 255), (31, 84, 118, 255))
    d = draw_of(img)
    facets = [
        [(0, 10), (11, 4), (21, 15), (36, 9)],
        [(0, 26), (10, 20), (19, 27), (36, 21)],
        [(0, 5), (8, 12), (20, 7), (36, 13)],
    ][variant]
    line(d, facets, (191, 234, 247, 70), 1.0)
    crack(d, [(3, 14), (10, 18), (12, 25), (20, 29), (32, 24)], (24, 70, 103, 130), 0.85)
    crack(d, [(20, 3), (17, 10), (21, 15), (19, 22), (25, 27)], (220, 249, 255, 80), 0.45)
    add_noise(img, 820 + variant, [(214, 246, 255, 55), (45, 113, 151, 55)], 20, 2.0)
    return img


# ---------------------------------------------------------------------------
# Platform tiles


def storybook_platform(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (115, 72, 44, 255), (53, 31, 19, 255), 6, 36)
    d = draw_of(img)
    rect(d, (0, 0, TILE, 7.0), (54, 111, 63, 255))
    rect(d, (0, 0, TILE, 2.4), (122, 183, 91, 255))
    wave = [(x * 2.0, 6.7 + math.sin(x * math.tau / 9.0) * 0.9) for x in range(19)]
    platform_grass = [(-1.0, 9.8)] + wave + [(TILE + 1.0, 9.8)]
    polygon(d, platform_grass, fill=(43, 96, 58, 255))
    line(d, [(0, 0.9), (TILE, 0.9)], (168, 221, 128, 120), 0.6)
    line(d, [(0, 7.0), (TILE, 7.0)], (28, 67, 39, 135), 0.65)
    for x in (6.0 + variant * 2.0, 18.0, 30.0 - variant * 1.3):
        line(d, [(x, 10.0), (x + 0.7, 31.5), (x - 0.6, 35.0)], (64, 38, 22, 200), 0.75)
    line(d, [(0, 20.0), (TILE, 19.3)], (151, 100, 57, 120), 0.55)
    line(d, [(0, 35.3), (TILE, 35.3)], (33, 19, 12, 200), 0.8)
    if variant == 1:
        line(d, [(25, 11), (27, 15), (24, 19)], (66, 143, 69, 220), 0.7)
    return img


def neon_platform(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (16, 28, 48, 255), (5, 9, 16, 255), 4, 36)
    d = draw_of(img)
    rect(d, (0, 0, TILE, 3.7), (10, 18, 30, 255))
    rect(d, (0, 0, TILE, 1.3), (95, 240, 255, 255))
    line(d, [(0, 3.7), (TILE, 3.7)], (46, 203, 231, 210), 0.7)
    rounded(d, (1.0, 5.0, TILE - 1.0, TILE - 1.0), 1.0, fill=(10, 18, 31, 255), outline=(28, 50, 74, 220), width=0.6)
    for x in (7.0 + variant, 24.0 - variant * 0.5):
        line(d, [(x, 7.0), (x, 33.6)], (22, 43, 65, 180), 0.55)
    line(d, [(1.0, 27.8), (TILE - 1.0, 27.8)], (241, 58, 192, 180), 0.7)
    line(d, [(0, 34.6), (TILE, 34.6)], (241, 58, 192, 70), 1.4)
    if variant == 2:
        ellipse(d, (14.5, 13.5, 21.5, 20.5), outline=(69, 220, 244, 90), width=0.65)
    return img


def wool_platform(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (217, 139, 169, 255), (164, 84, 118, 255), 4, 36)
    d = draw_of(img)
    for offset in range(-2, 6):
        x0 = offset * 9.0
        line(d, [(x0, 36), (x0 + 36, 0)], (235, 160, 186, 55), 0.6)
    rect(d, (0, 1.8, TILE, 7.4), (241, 211, 223, 255))
    for cx in (1.5, 10.5, 19.5, 28.5, 37.5):
        ellipse(d, (cx - 5.0, 0.0, cx + 5.0, 9.7), fill=(249, 230, 237, 255))
    for x in (2.5, 12.0, 21.5, 31.0):
        line(d, [(x, 8.8), (x + 3.8, 8.8)], (145, 76, 103, 200), 0.65)
    if variant != 1:
        line(d, [(0, 21.0), (TILE, 21.0)], (242, 185, 204, 120), 0.8)
        for x in (3.0, 12.0, 21.0, 30.0):
            line(d, [(x, 19.3), (x, 22.7)], (129, 64, 90, 160), 0.55)
    else:
        ellipse(d, (15.0, 14.0, 21.0, 20.0), fill=(241, 181, 202, 255), outline=(137, 70, 96, 160), width=0.55)
        for x, y in ((16.7, 16.0), (19.3, 16.0), (16.7, 18.0), (19.3, 18.0)):
            ellipse(d, (x - 0.4, y - 0.4, x + 0.4, y + 0.4), fill=(120, 59, 82, 220))
    line(d, [(0, 35.0), (TILE, 35.0)], (122, 59, 84, 190), 0.75)
    return img


def frost_platform(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (105, 179, 211, 255), (46, 108, 142, 255), 4, 36)
    d = draw_of(img)
    rect(d, (0, 0, TILE, 8.0), (225, 248, 255, 255))
    for cx in (1.5, 10.5, 19.5, 28.5, 37.5):
        ellipse(d, (cx - 4.9, -0.2, cx + 4.9, 9.5), fill=(241, 252, 255, 255))
    line(d, [(0, 8.1), (TILE, 8.1)], (88, 158, 192, 220), 0.8)
    facets = [
        [(0, 17), (9, 12), (18, 18), (27, 13), (36, 18)],
        [(0, 22), (7, 17), (15, 23), (25, 18), (36, 24)],
        [(0, 14), (10, 20), (20, 14), (29, 21), (36, 16)],
    ][variant]
    line(d, facets, (213, 246, 255, 70), 0.8)
    icicle_sets = [
        [(5.0, 8.0), (10.5, 6.0), (14.0, 4.0)],
        [(23.0, 6.0), (26.0, 9.0), (30.0, 4.5)],
        [(12.0, 5.0), (15.0, 7.5), (19.0, 3.5)],
    ][variant]
    for x, length in icicle_sets:
        polygon(d, [(x - 2.6, 35.5), (x, 35.5 - length), (x + 2.6, 35.5)], fill=(198, 239, 250, 235))
        line(d, [(x, 35.0 - length + 0.5), (x, 34.5)], (255, 255, 255, 150), 0.45)
    line(d, [(0, 35.2), (TILE, 35.2)], (35, 93, 126, 180), 0.7)
    return img


# ---------------------------------------------------------------------------
# Destructible blocks


def storybook_destructible(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    rounded(d, (1.0, 1.0, TILE - 1.0, TILE - 1.0), 3.2, fill=(91, 119, 83, 255), outline=(36, 52, 33, 255), width=1.4)
    rounded(d, (3.4, 3.4, TILE - 3.4, 18.0), 2.2, fill=(111, 142, 98, 255), outline=(60, 83, 54, 130), width=0.6)
    ellipse(d, (7.0, 0.2, 28.0, 8.0), fill=(72, 132, 70, 255))
    ellipse(d, (9.0, 1.0, 20.0, 5.6), fill=(117, 178, 99, 180))
    crack(d, [(8, 4), (14, 11), (12, 17), (19, 23), (17, 31)] if variant == 0 else [(26, 4), (21, 11), (24, 16), (19, 22), (22, 32)], (43, 58, 38, 210), 0.9)
    if variant == 1:
        ellipse(d, (13.5, 17.5, 22.5, 26.5), fill=(72, 97, 62, 255), outline=(37, 54, 35, 180), width=0.6)
        line(d, [(15, 22), (18, 19), (21, 22), (18, 25), (15, 22)], (217, 185, 91, 180), 0.65)
    return img


def neon_destructible(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    rounded(d, (1.0, 1.0, TILE - 1.0, TILE - 1.0), 2.0, fill=(13, 27, 46, 255), outline=(46, 230, 248, 225), width=0.9)
    rounded(d, (3.0, 3.0, TILE - 3.0, TILE - 3.0), 1.2, fill=(10, 18, 32, 255), outline=(26, 67, 96, 225), width=0.55)
    line(d, [(4.0, 9.0), (14.0, 9.0), (18.0, 13.0)], (102, 239, 255, 155), 0.65)
    line(d, [(32.0, 25.0), (23.0, 25.0), (19.0, 21.0)], (246, 61, 197, 145), 0.65)
    crack(d, [(18, 4), (14, 12), (20, 18), (16, 27), (21, 33)] if variant == 0 else [(8, 5), (12, 13), (9, 20), (16, 27), (13, 33)], (224, 252, 255, 180), 0.7)
    ellipse(d, (14.0, 13.0, 22.0, 21.0), fill=(238, 63, 193, 100), outline=(105, 244, 255, 230), width=0.65)
    return img


def wool_destructible(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    rounded(d, (1.0, 1.0, TILE - 1.0, TILE - 1.0), 5.0, fill=(237, 164, 189, 255), outline=(132, 68, 94, 235), width=1.3)
    rounded(d, (4.0, 4.0, TILE - 4.0, TILE - 4.0), 3.2, fill=(247, 197, 214, 255), outline=(247, 224, 232, 190), width=0.75)
    for x in range(5, 32, 5):
        line(d, [(x, 5.0), (x + 2.5, 5.0)], (157, 91, 117, 180), 0.55)
        line(d, [(x, 31.0), (x + 2.5, 31.0)], (157, 91, 117, 180), 0.55)
    ellipse(d, (12.0, 12.0, 24.0, 24.0), fill=(216, 111, 146, 255), outline=(123, 58, 84, 210), width=0.75)
    for x, y in ((15.0, 16.0), (21.0, 16.0), (15.0, 20.0), (21.0, 20.0)):
        ellipse(d, (x - 0.8, y - 0.8, x + 0.8, y + 0.8), fill=(103, 48, 69, 230))
    if variant == 1:
        line(d, [(4, 29), (8, 25), (6, 20)], (144, 70, 98, 160), 0.6)
    return img


def frost_destructible(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    rounded(d, (1.0, 1.0, TILE - 1.0, TILE - 1.0), 2.8, fill=(151, 218, 239, 245), outline=(225, 251, 255, 235), width=1.0)
    rounded(d, (3.5, 3.5, TILE - 3.5, TILE - 3.5), 2.0, fill=(117, 191, 222, 230), outline=(70, 145, 180, 150), width=0.65)
    line(d, [(4, 9), (13, 9), (17, 14), (28, 12)], (232, 253, 255, 140), 0.65)
    crack(d, [(16, 4), (12, 12), (18, 19), (14, 27), (20, 33)] if variant == 0 else [(26, 5), (22, 12), (26, 20), (20, 26), (24, 33)], (42, 108, 144, 190), 0.75)
    sparkle(d, 7.0, 26.0, 1.7, (245, 255, 255, 200))
    sparkle(d, 29.0, 9.0, 1.4, (245, 255, 255, 170))
    return img


# ---------------------------------------------------------------------------
# Vines


def vine_tile(strong: bool, variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    stem = (45, 114, 57, 255) if strong else (85, 153, 73, 255)
    leaf = (64, 147, 72, 255) if strong else (112, 186, 89, 255)
    light = (121, 201, 105, 255) if strong else (165, 219, 118, 255)
    dark = (27, 72, 38, 230)
    width = 3.4 if strong else 2.1
    y = 20.0 + (1.0 if variant else 0.0)
    points = []
    for i in range(9):
        x = -1.0 + i * (TILE + 2.0) / 8.0
        points.append((x, y + math.sin(i * 1.8 + variant) * 2.1))
    line(d, points, dark, width + 0.8)
    line(d, points, stem, width)
    line(d, [(x, yy - width * 0.23) for x, yy in points], light, 0.55)

    leaves = [
        (5.0, 16.0, -1), (13.0, 24.5, 1), (23.0, 15.0, -1), (32.0, 23.8, 1),
    ] if variant == 0 else [
        (7.0, 25.0, 1), (16.0, 15.8, -1), (27.0, 24.0, 1), (34.0, 16.5, -1),
    ]
    for lx, ly, direction in leaves:
        ellipse(d, (lx - 3.4, ly - 2.0, lx + 3.4, ly + 2.0), fill=leaf, outline=dark, width=0.45)
        line(d, [(lx - 2.2, ly), (lx + 2.4, ly - 0.2)], light, 0.45)
        line(d, [(lx - direction * 2.0, ly), (lx - direction * 4.8, ly - direction * 1.2)], dark, 0.45)

    if strong:
        for tx, ty, flip in ((3.0, 29.0, 1), (19.0, 9.0, -1), (31.0, 29.0, 1)):
            line(d, [(tx, ty), (tx + 2.0 * flip, ty + 3.0), (tx - 1.0 * flip, ty + 5.0)], stem, 0.7)
        if variant == 1:
            ellipse(d, (16.0, 27.2, 20.0, 31.2), fill=(238, 185, 91, 255))
    else:
        for fx, fy in ((8.0, 15.0), (29.0, 24.0)):
            for angle in range(5):
                a = angle * math.tau / 5.0
                ellipse(d, (fx + math.cos(a) * 2.3 - 0.9, fy + math.sin(a) * 2.3 - 0.9,
                           fx + math.cos(a) * 2.3 + 0.9, fy + math.sin(a) * 2.3 + 0.9), fill=(245, 207, 117, 240))
            ellipse(d, (fx - 0.8, fy - 0.8, fx + 0.8, fy + 0.8), fill=(241, 135, 146, 255))
    return img


# ---------------------------------------------------------------------------
# Decorations


def storybook_deco(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    if variant == 0:
        # Toadstool.
        rounded(d, (17.0, 20.0, 22.0, 35.0), 2.0, fill=(235, 218, 181, 255), outline=(103, 76, 58, 210), width=0.6)
        ellipse(d, (8.0, 11.0, 31.0, 24.0), fill=(183, 70, 58, 255), outline=(82, 39, 35, 225), width=0.7)
        for x, y, r in ((13, 15, 2.1), (23, 15, 1.7), (18, 19, 1.2), (27, 20, 1.0)):
            ellipse(d, (x - r, y - r, x + r, y + r), fill=(247, 222, 182, 255))
        ellipse(d, (10.0, 12.0, 20.0, 17.0), fill=(223, 112, 88, 160))
    elif variant == 1:
        # Fern / grass tuft.
        for x, h, lean in ((10, 20, -3), (15, 27, -1), (21, 24, 2), (27, 18, 4)):
            line(d, [(x, 35), (x + lean, 35 - h)], (54, 126, 62, 255), 1.4)
            for i in range(3):
                t = 0.35 + i * 0.2
                lx = x + lean * t
                ly = 35 - h * t
                line(d, [(lx, ly), (lx - 3.2, ly - 2.5)], (99, 173, 79, 235), 0.7)
                line(d, [(lx, ly), (lx + 3.4, ly - 2.0)], (78, 153, 70, 235), 0.7)
    elif variant == 2:
        # Foxglove flowers.
        line(d, [(18, 36), (17, 20), (19, 8)], (50, 112, 59, 255), 1.1)
        for x, y, color in ((15, 28, (212, 125, 172, 255)), (21, 24, (172, 112, 205, 255)), (16, 19, (232, 158, 187, 255)), (22, 14, (188, 127, 214, 255))):
            ellipse(d, (x - 3.0, y - 2.5, x + 2.2, y + 2.5), fill=color, outline=(96, 51, 88, 180), width=0.4)
        ellipse(d, (16.0, 7.0, 21.0, 12.0), fill=(231, 189, 98, 255))
    else:
        # Mossy stone with tiny sprout.
        ellipse(d, (5.0, 22.0, 30.0, 36.0), fill=(83, 105, 77, 255), outline=(36, 56, 39, 210), width=0.7)
        ellipse(d, (8.0, 23.0, 22.0, 30.0), fill=(110, 135, 94, 190))
        line(d, [(18, 23), (17, 14), (20, 7)], (53, 115, 58, 255), 1.0)
        ellipse(d, (14.0, 5.0, 19.0, 10.0), fill=(108, 179, 83, 255))
        ellipse(d, (19.0, 7.0, 24.0, 12.0), fill=(79, 152, 71, 255))
    return img


def neon_deco(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    if variant == 0:
        line(d, [(18, 36), (18, 21)], (53, 74, 92, 255), 1.5)
        rounded(d, (7.0, 8.0, 29.0, 23.0), 2.2, fill=(13, 27, 47, 255), outline=(67, 231, 249, 230), width=0.9)
        line(d, [(11, 15.5), (25, 15.5)], (246, 66, 198, 230), 1.0)
        line(d, [(11, 18.5), (21, 18.5)], (91, 239, 255, 200), 0.7)
    elif variant == 1:
        line(d, [(8, 36), (10, 24), (7, 13), (13, 8)], (68, 98, 122, 255), 1.2)
        for x, y in ((13, 8), (10, 24), (7, 13)):
            ellipse(d, (x - 1.5, y - 1.5, x + 1.5, y + 1.5), fill=(247, 73, 201, 220))
    elif variant == 2:
        rounded(d, (10.0, 12.0, 26.0, 35.0), 3.0, fill=(10, 24, 42, 255), outline=(59, 224, 246, 220), width=0.85)
        polygon(d, [(18, 16), (22, 23), (19, 23), (21, 30), (14, 22), (17.5, 22)], fill=(94, 242, 255, 235))
    else:
        line(d, [(18, 36), (18, 24)], (61, 86, 106, 255), 1.1)
        for y, color in ((20, (246, 69, 201, 220)), (14, (90, 239, 255, 220)), (8, (255, 236, 152, 220))):
            ellipse(d, (13.0, y - 4.0, 23.0, y + 4.0), fill=(16, 30, 50, 255), outline=color, width=0.8)
    return img


def wool_deco(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    if variant == 0:
        # Pom-pom on a yarn stem.
        line(d, [(18, 36), (18, 24)], (133, 83, 101, 255), 1.2)
        ellipse(d, (8.0, 7.0, 28.0, 27.0), fill=(249, 186, 207, 255), outline=(154, 82, 110, 200), width=0.7)
        for x, y in ((12, 12), (21, 10), (24, 19), (13, 21), (18, 15)):
            line(d, [(x - 2, y + 1), (x + 2, y - 1)], (255, 220, 232, 160), 0.55)
    elif variant == 1:
        # Button flower.
        line(d, [(18, 36), (18, 23)], (89, 141, 97, 255), 1.0)
        for angle in range(6):
            a = angle * math.tau / 6.0
            cx = 18 + math.cos(a) * 5.4
            cy = 16 + math.sin(a) * 5.4
            ellipse(d, (cx - 3.4, cy - 3.4, cx + 3.4, cy + 3.4), fill=(245, 216, 151, 255), outline=(153, 112, 62, 160), width=0.45)
        ellipse(d, (14.0, 12.0, 22.0, 20.0), fill=(210, 119, 151, 255), outline=(130, 65, 91, 210), width=0.6)
        for x, y in ((16.5, 14.5), (19.5, 14.5), (16.5, 17.5), (19.5, 17.5)):
            ellipse(d, (x - 0.55, y - 0.55, x + 0.55, y + 0.55), fill=(105, 54, 74, 230))
    elif variant == 2:
        ellipse(d, (8.0, 21.0, 28.0, 36.0), fill=(233, 160, 186, 255), outline=(135, 71, 97, 200), width=0.7)
        for i in range(3):
            line(d, [(11 + i * 2.2, 35), (25 - i * 1.2, 22 + i * 2.1)], (252, 207, 222, 140), 0.55)
        line(d, [(27, 36), (31, 27), (26, 20)], (142, 91, 108, 230), 0.8)
    else:
        # Stitched heart cushion.
        ellipse(d, (7.0, 9.0, 29.0, 31.0), fill=(236, 169, 191, 255), outline=(137, 71, 94, 200), width=0.7)
        polygon(d, [(17, 28), (10, 20), (10, 14), (14, 11), (18, 14), (22, 11), (26, 14), (26, 20)], fill=(223, 113, 148, 255), outline=(252, 222, 233, 190), width=0.55)
        line(d, [(18, 36), (18, 29)], (140, 81, 101, 230), 0.9)
    return img


def frost_deco(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    if variant == 0:
        for x, h, w in ((10, 24, 3.4), (18, 32, 4.2), (25, 18, 2.6)):
            polygon(d, [(x - w, 36), (x, 36 - h), (x + w, 36)], fill=(192, 236, 249, 235), outline=(239, 253, 255, 210), width=0.5)
            line(d, [(x, 36 - h + 2), (x, 33)], (245, 255, 255, 170), 0.45)
    elif variant == 1:
        ellipse(d, (7.0, 28.0, 29.0, 36.0), fill=(225, 248, 255, 255))
        for x, y, r in ((11, 26, 3), (18, 23, 4.2), (25, 27, 2.8)):
            ellipse(d, (x - r, y - r * 0.55, x + r, y + r * 0.7), fill=(242, 253, 255, 255))
        sparkle(d, 15.0, 18.0, 2.0, (255, 255, 255, 200))
    elif variant == 2:
        line(d, [(18, 36), (18, 16)], (157, 215, 235, 220), 1.2)
        for angle in range(6):
            a = angle * math.tau / 6.0
            line(d, [(18, 16), (18 + math.cos(a) * 8.0, 16 + math.sin(a) * 8.0)], (224, 250, 255, 220), 0.75)
        ellipse(d, (15.2, 13.2, 20.8, 18.8), fill=(126, 202, 230, 255))
    else:
        rounded(d, (8.0, 29.0, 28.0, 35.0), 2.2, fill=(210, 244, 254, 255), outline=(100, 172, 201, 170), width=0.5)
        for x, h in ((12.0, 9.0), (18.0, 14.0), (24.0, 7.0)):
            line(d, [(x, 31.0), (x + 1.0, 31.0 - h)], (132, 208, 233, 220), 1.0)
    return img


# ---------------------------------------------------------------------------
# Ground overlays


def ice_overlay(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    vertical_gradient(img, (212, 250, 255, 120), (63, 156, 198, 95))
    rounded(d, (0.5, 0.5, TILE - 0.5, TILE - 0.5), 2.0, fill=None, outline=(232, 253, 255, 100), width=0.6)
    line(d, [(0, 7.5), (TILE, 7.5)], (245, 255, 255, 125), 0.8)
    cracks = [
        [(4, 12), (11, 16), (14, 23), (22, 28), (31, 26)],
        [(7, 5), (13, 11), (18, 9), (24, 14), (30, 12)],
    ][variant]
    crack(d, cracks, (42, 117, 155, 105), 0.65)
    sparkle(d, 10.0, 19.0, 1.7, (255, 255, 255, 190))
    sparkle(d, 27.0, 10.0, 1.4, (255, 255, 255, 170))
    return img


def snow_overlay(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    # A soft drift aligned to the top of the cell.
    rect(d, (0, 0, TILE, 3.0), (255, 255, 255, 255))
    for cx in (2.0, 11.0, 20.0, 29.0, 38.0):
        ellipse(d, (cx - 5.2, 0.0, cx + 5.2, 9.2 + variant * 0.6), fill=(255, 255, 255, 245))
        ellipse(d, (cx - 3.5, 0.0, cx + 1.6, 5.5), fill=(255, 255, 255, 255))
    line(d, [(0, 8.0 + variant * 0.5), (TILE, 8.0 + variant * 0.5)], (184, 226, 240, 115), 0.75)
    for x, y, r in ((7, 13, 2.0), (18, 16, 1.5), (29, 12, 2.3)):
        ellipse(d, (x - r, y - r * 0.5, x + r, y + r * 0.7), fill=(245, 253, 255, 210))
    sparkle(d, 6.0, 12.0, 1.2, (227, 249, 255, 210))
    sparkle(d, 27.0, 17.0, 1.0, (227, 249, 255, 180))
    return img


def trampoline_overlay(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    rounded(d, (1.5, 1.0, TILE - 1.5, 13.0), 5.0, fill=(242, 158, 188, 255), outline=(137, 70, 96, 230), width=0.85)
    rounded(d, (4.0, 2.6, TILE - 4.0, 9.4), 3.2, fill=(251, 205, 222, 255), outline=(255, 239, 245, 190), width=0.5)
    for offset in (-1, 0, 1):
        line(d, [(4 + offset * 8, 9.2), (12 + offset * 8, 2.8)], (217, 122, 154, 150), 0.55)
    for x in (4.0, TILE - 4.0):
        ellipse(d, (x - 1.0, 5.0, x + 1.0, 7.0), fill=(193, 147, 72, 255), outline=(125, 91, 43, 200), width=0.35)
    for x in (8.0, 18.0, 28.0):
        line(d, [(x - 2.2, 13.0), (x - 1.0, 16.0), (x + 1.0, 13.5)], (137, 77, 95, 160), 0.55)
    if variant == 1:
        sparkle(d, 10.0, 25.0, 1.3, (255, 239, 246, 210))
        sparkle(d, 26.0, 29.0, 1.0, (255, 239, 246, 180))
    return img


# ---------------------------------------------------------------------------
# Theme definitions and generation


# ---------------------------------------------------------------------------
# Platine: dunkle Leiterplatte, leuchtende Cyan-Leiterbahnen, pinke Akzente.
# Passt zum Neon-Platinen-Hauptmenü.

PCB_BOARD = (7, 24, 28, 255)
PCB_BOARD_DARK = (4, 14, 18, 255)
PCB_TRACE = (64, 232, 214, 235)
PCB_TRACE_DIM = (40, 150, 142, 150)
PCB_GLOW = (150, 255, 240, 255)
PCB_PINK = (246, 92, 196, 235)
PCB_CHIP = (14, 18, 22, 255)
PCB_PIN = (176, 188, 194, 255)


def pcb_pad(d: ImageDraw.ImageDraw, x: float, y: float, r: float = 1.5, color=PCB_TRACE):
    ellipse(d, (x - r, y - r, x + r, y + r), fill=PCB_BOARD_DARK, outline=color, width=0.7)


def pcb_via(d: ImageDraw.ImageDraw, x: float, y: float, color=PCB_TRACE):
    ellipse(d, (x - 1.2, y - 1.2, x + 1.2, y + 1.2), fill=color)
    ellipse(d, (x - 0.45, y - 0.45, x + 0.45, y + 0.45), fill=PCB_BOARD_DARK)


def pcb_chip(d: ImageDraw.ImageDraw, x0: float, y0: float, x1: float, y1: float, pins: int = 3):
    step = (x1 - x0) / (pins + 1)
    for i in range(pins):
        px = x0 + step * (i + 1)
        rect(d, (px - 0.7, y0 - 1.6, px + 0.7, y0), PCB_PIN)
        rect(d, (px - 0.7, y1, px + 0.7, y1 + 1.6), PCB_PIN)
    rounded(d, (x0, y0, x1, y1), 0.6, fill=PCB_CHIP, outline=(40, 52, 58, 255), width=0.5)
    ellipse(d, (x0 + 1.0, y0 + 1.0, x0 + 2.2, y0 + 2.2), fill=(52, 64, 70, 255))


def platine_ground_top(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (9, 30, 34, 255), (4, 13, 17, 255))
    d = draw_of(img)
    # Leuchtende Kupferkante als Lauffläche.
    rect(d, (0, 0, TILE, 5.2), (5, 18, 22, 255))
    rect(d, (0, 0, TILE, 1.8), PCB_GLOW)
    rect(d, (0, 1.8, TILE, 4.2), (38, 196, 182, 255))
    line(d, [(0, 5.2), (TILE, 5.2)], (3, 10, 13, 255), 0.9)
    # Steckkontakt-Finger unter der Kante.
    for i in range(4):
        x = 2.5 + i * 9.0
        rounded(d, (x, 7.0, x + 4.6, 12.5), 0.8, fill=(214, 168, 72, 230), outline=(120, 88, 30, 255), width=0.4)
    if variant == 0:
        line(d, [(4.8, 12.5), (4.8, 20.0), (12.0, 27.0), (24.0, 27.0)], PCB_TRACE, 0.8)
        pcb_pad(d, 24.0, 27.0)
        line(d, [(31.0, 12.5), (31.0, 33.0)], PCB_TRACE_DIM, 0.6)
    elif variant == 1:
        line(d, [(13.8, 12.5), (13.8, 18.0), (20.0, 24.0), (20.0, 32.0)], PCB_TRACE, 0.8)
        pcb_via(d, 20.0, 32.0, PCB_PINK)
        line(d, [(22.8, 12.5), (22.8, 16.0), (30.0, 23.0), (TILE, 23.0)], PCB_TRACE_DIM, 0.6)
    else:
        pcb_chip(d, 8.0, 19.0, 26.0, 28.0, 4)
        line(d, [(31.8, 12.5), (31.8, 30.0), (28.0, 34.0)], PCB_TRACE, 0.7)
    add_noise(img, 910 + variant, [(64, 232, 214, 45), (246, 92, 196, 35), (120, 170, 170, 45)], 14, 3.0)
    return img


def platine_fill(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (7, 24, 28, 255), (4, 13, 17, 255))
    d = draw_of(img)
    if variant == 0:
        line(d, [(0, 9.0), (12.0, 9.0), (21.0, 18.0), (21.0, TILE)], PCB_TRACE_DIM, 0.7)
        line(d, [(0, 27.0), (8.0, 27.0)], PCB_TRACE_DIM, 0.6)
        pcb_via(d, 8.0, 27.0)
        line(d, [(30.0, 0), (30.0, 12.0), (TILE, 18.0)], (40, 150, 142, 110), 0.6)
    elif variant == 1:
        line(d, [(9.0, 0), (9.0, 14.0), (18.0, 23.0), (TILE, 23.0)], PCB_TRACE_DIM, 0.7)
        pcb_pad(d, 26.0, 9.0, 1.4, (246, 92, 196, 140))
        line(d, [(26.0, 10.4), (26.0, 16.0)], (246, 92, 196, 110), 0.55)
    else:
        line(d, [(0, 18.0), (TILE, 18.0)], PCB_TRACE_DIM, 0.6)
        line(d, [(18.0, 0), (18.0, 18.0)], PCB_TRACE_DIM, 0.6)
        pcb_via(d, 18.0, 18.0)
        for x, y in ((6.0, 30.0), (30.0, 30.0)):
            pcb_via(d, x, y, (40, 150, 142, 160))
    add_noise(img, 960 + variant, [(64, 232, 214, 30), (120, 170, 170, 35)], 12, 2.0)
    return img


def platine_platform(variant: int) -> Image.Image:
    img = canvas()
    vertical_gradient(img, (10, 34, 38, 255), (4, 13, 17, 255), 4, 36)
    d = draw_of(img)
    rect(d, (0, 0, TILE, 3.6), (5, 18, 22, 255))
    rect(d, (0, 0, TILE, 1.3), PCB_GLOW)
    line(d, [(0, 3.6), (TILE, 3.6)], (38, 196, 182, 230), 0.8)
    # Durchgehende Leiterbahn, damit lange Balken wie eine Bahn wirken.
    line(d, [(0, 12.0), (TILE, 12.0)], PCB_TRACE, 0.8)
    if variant == 0:
        pcb_pad(d, 9.0, 12.0)
        line(d, [(27.0, 12.0), (27.0, 22.0)], PCB_TRACE_DIM, 0.6)
        pcb_via(d, 27.0, 22.0, PCB_PINK)
    elif variant == 1:
        rect(d, (12.0, 17.0, 24.0, 22.0), (40, 30, 24, 255))
        for x in (14.0, 22.0):
            rect(d, (x - 1.2, 16.6, x + 1.2, 22.4), (196, 160, 80, 255))
        rect(d, (17.0, 17.0, 18.6, 22.0), PCB_PINK)
    else:
        pcb_chip(d, 6.0, 17.0, 20.0, 26.0, 3)
        pcb_via(d, 28.0, 21.0)
    line(d, [(0, 34.4), (TILE, 34.4)], (64, 232, 214, 70), 1.3)
    return img


def platine_destructible(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    # Ein Chip-Block mit Beinchen, der Risse bekommt.
    for i in range(4):
        x = 7.0 + i * 7.3
        rect(d, (x - 1.0, 1.0, x + 1.0, 4.0), PCB_PIN)
        rect(d, (x - 1.0, TILE - 4.0, x + 1.0, TILE - 1.0), PCB_PIN)
    rounded(d, (2.0, 4.0, TILE - 2.0, TILE - 4.0), 1.6, fill=PCB_CHIP, outline=(64, 232, 214, 200), width=0.8)
    ellipse(d, (4.5, 6.5, 7.0, 9.0), fill=(52, 64, 70, 255))
    line(d, [(9.0, 15.0), (27.0, 15.0)], (246, 92, 196, 200), 0.9)
    line(d, [(9.0, 19.5), (22.0, 19.5)], (64, 232, 214, 170), 0.7)
    crack(d, [(20, 5), (16, 12), (21, 18), (17, 26), (22, 31)] if variant == 0 else [(10, 5), (13, 13), (10, 21), (16, 27), (14, 31)], (210, 255, 248, 180), 0.7)
    return img


def platine_deco(variant: int) -> Image.Image:
    img = canvas()
    d = draw_of(img)
    if variant == 0:
        # Elektrolytkondensator
        line(d, [(15, 36), (15, 31)], PCB_PIN, 0.8)
        line(d, [(21, 36), (21, 31)], PCB_PIN, 0.8)
        rounded(d, (11.0, 14.0, 25.0, 31.5), 2.2, fill=(22, 52, 70, 255), outline=(64, 232, 214, 220), width=0.8)
        rect(d, (21.0, 14.5, 24.0, 31.0), (200, 220, 230, 160))
        ellipse(d, (11.0, 12.0, 25.0, 16.0), fill=(150, 170, 180, 255))
    elif variant == 1:
        # Leuchtdiode in Pink
        line(d, [(16, 36), (16, 26)], PCB_PIN, 0.8)
        line(d, [(20, 36), (20, 28)], PCB_PIN, 0.8)
        ellipse(d, (10.0, 9.0, 26.0, 25.0), fill=(246, 92, 196, 45))
        rounded(d, (13.0, 14.0, 23.0, 27.0), 4.5, fill=(246, 92, 196, 230), outline=(255, 190, 235, 255), width=0.6)
        ellipse(d, (15.0, 16.0, 18.0, 19.0), fill=(255, 235, 250, 230))
    elif variant == 2:
        # Widerstand, stehend
        line(d, [(18, 36), (18, 30)], PCB_PIN, 0.8)
        line(d, [(18, 16), (18, 10), (22, 10)], PCB_PIN, 0.8)
        rounded(d, (14.0, 16.0, 22.0, 30.0), 3.0, fill=(214, 190, 140, 255), outline=(120, 98, 60, 255), width=0.5)
        for y, c in ((19.0, (246, 92, 196, 255)), (22.5, (30, 30, 30, 255)), (26.0, (64, 232, 214, 255))):
            rect(d, (14.4, y, 21.6, y + 1.6), c)
    else:
        # Kleiner Chip mit Statuslicht
        pcb_chip(d, 9.0, 24.0, 27.0, 33.5, 4)
        ellipse(d, (22.0, 26.5, 25.0, 29.5), fill=(64, 232, 214, 255))
    return img



THEMES = {
    "storybook": {
        "ground_top": storybook_ground_top,
        "fill": storybook_fill,
        "platform": storybook_platform,
        "destructible": storybook_destructible,
        "deco": storybook_deco,
    },
    "neon": {
        "ground_top": neon_ground_top,
        "fill": neon_fill,
        "platform": neon_platform,
        "destructible": neon_destructible,
        "deco": neon_deco,
    },
    "wool": {
        "ground_top": wool_ground_top,
        "fill": wool_fill,
        "platform": wool_platform,
        "destructible": wool_destructible,
        "deco": wool_deco,
    },
    "frost": {
        "ground_top": frost_ground_top,
        "fill": frost_fill,
        "platform": frost_platform,
        "destructible": frost_destructible,
        "deco": frost_deco,
    },
    "platine": {
        "ground_top": platine_ground_top,
        "fill": platine_fill,
        "platform": platine_platform,
        "destructible": platine_destructible,
        "deco": platine_deco,
    },
}


def generate() -> None:
    for theme, makers in THEMES.items():
        for role, maker in makers.items():
            variants = 4 if role == "deco" else 3 if role in ("ground_top", "fill", "platform") else 2
            for i in range(variants):
                save(maker(i), theme, f"{role}_{i}.png")

    for i in range(2):
        save(vine_tile(True, i), "storybook", f"vine_strong_{i}.png")
        save(vine_tile(False, i), "storybook", f"vine_weak_{i}.png")
        save(ice_overlay(i), "frost", f"ice_{i}.png")
        save(snow_overlay(i), "frost", f"snow_{i}.png")
        save(trampoline_overlay(i), "wool", f"trampoline_{i}.png")

    print(f"Wrote themed tiles to {OUT}")


def contact_sheet() -> Path:
    roles = ["ground_top_0", "fill_0", "platform_0", "destructible_0", "deco_0"]
    extra = {"storybook": ["vine_strong_0", "vine_weak_0"], "neon": [], "wool": ["trampoline_0"], "frost": ["ice_0", "snow_0"], "platine": []}
    scale = 3
    cell = TILE * scale + 12
    sheet = Image.new("RGBA", (cell * 7 + 24, cell * len(THEMES) + 24), (9, 13, 21, 255))
    d = ImageDraw.Draw(sheet)
    for row, theme in enumerate(THEMES):
        names = list(roles) + extra.get(theme, [])
        for col, name in enumerate(names):
            path = OUT / theme / f"{name}.png"
            if not path.exists():
                continue
            art = Image.open(path).convert("RGBA")
            # Checkerboard behind transparency.
            bg = Image.new("RGBA", (TILE, TILE), (22, 28, 38, 255))
            checker = ImageDraw.Draw(bg)
            for y in range(0, TILE, 9):
                for x in range(0, TILE, 9):
                    if (x // 9 + y // 9) % 2 == 0:
                        checker.rectangle((x, y, x + 8, y + 8), fill=(32, 40, 52, 255))
            bg.alpha_composite(art)
            big = bg.resize((TILE * scale, TILE * scale), Image.Resampling.NEAREST)
            px = 12 + col * cell
            py = 12 + row * cell
            sheet.alpha_composite(big, (px, py))
            d.text((px, py + TILE * scale + 2), f"{theme}:{name}", fill=(210, 220, 232, 255))
    out = Path(tempfile.gettempdir()) / "battle_balls_tileset_preview.png"
    sheet.save(out)
    return out


if __name__ == "__main__":
    generate()
    if "--preview" in sys.argv:
        print("Preview:", contact_sheet())
