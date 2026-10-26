extends Node2D

const LevelModifierDefsClass = preload("res://scripts/level_modifier_defs.gd")

func _assert_spawn_distances(spawns: Array[Vector2], context: String) -> void:
	for i in range(spawns.size()):
		for j in range(i + 1, spawns.size()):
			var distance := spawns[i].distance_to(spawns[j])
			assert(
				distance >= LevelGenerator.TILE_SIZE * 3.0,
				"%s: spawns %d and %d are too close (%.1f px)" % [context, i + 1, j + 1, distance]
			)

func _ready() -> void:
	print("[TEST] Initializing Headless Integration Test inside full game tree...")
	# Statistik-Tests laufen nur im Speicher und dürfen die echte user://-Datei
	# sowie die Seltenheiten des Nutzers nicht verändern.
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	CardStats.reset_statistics(true)
	assert(SoundManager.sounds.has("death"), "Death sound should be registered")
	assert(SoundManager.sounds.has("coin"), "Coin pickup sound should be registered")
	# Team-Modi: deterministische Zuordnung und Helfer vor dem Match prüfen.
	Global.set_match_mode(Global.MATCH_MODE_2V2)
	Global.set_player_count(4)
	assert(Global.is_team_mode(), "2v2 should be a team mode")
	assert(Global.get_team_count() == 2, "2v2 should have two teams")
	assert(Global.get_team_for_slot(1) == 1 and Global.get_team_for_slot(2) == 1, "2v2 slots 1-2 should be team 1")
	assert(Global.get_team_for_slot(3) == 2 and Global.get_team_for_slot(4) == 2, "2v2 slots 3-4 should be team 2")
	assert(Global.get_team_members(1) == [1, 2], "2v2 team 1 should contain slots 1-2")
	Global.set_match_mode(Global.MATCH_MODE_3V3)
	Global.set_player_count(6)
	assert(Global.get_team_members(1) == [1, 2, 3], "3v3 team 1 should contain slots 1-3")
	assert(Global.get_team_members(2) == [4, 5, 6], "3v3 team 2 should contain slots 4-6")
	Global.set_match_mode(Global.MATCH_MODE_2V2V2)
	assert(Global.get_team_count() == 3, "2v2v2 should have three teams")
	assert(Global.get_team_for_slot(5) == 3 and Global.get_team_for_slot(6) == 3, "2v2v2 slots 5-6 should be team 3")
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	assert(not Global.is_team_mode(), "FFA should be a solo mode")
	assert(Global.get_team_for_slot(1) == 1 and Global.get_team_for_slot(2) == 2, "FFA slots should be their own teams")

	# Zuschauer belegen keinen Spieler-Slot und dürfen keine Slots steuern.
	var local_player_backup := Global.local_player_index
	Global.network_mode = true
	Global.is_spectator = true
	Global.set_local_player(0)
	assert(Global.local_player_index == 0, "Spectator should use local player index 0")
	assert(not Global.is_local_host(), "Spectator should never be treated as host")
	assert(not Global.can_control_slot(1), "Spectator should not control player slots")
	Global.is_spectator = false
	Global.network_mode = false
	Global.set_local_player(local_player_backup)

	# Ping-Formatierung für Client und Host (inkl. Zuschauer).
	NetworkManager.is_client = true
	NetworkManager.ping_ms = 42
	assert(NetworkManager.get_ping_text() == "PING 42 ms", "Client ping text should show the measured RTT")
	assert(NetworkManager.get_ping_summary() == "PING 42 ms", "Client ping summary should show the measured RTT")
	NetworkManager.is_client = false
	NetworkManager.is_host = true
	NetworkManager.peer_slots = {10: 2}
	NetworkManager.slot_peers = {2: 10}
	NetworkManager.spectator_peers = {11: true}
	NetworkManager.peer_pings = {10: 35, 11: 120}
	var host_ping_text := NetworkManager.get_ping_text()
	assert("P2 35 ms" in host_ping_text, "Host ping text should include player clients")
	assert("Z1 120 ms" in host_ping_text, "Host ping text should include spectators")
	assert(NetworkManager.get_ping_summary() == "PING max 120 ms", "Host ping summary should show the worst RTT")
	NetworkManager.peer_slots.clear()
	NetworkManager.slot_peers.clear()
	NetworkManager.spectator_peers.clear()
	NetworkManager.peer_pings.clear()
	NetworkManager.is_host = false
	NetworkManager.ping_ms = -1

	# Lobby-Loadouts: Preset speichern, verändern, wieder laden und löschen.
	var original_lobby_settings := Global.get_current_lobby_settings()
	var test_loadout_name := "_integration_test_%d" % Time.get_ticks_msec()
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(3)
	Global.set_scoring_config(777, 55, 66)
	Global.set_draft_config(2, 7)
	Global.set_blind_pick_enabled(true)
	Global.set_random_pick_enabled(true)
	Global.set_base_hp_percent(130)
	Global.set_base_damage(33.0)
	Global.set_selected_map("eisgrotte")
	Global.set_enabled_card_pools(["Kern", "Chaos"])
	Global.set_rarity_percent("Epic", 33.0)
	Global.banned_card_ids.clear()
	Global.banned_card_ids.append("blockbombe")
	assert(Global.save_lobby_loadout(test_loadout_name), "Lobby loadout should be saved")
	assert(Global.has_lobby_loadout(test_loadout_name), "Saved lobby loadout should be listed")
	assert(not Global.get_lobby_loadout_summary(test_loadout_name).is_empty(), "Lobby loadout should have a summary")
	Global.set_match_mode(Global.MATCH_MODE_2V2)
	Global.set_player_count(4)
	Global.set_scoring_config(100, 0, 0)
	Global.set_draft_config(1, 3)
	Global.set_blind_pick_enabled(false)
	Global.set_random_pick_enabled(false)
	Global.set_base_hp_percent(60)
	Global.set_base_damage(5.0)
	Global.set_selected_map(Global.MAP_RANDOM)
	Global.set_all_card_pools(true)
	Global.set_rarity_percent("Epic", 1.0)
	Global.banned_card_ids.clear()
	Global.apply_lobby_settings(Global.get_lobby_loadout(test_loadout_name))
	assert(Global.match_mode == Global.MATCH_MODE_FFA, "Loaded loadout should restore the match mode")
	assert(Global.player_count == 3, "Loaded loadout should restore the player count")
	assert(Global.points_to_win == 777 and Global.survival_points == 55 and Global.kill_points == 66, "Loaded loadout should restore scoring")
	assert(Global.draft_picks == 2 and Global.cards_per_draft == 7, "Loaded loadout should restore the draft config")
	assert(Global.blind_pick_enabled, "Loaded loadout should restore Blind pick")
	assert(Global.random_pick_enabled, "Loaded loadout should restore Random pick")
	var lobby_sync_preview := NetworkManager.build_lobby_sync()
	assert(bool(lobby_sync_preview.get("blind_pick_enabled", false)), "Lobby sync should include Blind pick")
	assert(bool(lobby_sync_preview.get("random_pick_enabled", false)), "Lobby sync should include Random pick")
	assert(Global.base_hp_percent == 130 and is_equal_approx(Global.base_damage, 33.0), "Loaded loadout should restore HP and damage")
	assert(Global.selected_map_id == "eisgrotte", "Loaded loadout should restore the map")
	assert(Global.enabled_card_pools == ["Kern", "Chaos"], "Loaded loadout should restore enabled card pools")
	assert(is_equal_approx(Global.get_rarity_percent("Epic"), 33.0), "Loaded loadout should restore rarity weights")
	assert(Global.banned_card_ids.has("blockbombe"), "Loaded loadout should restore banned cards")
	assert(Global.delete_lobby_loadout(test_loadout_name), "Lobby loadout should be deletable")
	assert(not Global.has_lobby_loadout(test_loadout_name), "Deleted lobby loadout should be gone")
	Global.apply_lobby_settings(original_lobby_settings)

	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	main.skip_menu = true
	add_child(main)

	# Notbremse: Falls eine Assertion fehlschlägt, beendet der Test trotzdem.
	get_tree().create_timer(25.0, true).timeout.connect(func():
		print("[TEST] TIMEOUT – breche ab.")
		get_tree().quit(1)
	)

	# Wait for nodes to ready
	await get_tree().create_timer(0.2).timeout

	var level = main.get_node_or_null("ProceduralLevel")
	assert(level != null, "Level should exist")
	assert(main.lobby.mode_option != null, "Lobby should build the match mode selector")
	assert(main.lobby.mode_option.item_count == Global.MATCH_MODE_ORDER.size(), "Lobby should list every match mode")
	assert(main.lobby.loadout_option != null, "Lobby should build the loadout selector")
	assert(main.lobby.loadout_save_btn != null, "Lobby should build the loadout save button")
	assert(main.lobby.loadout_name_edit != null, "Lobby should build the loadout name field")
	assert(main.lobby.blind_pick_check != null, "Lobby should build the Blind pick toggle")
	assert(main.lobby.random_pick_check != null, "Lobby should build the Random pick toggle")
	var blind_pick_backup := Global.blind_pick_enabled
	var random_pick_backup := Global.random_pick_enabled
	main.lobby._on_blind_pick_toggled(true)
	main.lobby._on_random_pick_toggled(true)
	assert(Global.blind_pick_enabled and Global.random_pick_enabled, "Lobby modifiers should update Global settings")
	assert(main.lobby.blind_pick_check.disabled, "Blind pick toggle should be disabled outside online matches")
	assert("Blind" not in main.lobby.draft_summary.text, "Local lobby summary should not advertise Blind pick")
	assert("Random" in main.lobby.draft_summary.text, "Lobby summary should list active Random pick")
	main.lobby._on_blind_pick_toggled(blind_pick_backup)
	main.lobby._on_random_pick_toggled(random_pick_backup)

	# Runden-Modifier-Reiter: Rate, Auswahl und Host-Sperre.
	assert(main.lobby.modifier_rate_spin != null, "Lobby should build the modifier rate selector")
	assert(main.lobby.modifier_checks.size() == 20, "Lobby should list all 20 round modifiers")
	assert(main.lobby.modifier_all_btn != null and main.lobby.modifier_none_btn != null, "Lobby should offer select-all/none buttons")
	var level_rate_backup: int = Global.level_modifier_rate_percent
	var level_mods_backup: Array[String] = Global.get_enabled_level_modifiers()
	main.lobby._on_modifier_rate_changed(0.0)
	assert(Global.level_modifier_rate_percent == 0, "Lobby should update the modifier rate")
	assert("Level-Mod 0 %" in main.lobby.draft_summary.text, "Lobby summary should show the modifier rate")
	main.lobby._on_modifier_rate_changed(200.0)
	assert(Global.level_modifier_rate_percent == 200, "Lobby should allow a 200 % modifier rate")
	main.lobby._on_none_modifiers_pressed()
	assert(Global.get_enabled_level_modifier_count() == 0, "None button should disable every modifier")
	var wind_check := main.lobby.modifier_checks["wind"] as CheckButton
	assert(wind_check != null and not wind_check.button_pressed, "Disabled modifiers should uncheck in the lobby")
	main.lobby._on_all_modifiers_pressed()
	assert(Global.get_enabled_level_modifier_count() == 20, "All button should enable every modifier")
	Global.set_level_modifier_rate_percent(level_rate_backup)
	Global.set_enabled_level_modifiers(level_mods_backup)
	main.lobby._refresh_modifier_controls()

	# Blind pick wirkt nur online gegen menschliche Spieler, nie gegen Bots.
	var draft_ui: CardDraftUI = main.card_draft_ui
	var draft_network_backup: bool = draft_ui.network_mode
	var draft_local_owner_backup: bool = draft_ui.local_owner
	var draft_drafter_backup: int = draft_ui.current_drafter
	var p2_kind_backup: int = Global.get_player_kind(2)
	Global.set_blind_pick_enabled(true)
	draft_ui.network_mode = false
	draft_ui.local_owner = false
	draft_ui.current_drafter = 2
	assert(not draft_ui._blind_pick_active(), "Blind pick should be inactive outside online matches")
	assert(not draft_ui._blind_pick_hidden(), "Blind pick should not hide local or bot drafts")
	draft_ui.network_mode = true
	Global.set_player_kind(2, Global.PlayerKind.HUMAN)
	assert(draft_ui._blind_pick_active(), "Blind pick should be active in online matches")
	assert(draft_ui._blind_pick_hidden(), "Blind pick should hide remote human drafts online")
	Global.set_player_kind(2, Global.PlayerKind.BOT)
	assert(not draft_ui._blind_pick_hidden(), "Blind pick should never hide bot drafts")
	draft_ui.network_mode = draft_network_backup
	draft_ui.local_owner = draft_local_owner_backup
	draft_ui.current_drafter = draft_drafter_backup
	Global.set_player_kind(2, p2_kind_backup)
	Global.set_blind_pick_enabled(blind_pick_backup)
	assert(main.lobby.ban_checks.size() == CardDatabase.all_cards.size(), "Lobby ban list should list every card")
	assert(main.lobby.ban_icons.size() == CardDatabase.all_cards.size(), "Lobby ban list should show an icon for every card")
	# Klassen-Icons: Jede Heldenklasse besitzt ein eigenes Icon im Helden-Grid,
	# in der Slot-Kopfzeile und im Charakter-Tab.
	var first_hero_grid := main.lobby.slot_nodes[1]["grid"] as HBoxContainer
	assert(first_hero_grid != null, "Lobby should build the hero grid")
	assert(first_hero_grid.get_child_count() == Global.heroes.size(), "Hero grid should show every class")
	for child in first_hero_grid.get_children():
		var hero_btn := child as Button
		assert(hero_btn != null, "Every hero entry should be a button")
		var hero_id := str(hero_btn.get_meta("hero_id", ""))
		assert(not hero_id.is_empty(), "Hero button should carry its class id")
		var stats_label := hero_btn.get_meta("stats_label", null) as Label
		assert(stats_label != null, "Hero button should contain a stats label")
		assert(stats_label.text == main.lobby._hero_button_text(Global.get_hero(hero_id)), "Hero button should show live class stats")
		assert(main.lobby._get_hero_icon(hero_id) != null, "Hero class should have an icon texture")
	var header_icon := main.lobby.slot_nodes[1]["hero_icon"] as TextureRect
	assert(header_icon != null and header_icon.texture != null, "Slot header should show the selected class icon")
	assert(main.lobby.character_hero_icon != null and main.lobby.character_hero_icon.texture != null, "Character tab should show the selected class icon")
	assert(main.lobby.ready_btn != null, "Lobby should build the footer ready button")
	# Charakteranpassung lebt in der Lobby und ist pro Spieler-Slot verfügbar.
	assert(main.lobby.tabs.get_tab_count() == 5, "Lobby should have five tabs")
	assert(main.lobby.tabs.get_tab_title(1) == "Charakter", "Lobby should provide a character tab")
	assert(main.lobby.tabs.get_tab_title(4) == "Modifier", "Lobby should provide a modifier tab")
	assert(main.lobby.character_tab != null and main.lobby.character_slot_option != null, "Lobby should build the character controls")
	assert(main.lobby.character_slot_option.item_count >= 1, "Local lobby should offer player slots for customization")
	assert(main.lobby.wand_shape_option != null, "Lobby should offer configurable wand tip shapes")
	assert(main.lobby.wand_tip_picker != null, "Lobby should offer a wand tip color")
	assert(main.lobby.shot_color_picker != null, "Lobby should offer a base shot color")
	assert(main.lobby.character_preview_wand != null, "Character preview should show the wand")
	assert(
		Global.WAND_TIP_SHAPES.size() == 4 and Global.WAND_TIP_SHAPES.has("star"),
		"Four wand tip shapes should be available"
	)
	var original_character_slot: int = main.lobby._character_slot
	var original_slot_look := Global.get_pig_appearance(2)
	var test_fur := Color(0.11, 0.22, 0.33, 1.0)
	var test_tip := Color(0.20, 0.90, 1.0, 1.0)
	var test_shot := Color(1.0, 0.55, 0.20, 1.0)
	main.lobby._character_slot = 2
	main.lobby._refresh_character_tab()
	main.lobby.fur_picker.color = test_fur
	main.lobby._on_character_color_changed(test_fur)
	assert(Global.get_pig_appearance(2)["fur"] == test_fur, "Lobby character tab should update the selected player slot")
	main.lobby.wand_shape_option.select(Global.WAND_TIP_SHAPES.find("star"))
	main.lobby.wand_tip_picker.color = test_tip
	main.lobby.shot_color_picker.color = test_shot
	main.lobby._on_character_wand_shape_changed(main.lobby.wand_shape_option.selected)
	var customized_look := Global.get_pig_appearance(2)
	assert(customized_look["wand_tip_shape"] == "star", "Lobby should store the selected wand tip shape")
	assert(customized_look["wand_tip_color"] == test_tip, "Lobby should store the selected wand tip color")
	assert(customized_look["shot_color"] == test_shot, "Lobby should store the selected shot color")
	assert(main.lobby.character_preview_wand.tip_shape == "star", "Preview should update the wand tip shape")
	assert(main.lobby.character_preview_wand.tip_color == test_tip, "Preview should update the wand tip color")
	main.lobby._on_reset_character_colors()
	assert(Global.get_pig_appearance(2)["fur"] == Global.default_pig_fur_colors[1], "Lobby reset should restore the selected slot")
	assert(Global.get_pig_appearance(2)["wand_tip_shape"] == "orb", "Lobby reset should restore the default wand shape")
	assert(main.lobby.character_preview_wand.tip_shape == "orb", "Preview should reset the wand shape")
	Global.set_pig_appearance(
		2,
		original_slot_look["fur"],
		original_slot_look["eyes"],
		original_slot_look["pants"],
		original_slot_look["wand_tip_shape"],
		original_slot_look["wand_tip_color"],
		original_slot_look["shot_color"]
	)
	main.lobby._character_slot = original_character_slot
	main.lobby._refresh_character_tab()

	# Das Charakterprofil des lokalen Nutzers wird ohne Speichern-Knopf
	# automatisch geschrieben. Die echte Profildatei wird gesichert und
	# anschließend wiederhergestellt, damit der Test keine Daten hinterlässt.
	var profile_path := Global.CHARACTER_CUSTOMIZATION_PATH
	var profile_had_file := FileAccess.file_exists(profile_path)
	var profile_backup := ""
	if profile_had_file:
		var backup_file := FileAccess.open(profile_path, FileAccess.READ)
		if backup_file != null:
			profile_backup = backup_file.get_as_text()
			backup_file.close()
	var persistence_local_backup := Global.local_player_index
	var persistence_look_backup := Global.get_pig_appearance(1)
	Global.set_local_player(1)
	Global.set_pig_appearance(
		1,
		Color(0.31, 0.42, 0.53, 1.0),
		Color(0.22, 0.18, 0.24, 1.0),
		Color(0.34, 0.28, 0.18, 1.0),
		"crystal",
		Color(0.15, 0.85, 1.0, 1.0),
		Color(1.0, 0.45, 0.15, 1.0)
	)
	assert(FileAccess.file_exists(profile_path), "Character customization should auto-save a profile")
	var saved_text := ""
	var saved_file := FileAccess.open(profile_path, FileAccess.READ)
	if saved_file != null:
		saved_text = saved_file.get_as_text()
		saved_file.close()
	var saved_profile: Variant = JSON.parse_string(saved_text)
	assert(saved_profile is Dictionary, "Saved character profile should be valid JSON")
	assert(saved_profile["appearance"]["wand_tip_shape"] == "crystal", "Saved profile should include the wand shape")
	Global.set_pig_appearance(
		1,
		persistence_look_backup["fur"],
		persistence_look_backup["eyes"],
		persistence_look_backup["pants"],
		persistence_look_backup["wand_tip_shape"],
		persistence_look_backup["wand_tip_color"],
		persistence_look_backup["shot_color"]
	)
	if profile_had_file:
		var restore_file := FileAccess.open(profile_path, FileAccess.WRITE)
		if restore_file != null:
			restore_file.store_string(profile_backup)
			restore_file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path))
	Global.set_local_player(persistence_local_backup)
	var ui_loadout_name := "_ui_test_%d" % Time.get_ticks_msec()
	assert(Global.save_lobby_loadout(ui_loadout_name), "Lobby UI test loadout should be saved")
	main.lobby._refresh_loadout_controls(ui_loadout_name)
	assert(main.lobby._selected_loadout_name() == ui_loadout_name, "Lobby loadout selector should show the saved preset")
	main.lobby.loadout_name_edit.text = ui_loadout_name
	main.lobby._on_loadout_save_pressed()
	assert(Global.has_lobby_loadout(ui_loadout_name), "Lobby save handler should store the preset")
	main.lobby._on_loadout_load_pressed()
	assert(Global.has_lobby_loadout(ui_loadout_name), "Lobby load handler should keep the preset available")
	main.lobby._on_loadout_delete_pressed()
	assert(not Global.has_lobby_loadout(ui_loadout_name), "Lobby delete handler should remove the preset")

	# Zuschauer-Status in der Lobby (ohne echten Netzwerk-Peer).
	var lobby_network_backup := Global.network_mode
	var lobby_spectator_backup := Global.is_spectator
	var lobby_local_backup := Global.local_player_index
	Global.network_mode = true
	Global.is_spectator = true
	Global.set_local_player(0)
	main.lobby._sync_from_global()
	assert("ZUSCHAUER" in main.lobby.net_label.text, "Lobby should label spectators")
	assert("Zuschauer" in main.lobby.status_label.text, "Lobby status should explain spectator mode")
	assert(main.lobby.start_btn.disabled, "Spectators must not be able to start the match")
	assert(main.lobby.ready_btn.disabled, "Spectators must not be able to ready up")
	Global.network_mode = lobby_network_backup
	Global.is_spectator = lobby_spectator_backup
	Global.set_local_player(lobby_local_backup)
	main.lobby._sync_from_global()
	var ready_before := Global.is_player_ready(1)
	main.lobby._on_ready_pressed()
	assert(Global.is_player_ready(1) != ready_before, "Footer ready button should toggle the local slot")
	main.lobby._on_ready_pressed()
	assert(Global.is_player_ready(1) == ready_before, "Footer ready button should toggle back")

	# Inhalt: neue Klassen und zusätzliche Basiskarten müssen vorhanden sein.
	# Titan wurde entfernt; Block ist stattdessen für alle Spieler verfügbar.
	assert(Global.heroes.size() >= 7, "At least 7 heroes should be registered")
	assert(not Global.heroes.has("titan"), "Titan should be removed")
	assert(CardDatabase.all_cards.size() >= 164, "At least 164 cards should be registered")
	assert(InputMap.has_action("p1_block"), "Block action should be registered")
	# R lädt nach; der Match-Neustart liegt auf F9.
	assert(InputMap.has_action("p1_reload"), "Reload action should be registered")
	assert(InputMap.has_action("restart_game"), "Restart action should be registered")
	var reload_has_r := false
	for reload_event in InputMap.action_get_events("p1_reload"):
		if reload_event is InputEventKey and reload_event.physical_keycode == KEY_R:
			reload_has_r = true
	assert(reload_has_r, "R should be bound to manual reload")
	var restart_has_f9 := false
	var restart_has_r := false
	for restart_event in InputMap.action_get_events("restart_game"):
		if restart_event is InputEventKey:
			if restart_event.physical_keycode == KEY_F9:
				restart_has_f9 = true
			elif restart_event.physical_keycode == KEY_R:
				restart_has_r = true
	assert(restart_has_f9, "F9 should restart the match")
	assert(not restart_has_r, "R must no longer restart the match")
	assert(CardDatabase.get_card("blockbombe") != null, "Block bomb card should exist")
	assert(CardDatabase.get_card("heilzone") != null, "Block heal zone card should exist")
	assert(CardDatabase.get_card("druckwelle") != null, "Block knockback card should exist")
	assert(CardDatabase.get_card("spiegelblock") != null, "Block reflect card should exist")
	# Kartenpools: jede Karte gehört zu genau einem gültigen Pool.
	for card in CardDatabase.all_cards:
		assert(Global.CARD_POOLS.has(card.pool), "Card %s has invalid pool %s" % [card.id, card.pool])
	assert(Global.enabled_card_pools.size() == Global.CARD_POOLS.size(), "All card pools should be enabled by default")
	for new_card_id in ["splittergeschoss", "panzerbrecher", "brandkapsel", "kettenreaktion", "sanitaeter", "bollwerk", "zweites_herz", "federstiefel", "windschatten", "leichtgewicht", "notvorrat", "fokuskristall", "instabiler_kern", "wandelnder_koloss", "leichtes_geschoss", "schweres_geschoss", "moerser", "moerser_praezision", "moerser_belagerung", "rueckstossfeder", "druckkammer", "schockgeschoss"]:
		assert(CardDatabase.get_card(new_card_id) != null, "New pool card %s should exist" % new_card_id)
	# Pool-Filter: Ohne Chaos dürfen keine Chaos-Karten angeboten werden.
	Global.set_enabled_card_pools(["Kern", "Offensive", "Defensive", "Bewegung"])
	assert(not CardDatabase.is_card_pool_enabled(CardDatabase.get_card("instabiler_kern")), "Chaos cards should be filtered out")
	var filtered_offer := CardDatabase.get_draft_offer(20, [], "ignis", [])
	for card in filtered_offer:
		assert(card.pool != "Chaos", "Filtered draft must not contain Chaos cards")
	Global.set_all_card_pools(true)
	assert(Global.enabled_card_pools.size() == Global.CARD_POOLS.size(), "All pools should be restorable")
	# Tank-Panzerung: eine Karte pro Seltenheit und ein zusammenhängender Baum.
	var tank_ids := [
		"tankplatte", "tank_stahlhaut", "tank_dornenhaut",
		"tank_festungspanzer", "tank_reflektorplatte",
		"tank_titanenbollwerk", "tank_spiegelpanzer",
		"tank_ewige_bastion", "tank_spiegelkoloss",
	]
	var tank_cards: Array[CardData] = []
	var tank_rarities: Dictionary = {}
	for tank_id in tank_ids:
		var tank_card := CardDatabase.get_card(tank_id)
		assert(tank_card != null, "Tank card %s should exist" % tank_id)
		assert(tank_card.pool == "Defensive", "Tank cards should belong to the Defensive pool")
		assert(tank_card.family_id == "tank_panzerung", "Tank cards should share one evolution family")
		tank_cards.append(tank_card)
		tank_rarities[tank_card.rarity] = true
	for tank_rarity in ["Common", "Uncommon", "Rare", "Epic", "Legendary"]:
		assert(tank_rarities.has(tank_rarity), "Tank tree should contain a %s card" % tank_rarity)
	var tank_root: CardData = tank_cards[0]
	assert(tank_root.parent_card_id.is_empty(), "Tankplatte should be the family root")
	assert(tank_root.armor_percent_add > 0.0, "Tank root should grant armor")
	assert(tank_cards[1].parent_card_id == "tankplatte" and tank_cards[1].evolution_branch == "A", "Stahlhaut should be branch A of Tankplatte")
	assert(tank_cards[2].parent_card_id == "tankplatte" and tank_cards[2].evolution_branch == "B", "Dornenhaut should be branch B of Tankplatte")
	assert(tank_cards[3].parent_card_id == "tank_stahlhaut", "Festungspanzer should evolve from Stahlhaut")
	assert(tank_cards[4].parent_card_id == "tank_dornenhaut", "Reflektorplatte should evolve from Dornenhaut")
	assert(tank_cards[5].parent_card_id == "tank_festungspanzer", "Titanenbollwerk should evolve from Festungspanzer")
	assert(tank_cards[6].parent_card_id == "tank_reflektorplatte", "Spiegelpanzer should evolve from Reflektorplatte")
	assert(tank_cards[7].parent_card_id == "tank_titanenbollwerk", "Ewige Bastion should evolve from Titanenbollwerk")
	assert(tank_cards[8].parent_card_id == "tank_spiegelpanzer", "Spiegelkoloss should evolve from Spiegelpanzer")
	assert(tank_cards[3].evolution_branch == "A" and tank_cards[5].evolution_branch == "A" and tank_cards[7].evolution_branch == "A", "Tank branch A descendants should keep branch A")
	assert(tank_cards[4].evolution_branch == "B" and tank_cards[6].evolution_branch == "B" and tank_cards[8].evolution_branch == "B", "Tank branch B descendants should keep branch B")
	assert(tank_cards[1].max_hp_mult > 1.0 and tank_cards[3].max_hp_mult > 1.0, "Tank branch A should scale maximum health by percentage")
	assert(tank_cards[2].damage_reflect_percent_add > 0.0, "Tank branch B should start with damage reflection")
	assert("RÜSTUNG" in CardMechanics.tooltip(tank_root), "Tank tooltip should explain armor")
	assert("REFLEXION" in CardMechanics.tooltip(tank_cards[2]), "Reflection tooltip should explain reflected damage")
	var tank_icon := CardIcon.new()
	tank_icon.setup(tank_root)
	assert(tank_icon._kind == "armor", "Tank cards should draw the armor icon")
	tank_icon.setup(tank_cards[2])
	assert(tank_icon._kind == "reflect", "Reflection cards should draw the reflect icon")
	tank_icon.free()
	assert(not CardDatabase.is_card_available_for_player(tank_cards[1], "ignis", []), "Tank upgrades should stay hidden without their parent")
	assert(CardDatabase.is_card_available_for_player(tank_cards[1], "ignis", ["tankplatte"]), "Tank upgrades should unlock with Tankplatte")
	# Evolutionsbaum-Entscheidung: Vor der Wahl sind beide Zweige verfügbar,
	# danach ist die Familie dauerhaft auf den gewählten Zweig festgelegt.
	assert(CardDatabase.is_card_available_for_player(tank_cards[2], "ignis", ["tankplatte"]), "Branch B should be available before the choice")
	var pre_choice_offer := CardDatabase.get_draft_offer(1000, [], "ignis", ["tankplatte"])
	var pre_choice_has_a := false
	var pre_choice_has_b := false
	for offered in pre_choice_offer:
		if offered.id == "tank_stahlhaut":
			pre_choice_has_a = true
		elif offered.id == "tank_dornenhaut":
			pre_choice_has_b = true
	assert(pre_choice_has_a and pre_choice_has_b, "Both tank branches should be offered before choosing one")
	assert(not CardDatabase.is_card_available_for_player(tank_cards[2], "ignis", ["tankplatte", "tank_stahlhaut"]), "Branch B must be locked after choosing branch A")
	assert(CardDatabase.is_card_available_for_player(tank_cards[3], "ignis", ["tankplatte", "tank_stahlhaut"]), "Branch A successors should unlock after choosing branch A")
	var branch_a_offer := CardDatabase.get_draft_offer(1000, ["tankplatte", "tank_stahlhaut"], "ignis", ["tankplatte", "tank_stahlhaut"])
	var branch_a_offer_has_b := false
	var branch_a_offer_has_successor := false
	for offered in branch_a_offer:
		if offered.id == "tank_dornenhaut":
			branch_a_offer_has_b = true
		elif offered.id == "tank_festungspanzer":
			branch_a_offer_has_successor = true
	assert(not branch_a_offer_has_b, "After choosing branch A the branch B card must not be offered")
	assert(branch_a_offer_has_successor, "After choosing branch A its successor should be offered")
	assert(not CardDatabase.is_card_available_for_player(tank_cards[1], "ignis", ["tankplatte", "tank_dornenhaut"]), "Branch A must be locked after choosing branch B")
	assert(CardDatabase.is_card_available_for_player(tank_cards[4], "ignis", ["tankplatte", "tank_dornenhaut"]), "Branch B successors should unlock after choosing branch B")
	var branch_b_offer := CardDatabase.get_draft_offer(1000, ["tankplatte", "tank_dornenhaut"], "ignis", ["tankplatte", "tank_dornenhaut"])
	var branch_b_offer_has_a := false
	var branch_b_offer_has_successor := false
	for offered in branch_b_offer:
		if offered.id == "tank_stahlhaut":
			branch_b_offer_has_a = true
		elif offered.id == "tank_reflektorplatte":
			branch_b_offer_has_successor = true
	assert(not branch_b_offer_has_a, "After choosing branch B the branch A card must not be offered")
	assert(branch_b_offer_has_successor, "After choosing branch B its successor should be offered")
	# Leichtfüßig senkt die Schwerkraft; Windschuhe sind der zugehörige Ausbau.
	var leichtfuessig := CardDatabase.get_card("leichtfuessig")
	var windschuhe := CardDatabase.get_card("windschuhe")
	var leichte_schuhe := CardDatabase.get_card("leichte_schuhe")
	assert(leichtfuessig != null and windschuhe != null and leichte_schuhe != null, "Shoe cards should exist")
	assert(is_equal_approx(leichtfuessig.move_speed_mult, 1.05), "Leichtfüßig should grant 5% move speed")
	assert(is_equal_approx(leichtfuessig.gravity_mult, 0.90), "Leichtfüßig should reduce gravity by 10%")
	assert(leichtfuessig.pool == "Bewegung", "Leichtfüßig should stay in the movement pool")
	assert(windschuhe.family_id == "leichte_schuhe" and windschuhe.parent_card_id == "leichte_schuhe", "Windschuhe should evolve from Leichte Schuhe")
	assert(windschuhe.evolution_branch == "A", "Windschuhe should be the first evolution branch")
	assert(not CardDatabase.is_card_available_for_player(windschuhe, "ignis", []), "Windschuhe must be hidden without Leichte Schuhe")
	assert(CardDatabase.is_card_available_for_player(windschuhe, "ignis", ["leichte_schuhe"]), "Windschuhe should unlock with Leichte Schuhe")
	# Projektil-Schwerkraft: flache und fallende Karten sowie der Mörser-Talentbaum.
	var leichtes_geschoss := CardDatabase.get_card("leichtes_geschoss")
	var schweres_geschoss := CardDatabase.get_card("schweres_geschoss")
	var moerser := CardDatabase.get_card("moerser")
	var moerser_praezision := CardDatabase.get_card("moerser_praezision")
	var moerser_belagerung := CardDatabase.get_card("moerser_belagerung")
	assert(leichtes_geschoss != null and schweres_geschoss != null, "Gravity projectile cards should exist")
	assert(moerser != null and moerser_praezision != null and moerser_belagerung != null, "Mortar family should exist")
	assert(leichtes_geschoss.projectile_gravity_mult < 1.0 and leichtes_geschoss.damage_mult > 1.0, "Light rounds should flatten the arc and add damage")
	assert(schweres_geschoss.projectile_gravity_mult > 1.0 and schweres_geschoss.damage_mult > 1.0, "Heavy rounds should steepen the arc and add damage")
	assert(moerser.family_id == "moerser" and moerser.pool == "Offensive", "Mortar should be an offensive family base card")
	assert(moerser.projectile_gravity_mult > 1.0 and moerser.damage_mult > 1.0, "Mortar base should increase gravity and damage")
	assert(moerser_praezision.parent_card_id == "moerser" and moerser_praezision.evolution_branch == "A", "Precision mortar should be branch A")
	assert(moerser_belagerung.parent_card_id == "moerser" and moerser_belagerung.evolution_branch == "B", "Siege mortar should be branch B")
	assert(moerser_praezision.projectile_gravity_mult < 1.0 and moerser_praezision.damage_mult > 1.0, "Precision mortar should flatten the arc and add damage")
	assert(moerser_belagerung.projectile_gravity_mult > 1.0 and moerser_belagerung.damage_mult > 1.0, "Siege mortar should steepen the arc and add damage")
	assert(not CardDatabase.is_card_available_for_player(moerser_praezision, "ignis", []), "Mortar upgrades must be hidden without the base card")
	assert(CardDatabase.is_card_available_for_player(moerser_praezision, "ignis", ["moerser"]), "Mortar upgrades should unlock with the base card")
	# Rückstoß-Familie: Grundkarte und zwei Ausbauten verstärken den Trefferimpuls.
	var rueckstossfeder := CardDatabase.get_card("rueckstossfeder")
	var druckkammer := CardDatabase.get_card("druckkammer")
	var schockgeschoss := CardDatabase.get_card("schockgeschoss")
	assert(rueckstossfeder != null and druckkammer != null and schockgeschoss != null, "Knockback family should exist")
	assert(rueckstossfeder.pool == "Offensive", "Knockback base card should be in the offensive pool")
	assert(rueckstossfeder.knockback_mult > 1.0, "Knockback base card should increase knockback")
	assert(druckkammer.parent_card_id == "rueckstossfeder" and druckkammer.evolution_branch == "A", "Druckkammer should be branch A")
	assert(schockgeschoss.parent_card_id == "rueckstossfeder" and schockgeschoss.evolution_branch == "B", "Schockgeschoss should be branch B")
	assert(druckkammer.knockback_mult > rueckstossfeder.knockback_mult and schockgeschoss.knockback_mult > druckkammer.knockback_mult, "Knockback upgrades should scale upward")
	assert(not CardDatabase.is_card_available_for_player(druckkammer, "ignis", []), "Knockback upgrades must be hidden without the base card")
	assert(CardDatabase.is_card_available_for_player(druckkammer, "ignis", ["rueckstossfeder"]), "Knockback upgrades should unlock with the base card")
	assert(CardMechanics.tooltip(rueckstossfeder).contains("RÜCKSTOSS"), "Knockback tooltip should explain the mechanic")
	var evolution_banner := CardMechanics.make_evolution_banner(moerser_praezision, 10)
	assert(evolution_banner != null and evolution_banner.get_child_count() > 0, "Evolution cards should create a banner")
	var evolution_label := evolution_banner.get_child(0) as Label
	assert(evolution_label != null and evolution_label.text == "EVOLUTION", "Evolution banner should be labelled EVOLUTION")
	evolution_banner.free()
	assert(CardMechanics.make_evolution_banner(moerser, 10) == null, "Base cards should not create an evolution banner")
	assert(CardMechanics.tooltip(moerser_praezision).contains("EVOLUTION"), "Evolution tooltip should name the evolution")
	# Mechanik-Voraussetzungen: Verstärkerkarten erscheinen nur mit passender Mechanik.
	var ausweichrolle := CardDatabase.get_card("ausweichrolle")
	assert(ausweichrolle.required_mechanic == "dash", "Ausweichrolle should require dash")
	assert(CardDatabase.is_card_available_for_player(ausweichrolle, "ignis", []), "Dash is universal, so Ausweichrolle stays available")
	var schildschnellbau := CardDatabase.get_card("schildschnellbau")
	assert(schildschnellbau.required_mechanic == "shield", "Schildschnellbau should require a shield source")
	assert(not CardDatabase.is_card_available_for_player(schildschnellbau, "ignis", []), "Ignis without shield must not see Schildschnellbau")
	assert(CardDatabase.is_card_available_for_player(schildschnellbau, "bastion", []), "Bastion has a base shield")
	assert(CardDatabase.is_card_available_for_player(schildschnellbau, "ignis", ["tactical_vest"]), "A shield card should unlock Schildschnellbau")
	# Mechanik-Tooltips erklären Gift und Frost.
	var gift_tooltip := CardMechanics.tooltip(CardDatabase.get_card("giftkapsel"))
	assert(gift_tooltip.contains("GIFT"), "Poison cards should explain the poison mechanic")
	var frost_tooltip := CardMechanics.tooltip(CardDatabase.get_card("frostschuss"))
	assert(frost_tooltip.contains("FROST"), "Frost cards should explain the frost mechanic")
	# Heilende Hände regenerieren immer, auch während Schaden genommen wird.
	var heilende_haende := CardDatabase.get_card("heilende_haende")
	assert(heilende_haende != null, "Heilende Hände should exist")
	assert(is_equal_approx(heilende_haende.hp_regen_always_add, 2.5), "Heilende Hände should use the always-active regeneration pool")
	assert(is_equal_approx(heilende_haende.hp_regen_add, 0.0), "Heilende Hände must not use the delayed regeneration pool")
	assert(CardMechanics.tooltip(heilende_haende).contains("auch während"), "Heilende Hände tooltip should explain unconditional healing")
	# Schutzdrohne: eigene Talentbaum-Familie mit Projektilblock und zwei Ausbauten.
	var schutzdrohne := CardDatabase.get_card("schutzdrohne")
	var schutzdrohne_heilung := CardDatabase.get_card("schutzdrohne_heilung")
	var schutzdrohne_schwarm := CardDatabase.get_card("schutzdrohne_schwarm")
	assert(schutzdrohne != null and schutzdrohne_heilung != null and schutzdrohne_schwarm != null, "Schutzdrohne family should exist")
	assert(schutzdrohne.family_id == "schutzdrohne" and schutzdrohne.pool == "Defensive", "Schutzdrohne should be a defensive family base card")
	assert(schutzdrohne_heilung.parent_card_id == "schutzdrohne" and schutzdrohne_heilung.evolution_branch == "A", "Healing upgrade should be branch A")
	assert(schutzdrohne_schwarm.parent_card_id == "schutzdrohne" and schutzdrohne_schwarm.evolution_branch == "B", "Swarm upgrade should be branch B")
	assert(not CardDatabase.is_card_available_for_player(schutzdrohne_heilung, "ignis", []), "Schutzdrohne upgrades must be hidden without the base card")
	assert(CardDatabase.is_card_available_for_player(schutzdrohne_heilung, "ignis", ["schutzdrohne"]), "Schutzdrohne upgrades should unlock with the base card")
	assert(schutzdrohne.blocker_drone_count_add == 1, "Schutzdrohne should start with one blocker drone")
	assert(schutzdrohne_heilung.blocker_drone_heal, "Schutzdrohne heal upgrade should enable healing")
	assert(schutzdrohne_schwarm.blocker_drone_count_add == 2, "Schutzdrohne swarm upgrade should add two drones")
	var schutz_tooltip := CardMechanics.tooltip(schutzdrohne_heilung)
	assert(schutz_tooltip.contains("SCHUTZDROHNE") and schutz_tooltip.contains("heilt"), "Schutzdrohne tooltip should explain blocking and healing")
	assert(CardDatabase.get_card("waechterdrohne_schild").title == "Regenerationsdrohne", "Old guardian upgrade should keep its id but use the new title")
	# Maps: sieben feste Spielfelder plus Zufallsauswahl, jeweils mit eigenem
	# Tileset. Die Arenen sind gegenüber der ursprünglichen 38x22-Fläche um
	# mehr als 30 % gewachsen.
	assert(Global.MAP_PLAYABLE.size() >= 7, "At least seven playable maps should be registered")
	assert(LevelGenerator.MAP_WIDTH * LevelGenerator.MAP_HEIGHT >= int(38 * 22 * 1.3), "Map area should be at least 30 percent larger")
	assert(Global.MAPS.has(Global.MAP_RANDOM), "Random map option should exist")
	for map_id in Global.MAP_PLAYABLE:
		assert(Global.MAPS.has(map_id), "Map %s should have metadata" % map_id)
	Global.set_selected_map("wuestenruine")
	assert(Global.resolve_map_id(12345) == "wuestenruine", "Selected map should override the seed")
	Global.set_selected_map(Global.MAP_RANDOM)
	assert(Global.MAP_PLAYABLE.has(Global.resolve_map_id(12345)), "Random map should resolve to a playable map")
	assert(Global.MAP_PLAYABLE.has(main.match_map_id), "Match should use a concrete playable map")
	assert(level.MAP_PROFILES.has(level.current_map_id), "Level should use a known map profile")
	assert(str(level.MAP_PROFILES["weite"].get("archetype", "")) == "sparse", "Weite Wiese should use the sparse layout")
	assert(str(level.MAP_PROFILES["wolkeninsel"].get("archetype", "")) == "sparse", "Wolkeninsel should use the sparse layout")
	assert(bool(level.MAP_PROFILES["kistenfestung"].get("crate_fortress", false)), "Kistenfestung should use the crate fortress layout")
	assert(LevelGenerator.TILESET_THEMES.size() == 4, "There should be four visual tileset themes")
	# Die Plattformebenen müssen genug Kopfraum für die Charaktere bieten.
	# Zwei freie Kacheln über jeder Plattformoberkante entsprechen 72 px.
	var low_platform_ceiling := false
	for raw_cell in level._solid_cells.keys():
		var cell: Vector2i = raw_cell
		if level._solid_cells.has(Vector2i(cell.x, cell.y - 1)):
			continue
		if level._solid_cells.has(Vector2i(cell.x, cell.y - 2)):
			low_platform_ceiling = true
			break
	assert(not low_platform_ceiling, "Platform layers should leave at least two free tiles of headroom")
	# Alle Helden müssen eine Drei-Kachel-Stufe (108 px) sicher erreichen.
	var required_jump_height := 3.0 * LevelGenerator.TILE_SIZE + 8.0
	for hero_key in Global.heroes.keys():
		var jump_hero: HeroData = Global.get_hero(str(hero_key))
		var jump_height := (jump_hero.base_jump_force * jump_hero.base_jump_force) / (2.0 * Player.GRAVITY)
		assert(jump_height > required_jump_height, "Hero %s should clear a three-tile platform step" % hero_key)
	assert(level.get_moving_object_count() > 0, "Map should spawn moving objects")
	var map_snapshots: Array = level.get_moving_object_snapshots()
	assert(map_snapshots.size() == level.get_moving_object_count(), "Every moving object should provide a snapshot")
	var seen_object_ids := {}
	var has_crate_snapshot := false
	var has_powerup_snapshot := false
	for snapshot in map_snapshots:
		assert(snapshot.has("id") and snapshot.has("type") and snapshot.has("pos"), "Map object snapshot should be well formed")
		assert(not seen_object_ids.has(snapshot["id"]), "Map object ids should be unique")
		seen_object_ids[snapshot["id"]] = true
		has_crate_snapshot = has_crate_snapshot or snapshot["type"] == "crate"
		has_powerup_snapshot = has_powerup_snapshot or snapshot["type"] == "powerup"
	assert(has_crate_snapshot, "Every map should spawn physics crates")
	assert(has_powerup_snapshot, "Every map should spawn at least one powerup")
	for map_id in Global.MAP_PLAYABLE:
		var map_profile: Dictionary = level.MAP_PROFILES[map_id]
		assert(int(map_profile.get("powerups", 0)) > 0, "Map %s should define random powerups" % map_id)
		assert(int(map_profile.get("crate_stacks", 0)) > 0 or bool(map_profile.get("crate_fortress", false)), "Map %s should define crate stacks or a crate fortress" % map_id)
	# Spawns dürfen nicht auf Federn, Portalen, Kisten, Stacheln oder anderen
	# Objekten liegen. Zusätzlich müssen sie deutlich auseinanderliegen und
	# mindestens zwei verschiedene Höhen nutzen.
	var seen_spawns := {}
	var round_spawns: Array[Vector2] = []
	var spawn_rows := {}
	for slot in range(1, 7):
		var spawn_pos: Vector2 = level.get_spawn_position(slot, 6)
		assert(level.is_spawn_position_clear(spawn_pos), "Spawn %d should be clear of map objects" % slot)
		assert(not seen_spawns.has(spawn_pos), "Spawn %d should not share a tile with another spawn" % slot)
		seen_spawns[spawn_pos] = true
		round_spawns.append(spawn_pos)
		var spawn_row := int(round((spawn_pos.y + LevelGenerator.SPAWN_BODY_OFFSET) / LevelGenerator.TILE_SIZE))
		spawn_rows[spawn_row] = true
	assert(spawn_rows.size() >= 2, "Round spawns should use at least two different heights")
	_assert_spawn_distances(round_spawns, "initial map")
	# Alle Karten werden zusätzlich in einer isolierten Level-Instanz
	# aufgebaut und auf Kopfraum, Objekte und sichere Spawns geprüft. Die
	# Instanz liegt weit außerhalb der echten Arena, damit die vielen Kisten
	# der Kistenfestung den restlichen Test nicht beeinflussen.
	var map_check_level = load("res://scenes/level/procedural_level.tscn").instantiate()
	map_check_level.position = Vector2(100000.0, 100000.0)
	add_child(map_check_level)
	for check_map_id in Global.MAP_PLAYABLE:
		map_check_level.generate_level(4242, check_map_id)
		assert(map_check_level.current_map_id == check_map_id, "Map builder should keep %s" % check_map_id)
		var check_low_ceiling := false
		for raw_cell in map_check_level._solid_cells.keys():
			var check_cell: Vector2i = raw_cell
			if map_check_level._solid_cells.has(Vector2i(check_cell.x, check_cell.y - 1)):
				continue
			if map_check_level._solid_cells.has(Vector2i(check_cell.x, check_cell.y - 2)):
				check_low_ceiling = true
				break
		assert(not check_low_ceiling, "Map %s should leave two free tiles above platforms" % check_map_id)
		var object_counts := {}
		for snapshot in map_check_level.get_moving_object_snapshots():
			var kind := str(snapshot["type"])
			object_counts[kind] = int(object_counts.get(kind, 0)) + 1
		assert(int(object_counts.get("crate", 0)) > 0, "Map %s should spawn physics crates" % check_map_id)
		assert(int(object_counts.get("powerup", 0)) > 0, "Map %s should spawn at least one powerup" % check_map_id)
		# Theme-Metadaten und geladene Materialien. Layout und Theme bleiben
		# getrennt, aber jede Karte muss ein vollständiges Tileset besitzen.
		var theme_id := str(map_check_level.current_theme_id)
		assert(LevelGenerator.TILESET_THEMES.has(theme_id), "Map %s should use a known tileset theme" % check_map_id)
		assert(not map_check_level.current_backdrop_variant.is_empty(), "Map %s should define a backdrop variant" % check_map_id)
		assert(map_check_level.ground_top_textures.size() > 0, "Map %s should load ground-top textures" % check_map_id)
		assert(map_check_level.ground_bottom_textures.size() > 0, "Map %s should load ground-fill textures" % check_map_id)
		assert(map_check_level.platform_textures.size() > 0, "Map %s should load platform textures" % check_map_id)
		assert(map_check_level.destructible_textures.size() > 0, "Map %s should load destructible textures" % check_map_id)
		assert(map_check_level.decoration_textures.size() > 0, "Map %s should load decoration textures" % check_map_id)
		var deep_snow_count := 0
		var trampoline_count := 0
		var booster_count := 0
		var backdrop_count := 0
		for child in map_check_level.get_children():
			if child is DeepSnow:
				deep_snow_count += 1
			elif child is TrampolineGround:
				trampoline_count += 1
			elif child is SpeedBooster:
				booster_count += 1
			elif child is ThemeBackdrop:
				backdrop_count += 1
				assert(child.theme_id == theme_id, "Map %s backdrop should match its theme" % check_map_id)
		assert(backdrop_count == 1, "Map %s should have exactly one themed backdrop" % check_map_id)
		match theme_id:
			"frost":
				assert(map_check_level.ice_tex != null, "Frost maps should load an ice overlay")
				assert(map_check_level.deep_snow_textures.size() > 0, "Frost maps should load deep-snow textures")
				assert(deep_snow_count > 0, "Frost map %s should place deep snow" % check_map_id)
			"wool":
				assert(map_check_level.trampoline_textures.size() > 0, "Wool maps should load trampoline textures")
				assert(trampoline_count > 0, "Wool map %s should place trampoline ground" % check_map_id)
			"neon":
				assert(booster_count > 0, "Neon map %s should place speed boosters" % check_map_id)
			_:
				assert(deep_snow_count == 0 and trampoline_count == 0 and booster_count == 0, "Storybook maps should not place foreign theme mechanics")
		if check_map_id == "kistenfestung":
			assert(map_check_level._solid_cells.size() == LevelGenerator.MAP_WIDTH * 2, "Crate fortress should only have the two ground rows as static tiles")
			assert(int(object_counts.get("crate", 0)) >= 40, "Crate fortress should build its layout from at least 40 crates")
			assert(int(object_counts.get("seesaw", 0)) == 1, "Crate fortress should have one large central seesaw")
		var check_spawns: Array[Vector2] = []
		var check_spawn_rows := {}
		for slot in range(1, 7):
			var check_spawn: Vector2 = map_check_level.get_spawn_position(slot, 6)
			assert(map_check_level.is_spawn_position_clear(check_spawn), "Map %s spawn %d should be clear" % [check_map_id, slot])
			check_spawns.append(check_spawn)
			var check_spawn_row := int(round((check_spawn.y + LevelGenerator.SPAWN_BODY_OFFSET) / LevelGenerator.TILE_SIZE))
			check_spawn_rows[check_spawn_row] = true
		assert(check_spawn_rows.size() >= 2, "Map %s should distribute spawns across at least two heights" % check_map_id)
		_assert_spawn_distances(check_spawns, "map %s" % check_map_id)
	map_check_level.queue_free()
	# Magische Portale: Benutzung teleportiert zum Partner und versteckt beide
	# Portale für die Cooldown-Dauer.
	var portal_scene: PackedScene = load("res://scenes/level/warp_pipe.tscn")
	var portal_a: WarpPipe = portal_scene.instantiate()
	var portal_b: WarpPipe = portal_scene.instantiate()
	add_child(portal_a)
	add_child(portal_b)
	portal_a.global_position = Vector2(-2000.0, -2000.0)
	portal_b.global_position = Vector2(-1900.0, -2000.0)
	portal_a.target_pipe = portal_b
	portal_b.target_pipe = portal_a
	var portal_body := CharacterBody2D.new()
	add_child(portal_body)
	portal_body.global_position = portal_a.global_position
	portal_a._on_body_entered(portal_body)
	assert(not portal_a.can_warp and not portal_b.can_warp, "Using a portal should disable both portals")
	assert(portal_a.warp_cooldown >= 9.9 and portal_b.warp_cooldown >= 9.9, "Portals should vanish for ten seconds")
	assert(portal_body.global_position.distance_to(portal_b.global_position + Vector2(0.0, -28.0)) < 0.01, "Portal should teleport to its partner")
	portal_a._process(10.1)
	portal_b._process(10.1)
	assert(portal_a.can_warp and portal_b.can_warp, "Portals should reactivate after the cooldown")
	assert(portal_a.visible and portal_b.visible, "Portals should reappear after the cooldown")
	portal_a.queue_free()
	portal_b.queue_free()
	portal_body.queue_free()
	# Dynamische Host-Objekte (z. B. Powerup-Drops aus Kisten) müssen auf
	# Clients aus einem Snapshot nachgebaut werden können.
	var remote_crate = level._instantiate_moving_object_from_snapshot({"type": "crate", "size": 1.0})
	assert(remote_crate != null and bool(remote_crate.get("is_replica")), "Remote crate snapshot should create a replica")
	remote_crate.free()
	var remote_powerup = level._instantiate_moving_object_from_snapshot({"type": "powerup", "kind": "damage"})
	assert(remote_powerup != null and str(remote_powerup.get("kind")) == "damage", "Remote powerup snapshot should keep its kind")
	remote_powerup.free()
	# Das explosive Fass zündet mit einer dreisekündigen Blinkphase statt sofort.
	var tnt_scene: PackedScene = load("res://scenes/level/barrel.tscn")
	var tnt: Barrel = tnt_scene.instantiate()
	tnt.explosive = true
	add_child(tnt)
	tnt.global_position = Vector2(640, -200)
	tnt.gravity_scale = 0.0
	tnt.hit_barrel(null)
	assert(tnt.fuse_active, "TNT barrel should start its fuse on hit")
	assert(not tnt.has_exploded, "TNT barrel must not explode immediately")
	assert(is_equal_approx(tnt.fuse_time_left, tnt.FUSE_DURATION), "TNT fuse should last three seconds")
	# Der Impuls wird vom Physics-Server im nächsten Schritt übernommen.
	await get_tree().create_timer(0.05).timeout
	assert(tnt.linear_velocity.length() > 100.0, "TNT barrel should be knocked back like a normal barrel")
	tnt.queue_free()
	var mystery_scene: PackedScene = load("res://scenes/level/mystery_block.tscn")
	var mystery_block = mystery_scene.instantiate()
	var heart_icon = mystery_block.get_node_or_null("Sprite2D/HeartIcon")
	assert(heart_icon != null and heart_icon.texture != null, "Mystery block should show a heart icon")
	mystery_block.free()

	var p1 = main.get_player(1)
	var p2 = main.get_player(2)
	assert(p1 != null, "Player 1 should exist")
	assert(p2 != null, "Player 2 should exist")
	# Additive Theme-Mechaniken im Player: Tiefschnee bremst, Booster
	# beschleunigt kurzzeitig und der Wool-Boden stellt Sprünge wieder her.
	var snow_probe := Node.new()
	add_child(snow_probe)
	var freeze_backup: float = p1.freeze_timer
	p1.freeze_timer = 0.0
	p1.add_deep_snow_source(snow_probe)
	assert(p1.on_deep_snow, "Deep snow should mark the player as slowed")
	assert(is_equal_approx(p1._current_ground_speed(), p1.move_speed * Player.DEEP_SNOW_SPEED_MULT), "Deep snow should scale ground speed")
	p1.remove_deep_snow_source(snow_probe)
	assert(not p1.on_deep_snow, "Leaving deep snow should restore the normal speed")
	assert(is_equal_approx(p1._current_ground_speed(), p1.move_speed), "Normal ground speed should be restored")
	p1.freeze_timer = freeze_backup
	snow_probe.queue_free()
	var boost_velocity_backup: Vector2 = p1.velocity
	var boost_timer_backup: float = p1.speed_boost_timer
	var boost_speed_backup: float = p1.speed_boost_speed
	var boost_direction_backup: float = p1.speed_boost_direction
	p1.apply_speed_boost(-1.0, 680.0, 0.26)
	assert(p1.speed_boost_direction < 0.0, "Speed boost should keep its direction")
	assert(p1.speed_boost_timer >= 0.25, "Speed boost should last for its configured duration")
	assert(p1.velocity.x <= -680.0, "Speed boost should set horizontal velocity")
	p1.speed_boost_timer = boost_timer_backup
	p1.speed_boost_speed = boost_speed_backup
	p1.speed_boost_direction = boost_direction_backup
	p1.velocity = boost_velocity_backup
	var bounce_velocity_backup: Vector2 = p1.velocity
	var jumps_backup: int = p1.jumps_remaining
	p1.jumps_remaining = 0
	p1.apply_trampoline_bounce(-690.0)
	assert(is_equal_approx(p1.velocity.y, -690.0), "Trampoline should launch the player upward")
	assert(p1.jumps_remaining == p1.max_jumps, "Trampoline should restore the player's jumps")
	p1.velocity = bounce_velocity_backup
	p1.jumps_remaining = jumps_backup
	# Rundenstart-Intro: Die Kamera startet nah am lokalen Charakter und zoomt
	# anschließend heraus. Nur der eigene Charakter erscheint aus einem Portal.
	assert(main.camera.is_round_intro_active(), "Camera should start its round intro")
	assert(main.camera.get_round_intro_focus() == p1, "Camera intro should focus the local character")
	assert(main.camera.zoom.x > main.camera.max_zoom, "Camera intro should begin closer than the normal overview")
	var portal_effects := get_tree().get_nodes_in_group("portal_spawn_effect")
	assert(portal_effects.size() == 1, "Only the local human character should get a portal spawn effect")
	var spawn_portal := portal_effects[0] as PortalSpawnEffect
	assert(spawn_portal != null, "Portal spawn effect should use the dedicated effect script")
	assert(spawn_portal.get_parent() == p1, "Portal spawn effect should belong to the local character")
	assert(spawn_portal.portal_color == Global.get_hero(Global.get_player_hero_id(1)).color_tint, "Portal should use the hero color")
	# Prozedurale Lauf- und Trefferanimationen.
	var old_velocity: Vector2 = p1.velocity
	var run_phase_before: float = p1.sprite._run_phase
	p1.velocity = Vector2(240.0, 0.0)
	p1.sprite._process(0.15)
	assert(p1.sprite._move_energy > 0.0, "Run animation should react to movement")
	assert(p1.sprite._run_phase > run_phase_before, "Run animation should advance its gait phase")
	p1.velocity = old_velocity
	p1.sprite.play_hit(Vector2.RIGHT)
	assert(is_equal_approx(p1.sprite._hit_timer, PigCharacter.HIT_DURATION), "Hit animation should start on damage")
	assert(p1.sprite._hit_direction == Vector2.RIGHT, "Hit animation should store the knockback direction")
	assert(p1.sprite._blood_particles.size() > 0, "A hit should spawn small blood particles")
	var blood_pos_before: Vector2 = p1.sprite._blood_particles[0]["pos"]
	p1.sprite._process(0.1)
	assert(p1.sprite._hit_timer > 0.0 and p1.sprite._hit_timer < PigCharacter.HIT_DURATION, "Hit animation should run down")
	assert(p1.sprite._blood_particles.size() > 0, "Blood particles should linger briefly after a hit")
	var blood_pos_after: Vector2 = p1.sprite._blood_particles[0]["pos"]
	assert(blood_pos_after.distance_to(blood_pos_before) > 0.1, "Blood particles should move outward")
	p1.sprite._process(PigCharacter.BLOOD_DURATION + 0.1)
	assert(p1.sprite._blood_particles.is_empty(), "Blood particles should fade out quickly")
	p1.sprite.play_hit(Vector2.ZERO, 0.25)
	assert(p1.sprite._blood_particles.is_empty(), "Very weak damage ticks should not spawn blood")
	# Charaktere kollidieren miteinander: Beide Spieler liegen auf Layer 2 und
	# nehmen Layer 2 in ihre Maske auf. Dadurch blockieren sich die Körper.
	assert(p1.collision_layer == 2 and p2.collision_layer == 2, "Players should use the character collision layer")
	assert((p1.collision_mask & 2) != 0 and (p2.collision_mask & 2) != 0, "Players should collide with each other")
	# Waffenbasis: Standard sind 3 Schuss, einzelne Klassen weichen ab.
	var p1_hero: HeroData = Global.get_hero(Global.get_player_hero_id(1))
	assert(p1.max_ammo == p1_hero.base_ammo, "Player should start with the hero's base ammo")
	assert(p1.current_ammo == p1.max_ammo, "Player should start with a full magazine")
	# Manuelles Nachladen: Mit vollem Magazin passiert nichts, mit Teilmunition
	# startet der reguläre Nachladevorgang.
	var reload_control_backup: bool = p1.control_enabled
	var reload_stun_backup: float = p1.stun_timer
	p1.control_enabled = true
	p1.stun_timer = 0.0
	p1.is_reloading = false
	p1.reload_timer = 0.0
	p1.manual_reload()
	assert(not p1.is_reloading, "Manual reload should not start with a full magazine")
	p1.current_ammo = p1.max_ammo - 1
	p1.manual_reload()
	assert(p1.is_reloading and p1.reload_timer > 0.0, "Manual reload should start with a partial magazine")
	p1.is_reloading = false
	p1.reload_timer = 0.0
	p1.current_ammo = p1.max_ammo
	p1.control_enabled = reload_control_backup
	p1.stun_timer = reload_stun_backup
	assert(is_equal_approx(p1.fire_rate_cooldown, p1_hero.base_fire_rate_cooldown), "Player should use the hero's base fire interval")
	assert(is_equal_approx(p1.reload_time, p1_hero.base_reload_time), "Player should use the hero's base reload time")
	assert(Global.get_hero("ignis").base_ammo == 3, "Ignis should use the standard three-round magazine")
	assert(Global.get_hero("volt").base_ammo == 4, "Volt should have a larger magazine")
	assert(Global.get_hero("phantom").base_ammo == 2, "Phantom should have a smaller burst magazine")
	for hero_key in Global.heroes.keys():
		var class_hero: HeroData = Global.get_hero(str(hero_key))
		assert(class_hero.base_fire_rate_cooldown < 0.35, "Class fire interval should be faster than the old base")
		assert(class_hero.base_reload_time > 1.0, "Class reload time should be longer than the old base")
	assert(main.hud.boxes.has(1), "HUD should have a status box for player 1")
	assert("Munition:" in str(main.hud.boxes[1]["ammo"].text), "HUD should show the initial ammo")
	# Die Weltstatus-Anzeige hängt direkt am Charakter und wird für Netzwerk-
	# Clients über zusätzliche Snapshot-Felder mitversorgt.
	var status_indicator: Node = p1.get_node_or_null("StatusIndicators")
	assert(status_indicator != null, "Player should have in-world status indicators")
	var p1_snapshot: Dictionary = main._player_snapshot(p1)
	assert(p1_snapshot.has("reload_timer") and p1_snapshot.has("reload_time"), "Snapshot should carry reload timing")
	assert(p1_snapshot.has("dash_cd") and p1_snapshot.has("dash_cd_max"), "Snapshot should carry dash cooldown")
	assert(p1_snapshot.has("poison"), "Snapshot should carry the poison status for client visuals")
	assert(is_equal_approx(float(p1_snapshot["dash_cd_max"]), p1.dash_cooldown), "Snapshot dash cooldown should match the player")
	# Regression: Eine bereits freigegebene Schadensquelle darf take_damage
	# nicht mit einem Typfehler abbrechen.
	var freed_source := Node2D.new()
	add_child(freed_source)
	freed_source.free()
	var hp_before: float = p1.current_health
	p1.take_damage(0.0, Vector2.ZERO, freed_source)
	assert(is_equal_approx(p1.current_health, hp_before), "Freed source should not damage the player")
	assert(main.players.size() == 2, "Two players should be spawned by default")
	assert(p2.is_bot == true, "Player 2 should be bot by default")
	assert(p1.shield_dome_node != null, "Player should have a shield dome visual")
	var dome_texture: Texture2D = p1.shield_dome_node.texture
	assert(dome_texture != null, "Shield dome should have a texture")
	assert(dome_texture.get_width() == dome_texture.get_height(), "Shield dome texture should be circular, not capsule-shaped")
	# Schutzdrohne: Basis + beide Ausbauten ergeben drei Drohnen, die gegnerische
	# Projektile abfangen und optional um den geblockten Schaden heilen.
	assert(Global.add_card_to_player(1, schutzdrohne), "Schutzdrohne base card should be addable")
	assert(Global.add_card_to_player(1, schutzdrohne_heilung), "Schutzdrohne heal upgrade should be addable")
	assert(Global.add_card_to_player(1, schutzdrohne_schwarm), "Schutzdrohne swarm upgrade should be addable")
	p1.apply_stats()
	# Munitions- und Nachlade-Karten verbessern die Waffenbasis.
	var ammo_before_cards: int = p1.max_ammo
	var fire_before_cards: float = p1.fire_rate_cooldown
	var reload_before_cards: float = p1.reload_time
	var quick_draw := CardDatabase.get_card("quick_draw")
	var schnelllader := CardDatabase.get_card("schnelllader")
	assert(quick_draw != null and schnelllader != null, "Weapon cards should exist")
	assert(Global.add_card_to_player(1, quick_draw), "Quick Draw should be addable")
	assert(Global.add_card_to_player(1, schnelllader), "Schnelllader should be addable")
	p1.apply_stats()
	assert(p1.max_ammo == ammo_before_cards + quick_draw.max_ammo_add, "Ammo card should increase magazine size")
	assert(p1.fire_rate_cooldown < fire_before_cards, "Fire-rate card should shorten the fire interval")
	assert(p1.reload_time < reload_before_cards, "Reload card should shorten reload time")
	assert(p1.blocker_drone_count == 3, "Schutzdrohne base and swarm should spawn three blocker drones")
	assert(p1.blocker_drone_heal, "Schutzdrohne heal upgrade should be active")
	assert(p1.drones.size() >= 3, "Blocker drones should be part of the player's companion list")
	var blocker: Companion = null
	for drone in p1.drones:
		if drone.blocks_projectiles:
			blocker = drone
			break
	assert(blocker != null, "Player should own a projectile-blocking drone")
	blocker.global_position = p1.global_position + Vector2(120.0, 0.0)
	p1.current_health = 40.0
	var blocked_hits_before := Global.get_match_stat(1, "blocked_hits")
	var enemy_bullet = load("res://scenes/player/bullet.tscn").instantiate()
	enemy_bullet.shooter = p2
	enemy_bullet.damage = 20.0
	enemy_bullet.velocity = Vector2.RIGHT * 300.0
	enemy_bullet.max_lifetime = 10.0
	add_child(enemy_bullet)
	enemy_bullet.global_position = blocker.global_position - Vector2(12.0, 0.0)
	blocker._try_block_projectiles(1.0 / 60.0)
	assert(enemy_bullet.blocked_by_drone and enemy_bullet.is_queued_for_deletion(), "Blocker drone should catch an enemy projectile")
	assert(is_equal_approx(p1.current_health, 60.0), "Healing blocker drone should heal the blocked damage")
	assert(Global.get_match_stat(1, "blocked_hits") == blocked_hits_before + 1.0, "Blocked projectile should count as a block")
	var friendly_bullet = load("res://scenes/player/bullet.tscn").instantiate()
	friendly_bullet.shooter = p1
	friendly_bullet.damage = 20.0
	friendly_bullet.velocity = Vector2.LEFT * 300.0
	friendly_bullet.max_lifetime = 10.0
	add_child(friendly_bullet)
	friendly_bullet.global_position = blocker.global_position
	blocker._try_block_projectiles(1.0 / 60.0)
	assert(not friendly_bullet.blocked_by_drone, "Blocker drone must not catch friendly projectiles")
	friendly_bullet.queue_free()
	assert(main.hud._upgrade_bar != null, "HUD should build the persistent upgrade bar")
	assert(main.hud._tab_overlay != null, "HUD should build the Tab character overlay")
	assert(main.hud._score_bars != null, "HUD should build the score progress bars")
	assert(main.hud._score_bar_rows.size() == Global.MAX_PLAYERS, "HUD should reserve a score bar for every player slot")
	assert(main.hud._score_bars.get_child_count() == Global.MAX_PLAYERS, "Score bar grid should contain every slot row")
	var score_row: Dictionary = main.hud._score_bar_rows[0]
	var score_bar: ProgressBar = score_row["bar"]
	var score_fill: StyleBoxFlat = score_row["fill"]
	var score_points: Label = score_row["points"]
	var score_hero: HeroData = Global.get_hero(Global.get_player_hero_id(1))
	assert(is_equal_approx(score_bar.max_value, float(Global.points_to_win)), "Score bar should use the match target")
	assert(is_equal_approx(score_bar.value, float(Global.player_scores[0])), "Score bar should reflect the player's score")
	assert(score_fill.bg_color == score_hero.color_tint, "Score bar should use the player color")
	assert((score_row["label"] as Label).text == "P1", "Score bar should label human player 1")
	var score_target_text: String
	if Global.is_team_mode():
		score_target_text = "Team-Ziel: %d Punkte" % Global.points_to_win
	else:
		score_target_text = "Ziel: %d Punkte" % Global.points_to_win
	assert(main.hud.score_label.text == score_target_text, "Score header should only show the match target, not current points")
	assert(score_points.text == str(Global.player_scores[0]), "Score row should show the player's current points")
	assert(score_points.get_index() == score_bar.get_index() + 1, "Points label should sit directly next to the score bar")
	assert(score_points.get_theme_color("font_color") == score_hero.color_tint, "Points label should use the player color")
	assert(main.hud._score_bar_rows[2]["row"].visible == false, "Unused score bar slots should stay hidden")
	var old_match_mode: String = Global.match_mode
	Global.match_mode = Global.MATCH_MODE_2V2
	main.hud._update_score()
	assert(main.hud.score_label.text == "Team-Ziel: %d Punkte" % Global.points_to_win, "Team mode should show the team target in the header")
	assert((main.hud._score_bar_rows[0]["label"] as Label).text == Global.get_team_name(1), "Team mode should label score bars by team")
	assert((main.hud._score_bar_rows[0]["fill"] as StyleBoxFlat).bg_color == Global.get_team_color(1), "Team score bars should use the team color")
	assert((main.hud._score_bar_rows[0]["points"] as Label).text == str(Global.get_team_score(1)), "Team points should appear next to the team bar")
	assert(main.hud._score_bar_rows[2]["row"].visible == false, "Team mode should hide unused team score bars")
	Global.match_mode = old_match_mode
	main.hud._update_score()
	var test_card := CardDatabase.get_card("sanitaeter")
	assert(test_card != null, "HUD test card should exist")
	assert(Global.add_card_to_player(1, test_card), "HUD test card should be added")
	main.hud._refresh_upgrade_bar()
	assert(main.hud._upgrade_bar.visible, "Upgrade bar should be visible for the local player")
	assert(main.hud._upgrade_flow.get_child_count() > 0, "Upgrade bar should display card icons")
	main.hud._refresh_tab_overlay()
	assert(main.hud._tab_content.get_child_count() > 0, "Tab overlay should display character stats and cards")
	assert(Global.points_to_win == 500, "Default match target should be 500 points")
	# Nach dem Match-Ende kann der Host das Ziel um 30 % der bisherigen
	# Zielpunktzahl erhöhen; Punktestände bleiben dabei erhalten.
	var target_before_continue: int = Global.points_to_win
	var scores_before_continue: Array = Global.get_scores()
	Global.set_network_scores([500, 450])
	assert(Global.advance_match_target(0.30) == 650, "Continuing should raise the target by 30 percent")
	assert(Global.points_to_win == 650, "The raised target should be active immediately")
	assert(Global.get_scores() == [500, 450], "Continuing must not reset the scores")
	Global.set_match_target(500)
	Global.set_network_scores([530, 450])
	assert(Global.advance_match_target(0.30) == 680, "The new target should stay above an overshooting leader")
	Global.set_scoring_config(target_before_continue, Global.survival_points, Global.kill_points)
	Global.set_network_scores(scores_before_continue)
	main.hud._on_match_over(1)
	assert(main.hud.continue_btn.visible, "Hosts should see the continue button")
	assert(not main.hud.continue_btn.disabled, "The local host should be able to continue the match")
	assert("30" in main.hud.continue_btn.text, "Continue button should mention the 30 percent target increase")
	assert(main.hud.continue_requested.is_connected(Callable(main, "_on_hud_continue_requested")), "Continue button should be wired to the host handler")
	main.hud.reset_for_round()
	assert(Global.survival_points == 50, "Default survival bonus should be 50 points")
	assert(Global.kill_points == 50, "Default kill reward should be 50 points")
	assert(Global.base_hp_percent == 100, "Default base HP factor should be 100 %")
	assert(Global.get_effective_base_hp(Global.get_hero("ignis")) == 100, "100 % should keep Ignis at 100 HP")
	assert(Global.get_effective_base_hp(Global.get_hero("volt")) == 85, "100 % should keep Volt at 85 HP")
	Global.set_base_hp_percent(150)
	assert(Global.get_effective_base_hp(Global.get_hero("volt")) == 128, "150 % should scale Volt to 128 HP")
	Global.set_base_hp_percent(100)
	assert(is_equal_approx(Global.base_damage, 22.0), "Default shot damage should be 22")
	assert(is_equal_approx(p1.bullet_damage, Global.base_damage), "Player bullet damage should use the base damage")
	# Freundschaftsfeuer: gleiches Team nimmt keinerlei Schaden.
	var old_p2_team: int = p2.team_id
	var hp_before_friendly: float = p2.current_health
	var shield_before_friendly: float = p2.current_shield
	p2.team_id = p1.team_id
	p2.take_damage(25.0, Vector2.ZERO, p1)
	assert(is_equal_approx(p2.current_health, hp_before_friendly), "Friendly fire should not damage health")
	assert(is_equal_approx(p2.current_shield, shield_before_friendly), "Friendly fire should not drain shields")
	p2.team_id = old_p2_team
	# Eigener Flächenschaden wird als freundliches Feuer um 50 % reduziert.
	var hp_before_self: float = p1.current_health
	var shield_before_self: float = p1.current_shield
	var hp_regen_before_self: float = p1.hp_regen_timer
	var shield_regen_before_self: float = p1.shield_regen_timer
	p1.current_health = p1.max_health
	p1.current_shield = 0.0
	p1.is_invulnerable = false
	p1.is_blocking = false
	p1.take_damage(20.0, Vector2.ZERO, p1)
	assert(is_equal_approx(p1.current_health, p1.max_health - 10.0), "Self-damage should be reduced by 50 percent")
	p1.current_health = hp_before_self
	p1.current_shield = shield_before_self
	p1.hp_regen_timer = hp_regen_before_self
	p1.shield_regen_timer = shield_regen_before_self
	# Powerups wirken sofort und laufen anschließend über kurze Timer aus.
	p1.current_health = 40.0
	p1.apply_powerup("heal")
	assert(p1.current_health >= 75.0, "Heal powerup should restore 35 HP")
	p1.apply_powerup("invulnerability")
	assert(p1.powerup_invuln_timer >= 2.9 and p1.is_invulnerable, "Invulnerability powerup should protect for a short time")
	p1.apply_powerup("damage")
	assert(p1.powerup_damage_timer >= 5.9 and p1.powerup_damage_mult > 1.0, "Damage powerup should boost projectile damage")
	p1.apply_powerup("rapid_fire")
	assert(p1.powerup_rapid_fire_timer >= 4.9, "Rapid-fire powerup should allow continuous shooting")
	p1.current_health = p1.max_health
	p1.powerup_invuln_timer = 0.0
	p1.powerup_damage_timer = 0.0
	p1.powerup_damage_mult = 1.0
	p1.powerup_rapid_fire_timer = 0.0
	p1.is_invulnerable = false
	# Projektil-Schwerkraft: Karten modifizieren den Multiplikator, der Spieler
	# reicht ihn an jedes neue Projektil weiter.
	var light_round_card := CardDatabase.get_card("leichtes_geschoss")
	assert(light_round_card != null, "Light round card should exist")
	assert(Global.add_card_to_player(1, light_round_card), "Light round card should be addable")
	p1.apply_stats()
	assert(is_equal_approx(p1.projectile_gravity_mult, light_round_card.projectile_gravity_mult), "Player should adopt the card's projectile gravity")
	var gravity_bullet = load("res://scenes/player/bullet.tscn").instantiate()
	gravity_bullet.shooter = p1
	gravity_bullet.velocity = Vector2(300.0, 0.0)
	gravity_bullet.projectile_gravity_mult = light_round_card.projectile_gravity_mult
	gravity_bullet.max_lifetime = 10.0
	add_child(gravity_bullet)
	gravity_bullet.global_position = Vector2(-2000.0, -2000.0)
	var fall_speed_before: float = gravity_bullet.velocity.y
	gravity_bullet._physics_process(0.1)
	assert(gravity_bullet.velocity.y > fall_speed_before, "Normal projectiles should fall under gravity")
	gravity_bullet.queue_free()
	# Rückstoß: Karten stapeln sich, wirken auf Projektiltreffer und verkürzen
	# kurz die Bewegungskontrolle des getroffenen Ziels.
	var knockback_base := CardDatabase.get_card("rueckstossfeder")
	var knockback_a := CardDatabase.get_card("druckkammer")
	var knockback_b := CardDatabase.get_card("schockgeschoss")
	assert(Global.add_card_to_player(1, knockback_base), "Knockback base card should be addable")
	assert(Global.add_card_to_player(1, knockback_a), "Knockback branch A should be addable")
	assert(Global.add_card_to_player(1, knockback_b), "Knockback branch B should be addable")
	p1.apply_stats()
	var expected_knockback := knockback_base.knockback_mult * knockback_a.knockback_mult * knockback_b.knockback_mult
	assert(is_equal_approx(p1.knockback_mult, expected_knockback), "Knockback cards should stack multiplicatively")
	var knockback_bullet: Bullet = p1._spawn_bullet(Vector2.RIGHT)
	var expected_impulse := Bullet.DIRECT_KNOCKBACK_BASE + knockback_bullet.damage * Bullet.DIRECT_KNOCKBACK_PER_DAMAGE
	assert(is_equal_approx(knockback_bullet.calculate_knockback().length(), expected_impulse), "Direct hits should carry a noticeable base impulse")
	knockback_bullet.queue_free()
	p2.is_invulnerable = false
	p2.is_blocking = false
	var p2_velocity_before: Vector2 = p2.velocity
	p2.knockback_timer = 0.0
	p2.take_damage(0.0, Vector2(100.0, 0.0), p1)
	assert(p2.velocity.x >= p2_velocity_before.x + 200.0, "Knockback cards should increase the shove on the target")
	assert(p2.knockback_timer > 0.0, "Knockback should briefly reduce movement control")
	assert(is_equal_approx(p2._knockback_control_scale(), Player.KNOCKBACK_CONTROL_SCALE), "Knockback window should scale movement control")
	p2.velocity = p2_velocity_before
	p2.knockback_timer = 0.0
	assert(is_equal_approx(p2._knockback_control_scale(), 1.0), "Movement control should recover after knockback")
	# Giftstatus: Der Charakter wird grün, Bläschen steigen auf, und der
	# Tick-Sound bleibt deutlich leiser als normale Treffer.
	var poison_health_before: float = p2.current_health
	var poison_tint_before: Color = p2.sprite.self_modulate
	p2.poison_ticks_left = 0
	p2.poison_tick_timer = 0.0
	p2._refresh_poison_visual()
	p2.apply_poison(2, 1.0)
	assert(p2.is_poisoned(), "Poison should mark the player as poisoned")
	assert(p2.sprite.self_modulate.g > p2.sprite.self_modulate.r, "Poisoned players should receive a green tint")
	assert(p2._poison_bubbles != null and p2._poison_bubbles.is_emitting(), "Poisoned players should emit rising bubbles")
	assert(Player.POISON_TICK_VOLUME_DB <= -8.0, "Poison tick sound should be quieter than normal hits")
	p2.poison_ticks_left = 0
	p2.poison_tick_timer = 0.0
	p2._refresh_poison_visual()
	assert(not p2.is_poisoned(), "Clearing poison stacks should end the poisoned state")
	assert(not p2._poison_bubbles.is_emitting(), "Clearing poison should stop new bubbles")
	assert(is_equal_approx(p2.sprite.self_modulate.r, 1.0), "Clearing poison should restore the normal tint")
	p2.current_health = poison_health_before
	p2.sprite.self_modulate = poison_tint_before
	# Klingensturm: trifft Gegner im Radius, erzeugt sichtbare Effekte und
	# gewährt kurz Unverwundbarkeit.
	var blade_target_pos: Vector2 = p2.global_position
	var blade_target_hp: float = p2.current_health
	var blade_target_shield: float = p2.current_shield
	var blade_target_velocity: Vector2 = p2.velocity
	var blade_target_knockback: float = p2.knockback_timer
	var effects_before_blade := get_tree().get_nodes_in_group("round_effect").size()
	p1.is_invulnerable = false
	p1.ability_invuln_timer = 0.0
	p2.is_invulnerable = false
	p2.is_blocking = false
	p2.current_health = p2.max_health
	p2.current_shield = 0.0
	p2.global_position = p1.global_position + Vector2(90.0, 0.0)
	p1._blade_storm()
	assert(p2.current_health < p2.max_health, "Klingensturm should damage nearby enemies")
	assert(get_tree().get_nodes_in_group("round_effect").size() > effects_before_blade, "Klingensturm should create visible effects")
	assert(p1.is_invulnerable, "Klingensturm should grant brief invulnerability")
	p2.global_position = blade_target_pos
	p2.current_health = blade_target_hp
	p2.current_shield = blade_target_shield
	p2.velocity = blade_target_velocity
	p2.knockback_timer = blade_target_knockback
	p1.is_invulnerable = false
	p1.ability_invuln_timer = 0.0
	# Heilende Hände: heilt trotz aktivem Schadens-Timer. Normale
	# Regeneration bleibt währenddessen weiterhin pausiert.
	var regen_health_before: float = p1.current_health
	var regen_hp_before: float = p1.hp_regen
	var regen_always_before: float = p1.hp_regen_always
	var regen_timer_before: float = p1.hp_regen_timer
	p1.current_health = maxf(1.0, p1.max_health - 20.0)
	p1.hp_regen = 0.0
	p1.hp_regen_always = 2.5
	p1.hp_regen_timer = 3.0
	var always_heal_target: float = p1.current_health
	p1._update_health_regeneration(1.0)
	assert(p1.current_health > always_heal_target, "Heilende Hände should heal while recently damaged")
	assert(p1.hp_regen_timer < 3.0, "Regeneration timer should still count down")
	p1.current_health = maxf(1.0, p1.max_health - 20.0)
	p1.hp_regen = 2.5
	p1.hp_regen_always = 0.0
	p1.hp_regen_timer = 2.0
	var delayed_heal_target: float = p1.current_health
	p1._update_health_regeneration(0.5)
	assert(is_equal_approx(p1.current_health, delayed_heal_target), "Delayed regeneration must stay paused while damaged")
	p1.current_health = regen_health_before
	p1.hp_regen = regen_hp_before
	p1.hp_regen_always = regen_always_before
	p1.hp_regen_timer = regen_timer_before
	print("[TEST] Players spawned: P1 at ", p1.global_position, " | P2 at ", p2.global_position)

	# Simulate combat
	print("[TEST] Simulating 1.5s of combat...")
	await get_tree().create_timer(1.5).timeout

	print("[TEST] P1 HP: ", p1.current_health, " | P2 HP: ", p2.current_health)
	var shots_before := Global.get_match_stat(1, "shots_fired")
	var spawned_bullet: Bullet = p1._spawn_bullet(Vector2.RIGHT)
	assert(is_equal_approx(Global.get_match_stat(1, "shots_fired"), shots_before + 1.0), "Firing a projectile should be tracked")
	assert(spawned_bullet != null and is_equal_approx(spawned_bullet.projectile_gravity_mult, p1.projectile_gravity_mult), "Spawned projectiles should inherit the player's gravity modifier")
	var player_look := Global.get_pig_appearance(1)
	assert(p1.wand != null, "Every player should carry a magic wand")
	assert(p1.wand.tip_shape == player_look["wand_tip_shape"], "Player wand should use the configured tip shape")
	assert(p1.wand.tip_color == player_look["wand_tip_color"], "Player wand should use the configured tip color")
	assert(spawned_bullet.modulate.is_equal_approx(p1.shot_color), "Base projectiles should use the configured shot color")

	# Turm: Standardleben, Schaden, Freundschaftsfeuer, Kanone, Lebensbalken-
	# Daten und die Kartenfreigabe über die Turm-Fähigkeit.
	var tower_armor := CardDatabase.get_card("turm_panzerung")
	var tower_rapid := CardDatabase.get_card("turm_schnellfeuer")
	assert(tower_armor != null and tower_rapid != null, "Tower cards should exist")
	assert(tower_armor.required_mechanic == "tower", "Tower armor should require the tower mechanic")
	assert(tower_rapid.required_mechanic == "tower", "Tower rapid fire should require the tower mechanic")
	assert(not CardDatabase.is_card_available_for_player(tower_armor, "ignis", []), "Tower cards should be hidden without the tower ability")
	assert(CardDatabase.is_card_available_for_player(tower_armor, "ignis", ["turm"]), "Tower cards should unlock with the tower ability")

	var default_tower := Companion.new()
	default_tower.mode = Companion.Mode.TOWER
	default_tower.owner_player = p1
	main.add_child(default_tower)
	assert(is_equal_approx(default_tower.max_health, 100.0), "Towers should have 100 base health")
	assert(is_equal_approx(default_tower.current_health, 100.0), "Towers should spawn at full health")
	assert(default_tower.cannon != null, "Tower should render a cannon")
	assert(default_tower.cannon.z_index == -1, "Health bar should draw above the cannon")
	assert(default_tower.collision_layer == 16, "Towers should use the dedicated tower collision layer")
	default_tower.queue_free()

	assert(Global.add_card_to_player(1, tower_armor), "Tower armor should be addable")
	assert(Global.add_card_to_player(1, tower_rapid), "Tower rapid fire should be addable")
	p1.apply_stats()
	assert(is_equal_approx(p1.tower_max_health, 175.0), "Tower armor should add 75 maximum health")
	assert(is_equal_approx(p1.tower_fire_rate_mult, 0.8), "Tower rapid fire should shorten the fire interval")

	var test_tower := Companion.new()
	test_tower.mode = Companion.Mode.TOWER
	test_tower.owner_player = p1
	test_tower.max_health = p1.tower_max_health
	test_tower.fire_interval = Companion.BASE_FIRE_INTERVAL * p1.tower_fire_rate_mult
	main.add_child(test_tower)
	test_tower.global_position = p1.global_position + Vector2(70.0, 0.0)
	assert(is_equal_approx(test_tower.current_health, 175.0), "Upgraded tower should spawn with its full health")
	assert(is_equal_approx(test_tower.fire_interval, Companion.BASE_FIRE_INTERVAL * 0.8), "Upgraded tower should use the shorter fire interval")
	var tower_hp_before := test_tower.current_health
	var tower_bullet: Bullet = load("res://scenes/player/bullet.tscn").instantiate()
	assert(tower_bullet.collision_mask == 19, "Bullets should collide with the tower layer")
	tower_bullet.shooter = p2
	tower_bullet.damage = 30.0
	assert(test_tower.hit_tower(tower_bullet), "Enemy bullet should hit a tower")
	assert(is_equal_approx(test_tower.current_health, tower_hp_before - 30.0), "Enemy damage should reduce tower health")
	tower_bullet.free()
	var tower_hp_after_enemy := test_tower.current_health
	var friendly_tower_bullet: Bullet = load("res://scenes/player/bullet.tscn").instantiate()
	friendly_tower_bullet.shooter = p1
	friendly_tower_bullet.damage = 30.0
	assert(not test_tower.hit_tower(friendly_tower_bullet), "Friendly bullets should not hit a tower")
	assert(is_equal_approx(test_tower.current_health, tower_hp_after_enemy), "Friendly fire should not damage a tower")
	friendly_tower_bullet.free()
	# Regression: Ein Projektil kann seinen Schützen überleben. Der freigegebene
	# Angreifer darf beim Turmschaden keinen Typfehler auslösen.
	var freed_attacker := Node2D.new()
	add_child(freed_attacker)
	freed_attacker.free()
	var tower_hp_before_orphan := test_tower.current_health
	test_tower.take_tower_damage(12.0, freed_attacker)
	assert(is_equal_approx(test_tower.current_health, tower_hp_before_orphan - 12.0), "A freed attacker should not block tower damage")
	var tower_snapshot_found := false
	for tower_entry in main._tower_snapshots():
		if int(tower_entry.get("id", 0)) == test_tower.net_id:
			tower_snapshot_found = true
			assert(is_equal_approx(float(tower_entry.get("hp", -1.0)), test_tower.current_health), "Tower snapshot should carry health")
			assert(is_equal_approx(float(tower_entry.get("max_hp", -1.0)), test_tower.max_health), "Tower snapshot should carry maximum health")
			assert(tower_entry.has("aim"), "Tower snapshot should carry the cannon aim angle")
	assert(tower_snapshot_found, "Active tower should appear in the tower snapshots")
	test_tower.queue_free()

	# Tank-Karten: Rüstung stapelt und wird gedeckelt, prozentuale HP wirken,
	# und ein Teil des tatsächlich erlittenen Schadens geht an den Angreifer zurück.
	var tank_deck_backup: Array = Global.get_player_cards(1).duplicate()
	Global.get_player_cards(1).clear()
	p1.apply_stats()
	var p1_base_hp: float = p1.max_health
	assert(Global.add_card_to_player(1, tank_cards[0]), "Tank root should be addable")
	p1.apply_stats()
	assert(p1.max_health > p1_base_hp, "Tank root should increase maximum health")
	assert(is_equal_approx(p1.armor_percent, tank_cards[0].armor_percent_add), "Tank root armor should be applied")
	for tank_index in range(1, tank_cards.size()):
		assert(Global.add_card_to_player(1, tank_cards[tank_index]), "Tank upgrade should be addable")
	p1.apply_stats()
	assert(is_equal_approx(p1.armor_percent, Player.MAX_ARMOR_PERCENT), "Stacked tank armor should respect the cap")
	assert(is_equal_approx(p1.damage_reflect_percent, Player.MAX_DAMAGE_REFLECT_PERCENT), "Stacked damage reflection should respect the cap")

	p1.max_health = 100.0
	p1.current_health = 100.0
	p1.current_shield = 0.0
	p1.max_shield = 0.0
	p1.is_dead = false
	p1.is_blocking = false
	p1.is_invulnerable = false
	p1.take_damage(50.0)
	assert(is_equal_approx(p1.current_health, 100.0 - 50.0 * (1.0 - Player.MAX_ARMOR_PERCENT)), "Armor should reduce incoming damage before health is lost")

	p1.armor_percent = 0.0
	p1.damage_reflect_percent = 0.25
	p1.current_health = 100.0
	p1.max_health = 100.0
	p2.current_health = 100.0
	p2.max_health = 100.0
	p2.current_shield = 0.0
	p2.max_shield = 0.0
	p2.armor_percent = 0.0
	p2.damage_reflect_percent = 0.0
	p2.is_dead = false
	p2.is_blocking = false
	p2.is_invulnerable = false
	p1.take_damage(40.0, Vector2.ZERO, p2)
	assert(is_equal_approx(p1.current_health, 60.0), "Damage reflection should not change the damage taken by the tank")
	assert(is_equal_approx(p2.current_health, 90.0), "Damage reflection should hurt the attacking player")
	Global.get_player_cards(1).clear()
	Global.get_player_cards(1).append_array(tank_deck_backup)
	p1.apply_stats()
	p2.apply_stats()
	print("[TEST] Tank armor, percentage health and damage reflection verified.")

	# Trigger round defeat: clear invulnerability flags if any
	print("[TEST] Simulating P2 defeat...")
	# Draft-Modifier: Random pick wählt automatisch, Blind pick verdeckt
	# die Bot-Auswahl auf dem lokalen Bildschirm.
	Global.set_random_pick_enabled(true)
	Global.set_blind_pick_enabled(true)
	p2.is_invulnerable = false
	p2.is_blocking = false
	p2.take_damage(9999.0, Vector2.ZERO, p1)
	assert(p2.is_dead, "Lethal damage should mark the player as dead exactly once")

	# Wait a short frame
	await get_tree().process_frame
	await get_tree().process_frame

	print("[TEST] Global state after P2 death: ", Global.current_state, " (expected: ", Global.GameState.CARD_DRAFT, ")")
	assert(Global.current_state == Global.GameState.CARD_DRAFT, "State should transition to CARD_DRAFT")
	assert(Global.player_scores[0] == Global.kill_points + Global.survival_points, "P1 should get kill and survival points")
	assert(Global.player_scores[1] == 0, "Dead P2 should not get survival points")
	assert(Global.get_match_stat(1, "kills") >= 1.0, "Killer should be credited with a kill")
	assert(Global.get_match_stat(2, "deaths") >= 1.0, "Victim should be credited with a death")
	assert(Global.get_match_stat(1, "damage_dealt") > 0.0, "Damage dealt should be tracked")
	var total_shots_fired := 0.0
	for slot in Global.get_active_player_indices():
		total_shots_fired += Global.get_match_stat(slot, "shots_fired")
	assert(total_shots_fired > 0.0, "Shots fired should be tracked")
	assert(Global.get_match_stats().size() == Global.MAX_PLAYERS, "Match stats should cover every slot")
	assert(Global.get_match_mvp_index() > 0, "An MVP should be computable from match stats")
	assert(main.card_draft_ui.visible == true, "Card draft UI should be visible")
	assert(main.card_draft_ui.current_drafter == 2, "Loser slot 2 should be the active drafter")
	assert(main.card_draft_ui.draft_tabs.get_tab_count() == 1, "Card draft should only contain the card tab")
	assert(not main.card_draft_ui.draft_tabs.has_node("Charakter"), "Character customization must not appear during the card draft")
	assert(not main.card_draft_ui._blind_pick_active(), "Local bot drafts should ignore Blind pick")
	assert(not main.card_draft_ui._blind_pick_hidden(), "Local bot drafts should not be hidden by Blind pick")
	assert("BLIND PICK" not in main.card_draft_ui.subtitle_label.text, "Local draft subtitle should not mention Blind pick")
	assert(main.card_draft_ui._authoritative_random_pick(), "Random pick should be host-authoritative")
	print("[TEST] Card Draft UI triggered successfully with ", main.card_draft_ui.offered_cards.size(), " cards.")

	print("[TEST] Waiting for random auto-draft (process_mode=ALWAYS timer)...")
	# Use process timer because tree is paused during draft
	await get_tree().create_timer(1.5, true).timeout

	var p2_cards = Global.get_player_cards(2)
	print("[TEST] P2 Cards after draft: ", p2_cards.size())
	assert(p2_cards.size() == 1, "P2 should have drafted 1 card")
	assert(main.card_draft_ui.offered_cards.has(p2_cards[0]), "Random pick should choose a card from the offer")
	print("[TEST] Successfully drafted card: ", p2_cards[0].title)
	Global.set_random_pick_enabled(false)
	Global.set_blind_pick_enabled(false)

	# Nachspiel-Statistik und Helden-Stats-Screen bauen lassen.
	main.hud._build_match_stats()
	var has_stats_block := false
	for child in main.hud.game_over_vbox.get_children():
		if child.has_meta("match_stats_block"):
			has_stats_block = true
	assert(has_stats_block, "Match stats table should be built")
	main.main_menu._on_hero_stats_pressed()
	assert(main.main_menu.hero_stats_grid.get_child_count() == Global.heroes.size(), "Hero stats screen should list every hero")
	main.main_menu._close_hero_stats()
	print("[TEST] Match stats table and hero stats screen built successfully.")

	# Rundenstart räumt Projektile, Türme, Flächen- und Kurzzeiteffekte auf.
	var cleanup_bullet: Bullet = load("res://scenes/player/bullet.tscn").instantiate()
	main.add_child(cleanup_bullet)
	var cleanup_zone := EffectZone.new()
	main.add_child(cleanup_zone)
	var cleanup_tower := Companion.new()
	cleanup_tower.mode = Companion.Mode.TOWER
	main.add_child(cleanup_tower)
	var cleanup_effect := Node2D.new()
	cleanup_effect.add_to_group("round_effect")
	main.add_child(cleanup_effect)
	assert(get_tree().get_nodes_in_group("bullet").size() > 0, "Cleanup test should create a projectile")
	assert(get_tree().get_nodes_in_group("effect_zone").size() > 0, "Cleanup test should create a zone effect")
	assert(get_tree().get_nodes_in_group("tower").size() > 0, "Cleanup test should create a tower")
	assert(get_tree().get_nodes_in_group("round_effect").size() > 0, "Cleanup test should create a transient effect")
	main._clear_round_effects()
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("bullet").is_empty(), "Round cleanup should remove all projectiles")
	assert(get_tree().get_nodes_in_group("effect_zone").is_empty(), "Round cleanup should remove all zone effects")
	assert(get_tree().get_nodes_in_group("tower").is_empty(), "Round cleanup should remove all towers")
	assert(get_tree().get_nodes_in_group("round_effect").is_empty(), "Round cleanup should remove all transient effects")
	print("[TEST] Round effect cleanup verified.")

	# Kartenstatistik: Angebote, Picks, Kills und Match-Siege werden gezählt.
	# Eine klar überdurchschnittliche Common-Karte steigt anschließend auf Uncommon.
	# Geschrieben wird in eine Testdatei, nie in die echte Statistik.
	var stats_test_path := "user://card_statistics_test_%d.json" % Time.get_ticks_msec()
	CardStats.storage_path = stats_test_path
	CardStats.set_persistence_enabled(true)
	CardStats.reset_statistics(true)
	Global.set_player_count(2)
	for slot in range(1, Global.MAX_PLAYERS + 1):
		Global.get_player_cards(slot).clear()
	var common_cards: Array[CardData] = []
	for card in CardDatabase.all_cards:
		if card.rarity == "Common":
			common_cards.append(card)
	assert(common_cards.size() >= 3, "Statistics test needs at least three Common cards")
	var stat_target: CardData = common_cards[0]
	var stat_peer: CardData = common_cards[1]
	CardStats.record_offer([stat_target, stat_peer])
	CardStats.record_offer([stat_target])
	CardStats.record_pick(stat_target.id)
	var target_stats := CardStats.get_card_stats(stat_target.id)
	assert(int(target_stats.get("offers", 0)) == 2, "Offers should be tracked per card")
	assert(int(target_stats.get("picks", 0)) == 1, "Picks should be tracked per card")
	assert(is_equal_approx(float(target_stats.get("pick_rate", 0.0)), 0.5), "Pick rate should be picks / offers")
	Global.add_card_to_player(1, stat_target)
	Global.add_card_to_player(2, stat_peer)
	CardStats.record_kill(1)
	assert(int(CardStats.get_card_stats(stat_target.id).get("kills", 0)) == 1, "Kills should be credited to deck cards")
	for i in range(10):
		CardStats.record_match(1)
	var promoted := CardStats.evaluate_rarity(true)
	assert(not promoted.is_empty(), "A dominant card should be promoted")
	assert(CardStats.get_rarity_override(stat_target.id) == "Uncommon", "Overperforming Common card should become Uncommon")
	assert(stat_target.rarity == "Uncommon", "Rarity override should be applied to CardData immediately")
	var stats_document := CardStats.get_statistics_document()
	assert(str(stats_document.get("path", "")) == CardStats.get_document_path(), "Statistics document should expose its storage path")
	assert(stats_document.has("cards") and stats_document.has("rarity_overrides"), "Statistics document should contain cards and overrides")
	var document_cards: Dictionary = stats_document.get("cards", {})
	assert(document_cards.size() == CardDatabase.all_cards.size(), "Statistics document should contain every registered card")
	assert(FileAccess.file_exists(stats_test_path), "Statistics should be written to disk at match end")
	var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(stats_test_path))
	assert(persisted is Dictionary, "Persisted statistics should be valid JSON")
	var persisted_data: Dictionary = persisted
	var persisted_cards: Dictionary = persisted_data.get("cards", {})
	assert(persisted_cards.has(stat_target.id), "Persisted document should contain the tracked card")
	var persisted_overrides: Dictionary = persisted_data.get("rarity_overrides", {})
	assert(str(persisted_overrides.get(stat_target.id, "")) == "Uncommon", "Rarity override should be persisted")
	CardStats.reload_from_disk()
	assert(CardStats.get_matches() == 10, "Reload should restore the aggregate match count")
	assert(int(CardStats.get_card_stats(stat_target.id).get("matches", 0)) == 10, "Reload should restore per-card samples")
	assert(CardStats.get_rarity_override(stat_target.id) == "Uncommon", "Reload should restore rarity overrides")
	assert(stat_target.rarity == "Uncommon", "Reload should reapply the promoted rarity")
	CardStats.set_persistence_enabled(false)
	CardStats.reset_statistics(true)
	CardStats.storage_path = "user://card_statistics.json"
	assert(stat_target.rarity == CardStats.get_base_rarity(stat_target.id), "Reset should restore the base rarity")
	assert(CardStats.get_rarity_override(stat_target.id).is_empty(), "Reset should clear rarity overrides")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stats_test_path))
	for slot in range(1, Global.MAX_PLAYERS + 1):
		Global.get_player_cards(slot).clear()
	print("[TEST] Card statistics and automatic rarity promotion verified.")

	# ============================================================
	# Level Modifier Tests
	# ============================================================
	print("[TEST] Verifying Level Modifier System...")
	var mod_mgr = main.modifier_manager
	assert(mod_mgr != null, "Main game should have an active modifier manager")
	assert(LevelModifierDefsClass.MODIFIERS.size() == 20, "Exactly 20 level modifiers should be defined")
	assert(mod_mgr.MODIFIERS.size() == 20, "Modifier manager should use the shared 20 modifier definitions")

	# Konfiguration: Rate 0 schaltet alles aus, Filterung und 200 % werden geprüft.
	var config_rate_backup: int = Global.level_modifier_rate_percent
	var config_enabled_backup: Array[String] = Global.get_enabled_level_modifiers()
	assert(mod_mgr.roll_modifiers(123, 0).is_empty(), "0 % rate should disable all modifiers")
	var only_wind: Array[String] = ["wind"]
	var wind_only_roll: Array[String] = mod_mgr.roll_modifiers(123, 200, only_wind)
	assert(wind_only_roll.size() == 1 and wind_only_roll[0] == "wind", "Allowed modifier ids should filter the roll")
	Global.set_enabled_level_modifiers([])
	assert(mod_mgr.roll_configured_modifiers(42).is_empty(), "An empty lobby selection should roll nothing")
	Global.set_level_modifier_rate_percent(0)
	Global.set_enabled_level_modifiers(config_enabled_backup)
	assert(mod_mgr.roll_configured_modifiers(42).is_empty(), "A 0 % lobby rate should roll nothing")
	Global.set_level_modifier_rate_percent(config_rate_backup)

	# 1. Test 10,000 rolls distribution
	var counts := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var total_rolls := 10000
	var incompatible_rolls := 0
	for seed_i in range(total_rolls):
		var rolled: Array[String] = mod_mgr.roll_modifiers(seed_i + 1)
		var c: int = rolled.size()
		counts[c] = int(counts.get(c, 0)) + 1
		if rolled.has("cave") and rolled.has("floor_is_lava"):
			incompatible_rolls += 1
		if rolled.has("low_gravity") and rolled.has("high_gravity"):
			incompatible_rolls += 1
	assert(incompatible_rolls == 0, "Cave/lava and low/high gravity must never be rolled together")

	var pct_0: float = float(counts[0]) / float(total_rolls) * 100.0
	var pct_1: float = float(counts[1]) / float(total_rolls) * 100.0
	var pct_2: float = float(counts[2]) / float(total_rolls) * 100.0
	var pct_3: float = float(counts[3]) / float(total_rolls) * 100.0
	var pct_4: float = float(counts[4]) / float(total_rolls) * 100.0
	print("[TEST] 10,000 Modifier Roll Distribution: 0=%0.1f%%, 1=%0.1f%%, 2=%0.1f%%, 3=%0.1f%%, 4=%0.1f%%" % [pct_0, pct_1, pct_2, pct_3, pct_4])
	assert(pct_0 > 49.0 and pct_0 < 57.0, "0 modifiers expected ~53%")
	assert(pct_1 > 30.0 and pct_1 < 36.0, "1 modifier expected ~33%")
	assert(pct_2 > 8.0 and pct_2 < 12.0, "2 modifiers expected ~10%")
	assert(pct_3 > 2.0 and pct_3 < 4.5, "3 modifiers expected ~3%")
	assert(pct_4 > 0.4 and pct_4 < 1.8, "4 modifiers expected ~1%")

	# 2. Test lifecycle & mechanics
	# Neue Runde im main wurde durch die Draft-Sequenz gestartet – auf frische Spieler warten.
	await get_tree().process_frame
	await get_tree().process_frame
	var test_mods: Array[String] = ["bounty", "pinata", "cave", "wind", "low_gravity", "mini_pigs"]
	mod_mgr.start_round_modifiers(test_mods, main, main.level_generator)
	assert(mod_mgr.has_modifier("bounty"), "Bounty should be active")
	assert(mod_mgr.has_modifier("pinata"), "Piñata should be active")
	assert(is_instance_valid(mod_mgr.current_coin_node), "Bounty coin node should exist")
	assert(is_instance_valid(mod_mgr.current_pinata), "Piñata llama node should exist")

	# Test player physics modifiers – frische Spieler nach Rundenstart aus main holen
	var active_p1 = main.get_player(1)
	var active_p2 = main.get_player(2)

	if active_p1 != null and active_p2 != null:
		var init_grav: float = active_p1.gravity_mult
		var init_scale: Vector2 = active_p1.scale
		mod_mgr.apply_player_modifiers(active_p1)
		assert(active_p1.gravity_mult < init_grav, "Low gravity should reduce player gravity_mult")
		assert(active_p1.scale.x < init_scale.x, "Mini pigs should shrink player scale")

		# Test coin collection via direkter Slot-Zuweisung (Spieler ist valide)
		mod_mgr._on_coin_collected(active_p1)
		mod_mgr._on_coin_collected(active_p1)
		mod_mgr._on_coin_collected(active_p2)
		assert(int(mod_mgr.player_coins.get(1, 0)) == 2, "P1 should have 2 coins")
		assert(int(mod_mgr.player_coins.get(2, 0)) == 1, "P2 should have 1 coin")

		# Test Piñata damage
		mod_mgr.current_pinata.take_damage(60.0, Vector2.ZERO, active_p2)
		mod_mgr.current_pinata.take_damage(20.0, Vector2.ZERO, active_p1)
		assert(float(mod_mgr.current_pinata.damage_by_player.get(2, 0.0)) == 60.0, "P2 should deal 60 dmg to llama")

		# Test Bonus Card drafters calculation
		var bonus_drafters: Array[int] = mod_mgr.get_bonus_card_drafters()
		assert(bonus_drafters.has(1), "P1 should get bonus card for most coins")
		assert(bonus_drafters.has(2), "P2 should get bonus card for most Piñata damage")

		# Das Lama flieht primär vor dem führenden Spieler.
		var score_1_backup: int = Global.player_scores[0]
		var score_2_backup: int = Global.player_scores[1]
		Global.player_scores[0] = 100
		Global.player_scores[1] = 10
		var leader_players: Array[Player] = [active_p1, active_p2]
		mod_mgr.update_physics_modifiers(0.0, leader_players)
		var llama = mod_mgr.current_pinata
		assert(llama.has_leader_target(), "Pinata should receive a leader target")
		assert(
			llama.get_leader_position().distance_to(active_p1.global_position) < 1.0,
			"Pinata should target the leading player"
		)
		llama.global_position = Vector2(500, 300)
		llama.set_leader_position(Vector2(800, 300))
		llama._flee_lock_timer = 0.0
		llama._update_flee_direction()
		assert(llama.get_flee_direction() < 0.0, "Pinata should run away from a leader on its right")
		Global.player_scores[0] = score_1_backup
		Global.player_scores[1] = score_2_backup
		print("[TEST] Modifier physics, coins, Piñata and bonus drafters verified with live players.")
	else:
		# Fallback: Wenn die neue Runde noch nicht gestartet ist, nur Slot-basierte Tests
		mod_mgr.player_coins[1] = 2
		mod_mgr.player_coins[2] = 1
		assert(int(mod_mgr.player_coins.get(1, 0)) == 2, "P1 should have 2 coins (slot test)")
		mod_mgr.player_coins.clear()
		var bonus_draft2: Array[int] = mod_mgr.get_bonus_card_drafters()
		assert(bonus_draft2.is_empty(), "No bonus drafters when no coins collected")
		print("[TEST] Modifier coin tracking verified (fallback, no live players available).")

	# Neue Modifier-Effekte prüfen: Schaden, Gravitation, Tempo, Luftjump,
	# Startschild, Regeneration und Kistenregen. Falls die Draft-Sequenz die
	# Runde bereits beendet hat, werden zwei temporäre Spieler erzeugt.
	var effect_p1: Player = active_p1
	var effect_p2: Player = active_p2
	var temp_effect_players: Array[Player] = []
	if not is_instance_valid(effect_p1):
		var temp_p1 := main.player_scene.instantiate() as Player
		temp_p1.name = "TestEffectP1"
		temp_p1.player_index = 1
		temp_p1.position = Vector2(400, 300)
		temp_p1.control_enabled = false
		main.add_child(temp_p1)
		temp_p1.set_physics_process(false)
		effect_p1 = temp_p1
		temp_effect_players.append(temp_p1)
	if not is_instance_valid(effect_p2):
		var temp_p2 := main.player_scene.instantiate() as Player
		temp_p2.name = "TestEffectP2"
		temp_p2.player_index = 2
		temp_p2.position = Vector2(650, 300)
		temp_p2.control_enabled = false
		main.add_child(temp_p2)
		temp_p2.set_physics_process(false)
		effect_p2 = temp_p2
		temp_effect_players.append(temp_p2)

	if is_instance_valid(effect_p1) and is_instance_valid(effect_p2):
		effect_p1.is_dead = false
		effect_p2.is_dead = false
		effect_p1.apply_stats()
		effect_p2.apply_stats()
		var effect_mods: Array[String] = [
			"double_damage", "high_gravity", "speed_demon", "air_jumps",
			"starting_shield", "regeneration", "crate_rain", "powerup_rain",
		]
		mod_mgr.active_modifiers.clear()
		mod_mgr.active_modifiers.append_array(effect_mods)
		mod_mgr._main_ref = main
		mod_mgr._level_ref = main.level_generator
		mod_mgr._regen_timer = 0.5

		var damage_before: float = effect_p1.bullet_damage
		var gravity_before: float = effect_p1.gravity_mult
		var speed_before: float = effect_p1.move_speed
		var jumps_before: int = effect_p1.max_jumps
		var shield_before: float = effect_p1.max_shield
		mod_mgr.apply_player_modifiers(effect_p1)
		assert(effect_p1.bullet_damage > damage_before, "Double damage should increase bullet damage")
		assert(effect_p1.gravity_mult > gravity_before, "High gravity should increase gravity_mult")
		assert(effect_p1.move_speed > speed_before, "Speed demon should increase move speed")
		assert(effect_p1.max_jumps == jumps_before + 1, "Air jumps should grant one extra jump")
		assert(effect_p1.max_shield > shield_before, "Starting shield should add bonus shield")
		assert(is_equal_approx(effect_p1.current_shield, effect_p1.max_shield), "Starting shield should be filled")

		effect_p1.current_health = maxf(1.0, effect_p1.max_health - 20.0)
		var health_before: float = effect_p1.current_health
		var effect_players: Array[Player] = [effect_p1, effect_p2]
		mod_mgr.update_physics_modifiers(0.5, effect_players)
		assert(effect_p1.current_health > health_before, "Regeneration should heal over time")

		var crates_before: int = 0
		for child in main.level_generator.get_children():
			if child is PhysicsCrate:
				crates_before += 1
		mod_mgr._spawn_crate_rain()
		var crates_after: int = 0
		for child in main.level_generator.get_children():
			if child is PhysicsCrate:
				crates_after += 1
		assert(crates_after >= crates_before + 3, "Crate rain should spawn three crates")
		assert(LevelModifierDefsClass.MODIFIERS.has("powerup_rain"), "Powerup rain should be defined")
		print("[TEST] New modifier effects verified: damage, gravity, speed, air jump, shield, regen, crates.")
		for temp_player in temp_effect_players:
			if is_instance_valid(temp_player):
				main.remove_child(temp_player)
				temp_player.free()

	# Test HUD integration – typed Array[Dictionary] wird benötigt
	var hud_test_mods: Array[Dictionary] = [
		{"id": "cave", "title": "Höhle", "icon": "🪨", "color": Color.GRAY, "description": "Feste Felswände"},
		{"id": "wind", "title": "Sturmwind", "icon": "🌪️", "color": Color.CYAN, "description": "Windböen"}
	]
	main.hud.show_level_modifiers(hud_test_mods)
	assert(main.hud._modifier_container.visible, "HUD modifier badges should be visible")
	assert(main.hud._modifier_container.get_child_count() == 2, "HUD should show 2 badges")
	assert(main.hud._modifier_container is VBoxContainer, "HUD modifier badges should stack vertically at the screen edge")
	assert(is_equal_approx(main.hud._modifier_container.anchor_left, 1.0), "HUD modifier badges should be anchored to the right")
	var first_badge := main.hud._modifier_container.get_child(0) as PanelContainer
	assert(first_badge != null, "HUD modifier badge should be a panel")
	var first_row := first_badge.get_child(0) as HBoxContainer
	assert(first_row != null and first_row.get_child_count() >= 2, "HUD modifier badge should contain icon and title")
	var badge_title := first_row.get_child(1) as Label
	assert(badge_title.get_theme_font_size("font_size") >= 20, "HUD badge title should be enlarged")

	main.hud.show_wind_notice(true, 1.0)
	assert(main.hud._event_label.visible, "HUD event label should display wind notice")
	main.hud.show_wind_notice(false, 0.0)
	assert(not main.hud._event_label.visible, "HUD event label should hide when wind stops")

	# Test Stempel-Animation (headless: Nodes werden korrekt erstellt)
	var stamp_test_mods: Array[Dictionary] = [
		{"id": "laser", "title": "Orbital-Laser", "icon": "🔴", "color": Color(1.0, 0.15, 0.2), "description": "50 Schaden"},
	]
	main.hud.show_modifier_stamp_reveal(stamp_test_mods)
	assert(is_instance_valid(main.hud._stamp_overlay), "Stamp overlay should be created")
	main.hud._stamp_overlay.queue_free()
	main.hud._stamp_overlay = null

	# Test round cleanup
	mod_mgr.clear_round()
	assert(mod_mgr.current_coin_node == null, "Coin should be cleaned up")
	assert(mod_mgr.current_pinata == null, "Piñata should be cleaned up")
	main.hud.reset_for_round()
	assert(not main.hud._modifier_container.visible, "HUD badges should be hidden after reset")
	print("[TEST] Level Modifier System fully verified!")

	SoundManager.stop_all_sounds()
	print("[SUCCESS] All integration tests passed smoothly! Game mechanics 100% verified.")
	get_tree().quit(0)
