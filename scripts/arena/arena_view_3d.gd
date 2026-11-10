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
const PIG_SCALE: float = 1.3

var camera_2d: Camera2D = null
var cam: Camera3D
var _pigs: Dictionary = {}        # Player-Instanz-ID -> VoxelPig
var _crates: Dictionary = {}      # Vector2i -> Node3D
var _shadow_mat: StandardMaterial3D
var _shadow_mesh: CylinderMesh
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
	_shadow_mesh = CylinderMesh.new()
	_shadow_mesh.top_radius = 12.0
	_shadow_mesh.bottom_radius = 12.0
	_shadow_mesh.height = 0.5
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.3)

func _build_environment(map_data: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	var floor_col: Color = map_data.get("floor", Color(0.4, 0.6, 0.3))
	env.background_color = Color(0.03, 0.035, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.9)
	env.ambient_light_energy = 0.45
	# Leichtes Glühen nur für helle, leuchtende Teile (Zauberstab, Randlinie).
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = CAMERA_DISTANCE * 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-58.0, -35.0, 0.0)
	add_child(sun)

func _voxel_multimesh(count: int, size: Vector3) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	box.size = size
	mm.mesh = box
	mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mmi.material_override = mat
	return mmi

func _jitter(c: Color, amount: float) -> Color:
	var f := _rng.randf_range(-amount, amount)
	return Color(clampf(c.r + f, 0, 1), clampf(c.g + f, 0, 1), clampf(c.b + f, 0, 1))

func _build_floor(map_data: Dictionary, grid: ArenaGrid) -> void:
	var t := grid.tile
	var floor_col: Color = map_data.get("floor", Color(0.4, 0.6, 0.3))
	var mmi := _voxel_multimesh(grid.width * grid.height, Vector3(t, 10.0, t))
	var i := 0
	for y in range(grid.height):
		for x in range(grid.width):
			var xf := Transform3D(Basis(), Vector3((x + 0.5) * t, -5.0, (y + 0.5) * t))
			mmi.multimesh.set_instance_transform(i, xf)
			var c := floor_col
			if (x + y) % 2 == 0:
				c = c.darkened(0.06)
			mmi.multimesh.set_instance_color(i, _jitter(c, 0.025))
			i += 1
	add_child(mmi)

func _build_blocks(map_data: Dictionary, grid: ArenaGrid) -> void:
	var t := grid.tile
	var wall_col: Color = map_data.get("wall", Color(0.6, 0.6, 0.6))
	var cover_col: Color = wall_col.lerp(Color(0.55, 0.45, 0.32), 0.35)
	var cubes: Array = []
	for cell in grid.blocks.keys():
		if grid.destructible.has(cell):
			continue
		for b in grid.blocks[cell]:
			var span: Vector2 = b
			var levels := int(round((span.y - span.x) / ArenaMode.BAND_H))
			for k in range(levels):
				var col := cover_col if span.y <= ArenaMode.BAND_H else wall_col
				if k == levels - 1:
					col = col.lightened(0.12) # hellere Deckschicht
				cubes.append([Vector3((cell.x + 0.5) * t, span.x + (k + 0.5) * ArenaMode.BAND_H, (cell.y + 0.5) * t), col])
	var mmi := _voxel_multimesh(cubes.size(), Vector3(t, ArenaMode.BAND_H, t))
	for i in range(cubes.size()):
		mmi.multimesh.set_instance_transform(i, Transform3D(Basis(), cubes[i][0]))
		mmi.multimesh.set_instance_color(i, _jitter(cubes[i][1], 0.03))
	add_child(mmi)
	# Zerstörbare Kisten einzeln, damit sie beim Bruch verschwinden können.
	for cell in grid.destructible.keys():
		var crate := Node3D.new()
		crate.position = Vector3((cell.x + 0.5) * t, 0.0, (cell.y + 0.5) * t)
		var wood := Color(0.62, 0.42, 0.22)
		_add_box(crate, Vector3(t - 2.0, ArenaMode.BAND_H - 2.0, t - 2.0), Vector3(0, ArenaMode.BAND_H * 0.5, 0), _jitter(wood, 0.04))
		_add_box(crate, Vector3(t * 0.5, 3.0, t + 0.5), Vector3(0, ArenaMode.BAND_H - 1.0, 0), wood.darkened(0.3))
		_add_box(crate, Vector3(t + 0.5, 3.0, t * 0.5), Vector3(0, ArenaMode.BAND_H - 1.0, 0), wood.darkened(0.3))
		add_child(crate)
		_crates[cell] = crate

func _build_border(map_data: Dictionary, grid: ArenaGrid) -> void:
	# Randmauer als Rahmen. Im Süden (zur Kamera hin) flach, damit sie
	# niemanden verdeckt.
	var t := grid.tile
	var wall_col: Color = (map_data.get("wall", Color(0.6, 0.6, 0.6)) as Color).darkened(0.25)
	var accent: Color = map_data.get("accent", Color(1, 0.5, 0.2))
	var cubes: Array = []
	for x in range(-1, grid.width + 1):
		for y in [-1, grid.height]:
			var h := ArenaMode.BAND_H * 2.0 if y < 0 else 10.0
			cubes.append([Vector3((x + 0.5) * t, h * 0.5, (y + 0.5) * t), Vector3(t, h, t)])
	for y in range(0, grid.height):
		for x in [-1, grid.width]:
			cubes.append([Vector3((x + 0.5) * t, ArenaMode.BAND_H, (y + 0.5) * t), Vector3(t, ArenaMode.BAND_H * 2.0, t)])
	for c in cubes:
		_add_box(self, c[1], c[0], _jitter(wall_col, 0.03))
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
			pig.build(fur, pants, Global.get_team_color(p.team_id), 1.0)
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
		pig.animate(delta, p.velocity.length() > 30.0, not p.arena_grounded, p.modulate.a)
		var shadow_node := pig.get_meta("shadow") as MeshInstance3D
		if shadow_node:
			shadow_node.visible = pig.visible
			var ground := 0.0
			if ArenaMode.grid:
				ground = ArenaMode.grid.support_height(pos, z, Vector2(8, 8), 0.5)
			shadow_node.global_position = Vector3(pos.x, ground + 0.6, pos.y)
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
