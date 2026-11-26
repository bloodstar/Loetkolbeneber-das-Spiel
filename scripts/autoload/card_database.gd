extends Node

var all_cards: Array[CardData] = []
var cards_by_id: Dictionary = {}

# Farben für den äußeren Kartenrahmen. Die Effektfarbe einer Karte bleibt in
# CardData.color und bestimmt den inneren Rahmen.
const RARITY_COLORS: Dictionary = {
	"Common": Color(0.72, 0.76, 0.82),
	"Uncommon": Color(0.35, 0.85, 0.45),
	"Rare": Color(0.30, 0.60, 1.0),
	"Epic": Color(0.72, 0.40, 1.0),
	"Legendary": Color(1.0, 0.68, 0.12),
}

func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color(0.72, 0.76, 0.82))

# Sub-Tags je Haupt-Tag (Pool). Eine Karte kann beliebig viele Sub-Tags haben,
# auch aus anderen Gruppen (z. B. Defensive-Karte mit "Tempo"). Die Diagramme
# zeigen pro Haupt-Tag die Karten dieses Pools verteilt auf seine Sub-Tags.
const SUB_TAG_GROUPS: Dictionary = {
	"Offensive": ["Schaden", "Feuerrate", "Projektil", "Bounce", "Durchschlag", "Zielsuche", "Mehrfachschuss", "Explosion", "Element", "Begleiter"],
	"Defensive": ["Leben", "Heilung", "Schild", "Barriere", "Rüstung", "Reflexion"],
	"Bewegung": ["Tempo", "Sprung", "Dash", "Schwerkraft", "Größe"],
	"Nahkampf": ["Klinge", "Reichweite", "Schlagtempo", "Rückstoß", "Kontrolle", "Elementarhieb"],
}
# Sub-Tags, die in jedem Pool vorkommen können.
const SHARED_SUB_TAGS: Array[String] = ["Fähigkeit", "Powerup", "Unique"]
const SUB_TAG_DESCRIPTIONS: Dictionary = {
	"Schaden": "Mehr Schussschaden.",
	"Feuerrate": "Feuerrate, Munition und Nachladen.",
	"Projektil": "Kugeltempo, -größe, Flugbahn und Rückstoß.",
	"Bounce": "Abpraller und ihre Ausbauten.",
	"Durchschlag": "Kugeln durchdringen Gegner und Wände.",
	"Zielsuche": "Kugeln lenken auf Gegner.",
	"Mehrfachschuss": "Mehr Projektile pro Schuss oder Streuung.",
	"Explosion": "Explosionsradius und Splitterbomben.",
	"Element": "Gift, Frost, Feuer und Blitz am Schuss.",
	"Begleiter": "Türme und Drohnen.",
	"Leben": "Mehr Maximalleben.",
	"Heilung": "Regeneration, Lebensraub und Heilzonen.",
	"Schild": "Schildgröße, Schildaufbau und Schild-Cooldown.",
	"Barriere": "Barrieredauer, Abklingzeit und Barriere-Effekte (Q). Unabhängig vom Schild.",
	"Rüstung": "Weniger erlittener Schaden.",
	"Reflexion": "Wirft Schaden oder Projektile zurück.",
	"Tempo": "Höheres Lauftempo.",
	"Sprung": "Sprungkraft und Extra-Sprünge.",
	"Dash": "Kürzere Dash-Abklingzeit.",
	"Schwerkraft": "Weniger Schwerkraft, längere Luftzeit.",
	"Größe": "Ändert die Charaktergröße (kleiner oder größer).",
	"Klinge": "Mehr Nahkampfschaden.",
	"Reichweite": "Nahkampf-Reichweite und Schlagbogen.",
	"Schlagtempo": "Kürzere Nahkampf-Abklingzeit.",
	"Rückstoß": "Stärkerer Nahkampf-Rückstoß.",
	"Kontrolle": "Verlangsamt oder betäubt im Nahkampf.",
	"Elementarhieb": "Gift, Brand oder Blitz am Nahkampftreffer.",
	"Fähigkeit": "Verstärkt die Heldenfähigkeit.",
	"Powerup": "Verstärkt eingesammelte Powerups.",
	"Unique": "Schaltet eine eigene Spezialmechanik frei.",
}

func get_sub_tags_for_pool(pool: String) -> Array[String]:
	var tags: Array[String] = []
	for tag in SUB_TAG_GROUPS.get(pool, []):
		tags.append(str(tag))
	tags.append_array(SHARED_SUB_TAGS)
	return tags

func get_all_sub_tags() -> Array[String]:
	var tags: Array[String] = []
	for pool in Global.CARD_POOLS:
		for tag in SUB_TAG_GROUPS.get(pool, []):
			if not tags.has(str(tag)):
				tags.append(str(tag))
	tags.append_array(SHARED_SUB_TAGS)
	return tags

func _ready() -> void:
	_init_database()

