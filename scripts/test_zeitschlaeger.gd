extends Node2D

## Fokussierter Test für den Zeitschläger.
## Start: godot --headless --path . scenes/test_zeitschlaeger.tscn

var _failed: int = 0

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _reset(p: Player) -> void:
	p.velocity = Vector2.ZERO
	p.stun_timer = 0.0
	p.freeze_timer = 0.0
	p.time_slow_timer = 0.0
	p.time_slow_mult = 1.0

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(40.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	var hero := Global.get_hero("zeitschlaeger")
	_check(hero.id == "zeitschlaeger" and hero.is_melee() and hero.has_ult(), "Zeitschläger existiert, Nahkampf, mit Ulti")
	_check(Global.get_melee_weapon_data(hero.melee_weapon)["arc_deg"] == 360.0, "Waffe ist der Flegel (Uhrenpendel)")
	_check(Global.get_hero_ability_details(hero) != hero.ability_desc and Global.get_hero_ult_details(hero) != hero.ult_desc, "Fähigkeits- und Ultitext mit Zahlen")
	print(Global.get_hero_kit_text(hero))
	_check(hero.get_ability_fingerprint().length() == 8, "Fähigkeits-Fingerabdruck")
	_check(CardMechanics.get_hero_icon("zeitschlaeger") != null, "Klassen-Icon lädt")

	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, "zeitschlaeger")
	Global.set_player_hero(2, "volt")
	Global.reset_match()
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var zs: Player = main.get_player(1)
	var foe: Player = main.get_player(2)
	_check(zs != null and foe != null, "Beide Spieler sind gespawnt")
	if zs == null or foe == null:
		get_tree().quit(1)
		return
	for p in [zs, foe]:
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
	_check(zs.is_melee and zs.sprite.outfit_id == "zeitschlaeger", "Nahkampf und Wecker-Outfit")
	_check(absf(zs.dash_cooldown - Player.ZEIT_REWIND_COOLDOWN) < 0.01, "Rückspul hat eigene Abklingzeit")

	# Passiv: der 3. Pendeltreffer verlangsamt.
	foe.global_position = zs.global_position + Vector2(40.0, 0.0)
	_reset(foe)
	for i in range(2):
		zs.melee_cooldown_timer = 0.0
		zs.melee_attack(Vector2.RIGHT)
	_check(foe.time_slow_timer <= 0.0, "Nach 2 Treffern noch nicht verlangsamt")
	zs.melee_cooldown_timer = 0.0
	foe.global_position = zs.global_position + Vector2(40.0, 0.0)
	zs.melee_attack(Vector2.RIGHT)
	_check(foe.time_slow_timer > 0.0 and absf(foe.time_slow_mult - 0.7) < 0.01, "3. Treffer verlangsamt um 30 %% (%.2f)" % foe.time_slow_mult)
	var full_speed := foe.move_speed
	_check(absf(foe._current_ground_speed() - full_speed * 0.7) < 1.0, "Tempo sinkt auf 70 %")

	# Zeitblase: Gegner und gegnerische Kugeln darin langsam.
	_reset(foe)
	foe.global_position = zs.global_position + Vector2(60.0, 0.0)
	zs.ability_timer = 0.0
	zs.use_ability()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bubbles := get_tree().get_nodes_in_group(TimeBubble.GROUP)
	_check(bubbles.size() == 1, "Zeitblase steht")
	_check(bubbles.size() == 1 and bubbles[0].get_network_state().get("k") == "tbubble" and NetEntity.create_replica("tbubble") is TimeBubble, "Zeitblase ist Netz-Objekt")
	_check(foe.time_slow_timer > 0.0 and foe.time_slow_mult < 0.5, "Gegner in der Blase stark verlangsamt (%.2f)" % foe.time_slow_mult)
	_check(zs.time_slow_timer <= 0.0, "Zeitschläger selbst nicht verlangsamt")
	var bullet = foe._spawn_bullet(Vector2.LEFT)
	if bullet != null:
		bullet.global_position = zs.global_position + Vector2(30.0, -30.0)
		_check(absf(TimeBubble.bullet_time_scale(bullet) - Player.ZEIT_BUBBLE_BULLET_SCALE) < 0.01, "Gegnerische Kugel in der Blase auf 25 %")
		bullet.global_position = zs.global_position + Vector2(900.0, -30.0)
		_check(TimeBubble.bullet_time_scale(bullet) == 1.0, "Kugel außerhalb normal")
		bullet.queue_free()
	for b in bubbles:
		b.finish()

	# Rückspul: zurück an die alte Stelle, Schaden kommt als Leben zurück.
	await _wait(0.3)
	_reset(zs)
	zs._zeit_hist.clear()
	zs._zeit_damage_log.clear()
	var old_pos := zs.global_position
	await _wait(0.5)
	zs.global_position = old_pos + Vector2(120.0, -10.0)
	zs.current_health = zs.max_health
	zs.current_shield = 0.0
	zs.is_invulnerable = false
	zs.take_damage(30.0, Vector2.ZERO, foe)
	var hp_hit := zs.current_health
	_check(absf(zs.zeit_rewind_heal_amount() - 30.0) < 0.5, "Rückspul würde 30 HP zurückgeben (%.1f)" % zs.zeit_rewind_heal_amount())
	zs.dash_charges = zs.dash_charges_max
	zs.dash()
	_check(zs.global_position.distance_to(old_pos) < 40.0, "Rückspul springt zurück (%.0f px)" % zs.global_position.distance_to(old_pos))
	_check(zs.current_health > hp_hit + 25.0, "Rückspul heilt den Schaden (%.0f → %.0f)" % [hp_hit, zs.current_health])
	_check(zs.dash_charges == zs.dash_charges_max - 1, "Rückspul verbraucht eine Ladung")

	# Zeitstopp: Gegner friert ein, Treffer stauen sich und kommen gesammelt.
	await _wait(0.3)
	_reset(foe)
	foe.global_position = zs.global_position + Vector2(40.0, 0.0)
	foe.is_invulnerable = false
	zs.ult_timer = 0.0
	zs.use_ultimate()
	_check(zs.is_time_stopping() and foe.is_time_frozen(), "Zeitstopp friert den Gegner ein")
	var frozen_pos := foe.global_position
	var hp_before := foe.current_health
	for i in range(2):
		zs.melee_cooldown_timer = 0.0
		zs.melee_attack(Vector2.RIGHT)
	_check(foe.current_health == hp_before, "Treffer im Zeitstopp kommen noch nicht an")
	_check(foe.get_time_frozen_damage() > 40.0, "Gestauter Schaden (%.0f)" % foe.get_time_frozen_damage())
	foe.dash_charges = foe.dash_charges_max
	foe.dash()
	_check(not foe.is_dashing, "Eingefroren: kein Dash")
	var fbullet = zs._spawn_bullet(Vector2.LEFT) if false else foe._spawn_bullet(Vector2.LEFT)
	await _wait(0.5)
	_check(foe.global_position.distance_to(frozen_pos) < 2.0, "Eingefrorener bewegt sich nicht")
	if fbullet != null and is_instance_valid(fbullet):
		_check(TimeBubble.bullet_time_scale(fbullet) == 0.0, "Gegnerische Kugel eingefroren")
	await _wait(Player.ZEIT_STOP_DURATION)
	_check(not foe.is_time_frozen() and not zs.is_time_stopping(), "Zeitstopp endet")
	_check(hp_before - foe.current_health > 40.0, "Gestaute Treffer schlagen ein (%.0f)" % (hp_before - foe.current_health))
	_check(foe.stun_timer <= 0.05, "Keine Rest-Betäubung nach dem Zeitstopp")
	if fbullet != null and is_instance_valid(fbullet):
		_check(TimeBubble.bullet_time_scale(fbullet) == 1.0, "Kugel fliegt danach weiter")

	# Klassenkarten
	for id in ["zeit_taktgeber", "zeit_schweres_pendel", "zeit_stundenschlag", "zeit_grosse_blase",
			"zeit_lange_erinnerung", "zeit_ewige_sekunde", "zeit_zinseszins", "zeit_schnellladung"]:
		var card := CardDatabase.get_card(id)
		_check(card != null and CardDatabase.is_card_available_for_player(card, "zeitschlaeger", []), "Karte %s für Zeitschläger verfügbar" % id)
		_check(card != null and not CardDatabase.is_card_available_for_player(card, "volt", []), "Karte %s nicht für Volt" % id)
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("zeit_zeitriss"), "zeitschlaeger", []), "Zeitriss braucht Lange Erinnerung")
	_check(CardDatabase.is_card_available_for_player(CardDatabase.get_card("zeit_zeitriss"), "zeitschlaeger", ["zeit_lange_erinnerung"]), "Zeitriss mit Langer Erinnerung verfügbar")
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("zeit_eigenzeit"), "zeitschlaeger", ["zeit_grosse_blase", "zeit_zerfall"]), "Nur ein Zweig pro Familie")

	# Stundenschlag: Taktschlag schon beim 2. Treffer.
	zs.ability_evolutions.append("zeit_passive_fast")
	zs.zeit_hit_count = 0
	_reset(foe)
	await _wait(0.2)
	for i in range(2):
		foe.global_position = zs.global_position + Vector2(40.0, 0.0)
		zs.melee_cooldown_timer = 0.0
		zs.melee_attack(Vector2.RIGHT)
	_check(foe.time_slow_timer > 2.0, "Stundenschlag: Verlangsamung beim 2. Treffer, länger")

	print("[TEST] fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
