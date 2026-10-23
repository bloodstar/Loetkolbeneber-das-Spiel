class_name Companion
extends Node2D

# Begleiter für Türme, Wächterdrohnen und Schutzdrohnen.
# Der Host simuliert Angriff, Blocken und Heilung. Auf dem Client werden Türme
# als Replikate aus den Snapshots bewegt; Drohnen laufen dort rein visuell mit.

enum Mode {
	TOWER,
	DRONE
}

const BULLET_SCENE: PackedScene = preload("res://scenes/player/bullet.tscn")
const TOWER_TEXTURE: Texture2D = preload("res://assets/projectiles/tile_0004.png")
const DRONE_TEXTURE: Texture2D = preload("res://assets/projectiles/tile_0000.png")
const SHIELD_TEXTURE: Texture2D = preload("res://assets/projectiles/effect_circle.png")

static var _next_net_id: int = 1

var mode: Mode = Mode.TOWER
var owner_player: Player = null
var target_enemy: Player = null
var follow_owner: bool = false
var support: bool = false
var is_replica: bool = false
var orbit_radius: float = 54.0
var orbit_speed: float = 1.6
var fire_interval: float = 0.85
var damage_mult: float = 0.65
var net_id: int = 0

# Schutzdrohne: blockt Projektile, schießt dafür nicht.
var blocks_projectiles: bool = false
var block_heals_owner: bool = false
var block_radius: float = 25.0

var _fire_timer: float = 0.35
var _heal_timer: float = 1.0
var _orbit_angle: float = 0.0
var _sprite: Sprite2D = null
var _shield_aura: Sprite2D = null

func _init() -> void:
	net_id = _next_net_id
	_next_net_id += 1

func _ready() -> void:
	z_index = 3
	if mode == Mode.TOWER:
		add_to_group("tower")
		add_to_group("companion")
		_sprite = Sprite2D.new()
		_sprite.texture = TOWER_TEXTURE
		_sprite.scale = Vector2(1.9, 1.9)
		_sprite.modulate = Color(0.55, 0.85, 1.0)
		add_child(_sprite)
	else:
		add_to_group("drone")
		add_to_group("companion")
		if blocks_projectiles:
			_shield_aura = Sprite2D.new()
			_shield_aura.texture = SHIELD_TEXTURE
			_shield_aura.scale = Vector2(0.72, 0.72)
			_shield_aura.modulate = Color(0.45, 0.90, 1.0, 0.42)
			add_child(_shield_aura)
		_sprite = Sprite2D.new()
		_sprite.texture = DRONE_TEXTURE
		_sprite.scale = Vector2(1.15, 1.15)
		_sprite.modulate = Color(0.45, 0.90, 1.0) if blocks_projectiles else Color(0.55, 0.90, 1.0)
		add_child(_sprite)

	if mode == Mode.DRONE:
		_orbit_angle = randf() * TAU

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player):
		queue_free()
		return

	if mode == Mode.DRONE:
		_orbit_angle += delta * orbit_speed
		var offset := Vector2(cos(_orbit_angle), sin(_orbit_angle)) * orbit_radius
		global_position = owner_player.global_position + offset
		if not is_replica:
			if blocks_projectiles:
				_try_block_projectiles(delta)
			else:
				_handle_support(delta)
	elif follow_owner and not is_replica:
		_orbit_angle += delta * 0.7
		var tower_offset := Vector2(cos(_orbit_angle), sin(_orbit_angle)) * (orbit_radius + 12.0)
		global_position = global_position.lerp(owner_player.global_position + tower_offset, delta * 4.0)

	if is_replica:
		return
	# Während des Start-Countdowns dürfen auch Begleiter nicht angreifen.
	if not owner_player.control_enabled:
		return
	# Schutzdrohnen greifen nicht an; ihre Aufgabe ist ausschließlich das
	# Abfangen gegnerischer Projektile.
	if blocks_projectiles:
		return

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_try_fire()

