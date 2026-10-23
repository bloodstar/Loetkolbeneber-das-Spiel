class_name Player
extends CharacterBody2D

signal died(player_index: int)
signal health_changed(current: float, max_h: float, shield: float, max_s: float)
signal ammo_changed(current: int, max_a: int)
signal ability_cooldown_updated(current: float, max_c: float)
signal block_state_changed(is_blocking: bool, cooldown: float, max_cooldown: float)

@export var player_index: int = 1
@export var team_id: int = 0
@export var is_bot: bool = false

# GrundgrÃƒÂ¶ÃƒÅ¸e der Spielfigur. Karten mit body_size_mult/giant_growth wirken
# zusÃƒÂ¤tzlich auf diesen Wert.
const BASE_CHARACTER_SCALE: float = 1.7
const GRAVITY: float = 980.0

# Nodes
@onready var sprite: PigCharacter = $Sprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var muzzle: Marker2D = $WeaponPivot/Muzzle
@onready var gun_sprite: Sprite2D = $WeaponPivot/GunSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ghost_timer: Timer = $GhostTimer

# Core Stats (Derived from Hero + Cards)
var max_health: float = 100.0
var current_health: float = 100.0
var max_shield: float = 0.0
var current_shield: float = 0.0
var move_speed: float = 300.0
var jump_force: float = -470.0
var gravity_mult: float = 1.0
var max_jumps: int = 1
var jumps_remaining: int = 1

# Bullet Stats
var bullet_damage: float = 22.0
var bullet_speed: float = 650.0
var bullet_size: float = 1.0
var projectile_gravity_mult: float = 1.0
var fire_rate_cooldown: float = 0.22
var fire_timer: float = 0.0
var max_ammo: int = 3
var current_ammo: int = 3
var reload_time: float = 1.8
var reload_timer: float = 0.0
var is_reloading: bool = false
var bounces: int = 0
var homing: float = 0.0
var explosion_radius: float = 0.0
var poison_stacks: int = 0
var freeze_duration: float = 0.0
var lifesteal_percent: float = 0.0
var multishot: int = 0
var spread_angle: float = 0.0
var piercing: int = 0
var kamikaze: bool = false
var ricochet_bonus: float = 0.0

# Dash
var dash_speed: float = 750.0
var dash_duration: float = 0.22
var dash_cooldown: float = 1.8
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var is_invulnerable: bool = false

# Ability
var ability_name: String = ""
var ability_max_cooldown: float = 6.0
var ability_timer: float = 0.0
var shield_dome_node: Sprite2D = null

# --- Standard-Block (Taste Q), fÃƒÂ¼r alle Spieler gleich ---
# Kurzer Schutz: verhindert Schaden vollstÃƒÂ¤ndig und reflektiert Projektile.
const BLOCK_BASE_DURATION: float = 0.5
const BLOCK_BASE_COOLDOWN: float = 4.0
var is_blocking: bool = false
var block_timer: float = 0.0
var block_duration: float = BLOCK_BASE_DURATION
var block_cooldown: float = BLOCK_BASE_COOLDOWN
var block_cooldown_timer: float = 0.0
var block_reflect_damage_add: float = 0.0
var block_knockback_radius: float = 0.0
var block_knockback_force: float = 0.0
var block_bomb: bool = false
var block_bomb_damage: float = 0.0
var block_heal_zone: bool = false
var block_reflect: bool = true
var block_heal_pos: Vector2 = Vector2.ZERO
var block_heal_timer: float = 0.0
var block_heal_tick: float = 0.0
var block_cd_display_tenths: int = -1

# Rocket Leap (Ignis)
var is_leaping: bool = false
var leap_timer: float = 0.0
var leap_dir: Vector2 = Vector2.ZERO

# ZusÃƒÂ¤tzliche FÃƒÂ¤higkeits-ZustÃƒÂ¤nde fÃƒÂ¼r die neuen Klassen.
var ability_invuln_timer: float = 0.0            # Klinge (Klingensturm) / Phantom (Schattensprung)
var heal_field_timer: float = 0.0                # Bastion
var heal_field_tick: float = 0.0                 # Bastion
var gravity_wells: Array = []                    # Nova: aktive SingularitÃƒÂ¤ten

# Status Effects
var poison_ticks_left: int = 0
var poison_tick_timer: float = 0.0
var poison_damage_per_tick: float = 4.0
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var burn_ticks_left: int = 0
var burn_tick_timer: float = 0.0
var burn_damage_per_tick: float = 5.0
var shield_regen_timer: float = 0.0
var shield_regen_mult: float = 1.0
var hp_regen: float = 0.0
var hp_regen_timer: float = 0.0

# --- Temporäre Powerup-Effekte aus Kisten und Random-Spawns ---
var powerup_invuln_timer: float = 0.0
var powerup_damage_timer: float = 0.0
var powerup_damage_mult: float = 1.0
var powerup_rapid_fire_timer: float = 0.0

# Letzte Schadensquelle für Kill-Credit. Der Timer verhindert, dass ein lange
# zurückliegender Treffer einen späteren Umgebungstod gutschreibt.
var last_damage_source: Player = null
var last_damage_timer: float = 0.0

# Countdown: Eingaben sind erst nach dem Start-Countdown erlaubt.
var control_enabled: bool = true

# --- Talentbaum-Effekte ---
var tower_enabled: bool = false
var tower_auto_spawn: bool = false
var tower_follow: bool = false
var tower_spawn_timer: float = 5.0
var towers: Array[Companion] = []

var poison_impact_cloud: bool = false
var poison_trail: bool = false
var poison_trail_timer: float = 0.0

var lightning_shot: bool = false
var chain_lightning: bool = false
var lightning_zone: bool = false

var frost_nova: bool = false
var frost_trail: bool = false
var frost_trail_timer: float = 0.0

var cluster_bomblets: bool = false

var fire_shot: bool = false
var fire_impact_zone: bool = false
var fire_trail: bool = false
var fire_trail_timer: float = 0.0

var drone_count: int = 0
var drone_guardian: bool = false
var blocker_drone_count: int = 0
var blocker_drone_heal: bool = false
var drones: Array[Companion] = []

# EisflÃƒÂ¤chen: Quellen werden gezÃƒÂ¤hlt, damit angrenzende Eis-Tiles kein Flackern
# verursachen. Bewegungsbeschleunigung und Reibung werden auf Eis reduziert.
var ice_sources: Dictionary = {}
var on_ice: bool = false

# Opponent reference for AI / Homing
var opponent: Player = null
var aim_direction: Vector2 = Vector2.RIGHT

# --- Netzwerk ---
# Replica: wird auf dem Client nur aus Snapshots dargestellt, keine eigene Physik.
var is_replica: bool = false
# Remote: wird auf dem Host von der Eingabe des Clients gesteuert.
var is_remote: bool = false
var net_target_pos: Vector2 = Vector2.ZERO
var remote_input: Dictionary = {
	"move_x": 0.0,
	"jump": false,
	"jump_release": false,
	"shoot": false,
	"dash": false,
	"ability": false,
	"block": false,
	"aim": Vector2.RIGHT,
}

var bullet_scene = preload("res://scenes/player/bullet.tscn")
const EFFECT_CIRCLE_TEXTURE: Texture2D = preload("res://assets/projectiles/effect_circle.png")

func _ready() -> void:
	ghost_timer.timeout.connect(_spawn_ghost_trail)
	
	# Schildwabe fÃƒÂ¼r den universellen Block.
	shield_dome_node = Sprite2D.new()
	shield_dome_node.texture = EFFECT_CIRCLE_TEXTURE
	shield_dome_node.modulate = Color(0.3, 0.8, 1.0, 0.7)
	shield_dome_node.scale = Vector2(4.5, 4.5)
	shield_dome_node.visible = false
	add_child(shield_dome_node)
	
	if not Global.pig_appearance_changed.is_connected(_on_pig_appearance_changed):
		Global.pig_appearance_changed.connect(_on_pig_appearance_changed)

	apply_stats()
	
	if is_replica:
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)

func _process(delta: float) -> void:
	if not is_replica or not visible:
		return
	if global_position.distance_to(net_target_pos) > 250.0:
		global_position = net_target_pos
	else:
		global_position = global_position.lerp(net_target_pos, clampf(20.0 * delta, 0.0, 1.0))

