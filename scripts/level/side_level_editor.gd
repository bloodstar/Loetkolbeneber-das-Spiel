class_name SideLevelEditor
extends CanvasLayer

# Karteneditor für Seitenansicht-Level. Lädt den Bauplan eines Levels
# (LevelGenerator.LAYOUTS oder eine Überschreibung aus SideLevels), zeigt ihn
# als Kachelraster und erlaubt Plattformen, Einweg-Stege, Kistenblöcke, Wände,
# Stacheln, Sprungfedern, Mystery-Blöcke, Röhren und Gruben zu zeichnen. Alle
# übrigen Objekte (Wippen, Ketten, Drehbalken, Häuser, Pyramiden …) werden
# angezeigt und lassen sich verschieben und löschen.
#
# Gespiegelte Level: Jeder Eintrag erscheint zusätzlich gespiegelt (blass).
# Zufällige Zusatzplattformen, Kistenhaufen und Eis aus dem Profil kommen im
# Spiel noch dazu, außer "Zufällige Extras" ist aus.

signal closed
signal test_requested(map_id: String)
signal arena_editor_requested

const UNDO_LIMIT := 80

# Zeichenwerkzeuge: Schlüssel im Bauplan, Name, Farbe, Art der Eingabe
const DRAW_TOOLS := [
	["platforms", "Plattform", Color(0.45, 0.62, 0.35), "row"],
	["oneway", "Einweg-Steg", Color(0.85, 0.75, 0.35), "row"],
	["blocks", "Kistenblöcke", Color(0.80, 0.52, 0.25), "row"],
	["walls", "Wand", Color(0.42, 0.45, 0.52), "rect"],
	["spikes", "Stacheln", Color(0.90, 0.30, 0.30), "cell"],
	["pads", "Sprungfeder", Color(0.30, 0.85, 0.45), "cell"],
	["mystery", "Mystery-Block", Color(0.98, 0.80, 0.20), "cell"],
	["pipes", "Röhrenpaar", Color(0.25, 0.75, 0.40), "pair"],
	["ground_gaps", "Grube", Color(0.10, 0.10, 0.14), "gap"],
]
# Weitere Objekte: Name und Farbe (nur verschieben/löschen)
const OTHER_KINDS := {
	"houses": ["Haus", Color(0.75, 0.55, 0.45)],
	"pyramids": ["Pyramide", Color(0.85, 0.75, 0.45)],
	"stairs": ["Treppe", Color(0.55, 0.62, 0.40)],
	"seesaws": ["Wippe", Color(0.55, 0.75, 0.95)],
	"chains": ["Kettenplattform", Color(0.70, 0.70, 0.78)],
	"chain_grids": ["Gitterzaun", Color(0.70, 0.70, 0.78)],
	"crate_chains": ["Kistenkette", Color(0.80, 0.60, 0.35)],
	"movers": ["Fahrplattform", Color(0.40, 0.80, 0.95)],
	"rotators": ["Drehbalken", Color(0.95, 0.55, 0.85)],
	"ramps": ["Schräge", Color(0.60, 0.65, 0.50)],
	"ball_gates": ["Kugeltor", Color(0.95, 0.65, 0.30)],
	"ball_rows": ["Kugelreihe", Color(0.95, 0.65, 0.30)],
	"ball_chains": ["Kugelkette", Color(0.95, 0.65, 0.30)],
	"ball_spawners": ["Kugelquelle", Color(0.95, 0.65, 0.30)],
	"reserve": ["Freihaltefläche", Color(1, 1, 1, 0.25)],
}
# Welche Felder eines Eintrags x- bzw. y-Koordinaten (in Kacheln) sind.
const COORDS := {
	"platforms": [[0, 1], [2]], "oneway": [[0, 1], [2]], "blocks": [[0, 1], [2]],
	"walls": [[0, 1], [2, 3]], "reserve": [[0, 1], [2, 3]],
	"spikes": [[0], [1]], "pads": [[0], [1]], "mystery": [[0], [1]],
	"pipes": [[0, 2], [1, 3]], "ground_gaps": [[0, 1], []],
	"houses": [[0, 1], [2]], "pyramids": [[0], [1, 2]], "stairs": [[0, 1], []],
	"seesaws": [[0], [1]], "chains": [[0], [1]], "movers": [[0], [1]],
	"rotators": [[0], [1]], "ball_gates": [[0], [1]], "ball_spawners": [[0], [1]],
	"crate_chains": [[0, 2], [1, 3]], "ramps": [[0, 2], [1, 3]],
	"ball_rows": [[0, 2], [1, 3]], "ball_chains": [[0, 2], [1, 3]],
}
# Felder, die Mittelpunkte sind (Spiegelung an w statt w - 1).
const CENTER_KINDS := ["pyramids", "seesaws", "chains", "rotators", "crate_chains", "ramps", "ball_gates", "ball_rows", "ball_chains", "ball_spawners"]

