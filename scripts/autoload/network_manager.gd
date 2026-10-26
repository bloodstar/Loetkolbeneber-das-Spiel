extends Node

# Zentraler Netzwerk-Manager für 2-6 Spieler.
# Der Host rechnet das Match autoritativ und verteilt die Slots 2..6 an Clients.
# Jeder Slot kann in der Lobby als Mensch (Client) oder Bot konfiguriert werden.
# Die Verbindung läuft direkt über ENet (UDP). Für Internet-Partien versucht der
# Host zusätzlich, den Port per UPnP im Router freizugeben.

signal hosting_started(port: int)
signal host_failed(reason: String)
signal join_started()
signal join_succeeded()
signal join_failed(reason: String)
signal peer_joined()
signal peer_left()
signal server_closed()
signal slot_assigned(slot: int)
signal ping_updated()

signal lobby_sync_received(data: Dictionary)
signal match_start_received(config: Dictionary)
signal round_start_received(seed: int, map_id: String, points_to_win: int)
signal snapshot_received(data: Dictionary)
signal input_received(slot: int, data: Dictionary)
signal draft_start_received(drafter: int, card_ids: Array, picks_total: int)
signal draft_pick_received(card_id: String)
signal draft_pick_requested(slot: int, card_id: String)
signal draft_finished_received()
signal match_over_received(winner_index: int, scores: Array, stats: Array)
signal tile_broken_received(tile_id: int)
signal tile_regrown_received(tile_id: int)
signal zone_spawn_received(data: Dictionary)

const DEFAULT_PORT: int = 7777
# Ein Host + bis zu fünf Spieler-Clients = 6 Spieler. Zusätzlich sind bis zu
# vier Zuschauer erlaubt; sie belegen keinen Spieler-Slot.
const MAX_PLAYER_CLIENTS: int = 5
const MAX_SPECTATOR_CLIENTS: int = 4
const MAX_CLIENTS: int = MAX_PLAYER_CLIENTS + MAX_SPECTATOR_CLIENTS
const PING_INTERVAL: float = 1.0

var is_host: bool = false
var is_client: bool = false
var is_spectator: bool = false
var join_as_spectator: bool = false
var host_port: int = DEFAULT_PORT
var network_info: String = ""

# Peer-ID <-> Slot-Zuordnung (nur auf dem Host befüllt).
var peer_slots: Dictionary = {}
var slot_peers: Dictionary = {}
# Zuschauer belegen keinen Slot und werden getrennt von den Spielern geführt.
var spectator_peers: Dictionary = {}
var peer_pings: Dictionary = {}
var ping_ms: int = -1

var _upnp_thread: Thread = null
var _ping_timer: float = 0.0
var _join_confirmed: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	Global.lobby_state_changed.connect(_on_global_lobby_changed)
	Global.banned_cards_changed.connect(_on_global_lobby_changed)
	Global.draft_config_changed.connect(_on_global_draft_changed)
	Global.draft_modifiers_changed.connect(_on_global_draft_modifiers_changed)
	Global.level_modifiers_changed.connect(_on_global_lobby_changed)
	Global.scoring_config_changed.connect(_on_global_scoring_changed)
	Global.bot_mode_toggled.connect(_on_global_bot_changed)
	Global.base_hp_percent_changed.connect(_on_global_base_hp_percent_changed)
	Global.base_damage_changed.connect(_on_global_base_damage_changed)
	Global.rarity_percentages_changed.connect(_on_global_rarity_changed)
	Global.card_pools_changed.connect(_on_global_card_pools_changed)
	Global.map_changed.connect(_on_global_map_changed)
	Global.match_mode_changed.connect(_on_global_match_mode_changed)
	Global.player_count_changed.connect(_on_global_player_count_changed)

func _exit_tree() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	disconnect_peer()

func _process(delta: float) -> void:
	if not is_network_active():
		return
	_ping_timer += delta
	if _ping_timer < PING_INTERVAL:
		return
	_ping_timer = 0.0
	_send_ping_probes()

func is_network_active() -> bool:
	return is_host or is_client

func has_clients() -> bool:
	return is_host and (not peer_slots.is_empty() or not spectator_peers.is_empty())

