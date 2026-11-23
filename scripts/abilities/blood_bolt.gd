class_name BloodBolt
extends Node2D

# Ulti "Blutruf" des Blutritters (Nahkampf-Vampir): eine herangezogene
# Blutkugel fliegt als Tropfen zum Blutritter zurück. Trifft sie unterwegs
# einen Gegner, explodiert sie (Schaden + Heilung über
# Player.vamp_melee_bolt_hit). Erreicht sie den Blutritter, lädt sie wie eine
# aufgesammelte Kugel Schild auf. Sie fliegt durch Gelände.
#
# Der Host simuliert, Clients bekommen Lage über den Snapshot ("ents").

const LIFETIME: float = 3.0
const START_SPEED_FACTOR: float = 0.35
const ACCEL_TIME: float = 0.35
const RETURN_RADIUS: float = 22.0
const CORE_RADIUS: float = 6.5
const TRAIL_POINTS: int = 7

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0

var speed: float = 620.0
var hit_radius: float = 26.0

var _age: float = 0.0
var _ended: bool = false
var _net_target: Vector2 = Vector2.ZERO
var _trail: PackedVector2Array = PackedVector2Array()
var _anim: float = 0.0

func setup(owner: Player, fly_speed: float, radius: float) -> void:
	owner_player = owner
	owner_index = owner.player_index
	speed = fly_speed
	hit_radius = radius

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("blood_bolt")
	add_to_group("round_effect")
	z_index = 6
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0 or _age >= LIFETIME:
		finish()
		return
	var to_owner := owner_player.global_position - global_position
	var dist := to_owner.length()
	if dist <= RETURN_RADIUS:
		owner_player.vamp_melee_bolt_return()
		finish()
		return
	var ramp := clampf(_age / ACCEL_TIME, 0.0, 1.0)
	var step := speed * lerpf(START_SPEED_FACTOR, 1.0, ramp) * delta
	global_position += to_owner / maxf(dist, 0.001) * minf(step, dist)
	var hits := owner_player._opponents_within(global_position, hit_radius)
	if not hits.is_empty():
		owner_player.vamp_melee_bolt_hit(global_position)
		finish()

func _process(delta: float) -> void:
	_anim += delta
	if is_replica:
		if global_position.distance_to(_net_target) > 250.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(18.0 * delta, 0.0, 1.0))
	_trail.insert(0, global_position)
	if _trail.size() > TRAIL_POINTS:
		_trail.resize(TRAIL_POINTS)
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group("blood_bolt")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "bbolt", "pos": global_position, "o": owner_index}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	owner_index = int(data.get("o", owner_index))

func remove_replica() -> void:
	finish()

# --- Darstellung ---

func _draw() -> void:
	var offset := ArenaMode.height_offset(ArenaMode.MUZZLE_H) if ArenaMode.active else Vector2.ZERO
	var pulse := 0.5 + 0.5 * sin(_anim * 18.0)
	for i in range(1, _trail.size()):
		var t := float(i) / float(TRAIL_POINTS)
		var local := to_local(_trail[i]) + offset
		draw_circle(local, CORE_RADIUS * (1.0 - t * 0.8), Color(0.75, 0.04, 0.12, 0.55 * (1.0 - t)))
	draw_circle(offset, CORE_RADIUS + 3.0 + 1.5 * pulse, Color(0.9, 0.05, 0.15, 0.28))
	draw_circle(offset, CORE_RADIUS, Color(0.78, 0.03, 0.12, 1.0))
	draw_circle(offset + Vector2(-1.8, -1.8), CORE_RADIUS * 0.35, Color(1.0, 0.6, 0.65, 0.9))
