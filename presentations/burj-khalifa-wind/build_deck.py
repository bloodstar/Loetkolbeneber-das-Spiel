"""Build the Burj Khalifa wind-engineering deck (part 1: slides 1-5)."""

from __future__ import annotations

import math
import os
from datetime import datetime

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.enum.dml import MSO_LINE_DASH_STYLE
from pptx.util import Inches, Pt

from deck_lib import (
    AMBER, BG, BG2, BLUE, CYAN, DIM, FONT, FONT_LIGHT, FONT_SEMI, GREEN, GRID,
    M, MUTED, ORANGE, PANEL, PANEL2, PURPLE, RED, SH, SW, TEAL, TEXT, TOTAL,
    arrow, axis_style, bar_chart, chip, footer, header, kpi, line, notes, panel,
    prep_chart, scatter_chart, source, table, tx, y_plan, low_tick_labels,
)

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Burj_Khalifa_Wind_Engineering.pptx")


def mix(a: RGBColor, b: RGBColor, t: float) -> RGBColor:
    return RGBColor(
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def base(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])
    s.background.fill.solid()
    s.background.fill.fore_color.rgb = BG
    return s


def blueprint_grid(s):
    for i in range(1, 17):
        x = i * SW / 17
        ln = line(s, x, 0, x, SH, color=mix(BG, CYAN, 0.10), width=0.5)
        ln.line.width = Pt(0.4)
    for j in range(1, 10):
        y = j * SH / 10
        line(s, 0, y, SW, y, color=mix(BG, CYAN, 0.07), width=0.4)


def tower_silhouette(s, cx, base_y, height, half, tiers=8):
    body_h = height * 0.72

    def w_at(t):
        return half * (1 - 0.45 * (t ** 0.9))

    pts = []
    # left boundary, ascending in steps
    for i in range(tiers):
        t0, t1 = i / tiers, (i + 1) / tiers
        w, y0, y1 = w_at(t0), base_y - body_h * t0, base_y - body_h * t1
        pts += [(cx - w, y0), (cx - w, y1)]
    top = base_y - height
    y_body = base_y - body_h
    wtop = w_at(1.0)
    # shoulder and long spire
    pts += [
        (cx - wtop, y_body),
        (cx - 0.13, y_body),
        (cx - 0.055, y_body - 0.30),
        (cx - 0.02, top + 0.06),
        (cx, top),
        (cx + 0.02, top + 0.06),
        (cx + 0.055, y_body - 0.30),
        (cx + 0.13, y_body),
        (cx + wtop, y_body),
    ]
    # right boundary, descending in steps
    for i in reversed(range(tiers)):
        t0, t1 = i / tiers, (i + 1) / tiers
        w, y0, y1 = w_at(t0), base_y - body_h * t0, base_y - body_h * t1
        pts += [(cx + w, y1), (cx + w, y0)]
    pts.append((cx + half, base_y))

    sh = s.shapes.build_freeform(round(pts[0][0] * 100), round(pts[0][1] * 100), scale=9144)
    sh.add_line_segments([(round(x * 100), round(y * 100)) for x, y in pts[1:]], close=True)
    body = sh.convert_to_shape()
    body.fill.gradient()
    body.fill.gradient_angle = 90
    stops = body.fill.gradient_stops
    stops[0].color.rgb = RGBColor(0x18, 0x3A, 0x63)
    stops[0].position = 0.0
    stops[1].color.rgb = RGBColor(0x09, 0x16, 0x28)
    stops[1].position = 1.0
    body.line.color.rgb = mix(CYAN, BG, 0.2)
    body.line.width = Pt(1.0)
    body.shadow.inherit = False

    # tier accents
    for t in (0.16, 0.32, 0.48, 0.62):
        w = half * (1 - 0.45 * (t ** 0.9))
        y = base_y - height * 0.72 * t
        line(s, cx - w, y, cx + w, y, color=mix(CYAN, BG, 0.6), width=0.5)

    tip = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx - 0.03), Inches(top - 0.03), Inches(0.06), Inches(0.06))
    tip.fill.solid()
    tip.fill.fore_color.rgb = AMBER
    tip.line.fill.background()
    tip.shadow.inherit = False
    return body


# ---------------------------------------------------------------- slide 1
def slide_title(prs):
    s = base(prs)
    blueprint_grid(s)

    from deck_lib import set_alpha

    glow = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(7.9), Inches(0.7), Inches(5.6), Inches(5.6))
    glow.fill.solid()
    glow.fill.fore_color.rgb = CYAN
    glow.line.fill.background()
    set_alpha(glow, 0.045)
    glow.shadow.inherit = False

    tower_silhouette(s, 10.62, 6.5, 4.5, 0.52)
    line(s, 9.65, 6.5, 11.95, 6.5, color=mix(CYAN, BG, 0.45), width=1.1)

    # dimension line
    line(s, 11.7, 6.5, 11.7, 1.15, color=mix(CYAN, BG, 0.4), width=0.8)
    for yy in (6.5, 1.15):
        line(s, 11.59, yy, 11.81, yy, color=mix(CYAN, BG, 0.2), width=1.0)
    dim = tx(s, 11.87, 3.4, 0.5, 1.0, "828 m", size=9, color=CYAN, bold=True, align=PP_ALIGN.CENTER)
    dim.rotation = 270

    # wind arrows approaching the tower
    for yy in (2.45, 3.2, 3.95, 4.7, 5.45):
        arrow(s, 8.62, yy, 0.95, 0.075, mix(CYAN, BG, 0.55))
    tx(s, 8.6, 2.18, 1.0, 0.2, "WIND", size=7, color=mix(CYAN, BG, 0.2), bold=True)
    tx(s, 9.35, 6.62, 3.0, 0.22, "TECHNICAL ELEVATION  ·  163 FLOORS", size=6.8, color=DIM)

    # vertical accent
    acc = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.72), Inches(1.55), Inches(0.05), Inches(3.9))
    acc.fill.solid()
    acc.fill.fore_color.rgb = CYAN
    acc.line.fill.background()
    acc.shadow.inherit = False

    tx(s, 0.95, 1.42, 7.6, 0.3, "TECHNICAL DOSSIER  ·  WIND ENGINEERING", size=10, color=CYAN, bold=True)
    tx(s, 0.92, 1.78, 8.2, 0.9, "Burj Khalifa", size=54, color=TEXT, bold=True, font=FONT_SEMI, line=0.95)
    tx(
        s, 0.95, 2.82, 8.0, 1.0,
        "Engineering 828 metres against the wind",
        size=21, color=mix(TEXT, CYAN, 0.35), font=FONT_LIGHT, line=1.0,
    )
    tx(
        s, 0.95, 3.62, 7.4, 1.1,
        "How aerodynamic shaping, boundary-layer wind-tunnel simulation and a buttressed concrete core produced the world's tallest building.",
        size=11.5, color=MUTED, line=1.28,
    )

    stats = [("828", "m", "architectural height"), ("163", "", "floors"), ("27", "", "setbacks"), ("40+", "", "wind-tunnel tests")]
    x = 0.95
    for i, (v, u, lab) in enumerate(stats):
        tx(s, x, 5.42, 2.0, 0.5, [[(v, {"size": 26, "bold": True, "color": TEXT}), (u, {"size": 11, "color": CYAN})]], line=0.9)
        tx(s, x, 5.94, 2.1, 0.3, lab.upper(), size=7.2, color=DIM)
        if i < 3:
            line(s, x + 1.85, 5.5, x + 1.85, 6.15, color=GRID, width=0.75)
        x += 2.18

    tx(s, 0.95, 6.82, 6.5, 0.3, "TECHNICAL PRESENTATION  ·  OCTOBER 2026", size=7.5, color=DIM)
    tx(s, SW - 2.4, 6.82, 1.7, 0.3, "01 / 20", size=8, color=CYAN, bold=True, align=PP_ALIGN.RIGHT)
    notes(
        s,
        "Opening: Burj Khalifa is not primarily a gravity problem — at 828 m the wind governs. "
        "The deck follows the design logic: wind climate, vortex shedding, aerodynamic shaping, "
        "wind-tunnel programme, structural response, foundations and verification.",
    )


# ---------------------------------------------------------------- slide 2
def slide_summary(prs):
    s = base(prs)
    header(s, 2, "Executive summary", "A 828-metre wind machine — tamed by geometry")

    # two narrative panels
    panel(s, M, 1.68, 5.86, 1.95, accent=AMBER)
    tx(s, M + 0.22, 1.82, 5.4, 0.25, "THE PROBLEM", size=8.5, color=AMBER, bold=True)
    tx(
        s, M + 0.22, 2.08, 5.42, 1.45,
        [[("At 828 m, wind — not gravity — sets the structural agenda. ", {"bold": True, "color": TEXT}),
          ("A slender tower in a 50-year storm meets roughly 43 m/s at the crown; vortex shedding can lock into its first modes and amplify motion.", {"color": MUTED})]],
        size=10.3, line=1.24,
    )

    panel(s, 6.78, 1.68, 5.86, 1.95, accent=CYAN)
    tx(s, 7.0, 1.82, 5.4, 0.25, "THE ANSWER", size=8.5, color=CYAN, bold=True)
    tx(
        s, 7.0, 2.08, 5.42, 1.45,
        [[("Change the shape at every tier. ", {"bold": True, "color": TEXT}),
          ("A Y-plan with 27 spiraling setbacks prevents a coherent vortex street; 40+ tunnel tests and an aeroelastic model verified the response.", {"color": MUTED})]],
        size=10.3, line=1.24,
    )

    cards = [
        ("828", " m", "HEIGHT", CYAN),
        ("163", "", "FLOORS", CYAN),
        ("27", "", "SETBACKS", AMBER),
        ("40+", "", "TUNNEL TESTS", AMBER),
        ("1:500", "", "AEROELASTIC SCALE", BLUE),
        ("12", " mg", "PEAK ACCELERATION", GREEN),
    ]
    x = 0.7
    for v, u, lab, col in cards:
        kpi(s, x, 3.86, 1.86, 1.42, v, u, lab, accent=col)
        x += 1.99

    panel(s, M, 5.62, SW - 2 * M, 0.9, fill=PANEL2, accent=GREEN)
    tx(s, M + 0.22, 5.75, 2.1, 0.25, "DESIGN OUTCOME", size=8, color=GREEN, bold=True)
    outcomes = [
        ("Comfort target", "criteria satisfied"),
        ("0", "auxiliary dampers"),
        ("1.5 m", "total sway at the top"),
        ("22 M", "construction man-hours"),
    ]
    x = 2.55
    for v, lab in outcomes:
        tx(s, x, 5.72, 2.5, 0.32, v, size=15, color=TEXT, bold=True, font=FONT_SEMI)
        tx(s, x, 6.06, 2.5, 0.22, lab, size=7.5, color=MUTED)
        x += 2.55

    source(s, "Sources: SOM; Irwin (CTBUH 2005); Baker et al. (SEI 2015); Novak (ICC 2023). 12 milli-g is the aeroelastic prediction for a 5-year return period.")
    footer(s, 2)


