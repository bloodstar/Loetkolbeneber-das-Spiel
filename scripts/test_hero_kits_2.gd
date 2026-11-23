extends Node2D

## Test für die Helden-Kits Teil 2: Ignis, Spore, Nova, Klinge, Bastion, Druide
## (Dash, Fähigkeit, Ulti). Je zwei Helden treten gegeneinander an.
## Start: godot --headless --path . scenes/test_hero_kits_2.tscn

var _failed: int = 0
var main = null
var _spawn: Dictionary = {}

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _hp(p: Player) -> float:
	return p.current_health + p.current_shield

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(90.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)
	for id in ["ignis", "spore", "nova", "klinge", "bastion", "druid"]:
		_check(Global.get_hero(id).has_ult(), "%s hat eine Ulti" % id)
	for id in ["ignis_glutspur", "ignis_komet", "spore_klebsporen", "spore_pandemie", "nova_druckwelle",
			"nova_phasenhuelle", "klinge_wurfklinge", "klinge_klingenfluss", "bastion_magnetfeld",
			"bastion_wanderfestung", "druid_fesselranke", "druid_dornenfell"]:
		_check(CardDatabase.get_card(id) != null, "Karte %s existiert" % id)
	_check(CardDatabase.get_card("ignis_meteorregen").required_mechanic == "ult", "Ulti-Karten brauchen die Ulti")

	var pair := await _start_match("ignis", "spore")
	await _test_ignis(pair[0], pair[1])
	await _test_spore(pair[1], pair[0])
	pair = await _start_match("nova", "klinge")
	await _test_nova(pair[0], pair[1])
	await _test_klinge(pair[1], pair[0])
	pair = await _start_match("bastion", "druid")
	await _test_bastion(pair[0], pair[1])
	await _test_druid(pair[1], pair[0])

	SideLevels.test_map_id = ""
	print("[TEST] Fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)

func _start_match(a: String, b: String) -> Array:
	if main != null:
		main.queue_free()
		await _wait(0.2)
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, a)
	Global.set_player_hero(2, b)
	Global.set_game_mode(Global.GAME_MODE_SIDE)
	Global.reset_match()
	# Feste, offene Karte, damit kein Gelände zwischen den Testfiguren steht.
	SideLevels.test_map_id = "weite"
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var p1: Player = main.get_player(1)
	var p2: Player = main.get_player(2)
	for p in [p1, p2]:
		p.is_bot = false
		p.control_enabled = true
		p.is_invulnerable = false
		p.max_health = 3000.0
		p.current_health = 3000.0
		var ai = p.get_node_or_null("AIController")
		if ai:
			ai.queue_free()
	_spawn = {1: p1.global_position, 2: p2.global_position}
	print("[INFO] Match %s gegen %s" % [a, b])
	return [p1, p2]

func _place(target: Player, near: Player, offset: Vector2) -> void:
	target.global_position = near.global_position + offset
	target.velocity = Vector2.ZERO
	target.is_invulnerable = false
	target.stun_timer = 0.0

# Gegner hinstellen, landen lassen und dann genau auf ihn zielen.
func _settle(target: Player, near: Player, offset: Vector2) -> void:
	_place(target, near, offset)
	await _wait(0.5)
	target.velocity = Vector2.ZERO
	near.aim_direction = (target.global_position - near.global_position).normalized()

func _los(a: Player, b: Player) -> String:
	var q := PhysicsRayQueryParameters2D.create(a.global_position, b.global_position, 1)
	q.exclude = [a.get_rid(), b.get_rid()]
	var hit := a.get_world_2d().direct_space_state.intersect_ray(q)
	return "frei" if hit.is_empty() else "Wand bei %s" % (hit["position"] - a.global_position)

# Zufallskarten: Steht Gelände zwischen den beiden, wird die Prüfung übersprungen.
func _check_if_clear(clear: bool, cond: bool, text: String) -> void:
	if clear:
		_check(cond, text)
	else:
		print("[SKIP] Gelände im Weg: ", text)

func _ents(cls) -> Array:
	return get_tree().get_nodes_in_group(NetEntity.GROUP).filter(func(e): return is_instance_of(e, cls) and e.is_active())

func _test_ignis(ignis: Player, foe: Player) -> void:
	_place(foe, ignis, Vector2(150.0, 0.0))
	ignis.dash_dir = Vector2.RIGHT
	ignis.dash()
	_check(ignis.is_dashing, "Ignis: Nachbrenner startet")
	await _wait(0.4)
	await _settle(foe, ignis, Vector2(160.0, 0.0))
	var before := _hp(foe)
	ignis.ult_timer = 0.0
	ignis.use_ultimate(foe.global_position)
	await _wait(0.05)
	_check(_ents(IgnisMeteor).size() == Player.IGNIS_METEOR_COUNT, "Ignis: %d Meteore angekündigt" % Player.IGNIS_METEOR_COUNT)
	foe.velocity = Vector2.ZERO
	await _wait(1.8)
	_check(_hp(foe) < before, "Ignis: Meteorschauer trifft (%.0f Schaden)" % (before - _hp(foe)))
	_check(_ents(IgnisMeteor).is_empty(), "Ignis: Meteore sind eingeschlagen")

