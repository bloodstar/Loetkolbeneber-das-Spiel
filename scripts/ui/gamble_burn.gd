extends Control

# Gamble: Ein Feuerbalken wandert von unten nach oben über die Karte. Unter dem
# Balken ist die Karte schon verkohlt, darüber liegt noch die offene Karte.

const DURATION := 0.9
const BAND_HEIGHT := 28.0

var _card_size := Vector2(200, 310)
var _clip: Control
var _band: Control
var _time := 0.0
var _burning := true

func setup(face: Control, charred: Control, card_size: Vector2) -> void:
	_card_size = card_size
	custom_minimum_size = card_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	charred.position = Vector2.ZERO
	charred.size = card_size
	add_child(charred)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.size = card_size
	add_child(_clip)
	face.position = Vector2.ZERO
	face.size = card_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(face)

	_band = Control.new()
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.size = Vector2(card_size.x, BAND_HEIGHT)
	_band.draw.connect(_draw_band)
	add_child(_band)
	_set_progress(0.0)

func _ready() -> void:
	# Läuft mit dem Draft-UI auch bei pausiertem Baum.
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, DURATION)
	tween.finished.connect(_on_burn_finished)

func _process(delta: float) -> void:
	if not _burning or _band == null:
		return
	_time += delta
	_band.queue_redraw()

func _set_progress(value: float) -> void:
	if _clip == null:
		return
	var edge_y := _card_size.y * (1.0 - value)
	_clip.size = Vector2(_card_size.x, edge_y)
	_band.position = Vector2(0.0, edge_y - BAND_HEIGHT * 0.5)
	_band.queue_redraw()

func _on_burn_finished() -> void:
	_burning = false
	if _clip != null:
		_clip.visible = false
	if _band != null:
		_band.visible = false

func _draw_band() -> void:
	var w := _band.size.x
	var h := BAND_HEIGHT
	# Glut unter der Kante, dann Flammenkern, darüber züngelnde Flammen.
	_band.draw_rect(Rect2(0.0, h * 0.55, w, h * 0.45), Color(0.75, 0.18, 0.04, 0.75))
	_band.draw_rect(Rect2(0.0, h * 0.40, w, h * 0.22), Color(1.0, 0.55, 0.10, 0.95))
	_band.draw_rect(Rect2(0.0, h * 0.47, w, h * 0.08), Color(1.0, 0.93, 0.55, 1.0))
	var x := 0.0
	while x < w:
		var wave := 0.5 + 0.5 * sin(_time * 17.0 + x * 0.41)
		var flame_h := h * 0.45 * (0.35 + 0.65 * wave)
		_band.draw_rect(Rect2(x, h * 0.42 - flame_h, 7.0, flame_h), Color(1.0, 0.62 + 0.25 * wave, 0.12, 0.85))
		x += 9.0
