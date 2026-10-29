class_name CardDraftUI
extends CanvasLayer

signal draft_sequence_finished
# ESC während der Kartenwahl: main.gd öffnet das Optionsmenü (main selbst ist
# im Draft pausiert und bekommt keine Eingaben).
signal options_requested

const BonusRainScript = preload("res://scripts/ui/bonus_rain.gd")
const GambleBurnScript = preload("res://scripts/ui/gamble_burn.gd")
const BONUS_SOURCE_NAMES := {"pinata": "PINATA", "gold": "GOLD"}
# Pre-Draft vor der ersten Runde läuft über denselben Quellen-Kanal wie die
# Bonus-Züge, damit Clients ihn ohne neues RPC erkennen.
const PRE_DRAFT_SOURCE := "pre_draft"
const BOT_RARITY_RANK := {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5}

@onready var main_control: Control = $MainControl
@onready var draft_view: VBoxContainer = $MainControl/DraftView
@onready var reveal_view: PanelContainer = $MainControl/RevealView

# Draft view nodes
@onready var turn_label: Label = $MainControl/DraftView/TurnLabel
@onready var subtitle_label: Label = $MainControl/DraftView/SubtitleLabel
@onready var draft_tabs: TabContainer = $MainControl/DraftView/DraftTabs
@onready var cards_container: HBoxContainer = $MainControl/DraftView/DraftTabs/Karten/CardsContainer
@onready var bot_status_label: Label = $MainControl/DraftView/DraftTabs/Karten/BotStatusLabel

# Reveal view nodes
@onready var reveal_header: Label = $MainControl/RevealView/VBox/RevealHeader
@onready var reveal_card_holder: CenterContainer = $MainControl/RevealView/VBox/CardHolder
@onready var continue_btn: Button = $MainControl/RevealView/VBox/ContinueBtn

@onready var bot_timer: Timer = $BotTimer
@onready var reveal_timer: Timer = $RevealTimer

var draft_queue: Array[int] = []
var current_drafter: int = 1
var offered_cards: Array[CardData] = []
var picked_this_draft: Array[CardData] = []
var picks_total: int = 1
var picks_remaining: int = 1
var is_bot_drafting: bool = false
var is_in_reveal: bool = false

# Online-Draft: Beide Seiten sehen dieselben Karten. Nur der aktive Spieler darf wählen.
var network_mode: bool = false
var local_owner: bool = true
var pending_network_pick: bool = false
var pending_remote_picks: Array[String] = []
# Mehrere Picks: Nach jeder Wahl wird ein komplett neues Angebot gezogen.
# Alle in diesem Draft schon gezeigten Karten werden dabei ausgeschlossen.
var draft_offered_history: Array[CardData] = []
# Client: Neues Angebot vom Host, das während der Auflösung eingetroffen ist.
var pending_reoffer_ids: Array = []
var awaiting_reoffer: bool = false
# Bonus-Züge durch Piñata oder Beute-Münzen: Quelle pro Eintrag in draft_queue
# ("" = normaler Zug). Während eines Bonus-Zugs regnen passende Partikel.
var draft_queue_sources: Array[String] = []
var current_bonus_source: String = ""
var bonus_rain: BonusRainScript = null
# Draft-Modifier Gamble: Die Karten liegen verdeckt (Rückseite in der Farbe der
# Seltenheit) und werden von links nach rechts einzeln aufgedeckt. Wählbar ist
# nur die zuletzt aufgedeckte Karte; wer die nächste umdreht, verkohlt sie.
# gamble_revealed = Anzahl aufgedeckter Karten im aktuellen Angebot.
var gamble_revealed: int = 0
# Client: Aufdeck-Stand vom Host, der vor dem zugehörigen Angebot eintraf.
var pending_gamble_revealed: int = 0
# Client: Umdrehen wurde beim Host angefragt, bis zur Antwort keine Wahl.
var gamble_flip_requested: bool = false
# Die eben verkohlte Karte kurz aufglühen lassen.
var gamble_burn_flash: bool = false
# Nach dem Pick werden kurz alle übrigen Karten aufgedeckt, bevor die
# Auflösung kommt.
const GAMBLE_AFTERMATH_TIME := 1.8
var gamble_aftermath_active: bool = false
var gamble_aftermath_card: CardData = null
# Tastatur-Navigation: A/D bewegt die Markierung, Leertaste wählt.
# draft_cursor ist der Index im aktuellen Kartenangebot (cards_container).
var draft_cursor: int = 0
# Kompakte Leiste unten mit den Karten des eigenen Spielers (lokal: des
# aktuellen Drafters). Details gibt es weiter über das Tab-Overlay.
const MAX_OWN_CARD_CHIPS := 27
var own_cards_bar: PanelContainer = null
var own_cards_title: Label = null
var own_cards_flow: HFlowContainer = null
# Die Chips unten zeigen ihre Beschreibung sofort (eigenes Hover-Panel statt
# Godot-Tooltip, dessen Verzögerung für die großen Draft-Karten gilt).
var own_card_hover: PanelContainer = null
var own_card_hover_label: Label = null

func _ready() -> void:
	visible = false
	draft_view.visible = true
	reveal_view.visible = false
	bot_timer.timeout.connect(_on_bot_auto_pick)
	reveal_timer.timeout.connect(_finish_current_reveal)
	continue_btn.pressed.connect(_finish_current_reveal)
	bonus_rain = BonusRainScript.new()
	main_control.add_child(bonus_rain)
	# Direkt über dem abgedunkelten Hintergrund, hinter Karten und Auflösung.
	main_control.move_child(bonus_rain, 1)
	bonus_rain.stop()
	_build_own_cards_bar()

func start_draft_sequence(losers: Array[int], sources: Array[String] = []) -> void:
	draft_queue = losers.duplicate()
	draft_queue_sources.clear()
	for i in range(draft_queue.size()):
		draft_queue_sources.append(sources[i] if i < sources.size() else "")
	if draft_queue.is_empty():
		_finish_entire_draft()
		return
	
	network_mode = NetworkManager.is_host and NetworkManager.has_clients()
	pending_network_pick = false
	pending_remote_picks.clear()
	bot_timer.stop()
	reveal_timer.stop()
	is_in_reveal = false
	visible = true
	draft_tabs.current_tab = 0
	get_tree().paused = true
	SoundManager.play_sound("draft_start", 0.0, 0.0)
	_process_next_in_queue()

# Pre-Draft: Alle Spieler draften vor Matchbeginn Global.pre_draft_picks Karten.
func start_pre_draft(slots: Array[int]) -> void:
	var sources: Array[String] = []
	for _slot in slots:
		sources.append(PRE_DRAFT_SOURCE)
	start_draft_sequence(slots, sources)

# Wird auf dem Client aufgerufen, wenn der Host das Kartenangebot geschickt hat.
func start_network_draft(drafter: int, card_ids: Array, picks_total_count: int, bonus_source: String = "") -> void:
	if card_ids.is_empty():
		return
	SoundManager.play_sound("draft_start", 0.0, 0.0)
	draft_queue.clear()
	draft_queue_sources.clear()
	_set_bonus_source(bonus_source)
	bot_timer.stop()
	reveal_timer.stop()
	is_in_reveal = false
	visible = true
	draft_tabs.current_tab = 0
	get_tree().paused = true
	network_mode = true
	current_drafter = drafter
	local_owner = (drafter == Global.local_player_index)
	pending_network_pick = false
	pending_remote_picks.clear()
	pending_reoffer_ids.clear()
	awaiting_reoffer = false
	pending_gamble_revealed = 0
	gamble_aftermath_active = false
	picked_this_draft.clear()
	draft_offered_history.clear()
	is_bot_drafting = false
	_set_offer_from_ids(card_ids)
	picks_total = maxi(picks_total_count, 1)
	picks_remaining = picks_total
	if picks_total <= 0:
		_finish_entire_draft()
		return
	_start_current_pick()

