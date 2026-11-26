class_name ChallengeDirector
extends Node2D

# Läuft eine Challenge-Runde (ChallengeDefs). Der Host simuliert Ziel, Zeit,
# Wertung und Respawns; Clients spiegeln den Zustand aus dem Snapshot
# ("challenge") und zeichnen dieselben Markierungen. Ein Kind pro Runde von
# Main, Gruppe "round_effect" (wird beim Rundenstart entfernt).
#
# Wertung: pro Team (in FFA ist jeder Slot sein eigenes Team, siehe
# Global.get_team_for_slot). Wer die Challenge gewinnt, bekommt über
# Main.challenge_finished() die normalen Rundenpunkte. Kills zählen wie immer.

const SLOT_COLORS: Array[Color] = [
	Color(1.0, 0.42, 0.42), Color(0.42, 0.7, 1.0), Color(0.5, 0.95, 0.5),
	Color(1.0, 0.85, 0.35), Color(0.85, 0.55, 1.0), Color(1.0, 0.6, 0.25),
]
## Rennen: Tor zählt, wenn die Körpermitte im Rechteck ist.
const RACE_RESPAWN_JITTER: float = 26.0
## Hügel: Radius der Zone (Seitenansicht kleiner, dort steht man auf einer Plattform).
const HILL_RADIUS_SIDE: float = 96.0
const HILL_RADIUS_ARENA: float = 118.0
## Bällebad
const BALL_START: int = 26
const BALL_WAVE: int = 3
const BALL_WAVE_EVERY: float = 2.0
const BALL_CAP: int = 72
const BALL_DAMP: float = 1.4
## Münzjagd: verlorene Münzen verschwinden nach COIN_DROP_LIFE s.
const COIN_DROP_LIFE: float = 14.0
const COIN_SNAPSHOT_EVERY: int = 2
## Lava: Abstand zur Flagge, ab dem sie berührt ist.
const FLAG_REACH: float = 46.0
## Hordenwelle: Start-Schwierigkeit (Sekunden Hordenzeit).
const WAVE_START_TIME: float = 70.0

static var current: ChallengeDirector = null

var kind: String = ""
var def: Dictionary = {}
var is_replica: bool = false
var main_node: Node = null
var level: LevelGenerator = null
var running: bool = false
var finished: bool = false
var time_left: float = 0.0
## Teamwertung (Team-ID -> Wert). In FFA ist die Team-ID der Slot.
var scores: Dictionary = {}
## Wertung pro Slot (Runden-Tore, getragene Münzen, Bälle in der Ecke, Kills).
var slot_values: Dictionary = {}
var winner_slot: int = 0

var _rng := RandomNumberGenerator.new()
var _respawns: Array = [] # {slot, t}
var _slots: Array[int] = []
var _anim: float = 0.0
var _net_count: int = 0
var hud: ChallengeHud = null

# Rennen
var checkpoints: Array[Rect2] = []
var laps: int = 3
# Hügel
var zone_center: Vector2 = Vector2.INF
var zone_radius: float = 0.0
var zone_owner: int = 0 # Team-ID, -1 umkämpft, 0 leer
# Bällebad
var pens: Array[Rect2] = []
var pen_of: Dictionary = {} # slot -> Index in pens
var _ball_t: float = 0.0
# Münzjagd
var coins: Dictionary = {} # id -> BountyCoin
var _coin_life: Dictionary = {} # id -> Restzeit (nur fallengelassene)
var _next_coin_id: int = 1
var _coin_spots: Array[Vector2] = []
# Lava
var flag_pos: Vector2 = Vector2.INF
# Hordenwelle
var wave: HordeDirector = null

static func is_active() -> bool:
	return current != null and is_instance_valid(current) and not current.finished

func _ready() -> void:
	current = self
	z_index = 3
	add_to_group("round_effect")

func _exit_tree() -> void:
	if current == self:
		current = null
	if wave != null and is_instance_valid(wave):
		wave.queue_free()
	for e in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		e.queue_free()

# ============================================================
# Aufbau
# ============================================================

