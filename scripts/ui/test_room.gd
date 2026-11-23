class_name TestRoom
extends CanvasLayer

## Testraum: Du (Slot 1) gegen einen Dummy (Slot 2) auf einer frei wählbaren
## Karte. Keine Runden, keine Punkte, keine Statistik; wer stirbt, steht nach
## kurzer Zeit wieder auf. Seitenleiste (F2) für Karte, Helden, Dummy-Verhalten
## und Messwerte, Kartenauswahl im Stil des Draft-Bildschirms für beide Seiten.
## main.gd ruft begin/end, on_round_started und on_player_died auf.

const PLAYER_SLOT: int = 1
const DUMMY_SLOT: int = 2
const RESPAWN_DELAY: float = 1.0
const DPS_WINDOW_MSEC: int = 5000
const MAX_SHOWN_CARDS: int = 70
const TOGGLE_KEY: Key = KEY_F2

const DUMMY_SHOOT := "shoot"
const DUMMY_AIM := "aim"
const DUMMY_BOT := "bot"
const DUMMY_MODES: Array = [
	[DUMMY_SHOOT, "Steht, zielt und schießt"],
	[DUMMY_AIM, "Steht und zielt (passiv)"],
	[DUMMY_BOT, "Bewegt sich und kämpft (Bot-KI)"],
]
const RARITIES: Array[String] = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]

var main: Node = null
var map_id: String = ""
var dummy_mode: String = DUMMY_SHOOT
var show_numbers: bool = true

var _backup: Dictionary = {}
var _autosave_backup: bool = true
var _respawn_token: Dictionary = {}   # Slot -> int, verwirft alte Respawns
var _last_pos: Dictionary = {}        # Slot -> Vector2 (Respawn am Todesort)
var _hits: Dictionary = {}            # Opfer-Slot -> Array von [msec, Schaden]
var _totals: Dictionary = {}          # Opfer-Slot -> Gesamtschaden
var _last_hit: Dictionary = {}        # Opfer-Slot -> letzter Treffer
var _numbers: Dictionary = {}         # Ziel-Instanz-ID -> letzte DamageNumber
var _blocked_input: bool = false

# Seitenleiste
var _panel: PanelContainer = null
var _body: VBoxContainer = null
var _toggle_btn: Button = null
var _map_option: OptionButton = null
var _map_ids: Array[String] = []
var _hero_options: Dictionary = {}    # Slot -> OptionButton
var _hero_ids: Array[String] = []
var _dummy_option: OptionButton = null
var _numbers_check: CheckBox = null
var _stats_label: Label = null
var _cards_label: Label = null

# Kartenauswahl
var _picker: Control = null
var _picker_slot: int = 0
var _picker_title: Label = null
var _picker_search: LineEdit = null
var _picker_rarity: OptionButton = null
var _picker_pool: OptionButton = null
var _picker_hero_only: CheckBox = null
var _picker_owned_flow: HFlowContainer = null
var _picker_grid: HFlowContainer = null
var _picker_info: Label = null
var _picker_dirty: bool = false
var _picker_paused_before: bool = false

func _init() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _ready() -> void:
	_build_panel()
	_build_picker()

# ---------------------------------------------------------------------------
# Ablauf
# ---------------------------------------------------------------------------

func begin(main_node: Node) -> void:
	main = main_node
	_backup = {
		"match_mode": Global.match_mode,
		"game_mode": Global.game_mode,
		"player_count": Global.player_count,
		"kinds": Global.player_kind.duplicate(),
		"heroes": Global.player_hero_ids.duplicate(),
		"weapons": Global.player_melee_weapons.duplicate(),
		"bot_test": Global.bot_test_mode,
	}
	# Nichts davon darf im Loadout "Last" landen.
	_autosave_backup = Global.lobby_autosave_enabled
	Global.lobby_autosave_enabled = false
	Global.bot_test_mode = false
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_kind(PLAYER_SLOT, Global.PlayerKind.HUMAN)
	Global.set_player_kind(DUMMY_SLOT, Global.PlayerKind.BOT)
	Global.test_room_active = true
	_hits.clear()
	_totals.clear()
	_last_hit.clear()
	_last_pos.clear()
	if map_id.is_empty() or not _all_map_ids().has(map_id):
		map_id = _default_map()
	_apply_game_mode_for_map()
	_refresh_panel_values()
	_set_panel_open(true)
	visible = true

