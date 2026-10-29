class_name ChainRopeSolver
extends Node

## Eigene Kettenphysik für alle Kistenketten einer Karte (nur auf dem Host).
##
## Godots Gelenke (PinJoint2D) geben unter Last nach und zittern, sobald man
## sie hart korrigiert. Deshalb rechnet dieser Solver die Ketten selbst: Jeder
## Gelenkpunkt ist ein Massepunkt (Verlet-Integration), jedes Glied und jede
## Kettenkiste ist ein starrer Stab fester Länge zwischen zwei Punkten. Die
## Glieder und Kisten selbst sind eingefrorene, kinematische Körper, die jeden
## Physikschritt auf ihren Stab gesetzt werden. So kollidieren sie weiter mit
## Spielern, Kugeln, Kisten und Schüssen, können sich aber nicht dehnen.
##
## Gegen Restdehnung bei langen Ketten gibt es zusätzlich Halteseile
## ("Long Range Attachments"): Kein Punkt darf weiter von einem festen Anker
## entfernt sein als die Kettenlänge dazwischen.
##
## Lasten: Spieler, die auf einem Glied stehen, und Kugeln oder Kisten, die
## darauf liegen, ziehen die Kette mit ihrem Gewicht nach unten.

const TILE_SIZE: float = 36.0
const ITERATIONS: int = 10
const TOLERANCE: float = 0.25
# Geschwindigkeitserhalt pro Schritt; in der ersten Sekunde stärker gedämpft,
# damit die Kette ruhig in ihre Ruhelage einschwingt.
const DAMPING: float = 0.996
const DAMPING_START: float = 0.90
const SETTLE_TIME: float = 1.0
const MAX_STEP: float = 28.0
const PLAYER_WEIGHT: float = 900.0
const LOST_Y: float = 3000.0
const TETHERS_PER_POINT: int = 2
# Teile, die keine Verbindung mehr zu einem festen Anker haben, werden normale
# Physikkörper (fallen und kollidieren richtig), blenden nach DESPAWN_DELAY
# über DESPAWN_FADE aus und verschwinden.
const DESPAWN_DELAY: float = 2.0
const DESPAWN_FADE: float = 0.6

## Prüft, ob ein Punkt (Generator-Koordinaten) in festem Gelände liegt.
var solid_check: Callable

var _gravity: float = 980.0
var _age: float = 0.0

# Punkte
var _pos := PackedVector2Array()
var _prev := PackedVector2Array()
var _mass := PackedFloat32Array()
var _fixed := PackedByteArray()
var _alive := PackedByteArray()
var _force := PackedVector2Array()
var _kick := PackedVector2Array()
var _point_body: Array = []

# Stäbe (Glieder, Kettenkisten, Befestigungen an Gitterkisten)
var _sa := PackedInt32Array()
var _sb := PackedInt32Array()
var _rest := PackedFloat32Array()
var _active := PackedByteArray()
var _stick_body: Array = []

# Halteseile: Punkt, Anker, Höchstabstand
var _tp := PackedInt32Array()
var _ta := PackedInt32Array()
var _tl := PackedFloat32Array()

var _body_stick: Dictionary = {}
var _body_point: Dictionary = {}
var _dirty: bool = true

func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))

# --- Aufbau ------------------------------------------------------------------

func add_point(p: Vector2, fixed: bool) -> int:
	_pos.append(p)
	_prev.append(p)
	_mass.append(0.0)
	_fixed.append(1 if fixed else 0)
	_alive.append(1)
	_force.append(Vector2.ZERO)
	_kick.append(Vector2.ZERO)
	_point_body.append(null)
	_dirty = true
	return _pos.size() - 1

func add_mass(i: int, m: float) -> void:
	_mass[i] += maxf(0.0, m)

func set_fixed(i: int, fixed: bool) -> void:
	_fixed[i] = 1 if fixed else 0
	_dirty = true

func point_position(i: int) -> Vector2:
	return _pos[i]