# Hält Bot-Wahl und Auflösungs-Timer an, solange lokal das Optionsmenü offen ist.
func set_timers_paused(paused: bool) -> void:
	bot_timer.paused = paused
	reveal_timer.paused = paused

func close_draft() -> void:
	_hide_own_card_hover()
	bot_timer.stop()
	reveal_timer.stop()
	visible = false
	draft_view.visible = true
	reveal_view.visible = false
	is_in_reveal = false
	picks_remaining = 0
	pending_network_pick = false
	pending_remote_picks.clear()
	pending_reoffer_ids.clear()
	awaiting_reoffer = false
	pending_gamble_revealed = 0
	gamble_flip_requested = false
	gamble_aftermath_active = false
	_set_bonus_source("")
	get_tree().paused = false

func _process_next_in_queue() -> void:
	if draft_queue.is_empty():
		_finish_entire_draft()
		return
	
	current_drafter = draft_queue.pop_front()
	_set_bonus_source(draft_queue_sources.pop_front() if not draft_queue_sources.is_empty() else "")
	is_in_reveal = false
	pending_network_pick = false
	pending_remote_picks.clear()
	pending_reoffer_ids.clear()
	awaiting_reoffer = false
	pending_gamble_revealed = 0
	picked_this_draft.clear()
	draft_offered_history.clear()
	is_bot_drafting = Global.is_bot_slot(current_drafter)
	local_owner = (not network_mode) or current_drafter == Global.local_player_index

	offered_cards = _draw_offer()
	
	if offered_cards.is_empty():
		# Keine Karten verfügbar (z. B. alles gesperrt) -> diesen Drafter überspringen.
		_process_next_in_queue()
		return
	
	_record_offer(offered_cards)
	# Jeder Pick bekommt ein eigenes Angebot, daher begrenzt die Angebotsgröße
	# die Zahl der Picks nicht mehr.
	picks_total = maxi(Global.pre_draft_picks if _is_pre_draft() else Global.draft_picks, 1)
	picks_remaining = picks_total
	
	# Host schickt das identische Angebot an den Client.
	if network_mode and NetworkManager.is_host:
		var ids: Array = []
		for c in offered_cards:
			ids.append(c.id)
		NetworkManager.send_draft_start(current_drafter, ids, picks_total, current_bonus_source)
	
	_start_current_pick()

# Zieht ein Angebot für den aktuellen Drafter. Besessene und gesperrte Karten
# werden ausgeschlossen. Ausbaukarten erscheinen nur mit ihrer Grundkarte;
# offene Zweige einer Familie werden gemeinsam angeboten. Seltene Karten werden
# seltener gezogen (einstellbar über die Seltenheits-Gewichtung). Karten aus
# früheren Angeboten dieses Drafts werden zusätzlich ausgeschlossen, damit jede
# Wahl eine komplett neue Auswahl zeigt. Reicht der Pool dafür nicht, dürfen sie
# wieder erscheinen.
func _draw_offer() -> Array[CardData]:
	var owned_ids := Global.get_owned_card_ids(current_drafter)
	var exclude: Array = owned_ids.duplicate()
	exclude.append_array(Global.banned_card_ids)
	var drafter_hero_id: String = Global.get_player_hero_id(current_drafter)
	if not draft_offered_history.is_empty():
		var fresh_exclude: Array = exclude.duplicate()
		for c in draft_offered_history:
			fresh_exclude.append(c.id)
		var fresh := CardDatabase.get_draft_offer(Global.cards_per_draft, fresh_exclude, drafter_hero_id, owned_ids)
		if not fresh.is_empty():
			return fresh
	return CardDatabase.get_draft_offer(Global.cards_per_draft, exclude, drafter_hero_id, owned_ids)

func _record_offer(cards: Array[CardData]) -> void:
	CardStats.record_offer(cards)
	for c in cards:
		if not draft_offered_history.has(c):
			draft_offered_history.append(c)

func _set_offer_from_ids(card_ids: Array) -> void:
	offered_cards.clear()
	for card_id in card_ids:
		var card = CardDatabase.get_card(str(card_id))
		if card:
			offered_cards.append(card)
	if not offered_cards.is_empty():
		_record_offer(offered_cards)

# Host/lokal: Nach einem Pick ein neues Angebot ziehen und an Clients schicken.
func _start_next_offer() -> void:
	# Wahlen zum alten Angebot sind ab hier ungültig.
	pending_remote_picks.clear()
	offered_cards = _draw_offer()
	if offered_cards.is_empty():
		_finish_drafter()
		return
	_record_offer(offered_cards)
	if network_mode and NetworkManager.is_host:
		var ids: Array = []
		for c in offered_cards:
			ids.append(c.id)
		NetworkManager.send_draft_reoffer(ids)
	_start_current_pick()

# Client: Der Host hat ein neues Angebot für den nächsten Pick gezogen.
func apply_network_reoffer(card_ids: Array) -> void:
	if card_ids.is_empty():
		return
	if is_in_reveal or not awaiting_reoffer:
		pending_reoffer_ids = card_ids.duplicate()
		return
	_apply_reoffer(card_ids)

func _apply_reoffer(card_ids: Array) -> void:
	awaiting_reoffer = false
	pending_reoffer_ids.clear()
	var buffered_gamble := pending_gamble_revealed
	pending_gamble_revealed = 0
	_set_offer_from_ids(card_ids)
	# Picks, die schon für das neue Angebot eingetroffen sind, direkt anwenden.
	while not pending_remote_picks.is_empty():
		var remote_id: String = pending_remote_picks.pop_front()
		var remote_card = CardDatabase.get_card(remote_id)
		if remote_card and _offer_has(remote_id):
			gamble_revealed = buffered_gamble
			_commit_pick(remote_card, true)
			return
	_start_current_pick()
	# Gamble: Karten, die der Host schon aufgedeckt hat, nachziehen.
	if buffered_gamble > 0:
		_apply_gamble_revealed(buffered_gamble)

func _offer_has(card_id: String) -> bool:
	for offered in offered_cards:
		if offered.id == card_id:
			return true
	return false

func _show_waiting_for_offer() -> void:
	awaiting_reoffer = true
	draft_view.visible = true
	reveal_view.visible = false
	bot_timer.stop()
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	var pick_number = picks_total - picks_remaining + 1
	turn_label.text = _turn_title(_drafter_name(current_drafter), pick_number)
	bot_status_label.text = "Neue Karten werden gezogen..."
	bot_status_label.visible = true
	_refresh_own_cards_bar()

func _finish_drafter() -> void:
	if not picked_this_draft.is_empty():
		RoundStats.record_draft(current_drafter, draft_offered_history, picked_this_draft)
	picks_remaining = 0
	_process_next_in_queue()

