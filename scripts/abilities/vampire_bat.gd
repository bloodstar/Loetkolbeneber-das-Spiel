class_name VampireBat
extends CharacterBody2D

# Fledermaus aus der Vampir-Ulti "Fledermausschwarm". Jede Blutkugel in der
# Nähe des Vampirs wird zu einer Fledermaus. Sie fliegt frei (auch über
# Gelände) zum nächsten Gegner und beißt ihn in festen Abständen. Mit
# wenig Leben kann man sie abschießen oder wegschlagen.
#
# Sie liegt auf der Turm-Ebene und nutzt dieselbe Treffer-Schnittstelle wie
# Türme und der Phantom-Köder (hit_tower / take_tower_damage).
#
# Der Host simuliert sie, Clients bekommen sie über den Snapshot ("ents").

const GROUP: String = "vampire_bat"
const HOVER_HEIGHT: float = 14.0
const BITE_RANGE: float = 22.0
const BAR_WIDTH: float = 16.0
# Abstand der Schwarm-Plätze vom Ziel.
const SWARM_SPREAD: float = 16.0

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0
var team_id: int = -1

var max_hp: float = 50.0
var hp: float = 50.0
var duration: float = 7.0
var speed: float = 270.0
var bite_damage: float = 8.0
var bite_interval: float = 0.7
# Evolution "Fledermauskönig": Anteil des Bissschadens, der den Vampir heilt.
var heal_share: float = 0.0
var arena_z: float = 0.0
# Platz im Schwarm (Winkel um das Ziel), damit mehrere Fledermäuse nicht
# als ein Klumpen fliegen.
var slot_angle: float = 0.0

var _age: float = 0.0
var _anim: float = 0.0
var _bite_timer: float = 0.0
var _gone: bool = false
var _hit_flash: float = 0.0
var _face: float = 1.0
var _wobble: float = 0.0
var _net_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group(GROUP)
	add_to_group("round_effect")
	z_index = 7
	_anim = randf() * TAU
	_wobble = randf() * TAU
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position
	collision_layer = 0 if is_replica else Companion.TOWER_COLLISION_LAYER
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 9.0
	col.shape = shape
	add_child(col)
	if ArenaMode.active:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

func is_active() -> bool:
	return not _gone and not is_queued_for_deletion()

func _physics_process(delta: float) -> void:
	if is_replica or _gone:
		return
	_age += delta
	if _age >= duration or not is_instance_valid(owner_player):
		pop()
		return
	_bite_timer = maxf(0.0, _bite_timer - delta)
	var target := _find_target()
	var goal: Vector2
	if target != null:
		goal = target.global_position + Vector2(0.0, -HOVER_HEIGHT if not ArenaMode.active else 0.0)
		# Um das Ziel verteilt: jede Fledermaus hat ihren eigenen Platz.
		goal += Vector2.from_angle(slot_angle + _age * 1.6) * SWARM_SPREAD
	else:
		# Ohne Gegner kreist sie um den Vampir.
		goal = owner_player.global_position + Vector2.from_angle(_age * 2.5 + slot_angle) * 50.0 + Vector2(0.0, -30.0)
	# Leichtes Flattern, damit ein Schwarm nicht als Klumpen fliegt.
	goal += Vector2(sin(_age * 5.0 + _wobble) * 10.0, cos(_age * 7.0 + _wobble) * 6.0)
	var to := goal - global_position
	var desired := to.normalized() * speed if to.length() > 4.0 else Vector2.ZERO
	velocity = velocity.lerp(desired, clampf(6.0 * delta, 0.0, 1.0))
	global_position += velocity * delta
	if absf(velocity.x) > 8.0:
		_face = signf(velocity.x)
	if target != null and _bite_timer <= 0.0 and global_position.distance_to(target.global_position) <= BITE_RANGE + SWARM_SPREAD + 8.0:
		_bite(target)

func _find_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for p in owner_player._opponents_within(global_position, 1400.0):
		if p.is_stealthed():
			continue
		var dist: float = global_position.distance_to(p.global_position)
		if dist < best_dist:
			best = p
			best_dist = dist
	return best

func _bite(target: Player) -> void:
	_bite_timer = bite_interval
	var dir := (target.global_position - global_position).normalized()
	owner_player._ability_hit(target, bite_damage, dir * 80.0)
	if heal_share > 0.0 and owner_player.current_health > 0.0:
		owner_player.heal(bite_damage * heal_share)
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(target.global_position,
		Color(0.85, 0.05, 0.15, 0.8), 0.3, 1.6, 0.15, 0.18), "hit", 0.25, -6.0))
	# Nach dem Biss kurz zurückflattern.
	velocity = -dir * speed * 0.6