func apply_stats() -> void:
	var hero_id: String = Global.get_player_hero_id(player_index)
	var hero: HeroData = Global.get_hero(hero_id)
	var card_list: Array = Global.get_player_cards(player_index)
	
	_apply_pig_appearance()
	
	ability_name = hero.ability_name
	ability_max_cooldown = hero.ability_cooldown
	
	# Basis-HP: Der Lobby-Prozent-Faktor skaliert den Heldenwert, damit die
	# Klassenunterschiede (z. B. Bastion 125 vs. Volt 85) erhalten bleiben.
	var base_hp: int = Global.get_effective_base_hp(hero)
	var base_shield = hero.base_shield
	var hp_mult = 1.0
	var hp_flat = 0
	var spd_mult = 1.0
	var jmp_mult = 1.0
	var grav_mult = 1.0
	var extra_jumps_total = hero.extra_jumps
	
	var dmg_mult = 1.0
	var b_spd_mult = 1.0
	var b_size_mult = 1.0
	var b_grav_mult = 1.0
	var fr_mult = 1.0
	var ammo_add = 0
	var dash_cd_mult = 1.0
	var ability_cd_mult = 1.0
	var reload_mult = 1.0
	var shield_regen_stack = 1.0
	var hp_regen_total = 0.0

	# Block-Modifikatoren aus Karten.
	var block_dur_add = 0.0
	var block_cd_mult = 1.0
	var block_kb_radius = 0.0
	var block_kb_force = 0.0
	var block_bomb_enabled = false
	var block_bomb_dmg = 0.0
	var block_heal_enabled = false
	var block_reflect_dmg_add = 0.0
	var size_mult = BASE_CHARACTER_SCALE
	var poison_dmg_mult = 1.0
	
	bounces = 0
	homing = 0.0
	explosion_radius = 0.0
	poison_stacks = 2 if hero.id == "spore" else 0
	freeze_duration = 0.0
	lifesteal_percent = 0.0
	multishot = 0
	spread_angle = 0.0
	piercing = 0
	kamikaze = false
	ricochet_bonus = 0.0

	# Talentbaum-Flags zurÃƒÂ¼cksetzen
	tower_enabled = false
	tower_auto_spawn = false
	tower_follow = false
	poison_impact_cloud = false
	poison_trail = false
	lightning_shot = false
	chain_lightning = false
	lightning_zone = false
	frost_nova = false
	frost_trail = false
	cluster_bomblets = false
	fire_shot = false
	fire_impact_zone = false
	fire_trail = false
	drone_count = 0
	drone_guardian = false
	blocker_drone_count = 0
	blocker_drone_heal = false
	
	# Stack Cards
	for c in card_list:
		hp_mult *= c.max_hp_mult
		hp_flat += c.max_hp_flat
		spd_mult *= c.move_speed_mult
		jmp_mult *= c.jump_force_mult
		grav_mult *= c.gravity_mult
		dmg_mult *= c.damage_mult
		b_spd_mult *= c.bullet_speed_mult
		b_size_mult *= c.bullet_size_mult
		b_grav_mult *= c.projectile_gravity_mult
		fr_mult *= c.fire_rate_mult
		ammo_add += c.max_ammo_add
		reload_mult *= c.reload_speed_mult
		dash_cd_mult *= c.dash_cooldown_mult
		ability_cd_mult *= c.ability_cooldown_mult
		shield_regen_stack *= c.shield_regen_mult
		extra_jumps_total += c.extra_jumps_add

		# Standard-Block verbessern.
		block_dur_add += c.block_duration_add
		block_cd_mult *= c.block_cooldown_mult
		block_kb_radius += c.block_knockback_radius_add
		block_kb_force += c.block_knockback_force_add
		block_reflect_dmg_add += c.block_reflect_damage_add
		if c.block_bomb:
			block_bomb_enabled = true
		block_bomb_dmg = maxf(block_bomb_dmg, c.block_bomb_damage)
		if c.block_heal_zone:
			block_heal_enabled = true
		base_shield += c.shield_max_add
		hp_regen_total += c.hp_regen_add
		bounces += c.bounces_add
		homing += c.homing_strength_add
		explosion_radius += c.explosion_radius_add
		poison_stacks += c.poison_stacks_add
		poison_dmg_mult *= c.poison_damage_mult
		freeze_duration += c.freeze_duration_add
		lifesteal_percent += c.lifesteal_percent_add
		multishot += c.multishot_add
		spread_angle += c.spread_angle_deg
		piercing += c.piercing_add
		size_mult *= c.body_size_mult
		size_mult *= 1.0 + c.giant_growth
		if c.kamikaze:
			kamikaze = true
		if c.id == "ricochet_frenzy":
			ricochet_bonus += 0.20

		# Talentbaum-Effekte
		if c.tower_enabled:
			tower_enabled = true
		if c.tower_auto_spawn:
			tower_auto_spawn = true
		if c.tower_follow:
			tower_follow = true
		if c.poison_impact_cloud:
			poison_impact_cloud = true
		if c.poison_trail:
			poison_trail = true
		if c.lightning_shot:
			lightning_shot = true
		if c.chain_lightning:
			chain_lightning = true
		if c.lightning_zone:
			lightning_zone = true
		if c.frost_nova:
			frost_nova = true
		if c.frost_trail:
			frost_trail = true
		if c.cluster_bomblets:
			cluster_bomblets = true
		if c.fire_shot:
			fire_shot = true
		if c.fire_impact_zone:
			fire_impact_zone = true
		if c.fire_trail:
			fire_trail = true
		drone_count += c.drone_count_add
		if c.drone_guardian:
			drone_guardian = true
		blocker_drone_count += c.blocker_drone_count_add
		if c.blocker_drone_heal:
			blocker_drone_heal = true
	
	max_health = (base_hp + hp_flat) * hp_mult
	current_health = max_health
	max_shield = base_shield
	current_shield = max_shield
	move_speed = hero.base_speed * spd_mult
	jump_force = hero.base_jump_force * jmp_mult
	gravity_mult = grav_mult
	max_jumps = 1 + extra_jumps_total
	jumps_remaining = max_jumps
	
	bullet_damage = Global.base_damage * dmg_mult
	bullet_speed = 650.0 * b_spd_mult
	bullet_size = 1.0 * b_size_mult
	projectile_gravity_mult = maxf(0.0, b_grav_mult)
	fire_rate_cooldown = maxf(0.08, hero.base_fire_rate_cooldown * fr_mult)
	max_ammo = maxi(1, hero.base_ammo + ammo_add)
	current_ammo = max_ammo
	dash_cooldown = maxf(0.5, 1.8 * dash_cd_mult)
	ability_max_cooldown = maxf(1.0, hero.ability_cooldown * ability_cd_mult)
	reload_time = hero.base_reload_time / maxf(0.1, reload_mult)
	shield_regen_mult = shield_regen_stack
	# Bastion-Passive "Aurora": doppelte Schild-Regeneration.
	if hero.id == "bastion":
		shield_regen_mult *= 2.0
	hp_regen = hp_regen_total

	# Universeller Block: Basiswerte plus Kartenboni. Dauer und Cooldown sind
	# gedeckelt, damit gestapelte Block-Karten nicht zu dauerhafter ImmunitÃƒÂ¤t fÃƒÂ¼hren.
	block_duration = clampf(BLOCK_BASE_DURATION + block_dur_add, 0.2, 1.5)
	block_cooldown = maxf(2.5, BLOCK_BASE_COOLDOWN * block_cd_mult)
	block_reflect_damage_add = block_reflect_dmg_add
	block_knockback_radius = block_kb_radius
	block_knockback_force = block_kb_force
	block_bomb = block_bomb_enabled
	block_bomb_damage = block_bomb_dmg if block_bomb_dmg > 0.0 else 30.0
	block_heal_zone = block_heal_enabled
	# Der Standard-Block reflektiert immer Projektile.
	block_reflect = true
	is_blocking = false
	block_timer = 0.0
	block_cooldown_timer = 0.0
	block_heal_timer = 0.0
	if shield_dome_node:
		shield_dome_node.visible = false
	hp_regen_timer = 0.0
	powerup_invuln_timer = 0.0
	powerup_damage_timer = 0.0
	powerup_damage_mult = 1.0
	powerup_rapid_fire_timer = 0.0
	poison_damage_per_tick = 4.0 * poison_dmg_mult

	tower_spawn_timer = 5.0
	poison_trail_timer = 0.0
	frost_trail_timer = 0.0
	fire_trail_timer = 0.0
	
	scale = Vector2(size_mult, size_mult)

	_clear_drones()
	_spawn_drones()
	
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("ability_cooldown_updated", 0.0, ability_max_cooldown)
	emit_signal("block_state_changed", false, 0.0, block_cooldown)

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	
	# Rocket Leap state (Ignis)
	if is_leaping:
		leap_timer -= delta
		velocity = leap_dir * 950.0
		_spawn_fire_sparks()
		var coll = move_and_collide(velocity * delta)
		if coll or leap_timer <= 0.0:
			is_leaping = false
			is_invulnerable = _has_temporary_invulnerability()
			_trigger_rocket_impact()
		return
	
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		return
	
	# Universeller Block: Schildwabe anzeigen und Projektile reflektieren.
	if is_blocking and shield_dome_node:
		shield_dome_node.visible = true
		shield_dome_node.rotation += delta * 8.0
		if block_reflect:
			for b in get_tree().get_nodes_in_group("bullet"):
				if is_instance_valid(b) and b.shooter != self and global_position.distance_to(b.global_position) < 60.0:
					if is_instance_valid(b.shooter) and b.shooter is Player and b.shooter.team_id == team_id:
						continue
					b.shooter = self
					b.target_enemy = _valid_opponent()
					b.velocity = -b.velocity * 1.3
					# Konterblitz-Karte: reflektierte Projektile werden stÃƒÂ¤rker.
					b.damage *= 1.0 + block_reflect_damage_add
					b.modulate = Color(0.75, 0.5, 1.0)
					SoundManager.play_sound("bounce", 0.3, 3.0)
	elif shield_dome_node:
		shield_dome_node.visible = false
	
	# Gravity & Movement
	if not is_on_floor():
		var grav := GRAVITY * gravity_mult
		# Wall sliding
		if is_on_wall() and velocity.y > 0 and (Input.is_action_pressed(_act("left")) or Input.is_action_pressed(_act("right"))):
			velocity.y = minf(velocity.y + (grav * 0.4) * delta, 150.0)
		else:
			velocity.y += grav * delta
	else:
		jumps_remaining = max_jumps
	
	# Input Handling. WÃƒÂ¤hrend des Start-Countdowns oder eines BetÃƒÂ¤ubungs-Effekts
	# werden keine Bewegungs-/Angriffseingaben verarbeitet.
	if control_enabled and stun_timer <= 0.0:
		if is_remote and not is_bot:
			_handle_remote_input(delta)
		elif not is_bot:
			_handle_player_input(delta)
	else:
		_apply_disabled_input()
		remote_input.jump = false
		remote_input.jump_release = false
		remote_input.dash = false
		remote_input.ability = false
		remote_input.block = false
		remote_input.shoot = false
	
	move_and_slide()
	
	# Aim pivot rotation
	weapon_pivot.rotation = aim_direction.angle()
	if abs(weapon_pivot.rotation) > PI / 2.0:
		gun_sprite.flip_v = true
		sprite.flip_h = true
	else:
		gun_sprite.flip_v = false
		sprite.flip_h = false

