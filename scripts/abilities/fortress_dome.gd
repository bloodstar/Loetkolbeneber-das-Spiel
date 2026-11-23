class_name FortressDome
extends Node2D

# Bastions Ulti "Festung": eine Kuppel, an der gegnerische Kugeln von außen
# abprallen. Innen heilen Bastion und Verbündete (Player.fortress_tick).
# Evolution "Wanderfestung": die Kuppel wandert mit Bastion. Host simuliert,
# Clients zeichnen aus dem Snapshot.

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var team_id: int = -1

var radius: float = 140.0
var duration: float = 5.0
var tick_interval: float = 0.5
var mobile: bool = false

var _age: float = 0.0
var _tick: float = 0.0
var _ended: bool = false
var _hit_flash: float = 0.0
var _net_target: Vector2 = Vector2.ZERO

func setup(owner: Player, p_radius: float, p_duration: float, p_tick: float, p_mobile: bool) -> void:
	owner_player = owner
	team_id = owner.team_id
	radius = p_radius
	duration = p_duration
	tick_interval = p_tick
	mobile = p_mobile

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("fortress_dome")
	add_to_group("round_effect")
	z_index = 8
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if not is_instance_valid(owner_player) or owner_player.current_health <= 0.0 or _age >= duration:
		finish()
		return
	if mobile:
		global_position = owner_player.global_position
	_reflect_bullets()
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		owner_player.fortress_tick(global_position, radius)

# Kugeln von außen werden an der Kuppelwand gespiegelt (v - 2(v·n)n).
func _reflect_bullets() -> void:
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.is_replica:
			continue
		var shooter = b.shooter
		if is_instance_valid(shooter) and shooter is Player and shooter.team_id == team_id:
			continue
		var to_b: Vector2 = b.global_position - global_position
		var dist := to_b.length()
		if dist > radius + 6.0 or dist < radius - 24.0 or dist < 1.0:
			continue
		var n := to_b / dist
		var v: Vector2 = b.velocity
		if v.dot(n) >= 0.0:
			continue
		b.velocity = v - 2.0 * v.dot(n) * n
		b.global_position = global_position + n * (radius + 7.0)
		_hit_flash = 0.15
		NetFx.emit(get_parent(), "sound", {"snd": ["bounce", 0.3, 2.0]})

func _process(delta: float) -> void:
	if is_replica:
		_age += delta
		_hit_flash = maxf(0.0, _hit_flash - delta)
		global_position = global_position.lerp(_net_target, clampf(14.0 * delta, 0.0, 1.0))
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group("fortress_dome")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

func get_network_state() -> Dictionary:
	return {"id": net_id, "k": "dome", "pos": global_position, "r": radius,
		"left": maxf(0.0, duration - _age), "hit": _hit_flash > 0.0}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	radius = float(data.get("r", radius))
	duration = _age + float(data.get("left", 0.0))
	if bool(data.get("hit", false)):
		_hit_flash = 0.15

func remove_replica() -> void:
	finish()

func _draw() -> void:
	var grow := clampf(_age / 0.2, 0.0, 1.0)
	var r := radius * grow
	var flash := _hit_flash / 0.15
	draw_circle(Vector2.ZERO, r, Color(0.3, 0.95, 0.75, 0.07 + 0.06 * flash))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(0.45, 1.0, 0.85, 0.55 + 0.4 * flash), 3.0, true)
	# Wabenmuster als Andeutung der Schutzhülle.
	for i in range(6):
		var a := TAU * float(i) / 6.0 + _age * 0.3
		draw_line(Vector2.from_angle(a) * r * 0.55, Vector2.from_angle(a) * r * 0.98, Color(0.45, 1.0, 0.85, 0.18), 1.5, true)
	draw_arc(Vector2.ZERO, r * 0.55, 0.0, TAU, 6, Color(0.45, 1.0, 0.85, 0.18), 1.5, true)
