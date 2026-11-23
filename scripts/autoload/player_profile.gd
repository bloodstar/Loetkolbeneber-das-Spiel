extends Node

# Spielerprofil mit Lebenszeit-Statistiken des lokalen Spielers.
#
# Ein Profil pro PC, gespeichert unter user://player_profile.json. Es gehört
# immer zu Global.local_player_index (offline normalerweise Slot 1, online der
# eigene Slot). Weitere Menschen am selben PC (Hot-Seat) zählen nicht mit.
# Bot-Test, Zuschauer, Bot-Slots und Testrunden aus den Map-Editoren zählen
# ebenfalls nicht.
#
# Datenfluss:
# - Rundenende: Host bzw. Offline-Spiel rechnet in main._finish_round (vor
#   Global.award_round) für jeden Slot die Werte dieser Runde aus
#   (Global.MATCH_STAT_KEYS seit Rundenstart) und schickt alle Zeilen per
#   NetworkManager.send_profile_round an die Clients. Jede Maschine bucht nur
#   die Zeile ihres eigenen Slots (_apply_round).
#   Lebenszeit-Summen (Kills, Tode, Schaden ...) stammen aus diesen Runden;
#   eine abgebrochene Runde zählt deshalb nicht.
# - Matchende: Global.match_over (feuert auf Host, Offline und Clients) bucht
#   Match, Sieg, Held, Waffe, Spielart und das Deck.
# - Kartenwahl: Global.card_selected zählt jede gewählte Karte des Slots.
#
# Erweiterung (z. B. Achievements, Titel):
# - Signale round_recorded(summary) und match_recorded(summary) feuern NACH
#   dem Hochzählen und VOR dem Speichern. Was ein Handler in get_ext(ns)
#   ändert, wird mitgespeichert.
# - get_ext("achievements") liefert ein veränderbares Dictionary im selben
#   Dokument; nach Änderungen außerhalb der Signale save_profile() aufrufen.
# - Die Profil-Ansicht (ProfileScreen) hängt einen Abschnitt ein, wenn ein
#   Autoload /root/AchievementManager build_profile_section() -> Control hat.

signal round_recorded(summary: Dictionary)
signal match_recorded(summary: Dictionary)
signal profile_changed()

const PROFILE_PATH: String = "user://player_profile.json"
const SCHEMA_VERSION: int = 1
const MAX_HISTORY: int = 20

# Summen, die aus den Rundenzeilen kommen (alle MATCH_STAT_KEYS außer
# rounds_won, das zählen wir selbst über won_round).
const ROUND_SUM_KEYS: Array[String] = [
	"kills", "deaths", "damage_dealt", "damage_taken", "damage_blocked",
	"blocked_hits", "healing_done", "shots_fired", "shots_hit",
	"melee_damage", "melee_hits", "ability_damage",
]

var persistence_enabled: bool = true
# Überschreibbar für Tests, damit diese niemals die echte Datei berühren.
var storage_path: String = PROFILE_PATH

var data: Dictionary = {}

# Laufendes Match/Runde (nur lokal, nicht gespeichert).
var _stats_at_round_start: Array = []
var _round_open: bool = false
var _round_map_id: String = ""
var _round_arena: bool = false
var _match_started_msec: int = 0
var _round_started_msec: int = 0
var _match_rounds: int = 0
var _match_rounds_won: int = 0
var _match_sums: Dictionary = {}
var _match_maps: Array = []
var _match_counted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("headless"):
		persistence_enabled = false
	for arg in OS.get_cmdline_args():
		if "test_scene" in arg:
			persistence_enabled = false
	load_profile()
	Global.match_reset.connect(_on_match_reset)
	Global.match_over.connect(_on_match_over)
	Global.card_selected.connect(_on_card_selected)
	_reset_match_tracking()

# --- Lesen ---

func get_totals() -> Dictionary:
	return data.get("totals", {})

func get_stat(key: String) -> float:
	return float(get_totals().get(key, 0.0))

func get_hero_stats() -> Dictionary:
	return data.get("heroes", {})

func get_card_stats() -> Dictionary:
	return data.get("cards", {})

func get_map_stats() -> Dictionary:
	return data.get("maps", {})

func get_melee_stats() -> Dictionary:
	return data.get("melee", {})

func get_mode_stats() -> Dictionary:
	return data.get("modes", {})

func get_records() -> Dictionary:
	return data.get("records", {})

func get_history() -> Array:
	return data.get("history", [])

func get_created_at() -> String:
	return str(data.get("created_at", ""))