static var _last_state: Dictionary = {}

var map_id: String = "grasarena"
var base_id: String = "grasarena"
var lay: Dictionary = {}
var extras: bool = true
var level_name: String = ""
var map_w: int = 44
var map_h: int = 25

var tool: String = "platforms"
var _undo: Array = []
var _redo: Array = []
var _dirty: bool = false
var _selected: Array = [] # [kind, index]

var _canvas: Control
var _zoom: float = 24.0
var _pan: Vector2 = Vector2(20, 20)
var _panning: bool = false
var _space_down: bool = false
var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_button: int = 0
var _move_last: Vector2i = Vector2i(-1, -1)
var _moving: bool = false
var _pipe_first: Vector2i = Vector2i(-1, -1)
var _hover: Vector2i = Vector2i(-1, -1)

var _level_opt: OptionButton
var _name_edit: LineEdit
var _mirror_check: CheckBox
var _extras_check: CheckBox
var _reset_btn: Button
var _status: Label
var _info: Label
var _tool_btns: Dictionary = {}
var _reset_armed: bool = false

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()

func is_open() -> bool:
	return visible

func open_editor() -> void:
	_refresh_level_list()
	if _last_state.is_empty():
		_load_level("grasarena")
	else:
		_restore(_last_state)
	visible = true
	_fit_view()

func close_editor() -> void:
	_store()
	visible = false
	closed.emit()

# --- Daten ------------------------------------------------------------------

func _load_level(id: String) -> void:
	map_id = id
	var entry: Dictionary = SideLevels.custom.get(id, {})
	base_id = str(entry.get("based_on", id))
	var profile: Dictionary = LevelGenerator.MAP_PROFILES.get(base_id, {})
	map_w = int(profile.get("width", LevelGenerator.MAP_WIDTH))
	map_h = int(profile.get("height", LevelGenerator.MAP_HEIGHT))
	lay = _clean(SideLevels.layout(id).duplicate(true))
	extras = SideLevels.extras_enabled(id)
	level_name = SideLevels.custom_name(id) if SideLevels.is_custom(id) else Global.get_map_name(id)
	_undo.clear()
	_redo.clear()
	_selected = []
	_dirty = false
	_sync_controls()
	_fit_view()
	_validate()

## JSON macht aus Zahlen float; ganzzahlige Felder wieder als int speichern,
## damit der Bauplan lesbar bleibt.
static func _clean(v):
	if v is Array:
		var out: Array = []
		for e in v:
			out.append(_clean(e))
		return out
	if v is Dictionary:
		var d := {}
		for k in v.keys():
			d[k] = _clean(v[k])
		return d
	if v is float and is_equal_approx(v, round(v)) and absf(v) < 100000.0:
		return int(round(v))
	return v

func _store() -> void:
	_last_state = {"id": map_id, "base": base_id, "lay": lay.duplicate(true), "extras": extras, "name": level_name, "dirty": _dirty}

func _restore(st: Dictionary) -> void:
	_load_level(str(st["id"]) if SideLevels.has(str(st["id"])) else "grasarena")
	if str(st["id"]) == map_id:
		lay = st["lay"]
		extras = bool(st["extras"])
		level_name = str(st["name"])
		_dirty = bool(st["dirty"])
		_sync_controls()
		_validate()

func _snapshot() -> Dictionary:
	return {"lay": lay.duplicate(true), "extras": extras}

func _push_undo() -> void:
	_undo.append(_snapshot())
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()
	_redo.clear()

func undo() -> void:
	if _undo.is_empty():
		return
	_redo.append(_snapshot())
	var s: Dictionary = _undo.pop_back()
	lay = s["lay"]
	extras = s["extras"]
	_selected = []
	_sync_controls()
	_changed()

