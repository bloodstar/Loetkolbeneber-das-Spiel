class_name ArenaMapEditor
extends CanvasLayer

# Karteneditor für Arena-Karten (Optionen → KARTENEDITOR). Malt das
# Zeichenraster aus ArenaMaps (Boden, Deckung, Mauern, Kisten, Spawns,
# Erhöhungen, Stege, Rampen) und schräge Wände, speichert als JSON unter
# user://arena_maps und startet auf Wunsch eine Testrunde mit Bots.
#
# Maus: links malen, rechts radieren, Mausrad zoomen, mittlere Taste oder
# Leertaste + Ziehen verschiebt die Ansicht.
# Tasten: B Pinsel, R Rechteck, F Füllen, W schräge Wand, Strg+Z / Strg+Y.

signal closed
signal test_requested(map_id: String)
signal side_editor_requested

const MIN_W := 12
const MAX_W := 120
const MIN_H := 10
const MAX_H := 80
const UNDO_LIMIT := 80
const RAMP_CHARS := {"E": ">", "W": "<", "N": "^", "S": "v"}

# Palette: Zeichen, Name, Farbe im Editor, Kurz-Hinweis
const PALETTE := [
	[".", "Boden", Color(0.30, 0.42, 0.26), "Freie Fläche"],
	["c", "Deckung", Color(0.62, 0.52, 0.38), "1 Schicht hoch, überspringbar, begehbar"],
	["H", "Halbmauer", Color(0.55, 0.55, 0.58), "2 Schichten, nur mit viel Sprungkraft"],
	["#", "Mauer", Color(0.36, 0.36, 0.40), "3 Schichten, blockt alles"],
	["x", "Kiste", Color(0.85, 0.55, 0.22), "Zerstörbar, 1 Schicht"],
	["S", "Spawn", Color(0.25, 0.85, 0.95), "Startpunkt, mindestens 2"],
	["p", "Erhöhung 1", Color(0.48, 0.62, 0.32), "Gelände 1 Schicht hoch (hochspringen)"],
	["P", "Erhöhung 2", Color(0.62, 0.74, 0.38), "Gelände 2 Schichten (Rampe nötig)"],
	["T", "Erhöhung 3", Color(0.76, 0.84, 0.48), "Gelände 3 Schichten (Rampe nötig)"],
	["=", "Steg", Color(0.62, 0.42, 0.22), "Holzsteg auf Höhe 3, darunter frei"],
	["R", "Rampe", Color(0.70, 0.66, 0.50), "Reihe in Steigrichtung, von Boden/Stufe zur Erhöhung"],
]
const WALL_HEIGHTS := [["#", "hoch"], ["H", "halb"], ["c", "niedrig"]]
const THEMES := [
	["Wiese", "arena_steppe"], ["Pflaster", "arena_marktplatz"], ["Canyon", "arena_canyon"],
	["Burghof", "arena_hof"], ["Hochplateau", "arena_plateau"], ["Stegwerk", "arena_stegwerk"],
]
const FLOOR_TEXES := ["grass", "sand", "cobble"]
const WALL_TEXES := ["brick", "rock"]
const SYM_NAMES := ["Aus", "Links ↔ Rechts", "Oben ↔ Unten", "Vierfach", "Punkt (180°)"]

# Zuletzt bearbeitete Karte bleibt über Testrunden hinweg erhalten.
static var _last_state: Dictionary = {}

var map_id: String = ""
var meta: Dictionary = {}
var cells: Array = [] # Array von Arrays mit Ein-Zeichen-Strings
var walls: Array = []
var map_w: int = 0
var map_h: int = 0

var tool: String = "brush"
var paint_char: String = "#"
var ramp_dir: String = "E"
var wall_height: String = "#"
var brush_size: int = 1
var symmetry: int = 0

var _undo: Array = []
var _redo: Array = []
var _dirty: bool = false

var _canvas: Control
var _zoom: float = 16.0
var _pan: Vector2 = Vector2(20, 20)
var _painting: bool = false
var _erasing: bool = false
var _panning: bool = false
var _drag_start: Vector2i = Vector2i(-1, -1)
var _wall_start: Vector2i = Vector2i(-1, -1)
var _hover: Vector2i = Vector2i(-1, -1)
var _hover_corner: Vector2i = Vector2i(-1, -1)
var _space_down: bool = false
var _stroke_open: bool = false

var _name_edit: LineEdit
var _w_spin: SpinBox
var _h_spin: SpinBox
var _pool_check: CheckBox
var _floor_tex_opt: OptionButton
var _wall_tex_opt: OptionButton
var _floor_col: ColorPickerButton
var _wall_col: ColorPickerButton
var _load_opt: OptionButton
var _delete_btn: Button
var _status: Label
var _info: Label
var _palette_btns: Dictionary = {}
var _tool_btns: Dictionary = {}
var _ramp_btns: Dictionary = {}
var _wallh_btns: Dictionary = {}
var _brush_opt: OptionButton
var _sym_opt: OptionButton
var _delete_armed: bool = false

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func is_open() -> bool:
	return visible

