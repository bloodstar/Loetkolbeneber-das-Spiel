extends Node2D

## Kurze Schlaganimation der Nahkampfwaffe (Taste E). Wird auf Host und
## Clients gleich erzeugt und hat keinen Einfluss auf Treffer: die berechnet
## Player.melee_attack() auf dem Host. Alles wird ohne Textur gezeichnet.
## Waffen: iron = Lötkolben (Stich), sword = Schwert (60°), hammer = Hammer
## (90°), flail = Flegel (360°).

const LINE_AA: bool = false
const STEEL: Color = Color(0.80, 0.83, 0.88, 1.0)
const STEEL_DARK: Color = Color(0.32, 0.35, 0.40, 1.0)
const GRIP: Color = Color(0.16, 0.17, 0.20, 1.0)
const WOOD: Color = Color(0.55, 0.36, 0.20, 1.0)
const COPPER: Color = Color(0.78, 0.45, 0.22, 1.0)
const CHAIN: Color = Color(0.62, 0.64, 0.70, 1.0)
const DURATIONS: Dictionary = {
	"iron": 0.18,
	"sword": 0.2,
	"hammer": 0.24,
	"flail": 0.32,
}

var weapon: String = "iron"
var direction: Vector2 = Vector2.RIGHT
var reach: float = 100.0
var arc_deg: float = 60.0
var glow_color: Color = Color(1.0, 0.5, 0.2, 1.0)
# Halbe Breite des Stich-Trefferstreifens (Player._melee_targets).
var thrust_half_width: float = 16.0
var follow: Node2D = null
var duration: float:
	get:
		return float(DURATIONS.get(weapon, 0.2))

var _time: float = 0.0
# Schlagrichtung im Uhrzeigersinn oder dagegen, passend zur Blickrichtung.
var _sweep_sign: float = 1.0

func _ready() -> void:
	z_index = 7
	_sweep_sign = -1.0 if direction.x < 0.0 else 1.0
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	if _time >= duration:
		queue_free()
		return
	queue_redraw()

func _progress() -> float:
	return clampf(_time / maxf(0.01, duration), 0.0, 1.0)

func _fade() -> float:
	# Die letzten 35 % blendet die Waffe aus.
	var t := _progress()
	return 1.0 if t < 0.65 else clampf((1.0 - t) / 0.35, 0.0, 1.0)

func _draw() -> void:
	_draw_hit_zone()
	match weapon:
		"iron":
			_draw_thrust()
		"flail":
			_draw_flail()
		_:
			_draw_arc_weapon()