# Versionierung: Wird eine bestehende Karte im Balancing verändert, zusätzlich
# `cX.version = <alte Version + 1>` setzen (Standard ist 1). Die Statistik
# trennt dann alte und neue Messwerte. Neue Karten starten einfach bei 1.
func _init_database() -> void:
	all_cards.clear()
	cards_by_id.clear()

	# 1. Bouncy Balls
	var c1 = CardData.new()
	c1.id = "bouncy_balls"
	c1.version = 3 # Evolution A von abpraller
	c1.title = "Bouncy Balls"
	c1.description = "Abpraller-Ausbau: Kugeln prallen von Wänden ab!\n+1 Abpraller, +15% Projektilgeschwindigkeit."
	c1.rarity = "Uncommon"
	c1.color = Color(0.3, 0.8, 0.3)
	c1.family_id = "abpraller"
	c1.parent_card_id = "abpraller"
	c1.evolution_branch = "A"
	c1.bounces_add = 1
	c1.bullet_speed_mult = 1.15
	_register(c1)

	# 2. Heavy Bullets
	var c2 = CardData.new()
	c2.id = "heavy_bullets"
	c2.version = 3 # Evolution B von scharfe_munition
	c2.title = "Heavy Bullets"
	c2.description = "Schadens-Ausbau: Wuchtiger, schwerer Einschlag.\n+15% Schaden, +40% Projektilgröße, -15% Projektilgeschwindigkeit."
	c2.rarity = "Uncommon"
	c2.color = Color(0.8, 0.4, 0.2)
	c2.family_id = "scharfe_munition"
	c2.parent_card_id = "scharfe_munition"
	c2.evolution_branch = "B"
	c2.damage_mult = 1.15
	c2.bullet_size_mult = 1.4
	c2.bullet_speed_mult = 0.85
	_register(c2)

	# 3. Fast Forward
	var c3 = CardData.new()
	c3.id = "fast_forward"
	c3.version = 3 # Evolution B von scharfschuetze
	c3.title = "Fast Forward"
	c3.description = "Projektil-Ausbau: Blitzschnelle Kugeln.\n+30% Projektilgeschwindigkeit, +12% Tempo."
	c3.rarity = "Uncommon"
	c3.color = Color(0.2, 0.7, 0.9)
	c3.family_id = "scharfschuetze"
	c3.parent_card_id = "scharfschuetze"
	c3.evolution_branch = "B"
	c3.bullet_speed_mult = 1.30
	c3.move_speed_mult = 1.12
	_register(c3)

	# 4. Tactical Vest
	var c4 = CardData.new()
	c4.id = "tactical_vest"
	c4.version = 2 # Max-HP/Schild-Bonus verdoppelt
	c4.title = "Tactical Vest"
	c4.description = "Verstärkte Panzerung.\n+60 Max HP, +30 Schild."
	c4.rarity = "Rare"
	c4.color = Color(0.4, 0.7, 0.4)
	c4.max_hp_flat = 60
	c4.shield_max_add = 30
	_register(c4)

	# 5. Quick Draw
	var c5 = CardData.new()
	c5.id = "quick_draw"
	c5.version = 2 # Seltenheit Common -> Rare (Duplikat-Abgleich)
	c5.title = "Quick Draw"
	c5.description = "Schneller Abzug.\n+30% Feuerrate, +1 Munition."
	c5.rarity = "Rare"
	c5.color = Color(0.9, 0.7, 0.2)
	c5.fire_rate_mult = 0.70 # Cooldown reduced by 30%
	c5.max_ammo_add = 1
	_register(c5)

	# 6. Feather Shoes
	var c6 = CardData.new()
	c6.id = "feather_shoes"
	c6.version = 2 # Seltenheit Common -> Uncommon (Duplikat-Abgleich)
	c6.title = "Feather Shoes"
	c6.description = "Trotze der Schwerkraft.\n+1 Luft-Sprung, +15% Sprungkraft."
	c6.rarity = "Uncommon"
	c6.color = Color(0.8, 0.8, 0.5)
	c6.extra_jumps_add = 1
	c6.jump_force_mult = 1.15
	_register(c6)

	# 7. Homing Rounds
	var c7 = CardData.new()
	c7.id = "homing_rounds"
	c7.title = "Homing Micro-Seekers"
	c7.description = "Kugeln suchen sich nahe Gegner!\n+Zielsuche, -10% Schaden."
	c7.rarity = "Rare"
	c7.color = Color(0.5, 0.3, 0.9)
	c7.homing_strength_add = 0.45
	c7.damage_mult = 0.90
	c7.version = 2 # Lenkung jetzt entfernungsabhängig (nah stark, fern schwach)
	_register(c7)

	# 8. Shotgun Spread
	var c8 = CardData.new()
	c8.id = "shotgun_spread"
	c8.title = "Buckshot Burst"
	c8.description = "Feuert 2 zusätzliche Projektile im Fächer!\n+2 Projektile, -35% Schaden."
	c8.rarity = "Rare"
	c8.color = Color(0.9, 0.4, 0.4)
	c8.multishot_add = 2
	c8.spread_angle_deg = 24.0
	c8.damage_mult = 0.65
	_register(c8)

	# 9. Cluster Bomb
	var c9 = CardData.new()
	c9.id = "cluster_bomb"
	c9.version = 2 # Explosionsradius +50 statt +35
	c9.title = "Cluster Warhead"
	c9.description = "Kugeln explodieren beim Einschlag!\n+50px Explosionsradius."
	c9.rarity = "Rare"
	c9.color = Color(0.9, 0.5, 0.1)
	c9.explosion_radius_add = 50.0
	_register(c9)

	# 10. Toxic Spores
	var c10 = CardData.new()
	c10.id = "toxic_spores"
	c10.version = 2 # nur noch Fernkampf
	c10.title = "Toxic Spores"
	c10.description = "Kugeln vergiften den Gegner.\n+3 Giftstapel."
	c10.rarity = "Rare"
	c10.color = Color(0.4, 0.9, 0.3)
	c10.poison_stacks_add = 3
	c10.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(c10)

	# 11. Frostbite
	var c11 = CardData.new()
	c11.id = "frostbite"
	c11.title = "Frostbite"
	c11.description = "Treffer verlangsamen den Gegner um 40% für 1.5s."
	c11.rarity = "Rare"
	c11.color = Color(0.3, 0.9, 1.0)
	c11.freeze_duration_add = 1.5
	_register(c11)

	# 12. Vampiric Leech
	var c12 = CardData.new()
	c12.id = "vampiric_leech"
	c12.version = 3 # Evolution A von blutdurst; nur noch Fernkampf
	c12.title = "Vampiric Leech"
	c12.description = "Lebensraub-Ausbau: Saugt Leben aus jedem Treffer.\n+15% Lebensraub."
	c12.rarity = "Rare"
	c12.color = Color(0.8, 0.1, 0.3)
	c12.family_id = "blutdurst"
	c12.parent_card_id = "blutdurst"
	c12.evolution_branch = "A"
	c12.lifesteal_percent_add = 0.15
	c12.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(c12)

	# 13. Kinetic Barrier
	var c13 = CardData.new()
	c13.id = "kinetic_barrier"
	c13.version = 2 # Max-HP/Schild-Bonus verdoppelt
	c13.title = "Kinetic Barrier"
	c13.description = "Massiver Schutzschild!\n+90 Schild."
	c13.rarity = "Rare"
	c13.color = Color(0.3, 0.5, 0.9)
	c13.shield_max_add = 90
	_register(c13)

	# 14. Sonic Dash
	var c14 = CardData.new()
	c14.id = "sonic_dash"
	c14.version = 2 # Seltenheit Rare -> Epic (Duplikat-Abgleich)
	c14.title = "Sonic Dash"
	c14.description = "Warp-Geschwindigkeit.\n-45% Dash-Abklingzeit, +20% Tempo"
	c14.rarity = "Epic"
	c14.color = Color(0.9, 0.9, 0.2)
	c14.dash_cooldown_mult = 0.55
	c14.move_speed_mult = 1.20
	_register(c14)

	# 15. Piercing Rail
	var c15 = CardData.new()
	c15.id = "piercing_rail"
	c15.title = "Piercing Rail"
	c15.description = "Geschosse durchdringen Gegner und Barrieren!\n+2 Durchschlag, +30% Projektilgeschwindigkeit"
	c15.rarity = "Rare"
	c15.color = Color(0.7, 0.4, 0.9)
	c15.piercing_add = 2
	c15.bullet_speed_mult = 1.3
	c15.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(c15)

	# 16. Ricochet Frenzy (Epic)
	var c16 = CardData.new()
	c16.id = "ricochet_frenzy"
	c16.version = 2 # Evolution A von Flipper-Modus: +3 Abpraller, +15% Projektilgeschwindigkeit
	c16.title = "Ricochet Frenzy"
	c16.description = "Abpraller-Ausbau: Absurder Flipper-Effekt!\n+3 Abpraller, +15% Projektilgeschwindigkeit, +20% Schaden pro Abpraller."
	c16.rarity = "Epic"
	c16.color = Color(0.85, 0.2, 0.85)
	c16.family_id = "flipper_modus"
	c16.parent_card_id = "flipper_modus"
	c16.evolution_branch = "A"
	c16.bounces_add = 3
	c16.bullet_speed_mult = 1.15
	_register(c16)

	# 17. Riese (Epic), früher "Colossus"
	var c17 = CardData.new()
	c17.id = "colossus"
	c17.version = 3 # Umbenannt in Riese: +50% Größe, +50% Leben, +10% Rüstung, -10% Tempo
	c17.title = "Riese"
	c17.description = "Wandle wie ein Titan.\n+50% Größe, +50% Max HP, +10% Rüstung, -10% Tempo."
	c17.rarity = "Epic"
	c17.color = Color(0.8, 0.5, 0.2)
	c17.max_hp_mult = 1.50
	c17.giant_growth = 0.50
	c17.armor_percent_add = 0.10
	c17.move_speed_mult = 0.90
	_register(c17)

	# 18. Glass Cannon (Epic)
	var c18 = CardData.new()
	c18.id = "glass_cannon"
	c18.title = "Glass Cannon"
	c18.description = "Tödlich aber zerbrechlich.\n+130% Schaden, -40% Max HP, +25% Projektilgeschwindigkeit"
	c18.rarity = "Epic"
	c18.color = Color(0.95, 0.1, 0.1)
	c18.damage_mult = 2.30
	c18.max_hp_mult = 0.60
	c18.bullet_speed_mult = 1.25
	_register(c18)

	# 19. Gatling Surge (Epic)
	var c19 = CardData.new()
	c19.id = "gatling_surge"
	c19.title = "Gatling Surge"
	c19.description = "Unaufhaltsamer Kugelhagel!\n+70% Feuerrate, +3 Munition"
	c19.rarity = "Epic"
	c19.color = Color(0.9, 0.6, 0.1)
	c19.fire_rate_mult = 0.50
	c19.max_ammo_add = 3
	_register(c19)

	# 20. Meteor Cannon ist seit 2026-11-26 Ausbau C von Explosivschuss (siehe dort).

	# 21. Kamikaze Soul (Legendary)
	var c21 = CardData.new()
	c21.id = "kamikaze"
	c21.version = 2 # Seltenheit Legendary -> Epic (Duplikat-Abgleich)
	c21.title = "Martyrdom Shockwave"
	c21.description = "Beim K.O. explodierst du in einer gigantischen Schockwelle, die dem Gegner schweren Schaden zufügt!"
	c21.rarity = "Epic"
	c21.color = Color(1.0, 0.8, 0.1)
	c21.kamikaze = true
	_register(c21)

	# 22. Chronos Drive (Legendary)
	var c22 = CardData.new()
	c22.id = "chronos_drive"
	c22.title = "Chronos Drive"
	c22.description = "Meister der Dimensionen.\n-50% Dash-Abklingzeit, +2 Luft-Sprünge, +25% Tempo"
	c22.rarity = "Legendary"
	c22.color = Color(1.0, 0.85, 0.2)
	c22.dash_cooldown_mult = 0.50
	c22.extra_jumps_add = 2
	c22.move_speed_mult = 1.25
	_register(c22)

	# ============================================================
	# Zusätzliche globale Karten
	# Common: Grundwerte (HP, Tempo, Schaden, Abpraller)
	# Uncommon: Regeneration, Lebensraub, Größe, Projektilwerte
	# Rare: Gift, Nachladen, Tempo, Doppelsprung, viele Abpraller
	# ============================================================

	# --- Common ---

	var n3 = CardData.new()
	n3.id = "leichtfuessig"
	n3.title = "Leichtfüßig"
	n3.description = "Leichter und flinker.\n+5% Tempo, -10% Schwerkraft."
	n3.rarity = "Common"
	n3.color = Color(0.35, 0.85, 0.90)
	n3.move_speed_mult = 1.05
	n3.gravity_mult = 0.90
	_register(n3)

	var n4 = CardData.new()
	n4.id = "windschuhe"
	n4.title = "Windschuhe"
	n4.description = "Leichte-Schuhe-Ausbau: Flott unterwegs.\n+18% Tempo, +10% Sprungkraft."
	n4.rarity = "Common"
	n4.color = Color(0.30, 0.80, 0.75)
	n4.move_speed_mult = 1.18
	n4.jump_force_mult = 1.10
	n4.family_id = "leichte_schuhe"
	n4.parent_card_id = "leichte_schuhe"
	n4.evolution_branch = "A"
	_register(n4)

	var n5 = CardData.new()
	n5.id = "scharfe_munition"
	n5.version = 2 # nur noch Fernkampf
	n5.title = "Scharfe Munition"
	n5.description = "Mehr Durchschlagskraft.\n+20% Schaden."
	n5.rarity = "Common"
	n5.color = Color(0.95, 0.45, 0.25)
	n5.damage_mult = 1.20
	n5.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(n5)

	var n6 = CardData.new()
	n6.id = "wuchtgeschoss"
	n6.version = 3 # Evolution A von scharfe_munition
	n6.title = "Wuchtgeschoss"
	n6.description = "Schadens-Ausbau: Schwerer Einschlag.\n+20% Schaden, -8% Projektilgeschwindigkeit."
	n6.rarity = "Uncommon"
	n6.color = Color(0.85, 0.35, 0.20)
	n6.family_id = "scharfe_munition"
	n6.parent_card_id = "scharfe_munition"
	n6.evolution_branch = "A"
	n6.damage_mult = 1.20
	n6.bullet_speed_mult = 0.92
	_register(n6)

	var n7 = CardData.new()
	n7.id = "abpraller"
	n7.title = "Abpraller"
	n7.description = "Ein zusätzlicher Wandkontakt.\n+1 Abpraller."
	n7.rarity = "Common"
	n7.color = Color(0.80, 0.85, 0.25)
	n7.bounces_add = 1
	_register(n7)

	# --- Uncommon ---
	var n9 = CardData.new()
	n9.id = "regenerationsserum"
	n9.version = 4 # Evolution A von regenerations_modul
	n9.title = "Regenerationsserum"
	n9.description = "Regenerations-Ausbau: Stetige Heilung.\n+2,0 HP/s Regeneration."
	n9.rarity = "Uncommon"
	n9.color = Color(0.20, 0.95, 0.55)
	n9.family_id = "regenerations_modul"
	n9.parent_card_id = "regenerations_modul"
	n9.evolution_branch = "A"
	n9.hp_regen_add = 2.0
	_register(n9)

	var n10 = CardData.new()
	n10.id = "heilende_haende"
	n10.title = "Heilende Hände"
	n10.description = "Heilt auch, während du Schaden nimmst.\n+2,5 HP/s Regeneration, -8% Schaden."
	n10.rarity = "Uncommon"
	n10.color = Color(0.45, 1.00, 0.65)
	n10.hp_regen_always_add = 2.5
	n10.damage_mult = 0.92
	_register(n10)

	var n11 = CardData.new()
	n11.id = "blutdurst"
	n11.version = 2 # nur noch Fernkampf
	n11.title = "Blutdurst"
	n11.description = "Heilt dich um 12% des verursachten Projektil-Schadens."
	n11.rarity = "Uncommon"
	n11.color = Color(0.85, 0.20, 0.35)
	n11.lifesteal_percent_add = 0.12
	n11.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(n11)

	var n12 = CardData.new()
	n12.id = "vampirklinge"
	n12.version = 3 # Evolution B von blutdurst; nur noch Fernkampf
	n12.title = "Vampirklinge"
	n12.description = "Lebensraub-Ausbau: Starker Lebensraub.\n+20% Lebensraub, -10% Max HP."
	n12.rarity = "Rare"
	n12.color = Color(0.70, 0.10, 0.25)
	n12.family_id = "blutdurst"
	n12.parent_card_id = "blutdurst"
	n12.evolution_branch = "B"
	n12.lifesteal_percent_add = 0.20
	n12.max_hp_mult = 0.90
	n12.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(n12)

	var n13 = CardData.new()
	n13.id = "kompakte_statur"
	n13.version = 3 # Evolution A von kompaktkern, werte erhöht
	n13.title = "Kompakte Statur"
	n13.description = "Größen-Ausbau: Schwerer zu treffen.\n-20% Größe, +20% Tempo."
	n13.rarity = "Uncommon"
	n13.color = Color(0.55, 0.80, 1.00)
	n13.family_id = "kompaktkern"
	n13.parent_card_id = "kompaktkern"
	n13.evolution_branch = "A"
	n13.body_size_mult = 0.8
	n13.move_speed_mult = 1.2
	_register(n13)

	var n14 = CardData.new()
	n14.id = "schlanker_koerper"
	n14.version = 2 # Evolution B von kompaktkern
	n14.title = "Schlanker Körper"
	n14.description = "Größen-Ausbau: Kleineres Ziel.\n-10% Größe, +10% Sprungkraft."
	n14.rarity = "Uncommon"
	n14.color = Color(0.45, 0.70, 0.95)
	n14.family_id = "kompaktkern"
	n14.parent_card_id = "kompaktkern"
	n14.evolution_branch = "B"
	n14.body_size_mult = 0.90
	n14.jump_force_mult = 1.10
	_register(n14)

	var n16 = CardData.new()
	n16.id = "splitterladung"
	n16.version = 2 # Evolution A von splittergeschoss
	n16.title = "Splitterladung"
	n16.description = "Mehrfachschuss-Ausbau: Enge, schnelle Salve.\n+1 Projektil, +15% Projektilgeschwindigkeit, -5% Schaden pro Kugel."
	n16.rarity = "Rare"
	n16.color = Color(0.70, 0.75, 1.00)
	n16.family_id = "splittergeschoss"
	n16.parent_card_id = "splittergeschoss"
	n16.evolution_branch = "A"
	n16.multishot_add = 1
	n16.spread_angle_deg = 2.0
	n16.bullet_speed_mult = 1.15
	n16.damage_mult = 0.95
	_register(n16)

	var n18 = CardData.new()
	n18.id = "railgun_munition"
	n18.version = 2 # Evolution A von scharfschuetze
	n18.title = "Railgun-Munition"
	n18.description = "Projektil-Ausbau: Extrem schnelle Geschosse.\n+30% Projektilgeschwindigkeit, +8% Schaden."
	n18.rarity = "Uncommon"
	n18.color = Color(0.30, 0.90, 0.95)
	n18.family_id = "scharfschuetze"
	n18.parent_card_id = "scharfschuetze"
	n18.evolution_branch = "A"
	n18.bullet_speed_mult = 1.30
	n18.damage_mult = 1.08
	_register(n18)

	var n20 = CardData.new()
	n20.id = "flipper_modus"
	n20.version = 2 # Seltenheit Uncommon -> Rare (Duplikat-Abgleich)
	n20.title = "Flipper-Modus"
	n20.description = "Geschosse tanzen durch die Arena.\n+3 Abpraller, +12% Projektilgeschwindigkeit."
	n20.rarity = "Rare"
	n20.color = Color(0.60, 0.95, 0.40)
	n20.bounces_add = 3
	n20.bullet_speed_mult = 1.12
	_register(n20)

	# Projektil-Schwerkraft: flache Präzisionsschüsse oder fallende Wucht.
	var ug1 = CardData.new()
	ug1.id = "leichtes_geschoss"
	ug1.title = "Leichtes Geschoss"
	ug1.description = "Flache, schnelle Flugbahn.\n+10% Schaden, -35% Projektil-Schwerkraft, +10% Projektilgeschwindigkeit."
	ug1.rarity = "Uncommon"
	ug1.color = Color(0.35, 0.90, 1.00)
	ug1.damage_mult = 1.10
	ug1.projectile_gravity_mult = 0.65
	ug1.bullet_speed_mult = 1.10
	_register(ug1)

	var ug2 = CardData.new()
	ug2.id = "schweres_geschoss"
	ug2.title = "Schweres Geschoss"
	ug2.description = "Wuchtige, fallende Geschosse.\n+20% Schaden, +45% Projektil-Schwerkraft, +10% Projektilgröße."
	ug2.rarity = "Uncommon"
	ug2.color = Color(0.90, 0.55, 0.25)
	ug2.damage_mult = 1.20
	ug2.projectile_gravity_mult = 1.45
	ug2.bullet_size_mult = 1.10
	_register(ug2)

	# --- Rückstoß ---
	# Treffer drücken Gegner spürbar weg. Der Multiplikator wirkt auf alle vom
	# Spieler verursachten Rückstöße, also Projektile, Explosionen und Fähigkeiten.
	var kb1 = CardData.new()
	kb1.id = "rueckstossfeder"
	kb1.title = "Rückstoßfeder"
	kb1.description = "Federnde Treffer drücken Gegner weg.\n+25% Rückstoß."
	kb1.rarity = "Common"
	kb1.color = Color(0.30, 0.90, 0.85)
	kb1.family_id = "rueckstossfeder"
	kb1.knockback_mult = 1.25
	_register(kb1)

	var kb2 = CardData.new()
	kb2.id = "druckkammer"
	kb2.title = "Druckkammer"
	kb2.description = "Rückstoß-Ausbau: Mehr Druck pro Schuss.\n+35% Rückstoß, +10% Projektilgeschwindigkeit."
	kb2.rarity = "Rare"
	kb2.color = Color(0.95, 0.65, 0.20)
	kb2.family_id = "rueckstossfeder"
	kb2.parent_card_id = "rueckstossfeder"
	kb2.evolution_branch = "A"
	kb2.knockback_mult = 1.35
	kb2.bullet_speed_mult = 1.10
	_register(kb2)

	var kb3 = CardData.new()
	kb3.id = "schockgeschoss"
	kb3.title = "Schockgeschoss"
	kb3.description = "Rückstoß-Ausbau: Wuchtige Einschläge.\n+45% Rückstoß, +8% Schaden."
	kb3.rarity = "Rare"
	kb3.color = Color(0.85, 0.35, 0.95)
	kb3.family_id = "rueckstossfeder"
	kb3.parent_card_id = "rueckstossfeder"
	kb3.evolution_branch = "B"
	kb3.knockback_mult = 1.45
	kb3.damage_mult = 1.08
	_register(kb3)

	# --- Rare ---
	var n21 = CardData.new()
	n21.id = "giftklinge"
	n21.version = 2 # Seltenheit Rare -> Epic (Duplikat-Abgleich)
	n21.title = "Nervengift"
	n21.description = "Stärkeres Gift.\n+50% Giftschaden, +2 Giftstapel."
	n21.rarity = "Epic"
	n21.color = Color(0.45, 0.95, 0.25)
	n21.poison_damage_mult = 1.50
	n21.poison_stacks_add = 2
	_register(n21)

	var n22 = CardData.new()
	n22.id = "aetzende_salve"
	n22.title = "Ätzende Salve"
	n22.description = "Verätzt den Gegner.\n+75% Giftschaden, +1 Giftstapel."
	n22.rarity = "Rare"
	n22.color = Color(0.30, 1.00, 0.15)
	n22.poison_damage_mult = 1.75
	n22.poison_stacks_add = 1
	_register(n22)

	var n24 = CardData.new()
	n24.id = "schnelllader"
	n24.title = "Schnelllader"
	n24.description = "Schneller wieder schussbereit.\n+35% Nachladegeschwindigkeit."
	n24.rarity = "Rare"
	n24.color = Color(0.95, 0.75, 0.20)
	n24.reload_speed_mult = 1.35
	_register(n24)

	var n25 = CardData.new()
	n25.id = "taktisches_magazin"
	n25.title = "Taktisches Magazin"
	n25.description = "Optimierter Nachladevorgang.\n+55% Nachladegeschwindigkeit, -10% Feuerrate."
	n25.rarity = "Rare"
	n25.color = Color(0.90, 0.65, 0.15)
	n25.reload_speed_mult = 1.55
	n25.fire_rate_mult = 1.10
	_register(n25)

	var n26 = CardData.new()
	n26.id = "windlaeufer"
	n26.title = "Windläufer"
	n26.description = "Deutlich schneller.\n+25% Tempo."
	n26.rarity = "Rare"
	n26.color = Color(0.30, 0.90, 0.80)
	n26.move_speed_mult = 1.25
	_register(n26)

	var n27 = CardData.new()
	n27.id = "blitzfuesse"
	n27.title = "Blitzfüße"
	n27.description = "Maximale Mobilität.\n+35% Tempo, -10% Max HP."
	n27.rarity = "Rare"
	n27.color = Color(0.20, 0.80, 1.00)
	n27.move_speed_mult = 1.35
	n27.max_hp_mult = 0.90
	_register(n27)

	var n32 = CardData.new()
	n32.id = "flummi_kern"
	n32.version = 3 # Evolution B von Flipper-Modus: +3 Abpraller, +15% Projektilgröße
	n32.title = "Flummi-Kern"
	n32.description = "Abpraller-Ausbau: Große, springende Geschosse.\n+3 Abpraller, +15% Projektilgröße."
	n32.rarity = "Epic"
	n32.color = Color(0.95, 0.50, 0.95)
	n32.family_id = "flipper_modus"
	n32.parent_card_id = "flipper_modus"
	n32.evolution_branch = "B"
	n32.bounces_add = 3
	n32.bullet_size_mult = 1.15
	_register(n32)

	# ============================================================
	# Talentbaum-Karten
	# Jede Grundkarte hat zwei Ausbauzweige. Ausbaukarten erscheinen nur,
	# wenn der Spieler die Grundkarte bereits besitzt.
	# ============================================================

	# --- Turm ---
	var tb1 = CardData.new()
	tb1.id = "turm"
	tb1.title = "Turm"
	tb1.description = "Spezialfähigkeit platziert zusätzlich einen Turm, der automatisch Gegner angreift. Türme verlieren 5% ihres Lebens pro Sekunde (max. 20 s)."
	tb1.rarity = "Epic"
	tb1.version = 2
	tb1.color = Color(0.45, 0.80, 1.00)
	tb1.family_id = "turm"
	tb1.tower_enabled = true
	_register(tb1)

	var tb2 = CardData.new()
	tb2.id = "turm_mehr"
	tb2.title = "Mehr Türme"
	tb2.description = "Turm-Ausbau: Erzeugt alle 5 Sekunden einen weiteren Turm an deiner aktuellen Position."
	tb2.rarity = "Legendary"
	tb2.color = Color(0.55, 0.90, 1.00)
	tb2.family_id = "turm"
	tb2.parent_card_id = "turm"
	tb2.evolution_branch = "A"
	tb2.tower_auto_spawn = true
	_register(tb2)

	var tb3 = CardData.new()
	tb3.id = "turm_folgen"
	tb3.title = "Folgende Türme"
	tb3.description = "Turm-Ausbau: Türme folgen deiner Spielfigur und greifen weiterhin automatisch an."
	tb3.rarity = "Legendary"
	tb3.color = Color(0.35, 0.70, 0.95)
	tb3.family_id = "turm"
	tb3.parent_card_id = "turm"
	tb3.evolution_branch = "B"
	tb3.tower_follow = true
	_register(tb3)

	# Turm-Karten erscheinen nur, wenn die Turm-Fähigkeit bereits im Deck liegt.
	var tp1 = CardData.new()
	tp1.id = "turm_panzerung"
	tp1.title = "Turm-Panzerung"
	tp1.description = "Turm-Karte: Deine Türme erhalten +75 Leben (halten mehr Treffer aus, Lebensdauer bleibt max. 20 s)."
	tp1.rarity = "Rare"
	tp1.version = 2
	tp1.pool = "Defensive"
	tp1.color = Color(0.55, 0.72, 0.85)
	tp1.required_mechanic = "tower"
	tp1.tower_max_health_add = 75
	_register(tp1)

	var tp2 = CardData.new()
	tp2.id = "turm_schnellfeuer"
	tp2.title = "Schnellfeuer-Geschütz"
	tp2.description = "Turm-Karte: Deine Türme feuern 25% schneller."
	tp2.rarity = "Rare"
	tp2.pool = "Offensive"
	tp2.color = Color(0.45, 0.88, 1.00)
	tp2.required_mechanic = "tower"
	tp2.tower_fire_rate_mult = 0.8
	_register(tp2)

	# --- Giftschuss ---
	var gb1 = CardData.new()
	gb1.id = "giftschuss"
	gb1.version = 2 # nur noch Fernkampf
	gb1.title = "Giftschuss"
	gb1.description = "Geschosse vergiften Gegner.\n+2 Giftstapel, +25% Giftschaden."
	gb1.rarity = "Rare"
	gb1.color = Color(0.40, 0.95, 0.25)
	gb1.family_id = "giftschuss"
	gb1.poison_stacks_add = 2
	gb1.poison_damage_mult = 1.25
	gb1.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(gb1)

	var gb2 = CardData.new()
	gb2.id = "giftschuss_wolke"
	gb2.title = "Giftwolke"
	gb2.description = "Giftschuss-Ausbau: Bei jedem Einschlag entsteht eine Giftwolke an der Einschlagstelle."
	gb2.rarity = "Epic"
	gb2.color = Color(0.30, 1.00, 0.15)
	gb2.family_id = "giftschuss"
	gb2.parent_card_id = "giftschuss"
	gb2.evolution_branch = "A"
	gb2.poison_impact_cloud = true
	_register(gb2)

	var gb3 = CardData.new()
	gb3.id = "giftschuss_spur"
	gb3.version = 2 # nur noch Fernkampf
	gb3.title = "Giftspur"
	gb3.description = "Giftschuss-Ausbau: Hinterlässt eine Giftspur. Sie schadet dir selbst nicht."
	gb3.rarity = "Epic"
	gb3.color = Color(0.50, 0.90, 0.20)
	gb3.family_id = "giftschuss"
	gb3.parent_card_id = "giftschuss"
	gb3.evolution_branch = "B"
	gb3.poison_trail = true
	gb3.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(gb3)

	# --- Blitzschuss ---
	var lb1 = CardData.new()
	lb1.id = "blitzschuss"
	lb1.version = 2 # nur noch Fernkampf
	lb1.title = "Blitzschuss"
	lb1.description = "Blitzangriff, der Gegner für 0,1 Sekunden betäubt."
	lb1.rarity = "Rare"
	lb1.color = Color(1.00, 0.90, 0.20)
	lb1.family_id = "blitzschuss"
	lb1.lightning_shot = true
	lb1.damage_mult = 1.05
	lb1.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(lb1)


	var lb3 = CardData.new()
	lb3.id = "blitzschuss_zone"
	lb3.title = "Blitz-Orb"
	lb3.description = "Blitzschuss-Ausbau: Erzeugt am Einschlag eine Blitzzone, die Gegner beim Betreten betäubt."
	lb3.rarity = "Epic"
	lb3.color = Color(0.90, 0.75, 1.00)
	lb3.family_id = "blitzschuss"
	lb3.parent_card_id = "blitzschuss"
	lb3.evolution_branch = "A" # seit Kettenblitz eigene Grundkarte ist (2026-11-26)
	lb3.lightning_zone = true
	_register(lb3)

	# --- Frostschuss ---
	var fb1 = CardData.new()
	fb1.id = "frostschuss"
	fb1.version = 2 # nur noch Fernkampf
	fb1.title = "Frostschuss"
	fb1.description = "Geschosse verlangsamen Gegner für 0,8 Sekunden."
	fb1.rarity = "Uncommon"
	fb1.color = Color(0.35, 0.85, 1.00)
	fb1.family_id = "frostschuss"
	fb1.freeze_duration_add = 0.8
	fb1.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(fb1)

	var fb2 = CardData.new()
	fb2.id = "frostschuss_nova"
	fb2.title = "Eisnova"
	fb2.description = "Frostschuss-Ausbau: Beim Einschlag entsteht eine Eisnova, die Gegner in der Nähe einfriert."
	fb2.rarity = "Rare"
	fb2.color = Color(0.55, 0.90, 1.00)
	fb2.family_id = "frostschuss"
	fb2.parent_card_id = "frostschuss"
	fb2.evolution_branch = "A"
	fb2.frost_nova = true
	fb2.freeze_duration_add = 0.4
	_register(fb2)

	var fb3 = CardData.new()
	fb3.id = "frostschuss_spur"
	fb3.version = 2 # nur noch Fernkampf
	fb3.title = "Eisbahn"
	fb3.description = "Frostschuss-Ausbau: Hinterlässt eine Eisbahn, die Gegner verlangsamt."
	fb3.rarity = "Rare"
	fb3.color = Color(0.45, 0.80, 0.95)
	fb3.family_id = "frostschuss"
	fb3.parent_card_id = "frostschuss"
	fb3.evolution_branch = "B"
	fb3.frost_trail = true
	fb3.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(fb3)

	# --- Explosivschuss ---
	var eb1 = CardData.new()
	eb1.id = "explosivschuss"
	eb1.title = "Explosivschuss"
	eb1.description = "Geschosse explodieren beim Einschlag.\n+30px Explosionsradius, +5% Schaden."
	eb1.rarity = "Uncommon"
	eb1.color = Color(1.00, 0.50, 0.15)
	eb1.family_id = "explosivschuss"
	eb1.explosion_radius_add = 30.0
	eb1.damage_mult = 1.05
	_register(eb1)

	var eb2 = CardData.new()
	eb2.id = "explosivschuss_kern"
	eb2.title = "Großer Knall"
	eb2.description = "Explosivschuss-Ausbau: +60px Explosionsradius und +15% Schaden."
	eb2.rarity = "Rare"
	eb2.color = Color(1.00, 0.35, 0.05)
	eb2.family_id = "explosivschuss"
	eb2.parent_card_id = "explosivschuss"
	eb2.evolution_branch = "A"
	eb2.explosion_radius_add = 60.0
	eb2.damage_mult = 1.15
	_register(eb2)

	var eb3 = CardData.new()
	eb3.id = "explosivschuss_splitter"
	eb3.title = "Splitterbomben"
	eb3.description = "Explosivschuss-Ausbau: Explosionen zerfallen in vier kleine Splitterbomben."
	eb3.rarity = "Rare"
	eb3.color = Color(0.95, 0.65, 0.10)
	eb3.family_id = "explosivschuss"
	eb3.parent_card_id = "explosivschuss"
	eb3.evolution_branch = "B"
	eb3.cluster_bomblets = true
	_register(eb3)

	# Meteor Cannon war eine eigene Epic-Karte mit demselben Effekt wie
	# Explosivschuss und ist seit 2026-11-26 dessen Ausbau C. Werte unverändert,
	# kommen jetzt aber zur Grundkarte dazu.
	var eb4 = CardData.new()
	eb4.id = "meteor_cannon"
	eb4.version = 2 # Ausbau C von Explosivschuss (vorher eigene Karte)
	eb4.title = "Meteor Cannon"
	eb4.description = "Explosivschuss-Ausbau: Riesige verheerende Explosion!\n+75px Explosionsradius, +60% Schaden, -30% Feuerrate"
	eb4.rarity = "Epic"
	eb4.color = Color(0.95, 0.3, 0.0)
	eb4.family_id = "explosivschuss"
	eb4.parent_card_id = "explosivschuss"
	eb4.evolution_branch = "C"
	eb4.explosion_radius_add = 75.0
	eb4.damage_mult = 1.60
	eb4.fire_rate_mult = 1.30
	_register(eb4)

	# --- Feuersturm ---
	# Seit v3 mit der früheren Einzelkarte Brandkapsel verschmolzen: Die
	# Grundkarte entzündet Gegner und den Boden. Ausbau A = mehr Feuerschaden,
	# B (Brandkapsel) = größere Feuerflächen, C = Feuerspur.
	var rb1 = CardData.new()
	rb1.id = "feuersturm"
	rb1.version = 3 # mit Brandkapsel verschmolzen: +Feuerzone, Episch, +10% Schaden
	rb1.title = "Feuersturm"
	rb1.description = "Geschosse entzünden Gegner und setzen beim Einschlag den Boden in Brand.\n+Feuerzone, +10% Schaden."
	rb1.rarity = "Epic"
	rb1.color = Color(1.00, 0.35, 0.10)
	rb1.family_id = "feuersturm"
	rb1.fire_shot = true
	rb1.fire_impact_zone = true
	rb1.damage_mult = 1.10
	rb1.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(rb1)

	var rb2 = CardData.new()
	rb2.id = "feuersturm_brandherd"
	rb2.version = 2 # jetzt Ausbau A: mehr Feuerschaden statt Feuerzone
	rb2.title = "Brandherd"
	rb2.description = "Feuersturm-Ausbau: Das Feuer brennt heißer. +60% Feuerschaden (Treffer, Feuerflächen, Spur)."
	rb2.rarity = "Epic"
	rb2.color = Color(1.00, 0.20, 0.05)
	rb2.family_id = "feuersturm"
	rb2.parent_card_id = "feuersturm"
	rb2.evolution_branch = "A"
	rb2.fire_damage_mult = 1.6
	_register(rb2)

	var rb_b = CardData.new()
	rb_b.id = "brandkapsel" # frühere Einzelkarte, seit 2026-11-25 Ausbau B von Feuersturm
	rb_b.version = 2 # Ausbau B: größere Feuerflächen
	rb_b.title = "Brandkapsel"
	rb_b.description = "Feuersturm-Ausbau: Das Feuer breitet sich weiter aus. +60% Feuerreichweite (Feuerflächen und Spur)."
	rb_b.rarity = "Epic"
	rb_b.color = Color(1.00, 0.40, 0.10)
	rb_b.family_id = "feuersturm"
	rb_b.parent_card_id = "feuersturm"
	rb_b.evolution_branch = "B"
	rb_b.fire_zone_radius_mult = 1.6
	_register(rb_b)

	var rb3 = CardData.new()
	rb3.id = "feuersturm_spur"
	rb3.version = 3 # Zweig C (A/B sind jetzt Feuerschaden/Feuerreichweite)
	rb3.title = "Feuerspur"
	rb3.description = "Feuersturm-Ausbau: Hinterlässt eine brennende Spur. Sie schadet dir selbst nicht."
	rb3.rarity = "Epic"
	rb3.color = Color(1.00, 0.50, 0.10)
	rb3.family_id = "feuersturm"
	rb3.parent_card_id = "feuersturm"
	rb3.evolution_branch = "C"
	rb3.fire_trail = true
	rb3.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(rb3)

	# --- Wächterdrohne ---
	var db1 = CardData.new()
	db1.id = "waechterdrohne"
	db1.title = "Wächterdrohne"
	db1.description = "Eine Drohne umkreist dich und greift Gegner automatisch an."
	db1.rarity = "Rare"
	db1.color = Color(0.40, 0.75, 1.00)
	db1.family_id = "waechterdrohne"
	db1.drone_count_add = 1
	_register(db1)

	var db2 = CardData.new()
	db2.id = "waechterdrohne_zwilling"
	db2.title = "Zwillingsdrohne"
	db2.description = "Wächterdrohnen-Ausbau: Eine zweite Drohne begleitet dich."
	db2.rarity = "Epic"
	db2.color = Color(0.30, 0.65, 0.95)
	db2.family_id = "waechterdrohne"
	db2.parent_card_id = "waechterdrohne"
	db2.evolution_branch = "A"
	db2.drone_count_add = 1
	_register(db2)

	var db3 = CardData.new()
	db3.id = "waechterdrohne_schild"
	db3.title = "Regenerationsdrohne"
	db3.description = "Wächterdrohnen-Ausbau: Deine Drohnen regenerieren laufend deine Lebenspunkte."
	db3.rarity = "Epic"
	db3.color = Color(0.55, 0.85, 1.00)
	db3.family_id = "waechterdrohne"
	db3.parent_card_id = "waechterdrohne"
	db3.evolution_branch = "B"
	db3.drone_guardian = true
	_register(db3)

	# --- Schutzdrohne ---
	# Eigene Familie: Schutzdrohnen schießen nicht, sondern fangen gegnerische
	# Projektile ab. Ausbau A heilt um den abgefangenen Schaden, Ausbau B
	# verstärkt den Schwarm um zwei weitere Drohnen.
	var sd1 = CardData.new()
	sd1.id = "schutzdrohne"
	sd1.title = "Schutzdrohne"
	sd1.description = "Eine Schutzdrohne umkreist dich und fängt gegnerische Schüsse ab."
	sd1.rarity = "Rare"
	sd1.pool = "Defensive"
	sd1.color = Color(0.45, 0.90, 1.00)
	sd1.family_id = "schutzdrohne"
	sd1.blocker_drone_count_add = 1
	_register(sd1)

	var sd2 = CardData.new()
	sd2.id = "schutzdrohne_heilung"
	sd2.title = "Heilende Schutzdrohne"
	sd2.description = "Schutzdrohnen-Ausbau: Heilt dich um den Schaden abgefangener Schüsse."
	sd2.rarity = "Epic"
	sd2.color = Color(0.35, 1.00, 0.65)
	sd2.family_id = "schutzdrohne"
	sd2.parent_card_id = "schutzdrohne"
	sd2.evolution_branch = "A"
	sd2.blocker_drone_heal = true
	_register(sd2)

	var sd3 = CardData.new()
	sd3.id = "schutzdrohne_schwarm"
	sd3.title = "Schutzdrohnen-Schwarm"
	sd3.description = "Schutzdrohnen-Ausbau: Zwei weitere Schutzdrohnen kreisen um dich."
	sd3.rarity = "Epic"
	sd3.color = Color(0.30, 0.75, 1.00)
	sd3.family_id = "schutzdrohne"
	sd3.parent_card_id = "schutzdrohne"
	sd3.evolution_branch = "B"
	sd3.blocker_drone_count_add = 2
	_register(sd3)

	# --- Mörser ---
	# Der Mörser tauscht eine flache Flugbahn gegen schwere, bogenförmige
	# Geschosse mit Flächenschaden. Ausbau A flacht den Bogen wieder ab,
	# Ausbau B macht ihn steiler und explosionsstärker.
	var mg1 = CardData.new()
	mg1.id = "moerser"
	mg1.title = "Mörser"
	mg1.description = "Schwere, bogenförmige Geschosse.\n+80% Projektil-Schwerkraft, +25% Schaden, +18px Explosionsradius."
	mg1.rarity = "Rare"
	mg1.color = Color(0.95, 0.55, 0.15)
	mg1.family_id = "moerser"
	mg1.projectile_gravity_mult = 1.80
	mg1.damage_mult = 1.25
	mg1.explosion_radius_add = 18.0
	mg1.bullet_size_mult = 1.15
	_register(mg1)

	var mg2 = CardData.new()
	mg2.id = "moerser_praezision"
	mg2.title = "Präzisionsmörser"
	mg2.description = "Mörser-Ausbau: Flachere, schnellere Geschosse.\n+30% Schaden, -45% Projektil-Schwerkraft, +20% Projektilgeschwindigkeit."
	mg2.rarity = "Epic"
	mg2.color = Color(0.55, 0.85, 1.00)
	mg2.family_id = "moerser"
	mg2.parent_card_id = "moerser"
	mg2.evolution_branch = "A"
	mg2.projectile_gravity_mult = 0.55
	mg2.damage_mult = 1.30
	mg2.bullet_speed_mult = 1.20
	mg2.explosion_radius_add = 8.0
	_register(mg2)

	var mg3 = CardData.new()
	mg3.id = "moerser_belagerung"
	mg3.title = "Belagerungsmörser"
	mg3.description = "Mörser-Ausbau: Extrem steile Geschosse.\n+40% Schaden, +50% Projektil-Schwerkraft, +30px Explosionsradius."
	mg3.rarity = "Epic"
	mg3.color = Color(1.00, 0.35, 0.10)
	mg3.family_id = "moerser"
	mg3.parent_card_id = "moerser"
	mg3.evolution_branch = "B"
	mg3.projectile_gravity_mult = 1.50
	mg3.damage_mult = 1.40
	mg3.explosion_radius_add = 30.0
	_register(mg3)

	# ============================================================
	# Klassenspezifische Upgrade-Karten
	# Erscheinen nur im Draft des passenden Helden (hero_id).
	# ============================================================

	# --- Ignis: Pyro Skirmisher ---
	var i1 = CardData.new()
	i1.id = "ignis_afterburner"
	i1.title = "Nachbrenner"
	i1.description = "Ignis: +20% Tempo, -20% Dash-Abklingzeit, +15% Sprungkraft."
	i1.rarity = "Rare"
	i1.color = Color(1.0, 0.45, 0.15)
	i1.hero_id = "ignis"
	i1.move_speed_mult = 1.20
	i1.dash_cooldown_mult = 0.80
	i1.jump_force_mult = 1.15
	_register(i1)

	var i2 = CardData.new()
	i2.id = "ignis_blast_core"
	i2.title = "Sprengkern"
	i2.description = "Ignis: +45px Explosionsradius, +25% Schaden, -10% Feuerrate."
	i2.rarity = "Epic"
	i2.color = Color(1.0, 0.3, 0.05)
	i2.hero_id = "ignis"
	i2.explosion_radius_add = 45.0
	i2.damage_mult = 1.25
	i2.fire_rate_mult = 1.10
	_register(i2)

	var i3 = CardData.new()
	i3.id = "ignis_overheat"
	i3.title = "Überhitzung"
	i3.description = "Ignis: +30% Feuerrate, +25% Projektilgeschwindigkeit, -15% Fähigkeits-Abklingzeit."
	i3.rarity = "Rare"
	i3.color = Color(1.0, 0.65, 0.1)
	i3.hero_id = "ignis"
	i3.fire_rate_mult = 0.70
	i3.bullet_speed_mult = 1.25
	i3.ability_cooldown_mult = 0.85
	_register(i3)

	# --- Volt: Hyper Speedster ---
	var v1 = CardData.new()
	v1.id = "volt_overclock"
	v1.title = "Overclock"
	v1.description = "Volt: -25% Fähigkeits-Abklingzeit, +15% Tempo, +20% Feuerrate."
	v1.rarity = "Rare"
	v1.color = Color(1.0, 0.9, 0.2)
	v1.hero_id = "volt"
	v1.ability_cooldown_mult = 0.75
	v1.move_speed_mult = 1.15
	v1.fire_rate_mult = 0.80
	_register(v1)

	var v2 = CardData.new()
	v2.id = "volt_static_field"
	v2.title = "Statisches Feld"
	v2.description = "Volt: +2 Abpraller, +30% Projektilgeschwindigkeit, +1 Durchschlag."
	v2.rarity = "Rare"
	v2.color = Color(0.8, 1.0, 0.3)
	v2.hero_id = "volt"
	v2.bounces_add = 2
	v2.bullet_speed_mult = 1.30
	v2.piercing_add = 1
	v2.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(v2)

	var v3 = CardData.new()
	v3.id = "volt_kinetic_charge"
	v3.title = "Kinetische Ladung"
	v3.description = "Volt: -35% Dash-Abklingzeit, +1 Luft-Sprung, +20% Tempo."
	v3.rarity = "Epic"
	v3.color = Color(1.0, 0.8, 0.1)
	v3.hero_id = "volt"
	v3.dash_cooldown_mult = 0.65
	v3.extra_jumps_add = 1
	v3.move_speed_mult = 1.20
	_register(v3)

	# --- Spore: Toxic Alchemist ---
	var s1 = CardData.new()
	s1.id = "spore_virulent"
	s1.title = "Virulenter Stamm"
	s1.description = "Spore: +4 Giftstapel, +15% Schaden."
	s1.rarity = "Rare"
	s1.color = Color(0.35, 0.95, 0.25)
	s1.hero_id = "spore"
	s1.poison_stacks_add = 4
	s1.damage_mult = 1.15
	_register(s1)

	var s2 = CardData.new()
	s2.id = "spore_mycelium"
	s2.version = 2 # Max-HP/Schild-Bonus verdoppelt
	s2.title = "Mycelnetz"
	s2.description = "Spore: +70 Max HP, +50 Schild, +20% Schild-Regeneration."
	s2.rarity = "Rare"
	s2.color = Color(0.45, 0.85, 0.35)
	s2.hero_id = "spore"
	s2.max_hp_flat = 70
	s2.shield_max_add = 50
	s2.shield_regen_mult = 1.20
	_register(s2)

	var s3 = CardData.new()
	s3.id = "spore_toxic_bloom"
	s3.title = "Toxische Blüte"
	s3.description = "Spore: +3 Giftstapel, +45px Explosionsradius, +15% Lebensraub."
	s3.rarity = "Epic"
	s3.color = Color(0.6, 1.0, 0.25)
	s3.hero_id = "spore"
	s3.poison_stacks_add = 3
	s3.explosion_radius_add = 45.0
	s3.lifesteal_percent_add = 0.15
	_register(s3)

	# ============================================================
	# Zusätzliche Basis-Karten (Common / Uncommon)
	# ============================================================

	# --- Common ---
	var bc1 = CardData.new()
	bc1.id = "zaeher_kern"
	bc1.version = 2 # Max-HP/Schild-Bonus verdoppelt
	bc1.title = "Zäher Kern"
	bc1.description = "Robuster Körperbau.\n+24% Max HP."
	bc1.rarity = "Common"
	bc1.color = Color(0.30, 0.80, 0.42)
	bc1.max_hp_mult = 1.24
	_register(bc1)

	var bc2 = CardData.new()
	bc2.id = "ausdauer_lunge"
	bc2.version = 2 # von 12% auf 50% erhöht
	bc2.title = "Ausdauerlunge"
	bc2.description = "Mehr Sprungkraft.\n+50% Sprungkraft."
	bc2.rarity = "Common"
	bc2.color = Color(0.60, 0.85, 0.55)
	bc2.jump_force_mult = 1.5
	_register(bc2)

	var bc3 = CardData.new()
	bc3.id = "leichte_schuhe"
	bc3.title = "Leichte Schuhe"
	bc3.description = "Flotter unterwegs.\n+10% Tempo."
	bc3.rarity = "Common"
	bc3.color = Color(0.35, 0.80, 0.90)
	bc3.move_speed_mult = 1.10
	_register(bc3)

	var bc4 = CardData.new()
	bc4.id = "scharfschuetze"
	bc4.version = 2 # +30% Projektilgeschwindigkeit statt +12% (Jochen)
	bc4.title = "Scharfschütze"
	bc4.description = "Schnellere Geschosse.\n+30% Projektilgeschwindigkeit."
	bc4.rarity = "Common"
	bc4.color = Color(0.30, 0.85, 0.95)
	bc4.bullet_speed_mult = 1.30
	_register(bc4)

	var bc5 = CardData.new()
	bc5.id = "grosses_magazin"
	bc5.title = "Großes Magazin"
	bc5.description = "Mehr Munition.\n+1 Munition."
	bc5.rarity = "Common"
	bc5.color = Color(0.90, 0.75, 0.30)
	bc5.max_ammo_add = 1
	_register(bc5)

	var bc9 = CardData.new()
	bc9.id = "grobkaliber"
	bc9.title = "Grobkaliber"
	bc9.description = "Größere Projektile.\n+15% Projektilgröße."
	bc9.rarity = "Common"
	bc9.color = Color(0.85, 0.55, 0.30)
	bc9.bullet_size_mult = 1.15
	_register(bc9)

	var bc10 = CardData.new()
	bc10.id = "stabilisator"
	bc10.version = 2 # Evolution B von abpraller
	bc10.title = "Stabilisator"
	bc10.description = "Abpraller-Ausbau: Schwere, stabile Kugeln.\n+1 Abpraller, +15% Projektilgröße."
	bc10.rarity = "Uncommon"
	bc10.color = Color(0.70, 0.85, 0.35)
	bc10.family_id = "abpraller"
	bc10.parent_card_id = "abpraller"
	bc10.evolution_branch = "B"
	bc10.bounces_add = 1
	bc10.bullet_size_mult = 1.15
	_register(bc10)

	var bc11 = CardData.new()
	bc11.id = "frostartig"
	bc11.title = "Frostartig"
	bc11.description = "Leichte Verlangsamung.\n+0,4s Einfrierdauer."
	bc11.rarity = "Common"
	bc11.color = Color(0.50, 0.85, 0.95)
	bc11.freeze_duration_add = 0.4
	_register(bc11)

	var bc12 = CardData.new()
	bc12.id = "giftkapsel"
	bc12.title = "Giftkapsel"
	bc12.description = "Schwaches Gift.\n+1 Giftstapel, +10% Giftschaden."
	bc12.rarity = "Common"
	bc12.color = Color(0.45, 0.90, 0.30)
	bc12.poison_stacks_add = 1
	bc12.poison_damage_mult = 1.10
	_register(bc12)

	var bc14 = CardData.new()
	bc14.id = "kompaktkern"
	bc14.title = "Kompaktkern"
	bc14.description = "Kleineres Ziel.\n-10% Größe."
	bc14.rarity = "Common"
	bc14.color = Color(0.55, 0.75, 0.95)
	bc14.body_size_mult = 0.90
	_register(bc14)

	var bc16 = CardData.new()
	bc16.id = "ausweichrolle"
	bc16.title = "Ausweichrolle"
	bc16.description = "Schneller wieder bereit.\n-15% Dash-Abklingzeit, +6% Tempo."
	bc16.rarity = "Common"
	bc16.color = Color(0.75, 0.85, 0.45)
	bc16.dash_cooldown_mult = 0.85
	bc16.move_speed_mult = 1.06
	bc16.required_mechanic = "dash"
	_register(bc16)

	var bc17 = CardData.new()
	bc17.id = "hartschale"
	bc17.version = 2 # Max-HP/Schild-Bonus verdoppelt
	bc17.title = "Hartschale"
	bc17.description = "Mehr Schild.\n+40 Schild."
	bc17.rarity = "Common"
	bc17.color = Color(0.40, 0.65, 0.90)
	bc17.shield_max_add = 40
	_register(bc17)

	var bc18 = CardData.new()
	bc18.id = "schnellfeuer"
	bc18.version = 2 # nur noch Fernkampf
	bc18.title = "Schnellfeuer"
	bc18.description = "Dauerfeuer.\n+18% Feuerrate."
	bc18.rarity = "Common"
	bc18.color = Color(0.95, 0.70, 0.20)
	bc18.fire_rate_mult = 0.82
	bc18.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(bc18)

	var bc19 = CardData.new()
	bc19.id = "federgewicht"
	bc19.title = "Federgewicht"
	bc19.description = "Leicht und schnell.\n+8% Tempo, -5% Größe."
	bc19.rarity = "Common"
	bc19.color = Color(0.50, 0.80, 0.95)
	bc19.move_speed_mult = 1.08
	bc19.body_size_mult = 0.95
	_register(bc19)

	var bc20 = CardData.new()
	bc20.id = "durchschlag"
	bc20.title = "Durchschlag"
	bc20.description = "Durchschlägt Gegner und dünne Wände.\n+1 Durchschlag."
	bc20.rarity = "Common"
	bc20.color = Color(0.80, 0.50, 0.85)
	bc20.piercing_add = 1
	bc20.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(bc20)

	# --- Uncommon ---
	var bu1 = CardData.new()
	bu1.id = "lebensquell"
	bu1.version = 3 # Evolution A von zaeher_kern
	bu1.title = "Lebensquell"
	bu1.description = "Leben-Ausbau: Deutlich mehr Leben.\n+20% Max HP."
	bu1.rarity = "Uncommon"
	bu1.color = Color(0.25, 0.90, 0.50)
	bu1.family_id = "zaeher_kern"
	bu1.parent_card_id = "zaeher_kern"
	bu1.evolution_branch = "A"
	bu1.max_hp_mult = 1.20
	_register(bu1)

	var bu2 = CardData.new()
	bu2.id = "regenerations_modul"
	bu2.version = 3 # Seltenheit Uncommon -> Common (Duplikat-Abgleich)
	bu2.title = "Regenerationsmodul"
	bu2.description = "Langsame Heilung.\n+2 HP/s Regeneration."
	bu2.rarity = "Common"
	bu2.color = Color(0.20, 0.95, 0.60)
	bu2.hp_regen_add = 2.0
	_register(bu2)

	var bu3 = CardData.new()
	bu3.id = "schildverstaerker"
	bu3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	bu3.title = "Schildverstärker"
	bu3.description = "Massiver Schild.\n+60 Schild."
	bu3.rarity = "Uncommon"
	bu3.color = Color(0.30, 0.60, 1.00)
	bu3.shield_max_add = 60
	_register(bu3)

	var bu4 = CardData.new()
	bu4.id = "schildschnellbau"
	bu4.title = "Schildschnellbau"
	bu4.description = "Schild lädt viel schneller.\n+40% Schild-Regeneration."
	bu4.rarity = "Uncommon"
	bu4.color = Color(0.40, 0.75, 1.00)
	bu4.shield_regen_mult = 1.40
	bu4.required_mechanic = "shield"
	_register(bu4)

	# Schild-Cooldown (Pause nach Schaden) verkürzen. Erscheinen erst ab 25 Schild (required_mechanic).
	var sp1 = CardData.new()
	sp1.id = "schildkondensator"
	sp1.title = "Schildkondensator"
	sp1.description = "Schild lädt früher nach.\n-0,75s Schild-Cooldown nach Schaden."
	sp1.rarity = "Common"
	sp1.color = Color(0.45, 0.80, 1.00)
	sp1.shield_regen_delay_add = -0.75
	sp1.required_mechanic = "shield"
	_register(sp1)

	var sp2 = CardData.new()
	sp2.id = "schnellstart_generator"
	sp2.title = "Schnellstart-Generator"
	sp2.description = "Schild springt früher wieder an.\n-1,25s Schild-Cooldown, +20% Schild-Regeneration."
	sp2.rarity = "Rare"
	sp2.color = Color(0.35, 0.70, 1.00)
	sp2.shield_regen_delay_add = -1.25
	sp2.shield_regen_mult = 1.20
	sp2.required_mechanic = "shield"
	_register(sp2)

	# Abpraller-Ausbau: erscheinen nur, wenn der Spieler schon Abpraller hat.
	var ab1 = CardData.new()
	ab1.id = "gummiwand"
	ab1.title = "Gummiwand"
	ab1.description = "Der Kartenrand federt zurück.\nKugeln prallen an der Kartengrenze ab, ohne einen Abpraller zu verbrauchen."
	ab1.rarity = "Legendary"
	ab1.color = Color(0.95, 0.80, 0.25)
	ab1.pool = "Offensive"
	ab1.border_bounce = true
	ab1.required_mechanic = "bounce"
	_register(ab1)

	var ab2 = CardData.new()
	ab2.id = "gummipuffer"
	ab2.title = "Gummipuffer"
	ab2.description = "Eigene Querschläger tun weniger weh.\n-50% Selbstschaden durch eigene Kugeln."
	ab2.rarity = "Epic"
	ab2.color = Color(0.55, 0.85, 0.75)
	ab2.pool = "Defensive"
	ab2.self_damage_reduction_add = 0.5
	ab2.required_mechanic = "bounce"
	_register(ab2)

	var ab3 = CardData.new()
	ab3.id = "zellteilung"
	ab3.title = "Zellteilung"
	ab3.description = "Jeder Abprall spaltet die Kugel.\nTeilt sich bei jedem Abprall in 2 kleinere Kugeln mit je 60% Schaden (max. 3 Teilungen)."
	ab3.rarity = "Epic"
	ab3.color = Color(0.80, 0.45, 0.95)
	ab3.pool = "Offensive"
	ab3.bounce_split = true
	ab3.required_mechanic = "bounce"
	_register(ab3)

	var bu6 = CardData.new()
	bu6.id = "leichte_schrotflinte"
	bu6.version = 2 # Evolution B von splittergeschoss
	bu6.title = "Leichte Schrotflinte"
	bu6.description = "Mehrfachschuss-Ausbau: Breite Schrotladung.\n+2 Projektile, -25% Schaden pro Kugel."
	bu6.rarity = "Rare"
	bu6.color = Color(0.90, 0.60, 0.45)
	bu6.family_id = "splittergeschoss"
	bu6.parent_card_id = "splittergeschoss"
	bu6.evolution_branch = "B"
	bu6.multishot_add = 2
	bu6.spread_angle_deg = 16.0
	bu6.damage_mult = 0.75
	_register(bu6)

	var bu8 = CardData.new()
	bu8.id = "eishaut"
	bu8.title = "Eishaut"
	bu8.description = "Stärkere Verlangsamung.\n+0,6s Einfrierdauer, +5% Schaden."
	bu8.rarity = "Uncommon"
	bu8.color = Color(0.40, 0.85, 1.00)
	bu8.freeze_duration_add = 0.6
	bu8.damage_mult = 1.05
	_register(bu8)

	var bu9 = CardData.new()
	bu9.id = "seuchenbringer"
	bu9.title = "Seuchenbringer"
	bu9.description = "Mehr Gift.\n+2 Giftstapel."
	bu9.rarity = "Uncommon"
	bu9.color = Color(0.45, 0.95, 0.25)
	bu9.poison_stacks_add = 2
	_register(bu9)

	var bu10 = CardData.new()
	bu10.id = "halsabschneider"
	bu10.title = "Halsabschneider"
	bu10.description = "Durchschlägt mehrere Gegner und Wände.\n+2 Durchschlag."
	bu10.rarity = "Uncommon"
	bu10.color = Color(0.85, 0.40, 0.90)
	bu10.piercing_add = 2
	bu10.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(bu10)

	var bu12 = CardData.new()
	bu12.id = "schwarzes_herz"
	bu12.version = 4 # Evolution B von zaeher_kern
	bu12.title = "Schwarzes Herz"
	bu12.description = "Leben-Ausbau: Viel Leben, etwas langsamer.\n+30% Max HP, -6% Tempo."
	bu12.rarity = "Uncommon"
	bu12.color = Color(0.70, 0.30, 0.55)
	bu12.family_id = "zaeher_kern"
	bu12.parent_card_id = "zaeher_kern"
	bu12.evolution_branch = "B"
	bu12.max_hp_mult = 1.30
	bu12.move_speed_mult = 0.94
	_register(bu12)

	# ============================================================
	# Klassenspezifische Karten der neuen Helden
	# ============================================================

	# --- Nova: Gravity Mage ---
	var no1 = CardData.new()
	no1.id = "nova_gravity"
	no1.title = "Schwerkraftkern"
	no1.description = "Nova: +40px Explosionsradius, +15% Schaden."
	no1.rarity = "Rare"
	no1.color = Color(0.60, 0.40, 1.0)
	no1.hero_id = "nova"
	no1.explosion_radius_add = 40.0
	no1.damage_mult = 1.15
	_register(no1)

	var no2 = CardData.new()
	no2.id = "nova_void"
	no2.title = "Leerer Raum"
	no2.description = "Nova: -20% Fähigkeits-Abklingzeit, +12% Projektilgeschwindigkeit."
	no2.rarity = "Rare"
	no2.color = Color(0.50, 0.35, 0.95)
	no2.hero_id = "nova"
	no2.ability_cooldown_mult = 0.80
	no2.bullet_speed_mult = 1.12
	_register(no2)

	var no3 = CardData.new()
	no3.id = "nova_supernova"
	no3.title = "Supernova"
	no3.description = "Nova: +70px Explosionsradius, +25% Schaden, -10% Tempo."
	no3.rarity = "Epic"
	no3.color = Color(0.75, 0.55, 1.0)
	no3.hero_id = "nova"
	no3.explosion_radius_add = 70.0
	no3.damage_mult = 1.25
	no3.move_speed_mult = 0.90
	_register(no3)

	# --- Klinge: Blade Dancer ---
	var kl1 = CardData.new()
	kl1.id = "klinge_wirbel"
	kl1.title = "Wirbelklinge"
	kl1.description = "Klinge: +25% Schaden, +15% Angriffstempo."
	kl1.rarity = "Rare"
	kl1.color = Color(1.0, 0.35, 0.55)
	kl1.hero_id = "klinge"
	kl1.damage_mult = 1.25
	kl1.fire_rate_mult = 0.85
	_register(kl1)

	var kl2 = CardData.new()
	kl2.id = "klinge_reflexe"
	kl2.title = "Klingenreflexe"
	kl2.description = "Klinge: -30% Dash-Abklingzeit, +12% Tempo."
	kl2.rarity = "Rare"
	kl2.color = Color(1.0, 0.45, 0.65)
	kl2.hero_id = "klinge"
	kl2.dash_cooldown_mult = 0.70
	kl2.move_speed_mult = 1.12
	_register(kl2)

	var kl3 = CardData.new()
	kl3.id = "klinge_duell"
	kl3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	kl3.title = "Duellklinge"
	kl3.description = "Klinge: +80 Max HP, +15% Lebensraub, +10% Schaden."
	kl3.rarity = "Epic"
	kl3.color = Color(1.0, 0.25, 0.45)
	kl3.hero_id = "klinge"
	kl3.max_hp_flat = 80
	kl3.lifesteal_percent_add = 0.15
	kl3.damage_mult = 1.10
	_register(kl3)

	# --- Bastion: Field Engineer ---
	var ba1 = CardData.new()
	ba1.id = "bastion_energieschild"
	ba1.version = 2 # Max-HP/Schild-Bonus verdoppelt
	ba1.title = "Energieschild"
	ba1.description = "Bastion: +80 Schild, +25% Schild-Regeneration."
	ba1.rarity = "Rare"
	ba1.color = Color(0.30, 0.90, 0.70)
	ba1.hero_id = "bastion"
	ba1.shield_max_add = 80
	ba1.shield_regen_mult = 1.25
	_register(ba1)

	var ba2 = CardData.new()
	ba2.id = "bastion_wartung"
	ba2.title = "Feldwartung"
	ba2.version = 2 # Nahkampfheld: Angriffstempo statt Nachladen
	ba2.description = "Bastion: +40% Schild-Regeneration, +15% Angriffstempo."
	ba2.rarity = "Rare"
	ba2.color = Color(0.35, 0.85, 0.75)
	ba2.hero_id = "bastion"
	ba2.shield_regen_mult = 1.40
	ba2.melee_cooldown_mult = 0.85
	_register(ba2)

	var ba3 = CardData.new()
	ba3.id = "bastion_festung"
	ba3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	ba3.title = "Bastionsfestung"
	ba3.description = "Bastion: +120 Schild, +50 Max HP, -10% Tempo."
	ba3.rarity = "Epic"
	ba3.color = Color(0.25, 0.95, 0.80)
	ba3.hero_id = "bastion"
	ba3.shield_max_add = 120
	ba3.max_hp_flat = 50
	ba3.move_speed_mult = 0.90
	_register(ba3)

	# --- Phantom: Shadow Assassin ---
	var ph1 = CardData.new()
	ph1.id = "phantom_schattenklinge"
	ph1.title = "Schattenklinge"
	ph1.description = "Phantom: +20% Schaden, +0,5 Felder Reichweite."
	ph1.rarity = "Rare"
	ph1.color = Color(0.50, 0.50, 0.70)
	ph1.hero_id = "phantom"
	ph1.damage_mult = 1.20
	ph1.melee_range_add = 0.5
	ph1.version = 3 # Nahkampfheld: Reichweite statt Durchschlag
	_register(ph1)

	var ph2 = CardData.new()
	ph2.id = "phantom_sprungkraft"
	ph2.title = "Schattenlauf"
	ph2.description = "Phantom: -25% Fähigkeits-Abklingzeit, +1 Luft-Sprung."
	ph2.rarity = "Rare"
	ph2.color = Color(0.45, 0.45, 0.65)
	ph2.hero_id = "phantom"
	ph2.ability_cooldown_mult = 0.75
	ph2.extra_jumps_add = 1
	_register(ph2)

	var ph3 = CardData.new()
	ph3.id = "phantom_todeskuss"
	ph3.title = "Todeskuss"
	ph3.description = "Phantom: +35% Schaden, +15% Lebensraub, -10% Max HP."
	ph3.rarity = "Epic"
	ph3.color = Color(0.35, 0.35, 0.55)
	ph3.hero_id = "phantom"
	ph3.damage_mult = 1.35
	ph3.lifesteal_percent_add = 0.15
	ph3.max_hp_mult = 0.90
	_register(ph3)

	# ============================================================
	# Fähigkeits-Upgrades pro Heldenklasse
	# Jede Klasse hat eine Fähigkeits-Familie (Grundkarte + zwei exklusive
	# Evolutionen) und eine einzelne Fähigkeitskarte. Die Evolutionseffekte
	# werden über ability_evolution in player.gd ausgelöst.
	# ============================================================

	# --- Ignis ---
	var fa1 = CardData.new()
	fa1.id = "ignis_raketentriebwerk"
	fa1.title = "Raketentriebwerk"
	fa1.description = "Ignis – Rocket Leap: +30% Einschlagschaden, +25% Einschlagradius, +20% Flugweite."
	fa1.rarity = "Rare"
	fa1.pool = "Offensive"
	fa1.color = Color(1.00, 0.45, 0.15)
	fa1.hero_id = "ignis"
	fa1.family_id = "ignis_rocket"
	fa1.ability_damage_mult = 1.30
	fa1.ability_radius_mult = 1.25
	fa1.ability_range_mult = 1.20
	_register(fa1)

	var fa2 = CardData.new()
	fa2.id = "ignis_napalm"
	fa2.title = "Napalm-Landung"
	fa2.description = "Rocket-Leap-Evolution: Der Einschlag hinterlässt 3,5 s lang eine große Feuerfläche, die Gegner entzündet."
	fa2.rarity = "Epic"
	fa2.color = Color(1.00, 0.45, 0.15)
	fa2.hero_id = "ignis"
	fa2.family_id = "ignis_rocket"
	fa2.parent_card_id = "ignis_raketentriebwerk"
	fa2.evolution_branch = "A"
	fa2.ability_evolution = "ignis_napalm"
	_register(fa2)

	var fa3 = CardData.new()
	fa3.id = "ignis_splitterlandung"
	fa3.title = "Splitterlandung"
	fa3.description = "Rocket-Leap-Evolution: Der Einschlag schleudert 4 explosive Splitterbomben in alle Richtungen. -15% Fähigkeits-Abklingzeit."
	fa3.rarity = "Epic"
	fa3.color = Color(1.00, 0.45, 0.15)
	fa3.hero_id = "ignis"
	fa3.family_id = "ignis_rocket"
	fa3.parent_card_id = "ignis_raketentriebwerk"
	fa3.evolution_branch = "B"
	fa3.ability_evolution = "ignis_splitter"
	fa3.ability_cooldown_mult = 0.85
	_register(fa3)

	var fa4 = CardData.new()
	fa4.id = "ignis_zuendschnur"
	fa4.title = "Kurze Zündschnur"
	fa4.description = "Ignis – Rocket Leap: -20% Fähigkeits-Abklingzeit, +10% Einschlagradius."
	fa4.rarity = "Uncommon"
	fa4.pool = "Offensive"
	fa4.color = Color(1.00, 0.45, 0.15)
	fa4.hero_id = "ignis"
	fa4.ability_cooldown_mult = 0.80
	fa4.ability_radius_mult = 1.10
	_register(fa4)

	# --- Ignis: Nachbrenner (Dash) und Meteorschauer (Ulti) ---
	var ig5 = CardData.new()
	ig5.id = "ignis_glutspur"
	ig5.title = "Glutspur"
	ig5.description = "Ignis – Nachbrenner: Die Feuerspur hält 60% länger, -10% Dash-Abklingzeit."
	ig5.rarity = "Rare"
	ig5.pool = "Bewegung"
	ig5.color = Color(1.00, 0.40, 0.20)
	ig5.hero_id = "ignis"
	ig5.family_id = "ignis_dash"
	ig5.dash_effect_mult = 1.6
	ig5.dash_cooldown_mult = 0.9
	_register(ig5)

	var ig6 = CardData.new()
	ig6.id = "ignis_zuendung"
	ig6.title = "Zündung"
	ig6.description = "Nachbrenner-Evolution: Am Ende des Dashs explodierst du (18 Schaden, Radius 95 px, Rückstoß)."
	ig6.rarity = "Epic"
	ig6.color = Color(1.00, 0.40, 0.20)
	ig6.hero_id = "ignis"
	ig6.family_id = "ignis_dash"
	ig6.parent_card_id = "ignis_glutspur"
	ig6.evolution_branch = "A"
	ig6.ability_evolution = "ignis_dash_blast"
	_register(ig6)

	var ig7 = CardData.new()
	ig7.id = "ignis_meteorregen"
	ig7.title = "Meteorregen"
	ig7.description = "Ignis – Meteorschauer: +2 Meteore, +15% Einschlagradius."
	ig7.rarity = "Rare"
	ig7.pool = "Offensive"
	ig7.color = Color(1.00, 0.40, 0.20)
	ig7.hero_id = "ignis"
	ig7.family_id = "ignis_ult"
	ig7.ult_count_add = 2
	ig7.ult_radius_mult = 1.15
	_register(ig7)

	var ig8 = CardData.new()
	ig8.id = "ignis_komet"
	ig8.title = "Komet"
	ig8.description = "Meteorschauer-Evolution: Statt einer Reihe schlägt ein einziger riesiger Komet ein (60% des Gesamtschadens, doppelter Radius, sehr starker Rückstoß)."
	ig8.rarity = "Epic"
	ig8.color = Color(1.00, 0.40, 0.20)
	ig8.hero_id = "ignis"
	ig8.family_id = "ignis_ult"
	ig8.parent_card_id = "ignis_meteorregen"
	ig8.evolution_branch = "A"
	ig8.ability_evolution = "ignis_comet"
	_register(ig8)

	var ig9 = CardData.new()
	ig9.id = "ignis_flaechenbrand"
	ig9.title = "Flächenbrand"
	ig9.description = "Meteorschauer-Evolution: Die Feuerflächen sind 50% größer und brennen doppelt so lange."
	ig9.rarity = "Epic"
	ig9.color = Color(1.00, 0.40, 0.20)
	ig9.hero_id = "ignis"
	ig9.family_id = "ignis_ult"
	ig9.parent_card_id = "ignis_meteorregen"
	ig9.evolution_branch = "B"
	ig9.ability_evolution = "ignis_wildfire"
	_register(ig9)


	# --- Volt ---
	var fa5 = CardData.new()
	fa5.id = "volt_hochspannung"
	fa5.version = 2
	fa5.title = "Hochspannung"
	fa5.description = "Volt – Kugelblitz: +35% Schockschaden, +25% Radius."
	fa5.rarity = "Rare"
	fa5.pool = "Offensive"
	fa5.color = Color(1.00, 0.90, 0.20)
	fa5.hero_id = "volt"
	fa5.family_id = "volt_orb"
	fa5.ability_damage_mult = 1.35
	fa5.ability_radius_mult = 1.25
	_register(fa5)

	var fa5a = CardData.new()
	fa5a.id = "volt_sprungziel"
	fa5a.title = "Sprungziel"
	fa5a.description = "Kugelblitz-Evolution: Fähigkeit erneut drücken, solange der Kugelblitz fliegt: Volt springt zu ihm und der Kugelblitz entlädt sich."
	fa5a.rarity = "Epic"
	fa5a.color = Color(1.00, 0.90, 0.20)
	fa5a.hero_id = "volt"
	fa5a.family_id = "volt_orb"
	fa5a.parent_card_id = "volt_hochspannung"
	fa5a.evolution_branch = "A"
	fa5a.ability_evolution = "volt_orb_jump"
	_register(fa5a)

	var fa5b = CardData.new()
	fa5b.id = "volt_entladung"
	fa5b.title = "Entladung"
	fa5b.description = "Kugelblitz-Evolution: Am Ende explodiert der Kugelblitz (20 Schaden, 0,6 s Betäubung)."
	fa5b.rarity = "Epic"
	fa5b.color = Color(1.00, 0.90, 0.20)
	fa5b.hero_id = "volt"
	fa5b.family_id = "volt_orb"
	fa5b.parent_card_id = "volt_hochspannung"
	fa5b.evolution_branch = "B"
	fa5b.ability_evolution = "volt_orb_burst"
	_register(fa5b)

	var vd1 = CardData.new()
	vd1.id = "volt_doppelladung"
	vd1.title = "Dreifachblitz"
	vd1.description = "Volt – Blitzschritt: +1 Ladung, +20% Teleportweite."
	vd1.rarity = "Rare"
	vd1.pool = "Bewegung"
	vd1.color = Color(1.00, 0.90, 0.20)
	vd1.hero_id = "volt"
	vd1.family_id = "volt_dash"
	vd1.dash_charges_add = 1
	vd1.ability_range_mult = 1.2
	_register(vd1)

	var fa6 = CardData.new()
	fa6.id = "volt_kettenblink"
	fa6.version = 2
	fa6.title = "Kettenblink"
	fa6.description = "Blitzschritt-Evolution: Am Zielpunkt springt ein Kettenblitz auf den nächsten Gegner in der Nähe."
	fa6.rarity = "Epic"
	fa6.color = Color(1.00, 0.90, 0.20)
	fa6.hero_id = "volt"
	fa6.family_id = "volt_dash"
	fa6.parent_card_id = "volt_doppelladung"
	fa6.evolution_branch = "A"
	fa6.ability_evolution = "volt_chain"
	_register(fa6)

	var fa7 = CardData.new()
	fa7.id = "volt_gewitterspur"
	fa7.version = 2
	fa7.title = "Gewitterspur"
	fa7.description = "Blitzschritt-Evolution: Der Zielpunkt wird 4 s lang zur Blitzzone, die Gegner beim Betreten betäubt."
	fa7.rarity = "Epic"
	fa7.color = Color(1.00, 0.90, 0.20)
	fa7.hero_id = "volt"
	fa7.family_id = "volt_dash"
	fa7.parent_card_id = "volt_doppelladung"
	fa7.evolution_branch = "B"
	fa7.ability_evolution = "volt_storm"
	_register(fa7)

	var vu1 = CardData.new()
	vu1.id = "volt_starkstrom"
	vu1.title = "Starkstrom"
	vu1.description = "Volt – Überladung: +30% Dauer, -10% Ulti-Abklingzeit."
	vu1.rarity = "Rare"
	vu1.pool = "Offensive"
	vu1.color = Color(1.00, 0.90, 0.20)
	vu1.hero_id = "volt"
	vu1.family_id = "volt_ult"
	vu1.ult_duration_mult = 1.3
	vu1.ult_cooldown_mult = 0.9
	_register(vu1)

	var vu2 = CardData.new()
	vu2.id = "volt_dauerblitz"
	vu2.title = "Dauerblitz"
	vu2.description = "Überladung-Evolution: Während der Überladung lädt der Blitzschritt dreimal so schnell nach."
	vu2.rarity = "Epic"
	vu2.color = Color(1.00, 0.90, 0.20)
	vu2.hero_id = "volt"
	vu2.family_id = "volt_ult"
	vu2.parent_card_id = "volt_starkstrom"
	vu2.evolution_branch = "A"
	vu2.ability_evolution = "volt_ult_blink"
	_register(vu2)

	var vu3 = CardData.new()
	vu3.id = "volt_schockring"
	vu3.title = "Schockring"
	vu3.description = "Überladung-Evolution: Am Ende der Überladung entlädt sich ein Schockring (25 Schaden, Rückstoß, 1,5 s Verlangsamung)."
	vu3.rarity = "Epic"
	vu3.color = Color(1.00, 0.90, 0.20)
	vu3.hero_id = "volt"
	vu3.family_id = "volt_ult"
	vu3.parent_card_id = "volt_starkstrom"
	vu3.evolution_branch = "B"
	vu3.ability_evolution = "volt_ult_ring"
	_register(vu3)

	var fa8 = CardData.new()
	fa8.id = "volt_restladung"
	fa8.version = 2
	fa8.title = "Restladung"
	fa8.description = "Volt – Kugelblitz: Fliegt 50% länger und verlangsamt 50% länger, -10% Fähigkeits-Abklingzeit."
	fa8.rarity = "Uncommon"
	fa8.pool = "Offensive"
	fa8.color = Color(1.00, 0.90, 0.20)
	fa8.hero_id = "volt"
	fa8.ability_duration_mult = 1.5
	fa8.ability_cooldown_mult = 0.9
	_register(fa8)

	# --- Spore ---
	var fa9 = CardData.new()
	fa9.id = "spore_dichter_nebel"
	fa9.version = 2
	fa9.title = "Pilzgarten"
	fa9.description = "Spore – Giftpilz: +1 Pilz gleichzeitig, +30% Wolkenradius."
	fa9.rarity = "Rare"
	fa9.pool = "Offensive"
	fa9.color = Color(0.40, 0.90, 0.30)
	fa9.hero_id = "spore"
	fa9.family_id = "spore_burst"
	fa9.wall_count_add = 1
	fa9.ability_radius_mult = 1.30
	_register(fa9)

	var fa10 = CardData.new()
	fa10.id = "spore_aetzender_nebel"
	fa10.version = 2
	fa10.title = "Ätzender Nebel"
	fa10.description = "Giftpilz-Evolution: Gegner in der Pilzwolke werden alle 0,8 s mit 3 Giftstapeln belegt, die nach dem Verlassen nachwirken. +20% Wolkenschaden."
	fa10.rarity = "Epic"
	fa10.color = Color(0.40, 0.90, 0.30)
	fa10.hero_id = "spore"
	fa10.family_id = "spore_burst"
	fa10.parent_card_id = "spore_dichter_nebel"
	fa10.evolution_branch = "A"
	fa10.ability_evolution = "spore_corrosive"
	fa10.ability_damage_mult = 1.20
	_register(fa10)

	var sp5 = CardData.new()
	sp5.id = "spore_klebsporen"
	sp5.title = "Klebsporen"
	sp5.description = "Giftpilz-Evolution: Gegner in der aufplatzenden Wolke kleben fest (1 s verlangsamt, kurz betäubt)."
	sp5.rarity = "Epic"
	sp5.color = Color(0.40, 0.90, 0.30)
	sp5.hero_id = "spore"
	sp5.family_id = "spore_burst"
	sp5.parent_card_id = "spore_dichter_nebel"
	sp5.evolution_branch = "B"
	sp5.ability_evolution = "spore_sticky"
	_register(sp5)

	var sp6 = CardData.new()
	sp6.id = "spore_sprungpilz"
	sp6.title = "Sprungpilz"
	sp6.description = "Giftpilz-Evolution: Landest du auf deinem eigenen Pilz, schleudert er dich hoch und gibt dir deine Sprünge zurück."
	sp6.rarity = "Epic"
	sp6.color = Color(0.40, 0.90, 0.30)
	sp6.hero_id = "spore"
	sp6.family_id = "spore_burst"
	sp6.parent_card_id = "spore_dichter_nebel"
	sp6.evolution_branch = "C"
	sp6.ability_evolution = "spore_bounce"
	_register(sp6)

	var fa12 = CardData.new()
	fa12.id = "spore_sporenvorrat"
	fa12.version = 2
	fa12.title = "Sporenvorrat"
	fa12.description = "Spore – Giftpilz: -20% Fähigkeits-Abklingzeit, +25% Wolkenschaden."
	fa12.rarity = "Uncommon"
	fa12.pool = "Offensive"
	fa12.color = Color(0.40, 0.90, 0.30)
	fa12.hero_id = "spore"
	fa12.ability_cooldown_mult = 0.80
	fa12.ability_damage_mult = 1.25
	_register(fa12)

	var sp7 = CardData.new()
	sp7.id = "spore_sporenschleier"
	sp7.title = "Sporenschleier"
	sp7.description = "Spore – Sporenstoß: Die Dash-Wolke ist 40% größer, -15% Dash-Abklingzeit."
	sp7.rarity = "Rare"
	sp7.pool = "Bewegung"
	sp7.color = Color(0.40, 0.90, 0.30)
	sp7.hero_id = "spore"
	sp7.family_id = "spore_dash"
	sp7.dash_effect_mult = 1.4
	sp7.dash_cooldown_mult = 0.85
	_register(sp7)

	var fa11 = CardData.new()
	fa11.id = "spore_symbiose"
	fa11.version = 2
	fa11.title = "Symbiose"
	fa11.description = "Sporenstoß-Evolution: Solange du in deiner Dash-Wolke stehst, heilst du 6 HP pro Sekunde."
	fa11.rarity = "Epic"
	fa11.color = Color(0.40, 0.90, 0.30)
	fa11.hero_id = "spore"
	fa11.family_id = "spore_dash"
	fa11.parent_card_id = "spore_sporenschleier"
	fa11.evolution_branch = "A"
	fa11.ability_evolution = "spore_symbiosis"
	_register(fa11)

	var sp8 = CardData.new()
	sp8.id = "spore_seuchenherd"
	sp8.title = "Seuchenherd"
	sp8.description = "Spore – Seuchennebel: +25% Radius, hält 25% länger."
	sp8.rarity = "Rare"
	sp8.pool = "Offensive"
	sp8.color = Color(0.40, 0.90, 0.30)
	sp8.hero_id = "spore"
	sp8.family_id = "spore_ult"
	sp8.ult_radius_mult = 1.25
	sp8.ult_duration_mult = 1.25
	_register(sp8)

	var sp9 = CardData.new()
	sp9.id = "spore_pandemie"
	sp9.title = "Pandemie"
	sp9.description = "Seuchennebel-Evolution: Vergiftete Gegner stecken andere Gegner in 130 px Umkreis an."
	sp9.rarity = "Epic"
	sp9.color = Color(0.40, 0.90, 0.30)
	sp9.hero_id = "spore"
	sp9.family_id = "spore_ult"
	sp9.parent_card_id = "spore_seuchenherd"
	sp9.evolution_branch = "A"
	sp9.ability_evolution = "spore_pandemic"
	_register(sp9)

	var sp10 = CardData.new()
	sp10.id = "spore_verwesung"
	sp10.title = "Verwesung"
	sp10.description = "Seuchennebel-Evolution: Gegner im Nebel können weder heilen noch Schild aufbauen."
	sp10.rarity = "Epic"
	sp10.color = Color(0.40, 0.90, 0.30)
	sp10.hero_id = "spore"
	sp10.family_id = "spore_ult"
	sp10.parent_card_id = "spore_seuchenherd"
	sp10.evolution_branch = "B"
	sp10.ability_evolution = "spore_decay"
	_register(sp10)

	# --- Nova ---
	var nv5 = CardData.new()
	nv5.id = "nova_druckwelle"
	nv5.title = "Druckwelle"
	nv5.description = "Nova – Gravitationsstoß: +25% Kegelbreite, +20% Reichweite."
	nv5.rarity = "Rare"
	nv5.pool = "Offensive"
	nv5.color = Color(0.60, 0.40, 1.00)
	nv5.hero_id = "nova"
	nv5.family_id = "nova_push"
	nv5.ability_radius_mult = 1.25
	nv5.ability_range_mult = 1.2
	_register(nv5)

	var nv6 = CardData.new()
	nv6.id = "nova_wandschlag"
	nv6.title = "Wandschlag"
	nv6.description = "Gravitationsstoß-Evolution: Prallt ein weggestoßener Gegner gegen eine Wand, nimmt er 20 Schaden und ist 0,8 s betäubt."
	nv6.rarity = "Epic"
	nv6.color = Color(0.60, 0.40, 1.00)
	nv6.hero_id = "nova"
	nv6.family_id = "nova_push"
	nv6.parent_card_id = "nova_druckwelle"
	nv6.evolution_branch = "A"
	nv6.ability_evolution = "nova_wallslam"
	_register(nv6)

	var nv7 = CardData.new()
	nv7.id = "nova_umkehr"
	nv7.title = "Umkehr"
	nv7.description = "Gravitationsstoß-Evolution: Abgelenkte Kugeln gehören danach dir und suchen Gegner."
	nv7.rarity = "Epic"
	nv7.color = Color(0.60, 0.40, 1.00)
	nv7.hero_id = "nova"
	nv7.family_id = "nova_push"
	nv7.parent_card_id = "nova_druckwelle"
	nv7.evolution_branch = "B"
	nv7.ability_evolution = "nova_reverse"
	_register(nv7)

	var nv8 = CardData.new()
	nv8.id = "nova_schwebeflug"
	nv8.title = "Schwebeflug"
	nv8.description = "Nova – Phasengleiten: Schwebt 50% länger."
	nv8.rarity = "Rare"
	nv8.pool = "Bewegung"
	nv8.color = Color(0.60, 0.40, 1.00)
	nv8.hero_id = "nova"
	nv8.family_id = "nova_dash"
	nv8.dash_effect_mult = 1.5
	_register(nv8)

	var nv9 = CardData.new()
	nv9.id = "nova_phasenhuelle"
	nv9.title = "Phasenhülle"
	nv9.description = "Phasengleiten-Evolution: Gegnerische Kugeln fliegen beim Gleiten durch dich hindurch und werden um die Hälfte langsamer."
	nv9.rarity = "Epic"
	nv9.color = Color(0.60, 0.40, 1.00)
	nv9.hero_id = "nova"
	nv9.family_id = "nova_dash"
	nv9.parent_card_id = "nova_schwebeflug"
	nv9.evolution_branch = "A"
	nv9.ability_evolution = "nova_phase"
	_register(nv9)

	var fa13 = CardData.new()
	fa13.id = "nova_ereignishorizont"
	fa13.version = 2
	fa13.title = "Ereignishorizont"
	fa13.description = "Nova – Singularität: +25% Sogradius, hält 30% länger, +15% Wurfweite."
	fa13.rarity = "Rare"
	fa13.pool = "Offensive"
	fa13.color = Color(0.60, 0.40, 1.00)
	fa13.hero_id = "nova"
	fa13.family_id = "nova_singularity"
	fa13.ult_radius_mult = 1.25
	fa13.ult_duration_mult = 1.30
	fa13.ability_range_mult = 1.15
	_register(fa13)

	var fa14 = CardData.new()
	fa14.id = "nova_implosion"
	fa14.version = 2
	fa14.title = "Schwarzes Loch"
	fa14.description = "Singularitäts-Evolution: Der Kern verschluckt gegnerische Kugeln und spuckt sie bei der Implosion als deine Kugeln in alle Richtungen aus."
	fa14.rarity = "Epic"
	fa14.color = Color(0.60, 0.40, 1.00)
	fa14.hero_id = "nova"
	fa14.family_id = "nova_singularity"
	fa14.parent_card_id = "nova_ereignishorizont"
	fa14.evolution_branch = "A"
	fa14.ability_evolution = "nova_blackhole"
	_register(fa14)

	var fa15 = CardData.new()
	fa15.id = "nova_doppelstern"
	fa15.version = 2
	fa15.title = "Doppelstern"
	fa15.description = "Singularitäts-Evolution: Erzeugt zwei Singularitäten nebeneinander statt einer."
	fa15.rarity = "Epic"
	fa15.color = Color(0.60, 0.40, 1.00)
	fa15.hero_id = "nova"
	fa15.family_id = "nova_singularity"
	fa15.parent_card_id = "nova_ereignishorizont"
	fa15.evolution_branch = "B"
	fa15.ability_evolution = "nova_binary"
	_register(fa15)

	var fa16 = CardData.new()
	fa16.id = "nova_massenanziehung"
	fa16.version = 2
	fa16.title = "Massenanziehung"
	fa16.description = "Nova – Singularität: -15% Ulti-Abklingzeit, +15% Sogradius."
	fa16.rarity = "Uncommon"
	fa16.pool = "Offensive"
	fa16.color = Color(0.60, 0.40, 1.00)
	fa16.hero_id = "nova"
	fa16.ult_cooldown_mult = 0.85
	fa16.ult_radius_mult = 1.15
	_register(fa16)

	# --- Klinge ---
	var kl5 = CardData.new()
	kl5.id = "klinge_wurfklinge"
	kl5.title = "Wurfklinge"
	kl5.description = "Klinge – Klingenbumerang: +25% Reichweite, +25% Schaden."
	kl5.rarity = "Rare"
	kl5.pool = "Offensive"
	kl5.color = Color(1.00, 0.30, 0.50)
	kl5.hero_id = "klinge"
	kl5.family_id = "klinge_boomerang"
	kl5.ability_range_mult = 1.25
	kl5.ability_damage_mult = 1.25
	_register(kl5)

	var kl6 = CardData.new()
	kl6.id = "klinge_blutung"
	kl6.title = "Blutung"
	kl6.description = "Klingenbumerang-Evolution: Getroffene Gegner bluten (4 × 4 Schaden) und nehmen 4 s lang 15% mehr Schaden von dir."
	kl6.rarity = "Epic"
	kl6.color = Color(1.00, 0.30, 0.50)
	kl6.hero_id = "klinge"
	kl6.family_id = "klinge_boomerang"
	kl6.parent_card_id = "klinge_wurfklinge"
	kl6.evolution_branch = "A"
	kl6.ability_evolution = "klinge_bleed"
	_register(kl6)

	var kl7 = CardData.new()
	kl7.id = "klinge_fangen"
	kl7.title = "Fangen"
	kl7.description = "Klingenbumerang-Evolution: Fängst du das Schwert im Dash, ist der Bumerang sofort wieder bereit. Größerer Fangradius."
	kl7.rarity = "Epic"
	kl7.color = Color(1.00, 0.30, 0.50)
	kl7.hero_id = "klinge"
	kl7.family_id = "klinge_boomerang"
	kl7.parent_card_id = "klinge_wurfklinge"
	kl7.evolution_branch = "B"
	kl7.ability_evolution = "klinge_catch"
	_register(kl7)

	var kl8 = CardData.new()
	kl8.id = "klinge_stossklinge"
	kl8.title = "Stoßklinge"
	kl8.description = "Klinge – Durchstoß: +30% Durchstoß-Schaden, -10% Dash-Abklingzeit."
	kl8.rarity = "Rare"
	kl8.pool = "Bewegung"
	kl8.color = Color(1.00, 0.30, 0.50)
	kl8.hero_id = "klinge"
	kl8.family_id = "klinge_dash"
	kl8.dash_effect_mult = 1.3
	kl8.dash_cooldown_mult = 0.9
	_register(kl8)

	var kl9 = CardData.new()
	kl9.id = "klinge_klingenfluss"
	kl9.title = "Klingenfluss"
	kl9.description = "Durchstoß-Evolution: Ein Treffer lädt den Dash ganz auf (höchstens alle 4 s)."
	kl9.rarity = "Epic"
	kl9.color = Color(1.00, 0.30, 0.50)
	kl9.hero_id = "klinge"
	kl9.family_id = "klinge_dash"
	kl9.parent_card_id = "klinge_stossklinge"
	kl9.evolution_branch = "A"
	kl9.ability_evolution = "klinge_dash_reset"
	_register(kl9)

	var fa17 = CardData.new()
	fa17.id = "klinge_geschliffen"
	fa17.version = 2
	fa17.title = "Geschliffene Klingen"
	fa17.description = "Klinge – Klingensturm: +30% Schaden, +15% Radius."
	fa17.rarity = "Rare"
	fa17.pool = "Offensive"
	fa17.color = Color(1.00, 0.30, 0.50)
	fa17.hero_id = "klinge"
	fa17.family_id = "klinge_storm"
	fa17.ult_damage_mult = 1.30
	fa17.ult_radius_mult = 1.15
	_register(fa17)

	var fa18 = CardData.new()
	fa18.id = "klinge_echowirbel"
	fa18.version = 2
	fa18.title = "Echowirbel"
	fa18.description = "Klingensturm-Evolution: Nach dem großen Schlusswirbel folgt ein zweiter mit 60% Schaden."
	fa18.rarity = "Epic"
	fa18.color = Color(1.00, 0.30, 0.50)
	fa18.hero_id = "klinge"
	fa18.family_id = "klinge_storm"
	fa18.parent_card_id = "klinge_geschliffen"
	fa18.evolution_branch = "A"
	fa18.ability_evolution = "klinge_echo"
	_register(fa18)

	var fa19 = CardData.new()
	fa19.id = "klinge_blutrausch"
	fa19.version = 2
	fa19.title = "Blutrausch"
	fa19.description = "Klingensturm-Evolution: Du heilst dich um 35% des mit Klingensturm verursachten Schadens. Der Sturm hält 20% länger."
	fa19.rarity = "Epic"
	fa19.color = Color(1.00, 0.30, 0.50)
	fa19.hero_id = "klinge"
	fa19.family_id = "klinge_storm"
	fa19.parent_card_id = "klinge_geschliffen"
	fa19.evolution_branch = "B"
	fa19.ability_evolution = "klinge_bloodlust"
	fa19.ult_duration_mult = 1.20
	_register(fa19)

	var fa20 = CardData.new()
	fa20.id = "klinge_tanzschritt"
	fa20.version = 2
	fa20.title = "Tanzschritt"
	fa20.description = "Klinge – Klingensturm: -15% Ulti-Abklingzeit, der Sturm hält 20% länger."
	fa20.rarity = "Uncommon"
	fa20.pool = "Offensive"
	fa20.color = Color(1.00, 0.30, 0.50)
	fa20.hero_id = "klinge"
	fa20.ult_cooldown_mult = 0.85
	fa20.ult_duration_mult = 1.20
	_register(fa20)

	# --- Bastion ---
	var bs5 = CardData.new()
	bs5.id = "bastion_langer_haken"
	bs5.title = "Langer Haken"
	bs5.description = "Bastion – Magnethaken: +30% Reichweite, -15% Fähigkeits-Abklingzeit."
	bs5.rarity = "Rare"
	bs5.pool = "Offensive"
	bs5.color = Color(0.30, 0.90, 0.70)
	bs5.hero_id = "bastion"
	bs5.family_id = "bastion_hook"
	bs5.ability_range_mult = 1.3
	bs5.ability_cooldown_mult = 0.85
	_register(bs5)

	var bs6 = CardData.new()
	bs6.id = "bastion_kettenschlag"
	bs6.title = "Kettenschlag"
	bs6.description = "Magnethaken-Evolution: Dein nächster Hammerschlag innerhalb von 3 s nach einem Hakentreffer macht doppelten Schaden."
	bs6.rarity = "Epic"
	bs6.color = Color(0.30, 0.90, 0.70)
	bs6.hero_id = "bastion"
	bs6.family_id = "bastion_hook"
	bs6.parent_card_id = "bastion_langer_haken"
	bs6.evolution_branch = "A"
	bs6.ability_evolution = "bastion_chain_hit"
	_register(bs6)

	var bs7 = CardData.new()
	bs7.id = "bastion_magnetfeld"
	bs7.title = "Magnetfeld"
	bs7.description = "Magnethaken-Evolution: Der fliegende Haken schluckt gegnerische Kugeln und sammelt Powerups für dich ein."
	bs7.rarity = "Epic"
	bs7.color = Color(0.30, 0.90, 0.70)
	bs7.hero_id = "bastion"
	bs7.family_id = "bastion_hook"
	bs7.parent_card_id = "bastion_langer_haken"
	bs7.evolution_branch = "B"
	bs7.ability_evolution = "bastion_magnet"
	_register(bs7)

	var bs8 = CardData.new()
	bs8.id = "bastion_rammbock"
	bs8.title = "Schwerer Rammbock"
	bs8.description = "Bastion – Rammbock: +30% Rückstoß am Ende, -10% Dash-Abklingzeit."
	bs8.rarity = "Rare"
	bs8.pool = "Bewegung"
	bs8.color = Color(0.30, 0.90, 0.70)
	bs8.hero_id = "bastion"
	bs8.family_id = "bastion_dash"
	bs8.dash_effect_mult = 1.3
	bs8.dash_cooldown_mult = 0.9
	_register(bs8)

	var bs9 = CardData.new()
	bs9.id = "bastion_prellbock"
	bs9.title = "Prellbock"
	bs9.description = "Rammbock-Evolution: Weggestoßene Gegner, die gegen eine Wand prallen, sind 1 s betäubt, und du bekommst 25 Schild."
	bs9.rarity = "Epic"
	bs9.color = Color(0.30, 0.90, 0.70)
	bs9.hero_id = "bastion"
	bs9.family_id = "bastion_dash"
	bs9.parent_card_id = "bastion_rammbock"
	bs9.evolution_branch = "A"
	bs9.ability_evolution = "bastion_ram_wall"
	_register(bs9)

	var fa21 = CardData.new()
	fa21.id = "bastion_emitter"
	fa21.version = 2
	fa21.title = "Verstärkte Emitter"
	fa21.description = "Bastion – Festung: +30% Heilung und Schildaufbau, hält 25% länger."
	fa21.rarity = "Rare"
	fa21.pool = "Defensive"
	fa21.color = Color(0.30, 0.90, 0.70)
	fa21.hero_id = "bastion"
	fa21.family_id = "bastion_field"
	fa21.ult_damage_mult = 1.30
	fa21.ult_duration_mult = 1.25
	_register(fa21)

	var fa22 = CardData.new()
	fa22.id = "bastion_schutzkuppel"
	fa22.version = 2
	fa22.title = "Schutzkuppel"
	fa22.description = "Festung-Evolution: Solange du in deiner Kuppel stehst, erleidest du 30% weniger Schaden."
	fa22.rarity = "Epic"
	fa22.color = Color(0.30, 0.90, 0.70)
	fa22.hero_id = "bastion"
	fa22.family_id = "bastion_field"
	fa22.parent_card_id = "bastion_emitter"
	fa22.evolution_branch = "A"
	fa22.ability_evolution = "bastion_bulwark"
	_register(fa22)

	var fa23 = CardData.new()
	fa23.id = "bastion_pulsfeld"
	fa23.version = 2
	fa23.title = "Pulsfeld"
	fa23.description = "Festung-Evolution: Bei jedem Heil-Tick pulsiert die Kuppel und verursacht 7 Schaden mit Rückstoß an Gegnern im Umkreis von 130 px."
	fa23.rarity = "Epic"
	fa23.color = Color(0.30, 0.90, 0.70)
	fa23.hero_id = "bastion"
	fa23.family_id = "bastion_field"
	fa23.parent_card_id = "bastion_emitter"
	fa23.evolution_branch = "B"
	fa23.ability_evolution = "bastion_pulse"
	_register(fa23)

	var bs10 = CardData.new()
	bs10.id = "bastion_wanderfestung"
	bs10.title = "Wanderfestung"
	bs10.description = "Festung-Evolution: Die Kuppel wandert mit dir mit."
	bs10.rarity = "Epic"
	bs10.color = Color(0.30, 0.90, 0.70)
	bs10.hero_id = "bastion"
	bs10.family_id = "bastion_field"
	bs10.parent_card_id = "bastion_emitter"
	bs10.evolution_branch = "C"
	bs10.ability_evolution = "bastion_mobile_dome"
	_register(bs10)

	var fa24 = CardData.new()
	fa24.id = "bastion_notfallprotokoll"
	fa24.version = 2
	fa24.title = "Notfallprotokoll"
	fa24.description = "Bastion – Festung: -20% Ulti-Abklingzeit."
	fa24.rarity = "Uncommon"
	fa24.pool = "Defensive"
	fa24.color = Color(0.30, 0.90, 0.70)
	fa24.hero_id = "bastion"
	fa24.ult_cooldown_mult = 0.80
	_register(fa24)

	# --- Phantom ---
	var fa25 = CardData.new()
	fa25.id = "phantom_lautlose_klinge"
	fa25.version = 2
	fa25.title = "Doppelgänger"
	fa25.description = "Phantom – Köder: Der Köder hält doppelt so viel aus, -15% Fähigkeits-Abklingzeit."
	fa25.rarity = "Rare"
	fa25.pool = "Defensive"
	fa25.color = Color(0.45, 0.45, 0.60)
	fa25.hero_id = "phantom"
	fa25.family_id = "phantom_decoy"
	fa25.ability_damage_mult = 2.0
	fa25.ability_cooldown_mult = 0.85
	_register(fa25)

	var fa25a = CardData.new()
	fa25a.id = "phantom_sprengkoeder"
	fa25a.title = "Sprengköder"
	fa25a.description = "Köder-Evolution: Der Köder explodiert, wenn er zerstört wird oder abläuft (30 Schaden, Rückstoß)."
	fa25a.rarity = "Epic"
	fa25a.color = Color(0.45, 0.45, 0.60)
	fa25a.hero_id = "phantom"
	fa25a.family_id = "phantom_decoy"
	fa25a.parent_card_id = "phantom_lautlose_klinge"
	fa25a.evolution_branch = "A"
	fa25a.ability_evolution = "phantom_decoy_bomb"
	_register(fa25a)

	var fa25b = CardData.new()
	fa25b.id = "phantom_platztausch"
	fa25b.title = "Platztausch"
	fa25b.description = "Köder-Evolution: Fähigkeit erneut drücken, solange der Köder lebt: Phantom tauscht den Platz mit ihm."
	fa25b.rarity = "Epic"
	fa25b.color = Color(0.45, 0.45, 0.60)
	fa25b.hero_id = "phantom"
	fa25b.family_id = "phantom_decoy"
	fa25b.parent_card_id = "phantom_lautlose_klinge"
	fa25b.evolution_branch = "B"
	fa25b.ability_evolution = "phantom_decoy_swap"
	_register(fa25b)

	var fa27 = CardData.new()
	fa27.id = "phantom_laehmendes_mal"
	fa27.version = 2
	fa27.title = "Lähmendes Mal"
	fa27.description = "Köder-Evolution: Wer den Köder trifft, wird 0,7 s betäubt."
	fa27.rarity = "Epic"
	fa27.color = Color(0.45, 0.45, 0.60)
	fa27.hero_id = "phantom"
	fa27.family_id = "phantom_decoy"
	fa27.parent_card_id = "phantom_lautlose_klinge"
	fa27.evolution_branch = "C"
	fa27.ability_evolution = "phantom_mark"
	_register(fa27)

	var fa26 = CardData.new()
	fa26.id = "phantom_schattenschnitt"
	fa26.version = 2
	fa26.title = "Schattenschnitt"
	fa26.description = "Phantom – Schattenschritt: Der Dash sticht alle Gegner auf dem Weg (60% Nahkampfschaden)."
	fa26.rarity = "Epic"
	fa26.pool = "Offensive"
	fa26.color = Color(0.45, 0.45, 0.60)
	fa26.hero_id = "phantom"
	fa26.ability_evolution = "phantom_cut"
	_register(fa26)

	var ph4 = CardData.new()
	ph4.id = "phantom_blutspur"
	ph4.title = "Blutspur"
	ph4.description = "Phantom – Nachtjagd: Ein Kill während der Nachtjagd gibt die halbe Ulti-Abklingzeit zurück."
	ph4.rarity = "Epic"
	ph4.pool = "Offensive"
	ph4.color = Color(0.45, 0.45, 0.60)
	ph4.hero_id = "phantom"
	ph4.ability_evolution = "phantom_hunt_blood"
	_register(ph4)

	var fa28 = CardData.new()
	fa28.id = "phantom_lange_schatten"
	fa28.version = 2
	fa28.title = "Lange Schatten"
	fa28.description = "Phantom – Köder: Köder und Unsichtbarkeit halten 50% länger, -10% Fähigkeits-Abklingzeit."
	fa28.rarity = "Uncommon"
	fa28.pool = "Defensive"
	fa28.color = Color(0.45, 0.45, 0.60)
	fa28.hero_id = "phantom"
	fa28.ability_duration_mult = 1.5
	fa28.ability_cooldown_mult = 0.9
	_register(fa28)

	# --- Vampir (Fernkampf): Blutkugeln ---
	var vp1 = CardData.new()
	vp1.id = "vampire_blutdurst"
	vp1.title = "Blutdurst"
	vp1.description = "Vampir: +15% Schaden, +10% Lebensraub."
	vp1.rarity = "Rare"
	vp1.pool = "Offensive"
	vp1.color = Color(0.72, 0.10, 0.18)
	vp1.hero_id = "vampire"
	vp1.damage_mult = 1.15
	vp1.lifesteal_percent_add = 0.10
	_register(vp1)

	var vp2 = CardData.new()
	vp2.id = "vampire_nachtschwinge"
	vp2.title = "Nachtschwinge"
	vp2.description = "Vampir: -20% Fähigkeits-Abklingzeit, +1 Luft-Sprung."
	vp2.rarity = "Rare"
	vp2.pool = "Bewegung"
	vp2.color = Color(0.62, 0.08, 0.20)
	vp2.hero_id = "vampire"
	vp2.ability_cooldown_mult = 0.8
	vp2.extra_jumps_add = 1
	_register(vp2)

	var vp3 = CardData.new()
	vp3.id = "vampire_blutfontaene"
	vp3.title = "Blutfontäne"
	vp3.description = "Vampir – Blutexplosion: +30% Explosionsradius, +20% Schaden, -15% Fähigkeits-Abklingzeit."
	vp3.rarity = "Rare"
	vp3.pool = "Offensive"
	vp3.color = Color(0.72, 0.10, 0.18)
	vp3.hero_id = "vampire"
	vp3.family_id = "vampire_burst"
	vp3.ability_radius_mult = 1.3
	vp3.ability_damage_mult = 1.2
	vp3.ability_cooldown_mult = 0.85
	_register(vp3)

	var vp3a = CardData.new()
	vp3a.id = "vampire_aderlass"
	vp3a.title = "Aderlass"
	vp3a.description = "Blutexplosion-Evolution: Jeder getroffene Gegner heilt dich um %d HP." % int(Player.VAMPIRE_LEECH_HEAL)
	vp3a.rarity = "Epic"
	vp3a.color = Color(0.72, 0.10, 0.18)
	vp3a.hero_id = "vampire"
	vp3a.family_id = "vampire_burst"
	vp3a.parent_card_id = "vampire_blutfontaene"
	vp3a.evolution_branch = "A"
	vp3a.ability_evolution = "vampire_burst_leech"
	_register(vp3a)

	var vp3b = CardData.new()
	vp3b.id = "vampire_gerinnung"
	vp3b.title = "Gerinnung"
	vp3b.description = "Blutexplosion-Evolution: Getroffene Gegner sind %.1f s verlangsamt." % Player.VAMPIRE_CLOT_SLOW
	vp3b.rarity = "Epic"
	vp3b.color = Color(0.72, 0.10, 0.18)
	vp3b.hero_id = "vampire"
	vp3b.family_id = "vampire_burst"
	vp3b.parent_card_id = "vampire_blutfontaene"
	vp3b.evolution_branch = "B"
	vp3b.ability_evolution = "vampire_burst_slow"
	_register(vp3b)

	var vp4 = CardData.new()
	vp4.id = "vampire_blutrausch"
	vp4.title = "Blutrausch"
	vp4.description = "Vampir: Schon jeder 2. Treffer lässt eine Blutkugel fallen."
	vp4.rarity = "Epic"
	vp4.pool = "Offensive"
	vp4.color = Color(0.80, 0.08, 0.16)
	vp4.hero_id = "vampire"
	vp4.ability_evolution = "vampire_frenzy"
	_register(vp4)

	var vp5 = CardData.new()
	vp5.id = "vampire_blutsturm_plus"
	vp5.title = "Rote Flut"
	vp5.description = "Vampir – Blutsturm: +1 Dash-Ladung, der Dash macht doppelten Schaden."
	vp5.rarity = "Epic"
	vp5.pool = "Bewegung"
	vp5.color = Color(0.62, 0.08, 0.20)
	vp5.hero_id = "vampire"
	vp5.dash_charges_add = 1
	vp5.ability_evolution = "vampire_dash_strong"
	_register(vp5)

	var vp6 = CardData.new()
	vp6.id = "vampire_fledermauskoenig"
	vp6.title = "Fledermauskönig"
	vp6.description = "Vampir – Fledermausschwarm: mindestens %d Fledermäuse, +30%% Dauer, ihre Bisse heilen dich um die Hälfte des Schadens." % Player.VAMPIRE_KING_MIN_BATS
	vp6.rarity = "Epic"
	vp6.pool = "Offensive"
	vp6.color = Color(0.40, 0.08, 0.30)
	vp6.hero_id = "vampire"
	vp6.ult_duration_mult = 1.3
	vp6.ability_evolution = "vampire_bat_king"
	_register(vp6)

	# --- Blutritter (Nahkampf-Vampir): Klassenkarten ---
	var vm1 = CardData.new()
	vm1.id = "vampm_aderlass"
	vm1.title = "Aderlass"
	vm1.description = "Blutritter: +20% Schaden, +10% Lebensraub."
	vm1.rarity = "Rare"
	vm1.color = Color(0.70, 0.12, 0.20)
	vm1.hero_id = "vampire_melee"
	vm1.damage_mult = 1.20
	vm1.lifesteal_percent_add = 0.10
	_register(vm1)

	var vm2 = CardData.new()
	vm2.id = "vampm_dickes_blut"
	vm2.title = "Dickes Blut"
	vm2.description = "Blutritter – Blutschild: Blutkugeln geben 50% mehr Schild, +10% Max HP."
	vm2.rarity = "Rare"
	vm2.pool = "Defensive"
	vm2.color = Color(0.62, 0.10, 0.18)
	vm2.hero_id = "vampire_melee"
	vm2.max_hp_mult = 1.10
	vm2.ability_evolution = "vampm_thick_blood"
	_register(vm2)

	var vm3 = CardData.new()
	vm3.id = "vampm_blutgier"
	vm3.title = "Blutgier"
	vm3.description = "Blutritter: +30% Schaden, +10% Tempo, -10% Max HP."
	vm3.rarity = "Epic"
	vm3.color = Color(0.55, 0.06, 0.14)
	vm3.hero_id = "vampire_melee"
	vm3.damage_mult = 1.30
	vm3.move_speed_mult = 1.10
	vm3.max_hp_mult = 0.90
	_register(vm3)

	# Fähigkeits-Familie Blutbersten: Grundkarte + zwei Evolutionen.
	var vm4 = CardData.new()
	vm4.id = "vampm_blutbersten"
	vm4.title = "Weites Bersten"
	vm4.description = "Blutritter – Blutbersten: +30% Radius, -15% Fähigkeits-Abklingzeit."
	vm4.rarity = "Rare"
	vm4.pool = "Offensive"
	vm4.color = Color(0.70, 0.10, 0.18)
	vm4.hero_id = "vampire_melee"
	vm4.family_id = "vampm_burst"
	vm4.ability_radius_mult = 1.30
	vm4.ability_cooldown_mult = 0.85
	_register(vm4)

	var vm4a = CardData.new()
	vm4a.id = "vampm_blutspende"
	vm4a.title = "Blutspende"
	vm4a.description = "Blutbersten-Evolution: Du heilst dich um 30% des verbrauchten Schilds."
	vm4a.rarity = "Epic"
	vm4a.color = Color(0.70, 0.10, 0.18)
	vm4a.hero_id = "vampire_melee"
	vm4a.family_id = "vampm_burst"
	vm4a.parent_card_id = "vampm_blutbersten"
	vm4a.evolution_branch = "A"
	vm4a.ability_evolution = "vampm_burst_heal"
	_register(vm4a)

	var vm4b = CardData.new()
	vm4b.id = "vampm_blutregen"
	vm4b.title = "Blutregen"
	vm4b.description = "Blutbersten-Evolution: Jeder getroffene Gegner lässt eine Blutkugel fallen."
	vm4b.rarity = "Epic"
	vm4b.color = Color(0.70, 0.10, 0.18)
	vm4b.hero_id = "vampire_melee"
	vm4b.family_id = "vampm_burst"
	vm4b.parent_card_id = "vampm_blutbersten"
	vm4b.evolution_branch = "B"
	vm4b.ability_evolution = "vampm_burst_orbs"
	_register(vm4b)

	var vm5 = CardData.new()
	vm5.id = "vampm_blutschneise"
	vm5.title = "Blutschneise"
	vm5.description = "Blutritter – Blutsturm: Der Dash schneidet alle Gegner auf dem Weg (50% Nahkampfschaden)."
	vm5.rarity = "Epic"
	vm5.pool = "Offensive"
	vm5.color = Color(0.62, 0.08, 0.16)
	vm5.hero_id = "vampire_melee"
	vm5.ability_evolution = "vampm_dash_cut"
	_register(vm5)

	var vm6 = CardData.new()
	vm6.id = "vampm_blutsog"
	vm6.title = "Blutsog"
	vm6.description = "Blutritter – Blutruf: zieht bis zu 10 statt 6 Kugeln aus 40% größerem Umkreis, -10% Ulti-Abklingzeit."
	vm6.rarity = "Epic"
	vm6.pool = "Offensive"
	vm6.color = Color(0.62, 0.08, 0.16)
	vm6.hero_id = "vampire_melee"
	vm6.ult_cooldown_mult = 0.90
	vm6.ability_evolution = "vampm_ult_more"
	_register(vm6)

	# --- Zeitschläger: Taktschlag, Zeitblase, Rückspul, Zeitstopp ---
	var zs1 = CardData.new()
	zs1.id = "zeit_taktgeber"
	zs1.title = "Taktgeber"
	zs1.description = "Zeitschläger: +15% Nahkampftempo, +10% Lauftempo."
	zs1.rarity = "Common"
	zs1.pool = "Bewegung"
	zs1.color = Color(0.86, 0.68, 0.30)
	zs1.hero_id = "zeitschlaeger"
	zs1.melee_cooldown_mult = 0.85
	zs1.move_speed_mult = 1.1
	_register(zs1)

	var zs2 = CardData.new()
	zs2.id = "zeit_schweres_pendel"
	zs2.title = "Schweres Pendel"
	zs2.description = "Zeitschläger: +30% Nahkampfschaden, +0,5 Felder Reichweite, -10% Nahkampftempo."
	zs2.rarity = "Uncommon"
	zs2.pool = "Offensive"
	zs2.color = Color(0.86, 0.68, 0.30)
	zs2.hero_id = "zeitschlaeger"
	zs2.melee_damage_mult = 1.3
	zs2.melee_range_add = 0.5
	zs2.melee_cooldown_mult = 1.1
	_register(zs2)

	var zs3 = CardData.new()
	zs3.id = "zeit_stundenschlag"
	zs3.title = "Stundenschlag"
	zs3.description = "Zeitschläger – Taktschlag: Schon jeder %d. Treffer verlangsamt, und zwar %.1f s lang." % [Player.ZEITEVO_FAST_HIT_INTERVAL, Player.ZEITEVO_FAST_SLOW_DURATION]
	zs3.rarity = "Epic"
	zs3.pool = "Offensive"
	zs3.color = Color(0.86, 0.68, 0.30)
	zs3.hero_id = "zeitschlaeger"
	zs3.ability_evolution = "zeit_passive_fast"
	_register(zs3)

	var zs4 = CardData.new()
	zs4.id = "zeit_grosse_blase"
	zs4.title = "Große Blase"
	zs4.description = "Zeitschläger – Zeitblase: +30% Radius, +25% Dauer, -10% Fähigkeits-Abklingzeit."
	zs4.rarity = "Rare"
	zs4.pool = "Defensive"
	zs4.color = Color(0.55, 0.72, 0.95)
	zs4.hero_id = "zeitschlaeger"
	zs4.family_id = "zeit_bubble"
	zs4.ability_radius_mult = 1.3
	zs4.ability_duration_mult = 1.25
	zs4.ability_cooldown_mult = 0.9
	_register(zs4)

	var zs4a = CardData.new()
	zs4a.id = "zeit_zerfall"
	zs4a.title = "Zerfall"
	zs4a.description = "Zeitblase-Evolution: Gegner in der Blase verlieren %d HP pro Sekunde." % int(Player.ZEITEVO_DECAY_DPS)
	zs4a.rarity = "Epic"
	zs4a.color = Color(0.55, 0.72, 0.95)
	zs4a.hero_id = "zeitschlaeger"
	zs4a.family_id = "zeit_bubble"
	zs4a.parent_card_id = "zeit_grosse_blase"
	zs4a.evolution_branch = "A"
	zs4a.ability_evolution = "zeit_bubble_decay"
	_register(zs4a)

	var zs4b = CardData.new()
	zs4b.id = "zeit_eigenzeit"
	zs4b.title = "Eigenzeit"
	zs4b.description = "Zeitblase-Evolution: In deiner Blase bist du %d%% schneller." % int(round((Player.ZEITEVO_HASTE_MULT - 1.0) * 100.0))
	zs4b.rarity = "Epic"
	zs4b.color = Color(0.55, 0.72, 0.95)
	zs4b.hero_id = "zeitschlaeger"
	zs4b.family_id = "zeit_bubble"
	zs4b.parent_card_id = "zeit_grosse_blase"
	zs4b.evolution_branch = "B"
	zs4b.ability_evolution = "zeit_bubble_haste"
	_register(zs4b)

	var zs5 = CardData.new()
	zs5.id = "zeit_lange_erinnerung"
	zs5.title = "Lange Erinnerung"
	zs5.description = "Zeitschläger – Rückspul: reicht %.0f s weiter zurück, -15%% Dash-Abklingzeit." % Player.ZEITEVO_LONG_REWIND_ADD
	zs5.rarity = "Rare"
	zs5.pool = "Bewegung"
	zs5.color = Color(0.86, 0.68, 0.30)
	zs5.hero_id = "zeitschlaeger"
	zs5.family_id = "zeit_rewind"
	zs5.ability_evolution = "zeit_rewind_long"
	zs5.dash_cooldown_mult = 0.85
	_register(zs5)

	var zs5a = CardData.new()
	zs5a.id = "zeit_zeitriss"
	zs5a.title = "Zeitriss"
	zs5a.description = "Rückspul-Evolution: An der verlassenen Stelle explodiert die Zeit (%d Schaden, Radius %d px, Rückstoß)." % [int(Player.ZEITEVO_RIFT_DAMAGE), int(Player.ZEITEVO_RIFT_RADIUS)]
	zs5a.rarity = "Epic"
	zs5a.color = Color(0.86, 0.68, 0.30)
	zs5a.hero_id = "zeitschlaeger"
	zs5a.family_id = "zeit_rewind"
	zs5a.parent_card_id = "zeit_lange_erinnerung"
	zs5a.evolution_branch = "A"
	zs5a.ability_evolution = "zeit_rewind_rift"
	_register(zs5a)

	var zs5b = CardData.new()
	zs5b.id = "zeit_reinigung"
	zs5b.title = "Reinigung"
	zs5b.description = "Rückspul-Evolution: Entfernt Gift, Brand und Verlangsamung und gibt %d Schild, auch über das Maximum." % int(Player.ZEITEVO_CLEANSE_SHIELD)
	zs5b.rarity = "Epic"
	zs5b.color = Color(0.86, 0.68, 0.30)
	zs5b.hero_id = "zeitschlaeger"
	zs5b.family_id = "zeit_rewind"
	zs5b.parent_card_id = "zeit_lange_erinnerung"
	zs5b.evolution_branch = "B"
	zs5b.ability_evolution = "zeit_rewind_cleanse"
	_register(zs5b)

	var zs6 = CardData.new()
	zs6.id = "zeit_ewige_sekunde"
	zs6.title = "Ewige Sekunde"
	zs6.description = "Zeitschläger – Zeitstopp: hält 50% länger."
	zs6.rarity = "Epic"
	zs6.pool = "Offensive"
	zs6.color = Color(0.55, 0.72, 0.95)
	zs6.hero_id = "zeitschlaeger"
	zs6.ult_duration_mult = 1.5
	_register(zs6)

	var zs7 = CardData.new()
	zs7.id = "zeit_zinseszins"
	zs7.title = "Zinseszins"
	zs7.description = "Zeitschläger – Zeitstopp: Gestaute Treffer schlagen mit %d%% Schaden ein." % int(round(Player.ZEITEVO_STOP_AMP * 100.0))
	zs7.rarity = "Epic"
	zs7.pool = "Offensive"
	zs7.color = Color(0.55, 0.72, 0.95)
	zs7.hero_id = "zeitschlaeger"
	zs7.ability_evolution = "zeit_stop_amp"
	_register(zs7)

	var zs8 = CardData.new()
	zs8.id = "zeit_schnellladung"
	zs8.title = "Schnellladung"
	zs8.description = "Zeitschläger: -15% Ulti-Abklingzeit, -10% Fähigkeits-Abklingzeit."
	zs8.rarity = "Uncommon"
	zs8.pool = "Defensive"
	zs8.color = Color(0.86, 0.68, 0.30)
	zs8.hero_id = "zeitschlaeger"
	zs8.ult_cooldown_mult = 0.85
	zs8.ability_cooldown_mult = 0.9
	_register(zs8)

	var gu1 = CardData.new()
	gu1.id = "ulti_akku"
	gu1.title = "Ulti-Akku"
	gu1.description = "-15% Ulti-Abklingzeit."
	gu1.rarity = "Uncommon"
	gu1.pool = "Offensive"
	gu1.color = Color(1.0, 0.75, 0.3)
	gu1.required_mechanic = "ult"
	gu1.ult_cooldown_mult = 0.85
	_register(gu1)

	# --- Druide: Wurzelwall ---
	var dr1 = CardData.new()
	dr1.id = "druid_wurzelwerk"
	dr1.title = "Wurzelwerk"
	dr1.description = "Druide – Wurzelwall: Wände +30% größer."
	dr1.rarity = "Uncommon"
	dr1.pool = "Defensive"
	dr1.color = Color(0.50, 0.72, 0.36)
	dr1.hero_id = "druid"
	dr1.ability_radius_mult = 1.30
	_register(dr1)

	var dr2 = CardData.new()
	dr2.id = "druid_immergruen"
	dr2.title = "Immergrün"
	dr2.description = "Druide – Wurzelwall: Wände halten 40% länger."
	dr2.rarity = "Uncommon"
	dr2.pool = "Defensive"
	dr2.color = Color(0.50, 0.72, 0.36)
	dr2.hero_id = "druid"
	dr2.ability_duration_mult = 1.40
	_register(dr2)

	var dr3 = CardData.new()
	dr3.id = "druid_schnellwuchs"
	dr3.title = "Schnellwuchs"
	dr3.description = "Druide – Wurzelwall: -25% Fähigkeits-Abklingzeit."
	dr3.rarity = "Uncommon"
	dr3.pool = "Defensive"
	dr3.color = Color(0.50, 0.72, 0.36)
	dr3.hero_id = "druid"
	dr3.ability_cooldown_mult = 0.75
	_register(dr3)

	var dr4 = CardData.new()
	dr4.id = "druid_wildwuchs"
	dr4.title = "Wildwuchs"
	dr4.description = "Druide – Wurzelwall: +1 Wand gleichzeitig."
	dr4.rarity = "Rare"
	dr4.pool = "Defensive"
	dr4.color = Color(0.50, 0.72, 0.36)
	dr4.hero_id = "druid"
	dr4.family_id = "druid_wall"
	dr4.wall_count_add = 1
	_register(dr4)

	var dr5 = CardData.new()
	dr5.id = "druid_elementarwand"
	dr5.title = "Elementarwand"
	dr5.description = "Wurzelwall-Evolution: Gegner, die deine Wand berühren, bekommen die Effekte deiner Waffe ab (Gift, Feuer, Frost, Blitz). Ohne Elementeffekt vergiften die Dornen."
	dr5.rarity = "Epic"
	dr5.color = Color(0.50, 0.72, 0.36)
	dr5.hero_id = "druid"
	dr5.family_id = "druid_wall"
	dr5.parent_card_id = "druid_wildwuchs"
	dr5.evolution_branch = "A"
	dr5.ability_evolution = "druid_elemental"
	_register(dr5)

	var dr6 = CardData.new()
	dr6.id = "druid_urwald"
	dr6.title = "Urwald"
	dr6.description = "Wurzelwall-Evolution: Wände halten 50% länger, bis zu +4 Wände gleichzeitig."
	dr6.rarity = "Epic"
	dr6.color = Color(0.50, 0.72, 0.36)
	dr6.hero_id = "druid"
	dr6.family_id = "druid_wall"
	dr6.parent_card_id = "druid_wildwuchs"
	dr6.evolution_branch = "B"
	dr6.ability_evolution = "druid_grove"
	dr6.ability_duration_mult = 1.50
	# Zusammen mit Wildwuchs (+1) ergibt das +4 Wände.
	dr6.wall_count_add = 3
	_register(dr6)

	var dr7 = CardData.new()
	dr7.id = "druid_lebensborke"
	dr7.title = "Lebensborke"
	dr7.description = "Wurzelwall-Evolution: Berührst du deine Wand, heilt sie dich um 12 HP pro Sekunde."
	dr7.rarity = "Epic"
	dr7.color = Color(0.50, 0.72, 0.36)
	dr7.hero_id = "druid"
	dr7.family_id = "druid_wall"
	dr7.parent_card_id = "druid_wildwuchs"
	dr7.evolution_branch = "C"
	dr7.ability_evolution = "druid_lifebark"
	_register(dr7)

	# --- Druide: Rankenschwung (Dash) und Urkeiler (Ulti) ---
	var dr8 = CardData.new()
	dr8.id = "druid_lange_ranke"
	dr8.title = "Lange Ranke"
	dr8.description = "Druide – Rankenschwung: +35% Rankenweite, -10% Dash-Abklingzeit."
	dr8.rarity = "Rare"
	dr8.pool = "Bewegung"
	dr8.color = Color(0.50, 0.72, 0.36)
	dr8.hero_id = "druid"
	dr8.family_id = "druid_dash"
	dr8.dash_effect_mult = 1.35
	dr8.dash_cooldown_mult = 0.9
	_register(dr8)

	var dr9 = CardData.new()
	dr9.id = "druid_fesselranke"
	dr9.title = "Fesselranke"
	dr9.description = "Rankenschwung-Evolution: Gegner auf der Linie der Ranke werden 0,7 s festgehalten."
	dr9.rarity = "Epic"
	dr9.color = Color(0.50, 0.72, 0.36)
	dr9.hero_id = "druid"
	dr9.family_id = "druid_dash"
	dr9.parent_card_id = "druid_lange_ranke"
	dr9.evolution_branch = "A"
	dr9.ability_evolution = "druid_vine_snare"
	_register(dr9)

	var dr10 = CardData.new()
	dr10.id = "druid_rankenkletterer"
	dr10.title = "Rankenkletterer"
	dr10.description = "Rankenschwung-Evolution: Greift die Ranke deinen eigenen Wurzelwall, bekommst du die Dash-Ladung zurück."
	dr10.rarity = "Epic"
	dr10.color = Color(0.50, 0.72, 0.36)
	dr10.hero_id = "druid"
	dr10.family_id = "druid_dash"
	dr10.parent_card_id = "druid_lange_ranke"
	dr10.evolution_branch = "B"
	dr10.ability_evolution = "druid_vine_wall"
	_register(dr10)

	var dr11 = CardData.new()
	dr11.id = "druid_urkraft"
	dr11.title = "Urkraft"
	dr11.description = "Druide – Urkeiler: Hält 30% länger, +25% Schaden."
	dr11.rarity = "Rare"
	dr11.pool = "Offensive"
	dr11.color = Color(0.50, 0.72, 0.36)
	dr11.hero_id = "druid"
	dr11.family_id = "druid_ult"
	dr11.ult_duration_mult = 1.3
	dr11.ult_damage_mult = 1.25
	_register(dr11)

	var dr12 = CardData.new()
	dr12.id = "druid_raserei"
	dr12.title = "Raserei"
	dr12.description = "Urkeiler-Evolution: Jeder Treffer in Keilergestalt verlängert sie um 0,5 s."
	dr12.rarity = "Epic"
	dr12.color = Color(0.50, 0.72, 0.36)
	dr12.hero_id = "druid"
	dr12.family_id = "druid_ult"
	dr12.parent_card_id = "druid_urkraft"
	dr12.evolution_branch = "A"
	dr12.ability_evolution = "druid_frenzy"
	_register(dr12)

	var dr13 = CardData.new()
	dr13.id = "druid_dornenfell"
	dr13.title = "Dornenfell"
	dr13.description = "Urkeiler-Evolution: In Keilergestalt wirfst du 30% des erlittenen Schadens zurück."
	dr13.rarity = "Epic"
	dr13.color = Color(0.50, 0.72, 0.36)
	dr13.hero_id = "druid"
	dr13.family_id = "druid_ult"
	dr13.parent_card_id = "druid_urkraft"
	dr13.evolution_branch = "B"
	dr13.ability_evolution = "druid_thornhide"
	_register(dr13)


	# ============================================================
	# Block-Karten (universell, verbessern die Q-Fähigkeit)
	# ============================================================

	# --- Common ---
	var bl1 = CardData.new()
	bl1.id = "block_uebung"
	bl1.title = "Barriereübung"
	bl1.description = "Längere Deckung.\n+0,15s Barrieredauer."
	bl1.rarity = "Common"
	bl1.color = Color(0.45, 0.80, 1.00)
	bl1.block_duration_add = 0.15
	_register(bl1)

	var bl2 = CardData.new()
	bl2.id = "schnelle_deckung"
	bl2.title = "Schnelle Deckung"
	bl2.description = "Schneller wieder bereit.\n-15% Barriere-Abklingzeit."
	bl2.rarity = "Common"
	bl2.color = Color(0.35, 0.75, 0.95)
	bl2.block_cooldown_mult = 0.85
	_register(bl2)

	# --- Uncommon ---
	var bl3 = CardData.new()
	bl3.id = "verstaerkte_deckung"
	bl3.version = 2 # Blockdauer +0,30 s statt +0,20 s
	bl3.title = "Verstärkte Deckung"
	bl3.description = "Längere Schadensimmunität.\n+0,3s Barrieredauer."
	bl3.rarity = "Uncommon"
	bl3.color = Color(0.40, 0.70, 1.00)
	bl3.block_duration_add = 0.30
	_register(bl3)

	var bl4 = CardData.new()
	bl4.id = "schildstoss"
	bl4.title = "Barrierestoß"
	bl4.description = "Barriere stößt Gegner in der Nähe weg.\n+130px Radius, +350 Rückstoß."
	bl4.rarity = "Uncommon"
	bl4.color = Color(0.55, 0.90, 1.00)
	bl4.block_knockback_radius_add = 130.0
	bl4.block_knockback_force_add = 350.0
	_register(bl4)

	# --- Rare ---
	var bl5 = CardData.new()
	bl5.id = "blockbombe"
	bl5.title = "Barrierebombe"
	bl5.description = "Beim Aktivieren der Barriere explodiert eine Bombe.\n35 Schaden + Rückstoß im Umkreis."
	bl5.rarity = "Rare"
	bl5.color = Color(1.00, 0.55, 0.15)
	bl5.block_bomb = true
	bl5.block_bomb_damage = 35.0
	_register(bl5)

	var bl6 = CardData.new()
	bl6.id = "heilzone"
	bl6.title = "Heilzone"
	bl6.description = "Barriere erzeugt ein Heilfeld.\nHeilt 6 HP alle 0,5s für 2,5s."
	bl6.rarity = "Rare"
	bl6.color = Color(0.35, 1.00, 0.55)
	bl6.block_heal_zone = true
	_register(bl6)

	var bl7 = CardData.new()
	bl7.id = "druckwelle"
	bl7.title = "Druckwelle"
	bl7.description = "Starker Rückstoß beim Aktivieren der Barriere.\n+170px Radius, +600 Rückstoß."
	bl7.rarity = "Rare"
	bl7.color = Color(0.40, 0.90, 1.00)
	bl7.block_knockback_radius_add = 170.0
	bl7.block_knockback_force_add = 600.0
	_register(bl7)

	var bl8 = CardData.new()
	bl8.id = "ausdauerblock"
	bl8.version = 3 # +0,3s Blockdauer statt +0,15s (Jochen)
	bl8.title = "Ausdauerbarriere"
	bl8.description = "Barriere-Ausbau: Länger und öfter abschirmen.\n+0,3s Barrieredauer, -10% Barriere-Abklingzeit."
	bl8.rarity = "Rare"
	bl8.color = Color(0.50, 0.85, 0.95)
	bl8.family_id = "verstaerkte_deckung"
	bl8.parent_card_id = "verstaerkte_deckung"
	bl8.evolution_branch = "A"
	bl8.block_duration_add = 0.30
	bl8.block_cooldown_mult = 0.90
	_register(bl8)

	# --- Epic ---
	var bl9 = CardData.new()
	bl9.id = "spiegelblock"
	bl9.title = "Konterblitz"
	bl9.description = "Reflektierte Projektile richten +50% Schaden an."
	bl9.rarity = "Epic"
	bl9.color = Color(0.75, 0.45, 1.00)
	bl9.block_reflect_damage_add = 0.50
	_register(bl9)

	var bl10 = CardData.new()
	bl10.id = "block_experte"
	bl10.title = "Barriere-Experte"
	bl10.description = "Meisterhafte Deckung.\n-30% Barriere-Abklingzeit, +0,2s Barrieredauer."
	bl10.rarity = "Epic"
	bl10.color = Color(0.45, 0.75, 1.00)
	bl10.block_cooldown_mult = 0.70
	bl10.block_duration_add = 0.20
	_register(bl10)

	var bl11 = CardData.new()
	bl11.id = "unzerbrechlich"
	bl11.title = "Unzerbrechlich"
	bl11.description = "Deutlich längere Deckung.\n+0,4s Barrieredauer, -10% Barriere-Abklingzeit."
	bl11.rarity = "Epic"
	bl11.color = Color(0.55, 0.65, 0.90)
	bl11.block_duration_add = 0.40
	bl11.block_cooldown_mult = 0.90
	_register(bl11)

	var bl12 = CardData.new()
	bl12.id = "panzerglas"
	bl12.title = "Panzerglas"
	bl12.description = "Die Barriere zerbricht nicht so schnell.\n+1 Treffer, den die Barriere aushält."
	bl12.rarity = "Uncommon"
	bl12.color = Color(0.55, 0.90, 1.00)
	bl12.block_hits_add = 1
	_register(bl12)

	# --- Minenleger (Talentbaum + Minen-Karten) ---
	var mn1 = CardData.new()
	mn1.id = "minenleger"
	mn1.title = "Minenleger"
	mn1.description = "Jede Barriere legt eine Mine, die zu Boden fällt. Gegner sehen sie nicht.\nNach 2s scharf, explodiert 1,5s nachdem ein Gegner darüberläuft.\n50 Schaden, 2 Felder Explosionsradius."
	mn1.rarity = "Rare"
	mn1.pool = "Defensive"
	mn1.color = Color(0.95, 0.35, 0.25)
	mn1.family_id = "minenleger"
	mn1.block_mine = true
	_register(mn1)

	var mn2 = CardData.new()
	mn2.id = "minen_sofortzuender"
	mn2.title = "Sofortzünder"
	mn2.description = "Minen-Ausbau: Keine Vorwarnung.\nMinen explodieren sofort, wenn ein Gegner darüberläuft."
	mn2.rarity = "Epic"
	mn2.color = Color(1.00, 0.45, 0.20)
	mn2.family_id = "minenleger"
	mn2.parent_card_id = "minenleger"
	mn2.evolution_branch = "A"
	mn2.mine_instant = true
	_register(mn2)

	# Minen-Karten erscheinen nur, wenn Minenleger im Deck liegt.
	var mn3 = CardData.new()
	mn3.id = "minenschaden"
	mn3.title = "Minenschaden"
	mn3.description = "Minen-Karte: Mehr Sprengstoff.\n+50 Minenschaden."
	mn3.rarity = "Rare"
	mn3.pool = "Defensive"
	mn3.color = Color(1.00, 0.30, 0.20)
	mn3.required_mechanic = "mine"
	mn3.mine_damage_add = 50.0
	_register(mn3)

	var mn4 = CardData.new()
	mn4.id = "minenreichweite"
	mn4.title = "Minenreichweite"
	mn4.description = "Minen-Karte: Größere Druckwelle.\n+1 Feld Explosionsradius für Minen."
	mn4.rarity = "Uncommon"
	mn4.pool = "Defensive"
	mn4.color = Color(1.00, 0.55, 0.30)
	mn4.required_mechanic = "mine"
	mn4.mine_radius_add = 1.0
	_register(mn4)

	# --- Neue Pool-Karten ---
	# Offensive
	var of1 = CardData.new()
	of1.id = "splittergeschoss"
	of1.title = "Splittergeschoss"
	of1.description = "Zusätzliches Projektil mit Streuung.\n+1 Schuss, +6° Streuung, -10% Schaden."
	of1.rarity = "Uncommon"
	of1.pool = "Offensive"
	of1.color = Color(0.35, 0.85, 1.00)
	of1.multishot_add = 1
	of1.spread_angle_deg = 6.0
	of1.damage_mult = 0.90
	_register(of1)

	var of2 = CardData.new()
	of2.id = "panzerbrecher"
	of2.title = "Panzerbrecher"
	of2.description = "Durchschlägt Gegner und Deckung.\n+30% Schaden, +1 Durchschlag, -10% Projektilgeschwindigkeit."
	of2.rarity = "Rare"
	of2.pool = "Offensive"
	of2.color = Color(1.00, 0.55, 0.20)
	of2.damage_mult = 1.30
	of2.piercing_add = 1
	of2.bullet_speed_mult = 0.90
	of2.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(of2)

	# Brandkapsel ist seit 2026-11-25 Ausbau B von Feuersturm (siehe dort).

	# --- Kettenblitz ---
	# Seit 2026-11-26 eigene Grundkarte für alle Helden (vorher Blitzschuss-Ausbau A,
	# nur Fernkampf). Kettenreaktion ist ihr Ausbau mit einem Sprung mehr.
	var lb2 = CardData.new()
	lb2.id = "blitzschuss_kette"
	lb2.version = 3 # eigene Grundkarte, auch für Nahkämpfer, Rare statt Epic
	lb2.title = "Kettenblitz"
	lb2.description = "Treffer springen als Blitz auf den nächsten Gegner über.\n45% Schaden, 0,1s Betäubung.\nIm 1-gegen-1 springt der Blitz aufs Ziel zurück."
	lb2.rarity = "Rare"
	lb2.pool = "Offensive"
	lb2.color = Color(1.00, 0.80, 0.10)
	lb2.family_id = "blitzschuss_kette"
	lb2.chain_lightning = true
	_register(lb2)

	var of4 = CardData.new()
	of4.id = "kettenreaktion"
	of4.version = 3 # Ausbau A von Kettenblitz: +1 Sprung (vorher eigene Karte mit Blitzschuss + Kettenblitz)
	of4.title = "Kettenreaktion"
	of4.description = "Kettenblitz-Ausbau: Der Blitz springt ein weiteres Mal.\n+1 Sprung."
	of4.rarity = "Epic"
	of4.pool = "Offensive"
	of4.color = Color(0.95, 0.85, 0.20)
	of4.family_id = "blitzschuss_kette"
	of4.parent_card_id = "blitzschuss_kette"
	of4.evolution_branch = "A"
	of4.chain_jumps_add = 1
	_register(of4)

	# Defensive
	var df1 = CardData.new()
	df1.id = "sanitaeter"
	df1.version = 4 # Evolution B von regenerations_modul
	df1.title = "Sanitäter"
	df1.description = "Regenerations-Ausbau: Heilung und Polster.\n+1 HP/s Regeneration, +30 Max HP."
	df1.rarity = "Uncommon"
	df1.pool = "Defensive"
	df1.color = Color(0.35, 1.00, 0.55)
	df1.family_id = "regenerations_modul"
	df1.parent_card_id = "regenerations_modul"
	df1.evolution_branch = "B"
	df1.hp_regen_add = 1.0
	df1.max_hp_flat = 30
	_register(df1)

	var df2 = CardData.new()
	df2.id = "bollwerk"
	df2.version = 3 # Barriere-Bonus durch Schild-Cooldown ersetzt (Schild und Barriere getrennt)
	df2.title = "Bollwerk"
	df2.description = "Mehr Schild, der früher wieder lädt.\n+60 Schild, -0,5s Schild-Cooldown."
	df2.rarity = "Rare"
	df2.pool = "Defensive"
	df2.color = Color(0.40, 0.75, 1.00)
	df2.shield_max_add = 60
	df2.shield_regen_delay_add = -0.5
	_register(df2)

	var df3 = CardData.new()
	df3.id = "zweites_herz"
	df3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	df3.title = "Zweites Herz"
	df3.description = "Deutlich mehr Lebensraum.\n+100 Max HP, +1 HP/s Regeneration."
	df3.rarity = "Epic"
	df3.pool = "Defensive"
	df3.color = Color(1.00, 0.30, 0.45)
	df3.max_hp_flat = 100
	df3.hp_regen_add = 1.0
	_register(df3)

	# --- Tank-Panzerung: Evolutionsbaum ---
	# Die Grundkarte teilt sich in einen prozentualen Lebens-/Rüstungszweig (A)
	# und einen Reflexionszweig (B). Jede Seltenheit ist im Baum vertreten.
	var tk1 = CardData.new()
	tk1.id = "tankplatte"
	tk1.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk1.title = "Tankplatte"
	tk1.description = "Mehr Leben und eine erste Panzerung.\n+60 Max HP, +5% Rüstung."
	tk1.rarity = "Common"
	tk1.pool = "Defensive"
	tk1.color = Color(0.45, 0.72, 0.55)
	tk1.family_id = "tank_panzerung"
	tk1.max_hp_flat = 60
	tk1.armor_percent_add = 0.05
	_register(tk1)

	var tk2 = CardData.new()
	tk2.id = "tank_stahlhaut"
	tk2.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk2.title = "Stahlhaut"
	tk2.description = "Prozentual mehr Leben und stärkere Panzerung.\n+36% Max HP, +6% Rüstung."
	tk2.rarity = "Uncommon"
	tk2.color = Color(0.40, 0.80, 0.55)
	tk2.family_id = "tank_panzerung"
	tk2.parent_card_id = "tankplatte"
	tk2.evolution_branch = "A"
	tk2.max_hp_mult = 1.36
	tk2.armor_percent_add = 0.06
	_register(tk2)

	var tk3 = CardData.new()
	tk3.id = "tank_dornenhaut"
	tk3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk3.title = "Dornenhaut"
	tk3.description = "Gepanzerte Stacheln werfen Schaden zurück.\n+50 Max HP, +8% Rüstung, 8% Schadensreflexion."
	tk3.rarity = "Uncommon"
	tk3.color = Color(0.55, 0.65, 0.35)
	tk3.family_id = "tank_panzerung"
	tk3.parent_card_id = "tankplatte"
	tk3.evolution_branch = "B"
	tk3.max_hp_flat = 50
	tk3.armor_percent_add = 0.08
	tk3.damage_reflect_percent_add = 0.08
	_register(tk3)

	var tk4 = CardData.new()
	tk4.id = "tank_festungspanzer"
	tk4.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk4.title = "Festungspanzer"
	tk4.description = "Schwerer Prozent-Lebenspanzer.\n+50% Max HP, +10% Rüstung, -5% Tempo."
	tk4.rarity = "Rare"
	tk4.color = Color(0.35, 0.65, 0.45)
	tk4.family_id = "tank_panzerung"
	tk4.parent_card_id = "tank_stahlhaut"
	tk4.evolution_branch = "A"
	tk4.max_hp_mult = 1.50
	tk4.armor_percent_add = 0.10
	tk4.move_speed_mult = 0.95
	_register(tk4)

	var tk5 = CardData.new()
	tk5.id = "tank_reflektorplatte"
	tk5.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk5.title = "Reflektorplatte"
	tk5.description = "Leitet einen Teil des Schadens zurück.\n+80 Max HP, +12% Rüstung, 12% Schadensreflexion."
	tk5.rarity = "Rare"
	tk5.color = Color(0.55, 0.55, 0.85)
	tk5.family_id = "tank_panzerung"
	tk5.parent_card_id = "tank_dornenhaut"
	tk5.evolution_branch = "B"
	tk5.max_hp_flat = 80
	tk5.armor_percent_add = 0.12
	tk5.damage_reflect_percent_add = 0.12
	_register(tk5)

	var tk6 = CardData.new()
	tk6.id = "tank_titanenbollwerk"
	tk6.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk6.title = "Titanenbollwerk"
	tk6.description = "Massiver Lebens- und Panzerturm.\n+50% Max HP, +12% Rüstung, 10% Schadensreflexion, -8% Tempo."
	tk6.rarity = "Epic"
	tk6.color = Color(0.45, 0.55, 0.35)
	tk6.family_id = "tank_panzerung"
	tk6.parent_card_id = "tank_festungspanzer"
	tk6.evolution_branch = "A"
	tk6.max_hp_mult = 1.50
	tk6.armor_percent_add = 0.12
	tk6.damage_reflect_percent_add = 0.10
	tk6.move_speed_mult = 0.92
	_register(tk6)

	var tk7 = CardData.new()
	tk7.id = "tank_spiegelpanzer"
	tk7.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk7.title = "Spiegelpanzer"
	tk7.description = "Spiegelt Angriffe mit voller Wucht.\n+100 Max HP, +14% Rüstung, 18% Schadensreflexion."
	tk7.rarity = "Epic"
	tk7.color = Color(0.60, 0.45, 0.90)
	tk7.family_id = "tank_panzerung"
	tk7.parent_card_id = "tank_reflektorplatte"
	tk7.evolution_branch = "B"
	tk7.max_hp_flat = 100
	tk7.armor_percent_add = 0.14
	tk7.damage_reflect_percent_add = 0.18
	_register(tk7)

	var tk8 = CardData.new()
	tk8.id = "tank_ewige_bastion"
	tk8.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk8.title = "Ewige Bastion"
	tk8.description = "Unerschütterlicher Koloss aus Leben und Stahl.\n+70% Max HP, +18% Rüstung, 15% Schadensreflexion, -10% Tempo."
	tk8.rarity = "Legendary"
	tk8.color = Color(0.95, 0.78, 0.30)
	tk8.family_id = "tank_panzerung"
	tk8.parent_card_id = "tank_titanenbollwerk"
	tk8.evolution_branch = "A"
	tk8.max_hp_mult = 1.70
	tk8.armor_percent_add = 0.18
	tk8.damage_reflect_percent_add = 0.15
	tk8.move_speed_mult = 0.90
	_register(tk8)

	var tk9 = CardData.new()
	tk9.id = "tank_spiegelkoloss"
	tk9.version = 2 # Max-HP/Schild-Bonus verdoppelt
	tk9.title = "Spiegelkoloss"
	tk9.description = "Ein wandelnder Spiegel, der Schaden zurückwirft.\n+120 Max HP, +16% Rüstung, 22% Schadensreflexion."
	tk9.rarity = "Legendary"
	tk9.color = Color(0.90, 0.65, 1.00)
	tk9.family_id = "tank_panzerung"
	tk9.parent_card_id = "tank_spiegelpanzer"
	tk9.evolution_branch = "B"
	tk9.max_hp_flat = 120
	tk9.armor_percent_add = 0.16
	tk9.damage_reflect_percent_add = 0.22
	_register(tk9)

	# --- Reflexions-Tanks (eigenständig, unabhängig vom Evolutionsbaum) ---
	var rf1 = CardData.new()
	rf1.id = "stachelweste"
	rf1.version = 2 # Max-HP/Schild-Bonus verdoppelt
	rf1.title = "Stachelweste"
	rf1.description = "Wer zuschlägt, sticht sich selbst.\n+30 Max HP, 6% Schadensreflexion."
	rf1.rarity = "Common"
	rf1.pool = "Defensive"
	rf1.color = Color(0.62, 0.70, 0.45)
	rf1.max_hp_flat = 30
	rf1.damage_reflect_percent_add = 0.06
	_register(rf1)

	var rf2 = CardData.new()
	rf2.id = "rachepanzer"
	rf2.version = 1
	rf2.title = "Rachepanzer"
	rf2.description = "Je angeschlagener, desto gefährlicher.\n+5% Rüstung, 8% Schadensreflexion, +12% Reflexion unter 35% Leben."
	rf2.rarity = "Uncommon"
	rf2.pool = "Defensive"
	rf2.color = Color(0.85, 0.40, 0.35)
	rf2.armor_percent_add = 0.05
	rf2.damage_reflect_percent_add = 0.08
	rf2.reflect_low_hp_bonus_add = 0.12
	_register(rf2)

	var rf3 = CardData.new()
	rf3.id = "blutspiegel"
	rf3.version = 2 # Max-HP/Schild-Bonus verdoppelt
	rf3.title = "Blutspiegel"
	rf3.description = "Zurückgeworfener Schaden nährt dich.\n+40 Max HP, 12% Schadensreflexion, 50% des reflektierten Schadens heilen dich."
	rf3.rarity = "Rare"
	rf3.pool = "Defensive"
	rf3.color = Color(0.85, 0.25, 0.45)
	rf3.max_hp_flat = 40
	rf3.damage_reflect_percent_add = 0.12
	rf3.reflect_heal_percent_add = 0.50
	_register(rf3)

	var rf4 = CardData.new()
	rf4.id = "vergeltungsschild"
	rf4.version = 2 # Max-HP/Schild-Bonus verdoppelt
	rf4.title = "Vergeltungsschild"
	rf4.description = "Schild und Spiegel in einem.\n+50 Schild, +6% Rüstung, 15% Schadensreflexion, +15% Reflexion unter 35% Leben."
	rf4.rarity = "Epic"
	rf4.pool = "Defensive"
	rf4.color = Color(0.50, 0.60, 1.00)
	rf4.shield_max_add = 50
	rf4.armor_percent_add = 0.06
	rf4.damage_reflect_percent_add = 0.15
	rf4.reflect_low_hp_bonus_add = 0.15
	_register(rf4)

	var rf5 = CardData.new()
	rf5.id = "dornenthron"
	rf5.version = 2 # Max-HP/Schild-Bonus verdoppelt
	rf5.title = "Dornenthron"
	rf5.description = "Jeder Angriff kostet den Angreifer Blut.\n+80 Max HP, +10% Rüstung, 20% Schadensreflexion, 35% des reflektierten Schadens heilen dich, -5% Tempo."
	rf5.rarity = "Legendary"
	rf5.pool = "Defensive"
	rf5.color = Color(0.70, 0.20, 0.30)
	rf5.max_hp_flat = 80
	rf5.armor_percent_add = 0.10
	rf5.damage_reflect_percent_add = 0.20
	rf5.reflect_heal_percent_add = 0.35
	rf5.move_speed_mult = 0.95
	_register(rf5)

	# Bewegung
	var mv1 = CardData.new()
	mv1.id = "federstiefel"
	mv1.version = 2 # Evolution A von feather_shoes
	mv1.title = "Federstiefel"
	mv1.description = "Sprung-Ausbau: Noch ein Sprung in der Luft.\n+1 Luft-Sprung, +10% Sprungkraft."
	mv1.rarity = "Rare"
	mv1.pool = "Bewegung"
	mv1.color = Color(0.45, 1.00, 0.70)
	mv1.family_id = "feather_shoes"
	mv1.parent_card_id = "feather_shoes"
	mv1.evolution_branch = "A"
	mv1.extra_jumps_add = 1
	mv1.jump_force_mult = 1.10
	_register(mv1)

	var mv2 = CardData.new()
	mv2.id = "windschatten"
	mv2.title = "Windschatten"
	mv2.description = "Schneller laufen und schneller dash-en.\n+20% Tempo, -20% Dash-Abklingzeit."
	mv2.rarity = "Rare"
	mv2.pool = "Bewegung"
	mv2.color = Color(0.40, 0.90, 1.00)
	mv2.move_speed_mult = 1.20
	mv2.dash_cooldown_mult = 0.80
	_register(mv2)

	# Munition und Fähigkeit (früher Pool „Kern“)
	var core1 = CardData.new()
	core1.id = "notvorrat"
	core1.version = 2 # Seltenheit Common -> Uncommon (Duplikat-Abgleich)
	core1.title = "Notvorrat"
	core1.description = "Mehr Munition und schnelleres Nachladen.\n+2 Munition, +15% Nachladegeschwindigkeit."
	core1.rarity = "Uncommon"
	core1.pool = "Offensive"
	core1.color = Color(0.85, 0.75, 0.45)
	core1.max_ammo_add = 2
	core1.reload_speed_mult = 1.15
	_register(core1)

	var core2 = CardData.new()
	core2.id = "fokuskristall"
	core2.title = "Fokuskristall"
	core2.description = "Fähigkeit und Feuerrate im Einklang.\n-15% Fähigkeits-Abklingzeit, -6% Feuerrate."
	core2.rarity = "Uncommon"
	core2.pool = "Offensive"
	core2.color = Color(0.65, 0.65, 1.00)
	core2.ability_cooldown_mult = 0.85
	core2.fire_rate_mult = 0.94
	core2.required_mechanic = "ability"
	_register(core2)

	# Allgemeine Fähigkeitskarten: verstärken die Klassenfähigkeit jedes Helden.
	# Größe = Wirkungsradius (nicht Teleport-, Sprung- oder Wurfweite),
	# Schaden = Schaden bzw. Heil-/Schildstärke der Fähigkeit.
	var gab1 = CardData.new()
	gab1.id = "weitstrahler"
	gab1.title = "Weitstrahler"
	gab1.description = "Deine Klassenfähigkeit wirkt auf größerer Fläche.\n+25% Fähigkeitsgröße."
	gab1.rarity = "Common"
	gab1.pool = "Offensive"
	gab1.color = Color(0.55, 0.75, 1.00)
	gab1.ability_radius_mult = 1.25
	gab1.required_mechanic = "ability"
	_register(gab1)

	var gab2 = CardData.new()
	gab2.id = "flaechenbrecher"
	gab2.title = "Flächenbrecher"
	gab2.description = "Fähigkeits-Ausbau: Die Wirkungsfläche wächst weiter.\n+50% Fähigkeitsgröße."
	gab2.rarity = "Common"
	gab2.pool = "Offensive"
	gab2.color = Color(0.45, 0.65, 1.00)
	gab2.family_id = "weitstrahler"
	gab2.parent_card_id = "weitstrahler"
	gab2.evolution_branch = "A"
	gab2.ability_radius_mult = 1.50
	gab2.required_mechanic = "ability"
	_register(gab2)

	var gab3 = CardData.new()
	gab3.id = "kraftladung"
	gab3.title = "Kraftladung"
	gab3.description = "Deine Klassenfähigkeit trifft härter (Bastion: heilt stärker).\n+25% Fähigkeitsschaden."
	gab3.rarity = "Common"
	gab3.pool = "Offensive"
	gab3.color = Color(1.00, 0.60, 0.55)
	gab3.ability_damage_mult = 1.25
	gab3.required_mechanic = "ability"
	_register(gab3)

	var gab4 = CardData.new()
	gab4.id = "ueberladung"
	gab4.title = "Überladung"
	gab4.description = "Fähigkeits-Ausbau: Noch mehr Wucht in der Fähigkeit.\n+50% Fähigkeitsschaden."
	gab4.rarity = "Common"
	gab4.pool = "Offensive"
	gab4.color = Color(1.00, 0.45, 0.40)
	gab4.family_id = "kraftladung"
	gab4.parent_card_id = "kraftladung"
	gab4.evolution_branch = "A"
	gab4.ability_damage_mult = 1.50
	gab4.required_mechanic = "ability"
	_register(gab4)

	# Schaden-/Munitionslinien mit je drei Stufen (Jochen 2026-11-25).
	# Jede Stufe schaltet die nächste frei (Zweig A) und stapelt sich (Schaden multiplikativ,
	# drei Stufen Schlagkraft = x2,2). Stufe 1
	# Common, Stufe 2 Uncommon, Stufe 3 Rare.
	var sm1 = CardData.new()
	sm1.id = "schlagkraft_1"
	sm1.version = 2 # nur noch Fernkampf
	sm1.title = "Schlagkraft I"
	sm1.description = "Deine Schüsse treffen härter.\n+30% Schaden."
	sm1.rarity = "Common"
	sm1.pool = "Offensive"
	sm1.color = Color(1.00, 0.55, 0.45)
	sm1.family_id = "schlagkraft_1"
	sm1.damage_mult = 1.30
	sm1.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(sm1)

	var sm2 = CardData.new()
	sm2.id = "schlagkraft_2"
	sm2.version = 2 # nur noch Fernkampf
	sm2.title = "Schlagkraft II"
	sm2.description = "Schlagkraft-Ausbau: Noch mehr Wucht.\n+30% Schaden."
	sm2.rarity = "Uncommon"
	sm2.pool = "Offensive"
	sm2.color = Color(1.00, 0.42, 0.32)
	sm2.family_id = "schlagkraft_1"
	sm2.parent_card_id = "schlagkraft_1"
	sm2.evolution_branch = "A"
	sm2.damage_mult = 1.30
	sm2.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(sm2)

	var sm3 = CardData.new()
	sm3.id = "schlagkraft_3"
	sm3.version = 2 # nur noch Fernkampf
	sm3.title = "Schlagkraft III"
	sm3.description = "Schlagkraft-Ausbau: Maximale Wucht.\n+30% Schaden."
	sm3.rarity = "Rare"
	sm3.pool = "Offensive"
	sm3.color = Color(1.00, 0.28, 0.20)
	sm3.family_id = "schlagkraft_1"
	sm3.parent_card_id = "schlagkraft_2"
	sm3.evolution_branch = "A"
	sm3.damage_mult = 1.30
	sm3.attack_type = "ranged" # Nahkampf hat eigene Karte (Nahkampf-Pool)
	_register(sm3)

	var sm4 = CardData.new()
	sm4.id = "munitionsgurt_1"
	sm4.title = "Munitionsgurt I"
	sm4.description = "Mehr Schuss pro Magazin.\n+2 Munition."
	sm4.rarity = "Common"
	sm4.pool = "Offensive"
	sm4.color = Color(0.90, 0.80, 0.45)
	sm4.family_id = "munitionsgurt_1"
	sm4.max_ammo_add = 2
	_register(sm4)

	var sm5 = CardData.new()
	sm5.id = "munitionsgurt_2"
	sm5.title = "Munitionsgurt II"
	sm5.description = "Munitionsgurt-Ausbau: Noch mehr Schuss.\n+2 Munition."
	sm5.rarity = "Uncommon"
	sm5.pool = "Offensive"
	sm5.color = Color(0.95, 0.75, 0.30)
	sm5.family_id = "munitionsgurt_1"
	sm5.parent_card_id = "munitionsgurt_1"
	sm5.evolution_branch = "A"
	sm5.max_ammo_add = 2
	_register(sm5)

	var sm6 = CardData.new()
	sm6.id = "munitionsgurt_3"
	sm6.title = "Munitionsgurt III"
	sm6.description = "Munitionsgurt-Ausbau: Volles Arsenal.\n+2 Munition."
	sm6.rarity = "Rare"
	sm6.pool = "Offensive"
	sm6.color = Color(1.00, 0.68, 0.15)
	sm6.family_id = "munitionsgurt_1"
	sm6.parent_card_id = "munitionsgurt_2"
	sm6.evolution_branch = "A"
	sm6.max_ammo_add = 2
	_register(sm6)

	var sm7 = CardData.new()
	sm7.id = "gefechtsbereit_1"
	sm7.title = "Gefechtsbereit I"
	sm7.description = "Etwas mehr Wucht und Munition.\n+15% Schaden, +1 Munition."
	sm7.rarity = "Common"
	sm7.pool = "Offensive"
	sm7.color = Color(0.95, 0.65, 0.80)
	sm7.family_id = "gefechtsbereit_1"
	sm7.damage_mult = 1.15
	sm7.max_ammo_add = 1
	_register(sm7)

	var sm8 = CardData.new()
	sm8.id = "gefechtsbereit_2"
	sm8.title = "Gefechtsbereit II"
	sm8.description = "Gefechtsbereit-Ausbau: Wucht und Munition wachsen weiter.\n+15% Schaden, +1 Munition."
	sm8.rarity = "Uncommon"
	sm8.pool = "Offensive"
	sm8.color = Color(0.90, 0.50, 0.85)
	sm8.family_id = "gefechtsbereit_1"
	sm8.parent_card_id = "gefechtsbereit_1"
	sm8.evolution_branch = "A"
	sm8.damage_mult = 1.15
	sm8.max_ammo_add = 1
	_register(sm8)

	var sm9 = CardData.new()
	sm9.id = "gefechtsbereit_3"
	sm9.title = "Gefechtsbereit III"
	sm9.description = "Gefechtsbereit-Ausbau: Voll ausgerüstet.\n+15% Schaden, +1 Munition."
	sm9.rarity = "Rare"
	sm9.pool = "Offensive"
	sm9.color = Color(0.80, 0.38, 0.95)
	sm9.family_id = "gefechtsbereit_1"
	sm9.parent_card_id = "gefechtsbereit_2"
	sm9.evolution_branch = "A"
	sm9.damage_mult = 1.15
	sm9.max_ammo_add = 1
	_register(sm9)

	# Pickup-Powerups: stärker (Dauer bzw. Heilmenge) und mit Evolution weiter
	# einsammeln. Nicht im Angebot, wenn die Lobby alle Powerups abschaltet.
	var pw1 = CardData.new()
	pw1.id = "powerup_verstaerker"
	pw1.title = "Powerup-Verstärker"
	pw1.description = "Eingesammelte Powerups wirken stärker.\n+25% Powerup-Wirkung (Dauer bzw. Heilung)."
	pw1.rarity = "Common"
	pw1.pool = "Offensive"
	pw1.color = Color(1.00, 0.80, 0.30)
	pw1.powerup_strength_add = 0.25
	_register(pw1)

	var pw2 = CardData.new()
	pw2.id = "powerup_magnet"
	pw2.title = "Powerup-Magnet"
	pw2.description = "Powerup-Ausbau: Powerups fliegen dir zu.\n+25% Powerup-Wirkung (Dauer bzw. Heilung).\n+2 Felder Sammelreichweite für Powerups."
	pw2.rarity = "Common"
	pw2.pool = "Offensive"
	pw2.color = Color(1.00, 0.70, 0.20)
	pw2.family_id = "powerup_verstaerker"
	pw2.parent_card_id = "powerup_verstaerker"
	pw2.evolution_branch = "A"
	pw2.powerup_strength_add = 0.25
	pw2.powerup_pickup_range_add = 2.0
	_register(pw2)

	# Früher Pool "Chaos", jetzt Defensive

	var ch2 = CardData.new()
	ch2.id = "wandelnder_koloss"
	ch2.version = 2 # Max-HP/Schild-Bonus verdoppelt
	ch2.title = "Wandelnder Koloss"
	ch2.description = "Groß, schwer und schwer zu übersehen.\n+35% Größe, +80 Max HP, -10% Tempo."
	ch2.rarity = "Epic"
	ch2.pool = "Defensive"
	ch2.color = Color(0.80, 0.55, 0.25)
	ch2.giant_growth = 0.35
	ch2.max_hp_flat = 80
	ch2.move_speed_mult = 0.90
	_register(ch2)

	# ============================================================
	# Nahkampf-Karten (universell, verbessern die E-Waffe)
	# ============================================================

	# --- Common ---
	var nk1 = CardData.new()
	nk1.id = "nk_schleifstein"
	nk1.title = "Schleifstein"
	nk1.description = "Scharf geschliffen.\n+25% Nahkampfschaden."
	nk1.rarity = "Common"
	nk1.pool = "Nahkampf"
	nk1.color = Color(1.00, 0.62, 0.30)
	nk1.melee_damage_mult = 1.25
	_register(nk1)
	var nk2 = CardData.new()
	nk2.id = "nk_langer_griff"
	nk2.title = "Langer Griff"
	nk2.description = "Mehr Abstand zum Gegner.\n+0,5 Felder Nahkampf-Reichweite."
	nk2.rarity = "Common"
	nk2.pool = "Nahkampf"
	nk2.color = Color(0.95, 0.75, 0.40)
	nk2.melee_range_add = 0.5
	_register(nk2)
	var nk3 = CardData.new()
	nk3.id = "nk_leichter_griff"
	nk3.title = "Leichter Griff"
	nk3.description = "Schneller wieder ausgeholt.\n-15% Nahkampf-Abklingzeit."
	nk3.rarity = "Common"
	nk3.pool = "Nahkampf"
	nk3.color = Color(1.00, 0.82, 0.45)
	nk3.melee_cooldown_mult = 0.85
	_register(nk3)
	var nk4 = CardData.new()
	nk4.id = "nk_schwerer_kopf"
	nk4.title = "Schwerer Kopf"
	nk4.description = "Mehr Wucht im Schlag.\n+40% Nahkampf-Rückstoß."
	nk4.rarity = "Common"
	nk4.pool = "Nahkampf"
	nk4.color = Color(0.85, 0.60, 0.40)
	nk4.melee_knockback_mult = 1.4
	_register(nk4)

	# --- Uncommon ---
	var nk5 = CardData.new()
	nk5.id = "nk_frostklinge"
	nk5.title = "Frostklinge"
	nk5.description = "Eiskalte Schneide.\nNahkampftreffer verlangsamen 1,2s."
	nk5.rarity = "Uncommon"
	nk5.pool = "Nahkampf"
	nk5.color = Color(0.55, 0.85, 1.00)
	nk5.melee_freeze_add = 1.2
	_register(nk5)
	var nk6 = CardData.new()
	nk6.id = "nk_giftzahn"
	nk6.title = "Giftzahn"
	nk6.description = "Vergiftete Spitze.\n+3 Giftstapel pro Nahkampftreffer."
	nk6.rarity = "Uncommon"
	nk6.pool = "Nahkampf"
	nk6.color = Color(0.45, 0.95, 0.40)
	nk6.melee_poison_stacks_add = 3
	_register(nk6)
	var nk7 = CardData.new()
	nk7.id = "nk_gluehende_spitze"
	nk7.title = "Glühende Spitze"
	nk7.description = "Heiß wie der Lötkolben.\nNahkampftreffer entzünden (3 Brandstapel)."
	nk7.rarity = "Uncommon"
	nk7.pool = "Nahkampf"
	nk7.color = Color(1.00, 0.45, 0.20)
	nk7.melee_burn_stacks_add = 3
	_register(nk7)
	var nk8 = CardData.new()
	nk8.id = "nk_weiter_schwung"
	nk8.title = "Weiter Schwung"
	nk8.description = "Ausholen mit ganzem Körper.\n+30° Schlagbogen (Stich: breiterer Stoß), +0,25 Felder Reichweite."
	nk8.rarity = "Uncommon"
	nk8.pool = "Nahkampf"
	nk8.color = Color(1.00, 0.70, 0.50)
	nk8.melee_arc_add = 30.0
	nk8.melee_range_add = 0.25
	_register(nk8)
	var nk9 = CardData.new()
	nk9.id = "nk_gnadenstoss"
	nk9.title = "Gnadenstoß"
	nk9.description = "Wer wankt, fällt.\n+60% Nahkampfschaden gegen Gegner unter 35% Leben."
	nk9.rarity = "Uncommon"
	nk9.pool = "Nahkampf"
	nk9.color = Color(0.95, 0.35, 0.35)
	nk9.melee_execute_bonus_add = 0.6
	_register(nk9)

	# --- Rare ---
	var nk10 = CardData.new()
	nk10.id = "nk_elektroschocker"
	nk10.title = "Elektroschocker"
	nk10.description = "Strom auf der Klinge.\nNahkampftreffer betäuben 0,35s."
	nk10.rarity = "Rare"
	nk10.pool = "Nahkampf"
	nk10.color = Color(1.00, 0.95, 0.35)
	nk10.melee_stun_add = 0.35
	_register(nk10)
	var nk11 = CardData.new()
	nk11.id = "nk_wandklatscher"
	nk11.title = "Wandklatscher"
	nk11.description = "Ab gegen die Wand.\nWer nach einem Nahkampftreffer gegen Wand oder Decke prallt, ist 0,6s betäubt.\n+20% Nahkampf-Rückstoß."
	nk11.rarity = "Rare"
	nk11.pool = "Nahkampf"
	nk11.color = Color(0.80, 0.65, 1.00)
	nk11.melee_wall_stun_add = 0.6
	nk11.melee_knockback_mult = 1.2
	_register(nk11)
	var nk12 = CardData.new()
	nk12.id = "nk_blutklinge"
	nk12.title = "Blutklinge"
	nk12.description = "Jeder Hieb nährt.\n25% des Nahkampfschadens heilt dich."
	nk12.rarity = "Rare"
	nk12.pool = "Nahkampf"
	nk12.color = Color(0.95, 0.25, 0.40)
	nk12.melee_lifesteal_add = 0.25
	_register(nk12)
	var nk13 = CardData.new()
	nk13.id = "nk_meisterschliff"
	nk13.title = "Meisterschliff"
	nk13.description = "Schwerer, schärfer, länger.\n+40% Nahkampfschaden, +0,5 Felder Reichweite, +10% Nahkampf-Abklingzeit."
	nk13.rarity = "Rare"
	nk13.pool = "Nahkampf"
	nk13.color = Color(1.00, 0.55, 0.25)
	nk13.melee_damage_mult = 1.4
	nk13.melee_range_add = 0.5
	nk13.melee_cooldown_mult = 1.1
	_register(nk13)

	# --- Epic ---
	var nk14 = CardData.new()
	nk14.id = "nk_hochspannung"
	nk14.title = "Hochspannung"
	nk14.description = "Der Funke springt über.\nNahkampftreffer springen als Blitz auf einen weiteren Gegner (50% Schaden, betäubt).\n+0,15s Nahkampf-Betäubung."
	nk14.rarity = "Epic"
	nk14.pool = "Nahkampf"
	nk14.color = Color(1.00, 0.90, 0.20)
	nk14.melee_chain_lightning = true
	nk14.melee_stun_add = 0.15
	_register(nk14)
	var nk15 = CardData.new()
	nk15.id = "nk_nachschlag"
	nk15.title = "Nachschlag"
	nk15.description = "Doppelt hält besser.\nNach jedem Nahkampfschlag folgt ein zweiter mit 60% Schaden."
	nk15.rarity = "Epic"
	nk15.pool = "Nahkampf"
	nk15.color = Color(1.00, 0.65, 0.35)
	nk15.melee_echo = true
	_register(nk15)
	var nk16 = CardData.new()
	nk16.id = "nk_parade"
	nk16.title = "Parade"
	nk16.description = "Zurück zum Absender.\nIst dein Nahkampfschlag bereit, schlägt er von selbst nach anfliegenden gegnerischen Projektilen und wirft sie zurück."
	nk16.rarity = "Legendary"
	nk16.version = 2 # Auto-Parade, -10% Abklingzeit entfernt, Legendär
	nk16.pool = "Nahkampf"
	nk16.color = Color(0.55, 0.80, 1.00)
	nk16.melee_parry = true
	_register(nk16)
	var nk17 = CardData.new()
	nk17.id = "nk_eiskern"
	nk17.title = "Eiskern"
	nk17.description = "Klirrende Kälte.\nNahkampftreffer verlangsamen 2s.\n+20% Nahkampfschaden."
	nk17.rarity = "Epic"
	nk17.pool = "Nahkampf"
	nk17.color = Color(0.45, 0.80, 1.00)
	nk17.melee_freeze_add = 2.0
	nk17.melee_damage_mult = 1.2
	_register(nk17)

	# --- Legendary ---
	var nk18 = CardData.new()
	nk18.id = "nk_werkbankmeister"
	nk18.title = "Meister der Werkbank"
	nk18.description = "Das beste Werkzeug der Werkstatt.\n+50% Nahkampfschaden, +1 Feld Reichweite, -25% Nahkampf-Abklingzeit, +30% Nahkampf-Rückstoß."
	nk18.rarity = "Legendary"
	nk18.pool = "Nahkampf"
	nk18.color = Color(1.00, 0.72, 0.15)
	nk18.melee_damage_mult = 1.5
	nk18.melee_range_add = 1.0
	nk18.melee_cooldown_mult = 0.75
	nk18.melee_knockback_mult = 1.3
	_register(nk18)
	var nk19 = CardData.new()
	nk19.id = "nk_gewitterschlag"
	nk19.title = "Gewitterschlag"
	nk19.description = "Donner in jedem Hieb.\nNahkampftreffer betäuben 0,4s und springen als Blitz über.\nJeder Schlag folgt ein zweiter mit 60% Schaden."
	nk19.rarity = "Legendary"
	nk19.pool = "Nahkampf"
	nk19.color = Color(1.00, 0.95, 0.45)
	nk19.melee_stun_add = 0.4
	nk19.melee_chain_lightning = true
	nk19.melee_echo = true
	_register(nk19)

	_register_frost_cards()
	_register_flocke_cards()
	_register_element_cards()

	# Ausbaukarten, die vor ihrer Grundkarte registriert wurden, übernehmen
	# hier nachträglich deren Pool.
	for card in all_cards:
		if not card.parent_card_id.is_empty() and cards_by_id.has(card.parent_card_id):
			card.pool = cards_by_id[card.parent_card_id].pool

