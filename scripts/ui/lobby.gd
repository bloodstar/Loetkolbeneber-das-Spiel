class_name Lobby
extends CanvasLayer

# Wird ausgelöst, wenn die Lobby bestätigt wurde und die Runde starten soll.
signal lobby_confirmed
# Wird ausgelöst, wenn die Lobby verlassen und zum Hauptmenü zurückgekehrt wird.
signal lobby_cancelled

const HERO_IDS: Array[String] = [
	"ignis", "volt", "spore", "nova",
	"klinge", "bastion", "phantom",
]
const HERO_ICON_DIR: String = "res://assets/ui/"

@onready var tabs: TabContainer = $Panel/Margin/VBox/Tabs
@onready var status_label: Label = $Panel/Margin/VBox/Header/StatusLabel
@onready var player_count_spin: SpinBox = $Panel/Margin/VBox/Header/PlayerCountSpin
@onready var draft_summary: Label = $Panel/Margin/VBox/DraftSummary
@onready var net_label: Label = $Panel/Margin/VBox/NetLabel
@onready var footer_hint: Label = $Panel/Margin/VBox/Footer/FooterHint

# Heldenslots (dynamisch für 1..6 aufgebaut)
@onready var slot_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Heroes/HeroesScroll/SlotList

# Die Inhalte von "Charakter", "Regeln" und "Karten" werden im Skript
# aufgebaut, damit die Lobby auch bei kleineren Fenstern flexibel bleibt.
@onready var character_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Charakter
@onready var rules_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Rules
@onready var cards_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Cards

@onready var back_btn: Button = $Panel/Margin/VBox/Footer/BackBtn
@onready var ready_btn: Button = $Panel/Margin/VBox/Footer/ReadyBtn
@onready var start_btn: Button = $Panel/Margin/VBox/Footer/StartBtn

# Die Bereit-Anzeigen in den Heldenslots und der Footer-Button teilen sich
# dieselben Farben: grün = bereit, neutral = noch nicht bereit.
var _ready_display_on: StyleBoxFlat
var _ready_display_off: StyleBoxFlat
var _ready_button_on: StyleBoxFlat
var _ready_button_off: StyleBoxFlat

# Regel-Controls
var score_spin: SpinBox
var survival_spin: SpinBox
var kill_spin: SpinBox
var base_hp_spin: SpinBox
var base_damage_spin: SpinBox
var picks_spin: SpinBox
var offer_spin: SpinBox
var blind_pick_check: CheckButton
var random_pick_check: CheckButton
var map_option: OptionButton
var map_info_label: Label
var mode_option: OptionButton
var mode_info_label: Label
var loadout_option: OptionButton
var loadout_name_edit: LineEdit
var loadout_load_btn: Button
var loadout_save_btn: Button
var loadout_delete_btn: Button
var loadout_desc_label: Label
var loadout_status: Label
var loadout_refreshing: bool = false

# Karten-Controls
var pool_checks: Dictionary = {}
var all_pools_btn: Button
var pool_count_label: Label
var rarity_spins: Dictionary = {}
var rarity_sum_label: Label
var ban_count: Label
var unban_btn: Button
var ban_sections: VBoxContainer
var ban_checks: Dictionary = {}
var ban_icons: Dictionary = {}

# Charakter-Controls
var fur_picker: ColorPickerButton = null
var eye_picker: ColorPickerButton = null
var pants_picker: ColorPickerButton = null
var wand_tip_picker: ColorPickerButton = null
var shot_color_picker: ColorPickerButton = null
var wand_shape_option: OptionButton = null
var character_preview: PigCharacter = null
var character_preview_wand: MagicWand = null
var character_preview_wand_pivot: Node2D = null
var character_hero_icon: TextureRect = null
var character_hint: Label = null
var character_slot_label: Label = null
var character_slot_option: OptionButton = null
var _character_ui_ready: bool = false
var _updating_character_ui: bool = false
var _character_slot: int = 1
var _character_slot_signature: String = ""

# slot_index -> { section, title, hero_icon, kind, ready, grid }
var slot_nodes: Dictionary = {}
var _hero_icon_cache: Dictionary = {}

func _ready() -> void:
	visible = false
	tabs.set_tab_title(0, "Helden")
	tabs.set_tab_title(1, "Charakter")
	tabs.set_tab_title(2, "Regeln")
	tabs.set_tab_title(3, "Karten")

	start_btn.pressed.connect(_on_start_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	player_count_spin.value_changed.connect(_on_player_count_changed)
	Global.banned_cards_changed.connect(_on_banned_cards_changed)
	Global.card_pools_changed.connect(_on_card_pools_changed)
	Global.map_changed.connect(_on_map_changed)
	Global.match_mode_changed.connect(_on_match_mode_changed)
	Global.lobby_state_changed.connect(_on_lobby_state_changed)
	Global.lobby_loadouts_changed.connect(_on_lobby_loadouts_changed)
	Global.pig_appearance_changed.connect(_on_pig_appearance_changed)
	Global.network_status_changed.connect(_refresh_network_status)
	NetworkManager.slot_assigned.connect(_on_slot_assigned)
	NetworkManager.ping_updated.connect(_refresh_network_status)
	tabs.tab_changed.connect(_on_lobby_tab_changed)
	CardStats.rarity_changed.connect(_on_card_rarity_changed)

	_build_ready_styles()
	_build_slot_list()
	_build_character_tab()
	_build_rules_tab()
	_build_cards_tab()
	# Summary auch ohne open_lobby() korrekt anzeigen.
	_sync_from_global()

func open_lobby() -> void:
	visible = true
	tabs.current_tab = 0
	if Global.network_mode:
		if Global.is_local_host():
			Global.set_player_ready(1, false)
		else:
			Global.set_player_ready(Global.local_player_index, false)
	else:
		Global.reset_lobby_state()
	_sync_from_global()
	get_tree().paused = true

func close_lobby() -> void:
	visible = false

func _build_ready_styles() -> void:
	_ready_display_on = _make_status_style(
		Color(0.08, 0.30, 0.15, 0.95),
		Color(0.30, 0.82, 0.42, 0.95)
	)
	_ready_display_off = _make_status_style(
		Color(0.09, 0.11, 0.16, 0.55),
		Color(0.28, 0.33, 0.43, 0.65)
	)
	_ready_button_on = _make_status_style(
		Color(0.10, 0.40, 0.18, 1.0),
		Color(0.38, 0.95, 0.52, 1.0)
	)
	_ready_button_off = _make_status_style(
		Color(0.12, 0.15, 0.22, 0.98),
		Color(0.30, 0.38, 0.50, 1.0)
	)

func _make_status_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

# --- Heldenslots ---

func _build_slot_list() -> void:
	for child in slot_list.get_children():
		slot_list.remove_child(child)
		child.queue_free()
	slot_nodes.clear()

	for i in range(1, Global.MAX_PLAYERS + 1):
		var section := VBoxContainer.new()
		section.add_theme_constant_override("separation", 3)
		slot_list.add_child(section)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		section.add_child(row)

		var hero_icon := TextureRect.new()
		hero_icon.custom_minimum_size = Vector2(28, 28)
		hero_icon.texture = _get_hero_icon(Global.get_player_hero_id(i))
		hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hero_icon)

		var title := Label.new()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 15)
		row.add_child(title)

		var kind := OptionButton.new()
		kind.add_item("Bot", 0)
		kind.add_item("Mensch", 1)
		kind.item_selected.connect(_on_kind_selected.bind(i))
		row.add_child(kind)

		# Reine Statusanzeige: Die Bereitschaft wird unten neben "Kampf
		# starten" gesetzt. Der CheckBox-Hintergrund wird bei Bereitschaft grün.
		var ready := CheckBox.new()
		ready.text = "Bereit"
		ready.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ready.focus_mode = Control.FOCUS_NONE
		ready.tooltip_text = "Anzeige: Bereitschaft dieses Slots"
		row.add_child(ready)

		var grid := HBoxContainer.new()
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("separation", 6)
		section.add_child(grid)
		for hero_id in HERO_IDS:
			var hero: HeroData = Global.get_hero(hero_id)
			var btn := _create_hero_button(hero)
			btn.pressed.connect(_select_hero.bind(i, hero.id))
			grid.add_child(btn)

		slot_nodes[i] = {
			"section": section,
			"title": title,
			"hero_icon": hero_icon,
			"kind": kind,
			"ready": ready,
			"grid": grid,
		}

func _get_hero_icon(hero_id: String) -> Texture2D:
	if _hero_icon_cache.has(hero_id):
		return _hero_icon_cache[hero_id]
	var path := "%shero_%s.svg" % [HERO_ICON_DIR, hero_id]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_hero_icon_cache[hero_id] = texture
	return texture

func _hero_button_text(hero: HeroData) -> String:
	var effective_hp := Global.get_effective_base_hp(hero)
	return "%s\nHP %d  ·  DMG %d\n%s" % [
		hero.name, effective_hp, int(Global.base_damage), hero.ability_name,
	]

