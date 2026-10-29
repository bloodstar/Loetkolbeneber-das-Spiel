class_name LevelModifierManager
extends Node

const BountyCoinClass = preload("res://scripts/level/bounty_coin.gd")
const MovingHealZoneClass = preload("res://scripts/level/moving_heal_zone.gd")
const PinataLamaClass = preload("res://scripts/level/pinata_lama.gd")
const OrbitalLaserClass = preload("res://scripts/level/orbital_laser.gd")
const MeteorHazardClass = preload("res://scripts/level/meteor.gd")
const NightOverlayClass = preload("res://scripts/level/night_overlay.gd")
const WindOverlayClass = preload("res://scripts/level/wind_overlay.gd")

# Sturmwind: Böen schwellen an, halten und flauen wieder ab.
const WIND_GUST_RAMP: float = 1.3       # s An- bzw. Abschwellen
const WIND_GUST_HOLD: float = 2.4       # s volle Stärke
const WIND_PLAYER_PUSH: float = 230.0   # px/s Drift bei voller Stärke (Laufen: 300)
const WIND_BULLET_ACCEL: float = 650.0  # px/s² seitliche Beschleunigung
const WIND_OBJECT_ACCEL: float = 1150.0 # px/s² für Kisten/Fässer (reicht gegen Reibung)
const LavaFloodMarkerClass = preload("res://scripts/level/lava_flood_marker.gd")
const FloorLavaOverlayClass = preload("res://scripts/level/floor_lava_overlay.gd")
const StormZoneClass = preload("res://scripts/level/storm_zone.gd")
const HotPotatoDevilClass = preload("res://scripts/level/hot_potato_devil.gd")

signal modifiers_rolled(active_modifiers: Array[Dictionary])
signal wind_changed(active: bool, direction: float)
signal coin_collected(player_slot: int, count: int)
signal pinata_hit(player_slot: int, total_damage: float)
signal devil_target_changed(player_slot: int, angry: bool)

const LevelModifierDefsClass = preload("res://scripts/level_modifier_defs.gd")
# Brawl: Nahkampfreichweite +50 %, Abklingzeit -50 %.
const BRAWL_RANGE_MULT: float = 1.5
const BRAWL_COOLDOWN_MULT: float = 0.5
const MODIFIERS: Dictionary = LevelModifierDefsClass.MODIFIERS

# Aktive Modifier der laufenden Runde
var active_modifiers: Array[String] = []

# Game References
var _main_ref: Node2D = null
var _level_ref: LevelGenerator = null

# Timers
var _wind_interval_timer: float = 10.0
var _wind_gust_time: float = -1.0  # < 0: gerade keine Böe
var _wind_strength: float = 0.0     # 0..1, Hüllkurve der aktuellen Böe
var _wind_direction: float = 1.0
var _replica_wind: float = 0.0  # Client: zuletzt vom Host gemeldeter Wind (0 = aus)

var _tnt_timer: float = 10.0
const LASER_INTERVAL := 10.0 # Sekunden zwischen Orbital-Lasern (auch erster Schuss)
var _laser_timer: float = LASER_INTERVAL
var _meteor_timer: float = 12.0
var _lava_timer: float = 0.0
var _regen_timer: float = 0.5
var _crate_timer: float = 9.0
# Kugelregen / Kugelhagel (host-seitig, Kugeln sind Map-Objekte mit Netz-ID).
const BALL_RAIN_INTERVAL: float = 4.0
const BALL_RAIN_COUNT: int = 5
const BALL_HAIL_INTERVAL: float = 16.0
const BALL_HAIL_FIRST: float = 6.0
const BALL_HAIL_COUNT: int = 24
const BALL_MODIFIER_MAX: int = 60
const BALL_MODIFIER_LIFETIME: float = 28.0
var _ball_rain_timer: float = BALL_RAIN_INTERVAL
var _ball_hail_timer: float = BALL_HAIL_FIRST

# Lava-Flut: ein Zyklus = Ruhe (mit Warnung am Ende), Anstieg, Halten, Absinken.
const FLOOD_REST: float = 11.0
const FLOOD_WARN: float = 3.0
const FLOOD_RISE: float = 7.0
const FLOOD_HOLD: float = 5.0
const FLOOD_FALL: float = 7.0
const FLOOD_PERIOD: float = FLOOD_REST + FLOOD_RISE + FLOOD_HOLD + FLOOD_FALL
# Startwert des Zyklus: Die erste Flut warnt 5 s nach dem Countdown.
const FLOOD_START_TIME: float = 3.0
var _flood_time: float = FLOOD_START_TIME
var _flood_peak_frac: float = 0.4
var _flood_y: float = -1.0       # aktuelle Oberfläche in px, -1 = keine Flut
var _flood_warn_y: float = -1.0  # Ziel der nächsten Flut während der Warnung
var _flood_marker: LavaFloodMarkerClass = null
var _floor_lava_overlay: Node2D = null

