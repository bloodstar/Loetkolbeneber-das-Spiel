class_name OptionsMenu
extends CanvasLayer

# Optionsmenü: Grafik (Fenstermodus), Audio (Master/Effekte/Musik) und
# Tastenbelegung, dazu der Knopf STATISTIK (StatsScreen). Erreichbar über den Hauptmenü-Knopf und während einer
# Runde über ESC. Lokal pausiert es das Spiel; online läuft die Simulation
# des Hosts weiter und nur die eigenen Eingaben werden ignoriert.

signal closed
signal main_menu_requested

var _in_game: bool = false
var _was_paused: bool = false
var _awaiting_action: String = ""
var _awaiting_button: Button = null

var _window_option: OptionButton = null
var _volume_sliders: Dictionary = {}
var _volume_labels: Dictionary = {}
var _pack_option: OptionButton = null
var _binding_buttons: Dictionary = {}
var _status_label: Label = null
var _back_btn: Button = null
var _menu_btn: Button = null
var _tabs: TabContainer = null
var _stats_screen: StatsScreen = null

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	_stats_screen = StatsScreen.new()
	_stats_screen.name = "StatsScreen"
	add_child(_stats_screen)
	_stats_screen.closed.connect(func(): _back_btn.grab_focus())
	GameSettings.settings_changed.connect(_refresh)

func is_open() -> bool:
	return visible

func open_options(in_game: bool = false) -> void:
	_in_game = in_game
	_cancel_rebind()
	_was_paused = get_tree().paused
	if in_game and not Global.network_mode:
		get_tree().paused = true
	GameSettings.gameplay_input_blocked = in_game
	_menu_btn.visible = in_game
	if in_game and Global.network_mode:
		_menu_btn.text = "SPIEL VERLASSEN"
	else:
		_menu_btn.text = "ZUM HAUPTMENÜ"
	_back_btn.text = "WEITER SPIELEN" if in_game else "ZURÜCK"
	_status_label.text = "Online läuft die Runde weiter, während dieses Menü offen ist." if in_game and Global.network_mode else ""
	_refresh()
	visible = true
	_back_btn.grab_focus()

func close_options() -> void:
	if not visible:
		return
	_cancel_rebind()
	_stats_screen.close_screen()
	visible = false
	GameSettings.gameplay_input_blocked = false
	if _in_game and not Global.network_mode:
		get_tree().paused = _was_paused
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible or _stats_screen.is_open():
		return
	if not _awaiting_action.is_empty():
		_handle_rebind_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SoundManager.play_sound("click")
		close_options()

# --- Aufbau ---

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 640)
	panel.add_theme_stylebox_override("panel", WorkshopStyle.panel_box())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)

	var title := Label.new()
	title.text = "OPTIONEN"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", WorkshopStyle.CYAN_LIGHT)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 6)
	body.add_child(title)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 18)
	body.add_child(_tabs)
	_tabs.add_child(_build_graphics_tab())
	_tabs.add_child(_build_audio_tab())
	_tabs.add_child(_build_controls_tab())

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", WorkshopStyle.ACCENT_LIGHT)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 22)
	body.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	body.add_child(buttons)

	_menu_btn = Button.new()
	_menu_btn.text = "ZUM HAUPTMENÜ"
	_menu_btn.custom_minimum_size = Vector2(240, 50)
	WorkshopStyle.style_button(_menu_btn, false, 18)
	_menu_btn.pressed.connect(_on_main_menu_pressed)
	buttons.add_child(_menu_btn)

	var stats_btn := Button.new()
	stats_btn.text = "STATISTIK"
	stats_btn.tooltip_text = "Balance-Auswertung aller gespielten Runden: Karten, Waffen und Helden."
	stats_btn.custom_minimum_size = Vector2(200, 50)
	WorkshopStyle.style_button(stats_btn, false, 18)
	stats_btn.pressed.connect(func():
		SoundManager.play_sound("click")
		_cancel_rebind()
		_stats_screen.open_screen()
	)
	buttons.add_child(stats_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)

	_back_btn = Button.new()
	_back_btn.text = "ZURÜCK"
	_back_btn.custom_minimum_size = Vector2(260, 50)
	WorkshopStyle.style_button(_back_btn, true, 20)
	_back_btn.pressed.connect(func():
		SoundManager.play_sound("confirm")
		close_options()
	)
	buttons.add_child(_back_btn)

