class_name SporeShroom
extends Node2D

# Spores Fähigkeit "Giftpilz": eine Falle am Boden. Nach kurzer Scharfschalt-
# zeit platzt sie, sobald ein Gegner nah kommt oder eine Kugel sie trifft,
# und hinterlässt eine Giftwolke (Player.spore_shroom_pop). Evolution
# "Sprungpilz": Spore springt vom eigenen Pilz hoch. Host simuliert, Clients
# zeichnen aus dem Snapshot.

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var team_id: int = -1

var lifetime: float = 18.0
var arm_time: float = 0.6
var trigger_radius: float = 55.0
var bounce: bool = false
var arena_z: float = 0.0

var _age: float = 0.0
var _ended: bool = false
var _bounce_cd: float = 0.0
var _armed: bool = false

func setup(owner: Player, p_lifetime: float, p_arm: float, p_trigger: float, p_bounce: bool) -> void:
	owner_player = owner
	team_id = owner.team_id
	lifetime = p_lifetime
	arm_time = p_arm
	trigger_radius = p_trigger
	bounce = p_bounce

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("spore_shroom")
	add_to_group("round_effect")
	z_index = 4
	if not is_replica:
		net_id = NetEntity.next_id()

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	_bounce_cd = maxf(0.0, _bounce_cd - delta)
	if not is_instance_valid(owner_player) or _age >= lifetime:
		discard()
		return
	_armed = _age >= arm_time
	if bounce and _bounce_cd <= 0.0 and not ArenaMode.active:
		var to_owner := owner_player.global_position - global_position
		if absf(to_owner.x) < 18.0 and to_owner.y < 0.0 and to_owner.y > -26.0 and owner_player.velocity.y >= 0.0:
			_bounce_cd = 0.4
			owner_player.spore_shroom_bounce()
	if not _armed:
		return
	if not owner_player._opponents_within(global_position, trigger_radius).is_empty():
		pop()
		return
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.is_replica:
			continue
		if b.global_position.distance_to(global_position) > 16.0:
			continue
		var shooter = b.shooter
		if is_instance_valid(shooter) and shooter is Player and shooter != owner_player and shooter.team_id == team_id:
			continue
		b.block_by_drone()
		pop()
		return

func pop() -> void:
	if _ended:
		return
	if not is_replica and is_instance_valid(owner_player):
		owner_player.spore_shroom_pop(global_position)
	_end()

# Ohne Wolke verschwinden (Limit erreicht, Ablauf).
func discard() -> void:
	_end()

func _end() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group("spore_shroom")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

func _process(delta: float) -> void:
	if is_replica:
		_age += delta
	queue_redraw()

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "shroom", "pos": global_position, "armed": _armed, "b": bounce}

func apply_network_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	_armed = bool(data.get("armed", _armed))
	bounce = bool(data.get("b", bounce))

func remove_replica() -> void:
	_end()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_age * (6.0 if _armed else 2.0))
	var cap := Color(0.55, 0.9, 0.3, 1.0) if _armed else Color(0.4, 0.6, 0.3, 0.8)
	if bounce:
		cap = cap.lerp(Color(0.9, 0.5, 1.0), 0.35)
	draw_rect(Rect2(-2.5, -6.0, 5.0, 7.0), Color(0.9, 0.85, 0.7, 1.0))
	var pts := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * float(i) / 12.0
		pts.append(Vector2(cos(a) * 9.0, -6.0 + sin(a) * 7.0))
	draw_colored_polygon(pts, cap)
	draw_circle(Vector2(-3.5, -9.0), 1.5, Color(1, 1, 0.8, 0.9))
	draw_circle(Vector2(3.0, -10.5), 1.2, Color(1, 1, 0.8, 0.9))
	if _armed:
		draw_circle(Vector2(0, -8.0), 13.0 + 2.0 * pulse, Color(0.5, 1.0, 0.3, 0.08 + 0.06 * pulse))
