from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parent
W, H = 1600, 1000
TILE = 28
COLS, ROWS = 44, 25
SCENE_W, SCENE_H = COLS * TILE, ROWS * TILE
SCENE_X, SCENE_Y = (W - SCENE_W) // 2, 130
GROUND = 22
PLATFORMS = [
    (3, 18, 7), (10, 13, 5), (18, 16, 8),
    (29, 12, 5), (35, 18, 7), (20, 7, 4),
]
P1_X, P2_X = 6.7, 23.4

FONT_REG = "C:/Windows/Fonts/segoeui.ttf"
FONT_BOLD = "C:/Windows/Fonts/segoeuib.ttf"
FONT_MONO = "C:/Windows/Fonts/consolab.ttf"


def font(size, bold=False, mono=False):
    return ImageFont.truetype(FONT_MONO if mono else (FONT_BOLD if bold else FONT_REG), size)


def text(d, xy, value, size=18, fill="white", bold=False, mono=False, anchor="la"):
    d.text(xy, value, font=font(size, bold, mono), fill=fill, anchor=anchor)


def vgrad(size, top, bottom):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img.convert("RGBA")


def bx(x, y, w, h, s):
    return [int(x * TILE * s), int(y * TILE * s),
            int((x + w) * TILE * s), int((y + h) * TILE * s)]


def px(v, s):
    return int(v * s)


def pxy(x, y, s):
    return int(x * s), int(y * s)


def poly(d, pts, s, fill=None, outline=None, width=1):
    d.polygon([(int(x * s), int(y * s)) for x, y in pts], fill=fill, outline=outline, width=max(1, int(width * s)))


def line(d, pts, s, fill, width=1):
    d.line([(int(x * s), int(y * s)) for x, y in pts], fill=fill, width=max(1, int(width * s)))


def ellipse(d, box, s, fill=None, outline=None, width=1):
    d.ellipse([int(box[0] * s), int(box[1] * s), int(box[2] * s), int(box[3] * s)],
              fill=fill, outline=outline, width=max(1, int(width * s)))


def rect(d, box, s, fill=None, outline=None, width=1, radius=0):
    b = [int(box[0] * s), int(box[1] * s), int(box[2] * s), int(box[3] * s)]
    if radius:
        d.rounded_rectangle(b, radius=int(radius * s), fill=fill, outline=outline, width=max(1, int(width * s)))
    else:
        d.rectangle(b, fill=fill, outline=outline, width=max(1, int(width * s)))


