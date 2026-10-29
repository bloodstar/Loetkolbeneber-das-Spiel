extends Node2D

## Testumgebung für PigCharacter.
##
## Die Figur animiert sich im Spiel aus der Bewegung ihres Parents
## (CharacterBody2D): Laufen, Springen, Fallen, Landen und Treffer. Diese Demo
## stellt dafür einen steuerbaren Rig mit echter Bodenkollision bereit und
## bietet Buttons für jede Animation sowie einen automatischen Spielablauf.
##
## Start:
##   godot --path . scenes/demo/pig_character_demo.tscn
##
## Tastatur: 1–9 Animationen, Leertaste = Springen, A = Auto, Esc = Beenden.

const PANEL_WIDTH: float = 460.0
const FLOOR_Y: float = 700.0
const RUN_SPEED: float = 260.0
const GROUND_ACCEL: float = 1800.0
const AIR_ACCEL: float = 220.0
const GRAVITY: float = 1700.0
const JUMP_SPEED: float = -760.0
const STAGE_MARGIN: float = 110.0
const MIN_ZOOM: float = 2.0
const MAX_ZOOM: float = 12.0
const DEFAULT_ZOOM: float = 7.0
# PigCharacter zeichnet die Hufunterkante bei lokal y ≈ 17.1, damit die Füße
# exakt auf der Bodenlinie stehen.
const PIG_FOOT_OFFSET: float = 17.1

const DEFAULT_FUR: Color = Color(0.91, 0.60, 0.67, 1.0)
const DEFAULT_EYES: Color = Color(0.18, 0.14, 0.20, 1.0)
const DEFAULT_PANTS: Color = Color(0.24, 0.36, 0.56, 1.0)
const DEFAULT_TOP: Color = Color(0.86, 0.32, 0.38, 1.0)
# Entspricht dem bisherigen Haarton (Fell um 18 % abgedunkelt).
const DEFAULT_HAIR: Color = Color(0.75, 0.49, 0.55, 1.0)
const DEFAULT_BELT_WIDTH: float = 2.7
const TEAM_BLUE: Color = Color(0.32, 0.62, 1.0, 1.0)

const MODULAR_PATH: String = "res://scripts/pig_modular_character.gd"

# Die fünf bisherigen Figuren sind jetzt Presets: Sie setzen nur noch die
# Teil-IDs des Baukastens. Jedes Teil lässt sich danach einzeln ändern.
const PRESETS: Array[Dictionary] = [
	{
		"name": "Original",
		"label": "Original – Spielschwein",
		"parts": {
			"body": "original", "eyes": "round", "snout": "round", "nose": "dots",
			"ears": "floppy", "hair": "tuft", "bottom": "shorts", "top": "none",
			"tail": "curly", "tail_side": -1.0, "tail_visible": true,
		},
	},
	{
		"name": "Mascot",
		"label": "Mascot – rund & knuffig",
		"parts": {
			"body": "mascot", "eyes": "big", "snout": "chubby", "nose": "dots",
			"ears": "floppy", "hair": "tuft", "bottom": "shorts", "top": "none",
			"tail": "curly", "tail_side": -1.0, "tail_visible": true,
		},
	},
	{
		"name": "Comic",
		"label": "Comic – breit & grafisch",
		"parts": {
			"body": "comic", "eyes": "round", "snout": "wide", "nose": "wide",
			"ears": "pointy", "hair": "tuft", "bottom": "shorts", "top": "none",
			"tail": "bushy", "tail_side": -1.0, "tail_visible": true,
		},
	},
	{
		"name": "Keiler",
		"label": "Keiler – kantig & wild",
		"parts": {
			"body": "boar", "eyes": "angry", "snout": "boar", "nose": "wide",
			"ears": "small", "hair": "mane", "bottom": "shorts", "top": "none",
			"tail": "straight", "tail_side": -1.0, "tail_visible": true,
		},
	},
	{
		"name": "Slim",
		"label": "Slim – schlank & elegant",
		"parts": {
			"body": "slim", "eyes": "sleepy", "snout": "small", "nose": "dots",
			"ears": "tall", "hair": "curl", "bottom": "shorts", "top": "none",
			"tail": "curly", "tail_side": -1.0, "tail_visible": true,
		},
	},
]

