class_name ThemeBackdrop
extends Node2D

## Prozeduraler, tileset-unabhängiger Hintergrund. Er liegt hinter der Arena
## und bleibt bewusst ruhig, damit Projektile und Plattformen lesbar bleiben.
## Die Level-Geometrie kennt nur diese Klasse, nie die einzelnen Layouts.

const PADDING: Vector2 = Vector2(360.0, 240.0)

var theme_id: String = "storybook"
var variant: String = "forest"
var accent: Color = Color.WHITE

var _canvas_size: Vector2 = Vector2.ZERO
var _map_size: Vector2 = Vector2.ZERO
var _map_rect: Rect2 = Rect2()
var _time: float = 0.0
var _motes: Array[Dictionary] = []
# Platine: vorberechnete Leiterbahnen (Punktlisten) und Chip-Rechtecke.
var _traces: Array[PackedVector2Array] = []
var _chips: Array[Rect2] = []

func configure(p_theme_id: String, p_variant: String, p_accent: Color, map_size: Vector2, seed_value: int) -> void:
	theme_id = p_theme_id
	variant = p_variant
	accent = p_accent
	_map_size = map_size
	_map_rect = Rect2(PADDING, map_size)
	_canvas_size = map_size + PADDING * 2.0
	position = -PADDING
	z_index = -100
	z_as_relative = false
	_build_gradient()
	_build_motes(seed_value)
	if theme_id == "platine":
		_build_circuit(seed_value)
	set_process(true)

