class_name GameLobby
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
const LevelModifierDefsClass = preload("res://scripts/level_modifier_defs.gd")
const MeleeWeaponTileScript = preload("res://scripts/ui/melee_weapon_tile.gd")
const LevelPreviewRendererScript = preload("res://scripts/ui/level_preview_renderer.gd")
const RadarChartScript = preload("res://scripts/ui/radar_chart.gd")
const LEVEL_THUMB_SIZE: Vector2 = Vector2(224, 126)
const PowerupScene = preload("res://scenes/level/powerup.tscn")
const POWERUP_PREVIEW_SIZE: Vector2 = Vector2(200, 92)

@onready var tabs: TabContainer = $Panel/Margin/VBox/Tabs
@onready var status_label: Label = $Panel/Margin/VBox/Header/StatusLabel
@onready var player_count_spin: SpinBox = $Panel/Margin/VBox/Header/PlayerCountSpin
@onready var draft_summary: Label = $Panel/Margin/VBox/DraftSummary
@onready var net_label: Label = $Panel/Margin/VBox/NetLabel
@onready var footer_hint: Label = $Panel/Margin/VBox/Footer/FooterHint

# Heldenslots (dynamisch für 1..6 aufgebaut)
@onready var slot_list: VBoxContainer = $Panel/Margin/VBox/Tabs/Heroes/HeroesScroll/SlotList

# Die Inhalte von "Charakter", "Regeln", "Karten" und "Modifier" werden im
# Skript aufgebaut, damit die Lobby auch bei kleineren Fenstern flexibel bleibt.
@onready var character_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Charakter
@onready var rules_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Rules
@onready var cards_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Cards
@onready var modifier_tab: VBoxContainer = $Panel/Margin/VBox/Tabs/Modifier

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
var melee_enabled_check: CheckButton
var random_pick_check: CheckButton
var gamble_check: CheckButton
var pre_draft_spin: SpinBox
var pre_draft_random_check: CheckButton
var map_option: OptionButton
var map_info_label: Label
var mode_option: OptionButton
var mode_info_label: Label
var loadout_option: OptionButton
var loadout_name_edit: LineEdit
var loadout_load_btn: Button
var loadout_save_btn: Button
var loadout_delete_btn: Button
var loadout_reset_btn: Button
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
var ban_panels: Dictionary = {}
var ban_meta_labels: Dictionary = {}
var pool_charts_box: VBoxContainer
# Filter der Powerup-Kartenliste: Haupt-Tags untereinander ODER, Sub-Tags
# untereinander ODER, beide Gruppen zusammen UND.
var ban_filter_btn: MenuButton
var ban_filter_label: Label
var ban_filter_main: Array[String] = []
var ban_filter_sub: Array[String] = []
var _ban_filter_item_tags: Dictionary = {} # PopupMenu-ID -> ["main"/"sub", Tag]

# Runden-Modifier-Controls
var modifier_rate_spin: SpinBox
var modifier_checks: Dictionary = {}
var modifier_count_label: Label
var modifier_all_btn: Button
var modifier_none_btn: Button

# Levels-Controls (Reiter wird im Skript angelegt, nicht in lobby.tscn)
var levels_tab: VBoxContainer = null
var level_scroll: ScrollContainer = null
var level_grid: GridContainer = null
var level_count_label: Label = null
var level_all_btn: Button = null
var level_none_btn: Button = null
# map_id -> { card, texture, placeholder, badge, name, check }
var level_cards: Dictionary = {}
var level_preview_renderer: LevelPreviewRendererScript = null
var _level_card_on: StyleBoxFlat
var _level_card_off: StyleBoxFlat
var level_viewer: Control = null
var level_viewer_title: Label = null
var level_viewer_texture: TextureRect = null
var level_viewer_placeholder: Label = null
var level_viewer_desc: Label = null
var level_viewer_check: CheckButton = null
var level_viewer_status: Label = null
var level_viewer_close_btn: Button = null
var _level_viewer_map: String = ""

# Powerups-Controls (Reiter wird im Skript angelegt, nicht in lobby.tscn)
var powerups_tab: VBoxContainer = null
var powerup_count_label: Label = null
var powerup_all_btn: Button = null
var powerup_none_btn: Button = null
# kind -> { card, preview, badge, name, desc, check }
var powerup_cards: Dictionary = {}

# Charakter-Controls
var fur_picker: ColorPickerButton = null
var eye_picker: ColorPickerButton = null
var pants_picker: ColorPickerButton = null
var wand_tip_picker: ColorPickerButton = null
var shot_color_picker: ColorPickerButton = null
var wand_shape_option: OptionButton = null
var tusk_shape_option: OptionButton = null
var player_name_edit: LineEdit = null
# Vier Waffenkacheln unter der Charaktervorschau, Reihenfolge wie MELEE_WEAPONS.
var melee_weapon_tiles: Array = []
var character_preview: PigModular = null
# Baukasten-Steuerelemente: Teile-Schlüssel (PigModular.PART_OPTIONS) -> OptionButton.
var part_options: Dictionary = {}
var part_eye_size_slider: HSlider = null
var part_snout_size_slider: HSlider = null
var part_belt_check: CheckButton = null
var part_belt_slider: HSlider = null
var part_tail_side_option: OptionButton = null
var part_tail_visible_check: CheckButton = null
var hair_color_picker: ColorPickerButton = null
var top_color_picker: ColorPickerButton = null
# Regler senden beim Ziehen viele Änderungen; an den Host geht nur der letzte
# Stand nach kurzer Pause.
var _parts_send_timer: Timer = null
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
	tabs.set_tab_title(4, "Modifier")

	start_btn.pressed.connect(_on_start_pressed)
	ready_btn.pressed.connect(_on_ready_pressed)
	back_btn.pressed.connect(_on_back_pressed)
	player_count_spin.value_changed.connect(_on_player_count_changed)
	Global.banned_cards_changed.connect(_on_banned_cards_changed)
	Global.card_pools_changed.connect(_on_card_pools_changed)
	Global.map_changed.connect(_on_map_changed)
	Global.map_pool_changed.connect(_on_map_pool_changed)
	Global.powerup_pool_changed.connect(_on_powerup_pool_changed)
	Global.match_mode_changed.connect(_on_match_mode_changed)
	Global.lobby_state_changed.connect(_on_lobby_state_changed)
	Global.level_modifiers_changed.connect(_on_level_modifiers_changed)
	Global.lobby_loadouts_changed.connect(_on_lobby_loadouts_changed)
	Global.lobby_last_loadout_saved.connect(_on_last_loadout_saved)
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
	_build_modifier_tab()
	_build_levels_tab()
	_build_powerups_tab()
	# Summary auch ohne open_lobby() korrekt anzeigen.
	_sync_from_global()

func open_lobby() -> void:
	visible = true
	tabs.current_tab = 0
	# Offline und als Host gelten immer die zuletzt eingestellten Regeln ("Last").
	if not Global.network_mode or NetworkManager.is_host:
		Global.restore_last_lobby_settings()
	if Global.network_mode:
		if Global.is_local_host():
			Global.set_player_ready(1, false)
		else:
			Global.set_player_ready(Global.local_player_index, false)
	else:
		Global.reset_lobby_state()
	_sync_from_global()
	# Preset-Auswahl auf "Last" stellen, damit Vorschau und LADEN zu den
	# aktiven Regeln passen (vorher stand dort immer "Standard").
	_refresh_loadout_controls(Global.LOBBY_LAST_LOADOUT)
	get_tree().paused = true
	_debug_log("--- open_lobby (vorher state=%s)" % str(Global.current_state))

func close_lobby() -> void:
	visible = false
	_close_level_viewer()

# Diagnose (vorübergehend): Bei jedem Mausklick in der Lobby festhalten,
# welches Control den Klick bekommt. Landet in user://lobby_click.log.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	var line := "%s %s=%s hover=%s paused=%s state=%s fps=%d tab=%d" % [
		Time.get_time_string_from_system(), "DOWN" if mb.pressed else "UP",
		str(mb.position),
		str(hovered.get_path()) if hovered != null else "<keins>",
		str(get_tree().paused), str(Global.current_state),
		Engine.get_frames_per_second(), tabs.current_tab,
	]
	_debug_log(line)