func setup(main: Node, lg: LevelGenerator, id: String, seed_value: int, replica: bool) -> void:
	main_node = main
	level = lg
	kind = id
	def = ChallengeDefs.get_def(id)
	is_replica = replica
	_rng.seed = hash([maxi(1, seed_value), "challenge_run", id])
	time_left = float(def.get("time", 60.0))
	_slots = Global.get_round_player_indices()
	for s in _slots:
		slot_values[s] = 0.0
		scores[Global.get_team_for_slot(s)] = 0.0
	match kind:
		"race":
			laps = int(def.get("laps", 3))
			for r in ArenaBuilder.current_map.get("checkpoints", []):
				checkpoints.append(_tile_rect(r))
		"ballpit":
			for r in ArenaBuilder.current_map.get("pens", []):
				pens.append(_tile_rect(r))
			for i in range(_slots.size()):
				if pens.is_empty():
					break
				pen_of[_slots[i]] = i % pens.size()
			if not is_replica:
				_place_players_in_pens()
		"hill":
			if not is_replica:
				_pick_zone()
		"coins":
			if not is_replica:
				_collect_coin_spots()
		"lava":
			if not is_replica:
				flag_pos = _highest_spot()
			# Die Turm-Lava hält in der Challenge nicht unter dem Gipfel an.
			var lava: Dictionary = main.get("rising_lava")
			if not lava.is_empty():
				lava["stop_y"] = -INF
				lava["speed"] = float(def.get("lava_speed", 26.0))
				lava["delay"] = 3.0
		"wave":
			wave = HordeDirector.new()
			wave.name = "ChallengeWave"
			wave.pvp_wave = true
			wave.is_replica = is_replica
			wave.main_node = main
			wave.player_count = maxi(1, _slots.size())
			main.add_child(wave)
	hud = ChallengeHud.new()
	hud.name = "ChallengeHud"
	add_child(hud)
	hud.bind(self)
	queue_redraw()

func _tile_rect(r: Array) -> Rect2:
	var t := LevelGenerator.TILE_SIZE
	var a := Vector2(float(r[0]), float(r[1])) * t
	var b := Vector2(float(r[2]), float(r[3])) * t
	return Rect2(a, b - a)

## Nach dem Countdown (Main._end_round_countdown).
func start() -> void:
	if is_replica:
		running = true
		return
	running = true
	match kind:
		"ballpit":
			for i in range(BALL_START):
				_spawn_ball(true)
		"coins":
			for i in range(int(def.get("coins_alive", 7))):
				_spawn_coin(Vector2.INF)
		"wave":
			if wave != null:
				wave.start(main_node, _rng.randi(), _slots.size())
				wave.run_time = WAVE_START_TIME

# ============================================================
# Host-Simulation
# ============================================================

func _physics_process(delta: float) -> void:
	_anim += delta
	queue_redraw()
	if is_replica or not running or finished:
		return
	if Global.current_state != Global.GameState.PLAYING:
		return
	time_left = maxf(0.0, time_left - delta)
	_update_respawns(delta)
	match kind:
		"race":
			_update_race()
		"hill":
			_update_hill(delta)
		"ballpit":
			_update_ballpit(delta)
		"coins":
			_update_coins(delta)
		"lava":
			_update_lava()
		"wave":
			_update_wave()
	if finished:
		return
	if time_left <= 0.0:
		_finish(_leader_team())

func _alive_players() -> Array[Player]:
	var out: Array[Player] = []
	if main_node == null:
		return out
	for p in main_node.players:
		if is_instance_valid(p) and not p.is_dead and p.current_health > 0.0:
			out.append(p)
	return out

func _recount_teams() -> void:
	for k in scores.keys():
		scores[k] = 0.0
	for s in slot_values.keys():
		var team := Global.get_team_for_slot(int(s))
		scores[team] = float(scores.get(team, 0.0)) + float(slot_values[s])

