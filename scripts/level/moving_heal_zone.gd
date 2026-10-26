class_name MovingHealZone
extends Area2D

const RADIUS: float = 65.0
const HEAL_PER_SECOND: float = 16.0
const HEAL_TICK_INTERVAL: float = 0.25

var _time: float = 0.0
var _arena_rect: Rect2 = Rect2(100, 100, 1100, 500)
var _current_target: Vector2 = Vector2.ZERO
var _speed: float = 65.0
var _heal_tick_timer: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Players layer
	monitoring = true
	monitorable = false

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	col.shape = shape
	add_child(col)

	_pick_new_target()

func setup_bounds(rect: Rect2) -> void:
	_arena_rect = rect
	global_position = rect.get_center()
	_pick_new_target()

func _pick_new_target() -> void:
	_current_target = Vector2(
		randf_range(_arena_rect.position.x + 80, _arena_rect.end.x - 80),
		randf_range(_arena_rect.position.y + 60, _arena_rect.end.y - 60)
	)

func _process(delta: float) -> void:
	_time += delta
	global_position = global_position.move_toward(_current_target, _speed * delta)
	if global_position.distance_to(_current_target) < 15.0:
		_pick_new_target()

	# Heilung in diskreten Ticks anwenden. Player.heal() erzeugt einen
	# Farbtween; ein Aufruf pro Frame würde hunderte Tweens überlagern.
	_heal_tick_timer -= delta
	if _heal_tick_timer <= 0.0:
		_heal_tick_timer = HEAL_TICK_INTERVAL
		for body in get_overlapping_bodies():
			if body is Player:
				body.heal(HEAL_PER_SECOND * HEAL_TICK_INTERVAL)

	queue_redraw()

func _draw() -> void:
	var pulse := 1.0 + sin(_time * 3.5) * 0.06
	var r := RADIUS * pulse

	# Outer aura
	draw_circle(Vector2.ZERO, r, Color(0.2, 0.9, 0.4, 0.12))
	# Inner aura
	draw_circle(Vector2.ZERO, r * 0.75, Color(0.3, 1.0, 0.5, 0.18))
	# Ring
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(0.4, 1.0, 0.6, 0.7), 2.5)

	# Medical Cross
	var cross_col := Color(0.5, 1.0, 0.7, 0.8)
	var sz := 16.0
	var th := 5.0
	draw_rect(Rect2(-th * 0.5, -sz, th, sz * 2.0), cross_col)
	draw_rect(Rect2(-sz, -th * 0.5, sz * 2.0, th), cross_col)