func open_editor() -> void:
	if _last_state.is_empty():
		_new_map()
	else:
		_restore_state(_last_state)
	_refresh_load_list()
	_sync_controls()
	visible = true
	_fit_view()
	_validate()

func close_editor() -> void:
	_store_state()
	visible = false
	closed.emit()

# --- Karte ---------------------------------------------------------------

func _new_map(w: int = 48, h: int = 30) -> void:
	map_id = ""
	meta = {"name": "Neue Karte", "description": "Eigene Karte aus dem Karteneditor.", "in_pool": false}
	_apply_theme_from("arena_steppe")
	map_w = w
	map_h = h
	cells = []
	for y in range(h):
		var row: Array = []
		row.resize(w)
		row.fill(".")
		cells.append(row)
	walls = []
	cells[h / 2][3] = "S"
	cells[h / 2][w - 4] = "S"
	_undo.clear()
	_redo.clear()
	_dirty = false

func _apply_theme_from(src_id: String) -> void:
	var src := ArenaMaps.get_map(src_id)
	for k in ["floor", "wall", "cliff", "top", "accent", "floor_tex", "wall_tex", "top_tex"]:
		if src.has(k):
			meta[k] = src[k]
		else:
			meta.erase(k)

func _load_map(id: String, as_copy: bool) -> void:
	var data := ArenaMaps.get_map(id)
	if data.is_empty():
		return
	meta = {}
	for k in data.keys():
		if k != "rows" and k != "walls":
			meta[k] = data[k]
	var rows: Array = data.get("rows", [])
	map_h = rows.size()
	map_w = 0
	for r in rows:
		map_w = maxi(map_w, str(r).length())
	cells = []
	for r in rows:
		var row: Array = []
		var text := str(r)
		for x in range(map_w):
			row.append(text[x] if x < text.length() else ".")
		cells.append(row)
	walls = []
	for wl in data.get("walls", []):
		walls.append([int(wl[0]), int(wl[1]), int(wl[2]), int(wl[3]), str(wl[4]) if wl.size() > 4 else "#"])
	if as_copy:
		map_id = ""
		meta["name"] = "%s Kopie" % str(data.get("name", id))
		meta["in_pool"] = false
	else:
		map_id = id
	_undo.clear()
	_redo.clear()
	_dirty = false
	_sync_controls()
	_fit_view()
	_validate()

func to_data() -> Dictionary:
	var data := meta.duplicate(true)
	var rows: Array = []
	for row in cells:
		rows.append("".join(PackedStringArray(row)))
	data["rows"] = rows
	var wl: Array = []
	for w in walls:
		wl.append(w.duplicate())
	data["walls"] = wl
	return data

func _store_state() -> void:
	_last_state = {"id": map_id, "data": to_data(), "dirty": _dirty}

func _restore_state(st: Dictionary) -> void:
	var data: Dictionary = st["data"]
	ArenaMaps.custom["__editor_tmp"] = data
	_load_map("__editor_tmp", false)
	ArenaMaps.custom.erase("__editor_tmp")
	map_id = str(st.get("id", ""))
	_dirty = bool(st.get("dirty", false))

func _resize(w: int, h: int) -> void:
	_push_undo()
	var new_cells: Array = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(cells[y][x] if y < map_h and x < map_w else ".")
		new_cells.append(row)
	cells = new_cells
	map_w = w
	map_h = h
	var kept: Array = []
	for wl in walls:
		if maxi(wl[0], wl[2]) <= w and maxi(wl[1], wl[3]) <= h:
			kept.append(wl)
	walls = kept
	_changed()
	_fit_view()

# --- Undo ------------------------------------------------------------------

func _snapshot() -> Dictionary:
	var c: Array = []
	for row in cells:
		c.append(row.duplicate())
	var wl: Array = []
	for w in walls:
		wl.append(w.duplicate())
	return {"cells": c, "walls": wl, "w": map_w, "h": map_h}

func _apply_snapshot(s: Dictionary) -> void:
	cells = s["cells"]
	walls = s["walls"]
	map_w = s["w"]
	map_h = s["h"]
	_sync_controls()
	_changed()

func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	_apply_snapshot(_undo.pop_back())

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	_apply_snapshot(_redo.pop_back())

func _changed() -> void:
	_dirty = true
	_validate()
	if _canvas:
		_canvas.queue_redraw()

# --- Malen -------------------------------------------------------------------

func _current_char() -> String:
	if paint_char == "R":
		return RAMP_CHARS[ramp_dir]
	return paint_char

func _in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < map_w and c.y < map_h