func _build_gradient() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	match theme_id:
		"neon":
			gradient.colors = PackedColorArray([
				Color(0.015, 0.025, 0.075, 1.0),
				Color(0.035, 0.065, 0.13, 1.0),
				Color(0.045, 0.055, 0.10, 1.0),
				Color(0.012, 0.018, 0.035, 1.0),
			])
		"wool":
			gradient.colors = PackedColorArray([
				Color(0.76, 0.90, 0.95, 1.0),
				Color(0.91, 0.80, 0.89, 1.0),
				Color(0.98, 0.83, 0.87, 1.0),
				Color(0.82, 0.66, 0.77, 1.0),
			])
		"platine":
			gradient.colors = PackedColorArray([
				Color(0.010, 0.035, 0.045, 1.0),
				Color(0.020, 0.075, 0.085, 1.0),
				Color(0.018, 0.060, 0.070, 1.0),
				Color(0.008, 0.025, 0.032, 1.0),
			])
		"frost":
			gradient.colors = PackedColorArray([
				Color(0.018, 0.075, 0.13, 1.0),
				Color(0.035, 0.16, 0.24, 1.0),
				Color(0.09, 0.28, 0.36, 1.0),
				Color(0.42, 0.70, 0.80, 1.0),
			])
		_:
			if variant == "desert":
				gradient.colors = PackedColorArray([
					Color(0.16, 0.10, 0.18, 1.0),
					Color(0.34, 0.20, 0.25, 1.0),
					Color(0.64, 0.39, 0.30, 1.0),
					Color(0.88, 0.65, 0.40, 1.0),
				])
			elif variant == "dusk":
				gradient.colors = PackedColorArray([
					Color(0.11, 0.10, 0.20, 1.0),
					Color(0.27, 0.22, 0.34, 1.0),
					Color(0.55, 0.38, 0.37, 1.0),
					Color(0.80, 0.63, 0.40, 1.0),
				])
			elif variant == "meadow":
				gradient.colors = PackedColorArray([
					Color(0.18, 0.37, 0.47, 1.0),
					Color(0.35, 0.58, 0.55, 1.0),
					Color(0.64, 0.77, 0.53, 1.0),
					Color(0.83, 0.84, 0.61, 1.0),
				])
			else:
				gradient.colors = PackedColorArray([
					Color(0.035, 0.12, 0.16, 1.0),
					Color(0.07, 0.22, 0.23, 1.0),
					Color(0.19, 0.38, 0.31, 1.0),
					Color(0.55, 0.64, 0.45, 1.0),
				])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 512
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var sprite := Sprite2D.new()
	sprite.name = "SkyGradient"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(_canvas_size.x / 32.0, _canvas_size.y / 512.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Der Himmelsverlauf ist ein Kind, würde aber standardmäßig über den
	# gezeichneten Hügeln/Wolken landen. show_behind_parent hält ihn hinten.
	sprite.show_behind_parent = true
	add_child(sprite)

func _build_motes(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ hash(theme_id)
	_motes.clear()
	var count := 26
	for i in range(count):
		_motes.append({
			"x": _map_rect.position.x + rng.randf_range(0.04, 0.96) * _map_size.x,
			"y": _map_rect.position.y + rng.randf_range(0.03, 0.92) * _map_size.y,
			"radius": rng.randf_range(1.2, 3.6),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.25, 0.8),
			"drift": rng.randf_range(-8.0, 8.0),
		})

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	match theme_id:
		"neon":
			_draw_neon()
		"wool":
			_draw_wool()
		"frost":
			_draw_frost()
		"platine":
			_draw_platine()
		_:
			_draw_storybook()

	_draw_motes()
	_draw_vignette()

# --- Storybook ---------------------------------------------------------------

func _draw_storybook() -> void:
	var horizon := _map_rect.position.y + _map_size.y * 0.70
	var warm := Color(1.0, 0.82, 0.52, 0.10)
	if variant == "desert":
		warm = Color(1.0, 0.60, 0.28, 0.12)
	elif variant == "dusk":
		warm = Color(1.0, 0.63, 0.42, 0.12)
	elif variant == "meadow":
		warm = Color(0.92, 1.0, 0.66, 0.11)

	# Warme Sonne / Mond als ruhiger Fixpunkt.
	var sun := Vector2(_map_rect.position.x + _map_size.x * 0.77, _map_rect.position.y + _map_size.y * 0.18)
	for i in range(5):
		draw_circle(sun, 48.0 + float(i) * 24.0, Color(warm.r, warm.g, warm.b, 0.035 - float(i) * 0.005))
	draw_circle(sun, 42.0, Color(warm.r, warm.g, warm.b, 0.22))

	if variant == "desert":
		# Dünen und Ruinenbögen.
		var dune_colors := [
			Color(0.33, 0.20, 0.20, 0.48),
			Color(0.47, 0.29, 0.23, 0.42),
			Color(0.63, 0.42, 0.28, 0.34),
		]
		for layer in range(3):
			var points := PackedVector2Array()
			points.append(Vector2(0.0, _canvas_size.y))
			points.append(Vector2(0.0, horizon + float(layer) * 48.0))
			for step in range(9):
				var t := float(step) / 8.0
				var x := _canvas_size.x * t
				var y := horizon + float(layer) * 44.0 + sin(t * 7.0 + float(layer) * 1.7) * 42.0
				points.append(Vector2(x, y))
			points.append(Vector2(_canvas_size.x, _canvas_size.y))
			draw_colored_polygon(points, dune_colors[layer])
		var base := Vector2(_map_rect.position.x + _map_size.x * 0.16, horizon + 30.0)
		for arch in range(3):
			var x := base.x + float(arch) * 300.0
			draw_rect(Rect2(x, horizon - 110.0, 26.0, 220.0), Color(0.22, 0.14, 0.16, 0.38))
			draw_rect(Rect2(x + 74.0, horizon - 145.0, 22.0, 255.0), Color(0.22, 0.14, 0.16, 0.32))
			draw_arc(Vector2(x + 50.0, horizon - 120.0), 44.0, PI, TAU, 28, Color(0.22, 0.14, 0.16, 0.32), 16.0, true)
	else:
		# Gestaffelte Hügel.
		var hills := [
			Color(0.035, 0.12, 0.10, 0.56),
			Color(0.05, 0.18, 0.13, 0.48),
			Color(0.07, 0.24, 0.16, 0.38),
		]
		for layer in range(3):
			var points := PackedVector2Array()
			points.append(Vector2(0.0, _canvas_size.y))
			points.append(Vector2(0.0, horizon + float(layer) * 38.0))
			for step in range(13):
				var t := float(step) / 12.0
				var x := _canvas_size.x * t
				var y := horizon + float(layer) * 34.0 - sin(t * TAU * 1.4 + float(layer) * 1.6) * (28.0 + float(layer) * 17.0)
				points.append(Vector2(x, y))
			points.append(Vector2(_canvas_size.x, _canvas_size.y))
			draw_colored_polygon(points, hills[layer])

		# Baumsilhouetten links und rechts.
		for side in [-1.0, 1.0]:
			var trunk_x: float = _map_rect.position.x + (70.0 if side < 0.0 else _map_size.x - 70.0)
			var trunk_top := _map_rect.position.y + 105.0 + (0.0 if side < 0.0 else 55.0)
			draw_rect(Rect2(trunk_x - 16.0, trunk_top, 32.0, _map_size.y * 0.66), Color(0.035, 0.08, 0.065, 0.56))
			draw_rect(Rect2(trunk_x - 25.0, trunk_top + 130.0, 9.0, 190.0), Color(0.035, 0.08, 0.065, 0.34))
			for i in range(4):
				var cy := trunk_top - 15.0 + float(i) * 72.0
				var r := 64.0 - float(i) * 8.0
				draw_circle(Vector2(trunk_x, cy), r, Color(0.04, 0.12, 0.085, 0.39))
				draw_circle(Vector2(trunk_x + side * 38.0, cy + 20.0), r * 0.72, Color(0.055, 0.16, 0.10, 0.30))

		# Schwebende Blätter / Glühwürmchen bleiben in der Motes-Schicht.

func _draw_neon() -> void:
	# Perspektivisches Bodenraster.
	var grid_color := Color(0.20, 0.78, 0.92, 0.065)
	var magenta := Color(0.95, 0.23, 0.73, 0.055)
	var center := Vector2(_map_rect.position.x + _map_size.x * 0.5, _map_rect.position.y + _map_size.y * 0.58)
	for i in range(-10, 11):
		var x := center.x + float(i) * 95.0
		draw_line(Vector2(x, _canvas_size.y), center + Vector2(0.0, 8.0), grid_color, 1.4, true)
	for i in range(8):
		var t := float(i) / 7.0
		var y := center.y + pow(t, 1.8) * (_canvas_size.y - center.y)
		draw_line(Vector2(0.0, y), Vector2(_canvas_size.x, y), grid_color, 1.2, true)

	# Technische Vertikalrohre an den Rändern.
	for x in [_map_rect.position.x - 70.0, _map_rect.end.x + 70.0]:
		draw_rect(Rect2(x - 16.0, 0.0, 32.0, _canvas_size.y), Color(0.03, 0.06, 0.10, 0.64))
		draw_line(Vector2(x, 0.0), Vector2(x, _canvas_size.y), Color(0.20, 0.72, 0.86, 0.20), 3.0, true)
		for i in range(8):
			var y := 70.0 + float(i) * 130.0
			draw_circle(Vector2(x, y), 5.0, Color(0.95, 0.30, 0.72, 0.22))

	# Große Neonringe als Landmarken.
	var ring_a := Vector2(_map_rect.position.x + _map_size.x * 0.16, _map_rect.position.y + 130.0)
	var ring_b := Vector2(_map_rect.position.x + _map_size.x * 0.84, _map_rect.position.y + 210.0)
	for ring in [ring_a, ring_b]:
		var color := Color(0.26, 0.90, 1.0, 0.13) if ring == ring_a else Color(1.0, 0.32, 0.76, 0.12)
		draw_circle(ring, 84.0, Color(color.r, color.g, color.b, 0.025))
		draw_arc(ring, 76.0, 0.0, TAU, 64, color, 3.0, true)
		draw_arc(ring, 58.0, 0.2, TAU * 0.86, 54, Color(color.r, color.g, color.b, color.a * 0.7), 1.4, true)

	# Ein paar Schaltkreislinien.
	for i in range(7):
		var y := _map_rect.position.y + 80.0 + float(i) * 105.0
		var x1 := _map_rect.position.x + 90.0 + float(i % 3) * 170.0
		var x2 := x1 + 110.0
		draw_line(Vector2(x1, y), Vector2(x2, y), magenta, 1.2, true)
		draw_line(Vector2(x2, y), Vector2(x2 + 24.0, y + 24.0), magenta, 1.2, true)
		draw_circle(Vector2(x2 + 24.0, y + 24.0), 2.4, Color(0.95, 0.30, 0.72, 0.18))

# --- Platine -----------------------------------------------------------------

## Leiterbahnen wie im Hauptmenü: rechtwinklige Züge mit 45-Grad-Knicken,
## Lötpunkten an den Enden und ein paar Chips. Alles gedämpft, damit die
## Arena davor gut lesbar bleibt.
func _build_circuit(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x51A7
	_traces.clear()
	_chips.clear()
	var step := 36.0
	var count := int(_canvas_size.x * _canvas_size.y / 26000.0)
	for i in range(count):
		var p := Vector2(
			snappedf(rng.randf_range(0.0, _canvas_size.x), step),
			snappedf(rng.randf_range(0.0, _canvas_size.y), step)
		)
		var pts := PackedVector2Array([p])
		var dir := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN][rng.randi_range(0, 3)] as Vector2
		for seg in range(rng.randi_range(2, 4)):
			p += dir * step * float(rng.randi_range(2, 6))
			pts.append(p)
			# Abwechselnd 45-Grad-Knick und rechter Winkel.
			if rng.randf() < 0.5:
				var diag := (dir + Vector2(dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0))
				p += diag * step
				pts.append(p)
			dir = Vector2(dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
		_traces.append(pts)
	for i in range(int(count / 8)):
		var size := Vector2(rng.randf_range(70.0, 140.0), rng.randf_range(34.0, 54.0))
		var pos := Vector2(rng.randf_range(0.0, _canvas_size.x - size.x), rng.randf_range(0.0, _canvas_size.y - size.y))
		_chips.append(Rect2(pos, size))

func _draw_platine() -> void:
	var trace_color := Color(0.25, 0.91, 0.84, 0.13)
	var pad_color := Color(0.25, 0.91, 0.84, 0.22)
	var pink := Color(0.96, 0.36, 0.77, 0.16)
	for i in range(_traces.size()):
		var pts := _traces[i]
		var color := pink if i % 9 == 0 else trace_color
		draw_polyline(pts, color, 2.0, true)
		for end in [pts[0], pts[pts.size() - 1]]:
			draw_arc(end, 5.0, 0.0, TAU, 16, Color(color.r, color.g, color.b, color.a * 1.6), 1.6, true)
	for chip in _chips:
		draw_rect(chip, Color(0.0, 0.0, 0.0, 0.32), true)
		draw_rect(chip, Color(0.25, 0.91, 0.84, 0.08), false, 1.2)
		var pins := int(chip.size.x / 14.0)
		for k in range(pins):
			var x := chip.position.x + 7.0 + float(k) * 14.0
			draw_rect(Rect2(x - 2.0, chip.position.y - 6.0, 4.0, 5.0), Color(0.7, 0.75, 0.78, 0.12), true)
			draw_rect(Rect2(x - 2.0, chip.end.y + 1.0, 4.0, 5.0), Color(0.7, 0.75, 0.78, 0.12), true)
	# Langsame Signalimpulse auf einigen Bahnen.
	for i in range(0, _traces.size(), 4):
		var pts := _traces[i]
		var total := 0.0
		for k in range(pts.size() - 1):
			total += pts[k].distance_to(pts[k + 1])
		if total <= 0.0:
			continue
		var travel := fposmod(_time * 60.0 + float(i) * 37.0, total)
		for k in range(pts.size() - 1):
			var seg := pts[k].distance_to(pts[k + 1])
			if travel <= seg:
				var pos := pts[k].lerp(pts[k + 1], travel / maxf(seg, 0.001))
				var c := Color(0.96, 0.36, 0.77, 0.55) if i % 8 == 0 else Color(0.55, 1.0, 0.94, 0.5)
				draw_circle(pos, 3.0, c)
				draw_circle(pos, 7.0, Color(c.r, c.g, c.b, 0.12))
				break
			travel -= seg

func _draw_wool() -> void:
	var cloud := Color(1.0, 0.96, 0.98, 0.34)
	var cloud_shadow := Color(0.67, 0.53, 0.67, 0.12)
	var clusters := [
		Vector2(_map_rect.position.x + 130.0, _map_rect.position.y + 90.0),
		Vector2(_map_rect.position.x + 620.0, _map_rect.position.y + 65.0),
		Vector2(_map_rect.position.x + 1120.0, _map_rect.position.y + 120.0),
		Vector2(_map_rect.position.x + 1450.0, _map_rect.position.y + 55.0),
	]
	for cluster in clusters:
		for i in range(7):
			var angle := float(i) * TAU / 7.0
			var offset := Vector2(cos(angle) * (34.0 + float(i % 3) * 11.0), sin(angle) * 22.0)
			draw_circle(cluster + offset, 33.0 + float(i % 2) * 9.0, cloud)
		draw_circle(cluster + Vector2(0.0, 25.0), 44.0, cloud_shadow)

	# Weiche Hügel aus Wolle.
	var hill := Color(0.58, 0.38, 0.55, 0.16)
	var horizon := _map_rect.position.y + _map_size.y * 0.68
	var points := PackedVector2Array([Vector2(0.0, _canvas_size.y), Vector2(0.0, horizon)])
	for step in range(15):
		var t := float(step) / 14.0
		points.append(Vector2(_canvas_size.x * t, horizon - sin(t * TAU * 1.7) * 34.0))
	points.append(Vector2(_canvas_size.x, _canvas_size.y))
	draw_colored_polygon(points, hill)

	# Garnschwünge.
	var yarn := Color(1.0, 0.72, 0.82, 0.11)
	for i in range(7):
		var center := Vector2(
			_map_rect.position.x + _map_size.x * (0.1 + 0.13 * float(i)),
			_map_rect.position.y + _map_size.y * (0.30 + 0.06 * float(i % 2))
		)
		draw_arc(center, 52.0 + float(i) * 7.0, -0.5, 2.2, 30, yarn, 2.0, true)
		draw_arc(center, 33.0 + float(i) * 4.0, 2.4, 5.1, 24, yarn, 1.4, true)

func _draw_frost() -> void:
	var top := _map_rect.position.y
	# Polarlichtbänder im sichtbaren Kartenbereich.
	var aurora_a := Color(0.28, 0.95, 0.80, 0.10)
	var aurora_b := Color(0.36, 0.66, 1.0, 0.09)
	for band in range(3):
		var points := PackedVector2Array()
		for step in range(18):
			var t := float(step) / 17.0
			var x := _canvas_size.x * t
			var y := top + 32.0 + float(band) * 40.0 + sin(t * 7.0 + float(band)) * 30.0
			points.append(Vector2(x, y))
		draw_polyline(points, aurora_a if band % 2 == 0 else aurora_b, 18.0 - float(band) * 3.0, true)

	# Höhlenbögen an den Seiten und oben (am oberen Kartenrand verankert).
	var cave := Color(0.015, 0.05, 0.08, 0.55)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, top - 70.0), Vector2(_canvas_size.x, top - 70.0),
		Vector2(_canvas_size.x, top + 20.0), Vector2(0.0, top + 40.0),
	]), cave)
	for side in [0.0, 1.0]:
		var x := 0.0 if side < 0.5 else _canvas_size.x
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, top - 70.0),
			Vector2(x + (150.0 if side < 0.5 else -150.0), top - 70.0),
			Vector2(x + (120.0 if side < 0.5 else -90.0), _canvas_size.y),
			Vector2(x, _canvas_size.y),
		]), Color(0.01, 0.035, 0.06, 0.52))

	# Eiszapfen am oberen Kartenrand.
	for i in range(15):
		var x := 20.0 + float(i) * (_canvas_size.x - 40.0) / 14.0
		var length := 28.0 + float((i * 37) % 85)
		var color := Color(0.58, 0.88, 0.95, 0.11)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 11.0, top - 4.0), Vector2(x + 11.0, top - 4.0), Vector2(x, top + length),
		]), color)

	# Gefrorene Seen / Nebel am Boden.
	var mist := Color(0.55, 0.85, 0.94, 0.05)
	for i in range(5):
		var y := _map_rect.position.y + _map_size.y * (0.58 + 0.07 * float(i))
		draw_line(Vector2(0.0, y), Vector2(_canvas_size.x, y + 12.0), mist, 26.0 - float(i) * 3.0, true)

