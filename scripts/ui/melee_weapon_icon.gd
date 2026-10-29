extends Control

## Quadratisches Waffen-Icon für die Nahkampfwahl im Charakter-Tab, im Stil
## klassischer Rollenspiel-Item-Icons: dunkler Farbverlauf, Bronzerahmen,
## diagonal liegende Waffe mit Umriss und Glanzlichtern. Alles wird ohne
## Textur gezeichnet, in einem 64×64-Raster, das auf die Größe skaliert.

const GRID: float = 64.0
const OUTLINE: Color = Color(0.04, 0.03, 0.03, 1.0)
const STEEL: Color = Color(0.74, 0.78, 0.84, 1.0)
const STEEL_LIGHT: Color = Color(0.95, 0.97, 1.0, 1.0)
const STEEL_DARK: Color = Color(0.34, 0.37, 0.43, 1.0)
const GOLD: Color = Color(0.93, 0.72, 0.28, 1.0)
const GOLD_DARK: Color = Color(0.55, 0.36, 0.10, 1.0)
const WOOD: Color = Color(0.52, 0.32, 0.16, 1.0)
const WOOD_DARK: Color = Color(0.30, 0.17, 0.08, 1.0)
const LEATHER: Color = Color(0.36, 0.20, 0.11, 1.0)
const COPPER: Color = Color(0.86, 0.48, 0.20, 1.0)
const BACKGROUNDS: Dictionary = {
	"iron": [Color(0.62, 0.20, 0.06), Color(0.10, 0.02, 0.01)],
	"sword": [Color(0.20, 0.38, 0.70), Color(0.02, 0.04, 0.10)],
	"hammer": [Color(0.58, 0.42, 0.16), Color(0.08, 0.05, 0.02)],
	"flail": [Color(0.40, 0.20, 0.56), Color(0.05, 0.02, 0.08)],
}

var weapon: String = "iron":
	set(value):
		weapon = value
		_background = null
		queue_redraw()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var hovered: bool = false:
	set(value):
		hovered = value
		queue_redraw()
var dimmed: bool = false:
	set(value):
		dimmed = value
		queue_redraw()

var _background: GradientTexture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var s := minf(size.x, size.y) / GRID
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	if selected:
		# Goldener Schein außerhalb des Rahmens.
		for i in range(4):
			var grow := 4.0 - float(i)
			draw_rect(Rect2(-grow, -grow, GRID + grow * 2.0, GRID + grow * 2.0),
				Color(1.0, 0.82, 0.25, 0.18 + 0.14 * float(i)), false, 1.5)
	draw_texture_rect(_get_background(), Rect2(2, 2, GRID - 4, GRID - 4), false)
	# Innenschatten zum Rand hin.
	for i in range(5):
		var inset := 2.0 + float(i)
		draw_rect(Rect2(inset, inset, GRID - inset * 2.0, GRID - inset * 2.0),
			Color(0, 0, 0, 0.32 - 0.06 * float(i)), false, 1.0)

	# Die Waffe liegt diagonal von unten links nach oben rechts.
	draw_set_transform(Vector2(32, 32) * s, -PI * 0.25, Vector2(s, s))
	match weapon:
		"sword":
			_draw_sword()
		"hammer":
			_draw_hammer()
		"flail":
			_draw_flail()
		_:
			_draw_iron()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))

	# Glanz oben links wie bei lackierten Icons.
	draw_colored_polygon(PackedVector2Array([
		Vector2(3, 3), Vector2(40, 3), Vector2(3, 30),
	]), Color(1, 1, 1, 0.07))
	if dimmed:
		draw_rect(Rect2(2, 2, GRID - 4, GRID - 4), Color(0.05, 0.05, 0.06, 0.62), true)
	elif hovered and not selected:
		draw_rect(Rect2(2, 2, GRID - 4, GRID - 4), Color(1, 1, 1, 0.08), true)
	_draw_frame()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frame() -> void:
	var outer := Color(0.03, 0.02, 0.01, 1.0)
	var metal := Color(1.0, 0.86, 0.35, 1.0) if selected else Color(0.62, 0.50, 0.30, 1.0)
	var metal_dark := Color(0.62, 0.40, 0.08, 1.0) if selected else Color(0.30, 0.23, 0.13, 1.0)
	if dimmed:
		metal = metal.darkened(0.45)
		metal_dark = metal_dark.darkened(0.45)
	draw_rect(Rect2(0.5, 0.5, GRID - 1.0, GRID - 1.0), outer, false, 1.0)
	draw_rect(Rect2(1.5, 1.5, GRID - 3.0, GRID - 3.0), metal_dark, false, 1.0)
	# Obere/linke Kante heller als untere/rechte: wirkt wie ein Wulst.
	draw_line(Vector2(2, 2.5), Vector2(GRID - 2, 2.5), metal, 1.2)
	draw_line(Vector2(2.5, 2), Vector2(2.5, GRID - 2), metal, 1.2)
	draw_line(Vector2(2, GRID - 2.5), Vector2(GRID - 2, GRID - 2.5), metal_dark.darkened(0.3), 1.2)
	draw_line(Vector2(GRID - 2.5, 2), Vector2(GRID - 2.5, GRID - 2), metal_dark.darkened(0.3), 1.2)
	draw_rect(Rect2(3.5, 3.5, GRID - 7.0, GRID - 7.0), Color(0, 0, 0, 0.85), false, 1.0)
	# Kleine Eckbeschläge.
	for corner in [Vector2(3, 3), Vector2(GRID - 3, 3), Vector2(3, GRID - 3), Vector2(GRID - 3, GRID - 3)]:
		draw_circle(corner, 2.0, metal_dark)
		draw_circle(corner, 1.1, metal)