# Abwärtskompatibler Name (wird an einigen Stellen noch verwendet).
func has_client() -> bool:
	return has_clients()

func has_client_slot(slot: int) -> bool:
	return slot_peers.has(slot)

func get_spectator_count() -> int:
	return spectator_peers.size()

func get_peer_for_slot(slot: int) -> int:
	return int(slot_peers.get(slot, 0))

func get_slot_for_peer(peer_id: int) -> int:
	return int(peer_slots.get(peer_id, 0))

# Alle verbundenen Gegenstellen, inklusive Zuschauer. Wird für Lobby-Sync und
# alle Match-Broadcasts verwendet, damit Zuschauer dieselben Snapshots erhalten.
func _broadcast_targets() -> Array[int]:
	var targets: Array[int] = []
	for peer_id in peer_slots.keys():
		targets.append(int(peer_id))
	for peer_id in spectator_peers.keys():
		var id := int(peer_id)
		if not targets.has(id):
			targets.append(id)
	return targets

# --- Ping ---

func _send_ping_probes() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var now := Time.get_ticks_msec()
	if is_host:
		for peer_id in _broadcast_targets():
			_ping_probe.rpc_id(peer_id, now)
	elif is_client:
		_ping_probe.rpc_id(1, now)

@rpc("any_peer", "call_remote", "unreliable")
func _ping_probe(sent_ms: int) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	if is_host:
		_ping_reply.rpc_id(sender, sent_ms, false)
	else:
		_ping_reply.rpc_id(1, sent_ms, true)

@rpc("any_peer", "call_remote", "unreliable")
func _ping_reply(sent_ms: int, for_host: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 0:
		return
	var rtt := maxi(0, Time.get_ticks_msec() - sent_ms)
	if is_host and for_host:
		peer_pings[sender] = rtt
		ping_updated.emit()
	elif is_client and not for_host:
		ping_ms = rtt
		ping_updated.emit()

func _format_ping(value: int) -> String:
	return "%d ms" % value if value >= 0 else "…"

func get_ping_text() -> String:
	if is_client:
		return "PING %s" % _format_ping(ping_ms)
	if is_host:
		var parts: Array[String] = []
		for slot in range(2, Global.player_count + 1):
			if not slot_peers.has(slot):
				continue
			var peer_id := get_peer_for_slot(slot)
			parts.append("P%d %s" % [slot, _format_ping(int(peer_pings.get(peer_id, -1)))])
		var spectator_index := 1
		for peer_id in spectator_peers.keys():
			parts.append("Z%d %s" % [spectator_index, _format_ping(int(peer_pings.get(int(peer_id), -1)))])
			spectator_index += 1
		if parts.is_empty():
			return "PING —"
		return "PING " + " · ".join(parts)
	return ""

func get_ping_summary() -> String:
	var worst := _worst_ping()
	if worst < 0:
		return "PING —"
	if is_host:
		return "PING max %d ms" % worst
	return "PING %d ms" % worst

func get_ping_color() -> Color:
	var value := _worst_ping()
	if value < 0:
		return Color(0.55, 0.6, 0.7, 1.0)
	if value <= 60:
		return Color(0.45, 0.9, 0.55, 1.0)
	if value <= 120:
		return Color(1.0, 0.82, 0.35, 1.0)
	return Color(1.0, 0.45, 0.4, 1.0)

func _worst_ping() -> int:
	if is_client:
		return ping_ms
	if is_host:
		var worst := -1
		for peer_id in _broadcast_targets():
			worst = maxi(worst, int(peer_pings.get(peer_id, -1)))
		return worst
	return -1

# Trennt den Client, der aktuell einen Slot belegt (z. B. wenn der Host den Slot
# von Mensch auf Bot umstellt oder die Spielerzahl reduziert).
func kick_slot(slot: int) -> void:
	if not is_host:
		return
	var peer_id := get_peer_for_slot(slot)
	if peer_id == 0:
		return
	peer_slots.erase(peer_id)
	slot_peers.erase(slot)
	peer_pings.erase(peer_id)
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	Global.set_player_ready(slot, false)
	Global.remote_connected = has_clients()
	ping_updated.emit()
	sync_lobby()

# Menschliche Slots ohne verbundenen Client (nur auf dem Host sinnvoll).
func missing_human_slots() -> Array[int]:
	var missing: Array[int] = []
	if not is_host:
		return missing
	for i in range(2, Global.player_count + 1):
		if Global.is_human_slot(i) and not slot_peers.has(i):
			missing.append(i)
	return missing

# --- Verbindung aufbauen ---

func host_game(port: int = DEFAULT_PORT) -> Error:
	disconnect_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		var reason := "Port %d ist belegt oder ungültig." % port
		host_failed.emit(reason)
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_client = false
	is_spectator = false
	join_as_spectator = false
	host_port = port
	Global.network_mode = true
	Global.remote_connected = false
	Global.is_spectator = false
	Global.set_local_player(1)
	_set_info("Host auf Port %d – warte auf Mitspieler..." % port)
	hosting_started.emit(port)
	_start_upnp(port)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT, as_spectator: bool = false) -> Error:
	disconnect_peer()
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		var reason := "Bitte die IP-Adresse des Hosts eingeben."
		join_failed.emit(reason)
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(clean_address, port)
	if err != OK:
		var reason := "Verbindung zu %s:%d fehlgeschlagen." % [clean_address, port]
		join_failed.emit(reason)
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = false
	is_spectator = false
	join_as_spectator = as_spectator
	_join_confirmed = false
	host_port = port
	Global.network_mode = true
	Global.is_spectator = false
	_set_info("Verbinde zu %s:%d ..." % [clean_address, port])
	join_started.emit()
	return OK