# Bausteine des Baukastens. Jede ID entspricht einem Zweig im modularen
# Zeichenskript; die Labels erklären die Wirkung.
const BODY_OPTIONS: Array[Dictionary] = [
	{"id": "original", "label": "Original – ausgewogen"},
	{"id": "mascot", "label": "Mascot – rund & knuffig"},
	{"id": "comic", "label": "Comic – breit & grafisch"},
	{"id": "boar", "label": "Keiler – breit & wild"},
	{"id": "slim", "label": "Slim – schlank & groß"},
]
const EYE_OPTIONS: Array[Dictionary] = [
	{"id": "round", "label": "Rund – normal"},
	{"id": "big", "label": "Groß – süß"},
	{"id": "happy", "label": "Glücklich – knuffig"},
	{"id": "sleepy", "label": "Schläfrig – entspannt"},
	{"id": "angry", "label": "Wild – mit Brauen"},
	{"id": "button", "label": "Knopf – comic"},
]
const SNOUT_OPTIONS: Array[Dictionary] = [
	{"id": "round", "label": "Rund – normal"},
	{"id": "wide", "label": "Breit – keilig"},
	{"id": "small", "label": "Klein – süß"},
	{"id": "long", "label": "Lang – schnüffelnd"},
	{"id": "heart", "label": "Herz – süß"},
	{"id": "chubby", "label": "Pausback – knuffig"},
	{"id": "boar", "label": "Kantig – wild"},
]
const NOSE_OPTIONS: Array[Dictionary] = [
	{"id": "dots", "label": "Punkte – normal"},
	{"id": "wide", "label": "Breite Nüstern"},
	{"id": "slits", "label": "Schlitze – wild"},
	{"id": "button", "label": "Knopf – knuffig"},
	{"id": "none", "label": "Ohne"},
]
const EAR_OPTIONS: Array[Dictionary] = [
	{"id": "floppy", "label": "Schlapp – normal"},
	{"id": "round", "label": "Rund – süß"},
	{"id": "pointy", "label": "Spitz – frech"},
	{"id": "tall", "label": "Lang – elegant"},
	{"id": "bat", "label": "Fledermaus – wild"},
	{"id": "small", "label": "Klein – keilig"},
	{"id": "none", "label": "Ohne"},
]
const HAIR_OPTIONS: Array[Dictionary] = [
	{"id": "tuft", "label": "Büschel – normal"},
	{"id": "mane", "label": "Mähne – wild"},
	{"id": "mohawk", "label": "Irokese – punk"},
	{"id": "bangs", "label": "Pony – süß"},
	{"id": "curl", "label": "Locke – elegant"},
	{"id": "none", "label": "Glatze"},
]
const BOTTOM_OPTIONS: Array[Dictionary] = [
	{"id": "shorts", "label": "Kurze Hose"},
	{"id": "pants", "label": "Lange Hose"},
	{"id": "long_skirt", "label": "Langer Rock (Knöchel)"},
	{"id": "mini_skirt", "label": "Minirock"},
]
const TOP_OPTIONS: Array[Dictionary] = [
	{"id": "none", "label": "Ohne Oberteil"},
	{"id": "muscle", "label": "Muscle Shirt"},
	{"id": "bikini", "label": "Bikini Top"},
	{"id": "robe", "label": "Kleid / Robe"},
]
const TAIL_OPTIONS: Array[Dictionary] = [
	{"id": "curly", "label": "Ringel – normal"},
	{"id": "spiral", "label": "Spirale – verspielt"},
	{"id": "straight", "label": "Keck nach oben"},
	{"id": "droopy", "label": "Hängend – gemütlich"},
	{"id": "bushy", "label": "Quaste – wild"},
	{"id": "short", "label": "Stummel – knuffig"},
	{"id": "none", "label": "Kein Schwanz"},
]
const GALLERY_ZOOM: float = 4.6

var rig: CharacterBody2D
var pig: PigCharacter

var _mode: String = "idle"
var _land_mode: String = "idle"
var _run_dir: float = 1.0
var _was_on_floor: bool = true
var _auto: bool = false
var _auto_token: int = 0
var _zoom: float = DEFAULT_ZOOM
var _light_bg: bool = false

var _status_label: Label
var _auto_toggle: CheckButton
var _zoom_slider: HSlider
var _speed_slider: HSlider
var _fur_picker: ColorPickerButton
var _eye_picker: ColorPickerButton
var _pants_picker: ColorPickerButton
var _outfit_option: OptionButton
var _tusk_option: OptionButton
var _team_check: CheckButton
var _animate_check: CheckButton
var _bg_check: CheckButton
var _gallery_check: CheckButton
var _preset_option: OptionButton
var _top_picker: ColorPickerButton
var _body_option: OptionButton
var _eyes_option: OptionButton
var _snout_option: OptionButton
var _nose_option: OptionButton
var _ears_option: OptionButton
var _hair_option: OptionButton
var _bottom_option: OptionButton
var _top_option: OptionButton
var _tail_option: OptionButton
var _tail_side_option: OptionButton
var _tail_visible_check: CheckButton
var _hair_picker: ColorPickerButton
var _belt_check: CheckButton
var _belt_slider: HSlider
var _eye_size_slider: HSlider
var _snout_size_slider: HSlider
var _preset_index: int = 0
var _custom_parts: bool = false
var _gallery_visible: bool = false
var _gallery: Array[PigCharacter] = []
var _outfit_ids: Array[String] = []
var _tusk_ids: Array[String] = []

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	_build_stage()
	_build_ui()
	_apply_zoom(DEFAULT_ZOOM)
	_apply_look()
	_play_idle()

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# --- Bühne ---