# Kills pro Tod; ohne Tode die Kills selbst.
func get_kd() -> float:
	var deaths := get_stat("deaths")
	var kills := get_stat("kills")
	return kills / deaths if deaths > 0.0 else kills

func get_match_win_rate() -> float:
	var matches := get_stat("matches")
	return get_stat("matches_won") / matches if matches > 0.0 else 0.0

# Held mit den meisten gespielten Runden (Gleichstand: mehr Matches).
func get_favorite_hero() -> String:
	return _best_key(get_hero_stats(), "rounds", "matches")

func get_most_picked_card() -> String:
	return _best_key(get_card_stats(), "picks", "matches")

func get_favorite_map() -> String:
	return _best_key(get_map_stats(), "rounds", "rounds_won")

# Veränderbarer Bereich für andere Systeme (Achievements, Titel ...).
func get_ext(ns: String) -> Dictionary:
	if not data.has("ext") or not data["ext"] is Dictionary:
		data["ext"] = {}
	var ext: Dictionary = data["ext"]
	if not ext.has(ns) or not ext[ns] is Dictionary:
		ext[ns] = {}
	return ext[ns]

# --- Zählen ---

# Gilt für den lokalen Spieler auf dieser Maschine?
func is_tracking_slot(slot: int) -> bool:
	return slot >= 1 and slot == Global.local_player_index and _tracking_allowed()

func _tracking_allowed() -> bool:
	if Global.is_spectator or Global.is_bot_test_active():
		return false
	if not ArenaMaps.test_map_id.is_empty() or not SideLevels.test_map_id.is_empty():
		return false
	var slot := Global.local_player_index
	return Global.is_active_slot(slot) and Global.is_human_slot(slot)

# main._start_fresh_round, auf allen Maschinen nach dem Levelaufbau.
func begin_round(map_id: String) -> void:
	_round_open = true
	_round_map_id = map_id
	_round_arena = ArenaMode.active
	_round_started_msec = Time.get_ticks_msec()
	_stats_at_round_start = Global.get_match_stats()

# main._finish_round auf Host/Offline, vor Global.award_round. Rechnet für
# jeden Slot die Rundenwerte aus und verteilt sie an die Clients.
func finish_round(winner_index: int, death_order: Array) -> void:
	if not _round_open or NetworkManager.is_client:
		return
	var now := Global.get_match_stats()
	var active: Array[int] = Global.get_round_player_indices()
	var winner_team := Global.get_team_for_slot(winner_index) if winner_index > 0 else -1
	var team_mode := Global.is_team_mode()
	var rows: Array = []
	for slot in active:
		var won := false
		if winner_index > 0:
			won = Global.get_team_for_slot(slot) == winner_team if team_mode else slot == winner_index
		var index := death_order.find(slot)
		rows.append({
			"slot": slot,
			"hero_id": Global.get_player_hero_id(slot),
			"won_round": won,
			"survived": index < 0,
			"placement": 1 if index < 0 else active.size() - index,
			"stats": _delta(slot, now),
		})
	var info := {
		"map_id": _round_map_id,
		"arena": _round_arena,
		"player_count": active.size(),
		"duration_s": snappedf(float(Time.get_ticks_msec() - _round_started_msec) / 1000.0, 0.01),
	}
	if NetworkManager.is_host and NetworkManager.has_clients():
		NetworkManager.send_profile_round(info, rows)
	receive_round(info, rows)

# Auch Ziel des Netzwerk-RPCs auf Clients.
func receive_round(info: Dictionary, rows: Array) -> void:
	_round_open = false
	for value in rows:
		if value is Dictionary and int(value.get("slot", 0)) == Global.local_player_index:
			_apply_round(info, value)
			return