# --- Frost-Karten (Element-System 2026-11-25) ---
# Frost hatte am wenigsten Karten. Alle verlangen das Element Frost.
# --- Flocke: Kältehauch, Gletscherlanze, Schlitterschritt, Blizzard ---
func _register_flocke_cards() -> void:
	var ice := Color(0.55, 0.86, 1.0)
	var f1 = CardData.new()
	f1.id = "flocke_frostatem"
	f1.title = "Frostatem"
	f1.description = "Flocke: Kältehauch verlangsamt 0,4 s länger, +10% Schussschaden."
	f1.rarity = "Common"
	f1.pool = "Offensive"
	f1.color = ice
	f1.hero_id = "flocke"
	f1.freeze_duration_add = 0.4
	f1.damage_mult = 1.1
	_register(f1)

	var f2 = CardData.new()
	f2.id = "flocke_eiszapfenhagel"
	f2.title = "Eiszapfenhagel"
	f2.description = "Flocke – Kältehauch: Schon jeder %d. Schuss ist ein durchschlagender Eissplitter, +1 Munition." % Player.FLOCKEEVO_FAST_SHARD_INTERVAL
	f2.rarity = "Epic"
	f2.pool = "Offensive"
	f2.color = ice
	f2.hero_id = "flocke"
	f2.ability_evolution = "flocke_passive_fast"
	f2.max_ammo_add = 1
	_register(f2)

	var f3 = CardData.new()
	f3.id = "flocke_lange_lanze"
	f3.title = "Lange Lanze"
	f3.description = "Flocke – Gletscherlanze: +30% Reichweite, +20% Schaden, -10% Fähigkeits-Abklingzeit."
	f3.rarity = "Rare"
	f3.pool = "Offensive"
	f3.color = ice
	f3.hero_id = "flocke"
	f3.family_id = "flocke_lance"
	f3.ability_range_mult = 1.3
	f3.ability_damage_mult = 1.2
	f3.ability_cooldown_mult = 0.9
	_register(f3)

	var f3a = CardData.new()
	f3a.id = "flocke_lanzenfaecher"
	f3a.title = "Lanzenfächer"
	f3a.description = "Gletscherlanze-Evolution: %d Lanzen im Fächer, jede mit %d%% Schaden." % [Player.FLOCKEEVO_FAN_COUNT, int(round(Player.FLOCKEEVO_FAN_DAMAGE_SHARE * 100.0))]
	f3a.rarity = "Epic"
	f3a.color = ice
	f3a.hero_id = "flocke"
	f3a.family_id = "flocke_lance"
	f3a.parent_card_id = "flocke_lange_lanze"
	f3a.evolution_branch = "A"
	f3a.ability_evolution = "flocke_lance_fan"
	_register(f3a)

	var f3b = CardData.new()
	f3b.id = "flocke_frostbahn"
	f3b.title = "Frostbahn"
	f3b.description = "Gletscherlanze-Evolution: Entlang der Lanze bleibt 3 s lang eine Eisbahn liegen."
	f3b.rarity = "Epic"
	f3b.color = ice
	f3b.hero_id = "flocke"
	f3b.family_id = "flocke_lance"
	f3b.parent_card_id = "flocke_lange_lanze"
	f3b.evolution_branch = "B"
	f3b.ability_evolution = "flocke_lance_trail"
	_register(f3b)

	var f4 = CardData.new()
	f4.id = "flocke_glatteis"
	f4.title = "Glatteis"
	f4.description = "Flocke – Schlitterschritt: breitere, länger haltende Eisbahn, -15% Dash-Abklingzeit."
	f4.rarity = "Uncommon"
	f4.pool = "Bewegung"
	f4.color = ice
	f4.hero_id = "flocke"
	f4.dash_effect_mult = 1.4
	f4.dash_cooldown_mult = 0.85
	_register(f4)

	var f5 = CardData.new()
	f5.id = "flocke_ewiger_winter"
	f5.title = "Ewiger Winter"
	f5.description = "Flocke – Blizzard: +30% Dauer, +20% Radius, -10% Ulti-Abklingzeit."
	f5.rarity = "Rare"
	f5.pool = "Offensive"
	f5.color = ice
	f5.hero_id = "flocke"
	f5.ult_duration_mult = 1.3
	f5.ult_radius_mult = 1.2
	f5.ult_cooldown_mult = 0.9
	_register(f5)

