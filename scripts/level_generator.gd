class_name LevelGenerator
extends Node2D

const TILE_SIZE: float = 36.0 # 18px * 2.0
# 44 x 25 statt der früheren 38 x 22: rund 32 % mehr Fläche. Die zusätzliche
# Breite und Höhe geben den neuen offenen Karten und der Kistenfestung mehr
# Raum, ohne die Sprungdistanzen der Helden zu verändern.
const MAP_WIDTH: int = 44
const MAP_HEIGHT: int = 25
# Tatsächliche Größe der aktuell erzeugten Karte. Standard-Arenen nutzen
# MAP_WIDTH x MAP_HEIGHT, Scroll-Levels ("width" im Profil) sind breiter.
# Statisch, damit Spieler, Modifier und Lava die Größe ohne Referenz auf den
# Generator abfragen können.
static var map_w: int = MAP_WIDTH
static var map_h: int = MAP_HEIGHT
const RUBBER_BAND: float = 320.0
# Abstand der Spawn-Mitte über der Standfläche. Der Player-Körper reicht etwa
# 12 px unter seinen Ursprung, sodass die Figur knapp über der Fläche startet
# und nicht mehrere Kacheln fällt.
const SPAWN_BODY_OFFSET: float = 14.0
const SPAWN_HEADROOM_ROWS: int = 2
const SPAWN_EDGE_MARGIN: int = 2
# Anteil des größtmöglichen Abstands, den ein zufällig gewählter Spawn
# mindestens erreichen muss (1.0 = immer der entfernteste Platz).
const SPAWN_SPREAD_KEEP: float = 0.7

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
# Globaler Faktor für alle Powerup-Spawns (Map-Profile, Kistendrops,
# Powerup-Regen). 0.7 = 30 % weniger Powerups als in den Profilwerten.
const POWERUP_SPAWN_MULT: float = 0.7
@export var deep_snow_scene: PackedScene = preload("res://scenes/level/deep_snow.tscn")
@export var trampoline_ground_scene: PackedScene = preload("res://scenes/level/trampoline_ground.tscn")
@export var speed_booster_scene: PackedScene = preload("res://scenes/level/speed_booster.tscn")
@export var moving_platform_scene: PackedScene = preload("res://scenes/level/moving_platform.tscn")

const ThemeBackdropScript = preload("res://scripts/level/theme_backdrop.gd")