func end() -> void:
	_close_picker(false)
	_set_input_blocked(false)
	visible = false
	for slot in _respawn_token.keys():
		_respawn_token[slot] = int(_respawn_token[slot]) + 1
	_clear_numbers()
	Global.test_room_active = false
	if _backup.is_empty():
		Global.lobby_autosave_enabled = _autosave_backup
		return
	Global.set_match_mode(_backup["match_mode"])
	Global.set_game_mode(_backup["game_mode"])
	Global.player_kind.assign(_backup["kinds"])
	Global.player_count = int(_backup["player_count"])
	Global.player_hero_ids.assign(_backup["heroes"])
	Global.player_melee_weapons.assign(_backup["weapons"])
	Global.bot_test_mode = bool(_backup["bot_test"])
	_backup.clear()
	Global.player_count_changed.emit(Global.player_count)
	Global.lobby_state_changed.emit()
	Global.lobby_autosave_enabled = _autosave_backup

## Nach jedem (Neu-)Aufbau der Karte durch main._start_fresh_round.
func on_round_started() -> void:
	_last_pos.clear()
	for slot in [PLAYER_SLOT, DUMMY_SLOT]:
		_respawn_token[slot] = int(_respawn_token.get(slot, 0)) + 1
		_setup_player(main.get_player(slot))

func reload_map() -> void:
	if main == null:
		return
	_close_picker(false)
	_clear_numbers()
	_apply_game_mode_for_map()
	main.restart_test_room_round(map_id)
	_refresh_panel_values()

func on_player_died(slot: int) -> void:
	var p: Player = main.get_player(slot)
	if p != null:
		_last_pos[slot] = p.global_position
		main.players.erase(p)
	var token := int(_respawn_token.get(slot, 0)) + 1
	_respawn_token[slot] = token
	var timer := get_tree().create_timer(RESPAWN_DELAY, false)
	timer.timeout.connect(func():
		if not Global.test_room_active or int(_respawn_token.get(slot, 0)) != token:
			return
		# Wer in Lava oder ins Leere fällt, kommt am Spawnpunkt zurück.
		_respawn(slot, false))

func _respawn(slot: int, keep_position: bool) -> void:
	var at := Vector2.INF
	if keep_position:
		var p: Player = main.get_player(slot)
		if p != null:
			at = p.global_position
	_respawn_token[slot] = int(_respawn_token.get(slot, 0)) + 1
	_setup_player(main.respawn_test_player(slot, at))

## Dummy-Steuerung und Treffer-Signal für eine frisch gespawnte Figur.
func _setup_player(p: Player) -> void:
	if p == null or not is_instance_valid(p):
		return
	if not p.damage_received.is_connected(_on_damage_received):
		p.damage_received.connect(_on_damage_received.bind(p))
	p.control_enabled = true
	if p.player_index != DUMMY_SLOT:
		return
	var old := p.get_node_or_null("TestDummyController")
	if old != null:
		old.queue_free()
	if dummy_mode == DUMMY_BOT:
		return
	var ai := p.get_node_or_null("AIController")
	if ai != null:
		p.remove_child(ai)
		ai.queue_free()
	var ctrl := TestDummyController.new()
	ctrl.name = "TestDummyController"
	ctrl.player = p
	ctrl.fire = dummy_mode == DUMMY_SHOOT
	p.add_child(ctrl)

func _process(_delta: float) -> void:
	if not visible:
		return
	_update_input_block()
	if _stats_label != null and _body.visible:
		_stats_label.text = _stats_text()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == TOGGLE_KEY and (_picker == null or not _picker.visible):
		_set_panel_open(not _body.visible)
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# ESC schließt nur die Kartenauswahl, nicht gleich das Optionsmenü.
	if _picker != null and _picker.visible and event is InputEventKey and event.pressed \
			and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_close_picker(true)
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------
# Schadenszahlen und Messwerte
# ---------------------------------------------------------------------------

