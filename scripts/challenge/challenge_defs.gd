class_name ChallengeDefs
extends RefCounted

# Challenge-Runden: Zwischen normalen FFA-/Team-Runden kommt ab und zu eine
# Runde mit eigenem Ziel (Lobby-Regel "Challenge-Runden"). Wer die Challenge
# gewinnt (bzw. dessen Team), bekommt die normalen Rundenpunkte, die Verlierer
# draften wie immer. Kills zählen in jeder Challenge ganz normal.
#
# Felder pro Challenge:
#   name, goal:  Anzeige (Lobby, Banner, HUD)
#   maps:        feste Karten (eine davon per Runden-Seed). Leer = die normale
#                Karte der Runde (Lobby-Einstellung Seite/Draufsicht/Beides).
#   time:        Zeitlimit in s. Danach gewinnt, wer vorn liegt.
#   respawn:     s bis zum Wiedereinstieg nach einem Tod. < 0 = wer stirbt,
#                ist für die Runde raus (normales Ausscheiden).
#   min_players: so viele Spieler braucht die Challenge mindestens.

const ORDER: Array[String] = ["race", "hill", "ballpit", "coins", "lava", "wave"]

const FREQUENCY_NAMES: Array[String] = ["Aus", "Selten", "Oft"]
## Chance pro Runde (nach mindestens einer normalen Runde).
const FREQUENCY_CHANCE: Array[float] = [0.0, 0.25, 0.45]

const DEFS: Dictionary = {
	"race": {
		"name": "Wettrennen",
		"goal": "3 Runden! Fahrt durch alle Tore, wer zuerst im Ziel ist, gewinnt.",
		"short": "3 Runden auf dem Rundkurs (Draufsicht). Tore der Reihe nach, wer stirbt, startet am letzten Tor neu.",
		"maps": ["arena_rundkurs"],
		"time": 180.0,
		"respawn": 2.0,
		"laps": 3,
		"color": Color(1.0, 0.75, 0.25),
	},
	"hill": {
		"name": "König des Hügels",
		"goal": "Haltet die Zone! Nur wer allein drinsteht, füllt seine Leiste.",
		"short": "Zone halten, bis die Leiste voll ist (20 s). Auf der normalen Karte der Runde.",
		"maps": [],
		"time": 90.0,
		"respawn": 2.0,
		"hold": 20.0,
		"color": Color(1.0, 0.85, 0.3),
	},
	"ballpit": {
		"name": "Bällebad",
		"goal": "Schiebt und schießt die Bälle in eure Ecke! Nach 60 s zählen sie.",
		"short": "Jeder startet in einer Ecke, die Karte wird mit Bällen geflutet. Nach 60 s gewinnt, wer die meisten Bälle in seiner Ecke hat.",
		"maps": ["arena_baellebad"],
		"time": 60.0,
		"respawn": 2.0,
		"color": Color(0.45, 0.85, 1.0),
	},
	"coins": {
		"name": "Münzjagd",
		"goal": "Sammelt Münzen! Wer stirbt, verliert die Hälfte.",
		"short": "60 s Münzen sammeln, wer stirbt, lässt die Hälfte fallen. Auf der normalen Karte der Runde.",
		"maps": [],
		"time": 60.0,
		"respawn": 2.0,
		"coins_alive": 7,
		"color": Color(1.0, 0.85, 0.2),
	},
	"lava": {
		"name": "Lava-Aufstieg",
		"goal": "Die Lava steigt ohne Pause! Wer zuerst die Flagge oben erreicht, gewinnt.",
		"short": "Im Lavaturm zur Flagge auf dem Gipfel klettern. Die Lava hält nicht an, wer stirbt, ist raus.",
		"maps": ["lavaturm"],
		"time": 150.0,
		"respawn": -1.0,
		"lava_speed": 26.0,
		"color": Color(1.0, 0.45, 0.2),
	},
	"wave": {
		"name": "Hordenwelle",
		"goal": "Die Horde greift an! Wer die meisten Gegner erlegt, gewinnt.",
		"short": "75 s gegen die Horde (Draufsicht), wer die meisten Gegner erlegt, gewinnt. Spieler-Kills zählen wie immer.",
		"maps": ["arena_hof", "arena_ruinen", "arena_steppe", "arena_marktplatz"],
		"time": 75.0,
		"respawn": 2.0,
		"color": Color(0.6, 1.0, 0.5),
	},
}

static func chance_for(frequency: int) -> float:
	return FREQUENCY_CHANCE[clampi(frequency, 0, FREQUENCY_CHANCE.size() - 1)]

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

static func display_name(id: String) -> String:
	return str(get_def(id).get("name", id))

static func is_possible(id: String, players: int) -> bool:
	if not DEFS.has(id):
		return false
	if players < int(get_def(id).get("min_players", 2)):
		return false
	for map_id in get_def(id).get("maps", []):
		if not ArenaMaps.is_arena_map(str(map_id)) and not SideLevels.has(str(map_id)) \
				and not LevelGenerator.MAP_PROFILES.has(str(map_id)):
			return false
	return true

## Feste Karte der Challenge ("" = normale Karte der Runde).
static func pick_map(id: String, level_seed: int) -> String:
	var maps: Array = get_def(id).get("maps", [])
	if maps.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([maxi(1, level_seed), "challenge_map"])
	return str(maps[rng.randi() % maps.size()])

## Respawn-Verzögerung (< 0 = kein Respawn).
static func respawn_delay(id: String) -> float:
	return float(get_def(id).get("respawn", -1.0))

## Passt die normale Karte der Runde zu einer Challenge ohne feste Karte?
## Keine Autoscroll-Strecken und keine Türme mit steigender Lava: Dort liefe
## eine feste Zone bzw. Münze aus dem Bild.
static func map_suitable(id: String, map_id: String) -> bool:
	if not (get_def(id).get("maps", []) as Array).is_empty():
		return true
	if ArenaMaps.is_arena_map(map_id):
		return not ArenaMaps.get_map(map_id).has("autoscroll")
	var prof := SideLevels.profile(map_id)
	return not (prof.has("autoscroll") or prof.has("rising_lava") or bool(prof.get("scrolling", false)))