const CRATE_SIZES: Array = [0.82, 1.0, 1.16]

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
	# Leiterplatte im Look des Hauptmenüs: dunkle Platine, leuchtende
	# Cyan-Leiterbahnen, pinke Akzente, Chips als zerstörbare Blöcke.
	"platine": {
		"dir": "res://assets/tilesets/platine",
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
		"portal_primary": Color(0.96, 0.36, 0.77, 0.96),
		"portal_secondary": Color(0.25, 0.91, 0.84, 0.92),
		"portal_glow": Color(0.25, 0.91, 0.84, 0.12),
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
	"uhrwerk": {
		"archetype": "layout",
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
		"accent": Color(1.0, 0.78, 0.25, 1.0),
		"ice_patches": 0,
		"speed_boosters": 2,
		"vines": false,
		"destructibles": 1,
		"random_platforms": 1,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"pilzpfad": {
		# Seitlich scrollend: 96 Kacheln breit, die Kamera folgt dem eigenen
		# Spieler. Keine Zufallsbalken, das Layout ist komplett gebaut.
		"archetype": "layout",
		"theme": "storybook",
		"backdrop_variant": "forest",
		"width": 96,
		"scrolling": true,
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [36, 37, 38, 39],
		"weak_vine": [96, 97, 98, 99],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [33],
		"accent": Color(0.95, 0.35, 0.3, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 3,
		"crate_powerup_chance": 0.6,
		"powerups": 4,
	},
	"gletscherpass": {
		"archetype": "layout",
		"theme": "frost",
		"backdrop_variant": "cave",
		"width": 88,
		"scrolling": true,
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
		"snow_patches": 4,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 3,
		"crate_powerup_chance": 0.6,
		"powerups": 4,
	},
	"hauptplatine": {
		# Arena auf einer Leiterplatte (Tileset "platine"). Ein Datenbus-
		# Shuttle pendelt unter dem oberen Mittelbalken, Chips dienen als
		# zerstörbare Deckung.
		"archetype": "layout",
		"theme": "platine",
		"backdrop_variant": "circuit",
		"ground_top": [113, 114, 115, 132, 133, 134],
		"ground_bottom": [132, 133, 134, 113, 114, 115],
		"platform": [111, 112, 113, 114, 115, 132, 133, 134],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [150, 151, 152, 157, 158, 159],
		"ice": [],
		"accent": Color(0.25, 0.91, 0.84, 1.0),
		"ice_patches": 0,
		"speed_boosters": 2,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"lavaturm": {
		# Vertikales Level: 61 Reihen hoch, die Kamera folgt dem eigenen
		# Spieler nach oben. Kurz nach dem Start steigt Lava aus der Tiefe und
		# hält erst unter der Gipfel-Arena an; im Sudden Death steigt sie
		# weiter. Gespawnt wird nur in der unteren Hälfte, jeder muss klettern.
		"archetype": "layout",
		"theme": "neon",
		"backdrop_variant": "foundry",
		"height": 61,
		"scrolling": true,
		"rising_lava": {"delay": 4.0, "speed": 20.0, "stop_row": 24},
		"spawn_min_row": 38,
		"ground_top": [113, 114, 115, 132, 133, 134],
		"ground_bottom": [132, 133, 134, 113, 114, 115],
		"platform": [111, 112, 113, 114, 115, 132, 133, 134],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [150, 151, 152, 157, 158, 159],
		"ice": [],
		"accent": Color(1.0, 0.45, 0.15, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.6,
		"powerups": 3,
	},
	"himmelsleiter": {
		# Zweites vertikales Level: ein Aufstieg durch die Wolken mit Feder,
		# Aufzug, Fähre und Wippe. Ein Portal führt vom Boden direkt zum
		# Gipfel. Ohne frühe Lava, Sudden Death wie gewohnt.
		"archetype": "layout",
		"theme": "wool",
		"backdrop_variant": "clouds",
		"height": 52,
		"scrolling": true,
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
		"trampolines": 2,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 0,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.55,
		"powerups": 3,
	},
	# --- Karten mit Einweg-Plattformen, Kistenketten, Pyramide und Haus ----
	"sonnentempel": {
		# Riesige, innen hohle Pyramide in der Mitte (unten offen, drei
		# Viertel der Kartenbreite), darüber eine Kistenkette.
		"archetype": "layout",
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
		"accent": Color(1.0, 0.80, 0.30, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"kettenwerk": {
		# Neon-Halle voller Kistenketten: Brücken zwischen Einweg-Stegen,
		# Ketten vom Rand zu den Plattformen und Kisten an der Decke.
		"archetype": "layout",
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
		"accent": Color(0.95, 0.35, 1.0, 1.0),
		"ice_patches": 0,
		"speed_boosters": 2,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 2,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"wollhaus": {
		# Stilisiertes Haus mit vier Räumen in der Mitte; Leisten und Luken
		# führen nach oben, über das Dach kommt man auf die andere Seite.
		"archetype": "layout",
		"theme": "wool",
		"backdrop_variant": "clouds",
		"ground_top": [80, 81, 82, 83, 100, 101, 102, 103],
		"ground_bottom": [53, 54, 55, 73, 74, 75],
		"platform": [53, 54, 55, 73, 74, 75, 113, 114, 115],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [153, 154, 155, 156],
		"ice": [33],
		"accent": Color(0.98, 0.55, 0.73, 1.0),
		"ice_patches": 0,
		"trampolines": 3,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 0,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.55,
		"powerups": 2,
	},
	"eispyramiden": {
		# Zwei große hohle Eispyramiden über fast die ganze Breite, zwischen
		# ihren Spitzen hängt eine Kistenkette.
		"archetype": "layout",
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
		"ice_patches": 3,
		"snow_patches": 3,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"serverhaus": {
		# Rechenzentrum auf der Platine: Haus mit vier Räumen, Kistenketten
		# vom Kartenrand bis an die Hauswand und Kisten am Deckenkabel.
		"archetype": "layout",
		"theme": "platine",
		"backdrop_variant": "circuit",
		"ground_top": [113, 114, 115, 132, 133, 134],
		"ground_bottom": [132, 133, 134, 113, 114, 115],
		"platform": [111, 112, 113, 114, 115, 132, 133, 134],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [150, 151, 152, 157, 158, 159],
		"ice": [],
		"accent": Color(0.25, 0.91, 0.84, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"gitterzaun": {
		# Gitterzaun auf der Platine: fünf senkrechte und vier waagrechte
		# Ketten von der Decke bis zum Boden, große Kisten an jeder Kreuzung.
		# Außen führen Einweg-Stege nach oben.
		"archetype": "layout",
		"theme": "platine",
		"backdrop_variant": "circuit",
		"ground_top": [113, 114, 115, 132, 133, 134],
		"ground_bottom": [132, 133, 134, 113, 114, 115],
		"platform": [111, 112, 113, 114, 115, 132, 133, 134],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [150, 151, 152, 157, 158, 159],
		"ice": [],
		"accent": Color(0.35, 1.0, 0.75, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"truemmerfeld": {
		# Offenes Trümmerfeld in der Abenddämmerung: zerstörbare Mauerreste,
		# ein Torbogen in der Mitte, viele Fässer und Kistenstapel.
		"archetype": "layout",
		"theme": "storybook",
		"backdrop_variant": "dusk",
		"ground_top": [120, 121, 122, 123, 140, 141, 142, 143],
		"ground_bottom": [120, 121, 122, 123, 140, 141, 142, 143],
		"platform": [40, 41, 42, 43, 60, 61, 62, 63, 144, 145, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [],
		"accent": Color(1.0, 0.62, 0.35, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 3,
		"random_platforms": 0,
		"barrels": 3,
		"tnt_barrels": 2,
		"crate_stacks": 4,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"schrottplatz": {
		# Offener Neon-Schrottplatz: Haufen aus zerstörbaren Blöcken,
		# Kisten an Deckenketten, viel TNT.
		"archetype": "layout",
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
		"accent": Color(1.0, 0.85, 0.2, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 3,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 3,
		"crate_stacks": 3,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"schneefeld": {
		# Weites Schneefeld: Schneeburgen aus zerstörbaren Blöcken, tiefer
		# Schnee und Eis, kaum feste Plattformen.
		"archetype": "layout",
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
		"accent": Color(0.75, 0.92, 1.0, 1.0),
		"ice_patches": 2,
		"snow_patches": 4,
		"vines": false,
		"destructibles": 3,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 3,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"wollmarkt": {
		# Offener Wollmarkt: Marktstände mit Einweg-Dächern auf zerstörbaren
		# Pfosten, Trampoline und viele Kisten.
		"archetype": "layout",
		"theme": "wool",
		"backdrop_variant": "clouds",
		"ground_top": [80, 81, 82, 83, 100, 101, 102, 103],
		"ground_bottom": [53, 54, 55, 73, 74, 75],
		"platform": [53, 54, 55, 73, 74, 75, 113, 114, 115],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [153, 154, 155, 156],
		"ice": [33],
		"accent": Color(1.0, 0.72, 0.45, 1.0),
		"ice_patches": 0,
		"trampolines": 2,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 4,
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
	# --- Kugel-Maps: rollende Kugeln aus Gummi, Holz und Eisen ---------------
	"kugellawine": {
		# Kugeln unter der Decke hinter einer Kettensperre; nach dem Reißen
		# rollen sie über ein Satteldach durch die ganze Arena.
		"archetype": "layout",
		"theme": "storybook",
		"backdrop_variant": "dusk",
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [],
		"accent": Color(1.0, 0.55, 0.25, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"kugelbahn": {
		# Doppelte, gespiegelte Kugelbahn im Zickzack; oben spawnen alle 5 s
		# Kugeln und rollen bis auf den Boden.
		"archetype": "layout",
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
		"accent": Color(0.35, 0.85, 1.0, 1.0),
		"ice_patches": 0,
		"speed_boosters": 2,
		"vines": false,
		"destructibles": 0,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"kugelkette": {
		# Lange Kette unter der Decke, oben drauf viele Kugeln.
		"archetype": "layout",
		"theme": "storybook",
		"backdrop_variant": "forest",
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [],
		"accent": Color(0.55, 0.95, 0.45, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 2,
		"random_platforms": 0,
		"barrels": 2,
		"tnt_barrels": 1,
		"crate_stacks": 2,
		"crate_powerup_chance": 0.6,
		"powerups": 2,
	},
	"kugelmuehle": {
		# Zwei gegenläufige Windmühlen-Kreuze schleudern herabfallende Kugeln
		# zur Mitte.
		"archetype": "layout",
		"theme": "storybook",
		"backdrop_variant": "meadow",
		"ground_top": [0, 2, 3, 20, 21, 22, 23],
		"ground_bottom": [4, 5, 6, 24, 25, 26],
		"platform": [1, 24, 25, 26, 30, 40, 42, 130, 131, 146, 147],
		"destructible": [12, 13, 14, 15],
		"strong_vine": [],
		"weak_vine": [],
		"decoration": [124, 125, 126, 127, 128],
		"ice": [],
		"accent": Color(1.0, 0.82, 0.35, 1.0),
		"ice_patches": 0,
		"vines": false,
		"destructibles": 1,
		"random_platforms": 0,
		"barrels": 1,
		"tnt_barrels": 1,
		"crate_stacks": 1,
		"crate_powerup_chance": 0.6,
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
# Zellen von Einweg-Plattformen. Sie stehen zusätzlich in _solid_cells (als
# Standfläche), lassen aber Sprünge von unten, Federschächte und Bot-Routen
# hindurch.
var _oneway_cells: Dictionary = {}
# Freizuhaltende Bereiche: Flugbahnen über Sprungfedern sowie Schwenk- und
# Fahrbereiche von Wippen, Ketten- und Bewegungsplattformen. Zufällige
# Balken, Ranken und Blöcke dürfen dort nicht entstehen.
var _reserved_cells: Dictionary = {}
var _ground_gap_columns: Dictionary = {}
# Standflächen von Wippen und Kettenplattformen in Ruhelage. Sie sind keine
# festen Kacheln, die Bot-KI braucht sie aber als Kletterstufen.
var _bot_surfaces: Dictionary = {}
var _special_tiles: Dictionary = {} # tile_id (int) -> SpecialTile
var _tile_cache: Dictionary = {}
var _theme_texture_cache: Dictionary = {}
var _moving_objects: Array[Node] = []
var _moving_objects_by_id: Dictionary = {}
# Feste Objekte mit Zustand (Herz-Blöcke, Portale). Host und Client erzeugen
# sie aus demselben Seed in derselben Reihenfolge; der Index dient als ID.
var _mystery_blocks: Array[Node] = []
var _warp_pipes: Array[Node] = []
var _next_moving_object_id: int = 1
var _spawn_candidates: Array[Dictionary] = []
var _round_spawn_positions: Array[Vector2] = []
var _round_spawn_total: int = 0
# Eigener Seed für die Spawn-Auswahl, getrennt vom Karten-Zufall. Er stammt
# aus dem Runden-Seed, damit Host und Clients dieselben Spawns berechnen,
# jede Runde auf derselben Karte aber andere Startplätze bekommt.
var _spawn_seed: int = 0
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
	_oneway_cells.clear()
	_special_tiles.clear()
	_reserved_cells.clear()
	_ground_gap_columns.clear()
	_bot_surfaces.clear()
	_moving_objects.clear()
	_moving_objects_by_id.clear()
	_next_moving_object_id = 1
	_mystery_blocks.clear()
	_warp_pipes.clear()
	_spawn_candidates.clear()
	_round_spawn_positions.clear()
	_round_spawn_total = 0
	_spawn_seed = hash([level_seed, "spawns"]) if level_seed != 0 else randi()
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
	map_w = int(profile.get("width", MAP_WIDTH))
	map_h = int(profile.get("height", MAP_HEIGHT))
	_build_theme_backdrop(level_seed)
	
	# 1. Boden: obere Grasschicht + Erde. Keine Seiten- oder Deckenwände –
	#    außerhalb der Karte übernimmt die Gummiwand. Scroll-Levels schneiden
	#    Gruben in den Boden; wer hineinfällt, landet in der Gummiwand.
	var layout: Dictionary = LAYOUTS.get(str(profile.get("layout", current_map_id)), {})
	for gap in layout.get("ground_gaps", []):
		_cut_ground(int(gap[0]), int(gap[1]))
	var segment_start := -1
	for x in range(map_w + 1):
		var is_gap := x >= map_w or _ground_gap_columns.has(x)
		if not is_gap and segment_start < 0:
			segment_start = x
		elif is_gap and segment_start >= 0:
			_build_rect_solid(segment_start, x - 1, map_h - 2, map_h - 2, ground_top_textures)
			_build_rect_solid(segment_start, x - 1, map_h - 1, map_h - 1, ground_bottom_textures)
			segment_start = -1

	# 2. Fester Bauplan pro Map (siehe LAYOUTS). Die Kistenfestung baut ihre
	#    Aufbauten ausschließlich aus Kisten in _spawn_crate_fortress().
	if str(profile.get("archetype", "")) == "crate_fortress":
		_generate_crate_fortress_arena()
	else:
		_build_layout(layout)
	
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

func get_map_width() -> int:
	return map_w

func get_map_height() -> int:
	return map_h

func is_scrolling_map() -> bool:
	return bool(MAP_PROFILES.get(current_map_id, {}).get("scrolling", false))

## Steigende Lava vom Rundenbeginn an (vertikale Level). Leer, wenn die
## Karte nur die normale Sudden-Death-Lava hat. Schlüssel: delay (s nach
## dem Countdown), speed (px/s), stop_y (Pixel-Höhe, an der sie vor dem
## Sudden Death anhält).
func get_rising_lava() -> Dictionary:
	var cfg: Dictionary = MAP_PROFILES.get(current_map_id, {}).get("rising_lava", {})
	if cfg.is_empty():
		return {}
	return {
		"delay": float(cfg.get("delay", 4.0)),
		"speed": float(cfg.get("speed", 20.0)),
		"stop_y": float(cfg.get("stop_row", 0)) * TILE_SIZE,
	}

func get_map_pixel_size() -> Vector2:
	return Vector2(float(map_w) * TILE_SIZE, float(map_h) * TILE_SIZE)

# Liefert die Spawnposition für einen Spieler-Slot. Alle Kandidaten werden aus
# freien Standflächen (Boden, Plattformen und ggf. Kistentürmen) gebildet und
# anschließend über das Level verteilt: Der erste Platz ist zufällig, jeder
# weitere wird zufällig unter den Kandidaten mit großem Abstand zu den bisher
# gewählten gezogen. Der Zufall hängt am Runden-Seed, daher sehen Host und
# Clients dieselben Spawns, jede Runde aber andere. Gespawnt wird nie in
# Stacheln, Portalen, Kisten, Federn oder anderen Objekten.
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

	# Zufall pro Runde: Die Reihenfolge der Höhenbänder, der erste Spawn und
	# die Wahl unter den gut verteilten Kandidaten hängen vom Spawn-Seed ab.
	# Der Abstand zwischen den Spielern bleibt trotzdem groß, weil nur
	# Kandidaten mit mindestens SPAWN_SPREAD_KEEP des besten Abstands in
	# Frage kommen.
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = _spawn_seed + total * 7919
	var band_order: Array[int] = [0, 2, 1]
	_shuffle_ints(band_order, spawn_rng)
	var band_use: Array[int] = [0, 0, 0]

	while _round_spawn_positions.size() < total:
		var band := _next_spawn_band(bands, band_use, band_order)
		if band < 0:
			break
		var chosen_index := -1
		if _round_spawn_positions.is_empty():
			chosen_index = spawn_rng.randi_range(0, bands[band].size() - 1)
		else:
			var scores: Array[float] = []
			var best_score := 0.0
			for i in range(bands[band].size()):
				var pos: Vector2 = (bands[band][i] as Dictionary)["pos"]
				var nearest := INF
				for selected in _round_spawn_positions:
					nearest = minf(nearest, pos.distance_to(selected))
				scores.append(nearest)
				best_score = maxf(best_score, nearest)
			var pool: Array[int] = []
			for i in range(scores.size()):
				if scores[i] >= best_score * SPAWN_SPREAD_KEEP:
					pool.append(i)
			if not pool.is_empty():
				chosen_index = pool[spawn_rng.randi_range(0, pool.size() - 1)]
		if chosen_index < 0:
			bands[band].clear()
			continue
		var chosen: Dictionary = bands[band][chosen_index]
		bands[band].remove_at(chosen_index)
		band_use[band] += 1
		_round_spawn_positions.append(chosen["pos"])

	# Slots zufällig auf die Plätze verteilen, damit Spieler 1 nicht immer
	# das erste (z. B. hohe) Band bekommt.
	_shuffle_vectors(_round_spawn_positions, spawn_rng)

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
	if cell.x < SPAWN_EDGE_MARGIN or cell.x >= map_w - SPAWN_EDGE_MARGIN:
		return false
	if cell.y < 2 or cell.y >= map_h - 1:
		return false
	if cell.y < int(MAP_PROFILES.get(current_map_id, {}).get("spawn_min_row", 0)):
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
		if row < 2 or row >= map_h - 1:
			continue
		var tile_x := int(floor(crate.position.x / TILE_SIZE))
		if tile_x < SPAWN_EDGE_MARGIN or tile_x >= map_w - SPAWN_EDGE_MARGIN:
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

func _next_spawn_band(bands: Array, band_use: Array[int], band_order: Array[int]) -> int:
	var best_band := -1
	var best_count := 2147483647
	for band in band_order:
		if bands[band].is_empty():
			continue
		if band_use[band] < best_count:
			best_count = band_use[band]
			best_band = band
	return best_band

func _shuffle_ints(values: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp

func _shuffle_vectors(values: Array[Vector2], rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := values[i]
		values[i] = values[j]
		values[j] = tmp

func _sort_spawn_candidates(a: Dictionary, b: Dictionary) -> bool:
	var row_a := int(a["row"])
	var row_b := int(b["row"])
	if row_a == row_b:
		return (a["pos"] as Vector2).x < (b["pos"] as Vector2).x
	return row_a < row_b

func _fallback_spawn_position() -> Vector2:
	var slot := _round_spawn_positions.size()
	var margin := 4.0
	var usable := float(map_w) - margin * 2.0
	var t := float(slot % 6) / 5.0
	var tile_x := int(round(margin + usable * t))
	return _spawn_position_on_surface(map_h - 2, tile_x)

# Öffentliche Prüfung für Tests und Debug-Anzeigen. Gültig sind genau die
# Positionen, die aus den geprüften Spawn-Kandidaten stammen.
func is_spawn_position_clear(world_position: Vector2) -> bool:
	if _spawn_candidates.is_empty():
		_collect_spawn_candidates()
	for candidate in _spawn_candidates:
		if (candidate["pos"] as Vector2).distance_to(world_position) < 0.5:
			return true
	return false

# --- Feste Baupläne ---------------------------------------------------------
#
# Alle Arenen liegen auf einem Drei-Kachel-Raster: Bodenoberkante Reihe 23,
# Plattformebenen in den Reihen 20, 17, 14, 11, 8 und 5. Jede Ebene ist damit
# genau 108 px über der nächsten und für alle Helden ohne Doppelsprung
# erreichbar; dazwischen bleiben zwei freie Kacheln Kopfraum.
#
# Regeln für Baupläne (geprüft von tools/level_check.tscn):
#  - Eine höhere Plattform braucht darunter eine Fläche, die mindestens eine
#    Kachel seitlich übersteht, oder eine Lücke von 1-3 Kacheln daneben.
#  - Über Sprungfedern bleibt die ganze Flugbahn (8 Kacheln) frei.
#  - Wippen, Ketten- und Bewegungsplattformen haben einen freien Schwenk- bzw.
#    Fahrbereich; der wird reserviert, damit Zufallselemente ihn nicht füllen.
#
# Koordinaten sind Kachelspalten/-reihen. Bei "mirror": true wird alles an der
# Kartenmitte gespiegelt (Spalte x <-> map_w - 1 - x).
#  platforms: [x_start, x_end, reihe]            feste Balken
#  stairs:    [x_start, x_end, höhe_links, höhe_rechts]  Treppen aus Bodenkacheln
#  blocks:    [x_start, x_end, reihe]            zerstörbare Blöcke (Mario-Steine)
#  pads:      [x, reihe_über_fläche]             Sprungfedern
#  mystery:   [x, reihe]                         Herz-Blöcke
#  spikes:    [x, reihe]
#  pipes:     [x1, reihe1, x2, reihe2]            Portalpaar (nicht gespiegelt)
#  seesaws:   [mitte_x_kacheln, reihe, breite]    Wippen-Oberkante auf Reihe
#  chains:    [mitte_x_kacheln, anker_reihe, länge, breite]
#  movers:    [x_start, reihe, breite, dx, dy, periode_s, phase(, 1 = nicht spiegeln)]
#  rotators:  [mitte_x, mitte_y, arm, gegenarm, periode_s, phase(, balken, stil)]  Drehbalken
#             (Kacheln als Kommazahl). periode < 0 dreht gegen den Uhrzeigersinn, phase in
#             Umdrehungen (0 = nach rechts, 0.75 = nach oben), balken 2 = Kreuz, stil
#             "clock" = mit Zifferblatt. Die gespiegelte Kopie dreht andersherum.
#  ground_gaps: [x_start, x_end]                  Gruben im Boden
#  reserve:   [x_start, x_end, reihe_oben, reihe_unten]  frei halten (keine Kisten o. Ä.)
#  oneway:    [x_start, x_end, reihe]            Einweg-Plattformen (von unten durchspringbar,
#                                                mit der Runter-Taste durchfallen)
#  pyramids:  [mitte_x, unterkante_y, spitze_y, halbe_breite]  hohle Pyramide (Kacheln als
#             Kommazahl), Wände enden über dem Boden, damit man unten hineinkommt
#  houses:    [x_links, x_rechts, bodenreihe]    Haus mit vier Räumen (Außenwände x_links/x_rechts)
#  crate_chains: [ax, ay, bx, by, [kistengrößen](, durchhang)]  Kistenkette zwischen zwei
#             Ankern (Kachel-Koordinaten als Kommazahl, z. B. Plattformkante oder Kartenrand);
#             bx = -1: hängt frei von A herab, by ist dann die Länge in Kacheln
#  chain_grids: [[spalten_x], [reihen_y], kistengröße]  Kettengitter: senkrechte Ketten
#             von der Decke, waagrechte zwischen den äußeren Spalten, an jeder Kreuzung
#             eine Kiste (nicht gespiegelt, die Spalten liegen selbst symmetrisch)
const LAYOUTS: Dictionary = {
	"grasarena": {
		"mirror": true,
		"platforms": [[3, 10, 20], [8, 13, 17], [18, 25, 17], [3, 7, 14], [12, 16, 14],
			[2, 6, 8], [12, 16, 8]],
		"oneway": [[8, 12, 11]],
		"pads": [[18, 16]],
		"mystery": [[4, 4]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
		"seesaws": [[22.0, 8, 6]],
	},
	"wuestenruine": {
		"mirror": true,
		"platforms": [[4, 9, 20], [17, 26, 20], [3, 7, 14], [18, 25, 14],
			[9, 13, 11], [15, 19, 8]],
		"oneway": [[10, 13, 17]],
		"pads": [[15, 22]],
		"mystery": [[21, 4]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
		"chains": [[6.0, 1, 7, 4]],
	},
	"eisgrotte": {
		"mirror": true,
		"platforms": [[3, 8, 20], [13, 18, 20], [7, 11, 17], [3, 6, 14], [12, 16, 14],
			[12, 17, 8], [3, 5, 8]],
		"oneway": [[7, 11, 11]],
		"mystery": [[4, 4]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
		"seesaws": [[22.0, 14, 6]],
		"chains": [[22.0, 0, 6, 4]],
	},
	"neonfabrik": {
		"mirror": true,
		"platforms": [[5, 12, 20], [14, 18, 17], [3, 9, 14], [17, 26, 8],
			[3, 7, 5]],
		"oneway": [[10, 15, 11]],
		"pads": [[20, 22]],
		"mystery": [[5, 1]],
		"spikes": [[13, 22]],
		"pipes": [[1, 22, 42, 22]],
		"chains": [[13.0, 0, 6, 4]],
	},
	"weite": {
		"mirror": true,
		"platforms": [[8, 14, 20], [18, 25, 17]],
		"oneway": [[20, 23, 14]],
		"pads": [[9, 19]],
		"mystery": [[21, 10]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
	},
	"wolkeninsel": {
		"mirror": true,
		"platforms": [[6, 12, 20], [12, 16, 17], [19, 24, 14]],
		"oneway": [[13, 16, 11]],
		"pads": [[7, 19]],
		"mystery": [[21, 10]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
		# Wolkenfähre über der Mitte: pendelt zwischen den beiden oberen Inseln.
		"movers": [[14, 8, 4, 12, 0, 9.0, 0.0, 1]],
	},
	"uhrwerk": {
		# Die Mitte ist ein großes Zifferblatt: Der lange Minutenzeiger dreht
		# sich in 16 s einmal im Uhrzeigersinn, man fährt auf ihm mit (die
		# Spitze kommt unten bis auf Sprunghöhe über den Boden). Zwei Aufzüge
		# an den Seiten fahren vom Boden bis zur vierten Ebene. Aus zwei
		# Trichtern fallen alle 10 s Kugeln, die der Zeiger herumschiebt.
		"mirror": true,
		"platforms": [[2, 8, 20], [2, 7, 14], [5, 8, 8]],
		"mystery": [[6, 4]],
		"pipes": [[1, 22, 42, 22]],
		"movers": [
			[10, 20, 3, 0, -9, 8.0, 0.0],
		],
		"rotators": [[22.0, 13.0, 7.5, 1.5, 16.0, 0.75, 1, "clock"]],
		"ball_spawners": [[17.0, 1.6, 0.0, 10.0]],
	},
	"pilzpfad": {
		# Seitlich scrollendes Level im Stil klassischer Jump-'n'-Runs:
		# Gruben, Treppenpyramiden, Steinreihen mit Herz-Blöcken, eine Fähre
		# über der großen Grube und ein Aufzug am Ende. Portale verbinden den
		# ersten und den letzten Abschnitt.
		"mirror": false,
		"ground_gaps": [[14, 17], [30, 33], [54, 60], [76, 79]],
		"platforms": [[4, 8, 20], [19, 23, 17], [48, 52, 17], [62, 66, 20], [67, 71, 17],
			[72, 75, 14], [89, 94, 11]],
		"oneway": [[9, 12, 17]],
		"stairs": [[26, 29, 1, 4], [34, 37, 4, 1], [90, 94, 1, 3]],
		"blocks": [[43, 44, 20], [46, 47, 20]],
		"mystery": [[6, 16], [21, 13], [45, 20], [73, 10], [91, 7]],
		"pipes": [[40, 22, 82, 22]],
		"spikes": [[24, 22], [65, 22]],
		# Zielplattform oben rechts bleibt frei von Kisten.
		"reserve": [[89, 94, 6, 10]],
		"movers": [
			[54, 20, 3, 4, 0, 5.0, 0.0],
			[86, 20, 3, 0, -9, 7.0, 0.25],
		],
	},
	"hauptplatine": {
		"mirror": true,
		"platforms": [[3, 9, 20], [17, 26, 17], [3, 7, 14], [12, 16, 14],
			[7, 11, 11], [16, 27, 8], [2, 6, 8]],
		"oneway": [[8, 13, 17]],
		"mystery": [[4, 4]],
		"spikes": [[21, 22]],
		"pipes": [[1, 22, 42, 22]],
		"movers": [[18, 11, 4, 4, 0, 6.0, 0.0, 1]],
	},
	"lavaturm": {
		# Turm mit 61 Reihen (Boden auf Reihe 59, Ebenen alle drei Reihen).
		# Unten Zickzack-Balken und eine Feder, in der Mitte Aufzüge an den
		# Außenwänden, darüber eine Wippe, ganz oben die Gipfel-Arena
		# (Reihen 23 bis 8), unter der die Lava anhält.
		"mirror": true,
		"platforms": [
			[4, 10, 56], [14, 29, 50], [4, 10, 47], [14, 29, 41],
			[5, 10, 38], [4, 9, 35], [12, 17, 32], [10, 16, 26],
			[3, 13, 23], [12, 17, 20], [17, 26, 17], [4, 9, 17], [7, 12, 14], [14, 19, 11],
			[8, 12, 8],
		],
		"oneway": [[9, 15, 53], [9, 15, 44]],
		"pads": [[2, 58]],
		"mystery": [[21, 46], [10, 4]],
		"spikes": [[18, 49]],
		"seesaws": [[22.0, 29, 6]],
		"movers": [
			[1, 47, 3, 0, -12, 8.0, 0.0],
		],
	},
	"himmelsleiter": {
		# 52 Reihen (Boden auf Reihe 50). Nicht gespiegelt: Der Weg windet
		# sich von links unten über Feder, Aufzug, Fähre und Wippe nach oben.
		"mirror": false,
		"platforms": [
			[12, 18, 47], [17, 23, 44], [23, 29, 41], [8, 13, 41], [39, 42, 35], [29, 34, 35],
			[8, 14, 32], [4, 9, 29], [25, 31, 20], [31, 37, 17],
			[14, 19, 11], [6, 12, 8], [22, 27, 8], [30, 35, 11], [38, 42, 8],
		],
		"oneway": [[11, 16, 26], [22, 28, 14]],
		"pads": [[6, 49]],
		"mystery": [[9, 4], [25, 4]],
		"spikes": [[20, 49]],
		"pipes": [[1, 49, 41, 7]],
		# Gipfel links unter dem Herz-Block bleibt frei von Kistenstapeln.
		"reserve": [[6, 12, 5, 7]],
		"seesaws": [[21.0, 23, 6]],
		"movers": [
			[36, 47, 3, 0, -12, 7.0, 0.0],
			[16, 32, 4, 8, 0, 7.0, 0.0],
		],
	},
	"gletscherpass": {
		# Zweites Scroll-Level: vereiste Gruben, Aufzüge im Abgrund, eine
		# hängende Wippe über der Höhle und eine Kettenplattform am Ende.
		"mirror": false,
		"ground_gaps": [[12, 15], [28, 35], [53, 57]],
		"platforms": [[3, 8, 20], [17, 21, 20], [22, 26, 17], [37, 41, 20], [42, 47, 17],
			[48, 52, 14], [62, 66, 17], [67, 70, 14], [82, 86, 20]],
		"oneway": [[8, 11, 17]],
		"stairs": [[58, 61, 1, 4]],
		"mystery": [[24, 13], [44, 13], [84, 16]],
		"pipes": [[1, 22, 86, 22]],
		"spikes": [[19, 22], [45, 22]],
		"seesaws": [[76.0, 17, 6]],
		"chains": [[73.0, 2, 9, 4]],
		"movers": [
			[29, 20, 3, 0, -6, 6.0, 0.0],
			[32, 17, 3, 0, 3, 6.0, 0.0],
			[53, 14, 3, 3, 0, 5.0, 0.5],
		],
	},
	"sonnentempel": {
		# Riesige hohle Pyramide (drei Viertel der Kartenbreite): außen
		# begehbare Schrägen, innen Einweg-Stege in drei Etagen bis unter die
		# Spitze. Über der Spitze hängt eine Kistenkette zwischen den oberen
		# Plattformen, an den Rändern führen Plattformen nach oben.
		"mirror": true,
		"platforms": [[1, 3, 20], [2, 5, 17], [1, 3, 14], [2, 5, 11], [8, 12, 9], [15, 18, 7]],
		"oneway": [[12, 17, 20], [17, 20, 17], [20, 23, 14]],
		"pyramids": [[22.0, 20.5, 9.5, 16.5]],
		"mystery": [[10, 5]],
		"pipes": [[1, 22, 42, 22]],
		"crate_chains": [
			[19.0, 7.2, 25.0, 7.2, [0.82], 1.03],
			[6.5, 0.0, -1, 4.0, [1.0]],
		],
	},
	"kettenwerk": {
		# Kettenbrücken zwischen Einweg-Stegen (unten und in der Mitte), eine
		# Kette vom Kartenrand zur Plattform und hängende Kisten.
		"mirror": true,
		"platforms": [[3, 8, 20], [9, 13, 17], [2, 6, 14], [7, 11, 11], [16, 20, 8]],
		"oneway": [[14, 18, 20], [12, 16, 14], [3, 6, 8]],
		"mystery": [[5, 4]],
		"pipes": [[1, 22, 42, 22]],
		"crate_chains": [
			[19.0, 20.2, 25.0, 20.2, [1.16]],
			[17.0, 14.2, 27.0, 14.2, [0.82, 0.82]],
			[0.0, 11.2, 7.0, 11.2, [0.82]],
			[13.5, 0.0, -1, 7.0, [1.0, 0.82]],
		],
	},
	"wollhaus": {
		# Haus mit vier Räumen: Türen unten, Fenster oben, Luken in der
		# Zwischendecke. Kistenkette vom Rand zur Plattform, Kisten an Fäden.
		"mirror": true,
		"houses": [[14, 29, 23]],
		"platforms": [[2, 6, 20], [7, 10, 17], [7, 10, 11]],
		"oneway": [[2, 6, 14], [2, 6, 8]],
		"mystery": [[4, 4]],
		"crate_chains": [
			[0.0, 17.2, 7.0, 17.2, [1.0]],
			[12.0, 0.0, -1, 5.0, [1.16]],
		],
	},
	"eispyramiden": {
		# Zwei große hohle Pyramiden, die zusammen fast die ganze Breite
		# einnehmen; zwischen ihren Spitzen hängt eine lange Kistenkette.
		# Innen je zwei Etagen Einweg-Stege, im Tal dazwischen ein Steg als
		# Aufstieg, darüber Plattformen bis unter die Decke.
		"mirror": true,
		"platforms": [[7, 9, 11], [2, 5, 8], [15, 18, 11], [19, 21, 8], [10, 13, 8], [16, 18, 5]],
		"oneway": [[6, 9, 20], [14, 17, 20], [21, 22, 20], [10, 13, 17]],
		"pyramids": [[11.5, 20.5, 14.0, 9.5]],
		"pipes": [[1, 22, 42, 22]],
		"crate_chains": [
			[12.5, 14.1, 31.5, 14.1, [0.82, 1.16, 0.82], 1.03],
			[22.0, 0.0, -1, 5.0, [1.0]],
		],
	},
	"serverhaus": {
		# Haus mit vier Räumen; tief gespannte Kistenketten vom Kartenrand bis
		# an die untere Leiste (unten durchlaufen oder draufspringen).
		"mirror": true,
		"houses": [[14, 29, 23]],
		"platforms": [[2, 6, 17], [2, 5, 11]],
		"oneway": [[6, 9, 14], [7, 10, 8]],
		"mystery": [[3, 7]],
		"crate_chains": [
			[0.0, 20.2, 11.0, 20.2, [0.82, 1.0], 1.02],
			[22.0, 0.0, -1, 5.0, [1.16, 0.82]],
		],
	},
	"gitterzaun": {
		# Kettengitter über die ganze Breite (nur Ketten und Kisten). Die
		# äußeren Einweg-Stege liegen auf Höhe der Kistenreihen.
		"mirror": true,
		"oneway": [[1, 4, 20], [1, 4, 17], [1, 4, 14], [1, 4, 11], [1, 4, 8]],
		"chain_grids": [[[7.333, 14.667, 22.0, 29.333, 36.667], [7.0, 10.5, 14.0, 17.5], 1.3]],
	},
	"truemmerfeld": {
		# Offen: zwei kurze Mauern, ein Torbogen in der Mitte, Zinnen und
		# Mauerreste aus zerstörbaren Blöcken.
		"mirror": true,
		"platforms": [[12, 16, 19], [3, 7, 16]],
		"oneway": [[19, 24, 16], [8, 11, 13], [15, 18, 10]],
		"blocks": [[12, 12, 18], [16, 16, 18], [7, 8, 22], [7, 8, 21], [17, 17, 22], [20, 20, 22], [20, 20, 21], [20, 23, 20], [3, 3, 15], [8, 8, 12]],
		"mystery": [[21, 12]],
		"pipes": [[1, 22, 42, 22]],
	},
	"schrottplatz": {
		# Offen: Schrotthaufen aus zerstörbaren Blöcken, Einweg-Stege und
		# Kisten an Ketten von der Decke.
		"mirror": true,
		"platforms": [[2, 5, 20], [2, 4, 14]],
		"oneway": [[6, 10, 18], [13, 17, 15], [19, 24, 12], [7, 10, 11]],
		"blocks": [[10, 13, 22], [11, 12, 21], [11, 11, 20], [17, 18, 22], [17, 17, 21], [14, 14, 14], [16, 16, 14]],
		"crate_chains": [
			[8.5, 0.0, -1, 6.0, [1.0, 0.82]],
			[22.0, 0.0, -1, 3.5, [1.16]],
		],
	},
	"schneefeld": {
		# Offen: Schneeburgen und ein Turm aus zerstörbaren Blöcken, eine
		# Brücke in der Mitte mit Zinnen.
		"mirror": true,
		"platforms": [[16, 21, 19], [4, 7, 15]],
		"oneway": [[9, 13, 18], [11, 14, 12], [18, 21, 15]],
		"blocks": [[5, 8, 22], [5, 5, 21], [8, 8, 21], [14, 15, 22], [14, 15, 21], [16, 16, 18], [21, 21, 18], [4, 4, 14], [7, 7, 14]],
		"pipes": [[1, 22, 42, 22]],
	},
	"wollmarkt": {
		# Offen: vier Marktstände (Einweg-Dach auf zerstörbaren Pfosten),
		# darüber lockere Einweg-Stege.
		"mirror": true,
		"platforms": [[2, 5, 17]],
		"oneway": [[5, 11, 20], [14, 19, 20], [8, 12, 15], [18, 25, 13], [3, 6, 14], [8, 11, 11]],
		"blocks": [[6, 6, 22], [6, 6, 21], [10, 10, 22], [10, 10, 21], [15, 15, 22], [15, 15, 21], [18, 18, 22], [18, 18, 21], [12, 12, 22]],
		"mystery": [[21, 7]],
	},
	"kugellawine": {
		# Zwei Schrägen unter der Decke, voll mit Kugeln aus Gummi, Holz und
		# Eisen. Eine Kettensperre an der Mitte hält sie, bis sie zerschossen
		# wird oder nach 7 s reißt; dann rollen die Kugeln in die Mittellücke,
		# über ein Satteldach nach außen und unten durch die Arena. Darunter
		# eine Höhle unter dem Dach mit einem Rührbalken: Er dreht sich so
		# tief, dass kleine Kugeln darunter durchrollen und große angeschoben
		# werden. Bordsteine am Rand halten Kugeln im Feld.
		"mirror": true,
		"ramps": [[4.0, 5.0, 20.0, 7.5, 0.75], [16.0, 14.0, 22.0, 11.0, 0.8]],
		"walls": [[0, 0, 22, 22]],
		"platforms": [[6, 10, 20], [11, 14, 17], [12, 15, 11]],
		"oneway": [[1, 3, 20], [1, 3, 17], [1, 3, 14], [1, 3, 11], [1, 3, 8], [7, 11, 14]],
		"rotators": [[22.0, 18.5, 3.0, 3.0, 9.0, 0.0]],
		"ball_rows": [[19.5, 7.43, 4.3, 5.05]],
		"ball_gates": [[19.75, 5.0, 2.45, 7.0]],
	},
	"kugelbahn": {
		# Doppelte Kugelbahn, an der Mitte gespiegelt: je vier Schrägen im
		# Zickzack, an den Wenden Prallwände. Oben an jeder Bahn spawnt alle
		# 5 s eine Kugel und rollt bis auf den Boden, dann über den Kartenrand
		# hinaus. In der Mitte führt eine Leiter aus Einweg-Stegen nach oben.
		"mirror": true,
		# Die Schrägen sind Einweg-Rampen: Spieler springen von unten durch
		# und fallen mit S/↓ hindurch, Kugeln rollen oben darauf.
		"ramps": [[1.0, 3.0, 16.5, 5.5, 0.6, 1], [19.0, 8.5, 3.5, 11.0, 0.6, 1],
			[1.0, 13.5, 16.5, 16.0, 0.6, 1], [19.0, 18.5, 3.5, 20.5, 0.6, 1]],
		"walls": [[19, 19, 4, 8], [0, 0, 10, 14], [19, 19, 14, 18]],
		"oneway": [[20, 23, 20], [20, 23, 17], [20, 23, 14], [20, 23, 11], [20, 23, 8], [20, 23, 5]],
		"ball_spawners": [[1.6, 1.8, 1.0, 5.0]],
	},
	"kugelkette": {
		# Eine lange Kette quer unter der Decke zwischen zwei Randleisten, oben
		# drauf liegen dicht an dicht Kugeln aller Größen. Sie rollen in die
		# Mitte und lassen die Kette durchhängen. Wird ein Glied zerschossen,
		# regnet alles in die offene Arena darunter.
		"mirror": true,
		"platforms": [[0, 2, 7], [4, 8, 20], [10, 14, 17], [4, 7, 14], [15, 18, 20]],
		"oneway": [[0, 2, 16], [0, 2, 13], [0, 2, 10], [19, 24, 18]],
		"ball_chains": [[3.0, 7.15, 41.0, 7.15, 1.0, 0.9, 0.15, 0.4]],
	},
	"kugelmuehle": {
		# Zwei Windmühlen-Kreuze drehen sich gegenläufig. Aus Trichtern
		# neben den Naben fallen alle 5 s Kugeln auf die Flügel; die heben
		# sie an und werfen sie zur Mitte. Dort führt eine Leiter aus
		# Einweg-Stegen nach oben, außen Treppen aus Stegen.
		"mirror": true,
		"platforms": [[2, 5, 20], [19, 21, 20], [6, 9, 8]],
		"oneway": [[1, 4, 17], [1, 4, 14], [1, 4, 11], [19, 21, 17], [19, 21, 14], [19, 21, 11], [13, 16, 8]],
		"rotators": [[12.5, 15.5, 4.5, 4.5, 6.0, 0.0, 2]],
		"ball_spawners": [[11.0, 1.6, 0.0, 5.0]],
	},
}

func _layout_mirror_x(x: int) -> int:
	return map_w - 1 - x

func _build_layout(layout: Dictionary) -> void:
	var mirror := bool(layout.get("mirror", false))
	# Gruben werden vor allem anderen aus dem Boden geschnitten.
	for gap in layout.get("ground_gaps", []):
		_cut_ground(int(gap[0]), int(gap[1]))
	for entry in layout.get("platforms", []):
		_build_layout_rect(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[2]), mirror, platform_textures)
	for entry in layout.get("oneway", []):
		_build_oneway_mirrored(int(entry[0]), int(entry[1]), int(entry[2]), mirror)
	for entry in layout.get("houses", []):
		var hx0 := int(entry[0])
		var hx1 := int(entry[1])
		_build_house(hx0, hx1, int(entry[2]))
		if mirror and _layout_mirror_x(hx1) > hx1:
			_build_house(_layout_mirror_x(hx1), _layout_mirror_x(hx0), int(entry[2]))
	for entry in layout.get("pyramids", []):
		_for_mirrored_center(float(entry[0]), mirror, func(cx: float) -> void:
			_build_pyramid(cx, float(entry[1]), float(entry[2]), float(entry[3])))
	for entry in layout.get("stairs", []):
		_build_stairs(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[3]), mirror)
	for entry in layout.get("blocks", []):
		for tx in range(int(entry[0]), int(entry[1]) + 1):
			_spawn_special_tile(tx, int(entry[2]), SpecialTile.Kind.DESTRUCTIBLE)
			var mx := _layout_mirror_x(tx)
			if mirror and mx != tx and not _special_cells.has(Vector2i(mx, int(entry[2]))):
				_spawn_special_tile(mx, int(entry[2]), SpecialTile.Kind.DESTRUCTIBLE)
	for entry in layout.get("mystery", []):
		_for_mirrored(int(entry[0]), mirror, func(x: int) -> void: _spawn_mystery_block(x, int(entry[1])))
	for entry in layout.get("pads", []):
		_for_mirrored(int(entry[0]), mirror, func(x: int) -> void: _spawn_jump_pad(x, int(entry[1])))
	for entry in layout.get("spikes", []):
		_for_mirrored(int(entry[0]), mirror, func(x: int) -> void: _spawn_spike(x, int(entry[1])))
	for entry in layout.get("reserve", []):
		_reserve_rect(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[3]))
		if mirror:
			_reserve_rect(_layout_mirror_x(int(entry[1])), _layout_mirror_x(int(entry[0])), int(entry[2]), int(entry[3]))
	for entry in layout.get("pipes", []):
		_spawn_pipe_pair(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[3]))
	for entry in layout.get("seesaws", []):
		_for_mirrored_center(float(entry[0]), mirror, func(cx: float) -> void:
			_spawn_seesaw_at(cx, int(entry[1]), int(entry[2])))
	for entry in layout.get("chains", []):
		_for_mirrored_center(float(entry[0]), mirror, func(cx: float) -> void:
			_spawn_chain_platform_at(cx, int(entry[1]), int(entry[2]), int(entry[3])))
	for entry in layout.get("chain_grids", []):
		_build_chain_grid(entry[0], entry[1], float(entry[2]))
	for entry in layout.get("crate_chains", []):
		_spawn_crate_chain_mirrored(entry, mirror)
	_build_ball_layout(layout, mirror)
	for entry in layout.get("movers", []):
		var x0 := int(entry[0])
		var width := int(entry[2])
		_spawn_moving_platform(x0, int(entry[1]), width, float(entry[3]), float(entry[4]), float(entry[5]), float(entry[6]))
		var single: bool = entry.size() > 7 and int(entry[7]) == 1
		if mirror and not single:
			var mx0 := map_w - x0 - width
			if mx0 != x0:
				_spawn_moving_platform(mx0, int(entry[1]), width, -float(entry[3]), float(entry[4]), float(entry[5]), float(entry[6]))
	for entry in layout.get("rotators", []):
		_spawn_rotator_mirrored(entry, mirror)

func _for_mirrored(x: int, mirror: bool, action: Callable) -> void:
	action.call(x)
	if mirror and _layout_mirror_x(x) != x:
		action.call(_layout_mirror_x(x))

func _for_mirrored_center(cx: float, mirror: bool, action: Callable) -> void:
	action.call(cx)
	var mirrored := float(map_w) - cx
	if mirror and absf(mirrored - cx) > 0.01:
		action.call(mirrored)

func _build_layout_rect(x_start: int, x_end: int, y_start: int, y_end: int, mirror: bool, textures: Array) -> void:
	_build_rect_solid(x_start, x_end, y_start, y_end, textures)
	if not mirror:
		return
	var mx_start := _layout_mirror_x(x_end)
	var mx_end := _layout_mirror_x(x_start)
	if mx_start > x_end:
		_build_rect_solid(mx_start, mx_end, y_start, y_end, textures)

# --- Einweg-Plattformen -----------------------------------------------------

# Dicke der Standfläche einer Einweg-Plattform. Sie liegt oben in der Kachel,
# damit die Oberkante mit festen Plattformen derselben Reihe fluchtet.
const ONE_WAY_THICKNESS: float = 12.0
const ONE_WAY_VISUAL_PX: float = 16.0

func _build_oneway_mirrored(x_start: int, x_end: int, row: int, mirror: bool) -> void:
	_build_oneway_platform(x_start, x_end, row)
	if not mirror:
		return
	var mx_start := _layout_mirror_x(x_end)
	var mx_end := _layout_mirror_x(x_start)
	if mx_start > x_end:
		_build_oneway_platform(mx_start, mx_end, row)

## Steg, durch den man von unten hindurchspringt und auf dem man von oben
## landet; mit der Runter-Taste fällt man hindurch (Player.drop_through).
## Projektile fliegen von unten ebenfalls hindurch. Die Zellen zählen als
## Standfläche (_solid_cells) und stehen zusätzlich in _oneway_cells.
func _build_oneway_platform(x_start: int, x_end: int, row: int) -> void:
	if platform_textures.is_empty():
		return
	var width_tiles := x_end - x_start + 1
	var body := StaticBody2D.new()
	body.add_to_group("solid")
	body.add_to_group("one_way_platform")
	body.collision_layer = 1
	body.collision_mask = 7
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width_tiles * TILE_SIZE, ONE_WAY_THICKNESS)
	col.shape = rect
	col.one_way_collision = true
	col.one_way_collision_margin = 6.0
	col.position = Vector2((x_start + width_tiles * 0.5) * TILE_SIZE, row * TILE_SIZE + ONE_WAY_THICKNESS * 0.5)
	body.add_child(col)
	var arrow_color := Color(current_accent.r, current_accent.g, current_accent.b, 0.6)
	for x in range(x_start, x_end + 1):
		# Nur der obere Streifen der Plattform-Kachel: ein dünner Steg.
		var tex := _pick_texture(platform_textures, x, row)
		var tex_w := maxf(1.0, float(tex.get_width()))
		var tile_scale := TILE_SIZE / tex_w
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.region_enabled = true
		sp.region_rect = Rect2(0.0, 0.0, tex_w, ONE_WAY_VISUAL_PX / tile_scale)
		sp.scale = Vector2.ONE * tile_scale
		if current_smooth_tiles:
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.position = Vector2((x + 0.5) * TILE_SIZE, row * TILE_SIZE + ONE_WAY_VISUAL_PX * 0.5)
		body.add_child(sp)
		# Kleiner Pfeil unter dem Steg: Hier kommt man von unten durch.
		var arrow := Polygon2D.new()
		var tip := Vector2((x + 0.5) * TILE_SIZE, row * TILE_SIZE + ONE_WAY_VISUAL_PX + 3.0)
		arrow.polygon = PackedVector2Array([tip, tip + Vector2(5.0, 6.0), tip + Vector2(-5.0, 6.0)])
		arrow.color = arrow_color
		body.add_child(arrow)
		_solid_cells[Vector2i(x, row)] = true
		_oneway_cells[Vector2i(x, row)] = true
	add_child(body)

# --- Pyramide und Haus --------------------------------------------------------

const PYRAMID_CAP_HALF: float = 1.0
const PYRAMID_WALL: float = 0.75
const HOUSE_EAVE: float = 0.5
const HOUSE_ROOF_RISE: float = 4.0

## Hohle Pyramide aus zwei schrägen Wänden und einer flachen Spitze
## (Kollisionspolygone). Die Schrägen sind flacher als 45 Grad und damit
## begehbar. Die Wände enden bei base_y über dem Boden: Unten ist die
## Pyramide offen, man läuft unter der Kante hinein. Koordinaten in Kacheln.
func _build_pyramid(cx: float, base_y: float, top_y: float, half_w: float) -> void:
	var run := maxf(0.5, half_w - PYRAMID_CAP_HALF)
	var rise := maxf(0.5, base_y - top_y)
	var theta := atan2(rise, run)
	var shift := PYRAMID_WALL / sin(theta)
	var inner_y := top_y + PYRAMID_WALL
	var outer_l := Vector2(cx - half_w, base_y)
	var outer_r := Vector2(cx + half_w, base_y)
	var top_l := Vector2(cx - PYRAMID_CAP_HALF, top_y)
	var top_r := Vector2(cx + PYRAMID_CAP_HALF, top_y)
	var inner_l := Vector2(cx - half_w + shift, base_y)
	var inner_r := Vector2(cx + half_w - shift, base_y)
	var inner_top_x := minf(cx - 0.1, cx - half_w + (base_y - inner_y) / tan(theta) + shift)
	var inner_tl := Vector2(inner_top_x, inner_y)
	var inner_tr := Vector2(2.0 * cx - inner_top_x, inner_y)
	var walls: Array = [
		[outer_l, top_l, inner_tl, inner_l],
		[top_l, top_r, inner_tr, inner_tl],
		[top_r, outer_r, inner_r, inner_tr],
	]
	_build_shape_solid(walls, [inner_l, inner_tl, inner_tr, inner_r], [outer_l, top_l, top_r, outer_r])

## Stilisiertes Haus mit vier Räumen (2 x 2) zwischen den Außenwänden x0 und
## x1 auf der Standfläche floor_row (Reihe f). Unten Türen (2 Reihen hoch),
## oben Fenster (3 Reihen), in der Zwischendecke über jedem unteren Raum eine
## Einweg-Luke über einer kleinen Plattform. Außen führen zwei Leisten zum
## Fenster und unter die Dachkante, das Satteldach ist begehbar.
##   f-15..f-12 Dach, f-11 Decke, f-10..f-7 obere Räume, f-6 Zwischendecke,
##   f-5..f-1 untere Räume.
func _build_house(x0: int, x1: int, floor_row: int) -> void:
	var f := floor_row
	# Wände mit Plattform-Textur und hellem Rahmen: Die Bodenfüllung ist auf
	# manchen Themes (Platine) kaum vom Hintergrund zu unterscheiden.
	var wall_tex: Array[Texture2D] = platform_textures if not platform_textures.is_empty() else ground_bottom_textures
	var back := Polygon2D.new()
	var back_l := float(x0 + 1) * TILE_SIZE
	var back_r := float(x1) * TILE_SIZE
	back.polygon = PackedVector2Array([
		Vector2(back_l, float(f - 10) * TILE_SIZE), Vector2(back_r, float(f - 10) * TILE_SIZE),
		Vector2(back_r, float(f) * TILE_SIZE), Vector2(back_l, float(f) * TILE_SIZE),
	])
	back.color = Color(0.0, 0.0, 0.0, 0.32)
	back.z_index = -1
	add_child(back)

	_build_rect_solid(x0, x1, f - 11, f - 11, platform_textures)
	for wx in [x0, x1]:
		_build_rect_solid(wx, wx, f - 10, f - 10, wall_tex)
		_build_rect_solid(wx, wx, f - 6, f - 3, wall_tex)
		_frame_rect(wx, wx, f - 10, f - 10)
		_frame_rect(wx, wx, f - 6, f - 3)
	var hatch_left := x0 + 2
	var hatch_right := x1 - 4
	_build_rect_solid(x0 + 1, hatch_left - 1, f - 6, f - 6, platform_textures)
	_build_oneway_platform(hatch_left, hatch_left + 2, f - 6)
	_build_rect_solid(hatch_left + 3, hatch_right - 1, f - 6, f - 6, platform_textures)
	_build_oneway_platform(hatch_right, hatch_right + 2, f - 6)
	_build_rect_solid(hatch_right + 3, x1 - 1, f - 6, f - 6, platform_textures)
	# Mittelwand (bei gerader Breite zwei Kacheln) mit Türen oben und unten.
	var w := x1 - x0 + 1
	var mid_end := x0 + int(w / 2)
	var mid_start := mid_end - 1 if w % 2 == 0 else mid_end
	_build_rect_solid(mid_start, mid_end, f - 10, f - 9, wall_tex)
	_build_rect_solid(mid_start, mid_end, f - 5, f - 3, wall_tex)
	_frame_rect(mid_start, mid_end, f - 10, f - 9)
	_frame_rect(mid_start, mid_end, f - 5, f - 3)
	# Kleine Plattformen direkt unter den Luken.
	_build_rect_solid(hatch_left, hatch_left + 2, f - 3, f - 3, platform_textures)
	_build_rect_solid(hatch_right, hatch_right + 2, f - 3, f - 3, platform_textures)
	# Außenleisten: zum Fenster (f-3) und unter die Dachkante (f-9).
	_build_rect_solid(x0 - 3, x0 - 1, f - 3, f - 3, platform_textures)
	_build_rect_solid(x1 + 1, x1 + 3, f - 3, f - 3, platform_textures)
	_build_rect_solid(x0 - 3, x0 - 2, f - 9, f - 9, platform_textures)
	_build_rect_solid(x1 + 2, x1 + 3, f - 9, f - 9, platform_textures)
	# Satteldach mit flachem First, steht eine Kachel über.
	var top := float(f - 11)
	var cx := float(x0 + x1 + 1) * 0.5
	# Die Traufe ist eine halbe Kachel dick, damit die Dachspitzen an den
	# Seiten keine dünnen Keile sind, in die Spieler hineinrutschen.
	var roof: Array = [
		Vector2(float(x0 - 1), top),
		Vector2(float(x0 - 1), top - HOUSE_EAVE),
		Vector2(cx - PYRAMID_CAP_HALF, top - HOUSE_ROOF_RISE),
		Vector2(cx + PYRAMID_CAP_HALF, top - HOUSE_ROOF_RISE),
		Vector2(float(x1 + 2), top - HOUSE_EAVE),
		Vector2(float(x1 + 2), top),
	]
	_build_shape_solid([roof], [], roof)
	# Die Decke liegt unter dem Dach: dort keine Spawns, Kisten oder Deko.
	for x in range(x0, x1 + 1):
		_object_cells[Vector2i(x, f - 11)] = true

## Heller Rahmen in der Akzentfarbe um einen Block aus Kacheln (Hauswände).
func _frame_rect(x0: int, x1: int, y0: int, y1: int) -> void:
	var inset := 1.5
	var l := float(x0) * TILE_SIZE + inset
	var r := float(x1 + 1) * TILE_SIZE - inset
	var t := float(y0) * TILE_SIZE + inset
	var b := float(y1 + 1) * TILE_SIZE - inset
	var shade := Polygon2D.new()
	shade.polygon = PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)])
	shade.color = Color(current_accent.r, current_accent.g, current_accent.b, 0.16)
	shade.z_index = 1
	add_child(shade)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)])
	edge.closed = true
	edge.width = 3.0
	edge.default_color = current_accent.lightened(0.15)
	edge.joint_mode = Line2D.LINE_JOINT_ROUND
	edge.z_index = 1
	add_child(edge)

## Fester Körper aus konvexen Polygonen (Kachel-Koordinaten) mit der
## Füll-Textur des Themes, einer hellen Kante entlang outline und optional
## einer abgedunkelten Innenfläche. Bedeckte Zellen werden für Spawns,
## Kisten, Deko und Zufallselemente gesperrt.
func _build_shape_solid(polys: Array, interior: Array, outline: Array) -> void:
	var textures: Array[Texture2D] = ground_bottom_textures if not ground_bottom_textures.is_empty() else platform_textures
	if textures.is_empty():
		return
	if not interior.is_empty():
		var shade := Polygon2D.new()
		shade.polygon = _tiles_to_px(interior)
		shade.color = Color(0.0, 0.0, 0.0, 0.38)
		shade.z_index = -1
		add_child(shade)
	var body := StaticBody2D.new()
	body.add_to_group("solid")
	body.collision_layer = 1
	body.collision_mask = 7
	var tex: Texture2D = textures[0]
	var tex_w := maxf(1.0, float(tex.get_width()))
	for raw_poly in polys:
		var pts := _tiles_to_px(raw_poly)
		var col := CollisionPolygon2D.new()
		col.polygon = pts
		body.add_child(col)
		var fill := Polygon2D.new()
		fill.polygon = pts
		fill.texture = tex
		fill.texture_scale = Vector2.ONE * (tex_w / TILE_SIZE)
		fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if current_smooth_tiles:
			fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		body.add_child(fill)
		_mark_shape_cells(raw_poly)
	if outline.size() >= 2:
		var edge := Line2D.new()
		edge.points = _tiles_to_px(outline)
		edge.width = 5.0
		edge.default_color = current_accent.lightened(0.15)
		edge.joint_mode = Line2D.LINE_JOINT_ROUND
		edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
		edge.end_cap_mode = Line2D.LINE_CAP_ROUND
		body.add_child(edge)
	add_child(body)

func _tiles_to_px(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append((p as Vector2) * TILE_SIZE)
	return result

func _mark_shape_cells(poly: Array) -> void:
	var packed := PackedVector2Array()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for raw in poly:
		var p: Vector2 = raw
		packed.append(p)
		min_x = minf(min_x, p.x)
		min_y = minf(min_y, p.y)
		max_x = maxf(max_x, p.x)
		max_y = maxf(max_y, p.y)
	var samples: Array[Vector2] = [Vector2(0.5, 0.5), Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]
	for x in range(int(floor(min_x)), int(ceil(max_x))):
		for y in range(int(floor(min_y)), int(ceil(max_y))):
			for sample in samples:
				if Geometry2D.is_point_in_polygon(Vector2(float(x), float(y)) + sample, packed):
					_object_cells[Vector2i(x, y)] = true
					_reserved_cells[Vector2i(x, y)] = true
					break

# --- Kistenketten -------------------------------------------------------------

# Anker sitzen 1,5 px vor der Plattformkante, damit das erste Glied nicht in
# der Plattform steckt und gegen sie drückt.
const CHAIN_ANCHOR_INSET: float = 1.5
const CHAIN_TINTS: Dictionary = {
	"neon": Color(0.80, 0.58, 1.0, 1.0),
	"platine": Color(0.45, 0.95, 0.88, 1.0),
	"frost": Color(0.78, 0.90, 1.0, 1.0),
	"wool": Color(0.94, 0.74, 0.82, 1.0),
}

func _spawn_crate_chain_mirrored(entry: Array, mirror: bool) -> void:
	var a := Vector2(float(entry[0]), float(entry[1]))
	var b := Vector2(float(entry[2]), float(entry[3]))
	var hanging := float(entry[2]) < 0.0
	var sizes: Array = entry[4] if entry.size() > 4 else []
	var slack := float(entry[5]) if entry.size() > 5 else 1.06
	_spawn_crate_chain(a, b, hanging, sizes, slack)
	if not mirror:
		return
	var ma := Vector2(float(map_w) - a.x, a.y)
	var mb := Vector2(float(map_w) - b.x, b.y)
	if hanging:
		if absf(ma.x - a.x) < 0.01:
			return
		mb = b
	elif (ma.is_equal_approx(b) and mb.is_equal_approx(a)) or (ma.is_equal_approx(a) and mb.is_equal_approx(b)):
		# Symmetrisch über die Kartenmitte gespannt: nur einmal bauen.
		return
	_spawn_crate_chain(ma, mb, hanging, sizes, slack)

## Baut eine Kistenkette (siehe CrateChain). a/b in Kacheln; bei hängenden
## Ketten ist b.y die Länge in Kacheln. Die Kisten sind normale PhysicsCrate-
## Objekte mit eigener Netzwerk-ID, die Glieder gehören zur Kette.
func _spawn_crate_chain(a_tiles: Vector2, b_tiles: Vector2, hanging: bool, sizes: Array, slack: float) -> void:
	var a_px := a_tiles * TILE_SIZE
	var b_px := b_tiles * TILE_SIZE
	var hang_px := 0.0
	if hanging:
		hang_px = b_tiles.y * TILE_SIZE
		a_px.y += CHAIN_ANCHOR_INSET
	else:
		var dir := (b_px - a_px).normalized()
		a_px += dir * CHAIN_ANCHOR_INSET
		b_px -= dir * CHAIN_ANCHOR_INSET
	var plan := CrateChain.plan(a_px, b_px, not hanging, hang_px, sizes, slack)
	var chain := CrateChain.new()
	chain.anchor_a = a_px
	chain.anchor_b = b_px
	chain.has_anchor_b = not hanging
	chain.elements = plan
	chain.tint = CHAIN_TINTS.get(current_theme_id, Color(0.66, 0.70, 0.76, 1.0))
	_register_moving_object(chain)
	for element in plan:
		if str(element["kind"]) != "crate":
			continue
		var p0: Vector2 = element["p0"]
		var p1: Vector2 = element["p1"]
		var crate := crate_scene.instantiate()
		crate.set("crate_size", float(element["size"]))
		crate.set("health", 2)
		crate.set("max_health", 2)
		# Kettenkisten zählen nicht für die Sudden-Death-Lavahöhe.
		crate.set_meta("chain_crate", true)
		crate.connect("crate_broken", Callable(self, "_on_crate_broken"))
		crate.position = (p0 + p1) * 0.5
		crate.rotation = (p1 - p0).angle()
		_register_moving_object(crate)
		add_child(crate)
		chain.crates.append(crate)
	add_child(chain)
	# Kettenverlauf und eine Kachel Luft darum freihalten.
	for element in plan:
		for raw_point in [element["p0"], element["p1"]]:
			var p: Vector2 = raw_point
			var cell := Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))
			_object_cells[cell] = true
			_reserve_rect(cell.x - 1, cell.x + 1, cell.y - 1, cell.y + 1)

# --- Kettenphysik -------------------------------------------------------------

var _rope_solver: ChainRopeSolver = null

## Gemeinsamer Ketten-Solver der aktuellen Karte (siehe ChainRopeSolver). Wird
## beim ersten Aufruf angelegt; generate_level entfernt ihn mit allen Kindern.
func get_rope_solver() -> ChainRopeSolver:
	if _rope_solver == null or not is_instance_valid(_rope_solver) or _rope_solver.is_queued_for_deletion() or _rope_solver.get_parent() != self:
		_rope_solver = ChainRopeSolver.new()
		_rope_solver.name = "ChainRopeSolver"
		_rope_solver.solid_check = Callable(self, "_rope_point_solid")
		add_child(_rope_solver)
	return _rope_solver

# Abgerissene Kettenteile landen auf festen Kacheln (nicht auf Einweg-Stegen).
func _rope_point_solid(p: Vector2) -> bool:
	var cell := Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))
	return _solid_cells.has(cell) and not _oneway_cells.has(cell)

# --- Kettengitter -------------------------------------------------------------

const GRID_CRATE_MASS: float = 0.7
const GRID_LINK_MASS: float = 0.35

## Kettengitter (Gitterzaun): An jeder Kreuzung aus Spalte und Reihe hängt
## eine große Kiste. Senkrechte Ketten laufen von der Decke zur obersten Kiste,
## von Kiste zu Kiste und von der untersten Kiste zum Boden, waagrechte
## verbinden die Kisten einer Reihe. Jedes
## Kettenstück ist eine eigene CrateChain, deren Enden an den Kisten hängen.
## Die Gitterkisten sind leichter als normale Kisten, damit die langen
## senkrechten Ketten nicht überdehnen.
func _build_chain_grid(cols: Array, rows: Array, crate_size: float) -> void:
	var half := PhysicsCrate.BASE_SIZE * crate_size * 0.5
	var crates := {}
	var centers := {}
	for ci in range(cols.size()):
		for ri in range(rows.size()):
			var crate := crate_scene.instantiate()
			crate.set("crate_size", crate_size)
			crate.set("health", 3)
			crate.set("max_health", 3)
			crate.set_meta("chain_crate", true)
			crate.connect("crate_broken", Callable(self, "_on_crate_broken"))
			var center := Vector2(float(cols[ci]), float(rows[ri])) * TILE_SIZE
			crate.position = center
			_register_moving_object(crate)
			add_child(crate)
			crate.set("mass", GRID_CRATE_MASS)
			crates[Vector2i(ci, ri)] = crate
			centers[Vector2i(ci, ri)] = center
			var cell := Vector2i(int(floor(float(cols[ci]))), int(floor(float(rows[ri]))))
			_object_cells[cell] = true
			_reserve_rect(cell.x - 1, cell.x + 1, cell.y - 1, cell.y + 1)
	for ci in range(cols.size()):
		var x := float(cols[ci]) * TILE_SIZE
		var top := Vector2i(ci, 0)
		_spawn_grid_segment(Vector2(x, CHAIN_ANCHOR_INSET), centers[top] - Vector2(0.0, half), null, crates[top])
		for ri in range(rows.size() - 1):
			var upper := Vector2i(ci, ri)
			var lower := Vector2i(ci, ri + 1)
			_spawn_grid_segment(centers[upper] + Vector2(0.0, half), centers[lower] - Vector2(0.0, half), crates[upper], crates[lower])
		# Unterste Kiste bis zum Boden: Das Gitter ist oben und unten verankert.
		var bottom := Vector2i(ci, rows.size() - 1)
		var ground_y := float(map_h - 2) * TILE_SIZE - CHAIN_ANCHOR_INSET
		_spawn_grid_segment(centers[bottom] + Vector2(0.0, half), Vector2(x, ground_y), crates[bottom], null)
	for ri in range(rows.size()):
		for ci in range(cols.size() - 1):
			var left := Vector2i(ci, ri)
			var right := Vector2i(ci + 1, ri)
			_spawn_grid_segment(centers[left] + Vector2(half, 0.0), centers[right] - Vector2(half, 0.0), crates[left], crates[right])

func _spawn_grid_segment(a_px: Vector2, b_px: Vector2, body_a: Node, body_b: Node) -> void:
	var plan := CrateChain.plan(a_px, b_px, true, 0.0, [], 1.0)
	var chain := CrateChain.new()
	chain.anchor_a = a_px
	chain.anchor_b = b_px
	chain.has_anchor_b = true
	chain.body_a = body_a as PhysicsBody2D
	chain.body_b = body_b as PhysicsBody2D
	chain.link_mass = GRID_LINK_MASS
	chain.elements = plan
	chain.tint = CHAIN_TINTS.get(current_theme_id, Color(0.66, 0.70, 0.76, 1.0))
	_register_moving_object(chain)
	add_child(chain)
	for element in plan:
		for raw_point in [element["p0"], element["p1"]]:
			var p: Vector2 = raw_point
			var cell := Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))
			_object_cells[cell] = true
			_reserve_rect(cell.x - 1, cell.x + 1, cell.y - 1, cell.y + 1)

# Treppe aus Bodenkacheln: Jede Spalte ist eine Kachel höher bzw. niedriger
# als die vorherige. Eine Kachel Stufenhöhe ist für alle Helden ein leichter
# Sprung; Mario-typische Pyramiden entstehen aus zwei gegenläufigen Treppen.
func _build_stairs(x_start: int, x_end: int, h_left: int, h_right: int, mirror: bool) -> void:
	var count := x_end - x_start + 1
	for i in range(count):
		var t := 0.0 if count <= 1 else float(i) / float(count - 1)
		var h := int(round(lerpf(float(h_left), float(h_right), t)))
		if h <= 0:
			continue
		var x := x_start + i
		var top := map_h - 2 - h
		_build_rect_solid(x, x, top, map_h - 3, ground_top_textures)
		if mirror and _layout_mirror_x(x) != x:
			_build_rect_solid(_layout_mirror_x(x), _layout_mirror_x(x), top, map_h - 3, ground_top_textures)

func _cut_ground(x_start: int, x_end: int) -> void:
	for x in range(x_start, x_end + 1):
		_ground_gap_columns[x] = true

func _reserve_rect(x_start: int, x_end: int, y_start: int, y_end: int) -> void:
	for x in range(x_start, x_end + 1):
		for y in range(y_start, y_end + 1):
			_reserved_cells[Vector2i(x, y)] = true

func _generate_crate_fortress_arena() -> void:
	# Absichtlich leer: Der Boden wird zentral erzeugt, alle Aufbauten
	# bestehen aus Holzkisten und entstehen in _spawn_crate_fortress().
	pass

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

const GRID_ROWS: Array[int] = [8, 11, 14, 17, 20]

func _add_random_platforms(count: int = 3) -> void:
	# Zusätzliche Balken liegen auf dem Drei-Kachel-Raster, halten zu allen
	# Nachbarn Abstand, lassen zwei Kacheln Kopfraum über und unter sich und
	# brauchen eine erreichbare Absprungstelle (siehe _has_jump_support).
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 64:
		attempts += 1
		var w := 3 + _rng.randi() % 3
		var y: int = GRID_ROWS[_rng.randi() % GRID_ROWS.size()]
		var half := int(map_w / 2)
		var x := 2 + _rng.randi() % maxi(1, half - w - 2)
		var x_end := x + w - 1
		if not _can_place_bridge(x, x_end, y):
			continue
		_build_rect_solid(x, x_end, y, y, platform_textures)
		var mirror_x := map_w - 1 - x_end
		if mirror_x > x_end + 1 and _can_place_bridge(mirror_x, mirror_x + w - 1, y):
			_build_rect_solid(mirror_x, mirror_x + w - 1, y, y, platform_textures)
		placed += 1

# Gemeinsame Regeln für zufällige Balken und Rankenbrücken.
func _can_place_bridge(x: int, x_end: int, y: int) -> bool:
	if x < 1 or x_end > map_w - 2:
		return false
	# Eine Kachel Abstand zu allem auf derselben Reihe, damit keine
	# bestehende Plattform verlängert oder eine Lücke geschlossen wird.
	if not _is_rect_free(x - 1, x_end + 1, y, y):
		return false
	if not _has_vertical_clearance(x - 1, x_end + 1, y, y, 2):
		return false
	# Die Absprungkante darunter darf nicht überdeckt werden: Wenn direkt
	# drei Reihen tiefer eine Plattform endet, muss ihr Ende frei bleiben.
	if _covers_platform_access(x, x_end, y):
		return false
	return _has_jump_support(x, x_end, y)

# Erreichbar ist ein Balken, wenn drei Reihen tiefer eine Fläche liegt, die
# seitlich übersteht (1-3 Kacheln neben dem Balken), oder wenn auf derselben
# Reihe 2-4 Kacheln entfernt eine Fläche liegt.
func _has_jump_support(x: int, x_end: int, y: int) -> bool:
	var below := y + 3
	for offset in [1, 2, 3]:
		for sx in [x - offset, x_end + offset]:
			if _is_surface_cell(Vector2i(sx, below)) and _column_free(sx, y, below - 1):
				return true
	# Seitlicher Sprung auf gleicher Höhe: Über der Lücke müssen drei Reihen
	# frei sein, sonst stößt man sich beim Sprung den Kopf.
	for offset in [2, 3, 4]:
		if _is_surface_cell(Vector2i(x - offset, y)) and _is_area_open(x - offset + 1, x - 1, y - 3, y - 1):
			return true
		if _is_surface_cell(Vector2i(x_end + offset, y)) and _is_area_open(x_end + 1, x_end + offset - 1, y - 3, y - 1):
			return true
	return false

func _is_area_open(x_start: int, x_end: int, y_start: int, y_end: int) -> bool:
	for x in range(x_start, x_end + 1):
		if not _column_free(x, y_start, y_end):
			return false
	return true

func _is_surface_cell(cell: Vector2i) -> bool:
	if not (_solid_cells.has(cell) or _special_cells.has(cell)):
		return false
	var above := Vector2i(cell.x, cell.y - 1)
	return not (_solid_cells.has(above) or _special_cells.has(above))

func _column_free(x: int, y_start: int, y_end: int) -> bool:
	for y in range(y_start, y_end + 1):
		var cell := Vector2i(x, y)
		if _solid_cells.has(cell) or _special_cells.has(cell) or _object_cells.has(cell):
			return false
	return true

# Prüft, ob ein neuer Balken in Reihe y die einzige freie Absprungkante einer
# tieferen Plattform (Reihe y + 3) zu einer höheren Plattform (Reihe y - 3)
# verdecken würde. Vereinfachung: Balken direkt über den Enden einer
# Plattform drei Reihen tiefer sind tabu.
func _covers_platform_access(x: int, x_end: int, y: int) -> bool:
	var below := y + 3
	for sx in range(x - 1, x_end + 2):
		var cell := Vector2i(sx, below)
		if not _is_surface_cell(cell):
			continue
		var left_end := not _is_surface_cell(Vector2i(sx - 1, below))
		var right_end := not _is_surface_cell(Vector2i(sx + 1, below))
		if left_end or right_end:
			return true
	return false

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
	if cell.x < 0 or cell.x >= map_w or cell.y < 0 or cell.y >= map_h:
		return false
	if not _solid_cells.has(cell) or _oneway_cells.has(cell):
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
	var mirror := Vector2i(map_w - 1 - cell.x, cell.y)
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
	_try_place_vine_bridge(SpecialTile.Kind.STRONG_VINE, 3, 5, true)
	_try_place_vine_bridge(SpecialTile.Kind.WEAK_VINE, 3, 5, true)
	_try_place_vine_bridge(SpecialTile.Kind.STRONG_VINE, 3, 4, false)

func _try_place_vine_bridge(kind: int, min_w: int, max_w: int, mirror: bool) -> void:
	# Ranken sind Brücken wie die Zufallsbalken und folgen denselben Regeln.
	var attempts := 0
	while attempts < 32:
		attempts += 1
		var w := min_w + _rng.randi() % (max_w - min_w + 1)
		var y: int = GRID_ROWS[_rng.randi() % GRID_ROWS.size()]
		var half := int(map_w / 2)
		var x := 2 + _rng.randi() % maxi(1, half - w - 2)
		var x_end := x + w - 1
		if not _can_place_bridge(x, x_end, y):
			continue
		for tx in range(x, x_end + 1):
			_spawn_special_tile(tx, y, kind)
		if mirror:
			var mx := map_w - 1 - x_end
			if mx > x_end + 1 and _can_place_bridge(mx, mx + w - 1, y):
				for tx in range(mx, mx + w):
					_spawn_special_tile(tx, y, kind)
		return

func _place_destructible_clusters(desired_clusters: int = 3) -> void:
	# Zerstörbare 2x2-Blöcke stehen als Deckung auf einer Standfläche. Über
	# ihnen bleiben drei Reihen frei, damit sie weder Durchgänge zu höheren
	# Ebenen versperren noch einen niedrigen Deckel bilden. Ihre Oberseite
	# liegt zwei Kacheln über der Fläche und ist damit leicht erreichbar.
	if desired_clusters <= 0 or destructible_textures.is_empty():
		return
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.x < 3 or cell.x > int(map_w / 2) - 3:
			continue
		if _can_place_cover(cell.x, cell.y):
			candidates.append(cell)
	candidates.sort()
	var placed := 0
	var attempts := 0
	while placed < desired_clusters and attempts < 30 and not candidates.is_empty():
		attempts += 1
		var cell: Vector2i = candidates[_rng.randi() % candidates.size()]
		if not _can_place_cover(cell.x, cell.y):
			continue
		_spawn_cover(cell.x, cell.y)
		var mx := map_w - 2 - cell.x
		if mx > cell.x + 2 and _can_place_cover(mx, cell.y):
			_spawn_cover(mx, cell.y)
		placed += 1

func _can_place_cover(x: int, surface_row: int) -> bool:
	for tx in [x, x + 1]:
		if not _is_surface_cell(Vector2i(tx, surface_row)):
			return false
		if _object_cells.has(Vector2i(tx, surface_row)) or _ice_cells.has(Vector2i(tx, surface_row)):
			return false
		# Deckung auf einem Einweg-Steg würde den Durchgang von unten sperren.
		if _oneway_cells.has(Vector2i(tx, surface_row)):
			return false
	# Nicht direkt an eine Plattformkante stellen, damit Spieler daneben
	# stehen und auf den Block springen können.
	if not _is_surface_cell(Vector2i(x - 1, surface_row)) or not _is_surface_cell(Vector2i(x + 2, surface_row)):
		return false
	if _is_near_spawn(x, surface_row):
		return false
	return _is_rect_free(x - 1, x + 2, surface_row - 5, surface_row - 1)

func _spawn_cover(x: int, surface_row: int) -> void:
	for tx in [x, x + 1]:
		for ty in [surface_row - 2, surface_row - 1]:
			_spawn_special_tile(tx, ty, SpecialTile.Kind.DESTRUCTIBLE)

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
	var mirror := Vector2i(map_w - 1 - cell.x, cell.y)
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
	var mirror := Vector2i(map_w - 1 - cell.x, cell.y)
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
			var mirror := Vector2i(map_w - 1 - cell.x, cell.y)
			if _is_top_available(mirror) and _spawn_speed_booster(mirror):
				placed += 1

func _spawn_speed_booster(cell: Vector2i) -> bool:
	if not _is_top_available(cell) or _oneway_cells.has(cell):
		return false
	var booster: SpeedBooster = speed_booster_scene.instantiate()
	booster.direction = 1.0 if cell.x < int(map_w / 2) else -1.0
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
		Vector2(map_w * TILE_SIZE, map_h * TILE_SIZE),
		level_seed
	)
	add_child(backdrop)

func _is_top_available(cell: Vector2i, check_spawn: bool = true) -> bool:
	if cell.x < 0 or cell.x >= map_w or cell.y <= 0 or cell.y >= map_h:
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
	var tile_id := ty * map_w + tx
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
	if x_start < 0 or x_end >= map_w or y_start < 0 or y_end >= map_h:
		return false
	for x in range(x_start, x_end + 1):
		for y in range(y_start, y_end + 1):
			var cell := Vector2i(x, y)
			if _solid_cells.has(cell) or _special_cells.has(cell) or _object_cells.has(cell) or _ice_cells.has(cell):
				return false
			if _reserved_cells.has(cell):
				return false
	return true

# Prüft, ob über und unter einem neuen Objekt genug Luft bleibt. Zwei freie
# Kacheln entsprechen 72 px und damit dem Mindestabstand der Plattformebenen.
func _has_vertical_clearance(x_start: int, x_end: int, y_start: int, y_end: int, free_rows: int = 2) -> bool:
	if y_start - free_rows < 0 or y_end + free_rows >= map_h:
		return false
	for check_y in range(y_start - free_rows, y_end + free_rows + 1):
		if check_y >= y_start and check_y <= y_end:
			continue
		for x in range(x_start, x_end + 1):
			var cell := Vector2i(x, check_y)
			if _solid_cells.has(cell) or _special_cells.has(cell) or _object_cells.has(cell) or _ice_cells.has(cell):
				return false
			if _reserved_cells.has(cell):
				return false
	return true

func _is_near_spawn(x: int, y: int) -> bool:
	# Die Spawns liegen unten links/rechts. Dort keine Spezial-Tiles platzieren.
	return y >= map_h - 6 and (x <= 7 or x >= map_w - 8)

func _build_rubber_boundary() -> void:
	var map_size := Vector2(map_w * TILE_SIZE, map_h * TILE_SIZE)
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
	
	# Stacheldraht auf dem Rand: zeigt, dass die Gummiwand Schaden macht.
	RubberWall.add_barbed_border(self, map_size)

func _build_cave_boundary() -> void:
	var w := float(map_w * TILE_SIZE)
	var h := float(map_h * TILE_SIZE)
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
	# Kartengrenze: Durchschlag-Projektile dürfen hier nicht hindurch.
	body.add_to_group("map_border")

	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.position = rect.get_center()
	body.add_child(col)
	add_child(body)

## Oberkante (Pixel-y) der höchsten Standfläche aus festen und speziellen
## Kacheln (Plattformen, Ranken, zerstörbare Blöcke). INF ohne Kacheln.
func get_highest_platform_top_y() -> float:
	var top_row := -1
	for cells in [_solid_cells, _special_cells]:
		for raw_cell in cells.keys():
			var cell: Vector2i = raw_cell
			if top_row < 0 or cell.y < top_row:
				top_row = cell.y
	if top_row < 0:
		return INF
	return float(top_row) * TILE_SIZE

func find_random_platform_top() -> Vector2:
	var candidates: Array[Vector2i] = []
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y <= 4 or cell.y >= map_h - 3:
			continue
		if _is_open_platform_top(cell):
			candidates.append(cell)
	if candidates.is_empty():
		for raw_cell in _solid_cells.keys():
			var cell: Vector2i = raw_cell
			if _is_open_platform_top(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return Vector2.INF
	var chosen := candidates[_rng.randi() % candidates.size()]
	return Vector2((float(chosen.x) + 0.5) * TILE_SIZE, float(chosen.y) * TILE_SIZE - 28.0)

# Oberseite mit zwei freien Reihen darüber. Zellen unter Formkörpern (Hausdach,
# Pyramide) sind Objektzellen und fallen damit heraus, ebenso die Hausdecke.
func _is_open_platform_top(cell: Vector2i) -> bool:
	if _object_cells.has(cell):
		return false
	for dy in range(1, 3):
		var above := Vector2i(cell.x, cell.y - dy)
		if _solid_cells.has(above) or _object_cells.has(above):
			return false
	return true

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

const JUMP_PAD_SHAFT_ROWS: int = 8

func _spawn_jump_pad(tx: int, ty: int) -> void:
	# Sicherheitsnetz: Eine Feder unter einer Plattform schleudert Spieler nur
	# gegen die Decke. Liegt in der Flugbahn (Spalte ±1, acht Reihen) etwas
	# Festes, wird die Feder nicht gesetzt.
	if not _is_jump_pad_shaft_clear(tx, ty):
		push_warning("Sprungfeder bei (%d, %d) ausgelassen: Flugbahn blockiert" % [tx, ty])
		return
	var pad = jump_pad_scene.instantiate()
	pad.scale = Vector2(2.0, 2.0)
	pad.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 1.0) * TILE_SIZE)
	add_child(pad)
	_object_cells[Vector2i(tx, ty)] = true
	# Flugbahn freihalten: Die Feder schleudert rund acht Kacheln hoch.
	_reserve_rect(tx - 1, tx + 1, maxi(0, ty - JUMP_PAD_SHAFT_ROWS), ty)

func _is_jump_pad_shaft_clear(tx: int, ty: int) -> bool:
	for x in range(tx - 1, tx + 2):
		for y in range(maxi(0, ty - JUMP_PAD_SHAFT_ROWS), ty):
			var cell := Vector2i(x, y)
			if _oneway_cells.has(cell):
				continue
			if _solid_cells.has(cell) or _special_cells.has(cell) or _object_cells.has(cell):
				return false
	return true

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
	
	var replica := Global.network_mode and not Global.is_local_host()
	pipe1.is_replica = replica
	pipe2.is_replica = replica
	add_child(pipe1)
	add_child(pipe2)
	_warp_pipes.append(pipe1)
	_warp_pipes.append(pipe2)
	_object_cells[Vector2i(tx1, ty1)] = true
	_object_cells[Vector2i(tx1, ty1 - 1)] = true
	_object_cells[Vector2i(tx2, ty2)] = true
	_object_cells[Vector2i(tx2, ty2 - 1)] = true

func _spawn_mystery_block(tx: int, ty: int) -> void:
	var mb = mystery_block_scene.instantiate()
	mb.scale = Vector2(2.0, 2.0)
	mb.position = Vector2((tx + 0.5) * TILE_SIZE, (ty + 0.5) * TILE_SIZE)
	add_child(mb)
	_mystery_blocks.append(mb)
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
	_crate_powerup_chance = float(profile.get("crate_powerup_chance", 0.0)) * POWERUP_SPAWN_MULT
	if bool(profile.get("crate_fortress", false)):
		_spawn_crate_fortress()
	for _i in range(int(profile.get("barrels", 0))):
		_spawn_barrel(false)
	var tnt_count := int(profile.get("tnt_barrels", 0))
	if active_level_modifiers.has("tnt_depot"):
		tnt_count += 3
	for _i in range(tnt_count):
		_spawn_barrel(true)
	for _i in range(int(profile.get("crate_stacks", 0))):
		_spawn_crate_stack()
	for _i in range(_scaled_powerup_count(int(profile.get("powerups", 0)))):
		_spawn_random_powerup()
	if active_level_modifiers.has("powerup_rain"):
		for _i in range(_scaled_powerup_count(4)):
			_spawn_random_powerup()
	if active_level_modifiers.has("ice_world"):
		for raw_cell in _solid_cells.keys():
			_spawn_ice_patch(raw_cell)

func _spawn_seesaw_at(center_x_tiles: float, top_row: int, width: int) -> void:
	# Die Wippe hängt sichtbar in der Luft. Ihre Oberkante liegt auf der
	# angegebenen Rasterreihe, damit sie wie eine normale Ebene erreichbar ist.
	# Der Kippbereich (max_angle) plus Kopfraum darüber wird reserviert.
	var seesaw := seesaw_scene.instantiate()
	seesaw.set("plank_width", float(width) * TILE_SIZE)
	seesaw.set("suspended", true)
	seesaw.set("chain_length", 3.0 * TILE_SIZE)
	seesaw.position = Vector2(center_x_tiles * TILE_SIZE, float(top_row) * TILE_SIZE + 7.0)
	_register_moving_object(seesaw)
	add_child(seesaw)
	var x_start := int(floor(center_x_tiles - float(width) * 0.5))
	var x_end := int(ceil(center_x_tiles + float(width) * 0.5)) - 1
	for x in range(x_start, x_end + 1):
		_object_cells[Vector2i(x, top_row - 1)] = true
		_object_cells[Vector2i(x, top_row)] = true
		_bot_surfaces[Vector2i(x, top_row)] = true
	_reserve_rect(x_start, x_end, top_row - 4, top_row + 1)

func _spawn_crate_fortress() -> void:
	# Die Kistenfestung kommt ohne feste Plattformen aus. Zwei große
	# Kistentürme bilden die Seiten, kleine Kistenstufen führen hinauf. In der
	# Mitte hängt eine besonders breite Wippe, die auf beiden Seiten mit
	# Kistentürmen beladen ist. Alle Teile sind normale, zerstörbare
	# PhysicsCrate-Objekte und damit host-seitig simuliert.
	var center_x := float(map_w) * 0.5 * TILE_SIZE
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
	var tower_top_y := float(map_h - 2) * TILE_SIZE - 5.0 * TILE_SIZE
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
	var ground_y := float(map_h - 2) * TILE_SIZE
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
	# Höchstens drei Kisten: Die oberste bleibt so von der Standfläche aus
	# erreichbar (drei Kistenhöhen entsprechen etwa einer Rasterstufe).
	var stack_height := 2 + _rng.randi() % 2
	if not _has_crate_headroom(cell, 5):
		# Enger Platz (gelockerte Suche): nur zwei Kisten, sonst stößt der
		# Stapel an die Ebene darüber.
		stack_height = mini(stack_height, 2)
	var center_x := (float(cell.x) + 0.5) * TILE_SIZE
	var cursor_y := float(cell.y) * TILE_SIZE - 2.0
	var used_cells: Array[Vector2i] = []
	var surface_y := cursor_y
	for index in range(stack_height):
		var size_factor: float = CRATE_SIZES[_rng.randi() % CRATE_SIZES.size()]
		var size_px := 36.0 * size_factor
		# Gesamthöhe auf etwa 104 px begrenzen, damit man oben draufkommt.
		if index > 0 and surface_y - (cursor_y - size_px) > 104.0:
			size_factor = CRATE_SIZES[0]
			size_px = 36.0 * size_factor
			if surface_y - (cursor_y - size_px) > 104.0:
				break
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
	# Erst mit großzügigem Abstand suchen, damit zwischen Kisten, Deckung und
	# Plattformkanten keine schmalen Löcher entstehen. Findet sich so kein
	# Platz (enge Karten), wird schrittweise gelockert, damit jede Map Kisten
	# bekommt.
	for strictness in [2, 1, 0]:
		var candidates := _crate_stack_candidates(strictness)
		if not candidates.is_empty():
			return candidates[_rng.randi() % candidates.size()]
	return Vector2i(-1, -1)

func _crate_stack_candidates(strictness: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	# Immer ±2 Kacheln Standfläche, damit an Plattformkanten keine Löcher
	# entstehen; gelockert wird nur der Kopfraum (5, 4, dann 3 Reihen).
	var side := 2
	var headroom := 3 + strictness
	for raw_cell in _solid_cells.keys():
		var cell: Vector2i = raw_cell
		if cell.y <= 5:
			continue
		if not _is_top_available(cell):
			continue
		if not _has_crate_headroom(cell, headroom):
			continue
		var roomy := true
		for dx in range(-side, side + 1):
			if dx != 0 and not _is_surface_cell(Vector2i(cell.x + dx, cell.y)):
				roomy = false
		if not roomy:
			continue
		if (not _has_crate_headroom(Vector2i(cell.x - 1, cell.y), 3) or not _has_crate_headroom(Vector2i(cell.x + 1, cell.y), 3)):
			continue
		candidates.append(cell)
	candidates.sort()
	return candidates

func _has_crate_headroom(cell: Vector2i, height: int) -> bool:
	for dy in range(1, height + 1):
		var above := Vector2i(cell.x, cell.y - dy)
		if above.y < 0:
			return false
		if _solid_cells.has(above) or _special_cells.has(above) or _object_cells.has(above) or _ice_cells.has(above):
			return false
		if _reserved_cells.has(above):
			return false
	return true

func _on_crate_broken(world_position, attacker) -> void:
	if _crate_drops_spawned >= 4:
		return
	if _rng.randf() > _crate_powerup_chance:
		return
	var kind := _random_powerup_kind()
	if kind.is_empty():
		return
	_crate_drops_spawned += 1
	call_deferred("_spawn_powerup_at", world_position, kind)

# Skaliert eine Profil-Anzahl mit POWERUP_SPAWN_MULT. Der Nachkommarest wird
# ausgewürfelt (2 × 0.7 = 1.4 → 1 oder 2), damit der Schnitt genau stimmt.
# Nutzt den Map-RNG, Host und Clients erzeugen also dieselbe Anzahl.
func _scaled_powerup_count(base_count: int) -> int:
	var scaled := float(base_count) * POWERUP_SPAWN_MULT
	var count := int(floor(scaled))
	if _rng.randf() < scaled - float(count):
		count += 1
	return count

func _spawn_random_powerup() -> void:
	# Alle Powerups in der Lobby aus: keine Spawns.
	if not Global.has_active_powerups():
		return
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

# Nur Powerups, die im Lobby-Reiter "Powerups" aktiv sind. Auto-Angriff
# braucht zusätzlich die Nahkampfwaffe. Leer = gar kein Powerup.
func _random_powerup_kind() -> String:
	var kinds: Array[String] = Global.get_active_powerup_kinds()
	if kinds.is_empty():
		return ""
	return kinds[_rng.randi() % kinds.size()]

func _spawn_chain_platform_at(center_x_tiles: float, anchor_row: int, length: int, width: int) -> void:
	# Die Plattform hängt an zwei Ketten unter dem Anker. Ihre Oberkante liegt
	# knapp über Reihe anchor_row + length + 1. Der Schwenkbereich (etwa ein
	# Drittel der Kettenlänge zu jeder Seite) wird reserviert.
	var chain := chain_platform_scene.instantiate()
	chain.set("platform_width", float(width) * TILE_SIZE)
	chain.set("chain_length", float(length) * TILE_SIZE)
	chain.position = Vector2(center_x_tiles * TILE_SIZE, (float(anchor_row) + 0.5) * TILE_SIZE)
	_register_moving_object(chain)
	add_child(chain)
	var platform_y: float = chain.position.y + float(length) * TILE_SIZE
	var platform_row := int(floor(platform_y / TILE_SIZE))
	var x_start := int(floor(center_x_tiles - float(width) * 0.5))
	var x_end := int(ceil(center_x_tiles + float(width) * 0.5)) - 1
	for x in range(x_start, x_end + 1):
		_object_cells[Vector2i(x, platform_row)] = true
		_bot_surfaces[Vector2i(x, platform_row)] = true
	var swing := int(ceil(float(length) * 0.35))
	_reserve_rect(x_start - swing, x_end + swing, anchor_row, platform_row + 1)

func _spawn_moving_platform(x_start: int, top_row: int, width: int, dx: float, dy: float, period: float, phase: float) -> void:
	# Fährt zwischen Start und Start + (dx, dy) Kacheln hin und her. Der Host
	# simuliert die Bahn, Clients erhalten Position und Phase per Snapshot.
	var mover := moving_platform_scene.instantiate()
	mover.set("platform_width", float(width) * TILE_SIZE)
	mover.set("travel", Vector2(dx, dy) * TILE_SIZE)
	mover.set("period", maxf(1.0, period))
	mover.set("phase", phase)
	mover.set("accent", current_accent)
	if not platform_textures.is_empty():
		mover.set("tile_texture", platform_textures[0])
	mover.set("smooth_tiles", current_smooth_tiles)
	mover.position = Vector2((float(x_start) + float(width) * 0.5) * TILE_SIZE, float(top_row) * TILE_SIZE + 9.0)
	_register_moving_object(mover)
	add_child(mover)
	var x_end := x_start + width - 1
	var min_x := mini(x_start, x_start + int(round(dx)))
	var max_x := maxi(x_end, x_end + int(round(dx)))
	var min_row := mini(top_row, top_row + int(round(dy)))
	var max_row := maxi(top_row, top_row + int(round(dy)))
	_reserve_rect(min_x, max_x, min_row - 3, max_row + 1)
	for x in range(min_x, max_x + 1):
		for y in range(min_row - 1, max_row + 1):
			_object_cells[Vector2i(x, y)] = true

# --- Drehbalken ---------------------------------------------------------------

func _spawn_rotator_mirrored(entry: Array, mirror: bool) -> void:
	var center := Vector2(float(entry[0]), float(entry[1]))
	var arm := float(entry[2])
	var tail := float(entry[3])
	var period := float(entry[4])
	var phase := float(entry[5])
	var spokes := int(entry[6]) if entry.size() > 6 else 1
	var style := str(entry[7]) if entry.size() > 7 else "bar"
	_spawn_rotator(center, arm, tail, period, phase, spokes, style)
	if mirror and absf(_mirror_point(center).x - center.x) > 0.01:
		# Spiegelbild: Winkel a -> PI - a, also umgekehrte Drehrichtung.
		_spawn_rotator(_mirror_point(center), arm, tail, -period, 0.5 - phase, spokes, style)

## Drehbalken um center (Kacheln). Der Host dreht ihn, Clients bekommen die
## Zeit per Snapshot. Der ganze Schwenkkreis plus Spielerhöhe wird
## reserviert, damit dort keine Kisten, Fässer, Deckung oder
## Zufallsplattformen entstehen, an denen Spieler eingeklemmt würden.
func _spawn_rotator(center: Vector2, arm: float, tail: float, period: float, phase: float, spokes: int, style: String) -> void:
	var rotor := RotatingPlatform.new()
	rotor.arm_length = arm * TILE_SIZE
	rotor.tail_length = tail * TILE_SIZE
	rotor.period = period
	rotor.phase = phase
	rotor.spokes = spokes
	rotor.style = style
	rotor.accent = current_accent
	if not platform_textures.is_empty():
		rotor.tile_texture = platform_textures[0]
	rotor.smooth_tiles = current_smooth_tiles
	rotor.position = center * TILE_SIZE
	_register_moving_object(rotor)
	add_child(rotor)
	var reach := rotor.get_sweep_radius() + RotatingPlatform.CLEARANCE
	var c := rotor.position
	for x in range(int(floor((c.x - reach) / TILE_SIZE)), int(floor((c.x + reach) / TILE_SIZE)) + 1):
		for y in range(int(floor((c.y - reach) / TILE_SIZE)), int(floor((c.y + reach) / TILE_SIZE)) + 1):
			var cell_rect := Rect2(float(x) * TILE_SIZE, float(y) * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			var nearest := Vector2(clampf(c.x, cell_rect.position.x, cell_rect.end.x), clampf(c.y, cell_rect.position.y, cell_rect.end.y))
			if nearest.distance_to(c) <= reach:
				_reserved_cells[Vector2i(x, y)] = true
				_object_cells[Vector2i(x, y)] = true

# --- Kletterhilfe für Bots ----------------------------------------------------

func _is_bot_surface(cell: Vector2i) -> bool:
	if not (_solid_cells.has(cell) or _bot_surfaces.has(cell)):
		return false
	return not _solid_cells.has(Vector2i(cell.x, cell.y - 1))

## Sucht für einen Bot (Fußpunkt in Weltkoordinaten) den nächsten Weg eine
## Ebene nach oben, z. B. um steigender Lava zu entkommen. Ergebnis:
## takeoff_x (hier abspringen), land_x/land_y (Ziel-Oberkante) und pad
## (true = einfach auf die Sprungfeder laufen). Leer, wenn es keinen Weg gibt.
func find_climb_route(feet: Vector2) -> Dictionary:
	var col := int(floor(feet.x / TILE_SIZE))
	var row := int(round(feet.y / TILE_SIZE))
	if not _is_bot_surface(Vector2i(col, row)):
		return {}
	# Begehbarer Abschnitt der aktuellen Ebene.
	var left := col
	while _is_bot_surface(Vector2i(left - 1, row)):
		left -= 1
	var right := col
	while _is_bot_surface(Vector2i(right + 1, row)):
		right += 1

	var best: Dictionary = {}
	var best_cost := INF
	# Sprungfedern auf dieser Ebene sind der schnellste Weg nach oben.
	for child in get_children():
		var pad_node := child as JumpPad
		if pad_node == null:
			continue
		var pad_col := int(floor(pad_node.global_position.x / TILE_SIZE))
		var pad_row := int(round(pad_node.global_position.y / TILE_SIZE))
		if pad_row != row or pad_col < left or pad_col > right:
			continue
		# Landeziel: höchste freie Standfläche seitlich neben der Flugbahn.
		var land := Vector2i(-1, -1)
		for y in range(row - JUMP_PAD_SHAFT_ROWS + 1, row - 1):
			for dx in range(2, 7):
				for side in [-1, 1]:
					var c := Vector2i(pad_col + dx * side, y)
					if land.x < 0 and _is_bot_surface(c) and not _solid_cells.has(Vector2i(c.x, c.y - 2)):
						land = c
		if land.x < 0:
			continue
		var cost := absf(float(pad_col - col)) - 3.0
		if cost < best_cost:
			best_cost = cost
			best = {"takeoff_x": pad_node.global_position.x, "land_x": (float(land.x) + 0.5) * TILE_SIZE,
				"land_y": float(land.y) * TILE_SIZE, "pad": true}

	var candidates: Array = _solid_cells.keys() + _bot_surfaces.keys()
	for raw in candidates:
		var cell: Vector2i = raw
		var rise := row - cell.y
		if rise < 2 or rise > 4 or not _is_bot_surface(cell):
			continue
		# Einweg-Steg: einfach direkt darunter hochspringen.
		if _oneway_cells.has(cell) and cell.x >= left and cell.x <= right:
			var shaft_clear := true
			for y in range(cell.y - 2, row):
				var shaft_cell := Vector2i(cell.x, y)
				if _solid_cells.has(shaft_cell) and not _oneway_cells.has(shaft_cell):
					shaft_clear = false
					break
			if shaft_clear:
				var direct_cost := absf(float(cell.x - col)) + absf(float(rise - 3)) * 2.0
				if direct_cost < best_cost:
					best_cost = direct_cost
					best = {"takeoff_x": (float(cell.x) + 0.5) * TILE_SIZE, "land_x": (float(cell.x) + 0.5) * TILE_SIZE,
						"land_y": float(cell.y) * TILE_SIZE, "pad": false}
		for dir in [-1, 1]:
			# Nur Plattform-Enden: daneben ist frei, dort kann man vorbeispringen.
			if _is_bot_surface(Vector2i(cell.x + dir, cell.y)) or _solid_cells.has(Vector2i(cell.x + dir, cell.y)):
				continue
			var approach: int = cell.x + dir
			# Bis zu drei Kacheln Lücke sind laut Bauplan-Regeln springbar.
			for offset in range(0, 4):
				var takeoff: int = approach + dir * offset
				if takeoff < left or takeoff > right:
					continue
				var clear := true
				for y in range(cell.y - 2, row):
					var probe := Vector2i(takeoff, y)
					if _solid_cells.has(probe) and not _oneway_cells.has(probe):
						clear = false
						break
				if not clear:
					continue
				var cost := absf(float(takeoff - col)) + float(offset) * 0.5 + absf(float(rise - 3)) * 2.0
				if cost < best_cost:
					best_cost = cost
					best = {"takeoff_x": (float(takeoff) + 0.5) * TILE_SIZE, "land_x": (float(cell.x) + 0.5) * TILE_SIZE,
						"land_y": float(cell.y) * TILE_SIZE, "pad": false, "dir": dir,
						"edge_x": float(cell.x + (1 if dir > 0 else 0)) * TILE_SIZE}
	return best

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
			var score := absf(float(cell.x) + 0.5 - float(map_w) * 0.5) * 2.5
			score += float((map_h - 2) - cell.y) * 3.0
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
		"ball":
			obj = RollingBall.new()
			obj.set("ball_material", str(data.get("mat", "wood")))
			obj.set("ball_size", float(data.get("size", 1.0)))
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

# Zustand der festen Objekte für den Snapshot: benutzte Herz-Blöcke und die
# Restsperre jedes Portals (0 = bereit).
func get_static_object_snapshot() -> Dictionary:
	var used: Array = []
	for i in range(_mystery_blocks.size()):
		var mb = _mystery_blocks[i]
		if is_instance_valid(mb) and bool(mb.get("is_used")):
			used.append(i)
	var pipes: Array = []
	for pipe in _warp_pipes:
		var remaining := 0.0
		if is_instance_valid(pipe) and not pipe.can_warp:
			remaining = maxf(0.01, pipe.warp_cooldown)
		pipes.append(remaining)
	return {"mb": used, "wp": pipes}

func apply_static_object_snapshot(data: Dictionary) -> void:
	if not Global.network_mode or Global.is_local_host():
		return
	var used = data.get("mb", [])
	if used is Array:
		for raw_index in used:
			var index := int(raw_index)
			if index < 0 or index >= _mystery_blocks.size():
				continue
			var mb = _mystery_blocks[index]
			if is_instance_valid(mb) and not mb.is_used:
				mb.apply_used_from_network()
	var pipes = data.get("wp", [])
	if pipes is Array:
		for i in range(mini(pipes.size(), _warp_pipes.size())):
			var pipe = _warp_pipes[i]
			if is_instance_valid(pipe):
				pipe.apply_network_cooldown(float(pipes[i]))

# Liefert das bewegliche Map-Objekt mit dieser net_id (oder null).
# Brennende Bodenzonen hängen sich so auf Host und Client an dasselbe Objekt.
func get_moving_object(id: int) -> Node:
	var obj = _moving_objects_by_id.get(id)
	if obj == null or not is_instance_valid(obj) or obj.is_queued_for_deletion():
		return null
	return obj

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


# --- Kugeln: Schrägen, Kugelreihen, Kettensperren, Spawner --------------------

## Layout-Keys der Kugel-Maps (Kacheln, Kommazahlen erlaubt; gespiegelt wird
## an der Kartenmitte, x -> map_w - x):
##   "ramps":         [x0, y0, x1, y1, Dicke, Einweg]  Oberkante von (x0,y0) nach
##                    (x1,y1); Einweg = 1: von unten passierbar wie ein Einweg-Steg
##   "walls":         [x0, x1, y0, y1]         feste Wand aus Kacheln
##   "ball_rows":     [x0, y0, x1, y1]         Kugeln entlang der Linie ab (x0,y0)
##   "ball_gates":    [x, y_oben, Höhe, Sekunden bis zum Reißen]
##   "ball_spawners": [x, y, Startrichtung, Intervall in s]
##   "ball_chains":   [ax, ay, bx, by, Durchhang, Gliedmasse, Anteil groß, Anteil klein]
##                    gespannte Kette ohne Kisten, oben drauf eine Reihe Kugeln
func _build_ball_layout(layout: Dictionary, mirror: bool) -> void:
	for entry in layout.get("ramps", []):
		var a := Vector2(float(entry[0]), float(entry[1]))
		var b := Vector2(float(entry[2]), float(entry[3]))
		var thick := float(entry[4]) if entry.size() > 4 else 0.75
		var oneway: bool = entry.size() > 5 and int(entry[5]) == 1
		_build_ramp(a, b, thick, oneway)
		if mirror and not _is_mirror_symmetric(a, b):
			_build_ramp(_mirror_point(a), _mirror_point(b), thick, oneway)
	for entry in layout.get("walls", []):
		_build_layout_rect(int(entry[0]), int(entry[1]), int(entry[2]), int(entry[3]), mirror, platform_textures)
	for entry in layout.get("ball_gates", []):
		var top := Vector2(float(entry[0]), float(entry[1]))
		var height := float(entry[2])
		var release := float(entry[3]) if entry.size() > 3 else 7.0
		_spawn_ball_gate(top, height, release)
		if mirror and absf(_mirror_point(top).x - top.x) > 0.01:
			_spawn_ball_gate(_mirror_point(top), height, release)
	for entry in layout.get("ball_rows", []):
		var a := Vector2(float(entry[0]), float(entry[1]))
		var b := Vector2(float(entry[2]), float(entry[3]))
		_spawn_ball_row(a, b)
		if mirror and not _is_mirror_symmetric(a, b):
			_spawn_ball_row(_mirror_point(a), _mirror_point(b))
	for entry in layout.get("ball_chains", []):
		var a := Vector2(float(entry[0]), float(entry[1]))
		var b := Vector2(float(entry[2]), float(entry[3]))
		var params: Array = [
			float(entry[4]) if entry.size() > 4 else 1.02,
			float(entry[5]) if entry.size() > 5 else 0.9,
			float(entry[6]) if entry.size() > 6 else 0.15,
			float(entry[7]) if entry.size() > 7 else 0.4,
		]
		_spawn_ball_chain(a, b, params[0], params[1], params[2], params[3])
		if mirror and not _is_mirror_symmetric(a, b):
			_spawn_ball_chain(_mirror_point(a), _mirror_point(b), params[0], params[1], params[2], params[3])
	var spawner_entries: Array = layout.get("ball_spawners", [])
	if not spawner_entries.is_empty():
		_spawn_ball_spawner(spawner_entries, mirror)

func _mirror_point(p: Vector2) -> Vector2:
	return Vector2(float(map_w) - p.x, p.y)

func _is_mirror_symmetric(a: Vector2, b: Vector2) -> bool:
	return _mirror_point(a).is_equal_approx(b) and _mirror_point(b).is_equal_approx(a)

## Schräge als fester Körper: Oberkante von a nach b, darunter senkrecht
## thick Kacheln dick. Flacher als 45 Grad ist sie auch begehbar.
func _build_ramp(a: Vector2, b: Vector2, thick: float, oneway: bool = false) -> void:
	var left := a if a.x <= b.x else b
	var right := b if a.x <= b.x else a
	var down := Vector2(0.0, thick)
	var poly: Array = [left, right, right + down, left + down]
	if oneway:
		_build_oneway_ramp(left, right, poly)
		return
	_build_shape_solid([poly], [], [left, right])

## Schräge Einweg-Rampe: Kollision nur als dünner Streifen an der Oberkante
## mit one_way_collision (wie _build_oneway_platform). Spieler springen von
## unten hindurch und fallen mit der Runter-Taste durch (Gruppe
## "one_way_platform"), Kugeln und Kisten rollen oben darauf. Sichtbar ist
## die volle Dicke, etwas durchscheinend, mit Pfeilen darunter.
func _build_oneway_ramp(left: Vector2, right: Vector2, poly: Array) -> void:
	var textures: Array[Texture2D] = platform_textures if not platform_textures.is_empty() else ground_bottom_textures
	if textures.is_empty():
		return
	var body := StaticBody2D.new()
	body.add_to_group("solid")
	body.add_to_group("one_way_platform")
	body.collision_layer = 1
	body.collision_mask = 7
	var l_px := left * TILE_SIZE
	var r_px := right * TILE_SIZE
	var strip := Vector2(0.0, ONE_WAY_THICKNESS)
	var col := CollisionPolygon2D.new()
	col.polygon = PackedVector2Array([l_px, r_px, r_px + strip, l_px + strip])
	col.one_way_collision = true
	col.one_way_collision_margin = 6.0
	body.add_child(col)
	var tex: Texture2D = textures[0]
	var tex_w := maxf(1.0, float(tex.get_width()))
	var fill := Polygon2D.new()
	fill.polygon = _tiles_to_px(poly)
	fill.texture = tex
	fill.texture_scale = Vector2.ONE * (tex_w / TILE_SIZE)
	fill.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	fill.modulate.a = 0.8
	if current_smooth_tiles:
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.add_child(fill)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([l_px, r_px])
	edge.width = 5.0
	edge.default_color = current_accent.lightened(0.15)
	edge.begin_cap_mode = Line2D.LINE_CAP_ROUND
	edge.end_cap_mode = Line2D.LINE_CAP_ROUND
	body.add_child(edge)
	# Pfeile unter der Rampe wie bei den Einweg-Stegen.
	var under: Vector2 = (poly[3] as Vector2) - (poly[0] as Vector2)
	var arrow_color := Color(current_accent.r, current_accent.g, current_accent.b, 0.6)
	var steps := maxi(1, int(round(right.x - left.x)))
	for i in range(steps):
		var t := (float(i) + 0.5) / float(steps)
		var tip := (left.lerp(right, t) + under) * TILE_SIZE + Vector2(0.0, 3.0)
		var arrow := Polygon2D.new()
		arrow.polygon = PackedVector2Array([tip, tip + Vector2(5.0, 6.0), tip + Vector2(-5.0, 6.0)])
		arrow.color = arrow_color
		body.add_child(arrow)
	add_child(body)
	_mark_shape_cells(poly)

## Reihe von Kugeln auf einer Schräge, Kugel an Kugel ab start Richtung end.
## Größe und Material kommen aus dem Karten-RNG (Host und Client gleich).
func _spawn_ball_row(start: Vector2, end: Vector2) -> void:
	var a_px := start * TILE_SIZE
	var b_px := end * TILE_SIZE
	var length := a_px.distance_to(b_px)
	if length < 1.0:
		return
	var dir := (b_px - a_px) / length
	var normal := Vector2(dir.y, -dir.x)
	if normal.y > 0.0:
		normal = -normal
	var s := 0.0
	while true:
		var size := RollingBall.random_size(_rng, 0.3, 0.35)
		var r := RollingBall.radius_for(size)
		if s + r * 2.0 > length:
			break
		var pos := a_px + dir * (s + r) + normal * (r + 1.0)
		spawn_ball(pos, RollingBall.random_material(_rng), size)
		s += r * 2.0 + 1.5
	# Über der Reihe keine Spawns, Kisten oder Deko.
	var steps := int(ceil(length / (TILE_SIZE * 0.5)))
	for i in range(steps + 1):
		var p := a_px.lerp(b_px, float(i) / float(maxi(1, steps)))
		for k in range(3):
			var q := p + normal * TILE_SIZE * float(k)
			var cell := Vector2i(int(floor(q.x / TILE_SIZE)), int(floor(q.y / TILE_SIZE)))
			_object_cells[cell] = true
			_reserved_cells[cell] = true

## Gespannte Kette (CrateChain ohne Kisten) mit Kugeln obendrauf. Schwerere
## Glieder als üblich, damit die beladene Kette nicht überdehnt.
func _spawn_ball_chain(a_tiles: Vector2, b_tiles: Vector2, slack: float, link_mass: float, big_chance: float, small_chance: float) -> void:
	var a_px := a_tiles * TILE_SIZE
	var b_px := b_tiles * TILE_SIZE
	if a_px.x > b_px.x:
		var tmp := a_px
		a_px = b_px
		b_px = tmp
	var dir := (b_px - a_px).normalized()
	a_px += dir * CHAIN_ANCHOR_INSET
	b_px -= dir * CHAIN_ANCHOR_INSET
	var plan := CrateChain.plan(a_px, b_px, true, 0.0, [], slack)
	var chain := CrateChain.new()
	chain.anchor_a = a_px
	chain.anchor_b = b_px
	chain.has_anchor_b = true
	chain.link_mass = link_mass
	chain.elements = plan
	chain.tint = CHAIN_TINTS.get(current_theme_id, Color(0.66, 0.70, 0.76, 1.0))
	_register_moving_object(chain)
	add_child(chain)
	for element in plan:
		for raw_point in [element["p0"], element["p1"]]:
			var p: Vector2 = raw_point
			var cell := Vector2i(int(floor(p.x / TILE_SIZE)), int(floor(p.y / TILE_SIZE)))
			_object_cells[cell] = true
			_reserve_rect(cell.x - 1, cell.x + 1, cell.y - 3, cell.y + 1)
	# Kugeln Kante an Kante auf der geplanten Kettenlinie, je eine Kachel
	# Abstand zu den Ankern.
	var x := a_px.x + TILE_SIZE
	var x_end := b_px.x - TILE_SIZE
	var lift := ChainLink.THICKNESS * 0.5 + 1.0
	while true:
		var size := RollingBall.random_size(_rng, big_chance, small_chance)
		var r := RollingBall.radius_for(size)
		if x + r * 2.0 > x_end:
			break
		var cx := x + r
		spawn_ball(Vector2(cx, _chain_plan_y(plan, cx) - lift - r), RollingBall.random_material(_rng), size)
		x += r * 2.0 + 1.5

## Höhe der geplanten Kettenlinie an der Stelle x (Kette läuft von links
## nach rechts).
func _chain_plan_y(plan: Array, x: float) -> float:
	for element in plan:
		var p0: Vector2 = element["p0"]
		var p1: Vector2 = element["p1"]
		if x >= minf(p0.x, p1.x) and x <= maxf(p0.x, p1.x):
			var t := 0.0 if absf(p1.x - p0.x) < 0.001 else (x - p0.x) / (p1.x - p0.x)
			return lerpf(p0.y, p1.y, t)
	var first: Vector2 = plan[0]["p0"]
	return first.y

func _spawn_ball_gate(top_tiles: Vector2, height_tiles: float, release_time: float) -> void:
	var gate := BallGate.new()
	gate.position = top_tiles * TILE_SIZE
	gate.height_px = height_tiles * TILE_SIZE
	gate.release_time = release_time
	gate.tint = CHAIN_TINTS.get(current_theme_id, Color(0.66, 0.70, 0.76, 1.0))
	_register_moving_object(gate)
	add_child(gate)
	var cx := int(floor(top_tiles.x))
	for y in range(int(floor(top_tiles.y)), int(ceil(top_tiles.y + height_tiles))):
		_object_cells[Vector2i(cx, y)] = true
		_reserved_cells[Vector2i(cx, y)] = true

func _spawn_ball_spawner(entries: Array, mirror: bool) -> void:
	var spawner := BallSpawner.new()
	for entry in entries:
		var p := Vector2(float(entry[0]), float(entry[1]))
		var dir := float(entry[2]) if entry.size() > 2 else 0.0
		spawner.points.append(p * TILE_SIZE)
		spawner.directions.append(dir)
		if mirror and absf(_mirror_point(p).x - p.x) > 0.01:
			spawner.points.append(_mirror_point(p) * TILE_SIZE)
			spawner.directions.append(-dir)
		if entry.size() > 3:
			spawner.interval = float(entry[3])
	add_child(spawner)

## Erzeugt eine Kugel als Map-Objekt mit Netzwerk-ID (Layout, Spawner,
## Modifier Kugelregen/Kugelhagel). Nur auf dem Host zur Laufzeit aufrufen.
func spawn_ball(world_position: Vector2, ball_mat: String, size: float, start_velocity: Vector2 = Vector2.ZERO) -> RollingBall:
	var ball := RollingBall.new()
	ball.ball_material = ball_mat
	ball.ball_size = size
	ball.position = world_position
	ball.linear_velocity = start_velocity
	_register_moving_object(ball)
	add_child(ball)
	return ball

func get_ball_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("rolling_ball"):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			count += 1
	return count
