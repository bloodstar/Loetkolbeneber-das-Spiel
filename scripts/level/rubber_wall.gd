class_name RubberWall
extends Area2D

# Gummiwand außerhalb der Karte. Wer hineingerät, nimmt Schaden und wird mit
# Nachdruck zurück in Richtung Bildschirmmitte geschleudert. Stacheldraht am
# Rand und ein roter Plasma-Schlag bei Kontakt zeigen, dass sie Schaden macht.

# Abstand der Dornen am Kartenrand; dazwischen sitzen die Drahtknoten.
const BARB_SPACING: float = 34.0
const BARB_SPIKE_COLOR := Color(1.0, 0.22, 0.28, 0.95)
const BARB_KNOT_COLOR := Color(0.86, 0.88, 0.92, 0.95)

@export var inner_rect: Rect2 = Rect2()
@export var damage: float = 10.0
@export var push_force: float = 950.0
@export var damage_interval: float = 0.45
@export var safe_margin: float = 120.0
# Abstand des Zielpunkts zum Kartenrand: Die Bildmitte wird so weit in die
# Karte gezogen, dass der Rückstoß immer nach innen zeigt.
@export var center_inset: float = 96.0

var _damage_timers: Dictionary = {}

func _ready() -> void:
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if inner_rect.size == Vector2.ZERO:
		return
	var view_center := _shared_view_center()
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not body.has_method("take_damage"):
			continue
		# Online-Kopien bewegt der Host über den Snapshot; der Client stößt sie
		# nicht selbst zurück und zeigt den Plasma-Schlag nur einmal (vom Host).
		if body.get("is_replica") == true:
			continue
		# Dash und Raketensprung setzen ihre Geschwindigkeit jeden Frame neu und
		# würden den Rückstoß überschreiben: Die Wand bricht sie ab.
		if body.has_method("interrupt_rush"):
			body.interrupt_rush()
		var center := _push_target(view_center, body.global_position)
		var to_center: Vector2 = center - body.global_position
		if to_center.length_squared() < 1.0:
			center = inner_rect.get_center()
			to_center = center - body.global_position
		if to_center.length_squared() < 1.0:
			continue
		var dir := to_center.normalized()
		
		# Direkte Rückführung + Geschwindigkeit: wirkt auch gegen gehaltene
		# Eingaben in Richtung Kartenrand.
		body.global_position += dir * push_force * 0.65 * delta
		body.velocity = body.velocity.lerp(dir * push_force, 0.6)
		
		var id := body.get_instance_id()
		var t := float(_damage_timers.get(id, 0.0)) - delta
		if t <= 0.0:
			var contact := _edge_contact(body.global_position)
			body.take_damage(damage, dir * 140.0)
			_damage_timers[id] = damage_interval
			NetFx.emit(get_parent(), "plasma", NetFx.with_sound(contact, "bounce", 0.15, -2.0))
			if not is_instance_valid(body):
				continue
		else:
			_damage_timers[id] = t
		
		# Sicherheitsnetz: nicht beliebig weit aus der Karte entkommen.
		var safe := inner_rect.grow(safe_margin)
		if not safe.has_point(body.global_position):
			body.global_position = body.global_position.clamp(safe.position, safe.end)

# Bildmitte der gemeinsamen Arena-Kamera (Mitte aller Spieler), auf allen
# Clients gleich. In Scroll-Levels folgt jede Kamera dem eigenen Spieler; die
# Bildmitte ist dann der Spieler selbst (Vector2.INF = Position des Körpers).
func _shared_view_center() -> Vector2:
	var cam := get_tree().get_first_node_in_group("dynamic_camera") as DynamicCamera
	if cam == null or cam.scroll_mode:
		return Vector2.INF
	return cam.get_shared_view_center()

# Zielpunkt des Rückstoßes: Bildmitte, in die Karte gezogen. Liegt die Mitte
# selbst am Rand oder fehlt sie, zeigt der Stoß senkrecht zurück ins Feld.
func _push_target(view_center: Vector2, body_pos: Vector2) -> Vector2:
	var point := body_pos if view_center == Vector2.INF else view_center
	var inset := minf(center_inset, minf(inner_rect.size.x, inner_rect.size.y) * 0.5)
	var inner := inner_rect.grow(-inset)
	return point.clamp(inner.position, inner.end)

# Berührpunkt auf dem Kartenrand ("p") und die Richtung ins Feld ("d") für den
# Plasma-Effekt. Außerhalb liegt der geklemmte Punkt schon auf dem Rand, sonst
# wird er auf die nächste Kante geschoben.
func _edge_contact(pos: Vector2) -> Dictionary:
	var r := inner_rect
	var p := pos.clamp(r.position, r.end)
	var dists := PackedFloat32Array([p.x - r.position.x, r.end.x - p.x, p.y - r.position.y, r.end.y - p.y])
	var best := 0
	for i in range(1, 4):
		if dists[i] < dists[best]:
			best = i
	match best:
		0:
			return {"p": Vector2(r.position.x, p.y), "d": Vector2.RIGHT}
		1:
			return {"p": Vector2(r.end.x, p.y), "d": Vector2.LEFT}
		2:
			return {"p": Vector2(p.x, r.position.y), "d": Vector2.DOWN}
	return {"p": Vector2(p.x, r.end.y), "d": Vector2.UP}

# Stacheldraht entlang des Kartenrands: rote Dornen zeigen ins Feld, dazwischen
# gekreuzte Drahtknoten. Wird einmal gezeichnet und pulsiert leicht.
static func add_barbed_border(parent: Node, map_size: Vector2) -> Node2D:
	var node := Node2D.new()
	node.z_index = 3
	node.draw.connect(func() -> void: _draw_barbs(node, map_size))
	parent.add_child(node)
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.7, 0.9)
	tw.tween_property(node, "modulate:a", 1.0, 0.9)
	return node

static func _draw_barbs(node: Node2D, map_size: Vector2) -> void:
	var corners: Array[Vector2] = [Vector2.ZERO, Vector2(map_size.x, 0.0), map_size, Vector2(0.0, map_size.y)]
	for i in range(4):
		if i == 2:  # Boden soll keine Stacheln haben
			continue
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var length := a.distance_to(b)
		if length < 1.0:
			continue
		var along := (b - a) / length
		# Ecken laufen im Uhrzeigersinn, links von der Laufrichtung liegt das Feld.
		var inward := Vector2(-along.y, along.x)
		var count := maxi(1, int(length / BARB_SPACING))
		var step := length / float(count)
		for k in range(count):
			var spike_pos := a + along * (float(k) + 0.5) * step
			node.draw_colored_polygon(PackedVector2Array([
				spike_pos - along * 3.5,
				spike_pos + inward * 5.0, #Stacheln kleiner (war 13)
				spike_pos + along * 3.5,
			]), BARB_SPIKE_COLOR)
			var knot := a + along * float(k) * step
			var d1 := (along + inward) * 5.0
			var d2 := (along - inward) * 5.0
			#knoten deaktiviert, zu viel
			#node.draw_line(knot - d1, knot + d1, BARB_KNOT_COLOR, 2.0, true)
			#node.draw_line(knot - d2, knot + d2, BARB_KNOT_COLOR, 2.0, true)

func _on_body_exited(body: Node2D) -> void:
	if body:
		_damage_timers.erase(body.get_instance_id())
