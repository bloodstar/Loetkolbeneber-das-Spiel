class_name HordeDirector
extends Node2D

# Steuert eine Horden-Runde (Koop gegen Schweinejäger).
#
# Host / lokal: Zeit, Wellen, Gegner-Spawns, Fluss-Feld für die Wegsuche,
# weiches Ausweichen der Gegner untereinander, XP-Kristalle, Stufenaufstiege
# (main startet dafür den normalen Draft), Bosse, Wiederbelebung und Ende.
# XP-Kristalle, Futter, Truhen und Gegnergeschosse sind reine Daten und
# werden hier gezeichnet (2D-Ebene liegt passgenau auf dem 3D-Boden).
#
# Clients: bauen Gegner als Replikate aus dem Snapshot nach (get_network_state
# / apply_network_state) und zeigen Kristalle, Geschosse und den Zustand an.

signal levelup_ready
signal notice(text: String, color: Color)
signal run_over(victory: bool)

const FLOW_INTERVAL: float = 0.4
const FLOW_BUDGET: int = 2200
const SEP_CELL: float = 48.0
const SHOT_RADIUS: float = 7.0
const GEM_SNAPSHOT_EVERY: int = 3
## Liegengebliebene XP-Kristalle verschmelzen mit Nachbarn zu größeren:
## alle GEM_MERGE_EVERY s, wenn sie älter als GEM_MERGE_AGE s sind und
## näher als GEM_MERGE_RADIUS beieinander liegen. Weniger Objekte im Level.
const GEM_MERGE_EVERY: float = 1.5
const GEM_MERGE_AGE: float = 6.0
const GEM_MERGE_RADIUS: float = 72.0
const FOOD_CHANCE: float = 0.012
const FOOD_HEAL: float = 30.0
const WOLF_RING_EVERY: float = 75.0
## Powerups: erstes nach POWERUP_FIRST s, dann alle POWERUP_INTERVAL s
## (mit mehr Ebern etwas öfter), höchstens POWERUP_MAX gleichzeitig.
const POWERUP_FIRST: float = 20.0
const POWERUP_INTERVAL: float = 28.0
const POWERUP_MAX: int = 4
## Nach einem Boss fliegen alle Kristalle und die Truhe sofort zu den Ebern.
## Das Gebiet wechselt, sobald die Truhen-Auswahl beendet ist. Fallback, falls
## die Truhe nicht eingesammelt wird (Spielzeit, ohne Kartenwahl-Pausen).
const MAP_CHANGE_FALLBACK: float = 15.0
## Kurze Pause nach der Truhen-Auswahl, bevor das neue Gebiet lädt.
const MAP_CHANGE_AFTER_CHEST: float = 0.6
## Nach einem Gebietswechsel kurz keine neuen Gegner.
const STAGE_SPAWN_GRACE: float = 4.0
## Treibjagd (Scroll-Karte): Schaden pro Tick hinter der Feuerwalze.
const SCROLL_DAMAGE: float = 7.0
const SCROLL_TICK: float = 0.5

static var current: HordeDirector = null

var is_replica: bool = false
var running: bool = false
var main_node: Node = null
var run_time: float = 0.0
var level: int = 1
var xp: int = 0
var xp_next: int = 10
var kills: int = 0
var pending_levelups: int = 0
var pending_bonus: int = 0
var levelup_active: bool = false
var over: int = 0 # 0 läuft, 1 gewonnen, 2 verloren
var player_count: int = 1
var boss_index: int = 0
var boss: HordeEnemy = null
var boss_info: Dictionary = {}
var final_boss_spawned: bool = false
## Gebiet (0 = Start). Wechselt nach jedem besiegten Boss (HordeDefs.STAGE_MAPS).
var stage: int = 0
var stage_map_id: String = ""
var stage_seed: int = 0
## Treibjagd: linke Kante des erlaubten Bereichs in px, -1 = keine Walze.
var scroll_x: float = -1.0
var _scroll_speed: float = 0.0
var _scroll_max: float = 0.0
var _scroll_wait: float = 0.0
var _scroll_tick: float = 0.0
var _map_change_t: float = -1.0
## Boss besiegt, Gebietswechsel wartet auf die Truhen-Auswahl.
var _stage_after_chest: bool = false
var _powerup_t: float = POWERUP_FIRST
var _spawn_grace: float = 0.0
## Pro Slot: {"kills": int, "damage": float, "deaths": int}
var slot_stats: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _spawn_acc: float = 0.0
var _next_ring: float = WOLF_RING_EVERY
var _targets: Array = []
var _targets_frame: int = -1
var _flow: PackedInt32Array = PackedInt32Array()
var _flow_w: int = 0
var _flow_h: int = 0
var _flow_t: float = 0.0
## Zählt hoch, wenn ein neues Fluss-Feld fertig ist (Gegner-Zwischenspeicher).
var flow_version: int = 0
var _sep_frame: int = -1
var _sep_buckets: Dictionary = {}
var _gems: Array = []   # {id, pos, v, t ("xp"|"food"|"chest"), fly}
var _shots: Array = []  # {pos, vel, dmg, k, life}
var _next_gem_id: int = 1
var _respawns: Array = [] # {slot, t}
var _dead_slots: Dictionary = {}
var _coin_sound_t: float = 0.0
var _gem_merge_t: float = GEM_MERGE_EVERY
var _notice_seq: int = 0
var _notice_text: String = ""
var _notice_color: Color = Color.WHITE
var _net_count: int = 0
var _replicas: Dictionary = {} # net_id -> HordeEnemy
var _seen_notice: int = 0
var _anim_t: float = 0.0

static func is_active() -> bool:
	return current != null and is_instance_valid(current)

func _ready() -> void:
	current = self
	z_index = 2
	add_to_group("round_effect")

func _exit_tree() -> void:
	if current == self:
		current = null

func start(main: Node, seed_value: int, players: int) -> void:
	main_node = main
	player_count = maxi(1, players)
	_rng.seed = maxi(1, seed_value)
	running = true
	run_time = 0.0
	level = 1
	xp = 0
	xp_next = HordeDefs.xp_needed(level, player_count)
	_spawn_acc = 4.0
	stage = 0
	stage_map_id = main.match_map_id if main.get("match_map_id") != null else ""
	stage_seed = seed_value
	_setup_scroll()
	_rebuild_flow()

# ============================================================
# Host-Simulation
# ============================================================

