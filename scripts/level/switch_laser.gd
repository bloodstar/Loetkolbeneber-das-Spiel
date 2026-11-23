class_name SwitchLaser
extends Node2D

## Laserschranke zwischen zwei Emittern, gesteuert über einen Schalter.
## invert = false: aus, Schalter an schaltet sie ein (erst 0,6 s Warnlinie,
## dann der Strahl). invert = true: Sperre ist an, Schalter schaltet sie ab.
## Der Strahl trifft Spieler, die ihn berühren (Schaden in kurzen Ticks).
## Schaden nur auf dem Host, Clients zeigen den Zustand aus dem Snapshot.

const WARN_TIME: float = 0.6
const HIT_RADIUS: float = 20.0
const TICK: float = 0.2
const TICK_DAMAGE: float = 14.0
const KNOCKBACK: float = 260.0

enum State { OFF, WARN, ON }

var net_id: int = 0
var object_type: String = "switch_laser"
var is_replica: bool = false
var network = null

## Endpunkte in Weltkoordinaten (der Knoten selbst liegt im Ursprung).
var point_a: Vector2 = Vector2.ZERO
var point_b: Vector2 = Vector2(200.0, 0.0)
var invert: bool = false
var channels: Array = [0]
var powered: bool = false
var damage_mult: float = 1.0

var state: int = State.OFF
var _warn_left: float = 0.0
var _tick_left: float = 0.0
var _hit_cooldown: Dictionary = {}
var _color: Color = Color.WHITE

func _ready() -> void:
	add_to_group("switch_laser")
	z_index = 4
	_color = SwitchNetwork.channel_color(int(channels[0]) if not channels.is_empty() else 0)
	state = State.ON if invert else State.OFF

func set_powered(on: bool) -> void:
	powered = on
	if is_replica:
		return
	var active := on != invert
	if active and state == State.OFF:
		state = State.WARN
		_warn_left = WARN_TIME
		_fx("warn")
	elif not active and state != State.OFF:
		state = State.OFF
		_fx("off")

func _fx(method: String) -> void:
	play_network_fx(method)
	NetFx.send("mobj", NetFx.mobj_args(self, method))

func play_network_fx(method: String) -> void:
	match method:
		"warn":
			SoundManager.play_sound("laser_small", 0.1, -4.0)
		"on":
			SoundManager.play_sound("laser_large", 0.1, -8.0)
		"off":
			SoundManager.play_sound("click", 0.1, -6.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	queue_redraw()
	if is_replica:
		return
	if state == State.WARN:
		_warn_left -= delta
		if _warn_left <= 0.0:
			state = State.ON
			_tick_left = 0.0
			_fx("on")
	elif state == State.ON:
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left = TICK
			_damage_players()

func _damage_players() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Player) or not is_instance_valid(p) or p.current_health <= 0.0:
			continue
		if distance_to(p.global_position) > HIT_RADIUS + 10.0 * p.scale.y:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(p.global_position, point_a, point_b)
		var push: Vector2 = p.global_position - closest
		if push.length() < 1.0:
			push = (point_b - point_a).orthogonal()
		p.take_damage(TICK_DAMAGE * damage_mult, push.normalized() * KNOCKBACK, null)

func distance_to(pos: Vector2) -> float:
	return pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, point_a, point_b))

## Für Bots: Warnlinie oder Strahl aktiv.
func is_dangerous() -> bool:
	return state != State.OFF

# --- Optik ---------------------------------------------------------------------

func _draw() -> void:
	var dir := (point_b - point_a).normalized()
	for end in [point_a, point_b]:
		var out: Vector2 = dir if end == point_a else -dir
		var side := out.orthogonal()
		var box := PackedVector2Array([
			end - out * 10.0 + side * 9.0, end + out * 4.0 + side * 7.0,
			end + out * 4.0 - side * 7.0, end - out * 10.0 - side * 9.0,
		])
		draw_colored_polygon(box, Color(0.14, 0.15, 0.19, 1.0))
		draw_polyline(box + PackedVector2Array([box[0]]), Color(_color.r, _color.g, _color.b, 0.9), 2.0)
		var lamp := Color(1.0, 0.25, 0.2) if state != State.OFF else _color.darkened(0.4)
		draw_circle(end + out * 2.0, 3.5, lamp)
	var t := float(Time.get_ticks_msec()) / 1000.0
	match state:
		State.WARN:
			if fmod(t, 0.16) < 0.1:
				draw_line(point_a, point_b, Color(1.0, 0.25, 0.2, 0.7), 2.0)
		State.ON:
			var wobble := 1.0 + 0.15 * sin(t * 40.0)
			draw_line(point_a, point_b, Color(1.0, 0.15, 0.1, 0.35), 22.0 * wobble)
			draw_line(point_a, point_b, Color(_color.r, _color.g, _color.b, 0.6), 11.0 * wobble)
			draw_line(point_a, point_b, Color(1.0, 0.95, 0.9, 1.0), 4.0)

# --- Netzwerk ------------------------------------------------------------------

func get_network_state() -> Dictionary:
	return {"id": net_id, "type": object_type, "s": state}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	state = int(data.get("s", state))

# --- Bots ------------------------------------------------------------------------

func bot_value(bot: Node2D, enemy: Node2D) -> float:
	var will_active := not invert
	if will_active == (state != State.OFF):
		return 0.0
	if will_active:
		var value := 0.0
		if distance_to(enemy.global_position) < 55.0:
			value += 3.0
		if distance_to(bot.global_position) < 80.0:
			value -= 4.0
		return value
	# Sperre abschalten lohnt sich, wenn sie zwischen Bot und Gegner liegt.
	var cross = Geometry2D.segment_intersects_segment(bot.global_position, enemy.global_position, point_a, point_b)
	return 1.0 if cross != null else 0.0
