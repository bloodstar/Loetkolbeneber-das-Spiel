class_name WindOverlay
extends Node2D

# Sturmwind-Modifier: Windschlieren und Blätter wehen in Windrichtung über den
# Bildschirm. Rein visuell und lokal: Jeder Client zeichnet seine eigenen
# Partikel, nur Richtung und Aktiv-Zustand kommen vom Host.

const STREAK_COUNT: int = 46
const LEAF_COUNT: int = 22
const FADE_IN_SPEED: float = 2.5
const FADE_OUT_SPEED: float = 1.2
const LEAF_COLORS: Array[Color] = [
	Color(0.42, 0.68, 0.22),
	Color(0.62, 0.74, 0.20),
	Color(0.85, 0.62, 0.16),
	Color(0.78, 0.36, 0.12),
	Color(0.55, 0.38, 0.18),
]

var _active: bool = false
var _direction: float = 1.0
var _strength: float = 0.0
var _target: float = 1.0  # Böenstärke 0..1, folgt der Host-Hüllkurve
var _time: float = 0.0
var _screen: Vector2 = Vector2(1280, 720)

var _streaks: Array[Dictionary] = []
var _leaves: Array[Dictionary] = []

func _ready() -> void:
	# Über der Welt, aber unter dem HUD (eigener CanvasLayer).
	z_index = 100
	z_as_relative = false
	visible = false
	_screen = get_viewport_rect().size
	for i in range(STREAK_COUNT):
		_streaks.append(_new_streak(true))
	for i in range(LEAF_COUNT):
		_leaves.append(_new_leaf(true))

func set_wind(active: bool, direction: float) -> void:
	var new_dir := signf(direction) if direction != 0.0 else _direction
	if active and (_strength < 0.05 or new_dir != _direction):
		# Neuer Windstoß: Partikel frisch über den Bildschirm verteilen, das
		# Einblenden kaschiert den Neustart.
		_direction = new_dir
		for i in range(_streaks.size()):
			_streaks[i] = _new_streak(true)
		for i in range(_leaves.size()):
			_leaves[i] = _new_leaf(true)
	_active = active
	if active:
		_target = 1.0
		visible = true

# Aktuelle Böe als Richtung * Stärke (-1..1); 0 = Wind aus.
func set_gust(value: float) -> void:
	if absf(value) <= 0.001:
		if _active:
			set_wind(false, _direction)
		return
	if not _active or signf(value) != _direction:
		set_wind(true, value)
	_target = clampf(absf(value), 0.0, 1.0)

func _new_streak(anywhere: bool) -> Dictionary:
	var x := randf_range(0.0, _screen.x) if anywhere else _spawn_x(randf_range(0.0, 300.0))
	return {
		"pos": Vector2(x, randf_range(0.0, _screen.y)),
		"speed": randf_range(900.0, 1500.0),
		"len": randf_range(40.0, 120.0),
		"alpha": randf_range(0.18, 0.45),
		"width": randf_range(1.2, 2.6),
		"phase": randf() * TAU,
	}

func _new_leaf(anywhere: bool) -> Dictionary:
	var x := randf_range(0.0, _screen.x) if anywhere else _spawn_x(randf_range(0.0, 200.0))
	return {
		"pos": Vector2(x, randf_range(-20.0, _screen.y)),
		"speed": randf_range(380.0, 720.0),
		"fall": randf_range(20.0, 70.0),
		"rot": randf() * TAU,
		"spin": randf_range(-7.0, 7.0),
		"size": randf_range(5.0, 10.0),
		"color": LEAF_COLORS[randi() % LEAF_COLORS.size()],
		"phase": randf() * TAU,
		"wobble": randf_range(1.5, 3.5),
	}

# Neue Partikel starten außerhalb des Bildschirms auf der Luv-Seite.
func _spawn_x(offset: float) -> float:
	return -60.0 - offset if _direction > 0.0 else _screen.x + 60.0 + offset

func _process(delta: float) -> void:
	if _active:
		_strength = move_toward(_strength, _target, delta * FADE_IN_SPEED)
	else:
		_strength = maxf(0.0, _strength - delta * FADE_OUT_SPEED)
		if _strength <= 0.0:
			visible = false
			return

	# In Bildschirmkoordinaten zeichnen, unabhängig von Kamera und Zoom.
	global_transform = get_viewport().get_canvas_transform().affine_inverse()
	_screen = get_viewport_rect().size
	_time += delta

	# Beim Abflauen werden die Partikel langsamer statt schlagartig zu stoppen.
	var speed_mult := 0.35 + 0.65 * _strength
	for i in range(_streaks.size()):
		var s: Dictionary = _streaks[i]
		var pos: Vector2 = s["pos"]
		pos.x += _direction * float(s["speed"]) * speed_mult * delta
		pos.y += sin(_time * 3.0 + float(s["phase"])) * 12.0 * delta
		s["pos"] = pos
		if _is_off_screen(pos, float(s["len"])):
			if _active:
				_streaks[i] = _new_streak(false)
			else:
				s["alpha"] = 0.0

	for i in range(_leaves.size()):
		var l: Dictionary = _leaves[i]
		var pos: Vector2 = l["pos"]
		var t := _time * float(l["wobble"]) + float(l["phase"])
		pos.x += _direction * float(l["speed"]) * speed_mult * delta
		pos.y += (float(l["fall"]) + sin(t) * 90.0) * delta
		l["pos"] = pos
		l["rot"] = float(l["rot"]) + float(l["spin"]) * delta
		if _is_off_screen(pos, 30.0) or pos.y > _screen.y + 30.0:
			if _active:
				_leaves[i] = _new_leaf(false)
			else:
				l["size"] = 0.0

	queue_redraw()

func _is_off_screen(pos: Vector2, margin: float) -> bool:
	if _direction > 0.0:
		return pos.x - margin > _screen.x + 80.0
	return pos.x + margin < -80.0

func _draw() -> void:
	if _strength <= 0.0:
		return
	for s in _streaks:
		var alpha := float(s["alpha"]) * _strength
		if alpha <= 0.0:
			continue
		var head: Vector2 = s["pos"]
		var tail := head - Vector2(_direction * float(s["len"]), 0.0)
		var mid := head.lerp(tail, 0.5)
		var w := float(s["width"])
		draw_line(tail, mid, Color(0.85, 0.95, 1.0, alpha * 0.35), w * 0.6, true)
		draw_line(mid, head, Color(0.9, 0.97, 1.0, alpha), w, true)

	for l in _leaves:
		var size := float(l["size"])
		if size <= 0.0:
			continue
		_draw_leaf(l["pos"], float(l["rot"]), size, l["color"])

func _draw_leaf(pos: Vector2, rot: float, size: float, base: Color) -> void:
	var col := base
	col.a = 0.9 * _strength
	# Spitzes Blatt: zwei Spitzen, breite Mitte.
	var pts := PackedVector2Array([
		Vector2(-size, 0.0),
		Vector2(-size * 0.3, -size * 0.45),
		Vector2(size * 0.5, -size * 0.35),
		Vector2(size, 0.0),
		Vector2(size * 0.5, size * 0.35),
		Vector2(-size * 0.3, size * 0.45),
	])
	var xf := Transform2D(rot, pos)
	draw_colored_polygon(xf * pts, col)
	var vein := col.darkened(0.35)
	draw_line(xf * Vector2(-size * 1.25, 0.0), xf * Vector2(size * 0.9, 0.0), vein, 1.0, true)
