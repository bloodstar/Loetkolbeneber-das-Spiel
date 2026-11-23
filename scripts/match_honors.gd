class_name MatchHonors
extends RefCounted

# MVP-Ehrungen am Matchende.
#
# Während des Matches merkt sich der Host (bzw. das Offline-Spiel) ein paar
# Werte, die Global.match_stats nicht kennt: Kill-Serien, Erstes Blut,
# Tode ohne gegnerischen Schützen, überlebte Runden, knappe Rundensiege und
# pro Runde Schaden und Karten (für "Beste Karte"). Am Matchende wählt
# compute() daraus und aus den Match-Statistiken die Ehrungen.
#
# Online rechnet nur der Host. Die Ehrungen gehen als kleine Liste
# ({"id", "slot", "value", "card"}) mit receive_match_over an die Clients;
# Titel, Texte und Namen baut jeder Rechner selbst (describe()).
#
# Statischer Zustand statt Autoload, damit project.godot unberührt bleibt.

const MAX_HONORS: int = 8
const MAX_FUN_HONORS: int = 2

# Reihenfolge = Priorität bei der Auswahl und Anzeige. "fun" sind die
# Spaß-Ehrungen (Pechvogel & Co.), die am Ende stehen.
const DEFS: Dictionary = {
	"mvp": {"title": "MVP", "icon": "★", "color": Color(1.0, 0.82, 0.30), "flavor": "Bester Gesamtwert des Matches"},
	"damage": {"title": "Schadenskönig", "icon": "✸", "color": Color(1.0, 0.45, 0.30), "flavor": "Meister Schaden"},
	"streak": {"title": "Serienkiller", "icon": "⚡", "color": Color(1.0, 0.62, 0.20), "flavor": "Längste Kill-Serie ohne Tod"},
	"best_card": {"title": "Beste Karte", "icon": "♠", "color": Color(0.75, 0.55, 1.0), "flavor": "Die Karte, die am meisten bewegt hat"},
	"sniper": {"title": "Scharfschütze", "icon": "◎", "color": Color(0.45, 0.90, 1.0), "flavor": "Beste Trefferquote"},
	"first_blood": {"title": "Erstes Blut", "icon": "✚", "color": Color(0.95, 0.25, 0.30), "flavor": "Am häufigsten den ersten Kill der Runde"},
	"ability": {"title": "Fähigkeiten-Ass", "icon": "✦", "color": Color(0.55, 0.75, 1.0), "flavor": "Meister Fähigkeitsschaden"},
	"melee": {"title": "Nahkampf-Metzger", "icon": "⚔", "color": Color(0.95, 0.65, 0.45), "flavor": "Meister Nahkampfschaden"},
	"wall": {"title": "Bollwerk", "icon": "⛨", "color": Color(0.45, 0.70, 1.0), "flavor": "Meister Barriere-Schaden"},
	"medic": {"title": "Sanitäter", "icon": "♥", "color": Color(0.45, 1.0, 0.55), "flavor": "Meiste Heilung"},
	"survivor": {"title": "Überlebenskünstler", "icon": "☘", "color": Color(0.55, 0.95, 0.45), "flavor": "Am häufigsten bis zum Rundenende überlebt"},
	"close_call": {"title": "Haarscharf", "icon": "♡", "color": Color(1.0, 0.55, 0.70), "flavor": "Runde mit dem letzten Rest Leben gewonnen"},
	"unlucky": {"title": "Größter Pechvogel", "icon": "☂", "color": Color(0.70, 0.72, 0.80), "flavor": "Am häufigsten gestorben", "fun": true},
	"clumsy": {"title": "Tollpatsch", "icon": "✖", "color": Color(0.85, 0.70, 0.40), "flavor": "Ohne fremde Hilfe gestorben (Lava, Absturz, eigene Schüsse)", "fun": true},
	"sponge": {"title": "Kugelfang", "icon": "◉", "color": Color(0.70, 0.60, 0.55), "flavor": "Am meisten Schaden eingesteckt", "fun": true},
}

# Mindestwerte, damit niemand für 3 Heilung geehrt wird.
const MIN_VALUES: Dictionary = {
	"damage": 1.0, "streak": 3.0, "first_blood": 2.0, "ability": 100.0,
	"melee": 60.0, "wall": 60.0, "medic": 60.0, "survivor": 2.0,
	"unlucky": 2.0, "clumsy": 1.0, "sponge": 1.0,
}
const SNIPER_MIN_SHOTS: float = 20.0
const SNIPER_MIN_ACCURACY: float = 0.25
const CLOSE_CALL_MAX_RATIO: float = 0.2
const RARITY_RANK: Dictionary = {"Common": 0, "Uncommon": 1, "Rare": 2, "Epic": 3, "Legendary": 4}

