class_name StatsScreen
extends CanvasLayer

# Balance-Statistik im Spiel: zeigt die Auswertung von BalanceReport
# (dieselben Zahlen wie tools/analyze_round_stats.py) als sortierbare
# Tabellen für Karten, Nahkampfwaffen und Helden plus eine Hinweisseite mit
# Aufstiegsvorschlägen, Fingerabdruck-Warnungen und den automatischen
# Aufstiegen aus card_statistics.json. Bleibt die Maus 0,5 s über einer
# Kartenzeile oder einem Kartennamen unter Hinweise, erscheint die Karte unten
# links (mit den aktuellen Werten). Geöffnet über den Knopf STATISTIK im
# Optionsmenü; liest das Protokoll bei jedem Öffnen neu ein.

signal closed

const PERCENT_KEYS: Array[String] = ["win_rate", "peer_rate", "damage_share", "healing_share", "pick_rate", "melee_share", "ability_share"]
# Erst ab Schema 3 im Protokoll; ohne Daten wird "–" angezeigt.
const ABILITY_KEYS: Array[String] = ["ability_per_round", "ability_share"]
const TEXT_KEYS: Array[String] = ["name", "rarity", "suggestion"]
const GOOD: Color = Color(0.45, 1.0, 0.55)
const BAD: Color = Color(1.0, 0.45, 0.45)
const GOLD: Color = Color(1.0, 0.82, 0.3)
const HOVER_DELAY_MSEC: int = 500
const PREVIEW_WIDTH: float = 250.0

# [Schlüssel, Spaltentitel, Mindestbreite, Erklärung]
const CARD_COLUMNS: Array = [
	["name", "Karte", 250, "Kartenname und Version. Grau = ältere Version, die so nicht mehr im Spiel ist."],
	["rarity", "Seltenheit", 110, "Seltenheit, mit der die Karte zuletzt im Protokoll stand."],
	["rounds", "Runden", 80, "Runden, in denen ein Spieler die Karte besaß."],
	["win_rate", "Siegq.", 80, "Geglättete Rundensiegquote: (Siege + 2) / (Runden + 4)."],
	["peer_rate", "Vergl.", 80, "Siegquote aller anderen Karten derselben Seltenheit."],
	["gap", "Diff", 75, "Siegquote minus Vergleichswert, in Prozentpunkten."],
	["kills_per_round", "Kills/R", 80, "Kills pro Runde des Besitzers."],
	["deaths_per_round", "Tode/R", 80, "Tode pro Runde des Besitzers."],
	["damage_share", "Schaden", 85, "Durchschnittlicher Anteil am gesamten Schaden der Runde."],
	["healing_share", "Heilung", 85, "Durchschnittlicher Anteil an der gesamten Heilung der Runde."],
	["melee_per_round", "Nahk./R", 80, "Nahkampfschaden pro Runde des Besitzers."],
	["offers", "Angeb.", 75, "Wie oft die Karte im Draft angeboten wurde."],
	["picks", "Picks", 65, "Wie oft sie dabei gewählt wurde."],
	["pick_rate", "Pickq.", 75, "Picks / Angebote."],
	["suggestion", "Vorschlag", 115, "Vorgeschlagene höhere Seltenheit (genug Runden und mind. 10 Punkte über dem Vergleich)."],
]
const WEAPON_COLUMNS: Array = [
	["name", "Waffe", 260, "Nahkampfwaffe und Version. Grau = ältere Version."],
	["rounds", "Runden", 90, "Runden, in denen ein Spieler die Waffe trug."],
	["win_rate", "Siegq.", 90, "Geglättete Rundensiegquote: (Siege + 2) / (Runden + 4)."],
	["melee_per_round", "Nahk./R", 100, "Nahkampfschaden pro Runde."],
	["melee_share", "Nahk.-Anteil", 120, "Anteil des eigenen Schadens, der aus dem Nahkampf kam."],
	["kills_per_round", "Kills/R", 90, "Kills pro Runde."],
]
const HERO_COLUMNS: Array = [
	["name", "Held", 260, "Held mit Version der Basiswerte (v) und der Fähigkeit (a). Grau = ältere Version."],
	["rounds", "Runden", 90, "Gespielte Runden mit diesem Helden."],
	["win_rate", "Siegq.", 90, "Geglättete Rundensiegquote: (Siege + 2) / (Runden + 4)."],
	["kills_per_round", "Kills/R", 90, "Kills pro Runde."],
	["deaths_per_round", "Tode/R", 90, "Tode pro Runde."],
	["damage_share", "Schaden", 100, "Durchschnittlicher Anteil am gesamten Schaden der Runde."],
	["healing_share", "Heilung", 100, "Durchschnittlicher Anteil an der gesamten Heilung der Runde."],
	["ability_per_round", "Fähigk./R", 100, "Schaden pro Runde durch direkte Treffer der Heldenfähigkeit (inkl. Evolutionen wie Kettenblitz, Blitzzonen, Splitter). Brand und Gift danach zählen nicht. Erst seit 28.10.2026 erfasst."],
	["ability_share", "Fähigk.-Anteil", 130, "Anteil des eigenen Schadens, der aus der Heldenfähigkeit kam. Erst seit 28.10.2026 erfasst."],
]

