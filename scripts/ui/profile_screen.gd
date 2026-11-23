class_name ProfileScreen
extends PanelContainer

# Profil-Ansicht im Hauptmenü (Knopf PROFIL): Lebenszeit-Werte aus
# PlayerProfile, Lieblingsheld, meistgewählte Karte, Rekorde, Tabellen für
# Helden/Karten/Maps und die letzten Matches. Gibt es einen Autoload
# AchievementManager mit build_profile_section() -> Control, wird dessen
# Abschnitt "TITEL & ERFOLGE" eingehängt.

signal closed()

const TOP_CARDS: int = 10
const TOP_MAPS: int = 8

var _content: VBoxContainer = null
var _name_label: Label = null
var _since_label: Label = null
var _reset_btn: Button = null
var _reset_armed: bool = false

func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 60.0
	offset_top = 40.0
	offset_right = -60.0
	offset_bottom = -40.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.055, 0.085, 0.995)
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color(UiTheme.CYAN, 0.6)
	panel_style.set_corner_radius_all(14)
	add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)

	var title := Label.new()
	title.text = "PROFIL"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", UiTheme.FS_H2)
	title.add_theme_color_override("font_color", UiTheme.CYAN)
	header.add_child(title)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.alignment = BoxContainer.ALIGNMENT_CENTER
	name_box.add_theme_constant_override("separation", 0)
	header.add_child(name_box)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", UiTheme.FS_L)
	_name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	name_box.add_child(_name_label)
	_since_label = Label.new()
	_since_label.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	_since_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	name_box.add_child(_since_label)

	_reset_btn = Button.new()
	_reset_btn.text = "ZURÜCKSETZEN"
	_reset_btn.tooltip_text = "Alle Lebenszeit-Werte löschen. Zweimal klicken zum Bestätigen."
	_reset_btn.custom_minimum_size = Vector2(170, 38)
	_reset_btn.pressed.connect(_on_reset_pressed)
	header.add_child(_reset_btn)

	var close_btn := Button.new()
	close_btn.text = "SCHLIESSEN"
	close_btn.custom_minimum_size = Vector2(160, 38)
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 18)
	scroll.add_child(_content)

	PlayerProfile.profile_changed.connect(_on_profile_changed)

func open() -> void:
	_reset_armed = false
	_reset_btn.text = "ZURÜCKSETZEN"
	refresh()
	visible = true

func close() -> void:
	SoundManager.play_sound("click")
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

func _on_profile_changed() -> void:
	if visible:
		refresh()

func _on_reset_pressed() -> void:
	SoundManager.play_sound("click")
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "WIRKLICH?"
		return
	_reset_armed = false
	_reset_btn.text = "ZURÜCKSETZEN"
	PlayerProfile.reset_profile()
	refresh()

func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var player_name := Global.get_player_name(Global.local_player_index)
	_name_label.text = player_name.to_upper()
	var since := PlayerProfile.get_created_at()
	_since_label.text = ("Profil seit %s" % _format_date(since)) if not since.is_empty() else ""

	if PlayerProfile.get_stat("rounds") <= 0.0:
		var empty := Label.new()
		empty.text = "Noch keine Runden gespielt. Nach deiner ersten Runde stehen hier deine Werte über alle Partien."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		_content.add_child(empty)
		_add_achievement_section()
		return

	_content.add_child(_build_tiles())
	_content.add_child(_build_highlights())
	_add_achievement_section()
	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 18)
	tables.add_child(_build_hero_table())
	tables.add_child(_build_card_table())
	_content.add_child(tables)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 18)
	lower.add_child(_build_map_table())
	lower.add_child(_build_history())
	_content.add_child(lower)

# --- Abschnitte ---

