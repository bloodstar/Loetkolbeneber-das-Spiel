extends Node

# Detailliertes Runden-Protokoll für spätere Balance-Auswertungen.
#
# Nach jeder Runde wird eine JSON-Zeile an user://round_stats.jsonl angehängt
# (unter Windows: %APPDATA%/Godot/app_userdata/Lötkolbeneber/, vor der Umbenennung BattleBalls). Jede Zeile ist
# ein vollständiges, eigenständiges Objekt; die Datei lässt sich also Zeile für
# Zeile mit Python, Excel/Power Query o. Ä. einlesen. Zeilentypen:
#
# - "round": eine gespielte Runde mit allen Spielern, ihren Karten (inkl.
#   Version, Fingerabdruck und Seltenheit) und den Werten NUR dieser Runde
#   (Kills, Tode, Schaden, Heilung, Blocks, Treffer ...), plus einer
#   Zusammenfassung pro Karte mit ihrem Anteil am Schaden/der Heilung.
# - "draft": ein Kartenangebot an einen Spieler und welche Karten er nahm.
#
# Helden (hero_version, ability_version) und Nahkampfwaffen (melee_version)
# tragen wie Karten eine Version und einen Fingerabdruck (Schema 2).
# Ab Schema 3 enthalten die Spielerwerte "ability_damage" und "ability_share"
# (direkte Treffer der Heldenfähigkeit; Brand/Gift danach zählen nicht).
#
# Nur der Host bzw. ein Offline-Spiel schreibt, weil nur dort Schaden, Kills
# und Rundensieger autoritativ feststehen. Clients schreiben nichts.

const LOG_PATH: String = "user://round_stats.jsonl"
# Bei Änderungen am Zeilenformat erhöhen, damit Auswertungen alte Zeilen
# erkennen können.
const SCHEMA_VERSION: int = 3

var enabled: bool = true
# Überschreibbar für Tests, damit diese niemals die echte Datei berühren.
var log_path: String = LOG_PATH

var match_id: String = ""
var round_number: int = 0
var round_active: bool = false
var round_started_msec: int = 0
var round_info: Dictionary = {}
var round_kills: Array = []
var stats_at_round_start: Array = []
# Wer in dieser Runde spielt (im Stechen nur die Finalisten).
var round_slots: Array[int] = []
# slot -> {card_id: Runde, nach der die Karte gedraftet wurde}
var acquired_round: Dictionary = {}
var _fingerprints: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("headless"):
		enabled = false
	for arg in OS.get_cmdline_args():
		if "test_scene" in arg:
			enabled = false
	Global.match_reset.connect(start_match)

func _is_authoritative() -> bool:
	return enabled and not NetworkManager.is_client

# Neues Match: Rundenzähler und Kartenherkunft zurücksetzen.
func start_match() -> void:
	match_id = "%s-%04x" % [Time.get_datetime_string_from_system(true).replace(":", ""), randi() % 0x10000]
	round_number = 0
	round_active = false
	acquired_round.clear()

# Eine abgebrochene Runde (Neustart, Verbindungsabbruch) wird nie beendet und
# vom nächsten begin_round einfach verworfen.
func begin_round(level_seed: int, map_id: String, modifiers: Array) -> void:
	if not _is_authoritative():
		return
	if match_id.is_empty():
		start_match()
	round_number += 1
	round_active = true
	round_started_msec = Time.get_ticks_msec()
	round_kills.clear()
	stats_at_round_start = Global.get_match_stats()
	round_slots = Global.get_round_player_indices()
	round_info = {
		"seed": level_seed,
		"map_id": map_id,
		"modifiers": modifiers.duplicate(),
		"sudden_death": false,
	}

# Rundendauer ab "GO!" messen, nicht ab Countdown-Beginn.
func mark_fight_started() -> void:
	if round_active:
		round_started_msec = Time.get_ticks_msec()

func mark_sudden_death() -> void:
	if round_active:
		round_info["sudden_death"] = true

func record_kill(killer_index: int, victim_index: int) -> void:
	if not round_active:
		return
	round_kills.append({
		"t": _round_seconds(),
		"killer": killer_index,
		"victim": victim_index,
	})