## Punkt für einen Körper, der als Ganzes an einem Punkt hängt (Gitterkiste).
## Der Körper wird kinematisch und jeden Schritt auf den Punkt gesetzt.
func point_for_body(body: RigidBody2D) -> int:
	var id := body.get_instance_id()
	if _body_point.has(id):
		return int(_body_point[id])
	var i := add_point(body.position, false)
	add_mass(i, body.mass)
	_point_body[i] = body
	_body_point[id] = i
	_make_kinematic(body)
	return i

## Starrer Stab zwischen zwei Punkten. body (Glied oder Kiste) wird darauf
## gesetzt; ohne body ist es eine unsichtbare Befestigung.
func add_stick(i: int, j: int, body: Node) -> int:
	_sa.append(i)
	_sb.append(j)
	_rest.append(_pos[i].distance_to(_pos[j]))
	_active.append(1)
	_stick_body.append(body)
	var k := _sa.size() - 1
	if body != null:
		_body_stick[body.get_instance_id()] = k
		if body is RigidBody2D:
			_make_kinematic(body)
	_dirty = true
	return k

## Alles, was nach einem Riss keinen festen Anker mehr erreicht, aus dem
## Solver lösen: Körper werden dynamisch und verschwinden kurz darauf.
func _release_loose(best: Array) -> void:
	var loose := PackedByteArray()
	loose.resize(_pos.size())
	for i in range(_pos.size()):
		loose[i] = 1 if _alive[i] == 1 and _fixed[i] == 0 and (best[i] as Array).is_empty() else 0
	for k in range(_sa.size()):
		if _active[k] == 0 or (loose[_sa[k]] == 0 and loose[_sb[k]] == 0):
			continue
		_active[k] = 0
		var body = _stick_body[k]
		if body != null and is_instance_valid(body):
			_body_stick.erase(body.get_instance_id())
			_release_body(body)
	for i in range(_pos.size()):
		if loose[i] == 0:
			continue
		_alive[i] = 0
		var body = _point_body[i]
		if body != null and is_instance_valid(body):
			_body_point.erase(body.get_instance_id())
			_release_body(body)

func _release_body(body: Node) -> void:
	if body.is_queued_for_deletion():
		return
	if body.has_meta("rope_solver"):
		body.remove_meta("rope_solver")
	var rigid := body as RigidBody2D
	if rigid != null:
		rigid.freeze = false
	var item := body as CanvasItem
	if item == null:
		body.queue_free()
		return
	var tween := item.create_tween()
	tween.tween_interval(DESPAWN_DELAY)
	tween.tween_property(item, "modulate:a", 0.0, DESPAWN_FADE)
	tween.tween_callback(item.queue_free)

func _make_kinematic(body: RigidBody2D) -> void:
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.set_meta("rope_solver", self)

## Ein Glied ist zerbrochen: Die Kette reißt an dieser Stelle.
func detach_body(body: Node) -> void:
	var id := body.get_instance_id()
	if _body_stick.has(id):
		_active[int(_body_stick[id])] = 0
		_body_stick.erase(id)
		_dirty = true

## Stoß (z. B. Explosion) auf ein Glied oder eine Kiste der Kette.
func impulse_body(body: Node, impulse: Vector2) -> void:
	var id := body.get_instance_id()
	if _body_stick.has(id):
		var k := int(_body_stick[id])
		_kick_point(_sa[k], impulse * 0.5)
		_kick_point(_sb[k], impulse * 0.5)
	elif _body_point.has(id):
		_kick_point(int(_body_point[id]), impulse)

func _kick_point(i: int, impulse: Vector2) -> void:
	if _fixed[i] == 0 and _mass[i] > 0.0:
		_kick[i] += impulse / _mass[i]

# --- Simulation --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _pos.is_empty() or delta <= 0.0:
		return
	_age += delta
	_check_bodies()
	if _dirty:
		_rebuild_tethers()
		_dirty = false
	_gather_loads()
	_integrate(delta)
	_solve()
	_collide()
	_pose()