func _physics_process(delta: float) -> void:
	_anim_t += delta
	if is_replica:
		_update_shots_visual(delta)
		queue_redraw()
		return
	if not running or over != 0:
		queue_redraw()
		return
	run_time += delta
	_coin_sound_t -= delta
	# Fluss-Feld zeitversetzt: höchstens FLOW_BUDGET Zellen pro Physik-Frame.
	_flow_t -= delta
	if _bfs_active:
		_step_flow(FLOW_BUDGET)
	elif _flow_t <= 0.0:
		_flow_t = FLOW_INTERVAL
		_begin_flow()
	_spawn_grace = maxf(0.0, _spawn_grace - delta)
	if _spawn_grace <= 0.0 and _map_change_t < 0.0:
		_update_spawning(delta)
		_update_bosses()
	_update_gems(delta)
	_update_shots(delta)
	_update_respawns(delta)
	_update_powerups(delta)
	_update_scroll(delta)
	_check_levelup()
	if _map_change_t >= 0.0:
		_map_change_t -= delta
		if _map_change_t < 0.0:
			_change_stage()
	queue_redraw()

func alive_targets() -> Array:
	var frame := Engine.get_physics_frames()
	if frame == _targets_frame:
		return _targets
	_targets_frame = frame
	_targets.clear()
	if main_node == null:
		return _targets
	for p in main_node.players:
		if is_instance_valid(p) and not p.is_dead and p.current_health > 0.0 and p.visible:
			_targets.append(p)
	return _targets

