class_name HordeBeast
extends Node3D

# Voxel-Modell eines Horden-Gegners für die Arena-3D-Ansicht.
#
# Jede Art besteht aus wenigen Teilen (Rumpf, Kopf, Beine, Flügel, Arm). Die
# Quader eines Teils sind zu einem ArrayMesh mit Vertex-Farben verschmolzen
# und pro Art zwischengespeichert, so kostet ein Gegner nur eine Handvoll
# MeshInstances mit gemeinsamem Material. Treffer-Aufblitzen läuft über ein
# gemeinsames Overlay-Material.
#
# Koordinaten wie VoxelPig: x = vorn, y = oben, z = seitlich, Einheit Pixel.

const PART_BODY := "body"
const PART_HEAD := "head"

static var _mesh_cache: Dictionary = {}  # kind -> {part: {mesh, pivot}}
static var _material: StandardMaterial3D = null
static var _flash_mat: StandardMaterial3D = null
static var _frost_mat: StandardMaterial3D = null
static var _gold_mat: StandardMaterial3D = null

var kind: String = "wolf"
var _pose: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _wings: Array[Node3D] = []
var _arm: Node3D
var _jaw: Node3D
var _tail: Node3D
var _meshes: Array[MeshInstance3D] = []
var _walk: float = 0.0
var _walk_amount: float = 0.0
var _time: float = 0.0
var _biped: bool = false
var _last_overlay: Material = null

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.85
		_material.metallic_specular = 0.2
		# Silhouette hinter Mauern (wie die Eber), in Warnrot.
		_material.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		_material.stencil_color = Color(1.0, 0.25, 0.2, 0.45)
	return _material

static func _overlay(kind_name: String) -> StandardMaterial3D:
	match kind_name:
		"flash":
			if _flash_mat == null:
				_flash_mat = StandardMaterial3D.new()
				_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_flash_mat.albedo_color = Color(1, 1, 1, 0.75)
			return _flash_mat
		"frost":
			if _frost_mat == null:
				_frost_mat = StandardMaterial3D.new()
				_frost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_frost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_frost_mat.albedo_color = Color(0.5, 0.85, 1.0, 0.45)
			return _frost_mat
		_:
			if _gold_mat == null:
				_gold_mat = StandardMaterial3D.new()
				_gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_gold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_gold_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_gold_mat.albedo_color = Color(1.0, 0.75, 0.2, 0.22)
			return _gold_mat

func build(p_kind: String) -> void:
	kind = p_kind
	for c in get_children():
		c.queue_free()
	_legs.clear()
	_wings.clear()
	_meshes.clear()
	_head = null
	_arm = null
	_jaw = null
	_tail = null
	_pose = Node3D.new()
	add_child(_pose)
	var parts := _parts_for(kind)
	_biped = kind == "metzger" or kind == "jaeger"
	for name in parts.keys():
		var entry: Dictionary = parts[name]
		var holder := Node3D.new()
		holder.position = entry["pivot"]
		var parent: Node3D = _pose
		if str(name).begins_with("jaw") and _head != null:
			parent = _head
			holder.position = entry["pivot"] - _head.position
		parent.add_child(holder)
		var mi := MeshInstance3D.new()
		mi.mesh = entry["mesh"]
		mi.material_override = _shared_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		holder.add_child(mi)
		_meshes.append(mi)
		var n := str(name)
		if n.begins_with("leg"):
			_legs.append(holder)
		elif n.begins_with("wing"):
			_wings.append(holder)
		elif n == PART_HEAD:
			_head = holder
		elif n == "arm":
			_arm = holder
		elif n.begins_with("jaw"):
			_jaw = holder
		elif n == "tail":
			_tail = holder

