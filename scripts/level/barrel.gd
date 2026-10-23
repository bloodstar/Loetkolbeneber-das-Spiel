class_name Barrel
extends RigidBody2D

const FUSE_DURATION: float = 3.0

var net_id: int = 0
var object_type: String = "barrel"
var is_replica: bool = false
var explosive: bool = false
var explosion_radius: float = 120.0
var explosion_damage: float = 42.0
var has_exploded: bool = false
var last_attacker: Node = null
var fuse_active: bool = false
var fuse_time_left: float = 0.0
var _fuse_blink_time: float = 0.0

func _ready() -> void:
	add_to_group("barrel")
	collision_layer = 1
	collision_mask = 7
	mass = 1.1
	gravity_scale = 1.0
	linear_damp = 0.35
	angular_damp = 0.8
	can_sleep = false
	object_type = "tnt_barrel" if explosive else "barrel"
	_build_visual()
	_build_collision()
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.75
	physics_material_override.bounce = 0.08
	set_process(false)
	if is_replica:
		set_replica(true)

func _process(delta: float) -> void:
	if not fuse_active or has_exploded:
		return
	fuse_time_left = maxf(0.0, fuse_time_left - delta)
	_fuse_blink_time += delta
	var pulse := 0.5 + 0.5 * sin(_fuse_blink_time * 20.0)
	modulate = Color(
		1.0 + pulse * 0.9,
		0.62 + (1.0 - pulse) * 0.25,
		0.52 + (1.0 - pulse) * 0.18,
		1.0
	)
	if fuse_time_left <= 0.0:
		if is_replica:
			set_process(false)
		else:
			explode()

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	col.shape = shape
	add_child(col)

func _build_visual() -> void:
	var body_color := Color(0.60, 0.35, 0.18, 1.0) if not explosive else Color(0.72, 0.16, 0.12, 1.0)
	var band_color := Color(0.28, 0.20, 0.12, 1.0) if not explosive else Color(0.35, 0.08, 0.06, 1.0)
	var highlight := Color(0.82, 0.56, 0.30, 1.0) if not explosive else Color(1.0, 0.45, 0.22, 1.0)

	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-15, -22), Vector2(15, -22),
		Vector2(20, -15), Vector2(20, 15),
		Vector2(15, 22), Vector2(-15, 22),
		Vector2(-20, 15), Vector2(-20, -15),
	])
	body.color = body_color
	add_child(body)

	var inner := Polygon2D.new()
	inner.polygon = PackedVector2Array([
		Vector2(-11, -18), Vector2(-5, -18), Vector2(-5, 18), Vector2(-11, 18),
	])
	inner.color = highlight
	inner.modulate.a = 0.35
	add_child(inner)

	for y in [-13.0, 0.0, 13.0]:
		var band := Line2D.new()
		band.points = PackedVector2Array([
			Vector2(-20, y), Vector2(20, y),
		])
		band.width = 3.0
		band.default_color = band_color
		add_child(band)

	var top_rim := Line2D.new()
	top_rim.points = PackedVector2Array([
		Vector2(-15, -22), Vector2(15, -22),
	])
	top_rim.width = 3.0
	top_rim.default_color = highlight
	add_child(top_rim)

	if explosive:
		var label := Label.new()
		label.text = "TNT"
		label.position = Vector2(-16, -8)
		label.size = Vector2(32, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 1.0))
		add_child(label)

		var fuse := Line2D.new()
		fuse.points = PackedVector2Array([
			Vector2(0, -22), Vector2(5, -31), Vector2(10, -29),
		])
		fuse.width = 2.0
		fuse.default_color = Color(0.16, 0.12, 0.08, 1.0)
		add_child(fuse)

		var spark := Polygon2D.new()
		spark.polygon = _circle_points(4.5, 8)
		spark.position = Vector2(11, -29)
		spark.color = Color(1.0, 0.72, 0.15, 1.0)
		add_child(spark)

func hit_barrel(projectile: Node2D) -> void:
	if is_replica or has_exploded:
		return
	if projectile != null:
		var attacker = projectile.get("shooter")
		if is_instance_valid(attacker) and attacker is Node:
			last_attacker = attacker
	# Beide Fassarten werden vom Treffer weggestoßen. Das explosive Fass
	# startet zusätzlich seine Lunte, statt den Impuls zu überspringen.
	var direction := Vector2.RIGHT
	var projectile_velocity = projectile.get("velocity") if projectile != null else null
	if projectile_velocity is Vector2:
		direction = projectile_velocity.normalized()
	apply_impulse(direction * 180.0 + Vector2(0.0, -35.0), Vector2.ZERO)
	angular_velocity += direction.x * 2.2
	if explosive:
		start_fuse()
	else:
		SoundManager.play_sound("bounce", 0.22, -6.0)

func start_fuse(duration: float = FUSE_DURATION) -> void:
	if is_replica or has_exploded or fuse_active:
		return
	fuse_active = true
	fuse_time_left = duration
	_fuse_blink_time = 0.0
	set_process(true)
	SoundManager.play_sound("click", 0.25, 1.0)

