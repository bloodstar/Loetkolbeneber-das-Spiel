extends Node

# Erfolge (Achievements) mit Titeln und Freischaltungen.
#
# Jeder Erfolg hat ein Ziel auf einem Lebenszeit-Zähler (z. B. 50 Kills) und
# eine Belohnung: einen Titel, der unter dem Namen steht, und/oder ein
# Aussehens-Teil (Baukasten-Teil, Hauer- oder Spitzenform), das bis dahin im
# Charakter-Tab gesperrt ist. Gespeichert wird alles in user://achievements.json
# (Zähler, Freischaltzeitpunkte, gewählter Titel).
#
# Ablauf: Nur der Host bzw. ein Offline-Spiel kennt Schaden, Kills und Sieger
# sicher. main.gd ruft begin_round() und end_round() auf; daraus entsteht pro
# Slot eine kleine Rundenzusammenfassung. Die des lokalen Spielers wird direkt
# verbucht, die eines Online-Mitspielers per RPC an dessen Rechner geschickt,
# der sie in seinem eigenen Profil verbucht. Bots und Bot-Test zählen nicht.
# Im lokalen Mehrspieler (mehrere Menschen an einem PC) zählt nur der eigene
# Slot (Global.local_player_index), weil es nur ein gespeichertes Profil gibt.
#
# Titel: Global.player_titles hält pro Slot die Titel-ID (Erfolgs-ID oder "").
# Clients melden ihren Titel per NetworkManager.request_player_title, der Host
# verteilt ihn mit dem Lobby-Sync (Schlüssel "titles").
#
# Neuen Erfolg anlegen: Eintrag in ACHIEVEMENTS (Zähler aus COUNTER_LABELS oder
# ein neuer Zähler, der in _apply_summary hochgezählt wird). Neues sperrbares
# Teil: "unlock" = [Kategorie, ID], Kategorie = PigModular.PART_OPTIONS-Schlüssel,
# "tusk" (Global.TUSK_SHAPES) oder "tip" (Global.WAND_TIP_SHAPES).

signal progress_changed()
signal achievement_unlocked(id: String)
signal title_changed(slot: int)

const SAVE_PATH: String = "user://achievements.json"
const SAVE_VERSION: int = 1

# Anzeigenamen der Zähler (Erfolgsliste, Wiki).
const COUNTER_LABELS: Dictionary = {
	"matches_played": "Matches gespielt",
	"matches_won": "Matches gewonnen",
	"rounds_played": "Runden gespielt",
	"rounds_won": "Runden gewonnen",
	"kills": "Kills",
	"damage_dealt": "Schaden",
	"healing_done": "Heilung",
	"blocked_hits": "Geblockte Treffer",
	"melee_damage": "Nahkampfschaden",
	"ability_damage": "Fähigkeitsschaden",
	"flawless_rounds": "Runden ohne Schaden gewonnen",
	"multikill_rounds": "Runden mit 3+ Kills",
	"sudden_death_wins": "Siege im Sudden Death",
	"hot_potato_wins": "Siege mit Heißer Kartoffel",
	"zone_wins": "Siege mit Zone",
	"arena_wins": "Siege im Arena-Modus",
	"heroes_match_won": "Helden mit Matchsieg",
	"max_cards_match": "Meiste Karten in einem Match",
}

const HERO_TITLES: Dictionary = {
	"ignis": "Feuerteufel",
	"volt": "Blitzableiter",
	"spore": "Pilzkönig",
	"nova": "Sternenkind",
	"klinge": "Klingenmeister",
	"bastion": "Eiserne Wand",
	"phantom": "Schattenschwein",
	"druid": "Waldhüter",
}
const HERO_ROUND_GOAL: int = 15

