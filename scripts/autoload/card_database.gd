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
	"Defensive": ["Leben", "Heilung", "Schild", "Block", "Rüstung", "Reflexion"],
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
	"Schild": "Schildgröße und Schildaufbau.",
	"Block": "Blockdauer, Abklingzeit und Block-Effekte.",
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
	c10.title = "Toxic Spores"
	c10.description = "Kugeln vergiften den Gegner.\n+3 Giftstapel."
	c10.rarity = "Rare"
	c10.color = Color(0.4, 0.9, 0.3)
	c10.poison_stacks_add = 3
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
	c12.version = 2 # Evolution A von blutdurst
	c12.title = "Vampiric Leech"
	c12.description = "Lebensraub-Ausbau: Saugt Leben aus jedem Treffer.\n+15% Lebensraub."
	c12.rarity = "Rare"
	c12.color = Color(0.8, 0.1, 0.3)
	c12.family_id = "blutdurst"
	c12.parent_card_id = "blutdurst"
	c12.evolution_branch = "A"
	c12.lifesteal_percent_add = 0.15
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

	# 20. Meteor Cannon (Epic)
	var c20 = CardData.new()
	c20.id = "meteor_cannon"
	c20.title = "Meteor Cannon"
	c20.description = "Riesige verheerende Explosion!\n+75px Explosionsradius, +60% Schaden, -30% Feuerrate"
	c20.rarity = "Epic"
	c20.color = Color(0.95, 0.3, 0.0)
	c20.explosion_radius_add = 75.0
	c20.damage_mult = 1.60
	c20.fire_rate_mult = 1.30
	_register(c20)

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
	n5.title = "Scharfe Munition"
	n5.description = "Mehr Durchschlagskraft.\n+20% Schaden."
	n5.rarity = "Common"
	n5.color = Color(0.95, 0.45, 0.25)
	n5.damage_mult = 1.20
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
	n11.title = "Blutdurst"
	n11.description = "Heilt dich um 12% des verursachten Projektil-Schadens."
	n11.rarity = "Uncommon"
	n11.color = Color(0.85, 0.20, 0.35)
	n11.lifesteal_percent_add = 0.12
	_register(n11)

	var n12 = CardData.new()
	n12.id = "vampirklinge"
	n12.version = 2 # Evolution B von blutdurst
	n12.title = "Vampirklinge"
	n12.description = "Lebensraub-Ausbau: Starker Lebensraub.\n+20% Lebensraub, -10% Max HP."
	n12.rarity = "Rare"
	n12.color = Color(0.70, 0.10, 0.25)
	n12.family_id = "blutdurst"
	n12.parent_card_id = "blutdurst"
	n12.evolution_branch = "B"
	n12.lifesteal_percent_add = 0.20
	n12.max_hp_mult = 0.90
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
	gb1.title = "Giftschuss"
	gb1.description = "Geschosse vergiften Gegner.\n+2 Giftstapel, +25% Giftschaden."
	gb1.rarity = "Rare"
	gb1.color = Color(0.40, 0.95, 0.25)
	gb1.family_id = "giftschuss"
	gb1.poison_stacks_add = 2
	gb1.poison_damage_mult = 1.25
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
	gb3.title = "Giftspur"
	gb3.description = "Giftschuss-Ausbau: Hinterlässt eine Giftspur. Sie schadet dir selbst nicht."
	gb3.rarity = "Epic"
	gb3.color = Color(0.50, 0.90, 0.20)
	gb3.family_id = "giftschuss"
	gb3.parent_card_id = "giftschuss"
	gb3.evolution_branch = "B"
	gb3.poison_trail = true
	_register(gb3)

	# --- Blitzschuss ---
	var lb1 = CardData.new()
	lb1.id = "blitzschuss"
	lb1.title = "Blitzschuss"
	lb1.description = "Blitzangriff, der Gegner für 0,1 Sekunden betäubt."
	lb1.rarity = "Rare"
	lb1.color = Color(1.00, 0.90, 0.20)
	lb1.family_id = "blitzschuss"
	lb1.lightning_shot = true
	lb1.damage_mult = 1.05
	_register(lb1)

	var lb2 = CardData.new()
	lb2.id = "blitzschuss_kette"
	lb2.title = "Kettenblitz"
	lb2.description = "Blitzschuss-Ausbau: Der Blitz springt auf nahe Gegner über und betäubt sie erneut."
	lb2.rarity = "Epic"
	lb2.color = Color(1.00, 0.80, 0.10)
	lb2.family_id = "blitzschuss"
	lb2.parent_card_id = "blitzschuss"
	lb2.evolution_branch = "A"
	lb2.chain_lightning = true
	_register(lb2)

	var lb3 = CardData.new()
	lb3.id = "blitzschuss_zone"
	lb3.title = "Blitz-Orb"
	lb3.description = "Blitzschuss-Ausbau: Erzeugt am Einschlag eine Blitzzone, die Gegner beim Betreten betäubt."
	lb3.rarity = "Epic"
	lb3.color = Color(0.90, 0.75, 1.00)
	lb3.family_id = "blitzschuss"
	lb3.parent_card_id = "blitzschuss"
	lb3.evolution_branch = "B"
	lb3.lightning_zone = true
	_register(lb3)

	# --- Frostschuss ---
	var fb1 = CardData.new()
	fb1.id = "frostschuss"
	fb1.title = "Frostschuss"
	fb1.description = "Geschosse verlangsamen Gegner für 0,8 Sekunden."
	fb1.rarity = "Uncommon"
	fb1.color = Color(0.35, 0.85, 1.00)
	fb1.family_id = "frostschuss"
	fb1.freeze_duration_add = 0.8
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
	fb3.title = "Eisbahn"
	fb3.description = "Frostschuss-Ausbau: Hinterlässt eine Eisbahn, die Gegner verlangsamt."
	fb3.rarity = "Rare"
	fb3.color = Color(0.45, 0.80, 0.95)
	fb3.family_id = "frostschuss"
	fb3.parent_card_id = "frostschuss"
	fb3.evolution_branch = "B"
	fb3.frost_trail = true
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

	# --- Feuersturm ---
	var rb1 = CardData.new()
	rb1.id = "feuersturm"
	rb1.title = "Feuersturm"
	rb1.description = "Geschosse entzünden Gegner und verursachen Brennschaden."
	rb1.rarity = "Rare"
	rb1.color = Color(1.00, 0.35, 0.10)
	rb1.family_id = "feuersturm"
	rb1.fire_shot = true
	rb1.damage_mult = 1.05
	_register(rb1)

	var rb2 = CardData.new()
	rb2.id = "feuersturm_brandherd"
	rb2.title = "Brandherd"
	rb2.description = "Feuersturm-Ausbau: Beim Einschlag entsteht ein brennender Boden, der Gegner entzündet."
	rb2.rarity = "Epic"
	rb2.color = Color(1.00, 0.20, 0.05)
	rb2.family_id = "feuersturm"
	rb2.parent_card_id = "feuersturm"
	rb2.evolution_branch = "A"
	rb2.fire_impact_zone = true
	_register(rb2)

	var rb3 = CardData.new()
	rb3.id = "feuersturm_spur"
	rb3.title = "Feuerspur"
	rb3.description = "Feuersturm-Ausbau: Hinterlässt eine brennende Spur. Sie schadet dir selbst nicht."
	rb3.rarity = "Epic"
	rb3.color = Color(1.00, 0.50, 0.10)
	rb3.family_id = "feuersturm"
	rb3.parent_card_id = "feuersturm"
	rb3.evolution_branch = "B"
	rb3.fire_trail = true
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
	bc18.title = "Schnellfeuer"
	bc18.description = "Dauerfeuer.\n+18% Feuerrate."
	bc18.rarity = "Common"
	bc18.color = Color(0.95, 0.70, 0.20)
	bc18.fire_rate_mult = 0.82
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

	# Schild-Pause verkürzen. Erscheinen erst ab 25 Schild (required_mechanic).
	var sp1 = CardData.new()
	sp1.id = "schildkondensator"
	sp1.title = "Schildkondensator"
	sp1.description = "Schild lädt früher nach.\n-0,75s Schild-Pause nach Schaden."
	sp1.rarity = "Common"
	sp1.color = Color(0.45, 0.80, 1.00)
	sp1.shield_regen_delay_add = -0.75
	sp1.required_mechanic = "shield"
	_register(sp1)

	var sp2 = CardData.new()
	sp2.id = "schnellstart_generator"
	sp2.title = "Schnellstart-Generator"
	sp2.description = "Schild springt sofort wieder an.\n-1,25s Schild-Pause, +20% Schild-Regeneration."
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
	kl1.description = "Klinge: +25% Schaden, +15% Feuerrate."
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
	ba2.description = "Bastion: +40% Schild-Regeneration, +15% Nachladegeschwindigkeit."
	ba2.rarity = "Rare"
	ba2.color = Color(0.35, 0.85, 0.75)
	ba2.hero_id = "bastion"
	ba2.shield_regen_mult = 1.40
	ba2.reload_speed_mult = 1.15
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
	ph1.description = "Phantom: +20% Schaden, +2 Durchschlag."
	ph1.rarity = "Rare"
	ph1.color = Color(0.50, 0.50, 0.70)
	ph1.hero_id = "phantom"
	ph1.damage_mult = 1.20
	ph1.piercing_add = 2
	ph1.version = 2 # Durchschlag wirkt jetzt auch durch Wände
	_register(ph1)

	var ph2 = CardData.new()
	ph2.id = "phantom_sprungkraft"
	ph2.title = "Schattensprung"
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

	# --- Volt ---
	var fa5 = CardData.new()
	fa5.id = "volt_hochspannung"
	fa5.title = "Hochspannung"
	fa5.description = "Volt – Flash Blink: +35% Schockschaden, +20% Schockradius, +25% Teleportweite."
	fa5.rarity = "Rare"
	fa5.pool = "Offensive"
	fa5.color = Color(1.00, 0.90, 0.20)
	fa5.hero_id = "volt"
	fa5.family_id = "volt_blink"
	fa5.ability_damage_mult = 1.35
	fa5.ability_radius_mult = 1.20
	fa5.ability_range_mult = 1.25
	_register(fa5)

	var fa6 = CardData.new()
	fa6.id = "volt_kettenblink"
	fa6.title = "Kettenblink"
	fa6.description = "Flash-Blink-Evolution: Jeder Gegner, den die Schockwelle trifft, löst einen Kettenblitz auf einen weiteren Gegner aus."
	fa6.rarity = "Epic"
	fa6.color = Color(1.00, 0.90, 0.20)
	fa6.hero_id = "volt"
	fa6.family_id = "volt_blink"
	fa6.parent_card_id = "volt_hochspannung"
	fa6.evolution_branch = "A"
	fa6.ability_evolution = "volt_chain"
	_register(fa6)

	var fa7 = CardData.new()
	fa7.id = "volt_gewitterspur"
	fa7.title = "Gewitterspur"
	fa7.description = "Flash-Blink-Evolution: Start- und Zielpunkt des Blinks werden 4 s lang zu Blitzzonen, die Gegner beim Betreten betäuben."
	fa7.rarity = "Epic"
	fa7.color = Color(1.00, 0.90, 0.20)
	fa7.hero_id = "volt"
	fa7.family_id = "volt_blink"
	fa7.parent_card_id = "volt_hochspannung"
	fa7.evolution_branch = "B"
	fa7.ability_evolution = "volt_storm"
	_register(fa7)

	var fa8 = CardData.new()
	fa8.id = "volt_restladung"
	fa8.title = "Restladung"
	fa8.description = "Volt – Flash Blink: Getroffene Gegner bleiben 50% länger verlangsamt, -10% Fähigkeits-Abklingzeit."
	fa8.rarity = "Uncommon"
	fa8.pool = "Offensive"
	fa8.color = Color(1.00, 0.90, 0.20)
	fa8.hero_id = "volt"
	fa8.ability_duration_mult = 1.50
	fa8.ability_cooldown_mult = 0.90
	_register(fa8)

	# --- Spore ---
	var fa9 = CardData.new()
	fa9.id = "spore_dichter_nebel"
	fa9.title = "Dichter Nebel"
	fa9.description = "Spore – Spore Burst: Die Giftwolke hat +40% Radius und hält 40% länger."
	fa9.rarity = "Rare"
	fa9.pool = "Offensive"
	fa9.color = Color(0.40, 0.90, 0.30)
	fa9.hero_id = "spore"
	fa9.family_id = "spore_burst"
	fa9.ability_radius_mult = 1.40
	fa9.ability_duration_mult = 1.40
	_register(fa9)

	var fa10 = CardData.new()
	fa10.id = "spore_aetzender_nebel"
	fa10.title = "Ätzender Nebel"
	fa10.description = "Spore-Burst-Evolution: Gegner in der Wolke werden alle 0,8 s mit 3 Giftstapeln belegt, die nach dem Verlassen nachwirken. +20% Wolkenschaden."
	fa10.rarity = "Epic"
	fa10.color = Color(0.40, 0.90, 0.30)
	fa10.hero_id = "spore"
	fa10.family_id = "spore_burst"
	fa10.parent_card_id = "spore_dichter_nebel"
	fa10.evolution_branch = "A"
	fa10.ability_evolution = "spore_corrosive"
	fa10.ability_damage_mult = 1.20
	_register(fa10)

	var fa11 = CardData.new()
	fa11.id = "spore_symbiose"
	fa11.title = "Symbiose"
	fa11.description = "Spore-Burst-Evolution: Solange du in deiner eigenen Wolke stehst, heilst du 6 HP pro Sekunde. +15% Wolkenradius."
	fa11.rarity = "Epic"
	fa11.color = Color(0.40, 0.90, 0.30)
	fa11.hero_id = "spore"
	fa11.family_id = "spore_burst"
	fa11.parent_card_id = "spore_dichter_nebel"
	fa11.evolution_branch = "B"
	fa11.ability_evolution = "spore_symbiosis"
	fa11.ability_radius_mult = 1.15
	_register(fa11)

	var fa12 = CardData.new()
	fa12.id = "spore_sporenvorrat"
	fa12.title = "Sporenvorrat"
	fa12.description = "Spore – Spore Burst: -20% Fähigkeits-Abklingzeit, +25% Wolkenschaden."
	fa12.rarity = "Uncommon"
	fa12.pool = "Offensive"
	fa12.color = Color(0.40, 0.90, 0.30)
	fa12.hero_id = "spore"
	fa12.ability_cooldown_mult = 0.80
	fa12.ability_damage_mult = 1.25
	_register(fa12)

	# --- Nova ---
	var fa13 = CardData.new()
	fa13.id = "nova_ereignishorizont"
	fa13.title = "Ereignishorizont"
	fa13.description = "Nova – Singularität: +30% Sogradius, hält 30% länger, +15% Wurfweite."
	fa13.rarity = "Rare"
	fa13.pool = "Offensive"
	fa13.color = Color(0.60, 0.40, 1.00)
	fa13.hero_id = "nova"
	fa13.family_id = "nova_singularity"
	fa13.ability_radius_mult = 1.30
	fa13.ability_duration_mult = 1.30
	fa13.ability_range_mult = 1.15
	_register(fa13)

	var fa14 = CardData.new()
	fa14.id = "nova_implosion"
	fa14.title = "Implosion"
	fa14.description = "Singularitäts-Evolution: Am Ende kollabiert die Singularität und schleudert alle Gegner im Umkreis mit 30 Schaden nach außen."
	fa14.rarity = "Epic"
	fa14.color = Color(0.60, 0.40, 1.00)
	fa14.hero_id = "nova"
	fa14.family_id = "nova_singularity"
	fa14.parent_card_id = "nova_ereignishorizont"
	fa14.evolution_branch = "A"
	fa14.ability_evolution = "nova_implosion"
	_register(fa14)

	var fa15 = CardData.new()
	fa15.id = "nova_doppelstern"
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
	fa16.title = "Massenanziehung"
	fa16.description = "Nova – Singularität: -15% Fähigkeits-Abklingzeit, +15% Sogradius."
	fa16.rarity = "Uncommon"
	fa16.pool = "Offensive"
	fa16.color = Color(0.60, 0.40, 1.00)
	fa16.hero_id = "nova"
	fa16.ability_cooldown_mult = 0.85
	fa16.ability_radius_mult = 1.15
	_register(fa16)

	# --- Klinge ---
	var fa17 = CardData.new()
	fa17.id = "klinge_geschliffen"
	fa17.title = "Geschliffene Klingen"
	fa17.description = "Klinge – Klingensturm: +30% Schaden, +15% Radius."
	fa17.rarity = "Rare"
	fa17.pool = "Offensive"
	fa17.color = Color(1.00, 0.30, 0.50)
	fa17.hero_id = "klinge"
	fa17.family_id = "klinge_storm"
	fa17.ability_damage_mult = 1.30
	fa17.ability_radius_mult = 1.15
	_register(fa17)

	var fa18 = CardData.new()
	fa18.id = "klinge_echowirbel"
	fa18.title = "Echowirbel"
	fa18.description = "Klingensturm-Evolution: 0,45 s nach dem ersten Wirbel folgt ein zweiter mit 60% Schaden und Rückstoß."
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
	fa19.title = "Blutrausch"
	fa19.description = "Klingensturm-Evolution: Du heilst dich um 35% des mit Klingensturm verursachten Schadens. +40% Unverwundbarkeitsdauer."
	fa19.rarity = "Epic"
	fa19.color = Color(1.00, 0.30, 0.50)
	fa19.hero_id = "klinge"
	fa19.family_id = "klinge_storm"
	fa19.parent_card_id = "klinge_geschliffen"
	fa19.evolution_branch = "B"
	fa19.ability_evolution = "klinge_bloodlust"
	fa19.ability_duration_mult = 1.40
	_register(fa19)

	var fa20 = CardData.new()
	fa20.id = "klinge_tanzschritt"
	fa20.title = "Tanzschritt"
	fa20.description = "Klinge – Klingensturm: -20% Fähigkeits-Abklingzeit, +30% Unverwundbarkeitsdauer."
	fa20.rarity = "Uncommon"
	fa20.pool = "Offensive"
	fa20.color = Color(1.00, 0.30, 0.50)
	fa20.hero_id = "klinge"
	fa20.ability_cooldown_mult = 0.80
	fa20.ability_duration_mult = 1.30
	_register(fa20)

	# --- Bastion ---
	var fa21 = CardData.new()
	fa21.id = "bastion_emitter"
	fa21.title = "Verstärkte Emitter"
	fa21.description = "Bastion – Heilfeld: +30% Heilung und Schildaufbau, hält 25% länger."
	fa21.rarity = "Rare"
	fa21.pool = "Defensive"
	fa21.color = Color(0.30, 0.90, 0.70)
	fa21.hero_id = "bastion"
	fa21.family_id = "bastion_field"
	fa21.ability_damage_mult = 1.30
	fa21.ability_duration_mult = 1.25
	_register(fa21)

	var fa22 = CardData.new()
	fa22.id = "bastion_schutzkuppel"
	fa22.title = "Schutzkuppel"
	fa22.description = "Heilfeld-Evolution: Solange dein Heilfeld aktiv ist, erleidest du 30% weniger Schaden."
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
	fa23.title = "Pulsfeld"
	fa23.description = "Heilfeld-Evolution: Bei jedem Heil-Tick pulsiert das Feld und verursacht 7 Schaden mit Rückstoß an Gegnern im Umkreis von 130 px."
	fa23.rarity = "Epic"
	fa23.color = Color(0.30, 0.90, 0.70)
	fa23.hero_id = "bastion"
	fa23.family_id = "bastion_field"
	fa23.parent_card_id = "bastion_emitter"
	fa23.evolution_branch = "B"
	fa23.ability_evolution = "bastion_pulse"
	_register(fa23)

	var fa24 = CardData.new()
	fa24.id = "bastion_notfallprotokoll"
	fa24.title = "Notfallprotokoll"
	fa24.description = "Bastion – Heilfeld: -25% Fähigkeits-Abklingzeit."
	fa24.rarity = "Uncommon"
	fa24.pool = "Defensive"
	fa24.color = Color(0.30, 0.90, 0.70)
	fa24.hero_id = "bastion"
	fa24.ability_cooldown_mult = 0.75
	_register(fa24)

	# --- Phantom ---
	var fa25 = CardData.new()
	fa25.id = "phantom_lautlose_klinge"
	fa25.title = "Lautlose Klinge"
	fa25.description = "Phantom – Schattensprung: +30% Schaden, +20% Trefferradius, +20% Sprungweite."
	fa25.rarity = "Rare"
	fa25.pool = "Offensive"
	fa25.color = Color(0.45, 0.45, 0.60)
	fa25.hero_id = "phantom"
	fa25.family_id = "phantom_step"
	fa25.ability_damage_mult = 1.30
	fa25.ability_radius_mult = 1.20
	fa25.ability_range_mult = 1.20
	_register(fa25)

	var fa26 = CardData.new()
	fa26.id = "phantom_schattenschnitt"
	fa26.title = "Schattenschnitt"
	fa26.description = "Schattensprung-Evolution: Trifft zusätzlich alle Gegner entlang der Sprungbahn."
	fa26.rarity = "Epic"
	fa26.color = Color(0.45, 0.45, 0.60)
	fa26.hero_id = "phantom"
	fa26.family_id = "phantom_step"
	fa26.parent_card_id = "phantom_lautlose_klinge"
	fa26.evolution_branch = "A"
	fa26.ability_evolution = "phantom_cut"
	_register(fa26)

	var fa27 = CardData.new()
	fa27.id = "phantom_laehmendes_mal"
	fa27.title = "Lähmendes Mal"
	fa27.description = "Schattensprung-Evolution: Getroffene Gegner werden 0,7 s betäubt."
	fa27.rarity = "Epic"
	fa27.color = Color(0.45, 0.45, 0.60)
	fa27.hero_id = "phantom"
	fa27.family_id = "phantom_step"
	fa27.parent_card_id = "phantom_lautlose_klinge"
	fa27.evolution_branch = "B"
	fa27.ability_evolution = "phantom_mark"
	_register(fa27)

	var fa28 = CardData.new()
	fa28.id = "phantom_lange_schatten"
	fa28.title = "Lange Schatten"
	fa28.description = "Phantom – Schattensprung: +50% Unverwundbarkeitsdauer, -10% Fähigkeits-Abklingzeit."
	fa28.rarity = "Uncommon"
	fa28.pool = "Offensive"
	fa28.color = Color(0.45, 0.45, 0.60)
	fa28.hero_id = "phantom"
	fa28.ability_duration_mult = 1.50
	fa28.ability_cooldown_mult = 0.90
	_register(fa28)

	# ============================================================
	# Block-Karten (universell, verbessern die Q-Fähigkeit)
	# ============================================================

	# --- Common ---
	var bl1 = CardData.new()
	bl1.id = "block_uebung"
	bl1.title = "Blockübung"
	bl1.description = "Längere Deckung.\n+0,15s Blockdauer."
	bl1.rarity = "Common"
	bl1.color = Color(0.45, 0.80, 1.00)
	bl1.block_duration_add = 0.15
	_register(bl1)

	var bl2 = CardData.new()
	bl2.id = "schnelle_deckung"
	bl2.title = "Schnelle Deckung"
	bl2.description = "Schneller wieder bereit.\n-15% Block-Abklingzeit."
	bl2.rarity = "Common"
	bl2.color = Color(0.35, 0.75, 0.95)
	bl2.block_cooldown_mult = 0.85
	_register(bl2)

	# --- Uncommon ---
	var bl3 = CardData.new()
	bl3.id = "verstaerkte_deckung"
	bl3.version = 2 # Blockdauer +0,30 s statt +0,20 s
	bl3.title = "Verstärkte Deckung"
	bl3.description = "Längere Schadensimmunität.\n+0,3s Blockdauer."
	bl3.rarity = "Uncommon"
	bl3.color = Color(0.40, 0.70, 1.00)
	bl3.block_duration_add = 0.30
	_register(bl3)

	var bl4 = CardData.new()
	bl4.id = "schildstoss"
	bl4.title = "Schildstoß"
	bl4.description = "Block stößt Gegner in der Nähe weg.\n+130px Radius, +350 Rückstoß."
	bl4.rarity = "Uncommon"
	bl4.color = Color(0.55, 0.90, 1.00)
	bl4.block_knockback_radius_add = 130.0
	bl4.block_knockback_force_add = 350.0
	_register(bl4)

	# --- Rare ---
	var bl5 = CardData.new()
	bl5.id = "blockbombe"
	bl5.title = "Blockbombe"
	bl5.description = "Beim Blocken explodiert eine Bombe.\n35 Schaden + Rückstoß im Umkreis."
	bl5.rarity = "Rare"
	bl5.color = Color(1.00, 0.55, 0.15)
	bl5.block_bomb = true
	bl5.block_bomb_damage = 35.0
	_register(bl5)

	var bl6 = CardData.new()
	bl6.id = "heilzone"
	bl6.title = "Heilzone"
	bl6.description = "Block erzeugt ein Heilfeld.\nHeilt 6 HP alle 0,5s für 2,5s."
	bl6.rarity = "Rare"
	bl6.color = Color(0.35, 1.00, 0.55)
	bl6.block_heal_zone = true
	_register(bl6)

	var bl7 = CardData.new()
	bl7.id = "druckwelle"
	bl7.title = "Druckwelle"
	bl7.description = "Starker Rückstoß beim Blocken.\n+170px Radius, +600 Rückstoß."
	bl7.rarity = "Rare"
	bl7.color = Color(0.40, 0.90, 1.00)
	bl7.block_knockback_radius_add = 170.0
	bl7.block_knockback_force_add = 600.0
	_register(bl7)

	var bl8 = CardData.new()
	bl8.id = "ausdauerblock"
	bl8.version = 3 # +0,3s Blockdauer statt +0,15s (Jochen)
	bl8.title = "Ausdauerblock"
	bl8.description = "Block-Ausbau: Länger und öfter blocken.\n+0,3s Blockdauer, -10% Block-Abklingzeit."
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
	bl10.title = "Block-Experte"
	bl10.description = "Meisterhafte Deckung.\n-30% Block-Abklingzeit, +0,2s Blockdauer."
	bl10.rarity = "Epic"
	bl10.color = Color(0.45, 0.75, 1.00)
	bl10.block_cooldown_mult = 0.70
	bl10.block_duration_add = 0.20
	_register(bl10)

	var bl11 = CardData.new()
	bl11.id = "unzerbrechlich"
	bl11.title = "Unzerbrechlich"
	bl11.description = "Deutlich längere Deckung.\n+0,4s Blockdauer, -10% Block-Abklingzeit."
	bl11.rarity = "Epic"
	bl11.color = Color(0.55, 0.65, 0.90)
	bl11.block_duration_add = 0.40
	bl11.block_cooldown_mult = 0.90
	_register(bl11)

	# --- Minenleger (Talentbaum + Minen-Karten) ---
	var mn1 = CardData.new()
	mn1.id = "minenleger"
	mn1.title = "Minenleger"
	mn1.description = "Blocken legt eine Mine, die zu Boden fällt. Gegner sehen sie nicht.\nNach 2s scharf, explodiert 1,5s nachdem ein Gegner darüberläuft.\n50 Schaden, 2 Felder Explosionsradius."
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

	var of3 = CardData.new()
	of3.id = "brandkapsel"
	of3.title = "Brandkapsel"
	of3.description = "Treffer entzünden den Boden.\n+Feuerzone, +10% Schaden."
	of3.rarity = "Epic"
	of3.pool = "Offensive"
	of3.color = Color(1.00, 0.40, 0.10)
	of3.fire_shot = true
	of3.fire_impact_zone = true
	of3.damage_mult = 1.10
	_register(of3)

	var of4 = CardData.new()
	of4.id = "kettenreaktion"
	of4.title = "Kettenreaktion"
	of4.description = "Blitze springen zwischen Gegnern.\n+Blitzschuss, +Kettenblitz."
	of4.rarity = "Epic"
	of4.pool = "Offensive"
	of4.color = Color(0.95, 0.85, 0.20)
	of4.lightning_shot = true
	of4.chain_lightning = true
	of4.damage_mult = 0.95
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
	df2.version = 2 # Max-HP/Schild-Bonus verdoppelt
	df2.title = "Bollwerk"
	df2.description = "Mehr Schild und längere Deckung.\n+60 Schild, +0,15s Blockdauer."
	df2.rarity = "Rare"
	df2.pool = "Defensive"
	df2.color = Color(0.40, 0.75, 1.00)
	df2.shield_max_add = 60
	df2.block_duration_add = 0.15
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

	# Ausbaukarten, die vor ihrer Grundkarte registriert wurden, übernehmen
	# hier nachträglich deren Pool.
	for card in all_cards:
		if not card.parent_card_id.is_empty() and cards_by_id.has(card.parent_card_id):
			card.pool = cards_by_id[card.parent_card_id].pool

