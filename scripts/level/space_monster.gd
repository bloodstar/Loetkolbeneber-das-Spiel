class_name SpaceMonster
extends CharacterBody2D

## Weltraumqualle für Weltraum-Maps. Treibt langsam auf den nächsten Spieler
## zu, lädt alle paar Sekunden sichtbar auf (wird rot und zittert) und
## schießt dann auf ihn zu. Berührung macht Schaden und stößt weg. Schüsse,
## Nahkampf und Explosionen verletzen sie, beim Tod lässt sie mit
## POWERUP_CHANCE ein Powerup fallen. Host simuliert, Clients folgen per
## Snapshot (Typ "space_monster").

signal monster_died(world_position: Vector2)

enum State { DRIFT, WINDUP, LUNGE }

const MAX_HEALTH: float = 90.0
const RADIUS: float = 24.0
const DRIFT_SPEED: float = 70.0
const DRIFT_ACCEL: float = 90.0
const LUNGE_SPEED: float = 430.0
const LUNGE_TIME: float = 0.65
const WINDUP_TIME: float = 0.75
const LUNGE_RANGE: float = 540.0
const LUNGE_INTERVAL_MIN: float = 3.0
const LUNGE_INTERVAL_MAX: float = 4.8
const CONTACT_DAMAGE: float = 13.0
const LUNGE_DAMAGE: float = 22.0
const CONTACT_KNOCKBACK: float = 420.0
const CONTACT_COOLDOWN: float = 0.9
const POWERUP_CHANCE: float = 0.6
const BULLET_PUSH: float = 110.0

const BODY_COLOR: Color = Color(0.85, 0.35, 0.95)
const GLOW_COLOR: Color = Color(0.40, 0.95, 1.0)
const ANGRY_COLOR: Color = Color(1.0, 0.30, 0.30)

var net_id: int = 0
var object_type: String = "space_monster"
var is_replica: bool = false
var health: float = MAX_HEALTH
var hazard_radius: float = RADIUS
var state: int = State.DRIFT

var _state_time: float = 0.0
var _next_lunge: float = 3.5
var _lunge_dir: Vector2 = Vector2.RIGHT
var _target: Node2D = null
var _hit_cooldowns: Dictionary = {}
var _dead: bool = false
var _time: float = 0.0
var _phase: float = 0.0
var _net_pos: Vector2 = Vector2.ZERO
var _net_seen: bool = false

func _ready() -> void:
	add_to_group("space_monster")
	add_to_group("space_hazard")
	_phase = randf() * TAU
	_next_lunge = randf_range(LUNGE_INTERVAL_MIN, LUNGE_INTERVAL_MAX)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS * 0.85
	col.shape = shape
	add_child(col)
	z_index = 2
	set_replica(is_replica)

func set_replica(replica: bool) -> void:
	is_replica = replica
	# Schüsse treffen die Welt-Ebene 1; die Qualle selbst prallt nur an
	# Wänden und Asteroiden ab (Spieler stoßen sie nicht).
	collision_layer = 0 if replica else 1
	collision_mask = 0 if replica else 1

func _physics_process(delta: float) -> void:
	_time += delta
	if is_replica or _dead:
		return
	_state_time += delta
	for key in _hit_cooldowns.keys():
		_hit_cooldowns[key] = float(_hit_cooldowns[key]) - delta
		if float(_hit_cooldowns[key]) <= 0.0:
			_hit_cooldowns.erase(key)
	_target = _nearest_player()
	match state:
		State.DRIFT:
			var want := Vector2.ZERO
			if _target != null:
				want = (_target.global_position - global_position).normalized() * DRIFT_SPEED
			velocity = velocity.move_toward(want, DRIFT_ACCEL * delta)
			_next_lunge -= delta
			if _next_lunge <= 0.0 and _target != null \
					and global_position.distance_to(_target.global_position) < LUNGE_RANGE:
				_set_state(State.WINDUP)
		State.WINDUP:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if _target != null:
				_lunge_dir = (_target.global_position - global_position).normalized()
			if _state_time >= WINDUP_TIME:
				velocity = _lunge_dir * LUNGE_SPEED
				_set_state(State.LUNGE)
				SoundManager.play_sound("dash", 0.15, -4.0)
		State.LUNGE:
			if _state_time >= LUNGE_TIME:
				_next_lunge = randf_range(LUNGE_INTERVAL_MIN, LUNGE_INTERVAL_MAX)
				_set_state(State.DRIFT)
	var col := move_and_collide(velocity * delta)
	if col != null:
		velocity = velocity.bounce(col.get_normal()) * 0.7
		var other := col.get_collider()
		if other is RigidBody2D:
			(other as RigidBody2D).apply_central_impulse(-col.get_normal() * 60.0)
	_check_contacts()
	_keep_in_map()