## Team mit der höchsten Wertung. Gleichstand: das Team mit den meisten
## Rundenpunkten im Match, dann die kleinere Team-ID.
func _leader_team() -> int:
	var best := 0
	var best_v := -INF
	for k in scores.keys():
		var v := float(scores[k])
		var team := int(k)
		if v > best_v or (is_equal_approx(v, best_v) and Global.get_team_score(team) > Global.get_team_score(best)):
			best_v = v
			best = team
	return best

func _finish(team: int) -> void:
	if finished or team <= 0:
		return
	finished = true
	running = false
	winner_slot = _best_slot_of_team(team)
	if wave != null and is_instance_valid(wave):
		wave.running = false
	SoundManager.play_sound("match_win", 0.0, -4.0)
	if main_node != null and main_node.has_method("challenge_finished"):
		main_node.challenge_finished(winner_slot)

func _best_slot_of_team(team: int) -> int:
	var best := 0
	var best_v := -INF
	for s in _slots:
		if Global.get_team_for_slot(s) != team:
			continue
		var v := float(slot_values.get(s, 0.0))
		if v > best_v:
			best_v = v
			best = s
	return best

# --- Respawn -----------------------------------------------------------------

## Main ruft das nach Kill-Gutschrift auf. true = Runde läuft weiter
## (Respawn), false = normales Ausscheiden.
func on_player_died(slot: int) -> bool:
	if finished:
		return true
	var delay := ChallengeDefs.respawn_delay(kind)
	if delay < 0.0:
		return false
	if is_replica:
		return true
	if kind == "coins":
		_drop_coins_of(slot)
	_respawns.append({"slot": slot, "t": delay})
	return true

func _update_respawns(delta: float) -> void:
	var i := _respawns.size() - 1
	while i >= 0:
		var r: Dictionary = _respawns[i]
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			var slot := int(r["slot"])
			main_node.horde_respawn_player(slot, respawn_position(slot))
			_respawns.remove_at(i)
		i -= 1

func respawn_left(slot: int) -> float:
	for r in _respawns:
		if int(r["slot"]) == slot:
			return float(r["t"])
	return -1.0

func respawn_position(slot: int) -> Vector2:
	match kind:
		"race":
			var passed := int(slot_values.get(slot, 0))
			if passed > 0 and not checkpoints.is_empty():
				var rect := checkpoints[(passed - 1) % checkpoints.size()]
				return _free_point_near(rect.get_center())
		"ballpit":
			if pen_of.has(slot):
				return _free_point_near(pens[int(pen_of[slot])].get_center())
	var idx := _slots.find(slot) + 1
	return level.get_spawn_position(maxi(1, idx), _slots.size())

func _free_point_near(p: Vector2) -> Vector2:
	var grid := ArenaMode.grid
	var jitter := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * RACE_RESPAWN_JITTER
	if grid == null:
		return p + jitter
	for ring in range(0, 6):
		for k in range(8):
			var q := p + jitter + Vector2.from_angle(TAU * float(k) / 8.0) * LevelGenerator.TILE_SIZE * float(ring)
			if grid.is_free_cell(grid.cell_of(q)):
				return q
	return p

# --- Rennen ------------------------------------------------------------------

func _update_race() -> void:
	if checkpoints.is_empty():
		return
	var n := checkpoints.size()
	var need := 1 + laps * n
	for p in _alive_players():
		var slot := p.player_index
		var passed := int(slot_values.get(slot, 0))
		var next := passed % n
		if checkpoints[next].has_point(p.global_position):
			passed += 1
			slot_values[slot] = float(passed)
			if next == 0 and passed > 1:
				var lap_done := (passed - 1) / n
				if passed >= need:
					_recount_teams()
					_finish(Global.get_team_for_slot(slot))
					return
				NetFx.emit(main_node, "ring", NetFx.with_sound(NetFx.ring_args(p.global_position,
					Color(1.0, 0.85, 0.3, 0.9), 0.6, 14.0, 0.3, 0.3), "coin", 0.1, 0.0))
				if hud != null:
					hud.flash("%s: Runde %d/%d" % [Global.get_player_name(slot), mini(lap_done + 1, laps), laps])
			else:
				SoundManager.play_sound("coin", 0.25, -6.0)
	_recount_teams()