var humans_only: bool = false
var current_only: bool = false
var min_rounds: int = BalanceReport.DEFAULT_MIN_ROUNDS

var _lines: Array = []
var _invalid_lines: int = 0
var _load_error: String = ""
var _report: BalanceReport = null

var _summary_label: Label = null
var _path_label: Label = null
var _card_tree: Tree = null
var _weapon_tree: Tree = null
var _hero_tree: Tree = null
var _notes: RichTextLabel = null
var _back_btn: Button = null
# Tree -> {"key": Spaltenschlüssel oder "" für Standardreihenfolge, "desc": bool}
var _sort: Dictionary = {}
var _tabs: TabContainer = null
# Kartenvorschau unten links: Kandidat = Karte unter der Maus ("id@vN" oder
# "id"), gezeigt wird sie erst nach HOVER_DELAY_MSEC.
var _preview_column: VBoxContainer = null
var _preview_key: String = ""
var _hover_key: String = ""
var _hover_since_msec: int = 0
var _notes_hover_key: String = ""

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func is_open() -> bool:
	return visible

func open_screen() -> void:
	reload()
	visible = true
	_back_btn.grab_focus()

func close_screen() -> void:
	if not visible:
		return
	visible = false
	_hide_preview()
	closed.emit()

func reload() -> void:
	var result := BalanceReport.read_lines(RoundStats.log_path)
	_lines = result["lines"]
	_invalid_lines = int(result["invalid"])
	_load_error = str(result["error"])
	_rebuild()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SoundManager.play_sound("click")
		close_screen()