# --- Treffer (Schnittstelle wie Companion-Türme) ---

func is_friendly_attacker(attacker) -> bool:
	if attacker == null or not is_instance_valid(attacker):
		return false
	if attacker == owner_player:
		return true
	return attacker is Player and (attacker as Player).team_id == team_id

func hit_tower(bullet: Bullet) -> bool:
	if is_replica or bullet == null or _gone:
		return false
	if is_friendly_attacker(bullet.shooter):
		return false
	take_tower_damage(bullet.damage, bullet.shooter)
	NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.18, 1.0]})
	return true

func take_tower_damage(amount: float, attacker = null) -> void:
	if is_replica or _gone or amount <= 0.0:
		return
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	if is_friendly_attacker(attacker):
		return
	hp = maxf(0.0, hp - amount)
	_hit_flash = 0.12
	if hp <= 0.0:
		pop()

func pop() -> void:
	if _gone:
		return
	_gone = true
	if not is_replica and get_parent() != null:
		NetFx.emit(get_parent(), "ring", NetFx.ring_args(global_position,
			Color(0.3, 0.05, 0.25, 0.8), 0.4, 2.4, 0.2, 0.2))
	queue_free()

func _process(delta: float) -> void:
	_anim += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if is_replica:
		_age += delta
		var prev := global_position
		if global_position.distance_to(_net_target) > 250.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(18.0 * delta, 0.0, 1.0))
		if absf(global_position.x - prev.x) > 0.3:
			_face = signf(global_position.x - prev.x)
	queue_redraw()

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"k": "bat",
		"pos": global_position,
		"o": owner_index,
		"hp": clampf(hp / maxf(1.0, max_hp), 0.0, 1.0),
		"z": arena_z,
	}

func apply_network_state(data: Dictionary) -> void:
	owner_index = int(data.get("o", owner_index))
	_net_target = data.get("pos", _net_target)
	var ratio := float(data.get("hp", 1.0))
	if ratio < hp / maxf(1.0, max_hp) - 0.01:
		_hit_flash = 0.12
	hp = ratio * max_hp
	arena_z = float(data.get("z", arena_z))

func remove_replica() -> void:
	_gone = true
	queue_free()

# --- Darstellung ---

func _draw() -> void:
	var c := ArenaMode.height_offset(arena_z + 30.0) if ArenaMode.active else Vector2.ZERO
	var flap := sin(_anim * 18.0)
	var body := Color(0.16, 0.08, 0.18, 1.0)
	var wing := Color(0.26, 0.10, 0.26, 1.0)
	var outline := Color(0.05, 0.0, 0.06, 1.0)
	if _hit_flash > 0.0:
		body = Color(1.0, 0.45, 0.45)
		wing = Color(1.0, 0.55, 0.55)
	# Flügel: zwei gezackte Dreiecke, die auf und ab schlagen.
	for side in [-1.0, 1.0]:
		var tip := c + Vector2(side * 13.0, -4.0 - flap * 6.0)
		var mid := c + Vector2(side * 8.0, 2.0 - flap * 2.0)
		var pts := PackedVector2Array([
			c + Vector2(side * 2.5, -2.0), tip, c + Vector2(side * 11.0, 3.0 - flap * 3.0),
			mid, c + Vector2(side * 5.0, 4.0), c + Vector2(side * 2.5, 2.5),
		])
		draw_colored_polygon(pts, wing)
		pts.append(pts[0])
		draw_polyline(pts, outline, 1.0, true)
	# Körper, Ohren, rote Augen.
	draw_circle(c, 4.6, outline)
	draw_circle(c, 3.8, body)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(side * 1.2, -3.0), c + Vector2(side * 3.4, -7.0), c + Vector2(side * 3.6, -2.4),
		]), body)
	draw_circle(c + Vector2(_face * 1.2 - 1.2, -0.6), 0.9, Color(1.0, 0.15, 0.15))
	draw_circle(c + Vector2(_face * 1.2 + 1.2, -0.6), 0.9, Color(1.0, 0.15, 0.15))
	# Kleiner Lebensbalken, sobald sie Schaden hat.
	if hp < max_hp:
		var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
		var bar := Rect2(c.x - BAR_WIDTH * 0.5, c.y + 9.0, BAR_WIDTH, 2.0)
		draw_rect(bar.grow(0.6), Color(0.02, 0.02, 0.04, 0.7), true)
		draw_rect(Rect2(bar.position, Vector2(BAR_WIDTH * ratio, 2.0)), Color(0.9, 0.2, 0.25, 0.95), true)
