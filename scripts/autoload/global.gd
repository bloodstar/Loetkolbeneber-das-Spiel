extends Node

const LevelModifierDefsClass = preload("res://scripts/level_modifier_defs.gd")

signal scores_changed(scores: Array)
signal round_ended(winner_index: int)
signal card_selected(player_index: int, card: CardData)
signal match_over(winner_index: int)
# Mehrere Spieler/Teams haben das Ziel gleichzeitig erreicht: Stechen.
signal tiebreak_started(slots: Array)
# Ein neues Match beginnt (Punkte, Karten und Match-Statistik wurden geleert).
signal match_reset()
signal bot_mode_toggled(enabled: bool)
signal cards_per_draft_changed(count: int)
signal draft_config_changed(picks: int, offered: int)
signal draft_modifiers_changed()
signal level_modifiers_changed()
signal melee_enabled_changed(enabled: bool)
signal banned_cards_changed()
signal scoring_config_changed()
signal match_target_changed(points: int)
signal base_hp_percent_changed(percent: int)
signal base_damage_changed(damage: float)
signal rarity_percentages_changed()
signal card_pools_changed()
signal map_changed()
# Levels wurden im Lobby-Reiter "Levels" an- oder abgeschaltet.
signal map_pool_changed()
# Powerups wurden im Lobby-Reiter "Powerups" an- oder abgeschaltet.
signal powerup_pool_changed()
signal match_mode_changed(mode: String)
signal player_count_changed(count: int)
signal lobby_state_changed()
signal lobby_loadouts_changed()
# "Last" wurde neu geschrieben; die Lobby aktualisiert daraufhin nur die Vorschau.
signal lobby_last_loadout_saved()
signal network_status_changed()
signal pig_appearance_changed(player_index: int)

enum GameState {
	MENU,
	PLAYING,
	CARD_DRAFT,
	GAME_OVER,
	LOBBY
}

# Wie ein Slot besetzt ist. Slot 1 ist immer der lokale Spieler bzw. der Host.
enum PlayerKind {
	OFF = 0,
	HUMAN = 1,
	BOT = 2
}

const MIN_PLAYERS: int = 2
const MAX_PLAYERS: int = 6

const MATCH_MODE_FFA: String = "ffa"
const MATCH_MODE_2V2: String = "2v2"
const MATCH_MODE_3V3: String = "3v3"
const MATCH_MODE_2V2V2: String = "2v2v2"
const MATCH_MODE_ORDER: Array[String] = [MATCH_MODE_FFA, MATCH_MODE_2V2, MATCH_MODE_3V3, MATCH_MODE_2V2V2]
const MATCH_MODES: Dictionary = {
	MATCH_MODE_FFA: {
		"name": "FFA",
		"players": 0,
		"teams": 0,
		"description": "Jeder gegen jeden. 2 bis 6 Spieler, jeder kämpft für sich.",
	},
	MATCH_MODE_2V2: {
		"name": "2v2",
		"players": 4,
		"teams": 2,
		"description": "Vier Spieler, zwei Teams mit je zwei Mitgliedern.",
	},
	MATCH_MODE_3V3: {
		"name": "3v3",
		"players": 6,
		"teams": 2,
		"description": "Sechs Spieler, zwei Teams mit je drei Mitgliedern.",
	},
	MATCH_MODE_2V2V2: {
		"name": "2v2v2",
		"players": 6,
		"teams": 3,
		"description": "Sechs Spieler, drei Teams mit je zwei Mitgliedern.",
	},
}
const TEAM_NAMES: Array[String] = ["ROT", "BLAU", "GRÜN"]
const TEAM_COLORS: Array[Color] = [
	Color(1.0, 0.36, 0.36, 1.0),
	Color(0.36, 0.68, 1.0, 1.0),
	Color(0.38, 0.95, 0.55, 1.0),
]

var current_state: GameState = GameState.PLAYING
var match_mode: String = MATCH_MODE_FFA

# Match-Punkte: Kills und das Überleben einer Runde geben Punkte. Wer zuerst
# die konfigurierte Punktzahl erreicht, gewinnt das Match.
var points_to_win: int = 500
# Stechen: Slots, die nach gleichzeitigem Erreichen des Ziels allein
# gegeneinander antreten. Leer = normales Match.
var tiebreak_slots: Array[int] = []
# Wie das letzte Match endete: "" (Ziel erreicht), "tiebreak" (im Stechen
# entschieden) oder "early" (vorzeitig beendet, Sieger nach Punkten).
var match_end_reason: String = ""
var survival_points: int = 50
var kill_points: int = 50

var cards_per_draft: int = 5 # Y: Wie viele Karten zur Auswahl stehen
var draft_picks: int = 1     # X: Wie viele Karten pro Draft gewählt werden
# Draft-Modifier: Blind pick verdeckt Angebot/Auswahl online vor anderen
# menschlichen Spielern (lokal gegen Bots ohne Wirkung), Random pick zieht
# automatisch eine zufällige Karte aus dem Angebot.
var blind_pick_enabled: bool = false
# Lobby-Regel: Nahkampfwaffen (E) und der Kartenpool "Nahkampf" an/aus.
var melee_enabled: bool = true
var random_pick_enabled: bool = false
# Draft-Modifier Gamble: Karten verdeckt (Rückseite = Seltenheit), von links
# einzeln aufdecken; wer weiterdreht, verkohlt die offene Karte.
var gamble_enabled: bool = false
# Lobby-Regel Pre-Draft: Jeder Spieler draftet vor der ersten Runde so viele
# Karten (0 = aus). pre_draft_random lässt diese Picks zufällig ziehen.
const PRE_DRAFT_MAX_PICKS: int = 10
var pre_draft_picks: int = 0
var pre_draft_random: bool = false
# Runden-Modifier: Rate in Prozent (0 = aus, 100 = Standard, 200 = mehr)
# und die Menge der freigeschalteten Modifier-IDs aus LevelModifierDefs.
var level_modifier_rate_percent: int = LevelModifierDefsClass.RATE_DEFAULT_PERCENT
var enabled_level_modifiers: Array[String] = []
var banned_card_ids: Array[String] = [] # Im Lobby gesperrte Powerup-Karten
# Prozent-Faktor auf die heldenspezifischen Basis-HP vor Kartenboni.
# 100 % = Heldenwert; die Klassenunterschiede bleiben dadurch erhalten.
const BASE_HP_PERCENT_MIN: int = 50
const BASE_HP_PERCENT_MAX: int = 300
var base_hp_percent: int = 100
# Grundschaden eines Projektils vor Helden-/Kartenmodifikatoren.
var base_damage: float = 22.0

# Kartenpools: Jede Karte gehört zu genau einem Pool. Die Lobby kann Pools
# einzeln aktivieren, damit Drafts klarer thematisiert werden können.
# Die früheren Pools "Kern" (jetzt Offensive) und "Chaos" (jetzt Defensive)
# gibt es nicht mehr; gespeicherte Einstellungen damit werden beim Laden ignoriert.
const CARD_POOLS: Array[String] = ["Offensive", "Defensive", "Bewegung", "Nahkampf"]
# Pools, die es schon vor dem Nahkampf-Pool gab. Gespeicherte Einstellungen
# ohne "known_card_pools" kennen nur diese; neuere Pools werden dann aktiviert.
const LEGACY_CARD_POOLS: Array[String] = ["Kern", "Offensive", "Defensive", "Bewegung", "Chaos"]
# Runden-Modifier, die nach dem ersten Speicherformat dazukamen. Gespeicherte
# Einstellungen ohne "known_level_modifiers" schalten diese automatisch ein.
const LATER_LEVEL_MODIFIERS: Array[String] = ["brawl"]
const CARD_POOL_DESCRIPTIONS: Dictionary = {
	"Offensive": "Schaden, Munition, Projektile und Elementareffekte.",
	"Defensive": "Leben, Schild, Block und Regeneration.",
	"Bewegung": "Tempo, Sprünge, Dash und Trefferfläche.",
	"Nahkampf": "Schaden, Reichweite und Effekte der Nahkampfwaffe (E).",
}
var enabled_card_pools: Array[String] = ["Offensive", "Defensive", "Bewegung", "Nahkampf"]
# Karten, die der Host trotz abgeschaltetem Pool einzeln freigegeben hat.
# Ausbaukarten einer freigegebenen Grundkarte gelten ebenfalls als frei.
var pool_unlocked_card_ids: Array[String] = []

# Spielfeld-Auswahl. Jede Map hat ein festes Tileset und ein eigenes
# Layout-Profil; "zufall" wählt deterministisch aus dem Seed.
const MAP_RANDOM: String = "zufall"
const MAP_PLAYABLE: Array[String] = [
	"grasarena", "wuestenruine", "eisgrotte", "neonfabrik",
	"weite", "wolkeninsel", "kistenfestung",
	"uhrwerk", "pilzpfad", "gletscherpass",
	"lavaturm", "himmelsleiter", "hauptplatine",
	"sonnentempel", "kettenwerk", "wollhaus", "eispyramiden", "serverhaus",
	"gitterzaun", "truemmerfeld", "schrottplatz", "schneefeld", "wollmarkt",
	"kugellawine", "kugelbahn", "kugelkette", "kugelmuehle",
]
const MAPS: Dictionary = {
	"zufall": {
		"name": "Zufällig",
		"description": "Wählt pro Runde eine der siebenundzwanzig Maps.",
	},
	"grasarena": {
		"name": "Grasarena",
		"description": "Luftige Balken, zentrale Wippe, Holzkisten und Powerups.",
	},
	"wuestenruine": {
		"name": "Wüstenruine",
		"description": "Offene Sandinseln mit Kettenplattformen, Kisten und TNT.",
	},
	"eisgrotte": {
		"name": "Eisgrotte",
		"description": "Glatte Eisflächen, schwebende Wippe und Kistenstapel.",
	},
	"neonfabrik": {
		"name": "Neonfabrik",
		"description": "Vertikale Technikarena mit Ketten, Kisten und Powerups.",
	},
	"weite": {
		"name": "Weite Wiese",
		"description": "Offene Wiese mit nur wenigen Plattformen und viel Luft für Duelle.",
	},
	"wolkeninsel": {
		"name": "Wolkeninsel",
		"description": "Kleine Wolkeninseln, weite Sprünge und eine pendelnde Wolkenfähre.",
	},
	"uhrwerk": {
		"name": "Uhrwerk",
		"description": "Riesiges Zifferblatt: Auf dem drehenden Minutenzeiger fährt man mit, Aufzüge an den Seiten, von oben fallen Kugeln.",
	},
	"pilzpfad": {
		"name": "Pilzpfad",
		"description": "Seitlich scrollendes Jump-'n'-Run-Level mit Gruben, Treppen, Steinen und Fähre.",
	},
	"gletscherpass": {
		"name": "Gletscherpass",
		"description": "Scroll-Level über vereiste Abgründe mit Aufzügen, Wippe und Kettenplattform.",
	},
	"hauptplatine": {
		"name": "Hauptplatine",
		"description": "Arena auf einer leuchtenden Leiterplatte mit Datenbus-Shuttle und Chip-Deckung.",
	},
	"lavaturm": {
		"name": "Lavaturm",
		"description": "Vertikaler Turm: Klettern, bevor die Lava aus der Tiefe euch einholt.",
	},
	"himmelsleiter": {
		"name": "Himmelsleiter",
		"description": "Vertikaler Aufstieg durch die Wolken mit Feder, Aufzug, Fähre und Gipfelportal.",
	},
	"sonnentempel": {
		"name": "Sonnentempel",
		"description": "Große hohle Pyramide: außen drüberlaufen, unten hinein. Darüber eine Kistenkette.",
	},
	"kettenwerk": {
		"name": "Kettenwerk",
		"description": "Neon-Halle voller Kistenketten zwischen Einweg-Stegen und am Kartenrand.",
	},
	"wollhaus": {
		"name": "Wollhaus",
		"description": "Haus mit vier Räumen, Luken und begehbarem Dach, dazu Kisten an Ketten.",
	},
	"eispyramiden": {
		"name": "Eispyramiden",
		"description": "Zwei hohle Eispyramiden, zwischen den Spitzen hängt eine Kistenkette.",
	},
	"serverhaus": {
		"name": "Serverhaus",
		"description": "Rechenzentrum mit vier Räumen auf der Platine, Kistenketten bis zum Kartenrand.",
	},
	"gitterzaun": {
		"name": "Gitterzaun",
		"description": "Ein Gitter aus fünf senkrechten und vier waagrechten Ketten, große Kisten an jeder Kreuzung.",
	},
	"truemmerfeld": {
		"name": "Trümmerfeld",
		"description": "Offene Ruinen mit zerstörbaren Mauern, Torbogen, Fässern und vielen Kisten.",
	},
	"schrottplatz": {
		"name": "Schrottplatz",
		"description": "Offener Neon-Schrottplatz: Blockhaufen, Kisten an Ketten und viel TNT.",
	},
	"schneefeld": {
		"name": "Schneefeld",
		"description": "Weites Schneefeld mit zerstörbaren Schneeburgen, Tiefschnee und Eis.",
	},
	"wollmarkt": {
		"name": "Wollmarkt",
		"description": "Offener Markt mit Ständen auf zerstörbaren Pfosten, Trampolinen und Kisten.",
	},
	"kistenfestung": {
		"name": "Kistenfestung",
		"description": "Komplett aus Holzkisten gebaut – mit großer Wippe und Kistentürmen in der Mitte.",
	},
	"kugellawine": {
		"name": "Kugellawine",
		"description": "Oben warten Kugeln aus Gummi, Holz und Eisen hinter einer Kette. Reißt sie, rollt die Lawine los.",
	},
	"kugelkette": {
		"name": "Kugelkette",
		"description": "Lange Kette quer unter der Decke, oben drauf viele Kugeln. Ein Schuss ins Glied, und es regnet Kugeln.",
	},
	"kugelbahn": {
		"name": "Kugelbahn",
		"description": "Doppelte Zickzack-Kugelbahn: Alle 5 Sekunden rollen neue Kugeln herab bis auf den Boden.",
	},
	"kugelmuehle": {
		"name": "Kugelmühle",
		"description": "Zwei gegenläufige Windmühlen-Kreuze fangen herabfallende Kugeln und schleudern sie zur Mitte.",
	},
}
var selected_map_id: String = MAP_RANDOM
# Abgeschaltete Levels. Bewusst eine Sperrliste: Neue Maps in MAP_PLAYABLE sind
# damit automatisch aktiv, auch in alten Presets. "Zufällig" wählt nur aus den
# übrigen. Sind alle aus, lässt die Lobby das Match nicht starten.
var disabled_map_ids: Array[String] = []