# Zone: startet größer als die Karte und schrumpft in Stufen (Warten, dann
# Schrumpfen). Danach wandert ein kleiner Kreis über die Karte. "frac" ist
# der Zielradius als Anteil der halben Kartendiagonale (0 = Endkreis).
const ZONE_STAGES: Array = [
	{"hold": 10.0, "shrink": 14.0, "frac": 0.6, "tick_damage": 3.0},
	{"hold": 7.0, "shrink": 11.0, "frac": 0.33, "tick_damage": 5.0},
	{"hold": 5.0, "shrink": 9.0, "frac": 0.0, "tick_damage": 7.0},
]
const ZONE_START_MARGIN: float = 140.0   # px über die Kartenecken hinaus
const ZONE_FINAL_RADIUS: float = 115.0
const ZONE_WANDER_SPEED: float = 55.0    # px/s
const ZONE_WANDER_TICK_DAMAGE: float = 8.0
const ZONE_TICK: float = 0.5             # s zwischen Schadensticks
# Im Sudden Death läuft die Zone doppelt so schnell und bleibt über der Lava.
const ZONE_SUDDEN_DEATH_SPEED: float = 2.0
var _zone_stage: int = 0
var _zone_phase_time: float = 0.0
var _zone_shrinking: bool = false
var _zone_center: Vector2 = Vector2.ZERO
var _zone_radius: float = -1.0
var _zone_from_center: Vector2 = Vector2.ZERO
var _zone_from_radius: float = 0.0
var _zone_next_center: Vector2 = Vector2.ZERO
var _zone_next_radius: float = -1.0
var _zone_wander_target: Vector2 = Vector2.ZERO
var _zone_tick_timer: float = ZONE_TICK
var _zone_node: StormZoneClass = null
var _replica_zone_shrinking: bool = false

# Heiße Kartoffel: Wer vom Ziel getroffen wird, gibt den Teufel weiter. Trifft
# ihn jemand anderes, wird dieser das Ziel und der Teufel ist DEVIL_ANGRY_TIME
# lang wütend (schneller, schießt öfter, Ziel gesperrt). DEVIL_SWITCH_GRACE
# verhindert, dass Schrotkugeln derselben Salve gleich weiterreichen.
const DEVIL_ANGRY_TIME: float = 5.0
const DEVIL_SWITCH_GRACE: float = 0.6
var current_devil: HotPotatoDevil = null
var _devil_grace: float = 0.0
var _replica_devil_slot: int = 0
var _replica_devil_angry: bool = false

# Tracking per round
var player_coins: Dictionary = {}         # slot -> coin count
var current_coin_node: BountyCoin = null
var current_heal_zone: MovingHealZone = null
var current_pinata: PinataLama = null

var _wind_overlay: WindOverlayClass = null
var _night_overlay: Node2D = null

