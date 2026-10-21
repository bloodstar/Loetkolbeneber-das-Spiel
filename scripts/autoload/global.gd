extends Node

signal score_changed(p1: int, p2: int)
signal round_ended(loser_index: int)
signal card_selected(player_index: int, card: CardData)
signal match_over(winner_index: int)
signal bot_mode_toggled(enabled: bool)
signal cards_per_draft_changed(count: int)
signal draft_config_changed(picks: int, offered: int)
signal banned_cards_changed()
signal score_to_win_changed(wins: int)
signal base_hp_changed(hp: int)
signal lobby_state_changed()
signal network_status_changed()

enum GameState {
	MENU,
	PLAYING,
	CARD_DRAFT,
	GAME_OVER,
	LOBBY
}

var current_state: GameState = GameState.PLAYING

var p1_score: int = 0
var p2_score: int = 0
var score_to_win: int = 3
var is_bot_enabled: bool = true
var cards_per_draft: int = 5 # Y: Wie viele Karten zur Auswahl stehen
var draft_picks: int = 1     # X: Wie viele Karten pro Draft gewählt werden
var banned_card_ids: Array[String] = [] # Im Lobby gesperrte Powerup-Karten
# 0 = Heldenstandard. > 0 = einheitliche Basis-HP für beide Spieler vor Karten.
var base_hp_override: int = 0

# --- Lobby / Session (multiplayer-ready) ---
var host_player_index: int = 1
var local_player_index: int = 1
var player_ready: Dictionary = {1: false, 2: false}

# --- Netzwerk ---
var network_mode: bool = false
var remote_connected: bool = false
var network_info: String = ""

var p1_hero_id: String = "ignis"
var p2_hero_id: String = "titan"

var p1_cards: Array[CardData] = []
var p2_cards: Array[CardData] = []

var heroes: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_heroes()
	_setup_default_inputs()
	reset_lobby_state()

func _setup_heroes() -> void:
	# 1. Ignis
	var ignis = HeroData.new()
	ignis.id = "ignis"
	ignis.name = "Ignis"
	ignis.role = "Pyro Skirmisher"
	ignis.description = "Explosiv und wendig."
	ignis.passive_desc = "Afterburner: Hinterlässt Feuerspur beim Dash"
	ignis.ability_name = "Rocket Leap"
	ignis.ability_desc = "Explosiver Sprung nach vorn mit AOE-Rückstoß!"
	ignis.ability_cooldown = 5.0
	ignis.base_hp = 100
	ignis.base_shield = 0
	ignis.base_speed = 310.0
	ignis.base_jump_force = -470.0
	ignis.color_tint = Color(1.0, 0.4, 0.2)
	ignis.sprite_tile_name = "tile_0000.png"
	heroes["ignis"] = ignis

	# 2. Titan
	var titan = HeroData.new()
	titan.id = "titan"
	titan.name = "Titan"
	titan.role = "Armored Brawler"
	titan.description = "Schwer gepanzert und standfest."
	titan.passive_desc = "Ironclad: 30 Start-Schild & weniger Knockback"
	titan.ability_name = "Fortress Shield"
	titan.ability_desc = "Erzeugt eine 2.5s undurchdringliche Barriere!"
	titan.ability_cooldown = 7.0
	titan.base_hp = 140
	titan.base_shield = 30
	titan.base_speed = 260.0
	titan.base_jump_force = -450.0
	titan.color_tint = Color(0.3, 0.6, 1.0)
	titan.sprite_tile_name = "tile_0004.png"
	heroes["titan"] = titan

	# 3. Volt
	var volt = HeroData.new()
	volt.id = "volt"
	volt.name = "Volt"
	volt.role = "Hyper Speedster"
	volt.description = "Extrem schnell und mobil."
	volt.passive_desc = "Overcharge: Standardmäßig Doppelsprung aktiv"
	volt.ability_name = "Flash Blink"
	volt.ability_desc = "Sofortiger Teleport-Dash in Zielrichtung!"
	volt.ability_cooldown = 4.5
	volt.base_hp = 85
	volt.base_shield = 0
	volt.base_speed = 350.0
	volt.base_jump_force = -480.0
	volt.extra_jumps = 1
	volt.color_tint = Color(1.0, 0.9, 0.2)
	volt.sprite_tile_name = "tile_0006.png"
	heroes["volt"] = volt

	# 4. Spore
	var spore = HeroData.new()
	spore.id = "spore"
	spore.name = "Spore"
	spore.role = "Toxic Alchemist"
	spore.description = "Zermürbt Feinde mit ätzenden Giften."
	spore.passive_desc = "Spore Coat: Angriffe vergiften Gegner"
	spore.ability_name = "Spore Burst"
	spore.ability_desc = "Hinterlässt eine giftige Gaswolke!"
	spore.ability_cooldown = 6.0
	spore.base_hp = 105
	spore.base_shield = 10
	spore.base_speed = 295.0
	spore.base_jump_force = -460.0
	spore.color_tint = Color(0.4, 0.9, 0.3)
	spore.sprite_tile_name = "tile_0002.png"
	heroes["spore"] = spore