func _test_spore(spore: Player, foe: Player) -> void:
	spore.ability_timer = 0.0
	_place(foe, spore, Vector2(400.0, 0.0))
	spore.use_ability(spore.global_position + Vector2(90.0, 0.0))
	await _wait(0.1)
	var shrooms := _ents(SporeShroom)
	_check(shrooms.size() == 1, "Spore: Giftpilz liegt")
	await _wait(0.8)
	if shrooms.size() == 1 and is_instance_valid(shrooms[0]):
		_place(foe, spore, Vector2(0.0, 0.0))
		foe.global_position = shrooms[0].global_position + Vector2(0.0, -10.0)
	var before := _hp(foe)
	await _wait(1.0)
	_check(_ents(SporeShroom).is_empty(), "Spore: Pilz platzt bei Gegnernähe")
	_check(_hp(foe) < before, "Spore: Pilzwolke macht Schaden (%.1f)" % (before - _hp(foe)))
	# Limit: höchstens spore_max_shrooms Pilze gleichzeitig.
	_place(foe, spore, Vector2(900.0, 0.0))
	for i in range(spore.spore_max_shrooms + 2):
		spore.ability_timer = 0.0
		spore.use_ability(spore.global_position + Vector2(-60.0 - 25.0 * float(i), 0.0))
	await _wait(0.1)
	_check(_ents(SporeShroom).size() == spore.spore_max_shrooms, "Spore: höchstens %d Pilze" % spore.spore_max_shrooms)
	# Seuchennebel.
	_place(foe, spore, Vector2(120.0, 0.0))
	spore.ult_timer = 0.0
	spore.use_ultimate()
	_check(is_instance_valid(spore.active_fog) and spore.active_fog.is_active(), "Spore: Seuchennebel läuft")
	await _wait(0.8)
	_check(foe.is_poisoned(), "Spore: Nebel vergiftet")
	spore.global_position += Vector2(-60.0, 0.0)
	await _wait(0.3)
	_check(spore.active_fog.global_position.distance_to(spore.global_position) < 40.0, "Spore: Nebel wandert mit")
	spore.dash_dir = Vector2.LEFT
	spore.dash()
	_check(spore.is_dashing, "Spore: Sporenstoß startet")
	await _wait(0.3)

func _test_nova(nova: Player, foe: Player) -> void:
	await _settle(foe, nova, Vector2(70.0, 0.0))
	nova.ability_timer = 0.0
	nova.use_ability()
	await _wait(0.03)
	_check(foe.velocity.length() > 200.0, "Nova: Gravitationsstoß stößt weg (v %.0f)" % foe.velocity.length())
	nova.dash_dir = Vector2.UP
	nova.dash()
	_check(nova.glide_timer > 0.0 and nova.is_invulnerable, "Nova: Phasengleiten läuft")
	await _wait(0.8)
	_check(nova.glide_timer <= 0.0, "Nova: Phasengleiten endet")
	_place(foe, nova, Vector2(150.0, 0.0))
	var before := _hp(foe)
	nova.ult_timer = 0.0
	nova.use_ultimate(foe.global_position)
	_check(not nova.gravity_wells.is_empty(), "Nova: Singularität als Ulti")
	await _wait(Player.SINGULARITY_DURATION + 0.4)
	_check(nova.gravity_wells.is_empty() and _hp(foe) < before, "Nova: Singularität implodiert (%.0f Schaden)" % (before - _hp(foe)))

# Zurück an den Startpunkt, falls ein vorheriger Test die Figur weggeschleudert hat.
func _reset(p: Player) -> void:
	p.global_position = _spawn.get(p.player_index, p.global_position)
	p.velocity = Vector2.ZERO
	p.stun_timer = 0.0
	p.knockback_timer = 0.0
	p.control_enabled = true