# --- Aufbau ---

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
	panel.custom_minimum_size = Vector2(1520, 850)
	panel.add_theme_stylebox_override("panel", WorkshopStyle.panel_box())
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	body.add_child(header)
	var title := Label.new()
	title.text = "STATISTIK"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", WorkshopStyle.CYAN_LIGHT)
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.2, 0.2))
	title.add_theme_constant_override("outline_size", 6)
	header.add_child(title)
	_summary_label = Label.new()
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_summary_label.add_theme_font_size_override("font_size", 16)
	_summary_label.add_theme_color_override("font_color", WorkshopStyle.ACCENT_LIGHT)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_summary_label)

	body.add_child(_build_filter_row())

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 18)
	body.add_child(tabs)
	_tabs = tabs
	_card_tree = _make_tree("Karten", CARD_COLUMNS)
	tabs.add_child(_card_tree)
	_weapon_tree = _make_tree("Waffen", WEAPON_COLUMNS)
	tabs.add_child(_weapon_tree)
	_hero_tree = _make_tree("Helden", HERO_COLUMNS)
	tabs.add_child(_hero_tree)
	_notes = RichTextLabel.new()
	_notes.name = "Hinweise"
	_notes.bbcode_enabled = true
	_notes.scroll_active = true
	_notes.selection_enabled = true
	_notes.add_theme_font_size_override("normal_font_size", 16)
	_notes.add_theme_font_size_override("bold_font_size", 18)
	_notes.add_theme_color_override("default_color", WorkshopStyle.TEXT)
	_notes.meta_hover_started.connect(func(meta: Variant): _notes_hover_key = str(meta))
	_notes.meta_hover_ended.connect(func(_meta: Variant): _notes_hover_key = "")
	tabs.add_child(_notes)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	body.add_child(footer)
	_path_label = Label.new()
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_path_label.add_theme_font_size_override("font_size", 13)
	_path_label.add_theme_color_override("font_color", WorkshopStyle.TEXT_DIM)
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	footer.add_child(_path_label)
	_back_btn = Button.new()
	_back_btn.text = "ZURÜCK"
	_back_btn.custom_minimum_size = Vector2(240, 48)
	WorkshopStyle.style_button(_back_btn, true, 20)
	_back_btn.pressed.connect(func():
		SoundManager.play_sound("confirm")
		close_screen()
	)
	footer.add_child(_back_btn)

	# Linke Spalte über dem ganzen Bildschirm; die Karte sitzt unten darin und
	# lässt die Maus durch, damit das Hovern darunter weiterläuft.
	_preview_column = VBoxContainer.new()
	_preview_column.anchor_bottom = 1.0
	_preview_column.offset_left = 28
	_preview_column.offset_top = 28
	_preview_column.offset_right = 28 + PREVIEW_WIDTH
	_preview_column.offset_bottom = -28
	_preview_column.alignment = BoxContainer.ALIGNMENT_END
	_preview_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview_column)

func _build_filter_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)

	var humans_box := CheckBox.new()
	humans_box.text = "Nur menschliche Spieler"
	humans_box.tooltip_text = "Runden- und Draftzeilen von Bots ignorieren."
	_style_toggle(humans_box)
	humans_box.button_pressed = humans_only
	humans_box.toggled.connect(func(pressed: bool):
		SoundManager.play_sound("click")
		humans_only = pressed
		_rebuild()
	)
	row.add_child(humans_box)

	var current_box := CheckBox.new()
	current_box.text = "Nur aktuelle Versionen"
	current_box.tooltip_text = "Ältere Versionen ausblenden. Sie zählen trotzdem zum Vergleichswert ihrer Seltenheit."
	_style_toggle(current_box)
	current_box.button_pressed = current_only
	current_box.toggled.connect(func(pressed: bool):
		SoundManager.play_sound("click")
		current_only = pressed
		_fill_tables()
	)
	row.add_child(current_box)

	var min_label := Label.new()
	min_label.text = "Mind. Runden für Vorschlag"
	min_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	min_label.add_theme_font_size_override("font_size", 16)
	min_label.add_theme_color_override("font_color", WorkshopStyle.TEXT)
	row.add_child(min_label)
	var min_spin := SpinBox.new()
	min_spin.min_value = 1
	min_spin.max_value = 500
	min_spin.step = 1
	min_spin.value = min_rounds
	min_spin.custom_minimum_size = Vector2(110, 36)
	min_spin.value_changed.connect(func(value: float):
		min_rounds = int(value)
		_rebuild()
	)
	row.add_child(min_spin)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var reload_btn := Button.new()
	reload_btn.text = "NEU LADEN"
	reload_btn.custom_minimum_size = Vector2(170, 40)
	WorkshopStyle.style_button(reload_btn, false, 16)
	reload_btn.pressed.connect(func():
		SoundManager.play_sound("click")
		reload()
	)
	row.add_child(reload_btn)
	return row

