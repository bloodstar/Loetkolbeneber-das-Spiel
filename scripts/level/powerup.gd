class_name Powerup
extends Area2D

const KIND_HEAL: String = "heal"
const KIND_INVULNERABILITY: String = "invulnerability"
const KIND_DAMAGE: String = "damage"
const KIND_RAPID_FIRE: String = "rapid_fire"
const KIND_AUTO_ATTACK: String = "auto_attack"
const KIND_MULTISHOT: String = "multishot"
const KIND_UNDYING: String = "undying"
const KIND_REVENGE: String = "revenge"
const KIND_INVISIBLE: String = "invisible"
const KINDS: Array[String] = [
	KIND_HEAL,
	KIND_INVULNERABILITY,
	KIND_DAMAGE,
	KIND_RAPID_FIRE,
	KIND_AUTO_ATTACK,
	KIND_MULTISHOT,
	KIND_UNDYING,
	KIND_REVENGE,
	KIND_INVISIBLE,
]

var net_id: int = 0
var object_type: String = "powerup"
var is_replica: bool = false
var kind: String = KIND_HEAL

# Sammelreichweite (Karte Powerup-Magnet): Spieler mit Bonusreichweite ziehen
# das Powerup aus dieser Entfernung zu sich. Grundabstand = Pickup-Radius plus
# ungefährer Körperradius.
const MAGNET_BASE_REACH: float = 40.0
const MAGNET_PULL_SPEED: float = 720.0

var _visual_root: Node2D
var _bob_time: float = 0.0
var _collected: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_collision()
	_build_visual()
	body_entered.connect(_on_body_entered)
	if is_replica:
		set_replica(true)

func _process(delta: float) -> void:
	_bob_time += delta
	if _visual_root != null:
		_visual_root.position.y = sin(_bob_time * 3.2) * 5.0
		_visual_root.rotation = sin(_bob_time * 1.7) * 0.08

func _physics_process(delta: float) -> void:
	if is_replica or _collected:
		return
	var target := _magnet_target()
	if target == null:
		return
	var to_target := target.global_position - global_position
	var step := MAGNET_PULL_SPEED * delta
	if to_target.length() <= maxf(step, 18.0):
		_collect(target)
		return
	global_position += to_target.normalized() * step

# Nächster lebender Spieler, dessen Powerup-Sammelreichweite uns erreicht.
func _magnet_target() -> Player:
	var best: Player = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Player
		if player == null or player.powerup_pickup_range <= 0.0 or player.current_health <= 0.0:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist <= MAGNET_BASE_REACH + player.powerup_pickup_range and dist < best_dist:
			best = player
			best_dist = dist
	return best

func _build_collision() -> void:
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	add_child(col)