func _handle_support(delta: float) -> void:
	if not support or not owner_player.control_enabled:
		return
	_heal_timer -= delta
	if _heal_timer <= 0.0:
		_heal_timer = 1.0
		if is_instance_valid(owner_player) and owner_player.current_health < owner_player.max_health:
			owner_player.heal(1.5)

# Prüft alle Projektile gegen die Flugbahn des aktuellen Frames. Die
# Segmentprüfung verhindert, dass schnelle Schüsse durch die kleine Drohne
# hindurchrutschen. Der Host entscheidet; Clients sehen nur die Drohne.
func _try_block_projectiles(delta: float) -> void:
	if not blocks_projectiles or is_replica or not is_instance_valid(owner_player):
		return
	var step := clampf(delta, 0.0, 0.05)
	for node in get_tree().get_nodes_in_group("bullet"):
		var bullet := node as Bullet
		if bullet == null or bullet.is_replica or bullet.blocked_by_drone \
				or bullet.is_queued_for_deletion():
			continue
		if _is_friendly_projectile(bullet):
			continue
		var start := bullet.global_position
		var finish := start + bullet.velocity * step
		var closest := Geometry2D.get_closest_point_to_segment(global_position, start, finish)
		if global_position.distance_to(closest) <= block_radius:
			_block_projectile(bullet)

func _is_friendly_projectile(bullet: Bullet) -> bool:
	var shooter := bullet.shooter
	if shooter == owner_player:
		return true
	if not is_instance_valid(shooter) or not (shooter is Player):
		return false
	var shooter_player := shooter as Player
	return shooter_player.team_id == owner_player.team_id

func _block_projectile(bullet: Bullet) -> void:
	var blocked_damage := maxf(float(bullet.damage), 0.0)
	if not bullet.block_by_drone():
		return
	_spawn_block_flash()
	SoundManager.play_sound("shield", 0.18, 3.0)
	if not is_instance_valid(owner_player):
		return
	Global.add_match_stat(owner_player.player_index, "damage_blocked", blocked_damage)
	Global.add_match_stat(owner_player.player_index, "blocked_hits", 1.0)
	if block_heals_owner and blocked_damage > 0.0 and owner_player.current_health > 0.0:
		owner_player.heal(blocked_damage)

func _spawn_block_flash() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Sprite2D.new()
	ring.texture = SHIELD_TEXTURE
	ring.modulate = Color(0.65, 1.0, 1.0, 0.9)
	ring.scale = Vector2(0.35, 0.35)
	parent.add_child(ring)
	ring.global_position = global_position
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.18)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)

func _try_fire() -> void:
	if not is_instance_valid(target_enemy) or target_enemy.current_health <= 0.0:
		target_enemy = _find_target()
	if not is_instance_valid(target_enemy):
		return

	var direction := (target_enemy.global_position - global_position).normalized()
	if direction == Vector2.ZERO:
		return

	var bullet = BULLET_SCENE.instantiate()
	bullet.shooter = owner_player
	# Nur gültige, lebende Ziele setzen (Gegner kann zwischen Frames sterben).
	bullet.target_enemy = target_enemy if is_instance_valid(target_enemy) else null
	bullet.damage = owner_player.bullet_damage * damage_mult
	bullet.velocity = direction * 680.0
	bullet.bounces_left = 0
	bullet.explosion_radius = 0.0
	bullet.max_lifetime = 2.0
	bullet.rotation = direction.angle()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	if bullet.has_node("Sprite2D"):
		bullet.get_node("Sprite2D").modulate = Color(0.65, 0.90, 1.0)

func _find_target() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p != owner_player and is_instance_valid(p) and p.current_health > 0.0 and p.team_id != owner_player.team_id:
			return p
	return null

func apply_network_state(pos: Vector2) -> void:
	if not is_replica:
		return
	global_position = pos
