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

	# Jeder 3. Angriffstreffer erzeugt eine Kugel, Fähigkeitsschaden zählt nicht.
	_clear_orbs()
	foe.global_position = vamp.global_position + Vector2(300.0, 0.0)
	foe.is_invulnerable = false
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	_check(_orbs().size() == 0, "Nach 2 Treffern noch keine Kugel")
	vamp._ability_hit(foe, 5.0, Vector2.ZERO)
	_check(_orbs().size() == 0, "Fähigkeitsschaden zählt nicht")
	foe.take_damage(5.0, Vector2.ZERO, vamp)
	await get_tree().process_frame
	_check(_orbs().size() == 1, "3. Treffer erzeugt eine Blutkugel")
	_check(get_tree().get_nodes_in_group("net_entity").size() >= 1, "Kugel ist Netz-Objekt")
	var snap: Dictionary = _orbs()[0].get_network_state()
	_check(snap.get("k") == "blood" and NetEntity.create_replica("blood") is BloodOrb, "Snapshot-Art blood")

	# Bei voller HP wird nicht aufgesammelt, verletzt schon (+25).
	_clear_orbs()
	vamp.current_health = vamp.max_health
	var orb := vamp.spawn_blood_orb(vamp.global_position + Vector2(0.0, -10.0))
	await _wait(0.8)
	_check(is_instance_valid(orb) and orb.is_free(), "Volle HP: Kugel bleibt liegen")
	vamp.current_health = vamp.max_health - 40.0
	await _wait(0.6)
	_check(not is_instance_valid(orb) or not orb.is_free(), "Verletzt: Kugel wird aufgesammelt")
	_check(absf(vamp.current_health - (vamp.max_health - 15.0)) < 3.0, "Kugel heilt 25 HP (%.0f / %.0f)" % [vamp.current_health, vamp.max_health])

	# Blutexplosion: ohne Kugel kein Cooldown, mit Kugel Schaden am Gegner.
	_clear_orbs()
	vamp.ability_timer = 0.0
	vamp.use_ability()
	_check(vamp.ability_timer == 0.0, "Ohne Kugel keine Abklingzeit")
	vamp.current_health = vamp.max_health
	foe.global_position = vamp.global_position + Vector2(150.0, 0.0)
	foe.velocity = Vector2.ZERO
	vamp.spawn_blood_orb(foe.global_position)
	var hp_before := foe.current_health
	vamp.use_ability()
	_check(vamp.ability_timer > 0.0, "Blutexplosion hat Abklingzeit")
	_check(hp_before - foe.current_health >= 24.0, "Blutexplosion macht 25 Schaden (%.0f)" % (hp_before - foe.current_health))
	_check(_orbs().size() == 0, "Kugel ist verbraucht")

	# Blutsturm: Dash durch den Gegner erzeugt eine Kugel.
	_clear_orbs()
	await _wait(0.3)
	foe.global_position = vamp.global_position + Vector2(60.0, 0.0)
	foe.velocity = Vector2.ZERO
	vamp.velocity = Vector2.ZERO
	vamp.aim_direction = Vector2.RIGHT
	hp_before = foe.current_health
	vamp.dash_charges = vamp.dash_charges_max
	vamp.dash()
	await _wait(0.35)
	_check(foe.current_health < hp_before, "Blutsturm trifft den Gegner")
	_check(_orbs().size() >= 1, "Blutsturm erzeugt eine Blutkugel (%d)" % _orbs().size())

	# Fledermausschwarm: Kugeln werden Fledermäuse, die beißen.
	_clear_orbs()
	foe.global_position = vamp.global_position + Vector2(200.0, 0.0)
	for i in range(3):
		vamp.spawn_blood_orb(vamp.global_position + Vector2(20.0 * i, -40.0))
	vamp.current_health = vamp.max_health
	vamp.ult_timer = 0.0
	hp_before = foe.current_health
	vamp.use_ultimate()
	await get_tree().process_frame
	var bats := get_tree().get_nodes_in_group(VampireBat.GROUP)
	_check(bats.size() == 3, "3 Kugeln werden 3 Fledermäuse (%d)" % bats.size())
	_check(_orbs().size() == 0, "Kugeln sind verbraucht")
	await _wait(2.0)
	_check(foe.current_health < hp_before, "Fledermäuse beißen (%.0f Schaden)" % (hp_before - foe.current_health))
	# Fledermäuse lassen sich abschießen.
	bats = get_tree().get_nodes_in_group(VampireBat.GROUP)
	if bats.size() > 0:
		bats[0].take_tower_damage(60.0, foe)
		await get_tree().process_frame
		_check(not is_instance_valid(bats[0]), "Fledermaus stirbt nach 50 Schaden")
	# Ohne Kugeln kommen mindestens 2.
	for b in get_tree().get_nodes_in_group(VampireBat.GROUP):
		b.pop()
	vamp.ult_timer = 0.0
	vamp.use_ultimate()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(VampireBat.GROUP).size() == Player.VAMPIRE_ULT_MIN_BATS, "Ohne Kugeln mindestens 2 Fledermäuse")

	print("[TEST] fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