func nearest_target(pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for p in alive_targets():
		var d: float = pos.distance_squared_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best

## Nächster lebender Gegner (für Zielsuche, Türme, Bots).
func nearest_enemy_to(pos: Vector2, max_dist: float = INF) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist * max_dist if max_dist < INF else INF
	for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var e := node as HordeEnemy
		if e == null or not e.is_alive() or e.is_replica:
			continue
		var d := pos.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func has_los(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var ray := PhysicsRayQueryParameters2D.create(a, b, 1)
	return space.intersect_ray(ray).is_empty()

## Sichtlinie über das Höhenraster für ein Geschoss in Höhe z (Würfe auf
## erhöhte Eber). Die Zielzelle selbst zählt nicht (dort steht der Eber).
func has_los_at(a: Vector2, b: Vector2, z: float) -> bool:
	var grid := ArenaMode.grid
	if grid == null:
		return true
	var goal := grid.cell_of(b)
	var steps := maxi(1, int(a.distance_to(b) / (LevelGenerator.TILE_SIZE * 0.5)))
	for i in range(1, steps):
		var c := grid.cell_of(a.lerp(b, float(i) / float(steps)))
		if c == goal:
			break
		if _blocks_shot(grid, c, z):
			return false
	return true

# --- Fluss-Feld: BFS von allen lebenden Ebern über freie Zellen ---

var _free: PackedByteArray = PackedByteArray()
## Höhe einer Felsstufe, auf die Bodengegner hüpfen (Kartenzeichen p).
const STEP_LEVEL_H: float = 36.0
var _free_t: float = 0.0

## Begehbarkeit je Zelle, zwischengespeichert (zerstörte Kisten werden alle
## paar Sekunden nachgezogen).
func _refresh_free_mask() -> void:
	var grid := ArenaMode.grid
	if grid == null:
		return
	_flow_w = grid.width
	_flow_h = grid.height
	_free.resize(_flow_w * _flow_h)
	for y in range(_flow_h):
		for x in range(_flow_w):
			_free[y * _flow_w + x] = _walk_code(grid, Vector2i(x, y))

## Begehbarkeit einer Zelle für Bodengegner: 0 = Mauer/Erhöhung, 1 = Boden,
## 2 = niedrige Felsstufe (p, 36 px), auf die Bodengegner hüpfen können.
## Stege mit Luft darunter zählen als Boden (man läuft unten durch).
func _walk_code(grid: ArenaGrid, cell: Vector2i) -> int:
	if not grid.in_bounds(cell) or grid.segment_cells.has(cell):
		return 0
	var spans: Array = grid.blocks.get(cell, [])
	if spans.is_empty():
		return 1
	var top := 0.0
	var low := 0
	for b in spans:
		var span: Vector2 = b
		if span.x >= ArenaMode.BODY_H:
			continue
		low += 1
		top = maxf(top, span.y)
	if low == 0:
		return 1
	if low == 1 and grid.terrain.has(cell) and absf(top - STEP_LEVEL_H) < 0.5:
		return 2
	return 0

func _is_free_idx(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= _flow_w or y >= _flow_h:
		return false
	return _free[y * _flow_w + x] != 0

## Höhenstufe der Zelle unter pos für Bodengegner: 0 Boden, 1 Felsstufe,
## -1 nicht begehbar.
func level_at(pos: Vector2) -> int:
	if _free.is_empty():
		return 0
	var t := LevelGenerator.TILE_SIZE
	var x := floori(pos.x / t)
	var y := floori(pos.y / t)
	if x < 0 or y < 0 or x >= _flow_w or y >= _flow_h:
		return -1
	return int(_free[y * _flow_w + x]) - 1

## Höchste Stufe, die ein Kreis (als Quadrat genähert) an pos berührt.
func area_level(pos: Vector2, r: float) -> int:
	if _free.is_empty():
		return 0
	var t := LevelGenerator.TILE_SIZE
	var x0 := floori((pos.x - r) / t)
	var x1 := floori((pos.x + r) / t)
	var y0 := floori((pos.y - r) / t)
	var y1 := floori((pos.y + r) / t)
	var best := 0
	for c in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x0, y1), Vector2i(x1, y1)]:
		if c.x >= 0 and c.y >= 0 and c.x < _flow_w and c.y < _flow_h:
			best = maxi(best, int(_free[c.y * _flow_w + c.x]) - 1)
	return best

## Ist ein Kreis (als Quadrat genähert) frei von Mauern?
func is_free_area(pos: Vector2, r: float) -> bool:
	if _free.is_empty():
		return true
	var t := LevelGenerator.TILE_SIZE
	var x0 := floori((pos.x - r) / t)
	var x1 := floori((pos.x + r) / t)
	var y0 := floori((pos.y - r) / t)
	var y1 := floori((pos.y + r) / t)
	return _is_free_idx(x0, y0) and _is_free_idx(x1, y0) and _is_free_idx(x0, y1) and _is_free_idx(x1, y1)

## Nächster Punkt um pos, an dem ein Kreis mit Radius r frei steht (Ringe in
## halben Kacheln, bis etwa 7 Kacheln weit). Vector2.INF, wenn nichts passt.
func find_free_spot(pos: Vector2, r: float) -> Vector2:
	if _free.is_empty():
		_refresh_free_mask()
	if _free.is_empty():
		return pos
	var w := float(_flow_w) * LevelGenerator.TILE_SIZE
	var h := float(_flow_h) * LevelGenerator.TILE_SIZE
	var lo := Vector2(r + 2.0, r + 2.0)
	var hi := Vector2(w - r - 2.0, h - r - 2.0)
	var p0 := pos.clamp(lo, hi)
	if is_free_area(p0, r) and not _behind_scroll(p0):
		return p0
	var step := LevelGenerator.TILE_SIZE * 0.5
	for ring in range(1, 15):
		var rad := step * float(ring)
		var n := 6 + ring * 3
		var a0 := _rng.randf() * TAU
		for k in range(n):
			var p := (p0 + Vector2.from_angle(a0 + TAU * float(k) / float(n)) * rad).clamp(lo, hi)
			if is_free_area(p, r) and not _behind_scroll(p):
				return p
	return Vector2.INF

func _behind_scroll(p: Vector2) -> bool:
	return scroll_x >= 0.0 and p.x < scroll_x + 60.0

var _bfs_active: bool = false
var _bfs_queue: PackedInt32Array = PackedInt32Array()
var _bfs_head: int = 0
var _flow_next: PackedInt32Array = PackedInt32Array()

## Komplettes Fluss-Feld sofort (Rundenstart).
func _rebuild_flow() -> void:
	_begin_flow()
	_step_flow(1 << 30)

func _begin_flow() -> void:
	var grid := ArenaMode.grid
	if grid == null:
		return
	_free_t -= FLOW_INTERVAL
	if _free.size() != grid.width * grid.height or _free_t <= 0.0:
		_free_t = 4.0
		_refresh_free_mask()
	var n := _flow_w * _flow_h
	if _flow_next.size() != n:
		_flow_next.resize(n)
	_flow_next.fill(-1)
	_bfs_queue.clear()
	_bfs_head = 0
	for p in alive_targets():
		var c := grid.cell_of(p.global_position)
		if grid.in_bounds(c):
			var i := c.y * _flow_w + c.x
			if _flow_next[i] < 0:
				_flow_next[i] = 0
				_bfs_queue.append(i)
	_bfs_active = true

func _step_flow(budget: int) -> void:
	if not _bfs_active:
		return
	var queue := _bfs_queue
	var head := _bfs_head
	var flow := _flow_next
	var w := _flow_w
	var h := _flow_h
	while head < queue.size() and budget > 0:
		budget -= 1
		var i := queue[head]
		head += 1
		var cx := i % w
		var cy := i / w
		var d := flow[i] + 1
		for k in range(4):
			var nx: int = cx + (1 if k == 0 else (-1 if k == 1 else 0))
			var ny: int = cy + (1 if k == 2 else (-1 if k == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var ni := ny * w + nx
			if flow[ni] >= 0:
				continue
			if _free[ni] == 0:
				flow[ni] = 1 << 28
				continue
			flow[ni] = d
			queue.append(ni)
	_bfs_head = head
	_bfs_queue = queue
	_flow_next = flow
	if head >= queue.size():
		_bfs_active = false
		var done := _flow
		_flow = _flow_next
		_flow_next = done
		flow_version += 1

func _flow_at(cx: int, cy: int) -> int:
	if cx < 0 or cy < 0 or cx >= _flow_w or cy >= _flow_h:
		return 1 << 29
	var v := _flow[cy * _flow_w + cx]
	return (1 << 29) if v < 0 else v

## Richtung zur Nachbarzelle mit dem kleinsten Abstand zum nächsten Eber.
func flow_dir(pos: Vector2) -> Vector2:
	var grid := ArenaMode.grid
	if grid == null or _flow.is_empty():
		return Vector2.ZERO
	var c := grid.cell_of(pos)
	var here := _flow_at(c.x, c.y)
	var best := here
	var best_cell := c
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var v := _flow_at(c.x + ox, c.y + oy)
			if ox != 0 and oy != 0:
				# Diagonal nur, wenn beide Nachbarn frei sind (keine Ecken schneiden).
				if _flow_at(c.x + ox, c.y) >= (1 << 28) or _flow_at(c.x, c.y + oy) >= (1 << 28):
					continue
			if v < best:
				best = v
				best_cell = Vector2i(c.x + ox, c.y + oy)
	if best_cell == c:
		return Vector2.ZERO
	var center := (Vector2(best_cell) + Vector2(0.5, 0.5)) * grid.tile
	return (center - pos).normalized()

# --- Weiches Ausweichen der Gegner (Raster-Hash) ---

func separation(e: HordeEnemy) -> Vector2:
	# Raster nur jeden zweiten Frame neu (Gegner fragen ohnehin versetzt).
	var frame := Engine.get_physics_frames()
	if frame - _sep_frame >= 2 or frame < _sep_frame:
		_sep_frame = frame
		_sep_buckets.clear()
		for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
			var en := node as HordeEnemy
			if en == null or en.is_dead or en.ai == "fly":
				continue
			var key := Vector2i(floori(en.global_position.x / SEP_CELL), floori(en.global_position.y / SEP_CELL))
			if not _sep_buckets.has(key):
				_sep_buckets[key] = []
			_sep_buckets[key].append(en)
	if e.ai == "fly":
		return Vector2.ZERO
	var push := Vector2.ZERO
	var pos := e.global_position
	var key0 := Vector2i(floori(pos.x / SEP_CELL), floori(pos.y / SEP_CELL))
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var list = _sep_buckets.get(key0 + Vector2i(ox, oy), null)
			if list == null:
				continue
			for other in list:
				# Raster ist bis zu einen Frame alt: Gestorbene überspringen.
				if other == e or not is_instance_valid(other):
					continue
				var d: Vector2 = pos - other.global_position
				var rs: float = e.radius + other.radius
				var dist := d.length()
				if dist < rs and dist > 0.01:
					push += d / dist * (rs - dist) / rs
	return push.limit_length(2.0)

# --- Spawns ---

func enemy_count() -> int:
	return get_tree().get_nodes_in_group(HordeEnemy.GROUP).size()

func _update_spawning(delta: float) -> void:
	var targets := alive_targets()
	if targets.is_empty():
		return
	var boss_alive := boss != null and is_instance_valid(boss) and not boss.is_dead
	var rate := HordeDefs.spawn_rate(run_time) * (1.0 + 0.3 * float(player_count - 1))
	if boss_alive:
		rate *= 0.5
	_spawn_acc += rate * delta
	var cap := mini(HordeDefs.max_alive(run_time, player_count), enemy_limit())
	var count := enemy_count()
	while _spawn_acc >= 1.0 and count < cap:
		var kind := HordeDefs.pick_kind(run_time, _rng)
		var pack := _rng.randi_range(1, int(HordeDefs.ENEMIES[kind].get("pack", 1)))
		var anchor := _spawn_point(targets[_rng.randi() % targets.size()].global_position)
		if anchor == Vector2.INF:
			break
		for i in range(pack):
			var pos := anchor + Vector2(_rng.randf_range(-40, 40), _rng.randf_range(-40, 40))
			spawn_enemy(kind, pos, _rng.randf() < HordeDefs.riese_chance(run_time))
			count += 1
		_spawn_acc -= float(pack)
	_spawn_acc = minf(_spawn_acc, 12.0)
	if run_time >= _next_ring:
		_next_ring += WOLF_RING_EVERY
		_wolf_ring(targets[_rng.randi() % targets.size()])
	# Abgehängte Gegner wieder nach vorn holen.
	if Engine.get_physics_frames() % 30 == 0:
		for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
			var en := node as HordeEnemy
			if en == null or en.is_dead or en.is_boss:
				continue
			var t := nearest_target(en.global_position)
			if t != null and (en.global_position.distance_to(t.global_position) > HordeDefs.DESPAWN_DIST \
					or _behind_scroll(en.global_position + Vector2(120.0, 0.0))):
				var p := _spawn_point(t.global_position)
				if p != Vector2.INF:
					en.global_position = p

func _spawn_point(center: Vector2) -> Vector2:
	var grid := ArenaMode.grid
	for i in range(12):
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(HordeDefs.SPAWN_MIN_DIST, HordeDefs.SPAWN_MAX_DIST)
		var p := center + Vector2.from_angle(a) * Vector2(d, d * 0.75)
		if grid == null:
			return p
		var c := grid.cell_of(p)
		if grid.in_bounds(c) and c.x > 1 and c.y > 1 and c.x < grid.width - 2 and c.y < grid.height - 2 \
				and is_free_area(p, 34.0) and not _behind_scroll(p - Vector2(80.0, 0.0)):
			return p
	return Vector2.INF

func spawn_enemy(kind: String, pos: Vector2, riese: bool = false) -> HordeEnemy:
	var e := HordeEnemy.new()
	e.director = self
	e.net_id = NetEntity.next_id()
	e.setup(kind, riese, HordeDefs.hp_mult(run_time, player_count), HordeDefs.damage_mult(run_time))
	# Nie in einer Mauer erscheinen: sonst kommt der Gegner nicht mehr los.
	if e.ai != "fly":
		pos = find_free_spot(pos, e.radius * 0.75 + 1.0)
		if pos == Vector2.INF:
			e.free()
			return null
	e.position = pos
	get_parent().add_child(e)
	return e

## Höchstzahl gleichzeitiger Gegner laut Grafikstufe (Optionen → Horden-Limit).
## Online zählt die Einstellung des Hosts, weil nur er spawnt.
func enemy_limit() -> int:
	var lim := GameSettings.horde_enemy_limit()
	if lim <= 0:
		lim = HordeDefs.MAX_ENEMIES_CAP
	return mini(HordeDefs.MAX_ENEMIES_CAP, lim)

func _wolf_ring(target: Node2D) -> void:
	var n := 14 + mini(10, int(run_time / 60.0) * 2)
	var kind := "wolf" if run_time > 60.0 else "fuchs"
	n = mini(n, enemy_limit() - enemy_count())
	for i in range(n):
		var p: Vector2 = target.global_position + Vector2.from_angle(TAU * float(i) / float(n)) * 560.0
		if _behind_scroll(p):
			continue
		spawn_enemy(kind, p)
	_post_notice("Das Rudel umzingelt euch!", Color(1.0, 0.75, 0.35))
	SoundManager.play_sound("warning", 0.05, -4.0)

# --- Bosse ---

func _update_bosses() -> void:
	if boss_index >= HordeDefs.BOSS_TIMES.size():
		return
	if run_time < HordeDefs.BOSS_TIMES[boss_index]:
		return
	var targets := alive_targets()
	if targets.is_empty():
		return
	var hero := _pick_boss_hero()
	var pos := _spawn_point(targets[0].global_position)
	if pos == Vector2.INF:
		return
	var b := HordeEnemy.new()
	b.director = self
	b.net_id = NetEntity.next_id()
	b.setup_boss(hero, HordeDefs.boss_hp(boss_index, player_count), HordeDefs.damage_mult(run_time))
	var free_pos := find_free_spot(pos, b.radius * 0.75 + 1.0)
	if free_pos == Vector2.INF:
		b.free()
		return
	b.position = free_pos
	get_parent().add_child(b)
	boss = b
	var final := boss_index == HordeDefs.BOSS_TIMES.size() - 1
	if final:
		final_boss_spawned = true
	boss_info = {"id": b.net_id, "hero": hero, "name": Global.get_hero(hero).name, "final": final}
	boss_index += 1
	_post_notice(("ENDBOSS: %s!" if final else "BOSS: %s erscheint!") % Global.get_hero(hero).name, Color(1.0, 0.35, 0.3))
	SoundManager.play_sound("sudden_death", 0.0, -2.0)
	Global.shake_camera(0.4)

func _pick_boss_hero() -> String:
	var taken: Array = []
	for slot in Global.get_active_player_indices():
		taken.append(Global.get_player_hero_id(slot))
	var pool: Array = []
	for id in Global.heroes.keys():
		if not taken.has(id) and str(id) != str(boss_info.get("hero", "")):
			pool.append(id)
	if pool.is_empty():
		pool = Global.heroes.keys()
	return str(pool[_rng.randi() % pool.size()])

func boss_slam(b: HordeEnemy, radius: float, dmg: float) -> void:
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(b.global_position,
		Color(1.0, 0.45, 0.2, 0.85), 0.5, radius / 6.0, 0.3, 0.3), "explosion", 0.1, -2.0))
	Global.shake_camera(0.3)
	for p in alive_targets():
		if p.global_position.distance_to(b.global_position) <= radius + 12.0 and p.arena_z < 40.0:
			p.take_damage(dmg, (p.global_position - b.global_position).normalized() * 420.0, b)

func boss_summon(b: HordeEnemy) -> void:
	if enemy_count() >= enemy_limit():
		return
	for i in range(4):
		var p := b.global_position + Vector2.from_angle(TAU * float(i) / 4.0 + _rng.randf()) * 70.0
		spawn_enemy(HordeDefs.pick_kind(run_time, _rng), p)
	NetFx.emit(get_parent(), "ring", NetFx.ring_args(b.global_position, Color(0.8, 0.3, 1.0, 0.7), 0.5, 14.0, 0.35, 0.3))

func howl(e: HordeEnemy) -> void:
	for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var en := node as HordeEnemy
		if en != null and (en.kind == "wolf" or en.kind == "fuchs" or en == e) \
				and en.global_position.distance_to(e.global_position) < 320.0:
			en.haste(4.0)
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(e.global_position,
		Color(0.85, 0.85, 1.0, 0.6), 0.5, 50.0, 0.5, 0.2), "warning", 0.2, -10.0))