func _hero_tooltip(hero: HeroData) -> String:
	var effective_hp := Global.get_effective_base_hp(hero)
	return "%s (%s)\nBasis-HP (effektiv): %d\nBasis-Schaden: %d\nBasis-Munition: %d\nFeuerintervall: %.2fs\nNachladezeit: %.1fs\nPassive: %s\nAktiv: %s (%ss Cooldown)\n%s" % [
		hero.name, hero.role, effective_hp, int(Global.base_damage),
		hero.base_ammo, hero.base_fire_rate_cooldown, hero.base_reload_time,
		hero.passive_desc, hero.ability_name, hero.ability_cooldown, hero.description,
	]

func _create_hero_button(hero: HeroData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 104)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.set_meta("hero_id", hero.id)
	btn.tooltip_text = _hero_tooltip(hero)

	var margin := MarginContainer.new()
	btn.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 1)
	margin.add_child(content)

	var icon := TextureRect.new()
	icon.texture = _get_hero_icon(hero.id)
	icon.custom_minimum_size = Vector2(0, 38)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)

	var label := Label.new()
	label.name = "StatsLabel"
	label.text = _hero_button_text(hero)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	btn.set_meta("stats_label", label)
	return btn

func _select_hero(slot: int, hero_id: String) -> void:
	if not Global.can_control_slot(slot):
		return
	SoundManager.play_sound("click")
	Global.set_player_hero(slot, hero_id)
	if not Global.is_bot_slot(slot):
		Global.set_player_ready(slot, false)
	_refresh_hero_highlights()
	_update_titles()

	# Online: Host teilt die Änderung mit, Client schickt seine eigene Wahl zum Host.
	if Global.network_mode:
		if Global.is_local_host():
			NetworkManager.sync_lobby()
		else:
			NetworkManager.request_hero(hero_id)

func _refresh_hero_highlights() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		_highlight_grid(slot_nodes[i]["grid"], Global.get_player_hero_id(i))

func _highlight_grid(grid: HBoxContainer, hero_id: String) -> void:
	for child in grid.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var is_selected: bool = btn.get_meta("hero_id", "") == hero_id
		var alpha := 0.45 if btn.disabled else 0.75
		if is_selected:
			btn.modulate = Color(1.0, 1.0, 0.8, 0.55 if btn.disabled else 1.0)
		else:
			btn.modulate = Color(1.0, 1.0, 1.0, alpha)

func _on_kind_selected(item: int, slot: int) -> void:
	if not Global.is_local_host():
		_refresh_kind_options()
		return
	var kind: int = Global.PlayerKind.BOT if item == 0 else Global.PlayerKind.HUMAN
	if not Global.network_mode and slot >= 3 and kind == Global.PlayerKind.HUMAN:
		Global.set_player_kind(slot, Global.PlayerKind.BOT)
		status_label.text = "Lokal sind nur Spieler 1 und 2 menschlich steuerbar. Slots 3-6 sind Bots."
		_refresh_kind_options()
		return
	SoundManager.play_sound("click")
	# Wird ein belegter Mensch-Slot zum Bot, den Client sauber freigeben.
	if kind == Global.PlayerKind.BOT and Global.network_mode and NetworkManager.has_client_slot(slot):
		NetworkManager.kick_slot(slot)
	Global.set_player_kind(slot, kind)
	_refresh_kind_options()
	_update_status()

func _local_ready_slots() -> Array[int]:
	var slots: Array[int] = []
	if Global.is_spectator:
		return slots
	if not Global.network_mode:
		# Lokal können Slot 1 und optional Slot 2 von Menschen gesteuert
		# werden. Der Footer-Button meldet alle lokalen Menschen gemeinsam
		# bereit, damit niemand seinen Slot separat suchen muss.
		for slot_index in Global.get_active_player_indices():
			if Global.is_human_slot(slot_index):
				slots.append(slot_index)
		return slots
	var slot := Global.local_player_index
	if slot >= 1 and slot <= Global.player_count and not Global.is_bot_slot(slot):
		slots.append(slot)
	return slots

func _on_ready_pressed() -> void:
	var slots := _local_ready_slots()
	if slots.is_empty():
		return
	var all_ready := true
	for slot in slots:
		if not Global.can_control_slot(slot) or not Global.is_player_ready(slot):
			all_ready = false
			break
	var next_state := not all_ready
	SoundManager.play_sound("click")
	for slot in slots:
		Global.set_player_ready(slot, next_state)
		if Global.network_mode and not Global.is_local_host() and slot == Global.local_player_index:
			NetworkManager.send_ready_state(next_state)
	_refresh_ready_checks()
	_update_status()

func _refresh_ready_button() -> void:
	if ready_btn == null:
		return
	var slots := _local_ready_slots()
	var can_ready := not slots.is_empty()
	var all_ready := can_ready
	for slot in slots:
		if not Global.is_player_ready(slot):
			all_ready = false
			break
	ready_btn.disabled = not can_ready
	ready_btn.text = "BEREIT ✓" if all_ready else "BEREIT"
	if not can_ready:
		ready_btn.tooltip_text = "Zuschauer können sich nicht bereit melden."
	elif slots.size() > 1:
		ready_btn.tooltip_text = "Bereitschaft aller lokalen Spieler umschalten"
	else:
		ready_btn.tooltip_text = "Bereitschaft für Slot %d umschalten" % slots[0]
	var style: StyleBoxFlat = _ready_button_on if all_ready else _ready_button_off
	ready_btn.add_theme_stylebox_override("normal", style)
	ready_btn.add_theme_stylebox_override("hover", style)
	ready_btn.add_theme_stylebox_override("pressed", style)
	ready_btn.add_theme_stylebox_override("disabled", _ready_button_off)
	ready_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var font_color: Color = Color(0.86, 1.0, 0.89, 1.0) if all_ready else Color(0.92, 0.95, 1.0, 1.0)
	ready_btn.add_theme_color_override("font_color", font_color)
	ready_btn.add_theme_color_override("font_hover_color", font_color)
	ready_btn.add_theme_color_override("font_pressed_color", font_color)
	ready_btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.53, 0.62, 1.0))

func _apply_ready_display_style(check: CheckBox, is_ready: bool) -> void:
	var style: StyleBoxFlat = _ready_display_on if is_ready else _ready_display_off
	check.add_theme_stylebox_override("normal", style)
	check.add_theme_stylebox_override("hover", style)
	check.add_theme_stylebox_override("pressed", style)
	check.add_theme_stylebox_override("disabled", style)
	check.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var font_color: Color = Color(0.82, 1.0, 0.85, 1.0) if is_ready else Color(0.70, 0.76, 0.86, 1.0)
	check.add_theme_color_override("font_color", font_color)
	check.add_theme_color_override("font_hover_color", font_color)
	check.add_theme_color_override("font_pressed_color", font_color)
	check.add_theme_color_override("font_disabled_color", font_color)

func _on_lobby_state_changed() -> void:
	_sync_from_global()

func _on_slot_assigned(slot: int) -> void:
	_sync_from_global()
	# Nach dem Beitritt das gespeicherte Profil einmalig an den Host senden,
	# damit der eigene Charakter sofort für alle sichtbar ist.
	if slot >= 1 and NetworkManager.is_client and slot == Global.local_player_index:
		var look := Global.get_pig_appearance(slot)
		NetworkManager.request_pig_appearance(
			look["fur"],
			look["eyes"],
			look["pants"],
			look["wand_tip_shape"],
			look["wand_tip_color"],
			look["shot_color"]
		)

func _refresh_slot_visibility() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var section: VBoxContainer = slot_nodes[i]["section"]
		section.visible = i <= Global.player_count

func _refresh_ready_checks() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var check: CheckBox = slot_nodes[i]["ready"]
		var bot := Global.is_bot_slot(i)
		var is_ready := Global.is_player_ready(i)
		check.set_pressed_no_signal(is_ready)
		check.disabled = false
		if bot:
			check.text = "Bot ist bereit"
		elif is_ready:
			check.text = "Bereit"
		else:
			check.text = "Nicht bereit"
		_apply_ready_display_style(check, is_ready)
	_refresh_ready_button()

func _refresh_kind_options() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var opt: OptionButton = slot_nodes[i]["kind"]
		opt.visible = i >= 2 and i <= Global.player_count
		opt.selected = 0 if Global.is_bot_slot(i) else 1
		opt.disabled = not Global.is_local_host()

func _refresh_hero_controls() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var can := Global.can_control_slot(i) and not Global.is_bot_slot(i)
		var grid: HBoxContainer = slot_nodes[i]["grid"]
		for child in grid.get_children():
			child.disabled = not can
	# Nach dem Setzen des Disabled-Status die Icons/Labels passend abdunkeln.
	_refresh_hero_highlights()

func _refresh_hero_stats_text() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var grid: HBoxContainer = slot_nodes[i]["grid"]
		for child in grid.get_children():
			var btn := child as Button
			if btn == null:
				continue
			var hero: HeroData = Global.get_hero(str(btn.get_meta("hero_id", "")))
			if hero == null:
				continue
			var stats_label := btn.get_meta("stats_label", null) as Label
			if stats_label != null:
				stats_label.text = _hero_button_text(hero)
			else:
				btn.text = _hero_button_text(hero)
			btn.tooltip_text = _hero_tooltip(hero)

