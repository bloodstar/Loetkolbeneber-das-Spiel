extends Node

# Persistente Hintergrund-Statistik pro Karte.
#
# Das Dokument liegt unter user://card_statistics.json und wird nach jedem
# Match aktualisiert. Es speichert Rohzähler und daraus abgeleitete Raten:
# - offers/picks -> pick_rate (wie oft eine angebotene Karte gewählt wurde)
# - kills -> kill_rate (Kills pro Match, in dem die Karte im Deck lag)
# - matches/wins -> win_rate (Match-Siege pro Deck-Teilnahme)
#
# Zusätzlich werden Karten derselben Seltenheit verglichen. Liegt die
# geglättete Winrate einer Karte deutlich über dem Durchschnitt ihrer
# Seltenheitsgruppe, steigt sie eine Stufe auf. Aufwertungen werden als
# Overrides gespeichert und beim Start auf die CardData-Ressourcen angewendet.

signal statistics_changed()
signal rarity_changed()

const CARD_STATS_PATH: String = "user://card_statistics.json"
const DOCUMENT_VERSION: int = 1
const MAX_PROMOTION_LOG: int = 100

# Auswertung: früh genug für regelmäßige Anpassungen, aber mit genug Daten,
# damit einzelne Ausreißer keine Kettenreaktion auslösen.
const EVALUATION_INTERVAL_MATCHES: int = 3
const MIN_CARD_MATCHES: int = 8
const MIN_PEER_MATCHES: int = 6
const PROMOTION_COOLDOWN_MATCHES: int = 8
const PROMOTION_WINRATE_GAP: float = 0.15
const PROMOTION_MIN_WINRATE: float = 0.55
const WINRATE_PRIOR_STRENGTH: float = 4.0
const WINRATE_PRIOR_MEAN: float = 0.5

var persistence_enabled: bool = true
var auto_evaluation_enabled: bool = true
# Überschreibbar für Tests, damit diese niemals die echte Statistikdatei berühren.
var storage_path: String = CARD_STATS_PATH

var statistics: Dictionary = {}
var rarity_overrides: Dictionary = {}
var promotion_log: Array = []
var matches: int = 0
var last_evaluated_match: int = 0
var base_rarities: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automatisierte Testläufe dürfen die echte Statistikdatei weder verändern
	# noch Karten dauerhaft aufwerten.
	if _is_automated_test_run():
		persistence_enabled = false
		auto_evaluation_enabled = false
	_snapshot_base_rarities()
	_load_document()
	apply_rarity_overrides()
	if auto_evaluation_enabled:
		evaluate_rarity()
	# Beim ersten Start direkt ein vollständiges Dokument mit allen Karten anlegen.
	if persistence_enabled and not FileAccess.file_exists(storage_path):
		_save_document()

func _is_automated_test_run() -> bool:
	if OS.has_feature("headless"):
		return true
	for arg in OS.get_cmdline_args():
		if "test_scene" in arg:
			return true
	return false

func _snapshot_base_rarities() -> void:
	base_rarities.clear()
	for card in CardDatabase.all_cards:
		base_rarities[card.id] = card.rarity

func _empty_card_stats() -> Dictionary:
	return {
		"offers": 0,
		"picks": 0,
		"kills": 0,
		"matches": 0,
		"wins": 0,
		"promotions": 0,
		"last_promotion_match": 0,
	}

func _entry(card_id: String) -> Dictionary:
	if card_id.is_empty() or CardDatabase.get_card(card_id) == null:
		return {}
	if not statistics.has(card_id):
		statistics[card_id] = _empty_card_stats()
	return statistics[card_id]

func record_offer(cards: Array) -> void:
	var changed := false
	var seen: Dictionary = {}
	for value in cards:
		var card := value as CardData
		if card == null or seen.has(card.id):
			continue
		seen[card.id] = true
		var entry := _entry(card.id)
		if entry.is_empty():
			continue
		entry["offers"] = int(entry.get("offers", 0)) + 1
		statistics[card.id] = entry
		changed = true
	if changed:
		statistics_changed.emit()

func record_pick(card_id: String) -> void:
	var entry := _entry(card_id)
	if entry.is_empty():
		return
	entry["picks"] = int(entry.get("picks", 0)) + 1
	statistics[card_id] = entry
	statistics_changed.emit()

# Ein Kill wird allen Karten im Deck des Schützen gutgeschrieben. Damit misst
# die Killrate die Leistung von Decks, in denen die Karte tatsächlich lag.
func record_kill(killer_index: int) -> void:
	var cards := Global.get_player_cards(killer_index)
	if cards.is_empty():
		return
	var changed := false
	for value in cards:
		var card := value as CardData
		if card == null:
			continue
		var entry := _entry(card.id)
		if entry.is_empty():
			continue
		entry["kills"] = int(entry.get("kills", 0)) + 1
		statistics[card.id] = entry
		changed = true
	if changed:
		statistics_changed.emit()