# Reihenfolge = Anzeige in der Erfolgsliste.
# id, name, desc, counter, goal, title ("" = kein Titel), unlock ([] oder [Kategorie, ID]).
const ACHIEVEMENTS: Array = [
	{"id": "first_blood", "name": "Erstes Blut", "desc": "Erziele deinen ersten Kill.", "counter": "kills", "goal": 1, "title": "Ersttäter", "unlock": []},
	{"id": "first_win", "name": "Erster Sieg", "desc": "Gewinne ein Match.", "counter": "matches_won", "goal": 1, "title": "Frischling", "unlock": ["tusk", "saber"]},
	{"id": "regular", "name": "Stammgast", "desc": "Spiele 10 Matches zu Ende.", "counter": "matches_played", "goal": 10, "title": "Stammgast", "unlock": ["ears", "bat"]},
	{"id": "rounds_25", "name": "Rundenjäger", "desc": "Gewinne 25 Runden.", "counter": "rounds_won", "goal": 25, "title": "Rundenjäger", "unlock": ["hair", "mohawk"]},
	{"id": "kills_50", "name": "Schweinejäger", "desc": "Erziele 50 Kills.", "counter": "kills", "goal": 50, "title": "Schweinejäger", "unlock": ["tip", "diamond"]},
	{"id": "triple", "name": "Dreifach-Eber", "desc": "Erziele 3 Kills in einer Runde.", "counter": "multikill_rounds", "goal": 1, "title": "Dreifach-Eber", "unlock": []},
	{"id": "flawless", "name": "Unberührbar", "desc": "Gewinne eine Runde, ohne Schaden zu nehmen.", "counter": "flawless_rounds", "goal": 1, "title": "Unberührbar", "unlock": []},
	{"id": "damage_10k", "name": "Feuerwerker", "desc": "Verursache insgesamt 10.000 Schaden.", "counter": "damage_dealt", "goal": 10000, "title": "Feuerwerker", "unlock": ["tail", "bushy"]},
	{"id": "healer", "name": "Feldsanitäter", "desc": "Heile insgesamt 3.000 HP.", "counter": "healing_done", "goal": 3000, "title": "Feldsanitäter", "unlock": ["snout", "heart"]},
	{"id": "blocker", "name": "Bollwerk", "desc": "Blocke 150 Treffer mit der Barriere.", "counter": "blocked_hits", "goal": 150, "title": "Bollwerk", "unlock": ["body", "boar"]},
	{"id": "brawler", "name": "Raufbold", "desc": "Verursache 4.000 Nahkampfschaden.", "counter": "melee_damage", "goal": 4000, "title": "Raufbold", "unlock": ["hair", "mane"]},
	{"id": "ability_fan", "name": "Fähigkeitsfanatiker", "desc": "Verursache 8.000 Schaden mit Heldenfähigkeiten.", "counter": "ability_damage", "goal": 8000, "title": "Fähigkeitsfanatiker", "unlock": ["tip", "spark"]},
	{"id": "potato_king", "name": "Kartoffelkönig", "desc": "Gewinne 3 Runden mit der Heißen Kartoffel.", "counter": "hot_potato_wins", "goal": 3, "title": "Kartoffelkönig", "unlock": []},
	{"id": "zone_runner", "name": "Zonenläufer", "desc": "Gewinne 5 Runden mit schrumpfender Zone.", "counter": "zone_wins", "goal": 5, "title": "Zonenläufer", "unlock": []},
	{"id": "arena_lord", "name": "Arenafürst", "desc": "Gewinne 10 Runden im Arena-Modus.", "counter": "arena_wins", "goal": 10, "title": "Arenafürst", "unlock": []},
	{"id": "nerves", "name": "Nervenstark", "desc": "Gewinne 5 Runden im Sudden Death.", "counter": "sudden_death_wins", "goal": 5, "title": "Nervenstark", "unlock": []},
	{"id": "card_shark", "name": "Kartenhai", "desc": "Halte 12 Karten in einem Match.", "counter": "max_cards_match", "goal": 12, "title": "Kartenhai", "unlock": []},
	{"id": "flawless_10", "name": "Unantastbar", "desc": "Gewinne 10 Runden, ohne Schaden zu nehmen.", "counter": "flawless_rounds", "goal": 10, "title": "Unantastbar", "unlock": ["tusk", "double"]},
	{"id": "winner_10", "name": "Seriensieger", "desc": "Gewinne 10 Matches.", "counter": "matches_won", "goal": 10, "title": "Seriensieger", "unlock": ["top", "robe"]},
	{"id": "kills_250", "name": "Keilerkönig", "desc": "Erziele 250 Kills.", "counter": "kills", "goal": 250, "title": "Keilerkönig", "unlock": ["eyes", "angry"]},
	{"id": "allrounder", "name": "Tausendsassa", "desc": "Gewinne mit jedem Helden mindestens ein Match.", "counter": "heroes_match_won", "goal": 8, "title": "Tausendsassa", "unlock": []},
	{"id": "veteran", "name": "Urgestein", "desc": "Spiele 100 Matches zu Ende.", "counter": "matches_played", "goal": 100, "title": "Urgestein", "unlock": []},
	{"id": "winner_50", "name": "Großmeister", "desc": "Gewinne 50 Matches.", "counter": "matches_won", "goal": 50, "title": "Großmeister des Lötens", "unlock": ["tip", "blaze"]},
	{"id": "kills_1000", "name": "Legende", "desc": "Erziele 1.000 Kills.", "counter": "kills", "goal": 1000, "title": "Legende vom Lötkolben", "unlock": []},
]