# --- Charakteranpassung ---

func _build_character_tab() -> void:
	_character_ui_ready = false
	_character_slot_signature = ""
	_clear_children(character_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	character_tab.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(770, 610)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.98)
	panel_style.set_corner_radius_all(16)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1.0, 0.78, 0.32, 0.75)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 28)
	margin.add_child(main_row)

	# Linke Seite: lebendige Vorschau des gewählten Spieler-Slots.
	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size = Vector2(280, 0)
	preview_column.add_theme_constant_override("separation", 8)
	main_row.add_child(preview_column)

	var preview_title := Label.new()
	preview_title.text = "CHARAKTERVORSCHAU"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 20)
	preview_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	preview_column.add_child(preview_title)

	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(280, 280)
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.03, 0.045, 0.07, 1.0)
	preview_style.set_corner_radius_all(14)
	preview_style.border_width_left = 2
	preview_style.border_width_top = 2
	preview_style.border_width_right = 2
	preview_style.border_width_bottom = 2
	preview_style.border_color = Color(0.28, 0.38, 0.52, 0.9)
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	preview_column.add_child(preview_frame)

	var preview_canvas := Control.new()
	preview_canvas.custom_minimum_size = Vector2(280, 280)
	preview_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(preview_canvas)

	character_preview = PigCharacter.new()
	character_preview.position = Vector2(140, 176)
	character_preview.scale = Vector2(4.4, 4.4)
	character_preview.animate = true
	character_preview.follow_parent_motion = false
	preview_canvas.add_child(character_preview)

	character_preview_wand_pivot = Node2D.new()
	character_preview_wand_pivot.position = Vector2(140, 176)
	character_preview_wand_pivot.scale = Vector2(4.4, 4.4)
	character_preview_wand_pivot.rotation = -0.24
	preview_canvas.add_child(character_preview_wand_pivot)

	character_preview_wand = MagicWand.new()
	character_preview_wand_pivot.add_child(character_preview_wand)

	character_hero_icon = TextureRect.new()
	character_hero_icon.position = Vector2(14, 14)
	character_hero_icon.size = Vector2(54, 54)
	character_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	character_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	character_hero_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_canvas.add_child(character_hero_icon)

	character_slot_label = Label.new()
	character_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_slot_label.add_theme_font_size_override("font_size", 13)
	character_slot_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.82))
	preview_column.add_child(character_slot_label)

	# Rechte Seite: Slot-Auswahl und Farbauswahl.
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 12)
	main_row.add_child(controls)

	var heading := Label.new()
	heading.text = "CHARAKTER ANPASSEN"
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	controls.add_child(heading)

	character_hint = Label.new()
	character_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_hint.add_theme_font_size_override("font_size", 13)
	character_hint.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
	controls.add_child(character_hint)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 12)
	controls.add_child(slot_row)

	var slot_caption := Label.new()
	slot_caption.text = "SPIELER-SLOT"
	slot_caption.add_theme_font_size_override("font_size", 15)
	slot_caption.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	slot_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_row.add_child(slot_caption)

	character_slot_option = OptionButton.new()
	character_slot_option.custom_minimum_size = Vector2(220, 36)
	character_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_slot_option.item_selected.connect(_on_character_slot_selected)
	slot_row.add_child(character_slot_option)

	fur_picker = ColorPickerButton.new()
	eye_picker = ColorPickerButton.new()
	pants_picker = ColorPickerButton.new()
	wand_tip_picker = ColorPickerButton.new()
	shot_color_picker = ColorPickerButton.new()
	_add_character_color_row(controls, "Fellfarbe", "Grundfarbe von Kopf, Körper und Ohren.", fur_picker)
	_add_character_color_row(controls, "Augenfarbe", "Farbe der Iris. Die Augen bleiben weiß umrandet.", eye_picker)
	_add_character_color_row(controls, "Hosenfarbe", "Farbe der kurzen Hose inklusive Gürtel und Hosenbeinen.", pants_picker)
	_add_character_shape_row(controls)
	_add_character_color_row(controls, "Zauberstab-Spitze", "Farbe des Leuchtkerns an der Spitze des Stabs.", wand_tip_picker)
	_add_character_color_row(controls, "Basis-Schuss", "Farbe der normalen Projektile, bevor Karten sie verändern.", shot_color_picker)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 2)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)

	var reset_button := Button.new()
	reset_button.text = "STANDARD-CHARAKTER ZURÜCKSETZEN"
	reset_button.custom_minimum_size = Vector2(0, 38)
	reset_button.pressed.connect(_on_reset_character_colors)
	controls.add_child(reset_button)

	_character_ui_ready = true

func _add_character_color_row(parent: VBoxContainer, title: String, description: String, picker: ColorPickerButton) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	text_column.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.50, 0.56, 0.65))
	text_column.add_child(desc_label)

	picker.custom_minimum_size = Vector2(120, 42)
	picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.edit_alpha = false
	picker.color_changed.connect(_on_character_color_changed)
	row.add_child(picker)

func _add_character_shape_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 1)
	row.add_child(text_column)

	var title_label := Label.new()
	title_label.text = "Spitzenform"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	text_column.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = "Form des Leuchtkerns am Ende des einhändigen Zauberstabs."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.50, 0.56, 0.65))
	text_column.add_child(desc_label)

	wand_shape_option = OptionButton.new()
	wand_shape_option.custom_minimum_size = Vector2(120, 42)
	wand_shape_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(Global.WAND_TIP_SHAPES.size()):
		var shape: String = Global.WAND_TIP_SHAPES[i]
		wand_shape_option.add_item(Global.get_wand_tip_shape_label(shape), i)
	wand_shape_option.item_selected.connect(_on_character_wand_shape_changed)
	row.add_child(wand_shape_option)

func _character_slots() -> Array[int]:
	var slots: Array[int] = []
	if Global.is_spectator:
		return slots
	for slot in Global.get_active_player_indices():
		if Global.can_control_slot(slot):
			slots.append(slot)
	return slots

func _can_customize_character_slot(slot: int) -> bool:
	if slot < 1 or slot > Global.MAX_PLAYERS or Global.is_spectator:
		return false
	if not Global.is_active_slot(slot):
		return false
	return Global.can_control_slot(slot)

func _character_kind_text(slot: int) -> String:
	return "Bot" if Global.is_bot_slot(slot) else "Mensch"

func _refresh_character_slot_options() -> void:
	if character_slot_option == null:
		return

	var slots := _character_slots()
	var signature_parts: Array[String] = []
	for slot in slots:
		signature_parts.append("%d:%s" % [slot, _character_kind_text(slot)])
	var signature := "|".join(signature_parts)
	if signature != _character_slot_signature:
		_character_slot_signature = signature
		_updating_character_ui = true
		character_slot_option.clear()
		for slot in slots:
			character_slot_option.add_item("Slot %d · %s" % [slot, _character_kind_text(slot)], slot)
		_updating_character_ui = false

	if slots.is_empty():
		_character_slot = 0
		character_slot_option.disabled = true
		return

	character_slot_option.disabled = false
	if not slots.has(_character_slot):
		_character_slot = Global.local_player_index if slots.has(Global.local_player_index) else slots[0]

	for i in range(character_slot_option.item_count):
		if character_slot_option.get_item_id(i) == _character_slot:
			character_slot_option.select(i)
			break

func _refresh_character_tab() -> void:
	if not _character_ui_ready:
		return

	_refresh_character_slot_options()
	var slots := _character_slots()
	var can_customize := slots.has(_character_slot)
	var look_slot := _character_slot if can_customize else 1
	var look := Global.get_pig_appearance(look_slot)

	_updating_character_ui = true
	fur_picker.color = look["fur"]
	eye_picker.color = look["eyes"]
	pants_picker.color = look["pants"]
	wand_tip_picker.color = look["wand_tip_color"]
	shot_color_picker.color = look["shot_color"]
	var shape_index := Global.WAND_TIP_SHAPES.find(str(look["wand_tip_shape"]))
	wand_shape_option.select(maxi(0, shape_index))
	_updating_character_ui = false

	fur_picker.disabled = not can_customize
	eye_picker.disabled = not can_customize
	pants_picker.disabled = not can_customize
	wand_tip_picker.disabled = not can_customize
	shot_color_picker.disabled = not can_customize
	wand_shape_option.disabled = not can_customize

	if character_preview:
		character_preview.setup(look["fur"], look["eyes"], look["pants"])
	if character_preview_wand:
		character_preview_wand.setup(look["wand_tip_shape"], look["wand_tip_color"])

	if character_hero_icon:
		character_hero_icon.visible = can_customize
		if can_customize:
			character_hero_icon.texture = _get_hero_icon(Global.get_player_hero_id(_character_slot))

	if character_slot_label:
		if can_customize:
			var hero := Global.get_hero(Global.get_player_hero_id(_character_slot))
			character_slot_label.text = "SLOT %d  ·  %s  ·  %s" % [
				_character_slot, _character_kind_text(_character_slot).to_upper(), hero.name.to_upper(),
			]
		else:
			character_slot_label.text = "ZUSCHAUER"

	if character_hint:
		if not can_customize:
			character_hint.text = "Zuschauer können keine Spielfigur anpassen."
		elif Global.network_mode:
			character_hint.text = "Du kannst deinen eigenen Slot anpassen. Charakter, Stabspitze und Schussfarbe werden mit dem Host synchronisiert und automatisch gespeichert."
		elif slots.size() > 1:
			character_hint.text = "Wähle oben den Spieler-Slot. Alle Anpassungen gelten sofort fürs Match; der eigene Slot wird automatisch gespeichert."
		else:
			character_hint.text = "Charakter, Zauberstabspitze und Schussfarbe werden sofort übernommen und automatisch gespeichert."

	tabs.set_tab_disabled(1, slots.is_empty())
	if slots.is_empty() and tabs.current_tab == 1:
		tabs.current_tab = 0

