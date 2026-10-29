class_name NetFx
extends RefCounted

# Kurze Optik- und Toneffekte (Heldenfähigkeiten, Explosionen, Treffer-Funken).
# Sie entstehen nur dort, wo das Spiel simuliert wird (Offline, Host).
# emit() spielt den Effekt lokal ab und schickt ihn online an alle Clients,
# dort spielt main.gd ihn über play() nach. Es wird nur Optik und Ton
# übertragen, Schaden und Physik bleiben beim Host.
#
# Effekte:
#   "ring"        wachsender, ausblendender Kreis
#   "zap"         Linie/Blitz von "from" nach "to"
#   "blade_storm" Klingenwirbel von Klinge
#   "sound"       nur Ton/Kamerawackeln
#   "pickup"      Aufnahme-Ring eines Powerups
#   "laser"       Orbitallaser (Modifier), auf Clients ohne Schaden
#   "meteor"      Meteorit (Modifier), auf Clients ohne Schaden
#   "static"      Animation eines festen Map-Objekts (Sprungfeld, Trampolin,
#                 Kachel): Gruppe "net_fx_static", gefunden über die Position
#   "mobj"        Animation eines beweglichen Map-Objekts über seine net_id
#   "pfx"         Spieler-Effekt (Treffer-, Heil-, Powerup-Blitz) über den Slot
#   "plasma"      roter Plasma-Schlag an der Gummiwand ("p" Punkt, "d" ins Feld)
# Jeder Effekt kann zusätzlich "snd" = [key, pitch_range, volume_db] und
# "shake" = Stärke mitbringen. "x" = Slot, dessen Rechner den Effekt schon
# selbst vorhersagt (eigener Schuss/Sprung), "o" = nur dieser Slot.

const EFFECT_CIRCLE_TEXTURE: Texture2D = preload("res://assets/projectiles/effect_circle.png")

static func emit(parent: Node, fx: String, args: Dictionary = {}) -> void:
	play(parent, fx, args)
	send(fx, args)

# Nur an die Clients schicken (der Host hat den Effekt schon selbst erzeugt).
static func send(fx: String, args: Dictionary = {}) -> void:
	if Global.network_mode and NetworkManager.is_host:
		NetworkManager.send_fx(fx, args)

static func play(parent: Node, fx: String, args: Dictionary) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var snd = args.get("snd", null)
	if snd is Array and snd.size() >= 3:
		SoundManager.play_sound(str(snd[0]), float(snd[1]), float(snd[2]))
	var shake := float(args.get("shake", 0.0))
	if shake > 0.0:
		Global.shake_camera(shake)
	match fx:
		"ring":
			_ring(parent, args)
		"zap":
			_zap(parent, args)
		"blade_storm":
			_blade_storm(parent, args)
		"pickup":
			_pickup(parent, args)
		"plasma":
			_plasma(parent, args)
		"laser":
			var laser := OrbitalLaser.new()
			var no_players: Array[Player] = []
			laser.setup(args.get("a", Vector2.ZERO), args.get("b", Vector2.ZERO), no_players)
			laser.add_to_group("round_effect")
			parent.add_child(laser)
		"meteor":
			var meteor := MeteorHazard.new()
			var no_targets: Array[Player] = []
			meteor.setup(args.get("p", Vector2.ZERO), no_targets)
			meteor.add_to_group("round_effect")
			parent.add_child(meteor)
		"static":
			_call_static(parent, args)
		"mobj":
			var level = parent.get("level_generator")
			if level != null and is_instance_valid(level):
				var obj = level.get_moving_object(int(args.get("id", -1)))
				if obj != null and obj.has_method("play_network_fx"):
					obj.play_network_fx(str(args.get("m", "")))
		"pfx":
			if parent.has_method("get_player"):
				var p = parent.get_player(int(args.get("s", 0)))
				if p != null and is_instance_valid(p):
					p.play_network_player_fx(str(args.get("m", "")), args.get("a", []))

# --- Bausteine ---