# --- Treffer und Tode ---

func note_damage(slot: int, amount: float) -> void:
	var s: Dictionary = slot_stats.get(slot, {"kills": 0, "damage": 0.0, "deaths": 0})
	s["damage"] = float(s["damage"]) + amount
	slot_stats[slot] = s

func on_enemy_killed(e: HordeEnemy, killer) -> void:
	kills += 1
	if killer is Player and is_instance_valid(killer):
		var s: Dictionary = slot_stats.get(killer.player_index, {"kills": 0, "damage": 0.0, "deaths": 0})
		s["kills"] = int(s["kills"]) + 1
		slot_stats[killer.player_index] = s
		Global.add_match_stat(killer.player_index, "kills", 1.0)
	var pos := e.global_position
	if e.is_boss:
		_drop(pos, "chest", 1)
		for i in range(10):
			_drop(pos + Vector2.from_angle(TAU * i / 10.0) * 40.0, "xp", 6)
		NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(pos,
			Color(1.0, 0.85, 0.3, 0.9), 1.0, 30.0, 0.5, 0.5), "explosion_big", 0.0, 0.0))
		Global.shake_camera(0.5)
		var was_final := bool(boss_info.get("final", false))
		if e == boss:
			boss = null
			boss_info = {}
		if was_final:
			_finish(true)
		else:
			# Magnet: alle Kristalle (und die Truhe) fliegen zu den Ebern,
			# danach geht es in ein neues Gebiet.
			_magnet_all()
			_stage_after_chest = true
			_map_change_t = MAP_CHANGE_FALLBACK
			_post_notice("Boss besiegt! Nach der Truhe geht es in ein neues Gebiet.", Color(1.0, 0.9, 0.4))
		return
	_drop(pos, "xp", e.xp_value)
	if _rng.randf() < FOOD_CHANCE:
		_drop(pos + Vector2(10, 0), "food", 1)
	if e.riese:
		NetFx.emit(get_parent(), "ring", NetFx.ring_args(pos, Color(1.0, 0.85, 0.3, 0.8), 0.5, 10.0, 0.3, 0.25))

