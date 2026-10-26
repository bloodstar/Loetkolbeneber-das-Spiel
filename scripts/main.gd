class_name MainGame
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
@export var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
const LevelModifierManagerClass = preload("res://scripts/level_modifier_manager.gd")
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

# Alle aktiven Spieler (Index 1..player_count). Slot = player_index.
var players: Array[Player] = []
var modifier_manager: Node = null
var is_sudden_death: bool = false
var lava_y_pos: float = 900.0
# Reihenfolge der Tode in der aktuellen Runde (für Gleichstand bei Doppel-KO).
var round_death_order: Array[int] = []
# Verhindert doppelte Statistik-Samples, falls das Match-Ende mehrfach signalisiert wird.
var card_stats_match_recorded: bool = false

# --- Netzwerk ---
var is_network_host: bool = false
var is_network_client: bool = false
var match_seed: int = 0
var match_map_id: String = ""
var net_snapshot_timer: float = 0.0
var net_input_timer: float = 0.0
var local_shoot_sound_timer: float = 0.0
var pending_jump: bool = false
var pending_jump_release: bool = false
var pending_dash: bool = false
var pending_ability: bool = false
var pending_block: bool = false
var pending_reload: bool = false
var remote_bullets: Dictionary = {}
var remote_towers: Dictionary = {}
# Auf Clients: zuletzt gesehener Lebenszustand pro Slot. Ein leerer Snapshot
# nach einem lebenden Snapshot ist ein Tod und löst den lokalen Todeston aus.
var network_alive_slots: Dictionary = {}
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
	hud.restart_requested.connect(_on_hud_restart_requested)
	hud.continue_requested.connect(_on_hud_continue_requested)

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

	modifier_manager = LevelModifierManagerClass.new()
	add_child(modifier_manager)
	modifier_manager.modifiers_rolled.connect(hud.on_modifiers_revealed)
	modifier_manager.wind_changed.connect(hud.show_wind_notice)
	modifier_manager.coin_collected.connect(hud.update_bounty_notice)
	modifier_manager.pinata_hit.connect(hud.update_pinata_notice)

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
	Global.is_spectator = false
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

func _start_fresh_round(forced_seed: int = 0, forced_map_id: String = "") -> void:
	Global.current_state = Global.GameState.PLAYING
	get_tree().paused = false
	lobby.close_lobby()
	card_draft_ui.close_draft()

	# Gemeinsamer Level-Seed: Host und alle Clients bauen dieselbe Karte.
	var level_seed := forced_seed
	if level_seed <= 0:
		level_seed = maxi(1, randi())
	match_seed = level_seed
	var map_id := forced_map_id
	if map_id.is_empty():
		map_id = Global.resolve_map_id(level_seed)
	match_map_id = map_id
	if is_network_host and NetworkManager.has_clients():
		NetworkManager.send_round_start(level_seed, map_id, Global.points_to_win)

	_clear_remote_bullets()
	_clear_remote_towers()
	_clear_round_effects()
	round_death_order.clear()
	card_stats_match_recorded = false

	# 1. Level-Modifier deterministisch bestimmen.
	var active_mods: Array[String] = []
	if modifier_manager != null:
		active_mods = modifier_manager.roll_modifiers(level_seed)

	# 2. Level regenerieren. Erst danach die Modifier-Hazards spawnen, damit
	#    Münzen, Meteore und Heilzonen die neue Karte als Grundlage nutzen.
	level_generator.generate_level(level_seed, map_id, active_mods)
	if modifier_manager != null:
		modifier_manager.start_round_modifiers(active_mods, self, level_generator)

	# 3. Reset Sudden Death. Der Timer startet erst nach dem Start-Countdown.
	is_sudden_death = false
	lava_overlay.visible = false
	lava_y_pos = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE)
	lava_overlay.position.y = lava_y_pos
	sudden_death_timer.stop()
	hud.set_sudden_death(false)

	_spawn_players()
	hud.reset_for_round()
	_start_round_countdown()

	if is_network_host and NetworkManager.has_clients():
		_send_snapshot()

