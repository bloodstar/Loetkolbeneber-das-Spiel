extends Control

# Partikelregen hinter den Draft-Karten während eines Bonus-Zugs.
# "pinata": Konfetti und Bonbons, "gold": Goldmünzen. Rein visuell und lokal,
# Host und Clients starten ihn über die Bonus-Quelle des Drafts.

const MAX_PARTICLES := 90
const SPAWN_PER_SECOND := 34.0

const CONFETTI_COLORS := [
	Color(1.0, 0.2, 0.6),
	Color(0.2, 0.8, 1.0),
	Color(1.0, 0.9, 0.2),
	Color(0.4, 1.0, 0.3),
	Color(1.0, 0.5, 0.1),
	Color(0.7, 0.4, 1.0),
]

var kind: String = ""
var _particles: Array[Dictionary] = []
var _spawn_acc: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)

func start(rain_kind: String) -> void:
	if rain_kind == kind and is_processing():
		return
	kind = rain_kind
	_particles.clear()
	_spawn_acc = 0.0
	visible = true
	# Direkt zu Beginn ein paar Partikel über den ganzen Schirm verteilen.
	for i in range(24):
		_spawn_particle(randf_range(0.0, _area().y * 0.6))
	set_process(true)

func stop() -> void:
	kind = ""
	_particles.clear()
	set_process(false)
	visible = false
	queue_redraw()

# Sichtbare Fläche: eigene Größe, zur Sicherheit mindestens das ganze Fenster.
func _area() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(maxf(size.x, vp.x), maxf(size.y, vp.y))

func _process(delta: float) -> void:
	_spawn_acc += delta * SPAWN_PER_SECOND
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if _particles.size() < MAX_PARTICLES:
			_spawn_particle(-20.0)
	var bottom := _area().y + 30.0
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		p["t"] += delta
		p["pos"] += Vector2(p["vx"] + sin(p["t"] * p["sway_f"]) * p["sway"], p["vy"]) * delta
		p["rot"] += p["spin"] * delta
		if p["pos"].y > bottom:
			_particles.remove_at(i)
	queue_redraw()

func _spawn_particle(y: float) -> void:
	var p := {
		"pos": Vector2(randf_range(0.0, _area().x), y),
		"vx": randf_range(-15.0, 15.0),
		"vy": randf_range(90.0, 170.0),
		"sway": randf_range(10.0, 40.0),
		"sway_f": randf_range(1.5, 3.5),
		"rot": randf() * TAU,
		"spin": randf_range(-5.0, 5.0),
		"t": randf() * 3.0,
		"scale": randf_range(0.8, 1.4),
		"col": CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()],
		"candy": randf() < 0.3,
	}
	if kind == "gold":
		p["vy"] = randf_range(140.0, 240.0)
		p["sway"] = randf_range(0.0, 12.0)
		p["spin"] = randf_range(3.0, 7.0)
	_particles.append(p)

func _draw() -> void:
	for p in _particles:
		if kind == "gold":
			_draw_coin(p)
		elif p["candy"]:
			_draw_candy(p)
		else:
			_draw_confetti(p)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_confetti(p: Dictionary) -> void:
	var s: float = p["scale"]
	# Flattern: Breite schwankt mit der Drehung.
	var flip := absf(cos(p["t"] * 4.0))
	draw_set_transform(p["pos"], p["rot"], Vector2(s * maxf(0.2, flip), s))
	draw_rect(Rect2(Vector2(-5, -3), Vector2(10, 6)), p["col"])

func _draw_candy(p: Dictionary) -> void:
	var s: float = p["scale"]
	var col: Color = p["col"]
	draw_set_transform(p["pos"], p["rot"], Vector2(s, s))
	# Bonbon im Papier: Kugel mit zwei gedrehten Enden.
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-12, -5), Vector2(-12, 5)]), col.darkened(0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(12, -5), Vector2(12, 5)]), col.darkened(0.2))
	draw_circle(Vector2.ZERO, 6.5, col)
	draw_circle(Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.6))

func _draw_coin(p: Dictionary) -> void:
	var s: float = p["scale"]
	# Drehende Münze wie die Beute-Münze im Level.
	var wobble := maxf(0.15, absf(cos(p["rot"])))
	draw_set_transform(p["pos"], 0.0, Vector2(s * wobble, s))
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.85, 0.2, 0.25))
	draw_circle(Vector2.ZERO, 9.0, Color(0.9, 0.65, 0.1, 1.0))
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.88, 0.25, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -4), Vector2(2.6, 0), Vector2(0, 4), Vector2(-2.6, 0),
	]), Color(0.85, 0.55, 0.1, 1.0))
