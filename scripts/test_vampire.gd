extends Node2D

## Fokussierter Test für den Fernkampf-Vampir und die Blutkugeln.
## Start: godot --headless --path . scenes/test_vampire.tscn

var _failed: int = 0

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _orbs() -> Array:
	return BloodOrb.free_orbs(get_tree())

func _clear_orbs() -> void:
	for orb in _orbs():
		orb.take()

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(40.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	var hero := Global.get_hero("vampire")
	_check(hero.id == "vampire" and not hero.is_melee() and hero.has_ult(), "Vampir existiert, Fernkampf, mit Ulti")
	_check(Global.is_vampire_hero("vampire") and Global.is_vampire_hero("vampire_melee") and not Global.is_vampire_hero("volt"), "is_vampire_hero")
	_check(not Global.get_hero_kit_text(hero).is_empty() and Global.get_hero_ability_details(hero) != hero.ability_desc, "Kit- und Fähigkeitstexte")
	print(Global.get_hero_kit_text(hero))
	_check(hero.get_ability_fingerprint().length() == 8, "Fähigkeits-Fingerabdruck")

	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, "vampire")
	Global.set_player_hero(2, "volt")
	Global.reset_match()
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var vamp: Player = main.get_player(1)
	var foe: Player = main.get_player(2)
	_check(vamp != null and foe != null, "Beide Spieler sind gespawnt")
	if vamp == null or foe == null:
		get_tree().quit(1)
		return
	for p in [vamp, foe]:
		p.is_bot = false
		p.control_enabled = true
		var ai = p.get_node_or_null("AIController")
		if ai:
			ai.queue_free()
	await _wait(1.0)
	foe.max_health = 5000.0
	foe.current_health = 5000.0
	foe.current_shield = 0.0
	foe.max_shield = 0.0
	_check(not vamp.is_melee, "Vampir schießt")

	# Jeder 3. Angriffstreffer gibt eine kreisende Kugel, Fähigkeitsschaden zählt nicht.
	_clear_orbs()
	vamp.vampire_orbs = 0
	vamp.vampire_hit_count = 0
	foe.global_position = vamp.global_position + Vector2(300.0, 0.0)
	foe.is_invulnerable = false
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	_check(vamp.vampire_orbs == 0, "Nach 2 Treffern noch keine Kugel")
	vamp._ability_hit(foe, 5.0, Vector2.ZERO)
	_check(vamp.vampire_orbs == 0, "Fähigkeitsschaden zählt nicht")
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	_check(vamp.vampire_orbs == 1, "3. Treffer gibt eine kreisende Kugel")
	_check(_orbs().size() == 0, "Keine Kugel am Boden")
	vamp.vampire_orbs = Player.VAMPIRE_ORBIT_MAX
	_check(not vamp.vampire_add_orb() and vamp.vampire_orbs == Player.VAMPIRE_ORBIT_MAX, "Vorrat hat eine Obergrenze")
	_check(NetEntity.create_replica("bmissile") is BloodMissile, "Snapshot-Art bmissile")

	# Fremde Kugel am Boden füllt den Vorrat.
	vamp.vampire_orbs = 0
	var orb := vamp.spawn_blood_orb(vamp.global_position + Vector2(0.0, -10.0))
	await _wait(0.8)
	_check(not is_instance_valid(orb) or not orb.is_free(), "Kugel am Boden wird eingesammelt")
	_check(vamp.vampire_orbs == 1, "Eingesammelte Kugel kreist (%d)" % vamp.vampire_orbs)

	# Blutgeschosse: ohne Vorrat kein Cooldown, mit Vorrat Schaden am Gegner.
	vamp.vampire_orbs = 0
	vamp.ability_timer = 0.0
	vamp.use_ability()
	_check(vamp.ability_timer == 0.0, "Ohne Kugel keine Abklingzeit")
	foe.global_position = vamp.global_position + Vector2(220.0, 0.0)
	foe.velocity = Vector2.ZERO
	vamp.vampire_orbs = 3
	vamp.aim_direction = Vector2.RIGHT
	var hp_before := foe.current_health
	vamp.current_health = vamp.max_health - 50.0
	var vamp_hp := vamp.current_health
	vamp.use_ability()
	_check(vamp.ability_timer > 0.0, "Blutgeschosse haben Abklingzeit")
	_check(vamp.vampire_orbs == 0, "Vorrat ist verbraucht")
	await _wait(1.5)
	_check(hp_before - foe.current_health >= 13.0 * 3.0, "3 Blutgeschosse treffen (%.0f Schaden)" % (hp_before - foe.current_health))
	_check(vamp.current_health > vamp_hp, "Treffer heilen den Vampir")

	# Blutsturm: Dash gibt sofort eine Kugel.
	await _wait(0.3)
	vamp.vampire_orbs = 0
	foe.global_position = vamp.global_position + Vector2(60.0, 0.0)
	foe.velocity = Vector2.ZERO
	vamp.velocity = Vector2.ZERO
	vamp.aim_direction = Vector2.RIGHT
	hp_before = foe.current_health
	vamp.dash_charges = vamp.dash_charges_max
	vamp.dash()
	_check(vamp.vampire_orbs == 1, "Blutsturm gibt eine Kugel (%d)" % vamp.vampire_orbs)
	await _wait(0.35)
	_check(foe.current_health < hp_before, "Blutsturm trifft den Gegner")

	# Fledermausschwarm: Grundschwarm plus eine pro Kugel im Vorrat.
	foe.global_position = vamp.global_position + Vector2(200.0, 0.0)
	vamp.vampire_orbs = 3
	vamp.current_health = vamp.max_health
	vamp.ult_timer = 0.0
	hp_before = foe.current_health
	vamp.use_ultimate()
	await get_tree().process_frame
	var bats := get_tree().get_nodes_in_group(VampireBat.GROUP)
	_check(bats.size() == Player.VAMPIRE_ULT_MIN_BATS + 3, "2 + 3 Kugeln = 5 Fledermäuse (%d)" % bats.size())
	_check(vamp.vampire_orbs == 0, "Vorrat ist verbraucht")
	await _wait(2.0)
	_check(foe.current_health < hp_before, "Fledermäuse beißen (%.0f Schaden)" % (hp_before - foe.current_health))
	# Fledermäuse lassen sich abschießen.
	bats = get_tree().get_nodes_in_group(VampireBat.GROUP)
	if bats.size() > 0:
		bats[0].take_tower_damage(60.0, foe)
		await get_tree().process_frame
		_check(not is_instance_valid(bats[0]), "Fledermaus stirbt nach 50 Schaden")
	# Ohne Kugeln der Grundschwarm.
	for b in get_tree().get_nodes_in_group(VampireBat.GROUP):
		b.pop()
	vamp.ult_timer = 0.0
	vamp.use_ultimate()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(VampireBat.GROUP).size() == Player.VAMPIRE_ULT_MIN_BATS, "Ohne Kugeln 2 Fledermäuse")

	# Klassenkarten
	for id in ["vampire_blutdurst", "vampire_nachtschwinge", "vampire_blutfontaene", "vampire_blutrausch",
			"vampire_blutsturm_plus", "vampire_fledermauskoenig"]:
		var card := CardDatabase.get_card(id)
		_check(card != null and CardDatabase.is_card_available_for_player(card, "vampire", []), "Karte %s für Vampir verfügbar" % id)
		_check(card != null and not CardDatabase.is_card_available_for_player(card, "volt", []), "Karte %s nicht für Volt" % id)
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampire_aderlass"), "vampire", []), "Aderlass braucht Blutfontäne")
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampire_aderlass"), "vampire", ["vampire_blutfontaene"]), "Aderlass mit Blutfontäne verfügbar")
	# Blutreserve / Blutkrone: je +3 Plätze.
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampire_blutkrone"), "vampire", []), "Blutkrone braucht Blutreserve")
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampire_blutkrone"), "vampire", ["vampire_blutreserve"]), "Blutkrone mit Blutreserve verfügbar")
	vamp.ability_evolutions.append("vampire_orbs_more")
	_check(vamp.vampire_orbit_max() == Player.VAMPIRE_ORBIT_MAX + 3, "Blutreserve: 9 Plätze")
	vamp.ability_evolutions.append("vampire_orbs_more2")
	_check(vamp.vampire_orbit_max() == Player.VAMPIRE_ORBIT_MAX + 6, "Blutkrone: 12 Plätze")
	vamp.vampire_orbs = 11
	_check(vamp.vampire_add_orb() and not vamp.vampire_add_orb(), "Vorrat bis 12")
	vamp.ability_evolutions.erase("vampire_orbs_more")
	vamp.ability_evolutions.erase("vampire_orbs_more2")
	vamp.vampire_orbs = 0
	# Blutrausch: Kugel schon beim 2. Treffer.
	_clear_orbs()
	vamp.ability_evolutions.append("vampire_frenzy")
	vamp.vampire_hit_count = 0
	vamp.vampire_orbs = 0
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	_check(vamp.vampire_orbs == 1, "Blutrausch: Kugel beim 2. Treffer")
	# Fledermauskönig: mindestens 4.
	_clear_orbs()
	for b in get_tree().get_nodes_in_group(VampireBat.GROUP):
		b.pop()
	vamp.ability_evolutions.append("vampire_bat_king")
	vamp.vampire_orbs = 0
	vamp.ult_timer = 0.0
	vamp.use_ultimate()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(VampireBat.GROUP).size() == Player.VAMPIRE_KING_MIN_BATS, "Fledermauskönig: 4 Fledermäuse")

	print("[TEST] fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