func _debug_log(line: String) -> void:
	var f := FileAccess.open("user://lobby_click.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("user://lobby_click.log", FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)

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
	return "%s (%s)\nBasis-HP (effektiv): %d\nBasis-Schaden: %d\nBasis-Munition: %d\nFeuerintervall: %.2fs\nNachladezeit: %.1fs\nPassive: %s\nAktiv: %s (%ss Cooldown)\n%s\n%s" % [
		hero.name, hero.role, effective_hp, int(Global.base_damage),
		hero.base_ammo, hero.base_fire_rate_cooldown, hero.base_reload_time,
		hero.passive_desc, hero.ability_name, hero.ability_cooldown,
		Global.get_hero_ability_details(hero), hero.description,
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

func _on_level_modifiers_changed() -> void:
	_refresh_modifier_controls()
	_update_status()

func _on_slot_assigned(slot: int) -> void:
	_sync_from_global()
	# Nach dem Beitritt das gespeicherte Profil einmalig an den Host senden,
	# damit der eigene Charakter sofort für alle sichtbar ist.
	if slot >= 1 and NetworkManager.is_client and slot == Global.local_player_index:
		var look := Global.get_pig_appearance(slot)
		NetworkManager.request_player_name(Global.get_custom_player_name(slot))
		NetworkManager.request_melee_weapon(Global.get_melee_weapon(slot))
		NetworkManager.request_pig_parts(Global.get_pig_parts(slot))
		NetworkManager.request_pig_appearance(
			look["fur"],
			look["eyes"],
			look["pants"],
			look["wand_tip_shape"],
			look["wand_tip_color"],
			look["shot_color"],
			str(look["tusk_shape"])
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

	character_preview = PigModular.new()
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
	_add_character_melee_tiles(preview_column)

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
	_add_character_name_row(controls)
	_add_character_color_row(controls, "Fellfarbe", "Grundfarbe von Kopf, Körper und Ohren.", fur_picker)
	_add_character_color_row(controls, "Augenfarbe", "Farbe der Iris. Die Augen bleiben weiß umrandet.", eye_picker)
	_add_character_color_row(controls, "Hosenfarbe", "Farbe von Hose oder Rock inklusive Gürtel.", pants_picker)
	_add_character_tusk_row(controls)
	_add_character_parts_section(controls)
	_add_character_shape_row(controls)
	_add_character_color_row(controls, "Lötspitzen-Glut", "Farbe, in der die Spitze des Lötkolbens glüht.", wand_tip_picker)
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
	desc_label.text = "Form der Lötspitze, z. B. Kegel, Meißel, Kugel oder Diamant."
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

func _add_character_text_column(row: HBoxContainer, title: String, description: String) -> void:
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

func _add_character_name_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	_add_character_text_column(row, "Benutzername", "Wird in Lobby und Spielstand angezeigt (max. %d Zeichen)." % Global.PLAYER_NAME_MAX_LENGTH)

	player_name_edit = LineEdit.new()
	player_name_edit.custom_minimum_size = Vector2(180, 38)
	player_name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	player_name_edit.max_length = Global.PLAYER_NAME_MAX_LENGTH
	player_name_edit.placeholder_text = "Name eingeben"
	player_name_edit.text_submitted.connect(_on_player_name_submitted)
	player_name_edit.focus_exited.connect(_commit_player_name)
	row.add_child(player_name_edit)

func _add_character_tusk_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	_add_character_text_column(row, "Hauer", "Form der Eberhauer: Klein, Lang, Säbel, Doppelt oder Stummel.")

	tusk_shape_option = OptionButton.new()
	tusk_shape_option.custom_minimum_size = Vector2(120, 42)
	tusk_shape_option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in range(Global.TUSK_SHAPES.size()):
		tusk_shape_option.add_item(Global.get_tusk_shape_label(Global.TUSK_SHAPES[i]), i)
	tusk_shape_option.item_selected.connect(_on_character_tusk_shape_changed)
	row.add_child(tusk_shape_option)

# Baukasten: Körperform, Gesichtsteile, Frisur, Kleidung und Schwanz.
const CHARACTER_PART_LABELS: Dictionary = {
	"body": "Körperform", "eyes": "Augen", "snout": "Rüssel", "nose": "Nasenlöcher",
	"ears": "Ohren", "hair": "Frisur", "top": "Oberteil", "bottom": "Unterteil",
	"tail": "Schwanz",
}

func _add_character_parts_section(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	parent.add_child(header)
	_add_character_text_column(header, "Aussehen", "Körperform, Gesicht, Frisur, Kleidung und Schwanz frei kombinieren.")
	var random_button := Button.new()
	random_button.text = "ZUFÄLLIG"
	random_button.tooltip_text = "Alle Teile neu würfeln. Farben bleiben."
	random_button.custom_minimum_size = Vector2(120, 38)
	random_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	random_button.pressed.connect(_on_character_parts_randomize)
	header.add_child(random_button)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)

	part_options.clear()
	for key in ["body", "eyes", "snout", "nose", "ears", "hair", "top", "bottom", "tail"]:
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(200, 32)
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for entry in PigModular.PART_OPTIONS[key]:
			option.add_item(str(entry[1]))
		option.item_selected.connect(func(_index: int): _commit_character_parts())
		_add_character_grid_row(grid, str(CHARACTER_PART_LABELS[key]), option)
		part_options[key] = option
		match key:
			"eyes":
				part_eye_size_slider = _make_character_part_slider(PigModular.SIZE_MIN, PigModular.SIZE_MAX, 0.05)
				_add_character_grid_row(grid, "Augengröße", part_eye_size_slider)
			"snout":
				part_snout_size_slider = _make_character_part_slider(PigModular.SIZE_MIN, PigModular.SIZE_MAX, 0.05)
				_add_character_grid_row(grid, "Rüsselgröße", part_snout_size_slider)
			"hair":
				hair_color_picker = _make_character_part_picker()
				_add_character_grid_row(grid, "Haarfarbe", hair_color_picker)
			"top":
				top_color_picker = _make_character_part_picker()
				_add_character_grid_row(grid, "Oberteil-Farbe", top_color_picker)
			"bottom":
				var belt_row := HBoxContainer.new()
				belt_row.add_theme_constant_override("separation", 8)
				part_belt_check = CheckButton.new()
				part_belt_check.tooltip_text = "Gürtel tragen"
				part_belt_check.toggled.connect(func(_pressed: bool): _commit_character_parts())
				belt_row.add_child(part_belt_check)
				part_belt_slider = _make_character_part_slider(PigModular.BELT_WIDTH_MIN, PigModular.BELT_WIDTH_MAX, 0.1)
				part_belt_slider.tooltip_text = "Gürteldicke"
				part_belt_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				belt_row.add_child(part_belt_slider)
				_add_character_grid_row(grid, "Gürtel", belt_row)
			"tail":
				var tail_row := HBoxContainer.new()
				tail_row.add_theme_constant_override("separation", 8)
				part_tail_side_option = OptionButton.new()
				part_tail_side_option.add_item("Links")
				part_tail_side_option.add_item("Rechts")
				part_tail_side_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				part_tail_side_option.item_selected.connect(func(_index: int): _commit_character_parts())
				tail_row.add_child(part_tail_side_option)
				part_tail_visible_check = CheckButton.new()
				part_tail_visible_check.text = "Sichtbar"
				part_tail_visible_check.toggled.connect(func(_pressed: bool): _commit_character_parts())
				tail_row.add_child(part_tail_visible_check)
				_add_character_grid_row(grid, "Schwanzseite", tail_row)

	_parts_send_timer = Timer.new()
	_parts_send_timer.one_shot = true
	_parts_send_timer.wait_time = 0.2
	_parts_send_timer.timeout.connect(_send_character_parts)
	parent.add_child(_parts_send_timer)

func _add_character_grid_row(grid: GridContainer, title: String, control: Control) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.86, 0.89, 0.95))
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _make_character_part_slider(min_value: float, max_value: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(160, 28)
	slider.value_changed.connect(func(_value: float): _commit_character_parts())
	return slider

func _make_character_part_picker() -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(120, 32)
	picker.edit_alpha = false
	picker.color_changed.connect(func(_color: Color): _commit_character_parts())
	return picker

## Liest alle Baukasten-Steuerelemente in ein Teile-Dictionary.
func _character_parts_from_ui() -> Dictionary:
	var parts := {}
	for key in part_options.keys():
		var option: OptionButton = part_options[key]
		var list: Array = PigModular.PART_OPTIONS[key]
		parts[key] = str(list[clampi(option.selected, 0, list.size() - 1)][0])
	parts["eye_size"] = part_eye_size_slider.value
	parts["snout_size"] = part_snout_size_slider.value
	parts["belt"] = part_belt_check.button_pressed
	parts["belt_width"] = part_belt_slider.value
	parts["tail_side"] = -1.0 if part_tail_side_option.selected == 0 else 1.0
	parts["tail_visible"] = part_tail_visible_check.button_pressed
	parts["hair_color"] = hair_color_picker.color
	# Solange niemand die Haarfarbe anfasst, bleibt sie "automatisch" (folgt dem Fell).
	var stored: Color = Global.get_pig_parts(_character_slot).get("hair_color", Color(0, 0, 0, 0))
	if stored.a <= 0.0 and hair_color_picker.color.is_equal_approx(fur_picker.color.darkened(0.18)):
		parts["hair_color"] = Color(0, 0, 0, 0)
	parts["top_color"] = top_color_picker.color
	return parts

## Stellt die Baukasten-Steuerelemente auf die Teile eines Slots (ohne Signale
## auszuwerten: Aufrufer setzt _updating_character_ui).
func _refresh_character_parts_ui(parts: Dictionary, can_customize: bool) -> void:
	if part_options.is_empty():
		return
	for key in part_options.keys():
		var option: OptionButton = part_options[key]
		var list: Array = PigModular.PART_OPTIONS[key]
		var index := 0
		for i in range(list.size()):
			if str(list[i][0]) == str(parts.get(key, "")):
				index = i
				break
		option.select(index)
		option.disabled = not can_customize
	part_eye_size_slider.set_value_no_signal(float(parts.get("eye_size", 1.0)))
	part_snout_size_slider.set_value_no_signal(float(parts.get("snout_size", 1.0)))
	part_belt_check.set_pressed_no_signal(bool(parts.get("belt", true)))
	part_belt_slider.set_value_no_signal(float(parts.get("belt_width", 2.7)))
	part_tail_side_option.select(0 if float(parts.get("tail_side", -1.0)) < 0.0 else 1)
	part_tail_visible_check.set_pressed_no_signal(bool(parts.get("tail_visible", true)))
	# Haarfarbe "automatisch" (Alpha 0) zeigt den aus dem Fell abgeleiteten Ton.
	var hair: Color = parts.get("hair_color", Color(0, 0, 0, 0))
	if hair.a <= 0.0:
		hair = fur_picker.color.darkened(0.18)
	hair_color_picker.color = hair
	top_color_picker.color = parts.get("top_color", PigModular.DEFAULT_TOP_COLOR)
	for control: Control in [part_eye_size_slider, part_snout_size_slider, part_belt_slider]:
		(control as Range).editable = can_customize
	for button: BaseButton in [part_belt_check, part_tail_side_option, part_tail_visible_check, hair_color_picker, top_color_picker]:
		button.disabled = not can_customize

func _commit_character_parts() -> void:
	if _updating_character_ui or not _character_ui_ready:
		return
	var slot := _character_slot
	if not _can_customize_character_slot(slot):
		return
	Global.set_pig_parts(slot, _character_parts_from_ui())
	if NetworkManager.is_client and slot == Global.local_player_index and _parts_send_timer:
		_parts_send_timer.start()

func _send_character_parts() -> void:
	if NetworkManager.is_client and Global.local_player_index >= 1:
		NetworkManager.request_pig_parts(Global.get_pig_parts(Global.local_player_index))

func _on_character_parts_randomize() -> void:
	var slot := _character_slot
	if not _can_customize_character_slot(slot):
		return
	SoundManager.play_sound("click")
	Global.set_pig_parts(slot, PigModular.random_parts(Global.get_pig_parts(slot)))
	_refresh_character_tab()
	if NetworkManager.is_client and slot == Global.local_player_index:
		_send_character_parts()

func _add_character_melee_tiles(parent: VBoxContainer) -> void:
	var caption := Label.new()
	caption.text = "NAHKAMPFWAFFE [E]"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	parent.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	melee_weapon_tiles.clear()
	for i in range(Global.MELEE_WEAPONS.size()):
		var tile = MeleeWeaponTileScript.new(Global.MELEE_WEAPONS[i])
		tile.pressed.connect(_on_character_melee_weapon_changed.bind(i))
		row.add_child(tile)
		melee_weapon_tiles.append(tile)

func _update_melee_weapon_tiles(weapon_id: String) -> void:
	for tile in melee_weapon_tiles:
		tile.set_selected(tile.weapon_id == weapon_id)

func _on_character_melee_weapon_changed(index: int) -> void:
	if _updating_character_ui or not _character_ui_ready:
		return
	var slot := _character_slot
	if not _can_customize_character_slot(slot):
		return
	var weapon_id: String = Global.MELEE_WEAPONS[clampi(index, 0, Global.MELEE_WEAPONS.size() - 1)]
	Global.set_melee_weapon(slot, weapon_id)
	_update_melee_weapon_tiles(weapon_id)
	if NetworkManager.is_client and slot == Global.local_player_index:
		NetworkManager.request_melee_weapon(weapon_id)

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

# Vorschau in Teamfarbe, sobald ein Team-Modus gewählt ist (wie im Spiel).
func _character_team_tint(slot: int) -> Color:
	if not Global.is_team_mode() or slot < 1:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Global.get_team_color(Global.get_team_for_slot(slot))

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
	if tusk_shape_option:
		tusk_shape_option.select(maxi(0, Global.TUSK_SHAPES.find(str(look.get("tusk_shape", "small")))))
	# Während der Eingabe nicht überschreiben, sonst springt der Cursor.
	if player_name_edit and not player_name_edit.has_focus():
		player_name_edit.text = Global.get_custom_player_name(look_slot)
	var melee_id := Global.get_melee_weapon(look_slot)
	_update_melee_weapon_tiles(melee_id)
	var parts := Global.get_pig_parts(look_slot)
	_refresh_character_parts_ui(parts, can_customize)
	_updating_character_ui = false

	fur_picker.disabled = not can_customize
	eye_picker.disabled = not can_customize
	pants_picker.disabled = not can_customize
	wand_tip_picker.disabled = not can_customize
	shot_color_picker.disabled = not can_customize
	wand_shape_option.disabled = not can_customize
	if tusk_shape_option:
		tusk_shape_option.disabled = not can_customize
	if player_name_edit:
		player_name_edit.editable = can_customize and not Global.is_bot_slot(look_slot)
	for tile in melee_weapon_tiles:
		tile.set_locked(not can_customize or not Global.melee_enabled)

	if character_preview:
		character_preview.setup(look["fur"], look["eyes"], look["pants"])
		character_preview.set_outfit(Global.get_player_hero_id(look_slot))
		character_preview.set_team_color(_character_team_tint(look_slot))
		character_preview.set_tusk_shape(str(look.get("tusk_shape", "small")))
		character_preview.apply_parts(parts)
	if character_preview_wand:
		character_preview_wand.setup(look["wand_tip_shape"], look["wand_tip_color"])
		character_preview_wand.set_grip_color(_character_team_tint(look_slot))

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
			character_hint.text = "Du kannst deinen eigenen Slot anpassen. Charakter, Lötspitze und Schussfarbe werden mit dem Host synchronisiert und automatisch gespeichert."
		elif slots.size() > 1:
			character_hint.text = "Wähle oben den Spieler-Slot. Alle Anpassungen gelten sofort fürs Match; der eigene Slot wird automatisch gespeichert."
		else:
			character_hint.text = "Charakter, Lötspitze und Schussfarbe werden sofort übernommen und automatisch gespeichert."

	tabs.set_tab_disabled(1, slots.is_empty())
	if slots.is_empty() and tabs.current_tab == 1:
		tabs.current_tab = 0

func _on_lobby_tab_changed(tab: int) -> void:
	if tab == 1:
		_refresh_character_tab()
	if levels_tab != null and tabs.get_tab_control(tab) == levels_tab:
		# Vorschauen erst rendern, wenn der Reiter wirklich angesehen wird.
		_request_level_previews()

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

func _on_character_tusk_shape_changed(_index: int) -> void:
	_commit_character_appearance()

func _selected_tusk_shape() -> String:
	if tusk_shape_option == null:
		return "small"
	var index := clampi(tusk_shape_option.selected, 0, Global.TUSK_SHAPES.size() - 1)
	return Global.TUSK_SHAPES[index]

func _on_player_name_submitted(_text: String) -> void:
	_commit_player_name()
	player_name_edit.release_focus()

func _commit_player_name() -> void:
	if _updating_character_ui or not _character_ui_ready or player_name_edit == null:
		return
	var slot := _character_slot
	if not _can_customize_character_slot(slot) or Global.is_bot_slot(slot):
		return
	Global.set_player_name(slot, player_name_edit.text)
	player_name_edit.text = Global.get_custom_player_name(slot)
	if NetworkManager.is_client and slot == Global.local_player_index:
		NetworkManager.request_player_name(Global.get_custom_player_name(slot))

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
		shot_color,
		_selected_tusk_shape()
	)
	if NetworkManager.is_client and slot == Global.local_player_index:
		NetworkManager.request_pig_appearance(
			fur_picker.color,
			eye_picker.color,
			pants_picker.color,
			shape,
			tip_color,
			shot_color,
			_selected_tusk_shape()
		)

func _on_reset_character_colors() -> void:
	if not _can_customize_character_slot(_character_slot):
		return
	var slot := _character_slot
	Global.reset_pig_appearance(slot)
	_refresh_character_tab()
	if NetworkManager.is_client and slot == Global.local_player_index:
		NetworkManager.request_pig_parts(Global.get_pig_parts(slot))
		var look := Global.get_pig_appearance(slot)
		NetworkManager.request_pig_appearance(
			look["fur"],
			look["eyes"],
			look["pants"],
			look["wand_tip_shape"],
			look["wand_tip_color"],
			look["shot_color"],
			str(look["tusk_shape"])
		)

func _refresh_host_controls() -> void:
	# Match-Regeln und Karten darf nur der Host ändern.
	var is_host := Global.is_local_host()
	for spin in [score_spin, survival_spin, kill_spin, base_hp_spin, base_damage_spin, picks_spin, offer_spin, pre_draft_spin]:
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
	for card_id in ban_checks.keys():
		var check := ban_checks[card_id] as CheckButton
		if check != null:
			check.disabled = not is_host or _is_card_melee_locked(CardDatabase.get_card(card_id))
	if blind_pick_check != null:
		blind_pick_check.disabled = not is_host or not Global.network_mode
	if melee_enabled_check != null:
		melee_enabled_check.disabled = not is_host
	# Der Nahkampf-Pool lässt sich nur schalten, solange Nahkampf aktiv ist.
	if pool_checks.has("Nahkampf"):
		var melee_pool_check := pool_checks["Nahkampf"] as CheckButton
		if melee_pool_check != null:
			melee_pool_check.disabled = not is_host or not Global.melee_enabled
	if random_pick_check != null:
		random_pick_check.disabled = not is_host
	if gamble_check != null:
		gamble_check.disabled = not is_host
	if pre_draft_random_check != null:
		pre_draft_random_check.disabled = not is_host or Global.pre_draft_picks <= 0
	_refresh_modifier_controls()
	_refresh_level_controls()
	_refresh_powerup_controls()
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
	# Abgeschaltete Levels (Reiter "Levels") lassen sich nicht als feste Map wählen.
	for i in range(mini(ids.size(), map_option.item_count)):
		map_option.set_item_disabled(i, ids[i] != Global.MAP_RANDOM and not Global.is_map_enabled(ids[i]))
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
	_refresh_character_tab()

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

func _slot_name_suffix(slot: int) -> String:
	var custom := Global.get_custom_player_name(slot)
	return "" if custom.is_empty() else " · %s" % custom

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
			title.text = team_prefix + ("SPIELER 1 (HOST)%s — HELD WÄHLEN" if Global.network_mode else "SPIELER 1%s — HELD WÄHLEN") % _slot_name_suffix(1)
			title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 1.0))
		elif Global.is_bot_slot(i):
			title.text = team_prefix + "SLOT %d / BOT — HELD WÄHLEN" % i
			title.add_theme_color_override("font_color", Color(0.65, 0.7, 0.8, 1.0))
		elif Global.network_mode:
			var you := " (DU)" if i == Global.local_player_index else ""
			var state := "verbunden" if NetworkManager.has_client_slot(i) else "warte auf Mitspieler"
			title.text = team_prefix + "SLOT %d / MENSCH%s%s — %s" % [i, _slot_name_suffix(i), you, state]
			title.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 1.0))
		else:
			title.text = team_prefix + "SPIELER %d%s — HELD WÄHLEN" % [i, _slot_name_suffix(i)]
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
	# Nahkampf-Schalter weit oben: schaltet Taste E und den Kartenpool "Nahkampf" gemeinsam.
	melee_enabled_check = CheckButton.new()
	melee_enabled_check.text = "Nahkampfwaffen (Taste E) und Nahkampf-Karten"
	melee_enabled_check.tooltip_text = "Aus: Niemand kann mit E zuschlagen, und Karten aus dem Pool „Nahkampf“ werden nicht angeboten."
	melee_enabled_check.add_theme_font_size_override("font_size", 15)
	melee_enabled_check.button_pressed = Global.melee_enabled
	melee_enabled_check.toggled.connect(_on_melee_enabled_toggled)
	body.add_child(melee_enabled_check)

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
	_add_section_title(body, "SPIELMODUS & SPIELFELD", Color(1.0, 0.55, 0.55, 1.0))
	# Modus und Map stehen nebeneinander, darunter jeweils ihre Erklärung.
	var choice_row := HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 24)
	body.add_child(choice_row)

	var mode_column := VBoxContainer.new()
	mode_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_column.size_flags_stretch_ratio = 1.0
	choice_row.add_child(mode_column)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	mode_column.add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "Modus:"
	mode_label.add_theme_font_size_override("font_size", 15)
	mode_row.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.custom_minimum_size = Vector2(200, 0)
	for mode_id in Global.MATCH_MODE_ORDER:
		mode_option.add_item(Global.get_match_mode_name(mode_id))
	mode_option.item_selected.connect(_on_mode_selected)
	mode_row.add_child(mode_option)

	mode_info_label = Label.new()
	mode_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_info_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	mode_info_label.add_theme_font_size_override("font_size", 12)
	mode_info_label.autowrap_mode = 2
	mode_column.add_child(mode_info_label)

	var map_column := VBoxContainer.new()
	map_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_column.size_flags_stretch_ratio = 1.0
	choice_row.add_child(map_column)
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 12)
	map_column.add_child(map_row)

	var map_label := Label.new()
	map_label.text = "Map:"
	map_label.add_theme_font_size_override("font_size", 15)
	map_row.add_child(map_label)

	map_option = OptionButton.new()
	map_option.custom_minimum_size = Vector2(200, 0)
	for map_id in _map_ids():
		map_option.add_item(Global.get_map_name(map_id))
	map_option.item_selected.connect(_on_map_selected)
	map_row.add_child(map_option)

	map_info_label = Label.new()
	map_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_info_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	map_info_label.add_theme_font_size_override("font_size", 12)
	map_info_label.autowrap_mode = 2
	map_column.add_child(map_info_label)

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

	var pre_draft_row := HBoxContainer.new()
	pre_draft_row.add_theme_constant_override("separation", 12)
	body.add_child(pre_draft_row)

	var pre_draft_label := Label.new()
	pre_draft_label.text = "Pre-Draft:"
	pre_draft_label.add_theme_font_size_override("font_size", 15)
	pre_draft_row.add_child(pre_draft_label)

	pre_draft_spin = SpinBox.new()
	pre_draft_spin.custom_minimum_size = Vector2(100, 0)
	pre_draft_spin.min_value = 0
	pre_draft_spin.max_value = Global.PRE_DRAFT_MAX_PICKS
	pre_draft_spin.step = 1
	pre_draft_spin.value = Global.pre_draft_picks
	pre_draft_spin.tooltip_text = "So viele Karten draftet jeder Spieler vor der ersten Runde. 0 = aus."
	pre_draft_spin.value_changed.connect(_on_pre_draft_picks_changed)
	pre_draft_row.add_child(pre_draft_spin)

	pre_draft_random_check = CheckButton.new()
	pre_draft_random_check.text = "Pre-Draft-Karten zufällig wählen"
	pre_draft_random_check.tooltip_text = "Die Pre-Draft-Picks werden automatisch zufällig aus dem Angebot gezogen. Gilt nur für den Pre-Draft, die Drafts nach den Runden bleiben normal."
	pre_draft_random_check.button_pressed = Global.pre_draft_random
	pre_draft_random_check.toggled.connect(_on_pre_draft_random_toggled)
	pre_draft_row.add_child(pre_draft_random_check)

	var pre_draft_hint := Label.new()
	pre_draft_hint.text = "Picks pro Spieler vor Matchbeginn (0 = aus)."
	pre_draft_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre_draft_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	pre_draft_hint.add_theme_font_size_override("font_size", 12)
	pre_draft_hint.autowrap_mode = 2
	pre_draft_row.add_child(pre_draft_hint)

	body.add_child(HSeparator.new())
	_add_section_title(body, "DRAFT-MODIFIER", Color(0.82, 0.62, 1.0, 1.0))
	var modifier_intro := Label.new()
	modifier_intro.text = "Modifier gelten für alle Drafts. Blind pick verdeckt Angebot und Auswahl online vor anderen menschlichen Spielern; lokal gegen Bots bleibt er ohne Wirkung. Random pick zieht automatisch eine zufällige Karte. Gamble legt die Karten verdeckt aus: aufdecken von links, wer weiterdreht, verkohlt die offene Karte."
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

	gamble_check = CheckButton.new()
	gamble_check.text = "Gamble"
	gamble_check.tooltip_text = "Die Karten liegen verdeckt, die Rückseite zeigt die Farbe der Seltenheit. Von links nach rechts deckt man einzeln auf: Entweder die offene Karte nehmen oder die nächste umdrehen, dann verkohlt die offene und ist weg. Die letzte Karte muss man nehmen. Mit Random pick ohne Wirkung."
	gamble_check.button_pressed = Global.gamble_enabled
	gamble_check.toggled.connect(_on_gamble_toggled)
	modifier_grid.add_child(gamble_check)

	var gamble_hint := Label.new()
	gamble_hint.text = "Verdeckt aufdecken: nehmen oder weiterdrehen, die vorherige Karte verkohlt."
	gamble_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gamble_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1.0))
	gamble_hint.add_theme_font_size_override("font_size", 12)
	gamble_hint.autowrap_mode = 2
	modifier_grid.add_child(gamble_hint)

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
	intro.text = "Gespeicherte Presets für Modus, Spielerzahl, Punkte, Draft inkl. Modifier, Kartenpools, Sperren, Map sowie HP und Schaden. Die aktuellen Regeln werden automatisch als \"Last\" gespeichert und beim nächsten Start geladen. Nur der Host kann Loadouts laden, speichern oder löschen."
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

	var reset_row := HBoxContainer.new()
	reset_row.add_theme_constant_override("separation", 12)
	body.add_child(reset_row)

	loadout_reset_btn = Button.new()
	loadout_reset_btn.text = "AUF STANDARD ZURÜCKSETZEN"
	loadout_reset_btn.tooltip_text = "Setzt alle Regeln auf die Standardwerte zurück. Das automatische \"Last\"-Loadout wird dabei überschrieben."
	loadout_reset_btn.pressed.connect(_on_loadout_reset_pressed)
	reset_row.add_child(loadout_reset_btn)

	_refresh_loadout_controls(Global.LOBBY_LAST_LOADOUT)

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
	var selected := _selected_loadout_name()
	var has_selection := not selected.is_empty()
	var is_last := selected == Global.LOBBY_LAST_LOADOUT
	if loadout_option != null:
		loadout_option.disabled = not is_host
	if loadout_name_edit != null:
		loadout_name_edit.editable = is_host
	if loadout_load_btn != null:
		loadout_load_btn.disabled = not is_host or not has_selection
	if loadout_save_btn != null:
		loadout_save_btn.disabled = not is_host
	if loadout_delete_btn != null:
		loadout_delete_btn.disabled = not is_host or not has_selection or is_last
		loadout_delete_btn.tooltip_text = (
			"Das automatisch gespeicherte Loadout \"Last\" kann nicht gelöscht werden."
			if is_last else "Ausgewähltes Loadout dauerhaft entfernen."
		)
	if loadout_reset_btn != null:
		loadout_reset_btn.disabled = not is_host

