class_name RollingBall
extends RigidBody2D

## Rollende Kugel aus Gummi, Holz oder Eisen, 0,5, 1 oder 2 Kacheln groß. Echter
## Physikkörper (Host simuliert, Clients folgen per Snapshot): Kugeln rollen
## Schrägen hinab, prallen voneinander ab und verletzen Spieler, auf die sie
## zurollen oder fallen (PhysicsImpact). Projektile, Nahkampf und Explosionen
## beschädigen sie, bis sie zerbrechen.
##
## Material bestimmt Gewicht, Rückprall, Haltbarkeit und Schaden:
##   Gummi: wie ein Strandball, sehr leicht, fliegt bei Treffern und
##          Anrempeln weit weg, sehr zäh, macht wenig Schaden.
##   Holz:  mittel, zerbricht schnell, mittlerer Schaden.
##   Eisen: sehr schwer, kaum Rückprall, sehr zäh, viel Schaden, zertrümmert
##          Kisten und zerstörbare Blöcke, über die es rollt.

signal ball_broken(world_position, attacker)

const TILE_SIZE: float = 36.0
const MATERIALS: Dictionary = {
	"rubber": {
		# Wie ein Strandball: sehr leicht, schwebt etwas, fliegt bei Treffern
		# weit weg und hält viel aus.
		"label": "Gummi", "density": 0.2, "health": 300.0, "bounce": 0.85, "friction": 0.95,
		"damage": 0.45, "max_damage": 16.0, "knockback": 1.6, "smash": false,
		"push": 3.0, "drag": 0.35, "gravity": 0.65, "kick": true,
		"color": Color(0.93, 0.30, 0.38), "dark": Color(0.52, 0.09, 0.17), "light": Color(1.0, 0.66, 0.70),
	},
	"wood": {
		"label": "Holz", "density": 0.9, "health": 40.0, "bounce": 0.18, "friction": 0.8,
		"damage": 1.0, "max_damage": 30.0, "knockback": 1.0, "smash": false,
		"push": 1.0, "drag": 0.05, "gravity": 1.0, "kick": false,
		"color": Color(0.70, 0.46, 0.24), "dark": Color(0.38, 0.22, 0.10), "light": Color(0.92, 0.70, 0.42),
	},
	"iron": {
		"label": "Eisen", "density": 2.4, "health": 120.0, "bounce": 0.04, "friction": 0.6,
		"damage": 1.7, "max_damage": 55.0, "knockback": 1.25, "smash": true,
		"push": 0.6, "drag": 0.05, "gravity": 1.0, "kick": false,
		"color": Color(0.52, 0.56, 0.62), "dark": Color(0.22, 0.24, 0.28), "light": Color(0.86, 0.90, 0.96),
	},
}
# Große Kugeln: vierfache Masse, doppelte Haltbarkeit, mehr Schaden.
const BIG_HEALTH_MULT: float = 2.0
const BIG_DAMAGE_MULT: float = 1.35
const BIG_MAX_DAMAGE_MULT: float = 1.4
# Kleine Kugeln (halbe Kachel): Viertel der Masse, halbe Haltbarkeit,
# weniger Schaden; kleine Eisenkugeln zertrümmern nichts.
const SMALL_HEALTH_MULT: float = 0.5
const SMALL_DAMAGE_MULT: float = 0.7
const SMALL_MAX_DAMAGE_MULT: float = 0.6
const MAX_SPEED: float = 1100.0
# Spieler sind CharacterBody2D und schieben Rigid Bodies nicht von selbst:
# Wer auf einer Kugel steht, drückt sie (außermittig, sie rollt weg), wer
# seitlich dagegen läuft, schiebt sie an. Schwere Kugeln bewegen sich kaum.
const PLAYER_WEIGHT: float = 700.0
const PLAYER_PUSH: float = 900.0
const BULLET_PUSH: float = 70.0
const BLAST_DAMAGE: float = 35.0
# Holzkugeln splittern bei harten Aufprallen, Eisenkugeln zertrümmern
# Kisten und zerstörbare Blöcke ab dieser Annäherungsgeschwindigkeit.
const WOOD_CRACK_SPEED: float = 650.0
const SMASH_SPEED: float = 260.0
const SMASH_COOLDOWN: float = 0.35
# Gummikugeln: Wer dagegen läuft oder springt, kickt sie weg (Faktor auf die
# Annäherungsgeschwindigkeit, mindestens KICK_MIN_SPEED).
const KICK_FACTOR: float = 1.4
const KICK_MIN_SPEED: float = 260.0
const KICK_COOLDOWN: float = 0.25