func _drop(pos: Vector2, t: String, value: int) -> void:
	if t == "xp" and _gems.size() >= HordeDefs.GEM_MAX:
		# Zu viele Kristalle: in den nächstgelegenen einrechnen.
		var best: Dictionary = {}
		var best_d := INF
		for g in _gems:
			if g["t"] != "xp":
				continue
			var d: float = pos.distance_squared_to(g["pos"])
			if d < best_d:
				best_d = d
				best = g
		if not best.is_empty():
			best["v"] = int(best["v"]) + value
			return
	_gems.append({"id": _next_gem_id, "pos": pos, "v": value, "t": t, "fly": false, "spd": 0.0, "age": 0.0})
	_next_gem_id += 1

func _update_gems(delta: float) -> void:
	_gem_merge_t -= delta
	if _gem_merge_t <= 0.0:
		_gem_merge_t = GEM_MERGE_EVERY
		_merge_gems()
	var targets := alive_targets()
	if targets.is_empty():
		return
	var i := _gems.size() - 1
	while i >= 0:
		var g: Dictionary = _gems[i]
		g["age"] = float(g.get("age", 0.0)) + delta
		var gp: Vector2 = g["pos"]
		var best: Node2D = null
		var best_d := INF
		for p in targets:
			var d: float = gp.distance_to(p.global_position)
			if d < best_d:
				best_d = d
				best = p
		var magnet := HordeDefs.GEM_MAGNET_RADIUS * (1.6 if g["t"] == "chest" else 1.0)
		if best != null and (bool(g["fly"]) or best_d < magnet):
			g["fly"] = true
			var mag := bool(g.get("mag", false))
			g["spd"] = minf(float(g["spd"]) + (3000.0 if mag else 1400.0) * delta, 2600.0 if mag else 900.0)
			gp = gp.move_toward(best.global_position, float(g["spd"]) * delta)
			g["pos"] = gp
			if gp.distance_to(best.global_position) < HordeDefs.GEM_PICKUP_RADIUS:
				_collect(g, best)
				_gems.remove_at(i)
		i -= 1

## Verschmilzt alte, ruhende XP-Kristalle mit Nachbarn (Raster-Hash). Der
## größere Kristall bleibt liegen und bekommt den Wert dazu.
func _merge_gems() -> void:
	if _gems.size() < 24:
		return
	var cell := GEM_MERGE_RADIUS
	var buckets := {}
	var removed := {}
	var r2 := GEM_MERGE_RADIUS * GEM_MERGE_RADIUS
	for g in _gems:
		if str(g["t"]) != "xp" or bool(g["fly"]) or float(g.get("age", 0.0)) < GEM_MERGE_AGE:
			continue
		var gp: Vector2 = g["pos"]
		var key := Vector2i(floori(gp.x / cell), floori(gp.y / cell))
		var merged := false
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var list = buckets.get(key + Vector2i(ox, oy), null)
				if list == null:
					continue
				for other in list:
					if gp.distance_squared_to(other["pos"]) <= r2:
						var big: bool = int(g["v"]) > int(other["v"])
						if big:
							other["pos"] = gp
						other["v"] = int(other["v"]) + int(g["v"])
						removed[int(g["id"])] = true
						merged = true
						break
				if merged:
					break
			if merged:
				break
		if not merged:
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append(g)
	if removed.is_empty():
		return
	var kept: Array = []
	for g in _gems:
		if not removed.has(int(g.get("id", -1))):
			kept.append(g)
	_gems = kept

## Alle liegenden Kristalle, Futter und Truhen fliegen sofort zu den Ebern.
func _magnet_all() -> void:
	for g in _gems:
		g["fly"] = true
		g["mag"] = true

## Was beim Gebietswechsel noch unterwegs ist, wird direkt gutgeschrieben.
func _collect_remaining() -> void:
	var targets := alive_targets()
	for g in _gems:
		if str(g["t"]) == "food":
			continue
		_collect(g, targets[0] if not targets.is_empty() else null)
	_gems.clear()

# --- Powerups ---

