class_name WarpPipe
extends Area2D

## Magisches Portal: teleportiert Spieler zum Partnerportal und verschwindet
## anschließend für zehn Sekunden. Die Röhren-Optik wurde durch einen
## prozedural gezeichneten, animierten Portalring ersetzt.

const HIDE_DURATION: float = 0.22
const APPEAR_DURATION: float = 0.28
const PORTAL_CENTER: Vector2 = Vector2(0.0, -24.0)

@export var target_pipe: WarpPipe
@export var cooldown_duration: float = 10.0
@export var portal_primary: Color = Color(0.62, 0.32, 1.0, 0.95)
@export var portal_secondary: Color = Color(0.25, 0.90, 1.0, 0.85)
@export var portal_glow: Color = Color(0.20, 0.75, 1.0, 0.09)

var can_warp: bool = true
var warp_cooldown: float = 0.0

var _anim_time: float = 0.0
var _hide_timer: float = 0.0
var _appear_tween: Tween = null

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_process(true)

func _process(delta: float) -> void:
	_anim_time += delta

	if _hide_timer > 0.0:
		_hide_timer = maxf(0.0, _hide_timer - delta)
		var progress := 1.0 - (_hide_timer / HIDE_DURATION)
		scale = Vector2.ONE * lerpf(1.0, 0.35, progress)
		var faded := modulate
		faded.a = 1.0 - progress
		modulate = faded
		queue_redraw()
		if _hide_timer <= 0.0:
			visible = false
			scale = Vector2.ONE
			modulate = Color.WHITE

	if not can_warp:
		warp_cooldown = maxf(0.0, warp_cooldown - delta)
		if warp_cooldown <= 0.0:
			_reactivate()
	elif visible:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not can_warp or not is_instance_valid(target_pipe) or not target_pipe.can_warp:
		return
	if body is CharacterBody2D:
		# Beide Portale sofort sperren, damit der Teleport nicht erneut auslöst.
		can_warp = false
		target_pipe.can_warp = false
		body.global_position = target_pipe.global_position + Vector2(0.0, -28.0)
		body.velocity = Vector2(0.0, -250.0)
		_begin_cooldown()
		target_pipe._begin_cooldown()

func _begin_cooldown() -> void:
	can_warp = false
	warp_cooldown = cooldown_duration
	_hide_timer = HIDE_DURATION
	_anim_time = 0.0
	visible = true
	scale = Vector2.ONE
	modulate = Color.WHITE
	if _appear_tween != null and _appear_tween.is_valid():
		_appear_tween.kill()
	set_deferred("monitoring", false)
	_collision_shape.set_deferred("disabled", true)
	queue_redraw()

func _reactivate() -> void:
	can_warp = true
	visible = true
	scale = Vector2.ONE * 0.55
	modulate = Color(1.6, 1.35, 2.0, 1.0)
	set_deferred("monitoring", true)
	_collision_shape.set_deferred("disabled", false)
	_anim_time = 0.0
	_appear_tween = create_tween()
	_appear_tween.set_parallel(true)
	_appear_tween.tween_property(self, "scale", Vector2.ONE, APPEAR_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_appear_tween.tween_property(self, "modulate", Color.WHITE, APPEAR_DURATION)
	queue_redraw()

func _draw() -> void:
	var primary := portal_primary
	var secondary := portal_secondary
	var glow := portal_glow
	# Magiekreis auf dem Boden.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 25.0, Color(primary.r, primary.g, primary.b, 0.10))
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 40, Color(primary.r, primary.g, primary.b, 0.35), 2.0, true)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 36, Color(secondary.r, secondary.g, secondary.b, 0.22), 1.5, true)

	# Aufrechter Portalring.
	draw_set_transform(PORTAL_CENTER, 0.0, Vector2(1.0, 1.18))
	draw_circle(Vector2.ZERO, 27.0, Color(primary.r, primary.g, primary.b, 0.07))
	draw_circle(Vector2.ZERO, 23.0, glow)
	draw_circle(Vector2.ZERO, 18.0, Color(0.02, 0.01, 0.06, 0.96))
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 56, primary, 3.0, true)
	draw_arc(Vector2.ZERO, 18.4, 0.0, TAU, 56, secondary, 1.4, true)

	# Wirbel im Inneren.
	for i in range(4):
		var radius := 15.5 - float(i) * 2.6
		var start := _anim_time * (1.1 + float(i) * 0.28) + float(i) * TAU / 4.0
		var swirl := primary.lerp(secondary, float(i) / 3.0)
		swirl.a = 0.72 - float(i) * 0.12
		draw_arc(Vector2.ZERO, radius, start, start + 1.8, 30, swirl, 2.0, true)

	# Funken am Rand.
	for i in range(7):
		var angle := -_anim_time * 1.6 + float(i) * TAU / 7.0
		var radius := 23.0 + sin(_anim_time * 2.3 + float(i) * 1.7) * 2.5
		var spark := Vector2(cos(angle) * radius, sin(angle) * radius)
		var twinkle := 0.55 + 0.45 * sin(_anim_time * 5.0 + float(i) * 2.1)
		draw_circle(spark, 1.2 + twinkle * 1.1, Color(secondary.r, secondary.g, secondary.b, twinkle * 0.85))

	draw_set_transform(Vector2.ZERO)
