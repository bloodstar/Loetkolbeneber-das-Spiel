class_name EffectZone
extends Node2D

# Boden-/Flächeneffekt für Gift, Feuer, Eis, Blitz sowie die rein visuellen
# Zonen Void (Singularität) und Heilung.
# Der Host simuliert Schaden und Status. Auf dem Client existiert die Zone nur
# als visuelle Replik. Die Darstellung wird komplett per _draw() erzeugt
# (keine Texturen, keine Partikel-Nodes), damit auch viele Zonen gleichzeitig
# günstig bleiben.

# Neue Arten nur hinten anhängen: der Wert wird übers Netzwerk geschickt.
enum Kind {
	POISON,
	FIRE,
	ICE,
	LIGHTNING,
	VOID,
	HEAL
}

# Feuer fällt wie brennendes Benzin auf den Boden darunter, auch aus großer Höhe.
const FIRE_FLOOR_SNAP: float = 5000.0
const FIRE_FLOOR_MASK: int = 1
const LIGHTNING_REFRESH: float = 0.07

var kind: Kind = Kind.POISON
var owner_player: Player = null
# Zone aus der Heldenfähigkeit: Schaden zählt als Fähigkeitsschaden (Statistik).
var from_ability: bool = false
var target: Player = null
var radius: float = 45.0
var duration: float = 3.0
var tick_interval: float = 0.55
var damage: float = 0.0
var poison_stacks: int = 2
var poison_damage: float = 4.0
var burn_stacks: int = 3
var burn_damage: float = 5.0
var freeze_duration: float = 1.2
var stun_duration: float = 0.25
var is_replica: bool = false
# Nur Optik (Void, Heilung, Sporenwolke): die Wirkung berechnet der Spieler selbst.
var visual_only: bool = false

var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _anim_time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _phase: Array[float] = []
var _offset: Array[float] = []

# Feuer: Bodenhöhe je Spalte (lokal), NAN = keine Fläche darunter.
var _fire_scanned: bool = false
var _fire_columns: PackedFloat32Array = PackedFloat32Array()

# Feuer auf beweglichem Untergrund (Plattform, Wippe, Kiste): die Zone hängt
# am Körper des Map-Objekts. carrier_id ist dessen net_id, damit Clients
# dasselbe Objekt finden; die Lage relativ zum Körper kommt vom Host.
var carrier_id: int = -1
var carrier_local_pos: Vector2 = Vector2.ZERO
var carrier_local_rot: float = 0.0
var _carrier: Node2D = null
var _carrier_resolved: bool = false

# Blitz: wird alle LIGHTNING_REFRESH Sekunden neu "geknistert".
var _bolt_timer: float = 0.0
var _bolts: Array[PackedVector2Array] = []
var _sparks: PackedVector2Array = PackedVector2Array()
var _rim: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	z_index = -2
	add_to_group("effect_zone")
	_rng.randomize()
	var count := 24
	for i in count:
		_phase.append(_rng.randf())
		_offset.append(_rng.randf_range(-1.0, 1.0))
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	modulate.a = clampf(1.0 - maxf(0.0, _elapsed - duration + 0.45) / 0.45, 0.0, 1.0)

	# Raumabfragen gehören in den Physik-Schritt. Die Position wird erst nach
	# add_child() gesetzt, darum hier statt in _ready().
	if kind == Kind.FIRE and not _fire_scanned:
		_scan_fire_floor()
	_follow_carrier()

	if is_replica or visual_only:
		if _elapsed >= duration:
			queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()

	if _elapsed >= duration:
		queue_free()

func _process(delta: float) -> void:
	_anim_time += delta
	# Auch im Render-Schritt nachziehen, damit die Flammen nicht hinterherruckeln.
	_follow_carrier()
	if kind == Kind.LIGHTNING:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = LIGHTNING_REFRESH
			_regenerate_lightning()
	queue_redraw()

func _apply_tick() -> void:
	if not is_instance_valid(target) or target.current_health <= 0.0:
		return
	if global_position.distance_to(target.global_position) > radius + 12.0:
		return

	match kind:
		Kind.POISON:
			target.apply_poison(poison_stacks, poison_damage)
		Kind.FIRE:
			target.apply_burn(burn_stacks, burn_damage)
		Kind.ICE:
			target.apply_freeze(freeze_duration)
		Kind.LIGHTNING:
			if damage > 0.0:
				var tag := from_ability and is_instance_valid(owner_player)
				if tag:
					owner_player.dealing_ability_damage = true
				target.take_damage(damage, Vector2.ZERO, owner_player)
				if tag and is_instance_valid(owner_player):
					owner_player.dealing_ability_damage = false
			target.apply_stun(stun_duration)

