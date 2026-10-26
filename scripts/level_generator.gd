class_name LevelGenerator
extends Node2D

const TILE_SIZE: float = 36.0 # 18px * 2.0
# 44 x 25 statt der früheren 38 x 22: rund 32 % mehr Fläche. Die zusätzliche
# Breite und Höhe geben den neuen offenen Karten und der Kistenfestung mehr
# Raum, ohne die Sprungdistanzen der Helden zu verändern.
const MAP_WIDTH: int = 44
const MAP_HEIGHT: int = 25
const RUBBER_BAND: float = 320.0
# Abstand der Spawn-Mitte über der Standfläche. Der Player-Körper reicht etwa
# 12 px unter seinen Ursprung, sodass die Figur knapp über der Fläche startet
# und nicht mehrere Kacheln fällt.
const SPAWN_BODY_OFFSET: float = 14.0
const SPAWN_HEADROOM_ROWS: int = 2
const SPAWN_EDGE_MARGIN: int = 2

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
@export var deep_snow_scene: PackedScene = preload("res://scenes/level/deep_snow.tscn")
@export var trampoline_ground_scene: PackedScene = preload("res://scenes/level/trampoline_ground.tscn")
@export var speed_booster_scene: PackedScene = preload("res://scenes/level/speed_booster.tscn")

const ThemeBackdropScript = preload("res://scripts/level/theme_backdrop.gd")

const CRATE_SIZES: Array = [0.82, 1.0, 1.16]
const POWERUP_KINDS: Array[String] = ["heal", "invulnerability", "damage", "rapid_fire"]

# Visuelle Themes sind bewusst von den Layout-Profilen getrennt. Die Arena
# entsteht weiterhin ausschließlich aus "archetype" & Co.; ein Theme tauscht
# nur Materialien, Deko und additive Spezialflächen aus.
const TILESET_THEMES: Dictionary = {
	"storybook": {
		"dir": "res://assets/tilesets/storybook",
		"ground_top": ["ground_top_0.png", "ground_top_1.png", "ground_top_2.png"],
		"ground_bottom": ["fill_0.png", "fill_1.png", "fill_2.png"],
		"platform": ["platform_0.png", "platform_1.png", "platform_2.png"],
		"destructible": ["destructible_0.png", "destructible_1.png"],
		"strong_vine": ["vine_strong_0.png", "vine_strong_1.png"],
		"weak_vine": ["vine_weak_0.png", "vine_weak_1.png"],
		"decoration": ["deco_0.png", "deco_1.png", "deco_2.png", "deco_3.png"],
		"ice": [],
		"deep_snow": [],
		"trampoline": [],
		"smooth": true,
		"portal_primary": Color(0.53, 0.90, 0.57, 0.95),
		"portal_secondary": Color(0.96, 0.80, 0.38, 0.88),
		"portal_glow": Color(0.30, 0.68, 0.42, 0.10),
	},
	"neon": {
		"dir": "res://assets/tilesets/neon",
		"ground_top": ["ground_top_0.png", "ground_top_1.png", "ground_top_2.png"],
		"ground_bottom": ["fill_0.png", "fill_1.png", "fill_2.png"],
		"platform": ["platform_0.png", "platform_1.png", "platform_2.png"],
		"destructible": ["destructible_0.png", "destructible_1.png"],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": ["deco_0.png", "deco_1.png", "deco_2.png", "deco_3.png"],
		"ice": [],
		"deep_snow": [],
		"trampoline": [],
		"smooth": true,
		"portal_primary": Color(0.72, 0.31, 1.0, 0.97),
		"portal_secondary": Color(0.25, 0.94, 1.0, 0.92),
		"portal_glow": Color(0.24, 0.78, 1.0, 0.12),
	},
	"wool": {
		"dir": "res://assets/tilesets/wool",
		"ground_top": ["ground_top_0.png", "ground_top_1.png", "ground_top_2.png"],
		"ground_bottom": ["fill_0.png", "fill_1.png", "fill_2.png"],
		"platform": ["platform_0.png", "platform_1.png", "platform_2.png"],
		"destructible": ["destructible_0.png", "destructible_1.png"],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": ["deco_0.png", "deco_1.png", "deco_2.png", "deco_3.png"],
		"ice": [],
		"deep_snow": [],
		"trampoline": ["trampoline_0.png", "trampoline_1.png"],
		"smooth": true,
		"portal_primary": Color(0.98, 0.55, 0.73, 0.95),
		"portal_secondary": Color(0.48, 0.94, 0.90, 0.88),
		"portal_glow": Color(0.95, 0.58, 0.77, 0.11),
	},
	"frost": {
		"dir": "res://assets/tilesets/frost",
		"ground_top": ["ground_top_0.png", "ground_top_1.png", "ground_top_2.png"],
		"ground_bottom": ["fill_0.png", "fill_1.png", "fill_2.png"],
		"platform": ["platform_0.png", "platform_1.png", "platform_2.png"],
		"destructible": ["destructible_0.png", "destructible_1.png"],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": ["deco_0.png", "deco_1.png", "deco_2.png", "deco_3.png"],
		"ice": ["ice_0.png", "ice_1.png"],
		"deep_snow": ["snow_0.png", "snow_1.png"],
		"trampoline": [],
		"smooth": true,
		"portal_primary": Color(0.42, 0.88, 1.0, 0.96),
		"portal_secondary": Color(0.86, 0.99, 1.0, 0.90),
		"portal_glow": Color(0.43, 0.90, 1.0, 0.11),
	},
}