func _update_powerups(delta: float) -> void:
	if not Global.has_active_powerups() or main_node == null:
		return
	_powerup_t -= delta * (1.0 + 0.2 * float(player_count - 1))
	if _powerup_t > 0.0:
		return
	_powerup_t = POWERUP_INTERVAL * _rng.randf_range(0.85, 1.15)
	if get_tree().get_nodes_in_group("powerup_pickup").size() >= POWERUP_MAX:
		return
	var targets := alive_targets()
	if targets.is_empty():
		return
	var lg = main_node.get("level_generator")
	if lg == null or not lg.has_method("_spawn_powerup_at"):
		return
	var center: Vector2 = targets[_rng.randi() % targets.size()].global_position
	for attempt in range(10):
		var d := _rng.randf_range(220.0, 520.0)
		var dir := Vector2.from_angle(_rng.randf() * TAU)
		if scroll_x >= 0.0:
			dir.x = absf(dir.x) # Treibjagd: nach vorn legen
		var p := find_free_spot(center + dir * Vector2(d, d * 0.75), 26.0)
		if p == Vector2.INF:
			continue
		var kind: String = lg._random_powerup_kind()
		if kind.is_empty():
			return
		lg._spawn_powerup_at(p, kind)
		NetFx.emit(get_parent(), "ring", NetFx.ring_args(p, Color(1.0, 0.95, 0.5, 0.8), 0.6, 8.0, 0.4, 0.2))
		return

# --- Treibjagd (Scroll-Karte) ---

func _setup_scroll() -> void:
	scroll_x = -1.0
	_scroll_speed = 0.0
	var data: Dictionary = ArenaMaps.get_map(stage_map_id) if not stage_map_id.is_empty() else {}
	var cfg = data.get("scroll", null)
	if not (cfg is Dictionary):
		return
	var map_px := float(LevelGenerator.map_w) * LevelGenerator.TILE_SIZE
	scroll_x = 0.0
	_scroll_wait = float(cfg.get("delay", 6.0))
	_scroll_speed = float(cfg.get("speed", 40.0))
	_scroll_max = maxf(0.0, map_px - float(cfg.get("end_room", 1900.0)))

func _update_scroll(delta: float) -> void:
	if scroll_x < 0.0:
		return
	if _scroll_wait > 0.0:
		_scroll_wait -= delta
	else:
		# Holt auf, wenn alle weit vorn sind; nie schneller als doppelt.
		var lead := INF
		for p in alive_targets():
			lead = minf(lead, p.global_position.x - scroll_x)
		var mult := 1.0 if lead == INF or lead < 900.0 else 1.8
		scroll_x = minf(_scroll_max, scroll_x + _scroll_speed * mult * delta)
	_scroll_tick -= delta
	if _scroll_tick > 0.0:
		return
	_scroll_tick = SCROLL_TICK
	for p in alive_targets():
		if p.global_position.x < scroll_x + 6.0:
			p.take_damage(SCROLL_DAMAGE * HordeDefs.damage_mult(run_time), Vector2(520.0, 0.0), null)

# --- Gebietswechsel ---

func _change_stage() -> void:
	_map_change_t = -1.0
	_stage_after_chest = false
	_collect_remaining()
	stage += 1
	stage_seed = maxi(1, int(main_node.match_seed) + stage * 7919) if main_node.get("match_seed") != null else stage * 7919
	stage_map_id = HordeDefs.stage_map(stage, stage_seed)
	main_node.horde_change_map(stage_map_id, stage_seed)

## main meldet: neues Gebiet ist gebaut. Gegner, Kristalle und Geschosse des
## alten Gebiets verschwinden, das Fluss-Feld wird neu berechnet.
func on_map_changed() -> void:
	for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var en := node as HordeEnemy
		if en != null and not en.is_replica:
			en.is_dead = true
			en.queue_free()
	_shots.clear()
	_gems.clear()
	_free.clear()
	_flow = PackedInt32Array()
	_bfs_active = false
	_spawn_acc = 2.0
	_spawn_grace = STAGE_SPAWN_GRACE
	_powerup_t = minf(_powerup_t, 8.0)
	_setup_scroll()
	_refresh_free_mask()
	_rebuild_flow()
	var title := ArenaMaps.display_name(stage_map_id)
	_post_notice("Neues Gebiet: %s" % title, Color(0.7, 1.0, 0.85))

func _collect(g: Dictionary, p: Node2D) -> void:
	match str(g["t"]):
		"xp":
			xp += int(g["v"])
			if _coin_sound_t <= 0.0:
				_coin_sound_t = 0.06
				SoundManager.play_sound("coin", 0.15, -10.0)
		"food":
			if p != null and p.has_method("heal"):
				p.heal(FOOD_HEAL)
			NetFx.emit(get_parent(), "sound", {"snd": ["heal", 0.1, -4.0]})
		"chest":
			pending_bonus += 1
			pending_levelups += 1
			_post_notice("Truhe! Bonus-Karte für alle.", Color(1.0, 0.85, 0.3))
			NetFx.emit(get_parent(), "sound", {"snd": ["mystery", 0.0, 0.0]})

func _check_levelup() -> void:
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = HordeDefs.xp_needed(level, player_count)
		pending_levelups += 1
	if pending_levelups > 0 and not levelup_active and over == 0:
		pending_levelups -= 1
		levelup_active = true
		levelup_ready.emit()

## main meldet: Kartenwahl fertig, weiter geht's.
func on_levelup_finished() -> void:
	levelup_active = false
	if pending_bonus > 0:
		pending_bonus -= 1
		# Truhen-Auswahl nach einem Boss fertig: weiter ins nächste Gebiet.
		if _stage_after_chest and pending_bonus == 0:
			_map_change_t = MAP_CHANGE_AFTER_CHEST

# --- Gegnergeschosse ---

## z: Flughöhe des Geschosses (Standhöhe des Ziels + Mündungshöhe). Auf
## erhöhte Eber fliegt es im Bogen über niedrigere Hindernisse.
func spawn_shot(pos: Vector2, vel: Vector2, dmg: float, k: String, z: float = ArenaMode.MUZZLE_H) -> void:
	_shots.append({"pos": pos, "vel": vel, "dmg": dmg, "k": k, "life": 3.0, "z": z})

## Blockiert die Zelle ein Geschoss in Höhe z? (Stege lassen unten durch.)
static func _blocks_shot(grid: ArenaGrid, c: Vector2i, z: float) -> bool:
	if float(grid.segment_cells.get(c, 0.0)) > z:
		return true
	for b in grid.blocks.get(c, []):
		var span: Vector2 = b
		if span.x < z and span.y > z:
			return true
	return false

