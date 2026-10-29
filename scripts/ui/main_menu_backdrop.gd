class_name MainMenuBackdrop
extends Control

# Hintergrund des Hauptmenüs im Platinen-Look: dunkles Board mit leuchtenden
# Leiterbahnen, Chips und ein Rahmen um die Menüknöpfe. Links und rechts
# steht je ein Eber mit glühendem Lötkolben, an dessen Spitze Funken sprühen.
# Ab und zu schießt einer der beiden in hohem Bogen über das Menü; wird der
# andere getroffen, kneift er kurz die Augen zu. Alles wird im Code gezeichnet bzw. aus den Spielfiguren (PigCharacter,
# MagicWand) zusammengesetzt.

const BOARD: Color = Color(0.02, 0.03, 0.06, 1.0)
const TRACE: Color = Color(0.1, 0.85, 0.8, 1.0)
const PAD: Color = Color(0.5, 1.0, 0.95, 1.0)
const CHIP: Color = Color(0.01, 0.02, 0.03, 0.95)
const PIN: Color = Color(0.45, 0.6, 0.62, 0.55)
const FRAME_FILL: Color = Color(0.02, 0.04, 0.07, 0.85)
const GRID: float = 20.0
const SEED: int = 23
const PIG_SCALE: float = 9.0
const WAND_SCALE: float = 7.0
const FRAME_PADDING: Vector2 = Vector2(60.0, 40.0)
const SHOT_INTERVAL_MIN: float = 2.5
const SHOT_INTERVAL_MAX: float = 5.5
const SHOT_FLIGHT_TIME: float = 1.15
# Unter BLOOD_MIN_STRENGTH der Figur: nur Augen zukneifen und Zucken, kein Blut.
const HIT_STRENGTH: float = 0.35

# Die beiden Eber: Fell, Augen, Hose, Glutfarbe, Spitzenform, Seite.
const HEROES: Array[Dictionary] = [
	{"fur": Color(0.91, 0.6, 0.67), "eyes": Color(0.12, 0.12, 0.15), "pants": Color(0.5, 0.2, 0.6),
		"heat": Color(1.0, 0.35, 0.7), "tip": "flame", "x": 0.16, "flip": false},
	{"fur": Color(0.6, 0.62, 0.68), "eyes": Color(0.12, 0.12, 0.15), "pants": Color(0.15, 0.4, 0.4),
		"heat": Color(0.1, 0.9, 0.8), "tip": "orb", "x": 0.84, "flip": true},
]

# Rahmen um diesen Knoten (die Knopfspalte), wird vom Hauptmenü gesetzt.
var frame_target: Control = null

var _traces: Array[PackedVector2Array] = []
var _chips: Array[Rect2] = []
var _time: float = 0.0
var _soft_texture: GradientTexture2D = null
var _heroes: Array[Dictionary] = []
var _shots: Array[Dictionary] = []
var _shot_timer: float = 2.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_soft_texture = _make_soft_texture()
	_rng.randomize()
	_shot_timer = _rng.randf_range(1.2, 2.5)
	for cfg in HEROES:
		_heroes.append(_build_hero(cfg))
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	# Leichtes Wippen der Lötkolben; Funken folgen der Spitze.
	for i in range(_heroes.size()):
		var hero: Dictionary = _heroes[i]
		var wand: MagicWand = hero["wand"]
		hero["recoil"] = maxf(0.0, float(hero.get("recoil", 0.0)) - delta * 4.0)
		var side := -1.0 if bool((hero["cfg"] as Dictionary)["flip"]) else 1.0
		wand.rotation = float(hero["rotation"]) + sin(_time * 1.6 + i * 2.1) * 0.06 - float(hero["recoil"]) * 0.35 * side
		var sparks: CPUParticles2D = hero["sparks"]
		sparks.position = wand.transform * Vector2(MagicWand.TIP_END_X, 0.0)
	_update_shots(delta)
	queue_redraw()

# --- Schüsse ---

