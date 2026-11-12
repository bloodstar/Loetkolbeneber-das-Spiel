class_name BallLightning
extends Node2D

# Volts Fähigkeit "Kugelblitz": eine langsam fliegende Blitzkugel. Sie schockt
# in festen Abständen alle Gegner in ihrer Nähe (wenig Schaden, kurze
# Verlangsamung) und sperrt so Wege ab. An festem Gelände oder nach Ablauf der
# Dauer erlischt sie.
#
# Der Host simuliert Flug und Schaden. Clients bekommen Lage und Restzeit über
# den Snapshot (main.gd "ents") und zeichnen nur.

const FADE_OUT: float = 0.2
const CORE_RADIUS: float = 9.0

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var team_id: int = -1

var velocity: Vector2 = Vector2.ZERO
var duration: float = 3.5
var radius: float = 85.0
var tick_interval: float = 0.4
var damage: float = 6.0
var slow: float = 0.6
# Evolution "Entladung": Explosion mit Betäubung am Ende.
var burst: bool = false
var burst_radius: float = 110.0
var burst_damage: float = 20.0
var burst_stun: float = 0.6
# Arena: Flughöhe über dem Boden.
var arena_z: float = 0.0

var _age: float = 0.0
var _tick: float = 0.0
var _anim: float = 0.0
var _ended: bool = false
var _net_target: Vector2 = Vector2.ZERO
var _arcs: Array = []
var _arc_timer: float = 0.0

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("ball_lightning")
	add_to_group("round_effect")
	z_index = 6
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position

func remaining_time() -> float:
	return maxf(0.0, duration - _age)

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	var next := global_position + velocity * delta
	if _hits_terrain(global_position, next):
		finish()
		return
	global_position = next
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_shock()
	if _age >= duration:
		finish()

func _process(delta: float) -> void:
	_anim += delta
	if is_replica:
		_age += delta
		if global_position.distance_to(_net_target) > 200.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(16.0 * delta, 0.0, 1.0))
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = 0.07
		_arcs.clear()
		for i in range(4):
			var angle := randf() * TAU
			var mid := Vector2.from_angle(angle + randf_range(-0.5, 0.5)) * radius * randf_range(0.3, 0.6)
			_arcs.append([mid, Vector2.from_angle(angle) * radius * randf_range(0.75, 1.0)])
	queue_redraw()

func _hits_terrain(from: Vector2, to: Vector2) -> bool:
	var mask := 1
	if ArenaMode.active:
		mask = ArenaMode.point_band_mask(arena_z)
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	if is_instance_valid(owner_player):
		query.exclude = [owner_player.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.get("collider")
	# Einweg-Stege halten die Kugel nicht auf.
	return not (collider is Node and (collider as Node).is_in_group("one_way_platform"))

func _shock() -> void:
	if not is_instance_valid(owner_player):
		return
	var hit_any := false
	for p in owner_player._opponents_within(global_position, radius):
		hit_any = true
		owner_player._ability_hit(p, damage, Vector2.ZERO)
		p.apply_freeze(slow)
		NetFx.emit(get_parent(), "zap", NetFx.zap_args(global_position, p.global_position,
			Color(1.0, 0.95, 0.35, 0.95), 2.5, 0.14, 5, 10.0))
	if hit_any:
		NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.2, -6.0]})

# Beendet die Kugel (Ablauf, Wand oder Sprungziel). Mit Evolution "Entladung"
# explodiert sie dabei.
func finish(with_burst: bool = true) -> void:
	if _ended:
		return
	_ended = true
	if not is_replica and with_burst and burst and is_instance_valid(owner_player):
		owner_player.volt_orb_burst(global_position, burst_radius, burst_damage, burst_stun)
	remove_from_group(NetEntity.GROUP)
	remove_from_group("ball_lightning")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"k": "orb",
		"pos": global_position,
		"r": radius,
		"left": remaining_time(),
		"z": arena_z,
	}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	radius = float(data.get("r", radius))
	arena_z = float(data.get("z", arena_z))
	duration = _age + float(data.get("left", remaining_time()))

func remove_replica() -> void:
	finish(false)

# --- Darstellung ---

func _draw() -> void:
	var offset := ArenaMode.height_offset(arena_z + ArenaMode.MUZZLE_H) if ArenaMode.active else Vector2.ZERO
	var pulse := 0.5 + 0.5 * sin(_anim * 14.0)
	# Wirkungsbereich als schwacher Ring, damit man ihm ausweichen kann.
	draw_circle(offset, radius, Color(1.0, 0.95, 0.3, 0.05))
	draw_arc(offset, radius, 0.0, TAU, 48, Color(1.0, 0.95, 0.3, 0.22 + 0.10 * pulse), 1.2, true)
	for arc in _arcs:
		var points := PackedVector2Array([offset, offset + arc[0], offset + arc[1]])
		draw_polyline(points, Color(1.0, 0.98, 0.6, 0.55), 1.2, true)
	draw_circle(offset, CORE_RADIUS + 5.0 + 2.0 * pulse, Color(1.0, 0.9, 0.2, 0.25))
	draw_circle(offset, CORE_RADIUS, Color(1.0, 0.95, 0.45, 0.95))
	draw_circle(offset, CORE_RADIUS * 0.5, Color(1.0, 1.0, 0.92, 1.0))
