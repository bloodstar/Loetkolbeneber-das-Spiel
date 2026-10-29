class_name CrateChain
extends Node2D

## Kistenkette: Holzkisten verschiedener Größe, mit Kettengliedern verbunden.
## Die Kette ist entweder zwischen zwei Ankern gespannt (an festen Plattformen
## oder am Kartenrand, hängt leicht durch) oder hängt frei von einem Anker
## herab. Glieder (ChainLink) und Kisten (PhysicsCrate) kollidieren mit
## Spielern, Kisten, Kugeln und Projektilen; Glieder und Kisten lassen sich
## zerschießen, dann reißt die Kette an dieser Stelle.
##
## Die Bewegung rechnet der ChainRopeSolver des LevelGenerators (feste
## Gliedlänge, keine Dehnung); Glieder und Kettenkisten sind dabei
## kinematische Körper, die der Solver jeden Schritt setzt. Der Host
## simuliert; Clients bekommen die Glieder per Snapshot.

const TILE_SIZE: float = 36.0
const LINK_LENGTH: float = ChainLink.LENGTH
const CRATE_BASE: float = PhysicsCrate.BASE_SIZE

var net_id: int = 0
var object_type: String = "crate_chain"
var is_replica: bool = false

# Bauplan (vor add_child gesetzt). Koordinaten in Pixeln im Raum des
# LevelGenerators; die Kette selbst liegt dort im Ursprung.
var anchor_a: Vector2 = Vector2.ZERO
var anchor_b: Vector2 = Vector2.ZERO
var has_anchor_b: bool = true
var elements: Array = []
var crates: Array = []
var tint: Color = Color(0.66, 0.70, 0.76, 1.0)
# Statt fester Anker kann die Kette an Körpern hängen (z. B. an den Kisten
# eines Kettengitters). Dann gibt es dort keinen Anker-Bolzen.
var body_a: PhysicsBody2D = null
var body_b: PhysicsBody2D = null
var link_mass: float = 0.3

var _links: Array = []
var _solver: ChainRopeSolver = null

## Liefert die Teile der Kette in Reihenfolge vom Anker A aus. Jedes Teil ist
## {"kind": "link"|"crate", "p0": Anfang, "p1": Ende, "size": Kistengröße}.
## Gespannte Ketten bekommen slack (z. B. 1.06 = 6 % länger als der Abstand)
## und hängen als Parabel durch; hängende Ketten laufen senkrecht nach unten,
## die letzte Kiste bildet das Ende.
static func plan(a: Vector2, b: Vector2, spanned: bool, hang_length: float, sizes: Array, slack: float = 1.06) -> Array:
	var crate_len := 0.0
	for s in sizes:
		crate_len += CRATE_BASE * float(s)
	var gaps := sizes.size() + 1 if spanned else maxi(1, sizes.size())
	var total := 0.0
	if spanned:
		total = maxf(a.distance_to(b) * maxf(1.0, slack), crate_len + LINK_LENGTH * float(gaps) * 2.0)
	else:
		total = maxf(hang_length, crate_len + LINK_LENGTH * float(gaps))
	# Aufrunden: Eine zu kurze Kette würde beim Start ruckartig gespannt.
	var link_count := maxi(gaps, int(ceil((total - crate_len) / LINK_LENGTH - 0.001)))
	# Straff gespannte Ketten (slack <= 1): Glieder minimal enger setzen, damit
	# die Kette exakt so lang ist wie der Abstand. Sonst hinge sie wegen des
	# aufgerundeten Glieds bei langen Spannweiten sichtbar durch.
	var spacing := LINK_LENGTH
	if spanned and slack <= 1.0 and total > crate_len:
		spacing = minf(LINK_LENGTH, (total - crate_len) / float(link_count))
	total = float(link_count) * spacing + crate_len

	# Glieder gleichmäßig auf die Abschnitte zwischen den Kisten verteilen,
	# den Rest in die mittleren Abschnitte.
	var per_gap: Array[int] = []
	for i in range(gaps):
		per_gap.append(int(link_count / gaps))
	var rest := link_count - int(link_count / gaps) * gaps
	var gi := int(gaps / 2)
	while rest > 0:
		per_gap[gi % gaps] += 1
		gi += 1
		rest -= 1

	var pts := PackedVector2Array()
	if spanned:
		pts = _sag_curve(a, b, total)
	else:
		pts = PackedVector2Array([a, a + Vector2(0.0, total)])
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i - 1].distance_to(pts[i]))

	var result: Array = []
	var u := 0.0
	for g in range(gaps):
		for _k in range(per_gap[g]):
			result.append({"kind": "link", "p0": _point_at(pts, cum, u), "p1": _point_at(pts, cum, u + spacing), "size": 0.0})
			u += spacing
		# Nach jedem Abschnitt folgt eine Kiste; gespannte Ketten enden mit
		# Gliedern am Anker B, hängende mit der letzten Kiste.
		if g < sizes.size():
			var len_px := CRATE_BASE * float(sizes[g])
			result.append({"kind": "crate", "p0": _point_at(pts, cum, u), "p1": _point_at(pts, cum, u + len_px), "size": float(sizes[g])})
			u += len_px
	return result

