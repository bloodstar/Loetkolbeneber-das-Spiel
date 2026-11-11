class_name ArenaView3D
extends Node3D

# 3D-Voxel-Ansicht der Arena. Spiegelt die 2D-Simulation:
#   2D (x, y) + Höhe z  ->  3D (x, z, y)   (Einheit: Pixel, 1 Tile = 36)
# Die 2D-Kamera (DynamicCamera) bleibt führend und ist in y um
# sin(TILT) gestaucht. Die orthografische 3D-Kamera schaut im selben
# Winkel auf denselben Bodenpunkt, dadurch liegen 2D-Effekte (Explosionen,
# Zonen, Powerups, Schadenszahlen, Kugeln) passgenau auf dem 3D-Boden.
# Kugeln bleiben 2D-Leuchtkugeln und werden um ihre Höhe versetzt gezeichnet.

const CAMERA_DISTANCE: float = 3000.0
# Voxel-Schwein etwas größer als die Kollisionsbox, damit es gut lesbar ist.
const PIG_SCALE: float = 1.45
# Sichtbare Dicke der Stege.
const STEG_VIS: float = 14.0

var camera_2d: Camera2D = null
var cam: Camera3D
var _pigs: Dictionary = {}        # Player-Instanz-ID -> VoxelPig
var _crates: Dictionary = {}      # Vector2i -> Node3D
var _shadow_mat: StandardMaterial3D
var _shadow_mesh: PlaneMesh
var _contact_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()

func setup(map_data: Dictionary, grid: ArenaGrid, cam2d: Camera2D) -> void:
	camera_2d = cam2d
	_rng.seed = 4242
	_build_environment(map_data)
	_build_floor(map_data, grid)
	_build_blocks(map_data, grid)
	_build_border(map_data, grid)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 10.0
	cam.far = CAMERA_DISTANCE * 2.0
	add_child(cam)
	cam.current = true
	_shadow_mesh = PlaneMesh.new()
	_shadow_mesh.size = Vector2(46.0, 46.0)
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_texture = ArenaTextures.get_soft_blob()
	_shadow_mat.albedo_color = Color(0.02, 0.04, 0.1, 0.55)

func _build_environment(_map_data: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.07)
	# Kühles Himmelslicht von überall, warme Sonne von schräg oben: Schatten
	# werden bläulich statt schwarz, beleuchtete Flächen warm.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.75, 0.96)
	env.ambient_light_energy = 0.7
	# Leichtes Glühen nur für helle, leuchtende Teile (Zauberstab, Randlinie).
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.8
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	add_child(sun)