# Lebenszeit-Zähler, ids freigeschalteter Erfolge -> Zeitstempel, Rundensiege pro Held.
var counters: Dictionary = {}
var unlocked: Dictionary = {}
var hero_round_wins: Dictionary = {}
var heroes_with_match_win: Array = []
# Gewählter Titel des lokalen Profils (Erfolgs-ID, "" = keiner).
var selected_title: String = ""
# Testschalter im Erfolge-Fenster: alle Teile wählbar, ohne Fortschritt zu ändern.
var unlock_all_cosmetics: bool = false
var enabled: bool = true
var save_path: String = SAVE_PATH

var _round_active: bool = false
var _stats_at_round_start: Array = []
var _round_modifiers: Array = []
var _round_arena: bool = false
var _round_slots: Array[int] = []
var _toast_layer: CanvasLayer = null
var _toast_box: VBoxContainer = null
var _toast_queue: Array = []
var _toast_busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("headless"):
		enabled = false
	for arg in OS.get_cmdline_args():
		if "test_scene" in arg:
			enabled = false
	_build_achievement_defs()
	load_progress()
	call_deferred("apply_local_title")

# Die Heldenerfolge werden aus HERO_TITLES erzeugt, damit neue Helden nur
# einen Titel brauchen.
var _defs: Array = []
var _defs_by_id: Dictionary = {}

func _build_achievement_defs() -> void:
	_defs.clear()
	_defs_by_id.clear()
	for entry in ACHIEVEMENTS:
		_defs.append(entry)
	for hero_id in HERO_TITLES.keys():
		var hero_name := str(hero_id).capitalize()
		if Global.heroes.has(hero_id):
			hero_name = Global.heroes[hero_id].name
		_defs.append({
			"id": "hero_" + str(hero_id),
			"name": "%s-Profi" % hero_name,
			"desc": "Gewinne %d Runden mit %s." % [HERO_ROUND_GOAL, hero_name],
			"counter": "hero_rounds:" + str(hero_id),
			"goal": HERO_ROUND_GOAL,
			"title": HERO_TITLES[hero_id],
			"unlock": [],
			"hero_id": hero_id,
		})
	for entry in _defs:
		_defs_by_id[str(entry["id"])] = entry

func get_achievements() -> Array:
	return _defs

func get_achievement(id: String) -> Dictionary:
	return _defs_by_id.get(id, {})

func is_unlocked(id: String) -> bool:
	return unlocked.has(id)

func get_unlocked_count() -> int:
	var count := 0
	for entry in _defs:
		if unlocked.has(str(entry["id"])):
			count += 1
	return count

