class_name HeroSelectCheer
extends Node2D

## Kleine Jubel-Animation + Grunzen, wenn in der Lobby ein Held gewählt wird.
##
## Hängt als Kind am Vorschau-Canvas der Großansicht. `actor` ist der Knoten,
## an dem Eber und Lötkolben hängen (Fußpunkt = Ursprung), damit Stauchen und
## Drehen um die Füße passieren. Jede Klasse hat ihre eigene Bewegung, ein
## eigenes Grunzen (SoundManager "grunt_<held>") und ein paar Partikel.
## Eine neue Wahl bricht eine laufende Animation ab und setzt alles zurück.

var actor: Node2D = null
var pig: Node2D = null          # PigModular (flip_h für Umdrehen)
var voxel: Node = null          # VoxelSprite oder null (airborne für angezogene Beine)

var _tween: Tween = null
var _base_pos: Vector2 = Vector2.ZERO
var _particles: Array[Dictionary] = []
var _ring_t: float = -1.0
var _ring_color: Color = Color.WHITE
# Partikel werden in Canvas-Koordinaten um den Fußpunkt gezeichnet.
var _scale_px: float = 5.8

func setup(p_actor: Node2D, p_pig: Node2D, p_voxel: Node, scale_px: float) -> void:
	actor = p_actor
	pig = p_pig
	voxel = p_voxel
	_scale_px = scale_px
	_base_pos = actor.position
	# Partikel über dem Eber zeichnen.
	z_index = 5

func play(hero_id: String, tint: Color) -> void:
	if actor == null:
		return
	_reset()
	SoundManager.play_sound("grunt_" + hero_id, 0.04)
	_tween = create_tween()
	match hero_id:
		"ignis": _anim_ignis(tint)
		"volt": _anim_volt(tint)
		"spore": _anim_spore(tint)
		"nova": _anim_nova(tint)
		"klinge": _anim_klinge(tint)
		"bastion": _anim_bastion(tint)
		"phantom": _anim_phantom(tint)
		"druid": _anim_druid(tint)
		"vampire": _anim_vampire(tint)
		"vampire_melee": _anim_blood_knight(tint)
		"zeitschlaeger": _anim_time(tint)
		"flocke": _anim_nova(tint)
		_: _anim_hop(tint)
	_tween.finished.connect(_reset_pose)

func _reset() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_reset_pose()

func _reset_pose() -> void:
	if actor == null:
		return
	actor.position = _base_pos
	actor.scale = Vector2.ONE
	actor.rotation = 0.0
	actor.modulate = Color.WHITE
	if pig != null:
		pig.flip_h = false
	_set_air(false)

func _set_air(value: bool) -> void:
	if voxel != null and "airborne" in voxel:
		voxel.set("airborne", value)

func _set_flip(value: bool) -> void:
	if pig != null:
		pig.flip_h = value

# --- Bausteine ---------------------------------------------------------------

