class_name BladeBoomerang
extends Node2D

# Klinges Fähigkeit "Klingenbumerang": das Schwert fliegt geradeaus bis zur
# vollen Weite oder bis zur Wand und kehrt dann zu Klinge zurück. Jeder
# Gegner wird auf Hin- und Rückweg je einmal getroffen (Player.boomerang_hit).
# Solange es fliegt, schlägt Klinge nicht. Host simuliert, Clients zeichnen.

const MAX_TIME: float = 3.0
const CATCH_DISTANCE: float = 18.0

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null

var direction: Vector2 = Vector2.RIGHT
var max_range: float = 280.0
var speed: float = 620.0
var damage: float = 10.0
var hit_radius: float = 24.0
var arena_z: float = 0.0

var returning: bool = false
var _travelled: float = 0.0
var _age: float = 0.0
var _spin: float = 0.0
var _ended: bool = false
var _hit_out: Array = []
var _hit_back: Array = []
var _net_target: Vector2 = Vector2.ZERO

func setup(owner: Player, dir: Vector2, p_range: float, p_speed: float, p_damage: float, p_radius: float) -> void:
	owner_player = owner
	direction = dir.normalized()
	max_range = p_range
	speed = p_speed
	damage = p_damage
	hit_radius = p_radius

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("blade_boomerang")
	add_to_group("round_effect")
	z_index = 9
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0:
		finish()
		return
	if not returning:
		var next := global_position + direction * speed * delta
		if _hits_terrain(global_position, next) or _travelled >= max_range:
			returning = true
		else:
			_travelled += speed * delta
			global_position = next
	else:
		var to_owner := owner_player.global_position - global_position
		var catch := CATCH_DISTANCE
		if owner_player._has_ability_evolution("klinge_catch"):
			catch = Player.KLINGEEVO_CATCH_RADIUS
		if to_owner.length() <= catch or _age >= MAX_TIME:
			owner_player.boomerang_caught()
			finish()
			return
		global_position += to_owner.normalized() * minf(speed * 1.15 * delta, to_owner.length())
	_hit_players()

func _hit_players() -> void:
	var list := _hit_back if returning else _hit_out
	var dir := direction
	if returning:
		dir = (owner_player.global_position - global_position).normalized()
	for p in owner_player._opponents_within(global_position, hit_radius + Player.MELEE_BODY_RADIUS):
		if list.has(p):
			continue
		list.append(p)
		owner_player.boomerang_hit(p, damage, dir)

func _hits_terrain(from: Vector2, to: Vector2) -> bool:
	var mask := 1
	if ArenaMode.active:
		mask = ArenaMode.point_band_mask(arena_z)
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	query.exclude = [owner_player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.get("collider")
	return not (collider is Node and (collider as Node).is_in_group("one_way_platform"))

func _process(delta: float) -> void:
	_spin += delta * 22.0
	if is_replica:
		if global_position.distance_to(_net_target) > 200.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(18.0 * delta, 0.0, 1.0))
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group("blade_boomerang")
	queue_free()

func is_active() -> bool:
	return not _ended

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "boomerang", "pos": global_position, "z": arena_z}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	arena_z = float(data.get("z", arena_z))

func remove_replica() -> void:
	finish()

func _draw() -> void:
	var offset := ArenaMode.height_offset(arena_z + ArenaMode.MUZZLE_H) if ArenaMode.active else Vector2.ZERO
	var a := Vector2.from_angle(_spin)
	var blade := Color(0.92, 0.95, 1.0, 1.0)
	draw_circle(offset, 16.0, Color(1.0, 0.6, 0.8, 0.10))
	draw_line(offset - a * 16.0, offset + a * 16.0, blade, 3.0, true)
	draw_line(offset - a.orthogonal() * 5.0, offset + a.orthogonal() * 5.0, Color(0.55, 0.35, 0.2, 1.0), 2.5, true)