func _on_loadout_selected(_index: int) -> void:
	if loadout_refreshing:
		return
	_refresh_loadout_description()
	_refresh_loadout_enabled()

func _on_lobby_loadouts_changed() -> void:
	_refresh_loadout_controls()

# "Last" wurde neu geschrieben: nur die Vorschau aktualisieren, damit ein
# offenes Preset-Dropdown nicht durch einen Listen-Rebuild zurückspringt.
func _on_last_loadout_saved() -> void:
	if _selected_loadout_name() == Global.LOBBY_LAST_LOADOUT:
		_refresh_loadout_description()

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

func _on_loadout_reset_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.apply_default_lobby_settings()
	_sync_from_global()
	_refresh_loadout_controls()
	_set_loadout_status("Alle Regeln auf Standard zurückgesetzt.")
	SoundManager.play_sound("confirm")

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
	# Sofort als "Last" übernehmen, damit ein Neustart das geladene Preset lädt.
	if Global.lobby_autosave_enabled:
		Global.save_last_lobby_settings()
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

# --- Modifier-Tab ---

func _build_modifier_tab() -> void:
	_clear_children(modifier_tab)
	modifier_checks.clear()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modifier_tab.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	_add_section_title(body, "RUNDEN-MODIFIER", Color(1.0, 0.55, 0.9, 1.0))
	var intro := Label.new()
	intro.text = "Lege fest, wie oft und mit welchen Modifiern eine Runde startet. Die Rate wirkt auf die bisherige Verteilung: 0 % deaktiviert Modifier, 100 % entspricht dem Standard, 200 % garantiert einen zusätzlichen Modifier."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var rate_row := HBoxContainer.new()
	rate_row.add_theme_constant_override("separation", 12)
	body.add_child(rate_row)

	var rate_label := Label.new()
	rate_label.text = "Modifier-Rate:"
	rate_label.add_theme_font_size_override("font_size", 16)
	rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_row.add_child(rate_label)

	modifier_rate_spin = SpinBox.new()
	modifier_rate_spin.custom_minimum_size = Vector2(150, 0)
	modifier_rate_spin.min_value = LevelModifierDefsClass.RATE_MIN_PERCENT
	modifier_rate_spin.max_value = LevelModifierDefsClass.RATE_MAX_PERCENT
	modifier_rate_spin.step = 10
	modifier_rate_spin.suffix = " %"
	modifier_rate_spin.value = Global.level_modifier_rate_percent
	modifier_rate_spin.value_changed.connect(_on_modifier_rate_changed)
	rate_row.add_child(modifier_rate_spin)

	var rate_hint := Label.new()
	rate_hint.text = "0 % = aus  |  100 % = Standard  |  200 % = garantiert +1"
	rate_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	rate_hint.add_theme_font_size_override("font_size", 12)
	rate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rate_row.add_child(rate_hint)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)

	modifier_count_label = Label.new()
	modifier_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modifier_count_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	modifier_count_label.add_theme_font_size_override("font_size", 14)
	modifier_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(modifier_count_label)

	modifier_all_btn = Button.new()
	modifier_all_btn.text = "ALLE"
	modifier_all_btn.tooltip_text = "Alle verfügbaren Runden-Modifier aktivieren."
	modifier_all_btn.pressed.connect(_on_all_modifiers_pressed)
	header.add_child(modifier_all_btn)

	modifier_none_btn = Button.new()
	modifier_none_btn.text = "KEINE"
	modifier_none_btn.tooltip_text = "Alle Runden-Modifier deaktivieren. Die Rate bleibt unverändert."
	modifier_none_btn.pressed.connect(_on_none_modifiers_pressed)
	header.add_child(modifier_none_btn)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	body.add_child(grid)

	for id in LevelModifierDefsClass.modifier_ids():
		var definition: Dictionary = LevelModifierDefsClass.MODIFIERS[id]
		var check := CheckButton.new()
		check.text = "%s  %s" % [
			str(definition.get("icon", "?")),
			str(definition.get("title", id)),
		]
		check.tooltip_text = str(definition.get("description", ""))
		check.button_pressed = Global.is_level_modifier_enabled(id)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.add_theme_font_size_override("font_size", 14)
		check.toggled.connect(_on_modifier_toggled.bind(id))
		grid.add_child(check)
		modifier_checks[id] = check

	var note := Label.new()
	note.text = "Nicht kombinierbar: Höhle + Der Boden ist Lava sowie Mondgravitation + Schwerewelt."
	note.add_theme_color_override("font_color", Color(0.6, 0.55, 0.5, 1.0))
	note.add_theme_font_size_override("font_size", 12)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)

	_refresh_modifier_controls()