func _set_state(s: int) -> void:
	state = s
	_state_time = 0.0

func _nearest_player() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p) or not p.visible or p.is_dead or p.current_health <= 0.0:
			continue
		if p.is_invisible():
			continue
		var d := global_position.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

func _check_contacts() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p) or not p.visible or p.is_dead or p.current_health <= 0.0:
			continue
		if p.is_invulnerable:
			continue
		var offset := p.global_position - global_position
		if offset.length() > RADIUS + 20.0:
			continue
		var key := p.get_instance_id()
		if _hit_cooldowns.has(key):
			continue
		_hit_cooldowns[key] = CONTACT_COOLDOWN
		var dir := offset.normalized() if offset.length() > 0.1 else Vector2.UP
		var dmg := LUNGE_DAMAGE if state == State.LUNGE else CONTACT_DAMAGE
		p.take_damage(dmg, dir * CONTACT_KNOCKBACK)
		SoundManager.play_sound("hit", 0.25, 0.0)
		if state == State.LUNGE:
			velocity = -dir * 120.0
			_next_lunge = randf_range(LUNGE_INTERVAL_MIN, LUNGE_INTERVAL_MAX)
			_set_state(State.DRIFT)

func _keep_in_map() -> void:
	var size := Vector2(float(LevelGenerator.map_w), float(LevelGenerator.map_h)) * LevelGenerator.TILE_SIZE
	var p := global_position
	if p.x < RADIUS and velocity.x < 0.0 or p.x > size.x - RADIUS and velocity.x > 0.0:
		velocity.x = -velocity.x
	if p.y < RADIUS and velocity.y < 0.0 or p.y > size.y - RADIUS and velocity.y > 0.0:
		velocity.y = -velocity.y

func hit_crate(projectile: Node2D = null) -> void:
	if is_replica or _dead:
		return
	var amount := 20.0
	if projectile != null:
		var dmg = projectile.get("damage")
		if dmg is float or dmg is int:
			amount = maxf(1.0, float(dmg))
		var vel = projectile.get("velocity")
		if vel is Vector2 and (vel as Vector2).length_squared() > 1.0:
			velocity += (vel as Vector2).normalized() * BULLET_PUSH
	_take_hit(amount)

func apply_blast(blast_position: Vector2, radius: float, force: float = 520.0, _attacker: Node = null) -> void:
	if is_replica or _dead:
		return
	var distance := blast_position.distance_to(global_position)
	if distance > radius + RADIUS:
		return
	var falloff := clampf(1.0 - distance / maxf(1.0, radius + RADIUS), 0.15, 1.0)
	var direction := (global_position - blast_position).normalized()
	velocity += direction * force * falloff * 0.5
	_take_hit(35.0 * falloff)

func _take_hit(amount: float) -> void:
	health -= amount
	_flash()
	SoundManager.play_sound("hit", 0.2, -3.0)
	NetFx.send("mobj", NetFx.mobj_args(self, "hit"))
	if health <= 0.0:
		_die()

func play_network_fx(_method: String) -> void:
	_flash()
	SoundManager.play_sound("hit", 0.2, -3.0)

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(2.0, 1.6, 1.6), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.15)

