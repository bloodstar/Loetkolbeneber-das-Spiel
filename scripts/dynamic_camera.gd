class_name DynamicCamera
extends Camera2D

@export var min_zoom: float = 0.65
# Nächste Zoomstufe der Arena-Kamera. 0.96 statt 1.25 (rund 30 % weiter
# draußen), damit zwei nah kämpfende Spieler nicht zu groß im Bild sind.
@export var max_zoom: float = 0.96
@export var zoom_margin: float = 240.0
@export var follow_speed: float = 6.0
@export var intro_start_zoom: float = 1.65
@export var intro_duration: float = 2.2

var targets: Array[Node2D] = []

# Scroll-Levels: Die Kamera folgt nur den Spielern in focus_targets (lokale
# Spieler) und bleibt innerhalb von world_rect. Alle anderen Ziele bekommen
# einen Randpfeil, sobald sie außerhalb des Bildes sind.
var scroll_mode: bool = false
var focus_targets: Array[Node2D] = []
var world_rect: Rect2 = Rect2()
@export var scroll_max_zoom: float = 1.0
var _indicator_layer: CanvasLayer
var _indicator_canvas: Control

# Rundenstart-Intro: Die Kamera beginnt nah am lokalen Charakter und zoomt
# anschließend zur normalen Übersicht über alle Spieler heraus.
var _intro_focus: Node2D = null
var _intro_elapsed: float = 0.0
var _intro_duration: float = 0.0
var _intro_start_zoom: float = 1.0
var _intro_active: bool = false

# Kill-Cam: Beim rundenentscheidenden Tod zoomt die Kamera nah auf Todesort
# und Schützen. Läuft in Echtzeit, weil main.gd dabei Engine.time_scale senkt.
@export var kill_cam_zoom: float = 2.0
@export var kill_cam_blend_time: float = 0.35
# Ist der Schütze weiter weg, als beide nah ins Bild passen, zeigt die
# Kamera nur den Todesort.
@export var kill_cam_min_fit_zoom: float = 1.25
var _kill_cam_active: bool = false
var _kill_cam_point: Vector2 = Vector2.ZERO
var _kill_cam_killer: Node2D = null
var _kill_cam_elapsed: float = 0.0
var _kill_cam_from_pos: Vector2 = Vector2.ZERO
var _kill_cam_from_zoom: float = 1.0

# Screen Shake
var trauma: float = 0.0
var trauma_decay: float = 2.5
var max_offset: Vector2 = Vector2(16.0, 16.0)

func _ready() -> void:
	add_to_group("dynamic_camera")
	_indicator_layer = CanvasLayer.new()
	_indicator_layer.layer = 5
	add_child(_indicator_layer)
	_indicator_canvas = Control.new()
	_indicator_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_indicator_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicator_canvas.draw.connect(_draw_offscreen_indicators)
	_indicator_layer.add_child(_indicator_canvas)

## Schaltet zwischen Arena-Kamera (alle Spieler im Bild) und Scroll-Kamera
## (folgt den lokalen Spielern, begrenzt auf die Karte) um.
func configure_world(rect: Rect2, scrolling: bool, local_targets: Array[Node2D]) -> void:
	world_rect = rect
	scroll_mode = scrolling
	focus_targets = local_targets.duplicate()
	if scrolling:
		# Etwas Rand, damit die Gummiwand am Kartenrand sichtbar bleibt.
		limit_left = int(rect.position.x - 140.0)
		limit_right = int(rect.end.x + 140.0)
		limit_top = int(rect.position.y - 260.0)
		limit_bottom = int(rect.end.y + 140.0)
	else:
		limit_left = -10000000
		limit_right = 10000000
		limit_top = -10000000
		limit_bottom = 10000000
	if _indicator_canvas:
		_indicator_canvas.queue_redraw()

func _active_targets() -> Array[Node2D]:
	if not scroll_mode:
		return targets
	var result: Array[Node2D] = []
	for t in focus_targets:
		if is_instance_valid(t) and t.visible and targets.has(t):
			result.append(t)
	# Eigener Spieler tot oder Zuschauer: allen verbleibenden Spielern folgen.
	return result if not result.is_empty() else targets

## Bildmitte, auf die die Arena-Kamera zielt: Mitte aller Spieler, ohne
## Glättung, Intro, Kill-Cam und Shake. Hängt nur von den synchronisierten
## Spielerpositionen ab und ist damit auf allen Clients gleich. Vector2.INF,
## wenn es keine Ziele gibt.
func get_shared_view_center() -> Vector2:
	var bounds := Rect2()
	var found := false
	for t in targets:
		if not is_instance_valid(t) or not t.visible:
			continue
		if not found:
			bounds = Rect2(t.global_position, Vector2.ZERO)
			found = true
		else:
			bounds = bounds.expand(t.global_position)
	return bounds.get_center() if found else Vector2.INF

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
	stop_kill_cam()
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

## Startet die Kill-Cam am Todesort. killer darf null sein (Lava, Selbsttod).
func start_kill_cam(point: Vector2, killer: Node2D = null) -> void:
	cancel_round_intro()
	_kill_cam_active = true
	_kill_cam_point = point
	_kill_cam_killer = killer
	_kill_cam_elapsed = 0.0
	_kill_cam_from_pos = global_position
	_kill_cam_from_zoom = zoom.x

func stop_kill_cam() -> void:
	_kill_cam_active = false
	_kill_cam_killer = null
	_kill_cam_elapsed = 0.0