func _build_stage() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector2(800.0, FLOOR_Y + 30.0)
	var floor_collision := CollisionShape2D.new()
	var floor_rect := RectangleShape2D.new()
	floor_rect.size = Vector2(3200.0, 60.0)
	floor_collision.shape = floor_rect
	floor_body.add_child(floor_collision)
	add_child(floor_body)

	rig = CharacterBody2D.new()
	rig.name = "Rig"
	rig.position = Vector2(420.0, FLOOR_Y)
	rig.floor_snap_length = 10.0
	add_child(rig)

	var body_collision := CollisionShape2D.new()
	var body_rect := RectangleShape2D.new()
	body_rect.size = Vector2(90.0, 150.0)
	body_collision.shape = body_rect
	body_collision.position = Vector2(0.0, -75.0)
	rig.add_child(body_collision)

	pig = _create_pig()
	pig.name = "Pig"
	pig.position = Vector2(0.0, -PIG_FOOT_OFFSET * _zoom)
	rig.add_child(pig)

func _stage_width() -> float:
	return maxf(420.0, get_viewport_rect().size.x - PANEL_WIDTH)

func _on_viewport_resized() -> void:
	queue_redraw()
	if rig != null:
		rig.position.x = clampf(rig.position.x, STAGE_MARGIN, _stage_width() - STAGE_MARGIN)
	if _gallery_visible:
		_build_gallery()

func _draw() -> void:
	var width := _stage_width()
	var bg := Color(0.10, 0.11, 0.15) if not _light_bg else Color(0.92, 0.91, 0.88)
	var grid := Color(1.0, 1.0, 1.0, 0.05) if not _light_bg else Color(0.0, 0.0, 0.0, 0.07)
	var floor_color := Color(0.16, 0.18, 0.23) if not _light_bg else Color(0.78, 0.77, 0.73)
	var floor_line := Color(0.42, 0.55, 0.80, 1.0) if not _light_bg else Color(0.35, 0.42, 0.55, 1.0)
	var bound_color := Color(1.0, 0.55, 0.35, 0.55)

	draw_rect(Rect2(0.0, 0.0, width, 1000.0), bg)
	for x in range(0, int(width) + 1, 50):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), FLOOR_Y), grid, 1.0)
	for y in range(0, int(FLOOR_Y) + 1, 50):
		draw_line(Vector2(0.0, float(y)), Vector2(width, float(y)), grid, 1.0)
	draw_rect(Rect2(0.0, FLOOR_Y, width, 1000.0 - FLOOR_Y), floor_color)
	draw_line(Vector2(0.0, FLOOR_Y), Vector2(width, FLOOR_Y), floor_line, 2.0)

	# Laufgrenzen andeuten.
	for x in [STAGE_MARGIN, width - STAGE_MARGIN]:
		draw_line(Vector2(x, FLOOR_Y - 26.0), Vector2(x, FLOOR_Y), bound_color, 2.0)

	# Maßstab: 100 px Referenzlinie unten links.
	var ref_y := FLOOR_Y + 70.0
	var ref_color := Color(1.0, 1.0, 1.0, 0.35) if not _light_bg else Color(0.0, 0.0, 0.0, 0.30)
	draw_line(Vector2(40.0, ref_y), Vector2(140.0, ref_y), ref_color, 2.0)
	draw_line(Vector2(40.0, ref_y - 5.0), Vector2(40.0, ref_y + 5.0), ref_color, 2.0)
	draw_line(Vector2(140.0, ref_y - 5.0), Vector2(140.0, ref_y + 5.0), ref_color, 2.0)

	# Namen der Presets in der Galerie.
	if _gallery_visible:
		var label_color := Color(0.85, 0.88, 0.95, 0.9) if not _light_bg else Color(0.18, 0.20, 0.26, 0.9)
		var spacing := width / float(PRESETS.size())
		for i in PRESETS.size():
			var center_x := spacing * (float(i) + 0.5)
			draw_string(
				ThemeDB.fallback_font,
				Vector2(center_x - 80.0, FLOOR_Y + 36.0),
				str(PRESETS[i]["name"]),
				HORIZONTAL_ALIGNMENT_CENTER,
				160.0,
				15,
				label_color
			)

# --- Steuerung ---

func _physics_process(delta: float) -> void:
	if rig == null or pig == null:
		return

	if _mode == "run":
		rig.velocity.x = move_toward(rig.velocity.x, _run_dir * RUN_SPEED, GROUND_ACCEL * delta)
		pig.flip_h = _run_dir < 0.0
	elif _mode == "idle":
		rig.velocity.x = move_toward(rig.velocity.x, 0.0, GROUND_ACCEL * delta)
	else:
		rig.velocity.x = move_toward(rig.velocity.x, 0.0, AIR_ACCEL * delta)

	if not rig.is_on_floor():
		rig.velocity.y += GRAVITY * delta
	elif rig.velocity.y > 0.0:
		rig.velocity.y = 0.0

	rig.move_and_slide()

	var right := _stage_width() - STAGE_MARGIN
	if rig.position.x < STAGE_MARGIN:
		rig.position.x = STAGE_MARGIN
		if _mode == "run" and _run_dir < 0.0:
			_run_dir = 1.0
	elif rig.position.x > right:
		rig.position.x = right
		if _mode == "run" and _run_dir > 0.0:
			_run_dir = -1.0

	# Notbremse, falls die Figur durch eine Teleport-Position unter den Boden fällt.
	if rig.position.y > FLOOR_Y + 200.0:
		rig.position = Vector2(rig.position.x, FLOOR_Y)
		rig.velocity = Vector2.ZERO

	var on_floor := rig.is_on_floor()
	if on_floor and not _was_on_floor:
		_mode = _land_mode
	_was_on_floor = on_floor