# Sucht die Bodenoberfläche unter pos. Liefert pos unverändert, wenn darunter
# nichts ist (z. B. über einem Abgrund). Der Host ruft das vor dem Spawn auf,
# damit Trefferfläche und Optik übereinstimmen.
static func snap_to_floor(space: PhysicsDirectSpaceState2D, pos: Vector2) -> Vector2:
	var hit := floor_hit(space, pos)
	if hit.is_empty():
		return pos
	return hit["position"]

# Strahl nach unten; liefert das Ergebnis von intersect_ray (leer = kein Boden).
static func floor_hit(space: PhysicsDirectSpaceState2D, pos: Vector2) -> Dictionary:
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters2D.create(pos + Vector2(0.0, -12.0), pos + Vector2(0.0, FIRE_FLOOR_SNAP), FIRE_FLOOR_MASK)
	return space.intersect_ray(query)

# Host: nach add_child() und Positionierung aufrufen. Tastet den Boden ab und
# hängt die Zone an ein bewegliches Map-Objekt, falls sie darauf liegt.
func setup_fire_host(hit: Dictionary) -> void:
	_scan_fire_floor()
	if hit.is_empty() or hit.get("collider") is StaticBody2D:
		return
	var obj := _moving_object_of(hit.get("collider") as Node)
	if obj == null:
		return
	var body := _carrier_body_of(obj)
	if body == null:
		return
	carrier_id = int(obj.get("net_id"))
	carrier_local_pos = body.to_local(global_position)
	carrier_local_rot = global_rotation - body.global_rotation
	_carrier = body
	_carrier_resolved = true

# Daten für die Netzwerk-Replik (an send_zone_spawn anhängen).
func fire_network_data() -> Dictionary:
	return {
		"cols": _fire_columns,
		"carrier_id": carrier_id,
		"carrier_pos": carrier_local_pos,
		"carrier_rot": carrier_local_rot,
	}

# Client: Bodenspalten und Träger vom Host übernehmen. Bewegliche Objekte
# kollidieren auf Clients nicht, eigenes Abtasten fände sie also nicht.
func apply_fire_network_data(data: Dictionary) -> void:
	var cols = data.get("cols", null)
	if cols is PackedFloat32Array and not (cols as PackedFloat32Array).is_empty():
		_fire_columns = cols
		_fire_scanned = true
	carrier_id = int(data.get("carrier_id", -1))
	carrier_local_pos = data.get("carrier_pos", Vector2.ZERO)
	carrier_local_rot = float(data.get("carrier_rot", 0.0))

static func _moving_object_of(node: Node) -> Node:
	var n := node
	for i in 4:
		if n == null:
			return null
		if n.has_method("get_network_state") and n.get("net_id") != null:
			return n
		n = n.get_parent()
	return null

static func _carrier_body_of(obj: Node) -> Node2D:
	for prop in ["body", "plank", "platform"]:
		var b = obj.get(prop)
		if b is Node2D and is_instance_valid(b):
			return b
	return obj as Node2D

func _follow_carrier() -> void:
	if carrier_id < 0:
		return
	if not _carrier_resolved:
		_carrier_resolved = true
		var scene := get_tree().current_scene
		var gen = scene.get("level_generator") if scene != null else null
		if gen != null and is_instance_valid(gen) and gen.has_method("get_moving_object"):
			var obj = gen.get_moving_object(carrier_id)
			if obj != null:
				_carrier = _carrier_body_of(obj)
	if _carrier == null or not is_instance_valid(_carrier) or _carrier.is_queued_for_deletion():
		# Träger zerstört (z. B. Kiste): Feuer bleibt an der letzten Stelle.
		carrier_id = -1
		_carrier = null
		return
	global_position = _carrier.to_global(carrier_local_pos)
	global_rotation = _carrier.global_rotation + carrier_local_rot