func disconnect_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	is_client = false
	is_spectator = false
	join_as_spectator = false
	_join_confirmed = false
	peer_slots.clear()
	slot_peers.clear()
	spectator_peers.clear()
	peer_pings.clear()
	ping_ms = -1
	_ping_timer = 0.0
	Global.network_mode = false
	Global.remote_connected = false
	Global.is_spectator = false
	_set_info("")
	ping_updated.emit()

# --- Peer-Ereignisse ---

# Sucht einen Slot für einen neu verbundenen Client: zuerst einen freien
# Mensch-Slot, sonst übernimmt der Client den niedrigsten freien Bot-Slot.
# Die Slot-Art wird erst bei der tatsächlichen Zuweisung geändert.
func _find_joinable_slot() -> int:
	for i in range(2, Global.player_count + 1):
		if Global.is_human_slot(i) and not slot_peers.has(i):
			return i
	for i in range(2, Global.player_count + 1):
		if Global.is_bot_slot(i) and not slot_peers.has(i):
			return i
	return 0

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	_set_info("Client verbunden – warte auf Beitrittsanfrage...")
	# Falls ein Peer nie eine Beitrittsanfrage schickt, Verbindung aufräumen.
	get_tree().create_timer(5.0).timeout.connect(func():
		if is_host and not peer_slots.has(peer_id) and not spectator_peers.has(peer_id):
			if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id):
				multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	)

# Wird vom Client direkt nach dem Verbindungsaufbau aufgerufen. Erst danach
# entscheidet der Host, ob ein Spieler-Slot vergeben oder Zuschauer akzeptiert
# wird. So kann ein voller Spieler-Slot nicht versehentlich belegt werden.
@rpc("any_peer", "call_remote", "reliable")
func request_join(as_spectator: bool) -> void:
	if not is_host:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return
	if peer_slots.has(peer_id) or spectator_peers.has(peer_id):
		return
	if Global.current_state != Global.GameState.LOBBY and Global.current_state != Global.GameState.MENU:
		_deny_join(peer_id, "Das Match läuft bereits. Beitritt ist nur in der Lobby möglich.")
		return
	if as_spectator:
		if spectator_peers.size() >= MAX_SPECTATOR_CLIENTS:
			_deny_join(peer_id, "Alle Zuschauerplätze sind belegt.")
			return
		_add_spectator(peer_id)
		return
	var slot := _find_joinable_slot()
	if slot == 0:
		_deny_join(peer_id, "Kein freier Spieler-Slot. Bitte als Zuschauer beitreten.")
		return
	_assign_peer_to_slot(peer_id, slot)