# ---------------------------------------------------------------- slide 3
def slide_wind_profile(prs):
    s = base(prs)
    header(s, 3, "Wind statistics", "At 828 m, wind becomes the design driver")

    # profile curve, fitted through the two reported anchors
    u10, u600 = 23.5, 41.0
    alpha = math.log(u600 / u10) / math.log(60.0)
    pts = []
    for z in (10, 50, 100, 150, 200, 300, 400, 500, 600, 700, 828):
        pts.append((z, u10 * (z / 10) ** alpha))
    scatter_chart(
        s, 0.55, 1.62, 7.55, 4.25,
        [
            {"name": "Standard boundary-layer profile", "points": pts, "color": CYAN, "width": 2.6, "smooth": True},
        ],
        xmax=900, ymax=50, xunit=100, yunit=5,
    )
    tx(s, 0.75, 5.95, 4.0, 0.22, "HEIGHT ABOVE GROUND (m)", size=7.2, color=DIM, bold=True)
    tx(s, 0.72, 1.55, 3.0, 0.22, "MEAN HOURLY WIND (m/s)", size=7.2, color=DIM, bold=True)

    panel(s, 8.42, 1.62, 4.2, 2.42, accent=CYAN)
    tx(s, 8.62, 1.74, 3.8, 0.24, "THE DESIGN PROFILE", size=8, color=CYAN, bold=True)
    tx(s, 8.62, 2.04, 3.9, 0.45, "U(z) = U₁₀ · (z/10)^α", size=17, color=TEXT, font=FONT_SEMI, line=1.0)
    tx(s, 8.62, 2.52, 3.8, 0.9, "α ≈ 0.136  ·  fitted to the reported 10 m and 600 m values\nq(z) = ½ ρ U(z)²", size=8.8, color=MUTED, line=1.45)
    tx(s, 8.62, 3.3, 3.8, 0.5, "50-year return period, mean-hourly — not a 3-second gust.", size=7.6, color=DIM, line=1.15)
    tx(s, 8.62, 3.72, 3.8, 0.24, "Mean profile only: gust factors enter in the load cases.", size=6.8, color=DIM)

    panel(s, 8.42, 4.08, 4.2, 2.05, fill=PANEL2)
    rows = [
        ("23.5 m/s", "50-year mean-hourly wind at 10 m"),
        ("41 m/s", "50-year mean-hourly wind at 600 m"),
        ("≈ 43 m/s", "derived at the 828 m crown"),
        ("≈ 1.06 kPa", "dynamic pressure at the crown"),
    ]
    y = 4.2
    for v, lab in rows:
        tx(s, 8.62, y, 1.28, 0.3, v, size=11.5, color=CYAN, bold=True, font=FONT_SEMI)
        tx(s, 9.9, y + 0.02, 2.55, 0.3, lab, size=8.2, color=MUTED, line=1.0)
        y += 0.44

    tx(s, M, 6.38, SW - 2 * M, 0.3,
       [[("Insight: ", {"color": CYAN, "bold": True}),
         ("a 50-year event is not a rare outlier in the design process — it is the load case that sizes the lateral system.", {"color": MUTED})]],
       size=9.2)
    source(s, "Anchors: Irwin, 'The Wind Engineering of the Burj Dubai Tower' (CTBUH 2005). Curve: power-law interpolation, α fitted to 23.5 m/s at 10 m and 41 m/s at 600 m; dynamic pressure with ρ = 1.15 kg/m³.", y=6.65)
    footer(s, 3)
    notes(
        s,
        "The tower was designed for a 50-year mean-hourly wind of 23.5 m/s at 10 m in open terrain; "
        "standard boundary-layer assumptions put the 600 m value at 41 m/s. The top speed is a derived value, not a measured one. "
        "The point: the lever arm is enormous even if the wind speed is not.",
    )


# ---------------------------------------------------------------- slide 4
def slide_vortex(prs):
    s = base(prs)
    header(s, 4, "Aerodynamics", "The real enemy: vortex shedding and lock-in")

    # schematic panel
    panel(s, M, 1.62, 6.25, 4.62, fill=BG2)
    tx(s, M + 0.2, 1.74, 4.0, 0.24, "PLAN VIEW  ·  BLUFF BODY IN CROSSFLOW", size=7.8, color=DIM, bold=True)

    for yy in (2.95, 3.42, 3.89, 4.36):
        arrow(s, 0.95, yy, 1.15, 0.11, mix(CYAN, BG, 0.45))
    tx(s, 0.95, 4.56, 1.2, 0.22, "WIND", size=7.5, color=CYAN, bold=True)
    line(s, 2.15, 2.72, 2.15, 4.62, color=mix(CYAN, BG, 0.4), width=1.0, dash=None)

    body = s.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(2.28), Inches(2.62), Inches(0.62), Inches(2.08))
    body.adjustments[0] = 0.18
    body.fill.solid()
    body.fill.fore_color.rgb = PANEL2
    body.line.color.rgb = CYAN
    body.line.width = Pt(1.4)
    body.shadow.inherit = False
    tx(s, 2.16, 4.78, 0.9, 0.24, "TOWER", size=7.5, color=CYAN, bold=True, align=PP_ALIGN.CENTER)

    line(s, 2.9, 3.66, 5.95, 3.66, color=GRID, width=0.75, dash=None)
    vortices = [(3.35, 3.16, "↻"), (3.98, 4.16, "↺"), (4.61, 3.16, "↻"), (5.24, 4.16, "↺")]
    for vx, vy, glyph in vortices:
        o = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(vx - 0.23), Inches(vy - 0.23), Inches(0.46), Inches(0.46))
        o.fill.solid()
        o.fill.fore_color.rgb = mix(AMBER, BG, 0.82)
        o.line.color.rgb = AMBER
        o.line.width = Pt(1.0)
        o.shadow.inherit = False
        tx(s, vx - 0.16, vy - 0.14, 0.32, 0.28, glyph, size=11, color=AMBER, align=PP_ALIGN.CENTER)
    tx(s, 3.55, 4.62, 2.7, 0.22, "alternating vortices", size=7.5, color=AMBER)

    panel(s, M + 0.2, 5.32, 5.85, 0.78, fill=PANEL, line=GRID)
    tx(s, M + 0.36, 5.42, 5.5, 0.3, "f  =  St · U / D", size=17, color=TEXT, font=FONT_SEMI)
    tx(s, M + 2.6, 5.46, 3.35, 0.5, "St ≈ 0.12  ·  D = plan width\nresonance when f  ≈  structural mode", size=7.6, color=MUTED, line=1.3)

    # chart
    us = list(range(0, 65, 5))
    fs = [0.12 * u / 50.0 for u in us]
    scatter_chart(
        s, 7.05, 1.58, 5.58, 4.42,
        [
            {"name": "shedding frequency (D = 50 m, St = 0.12)", "points": list(zip(us, fs)), "color": CYAN, "width": 2.5, "marker": False},
            {"name": "structural mode (illustrative 0.10 Hz)", "points": [(0, 0.10), (60, 0.10)], "color": AMBER, "width": 1.8, "dash": True, "marker": False},
        ],
        xmax=60, ymax=0.16, xunit=10, yunit=0.04, yfmt="0.00",
    )
    tx(s, 7.3, 6.02, 3.5, 0.22, "WIND SPEED U (m/s)", size=7.2, color=DIM, bold=True)
    tx(s, 11.2, 1.68, 1.3, 0.35, "f (Hz)", size=7.2, color=DIM, bold=True, align=PP_ALIGN.RIGHT)
    tx(s, 10.55, 3.38, 1.95, 0.55, "lock-in ≈ 42 m/s\nif the mode were 0.10 Hz", size=8.2, color=AMBER, bold=True, line=1.15, align=PP_ALIGN.RIGHT)

    tx(s, M, 6.4, SW - 2 * M, 0.3,
       [[("Why it matters: ", {"color": AMBER, "bold": True}),
         ("a square tower sheds one strong frequency. A tapered, twisted, stepped plan smears that frequency along the height, so no single vortex street can organise.", {"color": MUTED})]],
       size=9.2)
    source(s, "Physics schematic — not a Burj Khalifa measurement. Shedding relation f = St·U/D with illustrative width and Strouhal number. Shaping strategy: SOM / Irwin (2005).", y=6.66)
    footer(s, 4, accent=AMBER)
    notes(
        s,
        "Vortex shedding is the crosswind mechanism that governs supertall towers. The chart is a teaching schematic: "
        "for a 50 m wide bluff body with St = 0.12 and a 0.10 Hz first mode, lock-in would occur near 42 m/s. "
        "Burj Khalifa avoids a single lock-in frequency by changing its plan at every tier.",
    )


