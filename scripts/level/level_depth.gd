class_name LevelDepth
extends Node2D

## Räumliche Tiefe für die Seitenansicht: Jede feste Fläche bekommt Seiten-
## flächen, die perspektivisch nach hinten laufen (Fluchtpunkt = Bildmitte der
## Kamera). Wie ein Guckkasten: Links der Mitte sieht man die rechte Flanke
## der Plattformen, oberhalb die Unterseite. Verschiebt sich die Kamera
## (Folgen, Zoom, Wackeln), verschieben sich die Rückkanten gegen die
## Vorderkanten und das Level wirkt dreidimensional.
##
## Die Vorderseite bleibt exakt, wo sie war (Kollision und Kacheln ändern
## sich nicht). Die Perspektive rechnet ein Shader pro Eckpunkt: UV.x = 0
## liegt vorn, UV.x = 1 hinten.

# Wie weit die Rückseite zur Bildmitte rückt. 0.94 = 6 % näher zur Mitte,
# am Bildrand rund anderthalb Kacheln sichtbare Tiefe.
const FAR_SCALE: float = 0.94
# Hintergrund-Parallaxe: Anteil der Kamerabewegung, den der Hintergrund mitgeht.
const BACKDROP_FOLLOW: float = 0.3
# Tiefenflächen liegen hinter allen Kacheln, aber vor dem Hintergrund (-100).
const Z_DEPTH: int = -60

const SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;
uniform vec2 center = vec2(0.0);
uniform float far_scale = 0.94;
void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 back = center + (world - center) * far_scale;
	float depth = UV.x;
	// UV.y = Winkel der Außennormale der Fläche. Zeigt sie von der Bildmitte
	// weg, liegt die Fläche auf der abgewandten Seite: nicht zeichnen (auf die
	// Vorderkante zusammenfalten). Sonst stünden rechts und links Wände über
	// der Oberseite und die Plattform sähe aus wie eine Wanne.
	if (UV.y < 50.0) {
		vec2 n = mat2(MODEL_MATRIX[0].xy, MODEL_MATRIX[1].xy) * vec2(cos(UV.y), sin(UV.y));
		if (dot(n, center - world) <= 0.0) {
			depth = 0.0;
		}
	}
	world = mix(world, back, depth);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 0.0, 1.0)).xy;
}
void fragment() {
	COLOR = COLOR;
}
"""

static var _material: ShaderMaterial = null
static var _avg_cache: Dictionary = {}

var _st_vertices := PackedVector2Array()
var _st_colors := PackedColorArray()
var _st_uvs := PackedVector2Array()
var _mesh_instance: MeshInstance2D
var _backdrop: Node2D = null
var _backdrop_home: Vector2 = Vector2.ZERO
var _map_center: Vector2 = Vector2.ZERO
var _backdrop_limit: Vector2 = Vector2.ZERO
# Zielfarbe der Luftperspektive, je Level aus dem Hintergrund gesetzt. Statisch,
# damit auch einzeln angehängte Objekte (Kisten) dieselbe Farbe nehmen.
static var fog: Color = Color(0.05, 0.07, 0.12)

static func shared_material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter("far_scale", FAR_SCALE)
	return _material

## Mittlere Farbe einer Kacheltextur (für die Seitenflächen).
## `top_only`: nur das obere Viertel (z. B. die Grasnarbe einer Bodenkachel).
static func average_color(tex: Texture2D, top_only: bool = false) -> Color:
	if tex == null:
		return Color(0.3, 0.3, 0.34)
	var key := "%d|%s" % [tex.get_rid().get_id(), top_only]
	if _avg_cache.has(key):
		return _avg_cache[key]
	var img := tex.get_image()
	var result := Color(0.3, 0.3, 0.34)
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var sum := Vector3.ZERO
		var weight := 0.0
		var step := maxi(1, int(img.get_width() / 12))
		var rows := maxi(1, int(img.get_height() / 4)) if top_only else img.get_height()
		for y in range(0, rows, step if not top_only else 1):
			for x in range(0, img.get_width(), step):
				var c := img.get_pixel(x, y)
				sum += Vector3(c.r, c.g, c.b) * c.a
				weight += c.a
		if weight > 0.0:
			result = Color(sum.x / weight, sum.y / weight, sum.z / weight)
	_avg_cache[key] = result
	return result

func _init() -> void:
	z_index = Z_DEPTH
	z_as_relative = false

## Hintergrund, der bei Kamerabewegung langsamer mitzieht (wirkt weiter weg).
## `limit` = größter erlaubter Versatz (der Hintergrund hat nur so viel Rand).
func set_backdrop(node: Node2D, map_center: Vector2, limit: Vector2) -> void:
	_backdrop = node
	_backdrop_home = node.position
	_map_center = map_center
	_backdrop_limit = limit

## `top`: Farbe der Oberseite (Alpha 0 = aus `base` abgeleitet).
func add_rect(rect: Rect2, base: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	add_polygon(PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	]), base, top)

## Konvexes Polygon (beliebige Umlaufrichtung) in Pixelkoordinaten des Levels.
func add_polygon(points: PackedVector2Array, base: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	_append_faces(_st_vertices, _st_colors, _st_uvs, points, base, fog, top)

static func _append_faces(verts: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, points: PackedVector2Array, base: Color, fog_color: Color, top: Color = Color(0, 0, 0, 0)) -> void:
	var top_col := top if top.a > 0.0 else base.lightened(0.1)
	top_col.a = 1.0
	var n := points.size()
	if n < 3:
		return
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= float(n)
	# Rückwand zuerst (sonst sähe man zwischen den Flanken durch).
	var back_col := base.darkened(0.45).lerp(fog_color, 0.5)
	for i in range(1, n - 1):
		for p in [points[0], points[i], points[i + 1]]:
			verts.append(p)
			colors.append(back_col)
			uvs.append(Vector2(1.0, 100.0))
	for i in range(n):
		var a := points[i]
		var b := points[(i + 1) % n]
		var edge := b - a
		if edge.length_squared() < 0.01:
			continue
		var normal := Vector2(edge.y, -edge.x).normalized()
		if normal.dot((a + b) * 0.5 - center) < 0.0:
			normal = -normal
		# Licht von oben: Oberseiten hell, Unterseiten dunkel, Flanken mittel.
		var shade := base.darkened(0.3)
		var is_top := normal.y < -0.35
		if is_top:
			shade = top_col.darkened(0.08).lerp(base.darkened(0.3), 1.0 + normal.y)
		elif normal.y > 0.35:
			shade = base.darkened(0.3).lerp(base.darkened(0.58), normal.y)
		var far := shade.lerp(fog_color, 0.12) if is_top else shade.darkened(0.12).lerp(fog_color, 0.3)
		for item in [[a, 0.0], [b, 0.0], [b, 1.0], [a, 0.0], [b, 1.0], [a, 1.0]]:
			verts.append(item[0])
			colors.append(shade if item[1] == 0.0 else far)
			uvs.append(Vector2(item[1], normal.angle()))

static func _make_mesh(verts: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Nach dem Levelaufbau: alle gesammelten Flächen zu einem Mesh backen.
func bake() -> void:
	if _st_vertices.is_empty():
		return
	_mesh_instance = MeshInstance2D.new()
	_mesh_instance.mesh = _make_mesh(_st_vertices, _st_colors, _st_uvs)
	_mesh_instance.material = shared_material()
	add_child(_mesh_instance)
	_st_vertices = PackedVector2Array()
	_st_colors = PackedColorArray()
	_st_uvs = PackedVector2Array()

## Tiefe für ein einzelnes, bewegliches oder zerstörbares Objekt (Kiste,
## zerstörbare Kachel): eigener Knoten als Kind, zieht mit, dreht mit,
## verschwindet mit dem Elternknoten. `points` in lokalen Koordinaten.
static func attach(parent: CanvasItem, points: PackedVector2Array, base: Color, top: Color = Color(0, 0, 0, 0)) -> MeshInstance2D:
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	_append_faces(verts, colors, uvs, points, base, fog, top)
	var mi := MeshInstance2D.new()
	mi.name = "Depth"
	mi.mesh = _make_mesh(verts, colors, uvs)
	mi.material = shared_material()
	mi.z_index = Z_DEPTH + 1
	mi.z_as_relative = false
	parent.add_child(mi)
	return mi

static func attach_box(parent: CanvasItem, size: Vector2, base: Color, offset: Vector2 = Vector2.ZERO, top: Color = Color(0, 0, 0, 0)) -> MeshInstance2D:
	var h := size * 0.5
	return attach(parent, PackedVector2Array([
		offset + Vector2(-h.x, -h.y), offset + Vector2(h.x, -h.y), offset + Vector2(h.x, h.y), offset + Vector2(-h.x, h.y),
	]), base, top)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	shared_material().set_shader_parameter("center", center)
	if _backdrop != null and is_instance_valid(_backdrop):
		var shift := (center - _map_center) * BACKDROP_FOLLOW
		shift.x = clampf(shift.x, -_backdrop_limit.x, _backdrop_limit.x)
		shift.y = clampf(shift.y, -_backdrop_limit.y, _backdrop_limit.y)
		_backdrop.position = _backdrop_home + shift