func _update_shots(delta: float) -> void:
	var grid := ArenaMode.grid
	var targets := alive_targets()
	var i := _shots.size() - 1
	while i >= 0:
		var s: Dictionary = _shots[i]
		s["life"] = float(s["life"]) - delta
		var pos: Vector2 = s["pos"] + s["vel"] * delta
		s["pos"] = pos
		var gone := float(s["life"]) <= 0.0
		if not gone and grid != null:
			var c := grid.cell_of(pos)
			if not grid.in_bounds(c) or _blocks_shot(grid, c, float(s.get("z", ArenaMode.MUZZLE_H))):
				gone = true
		if not gone:
			# Wer über das Geschoss springt oder deutlich tiefer steht, wird nicht getroffen.
			var hz := float(s.get("z", ArenaMode.MUZZLE_H)) - ArenaMode.MUZZLE_H
			for p in targets:
				if p.arena_z > hz + 40.0 or p.arena_z < hz - 30.0:
					continue
				var r: float = SHOT_RADIUS + 12.0 * p.scale.x / Player.BASE_CHARACTER_SCALE
				if pos.distance_to(p.global_position) < r:
					p.take_damage(float(s["dmg"]), (s["vel"] as Vector2).normalized() * 150.0, null)
					gone = true
					break
		if gone:
			_shots.remove_at(i)
		i -= 1

func _update_shots_visual(delta: float) -> void:
	for s in _shots:
		s["pos"] = s["pos"] + s["vel"] * delta

# --- Spielertod, Wiederbelebung, Ende ---

func on_player_died(slot: int) -> void:
	var s: Dictionary = slot_stats.get(slot, {"kills": 0, "damage": 0.0, "deaths": 0})
	s["deaths"] = int(s["deaths"]) + 1
	slot_stats[slot] = s
	_dead_slots[slot] = true
	_respawns.append({"slot": slot, "t": HordeDefs.RESPAWN_DELAY})
	# Alle tot (der Sterbende ist schon raus)? Dann ist die Jagd verloren.
	var anyone := false
	for p in main_node.players:
		if is_instance_valid(p) and p.player_index != slot and not p.is_dead and p.current_health > 0.0:
			anyone = true
			break
	if not anyone:
		_finish(false)
	else:
		_post_notice("%s ist gefallen – steht in %d s wieder auf." % [Global.get_player_name(slot), int(HordeDefs.RESPAWN_DELAY)], Color(1.0, 0.5, 0.5))

func _update_respawns(delta: float) -> void:
	var i := _respawns.size() - 1
	while i >= 0:
		var r: Dictionary = _respawns[i]
		r["t"] = float(r["t"]) - delta
		if float(r["t"]) <= 0.0:
			var targets := alive_targets()
			if not targets.is_empty():
				var anchor: Node2D = targets[_rng.randi() % targets.size()]
				_dead_slots.erase(int(r["slot"]))
				main_node.horde_respawn_player(int(r["slot"]), anchor.global_position + Vector2(_rng.randf_range(-30, 30), _rng.randf_range(-30, 30)))
				_post_notice("%s ist wieder da!" % Global.get_player_name(int(r["slot"])), Color(0.5, 1.0, 0.6))
			_respawns.remove_at(i)
		i -= 1

func respawn_left(slot: int) -> float:
	for r in _respawns:
		if int(r["slot"]) == slot:
			return float(r["t"])
	return -1.0

func _finish(victory: bool) -> void:
	if over != 0:
		return
	over = 1 if victory else 2
	running = false
	SoundManager.play_sound("match_win" if victory else "round_end", 0.0, 0.0)
	run_over.emit(victory)

func _post_notice(text: String, color: Color) -> void:
	_notice_seq += 1
	_notice_text = text
	_notice_color = color
	notice.emit(text, color)

## Restzeit bis zum nächsten Boss (oder -1).
func next_boss_in() -> float:
	if boss_index >= HordeDefs.BOSS_TIMES.size():
		return -1.0
	return HordeDefs.BOSS_TIMES[boss_index] - run_time

func boss_health_ratio() -> float:
	if boss_info.is_empty():
		return -1.0
	if boss != null and is_instance_valid(boss):
		return clampf(boss.current_health / maxf(1.0, boss.max_health), 0.0, 1.0)
	return float(boss_info.get("hp", -1.0))

# ============================================================
# Netzwerk
# ============================================================

const KIND_ORDER: Array[String] = ["fuchs", "wolf", "adler", "metzger", "krokodil", "jaeger", "alphawolf", "baer", "boss"]

func get_network_state() -> Dictionary:
	_net_count += 1
	var rows: Array = []
	for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var en := node as HordeEnemy
		if en == null or en.is_dead or en.is_replica:
			continue
		rows.append(en.get_net_row(KIND_ORDER.find(en.kind)))
	var shots: Array = []
	for s in _shots:
		var p: Vector2 = s["pos"]
		var v: Vector2 = s["vel"]
		shots.append([int(p.x), int(p.y), int(v.x), int(v.y), s["k"], int(s.get("z", ArenaMode.MUZZLE_H))])
	var data := {
		"t": snappedf(run_time, 0.1), "lv": level, "xp": xp, "xn": xp_next, "k": kills,
		"e": rows, "s": shots, "o": over, "pc": player_count,
		"n": [_notice_seq, _notice_text, _notice_color.to_html()],
		"st": slot_stats, "rs": _respawn_snapshot(), "nb": snappedf(next_boss_in(), 0.1),
		"stg": [stage, stage_map_id, stage_seed], "sx": snappedf(scroll_x, 0.5),
	}
	if not boss_info.is_empty():
		var b := boss_info.duplicate()
		b["hp"] = snappedf(boss_health_ratio(), 0.005)
		data["b"] = b
	if _net_count % GEM_SNAPSHOT_EVERY == 1:
		var gems: Array = []
		for g in _gems:
			var gp: Vector2 = g["pos"]
			gems.append([int(gp.x), int(gp.y), int(g["v"]), str(g["t"])])
		data["g"] = gems
	return data

func _respawn_snapshot() -> Dictionary:
	var out := {}
	for r in _respawns:
		out[int(r["slot"])] = snappedf(float(r["t"]), 0.1)
	return out

var _replica_respawns: Dictionary = {}
var _replica_next_boss: float = -1.0