var net_id: int = 0
var object_type: String = "ball"
var is_replica: bool = false
var ball_material: String = "wood"
# 0.5, 1 oder 2 Kacheln.
var ball_size: float = 1.0
# > 0: Kugel verschwindet nach so vielen Sekunden (Spawner, Modifier).
var lifetime: float = 0.0
var health: float = 40.0
var max_health: float = 40.0
var last_attacker: Node = null

var _radius: float = 17.0
var _broken: bool = false
var _previous_velocity: Vector2 = Vector2.ZERO
var _hit_cooldowns: Dictionary = {}
var _smash_cooldowns: Dictionary = {}
var _kick_cooldowns: Dictionary = {}
var _crack_cooldown: float = 0.0
var _net_pos: Vector2 = Vector2.ZERO
var _net_rot: float = 0.0
var _net_seen: bool = false

static func random_material(rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	if roll < 0.42:
		return "wood"
	if roll < 0.74:
		return "rubber"
	return "iron"

static func radius_for(size: float) -> float:
	if size >= 1.5:
		return 35.0
	if size >= 0.75:
		return 17.0
	return 8.5

## Zufällige Größe: big_chance für 2 Kacheln, small_chance für 0,5 Kacheln.
static func random_size(rng: RandomNumberGenerator, big_chance: float, small_chance: float) -> float:
	var roll := rng.randf()
	if roll < big_chance:
		return 2.0
	if roll < big_chance + small_chance:
		return 0.5
	return 1.0

func _size_mult(big: float, normal: float, small: float) -> float:
	if ball_size >= 1.5:
		return big
	if ball_size >= 0.75:
		return normal
	return small

func _ready() -> void:
	add_to_group("rolling_ball")
	if not MATERIALS.has(ball_material):
		ball_material = "wood"
	ball_size = _size_mult(2.0, 1.0, 0.5)
	var mat: Dictionary = MATERIALS[ball_material]
	_radius = radius_for(ball_size)
	var area := ball_size * ball_size
	max_health = float(mat["health"]) * _size_mult(BIG_HEALTH_MULT, 1.0, SMALL_HEALTH_MULT)
	health = max_health
	collision_layer = 1
	collision_mask = 7
	mass = float(mat["density"]) * area
	gravity_scale = float(mat.get("gravity", 1.0))
	linear_damp = float(mat.get("drag", 0.05))
	angular_damp = 0.15
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = float(mat["friction"])
	physics_material_override.bounce = float(mat["bounce"])
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _radius
	col.shape = shape
	add_child(col)
	z_index = 1
	queue_redraw()
	if is_replica:
		set_replica(true)
	else:
		contact_monitor = true
		max_contacts_reported = 8

func _draw() -> void:
	var mat: Dictionary = MATERIALS.get(ball_material, MATERIALS["wood"])
	var base: Color = mat["color"]
	var dark: Color = mat["dark"]
	var light: Color = mat["light"]
	var r := _radius
	draw_circle(Vector2.ZERO, r, dark)
	draw_circle(Vector2.ZERO, r - 2.5, base)
	# Markierungen drehen sich mit, damit man das Rollen sieht.
	match ball_material:
		"wood":
			draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 28, dark, 1.6)
			draw_arc(Vector2.ZERO, r * 0.30, 0.0, TAU, 20, dark, 1.4)
			draw_line(Vector2(-r + 3.0, 0.0), Vector2(r - 3.0, 0.0), Color(dark.r, dark.g, dark.b, 0.7), 2.0)
		"rubber":
			draw_line(Vector2(0.0, -r + 2.5), Vector2(0.0, r - 2.5), light, _size_mult(5.0, 3.0, 1.6))
			draw_arc(Vector2.ZERO, r * 0.55, -0.6, 0.6, 10, light, 2.0)
			draw_arc(Vector2.ZERO, r * 0.55, PI - 0.6, PI + 0.6, 10, light, 2.0)
		"iron":
			for i in range(4):
				var a := TAU * float(i) / 4.0 + PI / 4.0
				draw_circle(Vector2.from_angle(a) * r * 0.62, _size_mult(3.2, 2.0, 1.1), dark)
			draw_arc(Vector2.ZERO, r * 0.86, 0.0, TAU, 32, Color(dark.r, dark.g, dark.b, 0.8), 1.6)
	# Glanzpunkt oben links.
	draw_circle(Vector2(-r * 0.36, -r * 0.38), r * 0.2, Color(light.r, light.g, light.b, 0.75))