func _act(suffix: String) -> String:
	return "p1_" + suffix if player_index == 1 else "p2_" + suffix

func _apply_disabled_input() -> void:
	var current_spd = move_speed * (0.6 if freeze_timer > 0.0 else 1.0)
	var decel_factor := 0.015 if on_ice else 0.2
	velocity.x = move_toward(velocity.x, 0, current_spd * decel_factor)

func _handle_player_input(_delta: float) -> void:
	# Move X Ã¢â‚¬â€œ auf Eis wird deutlich langsamer beschleunigt und gebremst.
	var input_x = Input.get_axis(_act("left"), _act("right"))
	var current_spd = move_speed * (0.6 if freeze_timer > 0.0 else 1.0)
	var accel_factor := 0.06 if on_ice else 0.25
	var decel_factor := 0.015 if on_ice else 0.2
	if input_x != 0:
		velocity.x = move_toward(velocity.x, input_x * current_spd, current_spd * accel_factor)
	else:
		velocity.x = move_toward(velocity.x, 0, current_spd * decel_factor)
	
	# Jump
	if Input.is_action_just_pressed(_act("jump")):
		jump()
	
	# Cut jump short on release
	if Input.is_action_just_released(_act("jump")) and velocity.y < 0:
		velocity.y *= 0.5
	
	# Aim
	if player_index == 1:
		aim_direction = (get_global_mouse_position() - global_position).normalized()
	else:
		# P2 keyboard aim fallback
		var aim_x = Input.get_axis("p2_left", "p2_right")
		var aim_y = Input.get_axis("p2_up", "p2_down")
		if Vector2(aim_x, aim_y).length_squared() > 0.1:
			aim_direction = Vector2(aim_x, aim_y).normalized()
	
	# Dash
	if Input.is_action_just_pressed(_act("dash")):
		dash()
	
	# Shoot
	if Input.is_action_pressed(_act("shoot")):
		shoot()
	
	# Standard-Block (Q) Ã¢â‚¬â€œ fÃƒÂ¼r alle Spieler gleich.
	if Input.is_action_just_pressed(_act("block")):
		start_block()

	# KlassenfÃƒÂ¤higkeit (Rechtsklick / E / F).
	var ability_pressed = Input.is_action_just_pressed(_act("ability"))
	if player_index == 1:
		ability_pressed = ability_pressed or Input.is_action_just_pressed("p1_ability_alt") or Input.is_action_just_pressed("p1_ability_f")
	if ability_pressed:
		use_ability()

# --- Netzwerk-Eingabe / Replikation ---

func set_remote_input(data: Dictionary) -> void:
	remote_input.move_x = clampf(float(data.get("move_x", 0.0)), -1.0, 1.0)
	remote_input.shoot = bool(data.get("shoot", false))
	var aim_value = data.get("aim", Vector2.RIGHT)
	if aim_value is Vector2 and aim_value.length_squared() > 0.001:
		remote_input.aim = aim_value.normalized()
	if bool(data.get("jump", false)):
		remote_input.jump = true
	if bool(data.get("jump_release", false)):
		remote_input.jump_release = true
	if bool(data.get("dash", false)):
		remote_input.dash = true
	if bool(data.get("ability", false)):
		remote_input.ability = true
	if bool(data.get("block", false)):
		remote_input.block = true

# EisflÃƒÂ¤chen melden sich hier an/ab. Mehrere Quellen gleichzeitig (z. B. zwei
# angrenzende Eis-Tiles) werden gezÃƒÂ¤hlt.
func add_ice_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	ice_sources[source.get_instance_id()] = true
	on_ice = true

func remove_ice_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	ice_sources.erase(source.get_instance_id())
	on_ice = not ice_sources.is_empty()

func _handle_remote_input(_delta: float) -> void:
	var input_x: float = remote_input.move_x
	var current_spd = move_speed * (0.6 if freeze_timer > 0.0 else 1.0)
	var accel_factor := 0.06 if on_ice else 0.25
	var decel_factor := 0.015 if on_ice else 0.2
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * current_spd, current_spd * accel_factor)
	else:
		velocity.x = move_toward(velocity.x, 0, current_spd * decel_factor)
	
	if remote_input.jump:
		remote_input.jump = false
		jump()
	
	if remote_input.jump_release:
		remote_input.jump_release = false
		if velocity.y < 0.0:
			velocity.y *= 0.5
	
	aim_direction = remote_input.aim
	
	if remote_input.dash:
		remote_input.dash = false
		dash()
	
	if remote_input.shoot:
		shoot()
	
	if remote_input.block:
		remote_input.block = false
		start_block()

	if remote_input.ability:
		remote_input.ability = false
		use_ability()