static var _streak: Dictionary = {}       # slot -> aktuelle Serie
static var _best_streak: Dictionary = {}  # slot -> längste Serie
static var _first_bloods: Dictionary = {} # slot -> Anzahl
static var _self_deaths: Dictionary = {}  # slot -> Tode ohne gegnerischen Schützen
static var _survived: Dictionary = {}     # slot -> überlebte Runden
static var _close_call: Dictionary = {}   # slot -> niedrigster HP-Anteil bei Rundensieg
static var _rounds: Array = []            # pro Runde {slots, damage{slot}, won{slot}, cards{slot: [ids]}}
static var _round_open: bool = false
static var _round_kills: int = 0
static var _round_damage_start: Dictionary = {}
static var _round_cards: Dictionary = {}
static var _round_slots: Array = []

static var _honors: Array = []
static var _valid: bool = false
static var _received: bool = false

static func reset() -> void:
	_streak.clear()
	_best_streak.clear()
	_first_bloods.clear()
	_self_deaths.clear()
	_survived.clear()
	_close_call.clear()
	_rounds.clear()
	_round_open = false
	_round_kills = 0
	_honors.clear()
	_valid = false
	_received = false

# --- Aufzeichnung (nur Host/offline) ---

static func begin_round(slots: Array) -> void:
	_round_open = true
	_round_kills = 0
	_round_slots = slots.duplicate()
	_round_damage_start.clear()
	_round_cards.clear()
	for value in slots:
		var slot := int(value)
		_round_damage_start[slot] = Global.get_match_stat(slot, "damage_dealt")
		var ids: Array = []
		for card_value in Global.get_player_cards(slot):
			var card := card_value as CardData
			if card != null:
				ids.append(card.id)
		_round_cards[slot] = ids
	_valid = false

# killer 0 = kein gegnerischer Schütze (Umgebung, eigener Schuss, Teamkill).
static func record_death(victim: int, killer: int) -> void:
	if not _round_open:
		return
	_streak[victim] = 0
	if killer <= 0:
		_self_deaths[victim] = int(_self_deaths.get(victim, 0)) + 1
	else:
		var streak := int(_streak.get(killer, 0)) + 1
		_streak[killer] = streak
		_best_streak[killer] = maxi(int(_best_streak.get(killer, 0)), streak)
		if _round_kills == 0:
			_first_bloods[killer] = int(_first_bloods.get(killer, 0)) + 1
		_round_kills += 1
	_valid = false

# survivor_hp: slot -> HP-Anteil (0..1) der Überlebenden bei Rundenende.
static func end_round(winner: int, survivor_hp: Dictionary) -> void:
	if not _round_open:
		return
	_round_open = false
	var damage := {}
	var won := {}
	var winner_team := Global.get_team_for_slot(winner) if winner > 0 else -1
	for value in _round_slots:
		var slot := int(value)
		damage[slot] = maxf(0.0, Global.get_match_stat(slot, "damage_dealt") - float(_round_damage_start.get(slot, 0.0)))
		if winner > 0:
			won[slot] = Global.get_team_for_slot(slot) == winner_team if Global.is_team_mode() else slot == winner
		else:
			won[slot] = false
	for key in survivor_hp.keys():
		var slot := int(key)
		_survived[slot] = int(_survived.get(slot, 0)) + 1
		if bool(won.get(slot, false)):
			var ratio := clampf(float(survivor_hp[key]), 0.0, 1.0)
			_close_call[slot] = minf(float(_close_call.get(slot, 1.0)), ratio)
	_rounds.append({
		"slots": _round_slots.duplicate(),
		"damage": damage,
		"won": won,
		"cards": _round_cards.duplicate(true),
	})
	_valid = false

# --- Ergebnis ---

# Clients übernehmen die Ehrungen des Hosts.
static func set_received(honors: Array) -> void:
	_honors = honors.duplicate(true)
	_valid = true
	_received = true

static func get_honors() -> Array:
	if not _received and not _valid:
		_honors = compute()
		_valid = true
	return _honors.duplicate(true)

