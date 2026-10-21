class_name LevelGenerator
extends Node2D

const TILE_SIZE: float = 36.0 # 18px * 2.0
const MAP_WIDTH: int = 38
const MAP_HEIGHT: int = 22
const RUBBER_BAND: float = 320.0

signal tile_broken(tile_id: int)
signal tile_regrown(tile_id: int)

@export var jump_pad_scene: PackedScene = preload("res://scenes/level/jump_pad.tscn")
@export var warp_pipe_scene: PackedScene = preload("res://scenes/level/warp_pipe.tscn")
@export var mystery_block_scene: PackedScene = preload("res://scenes/level/mystery_block.tscn")
@export var hazard_spike_scene: PackedScene = preload("res://scenes/level/hazard_spike.tscn")
@export var special_tile_scene: PackedScene = preload("res://scenes/level/special_tile.tscn")
@export var ice_patch_scene: PackedScene = preload("res://scenes/level/ice_patch.tscn")
@export var rubber_wall_scene: PackedScene = preload("res://scenes/level/rubber_wall.tscn")

var ground_top_textures: Array[Texture2D] = []
var ground_bottom_textures: Array[Texture2D] = []
var platform_textures: Array[Texture2D] = []
var destructible_textures: Array[Texture2D] = []
var strong_vine_textures: Array[Texture2D] = []
var weak_vine_textures: Array[Texture2D] = []
var decoration_textures: Array[Texture2D] = []
var ice_tex: Texture2D

var p1_spawn_pos: Vector2 = Vector2.ZERO
var p2_spawn_pos: Vector2 = Vector2.ZERO

var _rng: RandomNumberGenerator
var _solid_cells: Dictionary = {}
var _special_cells: Dictionary = {}
var _object_cells: Dictionary = {}
var _ice_cells: Dictionary = {}
var _special_tiles: Dictionary = {} # tile_id (int) -> SpecialTile

func _ready() -> void:
	_load_textures()
	generate_level()

func _load_textures() -> void:
	ground_top_textures = [
		load("res://assets/tiles/tile_0000.png"),
		load("res://assets/tiles/tile_0002.png"),
		load("res://assets/tiles/tile_0003.png"),
		load("res://assets/tiles/tile_0020.png"),
		load("res://assets/tiles/tile_0021.png"),
		load("res://assets/tiles/tile_0022.png"),
		load("res://assets/tiles/tile_0023.png"),
	]
	ground_bottom_textures = [
		load("res://assets/tiles/tile_0004.png"),
		load("res://assets/tiles/tile_0005.png"),
		load("res://assets/tiles/tile_0006.png"),
		load("res://assets/tiles/tile_0024.png"),
		load("res://assets/tiles/tile_0025.png"),
		load("res://assets/tiles/tile_0026.png"),
	]
	platform_textures = [
		load("res://assets/tiles/tile_0001.png"),
		load("res://assets/tiles/tile_0024.png"),
		load("res://assets/tiles/tile_0025.png"),
		load("res://assets/tiles/tile_0026.png"),
		load("res://assets/tiles/tile_0030.png"),
		load("res://assets/tiles/tile_0040.png"),
		load("res://assets/tiles/tile_0042.png"),
		load("res://assets/tiles/tile_0130.png"),
		load("res://assets/tiles/tile_0131.png"),
		load("res://assets/tiles/tile_0146.png"),
		load("res://assets/tiles/tile_0147.png"),
	]
	destructible_textures = [
		load("res://assets/tiles/tile_0012.png"),
		load("res://assets/tiles/tile_0013.png"),
		load("res://assets/tiles/tile_0014.png"),
		load("res://assets/tiles/tile_0015.png"),
	]
	strong_vine_textures = [
		load("res://assets/tiles/tile_0036.png"),
		load("res://assets/tiles/tile_0037.png"),
		load("res://assets/tiles/tile_0038.png"),
		load("res://assets/tiles/tile_0039.png"),
	]
	weak_vine_textures = [
		load("res://assets/tiles/tile_0096.png"),
		load("res://assets/tiles/tile_0097.png"),
		load("res://assets/tiles/tile_0098.png"),
		load("res://assets/tiles/tile_0099.png"),
	]
	decoration_textures = [
		load("res://assets/tiles/tile_0124.png"),
		load("res://assets/tiles/tile_0125.png"),
		load("res://assets/tiles/tile_0126.png"),
		load("res://assets/tiles/tile_0127.png"),
		load("res://assets/tiles/tile_0128.png"),
	]
	ice_tex = load("res://assets/tiles/tile_0033.png")