func _squash(amount: float, time: float) -> void:
	_tween.tween_property(actor, "scale", Vector2(1.0 + amount, 1.0 - amount), time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _settle(time: float = 0.18) -> void:
	_tween.tween_property(actor, "scale", Vector2.ONE, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _jump(height: float, up_time: float, down_time: float) -> void:
	_tween.tween_callback(_set_air.bind(true))
	_tween.tween_property(actor, "position:y", _base_pos.y - height, up_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "scale", Vector2(0.95, 1.05), up_time * 0.6)
	_tween.tween_property(actor, "position:y", _base_pos.y, down_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(actor, "scale", Vector2.ONE, down_time)
	_tween.tween_callback(_set_air.bind(false))

func _flash(color: Color, time: float) -> void:
	var bright := Color(lerpf(1.0, color.r * 1.6, 0.6), lerpf(1.0, color.g * 1.6, 0.6), lerpf(1.0, color.b * 1.6, 0.6), 1.0)
	_tween.parallel().tween_property(actor, "modulate", bright, time * 0.3)
	_tween.parallel().tween_property(actor, "modulate", Color.WHITE, time * 0.7).set_delay(time * 0.3)

func _emit(kind: String, color: Color, count: int) -> void:
	_tween.tween_callback(_spawn_particles.bind(kind, color, count))

func _ring(color: Color) -> void:
	_tween.tween_callback(func() -> void:
		_ring_t = 0.0
		_ring_color = color)

# --- Klassen -----------------------------------------------------------------

# Ignis: in die Knie, Hitzesprung mit Funkenregen, hart landen.
func _anim_ignis(tint: Color) -> void:
	_squash(0.18, 0.1)
	_emit("flame", Color(1.0, 0.55, 0.15), 18)
	_jump(40.0, 0.2, 0.18)
	_flash(Color(1.0, 0.5, 0.1), 0.4)
	_squash(0.16, 0.06)
	_settle()

# Volt: elektrisches Zittern mit Blitzflackern, dann ein kleiner Hüpfer.
func _anim_volt(tint: Color) -> void:
	_emit("spark", Color(1.0, 0.95, 0.35), 16)
	for i in 8:
		var dx := 7.0 if i % 2 == 0 else -7.0
		_tween.tween_property(actor, "position:x", _base_pos.x + dx, 0.035)
		_tween.parallel().tween_property(actor, "modulate",
			Color(1.6, 1.6, 0.8) if i % 2 == 0 else Color.WHITE, 0.035)
	_tween.tween_property(actor, "position:x", _base_pos.x, 0.04)
	_tween.parallel().tween_property(actor, "modulate", Color.WHITE, 0.04)
	_jump(26.0, 0.12, 0.12)
	_settle(0.12)

# Spore: gemütliches Hin- und Herwiegen, Sporen steigen auf.
func _anim_spore(tint: Color) -> void:
	_emit("rise", Color(0.55, 0.9, 0.4), 14)
	for side in [1.0, -1.0, 0.6, 0.0]:
		_tween.tween_property(actor, "rotation", 0.16 * side, 0.22) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.parallel().tween_property(actor, "scale",
			Vector2(1.0 + 0.05 * absf(side), 1.0 - 0.05 * absf(side)), 0.22)
	_settle(0.15)

# Nova: schwebt hoch, dreht sich zweimal wie eine Pirouette im Sternenregen, sinkt zurück.
func _anim_nova(tint: Color) -> void:
	_emit("star", Color(0.75, 0.6, 1.0), 16)
	_tween.tween_callback(_set_air.bind(true))
	_tween.tween_property(actor, "position:y", _base_pos.y - 28.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash(Color(0.7, 0.55, 1.0), 0.5)
	for i in 2:
		_tween.tween_property(actor, "scale:x", -1.0, 0.12).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(actor, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(actor, "position:y", _base_pos.y, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_set_air.bind(false))
	_settle(0.12)

# Klinge: Ausfallschritt nach vorn mit Hieb, zurückfedern.
func _anim_klinge(tint: Color) -> void:
	_tween.tween_property(actor, "position:x", _base_pos.x - 14.0, 0.1)
	_tween.parallel().tween_property(actor, "rotation", -0.12, 0.1)
	_tween.tween_property(actor, "position:x", _base_pos.x + 44.0, 0.07) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "rotation", 0.2, 0.07)
	_emit("slash", Color(1.0, 0.35, 0.3), 1)
	_tween.tween_interval(0.12)
	_tween.tween_property(actor, "position:x", _base_pos.x, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "rotation", 0.0, 0.25)

# Bastion: schwer anheben, auf den Boden stampfen, Staubring.
func _anim_bastion(tint: Color) -> void:
	_tween.tween_property(actor, "position:y", _base_pos.y - 22.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "scale", Vector2(0.94, 1.08), 0.22)
	_tween.tween_property(actor, "position:y", _base_pos.y, 0.07).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(actor, "scale", Vector2(1.24, 0.78), 0.07)
	_ring(Color(0.45, 0.85, 0.85))
	_emit("dust", Color(0.75, 0.7, 0.6), 14)
	for i in 4:
		var dy := 4.0 if i % 2 == 0 else -2.0
		_tween.tween_property(actor, "position:y", _base_pos.y + dy, 0.035)
	_tween.tween_property(actor, "position:y", _base_pos.y, 0.04)
	_settle(0.25)

# Phantom: verschwindet, taucht auf der anderen Seite umgedreht auf, blinzelt zurück.
func _anim_phantom(tint: Color) -> void:
	_emit("smoke", Color(0.55, 0.5, 0.75), 12)
	_tween.tween_property(actor, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func() -> void:
		actor.position.x = _base_pos.x + 50.0
		_set_flip(true))
	_tween.tween_property(actor, "modulate:a", 1.0, 0.1)
	_tween.tween_interval(0.22)
	_tween.tween_property(actor, "modulate:a", 0.0, 0.1)
	_tween.tween_callback(func() -> void:
		actor.position.x = _base_pos.x
		_set_flip(false))
	_emit("smoke", Color(0.55, 0.5, 0.75), 10)
	_tween.tween_property(actor, "modulate:a", 1.0, 0.14)

# Druide: wächst wie ein Baum, wiegt sich im Wind, Blätter fallen.
func _anim_druid(tint: Color) -> void:
	_emit("leaf", Color(0.45, 0.8, 0.35), 14)
	_tween.tween_property(actor, "scale", Vector2(1.12, 1.18), 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for side in [0.1, -0.1, 0.05]:
		_tween.tween_property(actor, "rotation", side, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(actor, "rotation", 0.0, 0.15)
	_tween.parallel().tween_property(actor, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_SINE)

# Vampir: lehnt sich zurück, wird blutrot und schwebt kurz, Fledermaus-Tropfen.
func _anim_vampire(tint: Color) -> void:
	_tween.tween_property(actor, "rotation", -0.18, 0.18).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(actor, "modulate", Color(1.3, 0.45, 0.5), 0.18)
	_emit("blood", Color(0.85, 0.1, 0.18), 14)
	_tween.tween_callback(_set_air.bind(true))
	_tween.tween_property(actor, "position:y", _base_pos.y - 30.0, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "rotation", 0.0, 0.3)
	_tween.tween_property(actor, "position:y", _base_pos.y, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(actor, "modulate", Color.WHITE, 0.3)
	_tween.tween_callback(_set_air.bind(false))

# Blutritter: duckt sich und springt mit Schwung nach vorn, Blutspritzer beim Landen.
func _anim_blood_knight(tint: Color) -> void:
	_squash(0.2, 0.14)
	_tween.tween_callback(_set_air.bind(true))
	_tween.tween_property(actor, "position", _base_pos + Vector2(30.0, -28.0), 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "rotation", 0.28, 0.16)
	_tween.parallel().tween_property(actor, "scale", Vector2(0.92, 1.1), 0.16)
	_tween.tween_property(actor, "position", _base_pos + Vector2(40.0, 0.0), 0.14).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(actor, "rotation", 0.0, 0.14)
	_tween.tween_callback(_set_air.bind(false))
	_emit("blood", Color(0.8, 0.08, 0.12), 12)
	_squash(0.15, 0.06)
	_tween.tween_property(actor, "position", _base_pos, 0.28) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.parallel().tween_property(actor, "scale", Vector2.ONE, 0.2)

# Zeitschläger: tickt wie ein Uhrzeiger, spult dann rückwärts an seinen Platz.
func _anim_time(tint: Color) -> void:
	_emit("tick", Color(0.95, 0.85, 0.5), 12)
	for step in [0.12, -0.12, 0.12, -0.12]:
		_tween.tween_property(actor, "rotation", step, 0.06).set_trans(Tween.TRANS_EXPO)
		_tween.tween_interval(0.06)
	_tween.tween_property(actor, "rotation", 0.0, 0.05)
	_tween.tween_property(actor, "position:x", _base_pos.x - 40.0, 0.14)
	_tween.parallel().tween_property(actor, "modulate", Color(0.75, 0.9, 1.4), 0.14)
	_tween.tween_property(actor, "position:x", _base_pos.x, 0.2) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(actor, "modulate", Color.WHITE, 0.2)

# Rückfall für neue Helden ohne eigene Animation.
func _anim_hop(tint: Color) -> void:
	_squash(0.12, 0.08)
	_emit("spark", tint.lerp(Color.WHITE, 0.3), 10)
	_jump(36.0, 0.16, 0.16)
	_settle()

# --- Partikel ----------------------------------------------------------------

func _spawn_particles(kind: String, color: Color, count: int) -> void:
	var origin := _base_pos + Vector2(0.0, -8.0 * _scale_px * 0.5)
	for i in count:
		var p := {
			"kind": kind,
			"color": color,
			"pos": origin + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 10.0)),
			"vel": Vector2.ZERO,
			"grav": 0.0,
			"life": randf_range(0.5, 0.9),
			"age": 0.0,
			"size": randf_range(3.0, 6.0),
			"spin": randf_range(-6.0, 6.0),
		}
		match kind:
			"flame":
				p["pos"] = _base_pos + Vector2(randf_range(-26.0, 26.0), randf_range(-6.0, 4.0))
				p["vel"] = Vector2(randf_range(-40.0, 40.0), randf_range(-260.0, -140.0))
				p["grav"] = 120.0
				p["color"] = color.lerp(Color(1.0, 0.9, 0.3), randf())
			"spark":
				var a := randf() * TAU
				p["vel"] = Vector2.from_angle(a) * randf_range(140.0, 260.0)
				p["life"] = randf_range(0.25, 0.45)
				p["size"] = randf_range(2.0, 4.0)
			"rise", "smoke":
				p["vel"] = Vector2(randf_range(-25.0, 25.0), randf_range(-90.0, -45.0))
				p["life"] = randf_range(0.8, 1.3)
			"star":
				var b := randf() * TAU
				p["pos"] = _base_pos + Vector2(0.0, -80.0) + Vector2.from_angle(b) * randf_range(20.0, 70.0)
				p["vel"] = Vector2.from_angle(b) * randf_range(20.0, 60.0)
				p["life"] = randf_range(0.6, 1.1)
			"slash":
				p["pos"] = _base_pos + Vector2(95.0, -70.0)
				p["life"] = 0.28
				p["size"] = 70.0
			"dust":
				var side := -1.0 if i % 2 == 0 else 1.0
				p["pos"] = _base_pos + Vector2(side * randf_range(20.0, 50.0), 0.0)
				p["vel"] = Vector2(side * randf_range(90.0, 200.0), randf_range(-70.0, -20.0))
				p["grav"] = 160.0
				p["life"] = randf_range(0.4, 0.7)
			"leaf":
				p["pos"] = _base_pos + Vector2(randf_range(-70.0, 70.0), randf_range(-170.0, -110.0))
				p["vel"] = Vector2(randf_range(-30.0, 30.0), randf_range(30.0, 70.0))
				p["life"] = randf_range(0.9, 1.4)
			"blood":
				p["vel"] = Vector2(randf_range(-120.0, 120.0), randf_range(-200.0, -80.0))
				p["grav"] = 520.0
				p["life"] = randf_range(0.5, 0.8)
			"tick":
				var c := float(i) / float(maxi(1, count)) * TAU
				p["pos"] = _base_pos + Vector2(0.0, -75.0) + Vector2.from_angle(c) * 95.0
				p["vel"] = Vector2.from_angle(c) * -40.0
				p["life"] = 0.7
				p["size"] = 4.0
		_particles.append(p)
	set_process(true)

func _process(delta: float) -> void:
	var alive: Array[Dictionary] = []
	for p in _particles:
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			continue
		var vel: Vector2 = p["vel"]
		vel.y += float(p["grav"]) * delta
		if str(p["kind"]) == "leaf":
			vel.x = sin(float(p["age"]) * 6.0 + float(p["spin"])) * 50.0
		p["vel"] = vel
		p["pos"] = (p["pos"] as Vector2) + vel * delta
		alive.append(p)
	_particles = alive
	if _ring_t >= 0.0:
		_ring_t += delta
		if _ring_t > 0.45:
			_ring_t = -1.0
	queue_redraw()
	if _particles.is_empty() and _ring_t < 0.0:
		set_process(false)

func _draw() -> void:
	if _ring_t >= 0.0:
		var k := _ring_t / 0.45
		var col := _ring_color
		col.a = 1.0 - k
		draw_arc(_base_pos + Vector2(0.0, -4.0), 30.0 + k * 130.0, PI * 1.05, TAU * 0.98, 32, col, 5.0 * (1.0 - k) + 1.0, true)
	for p in _particles:
		var k2 := float(p["age"]) / float(p["life"])
		var col2: Color = p["color"]
		col2.a = 1.0 - k2 * k2
		var pos: Vector2 = p["pos"]
		var size := float(p["size"])
		match str(p["kind"]):
			"spark", "flame":
				var vel: Vector2 = p["vel"]
				draw_line(pos, pos - vel.normalized() * size * 2.5, col2, size * 0.7, true)
			"star", "tick":
				var r := size * (1.0 - k2 * 0.5)
				var ang := float(p["spin"]) * float(p["age"])
				for j in 2:
					var d := Vector2.from_angle(ang + j * PI * 0.5) * r * 1.6
					draw_line(pos - d, pos + d, col2, 2.0, true)
			"slash":
				draw_arc(pos, size, -1.2, 1.0, 20, col2, 7.0 * (1.0 - k2) + 1.0, true)
				draw_arc(pos, size * 0.82, -1.0, 0.8, 20, Color(1, 1, 1, col2.a * 0.8), 3.0, true)
			"leaf":
				var rot := float(p["spin"]) * float(p["age"])
				draw_set_transform(pos, rot, Vector2(1.0, 0.5))
				draw_circle(Vector2.ZERO, size, col2)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"smoke":
				draw_circle(pos, size * (1.0 + k2 * 2.0), Color(col2.r, col2.g, col2.b, col2.a * 0.6))
			_:
				draw_circle(pos, size * (1.0 - k2 * 0.4), col2)