static func compute() -> Array:
	var slots: Array[int] = Global.get_active_player_indices()
	if slots.is_empty():
		return []
	var candidates: Array = []
	var mvp := Global.get_match_mvp_index()
	if mvp > 0:
		candidates.append({"id": "mvp", "slot": mvp, "value": float(Global.player_scores[mvp - 1])})

	candidates.append_array(_leader_honor("damage", slots, func(s: int) -> float: return Global.get_match_stat(s, "damage_dealt")))
	candidates.append_array(_leader_honor("streak", slots, func(s: int) -> float: return float(_best_streak.get(s, 0))))
	candidates.append_array(_best_card_honor())
	candidates.append_array(_sniper_honor(slots))
	candidates.append_array(_leader_honor("first_blood", slots, func(s: int) -> float: return float(_first_bloods.get(s, 0))))
	candidates.append_array(_leader_honor("ability", slots, func(s: int) -> float: return Global.get_match_stat(s, "ability_damage")))
	candidates.append_array(_leader_honor("melee", slots, func(s: int) -> float: return Global.get_match_stat(s, "melee_damage")))
	candidates.append_array(_leader_honor("wall", slots, func(s: int) -> float: return Global.get_match_stat(s, "damage_blocked")))
	candidates.append_array(_leader_honor("medic", slots, func(s: int) -> float: return Global.get_match_stat(s, "healing_done")))
	candidates.append_array(_leader_honor("survivor", slots, func(s: int) -> float: return float(_survived.get(s, 0))))
	candidates.append_array(_close_call_honor(slots))
	# Pechvogel: meiste Tode, bei Gleichstand der mit mehr eingestecktem Schaden.
	candidates.append_array(_leader_honor("unlucky", slots, func(s: int) -> float: return Global.get_match_stat(s, "deaths") + minf(Global.get_match_stat(s, "damage_taken"), 99999.0) / 100000.0))
	candidates.append_array(_leader_honor("clumsy", slots, func(s: int) -> float: return float(_self_deaths.get(s, 0))))
	candidates.append_array(_leader_honor("sponge", slots, func(s: int) -> float: return Global.get_match_stat(s, "damage_taken")))
	return _select(candidates, slots.size())

# Wählt höchstens MAX_HONORS Ehrungen und verteilt sie: Pro Spieler nur
# begrenzt viele, damit nicht einer alles abräumt.
static func _select(candidates: Array, player_count: int) -> Array:
	var per_player_cap := maxi(2, ceili(float(MAX_HONORS) / float(maxi(1, player_count))))
	var per_player := {}
	var result: Array = []
	var fun_count := 0
	for honor in candidates:
		var id := str(honor["id"])
		var fun := bool(DEFS[id].get("fun", false))
		if result.size() >= MAX_HONORS:
			break
		if fun and fun_count >= MAX_FUN_HONORS:
			continue
		var slot := int(honor["slot"])
		# Der MVP-Titel zählt nicht gegen die Obergrenze pro Spieler.
		if id != "mvp":
			if int(per_player.get(slot, 0)) >= per_player_cap:
				continue
			per_player[slot] = int(per_player.get(slot, 0)) + 1
		if fun:
			fun_count += 1
		result.append(honor)
	return result

static func _leader_honor(id: String, slots: Array[int], value_of: Callable) -> Array:
	var best_slot := 0
	var best := -INF
	for slot in slots:
		var value := float(value_of.call(slot))
		if value > best:
			best = value
			best_slot = slot
	if best_slot <= 0 or best < float(MIN_VALUES.get(id, 0.0)):
		return []
	return [{"id": id, "slot": best_slot, "value": best}]

static func _sniper_honor(slots: Array[int]) -> Array:
	var best_slot := 0
	var best := 0.0
	for slot in slots:
		var shots := Global.get_match_stat(slot, "shots_fired")
		if shots < SNIPER_MIN_SHOTS:
			continue
		var accuracy := Global.get_match_stat(slot, "shots_hit") / shots
		if accuracy > best:
			best = accuracy
			best_slot = slot
	if best_slot <= 0 or best < SNIPER_MIN_ACCURACY:
		return []
	return [{"id": "sniper", "slot": best_slot, "value": best}]

static func _close_call_honor(slots: Array[int]) -> Array:
	var best_slot := 0
	var best := INF
	for slot in slots:
		if not _close_call.has(slot):
			continue
		var ratio := float(_close_call[slot])
		if ratio < best:
			best = ratio
			best_slot = slot
	if best_slot <= 0 or best > CLOSE_CALL_MAX_RATIO:
		return []
	return [{"id": "close_call", "slot": best_slot, "value": best}]

