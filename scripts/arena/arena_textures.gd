class_name ArenaTextures
extends RefCounted

# Prozedurale Texturen für die Arena (Boden, Mauern, Kisten).
# Erzeugt aus der Grundfarbe der Karte, mit festem Zufall, damit alle
# Rechner dieselbe Optik sehen. Ergebnisse werden pro Sitzung zwischengespeichert.
#
# Stil: wenige, klar abgestufte Töne in weichen Flecken statt Pixelrauschen.
# Auf dem Bildschirm ist ein Texel etwa ein Pixel groß; feines Rauschen würde
# dort nur flimmern. Flächen (Gras, Sand, Pflaster, Fels, Mauer) kacheln erst
# nach zwei Kacheln, damit kein Raster sichtbar wird.

const SIZE: int = 32
# Flächentexturen reichen über mehrere Kacheln (gleiche Texeldichte), damit
# auf großen Karten kein Tapetenmuster entsteht.
const SPAN: Dictionary = {"grass": 4, "sand": 4, "cobble": 4, "rock": 2, "brick": 2}

static var _cache: Dictionary = {}

static func span_tiles(kind: String) -> int:
	return int(SPAN.get(kind, 1))

static func get_texture(kind: String, base: Color) -> Texture2D:
	var key := "%s_%s" % [kind, base.to_html()]
	if _cache.has(key):
		return _cache[key]
	var size := SIZE * span_tiles(kind)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
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
		"planks":
			_planks(img, base, rng)
		_:
			img.fill(base)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

