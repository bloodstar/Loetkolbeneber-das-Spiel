class_name BloodOrb
extends Node2D

# Blutkugel der Vampire. Jeder dritte Treffer eines Vampirs (Angriff, nicht
# Fähigkeit) lässt beim Gegner eine Kugel fallen, der Dash des Vampirs
# ebenfalls. Alle Vampire können jede Kugel nutzen, egal wer sie erzeugt hat.
# Was beim Aufsammeln passiert, entscheidet der Held in
# Player.on_blood_orb_pickup(): der Fernkampf-Vampir heilt sich nur, wenn er
# verletzt ist; andere Vampire können eigene Regeln haben.
#
# Fähigkeiten verbrauchen Kugeln über take(): der Fernkampf-Vampir lässt sie
# explodieren (Fähigkeit) oder macht Fledermäuse daraus (Ulti).
#
# Der Host simuliert Fall, Anziehung und Aufsammeln. Clients bekommen Lage
# und Restzeit über den Snapshot (main.gd "ents") und zeichnen nur.

const GROUP: String = "blood_orb"
const RADIUS: float = 6.5
const LIFETIME: float = 14.0
# So lange nach dem Entstehen kann niemand die Kugel aufsammeln, damit der
# Vampir sie nicht schon beim Erzeugen (z. B. Dash) wieder einsammelt.
const PICKUP_DELAY: float = 0.45
const PICKUP_RADIUS: float = 24.0
# Vampire, die die Kugel nutzen können, ziehen sie aus dieser Nähe an
# (Standard; der Fernkampf-Vampir hat mehr, siehe
# Player.blood_orb_magnet_radius).
const MAGNET_RADIUS: float = 80.0
# Größter Anziehungsradius aller Vampire (für die Vorauswahl).
const MAX_MAGNET_RADIUS: float = 200.0
const MAGNET_SPEED: float = 320.0
const GRAVITY: float = 520.0
const MAX_FALL_SPEED: float = 420.0
# Mehr Kugeln gleichzeitig gibt es nicht; die älteste verschwindet.
const MAX_ACTIVE: int = 14
const BLINK_TIME: float = 2.0
# Fällt eine Kugel länger als so lange, ohne Boden zu finden (Abgrund),
# bleibt sie in der Luft schweben, statt aus der Karte zu fallen.
const MAX_FALL_TIME: float = 1.4

var net_id: int = 0
var is_replica: bool = false
var spawner: Player = null
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = LIFETIME
var arena_z: float = 0.0

var _age: float = 0.0
var _anim: float = 0.0
var _gone: bool = false
var _resting: bool = false
var _fall_time: float = 0.0
var _net_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group(GROUP)
	add_to_group("round_effect")
	z_index = 5
	_anim = randf() * TAU
	if not is_replica:
		net_id = NetEntity.next_id()
		_limit_active()
	_net_target = global_position

# Erzeugt eine Kugel an pos (nur Host bzw. offline). parent ist Main.
static func spawn(parent: Node, pos: Vector2, by: Player = null, z: float = 0.0) -> BloodOrb:
	if parent == null:
		return null
	var orb := BloodOrb.new()
	orb.spawner = by
	orb.arena_z = z
	if ArenaMode.active:
		orb.velocity = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 90.0)
	else:
		orb.velocity = Vector2(randf_range(-70.0, 70.0), randf_range(-190.0, -120.0))
	orb.position = pos
	parent.add_child(orb)
	orb.global_position = pos
	return orb

# Alle Kugeln, die noch frei liegen, optional nur in einem Umkreis.
static func free_orbs(tree: SceneTree, center: Vector2 = Vector2.INF, radius: float = INF) -> Array:
	var result: Array = []
	for node in tree.get_nodes_in_group(GROUP):
		var orb := node as BloodOrb
		if orb == null or not orb.is_free():
			continue
		if center != Vector2.INF and orb.global_position.distance_to(center) > radius:
			continue
		result.append(orb)
	return result

func is_free() -> bool:
	return not _gone and not is_replica and not is_queued_for_deletion()

func remaining_time() -> float:
	return maxf(0.0, lifetime - _age)

# Verbraucht die Kugel (Aufsammeln, Explosion, Fledermaus …) und gibt ihre
# Position zurück. Auf Clients verschwindet sie mit dem nächsten Snapshot.
func take() -> Vector2:
	var pos := global_position
	_vanish()
	return pos

func _limit_active() -> void:
	var orbs := free_orbs(get_tree())
	orbs.erase(self)
	if orbs.size() < MAX_ACTIVE:
		return
	orbs.sort_custom(func(a, b): return a._age > b._age)
	for i in range(orbs.size() - MAX_ACTIVE + 1):
		orbs[i]._vanish()

