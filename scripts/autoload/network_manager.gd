extends Node

# Zentraler Netzwerk-Manager.
# Host = Spieler 1 und rechnet das Match. Client = Spieler 2 und sendet nur Eingaben.
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

signal lobby_sync_received(data: Dictionary)
signal match_start_received(config: Dictionary)
signal round_start_received(seed: int)
signal snapshot_received(data: Dictionary)
signal input_received(data: Dictionary)
signal draft_start_received(drafter: int, card_ids: Array, picks_total: int)
signal draft_pick_received(card_id: String)
signal draft_pick_requested(card_id: String)
signal draft_finished_received()
signal match_over_received(winner_index: int, p1_score: int, p2_score: int)
signal tile_broken_received(tile_id: int)
signal tile_regrown_received(tile_id: int)
signal zone_spawn_received(data: Dictionary)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 1
const SNAPSHOT_HZ: float = 25.0

var is_host: bool = false
var is_client: bool = false
var client_peer_id: int = 0
var host_port: int = DEFAULT_PORT
var network_info: String = ""

var _upnp_thread: Thread = null

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
	Global.score_to_win_changed.connect(_on_global_score_changed)
	Global.bot_mode_toggled.connect(_on_global_bot_changed)
	Global.base_hp_changed.connect(_on_global_base_hp_changed)

func _exit_tree() -> void:
	if _upnp_thread and _upnp_thread.is_started():
		_upnp_thread.wait_to_finish()
	disconnect_peer()

func is_network_active() -> bool:
	return is_host or is_client

func has_client() -> bool:
	return is_host and client_peer_id != 0

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
	host_port = port
	Global.network_mode = true
	Global.remote_connected = false
	Global.set_local_player(1)
	_set_info("Host auf Port %d – warte auf Mitspieler..." % port)
	hosting_started.emit(port)
	_start_upnp(port)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
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
	host_port = port
	_set_info("Verbinde zu %s:%d ..." % [clean_address, port])
	join_started.emit()
	return OK

func disconnect_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_host = false
	is_client = false
	client_peer_id = 0
	Global.network_mode = false
	Global.remote_connected = false
	_set_info("")

# --- Peer-Ereignisse ---

func _on_peer_connected(peer_id: int) -> void:
	if not is_host:
		return
	# Während eines laufenden Spiels keine neuen Spieler annehmen.
	if Global.current_state != Global.GameState.LOBBY and Global.current_state != Global.GameState.MENU:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	if client_peer_id != 0 and peer_id != client_peer_id:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	
	client_peer_id = peer_id
	Global.remote_connected = true
	Global.set_bot_enabled(false)
	Global.set_player_ready(2, false)
	Global.lobby_state_changed.emit()
	_set_info("Mitspieler verbunden. Bereit zum Start?")
	peer_joined.emit()
	sync_lobby()

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host or peer_id != client_peer_id:
		return
	client_peer_id = 0
	Global.remote_connected = false
	Global.set_player_ready(2, false)
	Global.lobby_state_changed.emit()
	_set_info("Mitspieler getrennt. Warte auf neuen Mitspieler...")
	peer_left.emit()

func _on_connected_to_server() -> void:
	is_host = false
	is_client = true
	Global.network_mode = true
	Global.remote_connected = true
	Global.set_local_player(2)
	Global.set_bot_enabled(false)
	_set_info("Verbunden mit dem Host.")
	join_succeeded.emit()
	register_client.rpc_id(1)

func _on_connection_failed() -> void:
	is_host = false
	is_client = false
	client_peer_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	Global.network_mode = false
	Global.remote_connected = false
	_set_info("")
	join_failed.emit("Verbindung fehlgeschlagen. IP, Port und Firewall prüfen.")

func _on_server_disconnected() -> void:
	is_host = false
	is_client = false
	client_peer_id = 0
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	Global.network_mode = false
	Global.remote_connected = false
	_set_info("Verbindung zum Host verloren.")
	server_closed.emit()

# --- Lobby-Synchronisation ---

func build_lobby_sync() -> Dictionary:
	return {
		"p1_hero": Global.p1_hero_id,
		"p2_hero": Global.p2_hero_id,
		"p1_ready": Global.is_player_ready(1),
		"p2_ready": Global.is_player_ready(2),
		"score_to_win": Global.score_to_win,
		"draft_picks": Global.draft_picks,
		"cards_per_draft": Global.cards_per_draft,
		"bans": Global.banned_card_ids.duplicate(),
		"bot": Global.is_bot_enabled,
		"base_hp": Global.base_hp_override,
	}

func sync_lobby() -> void:
	if is_host and client_peer_id != 0:
		receive_lobby_sync.rpc_id(client_peer_id, build_lobby_sync())

func _on_global_lobby_changed() -> void:
	sync_lobby()

func _on_global_draft_changed(_picks: int, _offered: int) -> void:
	sync_lobby()

func _on_global_score_changed(_wins: int) -> void:
	sync_lobby()

func _on_global_bot_changed(_enabled: bool) -> void:
	sync_lobby()

func _on_global_base_hp_changed(_hp: int) -> void:
	sync_lobby()

@rpc("any_peer", "call_remote", "reliable")
func register_client() -> void:
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	if client_peer_id == 0:
		client_peer_id = sender
		Global.remote_connected = true
	sync_lobby()

@rpc("authority", "call_remote", "reliable")
func receive_lobby_sync(data: Dictionary) -> void:
	if is_host:
		return
	_apply_lobby_sync(data)
	lobby_sync_received.emit(data)

