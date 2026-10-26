class_name Companion
extends StaticBody2D

# Begleiter für Türme, Wächterdrohnen und Schutzdrohnen.
# Der Host simuliert Angriff, Blocken, Heilung und Turm-Schaden. Auf dem Client
# werden Türme als Replikate aus den Snapshots bewegt; Drohnen laufen dort rein
# visuell mit.

enum Mode {
	TOWER,
	DRONE
}

const BULLET_SCENE: PackedScene = preload("res://scenes/player/bullet.tscn")
const DRONE_TEXTURE: Texture2D = preload("res://assets/projectiles/tile_0000.png")
const SHIELD_TEXTURE: Texture2D = preload("res://assets/projectiles/effect_circle.png")

const BASE_MAX_HEALTH: float = 100.0
const BASE_FIRE_INTERVAL: float = 0.85
const BASE_DAMAGE_MULT: float = 0.65
const TOWER_COLLISION_LAYER: int = 16
const TOWER_HIT_RADIUS: float = 14.0

static var _next_net_id: int = 1

var mode: Mode = Mode.TOWER
var owner_player: Player = null
var target_enemy: Player = null
var follow_owner: bool = false
var support: bool = false
var is_replica: bool = false
var orbit_radius: float = 54.0
var orbit_speed: float = 1.6
var fire_interval: float = BASE_FIRE_INTERVAL
var damage_mult: float = BASE_DAMAGE_MULT
var max_health: float = BASE_MAX_HEALTH
var current_health: float = BASE_MAX_HEALTH
var net_id: int = 0
var aim_angle: float = 0.0

var cannon: TowerCannon = null
var _fire_timer: float = 0.35
var _heal_timer: float = 1.0
var _orbit_angle: float = 0.0
var _sprite: Sprite2D = null
var _shield_aura: Sprite2D = null

# Schutzdrohne: blockt Projektile, schießt dafür nicht.
var blocks_projectiles: bool = false
var block_heals_owner: bool = false
var block_radius: float = 25.0

func _init() -> void:
	net_id = _next_net_id
	_next_net_id += 1

func _ready() -> void:
	z_index = 3
	collision_layer = 0
	collision_mask = 0
	if mode == Mode.TOWER:
		add_to_group("tower")
		add_to_group("companion")
		collision_layer = TOWER_COLLISION_LAYER
		var collider := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = TOWER_HIT_RADIUS
		collider.shape = shape
		collider.position = Vector2(0.0, 2.0)
		collider.disabled = is_replica
		add_child(collider)
		cannon = TowerCannon.new()
		cannon.z_index = -1
		cannon.set_accent_color(_owner_accent_color())
		add_child(cannon)
		current_health = max_health
		queue_redraw()
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

func _owner_accent_color() -> Color:
	if is_instance_valid(owner_player):
		var hero: HeroData = Global.get_hero(Global.get_player_hero_id(owner_player.player_index))
		if hero != null:
			return hero.color_tint
	return Color(0.45, 0.80, 1.0, 1.0)

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
	elif mode == Mode.TOWER:
		if not is_replica:
			if not is_instance_valid(target_enemy) or target_enemy.current_health <= 0.0:
				target_enemy = _find_target()
			if is_instance_valid(target_enemy):
				aim_angle = (target_enemy.global_position - global_position).angle()
			if follow_owner:
				_orbit_angle += delta * 0.7
				var tower_offset := Vector2(cos(_orbit_angle), sin(_orbit_angle)) * (orbit_radius + 12.0)
				global_position = global_position.lerp(owner_player.global_position + tower_offset, delta * 4.0)
		if is_instance_valid(cannon):
			cannon.set_aim_angle(aim_angle)

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
	ring.add_to_group("round_effect")
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
	bullet.global_position = get_muzzle_position()
	if bullet.has_node("Sprite2D"):
		bullet.get_node("Sprite2D").modulate = Color(0.65, 0.90, 1.0)
	if is_instance_valid(cannon):
		cannon.play_recoil()

func _find_target() -> Player:
	for p in get_tree().get_nodes_in_group("player"):
		if p != owner_player and is_instance_valid(p) and p.current_health > 0.0 and p.team_id != owner_player.team_id:
			return p
	return null

func get_muzzle_position() -> Vector2:
	if is_instance_valid(cannon):
		return cannon.get_muzzle_position()
	return global_position + Vector2(0.0, -2.0) + Vector2(28.0, 0.0).rotated(aim_angle)

