class_name LavaFloodMarker
extends Node2D

# Warnlinie für den Modifier "Lava-Flut": zeigt kurz vor dem Anstieg, bis
# wohin die Lava gleich steigen wird. Rein visuell, läuft auf Host und Clients.

var _target_y: float = -1.0
var _time: float = 0.0

func _ready() -> void:
	z_index = 60
	visible = false

func set_target(y: float) -> void:
	if y < 0.0:
		visible = false
		_target_y = -1.0
		return
	if not visible:
		_time = 0.0
	_target_y = y
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()

func _draw() -> void:
	if _target_y < 0.0:
		return
	var width := float(LevelGenerator.map_w) * LevelGenerator.TILE_SIZE
	var pulse := 0.55 + 0.45 * sin(_time * 9.0)
	var glow := Color(1.0, 0.35, 0.05, 0.12 * pulse)
	draw_rect(Rect2(0.0, _target_y, width, 10.0), glow)
	var line_color := Color(1.0, 0.55, 0.1, 0.9 * pulse)
	var dash := 22.0
	var gap := 14.0
	var x := -fmod(_time * 40.0, dash + gap)
	while x < width:
		draw_line(Vector2(maxf(x, 0.0), _target_y), Vector2(minf(x + dash, width), _target_y), line_color, 3.0)
		x += dash + gap