func _on_damage_received(amount: float, _source: Variant, kind: String, victim: Player) -> void:
	if not is_instance_valid(victim):
		return
	var slot := victim.player_index
	if kind == "hit":
		var now := Time.get_ticks_msec()
		var list: Array = _hits.get(slot, [])
		list.append([now, amount])
		_hits[slot] = list
		_totals[slot] = float(_totals.get(slot, 0.0)) + amount
		_last_hit[slot] = amount
	if show_numbers:
		_spawn_number(victim, amount, kind)

func _spawn_number(victim: Player, amount: float, kind: String) -> void:
	var key := victim.get_instance_id()
	var stored: Variant = _numbers.get(key, null)
	var last: DamageNumber = stored if is_instance_valid(stored) else null
	if last != null and last.can_merge(kind, amount):
		last.add_amount(amount)
		return
	if kind != "hit" and last != null and last.kind == kind and last.age < 0.35:
		return
	var n := DamageNumber.new()
	main.add_child(n)
	# Schnelle Folgetreffer stapeln sich etwas versetzt, statt sich zu überdecken.
	if last != null and last.age < 0.35:
		n.stack = (last.stack + 1) % 3
	var head := Vector2(0.0, -46.0 * victim.scale.y / Player.BASE_CHARACTER_SCALE)
	n.setup(amount, kind, victim.global_position + head + Vector2(n.stack * 10.0, -18.0 * n.stack))
	_numbers[key] = n

func _clear_numbers() -> void:
	for n in _numbers.values():
		if n != null and is_instance_valid(n):
			n.queue_free()
	_numbers.clear()

func _window_damage(slot: int) -> float:
	var list: Array = _hits.get(slot, [])
	var cutoff := Time.get_ticks_msec() - DPS_WINDOW_MSEC
	while not list.is_empty() and int(list[0][0]) < cutoff:
		list.pop_front()
	var sum := 0.0
	for entry in list:
		sum += float(entry[1])
	return sum

func _stats_line(slot: int, title: String) -> String:
	var window := _window_damage(slot)
	return "%s\n  Letzter Treffer: %s\n  Letzte 5 s: %s  (%s DPS)\n  Gesamt: %s" % [
		title,
		DamageNumber._fmt(float(_last_hit.get(slot, 0.0))),
		DamageNumber._fmt(window),
		DamageNumber._fmt(window / (DPS_WINDOW_MSEC / 1000.0)),
		DamageNumber._fmt(float(_totals.get(slot, 0.0))),
	]

func _stats_text() -> String:
	var lines: Array[String] = [
		_stats_line(DUMMY_SLOT, "SCHADEN AM DUMMY"),
		_stats_line(PLAYER_SLOT, "SCHADEN AN DIR"),
	]
	var dummy: Player = main.get_player(DUMMY_SLOT) if main != null else null
	if dummy != null and is_instance_valid(dummy):
		lines.append("Dummy: %d / %d HP · Schild %d" % [
			int(ceil(maxf(dummy.current_health, 0.0))), int(dummy.max_health), int(dummy.current_shield)])
	return "\n".join(lines)

func _reset_stats() -> void:
	_hits.clear()
	_totals.clear()
	_last_hit.clear()

# ---------------------------------------------------------------------------
# Seitenleiste
# ---------------------------------------------------------------------------