func _refresh_modifier_controls() -> void:
	if modifier_rate_spin == null:
		return
	var is_host := Global.is_local_host()
	modifier_rate_spin.set_value_no_signal(Global.level_modifier_rate_percent)
	modifier_rate_spin.editable = is_host
	for id in modifier_checks.keys():
		var check := modifier_checks[id] as CheckButton
		if check != null:
			check.set_pressed_no_signal(Global.is_level_modifier_enabled(str(id)))
			check.disabled = not is_host
	if modifier_all_btn != null:
		modifier_all_btn.disabled = not is_host
	if modifier_none_btn != null:
		modifier_none_btn.disabled = not is_host
	if modifier_count_label != null:
		var active_count := Global.get_enabled_level_modifier_count()
		var total_count := LevelModifierDefsClass.MODIFIERS.size()
		if Global.level_modifier_rate_percent <= 0:
			modifier_count_label.text = "Modifier-Rate 0 % - Runden-Modifier sind deaktiviert."
		else:
			modifier_count_label.text = "%d von %d Modifiern aktiv  |  Rate %d %%" % [
				active_count,
				total_count,
				Global.level_modifier_rate_percent,
			]

func _on_modifier_rate_changed(value: float) -> void:
	if not Global.is_local_host():
		_refresh_modifier_controls()
		return
	Global.set_level_modifier_rate_percent(int(round(value)))
	SoundManager.play_sound("click")
	_refresh_modifier_controls()
	_update_status()

func _on_modifier_toggled(pressed: bool, id: String) -> void:
	if not Global.is_local_host():
		_refresh_modifier_controls()
		return
	Global.set_level_modifier_enabled(id, pressed)
	SoundManager.play_sound("click")
	_refresh_modifier_controls()
	_update_status()

