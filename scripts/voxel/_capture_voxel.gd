extends Node3D

## Hilfsszene für Entwurfs-Screenshots der Voxel-Eber (nicht im Spiel benutzt).
## Start: godot --rendering-driver vulkan --path . res://scripts/voxel/_capture_voxel.tscn -- out=/pfad

const SPACING: float = 78.0
var out_dir := "/tmp/voxcap"
var cam: Camera3D
var models: Array[Node3D] = []
var _floor: Node3D
var _platform: Node3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_env()
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 10.0
	cam.far = 6000.0
	add_child(cam)
	cam.current = true
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3000, 1200)
	floor_mi.mesh = pm
	floor_mi.material_override = ArenaTextures.make_floor_material("grass", Color(0.38, 0.58, 0.3), 36.0)
	add_child(floor_mi)
	_floor = floor_mi
	# Plattform für die Seitenansicht (wie ein Level-Block mit Graskante)
	_platform = Node3D.new()
	add_child(_platform)
	var dirt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3000, 60, 70)
	dirt.mesh = bm
	dirt.position = Vector3(0, -30, 0)
	dirt.material_override = ArenaTextures.make_material("rock", Color(0.5, 0.4, 0.32), 36.0)
	_platform.add_child(dirt)
	var grass := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(3000, 6, 72)
	grass.mesh = gm
	grass.position = Vector3(0, -3, 0)
	grass.material_override = ArenaTextures.make_material("grass", Color(0.4, 0.62, 0.3), 36.0)
	_platform.add_child(grass)

	var variants: Array = [["old", ""], ["Grundkörper", ""], ["Schlank", ""], ["Kräftig", ""], ["Keiler", ""], ["Frischling", ""]]
	var classes: Array = [["Grundkörper", "ignis"], ["Grundkörper", "volt"], ["Schlank", "spore"], ["Grundkörper", "nova"], ["Kräftig", "klinge"], ["Kräftig", "bastion"], ["Schlank", "phantom"], ["Keiler", "druide"]]
	var colors: Array = [Color(0.91, 0.60, 0.67), Color(0.25, 0.35, 0.8)]
	for set_def in [["varianten", variants], ["klassen", classes]]:
		_spawn(set_def[1])
		for view in ["arena", "seite", "profil", "lauf"]:
			_place(view)
			await _settle()
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, set_def[0], view])
	# Nahaufnahme Grundkörper
	_spawn([["Grundkörper", ""], ["Keiler", ""]])
	_place("nah")
	await _settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/nah.png" % out_dir)
	get_tree().quit()

func _settle() -> void:
	for i in range(3):
		await get_tree().process_frame

func _spawn(defs: Array) -> void:
	for m in models:
		m.queue_free()
	models.clear()
	var i := 0
	for d in defs:
		var preset: String = d[0]
		var hero: String = d[1]
		var n: Node3D
		if preset == "old":
			var vp := VoxelPig.new()
			add_child(vp)
			vp.build(Color(0.91, 0.60, 0.67), Color(0.25, 0.35, 0.8), Color(1.0, 0.85, 0.3), 1.0, hero)
			vp.animate(0.016, false, false, 1.0)
			n = vp
		else:
			var vb := VoxelBoar.new()
			add_child(vb)
			vb.build(VoxelBoar.preset_spec(preset, {"outfit": hero}))
			vb.animate(0.0, false, false, 1.0)
			n = vb
		n.set_meta("idx", i)
		models.append(n)
		i += 1

func _place(view: String) -> void:
	var count := models.size()
	var spacing := 62.0 if count <= 6 else 56.0
	var w := spacing * (count - 1)
	for m in models:
		var i: int = m.get_meta("idx")
		m.position = Vector3(-w * 0.5 + spacing * i, 0, 0)
		m.rotation = Vector3.ZERO
		m.scale = Vector3.ONE
		if m is VoxelBoar:
			if view == "lauf":
				(m as VoxelBoar).pose_walk(0.25 + 0.17 * i)
			else:
				(m as VoxelBoar).pose_walk(0.0)
				(m as VoxelBoar)._walk_amount = 0.0
				(m as VoxelBoar).animate(0.0, false, false, 1.0)
	var side := view in ["seite", "profil", "lauf"]
	_floor.visible = not side
	_platform.visible = side
	var target := Vector3(0, 22, 0)
	var dist := 2000.0
	match view:
		"arena":
			var tilt := deg_to_rad(55.0)
			for m in models:
				m.rotation.y = deg_to_rad(-60.0)   # schaut nach rechts unten (zur Kamera)
				m.scale = Vector3.ONE * 1.45 if m is VoxelPig else Vector3.ONE * 1.3
			cam.size = (w + 120.0) * 0.5625 / 0.82
			cam.global_position = target + Vector3(0, sin(tilt), cos(tilt)) * dist
			cam.look_at(target, Vector3.UP)
		"seite", "lauf":
			for m in models:
				m.rotation.y = deg_to_rad(-45.0)   # Dreiviertel, schaut nach rechts
			cam.size = (w + 70.0) * 0.5625
			var sdir := Vector3(0.0, 0.18, 1.0).normalized()
			cam.global_position = Vector3(0, 26, 0) + sdir * dist
			cam.look_at(Vector3(0, 26, 0), Vector3.UP)
		"profil":
			cam.size = (w + 80.0) * 0.5625
			cam.global_position = Vector3(0, 24, dist)
			cam.look_at(Vector3(0, 24, 0), Vector3.UP)
		"nah":
			for m in models:
				m.rotation.y = deg_to_rad(-38.0)
			cam.size = 70.0
			var dir := Vector3(0.0, 0.35, 1.0).normalized()
			cam.global_position = Vector3(0, 26, 0) + dir * dist
			cam.look_at(Vector3(0, 26, 0), Vector3.UP)

func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.7, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.75, 0.96)
	env.ambient_light_energy = 0.7
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
	sun.directional_shadow_max_distance = 4000.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	add_child(sun)