func get_counter(counter: String) -> float:
	if counter.begins_with("hero_rounds:"):
		return float(hero_round_wins.get(counter.substr(12), 0))
	if counter == "heroes_match_won":
		return float(heroes_with_match_win.size())
	return float(counters.get(counter, 0))

func get_progress(id: String) -> float:
	var entry := get_achievement(id)
	if entry.is_empty():
		return 0.0
	return minf(get_counter(str(entry["counter"])), float(entry["goal"]))

func get_counter_label(counter: String) -> String:
	if counter.begins_with("hero_rounds:"):
		return "Rundensiege"
	return str(COUNTER_LABELS.get(counter, counter))

# --- Titel ---

## Text eines Titels (Erfolgs-ID) oder "" für keinen/unbekannten Titel.
func get_title_text(title_id: String) -> String:
	var entry := get_achievement(title_id)
	return "" if entry.is_empty() else str(entry.get("title", ""))

## Alle Titel, die das lokale Profil führen darf: [[id, Text], ...].
func get_unlocked_titles() -> Array:
	var list: Array = []
	for entry in _defs:
		var id := str(entry["id"])
		if unlocked.has(id) and not str(entry.get("title", "")).is_empty():
			list.append([id, str(entry["title"])])
	return list

func set_selected_title(title_id: String) -> void:
	if not title_id.is_empty() and (not unlocked.has(title_id) or get_title_text(title_id).is_empty()):
		return
	if selected_title == title_id:
		return
	selected_title = title_id
	save_progress()
	apply_local_title()
	title_changed.emit(Global.local_player_index)

## Schreibt den gewählten Titel in den lokalen Slot und meldet ihn online.
func apply_local_title() -> void:
	var slot := Global.local_player_index
	if slot < 1:
		return
	Global.set_player_title(slot, selected_title)
	if NetworkManager.is_client:
		NetworkManager.request_player_title(selected_title)

# --- Sperren für Aussehen ---

## Erfolg, der ein Teil freischaltet ("" = Teil ist nie gesperrt).
## category: PigModular.PART_OPTIONS-Schlüssel, "tusk" oder "tip".
func get_unlock_source(category: String, option_id: String) -> String:
	for entry in _defs:
		var unlock: Array = entry.get("unlock", [])
		if unlock.size() == 2 and str(unlock[0]) == category and str(unlock[1]) == option_id:
			return str(entry["id"])
	return ""

func is_option_locked(category: String, option_id: String) -> bool:
	if unlock_all_cosmetics:
		return false
	var source := get_unlock_source(category, option_id)
	return not source.is_empty() and not unlocked.has(source)

## Kurzer Hinweis für gesperrte Einträge, z. B. "Erfolg: Bollwerk".
func get_lock_hint(category: String, option_id: String) -> String:
	var entry := get_achievement(get_unlock_source(category, option_id))
	if entry.is_empty():
		return ""
	return "Gesperrt – Erfolg „%s“: %s" % [entry["name"], entry["desc"]]

## Ersetzt gesperrte Teile durch den Standard (z. B. nach ZUFÄLLIG).
func filter_locked_parts(parts: Dictionary) -> Dictionary:
	var clean := parts.duplicate()
	var defaults := PigModular.default_parts()
	for key in PigModular.PART_OPTIONS.keys():
		if is_option_locked(str(key), str(clean.get(key, ""))):
			clean[key] = defaults[key]
	return clean

func set_unlock_all_cosmetics(value: bool) -> void:
	if unlock_all_cosmetics == value:
		return
	unlock_all_cosmetics = value
	save_progress()
	progress_changed.emit()

func get_reward_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = []
	if not str(entry.get("title", "")).is_empty():
		parts.append("Titel „%s“" % entry["title"])
	var unlock: Array = entry.get("unlock", [])
	if unlock.size() == 2:
		parts.append(get_unlock_label(str(unlock[0]), str(unlock[1])))
	return " + ".join(parts)