func _update_shots(delta: float) -> void:
	_shot_timer -= delta
	if _shot_timer <= 0.0 and _heroes.size() >= 2:
		_shot_timer = _rng.randf_range(SHOT_INTERVAL_MIN, SHOT_INTERVAL_MAX)
		var shooter := _rng.randi_range(0, _heroes.size() - 1)
		_fire(shooter, 1 - shooter if _heroes.size() == 2 else (shooter + 1) % _heroes.size())
	for i in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[i]
		shot["t"] = float(shot["t"]) + delta / SHOT_FLIGHT_TIME
		if float(shot["t"]) >= 1.0:
			_hit(int(shot["target"]), shot)
			_shots.remove_at(i)

func _fire(shooter: int, target: int) -> void:
	var hero: Dictionary = _heroes[shooter]
	var sparks: Node2D = hero["sparks"]
	var target_pig: Node2D = _heroes[target]["pig"]
	hero["recoil"] = 1.0
	_shots.append({
		"from": sparks.position,
		"to": target_pig.position + Vector2(0.0, -6.0 * PIG_SCALE),
		"apex": size.y * 0.27,
		"t": 0.0,
		"color": hero["heat"],
		"target": target,
	})
	SoundManager.play_sound("shoot", 0.15, -2.0)

func _hit(target: int, shot: Dictionary) -> void:
	var pig: PigCharacter = _heroes[target]["pig"]
	var from: Vector2 = shot["from"]
	var to: Vector2 = shot["to"]
	pig.play_hit(Vector2(signf(to.x - from.x), 0.0), HIT_STRENGTH)
	SoundManager.play_sound("hit", 0.15, -2.0)

func _shot_position(shot: Dictionary, t: float) -> Vector2:
	# Hoher Bogen über dem Menü-Rahmen: Scheitel bei "apex" (Bildschirm-y).
	var from: Vector2 = shot["from"]
	var to: Vector2 = shot["to"]
	var base := from.lerp(to, t)
	var lift := minf(from.y, to.y) - float(shot["apex"])
	return base - Vector2(0.0, 4.0 * lift * t * (1.0 - t))

# --- Aufbau ---

