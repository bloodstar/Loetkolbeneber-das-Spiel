class_name PigCharacter
extends Node2D

## Prozedural gezeichnetes Schwein/Eber. Fell-, Augen- und Hosenfarbe sind
## unabhängig voneinander einstellbar, damit jeder Spieler seinen Charakter
## in der Lobby anpassen kann. Die Figur wird komplett im Code gezeichnet und
## benötigt keine Sprite-Textur.

@export var fur_color: Color = Color(0.91, 0.60, 0.67, 1.0)
@export var eye_color: Color = Color(0.18, 0.14, 0.20, 1.0)
@export var pants_color: Color = Color(0.24, 0.36, 0.56, 1.0)

# Wird vom Player gesetzt, damit die Figur in Blickrichtung schaut.
var flip_h: bool = false
# Vorschauen im Menü dürfen animiert sein, Ghost-Trails dagegen nicht.
var animate: bool = true
# Wenn false, wird die Laufanimation ignoriert (z. B. in der UI-Vorschau).
var follow_parent_motion: bool = true

var _time: float = 0.0
var _move_energy: float = 0.0

func _ready() -> void:
	queue_redraw()

func setup(p_fur: Color, p_eye: Color, p_pants: Color) -> void:
	fur_color = p_fur
	eye_color = p_eye
	pants_color = p_pants
	queue_redraw()

func _process(delta: float) -> void:
	if not animate:
		return

	_time += delta
	var moving := false
	if follow_parent_motion:
		var parent := get_parent()
		if parent is CharacterBody2D:
			moving = absf(parent.velocity.x) > 12.0 or absf(parent.velocity.y) > 20.0
	_move_energy = move_toward(_move_energy, 1.0 if moving else 0.0, delta * 7.0)
	# Auch im Stand leicht weiterzeichnen, damit der Schweine-Schwanz und die
	# Augen ein wenig lebendig wirken.
	queue_redraw()