# Wird vom Projektil aufgerufen. Freundliches Feuer wird ignoriert, damit
# eigene Türme nicht durch die eigenen Geschosse beschädigt werden.
func hit_tower(bullet: Bullet) -> bool:
	if mode != Mode.TOWER or is_replica or bullet == null:
		return false
	if is_friendly_attacker(bullet.shooter):
		return false
	take_tower_damage(bullet.damage, bullet.shooter)
	SoundManager.play_sound("hit", 0.18, 1.0)
	return true

func take_tower_damage(amount: float, attacker = null) -> void:
	if mode != Mode.TOWER or is_replica or amount <= 0.0 or current_health <= 0.0:
		return
	# Der Schütze kann zwischen Projektilstart und Einschlag freigegeben worden
	# sein. Ein untypisierter Parameter verhindert hier bereits den Laufzeitfehler
	# beim Übergeben einer freigegebenen Instanz; für den Kill-Credit wird sie
	# anschließend verworfen.
	if attacker != null and not is_instance_valid(attacker):
		attacker = null
	if is_friendly_attacker(attacker):
		return
	var old_health := current_health
	current_health = maxf(0.0, current_health - amount)
	queue_redraw()
	_flash_cannon()
	if current_health <= 0.0:
		_destroy_tower()
	elif is_instance_valid(owner_player) and is_instance_valid(attacker) and attacker is Player:
		var dealt := minf(amount, old_health)
		Global.add_match_stat((attacker as Player).player_index, "damage_dealt", dealt)

func is_friendly_attacker(attacker) -> bool:
	if attacker == null or not is_instance_valid(attacker) or not is_instance_valid(owner_player):
		return false
	if attacker == owner_player:
		return true
	if attacker is Player:
		return (attacker as Player).team_id == owner_player.team_id
	return false

func _flash_cannon() -> void:
	if not is_instance_valid(cannon):
		return
	cannon.modulate = Color(1.35, 0.72, 0.72, 1.0)
	var tween := create_tween()
	tween.tween_property(cannon, "modulate", Color.WHITE, 0.12)

func _destroy_tower() -> void:
	if is_queued_for_deletion():
		return
	if is_instance_valid(owner_player):
		owner_player.towers.erase(self)
	SoundManager.play_sound("explosion", 0.22, -3.0)
	_spawn_destroy_effect()
	queue_free()

func _spawn_destroy_effect() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ring := Sprite2D.new()
	ring.texture = SHIELD_TEXTURE
	ring.modulate = Color(1.0, 0.55, 0.15, 0.9)
	ring.scale = Vector2(0.35, 0.35)
	ring.add_to_group("round_effect")
	parent.add_child(ring)
	ring.global_position = global_position
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(1.8, 1.8), 0.28)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.28)
	tween.tween_callback(ring.queue_free)

func apply_network_state(pos: Vector2, health: float = -1.0, max_health_value: float = -1.0, network_aim: float = 0.0) -> void:
	if not is_replica:
		return
	global_position = pos
	if max_health_value > 0.0:
		max_health = max_health_value
	if health >= 0.0:
		current_health = health
	aim_angle = network_aim
	if is_instance_valid(cannon):
		cannon.set_aim_angle(aim_angle)
	queue_redraw()
	if current_health <= 0.0:
		queue_free()

func _draw() -> void:
	if mode != Mode.TOWER:
		return
	var bar_width := 44.0
	var bar_height := 6.0
	var bar_y := -34.0
	var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
	var fill := Color(0.30, 0.90, 0.38, 1.0)
	if ratio <= 0.25:
		fill = Color(0.95, 0.25, 0.22, 1.0)
	elif ratio <= 0.55:
		fill = Color(1.0, 0.72, 0.20, 1.0)
	draw_rect(Rect2(-bar_width * 0.5 - 1.0, bar_y - 1.0, bar_width + 2.0, bar_height + 2.0), Color(0.02, 0.03, 0.05, 0.92))
	draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, bar_height), Color(0.18, 0.07, 0.07, 0.95))
	if ratio > 0.0:
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * ratio, bar_height), fill)
		draw_line(Vector2(-bar_width * 0.5 + 1.0, bar_y + 1.0), Vector2(-bar_width * 0.5 + bar_width * ratio - 1.0, bar_y + 1.0), Color(1.0, 1.0, 1.0, 0.28), 1.0)
