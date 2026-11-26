extends Node2D

## Schockfunken um einen betäubten Eber: zuckende Blitzbögen um den Körper
## und kreisende Funken über dem Kopf. Der Player setzt jedes Frame die
## Restdauer (set_stun), online kommt sie per Snapshot ("stn"), daher läuft
## das auch auf Replikas. In der Arena wird um die Standhöhe versetzt.

const ARC_COUNT: int = 4
const ARC_SEGMENTS: int = 5
const ARC_REFRESH: float = 0.06
const BODY_RADIUS: Vector2 = Vector2(17.0, 19.0)
const CENTER: Vector2 = Vector2(0.0, -1.0)
const HEAD_CENTER: Vector2 = Vector2(0.0, -24.0)
const HEAD_RADIUS: Vector2 = Vector2(11.0, 3.5)
const STAR_COUNT: int = 4
const STAR_SPIN: float = 7.0 # rad/s
const FADE_IN: float = 14.0
const FADE_OUT: float = 5.0
const GLOW_COLOR: Color = Color(0.45, 0.75, 1.0, 0.6)
const CORE_COLOR: Color = Color(1.0, 1.0, 0.75, 1.0)
const STAR_COLOR: Color = Color(1.0, 0.92, 0.3, 1.0)
# Arena: Bildschirm-Versatz vom Bodenpunkt zur Körpermitte des Voxel-Ebers.
const ARENA_BODY_OFFSET: Vector2 = Vector2(0.0, -15.0)

var player: Node2D = null
var _remaining: float = 0.0
var _alpha: float = 0.0
var _time: float = 0.0
var _arc_timer: float = 0.0
var _arcs: Array = [] # Array von PackedVector2Array
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	z_index = 2
	set_process(false)
	visible = false

func set_stun(remaining: float) -> void:
	_remaining = remaining
	if remaining > 0.0 and not is_processing():
		set_process(true)
		visible = true
		_arc_timer = 0.0

func _process(delta: float) -> void:
	_time += delta
	if _remaining > 0.0:
		_alpha = minf(1.0, _alpha + delta * FADE_IN)
	else:
		_alpha = maxf(0.0, _alpha - delta * FADE_OUT)
		if _alpha <= 0.0:
			set_process(false)
			visible = false
			_arcs.clear()
			return
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = ARC_REFRESH
		_regenerate_arcs()
	queue_redraw()

func _regenerate_arcs() -> void:
	_arcs.clear()
	for i in ARC_COUNT:
		var start_angle := _rng.randf() * TAU
		var span := _rng.randf_range(0.9, 1.7)
		var pts := PackedVector2Array()
		for s in ARC_SEGMENTS + 1:
			var t := float(s) / float(ARC_SEGMENTS)
			var a := start_angle + span * t
			var jitter := 1.0 if s == 0 or s == ARC_SEGMENTS else _rng.randf_range(0.75, 1.3)
			pts.append(CENTER + Vector2(cos(a) * BODY_RADIUS.x, sin(a) * BODY_RADIUS.y) * jitter)
		_arcs.append(pts)

func _draw() -> void:
	if _alpha <= 0.0:
		return
	# Arena: Die 2D-Ebene liegt am Boden, das Voxel-Schwein steht auf seiner Höhe.
	# Dazu ein Stück nach oben, damit die Funken um den Körper statt um die
	# Füße sitzen (die 2D-Position ist der Bodenpunkt).
	if ArenaMode.active and is_instance_valid(player) and player.has_method("arena_lift"):
		var lift: Vector2 = player.call("arena_lift") + ARENA_BODY_OFFSET
		if lift != Vector2.ZERO:
			var sc := global_scale
			draw_set_transform(Vector2(lift.x / maxf(absf(sc.x), 0.01), lift.y / maxf(absf(sc.y), 0.01)))
	var flicker := 0.75 + 0.25 * sin(_time * 40.0)
	var a := _alpha * flicker
	for pts in _arcs:
		var glow := GLOW_COLOR
		glow.a *= a
		draw_polyline(pts, glow, 5.5, true)
		var core := CORE_COLOR
		core.a *= a
		draw_polyline(pts, core, 2.0, true)
		# Funke am Ende jedes Bogens.
		draw_circle(pts[pts.size() - 1], 2.2, core)
	# Kreisende Funken über dem Kopf (wie Sternchen bei Benommenheit).
	for i in STAR_COUNT:
		var ang := _time * STAR_SPIN + TAU * float(i) / float(STAR_COUNT)
		var p := HEAD_CENTER + Vector2(cos(ang) * HEAD_RADIUS.x, sin(ang) * HEAD_RADIUS.y)
		var star := STAR_COLOR
		# Hintere Funken etwas blasser, damit der Kreis räumlich wirkt.
		star.a *= a * (0.55 + 0.45 * (0.5 + 0.5 * sin(ang)))
		_draw_spark(p, 3.4, star)

func _draw_spark(p: Vector2, size: float, color: Color) -> void:
	draw_line(p + Vector2(-size, 0.0), p + Vector2(size, 0.0), color, 1.8, true)
	draw_line(p + Vector2(0.0, -size), p + Vector2(0.0, size), color, 1.8, true)
	draw_circle(p, size * 0.45, Color(1.0, 1.0, 1.0, color.a))