func _voxel_multimesh(count: int, size: Vector3, mat: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = size
	mm.mesh = box
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	return mmi

## Helligkeits-Tönung um Weiß (die Farbe steckt in der Textur).
func _tint(f: float, amount: float) -> Color:
	var v := clampf(f + _rng.randf_range(-amount, amount), 0.0, 1.0)
	return Color(v, v, v)

func _tex_kind(map_data: Dictionary, key: String, fallback: String) -> String:
	return str(map_data.get(key, fallback))

func _build_floor(map_data: Dictionary, grid: ArenaGrid) -> void:
	var t := grid.tile
	var floor_col: Color = map_data.get("floor", Color(0.4, 0.6, 0.3))
	var mat := ArenaTextures.make_floor_material(_tex_kind(map_data, "floor_tex", "grass"), floor_col, t)
	var mmi := _voxel_multimesh(grid.width * grid.height, Vector3(t, 10.0, t), mat)
	var i := 0
	for y in range(grid.height):
		for x in range(grid.width):
			var xf := Transform3D(Basis(), Vector3((x + 0.5) * t, -5.0, (y + 0.5) * t))
			mmi.multimesh.set_instance_transform(i, xf)
			# Die Farbvariation macht das Bodenmaterial (weich, ohne Raster).
			mmi.multimesh.set_instance_color(i, Color.WHITE)
			i += 1
	add_child(mmi)

func _build_blocks(map_data: Dictionary, grid: ArenaGrid) -> void:
	var t := grid.tile
	var wall_col: Color = map_data.get("wall", Color(0.6, 0.6, 0.6))
	var cover_col: Color = wall_col.lerp(Color(0.55, 0.45, 0.32), 0.35)
	var wall_mat := ArenaTextures.make_material(_tex_kind(map_data, "wall_tex", "brick"), wall_col, t)
	var cover_mat := ArenaTextures.make_material("rock", cover_col, t)
	var walls: Array = []
	var covers: Array = []
	for cell in grid.blocks.keys():
		if grid.destructible.has(cell) or grid.terrain.has(cell) or grid.stege.has(cell):
			continue
		for b in grid.blocks[cell]:
			var span: Vector2 = b
			var levels := int(round((span.y - span.x) / ArenaMode.BAND_H))
			for k in range(levels):
				var f := 1.0 if k == levels - 1 else 0.9 - 0.05 * float(levels - 1 - k)
				var entry := [Vector3((cell.x + 0.5) * t, span.x + (k + 0.5) * ArenaMode.BAND_H, (cell.y + 0.5) * t), f]
				if span.y <= ArenaMode.BAND_H:
					covers.append(entry)
				else:
					walls.append(entry)
	for pair in [[walls, wall_mat], [covers, cover_mat]]:
		var list: Array = pair[0]
		if list.is_empty():
			continue
		var mmi := _voxel_multimesh(list.size(), Vector3(t, ArenaMode.BAND_H, t), pair[1])
		for i in range(list.size()):
			mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), list[i][0]))
			mmi.multimesh.set_instance_color(i, _tint(list[i][1], 0.04))
		add_child(mmi)
	_build_contact_shadows(grid, walls + covers)
	_build_segments(grid, wall_mat)
	_build_terrain(map_data, grid)
	_build_stege(grid)
	_build_ramps(map_data, grid)
	# Zerstörbare Kisten einzeln, damit sie beim Bruch verschwinden können.
	var crate_mat := ArenaTextures.make_material("wood", Color(0.7, 0.47, 0.25), t)
	for cell in grid.destructible.keys():
		var crate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(t - 2.0, ArenaMode.BAND_H - 2.0, t - 2.0)
		crate.mesh = bm
		crate.material_override = crate_mat
		crate.position = Vector3((cell.x + 0.5) * t, ArenaMode.BAND_H * 0.5, (cell.y + 0.5) * t)
		add_child(crate)
		_crates[cell] = crate
		var skirt := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(t * 2.0, t * 2.0)
		skirt.mesh = pm
		skirt.material_override = _contact_material()
		skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		skirt.position = Vector3(0.0, -ArenaMode.BAND_H * 0.5 + 0.5, 0.0)
		crate.add_child(skirt)

## Kontaktschatten: weicher dunkler Saum am Fuß jedes Blocks. Erdet die
## Würfel auf dem Boden (ersetzt Ambient Occlusion, die der mobile Renderer
## nicht hat).
func _contact_material() -> StandardMaterial3D:
	if _contact_mat == null:
		_contact_mat = StandardMaterial3D.new()
		_contact_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contact_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_contact_mat.albedo_texture = ArenaTextures.get_soft_square()
		_contact_mat.albedo_color = Color(0.02, 0.04, 0.1, 0.3)
	return _contact_mat

func _build_contact_shadows(grid: ArenaGrid, entries: Array) -> void:
	var t := grid.tile
	var cells := {}
	for e in entries:
		var pos: Vector3 = e[0]
		if pos.y < ArenaMode.BAND_H:
			cells[Vector2(pos.x, pos.z)] = true
	for cell in grid.terrain.keys():
		cells[Vector2((cell.x + 0.5) * t, (cell.y + 0.5) * t)] = true
	if cells.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PlaneMesh.new()
	pm.size = Vector2(t * 2.0, t * 2.0)
	mm.mesh = pm
	mm.instance_count = cells.size()
	var i := 0
	for c in cells.keys():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(c.x, 0.5, c.y)))
		i += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _contact_material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _floor_material(map_data: Dictionary, grid: ArenaGrid) -> Material:
	var floor_col: Color = map_data.get("floor", Color(0.4, 0.6, 0.3))
	return ArenaTextures.make_material(_tex_kind(map_data, "floor_tex", "grass"), floor_col, grid.tile)