func generate_level(level_seed: int = 0) -> void:
	# Clear existing generated children
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	_solid_cells.clear()
	_special_cells.clear()
	_object_cells.clear()
	_ice_cells.clear()
	_special_tiles.clear()
	
	# Eigener Zufallsgenerator: Bei Netzwerkpartien erzeugen Host und Client
	# mit demselben Seed exakt dieselbe Karte.
	_rng = RandomNumberGenerator.new()
	if level_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = level_seed
	
	# 1. Boden: obere Grasschicht + Erde. Keine Seiten- oder Deckenwände –
	#    außerhalb der Karte übernimmt die Gummiwand.
	_build_rect_solid(0, MAP_WIDTH - 1, MAP_HEIGHT - 2, MAP_HEIGHT - 2, ground_top_textures)
	_build_rect_solid(0, MAP_WIDTH - 1, MAP_HEIGHT - 1, MAP_HEIGHT - 1, ground_bottom_textures)
	
	# 2. Grundlayout (0: Stepped, 1: Multi-Tier, 2: Floating Islands)
	var archetype := _rng.randi() % 3
	match archetype:
		0:
			_generate_stepped_arena()
		1:
			_generate_multitier_arena()
		2:
			_generate_islands_arena()
	
	# 3. Zusätzliche, gespiegelte Plattformen für mehr Varianz
	_add_random_platforms()
	
	# 4. Spezial-Tiles: Eis, Ranken, zerstörbare Blöcke
	_place_ice_patches()
	_place_vine_bridges()
	_place_destructible_clusters()
	
	# 5. Kleine Deko auf Plattformen
	_place_decorations()
	
	# 6. Symmetrische Spawns
	p1_spawn_pos = Vector2(4.0 * TILE_SIZE, (MAP_HEIGHT - 4) * TILE_SIZE)
	p2_spawn_pos = Vector2((MAP_WIDTH - 5.0) * TILE_SIZE, (MAP_HEIGHT - 4) * TILE_SIZE)
	
	# 7. Gummiwand außerhalb der Karte
	_build_rubber_boundary()

func _generate_stepped_arena() -> void:
	# Stepped pyramids on both sides
	var steps = 4
	for s in range(steps):
		var y = MAP_HEIGHT - 3 - s
		# Left step
		_build_rect_solid(4 + s, 8, y, y, platform_textures)
		# Right step (mirrored)
		_build_rect_solid(MAP_WIDTH - 9, MAP_WIDTH - 5 - s, y, y, platform_textures)
	
	# Center high platform
	_build_rect_solid(MAP_WIDTH / 2 - 4, MAP_WIDTH / 2 + 3, 11, 11, platform_textures)
	# Upper side ledges
	_build_rect_solid(8, 14, 7, 7, platform_textures)
	_build_rect_solid(MAP_WIDTH - 15, MAP_WIDTH - 9, 7, 7, platform_textures)
	
	# Mystery Blocks floating above center
	_spawn_mystery_block(MAP_WIDTH / 2 - 2, 8)
	_spawn_mystery_block(MAP_WIDTH / 2 + 1, 8)
	
	# Jump pads at bottom
	_spawn_jump_pad(11, MAP_HEIGHT - 3)
	_spawn_jump_pad(MAP_WIDTH - 12, MAP_HEIGHT - 3)
	
	# Warp Pipes (Left and Right)
	_spawn_pipe_pair(3, MAP_HEIGHT - 3, MAP_WIDTH - 4, MAP_HEIGHT - 3)
	
	# Small spike hazard in center pit
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_multitier_arena() -> void:
	# Lower side platforms
	_build_rect_solid(3, 12, 16, 16, platform_textures)
	_build_rect_solid(MAP_WIDTH - 13, MAP_WIDTH - 4, 16, 16, platform_textures)
	
	# Mid central battle bridge
	_build_rect_solid(13, MAP_WIDTH - 14, 12, 12, ground_top_textures)
	
	# High sniper perches
	_build_rect_solid(6, 11, 7, 7, platform_textures)
	_build_rect_solid(MAP_WIDTH - 12, MAP_WIDTH - 7, 7, 7, platform_textures)
	
	# Mystery Blocks
	_spawn_mystery_block(MAP_WIDTH / 2, 8)
	_spawn_mystery_block(8, 13)
	_spawn_mystery_block(MAP_WIDTH - 9, 13)
	
	# Jump pads
	_spawn_jump_pad(6, 15)
	_spawn_jump_pad(MAP_WIDTH - 7, 15)
	
	# Warp Pipes
	_spawn_pipe_pair(3, 15, MAP_WIDTH - 4, 15)