func _scan_fire_floor() -> void:
	_fire_scanned = true
	var cols := maxi(5, int(radius / 7.0))
	_fire_columns.resize(cols)
	var space := get_world_2d().direct_space_state
	var any_hit := false
	for i in cols:
		_fire_columns[i] = NAN
		if space == null:
			continue
		var x := lerpf(-radius, radius, float(i) / float(cols - 1))
		var from := global_position + Vector2(x, -18.0)
		var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 40.0), FIRE_FLOOR_MASK)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			_fire_columns[i] = NAN
		else:
			_fire_columns[i] = (hit["position"] as Vector2).y - global_position.y
			any_hit = true
	# Kein Boden in der Nähe: dann brennt die Lache einfach an Ort und Stelle.
	if not any_hit:
		for i in cols:
			_fire_columns[i] = 0.0

func _draw() -> void:
	match kind:
		Kind.FIRE:
			_draw_fire()
		Kind.LIGHTNING:
			_draw_lightning()
		Kind.POISON:
			_draw_poison()
		Kind.VOID:
			_draw_void()
		Kind.HEAL:
			draw_heal(self, radius, _anim_time, _phase, _offset)
		_:
			_draw_ice()

# --- Feuer: brennende Lache auf dem Boden ---

func _draw_fire() -> void:
	if _fire_columns.is_empty():
		return
	var t := _anim_time
	var grow := clampf(_elapsed / 0.18, 0.15, 1.0)
	var cols := _fire_columns.size()
	var col_w := (radius * 2.0) / float(cols - 1)

	# Lache: flacher, glimmender Brennstoff-Streifen pro Bodenabschnitt.
	for i in cols:
		var y := _fire_columns[i]
		if is_nan(y):
			continue
		var x := lerpf(-radius, radius, float(i) / float(cols - 1))
		var edge := 1.0 - absf(x) / (radius + col_w)
		draw_rect(Rect2(x - col_w * 0.5, y - 2.5, col_w, 4.0), Color(0.30, 0.06, 0.02, 0.55 * edge))
		draw_rect(Rect2(x - col_w * 0.5, y - 5.0, col_w, 3.0), Color(1.0, 0.45, 0.08, (0.25 + 0.1 * sin(t * 9.0 + x)) * edge))

	# Flammenzungen, die von der Oberfläche aufsteigen.
	var flames := cols
	for i in flames:
		var y := _fire_columns[i]
		if is_nan(y):
			continue
		var ph: float = _phase[i % _phase.size()] * TAU
		var x := lerpf(-radius, radius, float(i) / float(cols - 1)) + _offset[i % _offset.size()] * col_w * 0.3
		var edge := 1.0 - pow(absf(x) / (radius + col_w), 2.0)
		var flicker := 0.65 + 0.25 * sin(t * 8.0 + ph) + 0.12 * sin(t * 19.0 + ph * 2.3)
		var h := clampf(radius * 0.5, 14.0, 34.0) * flicker * (0.45 + 0.55 * edge) * grow
		var w := col_w * 1.5
		var sway := sin(t * 5.0 + ph) * w * 0.35
		_draw_flame(Vector2(x, y), w, h, sway, Color(0.95, 0.18, 0.04, 0.75))
		_draw_flame(Vector2(x, y), w * 0.68, h * 0.72, sway * 0.8, Color(1.0, 0.55, 0.08, 0.85))
		_draw_flame(Vector2(x, y), w * 0.36, h * 0.42, sway * 0.6, Color(1.0, 0.92, 0.45, 0.9))

	# Ein paar Funken steigen auf.
	var embers := clampi(int(radius / 9.0), 2, 8)
	for i in embers:
		var col := int(_phase[(i + 7) % _phase.size()] * float(cols)) % cols
		var y0 := _fire_columns[col]
		if is_nan(y0):
			continue
		var s := fposmod(t * 0.9 + _phase[i], 1.0)
		var x0 := lerpf(-radius, radius, float(col) / float(cols - 1))
		var p := Vector2(x0 + sin(t * 3.0 + float(i)) * 5.0, y0 - 8.0 - s * radius * 0.9)
		draw_circle(p, 1.6, Color(1.0, 0.75, 0.25, (1.0 - s) * 0.9))

func _draw_flame(base: Vector2, w: float, h: float, sway: float, color: Color) -> void:
	if h < 1.0:
		return
	var pts := PackedVector2Array([
		base + Vector2(-w * 0.5, 0.0),
		base + Vector2(-w * 0.42 + sway * 0.3, -h * 0.4),
		base + Vector2(sway, -h),
		base + Vector2(w * 0.42 + sway * 0.3, -h * 0.4),
		base + Vector2(w * 0.5, 0.0),
	])
	draw_colored_polygon(pts, color)

