class_name FloorLavaOverlay
extends Node2D

# Sichtbare Lava für den Modifier "Der Boden ist Lava": eine glühende Schicht
# über dem untersten Boden mit welliger Oberkante und Blasen. Rein visuell,
# läuft auf Host und Clients; der Schaden kommt weiterhin vom Modifier-Manager.
# Mit auto_floor = false zeigt main.gd damit auch die steigende Lava (Sudden
# Death, Lavaturm, Lava-Flut) und setzt die Oberfläche per set_surface_y().

const LAVA_COLOR := Color(1.0, 0.25, 0.05, 0.65)
const EDGE_COLOR := Color(1.0, 0.75, 0.2, 0.9)
const GLOW_COLOR := Color(1.0, 0.4, 0.05, 0.18)
# Die Lava steht etwas über der Bodenkante, damit Füße sichtbar eintauchen.
const SURFACE_ABOVE_GROUND: float = 12.0
const BUBBLE_COUNT: int = 18

var _time: float = 0.0
var _surface_y: float = 0.0
var _width: float = 0.0
var _bottom: float = 0.0
var _bubbles: Array[Dictionary] = []
var auto_floor: bool = true

func _ready() -> void:
	z_index = 10
	_fit_to_map()
	if auto_floor:
		_surface_y = float(LevelGenerator.map_h - 2) * LevelGenerator.TILE_SIZE - SURFACE_ABOVE_GROUND

## Passt Breite und Unterkante an die aktuelle Karte an; bei neuer Breite
## werden die Blasen neu verteilt.
func _fit_to_map() -> void:
	var tile := LevelGenerator.TILE_SIZE
	_bottom = float(LevelGenerator.map_h) * tile + 100.0
	var width := float(LevelGenerator.map_w) * tile
	if is_equal_approx(width, _width) and not _bubbles.is_empty():
		return
	_width = width
	_bubbles.clear()
	for i in range(BUBBLE_COUNT):
		_bubbles.append(_new_bubble(randf()))

func set_surface_y(y: float) -> void:
	_fit_to_map()
	_surface_y = y

func _new_bubble(phase: float) -> Dictionary:
	return {
		"x": randf() * _width,
		"phase": phase,
		"speed": randf_range(0.35, 0.7),
		"size": randf_range(2.5, 5.0),
	}

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	for i in range(_bubbles.size()):
		var b: Dictionary = _bubbles[i]
		b["phase"] = float(b["phase"]) + delta * float(b["speed"])
		if float(b["phase"]) >= 1.0:
			_bubbles[i] = _new_bubble(0.0)
	queue_redraw()

func _wave_y(x: float) -> float:
	return _surface_y + sin(x * 0.035 + _time * 2.2) * 2.5 + sin(x * 0.011 - _time * 1.3) * 2.0

func _draw() -> void:
	# Leichtes Glühen über der Oberfläche.
	draw_rect(Rect2(0.0, _surface_y - 18.0, _width, 18.0), GLOW_COLOR)
	# Lavakörper mit welliger Oberkante.
	var points := PackedVector2Array()
	var step := 18.0
	var x := 0.0
	while x <= _width:
		points.append(Vector2(x, _wave_y(x)))
		x += step
	points.append(Vector2(_width, _wave_y(_width)))
	var edge := points.duplicate()
	points.append(Vector2(_width, _bottom))
	points.append(Vector2(0.0, _bottom))
	draw_colored_polygon(points, LAVA_COLOR)
	var pulse := 0.75 + 0.25 * sin(_time * 3.0)
	draw_polyline(edge, Color(EDGE_COLOR, EDGE_COLOR.a * pulse), 3.0)
	# Aufsteigende Blasen, die an der Oberfläche platzen.
	for b in _bubbles:
		var phase := float(b["phase"])
		var bx := float(b["x"])
		var by := lerpf(_surface_y + 26.0, _wave_y(bx) - 2.0, phase)
		var alpha := 0.8 * (1.0 - absf(phase - 0.6))
		draw_circle(Vector2(bx, by), float(b["size"]) * (0.6 + phase * 0.6), Color(1.0, 0.8, 0.3, alpha))
