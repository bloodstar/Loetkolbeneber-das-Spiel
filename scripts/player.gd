class_name Player
extends CharacterBody2D

signal died(player_index: int)
signal health_changed(current: float, max_h: float, shield: float, max_s: float)
signal ammo_changed(current: int, max_a: int)
signal ability_cooldown_updated(current: float, max_c: float)

@export var player_index: int = 1
@export var is_bot: bool = false

# Grundgröße der Spielfigur. Karten mit body_size_mult/giant_growth wirken
# zusätzlich auf diesen Wert.
const BASE_CHARACTER_SCALE: float = 1.5

# Nodes
@onready var sprite: Sprite2D = $Sprite2D
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
var max_jumps: int = 1
var jumps_remaining: int = 1

# Bullet Stats
var bullet_damage: float = 22.0
var bullet_speed: float = 650.0
var bullet_size: float = 1.0
var fire_rate_cooldown: float = 0.35
var fire_timer: float = 0.0
var max_ammo: int = 5
var current_ammo: int = 5
var reload_time: float = 1.0
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
var is_barrier_active: bool = false
var barrier_duration_timer: float = 0.0
var shield_dome_node: Sprite2D = null

# Rocket Leap (Ignis)
var is_leaping: bool = false
var leap_timer: float = 0.0
var leap_dir: Vector2 = Vector2.ZERO

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
var barrier_duration_add: float = 0.0

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
var drones: Array[Companion] = []

# Eisflächen: Quellen werden gezählt, damit angrenzende Eis-Tiles kein Flackern
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
	"aim": Vector2.RIGHT,
}

var bullet_scene = preload("res://scenes/player/bullet.tscn")