func _cliff_material(map_data: Dictionary, grid: ArenaGrid) -> Material:
	var wall_col: Color = map_data.get("wall", Color(0.6, 0.6, 0.6))
	var cliff_col: Color = map_data.get("cliff", wall_col.lerp(Color(0.45, 0.36, 0.28), 0.4))
	return ArenaTextures.make_material("rock", cliff_col, grid.tile)

## Erhöhungen: Felswand je Höhenschicht, oben eine dünne Platte mit
## Bodentextur (Grasnarbe), damit man die Fläche als begehbar erkennt.
func _build_terrain(map_data: Dictionary, grid: ArenaGrid) -> void:
	if grid.terrain.is_empty():
		return
	var t := grid.tile
	var sides: Array = []
	var tops: Array = []
	for cell in grid.terrain.keys():
		var top := grid.top_at(cell)
		var levels := int(round(top / ArenaMode.BAND_H))
		for k in range(levels):
			var f := 0.82 + 0.12 * float(k) / maxf(1.0, float(levels - 1))
			sides.append([Vector3((cell.x + 0.5) * t, (k + 0.5) * ArenaMode.BAND_H, (cell.y + 0.5) * t), f])
		# Randkacheln etwas dunkler: Die Kante der Erhöhung bleibt lesbar.
		var rim := false
		for dn in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + dn
			if grid.in_bounds(nb) and not (grid.terrain.has(nb) and grid.top_at(nb) >= top):
				rim = true
		tops.append([Vector3((cell.x + 0.5) * t, top - 2.5, (cell.y + 0.5) * t), 0.8 if rim else 1.0])
	var side_mmi := _voxel_multimesh(sides.size(), Vector3(t, ArenaMode.BAND_H, t), _cliff_material(map_data, grid))
	for i in range(sides.size()):
		side_mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), sides[i][0]))
		side_mmi.multimesh.set_instance_color(i, _tint(sides[i][1], 0.04))
	add_child(side_mmi)
	# Oberseite etwas heller und wärmer als der Boden, damit die Erhöhung
	# auch von oben klar vom Boden absticht.
	var floor_col: Color = map_data.get("floor", Color(0.4, 0.6, 0.3))
	var top_col: Color = map_data.get("top", floor_col.lerp(Color(0.9, 0.85, 0.5), 0.15))
	var top_mat := ArenaTextures.make_material(_tex_kind(map_data, "top_tex", _tex_kind(map_data, "floor_tex", "grass")), top_col, t)
	var top_mmi := _voxel_multimesh(tops.size(), Vector3(t, 6.0, t), top_mat)
	for i in range(tops.size()):
		top_mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), tops[i][0]))
		top_mmi.multimesh.set_instance_color(i, _tint(tops[i][1], 0.04))
	add_child(top_mmi)

## Stege: Holzplanken in Steghöhe, darunter Luft (Pfosten an den Ecken
## wären Hindernisse, daher schweben die Stege zwischen ihren Auflagern).
func _build_stege(grid: ArenaGrid) -> void:
	if grid.stege.is_empty():
		return
	var t := grid.tile
	var mat := ArenaTextures.make_material("planks", Color(0.62, 0.43, 0.26), t)
	var list: Array = []
	# Sichtbar nur die oberen STEG_VIS px (Bohlen), die Kollision belegt das
	# ganze Band darunter, damit man darunter nicht hochspringen kann.
	for cell in grid.stege.keys():
		for b in grid.blocks.get(cell, []):
			var span: Vector2 = b
			list.append(Vector3((cell.x + 0.5) * t, span.y - STEG_VIS * 0.5, (cell.y + 0.5) * t))
	var mmi := _voxel_multimesh(list.size(), Vector3(t, STEG_VIS, t), mat)
	for i in range(list.size()):
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), list[i]))
		mmi.multimesh.set_instance_color(i, _tint(0.95, 0.05))
	add_child(mmi)