# --- Shared ------------------------------------------------------------------

func _draw_motes() -> void:
	var color := Color.WHITE
	match theme_id:
		"neon":
			color = Color(0.50, 0.95, 1.0, 0.35)
		"wool":
			color = Color(1.0, 0.86, 0.91, 0.50)
		"frost":
			color = Color(0.86, 0.97, 1.0, 0.38)
		"platine":
			color = Color(0.45, 1.0, 0.92, 0.30)
		_:
			color = Color(1.0, 0.88, 0.52, 0.38)
	for mote in _motes:
		var x := float(mote["x"])
		var y := float(mote["y"])
		var speed := float(mote["speed"])
		var drift := float(mote["drift"])
		if theme_id == "neon" or theme_id == "platine":
			y = _map_rect.position.y + fposmod(y - _map_rect.position.y - _time * 18.0 * speed, _map_size.y)
		elif theme_id == "wool":
			y = _map_rect.position.y + fposmod(y - _map_rect.position.y + _time * 11.0 * speed, _map_size.y)
			x += sin(_time * 0.7 + float(mote["phase"])) * 10.0
		elif theme_id == "frost":
			y = _map_rect.position.y + fposmod(y - _map_rect.position.y + _time * 14.0 * speed, _map_size.y)
			x += sin(_time * 0.6 + float(mote["phase"])) * 16.0
		else:
			x += sin(_time * 0.35 * speed + float(mote["phase"])) * 22.0
			y += cos(_time * 0.28 * speed + float(mote["phase"])) * 14.0
		var twinkle := 0.55 + 0.45 * sin(_time * 1.8 + float(mote["phase"]))
		draw_circle(Vector2(x, y), float(mote["radius"]) * 1.5, Color(color.r, color.g, color.b, 0.035))
		draw_circle(Vector2(x, y), float(mote["radius"]) * 0.65, Color(color.r, color.g, color.b, color.a * twinkle))

func _draw_vignette() -> void:
	# Weicher Rand statt harter schwarzer Balken.
	var band := 12.0
	var steps := 10
	for i in range(steps):
		var inset := float(i) * band
		var alpha := 0.012 * (1.0 - float(i) / float(steps))
		var dark := Color(0.0, 0.0, 0.0, alpha)
		draw_rect(Rect2(inset, inset, _canvas_size.x - inset * 2.0, band), dark, true)
		draw_rect(Rect2(inset, _canvas_size.y - inset - band, _canvas_size.x - inset * 2.0, band), dark, true)
		draw_rect(Rect2(inset, inset + band, band, _canvas_size.y - (inset + band) * 2.0), dark, true)
		draw_rect(Rect2(_canvas_size.x - inset - band, inset + band, band, _canvas_size.y - (inset + band) * 2.0), dark, true)