func _process(_delta: float) -> void:
	if _status_label == null or rig == null:
		return
	if _gallery_visible:
		_status_label.text = "GALERIE · %d Presets im Vergleich" % PRESETS.size()
		return
	var parts_label := "Eigener Charakter" if _custom_parts else str(PRESETS[_preset_index]["name"])
	_status_label.text = "%s  ·  %s  ·  %s  ·  v = %.0f / %.0f px/s  ·  Zoom %.1fx" % [
		_mode.to_upper(),
		parts_label,
		"BODEN" if rig.is_on_floor() else "LUFT",
		rig.velocity.x,
		rig.velocity.y,
		_zoom,
	]

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1: _manual_anim("idle")
		KEY_2: _manual_anim("run_right")
		KEY_3: _manual_anim("run_left")
		KEY_4: _manual_anim("jump")
		KEY_5: _manual_anim("fall")
		KEY_6: _manual_anim("land")
		KEY_7: _manual_anim("hit")
		KEY_8: _manual_anim("hit_light")
		KEY_9: _manual_anim("flip")
		KEY_A: _auto_toggle.button_pressed = not _auto_toggle.button_pressed
		KEY_SPACE: _manual_anim("jump")
		KEY_ESCAPE: get_tree().quit()

# --- Animationen ---

func _manual_anim(anim: String) -> void:
	_cancel_auto()
	match anim:
		"idle": _play_idle()
		"run_right": _play_run(1.0)
		"run_left": _play_run(-1.0)
		"jump": _play_jump()
		"fall": _play_fall()
		"land": _play_land()
		"hit": _play_hit(1.0)
		"hit_light": _play_hit(0.35)
		"flip": _play_flip()

func _play_idle() -> void:
	_mode = "idle"

func _play_run(direction: float) -> void:
	_run_dir = signf(direction) if direction != 0.0 else 1.0
	_mode = "run"

func _play_jump() -> void:
	if not rig.is_on_floor():
		return
	_land_mode = "run" if _mode == "run" else "idle"
	rig.velocity.y = JUMP_SPEED
	_mode = "air"

func _play_fall() -> void:
	_land_mode = "idle"
	_mode = "air"
	rig.position.y = FLOOR_Y - 430.0
	rig.velocity = Vector2(0.0, 120.0)

func _play_land() -> void:
	_land_mode = "idle"
	_mode = "air"
	rig.position.y = FLOOR_Y - 190.0
	rig.velocity = Vector2(0.0, 820.0)

func _play_hit(strength: float) -> void:
	var direction := Vector2(randf_range(-0.6, 1.0), randf_range(-0.8, 0.2)).normalized()
	pig.play_hit(direction, strength)

func _play_flip() -> void:
	pig.flip_h = not pig.flip_h

# --- Auto-Ablauf ---

func _on_auto_toggled(pressed: bool) -> void:
	_auto = pressed
	_auto_token += 1
	if pressed:
		_run_auto(_auto_token)

func _cancel_auto() -> void:
	_auto_token += 1
	if _auto:
		_auto = false
		if _auto_toggle != null:
			_auto_toggle.set_pressed_no_signal(false)

func _cancelled(token: int) -> bool:
	return not is_inside_tree() or not _auto or token != _auto_token

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

# Spieltypischer Ablauf: stehen, laufen, springen, Richtung wechseln, Treffer,
# aus großer Höhe fallen und landen.
func _run_auto(token: int) -> void:
	while not _cancelled(token):
		_play_idle()
		await _wait(1.0)
		if _cancelled(token): return

		_play_run(1.0)
		await _wait(1.8)
		if _cancelled(token): return

		_play_jump()
		await _wait(1.1)
		if _cancelled(token): return

		_play_run(-1.0)
		await _wait(1.8)
		if _cancelled(token): return

		_play_hit(1.0)
		await _wait(0.8)
		if _cancelled(token): return

		_play_idle()
		await _wait(0.8)
		if _cancelled(token): return

		_play_fall()
		await _wait(1.4)
		if _cancelled(token): return

		_play_idle()
		await _wait(0.8)
		if _cancelled(token): return

		_play_hit(0.35)
		await _wait(0.6)
		if _cancelled(token): return

		_play_flip()
		await _wait(0.8)

# --- Darstellung ---

func _apply_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if pig == null:
		return
	pig.scale = Vector2.ONE * _zoom
	pig.position = Vector2(0.0, -PIG_FOOT_OFFSET * _zoom)

func _apply_look() -> void:
	_style_pig(pig)
	if _is_modular(pig):
		_apply_parts(pig)
	for variant in _gallery:
		if is_instance_valid(variant):
			_style_pig(variant)

