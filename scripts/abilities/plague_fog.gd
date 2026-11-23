class_name PlagueFog
extends Node2D

# Spores Ulti "Seuchennebel": eine große Giftwolke, die mit Spore mitwandert.
# Jeder Tick ruft Player.plague_tick (Gift, Verlangsamung, Heilung für
# Spore). Host simuliert, Clients zeichnen aus dem Snapshot.

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null

var radius: float = 260.0
var duration: float = 6.0
var tick_interval: float = 0.5

var _age: float = 0.0
var _tick: float = 0.0
var _ended: bool = false
var _net_target: Vector2 = Vector2.ZERO

func setup(owner: Player, p_radius: float, p_duration: float, p_tick: float) -> void:
	owner_player = owner
	radius = p_radius
	duration = p_duration
	tick_interval = p_tick

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("round_effect")
	z_index = 5
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0 or _age >= duration:
		finish()
		return
	global_position = global_position.lerp(owner_player.global_position, clampf(10.0 * delta, 0.0, 1.0))
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		owner_player.plague_tick(global_position, radius, tick_interval)

func _process(delta: float) -> void:
	if is_replica:
		_age += delta
		global_position = global_position.lerp(_net_target, clampf(12.0 * delta, 0.0, 1.0))
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "fog", "pos": global_position, "r": radius, "left": maxf(0.0, duration - _age)}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	radius = float(data.get("r", radius))
	duration = _age + float(data.get("left", 0.0))

func remove_replica() -> void:
	finish()

func _draw() -> void:
	var fade := clampf((duration - _age) / 0.6, 0.0, 1.0) * clampf(_age / 0.3, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.75, 0.2, 0.10 * fade))
	for i in range(9):
		var a := _age * (0.4 + 0.07 * float(i)) + TAU * float(i) / 9.0
		var d := radius * (0.35 + 0.35 * sin(_age * 0.7 + float(i)))
		draw_circle(Vector2(cos(a), sin(a)) * d, radius * 0.28, Color(0.45, 0.85, 0.25, 0.07 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, Color(0.55, 1.0, 0.3, 0.30 * fade), 2.0, true)