# Netzwerk-Client: Münze, Lama und Heilzone sind nur Kopien des Host-Zustands.
var is_replica: bool = false
var _coin_net_id: int = 0       # Host: zählt jede gespawnte Münze hoch
var _replica_coin_id: int = -1  # Client: ID der aktuell angezeigten Münze

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
		# Ohne Nahkampf (Lobby-Regel) ergibt Brawl keinen Sinn.
		if k == "brawl" and not Global.melee_enabled:
			continue
		# Ohne aktive Powerups (Lobby-Reiter "Powerups") regnet es nichts.
		if k == "powerup_rain" and not Global.has_active_powerups():
			continue
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
	_wind_gust_time = -1.0
	_wind_strength = 0.0
	_tnt_timer = 10.0
	_laser_timer = LASER_INTERVAL
	_meteor_timer = 12.0
	_lava_timer = 0.0
	_regen_timer = 0.5
	_crate_timer = 9.0
	_ball_rain_timer = 2.0
	_ball_hail_timer = BALL_HAIL_FIRST
	_flood_time = FLOOD_START_TIME
	_flood_peak_frac = randf_range(1.0 / 3.0, 0.5)
	_flood_y = -1.0
	_flood_warn_y = -1.0

	var arena_rect := Rect2(60, 60, LevelGenerator.map_w * LevelGenerator.TILE_SIZE - 120, LevelGenerator.map_h * LevelGenerator.TILE_SIZE - 120)

	# 1. Beute (Coin Rush). Clients warten auf die Münze aus dem Host-Snapshot.
	_replica_coin_id = -1
	if has_modifier("bounty") and not is_replica:
		_spawn_bounty_coin()

	# 2. Wandernde Heilzone
	if has_modifier("heal_zone"):
		current_heal_zone = MovingHealZoneClass.new()
		current_heal_zone.is_replica = is_replica
		_main_ref.add_child(current_heal_zone)
		current_heal_zone.setup_bounds(arena_rect)

	# 3. Piñata-Lama
	if has_modifier("pinata"):
		current_pinata = PinataLamaClass.new()
		current_pinata.is_replica = is_replica
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

	# 5. Nacht: rein lokale Darstellung, läuft auf Host und Clients.
	if has_modifier("night"):
		_night_overlay = NightOverlayClass.new()
		_night_overlay.setup(_main_ref)
		_main_ref.add_child(_night_overlay)

	# 6. Lava-Flut: Warnlinie lokal, Höhe kommt auf Clients per Snapshot.
	if has_modifier("lava_flood"):
		_flood_marker = LavaFloodMarkerClass.new()
		_main_ref.add_child(_flood_marker)

	# 7. Boden ist Lava: sichtbare Lavaschicht, lokal auf Host und Clients.
	if has_modifier("floor_is_lava"):
		_floor_lava_overlay = FloorLavaOverlayClass.new()
		_main_ref.add_child(_floor_lava_overlay)

	# 8. Zone: Host simuliert, Clients zeigen den Snapshot-Zustand.
	if has_modifier("zone"):
		_setup_zone()

	# 9. Heiße Kartoffel: Host simuliert, Clients folgen dem Snapshot.
	if has_modifier("hot_potato"):
		_setup_devil()

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
	if has_modifier("brawl"):
		player.melee_cooldown *= BRAWL_COOLDOWN_MULT
		player.melee_range_mult *= BRAWL_RANGE_MULT
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

	# --- Kugelregen / Kugelhagel ---
	if has_modifier("ball_rain"):
		_ball_rain_timer -= delta
		if _ball_rain_timer <= 0.0:
			_ball_rain_timer = BALL_RAIN_INTERVAL
			_spawn_ball_drop(BALL_RAIN_COUNT, 0.2, false)
	if has_modifier("ball_hail"):
		_ball_hail_timer -= delta
		if _ball_hail_timer <= 0.0:
			_ball_hail_timer = BALL_HAIL_INTERVAL
			_spawn_ball_drop(BALL_HAIL_COUNT, 0.3, true)

	# --- Windstoß ---
	if has_modifier("wind"):
		if _wind_gust_time >= 0.0:
			_wind_gust_time += delta
			if _wind_gust_time >= WIND_GUST_RAMP * 2.0 + WIND_GUST_HOLD:
				_wind_gust_time = -1.0
				_wind_strength = 0.0
				_apply_wind_forces(delta, players, 0.0)
				wind_changed.emit(false, 0.0)
				if is_instance_valid(_wind_overlay):
					_wind_overlay.set_wind(false, _wind_direction)
			else:
				_wind_strength = _wind_envelope(_wind_gust_time)
				var wind := _wind_direction * _wind_strength
				_apply_wind_forces(delta, players, wind)
				if is_instance_valid(_wind_overlay):
					_wind_overlay.set_gust(wind)
		else:
			_wind_interval_timer -= delta
			if _wind_interval_timer <= 0.0:
				_wind_interval_timer = 10.0
				_wind_gust_time = 0.0
				_wind_strength = 0.0
				_wind_direction = -1.0 if randf() < 0.5 else 1.0
				wind_changed.emit(true, _wind_direction)
				SoundManager.play_sound("dash", 0.4, -2.0)
				if is_instance_valid(_wind_overlay):
					_wind_overlay.set_wind(true, _wind_direction)

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
			_laser_timer = LASER_INTERVAL
			_trigger_laser_hazard(players)

	# --- Meteoritenschauer ---
	if has_modifier("meteor_shower"):
		_meteor_timer -= delta
		if _meteor_timer <= 0.0:
			_meteor_timer = 12.0
			_trigger_meteor_shower(players)

	# --- Lava-Flut ---
	if has_modifier("lava_flood"):
		_update_lava_flood(delta)

	# --- Zone ---
	if has_modifier("zone"):
		_update_zone(delta, players)

	# --- Heiße Kartoffel ---
	if has_modifier("hot_potato"):
		_update_devil(delta, players)

	# --- Boden ist Lava ---
	if has_modifier("floor_is_lava") and _level_ref != null:
		# In diskreten Ticks statt pro Frame: take_damage() löst Trefferblitz,
		# Kamera-Shake und Statistiken aus und würde sonst 60-mal/s feuern.
		_lava_timer -= delta
		if _lava_timer <= 0.0:
			_lava_timer = 0.5
			var floor_y := (LevelGenerator.map_h - 3.2) * LevelGenerator.TILE_SIZE
			for p in players:
				if is_instance_valid(p) and p.current_health > 0 and p.global_position.y >= floor_y:
					p.take_damage(16.0, Vector2(0, -120.0))

# Bezugshöhe der Flut: die sichtbare Arena. Auf hohen Scroll-Karten (Turm,
# Himmelsleiter) flutet sie wie in einer normalen Arena nur den unteren Teil,
# statt die halbe Karte zu verschlucken.
func _flood_reference_height() -> float:
	return float(mini(LevelGenerator.map_h, LevelGenerator.MAP_HEIGHT)) * LevelGenerator.TILE_SIZE