# Netzwerk-Clients erhalten keine lokalen Todesereignisse. Beim Match-Ende
# werden die autoritativen Kill-Zähler des Hosts auf die eigenen Decks verteilt.
func record_kill_totals(match_stats: Array) -> void:
	var changed := false
	for slot in Global.get_active_player_indices():
		var stat_index := slot - 1
		if stat_index < 0 or stat_index >= match_stats.size():
			continue
		var stats_value: Variant = match_stats[stat_index]
		if not (stats_value is Dictionary):
			continue
		var kills := int(float(stats_value.get("kills", 0.0)))
		if kills <= 0:
			continue
		for value in Global.get_player_cards(slot):
			var card := value as CardData
			if card == null:
				continue
			var entry := _entry(card.id)
			if entry.is_empty():
				continue
			entry["kills"] = int(entry.get("kills", 0)) + kills
			statistics[card.id] = entry
			changed = true
	if changed:
		statistics_changed.emit()

# Ein Match-Sample entsteht für jede Karte, die am Match-Ende im Deck eines
# aktiven Spielers lag. Der Gewinner (bzw. das Gewinnerteam) erzeugt Wins.
func record_match(winner_index: int) -> void:
	matches += 1
	var winner_team := -1
	if winner_index >= 1 and winner_index <= Global.MAX_PLAYERS:
		winner_team = Global.get_team_for_slot(winner_index)

	for slot in Global.get_active_player_indices():
		var cards := Global.get_player_cards(slot)
		if cards.is_empty():
			continue
		var won := false
		if winner_index >= 1:
			if Global.is_team_mode():
				won = Global.get_team_for_slot(slot) == winner_team
			else:
				won = slot == winner_index
		for value in cards:
			var card := value as CardData
			if card == null:
				continue
			var entry := _entry(card.id)
			if entry.is_empty():
				continue
			entry["matches"] = int(entry.get("matches", 0)) + 1
			if won:
				entry["wins"] = int(entry.get("wins", 0)) + 1
			statistics[card.id] = entry

	statistics_changed.emit()
	if auto_evaluation_enabled and matches - last_evaluated_match >= EVALUATION_INTERVAL_MATCHES:
		evaluate_rarity()
	_save_document()

# Vergleicht Karten innerhalb ihrer aktuellen Seltenheit. Pro Seltenheit wird
# höchstens die Karte mit dem größten Winrate-Vorsprung eine Stufe angehoben.
# Das verhindert, dass eine einzelne Auswertung viele Karten gleichzeitig verschiebt.
func evaluate_rarity(force_evaluation: bool = false) -> Array:
	if matches <= 0:
		return []
	if not force_evaluation and matches - last_evaluated_match < EVALUATION_INTERVAL_MATCHES:
		return []

	last_evaluated_match = matches
	var groups: Dictionary = {}
	for card in CardDatabase.all_cards:
		if not statistics.has(card.id):
			continue
		var entry: Dictionary = statistics[card.id]
		if int(entry.get("matches", 0)) <= 0:
			continue
		if not groups.has(card.rarity):
			groups[card.rarity] = []
		groups[card.rarity].append(card)

	var promotions: Array = []
	for rarity in Global.RARITY_ORDER:
		if rarity == "Legendary" or not groups.has(rarity):
			continue
		var next_rarity := _next_rarity(rarity)
		if next_rarity.is_empty():
			continue
		var best_card: CardData = null
		var best_excess := 0.0
		var best_rate := 0.0
		var best_peer_rate := 0.0

		for value in groups[rarity]:
			var card := value as CardData
			if card == null:
				continue
			var entry: Dictionary = statistics.get(card.id, {})
			var card_matches := int(entry.get("matches", 0))
			if card_matches < MIN_CARD_MATCHES:
				continue
			if matches - int(entry.get("last_promotion_match", 0)) < PROMOTION_COOLDOWN_MATCHES:
				continue

			var card_wins := int(entry.get("wins", 0))
			var card_rate := _smoothed_win_rate(card_wins, card_matches)
			if card_rate < PROMOTION_MIN_WINRATE:
				continue

			var peer_wins := 0
			var peer_matches := 0
			for peer_value in groups[rarity]:
				var peer := peer_value as CardData
				if peer == null or peer.id == card.id:
					continue
				var peer_entry: Dictionary = statistics.get(peer.id, {})
				var peer_match_count := int(peer_entry.get("matches", 0))
				if peer_match_count < MIN_PEER_MATCHES:
					continue
				peer_matches += peer_match_count
				peer_wins += int(peer_entry.get("wins", 0))
			if peer_matches < MIN_PEER_MATCHES:
				continue

			var peer_rate := _smoothed_win_rate(peer_wins, peer_matches)
			var excess := card_rate - peer_rate
			if excess < PROMOTION_WINRATE_GAP:
				continue
			if excess > best_excess:
				best_excess = excess
				best_card = card
				best_rate = card_rate
				best_peer_rate = peer_rate

		if best_card != null:
			var old_rarity := best_card.rarity
			rarity_overrides[best_card.id] = next_rarity
			best_card.rarity = next_rarity
			var entry: Dictionary = statistics.get(best_card.id, _empty_card_stats())
			entry["promotions"] = int(entry.get("promotions", 0)) + 1
			entry["last_promotion_match"] = matches
			statistics[best_card.id] = entry
			promotions.append({
				"card_id": best_card.id,
				"title": best_card.title,
				"from": old_rarity,
				"to": next_rarity,
				"at_match": matches,
				"win_rate": best_rate,
				"peer_win_rate": best_peer_rate,
				"excess": best_excess,
			})
			_append_promotion_log(promotions[promotions.size() - 1])

	if not promotions.is_empty():
		rarity_changed.emit()
		_save_document()
	return promotions