func _physics_process(delta: float) -> void:
	if is_replica or _broken:
		return
	var mat: Dictionary = MATERIALS[ball_material]
	PhysicsImpact.tick_cooldowns(_hit_cooldowns, delta)
	PhysicsImpact.tick_cooldowns(_smash_cooldowns, delta)
	PhysicsImpact.tick_cooldowns(_kick_cooldowns, delta)
	_crack_cooldown = maxf(0.0, _crack_cooldown - delta)
	var source = last_attacker if is_instance_valid(last_attacker) else null
	var damage_mult := float(mat["damage"]) * _size_mult(BIG_DAMAGE_MULT, 1.0, SMALL_DAMAGE_MULT)
	var max_damage := float(mat["max_damage"]) * _size_mult(BIG_MAX_DAMAGE_MULT, 1.0, SMALL_MAX_DAMAGE_MULT)
	PhysicsImpact.check_players(self, _previous_velocity, _hit_cooldowns, damage_mult, max_damage, float(mat["knockback"]), source)
	if bool(mat["smash"]) and ball_size >= 0.75:
		_smash_obstacles()
	if ball_material == "wood" and _crack_cooldown <= 0.0:
		var speed_loss := _previous_velocity.length() - linear_velocity.length()
		if speed_loss > WOOD_CRACK_SPEED:
			_crack_cooldown = 0.4
			_take_hit(max_health * 0.5, null)
	_apply_player_contacts()
	if linear_velocity.length_squared() > MAX_SPEED * MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	_previous_velocity = linear_velocity
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			_break_apart()
			return
	# Aus der Karte gefallen (offene Kartenränder, Gruben): entfernen.
	if global_position.y > float(LevelGenerator.map_h + 8) * TILE_SIZE:
		_broken = true
		queue_free()

func _apply_player_contacts() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		var player := p as CharacterBody2D
		if player == null:
			continue
		for i in range(player.get_slide_collision_count()):
			var col := player.get_slide_collision(i)
			if col.get_collider() != self:
				continue
			var normal := col.get_normal()
			if bool(MATERIALS[ball_material].get("kick", false)) and normal.y >= -0.5:
				_kick_from(player, normal)
			elif normal.y < -0.5:
				apply_force(Vector2(0.0, PLAYER_WEIGHT), col.get_position() - global_position)
			elif absf(normal.x) > 0.5:
				apply_central_force(Vector2(-normal.x * PLAYER_PUSH, 0.0))
			break

## Gummikugel: Ein Spieler stößt sie seitlich oder von unten an und sie
## fliegt wie ein Strandball davon.
func _kick_from(player: CharacterBody2D, normal: Vector2) -> void:
	var key := player.get_instance_id()
	if _kick_cooldowns.has(key):
		return
	_kick_cooldowns[key] = KICK_COOLDOWN
	var dir := -normal
	var speed := maxf(KICK_MIN_SPEED, player.velocity.dot(dir) * KICK_FACTOR)
	apply_central_impulse((dir * speed + Vector2(0.0, -140.0)) * mass)
	SoundManager.play_sound("bounce", 0.2, -6.0)
	NetFx.send("mobj", NetFx.mobj_args(self, "kick"))

## Eisenkugeln: Kisten, Kettenglieder und zerstörbare Blöcke, auf die sie
## schnell genug zurollen, bekommen einen Treffer.
func _smash_obstacles() -> void:
	for other in get_colliding_bodies():
		# Kettenglieder und Kettensperren reißen nur durch Schüsse.
		if other is Player or other == self or other is ChainLink or other is BallGate:
			continue
		if not (other.has_method("hit_crate") or other.has_method("hit_tile")):
			continue
		var key: int = other.get_instance_id()
		if _smash_cooldowns.has(key):
			continue
		var dir: Vector2 = (other as Node2D).global_position - global_position
		if dir.length_squared() < 0.01:
			continue
		if _previous_velocity.dot(dir.normalized()) < SMASH_SPEED:
			continue
		_smash_cooldowns[key] = SMASH_COOLDOWN
		if other.has_method("hit_crate"):
			other.hit_crate(self)
		else:
			other.hit_tile(20.0)