# Wird auf dem Client pro Snapshot aufgerufen. Es wird keine Physik simuliert.
func apply_network_state(data: Dictionary) -> void:
	if data.is_empty():
		visible = false
		return
	
	visible = true
	net_target_pos = data.get("pos", net_target_pos)
	if global_position.distance_to(net_target_pos) > 250.0:
		global_position = net_target_pos
	
	velocity = data.get("vel", Vector2.ZERO)
	if data.get("fur") is Color and data.get("eyes") is Color and data.get("pants") is Color:
		sprite.setup(data["fur"], data["eyes"], data["pants"])
	max_health = float(data.get("max_hp", max_health))
	current_health = float(data.get("hp", current_health))
	max_shield = float(data.get("max_shield", max_shield))
	current_shield = float(data.get("shield", current_shield))
	max_ammo = int(data.get("max_ammo", max_ammo))
	current_ammo = int(data.get("ammo", current_ammo))
	ability_timer = float(data.get("ability", ability_timer))
	ability_max_cooldown = float(data.get("ability_max", ability_max_cooldown))
	is_reloading = bool(data.get("reload", is_reloading))
	reload_timer = float(data.get("reload_timer", reload_timer))
	reload_time = float(data.get("reload_time", reload_time))
	dash_cooldown_timer = float(data.get("dash_cd", dash_cooldown_timer))
	dash_cooldown = float(data.get("dash_cd_max", dash_cooldown))
	is_blocking = bool(data.get("blocking", is_blocking))
	block_cooldown_timer = float(data.get("block_cd", block_cooldown_timer))
	block_cooldown = float(data.get("block_cd_max", block_cooldown))
	powerup_invuln_timer = float(data.get("powerup_invuln", powerup_invuln_timer))
	powerup_damage_timer = float(data.get("powerup_damage", powerup_damage_timer))
	powerup_damage_mult = float(data.get("powerup_damage_mult", powerup_damage_mult))
	powerup_rapid_fire_timer = float(data.get("powerup_rapid", powerup_rapid_fire_timer))
	if powerup_invuln_timer > 0.0:
		is_invulnerable = true
	elif not is_dashing and not is_leaping and ability_invuln_timer <= 0.0:
		is_invulnerable = false
	
	var aim_value = data.get("aim", aim_direction)
	if aim_value is Vector2 and aim_value.length_squared() > 0.001:
		aim_direction = aim_value.normalized()
	
	weapon_pivot.rotation = aim_direction.angle()
	if abs(weapon_pivot.rotation) > PI / 2.0:
		gun_sprite.flip_v = true
		sprite.flip_h = true
	else:
		gun_sprite.flip_v = false
		sprite.flip_h = false
	
	if shield_dome_node:
		shield_dome_node.visible = is_blocking
		if is_blocking:
			shield_dome_node.modulate = _block_dome_color()
	
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	emit_signal("block_state_changed", is_blocking, block_cooldown_timer, block_cooldown)

func jump() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if is_on_floor():
		velocity.y = jump_force
		SoundManager.play_sound("click", 0.3, -4.0)
	elif is_on_wall():
		# Wall Jump
		var normal = get_wall_normal()
		velocity.y = jump_force * 0.95
		velocity.x = normal.x * move_speed * 1.1
		SoundManager.play_sound("click", 0.3, -4.0)
	elif jumps_remaining > 0:
		jumps_remaining -= 1
		velocity.y = jump_force * 0.9
		SoundManager.play_sound("click", 0.4, 0.0)

func apply_jump_pad_boost(force: float) -> void:
	velocity.y = force
	jumps_remaining = max_jumps

func dash() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if dash_cooldown_timer > 0.0 or is_dashing:
		return
	is_dashing = true
	is_invulnerable = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	# Dash in aim or movement direction
	if velocity.x != 0:
		dash_dir = Vector2(signf(velocity.x), 0.0)
	else:
		dash_dir = aim_direction.normalized()
	
	ghost_timer.start(0.04)
	
	# Ignis Passive: Afterburner fire sparks
	var hero_id: String = Global.get_player_hero_id(player_index)
	if hero_id == "ignis" and opponent and is_instance_valid(opponent):
		_spawn_fire_sparks()

func _spawn_ghost_trail() -> void:
	if not is_dashing:
		ghost_timer.stop()
		return
	var ghost := PigCharacter.new()
	ghost.setup(sprite.fur_color, sprite.eye_color, sprite.pants_color)
	ghost.animate = false
	ghost.follow_parent_motion = false
	ghost.scale = sprite.scale * scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.6)
	get_parent().add_child(ghost)
	ghost.global_position = sprite.global_position
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)

func _apply_pig_appearance() -> void:
	if sprite == null:
		return
	var look := Global.get_pig_appearance(player_index)
	sprite.setup(look["fur"], look["eyes"], look["pants"])

func _on_pig_appearance_changed(changed_index: int) -> void:
	if changed_index == player_index:
		_apply_pig_appearance()

func get_pig_colors() -> Dictionary:
	if sprite == null:
		return {}
	return {
		"fur": sprite.fur_color,
		"eyes": sprite.eye_color,
		"pants": sprite.pants_color,
	}

func shoot() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	var rapid_fire := powerup_rapid_fire_timer > 0.0
	if is_reloading and not rapid_fire:
		return
	if fire_timer > 0.0:
		return
	if current_ammo <= 0 and not rapid_fire:
		start_reload()
		return
	
	fire_timer = minf(0.09, fire_rate_cooldown) if rapid_fire else fire_rate_cooldown
	if not rapid_fire:
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, max_ammo)
	
	# Recoil Kickback
	var effective_damage := bullet_damage * powerup_damage_mult
	velocity -= aim_direction * (80.0 + effective_damage * 1.5)
	
	# Fire Projectiles (Base + Multishot)
	var total_bullets = 1 + multishot
	var base_angle = aim_direction.angle()
	var step_angle = deg_to_rad(spread_angle) / maxf(1.0, float(total_bullets - 1)) if total_bullets > 1 else 0.0
	var start_angle = base_angle - (deg_to_rad(spread_angle) / 2.0)
	
	for i in range(total_bullets):
		var angle = start_angle + (step_angle * i) if total_bullets > 1 else base_angle
		var dir = Vector2.from_angle(angle)
		_spawn_bullet(dir)
	
	SoundManager.play_sound("shoot", 0.2, 0.0)
	
	if current_ammo <= 0 and not rapid_fire:
		start_reload()

func _spawn_bullet(dir: Vector2) -> Bullet:
	var b: Bullet = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.velocity = dir * bullet_speed
	b.shooter = self
	b.target_enemy = _valid_opponent()
	b.damage = bullet_damage * powerup_damage_mult
	b.projectile_gravity_mult = projectile_gravity_mult
	b.bounces_left = bounces
	b.homing_strength = homing
	b.explosion_radius = explosion_radius
	b.poison_stacks = poison_stacks
	b.poison_damage = poison_damage_per_tick
	b.freeze_duration = freeze_duration
	b.lifesteal_percent = lifesteal_percent
	b.piercing_left = piercing
	b.ricochet_bonus = ricochet_bonus
	b.stun_duration = 0.1 if lightning_shot else 0.0
	b.poison_impact_cloud = poison_impact_cloud
	b.frost_nova = frost_nova
	b.chain_lightning = chain_lightning
	b.lightning_zone = lightning_zone
	b.cluster_bomblets = cluster_bomblets
	b.fire_shot = fire_shot
	b.fire_impact_zone = fire_impact_zone
	b.burn_stacks = 3 if fire_shot else 0
	b.burn_damage = burn_damage_per_tick
	b.scale = Vector2(bullet_size, bullet_size)
	Global.add_match_stat(player_index, "shots_fired", 1.0)
	
	# Projektile in der Heldenfarbe einfÃƒÂ¤rben (wichtig im FFA mit bis zu 6 Spielern).
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(player_index))
	b.modulate = hero.color_tint
	
	get_parent().add_child(b)
	return b

func start_reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time
	# Der letzte Schuss wurde bereits signalisiert, bevor der Nachladezustand
	# aktiv war. Ein zweites Signal aktualisiert die HUD-Anzeige auf "NACHLADEN".
	emit_signal("ammo_changed", current_ammo, max_ammo)
	SoundManager.play_sound("click", 0.1, -6.0)