func _style_pig(target: PigCharacter) -> void:
	if target == null:
		return
	target.setup(_fur_picker.color, _eye_picker.color, _pants_picker.color)
	target.set_outfit(_selected_outfit_id())
	target.set_tusk_shape(_selected_tusk_id())
	target.set_team_color(TEAM_BLUE if _team_check.button_pressed else Color(0.0, 0.0, 0.0, 0.0))
	if _is_modular(target) and _top_picker != null:
		target.set("top_color", _top_picker.color)
		target.set("hair_color", _hair_picker.color)

func _is_modular(target: PigCharacter) -> bool:
	return target != null and target.has_method("apply_preset")

## Überträgt die aktuell gewählten Bausteine auf die Hauptfigur.
func _apply_parts(target: PigCharacter) -> void:
	if not _is_modular(target):
		return
	target.set("body_style", _option_id(_body_option, BODY_OPTIONS))
	target.set("eye_style", _option_id(_eyes_option, EYE_OPTIONS))
	target.set("snout_style", _option_id(_snout_option, SNOUT_OPTIONS))
	target.set("nose_style", _option_id(_nose_option, NOSE_OPTIONS))
	target.set("ear_style", _option_id(_ears_option, EAR_OPTIONS))
	target.set("hair_style", _option_id(_hair_option, HAIR_OPTIONS))
	target.set("bottom_style", _option_id(_bottom_option, BOTTOM_OPTIONS))
	target.set("top_style", _option_id(_top_option, TOP_OPTIONS))
	target.set("tail_style", _option_id(_tail_option, TAIL_OPTIONS))
	target.set("tail_side", -1.0 if _tail_side_option.selected == 0 else 1.0)
	target.set("tail_visible", _tail_visible_check.button_pressed)
	target.set("belt_visible", _belt_check.button_pressed)
	target.set("belt_width", _belt_slider.value)
	target.set("eye_size", _eye_size_slider.value)
	target.set("snout_size", _snout_size_slider.value)
	target.set("top_color", _top_picker.color)
	target.queue_redraw()

func _option_id(option: OptionButton, catalog: Array[Dictionary]) -> String:
	if option == null or catalog.is_empty():
		return ""
	return str(catalog[clampi(option.selected, 0, catalog.size() - 1)]["id"])

## Setzt die Teil-Dropdowns auf die Werte eines Presets, ohne Signale auszulösen.
func _sync_part_options(parts: Dictionary) -> void:
	_sync_option(_body_option, BODY_OPTIONS, str(parts.get("body", "original")))
	_sync_option(_eyes_option, EYE_OPTIONS, str(parts.get("eyes", "round")))
	_sync_option(_snout_option, SNOUT_OPTIONS, str(parts.get("snout", "round")))
	_sync_option(_nose_option, NOSE_OPTIONS, str(parts.get("nose", "dots")))
	_sync_option(_ears_option, EAR_OPTIONS, str(parts.get("ears", "floppy")))
	_sync_option(_hair_option, HAIR_OPTIONS, str(parts.get("hair", "tuft")))
	_sync_option(_bottom_option, BOTTOM_OPTIONS, str(parts.get("bottom", "shorts")))
	_sync_option(_top_option, TOP_OPTIONS, str(parts.get("top", "none")))
	_sync_option(_tail_option, TAIL_OPTIONS, str(parts.get("tail", "curly")))
	_tail_side_option.select(0 if float(parts.get("tail_side", -1.0)) < 0.0 else 1)
	_tail_visible_check.set_pressed_no_signal(bool(parts.get("tail_visible", true)))
	_belt_check.set_pressed_no_signal(bool(parts.get("belt", true)))
	_belt_slider.set_value_no_signal(float(parts.get("belt_width", DEFAULT_BELT_WIDTH)))
	_eye_size_slider.set_value_no_signal(float(parts.get("eye_size", 1.0)))
	_snout_size_slider.set_value_no_signal(float(parts.get("snout_size", 1.0)))

func _sync_option(option: OptionButton, catalog: Array[Dictionary], id: String) -> void:
	if option == null:
		return
	for i in catalog.size():
		if str(catalog[i]["id"]) == id:
			option.select(i)
			return
	option.select(0)

func _on_preset_selected(index: int) -> void:
	if index < 0 or index >= PRESETS.size():
		return
	_preset_index = index
	_custom_parts = false
	_preset_option.select(index)
	_sync_part_options(PRESETS[index]["parts"])
	_apply_look()

## Jede Änderung an einem einzelnen Baustein löst das Preset und markiert die
## Figur als eigenen Charakter.
func _on_part_changed(_index: int = 0) -> void:
	_custom_parts = true
	_preset_option.select(PRESETS.size())
	_apply_look()