def shadow(scene, box, s, radius=18, blur=12, alpha=70):
    layer = Image.new("RGBA", scene.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([int(box[0] * s), int(box[1] * s), int(box[2] * s), int(box[3] * s)],
                        radius=int(radius * s), fill=(8, 12, 22, alpha))
    layer = layer.filter(ImageFilter.GaussianBlur(int(blur * s)))
    return Image.alpha_composite(scene, layer)


def save_sheet(index, title, kicker, scene, colors, note, filename):
    sheet = vgrad((W, H), (10, 16, 27), (5, 8, 15))
    sd = ImageDraw.Draw(sheet)
    text(sd, (72, 30), kicker.upper(), 13, (112, 210, 224), True, True)
    text(sd, (72, 56), title, 46, (246, 248, 252), True)
    text(sd, (74, 106), "BATTLE BALLS  /  TILESET-RICHTUNG", 11, (126, 142, 162), True, True)
    text(sd, (W - 72, 66), note, 16, (176, 190, 206), False, False, "ra")

    frame = [SCENE_X - 7, SCENE_Y - 7, SCENE_X + SCENE_W + 7, SCENE_Y + SCENE_H + 7]
    sd.rounded_rectangle(frame, radius=7, fill=(15, 23, 37), outline=(57, 74, 96), width=2)
    sheet.paste(scene.convert("RGB"), (SCENE_X, SCENE_Y))
    sd.rectangle([SCENE_X, SCENE_Y, SCENE_X + SCENE_W, SCENE_Y + SCENE_H], outline=(38, 50, 66), width=1)

    text(sd, (72, 866), "MATERIAL & FARBEN", 12, (137, 156, 178), True, True)
    labels = {
        1: ["HIMMEL", "ERDE", "GRAS", "PLATTFORM", "AKZENT", "INK"],
        2: ["HIMMEL", "ERDE", "MOOS", "PLATTFORM", "AKZENT", "INK"],
        3: ["NACHT", "STAHL", "NEON", "PLATTE", "MAGENTA", "WEISS"],
        4: ["PAPIER", "ERDE", "TEAL", "SONNE", "KORALLE", "INK"],
    }[index]
    for i, (label, color) in enumerate(zip(labels, colors)):
        x = 72 + i * 148
        sd.rounded_rectangle([x, 892, x + 124, 950], radius=7, fill=color, outline=(255, 255, 255, 30))
        text(sd, (x, 958), label, 10, (120, 135, 154), True, True)
    text(sd, (1010, 890), "STYLE-NOTIZ", 11, (112, 210, 224), True, True)
    text(sd, (1010, 912), note, 16, (226, 232, 240))
    text(sd, (1010, 942), note2_lookup(index), 13, (139, 154, 173))

    out = ROOT / filename
    sheet.save(out)
    print("wrote", out)


def note2_lookup(index):
    return {
        1: "Lesbarkeit: hoch  ·  Produktionsaufwand: niedrig  ·  Alle Maps: ja",
        2: "Lesbarkeit: mittel  ·  Produktionsaufwand: hoch  ·  Alle Maps: ja",
        3: "Lesbarkeit: hoch  ·  Produktionsaufwand: mittel  ·  Alle Maps: nein",
        4: "Lesbarkeit: sehr hoch  ·  Produktionsaufwand: niedrig  ·  Alle Maps: ja",
    }[index]


def arc_points(x1, y1, x2, y2, count, lift):
    pts = []
    for i in range(count):
        t = i / max(1, count - 1)
        x = x1 + (x2 - x1) * t
        y = y1 + (y2 - y1) * t - math.sin(math.pi * t) * lift
        pts.append((x, y))
    return pts


def pixel_cloud(d, cx, cy, scale, fill, shade):
    blocks = [(-2.2, 0.0, 1.1, 0.55), (-1.4, -0.35, 1.2, 0.8),
              (0.0, -0.55, 1.4, 1.0), (1.2, -0.2, 1.1, 0.7),
              (2.0, 0.05, 0.8, 0.45)]
    for bx0, by0, bw, bh in blocks:
        x0 = int(cx + bx0 * scale)
        y0 = int(cy + by0 * scale)
        x1 = int(cx + (bx0 + bw) * scale)
        y1 = int(cy + (by0 + bh) * scale)
        d.rectangle([x0, y0, x1, y1], fill=fill)
    d.rectangle([int(cx - 2.1 * scale), int(cy + 0.45 * scale),
                 int(cx + 2.8 * scale), int(cy + 0.62 * scale)], fill=shade)


def meadow_platform(d, x, y, w, vine=False):
    T = TILE
    body = [x * T, y * T, (x + w) * T, (y + 1.0) * T]
    d.rounded_rectangle([int(body[0]), int(body[1] + 8), int(body[2]), int(body[3] + 10)],
                        radius=5, fill=(70, 139, 91, 80))
    d.rectangle([int(body[0]), int(body[1]), int(body[2]), int(body[3])],
                fill=(151, 88, 52), outline=(28, 51, 69), width=3)
    d.rectangle([int(body[0] + 2), int(body[1] + 10), int(body[2] - 2), int(body[3] - 2)],
                fill=(188, 111, 62))
    d.rectangle([int(body[0]), int(body[1]), int(body[2]), int(body[1] + 9)], fill=(58, 186, 80))
    d.rectangle([int(body[0]), int(body[1]), int(body[2]), int(body[1] + 4)], fill=(139, 240, 116))
    d.line([int(body[0]), int(body[1]), int(body[2]), int(body[1])], fill=(21, 62, 47), width=2)
    for tx in range(int(x) + 1, int(x + w)):
        d.line([tx * T, int(body[1] + 12), tx * T, int(body[3] - 2)], fill=(157, 88, 53), width=1)
    if vine:
        vx = int((x + w * 0.72) * T)
        d.line([vx, int(body[3]), vx, int(body[3] + 34)], fill=(40, 130, 73), width=3)
        for vy in (body[3] + 12, body[3] + 27):
            d.rectangle([vx - 6, int(vy), vx, int(vy + 5)], fill=(87, 200, 93))
            d.rectangle([vx + 1, int(vy + 5), vx + 7, int(vy + 10)], fill=(87, 200, 93))


def meadow_ground(d):
    T = TILE
    top = GROUND * T
    d.rectangle([0, top, SCENE_W, SCENE_H], fill=(128, 77, 49))
    d.rectangle([0, top + 12, SCENE_W, SCENE_H], fill=(178, 103, 60))
    d.rectangle([0, top + 54, SCENE_W, SCENE_H], fill=(151, 85, 51))
    d.rectangle([0, top, SCENE_W, top + 10], fill=(42, 154, 66))
    d.rectangle([0, top, SCENE_W, top + 4], fill=(119, 231, 103))
    d.line([0, top, SCENE_W, top], fill=(20, 57, 44), width=2)
    for tx in range(0, COLS + 1):
        x = tx * T
        d.line([x, top + 10, x, SCENE_H], fill=(155, 88, 53), width=1)
    for layer_y in (top + 30, top + 58):
        d.line([0, layer_y, SCENE_W, layer_y], fill=(145, 81, 48), width=1)
    random.seed(7)
    for _ in range(90):
        x = random.randrange(0, SCENE_W)
        y = random.randrange(top + 14, SCENE_H - 2)
        c = random.choice([(197, 122, 70), (113, 66, 43), (208, 140, 79)])
        d.rectangle([x, y, x + random.choice([2, 3, 4]), y + 2], fill=c)
    for tx in range(1, COLS, 3):
        x = tx * T + 8
        d.line([x, top, x - 5, top - 9], fill=(35, 127, 57), width=2)
        d.line([x + 2, top, x + 7, top - 7], fill=(35, 127, 57), width=2)
        d.line([x, top, x, top - 12], fill=(69, 188, 82), width=2)
    for lx in (0, 40):
        x0 = lx * T
        x1 = (lx + 4) * T
        top2 = 20 * T
        d.rectangle([x0, top2, x1, top], fill=(178, 103, 60), outline=(28, 51, 69), width=3)
        d.rectangle([x0, top2, x1, top2 + 9], fill=(58, 186, 80))
        d.rectangle([x0, top2, x1, top2 + 4], fill=(139, 240, 116))
        d.line([x0, top2, x1, top2], fill=(21, 62, 47), width=2)


def meadow_crate(d, cx, bottom, size=1.55):
    T = TILE
    x0 = cx * T - size * T / 2
    y0 = bottom * T - size * T
    box = [x0, y0, x0 + size * T, bottom * T]
    d.rectangle(box, fill=(203, 139, 77), outline=(49, 43, 45), width=3)
    d.rectangle([box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6], outline=(142, 88, 49), width=2)
    d.line([box[0] + 6, box[1] + 6, box[2] - 6, box[3] - 6], fill=(167, 105, 57), width=3)
    d.line([box[2] - 6, box[1] + 6, box[0] + 6, box[3] - 6], fill=(167, 105, 57), width=3)
    for px_, py_ in ((box[0] + 5, box[1] + 5), (box[2] - 5, box[1] + 5),
                     (box[0] + 5, box[3] - 5), (box[2] - 5, box[3] - 5)):
        d.ellipse([px_ - 2, py_ - 2, px_ + 2, py_ + 2], fill=(77, 57, 48))


def meadow_barrel(d, cx, bottom):
    T = TILE
    w = 1.15 * T
    h = 1.3 * T
    x0 = cx * T - w / 2
    y0 = bottom * T - h
    d.rounded_rectangle([x0, y0, x0 + w, bottom * T], radius=8,
                        fill=(174, 94, 54), outline=(49, 43, 45), width=3)
    d.ellipse([x0, y0 - 5, x0 + w, y0 + 9], fill=(207, 128, 65), outline=(49, 43, 45), width=2)
    for yy in (y0 + 14, bottom * T - 18):
        d.rectangle([x0 + 1, yy, x0 + w - 1, yy + 6], fill=(81, 62, 55))
        d.rectangle([x0 + 2, yy + 1, x0 + w - 2, yy + 3], fill=(169, 113, 67))


def meadow_block(d, cx, bottom):
    T = TILE
    size = 1.15 * T
    x0 = cx * T - size / 2
    y0 = bottom * T - size
    d.rectangle([x0, y0, x0 + size, bottom * T], fill=(255, 199, 60), outline=(57, 43, 47), width=3)
    d.rectangle([x0 + 5, y0 + 5, x0 + size - 5, y0 + 12], fill=(255, 232, 118))
    text(d, (x0 + size / 2, y0 + size / 2 + 1), "?", 25, (72, 48, 45), True, True, "mm")


def pig_meadow(d, cx, feet, body, dark, accent, facing=1):
    T = TILE
    cx *= T
    feet *= T
    bw, bh = 1.28 * T, 1.22 * T
    left, right = cx - bw / 2, cx + bw / 2
    top = feet - bh - 5
    d.ellipse([left + 5, feet - 9, right - 5, feet + 2], fill=(30, 80, 55, 70))
    for lx in (-0.33, 0.33):
        x = cx + lx * T - 4
        d.rectangle([x, feet - 13, x + 8, feet], fill=dark, outline=(25, 37, 48), width=1)
    d.ellipse([left, top, right, feet - 7], fill=body, outline=(34, 44, 55), width=3)
    d.ellipse([left + 7, top + 8, left + bw * 0.55, top + bh * 0.55], fill=(255, 255, 255, 48))
    ear_y = top + 3
    d.polygon([(left + 8, ear_y + 14), (left + 12, ear_y - 7), (left + 25, ear_y + 7)],
              fill=body, outline=(34, 44, 55))
    d.polygon([(right - 8, ear_y + 14), (right - 12, ear_y - 7), (right - 25, ear_y + 7)],
              fill=body, outline=(34, 44, 55))
    sx = cx + facing * 0.23 * T
    d.ellipse([sx - 10, top + bh * 0.48, sx + 10, top + bh * 0.48 + 15],
              fill=(255, 164, 157), outline=(83, 51, 58), width=2)
    d.ellipse([sx - 5, top + bh * 0.52, sx - 2, top + bh * 0.52 + 4], fill=(91, 53, 59))
    d.ellipse([sx + 2, top + bh * 0.52, sx + 5, top + bh * 0.52 + 4], fill=(91, 53, 59))
    ex = cx + facing * 0.42 * T
    d.ellipse([ex - 5, top + 20, ex - 1, top + 24], fill=(24, 30, 38))
    d.rectangle([ex - 9, top + 31, ex + 1, top + 35], fill=accent)
    w0 = (cx + facing * 0.5 * T, top + bh * 0.62)
    w1 = (cx + facing * 0.78 * T, top + bh * 0.15)
    d.line([w0[0], w0[1], w1[0], w1[1]], fill=(69, 54, 53), width=4)
    d.line([w0[0], w0[1], w1[0], w1[1]], fill=(246, 224, 179), width=2)
    d.polygon([(w1[0], w1[1] - 8), (w1[0] + 7, w1[1]),
               (w1[0], w1[1] + 8), (w1[0] - 7, w1[1])], fill=accent, outline=(42, 43, 53))


def scene_meadow():
    S = 1
    T = TILE
    img = vgrad((SCENE_W, SCENE_H), (98, 208, 255), (226, 248, 255))
    d = ImageDraw.Draw(img)
    d.ellipse([31.5 * T, 1.6 * T, 39.2 * T, 9.3 * T], fill=(255, 229, 132), outline=(255, 177, 65), width=3)
    d.ellipse([33.1 * T, 3.2 * T, 37.6 * T, 7.7 * T], fill=(255, 246, 177))
    for cx, cy, sc in ((8, 4.6, 20), (17.4, 2.8, 16), (27.0, 6.2, 17), (42.0, 4.2, 14)):
        pixel_cloud(d, cx * T, cy * T, sc, (255, 255, 255), (214, 246, 255))
    hills = [((132, 222, 164), 19.1, 2.3, 0.010, 0.0),
             ((91, 207, 133), 20.2, 1.8, 0.014, 2.4),
             ((61, 187, 110), 21.2, 1.1, 0.021, 5.0)]
    for color, base, amp, freq, phase in hills:
        pts = [(0, SCENE_H)]
        for x in range(0, SCENE_W + 28, 28):
            y = base * T - amp * T * (0.55 + 0.45 * math.sin(x * freq + phase))
            pts.append((x, int(y // 7 * 7)))
        pts.append((SCENE_W, SCENE_H))
        d.polygon(pts, fill=color)
    meadow_ground(d)
    for x, y, w in PLATFORMS:
        meadow_platform(d, x, y, w, vine=(x in (10, 18, 35)))
    meadow_block(d, 19.4, 16)
    meadow_crate(d, 31.2, 22, 1.5)
    meadow_crate(d, 32.0, 20.63, 1.12)
    meadow_barrel(d, 37.2, 22)
    for tx, scale in ((4.4, 1.0), (15.2, 0.8), (27.0, 0.9), (41.2, 0.75)):
        base = GROUND * T
        d.line([tx * T, base, tx * T, base - 15 * scale], fill=(38, 139, 63), width=2)
        for angle in range(0, 360, 72):
            a = math.radians(angle + 18)
            fx = tx * T + math.cos(a) * 7 * scale
            fy = base - 15 * scale + math.sin(a) * 7 * scale
            d.ellipse([fx - 4 * scale, fy - 4 * scale, fx + 4 * scale, fy + 4 * scale],
                      fill=(255, 183, 75) if angle % 144 == 0 else (255, 106, 135))
    pig_meadow(d, P1_X, GROUND, (255, 126, 126), (178, 60, 77), (255, 209, 102), 1)
    pig_meadow(d, P2_X, 16, (100, 202, 255), (44, 112, 170), (255, 126, 214), -1)
    pts = arc_points(P1_X * T + 22, GROUND * T - 48, P2_X * T - 25, 16 * T - 43, 7, 72)
    for i, (x, y) in enumerate(pts):
        c = (255, 234, 146) if i % 2 == 0 else (255, 122, 96)
        d.rectangle([x - 3, y - 3, x + 3, y + 3], fill=c, outline=(73, 53, 55))
    for x, y, c in ((12.8, 8.2, (255, 255, 255)), (25.7, 6.4, (255, 213, 110)), (39.2, 10.1, (255, 255, 255))):
        d.rectangle([x * T, y * T, x * T + 4, y * T + 2], fill=c)
        d.rectangle([x * T + 2, y * T - 2, x * T + 4, y * T + 4], fill=c)
    return img.convert("RGB")


def story_platform(img, x, y, w, vine=True):
    s = 2
    T = TILE
    img = shadow(img, [x * T, (y + 0.55) * T, (x + w) * T, (y + 1.35) * T], s, 16, 10, 70)
    d = ImageDraw.Draw(img)
    rect(d, [x * T, y * T, (x + w) * T, (y + 0.92) * T], s,
         fill=(126, 91, 63), outline=(57, 44, 45), width=2, radius=12)
    rect(d, [x * T + 6, y * T + 8, (x + w) * T - 6, (y + 0.82) * T], s,
         fill=(151, 112, 76), width=0, radius=8)
    pts = [(x * T, y * T + 12), ((x + w * 0.25) * T, y * T - 2),
           ((x + w * 0.5) * T, y * T + 7), ((x + w * 0.75) * T, y * T - 3),
           ((x + w) * T, y * T + 10), ((x + w) * T, y * T + 20), (x * T, y * T + 20)]
    poly(d, pts, s, fill=(92, 135, 68), outline=(45, 69, 48), width=2)
    line(d, [(x * T + 8, y * T + 9), ((x + w) * T - 10, y * T + 8)], s, (139, 186, 91), 4)
    random.seed(int(x * 13 + y * 7))
    for _ in range(int(w * 10)):
        rx = random.uniform(x * T + 8, (x + w) * T - 8)
        ry = random.uniform(y * T + 18, (y + 0.8) * T)
        ellipse(d, [rx, ry, rx + 2, ry + 1], s, fill=(174, 132, 89))
    if vine:
        vx = (x + w * 0.72) * T
        line(d, [(vx, (y + 0.88) * T), (vx - 5, (y + 1.75) * T)], s, (57, 109, 63), 3)
        for yy in (y + 1.18, y + 1.54):
            ellipse(d, [vx - 13, yy * T - 4, vx - 3, yy * T + 5], s, fill=(83, 145, 78))
            ellipse(d, [vx + 1, yy * T + 5, vx + 11, yy * T + 14], s, fill=(83, 145, 78))
    return img


def story_pig(d, cx, feet, body, dark, accent, facing=1):
    s = 2
    T = TILE
    cx *= T
    feet *= T
    bw, bh = 1.28 * T, 1.2 * T
    left, right = cx - bw / 2, cx + bw / 2
    top = feet - bh - 4
    for lx in (-0.34, 0.34):
        x = cx + lx * T - 4
        rect(d, [x, feet - 12, x + 8, feet], s, fill=dark, outline=(54, 40, 43), width=1, radius=3)
    ellipse(d, [left, top, right, feet - 6], s, fill=body, outline=(58, 43, 46), width=3)
    ellipse(d, [left + 8, top + 8, left + bw * 0.56, top + bh * 0.5], s, fill=(255, 255, 255, 47))
    poly(d, [(left + 8, top + 16), (left + 13, top - 6), (left + 25, top + 8)],
         s, fill=body, outline=(58, 43, 46), width=2)
    poly(d, [(right - 8, top + 16), (right - 13, top - 6), (right - 25, top + 8)],
         s, fill=body, outline=(58, 43, 46), width=2)
    sx = cx + facing * 0.23 * T
    ellipse(d, [sx - 10, top + bh * 0.47, sx + 10, top + bh * 0.47 + 16], s,
            fill=(255, 172, 165), outline=(95, 61, 64), width=2)
    for nx in (sx - 5, sx + 2):
        ellipse(d, [nx, top + bh * 0.51, nx + 3, top + bh * 0.51 + 4], s, fill=(95, 57, 61))
    ex = cx + facing * 0.42 * T
    ellipse(d, [ex - 5, top + 21, ex - 1, top + 25], s, fill=(43, 34, 38))
    d.rectangle([int((ex - 9) * s), int((top + 31) * s), int((ex + 1) * s), int((top + 35) * s)], fill=accent)
    w0 = (cx + facing * 0.5 * T, top + bh * 0.62)
    w1 = (cx + facing * 0.8 * T, top + bh * 0.12)
    line(d, [w0, w1], s, (76, 57, 55), 4)
    line(d, [w0, w1], s, (245, 220, 172), 2)
    ellipse(d, [w1[0] - 7, w1[1] - 7, w1[0] + 7, w1[1] + 7], s,
            fill=accent, outline=(83, 62, 70), width=2)
    ellipse(d, [w1[0] - 6, w1[1] - 7, w1[0] - 1, w1[1] - 2], s, fill=(255, 255, 255, 120))


def story_tree(img, xt, top_t, base_t, scale=1.0, foliage=(94, 136, 68)):
    s = 2
    T = TILE
    x, top, base = xt * T, top_t * T, base_t * T
    blobs = [(-0.18, -0.18, 0.95, 0.8), (0.43, -0.42, 0.76, 0.64),
             (-0.55, -0.62, 0.68, 0.58), (0.08, -1.04, 0.82, 0.7),
             (0.54, -0.98, 0.55, 0.48), (-0.24, -1.4, 0.58, 0.48)]

    def paint(d, ox, oy, fill, outline=None, width=0, leaves=True):
        poly(d, [(x - 0.3 * T + ox, base + oy), (x + 0.3 * T + ox, base + oy),
                 (x + 0.17 * T + ox, top + 0.55 * T + oy),
                 (x - 0.17 * T + ox, top + 0.55 * T + oy)],
             s, fill=fill, outline=outline, width=width)
        for bx, by in ((-0.8, 0.32), (0.76, 0.16)):
            line(d, [(x + ox, top + 1.1 * T + oy),
                     (x + bx * T * scale + ox, top + by * T * scale + oy)],
                 s, fill, 4 if (len(fill) > 3 and fill[3] > 100) else 7)
        if leaves:
            for dx, dy, rx, ry in blobs:
                cx = x + dx * T * scale + ox
                cy = top + dy * T * scale + oy
                ellipse(d, [cx - rx * T * scale, cy - ry * T * scale,
                            cx + rx * T * scale, cy + ry * T * scale],
                        s, fill=fill, outline=outline, width=width)

    shadow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    paint(ImageDraw.Draw(shadow_layer), 10, 12, (25, 30, 24, 55))
    img = Image.alpha_composite(img, shadow_layer.filter(ImageFilter.GaussianBlur(4 * s)))
    d = ImageDraw.Draw(img)
    paint(d, 0, 0, (84, 63, 47), (54, 42, 40), 3, leaves=False)
    d2 = ImageDraw.Draw(img)
    for dx, dy, rx, ry in blobs:
        cx = x + dx * T * scale
        cy = top + dy * T * scale
        ellipse(d2, [cx - rx * T * scale, cy - ry * T * scale,
                     cx + rx * T * scale, cy + ry * T * scale],
                s, fill=foliage, outline=(45, 69, 48), width=3)
        ellipse(d2, [cx - rx * 0.56 * T * scale, cy - ry * 0.6 * T * scale,
                     cx + rx * 0.06 * T * scale, cy + ry * 0.1 * T * scale],
                s, fill=(139, 184, 91, 150))
    for lx, ly in ((-0.9, 0.35), (0.9, 0.5), (0.15, -1.7), (-0.5, -1.5)):
        ellipse(d2, [x + lx * T * scale - 5, top + ly * T * scale - 5,
                     x + lx * T * scale + 5, top + ly * T * scale + 5],
                s, fill=(157, 198, 101, 190))
    return img


def scene_storybook():
    s = 2
    T = TILE
    img = vgrad((SCENE_W * s, SCENE_H * s), (242, 178, 132), (91, 122, 120))
    d = ImageDraw.Draw(img)

    far = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(far)
    fd.ellipse([29 * T * s, 2 * T * s, 38 * T * s, 11 * T * s], fill=(255, 224, 154, 180))
    for bx_, by_, r in ((6, 8, 7), (14, 7, 5), (35, 7, 6), (41, 9, 5)):
        fd.ellipse([bx_ * T * s, by_ * T * s, (bx_ + 2.3) * T * s, (by_ + 2.3) * T * s],
                   fill=(255, 255, 255, 110))
    for cx_, w_ in ((4, 9), (14, 7), (25, 6), (35, 10)):
        fd.polygon([(cx_ * T * s, 22 * T * s), ((cx_ + w_ * 0.5) * T * s, 10 * T * s),
                    ((cx_ + w_) * T * s, 22 * T * s)], fill=(79, 111, 92, 190))
    far = far.filter(ImageFilter.GaussianBlur(4 * s))
    img = Image.alpha_composite(img, far)
    d = ImageDraw.Draw(img)
    for bx_, by_, sc in ((11.0, 5.2, 0.9), (13.4, 4.7, 0.7), (35.0, 4.4, 0.8)):
        line(d, [(bx_ * T - 8 * sc, by_ * T), (bx_ * T, by_ * T - 4 * sc),
                 (bx_ * T + 8 * sc, by_ * T)], s, (92, 73, 66), 2)

    for tx, ty, sc in ((4.8, 9.2, 1.35), (40.0, 9.8, 1.1), (28.0, 11.5, 0.72)):
        img = story_tree(img, tx, ty, GROUND, sc)
    d = ImageDraw.Draw(img)

    ground_top = GROUND * T
    pts = [(0, SCENE_H)]
    for x in range(0, SCENE_W + 28, 28):
        y = ground_top + math.sin(x * 0.018) * 6 + math.sin(x * 0.006 + 1.4) * 8
        pts.append((x, y))
    pts.extend([(SCENE_W, SCENE_H)])
    poly(d, pts, s, fill=(112, 78, 56), outline=(54, 42, 42), width=3)
    moss = []
    for x in range(0, SCENE_W + 28, 28):
        y = ground_top + math.sin(x * 0.018) * 6 + math.sin(x * 0.006 + 1.4) * 8
        moss.append((x, y))
    moss.extend([(SCENE_W, ground_top + 18), (0, ground_top + 18)])
    poly(d, moss, s, fill=(94, 136, 68))
    line(d, moss[:len(moss) - 2], s, (142, 184, 91), 10)
    line(d, moss[:len(moss) - 2], s, (178, 210, 121), 3)
    random.seed(31)
    for _ in range(260):
        x = random.uniform(0, SCENE_W)
        y = random.uniform(ground_top + 18, SCENE_H - 3)
        c = random.choice([(92, 62, 47), (139, 98, 67), (78, 55, 46), (158, 113, 75)])
        d.ellipse([x * s, y * s, (x + random.uniform(1, 4)) * s, (y + 2) * s], fill=c)
    for tx in range(1, COLS, 2):
        x = tx * T + 9
        line(d, [(x, ground_top + 2), (x - 7, ground_top - 12)], s, (55, 102, 61), 2)
        line(d, [(x + 2, ground_top + 2), (x + 10, ground_top - 10)], s, (55, 102, 61), 2)
        line(d, [(x, ground_top + 2), (x, ground_top - 16)], s, (88, 151, 79), 2)

    for x, y, w in PLATFORMS:
        img = story_platform(img, x, y, w, vine=(x in (10, 18, 35)))
    d = ImageDraw.Draw(img)
    for mx_, my_, sc_ in ((12.8, 20.8, 1.0), (27.6, 21.0, 0.8), (39.6, 21.1, 0.7)):
        rect(d, [mx_ * T - 3, my_ * T, mx_ * T + 3, my_ * T + 12], s, fill=(238, 224, 191))
        ellipse(d, [mx_ * T - 15, my_ * T - 6, mx_ * T + 15, my_ * T + 8], s,
                fill=(211, 88, 74), outline=(82, 48, 48), width=2)
        ellipse(d, [mx_ * T - 4, my_ * T - 1, mx_ * T, my_ * T + 3], s, fill=(255, 232, 198))

    img = story_crate(img, 31.2, 22, 1.5)
    img = story_barrel(img, 37.2, 22)
    d = ImageDraw.Draw(img)
    pig_shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(pig_shadow)
    ellipse(pd, [P1_X * T - 20, GROUND * T - 7, P1_X * T + 20, GROUND * T + 4], s, fill=(35, 29, 31, 75))
    ellipse(pd, [P2_X * T - 20, 16 * T - 7, P2_X * T + 20, 16 * T + 4], s, fill=(35, 29, 31, 75))
    img = Image.alpha_composite(img, pig_shadow.filter(ImageFilter.GaussianBlur(3 * s)))
    d = ImageDraw.Draw(img)
    story_pig(d, P1_X, GROUND, (235, 120, 113), (158, 67, 74), (255, 207, 98), 1)
    story_pig(d, P2_X, 16, (98, 174, 211), (47, 91, 134), (234, 133, 195), -1)

    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, (x, y) in enumerate(arc_points(P1_X * T + 22, GROUND * T - 46,
                                           P2_X * T - 25, 16 * T - 43, 8, 72)):
        r = 4 if i % 2 else 6
        gd.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s],
                   fill=(255, 218, 125, 210))
    for fx, fy in ((13.2, 10.0), (25.5, 8.6), (33.0, 15.1), (40.0, 12.8), (17.0, 18.6)):
        gd.ellipse([fx * T * s - 5 * s, fy * T * s - 5 * s,
                    fx * T * s + 5 * s, fy * T * s + 5 * s], fill=(255, 238, 150, 190))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(4 * s)))
    d = ImageDraw.Draw(img)
    for fx, fy in ((13.2, 10.0), (25.5, 8.6), (33.0, 15.1), (40.0, 12.8), (17.0, 18.6)):
        ellipse(d, [fx * T - 2, fy * T - 2, fx * T + 2, fy * T + 2], s, fill=(255, 248, 195))
    for x, y, c in ((12.8, 8.2, (255, 255, 255)), (25.7, 6.4, (255, 226, 151)), (39.2, 10.1, (255, 255, 255))):
        ellipse(d, [x * T, y * T, x * T + 3, y * T + 3], s, fill=(255, 255, 255, 180))
    img = img.resize((SCENE_W, SCENE_H), Image.LANCZOS)
    return img.convert("RGB")