# Argumente für einen Kreis: Position, Farbe, Start-/Endskalierung,
# Wachs- und Ausblendzeit, z_index, smooth = weich auslaufend.
static func ring_args(pos: Vector2, color: Color, from_scale: float, to_scale: float,
		grow_time: float, fade_time: float, z: int = 0, smooth: bool = false) -> Dictionary:
	return {"p": pos, "c": color, "s0": from_scale, "s1": to_scale,
		"t": grow_time, "f": fade_time, "z": z, "e": smooth}

static func zap_args(from_pos: Vector2, to_pos: Vector2, color: Color, width: float,
		fade_time: float, segments: int = 1, jitter: float = 0.0) -> Dictionary:
	return {"from": from_pos, "to": to_pos, "c": color, "w": width,
		"f": fade_time, "n": segments, "j": jitter}

# Hängt einen Ton an die Argumente eines Effekts.
static func with_sound(args: Dictionary, key: String, pitch_range: float, volume_db: float) -> Dictionary:
	args["snd"] = [key, pitch_range, volume_db]
	return args

# Feste Map-Objekte entstehen auf Host und Client aus demselben Seed an
# derselben Stelle; die Position identifiziert sie.
static func static_args(node: Node2D, method: String) -> Dictionary:
	return {"p": node.global_position, "m": method}

# Bewegliche Map-Objekte (Kisten, Kugeln, Sperren) über ihre net_id.
static func mobj_args(obj: Node, method: String) -> Dictionary:
	return {"id": int(obj.get("net_id")), "m": method}

static func _call_static(parent: Node, args: Dictionary) -> void:
	var pos: Vector2 = args.get("p", Vector2.ZERO)
	var method := str(args.get("m", ""))
	for node in parent.get_tree().get_nodes_in_group("net_fx_static"):
		if node is Node2D and is_instance_valid(node) \
				and (node as Node2D).global_position.distance_to(pos) < 1.0 and node.has_method("play_network_fx"):
			node.play_network_fx(method)
			return

# Roter Plasma-Schlag: Glutring, Funkenbögen entlang des Rands und kurze
# Funken ins Feld. "p" = Berührpunkt, "d" = Richtung ins Feld.
static func _plasma(parent: Node, args: Dictionary) -> void:
	var pos: Vector2 = args.get("p", Vector2.ZERO)
	var inward: Vector2 = args.get("d", Vector2.UP)
	var along := Vector2(-inward.y, inward.x)
	_ring(parent, ring_args(pos, Color(1.0, 0.12, 0.2, 0.8), 0.6, 4.2, 0.22, 0.3, 7, true))
	_ring(parent, ring_args(pos, Color(1.0, 0.8, 0.82, 0.95), 0.4, 1.8, 0.1, 0.14, 8))
	for side: float in [-1.0, 1.0]:
		for i in range(2):
			var arc_end := pos + along * side * randf_range(40.0, 85.0) + inward * randf_range(-6.0, 14.0)
			var arc := zap_args(pos, arc_end, Color(1.0, 0.25, 0.3, 0.95), 3.0 - float(i), 0.22, 5, 9.0)
			arc["z"] = 7
			_zap(parent, arc)
	for i in range(3):
		var dir := (inward + along * randf_range(-0.8, 0.8)).normalized()
		var spark := zap_args(pos, pos + dir * randf_range(22.0, 44.0), Color(1.0, 0.75, 0.6, 0.9), 2.0, 0.16, 3, 5.0)
		spark["z"] = 7
		_zap(parent, spark)

static func _pickup(parent: Node, args: Dictionary) -> void:
	var fx := Node2D.new()
	fx.z_index = 6
	fx.add_to_group("round_effect")
	parent.add_child(fx)
	fx.global_position = args.get("p", Vector2.ZERO)
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for i in range(18):
		points.append(Vector2.from_angle(TAU * float(i) / 18.0) * 16.0)
	points.append(points[0])
	ring.points = points
	ring.width = 3.0
	ring.default_color = args.get("c", Color.WHITE)
	fx.add_child(ring)
	var tw := fx.create_tween()
	tw.tween_property(fx, "scale", Vector2(1.8, 1.8), 0.22)
	tw.parallel().tween_property(fx, "modulate:a", 0.0, 0.24)
	tw.tween_callback(fx.queue_free)