func _apply_round(info: Dictionary, row: Dictionary) -> void:
	if not is_tracking_slot(int(row.get("slot", 0))):
		return
	var stats: Dictionary = row.get("stats", {})
	var won := bool(row.get("won_round", false))
	var hero_id := str(row.get("hero_id", ""))
	var map_id := str(info.get("map_id", ""))
	var totals := _section("totals")
	_add(totals, "rounds", 1.0)
	if won:
		_add(totals, "rounds_won", 1.0)
	if bool(row.get("survived", false)):
		_add(totals, "rounds_survived", 1.0)
	_add(totals, "play_time_s", float(info.get("duration_s", 0.0)))
	for key in ROUND_SUM_KEYS:
		var amount := float(stats.get(key, 0.0))
		_add(totals, key, amount)
		_match_sums[key] = float(_match_sums.get(key, 0.0)) + amount
	_match_rounds += 1
	if won:
		_match_rounds_won += 1
	if not _match_maps.has(map_id):
		_match_maps.append(map_id)

	if not hero_id.is_empty():
		var hero := _entry("heroes", hero_id)
		_add(hero, "rounds", 1.0)
		if won:
			_add(hero, "rounds_won", 1.0)
		for key in ["kills", "deaths", "damage_dealt", "healing_done", "ability_damage"]:
			_add(hero, key, float(stats.get(key, 0.0)))
	if not map_id.is_empty():
		var map_entry := _entry("maps", map_id)
		_add(map_entry, "rounds", 1.0)
		if won:
			_add(map_entry, "rounds_won", 1.0)
		_add(map_entry, "kills", float(stats.get("kills", 0.0)))

	var records := _section("records")
	_record_max(records, "most_kills_round", float(stats.get("kills", 0.0)))
	_record_max(records, "most_damage_round", float(stats.get("damage_dealt", 0.0)))

	var summary := {
		"map_id": map_id,
		"arena": bool(info.get("arena", false)),
		"hero_id": hero_id,
		"won_round": won,
		"survived": bool(row.get("survived", false)),
		"placement": int(row.get("placement", 0)),
		"player_count": int(info.get("player_count", 0)),
		"duration_s": float(info.get("duration_s", 0.0)),
		"game_mode": Global.game_mode,
		"match_mode": Global.match_mode,
		"stats": stats.duplicate(),
	}
	round_recorded.emit(summary)
	_touch_and_save()

func _on_card_selected(player_index: int, card: CardData) -> void:
	if card == null or not is_tracking_slot(player_index):
		return
	if Global.current_state == Global.GameState.GAME_OVER:
		return
	_add(_entry("cards", card.id), "picks", 1.0)
	_add(_section("totals"), "cards_picked", 1.0)
	_touch_and_save()

func _on_match_reset() -> void:
	_reset_match_tracking()

func _reset_match_tracking() -> void:
	_match_started_msec = Time.get_ticks_msec()
	_match_rounds = 0
	_match_rounds_won = 0
	_match_sums.clear()
	_match_maps.clear()
	_match_counted = false
	_round_open = false

func _on_match_over(winner_index: int) -> void:
	if _match_counted:
		return
	_match_counted = true
	var slot := Global.local_player_index
	if not is_tracking_slot(slot):
		return
	# Ohne eine fertige Runde (sofort verlassen) zählt das Match nicht.
	if _match_rounds <= 0:
		return
	var early := Global.match_end_reason == "early"
	var draw := winner_index <= 0
	var won := false
	if not draw:
		if Global.is_team_mode():
			won = Global.get_team_for_slot(slot) == Global.get_team_for_slot(winner_index)
		else:
			won = slot == winner_index
	var hero_id := Global.get_player_hero_id(slot)
	var weapon_id := Global.get_melee_weapon(slot)
	var mvp := Global.get_match_mvp_index() == slot and Global.get_active_player_indices().size() > 1

	var totals := _section("totals")
	_add(totals, "matches", 1.0)
	if won:
		_add(totals, "matches_won", 1.0)
	elif draw:
		_add(totals, "matches_drawn", 1.0)
	if early:
		_add(totals, "matches_left_early", 1.0)
	if mvp:
		_add(totals, "mvp", 1.0)

	var records := _section("records")
	if won:
		records["win_streak"] = int(records.get("win_streak", 0)) + 1
	else:
		records["win_streak"] = 0
	_record_max(records, "best_win_streak", float(records["win_streak"]))
	_record_max(records, "most_kills_match", float(_match_sums.get("kills", 0.0)))
	_record_max(records, "most_damage_match", float(_match_sums.get("damage_dealt", 0.0)))

	if not hero_id.is_empty():
		var hero := _entry("heroes", hero_id)
		_add(hero, "matches", 1.0)
		if won:
			_add(hero, "wins", 1.0)
	if not weapon_id.is_empty():
		var weapon := _entry("melee", weapon_id)
		_add(weapon, "matches", 1.0)
		if won:
			_add(weapon, "wins", 1.0)
		_add(weapon, "melee_damage", float(_match_sums.get("melee_damage", 0.0)))
	var mode_key := "%s/%s" % [Global.game_mode, Global.match_mode]
	var mode := _entry("modes", mode_key)
	_add(mode, "matches", 1.0)
	if won:
		_add(mode, "wins", 1.0)

	var card_ids: Array = []
	for value in Global.get_player_cards(slot):
		var card := value as CardData
		if card == null:
			continue
		card_ids.append(card.id)
		var entry := _entry("cards", card.id)
		_add(entry, "matches", 1.0)
		if won:
			_add(entry, "wins", 1.0)

	var summary := {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"won": won,
		"draw": draw,
		"early": early,
		"mvp": mvp,
		"hero_id": hero_id,
		"melee_weapon": weapon_id,
		"game_mode": Global.game_mode,
		"match_mode": Global.match_mode,
		"player_count": Global.get_active_player_indices().size(),
		"rounds": _match_rounds,
		"rounds_won": _match_rounds_won,
		"score": Global.player_scores[slot - 1] if slot <= Global.player_scores.size() else 0,
		"duration_s": snappedf(float(Time.get_ticks_msec() - _match_started_msec) / 1000.0, 0.1),
		"maps": _match_maps.duplicate(),
		"stats": _match_sums.duplicate(),
		"cards": card_ids,
	}
	var history: Array = data.get("history", [])
	history.push_front(summary.duplicate(true))
	while history.size() > MAX_HISTORY:
		history.pop_back()
	data["history"] = history
	match_recorded.emit(summary)
	_touch_and_save()