def story_crate(img, cx, bottom, size=1.55):
    s = 2
    T = TILE
    x0 = cx * T - size * T / 2
    y0 = bottom * T - size * T
    img = shadow(img, [x0, y0 + 8, x0 + size * T, bottom * T], s, 10, 7, 65)
    d = ImageDraw.Draw(img)
    rect(d, [x0, y0, x0 + size * T, bottom * T], s,
         fill=(174, 119, 75), outline=(61, 45, 45), width=3, radius=5)
    rect(d, [x0 + 6, y0 + 6, x0 + size * T - 6, bottom * T - 6], s,
         fill=(196, 143, 91), width=0, radius=3)
    line(d, [(x0 + 8, y0 + 8), (x0 + size * T - 8, bottom * T - 8)], s, (151, 95, 58), 5)
    line(d, [(x0 + size * T - 8, y0 + 8), (x0 + 8, bottom * T - 8)], s, (151, 95, 58), 5)
    for px_, py_ in ((x0 + 7, y0 + 7), (x0 + size * T - 7, y0 + 7),
                     (x0 + 7, bottom * T - 7), (x0 + size * T - 7, bottom * T - 7)):
        ellipse(d, [px_ - 2, py_ - 2, px_ + 2, py_ + 2], s, fill=(75, 57, 50))
    return img


