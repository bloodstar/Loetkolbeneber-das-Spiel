class_name ChainPlatform
extends Node2D

const TILE_SIZE: float = 36.0

var net_id: int = 0
var object_type: String = "chain_platform"
var is_replica: bool = false
var platform_width: float = 4.0 * TILE_SIZE
var platform_height: float = 14.0
var chain_length: float = 5.0 * TILE_SIZE

var anchor: StaticBody2D
var platform: RigidBody2D
var joint: PinJoint2D
var chain_left: Line2D
var chain_right: Line2D

func _ready() -> void:
	_build()
	if is_replica:
		set_replica(true)

func _build() -> void:
	z_index = 2

	anchor = StaticBody2D.new()
	anchor.name = "Anchor"
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	add_child(anchor)

	platform = RigidBody2D.new()
	platform.name = "Platform"
	platform.collision_layer = 1
	platform.collision_mask = 7
	platform.mass = 2.0
	platform.gravity_scale = 1.0
	platform.linear_damp = 0.4
	platform.angular_damp = 0.7
	platform.can_sleep = false
	platform.position = Vector2(0.0, chain_length)
	platform.physics_material_override = PhysicsMaterial.new()
	platform.physics_material_override.friction = 1.0
	platform.physics_material_override.bounce = 0.0
	add_child(platform)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width, platform_height)
	col.shape = rect
	platform.add_child(col)

	var half_w := platform_width * 0.5
	var half_h := platform_height * 0.5
	var wood := Polygon2D.new()
	wood.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h),
	])
	wood.color = Color(0.50, 0.32, 0.18, 1.0)
	platform.add_child(wood)

	var top_light := Line2D.new()
	top_light.points = PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
	])
	top_light.width = 3.0
	top_light.default_color = Color(0.86, 0.66, 0.38, 1.0)
	platform.add_child(top_light)

	var bottom_shadow := Line2D.new()
	bottom_shadow.points = PackedVector2Array([
		Vector2(-half_w, half_h), Vector2(half_w, half_h),
	])
	bottom_shadow.width = 3.0
	bottom_shadow.default_color = Color(0.24, 0.14, 0.08, 1.0)
	platform.add_child(bottom_shadow)

	var seams := 4
	for i in range(1, seams):
		var sx := -half_w + platform_width * float(i) / float(seams)
		var seam := Line2D.new()
		seam.points = PackedVector2Array([
			Vector2(sx, -half_h), Vector2(sx, half_h),
		])
		seam.width = 1.5
		seam.default_color = Color(0.30, 0.18, 0.10, 0.8)
		platform.add_child(seam)

	# Kleine Halterungen an den Kettenenden.
	for side in [-1.0, 1.0]:
		var bracket := Polygon2D.new()
		bracket.polygon = PackedVector2Array([
			Vector2(-5, -4), Vector2(5, -4), Vector2(3, 4), Vector2(-3, 4),
		])
		bracket.position = Vector2(side * (half_w - 8.0), -half_h - 1.0)
		bracket.color = Color(0.22, 0.25, 0.31, 1.0)
		platform.add_child(bracket)

	chain_left = _make_chain_line()
	chain_right = _make_chain_line()

	joint = PinJoint2D.new()
	joint.name = "SwingJoint"
	joint.position = Vector2(0.0, chain_length - platform_height * 0.5)
	joint.softness = 0.0
	add_child(joint)
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(platform)

	_update_chain_visuals()

func _make_chain_line() -> Line2D:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.45, 0.49, 0.56, 1.0)
	line.z_index = -1
	add_child(line)
	return line

func _process(_delta: float) -> void:
	_update_chain_visuals()

func _update_chain_visuals() -> void:
	if platform == null or chain_left == null or chain_right == null:
		return
	var half_w := platform_width * 0.5
	var half_h := platform_height * 0.5
	var top_left := platform.to_global(Vector2(-half_w + 8.0, -half_h))
	var top_right := platform.to_global(Vector2(half_w - 8.0, -half_h))
	chain_left.points = PackedVector2Array([Vector2.ZERO, to_local(top_left)])
	chain_right.points = PackedVector2Array([Vector2.ZERO, to_local(top_right)])

func _physics_process(_delta: float) -> void:
	if is_replica:
		return
	for p in get_tree().get_nodes_in_group("player"):
		var player := p as Node2D
		if player == null:
			continue
		var health = player.get("current_health")
		if health != null and float(health) <= 0.0:
			continue
		var local := platform.to_local(player.global_position)
		if absf(local.x) > platform_width * 0.5:
			continue
		if local.y > -platform_height * 0.5 + 18.0:
			continue
		if local.y < -platform_height * 0.5 - 70.0:
			continue
		var weight := Vector2(float(player.get("velocity").x) * 4.0, 1250.0)
		platform.apply_force(weight, Vector2(local.x, -platform_height * 0.5))
	platform.angular_velocity = clampf(platform.angular_velocity, -4.0, 4.0)

func set_replica(replica: bool) -> void:
	is_replica = replica
	if platform == null:
		return
	platform.freeze = replica
	platform.can_sleep = false
	set_physics_process(not replica)
	if replica:
		platform.collision_layer = 0
		platform.collision_mask = 0
		platform.linear_velocity = Vector2.ZERO
		platform.angular_velocity = 0.0
	else:
		platform.collision_layer = 1
		platform.collision_mask = 7

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": platform.global_position,
		"rot": platform.rotation,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica or platform == null:
		return
	platform.global_position = data.get("pos", platform.global_position)
	platform.rotation = float(data.get("rot", platform.rotation))
	platform.linear_velocity = Vector2.ZERO
	platform.angular_velocity = 0.0
