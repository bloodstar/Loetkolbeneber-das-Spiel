class_name MagicWand
extends Node2D

## Einhändiger Zauberstab mit prozedural gezeichneter Spitze. Form und Farbe
## der Spitze stammen aus der Charakteranpassung und werden ohne Textur
## gezeichnet, damit sie sich im Spiel und in der Lobby sofort aktualisieren.

const SHAPES: Array[String] = ["orb", "star", "crystal", "flame"]
const TIP_CENTER: Vector2 = Vector2(21.0, 0.0)
const WOOD_OUTLINE: Color = Color(0.16, 0.09, 0.05, 1.0)
const WOOD: Color = Color(0.48, 0.29, 0.14, 1.0)
const WOOD_HIGHLIGHT: Color = Color(0.76, 0.56, 0.32, 1.0)
const METAL: Color = Color(0.86, 0.70, 0.34, 1.0)

var tip_shape: String = "orb"
var tip_color: Color = Color(0.6, 0.85, 1.0, 1.0)
var flip_v: bool = false

func _ready() -> void:
	queue_redraw()

func setup(shape: String, color: Color) -> void:
	tip_shape = shape if SHAPES.has(shape) else "orb"
	tip_color = color
	queue_redraw()

func set_flip_v(value: bool) -> void:
	if flip_v == value:
		return
	flip_v = value
	queue_redraw()

func _draw() -> void:
	if flip_v:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, -1.0))
	_draw_shaft()
	_draw_tip()
	if flip_v:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_shaft() -> void:
	# Kurzer, einhändig geführter Stab mit goldener Griffwicklung.
	draw_line(Vector2(-3.0, 0.0), Vector2(18.4, 0.0), WOOD_OUTLINE, 4.4, true)
	draw_line(Vector2(-2.2, 0.0), Vector2(18.0, 0.0), WOOD, 2.8, true)
	draw_line(Vector2(-1.2, -0.9), Vector2(16.8, -0.9), WOOD_HIGHLIGHT, 0.8, true)
	draw_circle(Vector2(-2.8, 0.0), 2.6, WOOD_OUTLINE)
	draw_circle(Vector2(-2.8, 0.0), 1.8, WOOD)
	for x in [2.2, 5.2, 8.2]:
		draw_line(Vector2(x, -2.0), Vector2(x, 2.0), METAL, 1.0, true)
	# Kleine Metallfassung, in der die Spitze sitzt.
	draw_line(Vector2(17.0, -2.6), Vector2(17.0, 2.6), METAL, 1.6, true)

func _draw_tip() -> void:
	var outline := tip_color.darkened(0.55)
	var mid := tip_color
	var light := tip_color.lightened(0.45)
	# Weicher Schein um die Spitze.
	draw_circle(TIP_CENTER, 8.6, Color(tip_color.r, tip_color.g, tip_color.b, 0.055))
	draw_circle(TIP_CENTER, 6.4, Color(tip_color.r, tip_color.g, tip_color.b, 0.10))
	draw_circle(TIP_CENTER, 5.0, Color(tip_color.r, tip_color.g, tip_color.b, 0.14))

	match tip_shape:
		"star":
			var outer := _star_points(TIP_CENTER, 5.4, 2.4, 5)
			draw_colored_polygon(outer, outline)
			var inner := _star_points(TIP_CENTER, 4.3, 1.8, 5)
			draw_colored_polygon(inner, mid)
			draw_circle(TIP_CENTER, 1.15, light)
		"crystal":
			var shell := PackedVector2Array([
				TIP_CENTER + Vector2(-4.8, 0.0),
				TIP_CENTER + Vector2(-0.6, -3.7),
				TIP_CENTER + Vector2(6.2, 0.0),
				TIP_CENTER + Vector2(-0.6, 3.7),
			])
			draw_colored_polygon(shell, outline)
			var core := PackedVector2Array([
				TIP_CENTER + Vector2(-3.7, 0.0),
				TIP_CENTER + Vector2(-0.7, -2.7),
				TIP_CENTER + Vector2(4.8, 0.0),
				TIP_CENTER + Vector2(-0.7, 2.7),
			])
			draw_colored_polygon(core, mid)
			draw_line(
				TIP_CENTER + Vector2(-3.5, 0.0),
				TIP_CENTER + Vector2(4.6, 0.0),
				light,
				0.8,
				true
			)
			draw_circle(TIP_CENTER + Vector2(-1.6, -1.2), 0.8, light)
		"flame":
			var outer := PackedVector2Array([
				TIP_CENTER + Vector2(-4.4, 2.8),
				TIP_CENTER + Vector2(-5.6, 0.4),
				TIP_CENTER + Vector2(-3.5, -2.5),
				TIP_CENTER + Vector2(-0.8, -3.7),
				TIP_CENTER + Vector2(2.0, -2.1),
				TIP_CENTER + Vector2(6.0, -0.1),
				TIP_CENTER + Vector2(3.2, 2.8),
				TIP_CENTER + Vector2(0.1, 3.5),
			])
			draw_colored_polygon(outer, outline)
			var inner := PackedVector2Array([
				TIP_CENTER + Vector2(-2.6, 2.0),
				TIP_CENTER + Vector2(-3.0, 0.2),
				TIP_CENTER + Vector2(-1.5, -2.2),
				TIP_CENTER + Vector2(0.2, -1.3),
				TIP_CENTER + Vector2(3.1, 0.2),
				TIP_CENTER + Vector2(1.2, 2.1),
			])
			draw_colored_polygon(inner, mid)
			draw_circle(TIP_CENTER + Vector2(0.2, 0.4), 1.0, light)
		_:
			draw_circle(TIP_CENTER, 4.8, outline)
			draw_circle(TIP_CENTER, 3.9, mid)
			draw_circle(TIP_CENTER + Vector2(-1.3, -1.3), 1.35, light)
			draw_circle(TIP_CENTER + Vector2(1.6, 1.2), 0.65, Color(light.r, light.g, light.b, 0.55))

func _star_points(center: Vector2, outer_radius: float, inner_radius: float, points: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points * 2):
		var radius := outer_radius if i % 2 == 0 else inner_radius
		var angle := -PI / 2.0 + float(i) * PI / float(points)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return result