func _check_bodies() -> void:
	# Zerstörte Kisten und Glieder lösen ihre Stäbe bzw. Punkte.
	for k in range(_sa.size()):
		if _active[k] == 0:
			continue
		var body = _stick_body[k]
		if body != null and (not is_instance_valid(body) or body.is_queued_for_deletion()):
			_active[k] = 0
			_dirty = true
	for i in range(_pos.size()):
		if _alive[i] == 0:
			continue
		var body = _point_body[i]
		if body != null and (not is_instance_valid(body) or body.is_queued_for_deletion()):
			_alive[i] = 0
			_dirty = true
	if _dirty:
		for k in range(_sa.size()):
			if _active[k] == 1 and (_alive[_sa[k]] == 0 or _alive[_sb[k]] == 0):
				_active[k] = 0

func _gather_loads() -> void:
	var tree := get_tree()
	# Spieler, die auf der Kette stehen.
	for node in tree.get_nodes_in_group("player"):
		var player := node as CharacterBody2D
		if player == null or not player.is_on_floor():
			continue
		for c in range(player.get_slide_collision_count()):
			var col := player.get_slide_collision(c)
			if col.get_normal().y > -0.5:
				continue
			var collider := col.get_collider()
			if collider != null and _apply_load(collider, PLAYER_WEIGHT):
				break
	# Kugeln und lose Kisten, die auf der Kette liegen.
	for group in ["rolling_ball", "crate"]:
		for node in tree.get_nodes_in_group(group):
			var body := node as RigidBody2D
			if body == null or body.freeze or not body.contact_monitor:
				continue
			var touching: Array = []
			for other in body.get_colliding_bodies():
				if other is Node2D and (other as Node2D).global_position.y > body.global_position.y and _is_mapped(other):
					touching.append(other)
			if touching.is_empty():
				continue
			var share := body.mass * _gravity / float(touching.size())
			for other in touching:
				_apply_load(other, share)

func _is_mapped(node: Object) -> bool:
	var id := node.get_instance_id()
	return _body_stick.has(id) or _body_point.has(id)

func _apply_load(node: Object, weight: float) -> bool:
	var id := node.get_instance_id()
	if _body_stick.has(id):
		var k := int(_body_stick[id])
		_force[_sa[k]] += Vector2(0.0, weight * 0.5)
		_force[_sb[k]] += Vector2(0.0, weight * 0.5)
		return true
	if _body_point.has(id):
		_force[int(_body_point[id])] += Vector2(0.0, weight)
		return true
	return false

func _integrate(delta: float) -> void:
	var damping := lerpf(DAMPING_START, DAMPING, clampf(_age / SETTLE_TIME, 0.0, 1.0))
	var dt2 := delta * delta
	var g := Vector2(0.0, _gravity)
	for i in range(_pos.size()):
		if _fixed[i] == 1 or _alive[i] == 0:
			_force[i] = Vector2.ZERO
			_kick[i] = Vector2.ZERO
			continue
		var p := _pos[i]
		var v := (p - _prev[i]) * damping + _kick[i] * delta
		v = v.limit_length(MAX_STEP)
		var accel := g
		if _mass[i] > 0.0:
			accel += _force[i] / _mass[i]
		_prev[i] = p
		_pos[i] = p + v + accel * dt2
		_force[i] = Vector2.ZERO
		_kick[i] = Vector2.ZERO

func _inv(i: int) -> float:
	if _fixed[i] == 1 or _mass[i] <= 0.0:
		return 0.0
	return 1.0 / _mass[i]

func _solve() -> void:
	var count := _sa.size()
	for it in range(ITERATIONS):
		var worst := 0.0
		for n in range(count):
			var k := n if it % 2 == 0 else count - 1 - n
			if _active[k] == 0:
				continue
			var a := _sa[k]
			var b := _sb[k]
			var wa := _inv(a)
			var wb := _inv(b)
			var w := wa + wb
			if w <= 0.0:
				continue
			var d := _pos[b] - _pos[a]
			var dist := d.length()
			if dist < 0.0001:
				continue
			var diff := dist - _rest[k]
			worst = maxf(worst, absf(diff))
			var corr := d * (diff / (dist * w))
			_pos[a] += corr * wa
			_pos[b] -= corr * wb
		_apply_tethers()
		if worst < TOLERANCE:
			break

