class_name HotPotatoDevil
extends CharacterBody2D

# Modifier "Heiße Kartoffel": Ein kleines fliegendes Teufelschwein verfolgt
# einen Spieler und schießt auf ihn. Es fliegt durch Wände und Spieler hindurch
# (keine Kollision), nur Projektile, Explosionen und Nahkampf treffen es.
# Treffer meldet es per Signal; wer das neue Ziel wird, entscheidet der
# LevelModifierManager. Auf Clients folgt es nur den Host-Snapshots.

signal hit_by(attacker: Player)

# Gleiche Ebene wie Türme: Kugeln (Maske 19), Explosionen und Nahkampf
# treffen sie, Spieler (Maske 7) laufen hindurch.
const HIT_LAYER: int = 16
const HIT_RADIUS: float = 15.0
const BULLET_SCENE: PackedScene = preload("res://scenes/player/bullet.tscn")

# Bewegung: schwebt schräg über dem Ziel und wechselt ab und zu die Seite.
const CHASE_SPEED: float = 175.0        # px/s (Laufen: 300, also abschüttelbar)
const ANGRY_SPEED_MULT: float = 1.5
const STEER: float = 3.0
const HOVER_OFFSET: Vector2 = Vector2(130.0, -115.0)
const SIDE_SWITCH_MIN: float = 2.5
const SIDE_SWITCH_MAX: float = 4.5

# Schüsse: gerade Feuerbälle ohne Fall, nur mit Sichtlinie.
const FIRE_INTERVAL: float = 1.2
const ANGRY_FIRE_INTERVAL: float = 0.5
const FIRE_RANGE: float = 640.0
const SHOT_DAMAGE: float = 8.0
const SHOT_SPEED: float = 470.0
const SHOT_LIFETIME: float = 2.2
const SHOT_COLOR: Color = Color(1.0, 0.35, 0.08)
const START_DELAY: float = 2.0

const BODY_COLOR: Color = Color(0.82, 0.1, 0.12)
const ANGRY_COLOR: Color = Color(1.0, 0.32, 0.05)
const WING_COLOR: Color = Color(0.22, 0.04, 0.07)
const HORN_COLOR: Color = Color(0.95, 0.88, 0.75)

var target: Player = null
var angry_time: float = 0.0
var angry_duration: float = 5.0

var is_replica: bool = false
var _fire_timer: float = START_DELAY
var _side: float = 1.0
var _side_timer: float = SIDE_SWITCH_MIN
var _anim: float = 0.0
var _facing: float = 1.0
var _hit_flash: float = 0.0
var _bounds: Rect2 = Rect2(0, 0, 1280, 720)

# Netzwerk-Client: weich zur zuletzt gemeldeten Host-Position gleiten.
var _net_target: Vector2 = Vector2.INF
var _net_age: float = 0.0
const NET_EXTRAPOLATE_MAX: float = 0.25

func _ready() -> void:
	add_to_group("hot_potato_devil")
	z_index = 9
	collision_layer = 0 if is_replica else HIT_LAYER
	collision_mask = 0
	if is_replica:
		return
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	col.shape = circle
	add_child(col)

func setup_bounds(rect: Rect2) -> void:
	_bounds = rect

func is_angry() -> bool:
	return angry_time > 0.0

func get_target_slot() -> int:
	return target.player_index if is_instance_valid(target) else 0

## Nach einem Zielwechsel kurz Luft lassen; wütend schießt er schneller los.
func on_target_changed(angry: bool, duration: float) -> void:
	angry_duration = duration
	angry_time = duration if angry else 0.0
	_fire_timer = 0.35 if angry else maxf(_fire_timer, 0.9)

func get_network_state() -> Dictionary:
	return {
		"pos": global_position,
		"vel": velocity,
		"t": get_target_slot(),
		"ang": angry_time,
		"f": _facing,
		"hf": _hit_flash,
	}

func apply_network_state(data: Dictionary) -> void:
	var pos: Vector2 = data.get("pos", global_position)
	if _net_target == Vector2.INF or pos.distance_to(global_position) > 200.0:
		global_position = pos
	_net_target = pos
	_net_age = 0.0
	velocity = data.get("vel", velocity)
	angry_time = float(data.get("ang", 0.0))
	_facing = float(data.get("f", _facing))
	_hit_flash = maxf(_hit_flash, float(data.get("hf", 0.0)))

