"""Konzeptgrafiken fuer den Lötkolbeneber-Hauptbildschirm (1600x900)."""
import math
import random
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1600, 900
SS = 2
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def rgba(c, a=1.0):
    return tuple(int(max(0, min(1, v)) * 255) for v in c[:3]) + (int(a * 255),)


def dark(c, f):
    return tuple(v * (1 - f) for v in c[:3])


def light(c, f):
    return tuple(v + (1 - v) * f for v in c[:3])


class Pen:
    """Zeichnet in lokalen Spielkoordinaten (wie Godot _draw)."""

    def __init__(self, img, origin, scale, flip=1.0, rot=0.0):
        self.img = img
        self.d = ImageDraw.Draw(img, "RGBA")
        self.o = origin
        self.s = scale
        self.flip = flip
        self.rot = rot

    def p(self, x, y):
        x *= self.flip
        c, s = math.cos(self.rot), math.sin(self.rot)
        x, y = x * c - y * s, x * s + y * c
        return ((self.o[0] + x * self.s) * SS, (self.o[1] + y * self.s) * SS)

    def poly(self, pts, fill, outline=None, width=0.0):
        P = [self.p(*q) for q in pts]
        self.d.polygon(P, fill=fill)
        if outline and width > 0:
            self.d.line(P + [P[0]], fill=outline, width=max(1, int(width * self.s * SS)), joint="curve")

    def ellipse(self, cx, cy, rx, ry, fill, outline=None, width=0.0, seg=36):
        pts = [(cx + math.cos(t) * rx, cy + math.sin(t) * ry) for t in [i * math.tau / seg for i in range(seg)]]
        self.poly(pts, fill, outline, width)

    def circle(self, cx, cy, r, fill):
        self.ellipse(cx, cy, r, r, fill)

    def line(self, a, b, col, width):
        self.d.line([self.p(*a), self.p(*b)], fill=col, width=max(1, int(width * self.s * SS)))
        r = width * self.s * SS / 2
        for q in (a, b):
            x, y = self.p(*q)
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=col)

    def rect(self, x, y, w, h, fill, outline=None, width=0.0):
        self.poly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)], fill, outline, width)


