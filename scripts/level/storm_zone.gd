class_name StormZone
extends Node2D

# Darstellung des Modifiers "Zone": Sturm außerhalb des Kreises, leuchtender
# Rand und gestrichelte Vorschau der nächsten Zone. Rein visuell; Zustand
# und Schaden kommen vom LevelModifierManager (Host) bzw. per Snapshot.

const STORM_COLOR := Color(0.42, 0.22, 0.95, 0.24)
const EDGE_COLOR := Color(0.8, 0.65, 1.0, 0.95)
const NEXT_COLOR := Color(1.0, 1.0, 1.0, 0.75)
const EDGE_GLOW: float = 34.0

var center: Vector2 = Vector2.ZERO
var radius: float = -1.0
var next_center: Vector2 = Vector2.ZERO
var next_radius: float = -1.0

# Netzwerk-Clients: weich auf den zuletzt gemeldeten Host-Zustand gleiten.
var is_replica: bool = false
var _has_net: bool = false
var _net_center: Vector2 = Vector2.ZERO
var _net_radius: float = -1.0
var _time: float = 0.0

func _ready() -> void:
	z_index = 55

func set_state(c: Vector2, r: float, nc: Vector2, nr: float) -> void:
	center = c
	radius = r
	next_center = nc
	next_radius = nr

func apply_network_state(c: Vector2, r: float, nc: Vector2, nr: float) -> void:
	if not _has_net:
		center = c
		radius = r
		_has_net = true
	_net_center = c
	_net_radius = r
	next_center = nc
	next_radius = nr

func _process(delta: float) -> void:
	_time += delta
	if is_replica and _has_net:
		var k := minf(1.0, delta * 10.0)
		center = center.lerp(_net_center, k)
		radius = lerpf(radius, _net_radius, k)
	queue_redraw()

func _draw() -> void:
	if radius <= 0.0:
		return
	var map_size := Vector2(LevelGenerator.map_w, LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	var outer := 0.0
	for corner in [Vector2.ZERO, Vector2(map_size.x, 0.0), Vector2(0.0, map_size.y), map_size]:
		outer = maxf(outer, center.distance_to(corner))
	outer += 80.0
	var segs := clampi(int(radius / 5.0), 48, 180)

	# Sturmfläche als Ring von Vierecken: Godot kann keine Polygone mit Loch.
	if outer > radius:
		var glow_outer := minf(radius + EDGE_GLOW, outer)
		var glow_in := Color(STORM_COLOR, 0.42)
		var glow_out := Color(STORM_COLOR, 0.0)
		for i in segs:
			var d0 := Vector2.from_angle(TAU * float(i) / float(segs))
			var d1 := Vector2.from_angle(TAU * float(i + 1) / float(segs))
			draw_colored_polygon(PackedVector2Array([
				center + d0 * radius, center + d0 * outer,
				center + d1 * outer, center + d1 * radius,
			]), STORM_COLOR)
			draw_polygon(PackedVector2Array([
				center + d0 * radius, center + d0 * glow_outer,
				center + d1 * glow_outer, center + d1 * radius,
			]), PackedColorArray([glow_in, glow_out, glow_out, glow_in]))

	# Rand mit wandernden Sturmschlieren.
	var pulse := 0.8 + 0.2 * sin(_time * 4.0)
	draw_arc(center, radius, 0.0, TAU, segs + 1, Color(EDGE_COLOR, EDGE_COLOR.a * pulse), 3.0, true)
	var streak_r := radius + 12.0
	var streaks := clampi(int(TAU * streak_r / 90.0), 12, 90)
	var streak_len := 26.0 / streak_r
	for i in streaks:
		var a := TAU * float(i) / float(streaks) + _time * 0.35
		draw_arc(center, streak_r, a, a + streak_len, 4, Color(0.85, 0.75, 1.0, 0.45), 2.0, true)

	# Vorschau der nächsten Zone (gestrichelt, dreht sich langsam).
	if next_radius > 0.0:
		var dashes := clampi(int(TAU * next_radius / 40.0), 16, 120)
		var step := TAU / float(dashes)
		for i in dashes:
			var a := step * float(i) + _time * 0.15
			draw_arc(next_center, next_radius, a, a + step * 0.55, 5, NEXT_COLOR, 2.5, true)