## Zeichen für eine gespiegelte Kopie (Rampen drehen ihre Richtung mit).
static func _mirror_char(ch: String, flip_x: bool, flip_y: bool) -> String:
	if flip_x:
		if ch == ">":
			ch = "<"
		elif ch == "<":
			ch = ">"
	if flip_y:
		if ch == "^":
			ch = "v"
		elif ch == "v":
			ch = "^"
	return ch

## Alle Symmetrie-Kopien einer Zelle: [Zelle, flip_x, flip_y].
func _sym_cells(c: Vector2i) -> Array:
	var out := [[c, false, false]]
	var mx := map_w - 1 - c.x
	var my := map_h - 1 - c.y
	match symmetry:
		1:
			out.append([Vector2i(mx, c.y), true, false])
		2:
			out.append([Vector2i(c.x, my), false, true])
		3:
			out.append([Vector2i(mx, c.y), true, false])
			out.append([Vector2i(c.x, my), false, true])
			out.append([Vector2i(mx, my), true, true])
		4:
			out.append([Vector2i(mx, my), true, true])
	return out

func _set_cell(c: Vector2i, ch: String) -> void:
	for s in _sym_cells(c):
		var sc: Vector2i = s[0]
		if _in_map(sc):
			cells[sc.y][sc.x] = _mirror_char(ch, s[1], s[2])

func _paint_at(c: Vector2i, ch: String) -> void:
	var r := brush_size - 1
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var p := c + Vector2i(dx, dy)
			if _in_map(p):
				_set_cell(p, ch)

func _fill_rect(a: Vector2i, b: Vector2i, ch: String) -> void:
	for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			if _in_map(Vector2i(x, y)):
				_set_cell(Vector2i(x, y), ch)

func _flood(start: Vector2i, ch: String) -> void:
	if not _in_map(start):
		return
	var from: String = cells[start.y][start.x]
	if from == ch:
		return
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		_set_cell(c, ch)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if _in_map(n) and not seen.has(n) and cells[n.y][n.x] == from:
				seen[n] = true
				queue.append(n)

func _add_wall(a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	var copies := [[a, b]]
	match symmetry:
		1:
			copies.append([Vector2i(map_w - a.x, a.y), Vector2i(map_w - b.x, b.y)])
		2:
			copies.append([Vector2i(a.x, map_h - a.y), Vector2i(b.x, map_h - b.y)])
		3:
			copies.append([Vector2i(map_w - a.x, a.y), Vector2i(map_w - b.x, b.y)])
			copies.append([Vector2i(a.x, map_h - a.y), Vector2i(b.x, map_h - b.y)])
			copies.append([Vector2i(map_w - a.x, map_h - a.y), Vector2i(map_w - b.x, map_h - b.y)])
		4:
			copies.append([Vector2i(map_w - a.x, map_h - a.y), Vector2i(map_w - b.x, map_h - b.y)])
	for cp in copies:
		var p: Vector2i = cp[0]
		var q: Vector2i = cp[1]
		var dup := false
		for w in walls:
			if (Vector2i(w[0], w[1]) == p and Vector2i(w[2], w[3]) == q) or (Vector2i(w[0], w[1]) == q and Vector2i(w[2], w[3]) == p):
				dup = true
		if not dup:
			walls.append([p.x, p.y, q.x, q.y, wall_height])

func _remove_wall_near(pos_tiles: Vector2) -> bool:
	var best := -1
	var best_d := 0.6
	for i in range(walls.size()):
		var w: Array = walls[i]
		var d := pos_tiles.distance_to(Geometry2D.get_closest_point_to_segment(pos_tiles, Vector2(w[0], w[1]), Vector2(w[2], w[3])))
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return false
	walls.remove_at(best)
	return true

# --- Prüfung -----------------------------------------------------------------

func _validate() -> void:
	if _info == null:
		return
	var spawns: Array[Vector2i] = []
	for y in range(map_h):
		for x in range(map_w):
			if cells[y][x] == "S":
				spawns.append(Vector2i(x, y))
	var lines: Array[String] = []
	lines.append("%d × %d Kacheln, %d Spawns, %d schräge Wände" % [map_w, map_h, spawns.size(), walls.size()])
	var ok := true
	if spawns.size() < 2:
		lines.append("⚠ Mindestens 2 Spawns setzen.")
		ok = false
	else:
		var grid := ArenaBuilder.build_grid(to_data())
		var reached := _reachable(grid, spawns[0])
		var missing := 0
		for s in spawns:
			if not reached.has(s):
				missing += 1
		if missing > 0:
			lines.append("⚠ %d Spawn(s) vom ersten Spawn aus nicht erreichbar." % missing)
			ok = false
	var bad_ramps := _ramp_problems()
	if bad_ramps > 0:
		lines.append("⚠ %d Rampe(n) führen nicht höher (Ende ohne Erhöhung)." % bad_ramps)
	if ok:
		lines.append("✓ Alle Spawns erreichbar.")
	_info.text = "\n".join(lines)
	_info.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75) if ok and bad_ramps == 0 else Color(1.0, 0.8, 0.45))