func _style_toggle(box: CheckBox) -> void:
	box.add_theme_font_size_override("font_size", 16)
	box.add_theme_color_override("font_color", WorkshopStyle.TEXT)
	box.add_theme_color_override("font_hover_color", Color.WHITE)
	box.add_theme_color_override("font_pressed_color", WorkshopStyle.CYAN_LIGHT)

func _make_tree(tab_name: String, columns: Array) -> Tree:
	var tree := Tree.new()
	tree.name = tab_name
	tree.columns = columns.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_theme_font_size_override("font_size", 15)
	tree.add_theme_font_size_override("title_button_font_size", 15)
	tree.add_theme_color_override("font_color", WorkshopStyle.TEXT)
	tree.add_theme_color_override("title_button_color", WorkshopStyle.CYAN_LIGHT)
	tree.add_theme_stylebox_override("panel", WorkshopStyle.neon_box(WorkshopStyle.PLATE, Color(WorkshopStyle.CYAN.r, WorkshopStyle.CYAN.g, WorkshopStyle.CYAN.b, 0.35), 1, 4))
	tree.add_theme_constant_override("v_separation", 6)
	for i in range(columns.size()):
		var column: Array = columns[i]
		tree.set_column_title(i, str(column[1]))
		tree.set_column_title_tooltip_text(i, str(column[3]) + "\nKlicken zum Sortieren.")
		tree.set_column_custom_minimum_width(i, int(column[2]))
		tree.set_column_expand(i, i == 0)
		tree.set_column_clip_content(i, i == 0)
		if not TEXT_KEYS.has(str(column[0])):
			tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_RIGHT)
	tree.set_meta("columns", columns)
	_sort[tree] = {"key": "", "desc": false}
	tree.column_title_clicked.connect(_on_column_title_clicked.bind(tree))
	return tree

# --- Inhalt ---

func _rebuild() -> void:
	_report = BalanceReport.build(_lines, humans_only, min_rounds)
	var path := RoundStats.get_log_path()
	_path_label.text = "Quelle: %s" % path
	if not _load_error.is_empty():
		_summary_label.text = _load_error
	else:
		var parts: PackedStringArray = [
			"%d Runden" % _report.round_count,
			"%d Drafts" % _report.draft_count,
			"%d Karten(-Versionen)" % _report.cards.size(),
		]
		var suggestion_count := _report.get_suggestions().size()
		if suggestion_count > 0:
			parts.append("%d Aufstiegsvorschläge" % suggestion_count)
		if _invalid_lines > 0:
			parts.append("%d kaputte Zeilen übersprungen" % _invalid_lines)
		_summary_label.text = " · ".join(parts)
	_fill_tables()
	_fill_notes()

func _fill_tables() -> void:
	if _report == null:
		return
	_fill_tree(_card_tree, _report.cards)
	_fill_tree(_weapon_tree, _report.weapons)
	_fill_tree(_hero_tree, _report.heroes)

