class_name BlockMine
extends Node2D

# Mine aus der Karte "Minenleger": Blocken lässt sie fallen, sie bleibt auf dem
# Boden darunter liegen, wird nach ARM_DELAY scharf und zündet, sobald ein
# Gegner darüberläuft. Danach blinkt sie FUSE_TIME Sekunden und explodiert
# (Evolution "Sofortzünder": ohne Verzögerung).
# Der Host simuliert Fallen, Auslösen und Schaden. Clients bekommen Position und
# Zustand über den Snapshot (main.gd "mines") und zeigen nur die Optik.
# Gegner sehen die Mine erst, wenn sie blinkt.

enum State { ARMING, ARMED, TRIGGERED }

const ARM_DELAY: float = 2.0
const FUSE_TIME: float = 1.5
const FALL_GRAVITY: float = 980.0
const MAX_FALL_SPEED: float = 900.0
# Fällt die Mine so lange ins Leere (Abgrund), verschwindet sie.
const MAX_FALL_TIME: float = 6.0
const FLOOR_MASK: int = 1
const BODY_HALF_HEIGHT: float = 4.0
const BODY_RADIUS: float = 8.0
const KNOCKBACK: float = 420.0
# Abstand, in dem der Boden unter einer liegenden Mine erneut geprüft wird
# (zerstörbare Blöcke können wegbrechen).
const GROUND_RECHECK: float = 0.25
const ALLY_ALPHA: float = 0.8
# Lokal teilen sich alle einen Bildschirm: gegen menschliche Gegner bleibt die
# Mine nur schwach sichtbar, damit der Besitzer sie noch wiederfindet.
const SHARED_SCREEN_ALPHA: float = 0.18
const BLINK_INTERVAL: float = 0.14
# Effektkreis-Textur: Radius in Pixeln bei Skalierung 1.
const EFFECT_TEXTURE_RADIUS: float = 8.0

static var _next_net_id: int = 1

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0
var owner_team: int = -1
var damage: float = 50.0
var radius: float = 72.0
var instant: bool = false
var state: State = State.ARMING

var _age: float = 0.0
var _fuse: float = 0.0
var _fall_speed: float = 0.0
var _fall_time: float = 0.0
var _landed: bool = false
var _ground_timer: float = 0.0
var _carrier: Node2D = null
var _carrier_local: Vector2 = Vector2.ZERO
var _anim_time: float = 0.0
var _exploded: bool = false

func _ready() -> void:
	z_index = -1
	add_to_group("block_mine")
	add_to_group("round_effect")
	if not is_replica:
		net_id = _next_net_id
		_next_net_id += 1
	queue_redraw()

func setup(owner: Player, mine_damage: float, mine_radius: float, mine_instant: bool) -> void:
	owner_player = owner
	owner_index = owner.player_index
	owner_team = owner.team_id
	damage = mine_damage
	radius = mine_radius
	instant = mine_instant

func _physics_process(delta: float) -> void:
	if is_replica:
		return
	_age += delta
	match state:
		State.ARMING:
			if _age >= ARM_DELAY:
				state = State.ARMED
		State.ARMED:
			if _enemy_on_mine():
				_trigger()
				if _exploded:
					return
		State.TRIGGERED:
			_fuse -= delta
			if _fuse <= 0.0:
				_explode()
				return
	_update_fall(delta)

func _process(delta: float) -> void:
	_anim_time += delta
	queue_redraw()

# --- Fallen & Liegen (nur Host) ---

func _update_fall(delta: float) -> void:
	if _landed:
		if _carrier != null:
			if not is_instance_valid(_carrier) or _carrier.is_queued_for_deletion():
				_unland()
			else:
				global_position = _carrier.to_global(_carrier_local)
				return
		else:
			_ground_timer -= delta
			if _ground_timer <= 0.0:
				_ground_timer = GROUND_RECHECK
				if _floor_below(BODY_HALF_HEIGHT + 4.0).is_empty():
					_unland()
			return
	_fall_time += delta
	if _fall_time > MAX_FALL_TIME:
		queue_free()
		return
	_fall_speed = minf(_fall_speed + FALL_GRAVITY * delta, MAX_FALL_SPEED)
	var step := _fall_speed * delta
	var hit := _floor_below(step + BODY_HALF_HEIGHT)
	if hit.is_empty():
		global_position.y += step
		return
	_land(hit)

func _floor_below(distance: float) -> Dictionary:
	var space := get_world_2d().direct_space_state
	if space == null:
		return {}
	var from := global_position + Vector2(0.0, -2.0)
	var query := PhysicsRayQueryParameters2D.create(from, global_position + Vector2(0.0, distance), FLOOR_MASK)
	return space.intersect_ray(query)

func _land(hit: Dictionary) -> void:
	global_position = (hit["position"] as Vector2) - Vector2(0.0, BODY_HALF_HEIGHT)
	_landed = true
	_fall_speed = 0.0
	_fall_time = 0.0
	_ground_timer = GROUND_RECHECK
	_carrier = null
	# Auf Plattformen, Wippen und Kisten fährt die Mine mit.
	var collider = hit.get("collider")
	if collider is Node and not (collider is StaticBody2D):
		var obj := EffectZone._moving_object_of(collider as Node)
		if obj != null:
			var body := EffectZone._carrier_body_of(obj)
			if body != null:
				_carrier = body
				_carrier_local = body.to_local(global_position)