func _on_all_modifiers_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_enabled_level_modifiers(LevelModifierDefsClass.modifier_ids())
	SoundManager.play_sound("click")
	_refresh_modifier_controls()
	_update_status()

func _on_none_modifiers_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_enabled_level_modifiers([])
	SoundManager.play_sound("click")
	_refresh_modifier_controls()
	_update_status()

# --- Levels-Tab ---

func _build_levels_tab() -> void:
	if levels_tab == null:
		levels_tab = VBoxContainer.new()
		levels_tab.name = "Levels"
		levels_tab.add_theme_constant_override("separation", 8)
		tabs.add_child(levels_tab)
		tabs.set_tab_title(tabs.get_tab_idx_from_control(levels_tab), "Levels")
	_clear_children(levels_tab)
	level_cards.clear()

	if level_preview_renderer == null:
		level_preview_renderer = LevelPreviewRendererScript.new()
		level_preview_renderer.name = "LevelPreviewRenderer"
		add_child(level_preview_renderer)
		level_preview_renderer.preview_ready.connect(_on_level_preview_ready)

	_level_card_on = _make_status_style(Color(0.1, 0.13, 0.17, 1.0), Color(0.3, 0.9, 0.55, 0.9))
	_level_card_off = _make_status_style(Color(0.08, 0.08, 0.1, 1.0), Color(0.35, 0.35, 0.4, 0.6))

	level_scroll = ScrollContainer.new()
	level_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	level_scroll.resized.connect(_update_level_grid_columns)
	levels_tab.add_child(level_scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	level_scroll.add_child(body)

	_add_section_title(body, "LEVELS", Color(0.4, 0.95, 0.6, 1.0))
	var intro := Label.new()
	intro.text = "Abgeschaltete Levels kommen bei Map „Zufällig“ nicht mehr dran. Ein Klick auf ein Vorschaubild zeigt das Level groß. Ohne aktives Level lässt sich das Match nicht starten."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)

	level_count_label = Label.new()
	level_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_count_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	level_count_label.add_theme_font_size_override("font_size", 14)
	level_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(level_count_label)

	level_all_btn = Button.new()
	level_all_btn.text = "ALLE AN"
	level_all_btn.tooltip_text = "Alle Levels wieder aktivieren."
	level_all_btn.pressed.connect(_on_all_levels_pressed)
	header.add_child(level_all_btn)

	level_none_btn = Button.new()
	level_none_btn.text = "ALLE AUS"
	level_none_btn.tooltip_text = "Alle Levels abschalten, um danach gezielt einzelne einzuschalten."
	level_none_btn.pressed.connect(_on_no_levels_pressed)
	header.add_child(level_none_btn)

	level_grid = GridContainer.new()
	level_grid.columns = 4
	level_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_grid.add_theme_constant_override("h_separation", 12)
	level_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(level_grid)

	# Die Liste kommt direkt aus MAP_PLAYABLE: Neue Maps erscheinen hier ohne
	# weitere Pflege, das Bild rendert der LevelGenerator.
	for map_id in Global.MAP_PLAYABLE:
		level_grid.add_child(_create_level_card(map_id))

	_build_level_viewer()
	_refresh_level_controls()

func _create_level_card(map_id: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = Global.get_map_description(map_id)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var thumb := Button.new()
	thumb.custom_minimum_size = LEVEL_THUMB_SIZE
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	thumb.tooltip_text = "%s — Klicken für die Großansicht." % Global.get_map_name(map_id)
	thumb.focus_mode = Control.FOCUS_NONE
	thumb.pressed.connect(_open_level_viewer.bind(map_id))
	vbox.add_child(thumb)

	var texture_rect := TextureRect.new()
	texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect.offset_left = 4
	texture_rect.offset_top = 4
	texture_rect.offset_right = -4
	texture_rect.offset_bottom = -4
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = LevelPreviewRendererScript.get_cached(map_id)
	thumb.add_child(texture_rect)

	var placeholder := Label.new()
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.text = "Vorschau wird erstellt …"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 1.0))
	placeholder.add_theme_font_size_override("font_size", 12)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placeholder.visible = texture_rect.texture == null
	thumb.add_child(placeholder)

	var off_badge := Label.new()
	off_badge.text = "AUS"
	off_badge.position = Vector2(10, 8)
	off_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 1.0))
	off_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	off_badge.add_theme_constant_override("outline_size", 4)
	off_badge.add_theme_font_size_override("font_size", 16)
	off_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.add_child(off_badge)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var name_label := Label.new()
	name_label.text = Global.get_map_name(map_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.clip_text = true
	row.add_child(name_label)

	var check := CheckButton.new()
	check.tooltip_text = "Level an- oder abschalten."
	check.button_pressed = Global.is_map_enabled(map_id)
	check.toggled.connect(_on_level_toggled.bind(map_id))
	row.add_child(check)

	level_cards[map_id] = {
		"card": card,
		"texture": texture_rect,
		"placeholder": placeholder,
		"badge": off_badge,
		"name": name_label,
		"check": check,
	}
	return card

func _update_level_grid_columns() -> void:
	if level_grid == null or level_scroll == null:
		return
	var card_width := LEVEL_THUMB_SIZE.x + 24.0 + float(level_grid.get_theme_constant("h_separation"))
	level_grid.columns = clampi(int(floor((level_scroll.size.x - 12.0) / card_width)), 1, 6)

func _refresh_level_controls() -> void:
	if level_count_label == null:
		return
	var is_host := Global.is_local_host()
	for map_id in level_cards.keys():
		var nodes: Dictionary = level_cards[map_id]
		var enabled := Global.is_map_enabled(str(map_id))
		var check := nodes["check"] as CheckButton
		check.set_pressed_no_signal(enabled)
		check.disabled = not is_host
		var card := nodes["card"] as PanelContainer
		card.add_theme_stylebox_override("panel", _level_card_on if enabled else _level_card_off)
		var texture_rect := nodes["texture"] as TextureRect
		texture_rect.modulate = Color(1, 1, 1, 1) if enabled else Color(0.55, 0.55, 0.6, 0.45)
		var badge := nodes["badge"] as Label
		badge.visible = not enabled
		(nodes["name"] as Label).add_theme_color_override(
			"font_color", Color(0.92, 0.95, 1.0, 1.0) if enabled else Color(0.5, 0.52, 0.58, 1.0)
		)
	if level_all_btn != null:
		level_all_btn.disabled = not is_host or Global.disabled_map_ids.is_empty()
	if level_none_btn != null:
		level_none_btn.disabled = not is_host or not Global.has_enabled_maps()
	var total := Global.MAP_PLAYABLE.size()
	var active := Global.get_enabled_map_ids().size()
	var text := "%d von %d Levels aktiv" % [active, total]
	if active == 0:
		text = "Kein Level aktiv – das Match kann so nicht starten."
	if Global.selected_map_id != Global.MAP_RANDOM:
		text += "  |  Feste Map: %s (Regeln-Reiter)" % Global.get_map_name(Global.selected_map_id)
	if not is_host:
		text += "  |  Nur der Host kann Levels schalten."
	level_count_label.text = text
	_refresh_level_viewer()

func _request_level_previews() -> void:
	if level_preview_renderer == null:
		return
	var missing: Array[String] = []
	for map_id in Global.MAP_PLAYABLE:
		if not LevelPreviewRendererScript.has_cached(map_id):
			missing.append(map_id)
	if not missing.is_empty():
		level_preview_renderer.request(missing)

func _on_level_preview_ready(map_id: String, texture: Texture2D) -> void:
	if level_cards.has(map_id):
		var nodes: Dictionary = level_cards[map_id]
		var texture_rect := nodes["texture"] as TextureRect
		texture_rect.texture = texture
		var placeholder := nodes["placeholder"] as Label
		placeholder.visible = false
	if map_id == _level_viewer_map:
		_refresh_level_viewer()

func _on_level_toggled(pressed: bool, map_id: String) -> void:
	if not Global.is_local_host():
		_refresh_level_controls()
		return
	Global.set_map_enabled(map_id, pressed)
	SoundManager.play_sound("click")
	_refresh_level_controls()
	_update_status()

func _on_all_levels_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_disabled_maps([])
	SoundManager.play_sound("click")
	_refresh_level_controls()
	_update_status()

func _on_no_levels_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_disabled_maps(Global.MAP_PLAYABLE)
	SoundManager.play_sound("click")
	_refresh_level_controls()
	_update_status()

func _on_map_pool_changed() -> void:
	_refresh_level_controls()
	_refresh_map_controls()
	_update_status()

# --- Powerups-Tab ---

func _build_powerups_tab() -> void:
	if powerups_tab == null:
		powerups_tab = VBoxContainer.new()
		powerups_tab.name = "Powerups"
		powerups_tab.add_theme_constant_override("separation", 8)
		tabs.add_child(powerups_tab)
		tabs.set_tab_title(tabs.get_tab_idx_from_control(powerups_tab), "Powerups")
	_clear_children(powerups_tab)
	powerup_cards.clear()

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	powerups_tab.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	_add_section_title(body, "POWERUPS", Color(1.0, 0.8, 0.3, 1.0))
	var intro := Label.new()
	intro.text = "Powerups liegen zufällig in der Arena, fallen aus Kisten und kommen beim Modifier „Powerup-Regen“. Abgeschaltete Powerups erscheinen nicht mehr. Sind alle aus, gibt es keine Powerups, keinen Powerup-Regen und keine Powerup-Karten im Draft."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)

	powerup_count_label = Label.new()
	powerup_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	powerup_count_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 1.0))
	powerup_count_label.add_theme_font_size_override("font_size", 14)
	powerup_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	powerup_count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(powerup_count_label)

	powerup_all_btn = Button.new()
	powerup_all_btn.text = "ALLE AN"
	powerup_all_btn.tooltip_text = "Alle Powerups wieder aktivieren."
	powerup_all_btn.pressed.connect(_on_all_powerups_pressed)
	header.add_child(powerup_all_btn)

	powerup_none_btn = Button.new()
	powerup_none_btn.text = "ALLE AUS"
	powerup_none_btn.tooltip_text = "Alle Powerups abschalten: Runden ohne Powerups."
	powerup_none_btn.pressed.connect(_on_no_powerups_pressed)
	header.add_child(powerup_none_btn)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)

	for kind in Global.POWERUP_KINDS:
		grid.add_child(_create_powerup_card(kind))

	_refresh_powerup_controls()

