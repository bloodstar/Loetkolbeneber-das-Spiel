class_name SpeedBooster
extends Area2D

## Neon-Speedbooster: beschleunigt Spieler für kurze Zeit horizontal in
## Richtung des Pfeils. Die Zone ist ein Sensor auf einer soliden Oberfläche.

@export var direction: float = 1.0
@export var boost_speed: float = 680.0
@export var boost_duration: float = 0.26

var _time: float = 0.0
var _cooldowns: Dictionary = {}

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or not body.has_method("apply_speed_boost"):
		return
	var id := body.get_instance_id()
	if float(_cooldowns.get(id, 0.0)) > 0.0:
		return
	_cooldowns[id] = 0.32
	body.apply_speed_boost(direction, boost_speed, boost_duration)

func _draw() -> void:
	var sign_dir := 1.0 if direction >= 0.0 else -1.0
	var cyan := Color(0.24, 0.92, 1.0, 0.95)
	var magenta := Color(1.0, 0.28, 0.74, 0.95)
	var base := Color(0.035, 0.07, 0.13, 0.88)
	var rim := Color(0.20, 0.55, 0.70, 0.65)

	# Glow und Pad.
	draw_circle(Vector2(0.0, -4.0), 24.0, Color(0.20, 0.88, 1.0, 0.06))
	draw_rect(Rect2(-17.0, -9.0, 34.0, 9.0), base, true)
	draw_rect(Rect2(-17.0, -9.0, 34.0, 9.0), rim, false, 1.0)
	draw_line(Vector2(-18.0, -0.5), Vector2(18.0, -0.5), Color(0.28, 0.92, 1.0, 0.6), 1.0, true)

	var travel := fposmod(_time * 42.0, 18.0)
	for i in range(3):
		var x := -12.0 + float(i) * 10.0 + travel * 0.35
		if sign_dir < 0.0:
			x = -x
		var offset := x + sin(_time * 6.0 + float(i)) * 0.8
		var color := cyan if i % 2 == 0 else magenta
		var points := PackedVector2Array([
			Vector2(offset - 4.0 * sign_dir, -7.0),
			Vector2(offset + 2.0 * sign_dir, -4.5),
			Vector2(offset - 4.0 * sign_dir, -2.0),
		])
		draw_polyline(points, Color(color.r, color.g, color.b, 0.9), 1.8, true)
	# Seitliche Energiepunkte.
	draw_circle(Vector2(-15.0, -4.5), 1.4, magenta)
	draw_circle(Vector2(15.0, -4.5), 1.4, cyan)