## Fortschritt eines Slots: [Runde (1..laps), Tore in der Runde].
func race_lap(slot: int) -> int:
	var passed := int(slot_values.get(slot, 0))
	if checkpoints.is_empty() or passed <= 0:
		return 1
	return clampi((passed - 1) / checkpoints.size() + 1, 1, laps)

func next_checkpoint(slot: int) -> int:
	if checkpoints.is_empty():
		return -1
	return int(slot_values.get(slot, 0)) % checkpoints.size()

# --- Hügel -------------------------------------------------------------------

func _pick_zone() -> void:
	var size := level.get_map_pixel_size()
	var mid := size * 0.5
	if ArenaMode.active and ArenaMode.grid != null:
		zone_radius = HILL_RADIUS_ARENA
		zone_center = _free_point_near(mid)
		return
	zone_radius = HILL_RADIUS_SIDE
	var best := Vector2.INF
	var best_d := INF
	for raw in level._solid_cells.keys():
		var cell: Vector2i = raw
		if cell.y <= 3 or cell.y >= LevelGenerator.map_h - 2 or not level._is_open_platform_top(cell):
			continue
		var p := Vector2((float(cell.x) + 0.5) * LevelGenerator.TILE_SIZE, float(cell.y) * LevelGenerator.TILE_SIZE - 30.0)
		var d := absf(p.x - mid.x) + absf(p.y - mid.y) * 0.6
		if d < best_d:
			best_d = d
			best = p
	zone_center = best if best != Vector2.INF else mid

func _update_hill(delta: float) -> void:
	if zone_center == Vector2.INF:
		return
	var teams: Array[int] = []
	for p in _alive_players():
		if p.global_position.distance_to(zone_center) <= zone_radius:
			if not teams.has(p.team_id):
				teams.append(p.team_id)
	if teams.size() == 1:
		zone_owner = teams[0]
		var hold := float(def.get("hold", 20.0))
		# Wert pro Slot: die Zeit geht an alle Mitglieder in der Zone.
		var inside: Array[int] = []
		for p in _alive_players():
			if p.team_id == zone_owner and p.global_position.distance_to(zone_center) <= zone_radius:
				inside.append(p.player_index)
		for s in inside:
			slot_values[s] = float(slot_values.get(s, 0.0)) + delta / float(inside.size())
		_recount_teams()
		if float(scores.get(zone_owner, 0.0)) >= hold:
			_finish(zone_owner)
	elif teams.is_empty():
		zone_owner = 0
	else:
		zone_owner = -1

# --- Bällebad ----------------------------------------------------------------

func _place_players_in_pens() -> void:
	for p in main_node.players:
		if is_instance_valid(p) and pen_of.has(p.player_index):
			p.global_position = pens[int(pen_of[p.player_index])].get_center()

func _spawn_ball(initial: bool) -> void:
	var size := level.get_map_pixel_size()
	var mid := size * 0.5
	var pos: Vector2
	if initial:
		pos = mid + Vector2(_rng.randf_range(-size.x * 0.3, size.x * 0.3), _rng.randf_range(-size.y * 0.22, size.y * 0.22))
	else:
		# Neue Bälle rollen aus der Mitte oder von den Seiten herein.
		var side := _rng.randi() % 3
		if side == 0:
			pos = mid + Vector2(_rng.randf_range(-80, 80), _rng.randf_range(-60, 60))
		else:
			var x := 60.0 if side == 1 else size.x - 60.0
			pos = Vector2(x, mid.y + _rng.randf_range(-size.y * 0.15, size.y * 0.15))
	pos = _free_point_near(pos)
	var roll := _rng.randf()
	var mat := "rubber" if roll < 0.5 else ("wood" if roll < 0.85 else "iron")
	var ball_size := RollingBall.random_size(_rng, 0.12, 0.25)
	var vel := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(40.0, 160.0)
	var ball := level.spawn_ball(pos, mat, ball_size, vel)
	ball.harmless = true
	ball.linear_damp = maxf(ball.linear_damp, BALL_DAMP)
	ball.add_to_group("challenge_ball")