func _on_lobby_tab_changed(tab: int) -> void:
	if tab == 1:
		_refresh_character_tab()

func _on_character_slot_selected(index: int) -> void:
	if _updating_character_ui or character_slot_option == null or index < 0:
		return
	_character_slot = character_slot_option.get_item_id(index)
	SoundManager.play_sound("click")
	_refresh_character_tab()

func _on_pig_appearance_changed(slot: int) -> void:
	if slot == _character_slot:
		_refresh_character_tab()

func _on_character_color_changed(_color: Color) -> void:
	_commit_character_appearance()

func _on_character_wand_shape_changed(_index: int) -> void:
	_commit_character_appearance()

func _selected_wand_tip_shape() -> String:
	if wand_shape_option == null:
		return "orb"
	var index := clampi(wand_shape_option.selected, 0, Global.WAND_TIP_SHAPES.size() - 1)
	return Global.WAND_TIP_SHAPES[index]

func _commit_character_appearance() -> void:
	if _updating_character_ui or not _character_ui_ready:
		return
	var slot := _character_slot
	if not _can_customize_character_slot(slot):
		return

	var shape := _selected_wand_tip_shape()
	var tip_color := wand_tip_picker.color
	var shot_color := shot_color_picker.color
	Global.set_pig_appearance(
		slot,
		fur_picker.color,
		eye_picker.color,
		pants_picker.color,
		shape,
		tip_color,
		shot_color
	)
	if NetworkManager.is_client and slot == Global.local_player_index:
		NetworkManager.request_pig_appearance(
			fur_picker.color,
			eye_picker.color,
			pants_picker.color,
			shape,
			tip_color,
			shot_color
		)

func _on_reset_character_colors() -> void:
	if not _can_customize_character_slot(_character_slot):
		return
	var slot := _character_slot
	Global.reset_pig_appearance(slot)
	_refresh_character_tab()
	if NetworkManager.is_client and slot == Global.local_player_index:
		var look := Global.get_pig_appearance(slot)
		NetworkManager.request_pig_appearance(
			look["fur"],
			look["eyes"],
			look["pants"],
			look["wand_tip_shape"],
			look["wand_tip_color"],
			look["shot_color"]
		)

func _refresh_host_controls() -> void:
	# Match-Regeln und Karten darf nur der Host ändern.
	var is_host := Global.is_local_host()
	for spin in [score_spin, survival_spin, kill_spin, base_hp_spin, base_damage_spin, picks_spin, offer_spin]:
		if spin != null:
			spin.editable = is_host
	for rarity in rarity_spins.keys():
		rarity_spins[rarity].editable = is_host
	player_count_spin.editable = is_host
	if map_option != null:
		map_option.disabled = not is_host
	if mode_option != null:
		mode_option.disabled = not is_host
	unban_btn.disabled = not is_host
	all_pools_btn.disabled = not is_host
	for cb in pool_checks.values():
		var pool_check := cb as CheckButton
		if pool_check != null:
			pool_check.disabled = not is_host
	for cb in ban_checks.values():
		var check := cb as CheckButton
		if check != null:
			check.disabled = not is_host
	if blind_pick_check != null:
		blind_pick_check.disabled = not is_host or not Global.network_mode
	if random_pick_check != null:
		random_pick_check.disabled = not is_host
	_refresh_loadout_enabled()

func _map_ids() -> Array[String]:
	var ids: Array[String] = [Global.MAP_RANDOM]
	ids.append_array(Global.MAP_PLAYABLE)
	return ids

func _on_map_selected(index: int) -> void:
	if not Global.is_local_host():
		_refresh_map_controls()
		return
	var ids := _map_ids()
	if index < 0 or index >= ids.size():
		return
	Global.set_selected_map(ids[index])
	SoundManager.play_sound("click")
	_refresh_map_controls()
	_update_status()

func _on_map_changed() -> void:
	_refresh_map_controls()
	_update_status()

func _refresh_map_controls() -> void:
	if map_option == null:
		return
	var ids := _map_ids()
	var selected := maxi(0, ids.find(Global.selected_map_id))
	map_option.selected = selected
	if map_option.item_count > selected:
		map_option.text = map_option.get_item_text(selected)
	if map_info_label != null:
		map_info_label.text = "%s — %s" % [
			Global.get_map_name(Global.selected_map_id),
			Global.get_map_description(Global.selected_map_id),
		]

func _on_match_mode_changed() -> void:
	_refresh_mode_controls()
	_update_titles()
	_update_status()

func _on_mode_selected(index: int) -> void:
	if not Global.is_local_host():
		_refresh_mode_controls()
		return
	if index < 0 or index >= Global.MATCH_MODE_ORDER.size():
		return
	var mode := Global.MATCH_MODE_ORDER[index]
	Global.set_match_mode(mode)
	var required := Global.get_mode_required_players(mode)
	if required > 0:
		_on_player_count_changed(float(required))
	SoundManager.play_sound("click")
	_refresh_mode_controls()
	_update_titles()
	_update_status()

func _refresh_mode_controls() -> void:
	if mode_option == null:
		return
	var selected := maxi(0, Global.MATCH_MODE_ORDER.find(Global.match_mode))
	mode_option.selected = selected
	if mode_option.item_count > selected:
		mode_option.text = mode_option.get_item_text(selected)
	if mode_info_label != null:
		var info := Global.get_match_mode_description()
		var required := Global.get_mode_required_players()
		if required > 0:
			info += " Genau %d Spieler." % required
		if Global.is_team_mode():
			var groups: Array[String] = []
			for team in range(1, Global.get_team_count() + 1):
				var members: Array[String] = []
				for slot in Global.get_team_members(team):
					members.append(str(slot))
				groups.append(" + ".join(members))
			info += " Teams: %s." % " vs ".join(groups)
		mode_info_label.text = info

func _update_titles() -> void:
	for i in range(1, Global.MAX_PLAYERS + 1):
		if not slot_nodes.has(i):
			continue
		var title: Label = slot_nodes[i]["title"]
		var hero_icon: TextureRect = slot_nodes[i]["hero_icon"]
		if hero_icon != null:
			hero_icon.texture = _get_hero_icon(Global.get_player_hero_id(i))
		var team_prefix := ""
		if Global.is_team_mode():
			team_prefix = "[%s] " % Global.get_team_name(Global.get_team_for_slot(i))
		if i == 1:
			title.text = team_prefix + ("SPIELER 1 (HOST) — HELD WÄHLEN" if Global.network_mode else "SPIELER 1 — HELD WÄHLEN")
			title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1.0))
		elif Global.is_bot_slot(i):
			title.text = team_prefix + "SLOT %d / BOT — HELD WÄHLEN" % i
			title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 1.0))
		elif Global.network_mode:
			var you := " (DU)" if i == Global.local_player_index else ""
			var state := "verbunden" if NetworkManager.has_client_slot(i) else "warte auf Mitspieler"
			title.text = team_prefix + "SLOT %d / MENSCH%s — %s" % [i, you, state]
			title.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 1.0))
		else:
			title.text = team_prefix + "SPIELER %d — HELD WÄHLEN" % i
			title.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 1.0))

# --- Regeln-Tab ---

