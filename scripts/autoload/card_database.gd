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

func _ready() -> void:
	_init_database()

func _init_database() -> void:
	all_cards.clear()
	cards_by_id.clear()

	# 1. Bouncy Balls
	var c1 = CardData.new()
	c1.id = "bouncy_balls"
	c1.title = "Bouncy Balls"
	c1.description = "Bullets ricochet off walls!\n+2 Bounces, +15% Bullet Speed"
	c1.rarity = "Common"
	c1.color = Color(0.3, 0.8, 0.3)
	c1.bounces_add = 2
	c1.bullet_speed_mult = 1.15
	_register(c1)

	# 2. Heavy Bullets
	var c2 = CardData.new()
	c2.id = "heavy_bullets"
	c2.title = "Heavy Bullets"
	c2.description = "Massive heavy impact.\n+35% Damage, +40% Bullet Size, -15% Speed"
	c2.rarity = "Common"
	c2.color = Color(0.8, 0.4, 0.2)
	c2.damage_mult = 1.35
	c2.bullet_size_mult = 1.4
	c2.bullet_speed_mult = 0.85
	_register(c2)

	# 3. Fast Forward
	var c3 = CardData.new()
	c3.id = "fast_forward"
	c3.title = "Fast Forward"
	c3.description = "Lightning fast rounds.\n+50% Bullet Speed, +15% Move Speed"
	c3.rarity = "Common"
	c3.color = Color(0.2, 0.7, 0.9)
	c3.bullet_speed_mult = 1.5
	c3.move_speed_mult = 1.15
	_register(c3)

	# 4. Tactical Vest
	var c4 = CardData.new()
	c4.id = "tactical_vest"
	c4.title = "Tactical Vest"
	c4.description = "Reinforced plating.\n+30 Max HP, +15 Shield"
	c4.rarity = "Rare"
	c4.color = Color(0.4, 0.7, 0.4)
	c4.max_hp_flat = 30
	c4.shield_max_add = 15
	_register(c4)

	# 5. Quick Draw
	var c5 = CardData.new()
	c5.id = "quick_draw"
	c5.title = "Quick Draw"
	c5.description = "Rapid response trigger.\n+30% Fire Rate, +1 Max Ammo"
	c5.rarity = "Common"
	c5.color = Color(0.9, 0.7, 0.2)
	c5.fire_rate_mult = 0.70 # Cooldown reduced by 30%
	c5.max_ammo_add = 1
	_register(c5)

	# 6. Feather Shoes
	var c6 = CardData.new()
	c6.id = "feather_shoes"
	c6.title = "Feather Shoes"
	c6.description = "Defy gravity.\n+1 Extra Jump, +15% Jump Force"
	c6.rarity = "Common"
	c6.color = Color(0.8, 0.8, 0.5)
	c6.extra_jumps_add = 1
	c6.jump_force_mult = 1.15
	_register(c6)

	# 7. Homing Rounds
	var c7 = CardData.new()
	c7.id = "homing_rounds"
	c7.title = "Homing Micro-Seekers"
	c7.description = "Bullets curve towards your opponent!\n-10% Damage"
	c7.rarity = "Rare"
	c7.color = Color(0.5, 0.3, 0.9)
	c7.homing_strength_add = 0.45
	c7.damage_mult = 0.90
	_register(c7)

	# 8. Shotgun Spread
	var c8 = CardData.new()
	c8.id = "shotgun_spread"
	c8.title = "Buckshot Burst"
	c8.description = "Fires 2 extra projectiles in a cone!\n-35% Damage per bullet"
	c8.rarity = "Rare"
	c8.color = Color(0.9, 0.4, 0.4)
	c8.multishot_add = 2
	c8.spread_angle_deg = 24.0
	c8.damage_mult = 0.65
	_register(c8)

	# 9. Cluster Bomb
	var c9 = CardData.new()
	c9.id = "cluster_bomb"
	c9.title = "Cluster Warhead"
	c9.description = "Bullets explode into 3 micro-shrapnels on impact!\nExplosion Radius +35px"
	c9.rarity = "Rare"
	c9.color = Color(0.9, 0.5, 0.1)
	c9.explosion_radius_add = 35.0
	_register(c9)

	# 10. Toxic Spores
	var c10 = CardData.new()
	c10.id = "toxic_spores"
	c10.title = "Toxic Spores"
	c10.description = "Bullets poison the enemy for 3 seconds of damage-over-time."
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
	c12.title = "Vampiric Leech"
	c12.description = "Heilt dich um 25% des verursachten Projektil-Schadens."
	c12.rarity = "Rare"
	c12.color = Color(0.8, 0.1, 0.3)
	c12.lifesteal_percent_add = 0.25
	_register(c12)

	# 13. Kinetic Barrier
	var c13 = CardData.new()
	c13.id = "kinetic_barrier"
	c13.title = "Kinetic Barrier"
	c13.description = "Massiver Schutzschild!\n+45 Shield, regeneriert nach 3s ohne Schaden."
	c13.rarity = "Rare"
	c13.color = Color(0.3, 0.5, 0.9)
	c13.shield_max_add = 45
	_register(c13)

	# 14. Sonic Dash
	var c14 = CardData.new()
	c14.id = "sonic_dash"
	c14.title = "Sonic Dash"
	c14.description = "Warp-Geschwindigkeit.\n-45% Dash Cooldown, +20% Move Speed"
	c14.rarity = "Rare"
	c14.color = Color(0.9, 0.9, 0.2)
	c14.dash_cooldown_mult = 0.55
	c14.move_speed_mult = 1.20
	_register(c14)

	# 15. Piercing Rail
	var c15 = CardData.new()
	c15.id = "piercing_rail"
	c15.title = "Piercing Rail"
	c15.description = "Geschosse durchdringen Gegner und Barrieren!\n+2 Piercing, +30% Bullet Speed"
	c15.rarity = "Rare"
	c15.color = Color(0.7, 0.4, 0.9)
	c15.piercing_add = 2
	c15.bullet_speed_mult = 1.3
	_register(c15)

	# 16. Ricochet Frenzy (Epic)
	var c16 = CardData.new()
	c16.id = "ricochet_frenzy"
	c16.title = "Ricochet Frenzy"
	c16.description = "Absurder Flipper-Effekt!\n+5 Bounces, +20% Bullet Speed"
	c16.rarity = "Epic"
	c16.color = Color(0.85, 0.2, 0.85)
	c16.bounces_add = 5
	c16.bullet_speed_mult = 1.20
	_register(c16)

	# 17. Colossus (Epic)
	var c17 = CardData.new()
	c17.id = "colossus"
	c17.title = "Colossus"
	c17.description = "Wandle wie ein Titan.\n+80 Max HP, +30% Größe, -10% Move Speed"
	c17.rarity = "Epic"
	c17.color = Color(0.8, 0.5, 0.2)
	c17.max_hp_flat = 80
	c17.giant_growth = 0.30
	c17.move_speed_mult = 0.90
	_register(c17)

	# 18. Glass Cannon (Epic)
	var c18 = CardData.new()
	c18.id = "glass_cannon"
	c18.title = "Glass Cannon"
	c18.description = "Tödlich aber zerbrechlich.\n+130% Damage, -40% Max HP, +25% Bullet Speed"
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
	c19.description = "Unaufhaltsamer Kugelhagel!\n+70% Fire Rate, +3 Max Ammo"
	c19.rarity = "Epic"
	c19.color = Color(0.9, 0.6, 0.1)
	c19.fire_rate_mult = 0.50
	c19.max_ammo_add = 3
	_register(c19)

	# 20. Meteor Cannon (Epic)
	var c20 = CardData.new()
	c20.id = "meteor_cannon"
	c20.title = "Meteor Cannon"
	c20.description = "Riesige verheerende Explosion!\n+75px Explosion Radius, +60% Damage, -30% Fire Rate"
	c20.rarity = "Epic"
	c20.color = Color(0.95, 0.3, 0.0)
	c20.explosion_radius_add = 75.0
	c20.damage_mult = 1.60
	c20.fire_rate_mult = 1.30
	_register(c20)

	# 21. Kamikaze Soul (Legendary)
	var c21 = CardData.new()
	c21.id = "kamikaze"
	c21.title = "Martyrdom Shockwave"
	c21.description = "Beim K.O. explodierst du in einer gigantischen Schockwelle, die dem Gegner schweren Schaden zufügt!"
	c21.rarity = "Legendary"
	c21.color = Color(1.0, 0.8, 0.1)
	c21.kamikaze = true
	_register(c21)

	# 22. Chronos Drive (Legendary)
	var c22 = CardData.new()
	c22.id = "chronos_drive"
	c22.title = "Chronos Drive"
	c22.description = "Meister der Dimensionen.\n-50% Dash Cooldown, +2 Extra Air Jumps, +25% Move Speed"
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
	var n1 = CardData.new()
	n1.id = "vitaler_kern"
	n1.title = "Vitaler Kern"
	n1.description = "Mehr Lebensenergie.\n+30 Max HP."
	n1.rarity = "Common"
	n1.color = Color(0.35, 0.85, 0.45)
	n1.max_hp_flat = 30
	_register(n1)

	var n2 = CardData.new()
	n2.id = "robuster_koerper"
	n2.title = "Robuster Körper"
	n2.description = "Zäher und ausdauernder.\n+18% Max HP."
	n2.rarity = "Common"
	n2.color = Color(0.25, 0.75, 0.40)
	n2.max_hp_mult = 1.18
	_register(n2)

	var n3 = CardData.new()
	n3.id = "leichtfuessig"
	n3.title = "Leichtfüßig"
	n3.description = "Leichter und flinker.\n+5% Bewegungstempo, -10% Schwerkraft."
	n3.rarity = "Common"
	n3.color = Color(0.35, 0.85, 0.90)
	n3.move_speed_mult = 1.05
	n3.gravity_mult = 0.90
	_register(n3)

	var n4 = CardData.new()
	n4.id = "windschuhe"
	n4.title = "Windschuhe"
	n4.description = "Leichte-Schuhe-Ausbau: Flott unterwegs.\n+18% Bewegungstempo, +10% Sprungkraft."
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
	n6.title = "Wuchtgeschoss"
	n6.description = "Schwerer Einschlag.\n+30% Schaden, -8% Projektilgeschwindigkeit."
	n6.rarity = "Common"
	n6.color = Color(0.85, 0.35, 0.20)
	n6.damage_mult = 1.30
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

	var n8 = CardData.new()
	n8.id = "gummigeschoss"
	n8.title = "Gummigeschoss"
	n8.description = "Springt weiter und schneller.\n+1 Abpraller, +10% Projektilgeschwindigkeit."
	n8.rarity = "Common"
	n8.color = Color(0.65, 0.90, 0.30)
	n8.bounces_add = 1
	n8.bullet_speed_mult = 1.10
	_register(n8)

	# --- Uncommon ---
	var n9 = CardData.new()
	n9.id = "regenerationsserum"
	n9.title = "Regenerationsserum"
	n9.description = "Heilt 1,5 HP pro Sekunde, wenn du 3s keinen Schaden nimmst."
	n9.rarity = "Uncommon"
	n9.color = Color(0.20, 0.95, 0.55)
	n9.hp_regen_add = 1.5
	_register(n9)

	var n10 = CardData.new()
	n10.id = "heilende_haende"
	n10.title = "Heilende Hände"
	n10.description = "Heilt 2,5 HP pro Sekunde, auch während du Schaden nimmst.\n-8% Schaden."
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
	n12.title = "Vampirklinge"
	n12.description = "Starker Lebensraub.\n+18% Lebensraub, -10% Max HP."
	n12.rarity = "Uncommon"
	n12.color = Color(0.70, 0.10, 0.25)
	n12.lifesteal_percent_add = 0.18
	n12.max_hp_mult = 0.90
	_register(n12)

	var n13 = CardData.new()
	n13.id = "kompakte_statur"
	n13.title = "Kompakte Statur"
	n13.description = "Schwerer zu treffen.\n15% kleinere Spielfigur, +8% Bewegungstempo."
	n13.rarity = "Uncommon"
	n13.color = Color(0.55, 0.80, 1.00)
	n13.body_size_mult = 0.85
	n13.move_speed_mult = 1.08
	_register(n13)

	var n14 = CardData.new()
	n14.id = "schlanker_koerper"
	n14.title = "Schlanker Körper"
	n14.description = "Kleineres Ziel.\n20% kleinere Spielfigur, +10% Sprungkraft."
	n14.rarity = "Uncommon"
	n14.color = Color(0.45, 0.70, 0.95)
	n14.body_size_mult = 0.80
	n14.jump_force_mult = 1.10
	_register(n14)

	var n15 = CardData.new()
	n15.id = "zwillingsschuss"
	n15.title = "Zwillingsschuss"
	n15.description = "Feuert ein zusätzliches Projektil.\n+1 Projektil, -20% Schaden pro Kugel."
	n15.rarity = "Uncommon"
	n15.color = Color(0.55, 0.85, 1.00)
	n15.multishot_add = 1
	n15.spread_angle_deg = 8.0
	n15.damage_mult = 0.80
	_register(n15)

	var n16 = CardData.new()
	n16.id = "splitterladung"
	n16.title = "Splitterladung"
	n16.description = "Breitere Salve.\n+1 Projektil, +10% Projektilgeschwindigkeit, -25% Schaden pro Kugel."
	n16.rarity = "Uncommon"
	n16.color = Color(0.70, 0.75, 1.00)
	n16.multishot_add = 1
	n16.spread_angle_deg = 12.0
	n16.bullet_speed_mult = 1.10
	n16.damage_mult = 0.75
	_register(n16)

	var n17 = CardData.new()
	n17.id = "hochgeschwindigkeitsmunition"
	n17.title = "Hochgeschwindigkeitsmunition"
	n17.description = "Geschosse erreichen den Gegner schneller.\n+30% Projektilgeschwindigkeit."
	n17.rarity = "Uncommon"
	n17.color = Color(0.25, 0.85, 1.00)
	n17.bullet_speed_mult = 1.30
	_register(n17)

	var n18 = CardData.new()
	n18.id = "railgun_munition"
	n18.title = "Railgun-Munition"
	n18.description = "Extrem schnelle Geschosse.\n+45% Projektilgeschwindigkeit, +8% Schaden."
	n18.rarity = "Uncommon"
	n18.color = Color(0.30, 0.90, 0.95)
	n18.bullet_speed_mult = 1.45
	n18.damage_mult = 1.08
	_register(n18)

	var n19 = CardData.new()
	n19.id = "dreifacher_abpraller"
	n19.title = "Dreifacher Abpraller"
	n19.description = "Mehr Winkel, mehr Treffer.\n+3 Abpraller."
	n19.rarity = "Uncommon"
	n19.color = Color(0.75, 0.90, 0.30)
	n19.bounces_add = 3
	_register(n19)

	var n20 = CardData.new()
	n20.id = "flipper_modus"
	n20.title = "Flipper-Modus"
	n20.description = "Geschosse tanzen durch die Arena.\n+3 Abpraller, +12% Projektilgeschwindigkeit."
	n20.rarity = "Uncommon"
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
	n21.title = "Giftklinge"
	n21.description = "Stärkeres Gift.\n+50% Gift-Schaden, +2 Gift-Stapel."
	n21.rarity = "Rare"
	n21.color = Color(0.45, 0.95, 0.25)
	n21.poison_damage_mult = 1.50
	n21.poison_stacks_add = 2
	_register(n21)

	var n22 = CardData.new()
	n22.id = "aetzende_salve"
	n22.title = "Ätzende Salve"
	n22.description = "Verätzt den Gegner.\n+75% Gift-Schaden, +1 Gift-Stapel."
	n22.rarity = "Rare"
	n22.color = Color(0.30, 1.00, 0.15)
	n22.poison_damage_mult = 1.75
	n22.poison_stacks_add = 1
	_register(n22)

	var n23 = CardData.new()
	n23.id = "giftkern"
	n23.title = "Giftkern"
	n23.description = "Länger anhaltendes Gift.\n+2 Gift-Stapel, +35% Gift-Schaden."
	n23.rarity = "Rare"
	n23.color = Color(0.55, 0.90, 0.20)
	n23.poison_stacks_add = 2
	n23.poison_damage_mult = 1.35
	_register(n23)

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
	n26.description = "Deutlich schneller.\n+25% Bewegungstempo."
	n26.rarity = "Rare"
	n26.color = Color(0.30, 0.90, 0.80)
	n26.move_speed_mult = 1.25
	_register(n26)

	var n27 = CardData.new()
	n27.id = "blitzfuesse"
	n27.title = "Blitzfüße"
	n27.description = "Maximale Mobilität.\n+35% Bewegungstempo, -10% Max HP."
	n27.rarity = "Rare"
	n27.color = Color(0.20, 0.80, 1.00)
	n27.move_speed_mult = 1.35
	n27.max_hp_mult = 0.90
	_register(n27)

	var n28 = CardData.new()
	n28.id = "doppelsprung"
	n28.title = "Doppelsprung"
	n28.description = "Ein zusätzlicher Sprung in der Luft.\n+1 Luft-Sprung."
	n28.rarity = "Rare"
	n28.color = Color(0.80, 0.80, 1.00)
	n28.extra_jumps_add = 1
	_register(n28)

	var n29 = CardData.new()
	n29.id = "luftakrobat"
	n29.title = "Luftakrobat"
	n29.description = "Noch mehr Kontrolle in der Luft.\n+1 Luft-Sprung, +15% Sprungkraft."
	n29.rarity = "Rare"
	n29.color = Color(0.65, 0.90, 1.00)
	n29.extra_jumps_add = 1
	n29.jump_force_mult = 1.15
	_register(n29)

	var n30 = CardData.new()
	n30.id = "flipper_frenzy"
	n30.title = "Flipper-Frenzy"
	n30.description = "Geschosse springen unermüdlich.\n+5 Abpraller."
	n30.rarity = "Rare"
	n30.color = Color(0.90, 0.30, 0.90)
	n30.bounces_add = 5
	_register(n30)

	var n31 = CardData.new()
	n31.id = "ricochet_kern"
	n31.title = "Ricochet-Kern"
	n31.description = "Schnelle Abpraller.\n+5 Abpraller, +15% Projektilgeschwindigkeit."
	n31.rarity = "Rare"
	n31.color = Color(0.80, 0.40, 1.00)
	n31.bounces_add = 5
	n31.bullet_speed_mult = 1.15
	_register(n31)

	var n32 = CardData.new()
	n32.id = "flummi_kern"
	n32.title = "Flummi-Kern"
	n32.description = "Große, springende Geschosse.\n+5 Abpraller, +10% Projektilgröße."
	n32.rarity = "Rare"
	n32.color = Color(0.95, 0.50, 0.95)
	n32.bounces_add = 5
	n32.bullet_size_mult = 1.10
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
	tb1.description = "Spezialfähigkeit platziert zusätzlich einen Turm, der automatisch Gegner angreift."
	tb1.rarity = "Epic"
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
	tp1.description = "Turm-Karte: Deine Türme erhalten +75 Leben."
	tp1.rarity = "Rare"
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
	gb1.description = "Geschosse vergiften Gegner.\n+2 Gift-Stapel, +25% Gift-Schaden."
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
	i1.description = "Ignis: +20% Tempo, -20% Dash-Cooldown, +15% Sprungkraft."
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
	i3.description = "Ignis: +30% Feuerrate, +25% Projektilgeschwindigkeit, -15% Ability-Cooldown."
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
	v1.description = "Volt: -25% Ability-Cooldown, +15% Tempo, +20% Feuerrate."
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
	_register(v2)

	var v3 = CardData.new()
	v3.id = "volt_kinetic_charge"
	v3.title = "Kinetische Ladung"
	v3.description = "Volt: -35% Dash-Cooldown, +1 Luft-Sprung, +20% Tempo."
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
	s1.description = "Spore: +4 Gift-Stapel, +15% Schaden."
	s1.rarity = "Rare"
	s1.color = Color(0.35, 0.95, 0.25)
	s1.hero_id = "spore"
	s1.poison_stacks_add = 4
	s1.damage_mult = 1.15
	_register(s1)

	var s2 = CardData.new()
	s2.id = "spore_mycelium"
	s2.title = "Mycelnetz"
	s2.description = "Spore: +35 Max HP, +25 Schild, +20% Schild-Regeneration."
	s2.rarity = "Rare"
	s2.color = Color(0.45, 0.85, 0.35)
	s2.hero_id = "spore"
	s2.max_hp_flat = 35
	s2.shield_max_add = 25
	s2.shield_regen_mult = 1.20
	_register(s2)

	var s3 = CardData.new()
	s3.id = "spore_toxic_bloom"
	s3.title = "Toxische Blüte"
	s3.description = "Spore: +3 Gift-Stapel, +45px Explosionsradius, +15% Lebensraub."
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
	bc1.title = "Zäher Kern"
	bc1.description = "Robuster Körperbau.\n+12% Max HP."
	bc1.rarity = "Common"
	bc1.color = Color(0.30, 0.80, 0.42)
	bc1.max_hp_mult = 1.12
	_register(bc1)

	var bc2 = CardData.new()
	bc2.id = "ausdauer_lunge"
	bc2.title = "Ausdauerlunge"
	bc2.description = "Mehr Sprungkraft.\n+12% Sprungkraft."
	bc2.rarity = "Common"
	bc2.color = Color(0.60, 0.85, 0.55)
	bc2.jump_force_mult = 1.12
	_register(bc2)

	var bc3 = CardData.new()
	bc3.id = "leichte_schuhe"
	bc3.title = "Leichte Schuhe"
	bc3.description = "Flotter unterwegs.\n+10% Bewegungstempo."
	bc3.rarity = "Common"
	bc3.color = Color(0.35, 0.80, 0.90)
	bc3.move_speed_mult = 1.10
	_register(bc3)

	var bc4 = CardData.new()
	bc4.id = "scharfschuetze"
	bc4.title = "Scharfschütze"
	bc4.description = "Schnellere Geschosse.\n+12% Projektilgeschwindigkeit."
	bc4.rarity = "Common"
	bc4.color = Color(0.30, 0.85, 0.95)
	bc4.bullet_speed_mult = 1.12
	_register(bc4)

	var bc5 = CardData.new()
	bc5.id = "grosses_magazin"
	bc5.title = "Großes Magazin"
	bc5.description = "Mehr Munition.\n+1 Max Munition."
	bc5.rarity = "Common"
	bc5.color = Color(0.90, 0.75, 0.30)
	bc5.max_ammo_add = 1
	_register(bc5)

	var bc6 = CardData.new()
	bc6.id = "schnelle_haende"
	bc6.title = "Schnelle Hände"
	bc6.description = "Zügigerer Abzug.\n+12% Feuerrate."
	bc6.rarity = "Common"
	bc6.color = Color(0.95, 0.65, 0.25)
	bc6.fire_rate_mult = 0.88
	_register(bc6)

	var bc7 = CardData.new()
	bc7.id = "federkern"
	bc7.title = "Federkern"
	bc7.description = "Kürzere Erholung.\n-12% Dash-Cooldown."
	bc7.rarity = "Common"
	bc7.color = Color(0.85, 0.80, 0.40)
	bc7.dash_cooldown_mult = 0.88
	_register(bc7)

	var bc8 = CardData.new()
	bc8.id = "panzerplatte"
	bc8.title = "Panzerplatte"
	bc8.description = "Extra Schutz.\n+12 Schild."
	bc8.rarity = "Common"
	bc8.color = Color(0.45, 0.70, 0.95)
	bc8.shield_max_add = 12
	_register(bc8)

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
	bc10.title = "Stabilisator"
	bc10.description = "Etwas mehr Abpraller.\n+1 Abpraller, +8% Projektilgröße."
	bc10.rarity = "Common"
	bc10.color = Color(0.70, 0.85, 0.35)
	bc10.bounces_add = 1
	bc10.bullet_size_mult = 1.08
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
	bc12.description = "Schwaches Gift.\n+1 Gift-Stapel, +10% Giftschaden."
	bc12.rarity = "Common"
	bc12.color = Color(0.45, 0.90, 0.30)
	bc12.poison_stacks_add = 1
	bc12.poison_damage_mult = 1.10
	_register(bc12)

	var bc13 = CardData.new()
	bc13.id = "wendig"
	bc13.title = "Wendig"
	bc13.description = "Beweglich in alle Richtungen.\n+8% Tempo, +6% Sprungkraft."
	bc13.rarity = "Common"
	bc13.color = Color(0.40, 0.85, 0.75)
	bc13.move_speed_mult = 1.08
	bc13.jump_force_mult = 1.06
	_register(bc13)

	var bc14 = CardData.new()
	bc14.id = "kompaktkern"
	bc14.title = "Kompaktkern"
	bc14.description = "Kleineres Ziel.\n10% kleinere Spielfigur."
	bc14.rarity = "Common"
	bc14.color = Color(0.55, 0.75, 0.95)
	bc14.body_size_mult = 0.90
	_register(bc14)

	var bc15 = CardData.new()
	bc15.id = "treffsicher"
	bc15.title = "Treffsicher"
	bc15.description = "Kräftigere Treffer.\n+10% Schaden."
	bc15.rarity = "Common"
	bc15.color = Color(0.95, 0.45, 0.30)
	bc15.damage_mult = 1.10
	_register(bc15)

	var bc16 = CardData.new()
	bc16.id = "ausweichrolle"
	bc16.title = "Ausweichrolle"
	bc16.description = "Schneller wieder bereit.\n-15% Dash-Cooldown, +6% Tempo."
	bc16.rarity = "Common"
	bc16.color = Color(0.75, 0.85, 0.45)
	bc16.dash_cooldown_mult = 0.85
	bc16.move_speed_mult = 1.06
	bc16.required_mechanic = "dash"
	_register(bc16)

	var bc17 = CardData.new()
	bc17.id = "hartschale"
	bc17.title = "Hartschale"
	bc17.description = "Mehr Schild.\n+20 Schild."
	bc17.rarity = "Common"
	bc17.color = Color(0.40, 0.65, 0.90)
	bc17.shield_max_add = 20
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
	bc19.description = "Leicht und schnell.\n+8% Tempo, 5% kleinere Spielfigur."
	bc19.rarity = "Common"
	bc19.color = Color(0.50, 0.80, 0.95)
	bc19.move_speed_mult = 1.08
	bc19.body_size_mult = 0.95
	_register(bc19)

	var bc20 = CardData.new()
	bc20.id = "durchschlag"
	bc20.title = "Durchschlag"
	bc20.description = "Durchschlagskraft.\n+1 Durchschlag."
	bc20.rarity = "Common"
	bc20.color = Color(0.80, 0.50, 0.85)
	bc20.piercing_add = 1
	_register(bc20)

	# --- Uncommon ---
	var bu1 = CardData.new()
	bu1.id = "lebensquell"
	bu1.title = "Lebensquell"
	bu1.description = "Deutlich mehr Leben.\n+20% Max HP."
	bu1.rarity = "Uncommon"
	bu1.color = Color(0.25, 0.90, 0.50)
	bu1.max_hp_mult = 1.20
	_register(bu1)

	var bu2 = CardData.new()
	bu2.id = "regenerations_modul"
	bu2.title = "Regenerationsmodul"
	bu2.description = "Heilt 1 HP/s nach 3s ohne Schaden."
	bu2.rarity = "Uncommon"
	bu2.color = Color(0.20, 0.95, 0.60)
	bu2.hp_regen_add = 1.0
	_register(bu2)

	var bu3 = CardData.new()
	bu3.id = "schildverstaerker"
	bu3.title = "Schildverstärker"
	bu3.description = "Massiver Schild.\n+30 Schild."
	bu3.rarity = "Uncommon"
	bu3.color = Color(0.30, 0.60, 1.00)
	bu3.shield_max_add = 30
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

	var bu5 = CardData.new()
	bu5.id = "wirbelsturm"
	bu5.title = "Wirbelsturm"
	bu5.description = "Schnelle Abpraller.\n+1 Abpraller, +15% Projektilgeschwindigkeit."
	bu5.rarity = "Uncommon"
	bu5.color = Color(0.60, 0.90, 0.40)
	bu5.bounces_add = 1
	bu5.bullet_speed_mult = 1.15
	_register(bu5)

	var bu6 = CardData.new()
	bu6.id = "leichte_schrotflinte"
	bu6.title = "Leichte Schrotflinte"
	bu6.description = "Extra Projektil.\n+1 Projektil, -15% Schaden pro Kugel."
	bu6.rarity = "Uncommon"
	bu6.color = Color(0.90, 0.60, 0.45)
	bu6.multishot_add = 1
	bu6.spread_angle_deg = 10.0
	bu6.damage_mult = 0.85
	_register(bu6)

	var bu7 = CardData.new()
	bu7.id = "explosionswelle"
	bu7.title = "Explosionswelle"
	bu7.description = "Größere Explosionen.\n+25px Explosionsradius."
	bu7.rarity = "Uncommon"
	bu7.color = Color(1.00, 0.55, 0.20)
	bu7.explosion_radius_add = 25.0
	_register(bu7)

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
	bu9.description = "Mehr Gift.\n+2 Gift-Stapel."
	bu9.rarity = "Uncommon"
	bu9.color = Color(0.45, 0.95, 0.25)
	bu9.poison_stacks_add = 2
	_register(bu9)

	var bu10 = CardData.new()
	bu10.id = "halsabschneider"
	bu10.title = "Halsabschneider"
	bu10.description = "Durchschlägt mehrere Gegner.\n+2 Durchschlag."
	bu10.rarity = "Uncommon"
	bu10.color = Color(0.85, 0.40, 0.90)
	bu10.piercing_add = 2
	_register(bu10)

	var bu11 = CardData.new()
	bu11.id = "raketenschuh"
	bu11.title = "Raketenschuh"
	bu11.description = "Noch ein Luftsprung.\n+1 Luft-Sprung, +12% Sprungkraft."
	bu11.rarity = "Uncommon"
	bu11.color = Color(0.80, 0.80, 1.00)
	bu11.extra_jumps_add = 1
	bu11.jump_force_mult = 1.12
	_register(bu11)

	var bu12 = CardData.new()
	bu12.id = "schwarzes_herz"
	bu12.title = "Schwarzes Herz"
	bu12.description = "Viel Leben, etwas langsamer.\n+15% Max HP, -6% Tempo."
	bu12.rarity = "Uncommon"
	bu12.color = Color(0.70, 0.30, 0.55)
	bu12.max_hp_mult = 1.15
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
	no2.description = "Nova: -20% Ability-Cooldown, +12% Projektilgeschwindigkeit."
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
	kl2.description = "Klinge: -30% Dash-Cooldown, +12% Tempo."
	kl2.rarity = "Rare"
	kl2.color = Color(1.0, 0.45, 0.65)
	kl2.hero_id = "klinge"
	kl2.dash_cooldown_mult = 0.70
	kl2.move_speed_mult = 1.12
	_register(kl2)

	var kl3 = CardData.new()
	kl3.id = "klinge_duell"
	kl3.title = "Duellklinge"
	kl3.description = "Klinge: +40 Max HP, +15% Lebensraub, +10% Schaden."
	kl3.rarity = "Epic"
	kl3.color = Color(1.0, 0.25, 0.45)
	kl3.hero_id = "klinge"
	kl3.max_hp_flat = 40
	kl3.lifesteal_percent_add = 0.15
	kl3.damage_mult = 1.10
	_register(kl3)

	# --- Bastion: Field Engineer ---
	var ba1 = CardData.new()
	ba1.id = "bastion_energieschild"
	ba1.title = "Energieschild"
	ba1.description = "Bastion: +40 Schild, +25% Schild-Regeneration."
	ba1.rarity = "Rare"
	ba1.color = Color(0.30, 0.90, 0.70)
	ba1.hero_id = "bastion"
	ba1.shield_max_add = 40
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
	ba3.title = "Bastionsfestung"
	ba3.description = "Bastion: +60 Schild, +25 Max HP, -10% Tempo."
	ba3.rarity = "Epic"
	ba3.color = Color(0.25, 0.95, 0.80)
	ba3.hero_id = "bastion"
	ba3.shield_max_add = 60
	ba3.max_hp_flat = 25
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
	_register(ph1)

	var ph2 = CardData.new()
	ph2.id = "phantom_sprungkraft"
	ph2.title = "Schattensprung"
	ph2.description = "Phantom: -25% Ability-Cooldown, +1 Luft-Sprung."
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
	bl2.description = "Schneller wieder bereit.\n-15% Block-Cooldown."
	bl2.rarity = "Common"
	bl2.color = Color(0.35, 0.75, 0.95)
	bl2.block_cooldown_mult = 0.85
	_register(bl2)

	# --- Uncommon ---
	var bl3 = CardData.new()
	bl3.id = "verstaerkte_deckung"
	bl3.title = "Verstärkte Deckung"
	bl3.description = "Längere Schadensimmunität.\n+0,2s Blockdauer."
	bl3.rarity = "Uncommon"
	bl3.color = Color(0.40, 0.70, 1.00)
	bl3.block_duration_add = 0.20
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
	bl6.description = "Block erzeugt ein Heilfeld.\nHeilt 6 HP pro 0,5s für 2,5s."
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
	bl8.title = "Ausdauerblock"
	bl8.description = "Länger und öfter blocken.\n+0,3s Dauer, -10% Cooldown."
	bl8.rarity = "Rare"
	bl8.color = Color(0.50, 0.85, 0.95)
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
	bl10.description = "Meisterhafte Deckung.\n-30% Block-Cooldown, +0,2s Dauer."
	bl10.rarity = "Epic"
	bl10.color = Color(0.45, 0.75, 1.00)
	bl10.block_cooldown_mult = 0.70
	bl10.block_duration_add = 0.20
	_register(bl10)

	var bl11 = CardData.new()
	bl11.id = "unzerbrechlich"
	bl11.title = "Unzerbrechlich"
	bl11.description = "Deutlich längere Deckung.\n+0,4s Blockdauer, -10% Cooldown."
	bl11.rarity = "Epic"
	bl11.color = Color(0.55, 0.65, 0.90)
	bl11.block_duration_add = 0.40
	bl11.block_cooldown_mult = 0.90
	_register(bl11)

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
	of2.description = "Durchschlägt Gegner und Deckung.\n+30% Schaden, +1 Durchschlag, -10% Geschwindigkeit."
	of2.rarity = "Rare"
	of2.pool = "Offensive"
	of2.color = Color(1.00, 0.55, 0.20)
	of2.damage_mult = 1.30
	of2.piercing_add = 1
	of2.bullet_speed_mult = 0.90
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
	df1.title = "Sanitäter"
	df1.description = "Regeneration nach kurzer Pause.\n+1,2 HP/s, +15 Max HP."
	df1.rarity = "Uncommon"
	df1.pool = "Defensive"
	df1.color = Color(0.35, 1.00, 0.55)
	df1.hp_regen_add = 1.2
	df1.max_hp_flat = 15
	_register(df1)

	var df2 = CardData.new()
	df2.id = "bollwerk"
	df2.title = "Bollwerk"
	df2.description = "Mehr Schild und längere Deckung.\n+30 Schild, +0,15s Blockdauer."
	df2.rarity = "Rare"
	df2.pool = "Defensive"
	df2.color = Color(0.40, 0.75, 1.00)
	df2.shield_max_add = 30
	df2.block_duration_add = 0.15
	_register(df2)

	var df3 = CardData.new()
	df3.id = "zweites_herz"
	df3.title = "Zweites Herz"
	df3.description = "Deutlich mehr Lebensraum.\n+50 Max HP, +0,5 HP/s Regeneration."
	df3.rarity = "Epic"
	df3.pool = "Defensive"
	df3.color = Color(1.00, 0.30, 0.45)
	df3.max_hp_flat = 50
	df3.hp_regen_add = 0.5
	_register(df3)

	# --- Tank-Panzerung: Evolutionsbaum ---
	# Die Grundkarte teilt sich in einen prozentualen Lebens-/Rüstungszweig (A)
	# und einen Reflexionszweig (B). Jede Seltenheit ist im Baum vertreten.
	var tk1 = CardData.new()
	tk1.id = "tankplatte"
	tk1.title = "Tankplatte"
	tk1.description = "Mehr Leben und eine erste Panzerung.\n+30 Max HP, +5% Rüstung."
	tk1.rarity = "Common"
	tk1.pool = "Defensive"
	tk1.color = Color(0.45, 0.72, 0.55)
	tk1.family_id = "tank_panzerung"
	tk1.max_hp_flat = 30
	tk1.armor_percent_add = 0.05
	_register(tk1)

	var tk2 = CardData.new()
	tk2.id = "tank_stahlhaut"
	tk2.title = "Stahlhaut"
	tk2.description = "Prozentual mehr Leben und stärkere Panzerung.\n+18% Max HP, +6% Rüstung."
	tk2.rarity = "Uncommon"
	tk2.color = Color(0.40, 0.80, 0.55)
	tk2.family_id = "tank_panzerung"
	tk2.parent_card_id = "tankplatte"
	tk2.evolution_branch = "A"
	tk2.max_hp_mult = 1.18
	tk2.armor_percent_add = 0.06
	_register(tk2)

	var tk3 = CardData.new()
	tk3.id = "tank_dornenhaut"
	tk3.title = "Dornenhaut"
	tk3.description = "Gepanzerte Stacheln werfen Schaden zurück.\n+25 Max HP, +8% Rüstung, 8% Schadensreflexion."
	tk3.rarity = "Uncommon"
	tk3.color = Color(0.55, 0.65, 0.35)
	tk3.family_id = "tank_panzerung"
	tk3.parent_card_id = "tankplatte"
	tk3.evolution_branch = "B"
	tk3.max_hp_flat = 25
	tk3.armor_percent_add = 0.08
	tk3.damage_reflect_percent_add = 0.08
	_register(tk3)

	var tk4 = CardData.new()
	tk4.id = "tank_festungspanzer"
	tk4.title = "Festungspanzer"
	tk4.description = "Schwerer Prozent-Lebenspanzer.\n+25% Max HP, +10% Rüstung, -5% Tempo."
	tk4.rarity = "Rare"
	tk4.color = Color(0.35, 0.65, 0.45)
	tk4.family_id = "tank_panzerung"
	tk4.parent_card_id = "tank_stahlhaut"
	tk4.evolution_branch = "A"
	tk4.max_hp_mult = 1.25
	tk4.armor_percent_add = 0.10
	tk4.move_speed_mult = 0.95
	_register(tk4)

	var tk5 = CardData.new()
	tk5.id = "tank_reflektorplatte"
	tk5.title = "Reflektorplatte"
	tk5.description = "Leitet einen Teil des Schadens zurück.\n+40 Max HP, +12% Rüstung, 12% Schadensreflexion."
	tk5.rarity = "Rare"
	tk5.color = Color(0.55, 0.55, 0.85)
	tk5.family_id = "tank_panzerung"
	tk5.parent_card_id = "tank_dornenhaut"
	tk5.evolution_branch = "B"
	tk5.max_hp_flat = 40
	tk5.armor_percent_add = 0.12
	tk5.damage_reflect_percent_add = 0.12
	_register(tk5)

	var tk6 = CardData.new()
	tk6.id = "tank_titanenbollwerk"
	tk6.title = "Titanenbollwerk"
	tk6.description = "Massiver Lebens- und Panzerturm.\n+25% Max HP, +12% Rüstung, 10% Schadensreflexion, -8% Tempo."
	tk6.rarity = "Epic"
	tk6.color = Color(0.45, 0.55, 0.35)
	tk6.family_id = "tank_panzerung"
	tk6.parent_card_id = "tank_festungspanzer"
	tk6.evolution_branch = "A"
	tk6.max_hp_mult = 1.25
	tk6.armor_percent_add = 0.12
	tk6.damage_reflect_percent_add = 0.10
	tk6.move_speed_mult = 0.92
	_register(tk6)

	var tk7 = CardData.new()
	tk7.id = "tank_spiegelpanzer"
	tk7.title = "Spiegelpanzer"
	tk7.description = "Spiegelt Angriffe mit voller Wucht.\n+50 Max HP, +14% Rüstung, 18% Schadensreflexion."
	tk7.rarity = "Epic"
	tk7.color = Color(0.60, 0.45, 0.90)
	tk7.family_id = "tank_panzerung"
	tk7.parent_card_id = "tank_reflektorplatte"
	tk7.evolution_branch = "B"
	tk7.max_hp_flat = 50
	tk7.armor_percent_add = 0.14
	tk7.damage_reflect_percent_add = 0.18
	_register(tk7)

	var tk8 = CardData.new()
	tk8.id = "tank_ewige_bastion"
	tk8.title = "Ewige Bastion"
	tk8.description = "Unerschütterlicher Koloss aus Leben und Stahl.\n+35% Max HP, +18% Rüstung, 15% Schadensreflexion, -10% Tempo."
	tk8.rarity = "Legendary"
	tk8.color = Color(0.95, 0.78, 0.30)
	tk8.family_id = "tank_panzerung"
	tk8.parent_card_id = "tank_titanenbollwerk"
	tk8.evolution_branch = "A"
	tk8.max_hp_mult = 1.35
	tk8.armor_percent_add = 0.18
	tk8.damage_reflect_percent_add = 0.15
	tk8.move_speed_mult = 0.90
	_register(tk8)

	var tk9 = CardData.new()
	tk9.id = "tank_spiegelkoloss"
	tk9.title = "Spiegelkoloss"
	tk9.description = "Ein wandelnder Spiegel, der Schaden zurückwirft.\n+60 Max HP, +16% Rüstung, 22% Schadensreflexion."
	tk9.rarity = "Legendary"
	tk9.color = Color(0.90, 0.65, 1.00)
	tk9.family_id = "tank_panzerung"
	tk9.parent_card_id = "tank_spiegelpanzer"
	tk9.evolution_branch = "B"
	tk9.max_hp_flat = 60
	tk9.armor_percent_add = 0.16
	tk9.damage_reflect_percent_add = 0.22
	_register(tk9)

	# Bewegung
	var mv1 = CardData.new()
	mv1.id = "federstiefel"
	mv1.title = "Federstiefel"
	mv1.description = "Höher und ein zusätzliches Mal springen.\n+20% Sprungkraft, +1 Sprung."
	mv1.rarity = "Uncommon"
	mv1.pool = "Bewegung"
	mv1.color = Color(0.45, 1.00, 0.70)
	mv1.jump_force_mult = 1.20
	mv1.extra_jumps_add = 1
	_register(mv1)

	var mv2 = CardData.new()
	mv2.id = "windschatten"
	mv2.title = "Windschatten"
	mv2.description = "Schneller laufen und schneller dash-en.\n+20% Tempo, -20% Dash-Cooldown."
	mv2.rarity = "Rare"
	mv2.pool = "Bewegung"
	mv2.color = Color(0.40, 0.90, 1.00)
	mv2.move_speed_mult = 1.20
	mv2.dash_cooldown_mult = 0.80
	_register(mv2)

	var mv3 = CardData.new()
	mv3.id = "leichtgewicht"
	mv3.title = "Leichtgewicht"
	mv3.description = "Kleinere Trefferfläche gegen etwas weniger Leben.\n-15% Größe, +8% Tempo, -8% Max HP."
	mv3.rarity = "Rare"
	mv3.pool = "Bewegung"
	mv3.color = Color(0.65, 0.95, 0.45)
	mv3.body_size_mult = 0.85
	mv3.move_speed_mult = 1.08
	mv3.max_hp_mult = 0.92
	_register(mv3)

	# Kern
	var core1 = CardData.new()
	core1.id = "notvorrat"
	core1.title = "Notvorrat"
	core1.description = "Mehr Munition und schnelleres Nachladen.\n+2 Munition, +15% Nachladegeschwindigkeit."
	core1.rarity = "Common"
	core1.pool = "Kern"
	core1.color = Color(0.85, 0.75, 0.45)
	core1.max_ammo_add = 2
	core1.reload_speed_mult = 1.15
	_register(core1)

	var core2 = CardData.new()
	core2.id = "fokuskristall"
	core2.title = "Fokuskristall"
	core2.description = "Fähigkeit und Feuerrate im Einklang.\n-15% Fähigkeits-Cooldown, -6% Feuerrate."
	core2.rarity = "Uncommon"
	core2.pool = "Kern"
	core2.color = Color(0.65, 0.65, 1.00)
	core2.ability_cooldown_mult = 0.85
	core2.fire_rate_mult = 0.94
	core2.required_mechanic = "ability"
	_register(core2)

	# Chaos
	var ch1 = CardData.new()
	ch1.id = "instabiler_kern"
	ch1.title = "Instabiler Kern"
	ch1.description = "Explodiert beim Tod, aber schnell.\n+Kamikaze, +15% Tempo, +20 Max HP."
	ch1.rarity = "Rare"
	ch1.pool = "Chaos"
	ch1.color = Color(1.00, 0.45, 0.20)
	ch1.kamikaze = true
	ch1.move_speed_mult = 1.15
	ch1.max_hp_flat = 20
	_register(ch1)

	var ch2 = CardData.new()
	ch2.id = "wandelnder_koloss"
	ch2.title = "Wandelnder Koloss"
	ch2.description = "Groß, schwer und schwer zu übersehen.\n+35% Größe, +40 Max HP, -10% Tempo."
	ch2.rarity = "Epic"
	ch2.pool = "Chaos"
	ch2.color = Color(0.80, 0.55, 0.25)
	ch2.giant_growth = 0.35
	ch2.max_hp_flat = 40
	ch2.move_speed_mult = 0.90
	_register(ch2)