func _start_current_pick() -> void:
	is_in_reveal = false
	draft_view.visible = true
	reveal_view.visible = false
	gamble_revealed = 0
	gamble_flip_requested = false
	gamble_burn_flash = false
	gamble_aftermath_active = false
	draft_cursor = 0
	
	var pick_number = picks_total - picks_remaining + 1
	var drafter_name = _drafter_name(current_drafter)
	var blind_hidden := _blind_pick_hidden()
	var random_auto := _authoritative_random_pick()
	
	turn_label.text = _turn_title(drafter_name, pick_number)
	if blind_hidden:
		subtitle_label.text = "BLIND PICK: %s wählt verdeckt. Andere Spieler sehen nur Kartenrückseiten." % drafter_name
	elif random_auto:
		var random_prefix := "BLIND PICK + " if _blind_pick_active() else ""
		subtitle_label.text = "%sZUFALLS-PICK: Eine zufällige Karte wird gezogen (Pick %d/%d)." % [random_prefix, pick_number, picks_total]
	elif _random_pick_active():
		var host_prefix := "BLIND PICK + " if _blind_pick_active() else ""
		subtitle_label.text = "%sZUFALLS-PICK: Der Host zieht eine zufällige Karte (Pick %d/%d)." % [host_prefix, pick_number, picks_total]
	elif _blind_pick_active():
		subtitle_label.text = "BLIND PICK: Deine Auswahl bleibt vor anderen Spielern verborgen (Pick %d/%d)." % [pick_number, picks_total]
	else:
		subtitle_label.text = "Wähle 1 von %d Karten (Pick %d/%d). Alle sehen die Auswahl live!" % [offered_cards.size(), pick_number, picks_total]
	if _gamble_active() and not blind_hidden:
		var gamble_prefix := "BLIND PICK + " if _blind_pick_active() else ""
		subtitle_label.text = "%sGAMBLE: Karten verdeckt, die Rückseite zeigt die Seltenheit. Von links aufdecken: Nimm die offene Karte oder dreh die nächste um, dann verkohlt die offene (Pick %d/%d)." % [gamble_prefix, pick_number, picks_total]
	
	if random_auto:
		bot_status_label.text = "🎲 Zufällige Karte wird gezogen (Pick %d/%d)..." % [pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.start(0.9)
	elif is_bot_drafting:
		if blind_hidden:
			bot_status_label.text = "🙈🤖 Bot wählt verdeckt (Pick %d/%d)..." % [pick_number, picks_total]
		elif _gamble_active():
			bot_status_label.text = "🎰🤖 Bot zockt (Pick %d/%d)..." % [pick_number, picks_total]
		else:
			bot_status_label.text = "🤖 Bot analysiert Synergien und wählt (Pick %d/%d)..." % [pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.start(1.4)
	elif blind_hidden:
		bot_status_label.text = "🙈 Blind pick: %s' Auswahl ist verdeckt..." % drafter_name
		bot_status_label.visible = true
		bot_timer.stop()
	elif _random_pick_active():
		bot_status_label.text = "🎲 Der Host zieht eine zufällige Karte (Pick %d/%d)..." % [pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.stop()
	elif network_mode and not local_owner:
		bot_status_label.text = "%s wählt gerade (Pick %d/%d)..." % [drafter_name, pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.stop()
	else:
		bot_status_label.text = "A/D: Karte markieren  ·  Leertaste: wählen  ·  Maus oder Zifferntaste (1-%d) gehen auch" % _remaining_cards().size()
		bot_status_label.visible = true
		bot_timer.stop()
		_update_gamble_status()
	
	_populate_cards()
	_refresh_own_cards_bar()

func _blind_pick_active() -> bool:
	# Blind pick ist ausschließlich im Online-Spiel gegen menschliche Spieler
	# relevant. Lokal bzw. gegen Bots gibt es niemanden, vor dem verdeckt wird.
	return Global.blind_pick_enabled and network_mode

# Auf dem lokalen Bildschirm muss der aktive menschliche Spieler seine Karten
# sehen. Entfernte menschliche Spieler bleiben dagegen verdeckt; Bots werden
# nie verdeckt.
func _blind_pick_hidden() -> bool:
	if not _blind_pick_active():
		return false
	if Global.is_bot_slot(current_drafter):
		return false
	return not local_owner

func _random_pick_active() -> bool:
	return Global.random_pick_enabled or (_is_pre_draft() and Global.pre_draft_random)

# Random pick zieht ohnehin automatisch; dann bleibt Gamble ohne Wirkung.
func _gamble_active() -> bool:
	return Global.gamble_enabled and not _random_pick_active()

func _is_pre_draft() -> bool:
	return current_bonus_source == PRE_DRAFT_SOURCE

func _turn_title(drafter_name: String, pick_number: int) -> String:
	if _is_pre_draft():
		return "PRE-DRAFT: %s – PICK %d/%d" % [drafter_name, pick_number, picks_total]
	if current_bonus_source != "":
		return "BONUS ZUG (%s): %s – PICK %d/%d" % [_bonus_source_name(), drafter_name, pick_number, picks_total]
	return "UPGRADE-PHASE: %s – PICK %d/%d" % [drafter_name, pick_number, picks_total]

# Die zuletzt aufgedeckte Karte, die einzige wählbare Karte im Gamble.
func _gamble_current_card() -> CardData:
	var remaining := _remaining_cards()
	if gamble_revealed <= 0 or gamble_revealed > remaining.size():
		return null
	return remaining[gamble_revealed - 1]

func _update_gamble_status() -> void:
	if not _gamble_active() or not _local_can_manual_pick():
		return
	var count := _remaining_cards().size()
	if gamble_revealed <= 0:
		bot_status_label.text = "🎰 Leertaste: erste Karte aufdecken."
	elif gamble_revealed >= count:
		bot_status_label.text = "🎰 Letzte Karte: Leertaste nimmt sie."
	else:
		bot_status_label.text = "🎰 A/D: offene Karte oder nächste Rückseite markieren  ·  Leertaste: nehmen bzw. umdrehen (die offene verbrennt)."
	bot_status_label.visible = true

# Host bzw. lokal: nächste Karte aufdecken. Der Client fragt beim Host an.
func _gamble_flip_next() -> void:
	if not _gamble_active() or is_in_reveal or picks_remaining <= 0 or pending_network_pick:
		return
	if gamble_revealed >= _remaining_cards().size():
		return
	if network_mode and not NetworkManager.is_host:
		if gamble_flip_requested:
			return
		gamble_flip_requested = true
		NetworkManager.request_draft_gamble_flip(gamble_revealed + 1)
		bot_status_label.text = "Karte wird umgedreht..."
		bot_status_label.visible = true
		_populate_cards()
		return
	_apply_gamble_revealed(gamble_revealed + 1)
	if network_mode and NetworkManager.is_host:
		NetworkManager.send_draft_gamble_flip(gamble_revealed)

func _apply_gamble_revealed(revealed: int) -> void:
	revealed = clampi(revealed, 0, _remaining_cards().size())
	if revealed <= gamble_revealed:
		_update_gamble_status()
		_populate_cards()
		return
	var burns := revealed > 1
	gamble_revealed = revealed
	gamble_burn_flash = burns
	# Markierung springt auf die frisch aufgedeckte Karte.
	draft_cursor = gamble_revealed - 1
	SoundManager.play_sound("mystery", 0.05, 0.0)
	if burns:
		SoundManager.play_sound("fuse", 0.05, 0.0)
	_update_gamble_status()
	_populate_cards()
	gamble_burn_flash = false

# Host: Der Client am Zug möchte die nächste Karte umdrehen.
func apply_network_gamble_request(revealed: int) -> void:
	if not _gamble_active() or is_in_reveal or awaiting_reoffer or pending_network_pick or picks_remaining <= 0:
		return
	if revealed != gamble_revealed + 1:
		# Veraltete Anfrage: aktuellen Stand erneut schicken, damit der Client
		# nicht auf eine Antwort wartet.
		NetworkManager.send_draft_gamble_flip(gamble_revealed)
		return
	_gamble_flip_next()

# Client: Der Host hat Karten aufgedeckt.
func apply_network_gamble_flip(revealed: int) -> void:
	if not network_mode or NetworkManager.is_host:
		return
	gamble_flip_requested = false
	# Gehört zum nächsten Angebot, das noch nicht angezeigt wird.
	if is_in_reveal or awaiting_reoffer or not pending_reoffer_ids.is_empty():
		pending_gamble_revealed = maxi(pending_gamble_revealed, revealed)
		return
	_apply_gamble_revealed(revealed)

# Nur der Host (bzw. der lokale Modus ohne Netzwerk) darf Random-Picks ziehen.
func _authoritative_random_pick() -> bool:
	return _random_pick_active() and (not network_mode or NetworkManager.is_host)

func _local_can_manual_pick() -> bool:
	if is_bot_drafting or pending_network_pick or awaiting_reoffer or gamble_flip_requested or _random_pick_active():
		return false
	if network_mode and not local_owner:
		return false
	return true

func _drafter_name(index: int) -> String:
	var prefix := ""
	if Global.is_team_mode():
		prefix = "[%s] " % Global.get_team_name(Global.get_team_for_slot(index))
	if Global.is_bot_slot(index):
		return prefix + "BOT (Slot %d)" % index
	var is_local := Global.network_mode and index == Global.local_player_index
	# Eingegebener Spielername hat Vorrang, sonst Ersatz wie bisher.
	var custom := Global.get_custom_player_name(index)
	if not custom.is_empty():
		return prefix + custom.to_upper() + (" (DU)" if is_local else "")
	if is_local:
		return prefix + "DU (Slot %d)" % index
	return prefix + "SPIELER %d" % index

func _talent_badge_text(card: CardData) -> String:
	if card.parent_card_id.is_empty():
		return ""
	var base := CardDatabase.get_card(card.parent_card_id)
	var base_title := base.title if base else card.parent_card_id
	var branch := card.evolution_branch if not card.evolution_branch.is_empty() else "?"
	return "TALENTBAUM: %s  •  ZWEIG %s" % [base_title.to_upper(), branch]

func _remaining_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	var owned_ids := Global.get_owned_card_ids(current_drafter)
	var hero_id: String = Global.get_player_hero_id(current_drafter)
	for card in offered_cards:
		var already_picked := false
		for picked in picked_this_draft:
			if picked.id == card.id:
				already_picked = true
				break
		if already_picked:
			continue
		# Nach einer Zweigwahl wird die andere Option sofort aus dem offenen
		# Angebot entfernt, auch wenn beide Zweige gemeinsam gezogen wurden.
		if not CardDatabase.is_card_available_for_player(card, hero_id, owned_ids):
			continue
		result.append(card)
	return result

func _populate_cards() -> void:
	_fill_cards()
	_apply_cursor_highlight()

# Karten-Indizes, die man mit A/D anwählen kann. Im Gamble nur die offene
# Karte und die nächste Rückseite.
func _nav_slots() -> Array[int]:
	var slots: Array[int] = []
	var count := _remaining_cards().size()
	if _gamble_active():
		if gamble_revealed > 0 and gamble_revealed <= count:
			slots.append(gamble_revealed - 1)
		if gamble_revealed < count:
			slots.append(gamble_revealed)
		return slots
	for i in range(count):
		slots.append(i)
	return slots

func _move_cursor(direction: int) -> void:
	var slots := _nav_slots()
	if slots.is_empty():
		return
	var pos := slots.find(draft_cursor)
	if pos < 0:
		pos = 0
	else:
		pos = clampi(pos + direction, 0, slots.size() - 1)
	if slots[pos] == draft_cursor:
		return
	draft_cursor = slots[pos]
	SoundManager.play_sound("click")
	_apply_cursor_highlight()

# Leertaste: markierte Karte wählen. Im Gamble nimmt sie die offene Karte
# bzw. dreht die markierte Rückseite um.
func _activate_cursor() -> void:
	var remaining := _remaining_cards()
	if draft_cursor < 0 or draft_cursor >= remaining.size():
		return
	if not _gamble_active():
		_commit_pick(remaining[draft_cursor])
	elif draft_cursor == gamble_revealed - 1:
		_commit_pick(remaining[draft_cursor])
	elif draft_cursor == gamble_revealed:
		_gamble_flip_next()

func _apply_cursor_highlight() -> void:
	var slots := _nav_slots()
	var show := _local_can_manual_pick() and not is_in_reveal and not slots.is_empty()
	if show and not slots.has(draft_cursor):
		draft_cursor = slots[0]
	var children := cards_container.get_children()
	for i in range(children.size()):
		var c := children[i] as Control
		if c == null:
			continue
		var selected := show and i == draft_cursor
		c.pivot_offset = c.custom_minimum_size * 0.5
		c.scale = Vector2(1.06, 1.06) if selected else Vector2.ONE
		c.z_index = 1 if selected else 0
		if not show:
			c.modulate = Color.WHITE
		elif selected:
			c.modulate = Color(1.18, 1.18, 1.18)
		else:
			c.modulate = Color(0.78, 0.78, 0.84)

func _fill_cards() -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	
	var remaining = _remaining_cards()
	if _gamble_active():
		var gamble_hidden := _blind_pick_hidden()
		for i in range(remaining.size()):
			cards_container.add_child(_create_gamble_slot(remaining[i], i, gamble_hidden))
		return
	if _blind_pick_hidden():
		for i in range(remaining.size()):
			cards_container.add_child(_create_hidden_card(i + 1))
		return
	for i in range(remaining.size()):
		var card_panel = _create_card_button(remaining[i], i + 1)
		cards_container.add_child(card_panel)

func _create_framed_card(card: CardData, min_size: Vector2, outer_bg: Color, inner_bg: Color) -> Dictionary:
	# Äußerer Rahmen = Seltenheit, innerer Rahmen = Effektfarbe der Karte.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size

	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = outer_bg
	outer_style.set_corner_radius_all(12)
	outer_style.border_width_left = 5
	outer_style.border_width_right = 5
	outer_style.border_width_top = 5
	outer_style.border_width_bottom = 5
	outer_style.border_color = CardDatabase.get_rarity_color(card.rarity)
	panel.add_theme_stylebox_override("panel", outer_style)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 5)
	outer_margin.add_theme_constant_override("margin_right", 5)
	outer_margin.add_theme_constant_override("margin_top", 5)
	outer_margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(outer_margin)

	var inner_panel := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = inner_bg
	inner_style.set_corner_radius_all(8)
	inner_style.border_width_left = 2
	inner_style.border_width_right = 2
	inner_style.border_width_top = 2
	inner_style.border_width_bottom = 2
	inner_style.border_color = card.color
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	outer_margin.add_child(inner_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	inner_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	return {"panel": panel, "vbox": vbox}

# show_button = false: ohne WÄHLEN-Knopf, stattdessen optional eine Fußzeile.
func _create_card_button(card: CardData, slot_index: int, show_button: bool = true, footer: String = "", footer_color: Color = Color.WHITE) -> PanelContainer:
	var framed := _create_framed_card(
		card,
		Vector2(200, 310),
		Color(0.08, 0.10, 0.14, 0.98),
		Color(0.13, 0.15, 0.20, 0.98)
	)
	var panel: PanelContainer = framed["panel"]
	var vbox: VBoxContainer = framed["vbox"]
	
	# Key indicator + Rarity
	var top_row = HBoxContainer.new()
	var key_badge = Label.new()
	key_badge.text = "[%d]" % slot_index
	key_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_row.add_child(key_badge)

	var card_icon := CardIcon.new()
	card_icon.setup(card, 38.0)
	top_row.add_child(card_icon)
	
	var rarity_label = Label.new()
	rarity_label.text = card.rarity.to_upper()
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_label.add_theme_color_override("font_color", CardDatabase.get_rarity_color(card.rarity))
	top_row.add_child(rarity_label)
	vbox.add_child(top_row)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 11)
	if evolution_banner != null:
		vbox.add_child(evolution_banner)
	
	# Klassen-Badge für klassenspezifische Karten
	var class_badge := CardMechanics.make_class_badge(card, 12)
	if class_badge != null:
		vbox.add_child(class_badge)

	var talent_text := _talent_badge_text(card)
	if not talent_text.is_empty():
		var talent_label = Label.new()
		talent_label.text = talent_text
		talent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		talent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		talent_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		talent_label.add_theme_font_size_override("font_size", 11)
		vbox.add_child(talent_label)
	
	# Title
	var title = Label.new()
	title.text = card.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# Description
	var desc = Label.new()
	desc.text = CardMechanics.format_description(card.description)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)

	var unlock_label := CardMechanics.make_unlock_label(card, 11)
	if unlock_label != null:
		vbox.add_child(unlock_label)

	var evolutions_preview := CardMechanics.make_evolutions_preview(card, 11)
	if evolutions_preview != null:
		vbox.add_child(evolutions_preview)
	
	if not show_button:
		if not footer.is_empty():
			var footer_label := Label.new()
			footer_label.text = footer
			footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			footer_label.custom_minimum_size = Vector2(0, 34)
			footer_label.add_theme_color_override("font_color", footer_color)
			footer_label.add_theme_font_size_override("font_size", 15)
			vbox.add_child(footer_label)
		CardMechanics.apply_tooltip(panel, card)
		return panel

	# Select Button
	var btn = Button.new()
	btn.text = "WÄHLEN [%d]" % slot_index
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(func(): _select_card(card))
	
	if not _local_can_manual_pick():
		btn.disabled = true
	
	vbox.add_child(btn)
	CardMechanics.apply_tooltip(panel, card)
	return panel

func _create_hidden_card(slot_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.border_color = Color(0.36, 0.30, 0.55, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = "Blind pick: Diese Karte ist für andere Spieler verdeckt."

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var key_badge := Label.new()
	key_badge.text = "[%d]" % slot_index
	key_badge.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))
	key_badge.add_theme_font_size_override("font_size", 14)
	vbox.add_child(key_badge)

	var question := Label.new()
	question.text = "?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question.add_theme_color_override("font_color", Color(0.72, 0.64, 0.96))
	question.add_theme_font_size_override("font_size", 96)
	vbox.add_child(question)

	var label := Label.new()
	label.text = "BLIND PICK"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.82, 0.74, 1.0))
	label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(label)

	var hint := Label.new()
	hint.text = "Kartenrückseite"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.54, 0.64))
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)
	return panel