func _build_panel() -> void:
	var anchor := Control.new()
	anchor.name = "PanelAnchor"
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(anchor)

	_panel = PanelContainer.new()
	_panel.name = "TestRoomPanel"
	_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.05, 0.07, 0.92), UiTheme.CYAN_DIM, 2, 8, 12.0, 10.0))
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.offset_left = -330.0
	_panel.offset_right = -12.0
	_panel.offset_top = 96.0
	_panel.custom_minimum_size = Vector2(318, 0)
	anchor.add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)

	_toggle_btn = Button.new()
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	_toggle_btn.add_theme_font_size_override("font_size", UiTheme.FS_L)
	_toggle_btn.pressed.connect(func(): _set_panel_open(not _body.visible))
	outer.add_child(_toggle_btn)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	outer.add_child(_body)

	_body.add_child(_caption("KARTE"))
	_map_option = OptionButton.new()
	_map_option.focus_mode = Control.FOCUS_NONE
	_map_option.fit_to_longest_item = false
	_map_option.item_selected.connect(_on_map_selected)
	_body.add_child(_map_option)

	_hero_ids = _all_hero_ids()
	for slot in [PLAYER_SLOT, DUMMY_SLOT]:
		_body.add_child(_caption("DEIN HELD" if slot == PLAYER_SLOT else "HELD DES DUMMYS"))
		var opt := OptionButton.new()
		opt.focus_mode = Control.FOCUS_NONE
		for hero_id in _hero_ids:
			opt.add_item(Global.get_hero(hero_id).name)
		opt.item_selected.connect(_on_hero_selected.bind(slot))
		_body.add_child(opt)
		_hero_options[slot] = opt

	_body.add_child(_caption("DUMMY"))
	_dummy_option = OptionButton.new()
	_dummy_option.focus_mode = Control.FOCUS_NONE
	for entry in DUMMY_MODES:
		_dummy_option.add_item(entry[1])
	_dummy_option.item_selected.connect(_on_dummy_mode_selected)
	_body.add_child(_dummy_option)

	_numbers_check = CheckBox.new()
	_numbers_check.text = "Schadenszahlen anzeigen"
	_numbers_check.focus_mode = Control.FOCUS_NONE
	_numbers_check.button_pressed = show_numbers
	_numbers_check.toggled.connect(func(on: bool):
		show_numbers = on
		if not on:
			_clear_numbers())
	_body.add_child(_numbers_check)

	_body.add_child(_caption("KARTEN"))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 6)
	_body.add_child(card_row)
	card_row.add_child(_button("FÜR DICH", func(): _open_picker(PLAYER_SLOT), true))
	card_row.add_child(_button("FÜR DUMMY", func(): _open_picker(DUMMY_SLOT), true))
	_cards_label = Label.new()
	_cards_label.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	_cards_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	_cards_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(_cards_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	_body.add_child(action_row)
	action_row.add_child(_button("ALLE KARTEN WEG", _clear_all_cards, true))
	action_row.add_child(_button("VOLLE HP", _refill_all, true))
	var action_row2 := HBoxContainer.new()
	action_row2.add_theme_constant_override("separation", 6)
	_body.add_child(action_row2)
	action_row2.add_child(_button("MESSUNG NULLEN", _reset_stats, true))
	action_row2.add_child(_button("NEU LADEN", reload_map, true))

	_body.add_child(HSeparator.new())
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", UiTheme.FS_S)
	_stats_label.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	_body.add_child(_stats_label)

	var hint := Label.new()
	hint.text = "F2 klappt die Leiste ein · F9 lädt die Karte neu · ESC → Hauptmenü verlässt den Testraum"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	_body.add_child(hint)

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	l.add_theme_color_override("font_color", UiTheme.CYAN)
	return l

func _button(text: String, callback: Callable, expand: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", UiTheme.FS_S)
	if expand:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		SoundManager.play_sound("click")
		callback.call())
	return b

func _set_panel_open(open: bool) -> void:
	if _body == null:
		return
	_body.visible = open
	_toggle_btn.text = ("TESTRAUM  ▾  [F2]" if open else "TESTRAUM  ▸  [F2]")
	_panel.reset_size()

func _refresh_panel_values() -> void:
	_map_ids = _all_map_ids()
	_map_option.clear()
	for id in _map_ids:
		var label := Global.get_map_name(id)
		if ArenaMaps.is_arena_map(id):
			label = "Arena: " + ArenaMaps.display_name(id)
		_map_option.add_item(label)
	_map_option.select(maxi(0, _map_ids.find(map_id)))
	for slot in _hero_options.keys():
		var idx := _hero_ids.find(Global.get_player_hero_id(slot))
		(_hero_options[slot] as OptionButton).select(maxi(0, idx))
	for i in range(DUMMY_MODES.size()):
		if DUMMY_MODES[i][0] == dummy_mode:
			_dummy_option.select(i)
	_refresh_cards_label()

func _refresh_cards_label() -> void:
	if _cards_label == null:
		return
	_cards_label.text = "Du: %d Karten · Dummy: %d Karten" % [
		Global.get_player_cards(PLAYER_SLOT).size(), Global.get_player_cards(DUMMY_SLOT).size()]

# Maus über der Leiste: kein Schuss, kein Zielen ins Menü.
func _update_input_block() -> void:
	var over := false
	if _picker != null and _picker.visible:
		over = true
	elif _panel != null and _panel.visible:
		over = _panel.get_global_rect().has_point(_panel.get_global_mouse_position())
		# Ohne Maus darüber halb durchsichtig, damit man den Dummy dahinter sieht.
		_panel.modulate.a = 1.0 if over else 0.6
	_set_input_blocked(over)

func _set_input_blocked(blocked: bool) -> void:
	if blocked == _blocked_input:
		return
	# Das Optionsmenü setzt dieselbe Sperre; dann nicht dazwischenfunken.
	if main != null and main.options_menu != null and main.options_menu.is_open():
		_blocked_input = false
		return
	_blocked_input = blocked
	GameSettings.gameplay_input_blocked = blocked

func _on_map_selected(index: int) -> void:
	if index < 0 or index >= _map_ids.size():
		return
	map_id = _map_ids[index]
	reload_map()

func _on_hero_selected(index: int, slot: int) -> void:
	if index < 0 or index >= _hero_ids.size():
		return
	var hero_id := _hero_ids[index]
	if Global.get_player_hero_id(slot) == hero_id:
		return
	Global.set_player_hero(slot, hero_id)
	# Klassenkarten des alten Helden passen nicht mehr.
	var cards: Array = Global.get_player_cards(slot)
	for card in cards.duplicate():
		if not (card as CardData).hero_id.is_empty() and card.hero_id != hero_id:
			cards.erase(card)
	_refresh_cards_label()
	_respawn(slot, true)

func _on_dummy_mode_selected(index: int) -> void:
	dummy_mode = DUMMY_MODES[clampi(index, 0, DUMMY_MODES.size() - 1)][0]
	_respawn(DUMMY_SLOT, true)

func _clear_all_cards() -> void:
	for slot in [PLAYER_SLOT, DUMMY_SLOT]:
		Global.get_player_cards(slot).clear()
		_respawn(slot, true)
	_refresh_cards_label()

func _refill_all() -> void:
	for slot in [PLAYER_SLOT, DUMMY_SLOT]:
		var p: Player = main.get_player(slot)
		if p != null and is_instance_valid(p):
			p.current_health = p.max_health
			p.current_shield = p.max_shield
			p.health_changed.emit(p.current_health, p.max_health, p.current_shield, p.max_shield)

func _all_map_ids() -> Array[String]:
	var ids: Array[String] = Global.get_playable_maps()
	for id in ArenaMaps.MAP_IDS:
		if not ids.has(id):
			ids.append(id)
	for id in ArenaMaps.custom_ids():
		if not ids.has(id):
			ids.append(id)
	return ids

func _default_map() -> String:
	var selected: String = Global.selected_map_id
	var ids := _all_map_ids()
	if ids.has(selected):
		return selected
	return ids[0] if not ids.is_empty() else ""

func _apply_game_mode_for_map() -> void:
	Global.set_game_mode(Global.GAME_MODE_ARENA if ArenaMaps.is_arena_map(map_id) else Global.GAME_MODE_SIDE)

func _all_hero_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in GameLobby.HERO_IDS:
		if Global.heroes.has(id):
			ids.append(id)
	for id in Global.heroes.keys():
		if not ids.has(str(id)):
			ids.append(str(id))
	return ids

# ---------------------------------------------------------------------------
# Kartenauswahl (Karten-Optik aus dem Draft-Bildschirm)
# ---------------------------------------------------------------------------

func _build_picker() -> void:
	_picker = Control.new()
	_picker.name = "CardPicker"
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker.visible = false
	add_child(_picker)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.01, 0.02, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_picker.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	_picker_title = Label.new()
	_picker_title.add_theme_font_size_override("font_size", UiTheme.FS_H2)
	_picker_title.add_theme_font_override("font", UiTheme.FONT_BOLD)
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_picker_title)
	var done := _button("FERTIG  [ESC]", func(): _close_picker(true))
	done.add_theme_font_size_override("font_size", UiTheme.FS_L)
	done.custom_minimum_size = Vector2(180, 44)
	head.add_child(done)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 10)
	col.add_child(filters)
	_picker_search = LineEdit.new()
	_picker_search.placeholder_text = "Suchen (Name oder Text) …"
	_picker_search.custom_minimum_size = Vector2(320, 0)
	_picker_search.clear_button_enabled = true
	_picker_search.text_changed.connect(func(_t: String): _fill_picker_grid())
	filters.add_child(_picker_search)
	_picker_rarity = OptionButton.new()
	_picker_rarity.add_item("Alle Seltenheiten")
	for r in RARITIES:
		_picker_rarity.add_item(r)
	_picker_rarity.item_selected.connect(func(_i: int): _fill_picker_grid())
	filters.add_child(_picker_rarity)
	_picker_pool = OptionButton.new()
	_picker_pool.add_item("Alle Bereiche")
	for pool in Global.CARD_POOLS:
		_picker_pool.add_item(pool)
	_picker_pool.item_selected.connect(func(_i: int): _fill_picker_grid())
	filters.add_child(_picker_pool)
	_picker_hero_only = CheckBox.new()
	_picker_hero_only.text = "Nur Karten, die zum Helden passen"
	_picker_hero_only.button_pressed = true
	_picker_hero_only.toggled.connect(func(_on: bool): _fill_picker_grid())
	filters.add_child(_picker_hero_only)
	var clear_btn := _button("ALLE ENTFERNEN", func():
		Global.get_player_cards(_picker_slot).clear()
		_picker_dirty = true
		_refresh_picker())
	filters.add_child(clear_btn)

	var owned_box := PanelContainer.new()
	owned_box.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.07, 0.10, 0.88), Color(0.35, 0.55, 0.70, 0.65), 2, 8, 10.0, 6.0))
	col.add_child(owned_box)
	var owned_col := VBoxContainer.new()
	owned_box.add_child(owned_col)
	var owned_title := Label.new()
	owned_title.text = "AKTIVE KARTEN · KLICK ENTFERNT"
	owned_title.add_theme_font_size_override("font_size", UiTheme.FS_S)
	owned_title.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	owned_col.add_child(owned_title)
	_picker_owned_flow = HFlowContainer.new()
	_picker_owned_flow.add_theme_constant_override("h_separation", 6)
	_picker_owned_flow.add_theme_constant_override("v_separation", 5)
	owned_col.add_child(_picker_owned_flow)

	_picker_info = Label.new()
	_picker_info.add_theme_font_size_override("font_size", UiTheme.FS_S)
	_picker_info.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	col.add_child(_picker_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_picker_grid = HFlowContainer.new()
	_picker_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_grid.add_theme_constant_override("h_separation", 12)
	_picker_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_picker_grid)