func redo() -> void:
	if _redo.is_empty():
		return
	_undo.append(_snapshot())
	var s: Dictionary = _redo.pop_back()
	lay = s["lay"]
	extras = s["extras"]
	_selected = []
	_sync_controls()
	_changed()

func _changed() -> void:
	_dirty = true
	_validate()
	_canvas.queue_redraw()

func _entries(kind: String) -> Array:
	if not lay.has(kind):
		lay[kind] = []
	return lay[kind]

func _mirror() -> bool:
	return bool(lay.get("mirror", false))

# --- Geometrie --------------------------------------------------------------

## Rechtecke (in Kacheln) eines Eintrags zum Zeichnen und Anklicken.
func _rects(kind: String, e: Array) -> Array:
	var gr := float(map_h - 2)
	match kind:
		"platforms", "blocks", "houses":
			var y := float(e[2])
			if kind == "houses":
				return [Rect2(float(e[0]), y - 7.0, float(e[1]) - float(e[0]) + 1.0, 8.0)]
			return [Rect2(float(e[0]), y, float(e[1]) - float(e[0]) + 1.0, 1.0)]
		"oneway":
			return [Rect2(float(e[0]), float(e[2]), float(e[1]) - float(e[0]) + 1.0, 0.35)]
		"walls", "reserve":
			return [Rect2(float(e[0]), float(e[2]), float(e[1]) - float(e[0]) + 1.0, float(e[3]) - float(e[2]) + 1.0)]
		"spikes", "pads", "mystery":
			return [Rect2(float(e[0]), float(e[1]), 1.0, 1.0)]
		"pipes":
			return [Rect2(float(e[0]), float(e[1]) - 1.0, 1.0, 2.0), Rect2(float(e[2]), float(e[3]) - 1.0, 1.0, 2.0)]
		"ground_gaps":
			return [Rect2(float(e[0]), gr, float(e[1]) - float(e[0]) + 1.0, 2.0)]
		"pyramids":
			return [Rect2(float(e[0]) - float(e[3]), float(e[2]), float(e[3]) * 2.0, float(e[1]) - float(e[2]))]
		"stairs":
			var hmax := float(maxi(int(e[2]), int(e[3])))
			return [Rect2(float(e[0]), gr - hmax, float(e[1]) - float(e[0]) + 1.0, hmax)]
		"seesaws":
			return [Rect2(float(e[0]) - float(e[2]) * 0.5, float(e[1]), float(e[2]), 0.6)]
		"chains":
			return [Rect2(float(e[0]) - float(e[3]) * 0.5, float(e[1]), float(e[3]), float(e[2]) + 1.0)]
		"movers":
			return [Rect2(float(e[0]), float(e[1]), float(e[2]), 1.0)]
		"rotators":
			var r := float(e[2])
			return [Rect2(float(e[0]) - r, float(e[1]) - r, r * 2.0, r * 2.0)]
		"chain_grids":
			var cols: Array = e[0]
			var rows: Array = e[1]
			return [Rect2(float(cols.min()), float(rows.min()), float(cols.max()) - float(cols.min()) + 1.0, float(rows.max()) - float(rows.min()) + 1.0)]
		"ball_gates":
			return [Rect2(float(e[0]) - 0.3, float(e[1]), 0.6, float(e[2]))]
		"ball_spawners":
			return [Rect2(float(e[0]) - 0.5, float(e[1]) - 0.5, 1.0, 1.0)]
		"crate_chains", "ramps", "ball_rows", "ball_chains":
			var a := Vector2(float(e[0]), float(e[1]))
			var b := Vector2(float(e[2]), float(e[3])) if float(e[2]) >= 0.0 else a + Vector2(0, 4)
			return [Rect2(a, Vector2.ZERO).expand(b).grow(0.4)]
	return []

## Gespiegelter Eintrag (wie LevelGenerator ihn baut) oder [] ohne Spiegelung.
func _mirrored(kind: String, e: Array) -> Array:
	if not _mirror() or kind in ["pipes", "ground_gaps", "reserve", "chain_grids"]:
		return []
	var m := e.duplicate(true)
	var c: Array = COORDS.get(kind, [[], []])
	var center := kind in CENTER_KINDS
	if kind == "movers":
		m[0] = map_w - int(e[0]) - int(e[2])
		return m if m[0] != e[0] else []
	if kind == "crate_chains" and float(e[2]) < 0.0:
		m[0] = float(map_w) - float(e[0])
		return m
	for i in c[0]:
		m[i] = (float(map_w) - float(e[i])) if center else (map_w - 1 - int(e[i]))
	if c[0].size() == 2 and not center:
		var t = m[c[0][0]]
		m[c[0][0]] = m[c[0][1]]
		m[c[0][1]] = t
	if m == e:
		return []
	return m

