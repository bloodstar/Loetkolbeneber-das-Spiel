class_name BalanceReport
extends RefCounted

# Balance-Auswertung des Runden-Protokolls (user://round_stats.jsonl) im Spiel.
#
# Rechnet genauso wie tools/analyze_round_stats.py: pro Karte und Version
# (z. B. "heavy_bullets@v2") Siegquote, Kills, Tode, Schadens-/Heilanteil,
# Nahkampfschaden und Pickrate, verglichen mit allen anderen Karten derselben
# Seltenheit. Karten, die deutlich besser abschneiden, bekommen einen
# Vorschlag für die nächsthöhere Seltenheit. Dazu je eine Tabelle pro
# Nahkampfwaffe ("hammer@v2") und Held ("nova@v1/a2"). Zeilen ohne
# Versionsangabe zählen als Version 1. Fähigkeitsschaden gibt es erst ab
# Schema 3; Helden-Zeilen mitteln ihn nur über Runden, die ihn enthalten.
#
# Wer die Rechnung ändert, sollte das Python-Skript mitziehen, damit beide
# Auswertungen dieselben Zahlen liefern.

const RARITY_ORDER: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const PROMOTION_GAP: float = 0.10
const DEFAULT_MIN_ROUNDS: int = 20

var round_count: int = 0
var draft_count: int = 0
# Zeilen-Dictionaries für die Tabellen (Schlüssel siehe _analyze_*).
var cards: Array = []
var weapons: Array = []
var heroes: Array = []
# Einträge, deren Werte sich ohne neue Version geändert haben.
var fingerprint_warnings: Array[String] = []

var _card_acc: Dictionary = {}
var _weapon_acc: Dictionary = {}
var _hero_acc: Dictionary = {}

# Liest alle Zeilen des Protokolls. Kaputte Zeilen (z. B. eine gerade halb
# geschriebene letzte Zeile) werden gezählt und übersprungen.
static func read_lines(file_path: String) -> Dictionary:
	var result := {"lines": [], "invalid": 0, "error": ""}
	if not FileAccess.file_exists(file_path):
		result["error"] = "Noch kein Protokoll vorhanden. Es entsteht nach der ersten fertig gespielten Runde (offline oder als Host)."
		return result
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		result["error"] = "Protokoll konnte nicht gelesen werden (%s)." % error_string(FileAccess.get_open_error())
		return result
	var json := JSON.new()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		if json.parse(line) == OK and json.data is Dictionary:
			result["lines"].append(json.data)
		else:
			result["invalid"] = int(result["invalid"]) + 1
	file.close()
	return result

static func build(lines: Array, humans_only: bool, min_rounds: int) -> BalanceReport:
	var report := BalanceReport.new()
	report._collect(lines, humans_only)
	report._analyze_cards(min_rounds)
	report._analyze_weapons()
	report._analyze_heroes()
	report._collect_warnings()
	return report

# Laplace-Glättung, damit wenige Runden keine 0 % / 100 % erzeugen.
static func smoothed_rate(wins: int, rounds: int) -> float:
	return float(wins + 2) / float(rounds + 4)

func get_suggestions() -> Array:
	var result: Array = []
	for row in cards:
		if not str(row["suggestion"]).is_empty():
			result.append(row)
	return result

# --- Sammeln ---

func _collect(lines: Array, humans_only: bool) -> void:
	for raw in lines:
		var data: Dictionary = raw
		var kind := str(data.get("type", ""))
		if kind == "round":
			round_count += 1
			var players: Variant = data.get("players", [])
			if not (players is Array):
				continue
			for raw_player in players:
				if raw_player is Dictionary:
					_collect_player(raw_player, humans_only)
		elif kind == "draft":
			draft_count += 1
			if humans_only and str(data.get("kind", "")) == "bot":
				continue
			var offered: Variant = data.get("offered", [])
			if not (offered is Array):
				continue
			for raw_card in offered:
				if not (raw_card is Dictionary):
					continue
				var card: Dictionary = raw_card
				var entry := _card_entry(card)
				if str(entry["rarity"]).is_empty():
					entry["rarity"] = str(card.get("rarity", ""))
				entry["offers"] = int(entry["offers"]) + 1
				if bool(card.get("picked", false)):
					entry["picks"] = int(entry["picks"]) + 1
				_add_fingerprint(entry, str(card.get("fingerprint", "")))

