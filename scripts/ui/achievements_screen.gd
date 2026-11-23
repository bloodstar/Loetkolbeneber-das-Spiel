class_name AchievementsScreen
extends CanvasLayer

# Erfolgsliste: alle Erfolge aus AchievementManager mit Fortschritt, Belohnung
# (Titel / Aussehens-Teil) und Freischaltdatum, dazu die Titel-Auswahl und ein
# Testschalter, der alle Aussehens-Teile freigibt. Geöffnet über den Knopf
# ERFOLGE im Hauptmenü und im Charakter-Tab der Lobby. ESC schließt.

signal closed

var _summary_label: Label = null
var _title_option: OptionButton = null
var _title_ids: Array[String] = []
var _unlock_all_box: CheckBox = null
var _list: VBoxContainer = null
var _back_btn: Button = null
var _updating: bool = false

func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
	AchievementManager.progress_changed.connect(func():
		if visible:
			_rebuild()
	)

func is_open() -> bool:
	return visible

func open_screen() -> void:
	_rebuild()
	visible = true
	_back_btn.grab_focus()

func close_screen() -> void:
	if not visible:
		return
	visible = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SoundManager.play_sound("click")
		close_screen()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 820)
	panel.add_theme_stylebox_override("panel", WorkshopStyle.panel_box())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	body.add_child(header)
	var title := Label.new()
	title.text = "ERFOLGE"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", UiTheme.FS_H1)
	title.add_theme_color_override("font_color", WorkshopStyle.CYAN_LIGHT)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 6)
	header.add_child(title)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary_label.add_theme_font_size_override("font_size", UiTheme.FS_L)
	_summary_label.add_theme_color_override("font_color", UiTheme.GOLD)
	header.add_child(_summary_label)

	var options_row := HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 14)
	body.add_child(options_row)
	var title_caption := Label.new()
	title_caption.text = "Dein Titel"
	title_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_caption.add_theme_font_size_override("font_size", UiTheme.FS_BODY)
	options_row.add_child(title_caption)
	_title_option = OptionButton.new()
	_title_option.custom_minimum_size = Vector2(260, 38)
	_title_option.tooltip_text = "Steht unter deinem Namen in Lobby, Charakterbogen und Endstand. Online sehen ihn alle."
	_title_option.item_selected.connect(_on_title_selected)
	options_row.add_child(_title_option)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_row.add_child(spacer)
	_unlock_all_box = CheckBox.new()
	_unlock_all_box.text = "Alle Aussehens-Teile freigeben (Test)"
	_unlock_all_box.tooltip_text = "Macht gesperrte Hauer, Lötspitzen und Baukasten-Teile im Charakter-Tab wählbar.\nFortschritt, Erfolge und Titel ändern sich dadurch nicht."
	_unlock_all_box.toggled.connect(func(pressed: bool):
		if _updating:
			return
		SoundManager.play_sound("click")
		AchievementManager.set_unlock_all_cosmetics(pressed)
	)
	options_row.add_child(_unlock_all_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	body.add_child(footer)
	var path_label := Label.new()
	path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	path_label.add_theme_font_size_override("font_size", UiTheme.FS_S)
	path_label.add_theme_color_override("font_color", WorkshopStyle.TEXT_DIM)
	path_label.text = "Fortschritt zählt für deinen eigenen Slot in Matches mit mindestens einem Gegner (nicht im Bot-Test)."
	footer.add_child(path_label)
	_back_btn = Button.new()
	_back_btn.text = "ZURÜCK"
	_back_btn.custom_minimum_size = Vector2(240, 48)
	WorkshopStyle.style_button(_back_btn, true, UiTheme.FS_XL)
	_back_btn.pressed.connect(func():
		SoundManager.play_sound("confirm")
		close_screen()
	)
	footer.add_child(_back_btn)

func _rebuild() -> void:
	_updating = true
	var total := AchievementManager.get_achievements().size()
	_summary_label.text = "%d / %d freigeschaltet" % [AchievementManager.get_unlocked_count(), total]
	_title_option.clear()
	_title_ids.clear()
	_title_option.add_item("– kein Titel –")
	_title_ids.append("")
	for entry in AchievementManager.get_unlocked_titles():
		_title_option.add_item(str(entry[1]))
		_title_ids.append(str(entry[0]))
	_title_option.select(maxi(0, _title_ids.find(AchievementManager.selected_title)))
	_unlock_all_box.button_pressed = AchievementManager.unlock_all_cosmetics
	_updating = false

	for child in _list.get_children():
		child.queue_free()
	# Freigeschaltete zuerst? Nein: feste Reihenfolge, damit man Ziele wiederfindet.
	for entry in AchievementManager.get_achievements():
		_list.add_child(_build_row(entry))

func _on_title_selected(index: int) -> void:
	if _updating or index < 0 or index >= _title_ids.size():
		return
	SoundManager.play_sound("click")
	AchievementManager.set_selected_title(_title_ids[index])

static func build_row(entry: Dictionary) -> Control:
	var id := str(entry["id"])
	var done := AchievementManager.is_unlocked(id)
	var goal := float(entry["goal"])
	var progress := AchievementManager.get_progress(id)

	var panel := PanelContainer.new()
	var border := UiTheme.GOLD if done else UiTheme.with_alpha(UiTheme.TEXT_MUTED, 0.35)
	panel.add_theme_stylebox_override("panel", UiTheme.box(
		Color(0.06, 0.07, 0.04, 0.92) if done else Color(0.03, 0.05, 0.07, 0.85), border, 1, 8, 14, 8))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = "🏆" if done else "🔒"
	icon.custom_minimum_size = Vector2(36, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", UiTheme.FS_H2)
	if not done:
		icon.modulate = Color(1, 1, 1, 0.55)
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 1)
	row.add_child(text_col)
	var name_label := Label.new()
	name_label.text = str(entry["name"])
	name_label.add_theme_font_size_override("font_size", UiTheme.FS_L)
	name_label.add_theme_color_override("font_color", UiTheme.GOLD if done else UiTheme.TEXT)
	text_col.add_child(name_label)
	var desc := Label.new()
	desc.text = str(entry["desc"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", UiTheme.FS_S)
	desc.add_theme_color_override("font_color", UiTheme.TEXT_SOFT)
	text_col.add_child(desc)
	var reward := AchievementManager.get_reward_text(entry)
	if not reward.is_empty():
		var reward_label := Label.new()
		reward_label.text = "Belohnung: " + reward
		reward_label.add_theme_font_size_override("font_size", UiTheme.FS_XS)
		reward_label.add_theme_color_override("font_color", UiTheme.ACCENT_LIGHT if not done else UiTheme.SUCCESS)
		text_col.add_child(reward_label)

	var progress_col := VBoxContainer.new()
	progress_col.custom_minimum_size = Vector2(230, 0)
	progress_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(progress_col)
	var bar := ProgressBar.new()
	bar.max_value = goal
	bar.value = progress
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(230, 12)
	bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.02, 0.03, 0.04, 1.0), Color.TRANSPARENT, 0, 4, 0, 0))
	bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.GOLD if done else UiTheme.CYAN, Color.TRANSPARENT, 0, 4, 0, 0))
	progress_col.add_child(bar)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	value.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	var counter_label := AchievementManager.get_counter_label(str(entry["counter"]))
	if done:
		var stamp := str(AchievementManager.unlocked.get(id, ""))
		value.text = "Freigeschaltet %s" % _format_date(stamp)
	else:
		value.text = "%s / %s %s" % [_format_number(progress), _format_number(goal), counter_label]
	progress_col.add_child(value)
	return panel

func _build_row(entry: Dictionary) -> Control:
	return build_row(entry)

static func _format_number(value: float) -> String:
	var n := int(value)
	var text := str(n)
	if n >= 1000:
		var out := ""
		var digits := str(n)
		for i in range(digits.length()):
			if i > 0 and (digits.length() - i) % 3 == 0:
				out += "."
			out += digits[i]
		text = out
	return text

# "2026-11-22T23:10:00" -> "22.11.2026"
static func _format_date(stamp: String) -> String:
	if stamp.length() < 10:
		return ""
	var date := stamp.substr(0, 10).split("-")
	if date.size() != 3:
		return ""
	return "am %s.%s.%s" % [date[2], date[1], date[0]]
