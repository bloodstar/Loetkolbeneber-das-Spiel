class_name CardDraftUI
extends CanvasLayer

signal draft_sequence_finished

@onready var main_control: Control = $MainControl
@onready var draft_view: VBoxContainer = $MainControl/DraftView
@onready var reveal_view: PanelContainer = $MainControl/RevealView

# Draft view nodes
@onready var turn_label: Label = $MainControl/DraftView/TurnLabel
@onready var subtitle_label: Label = $MainControl/DraftView/SubtitleLabel
@onready var cards_container: HBoxContainer = $MainControl/DraftView/CardsContainer
@onready var bot_status_label: Label = $MainControl/DraftView/BotStatusLabel

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

func _ready() -> void:
	visible = false
	draft_view.visible = true
	reveal_view.visible = false
	bot_timer.timeout.connect(_on_bot_auto_pick)
	reveal_timer.timeout.connect(_finish_current_reveal)
	continue_btn.pressed.connect(_finish_current_reveal)

func start_draft_sequence(losers: Array[int]) -> void:
	draft_queue = losers.duplicate()
	if draft_queue.is_empty():
		_finish_entire_draft()
		return
	
	network_mode = NetworkManager.is_host and NetworkManager.has_client()
	pending_network_pick = false
	pending_remote_picks.clear()
	visible = true
	get_tree().paused = true
	_process_next_in_queue()

# Wird auf dem Client aufgerufen, wenn der Host das Kartenangebot geschickt hat.
func start_network_draft(drafter: int, card_ids: Array, picks_total_count: int) -> void:
	if card_ids.is_empty():
		return
	SoundManager.play_sound("confirm", 0.2, 0.0)
	draft_queue.clear()
	visible = true
	get_tree().paused = true
	network_mode = true
	current_drafter = drafter
	local_owner = (drafter == Global.local_player_index)
	pending_network_pick = false
	pending_remote_picks.clear()
	picked_this_draft.clear()
	is_bot_drafting = false
	offered_cards.clear()
	for card_id in card_ids:
		var card = CardDatabase.get_card(str(card_id))
		if card:
			offered_cards.append(card)
	picks_total = mini(picks_total_count, offered_cards.size())
	picks_remaining = picks_total
	if picks_total <= 0:
		_finish_entire_draft()
		return
	_start_current_pick()

func close_draft() -> void:
	bot_timer.stop()
	reveal_timer.stop()
	visible = false
	draft_view.visible = true
	reveal_view.visible = false
	is_in_reveal = false
	picks_remaining = 0
	pending_network_pick = false
	pending_remote_picks.clear()
	get_tree().paused = false

func _process_next_in_queue() -> void:
	if draft_queue.is_empty():
		_finish_entire_draft()
		return
	
	current_drafter = draft_queue.pop_front()
	is_in_reveal = false
	pending_network_pick = false
	pending_remote_picks.clear()
	picked_this_draft.clear()
	is_bot_drafting = (current_drafter == 2 and Global.is_bot_enabled)
	local_owner = (not network_mode) or current_drafter == Global.local_player_index
	
	# Kartenangebot einmal pro Drafter ziehen. Besessene und gesperrte Karten
	# ausschließen. Ausbaukarten erscheinen nur mit ihrer Grundkarte; offene
	# Zweige einer Familie werden gemeinsam angeboten.
	var owned_ids := Global.get_owned_card_ids(current_drafter)
	var exclude: Array = owned_ids.duplicate()
	exclude.append_array(Global.banned_card_ids)
	var drafter_hero_id: String = Global.p1_hero_id if current_drafter == 1 else Global.p2_hero_id
	offered_cards = CardDatabase.get_draft_offer(Global.cards_per_draft, exclude, drafter_hero_id, owned_ids)
	
	if offered_cards.is_empty():
		# Keine Karten verfügbar (z. B. alles gesperrt) -> diesen Drafter überspringen.
		_process_next_in_queue()
		return
	
	picks_total = mini(Global.draft_picks, offered_cards.size())
	picks_remaining = picks_total
	
	# Host schickt das identische Angebot an den Client.
	if network_mode and NetworkManager.is_host:
		var ids: Array = []
		for c in offered_cards:
			ids.append(c.id)
		NetworkManager.send_draft_start(current_drafter, ids, picks_total)
	
	_start_current_pick()