func _collect_player(player: Dictionary, humans_only: bool) -> void:
	if humans_only and str(player.get("kind", "")) == "bot":
		return
	var stats: Dictionary = player.get("stats", {}) if player.get("stats", {}) is Dictionary else {}
	var won := bool(player.get("won_round", false))
	var win_count := 1 if won else 0

	# Ältere Protokolle kennen noch keine Nahkampfwaffe.
	var weapon_id := _text(player.get("melee_weapon", ""))
	if not weapon_id.is_empty():
		var version := _version(player, "melee_version")
		var key := "%s@v%d" % [weapon_id, version]
		if not _weapon_acc.has(key):
			_weapon_acc[key] = {
				"key": key, "id": weapon_id, "version": version,
				"rounds": 0, "wins": 0, "melee_damage": 0.0, "melee_share": 0.0, "kills": 0.0,
				"fingerprints": {},
			}
		var weapon: Dictionary = _weapon_acc[key]
		_add_fingerprint(weapon, _text(player.get("melee_fingerprint", "")))
		weapon["rounds"] = int(weapon["rounds"]) + 1
		weapon["wins"] = int(weapon["wins"]) + win_count
		weapon["melee_damage"] = float(weapon["melee_damage"]) + _num(stats, "melee_damage")
		weapon["melee_share"] = float(weapon["melee_share"]) + _num(stats, "melee_share")
		weapon["kills"] = float(weapon["kills"]) + _num(stats, "kills")

	var hero_id := _text(player.get("hero_id", ""))
	if not hero_id.is_empty():
		var hero_version := _version(player, "hero_version")
		var ability_version := _version(player, "ability_version")
		var key := "%s@v%d/a%d" % [hero_id, hero_version, ability_version]
		if not _hero_acc.has(key):
			_hero_acc[key] = {
				"key": key, "id": hero_id, "version": hero_version, "ability_version": ability_version,
				"rounds": 0, "wins": 0, "kills": 0.0, "deaths": 0.0,
				"damage_share": 0.0, "healing_share": 0.0, "fingerprints": {},
				"ability_rounds": 0, "ability_damage": 0.0, "ability_share": 0.0,
			}
		var hero: Dictionary = _hero_acc[key]
		hero["rounds"] = int(hero["rounds"]) + 1
		hero["wins"] = int(hero["wins"]) + win_count
		hero["kills"] = float(hero["kills"]) + _num(stats, "kills")
		hero["deaths"] = float(hero["deaths"]) + _num(stats, "deaths")
		hero["damage_share"] = float(hero["damage_share"]) + _num(stats, "damage_share")
		hero["healing_share"] = float(hero["healing_share"]) + _num(stats, "healing_share")
		if stats.has("ability_damage"):
			hero["ability_rounds"] = int(hero["ability_rounds"]) + 1
			hero["ability_damage"] = float(hero["ability_damage"]) + _num(stats, "ability_damage")
			hero["ability_share"] = float(hero["ability_share"]) + _num(stats, "ability_share")
		var hero_fingerprint := _text(player.get("hero_fingerprint", ""))
		if not hero_fingerprint.is_empty():
			_add_fingerprint(hero, "%s/%s" % [hero_fingerprint, _text(player.get("ability_fingerprint", ""))])

	var owned: Variant = player.get("cards", [])
	if not (owned is Array):
		return
	for raw_card in owned:
		if not (raw_card is Dictionary):
			continue
		var card: Dictionary = raw_card
		var entry := _card_entry(card)
		entry["rarity"] = _text(card.get("rarity", entry["rarity"]))
		entry["rounds"] = int(entry["rounds"]) + 1
		entry["wins"] = int(entry["wins"]) + win_count
		entry["kills"] = float(entry["kills"]) + _num(stats, "kills")
		entry["deaths"] = float(entry["deaths"]) + _num(stats, "deaths")
		entry["damage_share"] = float(entry["damage_share"]) + _num(stats, "damage_share")
		entry["healing_share"] = float(entry["healing_share"]) + _num(stats, "healing_share")
		entry["melee_damage"] = float(entry["melee_damage"]) + _num(stats, "melee_damage")
		_add_fingerprint(entry, _text(card.get("fingerprint", "")))