func _assign_peer_to_slot(peer_id: int, slot: int) -> void:
	peer_slots[peer_id] = slot
	slot_peers[slot] = peer_id
	Global.set_player_kind(slot, Global.PlayerKind.HUMAN)
	Global.set_player_ready(slot, false)
	Global.remote_connected = true
	_set_info("Mitspieler verbunden (Slot %d)." % slot)
	receive_slot_assignment.rpc_id(peer_id, slot)
	peer_joined.emit()
	_send_ping_probe_to(peer_id)
	sync_lobby()

func _add_spectator(peer_id: int) -> void:
	spectator_peers[peer_id] = true
	Global.remote_connected = true
	_set_info("Zuschauer verbunden (%d)." % spectator_peers.size())
	receive_spectator_assignment.rpc_id(peer_id)
	_send_ping_probe_to(peer_id)
	sync_lobby()

func _deny_join(peer_id: int, reason: String) -> void:
	receive_join_denied.rpc_id(peer_id, reason)
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if is_host and multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(peer_id):
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
	)

func _send_ping_probe_to(peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null:
		_ping_probe.rpc_id(peer_id, Time.get_ticks_msec())

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host:
		return
	if peer_slots.has(peer_id):
		var slot: int = int(peer_slots[peer_id])
		peer_slots.erase(peer_id)
		slot_peers.erase(slot)
		peer_pings.erase(peer_id)
		Global.set_player_ready(slot, false)
		Global.remote_connected = has_clients()
		_set_info("Mitspieler getrennt (Slot %d)." % slot)
		peer_left.emit()
		ping_updated.emit()
		sync_lobby()
		return
	if spectator_peers.has(peer_id):
		spectator_peers.erase(peer_id)
		peer_pings.erase(peer_id)
		Global.remote_connected = has_clients()
		_set_info("Zuschauer getrennt.")
		ping_updated.emit()
		sync_lobby()

func _on_connected_to_server() -> void:
	is_host = false
	is_client = true
	is_spectator = false
	_join_confirmed = false
	Global.network_mode = true
	Global.remote_connected = true
	Global.is_spectator = false
	_set_info("Verbunden mit dem Host.")
	# Slot bzw. Zuschauer-Status kommt vom Host als Antwort auf diese Anfrage.
	request_join.rpc_id(1, join_as_spectator)
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_client and not _join_confirmed:
			join_failed.emit("Der Host hat den Beitritt nicht bestätigt.")
			disconnect_peer()
	)

func _on_connection_failed() -> void:
	is_host = false
	is_client = false
	is_spectator = false
	join_as_spectator = false
	_join_confirmed = false
	peer_slots.clear()
	slot_peers.clear()
	spectator_peers.clear()
	peer_pings.clear()
	ping_ms = -1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	Global.network_mode = false
	Global.remote_connected = false
	Global.is_spectator = false
	_set_info("")
	join_failed.emit("Verbindung fehlgeschlagen. IP, Port und Firewall prüfen.")

func _on_server_disconnected() -> void:
	is_host = false
	is_client = false
	is_spectator = false
	join_as_spectator = false
	_join_confirmed = false
	peer_slots.clear()
	slot_peers.clear()
	spectator_peers.clear()
	peer_pings.clear()
	ping_ms = -1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	Global.network_mode = false
	Global.remote_connected = false
	Global.is_spectator = false
	_set_info("Verbindung zum Host verloren.")
	server_closed.emit()

# --- Slot-Zuweisung ---

@rpc("authority", "call_remote", "reliable")
func receive_slot_assignment(slot: int) -> void:
	if _join_confirmed:
		return
	_join_confirmed = true
	is_spectator = false
	Global.is_spectator = false
	Global.set_local_player(slot)
	# Gespeichertes Nutzerprofil auf den tatsächlich zugewiesenen Slot anwenden.
	Global.apply_saved_character_customization(slot)
	slot_assigned.emit(slot)
	join_succeeded.emit()
	sync_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_spectator_assignment() -> void:
	if _join_confirmed:
		return
	_join_confirmed = true
	is_spectator = true
	Global.is_spectator = true
	Global.set_local_player(0)
	slot_assigned.emit(0)
	join_succeeded.emit()
	sync_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_join_denied(reason: String) -> void:
	if not is_client:
		return
	join_failed.emit(reason)
	disconnect_peer()

