extends "res://scripts/voxel/_capture_voxel.gd"

## Screenshots männlich/weiblich (nicht im Spiel benutzt).
## Start: godot --rendering-driver vulkan --path . res://scripts/voxel/_capture_gender.tscn -- out=/pfad

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
	_platform = Node3D.new()
	add_child(_platform)
	var specs: Array = [
		{"gender": "male"},
		{"gender": "female"},
		{"gender": "female", "top": "robe", "top_color": Color(0.35, 0.75, 0.95)},
		{"gender": "female", "body": "slim", "bottom": "skirt", "top": "muscle", "top_color": Color(0.95, 0.85, 0.3)},
		{"gender": "female", "body": "strong", "outfit": "bastion", "top": "bikini", "top_color": Color(0.9, 0.3, 0.4)},
		{"gender": "female", "outfit": "ignis", "head": "big", "pants": Color(0.6, 0.2, 0.5)},
	]
	for m in models:
		m.queue_free()
	models.clear()
	var i := 0
	for sp in specs:
		var vb := VoxelBoar.new()
		add_child(vb)
		vb.build(sp)
		vb.animate(0.0, false, false, 1.0)
		vb.set_meta("idx", i)
		models.append(vb)
		i += 1
	for view in ["seite", "profil", "lauf", "arena"]:
		_place(view)
		await _settle()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/gender_%s.png" % [out_dir, view])
	_place("nah")
	cam.size = 110.0
	await _settle()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/gender_nah.png" % out_dir)
	# Großaufnahmen: nur Grundkörper männlich/weiblich, vorn und im Profil.
	for k in range(models.size()):
		models[k].visible = k < 3
	for v in [["front", -80.0, Vector3(0.0, 0.2, 1.0)], ["profil_nah", 0.0, Vector3(0.0, 0.05, 1.0)], ["dreiviertel", -45.0, Vector3(0.0, 0.25, 1.0)]]:
		for k in range(3):
			var m: Node3D = models[k]
			m.position = Vector3(-70.0 + 70.0 * k, 0, 0)
			m.rotation = Vector3(0, deg_to_rad(v[1]), 0)
		cam.size = 120.0
		var dir: Vector3 = (v[2] as Vector3).normalized()
		cam.global_position = Vector3(0, 22, 0) + dir * 2000.0
		cam.look_at(Vector3(0, 22, 0), Vector3.UP)
		await _settle()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/gender_%s.png" % [out_dir, v[0]])
	get_tree().quit()