# ---------------------------------------------------------------- slide 5
def slide_setbacks(prs):
    s = base(prs)
    header(s, 5, "Massing", "Confuse the wind: a Y-plan with 27 spiraling setbacks", accent=AMBER)

    tx(s, M, 1.64, 6.0, 0.24, "27 TIERS  ·  EACH ONE A DIFFERENT PLAN", size=8, color=AMBER, bold=True)

    plans = [
        (1.95, 1.05, 0.58, 0, "BASE  ·  0 m"),
        (3.95, 0.82, 0.46, 11, "MID  ·  ≈ 300 m"),
        (5.95, 0.60, 0.34, 22, "CROWN  ·  ≈ 600 m"),
    ]
    for cx, r, w, rot, lab in plans:
        y_plan(s, cx, 3.55, r, w, rot=rot, fill=CYAN, line_color=mix(CYAN, BG, 0.25), opacity=0.14, lw=1.2)
        tx(s, cx - 1.0, 4.82, 2.0, 0.24, lab, size=8, color=MUTED, bold=True, align=PP_ALIGN.CENTER)

    panel(s, 7.25, 1.66, 5.4, 4.42, fill=PANEL, accent=AMBER)
    tx(s, 7.46, 1.8, 5.0, 0.26, "THE SHAPING MECHANISM", size=8, color=AMBER, bold=True)
    tx(s, 7.46, 2.08, 5.0, 1.0,
       "Three wings set back in sequence — A, then B, then C, clockwise — so the tower presents a different width, depth and corner geometry at every level.",
       size=10.4, color=TEXT, line=1.28)

    items = [
        ("01", "No repeating silhouette", "The wind never sees the same building twice, so vortices cannot build coherence over height."),
        ("02", "Width steps down", "The plan narrows with height, cutting the reference area that generates crosswind force."),
        ("03", "Mass follows the moment", "Setbacks remove concrete where bending demand is lowest — structure and aerodynamics agree."),
    ]
    y = 3.22
    for num, head, body in items:
        tx(s, 7.46, y, 0.4, 0.3, num, size=9, color=AMBER, bold=True)
        tx(s, 7.9, y - 0.02, 4.5, 0.28, head, size=9.8, color=TEXT, bold=True)
        tx(s, 7.9, y + 0.24, 4.55, 0.55, body, size=8.2, color=MUTED, line=1.2)
        y += 0.94

    tx(s, M, 5.62, 6.25, 0.55, "The setbacks are aligned to the structural grid: columns above land on walls below, so the shape changes without column transfers.", size=8.4, color=MUTED, line=1.2)

    source(s, "27 setbacks: SOM and Wikipedia. Wing setback sequence A→B→C and differing plan at each tier: Irwin (CTBUH 2005). Plans are schematic, not construction drawings.", y=6.42)
    footer(s, 5, accent=AMBER)
    notes(
        s,
        "The Y-plan is the architectural signature, but it is also the aerodynamic device. Each wing sets back in turn, clockwise, "
        "changing the plan at every tier. The result is not one vortex street but a stack of different bluff bodies.",
    )


# ---------------------------------------------------------------- slide 6
def slide_tunnel_programme(prs):
    s = base(prs)
    header(s, 6, "Test programme", "Forty-plus tunnel tests, four families of model", accent=BLUE)

    panel(s, M, 1.6, 7.6, 3.92, fill=PANEL)
    tx(s, M + 0.2, 1.72, 4.4, 0.22, "TEST MATRIX  ·  INDICATIVE SEQUENCE", size=7.6, color=DIM, bold=True)

    cols = ["CONCEPT", "MASSING", "FINAL", "VERIFY"]
    x0, cw = 3.1, 1.26
    for i, c in enumerate(cols):
        tx(s, x0 + i * cw, 2.0, cw, 0.22, c, size=6.8, color=DIM, bold=True, align=PP_ALIGN.CENTER)

    rows = [
        ("Aeroelastic", "1:500 · dynamics", [1, 2, 3, 2]),
        ("High-Re", "1:50 · sections", [0, 1, 2, 3]),
        ("Cladding", "pressure taps", [0, 1, 3, 2]),
        ("HFFB", "rigid · base force", [1, 3, 2, 1]),
    ]
    y = 2.3
    for name, sub, vals in rows:
        line(s, M + 0.2, y, 8.05, y, color=GRID, width=0.5)
        tx(s, M + 0.22, y + 0.14, 2.0, 0.26, name, size=9.4, color=TEXT, bold=True)
        tx(s, M + 0.22, y + 0.38, 2.1, 0.22, sub, size=7.2, color=DIM)
        for i, v in enumerate(vals):
            if v == 0:
                continue
            r = 0.06 + 0.045 * v
            cx = x0 + i * cw + cw / 2
            o = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx - r), Inches(y + 0.36 - r), Inches(2 * r), Inches(2 * r))
            o.fill.solid()
            o.fill.fore_color.rgb = BLUE if v < 3 else CYAN
            from deck_lib import set_alpha
            set_alpha(o, 0.35 + 0.2 * v)
            o.line.color.rgb = BLUE if v < 3 else CYAN
            o.line.width = Pt(1.0)
            o.shadow.inherit = False
        y += 0.74
    line(s, M + 0.2, 5.26, 8.05, 5.26, color=GRID, width=0.5)
    tx(s, M + 0.22, 5.34, 7.4, 0.22, "Dot size = relative weight of that model in each phase. Counts and sequencing are indicative.",
       size=7.0, color=DIM)

    panel(s, 8.5, 1.6, 4.13, 2.24, fill=PANEL2)
    tx(s, 8.68, 1.72, 3.8, 0.22, "RWDI BOUNDARY-LAYER TUNNELS", size=7.6, color=BLUE, bold=True)
    specs = [("2.4 × 1.9 m", "aeroelastic & cladding"), ("4.9 × 2.4 m", "high-Reynolds sections"), ("55 m/s", "achievable test speed")]
    yy = 2.02
    for v, lab in specs:
        tx(s, 8.68, yy, 3.8, 0.26, v, size=12.5, color=TEXT, bold=True, font=FONT_SEMI)
        tx(s, 8.68, yy + 0.26, 3.8, 0.2, lab, size=7.2, color=MUTED)
        yy += 0.56

    panel(s, 8.5, 3.98, 4.13, 1.54, fill=PANEL2)
    tx(s, 8.68, 4.1, 3.8, 0.22, "PROGRAMME SCALE", size=7.6, color=BLUE, bold=True)
    for i, (v, lab) in enumerate([("40+", "tests"), ("2", "scales"), ("3", "outputs")]):
        tx(s, 8.68 + i * 1.3, 4.4, 1.2, 0.42, v, size=21, color=CYAN, bold=True, font=FONT_SEMI)
        tx(s, 8.68 + i * 1.3, 4.86, 1.2, 0.22, lab.upper(), size=7, color=DIM)
    tx(s, 8.68, 5.14, 3.8, 0.24, "Concept → construction, iterated with SOM.", size=7.2, color=MUTED)

    outs = [
        ("01", "Design loads", "Along- and cross-wind base moments for every direction.", CYAN),
        ("02", "Occupant comfort", "Peak accelerations at the top occupied floor.", GREEN),
        ("03", "Cladding pressures", "Local peak pressures and suctions for the façade.", AMBER),
    ]
    x = M
    for num, head, body, col in outs:
        panel(s, x, 5.66, 3.94, 0.8, fill=PANEL2)
        tx(s, x + 0.16, 5.72, 0.3, 0.2, num, size=7.5, color=col, bold=True)
        tx(s, x + 0.5, 5.71, 3.3, 0.24, head, size=9.2, color=TEXT, bold=True)
        tx(s, x + 0.5, 5.96, 3.3, 0.42, body, size=7.4, color=MUTED, line=1.1)
        x += 4.11

    source(s, "Programme facts: RWDI project record; Irwin (CTBUH 2005). Matrix is an explanatory summary, not the project's test log.", y=6.6)
    footer(s, 6, accent=BLUE)
    notes(
        s,
        "The wind-tunnel programme was not a single test. It ran through the design: massing studies, aeroelastic checks, "
        "high-Reynolds sections, cladding pressure mapping and rigid force-balance work. 40+ tests across two RWDI tunnels.",
    )


# ---------------------------------------------------------------- slide 7
def slide_reynolds(prs):
    s = base(prs)
    header(s, 7, "Similitude", "Reynolds number: the scale that cannot be faked", accent=BLUE)

    panel(s, M, 1.6, 6.2, 4.62, fill=PANEL)
    tx(s, M + 0.22, 1.72, 5.6, 0.22, "REYNOLDS SIMILARITY", size=7.8, color=BLUE, bold=True)
    tx(s, M + 0.22, 1.98, 5.7, 0.5, "Re = U · D / ν", size=24, color=TEXT, font=FONT_SEMI)
    tx(s, M + 0.22, 2.5, 5.6, 0.3, "ν = 1.5 × 10⁻⁵ m²/s   ·   D = 50 m reference width   ·   U = 40 m/s", size=7.6, color=MUTED)

    bars = [
        ("FULL SCALE", "1.3 × 10⁸", 8.12, "true flow, true aeroelasticity"),
        ("1:50 SECTION", "2.7 × 10⁶", 6.43, "high-Re check on details"),
        ("1:500 MODEL", "2.7 × 10⁵", 5.43, "whole-building dynamics"),
    ]
    y = 3.0
    for label, val, lg, note in bars:
        tx(s, M + 0.22, y, 1.55, 0.22, label, size=7.2, color=MUTED, bold=True)
        tx(s, M + 1.85, y - 0.04, 1.25, 0.26, val, size=10.5, color=CYAN, bold=True, font=FONT_SEMI)
        w = (lg - 4.0) / 4.3 * 2.55
        panel(s, M + 3.35, y + 0.02, max(0.12, w), 0.16, fill=mix(BLUE, BG, 0.45), line=None, radius=0.4)
        tx(s, M + 3.35, y + 0.22, 3.0, 0.2, note, size=6.8, color=DIM)
        y += 0.82

    tx(s, M + 0.22, 5.55, 5.6, 0.5, "Bar length ∝ log₁₀(Re). Wind-tunnel Reynolds numbers are 2–3 orders below full scale.",
       size=7.2, color=DIM, line=1.15)

    panel(s, 7.1, 1.6, 5.53, 1.98, fill=PANEL, accent=BLUE)
    tx(s, 7.3, 1.74, 5.0, 0.22, "WHY TWO MODEL SCALES?", size=7.8, color=BLUE, bold=True)
    tx(s, 7.3, 2.0, 5.05, 1.5,
       [[("A full-height 1:50 model would stand 16.6 m tall. ", {"bold": True, "color": TEXT}),
         ("So the programme splits the problem: a 1:500 whole-building aeroelastic model captures the dynamic response; "
          "1:50 sectional models push Reynolds number up where corner detail matters.", {"color": MUTED})]],
       size=9.4, line=1.32)

    panel(s, 7.1, 3.72, 5.53, 2.5, fill=PANEL2)
    tx(s, 7.3, 3.84, 5.0, 0.22, "WHAT CHANGES WITH Re", size=7.8, color=AMBER, bold=True)
    pts = [
        ("Sharp corners", "insensitive — separation is fixed"),
        ("Rounded / tapered edges", "sensitive — separation moves"),
        ("Along-wind drag", "fairly stable across scale"),
        ("Cross-wind & torsion", "the risk area — needs high Re"),
    ]
    yy = 4.18
    for a, b in pts:
        tx(s, 7.3, yy, 2.0, 0.22, a, size=7.8, color=TEXT, bold=True)
        tx(s, 9.35, yy, 3.1, 0.22, b, size=7.6, color=MUTED)
        yy += 0.46

    tx(s, M, 6.38, SW - 2 * M, 0.3,
       [[("Consequence: ", {"color": AMBER, "bold": True}),
         ("a 1:500 test alone can mispredict cross-wind force. The 1:50 checks are an insurance policy against scale effects.", {"color": MUTED})]],
       size=9.0)
    source(s, "Re computed from U = 40 m/s, D = 50 m, ν = 1.5 × 10⁻⁵ m²/s (derived, not reported test values). Model-scale strategy: Irwin (CTBUH 2005); RWDI.", y=6.66)
    footer(s, 7, accent=BLUE)
    notes(
        s,
        "Reynolds number is the similarity parameter the wind tunnel cannot match. At 1:500 the model is roughly 2.7e5; "
        "full scale is 1.3e8. Rounded or tapered corners are Reynolds-sensitive, which is why 1:50 sectional tests were used "
        "alongside the whole-building aeroelastic model.",
    )