func _hit(tile_pos: Vector2) -> Array:
	# Kleine Objekte zuerst, damit sie über großen Flächen wählbar bleiben.
	var best: Array = []
	var best_area := INF
	for kind in lay.keys():
		if not (lay[kind] is Array):
			continue
		var list: Array = lay[kind]
		for i in range(list.size()):
			for r in _rects(kind, list[i]):
				var rr: Rect2 = r
				if rr.grow(0.15).has_point(tile_pos) and rr.get_area() < best_area:
					best_area = rr.get_area()
					best = [kind, i]
	return best

func _move_entry(kind: String, i: int, d: Vector2i) -> void:
	var e: Array = lay[kind][i]
	if kind == "chain_grids":
		var cols: Array = e[0]
		var rows: Array = e[1]
		for k in range(cols.size()):
			cols[k] = float(cols[k]) + d.x
		for k in range(rows.size()):
			rows[k] = float(rows[k]) + d.y
		return
	var c: Array = COORDS.get(kind, [[], []])
	for idx in c[0]:
		if kind == "crate_chains" and idx == 2 and float(e[2]) < 0.0:
			continue
		e[idx] = e[idx] + d.x
	for idx in c[1]:
		if kind == "crate_chains" and idx == 3 and float(e[2]) < 0.0:
			continue
		e[idx] = e[idx] + d.y

# --- Prüfung ----------------------------------------------------------------

func _validate() -> void:
	if _info == null:
		return
	var n := 0
	for k in lay.keys():
		if lay[k] is Array:
			n += (lay[k] as Array).size()
	var lines: Array[String] = []
	lines.append("%d × %d Kacheln, %d Einträge%s" % [map_w, map_h, n, " (gespiegelt)" if _mirror() else ""])
	var blocked := 0
	for e in lay.get("pads", []):
		for k in range(1, 9):
			var cell := Vector2(float(e[0]) + 0.5, float(e[1]) - k + 0.5)
			var hit := _hit(cell)
			if not hit.is_empty() and hit[0] in ["platforms", "walls", "blocks"]:
				blocked += 1
				break
	if blocked > 0:
		lines.append("⚠ %d Sprungfeder(n) mit blockierter Flugbahn – das Spiel lässt sie weg." % blocked)
	if SideLevels.has_override(map_id) and not SideLevels.is_custom(map_id):
		lines.append("Dieses Level nutzt eine geänderte Fassung.")
	_info.text = "\n".join(lines)

# --- Speichern ----------------------------------------------------------------

func _save() -> bool:
	if SideLevels.is_custom(map_id):
		level_name = _name_edit.text.strip_edges() if not _name_edit.text.strip_edges().is_empty() else level_name
	var data := {"layout": lay, "extras": extras}
	if SideLevels.is_custom(map_id):
		data["based_on"] = base_id
		data["name"] = level_name
		data["description"] = "Eigenes Level (Basis: %s)." % Global.get_map_name(base_id)
	var err := SideLevels.save(map_id, data)
	if err != OK:
		_set_status("Speichern fehlgeschlagen (Fehler %d)." % err, true)
		return false
	LevelPreviewRenderer._cache.erase(map_id)
	_dirty = false
	_refresh_level_list()
	_set_status("Gespeichert.", false)
	_validate()
	return true

func _save_as_new() -> void:
	var nm := _name_edit.text.strip_edges()
	if nm.is_empty() or nm == Global.get_map_name(map_id):
		nm = "%s Variante" % Global.get_map_name(base_id)
	var id := SideLevels.make_custom_id(nm)
	var k := 2
	while SideLevels.has(id):
		id = SideLevels.make_custom_id("%s %d" % [nm, k])
		k += 1
	map_id = id
	level_name = nm
	var data := {"layout": lay, "extras": extras, "based_on": base_id, "name": nm,
		"description": "Eigenes Level (Basis: %s)." % Global.get_map_name(base_id)}
	if SideLevels.save(id, data) != OK:
		_set_status("Speichern fehlgeschlagen.", true)
		return
	_dirty = false
	_refresh_level_list()
	_sync_controls()
	_set_status("Neues Level „%s“ angelegt. Es erscheint im Levels-Tab der Lobby." % nm, false)