func _physics_process(delta: float) -> void:
	if is_replica or _gone:
		return
	_age += delta
	if _age >= lifetime:
		_vanish()
		return
	var puller := _magnet_target() if _age >= PICKUP_DELAY else null
	if puller != null:
		_resting = false
		var to := puller.global_position - global_position
		if to.length() <= PICKUP_RADIUS:
			if puller.on_blood_orb_pickup(self):
				_pickup_fx(puller)
				_vanish()
			return
		global_position += to.normalized() * minf(MAGNET_SPEED * delta, to.length())
		velocity = Vector2.ZERO
		return
	if _resting:
		return
	if ArenaMode.active:
		velocity = velocity.move_toward(Vector2.ZERO, 160.0 * delta)
		var next_a := global_position + velocity * delta
		if _hits_terrain(global_position, next_a):
			velocity = Vector2.ZERO
		else:
			global_position = next_a
		if velocity.length_squared() < 1.0:
			_resting = true
		return
	_fall_time += delta
	if _fall_time >= MAX_FALL_TIME:
		_resting = true
		velocity = Vector2.ZERO
		return
	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	velocity.x = move_toward(velocity.x, 0.0, 60.0 * delta)
	var next := global_position + velocity * delta
	var hit := _terrain_hit(global_position, next + Vector2(0.0, RADIUS))
	if not hit.is_empty():
		var normal: Vector2 = hit.get("normal", Vector2.UP)
		if normal.y < -0.5:
			# Liegt auf dem Boden und bleibt dort.
			global_position = (hit["position"] as Vector2) - Vector2(0.0, RADIUS)
			_resting = true
			velocity = Vector2.ZERO
			return
		velocity.x = 0.0
		next.x = global_position.x
	global_position = next

# Nächster Vampir in Reichweite, der die Kugel gerade nutzen kann.
func _magnet_target() -> Player:
	var best: Player = null
	var best_dist := MAX_MAGNET_RADIUS
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or p.is_replica or p.current_health <= 0.0 or p.is_dead:
			continue
		if not Global.is_vampire_hero(Global.get_player_hero_id(p.player_index)):
			continue
		var dist := p.global_position.distance_to(global_position)
		if dist > best_dist or dist > p.blood_orb_magnet_radius() or not p.wants_blood_orb():
			continue
		best = p
		best_dist = dist
	return best

func _terrain_hit(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query)

func _hits_terrain(from: Vector2, to: Vector2) -> bool:
	var mask := ArenaMode.point_band_mask(arena_z) if ArenaMode.active else 1
	var query := PhysicsRayQueryParameters2D.create(from, to, mask)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _pickup_fx(by: Player) -> void:
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(by.global_position,
		Color(0.9, 0.1, 0.18, 0.85), 0.4, 3.0, 0.2, 0.22), "heal", 0.15, -4.0))

func _vanish() -> void:
	if _gone:
		return
	_gone = true
	remove_from_group(NetEntity.GROUP)
	remove_from_group(GROUP)
	queue_free()

func _process(delta: float) -> void:
	_anim += delta
	if is_replica:
		_age += delta
		if global_position.distance_to(_net_target) > 200.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(18.0 * delta, 0.0, 1.0))
	queue_redraw()

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"k": "blood",
		"pos": global_position,
		"left": remaining_time(),
		"z": arena_z,
	}

func apply_network_state(data: Dictionary) -> void:
	_net_target = data.get("pos", _net_target)
	arena_z = float(data.get("z", arena_z))
	lifetime = _age + float(data.get("left", remaining_time()))

func remove_replica() -> void:
	_gone = true
	queue_free()

# --- Darstellung ---

func _draw() -> void:
	var offset := ArenaMode.height_offset(arena_z + 6.0) if ArenaMode.active else Vector2.ZERO
	var bob := Vector2(0.0, sin(_anim * 3.2) * 1.6) if _resting or is_replica else Vector2.ZERO
	var c := offset + bob
	var pulse := 0.5 + 0.5 * sin(_anim * 6.0)
	var alpha := 1.0
	var left := remaining_time()
	if left < BLINK_TIME:
		alpha = 0.45 + 0.55 * absf(sin(_anim * 9.0))
	# Schein, Tropfen, Glanzlicht.
	draw_circle(c, RADIUS + 5.0 + 1.5 * pulse, Color(0.9, 0.05, 0.12, 0.16 * alpha))
	draw_circle(c, RADIUS + 1.2, Color(0.25, 0.0, 0.03, 0.9 * alpha))
	draw_circle(c, RADIUS, Color(0.78, 0.04, 0.10, alpha))
	draw_circle(c + Vector2(0.8, 1.2), RADIUS * 0.55, Color(0.55, 0.0, 0.06, 0.8 * alpha))
	draw_circle(c + Vector2(-2.0, -2.2), 1.8, Color(1.0, 0.75, 0.75, 0.9 * alpha))
