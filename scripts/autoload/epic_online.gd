extends Node

# Online-Modus über Epic Online Services (Plugin EOSG).
# Anmeldung per Geräte-ID (kein Epic-Konto nötig). Der Host legt eine Lobby mit
# einem 6-stelligen Code an, Clients suchen diesen Code und verbinden sich per
# EOS-P2P (NAT-Traversal, bei Bedarf über Epics Relay-Server). Die Lobby dient
# nur als "Telefonbuch": Clients treten ihr nicht bei.
# Die Zugangsdaten stehen in eos_config.cfg (neben der EXE oder im Projekt).
# Alle Plugin-Autoloads werden dynamisch geholt, damit LAN auch ohne Plugin läuft.

const CONFIG_FILE: String = "eos_config.cfg"
const SOCKET_NAME: String = "DopDopGame"
const BUCKET_ID: String = "dopdop"
const CODE_ATTRIBUTE: String = "CODE"
const CODE_CHARS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH: int = 6
const CREDENTIAL_KEYS: Array[String] = ["product_id", "sandbox_id", "deployment_id", "client_id", "client_secret"]
# Bricht ab, falls Epic nicht antwortet, damit das Menü nicht ewig wartet.
const TIMEOUT_SEC: float = 25.0
const LOG_FILE: String = "epic_online.log"

# Fortschritt für die Statuszeile im Menü.
signal status_changed(text: String)
signal _attempt_finished(peer: MultiplayerPeer)

var online_code: String = ""
var last_error: String = ""

var _platform_created: bool = false
var _logged_in: bool = false
var _busy: bool = false
var _lobby = null # HLobby des Hosts
var _attempt: int = 0
var _attempt_done: bool = true
var _step: String = ""

func _ready() -> void:
	# Menü und Lobby pausieren den SceneTree. EOS muss trotzdem weiter ticken,
	# sonst kommen keine Antworten (Login, Lobby, P2P-Pakete) an.
	var runtime := get_node_or_null("/root/EOSGRuntime")
	if runtime != null:
		runtime.process_mode = Node.PROCESS_MODE_ALWAYS

func is_plugin_available() -> bool:
	return ClassDB.class_exists("EOSGMultiplayerPeer") \
		and get_node_or_null("/root/HPlatform") != null \
		and get_node_or_null("/root/HAuth") != null \
		and get_node_or_null("/root/HLobbies") != null

# Leerer Text = alles bereit, sonst ein Hinweis für das Menü.
func get_setup_problem() -> String:
	if not is_plugin_available():
		return "Epic-Plugin (EOSG) ist nicht installiert oder nicht aktiviert."
	if _load_config().is_empty():
		return "eos_config.cfg fehlt oder ist unvollständig."
	return ""

func is_busy() -> bool:
	return _busy

# Startet den EOS-Server-Peer und veröffentlicht den Lobby-Code.
# Gibt den fertigen MultiplayerPeer zurück oder null (Grund in last_error).
func create_host_async() -> MultiplayerPeer:
	return await _run_attempt(_create_host_inner.bind())

# Sucht den Host zum Code und startet den EOS-Client-Peer.
func create_client_async(code: String) -> MultiplayerPeer:
	return await _run_attempt(_create_client_inner.bind(code))

# Lobby des Hosts aufräumen. Der Peer selbst wird vom NetworkManager geschlossen.
func stop() -> void:
	online_code = ""
	if _lobby != null:
		var lobby = _lobby
		_lobby = null
		lobby.destroy_async()

static func normalize_code(code: String) -> String:
	return code.strip_edges().to_upper().replace(" ", "").replace("-", "")

# --- intern ---

