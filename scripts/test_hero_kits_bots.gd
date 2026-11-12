extends Node2D

## Rauchtest: Bots mit den neuen Kits spielen einige Sekunden, erst in der
## Seitenansicht, dann in der Arena. Es zählt, dass keine Skriptfehler auftreten.
## Start: godot --headless --path . scenes/test_hero_kits_bots.tscn

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(4)
	var heroes := ["volt", "phantom", "klinge", "bastion"]
	for i in range(4):
		Global.set_player_hero(i + 1, heroes[i])
	Global.set_bot_test_random_loadouts(false)
	Global.set_bot_test_mode(true)
	Global.reset_match()
	for mode in [Global.GAME_MODE_SIDE, Global.GAME_MODE_ARENA]:
		Global.set_game_mode(mode)
		var main = load("res://scenes/main.tscn").instantiate()
		main.skip_menu = true
		main.kill_cam_enabled = false
		add_child(main)
		Engine.time_scale = 3.0
		var used := {"ult": 0, "decoy": 0, "orb": 0}
		for step in range(60):
			await _wait(0.25)
			used["decoy"] += get_tree().get_nodes_in_group("phantom_decoy").size()
			used["orb"] += get_tree().get_nodes_in_group("ball_lightning").size()
			for p in main.players:
				if is_instance_valid(p) and (p.overcharge_timer > 0.0 or p.hunt_timer > 0.0):
					used["ult"] += 1
			if Global.current_state == Global.GameState.CARD_DRAFT:
				main._start_fresh_round()
		var hero_list: Array = []
		for p in main.players:
			if is_instance_valid(p):
				hero_list.append(Global.get_player_hero_id(p.player_index))
		print("[INFO] Modus %s (%s): Bots nutzten %s" % [mode, hero_list, used])
		Engine.time_scale = 1.0
		main.queue_free()
		await _wait(0.3)
	print("[TEST] Bot-Rauchtest fertig")
	get_tree().quit(0)