func is_kill_cam_active() -> bool:
	return _kill_cam_active

# Mittelpunkt und Zoom der Kill-Cam: Todesort und Schütze zusammen, solange
# beide nah genug beieinander sind, sonst nur der Todesort.
func _kill_cam_frame() -> Array:
	var center := _kill_cam_point
	var target_zoom := kill_cam_zoom
	if is_instance_valid(_kill_cam_killer) and _kill_cam_killer.visible:
		var killer_pos := _kill_cam_killer.global_position
		var span := (killer_pos - _kill_cam_point).abs()
		var screen_size := get_viewport_rect().size
		var fit := minf(screen_size.x / maxf(span.x + 320.0, 1.0), screen_size.y / maxf(span.y + 260.0, 1.0))
		if fit >= kill_cam_min_fit_zoom:
			center = (_kill_cam_point + killer_pos) * 0.5
			target_zoom = minf(kill_cam_zoom, fit)
	return [center, target_zoom]

func _process_kill_cam(real_delta: float) -> void:
	var frame := _kill_cam_frame()
	var center: Vector2 = frame[0]
	var target_zoom: float = frame[1]
	if _kill_cam_elapsed < kill_cam_blend_time:
		_kill_cam_elapsed = minf(_kill_cam_elapsed + real_delta, kill_cam_blend_time)
		var eased := smoothstep(0.0, 1.0, _kill_cam_elapsed / maxf(kill_cam_blend_time, 0.001))
		global_position = _kill_cam_from_pos.lerp(center, eased)
		var zoom_value := lerpf(_kill_cam_from_zoom, target_zoom, eased)
		zoom = Vector2(zoom_value, zoom_value)
	else:
		var weight := minf(1.0, follow_speed * real_delta)
		global_position = global_position.lerp(center, weight)
		zoom = zoom.lerp(Vector2(target_zoom, target_zoom), weight)

func _process(delta: float) -> void:
	# Filter dead targets
	targets = targets.filter(func(t): return is_instance_valid(t))
	focus_targets = focus_targets.filter(func(t): return is_instance_valid(t))
	if _indicator_canvas:
		_indicator_canvas.queue_redraw()

	# delta ist um Engine.time_scale verkürzt; Kill-Cam und Shake laufen in Echtzeit.
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	if _kill_cam_active:
		_process_kill_cam(real_delta)
		_apply_shake(real_delta)
		return

	if targets.is_empty():
		return
	var active := _active_targets()
	
	# Midpoint calculation
	var bounds = Rect2(active[0].global_position, Vector2.ZERO)
	for t in active:
		bounds = bounds.expand(t.global_position)
	
	var target_center = bounds.get_center()
	
	# Zoom calculation
	var screen_size = get_viewport_rect().size
	var width_zoom = screen_size.x / maxf(bounds.size.x + zoom_margin * 2.0, 1.0)
	var height_zoom = screen_size.y / maxf(bounds.size.y + zoom_margin * 2.0, 1.0)
	var target_zoom = clampf(minf(width_zoom, height_zoom), min_zoom, scroll_max_zoom if scroll_mode else max_zoom)

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
	
	_apply_shake(real_delta)

func _apply_shake(delta: float) -> void:
	if trauma > 0.0:
		trauma = maxf(trauma - (trauma_decay * delta), 0.0)
		var shake_amount = trauma * trauma
		offset = Vector2(
			randf_range(-max_offset.x, max_offset.x) * shake_amount,
			randf_range(-max_offset.y, max_offset.y) * shake_amount
		)
	else:
		offset = Vector2.ZERO

# Randpfeile für Spieler außerhalb des Bildes (nur in Scroll-Levels). Die
# Farbe ist die Teamfarbe, die Größe wächst mit der Nähe.
func _draw_offscreen_indicators() -> void:
	if not scroll_mode or _indicator_canvas == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var screen := vp.get_visible_rect().size
	var xform := get_canvas_transform()
	var margin := 26.0
	var center := screen * 0.5
	for t in targets:
		if not is_instance_valid(t) or not t.visible or focus_targets.has(t):
			continue
		# Für diesen Betrachter unsichtbare Spieler (Powerup) verraten keinen Pfeil.
		if t is Player and t.is_invisible() and t.modulate.a < 0.3:
			continue
		var sp: Vector2 = xform * t.global_position
		if sp.x >= 0.0 and sp.x <= screen.x and sp.y >= 0.0 and sp.y <= screen.y:
			continue
		var dir := (sp - center)
		if dir.length() < 0.01:
			continue
		var scale_x := (screen.x * 0.5 - margin) / maxf(0.001, absf(dir.x))
		var scale_y := (screen.y * 0.5 - margin) / maxf(0.001, absf(dir.y))
		var edge := center + dir * minf(scale_x, scale_y)
		var n := dir.normalized()
		var side := Vector2(-n.y, n.x)
		var dist := t.global_position.distance_to(global_position)
		var size := clampf(22.0 - dist / 160.0, 10.0, 20.0)
		var color := Color(1, 1, 1, 0.9)
		var team = t.get("team_id")
		if team != null:
			color = Global.get_team_color(int(team))
		color.a = 0.9
		var pts := PackedVector2Array([edge + n * size, edge - n * size * 0.6 + side * size * 0.7, edge - n * size * 0.6 - side * size * 0.7])
		_indicator_canvas.draw_colored_polygon(pts, color)
		_indicator_canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.6), 2.0)