# Startet einen Ablauf und wartet auf sein Ende oder den Timeout.
func _run_attempt(work: Callable) -> MultiplayerPeer:
	if _busy:
		last_error = "Epic-Verbindung wird gerade schon aufgebaut."
		return null
	_busy = true
	_attempt += 1
	_attempt_done = false
	var attempt := _attempt
	last_error = ""
	_worker.call_deferred(work, attempt)
	get_tree().create_timer(TIMEOUT_SEC).timeout.connect(func():
		if attempt == _attempt and not _attempt_done:
			last_error = "Epic antwortet nicht (hängt bei: %s). Internet/Firewall prüfen." % _step
			_log("TIMEOUT bei Schritt: " + _step)
			_finish_attempt(attempt, null)
	)
	var peer: MultiplayerPeer = await _attempt_finished
	return peer

func _worker(work: Callable, attempt: int) -> void:
	var peer: MultiplayerPeer = await work.call()
	if attempt != _attempt or _attempt_done:
		# Zu spät (Timeout schon gemeldet): aufräumen.
		if peer != null:
			peer.close()
		stop()
		return
	if peer == null:
		_log("FEHLER: " + last_error)
	_finish_attempt(attempt, peer)

func _finish_attempt(attempt: int, peer: MultiplayerPeer) -> void:
	if attempt != _attempt or _attempt_done:
		return
	_attempt_done = true
	_busy = false
	_attempt_finished.emit(peer)

func _set_step(text: String) -> void:
	_step = text
	_log(text)
	status_changed.emit(text)

# Schreibt nach user://epic_online.log und beim Start aus dem Editor zusätzlich
# in den Projektordner, damit man das Log leicht findet.
func _log(text: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), text]
	print("[EpicOnline] " + text)
	var paths: Array[String] = ["user://" + LOG_FILE]
	if OS.has_feature("editor"):
		paths.append("res://" + LOG_FILE)
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ_WRITE)
		if file == null:
			file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			continue
		file.seek_end()
		file.store_line(line)
		file.close()

func _on_eos_log(msg) -> void:
	_log("EOS %s: %s" % [msg.category, msg.message])

func _create_host_inner() -> MultiplayerPeer:
	stop()
	_log("--- Online hosten ---")
	if not await _ensure_logged_in_async():
		return null
	_set_step("Starte P2P-Server ...")
	var inner: MultiplayerPeer = ClassDB.instantiate("EOSGMultiplayerPeer")
	if inner.create_server(SOCKET_NAME) != OK:
		last_error = "EOS-Server konnte nicht gestartet werden."
		return null

	var auth := get_node("/root/HAuth")
	var opts := EOS.Lobby.CreateLobbyOptions.new()
	opts.local_user_id = auth.product_user_id
	opts.bucket_id = BUCKET_ID
	opts.max_lobby_members = 2
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.presence_enabled = false
	opts.allow_invites = false
	opts.enable_join_by_id = false
	opts.enable_rtc_room = false
	_set_step("Erstelle Epic-Lobby ...")
	var lobby = await get_node("/root/HLobbies").create_lobby_async(opts)
	if lobby == null:
		inner.close()
		last_error = "Epic-Lobby konnte nicht erstellt werden."
		return null

	var code := _generate_code()
	_set_step("Veröffentliche Code %s ..." % code)
	lobby.add_attribute(CODE_ATTRIBUTE, code)
	if not await lobby.update_async():
		lobby.destroy_async()
		inner.close()
		last_error = "Lobby-Code konnte nicht veröffentlicht werden."
		return null
	_lobby = lobby
	online_code = code
	_set_step("Online-Spiel bereit, Code: " + code)
	return EosFragmentPeer.new(inner)