func _fill_tree(tree: Tree, source_rows: Array) -> void:
	var columns: Array = tree.get_meta("columns")
	var rows: Array = []
	for row in source_rows:
		if current_only and not bool(row["current"]):
			continue
		rows.append(row)
	var sort_state: Dictionary = _sort[tree]
	var sort_key := str(sort_state["key"])
	if not sort_key.is_empty():
		var desc := bool(sort_state["desc"])
		var text_sort := TEXT_KEYS.has(sort_key)
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var a_value: Variant = _sort_value(a, sort_key)
			var b_value: Variant = _sort_value(b, sort_key)
			if a_value == b_value:
				return str(a["key"]) < str(b["key"])
			if text_sort:
				return (str(a_value).naturalnocasecmp_to(str(b_value)) > 0) == desc
			return (float(a_value) > float(b_value)) == desc
		)
	for i in range(columns.size()):
		var title := str(columns[i][1])
		if str(columns[i][0]) == sort_key:
			title += " ▼" if bool(sort_state["desc"]) else " ▲"
		tree.set_column_title(i, title)

	tree.clear()
	var rounds_column := 0
	for i in range(columns.size()):
		if str(columns[i][0]) == "rounds":
			rounds_column = i
	var root := tree.create_item()
	if rows.is_empty():
		var empty := tree.create_item(root)
		empty.set_text(0, "Keine Daten." if _load_error.is_empty() else _load_error)
		empty.set_custom_color(0, WorkshopStyle.TEXT_DIM)
		return
	for row in rows:
		var item := tree.create_item(root)
		var old := not bool(row["current"])
		var thin := int(row["rounds"]) < min_rounds
		for i in range(columns.size()):
			var key := str(columns[i][0])
			item.set_text(i, _cell_text(row, key))
			if not TEXT_KEYS.has(key):
				item.set_text_alignment(i, HORIZONTAL_ALIGNMENT_RIGHT)
			var color := _cell_color(row, key)
			if old:
				color = WorkshopStyle.TEXT_DIM
			item.set_custom_color(i, color)
		item.set_tooltip_text(0, _row_tooltip(row, old, thin))
		if tree == _card_tree:
			item.set_metadata(0, str(row["key"]))
		if thin:
			item.set_tooltip_text(rounds_column, "Weniger als %d Runden: die Werte sind noch unsicher." % min_rounds)

func _sort_value(row: Dictionary, key: String) -> Variant:
	if key == "name":
		return "%s %03d %03d" % [str(row["name"]), int(row["version"]), int(row.get("ability_version", 0))]
	if key == "rarity":
		return "%d" % BalanceReport.RARITY_ORDER.find(str(row["rarity"]))
	if key == "suggestion":
		return "%d" % (BalanceReport.RARITY_ORDER.find(str(row["suggestion"])) + 1)
	return row.get(key, 0)

func _cell_text(row: Dictionary, key: String) -> String:
	var value: Variant = row.get(key, "")
	if ABILITY_KEYS.has(key) and int(row.get("ability_rounds", 0)) <= 0:
		return "–"
	match key:
		"name":
			var version := "v%d" % int(row["version"])
			if row.has("ability_version"):
				version += "/a%d" % int(row["ability_version"])
			return "%s  %s%s" % [str(row["name"]), version, "" if bool(row["current"]) else " (alt)"]
		"suggestion":
			return "" if str(value).is_empty() else "→ " + str(value)
		"gap":
			return "%+d" % roundi(float(value) * 100.0)
		"kills_per_round", "deaths_per_round":
			return "%.2f" % float(value)
		"melee_per_round", "ability_per_round":
			return "%.1f" % float(value)
	if PERCENT_KEYS.has(key):
		return "%d %%" % roundi(float(value) * 100.0)
	return str(value)

func _cell_color(row: Dictionary, key: String) -> Color:
	match key:
		"rarity":
			return CardDatabase.get_rarity_color(str(row["rarity"]))
		"suggestion":
			return GOLD
		"gap":
			var gap := float(row["gap"])
			if gap >= BalanceReport.PROMOTION_GAP:
				return GOOD
			if gap <= -BalanceReport.PROMOTION_GAP:
				return BAD
		"rounds":
			if int(row["rounds"]) < min_rounds:
				return WorkshopStyle.TEXT_DIM
	return WorkshopStyle.TEXT

func _row_tooltip(row: Dictionary, old: bool, thin: bool) -> String:
	var lines: PackedStringArray = [str(row["key"])]
	lines.append("Siege: %d von %d Runden" % [int(row["wins"]), int(row["rounds"])])
	if old:
		lines.append("Ältere Version, aktuell gelten andere Werte.")
	if thin:
		lines.append("Weniger als %d Runden: die Werte sind noch unsicher." % min_rounds)
	if int(row["fingerprints"]) > 1:
		lines.append("Achtung: Werte wurden ohne neue Version geändert (%d Fingerabdrücke)." % int(row["fingerprints"]))
	return "\n".join(lines)