def story_barrel(img, cx, bottom):
    s = 2
    T = TILE
    w = 1.2 * T
    h = 1.35 * T
    x0 = cx * T - w / 2
    y0 = bottom * T - h
    img = shadow(img, [x0, y0 + 8, x0 + w, bottom * T], s, 12, 7, 65)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 * s, y0 * s, (x0 + w) * s, bottom * T * s],
                        radius=9 * s, fill=(164, 99, 59), outline=(59, 44, 44), width=3 * s)
    ellipse(d, [x0, y0 - 4, x0 + w, y0 + 10], s,
            fill=(204, 133, 78), outline=(59, 44, 44), width=2)
    for yy in (y0 + 13, bottom * T - 18):
        rect(d, [x0 + 1, yy, x0 + w - 1, yy + 6], s, fill=(91, 73, 60), radius=2)
        line(d, [(x0 + 3, yy + 2), (x0 + w - 3, yy + 2)], s, (174, 123, 75), 2)
    return img


def neon_platform(img, x, y, w, accent=(42, 245, 226), under=(255, 61, 154)):
    s = 2
    T = TILE
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line([x * T * s, (y + 0.04) * T * s, (x + w) * T * s, (y + 0.04) * T * s],
            fill=(*accent, 210), width=4 * s)
    gd.line([(x + 0.06 * w) * T * s, (y + 0.92) * T * s,
             (x + 0.94 * w) * T * s, (y + 0.92) * T * s], fill=(*under, 150), width=5 * s)
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(9 * s)))
    d = ImageDraw.Draw(img)
    rect(d, [x * T, y * T, (x + w) * T, (y + 0.9) * T], s,
         fill=(17, 25, 45), outline=(60, 78, 112), width=2, radius=3)
    rect(d, [x * T + 3, y * T + 3, (x + w) * T - 3, (y + 0.26) * T], s,
         fill=(37, 52, 81), width=0, radius=2)
    line(d, [(x * T + 5, y * T + 3), ((x + w) * T - 5, y * T + 3)], s, accent, 2)
    line(d, [(x * T + 5, (y + 0.84) * T), ((x + w) * T - 5, (y + 0.84) * T)], s, under, 2)
    for tx in range(int(x) + 1, int(x + w)):
        line(d, [(tx * T, y * T + 4), (tx * T, (y + 0.84) * T)], s, (24, 35, 60), 1)
    for tx in (x + 0.25, x + w - 0.25):
        for yy in (y + 0.25, y + 0.65):
            ellipse(d, [tx * T - 3, yy * T, tx * T + 3, yy * T + 6], s,
                    fill=(80, 101, 138), outline=(29, 40, 64), width=1)
    return img