func _register(card: CardData) -> void:
	if card.pool.is_empty():
		card.pool = _infer_pool(card)
	if card.required_mechanic.is_empty():
		card.required_mechanic = _infer_required_mechanic(card)
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
	if card.shield_regen_mult > 1.0 and card.shield_max_add <= 0:
		return "shield"
	if card.poison_damage_mult > 1.0 and card.poison_stacks_add <= 0 \
			and not card.poison_impact_cloud and not card.poison_trail:
		return "poison"
	if card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0:
		return "tower"
	return ""

func is_card_available_for_player(card: CardData, hero_id: String, owned_ids: Array = []) -> bool:
	if card == null:
		return false
	if not is_card_pool_enabled(card):
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

func _player_has_mechanic(mechanic: String, hero_id: String, owned_ids: Array) -> bool:
	match mechanic:
		"dash", "ability", "block", "jump":
			return true
		"shield":
			var hero: HeroData = Global.heroes.get(hero_id, null)
			if hero != null and hero.base_shield > 0:
				return true
		"poison":
			if hero_id == "spore":
				return true

	for raw_id in owned_ids:
		var owned := get_card(str(raw_id))
		if owned == null:
			continue
		match mechanic:
			"shield":
				if owned.shield_max_add > 0:
					return true
			"poison":
				if owned.poison_stacks_add > 0 or owned.poison_impact_cloud or owned.poison_trail:
					return true
			"frost":
				if owned.freeze_duration_add > 0.0 or owned.frost_nova or owned.frost_trail:
					return true
			"fire":
				if owned.fire_shot or owned.fire_impact_zone or owned.fire_trail:
					return true
			"lightning":
				if owned.lightning_shot or owned.chain_lightning or owned.lightning_zone:
					return true
			"tower":
				if owned.tower_enabled or owned.tower_auto_spawn or owned.tower_follow:
					return true
			"drone":
				if owned.drone_count_add > 0 or owned.drone_guardian \
						or owned.blocker_drone_count_add > 0 or owned.blocker_drone_heal:
					return true
	return false

func is_card_pool_enabled(card: CardData) -> bool:
	return card != null and Global.enabled_card_pools.has(card.pool)

# Ordnet Karten automatisch einem klaren Draft-Pool zu. Explizit gesetzte
# Pools (z. B. bei neuen Karten) haben Vorrang und werden hier nicht überschrieben.
func _infer_pool(card: CardData) -> String:
	if card.kamikaze or card.giant_growth > 0.0:
		return "Chaos"
	if card.max_hp_mult > 1.0 or card.max_hp_flat > 0 or card.hp_regen_add > 0.0 \
		or card.hp_regen_always_add > 0.0 \
		or card.shield_max_add > 0 or card.shield_regen_mult > 1.0 \
		or card.block_duration_add > 0.0 or card.block_cooldown_mult < 1.0 \
		or card.block_reflect_damage_add > 0.0 or card.block_knockback_radius_add > 0.0 \
		or card.block_knockback_force_add > 0.0 or card.block_bomb or card.block_heal_zone \
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
	return "Kern"

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
