class_name PowerupAura
extends Node2D

## Gut sichtbare Auren für laufende Powerups, prozedural gezeichnet:
## - Schutz: Schildblase um den ganzen Charakter
## - Unsterblichkeit: goldener Heiligenschein über dem Kopf
## - Rache: drehender Stachelkranz
## - alle anderen: lodernde Energieaura (Super-Saiyajin-Stil) in der Powerup-Farbe
##
## Der Player hängt zwei Instanzen an: eine hinter den Körper (front = false,
## Energieaura) und eine davor (front = true, Blase/Heiligenschein/Stacheln).
## Die Restzeiten kommen online per Snapshot, daher läuft das auch auf Replikas.

const KIND_BUBBLE: String = "invulnerability"
const KIND_HALO: String = "undying"
const KIND_SPIKES: String = "revenge"

const FADE_SPEED: float = 6.0 # Ein-/Ausblenden pro Sekunde
const ENDING_TIME: float = 1.0 # letzte Sekunde: Flackern wie der Körper-Schimmer
const CENTER: Vector2 = Vector2(0.0, -1.0)

const BUBBLE_RADIUS: float = 23.0
const HALO_CENTER: Vector2 = Vector2(0.0, -23.5)
const HALO_RADIUS: Vector2 = Vector2(9.5, 2.8)
const HALO_COLOR: Color = Color(1.0, 0.86, 0.32, 1.0)
const SPIKE_COUNT: int = 8
const SPIKE_INNER: float = 17.5
const SPIKE_OUTER: float = 26.0
const SPIKE_SPIN: float = 2.4 # rad/s
const AURA_RADIUS: Vector2 = Vector2(15.5, 18.0)
const AURA_POINTS: int = 36
const AURA_SPARKS: int = 7

var front: bool = false
var _time: float = 0.0
# kind -> {"color": Color, "remaining": float, "alpha": float, "active": bool}
var _effects: Dictionary = {}
var _order: Array[String] = []

func _ready() -> void:
	set_process(false)

# effects: Array von [kind, Farbe, Restzeit] in Anzeigereihenfolge.
func set_effects(effects: Array) -> void:
	for kind in _effects.keys():
		_effects[kind]["active"] = false
	_order.clear()
	for entry in effects:
		var kind: String = entry[0]
		_order.append(kind)
		if not _effects.has(kind):
			_effects[kind] = {"alpha": 0.0}
		var e: Dictionary = _effects[kind]
		e["color"] = entry[1]
		e["remaining"] = entry[2]
		e["active"] = true
	if not _effects.is_empty():
		set_process(true)

func _process(delta: float) -> void:
	_time += delta
	for kind in _effects.keys():
		var e: Dictionary = _effects[kind]
		var target := 1.0 if bool(e["active"]) else 0.0
		e["alpha"] = move_toward(float(e["alpha"]), target, FADE_SPEED * delta)
		if not bool(e["active"]) and float(e["alpha"]) <= 0.0:
			_effects.erase(kind)
	if _effects.is_empty():
		_time = 0.0
		set_process(false)
	queue_redraw()

func _strength(e: Dictionary) -> float:
	var a := float(e["alpha"])
	if bool(e["active"]) and float(e["remaining"]) < ENDING_TIME:
		a *= 1.0 if int(_time * 12.0) % 2 == 0 else 0.25
	return a

func _draw() -> void:
	if _effects.is_empty():
		return
	if front:
		if _effects.has(KIND_SPIKES):
			_draw_spikes(_effects[KIND_SPIKES])
		if _effects.has(KIND_BUBBLE):
			_draw_bubble(_effects[KIND_BUBBLE])
		if _effects.has(KIND_HALO):
			_draw_halo(_effects[KIND_HALO])
		return
	# Hinten: Energieauren, die erste aktive am größten, weitere verschachtelt.
	var energy: Array[String] = []
	for kind in _order:
		if _is_energy_kind(kind):
			energy.append(kind)
	for kind in _effects.keys():
		if _is_energy_kind(kind) and not energy.has(kind):
			energy.append(kind) # blendet gerade aus
	for i in range(energy.size()):
		_draw_energy_aura(_effects[energy[i]], 1.0 - 0.13 * float(i), float(i) * 1.7)

func _is_energy_kind(kind: String) -> bool:
	return kind != KIND_BUBBLE and kind != KIND_HALO and kind != KIND_SPIKES

# --- Energieaura ------------------------------------------------------------

