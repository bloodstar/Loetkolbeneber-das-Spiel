class_name TimeBubble
extends Node2D

# Zeitschläger-Fähigkeit "Zeitblase": eine ortsfeste Kuppel. Gegner darin
# laufen langsamer, gegnerische Kugeln darin fliegen nur mit einem Bruchteil
# ihres Tempos. Der Zeitschläger und sein Team bewegen sich normal.
#
# Außerdem liegt hier die gemeinsame Zeitlogik für Kugeln: bullet_time_scale()
# fragt Zeitblasen und einen laufenden Zeitstopp ab (siehe Player.ZEIT_STOP_*).
#
# Der Host simuliert die Wirkung. Clients bekommen Lage, Radius und Restzeit
# über den Snapshot (main.gd "ents", Art "tbubble") und zeichnen nur.

const GROUP: String = "time_bubble"
const FADE_OUT: float = 0.25
# Aktualisierung der Verlangsamung: so lange hält sie nach dem Verlassen nach.
const SLOW_REFRESH: float = 0.15

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var team_id: int = -1

var radius: float = 150.0
var duration: float = 4.0
var slow: float = 0.6
var bullet_scale: float = 0.25
# Evolutionen: Zerfall (Schaden pro Sekunde), Eigenzeit (eigenes Tempo +).
var decay_dps: float = 0.0
var haste_mult: float = 1.0
var arena_z: float = 0.0

var _age: float = 0.0
var _anim: float = 0.0
var _ended: bool = false
var _decay_tick: float = 0.0

# Zeitschläger, deren Zeitstopp gerade läuft. Statisch, damit Kugeln ohne
# Szenensuche nachfragen können; ungültige Einträge fallen von selbst heraus.
static var _stoppers: Array = []

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group(GROUP)
	add_to_group("round_effect")
	z_index = 4
	if not is_replica:
		net_id = NetEntity.next_id()

func remaining_time() -> float:
	return maxf(0.0, duration - _age)

func contains(pos: Vector2) -> bool:
	return pos.distance_squared_to(global_position) <= radius * radius

func _physics_process(delta: float) -> void:
	if is_replica or _ended:
		return
	_age += delta
	if _age >= duration or not is_instance_valid(owner_player):
		finish()
		return
	var tick_damage := false
	if decay_dps > 0.0:
		_decay_tick -= delta
		if _decay_tick <= 0.0:
			_decay_tick = 0.5
			tick_damage = true
	for p in owner_player._opponents_within(global_position, radius):
		p.apply_time_slow(1.0 - slow, SLOW_REFRESH)
		if tick_damage:
			owner_player._ability_hit(p, decay_dps * 0.5, Vector2.ZERO)
	if haste_mult > 1.0 and contains(owner_player.global_position):
		owner_player.apply_time_haste(haste_mult, SLOW_REFRESH)

func _process(delta: float) -> void:
	_anim += delta
	if is_replica:
		_age += delta
	queue_redraw()

func finish() -> void:
	if _ended:
		return
	_ended = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group(GROUP)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)

func is_active() -> bool:
	return not _ended

# --- Zeitlogik für Kugeln ---

# Tempo-Faktor einer Kugel: 0 = eingefroren (Zeitstopp), <1 = Zeitblase.
static func bullet_time_scale(bullet: Node2D) -> float:
	var shooter_team := -999
	var shooter = bullet.get("shooter")
	if is_instance_valid(shooter) and shooter is Player:
		shooter_team = shooter.team_id
	for i in range(_stoppers.size() - 1, -1, -1):
		var s = _stoppers[i]
		if not is_instance_valid(s) or not s.is_time_stopping():
			_stoppers.remove_at(i)
			continue
		if shooter_team != s.team_id:
			return 0.0
	if not bullet.is_inside_tree():
		return 1.0
	var scale_out := 1.0
	for node in bullet.get_tree().get_nodes_in_group(GROUP):
		var bubble := node as TimeBubble
		if bubble == null or bubble._ended or bubble.team_id == shooter_team:
			continue
		if bubble.contains(bullet.global_position):
			scale_out = minf(scale_out, bubble.bullet_scale)
	return scale_out

static func register_stopper(p: Player) -> void:
	if not _stoppers.has(p):
		_stoppers.append(p)

static func unregister_stopper(p: Player) -> void:
	_stoppers.erase(p)

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"k": "tbubble",
		"pos": global_position,
		"r": radius,
		"left": remaining_time(),
		"z": arena_z,
		"t": team_id,
	}

func apply_network_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	radius = float(data.get("r", radius))
	arena_z = float(data.get("z", arena_z))
	team_id = int(data.get("t", team_id))
	duration = _age + float(data.get("left", remaining_time()))

func remove_replica() -> void:
	finish()

# --- Darstellung ---

func _draw() -> void:
	var offset := ArenaMode.height_offset(arena_z) if ArenaMode.active else Vector2.ZERO
	var appear := clampf(_age / 0.18, 0.0, 1.0)
	var r := radius * (0.6 + 0.4 * appear)
	var gold := Color(1.0, 0.82, 0.38)
	var pulse := 0.5 + 0.5 * sin(_anim * 3.0)
	draw_circle(offset, r, Color(0.55, 0.75, 1.0, 0.07 + 0.03 * pulse))
	draw_arc(offset, r, 0.0, TAU, 64, Color(gold.r, gold.g, gold.b, 0.55), 2.0, true)
	draw_arc(offset, r * 0.93, 0.0, TAU, 64, Color(0.6, 0.8, 1.0, 0.18), 1.0, true)
	# Zifferblatt: zwölf Striche am Rand.
	for i in range(12):
		var dir := Vector2.from_angle(TAU * float(i) / 12.0)
		var inner := 0.86 if i % 3 == 0 else 0.91
		draw_line(offset + dir * r * inner, offset + dir * r * 0.98,
			Color(gold.r, gold.g, gold.b, 0.6), 2.0 if i % 3 == 0 else 1.2, true)
	# Zeiger: der große zeigt die Restzeit, der kleine kreist langsam.
	var left_ratio := clampf(remaining_time() / maxf(0.01, duration), 0.0, 1.0)
	var big := Vector2.from_angle(-PI * 0.5 + TAU * (1.0 - left_ratio))
	var small := Vector2.from_angle(-PI * 0.5 + _anim * 0.8)
	draw_line(offset, offset + big * r * 0.7, Color(gold.r, gold.g, gold.b, 0.45), 2.4, true)
	draw_line(offset, offset + small * r * 0.42, Color(gold.r, gold.g, gold.b, 0.4), 3.0, true)
	draw_circle(offset, 4.0, Color(gold.r, gold.g, gold.b, 0.7))