func apply_network_state(data: Dictionary) -> void:
	run_time = float(data.get("t", run_time))
	level = int(data.get("lv", level))
	xp = int(data.get("xp", xp))
	xp_next = int(data.get("xn", xp_next))
	kills = int(data.get("k", kills))
	player_count = int(data.get("pc", player_count))
	var st = data.get("st", null)
	if st is Dictionary:
		slot_stats = st
	var rs = data.get("rs", null)
	if rs is Dictionary:
		_replica_respawns = rs
	_replica_next_boss = float(data.get("nb", -1.0))
	scroll_x = float(data.get("sx", scroll_x))
	var stg = data.get("stg", null)
	if stg is Array and stg.size() >= 3 and int(stg[0]) != stage:
		stage = int(stg[0])
		stage_map_id = str(stg[1])
		stage_seed = int(stg[2])
		if main_node != null and main_node.has_method("horde_apply_map"):
			main_node.horde_apply_map(stage_map_id, stage_seed)
		for id in _replicas.keys():
			if is_instance_valid(_replicas[id]):
				_replicas[id].queue_free()
		_replicas.clear()
	var b = data.get("b", null)
	boss_info = b if b is Dictionary else {}
	var n = data.get("n", null)
	if n is Array and n.size() >= 3 and int(n[0]) != _seen_notice:
		_seen_notice = int(n[0])
		if _seen_notice > 0:
			notice.emit(str(n[1]), Color.html(str(n[2])))
	var new_over := int(data.get("o", 0))
	if new_over != over:
		over = new_over
		if over != 0:
			run_over.emit(over == 1)
	_shots.clear()
	for s in data.get("s", []):
		_shots.append({"pos": Vector2(float(s[0]), float(s[1])), "vel": Vector2(float(s[2]), float(s[3])), "k": str(s[4]), "life": 1.0,
			"z": float(s[5]) if s.size() > 5 else ArenaMode.MUZZLE_H})
	var g = data.get("g", null)
	if g is Array:
		_gems.clear()
		for row in g:
			_gems.append({"pos": Vector2(float(row[0]), float(row[1])), "v": int(row[2]), "t": str(row[3])})
	_sync_replicas(data.get("e", []))

func _sync_replicas(rows: Array) -> void:
	var seen := {}
	for row in rows:
		if not (row is Array) or row.size() < 8:
			continue
		var id := int(row[0])
		seen[id] = true
		var en: HordeEnemy = _replicas.get(id, null)
		if en == null or not is_instance_valid(en):
			var k_idx := int(row[1])
			var kind: String = KIND_ORDER[clampi(k_idx, 0, KIND_ORDER.size() - 1)]
			en = HordeEnemy.new()
			en.is_replica = true
			en.net_id = id
			if kind == "boss":
				en.setup_boss(str(boss_info.get("hero", "ignis")), 1.0, 1.0)
			else:
				en.setup(kind, false, 1.0, 1.0)
			en.max_health = 1.0
			en.position = Vector2(float(row[2]), float(row[3]))
			get_parent().add_child(en)
			_replicas[id] = en
		en.apply_net_row(row)
	for id in _replicas.keys():
		if not seen.has(id):
			var en = _replicas[id]
			if is_instance_valid(en):
				en.queue_free()
			_replicas.erase(id)

func replica_respawn_left(slot: int) -> float:
	if not is_replica:
		return respawn_left(slot)
	return float(_replica_respawns.get(slot, _replica_respawns.get(str(slot), -1.0)))

func replica_next_boss_in() -> float:
	return _replica_next_boss if is_replica else next_boss_in()

# ============================================================
# Zeichnen: Kristalle, Futter, Truhen, Geschosse
# ============================================================

func _draw() -> void:
	if scroll_x >= 0.0:
		var mh := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
		var pulse := 0.5 + 0.5 * sin(_anim_t * 6.0)
		draw_rect(Rect2(scroll_x - 4000.0, 0.0, 4000.0, mh), Color(0.9, 0.22, 0.08, 0.32))
		draw_rect(Rect2(scroll_x - 26.0, 0.0, 26.0, mh), Color(1.0, 0.45, 0.1, 0.45 + 0.2 * pulse))
		draw_line(Vector2(scroll_x, 0.0), Vector2(scroll_x, mh), Color(1.0, 0.85, 0.35, 0.9), 4.0)
	for g in _gems:
		var p: Vector2 = g["pos"]
		match str(g["t"]):
			"xp":
				var v := int(g["v"])
				var col := HordeDefs.gem_color(v)
				var r := 4.0 + minf(6.0, sqrt(float(v)) * 1.3)
				var bob := sin(_anim_t * 4.0 + p.x * 0.05) * 2.0
				var c := p + Vector2(0, -6.0 + bob)
				draw_circle(p, r * 0.9, Color(0, 0, 0, 0.22))
				var pts := PackedVector2Array([c + Vector2(0, -r * 1.4), c + Vector2(r, 0), c + Vector2(0, r * 1.1), c + Vector2(-r, 0)])
				draw_colored_polygon(pts, col)
				draw_polyline(pts + PackedVector2Array([pts[0]]), col.lightened(0.5), 1.2, true)
				draw_circle(c + Vector2(-r * 0.3, -r * 0.5), r * 0.28, Color(1, 1, 1, 0.8))
			"food":
				var c2 := p + Vector2(0, -6.0)
				draw_circle(p, 7.0, Color(0, 0, 0, 0.22))
				draw_circle(c2, 7.0, Color(0.62, 0.38, 0.16))
				draw_rect(Rect2(c2 + Vector2(-7, -9), Vector2(14, 5)), Color(0.42, 0.26, 0.1))
				draw_line(c2 + Vector2(0, -9), c2 + Vector2(2, -13), Color(0.3, 0.2, 0.08), 2.0)
			"chest":
				var c3 := p + Vector2(0, -10.0 + sin(_anim_t * 3.0) * 3.0)
				draw_circle(p, 16.0, Color(1.0, 0.8, 0.3, 0.18 + 0.1 * sin(_anim_t * 5.0)))
				draw_rect(Rect2(c3 + Vector2(-14, -10), Vector2(28, 20)), Color(0.55, 0.32, 0.12))
				draw_rect(Rect2(c3 + Vector2(-14, -10), Vector2(28, 7)), Color(0.7, 0.42, 0.16))
				draw_rect(Rect2(c3 + Vector2(-14, -10), Vector2(28, 20)), Color(1.0, 0.82, 0.3), false, 2.0)
				draw_rect(Rect2(c3 + Vector2(-3, -5), Vector2(6, 7)), Color(1.0, 0.85, 0.3))
	for s in _shots:
		var p: Vector2 = s["pos"] + ArenaMode.height_offset(float(s.get("z", ArenaMode.MUZZLE_H)))
		match str(s["k"]):
			"cleaver":
				var a := _anim_t * 14.0
				var d := Vector2.from_angle(a)
				draw_line(p - d * 9.0, p + d * 9.0, Color(0.85, 0.88, 0.92), 5.0)
				draw_line(p - d * 9.0, p - d * 3.0, Color(0.35, 0.22, 0.12), 5.0)
			"pellet":
				draw_circle(p, 4.5, Color(1.0, 0.85, 0.4))
				draw_circle(p, 2.5, Color(1.0, 1.0, 0.85))
			_:
				draw_circle(p, 10.0, Color(1.0, 0.3, 0.45, 0.35))
				draw_circle(p, 6.5, Color(1.0, 0.45, 0.6))
				draw_circle(p, 3.0, Color(1.0, 0.9, 0.95))