func _physics_process(delta: float) -> void:
	_anim += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	angry_time = maxf(0.0, angry_time - delta)
	if is_replica:
		if _net_target != Vector2.INF:
			_net_age += delta
			if _net_age <= NET_EXTRAPOLATE_MAX:
				_net_target += velocity * delta
			global_position = global_position.lerp(_net_target, minf(1.0, delta * 12.0))
		queue_redraw()
		return

	if not _target_alive():
		# Ohne Ziel langsam ausschweben.
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, delta * 2.0))
		global_position += velocity * delta
		queue_redraw()
		return

	_side_timer -= delta
	if _side_timer <= 0.0:
		_side_timer = randf_range(SIDE_SWITCH_MIN, SIDE_SWITCH_MAX)
		_side = -_side
	var goal := _clamp_to_bounds(target.global_position + Vector2(HOVER_OFFSET.x * _side, HOVER_OFFSET.y))
	var speed := CHASE_SPEED * (ANGRY_SPEED_MULT if is_angry() else 1.0)
	var to_goal := goal - global_position
	var desired := Vector2.ZERO
	if to_goal.length() > 1.0:
		desired = to_goal.normalized() * minf(speed, to_goal.length() * 3.0)
	velocity = velocity.lerp(desired, clampf(STEER * delta, 0.0, 1.0))
	global_position = _clamp_to_bounds(global_position + velocity * delta)
	var dx := target.global_position.x - global_position.x
	if absf(dx) > 4.0:
		_facing = signf(dx)

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		if _try_fire():
			_fire_timer = ANGRY_FIRE_INTERVAL if is_angry() else FIRE_INTERVAL
		else:
			_fire_timer = 0.2
	queue_redraw()

func _target_alive() -> bool:
	return is_instance_valid(target) and not target.is_dead and target.current_health > 0.0

func _clamp_to_bounds(p: Vector2) -> Vector2:
	return Vector2(
		clampf(p.x, _bounds.position.x, _bounds.end.x),
		clampf(p.y, _bounds.position.y, _bounds.end.y)
	)

func _try_fire() -> bool:
	var aim_point := target.global_position
	var dist := global_position.distance_to(aim_point)
	if dist > FIRE_RANGE:
		return false
	var space := get_world_2d().direct_space_state
	# Steckt der Teufel gerade in einer Wand, schießt er nicht.
	var point := PhysicsPointQueryParameters2D.new()
	point.position = global_position
	point.collision_mask = 1
	if not space.intersect_point(point, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters2D.create(global_position, aim_point, 1)
	if not space.intersect_ray(ray).is_empty():
		return false
	# Leicht vorhalten, damit Stillstehen nicht die einzige Gefahr ist.
	aim_point += target.velocity * (dist / SHOT_SPEED) * 0.5
	var dir := (aim_point - global_position).normalized()
	if dir == Vector2.ZERO:
		return false
	var bullet := BULLET_SCENE.instantiate() as Bullet
	bullet.shooter = self
	bullet.damage = SHOT_DAMAGE
	bullet.velocity = dir * SHOT_SPEED
	bullet.projectile_gravity_mult = 0.0
	bullet.bounces_left = 0
	bullet.explosion_radius = 0.0
	bullet.max_lifetime = SHOT_LIFETIME
	bullet.rotation = dir.angle()
	bullet.modulate = SHOT_COLOR
	get_parent().add_child(bullet)
	bullet.global_position = global_position + dir * (HIT_RADIUS + 4.0)
	NetFx.emit(get_parent(), "sound", {"snd": ["shoot", 0.25, -4.0]})
	return true

# --- Treffer (nur Host) ---

# Direkter Projektiltreffer. true: Kugel ist verbraucht.
func hit_tower(bullet: Bullet) -> bool:
	if is_replica or bullet == null:
		return false
	if bullet.shooter == self:
		return false
	velocity += bullet.velocity * 0.15
	_register_hit(bullet.shooter)
	return true

# Explosionen und Nahkampf (gleiche Schnittstelle wie Türme).
func take_tower_damage(_amount: float, attacker = null) -> void:
	if is_replica:
		return
	_register_hit(attacker)

func _register_hit(attacker) -> void:
	_hit_flash = 0.15
	NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.3, 1.0]})
	var p := _resolve_player(attacker)
	if p != null:
		hit_by.emit(p)

