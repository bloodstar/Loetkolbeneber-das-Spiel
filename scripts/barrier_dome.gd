class_name BarrierDome
extends Node2D

## Barriere (Q) als glatte, prozedural gezeichnete Energiekugel im Stil der
## Schildblase aus powerup_aura.gd: weiche Füllung, leuchtender Rand,
## Glanzlichter und ein drehendes Wabenmuster auf der Kugel.
## Jeder Treffer lässt die Kugel aufblitzen, schickt eine Welle vom
## Einschlagpunkt aus und hinterlässt einen Riss. Beim Bruch übernimmt
## BarrierShatter (Scherben), die Kugel verschwindet sofort.

const RADIUS: float = 34.0
const CENTER: Vector2 = Vector2(0.0, -1.0)
const SEGMENTS: int = 56
const HEX_LON: int = 10 # Waben rundherum
const HEX_LAT: int = 5 # Wabenreihen von Pol zu Pol
const SPIN_SPEED: float = 1.6 # rad/s, Drehung um die Hochachse
const POP_TIME: float = 0.09
const FADE_SPEED: float = 9.0

var color: Color = Color(0.3, 0.8, 1.0, 0.7)
var active: bool = false
var _alpha: float = 0.0
var _pop: float = 1.0
var _time: float = 0.0
var _spin: float = 0.0
var _flash: float = 0.0
# [Einschlagrichtung (Einheitsvektor), Alter in s]
var _ripples: Array = []
var _cracks: Array[PackedVector2Array] = []
var _hex_segments: PackedVector2Array = PackedVector2Array()
var _hex_depth: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	z_index = 2
	_build_hex_grid()
	set_process(false)
	visible = false

# Waben-Kanten in Kugelkoordinaten (Länge, Breite), einmal vorberechnet.
func _build_hex_grid() -> void:
	_hex_segments.clear()
	var dlon := TAU / float(HEX_LON)
	var dlat := PI / float(HEX_LAT + 1)
	for row in range(HEX_LAT):
		var lat := -PI * 0.5 + dlat * float(row + 1)
		var offset := 0.5 * dlon if row % 2 == 1 else 0.0
		var lat_r := dlat * 0.55
		for col in range(HEX_LON):
			var lon := offset + dlon * float(col)
			var lon_r := dlon * 0.55
			for k in range(6):
				var a0 := TAU * float(k) / 6.0 + PI / 6.0
				var a1 := TAU * float(k + 1) / 6.0 + PI / 6.0
				_hex_segments.append(Vector2(lon + cos(a0) * lon_r, lat + sin(a0) * lat_r))
				_hex_segments.append(Vector2(lon + cos(a1) * lon_r, lat + sin(a1) * lat_r))

func show_dome(dome_color: Color) -> void:
	color = dome_color
	if not active:
		active = true
		_pop = 0.0
		_cracks.clear()
		_ripples.clear()
		_flash = 0.6
	visible = true
	set_process(true)

func hide_dome(instant: bool = false) -> void:
	active = false
	if instant:
		_alpha = 0.0
		visible = false
		_cracks.clear()
		_ripples.clear()
		set_process(false)

# Treffer: Aufblitzen, Welle ab Einschlag, neuer Riss. dir zeigt vom
# Mittelpunkt zur Schadensquelle; damage_left 0..1 = verbleibende Haltbarkeit.
func hit(dir: Vector2, damage_left: float = 1.0) -> void:
	if dir.length_squared() < 0.01:
		dir = Vector2.from_angle(randf() * TAU)
	dir = dir.normalized()
	_flash = 1.0
	_ripples.append([dir, 0.0])
	if damage_left < 0.999:
		_add_crack(dir)
	queue_redraw()

func _add_crack(dir: Vector2) -> void:
	var start := CENTER + dir * RADIUS * 0.97
	var main := PackedVector2Array([start])
	var heading := -dir
	var p := start
	var steps := 4 + randi() % 2
	for i in range(steps):
		heading = heading.rotated(randf_range(-0.55, 0.55))
		p += heading * randf_range(4.5, 7.5)
		if (p - CENTER).length() > RADIUS * 0.98:
			break
		main.append(p)
	_cracks.append(main)
	# Zwei kurze Seitenäste.
	for b in range(2):
		if main.size() < 3:
			break
		var from := main[1 + randi() % (main.size() - 2)]
		var branch := PackedVector2Array([from])
		var bh := heading.rotated(randf_range(0.7, 1.3) * (1.0 if b == 0 else -1.0))
		var bp := from
		for j in range(2):
			bp += bh * randf_range(3.5, 5.5)
			bh = bh.rotated(randf_range(-0.4, 0.4))
			if (bp - CENTER).length() > RADIUS * 0.98:
				break
			branch.append(bp)
		if branch.size() > 1:
			_cracks.append(branch)

func _process(delta: float) -> void:
	_time += delta
	_spin = fmod(_spin + SPIN_SPEED * delta, TAU)
	_pop = minf(1.0, _pop + delta / POP_TIME)
	_flash = maxf(0.0, _flash - delta * 5.0)
	_alpha = move_toward(_alpha, 1.0 if active else 0.0, FADE_SPEED * delta)
	for r in _ripples:
		r[1] = float(r[1]) + delta
	_ripples = _ripples.filter(func(r): return float(r[1]) < 0.32)
	if not active and _alpha <= 0.0:
		visible = false
		_cracks.clear()
		_ripples.clear()
		set_process(false)
	queue_redraw()