func _unland() -> void:
	_landed = false
	_carrier = null
	_fall_speed = 0.0

# --- Auslösen & Explosion (nur Host) ---

func _enemy_on_mine() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if not _is_enemy(p):
			continue
		var center: Vector2 = p.global_position
		var half := Vector2(16.0, 24.0)
		var cs = p.get("collision_shape")
		if cs is CollisionShape2D and is_instance_valid(cs) and cs.shape is RectangleShape2D:
			center = cs.global_position
			half = (cs.shape as RectangleShape2D).size * 0.5 * cs.global_scale.abs()
		var d: Vector2 = global_position - center
		if absf(d.x) <= half.x + BODY_RADIUS and absf(d.y) <= half.y + BODY_RADIUS:
			return true
	return false

func _is_enemy(p) -> bool:
	return p is Player and is_instance_valid(p) and p.current_health > 0.0 \
			and p.team_id != owner_team and p.visible

func _trigger() -> void:
	state = State.TRIGGERED
	_fuse = 0.0 if instant else FUSE_TIME
	if instant:
		_explode()
		return
	SoundManager.play_sound("warning", 0.1, 0.0)

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	# Optik und Ton auch für Clients (NetFx), auch bei sofort zündenden Minen,
	# die im Snapshot nie als ausgelöst auftauchen.
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(global_position,
		Color(1.0, 0.35, 0.2, 0.9), 1.0, radius / EFFECT_TEXTURE_RADIUS, 0.22, 0.3), "explosion", 0.2, 1.0))
	Seesaw.blast_all(get_tree(), global_position, radius, 1.0)
	var source: Player = owner_player if is_instance_valid(owner_player) else null
	for p in get_tree().get_nodes_in_group("player"):
		if not _is_enemy(p):
			continue
		if global_position.distance_to(p.global_position) > radius:
			continue
		var dir: Vector2 = (p.global_position - global_position).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		p.take_damage(damage, dir * KNOCKBACK, source)
	queue_free()

# Ohne Explosion entfernen (z. B. älteste Mine, wenn das Limit erreicht ist).
func discard() -> void:
	_exploded = true
	queue_free()

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"pos": global_position,
		"owner": owner_index,
		"team": owner_team,
		"st": int(state),
		"r": radius,
	}

func apply_network_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	owner_index = int(data.get("owner", owner_index))
	owner_team = int(data.get("team", owner_team))
	radius = float(data.get("r", radius))
	var new_state := int(data.get("st", int(state)))
	if new_state == State.TRIGGERED and state != State.TRIGGERED:
		SoundManager.play_sound("warning", 0.1, 0.0)
	state = new_state as State

# Client: Mine ist aus dem Snapshot verschwunden. Die Explosion kommt
# separat über NetFx vom Host.
func remove_replica() -> void:
	queue_free()

# --- Darstellung ---

func _viewer_alpha() -> float:
	if state == State.TRIGGERED:
		return 1.0
	if Global.network_mode:
		# Online sieht jeder Rechner nur die Minen des eigenen Teams.
		if Global.get_team_for_slot(Global.local_player_index) == owner_team:
			return ALLY_ALPHA
		return 0.0
	return SHARED_SCREEN_ALPHA if _human_opponent_present() else ALLY_ALPHA

func _human_opponent_present() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and is_instance_valid(p) and not p.is_bot and p.team_id != owner_team:
			return true
	return false

func _draw() -> void:
	var alpha := _viewer_alpha()
	if alpha <= 0.0:
		return
	var body := Color(0.22, 0.24, 0.27, alpha)
	var rim := Color(0.55, 0.58, 0.62, alpha)
	var light := Color(0.5, 0.5, 0.5, alpha)
	match state:
		State.ARMED:
			light = Color(1.0, 0.25, 0.2, alpha)
		State.TRIGGERED:
			var on := int(_anim_time / BLINK_INTERVAL) % 2 == 0
			light = Color(1.0, 0.95, 0.3, 1.0) if on else Color(1.0, 0.15, 0.1, 1.0)
			if on:
				draw_circle(Vector2(0.0, -2.0), BODY_RADIUS + 5.0, Color(1.0, 0.3, 0.15, 0.35))
	# Flache Kuppel auf einem Sockel.
	draw_rect(Rect2(-BODY_RADIUS, 0.0, BODY_RADIUS * 2.0, BODY_HALF_HEIGHT), body)
	var dome := PackedVector2Array()
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		dome.append(Vector2(cos(a) * BODY_RADIUS * 0.8, sin(a) * BODY_RADIUS * 0.6))
	draw_colored_polygon(dome, body)
	draw_polyline(dome, rim, 1.0)
	draw_circle(Vector2(0.0, -2.5), 2.0, light)