func _start_current_pick() -> void:
	is_in_reveal = false
	draft_view.visible = true
	reveal_view.visible = false
	
	var pick_number = picks_total - picks_remaining + 1
	var drafter_name = _drafter_name(current_drafter)
	
	turn_label.text = "UPGRADE-PHASE: %s – PICK %d/%d" % [drafter_name, pick_number, picks_total]
	subtitle_label.text = "Wähle %d von %d Karten. Alle sehen die Auswahl live!" % [picks_total, offered_cards.size()]
	
	if is_bot_drafting:
		bot_status_label.text = "🤖 Bot analysiert Synergien und wählt (Pick %d/%d)..." % [pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.start(1.4)
	elif network_mode and not local_owner:
		bot_status_label.text = "%s wählt gerade (Pick %d/%d)..." % [drafter_name, pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.stop()
	else:
		bot_status_label.text = "Wähle mit Maus oder Zifferntaste (1-%d)" % _remaining_cards().size()
		bot_status_label.visible = true
		bot_timer.stop()
	
	_populate_cards()

func _drafter_name(index: int) -> String:
	if index == 2 and Global.is_bot_enabled:
		return "BOT"
	return "SPIELER 1" if index == 1 else "SPIELER 2"

func _talent_badge_text(card: CardData) -> String:
	if card.parent_card_id.is_empty():
		return ""
	var base := CardDatabase.get_card(card.parent_card_id)
	var base_title := base.title if base else card.parent_card_id
	var branch := card.evolution_branch if not card.evolution_branch.is_empty() else "?"
	return "TALENTBAUM: %s  •  ZWEIG %s" % [base_title.to_upper(), branch]

func _remaining_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for card in offered_cards:
		var already_picked := false
		for picked in picked_this_draft:
			if picked.id == card.id:
				already_picked = true
				break
		if not already_picked:
			result.append(card)
	return result

func _populate_cards() -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	
	var remaining = _remaining_cards()
	for i in range(remaining.size()):
		var card_panel = _create_card_button(remaining[i], i + 1)
		cards_container.add_child(card_panel)

func _create_card_button(card: CardData, slot_index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 310)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.13, 0.17, 0.96)
	style.set_corner_radius_all(10)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = card.color
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Key indicator + Rarity
	var top_row = HBoxContainer.new()
	var key_badge = Label.new()
	key_badge.text = "[%d]" % slot_index
	key_badge.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	top_row.add_child(key_badge)
	
	var rarity_label = Label.new()
	rarity_label.text = card.rarity.to_upper()
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_label.add_theme_color_override("font_color", card.color)
	top_row.add_child(rarity_label)
	vbox.add_child(top_row)
	
	# Klassen-Badge für klassenspezifische Karten
	if not card.hero_id.is_empty():
		var hero: HeroData = Global.get_hero(card.hero_id)
		var class_label = Label.new()
		class_label.text = "KLASSE: %s" % hero.name.to_upper()
		class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_label.add_theme_color_override("font_color", hero.color_tint)
		class_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(class_label)

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
	desc.text = card.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	vbox.add_child(desc)
	
	# Select Button
	var btn = Button.new()
	btn.text = "WÄHLEN [%d]" % slot_index
	btn.custom_minimum_size = Vector2(0, 34)
	btn.pressed.connect(func(): _select_card(card))
	
	if is_bot_drafting or pending_network_pick or (network_mode and not local_owner):
		btn.disabled = true
	
	vbox.add_child(btn)
	return panel

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# In reveal mode, Space or Enter continues (im Online-Modus bestimmt der Timer das Tempo).
	if is_in_reveal:
		if not network_mode and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)):
			_finish_current_reveal()
			get_viewport().set_input_as_handled()
		return
	
	# Keyboard shortcuts 1-9 during draft
	if not is_bot_drafting and not pending_network_pick and not (network_mode and not local_owner) and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			var remaining = _remaining_cards()
			if idx < remaining.size():
				_commit_pick(remaining[idx])
				get_viewport().set_input_as_handled()

