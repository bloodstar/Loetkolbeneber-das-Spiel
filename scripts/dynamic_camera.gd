class_name DynamicCamera
extends Camera2D

@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.25
@export var zoom_margin: float = 240.0
@export var follow_speed: float = 6.0

var targets: Array[Node2D] = []

# Screen Shake
var trauma: float = 0.0
var trauma_decay: float = 2.5
var max_offset: Vector2 = Vector2(16.0, 16.0)

func _ready() -> void:
	pass

func add_target(node: Node2D) -> void:
	if not targets.has(node):
		targets.append(node)

func remove_target(node: Node2D) -> void:
	targets.erase(node)

func shake(amount: float = 0.4) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	# Filter dead targets
	targets = targets.filter(func(t): return is_instance_valid(t))
	
	if targets.is_empty():
		return
	
	# Midpoint calculation
	var bounds = Rect2(targets[0].global_position, Vector2.ZERO)
	for t in targets:
		bounds = bounds.expand(t.global_position)
	
	var target_center = bounds.get_center()
	global_position = global_position.lerp(target_center, follow_speed * delta)
	
	# Zoom calculation
	var screen_size = get_viewport_rect().size
	var width_zoom = screen_size.x / maxf(bounds.size.x + zoom_margin * 2.0, 1.0)
	var height_zoom = screen_size.y / maxf(bounds.size.y + zoom_margin * 2.0, 1.0)
	var target_zoom = clampf(minf(width_zoom, height_zoom), min_zoom, max_zoom)
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), follow_speed * delta)
	
	# Screen Shake application
	if trauma > 0.0:
		trauma = maxf(trauma - (trauma_decay * delta), 0.0)
		var shake_amount = trauma * trauma
		offset = Vector2(
			randf_range(-max_offset.x, max_offset.x) * shake_amount,
			randf_range(-max_offset.y, max_offset.y) * shake_amount
		)
	else:
		offset = Vector2.ZERO
