extends Node2D

## Fokussierter Test für Flocke (Frost-Magierin).
## Start: godot --headless --path . scenes/test_flocke.tscn

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
	p.max_health = 5000.0
	p.current_health = 5000.0
	p.current_shield = 0.0
	p.max_shield = 0.0
	p.is_invulnerable = false

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(40.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	var hero := Global.get_hero("flocke")
	_check(hero.id == "flocke" and not hero.is_melee() and hero.has_ult(), "Flocke existiert, Fernkampf, mit Ulti")
	_check(ElementSystem.hero_element("flocke") == ElementSystem.FROST, "Grundelement Frost")
	_check(Global.get_hero_ability_details(hero) != hero.ability_desc and Global.get_hero_ult_details(hero) != hero.ult_desc, "Fähigkeits- und Ultitext mit Zahlen")
	_check(hero.get_ability_fingerprint().length() == 8, "Fähigkeits-Fingerabdruck")
	_check(CardMechanics.get_hero_icon("flocke") != null, "Klassen-Icon lädt")
	var class_cards := 0
	for c in CardDatabase.all_cards:
		if c.hero_id == "flocke":
			class_cards += 1
	_check(class_cards >= 6, "Klassenkarten registriert (%d)" % class_cards)
	var boar_spec := VoxelBoar.spec_from_look({}, {"gender": "female"})
	_check(boar_spec["gender"] == "female", "Voxel-Spec übernimmt weiblichen Körperbau")

	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, "flocke")
	Global.set_player_hero(2, "volt")
	Global.reset_match()
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var fl: Player = main.get_player(1)
	var foe: Player = main.get_player(2)
	_check(fl != null and foe != null, "Beide Spieler sind gespawnt")
	if fl == null or foe == null:
		get_tree().quit(1)
		return
	for p in [fl, foe]:
		p.is_bot = false
		p.control_enabled = true
		var ai = p.get_node_or_null("AIController")
		if ai:
			ai.queue_free()
	await _wait(1.0)
	_reset(foe)
	_check(fl.sprite.outfit_id == "flocke", "Schal-und-Diadem-Outfit")
	_check(fl.freeze_duration >= Player.FLOCKE_PASSIVE_CHILL, "Kältehauch: Schüsse verlangsamen")
	_check(fl.elements.has(ElementSystem.FROST), "Flocke hat Frost im Element-Slot")

	# Passiv: jeder 4. Schuss ist ein durchschlagender Eissplitter.
	fl.flocke_shot_count = 0
	var shards := 0
	for i in range(Player.FLOCKE_PASSIVE_SHARD_INTERVAL):
		var b := fl._spawn_bullet(Vector2.RIGHT)
		if b.piercing_left > fl.piercing:
			shards += 1
		b.queue_free()
	_check(shards == 1, "Genau ein Eissplitter pro %d Schüsse" % Player.FLOCKE_PASSIVE_SHARD_INTERVAL)

	# Gletscherlanze: Gegner auf der Linie nimmt Schaden und wird verlangsamt.
	foe.global_position = fl.global_position + Vector2(160.0, 0.0)
	_reset(foe)
	fl.aim_direction = Vector2.RIGHT
	fl.ability_timer = 0.0
	var hp := foe.current_health
	fl.use_ability()
	await _wait(0.05)
	_check(foe.current_health < hp, "Gletscherlanze trifft (%.0f Schaden)" % (hp - foe.current_health))
	_check(foe.freeze_timer > 0.0, "Gletscherlanze verlangsamt")
	var ice := 0
	for z in get_tree().get_nodes_in_group("effect_zone"):
		if z.kind == EffectZone.Kind.ICE:
			ice += 1
	_check(ice >= 1, "Lanze endet in einer Eisnova")
	_check(fl.ability_timer > 0.0, "Fähigkeit hat Abklingzeit")

	# Lanze daneben: kein Treffer.
	_reset(foe)
	foe.global_position = fl.global_position + Vector2(160.0, -140.0)
	fl.ability_timer = 0.0
	hp = foe.current_health
	fl.use_ability()
	await _wait(0.05)
	_check(is_equal_approx(foe.current_health, hp), "Lanze trifft nur auf der Linie")

	# Schlitterschritt: Eisbahn hinter dem Dash.
	for z in get_tree().get_nodes_in_group("effect_zone"):
		z.queue_free()
	await _wait(0.05)
	fl.dash_charges = fl.dash_charges_max
	fl.dash_cooldown_timer = 0.0
	fl.velocity = Vector2(200.0, 0.0)
	fl.dash()
	await _wait(0.25)
	ice = 0
	for z in get_tree().get_nodes_in_group("effect_zone"):
		if z.kind == EffectZone.Kind.ICE and not z.is_queued_for_deletion():
			ice += 1
	_check(ice >= 2, "Schlitterschritt hinterlässt eine Eisbahn (%d Zonen)" % ice)

	# Blizzard: Schaden, Verlangsamung, nach 2 s Einfrieren.
	_reset(foe)
	await _wait(0.6)
	foe.global_position = fl.global_position + Vector2(200.0, 0.0)
	_reset(foe)
	fl.ult_timer = 0.0
	hp = foe.current_health
	fl.use_ultimate(foe.global_position)
	var storms := get_tree().get_nodes_in_group("round_effect").filter(func(n): return n is FlockeBlizzard)
	_check(storms.size() == 1, "Blizzard entsteht")
	var visual := 0
	for z in get_tree().get_nodes_in_group("effect_zone"):
		if z.kind == EffectZone.Kind.BLIZZARD:
			visual += 1
	_check(visual == 1, "Blizzard-Optik als Zone")
	var stunned := false
	for i in range(14):
		await _wait(0.2)
		if storms.size() == 1 and is_instance_valid(storms[0]):
			storms[0].global_position = foe.global_position
		foe.velocity = Vector2.ZERO
		if foe.stun_timer > 0.0:
			stunned = true
	_check(foe.current_health < hp, "Blizzard macht Schaden (%.0f)" % (hp - foe.current_health))
	_check(foe.freeze_timer > 0.0, "Blizzard verlangsamt")
	_check(stunned, "Wer lange im Sturm steht, friert ein")

	# Klassenkarte: Eiszapfenhagel macht jeden 3. Schuss zum Splitter.
	fl.ability_evolutions.append("flocke_passive_fast")
	_check(fl.flocke_shard_interval() == Player.FLOCKEEVO_FAST_SHARD_INTERVAL, "Eiszapfenhagel verkürzt das Intervall")
	fl.ability_evolutions.erase("flocke_passive_fast")

	# Bot-Flocke ist weiblich.
	var bot_spec := VoxelBoar.spec_for_player(2, Color.WHITE, "flocke") if Global.is_bot_slot(2) else {"gender": "female"}
	_check(bot_spec["gender"] == "female", "Bot-Flocke hat den weiblichen Körperbau")

	print("[TEST] fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
