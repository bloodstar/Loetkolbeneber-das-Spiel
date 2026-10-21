class_name MainGame
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
# Wird von der Testszene gesetzt, um das Hauptmenü zu überspringen.
@export var skip_menu: bool = false

@onready var level_generator: LevelGenerator = $ProceduralLevel
@onready var camera: DynamicCamera = $DynamicCamera
@onready var hud: HUD = $HUD
@onready var card_draft_ui: CardDraftUI = $CardDraftUI
@onready var lobby: Lobby = $Lobby
@onready var main_menu: MainMenu = $MainMenu
@onready var sudden_death_timer: Timer = $SuddenDeathTimer
@onready var lava_overlay: ColorRect = $LavaOverlay

var p1: Player = null
var p2: Player = null
var is_sudden_death: bool = false
var lava_y_pos: float = 900.0
var p1_hero_id: String = ""
var p2_hero_id: String = ""

# --- Netzwerk ---
var is_network_host: bool = false
var is_network_client: bool = false
var match_seed: int = 0
var net_snapshot_timer: float = 0.0
var net_input_timer: float = 0.0
var local_shoot_sound_timer: float = 0.0
var pending_jump: bool = false
var pending_jump_release: bool = false
var pending_dash: bool = false
var pending_ability: bool = false
var remote_bullets: Dictionary = {}
var remote_towers: Dictionary = {}
const SNAPSHOT_INTERVAL: float = 1.0 / 25.0
const INPUT_INTERVAL: float = 1.0 / 30.0

# Start-Countdown
const ROUND_COUNTDOWN_SECONDS: float = 3.0
var countdown_active: bool = false
var countdown_remaining: float = 0.0
var countdown_last_number: int = 3

func _ready() -> void:
	print("--- MAIN.GD: _ready() – Spiel bereit, zeige Hauptmenü. ---")
	# Wire signals
	Global.round_ended.connect(_on_round_ended)
	Global.card_selected.connect(_on_card_selected)
	card_draft_ui.draft_sequence_finished.connect(_on_draft_sequence_finished)
	lobby.lobby_confirmed.connect(_on_lobby_confirmed)
	lobby.lobby_cancelled.connect(_on_lobby_cancelled)
	sudden_death_timer.timeout.connect(_start_sudden_death)
	main_menu.start_requested.connect(_on_menu_start_requested)
	Global.match_over.connect(_on_match_over)
	
	# Online-Multiplayer
	main_menu.host_requested.connect(_on_menu_host_requested)
	main_menu.join_requested.connect(_on_menu_join_requested)
	main_menu.network_cancel_requested.connect(_on_menu_network_cancel)
	NetworkManager.join_succeeded.connect(_on_network_join_succeeded)
	NetworkManager.join_failed.connect(_on_network_join_failed)
	NetworkManager.host_failed.connect(_on_network_host_failed)
	NetworkManager.peer_left.connect(_on_network_peer_left)
	NetworkManager.server_closed.connect(_on_network_server_closed)
	NetworkManager.match_start_received.connect(_on_network_match_start)
	NetworkManager.round_start_received.connect(_on_network_round_start)
	NetworkManager.snapshot_received.connect(_on_network_snapshot)
	NetworkManager.input_received.connect(_on_network_input)
	NetworkManager.draft_start_received.connect(_on_network_draft_start)
	NetworkManager.draft_pick_received.connect(_on_network_draft_pick)
	NetworkManager.draft_pick_requested.connect(_on_network_draft_pick_requested)
	NetworkManager.match_over_received.connect(_on_network_match_over)
	NetworkManager.tile_broken_received.connect(_on_network_tile_broken)
	NetworkManager.tile_regrown_received.connect(_on_network_tile_regrown)
	NetworkManager.zone_spawn_received.connect(_on_network_zone_spawn)
	level_generator.tile_broken.connect(_on_level_tile_broken)
	level_generator.tile_regrown.connect(_on_level_tile_regrown)
	
	lava_overlay.visible = false
	
	if skip_menu:
		# Direkt in eine Runde springen (z. B. für automatisierte Tests).
		main_menu.close_menu()
		_start_fresh_round()
	else:
		Global.current_state = Global.GameState.MENU
		main_menu.open_menu()