func use_ability() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if ability_timer > 0.0:
		return
	ability_timer = ability_max_cooldown
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	var hero_id: String = Global.get_player_hero_id(player_index)
	match hero_id:
		"ignis":
			# Rocket Leap: Explosiver Katapultflug mit AOE-Einschlag
			SoundManager.play_sound("explosion", 0.2, 1.0)
			is_leaping = true
			is_invulnerable = true
			leap_timer = 0.32
			leap_dir = aim_direction.normalized()
			if leap_dir.length_squared() < 0.1:
				leap_dir = Vector2.UP
		"volt":
			# Flash Blink: Blitz-Teleport mit Schockwelle & BetÃƒÂ¤ubung
			_perform_flash_blink()
		"spore":
			# Toxic Gas Cloud: GroÃƒÅ¸e Giftwolke + 4 Sporen-Nadeln
			SoundManager.play_sound("poison", 0.3, 0.0)
			_spawn_spore_cloud()
		"nova":
			# SingularitÃƒÂ¤t: Gravitationskern, der Gegner heranzieht und schÃƒÂ¤digt
			_spawn_singularity()
		"klinge":
			# Klingensturm: Rundumschlag mit RÃƒÂ¼ckstoÃƒÅ¸ und kurzer Unverwundbarkeit
			_blade_storm()
		"bastion":
			# Heilfeld: Heilt ÃƒÂ¼ber Zeit und baut Schild auf
			_deploy_heal_field()
		"phantom":
			# Schattensprung: Teleport mit Treffer und kurzer Unverwundbarkeit
			_shadow_step()

	# Turm-Talent: Die SpezialfÃƒÂ¤higkeit platziert zusÃƒÂ¤tzlich einen Turm.
	if tower_enabled:
		_spawn_tower()

# ============================================================
# Standard-Block (Taste Q)
# ============================================================

func start_block() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if is_blocking or block_cooldown_timer > 0.0:
		return

	is_blocking = true
	block_timer = block_duration
	block_cooldown_timer = 0.0
	block_cd_display_tenths = -1
	if shield_dome_node:
		shield_dome_node.modulate = _block_dome_color()
		shield_dome_node.visible = true
	SoundManager.play_sound("shield", 0.2, 0.0)
	_trigger_block_effects()
	emit_signal("block_state_changed", true, block_cooldown_timer, block_cooldown)

func _end_block() -> void:
	is_blocking = false
	block_timer = 0.0
	# Der Cooldown beginnt erst nach dem Block, nicht schon beim Aktivieren.
	block_cooldown_timer = block_cooldown
	block_cd_display_tenths = -1
	if shield_dome_node:
		shield_dome_node.visible = false
	emit_signal("block_state_changed", false, block_cooldown_timer, block_cooldown)

# Karten-Effekte, die beim Aktivieren des Blocks ausgelÃƒÂ¶st werden.
func _trigger_block_effects() -> void:
	if block_knockback_radius > 0.0 and block_knockback_force > 0.0:
		for p in _opponents_within(global_position, block_knockback_radius):
			var dir: Vector2 = (p.global_position - global_position).normalized()
			p.apply_knockback(dir * block_knockback_force)
	if block_bomb:
		_spawn_block_bomb()
	if block_heal_zone:
		_spawn_block_heal_zone()

func _spawn_block_bomb() -> void:
	SoundManager.play_sound("explosion", 0.2, 1.0)
	var boom := Sprite2D.new()
	boom.texture = EFFECT_CIRCLE_TEXTURE
	boom.modulate = Color(1.0, 0.55, 0.15, 0.9)
	get_parent().add_child(boom)
	boom.global_position = global_position
	var tw := boom.create_tween()
	tw.tween_property(boom, "scale", Vector2(7.0, 7.0), 0.25)
	tw.parallel().tween_property(boom, "modulate:a", 0.0, 0.3)
	tw.tween_callback(boom.queue_free)
	for p in _opponents_within(global_position, 130.0):
		var dir: Vector2 = (p.global_position - global_position).normalized()
		p.take_damage(block_bomb_damage, dir * 480.0, self)

func _spawn_block_heal_zone() -> void:
	block_heal_pos = global_position
	block_heal_timer = 2.5
	block_heal_tick = 0.0
	var ring := Sprite2D.new()
	ring.texture = EFFECT_CIRCLE_TEXTURE
	ring.modulate = Color(0.35, 1.0, 0.55, 0.65)
	get_parent().add_child(ring)
	ring.global_position = block_heal_pos
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.3)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 2.5)
	tw.tween_callback(ring.queue_free)

# Wird auch von RÃƒÂ¼ckstoÃƒÅ¸-Karten genutzt; ein aktiver Block dÃƒÂ¤mpft den StoÃƒÅ¸.
func apply_knockback(force: Vector2) -> void:
	if is_blocking:
		force *= 0.2
	velocity += force

func _block_dome_color() -> Color:
	if block_reflect_damage_add > 0.0:
		return Color(0.75, 0.45, 1.0, 0.75)
	if block_bomb:
		return Color(1.0, 0.55, 0.2, 0.75)
	if block_knockback_radius > 0.0:
		return Color(0.4, 0.9, 1.0, 0.75)
	return Color(0.3, 0.8, 1.0, 0.7)

func _pulse_block_shield() -> void:
	SoundManager.play_sound("bounce", 0.2, 2.0)
	if shield_dome_node:
		var base_color := _block_dome_color()
		var tw := create_tween()
		tw.tween_property(shield_dome_node, "modulate", Color(2.0, 2.0, 2.0, 0.95), 0.05)
		tw.tween_property(shield_dome_node, "modulate", base_color, 0.1)

# Liefert nur einen gÃƒÂ¼ltigen, lebenden Gegner. Verhindert Zuweisungen an
# bereits freigegebene Player-Objekte (z. B. nach einem Tod).
func _valid_opponent() -> Player:
	if is_instance_valid(opponent) and opponent.current_health > 0.0 and opponent.team_id != team_id:
		return opponent
	return null

func _trigger_rocket_impact() -> void:
	SoundManager.play_sound("explosion", 0.2, -2.0)
	var shock = Sprite2D.new()
	shock.texture = EFFECT_CIRCLE_TEXTURE
	shock.modulate = Color(1.0, 0.4, 0.1, 0.9)
	get_parent().add_child(shock)
	shock.global_position = global_position
	var tw = shock.create_tween()
	tw.tween_property(shock, "scale", Vector2(9.0, 9.0), 0.3)
	tw.parallel().tween_property(shock, "modulate:a", 0.0, 0.3)
	tw.tween_callback(shock.queue_free)
	
	if opponent and is_instance_valid(opponent):
		for p in _opponents_within(global_position, 140.0):
			var dist = global_position.distance_to(p.global_position)
			var falloff = 1.0 - (dist / 140.0)
			p.take_damage(35.0 * falloff, (p.global_position - global_position).normalized() * 550.0, self)

func _perform_flash_blink() -> void:
	var start_pos = global_position
	var target_pos = _clamp_to_map(global_position + (aim_direction.normalized() * 260.0))
	
	var bolt = Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(1.0, 1.0, 0.3, 0.9)
	bolt.add_point(start_pos)
	bolt.add_point((start_pos + target_pos) * 0.5 + Vector2(randf_range(-15, 15), randf_range(-15, 15)))
	bolt.add_point(target_pos)
	get_parent().add_child(bolt)
	var tw = bolt.create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.2)
	tw.tween_callback(bolt.queue_free)
	
	global_position = target_pos
	velocity = Vector2.ZERO
	
	var shock = Sprite2D.new()
	shock.texture = EFFECT_CIRCLE_TEXTURE
	shock.modulate = Color(1.0, 1.0, 0.2, 0.9)
	get_parent().add_child(shock)
	shock.global_position = target_pos
	var tw2 = shock.create_tween()
	tw2.tween_property(shock, "scale", Vector2(7.0, 7.0), 0.25)
	tw2.parallel().tween_property(shock, "modulate:a", 0.0, 0.25)
	tw2.tween_callback(shock.queue_free)
	
	for p in _opponents_within(target_pos, 120.0):
		p.take_damage(20.0, (p.global_position - target_pos).normalized() * 300.0, self)
		p.apply_freeze(1.2)

func _spawn_fire_sparks() -> void:
	var spark = Sprite2D.new()
	spark.texture = EFFECT_CIRCLE_TEXTURE
	spark.modulate = Color(1.0, 0.4, 0.1, 0.8)
	get_parent().add_child(spark)
	spark.global_position = global_position
	var tw = spark.create_tween()
	tw.tween_property(spark, "scale", Vector2(2.0, 2.0), 0.3)
	tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spark.queue_free)

