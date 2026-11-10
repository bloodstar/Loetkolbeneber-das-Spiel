class_name ArenaBuilder
extends RefCounted

# Baut eine Arena-Karte (ArenaMaps) in den bestehenden LevelGenerator: nur
# Kollision und Spiellogik in 2D, keine 2D-Grafik. Die Darstellung übernimmt
# ArenaView3D. Die Schnittstelle des LevelGenerators (Spawns, Kacheln,
# Netzwerk-Tile-IDs) bleibt dadurch für main.gd und alle Systeme gleich.

const BORDER_THICKNESS: float = 72.0
# Dicke schräger Wände in Pixeln (knapp eine Kachel).
const WALL_THICKNESS: float = 30.0

static var spawn_cells: Array[Vector2i] = []
static var current_map: Dictionary = {}
static var current_map_id: String = ""
static var _spawn_cache_total: int = -1
static var _spawn_cache: Array[Vector2] = []

static func build(lg: LevelGenerator, map_id: String, level_seed: int) -> void:
	var data := ArenaMaps.get_map(map_id)
	var rows: Array = data.get("rows", [])
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, str(r).length())

	# Texturen der Standard-Map für zerstörbare Kacheln laden (deren Sprite
	# bleibt unsichtbar, die Logik braucht aber eine Textur).
	lg._apply_tileset("grasarena")
	lg.current_map_id = map_id
	LevelGenerator.map_w = w
	LevelGenerator.map_h = h
	current_map = data
	current_map_id = map_id
	spawn_cells.clear()
	_spawn_cache_total = -1
	_spawn_cache.clear()

	var grid := ArenaGrid.new()
	grid.setup(w, h, LevelGenerator.TILE_SIZE)
	ArenaMode.grid = grid
	ArenaMode.active = true
	set_world_gravity(lg, false)

	for y in range(h):
		var row := str(rows[y])
		var x := 0
		while x < w:
			var ch := row[x] if x < row.length() else "."
			if ch == "S":
				spawn_cells.append(Vector2i(x, y))
				x += 1
				continue
			if ch == "x":
				var top_x: float = ArenaMaps.BLOCK_HEIGHTS["x"]
				lg._spawn_special_tile(x, y, SpecialTile.Kind.DESTRUCTIBLE)
				var tile_id := y * w + x
				var tile := lg.get_special_tile(tile_id) as SpecialTile
				if tile:
					tile.collision_layer = ArenaMode.band_mask_range(0.0, top_x)
					tile.visible = false
				grid.add_block(Vector2i(x, y), 0.0, top_x)
				grid.destructible[Vector2i(x, y)] = tile_id
				x += 1
				continue
			if not ArenaMaps.BLOCK_HEIGHTS.has(ch):
				x += 1
				continue
			# Gleiche Blöcke einer Reihe zu einem Körper zusammenfassen.
			var x_end := x
			while x_end + 1 < w and x_end + 1 < row.length() and row[x_end + 1] == ch:
				x_end += 1
			var top: float = ArenaMaps.BLOCK_HEIGHTS[ch]
			_add_block_body(lg, x, x_end, y, 0.0, top)
			for cx in range(x, x_end + 1):
				grid.add_block(Vector2i(cx, y), 0.0, top)
			x = x_end + 1

	# Schräge Wände: [x1, y1, x2, y2, Höhenzeichen] in Kachel-Koordinaten.
	var tile_px := LevelGenerator.TILE_SIZE
	for wall in data.get("walls", []):
		var a := Vector2(float(wall[0]), float(wall[1])) * tile_px
		var b := Vector2(float(wall[2]), float(wall[3])) * tile_px
		var ch := str(wall[4]) if wall.size() > 4 else "#"
		var top_w: float = ArenaMaps.BLOCK_HEIGHTS.get(ch, 108.0)
		_add_segment_body(lg, a, b, WALL_THICKNESS, 0.0, top_w)
		grid.add_segment(a, b, WALL_THICKNESS, 0.0, top_w)

	_build_border(lg, w, h)
	var spawns := spawn_positions(2, level_seed)
	lg.p1_spawn_pos = spawns[0]
	lg.p2_spawn_pos = spawns[1] if spawns.size() > 1 else spawns[0]