func _on_menu_start_requested() -> void:
	# Lokales Spiel: eine eventuell offene Online-Verbindung sauber beenden.
	if NetworkManager.is_network_active():
		NetworkManager.disconnect_peer()
	is_network_host = false
	is_network_client = false
	Global.network_mode = false
	Global.remote_connected = false
	Global.set_local_player(1)
	_start_setup_phase()

func _input(event: InputEvent) -> void:
	# Die Bot-Steuerung wird ausschließlich in der Lobby gewählt. Während einer
	# Runde gibt es bewusst keinen F1-Umschalter mehr.
	if event.is_action_pressed("restart_game") and not event.is_echo():
		if Global.network_mode:
			return
		# Startet den gesamten Setup-Prozess neu (inkl. Lobby)
		_start_setup_phase()

# --- Setup Phase Management ---

func _start_setup_phase() -> void:
	# Neues Match: Punktestand und Karten zurücksetzen, dann Lobby öffnen.
	Global.reset_match()
	Global.current_state = Global.GameState.LOBBY
	get_tree().paused = false
	lobby.open_lobby()

func _on_lobby_confirmed() -> void:
	if is_network_host:
		NetworkManager.send_start_match(_build_network_config())
	_start_fresh_round()

func _on_lobby_cancelled() -> void:
	if is_network_host or is_network_client or NetworkManager.is_network_active():
		_abort_network_match("")
		return
	# Zurück ins Hauptmenü, ohne eine Runde zu starten.
	Global.current_state = Global.GameState.MENU
	main_menu.open_menu()

func _start_fresh_round(forced_seed: int = 0) -> void:
	Global.current_state = Global.GameState.PLAYING
	get_tree().paused = false
	lobby.close_lobby()
	card_draft_ui.close_draft()
	
	# Gemeinsamer Level-Seed: Host und Client bauen dieselbe Karte.
	var level_seed := forced_seed
	if level_seed <= 0:
		level_seed = maxi(1, randi())
	match_seed = level_seed
	if is_network_host and NetworkManager.has_client():
		NetworkManager.send_round_start(level_seed)
	
	_clear_remote_bullets()
	_clear_remote_towers()
	_clear_round_effects()
	
	# 1. Level regenerieren
	level_generator.generate_level(level_seed)
	
	# 2. Reset Sudden Death. Der Timer startet erst nach dem Start-Countdown.
	is_sudden_death = false
	lava_overlay.visible = false
	lava_y_pos = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE)
	lava_overlay.position.y = lava_y_pos
	sudden_death_timer.stop()
	hud.set_sudden_death(false)
	
	_spawn_players()
	hud.reset_for_round()
	_start_round_countdown()
	
	if is_network_host and NetworkManager.has_client():
		_send_snapshot()

func _spawn_players() -> void:
	# Clean up any lingering players
	if p1 and is_instance_valid(p1):
		p1.queue_free()
	if p2 and is_instance_valid(p2):
		p2.queue_free()
	
	# Spawn P1
	p1 = player_scene.instantiate()
	p1.player_index = 1
	p1.is_bot = false
	p1.is_replica = is_network_client
	add_child(p1)
	p1.global_position = level_generator.p1_spawn_pos
	p1.died.connect(_on_player_died)
	
	# Spawn P2
	p2 = player_scene.instantiate()
	p2.player_index = 2
	p2.is_bot = (false if Global.network_mode else Global.is_bot_enabled)
	p2.is_replica = is_network_client
	p2.is_remote = is_network_host
	add_child(p2)
	p2.global_position = level_generator.p2_spawn_pos
	p2.died.connect(_on_player_died)
	
	# Cross-reference opponents
	p1.opponent = p2
	p2.opponent = p1
	
	_update_p2_bot_controller()
	
	# Connect Camera
	camera.targets.clear()
	camera.add_target(p1)
	camera.add_target(p2)
	
	# Connect HUD
	hud.connect_player_signals(p1, p2)
	hud.update_all()

