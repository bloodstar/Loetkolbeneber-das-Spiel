class_name RotatingPlatform
extends Node2D

## Balken, der sich mit fester Geschwindigkeit um einen Drehpunkt dreht
## (Uhrzeiger auf Uhrwerk, Rührwerk auf Kugellawine, Windmühlen auf
## Kugelmühle). Der Host dreht einen AnimatableBody2D; Spieler, die darauf
## stehen, nimmt move_and_slide() mit, Kugeln, Kisten und Fässer schiebt der
## Balken physikalisch weg. Wie MovingPlatform dreht der Client lokal weiter
## (ohne Kollision) und übernimmt per Snapshot die Zeit des Hosts.

const TILE_SIZE: float = 36.0
## Luft rund um den Schwenkkreis: eine Spielerhöhe plus Reserve. Der
## Generator hält den Bereich frei, damit niemand eingeklemmt wird; dieselbe
## Zahl nutzt tools/level_check.
const CLEARANCE: float = 26.0

var net_id: int = 0
var object_type: String = "rotating_platform"
var is_replica: bool = false
## Länge vom Drehpunkt bis zur Spitze in Pixeln.
var arm_length: float = 6.0 * TILE_SIZE
## Länge auf der Gegenseite: 0 = Zeiger nur nach einer Seite,
## gleich arm_length = Balken mittig gelagert.
var tail_length: float = 0.0
var thickness: float = 18.0
## Anzahl Balken, gleichmäßig über 180 Grad verteilt (2 = Kreuz/Windmühle).
var spokes: int = 1
## Sekunden pro Umdrehung; negativ dreht gegen den Uhrzeigersinn.
var period: float = 12.0
## Startwinkel in Umdrehungen (0 = zeigt nach rechts, 0.75 = nach oben).
var phase: float = 0.0
## "bar" = nur Balken, "clock" = mit Zifferblatt und kleinem Stundenzeiger.
var style: String = "bar"
var accent: Color = Color(1.0, 0.78, 0.25, 1.0)
## Optional: Plattform-Kachel des Map-Themes (obere Hälfte, wie MovingPlatform).
var tile_texture: Texture2D
var smooth_tiles: bool = true

var body: AnimatableBody2D
var _hour_hand: Node2D
var _time: float = 0.0

func _ready() -> void:
	_build()
	_apply_time()
	if is_replica:
		set_replica(true)

func _build() -> void:
	z_index = 2
	if style == "clock":
		_build_dial()

	body = AnimatableBody2D.new()
	body.name = "Rotor"
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.add_to_group("solid")
	add_child(body)

	var length := arm_length + tail_length
	var center_x := (arm_length - tail_length) * 0.5
	for i in range(maxi(1, spokes)):
		var arm := Node2D.new()
		arm.rotation = PI * float(i) / float(maxi(1, spokes))
		body.add_child(arm)
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(length, thickness)
		col.shape = rect
		col.position = Vector2(center_x, 0.0).rotated(arm.rotation)
		col.rotation = arm.rotation
		body.add_child(col)
		if tile_texture != null:
			_build_tiles(arm, length, center_x)
		else:
			_build_plain(arm, length, center_x)
		if style == "clock":
			_build_tip(arm)
	_build_hub()

func _build_tiles(parent: Node2D, length: float, center_x: float) -> void:
	var tex_w := maxf(1.0, float(tile_texture.get_width()))
	var tex_h := maxf(1.0, float(tile_texture.get_height()))
	var tiles := maxi(1, int(round(length / TILE_SIZE)))
	var tile_w := length / float(tiles)
	var start := center_x - length * 0.5
	for i in range(tiles):
		var sp := Sprite2D.new()
		sp.texture = tile_texture
		sp.region_enabled = true
		sp.region_rect = Rect2(0.0, 0.0, tex_w, tex_h * 0.5)
		sp.scale = Vector2(tile_w / tex_w, thickness / (tex_h * 0.5))
		if smooth_tiles:
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.position = Vector2(start + tile_w * (float(i) + 0.5), 0.0)
		parent.add_child(sp)
	# Leuchtende Kanten in Akzentfarbe markieren den Drehbalken.
	for y in [-thickness * 0.5 + 1.0, thickness * 0.5 - 1.0]:
		var glow := Line2D.new()
		glow.points = PackedVector2Array([Vector2(start + 3.0, y), Vector2(start + length - 3.0, y)])
		glow.width = 2.5
		glow.default_color = Color(accent.r, accent.g, accent.b, 0.85)
		parent.add_child(glow)

func _build_plain(parent: Node2D, length: float, center_x: float) -> void:
	var half_h := thickness * 0.5
	var x0 := center_x - length * 0.5
	var x1 := center_x + length * 0.5
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(x0, -half_h), Vector2(x1, -half_h), Vector2(x1, half_h), Vector2(x0, half_h),
	])
	base.color = Color(0.20, 0.23, 0.30, 1.0)
	parent.add_child(base)
	var top := Line2D.new()
	top.points = PackedVector2Array([Vector2(x0, -half_h + 1.5), Vector2(x1, -half_h + 1.5)])
	top.width = 4.0
	top.default_color = accent.lightened(0.15)
	parent.add_child(top)