## Würfelt alle Bausteine neu (Teile, Schwanz, Gürtel, Hauer, Outfit).
## Farben bleiben unverändert.
func _randomize_parts() -> void:
	for option: OptionButton in [
		_body_option, _eyes_option, _snout_option, _nose_option, _ears_option,
		_hair_option, _bottom_option, _top_option, _tail_option, _tail_side_option,
		_tusk_option, _outfit_option,
	]:
		option.select(randi() % option.item_count)
	# "Kein Schwanz" bzw. unsichtbar nur selten, sonst fällt er kaum auf.
	_tail_visible_check.set_pressed_no_signal(randf() < 0.85)
	_belt_check.set_pressed_no_signal(randf() < 0.7)
	_belt_slider.set_value_no_signal(snappedf(randf_range(_belt_slider.min_value, _belt_slider.max_value), _belt_slider.step))
	# Größen nur moderat streuen, Extreme wirken beim Würfeln meist kaputt.
	_eye_size_slider.set_value_no_signal(snappedf(randf_range(0.05, 1.25), _eye_size_slider.step))
	_snout_size_slider.set_value_no_signal(snappedf(randf_range(0.05, 1.25), _snout_size_slider.step))
	_on_part_changed()

func _selected_outfit_id() -> String:
	if _outfit_option.selected > 0 and _outfit_option.selected <= _outfit_ids.size():
		return _outfit_ids[_outfit_option.selected - 1]
	return ""

func _selected_tusk_id() -> String:
	if _tusk_ids.is_empty():
		return "small"
	return _tusk_ids[clampi(_tusk_option.selected, 0, _tusk_ids.size() - 1)]

func _on_animate_toggled(pressed: bool) -> void:
	if pig != null:
		pig.animate = pressed

func _reset_look() -> void:
	_cancel_auto()
	_play_idle()
	_fur_picker.color = DEFAULT_FUR
	_eye_picker.color = DEFAULT_EYES
	_pants_picker.color = DEFAULT_PANTS
	_top_picker.color = DEFAULT_TOP
	_hair_picker.color = DEFAULT_HAIR
	_outfit_option.select(0)
	_tusk_option.select(maxi(0, _tusk_ids.find("small")))
	_team_check.set_pressed_no_signal(false)
	_preset_index = 0
	_custom_parts = false
	_preset_option.select(0)
	_sync_part_options(PRESETS[0]["parts"])
	_zoom_slider.set_value_no_signal(DEFAULT_ZOOM)
	_speed_slider.set_value_no_signal(1.0)
	Engine.time_scale = 1.0
	_animate_check.set_pressed_no_signal(true)
	pig.animate = true
	if _bg_check != null:
		_bg_check.set_pressed_no_signal(false)
	_light_bg = false
	queue_redraw()
	_apply_zoom(DEFAULT_ZOOM)
	_apply_look()

func _on_speed_changed(value: float) -> void:
	Engine.time_scale = clampf(value, 0.1, 1.0)

# --- Baukasten / Presets ---

func _create_pig() -> PigCharacter:
	var script: GDScript = load(MODULAR_PATH)
	if script == null:
		push_error("Modulares Design-Skript fehlt: " + MODULAR_PATH)
		return PigCharacter.new()
	return script.new() as PigCharacter

func _replace_pig() -> void:
	if pig == null:
		return
	var old := pig
	var next := _create_pig()
	next.name = "Pig"
	next.flip_h = old.flip_h
	next.animate = old.animate
	rig.add_child(next)
	pig = next
	old.queue_free()
	_apply_zoom(_zoom)

func _on_gallery_toggled(pressed: bool) -> void:
	_gallery_visible = pressed
	rig.visible = not pressed
	if pressed:
		_build_gallery()
	else:
		_clear_gallery()
	queue_redraw()

func _build_gallery() -> void:
	_clear_gallery()
	var spacing := _stage_width() / float(PRESETS.size())
	for i in PRESETS.size():
		var variant := _create_pig()
		variant.follow_parent_motion = false
		variant.animate = true
		variant.scale = Vector2.ONE * GALLERY_ZOOM
		variant.position = Vector2(
			spacing * (float(i) + 0.5),
			FLOOR_Y - PIG_FOOT_OFFSET * GALLERY_ZOOM
		)
		add_child(variant)
		if _is_modular(variant):
			variant.call("apply_preset", PRESETS[i]["parts"])
			variant.set("top_color", _top_picker.color)
			variant.set("hair_color", _hair_picker.color)
		_gallery.append(variant)
	_apply_look()

func _clear_gallery() -> void:
	for variant in _gallery:
		if is_instance_valid(variant):
			variant.queue_free()
	_gallery.clear()