func _spawn_spore_cloud() -> void:
	var cloud = Area2D.new()
	cloud.collision_layer = 4
	cloud.collision_mask = 2
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 45.0
	col.shape = shape
	cloud.add_child(col)
	
	var cloud_sprite = Sprite2D.new()
	cloud_sprite.texture = EFFECT_CIRCLE_TEXTURE
	cloud_sprite.modulate = Color(0.3, 0.9, 0.2, 0.5)
	cloud_sprite.scale = Vector2(7.0, 7.0)
	cloud.add_child(cloud_sprite)
	
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	
	var t = cloud.create_tween()
	t.tween_method(func(_val: float):
		for p in _opponents_within(cloud.global_position, 45.0):
			p.take_damage(0.15, Vector2.ZERO, self)
	, 0.0, 1.0, 3.5)
	t.parallel().tween_property(cloud_sprite, "modulate:a", 0.0, 3.5)
	t.tween_callback(cloud.queue_free)

# Liefert alle lebenden Gegner im Umkreis. Wichtig fÃƒÂ¼r FFA-Runden mit bis zu 6
# Spielern, damit FlÃƒÂ¤chenfÃƒÂ¤higkeiten nicht nur den ersten Gegner treffen.
func _opponents_within(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p) or p.current_health <= 0.0:
			continue
		if p.team_id == team_id:
			continue
		if pos.distance_to(p.global_position) <= radius:
			result.append(p)
	return result

# --- Nova: SingularitÃƒÂ¤t ---
func _spawn_singularity() -> void:
	SoundManager.play_sound("explosion", 0.2, 2.0)
	var center := global_position + aim_direction.normalized() * 220.0
	center = _clamp_to_map(center)
	var core := Sprite2D.new()
	core.texture = EFFECT_CIRCLE_TEXTURE
	core.modulate = Color(0.6, 0.4, 1.0, 0.9)
	get_parent().add_child(core)
	core.global_position = center
	var tw = core.create_tween()
	tw.tween_property(core, "scale", Vector2(5.5, 5.5), 0.3)
	tw.parallel().tween_property(core, "rotation", TAU, 1.4)
	tw.tween_interval(1.0)
	tw.tween_property(core, "modulate:a", 0.0, 0.4)
	tw.tween_callback(core.queue_free)
	gravity_wells.append({"pos": center, "time": 1.6, "tick": 0.0})

# --- Klinge: Klingensturm ---
func _blade_storm() -> void:
	SoundManager.play_sound("hit", 0.3, 2.0)
	is_invulnerable = true
	ability_invuln_timer = maxf(ability_invuln_timer, 0.5)
	var spin := Sprite2D.new()
	spin.texture = EFFECT_CIRCLE_TEXTURE
	spin.modulate = Color(1.0, 0.35, 0.55, 0.85)
	get_parent().add_child(spin)
	spin.global_position = global_position
	var tw = spin.create_tween()
	tw.tween_property(spin, "scale", Vector2(6.5, 6.5), 0.25)
	tw.parallel().tween_property(spin, "rotation", TAU * 2.0, 0.25)
	tw.parallel().tween_property(spin, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spin.queue_free)
	for p in _opponents_within(global_position, 135.0):
		p.take_damage(bullet_damage * 1.2, (p.global_position - global_position).normalized() * 520.0, self)

# --- Bastion: Heilfeld ---
func _deploy_heal_field() -> void:
	SoundManager.play_sound("confirm", 0.3, 0.0)
	heal_field_timer = 4.0
	heal_field_tick = 0.0
	var ring := Sprite2D.new()
	ring.texture = EFFECT_CIRCLE_TEXTURE
	ring.modulate = Color(0.3, 0.95, 0.7, 0.7)
	get_parent().add_child(ring)
	ring.global_position = global_position
	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.4)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 4.0)
	tw.tween_callback(ring.queue_free)

# --- Phantom: Schattensprung ---
func _shadow_step() -> void:
	var start := global_position
	var target := _clamp_to_map(global_position + aim_direction.normalized() * 260.0)
	var trail_bolt := Line2D.new()
	trail_bolt.width = 6.0
	trail_bolt.default_color = Color(0.45, 0.45, 0.65, 0.7)
	trail_bolt.add_point(start)
	trail_bolt.add_point(target)
	get_parent().add_child(trail_bolt)
	var tw = trail_bolt.create_tween()
	tw.tween_property(trail_bolt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(trail_bolt.queue_free)
	global_position = target
	velocity = Vector2.ZERO
	is_invulnerable = true
	ability_invuln_timer = maxf(ability_invuln_timer, 0.9)
	for p in _opponents_within(target, 120.0):
		p.take_damage(bullet_damage * 1.1, (p.global_position - target).normalized() * 320.0, self)

# Begrenzt eine Weltposition auf den spielbaren Kartenbereich.
func _clamp_to_map(pos: Vector2) -> Vector2:
	var map_w := float(LevelGenerator.MAP_WIDTH) * LevelGenerator.TILE_SIZE
	var map_h := float(LevelGenerator.MAP_HEIGHT) * LevelGenerator.TILE_SIZE
	return Vector2(clampf(pos.x, 60.0, map_w - 60.0), clampf(pos.y, 60.0, map_h - 60.0))

func _flash_effect() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 1.0), 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, source = null) -> void:
	# In Team-Modi gibt es kein Freundschaftsfeuer. Das gilt auch für
	# Flächenfähigkeiten und Explosionen, deren Quelle ein Spieler ist.
	if is_instance_valid(source) and source is Player and source != self and source.team_id == team_id:
		return
	# Dash, Sprung und kurze FÃƒÂ¤higkeits-Unverwundbarkeit negieren Schaden komplett.
	if is_invulnerable:
		SoundManager.play_sound("bounce", 0.2, 2.0)
		return

	# Universeller Block verhindert Schaden vollstÃƒÂ¤ndig; Projektile werden in
	# der Physik-Schleife reflektiert.
	if is_blocking:
		Global.add_match_stat(player_index, "damage_blocked", amount)
		Global.add_match_stat(player_index, "blocked_hits", 1.0)
		Global.shake_camera(0.16)
		_pulse_block_shield()
		return
	
	shield_regen_timer = 3.5
	hp_regen_timer = 3.0
	# Die Schadensquelle kann inzwischen freigegeben sein (z. B. ein bereits
	# zerstörter Schütze oder eine alte Flächeneffekt-Zone). Deshalb erst
	# validieren und dann als Kill-Credit übernehmen.
	if is_instance_valid(source) and source != self and source is Player:
		last_damage_source = source
		last_damage_timer = 8.0

	var effective_damage := minf(amount, current_shield + maxf(current_health, 0.0))
	var damage_source_index := 0
	if is_instance_valid(source) and source is Player and source != self:
		damage_source_index = source.player_index
	
	# Shield absorption
	if current_shield > 0.0:
		if current_shield >= amount:
			current_shield -= amount
			amount = 0.0
		else:
			amount -= current_shield
			current_shield = 0.0
	
	current_health -= amount
	velocity += knockback

	if effective_damage > 0.0:
		Global.add_match_stat(player_index, "damage_taken", effective_damage)
		if damage_source_index > 0:
			Global.add_match_stat(damage_source_index, "damage_dealt", effective_damage)
		Global.shake_camera(clampf(effective_damage * 0.008, 0.06, 0.45))
	
	_flash_hit()
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	
	if current_health <= 0.0:
		_die()

func _flash_hit() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.RED, 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func heal(amount: float) -> void:
	var before := current_health
	current_health = minf(current_health + amount, max_health)
	var healed := current_health - before
	if healed > 0.0:
		Global.add_match_stat(player_index, "healing_done", healed)
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.GREEN, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func apply_powerup(kind: String) -> void:
	if current_health <= 0.0:
		return
	match kind:
		"heal":
			heal(35.0)
			_flash_powerup(Color(0.45, 1.0, 0.55, 1.0))
		"invulnerability":
			powerup_invuln_timer = maxf(powerup_invuln_timer, 3.0)
			is_invulnerable = true
			_flash_powerup(Color(0.45, 0.78, 1.0, 1.0))
		"damage":
			powerup_damage_timer = maxf(powerup_damage_timer, 6.0)
			powerup_damage_mult = maxf(powerup_damage_mult, 1.65)
			_flash_powerup(Color(1.0, 0.45, 0.25, 1.0))
		"rapid_fire":
			powerup_rapid_fire_timer = maxf(powerup_rapid_fire_timer, 5.0)
			is_reloading = false
			reload_timer = 0.0
			current_ammo = maxi(current_ammo, 1)
			emit_signal("ammo_changed", current_ammo, max_ammo)
			_flash_powerup(Color(1.0, 0.86, 0.3, 1.0))