# --- Blitz: knisternde Fläche ---

func _regenerate_lightning() -> void:
	_bolts.clear()
	var bolt_count := 2 + int(radius / 30.0)
	for b in bolt_count:
		var start := Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.0, 0.3)
		var end := Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.75, 1.0)
		var bolt := _jagged_line(start, end, 6, radius * 0.13)
		_bolts.append(bolt)
		# Kleine Verästelung von der Mitte des Blitzes.
		if _rng.randf() < 0.7:
			var mid := bolt[3]
			var branch_end := mid + (end - start).rotated(_rng.randf_range(-0.9, 0.9)).normalized() * radius * 0.35
			_bolts.append(_jagged_line(mid, branch_end, 3, radius * 0.07))
	_sparks.clear()
	for s in 5:
		_sparks.append(Vector2.from_angle(_rng.randf() * TAU) * radius * sqrt(_rng.randf()))
	_rim.clear()
	var rim_segments := 28
	for i in rim_segments + 1:
		var a := TAU * float(i) / float(rim_segments)
		_rim.append(Vector2.from_angle(a) * radius * _rng.randf_range(0.94, 1.04))

func _jagged_line(from: Vector2, to: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from])
	var normal := (to - from).orthogonal().normalized()
	for i in range(1, segments):
		var p := from.lerp(to, float(i) / float(segments))
		pts.append(p + normal * _rng.randf_range(-jitter, jitter))
	pts.append(to)
	return pts

func _draw_lightning() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.9, 0.25, 0.07))
	if _rim.size() > 1:
		draw_polyline(_rim, Color(1.0, 0.95, 0.45, 0.45), 1.5, true)
	for bolt in _bolts:
		draw_polyline(bolt, Color(1.0, 0.85, 0.2, 0.3), 5.0, true)
		draw_polyline(bolt, Color(1.0, 1.0, 0.85, 0.95), 1.6, true)
	for p in _sparks:
		draw_circle(p, 1.8, Color(1.0, 1.0, 0.7, 0.9))

# --- Gift: kleine Wolke ---

func _draw_poison() -> void:
	var t := _anim_time
	var grow := clampf(_elapsed / 0.25, 0.3, 1.0)
	var puffs := 6 + clampi(int(radius / 15.0), 0, 5)
	var centers: Array[Vector2] = []
	var sizes: Array[float] = []
	for i in puffs:
		var u := float(i) / float(puffs - 1) * 2.0 - 1.0 # -1..1
		var bump := 1.0 - u * u
		var c := Vector2(
			u * radius * 0.78 + _offset[i] * radius * 0.06,
			radius * 0.12 - bump * radius * 0.42 * (0.6 + 0.4 * _phase[i]) + sin(t * 1.6 + _phase[i] * TAU) * 2.0
		)
		var r := radius * (0.24 + 0.2 * bump) * (1.0 + 0.06 * sin(t * 2.2 + _phase[i] * 5.0)) * grow
		centers.append(c)
		sizes.append(r)
	# Unterkante: zwei flache Puffs, damit die Wolke einen Boden hat.
	for i in 2:
		centers.append(Vector2((float(i) - 0.5) * radius * 0.7, radius * 0.22))
		sizes.append(radius * 0.3 * grow)

	for i in centers.size():
		draw_circle(centers[i], sizes[i] + 2.5, Color(0.16, 0.42, 0.08, 0.6))
	for i in centers.size():
		draw_circle(centers[i], sizes[i], Color(0.42, 0.80, 0.20, 0.62))
	for i in centers.size():
		draw_circle(centers[i] + Vector2(-sizes[i] * 0.25, -sizes[i] * 0.3), sizes[i] * 0.45, Color(0.72, 1.0, 0.45, 0.28))

	# Giftblasen steigen aus der Wolke und platzen.
	for i in 4:
		var s := fposmod(t * 0.55 + _phase[i + 10], 1.0)
		var p := Vector2(_offset[i + 10] * radius * 0.7, -radius * 0.25 - s * radius * 0.7)
		draw_arc(p, 2.0 + s * 2.0, 0.0, TAU, 10, Color(0.6, 1.0, 0.35, (1.0 - s) * 0.8), 1.2, true)