func _card_entry(card: Dictionary) -> Dictionary:
	var card_id := _text(card.get("id", "?"))
	if card_id.is_empty():
		card_id = "?"
	var version := _version(card, "version")
	var key := "%s@v%d" % [card_id, version]
	if not _card_acc.has(key):
		_card_acc[key] = {
			"key": key, "id": card_id, "version": version, "rarity": "",
			"rounds": 0, "wins": 0, "kills": 0.0, "deaths": 0.0,
			"damage_share": 0.0, "healing_share": 0.0, "melee_damage": 0.0,
			"fingerprints": {}, "offers": 0, "picks": 0,
		}
	return _card_acc[key]

# --- Auswerten ---

func _analyze_cards(min_rounds: int) -> void:
	var rarity_totals: Dictionary = {}
	for entry in _card_acc.values():
		var rarity := str(entry["rarity"])
		if not rarity_totals.has(rarity):
			rarity_totals[rarity] = {"wins": 0, "rounds": 0}
		rarity_totals[rarity]["wins"] = int(rarity_totals[rarity]["wins"]) + int(entry["wins"])
		rarity_totals[rarity]["rounds"] = int(rarity_totals[rarity]["rounds"]) + int(entry["rounds"])

	cards.clear()
	for entry in _card_acc.values():
		var rarity := str(entry["rarity"])
		var rounds := int(entry["rounds"])
		var wins := int(entry["wins"])
		var totals: Dictionary = rarity_totals[rarity]
		var peer_wins := int(totals["wins"]) - wins
		var peer_rounds := int(totals["rounds"]) - rounds
		var win_rate := smoothed_rate(wins, rounds)
		var peer_rate := 0.0
		var gap := 0.0
		if peer_rounds > 0:
			peer_rate = smoothed_rate(peer_wins, peer_rounds)
			gap = win_rate - peer_rate
		var suggestion := ""
		if rounds >= min_rounds and peer_rounds >= min_rounds and gap >= PROMOTION_GAP \
				and RARITY_ORDER.has(rarity) and rarity != "Legendary":
			suggestion = RARITY_ORDER[RARITY_ORDER.find(rarity) + 1]
		var per_round := float(maxi(rounds, 1))
		var offers := int(entry["offers"])
		var card_data: CardData = CardDatabase.get_card(str(entry["id"]))
		cards.append({
			"key": entry["key"],
			"id": entry["id"],
			"version": entry["version"],
			"name": card_data.title if card_data != null else str(entry["id"]),
			"current": card_data != null and card_data.version == int(entry["version"]),
			"rarity": rarity,
			"rounds": rounds,
			"wins": wins,
			"win_rate": win_rate,
			"peer_rate": peer_rate,
			"gap": gap,
			"kills_per_round": float(entry["kills"]) / per_round,
			"deaths_per_round": float(entry["deaths"]) / per_round,
			"damage_share": float(entry["damage_share"]) / per_round,
			"healing_share": float(entry["healing_share"]) / per_round,
			"melee_per_round": float(entry["melee_damage"]) / per_round,
			"offers": offers,
			"picks": int(entry["picks"]),
			"pick_rate": float(entry["picks"]) / float(offers) if offers > 0 else 0.0,
			"fingerprints": (entry["fingerprints"] as Dictionary).size(),
			"suggestion": suggestion,
		})
	# Wie im Skript: Vorschläge zuerst, dann nach Abstand zur Seltenheitsgruppe.
	cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_plain := str(a["suggestion"]).is_empty()
		var b_plain := str(b["suggestion"]).is_empty()
		if a_plain != b_plain:
			return b_plain
		if not is_equal_approx(float(a["gap"]), float(b["gap"])):
			return float(a["gap"]) > float(b["gap"])
		return str(a["key"]) < str(b["key"])
	)

