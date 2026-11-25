class_name HordeEnemy
extends CharacterBody2D

# Ein Gegner im Horden-Modus (Wolf, Bär, Metzger …) oder ein Boss-Held.
#
# Leichtgewichtig: kein Player, keine Karten. Er liegt auf der Turm-Ebene
# (Companion.TOWER_COLLISION_LAYER), dadurch treffen ihn Kugeln (normaler
# Trefferpfad mit Gift, Frost, Durchschlag, Lebensraub) und Explosionen ohne
# Sonderfälle. Für Nahkampf und Flächenfähigkeiten bietet er dieselben Felder
# und Methoden wie ein Player (take_damage, apply_stun, apply_poison …), und
# Player._opponents_within / _melee_targets nehmen ihn im Horden-Modus mit.
#
# Der Host simuliert, Clients bekommen Position und Zustand über den
# Horden-Snapshot (HordeDirector) und zeigen nur an.

const GROUP: String = "horde_enemy"
const POISON_TICK: float = 0.8
const BURN_TICK: float = 0.5
const FLY_HEIGHT: float = 70.0
## Hüpfen auf Felsstufen (p, 36 px): kurz ausholen, dann im Bogen hinauf.
const HOP_WINDUP: float = 0.35
const HOP_AIR: float = 0.32
const HOP_ARC: float = 22.0
const HOP_COOLDOWN: float = 0.5

var net_id: int = 0
var kind: String = "wolf"
var is_replica: bool = false
var is_boss: bool = false
var hero_id: String = ""
var riese: bool = false
var director: Node = null

# --- Felder, die Spieler-Code bei Gegnern abfragt (Duck-Typing) ---
var team_id: int = 99
var player_index: int = 0
var is_bot: bool = true
var is_dead: bool = false
var is_blocking: bool = false
var is_invulnerable: bool = false
var max_health: float = 20.0
var current_health: float = 20.0
var current_shield: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT
var arena_z: float = 0.0
var arena_vz: float = 0.0
var arena_grounded: bool = true
var knockback_timer: float = 0.0
var wall_slam_damage: float = 0.0
var wall_slam_shield: float = 0.0
var wall_slam_source = null
var melee_wall_stun_timer: float = 0.0
var melee_wall_stun_duration: float = 0.0
var heal_block_timer: float = 0.0
var mark_timer: float = 0.0
var mark_source = null
var last_damage_source = null

# --- Werte der Art ---
var speed: float = 120.0
var damage: float = 8.0
var radius: float = 14.0
var size: float = 1.0
var xp_value: int = 1
var ai: String = "chase"
var def: Dictionary = {}

# --- Zustand ---
var stun_timer: float = 0.0
var freeze_timer: float = 0.0
var poison_ticks_left: int = 0
var poison_damage_per_tick: float = 0.0
var _poison_t: float = 0.0
var burn_ticks_left: int = 0
var burn_damage_per_tick: float = 0.0
var _burn_t: float = 0.0
var _knock: Vector2 = Vector2.ZERO
var _contact_cd: float = 0.0
var _attack_cd: float = 0.0
var _special_cd: float = 0.0
var _state: String = ""      # "", "windup", "lunge", "dive", "rise", "charge"
var _state_t: float = 0.0
var _state_dir: Vector2 = Vector2.ZERO
var _strafe: float = 1.0
var _strafe_t: float = 0.0
var _haste_t: float = 0.0
var _time_slow_t: float = 0.0
var _time_slow_mult: float = 1.0
var _orbit_angle: float = 0.0
var hit_flash: float = 0.0
## Für die Anzeige: Animation (Schnappen, Werfen, Heulen) kurz an.
var anim_action: float = 0.0
var _net_target: Vector2 = Vector2.ZERO
# Zwischenspeicher, damit hunderte Gegner nicht jeden Frame alles neu rechnen:
# Fluss-Richtung je Zelle, Sichtlinie für kurze Zeit, Ausweichschub jeden
# zweiten Frame, Bewegung weit entfernter Gegner jeden dritten Frame.
var _flow_cell: Vector2i = Vector2i(-99999, -99999)
var _flow_ver: int = -1
var _flow_cache: Vector2 = Vector2.ZERO
var _los_t: float = 0.0
var _los_val: bool = false
# Höhenstufe (0 Boden, 1 Felsstufe), -1 = noch nicht bestimmt (frisch gespawnt).
var _stand_level: int = -1
var _hop_wind: float = 0.0
var _hop_air: float = 0.0
var _hop_cd: float = 0.0
var _hop_z0: float = 0.0
var _los_target: Node2D = null
var _sep_cache: Vector2 = Vector2.ZERO
var _move_cache: Vector2 = Vector2.ZERO
const FAR_THINK_DIST_SQ: float = 720.0 * 720.0
var _kill_credit = null