func _on_reset() -> void:
	var custom := SideLevels.is_custom(map_id)
	if not custom and not SideLevels.has_override(map_id):
		_set_status("Dieses Level ist unverändert.", false)
		return
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Wirklich?"
		return
	SideLevels.remove(map_id)
	LevelPreviewRenderer._cache.erase(map_id)
	_set_status("Gelöscht." if custom else "Original wiederhergestellt.", false)
	_refresh_level_list()
	_load_level(base_id if custom else map_id)

func _refresh_level_list() -> void:
	if _level_opt == null:
		return
	_level_opt.clear()
	for id in Global.get_playable_maps():
		var label := Global.get_map_name(id)
		if SideLevels.is_custom(id):
			label = "★ " + label
		elif SideLevels.has_override(id):
			label += " (geändert)"
		_level_opt.add_item(label)
		_level_opt.set_item_metadata(_level_opt.item_count - 1, id)
		if id == map_id:
			_level_opt.select(_level_opt.item_count - 1)

func _set_status(text: String, error: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5) if error else Color(0.8, 0.9, 1.0))

# --- Oberfläche -------------------------------------------------------------

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
	root.add_child(hbox)
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(330, 0)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hbox.add_child(side_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + m, 12)
	side_scroll.add_child(margin)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	margin.add_child(side)

	var title := Label.new()
	title.text = "KARTENEDITOR (SEITENANSICHT)"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	side.add_child(title)
	var top_row := HBoxContainer.new()
	side.add_child(top_row)
	var test_btn := _button("TESTEN", func(): _on_test(), true)
	test_btn.tooltip_text = "Speichert und startet ein Match in der Seitenansicht auf diesem Level (Spieler und Bots wie in der letzten Lobby). ESC → Hauptmenü beendet den Test."
	test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(test_btn)
	var close_btn := _button("SCHLIESSEN", func(): close_editor())
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(close_btn)
	var arena_btn := _button("Zum Arena-Editor", func():
		_store()
		visible = false
		arena_editor_requested.emit()
	)
	side.add_child(arena_btn)

	_section(side, "Level")
	_level_opt = OptionButton.new()
	_level_opt.clip_text = true
	_level_opt.focus_mode = Control.FOCUS_NONE
	_level_opt.item_selected.connect(func(i):
		_load_level(str(_level_opt.get_item_metadata(i)))
		_set_status("", false)
	)
	side.add_child(_level_opt)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name (für neues Level)"
	side.add_child(_name_edit)
	var file_row := HBoxContainer.new()
	side.add_child(file_row)
	file_row.add_child(_button("Speichern", func(): _save(), true))
	file_row.add_child(_button("Als neues Level", func(): _save_as_new()))
	_reset_btn = _button("Original", func(): _on_reset())
	_reset_btn.tooltip_text = "Eingebautes Level: Änderungen verwerfen. Eigenes Level: löschen."
	file_row.add_child(_reset_btn)
	_mirror_check = CheckBox.new()
	_mirror_check.text = "Gespiegelt (links ↔ rechts)"
	_mirror_check.toggled.connect(func(on):
		_push_undo()
		lay["mirror"] = on
		_changed()
	)
	side.add_child(_mirror_check)
	_extras_check = CheckBox.new()
	_extras_check.text = "Zufällige Extras (Zusatzplattformen, Kisten, Eis)"
	_extras_check.tooltip_text = "Das Profil des Levels streut pro Runde zufällige Zusatzplattformen, Kistenhaufen und Eisflächen dazu. Aus: nur der Bauplan."
	_extras_check.toggled.connect(func(on):
		_push_undo()
		extras = on
		_changed()
	)
	side.add_child(_extras_check)

	_section(side, "Zeichnen (links), Löschen (rechts)")
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	var group := ButtonGroup.new()
	var sel := _toggle("Auswählen / Verschieben", group, func(): _set_tool("select"))
	sel.icon = _swatch(Color(1, 1, 1))
	grid.add_child(sel)
	_tool_btns["select"] = sel
	for t in DRAW_TOOLS:
		var key: String = t[0]
		var b := _toggle(t[1], group, func(): _set_tool(key))
		b.icon = _swatch(t[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
		_tool_btns[key] = b
	var undo_row := HBoxContainer.new()
	side.add_child(undo_row)
	undo_row.add_child(_button("Rückgängig", func(): undo()))
	undo_row.add_child(_button("Wiederholen", func(): redo()))
	undo_row.add_child(_button("Entfernen", func(): _delete_selected()))

	_section(side, "Info")
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_status)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	help.text = "Plattformen, Stege, Kisten und Gruben waagrecht ziehen, Wände als Rechteck. Röhren: erst Eingang, dann Ausgang anklicken. Rechtsklick löscht das Objekt unter der Maus. Auswählen: Objekt ziehen verschiebt es, Entf löscht. Blasse Objekte sind die automatische Spiegelung. Mausrad zoomt, Leertaste oder mittlere Taste + Ziehen verschiebt."
	side.add_child(help)

	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_canvas_input)
	hbox.add_child(_canvas)
	_tool_btns["platforms"].button_pressed = true

