class_name IgnisMeteor
extends Node2D

# Ignis-Ulti "Meteorschauer": ein Einschlag. Erst erscheint ein Warnkreis am
# Boden, nach delay Sekunden schlägt der Meteor ein (Schaden, Rückstoß und
# Feuerfläche über Player.ignis_meteor_impact). Der Host zählt die Zeit,
# Clients zeichnen Warnkreis und fallenden Brocken aus dem Snapshot.

const FALL_TIME: float = 0.35

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null

var delay: float = 0.8
var radius: float = 72.0
var damage: float = 22.0
var knockback: float = 380.0

var _age: float = 0.0
var _ended: bool = false

func setup(owner: Player, _pos: Vector2, p_delay: float, p_radius: float, p_damage: float, p_knockback: float) -> void:
	owner_player = owner
	delay = p_delay
	radius = p_radius
	damage = p_damage
	knockback = p_knockback

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("round_effect")
	z_index = 7
	if not is_replica:
		net_id = NetEntity.next_id()

func _process(delta: float) -> void:
	if _ended:
		return
	_age += delta
	if not is_replica and _age >= delay:
		if is_instance_valid(owner_player):
			owner_player.ignis_meteor_impact(global_position, radius, damage, knockback)
		finish()
		return
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	queue_free()

func is_active() -> bool:
	return not _ended

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "meteor", "pos": global_position, "r": radius, "left": maxf(0.0, delay - _age)}

func apply_network_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	radius = float(data.get("r", radius))
	delay = _age + float(data.get("left", maxf(0.0, delay - _age)))

func remove_replica() -> void:
	finish()

func _draw() -> void:
	var t := clampf(_age / maxf(0.01, delay), 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_age * 18.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.1, 0.06 + 0.10 * t))
	draw_circle(Vector2.ZERO, radius * t, Color(1.0, 0.45, 0.1, 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.45 + 0.3 * pulse), 2.0, true)
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color(1.0, 0.7, 0.3, 0.8), 2.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color(1.0, 0.7, 0.3, 0.8), 2.0)
	# Der Brocken fällt schräg von oben herein.
	var left := delay - _age
	if left < FALL_TIME:
		var f := clampf(left / FALL_TIME, 0.0, 1.0)
		var rock := Vector2(-90.0, -340.0) * f
		var size := 7.0 + radius * 0.12
		draw_line(rock + Vector2(-30, -110) * 0.4, rock, Color(1.0, 0.6, 0.2, 0.5), size * 0.9, true)
		draw_circle(rock, size, Color(0.35, 0.18, 0.1, 1.0))
		draw_circle(rock, size * 0.6, Color(1.0, 0.55, 0.15, 0.9))
