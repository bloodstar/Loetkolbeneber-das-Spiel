class_name MovingPlatform
extends Node2D

## Plattform, die zwischen zwei Punkten hin- und herfährt (Aufzug oder Fähre).
## Der Host bewegt einen AnimatableBody2D entlang der Bahn; Spieler, die darauf
## stehen, werden von move_and_slide() mitgenommen. Clients erhalten Phase und
## Position per Snapshot und fahren dazwischen lokal weiter, damit die Bewegung
## auch bei 20-Hz-Snapshots flüssig bleibt.

const TILE_SIZE: float = 36.0

var net_id: int = 0
var object_type: String = "moving_platform"
var is_replica: bool = false
var platform_width: float = 3.0 * TILE_SIZE
var platform_height: float = 18.0
## Fahrweg relativ zum Startpunkt in Pixeln.
var travel: Vector2 = Vector2(4.0 * TILE_SIZE, 0.0)
## Dauer einer kompletten Hin- und Rückfahrt in Sekunden.
var period: float = 6.0
## Startphase 0..1, damit gespiegelte Plattformen gegenläufig fahren können.
var phase: float = 0.0
var accent: Color = Color(0.35, 0.85, 1.0, 1.0)
## Optional: Plattform-Kachel des Map-Themes. Gezeigt wird die obere Hälfte,
## damit die Fähre wie ein Stück der festen Plattformen aussieht.
var tile_texture: Texture2D
var smooth_tiles: bool = true

var body: AnimatableBody2D
var _time: float = 0.0

func _ready() -> void:
	_time = phase * period
	_build()
	body.position = _offset_at(_time)
	if is_replica:
		set_replica(true)

func _build() -> void:
	z_index = 2
	_build_track()

	body = AnimatableBody2D.new()
	body.name = "Platform"
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.add_to_group("solid")
	add_child(body)

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(platform_width, platform_height)
	col.shape = rect
	body.add_child(col)

	var half_w := platform_width * 0.5
	var half_h := platform_height * 0.5
	if tile_texture != null:
		_build_tiles(half_w, half_h)
	else:
		_build_plain(half_w, half_h)

	# Kleine Leuchtpfeile zeigen die Fahrtrichtung an.
	var arrow_dir := travel.normalized() if travel.length() > 0.1 else Vector2.RIGHT
	for i in range(-1, 2):
		var arrow := Polygon2D.new()
		var c := Vector2(float(i) * minf(28.0, half_w * 0.5), half_h - 4.0)
		var fwd := arrow_dir * 3.5
		var side := Vector2(-arrow_dir.y, arrow_dir.x) * 2.5
		arrow.polygon = PackedVector2Array([c + fwd, c - fwd + side, c - fwd - side])
		arrow.color = Color(accent.r, accent.g, accent.b, 0.95)
		body.add_child(arrow)

func _build_tiles(half_w: float, half_h: float) -> void:
	var tex_w := maxf(1.0, float(tile_texture.get_width()))
	var tex_h := maxf(1.0, float(tile_texture.get_height()))
	var tiles := maxi(1, int(round(platform_width / TILE_SIZE)))
	var tile_w := platform_width / float(tiles)
	for i in range(tiles):
		var sp := Sprite2D.new()
		sp.texture = tile_texture
		sp.region_enabled = true
		sp.region_rect = Rect2(0.0, 0.0, tex_w, tex_h * 0.5)
		sp.scale = Vector2(tile_w / tex_w, platform_height / (tex_h * 0.5))
		if smooth_tiles:
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.position = Vector2(-half_w + tile_w * (float(i) + 0.5), 0.0)
		body.add_child(sp)
	# Leuchtende Unterkante in Akzentfarbe markiert die bewegliche Plattform.
	var glow := Line2D.new()
	glow.points = PackedVector2Array([Vector2(-half_w + 3.0, half_h - 1.0), Vector2(half_w - 3.0, half_h - 1.0)])
	glow.width = 3.0
	glow.default_color = Color(accent.r, accent.g, accent.b, 0.9)
	body.add_child(glow)

func _build_plain(half_w: float, half_h: float) -> void:
	var base := Polygon2D.new()
	base.polygon = PackedVector2Array([
		Vector2(-half_w, -half_h), Vector2(half_w, -half_h),
		Vector2(half_w - 4.0, half_h), Vector2(-half_w + 4.0, half_h),
	])
	base.color = Color(0.20, 0.23, 0.30, 1.0)
	body.add_child(base)

	var top := Line2D.new()
	top.points = PackedVector2Array([Vector2(-half_w, -half_h + 1.5), Vector2(half_w, -half_h + 1.5)])
	top.width = 4.0
	top.default_color = accent.lightened(0.15)
	body.add_child(top)

func _build_track() -> void:
	# Gestrichelte Schiene entlang der Fahrbahn, damit Spieler die Route sehen.
	var track := Line2D.new()
	track.name = "Track"
	track.points = PackedVector2Array([Vector2.ZERO, travel])
	track.width = 3.0
	track.default_color = Color(accent.r, accent.g, accent.b, 0.4)
	track.z_index = -1
	add_child(track)
	for p in [Vector2.ZERO, travel]:
		var dot := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in range(8):
			var a := TAU * float(k) / 8.0
			pts.append(p + Vector2(cos(a), sin(a)) * 5.0)
		dot.polygon = pts
		dot.color = Color(accent.r, accent.g, accent.b, 0.45)
		dot.z_index = -1
		add_child(dot)

## Sanftes Pendeln: Kosinus-Profil, damit die Plattform an den Endpunkten
## abbremst und Spieler nicht abgeworfen werden.
func _offset_at(t: float) -> Vector2:
	var u := fposmod(t / maxf(0.1, period), 1.0)
	var k := 0.5 - 0.5 * cos(u * TAU)
	return travel * k

func _physics_process(delta: float) -> void:
	if body == null:
		return
	_time += delta
	body.position = _offset_at(_time)

func set_replica(replica: bool) -> void:
	is_replica = replica
	if body == null:
		return
	# Clients bewegen die Plattform weiter lokal (rein visuell), kollidieren
	# aber nicht – Spielerpositionen kommen ohnehin vom Host.
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
		"pos": body.global_position if body != null else global_position,
		"t": _time,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica or body == null:
		return
	# Host und Client zählen die Zeit gleich schnell weiter. Die Phase des
	# Hosts direkt zu übernehmen erzeugt daher nur winzige Sprünge, hält die
	# Plattform aber exakt synchron mit den Spielerpositionen des Hosts.
	_time = float(data.get("t", _time))
	body.position = _offset_at(_time)

# --- Hilfen für tools/level_check ------------------------------------------

## Gesamter Bereich, den die Plattform samt Mitfahrern überstreicht.
func get_path_rect() -> Rect2:
	var half := Vector2(platform_width * 0.5, platform_height * 0.5)
	var a := Rect2(position - half, half * 2.0)
	var b := Rect2(position + travel - half, half * 2.0)
	var r := a.merge(b)
	# Kopfraum für Mitfahrer.
	r.position.y -= 60.0
	r.size.y += 60.0
	return r

## Plattform-Rechtecke an fünf Punkten der Bahn (für die Erreichbarkeit).
func get_sample_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var half := Vector2(platform_width * 0.5, platform_height * 0.5)
	for i in range(5):
		var p := position + travel * (float(i) / 4.0)
		out.append(Rect2(p - half, half * 2.0))
	return out