func setup(p_kind: String, p_riese: bool, hp_mult: float, dmg_mult: float) -> void:
	kind = p_kind
	riese = p_riese
	def = HordeDefs.ENEMIES.get(kind, HordeDefs.ENEMIES["wolf"])
	speed = float(def["speed"]) * randf_range(0.92, 1.08)
	damage = float(def["damage"]) * dmg_mult
	radius = float(def["radius"])
	size = float(def["size"]) * randf_range(0.93, 1.07)
	xp_value = int(def["xp"])
	ai = str(def["ai"])
	max_health = float(def["hp"]) * hp_mult
	if riese:
		size *= HordeDefs.RIESE_SIZE
		radius *= HordeDefs.RIESE_SIZE
		max_health *= HordeDefs.RIESE_HP_MULT
		damage *= 1.5
		speed *= 0.9
		xp_value = int(round(float(xp_value) * HordeDefs.RIESE_XP_MULT))
	current_health = max_health
	_attack_cd = randf_range(0.5, float(def.get("shot_interval", 2.0)))
	_special_cd = randf_range(2.0, 5.0)
	if ai == "fly":
		arena_z = FLY_HEIGHT
		_orbit_angle = randf() * TAU

## Boss: ein Held mit sehr viel Leben.
func setup_boss(p_hero_id: String, hp: float, dmg_mult: float) -> void:
	is_boss = true
	kind = "boss"
	hero_id = p_hero_id
	def = {}
	ai = "boss_melee" if Global.is_melee_hero(hero_id) else "boss_ranged"
	speed = 125.0 if ai == "boss_melee" else 95.0
	damage = 22.0 * dmg_mult
	radius = 30.0
	size = 2.6
	xp_value = 60
	max_health = hp
	current_health = hp
	_attack_cd = 2.0
	_special_cd = 6.0

func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("round_effect")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	_net_target = global_position
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)
	if is_replica:
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
	else:
		collision_layer = Companion.TOWER_COLLISION_LAYER
		# Bodengegner stoßen an Mauern (Band 0), Adler fliegen darüber.
		collision_mask = 0 if ai == "fly" else 1

func is_alive() -> bool:
	return not is_dead and current_health > 0.0

# --- Simulation (Host) ---

func _physics_process(delta: float) -> void:
	if is_dead or director == null or not director.running:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	anim_action = maxf(0.0, anim_action - delta)
	_contact_cd -= delta
	_attack_cd -= delta
	_special_cd -= delta
	_haste_t = maxf(0.0, _haste_t - delta)
	_time_slow_t = maxf(0.0, _time_slow_t - delta)
	knockback_timer = maxf(0.0, knockback_timer - delta)
	mark_timer = maxf(0.0, mark_timer - delta)
	_tick_status(delta)
	if is_dead:
		return
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	var target: Node2D = director.nearest_target(global_position)
	var move := Vector2.ZERO
	var spd := speed * (1.35 if _haste_t > 0.0 else 1.0) * (_time_slow_mult if _time_slow_t > 0.0 else 1.0)
	var disabled := stun_timer > 0.0 or freeze_timer > 0.0
	if disabled:
		stun_timer = maxf(0.0, stun_timer - delta)
		freeze_timer = maxf(0.0, freeze_timer - delta)
		_state = "" if _state != "dive" else _state
	elif target != null:
		# Weit weg (außerhalb des Bildes) reicht jeder dritte Frame.
		var frame := Engine.get_physics_frames() + net_id
		if not is_boss and _state == "" and frame % 3 != 0 \
				and global_position.distance_squared_to(target.global_position) > FAR_THINK_DIST_SQ:
			move = _move_cache * spd
		else:
			_move_cache = _think(target, delta)
			move = _move_cache * spd
	if ai == "fly":
		_update_flight(delta, target)
	velocity = move + _knock
	if not is_boss:
		if (Engine.get_physics_frames() + net_id) % 2 == 0:
			_sep_cache = director.separation(self)
		velocity += _sep_cache * 90.0
	_grid_move(delta)
	_clamp_to_map()
	if target != null and not disabled:
		_try_contact(target)