def draw_pig(img, pos, scale, fur, eyes, pants, flip=1.0, mood="happy"):
    pen = Pen(img, pos, scale, flip)
    outline = rgba(dark(fur, 0.42))
    fur_dark = rgba(dark(fur, 0.18))
    snout = light(fur, 0.32)
    snout = rgba(tuple(a + (b - a) * 0.34 for a, b in zip(snout, (1.0, 0.66, 0.72))))
    snout_out = rgba(dark(fur, 0.35))
    hoof = rgba((0.28, 0.2, 0.2))
    belt = rgba(dark(pants, 0.35))
    # Schwanz
    tail = [(-11.5 + math.cos(t) * 3.6, 0.5 + math.sin(t) * 3.6) for t in [math.pi * (-0.85 + i * 1.7 / 16) for i in range(17)]]
    for a, b in zip(tail, tail[1:]):
        pen.line(a, b, outline, 1.5)
    # Beine
    for lx in (-5.4, 5.4):
        pen.ellipse(lx, 12.2, 2.7, 4.1, fur_dark, outline, 0.7)
        pen.ellipse(lx, 15.4, 2.7, 1.7, hoof, outline, 0.6)
    pen.ellipse(0, 1.7, 10.7, 9.9, rgba(fur), outline, 1.2)
    pen.ellipse(0, -8.2, 10.6, 9.8, rgba(fur), outline, 1.2)
    # Hose
    pen.rect(-10.2, 4.3, 20.4, 8.0, rgba(pants), outline, 1.0)
    pen.rect(-9.5, 11.5, 8.3, 3.9, rgba(pants), outline, 1.0)
    pen.rect(1.2, 11.5, 8.3, 3.9, rgba(pants), outline, 1.0)
    pen.rect(-10.2, 4.0, 20.4, 2.7, belt, outline, 1.0)
    pen.rect(-1.7, 3.6, 3.4, 3.4, rgba((1.0, 0.8, 0.28)), outline, 0.7)
    # Ohren
    for d in (-1.0, 1.0):
        b = (7.9 * d, -14.5)
        pen.poly([(b[0] - 2.2 * d, b[1] + 1.6), (b[0] + 4.4 * d, b[1] - 4.2), (b[0] + 5.0 * d, b[1] + 2.7)], fur_dark, outline, 1.0)
        pen.poly([(b[0] - 0.8 * d, b[1] + 1.0), (b[0] + 3.2 * d, b[1] - 2.4), (b[0] + 3.5 * d, b[1] + 1.7)], snout)
    pen.poly([(-2.4, -16.9), (0.0, -20.4), (2.8, -16.7)], fur_dark)
    # Schutzbrille auf der Stirn (Werkstatt-Look)
    pen.rect(-8.5, -17.0, 17.0, 2.0, rgba((0.18, 0.18, 0.2)))
    for gx in (-4.0, 4.0):
        pen.ellipse(gx, -16.0, 3.0, 2.4, rgba((0.35, 0.75, 0.95, 0.85)), rgba((0.15, 0.15, 0.18)), 0.8)
    pen.ellipse(0, -4.7, 5.9, 3.9, snout, snout_out, 0.8)
    pen.circle(-2.0, -4.7, 0.85, snout_out)
    pen.circle(2.0, -4.7, 0.85, snout_out)
    for ex in (-4.2, 4.2):
        pen.ellipse(ex, -10.5, 2.35, 2.7, rgba((0.98, 0.96, 0.93)), outline, 0.6)
        pen.circle(ex + 0.15, -10.25, 1.45, rgba(eyes))
        pen.circle(ex + 0.2, -10.1, 0.72, rgba((0.05, 0.04, 0.06)))
        pen.circle(ex - 0.3, -10.8, 0.42, rgba((1, 1, 1)))
    if mood == "angry":
        pen.line((-6.6, -14.2), (-2.2, -12.6), outline, 0.9)
        pen.line((6.6, -14.2), (2.2, -12.6), outline, 0.9)
    tusk = rgba((0.98, 0.95, 0.82))
    pen.poly([(-5.3, -3.3), (-7.5, -1.6), (-5.0, -1.3)], tusk)
    pen.poly([(5.3, -3.3), (7.5, -1.6), (5.0, -1.3)], tusk)
    pen.circle(-7.8, -6.0, 1.9, rgba((1.0, 0.42, 0.52), 0.2))
    pen.circle(7.8, -6.0, 1.9, rgba((1.0, 0.42, 0.52), 0.2))