func _create_client_inner(code: String) -> MultiplayerPeer:
	stop()
	var clean := normalize_code(code)
	if clean.length() != CODE_LENGTH:
		last_error = "Der Code hat %d Zeichen." % CODE_LENGTH
		return null
	_log("--- Beitreten mit Code %s ---" % clean)
	if not await _ensure_logged_in_async():
		return null
	_set_step("Suche Spiel %s ..." % clean)
	var lobbies = await get_node("/root/HLobbies").search_by_attribute_async({
		key = CODE_ATTRIBUTE,
		value = clean,
	})
	if lobbies == null:
		last_error = "Suche bei Epic fehlgeschlagen. Internet prüfen."
		return null
	if lobbies.is_empty():
		last_error = "Kein offenes Spiel mit Code %s gefunden." % clean
		return null
	var host_user_id: String = lobbies[0].owner_product_user_id
	if host_user_id == get_node("/root/HAuth").product_user_id:
		last_error = "Das ist dein eigenes Spiel (gleicher PC)."
		return null
	_set_step("Spiel gefunden, verbinde zum Host ...")
	var inner: MultiplayerPeer = ClassDB.instantiate("EOSGMultiplayerPeer")
	if inner.create_client(SOCKET_NAME, host_user_id) != OK:
		last_error = "Verbindung zum Host konnte nicht gestartet werden."
		return null
	return EosFragmentPeer.new(inner)

func _ensure_logged_in_async() -> bool:
	if _logged_in:
		return true
	var problem := get_setup_problem()
	if not problem.is_empty():
		last_error = problem
		return false
	if not _platform_created:
		# Plugin-Meldungen ausführlicher ins Ausgabe-Fenster.
		HLog.log_level = HLog.LogLevel.DEBUG
		var config := _load_config()
		var creds := HCredentials.new()
		creds.product_name = str(config.get("product_name", "DopDop"))
		creds.product_version = str(config.get("product_version", "1.0"))
		creds.product_id = config.product_id
		creds.sandbox_id = config.sandbox_id
		creds.deployment_id = config.deployment_id
		creds.client_id = config.client_id
		creds.client_secret = config.client_secret
		var platform := get_node("/root/HPlatform")
		# Das Epic-Overlay brauchen wir nicht (kein Epic-Konto-Login).
		platform.flags = EOS.Platform.PlatformFlags.DisableOverlay
		_set_step("Starte Epic-Dienste ...")
		if not await platform.setup_eos_async(creds):
			last_error = "EOS-Start fehlgeschlagen. IDs in eos_config.cfg prüfen."
			return false
		_platform_created = true
		platform.log_msg.connect(_on_eos_log)
		EOS.Logging.set_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Warning)
	_set_step("Melde bei Epic an ...")
	if not await get_node("/root/HAuth").login_anonymous_async(_display_name()):
		last_error = "Anmeldung bei Epic fehlgeschlagen. Client-Policy (Peer2Peer) prüfen."
		return false
	_logged_in = true
	_log("Angemeldet, Product User ID: " + str(get_node("/root/HAuth").product_user_id))
	return true

# Erst neben der EXE suchen (leicht austauschbar), dann im Projekt/PCK.
func _load_config() -> Dictionary:
	var paths: Array[String] = [
		OS.get_executable_path().get_base_dir().path_join(CONFIG_FILE),
		"res://" + CONFIG_FILE,
	]
	for path in paths:
		var file := ConfigFile.new()
		if file.load(path) != OK:
			continue
		if not file.has_section("eos"):
			continue
		var data := {}
		for key in file.get_section_keys("eos"):
			data[key] = str(file.get_value("eos", key, "")).strip_edges()
		var complete := true
		for key in CREDENTIAL_KEYS:
			if str(data.get(key, "")).is_empty():
				complete = false
		if complete:
			return data
	return {}

func _display_name() -> String:
	var saved_name := str(Global.user_character_customization.get("name", ""))
	if not saved_name.is_empty():
		return saved_name.substr(0, 32)
	var user := OS.get_environment("USERNAME")
	if user.is_empty():
		user = OS.get_environment("USER")
	if user.is_empty():
		user = "Spieler"
	return user.substr(0, 32)

func _generate_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in CODE_LENGTH:
		code += CODE_CHARS[rng.randi_range(0, CODE_CHARS.length() - 1)]
	return code