static func _ring(parent: Node, args: Dictionary) -> void:
	var ring := Sprite2D.new()
	ring.texture = EFFECT_CIRCLE_TEXTURE
	ring.modulate = args.get("c", Color.WHITE)
	ring.z_index = int(args.get("z", 0))
	ring.add_to_group("round_effect")
	parent.add_child(ring)
	ring.global_position = args.get("p", Vector2.ZERO)
	var s0 := float(args.get("s0", 1.0))
	var s1 := float(args.get("s1", 4.0))
	ring.scale = Vector2(s0, s0)
	var tw := ring.create_tween()
	var grow := tw.tween_property(ring, "scale", Vector2(s1, s1), float(args.get("t", 0.25)))
	if bool(args.get("e", false)):
		grow.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, float(args.get("f", 0.25)))
	tw.tween_callback(ring.queue_free)

static func _zap(parent: Node, args: Dictionary) -> void:
	var from_pos: Vector2 = args.get("from", Vector2.ZERO)
	var to_pos: Vector2 = args.get("to", Vector2.ZERO)
	var segments := maxi(1, int(args.get("n", 1)))
	var jitter := float(args.get("j", 0.0))
	var bolt := Line2D.new()
	bolt.width = float(args.get("w", 3.0))
	bolt.default_color = args.get("c", Color.WHITE)
	bolt.z_index = int(args.get("z", 0))
	var normal := (to_pos - from_pos).orthogonal().normalized()
	bolt.add_point(from_pos)
	for i in range(1, segments):
		bolt.add_point(from_pos.lerp(to_pos, float(i) / float(segments)) + normal * randf_range(-jitter, jitter))
	bolt.add_point(to_pos)
	bolt.add_to_group("round_effect")
	parent.add_child(bolt)
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "modulate:a", 0.0, float(args.get("f", 0.2)))
	tw.tween_callback(bolt.queue_free)

# Rotierende Klingen, Reichweitenring und Kernblitz. "r" = Grundradius,
# "rm" = Fähigkeitsgröße.
static func _blade_storm(parent: Node, args: Dictionary) -> void:
	var pos: Vector2 = args.get("p", Vector2.ZERO)
	var rm := float(args.get("rm", 1.0))
	var pivot := Node2D.new()
	pivot.z_index = 6
	pivot.add_to_group("round_effect")
	parent.add_child(pivot)
	pivot.global_position = pos
	pivot.scale = Vector2.ONE * rm

	for i in range(8):
		var blade := Line2D.new()
		blade.width = 5.0
		blade.default_color = Color(1.0, 0.62, 0.78, 0.95)
		blade.begin_cap_mode = Line2D.LINE_CAP_ROUND
		blade.end_cap_mode = Line2D.LINE_CAP_ROUND
		var dir := Vector2.from_angle(TAU * float(i) / 8.0)
		var side := dir.orthogonal()
		blade.add_point(dir * 38.0)
		blade.add_point(dir * 78.0 + side * 12.0)
		blade.add_point(dir * 118.0 - side * 5.0)
		blade.add_point(dir * float(args.get("r", 145.0)))
		pivot.add_child(blade)

	# Großer Ring zeigt die tatsächliche Reichweite der Fähigkeit.
	_ring(parent, ring_args(pos, Color(1.0, 0.32, 0.55, 0.75), 0.4, 18.5 * rm, 0.34, 0.4, 5, true))
	# Heller Kernblitz für den direkten Treffermoment.
	_ring(parent, ring_args(pos, Color(1.0, 0.85, 0.9, 0.9), 1.5, 4.5, 0.14, 0.16, 7))

	var tw := pivot.create_tween()
	tw.tween_property(pivot, "rotation", TAU * 1.15, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pivot, "scale", Vector2(1.08, 1.08) * rm, 0.2)
	tw.parallel().tween_property(pivot, "modulate:a", 0.0, 0.18).set_delay(0.2)
	tw.tween_callback(pivot.queue_free)
