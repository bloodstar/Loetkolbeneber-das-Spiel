extends Node2D

## Erstellt Übersichtsbilder aller Maps (braucht einen echten Renderer):
##   godot --rendering-driver opengl3 res://tools/level_screenshot.tscn -- --out=/pfad
## Je Map entsteht <map>.png mit der kompletten Karte.

func _ready() -> void:
	var out_dir := "user://level_shots"
	var maps: Array = Array(Global.MAP_PLAYABLE)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--maps="):
			maps = Array(a.substr(7).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var gen: LevelGenerator = load("res://scenes/level/procedural_level.tscn").instantiate()
	add_child(gen)
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	for map_id in maps:
		gen.generate_level(4242, str(map_id), [] as Array[String])
		var size := gen.get_map_pixel_size()
		var vp_size := get_viewport().get_visible_rect().size
		var z := minf(vp_size.x / (size.x + 80.0), vp_size.y / (size.y + 80.0))
		cam.zoom = Vector2(z, z)
		cam.position = size * 0.5
		for i in range(20):
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [out_dir, map_id]
		img.save_png(path)
		print("saved ", path)
	get_tree().quit()