# Pickup-Powerups (zufällige Spawns, Kisten-Drops, Powerup-Regen). Wie bei den
# Levels eine Sperrliste: Neue Powerup-Arten sind automatisch aktiv. Alle aus
# ist erlaubt, dann erscheinen keine Powerups.
const POWERUP_KINDS: Array[String] = ["heal", "invulnerability", "damage", "rapid_fire", "auto_attack", "multishot", "undying", "revenge", "invisible"]
const POWERUP_INFO: Dictionary = {
	"heal": {"name": "Heilung", "description": "Heilt sofort 35 HP."},
	"invulnerability": {"name": "Schutz", "description": "3 s unverwundbar."},
	"damage": {"name": "Schaden", "description": "6 s lang +65 % Schaden (Schüsse und Nahkampf)."},
	"rapid_fire": {"name": "Dauerfeuer", "description": "5 s Dauerfeuer ohne Munitionsverbrauch und ohne Nachladen."},
	"auto_attack": {"name": "Auto-Angriff", "description": "8 s halbe Nahkampf-Abklingzeit, schlägt selbst nach Gegnern in Reichweite. Erscheint nur mit Nahkampf."},
	"multishot": {"name": "Multishot", "description": "8 s lang feuert jeder Schuss 3 Projektile im Fächer."},
	"undying": {"name": "Unsterblichkeit", "description": "Stirbst du in den nächsten 10 s, stehst du nach 2 s mit halbem Leben wieder auf."},
	"revenge": {"name": "Rache", "description": "5 s lang 100 % Dornenschaden: Angreifer erleiden den Schaden, den sie dir zufügen."},
	"invisible": {"name": "Unsichtbar", "description": "6 s lang für Gegner unsichtbar. Deine Schüsse und Effekte bleiben sichtbar."},
}
var disabled_powerup_kinds: Array[String] = []

# Lobby-Loadouts: benannte Presets für alle Host-Einstellungen (Modus, Punkte,
# Draft, Kartenpools, Bans, Map, HP/Schaden usw.). Sie werden lokal gespeichert.
const LOBBY_LOADOUTS_PATH: String = "user://lobby_loadouts.json"
# Wird bei jeder Regeländerung automatisch mitgeschrieben und beim Start geladen.
const LOBBY_LAST_LOADOUT: String = "Last"
const LOBBY_AUTOSAVE_DELAY: float = 0.6
var lobby_loadouts: Dictionary = {}
# In Tests abschaltbar, damit sie die echte "Last"-Datei nicht überschreiben.
var lobby_autosave_enabled: bool = true
var _lobby_autosave_timer: Timer

# Automatisch gespeichertes Charakterprofil des lokalen Nutzers.
const CHARACTER_CUSTOMIZATION_PATH: String = "user://character_customization.json"
const WAND_TIP_SHAPES: Array[String] = ["orb", "star", "crystal", "flame", "ball", "diamond", "spark", "blaze"]
const WAND_TIP_SHAPE_LABELS: Dictionary = {
	"orb": "Kegel",
	"star": "Meißel",
	"crystal": "Messer",
	"flame": "Huf",
	"ball": "Kugel",
	"diamond": "Diamant",
	"spark": "Stern",
	"blaze": "Flamme",
}
# Hauerformen des Ebers (Charakter-Tab).
const TUSK_SHAPES: Array[String] = ["small", "long", "saber", "double", "stub"]
const TUSK_SHAPE_LABELS: Dictionary = {
	"small": "Klein",
	"long": "Lang",
	"saber": "Säbel",
	"double": "Doppelt",
	"stub": "Stummel",
}
const PLAYER_NAME_MAX_LENGTH: int = 16
# Nahkampfwaffen (Taste E). Reichweite in Feldern (1 Feld = 36 px) ab dem
# Rand des Ziels; arc_deg ist der volle Trefferwinkel um die Zielrichtung,
# 0 = gerader Stich. wall_stun: Betäubung, wenn das Ziel gegen eine Wand fliegt.
# version: Bei jeder Balance-Änderung einer Waffe (Schaden, Reichweite, Bogen,
# Rückstoß, Abklingzeit, Betäubung) um 1 erhöhen. Nur label/desc geändert:
# nicht erhöhen. Die Statistik trennt alte und neue Messwerte danach.
const MELEE_WEAPONS: Array[String] = ["iron", "sword", "hammer", "flail"]
const MELEE_TILE_SIZE: float = 36.0
const MELEE_WEAPON_DATA: Dictionary = {
	"iron": {
		"version": 2, # Balance von Jochen am 2026-10-27
		"label": "Lötkolben", "arc_deg": 0.0, "range_tiles": 3.0,
		"damage": 50.0, "knockback": 650.0, "cooldown": 1.4, "wall_stun": 0.0,
		"desc": "Sticht gerade Richtung Zeiger. Hoher Schaden, hohe Reichweite, starker Rückstoß.",
	},
	"sword": {
		"version": 2, # Balance von Jochen am 2026-10-27
		"label": "Schwert", "arc_deg": 60.0, "range_tiles": 3.0,
		"damage": 30.0, "knockback": 220.0, "cooldown": 0.9, "wall_stun": 0.0,
		"desc": "Hieb im 60°-Bogen Richtung Zeiger. Mittlerer Schaden, hohe Reichweite, wenig Rückstoß.",
	},
	"hammer": {
		"version": 3, # Balance von Jochen am 2026-10-27
		"label": "Hammer", "arc_deg": 120.0, "range_tiles": 1.0,
		"damage": 20.0, "knockback": 950.0, "cooldown": 1.1, "wall_stun": 0.8,
		"desc": "Schwingt im 120°-Bogen und schleudert Gegner weg. Wer gegen eine Wand fliegt, ist kurz betäubt.",
	},
	"flail": {
		"version": 2, # Balance von Jochen am 2026-10-27
		"label": "Flegel", "arc_deg": 360.0, "range_tiles": 2.0,
		"damage": 30.0, "knockback": 420.0, "cooldown": 1.2, "wall_stun": 0.0,
		"desc": "Kreist einmal komplett um den Eber. Mittlere Reichweite und mittlerer Rückstoß.",
	},
}
var user_character_customization: Dictionary = {}

# Seltenheiten und ihre konfigurierbaren Anteile am Kartenangebot. Die Werte
# müssen nicht genau 100 ergeben; sie werden beim Ziehen automatisch normalisiert.
const RARITY_ORDER: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
var rarity_percentages: Dictionary = {
	"Common": 54.0,
	"Uncommon": 25.0,
	"Rare": 15.0,
	"Epic": 5.0,
	"Legendary": 1.0,
}

# --- Spieler-Slots (Index 0..5 = Spieler 1..6) ---
var player_count: int = MIN_PLAYERS
var player_hero_ids: Array[String] = ["ignis", "volt", "spore", "nova", "ignis", "volt"]
var player_kind: Array[int] = [
	PlayerKind.HUMAN, PlayerKind.BOT, PlayerKind.OFF,
	PlayerKind.OFF, PlayerKind.OFF, PlayerKind.OFF
]
var player_scores: Array[int] = [0, 0, 0, 0, 0, 0]

const MATCH_STAT_KEYS: Array[String] = [
	"kills", "deaths", "damage_dealt", "damage_taken", "damage_blocked",
	"blocked_hits", "healing_done", "shots_fired", "shots_hit", "rounds_won",
	"melee_damage", "melee_hits", "ability_damage",
]
var match_stats: Array = []
# Pro Slot eine Liste der gedrafteten Karten.
var player_cards: Array = [[], [], [], [], [], []]

# --- Schweine-Charaktere ---
# Jeder Spieler darf Fell-, Augen- und Hosenfarbe in der Lobby anpassen.
# Die Standardwerte unterscheiden die Slots im Getümmel trotzdem deutlich.
const PIG_DEFAULT_EYE_COLOR: Color = Color(0.17, 0.13, 0.19, 1.0)
const PIG_DEFAULT_PANTS_COLOR: Color = Color(0.25, 0.37, 0.57, 1.0)
var default_pig_fur_colors: Array[Color] = [
	Color(0.91, 0.60, 0.67, 1.0),
	Color(0.58, 0.75, 0.88, 1.0),
	Color(0.63, 0.81, 0.67, 1.0),
	Color(0.85, 0.69, 0.48, 1.0),
	Color(0.71, 0.63, 0.85, 1.0),
	Color(0.49, 0.44, 0.46, 1.0),
]
var player_pig_fur_colors: Array[Color] = [
	Color(0.91, 0.60, 0.67, 1.0),
	Color(0.58, 0.75, 0.88, 1.0),
	Color(0.63, 0.81, 0.67, 1.0),
	Color(0.85, 0.69, 0.48, 1.0),
	Color(0.71, 0.63, 0.85, 1.0),
	Color(0.49, 0.44, 0.46, 1.0),
]
var player_pig_eye_colors: Array[Color] = [
	PIG_DEFAULT_EYE_COLOR, PIG_DEFAULT_EYE_COLOR, PIG_DEFAULT_EYE_COLOR,
	PIG_DEFAULT_EYE_COLOR, PIG_DEFAULT_EYE_COLOR, PIG_DEFAULT_EYE_COLOR,
]
var player_pig_pants_colors: Array[Color] = [
	PIG_DEFAULT_PANTS_COLOR, PIG_DEFAULT_PANTS_COLOR, PIG_DEFAULT_PANTS_COLOR,
	PIG_DEFAULT_PANTS_COLOR, PIG_DEFAULT_PANTS_COLOR, PIG_DEFAULT_PANTS_COLOR,
]
# Zauberstab-Spitze und Basis-Schuss sind pro Slot frei konfigurierbar.
var default_wand_tip_colors: Array[Color] = [
	Color(1.0, 0.4, 0.2, 1.0),
	Color(1.0, 0.9, 0.2, 1.0),
	Color(0.4, 0.9, 0.3, 1.0),
	Color(0.6, 0.4, 1.0, 1.0),
	Color(1.0, 0.3, 0.5, 1.0),
	Color(0.3, 0.9, 0.7, 1.0),
]
var player_wand_tip_shapes: Array[String] = ["orb", "orb", "orb", "orb", "orb", "orb"]
var player_tusk_shapes: Array[String] = ["small", "small", "small", "small", "small", "small"]
# Selbst gewählte Benutzernamen; leer = Ersatzname wie "Spieler 2".
var player_names: Array[String] = ["", "", "", "", "", ""]
# Gewählte Nahkampfwaffe pro Slot (Schlüssel aus MELEE_WEAPONS).
var player_melee_weapons: Array[String] = ["iron", "iron", "iron", "iron", "iron", "iron"]
var player_wand_tip_colors: Array[Color] = [
	Color(1.0, 0.4, 0.2, 1.0),
	Color(1.0, 0.9, 0.2, 1.0),
	Color(0.4, 0.9, 0.3, 1.0),
	Color(0.6, 0.4, 1.0, 1.0),
	Color(1.0, 0.3, 0.5, 1.0),
	Color(0.3, 0.9, 0.7, 1.0),
]
var player_shot_colors: Array[Color] = [
	Color(1.0, 0.4, 0.2, 1.0),
	Color(1.0, 0.9, 0.2, 1.0),
	Color(0.4, 0.9, 0.3, 1.0),
	Color(0.6, 0.4, 1.0, 1.0),
	Color(1.0, 0.3, 0.5, 1.0),
	Color(0.3, 0.9, 0.7, 1.0),
]

# --- Lobby / Session (multiplayer-ready) ---
var host_player_index: int = 1
var local_player_index: int = 1
var player_ready: Dictionary = {1: false, 2: true, 3: true, 4: true, 5: true, 6: true}

# --- Netzwerk ---
var network_mode: bool = false
var remote_connected: bool = false
var network_info: String = ""
var is_spectator: bool = false

var heroes: Dictionary = {}