## Erreichbare Zellen wie bei der Bot-Wegsuche (laufen, Rampen, 1 Schicht springen).
func _reachable(grid: ArenaGrid, start: Vector2i) -> Dictionary:
	var height := {start: 0.0}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if height.has(n):
				continue
			var nz := grid.reach_height(n, float(height[c]), ArenaBot.JUMPABLE_TOP)
			if nz < 0.0:
				continue
			height[n] = nz
			queue.append(n)
	return height

func _ramp_problems() -> int:
	var count := 0
	for y in range(map_h):
		for x in range(map_w):
			var ch: String = cells[y][x]
			if not ArenaMaps.RAMP_DIRS.has(ch):
				continue
			var d: Vector2i = ArenaMaps.RAMP_DIRS[ch]
			var nxt := Vector2i(x, y) + d
			if _in_map(nxt) and cells[nxt.y][nxt.x] == ch:
				continue
			var top_ch: String = cells[nxt.y][nxt.x] if _in_map(nxt) else "."
			if not ArenaMaps.BLOCK_HEIGHTS.has(top_ch) or ArenaMaps.BLOCK_BOTTOMS.has(top_ch) or top_ch == "x":
				count += 1
	return count

# --- Speichern / Laden ---------------------------------------------------------

func _save() -> bool:
	meta["name"] = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else "Eigene Karte"
	if map_id.is_empty() or not ArenaMaps.is_custom(map_id):
		map_id = ArenaMaps.make_custom_id(str(meta["name"]))
	var err := ArenaMaps.save_custom(map_id, to_data())
	if err != OK:
		_set_status("Speichern fehlgeschlagen (Fehler %d)." % err, true)
		return false
	_dirty = false
	_refresh_load_list()
	_set_status("Gespeichert als %s." % map_id.trim_prefix(ArenaMaps.CUSTOM_PREFIX), false)
	return true

func _refresh_load_list() -> void:
	if _load_opt == null:
		return
	_load_opt.clear()
	for id in ArenaMaps.custom_ids():
		if id.begins_with("__"):
			continue
		_load_opt.add_item(ArenaMaps.display_name(id))
		_load_opt.set_item_metadata(_load_opt.item_count - 1, {"id": id, "copy": false})
	for id in ArenaMaps.MAP_IDS:
		_load_opt.add_item("Vorlage: %s" % ArenaMaps.display_name(id))
		_load_opt.set_item_metadata(_load_opt.item_count - 1, {"id": id, "copy": true})

func _set_status(text: String, error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if error else Color(0.8, 0.9, 1.0))