## Rampen: je Zelle ein Keil. Die schräge Oberseite trägt die Bodentextur,
## die Seiten die Felswand.
func _build_ramps(map_data: Dictionary, grid: ArenaGrid) -> void:
	if grid.ramps.is_empty():
		return
	var t := grid.tile
	var top_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side_st := SurfaceTool.new()
	side_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell in grid.ramps.keys():
		var r: Dictionary = grid.ramps[cell]
		var d: Vector2i = r["dir"]
		var s0 := float(r["s0"])
		# Höhen an drei Stellen der Zelle (Anfang, Mitte, Ende in Steigrichtung),
		# weil die Rampe eine halbe Kachel vor dem Ende flach wird.
		var hs: Array[float] = [ArenaGrid.ramp_height(r, s0), ArenaGrid.ramp_height(r, s0 + 0.5), ArenaGrid.ramp_height(r, s0 + 1.0)]
		var o := Vector3(cell.x * t, 0.0, cell.y * t)
		for k in range(2):
			var a := float(k) * 0.5
			var b := a + 0.5
			var ha: float = hs[k]
			var hb: float = hs[k + 1]
			# Vier Ecken des Streifens [a, b] in Steigrichtung, über die volle Breite.
			var p := _ramp_quad(o, t, d, a, b)
			var q0: Vector3 = p[0] + Vector3(0, ha, 0)
			var q1: Vector3 = p[1] + Vector3(0, ha, 0)
			var q2: Vector3 = p[2] + Vector3(0, hb, 0)
			var q3: Vector3 = p[3] + Vector3(0, hb, 0)
			_tri2(top_st, q0, q1, q2, q3)
			# Seiten links und rechts (Trapez bis zum Boden).
			_tri2(side_st, p[0], q0, q3, p[3])
			_tri2(side_st, p[1], p[2], q2, q1)
		# Stirnseite am unteren Ende (falls die Rampe nicht am Boden beginnt).
		if s0 == 0.0 and hs[0] > 0.5:
			var p0 := _ramp_quad(o, t, d, 0.0, 0.0)
			_tri2(side_st, p0[0], p0[1], p0[1] + Vector3(0, hs[0], 0), p0[0] + Vector3(0, hs[0], 0))
	for pair in [[top_st, _floor_material(map_data, grid)], [side_st, _cliff_material(map_data, grid)]]:
		var st: SurfaceTool = pair[0]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = pair[1]
		var mat: StandardMaterial3D = (pair[1] as StandardMaterial3D)
		mat.vertex_color_use_as_albedo = false
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		add_child(mi)

## Ecken eines Streifens einer Rampenzelle: von a bis b (0..1) in
## Steigrichtung d. Reihenfolge: links-a, rechts-a, rechts-b, links-b.
func _ramp_quad(o: Vector3, t: float, d: Vector2i, a: float, b: float) -> Array:
	var fwd := Vector3(d.x, 0, d.y)
	var side := Vector3(-d.y, 0, d.x)
	var center := o + Vector3(t * 0.5, 0, t * 0.5)
	var base := center - fwd * t * 0.5
	var l := -side * t * 0.5
	var rr := side * t * 0.5
	return [base + l + fwd * t * a, base + rr + fwd * t * a, base + rr + fwd * t * b, base + l + fwd * t * b]

func _tri2(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)

## Schräge Wände: je Höhenschicht ein gedrehter Quader.
func _build_segments(grid: ArenaGrid, wall_mat: Material) -> void:
	for seg in grid.segments:
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var thick: float = seg["thick"]
		var bottom: float = seg["bottom"]
		var top: float = seg["top"]
		var levels := maxi(1, int(round((top - bottom) / ArenaMode.BAND_H)))
		var length := a.distance_to(b) + thick
		var mid := (a + b) * 0.5
		var angle := (b - a).angle()
		if bottom < 1.0:
			var skirt := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(length + thick * 2.0, thick * 3.0)
			skirt.mesh = pm
			skirt.material_override = _contact_material()
			skirt.position = Vector3(mid.x, 0.5, mid.y)
			skirt.rotation.y = -angle
			add_child(skirt)
		for k in range(levels):
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(length, ArenaMode.BAND_H, thick)
			mi.mesh = bm
			var mat := wall_mat.duplicate() as StandardMaterial3D
			var f := 1.0 if k == levels - 1 else 0.9 - 0.05 * float(levels - 1 - k)
			mat.vertex_color_use_as_albedo = false
			mat.albedo_color = Color(f, f, f)
			mi.material_override = mat
			mi.position = Vector3(mid.x, bottom + (k + 0.5) * ArenaMode.BAND_H, mid.y)
			mi.rotation.y = -angle
			add_child(mi)