func _update_ballpit(delta: float) -> void:
	_ball_t -= delta
	if _ball_t <= 0.0:
		_ball_t = BALL_WAVE_EVERY
		var count := get_tree().get_nodes_in_group("challenge_ball").size()
		for i in range(mini(BALL_WAVE, BALL_CAP - count)):
			_spawn_ball(false)
	# Bälle pro Ecke zählen.
	var per_pen: Array[int] = []
	per_pen.resize(pens.size())
	for b in get_tree().get_nodes_in_group("challenge_ball"):
		var ball := b as RollingBall
		if ball == null or not is_instance_valid(ball) or ball.is_queued_for_deletion():
			continue
		for i in range(pens.size()):
			if pens[i].has_point(ball.global_position):
				per_pen[i] += 1
				break
	for s in pen_of.keys():
		slot_values[s] = float(per_pen[int(pen_of[s])])
	_recount_teams()

func pen_color(i: int) -> Color:
	for s in pen_of.keys():
		if int(pen_of[s]) == i:
			return color_for_slot(int(s))
	return Color(0.7, 0.7, 0.7)

# --- Münzjagd ----------------------------------------------------------------

func _collect_coin_spots() -> void:
	_coin_spots.clear()
	var t := LevelGenerator.TILE_SIZE
	if ArenaMode.active and ArenaMode.grid != null:
		var grid := ArenaMode.grid
		for y in range(2, grid.height - 2):
			for x in range(2, grid.width - 2):
				if grid.is_free_cell(Vector2i(x, y)):
					_coin_spots.append((Vector2(x, y) + Vector2(0.5, 0.5)) * t)
		return
	for raw in level._solid_cells.keys():
		var cell: Vector2i = raw
		if cell.y <= 3 or cell.y >= LevelGenerator.map_h - 2 or not level._is_open_platform_top(cell):
			continue
		_coin_spots.append(Vector2((float(cell.x) + 0.5) * t, float(cell.y) * t - 28.0))

func _spawn_coin(at: Vector2, life: float = -1.0) -> void:
	var pos := at
	if pos == Vector2.INF:
		if _coin_spots.is_empty():
			return
		# Nicht direkt neben einer anderen Münze.
		for attempt in range(8):
			pos = _coin_spots[_rng.randi() % _coin_spots.size()]
			var close := false
			for c in coins.values():
				if is_instance_valid(c) and (c as Node2D).global_position.distance_to(pos) < 140.0:
					close = true
					break
			if not close:
				break
	var coin := BountyCoin.new()
	coin.position = pos
	var id := _next_coin_id
	_next_coin_id += 1
	coin.collected.connect(_on_coin_collected.bind(id))
	main_node.add_child(coin)
	coin.add_to_group("round_effect")
	coins[id] = coin
	if life > 0.0:
		_coin_life[id] = life

func _on_coin_collected(player: Node2D, id: int) -> void:
	coins.erase(id)
	var refill := not _coin_life.has(id)
	_coin_life.erase(id)
	if finished or not (player is Player):
		return
	var slot: int = (player as Player).player_index
	slot_values[slot] = float(slot_values.get(slot, 0.0)) + 1.0
	_recount_teams()
	# Feste Münzen kommen sofort an anderer Stelle wieder.
	if refill:
		call_deferred("_spawn_coin", Vector2.INF)

func _drop_coins_of(slot: int) -> void:
	var have := int(slot_values.get(slot, 0.0))
	var lost := have / 2
	if lost <= 0:
		return
	slot_values[slot] = float(have - lost)
	_recount_teams()
	var p: Player = main_node.get_player(slot)
	var origin: Vector2 = p.global_position if p != null and is_instance_valid(p) else zone_center
	if origin == Vector2.INF:
		return
	for i in range(lost):
		var off := Vector2.from_angle(TAU * float(i) / float(lost) + _rng.randf()) * _rng.randf_range(30.0, 90.0)
		var pos := origin + off
		if ArenaMode.active:
			pos = _free_point_near(pos)
		else:
			pos.y = minf(pos.y, origin.y) - 10.0
		call_deferred("_spawn_coin", pos, COIN_DROP_LIFE)