func _register_frost_cards() -> void:
	var f1 = CardData.new()
	f1.id = "frost_eissplitter"
	f1.title = "Eissplitter"
	f1.description = "Kälte macht spröde.\n+15% Schaden gegen verlangsamte Gegner."
	f1.rarity = "Rare"
	f1.color = Color(0.55, 0.88, 1.0)
	f1.pool = "Offensive"
	f1.required_element = ElementSystem.FROST
	f1.chill_damage_bonus_add = 0.15
	_register(f1)

	var f2 = CardData.new()
	f2.id = "frost_tiefkuehlung"
	f2.title = "Tiefkühlung"
	f2.description = "Eisiger Griff.\nVerlangsamung stärker: Getroffene laufen mit 50% statt 60% Tempo."
	f2.rarity = "Uncommon"
	f2.color = Color(0.40, 0.78, 1.0)
	f2.pool = "Offensive"
	f2.required_element = ElementSystem.FROST
	f2.chill_strength_add = 0.10
	_register(f2)

	var f3 = CardData.new()
	f3.id = "frostschuss_splitternova"
	f3.title = "Splitternova"
	f3.description = "Eisnova-Ausbau: Die Eisnova zerspringt in Eissplitter.\n8 Schaden an jedem Gegner in der Nova."
	f3.rarity = "Epic"
	f3.color = Color(0.70, 0.95, 1.0)
	f3.family_id = "frostschuss"
	f3.parent_card_id = "frostschuss_nova"
	f3.evolution_branch = "A"
	f3.frost_nova_shards = true
	_register(f3)

	var f4 = CardData.new()
	f4.id = "frostschuss_gletscherhaut"
	f4.title = "Gletscherhaut"
	f4.description = "Eisbahn-Ausbau: Auf deiner eigenen Eisbahn gleitest du.\n+20% Tempo und 2 HP pro Sekunde, solange du darauf stehst."
	f4.rarity = "Rare"
	f4.color = Color(0.60, 0.90, 1.0)
	f4.family_id = "frostschuss"
	f4.parent_card_id = "frostschuss_spur"
	f4.evolution_branch = "B"
	f4.frost_trail_haste = true
	f4.attack_type = "ranged"
	_register(f4)

	var f5 = CardData.new()
	f5.id = "frost_kaeltepanzer"
	f5.title = "Kältepanzer"
	f5.description = "Wer zuschlägt, friert.\n+8% Rüstung. Wer dich im Nahkampf trifft, wird 1s verlangsamt."
	f5.rarity = "Uncommon"
	f5.color = Color(0.50, 0.80, 0.95)
	f5.pool = "Defensive"
	f5.required_element = ElementSystem.FROST
	f5.armor_percent_add = 0.08
	f5.chill_on_melee_hit_add = 1.0
	_register(f5)