def draw_iron(img, pos, scale, angle, tip="cone", heat=(1.0, 0.55, 0.15), flip=1.0):
    """Lötkolben: Griff, Hitzeschutz-Hülse, Kupferspitze mit glühendem Ende."""
    pen = Pen(img, pos, scale, flip, angle)
    grip_out = rgba((0.07, 0.07, 0.09))
    grip = rgba((0.16, 0.17, 0.2))
    grip_hi = rgba((0.32, 0.34, 0.4))
    accent = rgba(heat)
    steel_out = rgba((0.2, 0.22, 0.26))
    steel = rgba((0.72, 0.75, 0.8))
    steel_hi = rgba((0.92, 0.94, 0.97))
    copper = rgba((0.78, 0.45, 0.22))
    # Kabel
    pen.line((-6.0, 0.0), (-9.0, 1.5), rgba((0.1, 0.1, 0.12)), 1.4)
    pen.line((-9.0, 1.5), (-11.0, 4.0), rgba((0.1, 0.1, 0.12)), 1.4)
    # Griff mit Rillen
    pen.poly([(-6.0, -2.0), (6.5, -2.6), (8.0, -1.8), (8.0, 1.8), (6.5, 2.6), (-6.0, 2.0)], grip, grip_out, 0.6)
    pen.line((-5.0, -1.0), (6.0, -1.5), grip_hi, 0.5)
    for x in (-3.0, -1.0, 1.0, 3.0):
        pen.line((x, -1.8), (x, 1.8), grip_out, 0.35)
    pen.rect(5.0, -2.6, 1.3, 5.2, accent)
    # Hülse
    pen.poly([(8.0, -1.3), (15.0, -0.9), (15.0, 0.9), (8.0, 1.3)], steel, steel_out, 0.4)
    pen.line((8.4, -0.6), (14.6, -0.4), steel_hi, 0.35)
    # Spitze
    if tip == "cone":
        pts = [(15.0, -0.9), (22.8, -0.15), (23.2, 0.0), (22.8, 0.15), (15.0, 0.9)]
    elif tip == "chisel":
        pts = [(15.0, -0.9), (21.0, -0.8), (23.0, -0.45), (23.0, 0.45), (21.0, 0.8), (15.0, 0.9)]
    elif tip == "knife":
        pts = [(15.0, -0.9), (19.0, -0.9), (23.5, 0.5), (19.0, 0.9), (15.0, 0.9)]
    else:  # hoof / bevel
        pts = [(15.0, -0.9), (20.5, -0.9), (22.8, -0.2), (21.8, 0.9), (15.0, 0.9)]
    pen.poly(pts, copper, rgba((0.35, 0.18, 0.08)), 0.35)
    # Glühende Spitze (vorderes Drittel)
    hot = [q for q in pts if q[0] > 19.5]
    if len(hot) >= 2:
        pen.poly([(19.5, -0.7)] + hot + [(19.5, 0.7)], rgba(light(heat, 0.25)))
    pen.circle(22.5, 0, 0.55, rgba(light(heat, 0.8)))
    return pen.p(23.2, 0.0)


def iron_glow(img, pos, scale, angle, tip, heat, flip=1.0, radius=40, alpha=0.8):
    t = draw_iron(img, pos, scale, angle, tip, heat=heat, flip=flip)
    glow(img, t, radius, heat, alpha)
    draw_iron(img, pos, scale, angle, tip, heat=heat, flip=flip)
    return t


def sparks(img, center, n, color, spread=120, seed=1):
    rnd = random.Random(seed)
    d = ImageDraw.Draw(img, "RGBA")
    cx, cy = center
    for _ in range(n):
        ang = rnd.uniform(0, math.tau)
        dist = rnd.uniform(6, spread) * SS
        x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist
        ln = rnd.uniform(4, 14) * SS
        d.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln)], fill=rgba(light(color, rnd.uniform(0.2, 0.8)), rnd.uniform(0.5, 1)), width=int(2 * SS))


def smoke(img, start, seed=3, n=7):
    layer = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(layer)
    rnd = random.Random(seed)
    x, y = start
    for i in range(n):
        r = (10 + i * 7) * SS
        x += rnd.uniform(-14, 10) * SS
        y -= 26 * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=max(10, 60 - i * 7))
    layer = layer.filter(ImageFilter.GaussianBlur(10 * SS))
    img.paste(Image.new("RGB", img.size, (220, 225, 235)), (0, 0), layer)


def glow(img, center, radius, color, alpha=0.5):
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    r = radius * SS
    d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=int(255 * alpha))
    mask = mask.filter(ImageFilter.GaussianBlur(radius * SS * 0.45))
    img.paste(Image.new("RGB", img.size, rgba(color)[:3]), (0, 0), mask)


