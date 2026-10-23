class_name PhysicsCrate
extends RigidBody2D

signal crate_broken(world_position, attacker)

const BASE_SIZE: float = 36.0

var net_id: int = 0
var object_type: String = "crate"
var is_replica: bool = false
var crate_size: float = 1.0
var health: int = 2
var max_health: int = 2
var last_attacker: Node = null

var _size_px: float = BASE_SIZE
var _broken: bool = false
var _previous_velocity: Vector2 = Vector2.ZERO
var _hit_cooldowns: Dictionary = {}

func _ready() -> void:
	add_to_group("crate")
	collision_layer = 1
	collision_mask = 7
	mass = 0.85 * crate_size * crate_size
	gravity_scale = 1.0
	linear_damp = 0.28
	angular_damp = 0.65
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.85
	physics_material_override.bounce = 0.03
	_build_collision()
	_build_visual()
	if is_replica:
		set_replica(true)
	else:
		contact_monitor = true
		max_contacts_reported = 6
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_replica:
		return
	_previous_velocity = linear_velocity
	for key in _hit_cooldowns.keys():
		_hit_cooldowns[key] = maxf(0.0, float(_hit_cooldowns[key]) - delta)
	if linear_velocity.y < -900.0 or linear_velocity.y > 900.0:
		linear_velocity.y = clampf(linear_velocity.y, -900.0, 900.0)

func _build_collision() -> void:
	_size_px = BASE_SIZE * crate_size
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(_size_px, _size_px)
	col.shape = shape
	add_child(col)

func _build_visual() -> void:
	var half := _size_px * 0.5
	var wood := Color(0.63, 0.39, 0.19, 1.0)
	var wood_dark := Color(0.35, 0.20, 0.09, 1.0)
	var wood_light := Color(0.86, 0.62, 0.32, 1.0)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half),
	])
	body.color = wood
	add_child(body)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(-half + 5.0, -half + 5.0),
		Vector2(half - 5.0, -half + 5.0),
		Vector2(half - 5.0, half - 5.0),
		Vector2(-half + 5.0, half - 5.0),
	])
	inner.color = wood_light
	inner.modulate.a = 0.55
	add_child(inner)

	var border := Line2D.new()
	border.points = PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half), Vector2(-half, -half),
	])
	border.width = 3.0
	border.default_color = wood_dark
	add_child(border)

	# Zwei Diagonalstreben machen die Kisten als Bauklötze lesbar.
	for direction in [-1.0, 1.0]:
		var brace := Line2D.new()
		brace.points = PackedVector2Array([
			Vector2(-half + 5.0, direction * (half - 5.0)),
			Vector2(half - 5.0, -direction * (half - 5.0)),
		])
		brace.width = 2.5
		brace.default_color = wood_dark
		brace.modulate.a = 0.75
		add_child(brace)

	var top_light := Line2D.new()
	top_light.points = PackedVector2Array([
		Vector2(-half + 3.0, -half - 1.0), Vector2(half - 3.0, -half - 1.0),
	])
	top_light.width = 2.0
	top_light.default_color = Color(1.0, 0.82, 0.48, 0.75)
	add_child(top_light)

func hit_crate(projectile: Node2D = null) -> void:
	if is_replica or _broken:
		return
	if projectile != null:
		var attacker = projectile.get("shooter")
		if is_instance_valid(attacker) and attacker is Node:
			last_attacker = attacker
	health -= 1
	_flash_damage()
	SoundManager.play_sound("hit", 0.18, -3.0)
	if health <= 0:
		_break_apart()

func apply_blast(blast_position: Vector2, radius: float, force: float = 520.0, attacker: Node = null) -> void:
	if is_replica or _broken:
		return
	if attacker != null and is_instance_valid(attacker):
		last_attacker = attacker
	var distance := blast_position.distance_to(global_position)
	if distance > radius:
		return
	var falloff := clampf(1.0 - distance / maxf(1.0, radius), 0.15, 1.0)
	var direction := (global_position - blast_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	apply_impulse(direction * force * falloff + Vector2(0.0, -90.0), Vector2.ZERO)
	health -= 1
	_flash_damage()
	if health <= 0:
		_break_apart()

func _flash_damage() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.6, 0.75, 0.55), 0.06)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func _break_apart() -> void:
	if _broken:
		return
	_broken = true
	var impact_position := global_position
	var attacker := last_attacker
	_spawn_splinters(impact_position)
	crate_broken.emit(impact_position, attacker)
	queue_free()

func _spawn_splinters(impact_position: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := Node2D.new()
	fx.global_position = impact_position
	fx.z_index = 5
	parent.add_child(fx)
	for i in range(6):
		var shard := Polygon2D.new()
		var shard_size := 3.0 + float(i % 3) * 1.5
		shard.polygon = PackedVector2Array([
			Vector2(-shard_size, -shard_size),
			Vector2(shard_size, 0),
			Vector2(-shard_size, shard_size),
		])
		shard.color = Color(0.58, 0.34, 0.15, 1.0)
		shard.rotation = float(i) * TAU / 6.0
		fx.add_child(shard)
		var direction := Vector2.from_angle(float(i) * TAU / 6.0 + 0.35)
		var tw := shard.create_tween()
		tw.tween_property(shard, "position", direction * (22.0 + float(i % 3) * 9.0), 0.22)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.24)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.3)
	cleanup.tween_callback(fx.queue_free)

func _on_body_entered(body: Node) -> void:
	if is_replica or _broken:
		return
	if not (body is Player):
		return
	var player := body as Player
	if player.current_health <= 0.0 or player.is_invulnerable:
		return
	var impact_speed := maxf(absf(_previous_velocity.y), absf(linear_velocity.y))
	if impact_speed < 165.0:
		return
	var key := player.get_instance_id()
	if float(_hit_cooldowns.get(key, 0.0)) > 0.0:
		return
	_hit_cooldowns[key] = 0.65
	var damage := clampf((impact_speed - 140.0) / 11.0, 7.0, 38.0)
	var source = last_attacker if is_instance_valid(last_attacker) else null
	player.take_damage(damage, Vector2(0.0, -190.0), source)
	SoundManager.play_sound("hit", 0.28, 1.0)

func set_replica(replica: bool) -> void:
	is_replica = replica
	freeze = replica
	can_sleep = false
	contact_monitor = false if replica else true
	if replica:
		collision_layer = 0
		collision_mask = 0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
	else:
		collision_layer = 1
		collision_mask = 7

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"rot": rotation,
		"size": crate_size,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	global_position = data.get("pos", global_position)
	rotation = float(data.get("rot", rotation))
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