# --- Oberfläche --------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(330, 0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(side_scroll)
	var side_margin := MarginContainer.new()
	side_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "top", "bottom"]:
		side_margin.add_theme_constant_override("margin_" + m, 12)
	side_scroll.add_child(side_margin)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side_margin.add_child(side)

	var title := Label.new()
	title.text = "KARTENEDITOR (ARENA)"
	title.add_theme_font_size_override("font_size", UiTheme.FS_XL)
	title.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	side.add_child(title)
	var top_row := HBoxContainer.new()
	side.add_child(top_row)
	var test_btn := _button("TESTEN", func(): _on_test(), true)
	test_btn.tooltip_text = "Speichert und startet eine Arena-Runde auf dieser Karte (Spieler und Bots wie in der letzten Lobby). ESC → Hauptmenü beendet den Test."
	test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(test_btn)
	var close_btn := _button("SCHLIESSEN", func(): close_editor())
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(close_btn)
	side.add_child(_button("Zum Seitenansicht-Editor", func():
		_store_state()
		visible = false
		side_editor_requested.emit()
	))

	# Datei
	_section(side, "Karte")
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name der Karte"
	_name_edit.text_changed.connect(func(t): meta["name"] = t; _dirty = true)
	side.add_child(_name_edit)
	var load_row := HBoxContainer.new()
	side.add_child(load_row)
	_load_opt = OptionButton.new()
	_load_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_load_opt.clip_text = true
	load_row.add_child(_load_opt)
	load_row.add_child(_button("Laden", func():
		if _load_opt.selected < 0:
			return
		var md: Dictionary = _load_opt.get_item_metadata(_load_opt.selected)
		_load_map(str(md["id"]), bool(md["copy"]))
		_set_status("Vorlage geladen. Speichern legt eine eigene Karte an." if md["copy"] else "Geladen.", false)
	))
	var file_row := HBoxContainer.new()
	side.add_child(file_row)
	file_row.add_child(_button("Neu", func():
		_push_undo()
		_new_map(int(_w_spin.value), int(_h_spin.value))
		_sync_controls()
		_fit_view()
		_validate()
		_set_status("Neue Karte.", false)
	))
	file_row.add_child(_button("Speichern", func(): _save(), true))
	_delete_btn = _button("Löschen", func(): _on_delete())
	file_row.add_child(_delete_btn)
	_pool_check = CheckBox.new()
	_pool_check.text = "Im Zufallspool der Arena"
	_pool_check.tooltip_text = "Gespeicherte Karten mit Haken kommen in die zufällige Kartenauswahl der Arena (online schickt der Host die Karte mit)."
	_pool_check.toggled.connect(func(on): meta["in_pool"] = on; _dirty = true)
	side.add_child(_pool_check)

	# Größe und Aussehen
	_section(side, "Größe und Aussehen")
	var size_row := HBoxContainer.new()
	side.add_child(size_row)
	_w_spin = _spin(MIN_W, MAX_W)
	_h_spin = _spin(MIN_H, MAX_H)
	size_row.add_child(_small_label("B"))
	size_row.add_child(_w_spin)
	size_row.add_child(_small_label("H"))
	size_row.add_child(_h_spin)
	size_row.add_child(_button("Ändern", func():
		_resize(int(_w_spin.value), int(_h_spin.value))
	))
	var theme_row := HBoxContainer.new()
	side.add_child(theme_row)
	theme_row.add_child(_small_label("Stil"))
	var theme_opt := OptionButton.new()
	theme_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in THEMES:
		theme_opt.add_item(t[0])
	theme_opt.item_selected.connect(func(i):
		_apply_theme_from(THEMES[i][1])
		_sync_controls()
		_dirty = true
	)
	theme_row.add_child(theme_opt)
	var tex_row := HBoxContainer.new()
	side.add_child(tex_row)
	_floor_tex_opt = _option(FLOOR_TEXES, func(i): meta["floor_tex"] = FLOOR_TEXES[i]; _dirty = true)
	_wall_tex_opt = _option(WALL_TEXES, func(i): meta["wall_tex"] = WALL_TEXES[i]; _dirty = true)
	tex_row.add_child(_small_label("Boden"))
	tex_row.add_child(_floor_tex_opt)
	tex_row.add_child(_small_label("Mauer"))
	tex_row.add_child(_wall_tex_opt)
	var col_row := HBoxContainer.new()
	side.add_child(col_row)
	_floor_col = ColorPickerButton.new()
	_floor_col.custom_minimum_size = Vector2(60, 28)
	_floor_col.color_changed.connect(func(c): meta["floor"] = c; _dirty = true; _canvas.queue_redraw())
	_wall_col = ColorPickerButton.new()
	_wall_col.custom_minimum_size = Vector2(60, 28)
	_wall_col.color_changed.connect(func(c): meta["wall"] = c; _dirty = true)
	col_row.add_child(_small_label("Bodenfarbe"))
	col_row.add_child(_floor_col)
	col_row.add_child(_small_label("Mauerfarbe"))
	col_row.add_child(_wall_col)

	# Werkzeuge
	_section(side, "Werkzeug")
	var tools_row := HBoxContainer.new()
	side.add_child(tools_row)
	var tool_group := ButtonGroup.new()
	for t in [["brush", "Pinsel (B)"], ["rect", "Rechteck (R)"], ["fill", "Füllen (F)"], ["wall", "Schräg (W)"]]:
		var b := _toggle(t[1], tool_group, func(): _set_tool(t[0]))
		tools_row.add_child(b)
		_tool_btns[t[0]] = b
	var brush_row := HBoxContainer.new()
	side.add_child(brush_row)
	brush_row.add_child(_small_label("Pinsel"))
	_brush_opt = _option(["1×1", "3×3", "5×5"], func(i): brush_size = i + 1)
	brush_row.add_child(_brush_opt)
	brush_row.add_child(_small_label("Symmetrie"))
	_sym_opt = _option(SYM_NAMES, func(i): symmetry = i; _canvas.queue_redraw())
	brush_row.add_child(_sym_opt)

	_section(side, "Kacheln (links malen, rechts radieren)")
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	var pal_group := ButtonGroup.new()
	for e in PALETTE:
		var ch: String = e[0]
		var b := _toggle(e[1], pal_group, func():
			paint_char = ch
			if tool == "wall":
				_set_tool("brush")
		)
		b.tooltip_text = e[3]
		b.icon = _swatch(e[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_palette_btns[ch] = b
	var ramp_row := HBoxContainer.new()
	side.add_child(ramp_row)
	ramp_row.add_child(_small_label("Rampe steigt"))
	var ramp_group := ButtonGroup.new()
	for r in [["E", "→"], ["W", "←"], ["N", "↑"], ["S", "↓"]]:
		var b := _toggle(r[1], ramp_group, func(): ramp_dir = r[0]; paint_char = "R"; _palette_btns["R"].button_pressed = true)
		ramp_row.add_child(b)
		_ramp_btns[r[0]] = b
	var wall_row := HBoxContainer.new()
	side.add_child(wall_row)
	wall_row.add_child(_small_label("Schräge Wand"))
	var wh_group := ButtonGroup.new()
	for wh in WALL_HEIGHTS:
		var b := _toggle(wh[1], wh_group, func(): wall_height = wh[0]; _set_tool("wall"))
		wall_row.add_child(b)
		_wallh_btns[wh[0]] = b

	var undo_row := HBoxContainer.new()
	side.add_child(undo_row)
	undo_row.add_child(_button("Rückgängig", func(): undo()))
	undo_row.add_child(_button("Wiederholen", func(): redo()))

	_section(side, "Prüfung")
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)

	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", UiTheme.FS_S)
	help.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	help.text = "Mausrad zoomt, mittlere Maustaste oder Leertaste + Ziehen verschiebt. Schräge Wände: von Ecke zu Ecke ziehen, Rechtsklick auf eine Wand löscht sie. Rampen: eine Reihe gleicher Pfeile, die an einer Erhöhung endet."
	side.add_child(help)


	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.focus_mode = Control.FOCUS_CLICK
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	_canvas.mouse_exited.connect(func(): _hover = Vector2i(-1, -1); _canvas.queue_redraw())
	hbox.add_child(_canvas)

	_tool_btns["brush"].button_pressed = true
	_palette_btns["#"].button_pressed = true
	paint_char = "#"
	_ramp_btns["E"].button_pressed = true
	_wallh_btns["#"].button_pressed = true

func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_M)
	l.add_theme_color_override("font_color", UiTheme.GOLD)
	parent.add_child(l)