# Liefert den Spieler mit dem gegebenen Slot-Index (1..6) oder null.
func get_player(index: int) -> Player:
	for p in players:
		if is_instance_valid(p) and p.player_index == index:
			return p
	return null

func _spawn_players() -> void:
	_clear_players()
	network_alive_slots.clear()

	var active_indices := Global.get_active_player_indices()
	var total := active_indices.size()
	for i in active_indices:
		var p: Player = player_scene.instantiate()
		p.player_index = i
		p.team_id = Global.get_team_for_slot(i)
		p.is_bot = Global.is_bot_slot(i)
		p.is_replica = is_network_client
		# Auf dem Host werden menschliche Slots außer Slot 1 von Clients gesteuert.
		p.is_remote = is_network_host and Global.is_human_slot(i) and i != 1
		# Position vor dem Einfügen in den Baum setzen: Sonst registriert die
		# Physik den Körper kurz bei (0, 0) und die Gummiwände schleudern ihn
		# beim Rundenstart scheinbar grundlos durch die Arena.
		p.position = level_generator.get_spawn_position(i, total)
		add_child(p)
		p.died.connect(_on_player_died)
		players.append(p)
		if modifier_manager != null:
			modifier_manager.apply_player_modifiers(p)

	# Gegner-Zuordnung: jeweils der nächste andere Spieler (für KI und Homing).
	for p in players:
		p.opponent = _nearest_other(p)

	_update_bot_controllers()

	# Kamera folgt allen Spielern.
	camera.targets.clear()
	for p in players:
		camera.add_target(p)
	_start_camera_round_intro()

	hud.setup_players(players)
	hud.update_all()

# Startet die Kamera nah am eigenen Charakter. Anschließend zoomt sie während
# des Countdowns zur normalen Übersicht über alle Spieler heraus.
func _start_camera_round_intro() -> void:
	if Global.is_spectator:
		camera.cancel_round_intro()
		return
	var focus := get_player(Global.local_player_index)
	if focus == null:
		focus = get_player(1)
	if focus == null or not is_instance_valid(focus):
		camera.cancel_round_intro()
		return
	camera.start_round_intro(focus, ROUND_COUNTDOWN_SECONDS * 0.72, 1.65)

func _nearest_other(origin: Player) -> Player:
	var best: Player = null
	var best_dist := INF
	for other in players:
		if other == origin or not is_instance_valid(other):
			continue
		if other.team_id == origin.team_id:
			continue
		var d := origin.global_position.distance_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best

func _update_bot_controllers() -> void:
	# Auf Clients laufen alle Figuren als Replikate; KI ist dort unnötig.
	if is_network_client:
		return
	for p in players:
		if not is_instance_valid(p):
			continue
		var existing := p.get_node_or_null("AIController")
		if p.is_bot:
			if not existing:
				var ai := AIController.new()
				ai.name = "AIController"
				p.add_child(ai)
		elif existing:
			existing.queue_free()

func _start_round_countdown() -> void:
	countdown_active = true
	countdown_remaining = ROUND_COUNTDOWN_SECONDS
	countdown_last_number = 3
	sudden_death_timer.stop()

	for p in players:
		if is_instance_valid(p):
			p.control_enabled = false
			p.velocity.x = 0.0

	_play_local_spawn_intro()
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

	for p in players:
		if is_instance_valid(p):
			p.control_enabled = true

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

func _play_local_spawn_intro() -> void:
	if Global.network_mode:
		var local := get_player(Global.local_player_index)
		if local and is_instance_valid(local):
			local.play_spawn_intro()
	else:
		# Lokal: eigener Charakter (P1) und alle nicht-Bot-Mitspieler erscheinen
		# aus einem Portal. Bots bleiben außen vor.
		for p in players:
			if is_instance_valid(p) and (p.player_index == 1 or not p.is_bot):
				p.play_spawn_intro()