func _ready() -> void:
	ghost_timer.timeout.connect(_spawn_ghost_trail)
	
	# Shield Dome for Titan
	shield_dome_node = Sprite2D.new()
	shield_dome_node.texture = load("res://assets/projectiles/tile_0000.png")
	shield_dome_node.modulate = Color(0.2, 0.7, 1.0, 0.6)
	shield_dome_node.scale = Vector2(4.5, 4.5)
	shield_dome_node.visible = false
	add_child(shield_dome_node)
	
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
	var hero_id = Global.p1_hero_id if player_index == 1 else Global.p2_hero_id
	var hero: HeroData = Global.get_hero(hero_id)
	var card_list = Global.p1_cards if player_index == 1 else Global.p2_cards
	
	# Load hero sprite
	var tex_path = "res://assets/characters/" + hero.sprite_tile_name
	if ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
	
	ability_name = hero.ability_name
	ability_max_cooldown = hero.ability_cooldown
	
	# Base Stats. Eine Lobby-Einstellung kann die heldenspezifischen Basis-HP
	# überschreiben; 0 bedeutet, dass der Heldenwert verwendet wird.
	var base_hp: int = Global.base_hp_override if Global.base_hp_override > 0 else hero.base_hp
	var base_shield = hero.base_shield
	var hp_mult = 1.0
	var hp_flat = 0
	var spd_mult = 1.0
	var jmp_mult = 1.0
	var extra_jumps_total = hero.extra_jumps
	
	var dmg_mult = 1.0
	var b_spd_mult = 1.0
	var b_size_mult = 1.0
	var fr_mult = 1.0
	var ammo_add = 0
	var dash_cd_mult = 1.0
	var ability_cd_mult = 1.0
	var reload_mult = 1.0
	var shield_regen_stack = 1.0
	var barrier_add = 0.0
	var hp_regen_total = 0.0
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

	# Talentbaum-Flags zurücksetzen
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
	
	# Stack Cards
	for c in card_list:
		hp_mult *= c.max_hp_mult
		hp_flat += c.max_hp_flat
		spd_mult *= c.move_speed_mult
		jmp_mult *= c.jump_force_mult
		dmg_mult *= c.damage_mult
		b_spd_mult *= c.bullet_speed_mult
		b_size_mult *= c.bullet_size_mult
		fr_mult *= c.fire_rate_mult
		ammo_add += c.max_ammo_add
		reload_mult *= c.reload_speed_mult
		dash_cd_mult *= c.dash_cooldown_mult
		ability_cd_mult *= c.ability_cooldown_mult
		shield_regen_stack *= c.shield_regen_mult
		barrier_add += c.barrier_duration_add
		extra_jumps_total += c.extra_jumps_add
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
	
	max_health = (base_hp + hp_flat) * hp_mult
	current_health = max_health
	max_shield = base_shield
	current_shield = max_shield
	move_speed = hero.base_speed * spd_mult
	jump_force = hero.base_jump_force * jmp_mult
	max_jumps = 1 + extra_jumps_total
	jumps_remaining = max_jumps
	
	bullet_damage = 22.0 * dmg_mult
	bullet_speed = 650.0 * b_spd_mult
	bullet_size = 1.0 * b_size_mult
	fire_rate_cooldown = maxf(0.08, 0.35 * fr_mult)
	max_ammo = 5 + ammo_add
	current_ammo = max_ammo
	dash_cooldown = maxf(0.5, 1.8 * dash_cd_mult)
	ability_max_cooldown = maxf(1.0, hero.ability_cooldown * ability_cd_mult)
	reload_time = 1.0 / maxf(0.1, reload_mult)
	shield_regen_mult = shield_regen_stack
	barrier_duration_add = barrier_add
	hp_regen = hp_regen_total
	hp_regen_timer = 0.0
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
			is_invulnerable = false
			_trigger_rocket_impact()
		return
	
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		return
	
	# Shield Dome behavior (Titan)
	if is_barrier_active and shield_dome_node:
		shield_dome_node.visible = true
		shield_dome_node.rotation += delta * 8.0
		# Deflect any incoming enemy bullets!
		var bullets = get_tree().get_nodes_in_group("bullet")
		for b in bullets:
			if is_instance_valid(b) and b.shooter != self and global_position.distance_to(b.global_position) < 55.0:
				b.shooter = self
				b.target_enemy = opponent
				b.velocity = -b.velocity * 1.3
				b.modulate = Color(0.2, 0.8, 1.0)
				SoundManager.play_sound("bounce", 0.3, 3.0)
	elif shield_dome_node:
		shield_dome_node.visible = false
	
	# Gravity & Movement
	if not is_on_floor():
		var grav = 980.0
		# Wall sliding
		if is_on_wall() and velocity.y > 0 and (Input.is_action_pressed(_act("left")) or Input.is_action_pressed(_act("right"))):
			velocity.y = minf(velocity.y + (grav * 0.4) * delta, 150.0)
		else:
			velocity.y += grav * delta
	else:
		jumps_remaining = max_jumps
	
	# Input Handling. Während des Start-Countdowns oder eines Betäubungs-Effekts
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
	# Move X – auf Eis wird deutlich langsamer beschleunigt und gebremst.
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
	
	# Ability
	var ability_pressed = Input.is_action_just_pressed(_act("ability"))
	if player_index == 1:
		ability_pressed = ability_pressed or Input.is_action_just_pressed("p1_ability_alt") or Input.is_action_just_pressed("p1_ability_q") or Input.is_action_just_pressed("p1_ability_f")
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

# Eisflächen melden sich hier an/ab. Mehrere Quellen gleichzeitig (z. B. zwei
# angrenzende Eis-Tiles) werden gezählt.
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
	max_health = float(data.get("max_hp", max_health))
	current_health = float(data.get("hp", current_health))
	max_shield = float(data.get("max_shield", max_shield))
	current_shield = float(data.get("shield", current_shield))
	max_ammo = int(data.get("max_ammo", max_ammo))
	current_ammo = int(data.get("ammo", current_ammo))
	ability_timer = float(data.get("ability", ability_timer))
	ability_max_cooldown = float(data.get("ability_max", ability_max_cooldown))
	is_reloading = bool(data.get("reload", is_reloading))
	is_barrier_active = bool(data.get("barrier", is_barrier_active))
	
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
		shield_dome_node.visible = is_barrier_active
	
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)

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
	SoundManager.play_sound("dash", 0.2, 0.0)
	
	# Ignis Passive: Afterburner fire sparks
	var hero_id = Global.p1_hero_id if player_index == 1 else Global.p2_hero_id
	if hero_id == "ignis" and opponent and is_instance_valid(opponent):
		_spawn_fire_sparks()