# Gamble: links verkohlt, dann die offene Karte, rechts die Rückseiten.
# Bei Blind pick sehen andere Spieler auch die offene Karte nur verdeckt und
# die Rückseiten ohne Seltenheitsfarbe.
func _create_gamble_slot(card: CardData, index: int, hidden: bool) -> Control:
	var slot_index := index + 1
	if index < gamble_revealed - 1:
		if gamble_burn_flash and index == gamble_revealed - 2:
			return _create_burning_card(card, slot_index, hidden)
		return _create_charred_card(card, slot_index, hidden)
	if index == gamble_revealed - 1:
		if hidden:
			return _create_hidden_card(slot_index)
		return _create_card_button(card, slot_index)
	return _create_gamble_back(card, slot_index, index == gamble_revealed, hidden)

func _create_gamble_back(card: CardData, slot_index: int, is_next: bool, hidden: bool) -> PanelContainer:
	var rarity_color := Color(0.45, 0.40, 0.62) if hidden else CardDatabase.get_rarity_color(card.rarity)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = rarity_color.darkened(0.78)
	style.set_corner_radius_all(12)
	style.set_border_width_all(5 if is_next else 4)
	style.border_color = rarity_color
	if is_next and _local_can_manual_pick():
		style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.45)
		style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = "Gamble: Verdeckte Karte. Die Rückseite zeigt die Seltenheit."

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var key_badge := Label.new()
	key_badge.text = "[%d]" % slot_index
	key_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	key_badge.add_theme_font_size_override("font_size", 14)
	vbox.add_child(key_badge)

	var question := Label.new()
	question.text = "?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question.add_theme_color_override("font_color", rarity_color)
	question.add_theme_font_size_override("font_size", 96)
	vbox.add_child(question)

	var label := Label.new()
	label.text = "GAMBLE"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", rarity_color.lightened(0.25))
	label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(label)

	if is_next:
		var btn := Button.new()
		btn.text = "UMDREHEN"
		btn.custom_minimum_size = Vector2(0, 34)
		btn.disabled = not _local_can_manual_pick()
		btn.pressed.connect(_on_gamble_flip_pressed)
		vbox.add_child(btn)
		if gamble_revealed > 0:
			var warn := Label.new()
			warn.text = "Die offene Karte verbrennt!"
			warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			warn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.25))
			warn.add_theme_font_size_override("font_size", 12)
			vbox.add_child(warn)
	else:
		var hint := Label.new()
		hint.text = "Kartenrückseite"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.add_theme_color_override("font_color", Color(0.5, 0.54, 0.64))
		hint.add_theme_font_size_override("font_size", 12)
		vbox.add_child(hint)
	return panel