# Jede Map hat ein festes Tileset und ein festes Layout-Profil. Damit bleibt
# die Optik einer Map konsistent, statt zufällig Tilesets zu mischen.
const MAP_PROFILES: Dictionary = {
	"grasarena": {
		"archetype": "stepped",
		"theme": "storybook",
		"backdrop_variant": "forest",
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [36, 37, 38, 39],
		"weak_vine": [96, 97, 98, 99],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [33],
		"accent": Color(0.25, 0.95, 0.55, 1.0),
		"ice_patches": 0,
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
		"theme": "storybook",
		"backdrop_variant": "desert",
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
		"vines": true,
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
		"theme": "frost",
		"backdrop_variant": "cave",
		"ground_top": [80, 81, 82, 83, 100, 101, 102, 103],
		"ground_bottom": [53, 54, 55, 73, 74, 75],
		"platform": [53, 54, 55, 73, 74, 75, 113, 114, 115],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [153, 154, 155, 156],
		"ice": [33],
		"accent": Color(0.45, 0.85, 1.0, 1.0),
		"ice_patches": 5,
		"snow_patches": 4,
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
		"theme": "neon",
		"backdrop_variant": "foundry",
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
		"speed_boosters": 4,
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
	"weite": {
		# Bewusst reduzierte Arena: nur vier feste Plattformen, keine
		# Zufallsbalken und keine beweglichen Ketten.
		"archetype": "sparse",
		"theme": "storybook",
		"backdrop_variant": "meadow",
		"sparse_variant": 0,
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [36, 37, 38, 39],
		"weak_vine": [96, 97, 98, 99],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [33],
		"accent": Color(0.3, 0.92, 0.48, 1.0),
		"ice_patches": 0,
		"vines": true,
		"destructibles": 0,
		"random_platforms": 0,
		"seesaws": 0,
		"chains": 0,
		"barrels": 1,
		"tnt_barrels": 0,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.5,
		"powerups": 2,
	},
	"wolkeninsel": {
		# Zweite einfache Karte: wenige, weit auseinanderliegende Inseln.
		"archetype": "sparse",
		"theme": "wool",
		"backdrop_variant": "clouds",
		"sparse_variant": 1,
		"ground_top": [80, 81, 82, 83, 100, 101, 102, 103],
		"ground_bottom": [53, 54, 55, 73, 74, 75],
		"platform": [53, 54, 55, 73, 74, 75, 113, 114, 115],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [153, 154, 155, 156],
		"ice": [33],
		"accent": Color(0.55, 0.9, 1.0, 1.0),
		"ice_patches": 0,
		"trampolines": 4,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"seesaws": 0,
		"chains": 0,
		"barrels": 1,
		"tnt_barrels": 0,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.55,
		"powerups": 2,
	},
	"kistenfestung": {
		# Einzige Arena ohne feste Plattformen: Alles oberhalb des Bodens
		# besteht aus dynamischen Holzkisten. Die große Mittelwippe wird in
		# _spawn_crate_fortress() zusammen mit ihren Kistentürmen erzeugt.
		"archetype": "crate_fortress",
		"theme": "storybook",
		"backdrop_variant": "dusk",
		"crate_fortress": true,
		"ground_top": [120, 121, 122, 123, 140, 141, 142, 143],
		"ground_bottom": [120, 121, 122, 123, 140, 141, 142, 143],
		"platform": [40, 41, 42, 43, 60, 61, 62, 63],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [],
		"ice": [],
		"accent": Color(1.0, 0.62, 0.22, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"seesaws": 0,
		"chains": 0,
		"barrels": 0,
		"tnt_barrels": 0,
		"crate_stacks": 0,
		"crate_powerup_chance": 0.7,
		"powerups": 2,
	},
}

var current_map_id: String = "grasarena"
var current_theme_id: String = "storybook"
var current_theme: Dictionary = {}
var current_backdrop_variant: String = "forest"
var current_accent: Color = Color(1.0, 0.25, 0.65, 0.95)
var ground_top_textures: Array[Texture2D] = []
var ground_bottom_textures: Array[Texture2D] = []
var platform_textures: Array[Texture2D] = []
var destructible_textures: Array[Texture2D] = []
var strong_vine_textures: Array[Texture2D] = []
var weak_vine_textures: Array[Texture2D] = []
var decoration_textures: Array[Texture2D] = []
var ice_tex: Texture2D
var deep_snow_textures: Array[Texture2D] = []
var trampoline_textures: Array[Texture2D] = []
var current_smooth_tiles: bool = true

var p1_spawn_pos: Vector2 = Vector2.ZERO
var p2_spawn_pos: Vector2 = Vector2.ZERO

var _rng: RandomNumberGenerator
var _solid_cells: Dictionary = {}
var _special_cells: Dictionary = {}
var _object_cells: Dictionary = {}
var _ice_cells: Dictionary = {}
var _special_tiles: Dictionary = {} # tile_id (int) -> SpecialTile
var _tile_cache: Dictionary = {}
var _theme_texture_cache: Dictionary = {}
var _moving_objects: Array[Node] = []
var _moving_objects_by_id: Dictionary = {}
var _next_moving_object_id: int = 1
var _spawn_candidates: Array[Dictionary] = []
var _round_spawn_positions: Array[Vector2] = []
var _round_spawn_total: int = 0
var _crate_powerup_chance: float = 0.0
var _crate_drops_spawned: int = 0
var active_level_modifiers: Array[String] = []

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
	current_theme_id = str(profile.get("theme", ""))
	current_backdrop_variant = str(profile.get("backdrop_variant", ""))
	current_theme = TILESET_THEMES.get(current_theme_id, {})
	current_accent = profile.get("accent", Color(1.0, 0.25, 0.65, 0.95))

	if not current_theme.is_empty():
		# Theme-Assets sind 36-px-Vektorraster und ersetzen die alten
		# 18-px-Kacheln. Die Layout-Indizes in MAP_PROFILES bleiben als
		# Fallback erhalten, werden hier aber nicht mehr gelesen.
		current_smooth_tiles = bool(current_theme.get("smooth", true))
		ground_top_textures = _theme_textures("ground_top")
		ground_bottom_textures = _theme_textures("ground_bottom")
		platform_textures = _theme_textures("platform")
		destructible_textures = _theme_textures("destructible")
		strong_vine_textures = _theme_textures("strong_vine")
		weak_vine_textures = _theme_textures("weak_vine")
		decoration_textures = _theme_textures("decoration")
		var ice_textures := _theme_textures("ice")
		ice_tex = ice_textures[0] if not ice_textures.is_empty() else null
		deep_snow_textures = _theme_textures("deep_snow")
		trampoline_textures = _theme_textures("trampoline")
		return

	# Fallback für alte/klassische Profile.
	current_smooth_tiles = false
	ground_top_textures = _textures_for(profile.get("ground_top", []))
	ground_bottom_textures = _textures_for(profile.get("ground_bottom", []))
	platform_textures = _textures_for(profile.get("platform", []))
	destructible_textures = _textures_for(profile.get("destructible", []))
	strong_vine_textures = _textures_for(profile.get("strong_vine", []))
	weak_vine_textures = _textures_for(profile.get("weak_vine", []))
	decoration_textures = _textures_for(profile.get("decoration", []))
	var ice_indices: Array = profile.get("ice", [])
	ice_tex = _tile_texture(int(ice_indices[0])) if not ice_indices.is_empty() else null
	deep_snow_textures = []
	trampoline_textures = []

func _theme_textures(role: String) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var base_dir := str(current_theme.get("dir", ""))
	if base_dir.is_empty():
		return result
	for filename in current_theme.get(role, []):
		var path := "%s/%s" % [base_dir, str(filename)]
		if not _theme_texture_cache.has(path):
			_theme_texture_cache[path] = load(path) if ResourceLoader.exists(path) else null
		var tex := _theme_texture_cache[path] as Texture2D
		if tex != null:
			result.append(tex)
	return result

func generate_level(level_seed: int = 0, map_id: String = "", modifiers: Array[String] = []) -> void:
	active_level_modifiers = modifiers.duplicate()
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
	_spawn_candidates.clear()
	_round_spawn_positions.clear()
	_round_spawn_total = 0
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
	_build_theme_backdrop(level_seed)
	
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
		"sparse":
			_generate_sparse_arena(int(profile.get("sparse_variant", 0)))
		"crate_fortress":
			_generate_crate_fortress_arena()
		_:
			_generate_stepped_arena()
	
	# 3. Zusätzliche, gespiegelte Plattformen für mehr Varianz
	_add_random_platforms(int(profile.get("random_platforms", 3)))
	
	# 4. Spezial-Tiles: Eis, Ranken, zerstörbare Blöcke
	_place_ice_patches(int(profile.get("ice_patches", 0)))
	if bool(profile.get("vines", false)):
		_place_vine_bridges()
	_place_destructible_clusters(int(profile.get("destructibles", 3)))

	# 4b. Additive Theme-Mechanik. Sie verändert kein Layout, sondern legt
	#     nur Sensoren auf bereits vorhandene Standflächen.
	_place_theme_specials(profile)

	# 5. Bewegliche Map-Objekte (host-seitig simuliert, für Clients repliziert)
	_spawn_map_objects(profile)
	
	# 6. Kleine Deko auf Plattformen
	_place_decorations()
	
	# 7. Spawns aus allen freien Standflächen wählen. Das geschieht erst nach
	#    dem Platzieren von Kisten, Portalen, Federn, Stacheln und Powerups,
	#    damit keine Spawn-Fläche von einem Objekt belegt wird.
	var default_spawns := _build_round_spawn_positions(2)
	p1_spawn_pos = default_spawns[0]
	p2_spawn_pos = default_spawns[1]
	
	# 8. Boundary: Entweder Höhle (solide Felswände) oder elastische Gummiwand
	if active_level_modifiers.has("cave"):
		_build_cave_boundary()
	else:
		_build_rubber_boundary()

# Liefert die Spawnposition für einen Spieler-Slot. Alle Kandidaten werden aus
# freien Standflächen (Boden, Plattformen und ggf. Kistentürmen) gebildet und
# anschließend per Farthest-Point über das Level verteilt. So starten die
# Spieler möglichst weit voneinander entfernt, auf verschiedenen Höhen und
# nicht in Stacheln, Portalen, Kisten, Federn oder anderen Objekten.
func get_spawn_position(index: int, total: int) -> Vector2:
	var positions := _build_round_spawn_positions(maxi(1, total))
	var spawn_index := clampi(index - 1, 0, positions.size() - 1)
	return positions[spawn_index]

func _build_round_spawn_positions(total: int) -> Array[Vector2]:
	if _round_spawn_total == total and _round_spawn_positions.size() >= total:
		return _round_spawn_positions
	_round_spawn_total = total
	_round_spawn_positions.clear()
	_collect_spawn_candidates()

	if _spawn_candidates.is_empty():
		while _round_spawn_positions.size() < total:
			_round_spawn_positions.append(_fallback_spawn_position())
		return _round_spawn_positions

	var min_row: int = int(_spawn_candidates[0]["row"])
	var max_row: int = min_row
	for candidate in _spawn_candidates:
		min_row = mini(min_row, int(candidate["row"]))
		max_row = maxi(max_row, int(candidate["row"]))

	# Drei Höhenbänder: hoch, mittel, niedrig. Die Auswahl rotiert zwischen
	# ihnen (hoch -> niedrig -> mittel), damit nicht alle Spieler unten landen.
	var bands: Array = [[], [], []]
	for candidate in _spawn_candidates:
		bands[_spawn_band(int(candidate["row"]), min_row, max_row)].append(candidate)

	var band_use: Array[int] = [0, 0, 0]
	var center := Vector2(
		float(MAP_WIDTH) * TILE_SIZE * 0.5,
		float(MAP_HEIGHT) * TILE_SIZE * 0.5
	)

	while _round_spawn_positions.size() < total:
		var band := _next_spawn_band(bands, band_use)
		if band < 0:
			break
		var chosen_index := -1
		var best_score := -INF
		for i in range(bands[band].size()):
			var candidate: Dictionary = bands[band][i]
			var pos: Vector2 = candidate["pos"]
			var score := 0.0
			if _round_spawn_positions.is_empty():
				# Erster Spawn möglichst weit außen, damit die folgenden
				# Farthest-Point-Wahlen die gesamte Karte ausnutzen.
				score = pos.distance_to(center)
			else:
				var nearest := INF
				for selected in _round_spawn_positions:
					nearest = minf(nearest, pos.distance_to(selected))
				score = nearest
			# Symmetrische Kandidaten deterministisch auflösen, damit Host
			# und Client exakt dieselben Spawns erhalten.
			score += pos.x * 0.0001 + pos.y * 0.00001
			if score > best_score:
				best_score = score
				chosen_index = i
		if chosen_index < 0:
			bands[band].clear()
			continue
		var chosen: Dictionary = bands[band][chosen_index]
		bands[band].remove_at(chosen_index)
		band_use[band] += 1
		_round_spawn_positions.append(chosen["pos"])

	while _round_spawn_positions.size() < total:
		# Theoretisch könnte eine Karte weniger saubere Flächen besitzen.
		# Der Boden-Fallback ist immer frei von festen Hindernissen.
		_round_spawn_positions.append(_fallback_spawn_position())
	return _round_spawn_positions

func _collect_spawn_candidates() -> void:
	_spawn_candidates.clear()
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if not _is_spawn_surface_clear(cell):
			continue
		_spawn_candidates.append({
			"pos": _spawn_position_on_surface(cell.y, cell.x),
			"row": cell.y,
		})
	# Die Kistenfestung hat keine festen Plattformen. Dort kommen die
	# exponierten Oberseiten der Kistentürme als erhöhte Spawns hinzu.
	if bool(MAP_PROFILES.get(current_map_id, {}).get("crate_fortress", false)):
		_add_crate_spawn_candidates()
	_spawn_candidates.sort_custom(_sort_spawn_candidates)

func _is_spawn_surface_clear(cell: Vector2i) -> bool:
	if cell.x < SPAWN_EDGE_MARGIN or cell.x >= MAP_WIDTH - SPAWN_EDGE_MARGIN:
		return false
	if cell.y < 2 or cell.y >= MAP_HEIGHT - 1:
		return false
	if not _solid_cells.has(cell):
		return false
	if _solid_cells.has(Vector2i(cell.x, cell.y - 1)):
		return false
	if _object_cells.has(cell) or _special_cells.has(cell) or _ice_cells.has(cell):
		return false
	for dy in range(1, SPAWN_HEADROOM_ROWS + 1):
		var above := Vector2i(cell.x, cell.y - dy)
		if above.y < 0:
			return false
		if _solid_cells.has(above) or _object_cells.has(above) or _special_cells.has(above) or _ice_cells.has(above):
			return false
	return true

func _spawn_position_on_surface(surface_row: int, tile_x: int) -> Vector2:
	return Vector2(
		(float(tile_x) + 0.5) * TILE_SIZE,
		float(surface_row) * TILE_SIZE - SPAWN_BODY_OFFSET
	)

func _add_crate_spawn_candidates() -> void:
	var crates: Array[PhysicsCrate] = []
	for node in _moving_objects:
		if node is PhysicsCrate and is_instance_valid(node):
			crates.append(node)
	for crate in crates:
		if not _is_exposed_crate_top(crate, crates):
			continue
		var half := 18.0 * crate.crate_size
		var surface_y := crate.position.y - half
		var row := int(round(surface_y / TILE_SIZE))
		if row < 2 or row >= MAP_HEIGHT - 1:
			continue
		var tile_x := int(floor(crate.position.x / TILE_SIZE))
		if tile_x < SPAWN_EDGE_MARGIN or tile_x >= MAP_WIDTH - SPAWN_EDGE_MARGIN:
			continue
		var pos := Vector2(crate.position.x, surface_y - SPAWN_BODY_OFFSET)
		if not _is_crate_spawn_clear(pos, crate, crates):
			continue
		_spawn_candidates.append({"pos": pos, "row": row})

func _is_exposed_crate_top(crate: PhysicsCrate, crates: Array[PhysicsCrate]) -> bool:
	for other in crates:
		if other == crate or not is_instance_valid(other):
			continue
		if absf(other.position.x - crate.position.x) > 26.0:
			continue
		if other.position.y < crate.position.y - 6.0:
			return false
	return true

func _is_crate_spawn_clear(pos: Vector2, crate: PhysicsCrate, crates: Array[PhysicsCrate]) -> bool:
	for hazard in get_tree().get_nodes_in_group("hazard_spike"):
		if is_instance_valid(hazard) and hazard.position.distance_to(pos) < TILE_SIZE * 1.5:
			return false
	for other in crates:
		if other == crate or not is_instance_valid(other):
			continue
		if other.position.distance_to(pos) < 26.0:
			return false
	return true

func _spawn_band(row: int, min_row: int, max_row: int) -> int:
	if max_row <= min_row:
		return 1
	var t := float(row - min_row) / float(max_row - min_row)
	return clampi(int(floor(t * 3.0)), 0, 2)

func _next_spawn_band(bands: Array, band_use: Array[int]) -> int:
	var best_band := -1
	var best_count := 2147483647
	for band in [0, 2, 1]:
		if bands[band].is_empty():
			continue
		if band_use[band] < best_count:
			best_count = band_use[band]
			best_band = band
	return best_band

func _sort_spawn_candidates(a: Dictionary, b: Dictionary) -> bool:
	var row_a := int(a["row"])
	var row_b := int(b["row"])
	if row_a == row_b:
		return (a["pos"] as Vector2).x < (b["pos"] as Vector2).x
	return row_a < row_b

func _fallback_spawn_position() -> Vector2:
	var slot := _round_spawn_positions.size()
	var margin := 4.0
	var usable := float(MAP_WIDTH) - margin * 2.0
	var t := float(slot % 6) / 5.0
	var tile_x := int(round(margin + usable * t))
	return _spawn_position_on_surface(MAP_HEIGHT - 2, tile_x)

# Öffentliche Prüfung für Tests und Debug-Anzeigen. Gültig sind genau die
# Positionen, die aus den geprüften Spawn-Kandidaten stammen.
func is_spawn_position_clear(world_position: Vector2) -> bool:
	if _spawn_candidates.is_empty():
		_collect_spawn_candidates()
	for candidate in _spawn_candidates:
		if (candidate["pos"] as Vector2).distance_to(world_position) < 0.5:
			return true
	return false

func _generate_stepped_arena() -> void:
	# Schlanke, schwebende Balken statt Treppen. Zwischen den Ebenen bleiben
	# zwei freie Kacheln (72 px) Luft, damit die Charaktere darunter
	# durchlaufen und bequem auf die nächste Ebene springen können.
	_build_symmetric_platform_pair(7, 9, 19)
	_build_symmetric_platform_pair(10, 7, 16)
	_build_symmetric_platform_pair(7, 3, 13)
	_build_rect_solid(17, 26, 13, 13, platform_textures)
	_build_symmetric_platform_pair(11, 4, 10)

	# Herz-Blöcke schweben über der zentralen Wippe.
	_spawn_mystery_block(MAP_WIDTH / 2 - 2, 4)
	_spawn_mystery_block(MAP_WIDTH / 2 + 1, 4)

	# Federn auf den unteren Balken; die mittlere Feder katapultiert auf die
	# zentral aufgehängte Wippe.
	_spawn_jump_pad(9, 18)
	_spawn_jump_pad(34, 18)
	_spawn_jump_pad(21, 12)

	# Portale und Stacheln bleiben am Boden, aber außerhalb der Spawn-Ecken.
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_multitier_arena() -> void:
	# Mehrere luftige Etagen aus schmalen Balken. Die Ebenen liegen drei
	# Kacheln auseinander, sodass zwischen ihnen genug Kopfraum bleibt.
	_build_symmetric_platform_pair(6, 8, 19)
	_build_symmetric_platform_pair(8, 7, 16)
	_build_symmetric_platform_pair(5, 6, 13)
	_build_rect_solid(17, 26, 13, 13, ground_top_textures)
	_build_rect_solid(19, 24, 10, 10, platform_textures)

	_spawn_mystery_block(9, 8)
	_spawn_mystery_block(34, 8)

	_spawn_jump_pad(7, 18)
	_spawn_jump_pad(36, 18)
	_spawn_jump_pad(21, 12)
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_islands_arena() -> void:
	# Kleine, offene Inseln mit klaren Sprungwegen. Keine massiven Treppen-
	# blöcke, nur ein Kachel hohe Plattformen mit zwei Kacheln Luft dazwischen.
	_build_symmetric_platform_pair(7, 7, 19)
	_build_symmetric_platform_pair(10, 6, 16)
	_build_symmetric_platform_pair(5, 5, 13)
	_build_rect_solid(17, 26, 16, 16, platform_textures)
	_build_rect_solid(19, 24, 13, 13, platform_textures)

	_spawn_mystery_block(20, 11)
	_spawn_mystery_block(23, 11)

	_spawn_jump_pad(10, 18)
	_spawn_jump_pad(33, 18)
	_spawn_jump_pad(21, 15)
	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_sparse_arena(variant: int) -> void:
	# Bewusst offene Karten mit nur vier bis fünf Plattformen. Die wenigen
	# Landeplätze machen Bewegung und Positionierung wichtiger als Deckung.
	if variant == 1:
		_build_rect_solid(7, 13, 19, 19, platform_textures)
		_build_rect_solid(30, 36, 19, 19, platform_textures)
		_build_rect_solid(10, 15, 16, 16, platform_textures)
		_build_rect_solid(28, 33, 16, 16, platform_textures)
		_build_rect_solid(18, 25, 13, 13, platform_textures)
		_spawn_mystery_block(21, 10)
		_spawn_jump_pad(11, 18)
		_spawn_jump_pad(32, 18)
		_spawn_jump_pad(21, 12)
	else:
		_build_rect_solid(8, 15, 19, 19, platform_textures)
		_build_rect_solid(28, 35, 19, 19, platform_textures)
		_build_rect_solid(18, 25, 16, 16, platform_textures)
		_build_rect_solid(20, 23, 13, 13, platform_textures)
		_spawn_mystery_block(21, 10)
		_spawn_jump_pad(9, 18)
		_spawn_jump_pad(34, 18)
		_spawn_jump_pad(21, 15)

	_spawn_pipe_pair(2, MAP_HEIGHT - 3, MAP_WIDTH - 3, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2 - 1, MAP_HEIGHT - 3)
	_spawn_spike(MAP_WIDTH / 2, MAP_HEIGHT - 3)

func _generate_crate_fortress_arena() -> void:
	# Absichtlich leer: Der Boden wird zentral erzeugt, alle Aufbauten
	# bestehen aus Holzkisten und entstehen in _spawn_crate_fortress().
	pass

func _build_symmetric_platform_pair(x_start: int, width: int, y: int) -> void:
	# Spiegelt eine Plattform um die Kartenmitte. Beide Seiten erhalten exakt
	# dieselbe Breite und Höhe, damit keine Seite einen Sprungvorteil bekommt.
	_build_rect_solid(x_start, x_start + width - 1, y, y, platform_textures)
	var mirror_start := MAP_WIDTH - x_start - width
	if mirror_start > x_start + width - 1:
		_build_rect_solid(mirror_start, mirror_start + width - 1, y, y, platform_textures)

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
			var tex_width := maxf(1.0, float(sp.texture.get_width())) if sp.texture else 18.0
			sp.scale = Vector2.ONE * (TILE_SIZE / tex_width)
			if current_smooth_tiles:
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	patch.overlay_texture = ice_tex
	patch.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(patch)
	_ice_cells[cell] = true
	
	# Spiegelung für faire Verteilung auf beiden Kartenseiten.
	var mirror := Vector2i(MAP_WIDTH - 1 - cell.x, cell.y)
	if _can_place_ice(mirror):
		var patch2: IcePatch = ice_patch_scene.instantiate()
		patch2.overlay_texture = ice_tex
		patch2.position = Vector2((mirror.x + 0.5) * TILE_SIZE, (mirror.y + 0.5) * TILE_SIZE)
		add_child(patch2)
		_ice_cells[mirror] = true
	return true

func _place_vine_bridges() -> void:
	if strong_vine_textures.is_empty() or weak_vine_textures.is_empty():
		return
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
	if desired_clusters <= 0 or destructible_textures.is_empty():
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

# --- Additive Theme-Mechaniken ---------------------------------------------

func _place_theme_specials(profile: Dictionary) -> void:
	match current_theme_id:
		"neon":
			_place_speed_boosters(int(profile.get("speed_boosters", 3)))
		"wool":
			_place_trampoline_patches(int(profile.get("trampolines", 4)))
		"frost":
			_place_deep_snow_patches(int(profile.get("snow_patches", 4)))

func _place_deep_snow_patches(desired_patches: int) -> void:
	if desired_patches <= 0 or deep_snow_textures.is_empty():
		return
	var top_cells := _collect_overlay_candidates()
	if top_cells.is_empty():
		return
	var patches := 0
	var attempts := 0
	while patches < desired_patches and attempts < 36:
		attempts += 1
		var start: Vector2i = top_cells[_rng.randi() % top_cells.size()]
		var run_len := 2 + _rng.randi() % 3
		var placed_any := false
		for i in range(run_len):
			if _spawn_deep_snow(Vector2i(start.x + i, start.y)):
				placed_any = true
		if placed_any:
			patches += 1

func _spawn_deep_snow(cell: Vector2i) -> bool:
	if not _can_place_ice(cell):
		return false
	var snow: DeepSnow = deep_snow_scene.instantiate()
	snow.overlay_texture = _pick_overlay_texture(deep_snow_textures)
	snow.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(snow)
	_ice_cells[cell] = true
	var mirror := Vector2i(MAP_WIDTH - 1 - cell.x, cell.y)
	if _can_place_ice(mirror):
		var snow2: DeepSnow = deep_snow_scene.instantiate()
		snow2.overlay_texture = snow.overlay_texture
		snow2.position = Vector2((mirror.x + 0.5) * TILE_SIZE, (mirror.y + 0.5) * TILE_SIZE)
		add_child(snow2)
		_ice_cells[mirror] = true
	return true

func _place_trampoline_patches(desired_patches: int) -> void:
	if desired_patches <= 0 or trampoline_textures.is_empty():
		return
	var top_cells := _collect_overlay_candidates()
	if top_cells.is_empty():
		return
	var patches := 0
	var attempts := 0
	while patches < desired_patches and attempts < 36:
		attempts += 1
		var start: Vector2i = top_cells[_rng.randi() % top_cells.size()]
		var run_len := 2 + _rng.randi() % 2
		var placed_any := false
		for i in range(run_len):
			if _spawn_trampoline(Vector2i(start.x + i, start.y)):
				placed_any = true
		if placed_any:
			patches += 1

func _spawn_trampoline(cell: Vector2i) -> bool:
	if not _can_place_ice(cell):
		return false
	var trampoline: TrampolineGround = trampoline_ground_scene.instantiate()
	trampoline.overlay_texture = _pick_overlay_texture(trampoline_textures)
	trampoline.position = Vector2((cell.x + 0.5) * TILE_SIZE, (cell.y + 0.5) * TILE_SIZE)
	add_child(trampoline)
	_ice_cells[cell] = true
	var mirror := Vector2i(MAP_WIDTH - 1 - cell.x, cell.y)
	if _can_place_ice(mirror):
		var trampoline2: TrampolineGround = trampoline_ground_scene.instantiate()
		trampoline2.overlay_texture = trampoline.overlay_texture
		trampoline2.position = Vector2((mirror.x + 0.5) * TILE_SIZE, (mirror.y + 0.5) * TILE_SIZE)
		add_child(trampoline2)
		_ice_cells[mirror] = true
	return true

func _place_speed_boosters(desired_boosters: int) -> void:
	if desired_boosters <= 0:
		return
	var top_cells: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if _is_top_available(cell):
			top_cells.append(cell)
	if top_cells.is_empty():
		return
	var placed := 0
	var attempts := 0
	while placed < desired_boosters and attempts < 36:
		attempts += 1
		var cell: Vector2i = top_cells[_rng.randi() % top_cells.size()]
		if not _is_top_available(cell):
			continue
		if _spawn_speed_booster(cell):
			placed += 1
			var mirror := Vector2i(MAP_WIDTH - 1 - cell.x, cell.y)
			if _is_top_available(mirror) and _spawn_speed_booster(mirror):
				placed += 1

func _spawn_speed_booster(cell: Vector2i) -> bool:
	if not _is_top_available(cell):
		return false
	var booster: SpeedBooster = speed_booster_scene.instantiate()
	booster.direction = 1.0 if cell.x < int(MAP_WIDTH / 2) else -1.0
	booster.position = Vector2((cell.x + 0.5) * TILE_SIZE, float(cell.y) * TILE_SIZE)
	add_child(booster)
	_object_cells[cell] = true
	return true

func _collect_overlay_candidates() -> Array[Vector2i]:
	var top_cells: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if _can_place_ice(cell):
			top_cells.append(cell)
	return top_cells

func _pick_overlay_texture(textures: Array[Texture2D]) -> Texture2D:
	return textures[_rng.randi() % textures.size()]

func _build_theme_backdrop(level_seed: int) -> void:
	var backdrop = ThemeBackdropScript.new()
	backdrop.configure(
		current_theme_id,
		current_backdrop_variant,
		current_accent,
		Vector2(MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE),
		level_seed
	)
	add_child(backdrop)

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
		var deco_tex := decoration_textures[_rng.randi() % decoration_textures.size()]
		deco.texture = deco_tex
		var deco_width := maxf(1.0, float(deco_tex.get_width()))
		var deco_scale := TILE_SIZE / deco_width
		deco.scale = Vector2.ONE * deco_scale
		if current_smooth_tiles:
			deco.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		deco.position = Vector2(
			(deco_cell.x + 0.5) * TILE_SIZE,
			deco_cell.y * TILE_SIZE - float(deco_tex.get_height()) * deco_scale * 0.5
		)
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

func _build_cave_boundary() -> void:
	var w := float(MAP_WIDTH * TILE_SIZE)
	var h := float(MAP_HEIGHT * TILE_SIZE)
	var thick := 48.0

	# Solide Felswände umgeben das Spielfeld komplett
	_create_solid_wall_rect(Rect2(-thick, -thick, thick, h + thick * 2.0))
	_create_solid_wall_rect(Rect2(w, -thick, thick, h + thick * 2.0))
	_create_solid_wall_rect(Rect2(-thick, -thick, w + thick * 2.0, thick))
	_create_solid_wall_rect(Rect2(-thick, h, w + thick * 2.0, thick))

	# Stein-Rahmen Visualisierung
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(w, 0),
		Vector2(w, h),
		Vector2(0, h),
		Vector2.ZERO,
	])
	var line := Line2D.new()
	line.points = points
	line.width = 8.0
	line.default_color = Color(0.6, 0.55, 0.5, 1.0)
	line.z_index = 2
	add_child(line)