# --- Void: schwarzes Loch, das alles nach innen saugt ---

func _draw_void() -> void:
	var t := _anim_time
	var appear := clampf(_elapsed / 0.3, 0.0, 1.0)
	var collapse := clampf((duration - _elapsed) / 0.35, 0.0, 1.0)
	var k := appear * collapse
	if k <= 0.0:
		return
	var r := radius * k

	draw_circle(Vector2.ZERO, r * 1.7, Color(0.22, 0.04, 0.35, 0.16))
	draw_circle(Vector2.ZERO, r * 1.15, Color(0.30, 0.08, 0.50, 0.22))

	# Materie strudelt spiralförmig hinein.
	var streams := 20
	for i in streams:
		var s := fposmod(t * 0.6 + _phase[i], 1.0)
		var dist := lerpf(r * 3.0, r * 0.42, pow(s, 0.8))
		var ang := _offset[i] * PI + s * 5.0 + t * 1.2
		var p := Vector2.from_angle(ang) * dist
		var tail := Vector2.from_angle(ang - 0.35) * (dist + 10.0 * (1.0 - s) + 4.0)
		var c := Color(0.85, 0.6, 1.0, 0.25 + 0.65 * s)
		draw_line(tail, p, c, 1.5 + s, true)

	# Akkretionsscheibe: rotierende Bögen.
	for j in 4:
		var rr := r * (0.55 + 0.12 * float(j))
		var start := t * (3.2 - float(j) * 0.5) + float(j) * 1.7
		var col := Color(0.75 - 0.1 * float(j), 0.35, 1.0, 0.85 - 0.15 * float(j))
		draw_arc(Vector2.ZERO, rr, start, start + PI * 0.9, 18, col, 2.5, true)
		draw_arc(Vector2.ZERO, rr, start + PI, start + PI * 1.6, 12, col, 2.0, true)

	# Ereignishorizont.
	draw_circle(Vector2.ZERO, r * 0.44, Color(0.0, 0.0, 0.0, 1.0))
	draw_arc(Vector2.ZERO, r * 0.46, 0.0, TAU, 32, Color(0.9, 0.7, 1.0, 0.9), 1.8, true)

# --- Heilung: aufsteigende grüne Pluszeichen ---
# Statisch, damit auch die wandernde Heilzone der Level-Modifikatoren sie nutzt.

static func draw_heal(ci: CanvasItem, r: float, t: float, phase: Array[float], offset: Array[float]) -> void:
	var pulse := 1.0 + sin(t * 3.0) * 0.04
	ci.draw_circle(Vector2.ZERO, r * pulse, Color(0.25, 0.95, 0.45, 0.10))
	ci.draw_circle(Vector2.ZERO, r * 0.6 * pulse, Color(0.35, 1.0, 0.55, 0.08))
	ci.draw_arc(Vector2.ZERO, r * pulse, 0.0, TAU, 40, Color(0.45, 1.0, 0.6, 0.55), 2.0, true)

	var count := mini(phase.size(), 6 + int(r / 12.0))
	for i in count:
		var cycle_pos := t * 0.45 + phase[i]
		var s := fposmod(cycle_pos, 1.0)
		# Bei jedem neuen Durchlauf startet das Plus an einer anderen Stelle.
		var cycle := floorf(cycle_pos)
		var rnd := fposmod(sin(float(i) * 12.9898 + cycle * 78.233) * 43758.5453, 1.0)
		var x := (rnd * 2.0 - 1.0) * r * 0.75 + sin(t * 2.0 + phase[i] * 6.0) * 4.0 + offset[i] * 3.0
		var y := r * 0.45 - s * r * 1.35
		var alpha := sin(s * PI)
		var size := 3.0 + 2.5 * fposmod(rnd * 7.0, 1.0)
		var th := size * 0.42
		var col := Color(0.4, 1.0, 0.5, 0.9 * alpha)
		ci.draw_rect(Rect2(x - th * 0.5, y - size, th, size * 2.0), col)
		ci.draw_rect(Rect2(x - size, y - th * 0.5, size * 2.0, th), col)

# --- Eis: unverändert schlicht ---

func _draw_ice() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.35, 0.75, 1.0, 0.20))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.60, 0.90, 1.0, 0.65), 2.0)
