class_name DynamicCamera
extends Camera2D

@export var min_zoom: float = 0.65
@export var max_zoom: float = 1.25
@export var zoom_margin: float = 240.0
@export var follow_speed: float = 6.0
@export var intro_start_zoom: float = 1.65
@export var intro_duration: float = 2.2

var targets: Array[Node2D] = []

# Rundenstart-Intro: Die Kamera beginnt nah am lokalen Charakter und zoomt
# anschließend zur normalen Übersicht über alle Spieler heraus.
var _intro_focus: Node2D = null
var _intro_elapsed: float = 0.0
var _intro_duration: float = 0.0
var _intro_start_zoom: float = 1.0
var _intro_active: bool = false

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

# Startet den Rundenstart-Zoom am übergebenen Charakter. duration <= 0 nutzt
# den exportierten Standardwert; dasselbe gilt für start_zoom.
func start_round_intro(focus: Node2D, duration: float = -1.0, start_zoom: float = -1.0) -> void:
	if not is_instance_valid(focus):
		return
	_intro_focus = focus
	_intro_elapsed = 0.0
	_intro_duration = maxf(0.05, duration if duration > 0.0 else intro_duration)
	_intro_start_zoom = maxf(0.05, start_zoom if start_zoom > 0.0 else intro_start_zoom)
	_intro_active = true
	global_position = focus.global_position
	zoom = Vector2(_intro_start_zoom, _intro_start_zoom)
	trauma = 0.0
	offset = Vector2.ZERO

func cancel_round_intro() -> void:
	_intro_active = false
	_intro_focus = null
	_intro_elapsed = 0.0

func is_round_intro_active() -> bool:
	return _intro_active

func get_round_intro_focus() -> Node2D:
	return _intro_focus

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
	
	# Zoom calculation
	var screen_size = get_viewport_rect().size
	var width_zoom = screen_size.x / maxf(bounds.size.x + zoom_margin * 2.0, 1.0)
	var height_zoom = screen_size.y / maxf(bounds.size.y + zoom_margin * 2.0, 1.0)
	var target_zoom = clampf(minf(width_zoom, height_zoom), min_zoom, max_zoom)

	var intro_running := _intro_active and is_instance_valid(_intro_focus)
	if _intro_active and not intro_running:
		cancel_round_intro()

	if intro_running:
		_intro_elapsed = minf(_intro_elapsed + delta, _intro_duration)
		var progress := _intro_elapsed / _intro_duration
		var eased := smoothstep(0.0, 1.0, progress)
		global_position = _intro_focus.global_position.lerp(target_center, eased)
		var zoom_value := lerpf(_intro_start_zoom, target_zoom, eased)
		zoom = Vector2(zoom_value, zoom_value)
		if progress >= 1.0:
			cancel_round_intro()
	else:
		global_position = global_position.lerp(target_center, follow_speed * delta)
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