func _start_round_countdown() -> void:
	countdown_active = true
	countdown_remaining = ROUND_COUNTDOWN_SECONDS
	countdown_last_number = 3
	sudden_death_timer.stop()

	if p1 and is_instance_valid(p1):
		p1.control_enabled = false
		p1.velocity.x = 0.0
	if p2 and is_instance_valid(p2):
		p2.control_enabled = false
		p2.velocity.x = 0.0

	_flash_local_character()
	hud.show_countdown_number(3)

func _update_round_countdown(delta: float) -> void:
	if not countdown_active:
		return
	if Global.current_state != Global.GameState.PLAYING:
		_cancel_round_countdown()
		return

	countdown_remaining -= delta
	var number := int(ceil(countdown_remaining))
	if number > 0 and number != countdown_last_number:
		countdown_last_number = number
		hud.show_countdown_number(number)

	if countdown_remaining <= 0.0:
		_end_round_countdown()

func _end_round_countdown() -> void:
	if not countdown_active:
		return
	countdown_active = false
	countdown_remaining = 0.0

	if p1 and is_instance_valid(p1):
		p1.control_enabled = true
	if p2 and is_instance_valid(p2):
		p2.control_enabled = true

	hud.show_countdown_go()
	if not is_network_client:
		sudden_death_timer.start(38.0)

	var hide_timer := get_tree().create_timer(0.8)
	hide_timer.timeout.connect(_hide_countdown_after_start)

func _hide_countdown_after_start() -> void:
	if Global.current_state == Global.GameState.PLAYING:
		hud.hide_countdown()

func _cancel_round_countdown() -> void:
	countdown_active = false
	countdown_remaining = 0.0
	hud.hide_countdown()

func _flash_local_character() -> void:
	if Global.network_mode:
		if Global.local_player_index == 1:
			if p1 and is_instance_valid(p1):
				p1.flash_intro()
		else:
			if p2 and is_instance_valid(p2):
				p2.flash_intro()
	else:
		if p1 and is_instance_valid(p1):
			p1.flash_intro()
		if not Global.is_bot_enabled and p2 and is_instance_valid(p2):
			p2.flash_intro()

func _update_p2_bot_controller() -> void:
	if not p2 or not is_instance_valid(p2):
		return
	
	var existing_ai = p2.get_node_or_null("AIController")
	if p2.is_bot:
		if not existing_ai:
			var ai = AIController.new()
			ai.name = "AIController"
			p2.add_child(ai)
	else:
		if existing_ai:
			existing_ai.queue_free()

func _process(delta: float) -> void:
	if countdown_active:
		_update_round_countdown(delta)

	if is_network_client:
		_process_network_client(delta)
	elif is_sudden_death and Global.current_state == Global.GameState.PLAYING:
		# Lava rises steadily
		lava_y_pos -= 35.0 * delta
		lava_overlay.position.y = lava_y_pos
		lava_overlay.size.y = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE) - lava_y_pos + 100.0
		
		# Check if players touch lava
		if p1 and is_instance_valid(p1) and p1.global_position.y > lava_y_pos:
			p1.take_damage(40.0 * delta, Vector2(0, -100.0))
		if p2 and is_instance_valid(p2) and p2.global_position.y > lava_y_pos:
			p2.take_damage(40.0 * delta, Vector2(0, -100.0))
	
	if is_network_host and NetworkManager.has_client() and Global.current_state == Global.GameState.PLAYING:
		net_snapshot_timer += delta
		if net_snapshot_timer >= SNAPSHOT_INTERVAL:
			net_snapshot_timer = 0.0
			_send_snapshot()