func _generate_islands_arena() -> void:
	# Floating Mario style islands
	_build_rect_solid(5, 11, 15, 15, platform_textures)
	_build_rect_solid(MAP_WIDTH - 12, MAP_WIDTH - 6, 15, 15, platform_textures)
	
	_build_rect_solid(MAP_WIDTH / 2 - 5, MAP_WIDTH / 2 + 4, 14, 14, ground_top_textures)
	_build_rect_solid(MAP_WIDTH / 2 - 3, MAP_WIDTH / 2 + 2, 8, 8, platform_textures)
	
	# Floating blocks
	_spawn_mystery_block(MAP_WIDTH / 2 - 2, 5)
	_spawn_mystery_block(MAP_WIDTH / 2 + 1, 5)
	
	# Jump pads on floor
	_spawn_jump_pad(8, MAP_HEIGHT - 3)
	_spawn_jump_pad(MAP_WIDTH - 9, MAP_HEIGHT - 3)
	
	# Warp Pipes
	_spawn_pipe_pair(3, MAP_HEIGHT - 3, MAP_WIDTH - 4, MAP_HEIGHT - 3)
	
	# Spikes
	_spawn_spike(14, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH - 15, MAP_HEIGHT - 3)

func _build_rect_solid(x_start: int, x_end: int, y_start: int, y_end: int, textures: Array) -> void:
	if textures.is_empty():
		return
	var width_tiles = (x_end - x_start + 1)
	var height_tiles = (y_end - y_start + 1)
	
	var body = StaticBody2D.new()
	body.add_to_group("solid")
	body.collision_layer = 1
	body.collision_mask = 7
	
	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(width_tiles * TILE_SIZE, height_tiles * TILE_SIZE)
	col.shape = rect
	col.position = Vector2((x_start + width_tiles * 0.5) * TILE_SIZE, (y_start + height_tiles * 0.5) * TILE_SIZE)
	body.add_child(col)
	
	# Fill with tiled sprites
	for x in range(x_start, x_end + 1):
		for y in range(y_start, y_end + 1):
			var sp = Sprite2D.new()
			sp.texture = _pick_texture(textures, x, y)
			sp.scale = Vector2(2.0, 2.0)
			sp.position = Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE)
			body.add_child(sp)
			_solid_cells[Vector2i(x, y)] = true
	
	add_child(body)

func _pick_texture(textures: Array, x: int, y: int) -> Texture2D:
	if textures.size() == 1:
		return textures[0] as Texture2D
	var idx: int = (x * 7 + y * 13) % textures.size()
	if _rng and _rng.randf() < 0.18:
		idx = _rng.randi() % textures.size()
	return textures[idx] as Texture2D

func _add_random_platforms() -> void:
	var placed := 0
	var attempts := 0
	while placed < 3 and attempts < 24:
		attempts += 1
		var w := 3 + _rng.randi() % 3
		var y := 5 + _rng.randi() % 9
		var max_x := int(MAP_WIDTH / 2) - w - 3
		if max_x < 3:
			continue
		var x := 3 + _rng.randi() % (max_x - 2)
		var x_end := x + w - 1
		if not _is_rect_free(x, x_end, y, y):
			continue
		_build_rect_solid(x, x_end, y, y, platform_textures)
		var mirror_x := MAP_WIDTH - 1 - x_end
		if _is_rect_free(mirror_x, mirror_x + w - 1, y, y):
			_build_rect_solid(mirror_x, mirror_x + w - 1, y, y, platform_textures)
		placed += 1