# --- UI ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	var ui_root := Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)

	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -PANEL_WIDTH
	panel.offset_right = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.98)
	style.border_width_left = 2
	style.border_color = Color(0.26, 0.32, 0.45, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	ui_root.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "PIG-CHARACTER DEMO"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.35, 1.0))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "Jede Animation einzeln testen. Der Auto-Modus spielt einen typischen Spielablauf. Tasten 1–9, Leertaste, A."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 1.0))
	box.add_child(hint)

	_status_label = Label.new()
	_status_label.text = "IDLE"
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70, 1.0))
	box.add_child(_status_label)

	box.add_child(HSeparator.new())
	box.add_child(_section_label("PRESET"))

	var design_row := HBoxContainer.new()
	design_row.add_theme_constant_override("separation", 8)
	box.add_child(design_row)

	_preset_option = OptionButton.new()
	_preset_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preset_option.custom_minimum_size = Vector2(0.0, 34.0)
	for preset in PRESETS:
		_preset_option.add_item(str(preset["label"]))
	_preset_option.add_item("Eigener Charakter")
	_preset_option.set_item_disabled(PRESETS.size(), true)
	_preset_option.item_selected.connect(_on_preset_selected)
	design_row.add_child(_preset_option)

	_gallery_check = CheckButton.new()
	_gallery_check.text = "Galerie"
	_gallery_check.tooltip_text = "Alle fünf Presets gleichzeitig vergleichen"
	_gallery_check.toggled.connect(_on_gallery_toggled)
	design_row.add_child(_gallery_check)

	box.add_child(HSeparator.new())
	box.add_child(_section_label("BAUKASTEN"))

	var random_btn := Button.new()
	random_btn.text = "Zufällig würfeln"
	random_btn.tooltip_text = "Alle Bausteine zufällig wählen (Farben bleiben)"
	random_btn.custom_minimum_size = Vector2(0.0, 36.0)
	random_btn.focus_mode = Control.FOCUS_NONE
	random_btn.pressed.connect(_randomize_parts)
	box.add_child(random_btn)

	var part_grid := GridContainer.new()
	part_grid.columns = 2
	part_grid.add_theme_constant_override("h_separation", 10)
	part_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(part_grid)

	_body_option = _add_part_row(part_grid, "Körper", BODY_OPTIONS)
	_eyes_option = _add_part_row(part_grid, "Augen", EYE_OPTIONS)
	_eye_size_slider = _add_size_row(part_grid, "Augengröße")
	_snout_option = _add_part_row(part_grid, "Rüssel", SNOUT_OPTIONS)
	_snout_size_slider = _add_size_row(part_grid, "Rüsselgröße")
	_nose_option = _add_part_row(part_grid, "Nasenlöcher", NOSE_OPTIONS)
	_ears_option = _add_part_row(part_grid, "Ohren", EAR_OPTIONS)
	_hair_option = _add_part_row(part_grid, "Haare", HAIR_OPTIONS)
	_bottom_option = _add_part_row(part_grid, "Unterteil", BOTTOM_OPTIONS)
	_top_option = _add_part_row(part_grid, "Oberteil", TOP_OPTIONS)

	_belt_check = CheckButton.new()
	_belt_check.text = "Gürtel"
	_belt_check.button_pressed = true
	_belt_check.toggled.connect(func(_pressed: bool): _on_part_changed())
	part_grid.add_child(_belt_check)
	_belt_slider = HSlider.new()
	_belt_slider.min_value = 1.0
	_belt_slider.max_value = 4.5
	_belt_slider.step = 0.1
	_belt_slider.value = DEFAULT_BELT_WIDTH
	_belt_slider.custom_minimum_size = Vector2(160.0, 24.0)
	_belt_slider.tooltip_text = "Gürteldicke"
	_belt_slider.value_changed.connect(func(_value: float): _on_part_changed())
	part_grid.add_child(_belt_slider)

	_tail_option = _add_part_row(part_grid, "Schwanz", TAIL_OPTIONS)

	_tail_side_option = OptionButton.new()
	_tail_side_option.custom_minimum_size = Vector2(160.0, 32.0)
	_tail_side_option.add_item("Links")
	_tail_side_option.add_item("Rechts")
	_tail_side_option.item_selected.connect(_on_part_changed)
	_add_labeled(part_grid, "Schwanzseite", _tail_side_option)

	_tail_visible_check = CheckButton.new()
	_tail_visible_check.text = "Schwanz sichtbar"
	_tail_visible_check.button_pressed = true
	_tail_visible_check.toggled.connect(func(_pressed: bool): _on_part_changed())
	part_grid.add_child(_tail_visible_check)

	box.add_child(HSeparator.new())
	box.add_child(_section_label("ANIMATIONEN"))

	var anim_grid := GridContainer.new()
	anim_grid.columns = 2
	anim_grid.add_theme_constant_override("h_separation", 8)
	anim_grid.add_theme_constant_override("v_separation", 6)
	box.add_child(anim_grid)
	_add_anim_button(anim_grid, "Idle", "idle")
	_add_anim_button(anim_grid, "Laufen →", "run_right")
	_add_anim_button(anim_grid, "Laufen ←", "run_left")
	_add_anim_button(anim_grid, "Springen", "jump")
	_add_anim_button(anim_grid, "Fallen (hoch)", "fall")
	_add_anim_button(anim_grid, "Landen (Sturz)", "land")
	_add_anim_button(anim_grid, "Treffer", "hit")
	_add_anim_button(anim_grid, "Treffer leicht", "hit_light")
	var flip_btn := _add_anim_button(anim_grid, "Blickrichtung wechseln", "flip")
	flip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anim_grid.get_child(anim_grid.get_child_count() - 1).size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_auto_toggle = CheckButton.new()
	_auto_toggle.text = "AUTO – Spielablauf abspielen"
	_auto_toggle.add_theme_font_size_override("font_size", 16)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	box.add_child(_auto_toggle)

	box.add_child(HSeparator.new())
	box.add_child(_section_label("DARSTELLUNG"))

	var look_grid := GridContainer.new()
	look_grid.columns = 2
	look_grid.add_theme_constant_override("h_separation", 10)
	look_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(look_grid)

	_fur_picker = _add_color_row(look_grid, "Fell", DEFAULT_FUR)
	_eye_picker = _add_color_row(look_grid, "Augen", DEFAULT_EYES)
	_pants_picker = _add_color_row(look_grid, "Hose", DEFAULT_PANTS)
	_top_picker = _add_color_row(look_grid, "Oberteil", DEFAULT_TOP)
	_hair_picker = _add_color_row(look_grid, "Haare", DEFAULT_HAIR)

	_outfit_option = OptionButton.new()
	_outfit_option.custom_minimum_size = Vector2(160.0, 32.0)
	_outfit_option.add_item("Kein Outfit")
	_outfit_ids.clear()
	for hero_id in Global.heroes.keys():
		var hero: HeroData = Global.heroes[hero_id]
		_outfit_option.add_item(hero.name)
		_outfit_ids.append(str(hero_id))
	_outfit_option.item_selected.connect(func(_index: int): _apply_look())
	_add_labeled(look_grid, "Outfit", _outfit_option)

	_tusk_option = OptionButton.new()
	_tusk_option.custom_minimum_size = Vector2(160.0, 32.0)
	_tusk_ids.clear()
	for shape in Global.TUSK_SHAPES:
		_tusk_option.add_item(Global.get_tusk_shape_label(shape))
		_tusk_ids.append(str(shape))
	_tusk_option.item_selected.connect(func(_index: int): _apply_look())
	_add_labeled(look_grid, "Hauer", _tusk_option)

	_team_check = CheckButton.new()
	_team_check.text = "Teamfarbe"
	_team_check.toggled.connect(func(_pressed: bool): _apply_look())
	look_grid.add_child(_team_check)

	_animate_check = CheckButton.new()
	_animate_check.text = "Animation an"
	_animate_check.button_pressed = true
	_animate_check.toggled.connect(_on_animate_toggled)
	look_grid.add_child(_animate_check)

	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = MIN_ZOOM
	_zoom_slider.max_value = MAX_ZOOM
	_zoom_slider.step = 0.5
	_zoom_slider.value = DEFAULT_ZOOM
	_zoom_slider.custom_minimum_size = Vector2(160.0, 24.0)
	_zoom_slider.value_changed.connect(_apply_zoom)
	_add_labeled(look_grid, "Zoom", _zoom_slider)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.1
	_speed_slider.max_value = 1.0
	_speed_slider.step = 0.05
	_speed_slider.value = 1.0
	_speed_slider.custom_minimum_size = Vector2(160.0, 24.0)
	_speed_slider.value_changed.connect(_on_speed_changed)
	_add_labeled(look_grid, "Zeitlupe", _speed_slider)

	var bg_check := CheckButton.new()
	bg_check.text = "Heller Hintergrund"
	bg_check.toggled.connect(func(pressed: bool):
		_light_bg = pressed
		queue_redraw()
	)
	_bg_check = bg_check
	look_grid.add_child(bg_check)

	var reset_btn := Button.new()
	reset_btn.text = "Alles zurücksetzen"
	reset_btn.pressed.connect(_reset_look)
	box.add_child(reset_btn)

	box.add_child(HSeparator.new())
	var note := Label.new()
	note.text = "Die Figur wird komplett prozedural gezeichnet. Animationen entstehen aus Geschwindigkeit und Bodenkontakt des Parents – wie im Spiel."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", Color(0.55, 0.60, 0.70, 1.0))
	box.add_child(note)