func _start_sudden_death() -> void:
	is_sudden_death = true
	lava_overlay.visible = true
	lava_overlay.position.x = 0
	lava_overlay.size.x = (level_generator.MAP_WIDTH * level_generator.TILE_SIZE)
	lava_y_pos = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE)
	hud.set_sudden_death(true)
	SoundManager.play_sound("explosion", 0.1, 2.0)

func _on_player_died(dead_player_index: int) -> void:
	_cancel_round_countdown()
	camera.shake(0.55)
	var winner_index = 2 if dead_player_index == 1 else 1
	Global.award_round(winner_index)

func _on_round_ended(loser_index: int) -> void:
	_cancel_round_countdown()
	if is_network_client:
		return
	# Letzten Spielstand (inkl. Tod) an den Client schicken, bevor pausiert wird.
	if is_network_host and NetworkManager.has_client():
		_send_snapshot()
	# All losers draft sequentially and publicly
	card_draft_ui.start_draft_sequence([loser_index])

func _on_match_over(winner_index: int) -> void:
	_cancel_round_countdown()
	if is_network_host and NetworkManager.has_client():
		_send_snapshot()
		NetworkManager.send_match_over(winner_index, Global.p1_score, Global.p2_score)

# --- Spezial-Tiles: Host ist autoritativ, Client übernimmt per RPC ---

func _on_level_tile_broken(tile_id: int) -> void:
	if is_network_host and NetworkManager.has_client():
		NetworkManager.send_tile_broken(tile_id)

func _on_level_tile_regrown(tile_id: int) -> void:
	if is_network_host and NetworkManager.has_client():
		NetworkManager.send_tile_regrown(tile_id)

func _on_network_tile_broken(tile_id: int) -> void:
	if is_network_client:
		level_generator.apply_network_tile_broken(tile_id)

func _on_network_tile_regrown(tile_id: int) -> void:
	if is_network_client:
		level_generator.apply_network_tile_regrown(tile_id)

func _on_card_selected(_p_idx: int, _card: CardData) -> void:
	pass

func _on_draft_sequence_finished() -> void:
	if is_network_client:
		# Der Client wartet auf das Signal des Hosts für die nächste Runde.
		return
	# Advance to next round with freshly generated Mario stage!
	_start_fresh_round()

# ============================================================
# Online-Multiplayer
# ============================================================

func _build_network_config() -> Dictionary:
	return {
		"score_to_win": Global.score_to_win,
		"draft_picks": Global.draft_picks,
		"cards_per_draft": Global.cards_per_draft,
		"bans": Global.banned_card_ids.duplicate(),
		"p1_hero": Global.p1_hero_id,
		"p2_hero": Global.p2_hero_id,
		"base_hp": Global.base_hp_override,
		"is_bot": false,
	}

func _apply_network_config(config: Dictionary) -> void:
	Global.p1_hero_id = str(config.get("p1_hero", Global.p1_hero_id))
	Global.p2_hero_id = str(config.get("p2_hero", Global.p2_hero_id))
	Global.set_score_to_win(int(config.get("score_to_win", Global.score_to_win)))
	Global.set_draft_config(
		int(config.get("draft_picks", Global.draft_picks)),
		int(config.get("cards_per_draft", Global.cards_per_draft))
	)
	Global.banned_card_ids.clear()
	for card_id in config.get("bans", []):
		Global.banned_card_ids.append(str(card_id))
	Global.banned_cards_changed.emit()
	Global.set_base_hp_override(int(config.get("base_hp", Global.base_hp_override)))
	Global.set_bot_enabled(false)
	Global.reset_match()
	Global.current_state = Global.GameState.PLAYING

# --- Menü-Aktionen ---

func _on_menu_host_requested(port: int) -> void:
	var err := NetworkManager.host_game(port)
	if err != OK:
		main_menu.set_network_status("Host konnte nicht gestartet werden. Anderen Port versuchen.", true)
		return
	is_network_host = true
	is_network_client = false
	main_menu.close_menu()
	Global.reset_match()
	Global.current_state = Global.GameState.LOBBY
	Global.network_mode = true
	Global.remote_connected = false
	Global.set_local_player(1)
	lobby.open_lobby()