func _place_ice_patches() -> void:
	var top_cells: Array[Vector2i] = []
	for cell in _solid_cells.keys():
		var x: int = cell.x
		var y: int = cell.y
		if y <= 0:
			continue
		if _solid_cells.has(Vector2i(x, y - 1)):
			continue
		top_cells.append(cell)
	if top_cells.is_empty():
		return
	
	var patches := 0
	var attempts := 0
	while patches < 4 and attempts < 30:
		attempts += 1
		var start: Vector2i = top_cells[_rng.randi() % top_cells.size()]
		var run_len := 2 + _rng.randi() % 3
		var placed_any := false
		for i in range(run_len):
			var ice_cell := Vector2i(start.x + i, start.y)
			if _spawn_ice_patch(ice_cell):
				placed_any = true
		if placed_any:
			patches += 1

func _can_place_ice(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= MAP_WIDTH or cell.y < 0 or cell.y >= MAP_HEIGHT:
		return false
	if not _solid_cells.has(cell):
		return false
	if _solid_cells.has(Vector2i(cell.x, cell.y - 1)):
		return false
	if _object_cells.has(cell) or _special_cells.has(cell) or _ice_cells.has(cell):
		return false
	if _is_near_spawn(cell.x, cell.y):
		return false
	return true

func _spawn_ice_patch(cell: Vector2i) -> bool:
	if not _can_place_ice(cell):
		return false
	var patch: IcePatch = ice_patch_scene.instantiate()
	patch.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(patch)
	_ice_cells[cell] = true
	
	# Spiegelung für faire Verteilung auf beiden Kartenseiten.
	var mirror := Vector2i(MAP_WIDTH - 1 - cell.x, cell.y)
	if _can_place_ice(mirror):
		var patch2: IcePatch = ice_patch_scene.instantiate()
		patch2.position = Vector2((mirror.x + 0.5) * TILE_SIZE, (mirror.y + 0.5) * TILE_SIZE)
		add_child(patch2)
		_ice_cells[mirror] = true
	return true

func _place_vine_bridges() -> void:
	_try_place_vine_bridge(SpecialTile.Kind.STRONG_VINE, 3, 5, 6, 12, true)
	_try_place_vine_bridge(SpecialTile.Kind.WEAK_VINE, 4, 6, 9, 15, true)
	_try_place_vine_bridge(SpecialTile.Kind.STRONG_VINE, 3, 4, 13, 16, false)
	_try_place_vine_bridge(SpecialTile.Kind.WEAK_VINE, 3, 5, 6, 9, false)

func _try_place_vine_bridge(kind: int, min_w: int, max_w: int, min_y: int, max_y: int, mirror: bool) -> void:
	var attempts := 0
	while attempts < 24:
		attempts += 1
		var w := min_w + _rng.randi() % (max_w - min_w + 1)
		var y := min_y + _rng.randi() % (max_y - min_y + 1)
		var max_x := int(MAP_WIDTH / 2) - w - 2
		if max_x < 3:
			continue
		var x := 3 + _rng.randi() % (max_x - 2)
		var x_end := x + w - 1
		if not _is_rect_free(x, x_end, y, y):
			continue
		for tx in range(x, x_end + 1):
			_spawn_special_tile(tx, y, kind)
		if mirror:
			var mx := MAP_WIDTH - 1 - x_end
			if _is_rect_free(mx, mx + w - 1, y, y):
				for tx in range(mx, mx + w):
					_spawn_special_tile(tx, y, kind)
		return

func _place_destructible_clusters() -> void:
	var placed := 0
	var attempts := 0
	while placed < 3 and attempts < 30:
		attempts += 1
		var w := 2
		var h := 2
		var y := 8 + _rng.randi() % 7
		var max_x := int(MAP_WIDTH / 2) - w - 3
		if max_x < 3:
			continue
		var x := 3 + _rng.randi() % (max_x - 2)
		var x_end := x + w - 1
		var y_end := y + h - 1
		if not _is_rect_free(x, x_end, y, y_end):
			continue
		for tx in range(x, x_end + 1):
			for ty in range(y, y_end + 1):
				_spawn_special_tile(tx, ty, SpecialTile.Kind.DESTRUCTIBLE)
		var mx := MAP_WIDTH - 1 - x_end
		if _is_rect_free(mx, mx + w - 1, y, y_end):
			for tx in range(mx, mx + w):
				for ty in range(y, y_end + 1):
					_spawn_special_tile(tx, ty, SpecialTile.Kind.DESTRUCTIBLE)
		placed += 1

func _place_decorations() -> void:
	var top_cells: Array[Vector2i] = []
	for cell in _solid_cells.keys():
		var x: int = cell.x
		var y: int = cell.y
		if y <= 0:
			continue
		if _solid_cells.has(Vector2i(x, y - 1)):
			continue
		if _object_cells.has(cell) or _ice_cells.has(cell) or _special_cells.has(cell):
			continue
		if _is_near_spawn(x, y):
			continue
		top_cells.append(cell)
	if top_cells.is_empty():
		return
	
	var count := mini(8, top_cells.size())
	for i in range(count):
		if top_cells.is_empty():
			break
		var idx := _rng.randi() % top_cells.size()
		var deco_cell: Vector2i = top_cells[idx]
		top_cells.remove_at(idx)
		var deco := Sprite2D.new()
		deco.texture = decoration_textures[_rng.randi() % decoration_textures.size()]
		deco.scale = Vector2(2.0, 2.0)
		deco.position = Vector2((deco_cell.x + 0.5) * TILE_SIZE, deco_cell.y * TILE_SIZE - 18.0)
		add_child(deco)

func _spawn_special_tile(tx: int, ty: int, kind: int) -> void:
	var tile_id := ty * MAP_WIDTH + tx
	var tile: SpecialTile = special_tile_scene.instantiate()
	tile.tile_id = tile_id
	tile.kind = kind
	match kind:
		SpecialTile.Kind.STRONG_VINE:
			tile.regrow_time = 8.0
			tile.tile_texture = strong_vine_textures[_rng.randi() % strong_vine_textures.size()]
		SpecialTile.Kind.WEAK_VINE:
			tile.regrow_time = 4.5
			tile.tile_texture = weak_vine_textures[_rng.randi() % weak_vine_textures.size()]
		_:
			tile.regrow_time = 0.0
			tile.tile_texture = destructible_textures[_rng.randi() % destructible_textures.size()]
	tile.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 0.5) * TILE_SIZE)
	add_child(tile)
	tile.broken.connect(_on_special_tile_broken)
	tile.regrown.connect(_on_special_tile_regrown)
	_special_tiles[tile_id] = tile
	_special_cells[Vector2i(tx, ty)] = true