# --- Lötkolben: schneller Stich nach vorn und zurück ---
func _draw_thrust() -> void:
	var t := _progress()
	# Schnell ausfahren (bis 40 %), dann langsamer zurückziehen.
	var ext := ease(t / 0.4, 0.4) if t < 0.4 else 1.0 - ease((t - 0.4) / 0.6, 2.0) * 0.6
	var tip_x := maxf(18.0, reach * ext)
	var alpha := _fade()
	draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
	# Luftzug hinter der Spitze.
	for i in range(3):
		var y := (float(i) - 1.0) * 5.0
		draw_line(Vector2(tip_x * 0.25, y), Vector2(tip_x - 10.0, y * 0.4),
			Color(1.0, 1.0, 1.0, 0.25 * alpha), 1.0, LINE_AA)
	# Griff, Stahlhülse, Kupferspitze mit Glut.
	draw_line(Vector2(-4.0, 0.0), Vector2(8.0, 0.0), _a(GRIP, alpha), 5.0, LINE_AA)
	draw_line(Vector2(8.0, 0.0), Vector2(tip_x - 8.0, 0.0), _a(STEEL, alpha), 3.0, LINE_AA)
	draw_colored_polygon(PackedVector2Array([
		Vector2(tip_x - 9.0, -2.6),
		Vector2(tip_x, 0.0),
		Vector2(tip_x - 9.0, 2.6),
	]), _a(COPPER, alpha))
	draw_circle(Vector2(tip_x - 1.0, 0.0), 2.6, _a(glow_color, alpha))
	if t > 0.3 and t < 0.6:
		draw_circle(Vector2(tip_x, 0.0), 6.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Schwert und Hammer: Bogen über arc_deg ---
func _draw_arc_weapon() -> void:
	var t := ease(_progress() / 0.7, 0.35) if _progress() < 0.7 else 1.0
	var alpha := _fade()
	var half := deg_to_rad(arc_deg) * 0.5
	var base := direction.angle()
	var start := base - half * _sweep_sign
	var current := start + deg_to_rad(arc_deg) * t * _sweep_sign
	var inner := reach * (0.3 if weapon == "sword" else 0.15)
	# Schweif zwischen Startwinkel und aktueller Position.
	var trail_color := Color(1.0, 1.0, 1.0, 0.28 * alpha) if weapon == "sword" \
		else Color(1.0, 0.78, 0.45, 0.3 * alpha)
	_draw_sector(inner, reach, start, current, trail_color)
	draw_set_transform(Vector2.ZERO, current, Vector2.ONE)
	if weapon == "hammer":
		var head_x := reach - 6.0
		draw_line(Vector2(0.0, 0.0), Vector2(head_x, 0.0), _a(WOOD, alpha), 3.0, LINE_AA)
		draw_rect(Rect2(head_x - 6.0, -8.0, 12.0, 16.0), _a(STEEL_DARK, alpha), true)
		draw_rect(Rect2(head_x - 4.5, -6.5, 9.0, 13.0), _a(STEEL, alpha), true)
	else:
		draw_line(Vector2(0.0, 0.0), Vector2(8.0, 0.0), _a(GRIP, alpha), 4.0, LINE_AA)
		draw_line(Vector2(8.0, -5.0), Vector2(8.0, 5.0), _a(COPPER, alpha), 2.0, LINE_AA)
		draw_colored_polygon(PackedVector2Array([
			Vector2(9.0, -2.5),
			Vector2(reach - 8.0, -2.0),
			Vector2(reach, 0.0),
			Vector2(reach - 8.0, 2.0),
			Vector2(9.0, 2.5),
		]), _a(STEEL, alpha))
		draw_line(Vector2(10.0, -0.6), Vector2(reach - 9.0, -0.6), Color(1.0, 1.0, 1.0, 0.7 * alpha), 1.0, LINE_AA)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Flegel: eine volle Umdrehung, Kugel an der Kette ---
func _draw_flail() -> void:
	var t := ease(_progress(), 0.6)
	var alpha := _fade()
	var start := direction.angle()
	var current := start + TAU * t * _sweep_sign
	var ball_r := 7.0
	var chain_end := reach - ball_r
	_draw_sector(chain_end - 6.0, reach, start, current, Color(1.0, 0.85, 0.6, 0.22 * alpha))
	draw_set_transform(Vector2.ZERO, current, Vector2.ONE)
	draw_line(Vector2(-3.0, 0.0), Vector2(7.0, 0.0), _a(WOOD, alpha), 4.0, LINE_AA)
	var links := int(chain_end / 6.0)
	for i in range(links):
		var x := 8.0 + (chain_end - 8.0) * float(i) / maxf(1.0, float(links - 1))
		draw_circle(Vector2(x, 0.0), 1.4, _a(CHAIN, alpha))
	for i in range(6):
		var spike_dir := Vector2.from_angle(TAU * float(i) / 6.0)
		draw_line(Vector2(chain_end, 0.0) + spike_dir * ball_r * 0.6,
			Vector2(chain_end, 0.0) + spike_dir * (ball_r + 3.0), _a(STEEL_DARK, alpha), 2.0, LINE_AA)
	draw_circle(Vector2(chain_end, 0.0), ball_r, _a(STEEL_DARK, alpha))
	draw_circle(Vector2(chain_end, 0.0), ball_r - 1.5, _a(STEEL, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Zeigt die echte Trefferfläche (gleiche Werte wie Player._melee_targets),
# damit Animation und Reichweite zusammenpassen. Ein Gegner wird getroffen,
# sobald sein Körperrand diese Fläche berührt.
func _draw_hit_zone() -> void:
	var t := _progress()
	var alpha := 1.0 - t
	if alpha <= 0.0:
		return
	var fill := Color(glow_color.r, glow_color.g, glow_color.b, 0.13 * alpha)
	var edge := Color(1.0, 1.0, 1.0, 0.45 * alpha)
	if weapon == "iron" or arc_deg <= 0.0:
		draw_set_transform(Vector2.ZERO, direction.angle(), Vector2.ONE)
		draw_rect(Rect2(0.0, -thrust_half_width, reach, thrust_half_width * 2.0), fill, true)
		draw_line(Vector2(reach, -thrust_half_width), Vector2(reach, thrust_half_width), edge, 2.0, LINE_AA)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if arc_deg >= 360.0:
		draw_circle(Vector2.ZERO, reach, fill)
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, edge, 2.0, LINE_AA)
		return
	var half := deg_to_rad(arc_deg) * 0.5
	var base := direction.angle()
	_draw_sector(2.0, reach, base - half, base + half, fill)
	draw_arc(Vector2.ZERO, reach, base - half, base + half, maxi(8, int(arc_deg / 6.0)), edge, 2.0, LINE_AA)

func _draw_sector(inner: float, outer: float, from_angle: float, to_angle: float, color: Color) -> void:
	# Ein geschlossener Ring wäre ein ungültiges Polygon.
	var span := clampf(to_angle - from_angle, -TAU * 0.97, TAU * 0.97)
	if absf(span) < 0.02:
		return
	var steps := maxi(3, int(absf(span) / 0.12))
	var points := PackedVector2Array()
	for i in range(steps + 1):
		points.append(Vector2.from_angle(from_angle + span * float(i) / float(steps)) * outer)
	for i in range(steps, -1, -1):
		points.append(Vector2.from_angle(from_angle + span * float(i) / float(steps)) * inner)
	draw_colored_polygon(points, color)

func _a(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)
