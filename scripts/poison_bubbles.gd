class_name PoisonBubbleEffect
extends Node2D

## Kleine, aufsteigende Giftbläschen für vergiftete Charaktere. Der Effekt wird
## prozedural gezeichnet und benötigt keine Textur oder GPU-Partikel.

const SPAWN_INTERVAL: float = 0.14
const MAX_BUBBLES: int = 32

var emitting: bool = false
var _spawn_cooldown: float = 0.0
var _bubbles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 1
	_rng.randomize()
	set_process(false)

func set_emitting(value: bool) -> void:
	if value == emitting:
		if value:
			set_process(true)
		return
	emitting = value
	if emitting:
		_spawn_cooldown = 0.0
		set_process(true)

func is_emitting() -> bool:
	return emitting

func _process(delta: float) -> void:
	if emitting:
		_spawn_cooldown -= delta
		while _spawn_cooldown <= 0.0:
			_spawn_bubble()
			_spawn_cooldown += _rng.randf_range(SPAWN_INTERVAL * 0.7, SPAWN_INTERVAL * 1.35)
	else:
		_spawn_cooldown = minf(_spawn_cooldown, 0.0)

	for i in range(_bubbles.size() - 1, -1, -1):
		var bubble := _bubbles[i]
		var life := float(bubble["life"]) - delta
		if life <= 0.0:
			_bubbles.remove_at(i)
			continue
		bubble["life"] = life
		var age := float(bubble["age"]) + delta
		bubble["age"] = age

		var velocity: Vector2 = bubble["vel"]
		velocity.y -= 9.0 * delta
		bubble["vel"] = velocity

		var position: Vector2 = bubble["pos"]
		position += velocity * delta
		position.x += sin(age * 7.0 + float(bubble["phase"])) * 9.0 * delta
		bubble["pos"] = position

	queue_redraw()
	if not emitting and _bubbles.is_empty():
		set_process(false)

func _spawn_bubble() -> void:
	var life := _rng.randf_range(0.9, 1.4)
	_bubbles.append({
		"pos": Vector2(_rng.randf_range(-8.5, 8.5), _rng.randf_range(0.0, 9.0)),
		"vel": Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-38.0, -20.0)),
		"life": life,
		"max_life": life,
		"age": 0.0,
		"radius": _rng.randf_range(1.3, 2.9),
		"phase": _rng.randf_range(0.0, TAU),
	})
	while _bubbles.size() > MAX_BUBBLES:
		_bubbles.remove_at(0)

func _draw() -> void:
	for bubble in _bubbles:
		var life := float(bubble["life"])
		var max_life := float(bubble["max_life"])
		var age := float(bubble["age"])
		var fade_in := clampf(age / 0.12, 0.0, 1.0)
		var fade_out := clampf(life / 0.32, 0.0, 1.0)
		var alpha := fade_in * fade_out
		if alpha <= 0.0:
			continue

		var radius := float(bubble["radius"]) * (1.0 + 0.14 * clampf(age / max_life, 0.0, 1.0))
		var position: Vector2 = bubble["pos"]
		draw_circle(position, radius, Color(0.16, 0.52, 0.20, 0.55 * alpha))
		draw_circle(position, radius * 0.72, Color(0.34, 0.92, 0.38, 0.62 * alpha))
		draw_circle(
			position + Vector2(-radius * 0.28, -radius * 0.30),
			maxf(0.35, radius * 0.26),
			Color(0.78, 1.0, 0.70, 0.85 * alpha)
		)
