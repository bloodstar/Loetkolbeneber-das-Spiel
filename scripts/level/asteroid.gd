class_name Asteroid
extends RigidBody2D

## Treibender Asteroid für Weltraum-Maps. Schwereloser Physikkörper (Host
## simuliert, Clients folgen per Snapshot, Typ "asteroid"). Rammt er einen
## Spieler, gibt es Schaden je nach Größe und Tempo (PhysicsImpact).
## Schüsse, Nahkampf und Explosionen zerlegen ihn: groß -> zwei mittlere,
## mittel -> zwei kleine. Kleine Asteroiden mit leuchtendem Kern ("loot")
## enthalten ein Powerup.

signal asteroid_broken(world_position: Vector2, size_class: int, loot: bool, velocity: Vector2)

const RADII: Dictionary = {1: 17.0, 2: 31.0, 3: 50.0}
const HEALTH: Dictionary = {1: 20.0, 2: 60.0, 3: 140.0}
const DAMAGE_MULT: Dictionary = {1: 0.6, 2: 1.0, 3: 1.45}
const MAX_DAMAGE: Dictionary = {1: 12.0, 2: 26.0, 3: 42.0}
const MAX_SPEED: float = 460.0
const BULLET_PUSH: float = 55.0
const BLAST_DAMAGE: float = 32.0
const SPLIT_SPEED: float = 70.0
# Anteil kleiner Bruchstücke eines mittleren Asteroiden mit Powerup-Kern.
const SPLIT_LOOT_CHANCE: float = 0.3
# So weit außerhalb der Karte verschwindet ein Asteroid.
const DESPAWN_MARGIN: float = 520.0

const ROCK: Color = Color(0.46, 0.42, 0.48)
const ROCK_DARK: Color = Color(0.24, 0.21, 0.27)
const ROCK_LIGHT: Color = Color(0.70, 0.66, 0.72)
const LOOT_COLOR: Color = Color(1.0, 0.82, 0.30)

var net_id: int = 0
var object_type: String = "asteroid"
var is_replica: bool = false
var size_class: int = 2
var loot: bool = false
var shape_seed: int = 1
var health: float = 60.0
var hazard_radius: float = 31.0

var _outline: PackedVector2Array = PackedVector2Array()
var _craters: Array[Vector3] = []
var _broken: bool = false
var _previous_velocity: Vector2 = Vector2.ZERO
var _hit_cooldowns: Dictionary = {}
var _time: float = 0.0
var _net_pos: Vector2 = Vector2.ZERO
var _net_rot: float = 0.0
var _net_seen: bool = false

static func radius_for(size: int) -> float:
	return float(RADII.get(clampi(size, 1, 3), 31.0))

func _ready() -> void:
	add_to_group("asteroid")
	add_to_group("space_hazard")
	size_class = clampi(size_class, 1, 3)
	hazard_radius = radius_for(size_class)
	health = float(HEALTH[size_class])
	_build_shape()
	collision_layer = 1
	collision_mask = 7
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	mass = 0.6 * float(size_class * size_class)
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.2
	physics_material_override.bounce = 0.7
	var col := CollisionPolygon2D.new()
	col.polygon = _scaled(_outline, 0.94)
	add_child(col)
	z_index = 1
	if is_replica:
		set_replica(true)
	else:
		contact_monitor = true
		max_contacts_reported = 6

func _build_shape() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = shape_seed
	var r := hazard_radius
	var n := 9 + size_class * 2
	_outline = PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n) + rng.randf_range(-0.12, 0.12)
		_outline.append(Vector2.from_angle(a) * r * rng.randf_range(0.78, 1.08))
	_craters.clear()
	for i in range(size_class + 1):
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.15, 0.55) * r
		_craters.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.12, 0.24) * r))

func _scaled(points: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * f)
	return out

func _draw() -> void:
	draw_colored_polygon(_outline, ROCK_DARK)
	draw_colored_polygon(_scaled(_outline, 0.86), ROCK)
	# Lichtkante oben links.
	var lit := PackedVector2Array()
	for p in _scaled(_outline, 0.86):
		lit.append(p + Vector2(-2.0, -2.0))
	draw_polyline(_close(lit), Color(ROCK_LIGHT.r, ROCK_LIGHT.g, ROCK_LIGHT.b, 0.35), 2.0, true)
	for c in _craters:
		draw_circle(Vector2(c.x, c.y), c.z, ROCK_DARK)
		draw_circle(Vector2(c.x - c.z * 0.2, c.y - c.z * 0.2), c.z * 0.65, Color(ROCK.r * 0.8, ROCK.g * 0.8, ROCK.b * 0.8))
	if loot:
		var pulse := 0.7 + 0.3 * sin(_time * 5.0)
		var r := hazard_radius
		draw_circle(Vector2.ZERO, r * 0.95, Color(LOOT_COLOR.r, LOOT_COLOR.g, LOOT_COLOR.b, 0.12 * pulse))
		var gem := PackedVector2Array([
			Vector2(0.0, -r * 0.5), Vector2(r * 0.38, 0.0), Vector2(0.0, r * 0.5), Vector2(-r * 0.38, 0.0),
		])
		draw_colored_polygon(gem, Color(LOOT_COLOR.r, LOOT_COLOR.g, LOOT_COLOR.b, 0.85 * pulse + 0.15))
		draw_polyline(_close(gem), Color(1.0, 1.0, 0.85, 0.9), 1.5, true)
	draw_polyline(_close(_outline), Color(0.08, 0.06, 0.10, 0.9), 2.0, true)