func _think(target: Node2D, delta: float) -> Vector2:
	var to := target.global_position - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if to.length_squared() > 1.0:
		aim_direction = dir
	match ai:
		"fly":
			return _think_fly(target, dist, dir)
		"lunge":
			return _think_lunge(dist, dir, delta)
		"ranged", "throw":
			return _think_ranged(target, dist, dir, delta)
		"howl":
			if _special_cd <= 0.0 and dist < 700.0:
				_special_cd = 7.0
				anim_action = 0.8
				director.howl(self)
			return _path_dir(target, dist, dir)
		"boss_melee":
			return _think_boss_melee(target, dist, dir, delta)
		"boss_ranged":
			return _think_boss_ranged(target, dist, dir, delta)
	return _path_dir(target, dist, dir)

## Laufrichtung zum Ziel: nah und mit freier Sicht direkt, sonst über das
## Fluss-Feld um Mauern herum.
func _path_dir(target: Node2D, dist: float, dir: Vector2) -> Vector2:
	if dist < 110.0:
		return dir
	var flow := _cached_flow()
	if flow == Vector2.ZERO:
		return dir
	if dist < 260.0 and _sees(target):
		return dir
	return flow

## Fluss-Richtung nur neu, wenn die Zelle oder das Fluss-Feld wechselt.
func _cached_flow() -> Vector2:
	var grid := ArenaMode.grid
	if grid == null:
		return Vector2.ZERO
	var c := grid.cell_of(global_position)
	var ver: int = director.flow_version
	if c != _flow_cell or ver != _flow_ver:
		_flow_cell = c
		_flow_ver = ver
		_flow_cache = director.flow_dir(global_position)
	return _flow_cache

## Sichtlinie zum Ziel, für 0,2 bis 0,3 s zwischengespeichert.
func _sees(target: Node2D) -> bool:
	_los_t -= get_physics_process_delta_time()
	if _los_t <= 0.0 or target != _los_target:
		_los_t = randf_range(0.2, 0.3)
		_los_target = target
		var tz := _target_floor(target)
		if tz > arena_z + 20.0:
			# Erhöhter Eber: Sicht über das Raster in Wurfhöhe (über Felsstufen hinweg).
			_los_val = director.has_los_at(global_position, target.global_position, tz + ArenaMode.MUZZLE_H)
		else:
			_los_val = director.has_los(global_position, target.global_position)
	return _los_val

func _think_lunge(dist: float, dir: Vector2, delta: float) -> Vector2:
	match _state:
		"windup":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "lunge"
				_state_t = 0.32
				anim_action = 0.4
			return Vector2.ZERO
		"lunge":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = ""
				_special_cd = 2.2
			return _state_dir * 4.8
	if dist < 150.0 and _special_cd <= 0.0:
		_state = "windup"
		_state_t = 0.4
		_state_dir = dir
		return Vector2.ZERO
	var target: Node2D = director.nearest_target(global_position)
	return _path_dir(target, dist, dir) if target != null else dir