# --- Abwärtskompatible Kurzschreibweisen für Spieler 1 und 2 ---
var p1_hero_id: String:
	get:
		return player_hero_ids[0]
	set(value):
		player_hero_ids[0] = value

var p2_hero_id: String:
	get:
		return player_hero_ids[1]
	set(value):
		player_hero_ids[1] = value

var p1_score: int:
	get:
		return player_scores[0]
	set(value):
		player_scores[0] = value

var p2_score: int:
	get:
		return player_scores[1]
	set(value):
		player_scores[1] = value

var p1_cards: Array:
	get:
		return player_cards[0]

var p2_cards: Array:
	get:
		return player_cards[1]

var is_bot_enabled: bool:
	get:
		return player_kind[1] == PlayerKind.BOT
	set(value):
		player_kind[1] = PlayerKind.BOT if value else PlayerKind.HUMAN

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled_level_modifiers = LevelModifierDefsClass.default_ids()
	_setup_heroes()
	_setup_default_inputs()
	reset_lobby_state()
	_load_lobby_loadouts()
	_restore_last_lobby_settings()
	_setup_lobby_settings_autosave()
	_load_character_customization()

# Versionierung wie bei Karten: Ändert sich ein Basiswert (HP, Schild, Tempo,
# Sprung, Munition, Feuerintervall, Nachladen) oder das Passiv eines Helden,
# `x.version` um 1 erhöhen. Ändert sich die aktive Fähigkeit (Konstanten in
# player.gd oder ability_cooldown), `x.ability_version` um 1 erhöhen.
func _setup_heroes() -> void:
	# 1. Ignis
	var ignis = HeroData.new()
	ignis.id = "ignis"
	ignis.name = "Ignis"
	ignis.role = "Pyro Skirmisher"
	ignis.description = "Explosiv und wendig."
	ignis.passive_desc = "Afterburner: Dash hinterlässt eine Feuerspur (%.0f s). Gegner darin brennen: %d × %d Schaden alle %.1f s." % [
		Player.AFTERBURNER_ZONE_DURATION, Player.AFTERBURNER_BURN_STACKS,
		int(Player.AFTERBURNER_BURN_DAMAGE), Player.BURN_TICK_INTERVAL,
	]
	ignis.ability_name = "Rocket Leap"
	ignis.ability_desc = "Explosiver Sprung nach vorn mit AOE-Rückstoß!"
	ignis.ability_cooldown = 5.0
	ignis.base_hp = 100
	ignis.base_shield = 0
	ignis.base_speed = 310.0
	ignis.base_jump_force = -510.0
	ignis.base_ammo = 3
	ignis.base_fire_rate_cooldown = 0.22
	ignis.base_reload_time = 1.2
	ignis.color_tint = Color(1.0, 0.4, 0.2)
	ignis.sprite_tile_name = "tile_0000.png"
	ignis.version = 2
	ignis.ability_version = 1
	heroes["ignis"] = ignis

	# 2. Volt
	var volt = HeroData.new()
	volt.id = "volt"
	volt.name = "Volt"
	volt.role = "Hyper Speedster"
	volt.description = "Extrem schnell und mobil."
	volt.passive_desc = "Overcharge: Standardmäßig Doppelsprung aktiv"
	volt.ability_name = "Flash Blink"
	volt.ability_desc = "Sofortiger Teleport-Dash in Zielrichtung!"
	volt.ability_cooldown = 4.5
	volt.base_hp = 85
	volt.base_shield = 0
	volt.base_speed = 350.0
	volt.base_jump_force = -520.0
	volt.extra_jumps = 1
	volt.base_ammo = 4
	volt.base_fire_rate_cooldown = 0.17
	volt.base_reload_time = 1.4
	volt.color_tint = Color(1.0, 0.9, 0.2)
	volt.sprite_tile_name = "tile_0006.png"
	volt.version = 2
	volt.ability_version = 1
	heroes["volt"] = volt

	# 3. Spore
	var spore = HeroData.new()
	spore.id = "spore"
	spore.name = "Spore"
	spore.role = "Toxic Alchemist"
	spore.description = "Zermürbt Feinde mit ätzenden Giften."
	spore.passive_desc = "Spore Coat: Treffer vergiften Gegner (2 Stapel à 4 Schaden, alle 0,8 s = 8 Schaden)"
	spore.ability_name = "Spore Burst"
	spore.ability_desc = "Hinterlässt eine giftige Gaswolke!"
	spore.ability_cooldown = 6.0
	spore.base_hp = 105
	spore.base_shield = 10
	spore.base_speed = 295.0
	spore.base_jump_force = -500.0
	spore.base_ammo = 3
	spore.base_fire_rate_cooldown = 0.28
	spore.base_reload_time = 1.05
	spore.color_tint = Color(0.4, 0.9, 0.3)
	spore.sprite_tile_name = "tile_0002.png"
	spore.version = 2
	spore.ability_version = 1
	heroes["spore"] = spore

	# 4. Nova – Gravitationsmagier
	var nova = HeroData.new()
	nova.id = "nova"
	nova.name = "Nova"
	nova.role = "Gravity Mage"
	nova.description = "Kontrolliert den Raum und zieht Gegner in ihr Verderben."
	nova.passive_desc = "Schwerelos: Höchste Sprungkraft (540)"
	nova.ability_name = "Singularität"
	nova.ability_desc = "Erzeugt einen Gravitationskern, der Gegner in die Mitte zieht!"
	nova.ability_cooldown = 6.5
	nova.base_hp = 95
	nova.base_shield = 10
	nova.base_speed = 290.0
	nova.base_jump_force = -540.0
	nova.base_ammo = 3
	nova.base_fire_rate_cooldown = 0.30
	nova.base_reload_time = 1.35
	nova.color_tint = Color(0.6, 0.4, 1.0)
	nova.sprite_tile_name = "tile_0003.png"
	nova.version = 2
	nova.ability_version = 1
	heroes["nova"] = nova

	# 5. Klinge – Klingentänzer
	var klinge = HeroData.new()
	klinge.id = "klinge"
	klinge.name = "Klinge"
	klinge.role = "Blade Dancer"
	klinge.description = "Schneidet sich nah am Gegner durch die Arena."
	klinge.passive_desc = "Klingentanz: 15 Start-Schild und hohe Grundgeschwindigkeit"
	klinge.ability_name = "Klingensturm"
	klinge.ability_desc = "Wirbelt herum und verletzt alle Gegner in der Nähe mit Rückstoß!"
	klinge.ability_cooldown = 5.5
	klinge.base_hp = 110
	klinge.base_shield = 15
	klinge.base_speed = 315.0
	klinge.base_jump_force = -505.0
	klinge.base_ammo = 4
	klinge.base_fire_rate_cooldown = 0.20
	klinge.base_reload_time = 1.25
	klinge.color_tint = Color(1.0, 0.3, 0.5)
	klinge.sprite_tile_name = "tile_0005.png"
	klinge.version = 2
	klinge.ability_version = 1
	heroes["klinge"] = klinge

	# 6. Bastion – Feldtechniker
	var bastion = HeroData.new()
	bastion.id = "bastion"
	bastion.name = "Bastion"
	bastion.role = "Field Engineer"
	bastion.description = "Robuster Unterstützer mit Schildtechnik."
	bastion.passive_desc = "Aurora: Doppelte Schild-Regeneration (30 statt 15 Schild/s, startet 3 s nach dem letzten Treffer)"
	bastion.ability_name = "Heilfeld"
	bastion.ability_desc = "Errichtet ein Feld, das dich über Zeit heilt und Schild aufbaut!"
	bastion.ability_cooldown = 8.0
	bastion.base_hp = 125
	bastion.base_shield = 20
	bastion.base_speed = 270.0
	bastion.base_jump_force = -490.0
	bastion.base_ammo = 3
	bastion.base_fire_rate_cooldown = 0.30
	bastion.base_reload_time = 1.45
	bastion.color_tint = Color(0.3, 0.9, 0.7)
	bastion.sprite_tile_name = "tile_0001.png"
	bastion.version = 2
	bastion.ability_version = 1
	heroes["bastion"] = bastion

	# 7. Phantom – Schattenassassine
	var phantom = HeroData.new()
	phantom.id = "phantom"
	phantom.name = "Phantom"
	phantom.role = "Shadow Assassin"
	phantom.description = "Blitzschnelle Überraschungsangriffe aus dem Nichts."
	phantom.passive_desc = "Nachtwind: Sehr hohes Grundtempo (325) und schnellstes Feuerintervall (0,14 s)"
	phantom.ability_name = "Schattensprung"
	phantom.ability_desc = "Teleportiert in Zielrichtung, wird kurz unverwundbar und schlägt zu!"
	phantom.ability_cooldown = 5.0
	phantom.base_hp = 90
	phantom.base_shield = 5
	phantom.base_speed = 325.0
	phantom.base_jump_force = -515.0
	phantom.base_ammo = 2
	phantom.base_fire_rate_cooldown = 0.14
	phantom.base_reload_time = 1.05
	phantom.color_tint = Color(0.45, 0.45, 0.6)
	phantom.sprite_tile_name = "tile_0007.png"
	phantom.version = 2
	phantom.ability_version = 1
	heroes["phantom"] = phantom

func get_hero(id: String) -> HeroData:
	return heroes.get(id, heroes["ignis"])

# Ausführliche Werte der Heldenfähigkeit (Schaden, Radius, Dauer usw.).
# Die Zahlen stammen aus den Konstanten in player.gd; Schaden, der vom
# Schussschaden abhängt, wird mit dem aktuellen Basis-Schaden berechnet.
# Kartenboni sind darin nicht enthalten.
func get_hero_ability_details(hero: HeroData) -> String:
	match hero.id:
		"ignis":
			return "Fliegt %.2f s lang mit Tempo %d in Zielrichtung (ca. %d px) und ist dabei unverwundbar. Beim Aufprall: Explosion mit Radius %d px, bis zu %d Schaden (nimmt zum Rand hin ab) und starker Rückstoß." % [
				Player.ROCKET_LEAP_DURATION, int(Player.ROCKET_LEAP_SPEED),
				int(Player.ROCKET_LEAP_SPEED * Player.ROCKET_LEAP_DURATION),
				int(Player.ROCKET_IMPACT_RADIUS), int(Player.ROCKET_IMPACT_DAMAGE),
			]
		"volt":
			return "Teleport %d px in Zielrichtung. Schockwelle am Ziel: Radius %d px, %d Schaden und verlangsamt Gegner %.1f s lang um %d%%." % [
				int(Player.FLASH_BLINK_DISTANCE), int(Player.FLASH_BLINK_RADIUS),
				int(Player.FLASH_BLINK_DAMAGE), Player.FLASH_BLINK_FREEZE,
				int(round((1.0 - Player.FREEZE_SPEED_MULT) * 100.0)),
			]
		"spore":
			return "Giftwolke an deiner Position: Radius %d px, %.1f s lang %d Schaden pro Sekunde (bis zu %d Schaden gesamt)." % [
				int(Player.SPORE_CLOUD_RADIUS), Player.SPORE_CLOUD_DURATION,
				int(Player.SPORE_CLOUD_DPS),
				int(Player.SPORE_CLOUD_DPS * Player.SPORE_CLOUD_DURATION),
			]
		"nova":
			return "Gravitationskern %d px vor dir, %.1f s aktiv. Zieht alle Gegner im Radius %d px stark in die Mitte, hält sie im Kern fest und schwächt ihre Laufkontrolle. Macht selbst keinen Schaden." % [
				int(Player.SINGULARITY_DISTANCE), Player.SINGULARITY_DURATION,
				int(Player.SINGULARITY_PULL_RADIUS),
			]
		"klinge":
			return "Rundumschlag im Radius %d px: %d Schaden (%d%% des Schussschadens) mit starkem Rückstoß. %.1f s unverwundbar." % [
				int(Player.BLADE_STORM_RADIUS),
				int(round(base_damage * Player.BLADE_STORM_DAMAGE_MULT)),
				int(round(Player.BLADE_STORM_DAMAGE_MULT * 100.0)),
				Player.BLADE_STORM_INVULN,
			]
		"bastion":
			var ticks := int(ceil(Player.HEAL_FIELD_DURATION / Player.HEAL_FIELD_TICK_INTERVAL))
			return "%.0f s lang: +%d HP pro Sekunde (%d HP gesamt) und +%d Schild pro Sekunde (bis zum Maximum)." % [
				Player.HEAL_FIELD_DURATION,
				int(round(Player.HEAL_FIELD_TICK_HEAL / Player.HEAL_FIELD_TICK_INTERVAL)),
				int(Player.HEAL_FIELD_TICK_HEAL * ticks),
				int(round(Player.HEAL_FIELD_TICK_SHIELD / Player.HEAL_FIELD_TICK_INTERVAL)),
			]
		"phantom":
			return "Teleport %d px in Zielrichtung, danach %.1f s unverwundbar. Am Ziel: Radius %d px, %d Schaden (%d%% des Schussschadens) mit Rückstoß." % [
				int(Player.SHADOW_STEP_DISTANCE), Player.SHADOW_STEP_INVULN,
				int(Player.SHADOW_STEP_RADIUS),
				int(round(base_damage * Player.SHADOW_STEP_DAMAGE_MULT)),
				int(round(Player.SHADOW_STEP_DAMAGE_MULT * 100.0)),
			]
	return hero.ability_desc