func _open_picker(slot: int) -> void:
	if main == null:
		return
	_picker_slot = slot
	_picker_dirty = false
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(slot))
	_picker_title.text = "KARTEN FÜR %s · %s" % ["DICH" if slot == PLAYER_SLOT else "DEN DUMMY", hero.name.to_upper()]
	_picker_title.add_theme_color_override("font_color", hero.color_tint)
	_picker_paused_before = get_tree().paused
	get_tree().paused = true
	_set_panel_open(false)
	_picker.visible = true
	_refresh_picker()
	_picker_search.grab_focus()

func _close_picker(apply: bool) -> void:
	if _picker == null or not _picker.visible:
		return
	_picker.visible = false
	for child in _picker_grid.get_children():
		child.queue_free()
	get_tree().paused = _picker_paused_before
	_set_panel_open(true)
	if apply and _picker_dirty:
		_respawn(_picker_slot, true)
	_picker_dirty = false
	_refresh_cards_label()

func _refresh_picker() -> void:
	_fill_owned_chips()
	_fill_picker_grid()

func _fill_owned_chips() -> void:
	for child in _picker_owned_flow.get_children():
		child.queue_free()
	var cards: Array = Global.get_player_cards(_picker_slot)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Karten. Klick unten auf eine Karte, um sie zu geben."
		empty.add_theme_font_size_override("font_size", UiTheme.FS_S)
		empty.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		_picker_owned_flow.add_child(empty)
		return
	for card in cards:
		_picker_owned_flow.add_child(_owned_chip(card))

