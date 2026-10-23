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
@export var seesaw_scene: PackedScene = preload("res://scenes/level/seesaw.tscn")
@export var chain_platform_scene: PackedScene = preload("res://scenes/level/chain_platform.tscn")
@export var barrel_scene: PackedScene = preload("res://scenes/level/barrel.tscn")
@export var crate_scene: PackedScene = preload("res://scenes/level/crate.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/level/powerup.tscn")

const CRATE_SIZES: Array = [0.82, 1.0, 1.16]
const POWERUP_KINDS: Array[String] = ["heal", "invulnerability", "damage", "rapid_fire"]

# Jede Map hat ein festes Tileset und ein festes Layout-Profil. Damit bleibt
# die Optik einer Map konsistent, statt zufällig Tilesets zu mischen.
const MAP_PROFILES: Dictionary = {
	"grasarena": {
		"archetype": "stepped",
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [36, 37, 38, 39],
		"weak_vine": [96, 97, 98, 99],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [33],
		"accent": Color(0.25, 0.95, 0.55, 1.0),
		"ice_patches": 3,
		"vines": true,
		"destructibles": 3,
		"random_platforms": 3,
		"seesaws": 1,
		"chains": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.55,
		"powerups": 2,
	},
	"wuestenruine": {
		"archetype": "islands",
		"ground_top": [120, 121, 122, 123, 140, 141, 142, 143],
		"ground_bottom": [120, 121, 122, 123, 140, 141, 142, 143],
		"platform": [40, 41, 42, 43, 60, 61, 62, 63, 144, 145, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [],
		"accent": Color(1.0, 0.72, 0.25, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 2,
		"seesaws": 0,
		"chains": 2,
		"barrels": 1,
		"tnt_barrels": 2,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.5,
		"powerups": 1,
	},
	"eisgrotte": {
		"archetype": "multitier",
		"ground_top": [80, 81, 82, 83, 100, 101, 102, 103],
		"ground_bottom": [53, 54, 55, 73, 74, 75],
		"platform": [53, 54, 55, 73, 74, 75, 113, 114, 115],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [153, 154, 155, 156],
		"ice": [33],
		"accent": Color(0.45, 0.85, 1.0, 1.0),
		"ice_patches": 6,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 2,
		"seesaws": 1,
		"chains": 1,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"neonfabrik": {
		"archetype": "stepped",
		"ground_top": [113, 114, 115, 132, 133, 134],
		"ground_bottom": [132, 133, 134, 113, 114, 115],
		"platform": [111, 112, 113, 114, 115, 132, 133, 134],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [150, 151, 152, 157, 158, 159],
		"ice": [],
		"accent": Color(0.2, 0.85, 1.0, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 3,
		"random_platforms": 3,
		"seesaws": 0,
		"chains": 2,
		"barrels": 1,
		"tnt_barrels": 2,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
}

var current_map_id: String = "grasarena"
var current_accent: Color = Color(1.0, 0.25, 0.65, 0.95)
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
var _tile_cache: Dictionary = {}
var _moving_objects: Array[Node] = []
var _moving_objects_by_id: Dictionary = {}
var _next_moving_object_id: int = 1
var _claimed_spawn_cells: Array[int] = []
var _crate_powerup_chance: float = 0.0
var _crate_drops_spawned: int = 0

func _ready() -> void:
	_load_textures()
	generate_level()

func _load_textures() -> void:
	_tile_cache.clear()
	_apply_tileset("grasarena")

func _tile_texture(index: int) -> Texture2D:
	if not _tile_cache.has(index):
		var path := "res://assets/tiles/tile_%04d.png" % index
		if ResourceLoader.exists(path):
			_tile_cache[index] = load(path)
		else:
			_tile_cache[index] = null
	return _tile_cache[index] as Texture2D

func _textures_for(indices: Array) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for raw_index in indices:
		var tex := _tile_texture(int(raw_index))
		if tex != null:
			result.append(tex)
	return result

func _apply_tileset(map_id: String) -> void:
	current_map_id = map_id if MAP_PROFILES.has(map_id) else "grasarena"
	var profile: Dictionary = MAP_PROFILES[current_map_id]
	ground_top_textures = _textures_for(profile.get("ground_top", []))
	ground_bottom_textures = _textures_for(profile.get("ground_bottom", []))
	platform_textures = _textures_for(profile.get("platform", []))
	destructible_textures = _textures_for(profile.get("destructible", []))
	strong_vine_textures = _textures_for(profile.get("strong_vine", []))
	weak_vine_textures = _textures_for(profile.get("weak_vine", []))
	decoration_textures = _textures_for(profile.get("decoration", []))
	var ice_indices: Array = profile.get("ice", [])
	ice_tex = _tile_texture(int(ice_indices[0])) if not ice_indices.is_empty() else null
	current_accent = profile.get("accent", Color(1.0, 0.25, 0.65, 0.95))

func generate_level(level_seed: int = 0, map_id: String = "") -> void:
	# Clear existing generated children
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	_solid_cells.clear()
	_special_cells.clear()
	_object_cells.clear()
	_ice_cells.clear()
	_special_tiles.clear()
	_moving_objects.clear()
	_moving_objects_by_id.clear()
	_next_moving_object_id = 1
	_claimed_spawn_cells.clear()
	_crate_powerup_chance = 0.0
	_crate_drops_spawned = 0
	
	# Eigener Zufallsgenerator: Bei Netzwerkpartien erzeugen Host und Client
	# mit demselben Seed exakt dieselbe Karte.
	_rng = RandomNumberGenerator.new()
	if level_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = level_seed

	var resolved_map := map_id
	if not MAP_PROFILES.has(resolved_map):
		resolved_map = Global.resolve_map_id(level_seed)
	_apply_tileset(resolved_map)
	var profile: Dictionary = MAP_PROFILES[current_map_id]
	
	# 1. Boden: obere Grasschicht + Erde. Keine Seiten- oder Deckenwände –
	#    außerhalb der Karte übernimmt die Gummiwand.
	_build_rect_solid(0, MAP_WIDTH - 1, MAP_HEIGHT - 2, MAP_HEIGHT - 2, ground_top_textures)
	_build_rect_solid(0, MAP_WIDTH - 1, MAP_HEIGHT - 1, MAP_HEIGHT - 1, ground_bottom_textures)
	
	# 2. Festes Layout-Profil pro Map.
	match str(profile.get("archetype", "stepped")):
		"islands":
			_generate_islands_arena()
		"multitier":
			_generate_multitier_arena()
		_:
			_generate_stepped_arena()
	
	# 3. Zusätzliche, gespiegelte Plattformen für mehr Varianz
	_add_random_platforms(int(profile.get("random_platforms", 3)))
	
	# 4. Spezial-Tiles: Eis, Ranken, zerstörbare Blöcke
	_place_ice_patches(int(profile.get("ice_patches", 0)))
	if bool(profile.get("vines", false)):
		_place_vine_bridges()
	_place_destructible_clusters(int(profile.get("destructibles", 3)))

	# 5. Bewegliche Map-Objekte (host-seitig simuliert, für Clients repliziert)
	_spawn_map_objects(profile)
	
	# 6. Kleine Deko auf Plattformen
	_place_decorations()
	
	# 7. Symmetrische Spawns. Die endgültigen Positionen werden erst später
	#    gegen Map-Objekte geprüft, weil Kisten und Powerups ebenfalls Spawn-
	#    Flächen belegen.
	p1_spawn_pos = _spawn_position_at(4)
	p2_spawn_pos = _spawn_position_at(MAP_WIDTH - 5)
	
	# 8. Gummiwand außerhalb der Karte
	_build_rubber_boundary()

# Liefert die Spawnposition für einen Spieler-Slot. Für 2 Spieler bleiben die
# bewährten linken/rechten Spawns erhalten, ab 3 Spielern werden die Plätze
# gleichmäßig am unteren Kartenrand verteilt. Jeder Platz sucht sich bei Bedarf
# die nächste freie Fläche, damit niemand auf Federn, Röhren, Kisten oder
# Stacheln startet.
func get_spawn_position(index: int, total: int) -> Vector2:
	var preferred_tile := 4
	if total > 1:
		var margin := 4.0
		var usable := float(MAP_WIDTH) - margin * 2.0
		var t := float(clampi(index - 1, 0, total - 1)) / float(maxi(total - 1, 1))
		preferred_tile = int(round(margin + usable * t))
	elif index > 1:
		preferred_tile = MAP_WIDTH - 5
	if total <= 2:
		preferred_tile = 4 if index <= 1 else MAP_WIDTH - 5

	var offsets: Array[int] = [0]
	for distance in range(1, MAP_WIDTH):
		offsets.append(distance)
		offsets.append(-distance)
	for offset in offsets:
		var tile_x := preferred_tile + offset
		if _is_spawn_tile_clear(tile_x, _claimed_spawn_cells):
			_claimed_spawn_cells.append(tile_x)
			return _spawn_position_at(tile_x)

	# Notfall: irgendeinen freien Platz am Boden nehmen.
	for tile_x in range(2, MAP_WIDTH - 2):
		if _is_spawn_tile_clear(tile_x, []):
			_claimed_spawn_cells.append(tile_x)
			return _spawn_position_at(tile_x)
	return _spawn_position_at(preferred_tile)

func _spawn_position_at(tile_x: int) -> Vector2:
	return Vector2((float(tile_x) + 0.5) * TILE_SIZE, float(MAP_HEIGHT - 4) * TILE_SIZE)

func _is_spawn_tile_clear(tile_x: int, claimed: Array) -> bool:
	if tile_x < 2 or tile_x >= MAP_WIDTH - 2:
		return false
	# Der Charakter ist mit seiner Kollisionsbreite (30,6 px) schmaler als eine
	# Kachel (36 px). Deshalb muss nur die Spawn-Kachel selbst frei sein; die
	# drei Reihen über dem Boden bleiben trotzdem gesperrt.
	for row in range(MAP_HEIGHT - 5, MAP_HEIGHT - 2):
		var cell := Vector2i(tile_x, row)
		if _solid_cells.has(cell) or _object_cells.has(cell) or _special_cells.has(cell) or _ice_cells.has(cell):
			return false
	for claimed_tile in claimed:
		if int(claimed_tile) == tile_x:
			return false
	return true

# Öffentliche Prüfung für Tests und Debug-Anzeigen.
func is_spawn_position_clear(world_position: Vector2) -> bool:
	var tile_x := int(floor(world_position.x / TILE_SIZE))
	return _is_spawn_tile_clear(tile_x, [])

func _generate_stepped_arena() -> void:
	# Schlanke, schwebende Balken statt Treppen. Zwischen den Ebenen bleiben
	# zwei freie Kacheln (72 px) Luft, damit die Charaktere darunter
	# durchlaufen und bequem auf die nächste Ebene springen können.
	_build_rect_solid(7, 13, 17, 17, platform_textures)
	_build_rect_solid(24, 30, 17, 17, platform_textures)
	_build_rect_solid(10, 16, 14, 14, platform_textures)
	_build_rect_solid(21, 27, 14, 14, platform_textures)
	_build_rect_solid(7, 9, 11, 11, platform_textures)
	_build_rect_solid(28, 30, 11, 11, platform_textures)
	_build_rect_solid(15, 22, 11, 11, platform_textures)
	_build_rect_solid(9, 12, 8, 8, platform_textures)
	_build_rect_solid(25, 28, 8, 8, platform_textures)

	# Herz-Blöcke schweben über der zentralen Wippe.
	_spawn_mystery_block(MAP_WIDTH / 2 - 2, 4)
	_spawn_mystery_block(MAP_WIDTH / 2 + 1, 4)

	# Federn auf den unteren Balken; die mittlere Feder katapultiert auf die
	# zentral aufgehängte Wippe.
	_spawn_jump_pad(8, 16)
	_spawn_jump_pad(29, 16)
	_spawn_jump_pad(19, 10)

	# Röhren und Stacheln bleiben am Boden, aber außerhalb der Spawn-Ecken.
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_multitier_arena() -> void:
	# Mehrere luftige Etagen aus schmalen Balken. Die Ebenen liegen drei
	# Kacheln auseinander, sodass zwischen ihnen genug Kopfraum bleibt.
	_build_rect_solid(6, 12, 17, 17, platform_textures)
	_build_rect_solid(25, 31, 17, 17, platform_textures)
	_build_rect_solid(8, 14, 14, 14, platform_textures)
	_build_rect_solid(23, 29, 14, 14, platform_textures)
	_build_rect_solid(5, 10, 11, 11, platform_textures)
	_build_rect_solid(27, 32, 11, 11, platform_textures)
	_build_rect_solid(14, 23, 11, 11, ground_top_textures)
	_build_rect_solid(16, 21, 8, 8, platform_textures)

	_spawn_mystery_block(9, 8)
	_spawn_mystery_block(28, 8)

	_spawn_jump_pad(7, 16)
	_spawn_jump_pad(30, 16)
	_spawn_jump_pad(18, 7)
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_islands_arena() -> void:
	# Kleine, offene Inseln mit klaren Sprungwegen. Keine massiven Treppen-
	# blöcke, nur ein Kachel hohe Plattformen mit zwei Kacheln Luft dazwischen.
	_build_rect_solid(7, 12, 17, 17, platform_textures)
	_build_rect_solid(25, 30, 17, 17, platform_textures)
	_build_rect_solid(9, 14, 14, 14, platform_textures)
	_build_rect_solid(23, 28, 14, 14, platform_textures)
	_build_rect_solid(5, 9, 11, 11, platform_textures)
	_build_rect_solid(28, 32, 11, 11, platform_textures)
	_build_rect_solid(14, 23, 11, 11, ground_top_textures)
	_build_rect_solid(16, 21, 8, 8, platform_textures)

	_spawn_mystery_block(MAP_WIDTH / 2 - 2, 5)
	_spawn_mystery_block(MAP_WIDTH / 2 + 1, 5)

	_spawn_jump_pad(11, MAP_HEIGHT - 3)
	_spawn_jump_pad(MAP_WIDTH - 12, MAP_HEIGHT - 3)
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

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

func _add_random_platforms(count: int = 3) -> void:
	var placed := 0
	var attempts := 0
	# Die zusätzlichen Balken dürfen keine niedrigen Decken über den festen
	# Ebenen erzeugen. Deshalb wird neben den belegten Kacheln auch der
	# vertikale Freiraum geprüft.
	while placed < count and attempts < 48:
		attempts += 1
		var w := 3 + _rng.randi() % 3
		var y := 5 + _rng.randi() % 10
		var max_x := int(MAP_WIDTH / 2) - w - 3
		if max_x < 3:
			continue
		var x := 3 + _rng.randi() % (max_x - 2)
		var x_end := x + w - 1
		if not _is_rect_free(x, x_end, y, y):
			continue
		if not _has_vertical_clearance(x, x_end, y, y):
			continue
		_build_rect_solid(x, x_end, y, y, platform_textures)
		var mirror_x := MAP_WIDTH - 1 - x_end
		if (_is_rect_free(mirror_x, mirror_x + w - 1, y, y)
				and _has_vertical_clearance(mirror_x, mirror_x + w - 1, y, y)):
			_build_rect_solid(mirror_x, mirror_x + w - 1, y, y, platform_textures)
		placed += 1

func _place_ice_patches(desired_patches: int = 4) -> void:
	if desired_patches <= 0:
		return
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
	while patches < desired_patches and attempts < 30:
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

func _place_destructible_clusters(desired_clusters: int = 3) -> void:
	if desired_clusters <= 0:
		return
	var placed := 0
	var attempts := 0
	while placed < desired_clusters and attempts < 30:
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

func _is_top_available(cell: Vector2i, check_spawn: bool = true) -> bool:
	if cell.x < 0 or cell.x >= MAP_WIDTH or cell.y <= 0 or cell.y >= MAP_HEIGHT:
		return false
	if not _solid_cells.has(cell):
		return false
	var above := Vector2i(cell.x, cell.y - 1)
	if _solid_cells.has(above):
		return false
	if _object_cells.has(cell) or _object_cells.has(above):
		return false
	if _special_cells.has(cell) or _special_cells.has(above):
		return false
	if _ice_cells.has(cell):
		return false
	if check_spawn and _is_near_spawn(cell.x, cell.y):
		return false
	return true

func _place_decorations() -> void:
	if decoration_textures.is_empty():
		return
	var top_cells: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if _is_top_available(cell):
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

# Prüft, ob über und unter einem neuen Objekt genug Luft bleibt. Zwei freie
# Kacheln entsprechen 72 px und damit dem Mindestabstand der Plattformebenen.
func _has_vertical_clearance(x_start: int, x_end: int, y_start: int, y_end: int, free_rows: int = 2) -> bool:
	if y_start - free_rows < 0 or y_end + free_rows >= MAP_HEIGHT:
		return false
	for check_y in range(y_start - free_rows, y_end + free_rows + 1):
		if check_y >= y_start and check_y <= y_end:
			continue
		for x in range(x_start, x_end + 1):
			var cell := Vector2i(x, check_y)
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
	var glow_color := current_accent
	glow_color.a = 0.18
	glow.default_color = glow_color
	glow.z_index = 1
	add_child(glow)
	
	var line := Line2D.new()
	line.points = points
	line.width = 5.0
	var line_color := current_accent
	line_color.a = 0.95
	line.default_color = line_color
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

# --- Bewegliche Map-Objekte -------------------------------------------------

func _register_moving_object(obj: Node) -> void:
	obj.set("net_id", _next_moving_object_id)
	obj.set("is_replica", Global.network_mode and not Global.is_local_host())
	_next_moving_object_id += 1
	_moving_objects.append(obj)
	_moving_objects_by_id[int(obj.get("net_id"))] = obj

func _spawn_map_objects(profile: Dictionary) -> void:
	_crate_powerup_chance = float(profile.get("crate_powerup_chance", 0.0))
	for _i in range(int(profile.get("seesaws", 0))):
		_try_spawn_seesaw()
	for i in range(int(profile.get("chains", 0))):
		_try_spawn_chain_platform(i)
	for _i in range(int(profile.get("barrels", 0))):
		_spawn_barrel(false)
	for _i in range(int(profile.get("tnt_barrels", 0))):
		_spawn_barrel(true)
	for _i in range(int(profile.get("crate_stacks", 0))):
		_spawn_crate_stack()
	for _i in range(int(profile.get("powerups", 0))):
		_spawn_random_powerup()

func _try_spawn_seesaw() -> void:
	# Die Wippe ist ein zentrales Landmarken-Objekt und hängt sichtbar in der
	# Luft. Sie wird nicht mehr auf den Boden oder auf eine zufällige Plattform
	# gestellt. Die Höhe richtet sich nach der obersten festen Ebene, damit
	# zwischen Wippe und Plattform genug Kopfraum bleibt.
	var width := 6
	var center_tile := int(MAP_WIDTH / 2)
	var archetype := str(MAP_PROFILES.get(current_map_id, {}).get("archetype", "stepped"))
	var center_row := 5 if archetype == "multitier" else 6
	var center_y := float(center_row) * TILE_SIZE
	var start := center_tile - int(width / 2)
	var seesaw := seesaw_scene.instantiate()
	seesaw.set("plank_width", float(width) * TILE_SIZE)
	seesaw.set("suspended", true)
	seesaw.set("chain_length", 3.0 * TILE_SIZE)
	seesaw.position = Vector2(
		(float(center_tile) + 0.5) * TILE_SIZE,
		center_y
	)
	_register_moving_object(seesaw)
	add_child(seesaw)
	for x in range(start, start + width):
		_object_cells[Vector2i(x, center_row - 1)] = true
		_object_cells[Vector2i(x, center_row)] = true

func _spawn_crate_stack() -> void:
	var cell := _find_crate_stack_cell()
	if cell.x < 0:
		return
	var stack_height := 2 + _rng.randi() % 3
	var center_x := (float(cell.x) + 0.5) * TILE_SIZE
	var cursor_y := float(cell.y) * TILE_SIZE - 2.0
	var used_cells: Array[Vector2i] = []
	for index in range(stack_height):
		var size_factor: float = CRATE_SIZES[_rng.randi() % CRATE_SIZES.size()]
		var size_px := 36.0 * size_factor
		var crate := crate_scene.instantiate()
		crate.set("crate_size", size_factor)
		crate.set("health", 2)
		crate.set("max_health", 2)
		crate.connect("crate_broken", Callable(self, "_on_crate_broken"))
		var jitter := _rng.randf_range(-1.5, 1.5)
		crate.position = Vector2(center_x + jitter, cursor_y - size_px * 0.5)
		crate.rotation = _rng.randf_range(-0.025, 0.025)
		_register_moving_object(crate)
		add_child(crate)
		used_cells.append(Vector2i(cell.x, int(floor(crate.position.y / TILE_SIZE))))
		cursor_y = crate.position.y - size_px * 0.5 - 1.0
	for used_cell in used_cells:
		for dx in range(-1, 2):
			for dy in range(-1, 1):
				_object_cells[Vector2i(used_cell.x + dx, used_cell.y + dy)] = true

func _find_crate_stack_cell() -> Vector2i:
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y <= 5:
			continue
		if not _is_top_available(cell):
			continue
		if not _has_crate_headroom(cell, 5):
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[_rng.randi() % candidates.size()]

func _has_crate_headroom(cell: Vector2i, height: int) -> bool:
	for dy in range(1, height + 1):
		var above := Vector2i(cell.x, cell.y - dy)
		if above.y < 0:
			return false
		if _solid_cells.has(above) or _special_cells.has(above) or _object_cells.has(above) or _ice_cells.has(above):
			return false
	return true

func _on_crate_broken(world_position, attacker) -> void:
	if _crate_drops_spawned >= 4:
		return
	if _rng.randf() > _crate_powerup_chance:
		return
	_crate_drops_spawned += 1
	call_deferred("_spawn_powerup_at", world_position, _random_powerup_kind())

func _spawn_random_powerup() -> void:
	var spawn_pos := _find_powerup_position()
	if spawn_pos == Vector2.INF:
		return
	_spawn_powerup_at(spawn_pos, _random_powerup_kind())

func _find_powerup_position() -> Vector2:
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y <= 4:
			continue
		if not _is_top_available(cell):
			continue
		if not _has_crate_headroom(cell, 2):
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return Vector2.INF
	for _attempt in range(24):
		var cell: Vector2i = candidates[_rng.randi() % candidates.size()]
		var pos := Vector2((float(cell.x) + 0.5) * TILE_SIZE, float(cell.y) * TILE_SIZE - 32.0)
		_object_cells[Vector2i(cell.x, cell.y - 1)] = true
		return pos
	return Vector2.INF

func _spawn_powerup_at(world_position: Vector2, kind: String) -> void:
	if not is_inside_tree():
		return
	var powerup := powerup_scene.instantiate()
	powerup.set("kind", kind)
	powerup.position = world_position
	_register_moving_object(powerup)
	add_child(powerup)

func _random_powerup_kind() -> String:
	return POWERUP_KINDS[_rng.randi() % POWERUP_KINDS.size()]

func _try_spawn_chain_platform(index: int) -> void:
	# Die Kettenplattformen hängen oberhalb der obersten festen Ebene. So
	# bilden sie keinen niedrigen Deckel zwischen zwei Etagen.
	var spots: Array[Dictionary] = [
		{"cx": 14, "anchor_y": 1, "length": 4},
		{"cx": 23, "anchor_y": 1, "length": 4},
		{"cx": 18, "anchor_y": 0, "length": 5},
		{"cx": 10, "anchor_y": 0, "length": 5},
		{"cx": 27, "anchor_y": 0, "length": 5},
	]
	var width := 4
	for offset in range(spots.size()):
		var spot: Dictionary = spots[(index + offset) % spots.size()]
		var cx := int(spot.get("cx", 18))
		var anchor_y := int(spot.get("anchor_y", 6))
		var length := int(spot.get("length", 5))
		var platform_y := anchor_y + length
		var x_start := cx - int(width / 2)
		var x_end := x_start + width - 1
		if not _is_rect_free(x_start, x_end, platform_y, platform_y):
			continue
		if not _has_vertical_clearance(x_start, x_end, platform_y, platform_y):
			continue
		var chain := chain_platform_scene.instantiate()
		chain.set("platform_width", float(width) * TILE_SIZE)
		chain.set("chain_length", float(length) * TILE_SIZE)
		chain.position = Vector2(
			(float(x_start) + float(width) * 0.5) * TILE_SIZE,
			(float(anchor_y) + 0.5) * TILE_SIZE
		)
		_register_moving_object(chain)
		add_child(chain)
		for x in range(x_start, x_end + 1):
			_object_cells[Vector2i(x, platform_y)] = true
		return

func _spawn_barrel(explosive: bool) -> void:
	var cell := _find_barrel_cell(explosive)
	if cell.x < 0:
		return
	var barrel := barrel_scene.instantiate()
	barrel.set("explosive", explosive)
	barrel.position = Vector2((float(cell.x) + 0.5) * TILE_SIZE, float(cell.y) * TILE_SIZE - 22.0)
	_register_moving_object(barrel)
	add_child(barrel)
	_object_cells[cell] = true
	_object_cells[Vector2i(cell.x, cell.y - 1)] = true

func _find_barrel_cell(explosive: bool) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y < 10:
			continue
		if not _is_top_available(cell):
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	if explosive:
		var best := candidates[0]
		var best_score := INF
		for cell in candidates:
			var score := absf(float(cell.x) + 0.5 - float(MAP_WIDTH) * 0.5) * 2.5
			score += float((MAP_HEIGHT - 2) - cell.y) * 3.0
			if score < best_score:
				best_score = score
				best = cell
		return best
	return candidates[_rng.randi() % candidates.size()]

func _instantiate_moving_object_from_snapshot(data: Dictionary) -> Node:
	var object_type := str(data.get("type", ""))
	var obj: Node = null
	match object_type:
		"crate":
			obj = crate_scene.instantiate()
			obj.set("crate_size", float(data.get("size", 1.0)))
		"powerup":
			obj = powerup_scene.instantiate()
			obj.set("kind", str(data.get("kind", "heal")))
		"barrel", "tnt_barrel":
			obj = barrel_scene.instantiate()
			obj.set("explosive", object_type == "tnt_barrel")
		_:
			return null
	obj.set("is_replica", true)
	return obj

func _adopt_moving_object(obj: Node, id: int) -> void:
	obj.set("net_id", id)
	obj.set("is_replica", true)
	_moving_objects.append(obj)
	_moving_objects_by_id[id] = obj
	if id >= _next_moving_object_id:
		_next_moving_object_id = id + 1

func get_moving_object_snapshots() -> Array:
	var result: Array = []
	for obj in _moving_objects:
		if not is_instance_valid(obj) or obj.is_queued_for_deletion():
			continue
		if obj.has_method("get_network_state"):
			result.append(obj.get_network_state())
	return result

func get_moving_object_count() -> int:
	var count := 0
	for obj in _moving_objects:
		if is_instance_valid(obj) and not obj.is_queued_for_deletion() and obj.has_method("get_network_state"):
			count += 1
	return count

func apply_moving_object_snapshots(snapshots: Array) -> void:
	if not Global.network_mode or Global.is_local_host():
		return
	var seen: Dictionary = {}
	for raw_snapshot in snapshots:
		if not raw_snapshot is Dictionary:
			continue
		var data: Dictionary = raw_snapshot
		var id := int(data.get("id", -1))
		if id < 0:
			continue
		seen[id] = true
		var obj = _moving_objects_by_id.get(id)
		if obj == null or not is_instance_valid(obj) or obj.is_queued_for_deletion():
			obj = _instantiate_moving_object_from_snapshot(data)
			if obj != null:
				_adopt_moving_object(obj, id)
				add_child(obj)
		if obj != null and is_instance_valid(obj) and not obj.is_queued_for_deletion():
			if obj.has_method("apply_network_state"):
				obj.apply_network_state(data)
	var missing: Array[int] = []
	for id in _moving_objects_by_id.keys():
		if not seen.has(id):
			missing.append(int(id))
	for id in missing:
		var obj = _moving_objects_by_id.get(id)
		_moving_objects_by_id.erase(id)
		if obj == null:
			continue
		_moving_objects.erase(obj)
		if not is_instance_valid(obj):
			continue
		if obj.has_method("spawn_remote_explosion"):
			obj.spawn_remote_explosion()
		else:
			obj.queue_free()