func _create_charred_card(card: CardData, slot_index: int, hidden: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 310)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.035, 0.03, 0.98)
	style.set_corner_radius_all(12)
	style.set_border_width_all(3)
	style.border_color = Color(0.55, 0.20, 0.05, 0.9)
	style.shadow_color = Color(1.0, 0.35, 0.05, 0.3)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = "Gamble: Diese Karte ist verkohlt und steht nicht mehr zur Auswahl."

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var key_badge := Label.new()
	key_badge.text = "[%d]" % slot_index
	key_badge.add_theme_color_override("font_color", Color(0.35, 0.30, 0.28))
	key_badge.add_theme_font_size_override("font_size", 14)
	vbox.add_child(key_badge)

	# Verkohlte Fläche mit Glutrissen statt Text.
	var ash := ColorRect.new()
	ash.color = Color(0.09, 0.06, 0.05, 1.0)
	ash.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var crack := ColorRect.new()
		crack.color = Color(0.85, 0.28, 0.05, 0.55 - i * 0.08)
		crack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crack.position = Vector2(18 + i * 37, 30 + (i * 53) % 120)
		crack.size = Vector2(22 + (i * 13) % 20, 2)
		ash.add_child(crack)
	vbox.add_child(ash)

	if not hidden:
		var title := Label.new()
		title.text = card.title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_color_override("font_color", Color(0.42, 0.38, 0.35))
		title.add_theme_font_size_override("font_size", 13)
		vbox.add_child(title)

	return panel