func _owned_chip(card: CardData) -> Button:
	var chip := Button.new()
	chip.focus_mode = Control.FOCUS_NONE
	chip.text = card.title + "  ✕"
	chip.add_theme_font_size_override("font_size", UiTheme.FS_S)
	chip.add_theme_color_override("font_color", card.color)
	var style := UiTheme.box(Color(0.09, 0.11, 0.15, 0.94), CardDatabase.get_rarity_color(card.rarity), 1, 6, 8.0, 3.0)
	chip.add_theme_stylebox_override("normal", style)
	chip.add_theme_stylebox_override("hover", UiTheme.box(Color(0.20, 0.08, 0.08, 0.96), UiTheme.DANGER, 1, 6, 8.0, 3.0))
	chip.add_theme_stylebox_override("pressed", style)
	CardMechanics.apply_tooltip(chip, card)
	chip.pressed.connect(func(): _toggle_card(card))
	return chip

func _card_matches(card: CardData, query: String, rarity: String, pool: String, hero_id: String, hero_only: bool) -> bool:
	if hero_only and not card.hero_id.is_empty() and card.hero_id != hero_id:
		return false
	if not rarity.is_empty() and card.rarity != rarity:
		return false
	if not pool.is_empty() and card.pool != pool:
		return false
	if query.is_empty():
		return true
	return card.title.to_lower().contains(query) or card.description.to_lower().contains(query) \
			or card.id.to_lower().contains(query)

