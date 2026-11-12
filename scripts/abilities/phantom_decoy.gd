class_name PhantomDecoy
extends CharacterBody2D

# Phantoms Fähigkeit "Köder": ein Doppelgänger, der in Blickrichtung
# weiterläuft, während Phantom selbst unsichtbar ist. Er sieht aus wie der
# echte Eber (samt Lebensbalken), hat wenig Leben und verschwindet nach
# kurzer Zeit. Bots, Türme und zielsuchende Kugeln nehmen ihn als Ziel.
#
# Er liegt auf der Turm-Ebene und nutzt dieselbe Schnittstelle wie Türme
# (hit_tower / take_tower_damage), damit Kugeln, Explosionen und Nahkampf
# ihn ohne Sonderfälle treffen.
#
# Der Host simuliert ihn, Clients bekommen ihn über den Snapshot ("ents").

const GRAVITY: float = 980.0
const BAR_Y: float = 22.0
const BAR_WIDTH: float = 28.0
const BAR_HEIGHT: float = 2.4

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0
var team_id: int = -1

var max_hp: float = 40.0
var hp: float = 40.0
var duration: float = 3.5
var run_dir: Vector2 = Vector2.RIGHT
var run_speed: float = 300.0
var jump_force: float = -480.0
var gravity_mult: float = 1.0
# Evolution "Lähmendes Mal": Wer den Köder trifft, wird so lange betäubt.
var stun_on_hit: float = 0.0
# Evolution "Sprengköder": explodiert beim Zerstören oder Ablaufen.
var bomb: bool = false
# Evolution "Platztausch": pro Köder nur ein Tausch.
var swapped: bool = false
# Anteil am Lebensbalken, den der echte Eber beim Wurf hatte.
var shown_health: float = 1.0
var shown_shield: float = 0.0
var arena_z: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _gone: bool = false
var _pig: PigCharacter = null
var _wand: MagicWand = null
var _net_target: Vector2 = Vector2.ZERO
var _hit_flash: float = 0.0
var _jump_cooldown: float = 0.0

func _ready() -> void:
	add_to_group(NetEntity.GROUP)
	add_to_group("phantom_decoy")
	add_to_group("round_effect")
	if not is_replica:
		net_id = NetEntity.next_id()
	_net_target = global_position
	collision_layer = Companion.TOWER_COLLISION_LAYER
	collision_mask = 1
	if is_replica:
		collision_layer = 0
		collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 22.0)
	col.shape = shape
	col.position = Vector2(0.0, 1.0)
	add_child(col)
	if ArenaMode.active:
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		if not is_replica:
			collision_mask = ArenaMode.with_bands(collision_mask, ArenaMode.body_band_mask(arena_z))
	_build_look()

# Übernimmt Aussehen, Größe und Zustand des Besitzers.
func setup(owner: Player) -> void:
	owner_player = owner
	owner_index = owner.player_index
	team_id = owner.team_id
	scale = owner.scale
	run_speed = owner.move_speed
	jump_force = owner.jump_force
	gravity_mult = owner.gravity_mult
	arena_z = owner.arena_z
	shown_health = clampf(owner.current_health / maxf(1.0, owner.max_health), 0.0, 1.0)
	shown_shield = clampf(owner.current_shield / maxf(1.0, owner.max_health), 0.0, 1.0)

func _look_source() -> Player:
	if is_instance_valid(owner_player):
		return owner_player
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p != null and p.player_index == owner_index:
			return p
	return null

func _build_look() -> void:
	var source := _look_source()
	var pig := PigModular.new()
	if source != null and is_instance_valid(source.sprite):
		pig.setup(source.sprite.fur_color, source.sprite.eye_color, source.sprite.pants_color)
		if source.sprite is PigModular:
			pig.apply_parts((source.sprite as PigModular).get_parts())
		pig.set_outfit(source.sprite.outfit_id)
		pig.set_team_color(source.sprite.team_color)
		pig.set_tusk_shape(source.sprite.tusk_shape)
		scale = source.scale
		team_id = source.team_id
	pig.use_parent_floor_state = not is_replica
	add_child(pig)
	_pig = pig
	_wand = MagicWand.new()
	if source != null:
		_wand.setup(source.wand_tip_shape, source.wand_tip_color)
	add_child(_wand)
	if ArenaMode.active:
		# In der Arena zeichnet ArenaView3D ein Voxel-Schwein.
		pig.visible = false
		_wand.visible = false
	_update_facing()

func _update_facing() -> void:
	var dir := aim_direction if aim_direction.length_squared() > 0.01 else run_dir
	if _wand != null:
		_wand.rotation = dir.angle()
		_wand.set_flip_v(absf(_wand.rotation) > PI / 2.0)
	if _pig != null:
		_pig.flip_h = absf(dir.angle()) > PI / 2.0

