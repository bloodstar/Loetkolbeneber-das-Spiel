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

const MODIFIERS: Dictionary = {
	"cave": {
		"id": "cave",
		"title": "Höhle",
		"icon": "🪨",
		"description": "Feste Felswände umgeben die Arena statt der elastischen Gummiwand.",
		"color": Color(0.7, 0.7, 0.75),
	},
	"tnt_depot": {
		"id": "tnt_depot",
		"title": "TNT-Depot",
		"icon": "💣",
		"description": "Mehr TNT im Level! Alle 10 Sekunden regnen 5 TNT-Kisten herab.",
		"color": Color(1.0, 0.35, 0.15),
	},
	"wind": {
		"id": "wind",
		"title": "Sturmwind",
		"icon": "🌪️",
		"description": "Alle 10s weht ein starker Windstoß (3,5s), der Spieler pustet und Projektile bremst.",
		"color": Color(0.4, 0.85, 1.0),
	},
	"laser": {
		"id": "laser",
		"title": "Orbital-Laser",
		"icon": "🔴",
		"description": "Alle 20s feuert ein warnender Riesenlaser quer über die Map (50 Schaden).",
		"color": Color(1.0, 0.15, 0.2),
	},
	"bounty": {
		"id": "bounty",
		"title": "Münzbeute",
		"icon": "🪙",
		"description": "Münzen spawnen im Level. Wer am Ende die meisten sammelt, erhält eine Extrakarte!",
		"color": Color(1.0, 0.85, 0.2),
	},
	"heal_zone": {
		"id": "heal_zone",
		"title": "Wandernde Heilzone",
		"icon": "💖",
		"description": "Ein schwebender Heilkreis gleitet sanft über die Map und heilt 16 HP/s.",
		"color": Color(0.3, 1.0, 0.5),
	},
	"pinata": {
		"id": "pinata",
		"title": "Piñata-Lama",
		"icon": "🦙",
		"description": "Ein unsterbliches Lama rennt panisch umher. Der meiste Schaden bringt eine Extrakarte!",
		"color": Color(1.0, 0.3, 0.8),
	},
	"low_gravity": {
		"id": "low_gravity",
		"title": "Mondgravitation",
		"icon": "🌕",
		"description": "50% Gravitation! Gigantische Sprünge, Schweben und enorme Rückstöße.",
		"color": Color(0.7, 0.6, 1.0),
	},
	"floor_is_lava": {
		"id": "floor_is_lava",
		"title": "Der Boden ist Lava",
		"icon": "🌋",
		"description": "Der unterste Boden brennt! Bleib auf Kisten, Plattformen und Federn.",
		"color": Color(1.0, 0.45, 0.0),
	},
	"meteor_shower": {
		"id": "meteor_shower",
		"title": "Meteoritenschauer",
		"icon": "☄️",
		"description": "Alle 12s stürzen 3 glühende Meteore mit Bodenzielkreuzen explosiv herab.",
		"color": Color(1.0, 0.5, 0.1),
	},
	"ice_world": {
		"id": "ice_world",
		"title": "Glatteis-Welt",
		"icon": "🧊",
		"description": "Alle Plattformen sind spiegelglatt! Rasantes Schlittern und hohes Tempo.",
		"color": Color(0.5, 0.95, 1.0),
	},
	"mini_pigs": {
		"id": "mini_pigs",
		"title": "Mini-Chaos",
		"icon": "✨",
		"description": "Schrumpffluch! Alle Schweine sind 35% kleiner, flinker und schwerer zu treffen.",
		"color": Color(1.0, 0.8, 0.9),
	},
}

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

# Tracking per round
var player_coins: Dictionary = {}         # slot -> coin count
var current_coin_node: Area2D = null
var current_heal_zone: Area2D = null
var current_pinata: PinataLama = null

var _wind_overlay: Node2D = null

func roll_modifiers(seed_val: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 7777

	var roll := rng.randf() * 100.0
	var count := 0

	# Exakte Vorgabe:
	# 1% für 4 Modifier
	# 3% für 3 Modifier
	# 10% für 2 Modifier
	# 33% für 1 Modifier
	# 53% für 0 Modifier
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

	if count == 0:
		return []

	var all_keys := MODIFIERS.keys()
	all_keys.sort() # Deterministic order before shuffle

	# Fisher-Yates with seeded RNG
	for i in range(all_keys.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var temp = all_keys[i]
		all_keys[i] = all_keys[j]
		all_keys[j] = temp

	var chosen: Array[String] = []
	for k in all_keys:
		if chosen.size() >= count:
			break
		# Inkompatibilitäten in beide Auswahlrichtungen ausschließen.
		if (k == "cave" and chosen.has("floor_is_lava")) \
				or (k == "floor_is_lava" and chosen.has("cave")):
			continue
		chosen.append(k)

	return chosen

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
	if has_modifier("mini_pigs"):
		player.scale *= 0.65
		player.move_speed *= 1.25

func update_physics_modifiers(delta: float, players: Array[Player]) -> void:
	if active_modifiers.is_empty() or _main_ref == null:
		return

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