func _setup_default_inputs() -> void:
	_ensure_key_action("p1_left", KEY_A)
	_ensure_key_action("p1_right", KEY_D)
	_ensure_key_action("p1_up", KEY_W)
	_ensure_key_action("p1_down", KEY_S)
	_ensure_key_action("p1_jump", KEY_SPACE)
	_ensure_key_action("p1_dash", KEY_SHIFT)
	_ensure_mouse_action("p1_shoot", MOUSE_BUTTON_LEFT)
	_ensure_mouse_action("p1_ability", MOUSE_BUTTON_RIGHT)
	# Universeller Block für alle Spieler.
	_ensure_key_action("p1_block", KEY_Q)
	# Manuelles Nachladen.
	_ensure_key_action("p1_reload", KEY_R)
	# Nahkampfwaffe aus dem Charakter-Tab.
	_ensure_key_action("p1_melee", KEY_E)

	# P2 bindings (Keyboard fallback for local 2-player)
	_ensure_key_action("p2_left", KEY_LEFT)
	_ensure_key_action("p2_right", KEY_RIGHT)
	_ensure_key_action("p2_up", KEY_UP)
	_ensure_key_action("p2_down", KEY_DOWN)
	_ensure_key_action("p2_jump", KEY_UP)
	_ensure_key_action("p2_dash", KEY_SLASH) # Shift or slash
	_ensure_key_action("p2_shoot", KEY_PERIOD)
	_ensure_key_action("p2_ability", KEY_COMMA)
	_ensure_key_action("p2_block", KEY_M)
	_ensure_key_action("p2_reload", KEY_L)
	_ensure_key_action("p2_melee", KEY_K)

	# Utility
	_ensure_key_action("restart_game", KEY_F9)

func _ensure_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _ensure_mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

# ============================================================
# Spieler-Slots
# ============================================================

func get_pig_appearance(index: int) -> Dictionary:
	var slot := clampi(index, 1, MAX_PLAYERS)
	return {
		"fur": player_pig_fur_colors[slot - 1],
		"eyes": player_pig_eye_colors[slot - 1],
		"pants": player_pig_pants_colors[slot - 1],
		"wand_tip_shape": player_wand_tip_shapes[slot - 1],
		"tusk_shape": player_tusk_shapes[slot - 1],
		"wand_tip_color": player_wand_tip_colors[slot - 1],
		"shot_color": player_shot_colors[slot - 1],
	}

func normalize_wand_tip_shape(shape: String) -> String:
	return shape if WAND_TIP_SHAPES.has(shape) else "orb"

func get_wand_tip_shape_label(shape: String) -> String:
	return str(WAND_TIP_SHAPE_LABELS.get(shape, shape.capitalize()))

func normalize_tusk_shape(shape: String) -> String:
	return shape if TUSK_SHAPES.has(shape) else "small"

func get_tusk_shape_label(shape: String) -> String:
	return str(TUSK_SHAPE_LABELS.get(shape, shape.capitalize()))

func normalize_melee_weapon(weapon_id: String) -> String:
	return weapon_id if MELEE_WEAPONS.has(weapon_id) else "iron"

func get_melee_weapon(index: int) -> String:
	if index < 1 or index > MAX_PLAYERS:
		return "iron"
	return player_melee_weapons[index - 1]

func get_melee_weapon_data(weapon_id: String) -> Dictionary:
	return MELEE_WEAPON_DATA[normalize_melee_weapon(weapon_id)]

func get_melee_weapon_label(weapon_id: String) -> String:
	return str(get_melee_weapon_data(weapon_id)["label"])

func get_melee_weapon_version(weapon_id: String) -> int:
	return int(get_melee_weapon_data(weapon_id).get("version", 1))

# Fingerabdruck der Balance-Werte (ohne label/desc/version). Ändert er sich
# ohne neue version, warnt die Statistik.
func get_melee_weapon_fingerprint(weapon_id: String) -> String:
	var data := get_melee_weapon_data(weapon_id)
	var parts: PackedStringArray = []
	for key in data.keys():
		if key in ["label", "desc", "version"]:
			continue
		parts.append("%s=%s" % [key, var_to_str(data[key])])
	parts.sort()
	return ";".join(parts).md5_text().substr(0, 8)

# Kurzer Werteblock für den Charakter-Tab.
func get_melee_weapon_stats_text(weapon_id: String) -> String:
	var data := get_melee_weapon_data(weapon_id)
	var arc := float(data["arc_deg"])
	var arc_text := "Stich" if arc <= 0.0 else ("360°" if arc >= 360.0 else "%d°-Bogen" % int(arc))
	var text := "%d Schaden · %s · %d %s Reichweite · %.1f s Abklingzeit" % [
		int(data["damage"]), arc_text, int(data["range_tiles"]),
		"Feld" if int(data["range_tiles"]) == 1 else "Felder", float(data["cooldown"]),
	]
	if float(data["wall_stun"]) > 0.0:
		text += " · %.1f s Wand-Betäubung" % float(data["wall_stun"])
	return text

func set_melee_weapon(index: int, weapon_id: String) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	var clean := normalize_melee_weapon(weapon_id)
	if player_melee_weapons[index - 1] == clean:
		return
	player_melee_weapons[index - 1] = clean
	if index == local_player_index:
		save_character_customization(index)
	lobby_state_changed.emit()

func _random_melee_weapon() -> String:
	return MELEE_WEAPONS[randi() % MELEE_WEAPONS.size()]

# Bots bekommen zu jedem Match eine zufällige Nahkampfwaffe (nur Host/Offline,
# Clients erhalten sie über den Lobby-Sync).
func randomize_bot_melee_weapons() -> void:
	var changed := false
	for i in range(1, MAX_PLAYERS + 1):
		if get_player_kind(i) == PlayerKind.BOT:
			player_melee_weapons[i - 1] = _random_melee_weapon()
			changed = true
	if changed:
		lobby_state_changed.emit()

func sanitize_player_name(raw: String) -> String:
	var clean := raw.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	return clean.substr(0, PLAYER_NAME_MAX_LENGTH)

# Nur der selbst eingegebene Name (kann leer sein).
func get_custom_player_name(index: int) -> String:
	if index < 1 or index > MAX_PLAYERS or is_bot_slot(index):
		return ""
	return player_names[index - 1]

# Anzeigename: eingegebener Benutzername oder Ersatz wie "Spieler 2" / "Bot 3".
func get_player_name(index: int) -> String:
	var custom := get_custom_player_name(index)
	if not custom.is_empty():
		return custom
	return ("Bot %d" if is_bot_slot(index) else "Spieler %d") % index

func set_player_name(index: int, value: String) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	var clean := sanitize_player_name(value)
	if player_names[index - 1] == clean:
		return
	player_names[index - 1] = clean
	if index == local_player_index:
		save_character_customization(index)
	lobby_state_changed.emit()

func set_pig_appearance(
		index: int,
		fur: Color,
		eyes: Color,
		pants: Color,
		wand_tip_shape: String = "",
		wand_tip_color: Color = Color(0, 0, 0, 0),
		shot_color: Color = Color(0, 0, 0, 0),
		tusk_shape: String = ""
	) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	var next_shape: String = player_wand_tip_shapes[index - 1]
	if not wand_tip_shape.is_empty():
		next_shape = normalize_wand_tip_shape(wand_tip_shape)
	var next_tip_color := wand_tip_color if wand_tip_color.a > 0.0 else player_wand_tip_colors[index - 1]
	var next_shot_color := shot_color if shot_color.a > 0.0 else player_shot_colors[index - 1]
	var next_tusk: String = player_tusk_shapes[index - 1]
	if not tusk_shape.is_empty():
		next_tusk = normalize_tusk_shape(tusk_shape)
	if player_pig_fur_colors[index - 1] == fur \
			and player_pig_eye_colors[index - 1] == eyes \
			and player_pig_pants_colors[index - 1] == pants \
			and player_wand_tip_shapes[index - 1] == next_shape \
			and player_wand_tip_colors[index - 1] == next_tip_color \
			and player_shot_colors[index - 1] == next_shot_color \
			and player_tusk_shapes[index - 1] == next_tusk:
		return
	player_pig_fur_colors[index - 1] = fur
	player_pig_eye_colors[index - 1] = eyes
	player_pig_pants_colors[index - 1] = pants
	player_wand_tip_shapes[index - 1] = next_shape
	player_wand_tip_colors[index - 1] = next_tip_color
	player_shot_colors[index - 1] = next_shot_color
	player_tusk_shapes[index - 1] = next_tusk
	pig_appearance_changed.emit(index)
	# Die Anpassung des lokalen Nutzers wird ohne separaten Speichern-Knopf
	# direkt in sein Profil geschrieben.
	if index == local_player_index:
		save_character_customization(index)

func reset_pig_appearance(index: int) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	set_pig_appearance(
		index,
		default_pig_fur_colors[index - 1],
		PIG_DEFAULT_EYE_COLOR,
		PIG_DEFAULT_PANTS_COLOR,
		"orb",
		default_wand_tip_colors[index - 1],
		default_wand_tip_colors[index - 1],
		"small"
	)

func apply_saved_character_customization(index: int) -> void:
	if user_character_customization.is_empty() or index < 1 or index > MAX_PLAYERS:
		return
	var look := user_character_customization
	set_pig_appearance(
		index,
		look["fur"],
		look["eyes"],
		look["pants"],
		look["wand_tip_shape"],
		look["wand_tip_color"],
		look["shot_color"],
		str(look.get("tusk_shape", "small"))
	)
	if look.has("name"):
		set_player_name(index, str(look["name"]))
	if look.has("melee_weapon"):
		set_melee_weapon(index, str(look["melee_weapon"]))