func _build_rules_tab() -> void:
	_clear_children(rules_tab)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rules_tab.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	_build_loadout_section(body)
	body.add_child(HSeparator.new())

	_add_section_title(body, "MATCH-REGELN", Color(1.0, 0.72, 0.3, 1.0))
	var rules_grid := GridContainer.new()
	rules_grid.columns = 3
	rules_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rules_grid.add_theme_constant_override("h_separation", 18)
	rules_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(rules_grid)

	score_spin = _add_spin_row(
		rules_grid, "Punkte für Match-Sieg:", 100, 5000, 50,
		Global.points_to_win, "Wer zuerst diese Punktzahl erreicht, gewinnt das Match."
	)
	survival_spin = _add_spin_row(
		rules_grid, "Punkte für Überleben:", 0, 500, 5,
		Global.survival_points, "Bonus am Rundenende. In Team-Modi erhalten alle Mitglieder des Siegerteams den Bonus."
	)
	kill_spin = _add_spin_row(
		rules_grid, "Punkte pro Kill:", 0, 500, 5,
		Global.kill_points, "Wird dem Schützen sofort gutgeschrieben."
	)
	base_hp_spin = _add_spin_row(
		rules_grid, "Basis-HP-Faktor (%):", 50, 300, 5,
		Global.base_hp_percent, "100 % = Heldenwert. Helden behalten ihre Klassenunterschiede."
	)
	base_damage_spin = _add_spin_row(
		rules_grid, "Basis-Schaden pro Schuss:", 1, 200, 1,
		Global.base_damage, "Grundschaden vor Helden- und Kartenmodifikatoren."
	)

	score_spin.value_changed.connect(_on_scoring_changed)
	survival_spin.value_changed.connect(_on_scoring_changed)
	kill_spin.value_changed.connect(_on_scoring_changed)
	base_hp_spin.value_changed.connect(_on_base_hp_percent_changed)
	base_damage_spin.value_changed.connect(_on_base_damage_changed)

	body.add_child(HSeparator.new())
	_add_section_title(body, "SPIELMODUS", Color(1.0, 0.55, 0.55, 1.0))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	body.add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "Modus:"
	mode_label.add_theme_font_size_override("font_size", 15)
	mode_row.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.custom_minimum_size = Vector2(230, 0)
	for mode_id in Global.MATCH_MODE_ORDER:
		mode_option.add_item(Global.get_match_mode_name(mode_id))
	mode_option.item_selected.connect(_on_mode_selected)
	mode_row.add_child(mode_option)

	mode_info_label = Label.new()
	mode_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_info_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	mode_info_label.add_theme_font_size_override("font_size", 12)
	mode_info_label.autowrap_mode = 2
	body.add_child(mode_info_label)

	body.add_child(HSeparator.new())
	_add_section_title(body, "SPIELFELD", Color(0.45, 0.9, 1.0, 1.0))
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 12)
	body.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map:"
	map_label.add_theme_font_size_override("font_size", 15)
	map_row.add_child(map_label)

	map_option = OptionButton.new()
	map_option.custom_minimum_size = Vector2(230, 0)
	for map_id in _map_ids():
		map_option.add_item(Global.get_map_name(map_id))
	map_option.item_selected.connect(_on_map_selected)
	map_row.add_child(map_option)

	map_info_label = Label.new()
	map_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_info_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	map_info_label.add_theme_font_size_override("font_size", 12)
	map_info_label.autowrap_mode = 2
	body.add_child(map_info_label)

	body.add_child(HSeparator.new())
	_add_section_title(body, "KARTEN-DRAFT", Color(0.45, 0.8, 1.0, 1.0))
	var draft_row := HBoxContainer.new()
	draft_row.add_theme_constant_override("separation", 12)
	body.add_child(draft_row)

	var draft_label := Label.new()
	draft_label.text = "Auswahl:"
	draft_label.add_theme_font_size_override("font_size", 15)
	draft_row.add_child(draft_label)

	picks_spin = SpinBox.new()
	picks_spin.custom_minimum_size = Vector2(100, 0)
	picks_spin.min_value = 1
	picks_spin.max_value = 10
	picks_spin.step = 1
	picks_spin.value = Global.draft_picks
	picks_spin.value_changed.connect(_on_picks_changed)
	draft_row.add_child(picks_spin)

	var von_label := Label.new()
	von_label.text = "von"
	von_label.add_theme_font_size_override("font_size", 15)
	draft_row.add_child(von_label)

	offer_spin = SpinBox.new()
	offer_spin.custom_minimum_size = Vector2(100, 0)
	offer_spin.min_value = 1
	offer_spin.max_value = 10
	offer_spin.step = 1
	offer_spin.value = Global.cards_per_draft
	offer_spin.value_changed.connect(_on_offer_changed)
	draft_row.add_child(offer_spin)

	var draft_hint := Label.new()
	draft_hint.text = "Karten pro Spieler und angebotene Karten pro Draft."
	draft_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draft_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	draft_hint.add_theme_font_size_override("font_size", 12)
	draft_row.add_child(draft_hint)

	body.add_child(HSeparator.new())
	_add_section_title(body, "DRAFT-MODIFIER", Color(0.82, 0.62, 1.0, 1.0))
	var modifier_intro := Label.new()
	modifier_intro.text = "Modifier gelten für alle Drafts. Blind pick verdeckt Angebot und Auswahl online vor anderen menschlichen Spielern; lokal gegen Bots bleibt er ohne Wirkung. Random pick zieht automatisch eine zufällige Karte."
	modifier_intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	modifier_intro.add_theme_font_size_override("font_size", 12)
	modifier_intro.autowrap_mode = 2
	body.add_child(modifier_intro)

	var modifier_grid := GridContainer.new()
	modifier_grid.columns = 2
	modifier_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_grid.add_theme_constant_override("h_separation", 18)
	modifier_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(modifier_grid)

	blind_pick_check = CheckButton.new()
	blind_pick_check.text = "Blind pick (online)"
	blind_pick_check.tooltip_text = "Nur online gegen menschliche Spieler: Andere sehen weder das Kartenangebot noch die gewählte Karte. Der aktive Spieler sieht seine Auswahl weiterhin. Lokal gegen Bots ohne Wirkung."
	blind_pick_check.button_pressed = Global.blind_pick_enabled and Global.network_mode
	blind_pick_check.toggled.connect(_on_blind_pick_toggled)
	modifier_grid.add_child(blind_pick_check)

	var blind_hint := Label.new()
	blind_hint.text = "Nur online gegen menschliche Spieler wirksam; lokal mit Bots ohne Effekt."
	blind_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blind_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	blind_hint.add_theme_font_size_override("font_size", 12)
	blind_hint.autowrap_mode = 2
	modifier_grid.add_child(blind_hint)

	random_pick_check = CheckButton.new()
	random_pick_check.text = "Random pick"
	random_pick_check.tooltip_text = "Beim Draft wird automatisch eine zufällige Karte aus dem Angebot gezogen. Manuelle Auswahl ist deaktiviert; der Host entscheidet online autoritativ."
	random_pick_check.button_pressed = Global.random_pick_enabled
	random_pick_check.toggled.connect(_on_random_pick_toggled)
	modifier_grid.add_child(random_pick_check)

	var random_hint := Label.new()
	random_hint.text = "Automatische Zufallswahl statt manuellem Picken."
	random_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	random_hint.add_theme_font_size_override("font_size", 12)
	random_hint.autowrap_mode = 2
	modifier_grid.add_child(random_hint)

	var info := Label.new()
	info.text = "Kills geben sofort Punkte. In FFA erhält der Überlebende den Bonus, in Team-Modi alle Mitglieder des Siegerteams. Bei einem Doppel-KO gibt es keinen Überlebensbonus."
	info.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	info.add_theme_font_size_override("font_size", 12)
	info.autowrap_mode = 2
	body.add_child(info)

# --- Lobby-Loadouts ---

func _build_loadout_section(body: VBoxContainer) -> void:
	_add_section_title(body, "LOBBY-LOADOUTS", Color(0.85, 0.65, 1.0, 1.0))

	var intro := Label.new()
	intro.text = "Gespeicherte Presets für Modus, Spielerzahl, Punkte, Draft inkl. Modifier, Kartenpools, Sperren, Map sowie HP und Schaden. Nur der Host kann Loadouts laden, speichern oder löschen."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = 2
	body.add_child(intro)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 12)
	body.add_child(preset_row)

	var preset_label := Label.new()
	preset_label.text = "Preset:"
	preset_label.add_theme_font_size_override("font_size", 15)
	preset_row.add_child(preset_label)

	loadout_option = OptionButton.new()
	loadout_option.custom_minimum_size = Vector2(260, 0)
	loadout_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout_option.item_selected.connect(_on_loadout_selected)
	preset_row.add_child(loadout_option)

	loadout_load_btn = Button.new()
	loadout_load_btn.text = "LADEN"
	loadout_load_btn.tooltip_text = "Ausgewähltes Loadout auf die aktuelle Lobby anwenden."
	loadout_load_btn.pressed.connect(_on_loadout_load_pressed)
	preset_row.add_child(loadout_load_btn)

	loadout_delete_btn = Button.new()
	loadout_delete_btn.text = "LÖSCHEN"
	loadout_delete_btn.tooltip_text = "Ausgewähltes Loadout dauerhaft entfernen."
	loadout_delete_btn.pressed.connect(_on_loadout_delete_pressed)
	preset_row.add_child(loadout_delete_btn)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 12)
	body.add_child(save_row)

	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.add_theme_font_size_override("font_size", 15)
	save_row.add_child(name_label)

	loadout_name_edit = LineEdit.new()
	loadout_name_edit.placeholder_text = "z. B. Turnier-Regeln"
	loadout_name_edit.max_length = 40
	loadout_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(loadout_name_edit)

	loadout_save_btn = Button.new()
	loadout_save_btn.text = "SPEICHERN"
	loadout_save_btn.tooltip_text = "Aktuelle Lobby-Einstellungen unter diesem Namen speichern."
	loadout_save_btn.pressed.connect(_on_loadout_save_pressed)
	save_row.add_child(loadout_save_btn)

	loadout_desc_label = Label.new()
	loadout_desc_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.9, 1.0))
	loadout_desc_label.add_theme_font_size_override("font_size", 12)
	loadout_desc_label.autowrap_mode = 2
	body.add_child(loadout_desc_label)

	loadout_status = Label.new()
	loadout_status.add_theme_font_size_override("font_size", 12)
	loadout_status.autowrap_mode = 2
	body.add_child(loadout_status)

	_refresh_loadout_controls()