func _on_menu_join_requested(address: String, port: int) -> void:
	var err := NetworkManager.join_game(address, port)
	if err != OK:
		main_menu.set_network_status("Verbindung konnte nicht gestartet werden.", true)

func _on_menu_network_cancel() -> void:
	NetworkManager.disconnect_peer()
	is_network_host = false
	is_network_client = false
	Global.network_mode = false
	Global.remote_connected = false
	Global.set_local_player(1)

func _on_network_host_failed(reason: String) -> void:
	main_menu.set_network_status(reason, true)

func _on_network_join_failed(reason: String) -> void:
	main_menu.set_network_status(reason, true)

func _on_network_join_succeeded() -> void:
	if is_network_client:
		return
	is_network_client = true
	is_network_host = false
	main_menu.close_menu()
	Global.reset_match()
	Global.current_state = Global.GameState.LOBBY
	Global.network_mode = true
	Global.remote_connected = true
	Global.set_local_player(2)
	lobby.open_lobby()

# --- Verbindungsabbruch ---

func _on_network_peer_left() -> void:
	if not is_network_host:
		return
	if Global.current_state == Global.GameState.LOBBY:
		return
	_abort_network_match("Mitspieler hat das Spiel verlassen.")

func _on_network_server_closed() -> void:
	if not is_network_client:
		return
	_abort_network_match("Verbindung zum Host verloren.")

func _abort_network_match(reason: String) -> void:
	is_network_host = false
	is_network_client = false
	NetworkManager.disconnect_peer()
	Global.network_mode = false
	Global.remote_connected = false
	Global.set_local_player(1)
	Global.current_state = Global.GameState.MENU
	get_tree().paused = false
	lobby.close_lobby()
	card_draft_ui.close_draft()
	_cancel_round_countdown()
	_clear_players()
	_clear_remote_bullets()
	_clear_remote_towers()
	_clear_round_effects()
	main_menu.open_menu(reason)

# --- Match-Start ---

func _on_network_match_start(config: Dictionary) -> void:
	if not is_network_client:
		return
	_apply_network_config(config)

func _on_network_round_start(level_seed: int) -> void:
	if not is_network_client:
		return
	lobby.close_lobby()
	main_menu.close_menu()
	_start_fresh_round(level_seed)

# --- Laufendes Spiel: Eingaben & Snapshots ---

func _process_network_client(delta: float) -> void:
	if Global.current_state != Global.GameState.PLAYING:
		return
	if countdown_active:
		pending_jump = false
		pending_jump_release = false
		pending_dash = false
		pending_ability = false
		return
	
	if local_shoot_sound_timer > 0.0:
		local_shoot_sound_timer -= delta
	
	if Input.is_action_just_pressed("p1_jump"):
		pending_jump = true
		SoundManager.play_sound("click", 0.25, -4.0)
	if Input.is_action_just_released("p1_jump"):
		pending_jump_release = true
	if Input.is_action_just_pressed("p1_dash"):
		pending_dash = true
		SoundManager.play_sound("dash", 0.2, 0.0)
	if Input.is_action_just_pressed("p1_ability") \
			or Input.is_action_just_pressed("p1_ability_alt") \
			or Input.is_action_just_pressed("p1_ability_q") \
			or Input.is_action_just_pressed("p1_ability_f"):
		pending_ability = true
	if Input.is_action_pressed("p1_shoot") and local_shoot_sound_timer <= 0.0:
		SoundManager.play_sound("shoot", 0.15, 0.0)
		local_shoot_sound_timer = 0.35
	
	net_input_timer += delta
	if net_input_timer < INPUT_INTERVAL:
		return
	net_input_timer = 0.0
	
	# Zielrichtung aus der Maus (Weltkoordinate).
	var aim := Vector2.RIGHT
	if p2 and is_instance_valid(p2):
		var cam := get_viewport().get_camera_2d()
		if cam:
			aim = (cam.get_global_mouse_position() - p2.global_position).normalized()
	
	NetworkManager.send_input({
		"move_x": Input.get_axis("p1_left", "p1_right"),
		"aim": aim,
		"shoot": Input.is_action_pressed("p1_shoot"),
		"jump": pending_jump,
		"jump_release": pending_jump_release,
		"dash": pending_dash,
		"ability": pending_ability,
	})
	pending_jump = false
	pending_jump_release = false
	pending_dash = false
	pending_ability = false