func get_unlock_label(category: String, option_id: String) -> String:
	match category:
		"tusk":
			return "Hauer „%s“" % Global.get_tusk_shape_label(option_id)
		"tip":
			return "Lötspitze „%s“" % Global.get_wand_tip_shape_label(option_id)
	const CATEGORY_NAMES := {
		"body": "Körperform", "eyes": "Augen", "snout": "Rüssel", "nose": "Nasenlöcher",
		"ears": "Ohren", "hair": "Frisur", "top": "Oberteil", "bottom": "Unterteil", "tail": "Schwanz",
	}
	var label := option_id
	for option in PigModular.PART_OPTIONS.get(category, []):
		if str(option[0]) == option_id:
			label = str(option[1]).get_slice(" – ", 0)
	return "%s „%s“" % [CATEGORY_NAMES.get(category, category), label]

# --- Runden erfassen (Host/Offline) ---

func _is_authoritative() -> bool:
	return not NetworkManager.is_client

func begin_round(modifiers: Array) -> void:
	if not _is_authoritative():
		return
	_round_active = true
	_stats_at_round_start = Global.get_match_stats()
	_round_modifiers = modifiers.duplicate()
	_round_arena = ArenaMode.active
	_round_slots = Global.get_round_player_indices()

## Nach Global.award_round: Rundensieger steht fest. match_winner > 0, wenn
## diese Runde das Match entschieden hat.
func end_round(winner_index: int, death_order: Array, match_winner: int, sudden_death: bool) -> void:
	if not _round_active or not _is_authoritative():
		return
	_round_active = false
	if Global.is_bot_test_active():
		return
	var active: Array[int] = _round_slots if not _round_slots.is_empty() else Global.get_active_player_indices()
	if active.size() < 2:
		return
	var now := Global.get_match_stats()
	var team_mode := Global.is_team_mode()
	for slot in active:
		if not Global.is_human_slot(slot):
			continue
		var won := false
		if winner_index > 0:
			won = Global.get_team_for_slot(slot) == Global.get_team_for_slot(winner_index) if team_mode else slot == winner_index
		var match_won := false
		if match_winner > 0:
			match_won = Global.get_team_for_slot(slot) == Global.get_team_for_slot(match_winner) if team_mode else slot == match_winner
		var summary := {
			"won_round": won,
			"survived": not death_order.has(slot),
			"hero_id": Global.get_player_hero_id(slot),
			"modifiers": _round_modifiers.duplicate(),
			"arena": _round_arena,
			"sudden_death": sudden_death,
			"match_over": match_winner > 0,
			"match_won": match_won,
			"cards_held": Global.get_player_cards(slot).size(),
		}
		var before: Dictionary = _stats_at_round_start[slot - 1] if slot - 1 < _stats_at_round_start.size() else {}
		var after: Dictionary = now[slot - 1] if slot - 1 < now.size() else {}
		for key in ["kills", "deaths", "damage_dealt", "damage_taken", "healing_done", "blocked_hits", "melee_damage", "ability_damage"]:
			summary[key] = maxf(0.0, float(after.get(key, 0.0)) - float(before.get(key, 0.0)))
		_deliver_summary(slot, summary)

func _deliver_summary(slot: int, summary: Dictionary) -> void:
	if slot == Global.local_player_index:
		_apply_summary(summary)
		return
	if not NetworkManager.is_host:
		return
	var peer := NetworkManager.get_peer_for_slot(slot)
	if peer > 1:
		receive_round_summary.rpc_id(peer, summary)

@rpc("authority", "call_remote", "reliable")
func receive_round_summary(summary: Dictionary) -> void:
	if not NetworkManager.is_client:
		return
	_apply_summary(summary)