func _build_hero(cfg: Dictionary) -> Dictionary:
	var flip := bool(cfg["flip"])
	var heat: Color = cfg["heat"]

	var pig := PigCharacter.new()
	pig.follow_parent_motion = false
	pig.flip_h = flip
	pig.scale = Vector2.ONE * PIG_SCALE
	pig.setup(cfg["fur"], cfg["eyes"], cfg["pants"])
	add_child(pig)

	var wand := MagicWand.new()
	var side := -1.0 if flip else 1.0
	wand.scale = Vector2(WAND_SCALE * side, WAND_SCALE)
	wand.setup(str(cfg["tip"]), heat)
	add_child(wand)

	var sparks := CPUParticles2D.new()
	sparks.amount = 22
	sparks.lifetime = 0.5
	sparks.direction = Vector2(0, -1)
	sparks.spread = 120.0
	sparks.gravity = Vector2(0, 480)
	sparks.initial_velocity_min = 70.0
	sparks.initial_velocity_max = 200.0
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, heat.lightened(0.7))
	ramp.add_point(0.4, Color(heat.r, heat.g, heat.b, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(heat.r, heat.g, heat.b, 0.0))
	sparks.color_ramp = ramp
	add_child(sparks)

	return {"cfg": cfg, "pig": pig, "wand": wand, "sparks": sparks, "heat": heat,
		"rotation": deg_to_rad(-70.0)}

func _make_soft_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

func _layout() -> void:
	var area := size
	if area.x < 10.0 or area.y < 10.0:
		return
	_generate_board(area)
	for hero in _heroes:
		var cfg: Dictionary = hero["cfg"]
		var side := -1.0 if bool(cfg["flip"]) else 1.0
		var pig_pos := Vector2(area.x * float(cfg["x"]), area.y * 0.68)
		var pig: Node2D = hero["pig"]
		var wand: Node2D = hero["wand"]
		pig.position = pig_pos
		wand.position = pig_pos + Vector2(40.0 * side, 15.0)

func _generate_board(area: Vector2) -> void:
	_traces.clear()
	_chips.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var cols := int(area.x / GRID)
	var rows := int(area.y / GRID)
	var directions := [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(1, -1)]
	var count := int(area.x * area.y / 18000.0)
	for i in range(count):
		var point := Vector2(rng.randi_range(0, cols), rng.randi_range(0, rows)) * GRID
		var line := PackedVector2Array([point])
		for s in range(rng.randi_range(2, 5)):
			var dir: Vector2 = directions[rng.randi_range(0, directions.size() - 1)]
			point += dir * float(rng.randi_range(2, 9)) * GRID
			line.append(point)
		_traces.append(line)
	for i in range(int(count / 5.0)):
		var chip_size := Vector2(rng.randi_range(40, 110), rng.randi_range(24, 60))
		_chips.append(Rect2(Vector2(rng.randf_range(0, area.x), rng.randf_range(0, area.y)), chip_size))

# --- Zeichnen ---

func _draw() -> void:
	var area := size
	draw_rect(Rect2(Vector2.ZERO, area), BOARD, true)
	# Leiterbahnen mit weichem Schein: breit und blass, darüber schmal und hell.
	for line in _traces:
		draw_polyline(line, Color(TRACE.r, TRACE.g, TRACE.b, 0.08), 9.0, true)
	for line in _traces:
		draw_polyline(line, Color(TRACE.r, TRACE.g, TRACE.b, 0.5), 2.5, true)
		for point in [line[0], line[line.size() - 1]]:
			draw_circle(point, 6.0, Color(PAD.r, PAD.g, PAD.b, 0.55))
			draw_circle(point, 2.5, BOARD)
	for chip in _chips:
		draw_rect(chip, CHIP, true)
		var x := chip.position.x + 8.0
		while x < chip.end.x - 6.0:
			draw_rect(Rect2(x, chip.position.y - 6.0, 4.0, 6.0), PIN, true)
			draw_rect(Rect2(x, chip.end.y, 4.0, 6.0), PIN, true)
			x += 12.0

	_draw_vignette(area)
	# Türkiser Schein hinter dem Titel.
	_draw_glow(Vector2(area.x * 0.5, area.y * 0.17), area.x * 0.28, Color(TRACE.r, TRACE.g, TRACE.b, 0.16))

	# Leuchten an den Lötspitzen.
	for hero in _heroes:
		var heat: Color = hero["heat"]
		var pulse := 0.85 + sin(_time * 9.0 + heat.r * 5.0) * 0.08 + sin(_time * 23.0) * 0.05
		var sparks: Node2D = hero["sparks"]
		_draw_glow(sparks.position, 48.0 * pulse, Color(heat.r, heat.g, heat.b, 0.8))

	_draw_menu_frame()
	_draw_shots()

func _draw_shots() -> void:
	for shot in _shots:
		var color: Color = shot["color"]
		var t := float(shot["t"])
		# Kurzer Schweif hinter der Kugel.
		for k in range(6):
			var tt := maxf(0.0, t - float(k) * 0.025)
			var alpha := 0.5 * (1.0 - float(k) / 6.0)
			draw_circle(_shot_position(shot, tt), 7.0 - float(k) * 0.8, Color(color.r, color.g, color.b, alpha))
		var pos := _shot_position(shot, t)
		_draw_glow(pos, 30.0, Color(color.r, color.g, color.b, 0.7))
		draw_circle(pos, 7.0, color.lightened(0.3))
		draw_circle(pos, 3.5, color.lightened(0.8))

func _draw_menu_frame() -> void:
	if frame_target == null or not frame_target.is_visible_in_tree():
		return
	var rect := Rect2(frame_target.global_position - global_position, frame_target.size).grow_individual(
		FRAME_PADDING.x, FRAME_PADDING.y, FRAME_PADDING.x, FRAME_PADDING.y)
	var box := StyleBoxFlat.new()
	box.bg_color = FRAME_FILL
	box.border_color = Color(TRACE.r, TRACE.g, TRACE.b, 0.7)
	box.set_border_width_all(2)
	box.set_corner_radius_all(18)
	box.shadow_color = Color(TRACE.r, TRACE.g, TRACE.b, 0.15)
	box.shadow_size = 20
	draw_style_box(box, rect)

func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	if _soft_texture == null:
		return
	draw_texture_rect(_soft_texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)

func _draw_vignette(area: Vector2) -> void:
	var steps := 12
	for i in range(steps):
		var t := float(i) / float(steps)
		var inset := t * 160.0
		draw_rect(Rect2(Vector2(inset, inset), area - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.09 * (1.0 - t)), false, 160.0 / steps * 2.0)
