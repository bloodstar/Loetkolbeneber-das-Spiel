class_name ArenaTextures
extends RefCounted

# Prozedurale 32x32-Pixeltexturen für die Arena (Boden, Mauern, Kisten).
# Erzeugt aus der Grundfarbe der Karte, mit festem Zufall, damit alle
# Rechner dieselbe Optik sehen. Ergebnisse werden pro Sitzung zwischengespeichert.

const SIZE: int = 32

static var _cache: Dictionary = {}

static func get_texture(kind: String, base: Color) -> Texture2D:
	var key := "%s_%s" % [kind, base.to_html()]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match kind:
		"grass":
			_grass(img, base, rng)
		"sand":
			_sand(img, base, rng)
		"cobble":
			_cobble(img, base, rng)
		"brick":
			_brick(img, base, rng)
		"rock":
			_rock(img, base, rng)
		"wood":
			_wood(img, base, rng)
		_:
			img.fill(base)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Material für Voxel-Würfel: Textur in Weltkoordinaten (Triplanar), eine
## Wiederholung pro Kachel, scharfe Pixel. Vertex-Farben tönen leicht.
static func make_material(kind: String, base: Color, tile: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_texture(kind, base)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / tile
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.92
	return mat

static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), 1.0)

static func _grass(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var f := 1.0 + rng.randf_range(-0.07, 0.07)
			img.set_pixel(x, y, _shade(base, f))
	# Halme: kurze dunkle und helle Striche
	for i in 34:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(1, SIZE - 1)
		var light := rng.randf() < 0.4
		var c := _shade(base, 1.28 if light else 0.72)
		img.set_pixel(x, y, c)
		img.set_pixel(x, y - 1, _shade(c, 1.05))
	# ein paar Blümchen/Steinchen
	for i in 3:
		var x := rng.randi_range(2, SIZE - 3)
		var y := rng.randi_range(2, SIZE - 3)
		img.set_pixel(x, y, Color(0.95, 0.9, 0.55) if rng.randf() < 0.5 else Color(0.85, 0.85, 0.82))
	_tile_edge(img, 0.9)

static func _sand(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			# leichte Rippel
			var ripple := sin((x * 0.35 + y * 0.9)) * 0.04
			img.set_pixel(x, y, _shade(base, 1.0 + ripple + rng.randf_range(-0.05, 0.05)))
	for i in 26:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		img.set_pixel(x, y, _shade(base, 0.7 if rng.randf() < 0.6 else 1.25))
	_tile_edge(img, 0.92)

static func _cobble(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	var grout := _shade(base, 0.72)
	img.fill(grout)
	# 2x2 quadratische Pflastersteine (bewusst anders als Mauerziegel)
	for row in 2:
		for col in 2:
			var x0 := col * 16 + 1
			var y0 := row * 16 + 1
			var f := 1.0 + rng.randf_range(-0.12, 0.12)
			for y in range(y0, y0 + 14):
				for x in range(x0, x0 + 14):
					if x < 0 or x >= SIZE or y < 0 or y >= SIZE:
						continue
					var c := _shade(base, f + rng.randf_range(-0.04, 0.04))
					if y == y0 or x == x0:
						c = _shade(c, 1.18)
					elif y == y0 + 13 or x == x0 + 13:
						c = _shade(c, 0.82)
					img.set_pixel(x, y, c)

static func _brick(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	var mortar := _shade(base, 0.5)
	img.fill(mortar)
	for row in 4:
		var y0 := row * 8
		var offset := 8 if row % 2 == 1 else 0
		for col in 3:
			var x0 := col * 16 - offset
			var f := 1.0 + rng.randf_range(-0.14, 0.14)
			for y in range(y0 + 1, y0 + 7):
				for x in range(x0 + 1, x0 + 15):
					var px := posmod(x, SIZE)
					var c := _shade(base, f + rng.randf_range(-0.05, 0.05))
					if y == y0 + 1:
						c = _shade(c, 1.2)
					elif y == y0 + 6:
						c = _shade(c, 0.8)
					img.set_pixel(px, y, c)

static func _rock(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	for y in SIZE:
		for x in SIZE:
			var n := sin(x * 0.7 + rng.randf() * 0.3) * cos(y * 0.5) * 0.08
			img.set_pixel(x, y, _shade(base, 1.0 + n + rng.randf_range(-0.08, 0.08)))
	# Risse
	for i in 4:
		var x := rng.randi_range(2, SIZE - 3)
		var y := rng.randi_range(2, SIZE - 3)
		for k in rng.randi_range(4, 9):
			img.set_pixel(clampi(x, 0, SIZE - 1), clampi(y, 0, SIZE - 1), _shade(base, 0.55))
			x += rng.randi_range(-1, 1)
			y += 1
	_tile_edge(img, 0.75)

static func _wood(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	# Waagrechte Bretter mit Maserung, dunkler Rahmen, Querstrebe
	for y in SIZE:
		var plank := int(y / 8)
		var pf := 1.0 + (0.08 if plank % 2 == 0 else -0.04)
		for x in SIZE:
			var grain := sin(x * 0.6 + plank * 2.0) * 0.05
			var c := _shade(base, pf + grain + rng.randf_range(-0.04, 0.04))
			if y % 8 == 7:
				c = _shade(base, 0.6)
			img.set_pixel(x, y, c)
	var frame := _shade(base, 0.5)
	for i in SIZE:
		for t in 3:
			img.set_pixel(i, t, frame)
			img.set_pixel(i, SIZE - 1 - t, frame)
			img.set_pixel(t, i, frame)
			img.set_pixel(SIZE - 1 - t, i, frame)
	for i in range(3, SIZE - 3):
		for t in 2:
			img.set_pixel(clampi(i + t, 0, SIZE - 1), i, frame)
	# Nägel
	for p in [Vector2i(4, 4), Vector2i(27, 4), Vector2i(4, 27), Vector2i(27, 27)]:
		img.set_pixelv(p, Color(0.8, 0.8, 0.75))

static func _tile_edge(img: Image, f: float) -> void:
	# dezente Kachelkante, damit das Raster lesbar bleibt
	for i in SIZE:
		img.set_pixel(i, 0, _shade(img.get_pixel(i, 0), f))
		img.set_pixel(0, i, _shade(img.get_pixel(0, i), f))
