class_name Lobby
extends CanvasLayer

# Wird ausgelöst, wenn die Lobby bestätigt wurde und die Runde starten soll.
signal lobby_confirmed
# Wird ausgelöst, wenn die Lobby verlassen und zum Hauptmenü zurückgekehrt wird.
signal lobby_cancelled

const HERO_IDS: Array[String] = ["ignis", "titan", "volt", "spore"]

@onready var tabs: TabContainer = $Panel/Margin/VBox/Tabs
@onready var status_label: Label = $Panel/Margin/VBox/Header/StatusLabel
@onready var draft_summary: Label = $Panel/Margin/VBox/DraftSummary
@onready var net_label: Label = $Panel/Margin/VBox/NetLabel
@onready var footer_hint: Label = $Panel/Margin/VBox/Footer/FooterHint

# Helden
@onready var p1_title: Label = $Panel/Margin/VBox/Tabs/Heroes/P1_Section/P1_Row/P1_Title
@onready var p1_grid: HBoxContainer = $Panel/Margin/VBox/Tabs/Heroes/P1_Section/P1_Grid
@onready var p1_ready_check: CheckBox = $Panel/Margin/VBox/Tabs/Heroes/P1_Section/P1_Row/P1_ReadyCheck
@onready var p2_title: Label = $Panel/Margin/VBox/Tabs/Heroes/P2_Section/P2_Row/P2_Title
@onready var p2_ready_check: CheckBox = $Panel/Margin/VBox/Tabs/Heroes/P2_Section/P2_Row/P2_ReadyCheck
@onready var p2_grid: HBoxContainer = $Panel/Margin/VBox/Tabs/Heroes/P2_Section/P2_Grid
@onready var p2_bot_check: CheckBox = $Panel/Margin/VBox/Tabs/Heroes/P2_Section/P2_Row/P2_BotCheck

# Regeln
@onready var score_spin: SpinBox = $Panel/Margin/VBox/Tabs/Rules/ScoreRow/ScoreSpin
@onready var base_hp_spin: SpinBox = $Panel/Margin/VBox/Tabs/Rules/BaseHpRow/BaseHpSpin
@onready var picks_spin: SpinBox = $Panel/Margin/VBox/Tabs/Rules/DraftRow/PicksSpin
@onready var offer_spin: SpinBox = $Panel/Margin/VBox/Tabs/Rules/DraftRow/OfferSpin
@onready var ban_count: Label = $Panel/Margin/VBox/Tabs/Rules/BanHeader/BanCount
@onready var unban_btn: Button = $Panel/Margin/VBox/Tabs/Rules/BanHeader/UnbanBtn
@onready var ban_grid: GridContainer = $Panel/Margin/VBox/Tabs/Rules/BanScroll/BanGrid

@onready var back_btn: Button = $Panel/Margin/VBox/Footer/BackBtn
@onready var start_btn: Button = $Panel/Margin/VBox/Footer/StartBtn