func save_character_customization(index: int = -1) -> bool:
	var slot := local_player_index if index < 0 else index
	if slot < 1 or slot > MAX_PLAYERS:
		return false
	var look := get_pig_appearance(slot)
	user_character_customization = look.duplicate(true)
	user_character_customization["name"] = player_names[slot - 1]
	user_character_customization["melee_weapon"] = player_melee_weapons[slot - 1]
	var payload := {
		"version": 1,
		"player_name": player_names[slot - 1],
		"melee_weapon": player_melee_weapons[slot - 1],
		"appearance": {
			"fur": _color_to_json(look["fur"]),
			"eyes": _color_to_json(look["eyes"]),
			"pants": _color_to_json(look["pants"]),
			"wand_tip_shape": look["wand_tip_shape"],
			"tusk_shape": look["tusk_shape"],
			"wand_tip_color": _color_to_json(look["wand_tip_color"]),
			"shot_color": _color_to_json(look["shot_color"]),
		},
	}
	var file := FileAccess.open(CHARACTER_CUSTOMIZATION_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t", false))
	file.close()
	return true

func _load_character_customization() -> void:
	user_character_customization.clear()
	if not FileAccess.file_exists(CHARACTER_CUSTOMIZATION_PATH):
		return
	var file := FileAccess.open(CHARACTER_CUSTOMIZATION_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var raw: Variant = parsed.get("appearance", {})
	if not (raw is Dictionary):
		return
	var look := _normalize_saved_appearance(raw)
	if look.is_empty():
		return
	look["name"] = sanitize_player_name(str(parsed.get("player_name", "")))
	look["melee_weapon"] = normalize_melee_weapon(str(parsed.get("melee_weapon", "iron")))
	user_character_customization = look
	apply_saved_character_customization(local_player_index)

func _normalize_saved_appearance(raw: Dictionary) -> Dictionary:
	if not (raw.get("fur") is Array and raw.get("eyes") is Array and raw.get("pants") is Array):
		return {}
	var shape := normalize_wand_tip_shape(str(raw.get("wand_tip_shape", "orb")))
	return {
		"fur": _color_from_json(raw.get("fur"), default_pig_fur_colors[0]),
		"eyes": _color_from_json(raw.get("eyes"), PIG_DEFAULT_EYE_COLOR),
		"pants": _color_from_json(raw.get("pants"), PIG_DEFAULT_PANTS_COLOR),
		"wand_tip_shape": shape,
		"tusk_shape": normalize_tusk_shape(str(raw.get("tusk_shape", "small"))),
		"wand_tip_color": _color_from_json(raw.get("wand_tip_color"), default_wand_tip_colors[0]),
		"shot_color": _color_from_json(raw.get("shot_color"), default_wand_tip_colors[0]),
	}

func _color_to_json(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]

func _color_from_json(value: Variant, fallback: Color) -> Color:
	if value is Array and value.size() >= 3:
		var alpha := float(value[3]) if value.size() > 3 else 1.0
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	return fallback

func get_player_hero_id(index: int) -> String:
	if index < 1 or index > MAX_PLAYERS:
		return "ignis"
	return player_hero_ids[index - 1]

func set_player_hero(index: int, hero_id: String) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	if not heroes.has(hero_id):
		return
	if player_hero_ids[index - 1] == hero_id:
		return
	player_hero_ids[index - 1] = hero_id
	lobby_state_changed.emit()

func get_player_kind(index: int) -> int:
	if index < 1 or index > MAX_PLAYERS:
		return PlayerKind.OFF
	return player_kind[index - 1]

func set_player_kind(index: int, kind: int) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	if index == 1 and kind == PlayerKind.OFF:
		return
	if player_kind[index - 1] == kind:
		return
	player_kind[index - 1] = kind
	if kind == PlayerKind.BOT:
		player_ready[index] = true
		player_melee_weapons[index - 1] = _random_melee_weapon()
	elif kind == PlayerKind.HUMAN:
		player_ready[index] = false
	lobby_state_changed.emit()

func is_active_slot(index: int) -> bool:
	return index >= 1 and index <= player_count and player_kind[index - 1] != PlayerKind.OFF

func is_bot_slot(index: int) -> bool:
	return get_player_kind(index) == PlayerKind.BOT

func is_human_slot(index: int) -> bool:
	return get_player_kind(index) == PlayerKind.HUMAN

func get_active_player_indices() -> Array[int]:
	var result: Array[int] = []
	for i in range(1, player_count + 1):
		if is_active_slot(i):
			result.append(i)
	return result

func get_active_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	for i in get_active_player_indices():
		ids.append(get_player_hero_id(i))
	return ids

func set_match_mode(mode: String) -> void:
	var resolved := mode if MATCH_MODES.has(mode) else MATCH_MODE_FFA
	if match_mode == resolved:
		return
	match_mode = resolved
	match_mode_changed.emit(match_mode)

func get_match_mode_name(mode: String = "") -> String:
	var resolved := mode if not mode.is_empty() else match_mode
	if not MATCH_MODES.has(resolved):
		return "FFA"
	return str(MATCH_MODES[resolved].get("name", "FFA"))

func get_match_mode_description(mode: String = "") -> String:
	var resolved := mode if not mode.is_empty() else match_mode
	if not MATCH_MODES.has(resolved):
		return ""
	return str(MATCH_MODES[resolved].get("description", ""))

func get_mode_required_players(mode: String = "") -> int:
	var resolved := mode if not mode.is_empty() else match_mode
	if not MATCH_MODES.has(resolved):
		return 0
	return int(MATCH_MODES[resolved].get("players", 0))

func is_team_mode(mode: String = "") -> bool:
	var resolved := mode if not mode.is_empty() else match_mode
	return resolved != MATCH_MODE_FFA and MATCH_MODES.has(resolved)

func get_team_count() -> int:
	if not is_team_mode():
		return player_count
	match match_mode:
		MATCH_MODE_2V2:
			return 2
		MATCH_MODE_3V3:
			return 2
		MATCH_MODE_2V2V2:
			return 3
		_:
			return player_count

func get_team_for_slot(slot: int) -> int:
	if slot < 1 or slot > MAX_PLAYERS:
		return 0
	if not is_team_mode():
		return slot
	var per_team := 2
	if match_mode == MATCH_MODE_3V3:
		per_team = 3
	return int(floor(float(slot - 1) / float(per_team))) + 1

func get_team_members(team: int) -> Array[int]:
	var members: Array[int] = []
	for i in get_active_player_indices():
		if get_team_for_slot(i) == team:
			members.append(i)
	return members

func get_team_score(team: int) -> int:
	var total := 0
	for i in get_team_members(team):
		total += player_scores[i - 1]
	return total

func get_team_score_for_slot(slot: int) -> int:
	if slot < 1 or slot > MAX_PLAYERS:
		return 0
	if not is_team_mode():
		return player_scores[slot - 1]
	return get_team_score(get_team_for_slot(slot))

func get_team_name(team: int) -> String:
	if not is_team_mode():
		return "P%d" % team
	if team < 1 or team > TEAM_NAMES.size():
		return "TEAM %d" % team
	return TEAM_NAMES[team - 1]

func get_team_color(team: int) -> Color:
	if team < 1 or team > TEAM_COLORS.size():
		return Color.WHITE
	return TEAM_COLORS[team - 1]

func set_player_count(count: int) -> void:
	var clamped := clampi(count, MIN_PLAYERS, MAX_PLAYERS)
	if player_count == clamped:
		return
	player_count = clamped
	for i in range(1, MAX_PLAYERS + 1):
		if i <= player_count:
			if player_kind[i - 1] == PlayerKind.OFF:
				player_kind[i - 1] = PlayerKind.BOT if i > 1 else PlayerKind.HUMAN
				if i > 1:
					player_ready[i] = true
		else:
			if player_kind[i - 1] != PlayerKind.OFF:
				player_kind[i - 1] = PlayerKind.OFF
				player_ready[i] = false
	player_count_changed.emit(player_count)
	lobby_state_changed.emit()

func get_scores() -> Array:
	var result: Array = []
	for i in range(player_count):
		result.append(player_scores[i])
	return result

func reset_match() -> void:
	for i in range(MAX_PLAYERS):
		player_scores[i] = 0
		if player_cards[i] is Array:
			player_cards[i].clear()
	reset_match_stats()
	tiebreak_slots.clear()
	match_end_reason = ""
	current_state = GameState.PLAYING
	scores_changed.emit(get_scores())
	match_reset.emit()

func _empty_match_stats() -> Dictionary:
	var stats := {}
	for key in MATCH_STAT_KEYS:
		stats[key] = 0.0
	return stats

func reset_match_stats() -> void:
	match_stats.clear()
	for _i in range(MAX_PLAYERS):
		match_stats.append(_empty_match_stats())

func _ensure_match_stats() -> void:
	while match_stats.size() < MAX_PLAYERS:
		match_stats.append(_empty_match_stats())
	for i in range(match_stats.size()):
		if not match_stats[i] is Dictionary:
			match_stats[i] = _empty_match_stats()

func add_match_stat(player_index: int, key: String, amount: float = 1.0) -> void:
	if player_index < 1 or player_index > MAX_PLAYERS:
		return
	if not MATCH_STAT_KEYS.has(key):
		return
	_ensure_match_stats()
	var stats: Dictionary = match_stats[player_index - 1]
	stats[key] = float(stats.get(key, 0.0)) + amount
	match_stats[player_index - 1] = stats

func get_match_stat(player_index: int, key: String) -> float:
	if player_index < 1 or player_index > MAX_PLAYERS:
		return 0.0
	_ensure_match_stats()
	var stats: Dictionary = match_stats[player_index - 1]
	return float(stats.get(key, 0.0))

func get_match_stats() -> Array:
	_ensure_match_stats()
	return match_stats.duplicate(true)

func set_match_stats(stats: Array) -> void:
	reset_match_stats()
	_ensure_match_stats()
	for i in range(mini(stats.size(), MAX_PLAYERS)):
		if not stats[i] is Dictionary:
			continue
		var merged: Dictionary = _empty_match_stats()
		merged.merge(stats[i], true)
		match_stats[i] = merged

func get_match_mvp_index() -> int:
	_ensure_match_stats()
	var best_index := 0
	var best_value := -INF
	for i in get_active_player_indices():
		var stats: Dictionary = match_stats[i - 1]
		var value := float(player_scores[i - 1]) * 2.0
		value += float(stats.get("kills", 0.0)) * 120.0
		value += float(stats.get("damage_dealt", 0.0)) * 0.6
		value += float(stats.get("damage_blocked", 0.0)) * 0.5
		value += float(stats.get("healing_done", 0.0)) * 0.4
		value += float(stats.get("rounds_won", 0.0)) * 80.0
		value -= float(stats.get("deaths", 0.0)) * 30.0
		if value > best_value:
			best_value = value
			best_index = i
	return best_index

func get_match_stat_leader(key: String) -> int:
	_ensure_match_stats()
	var best_index := 0
	var best_value := 0.0
	for i in get_active_player_indices():
		var value := get_match_stat(i, key)
		if value > best_value:
			best_value = value
			best_index = i
	return best_index

func shake_camera(amount: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.has_method("shake"):
		cam.shake(amount)

func award_kill(killer_index: int, victim_index: int = 0) -> void:
	if current_state != GameState.PLAYING:
		return
	if killer_index < 1 or killer_index > MAX_PLAYERS:
		return
	if killer_index == victim_index:
		return
	if victim_index >= 1 and is_team_mode() and get_team_for_slot(killer_index) == get_team_for_slot(victim_index):
		return
	player_scores[killer_index - 1] += kill_points
	scores_changed.emit(get_scores())

func award_round(winner_index: int, award_survival: bool = true) -> void:
	if winner_index < 1 or winner_index > MAX_PLAYERS:
		return
	var scoring_members: Array[int] = [winner_index]
	if is_team_mode():
		scoring_members = get_team_members(get_team_for_slot(winner_index))
	# Im Team-Modus werden die Siegpunkte auf das Team aufgeteilt, statt dass
	# jedes Mitglied die vollen Punkte bekommt. Der Rest beim Teilen geht an
	# den Rundensieger, damit das Team genau survival_points erhält.
	if scoring_members.is_empty():
		scoring_members = [winner_index]
	var share := floori(float(survival_points) / float(scoring_members.size()))
	var remainder := survival_points - share * scoring_members.size()
	for member in scoring_members:
		add_match_stat(member, "rounds_won", 1.0)
		if award_survival:
			player_scores[member - 1] += share + (remainder if member == winner_index else 0)
	scores_changed.emit(get_scores())

	# Stechen läuft: Wer die Runde mit Überlebenden gewinnt, gewinnt das Match.
	# Ein Doppel-KO entscheidet nichts, dann wird erneut gestochen.
	if not tiebreak_slots.is_empty():
		if award_survival and tiebreak_slots.has(winner_index):
			_finish_match(winner_index, "tiebreak")
		else:
			_start_tiebreak(tiebreak_slots.duplicate())
		return

	# Nicht nur der Rundensieger kann durch Kills die Zielpunktzahl erreicht
	# haben. Im Team-Modus zählt die Summe des Teams, in FFA der Spieler.
	# Erreichen mehrere Spieler/Teams das Ziel in derselben Runde, entscheidet
	# ein Stechen nur unter ihnen.
	var finalists := _slots_at_target()
	if _score_group_count(finalists) > 1:
		_start_tiebreak(finalists)
	elif not finalists.is_empty():
		_finish_match(_points_leader(winner_index), "")
	else:
		current_state = GameState.CARD_DRAFT
		round_ended.emit(winner_index)

func _finish_match(winner_index: int, reason: String) -> void:
	tiebreak_slots.clear()
	match_end_reason = reason
	current_state = GameState.GAME_OVER
	match_over.emit(winner_index)

func _start_tiebreak(slots: Array) -> void:
	set_tiebreak_slots(slots)
	current_state = GameState.CARD_DRAFT
	tiebreak_started.emit(tiebreak_slots.duplicate())

# Vorzeitiges Match-Ende (ESC → Hauptmenü, Verbindungsabbruch). winner 0 = Unentschieden.
func end_match_early(winner_index: int) -> void:
	_finish_match(winner_index, "early")

func is_tiebreak() -> bool:
	return not tiebreak_slots.is_empty()

func set_tiebreak_slots(slots: Array) -> void:
	tiebreak_slots.clear()
	for slot in slots:
		var i := int(slot)
		if i >= 1 and i <= MAX_PLAYERS and not tiebreak_slots.has(i):
			tiebreak_slots.append(i)

func clear_tiebreak() -> void:
	tiebreak_slots.clear()

# Slots, die in dieser Runde spielen: im Stechen nur die Finalisten.
func get_round_player_indices() -> Array[int]:
	var active := get_active_player_indices()
	if tiebreak_slots.is_empty():
		return active
	var result: Array[int] = []
	for slot in tiebreak_slots:
		if active.has(slot):
			result.append(slot)
	return result if not result.is_empty() else active

# Alle Slots, deren Punkte (Team-Modus: Teamsumme) das Ziel erreicht haben.
func _slots_at_target() -> Array[int]:
	var result: Array[int] = []
	for slot in get_active_player_indices():
		if get_team_score_for_slot(slot) >= points_to_win:
			result.append(slot)
	return result

# Anzahl Parteien unter den Slots: Spieler in FFA, Teams im Team-Modus.
func _score_group_count(slots: Array) -> int:
	if not is_team_mode():
		return slots.size()
	var teams: Array[int] = []
	for slot in slots:
		var team := get_team_for_slot(int(slot))
		if not teams.has(team):
			teams.append(team)
	return teams.size()

# Sieger bei vorzeitigem Ende: meiste Punkte (Team-Modus: Teamsumme).
# Gleichstand an der Spitze ergibt 0 = Unentschieden.
func get_early_end_winner() -> int:
	var best_score := -1
	var best_slots: Array[int] = []
	for slot in get_active_player_indices():
		var score := get_team_score_for_slot(slot)
		if score > best_score:
			best_score = score
			best_slots.clear()
			best_slots.append(slot)
		elif score == best_score:
			best_slots.append(slot)
	if best_slots.is_empty() or _score_group_count(best_slots) > 1:
		return 0
	return _points_leader(best_slots[0])

# Wurde in diesem Match schon etwas entschieden? Sonst lohnt kein Win-Screen.
func has_match_progress() -> bool:
	for slot in get_active_player_indices():
		if player_scores[slot - 1] > 0 or get_match_stat(slot, "rounds_won") > 0.0:
			return true
	return false

func _points_leader(preferred_index: int) -> int:
	if is_team_mode():
		var best_team := get_team_for_slot(preferred_index)
		var best_team_score := get_team_score(best_team)
		for team in range(1, get_team_count() + 1):
			var team_score := get_team_score(team)
			if team_score > best_team_score:
				best_team_score = team_score
				best_team = team
		var best_member := 0
		var best_member_score := -1
		for member in get_team_members(best_team):
			if player_scores[member - 1] > best_member_score:
				best_member_score = player_scores[member - 1]
				best_member = member
		return best_member if best_member > 0 else preferred_index

	var best_index := preferred_index
	var best_score := player_scores[preferred_index - 1]
	for i in get_active_player_indices():
		if player_scores[i - 1] > best_score:
			best_score = player_scores[i - 1]
			best_index = i
	return best_index

func add_card_to_player(player_index: int, card: CardData) -> bool:
	if card == null:
		return false
	if player_index < 1 or player_index > MAX_PLAYERS:
		return false
	# Jede Karte darf pro Spieler nur einmal vorkommen.
	if player_has_card(player_index, card.id):
		return false
	player_cards[player_index - 1].append(card)
	card_selected.emit(player_index, card)
	return true

func get_player_cards(player_index: int) -> Array:
	if player_index < 1 or player_index > MAX_PLAYERS:
		return []
	return player_cards[player_index - 1]

func player_has_card(player_index: int, card_id: String) -> bool:
	for card in get_player_cards(player_index):
		if card.id == card_id:
			return true
	return false

func get_owned_card_ids(player_index: int) -> Array[String]:
	var ids: Array[String] = []
	for card in get_player_cards(player_index):
		ids.append(card.id)
	return ids

func set_base_hp_percent(percent: int) -> void:
	var clamped := clampi(percent, BASE_HP_PERCENT_MIN, BASE_HP_PERCENT_MAX)
	if base_hp_percent == clamped:
		return
	base_hp_percent = clamped
	base_hp_percent_changed.emit(base_hp_percent)

# Effektive Basis-HP eines Helden vor Kartenboni. Der Prozent-Faktor skaliert
# den Heldenwert, statt ihn durch einen einheitlichen Absolutwert zu ersetzen.
func get_effective_base_hp(hero: HeroData) -> int:
	if hero == null:
		return base_hp_percent
	return maxi(1, int(round(float(hero.base_hp) * float(base_hp_percent) / 100.0)))

func set_base_damage(damage: float) -> void:
	var clamped := clampf(damage, 1.0, 200.0)
	if is_equal_approx(base_damage, clamped):
		return
	base_damage = clamped
	base_damage_changed.emit(base_damage)

func get_rarity_percent(rarity: String) -> float:
	return float(rarity_percentages.get(rarity, 0.0))

func get_rarity_percent_total() -> float:
	var total := 0.0
	for rarity in RARITY_ORDER:
		total += maxf(0.0, get_rarity_percent(rarity))
	return total

func set_rarity_percent(rarity: String, value: float) -> void:
	if not RARITY_ORDER.has(rarity):
		return
	var clamped := clampf(value, 0.0, 100.0)
	if is_equal_approx(get_rarity_percent(rarity), clamped):
		return
	rarity_percentages[rarity] = clamped
	rarity_percentages_changed.emit()

func is_card_pool_enabled(pool: String) -> bool:
	return enabled_card_pools.has(pool)

func set_card_pool_enabled(pool: String, enabled: bool) -> void:
	if not CARD_POOLS.has(pool):
		return
	if enabled == enabled_card_pools.has(pool):
		return
	# Mindestens ein Pool muss aktiv bleiben, sonst gäbe es keinen Draft mehr.
	if not enabled and enabled_card_pools.size() <= 1:
		return
	if enabled:
		enabled_card_pools.append(pool)
		_clear_pool_unlocks(pool)
	else:
		enabled_card_pools.erase(pool)
	card_pools_changed.emit()

# Wird ein Pool wieder eingeschaltet, sind seine Einzelfreigaben überflüssig.
# Schaltet man ihn später erneut ab, sind dann wieder alle Karten gesperrt.
func _clear_pool_unlocks(pool: String) -> void:
	var changed := false
	for card_id in pool_unlocked_card_ids.duplicate():
		var card: CardData = CardDatabase.get_card(card_id)
		if card == null or card.pool == pool:
			pool_unlocked_card_ids.erase(card_id)
			changed = true
	if changed:
		banned_cards_changed.emit()

func is_card_pool_unlocked(card: CardData) -> bool:
	if card == null:
		return false
	if pool_unlocked_card_ids.has(card.id):
		return true
	return not card.parent_card_id.is_empty() and pool_unlocked_card_ids.has(card.parent_card_id)

func set_card_pool_unlocked(card_id: String, unlocked: bool) -> void:
	if unlocked == pool_unlocked_card_ids.has(card_id):
		return
	if unlocked:
		pool_unlocked_card_ids.append(card_id)
	else:
		pool_unlocked_card_ids.erase(card_id)
	banned_cards_changed.emit()

func set_pool_unlocked_cards(card_ids: Array) -> void:
	pool_unlocked_card_ids.clear()
	for card_id in card_ids:
		var id := str(card_id)
		if not id.is_empty() and not pool_unlocked_card_ids.has(id):
			pool_unlocked_card_ids.append(id)

# Gesperrt = vom Host gebannt oder Pool aus (ohne Einzelfreigabe).
func is_card_locked(card: CardData) -> bool:
	return card == null or banned_card_ids.has(card.id) or not CardDatabase.is_card_pool_enabled(card)

func set_all_card_pools(enabled: bool) -> void:
	if not enabled:
		return
	var target: Array[String] = CARD_POOLS.duplicate()
	if target == enabled_card_pools:
		return
	enabled_card_pools = target
	if not pool_unlocked_card_ids.is_empty():
		pool_unlocked_card_ids.clear()
		banned_cards_changed.emit()
	card_pools_changed.emit()

# Setzt eine beliebige Pool-Auswahl (z. B. aus dem Netzwerk-Sync). Die Reihenfolge
# folgt immer CARD_POOLS und es bleibt mindestens ein Pool aktiv.
func set_enabled_card_pools(pools: Array) -> void:
	var target: Array[String] = []
	for pool in CARD_POOLS:
		if pools.has(pool):
			target.append(pool)
	if target.is_empty():
		target = CARD_POOLS.duplicate()
	if target == enabled_card_pools:
		return
	enabled_card_pools = target
	card_pools_changed.emit()

func get_map_name(map_id: String) -> String:
	var info: Dictionary = MAPS.get(map_id, {})
	return str(info.get("name", "Unbekannt"))

func get_map_description(map_id: String) -> String:
	if map_id == MAP_RANDOM:
		var enabled_count := get_enabled_map_ids().size()
		if enabled_count == MAP_PLAYABLE.size():
			return "Wählt pro Runde eine der %d Maps." % enabled_count
		if enabled_count == 0:
			return "Alle Levels sind abgeschaltet – im Reiter „Levels“ mindestens eins aktivieren."
		return "Wählt pro Runde eine der %d aktiven Maps (von %d)." % [enabled_count, MAP_PLAYABLE.size()]
	var info: Dictionary = MAPS.get(map_id, {})
	return str(info.get("description", ""))

func set_selected_map(map_id: String) -> void:
	if map_id != MAP_RANDOM and not MAP_PLAYABLE.has(map_id):
		return
	# Wer eine feste Map wählt, will sie spielen: ein abgeschaltetes Level
	# wird dabei wieder aktiv.
	if map_id != MAP_RANDOM and disabled_map_ids.has(map_id):
		disabled_map_ids.erase(map_id)
		map_pool_changed.emit()
	if selected_map_id == map_id:
		return
	selected_map_id = map_id
	map_changed.emit()

func is_map_enabled(map_id: String) -> bool:
	return MAP_PLAYABLE.has(map_id) and not disabled_map_ids.has(map_id)

# Aktive Levels in der Reihenfolge von MAP_PLAYABLE.
func has_enabled_maps() -> bool:
	return not get_enabled_map_ids().is_empty()

func get_enabled_map_ids() -> Array[String]:
	var result: Array[String] = []
	for map_id in MAP_PLAYABLE:
		if not disabled_map_ids.has(map_id):
			result.append(map_id)
	return result

func set_map_enabled(map_id: String, enabled: bool) -> void:
	if not MAP_PLAYABLE.has(map_id):
		return
	if enabled == is_map_enabled(map_id):
		return
	# Alle Levels aus ist erlaubt; die Lobby sperrt dann den Start.
	if enabled:
		disabled_map_ids.erase(map_id)
	else:
		disabled_map_ids.append(map_id)
	map_pool_changed.emit()
	# Eine fest gewählte Map, die abgeschaltet wird, fällt auf "Zufällig" zurück.
	if not enabled and selected_map_id == map_id:
		selected_map_id = MAP_RANDOM
		map_changed.emit()

# Setzt die komplette Sperrliste (Presets, Netzwerk-Sync). Unbekannte IDs
# werden verworfen.
func set_disabled_maps(map_ids: Array) -> void:
	var target: Array[String] = []
	for map_id in MAP_PLAYABLE:
		if map_ids.has(map_id):
			target.append(map_id)
	if target == disabled_map_ids:
		return
	disabled_map_ids = target
	map_pool_changed.emit()
	if selected_map_id != MAP_RANDOM and disabled_map_ids.has(selected_map_id):
		selected_map_id = MAP_RANDOM
		map_changed.emit()

# --- Powerups ---

func get_powerup_name(kind: String) -> String:
	return str(POWERUP_INFO.get(kind, {}).get("name", kind))

func get_powerup_description(kind: String) -> String:
	return str(POWERUP_INFO.get(kind, {}).get("description", ""))

func is_powerup_enabled(kind: String) -> bool:
	return POWERUP_KINDS.has(kind) and not disabled_powerup_kinds.has(kind)

# Powerups, die im Match wirklich erscheinen können. Auto-Angriff braucht
# zusätzlich die Nahkampfwaffe (Lobby-Regel).
func get_active_powerup_kinds() -> Array[String]:
	var result: Array[String] = []
	for kind in POWERUP_KINDS:
		if disabled_powerup_kinds.has(kind):
			continue
		if kind == "auto_attack" and not melee_enabled:
			continue
		result.append(kind)
	return result

func has_active_powerups() -> bool:
	return not get_active_powerup_kinds().is_empty()

func set_powerup_enabled(kind: String, enabled: bool) -> void:
	if not POWERUP_KINDS.has(kind) or enabled == is_powerup_enabled(kind):
		return
	if enabled:
		disabled_powerup_kinds.erase(kind)
	else:
		disabled_powerup_kinds.append(kind)
	powerup_pool_changed.emit()

# Setzt die komplette Sperrliste (Presets, Netzwerk-Sync). Unbekannte Arten
# werden verworfen.
func set_disabled_powerups(kinds: Array) -> void:
	var target: Array[String] = []
	for kind in POWERUP_KINDS:
		if kinds.has(kind):
			target.append(kind)
	if target == disabled_powerup_kinds:
		return
	disabled_powerup_kinds = target
	powerup_pool_changed.emit()

# Löst "zufall" deterministisch anhand des Runden-Seeds auf. Host und Client
# erhalten so dieselbe Map, auch wenn der Host "Zufällig" ausgewählt hat.
func resolve_map_id(level_seed: int) -> String:
	if selected_map_id != MAP_RANDOM and MAP_PLAYABLE.has(selected_map_id):
		return selected_map_id
	var pool := get_enabled_map_ids()
	if pool.is_empty():
		pool = MAP_PLAYABLE.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, level_seed)
	return pool[rng.randi() % pool.size()]

func toggle_bot() -> void:
	set_bot_enabled(not is_bot_enabled)

func set_bot_enabled(enabled: bool) -> void:
	if is_bot_enabled == enabled:
		return
	set_player_kind(2, PlayerKind.BOT if enabled else PlayerKind.HUMAN)
	bot_mode_toggled.emit(enabled)
	lobby_state_changed.emit()

func set_scoring_config(points: int, survival: int, kills: int) -> void:
	var p := clampi(points, 100, 5000)
	var s := clampi(survival, 0, 500)
	var k := clampi(kills, 0, 500)
	if points_to_win == p and survival_points == s and kill_points == k:
		return
	points_to_win = p
	survival_points = s
	kill_points = k
	scoring_config_changed.emit()

# Setzt nur die Zielpunktzahl. Wird nach dem Match-Ende für die
# "Weiterspielen"-Option verwendet, damit Punktestände und Decks erhalten
# bleiben und das Ziel über die Lobby-Grenzen hinaus wachsen kann.
func set_match_target(points: int) -> void:
	var target := maxi(100, points)
	if points_to_win == target:
		return
	points_to_win = target
	match_target_changed.emit(points_to_win)

# Erhöht das Match-Ziel um `percent` der bisherigen Zielpunktzahl. Liegt der
# Führende bereits über dem alten Ziel (z. B. durch Kill-Punkte), wird von
# seinem Punktestand aus weitergerechnet, damit das Spiel sicher weiterläuft.
func advance_match_target(percent: float = 0.30) -> int:
	var increment := maxi(1, int(round(float(points_to_win) * maxf(0.01, percent))))
	var leading_score := 0
	if is_team_mode():
		for team in range(1, get_team_count() + 1):
			leading_score = maxi(leading_score, get_team_score(team))
	else:
		for slot in get_active_player_indices():
			leading_score = maxi(leading_score, player_scores[slot - 1])
	set_match_target(maxi(points_to_win + increment, leading_score + increment))
	return points_to_win

# X von Y: picks = gewählte Karten pro Draft, offered = angebotene Karten
func set_draft_config(picks: int, offered: int) -> void:
	cards_per_draft = clampi(offered, 1, 10)
	draft_picks = clampi(picks, 1, cards_per_draft)
	draft_config_changed.emit(draft_picks, cards_per_draft)
	cards_per_draft_changed.emit(cards_per_draft)

func set_melee_enabled(enabled: bool) -> void:
	if melee_enabled == enabled:
		return
	melee_enabled = enabled
	melee_enabled_changed.emit(melee_enabled)
	lobby_state_changed.emit()

func set_blind_pick_enabled(enabled: bool) -> void:
	if blind_pick_enabled == enabled:
		return
	blind_pick_enabled = enabled
	draft_modifiers_changed.emit()
	lobby_state_changed.emit()

func set_random_pick_enabled(enabled: bool) -> void:
	if random_pick_enabled == enabled:
		return
	random_pick_enabled = enabled
	draft_modifiers_changed.emit()
	lobby_state_changed.emit()

func set_gamble_enabled(enabled: bool) -> void:
	if gamble_enabled == enabled:
		return
	gamble_enabled = enabled
	draft_modifiers_changed.emit()
	lobby_state_changed.emit()

func set_pre_draft_picks(picks: int) -> void:
	var clamped := clampi(picks, 0, PRE_DRAFT_MAX_PICKS)
	if pre_draft_picks == clamped:
		return
	pre_draft_picks = clamped
	draft_modifiers_changed.emit()
	lobby_state_changed.emit()

func set_pre_draft_random(enabled: bool) -> void:
	if pre_draft_random == enabled:
		return
	pre_draft_random = enabled
	draft_modifiers_changed.emit()
	lobby_state_changed.emit()

func set_level_modifier_rate_percent(percent: int) -> void:
	var clamped := clampi(
		percent,
		LevelModifierDefsClass.RATE_MIN_PERCENT,
		LevelModifierDefsClass.RATE_MAX_PERCENT
	)
	if level_modifier_rate_percent == clamped:
		return
	level_modifier_rate_percent = clamped
	level_modifiers_changed.emit()

func set_level_modifier_enabled(id: String, enabled: bool) -> void:
	if not LevelModifierDefsClass.is_valid_id(id):
		return
	var desired: Array[String] = enabled_level_modifiers.duplicate()
	if enabled and not desired.has(id):
		desired.append(id)
	elif not enabled and desired.has(id):
		desired.erase(id)
	var normalized := _normalize_level_modifier_ids(desired)
	if normalized == enabled_level_modifiers:
		return
	enabled_level_modifiers = normalized
	level_modifiers_changed.emit()

func set_enabled_level_modifiers(ids: Array) -> void:
	var normalized := _normalize_level_modifier_ids(ids)
	if normalized == enabled_level_modifiers:
		return
	enabled_level_modifiers = normalized
	level_modifiers_changed.emit()

func get_enabled_level_modifiers() -> Array[String]:
	return enabled_level_modifiers.duplicate()

func is_level_modifier_enabled(id: String) -> bool:
	return enabled_level_modifiers.has(id)

func get_enabled_level_modifier_count() -> int:
	return enabled_level_modifiers.size()

func _normalize_level_modifier_ids(ids: Array) -> Array[String]:
	var normalized: Array[String] = []
	for id in LevelModifierDefsClass.modifier_ids():
		if ids.has(id) and not normalized.has(id):
			normalized.append(id)
	return normalized

func cycle_cards_per_draft() -> void:
	var next_offered := 3
	if cards_per_draft == 3:
		next_offered = 5
	elif cards_per_draft == 5:
		next_offered = 7
	set_draft_config(draft_picks, next_offered)

func set_card_banned(card_id: String, banned: bool) -> void:
	if banned == banned_card_ids.has(card_id):
		return
	if banned:
		banned_card_ids.append(card_id)
	else:
		banned_card_ids.erase(card_id)
	banned_cards_changed.emit()

func is_card_banned(card_id: String) -> bool:
	return banned_card_ids.has(card_id)

func toggle_card_ban(card_id: String) -> void:
	set_card_banned(card_id, not banned_card_ids.has(card_id))

func get_available_card_count() -> int:
	var count := 0
	for card in CardDatabase.all_cards:
		if card.parent_card_id.is_empty() and not banned_card_ids.has(card.id) and CardDatabase.is_card_pool_enabled(card):
			count += 1
	return count

# Klassenspezifische Karten zählen nur für den passenden Helden. Für den Start
# eines Matches zählen nur Grundkarten; Ausbaukarten werden erst nach Besitz der
# Grundkarte draftbar. Für den Draft eines Spielers ist der Vorrat seines Helden
# entscheidend.
func get_available_card_count_for_hero(hero_id: String) -> int:
	var count := 0
	for card in CardDatabase.all_cards:
		if not card.parent_card_id.is_empty():
			continue
		if banned_card_ids.has(card.id):
			continue
		if not CardDatabase.is_card_available_for_player(card, hero_id, []):
			continue
		count += 1
	return count

# Kleinerer Vorrat aller aktiven Helden. `extra_ban_id` simuliert eine
# zusätzliche Sperre, damit die Lobby vor dem Setzen eines Bans prüfen kann, ob
# danach noch genug Karten für alle Helden übrig bleiben.
func get_available_card_count_for_match(extra_ban_id: String = "") -> int:
	var result := 999999
	for hero_id in get_active_hero_ids():
		var count := 0
		for card in CardDatabase.all_cards:
			if not card.parent_card_id.is_empty():
				continue
			if card.id == extra_ban_id:
				continue
			if banned_card_ids.has(card.id):
				continue
			if not CardDatabase.is_card_available_for_player(card, hero_id, []):
				continue
			count += 1
		result = mini(result, count)
	return maxi(0, result)

# --- Lobby-Loadouts ---

func get_current_lobby_settings() -> Dictionary:
	return {
		"match_mode": match_mode,
		"player_count": player_count,
		"points_to_win": points_to_win,
		"survival_points": survival_points,
		"kill_points": kill_points,
		"draft_picks": draft_picks,
		"cards_per_draft": cards_per_draft,
		"blind_pick_enabled": blind_pick_enabled,
		"random_pick_enabled": random_pick_enabled,
		"gamble_enabled": gamble_enabled,
		"pre_draft_picks": pre_draft_picks,
		"pre_draft_random": pre_draft_random,
		"melee_enabled": melee_enabled,
		"level_modifier_rate_percent": level_modifier_rate_percent,
		"enabled_level_modifiers": get_enabled_level_modifiers(),
		"known_level_modifiers": LevelModifierDefsClass.modifier_ids(),
		"base_hp_percent": base_hp_percent,
		"base_damage": base_damage,
		"map_id": selected_map_id,
		"disabled_map_ids": disabled_map_ids.duplicate(),
		"disabled_powerup_kinds": disabled_powerup_kinds.duplicate(),
		"enabled_card_pools": enabled_card_pools.duplicate(),
		"known_card_pools": CARD_POOLS.duplicate(),
		"banned_card_ids": banned_card_ids.duplicate(),
		"pool_unlocked_card_ids": pool_unlocked_card_ids.duplicate(),
		"rarity_percentages": rarity_percentages.duplicate(),
	}

func _default_lobby_settings() -> Dictionary:
	return {
		"match_mode": MATCH_MODE_FFA,
		"player_count": 2,
		"points_to_win": 500,
		"survival_points": 50,
		"kill_points": 50,
		"draft_picks": 1,
		"cards_per_draft": 5,
		"blind_pick_enabled": false,
		"random_pick_enabled": false,
		"gamble_enabled": false,
		"pre_draft_picks": 0,
		"pre_draft_random": false,
		"melee_enabled": true,
		"level_modifier_rate_percent": LevelModifierDefsClass.RATE_DEFAULT_PERCENT,
		"enabled_level_modifiers": LevelModifierDefsClass.default_ids(),
		"base_hp_percent": 100,
		"base_damage": 22.0,
		"map_id": MAP_RANDOM,
		"disabled_map_ids": [],
		"disabled_powerup_kinds": [],
		"enabled_card_pools": CARD_POOLS.duplicate(),
		"banned_card_ids": [],
		"pool_unlocked_card_ids": [],
		"rarity_percentages": {
			"Common": 50.0,
			"Uncommon": 25.0,
			"Rare": 15.0,
			"Epic": 8.0,
			"Legendary": 2.0,
		},
	}

# Öffentlicher Zugriff für den "Standard"-Button der Lobby.
func get_default_lobby_settings() -> Dictionary:
	return _default_lobby_settings()

# Setzt alle Regeln auf Standard und überschreibt dabei "Last".
func apply_default_lobby_settings() -> void:
	apply_lobby_settings(_default_lobby_settings())
	save_last_lobby_settings()

func _create_default_lobby_loadouts() -> void:
	lobby_loadouts.clear()
	lobby_loadouts["Standard"] = _default_lobby_settings()

	var fast := _default_lobby_settings()
	fast["player_count"] = 4
	fast["points_to_win"] = 300
	fast["survival_points"] = 40
	fast["kill_points"] = 60
	fast["cards_per_draft"] = 6
	fast["base_hp_percent"] = 80
	fast["base_damage"] = 28.0
	fast["map_id"] = "neonfabrik"
	fast["level_modifier_rate_percent"] = 150
	lobby_loadouts["Schnell & Wild"] = fast

	var team := _default_lobby_settings()
	team["match_mode"] = MATCH_MODE_2V2
	team["player_count"] = 4
	team["points_to_win"] = 400
	team["map_id"] = MAP_RANDOM
	lobby_loadouts["Team 2v2"] = team

	var chaos := _default_lobby_settings()
	chaos["player_count"] = 6
	chaos["points_to_win"] = 600
	chaos["survival_points"] = 30
	chaos["kill_points"] = 70
	chaos["draft_picks"] = 2
	chaos["cards_per_draft"] = 8
	chaos["base_hp_percent"] = 120
	chaos["base_damage"] = 30.0
	chaos["map_id"] = MAP_RANDOM
	chaos["level_modifier_rate_percent"] = 200
	chaos["rarity_percentages"] = {
		"Common": 30.0,
		"Uncommon": 30.0,
		"Rare": 25.0,
		"Epic": 12.0,
		"Legendary": 3.0,
	}
	lobby_loadouts["Chaos"] = chaos

func _load_lobby_loadouts() -> void:
	lobby_loadouts.clear()
	if not FileAccess.file_exists(LOBBY_LOADOUTS_PATH):
		_create_default_lobby_loadouts()
		_save_lobby_loadouts_file()
		return

	var file := FileAccess.open(LOBBY_LOADOUTS_PATH, FileAccess.READ)
	if file == null:
		_create_default_lobby_loadouts()
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	var valid := false
	var cleaned: Dictionary = {}
	if parsed is Dictionary and parsed.get("loadouts") is Dictionary:
		var raw: Dictionary = parsed.get("loadouts")
		for key in raw.keys():
			if raw[key] is Dictionary:
				cleaned[str(key)] = raw[key].duplicate(true)
		valid = true
	if not valid:
		_create_default_lobby_loadouts()
		_save_lobby_loadouts_file()
		return
	lobby_loadouts = cleaned

func _save_lobby_loadouts_file() -> bool:
	var file := FileAccess.open(LOBBY_LOADOUTS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "loadouts": lobby_loadouts}, "\t", false))
	file.close()
	return true

