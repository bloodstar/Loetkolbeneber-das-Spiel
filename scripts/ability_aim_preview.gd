class_name AbilityAimPreview
extends Node2D

# Zielvorschau für gerichtete Heldenfähigkeiten (Schwarzes Loch, Wurzelwall,
# Blink, Schattensprung, Raketensprung). Sie wird nur beim lokalen Spieler mit Maus erzeugt
# und zeichnet in Weltkoordinaten: Reichweitenring um den Eber und die Form
# der Fähigkeit am Zielpunkt. Liegt der Zeiger im Gelände, zeigt eine
# gestrichelte Linie zur nächsten freien Stelle, an der gezaubert wird.
#
# Die Daten kommen aus Player.ability_target_info(). In der Arena liegt die
# 2D-Ebene durch die gestauchte Kamera auf dem 3D-Boden, Kreise werden dort
# also von selbst zu Ellipsen.

const COLOR_OK: Color = Color(0.45, 0.95, 1.0, 1.0)
const COLOR_BAD: Color = Color(1.0, 0.25, 0.2, 1.0)
# Dunkler Rand unter den Linien, damit sie auch auf hellen Leveln lesbar sind.
const OUTLINE: Color = Color(0.02, 0.05, 0.1, 0.45)
# Ohne neue Daten (Optionsmenü, Betäubung, Tod) räumt sich die Vorschau
# nach dieser Zeit selbst ab.
const STALE_MSEC: int = 150

var player: Player = null
var _info: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _range: float = 0.0
var _last_update_msec: int = 0

func _ready() -> void:
	top_level = true
	z_index = 60
	global_position = Vector2.ZERO
	visible = false

func show_info(origin: Vector2, max_range: float, info: Dictionary) -> void:
	_origin = origin
	_range = max_range
	_info = info
	_last_update_msec = Time.get_ticks_msec()
	global_position = Vector2.ZERO
	global_rotation = 0.0
	visible = true
	queue_redraw()

func hide_preview() -> void:
	if visible:
		visible = false
		queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() - _last_update_msec > STALE_MSEC:
		if player != null and is_instance_valid(player):
			player.cancel_ability_aim()
		else:
			hide_preview()

func _draw() -> void:
	if not visible or _info.is_empty():
		return
	var valid := bool(_info.get("valid", true))
	var col := COLOR_OK if valid else COLOR_BAD
	var pos: Vector2 = _info.get("pos", _origin)
	# Reichweite um den Eber und Linie zum Ziel.
	if _range > 1.0:
		_dashed_circle(_origin, _range, Color(col.r, col.g, col.b, 0.2), 1.5, 40)
	draw_line(_origin, pos, Color(col.r, col.g, col.b, 0.22), 1.5, true)
	# Zeiger im Gelände: kleiner Punkt am Zeiger, Strich zur Ausweichstelle.
	if _info.get("cursor") is Vector2:
		var cursor: Vector2 = _info["cursor"]
		var anchor: Vector2 = _info.get("point", pos)
		draw_dashed_line(cursor, anchor, Color(col.r, col.g, col.b, 0.6), 1.5, 5.0, true)
		draw_circle(cursor, 4.0, Color(col.r, col.g, col.b, 0.6))

	match str(_info.get("kind", "")):
		"circle":
			var radius := float(_info.get("radius", 40.0))
			var outer := float(_info.get("outer", 0.0))
			var points: Array = _info.get("points", [pos])
			for p in points:
				var c: Vector2 = p
				if outer > radius:
					draw_circle(c, outer, Color(col.r, col.g, col.b, 0.05))
					_dashed_circle(c, outer, Color(col.r, col.g, col.b, 0.4), 1.5, 36)
				draw_circle(c, radius, Color(col.r, col.g, col.b, 0.18))
				draw_arc(c, radius, 0.0, TAU, 40, OUTLINE, 5.0, true)
				draw_arc(c, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.95), 2.0, true)
		"wall":
			var length := float(_info.get("len", 100.0))
			var thick := float(_info.get("thick", 20.0))
			var rot := float(_info.get("rot", 0.0))
			var axis := Vector2.RIGHT.rotated(rot) * length * 0.5
			var side := Vector2.DOWN.rotated(rot) * thick * 0.5
			var corners := PackedVector2Array([
				pos - axis - side, pos + axis - side, pos + axis + side, pos - axis + side,
			])
			draw_colored_polygon(corners, Color(col.r, col.g, col.b, 0.25))
			corners.append(corners[0])
			draw_polyline(corners, OUTLINE, 5.0, true)
			draw_polyline(corners, Color(col.r, col.g, col.b, 0.95), 2.0, true)
		"leap":
			# Flugbahn mit Pfeilspitze und Einschlagradius am Ende.
			var dir := (pos - _origin).normalized()
			draw_line(_origin, pos, OUTLINE, 6.0, true)
			draw_line(_origin, pos, Color(col.r, col.g, col.b, 0.85), 3.0, true)
			if dir.length_squared() > 0.5:
				var tip := PackedVector2Array([pos + dir * 12.0, pos - dir * 6.0 + dir.orthogonal() * 9.0, pos - dir * 6.0 - dir.orthogonal() * 9.0])
				draw_colored_polygon(tip, Color(col.r, col.g, col.b, 0.95))
			var impact := float(_info.get("radius", 0.0))
			if impact > 0.0:
				draw_circle(pos, impact, Color(col.r, col.g, col.b, 0.06))
				_dashed_circle(pos, impact, Color(col.r, col.g, col.b, 0.4), 1.5, 32)
		"blink":
			var hit_radius := float(_info.get("radius", 0.0))
			if hit_radius > 0.0:
				draw_circle(pos, hit_radius, Color(col.r, col.g, col.b, 0.07))
				_dashed_circle(pos, hit_radius, Color(col.r, col.g, col.b, 0.45), 1.5, 32)
			draw_circle(pos, 13.0, Color(col.r, col.g, col.b, 0.3))
			draw_arc(pos, 13.0, 0.0, TAU, 24, OUTLINE, 5.0, true)
			draw_arc(pos, 13.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.95), 2.0, true)
	if not valid:
		# Kreuz am Zielpunkt: hier kann nichts platziert werden.
		var s := 9.0
		draw_line(pos + Vector2(-s, -s), pos + Vector2(s, s), COLOR_BAD, 3.0, true)
		draw_line(pos + Vector2(-s, s), pos + Vector2(s, -s), COLOR_BAD, 3.0, true)

func _dashed_circle(center: Vector2, radius: float, color: Color, width: float, dashes: int) -> void:
	var step := TAU / float(dashes)
	for i in range(dashes):
		var a := step * float(i)
		draw_arc(center, radius, a, a + step * 0.55, 4, color, width, true)
