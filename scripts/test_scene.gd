extends Node2D

func _ready() -> void:
	print("[TEST] Initializing Headless Integration Test inside full game tree...")
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
	assert(main.lobby.ban_checks.size() == CardDatabase.all_cards.size(), "Lobby ban list should list every card")
	assert(main.lobby.ban_icons.size() == CardDatabase.all_cards.size(), "Lobby ban list should show an icon for every card")
	# Charakteranpassung lebt in der Lobby und ist pro Spieler-Slot verfügbar.
	assert(main.lobby.tabs.get_tab_count() == 4, "Lobby should have four tabs")
	assert(main.lobby.tabs.get_tab_title(1) == "Charakter", "Lobby should provide a character tab")
	assert(main.lobby.character_tab != null and main.lobby.character_slot_option != null, "Lobby should build the character controls")
	assert(main.lobby.character_slot_option.item_count >= 1, "Local lobby should offer player slots for customization")
	var original_character_slot: int = main.lobby._character_slot
	var original_slot_look := Global.get_pig_appearance(2)
	var test_fur := Color(0.11, 0.22, 0.33, 1.0)
	main.lobby._character_slot = 2
	main.lobby._refresh_character_tab()
	main.lobby.fur_picker.color = test_fur
	main.lobby._on_character_color_changed(test_fur)
	assert(Global.get_pig_appearance(2)["fur"] == test_fur, "Lobby character tab should update the selected player slot")
	main.lobby._on_reset_character_colors()
	assert(Global.get_pig_appearance(2)["fur"] == Global.default_pig_fur_colors[1], "Lobby reset should restore the selected slot")
	Global.set_pig_appearance(2, original_slot_look["fur"], original_slot_look["eyes"], original_slot_look["pants"])
	main.lobby._character_slot = original_character_slot
	main.lobby._refresh_character_tab()
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
	Global.network_mode = lobby_network_backup
	Global.is_spectator = lobby_spectator_backup
	Global.set_local_player(lobby_local_backup)
	main.lobby._sync_from_global()

	# Inhalt: neue Klassen und zusätzliche Basiskarten müssen vorhanden sein.
	# Titan wurde entfernt; Block ist stattdessen für alle Spieler verfügbar.
	assert(Global.heroes.size() >= 7, "At least 7 heroes should be registered")
	assert(not Global.heroes.has("titan"), "Titan should be removed")
	assert(CardDatabase.all_cards.size() >= 161, "At least 161 cards should be registered")
	assert(InputMap.has_action("p1_block"), "Block action should be registered")
	assert(CardDatabase.get_card("blockbombe") != null, "Block bomb card should exist")
	assert(CardDatabase.get_card("heilzone") != null, "Block heal zone card should exist")
	assert(CardDatabase.get_card("druckwelle") != null, "Block knockback card should exist")
	assert(CardDatabase.get_card("spiegelblock") != null, "Block reflect card should exist")
	# Kartenpools: jede Karte gehört zu genau einem gültigen Pool.
	for card in CardDatabase.all_cards:
		assert(Global.CARD_POOLS.has(card.pool), "Card %s has invalid pool %s" % [card.id, card.pool])
	assert(Global.enabled_card_pools.size() == Global.CARD_POOLS.size(), "All card pools should be enabled by default")
	for new_card_id in ["splittergeschoss", "panzerbrecher", "brandkapsel", "kettenreaktion", "sanitaeter", "bollwerk", "zweites_herz", "federstiefel", "windschatten", "leichtgewicht", "notvorrat", "fokuskristall", "instabiler_kern", "wandelnder_koloss", "leichtes_geschoss", "schweres_geschoss", "moerser", "moerser_praezision", "moerser_belagerung"]:
		assert(CardDatabase.get_card(new_card_id) != null, "New pool card %s should exist" % new_card_id)
	# Pool-Filter: Ohne Chaos dürfen keine Chaos-Karten angeboten werden.
	Global.set_enabled_card_pools(["Kern", "Offensive", "Defensive", "Bewegung"])
	assert(not CardDatabase.is_card_pool_enabled(CardDatabase.get_card("instabiler_kern")), "Chaos cards should be filtered out")
	var filtered_offer := CardDatabase.get_draft_offer(20, [], "ignis", [])
	for card in filtered_offer:
		assert(card.pool != "Chaos", "Filtered draft must not contain Chaos cards")
	Global.set_all_card_pools(true)
	assert(Global.enabled_card_pools.size() == Global.CARD_POOLS.size(), "All pools should be restorable")
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
	# Maps: vier feste Spielfelder plus Zufallsauswahl, jeweils mit eigenem Tileset.
	assert(Global.MAP_PLAYABLE.size() >= 4, "At least four playable maps should be registered")
	assert(Global.MAPS.has(Global.MAP_RANDOM), "Random map option should exist")
	for map_id in Global.MAP_PLAYABLE:
		assert(Global.MAPS.has(map_id), "Map %s should have metadata" % map_id)
	Global.set_selected_map("wuestenruine")
	assert(Global.resolve_map_id(12345) == "wuestenruine", "Selected map should override the seed")
	Global.set_selected_map(Global.MAP_RANDOM)
	assert(Global.MAP_PLAYABLE.has(Global.resolve_map_id(12345)), "Random map should resolve to a playable map")
	assert(Global.MAP_PLAYABLE.has(main.match_map_id), "Match should use a concrete playable map")
	assert(level.MAP_PROFILES.has(level.current_map_id), "Level should use a known map profile")
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
		assert(int(map_profile.get("crate_stacks", 0)) > 0, "Map %s should define crate stacks" % map_id)
		assert(int(map_profile.get("powerups", 0)) > 0, "Map %s should define random powerups" % map_id)
	# Spawns dürfen nicht auf Federn, Röhren, Kisten, Stacheln oder Plattformen liegen.
	# Die echten Spieler-Spawns haben bereits Kacheln belegt; für den
	# Sechs-Spieler-Test starten wir mit frischen Claims.
	level._claimed_spawn_cells.clear()
	var seen_spawns := {}
	for slot in range(1, 7):
		var spawn_pos: Vector2 = level.get_spawn_position(slot, 6)
		assert(level.is_spawn_position_clear(spawn_pos), "Spawn %d should be clear of map objects" % slot)
		assert(not seen_spawns.has(spawn_pos), "Spawn %d should not share a tile with another spawn" % slot)
		seen_spawns[spawn_pos] = true
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
	# Charaktere kollidieren miteinander: Beide Spieler liegen auf Layer 2 und
	# nehmen Layer 2 in ihre Maske auf. Dadurch blockieren sich die Körper.
	assert(p1.collision_layer == 2 and p2.collision_layer == 2, "Players should use the character collision layer")
	assert((p1.collision_mask & 2) != 0 and (p2.collision_mask & 2) != 0, "Players should collide with each other")
	# Waffenbasis: Standard sind 3 Schuss, einzelne Klassen weichen ab.
	var p1_hero: HeroData = Global.get_hero(Global.get_player_hero_id(1))
	assert(p1.max_ammo == p1_hero.base_ammo, "Player should start with the hero's base ammo")
	assert(p1.current_ammo == p1.max_ammo, "Player should start with a full magazine")
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
	var test_card := CardDatabase.get_card("sanitaeter")
	assert(test_card != null, "HUD test card should exist")
	assert(Global.add_card_to_player(1, test_card), "HUD test card should be added")
	main.hud._refresh_upgrade_bar()
	assert(main.hud._upgrade_bar.visible, "Upgrade bar should be visible for the local player")
	assert(main.hud._upgrade_flow.get_child_count() > 0, "Upgrade bar should display card icons")
	main.hud._refresh_tab_overlay()
	assert(main.hud._tab_content.get_child_count() > 0, "Tab overlay should display character stats and cards")
	assert(Global.points_to_win == 500, "Default match target should be 500 points")
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
	print("[TEST] Players spawned: P1 at ", p1.global_position, " | P2 at ", p2.global_position)

	# Simulate combat
	print("[TEST] Simulating 1.5s of combat...")
	await get_tree().create_timer(1.5).timeout

	print("[TEST] P1 HP: ", p1.current_health, " | P2 HP: ", p2.current_health)
	var shots_before := Global.get_match_stat(1, "shots_fired")
	var spawned_bullet: Bullet = p1._spawn_bullet(Vector2.RIGHT)
	assert(is_equal_approx(Global.get_match_stat(1, "shots_fired"), shots_before + 1.0), "Firing a projectile should be tracked")
	assert(spawned_bullet != null and is_equal_approx(spawned_bullet.projectile_gravity_mult, p1.projectile_gravity_mult), "Spawned projectiles should inherit the player's gravity modifier")

	# Trigger round defeat: clear invulnerability flags if any
	print("[TEST] Simulating P2 defeat...")
	p2.is_invulnerable = false
	p2.is_blocking = false
	p2.take_damage(9999.0, Vector2.ZERO, p1)

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
	print("[TEST] Card Draft UI triggered successfully with ", main.card_draft_ui.offered_cards.size(), " cards.")

	print("[TEST] Waiting for bot auto-draft (process_mode=ALWAYS timer)...")
	# Use process timer because tree is paused during draft
	await get_tree().create_timer(1.5, true).timeout

	var p2_cards = Global.get_player_cards(2)
	print("[TEST] P2 Cards after draft: ", p2_cards.size())
	assert(p2_cards.size() == 1, "P2 should have drafted 1 card")
	print("[TEST] Successfully drafted card: ", p2_cards[0].title)

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

	print("[SUCCESS] All integration tests passed smoothly! Game mechanics 100% verified.")
	get_tree().quit(0)