# Kugeln von Drohnen und Türmen zählen für deren Besitzer.
static func _resolve_player(attacker) -> Player:
	if not is_instance_valid(attacker):
		return null
	if attacker is Player:
		return attacker
	var owner_p = attacker.get("owner_player")
	if is_instance_valid(owner_p) and owner_p is Player:
		return owner_p
	return null

# --- Darstellung ---

func _draw() -> void:
	var bob := sin(_anim * 4.0) * 3.0
	var angry := is_angry()
	var pulse := 0.5 + 0.5 * sin(_anim * 14.0)
	var body := BODY_COLOR.lerp(ANGRY_COLOR, pulse * 0.7) if angry else BODY_COLOR
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2(_facing, 1.0))

	# Fledermausflügel hinter dem Körper
	var flap := sin(_anim * (26.0 if angry else 17.0)) * 7.0
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var base_x := -3.0 * s
		var wing := PackedVector2Array([
			Vector2(base_x, -5.0),
			Vector2(base_x - 21.0 * s, -15.0 + flap),
			Vector2(base_x - 17.0 * s, -6.0 + flap * 0.6),
			Vector2(base_x - 22.0 * s, 0.0 + flap * 0.4),
			Vector2(base_x - 12.0 * s, 1.0),
			Vector2(base_x, 2.0),
		])
		draw_colored_polygon(wing, WING_COLOR)

	# Spitzer Schwanz
	var tail := PackedVector2Array([Vector2(-11, 5), Vector2(-17, 9), Vector2(-21, 6), Vector2(-22, 0)])
	draw_polyline(tail, body.darkened(0.2), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-22, -5), Vector2(-26, 1), Vector2(-19, 1)]), body.darkened(0.2))

	# Körper, Hörner, Ohr
	draw_circle(Vector2.ZERO, 13.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -10), Vector2(-3, -11), Vector2(-8, -20)]), HORN_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(3, -12), Vector2(7, -10), Vector2(6, -21)]), HORN_COLOR)
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -12), Vector2(-5, -6), Vector2(1, -7)]), body.darkened(0.3))

	# Rüssel mit Nasenlöchern
	draw_circle(Vector2(12.0, 2.0), 5.0, Color(1.0, 0.5, 0.5))
	draw_circle(Vector2(11.0, 1.0), 1.1, Color(0.3, 0.05, 0.05))
	draw_circle(Vector2(14.0, 1.0), 1.1, Color(0.3, 0.05, 0.05))

	# Gelbes Auge mit Schlitzpupille und böser Braue
	draw_circle(Vector2(5.0, -4.0), 3.2, Color(1.0, 0.9, 0.2))
	draw_line(Vector2(5.0, -6.2), Vector2(5.0, -1.8), Color.BLACK, 1.4)
	draw_line(Vector2(1.0, -9.0), Vector2(9.0, -6.0 if angry else -7.5), Color(0.15, 0.0, 0.0), 2.0)

	# Wut: Dampfwölkchen aus dem Rüssel
	if angry:
		for i in 3:
			var t := fmod(_anim * 1.6 + float(i) / 3.0, 1.0)
			draw_circle(Vector2(17.0 + t * 14.0, 1.0 - t * 10.0 + (i - 1) * 3.0), 1.5 + t * 3.0,
				Color(0.85, 0.85, 0.85, 0.7 * (1.0 - t)))

	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 14.0, Color(1, 1, 1, _hit_flash / 0.15 * 0.7))

	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE)
	# Restliche Wut als Ring
	if angry:
		var frac := clampf(angry_time / maxf(0.01, angry_duration), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 21.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(1.0, 0.45, 0.1, 0.9), 2.5)

	# Markierung über dem Kopf des Ziels
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_instance_valid(target) and not target.is_dead:
		var head := target.global_position - global_position + Vector2(0.0, -40.0 * target.scale.y - 6.0 + sin(_anim * 6.0) * 2.0)
		var col := ANGRY_COLOR if angry else Color(1.0, 0.2, 0.2)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -8), head + Vector2(6, -8), head]), col)
		draw_colored_polygon(PackedVector2Array([head + Vector2(-6, -8), head + Vector2(-3, -8), head + Vector2(-7, -15)]), col)
		draw_colored_polygon(PackedVector2Array([head + Vector2(3, -8), head + Vector2(6, -8), head + Vector2(7, -15)]), col)
