class_name MagnetHook
extends Node2D

# Bastions Fähigkeit "Magnethaken": fliegt geradeaus. Trifft er einen Gegner,
# wird der kurz betäubt und zu Bastion gezogen (Player.bastion_hook_hit).
# An Gelände oder nach voller Weite rollt sich die Kette wieder ein.
# Evolution "Magnetfeld": unterwegs schluckt der Haken gegnerische Kugeln
# und sammelt Powerups für Bastion ein. Host simuliert, Clients zeichnen.

const HIT_RADIUS: float = 14.0
const PULL_MAX_TIME: float = 0.5
const PULL_STOP_DISTANCE: float = 46.0

enum State { FLY, PULL, RETRACT }

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0

var direction: Vector2 = Vector2.RIGHT
var max_range: float = 380.0
var speed: float = 950.0
var pull_speed: float = 1000.0
var magnet: bool = false
var magnet_radius: float = 55.0
var arena_z: float = 0.0

var state: int = State.FLY
var _travelled: float = 0.0
var _pull_time: float = 0.0
var _target = null # Player oder HordeEnemy
var _ended: bool = false
var _net_target: Vector2 = Vector2.ZERO

func setup(owner: Player, dir: Vector2, p_range: float, p_speed: float, p_pull_speed: float) -> void:
	owner_player = owner
	owner_index = owner.player_index
	direction = dir.normalized()
	max_range = p_range
	speed = p_speed
	pull_speed = p_pull_speed

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("round_effect")
	z_index = 9
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0:
		finish()
		return
	match state:
		State.FLY:
			var next := global_position + direction * speed * delta
			if _hits_terrain(global_position, next) or _travelled >= max_range:
				state = State.RETRACT
				return
			_travelled += speed * delta
			global_position = next
			if magnet:
				_magnet_sweep()
			var hits: Array = owner_player._opponents_within(global_position, HIT_RADIUS + Player.MELEE_BODY_RADIUS)
			if not hits.is_empty():
				_target = hits[0]
				state = State.PULL
				owner_player.bastion_hook_hit(_target)
		State.PULL:
			_pull_time += delta
			if not is_instance_valid(_target) or _target.current_health <= 0.0:
				state = State.RETRACT
				return
			var to_owner: Vector2 = owner_player.global_position - _target.global_position
			if to_owner.length() <= PULL_STOP_DISTANCE or _pull_time >= PULL_MAX_TIME:
				_target.velocity *= 0.2
				finish()
				return
			_target.velocity = to_owner.normalized() * pull_speed
			_target.knockback_timer = maxf(_target.knockback_timer, 0.1)
			global_position = _target.global_position
		State.RETRACT:
			var back := owner_player.global_position - global_position
			if back.length() < 20.0:
				finish()
				return
			global_position += back.normalized() * minf(speed * 1.4 * delta, back.length())

func _magnet_sweep() -> void:
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.is_replica:
			continue
		var shooter = b.shooter
		if shooter == owner_player or (is_instance_valid(shooter) and shooter is Player and shooter.team_id == owner_player.team_id):
			continue
		if b.global_position.distance_to(global_position) <= magnet_radius:
			b.block_by_drone()
	for pu in get_tree().get_nodes_in_group("powerup_pickup"):
		if is_instance_valid(pu) and pu.has_method("_collect") and pu.global_position.distance_to(global_position) <= magnet_radius:
			pu._collect(owner_player)

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

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	queue_free()

func is_active() -> bool:
	return not _ended

func _process(delta: float) -> void:
	if is_replica:
		if global_position.distance_to(_net_target) > 240.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(20.0 * delta, 0.0, 1.0))
		if owner_player == null or not is_instance_valid(owner_player):
			owner_player = _find_owner()
	queue_redraw()

func _find_owner() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.player_index == owner_index:
			return p
	return null

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "hook", "pos": global_position, "o": owner_index, "z": arena_z, "m": magnet}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	owner_index = int(data.get("o", owner_index))
	arena_z = float(data.get("z", arena_z))
	magnet = bool(data.get("m", magnet))

func remove_replica() -> void:
	finish()

func _draw() -> void:
	var offset := ArenaMode.height_offset(arena_z + ArenaMode.MUZZLE_H) if ArenaMode.active else Vector2.ZERO
	if is_instance_valid(owner_player):
		var start := to_local(owner_player.global_position) + offset
		var seg := 8.0
		var length := start.distance_to(offset)
		var steps := int(length / seg)
		for i in range(steps):
			var p := start.lerp(offset, float(i) / float(maxi(1, steps)))
			draw_circle(p, 2.0, Color(0.6, 0.65, 0.7, 0.9))
	if magnet:
		draw_circle(offset, magnet_radius, Color(0.4, 0.7, 1.0, 0.08))
	draw_circle(offset, 6.0, Color(0.75, 0.8, 0.85, 1.0))
	draw_arc(offset, 7.0, 0.0, TAU, 16, Color(0.3, 0.5, 1.0, 0.9), 2.0, true)