func _update_coins(delta: float) -> void:
	for id in _coin_life.keys():
		_coin_life[id] = float(_coin_life[id]) - delta
		if float(_coin_life[id]) <= 0.0:
			var c: Node = coins.get(id, null)
			if c != null and is_instance_valid(c):
				c.queue_free()
			coins.erase(id)
			_coin_life.erase(id)

# --- Lava --------------------------------------------------------------------

func _highest_spot() -> Vector2:
	var t := LevelGenerator.TILE_SIZE
	var mid_x := float(LevelGenerator.map_w) * t * 0.5
	var best := Vector2.INF
	for raw in level._solid_cells.keys():
		var cell: Vector2i = raw
		if cell.y <= 1 or not level._is_open_platform_top(cell):
			continue
		var p := Vector2((float(cell.x) + 0.5) * t, float(cell.y) * t - 30.0)
		if best == Vector2.INF or p.y < best.y - 1.0 or (absf(p.y - best.y) <= 1.0 and absf(p.x - mid_x) < absf(best.x - mid_x)):
			best = p
	return best

func _update_lava() -> void:
	if flag_pos == Vector2.INF:
		return
	for p in _alive_players():
		if p.global_position.distance_to(flag_pos) <= FLAG_REACH + 10.0 * p.scale.y:
			slot_values[p.player_index] = 1.0
			_recount_teams()
			_finish(p.team_id)
			return
	# Wertung für das Zeitlimit: Höhe (je höher, desto besser).
	var h := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	for p in _alive_players():
		var v := clampf(1.0 - p.global_position.y / maxf(1.0, h), 0.0, 0.99)
		slot_values[p.player_index] = maxf(float(slot_values.get(p.player_index, 0.0)), v)
	_recount_teams()

# --- Hordenwelle -------------------------------------------------------------

func _update_wave() -> void:
	if wave == null or not is_instance_valid(wave):
		return
	for s in _slots:
		var st: Dictionary = wave.slot_stats.get(s, {})
		slot_values[s] = float(st.get("kills", 0))
	_recount_teams()

# ============================================================
# Bots
# ============================================================

## Wohin ein Bot in der Challenge läuft. INF = normal kämpfen.
static func bot_goal(p: Player) -> Vector2:
	if not is_active() or not current.running:
		return Vector2.INF
	return current._bot_goal(p)

func _bot_goal(p: Player) -> Vector2:
	match kind:
		"race":
			var n := next_checkpoint(p.player_index)
			if n >= 0:
				return checkpoints[n].get_center()
		"hill":
			return zone_center
		"lava":
			return flag_pos
		"coins":
			var best := Vector2.INF
			var best_d := INF
			for c in coins.values():
				if not is_instance_valid(c):
					continue
				var cp: Vector2 = (c as Node2D).global_position
				var d := p.global_position.distance_squared_to(cp)
				if d < best_d:
					best_d = d
					best = cp
			return best
		"ballpit":
			return _ballpit_bot_goal(p)
	return Vector2.INF

## Bällebad: zum nächsten Ball außerhalb der eigenen Ecke, dahinter stellen
## und ihn Richtung Ecke schieben.
func _ballpit_bot_goal(p: Player) -> Vector2:
	if not pen_of.has(p.player_index):
		return Vector2.INF
	var pen := pens[int(pen_of[p.player_index])]
	var home := pen.get_center()
	var best: RollingBall = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("challenge_ball"):
		var ball := b as RollingBall
		if ball == null or not is_instance_valid(ball) or pen.has_point(ball.global_position):
			continue
		var d := p.global_position.distance_to(ball.global_position) + ball.global_position.distance_to(home) * 0.5
		if d < best_d:
			best_d = d
			best = ball
	if best == null:
		return home
	var to_home := (home - best.global_position).normalized()
	var behind := best.global_position - to_home * (RollingBall.radius_for(best.ball_size) + 26.0)
	if p.global_position.distance_to(behind) > 30.0:
		return behind
	return best.global_position + to_home * 80.0