func _die() -> void:
	if _dead:
		return
	_dead = true
	_spawn_burst(global_position)
	SoundManager.play_sound("explosion", 0.2, -4.0)
	monster_died.emit(global_position)
	queue_free()

func _spawn_burst(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	NetFx.play(parent, "ring", NetFx.ring_args(at, Color(BODY_COLOR.r, BODY_COLOR.g, BODY_COLOR.b, 0.8), 0.3, 2.2, 0.25, 0.3, 6, true))
	NetFx.play(parent, "ring", NetFx.ring_args(at, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, 0.6), 0.2, 1.4, 0.2, 0.25, 6, true))

func spawn_remote_explosion() -> void:
	if not _dead:
		_dead = true
		_spawn_burst(global_position)
		SoundManager.play_sound("explosion", 0.2, -4.0)
	queue_free()

func _process(delta: float) -> void:
	if is_replica and _net_seen:
		global_position = global_position.lerp(_net_pos, clampf(delta * 14.0, 0.0, 1.0))
		if is_replica:
			_time += delta
	queue_redraw()

func _draw() -> void:
	var angry := 0.0
	var shake := Vector2.ZERO
	if state == State.WINDUP:
		angry = 1.0
		shake = Vector2(sin(_time * 60.0), cos(_time * 53.0)) * 2.5
	elif state == State.LUNGE:
		angry = 0.7
	var body := BODY_COLOR.lerp(ANGRY_COLOR, angry)
	var glow := GLOW_COLOR.lerp(ANGRY_COLOR, angry)
	var pulse := 0.85 + 0.15 * sin(_time * 4.0 + _phase)
	var r := RADIUS * pulse
	var c := shake
	draw_circle(c, r * 1.6, Color(glow.r, glow.g, glow.b, 0.08))
	# Tentakel.
	for i in range(5):
		var x := c.x + (float(i) - 2.0) * r * 0.38
		var pts := PackedVector2Array()
		for k in range(7):
			var t := float(k) / 6.0
			var y := c.y + r * 0.15 + t * r * 1.5
			pts.append(Vector2(x + sin(_time * 5.0 + _phase + float(i) * 1.3 + t * 4.0) * 5.0 * t, y))
		draw_polyline(pts, Color(body.r, body.g, body.b, 0.75), 3.0 - float(i % 2), true)
	# Schirm (Halbkugel).
	var dome := PackedVector2Array()
	for k in range(17):
		var a := PI + PI * float(k) / 16.0
		dome.append(c + Vector2(cos(a) * r, sin(a) * r * 0.95))
	dome.append(c + Vector2(r, r * 0.25))
	dome.append(c + Vector2(-r, r * 0.25))
	draw_colored_polygon(dome, Color(body.r, body.g, body.b, 0.85))
	draw_circle(c + Vector2(-r * 0.3, -r * 0.45), r * 0.2, Color(1, 1, 1, 0.35))
	# Augen.
	var eye := Color(1.0, 1.0, 0.9) if angry < 0.5 else Color(1.0, 0.9, 0.3)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.1), 4.0, eye)
	draw_circle(c + Vector2(r * 0.3, -r * 0.1), 4.0, eye)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.08), 2.0, Color(0.1, 0.05, 0.15))
	draw_circle(c + Vector2(r * 0.3, -r * 0.08), 2.0, Color(0.1, 0.05, 0.15))
	# Lebensbalken, sobald verletzt.
	if health < MAX_HEALTH:
		var w := 40.0
		var frac := clampf(health / MAX_HEALTH, 0.0, 1.0)
		draw_rect(Rect2(c.x - w * 0.5, c.y - r - 12.0, w, 4.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(c.x - w * 0.5, c.y - r - 12.0, w * frac, 4.0), Color(0.5, 1.0, 0.5, 0.9))

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"st": state,
		"hp": health,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	_net_pos = data.get("pos", global_position)
	state = int(data.get("st", state))
	health = float(data.get("hp", health))
	if not _net_seen:
		_net_seen = true
		global_position = _net_pos