## Pro Frame aus HordeEnemy-Zustand.
func animate(delta: float, planar_speed: float, action: float, flash: bool, frozen: bool, riese: bool) -> void:
	if _pose == null:
		return
	_time += delta
	var moving := planar_speed > 15.0 and not frozen
	_walk_amount = move_toward(_walk_amount, 1.0 if moving else 0.0, delta * 6.0)
	if moving:
		_walk += delta * clampf(planar_speed / 12.0, 6.0, 22.0)
	var swing := sin(_walk)
	for i in range(_legs.size()):
		var sgn := 1.0 if (i % 2 == 0) == (i < 2) else -1.0
		if _biped:
			sgn = 1.0 if i == 0 else -1.0
		_legs[i].rotation.z = swing * sgn * 0.7 * _walk_amount
	_pose.position.y = absf(swing) * 1.6 * _walk_amount
	for i in range(_wings.size()):
		var side := -1.0 if i == 0 else 1.0
		var flap := sin(_time * (16.0 if action > 0.0 else 9.0)) * 0.65
		if action > 0.0:
			flap = -0.9
		_wings[i].rotation.x = flap * side
	if _head:
		_head.rotation.z = -swing * 0.06 * _walk_amount + (0.35 if action > 0.0 and not _biped else 0.0)
	if _jaw:
		_jaw.rotation.z = (-0.55 if action > 0.0 else -0.05 - absf(sin(_time * 2.0)) * 0.05)
	if _arm:
		_arm.rotation.z = (1.6 if action > 0.0 else -swing * 0.5 * _walk_amount)
	if _tail:
		_tail.rotation.y = sin(_time * 7.0) * 0.3
	var overlay: Material = null
	if flash:
		overlay = _overlay("flash")
	elif frozen:
		overlay = _overlay("frost")
	elif riese:
		overlay = _overlay("gold")
	if overlay != _last_overlay:
		_last_overlay = overlay
		for mi in _meshes:
			mi.material_overlay = overlay

# ============================================================
# Modelle
# ============================================================

static func _parts_for(k: String) -> Dictionary:
	if _mesh_cache.has(k):
		return _mesh_cache[k]
	var spec: Dictionary = {}
	match k:
		"fuchs":
			spec = _spec_fox()
		"wolf":
			spec = _spec_wolf(Color(0.55, 0.56, 0.6), Color(0.82, 0.82, 0.84), Color(1.0, 0.85, 0.2), false)
		"alphawolf":
			spec = _spec_wolf(Color(0.24, 0.24, 0.28), Color(0.85, 0.85, 0.9), Color(1.0, 0.2, 0.15), true)
		"adler":
			spec = _spec_eagle()
		"krokodil":
			spec = _spec_croc()
		"baer":
			spec = _spec_bear()
		"metzger":
			spec = _spec_butcher()
		"jaeger":
			spec = _spec_hunter()
		_:
			spec = _spec_wolf(Color(0.55, 0.56, 0.6), Color(0.82, 0.82, 0.84), Color(1.0, 0.85, 0.2), false)
	var out := {}
	for name in spec.keys():
		var part: Dictionary = spec[name]
		out[name] = {"mesh": _bake(part["boxes"], part["pivot"]), "pivot": part["pivot"]}
	_mesh_cache[k] = out
	return out

