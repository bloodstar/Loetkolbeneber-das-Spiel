class_name ArenaMaps
extends RefCounted

# Arena-Karten als Zeichenraster (eine Zeile = eine Kachelreihe, Nord oben).
#   .  Boden
#   #  hohe Mauer (3 Bänder, 108 px) – nur mit sehr viel Sprungkraft erklimmbar
#   H  halbhohe Mauer (2 Bänder, 72 px)
#   c  niedrige Deckung (1 Band, 36 px) – überspringbar, man kann draufstehen
#   x  zerstörbare Kiste (1 Band)
#   S  Spawnpunkt (Boden)
# Rampen und Stege folgen (siehe ArenaGrid.ramps / Blöcke mit Luft darunter).

const MAP_IDS: Array[String] = ["arena_hof", "arena_kistenlager", "arena_ruinen"]

const BLOCK_HEIGHTS: Dictionary = {
	"#": 108.0,
	"H": 72.0,
	"c": 36.0,
	"x": 36.0,
}

const MAPS: Dictionary = {
	"arena_hof": {
		"name": "Burghof",
		"description": "Steinsäulen, ein Brunnenblock in der Mitte und niedrige Mäuerchen zum Drüberspringen.",
		"floor": Color(0.42, 0.62, 0.32),
		"wall": Color(0.62, 0.6, 0.56),
		"accent": Color(1.0, 0.75, 0.3, 0.95),
		"rows": [
			"..................................",
			".........xx.....S......xx.........",
			"..S............H..H............S..",
			"...............H..H...............",
			"......##.......H..H.......##......",
			"......##..................##......",
			".............x......x.............",
			"..................................",
			".....x......................x.....",
			"...........cc..####..cc...........",
			"..ccc..........####..........cccS.",
			".Sccc..........####..........ccc..",
			"...........cc..####..cc...........",
			".....x......................x.....",
			"..................................",
			".............x......x.............",
			"......##..................##......",
			"......##.......H..H.......##......",
			"...............H..H...............",
			"..S............H..H............S..",
			".........xx......S.....xx.........",
			"..................................",
		],
	},
	"arena_kistenlager": {
		"name": "Kistenlager",
		"description": "Reihen zerstörbarer Kisten: Wer schießt, macht sich den Weg frei.",
		"floor": Color(0.55, 0.5, 0.42),
		"wall": Color(0.45, 0.42, 0.4),
		"accent": Color(0.3, 0.85, 1.0, 0.95),
		"rows": [
			"..................................",
			".S..............................S.",
			"................S.................",
			"....xx...xx...xx...xx...xx...xx...",
			"..................................",
			".cc......#..............#......cc.",
			".........#..............#.........",
			"..................................",
			"....xx...xx...xx...xx...xx...xx...",
			"..................................",
			".S............H.cc.H..............",
			"..............H.cc.H............S.",
			"..................................",
			"....xx...xx...xx...xx...xx...xx...",
			"..................................",
			".........#..............#.........",
			".cc......#..............#......cc.",
			"..................................",
			"....xx...xx...xx...xx...xx...xx...",
			".................S................",
			".S..............................S.",
			"..................................",
		],
	},
	"arena_ruinen": {
		"name": "Ruinen",
		"description": "Lange Mauerzüge, Gänge und eine Säule in der Mitte.",
		"floor": Color(0.78, 0.68, 0.46),
		"wall": Color(0.7, 0.58, 0.42),
		"accent": Color(1.0, 0.35, 0.55, 0.95),
		"rows": [
			"..................................",
			".S..............S...............S.",
			"..................................",
			".....#######.........xxxx...H.....",
			".....#......................H.....",
			".....#......................H.....",
			".....#......................H.....",
			".....#......cccccccccc......H.....",
			".....#............................",
			"................##................",
			"........HH...x..##..x...HH.....S..",
			"..S.....HH...x..##..x...HH........",
			"................##................",
			"............................#.....",
			".....H......cccccccccc......#.....",
			".....H......................#.....",
			".....H......................#.....",
			".....H......................#.....",
			".....H...xxxx.........#######.....",
			"..................................",
			".S...............S..............S.",
			"..................................",
		],
	},
}

static func is_arena_map(map_id: String) -> bool:
	return MAPS.has(map_id)

static func get_map(map_id: String) -> Dictionary:
	return MAPS.get(map_id, {})

static func display_name(map_id: String) -> String:
	return str(MAPS.get(map_id, {}).get("name", map_id))

## Zufällige Arena-Karte, deterministisch aus dem Runden-Seed.
static func pick_random(level_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, level_seed)
	return MAP_IDS[rng.randi() % MAP_IDS.size()]