func _get_background() -> GradientTexture2D:
	if _background != null:
		return _background
	var colors: Array = BACKGROUNDS.get(weapon, BACKGROUNDS["iron"])
	var gradient := Gradient.new()
	gradient.set_color(0, colors[0])
	gradient.set_color(1, colors[1])
	gradient.add_point(0.45, colors[0].lerp(colors[1], 0.55))
	_background = GradientTexture2D.new()
	_background.gradient = gradient
	_background.fill = GradientTexture2D.FILL_RADIAL
	_background.fill_from = Vector2(0.45, 0.4)
	_background.fill_to = Vector2(1.05, 1.05)
	_background.width = 64
	_background.height = 64
	return _background

# Gefülltes Polygon mit dunklem Umriss.
func _shape(points: PackedVector2Array, fill: Color, outline_width: float = 1.6) -> void:
	draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, OUTLINE, outline_width, true)

func _box(x0: float, x1: float, half_h: float, fill: Color) -> void:
	_shape(PackedVector2Array([
		Vector2(x0, -half_h), Vector2(x1, -half_h), Vector2(x1, half_h), Vector2(x0, half_h),
	]), fill)

func _gem(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + 0.9, OUTLINE)
	draw_circle(center, radius, color)
	draw_circle(center + Vector2(-radius * 0.35, -radius * 0.35), radius * 0.4, Color(1, 1, 1, 0.75))

# --- Lötkolben: Gummigriff, Stahlschaft, glühende Kupferspitze ---
func _draw_iron() -> void:
	# Hitzeschein hinter der Spitze.
	for i in range(4):
		draw_circle(Vector2(23, 0), 12.0 - float(i) * 2.6, Color(1.0, 0.55, 0.15, 0.10 + 0.07 * float(i)))
	_shape(PackedVector2Array([
		Vector2(-27, -4.2), Vector2(-8, -5.2), Vector2(-5, -3.6),
		Vector2(-5, 3.6), Vector2(-8, 5.2), Vector2(-27, 4.2), Vector2(-28.5, 0),
	]), Color(0.16, 0.17, 0.21))
	for x in [-23.0, -19.0, -15.0, -11.0]:
		draw_line(Vector2(x, -4.4), Vector2(x, 4.4), Color(0.30, 0.32, 0.38), 1.2)
	draw_line(Vector2(-26, -2.6), Vector2(-7, -3.4), Color(1, 1, 1, 0.22), 1.0)
	_box(-5, -1, 3.2, GOLD)
	draw_line(Vector2(-4.5, -2.0), Vector2(-1.5, -2.0), Color(1, 0.95, 0.7, 0.9), 0.8)
	_box(-1, 15, 1.8, STEEL)
	draw_line(Vector2(-0.5, -0.8), Vector2(14.5, -0.8), STEEL_LIGHT, 0.7)
	_shape(PackedVector2Array([
		Vector2(15, -3.0), Vector2(26.5, 0), Vector2(15, 3.0),
	]), COPPER)
	draw_line(Vector2(16, -1.6), Vector2(24, -0.3), Color(1.0, 0.85, 0.55, 0.95), 0.9)
	draw_circle(Vector2(25.2, 0), 1.8, Color(1.0, 0.92, 0.55))

# --- Schwert: Klinge mit Hohlkehle, Goldparierstange, Lederheft ---
func _draw_sword() -> void:
	_shape(PackedVector2Array([
		Vector2(-6, -3.6), Vector2(20, -3.2), Vector2(28.5, 0),
		Vector2(20, 3.2), Vector2(-6, 3.6),
	]), STEEL)
	# Untere Klingenhälfte dunkler, Hohlkehle in der Mitte.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 0.3), Vector2(27, 0.3), Vector2(20, 2.6), Vector2(-5, 2.9),
	]), STEEL_DARK.lerp(STEEL, 0.4))
	draw_line(Vector2(-4, 0), Vector2(19, 0), STEEL_DARK, 1.0)
	draw_line(Vector2(-4, -2.5), Vector2(20, -2.2), STEEL_LIGHT, 0.8)
	draw_circle(Vector2(24, -0.8), 1.0, Color(1, 1, 1, 0.9))
	# Parierstange mit Edelstein.
	_shape(PackedVector2Array([
		Vector2(-9, -11), Vector2(-5.5, -10), Vector2(-5.5, 10), Vector2(-9, 11),
	]), GOLD)
	draw_line(Vector2(-8.4, -9.5), Vector2(-8.4, 9.5), Color(1, 0.95, 0.7, 0.8), 0.8)
	_gem(Vector2(-7.2, 0), 2.0, Color(0.15, 0.55, 1.0))
	# Heft mit Lederwicklung.
	_box(-20, -9, 2.6, LEATHER)
	for x in [-18.5, -15.5, -12.5]:
		draw_line(Vector2(x, -2.6), Vector2(x + 2.2, 2.6), Color(0.62, 0.40, 0.22), 1.0)
	_shape(PackedVector2Array([
		Vector2(-20, -4.2), Vector2(-25, -3.0), Vector2(-27, 0),
		Vector2(-25, 3.0), Vector2(-20, 4.2),
	]), GOLD)
	_gem(Vector2(-23.2, 0), 1.6, Color(0.9, 0.12, 0.12))