## Verbucht eine Rundenzusammenfassung im lokalen Profil und prüft Erfolge.
func _apply_summary(summary: Dictionary) -> void:
	if not enabled:
		return
	var won := bool(summary.get("won_round", false))
	_add("rounds_played", 1)
	for key in ["kills", "damage_dealt", "healing_done", "blocked_hits", "melee_damage", "ability_damage"]:
		_add(key, roundi(float(summary.get(key, 0.0))))
	if float(summary.get("kills", 0.0)) >= 3.0:
		_add("multikill_rounds", 1)
	var hero_id := str(summary.get("hero_id", ""))
	var modifiers: Array = summary.get("modifiers", [])
	if won:
		_add("rounds_won", 1)
		if bool(summary.get("survived", false)) and float(summary.get("damage_taken", 0.0)) <= 0.0:
			_add("flawless_rounds", 1)
		if bool(summary.get("sudden_death", false)):
			_add("sudden_death_wins", 1)
		if modifiers.has("hot_potato"):
			_add("hot_potato_wins", 1)
		if modifiers.has("zone"):
			_add("zone_wins", 1)
		if bool(summary.get("arena", false)):
			_add("arena_wins", 1)
		if not hero_id.is_empty():
			hero_round_wins[hero_id] = int(hero_round_wins.get(hero_id, 0)) + 1
	counters["max_cards_match"] = maxi(int(counters.get("max_cards_match", 0)), int(summary.get("cards_held", 0)))
	if bool(summary.get("match_over", false)):
		_add("matches_played", 1)
		if bool(summary.get("match_won", false)):
			_add("matches_won", 1)
			if not hero_id.is_empty() and not heroes_with_match_win.has(hero_id):
				heroes_with_match_win.append(hero_id)
	_check_unlocks()
	save_progress()
	progress_changed.emit()

func _add(counter: String, amount: int) -> void:
	if amount == 0:
		return
	counters[counter] = int(counters.get(counter, 0)) + amount

func _check_unlocks() -> void:
	for entry in _defs:
		var id := str(entry["id"])
		if unlocked.has(id):
			continue
		if get_counter(str(entry["counter"])) >= float(entry["goal"]):
			unlocked[id] = Time.get_datetime_string_from_system(true)
			achievement_unlocked.emit(id)
			_show_toast(entry)

# --- Speichern ---

func save_progress() -> bool:
	if not enabled:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"counters": counters,
		"hero_round_wins": hero_round_wins,
		"heroes_with_match_win": heroes_with_match_win,
		"unlocked": unlocked,
		"selected_title": selected_title,
		"unlock_all_cosmetics": unlock_all_cosmetics,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t", false))
	file.close()
	return true

func load_progress() -> void:
	counters.clear()
	unlocked.clear()
	hero_round_wins.clear()
	heroes_with_match_win.clear()
	selected_title = ""
	unlock_all_cosmetics = false
	if not enabled or not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (parsed is Dictionary):
		return
	var raw_counters: Variant = parsed.get("counters", {})
	if raw_counters is Dictionary:
		for key in raw_counters.keys():
			counters[str(key)] = int(raw_counters[key])
	var raw_heroes: Variant = parsed.get("hero_round_wins", {})
	if raw_heroes is Dictionary:
		for key in raw_heroes.keys():
			hero_round_wins[str(key)] = int(raw_heroes[key])
	var raw_match_heroes: Variant = parsed.get("heroes_with_match_win", [])
	if raw_match_heroes is Array:
		for hero_id in raw_match_heroes:
			if not heroes_with_match_win.has(str(hero_id)):
				heroes_with_match_win.append(str(hero_id))
	var raw_unlocked: Variant = parsed.get("unlocked", {})
	if raw_unlocked is Dictionary:
		for key in raw_unlocked.keys():
			if _defs_by_id.has(str(key)):
				unlocked[str(key)] = str(raw_unlocked[key])
	unlock_all_cosmetics = bool(parsed.get("unlock_all_cosmetics", false))
	var title := str(parsed.get("selected_title", ""))
	selected_title = title if unlocked.has(title) else ""
	# Neue Erfolge mit schon erreichten Zielen still nachtragen.
	for entry in _defs:
		var id := str(entry["id"])
		if not unlocked.has(id) and get_counter(str(entry["counter"])) >= float(entry["goal"]):
			unlocked[id] = Time.get_datetime_string_from_system(true)