func end_round(winner_index: int, death_order: Array, match_winner: int = 0) -> void:
	if not round_active or not _is_authoritative():
		return
	round_active = false

	var current_stats := Global.get_match_stats()
	var winner_team := Global.get_team_for_slot(winner_index) if winner_index > 0 else -1
	var team_mode := Global.is_team_mode()
	var active: Array[int] = round_slots if not round_slots.is_empty() else Global.get_active_player_indices()
	# Ohne Überlebende war es ein Doppel-KO (der zuletzt Gestorbene gewinnt).
	var decided_by_survival := false
	for slot in active:
		if not death_order.has(slot):
			decided_by_survival = true

	var round_totals := {"damage_dealt": 0.0, "healing_done": 0.0, "kills": 0.0, "melee_damage": 0.0}
	var player_rows: Array = []
	for slot in active:
		var delta := _stats_delta(slot, current_stats)
		for key in round_totals.keys():
			round_totals[key] = float(round_totals[key]) + float(delta.get(key, 0.0))
		var won := false
		if winner_index > 0:
			won = Global.get_team_for_slot(slot) == winner_team if team_mode else slot == winner_index
		var row := {
			"slot": slot,
			"kind": "bot" if Global.is_bot_slot(slot) else "human",
			"hero_id": Global.get_player_hero_id(slot),
			"melee_weapon": Global.get_melee_weapon(slot),
			"team": Global.get_team_for_slot(slot) if team_mode else 0,
			"won_round": won,
			"survived": not death_order.has(slot),
			"placement": _placement(slot, death_order, active.size()),
			"score_after": Global.player_scores[slot - 1],
			"stats": delta,
			"cards": _card_rows(slot),
		}
		row.merge(_loadout_versions(slot))
		player_rows.append(row)

	for row in player_rows:
		var stats: Dictionary = row["stats"]
		stats["damage_share"] = _ratio(float(stats.get("damage_dealt", 0.0)), float(round_totals["damage_dealt"]))
		stats["healing_share"] = _ratio(float(stats.get("healing_done", 0.0)), float(round_totals["healing_done"]))
		# Anteil am eigenen Schaden, der aus dem Nahkampf kam.
		stats["melee_share"] = _ratio(float(stats.get("melee_damage", 0.0)), float(stats.get("damage_dealt", 0.0)))
		# Anteil am eigenen Schaden aus direkten Treffern der Heldenfähigkeit (ab Schema 3).
		stats["ability_share"] = _ratio(float(stats.get("ability_damage", 0.0)), float(stats.get("damage_dealt", 0.0)))
		stats["accuracy"] = _ratio(float(stats.get("shots_hit", 0.0)), float(stats.get("shots_fired", 0.0)))

	_append_line({
		"type": "round",
		"schema": SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"match_id": match_id,
		"round": round_number,
		"network": "host" if NetworkManager.is_host else "offline",
		"match_mode": Global.match_mode,
		"player_count": active.size(),
		"duration_s": _round_seconds(),
		"map_id": round_info.get("map_id", ""),
		"seed": round_info.get("seed", 0),
		"modifiers": round_info.get("modifiers", []),
		"sudden_death": round_info.get("sudden_death", false),
		"winner": winner_index,
		"decided_by_survival": decided_by_survival,
		"match_over": match_winner > 0,
		"match_winner": match_winner,
		"totals": round_totals,
		"kills": round_kills.duplicate(true),
		"players": player_rows,
		"card_summary": _card_summary(player_rows, round_totals),
	})

# Ein Kartenangebot inklusive gewählter Karten. Wird erst geschrieben, wenn
# der Drafter fertig ist, damit Angebot und Wahl in einer Zeile stehen.
func record_draft(drafter: int, offered: Array, picked: Array) -> void:
	if not _is_authoritative() or offered.is_empty():
		return
	var picked_ids: Array = []
	for value in picked:
		var card := value as CardData
		if card == null:
			continue
		picked_ids.append(card.id)
		if not acquired_round.has(drafter):
			acquired_round[drafter] = {}
		acquired_round[drafter][card.id] = round_number
	var offered_rows: Array = []
	for value in offered:
		var card := value as CardData
		if card == null:
			continue
		var row := _card_info(card)
		row["picked"] = picked_ids.has(card.id)
		offered_rows.append(row)
	_append_line({
		"type": "draft",
		"schema": SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true),
		"match_id": match_id,
		"after_round": round_number,
		"drafter": drafter,
		"kind": "bot" if Global.is_bot_slot(drafter) else "human",
		"hero_id": Global.get_player_hero_id(drafter),
		"hero_version": Global.get_hero(Global.get_player_hero_id(drafter)).version,
		"ability_version": Global.get_hero(Global.get_player_hero_id(drafter)).ability_version,
		"cards_owned_before": Global.get_player_cards(drafter).size() - picked_ids.size(),
		"offered": offered_rows,
	})

func get_log_path() -> String:
	return ProjectSettings.globalize_path(log_path)

# --- intern ---

func _round_seconds() -> float:
	return snappedf(float(Time.get_ticks_msec() - round_started_msec) / 1000.0, 0.01)

func _stats_delta(slot: int, current_stats: Array) -> Dictionary:
	var result := {}
	var now: Dictionary = current_stats[slot - 1] if slot - 1 < current_stats.size() else {}
	var before: Dictionary = {}
	if slot - 1 < stats_at_round_start.size() and stats_at_round_start[slot - 1] is Dictionary:
		before = stats_at_round_start[slot - 1]
	for key in Global.MATCH_STAT_KEYS:
		result[key] = snappedf(float(now.get(key, 0.0)) - float(before.get(key, 0.0)), 0.01)
	return result