func _on_network_input(data: Dictionary) -> void:
	if not is_network_host or Global.current_state != Global.GameState.PLAYING:
		return
	if countdown_active:
		return
	if p2 and is_instance_valid(p2) and p2.is_remote and p2.control_enabled:
		p2.set_remote_input(data)

func _send_snapshot() -> void:
	if not is_network_host or not NetworkManager.has_client():
		return
	NetworkManager.send_snapshot({
		"p1": _player_snapshot(p1),
		"p2": _player_snapshot(p2),
		"bullets": _bullet_snapshots(),
		"towers": _tower_snapshots(),
		"scores": [Global.p1_score, Global.p2_score],
		"sudden": is_sudden_death,
		"lava": lava_y_pos,
	})

func _player_snapshot(player: Player) -> Dictionary:
	if not player or not is_instance_valid(player) or not player.visible:
		return {}
	if player.current_health <= 0.0:
		return {}
	return {
		"pos": player.global_position,
		"vel": player.velocity,
		"hp": player.current_health,
		"max_hp": player.max_health,
		"shield": player.current_shield,
		"max_shield": player.max_shield,
		"ammo": player.current_ammo,
		"max_ammo": player.max_ammo,
		"aim": player.aim_direction,
		"ability": player.ability_timer,
		"ability_max": player.ability_max_cooldown,
		"reload": player.is_reloading,
		"barrier": player.is_barrier_active,
	}

func _bullet_snapshots() -> Array:
	var result: Array = []
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.is_replica:
			continue
		result.append({
			"id": b.net_id,
			"pos": b.global_position,
			"vel": b.velocity,
			"rot": b.rotation,
			"scale": b.scale.x,
			"color": b.modulate,
		})
	return result

func _tower_snapshots() -> Array:
	var result: Array = []
	for t in get_tree().get_nodes_in_group("tower"):
		if not is_instance_valid(t) or t.is_replica:
			continue
		var owner_index := 0
		if is_instance_valid(t.owner_player):
			owner_index = t.owner_player.player_index
		result.append({
			"id": t.net_id,
			"pos": t.global_position,
			"owner": owner_index,
		})
	return result

func _on_network_snapshot(data: Dictionary) -> void:
	if not is_network_client:
		return
	_apply_player_snapshot(1, data.get("p1", {}))
	_apply_player_snapshot(2, data.get("p2", {}))
	_sync_remote_bullets(data.get("bullets", []))
	_sync_remote_towers(data.get("towers", []))
	
	var scores = data.get("scores", [])
	if scores is Array and scores.size() >= 2:
		Global.set_network_scores(int(scores[0]), int(scores[1]))
	
	var sudden := bool(data.get("sudden", false))
	if sudden != is_sudden_death:
		is_sudden_death = sudden
		hud.set_sudden_death(sudden)
	lava_y_pos = float(data.get("lava", lava_y_pos))
	_update_lava_overlay()

func _apply_player_snapshot(index: int, data: Dictionary) -> void:
	var player = p1 if index == 1 else p2
	if not player or not is_instance_valid(player):
		return
	if data.is_empty():
		player.visible = false
		camera.remove_target(player)
		return
	if not player.visible:
		player.visible = true
		camera.add_target(player)
	player.apply_network_state(data)