func _selected_loadout_name() -> String:
	if loadout_option == null or loadout_option.item_count == 0:
		return ""
	var index := loadout_option.selected
	if index < 0 or index >= loadout_option.item_count:
		return ""
	var preset_name := loadout_option.get_item_text(index)
	if not Global.has_lobby_loadout(preset_name):
		return ""
	return preset_name

func _refresh_loadout_controls(preferred_name: String = "") -> void:
	if loadout_option == null:
		return
	var previous := preferred_name
	if previous.is_empty():
		previous = _selected_loadout_name()
	var names := Global.get_lobby_loadout_names()
	loadout_refreshing = true
	loadout_option.clear()
	if names.is_empty():
		loadout_option.add_item("Keine Loadouts")
		loadout_option.set_item_disabled(0, true)
		loadout_option.selected = 0
	else:
		for preset_name in names:
			loadout_option.add_item(preset_name)
		var index := names.find(previous)
		if index < 0:
			index = 0
		loadout_option.selected = index
		loadout_option.text = names[index]
	loadout_refreshing = false
	_refresh_loadout_description()
	_refresh_loadout_enabled()

func _refresh_loadout_description() -> void:
	if loadout_desc_label == null:
		return
	var preset_name := _selected_loadout_name()
	if preset_name.is_empty():
		if Global.get_lobby_loadout_names().is_empty():
			loadout_desc_label.text = "Noch keine Loadouts gespeichert. Stelle die gewünschten Regeln ein und speichere sie oben."
		else:
			loadout_desc_label.text = "Wähle ein Preset, um die gespeicherten Einstellungen zu sehen."
		return
	loadout_desc_label.text = Global.get_lobby_loadout_summary(preset_name)

func _refresh_loadout_enabled() -> void:
	var is_host := Global.is_local_host()
	var has_selection := not _selected_loadout_name().is_empty()
	if loadout_option != null:
		loadout_option.disabled = not is_host
	if loadout_name_edit != null:
		loadout_name_edit.editable = is_host
	if loadout_load_btn != null:
		loadout_load_btn.disabled = not is_host or not has_selection
	if loadout_save_btn != null:
		loadout_save_btn.disabled = not is_host
	if loadout_delete_btn != null:
		loadout_delete_btn.disabled = not is_host or not has_selection

func _on_loadout_selected(_index: int) -> void:
	if loadout_refreshing:
		return
	_refresh_loadout_description()
	_refresh_loadout_enabled()

func _on_lobby_loadouts_changed() -> void:
	_refresh_loadout_controls()

func _set_loadout_status(message: String, is_error: bool = false) -> void:
	if loadout_status == null:
		return
	loadout_status.text = message
	loadout_status.add_theme_color_override(
		"font_color", Color(1.0, 0.55, 0.5, 1.0) if is_error else Color(0.55, 0.9, 0.65, 1.0)
	)

func _on_loadout_save_pressed() -> void:
	if not Global.is_local_host():
		return
	var preset_name := loadout_name_edit.text.strip_edges()
	if preset_name.is_empty():
		preset_name = _selected_loadout_name()
	if preset_name.is_empty():
		preset_name = "Mein Loadout"
	if not Global.save_lobby_loadout(preset_name):
		_set_loadout_status("Loadout konnte nicht gespeichert werden.", true)
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	loadout_name_edit.text = preset_name
	_refresh_loadout_controls(preset_name)
	_set_loadout_status("Loadout '%s' gespeichert." % preset_name)
	SoundManager.play_sound("confirm")

func _on_loadout_delete_pressed() -> void:
	if not Global.is_local_host():
		return
	var preset_name := _selected_loadout_name()
	if preset_name.is_empty():
		return
	if not Global.delete_lobby_loadout(preset_name):
		_set_loadout_status("Loadout konnte nicht gelöscht werden.", true)
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	_refresh_loadout_controls()
	_set_loadout_status("Loadout '%s' gelöscht." % preset_name)
	SoundManager.play_sound("click")

func _on_loadout_load_pressed() -> void:
	if not Global.is_local_host():
		return
	var preset_name := _selected_loadout_name()
	if preset_name.is_empty():
		return
	if not _apply_lobby_loadout(preset_name):
		return
	_set_loadout_status("Loadout '%s' geladen." % preset_name)
	SoundManager.play_sound("confirm")

func _apply_lobby_loadout(preset_name: String) -> bool:
	var data := Global.get_lobby_loadout(preset_name)
	if data.is_empty():
		_set_loadout_status("Loadout '%s' ist nicht verfügbar." % preset_name, true)
		return false
	var mode := str(data.get("match_mode", Global.match_mode))
	Global.set_match_mode(mode)
	var desired := Global.get_mode_required_players(mode)
	if desired <= 0:
		desired = clampi(int(data.get("player_count", Global.player_count)), Global.MIN_PLAYERS, Global.MAX_PLAYERS)
	if Global.network_mode:
		for i in range(desired + 1, Global.MAX_PLAYERS + 1):
			if NetworkManager.has_client_slot(i):
				NetworkManager.kick_slot(i)
	Global.apply_lobby_settings(data)
	_sync_from_global()
	return true

func _add_spin_row(grid: GridContainer, label_text: String, min_value: float, max_value: float, step: float, value: float, hint_text: String) -> SpinBox:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 15)
	grid.add_child(label)

	var spin := SpinBox.new()
	spin.custom_minimum_size = Vector2(130, 0)
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	grid.add_child(spin)

	var hint := Label.new()
	hint.text = hint_text
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	hint.add_theme_font_size_override("font_size", 12)
	hint.autowrap_mode = 2
	grid.add_child(hint)
	return spin

# --- Karten-Tab ---

func _build_cards_tab() -> void:
	_clear_children(cards_tab)
	rarity_spins.clear()
	ban_checks.clear()
	ban_icons.clear()
	pool_checks.clear()

	_add_section_title(cards_tab, "KARTENPOOLS", Color(0.45, 0.9, 1.0, 1.0))
	var pool_intro := Label.new()
	pool_intro.text = "Nur Karten aus aktiven Pools erscheinen im Draft. Mindestens ein Pool bleibt aktiv; Ausbaukarten erben den Pool ihrer Grundkarte."
	pool_intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	pool_intro.add_theme_font_size_override("font_size", 12)
	pool_intro.autowrap_mode = 2
	cards_tab.add_child(pool_intro)

	var pool_header := HBoxContainer.new()
	pool_header.add_theme_constant_override("separation", 12)
	cards_tab.add_child(pool_header)

	pool_count_label = Label.new()
	pool_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_count_label.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95, 1.0))
	pool_count_label.add_theme_font_size_override("font_size", 13)
	pool_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pool_header.add_child(pool_count_label)

	all_pools_btn = Button.new()
	all_pools_btn.text = "Alle Pools"
	all_pools_btn.tooltip_text = "Aktiviert alle Kartenpools für den Draft."
	all_pools_btn.pressed.connect(_on_all_card_pools_pressed)
	pool_header.add_child(all_pools_btn)

	var pool_grid := GridContainer.new()
	pool_grid.columns = 5
	pool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_grid.add_theme_constant_override("h_separation", 12)
	pool_grid.add_theme_constant_override("v_separation", 2)
	cards_tab.add_child(pool_grid)

	for pool in Global.CARD_POOLS:
		var cb := CheckButton.new()
		cb.text = pool
		cb.button_pressed = Global.is_card_pool_enabled(pool)
		cb.tooltip_text = Global.CARD_POOL_DESCRIPTIONS.get(pool, "")
		cb.add_theme_font_size_override("font_size", 14)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.toggled.connect(_on_card_pool_toggled.bind(pool, cb))
		pool_grid.add_child(cb)
		pool_checks[pool] = cb

	cards_tab.add_child(HSeparator.new())
	_add_section_title(cards_tab, "SELTENHEITEN", Color(1.0, 0.72, 0.3, 1.0))
	var intro := Label.new()
	intro.text = "Prozentsatz pro Seltenheit im Kartenangebot. Die Summe wird automatisch normalisiert; alle 0 % bedeutet Gleichverteilung."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = 2
	cards_tab.add_child(intro)

	var rarity_grid := GridContainer.new()
	rarity_grid.columns = 5
	rarity_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_grid.add_theme_constant_override("h_separation", 12)
	rarity_grid.add_theme_constant_override("v_separation", 4)
	cards_tab.add_child(rarity_grid)

	for rarity in Global.RARITY_ORDER:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 3)
		rarity_grid.add_child(cell)

		var label := Label.new()
		label.text = rarity
		label.add_theme_color_override("font_color", CardDatabase.get_rarity_color(rarity))
		label.add_theme_font_size_override("font_size", 15)
		cell.add_child(label)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		cell.add_child(row)

		var spin := SpinBox.new()
		spin.custom_minimum_size = Vector2(110, 0)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spin.min_value = 0
		spin.max_value = 100
		spin.step = 1
		spin.value = Global.get_rarity_percent(rarity)
		spin.value_changed.connect(_on_rarity_percent_changed.bind(rarity))
		row.add_child(spin)
		rarity_spins[rarity] = spin

		var percent := Label.new()
		percent.text = "%"
		percent.add_theme_font_size_override("font_size", 14)
		row.add_child(percent)

	rarity_sum_label = Label.new()
	rarity_sum_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1.0))
	rarity_sum_label.add_theme_font_size_override("font_size", 13)
	cards_tab.add_child(rarity_sum_label)

	var legend := Label.new()
	legend.text = "Kartenrahmen: außen = Seltenheit, innen = Effektfarbe der Karte."
	legend.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	legend.add_theme_font_size_override("font_size", 12)
	cards_tab.add_child(legend)

	cards_tab.add_child(HSeparator.new())

	var ban_header := HBoxContainer.new()
	ban_header.add_theme_constant_override("separation", 12)
	cards_tab.add_child(ban_header)

	var ban_title := Label.new()
	ban_title.text = "Powerup-Karten sperren:"
	ban_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban_title.add_theme_font_size_override("font_size", 16)
	ban_header.add_child(ban_title)

	ban_count = Label.new()
	ban_count.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1.0))
	ban_count.add_theme_font_size_override("font_size", 13)
	ban_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban_header.add_child(ban_count)

	unban_btn = Button.new()
	unban_btn.text = "Alle entsperren"
	unban_btn.pressed.connect(_on_unban_all)
	ban_header.add_child(unban_btn)

	var ban_scroll := ScrollContainer.new()
	ban_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ban_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_tab.add_child(ban_scroll)

	ban_sections = VBoxContainer.new()
	ban_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban_sections.add_theme_constant_override("separation", 4)
	ban_scroll.add_child(ban_sections)

	_build_ban_sections()