func _fill_notes() -> void:
	var text := ""
	if not _load_error.is_empty():
		text += "[color=#%s]%s[/color]\n\n" % [WorkshopStyle.ACCENT_LIGHT.to_html(false), _escape(_load_error)]

	var gold := GOLD.to_html(false)
	text += "[b]Aufstiegsvorschläge[/b]  (mind. %d Runden, mind. %d Punkte über dem Vergleich)\n" \
		% [min_rounds, roundi(BalanceReport.PROMOTION_GAP * 100.0)]
	var suggestions := _report.get_suggestions()
	if suggestions.is_empty():
		text += "  Keine.\n"
	for row in suggestions:
		text += "  [url=%s][color=#%s]%s[/color][/url] (%s): %s → %s, Siegquote %d %% gegen %d %%\n" % [
			str(row["key"]), gold, _escape(str(row["name"])), str(row["key"]), str(row["rarity"]), str(row["suggestion"]),
			roundi(float(row["win_rate"]) * 100.0), roundi(float(row["peer_rate"]) * 100.0),
		]

	text += "\n[b]Werte ohne neue Version geändert[/b]\n"
	if _report.fingerprint_warnings.is_empty():
		text += "  Keine. Alle Versionen haben eindeutige Werte.\n"
	else:
		text += "  Diese Einträge haben mehrere Fingerabdrücke, ihre Zahlen mischen alte und neue Werte. Version erhöhen (README „Balance-Versionen“).\n"
		for key in _report.fingerprint_warnings:
			var line := "[color=#%s]%s[/color]" % [BAD.to_html(false), _escape(key)]
			if CardDatabase.get_card(key.get_slice("@", 0)) != null:
				line = "[url=%s]%s[/url]" % [key, line]
			text += "  %s\n" % line

	text += "\n[b]Automatische Aufstiege im Spiel[/b]  (card_statistics.json, neueste zuerst)\n"
	var promotions := CardStats.get_promotion_log()
	if promotions.is_empty():
		text += "  Noch keine.\n"
	promotions.reverse()
	for entry in promotions.slice(0, 20):
		text += "  [url=%s]%s[/url]: %s → %s nach Match %d (Siegquote %d %% gegen %d %%)\n" % [
			str(entry.get("card_id", "")), _escape(str(entry.get("title", entry.get("card_id", "?")))), str(entry.get("from", "")), str(entry.get("to", "")),
			int(entry.get("at_match", 0)), roundi(float(entry.get("win_rate", 0.0)) * 100.0),
			roundi(float(entry.get("peer_win_rate", 0.0)) * 100.0),
		]

	text += "\n[b]So wird gerechnet[/b]\n"
	text += "  Grundlage ist jede fertig gespielte Runde (offline oder als Host). Eine Karte zählt in jeder Runde, in der ihr Besitzer sie hatte.\n"
	text += "  Siegquoten sind geglättet: (Siege + 2) / (Runden + 4), damit wenige Runden keine 0 % oder 100 % ergeben.\n"
	text += "  Vergleich = Siegquote aller anderen Karten derselben Seltenheit. Die Tabellen lassen sich per Klick auf die Spaltenköpfe sortieren.\n"
	text += "  Grau = ältere Version (v = Werte, a = Heldenfähigkeit). Dieselbe Auswertung liefert tools/analyze_round_stats.py.\n"
	text += "  Maus kurz über eine Kartenzeile oder einen Kartennamen halten: die Karte erscheint unten links.\n"
	_notes_hover_key = ""
	_notes.text = text
	_notes.scroll_to_line(0)

func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

func _on_column_title_clicked(column: int, mouse_button_index: int, tree: Tree) -> void:
	if mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	SoundManager.play_sound("click")
	var columns: Array = tree.get_meta("columns")
	var key := str(columns[column][0])
	var state: Dictionary = _sort[tree]
	if str(state["key"]) == key:
		state["desc"] = not bool(state["desc"])
	else:
		state["key"] = key
		# Zahlen zuerst absteigend (beste oben), Text alphabetisch.
		state["desc"] = not TEXT_KEYS.has(key)
	_fill_tables()