# --- Automatisches "Last"-Loadout ---

func _restore_last_lobby_settings() -> void:
	if lobby_loadouts.has(LOBBY_LAST_LOADOUT):
		apply_lobby_settings(get_lobby_loadout(LOBBY_LAST_LOADOUT))
		return
	# Erster Start mit dieser Version: Standardwerte übernehmen und als "Last" ablegen.
	apply_default_lobby_settings()

# Lädt "Last" beim Öffnen der Lobby erneut. Dadurch verschwinden Werte, die
# nicht vom Host eingestellt wurden: gespiegelte Regeln eines fremden Hosts
# (nach einer Runde als Client) und das per "Weiterspielen" erhöhte Match-Ziel.
func restore_last_lobby_settings() -> void:
	if not lobby_autosave_enabled:
		return
	if network_mode and not is_local_host():
		return
	# Noch nicht geschriebene Änderung zuerst sichern, sie ist der neueste Stand.
	if _lobby_autosave_timer != null and not _lobby_autosave_timer.is_stopped():
		_lobby_autosave_timer.stop()
		save_last_lobby_settings()
		return
	if lobby_loadouts.has(LOBBY_LAST_LOADOUT):
		apply_lobby_settings(get_lobby_loadout(LOBBY_LAST_LOADOUT))

