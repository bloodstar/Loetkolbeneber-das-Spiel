extends Node2D

## Temporäre Capture-Hilfe: rendert Presets und alle Bausteine als PNG.
## Wird nach der Sichtprüfung wieder gelöscht.

const MOD: GDScript = preload("res://scripts/pig_modular_character.gd")
const OUT: String = "C:/Users/joche/AppData/Local/Temp/opencode/"
const WIDTH: float = 1600.0
const HEIGHT: float = 1000.0

const BASE: Dictionary = {
	"body": "original", "eyes": "round", "snout": "round", "nose": "dots",
	"ears": "floppy", "hair": "tuft", "bottom": "shorts", "top": "none",
	"tail": "curly", "tail_side": -1.0, "tail_visible": true,
}

var _pigs: Array[Node2D] = []
var _labels: Array[Dictionary] = []
var _title: String = ""

func _ready() -> void:
	get_window().size = Vector2i(int(WIDTH), int(HEIGHT))
	await get_tree().process_frame
	await _capture_presets()
	await _capture_compare()
	await _capture_clothing()
	await _capture_parts("eyes.png", "AUGEN", "eyes", [
		["round", "Rund"], ["big", "Groß"], ["happy", "Glücklich"],
		["sleepy", "Schläfrig"], ["angry", "Wild"], ["star", "Stern"],
		["heart", "Herz"], ["button", "Knopf"],
	])
	await _capture_parts("snouts.png", "SCHNAUZEN", "snout", [
		["round", "Rund"], ["wide", "Breit"], ["small", "Klein"],
		["long", "Lang"], ["heart", "Herz"],
	])
	await _capture_parts("noses.png", "NASEN", "nose", [
		["dots", "Punkte"], ["wide", "Breite Nüstern"], ["slits", "Schlitze"],
		["heart", "Herz-Nüstern"], ["button", "Knopf"], ["none", "Ohne"],
	])
	await _capture_parts("ears.png", "OHREN", "ears", [
		["floppy", "Schlapp"], ["round", "Rund"], ["pointy", "Spitz"],
		["tall", "Lang"], ["bat", "Fledermaus"], ["small", "Klein"],
		["none", "Ohne"],
	])
	await _capture_parts("hair.png", "HAARE", "hair", [
		["tuft", "Büschel"], ["mane", "Mähne"], ["mohawk", "Irokese"],
		["bangs", "Pony"], ["curl", "Locke"], ["none", "Glatze"],
	])
	await _capture_tails()
	get_tree().quit()

func _reset(title: String) -> void:
	_title = title
	_labels.clear()
	for pig in _pigs:
		if is_instance_valid(pig):
			pig.queue_free()
	_pigs.clear()
	queue_redraw()

func _label(x: float, y: float, text: String) -> void:
	_labels.append({"x": x, "y": y, "text": text})

func _spawn(parts: Dictionary, x: float, feet_y: float, scale: float) -> void:
	var pig: Node2D = MOD.new()
	pig.call("apply_preset", parts)
	pig.set("animate", false)
	pig.set("follow_parent_motion", false)
	pig.scale = Vector2.ONE * scale
	pig.position = Vector2(x, feet_y - 17.1 * scale)
	add_child(pig)
	_pigs.append(pig)

func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUT + name)
	print("CAPTURE ", name, " -> ", error)

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), Color(0.10, 0.11, 0.15, 1.0))
	for x in range(0, int(WIDTH) + 1, 100):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), HEIGHT), Color(1, 1, 1, 0.035), 1.0)
	for y in range(0, int(HEIGHT) + 1, 100):
		draw_line(Vector2(0.0, float(y)), Vector2(WIDTH, float(y)), Color(1, 1, 1, 0.035), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40.0, 52.0), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.72, 0.35, 1.0))
	for entry in _labels:
		draw_string(
			font,
			Vector2(float(entry["x"]) - 130.0, float(entry["y"])),
			str(entry["text"]),
			HORIZONTAL_ALIGNMENT_CENTER,
			260.0,
			16,
			Color(0.86, 0.90, 0.98, 0.95)
		)