func _create_powerup_card(kind: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.tooltip_text = Global.get_powerup_description(kind)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Vorschau: dasselbe Powerup wie in der Arena, nur ohne Kollision.
	var preview := Control.new()
	preview.custom_minimum_size = POWERUP_PREVIEW_SIZE
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(preview)

	var powerup := PowerupScene.instantiate()
	powerup.set("kind", kind)
	powerup.set("is_replica", true)
	powerup.position = Vector2(POWERUP_PREVIEW_SIZE.x * 0.5, POWERUP_PREVIEW_SIZE.y * 0.5 - 10.0)
	preview.add_child(powerup)
	# Die Vorschau bleibt mittig, auch wenn die Karte breiter wird.
	preview.resized.connect(func() -> void:
		if is_instance_valid(powerup):
			powerup.position = Vector2(preview.size.x * 0.5, preview.size.y * 0.5 - 10.0)
	)

	var off_badge := Label.new()
	off_badge.text = "AUS"
	off_badge.position = Vector2(6, 4)
	off_badge.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4, 1.0))
	off_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	off_badge.add_theme_constant_override("outline_size", 4)
	off_badge.add_theme_font_size_override("font_size", 16)
	off_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(off_badge)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	vbox.add_child(row)

	var name_label := Label.new()
	name_label.text = Global.get_powerup_name(kind)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.clip_text = true
	row.add_child(name_label)

	var check := CheckButton.new()
	check.tooltip_text = "Powerup an- oder abschalten."
	check.button_pressed = Global.is_powerup_enabled(kind)
	check.toggled.connect(_on_powerup_toggled.bind(kind))
	row.add_child(check)

	var desc := Label.new()
	desc.text = Global.get_powerup_description(kind)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(POWERUP_PREVIEW_SIZE.x, 0)
	desc.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc)

	powerup_cards[kind] = {
		"card": card,
		"preview": powerup,
		"badge": off_badge,
		"name": name_label,
		"desc": desc,
		"check": check,
	}
	return card

func _refresh_powerup_controls() -> void:
	if powerup_count_label == null:
		return
	var is_host := Global.is_local_host()
	for kind in powerup_cards.keys():
		var nodes: Dictionary = powerup_cards[kind]
		var enabled := Global.is_powerup_enabled(str(kind))
		# Auto-Angriff ohne Nahkampfwaffe erscheint trotz Schalter nicht.
		var melee_blocked: bool = str(kind) == "auto_attack" and not Global.melee_enabled
		var active := enabled and not melee_blocked
		var check := nodes["check"] as CheckButton
		check.set_pressed_no_signal(enabled)
		check.disabled = not is_host
		var card := nodes["card"] as PanelContainer
		card.add_theme_stylebox_override("panel", _level_card_on if active else _level_card_off)
		var preview := nodes["preview"] as Node2D
		if is_instance_valid(preview):
			preview.modulate = Color(1, 1, 1, 1) if active else Color(0.55, 0.55, 0.6, 0.45)
		var badge := nodes["badge"] as Label
		badge.visible = not active
		badge.text = "NAHKAMPF AUS" if enabled and melee_blocked else "AUS"
		(nodes["name"] as Label).add_theme_color_override(
			"font_color", Color(0.92, 0.95, 1.0, 1.0) if active else Color(0.5, 0.52, 0.58, 1.0)
		)
		(nodes["desc"] as Label).add_theme_color_override(
			"font_color", Color(0.66, 0.7, 0.8, 1.0) if active else Color(0.45, 0.47, 0.52, 1.0)
		)
	if powerup_all_btn != null:
		powerup_all_btn.disabled = not is_host or Global.disabled_powerup_kinds.is_empty()
	if powerup_none_btn != null:
		powerup_none_btn.disabled = not is_host \
			or Global.disabled_powerup_kinds.size() >= Global.POWERUP_KINDS.size()
	var total := Global.POWERUP_KINDS.size()
	var active_count := Global.get_active_powerup_kinds().size()
	var text := "%d von %d Powerups aktiv" % [active_count, total]
	if active_count == 0:
		text = "Keine Powerups aktiv – Runden laufen ohne Powerups."
	if not Global.melee_enabled and Global.is_powerup_enabled("auto_attack"):
		text += "  |  Auto-Angriff ruht, solange Nahkampf aus ist."
	if not is_host:
		text += "  |  Nur der Host kann Powerups schalten."
	powerup_count_label.text = text

func _on_powerup_toggled(pressed: bool, kind: String) -> void:
	if not Global.is_local_host():
		_refresh_powerup_controls()
		return
	Global.set_powerup_enabled(kind, pressed)
	SoundManager.play_sound("click")
	_refresh_powerup_controls()

func _on_all_powerups_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_disabled_powerups([])
	SoundManager.play_sound("click")
	_refresh_powerup_controls()

func _on_no_powerups_pressed() -> void:
	if not Global.is_local_host():
		return
	Global.set_disabled_powerups(Global.POWERUP_KINDS)
	SoundManager.play_sound("click")
	_refresh_powerup_controls()

func _on_powerup_pool_changed() -> void:
	_refresh_powerup_controls()
	# Powerup-Karten hängen davon ab, ob überhaupt Powerups aktiv sind.
	_refresh_ban_states()

# Großansicht: liegt als eigenes Overlay über dem gesamten Lobby-Panel.
func _build_level_viewer() -> void:
	if level_viewer != null:
		return
	level_viewer = Control.new()
	level_viewer.name = "LevelViewer"
	level_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_viewer.visible = false
	level_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	level_viewer.gui_input.connect(_on_level_viewer_gui_input)
	add_child(level_viewer)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_level_viewer_backdrop_input)
	level_viewer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_viewer.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _make_status_style(Color(0.07, 0.08, 0.11, 0.98), Color(0.4, 0.95, 0.6, 0.9)))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var prev_btn := Button.new()
	prev_btn.text = "◀"
	prev_btn.tooltip_text = "Vorheriges Level (Pfeil links)"
	prev_btn.pressed.connect(_step_level_viewer.bind(-1))
	header.add_child(prev_btn)

	level_viewer_title = Label.new()
	level_viewer_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_viewer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_viewer_title.add_theme_font_size_override("font_size", 22)
	level_viewer_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6, 1.0))
	header.add_child(level_viewer_title)

	var next_btn := Button.new()
	next_btn.text = "▶"
	next_btn.tooltip_text = "Nächstes Level (Pfeil rechts)"
	next_btn.pressed.connect(_step_level_viewer.bind(1))
	header.add_child(next_btn)

	level_viewer_close_btn = Button.new()
	level_viewer_close_btn.text = "✕"
	level_viewer_close_btn.tooltip_text = "Schließen (Esc)"
	level_viewer_close_btn.pressed.connect(_close_level_viewer)
	header.add_child(level_viewer_close_btn)

	var image_frame := Control.new()
	image_frame.name = "ImageFrame"
	vbox.add_child(image_frame)
	level_viewer_texture = TextureRect.new()
	level_viewer_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_viewer_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	level_viewer_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	level_viewer_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	level_viewer_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_frame.add_child(level_viewer_texture)
	level_viewer_placeholder = Label.new()
	level_viewer_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_viewer_placeholder.text = "Vorschau wird erstellt …"
	level_viewer_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_viewer_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_viewer_placeholder.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7, 1.0))
	level_viewer_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_frame.add_child(level_viewer_placeholder)

	level_viewer_desc = Label.new()
	level_viewer_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_viewer_desc.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85, 1.0))
	level_viewer_desc.add_theme_font_size_override("font_size", 14)
	vbox.add_child(level_viewer_desc)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)

	level_viewer_check = CheckButton.new()
	level_viewer_check.text = "Level aktiv"
	level_viewer_check.add_theme_font_size_override("font_size", 15)
	level_viewer_check.toggled.connect(_on_level_viewer_toggled)
	footer.add_child(level_viewer_check)

	level_viewer_status = Label.new()
	level_viewer_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_viewer_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_viewer_status.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	level_viewer_status.add_theme_font_size_override("font_size", 12)
	footer.add_child(level_viewer_status)

func _open_level_viewer(map_id: String) -> void:
	if level_viewer == null or not Global.MAP_PLAYABLE.has(map_id):
		return
	_level_viewer_map = map_id
	# Bildgröße an das Fenster anpassen (16:9, Platz für Kopf- und Fußzeile).
	var screen := get_viewport().get_visible_rect().size
	var width := minf(screen.x * 0.82, (screen.y - 220.0) * 16.0 / 9.0)
	width = maxf(width, 320.0)
	var frame := level_viewer_texture.get_parent() as Control
	frame.custom_minimum_size = Vector2(width, width * 9.0 / 16.0)
	level_viewer_desc.custom_minimum_size = Vector2(width, 0)
	level_viewer.visible = true
	level_viewer_close_btn.grab_focus()
	if level_preview_renderer != null and not LevelPreviewRendererScript.has_cached(map_id):
		level_preview_renderer.prioritize(map_id)
	SoundManager.play_sound("click")
	_refresh_level_viewer()

func _close_level_viewer() -> void:
	if level_viewer == null:
		return
	level_viewer.visible = false
	_level_viewer_map = ""

func _step_level_viewer(direction: int) -> void:
	var ids := Global.MAP_PLAYABLE
	if _level_viewer_map.is_empty() or ids.is_empty():
		return
	var index := ids.find(_level_viewer_map)
	_open_level_viewer(ids[posmod(index + direction, ids.size())])

func _refresh_level_viewer() -> void:
	if level_viewer == null or not level_viewer.visible or _level_viewer_map.is_empty():
		return
	var map_id := _level_viewer_map
	var index := Global.MAP_PLAYABLE.find(map_id)
	level_viewer_title.text = "%s  (%d/%d)" % [Global.get_map_name(map_id), index + 1, Global.MAP_PLAYABLE.size()]
	level_viewer_desc.text = Global.get_map_description(map_id)
	var texture := LevelPreviewRendererScript.get_cached(map_id)
	level_viewer_texture.texture = texture
	level_viewer_placeholder.visible = texture == null
	var enabled := Global.is_map_enabled(map_id)
	level_viewer_texture.modulate = Color(1, 1, 1, 1) if enabled else Color(0.6, 0.6, 0.65, 0.6)
	level_viewer_check.set_pressed_no_signal(enabled)
	level_viewer_check.disabled = not Global.is_local_host()
	if not Global.is_local_host():
		level_viewer_status.text = "Nur der Host kann Levels schalten."
	elif not Global.has_enabled_maps():
		level_viewer_status.text = "Kein Level aktiv – das Match kann so nicht starten."
	else:
		level_viewer_status.text = "Beispiel-Aufbau: Zusatzplattformen und Objekte wechseln jede Runde."

func _on_level_viewer_toggled(pressed: bool) -> void:
	if _level_viewer_map.is_empty():
		return
	_on_level_toggled(pressed, _level_viewer_map)

func _on_level_viewer_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_level_viewer()
		get_viewport().set_input_as_handled()

# Tasten erreichen das Overlay über den fokussierten Schließen-Button.
func _on_level_viewer_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_level_viewer()
		level_viewer.accept_event()
	elif event.is_action_pressed("ui_left"):
		_step_level_viewer(-1)
		level_viewer.accept_event()
	elif event.is_action_pressed("ui_right"):
		_step_level_viewer(1)
		level_viewer.accept_event()

# --- Karten-Tab ---