## Material für Voxel-Würfel: Textur in Weltkoordinaten (Triplanar).
## Vertex-Farben tönen leicht.
static func make_material(kind: String, base: Color, tile: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_texture(kind, base)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE / (tile * float(span_tiles(kind)))
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	return mat

const FLOOR_SHADER: String = """
shader_type spatial;
render_mode specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D vary : filter_linear, repeat_enable;
uniform float tex_scale = 0.01;
uniform float vary_scale = 0.001;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 uv = abs(wnrm.y) > 0.5 ? wpos.xz : (abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy);
	vec3 a = texture(tex, uv * tex_scale).rgb;
	// Große, weiche Hell-Dunkel-Felder, schräg zum Raster: verdeckt die
	// Wiederholung der Textur auf weiten Flächen.
	vec2 q = vec2(wpos.x * 0.83 - wpos.z * 0.56, wpos.x * 0.56 + wpos.z * 0.83) * vary_scale;
	float v = texture(vary, q).r * 0.65 + texture(vary, q * 2.7 + vec2(0.37, 0.11)).r * 0.35;
	vec3 tint = mix(vec3(0.80, 0.86, 0.92), vec3(1.10, 1.07, 0.98), smoothstep(0.25, 0.75, v));
	ALBEDO = a * tint * COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

static var _floor_shader: Shader = null

## Bodenmaterial mit großflächiger Farbvariation (siehe FLOOR_SHADER).
static func make_floor_material(kind: String, base: Color, tile: float) -> ShaderMaterial:
	if _floor_shader == null:
		_floor_shader = Shader.new()
		_floor_shader.code = FLOOR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _floor_shader
	mat.set_shader_parameter("tex", get_texture(kind, base))
	mat.set_shader_parameter("vary", _get_vary())
	mat.set_shader_parameter("tex_scale", 1.0 / (tile * float(span_tiles(kind))))
	mat.set_shader_parameter("vary_scale", 1.0 / (tile * 26.0))
	return mat

static func _get_vary() -> Texture2D:
	if _cache.has("__vary"):
		return _cache["__vary"]
	var n := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 9917
	var lat := _lattice(rng, 6)
	var img := Image.create(n, n, false, Image.FORMAT_R8)
	for y in n:
		for x in n:
			var v := _noise(lat, 6, float(x) / n, float(y) / n)
			img.set_pixel(x, y, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	_cache["__vary"] = tex
	return tex

static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), 1.0)

## Ton mit Farbstich: dunkle Töne kühler, helle wärmer. Das wirkt lebendiger
## als reines Abdunkeln derselben Farbe.
static func _tone(c: Color, f: float) -> Color:
	var s := _shade(c, f)
	if f < 1.0:
		return s.lerp(Color(s.r * 0.82, s.g * 0.9, s.b * 1.12), clampf((1.0 - f) * 1.6, 0.0, 1.0))
	return s.lerp(Color(minf(1.0, s.r * 1.08), minf(1.0, s.g * 1.04), s.b * 0.9), clampf((f - 1.0) * 1.6, 0.0, 1.0))

# --- kachelbares Rauschen ---------------------------------------------------

static func _lattice(rng: RandomNumberGenerator, cells: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(cells * cells)
	for i in out.size():
		out[i] = rng.randf()
	return out

## Weiches, randlos kachelndes Wertrauschen (0..1) mit `cells` Stützstellen.
static func _noise(lat: PackedFloat32Array, cells: int, u: float, v: float) -> float:
	var fx := u * cells
	var fy := v * cells
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - x0
	var ty := fy - y0
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := lat[posmod(y0, cells) * cells + posmod(x0, cells)]
	var b := lat[posmod(y0, cells) * cells + posmod(x0 + 1, cells)]
	var c := lat[posmod(y0 + 1, cells) * cells + posmod(x0, cells)]
	var d := lat[posmod(y0 + 1, cells) * cells + posmod(x0 + 1, cells)]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	var s := img.get_width()
	img.set_pixel(posmod(x, s), posmod(y, s), c)

## Kachelnde Voronoi-Zellen auf einem verwackelten Raster mit n x n Punkten.
## Liefert je Pixel [Zellindex, Abstand zur Kante].
static func _voronoi(size: int, n: int, points: Array) -> Array:
	var out: Array = []
	out.resize(size * size)
	var step := float(size) / n
	for y in size:
		for x in size:
			var best := 1e9
			var second := 1e9
			var idx := 0
			var gx := int(x / step)
			var gy := int(y / step)
			for oy in range(-2, 3):
				for ox in range(-2, 3):
					var i := posmod(gy + oy, n) * n + posmod(gx + ox, n)
					var p: Vector2 = points[i]
					var dx := absf(x + 0.5 - p.x)
					var dy := absf(y + 0.5 - p.y)
					dx = minf(dx, size - dx)
					dy = minf(dy, size - dy)
					var d := sqrt(dx * dx + dy * dy)
					if d < best:
						second = best
						best = d
						idx = i
					elif d < second:
						second = d
			out[y * size + x] = [idx, second - best]
	return out

static func _jitter_points(size: int, n: int, rng: RandomNumberGenerator) -> Array:
	var pts: Array = []
	var step := float(size) / n
	for gy in n:
		for gx in n:
			pts.append(Vector2((gx + rng.randf_range(0.15, 0.85)) * step, (gy + rng.randf_range(0.15, 0.85)) * step))
	return pts

# --- Flächen ----------------------------------------------------------------

static func _grass(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	var s := img.get_width()
	var big := _lattice(rng, 5)
	var small := _lattice(rng, 17)
	var tones: Array[float] = [0.94, 0.975, 1.0, 1.035]
	for y in s:
		for x in s:
			var n := _noise(big, 5, float(x) / s, float(y) / s) * 0.6 + _noise(small, 17, float(x) / s, float(y) / s) * 0.4
			var t := clampi(int((n - 0.22) / 0.56 * tones.size()), 0, tones.size() - 1)
			img.set_pixel(x, y, _tone(base, tones[t]))
	# Grasbüschel: kleine helle Halme mit dunklem Fuß
	for i in 40:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		_put(img, x, y, _tone(base, 0.8))
		_put(img, x - 1, y - 1, _tone(base, 1.12))
		_put(img, x, y - 2, _tone(base, 1.16))
		_put(img, x + 1, y - 1, _tone(base, 1.1))
	# wenige Blüten
	for i in 7:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		var c := Color(0.98, 0.93, 0.6) if i % 2 == 0 else Color(0.95, 0.95, 0.98)
		_put(img, x, y, c)
		_put(img, x, y + 1, _tone(base, 0.76))

static func _sand(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	var s := img.get_width()
	var big := _lattice(rng, 6)
	for y in s:
		for x in s:
			var n := _noise(big, 6, float(x) / s, float(y) / s)
			# weiche Windrippel, quer zur Dünung leicht verbogen
			var r := sin((y + n * 14.0) * TAU / 16.0 + x * TAU / float(s))
			var f := 1.0
			if r > 0.72:
				f = 1.06
			elif r < -0.78:
				f = 0.92
			f += (n - 0.5) * 0.08
			img.set_pixel(x, y, _tone(base, f))
	for i in 30:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		_put(img, x, y, _tone(base, 0.7))
		_put(img, x, y - 1, _tone(base, 1.16))
		if i % 3 == 0:
			_put(img, x + 1, y, _tone(base, 0.76))
			_put(img, x + 1, y - 1, _tone(base, 1.12))

static func _stones(img: Image, base: Color, rng: RandomNumberGenerator, cells: int, gap: float, spread: float) -> void:
	var s := img.get_width()
	var pts := _jitter_points(s, cells, rng)
	var shades: Array[float] = []
	for i in pts.size():
		shades.append(1.0 + rng.randf_range(-spread, spread))
	var vor := _voronoi(s, cells, pts)
	for y in s:
		for x in s:
			var cell: Array = vor[y * s + x]
			var edge: float = cell[1]
			var f: float = shades[cell[0]]
			if edge < gap:
				img.set_pixel(x, y, _tone(base, 0.6))
				continue
			# Licht von oben links: Kante dort hell, gegenüber dunkel
			var up: Array = vor[posmod(y - 1, s) * s + posmod(x - 1, s)]
			var down: Array = vor[posmod(y + 1, s) * s + posmod(x + 1, s)]
			if up[0] != cell[0] or up[1] < gap:
				f *= 1.13
			elif down[0] != cell[0] or down[1] < gap:
				f *= 0.86
			img.set_pixel(x, y, _tone(base, f))

static func _cobble(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	_stones(img, base, rng, 10, 1.3, 0.1)

static func _rock(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	_stones(img, base, rng, 3, 0.9, 0.13)
	var s := img.get_width()
	# feine Schichtlinien für den Felscharakter
	for i in 7:
		var x := rng.randi_range(0, s - 1)
		var y := rng.randi_range(0, s - 1)
		for k in rng.randi_range(4, 9):
			var px := posmod(x + k, s)
			var c := img.get_pixel(px, posmod(y, s))
			img.set_pixel(px, posmod(y, s), _shade(c, 0.86))

static func _brick(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	# Große Quader: zwei Lagen je Kachelhöhe, Steine eine Kachel lang.
	var s := img.get_width()
	var row_h := 16
	var brick_w := 32
	var mortar := _tone(base, 0.62)
	img.fill(mortar)
	for row in int(s / row_h):
		var y0 := row * row_h
		var offset := int(brick_w / 2) if row % 2 == 1 else 0
		for col in int(s / brick_w) + 1:
			var x0 := col * brick_w - offset
			var f := 1.0 + rng.randf_range(-0.09, 0.09)
			var chip := rng.randi_range(0, 5)
			for y in range(y0 + 1, y0 + row_h - 1):
				for x in range(x0 + 1, x0 + brick_w - 1):
					var ff := f
					if y == y0 + 1 or x == x0 + 1:
						ff *= 1.12
					elif y == y0 + row_h - 2 or x == x0 + brick_w - 2:
						ff *= 0.84
					_put(img, x, y, _tone(base, ff))
			# kleine Macke oder Fuge im Stein, damit die Fläche nicht steril wirkt
			if chip == 0:
				var cx := x0 + rng.randi_range(6, brick_w - 8)
				for k in 4:
					_put(img, cx + k, y0 + 6 + (k % 2), _tone(base, f * 0.8))
			elif chip == 1:
				var cx := x0 + rng.randi_range(5, brick_w - 6)
				_put(img, cx, y0 + row_h - 3, mortar)
				_put(img, cx + 1, y0 + row_h - 3, mortar)
				_put(img, cx, y0 + row_h - 4, mortar)

static func _wood(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	# Kiste: waagrechte Bretter mit ruhiger Maserung, dunkler Rahmen, Querstrebe
	for y in SIZE:
		var plank := int(y / 8)
		var pf := 1.0 + (0.06 if plank % 2 == 0 else -0.04)
		for x in SIZE:
			var grain := 0.05 if int((x + plank * 5) / 6) % 3 == 0 else 0.0
			var c := _tone(base, pf - grain)
			if y % 8 == 7:
				c = _tone(base, 0.66)
			elif y % 8 == 0:
				c = _tone(base, pf + 0.08)
			img.set_pixel(x, y, c)
	var frame := _tone(base, 0.56)
	var frame_hi := _tone(base, 0.78)
	for i in SIZE:
		for t in 3:
			var c := frame_hi if t == 2 else frame
			img.set_pixel(i, t, c)
			img.set_pixel(i, SIZE - 1 - t, c)
			img.set_pixel(t, i, c)
			img.set_pixel(SIZE - 1 - t, i, c)
	for i in range(3, SIZE - 3):
		img.set_pixel(i, i, frame)
		img.set_pixel(clampi(i + 1, 0, SIZE - 1), i, frame)
		img.set_pixel(clampi(i + 2, 0, SIZE - 1), i, frame_hi)
	for p in [Vector2i(4, 4), Vector2i(27, 4), Vector2i(4, 27), Vector2i(27, 27)]:
		img.set_pixelv(p, Color(0.86, 0.84, 0.78))
		img.set_pixelv(p + Vector2i(1, 1), _tone(base, 0.4))

static func _planks(img: Image, base: Color, rng: RandomNumberGenerator) -> void:
	# Stegbohlen: vier Bretter quer, versetzte Stöße, zwei Nägel je Brett
	for row in 4:
		var y0 := row * 8
		var pf := 1.0 + rng.randf_range(-0.08, 0.08)
		var joint := rng.randi_range(6, 26)
		for y in range(y0, y0 + 8):
			for x in SIZE:
				var grain := 0.05 if int((x + row * 7) / 5) % 3 == 0 and (y - y0) % 3 == 1 else 0.0
				var c := _tone(base, pf - grain)
				if y == y0 + 7:
					c = _tone(base, 0.5)
				elif y == y0:
					c = _tone(base, pf + 0.1)
				if x == joint:
					c = _tone(base, 0.58)
				img.set_pixel(x, y, c)
		img.set_pixel(posmod(joint - 3, SIZE), y0 + 3, Color(0.8, 0.8, 0.74))
		img.set_pixel(posmod(joint + 3, SIZE), y0 + 3, Color(0.8, 0.8, 0.74))

## Weicher Schattenfleck (Mitte dunkel, Rand transparent) für Kontaktschatten
## am Fuß von Mauern und unter Figuren.
static func get_soft_blob() -> Texture2D:
	if _cache.has("__blob"):
		return _cache["__blob"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * (3.0 - 2.0 * a)))
	var tex := ImageTexture.create_from_image(img)
	_cache["__blob"] = tex
	return tex

## Wie get_soft_blob, aber als abgerundetes Quadrat: innen voll, Rand weich.
static func get_soft_square() -> Texture2D:
	if _cache.has("__square"):
		return _cache["__square"]
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := absf(x + 0.5 - n * 0.5) / (n * 0.5)
			var dy := absf(y + 0.5 - n * 0.5) / (n * 0.5)
			# 0.5 = Blockkante (Quad ist doppelt so groß wie der Block)
			var d := maxf(dx, dy)
			var a := clampf((1.0 - d) / 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a))
	var tex := ImageTexture.create_from_image(img)
	_cache["__square"] = tex
	return tex