func _build_tiles() -> Control:
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var matches := PlayerProfile.get_stat("matches")
	var rounds := PlayerProfile.get_stat("rounds")
	var shots := PlayerProfile.get_stat("shots_fired")
	grid.add_child(_tile("MATCHES", _int(matches), "%s Siege" % _int(PlayerProfile.get_stat("matches_won"))))
	grid.add_child(_tile("SIEGQUOTE", _pct(PlayerProfile.get_match_win_rate()) if matches > 0.0 else "–", "der Matches"))
	grid.add_child(_tile("RUNDEN", _int(rounds), "%s gewonnen" % _int(PlayerProfile.get_stat("rounds_won"))))
	grid.add_child(_tile("K/D", "%.2f" % PlayerProfile.get_kd(), "%s Kills · %s Tode" % [_int(PlayerProfile.get_stat("kills")), _int(PlayerProfile.get_stat("deaths"))], UiTheme.GOLD))
	grid.add_child(_tile("MVP", _int(PlayerProfile.get_stat("mvp")), "Matches als bester Spieler"))
	grid.add_child(_tile("SCHADEN", _int(PlayerProfile.get_stat("damage_dealt")), "%s pro Runde" % _int(PlayerProfile.get_stat("damage_dealt") / maxf(rounds, 1.0))))
	grid.add_child(_tile("TREFFERQUOTE", _pct(PlayerProfile.get_stat("shots_hit") / shots) if shots > 0.0 else "–", "%s Schüsse" % _int(shots)))
	grid.add_child(_tile("HEILUNG", _int(PlayerProfile.get_stat("healing_done")), "%s geblockt" % _int(PlayerProfile.get_stat("damage_blocked"))))
	grid.add_child(_tile("KARTEN", _int(PlayerProfile.get_stat("cards_picked")), "gewählt"))
	grid.add_child(_tile("SPIELZEIT", _duration(PlayerProfile.get_stat("play_time_s")), "in Runden"))
	return grid

func _build_highlights() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var hero_id := PlayerProfile.get_favorite_hero()
	if not hero_id.is_empty():
		var entry: Dictionary = PlayerProfile.get_hero_stats().get(hero_id, {})
		var hero_matches := float(entry.get("matches", 0.0))
		var detail := "%s Runden" % _int(float(entry.get("rounds", 0.0)))
		if hero_matches > 0.0:
			detail += " · %s Siegquote" % _pct(float(entry.get("wins", 0.0)) / hero_matches)
		row.add_child(_highlight("LIEBLINGSHELD", _hero_name(hero_id), detail, UiTheme.CYAN))

	var card_id := PlayerProfile.get_most_picked_card()
	if not card_id.is_empty():
		var card_entry: Dictionary = PlayerProfile.get_card_stats().get(card_id, {})
		var card := CardDatabase.get_card(card_id)
		var color := CardDatabase.get_rarity_color(card.rarity) if card != null else UiTheme.ACCENT
		row.add_child(_highlight("MEISTGEWÄHLTE KARTE", _card_name(card_id), "%s× gewählt" % _int(float(card_entry.get("picks", 0.0))), color))

	var map_id := PlayerProfile.get_favorite_map()
	if not map_id.is_empty():
		var map_entry: Dictionary = PlayerProfile.get_map_stats().get(map_id, {})
		row.add_child(_highlight("LIEBLINGSMAP", Global.get_map_name(map_id), "%s Runden" % _int(float(map_entry.get("rounds", 0.0))), UiTheme.INFO))

	var records := PlayerProfile.get_records()
	var lines: Array[String] = [
		"Meiste Kills in einer Runde: %s" % _int(float(records.get("most_kills_round", 0.0))),
		"Meiste Kills in einem Match: %s" % _int(float(records.get("most_kills_match", 0.0))),
		"Meister Schaden in einem Match: %s" % _int(float(records.get("most_damage_match", 0.0))),
		"Längste Siegesserie: %s (aktuell %s)" % [_int(float(records.get("best_win_streak", 0.0))), _int(float(records.get("win_streak", 0.0)))],
	]
	var rec := _box("REKORDE", UiTheme.GOLD)
	for line in lines:
		rec.get_child(0).add_child(_small_label(line, UiTheme.TEXT_SOFT))
	row.add_child(rec)
	return row

