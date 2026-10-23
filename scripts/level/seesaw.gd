class_name Seesaw
extends Node2D

const TILE_SIZE: float = 36.0

var net_id: int = 0
var object_type: String = "seesaw"
var is_replica: bool = false
var plank_width: float = 6.0 * TILE_SIZE
var plank_height: float = 14.0
var max_angle: float = 0.40
var suspended: bool = false
var chain_length: float = 0.0

var anchor: StaticBody2D
var plank: RigidBody2D
var joint: PinJoint2D

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

	if suspended:
		_build_suspension()
	else:
		# Statisches Dreieck als Wippenlager.
		var base := Polygon2D.new()
		base.name = "PivotBase"
		base.polygon = PackedVector2Array([
			Vector2(-32, 6), Vector2(32, 6), Vector2(12, 34), Vector2(-12, 34),
		])
		base.color = Color(0.16, 0.19, 0.26, 1.0)
		base.z_index = -1
		add_child(base)

		var base_light := Polygon2D.new()
		base_light.polygon = PackedVector2Array([
			Vector2(-18, 10), Vector2(18, 10), Vector2(7, 28), Vector2(-7, 28),
		])
		base_light.color = Color(0.28, 0.32, 0.42, 1.0)
		base_light.z_index = -1
		add_child(base_light)

		var base_glow := Polygon2D.new()
		base_glow.polygon = PackedVector2Array([
			Vector2(-6, 19), Vector2(6, 19), Vector2(3, 26), Vector2(-3, 26),
		])
		base_glow.color = Color(1.0, 0.55, 0.2, 0.9)
		base_glow.z_index = -1
		add_child(base_glow)

	plank = RigidBody2D.new()
	plank.name = "Plank"
	plank.collision_layer = 1
	plank.collision_mask = 7
	plank.mass = 1.5
	plank.gravity_scale = 1.0
	plank.linear_damp = 2.5
	plank.angular_damp = 2.2
	plank.can_sleep = false
	add_child(plank)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(plank_width, plank_height)
	col.shape = rect
	plank.add_child(col)

	var half_w := plank_width * 0.5
	var half_h := plank_height * 0.5
	var wood := Polygon2D.new()
	wood.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h),
	])
	wood.color = Color(0.58, 0.35, 0.18, 1.0)
	plank.add_child(wood)

	var top_light := Line2D.new()
	top_light.points = PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
	])
	top_light.width = 3.0
	top_light.default_color = Color(0.92, 0.70, 0.38, 1.0)
	plank.add_child(top_light)

	var bottom_shadow := Line2D.new()
	bottom_shadow.points = PackedVector2Array([
		Vector2(-half_w, half_h), Vector2(half_w, half_h),
	])
	bottom_shadow.width = 3.0
	bottom_shadow.default_color = Color(0.28, 0.16, 0.08, 1.0)
	plank.add_child(bottom_shadow)

	var seams := 5
	for i in range(1, seams):
		var sx := -half_w + plank_width * float(i) / float(seams)
		var seam := Line2D.new()
		seam.points = PackedVector2Array([
			Vector2(sx, -half_h), Vector2(sx, half_h),
		])
		seam.width = 1.5
		seam.default_color = Color(0.35, 0.20, 0.10, 0.8)
		plank.add_child(seam)

	joint = PinJoint2D.new()
	joint.name = "PivotJoint"
	joint.position = Vector2.ZERO
	joint.softness = 0.0
	add_child(joint)
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(plank)

func _build_suspension() -> void:
	var top_y := -chain_length if chain_length > 0.0 else -3.0 * TILE_SIZE
	var half_beam := plank_width * 0.5
	var beam := Polygon2D.new()
	beam.name = "SuspensionBeam"
	beam.polygon = PackedVector2Array([
		Vector2(-half_beam, top_y - 7.0),
		Vector2(half_beam, top_y - 7.0),
		Vector2(half_beam, top_y + 7.0),
		Vector2(-half_beam, top_y + 7.0),
	])
	beam.color = Color(0.20, 0.23, 0.30, 1.0)
	beam.z_index = -1
	add_child(beam)

	var beam_light := Line2D.new()
	beam_light.points = PackedVector2Array([
		Vector2(-half_beam + 8.0, top_y - 6.0),
		Vector2(half_beam - 8.0, top_y - 6.0),
	])
	beam_light.width = 2.0
	beam_light.default_color = Color(0.60, 0.72, 0.85, 0.9)
	beam_light.z_index = -1
	add_child(beam_light)

	for side in [-1.0, 1.0]:
		var chain := Line2D.new()
		chain.name = "SuspensionChain"
		chain.points = PackedVector2Array([
			Vector2(side * (half_beam - 22.0), top_y + 5.0),
			Vector2(side * 18.0, -4.0),
		])
		chain.width = 3.0
		chain.default_color = Color(0.48, 0.54, 0.62, 1.0)
		chain.z_index = -1
		add_child(chain)

	var hub := Polygon2D.new()
	hub.name = "PivotHub"
	hub.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
	])
	hub.color = Color(0.32, 0.38, 0.48, 1.0)
	hub.z_index = 1
	add_child(hub)

	var hub_glow := Polygon2D.new()
	hub_glow.polygon = PackedVector2Array([
		Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3),
	])
	hub_glow.color = Color(1.0, 0.62, 0.24, 0.95)
	hub_glow.z_index = 2
	add_child(hub_glow)

func _physics_process(_delta: float) -> void:
	if is_replica:
		return
	var torque := 0.0
	var weighting_players := 0
	for p in get_tree().get_nodes_in_group("player"):
		var player := p as Node2D
		if player == null:
			continue
		var health = player.get("current_health")
		if health != null and float(health) <= 0.0:
			continue
		var local := plank.to_local(player.global_position)
		if absf(local.x) > plank_width * 0.5 - 4.0:
			continue
		if local.y > -plank_height * 0.5 + 12.0:
			continue
		if local.y < -plank_height * 0.5 - 90.0:
			continue
		var side := signf(local.x)
		torque += side * (240.0 + absf(local.x) * 2.2)
		weighting_players += 1

	if weighting_players == 0:
		# Sanfte Rückstellung in die Waagerechte, wenn niemand auf der Wippe steht.
		torque = -plank.rotation * 46.0

	plank.apply_torque(torque)
	plank.angular_velocity = clampf(plank.angular_velocity, -4.5, 4.5)
	if absf(plank.rotation) > max_angle:
		plank.rotation = clampf(plank.rotation, -max_angle, max_angle)
		plank.angular_velocity = 0.0

func set_replica(replica: bool) -> void:
	is_replica = replica
	if plank == null:
		return
	plank.freeze = replica
	plank.can_sleep = false
	set_physics_process(not replica)
	if replica:
		plank.collision_layer = 0
		plank.collision_mask = 0
		plank.linear_velocity = Vector2.ZERO
		plank.angular_velocity = 0.0
	else:
		plank.collision_layer = 1
		plank.collision_mask = 7

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": plank.global_position,
		"rot": plank.rotation,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica or plank == null:
		return
	plank.global_position = data.get("pos", plank.global_position)
	plank.rotation = float(data.get("rot", plank.rotation))
	plank.linear_velocity = Vector2.ZERO
	plank.angular_velocity = 0.0