func _spawn_ghost_trail() -> void:
	if not is_dashing:
		ghost_timer.stop()
		return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale * scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.6)
	get_parent().add_child(ghost)
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)

func shoot() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if is_reloading or fire_timer > 0.0:
		return
	if current_ammo <= 0:
		start_reload()
		return
	
	fire_timer = fire_rate_cooldown
	current_ammo -= 1
	emit_signal("ammo_changed", current_ammo, max_ammo)
	
	# Recoil Kickback
	velocity -= aim_direction * (80.0 + bullet_damage * 1.5)
	
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
	
	if current_ammo <= 0:
		start_reload()

func _spawn_bullet(dir: Vector2) -> void:
	var b: Bullet = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.velocity = dir * bullet_speed
	b.shooter = self
	b.target_enemy = opponent
	b.damage = bullet_damage
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
	
	# Tint bullet by hero color
	if player_index == 1:
		b.modulate = Color(1.0, 0.6, 0.3)
	else:
		b.modulate = Color(0.4, 0.8, 1.0)
	
	get_parent().add_child(b)

func start_reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time
	SoundManager.play_sound("click", 0.1, -6.0)

func use_ability() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if ability_timer > 0.0:
		return
	ability_timer = ability_max_cooldown
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	var hero_id = Global.p1_hero_id if player_index == 1 else Global.p2_hero_id
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
		"titan":
			# Fortress Shield Barrier: Unverwundbare Kugel, die gegnerische Schüsse reflektiert
			SoundManager.play_sound("shield", 0.2, 0.0)
			is_barrier_active = true
			barrier_duration_timer = 2.8 + barrier_duration_add
			if shield_dome_node:
				shield_dome_node.visible = true
		"volt":
			# Flash Blink: Blitz-Teleport mit Schockwelle & Betäubung
			SoundManager.play_sound("dash", 0.4, 3.0)
			_perform_flash_blink()
		"spore":
			# Toxic Gas Cloud: Große Giftwolke + 4 Sporen-Nadeln
			SoundManager.play_sound("poison", 0.3, 0.0)
			_spawn_spore_cloud()

	# Turm-Talent: Die Spezialfähigkeit platziert zusätzlich einen Turm.
	if tower_enabled:
		_spawn_tower()

func _trigger_rocket_impact() -> void:
	SoundManager.play_sound("explosion", 0.2, -2.0)
	var shock = Sprite2D.new()
	shock.texture = load("res://assets/projectiles/tile_0000.png")
	shock.modulate = Color(1.0, 0.4, 0.1, 0.9)
	get_parent().add_child(shock)
	shock.global_position = global_position
	var tw = shock.create_tween()
	tw.tween_property(shock, "scale", Vector2(9.0, 9.0), 0.3)
	tw.parallel().tween_property(shock, "modulate:a", 0.0, 0.3)
	tw.tween_callback(shock.queue_free)
	
	if opponent and is_instance_valid(opponent):
		var dist = global_position.distance_to(opponent.global_position)
		if dist < 140.0:
			var falloff = 1.0 - (dist / 140.0)
			opponent.take_damage(35.0 * falloff, (opponent.global_position - global_position).normalized() * 550.0)

func _perform_flash_blink() -> void:
	var start_pos = global_position
	var target_pos = global_position + (aim_direction.normalized() * 260.0)
	target_pos.x = clampf(target_pos.x, 60.0, 1320.0)
	target_pos.y = clampf(target_pos.y, 60.0, 720.0)
	
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
	shock.texture = load("res://assets/projectiles/tile_0000.png")
	shock.modulate = Color(1.0, 1.0, 0.2, 0.9)
	get_parent().add_child(shock)
	shock.global_position = target_pos
	var tw2 = shock.create_tween()
	tw2.tween_property(shock, "scale", Vector2(7.0, 7.0), 0.25)
	tw2.parallel().tween_property(shock, "modulate:a", 0.0, 0.25)
	tw2.tween_callback(shock.queue_free)
	
	if opponent and is_instance_valid(opponent):
		var dist = global_position.distance_to(opponent.global_position)
		if dist < 120.0:
			opponent.take_damage(20.0, (opponent.global_position - global_position).normalized() * 300.0)
			opponent.apply_freeze(1.2)

