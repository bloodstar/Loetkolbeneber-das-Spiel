class_name OrbitalLaser
extends Node2D

signal fired

var start_point: Vector2 = Vector2.ZERO
var end_point: Vector2 = Vector2.ZERO
var damage: float = 50.0

var _is_firing: bool = false
var _line: Line2D
var _players_ref: Array[Player] = []

func setup(p_start: Vector2, p_end: Vector2, all_players: Array[Player]) -> void:
	start_point = p_start
	end_point = p_end
	_players_ref = all_players
	if is_inside_tree() and _line != null:
		_telegraph_and_fire()

func _ready() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(1.0, 0.2, 0.2, 0.4)
	add_child(_line)

	if start_point != Vector2.ZERO or end_point != Vector2.ZERO:
		_telegraph_and_fire()

func _telegraph_and_fire() -> void:
	_line.points = PackedVector2Array([start_point, end_point])
	SoundManager.play_sound("laser_small", 0.4, 2.0)

	# Warning pulse tween (1.8s)
	var tw := create_tween()
	tw.tween_property(_line, "width", 5.0, 0.4)
	tw.tween_property(_line, "width", 2.0, 0.4)
	tw.tween_property(_line, "width", 7.0, 0.4)
	tw.tween_property(_line, "width", 3.0, 0.3)
	tw.tween_property(_line, "default_color", Color(1.0, 0.1, 0.1, 1.0), 0.3)
	tw.tween_callback(_fire_blast)

func _fire_blast() -> void:
	_is_firing = true
	SoundManager.play_sound("laser_large", 0.1, 0.0)
	fired.emit()

	# Blast visuals: Giant 45px glowing beam
	_line.width = 46.0
	_line.default_color = Color(1.0, 0.95, 0.8, 1.0)

	var outer_beam := Line2D.new()
	outer_beam.points = _line.points
	outer_beam.width = 75.0
	outer_beam.default_color = Color(1.0, 0.2, 0.1, 0.6)
	add_child(outer_beam)

	# Check damage to players along beam line segment
	for player in _players_ref:
		if is_instance_valid(player) and player.current_health > 0:
			var closest := Geometry2D.get_closest_point_to_segment(player.global_position, start_point, end_point)
			if player.global_position.distance_to(closest) < 38.0:
				var dir := (end_point - start_point).orthogonal().normalized()
				if dir.dot(player.global_position - closest) < 0:
					dir = -dir
				player.take_damage(damage, dir * 450.0)

	# Beam fade out
	var tw := create_tween()
	tw.tween_property(_line, "width", 0.0, 0.35)
	tw.parallel().tween_property(outer_beam, "width", 0.0, 0.35)
	tw.parallel().tween_property(outer_beam, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
