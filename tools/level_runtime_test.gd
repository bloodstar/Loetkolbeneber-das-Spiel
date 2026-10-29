extends Node

## Laufzeit-Test für Bewegungs- und Drehplattformen und Scroll-Kamera.
## Aufruf: godot --headless res://tools/level_runtime_test.tscn

var failures: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   " + msg)
	else:
		print("  FAIL " + msg)
		failures.append(msg)

func _ready() -> void:
	Global.set_player_count(2)
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	for map_id in ["uhrwerk", "pilzpfad", "gletscherpass", "wolkeninsel", "grasarena"]:
		print("== %s ==" % map_id)
		main._start_fresh_round(4242, map_id)
		await get_tree().physics_frame
		var level: LevelGenerator = main.level_generator
		_check(level.current_map_id == map_id, "Map gebaut")
		var scrolling := level.is_scrolling_map()
		_check(main.camera.scroll_mode == scrolling, "Kamera-Modus passt (scroll=%s)" % scrolling)
		if scrolling:
			_check(main.camera.limit_right == int(level.get_map_pixel_size().x + 140.0), "Kamera-Grenze rechts = Kartenbreite")
		var movers: Array = []
		for c in level.get_children():
			if c is MovingPlatform:
				movers.append(c)
		var snaps: Array = level.get_moving_object_snapshots()
		var mover_snaps := 0
		for snap in snaps:
			if str(snap.get("type", "")) == "moving_platform":
				mover_snaps += 1
		_check(mover_snaps == movers.size(), "Snapshot enthält alle %d Bewegungsplattformen" % movers.size())
		if movers.is_empty():
			continue
		# Spieler 1 auf die erste Plattform stellen und mitfahren lassen.
		var mover: MovingPlatform = movers[0]
		var p1: Player = main.get_player(1)
		var p2: Player = main.get_player(2)
		if p2:
			p2.global_position = Vector2(60, 60)
		var start_body: Vector2 = mover.body.global_position
		p1.velocity = Vector2.ZERO
		p1.global_position = start_body + Vector2(0, -7.0 - 13.0)
		await get_tree().create_timer(0.25).timeout
		var rel_before: Vector2 = p1.global_position - mover.body.global_position
		await get_tree().create_timer(1.5).timeout
		var moved: float = mover.body.global_position.distance_to(start_body)
		var rel_after: Vector2 = p1.global_position - mover.body.global_position
		_check(moved > 20.0, "Plattform bewegt sich (%.0f px)" % moved)
		_check(rel_after.distance_to(rel_before) < 14.0, "Spieler fährt mit (Abweichung %.1f px)" % rel_after.distance_to(rel_before))
		_check(p1.is_on_floor(), "Spieler steht auf der Plattform")
		# Replik auf dem Client: Phase aus dem Snapshot übernehmen.
		var replica: MovingPlatform = load("res://scenes/level/moving_platform.tscn").instantiate()
		replica.travel = mover.travel
		replica.period = mover.period
		replica.platform_width = mover.platform_width
		replica.is_replica = true
		replica.position = mover.position
		level.add_child(replica)
		replica.apply_network_state(mover.get_network_state())
		_check(replica.body.global_position.distance_to(mover.body.global_position) < 6.0, "Client-Replik übernimmt Position aus Snapshot (%.1f px, %s vs %s)" % [replica.body.global_position.distance_to(mover.body.global_position), replica.body.global_position, mover.body.global_position])
		_check(replica.body.collision_layer == 0, "Client-Replik kollidiert nicht")
		replica.queue_free()
	for map_id in ["uhrwerk", "kugellawine", "kugelmuehle"]:
		print("== %s (Drehbalken) ==" % map_id)
		main._start_fresh_round(4242, map_id)
		await get_tree().physics_frame
		var level: LevelGenerator = main.level_generator
		var rotors: Array = []
		for c in level.get_children():
			if c is RotatingPlatform:
				rotors.append(c)
		_check(not rotors.is_empty(), "Map hat Drehbalken (%d)" % rotors.size())
		if rotors.is_empty():
			continue
		var rotor_snaps := 0
		for snap in level.get_moving_object_snapshots():
			if str(snap.get("type", "")) == "rotating_platform":
				rotor_snaps += 1
		_check(rotor_snaps == rotors.size(), "Snapshot enthält alle Drehbalken")
		var rotor: RotatingPlatform = rotors[0]
		var angle_before: float = rotor.body.rotation
		await get_tree().create_timer(0.5).timeout
		var turned: float = absf(angle_difference(angle_before, rotor.body.rotation))
		_check(turned > 0.05, "Balken dreht sich (%.2f rad in 0,5 s)" % turned)
		var replica := RotatingPlatform.new()
		replica.arm_length = rotor.arm_length
		replica.tail_length = rotor.tail_length
		replica.period = rotor.period
		replica.phase = rotor.phase
		replica.spokes = rotor.spokes
		replica.is_replica = true
		replica.position = rotor.position
		level.add_child(replica)
		replica.apply_network_state(rotor.get_network_state())
		_check(absf(angle_difference(replica.body.rotation, rotor.body.rotation)) < 0.02, "Client-Replik übernimmt Winkel aus Snapshot")
		_check(replica.body.collision_layer == 0, "Client-Replik kollidiert nicht")
		replica.queue_free()
	print("RUNTIME_TEST_DONE failures=%d" % failures.size())
	get_tree().quit(failures.size())