func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.70, 0.76, 0.90, 1.0))
	return label

func _add_labeled(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	grid.add_child(label)
	grid.add_child(control)

func _add_color_row(grid: GridContainer, text: String, default_color: Color) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(160.0, 32.0)
	picker.edit_alpha = false
	picker.color = default_color
	picker.color_changed.connect(func(_color: Color): _apply_look())
	_add_labeled(grid, text, picker)
	return picker

func _add_part_row(
	grid: GridContainer,
	text: String,
	catalog: Array[Dictionary]
) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(160.0, 32.0)
	for entry in catalog:
		option.add_item(str(entry["label"]))
	option.item_selected.connect(_on_part_changed)
	_add_labeled(grid, text, option)
	return option

## Regler für einen Größenfaktor (0.6–1.5, 1 = Standard der Körperform).
func _add_size_row(grid: GridContainer, text: String) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.6
	slider.max_value = 1.5
	slider.step = 0.05
	slider.value = 1.0
	slider.custom_minimum_size = Vector2(160.0, 24.0)
	slider.tooltip_text = "%s (1.0 = Standard)" % text
	slider.value_changed.connect(func(_value: float): _on_part_changed())
	_add_labeled(grid, text, slider)
	return slider

func _add_anim_button(grid: GridContainer, text: String, anim: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Kein Fokus, damit Leertaste (Springen) nicht den zuletzt geklickten Button auslöst.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_manual_anim.bind(anim))
	grid.add_child(button)
	return button
     