# --- Element-Karten ---
# "Element" liegt zusätzlich im Angebot, solange ein Slot frei ist, und öffnet
# den Unter-Draft. Dort stehen je Element eine Karte: "element_<id>" für das
# erste Mal oder "element_<id>_rein" für die reine Form. Beschreibung der
# Kombination steht unten auf der Karte (CardDraftUI._element_footer).
func _register_element_cards() -> void:
	var pick = CardData.new()
	pick.id = ElementSystem.PICK_CARD_ID
	pick.title = "Element"
	pick.description = "Wähle ein Element für deinen Build: Feuer, Gift, Frost oder Blitz.\nZwei Elemente ergeben eine Kombination, zweimal dasselbe die reine Form.\nHöchstens 2 Element-Slots."
	pick.rarity = "Rare"
	pick.color = Color(0.95, 0.85, 0.55)
	pick.pool = "Offensive"
	pick.sub_tags = _element_tags()
	pick.element_pick = true
	_register(pick)

	var core_texts := {
		ElementSystem.FIRE: "Bringt Feuersturm mit: Treffer entzünden, am Einschlag brennt der Boden.",
		ElementSystem.POISON: "Bringt Giftschuss mit: Treffer vergiften.",
		ElementSystem.FROST: "Bringt Frostschuss mit: Treffer verlangsamen.",
		ElementSystem.LIGHTNING: "Bringt Blitzschuss mit: Treffer betäuben kurz.",
	}
	for el in ElementSystem.ELEMENTS:
		var first = CardData.new()
		first.id = ElementSystem.card_id_for(el, false)
		first.title = ElementSystem.element_name(el)
		first.description = "Element %s.\n%s\nSchaltet die Ausbauten des Elements frei." % [ElementSystem.element_name(el), core_texts[el]]
		first.rarity = "Rare"
		first.color = ElementSystem.element_color(el)
		first.pool = "Offensive"
		first.sub_tags = _element_tags()
		first.element = el
		_register(first)

		var pure = CardData.new()
		pure.id = ElementSystem.card_id_for(el, true)
		var combo := ElementSystem.combo_for(el, el)
		pure.title = "%s (rein)" % ElementSystem.element_name(el)
		pure.description = "Reine Form: %s.\n%s" % [ElementSystem.COMBO_NAMES[combo], ElementSystem.COMBO_DESCRIPTIONS[combo]]
		pure.rarity = "Epic"
		pure.color = ElementSystem.element_color(el).lightened(0.2)
		pure.pool = "Offensive"
		pure.sub_tags = _element_tags()
		pure.element = el
		pure.element_pure = true
		_register(pure)

	# Grundkarten der Elemente kommen nur noch über die Elementkarte.
	for table in [ElementSystem.CORE_RANGED, ElementSystem.CORE_MELEE]:
		for el in table:
			var core: CardData = cards_by_id.get(table[el], null)
			if core != null:
				core.element_core = true
	# Kleine Element-Boni ohne Talentbaum verlangen das Element.
	for card in all_cards:
		if card.required_element.is_empty():
			card.required_element = _infer_required_element(card)

