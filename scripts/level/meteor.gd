class_name MeteorHazard
extends Node2D

var target_position: Vector2 = Vector2.ZERO
var damage: float = 40.0
var _crosshair: Node2D
var _players_ref: Array[Player] = []

func setup(target: Vector2, all_players: Array[Player]) -> void:
	target_position = target
	_players_ref = all_players
	if is_inside_tree() and _crosshair == null:
		_start_falling()

func _ready() -> void:
	if target_position != Vector2.ZERO:
		_start_falling()

func _start_falling() -> void:
	# Spawn ground indicator
	_crosshair = Node2D.new()
	get_parent().add_child(_crosshair)
	_crosshair.global_position = target_position

	_crosshair.draw.connect(func():
		_crosshair.draw_circle(Vector2.ZERO, 35.0, Color(1.0, 0.2, 0.1, 0.2))
		_crosshair.draw_arc(Vector2.ZERO, 35.0, 0.0, TAU, 24, Color(1.0, 0.3, 0.1, 0.8), 2.0)
		_crosshair.draw_line(Vector2(-15, 0), Vector2(15, 0), Color(1.0, 0.3, 0.1, 0.9), 2.0)
		_crosshair.draw_line(Vector2(0, -15), Vector2(0, 15), Color(1.0, 0.3, 0.1, 0.9), 2.0)
	)

	# Fall animation from top
	global_position = Vector2(target_position.x - 120.0, -80.0)

	var tw := create_tween()
	tw.tween_property(self, "global_position", target_position, 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_explode)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Flaming meteor rock
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.5, 0.1, 0.9))
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.9, 0.3, 1.0))
	draw_line(Vector2.ZERO, Vector2(-25, -35), Color(1.0, 0.3, 0.0, 0.6), 14.0)

func _explode() -> void:
	SoundManager.play_sound("explosion_big", 0.15, -2.0)
	if is_instance_valid(_crosshair):
		_crosshair.queue_free()

	# Blast ring
	var shock := Node2D.new()
	get_parent().add_child(shock)
	shock.global_position = target_position
	var tw := shock.create_tween()
	shock.draw.connect(func():
		# Fester Radius; die Skalierungs-Tween lässt den Ring sichtbar expandieren.
		shock.draw_circle(Vector2.ZERO, 55.0, Color(1.0, 0.4, 0.1, 0.8))
	)
	tw.tween_property(shock, "scale", Vector2(2.5, 2.5), 0.3)
	tw.tween_callback(shock.queue_free)

	Seesaw.blast_all(get_tree(), target_position, 100.0, 1.6)

	# Damage nearby players
	for player in _players_ref:
		if is_instance_valid(player) and player.current_health > 0:
			var d := player.global_position.distance_to(target_position)
			if d < 65.0:
				var falloff := 1.0 - (d / 65.0)
				var dir := (player.global_position - target_position).normalized()
				player.take_damage(damage * falloff, dir * 450.0)

	queue_free()