func _process(delta: float) -> void:
	if countdown_active:
		_update_round_countdown(delta)

	if is_network_client:
		_process_network_client(delta)
	elif Global.current_state == Global.GameState.PLAYING:
		if not countdown_active and modifier_manager != null:
			modifier_manager.update_physics_modifiers(delta, players)

		if is_sudden_death:
			# Lava rises steadily
			lava_y_pos -= 35.0 * delta
			lava_overlay.position.y = lava_y_pos
			lava_overlay.size.y = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE) - lava_y_pos + 100.0

			# Check if players touch lava
			for p in players:
				if is_instance_valid(p) and p.global_position.y > lava_y_pos:
					p.take_damage(40.0 * delta, Vector2(0, -100.0))

	if is_network_host and NetworkManager.has_clients() and Global.current_state == Global.GameState.PLAYING:
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
	if Global.current_state != Global.GameState.PLAYING:
		return
	camera.shake(0.55)
	round_death_order.append(dead_player_index)
	Global.add_match_stat(dead_player_index, "deaths", 1.0)

	# Kill-Punkte sofort gutschreiben. Der Schütze wird über die letzte
	# Schadensquelle am gestorbenen Spieler ermittelt.
	var dead_player := get_player(dead_player_index)
	if dead_player != null and is_instance_valid(dead_player):
		var killer := dead_player.last_damage_source
		if killer != null and is_instance_valid(killer) and killer.player_index != dead_player_index and killer.team_id != dead_player.team_id:
			Global.award_kill(killer.player_index, dead_player_index)
			Global.add_match_stat(killer.player_index, "kills", 1.0)
			CardStats.record_kill(killer.player_index)

	# Runde endet in FFA, wenn höchstens noch ein Spieler lebt. In Team-Modi
	# endet sie, sobald nur noch ein Team lebende Mitglieder hat.
	var alive: Array[int] = []
	var alive_teams: Array[int] = []
	for p in players:
		if is_instance_valid(p) and p.current_health > 0.0:
			alive.append(p.player_index)
			if not alive_teams.has(p.team_id):
				alive_teams.append(p.team_id)

	var team_mode := Global.is_team_mode()
	if team_mode:
		if alive_teams.size() > 1:
			return
	else:
		if alive.size() > 1:
			return

	var winner := 0
	var award_survival := false
	if team_mode:
		if alive_teams.size() == 1:
			winner = _best_team_member(alive_teams[0], alive)
			award_survival = true
		elif not round_death_order.is_empty():
			# Doppel-KO: das Team des zuletzt gestorbenen Spielers gewinnt.
			var last_dead := round_death_order[round_death_order.size() - 1]
			winner = _best_team_member(Global.get_team_for_slot(last_dead), [])
	elif alive.size() == 1:
		winner = alive[0]
		award_survival = true
	elif not round_death_order.is_empty():
		# Doppel-KO: der zuletzt gestorbene Spieler gewinnt die Runde.
		winner = round_death_order[round_death_order.size() - 1]

	if winner > 0:
		Global.award_round(winner, award_survival)

func _best_team_member(team: int, candidates: Array = []) -> int:
	var pool: Array = candidates
	if pool.is_empty():
		pool = Global.get_team_members(team)
	var best := 0
	var best_score := -1
	for slot in pool:
		var i := int(slot)
		if i < 1 or i > Global.MAX_PLAYERS:
			continue
		if Global.player_scores[i - 1] > best_score:
			best_score = Global.player_scores[i - 1]
			best = i
	return best

func _on_round_ended(winner_index: int) -> void:
	_cancel_round_countdown()
	camera.cancel_round_intro()
	if is_network_client:
		return
	# Letzten Spielstand (inkl. Tod) an alle Clients schicken, bevor pausiert wird.
	if is_network_host and NetworkManager.has_clients():
		_send_snapshot()
	# Alle Verlierer draften nacheinander öffentlich. In Team-Modi erhält das
	# gesamte Verliererteam Karten, nicht nur einzelne Spieler.
	var losers: Array[int] = []
	var winner_team := Global.get_team_for_slot(winner_index)
	for i in Global.get_active_player_indices():
		if Global.get_team_for_slot(i) != winner_team:
			losers.append(i)

	# Modifier-Boni (z.B. Beute-Münzen & Piñata): Beste Sammler/Klopfer erhalten Extrakarte!
	if modifier_manager != null:
		var bonus_slots: Array[int] = modifier_manager.get_bonus_card_drafters()
		for b_slot in bonus_slots:
			losers.append(b_slot)

	card_draft_ui.start_draft_sequence(losers)