# Beim Schließen des Fensters eine noch wartende Änderung sofort schreiben,
# sonst geht alles verloren, was in den letzten LOBBY_AUTOSAVE_DELAY Sekunden
# eingestellt wurde.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _lobby_autosave_timer != null and not _lobby_autosave_timer.is_stopped():
			_lobby_autosave_timer.stop()
			_flush_lobby_autosave()

func _setup_lobby_settings_autosave() -> void:
	_lobby_autosave_timer = Timer.new()
	_lobby_autosave_timer.name = "LobbySettingsAutosave"
	_lobby_autosave_timer.one_shot = true
	_lobby_autosave_timer.wait_time = LOBBY_AUTOSAVE_DELAY
	_lobby_autosave_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_lobby_autosave_timer.timeout.connect(_flush_lobby_autosave)
	add_child(_lobby_autosave_timer)
	match_mode_changed.connect(_queue_lobby_autosave)
	player_count_changed.connect(_queue_lobby_autosave)
	scoring_config_changed.connect(_queue_lobby_autosave)
	draft_config_changed.connect(_queue_lobby_autosave)
	draft_modifiers_changed.connect(_queue_lobby_autosave)
	level_modifiers_changed.connect(_queue_lobby_autosave)
	melee_enabled_changed.connect(_queue_lobby_autosave)
	banned_cards_changed.connect(_queue_lobby_autosave)
	card_pools_changed.connect(_queue_lobby_autosave)
	map_changed.connect(_queue_lobby_autosave)
	map_pool_changed.connect(_queue_lobby_autosave)
	powerup_pool_changed.connect(_queue_lobby_autosave)
	base_hp_percent_changed.connect(_queue_lobby_autosave)
	base_damage_changed.connect(_queue_lobby_autosave)
	rarity_percentages_changed.connect(_queue_lobby_autosave)