func _sync_remote_bullets(list: Array) -> void:
	var seen := {}
	for entry in list:
		var bullet_id := int(entry.get("id", 0))
		if bullet_id == 0:
			continue
		seen[bullet_id] = true
		var b = remote_bullets.get(bullet_id, null)
		if b == null or not is_instance_valid(b):
			b = bullet_scene.instantiate()
			b.is_replica = true
			b.net_id = bullet_id
			add_child(b)
			b.position = entry.get("pos", Vector2.ZERO)
			remote_bullets[bullet_id] = b
		b.apply_network_state(entry)
	
	for bullet_id in remote_bullets.keys():
		if not seen.has(bullet_id):
			var b = remote_bullets[bullet_id]
			if is_instance_valid(b):
				b.queue_free()
			remote_bullets.erase(bullet_id)

func _clear_remote_bullets() -> void:
	for b in remote_bullets.values():
		if is_instance_valid(b):
			b.queue_free()
	remote_bullets.clear()

func _sync_remote_towers(list: Array) -> void:
	var seen := {}
	for entry in list:
		var tower_id := int(entry.get("id", 0))
		if tower_id == 0:
			continue
		seen[tower_id] = true
		var tower = remote_towers.get(tower_id, null)
		if tower == null or not is_instance_valid(tower):
			tower = Companion.new()
			tower.mode = Companion.Mode.TOWER
			tower.is_replica = true
			var owner_index := int(entry.get("owner", 1))
			tower.owner_player = p1 if owner_index == 1 else p2
			add_child(tower)
			remote_towers[tower_id] = tower
		tower.apply_network_state(entry.get("pos", tower.global_position))

	for tower_id in remote_towers.keys():
		if not seen.has(tower_id):
			var tower = remote_towers[tower_id]
			if is_instance_valid(tower):
				tower.queue_free()
			remote_towers.erase(tower_id)

func _clear_remote_towers() -> void:
	for t in remote_towers.values():
		if is_instance_valid(t):
			t.queue_free()
	remote_towers.clear()

# Entfernt Türme und Flächeneffekte der vorherigen Runde. Drones hängen an den
# Spielern und werden mit diesen neu erzeugt.
func _clear_round_effects() -> void:
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower) and not tower.is_replica:
			tower.queue_free()
	for zone in get_tree().get_nodes_in_group("effect_zone"):
		if is_instance_valid(zone):
			zone.queue_free()

func _on_network_zone_spawn(data: Dictionary) -> void:
	if not is_network_client:
		return
	var owner_index := int(data.get("owner_index", 1))
	var owner = p1 if owner_index == 1 else p2
	if owner and is_instance_valid(owner):
		owner.spawn_network_zone(data)

func _update_lava_overlay() -> void:
	lava_overlay.visible = is_sudden_death
	lava_overlay.position.x = 0.0
	lava_overlay.size.x = (level_generator.MAP_WIDTH * level_generator.TILE_SIZE)
	lava_overlay.position.y = lava_y_pos
	lava_overlay.size.y = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE) - lava_y_pos + 100.0

# --- Draft / Match-Ende ---

func _on_network_draft_start(drafter: int, card_ids: Array, picks_total: int) -> void:
	if not is_network_client:
		return
	card_draft_ui.start_network_draft(drafter, card_ids, picks_total)

func _on_network_draft_pick(card_id: String) -> void:
	if not is_network_client or not card_draft_ui.visible:
		return
	card_draft_ui.apply_network_pick(card_id)

func _on_network_draft_pick_requested(card_id: String) -> void:
	if not is_network_host or not card_draft_ui.visible:
		return
	# Der Client darf nur während seines eigenen Drafts wählen (er ist Spieler 2).
	if card_draft_ui.current_drafter != 2:
		return
	card_draft_ui.apply_network_pick(card_id)

func _on_network_match_over(winner_index: int, p1_score: int, p2_score: int) -> void:
	if not is_network_client:
		return
	Global.set_network_scores(p1_score, p2_score)
	Global.set_network_match_over(winner_index)

func _clear_players() -> void:
	if p1 and is_instance_valid(p1):
		p1.queue_free()
	if p2 and is_instance_valid(p2):
		p2.queue_free()
	p1 = null
	p2 = null
	camera.targets.clear()