func get_hero(id: String) -> HeroData:
	return heroes.get(id, heroes["ignis"])

func _setup_default_inputs() -> void:
	_ensure_key_action("p1_left", KEY_A)
	_ensure_key_action("p1_right", KEY_D)
	_ensure_key_action("p1_up", KEY_W)
	_ensure_key_action("p1_down", KEY_S)
	_ensure_key_action("p1_jump", KEY_SPACE)
	_ensure_key_action("p1_dash", KEY_SHIFT)
	_ensure_mouse_action("p1_shoot", MOUSE_BUTTON_LEFT)
	_ensure_mouse_action("p1_ability", MOUSE_BUTTON_RIGHT)
	_ensure_key_action("p1_ability_alt", KEY_E)
	_ensure_key_action("p1_ability_q", KEY_Q)
	_ensure_key_action("p1_ability_f", KEY_F)

	# P2 bindings (Keyboard fallback for local 2-player)
	_ensure_key_action("p2_left", KEY_LEFT)
	_ensure_key_action("p2_right", KEY_RIGHT)
	_ensure_key_action("p2_up", KEY_UP)
	_ensure_key_action("p2_down", KEY_DOWN)
	_ensure_key_action("p2_jump", KEY_UP)
	_ensure_key_action("p2_dash", KEY_SLASH) # Shift or slash
	_ensure_key_action("p2_shoot", KEY_PERIOD)
	_ensure_key_action("p2_ability", KEY_COMMA)

	# Utility
	_ensure_key_action("restart_game", KEY_R)