# ---------------------------------------------------------------- slide 8
def slide_aeroelastic(prs):
    s = base(prs)
    header(s, 8, "Dynamics", "Aeroelastic response: where the tower answers back", accent=CYAN)

    import math as _m
    pts_sq, pts_y = [], []
    for i in range(0, 81):
        vr = i * 0.25
        peak = 2.85 * _m.exp(-((vr - 8.3) ** 2) / (2 * 0.9 ** 2))
        broad = 1.02 * _m.exp(-((vr - 9.0) ** 2) / (2 * 3.4 ** 2))
        pts_sq.append((vr, 0.18 + peak))
        pts_y.append((vr, 0.18 + broad))
    scatter_chart(
        s, 0.55, 1.6, 7.55, 4.3,
        [
            {"name": "Square plan — sharp lock-in", "points": pts_sq, "color": AMBER, "width": 2.2, "marker": False, "smooth": True},
            {"name": "Stepped Y-plan — smeared response", "points": pts_y, "color": CYAN, "width": 2.6, "marker": False, "smooth": True},
        ],
        xmax=20, ymax=3.4, xunit=2, yunit=0.5, xfmt="0", yfmt="0.0",
    )
    tx(s, 0.9, 5.86, 4.0, 0.22, "REDUCED WIND SPEED  Vr = U / (f · D)", size=7.2, color=DIM, bold=True)
    tx(s, 6.95, 1.7, 1.05, 0.22, "NORMALISED RMS TIP RESPONSE", size=6.8, color=DIM, bold=True, align=PP_ALIGN.RIGHT)
    line(s, 3.83, 1.95, 3.83, 5.2, color=mix(AMBER, BG, 0.55), width=0.8, dash=MSO_LINE_DASH_STYLE.DASH)
    tx(s, 3.33, 5.26, 1.0, 0.22, "Vr ≈ 8.3", size=7.4, color=AMBER, bold=True, align=PP_ALIGN.CENTER)

    panel(s, 8.2, 1.6, 4.43, 2.35, fill=PANEL, accent=AMBER)
    tx(s, 8.4, 1.72, 4.0, 0.22, "THE LOCK-IN CONDITION", size=7.8, color=AMBER, bold=True)
    tx(s, 8.4, 1.98, 4.05, 0.34, "f  =  St · U / D", size=17, color=TEXT, font=FONT_SEMI)
    tx(s, 8.4, 2.38, 4.05, 1.4,
       [[("Shedding matches a structural mode when ", {"color": MUTED}),
         ("Vr = 1 / St ≈ 8.3", {"color": TEXT, "bold": True}),
         (". A square tower concentrates energy at that one speed; a stepped plan spreads it over 5 < Vr < 14.", {"color": MUTED})]],
       size=8.6, line=1.3)

    panel(s, 8.2, 4.08, 4.43, 2.14, fill=PANEL2)
    tx(s, 8.4, 4.2, 4.0, 0.22, "AERODYNAMIC DAMPING", size=7.8, color=CYAN, bold=True)
    tx(s, 8.4, 4.46, 4.05, 1.6,
       "Moving air adds damping that grows with speed. It is not a structural damper — it is the wind resisting the tower's own motion. "
       "The aeroelastic model captures it; a rigid force-balance test cannot.",
       size=8.8, color=MUTED, line=1.3)
    tx(s, 8.4, 5.72, 4.05, 0.3, "damping ratio  ∝  ρ U D / (2 m ω)", size=9.6, color=CYAN, bold=True, font=FONT_SEMI)

    tx(s, M, 6.34, SW - 2 * M, 0.3,
       [[("Read the chart: ", {"color": CYAN, "bold": True}),
         ("shaping does not eliminate the dynamic response — it removes the sharp peak that drives the design.", {"color": MUTED})]],
       size=9.0)
    source(s, "Response curves are a teaching schematic, not measured Burj data. Lock-in condition and Vr = 1/St are standard bluff-body aerodynamics.", y=6.64)
    footer(s, 8, accent=CYAN)
    notes(
        s,
        "This is the core dynamic argument. A square plan has a narrow, violent lock-in peak near Vr = 8.3. "
        "The stepped Y-plan smears that peak across a wide band and lowers its amplitude. "
        "Aeroelastic damping — the wind damping the building — is captured only by an aeroelastic model.",
    )


# ---------------------------------------------------------------- slide 9
def slide_optimisation(prs):
    s = base(prs)
    header(s, 9, "Optimisation", "Three numbers: 37 → 19 → 12 milli-g", accent=GREEN)

    bar_chart(
        s, 0.45, 1.6, 7.4, 4.35,
        ["Initial massing\n(May 2003)", "After setbacks\n& taper", "Final shape\n+ tuning"],
        [37, 19, 12],
        [RED, AMBER, GREEN],
        vmax=45, unit=10, labels=True,
    )
    tx(s, 0.75, 1.68, 4.6, 0.22, "PREDICTED PEAK ACCELERATION  ·  MILLI-g  ·  5-YEAR RETURN", size=7.2, color=DIM, bold=True)

    panel(s, 7.9, 1.6, 4.73, 4.35, fill=PANEL, accent=GREEN)
    tx(s, 8.1, 1.72, 4.3, 0.22, "THE FEEDBACK LOOP", size=7.8, color=GREEN, bold=True)

    steps = [
        ("01", "Shape", "Move the wings, change the setbacks, adjust taper.", CYAN),
        ("02", "Test", "Aeroelastic model in the boundary layer; directional tests.", BLUE),
        ("03", "Compare", "Base moments and accelerations against criteria.", AMBER),
        ("04", "Refine", "Iterate the massing until the response flattens.", GREEN),
    ]
    y = 2.06
    for i, (num, head, body, col) in enumerate(steps):
        o = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(8.14), Inches(y), Inches(0.34), Inches(0.34))
        o.fill.solid()
        o.fill.fore_color.rgb = col
        from deck_lib import set_alpha
        set_alpha(o, 0.18)
        o.line.color.rgb = col
        o.line.width = Pt(1.0)
        o.shadow.inherit = False
        tx(s, 8.14, y + 0.04, 0.34, 0.24, num, size=7, color=col, bold=True, align=PP_ALIGN.CENTER)
        tx(s, 8.62, y - 0.02, 3.9, 0.26, head, size=9.6, color=TEXT, bold=True)
        tx(s, 8.62, y + 0.24, 3.9, 0.4, body, size=7.6, color=MUTED, line=1.15)
        if i < 3:
            line(s, 8.31, y + 0.36, 8.31, y + 0.72, color=GRID, width=1.0)
            arrow(s, 8.27, y + 0.66, 0.08, 0.1, GRID)
        y += 0.72

    tx(s, 8.1, 5.12, 4.3, 0.3, "−68%", size=22, color=GREEN, bold=True, font=FONT_SEMI)
    tx(s, 9.2, 5.2, 3.2, 0.3, "peak acceleration vs the May 2003 baseline", size=7.6, color=MUTED, line=1.1)

    panel(s, M, 6.08, SW - 2 * M, 0.5, fill=PANEL2, accent=GREEN)
    tx(s, M + 0.2, 6.2, SW - 2 * M - 0.4, 0.28,
       [[("Result: ", {"color": GREEN, "bold": True}),
         ("12 milli-g satisfies the comfort criterion with no auxiliary damping device — mass, stiffness and geometry did the work.", {"color": TEXT})]],
       size=9.0)

    source(s, "Acceleration history: Irwin (CTBUH 2005); Baker et al. (2015). Values are aeroelastic predictions at the 5-year return period, not measurements.", y=6.7)
    footer(s, 9, accent=GREEN)
    notes(
        s,
        "The headline of the wind programme: initial predictions were about 37 milli-g, more than twice the comfort target. "
        "Setbacks and taper cut it to 19; final geometry and structural tuning brought it to 12 — a 68% reduction without a tuned mass damper.",
    )