func _think_ranged(target: Node2D, dist: float, dir: Vector2, delta: float) -> Vector2:
	var reach := float(def.get("range", 450.0))
	var sees: bool = _sees(target)
	if _attack_cd <= 0.0 and dist < reach and sees:
		_attack_cd = float(def.get("shot_interval", 2.5)) * randf_range(0.85, 1.15)
		anim_action = 0.35
		var shot_kind := "cleaver" if ai == "throw" else "pellet"
		var lead := target.global_position
		if target is CharacterBody2D:
			lead += (target as CharacterBody2D).velocity * clampf(dist / float(def.get("shot_speed", 400.0)), 0.0, 0.6) * 0.5
		var aim := (lead - global_position).normalized()
		# Steht der Eber höher, fliegt der Wurf im Bogen auf seine Höhe.
		director.spawn_shot(global_position + aim * radius, aim * float(def.get("shot_speed", 400.0)),
			float(def.get("shot_damage", 10.0)) * HordeDefs.damage_mult(director.run_time), shot_kind,
			maxf(arena_z, _target_floor(target)) + ArenaMode.MUZZLE_H)
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 2.2)
		_strafe = -_strafe
	var keep := reach * (0.62 if ai == "ranged" else 0.5)
	if not sees or dist > reach * 0.9:
		return _path_dir(target, dist, dir)
	if dist < keep * 0.7:
		return (-dir + dir.orthogonal() * _strafe * 0.5).normalized()
	return (dir.orthogonal() * _strafe + dir * 0.15).normalized() * 0.7

func _think_fly(target: Node2D, dist: float, dir: Vector2) -> Vector2:
	match _state:
		"dive":
			return _state_dir * 2.1
		"rise":
			return _state_dir * 1.0
	# Kreisen um das Ziel, dann Sturzflug.
	_orbit_angle += 0.02
	var orbit := target.global_position + Vector2.from_angle(_orbit_angle) * 170.0
	if dist < 230.0 and _special_cd <= 0.0:
		_state = "dive"
		_state_t = 0.55
		_state_dir = dir
		anim_action = 0.55
		return dir * 2.1
	return (orbit - global_position).normalized()

func _update_flight(delta: float, target: Node2D) -> void:
	# Adler fliegen über erhöhten Ebern höher und stoßen auf ihre Höhe herab.
	var tz := _target_floor(target)
	var cruise := maxf(FLY_HEIGHT, tz + 40.0)
	match _state:
		"dive":
			arena_z = move_toward(arena_z, tz + 8.0, 260.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "rise"
				_state_t = 0.7
		"rise":
			arena_z = move_toward(arena_z, cruise, 120.0 * delta)
			_state_t -= delta
			if _state_t <= 0.0:
				_state = ""
				_special_cd = randf_range(2.5, 4.0)
		_:
			arena_z = move_toward(arena_z, cruise, 90.0 * delta)

func _think_boss_melee(target: Node2D, dist: float, dir: Vector2, delta: float) -> Vector2:
	match _state:
		"windup":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = "charge"
				_state_t = 0.5
				anim_action = 0.5
			return Vector2.ZERO
		"charge":
			_state_t -= delta
			if _state_t <= 0.0:
				_state = ""
				_special_cd = randf_range(3.2, 4.5)
				director.boss_slam(self, 120.0, damage * 1.3)
			return _state_dir * 5.2
	if _attack_cd <= 0.0:
		_attack_cd = 9.0
		director.boss_summon(self)
	if dist < 420.0 and _special_cd <= 0.0:
		_state = "windup"
		_state_t = 0.65
		_state_dir = dir
		return Vector2.ZERO
	return _path_dir(target, dist, dir)

func _think_boss_ranged(target: Node2D, dist: float, dir: Vector2, delta: float) -> Vector2:
	if _special_cd <= 0.0:
		_special_cd = randf_range(2.4, 3.2)
		anim_action = 0.4
		var n := 12
		var base := randf() * TAU
		for i in range(n):
			var a := base + TAU * float(i) / float(n)
			director.spawn_shot(global_position, Vector2.from_angle(a) * 300.0, damage * 0.55, "orb")
	if _attack_cd <= 0.0 and _sees(target):
		_attack_cd = randf_range(1.6, 2.2)
		anim_action = 0.3
		for i in range(3):
			var spread := (float(i) - 1.0) * 0.16
			director.spawn_shot(global_position + dir * radius, dir.rotated(spread) * 470.0, damage * 0.7, "orb",
				maxf(arena_z, _target_floor(target)) + ArenaMode.MUZZLE_H)
	_state_t -= delta
	if _state_t <= 0.0:
		_state_t = 10.0
		director.boss_summon(self)
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.5, 2.5)
		_strafe = -_strafe
	if dist > 380.0:
		return _path_dir(target, dist, dir)
	if dist < 220.0:
		return -dir * 0.8
	return dir.orthogonal() * _strafe * 0.6

