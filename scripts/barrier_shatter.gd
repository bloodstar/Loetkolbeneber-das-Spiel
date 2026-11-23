class_name BarrierShatter
extends Node2D

## Bruch der Barriere: heller Blitz, Druckwelle und Glasscherben in der
## Barrierefarbe, die vom Einschlag weg fliegen, sich drehen und fallen.
## Wird über NetFx ("barrier_break") auch auf Clients abgespielt.

const LIFETIME: float = 0.6
const SHARD_COUNT: int = 16
const RADIUS: float = BarrierDome.RADIUS
const GRAVITY: float = 520.0

var color: Color = Color(0.3, 0.8, 1.0)
var impact_dir: Vector2 = Vector2.ZERO
var _time: float = 0.0
# Scherbe: {"p": Pos, "v": Tempo, "r": Drehung, "w": Drehtempo, "pts": Form}
var _shards: Array = []

static func spawn(parent: Node, pos: Vector2, shard_color: Color, dir: Vector2) -> void:
	var fx := BarrierShatter.new()
	fx.color = shard_color
	fx.impact_dir = dir
	fx.z_index = 7
	fx.add_to_group("round_effect")
	parent.add_child(fx)
	fx.global_position = pos

func _ready() -> void:
	var away := -impact_dir.normalized() if impact_dir.length_squared() > 0.01 else Vector2.ZERO
	for i in range(SHARD_COUNT):
		var angle := TAU * (float(i) + randf_range(-0.3, 0.3)) / float(SHARD_COUNT)
		var out := Vector2.from_angle(angle)
		var speed := randf_range(140.0, 300.0)
		# Vom Einschlag weg etwas schneller.
		speed *= 1.0 + 0.6 * maxf(0.0, out.dot(away))
		var size := randf_range(3.5, 7.0)
		var pts := PackedVector2Array([
			Vector2(size, 0.0),
			Vector2(-size * 0.6, size * randf_range(0.4, 0.8)),
			Vector2(-size * randf_range(0.3, 0.7), -size * randf_range(0.4, 0.9)),
		])
		_shards.append({
			"p": BarrierDome.CENTER + out * RADIUS * randf_range(0.75, 1.0),
			"v": out * speed + Vector2(0.0, -60.0),
			"r": randf() * TAU,
			"w": randf_range(-14.0, 14.0),
			"pts": pts,
		})

func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	for s in _shards:
		var v: Vector2 = s["v"]
		v.y += GRAVITY * delta
		v *= 1.0 - 1.8 * delta
		s["v"] = v
		s["p"] = (s["p"] as Vector2) + v * delta
		s["r"] = float(s["r"]) + float(s["w"]) * delta
	queue_redraw()

func _draw() -> void:
	var t := _time / LIFETIME
	var base := color
	base.a = 1.0
	# Blitz in der Mitte.
	var flash_t := clampf(_time / 0.12, 0.0, 1.0)
	if flash_t < 1.0:
		var flash := Color(1.0, 1.0, 1.0, (1.0 - flash_t) * 0.75)
		draw_circle(BarrierDome.CENTER, RADIUS * (0.8 + 0.3 * flash_t), flash, true, -1.0, true)
	# Druckwelle.
	var wave_t := clampf(_time / 0.3, 0.0, 1.0)
	if wave_t < 1.0:
		var r := RADIUS * (1.0 + 0.9 * ease(wave_t, 0.4))
		var glow := base.lightened(0.3)
		glow.a = (1.0 - wave_t) * 0.45
		draw_arc(BarrierDome.CENTER, r, 0.0, TAU, 48, glow, 7.0 * (1.0 - wave_t) + 1.0, true)
		var ring := Color(1.0, 1.0, 1.0, (1.0 - wave_t) * 0.9)
		draw_arc(BarrierDome.CENTER, r, 0.0, TAU, 48, ring, 1.6, true)
	# Scherben.
	# Kräftige Farbe mit dunklerem Rand und weißer Glanzkante, damit die
	# Scherben auf hellen wie dunklen Maps erkennbar sind.
	var fade := 1.0 - t * t
	var fill := base.lightened(0.15)
	fill.a = 0.9 * fade
	var edge := base.darkened(0.35)
	edge.a = 0.9 * fade
	var shine := Color(1.0, 1.0, 1.0, 0.95 * fade)
	for s in _shards:
		var xf := Transform2D(float(s["r"]), s["p"])
		var pts: PackedVector2Array = xf * (s["pts"] as PackedVector2Array)
		draw_colored_polygon(pts, fill)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, edge, 1.0, true)
		draw_line(pts[0], pts[1], shine, 1.0, true)