def neon_ground(d):
    s = 2
    T = TILE
    top = GROUND * T
    rect(d, [0, top, SCENE_W, SCENE_H], s, fill=(8, 13, 26))
    rect(d, [0, top, SCENE_W, top + 13], s, fill=(31, 45, 71))
    rect(d, [0, top, SCENE_W, top + 7], s, fill=(55, 74, 108))
    line(d, [(0, top + 1), (SCENE_W, top + 1)], s, (48, 244, 225), 3)
    line(d, [(0, top + 21), (SCENE_W, top + 21)], s, (255, 62, 155), 2)
    for tx in range(0, COLS + 1, 2):
        x = tx * T
        line(d, [(x, top + 7), (x, SCENE_H)], s, (21, 31, 53), 2)
        line(d, [(x + 4, top + 11), (x + 4, SCENE_H)], s, (13, 20, 36), 1)
    for tx in range(1, COLS, 2):
        for yy in (top + 17, top + 43):
            ellipse(d, [tx * T - 2, yy - 2, tx * T + 2, yy + 2], s, fill=(98, 119, 150))
    rect(d, [0, SCENE_H - 18, SCENE_W, SCENE_H], s, fill=(5, 8, 16))


def neon_crate(img, cx, bottom, size=1.55):
    s = 2
    T = TILE
    x0 = cx * T - size * T / 2
    y0 = bottom * T - size * T
    d = ImageDraw.Draw(img)
    rect(d, [x0, y0, x0 + size * T, bottom * T], s,
         fill=(16, 24, 43), outline=(74, 92, 125), width=3, radius=3)
    rect(d, [x0 + 5, y0 + 5, x0 + size * T - 5, bottom * T - 5], s,
         fill=(23, 35, 58), width=0, radius=2)
    line(d, [(x0 + 8, y0 + 8), (x0 + size * T - 8, bottom * T - 8)], s, (39, 239, 220), 3)
    line(d, [(x0 + size * T - 8, y0 + 8), (x0 + 8, bottom * T - 8)], s, (255, 61, 154), 2)
    for px_, py_ in ((x0 + 7, y0 + 7), (x0 + size * T - 7, y0 + 7),
                     (x0 + 7, bottom * T - 7), (x0 + size * T - 7, bottom * T - 7)):
        ellipse(d, [px_ - 2, py_ - 2, px_ + 2, py_ + 2], s, fill=(106, 133, 162))
    return img


def neon_barrel(img, cx, bottom):
    s = 2
    T = TILE
    w = 1.18 * T
    h = 1.3 * T
    x0 = cx * T - w / 2
    y0 = bottom * T - h
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 * s, y0 * s, (x0 + w) * s, bottom * T * s],
                        radius=8 * s, fill=(18, 27, 46), outline=(74, 92, 125), width=3 * s)
    ellipse(d, [x0, y0 - 4, x0 + w, y0 + 10], s,
            fill=(35, 48, 72), outline=(86, 108, 139), width=2)
    for yy in (y0 + 13, bottom * T - 18):
        rect(d, [x0 + 1, yy, x0 + w - 1, yy + 7], s, fill=(21, 31, 50), radius=2)
        line(d, [(x0 + 3, yy + 2), (x0 + w - 3, yy + 2)], s, (255, 182, 53), 2)
    rect(d, [x0 + 8, y0 + 28, x0 + w - 8, y0 + 47], s, fill=(255, 182, 53), radius=2)
    text(d, ((x0 + w / 2) * s, (y0 + 37) * s), "!", 10 * s, (20, 25, 35), True, True, "mm")
    return img


def pig_neon(d, cx, feet, body, accent, facing=1):
    s = 2
    T = TILE
    cx *= T
    feet *= T
    bw, bh = 1.3 * T, 1.22 * T
    left, right = cx - bw / 2, cx + bw / 2
    top = feet - bh - 5
    ellipse(d, [left + 4, feet - 9, right - 4, feet + 4], s, fill=(*accent, 55))
    for lx in (-0.34, 0.34):
        x = cx + lx * T - 4
        rect(d, [x, feet - 12, x + 8, feet], s, fill=(12, 18, 32), outline=accent, width=1, radius=2)
    ellipse(d, [left, top, right, feet - 7], s, fill=(17, 24, 43), outline=accent, width=3)
    ellipse(d, [left + 8, top + 8, left + bw * 0.56, top + bh * 0.5], s, fill=(255, 255, 255, 18))
    poly(d, [(left + 8, top + 16), (left + 13, top - 7), (left + 25, top + 8)],
         s, fill=(20, 29, 49), outline=accent, width=2)
    poly(d, [(right - 8, top + 16), (right - 13, top - 7), (right - 25, top + 8)],
         s, fill=(20, 29, 49), outline=accent, width=2)
    sx = cx + facing * 0.23 * T
    ellipse(d, [sx - 10, top + bh * 0.47, sx + 10, top + bh * 0.47 + 16], s,
            fill=(25, 35, 58), outline=(255, 156, 207), width=2)
    for nx in (sx - 5, sx + 2):
        ellipse(d, [nx, top + bh * 0.51, nx + 3, top + bh * 0.51 + 4], s, fill=(255, 156, 207))
    visor_x = cx + facing * 0.36 * T
    d.rounded_rectangle([(visor_x - 12) * s, (top + 19) * s, (visor_x + 8) * s, (top + 28) * s],
                        radius=4 * s, fill=(35, 245, 222), outline=(8, 14, 26), width=2 * s)
    line(d, [(visor_x - 7, top + 23), (visor_x + 3, top + 23)], s, (255, 255, 255), 2)
    w0 = (cx + facing * 0.5 * T, top + bh * 0.62)
    w1 = (cx + facing * 0.82 * T, top + bh * 0.12)
    line(d, [w0, w1], s, (54, 69, 96), 4)
    line(d, [w0, w1], s, accent, 2)
    ellipse(d, [w1[0] - 7, w1[1] - 7, w1[0] + 7, w1[1] + 7], s,
            fill=(*accent, 210), outline=(240, 255, 255), width=2)