func _build_visual() -> void:
	_visual_root = Node2D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	var color := _kind_color()
	var glow := Polygon2D.new()
	glow.polygon = _circle_points(24.0, 24)
	glow.color = Color(color.r, color.g, color.b, 0.18)
	_visual_root.add_child(glow)

	var ring := Line2D.new()
	ring.points = _circle_points(18.0, 24)
	ring.width = 3.0
	ring.default_color = color
	_visual_root.add_child(ring)

	var core := Polygon2D.new()
	core.polygon = _circle_points(12.0, 20)
	core.color = color.darkened(0.18)
	_visual_root.add_child(core)

	var icon := Node2D.new()
	icon.name = "Icon"
	_visual_root.add_child(icon)
	_build_icon(icon, color)

	var label := Label.new()
	label.text = _kind_label()
	label.position = Vector2(-36.0, 24.0)
	label.size = Vector2(72.0, 16.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.88, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.08, 0.1, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	_visual_root.add_child(label)

func _build_icon(icon: Node2D, color: Color) -> void:
	match kind:
		KIND_HEAL:
			var vertical := Polygon2D.new()
			vertical.polygon = PackedVector2Array([
				Vector2(-4, -11), Vector2(4, -11), Vector2(4, 11), Vector2(-4, 11),
			])
			vertical.color = Color(0.94, 1.0, 0.94, 1.0)
			icon.add_child(vertical)
			var horizontal := Polygon2D.new()
			horizontal.polygon = PackedVector2Array([
				Vector2(-11, -4), Vector2(11, -4), Vector2(11, 4), Vector2(-11, 4),
			])
			horizontal.color = Color(0.94, 1.0, 0.94, 1.0)
			icon.add_child(horizontal)
		KIND_INVULNERABILITY:
			var shield := Polygon2D.new()
			shield.polygon = PackedVector2Array([
				Vector2(0, -12), Vector2(10, -7), Vector2(8, 6),
				Vector2(0, 13), Vector2(-8, 6), Vector2(-10, -7),
			])
			shield.color = Color(0.9, 0.98, 1.0, 1.0)
			icon.add_child(shield)
			var inner := Polygon2D.new()
			inner.polygon = PackedVector2Array([
				Vector2(0, -7), Vector2(5, -4), Vector2(0, 7), Vector2(-5, -4),
			])
			inner.color = color.darkened(0.2)
			icon.add_child(inner)
		KIND_DAMAGE:
			var bolt := Polygon2D.new()
			bolt.polygon = PackedVector2Array([
				Vector2(-3, -12), Vector2(9, -12), Vector2(1, -2),
				Vector2(8, -2), Vector2(-7, 13), Vector2(-2, 1), Vector2(-9, 1),
			])
			bolt.color = Color(1.0, 0.94, 0.72, 1.0)
			icon.add_child(bolt)
		KIND_RAPID_FIRE:
			for i in range(3):
				var shot := Polygon2D.new()
				shot.polygon = PackedVector2Array([
					Vector2(-9.0 + float(i) * 5.0, -9.0),
					Vector2(-3.0 + float(i) * 5.0, -9.0),
					Vector2(-5.0 + float(i) * 5.0, 9.0),
					Vector2(-11.0 + float(i) * 5.0, 9.0),
				])
				shot.color = Color(1.0, 0.95, 0.72, 1.0)
				icon.add_child(shot)
		KIND_AUTO_ATTACK:
			# Zwei gekreuzte Klingen.
			for side in [-1.0, 1.0]:
				var blade := Polygon2D.new()
				blade.polygon = PackedVector2Array([
					Vector2(-1.6, -12), Vector2(1.6, -12), Vector2(1.6, 6), Vector2(-1.6, 6),
				])
				blade.color = Color(0.96, 0.94, 1.0, 1.0)
				blade.rotation = deg_to_rad(40.0 * side)
				icon.add_child(blade)
				var guard := Polygon2D.new()
				guard.polygon = PackedVector2Array([
					Vector2(-5, 5), Vector2(5, 5), Vector2(5, 8), Vector2(-5, 8),
				])
				guard.color = color.darkened(0.35)
				guard.rotation = deg_to_rad(40.0 * side)
				icon.add_child(guard)
		KIND_MULTISHOT:
			# Drei Geschosse im Fächer.
			for angle in [-28.0, 0.0, 28.0]:
				var shot := Polygon2D.new()
				shot.polygon = PackedVector2Array([
					Vector2(-2.5, 2), Vector2(2.5, 2), Vector2(2.5, -7), Vector2(0, -12), Vector2(-2.5, -7),
				])
				shot.color = Color(0.9, 1.0, 0.97, 1.0)
				shot.position = Vector2(0, 8)
				shot.rotation = deg_to_rad(angle)
				icon.add_child(shot)
		KIND_UNDYING:
			# Herz mit Heiligenschein.
			var halo := Line2D.new()
			halo.points = PackedVector2Array([
				Vector2(-7, -11), Vector2(-3, -13), Vector2(3, -13), Vector2(7, -11),
			])
			halo.width = 2.0
			halo.default_color = Color(1.0, 1.0, 0.85, 1.0)
			icon.add_child(halo)
			var heart := Polygon2D.new()
			heart.polygon = PackedVector2Array([
				Vector2(0, 10), Vector2(-9, 0), Vector2(-9, -5), Vector2(-5, -8),
				Vector2(0, -4), Vector2(5, -8), Vector2(9, -5), Vector2(9, 0),
			])
			heart.color = Color(1.0, 0.98, 0.9, 1.0)
			icon.add_child(heart)
		KIND_REVENGE:
			# Dornenkranz: Stacheln rundherum.
			var thorns := Polygon2D.new()
			var points := PackedVector2Array()
			for i in range(16):
				var a := TAU * float(i) / 16.0
				var r := 12.0 if i % 2 == 0 else 6.0
				points.append(Vector2(cos(a), sin(a)) * r)
			thorns.polygon = points
			thorns.color = Color(1.0, 0.85, 0.85, 1.0)
			icon.add_child(thorns)
		KIND_INVISIBLE:
			# Halb durchsichtiges Auge mit Querstrich.
			var eye := Polygon2D.new()
			eye.polygon = PackedVector2Array([
				Vector2(-11, 0), Vector2(-5, -6), Vector2(5, -6), Vector2(11, 0), Vector2(5, 6), Vector2(-5, 6),
			])
			eye.color = Color(0.95, 0.96, 1.0, 0.55)
			icon.add_child(eye)
			var pupil := Polygon2D.new()
			pupil.polygon = _circle_points(3.5, 12)
			pupil.color = color.darkened(0.4)
			icon.add_child(pupil)
			var strike := Line2D.new()
			strike.points = PackedVector2Array([Vector2(-10, 9), Vector2(10, -9)])
			strike.width = 2.5
			strike.default_color = Color(1.0, 1.0, 1.0, 0.95)
			icon.add_child(strike)

func _kind_color() -> Color:
	match kind:
		KIND_INVULNERABILITY:
			return Color(0.32, 0.72, 1.0, 1.0)
		KIND_DAMAGE:
			return Color(1.0, 0.38, 0.22, 1.0)
		KIND_RAPID_FIRE:
			return Color(1.0, 0.78, 0.22, 1.0)
		KIND_AUTO_ATTACK:
			return Color(0.78, 0.4, 1.0, 1.0)
		KIND_MULTISHOT:
			return Color(0.22, 0.9, 0.78, 1.0)
		KIND_UNDYING:
			return Color(1.0, 0.88, 0.45, 1.0)
		KIND_REVENGE:
			return Color(0.9, 0.12, 0.28, 1.0)
		KIND_INVISIBLE:
			return Color(0.55, 0.58, 0.75, 1.0)
		_:
			return Color(0.35, 1.0, 0.48, 1.0)

func _kind_label() -> String:
	match kind:
		KIND_INVULNERABILITY:
			return "SCHUTZ"
		KIND_DAMAGE:
			return "SCHADEN"
		KIND_RAPID_FIRE:
			return "DAUERFEUER"
		KIND_AUTO_ATTACK:
			return "AUTO-ANGRIFF"
		KIND_MULTISHOT:
			return "MULTISHOT"
		KIND_UNDYING:
			return "UNSTERBLICH"
		KIND_REVENGE:
			return "RACHE"
		KIND_INVISIBLE:
			return "UNSICHTBAR"
		_:
			return "HEILUNG"

func _on_body_entered(body: Node2D) -> void:
	if is_replica or _collected:
		return
	if not (body is Player):
		return
	_collect(body as Player)

func _collect(player: Player) -> void:
	if _collected or player == null or player.current_health <= 0.0:
		return
	_collected = true
	player.apply_powerup(kind)
	_spawn_pickup_flash()
	queue_free()

# Aufnahme-Ring, auch für Clients (NetFx).
func _spawn_pickup_flash() -> void:
	var parent := get_parent()
	if parent == null:
		return
	NetFx.emit(parent, "pickup", {"p": global_position, "c": _kind_color()})

func set_replica(replica: bool) -> void:
	is_replica = replica
	monitoring = not replica
	monitorable = not replica
	if replica:
		collision_layer = 0
		collision_mask = 0

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"rot": rotation,
		"kind": kind,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	global_position = data.get("pos", global_position)
	var new_kind := str(data.get("kind", kind))
	if new_kind != kind:
		kind = new_kind
		if _visual_root != null:
			_visual_root.queue_free()
			_build_visual()

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	if not points.is_empty():
		points.append(points[0])
	return points