# Die eben weggedrehte Karte: Ein Feuerbalken wandert von unten nach oben,
# danach bleibt die verkohlte Karte liegen.
func _create_burning_card(card: CardData, slot_index: int, hidden: bool) -> Control:
	var face: Control = _create_hidden_card(slot_index) if hidden else _create_card_button(card, slot_index, false)
	var burn := GambleBurnScript.new()
	burn.setup(face, _create_charred_card(card, slot_index, hidden), Vector2(200, 310))
	return burn

# Nach dem Pick: übrige Rückseiten umdrehen, damit alle sehen, was noch lag.
func _show_gamble_aftermath(card: CardData, cards: Array[CardData]) -> void:
	is_in_reveal = true
	gamble_aftermath_active = true
	gamble_aftermath_card = card
	bot_timer.stop()
	draft_view.visible = true
	reveal_view.visible = false
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	var picked_index := cards.find(card)
	for i in range(cards.size()):
		var c: CardData = cards[i]
		if i == picked_index:
			cards_container.add_child(_create_card_button(c, i + 1, false, "✔ GENOMMEN", Color(1.0, 0.85, 0.3)))
		elif i < picked_index:
			cards_container.add_child(_create_charred_card(c, i + 1, false))
		else:
			var missed := _create_card_button(c, i + 1, false, "NICHT AUFGEDECKT", Color(0.6, 0.62, 0.7))
			missed.modulate = Color(0.75, 0.75, 0.8)
			cards_container.add_child(missed)
	bot_status_label.text = "🎰 Aufgedeckt: Das lag noch unter den Rückseiten."
	bot_status_label.visible = true
	SoundManager.play_sound("mystery", 0.05, 0.0)
	reveal_timer.start(GAMBLE_AFTERMATH_TIME)

func _on_gamble_flip_pressed() -> void:
	if not _local_can_manual_pick():
		return
	_gamble_flip_next()

func _create_hidden_reveal_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.15, 0.99)
	style.set_corner_radius_all(14)
	style.set_border_width_all(4)
	style.border_color = Color(0.48, 0.38, 0.72, 0.95)
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = "Blind pick: Die gewählte Karte bleibt vor anderen Spielern verborgen."

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var question := Label.new()
	question.text = "?"
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	question.add_theme_color_override("font_color", Color(0.78, 0.68, 1.0))
	question.add_theme_font_size_override("font_size", 120)
	vbox.add_child(question)

	var label := Label.new()
	label.text = "KARTE VERDECKT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.86, 0.78, 1.0))
	label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(label)

	var hint := Label.new()
	hint.text = "Blind pick ist aktiv."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.58, 0.62, 0.72))
	hint.add_theme_font_size_override("font_size", 14)
	vbox.add_child(hint)
	return panel

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Solange Tab gehalten wird, liegt der Charakterbogen darüber; die Zahlen-
	# tasten wechseln dort den Spieler und sollen keine Karte wählen.
	if Input.is_physical_key_pressed(KEY_TAB):
		return
	# Offenes Optionsmenü: keine Kartenwahl per Tastatur darunter.
	if GameSettings.gameplay_input_blocked:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		options_requested.emit()
		return
	
	# In reveal mode, Space or Enter continues (im Online-Modus bestimmt der Timer das Tempo).
	if is_in_reveal:
		if not network_mode and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)):
			_finish_current_reveal()
			get_viewport().set_input_as_handled()
		return
	
	# A/D (bzw. Pfeiltasten) bewegen die Markierung, Leertaste wählt.
	# Im Gamble nimmt Enter direkt die offene Karte.
	if _local_can_manual_pick() and event is InputEventKey and event.pressed:
		var key: int = event.keycode
		if key == KEY_A or key == KEY_LEFT:
			_move_cursor(-1)
			get_viewport().set_input_as_handled()
			return
		if key == KEY_D or key == KEY_RIGHT:
			_move_cursor(1)
			get_viewport().set_input_as_handled()
			return
		if event.is_echo():
			return
		if key == KEY_SPACE:
			_activate_cursor()
			get_viewport().set_input_as_handled()
			return
		if _gamble_active() and (key == KEY_ENTER or key == KEY_KP_ENTER):
			var open_card := _gamble_current_card()
			if open_card != null:
				_commit_pick(open_card)
			get_viewport().set_input_as_handled()
			return

	# Keyboard shortcuts 1-9 during draft
	if _local_can_manual_pick() and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			var remaining = _remaining_cards()
			if idx < remaining.size():
				if not _gamble_active():
					_commit_pick(remaining[idx])
				elif idx == gamble_revealed - 1:
					_commit_pick(remaining[idx])
				elif idx == gamble_revealed:
					_gamble_flip_next()
				get_viewport().set_input_as_handled()

func _select_card(card: CardData) -> void:
	if not _local_can_manual_pick():
		return
	_commit_pick(card)

func _commit_pick(card: CardData, from_network: bool = false) -> void:
	if picks_remaining <= 0 or is_in_reveal or pending_network_pick:
		return
	if Global.player_has_card(current_drafter, card.id):
		return
	for picked in picked_this_draft:
		if picked.id == card.id:
			return
	# Exklusive Evolutionszweige: Sobald ein Zweig gewählt wurde, sind die
	# Karten des Geschwisterzweigs nicht mehr wählbar.
	var owned_ids := Global.get_owned_card_ids(current_drafter)
	if not CardDatabase.is_card_available_for_player(card, Global.get_player_hero_id(current_drafter), owned_ids):
		return
	# Gamble: Nur die zuletzt aufgedeckte Karte ist wählbar. Der Client
	# übernimmt bestätigte Host-Wahlen ohne eigene Prüfung.
	if _gamble_active() and not (from_network and network_mode and not NetworkManager.is_host):
		var gamble_card := _gamble_current_card()
		if gamble_card == null or gamble_card.id != card.id:
			return
	
	# Client schickt die Wahl zum Host; erst der Host wendet sie verbindlich an.
	if network_mode and not from_network and not NetworkManager.is_host:
		pending_network_pick = true
		NetworkManager.request_draft_pick(card.id)
		bot_status_label.text = "Auswahl wird an den Host übertragen..."
		bot_status_label.visible = true
		_populate_cards()
		return
	
	# Gamble: Angebot vor dem Pick merken, um danach alles aufzudecken.
	var gamble_aftermath := _gamble_active() and not _blind_pick_hidden()
	var gamble_cards: Array[CardData] = []
	if gamble_aftermath:
		gamble_cards = _remaining_cards()
	SoundManager.play_sound("card_pick", 0.03, 0.0)
	if not Global.add_card_to_player(current_drafter, card):
		return
	CardStats.record_pick(card.id)
	picked_this_draft.append(card)
	picks_remaining -= 1
	if picks_remaining <= 0:
		RoundStats.record_draft(current_drafter, draft_offered_history, picked_this_draft)
	if gamble_aftermath and gamble_cards.has(card):
		_show_gamble_aftermath(card, gamble_cards)
	else:
		_show_public_reveal(current_drafter, card)
	
	if network_mode and NetworkManager.is_host:
		NetworkManager.send_draft_pick(card.id)

# Wird auf beiden Seiten angewendet: Host nach Client-Wahl, Client nach Host-Bestätigung.
func apply_network_pick(card_id: String) -> void:
	pending_network_pick = false
	# Client: Ein neues Angebot liegt schon bereit oder wird erwartet. Die Wahl
	# gehört zu diesem neuen Angebot und wird nach dessen Anzeige angewendet.
	if network_mode and not NetworkManager.is_host and (is_in_reveal or awaiting_reoffer or not pending_reoffer_ids.is_empty()):
		pending_remote_picks.append(card_id)
		return
	# Nur Karten akzeptieren, die auch wirklich im aktuellen Angebot waren.
	if not _offer_has(card_id):
		return
	# Wenn gerade die Auflösung des vorherigen Picks läuft, Wahl zwischenspeichern.
	if is_in_reveal:
		pending_remote_picks.append(card_id)
		return
	var card = CardDatabase.get_card(card_id)
	if card:
		_commit_pick(card, true)