# ---------------------------------------------------------------- slide 10
def slide_comfort(prs):
    s = base(prs)
    header(s, 10, "Occupant comfort", "Comfort is a wind-load case too", accent=GREEN)

    tx(s, M, 1.66, 7.0, 0.22, "PEAK HORIZONTAL ACCELERATION  ·  5-YEAR RETURN PERIOD", size=7.6, color=DIM, bold=True)

    x0, wbar = 1.0, 11.2
    bands = [
        (0, 5, mix(GREEN, BG, 0.45), "imperceptible"),
        (5, 10, mix(TEAL, BG, 0.35), "perceptible"),
        (10, 15, mix(GREEN, BG, 0.2), "residential target"),
        (15, 25, mix(AMBER, BG, 0.2), "above target"),
        (25, 40, mix(RED, BG, 0.3), "unacceptable"),
    ]
    for a, b, col, lab in bands:
        xa = x0 + a / 40 * wbar
        wb = (b - a) / 40 * wbar
        sh = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(xa), Inches(2.0), Inches(wb), Inches(0.46))
        sh.fill.solid()
        sh.fill.fore_color.rgb = col
        from deck_lib import set_alpha
        set_alpha(sh, 0.55)
        sh.line.color.rgb = BG
        sh.line.width = Pt(1.2)
        sh.shadow.inherit = False
        tx(s, xa, 2.5, wb, 0.2, lab.upper(), size=6.4, color=DIM, align=PP_ALIGN.CENTER)
    for mg in range(0, 41, 5):
        xa = x0 + mg / 40 * wbar
        line(s, xa, 2.0, xa, 1.94, color=DIM, width=0.75)
        tx(s, xa - 0.2, 2.68, 0.4, 0.2, str(mg), size=6.8, color=MUTED, align=PP_ALIGN.CENTER)
    tx(s, x0 + wbar + 0.12, 2.08, 1.0, 0.3, "mg", size=8, color=MUTED, bold=True)

    mx = x0 + 12 / 40 * wbar
    line(s, mx, 1.72, mx, 2.46, color=TEXT, width=1.6)
    tx(s, mx - 0.7, 1.45, 1.4, 0.24, "BURJ 12 mg", size=8.4, color=TEXT, bold=True, align=PP_ALIGN.CENTER)

    tx(s, M, 3.05, 6.0, 0.22, "TYPICAL 5-YEAR COMFORT TARGETS", size=7.6, color=DIM, bold=True)
    rows = [
        ("Residential", "10 – 15 mg", "Burj residences & hotel"),
        ("Hotel", "15 – 20 mg", "Armani Hotel floors"),
        ("Office", "20 – 25 mg", "corporate suites"),
        ("Observation", "25 – 30 mg", "At the Top decks"),
    ]
    y = 3.5
    for use, val, note in rows:
        line(s, M, y, 6.3, y, color=GRID, width=0.5)
        tx(s, M, y + 0.14, 1.6, 0.24, use, size=8.6, color=TEXT, bold=True)
        tx(s, 2.35, y + 0.12, 1.35, 0.26, val, size=10, color=GREEN, bold=True, font=FONT_SEMI)
        tx(s, 3.85, y + 0.14, 2.4, 0.24, note, size=7.4, color=MUTED)
        y += 0.55
    tx(s, M, 5.85, 6.3, 0.5, "Limits are frequency-dependent and project-specific; the bands above are typical supertall practice, not code minima.",
       size=7.2, color=DIM, line=1.2)

    panel(s, 6.75, 3.15, 5.88, 2.9, fill=PANEL, accent=GREEN)
    tx(s, 6.95, 3.27, 5.4, 0.22, "WHY 12 MILLI-G IS THE RIGHT NUMBER", size=7.8, color=GREEN, bold=True)

    items = [
        ("Damping is structural", "Concrete core, finishes and foundations give roughly 1–2% of critical — the model must assume the low end."),
        ("No damper, no fallback", "Without a TMD, the margin has to come from geometry and stiffness. 12 mg leaves room for uncertainty."),
        ("Serviceability, not safety", "Comfort governs the 5-year storm; strength is governed by the 50-year load case."),
    ]
    y = 3.62
    for head, body in items:
        tx(s, 6.95, y, 0.16, 0.16, "■", size=7, color=GREEN)
        tx(s, 7.15, y - 0.03, 5.2, 0.24, head, size=8.8, color=TEXT, bold=True)
        tx(s, 7.15, y + 0.21, 5.25, 0.45, body, size=7.6, color=MUTED, line=1.18)
        y += 0.78

    source(s, "12 mg: aeroelastic prediction for the 5-year return period (Irwin 2005; Baker et al. 2015). Comfort-band thresholds are illustrative of ISO 10137 practice.", y=6.3)
    footer(s, 10, accent=GREEN)
    notes(
        s,
        "Comfort is a serviceability limit state checked at the 5-year storm, not the 50-year strength case. "
        "The design target sits inside the residential band, which is why 12 milli-g mattered. "
        "With no auxiliary damper, that margin had to be bought with shape and stiffness.",
    )


# ---------------------------------------------------------------- slide 11
def slide_core(prs):
    s = base(prs)
    header(s, 11, "Structural system", "The buttressed core: three wings holding each other up", accent=PURPLE)

    panel(s, M, 1.6, 6.55, 4.72, fill=BG2)
    tx(s, M + 0.2, 1.72, 4.6, 0.22, "PLAN  ·  TYPICAL FLOOR  ·  SCHEMATIC", size=7.6, color=DIM, bold=True)

    cx, cy, r, w = 3.75, 4.18, 2.05, 0.86
    import math as _m
    y_plan(s, cx, cy, r, w, rot=-90, fill=PURPLE, line_color=mix(PURPLE, BG, 0.2), opacity=0.16, lw=1.6)

    for ang, lab, col in [(-90, "WING A", CYAN), (30, "WING B", PURPLE), (150, "WING C", PURPLE)]:
        th = _m.radians(ang)
        lx = cx + (r * 0.78) * _m.cos(th)
        ly = cy + (r * 0.78) * _m.sin(th)
        tx(s, lx - 0.45, ly - 0.1, 0.9, 0.22, lab, size=7.2, color=col, bold=True, align=PP_ALIGN.CENTER)

    tx(s, cx - 0.5, cy - 0.09, 1.0, 0.2, "CORE", size=7.2, color=TEXT, bold=True, align=PP_ALIGN.CENTER)

    # wind arrows
    for yy in (3.2, 3.75, 4.3, 4.85):
        arrow(s, 0.95, yy, 0.5, 0.07, mix(CYAN, BG, 0.5))
    tx(s, 0.95, 3.0, 0.8, 0.2, "WIND", size=6.8, color=CYAN, bold=True)

    # load path callout
    tx(s, M + 0.2, 5.86, 4.0, 0.4, "Each wing braces the other two. Remove one and the system loses its torsional stiffness.",
       size=7.8, color=MUTED, line=1.2)

    panel(s, 7.4, 1.6, 5.23, 4.72, fill=PANEL, accent=PURPLE)
    tx(s, 7.6, 1.72, 4.8, 0.22, "HOW A BUTTRESSED CORE WORKS", size=7.8, color=PURPLE, bold=True)
    tx(s, 7.6, 1.98, 4.85, 1.0,
       "A central hexagonal hub with three residential wings. The wings are not attached decoration — they are the lateral system. "
       "Wind on one wing is resisted by the other two acting as buttresses.",
       size=9.2, color=MUTED, line=1.3)

    rows = [
        ("Torsion", "Wings at 120° put mass and stiffness away from the centre, raising torsional resistance."),
        ("Overturning", "The plan spreads compression over a wide footprint, cutting foundation pressure."),
        ("Flexibility", "Wall lengths set the period — long wings are stiff in bending but never fully closed."),
    ]
    y = 3.12
    for head, body in rows:
        tx(s, 7.6, y, 0.14, 0.14, "■", size=6.5, color=PURPLE)
        tx(s, 7.8, y - 0.04, 4.6, 0.24, head, size=8.8, color=TEXT, bold=True)
        tx(s, 7.8, y + 0.2, 4.6, 0.5, body, size=7.6, color=MUTED, line=1.2)
        y += 0.72

    panel(s, 7.4, 5.48, 5.23, 0.84, fill=PANEL2)
    tx(s, 7.6, 5.56, 1.3, 0.3, "C60 – C80", size=13, color=PURPLE, bold=True, font=FONT_SEMI)
    tx(s, 7.6, 5.92, 4.6, 0.24, "high-strength concrete in the walls and core", size=7.2, color=MUTED)
    tx(s, 9.9, 5.56, 2.6, 0.3, "3 wings · 1 core", size=10, color=TEXT, bold=True, align=PP_ALIGN.RIGHT)
    tx(s, 9.9, 5.92, 2.6, 0.24, "no perimeter moment frame", size=7.2, color=MUTED, align=PP_ALIGN.RIGHT)

    source(s, "Buttressed-core concept and concrete grades: SOM / Baker et al. Plan is a schematic, not a construction drawing.", y=6.42)
    footer(s, 11, accent=PURPLE)
    notes(
        s,
        "The buttressed core is the structural idea that makes the Y-plan work. Three wings around a hexagonal hub: "
        "each wing buttresses the other two, giving torsional stiffness without a perimeter frame. "
        "The same geometry that confuses the wind also carries the load.",
    )


# ---------------------------------------------------------------- slide 12
def slide_loadpath(prs):
    s = base(prs)
    header(s, 12, "Load path", "From wind pressure to the ground in five steps", accent=CYAN)

    panel(s, M, 1.6, 6.35, 4.72, fill=BG2)
    tx(s, M + 0.2, 1.72, 4.6, 0.22, "ELEVATION  ·  OUTRIGGER LEVELS", size=7.6, color=DIM, bold=True)

    base_y, h, cx = 6.05, 4.1, 3.55
    tower_silhouette(s, cx, base_y, h, 0.78, tiers=8)
    line(s, 2.35, base_y, 4.85, base_y, color=mix(CYAN, BG, 0.5), width=1.1)

    for t, num in [(0.24, "01"), (0.40, "02"), (0.55, "03"), (0.68, "04"), (0.80, "05")]:
        y = base_y - h * 0.72 * t
        w = 0.78 * (1 - 0.45 * (t ** 0.9))
        line(s, cx - w, y, cx + w, y, color=AMBER, width=1.6)
        tx(s, cx + w + 0.12, y - 0.1, 0.5, 0.2, num, size=6.6, color=AMBER, bold=True)

    arrow(s, 1.15, 2.35, 0.6, 0.1, CYAN)
    tx(s, 1.15, 2.1, 1.0, 0.2, "WIND", size=6.8, color=CYAN, bold=True)
    tx(s, 4.55, 2.62, 1.5, 0.3, "5 outrigger sets", size=8, color=AMBER, bold=True)

    # moment diagram
    scatter_chart(
        s, 7.15, 1.62, 5.2, 3.2,
        [{"name": "overturning moment", "points": [( (1 - z) ** 2, z) for z in [i / 40 for i in range(41)]], "color": CYAN, "width": 2.4, "marker": False, "smooth": True}],
        xmax=1.05, ymax=1.0, xunit=0.25, yunit=0.2, xfmt="0.00", yfmt="0.0",
    )
    tx(s, 7.45, 4.86, 4.2, 0.22, "M / M_base", size=7.2, color=DIM, bold=True)
    tx(s, 11.55, 1.7, 0.9, 0.22, "z / H", size=7.2, color=DIM, bold=True, align=PP_ALIGN.RIGHT)

    panel(s, 7.15, 5.0, 5.48, 1.32, fill=PANEL2)
    tx(s, 7.35, 5.1, 5.0, 0.22, "WHY OUTRIGGERS?", size=7.6, color=CYAN, bold=True)
    tx(s, 7.35, 5.36, 5.1, 0.9,
       "They couple the core to the perimeter columns, widening the effective structural depth. Five sets keep the core from carrying the whole moment alone.",
       size=7.8, color=MUTED, line=1.2)

    tx(s, M, 6.4, 6.2, 0.3,
       [[("Load path: ", {"color": CYAN, "bold": True}),
         ("façade → floor plates → core walls → outriggers → columns → raft → piles.", {"color": MUTED})]],
       size=8.2)
    source(s, "Outrigger sets and load path: SOM / Baker et al. (2015). Moment curve is the elastic cantilever relation M(z) ∝ (H − z)², normalised.", y=6.62)
    footer(s, 12, accent=CYAN)
    notes(
        s,
        "The outriggers are the load-path shortcut. Instead of the core alone resisting overturning, five sets of outrigger walls "
        "engage the perimeter columns and widen the structural depth. The moment diagram shows why the base is the expensive part.",
    )