func _add_achievement_section() -> void:
	var manager := get_node_or_null("/root/AchievementManager")
	if manager == null or not manager.has_method("build_profile_section"):
		return
	var section: Variant = manager.call("build_profile_section")
	if not section is Control:
		return
	var box := _box("TITEL & ERFOLGE", UiTheme.ACCENT)
	box.get_child(0).add_child(section)
	_content.add_child(box)

func _build_hero_table() -> Control:
	var rows: Array = []
	var heroes := PlayerProfile.get_hero_stats()
	var ids := heroes.keys()
	ids.sort_custom(func(a, b): return float(heroes[a].get("rounds", 0.0)) > float(heroes[b].get("rounds", 0.0)))
	for id in ids:
		var e: Dictionary = heroes[id]
		var deaths := float(e.get("deaths", 0.0))
		var kills := float(e.get("kills", 0.0))
		var matches := float(e.get("matches", 0.0))
		rows.append([
			_hero_name(str(id)),
			_int(float(e.get("rounds", 0.0))),
			_int(matches),
			_pct(float(e.get("wins", 0.0)) / matches) if matches > 0.0 else "–",
			"%.2f" % (kills / deaths if deaths > 0.0 else kills),
			_int(float(e.get("damage_dealt", 0.0))),
		])
	return _table("HELDEN", ["Held", "Runden", "Matches", "Siege", "K/D", "Schaden"], rows, UiTheme.CYAN)

func _build_card_table() -> Control:
	var rows: Array = []
	var cards := PlayerProfile.get_card_stats()
	var ids := cards.keys()
	ids.sort_custom(func(a, b):
		var pa := float(cards[a].get("picks", 0.0))
		var pb := float(cards[b].get("picks", 0.0))
		if pa == pb:
			return float(cards[a].get("matches", 0.0)) > float(cards[b].get("matches", 0.0))
		return pa > pb)
	for id in ids.slice(0, TOP_CARDS):
		var e: Dictionary = cards[id]
		var matches := float(e.get("matches", 0.0))
		rows.append([
			_card_name(str(id)),
			_int(float(e.get("picks", 0.0))),
			_int(matches),
			_pct(float(e.get("wins", 0.0)) / matches) if matches > 0.0 else "–",
		])
	return _table("KARTEN (TOP %d)" % TOP_CARDS, ["Karte", "Gewählt", "Matches", "Siege"], rows, UiTheme.ACCENT)

func _build_map_table() -> Control:
	var rows: Array = []
	var maps := PlayerProfile.get_map_stats()
	var ids := maps.keys()
	ids.sort_custom(func(a, b): return float(maps[a].get("rounds", 0.0)) > float(maps[b].get("rounds", 0.0)))
	for id in ids.slice(0, TOP_MAPS):
		var e: Dictionary = maps[id]
		var rounds := float(e.get("rounds", 0.0))
		rows.append([
			Global.get_map_name(str(id)),
			_int(rounds),
			_pct(float(e.get("rounds_won", 0.0)) / rounds) if rounds > 0.0 else "–",
			_int(float(e.get("kills", 0.0))),
		])
	return _table("MAPS", ["Map", "Runden", "Gewonnen", "Kills"], rows, UiTheme.INFO)