## Pfeilspitze am Ende des Uhrzeigers (nur Optik, liegt auf dem Balken).
func _build_tip(parent: Node2D) -> void:
	var tip := Polygon2D.new()
	var x := arm_length
	var h := thickness * 0.5
	tip.polygon = PackedVector2Array([
		Vector2(x - 30.0, -h), Vector2(x, 0.0), Vector2(x - 30.0, h),
	])
	tip.color = Color(accent.r, accent.g, accent.b, 0.95)
	tip.z_index = 1
	parent.add_child(tip)

## Nabe in der Mitte (nur Optik): Spieler sehen, wo der Balken gelagert ist.
func _build_hub() -> void:
	var hub_r := thickness * 0.5 + 5.0
	var ring := Polygon2D.new()
	ring.polygon = _circle_points(hub_r, 16)
	ring.color = accent.darkened(0.25)
	ring.z_index = 1
	add_child(ring)
	var cap := Polygon2D.new()
	cap.polygon = _circle_points(hub_r * 0.45, 12)
	cap.color = Color(0.12, 0.12, 0.15, 1.0)
	cap.z_index = 1
	add_child(cap)

## Zifferblatt hinter dem Zeiger: Scheibe, Rand, zwölf Striche und ein kleiner
## Stundenzeiger, der zwölfmal langsamer mitläuft. Alles ohne Kollision.
func _build_dial() -> void:
	var radius := arm_length + 22.0
	var face := Polygon2D.new()
	face.polygon = _circle_points(radius, 64)
	face.color = Color(0.0, 0.0, 0.0, 0.22)
	face.z_index = -4
	add_child(face)
	var rim := Line2D.new()
	var rim_pts := _circle_points(radius, 64)
	rim_pts.append(rim_pts[0])
	rim.points = rim_pts
	rim.width = 5.0
	rim.default_color = Color(accent.r, accent.g, accent.b, 0.55)
	rim.z_index = -3
	add_child(rim)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var dir := Vector2(cos(a), sin(a))
		var major := i % 3 == 0
		var tick := Line2D.new()
		tick.points = PackedVector2Array([dir * (radius - (30.0 if major else 18.0)), dir * (radius - 6.0)])
		tick.width = 6.0 if major else 3.0
		tick.default_color = Color(accent.r, accent.g, accent.b, 0.7 if major else 0.45)
		tick.z_index = -3
		add_child(tick)
	_hour_hand = Node2D.new()
	_hour_hand.z_index = -2
	add_child(_hour_hand)
	var hand := Polygon2D.new()
	var len := arm_length * 0.55
	hand.polygon = PackedVector2Array([
		Vector2(-18.0, -7.0), Vector2(len - 20.0, -5.0), Vector2(len, 0.0),
		Vector2(len - 20.0, 5.0), Vector2(-18.0, 7.0),
	])
	hand.color = Color(accent.r, accent.g, accent.b, 0.4)
	_hour_hand.add_child(hand)

func _circle_points(r: float, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(count):
		var a := TAU * float(k) / float(count)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts

func _angle_at(t: float) -> float:
	var p := period if absf(period) >= 0.5 else 0.5
	return TAU * (phase + t / p)

func _apply_time() -> void:
	if body == null:
		return
	var angle := _angle_at(_time)
	body.rotation = fposmod(angle, TAU)
	if _hour_hand != null:
		# Stundenzeiger: zwölfmal langsamer, startet versetzt auf "vier Uhr".
		_hour_hand.rotation = fposmod(angle / 12.0 + TAU / 3.0, TAU)

func _physics_process(delta: float) -> void:
	_time += delta
	_apply_time()

func set_replica(replica: bool) -> void:
	is_replica = replica
	if body == null:
		return
	# Clients drehen nur optisch mit; Spieler- und Kugelpositionen kommen
	# vom Host.
	if replica:
		body.collision_layer = 0
		body.sync_to_physics = false
	else:
		body.collision_layer = 1
		body.sync_to_physics = true

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"t": _time,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica or body == null:
		return
	_time = float(data.get("t", _time))
	_apply_time()

# --- Hilfen für Generator und tools/level_check -----------------------------

## Radius des Kreises, den der Balken samt Ecken überstreicht.
func get_sweep_radius() -> float:
	return Vector2(maxf(arm_length, tail_length), thickness * 0.5).length()

## Standflächen, wenn der Balken waagrecht liegt (nach rechts bzw. links).
## Senkrechte Stellungen sind nicht begehbar und zählen nicht.
func get_stand_rects() -> Array[Rect2]:
	var half_h := thickness * 0.5
	var out: Array[Rect2] = []
	out.append(Rect2(position.x - tail_length, position.y - half_h, arm_length + tail_length, thickness))
	if not is_equal_approx(arm_length, tail_length):
		out.append(Rect2(position.x - arm_length, position.y - half_h, arm_length + tail_length, thickness))
	return out