func _flood_peak_y() -> float:
	var bottom := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	return bottom - _flood_peak_frac * _flood_reference_height()

func _update_lava_flood(delta: float) -> void:
	_flood_time += delta
	if _flood_time >= FLOOD_PERIOD:
		_flood_time -= FLOOD_PERIOD
		# Jede Flut steigt unterschiedlich hoch: 1/3 bis 1/2 der Arena.
		_flood_peak_frac = randf_range(1.0 / 3.0, 0.5)
	var bottom := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	var peak_y := _flood_peak_y()
	var level := 0.0
	var t := _flood_time
	if t < FLOOD_REST:
		level = 0.0
	elif t < FLOOD_REST + FLOOD_RISE:
		level = smoothstep(0.0, 1.0, (t - FLOOD_REST) / FLOOD_RISE)
	elif t < FLOOD_REST + FLOOD_RISE + FLOOD_HOLD:
		level = 1.0
	else:
		level = 1.0 - smoothstep(0.0, 1.0, (t - FLOOD_REST - FLOOD_RISE - FLOOD_HOLD) / FLOOD_FALL)
	# Ganz unten liegt die Oberfläche knapp unter dem Kartenrand und ist aus.
	_flood_y = lerpf(bottom + 4.0, peak_y, level) if level > 0.0 else -1.0
	var warn := -1.0
	if t >= FLOOD_REST - FLOOD_WARN and t < FLOOD_REST:
		warn = peak_y
	_set_flood_warning(warn)

func _set_flood_warning(y: float) -> void:
	if y >= 0.0 and _flood_warn_y < 0.0:
		SoundManager.play_sound("warning", 0.05, 0.0)
	_flood_warn_y = y
	if is_instance_valid(_flood_marker):
		_flood_marker.set_target(y)

func _zone_map_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(LevelGenerator.map_w, LevelGenerator.map_h) * LevelGenerator.TILE_SIZE)

func _zone_stage_radius(stage: int) -> float:
	var frac := float(ZONE_STAGES[stage]["frac"])
	var half_diag := _zone_map_rect().size.length() * 0.5
	return maxf(ZONE_FINAL_RADIUS, half_diag * frac)

func _setup_zone() -> void:
	_zone_node = StormZoneClass.new()
	_zone_node.is_replica = is_replica
	_main_ref.add_child(_zone_node)
	_replica_zone_shrinking = false
	if is_replica:
		return
	var rect := _zone_map_rect()
	_zone_stage = 0
	_zone_phase_time = 0.0
	_zone_shrinking = false
	_zone_tick_timer = ZONE_TICK
	_zone_center = rect.get_center()
	_zone_radius = rect.size.length() * 0.5 + ZONE_START_MARGIN
	_zone_pick_next()
	_zone_node.set_state(_zone_center, _zone_radius, _zone_next_center, _zone_next_radius)

# Nächste Zone liegt wie in Fortnite innerhalb der aktuellen.
func _zone_pick_next() -> void:
	var next_r := _zone_stage_radius(_zone_stage)
	var max_offset := maxf(0.0, _zone_radius - next_r)
	var candidate := _zone_center + Vector2.from_angle(randf() * TAU) * randf() * max_offset
	_zone_next_center = _zone_clamp_center(candidate, next_r)
	_zone_next_radius = next_r

func _zone_pick_wander_target() -> Vector2:
	var rect := _zone_map_rect()
	var best := _zone_center
	for i in 6:
		var candidate := _zone_clamp_center(Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		), _zone_radius)
		best = candidate
		if candidate.distance_to(_zone_center) > 220.0:
			break
	return best

# Hält den Kreis größtenteils auf der Karte. Im Sudden Death liegt die
# Kreismitte über der Endhöhe der Lava, damit immer ein sicherer Platz bleibt.
func _zone_clamp_center(p: Vector2, r: float) -> Vector2:
	var rect := _zone_map_rect()
	var inset_x := minf(r * 0.6 + 30.0, rect.size.x * 0.5)
	var inset_y := minf(r * 0.6 + 30.0, rect.size.y * 0.5)
	var out := Vector2(
		clampf(p.x, rect.position.x + inset_x, rect.end.x - inset_x),
		clampf(p.y, rect.position.y + inset_y, rect.end.y - inset_y)
	)
	if _main_ref != null and _main_ref.get("is_sudden_death") == true:
		var stop_y := float(_main_ref.get("sudden_death_lava_stop_y"))
		if stop_y > -INF:
			out.y = minf(out.y, stop_y - r * 0.3)
	return out

