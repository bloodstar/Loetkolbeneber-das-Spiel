extends Node2D

## Fokussierter Test für die Helden-Kits (Nah-/Fernkampf pro Held, Ulti auf E,
## Dash-Ladungen, Volt- und Phantom-Kit, Kartenfilter nach Angriffsart).
## Start: godot --headless --path . scenes/test_hero_kits.tscn

var _failed: int = 0

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(40.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	# --- Heldendaten ---
	_check(Global.is_melee_hero("phantom") and Global.is_melee_hero("klinge") and Global.is_melee_hero("bastion"), "Phantom, Klinge, Bastion sind Nahkämpfer")
	_check(not Global.is_melee_hero("volt") and not Global.is_melee_hero("ignis"), "Volt und Ignis sind Fernkämpfer")
	_check(Global.get_hero("volt").has_ult() and Global.get_hero("phantom").has_ult(), "Volt und Phantom haben eine Ulti")
	_check(InputMap.has_action("p1_ult") and not InputMap.has_action("p1_melee"), "E ist die Ulti-Taste")

	# --- Kartenfilter ---
	var melee_only := 0
	var ranged_only := 0
	for card in CardDatabase.all_cards:
		if card.attack_type == "melee":
			melee_only += 1
			_check(not CardDatabase.is_card_available_for_player(card, "volt", []), "Nahkampfkarte %s nicht für Volt" % card.id)
		elif card.attack_type == "ranged":
			ranged_only += 1
			if not CardDatabase.is_card_attack_type_allowed(card, "volt") or CardDatabase.is_card_attack_type_allowed(card, "phantom"):
				_check(false, "Fernkampfkarte %s falsch gefiltert" % card.id)
	print("[INFO] Karten nur Nahkampf: %d, nur Fernkampf: %d, gesamt: %d" % [melee_only, ranged_only, CardDatabase.all_cards.size()])
	_check(melee_only > 5 and ranged_only > 5, "Beide Angriffsarten haben eigene Karten")
	for hero_id in ["volt", "phantom", "klinge", "ignis"]:
		var n := 0
		for card in CardDatabase.all_cards:
			if CardDatabase.is_card_available_for_player(card, hero_id, []):
				n += 1
		print("[INFO] %s: %d Karten ohne Vorbedingung verfügbar" % [hero_id, n])
		_check(n >= 40, "%s hat einen ausreichend großen Kartenpool" % hero_id)
	for id in ["volt_sprungziel", "volt_entladung", "volt_doppelladung", "volt_starkstrom", "volt_dauerblitz", "volt_schockring",
			"phantom_sprengkoeder", "phantom_platztausch", "phantom_blutspur", "ulti_akku"]:
		_check(CardDatabase.get_card(id) != null, "Karte %s existiert" % id)
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("ulti_akku"), "volt", []), "Ulti-Akku für Volt verfügbar")
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("ulti_akku"), "ignis", []), "Ulti-Akku nicht für Helden ohne Ulti")
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("volt_kettenblink"), "volt", []), "Kettenblink braucht die Blitzschritt-Grundkarte")
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("volt_kettenblink"), "volt", ["volt_doppelladung"]), "Kettenblink mit Grundkarte verfügbar")

	# --- Match: Volt (1) gegen Phantom (2) ---
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, "volt")
	Global.set_player_hero(2, "phantom")
	Global.reset_match()
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var volt: Player = main.get_player(1)
	var phantom: Player = main.get_player(2)
	_check(volt != null and phantom != null, "Beide Spieler sind gespawnt")
	if volt == null or phantom == null:
		get_tree().quit(1)
		return
	for p in [volt, phantom]:
		p.is_bot = false
		p.control_enabled = true
		var ai = p.get_node_or_null("AIController")
		if ai:
			ai.queue_free()
	_check(not volt.is_melee and phantom.is_melee, "Angriffsart am Spieler gesetzt")
	_check(absf(volt.ult_timer - volt.ult_max_cooldown * 0.5) < 1.0, "Ulti startet halb geladen (%.1f / %.1f)" % [volt.ult_timer, volt.ult_max_cooldown])
	_check(volt.dash_charges_max == 2 and volt.dash_charges == 2, "Volt hat 2 Blitzschritt-Ladungen")

	# Volt: Blitzschritt teleportiert und verbraucht Ladungen.
	var before := volt.global_position
	volt.aim_direction = Vector2.RIGHT
	volt.dash()
	await _wait(0.1)
	_check(volt.dash_charges == 1, "Blitzschritt verbraucht eine Ladung")
	_check(volt.global_position.distance_to(before) > 20.0, "Blitzschritt bewegt Volt (%.0f px)" % volt.global_position.distance_to(before))
	volt.dash()
	await _wait(0.1)
	_check(volt.dash_charges == 0, "Zweite Ladung verbraucht")
	volt.dash()
	_check(volt.dash_charges == 0, "Ohne Ladung kein Dash")

	# Volt: Kugelblitz trifft Phantom.
	volt.max_health = 2000.0
	volt.current_health = 2000.0
	phantom.max_health = 2000.0
	phantom.current_health = 2000.0
	phantom.global_position = volt.global_position + Vector2(-30.0, 0.0)
	phantom.velocity = Vector2.ZERO
	volt.aim_direction = Vector2.LEFT
	var hp_before := phantom.current_health + phantom.current_shield
	volt.ability_timer = 0.0
	volt.use_ability()
	await _wait(0.2)
	_check(get_tree().get_nodes_in_group("net_entity").size() >= 1, "Kugelblitz existiert als Netz-Objekt")
	await _wait(1.0)
	_check(phantom.current_health + phantom.current_shield < hp_before, "Kugelblitz schockt Gegner in der Nähe")
	_check(volt.ability_timer > 0.0, "Kugelblitz hat Abklingzeit")

	# Volt: Überladung.
	volt.ult_timer = 0.0
	var speed_before := volt._current_ground_speed()
	volt.use_ultimate()
	_check(volt.overcharge_timer > 0.0, "Überladung läuft")
	_check(volt._current_ground_speed() > speed_before * 1.2, "Überladung macht schneller")
	_check(is_equal_approx(volt.ult_timer, volt.ult_max_cooldown), "Ulti-Abklingzeit startet")
	var ammo := volt.current_ammo
	volt.fire_timer = 0.0
	volt.shoot()
	_check(volt.current_ammo == ammo, "Überladung verbraucht keine Munition")
	volt.overcharge_timer = 0.0

	# Phantom: Schattenschritt macht unsichtbar.
	phantom.global_position = volt.global_position + Vector2(200.0, 0.0)
	phantom.dash()
	await _wait(0.5)
	_check(phantom.is_stealthed(), "Schattenschritt macht Phantom unsichtbar")
	await _wait(1.2)
	_check(not phantom.is_stealthed(), "Unsichtbarkeit endet wieder")

	# Phantom: Köder.
	phantom.ability_timer = 0.0
	phantom.aim_direction = Vector2.LEFT
	phantom.use_ability()
	await _wait(0.1)
	var decoys := get_tree().get_nodes_in_group("phantom_decoy")
	_check(decoys.size() == 1, "Köder gespawnt")
	_check(phantom.is_stealthed(), "Köder macht Phantom unsichtbar")
	_check(phantom.get_lure_target() != phantom, "Gegner zielen auf den Köder")
	if decoys.size() == 1:
		decoys[0].take_tower_damage(999.0, volt)
		await _wait(0.1)
		_check(get_tree().get_nodes_in_group("phantom_decoy").filter(func(d): return d.is_active()).is_empty(), "Köder platzt bei Schaden")
	phantom.stealth_timer = 0.0

	# Phantom: Nahkampf auf Linksklick, Nachtjagd verdoppelt den ersten Treffer.
	await _wait(0.3)
	volt.global_position = phantom.global_position + Vector2(24.0, 0.0)
	volt.velocity = Vector2.ZERO
	volt.is_invulnerable = false
	phantom.aim_direction = Vector2.RIGHT
	var v_before := volt.current_health + volt.current_shield
	phantom.melee_cooldown_timer = 0.0
	phantom.attack()
	await _wait(0.4)
	var normal_hit := v_before - (volt.current_health + volt.current_shield)
	_check(normal_hit > 0.0, "Phantoms Linksklick schlägt zu (%.1f Schaden)" % normal_hit)
	phantom.ult_timer = 0.0
	phantom.use_ultimate()
	_check(phantom.hunt_timer > 0.0 and phantom.is_stealthed(), "Nachtjagd läuft und macht unsichtbar")
	volt.global_position = phantom.global_position + Vector2(24.0, 0.0)
	volt.velocity = Vector2.ZERO
	v_before = volt.current_health + volt.current_shield
	phantom.melee_cooldown_timer = 0.0
	phantom.aim_direction = Vector2.RIGHT
	phantom.attack()
	await _wait(0.4)
	var hunt_hit := v_before - (volt.current_health + volt.current_shield)
	_check(hunt_hit > normal_hit * 1.5, "Erster Nachtjagd-Treffer ist stärker (%.1f statt %.1f)" % [hunt_hit, normal_hit])
	_check(phantom.hunt_timer > 0.0, "Nachtjagd bleibt nach dem Angriff aktiv")

	# Ulti-Abklingzeit bleibt über den Rundenwechsel erhalten.
	phantom.ult_timer = 11.0
	phantom._store_ult_timer()
	main._start_fresh_round()
	await _wait(0.4)
	var phantom2: Player = main.get_player(2)
	_check(phantom2 != null and absf(phantom2.ult_timer - 11.0) < 1.0, "Ulti-Abklingzeit läuft über die Runde weiter (%.1f)" % (phantom2.ult_timer if phantom2 else -1.0))

	print("[TEST] Fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
