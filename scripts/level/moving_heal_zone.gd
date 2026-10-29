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
# Netzwerk-Clients: Position kommt vom Host, geheilt wird nur dort.
var is_replica: bool = false
var _net_target: Vector2 = Vector2.INF
# Startphasen der aufsteigenden Pluszeichen (siehe EffectZone.draw_heal).
var _plus_phase: Array[float] = []
var _plus_offset: Array[float] = []

func apply_network_position(pos: Vector2) -> void:
	if _net_target == Vector2.INF:
		global_position = pos
	_net_target = pos

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Players layer
	monitoring = true
	monitorable = false
	for i in 16:
		_plus_phase.append(randf())
		_plus_offset.append(randf_range(-1.0, 1.0))

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
	if is_replica:
		if _net_target != Vector2.INF:
			global_position = global_position.lerp(_net_target, minf(1.0, delta * 12.0))
		queue_redraw()
		return
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
	# Aura, Ring und aufsteigende Pluszeichen wie bei den Heilzonen der Spieler.
	EffectZone.draw_heal(self, RADIUS, _time, _plus_phase, _plus_offset)

	# Medical Cross
	var cross_col := Color(0.5, 1.0, 0.7, 0.55)
	var sz := 12.0
	var th := 4.0
	draw_rect(Rect2(-th * 0.5, -sz, th, sz * 2.0), cross_col)
	draw_rect(Rect2(-sz, -th * 0.5, sz * 2.0, th), cross_col)