func _append_promotion_log(entry: Dictionary) -> void:
	promotion_log.append(entry.duplicate(true))
	while promotion_log.size() > MAX_PROMOTION_LOG:
		promotion_log.pop_front()

func _next_rarity(rarity: String) -> String:
	var index := Global.RARITY_ORDER.find(rarity)
	if index < 0 or index >= Global.RARITY_ORDER.size() - 1:
		return ""
	return Global.RARITY_ORDER[index + 1]

func _smoothed_win_rate(wins: int, match_count: int) -> float:
	if match_count <= 0:
		return 0.0
	return (float(wins) + WINRATE_PRIOR_MEAN * WINRATE_PRIOR_STRENGTH) \
		/ (float(match_count) + WINRATE_PRIOR_STRENGTH)

func _ratio(numerator: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return numerator / denominator

func get_card_stats(card_id: String) -> Dictionary:
	var entry: Dictionary = statistics.get(card_id, _empty_card_stats()).duplicate(true)
	var match_count := int(entry.get("matches", 0))
	var offers := int(entry.get("offers", 0))
	entry["kill_rate"] = _ratio(float(entry.get("kills", 0)), float(match_count))
	entry["win_rate"] = _ratio(float(entry.get("wins", 0)), float(match_count))
	entry["pick_rate"] = _ratio(float(entry.get("picks", 0)), float(offers))
	return entry

func get_win_rate(card_id: String) -> float:
	return float(get_card_stats(card_id).get("win_rate", 0.0))

func get_pick_rate(card_id: String) -> float:
	return float(get_card_stats(card_id).get("pick_rate", 0.0))

func get_kill_rate(card_id: String) -> float:
	return float(get_card_stats(card_id).get("kill_rate", 0.0))

func get_matches() -> int:
	return matches

func get_rarity_override(card_id: String) -> String:
	return str(rarity_overrides.get(card_id, ""))

func get_base_rarity(card_id: String) -> String:
	return str(base_rarities.get(card_id, ""))

func get_promotion_log() -> Array:
	return promotion_log.duplicate(true)

func get_document_path() -> String:
	return storage_path

func get_statistics_document() -> Dictionary:
	return _build_document()

# Stellt alle Karten auf ihre Ausgangsseltenheit zurück. Wird u. a. von
# automatisierten Tests genutzt, damit Testdaten die echte Datei nicht verändern.
func reset_statistics(clear_overrides: bool = true) -> void:
	statistics.clear()
	promotion_log.clear()
	matches = 0
	last_evaluated_match = 0
	if clear_overrides:
		rarity_overrides.clear()
	apply_rarity_overrides()
	statistics_changed.emit()
	if persistence_enabled:
		_save_document()

func set_persistence_enabled(enabled: bool) -> void:
	persistence_enabled = enabled

func save_statistics() -> void:
	_save_document()

# Liest die aktuelle Datei neu ein. Nützlich für Tests und zum manuellen
# Nachladen, ohne das Spiel neu zu starten.
func reload_from_disk() -> void:
	statistics.clear()
	rarity_overrides.clear()
	promotion_log.clear()
	matches = 0
	last_evaluated_match = 0
	_load_document()
	apply_rarity_overrides()
	statistics_changed.emit()

func apply_rarity_overrides() -> void:
	var changed := false
	for card in CardDatabase.all_cards:
		var base_rarity := str(base_rarities.get(card.id, card.rarity))
		var target := str(rarity_overrides.get(card.id, base_rarity))
		if not Global.RARITY_ORDER.has(target):
			target = base_rarity
		var base_index := Global.RARITY_ORDER.find(base_rarity)
		var target_index := Global.RARITY_ORDER.find(target)
		if base_index < 0 or target_index < base_index:
			target = base_rarity
		if card.rarity != target:
			card.rarity = target
			changed = true
	if changed:
		rarity_changed.emit()

func _build_document() -> Dictionary:
	var card_documents: Dictionary = {}
	for card in CardDatabase.all_cards:
		var card_id := card.id
		var entry: Dictionary = statistics.get(card_id, _empty_card_stats())
		var match_count := int(entry.get("matches", 0))
		var offers := int(entry.get("offers", 0))
		card_documents[card_id] = {
			"title": card.title,
			"rarity": card.rarity,
			"base_rarity": get_base_rarity(card_id),
			"offers": offers,
			"picks": int(entry.get("picks", 0)),
			"kills": int(entry.get("kills", 0)),
			"matches": match_count,
			"wins": int(entry.get("wins", 0)),
			"promotions": int(entry.get("promotions", 0)),
			"last_promotion_match": int(entry.get("last_promotion_match", 0)),
			"pick_rate": _ratio(float(entry.get("picks", 0)), float(offers)),
			"kill_rate": _ratio(float(entry.get("kills", 0)), float(match_count)),
			"win_rate": _ratio(float(entry.get("wins", 0)), float(match_count)),
		}

	return {
		"version": DOCUMENT_VERSION,
		"updated_at": Time.get_datetime_string_from_system(true),
		"path": storage_path,
		"metrics": {
			"pick_rate": "picks / offers",
			"kill_rate": "kills / matches (cards in the killer's deck)",
			"win_rate": "wins / matches (cards in the player's final deck)",
		},
		"thresholds": {
			"evaluation_interval_matches": EVALUATION_INTERVAL_MATCHES,
			"min_card_matches": MIN_CARD_MATCHES,
			"min_peer_matches": MIN_PEER_MATCHES,
			"promotion_cooldown_matches": PROMOTION_COOLDOWN_MATCHES,
			"promotion_winrate_gap": PROMOTION_WINRATE_GAP,
			"promotion_min_winrate": PROMOTION_MIN_WINRATE,
		},
		"matches": matches,
		"last_evaluated_match": last_evaluated_match,
		"cards": card_documents,
		"rarity_overrides": rarity_overrides.duplicate(true),
		"promotion_log": promotion_log.duplicate(true),
	}

func _load_document() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var text := FileAccess.get_file_as_string(storage_path)
	if text.strip_edges().is_empty():
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("CardStats: Statistikdatei konnte nicht gelesen werden.")
		return

	var data: Dictionary = parsed
	matches = maxi(0, int(data.get("matches", 0)))
	last_evaluated_match = clampi(int(data.get("last_evaluated_match", 0)), 0, matches)
	var raw_promotions: Variant = data.get("promotion_log", [])
	if raw_promotions is Array:
		for value in raw_promotions:
			if value is Dictionary:
				promotion_log.append(value.duplicate(true))
		while promotion_log.size() > MAX_PROMOTION_LOG:
			promotion_log.pop_front()

	var raw_overrides: Variant = data.get("rarity_overrides", {})
	if raw_overrides is Dictionary:
		for key in raw_overrides.keys():
			var card_id := str(key)
			var rarity := str(raw_overrides[key])
			if CardDatabase.get_card(card_id) != null and Global.RARITY_ORDER.has(rarity):
				rarity_overrides[card_id] = rarity

	var raw_cards: Variant = data.get("cards", {})
	if raw_cards is Dictionary:
		for key in raw_cards.keys():
			var card_id := str(key)
			var raw_entry: Variant = raw_cards[key]
			if CardDatabase.get_card(card_id) == null or not (raw_entry is Dictionary):
				continue
			var raw: Dictionary = raw_entry
			var match_count := maxi(0, int(raw.get("matches", 0)))
			statistics[card_id] = {
				"offers": maxi(0, int(raw.get("offers", 0))),
				"picks": maxi(0, int(raw.get("picks", 0))),
				"kills": maxi(0, int(raw.get("kills", 0))),
				"matches": match_count,
				"wins": clampi(int(raw.get("wins", 0)), 0, match_count),
				"promotions": maxi(0, int(raw.get("promotions", 0))),
				"last_promotion_match": maxi(0, int(raw.get("last_promotion_match", 0))),
			}

func _save_document() -> void:
	if not persistence_enabled:
		return
	var file := FileAccess.open(storage_path, FileAccess.WRITE)
	if file == null:
		push_warning("CardStats: Statistikdatei konnte nicht geschrieben werden: %s" % storage_path)
		return
	file.store_string(JSON.stringify(_build_document(), "\t"))
	file.close()