# --- Lobby-Synchronisation ---

func build_lobby_sync() -> Dictionary:
	return {
		"player_count": Global.player_count,
		"heroes": Global.player_hero_ids.duplicate(),
		"kinds": Global.player_kind.duplicate(),
		"ready": Global.player_ready.duplicate(),
		"points_to_win": Global.points_to_win,
		"survival_points": Global.survival_points,
		"kill_points": Global.kill_points,
		"draft_picks": Global.draft_picks,
		"cards_per_draft": Global.cards_per_draft,
		"blind_pick_enabled": Global.blind_pick_enabled,
		"random_pick_enabled": Global.random_pick_enabled,
		"level_modifier_rate_percent": Global.level_modifier_rate_percent,
		"enabled_level_modifiers": Global.get_enabled_level_modifiers(),
		"bans": Global.banned_card_ids.duplicate(),
		"base_hp_percent": Global.base_hp_percent,
		"base_damage": Global.base_damage,
		"rarity_percentages": Global.rarity_percentages.duplicate(),
		"card_pools": Global.enabled_card_pools.duplicate(),
		"map_id": Global.selected_map_id,
		"match_mode": Global.match_mode,
	}

func sync_lobby() -> void:
	if not is_host:
		return
	var data := build_lobby_sync()
	for peer_id in _broadcast_targets():
		receive_lobby_sync.rpc_id(int(peer_id), data)

func _on_global_lobby_changed() -> void:
	sync_lobby()

func _on_global_draft_changed(_picks: int, _offered: int) -> void:
	sync_lobby()

func _on_global_draft_modifiers_changed() -> void:
	sync_lobby()

func _on_global_scoring_changed() -> void:
	sync_lobby()

func _on_global_bot_changed(_enabled: bool) -> void:
	sync_lobby()

func _on_global_base_hp_percent_changed(_percent: int) -> void:
	sync_lobby()

func _on_global_base_damage_changed(_damage: float) -> void:
	sync_lobby()

func _on_global_rarity_changed() -> void:
	sync_lobby()

func _on_global_card_pools_changed() -> void:
	sync_lobby()

func _on_global_map_changed() -> void:
	sync_lobby()

func _on_global_match_mode_changed(_mode: String) -> void:
	sync_lobby()

func _on_global_player_count_changed(_count: int) -> void:
	sync_lobby()

@rpc("any_peer", "call_remote", "reliable")
func register_client() -> void:
	if not is_host:
		return
	sync_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_lobby_sync(data: Dictionary) -> void:
	if is_host:
		return
	_apply_lobby_sync(data)
	lobby_sync_received.emit(data)

func _apply_lobby_sync(data: Dictionary) -> void:
	Global.set_player_count(int(data.get("player_count", Global.player_count)))
	Global.set_match_mode(str(data.get("match_mode", Global.MATCH_MODE_FFA)))
	var heroes: Array = data.get("heroes", [])
	for i in range(mini(heroes.size(), Global.MAX_PLAYERS)):
		Global.player_hero_ids[i] = str(heroes[i])
	var kinds: Array = data.get("kinds", [])
	for i in range(mini(kinds.size(), Global.MAX_PLAYERS)):
		Global.player_kind[i] = int(kinds[i])
	var ready: Dictionary = data.get("ready", {})
	for key in ready.keys():
		Global.player_ready[int(key)] = bool(ready[key])
	Global.set_scoring_config(
		int(data.get("points_to_win", Global.points_to_win)),
		int(data.get("survival_points", Global.survival_points)),
		int(data.get("kill_points", Global.kill_points))
	)
	Global.set_draft_config(
		int(data.get("draft_picks", Global.draft_picks)),
		int(data.get("cards_per_draft", Global.cards_per_draft))
	)
	Global.set_blind_pick_enabled(bool(data.get("blind_pick_enabled", Global.blind_pick_enabled)))
	Global.set_random_pick_enabled(bool(data.get("random_pick_enabled", Global.random_pick_enabled)))
	Global.set_level_modifier_rate_percent(
		int(data.get("level_modifier_rate_percent", Global.level_modifier_rate_percent))
	)
	var level_mods: Variant = data.get("enabled_level_modifiers", null)
	if level_mods is Array:
		Global.set_enabled_level_modifiers(level_mods)
	var rarity_data: Dictionary = data.get("rarity_percentages", {})
	for rarity in Global.RARITY_ORDER:
		if rarity_data.has(rarity):
			Global.set_rarity_percent(rarity, float(rarity_data[rarity]))
	if data.has("card_pools"):
		Global.set_enabled_card_pools(data.get("card_pools", []))
	if data.has("map_id"):
		Global.set_selected_map(str(data.get("map_id", Global.MAP_RANDOM)))
	Global.banned_card_ids.clear()
	for card_id in data.get("bans", []):
		Global.banned_card_ids.append(str(card_id))
	Global.banned_cards_changed.emit()
	Global.set_base_hp_percent(int(data.get("base_hp_percent", Global.base_hp_percent)))
	Global.set_base_damage(float(data.get("base_damage", Global.base_damage)))
	Global.lobby_state_changed.emit()