func _update_zone(delta: float, players: Array[Player]) -> void:
	if _zone_radius <= 0.0:
		return
	var speed := ZONE_SUDDEN_DEATH_SPEED if _main_ref.get("is_sudden_death") == true else 1.0
	if _zone_stage < ZONE_STAGES.size():
		var stage: Dictionary = ZONE_STAGES[_zone_stage]
		_zone_next_center = _zone_clamp_center(_zone_next_center, _zone_next_radius)
		_zone_phase_time += delta * speed
		if not _zone_shrinking and _zone_phase_time >= float(stage["hold"]):
			_zone_phase_time -= float(stage["hold"])
			_zone_shrinking = true
			_zone_from_center = _zone_center
			_zone_from_radius = _zone_radius
			SoundManager.play_sound("warning", 0.05, 0.0)
		if _zone_shrinking:
			var k := clampf(_zone_phase_time / float(stage["shrink"]), 0.0, 1.0)
			var s := smoothstep(0.0, 1.0, k)
			_zone_center = _zone_from_center.lerp(_zone_next_center, s)
			_zone_radius = lerpf(_zone_from_radius, _zone_next_radius, s)
			if k >= 1.0:
				_zone_stage += 1
				_zone_shrinking = false
				_zone_phase_time = 0.0
				if _zone_stage < ZONE_STAGES.size():
					_zone_pick_next()
				else:
					_zone_next_radius = -1.0
					_zone_wander_target = _zone_pick_wander_target()
	else:
		var target := _zone_clamp_center(_zone_wander_target, _zone_radius)
		_zone_center = _zone_center.move_toward(target, ZONE_WANDER_SPEED * speed * delta)
		if _zone_center.distance_to(target) < 8.0:
			_zone_wander_target = _zone_pick_wander_target()
	if is_instance_valid(_zone_node):
		_zone_node.set_state(_zone_center, _zone_radius, _zone_next_center, _zone_next_radius)

	# Schaden in Ticks wie bei "Boden ist Lava"; steigt mit jeder Stufe.
	_zone_tick_timer -= delta
	if _zone_tick_timer > 0.0:
		return
	_zone_tick_timer = ZONE_TICK
	var damage := ZONE_WANDER_TICK_DAMAGE
	if _zone_stage < ZONE_STAGES.size():
		damage = float(ZONE_STAGES[_zone_stage]["tick_damage"])
	for p in players:
		if is_instance_valid(p) and not p.is_dead and p.current_health > 0.0 \
				and p.global_position.distance_to(_zone_center) > _zone_radius:
			p.take_damage(damage, Vector2.ZERO)

## Aktuelle Zone für Bots: {"center", "radius"}, leer ohne Zone.
func get_zone_state() -> Dictionary:
	if not has_modifier("zone") or not is_instance_valid(_zone_node) or _zone_node.radius <= 0.0:
		return {}
	return {"center": _zone_node.center, "radius": _zone_node.radius}

func _setup_devil() -> void:
	var rect := _zone_map_rect()
	current_devil = HotPotatoDevilClass.new()
	current_devil.is_replica = is_replica
	current_devil.position = Vector2(rect.get_center().x, rect.position.y + 90.0)
	current_devil.setup_bounds(rect.grow(-30.0))
	_main_ref.add_child(current_devil)
	_devil_grace = 0.0
	_replica_devil_slot = 0
	_replica_devil_angry = false
	if not is_replica:
		current_devil.hit_by.connect(_on_devil_hit)

# Erstes Ziel ist der Führende, bei Gleichstand ein zufälliger davon. Stirbt
# das Ziel, jagt der Teufel einen zufälligen Überlebenden.
func _update_devil(delta: float, players: Array[Player]) -> void:
	if not is_instance_valid(current_devil):
		return
	_devil_grace = maxf(0.0, _devil_grace - delta)
	var t := current_devil.target
	if is_instance_valid(t) and not t.is_dead and t.current_health > 0.0:
		return
	var next: Player = null
	if t == null:
		next = _pick_devil_leader(players)
	else:
		next = _pick_random_living(players, [t])
	if next != null:
		_set_devil_target(next, false)

func _on_devil_hit(attacker: Player) -> void:
	if not is_instance_valid(current_devil) or not is_instance_valid(attacker):
		return
	if attacker.is_dead or _devil_grace > 0.0 or current_devil.is_angry():
		return
	if attacker == current_devil.target:
		var next := _pick_devil_pass_target(attacker)
		if next != null:
			_set_devil_target(next, false)
	else:
		_set_devil_target(attacker, true)

func _set_devil_target(p: Player, angry: bool) -> void:
	current_devil.target = p
	current_devil.on_target_changed(angry, DEVIL_ANGRY_TIME)
	_devil_grace = DEVIL_SWITCH_GRACE
	SoundManager.play_sound("warning", 0.1, -3.0 if angry else -6.0)
	devil_target_changed.emit(p.player_index, angry)