# ---------------------------------------------------------------- slide 13
def slide_foundation(prs):
    s = base(prs)
    header(s, 13, "Foundations", "192 piles, one raft, and a lot of Dubai sand", accent=AMBER)

    panel(s, M, 1.6, 7.3, 4.72, fill=BG2)
    tx(s, M + 0.2, 1.72, 5.0, 0.22, "SECTION  ·  PILED RAFT  ·  SCHEMATIC", size=7.6, color=DIM, bold=True)

    # soil strata
    strata = [(3.23, 4.15, RGBColor(0x2A, 0x25, 0x1C)), (4.15, 5.15, RGBColor(0x26, 0x24, 0x22)), (5.15, 6.2, RGBColor(0x1C, 0x22, 0x2B))]
    for y0, y1, col in strata:
        sh = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.9), Inches(y0), Inches(6.7), Inches(y1 - y0))
        sh.fill.solid()
        sh.fill.fore_color.rgb = col
        sh.line.fill.background()
        sh.shadow.inherit = False
    line(s, 0.9, 3.23, 7.6, 3.23, color=mix(AMBER, BG, 0.35), width=1.2)
    tx(s, 0.95, 3.4, 2.4, 0.2, "SAND / WEAK ROCK", size=6.4, color=DIM)
    tx(s, 0.95, 4.42, 2.4, 0.2, "CALCARENITE", size=6.4, color=DIM)
    tx(s, 0.95, 5.5, 2.4, 0.2, "BEARING STRATUM", size=6.4, color=DIM)

    # tower stub above the raft
    for yy, ww, note in [(2.62, 4.0, None), (2.28, 3.6, None), (1.94, 3.2, "TOWER ABOVE")]:
        x0 = 4.35 - ww / 2
        sh = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(x0), Inches(yy), Inches(ww), Inches(0.34))
        sh.fill.solid()
        sh.fill.fore_color.rgb = PANEL2
        sh.line.color.rgb = mix(CYAN, BG, 0.35)
        sh.line.width = Pt(0.9)
        sh.shadow.inherit = False
        if note:
            tx(s, x0 + 0.12, yy + 0.07, 2.4, 0.2, note, size=6.4, color=MUTED, bold=True)

    # raft
    raft = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(2.1), Inches(2.95), Inches(4.5), Inches(0.28))
    raft.fill.solid()
    raft.fill.fore_color.rgb = mix(AMBER, BG, 0.45)
    raft.line.color.rgb = AMBER
    raft.line.width = Pt(1.2)
    raft.shadow.inherit = False

    # piles
    for i in range(17):
        px = 2.3 + i * 0.25
        depth = 5.95 - (0.22 if 6 <= i <= 10 else 0.0)
        pl = s.shapes.add_connector(1, Inches(px), Inches(3.23), Inches(px), Inches(depth))
        pl.line.color.rgb = mix(AMBER, BG, 0.18 if i % 2 else 0.06)
        pl.line.width = Pt(2.6)

    tx(s, 2.1, 6.04, 3.4, 0.2, "192 piles  ·  spacing schematic", size=6.6, color=DIM)

    # callouts
    line(s, 1.4, 3.09, 2.08, 3.09, color=AMBER, width=0.8)
    tx(s, 0.95, 2.55, 1.2, 0.4, "3.7 m\nraft", size=7.4, color=AMBER, bold=True, line=1.05)

    line(s, 6.35, 5.72, 6.6, 5.72, color=AMBER, width=0.8)
    tx(s, 6.62, 5.6, 0.7, 0.24, "47.45 m", size=7.0, color=AMBER, bold=True)

    panel(s, 8.05, 1.6, 4.58, 2.1, fill=PANEL, accent=AMBER)
    tx(s, 8.25, 1.72, 4.2, 0.22, "THE NUMBERS", size=7.8, color=AMBER, bold=True)
    stats = [("192", "bored piles"), ("1.5 m", "pile diameter"), ("47.45 m", "pile depth"), ("3.7 m", "raft thickness")]
    for i, (v, lab) in enumerate(stats):
        x = 8.25 + (i % 2) * 2.1
        y = 2.0 + (i // 2) * 0.78
        tx(s, x, y, 1.9, 0.3, v, size=15, color=TEXT, bold=True, font=FONT_SEMI)
        tx(s, x, y + 0.34, 1.9, 0.2, lab, size=7.2, color=MUTED)

    panel(s, 8.05, 3.86, 4.58, 2.46, fill=PANEL2)
    tx(s, 8.25, 3.98, 4.2, 0.22, "WHY A PILED RAFT?", size=7.8, color=AMBER, bold=True)
    tx(s, 8.25, 4.24, 4.25, 1.9,
       "Dubai's ground is weak carbonate sand and rock. The raft spreads load; the piles reach the stronger stratum and mobilise skin friction. "
       "Excavating the basement also removes weight — a compensated foundation, so the net pressure on the soil stays low.",
       size=8.0, color=MUTED, line=1.24)
    tx(s, 8.25, 5.78, 4.25, 0.4, "Net pressure ≈ building weight − excavated soil", size=7.4, color=CYAN, bold=True, line=1.15)

    source(s, "Pile count, diameter, depth and raft thickness: CTBUH / SOM foundation papers. Section is diagrammatic; pile spacing is not to scale.", y=6.42)
    footer(s, 13, accent=AMBER)
    notes(
        s,
        "The foundation is a piled raft: a 3.7 m raft on 192 bored piles, 1.5 m diameter and about 47 m deep. "
        "The basement excavation is part of the design — removing soil weight compensates for the tower, so net ground pressure stays manageable.",
    )


# ---------------------------------------------------------------- slide 14
def slide_construction(prs):
    s = base(prs)
    header(s, 14, "Construction", "Building 828 metres, one climbing cycle at a time", accent=AMBER)

    stats = [
        ("330,000", "m³", "concrete"),
        ("39,000", "t", "reinforcement"),
        ("C60–C80", "", "concrete cube strength"),
        ("22 M", "", "construction man-hours"),
        ("12,000", "", "workers at peak"),
        ("600 m+", "", "concrete pump height"),
    ]
    x = M
    for i, (v, u, lab) in enumerate(stats):
        col = x + (i % 3) * 2.1
        row = 1.62 + (i // 3) * 1.3
        panel(s, col, row, 1.96, 1.12, fill=PANEL)
        tx(s, col + 0.14, row + 0.1, 1.7, 0.5, [[(v, {"size": 17, "bold": True, "color": TEXT}), (u, {"size": 8, "color": AMBER, "bold": True})]], line=0.95)
        tx(s, col + 0.14, row + 0.72, 1.7, 0.34, lab, size=6.8, color=MUTED, line=1.05)
        x += 0.0

    panel(s, M, 4.34, 6.2, 2.0, fill=PANEL2, accent=AMBER)
    tx(s, M + 0.2, 4.46, 5.8, 0.22, "THE CLIMBING SYSTEM", size=7.6, color=AMBER, bold=True)
    tx(s, M + 0.2, 4.72, 5.85, 1.2,
       "A self-climbing formwork system jumped with the core. Each wing followed its own cycle, so the setbacks were built as ordinary floor steps — "
       "no transfer beams, no temporary works holding the shape.",
       size=8.4, color=MUTED, line=1.28)

    for i, (lab, val) in enumerate([("CORE", "leads"), ("WINGS", "follow"), ("SETBACKS", "stack")]):
        x2 = M + 0.2 + i * 2.0
        tx(s, x2, 5.72, 1.6, 0.2, lab, size=6.4, color=DIM, bold=True)
        tx(s, x2, 5.92, 1.6, 0.24, val, size=11, color=AMBER, bold=True, font=FONT_SEMI)

    panel(s, 7.1, 1.62, 5.53, 4.72, fill=PANEL, accent=CYAN)
    tx(s, 7.3, 1.74, 4.9, 0.22, "PROGRAMME  ·  2004 – 2010", size=7.8, color=CYAN, bold=True)

    miles = [
        ("2004", "Excavation and piling", "192 piles; 3.7 m raft cast in stages."),
        ("2005", "Tower rises", "Climbing formwork established; core leads the wings."),
        ("2007", "Level 100", "Concrete pumped beyond 400 m — a record at the time."),
        ("2009", "Topped out", "Spire completes at 828 m; cladding closes."),
        ("2010", "Opening", "Burj Khalifa opens on 4 January."),
    ]
    y = 2.14
    for i, (yr, head, body) in enumerate(miles):
        o = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(7.32), Inches(y + 0.04), Inches(0.14), Inches(0.14))
        o.fill.solid()
        o.fill.fore_color.rgb = CYAN if i < 4 else GREEN
        o.line.fill.background()
        o.shadow.inherit = False
        if i < len(miles) - 1:
            line(s, 7.39, y + 0.2, 7.39, y + 0.82, color=GRID, width=1.0)
        tx(s, 7.6, y - 0.04, 0.7, 0.24, yr, size=8, color=CYAN, bold=True)
        tx(s, 8.3, y - 0.04, 4.0, 0.24, head, size=9.0, color=TEXT, bold=True)
        tx(s, 8.3, y + 0.2, 4.05, 0.4, body, size=7.4, color=MUTED, line=1.15)
        y += 0.82

    tx(s, M, 6.42, SW - 2 * M, 0.3,
       [[("Why it matters: ", {"color": AMBER, "bold": True}),
         ("the aerodynamic shape had to be buildable. A geometry that saves wind load but adds a transfer structure would have lost the argument.", {"color": MUTED})]],
       size=8.4)
    source(s, "Quantities: SOM / CTBUH project records; ICC Building Safety Journal (2023). Programme dates are approximate milestones.", y=6.66)
    footer(s, 14, accent=AMBER)
    notes(
        s,
        "Construction is where the aerodynamic argument meets logistics. 330,000 cubic metres of concrete, 39,000 tonnes of steel, "
        "22 million man-hours. The setbacks were aligned to the structural grid so the shape could be built with a climbing formwork cycle, not special transfers.",
    )


# ---------------------------------------------------------------- slide 15
def slide_stack(prs):
    s = base(prs)
    header(s, 15, "Verification", "Five models, one building: the simulation stack", accent=BLUE)

    stages = [
        ("01", "Climate", "Met data, balloon profiles, MM5 mesoscale modelling → design speed profile.", "design wind profile", CYAN),
        ("02", "Shape", "Massing studies; setbacks and taper iterated against aerodynamic response.", "candidate massing", PURPLE),
        ("03", "Tunnel", "1:500 aeroelastic + 1:50 high-Re + cladding pressure tests.", "loads & accelerations", BLUE),
        ("04", "FE model", "Shell model of core, wings, outriggers; mode shapes and periods.", "stresses & drift", AMBER),
        ("05", "Design", "Load cases, reinforcement, comfort check, foundation design.", "construction drawings", GREEN),
    ]
    x = M
    wcard = 2.28
    for i, (num, head, body, out, col) in enumerate(stages):
        panel(s, x, 1.68, wcard, 1.98, fill=PANEL, accent=col)
        tx(s, x + 0.16, 1.82, 0.4, 0.22, num, size=7.4, color=col, bold=True)
        tx(s, x + 0.16, 2.06, wcard - 0.3, 0.3, head, size=12, color=TEXT, bold=True, font=FONT_SEMI)
        tx(s, x + 0.16, 2.46, wcard - 0.3, 0.8, body, size=7.6, color=MUTED, line=1.22)
        tx(s, x + 0.16, 3.34, wcard - 0.3, 0.22, "→ " + out, size=6.8, color=col, bold=True)
        if i < 4:
            arrow(s, x + wcard + 0.03, 2.55, 0.16, 0.12, GRID)
        x += wcard + 0.22

    panel(s, M, 3.9, 7.6, 2.4, fill=PANEL2)
    tx(s, M + 0.2, 4.02, 5.0, 0.22, "CROSS-CHECKS  ·  NO SINGLE MODEL DECIDES", size=7.6, color=BLUE, bold=True)
    checks = [
        ("CFD", "pressure fields, qualitative"),
        ("Aeroelastic", "dynamic response + damping"),
        ("HFFB", "base moments, many directions"),
        ("FE", "internal forces, drift, periods"),
    ]
    for i, (a, b) in enumerate(checks):
        x2 = M + 0.2 + (i % 2) * 3.7
        y2 = 4.5 + (i // 2) * 0.8
        tx(s, x2, y2, 1.1, 0.22, a, size=8.4, color=TEXT, bold=True)
        tx(s, x2 + 1.1, y2, 2.5, 0.22, b, size=7.4, color=MUTED)

    tx(s, M + 0.2, 5.92, 7.2, 0.24, "Four independent checks. A disagreement is a design flag, not a rounding error.",
       size=7.2, color=DIM)

    panel(s, 8.45, 3.9, 4.18, 2.4, fill=PANEL, accent=GREEN)
    tx(s, 8.65, 4.02, 3.8, 0.22, "THE RULE", size=7.6, color=GREEN, bold=True)
    tx(s, 8.65, 4.3, 3.85, 1.4,
       "Wind tunnel gives the loads. Finite element gives the stresses. Neither is trusted alone — "
       "the design only closes when both agree.",
       size=9.4, color=MUTED, line=1.35)
    tx(s, 8.65, 5.62, 3.85, 0.5, "If they disagree, re-test the geometry — don't average the answer.",
       size=8.2, color=GREEN, bold=True, line=1.2)

    tx(s, M, 6.52, SW - 2 * M, 0.3,
       [[("Practical point: ", {"color": BLUE, "bold": True}),
         ("the models were updated as the massing changed. A wind tunnel result is only valid for the geometry that was tested.", {"color": MUTED})]],
       size=8.4)
    source(s, "Workflow reconstructed from published project papers (Irwin 2005; Baker et al. 2015; RWDI). Tool names are not claimed.", y=6.72)
    footer(s, 15, accent=BLUE)
    notes(
        s,
        "Five models, not one. Climate gives the input, shape studies narrow the options, the tunnel measures the loads, "
        "the finite-element model turns loads into stresses, and the design closes the loop. Each model checks the others.",
    )


# ---------------------------------------------------------------- slide 16
def slide_monitoring(prs):
    s = base(prs)
    header(s, 16, "Monitoring", "The tower as a full-scale experiment", accent=TEAL)

    panel(s, M, 1.6, 5.5, 4.7, fill=BG2)
    tx(s, M + 0.2, 1.72, 4.4, 0.22, "INSTRUMENTATION  ·  SCHEMATIC", size=7.6, color=DIM, bold=True)

    cx, base_y, h, half = 2.85, 5.55, 3.45, 0.5
    tower_silhouette(s, cx, base_y, h, half, tiers=8)
    line(s, 1.85, base_y, 3.85, base_y, color=mix(TEAL, BG, 0.4), width=1.0)

    sensors = [
        (0.90, "GPS + anemometer", "top displacement & wind speed"),
        (0.72, "accelerometers", "3 levels, two axes"),
        (0.48, "strain gauges", "core & outrigger walls"),
        (0.22, "temperature", "thermal gradients"),
    ]
    for t, name, note in sensors:
        y = base_y - h * 0.72 * t
        w = half * (1 - 0.45 * (t ** 0.9))
        o = s.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx + w - 0.05), Inches(y - 0.05), Inches(0.12), Inches(0.12))
        o.fill.solid()
        o.fill.fore_color.rgb = TEAL
        o.line.color.rgb = BG
        o.line.width = Pt(1.0)
        o.shadow.inherit = False
        line(s, cx + w + 0.02, y, 3.55, y, color=mix(TEAL, BG, 0.5), width=0.7)
        tx(s, 3.62, y - 0.2, 2.3, 0.22, name, size=7.6, color=TEXT, bold=True)
        tx(s, 3.62, y + 0.01, 2.3, 0.2, note, size=6.6, color=MUTED)

    tx(s, M + 0.2, 5.72, 5.0, 0.5, "Sensors validate the models, not just the building: measured frequencies and damping feed back into the next design.",
       size=7.4, color=DIM, line=1.2)

    import math as _m
    pts = []
    for i in range(0, 601, 3):
        amp = 7.5 * (0.55 + 0.45 * _m.sin(2 * _m.pi * i / 190.0))
        pts.append((i, amp * _m.sin(2 * _m.pi * 0.11 * i)))
    ch = scatter_chart(
        s, 6.55, 1.6, 6.08, 2.62,
        [{"name": "acceleration", "points": pts, "color": TEAL, "width": 1.1, "marker": False}],
        xmax=600, ymax=15, xmin=0, ymin=-15, xunit=120, yunit=5, xfmt="0", yfmt="0",
    )
    low_tick_labels(ch.category_axis)
    tx(s, 7.1, 1.66, 4.2, 0.22, "TIME HISTORY  ·  ≈ 0.11 Hz FIRST MODE", size=6.8, color=DIM, bold=True)
    tx(s, 11.4, 1.7, 1.1, 0.22, "MILLI-g", size=6.8, color=DIM, bold=True, align=PP_ALIGN.RIGHT)

    panel(s, 6.55, 4.32, 6.08, 1.98, fill=PANEL, accent=TEAL)
    tx(s, 6.75, 4.44, 5.6, 0.22, "WHAT THE DATA PROVED", size=7.8, color=TEAL, bold=True)
    finds = [
        ("Frequencies", "measured modes landed close to the FE predictions — the stiffness model was right."),
        ("Damping", "roughly 1–2% of critical, amplitude-dependent; the low end governed the design."),
        ("Response", "measured accelerations stayed inside the wind-tunnel envelope."),
    ]
    y = 4.72
    for head, body in finds:
        tx(s, 6.75, y, 1.3, 0.22, head, size=8.2, color=TEXT, bold=True)
        tx(s, 8.1, y, 4.4, 0.24, body, size=7.6, color=MUTED)
        y += 0.48

    source(s, "Monitoring scope: published SHM descriptions (SmartSync / CTBUH). Time history is an illustrative 10-minute record, not measured Burj data.", y=6.5)
    footer(s, 16, accent=TEAL)
    notes(
        s,
        "The building itself is the last model. Accelerometers, GPS, anemometers and strain gauges check the assumptions: "
        "frequency, damping, and the actual acceleration envelope. Measured damping of 1–2% is why the design cannot rely on a high damping assumption.",
    )


