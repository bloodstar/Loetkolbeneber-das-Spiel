class_name BloodMissile
extends Node2D

# Fähigkeit "Blutgeschosse" des Fernkampf-Vampirs: jede Blutkugel, die um den
# Vampir kreist, fliegt als zielsuchendes Geschoss zum nächsten Gegner (wie
# arkane Geschosse). Die Kugeln starten kurz nacheinander (delay), fliegen
# durch Gelände und explodieren am Gegner (Player.vampire_missile_hit).
#
# Der Host simuliert, Clients bekommen Lage über den Snapshot ("ents").

const LIFETIME: float = 2.4
const TRAIL_POINTS: int = 8
const CORE_RADIUS: float = 5.5
const TARGET_RANGE: float = 1100.0

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0

var speed: float = 560.0
var turn_rate: float = 9.0
var hit_radius: float = 18.0
# Wartezeit vor dem Start; so lange hängt die Kugel an ihrem Platz.
var delay: float = 0.0
var velocity: Vector2 = Vector2.ZERO

var _age: float = 0.0
var _ended: bool = false
var _launched: bool = false
var _target: Node2D = null
var _net_target: Vector2 = Vector2.ZERO
var _trail: PackedVector2Array = PackedVector2Array()
var _anim: float = 0.0

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("blood_missile")
	add_to_group("round_effect")
	z_index = 6
	_anim = randf() * TAU
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0:
		finish()
		return
	if delay > 0.0:
		delay -= delta
		return
	if not _launched:
		_launched = true
		_target = _pick_target()
		owner_player._fx("sound", {"snd": ["shoot", 0.15, -6.0]})
	_age += delta
	if _age >= LIFETIME:
		finish()
		return
	if not _target_valid():
		_target = _pick_target()
	if _target != null:
		var want := (_target.global_position - global_position).normalized() * speed
		# Lenkt mit begrenzter Drehrate, nah am Ziel schärfer.
		var dist := global_position.distance_to(_target.global_position)
		var rate := turn_rate * (1.0 + clampf(1.0 - dist / 300.0, 0.0, 1.0) * 2.0)
		velocity = velocity.lerp(want, clampf(rate * delta, 0.0, 1.0))
	velocity = velocity.normalized() * minf(speed, velocity.length() + speed * 3.0 * delta)
	global_position += velocity * delta
	var hits := owner_player._opponents_within(global_position, hit_radius)
	if not hits.is_empty():
		owner_player.vampire_missile_hit(global_position)
		finish()

func _target_valid() -> bool:
	if _target == null or not is_instance_valid(_target):
		return false
	if _target is Player:
		var p := _target as Player
		return p.current_health > 0.0 and not p.is_stealthed()
	if _target is HordeEnemy:
		return (_target as HordeEnemy).is_alive()
	return true

func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_score := INF
	var aim := owner_player.aim_direction.normalized()
	for node in owner_player._opponents_within(global_position, TARGET_RANGE):
		if node is Player and (node as Player).is_stealthed():
			continue
		var to: Vector2 = node.global_position - global_position
		# Gegner in Zielrichtung werden bevorzugt.
		var score := to.length() * (1.6 - 0.6 * aim.dot(to.normalized()))
		if score < best_score:
			best = node
			best_score = score
	return best

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
	remove_from_group("blood_missile")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.1)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "bmissile", "pos": global_position, "o": owner_index}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	owner_index = int(data.get("o", owner_index))

func remove_replica() -> void:
	finish()

# --- Darstellung ---

func _draw() -> void:
	var offset := ArenaMode.height_offset(ArenaMode.MUZZLE_H) if ArenaMode.active else Vector2.ZERO
	var pulse := 0.5 + 0.5 * sin(_anim * 16.0)
	for i in range(1, _trail.size()):
		var t := float(i) / float(TRAIL_POINTS)
		var local := to_local(_trail[i]) + offset
		draw_circle(local, CORE_RADIUS * (1.0 - t * 0.75), Color(0.85, 0.05, 0.16, 0.6 * (1.0 - t)))
	draw_circle(offset, CORE_RADIUS + 3.5 + 1.5 * pulse, Color(1.0, 0.1, 0.2, 0.3))
	draw_circle(offset, CORE_RADIUS, Color(0.82, 0.03, 0.12, 1.0))
	draw_circle(offset + Vector2(-1.6, -1.6), CORE_RADIUS * 0.35, Color(1.0, 0.65, 0.7, 0.95))
