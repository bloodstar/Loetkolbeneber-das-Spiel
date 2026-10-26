class_name LevelModifierManager
extends Node

const BountyCoinClass = preload("res://scripts/level/bounty_coin.gd")
const MovingHealZoneClass = preload("res://scripts/level/moving_heal_zone.gd")
const PinataLamaClass = preload("res://scripts/level/pinata_lama.gd")
const OrbitalLaserClass = preload("res://scripts/level/orbital_laser.gd")
const MeteorHazardClass = preload("res://scripts/level/meteor.gd")

signal modifiers_rolled(active_modifiers: Array[Dictionary])
signal wind_changed(active: bool, direction: float)
signal coin_collected(player_slot: int, count: int)
signal pinata_hit(player_slot: int, total_damage: float)

const LevelModifierDefsClass = preload("res://scripts/level_modifier_defs.gd")
const MODIFIERS: Dictionary = LevelModifierDefsClass.MODIFIERS

# Aktive Modifier der laufenden Runde
var active_modifiers: Array[String] = []

# Game References
var _main_ref: Node2D = null
var _level_ref: LevelGenerator = null

# Timers
var _wind_interval_timer: float = 10.0
var _wind_active_timer: float = 0.0
var _wind_direction: float = 1.0

var _tnt_timer: float = 10.0
var _laser_timer: float = 20.0
var _meteor_timer: float = 12.0
var _lava_timer: float = 0.0
var _regen_timer: float = 0.5
var _crate_timer: float = 9.0

# Tracking per round
var player_coins: Dictionary = {}         # slot -> coin count
var current_coin_node: Area2D = null
var current_heal_zone: Area2D = null
var current_pinata: PinataLama = null

var _wind_overlay: Node2D = null

func roll_modifiers(seed_val: int, rate_percent: int = LevelModifierDefsClass.RATE_DEFAULT_PERCENT, allowed_ids: Array[String] = []) -> Array[String]:
	var ids: Array[String] = []
	if allowed_ids.is_empty():
		ids = LevelModifierDefsClass.default_ids()
	else:
		for id in allowed_ids:
			if MODIFIERS.has(id) and not ids.has(id):
				ids.append(id)
	return _roll_with_config(seed_val, rate_percent, ids)

# Verwendet die aktuell in der Lobby konfigurierte Rate und Auswahl.
func roll_configured_modifiers(seed_val: int) -> Array[String]:
	var ids := Global.get_enabled_level_modifiers()
	if ids.is_empty():
		return []
	return _roll_with_config(seed_val, Global.level_modifier_rate_percent, ids)