func _on_match_over(winner_index: int) -> void:
	_cancel_round_countdown()
	if is_network_host and NetworkManager.has_clients():
		_send_snapshot()
		NetworkManager.send_match_over(winner_index, Global.get_scores(), Global.get_match_stats())
	_record_card_statistics(winner_index)

func _record_card_statistics(winner_index: int) -> void:
	if card_stats_match_recorded:
		return
	card_stats_match_recorded = true
	# Clients haben keine lokalen Todesereignisse; der Host liefert die
	# autoritativen Kill-Zähler mit dem Match-Ende.
	if is_network_client:
		CardStats.record_kill_totals(Global.get_match_stats())
	CardStats.record_match(winner_index)

# --- Spezial-Tiles: Host ist autoritativ, Client übernimmt per RPC ---

func _on_level_tile_broken(tile_id: int) -> void:
	if is_network_host and NetworkManager.has_clients():
		NetworkManager.send_tile_broken(tile_id)

func _on_level_tile_regrown(tile_id: int) -> void:
	if is_network_host and NetworkManager.has_clients():
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
	# Nächste Runde mit frischem Level starten.
	_start_fresh_round()

# ============================================================
# Online-Multiplayer
# ============================================================

func _build_network_config() -> Dictionary:
	return {
		"points_to_win": Global.points_to_win,
		"survival_points": Global.survival_points,
		"kill_points": Global.kill_points,
		"draft_picks": Global.draft_picks,
		"cards_per_draft": Global.cards_per_draft,
		"blind_pick_enabled": Global.blind_pick_enabled,
		"random_pick_enabled": Global.random_pick_enabled,
		"bans": Global.banned_card_ids.duplicate(),
		"player_count": Global.player_count,
		"heroes": Global.player_hero_ids.duplicate(),
		"kinds": Global.player_kind.duplicate(),
		"base_hp_percent": Global.base_hp_percent,
		"base_damage": Global.base_damage,
		"rarity_percentages": Global.rarity_percentages.duplicate(),
		"card_pools": Global.enabled_card_pools.duplicate(),
		"map_id": Global.selected_map_id,
		"match_mode": Global.match_mode,
	}

func _apply_network_config(config: Dictionary) -> void:
	Global.set_player_count(int(config.get("player_count", Global.player_count)))
	Global.set_match_mode(str(config.get("match_mode", Global.MATCH_MODE_FFA)))
	var heroes: Array = config.get("heroes", [])
	for i in range(mini(heroes.size(), Global.MAX_PLAYERS)):
		Global.player_hero_ids[i] = str(heroes[i])
	var kinds: Array = config.get("kinds", [])
	for i in range(mini(kinds.size(), Global.MAX_PLAYERS)):
		Global.player_kind[i] = int(kinds[i])
	Global.set_scoring_config(
		int(config.get("points_to_win", Global.points_to_win)),
		int(config.get("survival_points", Global.survival_points)),
		int(config.get("kill_points", Global.kill_points))
	)
	Global.set_draft_config(
		int(config.get("draft_picks", Global.draft_picks)),
		int(config.get("cards_per_draft", Global.cards_per_draft))
	)
	Global.set_blind_pick_enabled(bool(config.get("blind_pick_enabled", Global.blind_pick_enabled)))
	Global.set_random_pick_enabled(bool(config.get("random_pick_enabled", Global.random_pick_enabled)))
	var rarity_data: Dictionary = config.get("rarity_percentages", {})
	for rarity in Global.RARITY_ORDER:
		if rarity_data.has(rarity):
			Global.set_rarity_percent(rarity, float(rarity_data[rarity]))
	if config.has("card_pools"):
		Global.set_enabled_card_pools(config.get("card_pools", []))
	if config.has("map_id"):
		Global.set_selected_map(str(config.get("map_id", Global.MAP_RANDOM)))
	Global.banned_card_ids.clear()
	for card_id in config.get("bans", []):
		Global.banned_card_ids.append(str(card_id))
	Global.banned_cards_changed.emit()
	Global.set_base_hp_percent(int(config.get("base_hp_percent", Global.base_hp_percent)))
	Global.set_base_damage(float(config.get("base_damage", Global.base_damage)))
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
	Global.is_spectator = false
	Global.set_local_player(1)
	lobby.open_lobby()