func _capture_presets() -> void:
	_reset("PRESETS")
	var presets: Array[Dictionary] = [
		{"label": "Original", "parts": BASE.duplicate()},
		{"label": "Mascot", "parts": _merge({"body": "mascot", "eyes": "big"})},
		{"label": "Comic", "parts": _merge({"body": "comic", "snout": "wide", "nose": "wide", "ears": "pointy", "tail": "bushy"})},
		{"label": "Keiler", "parts": _merge({"body": "boar", "eyes": "angry", "snout": "wide", "nose": "wide", "ears": "small", "hair": "mane", "tail": "straight"})},
		{"label": "Slim", "parts": _merge({"body": "slim", "eyes": "sleepy", "snout": "small", "ears": "tall", "hair": "curl"})},
	]
	for i in presets.size():
		var x := 160.0 + 320.0 * float(i)
		_spawn(presets[i]["parts"], x, 470.0, 6.6)
		_label(x, 540.0, str(presets[i]["label"]))
	await _capture("modular_presets.png")

func _capture_compare() -> void:
	_reset("ORIGINAL-VERGLEICH  ·  links: PigCharacter, rechts: Baukasten-Preset")
	var original := PigCharacter.new()
	original.set("animate", false)
	original.set("follow_parent_motion", false)
	original.scale = Vector2.ONE * 8.0
	original.position = Vector2(520.0, 470.0 - 17.1 * 8.0)
	add_child(original)
	_pigs.append(original)
	_spawn(BASE, 1080.0, 470.0, 8.0)
	_label(520.0, 560.0, "PigCharacter (Original)")
	_label(1080.0, 560.0, "Baukasten: Original-Preset")
	await _capture("modular_compare.png")

func _capture_clothing() -> void:
	_reset("KLEIDUNG  ·  Spalten: Unterteil, Zeilen: Oberteil")
	var bottoms: Array[Array] = [
		["shorts", "Kurze Hose"],
		["pants", "Lange Hose"],
		["long_skirt", "Langer Rock"],
		["mini_skirt", "Minirock"],
	]
	var tops: Array[Array] = [
		["none", "Ohne Oberteil"],
		["muscle", "Muscle Shirt"],
		["bikini", "Bikini Top"],
		["robe", "Kleid / Robe"],
	]
	for row in tops.size():
		for col in bottoms.size():
			var x := 200.0 + 400.0 * float(col)
			var feet := 225.0 + 245.0 * float(row)
			_spawn(
				_merge({"bottom": bottoms[col][0], "top": tops[row][0]}),
				x,
				feet,
				3.7
			)
			if row == 0:
				_label(x, 250.0 - 120.0, str(bottoms[col][1]))
		_label(80.0, 225.0 + 245.0 * float(row) - 95.0, str(tops[row][1]))
	await _capture("modular_clothing.png")

func _capture_parts(
	name: String,
	title: String,
	key: String,
	values: Array
) -> void:
	_reset(title)
	var columns := 4
	var spacing := 380.0
	for i in values.size():
		var row := i / columns
		var col := i % columns
		var x := 200.0 + spacing * float(col)
		var feet := 400.0 + 400.0 * float(row)
		_spawn(_merge({key: values[i][0]}), x, feet, 6.0)
		_label(x, feet + 55.0, str(values[i][1]))
	await _capture(name)

func _capture_tails() -> void:
	_reset("SCHWÄNZE  ·  links/rechts")
	var tails: Array[Array] = [
		["curly", "Ringel"],
		["straight", "Gerade"],
		["bushy", "Buschig"],
		["short", "Kurz"],
		["none", "Kein Schwanz"],
	]
	for i in tails.size():
		var x := 200.0 + 380.0 * float(i % 4)
		var feet := 400.0 + 400.0 * float(i / 4)
		_spawn(_merge({"tail": tails[i][0], "tail_side": -1.0}), x, feet, 6.0)
		_label(x, feet + 55.0, "%s (links)" % tails[i][1])
	for i in tails.size():
		var x := 200.0 + 380.0 * float(i % 4)
		var feet := 800.0 + 400.0 * float(i / 4)
		_spawn(_merge({"tail": tails[i][0], "tail_side": 1.0}), x, feet, 6.0)
		_label(x, feet + 55.0, "%s (rechts)" % tails[i][1])
	await _capture("modular_tails.png")

func _merge(overrides: Dictionary) -> Dictionary:
	var parts := BASE.duplicate()
	for key in overrides.keys():
		parts[key] = overrides[key]
	return parts