func _try_contact(target: Node2D) -> void:
	if _contact_cd > 0.0:
		return
	# Über Gegner springen: Wer hoch genug ist, wird nicht gebissen.
	var tz := float(target.get("arena_z")) if target.get("arena_z") != null else 0.0
	if tz - arena_z > 30.0 or arena_z - tz > 30.0:
		return
	var reach := radius + 14.0 * (target.scale.x / Player.BASE_CHARACTER_SCALE)
	if global_position.distance_to(target.global_position) > reach:
		return
	_contact_cd = HordeDefs.CONTACT_INTERVAL * (0.5 if _state == "lunge" else 1.0)
	var push := (target.global_position - global_position).normalized() * (160.0 + damage * 6.0)
	var dmg := damage * (1.6 if _state == "lunge" or _state == "dive" else 1.0)
	anim_action = maxf(anim_action, 0.25)
	if target.has_method("take_damage"):
		target.take_damage(dmg, push, self)
	if _state == "dive":
		_state = "rise"
		_state_t = 0.7
		_state_dir = -_state_dir

## Bewegung ohne Physik-Engine: Mauern liegen im Arena-Raster, daher reicht
## eine Prüfung der Zellen je Achse (Gleiten an Wänden). Deutlich günstiger
## als move_and_slide für hunderte Gegner. Adler fliegen über alles.
func _grid_move(delta: float) -> void:
	var step := velocity * delta
	var pos := global_position
	if ai == "fly" or ArenaMode.grid == null:
		global_position = pos + step
		return
	var r := radius * 0.75
	# Steckt der Gegner in einer Mauer (Rückstoß, neue Kiste, Kartenwechsel),
	# holt ihn die nächste freie Stelle heraus, statt dass er festhängt.
	if not director.is_free_area(pos, r):
		var free_pos: Vector2 = director.find_free_spot(pos, r)
		if free_pos != Vector2.INF:
			global_position = free_pos
		return
	# Höhenstufen: Bodengegner laufen auf Boden und Felsstufen (p). Eine
	# höhere Stufe erreichen sie nur mit einem Hüpfer, Plateaus (P/T) gar nicht.
	var lvl: int = director.level_at(pos)
	if _stand_level < 0:
		_stand_level = maxi(lvl, 0)
		arena_z = float(_stand_level) * HordeDirector.STEP_LEVEL_H
	_hop_cd -= delta
	if _hop_wind > 0.0:
		_hop_wind -= delta
		if _hop_wind <= 0.0:
			_hop_air = HOP_AIR
			_hop_z0 = arena_z
		_settle_height(delta)
		return
	var max_lvl := 1 if _hop_air > 0.0 else _stand_level
	var here_area: int = director.area_level(pos, r)
	var blocked_up := false
	var nx := pos + Vector2(step.x, 0.0)
	if director.is_free_area(nx, r):
		if _may_enter(nx, r, max_lvl, here_area):
			pos = nx
		else:
			blocked_up = true
	var ny := pos + Vector2(0.0, step.y)
	if director.is_free_area(ny, r):
		if _may_enter(ny, r, max_lvl, here_area):
			pos = ny
		else:
			blocked_up = true
	global_position = pos
	if _hop_air > 0.0:
		_hop_air -= delta
		var k := 1.0 - clampf(_hop_air / HOP_AIR, 0.0, 1.0)
		arena_z = lerpf(_hop_z0, HordeDirector.STEP_LEVEL_H, k) + sin(k * PI) * HOP_ARC
		if _hop_air <= 0.0:
			_stand_level = maxi(director.level_at(global_position), 0)
			_hop_cd = HOP_COOLDOWN
		return
	if blocked_up and _stand_level == 0 and _hop_cd <= 0.0 and step.length_squared() > 0.01 \
			and stun_timer <= 0.0 and freeze_timer <= 0.0:
		_hop_wind = HOP_WINDUP
		anim_action = maxf(anim_action, HOP_WINDUP)
	# Über die Kante gelaufen oder gestoßen: herunterfallen.
	var now: int = director.level_at(global_position)
	if now >= 0 and now < _stand_level:
		_stand_level = now
	_settle_height(delta)