func _element_tags() -> Array[String]:
	var tags: Array[String] = ["Element"]
	return tags

func is_element_card(card: CardData) -> bool:
	return card != null and (card.element_pick or not card.element.is_empty())

# Welches Element braucht diese Karte? Klassenkarten, Elementkarten, die
# Grundkarten selbst und Ausbauten (hängen an ihrer Grundkarte) brauchen keins.
func _infer_required_element(card: CardData) -> String:
	if not card.hero_id.is_empty() or is_element_card(card) or card.element_core:
		return ""
	if not card.parent_card_id.is_empty():
		return ""
	if card.poison_stacks_add > 0 or card.poison_damage_mult > 1.0 or card.poison_impact_cloud \
			or card.poison_trail or card.melee_poison_stacks_add > 0:
		return ElementSystem.POISON
	if card.fire_shot or card.fire_impact_zone or card.fire_trail or card.fire_damage_mult > 1.0 \
			or card.melee_burn_stacks_add > 0:
		return ElementSystem.FIRE
	if card.freeze_duration_add > 0.0 or card.frost_nova or card.frost_trail or card.melee_freeze_add > 0.0:
		return ElementSystem.FROST
	if card.lightning_shot or card.chain_lightning or card.lightning_zone or card.melee_chain_lightning \
			or card.melee_stun_add > 0.0:
		return ElementSystem.LIGHTNING
	return ""