func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	parent.add_child(l)

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
	WorkshopStyle.style_button(b, false, 13)
	b.pressed.connect(cb)
	return b

func _swatch(c: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)

func _set_tool(t: String) -> void:
	tool = t
	_pipe_first = Vector2i(-1, -1)
	if _tool_btns.has(t):
		_tool_btns[t].button_pressed = true
	_canvas.queue_redraw()

func _sync_controls() -> void:
	if _name_edit == null:
		return
	_name_edit.text = level_name if SideLevels.is_custom(map_id) else ""
	_name_edit.placeholder_text = "Name für „Als neues Level“"
	_mirror_check.set_pressed_no_signal(_mirror())
	_extras_check.set_pressed_no_signal(extras)
	_reset_armed = false
	_reset_btn.text = "Löschen" if SideLevels.is_custom(map_id) else "Original"
	_refresh_level_list()

func _on_test() -> void:
	if _dirty or SideLevels.is_custom(map_id) or SideLevels.has_override(map_id):
		if not _save():
			return
	_store()
	visible = false
	test_requested.emit(map_id)

func _delete_selected() -> void:
	if _selected.is_empty():
		return
	_push_undo()
	(lay[_selected[0]] as Array).remove_at(int(_selected[1]))
	_selected = []
	_changed()

# --- Eingabe ----------------------------------------------------------------

func _fit_view() -> void:
	if _canvas == null:
		return
	var size := _canvas.size
	if size.x < 10.0:
		size = get_viewport().get_visible_rect().size - Vector2(330, 0)
	_zoom = clampf(minf((size.x - 40.0) / map_w, (size.y - 40.0) / map_h), 4.0, 48.0)
	_pan = (size - Vector2(map_w, map_h) * _zoom) * 0.5
	_canvas.queue_redraw()

func _tiles(p: Vector2) -> Vector2:
	return (p - _pan) / _zoom