func _physics_process(delta: float) -> void:
	if is_replica or _gone:
		return
	_age += delta
	if _age >= duration:
		pop()
		return
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	if ArenaMode.active:
		velocity = run_dir * run_speed
		move_and_slide()
		# An einer Wand entlanggleiten wirkt glaubwürdiger als stehen zu bleiben.
		if get_slide_collision_count() > 0 and get_real_velocity().length() < run_speed * 0.2:
			run_dir = run_dir.rotated(PI * 0.5)
		aim_direction = run_dir
	else:
		var side := signf(run_dir.x)
		if side == 0.0:
			side = 1.0
		velocity.x = side * run_speed
		if not is_on_floor():
			velocity.y += GRAVITY * gravity_mult * delta
		elif is_on_wall() and _jump_cooldown <= 0.0:
			velocity.y = jump_force
			_jump_cooldown = 0.4
		move_and_slide()
		aim_direction = Vector2(side, 0.0)
	_update_facing()

func _process(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if is_replica:
		if global_position.distance_to(_net_target) > 250.0:
			global_position = _net_target
		else:
			global_position = global_position.lerp(_net_target, clampf(20.0 * delta, 0.0, 1.0))
		_update_facing()
	if _pig != null:
		_pig.modulate = Color(2.2, 0.42, 0.42) if _hit_flash > 0.0 else Color.WHITE
	queue_redraw()

func is_active() -> bool:
	return not _gone and not is_queued_for_deletion()

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
	if _pig != null:
		_pig.play_hit(Vector2.ZERO, 0.8)
	if stun_on_hit > 0.0 and attacker is Player:
		(attacker as Player).apply_stun(stun_on_hit)
	if hp <= 0.0:
		pop()

# Löst den Köder auf. Mit "Sprengköder" explodiert er dabei.
func pop(explode: bool = true) -> void:
	if _gone:
		return
	_gone = true
	if not is_replica:
		NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(global_position,
			Color(0.5, 0.5, 0.7, 0.8), 0.6, 4.0, 0.25, 0.25), "teleport", 0.08, -4.0))
		if explode and bomb and is_instance_valid(owner_player):
			owner_player.phantom_decoy_explode(global_position)
	queue_free()

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"k": "decoy",
		"pos": global_position,
		"vel": velocity,
		"o": owner_index,
		"aim": aim_direction,
		"hp": clampf(hp / maxf(1.0, max_hp), 0.0, 1.0),
		"sh": shown_health,
		"ss": shown_shield,
		"z": arena_z,
	}

func apply_network_state(data: Dictionary) -> void:
	owner_index = int(data.get("o", owner_index))
	_net_target = data.get("pos", _net_target)
	velocity = data.get("vel", velocity)
	var aim = data.get("aim", aim_direction)
	if aim is Vector2:
		aim_direction = aim
	var ratio := float(data.get("hp", 1.0))
	if ratio < hp / maxf(1.0, max_hp) - 0.01:
		_hit_flash = 0.12
	hp = ratio * max_hp
	shown_health = float(data.get("sh", shown_health))
	shown_shield = float(data.get("ss", shown_shield))
	arena_z = float(data.get("z", arena_z))

func remove_replica() -> void:
	_gone = true
	queue_free()

# --- Darstellung ---

# Lebensbalken wie am echten Eber (player_status_indicators.gd). Er zeigt den
# Stand des Besitzers beim Wurf und sinkt mit dem Leben des Köders.
func _draw() -> void:
	if ArenaMode.active:
		return
	var ratio := shown_health * clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var background := Rect2(-BAR_WIDTH * 0.5 - 1.0, BAR_Y - 1.0, BAR_WIDTH + 2.0, BAR_HEIGHT + 2.0)
	draw_rect(background, Color(0.015, 0.02, 0.035, 0.66), true)
	draw_rect(background, Color(0.92, 0.96, 1.0, 0.16), false, 0.45, true)
	var color := Color(0.95, 0.23, 0.20, 0.98).lerp(Color(0.35, 0.94, 0.45, 0.98), smoothstep(0.15, 0.85, ratio))
	if ratio > 0.0:
		draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_Y, BAR_WIDTH * ratio, BAR_HEIGHT), color, true)
	if shown_shield > 0.0:
		draw_rect(Rect2(-BAR_WIDTH * 0.5, BAR_Y, BAR_WIDTH * minf(1.0, shown_shield), BAR_HEIGHT),
			Color(0.25, 0.55, 1.0, 0.72), true)