# ---------------------------------------------------------------- slide 17
def slide_scorecard(prs):
    s = base(prs)
    header(s, 17, "Scorecard", "Did the design deliver what it promised?", accent=GREEN)

    rows = [
        ["Metric", "Design intent", "Verified outcome", "Status"],
        ["Height", "828 m architectural", "828 m, 163 floors", "MET"],
        ["Design wind", "50-yr mean-hourly, 23.5 m/s @ 10 m", "41 m/s at 600 m, ≈43 m/s at crown", "ADOPTED"],
        ["Comfort", "≤ 15 milli-g, 5-yr return", "12 milli-g predicted", "MET"],
        ["Damping devices", "avoid auxiliary dampers", "none installed", "MET"],
        ["Top sway", "≈ 1.5 m in the design storm", "within serviceability limits", "MET"],
        ["Foundation", "piled raft on 192 piles", "192 × 1.5 m, 47.45 m deep, 3.7 m raft", "MET"],
        ["Wind tunnel", "40+ tests, two scales", "1:500 aeroelastic + 1:50 high-Re", "MET"],
        ["Occupancy", "mixed-use, 163 floors", "residential, hotel, office, observation", "OPENED 2010"],
    ]
    tbl = table(s, M, 1.66, 9.05, 4.5, rows, [1.75, 2.85, 3.35, 1.1], header_size=8.0, body_size=8.2, row_h=0.46, header_h=0.42)
    for r in range(1, len(rows)):
        cell = tbl.cell(r, 3)
        run = cell.text_frame.paragraphs[0].runs[0]
        run.font.bold = True
        run.font.color.rgb = GREEN if rows[r][3] in ("MET", "ADOPTED", "OPENED 2010") else AMBER
        run.font.size = Pt(7.2)

    panel(s, 9.95, 1.66, 2.68, 2.1, fill=PANEL, accent=GREEN)
    tx(s, 10.12, 1.78, 2.4, 0.22, "THE HEADLINE", size=7.4, color=GREEN, bold=True)
    tx(s, 10.12, 2.05, 2.4, 0.5, "−68%", size=30, color=GREEN, bold=True, font=FONT_SEMI)
    tx(s, 10.12, 2.66, 2.4, 0.9, "peak acceleration versus the first massing study — without a damper.", size=7.6, color=MUTED, line=1.2)

    panel(s, 9.95, 3.92, 2.68, 2.24, fill=PANEL2)
    tx(s, 10.12, 4.04, 2.4, 0.22, "THE CAVEAT", size=7.4, color=AMBER, bold=True)
    tx(s, 10.12, 4.3, 2.4, 1.0, "Acceleration and sway are predictions, not long-term measurements. The scorecard marks design intent, not proof.", size=7.6, color=MUTED, line=1.24)
    tx(s, 10.12, 5.02, 2.4, 0.6, "Long-term monitoring, a stronger storm or added damping would update the verdict.", size=7.2, color=DIM, line=1.2)

    source(s, "Table compiled from SOM, RWDI, CTBUH and ICC sources. 'MET' = design target reported as satisfied; acceleration values are aeroelastic predictions.", y=6.36)
    footer(s, 17, accent=GREEN)
    notes(
        s,
        "The scorecard is deliberately conservative: it separates what was designed from what was measured. "
        "The 68% acceleration reduction and the no-damper outcome are the headline. The caveat matters — comfort numbers are predictions.",
    )