def pcb_background(img, base, trace, seed=7, density=60, pad=None):
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 0, W * SS, H * SS], fill=rgba(base))
    rnd = random.Random(seed)
    pad = pad or light(trace, 0.3)
    for _ in range(density):
        x = rnd.randrange(0, W, 20) * SS
        y = rnd.randrange(0, H, 20) * SS
        pts = [(x, y)]
        for _ in range(rnd.randint(2, 5)):
            dx, dy = rnd.choice([(1, 0), (0, 1), (1, 1), (-1, 0), (0, -1), (1, -1)])
            ln = rnd.randint(2, 9) * 20 * SS
            x += dx * ln
            y += dy * ln
            pts.append((x, y))
        d.line(pts, fill=rgba(trace, 0.55), width=int(3 * SS), joint="curve")
        for q in (pts[0], pts[-1]):
            r = 6 * SS
            d.ellipse([q[0] - r, q[1] - r, q[0] + r, q[1] + r], fill=rgba(pad, 0.7))
            r2 = 2.5 * SS
            d.ellipse([q[0] - r2, q[1] - r2, q[0] + r2, q[1] + r2], fill=rgba(base))
    # Bauteile
    for _ in range(14):
        x = rnd.randrange(0, W) * SS
        y = rnd.randrange(0, H) * SS
        w = rnd.randint(40, 110) * SS
        h = rnd.randint(24, 60) * SS
        d.rounded_rectangle([x, y, x + w, y + h], radius=4 * SS, fill=rgba(dark(base, 0.55), 0.85))
        for px in range(int(x + 8 * SS), int(x + w - 4 * SS), int(12 * SS)):
            d.rectangle([px, y - 6 * SS, px + 4 * SS, y], fill=rgba((0.75, 0.75, 0.7), 0.6))
            d.rectangle([px, y + h, px + 4 * SS, y + h + 6 * SS], fill=rgba((0.75, 0.75, 0.7), 0.6))


def vignette(img, strength=0.65):
    layer = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(layer)
    for i in range(40):
        t = i / 40
        d.ellipse([-W * 0.3 + t * W * 0.3, -H * 0.3 + t * H * 0.3, W * 1.3 - t * W * 0.3, H * 1.3 - t * H * 0.3], fill=int(255 * t))
    layer = layer.filter(ImageFilter.GaussianBlur(60)).resize(img.size)
    inv = Image.eval(layer, lambda v: int((255 - v) * strength))
    img.paste(Image.new("RGB", img.size, (0, 0, 0)), (0, 0), inv)


def text(img, xy, s, size, fill, font=FONT_BOLD, anchor="la", stroke=0, stroke_fill=None, shadow=None):
    d = ImageDraw.Draw(img, "RGBA")
    f = ImageFont.truetype(font, int(size * SS))
    x, y = xy[0] * SS, xy[1] * SS
    if shadow:
        d.text((x + shadow[0] * SS, y + shadow[1] * SS), s, font=f, fill=shadow[2], anchor=anchor, stroke_width=int(stroke * SS), stroke_fill=shadow[2])
    d.text((x, y), s, font=f, fill=fill, anchor=anchor, stroke_width=int(stroke * SS), stroke_fill=stroke_fill)


def button(img, x, y, w, h, label, primary=False, accent=(1.0, 0.55, 0.15), style="plate"):
    d = ImageDraw.Draw(img, "RGBA")
    X, Y, Wd, Hd = x * SS, y * SS, w * SS, h * SS
    if style == "plate":
        fill = rgba(accent) if primary else rgba((0.13, 0.15, 0.19), 0.92)
        d.rounded_rectangle([X, Y + 5 * SS, X + Wd, Y + Hd + 5 * SS], radius=10 * SS, fill=rgba(dark(accent, 0.55) if primary else (0.04, 0.05, 0.07)))
        d.rounded_rectangle([X, Y, X + Wd, Y + Hd], radius=10 * SS, fill=fill, outline=rgba(light(accent, 0.2) if primary else (0.3, 0.33, 0.4)), width=int(2 * SS))
        for sx in (X + 12 * SS, X + Wd - 12 * SS):
            r = 3.5 * SS
            d.ellipse([sx - r, Y + Hd / 2 - r, sx + r, Y + Hd / 2 + r], fill=rgba((0.6, 0.62, 0.66) if not primary else dark(accent, 0.4)))
        col = rgba((0.08, 0.06, 0.04)) if primary else rgba((0.9, 0.92, 0.96))
    elif style == "neon":
        d.rounded_rectangle([X, Y, X + Wd, Y + Hd], radius=6 * SS, fill=rgba((0.02, 0.05, 0.06), 0.8), outline=rgba(accent, 1.0 if primary else 0.55), width=int((3 if primary else 2) * SS))
        col = rgba(light(accent, 0.3)) if primary else rgba((0.75, 0.9, 0.9))
    else:  # tag
        d.rounded_rectangle([X, Y, X + Wd, Y + Hd], radius=Hd / 2, fill=rgba(accent) if primary else rgba((1, 1, 1), 0.1), outline=rgba((1, 1, 1), 0.25), width=int(2 * SS))
        col = rgba((0.1, 0.07, 0.05)) if primary else rgba((0.95, 0.95, 0.97))
    text(img, (x + w / 2, y + h / 2), label, 22 if primary else 19, col, anchor="mm")


