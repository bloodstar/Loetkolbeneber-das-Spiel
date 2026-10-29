class_name PinataLama
extends CharacterBody2D

signal damaged(player_slot: int, amount: float)

var damage_by_player: Dictionary = {} # slot -> total_damage

const GRAVITY: float = 850.0
const RUN_SPEED: float = 180.0
const JUMP_FORCE: float = -420.0

var _direction: float = 1.0
var _hop_timer: float = 0.0
var _anim_time: float = 0.0
var _arena_rect: Rect2 = Rect2(60, 60, 1200, 700)
var _leader_position: Vector2 = Vector2.INF
var _has_leader: bool = false
var _flee_lock_timer: float = 0.0

# Auf Netzwerk-Clients bewegt sich das Lama nicht selbst, sondern folgt den
# Snapshots des Hosts. Schaden zählt nur der Host.
var is_replica: bool = false
var _net_target: Vector2 = Vector2.INF
# Sekunden seit dem letzten Host-Snapshot. Bleiben Snapshots aus (z. B. im
# Match-Endbildschirm), wird nicht mehr mit der alten Geschwindigkeit
# extrapoliert, sonst fliegt das Lama auf Clients durch die Karte.
var _net_age: float = 0.0
const NET_EXTRAPOLATE_MAX: float = 0.25

func get_network_state() -> Dictionary:
	return {
		"pos": global_position,
		"vel": velocity,
		"dir": _direction,
		"dmg": damage_by_player.duplicate(),
	}

func apply_network_state(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", global_position)
	if _net_target == Vector2.INF or pos.distance_to(global_position) > 160.0:
		global_position = pos
	_net_target = pos
	_net_age = 0.0
	velocity = data.get("vel", velocity)
	_direction = float(data.get("dir", _direction))
	var dmg = data.get("dmg", {})
	if dmg is Dictionary:
		damage_by_player = dmg.duplicate()

func setup_bounds(rect: Rect2) -> void:
	_arena_rect = rect

func set_leader_position(world_position: Vector2) -> void:
	_leader_position = world_position
	_has_leader = true

func has_leader_target() -> bool:
	return _has_leader

func get_leader_position() -> Vector2:
	return _leader_position

func get_flee_direction() -> float:
	return _direction

# Mitte der Kollisionsbox (sie sitzt über dem Ursprung), für Nahkampftreffer.
func get_hit_center() -> Vector2:
	return global_position + Vector2(0, -17.0)

func _ready() -> void:
	add_to_group("pinata")
	collision_layer = 2 # Treat like player/hittable
	collision_mask = 1  # Collide with solid world

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28.0, 34.0)
	col.shape = rect
	col.position = Vector2(0, -17.0)
	add_child(col)

func _physics_process(delta: float) -> void:
	_anim_time += delta * 12.0
	if is_replica:
		if _net_target != Vector2.INF:
			_net_age += delta
			if _net_age <= NET_EXTRAPOLATE_MAX:
				_net_target += velocity * delta
			global_position = global_position.lerp(_net_target, minf(1.0, delta * 15.0))
		queue_redraw()
		return
	_hop_timer -= delta
	_flee_lock_timer = maxf(0.0, _flee_lock_timer - delta)
	_update_flee_direction()

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		var panic_speed := 1.0
		if _has_leader:
			var distance := global_position.distance_to(_leader_position)
			panic_speed = 1.0 + clampf(1.0 - distance / 420.0, 0.0, 1.0) * 0.45
		velocity.x = _direction * RUN_SPEED * panic_speed
		# Jump over walls or panic-hop when the leader gets close.
		if is_on_wall() and _hop_timer <= 0.0:
			velocity.y = JUMP_FORCE
			_hop_timer = 0.55
			_flee_lock_timer = 0.45
			_direction = -_direction
		elif _has_leader and _hop_timer <= 0.0 and randf() < 0.035:
			velocity.y = JUMP_FORCE * 0.9
			_hop_timer = 0.75
		elif randf() < 0.015 and _hop_timer <= 0.0:
			velocity.y = JUMP_FORCE * 0.8
			_hop_timer = 0.8

	# Turn around if hitting edges of arena
	if global_position.x < _arena_rect.position.x + 50:
		_direction = 1.0
	elif global_position.x > _arena_rect.end.x - 50:
		_direction = -1.0

	move_and_slide()
	queue_redraw()