func _devil_candidates() -> Array[Player]:
	var result: Array[Player] = []
	if _main_ref == null:
		return result
	var list = _main_ref.get("players")
	if not (list is Array):
		return result
	for p in list:
		if is_instance_valid(p) and p is Player and not p.is_dead and p.current_health > 0.0:
			result.append(p)
	return result

# Weitergeben: bevorzugt an einen Gegner des Werfers (im Teammodus nicht an
# den eigenen Mitspieler), sonst an irgendeinen anderen Überlebenden.
func _pick_devil_pass_target(from: Player) -> Player:
	var enemies: Array[Player] = []
	var others: Array[Player] = []
	for p in _devil_candidates():
		if p == from:
			continue
		others.append(p)
		if p.team_id != from.team_id:
			enemies.append(p)
	if not enemies.is_empty():
		return enemies.pick_random()
	if not others.is_empty():
		return others.pick_random()
	return null

func _pick_random_living(players: Array[Player], exclude: Array) -> Player:
	var pool: Array[Player] = []
	for p in players:
		if is_instance_valid(p) and not p.is_dead and p.current_health > 0.0 and not exclude.has(p):
			pool.append(p)
	return pool.pick_random() if not pool.is_empty() else null

func _pick_devil_leader(players: Array[Player]) -> Player:
	var best_score := -INF
	var leaders: Array[Player] = []
	for p in players:
		if not is_instance_valid(p) or p.is_dead or p.current_health <= 0.0:
			continue
		var score := 0.0
		var score_index := p.player_index - 1
		if score_index >= 0 and score_index < Global.player_scores.size():
			score = float(Global.player_scores[score_index])
		if score > best_score:
			best_score = score
			leaders.clear()
		if score == best_score:
			leaders.append(p)
	return leaders.pick_random() if not leaders.is_empty() else null

## Teufel für Bots: {"pos", "target_slot", "angry"}, leer ohne Modifier.
func get_devil_state() -> Dictionary:
	if not has_modifier("hot_potato") or not is_instance_valid(current_devil):
		return {}
	return {
		"pos": current_devil.global_position,
		"target_slot": current_devil.get_target_slot(),
		"angry": current_devil.is_angry(),
	}

## Oberfläche der Flut-Lava in px (kleineres y = höher), INF ohne Flut.
func get_lava_flood_y() -> float:
	if not has_modifier("lava_flood") or _flood_y < 0.0:
		return INF
	return _flood_y

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
	_coin_net_id += 1

# --- Netzwerk-Sync (Host -> Clients) ---

func get_network_snapshot() -> Dictionary:
	var data := {}
	if has_modifier("bounty"):
		data["coins"] = player_coins.duplicate()
		if is_instance_valid(current_coin_node) and not current_coin_node.is_queued_for_deletion():
			data["coin_id"] = _coin_net_id
			data["coin_pos"] = current_coin_node.get_base_position()
	if has_modifier("pinata") and is_instance_valid(current_pinata):
		data["pinata"] = current_pinata.get_network_state()
	if has_modifier("heal_zone") and is_instance_valid(current_heal_zone):
		data["heal_zone"] = current_heal_zone.global_position
	if has_modifier("wind"):
		data["wind"] = _wind_direction * _wind_strength if _wind_gust_time >= 0.0 else 0.0
	if has_modifier("lava_flood"):
		data["flood"] = [_flood_y, _flood_warn_y]
	if has_modifier("zone"):
		data["zone"] = [_zone_center, _zone_radius, _zone_next_center, _zone_next_radius, _zone_shrinking]
	if has_modifier("hot_potato") and is_instance_valid(current_devil):
		data["devil"] = current_devil.get_network_state()
	return data