func _on_menu_join_requested(address: String, port: int, as_spectator: bool) -> void:
	var err := NetworkManager.join_game(address, port, as_spectator)
	if err != OK:
		main_menu.set_network_status("Verbindung konnte nicht gestartet werden.", true)

func _on_menu_network_cancel() -> void:
	NetworkManager.disconnect_peer()
	is_network_host = false
	is_network_client = false
	Global.network_mode = false
	Global.remote_connected = false
	Global.is_spectator = false
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
	Global.is_spectator = false
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
	hud.reset_for_round()
	main_menu.open_menu(reason)

# --- Match-Start ---

func _on_network_match_start(config: Dictionary) -> void:
	if not is_network_client:
		return
	_apply_network_config(config)

func _on_network_round_start(level_seed: int, map_id: String, points_to_win: int = 0) -> void:
	if not is_network_client:
		return
	if points_to_win > 0:
		Global.set_match_target(points_to_win)
	lobby.close_lobby()
	main_menu.close_menu()
	_start_fresh_round(level_seed, map_id)

# --- Laufendes Spiel: Eingaben & Snapshots ---

func _process_network_client(delta: float) -> void:
	if Global.is_spectator:
		return
	if Global.current_state != Global.GameState.PLAYING:
		return
	if countdown_active:
		pending_jump = false
		pending_jump_release = false
		pending_dash = false
		pending_ability = false
		pending_block = false
		pending_reload = false
		return

	if local_shoot_sound_timer > 0.0:
		local_shoot_sound_timer -= delta

	var local := get_player(Global.local_player_index)

	if Input.is_action_just_pressed("p1_jump"):
		pending_jump = true
		SoundManager.play_sound("click", 0.25, -4.0)
	if Input.is_action_just_released("p1_jump"):
		pending_jump_release = true
	if Input.is_action_just_pressed("p1_dash"):
		pending_dash = true
	if Input.is_action_just_pressed("p1_block"):
		pending_block = true
	if Input.is_action_just_pressed("p1_reload"):
		pending_reload = true
	if Input.is_action_just_pressed("p1_ability") \
			or Input.is_action_just_pressed("p1_ability_alt") \
			or Input.is_action_just_pressed("p1_ability_f"):
		pending_ability = true
	if Input.is_action_pressed("p1_shoot") and local_shoot_sound_timer <= 0.0:
		if _can_local_shoot(local):
			SoundManager.play_sound("shoot", 0.15, 0.0)
			var sound_interval := maxf(0.08, local.fire_rate_cooldown)
			if local.powerup_rapid_fire_timer > 0.0:
				sound_interval = minf(sound_interval, 0.09)
			local_shoot_sound_timer = sound_interval

	net_input_timer += delta
	if net_input_timer < INPUT_INTERVAL:
		return
	net_input_timer = 0.0

	# Zielrichtung aus der Maus (Weltkoordinate) für den eigenen Slot.
	var aim := Vector2.RIGHT
	if local and is_instance_valid(local):
		var cam := get_viewport().get_camera_2d()
		if cam:
			aim = (cam.get_global_mouse_position() - local.global_position).normalized()

	NetworkManager.send_input({
		"move_x": Input.get_axis("p1_left", "p1_right"),
		"aim": aim,
		"shoot": Input.is_action_pressed("p1_shoot"),
		"jump": pending_jump,
		"jump_release": pending_jump_release,
		"dash": pending_dash,
		"ability": pending_ability,
		"block": pending_block,
		"reload": pending_reload,
	})
	pending_jump = false
	pending_jump_release = false
	pending_dash = false
	pending_ability = false
	pending_block = false
	pending_reload = false