# Elemente eines Spielers aus Held und Kartenliste.
func get_player_elements(hero_id: String, owned_ids: Array) -> Array[String]:
	return ElementSystem.elements_for(hero_id, owned_ids)

# Unter-Draft: je Element eine Karte, die reine Form für schon vorhandene Elemente.
func get_element_offer(hero_id: String, owned_ids: Array) -> Array[CardData]:
	var have := ElementSystem.elements_for(hero_id, owned_ids)
	var result: Array[CardData] = []
	for el in ElementSystem.ELEMENTS:
		var pure := have.has(el)
		var card: CardData = cards_by_id.get(ElementSystem.card_id_for(el, pure), null)
		if card != null and not owned_ids.has(card.id):
			result.append(card)
	return result

func _register(card: CardData) -> void:
	if card.pool.is_empty():
		card.pool = _infer_pool(card)
	if card.required_mechanic.is_empty():
		card.required_mechanic = _infer_required_mechanic(card)
	if card.sub_tags.is_empty():
		card.sub_tags = _infer_sub_tags(card)
	if card.attack_type.is_empty():
		card.attack_type = _infer_attack_type(card)
	# Ausbaukarten bleiben im selben Pool wie ihre Grundkarte.
	if not card.parent_card_id.is_empty():
		var parent: CardData = cards_by_id.get(card.parent_card_id, null)
		if parent != null:
			card.pool = parent.pool
	all_cards.append(card)
	cards_by_id[card.id] = card