func _select_card(card: CardData) -> void:
	if is_bot_drafting or pending_network_pick or (network_mode and not local_owner):
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
	
	# Client schickt die Wahl zum Host; erst der Host wendet sie verbindlich an.
	if network_mode and not from_network and not NetworkManager.is_host:
		pending_network_pick = true
		NetworkManager.request_draft_pick(card.id)
		bot_status_label.text = "Auswahl wird an den Host übertragen..."
		bot_status_label.visible = true
		_populate_cards()
		return
	
	SoundManager.play_sound("confirm", 0.1, 0.0)
	if not Global.add_card_to_player(current_drafter, card):
		return
	picked_this_draft.append(card)
	picks_remaining -= 1
	_show_public_reveal(current_drafter, card)
	
	if network_mode and NetworkManager.is_host:
		NetworkManager.send_draft_pick(card.id)

# Wird auf beiden Seiten angewendet: Host nach Client-Wahl, Client nach Host-Bestätigung.
func apply_network_pick(card_id: String) -> void:
	pending_network_pick = false
	# Nur Karten akzeptieren, die auch wirklich im aktuellen Angebot waren.
	var is_offered := false
	for offered in offered_cards:
		if offered.id == card_id:
			is_offered = true
			break
	if not is_offered:
		return
	# Wenn gerade die Auflösung des vorherigen Picks läuft, Wahl zwischenspeichern.
	if is_in_reveal:
		pending_remote_picks.append(card_id)
		return
	var card = CardDatabase.get_card(card_id)
	if card:
		_commit_pick(card, true)

func _show_public_reveal(drafter_idx: int, card: CardData) -> void:
	is_in_reveal = true
	draft_view.visible = false
	reveal_view.visible = true
	# Im Online-Modus darf die Auflösung nicht übersprungen werden, sonst könnten
	# Host und Client bei mehreren Picks auseinanderlaufen.
	continue_btn.disabled = network_mode
	
	var drafter_name = _drafter_name(drafter_idx)
	var pick_number = picks_total - picks_remaining
	reveal_header.text = "📢 ÖFFENTLICHE WAHL: %s WÄHLT %s! (PICK %d/%d)" % [drafter_name, card.title.to_upper(), pick_number, picks_total]
	
	# Clear previous reveal card
	for child in reveal_card_holder.get_children():
		child.queue_free()
	
	var reveal_panel = PanelContainer.new()
	reveal_panel.custom_minimum_size = Vector2(260, 360)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.22, 0.98)
	style.set_corner_radius_all(12)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = card.color
	reveal_panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	reveal_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	var rarity = Label.new()
	rarity.text = "⭐ " + card.rarity.to_upper() + " ⭐"
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", card.color)
	rarity.add_theme_font_size_override("font_size", 16)
	vbox.add_child(rarity)
	
	if not card.hero_id.is_empty():
		var hero: HeroData = Global.get_hero(card.hero_id)
		var class_label = Label.new()
		class_label.text = "KLASSE: %s" % hero.name.to_upper()
		class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_label.add_theme_color_override("font_color", hero.color_tint)
		class_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(class_label)

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
	desc.text = card.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 15)
	vbox.add_child(desc)
	
	reveal_card_holder.add_child(reveal_panel)
	
	# Auto advance after 2.2 seconds if not skipped
	reveal_timer.start(2.2)

func _finish_current_reveal() -> void:
	reveal_timer.stop()
	if not is_in_reveal:
		return
	is_in_reveal = false
	
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
	
	# Weitere Picks offen? -> gleiche Kartenauswahl erneut anzeigen.
	if picks_remaining > 0 and not _remaining_cards().is_empty():
		_start_current_pick()
	else:
		_process_next_in_queue()

func _finish_entire_draft() -> void:
	bot_timer.stop()
	reveal_timer.stop()
	picks_remaining = 0
	visible = false
	get_tree().paused = false
	if network_mode and NetworkManager.is_host:
		NetworkManager.send_draft_finished()
	draft_sequence_finished.emit()

func _on_bot_auto_pick() -> void:
	if not visible or not is_bot_drafting or is_in_reveal or picks_remaining <= 0:
		return
	
	var remaining = _remaining_cards()
	if remaining.is_empty():
		picks_remaining = 0
		_process_next_in_queue()
		return
	
	# Bot bevorzugt wertvolle Seltenheit und baut vorhandene Talentbäume aus.
	var rarity_rank := {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5}
	var chosen: CardData = remaining[0]
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