# --- Hammer: Holzstiel, schwerer Stahlkopf mit Nieten ---
func _draw_hammer() -> void:
	_box(-27, 12, 2.6, WOOD)
	draw_line(Vector2(-26, -1.0), Vector2(11, -1.0), Color(0.72, 0.50, 0.28), 0.9)
	draw_line(Vector2(-22, 1.0), Vector2(4, 1.2), WOOD_DARK, 0.8)
	# Lederwicklung am Griffende.
	_box(-27, -16, 3.2, LEATHER)
	for x in [-25.0, -22.0, -19.0]:
		draw_line(Vector2(x, -3.2), Vector2(x + 2.0, 3.2), Color(0.60, 0.40, 0.22), 1.0)
	draw_circle(Vector2(-27.5, 0), 2.6, GOLD_DARK)
	# Kopf quer zum Stiel.
	_shape(PackedVector2Array([
		Vector2(8, -14), Vector2(22, -14), Vector2(24, -12), Vector2(24, 12),
		Vector2(22, 14), Vector2(8, 14), Vector2(6.5, 12), Vector2(6.5, -12),
	]), STEEL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, -13), Vector2(23, -12), Vector2(23, 12), Vector2(16, 13),
	]), STEEL_DARK.lerp(STEEL, 0.35))
	# Schlagflächen oben und unten.
	_box(7.5, 23, 1.6, STEEL_DARK)
	draw_line(Vector2(8, -13), Vector2(8, 13), STEEL_LIGHT, 1.0)
	draw_line(Vector2(9, -13.2), Vector2(21, -13.2), STEEL_LIGHT, 0.8)
	for p in [Vector2(11, -9), Vector2(19, -9), Vector2(11, 9), Vector2(19, 9)]:
		draw_circle(p, 1.4, OUTLINE)
		draw_circle(p, 0.9, GOLD)
	# Goldband zwischen Kopf und Stiel.
	_box(3, 6.5, 3.6, GOLD)

# --- Flegel: Stiel, Kette, Stachelkugel ---
func _draw_flail() -> void:
	_box(-27, -7, 3.0, WOOD)
	draw_line(Vector2(-26, -1.2), Vector2(-8, -1.2), Color(0.72, 0.50, 0.28), 0.9)
	_box(-28.5, -25, 3.8, GOLD)
	_box(-8, -4.5, 3.8, GOLD)
	draw_circle(Vector2(-3.5, 0), 1.6, GOLD_DARK)
	# Kettenglieder abwechselnd längs und quer, leicht durchhängend.
	var links := [Vector2(-0.5, 0.8), Vector2(3.2, 2.0), Vector2(6.9, 2.6), Vector2(10.6, 2.4)]
	for i in range(links.size()):
		var c: Vector2 = links[i]
		if i % 2 == 0:
			draw_rect(Rect2(c.x - 2.2, c.y - 1.3, 4.4, 2.6), OUTLINE, false, 1.8)
			draw_rect(Rect2(c.x - 2.2, c.y - 1.3, 4.4, 2.6), STEEL, false, 0.9)
		else:
			draw_line(c + Vector2(-2.0, 0), c + Vector2(2.0, 0), OUTLINE, 2.4)
			draw_line(c + Vector2(-2.0, 0), c + Vector2(2.0, 0), STEEL_LIGHT, 1.0)
	var ball := Vector2(19, 1.5)
	var radius := 8.0
	for i in range(8):
		var dir := Vector2.from_angle(TAU * float(i) / 8.0 + 0.2)
		var side := dir.orthogonal() * 1.8
		_shape(PackedVector2Array([
			ball + dir * (radius - 1.0) + side,
			ball + dir * (radius + 4.5),
			ball + dir * (radius - 1.0) - side,
		]), STEEL_LIGHT if dir.y < 0.0 else STEEL, 1.2)
	draw_circle(ball, radius + 1.0, OUTLINE)
	draw_circle(ball, radius, STEEL_DARK)
	draw_circle(ball + Vector2(-1.4, -1.4), radius * 0.72, STEEL)
	draw_circle(ball + Vector2(-3.0, -3.0), radius * 0.28, Color(1, 1, 1, 0.8))
