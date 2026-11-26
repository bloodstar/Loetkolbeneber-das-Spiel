class_name HordeDefs
extends RefCounted

# Werte des Horden-Modus: Gegnerarten, Kurven für Wellen, XP und Bosse.
# Alle Zahlen sind erste Schätzungen und gehören in Testrunden nachjustiert.

## Spieldauer bis zum Endboss in Sekunden.
const RUN_LENGTH: float = 600.0
## Bosse (Sekunden ab Start). Der letzte ist der Endboss: Wer ihn besiegt, gewinnt.
const BOSS_TIMES: Array[float] = [180.0, 360.0, 540.0, 600.0]
const BOSS_BASE_HP: Array[float] = [900.0, 1800.0, 3000.0, 5200.0]
## Gebiete: Nach jedem besiegten Boss geht es auf die nächste Karte. Die
## Treibjagd ist eine lange Scroll-Strecke (Feuerwalze von links).
## Gebiet 2 und 4 werden je Lauf aus zwei Karten gewürfelt: Felsterrassen und
## Tafelberge haben Höhenebenen, die man nur durch Springen erreicht
## (HordeLevelMaps). Der Host würfelt, Clients bekommen die Karten-id.
const STAGE_MAPS: Array[String] = ["arena_wildnis", "arena_horde_steppe", "arena_horde_treibjagd", "arena_horde_ruinen"]
const STAGE_ALTERNATIVES: Dictionary = {
	1: ["arena_horde_steppe", "arena_horde_tafelberge"],
	3: ["arena_horde_ruinen", "arena_horde_terrassen"],
}
## Level-Modifier, die im Horden-Modus erlaubt sind (Sturmzone nicht).
const MODIFIERS: Array[String] = [
	"wind", "low_gravity", "high_gravity", "mini_pigs", "double_damage",
	"speed_demon", "air_jumps", "regeneration", "starting_shield",
]
## Inhalt der Boss-Truhe: Seltenheits-Anteile in Prozent.
const CHEST_RARITY: Dictionary = {"Epic": 95.0, "Legendary": 5.0}
## Wiederbelebung nach dem Tod, solange ein Teamkollege lebt.
const RESPAWN_DELAY: float = 12.0
## XP-Kristalle fliegen ab diesem Abstand zum Eber, darunter werden sie eingesammelt.
## Sammelreichweite 2026-11-26 um 50 % erhöht (120 -> 180, 22 -> 33).
const GEM_MAGNET_RADIUS: float = 180.0
const GEM_PICKUP_RADIUS: float = 33.0
## Mehr liegende Kristalle werden in den nächsten eingerechnet.
const GEM_MAX: int = 220
const MAX_ENEMIES_CAP: int = 230
## Weniger, dafür stärkere Gegner (2026-11-26): Spawnrate, Höchstzahl und
## Rudel-Ringe laufen mit diesem Faktor, dafür kommen deutlich mehr Riesen.
## Gesamt-HP und XP der Horde bleiben dadurch etwa gleich.
const ENEMY_COUNT_MULT: float = 0.7
## Gegner erscheinen in diesem Abstand zum nächsten Eber (außerhalb des Bildes).
const SPAWN_MIN_DIST: float = 620.0
const SPAWN_MAX_DIST: float = 900.0
## Gegner, die zu weit weg sind, werden näher an die Eber versetzt.
const DESPAWN_DIST: float = 1700.0
## Kontaktschaden höchstens so oft pro Gegner.
const CONTACT_INTERVAL: float = 0.7
const RIESE_CHANCE_START: float = 0.03
const RIESE_CHANCE_PER_MIN: float = 0.015
const RIESE_CHANCE_MAX: float = 0.2
const RIESE_SIZE: float = 1.6
const RIESE_HP_MULT: float = 4.0
const RIESE_XP_MULT: float = 5.0