# ---------------------------------------------------------------- slide 18
def slide_lessons(prs):
    s = base(prs)
    header(s, 18, "Lessons", "Six principles that transferred beyond Dubai", accent=CYAN)

    lessons = [
        ("01", "Shape before stiffness", "Geometry removed 68% of the acceleration. Adding concrete would have cost far more.", "37 → 19 → 12 milli-g", CYAN),
        ("02", "Test the dynamics", "An aeroelastic model captures damping and lock-in; a rigid pressure test cannot.", "1:500 model · 40+ tests", BLUE),
        ("03", "Let structure follow wind", "Setbacks aligned to the column grid: the aerodynamic move was also the structural move.", "27 setbacks · no transfers", PURPLE),
        ("04", "Design the margin", "No damper meant the shape and stiffness had to carry the uncertainty.", "12 mg with 0 dampers", AMBER),
        ("05", "Verify at two scales", "Reynolds effects are real; the 1:50 checks are cheap insurance.", "1:50 sections vs 1:500", GREEN),
        ("06", "Design for the occupant", "Comfort, not code minimum, sized the top of the tower.", "12 mg vs 10–15 mg target", TEAL),
    ]
    for i, (num, head, body, example, col) in enumerate(lessons):
        x = M + (i % 3) * 4.0
        y = 1.66 + (i // 3) * 1.9
        panel(s, x, y, 3.82, 1.66, fill=PANEL, accent=col)
        tx(s, x + 0.2, y + 0.12, 0.5, 0.22, num, size=7.6, color=col, bold=True)
        tx(s, x + 0.2, y + 0.38, 3.4, 0.3, head, size=11.5, color=TEXT, bold=True, font=FONT_SEMI)
        tx(s, x + 0.2, y + 0.76, 3.45, 0.65, body, size=7.8, color=MUTED, line=1.25)
        tx(s, x + 0.2, y + 1.36, 3.45, 0.22, example, size=7.0, color=col, bold=True)

    panel(s, M, 5.56, SW - 2 * M, 0.82, fill=PANEL2, accent=CYAN)
    tx(s, M + 0.3, 5.56, 11.6, 0.82,
       [[("The transferable idea: ", {"color": CYAN, "bold": True}),
         ("at supertall height, the cheapest structural material is the shape of the building.", {"color": TEXT})]],
       size=12.5, line=1.1, anchor=MSO_ANCHOR.MIDDLE)

    source(s, "Synthesis of published Burj Khalifa wind-engineering papers; principles are the author's interpretation, not a client statement.", y=6.62)
    footer(s, 18, accent=CYAN)
    notes(
        s,
        "Six transferable principles. The strongest is the first: shape is cheaper than stiffness. "
        "The rest are process lessons — test dynamics, align architecture with structure, keep margin, verify at two scales, design for people.",
    )


# ---------------------------------------------------------------- slide 19
def slide_modes(prs):
    s = base(prs)
    header(s, 19, "Aeroelastic safety", "Five instabilities a supertall must survive", accent=RED)

    rows = [
        ["Instability", "Mechanism", "Burj Khalifa response"],
        ["Vortex shedding", "Alternating vortices create a cross-wind force at the shedding frequency.", "Stepped Y-plan smears the frequency; no coherent lock-in over the full height."],
        ["Lock-in", "Shedding synchronises with a structural mode and amplifies motion.", "27 setbacks and taper keep the response broad and low."],
        ["Galloping", "Negative aerodynamic damping drives divergent cross-wind oscillation.", "Bluff, stiff concrete section; no slender icy cables or sharp-section galloping."],
        ["Flutter", "Coupled torsional–translational instability above a critical wind speed.", "High torsional stiffness from the three-wing core; design speed well below critical."],
        ["Wake buffering", "Downstream towers sit in another building's wake.", "Site layout and directionality considered in the tunnel programme."],
    ]
    table(s, M, 1.66, SW - 2 * M, 4.1, rows, [3.0, 4.9, 4.0], header_size=8.6, body_size=8.2, row_h=0.62, header_h=0.44)

    panel(s, M, 5.92, SW - 2 * M, 0.58, fill=PANEL2, accent=RED)
    tx(s, M + 0.22, 6.04, SW - 2 * M - 0.4, 0.34,
       [[("Key point: ", {"color": RED, "bold": True}),
         ("comfort and safety are different checks. Comfort is a 5-year acceleration limit; safety is the 50-year strength and stability case.", {"color": TEXT})]],
       size=8.8)

    source(s, "Instability definitions: standard bluff-body aeroelasticity. Burj responses are qualitative summaries of the published shaping strategy.", y=6.62)
    footer(s, 19, accent=RED)
    notes(
        s,
        "Five instabilities, one shape response. Vortex shedding and lock-in are the design drivers; galloping and flutter are checked and kept far from the design speed. "
        "Wake buffering matters because Dubai Marina grew up around the tower.",
    )


# ---------------------------------------------------------------- slide 20
def slide_sources(prs):
    s = base(prs)
    header(s, 20, "Sources & method", "What is measured, what is modelled, what is schematic", accent=MUTED)

    panel(s, M, 1.62, 6.05, 3.5, fill=PANEL)
    tx(s, M + 0.22, 1.74, 5.6, 0.22, "PRIMARY SOURCES", size=7.8, color=CYAN, bold=True)
    srcs = [
        ("Irwin, P. A.", "'The Wind Engineering of the Burj Dubai Tower', CTBUH 2005."),
        ("Baker, W. F. et al.", "'The Structural Design of the World's Tallest Structure', SEI 2015."),
        ("RWDI", "Project record: Burj Khalifa wind tunnel testing."),
        ("SOM", "Burj Khalifa project documentation."),
        ("ICC Building Safety Journal", "'A Tall Adventure', 2023."),
        ("CTBUH", "Height criteria and project data."),
    ]
    y = 2.06
    for who, what in srcs:
        tx(s, M + 0.22, y, 1.85, 0.24, who, size=7.8, color=TEXT, bold=True)
        tx(s, M + 2.15, y, 3.75, 0.4, what, size=7.4, color=MUTED, line=1.1)
        y += 0.48

    panel(s, 6.95, 1.62, 5.68, 3.5, fill=PANEL2)
    tx(s, 7.15, 1.74, 5.2, 0.22, "HOW TO READ THE NUMBERS", size=7.8, color=AMBER, bold=True)
    legend = [
        ("REPORTED", "828 m, 163 floors, 192 piles, 40+ tests, 23.5 m/s at 10 m.", GREEN),
        ("PREDICTED", "12 milli-g, 37 → 19 → 12, 1.5 m top sway.", AMBER),
        ("DERIVED", "α ≈ 0.136, 43 m/s at the crown, Reynolds numbers.", CYAN),
        ("SCHEMATIC", "lock-in curves, moment diagram, foundation section.", PURPLE),
    ]
    y = 2.08
    for tag, text, col in legend:
        tx(s, 7.15, y, 1.2, 0.22, tag, size=6.8, color=col, bold=True)
        tx(s, 8.35, y - 0.02, 4.15, 0.4, text, size=7.6, color=MUTED, line=1.15)
        y += 0.66

    panel(s, M, 5.28, SW - 2 * M, 1.12, fill=PANEL, accent=CYAN)
    tx(s, M + 0.3, 5.44, 4.4, 0.4, "Burj Khalifa", size=18, color=TEXT, bold=True, font=FONT_SEMI)
    tx(s, M + 0.3, 5.86, 5.6, 0.3, "Wind engineering dossier  ·  20 slides", size=7.6, color=MUTED)
    tx(s, SW - M - 4.4, 5.46, 4.1, 0.8,
       "Aerodynamic shape, verified by simulation, built in concrete.",
       size=9.4, color=CYAN, align=PP_ALIGN.RIGHT, line=1.2)

    tx(s, M, 6.62, SW - 2 * M, 0.3, "Prepared as a technical explainer. No confidential project data is included.", size=7.2, color=DIM)
    footer(s, 20, accent=MUTED)
    notes(
        s,
        "Close on method: separate reported facts from predictions, derived quantities and teaching schematics. "
        "The deck's argument is that the shape did most of the engineering work — and the test programme proved it.",
    )


def build():
    prs = Presentation()
    prs.slide_width = Inches(SW)
    prs.slide_height = Inches(SH)
    cp = prs.core_properties
    cp.title = "Burj Khalifa — Wind Engineering"
    cp.subject = "Wind design statistics, tunnel simulation and structural response of the Burj Khalifa"
    cp.author = "Wind Engineering Dossier"
    cp.keywords = "Burj Khalifa, wind engineering, aeroelastic, vortex shedding, boundary layer, supertall"
    cp.category = "Technical presentation"
    cp.comments = "20-slide technical explainer. Sources and data provenance on slide 20."
    cp.last_modified_by = "Wind Engineering Dossier"
    cp.revision = 1
    now = datetime.now().replace(microsecond=0)
    cp.created = now
    cp.modified = now
    slide_title(prs)
    slide_summary(prs)
    slide_wind_profile(prs)
    slide_vortex(prs)
    slide_setbacks(prs)
    slide_tunnel_programme(prs)
    slide_reynolds(prs)
    slide_aeroelastic(prs)
    slide_optimisation(prs)
    slide_comfort(prs)
    slide_core(prs)
    slide_loadpath(prs)
    slide_foundation(prs)
    slide_construction(prs)
    slide_stack(prs)
    slide_monitoring(prs)
    slide_scorecard(prs)
    slide_lessons(prs)
    slide_modes(prs)
    slide_sources(prs)
    # ==== APPEND ====
    prs.save(OUT)
    print("saved", OUT, len(prs.slides.__iter__.__self__._sldIdLst))


if __name__ == "__main__":
    build()