func explode() -> void:
	if is_replica or has_exploded:
		return
	has_exploded = true
	fuse_active = false
	set_process(false)
	# Der Angreifer kann zwischen Treffer und Explosion bereits freigegeben
	# worden sein (z. B. nach dem Sieg). Dann darf keine ungültige Referenz an
	# typisierte Parameter weitergereicht werden.
	var source: Node = last_attacker if is_instance_valid(last_attacker) else null
	var blast_pos := global_position
	_spawn_explosion_effect(blast_pos, explosion_radius)
	SoundManager.play_sound("explosion", 0.65, 0.0)
	Global.shake_camera(0.55)
	_apply_explosion_damage(blast_pos, source)
	_damage_nearby_crates(blast_pos, source)
	_chain_to_other_barrels(blast_pos, source)
	queue_free()

func explode_delayed(delay: float) -> void:
	if is_replica or has_exploded:
		return
	fuse_active = true
	fuse_time_left = delay
	_fuse_blink_time = 0.0
	set_process(true)
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self) and is_inside_tree() and not has_exploded:
		explode()

func _apply_explosion_damage(blast_pos: Vector2, source: Node = null) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var player := p as Node2D
		if player == null or not player.has_method("take_damage"):
			continue
		var health = player.get("current_health")
		if health != null and float(health) <= 0.0:
			continue
		var distance := blast_pos.distance_to(player.global_position)
		if distance > explosion_radius:
			continue
		var falloff := clampf(1.0 - distance / explosion_radius, 0.25, 1.0)
		var direction := (player.global_position - blast_pos).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.UP
		player.call("take_damage", explosion_damage * falloff, direction * (480.0 + 320.0 * falloff), source)

func _damage_nearby_crates(blast_pos: Vector2, source: Node = null) -> void:
	for crate in get_tree().get_nodes_in_group("crate"):
		if not is_instance_valid(crate) or not crate.has_method("apply_blast"):
			continue
		if blast_pos.distance_to(crate.global_position) <= explosion_radius * 1.2:
			crate.apply_blast(blast_pos, explosion_radius * 1.2, 460.0, source)

func _chain_to_other_barrels(blast_pos: Vector2, source: Node = null) -> void:
	for other in get_tree().get_nodes_in_group("barrel"):
		if other == self or not is_instance_valid(other):
			continue
		var other_body := other as RigidBody2D
		if other_body == null:
			continue
		var distance := blast_pos.distance_to(other_body.global_position)
		if distance > explosion_radius * 1.35:
			continue
		if bool(other_body.get("explosive")):
			if source != null and is_instance_valid(source):
				other_body.set("last_attacker", source)
			other_body.call_deferred("explode_delayed", 0.10)
		else:
			var direction := (other_body.global_position - blast_pos).normalized()
			var strength := 520.0 * clampf(1.0 - distance / (explosion_radius * 1.35), 0.15, 1.0)
			other_body.apply_impulse(direction * strength + Vector2(0.0, -80.0), Vector2.ZERO)

func _spawn_explosion_effect(effect_pos: Vector2, radius: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := Node2D.new()
	fx.global_position = effect_pos
	fx.z_index = 8
	parent.add_child(fx)

	var fill := Polygon2D.new()
	fill.polygon = _circle_points(radius * 0.55, 24)
	fill.color = Color(1.0, 0.46, 0.08, 0.45)
	fx.add_child(fill)

	var ring := Line2D.new()
	ring.points = _circle_points(radius, 32)
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.82, 0.28, 0.95)
	fx.add_child(ring)

	var inner_ring := Line2D.new()
	inner_ring.points = _circle_points(radius * 0.55, 24)
	inner_ring.width = 3.0
	inner_ring.default_color = Color(1.0, 0.95, 0.65, 0.9)
	fx.add_child(inner_ring)

	var tween := fx.create_tween()
	tween.tween_property(fx, "scale", Vector2(1.3, 1.3), 0.28)
	tween.parallel().tween_property(fx, "modulate:a", 0.0, 0.28)
	tween.tween_callback(fx.queue_free)

func spawn_remote_explosion() -> void:
	if explosive:
		_spawn_explosion_effect(global_position, explosion_radius)
	queue_free()

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if not points.is_empty():
		points.append(points[0])
	return points

func set_replica(replica: bool) -> void:
	is_replica = replica
	freeze = replica
	can_sleep = false
	if replica:
		collision_layer = 0
		collision_mask = 0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		set_process(false)
		modulate = Color.WHITE
	else:
		collision_layer = 1
		collision_mask = 7

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"rot": rotation,
		"fuse": fuse_active,
		"fuse_time": fuse_time_left,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	global_position = data.get("pos", global_position)
	rotation = float(data.get("rot", rotation))
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	var remote_fuse := bool(data.get("fuse", false))
	if remote_fuse and not has_exploded:
		fuse_active = true
		fuse_time_left = float(data.get("fuse_time", fuse_time_left))
		set_process(true)
	elif not remote_fuse:
		fuse_active = false
		modulate = Color.WHITE
		set_process(false)