func _build_history() -> Control:
	var rows: Array = []
	for value in PlayerProfile.get_history():
		if not value is Dictionary:
			continue
		var m: Dictionary = value
		var result := "Sieg" if bool(m.get("won", false)) else ("Remis" if bool(m.get("draw", false)) else "Niederlage")
		if bool(m.get("early", false)):
			result += " (abgebr.)"
		if bool(m.get("mvp", false)):
			result += " · MVP"
		var stats: Dictionary = m.get("stats", {})
		rows.append([
			_format_date(str(m.get("timestamp", ""))),
			_hero_name(str(m.get("hero_id", ""))),
			result,
			"%s/%s" % [_int(float(stats.get("kills", 0.0))), _int(float(stats.get("deaths", 0.0)))],
			"%s/%s" % [int(m.get("rounds_won", 0)), int(m.get("rounds", 0))],
		])
	return _table("LETZTE MATCHES", ["Datum", "Held", "Ergebnis", "K/T", "Runden"], rows, UiTheme.GOLD)

# --- Bausteine ---

func _tile(caption: String, value: String, detail: String, color: Color = UiTheme.TEXT) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _plate_style(Color(UiTheme.CYAN, 0.25)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	box.add_child(_small_label(caption, UiTheme.TEXT_MUTED, UiTheme.FS_XS))
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", UiTheme.FS_XL)
	value_label.add_theme_color_override("font_color", color)
	box.add_child(value_label)
	box.add_child(_small_label(detail, UiTheme.TEXT_DIM, UiTheme.FS_XS))
	return panel

func _highlight(caption: String, value: String, detail: String, color: Color) -> Control:
	var box := _box(caption, color)
	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", UiTheme.FS_XL)
	value_label.add_theme_color_override("font_color", color)
	box.get_child(0).add_child(value_label)
	box.get_child(0).add_child(_small_label(detail, UiTheme.TEXT_SOFT))
	return box

# PanelContainer mit Überschrift; Inhalt in get_child(0) (VBoxContainer).
func _box(caption: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _plate_style(Color(color, 0.45)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var head := Label.new()
	head.text = caption
	head.add_theme_font_size_override("font_size", UiTheme.FS_S)
	head.add_theme_color_override("font_color", color)
	box.add_child(head)
	return panel

func _table(caption: String, columns: Array, rows: Array, color: Color) -> Control:
	var box := _box(caption, color)
	var grid := GridContainer.new()
	grid.columns = columns.size()
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 3)
	box.get_child(0).add_child(grid)
	for i in range(columns.size()):
		var head := _small_label(str(columns[i]), UiTheme.TEXT_MUTED, UiTheme.FS_XS)
		if i == 0:
			head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(head)
	if rows.is_empty():
		box.get_child(0).add_child(_small_label("Noch keine Daten.", UiTheme.TEXT_DIM))
	for row in rows:
		for i in range(row.size()):
			var cell := _small_label(str(row[i]), UiTheme.TEXT if i == 0 else UiTheme.TEXT_SOFT, UiTheme.FS_M)
			if i > 0:
				cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grid.add_child(cell)
	return box

func _small_label(text: String, color: Color, size: int = UiTheme.FS_S) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _plate_style(border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.PLATE
	style.set_border_width_all(1)
	style.border_color = border
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _hero_name(id: String) -> String:
	if id.is_empty() or not Global.heroes.has(id):
		return id if not id.is_empty() else "–"
	return Global.get_hero(id).name

func _card_name(id: String) -> String:
	var card := CardDatabase.get_card(id)
	return card.title if card != null else id

func _int(value: float) -> String:
	var n := int(round(value))
	var text := str(absi(n))
	var out := ""
	while text.length() > 3:
		out = "." + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if n < 0 else "") + text + out

func _pct(ratio: float) -> String:
	return "%d %%" % int(round(ratio * 100.0))

func _duration(seconds: float) -> String:
	var total := int(seconds)
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	if hours > 0:
		return "%d h %02d min" % [hours, minutes]
	return "%d min" % minutes

# "2026-11-22T23:05:00" → "22.11.2026"
func _format_date(iso: String) -> String:
	var date := iso.split("T")[0].split(" ")[0]
	var parts := date.split("-")
	if parts.size() != 3:
		return iso
	return "%s.%s.%s" % [parts[2], parts[1], parts[0]]