func _create_solid_wall_rect(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 7
	body.add_to_group("solid")

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.get_center()
	body.add_child(col)
	add_child(body)

func find_random_platform_top() -> Vector2:
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y <= 4 or cell.y >= MAP_HEIGHT - 3:
			continue
		var above := Vector2i(cell.x, cell.y - 1)
		if not _solid_cells.has(above):
			candidates.append(cell)
	if candidates.is_empty():
		for raw_cell in _solid_cells.keys():
			var cell: Vector2i = raw_cell
			var above := Vector2i(cell.x, cell.y - 1)
			if not _solid_cells.has(above):
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2.INF
	var chosen := candidates[_rng.randi() % candidates.size()]
	return Vector2((float(chosen.x) + 0.5) * TILE_SIZE, float(chosen.y) * TILE_SIZE - 28.0)

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
	var portal_primary: Color = current_theme.get("portal_primary", Color(0.62, 0.32, 1.0, 0.95))
	var portal_secondary: Color = current_theme.get("portal_secondary", Color(0.25, 0.90, 1.0, 0.85))
	var portal_glow: Color = current_theme.get("portal_glow", Color(0.20, 0.75, 1.0, 0.09))
	for pipe in [pipe1, pipe2]:
		pipe.portal_primary = portal_primary
		pipe.portal_secondary = portal_secondary
		pipe.portal_glow = portal_glow
	
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
	if bool(profile.get("crate_fortress", false)):
		_spawn_crate_fortress()
	for _i in range(int(profile.get("seesaws", 0))):
		_try_spawn_seesaw()
	for i in range(int(profile.get("chains", 0))):
		_try_spawn_chain_platform(i)
	for _i in range(int(profile.get("barrels", 0))):
		_spawn_barrel(false)
	var tnt_count := int(profile.get("tnt_barrels", 0))
	if active_level_modifiers.has("tnt_depot"):
		tnt_count += 3
	for _i in range(tnt_count):
		_spawn_barrel(true)
	for _i in range(int(profile.get("crate_stacks", 0))):
		_spawn_crate_stack()
	for _i in range(int(profile.get("powerups", 0))):
		_spawn_random_powerup()
	if active_level_modifiers.has("ice_world"):
		for raw_cell in _solid_cells.keys():
			_spawn_ice_patch(raw_cell)

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

func _spawn_crate_fortress() -> void:
	# Die Kistenfestung kommt ohne feste Plattformen aus. Zwei große
	# Kistentürme bilden die Seiten, kleine Kistenstufen führen hinauf. In der
	# Mitte hängt eine besonders breite Wippe, die auf beiden Seiten mit
	# Kistentürmen beladen ist. Alle Teile sind normale, zerstörbare
	# PhysicsCrate-Objekte und damit host-seitig simuliert.
	var center_x := float(MAP_WIDTH) * 0.5 * TILE_SIZE
	var seesaw_row := 18
	var seesaw_y := float(seesaw_row) * TILE_SIZE
	var seesaw_width := 12

	var seesaw := seesaw_scene.instantiate()
	seesaw.set("plank_width", float(seesaw_width) * TILE_SIZE)
	seesaw.set("suspended", true)
	seesaw.set("chain_length", 3.0 * TILE_SIZE)
	seesaw.position = Vector2(center_x, seesaw_y)
	_register_moving_object(seesaw)
	add_child(seesaw)

	var center_tile := int(floor(center_x / TILE_SIZE))
	var seesaw_start := center_tile - int(seesaw_width / 2)
	for x in range(seesaw_start, seesaw_start + seesaw_width):
		_object_cells[Vector2i(x, seesaw_row - 1)] = true
		_object_cells[Vector2i(x, seesaw_row)] = true

	# Zwei fünflagige Kistentürme. Die oberste Lage liegt auf derselben Höhe
	# wie die Wippe, sodass Spieler von beiden Seiten auf die Planke springen.
	_spawn_crate_wall(12, 14, 5)
	_spawn_crate_wall(29, 31, 5)

	# Je eine niedrigere Kistenstufe davor: 72 px bis zur Stufe, 108 px von
	# dort auf den Turm. Beide Höhen sind für alle Helden sicher erreichbar.
	_spawn_crate_wall(9, 10, 2)
	_spawn_crate_wall(33, 34, 2)

	# Lose Kisten auf den Türmen können heruntergeschossen werden.
	var tower_top_y := float(MAP_HEIGHT - 2) * TILE_SIZE - 5.0 * TILE_SIZE
	_spawn_crate_at(Vector2((float(13) + 0.5) * TILE_SIZE, tower_top_y - 18.0))
	_spawn_crate_at(Vector2((float(30) + 0.5) * TILE_SIZE, tower_top_y - 18.0))

	# Beladung der großen Wippe: zwei Stapel pro Seite, jeweils zwei Kisten
	# hoch. Die Symmetrie hält die Wippe beim Start waagerecht.
	var stack_base_y := seesaw_y - 7.0 - 18.0 - 1.0
	for side in [-1.0, 1.0]:
		var side_sign := float(side)
		for offset_tiles in [3, 5]:
			var crate_x: float = center_x + side_sign * float(offset_tiles) * TILE_SIZE
			for layer in range(2):
				var crate_y := stack_base_y - float(layer) * (TILE_SIZE + 1.0)
				_spawn_crate_at(Vector2(crate_x, crate_y))

func _spawn_crate_wall(x_start: int, x_end: int, height: int) -> void:
	var ground_y := float(MAP_HEIGHT - 2) * TILE_SIZE
	for x in range(x_start, x_end + 1):
		for layer in range(height):
			var y := ground_y - 18.0 - float(layer) * TILE_SIZE
			_spawn_crate_at(Vector2((float(x) + 0.5) * TILE_SIZE, y))

func _spawn_crate_at(world_position: Vector2) -> void:
	var crate := crate_scene.instantiate()
	crate.set("crate_size", 1.0)
	crate.set("health", 2)
	crate.set("max_health", 2)
	crate.connect("crate_broken", Callable(self, "_on_crate_broken"))
	crate.position = world_position
	_register_moving_object(crate)
	add_child(crate)
	var cell := Vector2i(
		int(floor(world_position.x / TILE_SIZE)),
		int(floor(world_position.y / TILE_SIZE))
	)
	for dx in range(-1, 2):
		for dy in range(-1, 1):
			_object_cells[Vector2i(cell.x + dx, cell.y + dy)] = true

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