# Parabel von a nach b, die um sag senkrecht zur Verbindung durchhängt. sag
# wird per Bisektion so gewählt, dass die Bogenlänge length entspricht.
static func _sag_curve(a: Vector2, b: Vector2, length: float) -> PackedVector2Array:
	var dist := a.distance_to(b)
	var dir := (b - a) / maxf(dist, 0.001)
	var normal := Vector2(-dir.y, dir.x)
	if normal.y < 0.0 or (absf(normal.y) < 0.000001 and normal.x < 0.0):
		normal = -normal
	var lo := 0.0
	var hi := maxf(dist, length)
	for _i in range(40):
		var mid := (lo + hi) * 0.5
		if _curve_length(_curve(a, b, normal, mid)) < length:
			lo = mid
		else:
			hi = mid
	return _curve(a, b, normal, lo)

static func _curve(a: Vector2, b: Vector2, normal: Vector2, sag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 96
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		pts.append(a.lerp(b, t) + normal * sag * 4.0 * t * (1.0 - t))
	return pts

static func _curve_length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total

static func _point_at(pts: PackedVector2Array, cum: PackedFloat32Array, d: float) -> Vector2:
	if d <= 0.0:
		return pts[0]
	for i in range(1, pts.size()):
		if cum[i] >= d:
			var seg := cum[i] - cum[i - 1]
			var t := 0.0 if seg <= 0.0 else (d - cum[i - 1]) / seg
			return pts[i - 1].lerp(pts[i], t)
	# Über das Ende hinaus (nur bei hängenden Ketten möglich): geradeaus weiter.
	var last := pts[pts.size() - 1]
	var dir := (last - pts[pts.size() - 2]).normalized()
	return last + dir * (d - cum[cum.size() - 1])

func _ready() -> void:
	add_to_group("crate_chain")
	z_index = 1
	_build()
	set_physics_process(false)

func _build() -> void:
	if body_a == null:
		_make_anchor(anchor_a)
	if body_b == null and has_anchor_b:
		_make_anchor(anchor_b)

	var crate_cursor := 0
	var bodies: Array = []
	for element in elements:
		var p0: Vector2 = element["p0"]
		var p1: Vector2 = element["p1"]
		if str(element["kind"]) == "crate":
			var crate: Node = crates[crate_cursor] if crate_cursor < crates.size() else null
			crate_cursor += 1
			bodies.append(crate)
			continue
		var link := ChainLink.new()
		link.index = _links.size()
		link.tint = tint
		link.link_mass = link_mass
		link.is_replica = is_replica
		link.position = (p0 + p1) * 0.5
		link.rotation = (p1 - p0).angle()
		add_child(link)
		link.link_broken.connect(_on_link_broken)
		_links.append(link)
		bodies.append(link)

	if is_replica or elements.is_empty():
		return
	var generator := get_parent()
	if generator == null or not generator.has_method("get_rope_solver"):
		return
	_solver = generator.get_rope_solver()
	# Punkte an allen Übergängen: Anker A -> Teil 0 -> ... -> Teil n (-> Anker B).
	var first: Vector2 = elements[0]["p0"]
	var previous := _solver.add_point(first, body_a == null)
	if body_a is RigidBody2D:
		_solver.add_stick(_solver.point_for_body(body_a as RigidBody2D), previous, null)
	for i in range(elements.size()):
		var element: Dictionary = elements[i]
		var point := _solver.add_point(element["p1"], false)
		var body: Node = bodies[i]
		var mass := link_mass
		if str(element["kind"]) == "crate":
			mass = float(body.get("mass")) if body != null else 0.85
		_solver.add_mass(previous, mass * 0.5)
		_solver.add_mass(point, mass * 0.5)
		_solver.add_stick(previous, point, body)
		previous = point
	if body_b is RigidBody2D:
		_solver.add_stick(previous, _solver.point_for_body(body_b as RigidBody2D), null)
	elif has_anchor_b:
		_solver.set_fixed(previous, true)

func _make_anchor(world_pos: Vector2) -> StaticBody2D:
	var anchor := StaticBody2D.new()
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	anchor.position = world_pos
	add_child(anchor)
	# Kleine Halteplatte mit Bolzen am Befestigungspunkt.
	var plate := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(8):
		var a := TAU * float(i) / 8.0 + PI / 8.0
		pts.append(Vector2(cos(a), sin(a)) * 7.0)
	plate.polygon = pts
	plate.color = Color(tint.r * 0.45, tint.g * 0.45, tint.b * 0.5, 1.0)
	anchor.add_child(plate)
	var bolt := Polygon2D.new()
	var bolt_pts := PackedVector2Array()
	for i in range(6):
		var a := TAU * float(i) / 6.0
		bolt_pts.append(Vector2(cos(a), sin(a)) * 3.0)
	bolt.polygon = bolt_pts
	bolt.color = tint.lightened(0.3)
	anchor.add_child(bolt)
	return anchor

func _on_link_broken(link: ChainLink) -> void:
	if _solver != null and is_instance_valid(_solver):
		_solver.detach_body(link)

func get_network_state() -> Dictionary:
	var positions := PackedVector2Array()
	var rotations := PackedFloat32Array()
	var alive := PackedByteArray()
	for link in _links:
		if is_instance_valid(link) and not link.is_queued_for_deletion():
			positions.append(link.position)
			rotations.append(link.rotation)
			alive.append(1)
		else:
			positions.append(Vector2.ZERO)
			rotations.append(0.0)
			alive.append(0)
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"lp": positions,
		"lr": rotations,
		"la": alive,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	var positions: PackedVector2Array = data.get("lp", PackedVector2Array())
	var rotations: PackedFloat32Array = data.get("lr", PackedFloat32Array())
	var alive: PackedByteArray = data.get("la", PackedByteArray())
	var count := mini(_links.size(), mini(positions.size(), mini(rotations.size(), alive.size())))
	for i in range(count):
		var link = _links[i]
		if not is_instance_valid(link) or link.is_queued_for_deletion():
			continue
		if alive[i] == 0:
			link.apply_network_break()
			continue
		link.set_meta("net_pos", positions[i])
		link.set_meta("net_rot", rotations[i])
		if not link.has_meta("net_seen"):
			link.set_meta("net_seen", true)
			link.position = positions[i]
			link.rotation = rotations[i]

## Clients: Glieder gleiten zur letzten Snapshot-Lage, damit sie zwischen
## den Netzwerk-Updates nicht ruckeln.
func _process(delta: float) -> void:
	if not is_replica:
		return
	var t := clampf(delta * 18.0, 0.0, 1.0)
	for link in _links:
		if not is_instance_valid(link) or not link.has_meta("net_pos"):
			continue
		link.position = link.position.lerp(link.get_meta("net_pos"), t)
		link.rotation = lerp_angle(link.rotation, float(link.get_meta("net_rot")), t)