func _apply_tethers() -> void:
	for t in range(_tp.size()):
		var i := _tp[t]
		if _alive[i] == 0:
			continue
		var anchor := _pos[_ta[t]]
		var d := _pos[i] - anchor
		var limit := _tl[t]
		if d.length_squared() > limit * limit:
			_pos[i] = anchor + d.normalized() * limit

func _collide() -> void:
	for i in range(_pos.size()):
		if _fixed[i] == 1 or _alive[i] == 0:
			continue
		var p := _pos[i]
		if p.y > LOST_Y:
			_alive[i] = 0
			_dirty = true
			continue
		if solid_check.is_valid() and solid_check.call(p):
			# Auf die Oberkante der Kachel schieben, mit etwas Reibung.
			p.y = floorf(p.y / TILE_SIZE) * TILE_SIZE - 0.5
			_pos[i] = p
			var q := _prev[i]
			q.x = lerpf(q.x, p.x, 0.5)
			_prev[i] = q
	if _dirty:
		for k in range(_sa.size()):
			if _active[k] == 1 and (_alive[_sa[k]] == 0 or _alive[_sb[k]] == 0):
				_active[k] = 0

func _pose() -> void:
	for k in range(_sa.size()):
		if _active[k] == 0:
			continue
		var body = _stick_body[k]
		if body == null or not is_instance_valid(body):
			continue
		var pa := _pos[_sa[k]]
		var pb := _pos[_sb[k]]
		(body as Node2D).position = (pa + pb) * 0.5
		(body as Node2D).rotation = (pb - pa).angle()
	for i in range(_pos.size()):
		if _alive[i] == 0:
			continue
		var body = _point_body[i]
		if body != null and is_instance_valid(body):
			(body as Node2D).position = _pos[i]

# --- Halteseile --------------------------------------------------------------

## Für jeden Punkt die kürzeste Kettenlänge zu den nächsten festen Ankern
## (über aktive Stäbe). Nach jedem Riss neu berechnet.
func _rebuild_tethers() -> void:
	_tp.clear()
	_ta.clear()
	_tl.clear()
	var n := _pos.size()
	var adjacency: Array = []
	adjacency.resize(n)
	for i in range(n):
		adjacency[i] = PackedInt32Array()
	for k in range(_sa.size()):
		if _active[k] == 0:
			continue
		var a := _sa[k]
		var b := _sb[k]
		var la: PackedInt32Array = adjacency[a]
		la.append(k)
		adjacency[a] = la
		var lb: PackedInt32Array = adjacency[b]
		lb.append(k)
		adjacency[b] = lb
	# Pro Punkt die besten Anker sammeln: [abstand, anker]
	var best: Array = []
	best.resize(n)
	for i in range(n):
		best[i] = []
	for src in range(n):
		if _fixed[src] == 0 or _alive[src] == 0 or (adjacency[src] as PackedInt32Array).is_empty():
			continue
		var dist := PackedFloat32Array()
		dist.resize(n)
		dist.fill(INF)
		dist[src] = 0.0
		var queue := PackedInt32Array([src])
		var head := 0
		while head < queue.size():
			var u := queue[head]
			head += 1
			for k in adjacency[u]:
				var v := _sb[k] if _sa[k] == u else _sa[k]
				var nd := dist[u] + _rest[k]
				if nd + 0.01 < dist[v]:
					dist[v] = nd
					# Über feste Punkte hinaus nicht weitersuchen.
					if _fixed[v] == 0:
						queue.append(v)
		for i in range(n):
			if i == src or _fixed[i] == 1 or dist[i] == INF:
				continue
			(best[i] as Array).append([dist[i], src])
	_release_loose(best)
	for i in range(n):
		var list: Array = best[i]
		if list.is_empty():
			continue
		list.sort_custom(func(x, y): return x[0] < y[0])
		for e in range(mini(TETHERS_PER_POINT, list.size())):
			_tp.append(i)
			_ta.append(int(list[e][1]))
			_tl.append(float(list[e][0]))