func _on_card_rarity_changed() -> void:
	# Automatische Aufwertungen können während eines Matches passieren. Die
	# Kartenliste wird deshalb im Hintergrund neu gruppiert, damit die Lobby
	# beim nächsten Öffnen sofort die aktuelle Seltenheit zeigt.
	if ban_sections != null and is_instance_valid(ban_sections):
		_build_ban_sections()
		_refresh_host_controls()

func _build_ban_sections() -> void:
	_clear_children(ban_sections)
	ban_checks.clear()
	ban_icons.clear()

	var grouped: Dictionary = {}
	for card in CardDatabase.all_cards:
		if not grouped.has(card.rarity):
			grouped[card.rarity] = []
		grouped[card.rarity].append(card)

	for rarity in Global.RARITY_ORDER:
		if grouped.has(rarity):
			_add_ban_section(rarity, grouped[rarity])
			grouped.erase(rarity)
	for rarity in grouped.keys():
		_add_ban_section(str(rarity), grouped[rarity])

func _add_ban_section(rarity: String, cards: Array) -> void:
	cards.sort_custom(func(a, b): return a.title < b.title)
	var header := Label.new()
	header.text = "%s  ·  %d Karten" % [rarity, cards.size()]
	header.add_theme_color_override("font_color", CardDatabase.get_rarity_color(rarity))
	header.add_theme_font_size_override("font_size", 16)
	header.custom_minimum_size = Vector2(0, 26)
	ban_sections.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	ban_sections.add_child(grid)

	for card in cards:
		grid.add_child(_create_ban_card(card))

func _create_ban_card(card: CardData) -> PanelContainer:
	var class_hint := ""
	if not card.hero_id.is_empty():
		var hero: HeroData = Global.get_hero(card.hero_id)
		class_hint = "Klassenkarte: nur für %s." % hero.name
	if not card.parent_card_id.is_empty():
		var parent_card := CardDatabase.get_card(card.parent_card_id)
		var parent_title: String = parent_card.title if parent_card != null else card.parent_card_id
		if not class_hint.is_empty():
			class_hint += "\n"
		class_hint += "Ausbaukarte: erscheint nur mit %s im Deck." % parent_title
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 66)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Wie im Draft: äußerer Rahmen in Seltenheitsfarbe, innen die Effektfarbe.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.96)
	style.set_corner_radius_all(8)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = CardDatabase.get_rarity_color(card.rarity)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var card_icon := CardIcon.new()
	card_icon.setup(card, 42.0, false)
	row.add_child(card_icon)
	ban_icons[card.id] = card_icon

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var title := Label.new()
	title.text = card.title
	title.add_theme_color_override("font_color", card.color)
	title.add_theme_font_size_override("font_size", 13)
	title.clip_text = true
	text_box.add_child(title)

	var meta := Label.new()
	meta.text = "%s · %s" % [card.rarity, card.pool]
	meta.add_theme_color_override("font_color", CardDatabase.get_rarity_color(card.rarity))
	meta.add_theme_font_size_override("font_size", 10)
	text_box.add_child(meta)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 9)
	if evolution_banner != null:
		text_box.add_child(evolution_banner)

	var description := Label.new()
	description.text = card.description
	description.add_theme_color_override("font_color", Color(0.68, 0.72, 0.80, 1.0))
	description.add_theme_font_size_override("font_size", 10)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 2
	text_box.add_child(description)

	var cb := CheckButton.new()
	cb.button_pressed = Global.is_card_banned(card.id)
	cb.set_meta("card_id", card.id)
	cb.toggled.connect(_on_ban_toggled.bind(card.id, cb))
	row.add_child(cb)
	ban_checks[card.id] = cb
	CardMechanics.apply_tooltip(panel, card, true, class_hint)
	return panel

func _on_card_pool_toggled(pressed: bool, pool: String, checkbox: CheckButton) -> void:
	if not Global.is_local_host():
		_refresh_pool_states()
		return
	if not pressed and Global.enabled_card_pools.size() <= 1:
		checkbox.set_pressed_no_signal(true)
		SoundManager.play_sound("bounce", 0.2, 0.0)
		status_label.text = "Mindestens ein Kartenpool muss aktiv bleiben."
		return

	var previous := Global.enabled_card_pools.duplicate()
	Global.set_card_pool_enabled(pool, pressed)
	if not pressed:
		var needed := maxi(1, Global.cards_per_draft)
		var available := Global.get_available_card_count_for_match()
		if available < needed:
			Global.set_enabled_card_pools(previous)
			checkbox.set_pressed_no_signal(true)
			SoundManager.play_sound("bounce", 0.2, 0.0)
			status_label.text = "Pool bleibt aktiv: Sonst blieben nur %d von %d benötigten Karten übrig." % [available, needed]
			return

	SoundManager.play_sound("click")
	_update_pool_summary()
	_update_status()

func _on_all_card_pools_pressed() -> void:
	if not Global.is_local_host():
		return
	SoundManager.play_sound("click")
	Global.set_all_card_pools(true)
	_update_pool_summary()
	_update_status()

func _on_card_pools_changed() -> void:
	_refresh_pool_states()
	_update_pool_summary()
	_update_status()

func _refresh_pool_states() -> void:
	for pool in pool_checks.keys():
		var cb := pool_checks[pool] as CheckButton
		if cb != null:
			cb.set_pressed_no_signal(Global.is_card_pool_enabled(pool))

func _update_pool_summary() -> void:
	if pool_count_label == null:
		return
	var total := 0
	var base_cards := 0
	for card in CardDatabase.all_cards:
		if not CardDatabase.is_card_pool_enabled(card):
			continue
		total += 1
		if card.parent_card_id.is_empty():
			base_cards += 1
	var active := "Alle" if Global.enabled_card_pools.size() == Global.CARD_POOLS.size() else ", ".join(Global.enabled_card_pools)
	pool_count_label.text = "Aktiv: %s  ·  %d Karten (%d Grundkarten)" % [active, total, base_cards]

func _on_player_count_changed(value: float) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	var new_count := int(value)
	var required := Global.get_mode_required_players()
	if Global.is_team_mode() and required > 0 and new_count != required:
		_sync_from_global()
		status_label.text = "%s benötigt genau %d Spieler. Andere Spielerzahl zuerst im Modus auf FFA stellen." % [
			Global.get_match_mode_name(), required,
		]
		return
	if Global.network_mode:
		# Clients jenseits der neuen Spielerzahl freigeben.
		for i in range(new_count + 1, Global.MAX_PLAYERS + 1):
			if NetworkManager.has_client_slot(i):
				NetworkManager.kick_slot(i)
	Global.set_player_count(new_count)
	_sync_from_global()

func _on_scoring_changed(_value: float) -> void:
	if not Global.is_local_host():
		return
	Global.set_scoring_config(int(score_spin.value), int(survival_spin.value), int(kill_spin.value))
	_update_status()