func _build_border(map_data: Dictionary, grid: ArenaGrid) -> void:
	# Randmauer als Rahmen. Im Süden (zur Kamera hin) flach, damit sie
	# niemanden verdeckt.
	var t := grid.tile
	var wall_col: Color = (map_data.get("wall", Color(0.6, 0.6, 0.6)) as Color).darkened(0.3)
	var accent: Color = map_data.get("accent", Color(1, 0.5, 0.2))
	var mat := ArenaTextures.make_material(_tex_kind(map_data, "wall_tex", "brick"), wall_col, t)
	var cubes: Array = []
	for x in range(-1, grid.width + 1):
		cubes.append([Vector3((x + 0.5) * t, ArenaMode.BAND_H * 0.5, -0.5 * t), 1.0])
		cubes.append([Vector3((x + 0.5) * t, ArenaMode.BAND_H * 1.5, -0.5 * t), 1.1])
	for y in range(0, grid.height):
		for x in [-1, grid.width]:
			cubes.append([Vector3((x + 0.5) * t, ArenaMode.BAND_H * 0.5, (y + 0.5) * t), 1.0])
			cubes.append([Vector3((x + 0.5) * t, ArenaMode.BAND_H * 1.5, (y + 0.5) * t), 1.1])
	var mmi := _voxel_multimesh(cubes.size(), Vector3(t, ArenaMode.BAND_H, t), mat)
	for i in range(cubes.size()):
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), cubes[i][0]))
		mmi.multimesh.set_instance_color(i, _tint(cubes[i][1], 0.04))
	add_child(mmi)
	# Südkante flach (verdeckt nichts)
	var south := _voxel_multimesh(grid.width + 2, Vector3(t, 10.0, t), mat)
	for x in range(-1, grid.width + 1):
		south.multimesh.set_instance_transform(x + 1, Transform3D(Basis(), Vector3((x + 0.5) * t, 5.0, (grid.height + 0.5) * t)))
		south.multimesh.set_instance_color(x + 1, _tint(1.0, 0.04))
	add_child(south)
	# Leuchtende Kante innen als Markierung der Kartengrenze.
	var mw := grid.width * t
	var mh := grid.height * t
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = accent
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 1.4
	for seg in [
		[Vector3(mw * 0.5, 1.5, 0), Vector3(mw, 3, 4)],
		[Vector3(mw * 0.5, 1.5, mh), Vector3(mw, 3, 4)],
		[Vector3(0, 1.5, mh * 0.5), Vector3(4, 3, mh)],
		[Vector3(mw, 1.5, mh * 0.5), Vector3(4, 3, mh)],
	]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = seg[1]
		mi.mesh = bm
		mi.material_override = glow
		mi.position = seg[0]
		add_child(mi)

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _process(delta: float) -> void:
	_sync_camera()
	_sync_players(delta)
	_sync_crates()

func _sync_camera() -> void:
	if cam == null or camera_2d == null or not is_instance_valid(camera_2d):
		return
	var center := camera_2d.get_screen_center_position()
	var zoom_x := maxf(0.01, camera_2d.zoom.x)
	var vis_h := get_viewport().get_visible_rect().size.y
	cam.size = vis_h / zoom_x
	var tilt := deg_to_rad(ArenaMode.TILT_DEG)
	var target := Vector3(center.x, 0.0, center.y)
	var back := Vector3(0.0, sin(tilt), cos(tilt))
	cam.global_position = target + back * CAMERA_DISTANCE
	cam.look_at(target, Vector3.UP)