# ============================================================
# Netzwerk
# ============================================================

func get_network_state() -> Dictionary:
	_net_count += 1
	var data := {
		"k": kind, "t": snappedf(time_left, 0.1), "r": running, "f": finished,
		"v": slot_values, "rs": _respawn_snapshot(),
	}
	match kind:
		"hill":
			data["z"] = [zone_center.x, zone_center.y, zone_radius, zone_owner]
		"lava":
			data["fl"] = [flag_pos.x, flag_pos.y]
		"coins":
			if _net_count % COIN_SNAPSHOT_EVERY == 1:
				var rows: Array = []
				for id in coins.keys():
					var c: BountyCoin = coins[id]
					if is_instance_valid(c) and not c.is_queued_for_deletion():
						var cp := c.get_base_position()
						rows.append([int(id), int(cp.x), int(cp.y)])
				data["c"] = rows
		"wave":
			if wave != null and is_instance_valid(wave):
				data["w"] = wave.get_network_state()
	return data

func _respawn_snapshot() -> Dictionary:
	var out := {}
	for r in _respawns:
		out[int(r["slot"])] = snappedf(float(r["t"]), 0.1)
	return out

var _replica_respawns: Dictionary = {}

func apply_network_state(data: Dictionary) -> void:
	time_left = float(data.get("t", time_left))
	running = bool(data.get("r", running))
	finished = bool(data.get("f", finished))
	var v = data.get("v", null)
	if v is Dictionary:
		slot_values.clear()
		for s in v.keys():
			slot_values[int(s)] = float(v[s])
		_recount_teams()
	var rs = data.get("rs", null)
	if rs is Dictionary:
		_replica_respawns = rs
	var z = data.get("z", null)
	if z is Array and z.size() >= 4:
		zone_center = Vector2(float(z[0]), float(z[1]))
		zone_radius = float(z[2])
		zone_owner = int(z[3])
	var fl = data.get("fl", null)
	if fl is Array and fl.size() >= 2:
		flag_pos = Vector2(float(fl[0]), float(fl[1]))
	var c = data.get("c", null)
	if c is Array:
		_sync_coin_replicas(c)
	var w = data.get("w", null)
	if w is Dictionary and wave != null and is_instance_valid(wave):
		wave.apply_network_state(w)

func replica_respawn_left(slot: int) -> float:
	if not is_replica:
		return respawn_left(slot)
	for k in _replica_respawns.keys():
		if int(k) == slot:
			return float(_replica_respawns[k])
	return -1.0

func _sync_coin_replicas(rows: Array) -> void:
	var seen := {}
	for row in rows:
		if not (row is Array) or row.size() < 3:
			continue
		var id := int(row[0])
		seen[id] = true
		var coin: BountyCoin = coins.get(id, null)
		if coin == null or not is_instance_valid(coin):
			coin = BountyCoin.new()
			coin.is_replica = true
			main_node.add_child(coin)
			coin.add_to_group("round_effect")
			coins[id] = coin
		coin.set_base_position(Vector2(float(row[1]), float(row[2])))
	for id in coins.keys():
		if not seen.has(id):
			var old: BountyCoin = coins[id]
			if is_instance_valid(old):
				old.play_collect_effect()
				old.queue_free()
			coins.erase(id)

# ============================================================
# Anzeige
# ============================================================

func color_for_slot(slot: int) -> Color:
	if Global.is_team_mode():
		return Global.get_team_color(Global.get_team_for_slot(slot))
	return SLOT_COLORS[clampi(slot - 1, 0, SLOT_COLORS.size() - 1)]

func color_for_team(team: int) -> Color:
	if Global.is_team_mode():
		return Global.get_team_color(team)
	return color_for_slot(team)

func team_label(team: int) -> String:
	if Global.is_team_mode():
		return Global.get_team_name(team)
	return Global.get_player_name(team)

