class_name BountyCoin
extends Area2D

signal collected(player: Node2D)

var _time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 # Players layer
	monitoring = true
	monitorable = true
	_base_y = position.y
	body_entered.connect(_on_body_entered)

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	col.shape = circle
	add_child(col)

func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * 4.0) * 6.0
	queue_redraw()

func _draw() -> void:
	# Gold coin with shiny border and star
	var wobble: float = cos(_time * 5.0)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(maxf(0.15, absf(wobble)), 1.0))

	# Glow
	draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.85, 0.2, 0.25))
	# Outer rim
	draw_circle(Vector2.ZERO, 12.0, Color(0.9, 0.65, 0.1, 1.0))
	# Inner face
	draw_circle(Vector2.ZERO, 9.5, Color(1.0, 0.88, 0.25, 1.0))
	# Center star / diamond
	var pts := PackedVector2Array([
		Vector2(0, -5),
		Vector2(3.5, 0),
		Vector2(0, 5),
		Vector2(-3.5, 0),
	])
	draw_colored_polygon(pts, Color(0.85, 0.55, 0.1, 1.0))

func _on_body_entered(body: Node2D) -> void:
	# Nur echte Spieler dürfen Münzen aufnehmen. Das Piñata-Lama teilt sich
	# denselben Collision-Layer und hat ebenfalls take_damage(), darf aber
	# keine Beute für Slot 1 auslösen.
	if body is Player:
		SoundManager.play_sound("glass", 0.3, 2.0)
		collected.emit(body)

		# Sparkle particle effect
		var sparkle := Node2D.new()
		get_parent().add_child(sparkle)
		sparkle.global_position = global_position
		sparkle.draw.connect(func():
			sparkle.draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.9, 0.3, 0.7))
		)
		var tw := sparkle.create_tween()
		tw.tween_property(sparkle, "scale", Vector2(2.5, 2.5), 0.25)
		tw.tween_callback(sparkle.queue_free)

		queue_free()