func _fill_picker_grid() -> void:
	if _picker_grid == null or not _picker.visible:
		return
	for child in _picker_grid.get_children():
		_picker_grid.remove_child(child)
		child.queue_free()
	var query := _picker_search.text.strip_edges().to_lower()
	var rarity := "" if _picker_rarity.selected <= 0 else RARITIES[_picker_rarity.selected - 1]
	var pool := "" if _picker_pool.selected <= 0 else Global.CARD_POOLS[_picker_pool.selected - 1]
	var hero_id := Global.get_player_hero_id(_picker_slot)
	var matches: Array[CardData] = []
	for card in CardDatabase.all_cards:
		if _card_matches(card, query, rarity, pool, hero_id, _picker_hero_only.button_pressed):
			matches.append(card)
	var shown := mini(matches.size(), MAX_SHOWN_CARDS)
	_picker_info.text = "%d Karten passen%s · Klick auf eine Karte gibt sie, nochmal Klick nimmt sie weg." % [
		matches.size(), "" if shown == matches.size() else " (die ersten %d werden gezeigt, Suche eingrenzen)" % shown]
	var draft_ui: CardDraftUI = main.card_draft_ui
	for i in range(shown):
		var card := matches[i]
		var owned := Global.player_has_card(_picker_slot, card.id)
		var footer := "✓ AKTIV · KLICK ENTFERNT" if owned else "KLICK: GEBEN"
		var panel: PanelContainer = draft_ui._create_card_button(card, i + 1, false, footer, UiTheme.SUCCESS if owned else UiTheme.TEXT_SOFT)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if owned:
			panel.modulate = Color(0.75, 1.0, 0.8)
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_toggle_card(card))
		_picker_grid.add_child(panel)

func _toggle_card(card: CardData) -> void:
	var cards: Array = Global.get_player_cards(_picker_slot)
	if Global.player_has_card(_picker_slot, card.id):
		for owned in cards.duplicate():
			if owned.id == card.id:
				cards.erase(owned)
	else:
		Global.add_card_to_player(_picker_slot, card)
	_picker_dirty = true
	SoundManager.play_sound("click")
	# Scrollposition behalten: nur neu befüllen, nicht neu aufbauen.
	var scroll := _picker_grid.get_parent() as ScrollContainer
	var keep := scroll.scroll_vertical if scroll != null else 0
	_refresh_picker()
	if scroll != null:
		scroll.set_deferred("scroll_vertical", keep)