func apply_network_snapshot(data: Dictionary) -> void:
	if not is_replica or _main_ref == null:
		return

	if has_modifier("bounty"):
		var coins = data.get("coins", {})
		if coins is Dictionary:
			for slot in coins.keys():
				var count := int(coins[slot])
				if count > int(player_coins.get(slot, 0)):
					coin_collected.emit(int(slot), count)
			player_coins = coins.duplicate()

		var coin_id := int(data.get("coin_id", -1))
		if coin_id != _replica_coin_id:
			# Alte Münze wurde eingesammelt: Effekt an der alten Stelle zeigen.
			if is_instance_valid(current_coin_node):
				if _replica_coin_id >= 0:
					current_coin_node.play_collect_effect()
				current_coin_node.queue_free()
			current_coin_node = null
			_replica_coin_id = coin_id
			if coin_id >= 0:
				var coin := BountyCoinClass.new()
				coin.is_replica = true
				_main_ref.add_child(coin)
				current_coin_node = coin
		if is_instance_valid(current_coin_node) and data.has("coin_pos"):
			current_coin_node.set_base_position(data["coin_pos"])

	if has_modifier("pinata") and is_instance_valid(current_pinata) and data.has("pinata"):
		var state: Dictionary = data["pinata"]
		var old_dmg: Dictionary = current_pinata.damage_by_player.duplicate()
		current_pinata.apply_network_state(state)
		var hit := false
		for slot in current_pinata.damage_by_player.keys():
			var total := float(current_pinata.damage_by_player[slot])
			if total > float(old_dmg.get(slot, 0.0)) + 0.01:
				hit = true
				pinata_hit.emit(int(slot), total)
		if hit:
			SoundManager.play_sound("hit", 0.4, 2.5)
			current_pinata._spawn_confetti()

	if has_modifier("heal_zone") and is_instance_valid(current_heal_zone) and data.has("heal_zone"):
		current_heal_zone.apply_network_position(data["heal_zone"])

	# Sturmwind: Clients zeigen Hinweis und Windpartikel lokal an.
	if has_modifier("wind"):
		var wind := float(data.get("wind", 0.0))
		var was_active := absf(_replica_wind) > 0.001
		var now_active := absf(wind) > 0.001
		_replica_wind = wind
		if now_active != was_active:
			wind_changed.emit(now_active, signf(wind))
			if now_active:
				SoundManager.play_sound("dash", 0.4, -2.0)
		if is_instance_valid(_wind_overlay):
			_wind_overlay.set_gust(wind)

	# Lava-Flut: Höhe und Warnlinie vom Host übernehmen.
	if has_modifier("lava_flood"):
		var flood = data.get("flood", [])
		if flood is Array and flood.size() >= 2:
			_flood_y = float(flood[0])
			_set_flood_warning(float(flood[1]))

	# Zone: Kreis, Vorschau und Warnton beim Schrumpfbeginn.
	if has_modifier("zone") and is_instance_valid(_zone_node):
		var zone = data.get("zone", [])
		if zone is Array and zone.size() >= 5:
			_zone_node.apply_network_state(zone[0], float(zone[1]), zone[2], float(zone[3]))
			var shrinking := bool(zone[4])
			if shrinking and not _replica_zone_shrinking:
				SoundManager.play_sound("warning", 0.05, 0.0)
			_replica_zone_shrinking = shrinking

	# Heiße Kartoffel: Position, Ziel und Wut übernehmen, Zielwechsel melden.
	if has_modifier("hot_potato") and is_instance_valid(current_devil):
		var devil = data.get("devil", {})
		if devil is Dictionary and not devil.is_empty():
			current_devil.apply_network_state(devil)
			var slot := int(devil.get("t", 0))
			var angry := float(devil.get("ang", 0.0)) > 0.0
			if slot != _replica_devil_slot or (angry and not _replica_devil_angry):
				var target_player = _main_ref.call("get_player", slot) if slot > 0 and _main_ref.has_method("get_player") else null
				current_devil.target = target_player if target_player is Player else null
				if slot > 0:
					current_devil.angry_duration = DEVIL_ANGRY_TIME
					SoundManager.play_sound("warning", 0.1, -3.0 if angry else -6.0)
					devil_target_changed.emit(slot, angry)
			_replica_devil_slot = slot
			_replica_devil_angry = angry

func _on_coin_collected(player: Node2D) -> void:
	var slot := int(player.get("player_index")) if player.get("player_index") != null else 1
	player_coins[slot] = int(player_coins.get(slot, 0)) + 1
	coin_collected.emit(slot, player_coins[slot])

	# Respawn next coin on another platform. Deferred, weil wir uns noch im
	# body_entered-Callback der alten Münze befinden und Godot dort keine neuen
	# Areas/Shapes aktivieren darf.
	_spawn_bounty_coin.call_deferred()

func _spawn_tnt_air_drop() -> void:
	if _level_ref == null or _main_ref == null:
		return
	NetFx.emit(_main_ref, "sound", {"snd": ["warning", 0.05, 0.0]})
	for i in range(5):
		var x := randf_range(120.0, LevelGenerator.map_w * LevelGenerator.TILE_SIZE - 120.0)
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
	NetFx.emit(_main_ref, "sound", {"snd": ["warning", 0.05, -2.0]})
	for i in range(3):
		var x := randf_range(120.0, LevelGenerator.map_w * LevelGenerator.TILE_SIZE - 120.0)
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