# Gegnerarten. radius = Kollisionsradius in px, size = Modellgröße,
# unlock = ab wann (Sekunden) sie auftauchen, weight = Häufigkeit.
# ai: chase (läuft direkt), fly (fliegt über Mauern, stößt herab),
# lunge (schnappt aus kurzer Distanz zu), ranged (Abstand halten, schießen),
# throw (näherkommen, Hackbeile werfen), howl (Elite, beschleunigt Wölfe).
const ENEMIES: Dictionary = {
	"fuchs": {
		"name": "Fuchs", "hp": 12.0, "speed": 165.0, "damage": 6.0, "radius": 11.0,
		"size": 0.85, "xp": 1, "ai": "chase", "unlock": 0.0, "weight": 10.0, "pack": 3,
	},
	"wolf": {
		"name": "Wolf", "hp": 26.0, "speed": 145.0, "damage": 9.0, "radius": 14.0,
		"size": 1.0, "xp": 2, "ai": "chase", "unlock": 25.0, "weight": 9.0, "pack": 4,
	},
	"adler": {
		"name": "Steinadler", "hp": 16.0, "speed": 185.0, "damage": 8.0, "radius": 12.0,
		"size": 0.95, "xp": 2, "ai": "fly", "unlock": 70.0, "weight": 4.0, "pack": 2,
	},
	"metzger": {
		"name": "Metzger", "hp": 60.0, "speed": 92.0, "damage": 12.0, "radius": 15.0,
		"size": 1.0, "xp": 4, "ai": "throw", "unlock": 100.0, "weight": 4.0, "pack": 1,
		"shot_damage": 11.0, "shot_speed": 330.0, "shot_interval": 2.8, "range": 420.0,
	},
	"krokodil": {
		"name": "Krokodil", "hp": 95.0, "speed": 70.0, "damage": 18.0, "radius": 18.0,
		"size": 1.15, "xp": 6, "ai": "lunge", "unlock": 140.0, "weight": 3.0, "pack": 1,
	},
	"jaeger": {
		"name": "Jäger", "hp": 40.0, "speed": 100.0, "damage": 8.0, "radius": 14.0,
		"size": 1.0, "xp": 4, "ai": "ranged", "unlock": 200.0, "weight": 3.0, "pack": 2,
		"shot_damage": 14.0, "shot_speed": 520.0, "shot_interval": 2.4, "range": 520.0,
	},
	"alphawolf": {
		"name": "Alphawolf", "hp": 150.0, "speed": 150.0, "damage": 16.0, "radius": 20.0,
		"size": 1.45, "xp": 9, "ai": "howl", "unlock": 260.0, "weight": 1.2, "pack": 1,
	},
	"baer": {
		"name": "Braunbär", "hp": 240.0, "speed": 68.0, "damage": 26.0, "radius": 26.0,
		"size": 1.7, "xp": 14, "ai": "chase", "unlock": 300.0, "weight": 1.6, "pack": 1,
	},
}

## Gegner pro Sekunde (vor der Spielerzahl-Skalierung).
static func spawn_rate(t: float) -> float:
	var m := t / 60.0
	return (0.9 + m * 0.62 + m * m * 0.03) * ENEMY_COUNT_MULT

## Höchstzahl lebender Gegner.
static func max_alive(t: float, players: int) -> int:
	var m := t / 60.0
	var base := (45.0 + m * 17.0) * ENEMY_COUNT_MULT
	# Auch die feste Obergrenze schrumpft mit, sonst merken 4 Spieler ab
	# Minute 9 nichts von der Verringerung.
	var cap := int(round(float(MAX_ENEMIES_CAP) * ENEMY_COUNT_MULT))
	return mini(cap, int(base * (1.0 + 0.25 * float(maxi(0, players - 1)))))

static func hp_mult(t: float, players: int) -> float:
	var m := t / 60.0
	return (1.0 + m * 0.2 + m * m * 0.012) * (1.0 + 0.3 * float(maxi(0, players - 1)))

static func damage_mult(t: float) -> float:
	return 1.0 + (t / 60.0) * 0.09

## XP bis zur nächsten Stufe (Stufe 1 -> 2 braucht xp_needed(1)).
static func xp_needed(level: int, players: int) -> int:
	var l := float(level)
	var base := 5.0 + 4.0 * l + 0.4 * l * l
	return int(round(base * (1.0 + 0.2 * float(maxi(0, players - 1)))))

static func boss_hp(index: int, players: int) -> float:
	var i := clampi(index, 0, BOSS_BASE_HP.size() - 1)
	return BOSS_BASE_HP[i] * (1.0 + 0.6 * float(maxi(0, players - 1)))

## Zufällige Gegnerart, gewichtet nach Häufigkeit, nur freigeschaltete.
static func pick_kind(t: float, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	var pool: Array = []
	for id in ENEMIES.keys():
		var e: Dictionary = ENEMIES[id]
		if t < float(e["unlock"]):
			continue
		# Frühe Arten werden mit der Zeit seltener, damit die Mischung wandert.
		var w := float(e["weight"])
		if id == "fuchs":
			w *= clampf(1.4 - t / 300.0, 0.25, 1.4)
		total += w
		pool.append([id, w])
	if pool.is_empty():
		return "fuchs"
	var roll := rng.randf() * total
	for entry in pool:
		roll -= float(entry[1])
		if roll <= 0.0:
			return str(entry[0])
	return str(pool[pool.size() - 1][0])

static func riese_chance(t: float) -> float:
	return minf(RIESE_CHANCE_MAX, RIESE_CHANCE_START + RIESE_CHANCE_PER_MIN * (t / 60.0))

static func gem_color(value: int) -> Color:
	if value >= 20:
		return Color(1.0, 0.35, 0.35)
	if value >= 6:
		return Color(0.4, 1.0, 0.5)
	return Color(0.45, 0.75, 1.0)

static func stage_map(index: int, seed_value: int = 0) -> String:
	var i := clampi(index, 0, STAGE_MAPS.size() - 1)
	var options: Array = STAGE_ALTERNATIVES.get(i, [])
	if seed_value != 0 and not options.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		return str(options[rng.randi() % options.size()])
	return STAGE_MAPS[i]

static func stage_title(index: int) -> String:
	return ArenaMaps.display_name(stage_map(index))

## Zeit als m:ss.
static func format_time(t: float) -> String:
	var s := maxi(0, int(t))
	return "%d:%02d" % [s / 60, s % 60]