func _draw() -> void:
	var bob := sin(_time * 8.5) * 0.75 * _move_energy
	var leg_swing := sin(_time * 13.0) * 2.1 * _move_energy

	var outline := fur_color.darkened(0.42)
	outline.a = 1.0
	var fur_dark := fur_color.darkened(0.18)
	var snout_color := fur_color.lightened(0.32).lerp(Color(1.0, 0.66, 0.72, 1.0), 0.34)
	var snout_outline := fur_color.darkened(0.35)
	var hoof_color := Color(0.28, 0.20, 0.20, 1.0)
	var belt_color := pants_color.darkened(0.35)
	var buckle_color := Color(1.0, 0.80, 0.28, 1.0)
	var tusk_color := Color(0.98, 0.95, 0.82, 1.0)

	var flip_scale := Vector2(-1.0 if flip_h else 1.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, flip_scale)

	# Ringelschwanz hinter dem Körper.
	draw_arc(Vector2(-11.0, 0.5 + bob), 3.6, -PI * 0.85, PI * 0.85, 14, outline, 1.5, true)
	draw_arc(Vector2(-12.2, -1.0 + bob), 1.8, PI * 0.35, PI * 2.15, 10, fur_dark, 1.2, true)

	# Beine und Hufe (hinter der Hose).
	var left_leg_x := -5.4 + leg_swing
	var right_leg_x := 5.4 - leg_swing
	_draw_ellipse(Vector2(left_leg_x, 12.2 + bob), 2.7, 4.1, fur_dark, outline, 0.7)
	_draw_ellipse(Vector2(right_leg_x, 12.2 + bob), 2.7, 4.1, fur_dark, outline, 0.7)
	_draw_ellipse(Vector2(left_leg_x, 15.4 + bob), 2.7, 1.7, hoof_color, outline, 0.6)
	_draw_ellipse(Vector2(right_leg_x, 15.4 + bob), 2.7, 1.7, hoof_color, outline, 0.6)

	# Körper und Kopf als zwei überlappende, weiche Kugeln.
	_draw_ellipse(Vector2(0.0, 1.7 + bob), 10.7, 9.9, fur_color, outline, 1.2)
	_draw_ellipse(Vector2(0.0, -8.2 + bob), 10.6, 9.8, fur_color, outline, 1.2)

	# Kurze Hose mit Gürtel und zwei Hosenbeinen.
	_draw_pants(bob, outline, belt_color, buckle_color)

	# Ohren liegen hinter dem Kopf.
	_draw_ear(Vector2(-7.9, -14.5 + bob), -1.0, fur_dark, snout_color, outline)
	_draw_ear(Vector2(7.9, -14.5 + bob), 1.0, fur_dark, snout_color, outline)

	# Kleiner Eberbüschel auf dem Kopf.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.4, -16.9 + bob),
		Vector2(0.0, -20.4 + bob),
		Vector2(2.8, -16.7 + bob),
	]), fur_dark)

	# Rüssel.
	var snout_center := Vector2(0.0, -4.7 + bob)
	_draw_ellipse(snout_center, 5.9, 3.9, snout_color, snout_outline, 0.8)
	draw_circle(snout_center + Vector2(-2.0, 0.0), 0.85, snout_outline)
	draw_circle(snout_center + Vector2(2.0, 0.0), 0.85, snout_outline)

	# Augen mit einstellbarer Irisfarbe.
	_draw_eye(Vector2(-4.2, -10.5 + bob), outline)
	_draw_eye(Vector2(4.2, -10.5 + bob), outline)

	# Kleine Eberhauer.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.3, -3.3 + bob),
		Vector2(-7.5, -1.6 + bob),
		Vector2(-5.0, -1.3 + bob),
	]), tusk_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.3, -3.3 + bob),
		Vector2(7.5, -1.6 + bob),
		Vector2(5.0, -1.3 + bob),
	]), tusk_color)

	# Wangenrouge.
	draw_circle(Vector2(-7.8, -6.0 + bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))
	draw_circle(Vector2(7.8, -6.0 + bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_pants(bob: float, outline: Color, belt_color: Color, buckle_color: Color) -> void:
	var top := 4.3 + bob
	var bottom := 12.3 + bob
	var pants_rect := Rect2(-10.2, top, 20.4, bottom - top)
	draw_rect(pants_rect, pants_color, true)
	draw_rect(pants_rect, outline, false, 1.0)

	# Zwei Hosenbeine.
	var left_leg := Rect2(-9.5, bottom - 0.8, 8.3, 3.9)
	var right_leg := Rect2(1.2, bottom - 0.8, 8.3, 3.9)
	draw_rect(left_leg, pants_color, true)
	draw_rect(right_leg, pants_color, true)
	draw_rect(left_leg, outline, false, 1.0)
	draw_rect(right_leg, outline, false, 1.0)

	# Gürtel.
	var belt := Rect2(-10.2, top - 0.3, 20.4, 2.7)
	draw_rect(belt, belt_color, true)
	draw_rect(belt, outline, false, 1.0)
	draw_rect(Rect2(-1.7, top - 0.7, 3.4, 3.4), buckle_color, true)
	draw_rect(Rect2(-1.7, top - 0.7, 3.4, 3.4), outline, false, 0.7)

	# Kleine Naht in der Mitte.
	draw_line(Vector2(0.0, top + 2.2), Vector2(0.0, bottom - 0.6), outline, 0.8, true)

func _draw_ear(base: Vector2, direction: float, outer: Color, inner: Color, outline: Color) -> void:
	var outer_points := PackedVector2Array([
		base + Vector2(-2.2 * direction, 1.6),
		base + Vector2(4.4 * direction, -4.2),
		base + Vector2(5.0 * direction, 2.7),
	])
	draw_colored_polygon(outer_points, outer)
	outer_points.append(outer_points[0])
	draw_polyline(outer_points, outline, 1.0, true)

	var inner_points := PackedVector2Array([
		base + Vector2(-0.8 * direction, 1.0),
		base + Vector2(3.2 * direction, -2.4),
		base + Vector2(3.5 * direction, 1.7),
	])
	draw_colored_polygon(inner_points, inner)

func _draw_eye(pos: Vector2, outline: Color) -> void:
	_draw_ellipse(pos, 2.35, 2.7, Color(0.98, 0.96, 0.93, 1.0), outline, 0.6)
	var iris := pos + Vector2(0.15, 0.25)
	draw_circle(iris, 1.45, eye_color)
	draw_circle(iris + Vector2(0.05, 0.15), 0.72, Color(0.05, 0.04, 0.06, 1.0))
	draw_circle(iris + Vector2(-0.45, -0.58), 0.42, Color(1.0, 1.0, 1.0, 0.95))

func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, fill: Color, outline: Color, outline_width: float) -> void:
	var points := _ellipse_points(center, radius_x, radius_y, 24)
	draw_colored_polygon(points, fill)
	if outline_width > 0.0 and outline.a > 0.0:
		var line_points := PackedVector2Array(points)
		line_points.append(points[0])
		draw_polyline(line_points, outline, outline_width, true)

func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