func _show_public_reveal(drafter_idx: int, card: CardData) -> void:
	_hide_own_card_hover()
	is_in_reveal = true
	draft_view.visible = false
	reveal_view.visible = true
	# Im Online-Modus darf die Auflösung nicht übersprungen werden, sonst könnten
	# Host und Client bei mehreren Picks auseinanderlaufen.
	continue_btn.disabled = network_mode
	
	var drafter_name = _drafter_name(drafter_idx)
	var pick_number = picks_total - picks_remaining
	var blind_hidden := _blind_pick_hidden()
	if blind_hidden:
		var hidden_action := "EINE ZUFÄLLIGE KARTE GEZOGEN" if _random_pick_active() else "EINE KARTE GEWÄHLT"
		reveal_header.text = "🙈 BLIND PICK: %s HAT %s! (PICK %d/%d)" % [drafter_name, hidden_action, pick_number, picks_total]
	elif _blind_pick_active():
		var blind_label := "DEINE BLIND-ZUFALLSWAHL" if _random_pick_active() else "DEINE BLIND-WAHL"
		reveal_header.text = "🔒 %s: %s! (PICK %d/%d)" % [blind_label, card.title.to_upper(), pick_number, picks_total]
	elif _gamble_active():
		var burned := maxi(gamble_revealed - 1, 0)
		var burned_text := " (%d VERKOHLT)" % burned if burned > 0 else ""
		reveal_header.text = "🎰 GAMBLE: %s NIMMT %s%s! (PICK %d/%d)" % [drafter_name, card.title.to_upper(), burned_text, pick_number, picks_total]
	elif _random_pick_active():
		reveal_header.text = "🎲 ZUFALLS-PICK: %s ERHÄLT %s! (PICK %d/%d)" % [drafter_name, card.title.to_upper(), pick_number, picks_total]
	else:
		reveal_header.text = "📢 ÖFFENTLICHE WAHL: %s WÄHLT %s! (PICK %d/%d)" % [drafter_name, card.title.to_upper(), pick_number, picks_total]
	
	# Clear previous reveal card
	for child in reveal_card_holder.get_children():
		child.queue_free()
	
	if blind_hidden:
		reveal_card_holder.add_child(_create_hidden_reveal_card())
		reveal_timer.start(2.2)
		return

	var framed := _create_framed_card(
		card,
		Vector2(260, 360),
		Color(0.10, 0.12, 0.17, 0.99),
		Color(0.14, 0.16, 0.22, 0.99)
	)
	var reveal_panel: PanelContainer = framed["panel"]
	var vbox: VBoxContainer = framed["vbox"]

	var rarity_row := HBoxContainer.new()
	rarity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rarity_row.add_theme_constant_override("separation", 10)
	var card_icon := CardIcon.new()
	card_icon.setup(card, 44.0)
	rarity_row.add_child(card_icon)

	var rarity = Label.new()
	rarity.text = "⭐ " + card.rarity.to_upper() + " ⭐"
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", CardDatabase.get_rarity_color(card.rarity))
	rarity.add_theme_font_size_override("font_size", 16)
	rarity_row.add_child(rarity)
	vbox.add_child(rarity_row)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 12)
	if evolution_banner != null:
		vbox.add_child(evolution_banner)
	
	var class_badge := CardMechanics.make_class_badge(card, 13)
	if class_badge != null:
		vbox.add_child(class_badge)

	var talent_text := _talent_badge_text(card)
	if not talent_text.is_empty():
		var talent_label = Label.new()
		talent_label.text = talent_text
		talent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		talent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		talent_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
		talent_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(talent_label)
	
	var title = Label.new()
	title.text = card.title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	vbox.add_child(HSeparator.new())
	
	var desc = Label.new()
	desc.text = CardMechanics.format_description(card.description)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 15)
	vbox.add_child(desc)

	var unlock_label := CardMechanics.make_unlock_label(card, 12)
	if unlock_label != null:
		vbox.add_child(unlock_label)

	var evolutions_preview := CardMechanics.make_evolutions_preview(card, 12)
	if evolutions_preview != null:
		vbox.add_child(evolutions_preview)
	CardMechanics.apply_tooltip(reveal_panel, card)
	
	reveal_card_holder.add_child(reveal_panel)
	
	# Auto advance after 2.2 seconds if not skipped
	reveal_timer.start(2.2)

func _finish_current_reveal() -> void:
	reveal_timer.stop()
	if not is_in_reveal:
		return
	if gamble_aftermath_active:
		gamble_aftermath_active = false
		_show_public_reveal(current_drafter, gamble_aftermath_card)
		return
	is_in_reveal = false
	
	# Weitere Picks offen? -> komplett neues Angebot. Der Client wartet auf das
	# Angebot des Hosts, Host und lokales Spiel ziehen selbst.
	if picks_remaining > 0:
		if network_mode and not NetworkManager.is_host:
			if pending_reoffer_ids.is_empty():
				_show_waiting_for_offer()
			else:
				_apply_reoffer(pending_reoffer_ids.duplicate())
		else:
			_start_next_offer()
		return
	
	# Online können Picks eintreffen, während die vorherige Auflösung noch läuft.
	while not pending_remote_picks.is_empty():
		var remote_id: String = pending_remote_picks.pop_front()
		var remote_card = CardDatabase.get_card(remote_id)
		var already_picked := false
		for picked in picked_this_draft:
			if picked.id == remote_id:
				already_picked = true
				break
		if remote_card and not already_picked:
			_commit_pick(remote_card, true)
			return
	
	_process_next_in_queue()

func _finish_entire_draft() -> void:
	_hide_own_card_hover()
	bot_timer.stop()
	reveal_timer.stop()
	picks_remaining = 0
	_set_bonus_source("")
	visible = false
	get_tree().paused = false
	# Pick-/Angebotsstatistik nach jedem abgeschlossenen Draft sichern.
	CardStats.save_statistics()
	if network_mode and NetworkManager.is_host:
		NetworkManager.send_draft_finished()
	draft_sequence_finished.emit()

func _on_bot_auto_pick() -> void:
	if not visible or is_in_reveal or picks_remaining <= 0:
		return
	var random_roll := _authoritative_random_pick()
	if not random_roll and not is_bot_drafting:
		return
	
	var remaining = _remaining_cards()
	if remaining.is_empty():
		_finish_drafter()
		return
	if _gamble_active():
		_bot_gamble_step(remaining)
		return
	
	var chosen: CardData
	if random_roll:
		# Random pick: gleichverteilt aus dem aktuell verbleibenden Angebot.
		chosen = remaining[randi_range(0, remaining.size() - 1)]
		bot_status_label.text = "🎲 Zufällige Karte: %s" % chosen.title
	else:
		# Bot bevorzugt wertvolle Seltenheit und baut vorhandene Talentbäume aus.
		var rarity_rank := BOT_RARITY_RANK
		chosen = remaining[0]
		var best_score := _bot_card_score(chosen, rarity_rank)
		for c in remaining:
			var score := _bot_card_score(c, rarity_rank)
			if score > best_score:
				chosen = c
				best_score = score
	
	_commit_pick(chosen)