func _update_flee_direction() -> void:
	if not _has_leader or _flee_lock_timer > 0.0:
		return
	var away := global_position.x - _leader_position.x
	if absf(away) < 1.0:
		away = 1.0 if randf() < 0.5 else -1.0
	_direction = 1.0 if away > 0.0 else -1.0

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, source = null, _is_reflected: bool = false) -> void:
	if is_replica:
		return
	velocity += knockback * 0.4
	SoundManager.play_sound("hit", 0.4, 2.5)

	var slot := 0
	# Die Schadensquelle kann inzwischen freigegeben sein (z. B. ein zerstörter
	# Turm). Vor jedem Methodenaufruf validieren.
	if is_instance_valid(source) and source.has_method("get") and source.get("player_index") != null:
		slot = int(source.get("player_index"))
	elif is_instance_valid(source) and source is Node and source.has_method("get_player_index"):
		slot = source.get_player_index()

	if slot > 0:
		damage_by_player[slot] = float(damage_by_player.get(slot, 0.0)) + amount
		damaged.emit(slot, amount)

	_spawn_confetti()

func _spawn_confetti() -> void:
	var confetti := Node2D.new()
	get_parent().add_child(confetti)
	confetti.global_position = global_position + Vector2(0, -18)

	var colors := [
		Color(1.0, 0.2, 0.6), # Magenta
		Color(0.2, 0.8, 1.0), # Cyan
		Color(1.0, 0.9, 0.2), # Yellow
		Color(0.4, 1.0, 0.3), # Green
		Color(1.0, 0.5, 0.1), # Orange
	]

	var particles: Array[Dictionary] = []
	for i in range(12):
		var ang := randf() * TAU
		var spd := randf_range(60.0, 160.0)
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(ang) * spd,
			"col": colors[i % colors.size()],
			"rot": randf() * TAU,
		})

	var tw := confetti.create_tween()
	tw.tween_method(func(progress: float):
		confetti.queue_redraw()
		for p in particles:
			p["pos"] = p["vel"] * progress + Vector2(0, progress * progress * 120.0)
			p["rot"] += progress * 0.2
	, 0.0, 0.5, 0.5)

	confetti.draw.connect(func():
		for p in particles:
			var pts := PackedVector2Array([
				p["pos"] + Vector2(-3, -2).rotated(p["rot"]),
				p["pos"] + Vector2(3, -2).rotated(p["rot"]),
				p["pos"] + Vector2(3, 2).rotated(p["rot"]),
				p["pos"] + Vector2(-3, 2).rotated(p["rot"]),
			])
			confetti.draw_colored_polygon(pts, p["col"])
	)
	tw.tween_callback(confetti.queue_free)

func _draw() -> void:
	var flip := -1.0 if _direction < 0 else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))

	var leg_swing := sin(_anim_time) * 6.0

	# Legs
	draw_line(Vector2(-8, -6), Vector2(-8 + leg_swing, 0), Color(0.9, 0.2, 0.5), 4.0)
	draw_line(Vector2(6, -6), Vector2(6 - leg_swing, 0), Color(0.1, 0.7, 0.9), 4.0)

	# Striped Body
	var stripes := [
		Color(1.0, 0.2, 0.6), # Magenta
		Color(0.2, 0.8, 1.0), # Cyan
		Color(1.0, 0.85, 0.2),# Yellow
		Color(0.3, 0.9, 0.4), # Green
	]

	for i in range(4):
		var y_top := -24.0 + (i * 4.5)
		draw_rect(Rect2(-12, y_top, 24, 4.5), stripes[i])

	# Neck & Head
	draw_rect(Rect2(4, -34, 8, 12), Color(1.0, 0.2, 0.6))
	draw_rect(Rect2(4, -38, 14, 8), Color(0.2, 0.8, 1.0))

	# Snout
	draw_rect(Rect2(16, -35, 5, 4), Color(1.0, 0.85, 0.2))

	# Eye
	draw_circle(Vector2(12, -35), 2.0, Color.WHITE)
	draw_circle(Vector2(12.5, -35), 1.0, Color.BLACK)

	# Ears
	draw_line(Vector2(6, -38), Vector2(4, -44), Color(1.0, 0.2, 0.6), 2.5)
	draw_line(Vector2(9, -38), Vector2(8, -44), Color(0.2, 0.8, 1.0), 2.5)

	# Tail
	draw_line(Vector2(-12, -22), Vector2(-16, -26), Color(1.0, 0.85, 0.2), 3.0)