func _roll_with_config(seed_val: int, rate_percent: int, allowed_ids: Array[String]) -> Array[String]:
	var rate := clampf(float(rate_percent) / 100.0, 0.0, 2.0)
	if rate <= 0.0 or allowed_ids.is_empty():
		return []

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 7777

	var roll := rng.randf() * 100.0
	var count := 0

	# Standardverteilung bei 100 %:
	# 1 % für 4 Modifier, 3 % für 3, 10 % für 2, 33 % für 1, 53 % für 0.
	if roll < 1.0:
		count = 4
	elif roll < 4.0:
		count = 3
	elif roll < 14.0:
		count = 2
	elif roll < 47.0:
		count = 1
	else:
		count = 0

	# Unter 100 % fällt gelegentlich ein Modifier weg, über 100 % kommt
	# gelegentlich einer hinzu. Bei 200 % ist es garantiert einer mehr.
	if rate < 1.0:
		if rng.randf() < (1.0 - rate):
			count = maxi(0, count - 1)
	elif rate > 1.0:
		if count < 4 and rng.randf() < minf(1.0, rate - 1.0):
			count += 1

	if count == 0:
		return []

	var all_keys: Array[String] = allowed_ids.duplicate()
	all_keys.sort() # Deterministic order before shuffle

	# Fisher-Yates with seeded RNG
	for i in range(all_keys.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var temp := all_keys[i]
		all_keys[i] = all_keys[j]
		all_keys[j] = temp

	var chosen: Array[String] = []
	for k in all_keys:
		if chosen.size() >= count:
			break
		if _are_incompatible(k, chosen):
			continue
		chosen.append(k)

	return chosen

func _are_incompatible(candidate: String, chosen: Array[String]) -> bool:
	if (candidate == "cave" and chosen.has("floor_is_lava")) \
			or (candidate == "floor_is_lava" and chosen.has("cave")):
		return true
	if (candidate == "low_gravity" and chosen.has("high_gravity")) \
			or (candidate == "high_gravity" and chosen.has("low_gravity")):
		return true
	return false

func start_round_modifiers(mod_ids: Array[String], main_node: Node2D, level_gen: LevelGenerator) -> void:
	clear_round()
	active_modifiers = mod_ids.duplicate()
	_main_ref = main_node
	_level_ref = level_gen

	player_coins.clear()
	_wind_interval_timer = 8.0
	_wind_active_timer = 0.0
	_tnt_timer = 10.0
	_laser_timer = 18.0
	_meteor_timer = 12.0
	_lava_timer = 0.0
	_regen_timer = 0.5
	_crate_timer = 9.0

	var arena_rect := Rect2(60, 60, LevelGenerator.MAP_WIDTH * LevelGenerator.TILE_SIZE - 120, LevelGenerator.MAP_HEIGHT * LevelGenerator.TILE_SIZE - 120)

	# 1. Beute (Coin Rush)
	if has_modifier("bounty"):
		_spawn_bounty_coin()

	# 2. Wandernde Heilzone
	if has_modifier("heal_zone"):
		current_heal_zone = MovingHealZoneClass.new()
		_main_ref.add_child(current_heal_zone)
		current_heal_zone.setup_bounds(arena_rect)

	# 3. Piñata-Lama
	if has_modifier("pinata"):
		current_pinata = PinataLamaClass.new()
		current_pinata.position = arena_rect.get_center()
		current_pinata.damaged.connect(func(slot: int, _amt: float):
			var total_dmg: float = float(current_pinata.damage_by_player.get(slot, 0.0))
			pinata_hit.emit(slot, total_dmg)
		)
		_main_ref.add_child(current_pinata)
		current_pinata.setup_bounds(arena_rect)

	# 4. Wind Overlay
	if has_modifier("wind"):
		_setup_wind_overlay()

	# Notify HUD
	var details: Array[Dictionary] = []
	for id in active_modifiers:
		if MODIFIERS.has(id):
			details.append(MODIFIERS[id])
	modifiers_rolled.emit(details)

func has_modifier(id: String) -> bool:
	return active_modifiers.has(id)

func apply_player_modifiers(player: Player) -> void:
	if not is_instance_valid(player):
		return
	if has_modifier("low_gravity"):
		player.gravity_mult *= 0.45
	if has_modifier("high_gravity"):
		player.gravity_mult *= 1.6
	if has_modifier("mini_pigs"):
		player.scale *= 0.65
		player.move_speed *= 1.25
	if has_modifier("speed_demon"):
		player.move_speed *= 1.3
	if has_modifier("double_damage"):
		player.bullet_damage *= 1.35
	if has_modifier("air_jumps"):
		player.max_jumps += 1
		player.jumps_remaining = player.max_jumps
	if has_modifier("starting_shield"):
		var bonus_shield := player.max_health * 0.3
		player.max_shield += bonus_shield
		player.current_shield = player.max_shield
		player.emit_signal(
			"health_changed",
			player.current_health,
			player.max_health,
			player.current_shield,
			player.max_shield
		)

func update_physics_modifiers(delta: float, players: Array[Player]) -> void:
	if active_modifiers.is_empty() or _main_ref == null:
		return

	# --- Piñata: primär vor dem führenden Spieler fliehen ---
	if has_modifier("pinata") and is_instance_valid(current_pinata):
		var leader := _get_leading_player(players)
		if leader != null:
			current_pinata.set_leader_position(leader.global_position)

	# --- Regeneration ---
	if has_modifier("regeneration"):
		_regen_timer -= delta
		if _regen_timer <= 0.0:
			_regen_timer = 0.5
			for p in players:
				if is_instance_valid(p) and not p.is_dead and p.current_health > 0.0:
					p.heal(2.0)

	# --- Kistenregen ---
	if has_modifier("crate_rain"):
		_crate_timer -= delta
		if _crate_timer <= 0.0:
			_crate_timer = 9.0
			_spawn_crate_rain()

	# --- Windstoß ---
	if has_modifier("wind"):
		if _wind_active_timer > 0.0:
			_wind_active_timer -= delta
			var wind_force := _wind_direction * 460.0
			for p in players:
				if is_instance_valid(p) and p.current_health > 0:
					p.velocity.x += wind_force * delta
			if _wind_active_timer <= 0.0:
				wind_changed.emit(false, 0.0)
				if is_instance_valid(_wind_overlay):
					_wind_overlay.visible = false
		else:
			_wind_interval_timer -= delta
			if _wind_interval_timer <= 0.0:
				_wind_interval_timer = 10.0
				_wind_active_timer = 3.6
				_wind_direction = -1.0 if randf() < 0.5 else 1.0
				wind_changed.emit(true, _wind_direction)
				SoundManager.play_sound("dash", 0.4, -2.0)
				if is_instance_valid(_wind_overlay):
					_wind_overlay.visible = true

	# --- TNT Depot Drop ---
	if has_modifier("tnt_depot"):
		_tnt_timer -= delta
		if _tnt_timer <= 0.0:
			_tnt_timer = 10.0
			_spawn_tnt_air_drop()

	# --- Orbital Laser ---
	if has_modifier("laser"):
		_laser_timer -= delta
		if _laser_timer <= 0.0:
			_laser_timer = 20.0
			_trigger_laser_hazard(players)

	# --- Meteoritenschauer ---
	if has_modifier("meteor_shower"):
		_meteor_timer -= delta
		if _meteor_timer <= 0.0:
			_meteor_timer = 12.0
			_trigger_meteor_shower(players)

	# --- Boden ist Lava ---
	if has_modifier("floor_is_lava") and _level_ref != null:
		# In diskreten Ticks statt pro Frame: take_damage() löst Trefferblitz,
		# Kamera-Shake und Statistiken aus und würde sonst 60-mal/s feuern.
		_lava_timer -= delta
		if _lava_timer <= 0.0:
			_lava_timer = 0.5
			var floor_y := (LevelGenerator.MAP_HEIGHT - 3.2) * LevelGenerator.TILE_SIZE
			for p in players:
				if is_instance_valid(p) and p.current_health > 0 and p.global_position.y >= floor_y:
					p.take_damage(16.0, Vector2(0, -120.0))

func _spawn_bounty_coin() -> void:
	if _level_ref == null or _main_ref == null or not has_modifier("bounty"):
		return
	var pos := _level_ref.find_random_platform_top()
	if pos == Vector2.INF:
		pos = Vector2(600, 300)

	var coin := BountyCoinClass.new()
	coin.position = pos
	coin.collected.connect(_on_coin_collected)
	_main_ref.add_child(coin)
	current_coin_node = coin

func _on_coin_collected(player: Node2D) -> void:
	var slot := int(player.get("player_index")) if player.get("player_index") != null else 1
	player_coins[slot] = int(player_coins.get(slot, 0)) + 1
	coin_collected.emit(slot, player_coins[slot])

	# Respawn next coin on another platform
	_spawn_bounty_coin()

func _spawn_tnt_air_drop() -> void:
	if _level_ref == null or _main_ref == null:
		return
	SoundManager.play_sound("click", 0.2, 0.0)
	for i in range(5):
		var x := randf_range(120.0, LevelGenerator.MAP_WIDTH * LevelGenerator.TILE_SIZE - 120.0)
		# Innerhalb der Arena spawnen: Die Höhlen-Variante besitzt eine solide
		# Decke oberhalb von y=0, auf der Fässer sonst liegen bleiben würden.
		var y := randf_range(12.0, 48.0)
		var barrel = _level_ref.barrel_scene.instantiate()
		barrel.set("explosive", true)
		barrel.position = Vector2(x, y)
		barrel.linear_velocity = Vector2(randf_range(-30, 30), randf_range(40, 100))
		_level_ref._register_moving_object(barrel)
		_level_ref.add_child(barrel)

func _spawn_crate_rain() -> void:
	if _level_ref == null or _main_ref == null:
		return
	SoundManager.play_sound("click", 0.2, -3.0)
	for i in range(3):
		var x := randf_range(120.0, LevelGenerator.MAP_WIDTH * LevelGenerator.TILE_SIZE - 120.0)
		var y := randf_range(12.0, 48.0)
		var crate = _level_ref.crate_scene.instantiate()
		crate.set("crate_size", randf_range(0.75, 1.05))
		crate.set("health", 2)
		crate.set("max_health", 2)
		crate.connect("crate_broken", Callable(_level_ref, "_on_crate_broken"))
		crate.position = Vector2(x, y)
		crate.linear_velocity = Vector2(randf_range(-30, 30), randf_range(40, 100))
		_level_ref._register_moving_object(crate)
		_level_ref.add_child(crate)

func _get_leading_player(players: Array[Player]) -> Player:
	var best: Player = null
	var best_score := -INF
	for p in players:
		if not is_instance_valid(p) or p.is_dead or p.current_health <= 0.0:
			continue
		var score := 0.0
		var score_index := p.player_index - 1
		if score_index >= 0 and score_index < Global.player_scores.size():
			score = float(Global.player_scores[score_index])
		if best == null or score > best_score:
			best = p
			best_score = score
	return best

func _trigger_laser_hazard(players: Array[Player]) -> void:
	if _main_ref == null:
		return
	var map_w := float(LevelGenerator.MAP_WIDTH * LevelGenerator.TILE_SIZE)
	var map_h := float(LevelGenerator.MAP_HEIGHT * LevelGenerator.TILE_SIZE)

	var p_start: Vector2
	var p_end: Vector2

	var orient := randi() % 3
	if orient == 0:
		# Horizontal beam across arena
		var y := randf_range(160.0, map_h - 140.0)
		p_start = Vector2(0, y)
		p_end = Vector2(map_w, y)
	elif orient == 1:
		# Vertical beam cutting through
		var x := randf_range(180.0, map_w - 180.0)
		p_start = Vector2(x, 0)
		p_end = Vector2(x, map_h)
	else:
		# Diagonal beam
		if randf() < 0.5:
			p_start = Vector2(0, randf_range(100, 300))
			p_end = Vector2(map_w, randf_range(map_h - 300, map_h - 100))
		else:
			p_start = Vector2(map_w, randf_range(100, 300))
			p_end = Vector2(0, randf_range(map_h - 300, map_h - 100))

	var laser := OrbitalLaserClass.new()
	laser.setup(p_start, p_end, players)
	_main_ref.add_child(laser)

func _trigger_meteor_shower(players: Array[Player]) -> void:
	if _main_ref == null or _level_ref == null:
		return
	for i in range(3):
		var target := _level_ref.find_random_platform_top()
		if target == Vector2.INF:
			target = Vector2(randf_range(200, 1000), 600)
		var meteor := MeteorHazardClass.new()
		meteor.setup(target, players)
		_main_ref.add_child(meteor)

func _setup_wind_overlay() -> void:
	if not is_instance_valid(_main_ref):
		return
	_wind_overlay = Node2D.new()
	_wind_overlay.visible = false
	_main_ref.add_child(_wind_overlay)

	var streaks: Array[Vector2] = []
	for i in range(18):
		streaks.append(Vector2(randf_range(0, 1400), randf_range(50, 750)))

	_wind_overlay.draw.connect(func():
		var col := Color(0.8, 0.95, 1.0, 0.35)
		var len := 45.0 * _wind_direction
		for pt in streaks:
			_wind_overlay.draw_line(pt, pt + Vector2(len, 0), col, 2.5)
	)

func get_bonus_card_drafters() -> Array[int]:
	var bonus: Array[int] = []

	# 1. Beute / Coin Rush: Spieler mit den meisten Münzen
	if has_modifier("bounty") and not player_coins.is_empty():
		var max_c := 0
		for slot in player_coins.keys():
			max_c = maxi(max_c, int(player_coins[slot]))
		if max_c > 0:
			for slot in player_coins.keys():
				if int(player_coins[slot]) == max_c:
					bonus.append(int(slot))

	# 2. Piñata: Spieler mit dem meisten Schaden am Lama
	if has_modifier("pinata") and is_instance_valid(current_pinata) and not current_pinata.damage_by_player.is_empty():
		var max_dmg := 0.0
		var top_slot := 0
		for slot in current_pinata.damage_by_player.keys():
			var dmg := float(current_pinata.damage_by_player[slot])
			if dmg > max_dmg:
				max_dmg = dmg
				top_slot = int(slot)
		if top_slot > 0 and max_dmg > 5.0 and not bonus.has(top_slot):
			bonus.append(top_slot)

	return bonus

func clear_round() -> void:
	if is_instance_valid(current_coin_node):
		current_coin_node.queue_free()
	if is_instance_valid(current_heal_zone):
		current_heal_zone.queue_free()
	if is_instance_valid(current_pinata):
		current_pinata.queue_free()
	if is_instance_valid(_wind_overlay):
		_wind_overlay.queue_free()

	current_coin_node = null
	current_heal_zone = null
	current_pinata = null
	_wind_overlay = null
	active_modifiers.clear()