func _spawn_fire_sparks() -> void:
	var spark = Sprite2D.new()
	spark.texture = load("res://assets/projectiles/tile_0000.png")
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
	cloud_sprite.texture = load("res://assets/projectiles/tile_0000.png")
	cloud_sprite.modulate = Color(0.3, 0.9, 0.2, 0.5)
	cloud_sprite.scale = Vector2(7.0, 7.0)
	cloud.add_child(cloud_sprite)
	
	get_parent().add_child(cloud)
	cloud.global_position = global_position
	
	var t = cloud.create_tween()
	t.tween_method(func(_val: float):
		if opponent and is_instance_valid(opponent):
			if cloud.global_position.distance_to(opponent.global_position) <= 45.0:
				opponent.take_damage(0.15, Vector2.ZERO)
	, 0.0, 1.0, 3.5)
	t.parallel().tween_property(cloud_sprite, "modulate:a", 0.0, 3.5)
	t.tween_callback(cloud.queue_free)

func _flash_effect() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 1.0), 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or is_barrier_active:
		SoundManager.play_sound("bounce", 0.2, 2.0)
		if shield_dome_node:
			var tw = create_tween()
			tw.tween_property(shield_dome_node, "modulate", Color(1.5, 2.0, 2.5, 0.9), 0.06)
			tw.tween_property(shield_dome_node, "modulate", Color(0.2, 0.7, 1.0, 0.6), 0.12)
		return
	
	shield_regen_timer = 3.5
	hp_regen_timer = 3.0
	
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
	
	_flash_hit()
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	
	if current_health <= 0.0:
		_die()

func _flash_hit() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.RED, 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func heal(amount: float) -> void:
	current_health = minf(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.GREEN, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func apply_poison(stacks: int, damage_per_tick: float = 4.0) -> void:
	# Stärkeres Gift überschreibt schwächeres, schwächeres Gift verlängert nur.
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

# --- Talentbaum: Türme und Drohnen ---

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
		drone.target_enemy = opponent
		drone.support = drone_guardian
		drone.is_replica = is_replica
		drone.orbit_radius = 48.0 + float(i) * 16.0
		drone.orbit_speed = 1.5 + float(i) * 0.25
		add_child(drone)
		drones.append(drone)

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
	tower.target_enemy = opponent
	tower.follow_owner = tower_follow
	tower.is_replica = false
	get_parent().add_child(tower)
	tower.global_position = global_position
	towers.append(tower)

# --- Talentbaum: Flächeneffekte ---

func spawn_effect_zone(kind: int, pos: Vector2, radius: float, duration: float, params: Dictionary = {}) -> void:
	if is_replica:
		return
	var zone := EffectZone.new()
	zone.kind = kind
	zone.owner_player = self
	zone.target = opponent
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
		if p != self and p != primary and is_instance_valid(p) and p.current_health > 0.0:
			chain_target = p
			break
	if chain_target == null and is_instance_valid(primary) and primary.current_health > 0.0:
		# Im 1-gegen-1 springt der Kettenblitz auf das Primärziel zurück.
		chain_target = primary
	if chain_target == null:
		return

	chain_target.take_damage(bullet_damage * 0.45)
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
		b.target_enemy = opponent
		b.damage = bullet_damage * 0.40
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
	emit_signal("died", player_index)
	queue_free()

func _trigger_kamikaze() -> void:
	SoundManager.play_sound("explosion", 0.2, 0.0)
	if opponent and is_instance_valid(opponent):
		var dist = global_position.distance_to(opponent.global_position)
		if dist < 160.0:
			var falloff = 1.0 - (dist / 160.0)
			opponent.take_damage(65.0 * falloff, (opponent.global_position - global_position).normalized() * 500.0)

func _handle_timers(delta: float) -> void:
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
			is_invulnerable = false
	
	if ability_timer > 0.0:
		ability_timer -= delta
		if ability_timer <= 0.0:
			ability_timer = 0.0
			emit_signal("ability_cooldown_updated", 0.0, ability_max_cooldown)
		else:
			emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	if is_barrier_active:
		barrier_duration_timer -= delta
		if barrier_duration_timer <= 0.0:
			is_barrier_active = false
			modulate = Color.WHITE
	
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

	# Turm-Talent: automatisch neue Türme erzeugen.
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
