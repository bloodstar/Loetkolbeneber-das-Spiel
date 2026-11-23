extends Node

## Laufzeit-Test für Schalter, Türen, Falltüren, Laser und Orbitalschläge.
## Aufruf: godot --headless res://tools/switch_runtime_test.tscn

var failures: Array[String] = []
var main: Node
var p1: Player
var p2: Player

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   " + msg)
	else:
		print("  FAIL " + msg)
		failures.append(msg)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _of_type(level: Node, script_class) -> Array:
	var out: Array = []
	for c in level.get_children():
		if is_instance_of(c, script_class):
			out.append(c)
	return out

func _start(map_id: String) -> LevelGenerator:
	main._start_fresh_round(4242, map_id)
	await get_tree().physics_frame
	main.countdown_active = false
	Global.current_state = Global.GameState.PLAYING
	p1 = main.get_player(1)
	p2 = main.get_player(2)
	for p in [p1, p2]:
		if p:
			# Kein Bot, keine Runde durch Tod beenden: viel Leben.
			p.is_bot = false
			p.max_health = 100000.0
			p.current_health = 100000.0
			p.control_enabled = true
			p.global_position = Vector2(60, 60)
			p.velocity = Vector2.ZERO
	return main.level_generator

func _park(p: Player, pos: Vector2) -> void:
	p.global_position = pos
	p.velocity = Vector2.ZERO