func _sync_players(delta: float) -> void:
	var seen := {}
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p):
			continue
		var pid := p.get_instance_id()
		seen[pid] = true
		var pig: VoxelPig = _pigs.get(pid, null)
		if pig == null:
			pig = VoxelPig.new()
			add_child(pig)
			var fur: Color = Color(0.91, 0.60, 0.67)
			var pants: Color = Color(0.25, 0.35, 0.8)
			if p.sprite != null:
				var f = p.sprite.get("fur_color")
				if f is Color:
					fur = f
				var pc = p.sprite.get("pants_color")
				if pc is Color:
					pants = pc
			pig.build(fur, pants, Global.get_team_color(p.team_id), 1.0, Global.get_player_hero_id(p.player_index), p.wand_tip_color)
			var shadow := MeshInstance3D.new()
			shadow.name = "Shadow"
			shadow.mesh = _shadow_mesh
			shadow.material_override = _shadow_mat
			add_child(shadow)
			pig.set_meta("shadow", shadow)
			_pigs[pid] = pig
		var z: float = p.arena_z
		var pos := p.global_position
		pig.visible = p.visible and not p.is_dead
		var size_scale: float = p.scale.x / Player.BASE_CHARACTER_SCALE if Player.BASE_CHARACTER_SCALE > 0.0 else 1.0
		pig.scale = Vector3.ONE * clampf(size_scale, 0.3, 3.0) * PIG_SCALE
		pig.global_position = Vector3(pos.x, z, pos.y)
		var aim := p.aim_direction
		if aim.length_squared() > 0.001:
			pig.rotation.y = -atan2(aim.y, aim.x)
		pig.animate(delta, p.velocity.length() > 30.0, not p.arena_grounded, p.modulate.a, p.velocity, pig.rotation.y, p.arena_vz)
		# Schuss und Treffer aus dem Spielerzustand ablesen (läuft so auch auf
		# Clients, die nur Snapshots bekommen).
		var pool: float = p.current_health + p.current_shield
		var last: Dictionary = pig.get_meta("last", {})
		if not last.is_empty():
			if pool < float(last["pool"]) - 0.5:
				pig.flash()
			if p.current_ammo < int(last["ammo"]) or p.fire_timer > float(last["fire"]) + 0.01:
				pig.recoil(1.0)
		pig.set_meta("last", {"pool": pool, "ammo": p.current_ammo, "fire": p.fire_timer})
		var shadow_node := pig.get_meta("shadow") as MeshInstance3D
		if shadow_node:
			shadow_node.visible = pig.visible
			var ground := 0.0
			if ArenaMode.grid:
				ground = ArenaMode.grid.support_height(pos, z, Vector2(8, 8), 0.5)
			shadow_node.global_position = Vector3(pos.x, ground + 0.8, pos.y)
			# Je höher die Figur über dem Boden, desto kleiner und blasser.
			var lift := clampf((z - ground) / 120.0, 0.0, 1.0)
			shadow_node.scale = Vector3.ONE * pig.scale.x / PIG_SCALE * lerpf(1.0, 0.6, lift)
	for pid in _pigs.keys():
		if not seen.has(pid):
			var pig: VoxelPig = _pigs[pid]
			var sh = pig.get_meta("shadow")
			if sh is Node:
				(sh as Node).queue_free()
			pig.queue_free()
			_pigs.erase(pid)

func _sync_crates() -> void:
	var lg := get_parent().get_node_or_null("ProceduralLevel") as LevelGenerator
	if lg == null or ArenaMode.grid == null:
		return
	for cell in _crates.keys():
		var tile_id: int = ArenaMode.grid.destructible.get(cell, -1)
		var tile := lg.get_special_tile(tile_id) as SpecialTile
		var broken := tile == null or not is_instance_valid(tile) or tile.is_broken
		var crate: Node3D = _crates[cell]
		if broken and crate.visible:
			crate.visible = false
			ArenaMode.grid.clear_cell(cell)