func _queue_lobby_autosave(_arg1: Variant = null, _arg2: Variant = null) -> void:
	if not lobby_autosave_enabled or _lobby_autosave_timer == null:
		return
	# Clients spiegeln die Host-Regeln und sollen ihr eigenes "Last" nicht überschreiben.
	if network_mode and not is_local_host():
		return
	_lobby_autosave_timer.start()

func _flush_lobby_autosave() -> void:
	if not lobby_autosave_enabled:
		return
	if network_mode and not is_local_host():
		return
	save_last_lobby_settings()

# Schreibt die aktuellen Regeln sofort als "Last". Liefert false, wenn die Datei
# nicht geschrieben werden konnte; der vorherige Stand bleibt dann erhalten.
func save_last_lobby_settings() -> bool:
	var settings := get_current_lobby_settings()
	var previous: Variant = lobby_loadouts.get(LOBBY_LAST_LOADOUT, null)
	if previous is Dictionary and JSON.stringify(previous) == JSON.stringify(settings):
		return true
	var is_new := previous == null
	lobby_loadouts[LOBBY_LAST_LOADOUT] = settings
	if not _save_lobby_loadouts_file():
		if is_new:
			lobby_loadouts.erase(LOBBY_LAST_LOADOUT)
		else:
			lobby_loadouts[LOBBY_LAST_LOADOUT] = previous
		return false
	lobby_last_loadout_saved.emit()
	# Nur beim ersten Anlegen muss die Preset-Liste neu aufgebaut werden. Ein
	# Rebuild bei jeder Regeländerung würde ein offenes Dropdown zurücksetzen.
	if is_new:
		lobby_loadouts_changed.emit()
	return true

func get_lobby_loadout_names() -> Array[String]:
	var names: Array[String] = []
	for key in lobby_loadouts.keys():
		names.append(str(key))
	return names

func has_lobby_loadout(name: String) -> bool:
	return lobby_loadouts.has(name)

func get_lobby_loadout(name: String) -> Dictionary:
	var data: Variant = lobby_loadouts.get(name, {})
	if data is Dictionary:
		return data.duplicate(true)
	return {}

func save_lobby_loadout(name: String) -> bool:
	var key := name.strip_edges()
	if key.is_empty():
		return false
	if key.length() > 40:
		key = key.substr(0, 40)
	lobby_loadouts[key] = get_current_lobby_settings()
	if not _save_lobby_loadouts_file():
		return false
	lobby_loadouts_changed.emit()
	return true

func delete_lobby_loadout(name: String) -> bool:
	if name == LOBBY_LAST_LOADOUT:
		return false
	if not lobby_loadouts.has(name):
		return false
	lobby_loadouts.erase(name)
	if not _save_lobby_loadouts_file():
		return false
	lobby_loadouts_changed.emit()
	return true

func apply_lobby_settings(settings: Dictionary) -> void:
	set_match_mode(str(settings.get("match_mode", match_mode)))
	var required := get_mode_required_players()
	var count := required if required > 0 else int(settings.get("player_count", player_count))
	set_player_count(count)
	set_scoring_config(
		int(settings.get("points_to_win", points_to_win)),
		int(settings.get("survival_points", survival_points)),
		int(settings.get("kill_points", kill_points))
	)
	set_draft_config(
		int(settings.get("draft_picks", draft_picks)),
		int(settings.get("cards_per_draft", cards_per_draft))
	)
	# Alte Loadouts kennen die Modifier noch nicht; sie werden beim Laden
	# bewusst deaktiviert, damit ein Preset eine vollständige Konfiguration ist.
	set_blind_pick_enabled(bool(settings.get("blind_pick_enabled", false)))
	set_random_pick_enabled(bool(settings.get("random_pick_enabled", false)))
	set_gamble_enabled(bool(settings.get("gamble_enabled", false)))
	set_pre_draft_picks(int(settings.get("pre_draft_picks", 0)))
	set_pre_draft_random(bool(settings.get("pre_draft_random", false)))
	set_melee_enabled(bool(settings.get("melee_enabled", true)))
	set_level_modifier_rate_percent(
		int(settings.get(
			"level_modifier_rate_percent",
			LevelModifierDefsClass.RATE_DEFAULT_PERCENT
		))
	)
	var level_mods: Variant = settings.get("enabled_level_modifiers", null)
	if level_mods is Array:
		# Modifier, die beim Speichern noch nicht existierten, sind an.
		var mod_list: Array = level_mods.duplicate()
		var known_mods: Variant = settings.get("known_level_modifiers", null)
		for id in LevelModifierDefsClass.modifier_ids():
			var is_new: bool = LATER_LEVEL_MODIFIERS.has(id)
			if known_mods is Array:
				is_new = not known_mods.has(id)
			if is_new and not mod_list.has(id):
				mod_list.append(id)
		set_enabled_level_modifiers(mod_list)
	else:
		set_enabled_level_modifiers(LevelModifierDefsClass.default_ids())
	set_base_hp_percent(int(settings.get("base_hp_percent", base_hp_percent)))
	set_base_damage(float(settings.get("base_damage", base_damage)))
	# Erst die Level-Sperrliste, dann die Map: Alte Presets ohne Liste
	# spielen alle Levels.
	var disabled_maps: Variant = settings.get("disabled_map_ids", [])
	set_disabled_maps(disabled_maps if disabled_maps is Array else [])
	if settings.has("map_id"):
		set_selected_map(str(settings.get("map_id", selected_map_id)))
	# Alte Presets ohne Liste haben alle Powerups an.
	var disabled_powerups: Variant = settings.get("disabled_powerup_kinds", [])
	set_disabled_powerups(disabled_powerups if disabled_powerups is Array else [])
	var pools: Variant = settings.get("enabled_card_pools", null)
	if pools is Array:
		# Pools, die beim Speichern noch nicht existierten, sind an.
		var pool_list: Array = pools.duplicate()
		var known_pools: Variant = settings.get("known_card_pools", null)
		var known: Array = known_pools if known_pools is Array else LEGACY_CARD_POOLS
		for pool in CARD_POOLS:
			if not known.has(pool) and not pool_list.has(pool):
				pool_list.append(pool)
		set_enabled_card_pools(pool_list)
	var rarity_data: Variant = settings.get("rarity_percentages", null)
	if rarity_data is Dictionary:
		for rarity in RARITY_ORDER:
			if rarity_data.has(rarity):
				set_rarity_percent(rarity, float(rarity_data[rarity]))
	banned_card_ids.clear()
	var bans: Variant = settings.get("banned_card_ids", null)
	if bans is Array:
		for card_id in bans:
			var id := str(card_id)
			if not id.is_empty() and not banned_card_ids.has(id):
				banned_card_ids.append(id)
	var unlocks: Variant = settings.get("pool_unlocked_card_ids", null)
	set_pool_unlocked_cards(unlocks if unlocks is Array else [])
	banned_cards_changed.emit()

func get_lobby_loadout_summary(name: String) -> String:
	var data := get_lobby_loadout(name)
	if data.is_empty():
		return ""
	var pools: Variant = data.get("enabled_card_pools", [])
	var bans: Variant = data.get("banned_card_ids", [])
	var modifiers: Array[String] = []
	if bool(data.get("blind_pick_enabled", false)):
		modifiers.append("Blind")
	if bool(data.get("random_pick_enabled", false)):
		modifiers.append("Random")
	if bool(data.get("gamble_enabled", false)):
		modifiers.append("Gamble")
	var modifier_text := ""
	if not modifiers.is_empty():
		modifier_text = " · Modifier: %s" % ", ".join(modifiers)
	var pre_picks := int(data.get("pre_draft_picks", 0))
	if pre_picks > 0:
		modifier_text += " · Pre-Draft %d%s" % [pre_picks, " (zufällig)" if bool(data.get("pre_draft_random", false)) else ""]
	var level_mods: Variant = data.get("enabled_level_modifiers", LevelModifierDefsClass.default_ids())
	var level_mod_count: int = level_mods.size() if level_mods is Array else 0
	modifier_text += " · Level-Mod %d %% (%d/%d)" % [
		int(data.get("level_modifier_rate_percent", LevelModifierDefsClass.RATE_DEFAULT_PERCENT)),
		level_mod_count,
		LevelModifierDefsClass.MODIFIERS.size(),
	]
	var disabled_maps: Variant = data.get("disabled_map_ids", [])
	var disabled_map_count := 0
	if disabled_maps is Array:
		for map_id in MAP_PLAYABLE:
			if disabled_maps.has(map_id):
				disabled_map_count += 1
	if disabled_map_count > 0 and disabled_map_count < MAP_PLAYABLE.size():
		modifier_text += " · Levels %d/%d" % [MAP_PLAYABLE.size() - disabled_map_count, MAP_PLAYABLE.size()]
	var disabled_powerups: Variant = data.get("disabled_powerup_kinds", [])
	var disabled_powerup_count := 0
	if disabled_powerups is Array:
		for kind in POWERUP_KINDS:
			if disabled_powerups.has(kind):
				disabled_powerup_count += 1
	if disabled_powerup_count >= POWERUP_KINDS.size():
		modifier_text += " · Powerups aus"
	elif disabled_powerup_count > 0:
		modifier_text += " · Powerups %d/%d" % [POWERUP_KINDS.size() - disabled_powerup_count, POWERUP_KINDS.size()]
	return "%s · %d Spieler · Ziel %d P · Draft %d/%d · HP %d %% · DMG %d · Map %s · %d Pools · %d Bans%s" % [
		get_match_mode_name(str(data.get("match_mode", MATCH_MODE_FFA))),
		int(data.get("player_count", 2)),
		int(data.get("points_to_win", points_to_win)),
		int(data.get("draft_picks", draft_picks)),
		int(data.get("cards_per_draft", cards_per_draft)),
		int(data.get("base_hp_percent", base_hp_percent)),
		int(float(data.get("base_damage", base_damage))),
		get_map_name(str(data.get("map_id", MAP_RANDOM))),
		pools.size() if pools is Array else 0,
		bans.size() if bans is Array else 0,
		modifier_text,
	]

# --- Lobby / Ready / Host ---

func reset_lobby_state() -> void:
	for i in range(1, MAX_PLAYERS + 1):
		player_ready[i] = is_bot_slot(i)
	lobby_state_changed.emit()

func set_player_ready(index: int, ready: bool) -> void:
	if index < 1 or index > MAX_PLAYERS:
		return
	if is_player_ready(index) == ready:
		return
	player_ready[index] = ready
	lobby_state_changed.emit()

func is_player_ready(index: int) -> bool:
	return bool(player_ready.get(index, false))

func all_players_ready() -> bool:
	for i in get_active_player_indices():
		if not is_player_ready(i):
			return false
	return true

func is_local_host() -> bool:
	return local_player_index == host_player_index

# Für Netzwerk-Clients: legt fest, welcher Slot lokal gesteuert wird.
func set_local_player(index: int) -> void:
	local_player_index = clampi(index, 0, MAX_PLAYERS)
	lobby_state_changed.emit()

# Darf der lokale Spieler diesen Slot bearbeiten (Held, Bereit)?
func can_control_slot(index: int) -> bool:
	if not network_mode:
		return true
	return index == local_player_index

# --- Netzwerk-Spielstand (vom Host gespiegelt) ---

func set_network_scores(scores: Array) -> void:
	for i in range(mini(scores.size(), MAX_PLAYERS)):
		player_scores[i] = int(scores[i])
	scores_changed.emit(get_scores())

func set_network_match_over(winner_index: int, stats: Array = [], reason: String = "") -> void:
	if stats.is_empty():
		reset_match_stats()
	else:
		set_match_stats(stats)
	_finish_match(winner_index, reason)

func set_network_info(text: String) -> void:
	network_info = text
	network_status_changed.emit()