func _ready() -> void:
	Global.set_player_count(2)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	add_child(main)
	await _wait(0.3)
	var editor_script = load("res://scripts/level/side_level_editor.gd")
	_check(editor_script != null and editor_script.can_instantiate(), "Karteneditor lädt")

	# --- Map-Aufbau und Snapshots -----------------------------------------
	for map_id in ["falltuerburg", "laserlabor", "schleusenwerk", "grasarena", "neonfabrik", "wollhaus"]:
		print("== %s ==" % map_id)
		var level := await _start(map_id)
		var net: SwitchNetwork = level.switch_network
		var switches := net.get_switches()
		_check(switches.size() >= 2, "Schalter gebaut (%d)" % switches.size())
		var snap_types: Dictionary = {}
		for snap in level.get_moving_object_snapshots():
			snap_types[str(snap.get("type", ""))] = int(snap_types.get(str(snap.get("type", "")), 0)) + 1
		_check(int(snap_types.get("level_switch", 0)) == switches.size(), "Snapshot enthält alle Schalter")
		for sw in switches:
			_check(not net.targets_for(sw.channel).is_empty(), "Schalter Kanal %d hat ein Ziel" % sw.channel)

	# --- Falltür über Hebel (Falltürburg) ---------------------------------
	print("== Falltür und Hebel ==")
	var level := await _start("falltuerburg")
	var net: SwitchNetwork = level.switch_network
	var hatch: SwitchGate = null
	for g in _of_type(level, SwitchGate):
		if g.size_px.x > 300.0:
			hatch = g
	_check(hatch != null and (hatch.channels as Array).size() == 2, "Mittelfalltür hört auf beide Seiten")
	var lever: LevelSwitch = null
	for sw in net.get_switches():
		if sw.kind == "lever" and sw.channel == 0:
			lever = sw
	var r := hatch.get_rect()
	_park(p2, Vector2(r.get_center().x, r.position.y - 14.0))
	_park(p1, Vector2(lever.global_position.x - 120.0, 810.0))
	await _wait(0.4)
	_check(p2.is_on_floor(), "Spieler steht auf der geschlossenen Falltür")
	_check(lever.bot_value(p1, p2) > 0.9, "Bot sieht Wert im Hebel (Gegner auf Falltür): %.1f" % lever.bot_value(p1, p2))
	# Echte Kugel auf den Hebel schießen.
	# Als Bot (ohne Steuerung) übernimmt die Figur keine Mauszielrichtung.
	p1.is_bot = true
	p1.aim_direction = (lever.global_position + Vector2(0, 30) - p1.global_position).normalized()
	p1.shoot()
	await _wait(0.6)
	p1.is_bot = false
	_check(lever.is_on, "Schuss legt den Hebel um")
	_check(hatch.is_open, "Falltür öffnet")
	await _wait(0.5)
	_check(p2.global_position.y > r.end.y + 10.0, "Spieler fällt durch (y %.0f)" % p2.global_position.y)
	await _wait(lever.duration)
	_check(not lever.is_on and lever.cooldown_left > 0.0, "Hebel fällt nach %.0f s zurück und ist gesperrt" % lever.duration)
	await _wait(0.4)
	_check(not hatch.is_open, "Falltür schließt wieder")
	lever.hit_tile(10.0)
	_check(not lever.is_on, "Gesperrter Hebel reagiert nicht")
	# Klemmschutz: Spieler steht im Rahmen, während die Tür schließen will.
	await _wait(lever.cooldown + 0.1)
	lever.hit_tile(10.0)
	await _wait(0.1)
	_park(p2, Vector2(r.get_center().x, r.get_center().y))
	p2.set_physics_process(false)
	await _wait(lever.duration + 0.4)
	_check(hatch.is_open, "Falltür bleibt offen, solange jemand im Rahmen steckt")
	p2.set_physics_process(true)
	_park(p2, Vector2(60, 60))
	await _wait(0.4)
	_check(not hatch.is_open, "Falltür schließt, sobald der Rahmen frei ist")

	# --- Replik ----------------------------------------------------------
	var replica := SwitchGate.new()
	replica.kind = hatch.kind
	replica.size_px = hatch.size_px
	replica.channels = hatch.channels
	replica.is_replica = true
	level.add_child(replica)
	replica.apply_network_state({"id": 0, "type": "switch_gate", "o": true})
	_check(replica.is_open, "Client-Replik übernimmt Türzustand")
	replica.queue_free()
	var sw_rep := LevelSwitch.new()
	sw_rep.is_replica = true
	level.add_child(sw_rep)
	sw_rep.apply_network_state({"on": true, "r": 2.0, "cd": 0.0})
	_check(sw_rep.is_on and is_equal_approx(sw_rep.remaining, 2.0), "Client-Replik übernimmt Schalterzustand")
	sw_rep.hit_tile(10.0)
	_check(sw_rep.is_on, "Client löst selbst nichts aus")
	sw_rep.queue_free()

	# --- Platte und Orbitalschlag ------------------------------------------
	print("== Druckplatte und Orbitalschlag ==")
	var plate: LevelSwitch = null
	for sw in net.get_switches():
		if sw.kind == "plate" and sw.channel == 2:
			plate = sw
	_park(p1, plate.global_position + Vector2(0, -14))
	await _wait(0.3)
	_check(plate.is_on and plate.pressed, "Platte gedrückt, solange man draufsteht")
	var lasers := 0
	for c in get_tree().current_scene.get_children() + main.get_children():
		if c is OrbitalLaser:
			lasers += 1
	_check(lasers >= 1, "Platte feuert Orbitallaser (%d)" % lasers)
	_park(p1, Vector2(60, 60))
	await _wait(plate.duration + 0.3)
	_check(not plate.is_on, "Platte fällt nach dem Verlassen zurück")

	# --- Laser -------------------------------------------------------------
	print("== Laser ==")
	level = await _start("laserlabor")
	net = level.switch_network
	var ground: SwitchLaser = null
	for l in _of_type(level, SwitchLaser):
		if (l.point_a.y > 700.0) and not l.invert:
			ground = l
	_check(ground != null and ground.state == SwitchLaser.State.OFF, "Bodenlaser ist aus")
	var vault := 0
	for l in _of_type(level, SwitchLaser):
		if l.invert and l.state == SwitchLaser.State.ON:
			vault += 1
	_check(vault == 2, "Tresor-Laserwände sind an (%d)" % vault)
	_park(p2, Vector2((ground.point_a.x + ground.point_b.x) * 0.5, 816.0))
	await _wait(0.3)
	var hp_before := p2.current_health
	var g_lever: LevelSwitch = null
	for sw in net.get_switches():
		if sw.channel == 0:
			g_lever = sw
	g_lever.hit_tile(10.0)
	_check(ground.state == SwitchLaser.State.WARN, "Laser warnt zuerst")
	await _wait(SwitchLaser.WARN_TIME + 0.5)
	_check(ground.state == SwitchLaser.State.ON, "Laser feuert nach der Warnung")
	_check(p2.current_health < hp_before, "Laser trifft Spieler (%.0f -> %.0f)" % [hp_before, p2.current_health])
	# Toggle-Hebel schaltet die Tresorwand ab und wieder an.
	var t_lever: LevelSwitch = null
	for sw in net.get_switches():
		if sw.mode == "toggle":
			t_lever = sw
			break
	var wall: SwitchLaser = net.targets_for(t_lever.channel)[0]
	t_lever.hit_tile(10.0)
	_check(wall.state == SwitchLaser.State.OFF, "Toggle-Hebel schaltet Laserwand ab")
	await _wait(SwitchLaser.WARN_TIME)
	t_lever.hit_tile(10.0)
	_check(not t_lever.is_on, "Zweiter Treffer schaltet zurück")
	await _wait(SwitchLaser.WARN_TIME + 0.1)
	_check(wall.state == SwitchLaser.State.ON, "Laserwand ist wieder an")

	# --- Tür über Platte (Schleusenwerk) ------------------------------------
	print("== Schleusentür ==")
	level = await _start("schleusenwerk")
	net = level.switch_network
	var door_plate: LevelSwitch = null
	for sw in net.get_switches():
		if sw.kind == "plate" and sw.channel == 1:
			door_plate = sw
	var door: SwitchGate = net.targets_for(1)[0]
	_check(not door.is_open, "Tür ist zu")
	_park(p1, door_plate.global_position + Vector2(0, -14))
	await _wait(0.3)
	_check(door.is_open, "Platte öffnet die Tür")
	_park(p1, Vector2(60, 60))
	await _wait(door_plate.duration + 0.5)
	_check(not door.is_open, "Tür schließt nach Ablauf")

	# --- Bot schießt auf Hebel ---------------------------------------------
	print("== Bot ==")
	level = await _start("falltuerburg")
	net = level.switch_network
	for sw in net.get_switches():
		if sw.kind == "lever" and sw.channel == 0:
			lever = sw
	for g in _of_type(level, SwitchGate):
		if g.size_px.x > 300.0:
			hatch = g
	r = hatch.get_rect()
	p1.is_bot = true
	var ai := AIController.new()
	ai.player = p1
	p1.add_child(ai)
	ai.target = p2
	# Bot bleibt stehen (Tempo 0), geprüft wird Zielwahl und Schuss.
	p1.move_speed = 0.0
	_park(p1, Vector2(lever.global_position.x - 160.0, 810.0))
	_park(p2, Vector2(r.get_center().x + 60.0, r.position.y - 14.0))
	var opened := false
	for i in range(100):
		_park(p2, Vector2(r.get_center().x + 60.0, p2.global_position.y if p2.global_position.y < r.position.y else r.position.y - 14.0))
		await _wait(0.1)
		if lever.is_on:
			opened = true
			break
	if not opened:
		print("  info bot aim=%s pos=%s lever=%s value=%.1f" % [ai._switch_aim, p1.global_position, lever.global_position, lever.bot_value(p1, p2)])
	_check(opened, "Bot schießt den Hebel, wenn der Gegner auf der Falltür steht")
	ai.queue_free()
	p1.is_bot = false

	print("SWITCH_TEST_DONE failures=%d" % failures.size())
	get_tree().quit(failures.size())