func _small_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", UiTheme.FS_S)
	return l

func _button(text: String, cb: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	WorkshopStyle.style_button(b, primary, 14)
	b.pressed.connect(func():
		SoundManager.play_sound("click")
		cb.call()
	)
	return b

func _toggle(text: String, group: ButtonGroup, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.focus_mode = Control.FOCUS_NONE
	WorkshopStyle.style_button(b, false, UiTheme.FS_S)
	b.pressed.connect(cb)
	return b

func _option(items: Array, cb: Callable) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(cb)
	return o

func _spin(lo: int, hi: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.custom_minimum_size = Vector2(70, 0)
	return s

func _swatch(c: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _set_tool(t: String) -> void:
	tool = t
	if _tool_btns.has(t):
		_tool_btns[t].button_pressed = true
	_canvas.queue_redraw()

func _sync_controls() -> void:
	if _name_edit == null:
		return
	_name_edit.text = str(meta.get("name", ""))
	_w_spin.value = map_w
	_h_spin.value = map_h
	_pool_check.set_pressed_no_signal(bool(meta.get("in_pool", false)))
	_floor_tex_opt.select(maxi(0, FLOOR_TEXES.find(str(meta.get("floor_tex", "grass")))))
	_wall_tex_opt.select(maxi(0, WALL_TEXES.find(str(meta.get("wall_tex", "brick")))))
	_floor_col.color = meta.get("floor", Color(0.4, 0.6, 0.3))
	_wall_col.color = meta.get("wall", Color(0.6, 0.6, 0.6))
	_delete_armed = false
	_delete_btn.text = "Löschen"

func _on_delete() -> void:
	if map_id.is_empty() or not ArenaMaps.is_custom(map_id):
		_set_status("Diese Karte ist nicht gespeichert.", true)
		return
	if not _delete_armed:
		_delete_armed = true
		_delete_btn.text = "Wirklich?"
		return
	ArenaMaps.delete_custom(map_id)
	_set_status("Gelöscht: %s" % str(meta.get("name", map_id)), false)
	map_id = ""
	_refresh_load_list()
	_delete_armed = false
	_delete_btn.text = "Löschen"

func _on_test() -> void:
	if not _save():
		return
	_store_state()
	visible = false
	test_requested.emit(map_id)

# --- Ansicht -------------------------------------------------------------------

func _fit_view() -> void:
	if _canvas == null or map_w == 0:
		return
	var size := _canvas.size
	if size.x < 10.0:
		size = get_viewport().get_visible_rect().size - Vector2(330, 0)
	_zoom = clampf(minf((size.x - 40.0) / map_w, (size.y - 40.0) / map_h), 4.0, 48.0)
	_pan = (size - Vector2(map_w, map_h) * _zoom) * 0.5
	_canvas.queue_redraw()

func _to_cell(p: Vector2) -> Vector2i:
	var t := (p - _pan) / _zoom
	return Vector2i(int(floor(t.x)), int(floor(t.y)))

func _to_tiles(p: Vector2) -> Vector2:
	return (p - _pan) / _zoom

func _to_corner(p: Vector2) -> Vector2i:
	var t := _to_tiles(p)
	return Vector2i(clampi(int(round(t.x)), 0, map_w), clampi(int(round(t.y)), 0, map_h))

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				var before := _to_tiles(mb.position)
				_zoom = clampf(_zoom * f, 3.0, 64.0)
				_pan = mb.position - before * _zoom
				_canvas.queue_redraw()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and _space_down):
			_panning = mb.pressed
			return
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var erase := mb.button_index == MOUSE_BUTTON_RIGHT
			if mb.pressed:
				_begin_action(mb.position, erase)
			else:
				_end_action(mb.position)
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_pan += mm.relative
			_canvas.queue_redraw()
			return
		_hover = _to_cell(mm.position)
		_hover_corner = _to_corner(mm.position)
		if _painting and tool == "brush":
			_paint_at(_hover, "." if _erasing else _current_char())
			_changed()
		_canvas.queue_redraw()

func _begin_action(pos: Vector2, erase: bool) -> void:
	var c := _to_cell(pos)
	_erasing = erase
	if tool == "wall":
		if erase:
			_push_undo()
			if _remove_wall_near(_to_tiles(pos)):
				_changed()
			else:
				_undo.pop_back()
			return
		_wall_start = _to_corner(pos)
		return
	if not _in_map(c):
		return
	_push_undo()
	var ch := "." if erase else _current_char()
	match tool:
		"brush":
			_painting = true
			_paint_at(c, ch)
			_changed()
		"rect":
			_drag_start = c
		"fill":
			_flood(c, ch)
			_changed()

func _end_action(pos: Vector2) -> void:
	if tool == "wall" and _wall_start.x >= 0:
		var end := _to_corner(pos)
		if end != _wall_start:
			_push_undo()
			_add_wall(_wall_start, end)
			_changed()
		_wall_start = Vector2i(-1, -1)
	elif tool == "rect" and _drag_start.x >= 0:
		var c := _to_cell(pos)
		c = Vector2i(clampi(c.x, 0, map_w - 1), clampi(c.y, 0, map_h - 1))
		_fill_rect(_drag_start, c, "." if _erasing else _current_char())
		_drag_start = Vector2i(-1, -1)
		_changed()
	_painting = false
	_canvas.queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE:
			_space_down = k.pressed
		if not k.pressed or k.echo:
			return
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is SpinBox or (focus != null and focus.get_parent() is SpinBox):
			if k.keycode == KEY_ESCAPE:
				focus.release_focus()
				get_viewport().set_input_as_handled()
			return
		var handled := true
		if k.ctrl_pressed and k.keycode == KEY_Z:
			if k.shift_pressed:
				redo()
			else:
				undo()
		elif k.ctrl_pressed and k.keycode == KEY_Y:
			redo()
		elif k.ctrl_pressed and k.keycode == KEY_S:
			_save()
		elif k.keycode == KEY_B:
			_set_tool("brush")
		elif k.keycode == KEY_R:
			_set_tool("rect")
		elif k.keycode == KEY_F:
			_set_tool("fill")
		elif k.keycode == KEY_W:
			_set_tool("wall")
		elif k.keycode == KEY_ESCAPE:
			close_editor()
		elif k.keycode == KEY_SPACE:
			pass
		else:
			handled = false
		if handled:
			get_viewport().set_input_as_handled()

func _char_color(ch: String) -> Color:
	if ArenaMaps.RAMP_DIRS.has(ch):
		return PALETTE[10][2]
	for e in PALETTE:
		if e[0] == ch:
			return e[2]
	return Color.MAGENTA

func _draw_canvas() -> void:
	var font := ThemeDB.fallback_font
	var z := _zoom
	var floor_c: Color = meta.get("floor", PALETTE[0][2])
	floor_c = floor_c.darkened(0.35)
	_canvas.draw_rect(Rect2(_pan - Vector2(6, 6), Vector2(map_w, map_h) * z + Vector2(12, 12)), Color(0.18, 0.18, 0.22))
	for y in range(map_h):
		for x in range(map_w):
			var ch: String = cells[y][x]
			var r := Rect2(_pan + Vector2(x, y) * z, Vector2(z, z))
			var col := floor_c if ch == "." or ch == "S" else _char_color(ch)
			if (x + y) % 2 == 0:
				col = col.darkened(0.05)
			_canvas.draw_rect(r, col)
			if ch == "S":
				_canvas.draw_circle(r.get_center(), z * 0.36, PALETTE[5][2])
			elif ch == "x":
				_canvas.draw_line(r.position + Vector2(2, 2), r.end - Vector2(2, 2), Color(0.4, 0.22, 0.08), maxf(1.0, z * 0.08))
				_canvas.draw_line(Vector2(r.position.x + 2, r.end.y - 2), Vector2(r.end.x - 2, r.position.y + 2), Color(0.4, 0.22, 0.08), maxf(1.0, z * 0.08))
			elif ch == "=":
				for k in range(1, 3):
					var yy := r.position.y + r.size.y * k / 3.0
					_canvas.draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(0.35, 0.22, 0.1), 1.0)
			elif ArenaMaps.RAMP_DIRS.has(ch):
				var d: Vector2 = Vector2(ArenaMaps.RAMP_DIRS[ch])
				var c := r.get_center()
				var tip := c + d * z * 0.36
				var side := Vector2(-d.y, d.x) * z * 0.22
				_canvas.draw_colored_polygon(PackedVector2Array([tip, c - d * z * 0.1 + side, c - d * z * 0.1 - side]), Color(0.25, 0.2, 0.12))
				_canvas.draw_line(c - d * z * 0.36, c, Color(0.25, 0.2, 0.12), maxf(1.0, z * 0.1))
			elif z >= 14.0 and ArenaMaps.BLOCK_HEIGHTS.has(ch):
				var lv := int(round(float(ArenaMaps.BLOCK_HEIGHTS[ch]) / ArenaMode.BAND_H))
				_canvas.draw_string(font, r.position + Vector2(z * 0.32, z * 0.72), str(lv), HORIZONTAL_ALIGNMENT_LEFT, -1, int(z * 0.5), Color(0, 0, 0, 0.55))
	# Raster
	if z >= 8.0:
		var gc := Color(0, 0, 0, 0.18)
		for x in range(map_w + 1):
			_canvas.draw_line(_pan + Vector2(x * z, 0), _pan + Vector2(x * z, map_h * z), gc, 1.0)
		for y in range(map_h + 1):
			_canvas.draw_line(_pan + Vector2(0, y * z), _pan + Vector2(map_w * z, y * z), gc, 1.0)
	# Symmetrie-Achsen
	var axis_c := Color(1, 0.4, 0.9, 0.5)
	if symmetry == 1 or symmetry == 3:
		_canvas.draw_dashed_line(_pan + Vector2(map_w * z * 0.5, 0), _pan + Vector2(map_w * z * 0.5, map_h * z), axis_c, 2.0, 8.0)
	if symmetry == 2 or symmetry == 3:
		_canvas.draw_dashed_line(_pan + Vector2(0, map_h * z * 0.5), _pan + Vector2(map_w * z, map_h * z * 0.5), axis_c, 2.0, 8.0)
	if symmetry == 4:
		_canvas.draw_circle(_pan + Vector2(map_w, map_h) * z * 0.5, 5.0, axis_c)
	# Schräge Wände
	for w in walls:
		var wc := _char_color(str(w[4])).lightened(0.15)
		_canvas.draw_line(_pan + Vector2(w[0], w[1]) * z, _pan + Vector2(w[2], w[3]) * z, wc, maxf(3.0, z * 0.8))
	# Vorschau
	if tool == "wall":
		if _hover_corner.x >= 0:
			_canvas.draw_circle(_pan + Vector2(_hover_corner) * z, maxf(3.0, z * 0.18), Color(1, 1, 1, 0.8))
		if _wall_start.x >= 0 and _hover_corner.x >= 0:
			_canvas.draw_line(_pan + Vector2(_wall_start) * z, _pan + Vector2(_hover_corner) * z, Color(1, 1, 1, 0.7), maxf(3.0, z * 0.8))
	elif tool == "rect" and _drag_start.x >= 0 and _hover.x >= 0:
		var a := Vector2(mini(_drag_start.x, _hover.x), mini(_drag_start.y, _hover.y))
		var b := Vector2(maxi(_drag_start.x, _hover.x) + 1, maxi(_drag_start.y, _hover.y) + 1)
		_canvas.draw_rect(Rect2(_pan + a * z, (b - a) * z), Color(1, 1, 1, 0.9), false, 2.0)
	elif _in_map(_hover):
		var r := brush_size - 1 if tool == "brush" else 0
		for s in _sym_cells(_hover):
			var sc: Vector2i = s[0]
			_canvas.draw_rect(Rect2(_pan + Vector2(sc - Vector2i(r, r)) * z, Vector2(r * 2 + 1, r * 2 + 1) * z), Color(1, 1, 1, 0.85), false, 2.0)
	if _in_map(_hover):
		var ch: String = cells[_hover.y][_hover.x]
		var txt := "%d, %d  %s" % [_hover.x, _hover.y, _cell_name(ch)]
		_canvas.draw_string(font, Vector2(12, _canvas.size.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.9, 0.95, 1.0))

func _cell_name(ch: String) -> String:
	if ArenaMaps.RAMP_DIRS.has(ch):
		return "Rampe " + {">": "→", "<": "←", "^": "↑", "v": "↓"}[ch]
	for e in PALETTE:
		if e[0] == ch:
			return e[1]
	return ch