# --- Speichern ---

func load_profile() -> void:
	data = _empty_document()
	if not persistence_enabled or not FileAccess.file_exists(storage_path):
		return
	var text := FileAccess.get_file_as_string(storage_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("PlayerProfile: Profil konnte nicht gelesen werden: %s" % storage_path)
		return
	var loaded: Dictionary = parsed
	data.merge(loaded, true)
	for key in ["totals", "heroes", "cards", "maps", "melee", "modes", "records", "ext"]:
		if not data[key] is Dictionary:
			data[key] = {}
	if not data["history"] is Array:
		data["history"] = []

func save_profile() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		push_warning("PlayerProfile: Profil konnte nicht gespeichert werden: %s" % storage_path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# Setzt alle Lebenszeit-Werte zurück. Erweiterungen (ext) bleiben erhalten,
# außer keep_ext ist false.
func reset_profile(keep_ext: bool = true) -> void:
	var ext: Dictionary = data.get("ext", {})
	data = _empty_document()
	if keep_ext:
		data["ext"] = ext
	_touch_and_save()

func get_profile_path() -> String:
	return ProjectSettings.globalize_path(storage_path)

# --- intern ---

func _empty_document() -> Dictionary:
	return {
		"schema": SCHEMA_VERSION,
		"created_at": Time.get_datetime_string_from_system(false, true),
		"updated_at": "",
		"totals": {},
		"heroes": {},
		"cards": {},
		"maps": {},
		"melee": {},
		"modes": {},
		"records": {},
		"history": [],
		"ext": {},
	}

func _touch_and_save() -> void:
	data["schema"] = SCHEMA_VERSION
	data["updated_at"] = Time.get_datetime_string_from_system(false, true)
	save_profile()
	profile_changed.emit()

func _section(key: String) -> Dictionary:
	if not data.get(key) is Dictionary:
		data[key] = {}
	return data[key]

func _entry(section_key: String, id: String) -> Dictionary:
	var section := _section(section_key)
	if not section.get(id) is Dictionary:
		section[id] = {}
	return section[id]

func _add(target: Dictionary, key: String, amount: float) -> void:
	target[key] = snappedf(float(target.get(key, 0.0)) + amount, 0.01)

func _record_max(records: Dictionary, key: String, value: float) -> void:
	if value > float(records.get(key, 0.0)):
		records[key] = snappedf(value, 0.01)

func _delta(slot: int, now: Array) -> Dictionary:
	var result := {}
	var current: Dictionary = now[slot - 1] if slot - 1 < now.size() and now[slot - 1] is Dictionary else {}
	var before: Dictionary = {}
	if slot - 1 < _stats_at_round_start.size() and _stats_at_round_start[slot - 1] is Dictionary:
		before = _stats_at_round_start[slot - 1]
	for key in ROUND_SUM_KEYS:
		result[key] = snappedf(float(current.get(key, 0.0)) - float(before.get(key, 0.0)), 0.01)
	return result

func _best_key(section: Dictionary, primary: String, secondary: String) -> String:
	var best := ""
	var best_primary := 0.0
	var best_secondary := -1.0
	for id in section.keys():
		var entry: Variant = section[id]
		if not entry is Dictionary:
			continue
		var p := float(entry.get(primary, 0.0))
		var s := float(entry.get(secondary, 0.0))
		if p > best_primary or (p == best_primary and p > 0.0 and s > best_secondary):
			best = str(id)
			best_primary = p
			best_secondary = s
	return best
