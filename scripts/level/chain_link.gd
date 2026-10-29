class_name ChainLink
extends RigidBody2D

## Ein Glied einer Kistenkette (CrateChain). Es kollidiert wie eine Kiste mit
## Spielern, Kisten und Projektilen und bricht nach zwei Treffern. Gelenke zu
## den Nachbarn legt die Kette an; bricht ein Glied, reißt die Kette dort.

signal link_broken(link: ChainLink)

# 24 statt 16 px: weniger Glieder pro Kette, weniger Rechenaufwand und
# stabilere Ketten.
const LENGTH: float = 24.0
const THICKNESS: float = 8.0
const MAX_HEALTH: int = 2

var is_replica: bool = false
var index: int = 0
var health: int = MAX_HEALTH
var tint: Color = Color(0.66, 0.70, 0.76, 1.0)
var link_mass: float = 0.3
var last_attacker: Node = null

var _broken: bool = false

func _ready() -> void:
	add_to_group("chain_link")
	collision_layer = 1
	collision_mask = 7
	mass = link_mass
	gravity_scale = 1.0
	linear_damp = 0.5
	angular_damp = 2.0
	can_sleep = false
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# Etwas länger als das Glied, damit zwischen den Gliedern keine Lücke
	# entsteht, in der Füße oder Projektile hängen bleiben.
	# Kollision dicker als das gezeichnete Glied und mit kontinuierlicher
	# Kollisionsprüfung, damit schnelle oder kleine Kugeln nicht durch die
	# Kette tunneln.
	shape.size = Vector2(LENGTH + 2.0, THICKNESS + 6.0)
	col.shape = shape
	add_child(col)
	_build_visual()
	if is_replica:
		set_replica(true)

func _build_visual() -> void:
	var dark := Color(tint.r * 0.38, tint.g * 0.38, tint.b * 0.42, 1.0)
	var light := tint.lightened(0.35)
	var half := LENGTH * 0.5 + 2.0
	if index % 2 == 0:
		# Glied von der Seite: ovaler Ring mit dunklem Loch.
		var ring := Line2D.new()
		var pts := PackedVector2Array()
		for i in range(13):
			var a := TAU * float(i) / 12.0
			pts.append(Vector2(cos(a) * half, sin(a) * 5.6))
		ring.points = pts
		ring.width = 3.6
		ring.default_color = tint
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		add_child(ring)
		var shine := Line2D.new()
		shine.points = PackedVector2Array([Vector2(-half * 0.55, -4.4), Vector2(half * 0.45, -4.4)])
		shine.width = 1.2
		shine.default_color = Color(light.r, light.g, light.b, 0.8)
		add_child(shine)
	else:
		# Glied von oben: kurzer, dicker Steg.
		var bar := Line2D.new()
		bar.points = PackedVector2Array([Vector2(-half, 0.0), Vector2(half, 0.0)])
		bar.width = 4.6
		bar.default_color = dark
		bar.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bar.end_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(bar)
		var core := Line2D.new()
		core.points = PackedVector2Array([Vector2(-half + 2.0, -0.8), Vector2(half - 2.0, -0.8)])
		core.width = 1.8
		core.default_color = tint
		add_child(core)

## Treffer von Projektilen und Nahkampf (gleiche Schnittstelle wie
## zerstörbare Kacheln, damit Kugel, Durchschlag und Waffen sie erkennen).
func hit_tile(_amount: float = 0.0) -> void:
	if is_replica or _broken:
		return
	health -= 1
	_flash()
	NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.18, -6.0]})
	if health <= 0:
		break_link()

func apply_blast(blast_position: Vector2, radius: float, force: float = 520.0, attacker: Node = null) -> void:
	if is_replica or _broken:
		return
	if attacker != null and is_instance_valid(attacker):
		last_attacker = attacker
	var distance := blast_position.distance_to(global_position)
	if distance > radius:
		return
	var falloff := clampf(1.0 - distance / maxf(1.0, radius), 0.15, 1.0)
	var direction := (global_position - blast_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	# Explosionen schubsen die Kette nur; reißen soll sie allein durch
	# Schüsse und Schläge (hit_tile).
	var impulse := direction * force * falloff * mass
	# Kettenglieder werden vom ChainRopeSolver bewegt (kinematisch).
	if has_meta("rope_solver") and is_instance_valid(get_meta("rope_solver")):
		get_meta("rope_solver").impulse_body(self, impulse)
	else:
		apply_impulse(impulse, Vector2.ZERO)

func _flash() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.8, 1.2, 0.7), 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, 0.12)

func break_link() -> void:
	if _broken:
		return
	_broken = true
	_spawn_sparks()
	SoundManager.play_sound("bounce", 0.2, -3.0)
	link_broken.emit(self)
	queue_free()

## Client: Der Host hat das Glied zerstört.
func apply_network_break() -> void:
	if _broken:
		return
	_broken = true
	_spawn_sparks()
	SoundManager.play_sound("bounce", 0.2, -3.0)
	queue_free()

func _spawn_sparks() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fx := Node2D.new()
	fx.global_position = global_position
	fx.z_index = 5
	parent.add_child(fx)
	for i in range(5):
		var spark := Line2D.new()
		var dir := Vector2.from_angle(float(i) * TAU / 5.0 + rotation)
		spark.points = PackedVector2Array([Vector2.ZERO, dir * 5.0])
		spark.width = 2.0
		spark.default_color = Color(1.0, 0.85, 0.45, 1.0)
		fx.add_child(spark)
		var tw := spark.create_tween()
		tw.tween_property(spark, "position", dir * 18.0, 0.2)
		tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.22)
	var cleanup := fx.create_tween()
	cleanup.tween_interval(0.26)
	cleanup.tween_callback(fx.queue_free)

func set_replica(replica: bool) -> void:
	is_replica = replica
	freeze = replica
	if replica:
		collision_layer = 0
		collision_mask = 0
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
	else:
		collision_layer = 1
		collision_mask = 7