def finish(img, name):
    out = img.resize((W, H), Image.LANCZOS).convert("RGB")
    out.save(OUT / name, optimize=True)
    return out


PIG_PINK = (0.91, 0.6, 0.67)
PIG_BROWN = (0.62, 0.42, 0.3)
PIG_GREY = (0.6, 0.62, 0.68)


def concept_a():
    """Werkstatt: Platine als Hintergrund, Menü links, großer Eber rechts."""
    img = Image.new("RGB", (W * SS, H * SS))
    pcb_background(img, (0.04, 0.17, 0.12), (0.75, 0.6, 0.25), seed=11)
    vignette(img, 0.55)
    # Werkbank-Kante unten
    d = ImageDraw.Draw(img, "RGBA")
    d.rectangle([0, 760 * SS, W * SS, H * SS], fill=rgba((0.2, 0.13, 0.08)))
    d.rectangle([0, 760 * SS, W * SS, 772 * SS], fill=rgba((0.38, 0.25, 0.14)))
    glow(img, (1120 * SS, 470 * SS), 330, (1.0, 0.5, 0.15), 0.22)
    draw_pig(img, (1120, 560), 13.5, PIG_PINK, (0.18, 0.14, 0.2), (0.24, 0.36, 0.56), flip=-1.0)
    tip = iron_glow(img, (1040, 600), 9.0, math.radians(-38), "cone", (1.0, 0.55, 0.15), -1.0, 50, 0.8)
    sparks(img, tip, 26, (1.0, 0.65, 0.2), 70, seed=4)
    smoke(img, (tip[0] / SS, tip[1] / SS))
    # Titel
    text(img, (110, 150), "LÖTKOLBEN", 92, rgba((1.0, 0.62, 0.18)), stroke=3, stroke_fill=rgba((0.25, 0.12, 0.03)), shadow=(0, 7, rgba((0, 0, 0), 0.6)))
    text(img, (110, 250), "EBER", 120, rgba((1.0, 0.86, 0.55)), stroke=3, stroke_fill=rgba((0.25, 0.12, 0.03)), shadow=(0, 8, rgba((0, 0, 0), 0.6)))
    d.line([110 * SS, 400 * SS, 560 * SS, 400 * SS], fill=rgba((0.75, 0.6, 0.25), 0.7), width=int(3 * SS))
    for i, (lbl, prim) in enumerate([("SPIEL STARTEN", True), ("ONLINE", False), ("HELDEN", False), ("OPTIONEN", False), ("BEENDEN", False)]):
        button(img, 110, 430 + i * 64, 360, 52, lbl, prim)
    text(img, (1580, 880), "Build 26.10.2026 · 6d31757", 13, rgba((0.6, 0.66, 0.78), 0.9), font=FONT, anchor="rs")
    return finish(img, "konzept_a_werkstatt.png")