func _flash_powerup(flash_color: Color) -> void:
	if not is_instance_valid(sprite):
		return
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", flash_color, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func apply_poison(stacks: int, damage_per_tick: float = 4.0) -> void:
	# StÃƒÂ¤rkeres Gift ÃƒÂ¼berschreibt schwÃƒÂ¤cheres, schwÃƒÂ¤cheres Gift verlÃƒÂ¤ngert nur.
	poison_damage_per_tick = maxf(poison_damage_per_tick, damage_per_tick)
	poison_ticks_left = maxi(poison_ticks_left, stacks)

func apply_freeze(duration: float) -> void:
	freeze_timer = maxf(freeze_timer, duration)

func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)

func apply_burn(stacks: int, damage_per_tick: float = 5.0) -> void:
	burn_ticks_left = maxi(burn_ticks_left, stacks)
	burn_damage_per_tick = maxf(burn_damage_per_tick, damage_per_tick)

# Kurzes Aufblinken des eigenen Charakters beim Rundenstart.
func flash_intro() -> void:
	if not is_instance_valid(sprite):
		return
	var tw = create_tween()
	for i in range(3):
		tw.tween_property(sprite, "modulate", Color(2.2, 2.2, 0.8, 0.35), 0.10)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.10)

# --- Talentbaum: TÃƒÂ¼rme und Drohnen ---

func _clear_drones() -> void:
	for drone in drones:
		if is_instance_valid(drone):
			drone.queue_free()
	drones.clear()

func _spawn_drones() -> void:
	for i in range(drone_count):
		var drone := Companion.new()
		drone.mode = Companion.Mode.DRONE
		drone.owner_player = self
		drone.target_enemy = _valid_opponent()
		drone.support = drone_guardian
		drone.is_replica = is_replica
		drone.orbit_radius = 48.0 + float(i) * 16.0
		drone.orbit_speed = 1.5 + float(i) * 0.25
		add_child(drone)
		drones.append(drone)

	# Schutzdrohnen bilden einen eigenen, weiter außen liegenden Ring. Sie
	# schießen nicht, sondern fangen Projektile ab.
	for i in range(blocker_drone_count):
		var blocker := Companion.new()
		blocker.mode = Companion.Mode.DRONE
		blocker.owner_player = self
		blocker.is_replica = is_replica
		blocker.blocks_projectiles = true
		blocker.block_heals_owner = blocker_drone_heal
		blocker.orbit_radius = 66.0 + float(i) * 16.0
		blocker.orbit_speed = 1.7 + float(i) * 0.22
		add_child(blocker)
		drones.append(blocker)

func _spawn_tower() -> void:
	if is_replica:
		return
	var valid_towers: Array[Companion] = []
	for tower in towers:
		if is_instance_valid(tower):
			valid_towers.append(tower)
	towers = valid_towers
	if towers.size() >= 8:
		return

	var tower := Companion.new()
	tower.mode = Companion.Mode.TOWER
	tower.owner_player = self
	tower.target_enemy = _valid_opponent()
	tower.follow_owner = tower_follow
	tower.is_replica = false
	get_parent().add_child(tower)
	tower.global_position = global_position
	towers.append(tower)

# --- Talentbaum: FlÃƒÂ¤cheneffekte ---

func spawn_effect_zone(kind: int, pos: Vector2, radius: float, duration: float, params: Dictionary = {}) -> void:
	if is_replica:
		return
	var zone := EffectZone.new()
	zone.kind = kind
	zone.owner_player = self
	zone.target = _valid_opponent()
	zone.radius = radius
	zone.duration = duration
	zone.tick_interval = float(params.get("tick_interval", 0.55))
	zone.damage = float(params.get("damage", 0.0))
	zone.poison_stacks = int(params.get("poison_stacks", 2))
	zone.poison_damage = float(params.get("poison_damage", 4.0))
	zone.burn_stacks = int(params.get("burn_stacks", 3))
	zone.burn_damage = float(params.get("burn_damage", 5.0))
	zone.freeze_duration = float(params.get("freeze_duration", 1.2))
	zone.stun_duration = float(params.get("stun_duration", 0.25))
	get_parent().add_child(zone)
	zone.global_position = pos

	if Global.network_mode and NetworkManager.is_host:
		NetworkManager.send_zone_spawn({
			"kind": kind,
			"pos": pos,
			"radius": radius,
			"duration": duration,
			"tick_interval": zone.tick_interval,
			"damage": zone.damage,
			"poison_stacks": zone.poison_stacks,
			"poison_damage": zone.poison_damage,
			"burn_stacks": zone.burn_stacks,
			"burn_damage": zone.burn_damage,
			"freeze_duration": zone.freeze_duration,
			"stun_duration": zone.stun_duration,
			"owner_index": player_index,
		})

func spawn_network_zone(data: Dictionary) -> void:
	var zone := EffectZone.new()
	zone.is_replica = true
	zone.kind = int(data.get("kind", EffectZone.Kind.POISON))
	zone.radius = float(data.get("radius", 40.0))
	zone.duration = float(data.get("duration", 2.0))
	zone.tick_interval = float(data.get("tick_interval", 0.55))
	get_parent().add_child(zone)
	zone.global_position = data.get("pos", global_position)

func spawn_poison_cloud(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.POISON, pos, 52.0, 3.2, {
		"tick_interval": 0.55,
		"poison_stacks": 1,
		"poison_damage": poison_damage_per_tick,
	})

func spawn_fire_zone(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.FIRE, pos, 56.0, 3.0, {
		"tick_interval": 0.5,
		"burn_stacks": 1,
		"burn_damage": burn_damage_per_tick,
	})

func spawn_frost_nova(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.ICE, pos, 66.0, 0.9, {
		"tick_interval": 0.2,
		"freeze_duration": 1.4,
	})

func spawn_lightning_zone(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.LIGHTNING, pos, 52.0, 4.0, {
		"tick_interval": 0.45,
		"damage": 2.5,
		"stun_duration": 0.25,
	})

func _spawn_trail_zone(kind: int) -> void:
	var behind_x := -signf(velocity.x) * 18.0
	var pos := global_position + Vector2(behind_x, 10.0)
	match kind:
		EffectZone.Kind.POISON:
			spawn_effect_zone(kind, pos, 30.0, 2.2, {
				"tick_interval": 0.45,
				"poison_stacks": 1,
				"poison_damage": poison_damage_per_tick,
			})
		EffectZone.Kind.FIRE:
			spawn_effect_zone(kind, pos, 32.0, 2.0, {
				"tick_interval": 0.45,
				"burn_stacks": 1,
				"burn_damage": burn_damage_per_tick,
			})
		EffectZone.Kind.ICE:
			spawn_effect_zone(kind, pos, 30.0, 2.5, {
				"tick_interval": 0.3,
				"freeze_duration": 1.0,
			})

func trigger_chain_lightning(primary: Player, from_position: Vector2) -> void:
	if is_replica:
		return
	var chain_target: Player = null
	for p in get_tree().get_nodes_in_group("player"):
		if p != self and p != primary and p.team_id != team_id and is_instance_valid(p) and p.current_health > 0.0:
			chain_target = p
			break
	if chain_target == null and is_instance_valid(primary) and primary.current_health > 0.0:
		# Im 1-gegen-1 springt der Kettenblitz auf das PrimÃƒÂ¤rziel zurÃƒÂ¼ck.
		chain_target = primary
	if chain_target == null:
		return

	chain_target.take_damage(bullet_damage * 0.45, Vector2.ZERO, self)
	chain_target.apply_stun(0.1)
	_spawn_lightning_arc(from_position, chain_target.global_position)

func _spawn_lightning_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	var bolt := Line2D.new()
	bolt.width = 3.0
	bolt.default_color = Color(1.0, 0.95, 0.3, 0.95)
	bolt.add_point(from_pos)
	bolt.add_point((from_pos + to_pos) * 0.5 + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0)))
	bolt.add_point(to_pos)
	get_parent().add_child(bolt)
	var tw = bolt.create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, 0.18)
	tw.tween_callback(bolt.queue_free)

