class_name SwitchGate
extends StaticBody2D

## Tür oder Falltür, die ein Schalter (LevelSwitch) öffnet oder schließt.
##  "door"  senkrecht, fährt nach oben in den Rahmen.
##  "hatch" waagrecht, zwei Klappen schwingen an den Rändern nach unten auf.
## invert = false: geschlossen, Schalter an öffnet. invert = true: offen,
## Schalter an schließt.
##
## Sicherheit: Geschlossen wird nur, wenn niemand (Spieler, Kiste, Kugel) im
## Rahmen steht. Sonst wartet die Tür und blinkt, bis der Weg frei ist. So
## klemmt nie jemand fest. Host entscheidet, Clients spielen nach Snapshot.

const TILE_SIZE: float = 36.0
const MOVE_TIME: float = 0.28
const BLOCK_RETRY: float = 0.15
const HATCH_SEGMENT: float = 4.0 * TILE_SIZE

var net_id: int = 0
var object_type: String = "switch_gate"
var is_replica: bool = false
var network = null

var kind: String = "door"
var invert: bool = false
## Größe in Pixeln, Ursprung = linke obere Ecke.
var size_px: Vector2 = Vector2(TILE_SIZE, TILE_SIZE * 2.0)
var channels: Array = [0]
var powered: bool = false
var tile_texture: Texture2D = null

var is_open: bool = false
var _amount: float = 0.0 # 0 = zu, 1 = offen (Animation)
var _wants_open: bool = false
var _blocked: bool = false
var _retry: float = 0.0
var _shape: CollisionShape2D = null
var _color: Color = Color.WHITE

func _ready() -> void:
	add_to_group("solid")
	add_to_group("switch_gate")
	collision_layer = 1
	collision_mask = 7
	z_index = 1
	_color = SwitchNetwork.channel_color(int(channels[0]) if not channels.is_empty() else 0)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px
	_shape.shape = rect
	_shape.position = size_px * 0.5
	add_child(_shape)
	is_open = invert
	_wants_open = is_open
	_amount = 1.0 if is_open else 0.0
	_apply_collision()

func set_powered(on: bool) -> void:
	powered = on
	if is_replica:
		return
	_wants_open = on != invert
	_retry = 0.0

func _physics_process(delta: float) -> void:
	if not is_replica and _wants_open != is_open:
		if _wants_open:
			is_open = true
			_blocked = false
			_apply_collision()
			SoundManager.play_sound("dash", 0.1, -8.0)
			NetFx.send("mobj", NetFx.mobj_args(self, "move"))
		else:
			_retry -= delta
			if _retry <= 0.0:
				_retry = BLOCK_RETRY
				_blocked = _is_occupied()
				if not _blocked:
					is_open = false
					_apply_collision()
					SoundManager.play_sound("dash", 0.1, -8.0)
					NetFx.send("mobj", NetFx.mobj_args(self, "move"))
	var target := 1.0 if is_open else 0.0
	if not is_equal_approx(_amount, target):
		_amount = move_toward(_amount, target, delta / MOVE_TIME)
		queue_redraw()
	elif _blocked:
		queue_redraw()

func _apply_collision() -> void:
	if _shape == null:
		return
	_shape.set_deferred("disabled", is_open)

## Steht etwas im Rahmen? Spieler, Kisten und Kugeln.
func _is_occupied() -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size_px + Vector2(2.0, 2.0)
	query.shape = rect
	query.transform = Transform2D(0.0, global_position + size_px * 0.5)
	query.collision_mask = 1 | 2
	query.exclude = [get_rid()]
	for hit in space.intersect_shape(query, 16):
		var body = hit.get("collider")
		if body is Player:
			if (body as Player).current_health > 0.0:
				return true
		elif body is RigidBody2D and not (body as RigidBody2D).freeze:
			return true
	return false

func play_network_fx(method: String) -> void:
	if method == "move":
		SoundManager.play_sound("dash", 0.1, -8.0)

# --- Optik ---------------------------------------------------------------------

func _draw() -> void:
	# Rahmen bleibt immer sichtbar, damit man auch die offene Tür erkennt.
	var frame_col := Color(_color.r, _color.g, _color.b, 0.75)
	if _blocked and fmod(float(Time.get_ticks_msec()) / 1000.0, 0.3) < 0.15:
		frame_col = Color(1.0, 0.3, 0.3, 0.9)
	if kind == "hatch":
		_draw_hatch(frame_col)
	else:
		_draw_door(frame_col)