## Lässt count Kugeln oben in der Arena erscheinen. Beim Hagel (spread) sind
## sie gleichmäßig über die Breite verteilt, sonst zufällig. Insgesamt höchstens
## BALL_MODIFIER_MAX Kugeln gleichzeitig; sie zerfallen nach einer Weile.
func _spawn_ball_drop(count: int, big_chance: float, spread: bool) -> void:
	if _level_ref == null or _main_ref == null:
		return
	var free_slots := BALL_MODIFIER_MAX - _level_ref.get_ball_count()
	count = mini(count, free_slots)
	if count <= 0:
		return
	NetFx.emit(_main_ref, "sound", {"snd": ["warning", 0.05, -2.0 if spread else -6.0]})
	var width := LevelGenerator.map_w * LevelGenerator.TILE_SIZE
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		var x := 0.0
		if spread:
			x = lerpf(90.0, width - 90.0, (float(i) + 0.5) / float(count)) + rng.randf_range(-25.0, 25.0)
		else:
			x = rng.randf_range(120.0, width - 120.0)
		# Innerhalb der Arena spawnen (Höhlen-Variante hat eine Decke).
		var y := rng.randf_range(40.0, 70.0) - (rng.randf_range(0.0, 30.0) if spread else 0.0)
		var size := RollingBall.random_size(rng, big_chance, 0.3)
		var ball := _level_ref.spawn_ball(Vector2(x, maxf(38.0, y)), RollingBall.random_material(rng), size,
			Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(60.0, 140.0)))
		ball.lifetime = BALL_MODIFIER_LIFETIME + rng.randf_range(0.0, 4.0)

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
	var map_w := float(LevelGenerator.map_w * LevelGenerator.TILE_SIZE)
	var map_h := float(LevelGenerator.map_h * LevelGenerator.TILE_SIZE)

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
	# Clients zeigen denselben Strahl, Schaden macht nur der Host.
	NetFx.send("laser", {"a": p_start, "b": p_end})

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
		NetFx.send("meteor", {"p": target})

# Böen-Hüllkurve: weich anschwellen, halten, weich abflauen (0..1).
func _wind_envelope(t: float) -> float:
	if t < WIND_GUST_RAMP:
		return smoothstep(0.0, WIND_GUST_RAMP, t)
	if t < WIND_GUST_RAMP + WIND_GUST_HOLD:
		return 1.0
	return 1.0 - smoothstep(WIND_GUST_RAMP + WIND_GUST_HOLD, WIND_GUST_RAMP * 2.0 + WIND_GUST_HOLD, t)

# Nur der Host simuliert: Spieler, Projektile und Physikobjekte werden
# geschoben. wind = Richtung * Stärke (-1..1). Impulse statt Kräfte, weil das
# hier aus _process läuft und sonst von der Bildrate abhinge.
func _apply_wind_forces(delta: float, players: Array[Player], wind: float) -> void:
	for p in players:
		if is_instance_valid(p):
			p.wind_push = wind * WIND_PLAYER_PUSH
	if wind == 0.0:
		return
	for b in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			b.velocity.x += wind * WIND_BULLET_ACCEL * delta
	for group in ["crate", "barrel", "chain_link", "rolling_ball"]:
		for o in get_tree().get_nodes_in_group(group):
			if o is RigidBody2D and is_instance_valid(o) and o.get("is_replica") != true:
				var body := o as RigidBody2D
				body.apply_central_impulse(Vector2(wind * WIND_OBJECT_ACCEL * body.mass * delta, 0.0))
	for group in ["seesaw", "chain_platform"]:
		for o in get_tree().get_nodes_in_group(group):
			if is_instance_valid(o) and o.has_method("apply_wind"):
				o.apply_wind(wind, delta)

func _setup_wind_overlay() -> void:
	if not is_instance_valid(_main_ref):
		return
	# Rein visuell und lokal: läuft auf Host und Clients.
	_wind_overlay = WindOverlayClass.new()
	_main_ref.add_child(_wind_overlay)

func get_bonus_card_drafters() -> Array[int]:
	var bonus: Array[int] = []
	for entry in get_bonus_card_draft_entries():
		bonus.append(int(entry["slot"]))
	return bonus

# Bonus-Züge mit Quelle: "gold" (Beute-Münzen) oder "pinata" (Lama-Schaden).
func get_bonus_card_draft_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
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
					entries.append({"slot": int(slot), "source": "gold"})

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
			entries.append({"slot": top_slot, "source": "pinata"})

	return entries

func clear_round() -> void:
	if is_instance_valid(current_coin_node):
		current_coin_node.queue_free()
	if is_instance_valid(current_heal_zone):
		current_heal_zone.queue_free()
	if is_instance_valid(current_pinata):
		current_pinata.queue_free()
	if is_instance_valid(_wind_overlay):
		_wind_overlay.queue_free()
	if is_instance_valid(_night_overlay):
		_night_overlay.queue_free()
	if is_instance_valid(_flood_marker):
		_flood_marker.queue_free()
	if is_instance_valid(_floor_lava_overlay):
		_floor_lava_overlay.queue_free()
	if is_instance_valid(_zone_node):
		_zone_node.queue_free()
	if is_instance_valid(current_devil):
		current_devil.queue_free()

	current_coin_node = null
	current_devil = null
	current_heal_zone = null
	current_pinata = null
	_wind_overlay = null
	_replica_wind = 0.0
	_night_overlay = null
	_flood_marker = null
	_floor_lava_overlay = null
	_zone_node = null
	_zone_radius = -1.0
	_zone_next_radius = -1.0
	_flood_y = -1.0
	_flood_warn_y = -1.0
	active_modifiers.clear()