func _on_special_tile_broken(tile_id: int) -> void:
	tile_broken.emit(tile_id)

func _on_special_tile_regrown(tile_id: int) -> void:
	tile_regrown.emit(tile_id)

func apply_network_tile_broken(tile_id: int) -> void:
	var tile := _special_tiles.get(tile_id, null) as SpecialTile
	if tile and is_instance_valid(tile):
		tile.apply_network_break()

func apply_network_tile_regrown(tile_id: int) -> void:
	var tile := _special_tiles.get(tile_id, null) as SpecialTile
	if tile and is_instance_valid(tile):
		tile.apply_network_regrow()

func get_special_tile(tile_id: int) -> Node:
	return _special_tiles.get(tile_id, null)

func _is_rect_free(x_start: int, x_end: int, y_start: int, y_end: int) -> bool:
	if x_start < 0 or x_end >= MAP_WIDTH or y_start < 0 or y_end >= MAP_HEIGHT:
		return false
	for x in range(x_start, x_end + 1):
		for y in range(y_start, y_end + 1):
			var cell := Vector2i(x, y)
			if _solid_cells.has(cell) or _special_cells.has(cell) or _object_cells.has(cell) or _ice_cells.has(cell):
				return false
	return true

func _is_near_spawn(x: int, y: int) -> bool:
	# Die Spawns liegen unten links/rechts. Dort keine Spezial-Tiles platzieren.
	return y >= MAP_HEIGHT - 6 and (x <= 7 or x >= MAP_WIDTH - 8)