func _register(card: CardData) -> void:
	if card.pool.is_empty():
		card.pool = _infer_pool(card)
	if card.required_mechanic.is_empty():
		card.required_mechanic = _infer_required_mechanic(card)
	if card.sub_tags.is_empty():
		card.sub_tags = _infer_sub_tags(card)
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
	if (card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0) and card.shield_max_add <= 0:
		return "shield"
	if card.poison_damage_mult > 1.0 and card.poison_stacks_add <= 0 \
			and not card.poison_impact_cloud and not card.poison_trail:
		return "poison"
	if card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0:
		return "tower"
	return ""

# Helden, deren Grundfähigkeit keinen Schaden macht: Allgemeine
# Fähigkeitsschaden-Karten erscheinen erst mit dieser Evolutionskarte im Deck.
const ABILITY_DAMAGE_UNLOCK_CARDS: Dictionary = {"nova": "nova_implosion"}

func is_ability_damage_locked(card: CardData, hero_id: String, owned_ids: Array = []) -> bool:
	if card == null or not card.hero_id.is_empty() or card.ability_damage_mult <= 1.0:
		return false
	if not ABILITY_DAMAGE_UNLOCK_CARDS.has(hero_id):
		return false
	return not owned_ids.has(ABILITY_DAMAGE_UNLOCK_CARDS[hero_id])