## Darf der Gegner nach p? Die Mitte darf nicht höher stehen als seine Stufe,
## und er darf nicht weiter auf eine höhere Stufe rutschen, als er schon
## berührt (sonst klebt er nach einem missglückten Hüpfer an der Kante).
func _may_enter(p: Vector2, r: float, max_lvl: int, here_area: int) -> bool:
	if director.level_at(p) > max_lvl:
		return false
	var a: int = director.area_level(p, r)
	return a <= max_lvl or a <= here_area

func _settle_height(delta: float) -> void:
	var floor_z := float(maxi(_stand_level, 0)) * HordeDirector.STEP_LEVEL_H
	if arena_z > floor_z:
		arena_z = move_toward(arena_z, floor_z, 320.0 * delta)
	else:
		arena_z = floor_z

## Standhöhe eines Ziels, auf ganze Höhenbänder abgerundet (springende Eber
## zählen zur Fläche unter ihnen).
static func _target_floor(target: Node2D) -> float:
	if target == null:
		return 0.0
	var tz = target.get("arena_z")
	if tz == null:
		return 0.0
	return floorf(maxf(float(tz), 0.0) / ArenaMode.BAND_H) * ArenaMode.BAND_H

func _clamp_to_map() -> void:
	var w := float(LevelGenerator.map_w) * LevelGenerator.TILE_SIZE
	var h := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	if w <= 0.0:
		return
	global_position = global_position.clamp(Vector2(radius, radius), Vector2(w - radius, h - radius))

func _tick_status(delta: float) -> void:
	if poison_ticks_left > 0:
		_poison_t += delta
		if _poison_t >= POISON_TICK:
			_poison_t = 0.0
			poison_ticks_left -= 1
			_apply_damage(poison_damage_per_tick, _kill_credit)
	if burn_ticks_left > 0:
		_burn_t += delta
		if _burn_t >= BURN_TICK:
			_burn_t = 0.0
			burn_ticks_left -= 1
			_apply_damage(burn_damage_per_tick, _kill_credit)

# --- Schnittstelle wie Player ---

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, source = null, _is_reflected: bool = false) -> void:
	if is_replica or is_dead or amount <= 0.0:
		return
	if not is_instance_valid(source):
		source = null
	# Gegner verletzen sich nicht gegenseitig.
	if source is HordeEnemy:
		return
	if source is Player:
		_kill_credit = source
		last_damage_source = source
	if mark_timer > 0.0 and source != null and source == mark_source:
		amount *= 1.25
	var resist := 0.25 if is_boss else (0.6 if riese else 1.0)
	_knock += knockback * resist * 0.6
	_apply_damage(amount, source)

func _apply_damage(amount: float, source) -> void:
	if is_dead:
		return
	if not is_instance_valid(source):
		source = null
	if not is_instance_valid(_kill_credit):
		_kill_credit = null
	var dealt := minf(amount, current_health)
	current_health -= amount
	hit_flash = 0.1
	if source is Player and is_instance_valid(source):
		Global.add_match_stat(source.player_index, "damage_dealt", dealt)
		if source.dealing_ability_damage:
			Global.add_match_stat(source.player_index, "ability_damage", dealt)
		if director != null:
			director.note_damage(source.player_index, dealt)
	if current_health <= 0.0:
		_die(source if source is Player else _kill_credit)

