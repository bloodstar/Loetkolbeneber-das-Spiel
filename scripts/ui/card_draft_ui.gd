class_name CardDraftUI
extends CanvasLayer

signal draft_sequence_finished

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
	
	network_mode = NetworkManager.is_host and NetworkManager.has_clients()
	pending_network_pick = false
	pending_remote_picks.clear()
	bot_timer.stop()
	reveal_timer.stop()
	is_in_reveal = false
	visible = true
	draft_tabs.current_tab = 0
	get_tree().paused = true
	_process_next_in_queue()

# Wird auf dem Client aufgerufen, wenn der Host das Kartenangebot geschickt hat.
func start_network_draft(drafter: int, card_ids: Array, picks_total_count: int) -> void:
	if card_ids.is_empty():
		return
	SoundManager.play_sound("confirm", 0.2, 0.0)
	draft_queue.clear()
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
	picked_this_draft.clear()
	is_bot_drafting = false
	offered_cards.clear()
	for card_id in card_ids:
		var card = CardDatabase.get_card(str(card_id))
		if card:
			offered_cards.append(card)
	if not offered_cards.is_empty():
		CardStats.record_offer(offered_cards)
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
	is_bot_drafting = Global.is_bot_slot(current_drafter)
	local_owner = (not network_mode) or current_drafter == Global.local_player_index

	# Kartenangebot einmal pro Drafter ziehen. Besessene und gesperrte Karten
	# ausschließen. Ausbaukarten erscheinen nur mit ihrer Grundkarte; offene
	# Zweige einer Familie werden gemeinsam angeboten. Seltene Karten werden
	# seltener gezogen (einstellbar über die Seltenheits-Gewichtung).
	var owned_ids := Global.get_owned_card_ids(current_drafter)
	var exclude: Array = owned_ids.duplicate()
	exclude.append_array(Global.banned_card_ids)
	var drafter_hero_id: String = Global.get_player_hero_id(current_drafter)
	offered_cards = CardDatabase.get_draft_offer(Global.cards_per_draft, exclude, drafter_hero_id, owned_ids)
	
	if offered_cards.is_empty():
		# Keine Karten verfügbar (z. B. alles gesperrt) -> diesen Drafter überspringen.
		_process_next_in_queue()
		return
	
	CardStats.record_offer(offered_cards)
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
	var blind_hidden := _blind_pick_hidden()
	var random_auto := _authoritative_random_pick()
	
	turn_label.text = "UPGRADE-PHASE: %s – PICK %d/%d" % [drafter_name, pick_number, picks_total]
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
		subtitle_label.text = "Wähle %d von %d Karten. Alle sehen die Auswahl live!" % [picks_total, offered_cards.size()]
	
	if random_auto:
		bot_status_label.text = "🎲 Zufällige Karte wird gezogen (Pick %d/%d)..." % [pick_number, picks_total]
		bot_status_label.visible = true
		bot_timer.start(0.9)
	elif is_bot_drafting:
		if blind_hidden:
			bot_status_label.text = "🙈🤖 Bot wählt verdeckt (Pick %d/%d)..." % [pick_number, picks_total]
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
		bot_status_label.text = "Wähle mit Maus oder Zifferntaste (1-%d)" % _remaining_cards().size()
		bot_status_label.visible = true
		bot_timer.stop()
	
	_populate_cards()

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
	return Global.random_pick_enabled

# Nur der Host (bzw. der lokale Modus ohne Netzwerk) darf Random-Picks ziehen.
func _authoritative_random_pick() -> bool:
	return _random_pick_active() and (not network_mode or NetworkManager.is_host)

func _local_can_manual_pick() -> bool:
	if is_bot_drafting or pending_network_pick or _random_pick_active():
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
	if Global.network_mode and index == Global.local_player_index:
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
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
	
	var remaining = _remaining_cards()
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

func _create_card_button(card: CardData, slot_index: int) -> PanelContainer:
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
	
	# In reveal mode, Space or Enter continues (im Online-Modus bestimmt der Timer das Tempo).
	if is_in_reveal:
		if not network_mode and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE)):
			_finish_current_reveal()
			get_viewport().set_input_as_handled()
		return
	
	# Keyboard shortcuts 1-9 during draft
	if _local_can_manual_pick() and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx = event.keycode - KEY_1
			var remaining = _remaining_cards()
			if idx < remaining.size():
				_commit_pick(remaining[idx])
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
	CardStats.record_pick(card.id)
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
	var blind_hidden := _blind_pick_hidden()
	if blind_hidden:
		var hidden_action := "EINE ZUFÄLLIGE KARTE GEZOGEN" if _random_pick_active() else "EINE KARTE GEWÄHLT"
		reveal_header.text = "🙈 BLIND PICK: %s HAT %s! (PICK %d/%d)" % [drafter_name, hidden_action, pick_number, picks_total]
	elif _blind_pick_active():
		var blind_label := "DEINE BLIND-ZUFALLSWAHL" if _random_pick_active() else "DEINE BLIND-WAHL"
		reveal_header.text = "🔒 %s: %s! (PICK %d/%d)" % [blind_label, card.title.to_upper(), pick_number, picks_total]
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
	CardMechanics.apply_tooltip(reveal_panel, card)
	
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
		picks_remaining = 0
		_process_next_in_queue()
		return
	
	var chosen: CardData
	if random_roll:
		# Random pick: gleichverteilt aus dem aktuell verbleibenden Angebot.
		chosen = remaining[randi_range(0, remaining.size() - 1)]
		bot_status_label.text = "🎲 Zufällige Karte: %s" % chosen.title
	else:
		# Bot bevorzugt wertvolle Seltenheit und baut vorhandene Talentbäume aus.
		var rarity_rank := {"Common": 1, "Uncommon": 2, "Rare": 3, "Epic": 4, "Legendary": 5}
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