## Anzeige-Wert eines Teams für das HUD.
func value_text(team: int) -> String:
	var v := float(scores.get(team, 0.0))
	match kind:
		"race":
			var best_slot := _best_slot_of_team(team)
			var passed := int(slot_values.get(best_slot, 0))
			var n := maxi(1, checkpoints.size())
			if passed <= 0:
				return "Start"
			return "Runde %d/%d · Tor %d/%d" % [race_lap(best_slot), laps, ((passed - 1) % n) + 1, n]
		"hill":
			return "%d/%d s" % [int(v), int(def.get("hold", 20.0))]
		"ballpit":
			return "%d Bälle" % int(v)
		"coins":
			return "%d Münzen" % int(v)
		"lava":
			return "%d %%" % int(v * 100.0) if v < 1.0 else "Flagge!"
		"wave":
			return "%d Gegner" % int(v)
	return str(v)

func _local_slot() -> int:
	return Global.local_player_index if Global.network_mode else 1

func _draw() -> void:
	var font := ThemeDB.fallback_font
	match kind:
		"race":
			var own_next := next_checkpoint(_local_slot())
			for i in range(checkpoints.size()):
				var r := checkpoints[i]
				var is_next := i == own_next
				var col := Color(1.0, 0.85, 0.3, 0.55) if is_next else Color(1.0, 1.0, 1.0, 0.16)
				if i == 0:
					_draw_checker(r)
				draw_rect(r, col if is_next else Color(col.r, col.g, col.b, 0.08), true)
				draw_rect(r, col, false, 3.0 if is_next else 1.5)
				draw_string(font, r.get_center() + Vector2(-10, 8), "Z" if i == 0 else str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, col)
		"hill":
			if zone_center == Vector2.INF:
				return
			var col := Color(1.0, 1.0, 1.0, 0.8)
			if zone_owner > 0:
				col = color_for_team(zone_owner)
			elif zone_owner < 0:
				col = Color(1.0, 0.3, 0.3) if int(_anim * 6.0) % 2 == 0 else Color(1.0, 1.0, 1.0)
			var pulse := 1.0 + sin(_anim * 3.0) * 0.03
			draw_circle(zone_center, zone_radius * pulse, Color(col.r, col.g, col.b, 0.16))
			draw_arc(zone_center, zone_radius * pulse, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.9), 4.0)
			draw_arc(zone_center, zone_radius * 0.35, _anim, _anim + PI * 1.4, 24, Color(col.r, col.g, col.b, 0.7), 3.0)
		"ballpit":
			for i in range(pens.size()):
				var r := pens[i]
				var col := pen_color(i)
				draw_rect(r, Color(col.r, col.g, col.b, 0.2), true)
				draw_rect(r, Color(col.r, col.g, col.b, 0.85), false, 3.0)
				var count := 0
				for s in pen_of.keys():
					if int(pen_of[s]) == i:
						count = int(slot_values.get(s, 0.0))
				if pen_of.values().has(i):
					draw_string(font, r.get_center() + Vector2(-14, 10), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.9))
		"lava":
			if flag_pos == Vector2.INF:
				return
			var base := flag_pos + Vector2(0, 28)
			draw_line(base, base + Vector2(0, -78), Color(0.85, 0.85, 0.9), 4.0)
			var wave_off := sin(_anim * 5.0) * 5.0
			var cloth := PackedVector2Array([base + Vector2(2, -78), base + Vector2(48, -66 + wave_off), base + Vector2(2, -52)])
			draw_colored_polygon(cloth, Color(1.0, 0.85, 0.2))
			draw_circle(flag_pos, FLAG_REACH, Color(1.0, 0.85, 0.2, 0.12))
			draw_arc(flag_pos, FLAG_REACH, 0.0, TAU, 40, Color(1.0, 0.85, 0.2, 0.6), 2.0)

func _draw_checker(r: Rect2) -> void:
	var s := 18.0
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x
		var colm := row % 2
		while x < r.end.x:
			if colm % 2 == 0:
				draw_rect(Rect2(Vector2(x, y), Vector2(minf(s, r.end.x - x), minf(s, r.end.y - y))), Color(1, 1, 1, 0.35), true)
			x += s
			colm += 1
		y += s
		row += 1