func _apply_lobby_sync(data: Dictionary) -> void:
	Global.p1_hero_id = str(data.get("p1_hero", Global.p1_hero_id))
	Global.p2_hero_id = str(data.get("p2_hero", Global.p2_hero_id))
	Global.set_score_to_win(int(data.get("score_to_win", Global.score_to_win)))
	Global.set_draft_config(
		int(data.get("draft_picks", Global.draft_picks)),
		int(data.get("cards_per_draft", Global.cards_per_draft))
	)
	Global.banned_card_ids.clear()
	for card_id in data.get("bans", []):
		Global.banned_card_ids.append(str(card_id))
	Global.banned_cards_changed.emit()
	Global.set_base_hp_override(int(data.get("base_hp", Global.base_hp_override)))
	Global.set_bot_enabled(bool(data.get("bot", false)))
	Global.player_ready[1] = bool(data.get("p1_ready", false))
	Global.player_ready[2] = bool(data.get("p2_ready", false))
	Global.lobby_state_changed.emit()

# Client meldet eigene Heldenwahl / Bereitschaft an den Host.
func request_hero(hero_id: String) -> void:
	if is_client:
		client_hero.rpc_id(1, hero_id)

@rpc("any_peer", "call_remote", "reliable")
func client_hero(hero_id: String) -> void:
	if not is_host or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	if not Global.heroes.has(hero_id):
		return
	Global.p2_hero_id = hero_id
	Global.set_player_ready(2, false)
	sync_lobby()

func send_ready_state(ready: bool) -> void:
	if is_client:
		client_ready.rpc_id(1, ready)

@rpc("any_peer", "call_remote", "reliable")
func client_ready(ready: bool) -> void:
	if not is_host or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	Global.set_player_ready(2, ready)
	sync_lobby()

# --- Match-Start / Runden ---

func send_start_match(config: Dictionary) -> void:
	if is_host and client_peer_id != 0:
		receive_start_match.rpc_id(client_peer_id, config)

@rpc("authority", "call_remote", "reliable")
func receive_start_match(config: Dictionary) -> void:
	match_start_received.emit(config)

func send_round_start(level_seed: int) -> void:
	if is_host and client_peer_id != 0:
		receive_round_start.rpc_id(client_peer_id, level_seed)

@rpc("authority", "call_remote", "reliable")
func receive_round_start(level_seed: int) -> void:
	round_start_received.emit(level_seed)

func send_snapshot(data: Dictionary) -> void:
	if is_host and client_peer_id != 0:
		receive_snapshot.rpc_id(client_peer_id, data)

@rpc("authority", "call_remote", "unreliable")
func receive_snapshot(data: Dictionary) -> void:
	snapshot_received.emit(data)

func send_input(data: Dictionary) -> void:
	if is_client:
		receive_input.rpc_id(1, data)

@rpc("any_peer", "call_remote", "reliable")
func receive_input(data: Dictionary) -> void:
	if not is_host or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	input_received.emit(data)

func send_match_over(winner_index: int, p1_score: int, p2_score: int) -> void:
	if is_host and client_peer_id != 0:
		receive_match_over.rpc_id(client_peer_id, winner_index, p1_score, p2_score)

@rpc("authority", "call_remote", "reliable")
func receive_match_over(winner_index: int, p1_score: int, p2_score: int) -> void:
	match_over_received.emit(winner_index, p1_score, p2_score)

# --- Spezial-Tiles (zerstörbar / Ranken) ---

func send_tile_broken(tile_id: int) -> void:
	if is_host and client_peer_id != 0:
		receive_tile_broken.rpc_id(client_peer_id, tile_id)

@rpc("authority", "call_remote", "reliable")
func receive_tile_broken(tile_id: int) -> void:
	tile_broken_received.emit(tile_id)

func send_tile_regrown(tile_id: int) -> void:
	if is_host and client_peer_id != 0:
		receive_tile_regrown.rpc_id(client_peer_id, tile_id)

@rpc("authority", "call_remote", "reliable")
func receive_tile_regrown(tile_id: int) -> void:
	tile_regrown_received.emit(tile_id)

# --- Talentbaum-Flächeneffekte (visuelle Replikation) ---

func send_zone_spawn(data: Dictionary) -> void:
	if is_host and client_peer_id != 0:
		receive_zone_spawn.rpc_id(client_peer_id, data)

@rpc("authority", "call_remote", "reliable")
func receive_zone_spawn(data: Dictionary) -> void:
	zone_spawn_received.emit(data)

# --- Draft-Synchronisation ---

func send_draft_start(drafter: int, card_ids: Array, picks_total: int) -> void:
	if is_host and client_peer_id != 0:
		receive_draft_start.rpc_id(client_peer_id, drafter, card_ids, picks_total)

@rpc("authority", "call_remote", "reliable")
func receive_draft_start(drafter: int, card_ids: Array, picks_total: int) -> void:
	draft_start_received.emit(drafter, card_ids, picks_total)

func request_draft_pick(card_id: String) -> void:
	if is_client:
		client_draft_pick.rpc_id(1, card_id)

@rpc("any_peer", "call_remote", "reliable")
func client_draft_pick(card_id: String) -> void:
	if not is_host or multiplayer.get_remote_sender_id() != client_peer_id:
		return
	draft_pick_requested.emit(card_id)

func send_draft_pick(card_id: String) -> void:
	if is_host and client_peer_id != 0:
		receive_draft_pick.rpc_id(client_peer_id, card_id)

@rpc("authority", "call_remote", "reliable")
func receive_draft_pick(card_id: String) -> void:
	draft_pick_received.emit(card_id)

func send_draft_finished() -> void:
	if is_host and client_peer_id != 0:
		receive_draft_finished.rpc_id(client_peer_id)

@rpc("authority", "call_remote", "reliable")
func receive_draft_finished() -> void:
	draft_finished_received.emit()

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
