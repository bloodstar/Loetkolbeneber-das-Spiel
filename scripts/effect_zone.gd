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
	HEAL,
	# Element-Reaktionen (ElementReactions):
	STEAM,       # Dampfwolke: Feuer trifft Eis
	PLASMA,      # Plasmafeld: Blitz trifft Feuer
	RIME,        # Giftreif: Frost trifft Giftwolke, liegt am Boden
	TOXIC_STORM, # Giftgewitter: Blitz trifft Giftwolke
	BLIZZARD,    # Flockes Ulti (nur Optik, Logik in FlockeBlizzard)
}

# Arten, die wie Feuer auf den Boden darunter fallen (Seitenansicht).
static func is_floor_kind(k: int) -> bool:
	return k == Kind.FIRE or k == Kind.PLASMA or k == Kind.RIME

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
## Arena: Bodenhöhe unter der Fläche (Plattform, Plateau). Nur Optik: die
## Fläche wird um den Höhenversatz nach oben gezeichnet, damit sie auf der
## Plattform liegt statt versetzt darunter.
var ground_z: float = 0.0
# Nur Optik (Void, Heilung, Sporenwolke): die Wirkung berechnet der Spieler selbst.
var visual_only: bool = false
# Gasbrand (eigener Build): Diese Giftwolke brennt zusätzlich.
var also_burn: bool = false
# Diese Zone löst keine Element-Reaktion aus (z. B. die Blitzfelder des Supraleiters).
var no_react: bool = false

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
	z_index = 4 if kind == Kind.STEAM else (3 if kind == Kind.BLIZZARD else -2)
	add_to_group("effect_zone")
	if no_react:
		set_meta("reacted", true)
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
	if is_floor_kind(kind) and not _fire_scanned:
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
	if kind == Kind.LIGHTNING or kind == Kind.TOXIC_STORM:
		_bolt_timer -= delta
		if _bolt_timer <= 0.0:
			_bolt_timer = LIGHTNING_REFRESH
			_regenerate_lightning()
	queue_redraw()

func _apply_tick() -> void:
	# Horden-Modus: Zonen wirken auf alle Gegner in ihrem Radius.
	if HordeDirector.is_active():
		for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
			var e := node as HordeEnemy
			if e != null and e.is_alive() and not e.is_replica \
					and global_position.distance_to(e.global_position) <= radius + e.radius:
				_apply_effect_to(e)
	if not is_instance_valid(target) or target.current_health <= 0.0:
		return
	if global_position.distance_to(target.global_position) > radius + 12.0:
		return
	_apply_effect_to(target)

func _apply_effect_to(target) -> void:
	# Die Quelle geht mit, damit Element-Reaktionen am Ziel auslösen können.
	var src: Player = owner_player if is_instance_valid(owner_player) and not no_react else null
	match kind:
		Kind.POISON:
			target.apply_poison(poison_stacks, poison_damage, src)
			if also_burn and is_instance_valid(owner_player):
				target.apply_burn(1, owner_player.burn_damage_per_tick)
		Kind.FIRE:
			target.apply_burn(burn_stacks, burn_damage, src)
		Kind.ICE:
			target.apply_freeze(freeze_duration, src)
		Kind.LIGHTNING:
			_deal_zone_damage(target)
			target.apply_stun(stun_duration, src)
		Kind.STEAM:
			_deal_zone_damage(target)
		Kind.PLASMA:
			_deal_zone_damage(target)
			target.apply_burn(burn_stacks, burn_damage)
			target.apply_stun(stun_duration)
		Kind.RIME:
			target.apply_poison(poison_stacks, poison_damage)
			target.apply_freeze(freeze_duration)
		Kind.TOXIC_STORM:
			_deal_zone_damage(target)
			target.apply_poison(poison_stacks, poison_damage)
			target.apply_stun(stun_duration)

func _deal_zone_damage(target) -> void:
	if damage <= 0.0:
		return
	var tag := from_ability and is_instance_valid(owner_player)
	if tag:
		owner_player.dealing_ability_damage = true
	target.take_damage(damage, Vector2.ZERO, owner_player if is_instance_valid(owner_player) else null)
	if tag and is_instance_valid(owner_player):
		owner_player.dealing_ability_damage = false