# Beste Karte: Wie stark war der Besitzer in den Runden mit der Karte?
# Leistung pro Runde = Schadensanteil relativ zum Durchschnitt (1.0 = normal)
# plus 0.5 für einen Rundensieg. Hatte der Besitzer die Karte nicht von
# Anfang an, zählt zusätzlich die Verbesserung gegenüber den Runden davor.
static func _best_card_honor() -> Array:
	if _rounds.is_empty():
		return []
	var impact := {}  # slot -> {round_index: impact}
	for i in range(_rounds.size()):
		var round_data: Dictionary = _rounds[i]
		var slots: Array = round_data["slots"]
		if slots.is_empty():
			continue
		var total := 0.0
		for slot in slots:
			total += float(round_data["damage"].get(slot, 0.0))
		for slot in slots:
			var share := 0.0
			if total > 0.0:
				share = float(round_data["damage"].get(slot, 0.0)) / total * float(slots.size())
			var value := share + (0.5 if bool(round_data["won"].get(slot, false)) else 0.0)
			if not impact.has(slot):
				impact[slot] = {}
			impact[slot][i] = value

	var best: Dictionary = {}
	var best_score := -INF
	for slot in impact.keys():
		var slot_rounds: Dictionary = impact[slot]
		var seen := {}
		for i in slot_rounds.keys():
			var cards: Array = _rounds[i]["cards"].get(slot, [])
			for card_id in cards:
				seen[str(card_id)] = true
		for card_id in seen.keys():
			var with_sum := 0.0
			var with_n := 0
			var without_sum := 0.0
			var without_n := 0
			for i in slot_rounds.keys():
				var cards: Array = _rounds[i]["cards"].get(slot, [])
				if cards.has(card_id):
					with_sum += float(slot_rounds[i])
					with_n += 1
				else:
					without_sum += float(slot_rounds[i])
					without_n += 1
			if with_n == 0:
				continue
			var with_avg := with_sum / float(with_n)
			var gain := 0.0
			if without_n > 0:
				gain = with_avg - without_sum / float(without_n)
			var card := CardDatabase.get_card(card_id)
			var rarity_bonus := float(RARITY_RANK.get(card.rarity if card != null else "", 0)) * 0.02
			var score := with_avg + gain * 0.75 + rarity_bonus
			if score > best_score:
				best_score = score
				best = {"id": "best_card", "slot": int(slot), "value": gain if without_n > 0 else with_avg - 1.0, "card": card_id, "rounds": with_n, "gain": without_n > 0}
	if best.is_empty() or best_score < 1.0:
		return []
	return [best]

# --- Anzeige ---

# Titel, Symbol, Farbe und Werte-Text einer Ehrung (lokal gebaut).
static func describe(honor: Dictionary) -> Dictionary:
	var id := str(honor.get("id", ""))
	var def: Dictionary = DEFS.get(id, {"title": id, "icon": "★", "color": Color.WHITE, "flavor": ""})
	var slot := int(honor.get("slot", 0))
	var value := float(honor.get("value", 0.0))
	var detail := ""
	match id:
		"mvp":
			detail = "%d Punkte · %d Kills · %d Schaden" % [Global.player_scores[slot - 1] if slot > 0 else 0, int(Global.get_match_stat(slot, "kills")), int(Global.get_match_stat(slot, "damage_dealt"))]
		"damage":
			detail = "%d Schaden" % int(value)
		"streak":
			detail = "%d Kills in Folge" % int(value)
		"sniper":
			detail = "%d %% Treffer (%d Schüsse)" % [int(round(value * 100.0)), int(Global.get_match_stat(slot, "shots_fired"))]
		"first_blood":
			detail = "%d× den ersten Kill geholt" % int(value)
		"ability":
			detail = "%d Fähigkeitsschaden" % int(value)
		"melee":
			detail = "%d Schaden mit %s" % [int(value), Global.get_melee_weapon_label(Global.get_melee_weapon(slot))]
		"wall":
			detail = "%d Schaden abgeblockt" % int(value)
		"medic":
			detail = "%d HP geheilt" % int(value)
		"survivor":
			detail = "%d Runden überlebt" % int(value)
		"close_call":
			detail = "Sieg mit %d %% Leben" % maxi(1, int(round(value * 100.0)))
		"unlucky":
			detail = "%d× gestorben" % int(Global.get_match_stat(slot, "deaths"))
		"clumsy":
			detail = "%d× selbst erledigt" % int(value)
		"sponge":
			detail = "%d Schaden eingesteckt" % int(value)
		"best_card":
			var card := CardDatabase.get_card(str(honor.get("card", "")))
			var card_name := card.title if card != null else str(honor.get("card", "?"))
			if bool(honor.get("gain", false)) and value > 0.0:
				detail = "%s · +%d %% Leistung" % [card_name, int(round(value * 100.0))]
			else:
				detail = "%s · %d Runden im Deck" % [card_name, int(honor.get("rounds", 1))]
	return {
		"title": str(def["title"]),
		"icon": str(def["icon"]),
		"color": def["color"],
		"flavor": str(def.get("flavor", "")),
		"detail": detail,
		"fun": bool(def.get("fun", false)),
	}