# --- Kartenvorschau ---

func _process(_delta: float) -> void:
	if not visible:
		return
	# Echte Zeit statt delta, damit Zeitlupe (Kill-Cam) die Verzögerung nicht streckt.
	var key := _hovered_card_key()
	if key != _hover_key:
		_hover_key = key
		_hover_since_msec = Time.get_ticks_msec()
	if key.is_empty():
		_hide_preview()
	elif key != _preview_key and Time.get_ticks_msec() - _hover_since_msec >= HOVER_DELAY_MSEC:
		_show_preview(key)

func _hovered_card_key() -> String:
	var current := _tabs.get_current_tab_control()
	if current == _notes:
		return _notes_hover_key
	if current != _card_tree:
		return ""
	var local := _card_tree.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _card_tree.size).has_point(local):
		return ""
	var item := _card_tree.get_item_at_position(local)
	if item == null:
		return ""
	var meta: Variant = item.get_metadata(0)
	return "" if meta == null else str(meta)

func _show_preview(key: String) -> void:
	_hide_preview()
	var card := CardDatabase.get_card(key.get_slice("@", 0))
	if card == null:
		return
	_preview_key = key
	# "id@vN": gezeigt werden immer die aktuellen Werte, also ggf. darauf hinweisen.
	var shown_version := int(key.get_slice("@v", 1)) if key.contains("@v") else card.version
	var preview := _build_card_preview(card, shown_version)
	_ignore_mouse(preview)
	_preview_column.add_child(preview)

func _hide_preview() -> void:
	_preview_key = ""
	if _preview_column == null:
		return
	for child in _preview_column.get_children():
		child.queue_free()

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

# Nachbau der Draft-Karte (CardDraftUI._create_card_button) ohne Knopf.
func _build_card_preview(card: CardData, shown_version: int) -> Control:
	var rarity_color := CardDatabase.get_rarity_color(card.rarity)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PREVIEW_WIDTH, 0)
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	outer_style.set_corner_radius_all(12)
	outer_style.set_border_width_all(5)
	outer_style.border_color = rarity_color
	outer_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	outer_style.shadow_size = 12
	outer_style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", outer_style)

	var inner := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = Color(0.13, 0.15, 0.20, 0.98)
	inner_style.set_corner_radius_all(8)
	inner_style.set_border_width_all(2)
	inner_style.border_color = card.color
	inner_style.set_content_margin_all(10)
	inner.add_theme_stylebox_override("panel", inner_style)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	inner.add_child(vbox)

	var top_row := HBoxContainer.new()
	var card_icon := CardIcon.new()
	card_icon.setup(card, 38.0)
	top_row.add_child(card_icon)
	var rarity_label := Label.new()
	rarity_label.text = card.rarity.to_upper()
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rarity_label.add_theme_color_override("font_color", rarity_color)
	top_row.add_child(rarity_label)
	vbox.add_child(top_row)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 11)
	if evolution_banner != null:
		vbox.add_child(evolution_banner)

	var class_badge := CardMechanics.make_class_badge(card, 12)
	if class_badge != null:
		vbox.add_child(class_badge)

	var title := _preview_label(card.title, 16, Color.WHITE)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	vbox.add_child(_preview_label(CardMechanics.format_description(card.description), 13, WorkshopStyle.TEXT))

	var unlock_label := CardMechanics.make_unlock_label(card, 11)
	if unlock_label != null:
		vbox.add_child(unlock_label)
	var evolutions_preview := CardMechanics.make_evolutions_preview(card, 11)
	if evolutions_preview != null:
		vbox.add_child(evolutions_preview)

	if shown_version != card.version:
		vbox.add_child(_preview_label("Zeile = v%d, Karte zeigt die aktuellen Werte (v%d)." % [shown_version, card.version], 11, WorkshopStyle.TEXT_DIM))
	return panel

func _preview_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