def concept_b():
    """Arena-Duell: Titel mittig, zwei Eber kreuzen die Lötkolben, Buttons als Leiste."""
    img = Image.new("RGB", (W * SS, H * SS))
    d = ImageDraw.Draw(img, "RGBA")
    for y in range(H):
        t = y / H
        c = tuple(a + (b - a) * t for a, b in zip((0.09, 0.07, 0.2), (0.35, 0.12, 0.2)))
        d.rectangle([0, y * SS, W * SS, (y + 1) * SS], fill=rgba(c))
    # Hügel / Plattformen wie im Spiel
    d.polygon([(0, 700 * SS), (300 * SS, 640 * SS), (650 * SS, 690 * SS), (1000 * SS, 630 * SS), (1350 * SS, 680 * SS), (W * SS, 640 * SS), (W * SS, H * SS), (0, H * SS)], fill=rgba((0.14, 0.32, 0.22)))
    d.rectangle([0, 760 * SS, W * SS, H * SS], fill=rgba((0.1, 0.18, 0.14)))
    for px, py, pw in ((180, 560, 220), (1200, 540, 240)):
        d.rounded_rectangle([px * SS, py * SS, (px + pw) * SS, (py + 26) * SS], radius=6 * SS, fill=rgba((0.55, 0.36, 0.2)), outline=rgba((0.3, 0.18, 0.1)), width=int(3 * SS))
        d.rectangle([px * SS, py * SS, (px + pw) * SS, (py + 8) * SS], fill=rgba((0.35, 0.7, 0.3)))
    glow(img, (800 * SS, 470 * SS), 260, (1.0, 0.75, 0.3), 0.3)
    draw_pig(img, (560, 520), 10.5, PIG_PINK, (0.18, 0.14, 0.2), (0.7, 0.2, 0.2), mood="angry")
    t1 = draw_iron(img, (610, 530), 8.0, math.radians(-25), "chisel", heat=(1.0, 0.45, 0.1))
    draw_pig(img, (1040, 520), 10.5, PIG_BROWN, (0.15, 0.3, 0.2), (0.2, 0.4, 0.7), flip=-1.0, mood="angry")
    t2 = draw_iron(img, (990, 530), 8.0, math.radians(-25), "knife", heat=(0.35, 0.8, 1.0), flip=-1.0)
    mid = ((t1[0] + t2[0]) / 2, (t1[1] + t2[1]) / 2)
    glow(img, mid, 70, (1.0, 0.9, 0.6), 0.6)
    draw_iron(img, (610, 530), 8.0, math.radians(-25), "chisel", heat=(1.0, 0.45, 0.1))
    draw_iron(img, (990, 530), 8.0, math.radians(-25), "knife", heat=(0.35, 0.8, 1.0), flip=-1.0)
    sparks(img, mid, 46, (1.0, 0.8, 0.3), 110, seed=9)
    text(img, (800, 135), "LÖTKOLBENEBER", 104, rgba((1.0, 0.93, 0.75)), anchor="mm", stroke=5, stroke_fill=rgba((0.35, 0.1, 0.12)), shadow=(0, 9, rgba((0.05, 0.0, 0.08), 0.7)))
    labels = [("ONLINE", False), ("HELDEN", False), ("SPIEL STARTEN", True), ("OPTIONEN", False), ("BEENDEN", False)]
    widths = [200, 200, 300, 200, 200]
    total = sum(widths) + 20 * 4
    x = (W - total) / 2
    for (lbl, prim), w in zip(labels, widths):
        button(img, x, 792, w, 58 if prim else 50, lbl, prim, accent=(1.0, 0.72, 0.25), style="tag")
        x += w + 20
    text(img, (1580, 890), "Build 26.10.2026 · 6d31757", 13, rgba((0.75, 0.75, 0.85), 0.9), font=FONT, anchor="rs")
    return finish(img, "konzept_b_arena_duell.png")