# Verhindert Schussgeräusche, während der lokale Spieler nachlädt oder kein
# Magazin mehr hat.
func _can_local_shoot(local: Player) -> bool:
	if local == null or not is_instance_valid(local):
		return false
	return local.visible and local.current_health > 0.0 \
		and local.control_enabled and local.current_ammo > 0 \
		and not local.is_reloading

func _on_network_input(slot: int, data: Dictionary) -> void:
	if not is_network_host or Global.current_state != Global.GameState.PLAYING:
		return
	if countdown_active:
		return
	var p := get_player(slot)
	if p and is_instance_valid(p) and p.is_remote and p.control_enabled:
		p.set_remote_input(data)

func _send_snapshot() -> void:
	if not is_network_host or not NetworkManager.has_clients():
		return
	var snap_list: Array = []
	for i in range(Global.MAX_PLAYERS):
		snap_list.append({})
	for p in players:
		if is_instance_valid(p):
			snap_list[p.player_index - 1] = _player_snapshot(p)
	NetworkManager.send_snapshot({
		"players": snap_list,
		"bullets": _bullet_snapshots(),
		"towers": _tower_snapshots(),
		"map_objects": level_generator.get_moving_object_snapshots(),
		"scores": Global.get_scores(),
		"sudden": is_sudden_death,
		"lava": lava_y_pos,
	})

func _player_snapshot(player: Player) -> Dictionary:
	if not player or not is_instance_valid(player) or not player.visible:
		return {}
	if player.current_health <= 0.0:
		return {}
	var pig_colors := player.get_pig_colors()
	if pig_colors.is_empty():
		pig_colors = Global.get_pig_appearance(player.player_index)
	return {
		"pos": player.global_position,
		"vel": player.velocity,
		"fur": pig_colors["fur"],
		"eyes": pig_colors["eyes"],
		"pants": pig_colors["pants"],
		"wand_shape": str(pig_colors.get("wand_tip_shape", "orb")),
		"wand_tip": pig_colors.get("wand_tip_color", Color.WHITE),
		"shot": pig_colors.get("shot_color", Color.WHITE),
		"hp": player.current_health,
		"max_hp": player.max_health,
		"armor": player.armor_percent,
		"reflect": player.damage_reflect_percent,
		"poison": player.poison_ticks_left,
		"shield": player.current_shield,
		"max_shield": player.max_shield,
		"ammo": player.current_ammo,
		"max_ammo": player.max_ammo,
		"aim": player.aim_direction,
		"ability": player.ability_timer,
		"ability_max": player.ability_max_cooldown,
		"reload": player.is_reloading,
		"reload_timer": player.reload_timer,
		"reload_time": player.reload_time,
		"dash_cd": player.dash_cooldown_timer,
		"dash_cd_max": player.dash_cooldown,
		"blocking": player.is_blocking,
		"block_cd": player.block_cooldown_timer,
		"block_cd_max": player.block_cooldown,
		"powerup_invuln": player.powerup_invuln_timer,
		"powerup_damage": player.powerup_damage_timer,
		"powerup_damage_mult": player.powerup_damage_mult,
		"powerup_rapid": player.powerup_rapid_fire_timer,
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
			"hp": t.current_health,
			"max_hp": t.max_health,
			"aim": t.aim_angle,
		})
	return result

func _on_network_snapshot(data: Dictionary) -> void:
	if not is_network_client:
		return
	var snap_list: Array = data.get("players", [])
	for i in range(snap_list.size()):
		_apply_player_snapshot(i + 1, snap_list[i])
	_sync_remote_bullets(data.get("bullets", []))
	_sync_remote_towers(data.get("towers", []))
	level_generator.apply_moving_object_snapshots(data.get("map_objects", []))

	var scores = data.get("scores", [])
	if scores is Array:
		Global.set_network_scores(scores)

	var sudden := bool(data.get("sudden", false))
	if sudden != is_sudden_death:
		is_sudden_death = sudden
		hud.set_sudden_death(sudden)
	lava_y_pos = float(data.get("lava", lava_y_pos))
	_update_lava_overlay()

