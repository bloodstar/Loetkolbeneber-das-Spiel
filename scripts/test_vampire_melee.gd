extends Node2D

## Test für den Blutritter (Nahkampf-Vampir, "vampire_melee"): Blutschild bis
## 200 % HP, Blutbersten, Blutsturm durch Gegner mit Kugel an der Startstelle,
## Blutruf zieht Kugeln heran.
## Start: godot --headless --path . scenes/test_vampire_melee.tscn

const ID := "vampire_melee"

var _failed: int = 0

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _free_orbs() -> Array:
	return get_tree().get_nodes_in_group("blood_orb").filter(
		func(o): return is_instance_valid(o) and not o.is_queued_for_deletion() and o.is_free())

func _clear_orbs() -> void:
	for o in _free_orbs():
		o.take()

# Seite (links/rechts), auf der vor pos 300 px kein Gelände liegt.
func _clear_side(pos: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	for side in [1.0, -1.0]:
		var ok := true
		for dy in [-14.0, 0.0, 8.0]:
			var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0.0, dy), pos + Vector2(300.0 * side, dy), 1)
			if not space.intersect_ray(q).is_empty():
				ok = false
		if ok:
			return side
	return 1.0

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(40.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	# --- Heldendaten ---
	var hero := Global.get_hero(ID)
	_check(hero.id == ID, "Blutritter existiert")
	_check(Global.is_melee_hero(ID), "Blutritter ist Nahkämpfer")
	_check(Global.is_vampire_hero(ID), "Blutritter zählt als Vampir")
	_check(hero.has_ult(), "Blutritter hat eine Ulti")
	_check(not Global.get_hero_kit_text(hero).is_empty(), "Kit-Text vorhanden")
	_check(hero.get_ability_fingerprint().length() == 8, "Fähigkeits-Fingerabdruck berechenbar")
	_check(load("res://assets/ui/hero_vampire_melee.svg") != null, "Helden-Icon vorhanden")

	# --- Klassenkarten ---
	for id in ["vampm_aderlass", "vampm_dickes_blut", "vampm_blutgier", "vampm_blutbersten",
			"vampm_blutspende", "vampm_blutregen", "vampm_blutschneise", "vampm_blutsog"]:
		var card = CardDatabase.get_card(id)
		_check(card != null and card.hero_id == ID, "Klassenkarte %s existiert" % id)
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampm_aderlass"), ID, []), "Aderlass für den Blutritter verfügbar")
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampm_aderlass"), "vampire", []), "Aderlass nicht für den Fernkampf-Vampir")
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampm_blutspende"), ID, []), "Blutspende braucht die Grundkarte")
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("vampm_blutspende"), ID, ["vampm_blutbersten"]), "Blutspende mit Grundkarte verfügbar")

	# --- Match: Blutritter (1) gegen Volt (2) ---
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, ID)
	Global.set_player_hero(2, "volt")
	Global.set_selected_map("weite")
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
	_check(vamp.is_melee and vamp.sprite.outfit_id == ID, "Nahkampf und Outfit gesetzt")
	foe.max_health = 2000.0
	foe.current_health = 2000.0
	await _wait(0.1)
	_clear_orbs()

	# --- Passiv: Blutkugel gibt Schild, höchstens 200 % Max-HP ---
	vamp.current_shield = 0.0
	_check(vamp.on_blood_orb_pickup(null) and is_equal_approx(vamp.current_shield, Player.VAMP_MELEE_ORB_SHIELD), "Blutkugel gibt %d Schild" % int(Player.VAMP_MELEE_ORB_SHIELD))
	_check(vamp.current_health >= vamp.max_health and vamp.on_blood_orb_pickup(null), "Sammelt auch bei voller HP")
	var cap := vamp.max_health * Player.VAMP_MELEE_SHIELD_CAP
	vamp.current_shield = cap - 5.0
	vamp.on_blood_orb_pickup(null)
	_check(is_equal_approx(vamp.current_shield, cap), "Schild gedeckelt auf %d (200 %% HP)" % int(cap))
	_check(not vamp.on_blood_orb_pickup(null), "Bei vollem Blutschild bleibt die Kugel liegen")
	await _wait(0.3)
	_check(vamp.current_shield >= cap - 0.5, "Normale Schild-Logik kürzt den Blutschild nicht")

	# --- Fähigkeit: Blutbersten ---
	foe.global_position = vamp.global_position + Vector2(60.0, 0.0)
	foe.velocity = Vector2.ZERO
	foe.current_shield = 0.0
	foe.is_invulnerable = false
	var hp_before := foe.current_health
	vamp.ability_timer = 0.0
	vamp.use_ability()
	await _wait(0.05)
	var burst_dmg := hp_before - foe.current_health
	_check(absf(burst_dmg - cap) < 2.0, "Blutbersten: 1 Schaden pro Schild (%.0f bei %.0f Schild)" % [burst_dmg, cap])
	_check(vamp.current_shield <= 0.0, "Schild ist danach weg")
	_check(vamp.ability_timer > 0.0, "Blutbersten hat Abklingzeit")
	vamp.ability_timer = 0.0
	vamp.use_ability()
	_check(vamp.ability_timer <= 0.0, "Ohne Schild verpufft nichts und kein Cooldown")

	# --- Dash: Blutsturm durch den Gegner, Kugel an der Startstelle ---
	await _wait(0.6)
	_clear_orbs()
	var start := vamp.global_position
	var side := _clear_side(start)
	foe.global_position = start + Vector2(70.0 * side, 0.0)
	foe.velocity = Vector2.ZERO
	vamp.velocity = Vector2.ZERO
	vamp.aim_direction = Vector2(side, 0.0)
	vamp.dash()
	await _wait(0.05)
	var orbs := _free_orbs()
	_check(orbs.size() == 1 and orbs[0].global_position.distance_to(start) < 30.0, "Blutsturm legt eine Blutkugel an der Startstelle ab")
	await _wait(0.45)
	_check((vamp.global_position.x - start.x) * side > 110.0,
		"Blutsturm stürmt durch den Gegner (%.0f px, Gegner bei 70)" % ((vamp.global_position.x - start.x) * side))
	_check(vamp.get_collision_mask_value(2), "Nach dem Dash kollidiert er wieder mit Spielern")

	# --- Ulti: Blutruf ---
	_clear_orbs()
	await _wait(0.05)
	vamp.ult_timer = 0.0
	vamp.use_ultimate()
	_check(vamp.ult_timer <= 0.0, "Ohne Blutkugel bleibt die Ulti geladen")
	# Gegner steht zwischen Kugel und Blutritter.
	vamp.global_position = start
	vamp.velocity = Vector2.ZERO
	vamp.current_health = vamp.max_health - 50.0
	side = _clear_side(start)
	foe.global_position = start + Vector2(120.0 * side, -10.0)
	foe.velocity = Vector2.ZERO
	# Gegner bleibt stehen, damit er sicher in der Flugbahn liegt.
	foe.set_physics_process(false)
	vamp.spawn_blood_orb(start + Vector2(240.0 * side, -10.0))
	vamp.spawn_blood_orb(start + Vector2(-200.0 * side, -10.0))
	await _wait(0.05)
	foe.max_shield = 0.0
	foe.current_shield = 0.0
	hp_before = foe.current_health
	var own_before := vamp.current_health
	vamp.current_shield = 0.0
	vamp.use_ultimate()
	_check(vamp.ult_timer > 0.0, "Blutruf startet die Abklingzeit")
	_check(get_tree().get_nodes_in_group("blood_bolt").size() == 2, "Zwei Kugeln fliegen heran")
	await _wait(1.2)
	var ult_dmg := hp_before - foe.current_health
	_check(absf(ult_dmg - Player.VAMP_MELEE_ULT_DAMAGE) < 2.0, "Treffer explodiert für %d Schaden (%.0f)" % [int(Player.VAMP_MELEE_ULT_DAMAGE), ult_dmg])
	_check(vamp.current_health - own_before >= Player.VAMP_MELEE_ULT_HEAL - 1.0, "Treffer heilt den Blutritter (%.0f -> %.0f)" % [own_before, vamp.current_health])
	_check(vamp.current_shield > 0.0, "Die zweite Kugel erreicht ihn und gibt Schild")
	_check(get_tree().get_nodes_in_group("blood_bolt").is_empty(), "Keine Tropfen mehr unterwegs")
	foe.set_physics_process(true)

	# --- Evolutionen ---
	vamp.ability_evolutions = ["vampm_thick_blood", "vampm_burst_heal", "vampm_ult_more"]
	vamp.current_shield = 0.0
	vamp.on_blood_orb_pickup(null)
	_check(is_equal_approx(vamp.current_shield, Player.VAMP_MELEE_ORB_SHIELD * Player.VAMPMEVO_THICK_BLOOD_MULT), "Dickes Blut: mehr Schild pro Kugel")
	vamp.current_shield = 100.0
	vamp.current_health = 20.0
	foe.global_position = vamp.global_position + Vector2(400.0, 0.0)
	vamp.ability_timer = 0.0
	vamp.use_ability()
	_check(absf(vamp.current_health - (20.0 + 100.0 * Player.VAMPMEVO_BURST_HEAL)) < 1.0, "Blutspende heilt (%.0f HP)" % vamp.current_health)
	_clear_orbs()
	await _wait(0.05)
	vamp.spawn_blood_orb(vamp.global_position + Vector2(-Player.VAMP_MELEE_ULT_RADIUS * 1.2, -10.0))
	await _wait(0.05)
	vamp.ult_timer = 0.0
	vamp.use_ultimate()
	_check(vamp.ult_timer > 0.0, "Blutsog: Blutruf erreicht weiter entfernte Kugeln")

	print("[TEST] Fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