func is_card_available_for_player(card: CardData, hero_id: String, owned_ids: Array = []) -> bool:
	if card == null:
		return false
	if is_ability_damage_locked(card, hero_id, owned_ids):
		return false
	if not is_card_pool_enabled(card):
		return false
	if is_powerup_card_locked(card):
		return false
	if not card.hero_id.is_empty() and card.hero_id != hero_id:
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

# Held, der eine Mechanik schon mitbringt (ohne passende Karte).
const HERO_MECHANICS := {"poison": "spore"}

func _player_has_mechanic(mechanic: String, hero_id: String, owned_ids: Array) -> bool:
	if ALWAYS_AVAILABLE_MECHANICS.has(mechanic):
		return true
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
		or card.block_duration_add > 0.0 or card.block_cooldown_mult < 1.0 \
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
		or card.chain_lightning or card.lightning_zone)
	add.call("Begleiter", card.tower_enabled or card.tower_auto_spawn or card.tower_follow \
		or card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0 or card.drone_count_add > 0 \
		or card.drone_guardian or card.blocker_drone_count_add > 0 or card.blocker_drone_heal)
	# Defensive
	add.call("Leben", card.max_hp_mult > 1.0 or card.max_hp_flat > 0)
	add.call("Heilung", card.hp_regen_add > 0.0 or card.hp_regen_always_add > 0.0 \
		or card.lifesteal_percent_add > 0.0 or card.block_heal_zone or card.blocker_drone_heal \
		or card.reflect_heal_percent_add > 0.0 or card.melee_lifesteal_add > 0.0)
	add.call("Schild", card.shield_max_add > 0 or card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0)
	add.call("Block", card.block_duration_add > 0.0 or card.block_cooldown_mult < 1.0 \
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
		or card.ability_range_mult != 1.0 or not card.ability_evolution.is_empty())
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
func get_draft_offer(count: int = 5, exclude_ids: Array = [], hero_id: String = "", owned_ids: Array = []) -> Array[CardData]:
	var base_cards: Array[CardData] = []
	var upgrade_groups: Dictionary = {}

	for c in all_cards:
		if exclude_ids.has(c.id):
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

		var weights := _unit_rarity_weights(units, fitting)
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

func _unit_rarity_weights(units: Array, fitting: Array[int]) -> Array[float]:
	var counts: Dictionary = {}
	for i in fitting:
		var rarity: String = _unit_rarity(units[i]["cards"])
		counts[rarity] = int(counts.get(rarity, 0)) + 1

	var total_percent := 0.0
	for rarity in counts.keys():
		total_percent += maxf(0.0, Global.get_rarity_percent(rarity))

	var weights: Array[float] = []
	if total_percent <= 0.0:
		for i in fitting:
			weights.append(1.0)
		return weights

	for i in fitting:
		var rarity: String = _unit_rarity(units[i]["cards"])
		var percent := maxf(0.0, Global.get_rarity_percent(rarity))
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