## Quader [size, pos, color] (pos in Modellkoordinaten) relativ zum Drehpunkt backen.
static func _bake(boxes: Array, pivot: Vector3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in boxes:
		_add_box(st, b[0], b[1] - pivot, b[2])
	return st.commit()

static func _add_box(st: SurfaceTool, size: Vector3, c: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
		[Vector3(-1, 0, 0), [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
		[Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
		[Vector3(0, -1, 0), [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1)]],
		[Vector3(0, 0, 1), [Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)]],
		[Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, -1, -1)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		# Einfache Schattierung: Oberseiten heller, Unterseiten dunkler.
		var shade := 1.0
		if n.y > 0.5:
			shade = 1.08
		elif n.y < -0.5:
			shade = 0.7
		var fc := Color(col.r * shade, col.g * shade, col.b * shade, col.a)
		var v: Array = f[1]
		var p0: Vector3 = c + v[0] * h
		var p1: Vector3 = c + v[1] * h
		var p2: Vector3 = c + v[2] * h
		var p3: Vector3 = c + v[3] * h
		for p in [p0, p2, p1, p0, p3, p2]:
			st.set_normal(n)
			st.set_color(fc)
			st.add_vertex(p)

static func _part(pivot: Vector3, boxes: Array) -> Dictionary:
	return {"pivot": pivot, "boxes": boxes}

static func _legs4(spec: Dictionary, xs: Array, zs: Array, hip_y: float, thick: float, len: float, col: Color, foot: Color) -> void:
	var i := 0
	for lx in xs:
		for lz in zs:
			var pivot := Vector3(lx, hip_y, lz)
			spec["leg%d" % i] = _part(pivot, [
				[Vector3(thick, len, thick), pivot + Vector3(0, -len * 0.5, 0), col],
				[Vector3(thick + 0.6, 2.0, thick + 0.8), pivot + Vector3(0.6, -len + 1.0, 0), foot],
			])
			i += 1

static func _eyes(boxes: Array, x: float, y: float, z: float, col: Color) -> void:
	for s in [-1.0, 1.0]:
		boxes.append([Vector3(1.2, 2.0, 2.2), Vector3(x, y, z * s), col])

static func _spec_fox() -> Dictionary:
	var fur := Color(0.92, 0.48, 0.16)
	var white := Color(0.97, 0.93, 0.86)
	var dark := Color(0.2, 0.12, 0.08)
	var spec := {}
	_legs4(spec, [-5.0, 5.0], [-3.0, 3.0], 7.0, 2.6, 7.0, dark, dark)
	spec[PART_BODY] = _part(Vector3.ZERO, [
		[Vector3(16, 7, 8), Vector3(0, 10, 0), fur],
		[Vector3(12, 2, 6), Vector3(0, 6.6, 0), white],
	])
	var head := [
		[Vector3(8, 7, 8), Vector3(10, 14, 0), fur],
		[Vector3(6, 3.5, 4.6), Vector3(16, 12.2, 0), white],
		[Vector3(1.6, 1.6, 1.6), Vector3(19.2, 13.0, 0), dark],
		[Vector3(2.2, 5, 2.6), Vector3(9, 19.5, -2.6), fur],
		[Vector3(2.2, 5, 2.6), Vector3(9, 19.5, 2.6), fur],
		[Vector3(1.0, 2.6, 1.6), Vector3(10.2, 20.5, -2.6), dark],
		[Vector3(1.0, 2.6, 1.6), Vector3(10.2, 20.5, 2.6), dark],
	]
	_eyes(head, 14.1, 15.2, 2.4, Color(0.15, 0.1, 0.05))
	spec[PART_HEAD] = _part(Vector3(7, 12, 0), head)
	spec["tail"] = _part(Vector3(-8, 11, 0), [
		[Vector3(10, 5, 5), Vector3(-12, 11.5, 0), fur],
		[Vector3(4, 4.4, 4.4), Vector3(-18.5, 12, 0), white],
	])
	return spec

static func _spec_wolf(fur: Color, light: Color, eye: Color, alpha: bool) -> Dictionary:
	var dark := fur.darkened(0.35)
	var spec := {}
	_legs4(spec, [-7.0, 7.0], [-3.6, 3.6], 9.0, 3.4, 9.0, dark, dark.darkened(0.3))
	var body := [
		[Vector3(22, 10, 10), Vector3(0, 13, 0), fur],
		[Vector3(16, 2.4, 7.6), Vector3(0, 7.8, 0), light],
		[Vector3(12, 3, 10.6), Vector3(4, 18, 0), fur.darkened(0.12)],
	]
	if alpha:
		# Mähne und Narben-Streifen
		body.append([Vector3(9, 13, 13), Vector3(8, 15, 0), light])
		body.append([Vector3(2, 1.2, 10.8), Vector3(-4, 18.2, 0), Color(0.75, 0.15, 0.12)])
	spec[PART_BODY] = _part(Vector3.ZERO, body)
	var head := [
		[Vector3(10, 9, 10), Vector3(14, 18, 0), fur],
		[Vector3(8, 4.4, 6), Vector3(21, 15.2, 0), light],
		[Vector3(2.2, 2.2, 2.6), Vector3(25.2, 16.6, 0), Color(0.08, 0.08, 0.1)],
		[Vector3(3, 6, 3), Vector3(12, 25, -3.4), fur],
		[Vector3(3, 6, 3), Vector3(12, 25, 3.4), fur],
	]
	_eyes(head, 19.1, 19.6, 2.8, eye)
	spec[PART_HEAD] = _part(Vector3(10, 16, 0), head)
	spec["jaw"] = _part(Vector3(17, 13.6, 0), [
		[Vector3(8, 2, 5.4), Vector3(21, 12.6, 0), light.darkened(0.1)],
		[Vector3(1, 1.6, 1), Vector3(24, 13.8, -2), Color(1, 1, 1)],
		[Vector3(1, 1.6, 1), Vector3(24, 13.8, 2), Color(1, 1, 1)],
	])
	spec["tail"] = _part(Vector3(-11, 15, 0), [
		[Vector3(11, 4, 4), Vector3(-16, 13, 0), fur],
		[Vector3(4, 3.4, 3.4), Vector3(-22, 11.4, 0), light],
	])
	return spec

static func _spec_eagle() -> Dictionary:
	var brown := Color(0.42, 0.27, 0.15)
	var white := Color(0.96, 0.95, 0.92)
	var beak := Color(1.0, 0.78, 0.18)
	var spec := {}
	spec[PART_BODY] = _part(Vector3.ZERO, [
		[Vector3(14, 7, 8), Vector3(0, 10, 0), brown],
		[Vector3(7, 3, 9), Vector3(-9, 10, 0), white],
		[Vector3(2.4, 3, 1.6), Vector3(1, 5.2, -2), beak],
		[Vector3(2.4, 3, 1.6), Vector3(1, 5.2, 2), beak],
	])
	var head := [
		[Vector3(7, 7, 7), Vector3(9, 13, 0), white],
		[Vector3(4, 2.6, 3), Vector3(14, 12, 0), beak],
		[Vector3(1.6, 2.2, 1.6), Vector3(15.6, 10.4, 0), beak.darkened(0.2)],
	]
	_eyes(head, 12.6, 14.2, 2.0, Color(0.1, 0.08, 0.04))
	spec[PART_HEAD] = _part(Vector3(6, 11, 0), head)
	spec["wing0"] = _part(Vector3(1, 12, -4), [
		[Vector3(11, 2, 20), Vector3(0, 12, -14), brown],
		[Vector3(7, 1.6, 6), Vector3(-2, 12, -26), brown.darkened(0.4)],
	])
	spec["wing1"] = _part(Vector3(1, 12, 4), [
		[Vector3(11, 2, 20), Vector3(0, 12, 14), brown],
		[Vector3(7, 1.6, 6), Vector3(-2, 12, 26), brown.darkened(0.4)],
	])
	return spec

static func _spec_croc() -> Dictionary:
	var green := Color(0.28, 0.46, 0.22)
	var belly := Color(0.72, 0.74, 0.46)
	var dark := green.darkened(0.35)
	var spec := {}
	_legs4(spec, [-8.0, 8.0], [-7.5, 7.5], 5.0, 3.6, 5.0, dark, dark)
	var body := [
		[Vector3(28, 6.5, 12), Vector3(0, 6.5, 0), green],
		[Vector3(24, 1.6, 9), Vector3(0, 3.2, 0), belly],
	]
	for i in range(5):
		body.append([Vector3(2.2, 2.0, 2.2), Vector3(-10 + i * 5.0, 10.6, -2.6), dark])
		body.append([Vector3(2.2, 2.0, 2.2), Vector3(-10 + i * 5.0, 10.6, 2.6), dark])
	spec[PART_BODY] = _part(Vector3.ZERO, body)
	var head := [
		[Vector3(16, 4.5, 9), Vector3(21, 8.4, 0), green],
		[Vector3(3, 3, 3), Vector3(16, 11.6, -3), green],
		[Vector3(3, 3, 3), Vector3(16, 11.6, 3), green],
	]
	_eyes(head, 16.8, 12.2, 3.0, Color(1.0, 0.85, 0.2))
	for i in range(4):
		head.append([Vector3(1.2, 1.6, 1), Vector3(17 + i * 3.6, 5.6, -4.4), Color(1, 1, 0.92)])
		head.append([Vector3(1.2, 1.6, 1), Vector3(17 + i * 3.6, 5.6, 4.4), Color(1, 1, 0.92)])
	spec[PART_HEAD] = _part(Vector3(13, 7, 0), head)
	spec["jaw"] = _part(Vector3(14, 5.6, 0), [
		[Vector3(15, 2.4, 8.4), Vector3(21, 4.6, 0), belly.darkened(0.1)],
	])
	spec["tail"] = _part(Vector3(-13, 6, 0), [
		[Vector3(12, 5, 8), Vector3(-19, 5.6, 0), green],
		[Vector3(10, 3.4, 5), Vector3(-29, 4.6, 0), green],
		[Vector3(6, 2.4, 3), Vector3(-36, 4.0, 0), dark],
	])
	return spec

static func _spec_bear() -> Dictionary:
	var fur := Color(0.42, 0.27, 0.16)
	var light := Color(0.62, 0.45, 0.3)
	var dark := fur.darkened(0.35)
	var spec := {}
	_legs4(spec, [-8.0, 8.0], [-6.0, 6.0], 11.0, 6.5, 11.0, dark, dark.darkened(0.3))
	spec[PART_BODY] = _part(Vector3.ZERO, [
		[Vector3(26, 17, 18), Vector3(0, 19, 0), fur],
		[Vector3(18, 3, 14), Vector3(0, 10, 0), light],
		[Vector3(14, 6, 17), Vector3(6, 28, 0), fur.darkened(0.08)],
	])
	var head := [
		[Vector3(13, 12, 13), Vector3(16, 24, 0), fur],
		[Vector3(7, 6, 7), Vector3(24, 21, 0), light],
		[Vector3(2.6, 2.4, 3.4), Vector3(27.6, 22.6, 0), Color(0.08, 0.06, 0.05)],
		[Vector3(4, 4, 3), Vector3(13, 31, -5), fur],
		[Vector3(4, 4, 3), Vector3(13, 31, 5), fur],
		[Vector3(1.6, 2.4, 1.6), Vector3(14.6, 31, -5), light],
		[Vector3(1.6, 2.4, 1.6), Vector3(14.6, 31, 5), light],
	]
	_eyes(head, 22.6, 26, 3.4, Color(0.06, 0.05, 0.05))
	spec[PART_HEAD] = _part(Vector3(12, 22, 0), head)
	return spec

static func _spec_human(apron: Color, shirt: Color, pants: Color, hat: Array, tool: Array) -> Dictionary:
	var skin := Color(0.98, 0.78, 0.64)
	var spec := {}
	for i in range(2):
		var z := -3.4 if i == 0 else 3.4
		var pivot := Vector3(0, 13, z)
		spec["leg%d" % i] = _part(pivot, [
			[Vector3(4.6, 12, 4.4), pivot + Vector3(0, -6, 0), pants],
			[Vector3(6, 2.4, 5), pivot + Vector3(1, -12, 0), Color(0.16, 0.12, 0.1)],
		])
	spec[PART_BODY] = _part(Vector3.ZERO, [
		[Vector3(8, 13, 13), Vector3(0, 19.5, 0), shirt],
		[Vector3(1.4, 12, 10), Vector3(4.4, 18, 0), apron],
		[Vector3(4, 4, 4), Vector3(0, 23, -8.4), shirt],
	])
	var head := [
		[Vector3(9, 9, 9), Vector3(0.5, 30.5, 0), skin],
		[Vector3(1.6, 1.6, 2.4), Vector3(5.2, 29.4, 0), skin.darkened(0.12)],
		[Vector3(1.2, 1.2, 5), Vector3(5.2, 27.4, 0), Color(0.4, 0.22, 0.14)],
	]
	_eyes(head, 5.1, 31.6, 2.2, Color(0.1, 0.1, 0.12))
	head.append_array(hat)
	spec[PART_HEAD] = _part(Vector3(0, 26, 0), head)
	var arm := [[Vector3(4, 10, 4), Vector3(0, 19, 8.4), shirt], [Vector3(3.6, 3.6, 3.6), Vector3(0, 13.4, 8.4), skin]]
	arm.append_array(tool)
	spec["arm"] = _part(Vector3(0, 24, 8.4), arm)
	return spec

static func _spec_butcher() -> Dictionary:
	var white := Color(0.95, 0.95, 0.94)
	var blood := Color(0.7, 0.08, 0.08)
	var hat := [
		[Vector3(10, 2, 10), Vector3(0.5, 35.6, 0), white],
		[Vector3(8, 4, 8), Vector3(0.5, 38.4, 0), white],
	]
	var tool := [
		[Vector3(2, 6, 1.6), Vector3(0, 9.6, 8.4), Color(0.35, 0.2, 0.1)],
		[Vector3(8, 7, 1.2), Vector3(3, 6.4, 8.4), Color(0.82, 0.85, 0.9)],
	]
	var spec := _spec_human(white, Color(0.62, 0.22, 0.22), Color(0.22, 0.24, 0.3), hat, tool)
	(spec[PART_BODY]["boxes"] as Array).append([Vector3(1.6, 3, 3), Vector3(5.2, 16, 2.4), blood])
	(spec[PART_BODY]["boxes"] as Array).append([Vector3(1.6, 2, 2), Vector3(5.2, 21, -2.6), blood])
	return spec

static func _spec_hunter() -> Dictionary:
	var green := Color(0.24, 0.38, 0.2)
	var hat := [
		[Vector3(12, 1.6, 12), Vector3(0.5, 35.2, 0), green.darkened(0.25)],
		[Vector3(8, 4, 8), Vector3(0.5, 37.6, 0), green.darkened(0.15)],
		[Vector3(1, 6, 1), Vector3(-2, 40, 3.4), Color(0.9, 0.3, 0.2)],
	]
	var tool := [
		[Vector3(18, 2.4, 2.4), Vector3(6, 13.4, 8.4), Color(0.12, 0.12, 0.14)],
		[Vector3(7, 3.4, 3), Vector3(-2, 13, 8.4), Color(0.4, 0.24, 0.12)],
	]
	return _spec_human(Color(0.32, 0.25, 0.16), green, Color(0.36, 0.28, 0.18), hat, tool)