# Client meldet eigene Heldenwahl / Bereitschaft an den Host.
func request_hero(hero_id: String) -> void:
	if is_client:
		client_hero.rpc_id(1, hero_id)

@rpc("any_peer", "call_remote", "reliable")
func client_hero(hero_id: String) -> void:
	if not is_host:
		return
	var slot := get_slot_for_peer(multiplayer.get_remote_sender_id())
	if slot == 0 or not Global.heroes.has(hero_id):
		return
	Global.set_player_hero(slot, hero_id)
	Global.set_player_ready(slot, false)
	sync_lobby()

func send_ready_state(ready: bool) -> void:
	if is_client:
		client_ready.rpc_id(1, ready)

@rpc("any_peer", "call_remote", "reliable")
func client_ready(ready: bool) -> void:
	if not is_host:
		return
	var slot := get_slot_for_peer(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	Global.set_player_ready(slot, ready)
	sync_lobby()

# --- Match-Start / Runden ---

func send_start_match(config: Dictionary) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_start_match.rpc_id(int(peer_id), config)

@rpc("authority", "call_remote", "reliable")
func receive_start_match(config: Dictionary) -> void:
	match_start_received.emit(config)

func send_round_start(level_seed: int, map_id: String, points_to_win: int = 0) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_round_start.rpc_id(int(peer_id), level_seed, map_id, points_to_win)

@rpc("authority", "call_remote", "reliable")
func receive_round_start(level_seed: int, map_id: String, points_to_win: int = 0) -> void:
	round_start_received.emit(level_seed, map_id, points_to_win)

func send_snapshot(data: Dictionary) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_snapshot.rpc_id(int(peer_id), data)

@rpc("authority", "call_remote", "unreliable")
func receive_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)

func send_input(data: Dictionary) -> void:
	if is_client:
		receive_input.rpc_id(1, data)