func _tab_page(tab_name: String) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.name = tab_name
	page.add_theme_constant_override("separation", 16)
	return page

func _row(parent: Control, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", WorkshopStyle.TEXT)
	row.add_child(label)
	parent.add_child(row)
	return row

func _build_graphics_tab() -> Control:
	var page := _tab_page("Grafik")
	page.add_child(_spacer(6))
	var row := _row(page, "Anzeigemodus")
	_window_option = OptionButton.new()
	_window_option.custom_minimum_size = Vector2(340, 44)
	_window_option.add_theme_font_size_override("font_size", 18)
	for i in range(GameSettings.WINDOW_MODES.size()):
		var mode: String = GameSettings.WINDOW_MODES[i]
		_window_option.add_item(str(GameSettings.WINDOW_MODE_LABELS[mode]), i)
	_window_option.item_selected.connect(func(index: int):
		SoundManager.play_sound("click")
		GameSettings.set_window_mode(GameSettings.WINDOW_MODES[index])
	)
	row.add_child(_window_option)
	return page

func _build_audio_tab() -> Control:
	var page := _tab_page("Audio")
	page.add_child(_spacer(6))
	var labels := {"master": "Gesamtlautstärke", "effects": "Effekte", "music": "Musik"}
	for key in GameSettings.VOLUME_KEYS:
		var row := _row(page, str(labels[key]))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.custom_minimum_size = Vector2(380, 32)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(64, 0)
		value_label.add_theme_font_size_override("font_size", 18)
		value_label.add_theme_color_override("font_color", WorkshopStyle.ACCENT_LIGHT)
		row.add_child(value_label)
		_volume_sliders[key] = slider
		_volume_labels[key] = value_label
		slider.value_changed.connect(func(value: float):
			value_label.text = "%d %%" % int(value)
			GameSettings.set_volume(key, value / 100.0, false)
		)
		# Erst beim Loslassen speichern und kurz Probe hören lassen.
		slider.drag_ended.connect(func(_changed: bool):
			GameSettings.save_settings()
			if key == "effects" or key == "master":
				SoundManager.play_sound("coin")
		)

	# Soundpaket zum Vergleichen: wirkt sofort, auch mitten in einer Runde.
	page.add_child(_spacer(4))
	var pack_row := _row(page, "Soundpaket")
	_pack_option = OptionButton.new()
	_pack_option.custom_minimum_size = Vector2(300, 44)
	_pack_option.add_theme_font_size_override("font_size", 18)
	var pack_list := SoundManager.get_sound_pack_list()
	for i in range(pack_list.size()):
		_pack_option.add_item(str(pack_list[i]["label"]), i)
	_pack_option.item_selected.connect(func(index: int):
		GameSettings.set_sound_pack(str(pack_list[index]["id"]))
		_play_pack_demo()
	)
	pack_row.add_child(_pack_option)
	var demo_btn := Button.new()
	demo_btn.text = "PROBE"
	demo_btn.custom_minimum_size = Vector2(110, 44)
	WorkshopStyle.style_button(demo_btn, false, 16)
	demo_btn.pressed.connect(_play_pack_demo)
	pack_row.add_child(demo_btn)
	var pack_hint := Label.new()
	pack_hint.text = "Test: andere Effekt-Sets ausprobieren. Gilt nur auf diesem PC, Mitspieler hören ihr eigenes Set."
	pack_hint.add_theme_font_size_override("font_size", 14)
	pack_hint.add_theme_color_override("font_color", WorkshopStyle.TEXT_DIM)
	pack_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(pack_hint)
	return page

# Kurze Hörprobe des gewählten Pakets: Schüsse, Treffer, Sprung, Münze, Explosion.
func _play_pack_demo() -> void:
	var steps := [["shoot", 0.0], ["shoot", 0.14], ["hit", 0.3], ["jump", 0.55], ["bounce", 0.8], ["coin", 1.05], ["explosion", 1.35]]
	for step in steps:
		var key: String = step[0]
		var delay: float = step[1]
		if delay <= 0.0:
			SoundManager.play_sound(key)
		else:
			get_tree().create_timer(delay, true).timeout.connect(func(): SoundManager.play_sound(key))

func _build_controls_tab() -> Control:
	var page := _tab_page("Steuerung")
	var hint := Label.new()
	hint.text = "Feld anklicken, dann neue Taste oder Maustaste drücken. Esc bricht ab."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", WorkshopStyle.TEXT_DIM)
	page.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for entry in GameSettings.REBINDABLE_ACTIONS:
		if entry.has("group"):
			var header := Label.new()
			header.text = str(entry["group"]).to_upper()
			header.add_theme_font_size_override("font_size", 15)
			header.add_theme_color_override("font_color", WorkshopStyle.CYAN)
			list.add_child(_spacer(4))
			list.add_child(header)
			continue
		var action := str(entry["action"])
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var label := Label.new()
		label.text = str(entry["label"])
		label.custom_minimum_size = Vector2(300, 0)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", WorkshopStyle.TEXT)
		row.add_child(label)
		var bind_btn := Button.new()
		bind_btn.custom_minimum_size = Vector2(260, 36)
		WorkshopStyle.style_button(bind_btn, false, 16)
		bind_btn.pressed.connect(_start_rebind.bind(action, bind_btn))
		row.add_child(bind_btn)
		list.add_child(row)
		_binding_buttons[action] = bind_btn

	var reset_btn := Button.new()
	reset_btn.text = "STANDARD WIEDERHERSTELLEN"
	reset_btn.custom_minimum_size = Vector2(320, 42)
	reset_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	WorkshopStyle.style_button(reset_btn, false, 16)
	reset_btn.pressed.connect(func():
		SoundManager.play_sound("click")
		_cancel_rebind()
		GameSettings.reset_bindings()
		_status_label.text = "Tastenbelegung auf Standard zurückgesetzt."
	)
	page.add_child(reset_btn)
	return page

func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

# --- Werte anzeigen ---

func _refresh() -> void:
	if _window_option == null:
		return
	_window_option.select(maxi(0, GameSettings.WINDOW_MODES.find(GameSettings.window_mode)))
	if _pack_option != null:
		var pack_list := SoundManager.get_sound_pack_list()
		for i in range(mini(pack_list.size(), _pack_option.item_count)):
			if str(pack_list[i]["id"]) == GameSettings.sound_pack:
				_pack_option.select(i)
	for key in _volume_sliders.keys():
		var slider: HSlider = _volume_sliders[key]
		var value := roundf(GameSettings.get_volume(key) * 100.0)
		slider.set_value_no_signal(value)
		(_volume_labels[key] as Label).text = "%d %%" % int(value)
	for action in _binding_buttons.keys():
		if action == _awaiting_action:
			continue
		(_binding_buttons[action] as Button).text = GameSettings.get_binding_text(action)

# --- Tastenbelegung ---

func _start_rebind(action: String, button: Button) -> void:
	SoundManager.play_sound("click")
	_cancel_rebind()
	_awaiting_action = action
	_awaiting_button = button
	button.text = "Taste drücken …"
	_status_label.text = "Neue Taste für „%s“ drücken (Esc bricht ab)." % GameSettings.get_action_label(action)

func _cancel_rebind() -> void:
	if _awaiting_button != null and is_instance_valid(_awaiting_button):
		_awaiting_button.text = GameSettings.get_binding_text(_awaiting_action)
	_awaiting_action = ""
	_awaiting_button = null

func _handle_rebind_input(event: InputEvent) -> void:
	var accepted: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_rebind()
			_status_label.text = ""
			return
		accepted = event
	elif event is InputEventMouseButton and event.pressed:
		# Mausrad taugt nicht als Taste zum Gedrückthalten.
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
			return
		accepted = event
	if accepted == null:
		return
	get_viewport().set_input_as_handled()
	var action := _awaiting_action
	var conflicts := GameSettings.find_conflicts(action, accepted)
	_awaiting_action = ""
	_awaiting_button = null
	if GameSettings.set_binding(action, accepted):
		SoundManager.play_sound("confirm")
		if conflicts.is_empty():
			_status_label.text = "„%s“ liegt jetzt auf %s." % [GameSettings.get_action_label(action), GameSettings.get_binding_text(action)]
		else:
			var names: Array[String] = []
			for other in conflicts:
				names.append(GameSettings.get_action_label(other) + (" (P2)" if other.begins_with("p2_") else ""))
			_status_label.text = "Achtung: %s ist auch belegt für %s." % [GameSettings.get_binding_text(action), ", ".join(names)]
	_refresh()

func _on_main_menu_pressed() -> void:
	SoundManager.play_sound("click")
	close_options()
	main_menu_requested.emit()