func _build_rubber_boundary() -> void:
	var map_size := Vector2(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE)
	var inner := Rect2(Vector2.ZERO, map_size)
	var band := RUBBER_BAND
	
	# Vier Bänder außerhalb der Karte. Sie sind keine soliden Wände, sondern
	# Sensoren: Schaden + Rückstoß in Richtung Kartenmitte.
	_add_rubber_band(Rect2(-band, -band, band, map_size.y + band * 2.0), inner)
	_add_rubber_band(Rect2(map_size.x, -band, band, map_size.y + band * 2.0), inner)
	_add_rubber_band(Rect2(0, -band, map_size.x, band), inner)
	_add_rubber_band(Rect2(0, map_size.y, map_size.x, band), inner)
	
	# Sichtbarer Neon-Rand als Markierung der Gummiwand.
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(map_size.x, 0),
		map_size,
		Vector2(0, map_size.y),
		Vector2.ZERO,
	])
	var glow := Line2D.new()
	glow.points = points
	glow.width = 26.0
	glow.default_color = Color(1.0, 0.15, 0.55, 0.18)
	glow.z_index = 1
	add_child(glow)
	
	var line := Line2D.new()
	line.points = points
	line.width = 5.0
	line.default_color = Color(1.0, 0.25, 0.65, 0.95)
	line.z_index = 2
	add_child(line)
	
	var tw := line.create_tween().set_loops()
	tw.tween_property(line, "modulate:a", 0.55, 1.1)
	tw.tween_property(line, "modulate:a", 1.0, 1.1)

func _add_rubber_band(rect: Rect2, inner: Rect2) -> void:
	var wall: RubberWall = rubber_wall_scene.instantiate()
	wall.inner_rect = inner
	wall.position = rect.position + rect.size * 0.5
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	wall.add_child(shape)
	add_child(wall)

func _spawn_jump_pad(tx: int, ty: int) -> void:
	var pad = jump_pad_scene.instantiate()
	pad.scale = Vector2(2.0, 2.0)
	pad.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 1.0) * TILE_SIZE)
	add_child(pad)
	_object_cells[Vector2i(tx, ty)] = true

func _spawn_pipe_pair(tx1: int, ty1: int, tx2: int, ty2: int) -> void:
	var pipe1: WarpPipe = warp_pipe_scene.instantiate()
	var pipe2: WarpPipe = warp_pipe_scene.instantiate()
	
	pipe1.position = Vector2((tx1 + 0.5) * TILE_SIZE, (ty1 + 1.0) * TILE_SIZE)
	pipe2.position = Vector2((tx2 + 0.5) * TILE_SIZE, (ty2 + 1.0) * TILE_SIZE)
	
	pipe1.target_pipe = pipe2
	pipe2.target_pipe = pipe1
	
	add_child(pipe1)
	add_child(pipe2)
	_object_cells[Vector2i(tx1, ty1)] = true
	_object_cells[Vector2i(tx1, ty1 - 1)] = true
	_object_cells[Vector2i(tx2, ty2)] = true
	_object_cells[Vector2i(tx2, ty2 - 1)] = true

func _spawn_mystery_block(tx: int, ty: int) -> void:
	var mb = mystery_block_scene.instantiate()
	mb.scale = Vector2(2.0, 2.0)
	mb.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 0.5) * TILE_SIZE)
	add_child(mb)
	_object_cells[Vector2i(tx, ty)] = true

func _spawn_spike(tx: int, ty: int) -> void:
	var sp = hazard_spike_scene.instantiate()
	sp.scale = Vector2(2.0, 2.0)
	sp.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 1.0) * TILE_SIZE)
	add_child(sp)
	_object_cells[Vector2i(tx, ty)] = true
