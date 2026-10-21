extends Node

var all_cards: Array[CardData] = []
var cards_by_id: Dictionary = {}

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
	c4.rarity = "Common"
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
	n3.description = "Schneller auf den Beinen.\n+12% Bewegungstempo."
	n3.rarity = "Common"
	n3.color = Color(0.35, 0.85, 0.90)
	n3.move_speed_mult = 1.12
	_register(n3)

	var n4 = CardData.new()
	n4.id = "windschuhe"
	n4.title = "Windschuhe"
	n4.description = "Flott unterwegs.\n+18% Bewegungstempo, +10% Sprungkraft."
	n4.rarity = "Common"
	n4.color = Color(0.30, 0.80, 0.75)
	n4.move_speed_mult = 1.18
	n4.jump_force_mult = 1.10
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
	n10.description = "Heilt 2,5 HP pro Sekunde nach 3s ohne Schaden.\n-8% Schaden."
	n10.rarity = "Uncommon"
	n10.color = Color(0.45, 1.00, 0.65)
	n10.hp_regen_add = 2.5
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
	db3.title = "Schutzdrohne"
	db3.description = "Wächterdrohnen-Ausbau: Deine Drohnen regenerieren zusätzlich deine Lebenspunkte."
	db3.rarity = "Epic"
	db3.color = Color(0.55, 0.85, 1.00)
	db3.family_id = "waechterdrohne"
	db3.parent_card_id = "waechterdrohne"
	db3.evolution_branch = "B"
	db3.drone_guardian = true
	_register(db3)

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

	# --- Titan: Armored Brawler ---
	var t1 = CardData.new()
	t1.id = "titan_bulwark"
	t1.title = "Bollwerk"
	t1.description = "Titan: +50 Schild, +25 Max HP, -10% Tempo."
	t1.rarity = "Rare"
	t1.color = Color(0.3, 0.65, 1.0)
	t1.hero_id = "titan"
	t1.shield_max_add = 50
	t1.max_hp_flat = 25
	t1.move_speed_mult = 0.90
	_register(t1)

	var t2 = CardData.new()
	t2.id = "titan_reactive_armor"
	t2.title = "Reaktive Panzerung"
	t2.description = "Titan: +30 Schild, +60% Schild-Regeneration, +20% Max HP."
	t2.rarity = "Epic"
	t2.color = Color(0.2, 0.5, 0.9)
	t2.hero_id = "titan"
	t2.shield_max_add = 30
	t2.shield_regen_mult = 1.60
	t2.max_hp_mult = 1.20
	_register(t2)

	var t3 = CardData.new()
	t3.id = "titan_fortress"
	t3.title = "Festungsprotokoll"
	t3.description = "Titan: +1.5s Barriere-Dauer, -20% Ability-Cooldown, +15% Schaden."
	t3.rarity = "Epic"
	t3.color = Color(0.4, 0.75, 1.0)
	t3.hero_id = "titan"
	t3.barrier_duration_add = 1.5
	t3.ability_cooldown_mult = 0.80
	t3.damage_mult = 1.15
	_register(t3)

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

func _register(card: CardData) -> void:
	all_cards.append(card)
	cards_by_id[card.id] = card

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
func get_draft_offer(count: int = 5, exclude_ids: Array = [], hero_id: String = "", owned_ids: Array = []) -> Array[CardData]:
	var base_cards: Array[CardData] = []
	var upgrade_groups: Dictionary = {}

	for c in all_cards:
		if exclude_ids.has(c.id):
			continue
		if not c.hero_id.is_empty() and c.hero_id != hero_id:
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

	var selected: Array[CardData] = []
	var group_keys: Array = upgrade_groups.keys()
	group_keys.shuffle()

	# Zuerst komplette Talentbaum-Gruppen anbieten.
	for key in group_keys:
		var group: Array = upgrade_groups[key]
		if selected.size() + group.size() <= count:
			selected.append_array(group)

	# Falls das Angebot sonst leer bliebe (z. B. sehr kleines Angebot), einen
	# Teil einer Gruppe übernehmen. Das ist nur ein Notfall für count < 2.
	if selected.is_empty() and not group_keys.is_empty():
		var first_group: Array = upgrade_groups[group_keys[0]]
		for c in first_group:
			if selected.size() >= count:
				break
			selected.append(c)

	# Rest mit Grundkarten auffüllen.
	base_cards.shuffle()
	for c in base_cards:
		if selected.size() >= count:
			break
		selected.append(c)

	# Letzte Lücken mit noch nicht gewählten Ausbaukarten füllen.
	for c in all_available:
		if selected.size() >= count:
			break
		if not selected.has(c):
			selected.append(c)

	selected.shuffle()
	return selected