func _analyze_weapons() -> void:
	weapons.clear()
	for entry in _weapon_acc.values():
		var weapon_id := str(entry["id"])
		var rounds := int(entry["rounds"])
		var per_round := float(maxi(rounds, 1))
		var known := Global.MELEE_WEAPON_DATA.has(weapon_id)
		weapons.append({
			"key": entry["key"],
			"id": weapon_id,
			"version": entry["version"],
			"name": Global.get_melee_weapon_label(weapon_id) if known else weapon_id,
			"current": known and Global.get_melee_weapon_version(weapon_id) == int(entry["version"]),
			"rounds": rounds,
			"wins": int(entry["wins"]),
			"win_rate": smoothed_rate(int(entry["wins"]), rounds),
			"melee_per_round": float(entry["melee_damage"]) / per_round,
			"melee_share": float(entry["melee_share"]) / per_round,
			"kills_per_round": float(entry["kills"]) / per_round,
			"fingerprints": (entry["fingerprints"] as Dictionary).size(),
		})
	weapons.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["key"]) < str(b["key"]))

func _analyze_heroes() -> void:
	heroes.clear()
	for entry in _hero_acc.values():
		var hero_id := str(entry["id"])
		var rounds := int(entry["rounds"])
		var per_round := float(maxi(rounds, 1))
		var hero: HeroData = Global.heroes.get(hero_id, null)
		heroes.append({
			"key": entry["key"],
			"id": hero_id,
			"version": entry["version"],
			"ability_version": entry["ability_version"],
			"name": hero.name if hero != null else hero_id,
			"current": hero != null and hero.version == int(entry["version"]) \
				and hero.ability_version == int(entry["ability_version"]),
			"rounds": rounds,
			"wins": int(entry["wins"]),
			"win_rate": smoothed_rate(int(entry["wins"]), rounds),
			"kills_per_round": float(entry["kills"]) / per_round,
			"deaths_per_round": float(entry["deaths"]) / per_round,
			"damage_share": float(entry["damage_share"]) / per_round,
			"healing_share": float(entry["healing_share"]) / per_round,
			"ability_rounds": int(entry["ability_rounds"]),
			"ability_per_round": float(entry["ability_damage"]) / float(maxi(int(entry["ability_rounds"]), 1)),
			"ability_share": float(entry["ability_share"]) / float(maxi(int(entry["ability_rounds"]), 1)),
			"fingerprints": (entry["fingerprints"] as Dictionary).size(),
		})
	heroes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["key"]) < str(b["key"]))

func _collect_warnings() -> void:
	fingerprint_warnings.clear()
	var keys: Array[String] = []
	for row in cards:
		if int(row["fingerprints"]) > 1:
			keys.append(str(row["key"]))
	var others: Array[String] = []
	for row in weapons + heroes:
		if int(row["fingerprints"]) > 1:
			others.append(str(row["key"]))
	others.sort()
	keys.append_array(others)
	fingerprint_warnings = keys

# --- Helfer ---

func _add_fingerprint(entry: Dictionary, fingerprint: String) -> void:
	if not fingerprint.is_empty():
		(entry["fingerprints"] as Dictionary)[fingerprint] = true

static func _num(source: Dictionary, key: String) -> float:
	var value: Variant = source.get(key, 0.0)
	if value is float or value is int:
		return float(value)
	return 0.0

# JSON liefert Zahlen als float; fehlende Versionen zählen als 1.
static func _version(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key, 1)
	if value is float or value is int:
		return int(value)
	return 1

static func _text(value: Variant) -> String:
	return "" if value == null else str(value)