def scene_neon():
    s = 2
    T = TILE
    img = vgrad((SCENE_W * s, SCENE_H * s), (5, 9, 20), (11, 19, 38))
    d = ImageDraw.Draw(img)
    for i in range(14):
        y = (4 + i * 1.25) * T
        d.line([0, y * s, SCENE_W * s, y * s], fill=(42, 78, 117, 20), width=1 * s)
    for i in range(22):
        x = i * 2 * T
        d.line([x * s, 4 * T * s, x * s, GROUND * T * s], fill=(42, 78, 117, 20), width=1 * s)
    ring = [31 * T, 2 * T, 41 * T, 12 * T]
    ring_inner = [33 * T, 4 * T, 39 * T, 10 * T]
    ring_glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rgd = ImageDraw.Draw(ring_glow)
    rgd.ellipse([ring[0] * s, ring[1] * s, ring[2] * s, ring[3] * s],
                outline=(42, 245, 226, 180), width=5 * s)
    rgd.ellipse([ring_inner[0] * s, ring_inner[1] * s, ring_inner[2] * s, ring_inner[3] * s],
                outline=(255, 61, 154, 140), width=3 * s)
    img = Image.alpha_composite(img, ring_glow.filter(ImageFilter.GaussianBlur(9 * s)))
    d = ImageDraw.Draw(img)
    ellipse(d, ring, s, fill=(20, 54, 76, 20), outline=(42, 245, 226, 105), width=2)
    ellipse(d, ring_inner, s, outline=(255, 61, 154, 90), width=2)

    far = Image.new("RGBA", img.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(far)
    for x0, y0, w0, h0 in ((2, 13, 7, 9), (11, 11, 5, 11), (19, 14, 9, 8),
                           (30, 12, 6, 10), (37, 15, 7, 7)):
        fd.rectangle([x0 * T * s, y0 * T * s, (x0 + w0) * T * s, (y0 + h0) * T * s],
                     fill=(13, 23, 44, 220))
        for row in range(4):
            for col in range(2):
                fd.rectangle([(x0 + 1 + col * 2) * T * s, (y0 + 1 + row * 2) * T * s,
                              (x0 + 1.4 + col * 2) * T * s, (y0 + 1.3 + row * 2) * T * s],
                             fill=(38, 101, 111, 80))
    for x0 in (5, 17, 28, 39):
        fd.rectangle([x0 * T * s, 7 * T * s, (x0 + 0.3) * T * s, 22 * T * s],
                     fill=(20, 43, 63, 110))
    img = Image.alpha_composite(img, far.filter(ImageFilter.GaussianBlur(5 * s)))
    d = ImageDraw.Draw(img)
    for px_, accent in ((4.0, (42, 245, 226)), (15.5, (255, 61, 154)),
                        (26.5, (42, 245, 226)), (38.5, (255, 61, 154))):
        rect(d, [px_ * T, 5.5 * T, (px_ + 0.34) * T, GROUND * T], s,
             fill=(15, 23, 41), outline=(46, 65, 96), width=1)
        for yy in range(7, GROUND, 4):
            rect(d, [px_ * T, yy * T, (px_ + 0.34) * T, yy * T + 0.18 * T], s,
                 fill=(25, 38, 62), outline=(46, 65, 96), width=1)
        seam = (32, 120, 125) if accent[1] > 200 else (120, 38, 80)
        line(d, [((px_ + 0.06) * T, 6 * T), ((px_ + 0.06) * T, GROUND * T)], s,
             (38, 140, 150), 1)
        line(d, [((px_ + 0.29) * T, 6 * T), ((px_ + 0.29) * T, GROUND * T)], s,
             seam, 1)

    neon_ground(d)
    for idx, (x, y, w) in enumerate(PLATFORMS):
        img = neon_platform(img, x, y, w,
                            (42, 245, 226) if idx % 2 == 0 else (255, 61, 154),
                            (255, 61, 154) if idx % 2 == 0 else (42, 245, 226))
    d = ImageDraw.Draw(img)
    neon_crate(img, 31.2, 22, 1.5)
    neon_crate(img, 32.0, 20.63, 1.12)
    neon_barrel(img, 37.2, 22)
    d = ImageDraw.Draw(img)
    # Power core on the high center platform.
    core_x, core_y = 21.8 * T, 8.1 * T
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([(core_x - 28) * s, (core_y - 28) * s, (core_x + 28) * s, (core_y + 28) * s],
               fill=(43, 245, 226, 170))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(11 * s)))
    d = ImageDraw.Draw(img)
    d.polygon([(core_x * s, (core_y - 18) * s), ((core_x + 17) * s, core_y * s),
               (core_x * s, (core_y + 18) * s), ((core_x - 17) * s, core_y * s)],
              fill=(198, 255, 250), outline=(255, 61, 154), width=3 * s)
    d.polygon([(core_x * s, (core_y - 9) * s), ((core_x + 8) * s, core_y * s),
               (core_x * s, (core_y + 9) * s), ((core_x - 8) * s, core_y * s)],
              fill=(42, 245, 226))

    pig_neon(d, P1_X, GROUND, (255, 126, 126), (255, 95, 155), 1)
    pig_neon(d, P2_X, 16, (100, 202, 255), (42, 245, 226), -1)
    for i, (x, y) in enumerate(arc_points(P1_X * T + 24, GROUND * T - 47,
                                           P2_X * T - 28, 16 * T - 44, 9, 75)):
        r = 3 if i % 2 else 5
        ellipse(d, [x - r, y - r, x + r, y + r], s,
                fill=(255, 220, 100) if i % 2 else (255, 73, 157))
    random.seed(19)
    for _ in range(110):
        x = random.uniform(0, SCENE_W)
        y = random.uniform(2 * T, 21 * T)
        c = random.choice([(42, 245, 226), (255, 61, 154), (255, 214, 109)])
        rect(d, [x, y, x + random.choice([1, 2, 3]), y + 1], s, fill=c)
    scan = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(scan)
    for y in range(0, SCENE_H * s, 4 * s):
        sd.line([0, y, SCENE_W * s, y], fill=(0, 0, 0, 16), width=1 * s)
    img = Image.alpha_composite(img, scan)
    img = img.resize((SCENE_W, SCENE_H), Image.LANCZOS)
    return img.convert("RGB")


def paper_platform(img, x, y, w):
    s = 2
    T = TILE
    img = shadow(img, [x * T + 8, (y + 0.75) * T, (x + w) * T + 8, (y + 1.45) * T],
                 s, 6, 3, 45)
    d = ImageDraw.Draw(img)
    rect(d, [x * T, y * T, (x + w) * T, (y + 0.9) * T], s,
         fill=(86, 166, 158), outline=(36, 49, 70), width=3, radius=9)
    rect(d, [x * T + 7, y * T + 7, (x + w) * T - 7, (y + 0.56) * T], s,
         fill=(242, 193, 78), width=0, radius=5)
    line(d, [(x * T + 15, (y + 0.72) * T), ((x + w) * T - 15, (y + 0.72) * T)],
         s, (45, 115, 112), 3)
    for tx in range(1, int(w), 2):
        line(d, [((x + tx) * T, y * T + 8), ((x + tx) * T - 4, (y + 0.82) * T)], s,
             (70, 143, 139), 2)
    return img


def paper_ground(d):
    s = 2
    T = TILE
    top = GROUND * T
    rect(d, [0, top, SCENE_W, SCENE_H], s, fill=(211, 154, 103),
         outline=(36, 49, 70), width=4)
    rect(d, [0, top, SCENE_W, top + 11], s, fill=(217, 108, 74),
         outline=(36, 49, 70), width=3)
    rect(d, [0, top + 8, SCENE_W, top + 18], s, fill=(242, 193, 78))
    rect(d, [0, top + 18, SCENE_W, SCENE_H], s, fill=(211, 154, 103))
    for tx in range(0, COLS + 1, 3):
        x = tx * T
        line(d, [(x, top + 20), (x + 9, SCENE_H)], s, (194, 135, 88), 2)
    for tx in range(1, COLS, 4):
        x = tx * T + 10
        line(d, [(x, top), (x - 6, top - 10)], s, (54, 113, 105), 3)
        line(d, [(x + 2, top), (x + 10, top - 8)], s, (54, 113, 105), 3)
    line(d, [(0, top), (SCENE_W, top)], s, (36, 49, 70), 4)


def paper_crate(img, cx, bottom, size=1.5):
    s = 2
    T = TILE
    x0 = cx * T - size * T / 2
    y0 = bottom * T - size * T
    img = shadow(img, [x0 + 7, y0 + 7, x0 + size * T + 7, bottom * T + 7], s, 6, 2, 50)
    d = ImageDraw.Draw(img)
    rect(d, [x0, y0, x0 + size * T, bottom * T], s,
         fill=(229, 173, 93), outline=(36, 49, 70), width=3, radius=5)
    line(d, [(x0 + 7, y0 + 7), (x0 + size * T - 7, bottom * T - 7)], s, (197, 131, 69), 4)
    line(d, [(x0 + size * T - 7, y0 + 7), (x0 + 7, bottom * T - 7)], s, (197, 131, 69), 4)
    rect(d, [x0 + 6, y0 + 6, x0 + size * T - 6, y0 + 12], s, fill=(246, 204, 126), radius=2)
    return img


def paper_barrel(img, cx, bottom):
    s = 2
    T = TILE
    w = 1.16 * T
    x0 = cx * T - w / 2
    y0 = bottom * T - 1.3 * T
    img = shadow(img, [x0 + 7, y0 + 7, x0 + w + 7, bottom * T + 7], s, 6, 2, 50)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x0 * s, y0 * s, (x0 + w) * s, bottom * T * s],
                        radius=8 * s, fill=(217, 108, 74), outline=(36, 49, 70), width=3 * s)
    d.ellipse([x0 * s, (y0 - 5) * s, (x0 + w) * s, (y0 + 9) * s],
              fill=(242, 154, 108), outline=(36, 49, 70), width=2 * s)
    for yy in (y0 + 13, bottom * T - 18):
        rect(d, [x0 + 2, yy, x0 + w - 2, yy + 6], s, fill=(242, 193, 78), radius=2)
    return img