func _aura_polygon(size: float, phase: float, flicker: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(AURA_POINTS):
		var angle := TAU * float(i) / float(AURA_POINTS)
		var dir := Vector2(cos(angle), sin(angle))
		var up := maxf(0.0, -dir.y) # 1 = oben, 0 = Seite/unten
		# Spitz nach oben gezogen, unten eng am Körper.
		var stretch := 1.0 + 0.85 * up * up * up
		# Züngelnde Flammen: abwechselnd Spitze/Kerbe, nach oben stärker.
		var tongue := 1.0 + (0.16 if i % 2 == 0 else -0.06) * (0.4 + up)
		var lick := sin(_time * 11.0 + float(i) * 1.9 + phase) * 0.07 * flicker * (0.3 + up)
		var r := size * (tongue + lick)
		points.append(CENTER + Vector2(dir.x * AURA_RADIUS.x * r, dir.y * AURA_RADIUS.y * r * stretch))
	return points

func _draw_energy_aura(e: Dictionary, size: float, phase: float) -> void:
	var s := _strength(e)
	if s <= 0.0:
		return
	var color: Color = e["color"]
	var breathe := 1.0 + 0.04 * sin(_time * 9.0 + phase)
	var outer := color
	outer.a = 0.30 * s
	draw_colored_polygon(_aura_polygon(1.12 * size * breathe, phase, 1.0), outer)
	var mid := color.lightened(0.25)
	mid.a = 0.38 * s
	draw_colored_polygon(_aura_polygon(0.92 * size * breathe, phase + 2.3, 0.8), mid)
	var core := color.lightened(0.7)
	core.a = 0.22 * s
	draw_colored_polygon(_aura_polygon(0.68 * size, phase + 4.1, 0.5), core)
	# Aufsteigende Funken innerhalb der Aura.
	for j in range(AURA_SPARKS):
		var t := fmod(_time * 1.5 + float(j) * 0.37 + phase * 0.11, 1.0)
		var x := sin(float(j) * 12.9 + phase) * 11.0 * size
		var y := 13.0 - t * 44.0 * size
		var spark := color.lightened(0.55)
		spark.a = (1.0 - t) * 0.9 * s
		draw_line(Vector2(x, y), Vector2(x, y + 4.5), spark, 1.4)

# --- Schildblase ------------------------------------------------------------

func _draw_bubble(e: Dictionary) -> void:
	var s := _strength(e)
	if s <= 0.0:
		return
	var color: Color = e["color"]
	var points := PackedVector2Array()
	var segments := 40
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		var wobble := sin(angle * 3.0 + _time * 4.0) * 0.7 + sin(angle * 5.0 - _time * 3.0) * 0.4
		points.append(CENTER + Vector2(cos(angle), sin(angle)) * (BUBBLE_RADIUS + wobble))
	var fill := color
	fill.a = 0.14 * s
	draw_colored_polygon(points.slice(0, segments), fill)
	var rim_glow := color
	rim_glow.a = 0.28 * s
	draw_polyline(points, rim_glow, 4.0)
	var rim := color.lightened(0.35)
	rim.a = 0.85 * s
	draw_polyline(points, rim, 1.4)
	# Glanzlichter: fester Bogen oben links und ein umlaufender Schimmer.
	var shine := Color(1.0, 1.0, 1.0, 0.75 * s)
	draw_arc(CENTER, BUBBLE_RADIUS - 3.5, deg_to_rad(200.0), deg_to_rad(250.0), 10, shine, 1.6)
	draw_circle(CENTER + Vector2(-9.5, -14.0), 1.5, shine)
	var sweep := _time * 1.8
	var sweep_color := Color(1.0, 1.0, 1.0, 0.35 * s)
	draw_arc(CENTER, BUBBLE_RADIUS - 1.0, sweep, sweep + 0.6, 8, sweep_color, 2.0)

# --- Heiligenschein ---------------------------------------------------------

func _draw_halo(e: Dictionary) -> void:
	var s := _strength(e)
	if s <= 0.0:
		return
	var center := HALO_CENTER + Vector2(0.0, sin(_time * 3.2) * 1.2)
	var points := PackedVector2Array()
	var segments := 28
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * HALO_RADIUS.x, sin(angle) * HALO_RADIUS.y))
	var glow := HALO_COLOR
	glow.a = 0.18 * s
	draw_colored_polygon(points.slice(0, segments), glow)
	var outer := HALO_COLOR
	outer.a = 0.35 * s
	draw_polyline(points, outer, 4.2)
	var ring := HALO_COLOR.lightened(0.45)
	ring.a = s
	draw_polyline(points, ring, 1.6)
	# Ein Funkeln wandert über den Ring.
	var spark_angle := _time * 2.6
	var spark_pos := center + Vector2(cos(spark_angle) * HALO_RADIUS.x, sin(spark_angle) * HALO_RADIUS.y)
	var sparkle := Color(1.0, 1.0, 0.9, s * (0.6 + 0.4 * sin(_time * 14.0)))
	draw_line(spark_pos + Vector2(-2.2, 0.0), spark_pos + Vector2(2.2, 0.0), sparkle, 1.0)
	draw_line(spark_pos + Vector2(0.0, -2.2), spark_pos + Vector2(0.0, 2.2), sparkle, 1.0)

# --- Stachelkranz -----------------------------------------------------------

func _draw_spikes(e: Dictionary) -> void:
	var s := _strength(e)
	if s <= 0.0:
		return
	var color: Color = e["color"]
	var ring := color
	ring.a = 0.35 * s
	draw_arc(CENTER, SPIKE_INNER, 0.0, TAU, 32, ring, 1.6)
	var fill := color.lightened(0.15)
	fill.a = s
	var edge := color.darkened(0.55)
	edge.a = s
	var shine := Color(1.0, 0.85, 0.85, 0.7 * s)
	var spin := _time * SPIKE_SPIN
	for i in range(SPIKE_COUNT):
		var angle := spin + TAU * float(i) / float(SPIKE_COUNT)
		var dir := Vector2(cos(angle), sin(angle))
		var side := Vector2(-dir.y, dir.x)
		var base := CENTER + dir * SPIKE_INNER
		var tip := CENTER + dir * SPIKE_OUTER
		var tri := PackedVector2Array([base + side * 3.6, tip, base - side * 3.6])
		draw_colored_polygon(tri, fill)
		tri.append(tri[0])
		draw_polyline(tri, edge, 1.0)
		draw_line(base + side * 1.2, tip - dir * 1.5, shine, 0.8)