func spawn_cluster_bomblets(pos: Vector2) -> void:
	if is_replica:
		return
	for i in range(4):
		var dir := Vector2.from_angle((TAU / 4.0) * float(i) + randf_range(-0.25, 0.25))
		var b: Bullet = bullet_scene.instantiate()
		b.shooter = self
		b.target_enemy = _valid_opponent()
		b.damage = bullet_damage * 0.40
		b.projectile_gravity_mult = projectile_gravity_mult
		b.velocity = dir * bullet_speed * 0.65
		b.bounces_left = 1
		b.explosion_radius = 18.0
		b.max_lifetime = 1.4
		b.scale = Vector2(0.7, 0.7)
		b.modulate = Color(1.0, 0.65, 0.15)
		get_parent().add_child(b)
		b.global_position = pos + dir * 2.0

func _die() -> void:
	if kamikaze:
		_trigger_kamikaze()
	SoundManager.play_sound("hit", 0.3, -4.0)
	Global.shake_camera(0.5)
	emit_signal("died", player_index)
	queue_free()

func _trigger_kamikaze() -> void:
	SoundManager.play_sound("explosion", 0.2, 0.0)
	for p in _opponents_within(global_position, 160.0):
		var dist = global_position.distance_to(p.global_position)
		var falloff = 1.0 - (dist / 160.0)
		p.take_damage(65.0 * falloff, (p.global_position - global_position).normalized() * 500.0, self)

func _has_temporary_invulnerability() -> bool:
	return is_dashing or is_leaping or ability_invuln_timer > 0.0 or powerup_invuln_timer > 0.0

func _handle_timers(delta: float) -> void:
	if last_damage_timer > 0.0:
		last_damage_timer -= delta
		if last_damage_timer <= 0.0:
			last_damage_source = null

	if fire_timer > 0.0:
		fire_timer -= delta
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
			emit_signal("ammo_changed", current_ammo, max_ammo)
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = _has_temporary_invulnerability()
	
	if ability_timer > 0.0:
		ability_timer -= delta
		if ability_timer <= 0.0:
			ability_timer = 0.0
			emit_signal("ability_cooldown_updated", 0.0, ability_max_cooldown)
		else:
			emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	# Standard-Block: Dauer und Cooldown verwalten.
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			_end_block()
	if block_cooldown_timer > 0.0:
		block_cooldown_timer = maxf(0.0, block_cooldown_timer - delta)
	# HUD nur ~10x pro Sekunde aktualisieren, nicht jeden Frame.
	var block_tenths := int(ceil(block_cooldown_timer * 10.0))
	if block_tenths != block_cd_display_tenths:
		block_cd_display_tenths = block_tenths
		emit_signal("block_state_changed", is_blocking, block_cooldown_timer, block_cooldown)

	# Heilzone aus dem Block-Kartenpfad.
	if block_heal_timer > 0.0:
		block_heal_timer -= delta
		block_heal_tick -= delta
		if block_heal_tick <= 0.0:
			block_heal_tick = 0.5
			if global_position.distance_to(block_heal_pos) <= 110.0:
				heal(6.0)

	# Kurze Unverwundbarkeit durch Klingensturm / Schattensprung.
	if ability_invuln_timer > 0.0:
		ability_invuln_timer -= delta
		if ability_invuln_timer <= 0.0 and not is_dashing and not is_leaping:
			is_invulnerable = _has_temporary_invulnerability()

	if powerup_invuln_timer > 0.0:
		powerup_invuln_timer = maxf(0.0, powerup_invuln_timer - delta)
		if powerup_invuln_timer <= 0.0:
			is_invulnerable = _has_temporary_invulnerability()

	if powerup_damage_timer > 0.0:
		powerup_damage_timer = maxf(0.0, powerup_damage_timer - delta)
		if powerup_damage_timer <= 0.0:
			powerup_damage_mult = 1.0

	if powerup_rapid_fire_timer > 0.0:
		powerup_rapid_fire_timer = maxf(0.0, powerup_rapid_fire_timer - delta)

	# Bastion-Heilfeld: heilt und lÃƒÂ¤dt Schild ÃƒÂ¼ber einige Sekunden auf.
	if heal_field_timer > 0.0:
		heal_field_timer -= delta
		heal_field_tick -= delta
		if heal_field_tick <= 0.0:
			heal_field_tick = 0.5
			heal(8.0)
			if max_shield > 0.0 and current_shield < max_shield:
				current_shield = minf(current_shield + 10.0, max_shield)
				emit_signal("health_changed", current_health, max_health, current_shield, max_shield)

	# Nova-SingularitÃƒÂ¤ten: ziehen Gegner heran und schÃƒÂ¤digen sie.
	if not gravity_wells.is_empty():
		for i in range(gravity_wells.size() - 1, -1, -1):
			var well: Dictionary = gravity_wells[i]
			well["time"] = float(well["time"]) - delta
			well["tick"] = float(well["tick"]) - delta
			var well_pos: Vector2 = well["pos"]
			for p in _opponents_within(well_pos, 250.0):
				var to_center: Vector2 = well_pos - p.global_position
				if to_center.length() > 10.0:
					p.velocity += to_center.normalized() * 900.0 * delta
			if float(well["tick"]) <= 0.0:
				well["tick"] = 0.35
				for p in _opponents_within(well_pos, 130.0):
					p.take_damage(6.0)
			if float(well["time"]) <= 0.0:
				gravity_wells.remove_at(i)
	
	if freeze_timer > 0.0:
		freeze_timer -= delta

	if stun_timer > 0.0:
		stun_timer -= delta
	
	# Poison ticks
	if poison_ticks_left > 0:
		poison_tick_timer += delta
		if poison_tick_timer >= 0.8:
			poison_tick_timer = 0.0
			poison_ticks_left -= 1
			take_damage(poison_damage_per_tick)
			SoundManager.play_sound("poison", 0.2, 2.0)

	# Brennschaden
	if burn_ticks_left > 0:
		burn_tick_timer += delta
		if burn_tick_timer >= 0.6:
			burn_tick_timer = 0.0
			burn_ticks_left -= 1
			take_damage(burn_damage_per_tick)

	# Turm-Talent: automatisch neue TÃƒÂ¼rme erzeugen.
	if tower_enabled and tower_auto_spawn:
		tower_spawn_timer -= delta
		if tower_spawn_timer <= 0.0:
			tower_spawn_timer = 5.0
			_spawn_tower()

	# Spuren nur beim Bewegen auf dem Boden erzeugen.
	var moving_on_ground := is_on_floor() and absf(velocity.x) > 35.0
	if poison_trail:
		if moving_on_ground:
			poison_trail_timer -= delta
			if poison_trail_timer <= 0.0:
				poison_trail_timer = 0.55
				_spawn_trail_zone(EffectZone.Kind.POISON)
		else:
			poison_trail_timer = minf(poison_trail_timer, 0.1)

	if fire_trail:
		if moving_on_ground:
			fire_trail_timer -= delta
			if fire_trail_timer <= 0.0:
				fire_trail_timer = 0.50
				_spawn_trail_zone(EffectZone.Kind.FIRE)
		else:
			fire_trail_timer = minf(fire_trail_timer, 0.1)

	if frost_trail:
		if moving_on_ground:
			frost_trail_timer -= delta
			if frost_trail_timer <= 0.0:
				frost_trail_timer = 0.70
				_spawn_trail_zone(EffectZone.Kind.ICE)
		else:
			frost_trail_timer = minf(frost_trail_timer, 0.1)
	
	# HP-Regeneration: erst nach 3s ohne Schaden, dann kontinuierlich.
	if hp_regen_timer > 0.0:
		hp_regen_timer -= delta
	elif hp_regen > 0.0 and current_health > 0.0 and current_health < max_health:
		current_health = minf(current_health + hp_regen * delta, max_health)
		emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	
	# Shield passive regeneration
	if shield_regen_timer > 0.0:
		shield_regen_timer -= delta
	elif current_shield < max_shield:
		current_shield = minf(current_shield + (15.0 * shield_regen_mult * delta), max_shield)
		emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
