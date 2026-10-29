class_name LevelModifierDefs
extends RefCounted

# Zentrale Quelle für alle Runden-Modifier. Manager, Lobby und Global greifen
# auf dieselben IDs, Titel und Beschreibungen zu, damit Auswahl und Anzeige
# niemals auseinanderlaufen.
const RATE_MIN_PERCENT: int = 0
const RATE_MAX_PERCENT: int = 200
const RATE_DEFAULT_PERCENT: int = 100

const MODIFIERS: Dictionary = {
	"cave": {
		"id": "cave",
		"title": "Höhle",
		"icon": "⛰",
		"description": "Feste Felswände umgeben die Arena statt der elastischen Gummiwand.",
		"color": Color(0.7, 0.7, 0.75),
	},
	"tnt_depot": {
		"id": "tnt_depot",
		"title": "TNT-Depot",
		"icon": "💣",
		"description": "Mehr TNT im Level! Alle 10 Sekunden regnen 5 TNT-Kisten herab.",
		"color": Color(1.0, 0.35, 0.15),
	},
	"wind": {
		"id": "wind",
		"title": "Sturmwind",
		"icon": "🌪",
		"description": "Alle 10s weht ein starker Windstoß (3,5s), der Spieler pustet und Projektile bremst.",
		"color": Color(0.4, 0.85, 1.0),
	},
	"laser": {
		"id": "laser",
		"title": "Orbital-Laser",
		"icon": "🔴",
		"description": "Alle 10s feuert ein warnender Riesenlaser quer über die Map (50 Schaden).",
		"color": Color(1.0, 0.15, 0.2),
	},
	"bounty": {
		"id": "bounty",
		"title": "Münzbeute",
		"icon": "🪙",
		"description": "Münzen spawnen im Level. Wer am Ende die meisten sammelt, erhält eine Extrakarte!",
		"color": Color(1.0, 0.85, 0.2),
	},
	"heal_zone": {
		"id": "heal_zone",
		"title": "Wandernde Heilzone",
		"icon": "💚",
		"description": "Ein schwebender Heilkreis gleitet sanft über die Map und heilt 16 HP/s.",
		"color": Color(0.3, 1.0, 0.5),
	},
	"pinata": {
		"id": "pinata",
		"title": "Piñata-Lama",
		"icon": "🦙",
		"description": "Ein unsterbliches Lama rennt panisch vor dem führenden Spieler weg. Der meiste Schaden bringt eine Extrakarte!",
		"color": Color(1.0, 0.3, 0.8),
	},
	"low_gravity": {
		"id": "low_gravity",
		"title": "Mondgravitation",
		"icon": "🌙",
		"description": "50 % Gravitation! Gigantische Sprünge, Schweben und enorme Rückstöße.",
		"color": Color(0.7, 0.6, 1.0),
	},
	"floor_is_lava": {
		"id": "floor_is_lava",
		"title": "Der Boden ist Lava",
		"icon": "🌋",
		"description": "Der unterste Boden brennt! Bleib auf Kisten, Plattformen und Federn.",
		"color": Color(1.0, 0.45, 0.0),
	},
	"meteor_shower": {
		"id": "meteor_shower",
		"title": "Meteoritenschauer",
		"icon": "☄",
		"description": "Alle 12s stürzen 3 glühende Meteore mit Bodenzielkreuzen explosiv herab.",
		"color": Color(1.0, 0.5, 0.1),
	},
	"ice_world": {
		"id": "ice_world",
		"title": "Glatteis-Welt",
		"icon": "❄",
		"description": "Alle Plattformen sind spiegelglatt! Rasantes Schlittern und hohes Tempo.",
		"color": Color(0.5, 0.95, 1.0),
	},
	"mini_pigs": {
		"id": "mini_pigs",
		"title": "Mini-Chaos",
		"icon": "🐷",
		"description": "Schrumpffluch! Alle Schweine sind 35 % kleiner, flinker und schwerer zu treffen.",
		"color": Color(1.0, 0.8, 0.9),
	},
	"double_damage": {
		"id": "double_damage",
		"title": "Schadensrausch",
		"icon": "💥",
		"description": "Alle Waffen richten 35 % mehr Schaden an. Kämpfe enden deutlich schneller.",
		"color": Color(1.0, 0.25, 0.25),
	},
	"high_gravity": {
		"id": "high_gravity",
		"title": "Schwerewelt",
		"icon": "🪨",
		"description": "Die Gravitation ist 60 % stärker. Sprünge werden kurz und Rückstöße schwächer.",
		"color": Color(0.65, 0.55, 0.9),
	},
	"speed_demon": {
		"id": "speed_demon",
		"title": "Turboschweine",
		"icon": "💨",
		"description": "Alle Spieler bewegen sich 30 % schneller. Volle Raserei!",
		"color": Color(1.0, 0.85, 0.2),
	},
	"air_jumps": {
		"id": "air_jumps",
		"title": "Luftakrobatik",
		"icon": "🪂",
		"description": "Jeder Spieler erhält einen zusätzlichen Sprung in der Luft.",
		"color": Color(0.4, 0.9, 1.0),
	},
	"regeneration": {
		"id": "regeneration",
		"title": "Regeneration",
		"icon": "🌿",
		"description": "Alle Spieler heilen 4 HP pro Sekunde, solange sie leben.",
		"color": Color(0.35, 1.0, 0.5),
	},
	"starting_shield": {
		"id": "starting_shield",
		"title": "Startschild",
		"icon": "🛡",
		"description": "Alle starten mit einem Bonusschild in Höhe von 30 % ihrer maximalen HP.",
		"color": Color(0.45, 0.75, 1.0),
	},
	"crate_rain": {
		"id": "crate_rain",
		"title": "Kistenregen",
		"icon": "📦",
		"description": "Alle 9 Sekunden regnen drei Holzkisten in die Arena.",
		"color": Color(0.9, 0.65, 0.35),
	},
	"powerup_rain": {
		"id": "powerup_rain",
		"title": "Powerup-Regen",
		"icon": "🎁",
		"description": "Beim Levelaufbau erscheinen etwa drei zusätzliche Powerups.",
		"color": Color(1.0, 0.5, 0.9),
	},
	"lava_flood": {
		"id": "lava_flood",
		"title": "Lava-Flut",
		"icon": "🌊",
		"description": "Alle 30s steigt die Lava auf ein Drittel bis die Hälfte der Levelhöhe und sinkt wieder ab.",
		"color": Color(1.0, 0.4, 0.05),
	},
	"zone": {
		"id": "zone",
		"title": "Zone",
		"icon": "🌀",
		"description": "Wie in Fortnite: Ein Sturmkreis schrumpft in Stufen und wandert am Ende über die Map. Außerhalb gibt es Schaden.",
		"color": Color(0.6, 0.4, 1.0),
	},
	"night": {
		"id": "night",
		"title": "Nacht",
		"icon": "🌑",
		"description": "Stockdunkel! Jeder sieht nur einen kleinen Lichtkreis um sich herum.",
		"color": Color(0.35, 0.4, 0.8),
	},
	"ball_rain": {
		"id": "ball_rain",
		"title": "Kugelregen",
		"icon": "⚪",
		"description": "Alle 4 Sekunden fallen fünf Kugeln aus Gummi, Holz oder Eisen vom Himmel. Treffer tun weh!",
		"color": Color(0.85, 0.75, 0.55),
	},
	"ball_hail": {
		"id": "ball_hail",
		"title": "Kugelhagel",
		"icon": "🎳",
		"description": "Alle 16 Sekunden prasseln 24 Kugeln auf einmal über die ganze Arena herab.",
		"color": Color(0.7, 0.75, 0.85),
	},
	"hot_potato": {
		"id": "hot_potato",
		"title": "Heiße Kartoffel",
		"icon": "😈",
		"description": "Ein fliegendes Teufelschwein jagt den Führenden und schießt auf ihn. Triff es, um es weiterzugeben. Wer es aus Versehen trifft, wird 5 s lang sein wütendes Ziel!",
		"color": Color(1.0, 0.25, 0.15),
	},
	"brawl": {
		"id": "brawl",
		"title": "Brawl",
		"icon": "🔨",
		"description": "Nahkampf-Rausch! Nahkampfwaffen haben 50 % mehr Reichweite und halbe Abklingzeit.",
		"color": Color(0.95, 0.55, 0.25),
	},
}

# Stabile Reihenfolge für UI, Loadouts und Netzwerk-Snapshots.
static func modifier_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in MODIFIERS.keys():
		ids.append(str(key))
	return ids

static func default_ids() -> Array[String]:
	return modifier_ids()

static func is_valid_id(id: String) -> bool:
	return MODIFIERS.has(id)