func _test_klinge(klinge: Player, foe: Player) -> void:
	_reset(klinge)
	await _wait(0.5)
	print("[INFO] Klinge lebt %s, Steuerung %s, Betäubung %.2f" % [klinge.current_health > 0.0, klinge.control_enabled, klinge.stun_timer])
	var hits: Array = []
	for i in range(3):
		await _settle(foe, klinge, Vector2(24.0, 0.0))
		klinge.klinge_combo_timer = Player.KLINGE_COMBO_WINDOW
		klinge.melee_cooldown_timer = 0.0
		var before := _hp(foe)
		klinge.attack()
		await _wait(0.15)
		hits.append(before - _hp(foe))
	_check(hits[0] > 0.0 and hits[2] > hits[0] * 1.3, "Klinge: dritter Hieb ist stark (%s)" % [hits])
	# Bumerang.
	await _settle(foe, klinge, Vector2(140.0, 0.0))
	klinge.ability_timer = 0.0
	var b0 := _hp(foe)
	var bm_clear := _los(klinge, foe) == "frei"
	klinge.use_ability()
	await _wait(0.05)
	_check(is_instance_valid(klinge.active_boomerang), "Klinge: Bumerang fliegt")
	klinge.melee_cooldown_timer = 0.0
	var mcd := klinge.melee_cooldown_timer
	klinge.attack()
	_check(klinge.melee_cooldown_timer == mcd, "Klinge: kein Hieb ohne Schwert")
	await _wait(1.4)
	_check_if_clear(bm_clear, _hp(foe) < b0, "Klinge: Bumerang trifft (%.0f)" % (b0 - _hp(foe)))
	_check(klinge.active_boomerang == null or not is_instance_valid(klinge.active_boomerang), "Klinge: Schwert ist zurück")
	# Durchstoß.
	_place(foe, klinge, Vector2(40.0, 0.0))
	klinge.dash_charges = klinge.dash_charges_max
	klinge.dash_dir = Vector2.RIGHT
	var d0 := _hp(foe)
	klinge.dash()
	await _wait(0.3)
	_check(_hp(foe) < d0, "Klinge: Durchstoß trifft")
	_check(klinge.dash_cooldown_timer < klinge.dash_cooldown * 0.75, "Klinge: Treffer verkürzt die Dash-Abklingzeit")
	# Klingensturm.
	_place(foe, klinge, Vector2(60.0, 0.0))
	klinge.ult_timer = 0.0
	var s0 := _hp(foe)
	klinge.use_ultimate()
	_check(klinge.blade_storm_timer > 0.0, "Klinge: Klingensturm läuft")
	await _wait(0.7)
	_check(_hp(foe) < s0, "Klinge: Klingensturm schneidet")
	await _wait(Player.BLADE_STORM_DURATION)
	_check(klinge.blade_storm_timer <= 0.0, "Klinge: Klingensturm endet")

func _test_bastion(bastion: Player, foe: Player) -> void:
	await _wait(0.3)
	await _settle(foe, bastion, Vector2(220.0, 0.0))
	bastion.ability_timer = 0.0
	var h0 := _hp(foe)
	var hook_clear := _los(bastion, foe) == "frei"
	bastion.use_ability()
	await _wait(0.9)
	var dist := foe.global_position.distance_to(bastion.global_position)
	_check_if_clear(hook_clear, _hp(foe) < h0 and dist < 150.0, "Bastion: Magnethaken zieht heran (Abstand %.0f)" % dist)
	_place(foe, bastion, Vector2(300.0, 0.0))
	bastion.dash_charges = bastion.dash_charges_max
	bastion.dash_dir = Vector2.RIGHT
	bastion.dash()
	_check(bastion.is_dashing and not bastion.is_invulnerable, "Bastion: Rammbock macht nicht unverwundbar")
	await _wait(0.5)
	bastion.current_health = 1000.0
	bastion.ult_timer = 0.0
	bastion.use_ultimate()
	_check(is_instance_valid(bastion.active_dome) and bastion.active_dome.is_active(), "Bastion: Festung steht")
	await _wait(1.2)
	_check(bastion.current_health > 1000.0, "Bastion: Festung heilt (%.0f)" % bastion.current_health)

func _test_druid(druid: Player, foe: Player) -> void:
	_reset(druid)
	await _wait(0.4)
	var hp0 := druid.max_health
	var scale0 := druid.scale.x
	druid.ult_timer = 0.0
	druid.use_ultimate()
	_check(druid.boar_timer > 0.0 and druid.is_melee and druid.max_health > hp0 and druid.scale.x > scale0 * 1.3,
		"Druide: Urkeiler verwandelt (HP %.0f, Größe %.2f)" % [druid.max_health, druid.scale.x])
	_place(foe, druid, Vector2(60.0, 0.0))
	druid.dash_charges = druid.dash_charges_max
	druid.dash_dir = Vector2.RIGHT
	var c0 := _hp(foe)
	druid.dash()
	await _wait(0.4)
	_check(_hp(foe) < c0, "Druide: Ansturm trifft")
	druid._end_boar()
	_check(not druid.is_melee and is_equal_approx(druid.max_health, hp0) and is_equal_approx(druid.scale.x, scale0), "Druide: Gestalt endet sauber")
	druid.aim_direction = Vector2.UP
	druid.dash_charges = druid.dash_charges_max
	druid.dash()
	_check(druid.is_dashing, "Druide: Rankenschwung bzw. Dash startet")
	await _wait(0.4)