## Verlässt den Arena-Modus (Seitenansicht-Karte wird gebaut).
static func deactivate(lg: LevelGenerator) -> void:
	if not ArenaMode.active:
		return
	ArenaMode.active = false
	ArenaMode.grid = null
	current_map = {}
	current_map_id = ""
	set_world_gravity(lg, true)

## RigidBodies (Kisten, Fässer, Münzen) fallen in der Draufsicht nicht.
static func set_world_gravity(lg: Node, enabled: bool) -> void:
	if not lg.is_inside_tree():
		return
	var space := lg.get_viewport().world_2d.space
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0) if enabled else 0.0
	PhysicsServer2D.area_set_param(space, PhysicsServer2D.AREA_PARAM_GRAVITY, g)

static func _add_block_body(lg: Node, x0: int, x1: int, y: int, bottom: float, top: float) -> void:
	var tile := LevelGenerator.TILE_SIZE
	var body := StaticBody2D.new()
	body.add_to_group("solid")
	body.add_to_group("arena_block")
	body.collision_layer = ArenaMode.band_mask_range(bottom, top)
	body.collision_mask = 7
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(float(x1 - x0 + 1) * tile, tile)
	col.shape = rect
	col.position = Vector2((float(x0) + float(x1 - x0 + 1) * 0.5) * tile, (float(y) + 0.5) * tile)
	body.add_child(col)
	lg.add_child(body)

static func _add_segment_body(lg: Node, a: Vector2, b: Vector2, thick: float, bottom: float, top: float) -> void:
	var body := StaticBody2D.new()
	body.add_to_group("solid")
	body.add_to_group("arena_block")
	body.collision_layer = ArenaMode.band_mask_range(bottom, top)
	body.collision_mask = 7
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Etwas länger als die Strecke, damit Ecken zweier Wände dicht schließen.
	rect.size = Vector2(a.distance_to(b) + thick, thick)
	col.shape = rect
	body.position = (a + b) * 0.5
	body.rotation = (b - a).angle()
	body.add_child(col)
	lg.add_child(body)

static func _build_border(lg: Node, w: int, h: int) -> void:
	var tile := LevelGenerator.TILE_SIZE
	var mw := float(w) * tile
	var mh := float(h) * tile
	var t := BORDER_THICKNESS
	for r in [
		Rect2(-t, -t, t, mh + t * 2.0),
		Rect2(mw, -t, t, mh + t * 2.0),
		Rect2(0, -t, mw, t),
		Rect2(0, mh, mw, t),
	]:
		var rect: Rect2 = r
		var body := StaticBody2D.new()
		body.collision_layer = ArenaMode.all_bands_mask()
		body.collision_mask = 7
		body.add_to_group("solid")
		body.add_to_group("map_border")
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		col.shape = shape
		col.position = rect.get_center()
		body.add_child(col)
		lg.add_child(body)

## Spawnpunkte für total Spieler: zufällig (Seed), aber weit verteilt.
static func spawn_positions(total: int, level_seed: int) -> Array[Vector2]:
	if total == _spawn_cache_total and _spawn_cache.size() >= total:
		return _spawn_cache
	var tile := LevelGenerator.TILE_SIZE
	var cands: Array[Vector2] = []
	for c in spawn_cells:
		cands.append((Vector2(c) + Vector2(0.5, 0.5)) * tile)
	if cands.is_empty():
		var mid := Vector2(LevelGenerator.map_w, LevelGenerator.map_h) * tile * 0.5
		cands.append(mid)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([level_seed, "arena_spawns"])
	var result: Array[Vector2] = []
	result.append(cands[rng.randi() % cands.size()])
	while result.size() < total:
		# Weitester Kandidat zu allen bisherigen (mit etwas Zufall).
		var best := cands[0]
		var best_score := -1.0
		for c in cands:
			var nearest := INF
			for r in result:
				nearest = minf(nearest, c.distance_to(r))
			var score := nearest * rng.randf_range(0.85, 1.0)
			if score > best_score:
				best_score = score
				best = c
		result.append(best)
	_spawn_cache_total = total
	_spawn_cache = result
	return result
