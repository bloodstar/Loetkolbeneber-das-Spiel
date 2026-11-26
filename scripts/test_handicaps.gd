extends Node2D

# Handicaps (Lobby-Reiter): Leben- und Schadensfaktor pro Spieler.
# Start: godot --headless --path . res://scenes/test_handicaps.tscn
# Mit SHOT=1 (ohne --headless) wird zusätzlich ein Bild vom Reiter gespeichert.

func _ready() -> void:
	print("[TEST] Handicaps")
	Global.lobby_autosave_enabled = false
	# Gespeicherter Modus (z. B. Horde = alle im selben Team) darf nicht stören.
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.reset_handicaps()
	for slot in range(1, Global.MAX_PLAYERS + 1):
		Global.set_barrier_auto(slot, false)
	get_tree().create_timer(20.0, true).timeout.connect(func():
		print("[TEST] TIMEOUT – breche ab.")
		get_tree().quit(1)
	)

	# Grenzen und Presets.
	Global.set_hp_handicap(2, 300)
	Global.set_damage_handicap(2, 10)
	assert(Global.get_hp_handicap_percent(2) == 200, "HP handicap is capped at 200 %")
	assert(Global.get_damage_handicap_percent(2) == 50, "Damage handicap is at least 50 %")
	assert(Global.get_hp_handicap_percent(0) == 100 and Global.get_hp_handicap_percent(9) == 100, "Unknown slots stay at 100 %")
	var preset := Global.get_current_lobby_settings()
	Global.reset_handicaps()
	assert(not Global.has_handicaps(), "Reset sets everyone to 100 %")
	Global.apply_lobby_settings(preset)
	assert(Global.get_hp_handicap_percent(2) == 200 and Global.get_damage_handicap_percent(2) == 50, "Presets restore handicaps")
	var sync := NetworkManager.build_lobby_sync()
	assert(sync.has("handicaps"), "Lobby sync carries handicaps")
	Global.reset_handicaps()

	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await get_tree().create_timer(0.3).timeout

	var p1: Player = main.get_player(1)
	var p2: Player = main.get_player(2)
	assert(p1 != null and p2 != null, "Two players spawned")

	# Gespeicherte Lobby-Werte ("Last") dürfen den Test nicht beeinflussen.
	for slot in range(1, Global.MAX_PLAYERS + 1):
		Global.set_barrier_auto(slot, false)
	# Schaden: Faktor des Angreifers.
	p2.is_invulnerable = false
	p2.is_blocking = false
	p2.armor_percent = 0.0
	p2.current_shield = 0.0
	p2.current_health = 1000.0
	Global.set_damage_handicap(1, 50)
	p2.take_damage(10.0, Vector2.ZERO, p1)
	assert(is_equal_approx(p2.current_health, 995.0), "50 %% damage handicap halves damage (got %.2f)" % p2.current_health)
	Global.set_damage_handicap(1, 200)
	p2.take_damage(10.0, Vector2.ZERO, p1)
	assert(is_equal_approx(p2.current_health, 975.0), "200 %% damage handicap doubles damage (got %.2f)" % p2.current_health)
	# Das Handicap des Ziels ändert den erlittenen Schaden nicht.
	Global.set_damage_handicap(1, 100)
	Global.set_damage_handicap(2, 50)
	p2.take_damage(10.0, Vector2.ZERO, p1)
	assert(is_equal_approx(p2.current_health, 965.0), "Target's own damage handicap does not reduce damage taken")
	Global.reset_handicaps()

	# Barriere automatisch: Treffer zündet die bereite Barriere und wird abgefangen.
	Global.set_barrier_auto(2, true)
	Global.reset_handicaps()
	assert(Global.get_barrier_auto(2), "ALLE 100 % keeps Barriere automatisch")
	assert(Global.get_handicaps().has("barrier_auto"), "Barriere automatisch is synced with the handicaps")
	p2.block_cooldown_timer = 0.0
	p2.control_enabled = true
	p2.stun_timer = 0.0
	p2.take_damage(10.0, Vector2.ZERO, p1)
	assert(p2.is_blocking and is_equal_approx(p2.current_health, 965.0), "Barriere automatisch blocks the hit")
	p2._end_block()
	p2.take_damage(10.0, Vector2.ZERO, p1)
	assert(not p2.is_blocking and is_equal_approx(p2.current_health, 955.0), "No auto barrier while on cooldown")
	Global.set_barrier_auto(2, false)
	p2.block_cooldown_timer = 0.0

	# Leben: Faktor auf die maximalen Leben.
	p1.apply_stats()
	var max_before := p1.max_health
	Global.set_hp_handicap(1, 150)
	p1.apply_stats()
	assert(is_equal_approx(p1.max_health, max_before * 1.5), "150 % HP handicap scales max health")
	Global.set_hp_handicap(1, 50)
	p1.apply_stats()
	assert(is_equal_approx(p1.max_health, max_before * 0.5), "50 % HP handicap halves max health")
	Global.reset_handicaps()

	# Lobby-Reiter.
	var lobby = main.lobby
	var idx: int = lobby.tabs.get_tab_idx_from_control(lobby.handicaps_tab)
	assert(idx >= 0, "Lobby has a handicaps tab")
	assert(lobby.tabs.get_tab_title(idx) == "Handicaps", "Tab title without active handicaps")
	assert(lobby.handicap_rows.size() == Global.get_active_player_indices().size(), "One row per active player")
	Global.set_hp_handicap(2, 150)
	Global.set_damage_handicap(1, 70)
	assert(lobby.tabs.get_tab_title(idx) == "Handicaps •", "Tab title marks active handicaps")
	var row: Dictionary = lobby.handicap_rows[2]
	assert(int((row["hp_slider"] as HSlider).value) == 150, "Slider follows the global value")
	(row["dmg_slider"] as HSlider).value = 180
	assert(Global.get_damage_handicap_percent(2) == 180, "Slider sets the handicap for the host")

	if OS.get_environment("SHOT") == "1":
		main.lobby.open_lobby()
		Global.set_hp_handicap(2, 150)
		Global.set_damage_handicap(1, 70)
		Global.set_damage_handicap(2, 180)
		lobby.tabs.current_tab = idx
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_PATH") if OS.has_environment("SHOT_PATH") else "user://handicaps.png")

	Global.reset_handicaps()
	print("[TEST] Handicaps OK")
	get_tree().quit(0)