@rpc("any_peer", "call_remote", "unreliable")
func receive_input(data: Dictionary) -> void:
	if not is_host:
		return
	var slot := get_slot_for_peer(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	input_received.emit(slot, data)

func send_match_over(winner_index: int, scores: Array, stats: Array = []) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_match_over.rpc_id(int(peer_id), winner_index, scores, stats)

@rpc("authority", "call_remote", "reliable")
func receive_match_over(winner_index: int, scores: Array, stats: Array) -> void:
	match_over_received.emit(winner_index, scores, stats)

# --- Spezial-Tiles (zerstörbar / Ranken) ---

func send_tile_broken(tile_id: int) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_tile_broken.rpc_id(int(peer_id), tile_id)

@rpc("authority", "call_remote", "reliable")
func receive_tile_broken(tile_id: int) -> void:
	tile_broken_received.emit(tile_id)

func send_tile_regrown(tile_id: int) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_tile_regrown.rpc_id(int(peer_id), tile_id)

@rpc("authority", "call_remote", "reliable")
func receive_tile_regrown(tile_id: int) -> void:
	tile_regrown_received.emit(tile_id)

# --- Talentbaum-Flächeneffekte (visuelle Replikation) ---

func send_zone_spawn(data: Dictionary) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_zone_spawn.rpc_id(int(peer_id), data)

@rpc("authority", "call_remote", "reliable")
func receive_zone_spawn(data: Dictionary) -> void:
	zone_spawn_received.emit(data)

# --- Draft-Synchronisation ---

func send_draft_start(drafter: int, card_ids: Array, picks_total: int) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_draft_start.rpc_id(int(peer_id), drafter, card_ids, picks_total)

@rpc("authority", "call_remote", "reliable")
func receive_draft_start(drafter: int, card_ids: Array, picks_total: int) -> void:
	draft_start_received.emit(drafter, card_ids, picks_total)

func request_draft_pick(card_id: String) -> void:
	if is_client:
		client_draft_pick.rpc_id(1, card_id)

@rpc("any_peer", "call_remote", "reliable")
func client_draft_pick(card_id: String) -> void:
	if not is_host:
		return
	var slot := get_slot_for_peer(multiplayer.get_remote_sender_id())
	if slot == 0:
		return
	draft_pick_requested.emit(slot, card_id)

func send_draft_pick(card_id: String) -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_draft_pick.rpc_id(int(peer_id), card_id)

@rpc("authority", "call_remote", "reliable")
func receive_draft_pick(card_id: String) -> void:
	draft_pick_received.emit(card_id)

func send_draft_finished() -> void:
	if not is_host:
		return
	for peer_id in _broadcast_targets():
		receive_draft_finished.rpc_id(int(peer_id))

@rpc("authority", "call_remote", "reliable")
func receive_draft_finished() -> void:
	draft_finished_received.emit()

# --- Charakteranpassung ---
# Clients dürfen nur den eigenen Slot anpassen. Der Host übernimmt Farben,
# Stabspitze und Schussfarbe und verteilt sie über die Spieler-Snapshots.
func request_pig_appearance(
		fur: Color,
		eyes: Color,
		pants: Color,
		wand_tip_shape: String,
		wand_tip_color: Color,
		shot_color: Color
	) -> void:
	if is_client:
		client_pig_appearance.rpc_id(
			1, fur, eyes, pants, wand_tip_shape, wand_tip_color, shot_color
		)

@rpc("any_peer", "call_remote", "reliable")
func client_pig_appearance(
		fur: Color,
		eyes: Color,
		pants: Color,
		wand_tip_shape: String,
		wand_tip_color: Color,
		shot_color: Color
	) -> void:
	if not is_host:
		return
	var slot := get_slot_for_peer(multiplayer.get_remote_sender_id())
	if slot <= 0:
		return
	Global.set_pig_appearance(
		slot, fur, eyes, pants, wand_tip_shape, wand_tip_color, shot_color
	)

# --- Netzwerk-Info / UPnP ---

func _set_info(text: String) -> void:
	network_info = text
	Global.set_network_info(text)

func get_lan_ip() -> String:
	for address in IP.get_local_addresses():
		if address.contains(":"):
			continue
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "127.0.0.1"

func _start_upnp(port: int) -> void:
	if _upnp_thread and _upnp_thread.is_started():
		return
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))

func _upnp_worker(port: int) -> void:
	var upnp := UPNP.new()
	var mapping_ok := false
	var external_ip := ""
	var err := upnp.discover()
	if err == OK:
		var gateway = upnp.get_gateway()
		if gateway and gateway.is_valid_gateway():
			if upnp.add_port_mapping(port, port, "Battle Balls", "UDP", 0) == OK:
				mapping_ok = true
				external_ip = upnp.get_external_ip()
	call_deferred("_on_upnp_done", mapping_ok, external_ip, port)

func _on_upnp_done(mapping_ok: bool, external_ip: String, port: int) -> void:
	if not is_host or port != host_port:
		# Der Host wurde inzwischen beendet oder neu auf einem anderen Port gestartet.
		return
	var lan_ip := get_lan_ip()
	if mapping_ok and not external_ip.is_empty():
		_set_info("Host bereit! Internet: %s:%d (UPnP aktiv)  •  LAN: %s:%d" % [external_ip, port, lan_ip, port])
	else:
		_set_info("Host bereit! LAN: %s:%d  •  Internet: UDP-Port %d im Router freigeben – oder ZeroTier/Tailscale nutzen." % [lan_ip, port, port])