func _die(killer) -> void:
	if is_dead:
		return
	is_dead = true
	current_health = 0.0
	if director != null:
		director.on_enemy_killed(self, killer if is_instance_valid(killer) else null)
	queue_free()

func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration * (0.3 if is_boss else 1.0))

func apply_freeze(duration: float) -> void:
	freeze_timer = maxf(freeze_timer, duration * (0.3 if is_boss else 0.8))

func apply_poison(stacks: int, damage_per_tick: float = 4.0) -> void:
	poison_damage_per_tick = maxf(poison_damage_per_tick, damage_per_tick)
	poison_ticks_left = maxi(poison_ticks_left, stacks)

func apply_burn(stacks: int, damage_per_tick: float = 5.0) -> void:
	burn_ticks_left = maxi(burn_ticks_left, stacks)
	burn_damage_per_tick = maxf(burn_damage_per_tick, damage_per_tick)

func apply_knockback(force: Vector2) -> void:
	_knock += force * (0.25 if is_boss else 0.7)

func apply_slow(_mult: float, duration: float) -> void:
	freeze_timer = maxf(freeze_timer, duration * 0.3)

# Zeitschläger (Taktschlag, Zeitblase): Verlangsamung, Bosse nur halb so stark.
func apply_time_slow(mult: float, duration: float) -> void:
	var m := clampf(mult, 0.05, 1.0)
	if is_boss:
		m = lerpf(m, 1.0, 0.5)
	if _time_slow_t <= 0.0 or m < _time_slow_mult:
		_time_slow_mult = m
	_time_slow_t = maxf(_time_slow_t, duration)

# Zeitstopp trifft nur Eber; Horden-Gegner werden nie eingefroren.
func is_time_frozen() -> bool:
	return false

func is_poisoned() -> bool:
	return poison_ticks_left > 0

func is_invisible() -> bool:
	return false

func is_reviving() -> bool:
	return false

func get_lure_target() -> Node2D:
	return self

func heal(amount: float) -> void:
	current_health = minf(max_health, current_health + amount)

func haste(duration: float) -> void:
	_haste_t = maxf(_haste_t, duration)

# --- Netzwerk ---

func get_net_row(kind_index: int) -> Array:
	var flags := 0
	if riese:
		flags |= 1
	if hit_flash > 0.0:
		flags |= 2
	if anim_action > 0.0:
		flags |= 4
	if freeze_timer > 0.0:
		flags |= 8
	if poison_ticks_left > 0:
		flags |= 16
	return [net_id, kind_index, int(global_position.x), int(global_position.y),
		int(clampf(current_health / maxf(1.0, max_health), 0.0, 1.0) * 255.0),
		snappedf(aim_direction.angle(), 0.05), int(arena_z), flags, snappedf(size, 0.01)]

func apply_net_row(row: Array) -> void:
	_net_target = Vector2(float(row[2]), float(row[3]))
	current_health = float(row[4]) / 255.0 * max_health
	aim_direction = Vector2.from_angle(float(row[5]))
	arena_z = float(row[6])
	var flags := int(row[7])
	riese = (flags & 1) != 0
	if (flags & 2) != 0:
		hit_flash = 0.1
	if (flags & 4) != 0:
		anim_action = 0.2
	freeze_timer = 0.2 if (flags & 8) != 0 else 0.0
	poison_ticks_left = 1 if (flags & 16) != 0 else 0
	if row.size() > 8:
		size = float(row[8])

func _process(delta: float) -> void:
	if not is_replica:
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	anim_action = maxf(0.0, anim_action - delta)
	var prev := global_position
	if global_position.distance_to(_net_target) > 300.0:
		global_position = _net_target
	else:
		global_position = global_position.lerp(_net_target, clampf(14.0 * delta, 0.0, 1.0))
	velocity = (global_position - prev) / maxf(delta, 0.001)
