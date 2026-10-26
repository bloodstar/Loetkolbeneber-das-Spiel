class_name TowerCannon
extends Node2D

## Kleine, prozedural gezeichnete Kanone für den Turm. Der Lauf dreht sich
## zum Ziel; das Holzrad und die Lafette bleiben in Spielerfarbe akzentuiert.

const BARREL_PIVOT: Vector2 = Vector2(0.0, -2.0)
const MUZZLE_LOCAL: Vector2 = Vector2(28.0, 0.0)

var aim_angle: float = 0.0
var accent_color: Color = Color(0.45, 0.80, 1.0)
var _recoil: float = 0.0

func _ready() -> void:
	queue_redraw()

func set_aim_angle(value: float) -> void:
	aim_angle = value
	queue_redraw()

func set_accent_color(value: Color) -> void:
	accent_color = value
	queue_redraw()

func get_muzzle_position() -> Vector2:
	return global_position + BARREL_PIVOT + MUZZLE_LOCAL.rotated(aim_angle)

func play_recoil() -> void:
	_recoil = 3.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_recoil, 3.0, 0.0, 0.13)

func _set_recoil(value: float) -> void:
	_recoil = value
	queue_redraw()

func _draw() -> void:
	# Weicher Bodenschatten.
	draw_set_transform(Vector2(0.0, 13.0), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, 18.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var wood_dark := Color(0.20, 0.11, 0.06, 1.0)
	var wood := Color(0.48, 0.29, 0.14, 1.0)
	var wood_light := Color(0.68, 0.45, 0.23, 1.0)
	var metal_dark := Color(0.18, 0.21, 0.25, 1.0)
	var metal := Color(0.48, 0.56, 0.63, 1.0)
	var metal_light := Color(0.76, 0.84, 0.90, 1.0)

	# Lafette und Ausleger.
	draw_rect(Rect2(-16.0, 1.0, 32.0, 10.0), wood_dark)
	draw_rect(Rect2(-14.0, 1.0, 28.0, 7.0), wood)
	draw_line(Vector2(-13.0, 2.5), Vector2(12.0, 2.5), wood_light, 1.1, true)
	draw_line(Vector2(-12.0, 10.0), Vector2(-20.0, 16.0), wood_dark, 3.2, true)
	draw_line(Vector2(12.0, 10.0), Vector2(20.0, 16.0), wood_dark, 3.2, true)
	draw_line(Vector2(-13.0, 0.5), Vector2(13.0, 0.5), accent_color.darkened(0.35), 1.4, true)

	# Räder.
	_draw_wheel(Vector2(-11.5, 10.0), 7.0, wood_dark, metal_dark, metal)
	_draw_wheel(Vector2(11.5, 10.0), 7.0, wood_dark, metal_dark, metal)

	# Drehsockel.
	draw_circle(Vector2(0.0, -2.0), 7.0, metal_dark)
	draw_circle(Vector2(0.0, -2.0), 5.4, metal)
	draw_circle(Vector2(0.0, -2.0), 3.5, accent_color.darkened(0.25))
	draw_circle(Vector2(-1.2, -3.1), 1.3, metal_light)

	# Lauf, relativ zum Drehsockel ausgerichtet.
	draw_set_transform(BARREL_PIVOT, aim_angle, Vector2.ONE)
	var recoil := _recoil
	var outline := PackedVector2Array([
		Vector2(2.0 - recoil, -4.2),
		Vector2(24.0 - recoil, -3.6),
		Vector2(28.5 - recoil, -2.5),
		Vector2(28.5 - recoil, 2.5),
		Vector2(24.0 - recoil, 3.6),
		Vector2(2.0 - recoil, 4.2),
	])
	draw_colored_polygon(outline, metal_dark)
	draw_rect(Rect2(4.0 - recoil, -3.0, 21.0, 6.0), metal)
	draw_line(Vector2(5.0 - recoil, -2.0), Vector2(24.0 - recoil, -2.0), metal_light, 0.9, true)
	draw_rect(Rect2(9.0 - recoil, -3.4, 2.2, 6.8), accent_color)
	draw_rect(Rect2(24.0 - recoil, -4.6, 3.4, 9.2), metal_dark)
	draw_circle(Vector2(27.4 - recoil, 0.0), 2.8, metal)
	draw_circle(Vector2(27.4 - recoil, 0.0), 1.5, Color(0.04, 0.05, 0.07, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_wheel(center: Vector2, radius: float, rim_dark: Color, hub: Color, spoke: Color) -> void:
	draw_circle(center, radius + 1.0, Color(0.04, 0.05, 0.07, 0.85))
	draw_circle(center, radius, rim_dark)
	draw_circle(center, radius * 0.72, Color(0.34, 0.23, 0.14, 1.0))
	for i in range(4):
		var direction := Vector2.RIGHT.rotated(float(i) * PI / 4.0)
		draw_line(center - direction * radius * 0.62, center + direction * radius * 0.62, spoke, 0.85, true)
	draw_circle(center, radius * 0.30, hub)
	draw_circle(center - Vector2(1.1, 1.1), radius * 0.12, Color(0.88, 0.94, 0.98, 0.8))