func _build_cards_tab() -> void:
	_clear_children(cards_tab)
	rarity_spins.clear()
	ban_checks.clear()
	ban_icons.clear()
	ban_panels.clear()
	ban_meta_labels.clear()
	pool_checks.clear()

	# Ganzer Tab-Inhalt in einem ScrollContainer, damit Pools und Seltenheiten
	# beim Scrollen mitwandern statt dauerhaft Platz zu belegen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards_tab.add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)

	_add_section_title(body, "KARTENPOOLS", Color(0.45, 0.9, 1.0, 1.0))
	var pool_intro := Label.new()
	pool_intro.text = "Nur Karten aus aktiven Pools erscheinen im Draft. Mindestens ein Pool bleibt aktiv; Ausbaukarten erben den Pool ihrer Grundkarte. Karten eines abgeschalteten Pools sind unten gesperrt und lassen sich einzeln wieder freigeben."
	pool_intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	pool_intro.add_theme_font_size_override("font_size", 12)
	pool_intro.autowrap_mode = 2
	body.add_child(pool_intro)

	var pool_header := HBoxContainer.new()
	pool_header.add_theme_constant_override("separation", 12)
	body.add_child(pool_header)

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
	# Vier Pools in einer Reihe.
	pool_grid.columns = 4
	pool_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_grid.add_theme_constant_override("h_separation", 12)
	pool_grid.add_theme_constant_override("v_separation", 2)
	body.add_child(pool_grid)

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

	var chart_intro := Label.new()
	chart_intro.text = "Verteilung aller aktuell verfügbaren Karten (aktive Pools und Freigaben, ohne Sperren): Haupt-Tags, Sub-Tags je Haupt-Tag und Seltenheiten."
	chart_intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	chart_intro.add_theme_font_size_override("font_size", 12)
	chart_intro.autowrap_mode = 2
	body.add_child(chart_intro)
	pool_charts_box = VBoxContainer.new()
	pool_charts_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pool_charts_box)

	body.add_child(HSeparator.new())
	_add_section_title(body, "SELTENHEITEN", Color(1.0, 0.72, 0.3, 1.0))
	var intro := Label.new()
	intro.text = "Prozentsatz pro Seltenheit im Kartenangebot. Die Summe wird automatisch normalisiert; alle 0 % bedeutet Gleichverteilung."
	intro.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	intro.add_theme_font_size_override("font_size", 12)
	intro.autowrap_mode = 2
	body.add_child(intro)

	var rarity_grid := GridContainer.new()
	rarity_grid.columns = 5
	rarity_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_grid.add_theme_constant_override("h_separation", 12)
	rarity_grid.add_theme_constant_override("v_separation", 4)
	body.add_child(rarity_grid)

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
	body.add_child(rarity_sum_label)

	var legend := Label.new()
	legend.text = "Kartenrahmen: außen = Seltenheit, innen = Effektfarbe der Karte."
	legend.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	legend.add_theme_font_size_override("font_size", 12)
	body.add_child(legend)

	body.add_child(HSeparator.new())

	var ban_header := HBoxContainer.new()
	ban_header.add_theme_constant_override("separation", 12)
	body.add_child(ban_header)

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
	unban_btn.tooltip_text = "Hebt alle Einzelsperren auf. Karten aus abgeschalteten Pools bleiben gesperrt."
	unban_btn.pressed.connect(_on_unban_all)
	ban_header.add_child(unban_btn)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 10)
	body.add_child(filter_row)

	ban_filter_btn = MenuButton.new()
	ban_filter_btn.text = "Filter ▾"
	ban_filter_btn.flat = false
	ban_filter_btn.tooltip_text = "Kartenliste nach Haupt-Tags (Pools) und Sub-Tags filtern."
	filter_row.add_child(ban_filter_btn)
	_build_ban_filter_menu()

	ban_filter_label = Label.new()
	ban_filter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban_filter_label.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
	ban_filter_label.add_theme_font_size_override("font_size", 12)
	ban_filter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ban_filter_label.autowrap_mode = 2
	filter_row.add_child(ban_filter_label)

	var filter_reset := Button.new()
	filter_reset.text = "Filter zurücksetzen"
	filter_reset.pressed.connect(_on_ban_filter_reset)
	filter_row.add_child(filter_reset)

	ban_sections = VBoxContainer.new()
	ban_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ban_sections.add_theme_constant_override("separation", 4)
	body.add_child(ban_sections)

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
	ban_panels.clear()
	ban_meta_labels.clear()

	var grouped: Dictionary = {}
	var shown := 0
	for card in CardDatabase.all_cards:
		if not _card_matches_ban_filter(card):
			continue
		shown += 1
		if not grouped.has(card.rarity):
			grouped[card.rarity] = []
		grouped[card.rarity].append(card)

	for rarity in Global.RARITY_ORDER:
		if grouped.has(rarity):
			_add_ban_section(rarity, grouped[rarity])
			grouped.erase(rarity)
	for rarity in grouped.keys():
		_add_ban_section(str(rarity), grouped[rarity])
	_update_ban_filter_label(shown)
	if shown == 0:
		var empty := Label.new()
		empty.text = "Keine Karte passt zum Filter."
		empty.add_theme_color_override("font_color", Color(0.62, 0.66, 0.75, 1.0))
		empty.add_theme_font_size_override("font_size", 13)
		ban_sections.add_child(empty)
	_refresh_ban_states()

# --- Filter der Powerup-Kartenliste ---

func _build_ban_filter_menu() -> void:
	var popup := ban_filter_btn.get_popup()
	popup.clear()
	popup.hide_on_checkable_item_selection = false
	_ban_filter_item_tags.clear()
	var next_id := 0
	popup.add_separator("Haupt-Tags")
	for pool in Global.CARD_POOLS:
		popup.add_check_item(pool, next_id)
		popup.set_item_checked(popup.get_item_index(next_id), ban_filter_main.has(pool))
		popup.set_item_tooltip(popup.get_item_index(next_id), Global.CARD_POOL_DESCRIPTIONS.get(pool, ""))
		_ban_filter_item_tags[next_id] = ["main", pool]
		next_id += 1
	var groups: Array = Global.CARD_POOLS.duplicate()
	groups.append("Allgemein")
	for group in groups:
		var tags: Array = []
		if group == "Allgemein":
			tags.append_array(CardDatabase.SHARED_SUB_TAGS)
		else:
			tags.append_array(CardDatabase.SUB_TAG_GROUPS.get(group, []))
		popup.add_separator("Sub-Tags · %s" % group)
		for tag in tags:
			popup.add_check_item(str(tag), next_id)
			popup.set_item_checked(popup.get_item_index(next_id), ban_filter_sub.has(str(tag)))
			popup.set_item_tooltip(popup.get_item_index(next_id), CardDatabase.SUB_TAG_DESCRIPTIONS.get(str(tag), ""))
			_ban_filter_item_tags[next_id] = ["sub", str(tag)]
			next_id += 1
	if not popup.id_pressed.is_connected(_on_ban_filter_id_pressed):
		popup.id_pressed.connect(_on_ban_filter_id_pressed)

func _on_ban_filter_id_pressed(id: int) -> void:
	if not _ban_filter_item_tags.has(id):
		return
	var entry: Array = _ban_filter_item_tags[id]
	var kind := str(entry[0])
	var tag := str(entry[1])
	var target: Array[String] = ban_filter_main if kind == "main" else ban_filter_sub
	if target.has(tag):
		target.erase(tag)
	else:
		target.append(tag)
	var popup := ban_filter_btn.get_popup()
	popup.set_item_checked(popup.get_item_index(id), target.has(tag))
	SoundManager.play_sound("click")
	_build_ban_sections()
	_refresh_host_controls()

func _on_ban_filter_reset() -> void:
	if ban_filter_main.is_empty() and ban_filter_sub.is_empty():
		return
	ban_filter_main.clear()
	ban_filter_sub.clear()
	SoundManager.play_sound("click")
	_build_ban_filter_menu()
	_build_ban_sections()
	_refresh_host_controls()

func _card_matches_ban_filter(card: CardData) -> bool:
	if card == null:
		return false
	if not ban_filter_main.is_empty() and not ban_filter_main.has(card.pool):
		return false
	if not ban_filter_sub.is_empty():
		for tag in ban_filter_sub:
			if card.sub_tags.has(tag):
				return true
		return false
	return true

func _update_ban_filter_label(shown: int) -> void:
	if ban_filter_label == null:
		return
	var parts: Array[String] = []
	parts.append_array(ban_filter_main)
	parts.append_array(ban_filter_sub)
	if parts.is_empty():
		ban_filter_label.text = "Kein Filter · %d Karten" % shown
		ban_filter_btn.text = "Filter ▾"
	else:
		ban_filter_label.text = "%s · %d von %d Karten" % [", ".join(parts), shown, CardDatabase.all_cards.size()]
		ban_filter_btn.text = "Filter (%d) ▾" % parts.size()

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
	meta.text = _ban_meta_text(card)
	meta.add_theme_color_override("font_color", CardDatabase.get_rarity_color(card.rarity))
	meta.add_theme_font_size_override("font_size", 10)
	text_box.add_child(meta)
	ban_meta_labels[card.id] = meta

	if not card.sub_tags.is_empty():
		var tags := Label.new()
		tags.text = " · ".join(card.sub_tags)
		tags.add_theme_color_override("font_color", Color(0.55, 0.78, 0.95, 1.0))
		tags.add_theme_font_size_override("font_size", 9)
		tags.clip_text = true
		text_box.add_child(tags)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 9)
	if evolution_banner != null:
		text_box.add_child(evolution_banner)

	var unlock_label := CardMechanics.make_unlock_label(card, 9, false)
	if unlock_label != null:
		text_box.add_child(unlock_label)

	var description := Label.new()
	description.text = CardMechanics.format_description(card.description)
	description.add_theme_color_override("font_color", Color(0.68, 0.72, 0.80, 1.0))
	description.add_theme_font_size_override("font_size", 10)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(description)

	var cb := CheckButton.new()
	cb.button_pressed = Global.is_card_locked(card)
	cb.set_meta("card_id", card.id)
	cb.toggled.connect(_on_ban_toggled.bind(card.id, cb))
	row.add_child(cb)
	ban_checks[card.id] = cb
	ban_panels[card.id] = panel
	CardMechanics.apply_tooltip(panel, card, true)
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
	_refresh_ban_states()
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
	var unlocked_text := ""
	if not Global.pool_unlocked_card_ids.is_empty():
		unlocked_text = "  ·  %d einzeln freigegeben" % Global.pool_unlocked_card_ids.size()
	pool_count_label.text = "Aktiv: %s  ·  %d Karten (%d Grundkarten)%s" % [active, total, base_cards, unlocked_text]
	_update_pool_charts()

