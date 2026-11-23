extends Node

## Mockup-Aufnahme: echtes Seitenansicht-Match (Bots), einmal mit den
## 2D-Schweinen und einmal mit Voxel-Ebern darübergelegt. Die 2D-Welt wird
## per Environment.BG_CANVAS als Hintergrund der 3D-Szene gezeichnet.
## Nur für Entwürfe, nicht im Spiel benutzt.

const PRESETS_CYCLE: Array[String] = ["Grundkörper", "Kräftig", "Schlank", "Keiler"]
const BOAR_SCALE: float = 1.12
var out_dir := "/tmp/voxcap"
var map_id := "sonnentempel"
var wait_s := 6.0
var main: Node
var overlay: Node3D
var cam: Camera3D
var boars: Dictionary = {}

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
		elif a.begins_with("map="):
			map_id = a.substr(4)
		elif a.begins_with("wait="):
			wait_s = float(a.substr(5))
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	Global.set_player_count(4)
	Global.set_bot_test_mode(true)
	Global.set_game_mode("side")
	Global.selected_map_id = map_id
	main.main_menu.close_menu()
	main._on_menu_start_requested()
	await get_tree().process_frame
	main._on_lobby_confirmed()
	await get_tree().create_timer(wait_s).timeout
	Engine.time_scale = 0.0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/ingame_%s_2d.png" % [out_dir, map_id])
	_build_overlay()
	for i in range(3):
		_sync(0.016)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/ingame_%s_voxel.png" % [out_dir, map_id])
	get_tree().quit()

func _build_overlay() -> void:
	overlay = Node3D.new()
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(overlay)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.76, 0.95)
	env.ambient_light_energy = 0.75
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	overlay.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	overlay.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 1.0
	cam.far = 4000.0
	overlay.add_child(cam)
	cam.current = true
	var i := 0
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null:
			continue
		var b := VoxelBoar.new()
		overlay.add_child(b)
		var fur: Color = p.sprite.get("fur_color")
		var pants: Color = p.sprite.get("pants_color")
		b.build(VoxelBoar.preset_spec(PRESETS_CYCLE[i % PRESETS_CYCLE.size()], {
			"outfit": Global.get_player_hero_id(p.player_index),
			"pants": pants, "fur": fur if i % 4 != 3 else Color(0.47, 0.33, 0.25),
			"accent": Global.get_team_color(p.team_id), "tip": p.wand_tip_color}))
		boars[p] = b
		p.sprite.visible = false
		var wand := p.get_node_or_null("WeaponPivot")
		if wand:
			wand.visible = false
		i += 1
	# Alle übrigen 2D-Schweine (Dash-Geister, Klone) ebenfalls ausblenden
	for n in get_tree().root.find_children("*", "Node2D", true, false):
		if n is PigCharacter:
			(n as Node2D).visible = false

func _sync(delta: float) -> void:
	var cam2d := get_viewport().get_camera_2d()
	if cam2d:
		var c := cam2d.get_screen_center_position()
		cam.size = get_viewport().get_visible_rect().size.y / maxf(0.01, cam2d.zoom.y)
		cam.position = Vector3(c.x, -c.y, 1000.0)
	for key in boars.keys():
		if not is_instance_valid(key):
			continue
		var p: Player = key
		var b: VoxelBoar = boars[key]
		b.visible = p.visible and not p.is_dead
		var feet := p.global_position + Vector2(0, 12.0 * p.scale.y)
		b.position = Vector3(feet.x, -feet.y, 0.0)
		b.scale = Vector3.ONE * BOAR_SCALE * p.scale.x / Player.BASE_CHARACTER_SCALE
		var left: bool = p.sprite.flip_h
		b.rotation.y = deg_to_rad(225.0 if left else -45.0)
		b.animate(delta, absf(p.velocity.x) > 30.0, not p.is_on_floor(), 1.0)