func _bot_card_score(card: CardData, rarity_rank: Dictionary) -> int:
	var score := int(rarity_rank.get(card.rarity, 0)) * 10
	# Der Bot baut vorhandene Talentbäume bevorzugt weiter aus.
	if not card.parent_card_id.is_empty():
		score += 18
	return score

# Bot im Gamble: Er sieht die Seltenheit der Rückseiten und dreht weiter, solange
# rechts noch eine Karte liegt, deren Seltenheit mehr verspricht als die offene.
func _bot_gamble_step(remaining: Array[CardData]) -> void:
	if gamble_revealed <= 0 or (gamble_revealed < remaining.size() and _bot_wants_gamble_flip(remaining)):
		_gamble_flip_next()
		bot_status_label.text = "🎰🤖 Bot deckt Karte %d auf..." % gamble_revealed
		bot_status_label.visible = true
		bot_timer.start(0.9)
		return
	_commit_pick(remaining[gamble_revealed - 1])

func _bot_wants_gamble_flip(remaining: Array[CardData]) -> bool:
	var current_score := _bot_card_score(remaining[gamble_revealed - 1], BOT_RARITY_RANK)
	var best_back := 0
	for i in range(gamble_revealed, remaining.size()):
		best_back = maxi(best_back, int(BOT_RARITY_RANK.get(remaining[i].rarity, 0)) * 10)
	return best_back > current_score

func _bonus_source_name() -> String:
	return str(BONUS_SOURCE_NAMES.get(current_bonus_source, current_bonus_source.to_upper()))

# Setzt die Bonus-Quelle des aktuellen Zugs und startet/stoppt den Partikelregen.
func _set_bonus_source(source: String) -> void:
	current_bonus_source = source
	if source == "pinata":
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.8))
	elif source == "gold":
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	elif source == PRE_DRAFT_SOURCE:
		turn_label.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	else:
		turn_label.remove_theme_color_override("font_color")
	if bonus_rain == null:
		return
	if source == "" or source == PRE_DRAFT_SOURCE:
		bonus_rain.stop()
	else:
		bonus_rain.start(source)

# --- Eigene Karten als Liste ------------------------------------------------

func _build_own_cards_bar() -> void:
	own_cards_bar = PanelContainer.new()
	own_cards_bar.name = "OwnCardsBar"
	own_cards_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.88)
	style.set_corner_radius_all(8)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.55, 0.70, 0.65)
	own_cards_bar.add_theme_stylebox_override("panel", style)
	draft_view.add_child(own_cards_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own_cards_bar.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	own_cards_title = Label.new()
	own_cards_title.add_theme_font_size_override("font_size", 12)
	own_cards_title.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 1.0))
	own_cards_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(own_cards_title)

	own_cards_flow = HFlowContainer.new()
	own_cards_flow.add_theme_constant_override("h_separation", 6)
	own_cards_flow.add_theme_constant_override("v_separation", 5)
	own_cards_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(own_cards_flow)
	own_cards_bar.visible = false

	own_card_hover = PanelContainer.new()
	own_card_hover.name = "OwnCardHover"
	own_card_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own_card_hover.top_level = true
	own_card_hover.z_index = 100
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.06, 0.07, 0.10, 0.97)
	hover_style.set_corner_radius_all(6)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0.45, 0.55, 0.70, 0.9)
	hover_style.set_content_margin_all(8)
	own_card_hover.add_theme_stylebox_override("panel", hover_style)
	own_card_hover_label = Label.new()
	own_card_hover_label.add_theme_font_size_override("font_size", 13)
	own_card_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	own_card_hover.add_child(own_card_hover_label)
	main_control.add_child(own_card_hover)
	own_card_hover.visible = false

func _show_own_card_hover(card: CardData) -> void:
	if own_card_hover == null or card == null:
		return
	own_card_hover_label.text = CardMechanics.tooltip(card, true)
	own_card_hover.reset_size()
	own_card_hover.visible = true
	_move_own_card_hover()

func _move_own_card_hover() -> void:
	if own_card_hover == null or not own_card_hover.visible:
		return
	var view_size := main_control.get_viewport_rect().size
	var mouse := main_control.get_global_mouse_position()
	var hover_size := own_card_hover.get_combined_minimum_size()
	# Die Leiste liegt unten, daher das Panel bevorzugt über dem Mauszeiger.
	var pos := mouse + Vector2(14, -hover_size.y - 10)
	if pos.y < 4.0:
		pos.y = mouse.y + 20.0
	pos.x = clampf(pos.x, 4.0, maxf(4.0, view_size.x - hover_size.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, view_size.y - hover_size.y - 4.0))
	own_card_hover.global_position = pos

func _hide_own_card_hover() -> void:
	if own_card_hover != null:
		own_card_hover.visible = false

# Online immer der eigene Slot, lokal (ein Bildschirm) der aktuelle Drafter.
func _own_cards_slot() -> int:
	if Global.network_mode or network_mode:
		if Global.is_spectator:
			return -1
		return Global.local_player_index
	return current_drafter

func _refresh_own_cards_bar() -> void:
	if own_cards_bar == null:
		return
	_hide_own_card_hover()
	var slot := _own_cards_slot()
	if slot < 1:
		own_cards_bar.visible = false
		return
	for child in own_cards_flow.get_children():
		own_cards_flow.remove_child(child)
		child.queue_free()

	var cards := Global.get_player_cards(slot)
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(slot))
	var owner_text := "DEINE KARTEN" if (Global.network_mode or network_mode) else "KARTEN VON %s" % _drafter_name(slot)
	own_cards_title.text = "%s · %s (%d) · TAB HALTEN FÜR DETAILS" % [owner_text, hero.name.to_upper(), cards.size()]
	own_cards_title.add_theme_color_override("font_color", hero.color_tint)
	own_cards_bar.visible = true

	if cards.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Karten."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.55, 0.60, 0.68, 1.0))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		own_cards_flow.add_child(empty)
		return

	# In diesem Draft gewählte Karten werden golden umrandet.
	var new_ids: Array[String] = []
	if slot == current_drafter:
		for picked in picked_this_draft:
			new_ids.append(picked.id)

	var shown := mini(cards.size(), MAX_OWN_CARD_CHIPS)
	for i in range(shown):
		var card: CardData = cards[i]
		own_cards_flow.add_child(_create_own_card_chip(card, new_ids.has(card.id)))

	if cards.size() > shown:
		var more := Label.new()
		more.text = "+%d" % (cards.size() - shown)
		more.add_theme_font_size_override("font_size", 13)
		more.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 1.0))
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		own_cards_flow.add_child(more)

func _create_own_card_chip(card: CardData, is_new: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.14, 0.07, 0.96) if is_new else Color(0.09, 0.11, 0.15, 0.94)
	style.set_corner_radius_all(6)
	style.set_border_width_all(2 if is_new else 1)
	style.border_color = Color(1.0, 0.82, 0.25, 1.0) if is_new else CardDatabase.get_rarity_color(card.rarity)
	style.content_margin_left = 4
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)

	var icon := CardIcon.new()
	icon.setup(card, 22.0, false)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var title := Label.new()
	title.text = ("NEU · " if is_new else "") + card.title
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", card.color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)

	chip.mouse_entered.connect(_show_own_card_hover.bind(card))
	chip.mouse_exited.connect(_hide_own_card_hover)
	chip.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseMotion:
			_move_own_card_hover())
	return chip