# Host: Zone vorzeitig beenden (verbraucht von einer Element-Reaktion). Clients
# entfernen ihre Replik über NetworkManager.send_zone_end.
func end_zone() -> void:
	if is_queued_for_deletion():
		return
	if not is_replica and Global.network_mode and NetworkManager.is_host:
		NetworkManager.send_zone_end(int(kind), global_position)
	queue_free()

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
	# Arena (Draufsicht): Der Boden ist überall, Feuer brennt an Ort und Stelle.
	if space == null or ArenaMode.active:
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
	if ArenaMode.active:
		space = null
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
	if ground_z > 0.0 and ArenaMode.active:
		draw_set_transform(ArenaMode.height_offset(ground_z))
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
		Kind.STEAM:
			_draw_steam()
		Kind.PLASMA:
			_draw_fire(PLASMA_PALETTE)
		Kind.RIME:
			_draw_rime()
		Kind.TOXIC_STORM:
			_draw_poison()
			_draw_storm_bolts()
		Kind.BLIZZARD:
			_draw_blizzard()
		_:
			_draw_ice()
	if also_burn and kind == Kind.POISON:
		_draw_burning_cloud_rim()

# --- Feuer: brennende Lache auf dem Boden ---

const FIRE_PALETTE: Array[Color] = [
	Color(0.95, 0.18, 0.04, 0.75), Color(1.0, 0.55, 0.08, 0.85), Color(1.0, 0.92, 0.45, 0.9),
	Color(0.30, 0.06, 0.02, 0.55), Color(1.0, 0.45, 0.08, 1.0), Color(1.0, 0.75, 0.25, 0.9),
]
# Plasmafeld: dieselben Flammen in Violett und Pink.
const PLASMA_PALETTE: Array[Color] = [
	Color(0.62, 0.10, 0.95, 0.75), Color(0.95, 0.35, 1.0, 0.85), Color(1.0, 0.85, 1.0, 0.9),
	Color(0.18, 0.02, 0.30, 0.55), Color(0.85, 0.35, 1.0, 1.0), Color(1.0, 0.7, 1.0, 0.9),
]

func _draw_fire(palette: Array[Color] = FIRE_PALETTE) -> void:
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
		var pool_c: Color = palette[3]
		var glow_c: Color = palette[4]
		draw_rect(Rect2(x - col_w * 0.5, y - 2.5, col_w, 4.0), Color(pool_c.r, pool_c.g, pool_c.b, pool_c.a * edge))
		draw_rect(Rect2(x - col_w * 0.5, y - 5.0, col_w, 3.0), Color(glow_c.r, glow_c.g, glow_c.b, (0.25 + 0.1 * sin(t * 9.0 + x)) * edge))

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
		_draw_flame(Vector2(x, y), w, h, sway, palette[0])
		_draw_flame(Vector2(x, y), w * 0.68, h * 0.72, sway * 0.8, palette[1])
		_draw_flame(Vector2(x, y), w * 0.36, h * 0.42, sway * 0.6, palette[2])

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
		var ember: Color = palette[5]
		draw_circle(p, 1.6, Color(ember.r, ember.g, ember.b, (1.0 - s) * 0.9))

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

# --- Element-Reaktionen ---

# Dampfwolke: weiße Schwaden, die langsam aufsteigen und Spieler halb verdecken.
func _draw_steam() -> void:
	var t := _anim_time
	var grow := clampf(_elapsed / 0.3, 0.3, 1.0)
	var puffs := 7 + clampi(int(radius / 14.0), 0, 6)
	# In der Seitenansicht steigt der Dampf auf, in der Draufsicht wabert er.
	var rise := 0.0 if ArenaMode.active else 1.0
	for i in puffs:
		var ph: float = _phase[i % _phase.size()]
		var s := fposmod(t * 0.35 + ph, 1.0)
		var u: float = _offset[i % _offset.size()]
		var c := Vector2(u * radius * 0.8 + sin(t * 1.3 + ph * TAU) * 4.0,
				radius * 0.2 - s * radius * 0.9 * rise + cos(t + ph * 5.0) * 3.0 * (1.0 - rise))
		var r := radius * (0.28 + 0.18 * sin(s * PI)) * grow
		draw_circle(c, r, Color(0.92, 0.95, 1.0, 0.36 * sin(s * PI) + 0.12))
	draw_circle(Vector2.ZERO, radius * 0.75 * grow, Color(0.95, 0.97, 1.0, 0.16))