func _on_base_hp_percent_changed(value: float) -> void:
	if not Global.is_local_host():
		return
	Global.set_base_hp_percent(int(value))
	_refresh_hero_stats_text()
	_update_status()

func _on_base_damage_changed(value: float) -> void:
	if not Global.is_local_host():
		return
	Global.set_base_damage(value)
	_refresh_hero_stats_text()
	_update_status()

func _on_rarity_percent_changed(value: float, rarity: String) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_rarity_percent(rarity, value)
	_update_rarity_sum()
	_update_status()

func _on_offer_changed(value: float) -> void:
	if not Global.is_local_host():
		return
	var offered := int(value)
	picks_spin.max_value = offered
	if int(picks_spin.value) > offered:
		picks_spin.set_value_no_signal(offered)
	Global.set_draft_config(int(picks_spin.value), offered)
	_update_status()

func _on_picks_changed(value: float) -> void:
	if not Global.is_local_host():
		return
	Global.set_draft_config(int(value), int(offer_spin.value))
	_update_status()

func _on_blind_pick_toggled(pressed: bool) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_blind_pick_enabled(pressed)
	SoundManager.play_sound("click")
	_update_status()

func _on_random_pick_toggled(pressed: bool) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_random_pick_enabled(pressed)
	SoundManager.play_sound("click")
	_update_status()

# --- Karten sperren ---

func _on_ban_toggled(pressed: bool, card_id: String, checkbox: CheckButton) -> void:
	if not Global.is_local_host():
		_refresh_ban_states()
		return
	if pressed:
		# Es müssen immer genug Karten für das komplette Angebot verfügbar bleiben.
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
	for card_id in ban_checks.keys():
		var cb := ban_checks[card_id] as CheckButton
		if cb != null:
			cb.set_pressed_no_signal(Global.is_card_banned(card_id))

func _on_unban_all() -> void:
	SoundManager.play_sound("click")
	if Global.banned_card_ids.is_empty():
		return
	Global.banned_card_ids.clear()
	Global.banned_cards_changed.emit()

# --- Status / Sync ---

func _sync_from_global() -> void:
	player_count_spin.set_value_no_signal(Global.player_count)
	score_spin.set_value_no_signal(Global.points_to_win)
	survival_spin.set_value_no_signal(Global.survival_points)
	kill_spin.set_value_no_signal(Global.kill_points)
	base_hp_spin.set_value_no_signal(Global.base_hp_percent)
	base_damage_spin.set_value_no_signal(Global.base_damage)
	offer_spin.set_value_no_signal(Global.cards_per_draft)
	picks_spin.max_value = Global.cards_per_draft
	picks_spin.set_value_no_signal(Global.draft_picks)
	if blind_pick_check != null:
		blind_pick_check.set_pressed_no_signal(Global.blind_pick_enabled and Global.network_mode)
	if random_pick_check != null:
		random_pick_check.set_pressed_no_signal(Global.random_pick_enabled)
	for rarity in rarity_spins.keys():
		rarity_spins[rarity].set_value_no_signal(Global.get_rarity_percent(rarity))
	_update_rarity_sum()
	_refresh_pool_states()
	_update_pool_summary()
	_refresh_map_controls()
	_refresh_mode_controls()
	_refresh_slot_visibility()
	_refresh_hero_highlights()
	_refresh_ban_states()
	_refresh_ready_checks()
	_refresh_kind_options()
	_refresh_host_controls()
	_refresh_hero_controls()
	_refresh_hero_stats_text()
	_refresh_character_tab()
	_refresh_network_status()
	_update_titles()
	_update_status()

func _update_rarity_sum() -> void:
	if rarity_sum_label == null:
		return
	var total := Global.get_rarity_percent_total()
	if total <= 0.0:
		rarity_sum_label.text = "Summe: 0 % — alle Seltenheiten werden gleich behandelt."
	elif absf(total - 100.0) < 0.01:
		rarity_sum_label.text = "Summe: 100 %"
	else:
		rarity_sum_label.text = "Summe: %.0f %% — wird automatisch auf 100 %% normalisiert." % total

func _refresh_network_status() -> void:
	if not Global.network_mode:
		net_label.visible = false
		footer_hint.text = "Lokal: Spieler 1 stellt die Lobby ein. Slots 2-6 sind Bots (Slot 2 optional lokaler Mensch)."
		return

	net_label.visible = true
	var role := "HOST" if Global.is_local_host() else ("ZUSCHAUER" if Global.is_spectator else "CLIENT")
	var info := NetworkManager.network_info
	if info.is_empty():
		info = Global.network_info
	var status := "ONLINE (%s, Slot %d): %s" % [role, Global.local_player_index, info]
	if Global.is_spectator:
		status = "ONLINE (ZUSCHAUER): %s" % info
	if Global.is_local_host() and NetworkManager.get_spectator_count() > 0:
		status += "  ·  Zuschauer: %d" % NetworkManager.get_spectator_count()
	var ping_text := NetworkManager.get_ping_text()
	if not ping_text.is_empty():
		status += "  ·  " + ping_text
	net_label.text = status
	if Global.is_spectator:
		footer_hint.text = "Zuschauer: Du siehst die Lobby und das Match, steuerst aber keinen Spieler-Slot."
	else:
		footer_hint.text = "Online: Der Host konfiguriert jeden Slot als Bot oder Mensch. Jeder Mensch wählt seinen Helden und bestätigt Bereit."

func _update_status() -> void:
	var total_cards := CardDatabase.all_cards.size()
	var available_total := Global.get_available_card_count()
	var available := Global.get_available_card_count_for_match()
	ban_count.text = "%d von %d gesperrt · %d Grundkarten · min. %d je Held" % [
		Global.banned_card_ids.size(), total_cards, available_total, available,
	]
	var active_modifiers: Array[String] = []
	if Global.blind_pick_enabled and Global.network_mode:
		active_modifiers.append("Blind")
	if Global.random_pick_enabled:
		active_modifiers.append("Random")
	var modifier_summary := ""
	if not active_modifiers.is_empty():
		modifier_summary = "  ·  Modifier: %s" % ", ".join(active_modifiers)
	draft_summary.text = "Modus %s  ·  Spieler %d  ·  Draft %d/%d  ·  Ziel %d P (Überleben +%d, Kill +%d)  ·  HP %d %%  ·  DMG %d  ·  Map %s  ·  Pool min. %d/Held%s" % [
		Global.get_match_mode_name(), Global.player_count, Global.draft_picks, Global.cards_per_draft,
		Global.points_to_win, Global.survival_points, Global.kill_points,
		Global.base_hp_percent, int(Global.base_damage),
		Global.get_map_name(Global.selected_map_id), available, modifier_summary,
	]

	var enough_cards := available >= Global.cards_per_draft
	var is_host := Global.is_local_host()
	var all_ready := Global.all_players_ready()
	var missing: Array[int] = []
	if Global.network_mode:
		missing = NetworkManager.missing_human_slots()
	start_btn.disabled = not (enough_cards and is_host and all_ready and missing.is_empty())

	if Global.is_spectator:
		status_label.text = "Zuschauer — du siehst das Match, steuerst aber keinen Spieler-Slot."
	elif not enough_cards:
		status_label.text = "Zu wenige Karten — Pools/Sperren prüfen: mindestens %d müssen für alle Helden verfügbar sein." % Global.cards_per_draft
	elif not is_host:
		if Global.network_mode and not Global.is_player_ready(Global.local_player_index):
			status_label.text = "Wähle deinen Helden und setze dich bereit."
		else:
			status_label.text = "Bereit — warte auf den Host, er startet das Match."
	elif not missing.is_empty():
		var names: Array[String] = []
		for slot in missing:
			names.append("Slot %d" % slot)
		status_label.text = "Warte auf Mitspieler für %s ..." % ", ".join(names)
	elif not all_ready:
		var waiting: Array[String] = []
		for i in Global.get_active_player_indices():
			if not Global.is_player_ready(i):
				waiting.append("Slot %d" % i)
		status_label.text = "Warte auf: %s" % ", ".join(waiting)
	else:
		var prefix := "Online-Match" if Global.network_mode else "Match"
		status_label.text = "%s: Alle bereit — der Host kann starten." % prefix

# --- Bestätigen / Verlassen ---

func _on_start_pressed() -> void:
	if not Global.is_local_host():
		status_label.text = "Nur der Host kann das Match starten."
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	if Global.network_mode:
		var missing := NetworkManager.missing_human_slots()
		if not missing.is_empty():
			status_label.text = "Es fehlen noch Mitspieler: %s" % str(missing)
			SoundManager.play_sound("bounce", 0.2, 0.0)
			return
	if not Global.all_players_ready():
		status_label.text = "Alle Spieler müssen bereit sein."
		SoundManager.play_sound("bounce", 0.2, 0.0)
		return
	if Global.get_available_card_count_for_match() < Global.cards_per_draft:
		status_label.text = "Zu viele Karten gesperrt — mindestens %d müssen für alle Helden verfügbar sein." % Global.cards_per_draft
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

# --- Helpers ---

func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _add_section_title(parent: VBoxContainer, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