func _ensure_key_action(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _ensure_mouse_action(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

func reset_match() -> void:
	p1_score = 0
	p2_score = 0
	p1_cards.clear()
	p2_cards.clear()
	current_state = GameState.PLAYING
	score_changed.emit(p1_score, p2_score)

func award_round(winner_index: int) -> void:
	if winner_index == 1:
		p1_score += 1
	else:
		p2_score += 1
	score_changed.emit(p1_score, p2_score)
	
	if p1_score >= score_to_win:
		current_state = GameState.GAME_OVER
		match_over.emit(1)
	elif p2_score >= score_to_win:
		current_state = GameState.GAME_OVER
		match_over.emit(2)
	else:
		current_state = GameState.CARD_DRAFT
		var loser = 2 if winner_index == 1 else 1
		round_ended.emit(loser)

func add_card_to_player(player_index: int, card: CardData) -> bool:
	if card == null:
		return false
	# Jede Karte darf pro Spieler nur einmal vorkommen.
	if player_has_card(player_index, card.id):
		return false
	if player_index == 1:
		p1_cards.append(card)
	else:
		p2_cards.append(card)
	card_selected.emit(player_index, card)
	return true

func get_player_cards(player_index: int) -> Array[CardData]:
	if player_index == 1:
		return p1_cards
	return p2_cards

func player_has_card(player_index: int, card_id: String) -> bool:
	for card in get_player_cards(player_index):
		if card.id == card_id:
			return true
	return false

func get_owned_card_ids(player_index: int) -> Array[String]:
	var ids: Array[String] = []
	for card in get_player_cards(player_index):
		ids.append(card.id)
	return ids

func set_base_hp_override(hp: int) -> void:
	var clamped := clampi(hp, 0, 500)
	if base_hp_override == clamped:
		return
	base_hp_override = clamped
	base_hp_changed.emit(base_hp_override)

func toggle_bot() -> void:
	set_bot_enabled(not is_bot_enabled)

func set_bot_enabled(enabled: bool) -> void:
	if is_bot_enabled == enabled:
		return
	is_bot_enabled = enabled
	# Bots sind immer bereit; ein menschlicher Spieler muss bestätigen.
	player_ready[2] = enabled
	bot_mode_toggled.emit(is_bot_enabled)
	lobby_state_changed.emit()

func set_score_to_win(wins: int) -> void:
	score_to_win = clampi(wins, 1, 10)
	score_to_win_changed.emit(score_to_win)

# X von Y: picks = gewählte Karten pro Draft, offered = angebotene Karten
func set_draft_config(picks: int, offered: int) -> void:
	cards_per_draft = clampi(offered, 1, 10)
	draft_picks = clampi(picks, 1, cards_per_draft)
	draft_config_changed.emit(draft_picks, cards_per_draft)
	cards_per_draft_changed.emit(cards_per_draft)

func cycle_cards_per_draft() -> void:
	var next_offered := 3
	if cards_per_draft == 3:
		next_offered = 5
	elif cards_per_draft == 5:
		next_offered = 7
	set_draft_config(draft_picks, next_offered)

func set_card_banned(card_id: String, banned: bool) -> void:
	if banned == banned_card_ids.has(card_id):
		return
	if banned:
		banned_card_ids.append(card_id)
	else:
		banned_card_ids.erase(card_id)
	banned_cards_changed.emit()

func is_card_banned(card_id: String) -> bool:
	return banned_card_ids.has(card_id)

func toggle_card_ban(card_id: String) -> void:
	set_card_banned(card_id, not banned_card_ids.has(card_id))

func get_available_card_count() -> int:
	var count := 0
	for card in CardDatabase.all_cards:
		if card.parent_card_id.is_empty() and not banned_card_ids.has(card.id):
			count += 1
	return count

# Klassenspezifische Karten zählen nur für den passenden Helden. Für den Start
# eines Matches zählen nur Grundkarten; Ausbaukarten werden erst nach Besitz der
# Grundkarte draftbar. Für den Draft eines Spielers ist der Vorrat seines Helden
# entscheidend.
func get_available_card_count_for_hero(hero_id: String) -> int:
	var count := 0
	for card in CardDatabase.all_cards:
		if not card.parent_card_id.is_empty():
			continue
		if banned_card_ids.has(card.id):
			continue
		if not card.hero_id.is_empty() and card.hero_id != hero_id:
			continue
		count += 1
	return count

# Kleinerer Vorrat beider Helden. `extra_ban_id` simuliert eine zusätzliche
# Sperre, damit die Lobby vor dem Setzen eines Bans prüfen kann, ob danach noch
# genug Karten für beide Helden übrig bleiben.
func get_available_card_count_for_match(extra_ban_id: String = "") -> int:
	var result := 999999
	var hero_ids: Array[String] = [p1_hero_id, p2_hero_id]
	for hero_id in hero_ids:
		var count := 0
		for card in CardDatabase.all_cards:
			if not card.parent_card_id.is_empty():
				continue
			if card.id == extra_ban_id:
				continue
			if banned_card_ids.has(card.id):
				continue
			if not card.hero_id.is_empty() and card.hero_id != hero_id:
				continue
			count += 1
		result = mini(result, count)
	return maxi(0, result)

# --- Lobby / Ready / Host ---

func reset_lobby_state() -> void:
	player_ready[1] = false
	player_ready[2] = is_bot_enabled
	lobby_state_changed.emit()

func set_player_ready(index: int, ready: bool) -> void:
	if is_player_ready(index) == ready:
		return
	player_ready[index] = ready
	lobby_state_changed.emit()

func is_player_ready(index: int) -> bool:
	return bool(player_ready.get(index, false))

func all_players_ready() -> bool:
	return is_player_ready(1) and is_player_ready(2)

func is_local_host() -> bool:
	return local_player_index == host_player_index

# Für Netzwerk-Clients: legt fest, welcher Slot lokal gesteuert wird.
func set_local_player(index: int) -> void:
	local_player_index = clampi(index, 1, 2)
	lobby_state_changed.emit()

# Darf der lokale Spieler diesen Slot bearbeiten (Held, Bereit)?
func can_control_slot(index: int) -> bool:
	if not network_mode:
		return true
	return index == local_player_index

# --- Netzwerk-Spielstand (vom Host gespiegelt) ---

func set_network_scores(s1: int, s2: int) -> void:
	if s1 == p1_score and s2 == p2_score:
		return
	p1_score = s1
	p2_score = s2
	score_changed.emit(p1_score, p2_score)

func set_network_match_over(winner_index: int) -> void:
	current_state = GameState.GAME_OVER
	match_over.emit(winner_index)

func set_network_info(text: String) -> void:
	network_info = text
	network_status_changed.emit()