func _cell(p: Vector2) -> Vector2i:
	var t := _tiles(p)
	return Vector2i(clampi(int(floor(t.x)), 0, map_w - 1), clampi(int(floor(t.y)), 0, map_h - 1))

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				var before := _tiles(mb.position)
				_zoom = clampf(_zoom * f, 3.0, 72.0)
				_pan = mb.position - before * _zoom
				_canvas.queue_redraw()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE or (mb.button_index == MOUSE_BUTTON_LEFT and _space_down):
			_panning = mb.pressed
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var hit := _hit(_tiles(mb.position))
			if not hit.is_empty():
				_push_undo()
				(lay[hit[0]] as Array).remove_at(int(hit[1]))
				_selected = []
				_changed()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press(mb.position)
			else:
				_release(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _panning:
			_pan += mm.relative
			_canvas.queue_redraw()
			return
		_hover = _cell(mm.position)
		if _moving and not _selected.is_empty():
			var c := Vector2i(int(floor(_tiles(mm.position).x)), int(floor(_tiles(mm.position).y)))
			var d := c - _move_last
			if d != Vector2i.ZERO:
				_move_entry(_selected[0], int(_selected[1]), d)
				_move_last = c
				_changed()
		_canvas.queue_redraw()

func _press(pos: Vector2) -> void:
	var c := _cell(pos)
	if tool == "select":
		_selected = _hit(_tiles(pos))
		if not _selected.is_empty():
			_push_undo()
			_moving = true
			_move_last = Vector2i(int(floor(_tiles(pos).x)), int(floor(_tiles(pos).y)))
		_canvas.queue_redraw()
		return
	var kind := _tool_kind()
	if kind == "cell":
		_push_undo()
		_entries(tool).append([c.x, c.y])
		_changed()
	elif kind == "pair":
		if _pipe_first.x < 0:
			_pipe_first = c
		else:
			_push_undo()
			_entries("pipes").append([_pipe_first.x, _pipe_first.y, c.x, c.y])
			_pipe_first = Vector2i(-1, -1)
			_changed()
	else:
		_drag_start = c
	_canvas.queue_redraw()

func _release(pos: Vector2) -> void:
	if _moving:
		_moving = false
		_canvas.queue_redraw()
		return
	if _drag_start.x < 0:
		return
	var c := _cell(pos)
	var x0 := mini(_drag_start.x, c.x)
	var x1 := maxi(_drag_start.x, c.x)
	_push_undo()
	match _tool_kind():
		"row":
			_entries(tool).append([x0, x1, _drag_start.y])
		"rect":
			_entries(tool).append([x0, x1, mini(_drag_start.y, c.y), maxi(_drag_start.y, c.y)])
		"gap":
			_entries(tool).append([x0, x1])
	_drag_start = Vector2i(-1, -1)
	_changed()

func _tool_kind() -> String:
	for t in DRAW_TOOLS:
		if t[0] == tool:
			return t[3]
	return ""

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if k.keycode == KEY_SPACE:
		_space_down = k.pressed
	if not k.pressed or k.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
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
	elif k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE:
		_delete_selected()
	elif k.keycode == KEY_ESCAPE:
		close_editor()
	elif k.keycode == KEY_SPACE:
		pass
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()

# --- Zeichnen ---------------------------------------------------------------

func _kind_color(kind: String) -> Color:
	for t in DRAW_TOOLS:
		if t[0] == kind:
			return t[2]
	return OTHER_KINDS.get(kind, ["", Color.MAGENTA])[1]

func _kind_name(kind: String) -> String:
	for t in DRAW_TOOLS:
		if t[0] == kind:
			return t[1]
	return OTHER_KINDS.get(kind, [kind])[0]

func _r(r: Rect2) -> Rect2:
	return Rect2(_pan + r.position * _zoom, r.size * _zoom)

func _draw_canvas() -> void:
	var z := _zoom
	var font := ThemeDB.fallback_font
	_canvas.draw_rect(_r(Rect2(0, 0, map_w, map_h)), Color(0.16, 0.2, 0.3))
	# Boden (zwei Reihen) ohne Gruben
	var gaps := {}
	for g in lay.get("ground_gaps", []):
		for x in range(int(g[0]), int(g[1]) + 1):
			gaps[x] = true
	for x in range(map_w):
		if not gaps.has(x):
			_canvas.draw_rect(_r(Rect2(x, map_h - 2, 1, 1)), Color(0.36, 0.55, 0.3))
			_canvas.draw_rect(_r(Rect2(x, map_h - 1, 1, 1)), Color(0.36, 0.26, 0.18))
	if z >= 8.0:
		var gc := Color(1, 1, 1, 0.06)
		for x in range(map_w + 1):
			_canvas.draw_line(_pan + Vector2(x, 0) * z, _pan + Vector2(x, map_h) * z, gc)
		for y in range(map_h + 1):
			_canvas.draw_line(_pan + Vector2(0, y) * z, _pan + Vector2(map_w, y) * z, gc)
	if _mirror():
		_canvas.draw_dashed_line(_pan + Vector2(map_w * 0.5, 0) * z, _pan + Vector2(map_w * 0.5, map_h) * z, Color(1, 0.4, 0.9, 0.45), 2.0, 8.0)
	# Objekte: erst Spiegelungen blass, dann Originale
	for pass_i in range(2):
		for kind in lay.keys():
			if not (lay[kind] is Array) or kind == "ground_gaps":
				continue
			var list: Array = lay[kind]
			for i in range(list.size()):
				var e: Array = list[i]
				if pass_i == 0:
					var m := _mirrored(kind, e)
					if not m.is_empty():
						_draw_entry(kind, m, 0.38, false)
				else:
					_draw_entry(kind, e, 1.0, _selected == [kind, i])
	# Vorschau beim Ziehen
	if _drag_start.x >= 0 and _hover.x >= 0:
		var a := Vector2(mini(_drag_start.x, _hover.x), _drag_start.y)
		var w := absi(_hover.x - _drag_start.x) + 1
		var h := 1
		if _tool_kind() == "rect":
			a.y = mini(_drag_start.y, _hover.y)
			h = absi(_hover.y - _drag_start.y) + 1
		elif _tool_kind() == "gap":
			a.y = map_h - 2
			h = 2
		_canvas.draw_rect(_r(Rect2(a, Vector2(w, h))), Color(1, 1, 1, 0.9), false, 2.0)
	elif _hover.x >= 0 and tool != "select":
		_canvas.draw_rect(_r(Rect2(Vector2(_hover), Vector2.ONE)), Color(1, 1, 1, 0.8), false, 2.0)
	if _pipe_first.x >= 0:
		_canvas.draw_rect(_r(Rect2(Vector2(_pipe_first), Vector2.ONE)), Color(0.3, 1, 0.5), false, 3.0)
	if _hover.x >= 0:
		var hit := _hit(Vector2(_hover) + Vector2(0.5, 0.5))
		var txt := "%d, %d" % [_hover.x, _hover.y]
		if not hit.is_empty():
			txt += "  %s %s" % [_kind_name(hit[0]), str(lay[hit[0]][hit[1]])]
		_canvas.draw_string(font, Vector2(12, _canvas.size.y - 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.95, 1.0))

func _draw_entry(kind: String, e: Array, alpha: float, selected: bool) -> void:
	var col := _kind_color(kind)
	col.a *= alpha
	var z := _zoom
	match kind:
		"pyramids":
			var cx := float(e[0])
			var pts := PackedVector2Array([
				_pan + Vector2(cx - float(e[3]), float(e[1])) * z,
				_pan + Vector2(cx + float(e[3]), float(e[1])) * z,
				_pan + Vector2(cx, float(e[2])) * z])
			_canvas.draw_colored_polygon(pts, col)
		"rotators":
			var c := _pan + Vector2(float(e[0]), float(e[1])) * z
			_canvas.draw_arc(c, float(e[2]) * z, 0, TAU, 32, col, 2.0)
			_canvas.draw_line(c - Vector2(float(e[2]), 0) * z, c + Vector2(float(e[3]), 0) * z, col, maxf(2.0, z * 0.3))
		"crate_chains", "ramps", "ball_rows", "ball_chains":
			var a := Vector2(float(e[0]), float(e[1]))
			var b := Vector2(float(e[2]), float(e[3])) if float(e[2]) >= 0.0 else a + Vector2(0, 4)
			_canvas.draw_line(_pan + a * z, _pan + b * z, col, maxf(2.0, z * 0.3))
		"movers":
			var r := _r(Rect2(float(e[0]), float(e[1]), float(e[2]), 1.0))
			_canvas.draw_rect(r, col)
			var off := Vector2(float(e[3]), float(e[4])) * z
			_canvas.draw_dashed_line(r.get_center(), r.get_center() + off, col, 2.0, 6.0)
		"chains":
			var top := _pan + Vector2(float(e[0]), float(e[1])) * z
			var bottom := top + Vector2(0, float(e[2])) * z
			_canvas.draw_line(top, bottom, col, 2.0)
			_canvas.draw_rect(_r(Rect2(float(e[0]) - float(e[3]) * 0.5, float(e[1]) + float(e[2]), float(e[3]), 0.6)), col)
		"reserve":
			for r in _rects(kind, e):
				_canvas.draw_rect(_r(r), Color(1, 1, 1, 0.25 * alpha), false, 1.0)
		_:
			for r in _rects(kind, e):
				var rr := _r(r)
				if kind == "houses":
					_canvas.draw_rect(rr, col, false, maxf(2.0, z * 0.2))
				else:
					_canvas.draw_rect(rr, col)
				if kind == "spikes":
					_canvas.draw_colored_polygon(PackedVector2Array([rr.position + Vector2(0, rr.size.y), rr.end, rr.position + Vector2(rr.size.x * 0.5, 0)]), Color(1, 0.85, 0.85, alpha))
	if selected:
		for r in _rects(kind, e):
			_canvas.draw_rect(_r(r).grow(3.0), Color(1, 1, 1), false, 2.0)