# Blizzard: kalter Schleier, wirbelnde Schneeflocken und Windböen.
func _draw_blizzard() -> void:
	var t := _anim_time
	var grow := clampf(_elapsed / 0.4, 0.2, 1.0)
	var r := radius * grow
	draw_circle(Vector2.ZERO, r, Color(0.78, 0.9, 1.0, 0.16))
	draw_circle(Vector2.ZERO, r * 0.7, Color(0.9, 0.96, 1.0, 0.1))
	draw_arc(Vector2.ZERO, r, t * 0.8, t * 0.8 + TAU * 0.8, 40, Color(0.85, 0.95, 1.0, 0.55), 2.0)
	# Windböen: Bogenstücke, die um die Mitte kreisen.
	for i in 5:
		var a := t * 2.2 + float(i) * TAU / 5.0
		var rr := r * (0.35 + 0.12 * float(i % 3))
		draw_arc(Vector2.ZERO, rr, a, a + 0.9, 10, Color(0.95, 0.98, 1.0, 0.35), 2.5)
	# Flocken: fallen schräg und wirbeln mit (Seitenansicht), kreisen in der Draufsicht.
	var flakes := 26 + clampi(int(radius / 6.0), 0, 30)
	var fall := 0.0 if ArenaMode.active else 1.0
	for i in flakes:
		var ph: float = _phase[i % _phase.size()] + float(i) * 0.137
		var u: float = _offset[i % _offset.size()]
		var s := fposmod(t * (0.5 + 0.3 * fposmod(ph, 1.0)) + ph, 1.0)
		var ang := ph * TAU + t * (1.2 + 0.4 * u)
		var dist := r * (0.15 + 0.8 * fposmod(ph * 3.1, 1.0))
		var p := Vector2(cos(ang), sin(ang)) * dist * (1.0 - fall * 0.4)
		p += Vector2(sin(t * 3.0 + ph * 9.0) * 6.0 - s * 18.0, -r * 0.8 + s * r * 1.6) * fall
		if p.length() > r:
			continue
		var size := 1.2 + 1.3 * fposmod(ph * 7.3, 1.0)
		var alpha := 0.85 * sin(s * PI)
		draw_circle(p, size, Color(1.0, 1.0, 1.0, alpha))
		if size > 2.0:
			draw_line(p - Vector2(size + 1.0, 0.0), p + Vector2(size + 1.0, 0.0), Color(1, 1, 1, alpha * 0.8), 1.0)
			draw_line(p - Vector2(0.0, size + 1.0), p + Vector2(0.0, size + 1.0), Color(1, 1, 1, alpha * 0.8), 1.0)

# Giftreif: grünlich gefrorene Schicht am Boden mit kleinen Eiszacken.
func _draw_rime() -> void:
	if _fire_columns.is_empty():
		draw_circle(Vector2.ZERO, radius, Color(0.55, 0.95, 0.7, 0.22))
		return
	var t := _anim_time
	var cols := _fire_columns.size()
	var col_w := (radius * 2.0) / float(cols - 1)
	for i in cols:
		var y := _fire_columns[i]
		if is_nan(y):
			continue
		var x := lerpf(-radius, radius, float(i) / float(cols - 1))
		var edge := 1.0 - absf(x) / (radius + col_w)
		draw_rect(Rect2(x - col_w * 0.5, y - 3.0, col_w, 4.0), Color(0.45, 0.85, 0.55, 0.6 * edge))
		draw_rect(Rect2(x - col_w * 0.5, y - 4.5, col_w, 1.5), Color(0.85, 1.0, 0.95, 0.75 * edge))
		var spike := (4.0 + 5.0 * _phase[i % _phase.size()]) * edge
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 2.5, y - 3.0), Vector2(x, y - 3.0 - spike), Vector2(x + 2.5, y - 3.0)
		]), Color(0.8, 1.0, 0.9, 0.7 * edge))
		# Giftblasen unter dem Eis.
		if i % 3 == 0:
			var s := fposmod(t * 0.5 + _phase[i % _phase.size()], 1.0)
			draw_circle(Vector2(x, y - 1.5), 1.2 + s * 1.5, Color(0.5, 1.0, 0.3, (1.0 - s) * 0.7))

# Giftgewitter: Blitze in der Giftwolke.
func _draw_storm_bolts() -> void:
	for bolt in _bolts:
		draw_polyline(bolt, Color(0.85, 1.0, 0.3, 0.35), 4.0, true)
		draw_polyline(bolt, Color(1.0, 1.0, 0.75, 0.95), 1.4, true)

# Gasbrand: Die Giftwolke glimmt am Rand orange.
func _draw_burning_cloud_rim() -> void:
	var t := _anim_time
	for i in 6:
		var a := TAU * float(i) / 6.0 + t * 0.7
		var p := Vector2.from_angle(a) * radius * 0.7
		draw_circle(p, 2.0 + sin(t * 6.0 + float(i)) * 0.8, Color(1.0, 0.55, 0.15, 0.85))