func _close(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if out.size() > 0:
		out.append(out[0])
	return out

func _process(delta: float) -> void:
	_time += delta
	if loot:
		queue_redraw()
	if not is_replica or not _net_seen:
		return
	var t := clampf(delta * 16.0, 0.0, 1.0)
	global_position = global_position.lerp(_net_pos, t)
	rotation = lerp_angle(rotation, _net_rot, t)

func _physics_process(delta: float) -> void:
	if is_replica or _broken:
		return
	PhysicsImpact.tick_cooldowns(_hit_cooldowns, delta)
	PhysicsImpact.check_players(self, _previous_velocity, _hit_cooldowns,
		float(DAMAGE_MULT[size_class]), float(MAX_DAMAGE[size_class]), 1.0, null)
	if linear_velocity.length_squared() > MAX_SPEED * MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	_previous_velocity = linear_velocity
	var map_rect := Rect2(Vector2.ZERO, Vector2(float(LevelGenerator.map_w), float(LevelGenerator.map_h)) * LevelGenerator.TILE_SIZE)
	if not map_rect.grow(DESPAWN_MARGIN).has_point(global_position):
		_broken = true
		queue_free()

func hit_crate(projectile: Node2D = null) -> void:
	if is_replica or _broken:
		return
	var amount := 20.0
	if projectile != null:
		var dmg = projectile.get("damage")
		if dmg is float or dmg is int:
			amount = maxf(1.0, float(dmg))
		var vel = projectile.get("velocity")
		if vel is Vector2 and (vel as Vector2).length_squared() > 1.0:
			apply_central_impulse((vel as Vector2).normalized() * BULLET_PUSH)
	_take_hit(amount)

func apply_blast(blast_position: Vector2, radius: float, force: float = 520.0, _attacker: Node = null) -> void:
	if is_replica or _broken:
		return
	var distance := blast_position.distance_to(global_position)
	if distance > radius + hazard_radius:
		return
	var falloff := clampf(1.0 - distance / maxf(1.0, radius + hazard_radius), 0.15, 1.0)
	var direction := (global_position - blast_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	apply_central_impulse(direction * force * falloff * 0.6)
	_take_hit(BLAST_DAMAGE * falloff)

func _take_hit(amount: float) -> void:
	if _broken:
		return
	health -= amount
	_flash()
	SoundManager.play_sound("hit", 0.2, -5.0)
	NetFx.send("mobj", NetFx.mobj_args(self, "hit"))
	if health <= 0.0:
		_break_apart()

func play_network_fx(_method: String) -> void:
	_flash()
	SoundManager.play_sound("hit", 0.2, -5.0)

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.7, 1.4, 1.2), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func _break_apart() -> void:
	if _broken:
		return
	_broken = true
	_spawn_debris(global_position)
	SoundManager.play_sound("explosion" if size_class >= 2 else "hit", 0.2, -4.0 if size_class >= 2 else -2.0)
	asteroid_broken.emit(global_position, size_class, loot, linear_velocity)
	queue_free()

func _spawn_debris(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := Node2D.new()
	fx.global_position = at
	fx.z_index = 5
	parent.add_child(fx)
	var count := 4 + size_class * 3
	for i in range(count):
		var bit := Polygon2D.new()
		var s := (2.5 + float(i % 3) * 1.6) * (0.7 + 0.3 * float(size_class))
		bit.polygon = PackedVector2Array([Vector2(-s, -s * 0.7), Vector2(s, -s * 0.3), Vector2(s * 0.4, s), Vector2(-s * 0.8, s * 0.5)])
		bit.color = ROCK if i % 2 == 0 else ROCK_DARK
		if loot and i % 3 == 0:
			bit.color = LOOT_COLOR
		fx.add_child(bit)
		var direction := Vector2.from_angle(float(i) * TAU / float(count) + 0.4)
		var tw := bit.create_tween()
		tw.tween_property(bit, "position", direction * (hazard_radius + 16.0 + float(i % 4) * 10.0), 0.35)
		tw.parallel().tween_property(bit, "rotation", float(i) * 1.3, 0.35)
		tw.parallel().tween_property(bit, "modulate:a", 0.0, 0.38)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.42)
	cleanup.tween_callback(fx.queue_free)

## Client: Der Asteroid fehlt im Host-Snapshot, er ist zerbrochen (oder
## aus der Karte getrieben, dann sieht man die Trümmer nicht).
func spawn_remote_explosion() -> void:
	if not _broken:
		_broken = true
		var map_rect := Rect2(Vector2.ZERO, Vector2(float(LevelGenerator.map_w), float(LevelGenerator.map_h)) * LevelGenerator.TILE_SIZE)
		if map_rect.grow(60.0).has_point(global_position):
			_spawn_debris(global_position)
			SoundManager.play_sound("explosion" if size_class >= 2 else "hit", 0.2, -4.0)
	queue_free()

func set_replica(replica: bool) -> void:
	is_replica = replica
	freeze = replica
	contact_monitor = not replica
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
		"size": size_class,
		"loot": loot,
		"seed": shape_seed,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	_net_pos = data.get("pos", global_position)
	_net_rot = float(data.get("rot", rotation))
	if not _net_seen:
		_net_seen = true
		global_position = _net_pos
		rotation = _net_rot