def pig_paper(d, cx, feet, body, dark, accent, facing=1):
    s = 2
    T = TILE
    cx *= T
    feet *= T
    bw, bh = 1.28 * T, 1.2 * T
    left, right = cx - bw / 2, cx + bw / 2
    top = feet - bh - 5
    ellipse(d, [left + 5, feet - 9, right + 5, feet + 4], s, fill=(36, 49, 70, 50))
    for lx in (-0.34, 0.34):
        x = cx + lx * T - 4
        rect(d, [x, feet - 12, x + 8, feet], s, fill=dark, outline=(36, 49, 70), width=1, radius=2)
    ellipse(d, [left, top, right, feet - 7], s, fill=body, outline=(36, 49, 70), width=3)
    poly(d, [(left + 8, top + 16), (left + 13, top - 7), (left + 25, top + 8)],
         s, fill=body, outline=(36, 49, 70), width=2)
    poly(d, [(right - 8, top + 16), (right - 13, top - 7), (right - 25, top + 8)],
         s, fill=body, outline=(36, 49, 70), width=2)
    sx = cx + facing * 0.23 * T
    ellipse(d, [sx - 10, top + bh * 0.47, sx + 10, top + bh * 0.47 + 16], s,
            fill=(255, 189, 169), outline=(36, 49, 70), width=2)
    for nx in (sx - 5, sx + 2):
        ellipse(d, [nx, top + bh * 0.51, nx + 3, top + bh * 0.51 + 4], s, fill=(68, 55, 64))
    ex = cx + facing * 0.42 * T
    ellipse(d, [ex - 5, top + 21, ex - 1, top + 25], s, fill=(36, 49, 70))
    rect(d, [ex - 9, top + 31, ex + 1, top + 35], s, fill=accent, radius=2)
    w0 = (cx + facing * 0.5 * T, top + bh * 0.62)
    w1 = (cx + facing * 0.8 * T, top + bh * 0.12)
    line(d, [w0, w1], s, (36, 49, 70), 4)
    line(d, [w0, w1], s, (255, 247, 230), 2)
    poly(d, [(w1[0], w1[1] - 9), (w1[0] + 8, w1[1]),
             (w1[0], w1[1] + 9), (w1[0] - 8, w1[1])],
         s, fill=accent, outline=(36, 49, 70), width=2)


def paper_tree(img, xt, top_t, base_t, scale=1.0, foliage=(79, 166, 160)):
    s = 2
    T = TILE
    x, top, base = xt * T, top_t * T, base_t * T
    blobs = [(-0.18, -0.25, 1.05, 0.88), (0.62, -0.55, 0.82, 0.68),
             (-0.62, -0.82, 0.74, 0.6), (0.12, -1.22, 0.88, 0.72),
             (0.72, -1.1, 0.55, 0.5), (-0.3, -1.55, 0.55, 0.45)]

    def paint(d, ox, oy, fill, outline=None, width=0, leaves=True):
        poly(d, [(x - 0.3 * T + ox, base + oy), (x + 0.3 * T + ox, base + oy),
                 (x + 0.18 * T + ox, top + 0.55 * T + oy),
                 (x - 0.18 * T + ox, top + 0.55 * T + oy)],
             s, fill=fill, outline=outline, width=width)
        for bx, by in ((-0.85, 0.35), (0.82, 0.18)):
            line(d, [(x + ox, top + 1.15 * T + oy),
                     (x + bx * T * scale + ox, top + by * T * scale + oy)],
                 s, fill, 7 if (len(fill) > 3 and fill[3] > 100) else 10)
        if leaves:
            for dx, dy, rx, ry in blobs:
                cx = x + dx * T * scale + ox
                cy = top + dy * T * scale + oy
                ellipse(d, [cx - rx * T * scale, cy - ry * T * scale,
                            cx + rx * T * scale, cy + ry * T * scale],
                        s, fill=fill, outline=outline, width=width)

    shadow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    paint(ImageDraw.Draw(shadow_layer), 12, 14, (36, 49, 70, 45))
    img = Image.alpha_composite(img, shadow_layer.filter(ImageFilter.GaussianBlur(3 * s)))
    d = ImageDraw.Draw(img)
    paint(d, 0, 0, (126, 91, 63), (36, 49, 70), 4, leaves=False)
    for bx, by in ((-0.85, 0.35), (0.82, 0.18)):
        line(d, [(x, top + 1.15 * T), (x + bx * T * scale, top + by * T * scale)],
             s, (36, 49, 70), 9)
        line(d, [(x, top + 1.15 * T), (x + bx * T * scale, top + by * T * scale)],
             s, (126, 91, 63), 5)
    for dx, dy, rx, ry in blobs:
        cx = x + dx * T * scale
        cy = top + dy * T * scale
        ellipse(d, [cx - rx * T * scale, cy - ry * T * scale,
                    cx + rx * T * scale, cy + ry * T * scale],
                s, fill=foliage, outline=(36, 49, 70), width=4)
        ellipse(d, [cx - rx * 0.58 * T * scale, cy - ry * 0.62 * T * scale,
                    cx + rx * 0.02 * T * scale, cy + ry * 0.02 * T * scale],
                s, fill=(134, 195, 179))
    for lx, ly in ((-1.05, 0.4), (1.05, 0.55), (0.18, -1.9), (-0.62, -1.62)):
        ellipse(d, [x + lx * T * scale - 6, top + ly * T * scale - 6,
                    x + lx * T * scale + 6, top + ly * T * scale + 6],
                s, fill=foliage, outline=(36, 49, 70), width=3)
    return img


def paper_plant(d, x, base, scale=1.0, color=(79, 166, 160)):
    s = 2
    T = TILE
    line(d, [(x, base), (x, base - 2.2 * T * scale)], s, (36, 49, 70), 5)
    line(d, [(x, base), (x, base - 2.2 * T * scale)], s, (88, 139, 91), 3)
    for side, yy in ((-1, 1.2), (1, 1.5), (-1, 1.9)):
        poly(d, [(x, base - yy * T * scale),
                 (x + side * 0.85 * T * scale, base - (yy + 0.25) * T * scale),
                 (x + side * 0.2 * T * scale, base - (yy - 0.2) * T * scale)],
             s, fill=color, outline=(36, 49, 70), width=3)
    ellipse(d, [x - 0.32 * T * scale, base - 2.55 * T * scale,
                x + 0.32 * T * scale, base - 1.95 * T * scale],
            s, fill=(242, 193, 78), outline=(36, 49, 70), width=3)


def paper_sign(d, x, base):
    s = 2
    T = TILE
    for px_ in (x - 0.7, x + 0.7):
        rect(d, [px_ * T - 5, base - 2.2 * T, px_ * T + 5, base], s,
             fill=(126, 91, 63), outline=(36, 49, 70), width=3, radius=2)
    rect(d, [x * T - 1.25 * T, base - 2.8 * T, x * T + 1.25 * T, base - 1.45 * T], s,
         fill=(242, 193, 78), outline=(36, 49, 70), width=4, radius=5)
    poly(d, [(x * T, base - 2.55 * T), (x * T + 0.18 * T, base - 2.18 * T),
             (x * T + 0.52 * T, base - 2.22 * T), (x * T + 0.25 * T, base - 1.9 * T),
             (x * T + 0.34 * T, base - 1.6 * T), (x * T, base - 1.78 * T),
             (x * T - 0.34 * T, base - 1.6 * T), (x * T - 0.25 * T, base - 1.9 * T),
             (x * T - 0.52 * T, base - 2.22 * T), (x * T - 0.18 * T, base - 2.18 * T)],
         s, fill=(229, 107, 85), outline=(36, 49, 70), width=2)