# 1 = bester Platz. Überlebende teilen sich Platz 1, danach in umgekehrter
# Todesreihenfolge (zuletzt gestorben = besser).
func _placement(slot: int, death_order: Array, player_count: int) -> int:
	var index := death_order.find(slot)
	if index < 0:
		return 1
	return player_count - index

func _card_info(card: CardData) -> Dictionary:
	if not _fingerprints.has(card.id):
		_fingerprints[card.id] = card.get_balance_fingerprint()
	return {
		"id": card.id,
		"version": card.version,
		"fingerprint": _fingerprints[card.id],
		"rarity": card.rarity,
		"base_rarity": CardStats.get_base_rarity(card.id),
		"pool": card.pool,
		"family_id": card.family_id,
		"branch": card.evolution_branch,
		"hero_id": card.hero_id,
	}

# Versionen und Fingerabdrücke von Held, Heldenfähigkeit und Nahkampfwaffe.
func _loadout_versions(slot: int) -> Dictionary:
	var hero := Global.get_hero(Global.get_player_hero_id(slot))
	var weapon_id := Global.get_melee_weapon(slot)
	var hero_key := "hero:" + hero.id
	if not _fingerprints.has(hero_key):
		_fingerprints[hero_key] = [hero.get_balance_fingerprint(), hero.get_ability_fingerprint()]
	var melee_key := "melee:" + weapon_id
	if not _fingerprints.has(melee_key):
		_fingerprints[melee_key] = Global.get_melee_weapon_fingerprint(weapon_id)
	return {
		"hero_version": hero.version,
		"hero_fingerprint": _fingerprints[hero_key][0],
		"ability_version": hero.ability_version,
		"ability_fingerprint": _fingerprints[hero_key][1],
		"melee_version": Global.get_melee_weapon_version(weapon_id),
		"melee_fingerprint": _fingerprints[melee_key],
	}

func _card_rows(slot: int) -> Array:
	var rows: Array = []
	var origins: Dictionary = acquired_round.get(slot, {})
	for value in Global.get_player_cards(slot):
		var card := value as CardData
		if card == null:
			continue
		var row := _card_info(card)
		row["acquired_after_round"] = int(origins.get(card.id, -1))
		rows.append(row)
	return rows

# Pro Karte (je Version): wer sie hatte und welchen Anteil deren Besitzer an
# Schaden, Heilung und Kills der Runde hatten. Der Schaden wird nicht einzelnen
# Karten zugeordnet, sondern dem ganzen Deck; über viele Runden zeigt der
# Vergleich mit anderen Karten trotzdem, welche Karten Decks stark machen.
func _card_summary(player_rows: Array, round_totals: Dictionary) -> Dictionary:
	var summary: Dictionary = {}
	for row in player_rows:
		var stats: Dictionary = row["stats"]
		for card_row in row["cards"]:
			var key := "%s@v%d" % [card_row["id"], int(card_row["version"])]
			if not summary.has(key):
				summary[key] = {
					"id": card_row["id"],
					"version": card_row["version"],
					"rarity": card_row["rarity"],
					"holders": 0,
					"holders_won": 0,
					"kills": 0.0,
					"deaths": 0.0,
					"damage_dealt": 0.0,
					"damage_taken": 0.0,
					"healing_done": 0.0,
					"damage_blocked": 0.0,
					"melee_damage": 0.0,
				}
			var entry: Dictionary = summary[key]
			entry["holders"] = int(entry["holders"]) + 1
			if row["won_round"]:
				entry["holders_won"] = int(entry["holders_won"]) + 1
			for stat_key in ["kills", "deaths", "damage_dealt", "damage_taken", "healing_done", "damage_blocked", "melee_damage"]:
				entry[stat_key] = float(entry[stat_key]) + float(stats.get(stat_key, 0.0))
	for key in summary.keys():
		var entry: Dictionary = summary[key]
		entry["damage_share"] = _ratio(float(entry["damage_dealt"]), float(round_totals.get("damage_dealt", 0.0)))
		entry["healing_share"] = _ratio(float(entry["healing_done"]), float(round_totals.get("healing_done", 0.0)))
		entry["kill_share"] = _ratio(float(entry["kills"]), float(round_totals.get("kills", 0.0)))
	return summary

func _ratio(numerator: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return snappedf(numerator / denominator, 0.0001)

func _append_line(data: Dictionary) -> void:
	var file: FileAccess
	if FileAccess.file_exists(log_path):
		file = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(log_path, FileAccess.WRITE)
	if file == null:
		push_warning("RoundStats: Protokoll konnte nicht geschrieben werden: %s" % log_path)
		return
	file.store_line(JSON.stringify(data))
	file.close()