func _draw_door(frame_col: Color) -> void:
	var w := size_px.x
	var h := size_px.y
	# Schiene oben und unten.
	draw_rect(Rect2(Vector2(-3.0, -4.0), Vector2(w + 6.0, 5.0)), frame_col)
	draw_rect(Rect2(Vector2(-3.0, h - 1.0), Vector2(w + 6.0, 4.0)), frame_col)
	var visible_h := h * (1.0 - _amount)
	if visible_h < 1.0:
		return
	_draw_panel(Rect2(Vector2(3.0, 0.0), Vector2(w - 6.0, visible_h)))

func _draw_hatch(frame_col: Color) -> void:
	var w := size_px.x
	var h := size_px.y
	# Breite Falltüren bestehen aus mehreren Klappenpaaren (je höchstens
	# HATCH_SEGMENT breit), damit offene Klappen nicht bis in den Boden hängen.
	var segments := maxi(1, int(ceil(w / HATCH_SEGMENT)))
	var seg_w := w / float(segments)
	var half := seg_w * 0.5
	var angle := _amount * PI * 0.5
	for i in range(segments):
		var x0 := seg_w * float(i)
		# Scharniere an den Rändern jedes Paars.
		draw_circle(Vector2(x0, h * 0.5), 4.0, frame_col)
		draw_circle(Vector2(x0 + seg_w, h * 0.5), 4.0, frame_col)
		# Linke Klappe dreht um die linke Kante nach unten, rechte um die rechte.
		draw_set_transform(Vector2(x0, 0.0), angle, Vector2.ONE)
		_draw_panel(Rect2(Vector2(0.0, 0.0), Vector2(half - 1.0, h)))
		draw_set_transform(Vector2(x0 + seg_w, 0.0), -angle, Vector2.ONE)
		_draw_panel(Rect2(Vector2(-half + 1.0, 0.0), Vector2(half - 1.0, h)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Metallplatte mit Warnstreifen in Kanalfarbe.
func _draw_panel(r: Rect2) -> void:
	if tile_texture != null:
		draw_texture_rect(tile_texture, r, true, Color(0.75, 0.75, 0.8, 1.0))
	else:
		draw_rect(r, Color(0.2, 0.22, 0.27, 1.0))
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.25))
	var stripe := Color(_color.r, _color.g, _color.b, 0.55)
	var step := 14.0
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(maxf(x, r.position.x), r.position.y + maxf(0.0, r.position.x - x))
		var b_x := minf(x + r.size.y, r.end.x)
		var b := Vector2(b_x, r.position.y + (b_x - x))
		if a.x < b.x and a.y < r.end.y:
			b.y = minf(b.y, r.end.y)
			draw_line(a, b, stripe, 4.0)
		x += step
	draw_rect(r, _color.darkened(0.2), false, 2.0)

# --- Netzwerk ------------------------------------------------------------------

func get_network_state() -> Dictionary:
	return {"id": net_id, "type": object_type, "o": is_open, "b": _blocked}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	var open := bool(data.get("o", is_open))
	_blocked = bool(data.get("b", false))
	if open != is_open:
		is_open = open
		_apply_collision()
	queue_redraw()

# --- Bots und Werkzeuge ----------------------------------------------------------

func get_rect() -> Rect2:
	return Rect2(global_position, size_px)

## Was brächte es, wenn der Schalter diese Tür jetzt umlegt?
func bot_value(bot: Node2D, enemy: Node2D) -> float:
	var will_open := not invert
	if will_open == is_open:
		return 0.0
	var r := get_rect()
	if kind == "hatch":
		if not will_open:
			return 0.0
		var value := 0.0
		if _stands_on(enemy, r):
			value += 3.0
		if _stands_on(bot, r):
			value -= 4.0
		return value
	# Tür: lohnt sich, wenn sie zwischen Bot und Gegner steht.
	if will_open:
		var lo := minf(bot.global_position.x, enemy.global_position.x)
		var hi := maxf(bot.global_position.x, enemy.global_position.x)
		var between := r.position.x > lo and r.end.x < hi
		var y_hit := (bot.global_position.y > r.position.y - 20.0 and bot.global_position.y < r.end.y + 20.0) \
			or (enemy.global_position.y > r.position.y - 20.0 and enemy.global_position.y < r.end.y + 20.0)
		return 1.2 if between and y_hit else 0.0
	return 0.0

static func _stands_on(p: Node2D, r: Rect2) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	var feet := p.global_position.y + 14.0 * p.scale.y
	return p.global_position.x > r.position.x - 6.0 and p.global_position.x < r.end.x + 6.0 \
		and feet > r.position.y - 30.0 and feet < r.position.y + 6.0