func _update_pool_charts() -> void:
	if pool_charts_box == null or not is_instance_valid(pool_charts_box):
		return
	_clear_children(pool_charts_box)
	var cards: Array = []
	for card in CardDatabase.all_cards:
		if Global.is_card_locked(card):
			continue
		cards.append(card)
	pool_charts_box.add_child(RadarChartScript.build_card_charts(cards, 4, Vector2(230, 200)))

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

func _on_pre_draft_picks_changed(value: float) -> void:
	if not Global.is_local_host():
		pre_draft_spin.set_value_no_signal(Global.pre_draft_picks)
		return
	Global.set_pre_draft_picks(int(value))
	_refresh_host_controls()
	_update_status()

func _on_pre_draft_random_toggled(pressed: bool) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_pre_draft_random(pressed)
	SoundManager.play_sound("click")
	_update_status()

func _on_melee_enabled_toggled(pressed: bool) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_melee_enabled(pressed)
	SoundManager.play_sound("click")
	_refresh_host_controls()
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

func _on_gamble_toggled(pressed: bool) -> void:
	if not Global.is_local_host():
		_sync_from_global()
		return
	Global.set_gamble_enabled(pressed)
	SoundManager.play_sound("click")
	_update_status()

# --- Karten sperren ---

# Schalter an = Karte gesperrt. Gesperrt ist eine Karte, wenn der Host sie
# gebannt hat oder ihr Pool aus ist; Letzteres hebt eine Einzelfreigabe auf.
func _on_ban_toggled(pressed: bool, card_id: String, checkbox: CheckButton) -> void:
	if not Global.is_local_host():
		_refresh_ban_states()
		return
	var card := CardDatabase.get_card(card_id)
	if card == null:
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
		if Global.pool_unlocked_card_ids.has(card_id):
			Global.set_card_pool_unlocked(card_id, false)
		# Noch über die Grundkarte freigegeben oder Pool aktiv: normal sperren.
		if CardDatabase.is_card_pool_enabled(card):
			Global.set_card_banned(card_id, true)
	else:
		if _is_card_melee_locked(card):
			checkbox.set_pressed_no_signal(true)
			SoundManager.play_sound("bounce", 0.2, 0.0)
			status_label.text = "Nahkampf ist aus — Nahkampf-Karten lassen sich erst nach dem Einschalten freigeben."
			return
		Global.set_card_banned(card_id, false)
		if not CardDatabase.is_card_pool_enabled(card):
			Global.set_card_pool_unlocked(card_id, true)
	SoundManager.play_sound("click")

func _is_card_melee_locked(card: CardData) -> bool:
	return card != null and card.pool == "Nahkampf" and not Global.melee_enabled

func _is_card_pool_locked(card: CardData) -> bool:
	return card != null and not CardDatabase.is_card_pool_enabled(card)

func _ban_meta_text(card: CardData) -> String:
	var text := "%s · %s" % [card.rarity, card.pool]
	if _is_card_melee_locked(card):
		text += " · Nahkampf aus"
	elif _is_card_pool_locked(card):
		text += " · Pool aus"
	elif CardDatabase.is_powerup_card_locked(card):
		text += " · Powerups aus"
	elif not Global.is_card_pool_enabled(card.pool):
		text += " · freigegeben"
	return text

func _on_banned_cards_changed() -> void:
	_refresh_ban_states()
	_update_pool_summary()
	_update_status()

func _refresh_ban_states() -> void:
	for card_id in ban_checks.keys():
		var card := CardDatabase.get_card(card_id)
		var cb := ban_checks[card_id] as CheckButton
		if cb != null:
			cb.set_pressed_no_signal(Global.is_card_locked(card))
			if _is_card_pool_locked(card):
				cb.tooltip_text = "Gesperrt, weil der Pool „%s“ aus ist. Ausschalten gibt die Karte einzeln frei." % card.pool
			else:
				cb.tooltip_text = "An = gesperrt."
		if ban_meta_labels.has(card_id):
			var meta := ban_meta_labels[card_id] as Label
			if meta != null:
				meta.text = _ban_meta_text(card)
		if ban_panels.has(card_id):
			var panel := ban_panels[card_id] as Control
			if panel != null:
				# Durch den Pool gesperrte Karten deutlich abdunkeln.
				panel.modulate = Color(1, 1, 1, 0.5) if _is_card_pool_locked(card) else Color.WHITE

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
	if gamble_check != null:
		gamble_check.set_pressed_no_signal(Global.gamble_enabled)
	if pre_draft_spin != null:
		pre_draft_spin.set_value_no_signal(Global.pre_draft_picks)
	if pre_draft_random_check != null:
		pre_draft_random_check.set_pressed_no_signal(Global.pre_draft_random)
	if melee_enabled_check != null:
		melee_enabled_check.set_pressed_no_signal(Global.melee_enabled)
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
		_refresh_online_code_row()
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
	var build_mismatch := not Global.is_local_host() and not NetworkManager.host_build_id.is_empty() \
		and NetworkManager.host_build_id != BuildInfo.get_build_id()
	if build_mismatch:
		status += "  ·  ACHTUNG: andere Version als der Host (Host %s, du %s)" % [NetworkManager.host_build_id, BuildInfo.get_build_id()]
	net_label.text = status
	net_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if build_mismatch else Color(0.45, 0.75, 1, 1))
	_refresh_online_code_row()
	if Global.is_spectator:
		footer_hint.text = "Zuschauer: Du siehst die Lobby und das Match, steuerst aber keinen Spieler-Slot."
	else:
		footer_hint.text = "Online: Der Host konfiguriert jeden Slot als Bot oder Mensch. Jeder Mensch wählt seinen Helden und bestätigt Bereit."

func _map_summary_text() -> String:
	var text := Global.get_map_name(Global.selected_map_id)
	if Global.selected_map_id == Global.MAP_RANDOM and not Global.disabled_map_ids.is_empty():
		text += " (%d/%d)" % [Global.get_enabled_map_ids().size(), Global.MAP_PLAYABLE.size()]
	return text

func _update_status() -> void:
	var total_cards := CardDatabase.all_cards.size()
	var available_total := Global.get_available_card_count()
	var available := Global.get_available_card_count_for_match()
	var pool_locked := 0
	for card in CardDatabase.all_cards:
		if not Global.is_card_banned(card.id) and not CardDatabase.is_card_pool_enabled(card):
			pool_locked += 1
	var pool_locked_text := ""
	if pool_locked > 0:
		pool_locked_text = " (+%d durch Pools)" % pool_locked
	ban_count.text = "%d von %d gesperrt%s · %d Grundkarten · min. %d je Held" % [
		Global.banned_card_ids.size(), total_cards, pool_locked_text, available_total, available,
	]
	var active_modifiers: Array[String] = []
	if Global.blind_pick_enabled and Global.network_mode:
		active_modifiers.append("Blind")
	if Global.random_pick_enabled:
		active_modifiers.append("Random")
	if Global.gamble_enabled:
		active_modifiers.append("Gamble")
	var modifier_summary := ""
	if not active_modifiers.is_empty():
		modifier_summary = "  ·  Modifier: %s" % ", ".join(active_modifiers)
	if Global.pre_draft_picks > 0:
		modifier_summary += "  ·  Pre-Draft %d%s" % [Global.pre_draft_picks, " (zufällig)" if Global.pre_draft_random else ""]
	modifier_summary += "  ·  Level-Mod %d %% (%d/%d)" % [
		Global.level_modifier_rate_percent,
		Global.get_enabled_level_modifier_count(),
		LevelModifierDefsClass.MODIFIERS.size(),
	]
	draft_summary.text = "Modus %s  ·  Spieler %d  ·  Draft %d/%d  ·  Ziel %d P (Überleben +%d, Kill +%d)  ·  HP %d %%  ·  DMG %d  ·  Map %s  ·  Pool min. %d/Held%s" % [
		Global.get_match_mode_name(), Global.player_count, Global.draft_picks, Global.cards_per_draft,
		Global.points_to_win, Global.survival_points, Global.kill_points,
		Global.base_hp_percent, int(Global.base_damage),
		_map_summary_text(), available, modifier_summary,
	]

	var enough_cards := available >= Global.cards_per_draft
	var has_levels := Global.has_enabled_maps()
	var is_host := Global.is_local_host()
	var all_ready := Global.all_players_ready()
	var missing: Array[int] = []
	if Global.network_mode:
		missing = NetworkManager.missing_human_slots()
	start_btn.disabled = not (enough_cards and has_levels and is_host and all_ready and missing.is_empty())

	if Global.is_spectator:
		status_label.text = "Zuschauer — du siehst das Match, steuerst aber keinen Spieler-Slot."
	elif not has_levels:
		status_label.text = "Kein Level aktiv — im Reiter „Levels“ mindestens eins einschalten."
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
	if not Global.has_enabled_maps():
		status_label.text = "Kein Level aktiv — im Reiter „Levels“ mindestens eins einschalten."
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

	Global.randomize_bot_melee_weapons()
	# Die neuen Bot-Waffen müssen vor dem Matchstart bei den Clients sein.
	if Global.network_mode:
		NetworkManager.sync_lobby()
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

# --- Epic-Online-Code (nur Host) ---

var online_code_row: HBoxContainer = null
var online_code_label: Label = null
var online_code_copy_btn: Button = null

func _current_online_code() -> String:
	if not Global.network_mode or not Global.is_local_host() or not NetworkManager.online_mode:
		return ""
	var epic := NetworkManager.get_node_or_null("EpicOnline")
	if epic == null:
		return ""
	return str(epic.online_code)

# Große Code-Anzeige mit Kopieren-Button direkt unter der Statuszeile.
func _refresh_online_code_row() -> void:
	var code := _current_online_code()
	if code.is_empty():
		if online_code_row != null:
			online_code_row.visible = false
		return
	if online_code_row == null:
		online_code_row = HBoxContainer.new()
		online_code_row.add_theme_constant_override("separation", 12)
		var caption := Label.new()
		caption.text = "Online-Code:"
		caption.add_theme_font_size_override("font_size", 20)
		caption.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 1))
		online_code_label = Label.new()
		online_code_label.add_theme_font_size_override("font_size", 30)
		online_code_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55, 1))
		online_code_copy_btn = Button.new()
		online_code_copy_btn.text = "Kopieren"
		online_code_copy_btn.pressed.connect(func():
			DisplayServer.clipboard_set(online_code_label.text)
			online_code_copy_btn.text = "Kopiert!"
			get_tree().create_timer(1.5).timeout.connect(func(): online_code_copy_btn.text = "Kopieren")
		)
		var hint := Label.new()
		hint.text = "an Mitspieler schicken, sie geben ihn bei \"Mit Code beitreten\" ein"
		hint.add_theme_font_size_override("font_size", 13)
		hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1))
		for node in [caption, online_code_label, online_code_copy_btn, hint]:
			node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			online_code_row.add_child(node)
		var parent := net_label.get_parent()
		parent.add_child(online_code_row)
		parent.move_child(online_code_row, net_label.get_index() + 1)
	online_code_label.text = code
	online_code_row.visible = true