func _circle_points(radius: float, wobble: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(SEGMENTS + 1):
		var angle := TAU * float(i) / float(SEGMENTS)
		var w := (sin(angle * 4.0 + _time * 5.0) * 0.5 + sin(angle * 7.0 - _time * 4.0) * 0.3) * wobble
		points.append(CENTER + Vector2(cos(angle), sin(angle)) * (radius + w))
	return points

func _draw() -> void:
	if _alpha <= 0.0:
		return
	var s := _alpha
	# Aufploppen: kurz größer, dann auf Normalgröße.
	var pop_t := _pop
	var scale_f := lerpf(0.55, 1.0, ease(pop_t, 0.35)) + sin(pop_t * PI) * 0.12
	var radius := RADIUS * scale_f
	var base := color
	base.a = 1.0
	var bright := base.lightened(0.45 + 0.4 * _flash)

	# Weiche Füllung: von innen nach außen dichter (Kugelrand wirkt dicker).
	var rings := 6
	for i in range(rings):
		var t := 1.0 - float(i) / float(rings)
		var fill := base
		fill.a = (0.035 + 0.05 * t * t) * s + 0.06 * _flash * s
		draw_circle(CENTER, radius * (0.45 + 0.55 * t), fill, true, -1.0, true)

	# Wabenmuster auf der Kugel, vorne kräftig, hinten nur angedeutet.
	_draw_hex(radius, base, s)

	# Risse.
	if not _cracks.is_empty():
		var crack_glow := base.lightened(0.6)
		crack_glow.a = 0.35 * s
		var crack := Color(1.0, 1.0, 1.0, 0.95 * s)
		var k := radius / RADIUS
		for c in _cracks:
			var pts := PackedVector2Array()
			for p in c:
				pts.append(CENTER + (p - CENTER) * k)
			draw_polyline(pts, crack_glow, 3.0, true)
			draw_polyline(pts, crack, 1.1, true)

	# Leuchtender Rand.
	var points := _circle_points(radius, 0.6 + 1.4 * _flash)
	var rim_glow := base
	rim_glow.a = (0.22 + 0.25 * _flash) * s
	draw_polyline(points, rim_glow, 6.0, true)
	var rim := bright
	rim.a = (0.8 + 0.2 * _flash) * s
	draw_polyline(points, rim, 1.8, true)

	# Wellen vom Einschlagpunkt entlang des Rands.
	for r in _ripples:
		var dir: Vector2 = r[0]
		var age := float(r[1]) / 0.32
		var spread := 0.25 + age * 1.9
		var wave := Color(1.0, 1.0, 1.0, (1.0 - age) * 0.9 * s)
		var a := dir.angle()
		draw_arc(CENTER, radius + 1.0, a - spread, a + spread, 18, wave, 2.6 * (1.0 - age) + 0.6, true)
		var hit_glow := bright
		hit_glow.a = (1.0 - age) * 0.5 * s
		draw_circle(CENTER + dir * (radius - 2.0), 7.0 * (1.0 - age) + 1.0, hit_glow, true, -1.0, true)

	# Glanzlichter wie bei der Schildblase.
	var shine := Color(1.0, 1.0, 1.0, 0.7 * s)
	draw_arc(CENTER, radius - 4.5, deg_to_rad(198.0), deg_to_rad(252.0), 14, shine, 2.0, true)
	draw_circle(CENTER + Vector2(-0.42, -0.62) * radius, 1.9 * scale_f, shine, true, -1.0, true)
	var sweep := _time * 2.2
	var sweep_color := Color(1.0, 1.0, 1.0, 0.3 * s)
	draw_arc(CENTER, radius - 1.2, sweep, sweep + 0.7, 10, sweep_color, 2.2, true)

func _draw_hex(radius: float, base: Color, s: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var line := base.lightened(0.35)
	for i in range(0, _hex_segments.size(), 2):
		var a := _project(_hex_segments[i], radius)
		var b := _project(_hex_segments[i + 1], radius)
		var depth := minf(a.z, b.z)
		if depth < -0.15:
			continue
		var c := line
		# Vorderseite kräftig, Ränder und Rückseite schwach.
		c.a = (0.06 + 0.32 * clampf(depth, 0.0, 1.0)) * s
		pts.append(Vector2(a.x, a.y))
		pts.append(Vector2(b.x, b.y))
		cols.append(c)
	if not pts.is_empty():
		draw_multiline_colors(pts, cols, 1.0)

# Kugelkoordinate -> Bildpunkt + Tiefe (1 = zur Kamera, -1 = hinten).
func _project(lonlat: Vector2, radius: float) -> Vector3:
	var lon := lonlat.x + _spin
	var lat := lonlat.y
	var r := radius * 0.93
	var x := r * cos(lat) * sin(lon)
	var y := r * sin(lat)
	var z := cos(lat) * cos(lon)
	return Vector3(CENTER.x + x, CENTER.y + y, z)