# Karten, die nur eine vorhandene Mechanik verstärken, dürfen nicht auftauchen,
# wenn der Spieler diese Mechanik gar nicht besitzt. Karten, die die Mechanik
# selbst verleihen (z. B. Giftkapsel oder Frostschuss), bleiben ohne Bedingung.
func _infer_required_mechanic(card: CardData) -> String:
	if card.dash_cooldown_mult < 1.0:
		return "dash"
	if card.ability_cooldown_mult < 1.0:
		return "ability"
	if card.ult_cooldown_mult < 1.0 or card.ult_duration_mult > 1.0 or card.ult_damage_mult > 1.0 \
			or card.ult_radius_mult > 1.0 or card.ult_count_add > 0:
		return "ult"
	if (card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0) and card.shield_max_add <= 0:
		return "shield"
	if card.poison_damage_mult > 1.0 and card.poison_stacks_add <= 0 \
			and not card.poison_impact_cloud and not card.poison_trail:
		return "poison"
	if card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0:
		return "tower"
	return ""

# Für welche Angriffsart taugt die Karte? Nahkampfwerte nützen nur
# Nahkämpfern. Werte, die nur an Kugeln hängen (Munition, Nachladen,
# Abpraller, Zielsuche, Explosion, Mehrfachschuss, Durchschlag, Flugbahn),
# nützen nur Fernkämpfern. Schaden, Feuerrate, Rückstoß, Lebensraub und die
# Elementkarten wirken bei Nahkämpfern auf die Schläge (Player.apply_stats)
# und bleiben deshalb für beide. Ausnahme: Schuss-Karten mit eigenem
# Nahkampf-Gegenstück (Giftschuss, Frostschuss, Schnellfeuer, Blutdurst ...)
# setzen attack_type = "ranged" ausdrücklich. Klassenkarten folgen ihrem Helden.
func _infer_attack_type(card: CardData) -> String:
	if not card.hero_id.is_empty():
		return ""
	if card.pool == "Nahkampf" or has_melee_values(card):
		return "melee"
	if has_projectile_only_values(card):
		return "ranged"
	return ""

func has_melee_values(card: CardData) -> bool:
	return card.melee_damage_mult != 1.0 or card.melee_range_add != 0.0 or card.melee_cooldown_mult != 1.0 \
		or card.melee_knockback_mult != 1.0 or card.melee_arc_add != 0.0 or card.melee_freeze_add != 0.0 \
		or card.melee_poison_stacks_add != 0 or card.melee_stun_add != 0.0 or card.melee_burn_stacks_add != 0 \
		or card.melee_lifesteal_add != 0.0 or card.melee_wall_stun_add != 0.0 \
		or card.melee_execute_bonus_add != 0.0 or card.melee_chain_lightning or card.melee_echo or card.melee_parry

func has_projectile_only_values(card: CardData) -> bool:
	return card.bullet_speed_mult != 1.0 or card.bullet_size_mult != 1.0 or card.projectile_gravity_mult != 1.0 \
		or card.max_ammo_add != 0 or card.reload_speed_mult != 1.0 or card.bounces_add != 0 \
		or card.homing_strength_add != 0.0 or card.explosion_radius_add != 0.0 or card.multishot_add != 0 \
		or card.spread_angle_deg != 0.0 or card.piercing_add != 0 or card.border_bounce or card.bounce_split \
		or card.self_damage_reduction_add != 0.0 or card.cluster_bomblets or card.poison_impact_cloud \
		or card.frost_nova or card.lightning_zone or card.fire_impact_zone or card.id == "ricochet_frenzy"

# Passt die Karte zur Angriffsart des Helden?
func is_card_attack_type_allowed(card: CardData, hero_id: String) -> bool:
	if card == null or card.attack_type.is_empty() or hero_id.is_empty():
		return true
	var wanted := "melee" if Global.is_melee_hero(hero_id) else "ranged"
	return card.attack_type == wanted

# Helden, deren Grundfähigkeit keinen Schaden macht: Allgemeine
# Fähigkeitsschaden-Karten erscheinen erst mit dieser Evolutionskarte im Deck.
const ABILITY_DAMAGE_UNLOCK_CARDS: Dictionary = {"phantom": "phantom_sprengkoeder"}

func is_ability_damage_locked(card: CardData, hero_id: String, owned_ids: Array = []) -> bool:
	if card == null or not card.hero_id.is_empty() or card.ability_damage_mult <= 1.0:
		return false
	if not ABILITY_DAMAGE_UNLOCK_CARDS.has(hero_id):
		return false
	return not owned_ids.has(ABILITY_DAMAGE_UNLOCK_CARDS[hero_id])

func is_card_available_for_player(card: CardData, hero_id: String, owned_ids: Array = []) -> bool:
	if card == null:
		return false
	# Element-System: "Element" und die Elementkarten hängen nur an freien Slots.
	if card.element_pick:
		return ElementSystem.free_slots(hero_id, owned_ids) > 0
	if not card.element.is_empty():
		if ElementSystem.free_slots(hero_id, owned_ids) <= 0:
			return false
		return card.element_pure == ElementSystem.elements_for(hero_id, owned_ids).has(card.element)
	if not card.required_element.is_empty() \
			and not ElementSystem.elements_for(hero_id, owned_ids).has(card.required_element):
		return false
	if is_ability_damage_locked(card, hero_id, owned_ids):
		return false
	if not is_card_pool_enabled(card):
		return false
	if not is_card_attack_type_allowed(card, hero_id):
		return false
	if is_powerup_card_locked(card):
		return false
	if not card.hero_id.is_empty() and card.hero_id != hero_id:
		return false
	# Horden-Modus: Märtyrium nur, wenn man zurückkommen kann (Teamkollegen
	# beleben wieder). Allein endet die Jagd mit dem Tod, die Explosion nützt nichts.
	if card.kamikaze and Global.is_horde_mode() and Global.get_active_player_indices().size() < 2:
		return false
	if not card.parent_card_id.is_empty() and not owned_ids.has(card.parent_card_id):
		return false
	if not card.evolution_branch.is_empty():
		var locked_branch := get_locked_evolution_branch(get_card_family_id(card), owned_ids)
		if not locked_branch.is_empty() and locked_branch != card.evolution_branch:
			return false
	if not card.required_mechanic.is_empty() \
			and not _player_has_mechanic(card.required_mechanic, hero_id, owned_ids):
		return false
	return true

# Familienname eines Talentbaums. Ältere Karten ohne family_id werden über ihre
# Grundkarte gruppiert.
func get_card_family_id(card: CardData) -> String:
	if card == null:
		return ""
	if not card.family_id.is_empty():
		return card.family_id
	return card.parent_card_id

# Sobald ein Spieler eine Zweigoption gewählt hat, ist diese Familie auf diesen
# Zweig festgelegt. Die Sperre wird aus dem Deck abgeleitet und gilt damit
# gleichermaßen für lokale Drafts, Bots, Host und Client.
func get_locked_evolution_branch(family_id: String, owned_ids: Array = []) -> String:
	if family_id.is_empty():
		return ""
	for raw_id in owned_ids:
		var owned := get_card(str(raw_id))
		if owned == null:
			continue
		if get_card_family_id(owned) != family_id:
			continue
		if not owned.evolution_branch.is_empty():
			return owned.evolution_branch
	return ""

const SHIELD_UPGRADE_MIN: int = 25

func _player_shield_total(hero_id: String, owned_ids: Array) -> int:
	var total := 0
	var hero: HeroData = Global.heroes.get(hero_id, null)
	if hero != null:
		total += hero.base_shield
	for raw_id in owned_ids:
		var owned := get_card(str(raw_id))
		if owned != null:
			total += owned.shield_max_add
	return total

# Mechaniken, die jeder Held von Anfang an hat. Karten mit dieser Bedingung
# sind immer verfügbar, die Bedingung wird deshalb auch nicht angezeigt.
const ALWAYS_AVAILABLE_MECHANICS: Array[String] = ["dash", "ability", "block", "jump"]

# Hat der Held schon eine Ulti (Taste E)? Karten für die Ulti erscheinen nur dann.
func _hero_has_ult(hero_id: String) -> bool:
	var hero: HeroData = Global.heroes.get(hero_id, null)
	return hero != null and hero.has_ult()

# Held, der eine Mechanik schon mitbringt (ohne passende Karte).
const HERO_MECHANICS := {"poison": "spore"}

func _player_has_mechanic(mechanic: String, hero_id: String, owned_ids: Array) -> bool:
	if ALWAYS_AVAILABLE_MECHANICS.has(mechanic):
		return true
	if mechanic == "ult":
		return _hero_has_ult(hero_id)
	if mechanic == "shield":
		# Schild-Verbesserungen erst ab SHIELD_UPGRADE_MIN Gesamtschild
		# (Held + Karten), damit sie nicht für Mini-Schilde auftauchen.
		return _player_shield_total(hero_id, owned_ids) >= SHIELD_UPGRADE_MIN
	if HERO_MECHANICS.has(mechanic) and HERO_MECHANICS[mechanic] == hero_id:
		return true
	for raw_id in owned_ids:
		if card_grants_mechanic(get_card(str(raw_id)), mechanic):
			return true
	return false

# Verleiht diese Karte die Mechanik (und schaltet damit Karten mit
# required_mechanic frei)? Schild zählt über den Gesamtwert, nicht pro Karte.
func card_grants_mechanic(owned: CardData, mechanic: String) -> bool:
	if owned == null:
		return false
	match mechanic:
		"poison":
			return owned.poison_stacks_add > 0 or owned.poison_impact_cloud or owned.poison_trail
		"frost":
			return owned.freeze_duration_add > 0.0 or owned.frost_nova or owned.frost_trail
		"fire":
			return owned.fire_shot or owned.fire_impact_zone or owned.fire_trail
		"lightning":
			return owned.lightning_shot or owned.chain_lightning or owned.lightning_zone
		"tower":
			return owned.tower_enabled or owned.tower_auto_spawn or owned.tower_follow
		"bounce":
			return owned.bounces_add > 0
		"drone":
			return owned.drone_count_add > 0 or owned.drone_guardian \
					or owned.blocker_drone_count_add > 0 or owned.blocker_drone_heal
		"shield":
			return owned.shield_max_add > 0
		"mine":
			return owned.block_mine
	return false

# Alle Karten, die eine Mechanik verleihen (für die Anzeige der Bedingungen).
func get_mechanic_providers(mechanic: String) -> Array[CardData]:
	var result: Array[CardData] = []
	for card in all_cards:
		if card.required_mechanic != mechanic and card_grants_mechanic(card, mechanic):
			result.append(card)
	return result

# Karten, die nur Pickup-Powerups verstärken.
func is_powerup_card(card: CardData) -> bool:
	return card != null and (card.powerup_strength_add > 0.0 or card.powerup_pickup_range_add > 0.0)

# Sind in der Lobby alle Powerups aus (oder nur Auto-Angriff ohne Nahkampf),
# wären Powerup-Karten nutzlos und werden nicht angeboten.
func is_powerup_card_locked(card: CardData) -> bool:
	return is_powerup_card(card) and not Global.has_active_powerups()

func is_card_pool_enabled(card: CardData) -> bool:
	# Ist Nahkampf in den Lobby-Regeln aus, gibt es auch keine Nahkampf-Karten.
	if card != null and card.pool == "Nahkampf" and not Global.melee_enabled:
		return false
	if card == null:
		return false
	# Der Host kann einzelne Karten eines abgeschalteten Pools wieder freigeben.
	return Global.enabled_card_pools.has(card.pool) or Global.is_card_pool_unlocked(card)

# Ordnet Karten automatisch einem klaren Draft-Pool zu. Explizit gesetzte
# Pools (z. B. bei neuen Karten) haben Vorrang und werden hier nicht überschrieben.
func _infer_pool(card: CardData) -> String:
	# Kamikaze und Riesenwuchs (früher Pool "Chaos") zählen zur Defensive.
	if card.kamikaze or card.giant_growth > 0.0:
		return "Defensive"
	if card.max_hp_mult > 1.0 or card.max_hp_flat > 0 or card.hp_regen_add > 0.0 \
		or card.hp_regen_always_add > 0.0 \
		or card.shield_max_add > 0 or card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0 \
		or card.block_duration_add > 0.0 or card.block_cooldown_mult < 1.0 or card.block_hits_add > 0 \
		or card.block_reflect_damage_add > 0.0 or card.block_knockback_radius_add > 0.0 \
		or card.block_knockback_force_add > 0.0 or card.block_bomb or card.block_heal_zone \
		or card.block_mine or card.mine_damage_add > 0.0 or card.mine_radius_add > 0.0 or card.mine_instant \
		or card.lifesteal_percent_add > 0.0 or card.blocker_drone_count_add > 0 \
		or card.blocker_drone_heal or card.tower_max_health_add > 0 \
		or card.armor_percent_add > 0.0 or card.damage_reflect_percent_add > 0.0:
		return "Defensive"
	if card.move_speed_mult > 1.0 or card.jump_force_mult > 1.0 or card.extra_jumps_add > 0 \
		or card.dash_cooldown_mult < 1.0 or card.body_size_mult < 1.0 or card.gravity_mult < 1.0:
		return "Bewegung"
	if card.damage_mult > 1.0 or card.bullet_speed_mult != 1.0 or card.bullet_size_mult != 1.0 \
		or card.projectile_gravity_mult != 1.0 or card.knockback_mult > 1.0 \
		or card.fire_rate_mult < 1.0 or card.max_ammo_add > 0 or card.reload_speed_mult > 1.0 \
		or card.bounces_add > 0 or card.homing_strength_add > 0.0 or card.explosion_radius_add > 0.0 \
		or card.poison_stacks_add > 0 or card.poison_damage_mult > 1.0 or card.freeze_duration_add > 0.0 \
		or card.multishot_add > 0 or card.spread_angle_deg != 0.0 or card.piercing_add > 0 \
		or card.poison_impact_cloud or card.poison_trail or card.lightning_shot or card.chain_lightning \
		or card.lightning_zone or card.frost_nova or card.frost_trail or card.cluster_bomblets \
		or card.fire_shot or card.fire_impact_zone or card.fire_trail or card.tower_enabled \
		or card.tower_auto_spawn or card.tower_follow or card.tower_fire_rate_mult < 1.0 \
		or card.drone_count_add > 0 or card.drone_guardian:
		return "Offensive"
	# Reine Utility-Karten ohne klaren Schwerpunkt zählen zur Offensive.
	return "Offensive"

# Leitet die Sub-Tags aus den Kartenwerten ab. Explizit gesetzte sub_tags
# haben Vorrang (siehe _register).
func _infer_sub_tags(card: CardData) -> Array[String]:
	var tags: Array[String] = []
	var add := func(tag: String, condition: bool) -> void:
		if condition and not tags.has(tag):
			tags.append(tag)
	# Offensive
	add.call("Schaden", card.damage_mult > 1.0)
	add.call("Feuerrate", card.fire_rate_mult < 1.0 or card.max_ammo_add > 0 or card.reload_speed_mult > 1.0)
	add.call("Projektil", card.bullet_speed_mult != 1.0 or card.bullet_size_mult != 1.0 \
		or card.projectile_gravity_mult != 1.0 or card.knockback_mult > 1.0)
	add.call("Bounce", card.bounces_add > 0 or card.border_bounce or card.bounce_split \
		or card.required_mechanic == "bounce")
	add.call("Durchschlag", card.piercing_add > 0)
	add.call("Zielsuche", card.homing_strength_add > 0.0)
	add.call("Mehrfachschuss", card.multishot_add > 0 or card.spread_angle_deg != 0.0)
	add.call("Explosion", card.explosion_radius_add > 0.0 or card.cluster_bomblets or card.block_mine \
		or card.mine_damage_add > 0.0 or card.mine_radius_add > 0.0 or card.mine_instant)
	add.call("Element", card.poison_stacks_add > 0 or card.poison_damage_mult > 1.0 or card.poison_impact_cloud \
		or card.poison_trail or card.freeze_duration_add > 0.0 or card.frost_nova or card.frost_trail \
		or card.fire_shot or card.fire_impact_zone or card.fire_trail or card.lightning_shot \
		or card.chain_lightning or card.lightning_zone or card.fire_damage_mult > 1.0 \
		or card.fire_zone_radius_mult > 1.0)
	add.call("Begleiter", card.tower_enabled or card.tower_auto_spawn or card.tower_follow \
		or card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0 or card.drone_count_add > 0 \
		or card.drone_guardian or card.blocker_drone_count_add > 0 or card.blocker_drone_heal)
	# Defensive
	add.call("Leben", card.max_hp_mult > 1.0 or card.max_hp_flat > 0)
	add.call("Heilung", card.hp_regen_add > 0.0 or card.hp_regen_always_add > 0.0 \
		or card.lifesteal_percent_add > 0.0 or card.block_heal_zone or card.blocker_drone_heal \
		or card.reflect_heal_percent_add > 0.0 or card.melee_lifesteal_add > 0.0)
	add.call("Schild", card.shield_max_add > 0 or card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0)
	add.call("Barriere", card.block_duration_add > 0.0 or card.block_cooldown_mult < 1.0 or card.block_hits_add > 0 \
		or card.block_knockback_radius_add > 0.0 or card.block_knockback_force_add > 0.0 \
		or card.block_bomb or card.block_heal_zone or card.block_reflect_damage_add > 0.0 \
		or card.block_mine or card.mine_damage_add > 0.0 or card.mine_radius_add > 0.0 or card.mine_instant)
	add.call("Rüstung", card.armor_percent_add > 0.0 or card.self_damage_reduction_add > 0.0)
	add.call("Reflexion", card.damage_reflect_percent_add > 0.0 or card.reflect_low_hp_bonus_add > 0.0 \
		or card.block_reflect_damage_add > 0.0 or card.melee_parry)
	# Bewegung
	add.call("Tempo", card.move_speed_mult > 1.0)
	add.call("Sprung", card.jump_force_mult > 1.0 or card.extra_jumps_add > 0)
	add.call("Dash", card.dash_cooldown_mult < 1.0)
	add.call("Schwerkraft", card.gravity_mult < 1.0)
	add.call("Größe", card.body_size_mult != 1.0 or card.giant_growth != 0.0)
	# Nahkampf
	add.call("Klinge", card.melee_damage_mult > 1.0 or card.melee_execute_bonus_add > 0.0)
	add.call("Reichweite", card.melee_range_add > 0.0 or card.melee_arc_add > 0.0)
	add.call("Schlagtempo", card.melee_cooldown_mult < 1.0)
	add.call("Rückstoß", card.melee_knockback_mult > 1.0)
	add.call("Kontrolle", card.melee_freeze_add > 0.0 or card.melee_stun_add > 0.0 or card.melee_wall_stun_add > 0.0)
	add.call("Elementarhieb", card.melee_poison_stacks_add > 0 or card.melee_burn_stacks_add > 0 \
		or card.melee_chain_lightning)
	# Übergreifend
	add.call("Fähigkeit", card.ability_cooldown_mult != 1.0 or card.ability_damage_mult != 1.0 \
		or card.ability_radius_mult != 1.0 or card.ability_duration_mult != 1.0 \
		or card.ability_range_mult != 1.0 or card.wall_count_add > 0 \
		or not card.ability_evolution.is_empty())
	add.call("Powerup", is_powerup_card(card))
	add.call("Unique", card.border_bounce or card.bounce_split or card.kamikaze or card.tower_enabled \
		or card.tower_auto_spawn or card.tower_follow or card.poison_impact_cloud or card.poison_trail \
		or card.lightning_shot or card.chain_lightning or card.lightning_zone or card.frost_nova \
		or card.frost_trail or card.cluster_bomblets or card.fire_shot or card.fire_impact_zone \
		or card.fire_trail or card.drone_guardian or card.blocker_drone_heal or card.block_bomb \
		or card.block_heal_zone or card.block_mine or card.mine_instant \
		or card.melee_chain_lightning or card.melee_echo or card.melee_parry \
		or not card.ability_evolution.is_empty())
	return tags

func card_has_sub_tag(card: CardData, tag: String) -> bool:
	return card != null and card.sub_tags.has(tag)

func get_card(id: String) -> CardData:
	return cards_by_id.get(id, null)

# Zieht `count` unterschiedliche Karten. Klassenspezifische Karten werden nur
# angeboten, wenn `hero_id` zum Helden der Karte passt.
# Ohne `owned_ids` werden ausschließlich Grundkarten angeboten.
func get_random_cards(count: int = 5, exclude_ids: Array = [], hero_id: String = "") -> Array[CardData]:
	return get_draft_offer(count, exclude_ids, hero_id, [])

# Baut das Kartenangebot für einen Draft.
# - Grundkarten sind immer verfügbar.
# - Ausbaukarten erscheinen nur, wenn die zugehörige Grundkarte bereits im Besitz ist.
# - Wenn ein Talentbaum angeboten wird, werden möglichst alle offenen Zweige
#   dieser Familie gemeinsam angezeigt (z. B. "Mehr Türme" und "Folgende Türme").
# - Die Seltenheit wird über die in der Lobby eingestellten Prozente gewichtet.
## rarity_percents: eigene Seltenheits-Anteile statt der Lobby-Werte (z. B.
## Boss-Truhe im Horden-Modus: {"Epic": 95, "Legendary": 5}). Leer = Lobby.
func get_draft_offer(count: int = 5, exclude_ids: Array = [], hero_id: String = "", owned_ids: Array = [], rarity_percents: Dictionary = {}) -> Array[CardData]:
	var base_cards: Array[CardData] = []
	var upgrade_groups: Dictionary = {}

	for c in all_cards:
		if exclude_ids.has(c.id):
			continue
		# Elementkarten und Element-Grundkarten kommen nur über die Karte "Element".
		if is_element_card(c) or c.element_core:
			continue
		if not is_card_available_for_player(c, hero_id, owned_ids):
			continue

		if c.parent_card_id.is_empty():
			base_cards.append(c)
		elif owned_ids.has(c.parent_card_id):
			var group_id: String = c.family_id if not c.family_id.is_empty() else c.parent_card_id
			if not upgrade_groups.has(group_id):
				upgrade_groups[group_id] = []
			upgrade_groups[group_id].append(c)

	var all_available: Array[CardData] = []
	all_available.append_array(base_cards)
	for group in upgrade_groups.values():
		all_available.append_array(group)

	if all_available.size() <= count:
		all_available.shuffle()
		return all_available

	# Alle Angebote (Einzelkarten und komplette Talentbaum-Gruppen) werden zu
	# Einheiten zusammengefasst. Innerhalb einer Seltenheit teilen sich die
	# Einheiten den eingestellten Prozentanteil gleichmäßig. Dadurch entspricht
	# der Anteil einer Seltenheit am fertigen Angebot den Lobby-Prozenten.
	var units: Array = []
	for c in base_cards:
		units.append({"cards": [c]})
	for group in upgrade_groups.values():
		units.append({"cards": group})

	var selected: Array[CardData] = []

	while selected.size() < count and not units.is_empty():
		var fitting: Array[int] = []
		for i in range(units.size()):
			if selected.size() + units[i]["cards"].size() <= count:
				fitting.append(i)
		if fitting.is_empty():
			break

		var weights := _unit_rarity_weights(units, fitting, rarity_percents)
		var total := 0.0
		for weight in weights:
			total += weight
		var roll := randf() * total
		var chosen_pos := weights.size() - 1
		for j in range(weights.size()):
			roll -= weights[j]
			if roll <= 0.0:
				chosen_pos = j
				break

		var chosen_index: int = fitting[chosen_pos]
		selected.append_array(units[chosen_index]["cards"])
		units.remove_at(chosen_index)

	# Verbleibende Plätze mit gewichtet gezogenen Einzelkarten auffüllen.
	if selected.size() < count:
		var pool: Array[CardData] = []
		for c in all_available:
			if not selected.has(c):
				pool.append(c)
		while selected.size() < count and not pool.is_empty():
			var weights := _card_rarity_weights(pool)
			var total := 0.0
			for weight in weights:
				total += weight
			var roll := randf() * total
			var chosen_index := weights.size() - 1
			for j in range(weights.size()):
				roll -= weights[j]
				if roll <= 0.0:
					chosen_index = j
					break
			selected.append(pool[chosen_index])
			pool.remove_at(chosen_index)

	selected.shuffle()
	return selected

func _unit_rarity_weights(units: Array, fitting: Array[int], rarity_percents: Dictionary = {}) -> Array[float]:
	var counts: Dictionary = {}
	for i in fitting:
		var rarity: String = _unit_rarity(units[i]["cards"])
		counts[rarity] = int(counts.get(rarity, 0)) + 1

	# Eigene Anteile nur, wenn davon überhaupt etwas im Angebot ist.
	var custom := false
	if not rarity_percents.is_empty():
		for rarity in counts.keys():
			if float(rarity_percents.get(rarity, 0.0)) > 0.0:
				custom = true
				break
	var percent_of := func(r: String) -> float:
		return maxf(0.0, float(rarity_percents.get(r, 0.0)) if custom else Global.get_rarity_percent(r))

	var total_percent := 0.0
	for rarity in counts.keys():
		total_percent += percent_of.call(rarity)

	var weights: Array[float] = []
	if total_percent <= 0.0:
		for i in fitting:
			weights.append(1.0)
		return weights

	for i in fitting:
		var rarity: String = _unit_rarity(units[i]["cards"])
		var percent: float = percent_of.call(rarity)
		weights.append(percent / float(counts[rarity]))
	return weights

func _card_rarity_weights(pool: Array[CardData]) -> Array[float]:
	var counts: Dictionary = {}
	for card in pool:
		counts[card.rarity] = int(counts.get(card.rarity, 0)) + 1

	var total_percent := 0.0
	for rarity in counts.keys():
		total_percent += maxf(0.0, Global.get_rarity_percent(rarity))

	var weights: Array[float] = []
	if total_percent <= 0.0:
		for card in pool:
			weights.append(1.0)
		return weights

	for card in pool:
		var percent := maxf(0.0, Global.get_rarity_percent(card.rarity))
		weights.append(percent / float(counts[card.rarity]))
	return weights

func _unit_rarity(cards: Array) -> String:
	if cards.is_empty():
		return "Common"
	var card := cards[0] as CardData
	return card.rarity if card else "Common"