## Nur für Tests: Profil leeren, ohne die Datei anzufassen.
func reset_progress_for_tests() -> void:
	counters.clear()
	unlocked.clear()
	hero_round_wins.clear()
	heroes_with_match_win.clear()
	selected_title = ""
	unlock_all_cosmetics = false

# --- Abschnitt für die Profil-Ansicht ---

## Kompakter Block "TITEL & ERFOLGE" für andere Fenster (z. B. das
## Spielerprofil): Titel-Auswahl, Fortschritt, die letzten Freischaltungen und
## ein Knopf zur vollständigen Erfolgsliste.
func build_profile_section() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	box.add_child(top)
	var count := Label.new()
	count.text = "%d / %d Erfolge" % [get_unlocked_count(), _defs.size()]
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count.add_theme_font_size_override("font_size", UiTheme.FS_L)
	count.add_theme_color_override("font_color", UiTheme.GOLD)
	top.add_child(count)
	var title_option := OptionButton.new()
	title_option.custom_minimum_size = Vector2(240, 36)
	var ids: Array[String] = [""]
	title_option.add_item("– kein Titel –")
	for entry in get_unlocked_titles():
		title_option.add_item(str(entry[1]))
		ids.append(str(entry[0]))
	title_option.select(maxi(0, ids.find(selected_title)))
	title_option.item_selected.connect(func(index: int):
		SoundManager.play_sound("click")
		set_selected_title(ids[clampi(index, 0, ids.size() - 1)])
	)
	top.add_child(title_option)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var open_button := Button.new()
	open_button.text = "ALLE ERFOLGE"
	open_button.custom_minimum_size = Vector2(160, 36)
	open_button.pressed.connect(func():
		SoundManager.play_sound("click")
		var screen := AchievementsScreen.new()
		box.get_tree().root.add_child(screen)
		screen.closed.connect(screen.queue_free)
		screen.open_screen()
	)
	top.add_child(open_button)
	# Die drei zuletzt freigeschalteten Erfolge.
	var recent: Array = []
	for id in unlocked.keys():
		recent.append([str(unlocked[id]), str(id)])
	recent.sort()
	recent.reverse()
	for i in range(mini(3, recent.size())):
		box.add_child(AchievementsScreen.build_row(get_achievement(str(recent[i][1]))))
	if recent.is_empty():
		var hint := Label.new()
		hint.text = "Noch keine Erfolge. Spiel ein Match, um die ersten freizuschalten."
		hint.add_theme_font_size_override("font_size", UiTheme.FS_S)
		hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		box.add_child(hint)
	return box

# --- Einblendung "Erfolg freigeschaltet" ---

func _show_toast(entry: Dictionary) -> void:
	if OS.has_feature("headless"):
		return
	_toast_queue.append(entry)
	if not _toast_busy:
		_next_toast()

func _ensure_toast_layer() -> void:
	if _toast_layer != null:
		return
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 60
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.offset_top = 70
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(_toast_box)

func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	_ensure_toast_layer()
	var entry: Dictionary = _toast_queue.pop_front()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.06, 0.04, 0.95), UiTheme.GOLD, 2, 10, 22, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	var head := Label.new()
	head.text = "🏆 ERFOLG FREIGESCHALTET"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", UiTheme.FS_S)
	head.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(head)
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UiTheme.FS_XL)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	column.add_child(name_label)
	var reward := get_reward_text(entry)
	if not reward.is_empty():
		var reward_label := Label.new()
		reward_label.text = "Belohnung: " + reward
		reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_label.add_theme_font_size_override("font_size", UiTheme.FS_S)
		reward_label.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
		column.add_child(reward_label)
	_toast_box.add_child(panel)
	SoundManager.play_sound("coin", 0.0, 0.0)
	# Echtzeit (ignore_time_scale), damit die Kill-Cam-Zeitlupe nicht bremst.
	await get_tree().create_timer(4.0, true, false, true).timeout
	panel.queue_free()
	await get_tree().create_timer(0.25, true, false, true).timeout
	_next_toast()