def scene_paper():
    s = 2
    T = TILE
    img = Image.new("RGBA", (SCENE_W * s, SCENE_H * s), (247, 238, 218, 255))
    d = ImageDraw.Draw(img)
    random.seed(77)
    for _ in range(900):
        x = random.uniform(0, SCENE_W * s)
        y = random.uniform(0, SCENE_H * s)
        d.point((x, y), fill=(206, 190, 158, random.choice([28, 42, 58])))
    sun_box = [32 * T, 2 * T, 40 * T, 10 * T]
    ellipse(d, [sun_box[0] + 10, sun_box[1] + 12, sun_box[2] + 10, sun_box[3] + 12],
            s, fill=(36, 49, 70, 35))
    ellipse(d, sun_box, s, fill=(242, 193, 78), outline=(36, 49, 70), width=4)
    ellipse(d, [33 * T, 3 * T, 39 * T, 9 * T], s, fill=(255, 215, 107))
    for cx_, cy_, w_ in ((7, 4, 6), (18, 3, 4), (29, 5, 5)):
        for dx, dy, r in ((-1, 0, 1.4), (0, -0.4, 1.9), (1.4, 0, 1.3)):
            ellipse(d, [(cx_ + dx - r) * T + 9, (cy_ + dy - r * 0.6) * T + 11,
                        (cx_ + dx + r) * T + 9, (cy_ + dy + r * 0.6) * T + 11],
                    s, fill=(36, 49, 70, 32))
        for dx, dy, r in ((-1, 0, 1.4), (0, -0.4, 1.9), (1.4, 0, 1.3)):
            ellipse(d, [(cx_ + dx - r) * T, (cy_ + dy - r * 0.6) * T,
                        (cx_ + dx + r) * T, (cy_ + dy + r * 0.6) * T],
                    s, fill=(255, 252, 242), outline=(36, 49, 70), width=3)
    for base, color, off, amp in ((18.2, (229, 107, 85), 0.0, 22),
                                  (19.4, (134, 195, 179), 1.6, 20),
                                  (20.4, (79, 166, 160), 3.2, 17)):
        pts = [(0, SCENE_H)]
        for x in range(0, SCENE_W + 30, 30):
            pts.append((x, base * T + math.sin(x * 0.017 + off) * amp))
        pts.append((SCENE_W, SCENE_H))
        shadow_pts = [(x + 10, y + 12) for x, y in pts]
        poly(d, shadow_pts, s, fill=(36, 49, 70, 45))
        poly(d, pts, s, fill=color, outline=(36, 49, 70), width=3)
    for tx, ty, sc in ((4.8, 9.2, 1.35), (40.0, 9.8, 1.1), (28.0, 11.5, 0.72)):
        img = paper_tree(img, tx, ty, GROUND, sc)
    d = ImageDraw.Draw(img)
    paper_ground(d)
    for x, y, w in PLATFORMS:
        img = paper_platform(img, x, y, w)
    d = ImageDraw.Draw(img)
    img = paper_crate(img, 31.2, 22, 1.5)
    img = paper_crate(img, 32.0, 20.63, 1.1)
    img = paper_barrel(img, 37.2, 22)
    d = ImageDraw.Draw(img)
    paper_sign(d, 14.0, GROUND * T)
    paper_plant(d, 2.1 * T, GROUND * T, 1.0)
    paper_plant(d, 9.3 * T, GROUND * T, 0.72, (134, 195, 179))
    paper_plant(d, 21.8 * T, GROUND * T, 0.68, (229, 107, 85))
    paper_plant(d, 42.0 * T, GROUND * T, 0.8, (229, 107, 85))
    pig_paper(d, P1_X, GROUND, (229, 107, 85), (173, 73, 73), (242, 193, 78), 1)
    pig_paper(d, P2_X, 16, (79, 166, 160), (43, 113, 111), (240, 143, 190), -1)
    for i, (x, y) in enumerate(arc_points(P1_X * T + 22, GROUND * T - 46,
                                           P2_X * T - 25, 16 * T - 43, 7, 70)):
        r = 4 if i % 2 else 6
        ellipse(d, [x - r, y - r, x + r, y + r], s,
                fill=(242, 193, 78) if i % 2 else (229, 107, 85),
                outline=(36, 49, 70), width=2)
    line(d, [(18 * T, 2.4 * T), (34 * T, 2.9 * T)], s, (36, 49, 70), 3)
    for i in range(9):
        t = i / 8
        bx_ = (18 + 16 * t) * T
        by_ = (2.4 + 0.5 * t) * T
        poly(d, [(bx_ - 12, by_), (bx_ + 12, by_), (bx_, by_ + 0.62 * T)],
             s, fill=(229, 107, 85) if i % 2 else (242, 193, 78),
             outline=(36, 49, 70), width=2)
    for bx_, by_, sc in ((11.2, 6.3, 1.0), (13.4, 5.7, 0.8), (34.4, 4.8, 0.9)):
        line(d, [(bx_ * T - 8 * sc, by_ * T), (bx_ * T, by_ * T - 4 * sc),
                 (bx_ * T + 8 * sc, by_ * T)], s, (36, 49, 70), 3)
    img = img.resize((SCENE_W, SCENE_H), Image.LANCZOS)
    return img.convert("RGB")


def make_overview():
    cw, ch = 2400, 1600
    canvas = vgrad((cw, ch), (10, 16, 27), (4, 7, 13))
    d = ImageDraw.Draw(canvas)
    text(d, (80, 36), "TILESET-KONZEPTE  /  BATTLE BALLS", 13, (112, 210, 224), True, True)
    text(d, (80, 64), "Vier Looks. Eine Arena.", 54, (246, 248, 252), True)
    text(d, (82, 132), "Gleiches 44 × 25-Layout, gleiche Sprungpunkte – nur Material, Licht und Formsprache ändern sich.",
         18, (176, 190, 206))
    d.line([80, 178, cw - 80, 178], fill=(40, 54, 72), width=1)

    items = [
        ("01", "Meadow Pop", "Chunky Pixel · hohe Lesbarkeit · niedriger Aufwand",
         "01_meadow_pop.png", (119, 231, 103)),
        ("02", "Storybook", "Handgemalt · weiche Tiefe · hoher Aufwand",
         "02_storybook.png", (235, 120, 113)),
        ("03", "Neon Foundry", "Dark Tech · starke Kontraste · map-spezifisch",
         "03_neon_foundry.png", (42, 245, 226)),
        ("04", "Paper Cutout", "Flat Vector · klare Silhouetten · niedriger Aufwand",
         "04_paper_cutout.png", (242, 193, 78)),
    ]
    positions = [(80, 226), (1240, 226), (80, 916), (1240, 916)]
    card_w, card_h = 1080, 614
    for (num, title, tagline, filename, accent), (x, y) in zip(items, positions):
        d.rounded_rectangle([x - 7, y - 7, x + card_w + 7, y + card_h + 7],
                            radius=11, fill=(8, 12, 20), outline=(46, 60, 78), width=2)
        d.rounded_rectangle([x - 3, y - 3, x + card_w + 3, y + card_h + 3],
                            radius=8, outline=accent, width=2)
        sheet = Image.open(ROOT / filename).convert("RGB")
        scene = sheet.crop((SCENE_X, SCENE_Y, SCENE_X + SCENE_W, SCENE_Y + SCENE_H))
        scene = scene.resize((card_w, card_h), Image.LANCZOS)
        canvas.paste(scene, (x, y))
        d.rounded_rectangle([x, y - 52, x + 34, y - 18], radius=6, fill=accent)
        text(d, (x + 17, y - 35), num, 16, (9, 15, 25), True, True, "mm")
        text(d, (x + 48, y - 55), title, 27, (246, 248, 252), True)
        text(d, (x + 50, y - 24), tagline, 13, (158, 174, 194))

    text(d, (80, 1552), "EMPFEHLUNG", 11, (112, 210, 224), True, True)
    text(d, (80, 1572), "Meadow Pop als Basis für alle Maps · Neon Foundry als eigener Satz für die Neonfabrik · Paper Cutout als saubere, günstige Alternative.",
         16, (206, 216, 229))
    text(d, (cw - 80, 1578), "Konzept-Mockups · keine finalen Tiles", 12, (120, 135, 154), False, False, "ra")
    out = ROOT / "00_overview.png"
    canvas.save(out)
    print("wrote", out)


def main():
    save_sheet(
        1, "Meadow Pop", "Konzept 01  ·  Chunky Pixel",
        scene_meadow(),
        [(99, 208, 255), (178, 103, 60), (119, 231, 103), (188, 111, 62), (255, 126, 126), (28, 51, 69)],
        "Chunky Pixel · hohe Lesbarkeit",
        "01_meadow_pop.png",
    )
    save_sheet(
        2, "Storybook", "Konzept 02  ·  Handgemalt",
        scene_storybook(),
        [(245, 196, 159), (126, 91, 63), (94, 136, 68), (151, 112, 76), (235, 120, 113), (58, 43, 46)],
        "Handgemalt · weiche Tiefe",
        "02_storybook.png",
    )
    save_sheet(
        3, "Neon Foundry", "Konzept 03  ·  Dark Tech",
        scene_neon(),
        [(6, 10, 20), (17, 25, 45), (42, 245, 226), (31, 45, 71), (255, 61, 154), (218, 255, 250)],
        "Dark Tech · starke Kontraste",
        "03_neon_foundry.png",
    )
    save_sheet(
        4, "Paper Cutout", "Konzept 04  ·  Flat Vector",
        scene_paper(),
        [(247, 238, 218), (211, 154, 103), (79, 166, 160), (242, 193, 78), (229, 107, 85), (36, 49, 70)],
        "Flat Vector · klare Silhouetten",
        "04_paper_cutout.png",
    )
    make_overview()


if __name__ == "__main__":
    main()