def concept_c():
    """Neon-Platine: dunkles Board, leuchtende Leiterbahnen, Menü zentriert, Eber-Trio."""
    img = Image.new("RGB", (W * SS, H * SS))
    pcb_background(img, (0.02, 0.03, 0.06), (0.1, 0.85, 0.8), seed=23, density=80, pad=(0.5, 1.0, 0.95))
    from PIL import ImageChops
    layer = img.filter(ImageFilter.GaussianBlur(6 * SS))
    img.paste(Image.blend(img, ImageChops.lighter(img, ImageChops.add(layer, layer)), 0.6))
    vignette(img, 0.75)
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle([560 * SS, 300 * SS, 1040 * SS, 790 * SS], radius=18 * SS, fill=rgba((0.02, 0.04, 0.07), 0.85), outline=rgba((0.1, 0.85, 0.8), 0.7), width=int(2 * SS))
    glow(img, (800 * SS, 160 * SS), 380, (0.1, 0.85, 0.8), 0.18)
    text(img, (800, 160), "LÖTKOLBENEBER", 96, rgba((0.75, 1.0, 0.97)), anchor="mm", shadow=(0, 0, rgba((0.1, 0.85, 0.8), 0.6)))
    text(img, (800, 240), "· 2–6 SCHWEINE · EINE PLATINE ·", 18, rgba((1.0, 0.45, 0.75), 0.9), font=FONT, anchor="mm")
    for i, (lbl, prim) in enumerate([("SPIEL STARTEN", True), ("ONLINE", False), ("HELDEN", False), ("OPTIONEN", False), ("BEENDEN", False)]):
        button(img, 620, 340 + i * 86, 360, 60, lbl, prim, accent=(1.0, 0.35, 0.7) if prim else (0.1, 0.85, 0.8), style="neon")
    for (x, fur, pants, heat, tipk, fl) in ((260, PIG_PINK, (0.5, 0.2, 0.6), (1.0, 0.35, 0.7), "hoof", 1.0), (1340, PIG_GREY, (0.15, 0.4, 0.4), (0.1, 0.9, 0.8), "cone", -1.0)):
        draw_pig(img, (x, 610), 9.0, fur, (0.12, 0.12, 0.15), pants, flip=fl)
        t = iron_glow(img, (x + 40 * fl, 625), 7.0, math.radians(-70), tipk, heat, fl, 40, 0.9)
        sparks(img, t, 14, heat, 50, seed=int(x))
    text(img, (1580, 880), "Build 26.10.2026 · 6d31757", 13, rgba((0.5, 0.8, 0.8), 0.8), font=FONT, anchor="rs")
    return finish(img, "konzept_c_neon_platine.png")


def iron_sheet():
    """Lötkolben-Spitzen im Vergleich (Spielmaßstab x8)."""
    img = Image.new("RGB", (W * SS, 360 * SS), rgba((0.08, 0.09, 0.12))[:3])
    names = [("cone", "Kegel"), ("chisel", "Meißel"), ("knife", "Messer"), ("hoof", "Huf")]
    heats = [(1.0, 0.55, 0.15), (0.35, 0.8, 1.0), (0.6, 1.0, 0.4), (1.0, 0.35, 0.7)]
    for i, ((k, label), heat) in enumerate(zip(names, heats)):
        cx = 60 + i * 390
        iron_glow(img, (cx + 130, 170), 9.0, 0.0, k, heat, 1.0, 30, 0.75)
        text(img, (cx + 190, 300), label, 26, rgba((0.9, 0.92, 0.96)), anchor="mm")
    out = img.resize((W, 360), Image.LANCZOS).convert("RGB")
    out.save(OUT / "loetkolben_spitzen.png", optimize=True)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    a, b, c = concept_a(), concept_b(), concept_c()
    iron_sheet()
    ov = Image.new("RGB", (W, H), (12, 13, 18))
    for i, im in enumerate((a, b, c)):
        t = im.resize((W // 2 - 30, H // 2 - 30))
        pos = [(20, 20), (W // 2 + 10, 20), (W // 4 + 15, H // 2 + 10)][i]
        ov.paste(t, pos)
    ov.save(OUT / "00_uebersicht.png", optimize=True)
    print("ok")