func _apply_player_snapshot(index: int, data: Dictionary) -> void:
	var player := get_player(index)
	if not player or not is_instance_valid(player):
		return
	if data.is_empty():
		if bool(network_alive_slots.get(index, false)):
			SoundManager.play_sound("death", 0.08, -1.0)
		network_alive_slots[index] = false
		player.visible = false
		camera.remove_target(player)
		return
	network_alive_slots[index] = true
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
			tower.owner_player = get_player(owner_index)
			add_child(tower)
			remote_towers[tower_id] = tower
		tower.apply_network_state(
			entry.get("pos", tower.global_position),
			float(entry.get("hp", -1.0)),
			float(entry.get("max_hp", -1.0)),
			float(entry.get("aim", 0.0))
		)

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

# Entfernt alle Effekte der vorherigen Runde: Projektile, Türme, Flächeneffekte
# und die kurzen visuellen Effekte (Explosionen, Blitze, Schockwellen usw.).
# Drones hängen an den Spielern und werden mit diesen neu erzeugt.
func _clear_round_effects() -> void:
	for bullet in get_tree().get_nodes_in_group("bullet"):
		if is_instance_valid(bullet):
			bullet.queue_free()
	for tower in get_tree().get_nodes_in_group("tower"):
		if is_instance_valid(tower):
			tower.queue_free()
	for zone in get_tree().get_nodes_in_group("effect_zone"):
		if is_instance_valid(zone):
			zone.queue_free()
	for effect in get_tree().get_nodes_in_group("round_effect"):
		if is_instance_valid(effect):
			effect.queue_free()
	remote_bullets.clear()
	remote_towers.clear()
	if modifier_manager != null:
		modifier_manager.clear_round()

func _on_network_zone_spawn(data: Dictionary) -> void:
	if not is_network_client:
		return
	var owner_index := int(data.get("owner_index", 1))
	var owner := get_player(owner_index)
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

func _on_network_draft_pick_requested(slot: int, card_id: String) -> void:
	if not is_network_host or not card_draft_ui.visible:
		return
	# Random pick wird ausschließlich vom Host gezogen; Client-Wahlen werden ignoriert.
	if Global.random_pick_enabled:
		return
	# Nur der Slot, der gerade am Zug ist, darf wählen.
	if card_draft_ui.current_drafter != slot:
		return
	card_draft_ui.apply_network_pick(card_id)

func _on_network_match_over(winner_index: int, scores: Array, stats: Array) -> void:
	if not is_network_client:
		return
	Global.set_network_scores(scores)
	Global.set_network_match_over(winner_index, stats)

func _clear_players() -> void:
	for p in players:
		if is_instance_valid(p):
			p.queue_free()
	players.clear()
	camera.targets.clear()
	camera.cancel_round_intro()

# --- "Nochmal" / Zurück ins Menü ohne Szenenwechsel ---

func _on_hud_continue_requested() -> void:
	# Nur der Host entscheidet über die Verlängerung. Im lokalen Spiel ist der
	# lokale Spieler automatisch Host.
	if Global.network_mode and not is_network_host:
		return
	if Global.current_state != Global.GameState.GAME_OVER:
		return
	# Ziel um rund 30 % erhöhen. Punkte, Decks und Match-Statistik bleiben
	# erhalten; die nächste Runde startet direkt ohne neuen Draft.
	Global.advance_match_target(0.30)
	_start_fresh_round()

func _on_hud_restart_requested() -> void:
	if Global.network_mode or NetworkManager.is_network_active():
		_abort_network_match("")
		return
	# In-Place-Neustart: kein reload_current_scene(), sondern sauberes Aufräumen.
	Global.reset_match()
	Global.current_state = Global.GameState.MENU
	get_tree().paused = false
	lobby.close_lobby()
	card_draft_ui.close_draft()
	_cancel_round_countdown()
	_clear_players()
	_clear_remote_bullets()
	_clear_remote_towers()
	_clear_round_effects()
	hud.reset_for_round()
	main_menu.open_menu()