func hit_crate(projectile: Node2D = null) -> void:
	if is_replica or _broken:
		return
	var attacker: Node = null
	var amount := 20.0
	if projectile != null:
		var shooter = projectile.get("shooter")
		if is_instance_valid(shooter) and shooter is Node:
			attacker = shooter
		var dmg = projectile.get("damage")
		if dmg is float or dmg is int:
			amount = maxf(1.0, float(dmg))
		var vel = projectile.get("velocity")
		if vel is Vector2 and (vel as Vector2).length_squared() > 1.0 and not (projectile is RollingBall):
			apply_central_impulse((vel as Vector2).normalized() * BULLET_PUSH * float(MATERIALS[ball_material].get("push", 1.0)))
	_take_hit(amount, attacker)

func apply_blast(blast_position: Vector2, radius: float, force: float = 520.0, attacker: Node = null) -> void:
	if is_replica or _broken:
		return
	var distance := blast_position.distance_to(global_position)
	if distance > radius:
		return
	var falloff := clampf(1.0 - distance / maxf(1.0, radius), 0.15, 1.0)
	var direction := (global_position - blast_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	# Wie bei Kisten (Masse um 1): leichte Kugeln fliegen weiter als schwere.
	apply_central_impulse((direction * force * falloff + Vector2(0.0, -90.0)) * float(MATERIALS[ball_material].get("push", 1.0)))
	_take_hit(BLAST_DAMAGE * falloff, attacker)

func _take_hit(amount: float, attacker: Node) -> void:
	if _broken:
		return
	if attacker != null and is_instance_valid(attacker):
		last_attacker = attacker
	health -= amount
	_play_hit_feedback()
	NetFx.send("mobj", NetFx.mobj_args(self, "hit"))
	if health <= 0.0:
		_break_apart()

func _play_hit_feedback() -> void:
	_flash_damage()
	match ball_material:
		"rubber":
			SoundManager.play_sound("bounce", 0.2, -4.0)
		_:
			SoundManager.play_sound("hit", 0.18, -3.0)

# Client: Treffer vom Host (Blitz und Ton) bzw. Tritt eines Spielers.
func play_network_fx(method: String) -> void:
	if method == "kick":
		SoundManager.play_sound("bounce", 0.2, -6.0)
	else:
		_play_hit_feedback()

func _flash_damage() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.6, 0.8, 0.6), 0.06)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func _break_apart() -> void:
	if _broken:
		return
	_broken = true
	var attacker := last_attacker
	_spawn_shards(global_position)
	ball_broken.emit(global_position, attacker)
	queue_free()

func _spawn_shards(at: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat: Dictionary = MATERIALS.get(ball_material, MATERIALS["wood"])
	var fx := Node2D.new()
	fx.global_position = at
	fx.z_index = 5
	parent.add_child(fx)
	var count := int(_size_mult(10.0, 6.0, 4.0))
	for i in range(count):
		var shard := Polygon2D.new()
		var s := (3.0 + float(i % 3) * 1.5) * _size_mult(1.5, 1.0, 0.6)
		shard.polygon = PackedVector2Array([Vector2(-s, -s), Vector2(s, 0), Vector2(-s, s)])
		shard.color = mat["color"] if i % 2 == 0 else mat["dark"]
		shard.rotation = float(i) * TAU / float(count)
		fx.add_child(shard)
		var direction := Vector2.from_angle(float(i) * TAU / float(count) + 0.35)
		var tw := shard.create_tween()
		tw.tween_property(shard, "position", direction * (_radius + 10.0 + float(i % 3) * 9.0), 0.24)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.26)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.32)
	cleanup.tween_callback(fx.queue_free)

## Client: Die Kugel fehlt im Host-Snapshot, sie ist zerbrochen.
func spawn_remote_explosion() -> void:
	if not _broken:
		_broken = true
		_spawn_shards(global_position)
	queue_free()

func set_replica(replica: bool) -> void:
	is_replica = replica
	freeze = replica
	can_sleep = false
	contact_monitor = not replica
	if replica:
		collision_layer = 0
		collision_mask = 0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
	else:
		collision_layer = 1
		collision_mask = 7

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"rot": rotation,
		"mat": ball_material,
		"size": ball_size,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	_net_pos = data.get("pos", global_position)
	_net_rot = float(data.get("rot", rotation))
	if not _net_seen:
		_net_seen = true
		global_position = _net_pos
		rotation = _net_rot

## Clients: zwischen den Snapshots zur letzten Lage gleiten, schnelle Kugeln
## ruckeln sonst sichtbar.
func _process(delta: float) -> void:
	if not is_replica or not _net_seen:
		return
	var t := clampf(delta * 18.0, 0.0, 1.0)
	global_position = global_position.lerp(_net_pos, t)
	rotation = lerp_angle(rotation, _net_rot, t)