func _ready() -> void:
	visible = false
	tabs.set_tab_title(0, "Helden")
	tabs.set_tab_title(1, "Regeln & Karten")

	start_btn.pressed.connect(_on_start_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	unban_btn.pressed.connect(_on_unban_all)
	score_spin.value_changed.connect(_on_score_changed)
	base_hp_spin.value_changed.connect(_on_base_hp_changed)
	offer_spin.value_changed.connect(_on_offer_changed)
	picks_spin.value_changed.connect(_on_picks_changed)
	p2_bot_check.toggled.connect(_on_bot_toggled)
	p1_ready_check.toggled.connect(_on_ready_toggled.bind(1))
	p2_ready_check.toggled.connect(_on_ready_toggled.bind(2))
	Global.banned_cards_changed.connect(_on_banned_cards_changed)
	Global.lobby_state_changed.connect(_on_lobby_state_changed)
	Global.network_status_changed.connect(_refresh_network_status)

	_build_hero_grid(p1_grid, 1)
	_build_hero_grid(p2_grid, 2)
	_build_ban_grid()
	# Summary auch ohne open_lobby() korrekt anzeigen (z. B. beim ersten Aufbau).
	_update_status()

func open_lobby() -> void:
	visible = true
	tabs.current_tab = 0
	if Global.network_mode:
		if Global.is_local_host():
			Global.set_player_ready(1, false)
			if not Global.remote_connected:
				Global.set_player_ready(2, false)
		else:
			Global.set_player_ready(2, false)
	else:
		Global.reset_lobby_state()
	_sync_from_global()
	get_tree().paused = true

func close_lobby() -> void:
	visible = false

# --- Heldenauswahl ---

func _build_hero_grid(grid: HBoxContainer, player_index: int) -> void:
	for hero_id in HERO_IDS:
		var hero: HeroData = Global.get_hero(hero_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 150)
		btn.set_meta("hero_id", hero.id)
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_font_size_override("font_size", 12)
		btn.text = "%s\n[%s]\nHP %d  •  Tempo %d\n%s" % [
			hero.name.to_upper(), hero.role, hero.base_hp, int(hero.base_speed), hero.ability_name
		]
		btn.tooltip_text = "%s\nPassive: %s\nAktiv: %s (%ss Cooldown)\n%s" % [
			hero.name, hero.passive_desc, hero.ability_name, hero.ability_cooldown, hero.description
		]
		btn.pressed.connect(_select_hero.bind(player_index, hero.id))
		grid.add_child(btn)

func _select_hero(player_index: int, hero_id: String) -> void:
	if not Global.can_control_slot(player_index):
		return
	SoundManager.play_sound("click")
	if player_index == 1:
		Global.p1_hero_id = hero_id
	else:
		Global.p2_hero_id = hero_id
	# Heldenwechsel hebt die Bereitschaft dieses Spielers auf (Bots bleiben bereit).
	if not (player_index == 2 and Global.is_bot_enabled):
		Global.set_player_ready(player_index, false)
	_refresh_hero_highlights()
	
	# Online: Host teilt die Änderung mit, Client schickt seine eigene Wahl zum Host.
	if Global.network_mode:
		if Global.is_local_host():
			NetworkManager.sync_lobby()
		else:
			NetworkManager.request_hero(hero_id)

func _refresh_hero_highlights() -> void:
	_highlight_grid(p1_grid, Global.p1_hero_id)
	_highlight_grid(p2_grid, Global.p2_hero_id)

func _highlight_grid(grid: HBoxContainer, hero_id: String) -> void:
	for child in grid.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var is_selected: bool = btn.get_meta("hero_id", "") == hero_id
		btn.modulate = Color(1.0, 1.0, 0.8, 1.0) if is_selected else Color(1.0, 1.0, 1.0, 0.75)

func _on_bot_toggled(enabled: bool) -> void:
	SoundManager.play_sound("click")
	if Global.network_mode:
		# Im Online-Spiel gibt es keinen Bot-Slot.
		p2_bot_check.set_pressed_no_signal(false)
		return
	Global.set_bot_enabled(enabled)
	_update_titles()

func _on_ready_toggled(ready: bool, player_index: int) -> void:
	if not Global.can_control_slot(player_index):
		_refresh_ready_checks()
		return
	SoundManager.play_sound("click")
	Global.set_player_ready(player_index, ready)
	if Global.network_mode and not Global.is_local_host() and player_index == 2:
		NetworkManager.send_ready_state(ready)

func _on_lobby_state_changed() -> void:
	# Hält auch beim Client alle Anzeigen (Helden, Regeln, Bans, Ready) aktuell.
	_sync_from_global()

func _refresh_ready_checks() -> void:
	p1_ready_check.set_pressed_no_signal(Global.is_player_ready(1))
	p2_ready_check.set_pressed_no_signal(Global.is_player_ready(2))
	# Jeder steuert online nur seinen eigenen Slot; lokal darf P1 beide setzen.
	p1_ready_check.disabled = not Global.can_control_slot(1)
	p2_ready_check.disabled = Global.is_bot_enabled or not Global.can_control_slot(2)
	p2_ready_check.text = "Bot ist bereit" if Global.is_bot_enabled else "Bereit"

func _refresh_hero_controls() -> void:
	var can_p1 := Global.can_control_slot(1)
	var can_p2 := Global.can_control_slot(2)
	for child in p1_grid.get_children():
		child.disabled = not can_p1
	for child in p2_grid.get_children():
		child.disabled = not can_p2
	p2_bot_check.disabled = Global.network_mode

func _refresh_host_controls() -> void:
	# Match-Regeln und Kartenbans darf nur der Host ändern.
	var is_host := Global.is_local_host()
	score_spin.editable = is_host
	base_hp_spin.editable = is_host
	picks_spin.editable = is_host
	offer_spin.editable = is_host
	unban_btn.disabled = not is_host
	for child in ban_grid.get_children():
		var cb := child as CheckButton
		if cb:
			cb.disabled = not is_host

func _update_titles() -> void:
	if Global.network_mode:
		p1_title.text = "SPIELER 1 (HOST) – HELD WÄHLEN"
		if Global.is_local_host():
			if Global.remote_connected:
				p2_title.text = "SPIELER 2 (ONLINE) – HELD WÄHLEN"
			else:
				p2_title.text = "SPIELER 2 – WARTE AUF MITSPIELER"
		else:
			p1_title.text = "SPIELER 1 (HOST)"
			p2_title.text = "SPIELER 2 (DU) – HELD WÄHLEN"
		return
	if Global.is_bot_enabled:
		p2_title.text = "SPIELER 2 / BOT – HELD WÄHLEN"
	else:
		p2_title.text = "SPIELER 2 – HELD WÄHLEN"

# --- Match-Regeln ---

func _on_score_changed(value: float) -> void:
	Global.set_score_to_win(int(value))
	_update_status()

func _on_base_hp_changed(value: float) -> void:
	Global.set_base_hp_override(int(value))
	_update_status()

func _on_offer_changed(value: float) -> void:
	var offered := int(value)
	picks_spin.max_value = offered
	if int(picks_spin.value) > offered:
		picks_spin.set_value_no_signal(offered)
	Global.set_draft_config(int(picks_spin.value), offered)
	_update_status()

func _on_picks_changed(value: float) -> void:
	Global.set_draft_config(int(value), int(offer_spin.value))
	_update_status()

# --- Karten sperren ---

func _build_ban_grid() -> void:
	for card in CardDatabase.all_cards:
		var cb := CheckButton.new()
		var class_tag := ""
		var class_hint := ""
		if not card.hero_id.is_empty():
			var hero: HeroData = Global.get_hero(card.hero_id)
			class_tag = " [%s]" % hero.name
			class_hint = "\nKlassenkarte: nur für %s." % hero.name
		if not card.parent_card_id.is_empty():
			var parent_card := CardDatabase.get_card(card.parent_card_id)
			var parent_title := parent_card.title if parent_card else card.parent_card_id
			class_tag += " [Talent: %s]" % parent_title
			class_hint += "\nAusbaukarte: erscheint nur mit %s im Deck." % parent_title
		cb.text = "%s (%s)%s" % [card.title, card.rarity, class_tag]
		cb.tooltip_text = card.description + class_hint
		cb.add_theme_color_override("font_color", card.color)
		cb.set_meta("card_id", card.id)
		cb.toggled.connect(_on_ban_toggled.bind(card.id, cb))
		ban_grid.add_child(cb)

func _on_ban_toggled(pressed: bool, card_id: String, checkbox: CheckButton) -> void:
	if not Global.is_local_host():
		_refresh_ban_states()
		return
	if pressed:
		# Es müssen immer genug Karten für das komplette Angebot verfügbar bleiben.
		# Klassenspezifische Karten zählen nur für den jeweiligen Helden, daher
		# prüfen wir den kleineren Vorrat beider Helden.
		var available_after := Global.get_available_card_count_for_match(card_id)
		var needed := maxi(1, Global.cards_per_draft)
		if available_after < needed:
			checkbox.set_pressed_no_signal(false)
			SoundManager.play_sound("bounce", 0.2, 0.0)
			status_label.text = "Mindestens %d Karte(n) müssen für das Angebot verfügbar bleiben." % needed
			return
	Global.set_card_banned(card_id, pressed)
	SoundManager.play_sound("click")

func _on_banned_cards_changed() -> void:
	_refresh_ban_states()
	_update_status()

func _refresh_ban_states() -> void:
	for child in ban_grid.get_children():
		var cb := child as CheckButton
		if cb == null:
			continue
		cb.set_pressed_no_signal(Global.is_card_banned(cb.get_meta("card_id", "")))

func _on_unban_all() -> void:
	SoundManager.play_sound("click")
	if Global.banned_card_ids.is_empty():
		return
	Global.banned_card_ids.clear()
	Global.banned_cards_changed.emit()

# --- Status / Sync ---

func _sync_from_global() -> void:
	score_spin.set_value_no_signal(Global.score_to_win)
	base_hp_spin.set_value_no_signal(Global.base_hp_override)
	offer_spin.set_value_no_signal(Global.cards_per_draft)
	picks_spin.max_value = Global.cards_per_draft
	picks_spin.set_value_no_signal(Global.draft_picks)
	p2_bot_check.set_pressed_no_signal(Global.is_bot_enabled)
	_refresh_hero_highlights()
	_refresh_ban_states()
	_refresh_ready_checks()
	_refresh_host_controls()
	_refresh_hero_controls()
	_refresh_network_status()
	_update_titles()
	_update_status()

func _refresh_network_status() -> void:
	if not Global.network_mode:
		net_label.visible = false
		footer_hint.text = "Lokal: Spieler 1 stellt Regeln und Bot-Steuerung hier in der Lobby ein."
		return
	
	net_label.visible = true
	var role := "HOST" if Global.is_local_host() else "CLIENT"
	var info := NetworkManager.network_info
	if info.is_empty():
		info = Global.network_info
	net_label.text = "ONLINE (%s): %s" % [role, info]
	footer_hint.text = "Online: Der Host legt Regeln und Kartenbans fest. Jeder wählt seinen eigenen Helden und bestätigt Bereit."

func _update_status() -> void:
	var total_cards := CardDatabase.all_cards.size()
	# Der Vorrat wird pro Held berechnet: Klassenkarten zählen nur beim passenden
	# Helden. Für den Start müssen beide Helden genug Karten angeboten bekommen.
	var available := Global.get_available_card_count_for_match()
	var p1_available := Global.get_available_card_count_for_hero(Global.p1_hero_id)
	var p2_available := Global.get_available_card_count_for_hero(Global.p2_hero_id)
	ban_count.text = "%d von %d gesperrt" % [Global.banned_card_ids.size(), total_cards]
	var hp_text := "Heldenwert" if Global.base_hp_override <= 0 else str(Global.base_hp_override)
	draft_summary.text = "Draft: %d von %d Karten  •  Match: %d Siege  •  Basis-HP: %s  •  %d / %d Karten (P1/P2)" % [
		Global.draft_picks, Global.cards_per_draft, Global.score_to_win, hp_text, p1_available, p2_available
	]

	var enough_cards := available >= Global.cards_per_draft
	var is_host := Global.is_local_host()
	var all_ready := Global.all_players_ready()
	start_btn.disabled = not (enough_cards and is_host and all_ready)

	if not enough_cards:
		status_label.text = "Zu viele Karten gesperrt – mindestens %d müssen für beide Helden verfügbar sein." % Global.cards_per_draft
	elif not is_host:
		if Global.network_mode and not Global.is_player_ready(2):
			status_label.text = "Wähle deinen Helden und setze dich bereit."
		else:
			status_label.text = "Bereit – warte auf den Host, er startet das Match."
	elif Global.network_mode and not Global.remote_connected:
		status_label.text = "Warte auf Mitspieler..."
	elif not all_ready:
		var waiting: Array[String] = []
		if not Global.is_player_ready(1):
			waiting.append("Spieler 1")
		if not Global.is_player_ready(2):
			waiting.append("Spieler 2")
		status_label.text = "Warte auf: %s" % ", ".join(waiting)
	else:
		var prefix := "Online-Match" if Global.network_mode else "Match"
		status_label.text = "%s: Alle bereit ✓ – der Host kann starten." % prefix

# --- Bestätigen / Verlassen ---

func _on_start_pressed() -> void:
	if not Global.is_local_host():
		status_label.text = "Nur der Host kann das Match starten."
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	if not Global.all_players_ready():
		status_label.text = "Beide Spieler müssen bereit sein."
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	if Global.network_mode and not Global.remote_connected:
		status_label.text = "Warte auf einen Mitspieler, bevor du startest."
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	if Global.get_available_card_count_for_match() < Global.cards_per_draft:
		status_label.text = "Zu viele Karten gesperrt – mindestens %d müssen für beide Helden verfügbar sein." % Global.cards_per_draft
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return

	SoundManager.play_sound("confirm")
	visible = false
	get_tree().paused = false
	lobby_confirmed.emit()

func _on_back_pressed() -> void:
	SoundManager.play_sound("click")
	visible = false
	get_tree().paused = false
	lobby_cancelled.emit()
