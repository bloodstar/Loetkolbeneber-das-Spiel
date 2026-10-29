class_name Bullet
extends CharacterBody2D

# Normale Projektile fallen spürbar und fliegen im Bogen. Karten können diesen
# Wert über projectile_gravity_mult verstärken (Mörser) oder abschwächen
# (flache Schüsse). Bots gleichen den Fall beim Zielen aus (AIController).
const BULLET_GRAVITY: float = 240.0
# Solange die Kugel steigt, wirkt die Schwerkraft doppelt. Ein Schuss nach
# oben kommt so nach ca. 440 px oben an und fällt innerhalb der Flugzeit
# zurück. Flache Schüsse ändern sich dadurch kaum.
const BULLET_RISE_GRAVITY_MULT: float = 2.0
# Grundimpuls eines direkten Treffers. Der Rückstoß-Multiplikator des Schützen
# wird beim Ziel in Player.take_damage() angewendet.
const DIRECT_KNOCKBACK_BASE: float = 220.0
const DIRECT_KNOCKBACK_PER_DAMAGE: float = 2.5
const EXPLOSION_KNOCKBACK_FORCE: float = 340.0
# Durchschlag durch Gelände: Jeder Punkt reicht für 0,5 Tile feste Wand oder
# 1 Tile zerstörbare Blöcke (Tiles, Ranken, Kisten). Die Kartengrenze hält.
const WALL_PIERCE_SOLID_PX: float = 18.0
const WALL_PIERCE_DESTRUCTIBLE_PX: float = 36.0
const WALL_PIERCE_STEP: float = 2.0
# Abgetastet wird ab der Projektilmitte. Bis zur Wand dürfen Radius plus
# dieser Spielraum Luft liegen, sonst gilt der Treffer als Streifschuss.
const WALL_PIERCE_ENTRY_SLACK: float = 6.0
# Die Abtastung in Schritten rundet leicht auf. Ohne diese Toleranz würde ein
# Tile, das genau die vorhandenen Punkte kostet, knapp scheitern.
const WALL_PIERCE_TOLERANCE: float = 0.08
const TERRAIN_LAYER: int = 1
# Zielsuche lenkt abhängig von der Entfernung zum Ziel: weit weg kaum, ab
# HOMING_FAR_DIST zunehmend und ab HOMING_NEAR_DIST mit voller Kraft.
const HOMING_FAR_DIST: float = 380.0
const HOMING_NEAR_DIST: float = 140.0
const HOMING_FAR_MULT: float = 0.15
const HOMING_NEAR_MULT: float = 3.0
# Projektile verschiedener Teams treffen sich gegenseitig. Stärke = Schaden *
# Größe. Ist der schwächere mindestens CLASH_SIMILAR_RATIO so stark wie der
# stärkere, heben sich beide auf. Sonst fliegt der stärkere mit der
# Differenz weiter (Schaden und Größe schrumpfen entsprechend).
const CLASH_SIMILAR_RATIO: float = 0.7
const CLASH_MIN_KEEP: float = 0.15
# Teilung beim Abprall: Aus einer Kugel werden zwei kleinere mit je 60 %
# Schaden. Schutz gegen Endlos-Vermehrung: höchstens SPLIT_MAX_DEPTH
# Teilungen pro Schuss (also maximal 8 Teile) und keine Teilung mehr, wenn
# schon SPLIT_MAX_BULLETS Projektile unterwegs sind.
const SPLIT_DAMAGE_MULT: float = 0.6
const SPLIT_SCALE_MULT: float = 0.8
const SPLIT_ANGLE: float = 0.24 # rad, ca. 14° Auffächerung je Hälfte
const SPLIT_MAX_DEPTH: int = 3
const SPLIT_MAX_BULLETS: int = 160
const BULLET_SCENE_PATH: String = "res://scenes/player/bullet.tscn"

# Einmal pro Physik-Frame prüft der erste Host-Bullet alle Paare.
static var _clash_frame: int = -1
var _prev_pos: Vector2 = Vector2.ZERO
var _has_moved: bool = false

var shooter: Node2D = null
# Splitter aus der Heldenfähigkeit: Treffer zählen als Fähigkeitsschaden.
var from_ability: bool = false
var target_enemy: Node2D = null

var damage: float = 20.0
var max_lifetime: float = 4.0
var lifetime: float = 0.0
var projectile_gravity_mult: float = 1.0

var bounces_left: int = 0
var homing_strength: float = 0.0
var explosion_radius: float = 0.0
var poison_stacks: int = 0
var poison_damage: float = 4.0
var freeze_duration: float = 0.0
var lifesteal_percent: float = 0.0
var piercing_left: int = 0
# Restliche Durchschlagspunkte für Wände, getrennt vom Durchschlag durch Gegner.
var wall_pierce_left: float = 0.0
var ricochet_bonus: float = 0.0
# Gummiwand: prallt kostenlos am Kartenrand ab (Gummiband und Höhlenwand).
var border_bounce: bool = false
var split_on_bounce: bool = false
var split_depth: int = 0
# Spielerschüsse können den eigenen Schützen treffen (Schuss nach oben, der
# zurückfällt, Abpraller, Wind). Die Kollisionsausnahme gilt nur, bis die
# Kugel den Körper des Schützen verlassen hat.
var can_hit_shooter: bool = false
var _shooter_exception: Node2D = null

# Talentbaum-Effekte
var stun_duration: float = 0.0
var poison_impact_cloud: bool = false
var frost_nova: bool = false
var chain_lightning: bool = false
var lightning_zone: bool = false
var cluster_bomblets: bool = false
var fire_shot: bool = false
var fire_impact_zone: bool = false
var burn_stacks: int = 0
var burn_damage: float = 5.0

# --- Netzwerk ---
static var _next_net_id: int = 1
var net_id: int = 0
var is_replica: bool = false
var net_target_pos: Vector2 = Vector2.ZERO
var net_target_rotation: float = 0.0
var blocked_by_drone: bool = false

var trail: Line2D = null
const TRAIL_RESET_DISTANCE: float = 200.0
var _trail_points: PackedVector2Array = PackedVector2Array()
# Blitzschuss: zuckender Zickzack-Schweif statt glatter Linie.
var lightning_trail: bool = false
var _trail_glow: Line2D = null

# Aussehen wie die Schüsse im Hauptmenü (MainMenuBackdrop._draw_shots): weicher
# Schein, leuchtende Kugel, heller Kern. Gezeichnet wird in Weiß bzw.
# überhellt, die Farbe kommt allein über modulate (Schussfarbe, Karten,
# Helden). So sehen Host und Client-Replikate gleich aus.
const ORB_RADIUS: float = 6.0
const ORB_CORE_RADIUS: float = 3.0
const ORB_GLOW_RADIUS: float = 18.0
const ORB_GLOW_ALPHA: float = 0.6
# Werte über 1 hellen die Farbe nach dem Multiplizieren mit modulate auf
# (entspricht grob color.lightened() im Menü).
const ORB_BODY_BOOST: float = 1.3
const ORB_CORE_BOOST: float = 3.0
const TRAIL_WIDTH: float = 10.0
static var _glow_texture: GradientTexture2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if net_id == 0:
		net_id = _next_net_id
		_next_net_id += 1

	if sprite:
		sprite.visible = false
	_build_trail()
	if not is_replica and (stun_duration > 0.0 or chain_lightning or lightning_zone):
		_enable_lightning_trail()
	
	if is_replica:
		collision_layer = 0
		collision_mask = 0
		collision_shape.disabled = true
		set_physics_process(false)
		return
	
	add_to_group("bullet")
	# Ignore shooter collision initially
	if is_instance_valid(shooter):
		add_collision_exception_with(shooter)
		if can_hit_shooter:
			_shooter_exception = shooter

func _build_trail() -> void:
	trail = Line2D.new()
	trail.name = "Trail"
	trail.top_level = true
	trail.width = TRAIL_WIDTH * maxf(scale.x, 0.1)
	# Wie im Menü: Schweif läuft hinter der Kugel spitz zu.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.25))
	taper.add_point(Vector2(1.0, 1.0))
	trail.width_curve = taper
	trail.antialiased = true
	trail.z_index = -2
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	# Erst beim ersten _advance_trail() befüllen: Manche Spawner (Drohne,
	# Streubombe, Client-Replikate) setzen die Position erst nach add_child.
	_trail_points = PackedVector2Array()
	trail.points = _trail_points
	_update_trail_color()

# Grundimpuls für einen direkten Treffer. Der Multiplikator des Schützen wird
# erst am Ziel angewendet, damit auch Fähigkeiten und Explosionen davon profitieren.
func calculate_knockback() -> Vector2:
	var impulse := DIRECT_KNOCKBACK_BASE + maxf(0.0, damage) * DIRECT_KNOCKBACK_PER_DAMAGE
	return velocity.normalized() * impulse

func _enable_lightning_trail() -> void:
	if lightning_trail or trail == null:
		return
	lightning_trail = true
	trail.width = 2.5
	trail.width_curve = null
	trail.joint_mode = Line2D.LINE_JOINT_SHARP
	_trail_glow = Line2D.new()
	_trail_glow.name = "TrailGlow"
	_trail_glow.top_level = true
	_trail_glow.width = 8.0
	_trail_glow.antialiased = true
	_trail_glow.z_index = -3
	_trail_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(_trail_glow)
	_update_trail_color()

func _update_trail_color() -> void:
	if trail == null:
		return
	if lightning_trail:
		var bolt := Gradient.new()
		bolt.set_color(0, Color(1.0, 0.95, 0.5, 0.0))
		bolt.set_color(1, Color(1.0, 1.0, 0.85, 1.0))
		trail.gradient = bolt
		var glow := Gradient.new()
		glow.set_color(0, Color(1.0, 0.8, 0.2, 0.0))
		glow.set_color(1, Color(1.0, 0.85, 0.25, 0.35))
		_trail_glow.gradient = glow
		return
	var c := modulate
	var gradient := Gradient.new()
	gradient.set_color(0, Color(c.r, c.g, c.b, 0.0))
	gradient.set_color(1, Color(c.r, c.g, c.b, 0.5))
	trail.gradient = gradient

func _draw() -> void:
	if _glow_texture == null:
		_glow_texture = _make_glow_texture()
	var r := ORB_GLOW_RADIUS
	draw_texture_rect(_glow_texture, Rect2(Vector2(-r, -r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, ORB_GLOW_ALPHA))
	draw_circle(Vector2.ZERO, ORB_RADIUS, Color(ORB_BODY_BOOST, ORB_BODY_BOOST, ORB_BODY_BOOST, 1.0))
	draw_circle(Vector2.ZERO, ORB_CORE_RADIUS, Color(ORB_CORE_BOOST, ORB_CORE_BOOST, ORB_CORE_BOOST, 1.0))

static func _make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture

func _advance_trail() -> void:
	if trail == null:
		return
	# Großer Sprung (Teleport, Netz-Korrektur): Schweif neu beginnen statt
	# eine Linie quer über die Karte zu ziehen.
	if not _trail_points.is_empty() and _trail_points[_trail_points.size() - 1].distance_to(global_position) > TRAIL_RESET_DISTANCE:
		_trail_points.clear()
	if _trail_points.is_empty() or _trail_points[_trail_points.size() - 1].distance_to(global_position) > 1.0:
		_trail_points.append(global_position)
	var max_points := 13 if lightning_trail else 9
	while _trail_points.size() > max_points:
		_trail_points.remove_at(0)
	if lightning_trail:
		# Jedes Bild neu verzackt, damit der Blitz zuckt. Ende am Projektil bleibt fest.
		var jagged := PackedVector2Array()
		var count := _trail_points.size()
		for i in count:
			var p := _trail_points[i]
			if i > 0 and i < count - 1:
				var dir := (_trail_points[i + 1] - _trail_points[i - 1]).orthogonal().normalized()
				p += dir * randf_range(-6.0, 6.0)
			jagged.append(p)
		trail.points = jagged
		_trail_glow.points = jagged
	else:
		trail.width = TRAIL_WIDTH * maxf(scale.x, 0.1)
		trail.points = _trail_points

func _process(delta: float) -> void:
	if not is_replica:
		return
	if global_position.distance_to(net_target_pos) > 300.0:
		global_position = net_target_pos
	else:
		global_position = global_position.lerp(net_target_pos, clampf(25.0 * delta, 0.0, 1.0))
	rotation = lerp_angle(rotation, net_target_rotation, clampf(20.0 * delta, 0.0, 1.0))
	_advance_trail()

# Wird auf dem Client pro Snapshot aufgerufen (keine Kollisionen/Physik).
func apply_network_state(data: Dictionary) -> void:
	net_target_pos = data.get("pos", net_target_pos)
	net_target_rotation = float(data.get("rot", net_target_rotation))
	velocity = data.get("vel", Vector2.ZERO)
	var s := float(data.get("scale", 1.0))
	scale = Vector2(s, s)
	if bool(data.get("lt", false)):
		_enable_lightning_trail()
	var col = data.get("color", Color.WHITE)
	if col is Color:
		modulate = col
		_update_trail_color()

func _physics_process(delta: float) -> void:
	if blocked_by_drone:
		return
	if not is_replica:
		var frame := Engine.get_physics_frames()
		if frame != _clash_frame:
			_clash_frame = frame
			_resolve_projectile_clashes()
		if is_queued_for_deletion():
			return
	lifetime += delta
	if lifetime >= max_lifetime:
		_explode_and_destroy()
		return
	
	# Schwerkraft: Die Flugbahn wird zum Bogen. Mörser-Karten
	# verstärken den Fall, Präzisionskarten flachen ihn ab.
	var gravity := BULLET_GRAVITY * maxf(0.0, projectile_gravity_mult)
	if velocity.y < 0.0:
		gravity *= BULLET_RISE_GRAVITY_MULT
	velocity.y += gravity * delta

	# Zielsuche: weit weg nur leichtes Nachführen, nah am Gegner starkes Einlenken.
	# Unsichtbare Spieler (Powerup) entziehen sich der Zielsuche.
	if homing_strength > 0.0 and target_enemy and is_instance_valid(target_enemy) \
			and not (target_enemy is Player and target_enemy.is_invisible()):
		var to_target: Vector2 = target_enemy.global_position - global_position
		var proximity := clampf((HOMING_FAR_DIST - to_target.length()) / (HOMING_FAR_DIST - HOMING_NEAR_DIST), 0.0, 1.0)
		var turn_mult := lerpf(HOMING_FAR_MULT, HOMING_NEAR_MULT, proximity)
		var weight := clampf(homing_strength * delta * 5.0 * turn_mult, 0.0, 1.0)
		var new_dir := velocity.normalized().lerp(to_target.normalized(), weight)
		if new_dir != Vector2.ZERO:
			velocity = new_dir.normalized() * velocity.length()
		rotation = velocity.angle()
	else:
		rotation = velocity.angle()
	
	if _shooter_exception != null:
		_try_release_shooter_exception()
	_prev_pos = global_position
	var collision = move_and_collide(velocity * delta)
	_has_moved = true
	_advance_trail()
	if collision:
		_handle_collision(collision)
	if border_bounce and not is_queued_for_deletion():
		_bounce_off_map_edge()

# Hebt die Ausnahme für den Schützen auf, sobald die Kugel ihn nicht mehr
# überlappt. Ab dann kann sie ihn wie jeden anderen Spieler treffen.
func _try_release_shooter_exception() -> void:
	if not is_instance_valid(_shooter_exception):
		_shooter_exception = null
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = 2 # Spieler
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		if hit.get("collider") == _shooter_exception:
			return
	remove_collision_exception_with(_shooter_exception)
	_shooter_exception = null

# Wird von einer Schutzdrohne aufgerufen. Das Projektil verschwindet ohne
# Explosion, Flächeneffekt oder Trefferzählung; die Drohne übernimmt Heilung
# und Statistik. Der Rückgabewert verhindert doppeltes Blocken im selben Frame.
func block_by_drone() -> bool:
	if blocked_by_drone or is_replica:
		return false
	blocked_by_drone = true
	set_physics_process(false)
	if is_instance_valid(collision_shape):
		collision_shape.set_deferred("disabled", true)
	queue_free()
	return true

func _handle_collision(collision: KinematicCollision2D) -> void:
	var collider = collision.get_collider()

	# Durchschlag: dünne Wände und zerstörbare Blöcke durchfliegen, solange
	# genug Wand-Durchschlag übrig ist. Sonst normale Trefferbehandlung.
	if _is_pierceable_terrain(collider) and _try_pierce_terrain(collision):
		return
	
	# Treffer auf zerstörbare Tiles und Ranken
	if collider.has_method("hit_tile"):
		collider.hit_tile(damage)
		_explode_and_destroy()
		return
	
	# Treffer auf bewegliche Map-Objekte (Fässer / TNT)
	if collider.has_method("hit_barrel"):
		collider.hit_barrel(self)
		_explode_and_destroy()
		return

	# Holzkisten zerbrechen nach mehreren Treffern.
	if collider.has_method("hit_crate"):
		collider.hit_crate(self)
		_explode_and_destroy()
		return

	# Hit mystery block
	if collider.has_method("hit_block"):
		collider.hit_block(self)
		_explode_and_destroy()
		return

	# Treffer auf einen Turm. Eigene Türme werden ignoriert, damit das
	# Projektil weiterfliegen kann.
	if collider.has_method("hit_tower"):
		if collider.hit_tower(self):
			if is_instance_valid(shooter) and shooter is Player:
				var tower_shooter := shooter as Player
				Global.add_match_stat(tower_shooter.player_index, "shots_hit", 1.0)
			_explode_and_destroy()
		else:
			add_collision_exception_with(collider)
		return
	
	# Eigene Kugel trifft den Schützen: Selbstschaden (in Player.take_damage
	# halbiert, Gummipuffer verringert weiter). Keine Effekte wie Gift oder
	# Lebensraub auf sich selbst.
	if can_hit_shooter and collider == shooter and collider.has_method("take_damage"):
		collider.take_damage(damage, calculate_knockback(), shooter)
		NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.2, 2.0]})
		if piercing_left > 0:
			piercing_left -= 1
			add_collision_exception_with(collider)
			return
		_explode_and_destroy()
		return

	# Hit a player
	if collider is CharacterBody2D and collider != shooter:
		var shooter_is_player := is_instance_valid(shooter) and shooter is Player
		if collider is Player and shooter_is_player and collider.team_id == shooter.team_id:
			# Teammitglieder blocken das Projektil körperlich, nehmen aber
			# weder Schaden noch werden sie als Treffer gezählt.
			_explode_and_destroy()
			return
		if collider.has_method("take_damage"):
			if shooter_is_player:
				Global.add_match_stat(shooter.player_index, "shots_hit", 1.0)
			_deal_damage(collider, damage, calculate_knockback())
			
			if poison_stacks > 0 and collider.has_method("apply_poison"):
				collider.apply_poison(poison_stacks, poison_damage)
			if freeze_duration > 0 and collider.has_method("apply_freeze"):
				collider.apply_freeze(freeze_duration)
			if stun_duration > 0.0 and collider.has_method("apply_stun"):
				collider.apply_stun(stun_duration)
			if burn_stacks > 0 and collider.has_method("apply_burn"):
				collider.apply_burn(burn_stacks, burn_damage)
			if chain_lightning and is_instance_valid(shooter) and shooter.has_method("trigger_chain_lightning"):
				shooter.trigger_chain_lightning(collider, global_position)
			if lifesteal_percent > 0.0 and is_instance_valid(shooter) and shooter.has_method("heal"):
				shooter.heal(damage * lifesteal_percent)
			
			NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.2, 2.0]})
		
		if piercing_left > 0:
			piercing_left -= 1
			add_collision_exception_with(collider)
			return
		else:
			_explode_and_destroy()
			return
	
	# Treffer auf eine Wippe: Drehstoß am Trefferpunkt, danach wie eine Wand.
	if collider is Node and collider.get_parent() is Seesaw:
		collider.get_parent().apply_projectile_hit(collision.get_position(), velocity, damage)

	# Hit wall / static geometry. Mit Gummiwand kostet die Kartengrenze
	# (Höhlenwand) keinen Abpraller.
	var free_bounce: bool = border_bounce and collider is Node and (collider as Node).is_in_group("map_border")
	if free_bounce or bounces_left > 0:
		if not free_bounce:
			bounces_left -= 1
		velocity = velocity.bounce(collision.get_normal())
		_on_bounced(not free_bounce)
	else:
		_explode_and_destroy()

# Gemeinsame Folgen jedes Abpralls (Wand, Höhlenrand oder Gummiwand).
# Der Ricochet-Bonus zählt nur für verbrauchte Abpraller, sonst würde eine
# Kugel an der Gummiwand ihren Schaden beliebig oft steigern.
func _on_bounced(counts_for_ricochet: bool = true) -> void:
	if counts_for_ricochet and ricochet_bonus > 0.0:
		damage *= (1.0 + ricochet_bonus)
	NetFx.emit(get_parent(), "sound", {"snd": ["bounce", 0.2, -6.0]})
	_split_on_bounce()

# Gummiwand-Modus: Die Karte ist von Sensor-Bändern umgeben, nicht von festen
# Wänden. Verlässt die Kugel das Spielfeld, wird sie an der Kante gespiegelt.
func _bounce_off_map_edge() -> void:
	var map_w := float(LevelGenerator.map_w) * LevelGenerator.TILE_SIZE
	var map_h := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	if map_w <= 0.0 or map_h <= 0.0:
		return
	var r := _clash_radius()
	var bounced := false
	if global_position.x < r and velocity.x < 0.0:
		global_position.x = r
		velocity.x = -velocity.x
		bounced = true
	elif global_position.x > map_w - r and velocity.x > 0.0:
		global_position.x = map_w - r
		velocity.x = -velocity.x
		bounced = true
	if global_position.y < r and velocity.y < 0.0:
		global_position.y = r
		velocity.y = -velocity.y
		bounced = true
	elif global_position.y > map_h - r and velocity.y > 0.0:
		global_position.y = map_h - r
		velocity.y = -velocity.y
		bounced = true
	if bounced:
		_on_bounced(false)

# Teilt die Kugel in zwei kleinere Hälften. Diese Kugel wird zur einen
# Hälfte, die andere ist eine Kopie mit allen Effekten. Nur auf dem Host;
# Clients bekommen die neue Kugel über die Snapshots.
func _split_on_bounce() -> void:
	if not split_on_bounce or is_replica or split_depth >= SPLIT_MAX_DEPTH:
		return
	if get_tree().get_nodes_in_group("bullet").size() >= SPLIT_MAX_BULLETS:
		return
	var scene: PackedScene = load(BULLET_SCENE_PATH)
	if scene == null or get_parent() == null:
		return
	split_depth += 1
	damage *= SPLIT_DAMAGE_MULT
	scale *= SPLIT_SCALE_MULT
	var twin: Bullet = scene.instantiate()
	if is_instance_valid(shooter):
		twin.shooter = shooter
	if is_instance_valid(target_enemy):
		twin.target_enemy = target_enemy
	twin.damage = damage
	twin.max_lifetime = max_lifetime
	twin.lifetime = lifetime
	twin.projectile_gravity_mult = projectile_gravity_mult
	twin.bounces_left = bounces_left
	twin.homing_strength = homing_strength
	twin.explosion_radius = explosion_radius
	twin.poison_stacks = poison_stacks
	twin.poison_damage = poison_damage
	twin.freeze_duration = freeze_duration
	twin.lifesteal_percent = lifesteal_percent
	twin.piercing_left = piercing_left
	twin.wall_pierce_left = wall_pierce_left
	twin.ricochet_bonus = ricochet_bonus
	twin.border_bounce = border_bounce
	twin.split_on_bounce = split_on_bounce
	twin.split_depth = split_depth
	twin.can_hit_shooter = can_hit_shooter
	twin.stun_duration = stun_duration
	twin.poison_impact_cloud = poison_impact_cloud
	twin.frost_nova = frost_nova
	twin.chain_lightning = chain_lightning
	twin.lightning_zone = lightning_zone
	twin.cluster_bomblets = cluster_bomblets
	twin.fire_shot = fire_shot
	twin.fire_impact_zone = fire_impact_zone
	twin.burn_stacks = burn_stacks
	twin.burn_damage = burn_damage
	twin.scale = scale
	twin.modulate = modulate
	twin.velocity = velocity.rotated(SPLIT_ANGLE)
	velocity = velocity.rotated(-SPLIT_ANGLE)
	get_parent().add_child(twin)
	twin.global_position = global_position
	# Bereits durchschlagene Gegner trifft auch die Kopie nicht noch einmal.
	for body in get_collision_exceptions():
		if is_instance_valid(body):
			twin.add_collision_exception_with(body)

# Prüft die Flugstrecken des letzten Frames aller Host-Projektile paarweise.
# Die Strecken (nicht nur die Endpunkte) werden verglichen, damit sich
# schnelle, entgegenfliegende Schüsse nicht durchtunneln.
func _resolve_projectile_clashes() -> void:
	var list: Array[Bullet] = []
	for node in get_tree().get_nodes_in_group("bullet"):
		var candidate := node as Bullet
		if candidate == null or candidate.is_replica or candidate.blocked_by_drone \
				or not candidate._has_moved or candidate.is_queued_for_deletion():
			continue
		list.append(candidate)
	var count := list.size()
	for i in range(count):
		var a := list[i]
		if a.is_queued_for_deletion():
			continue
		for j in range(i + 1, count):
			var b := list[j]
			if b.is_queued_for_deletion() or not _is_hostile_pair(a, b):
				continue
			var reach := a._clash_radius() + b._clash_radius()
			var a_move := a.global_position - a._prev_pos
			var b_move := b.global_position - b._prev_pos
			# Grobe Vorprüfung, bevor der genaue Streckenabstand gerechnet wird.
			if a.global_position.distance_to(b.global_position) > reach + a_move.length() + b_move.length():
				continue
			var rel_start := a._prev_pos - b._prev_pos
			var rel_move := a_move - b_move
			var t := 1.0
			var rel_len_sq := rel_move.length_squared()
			if rel_len_sq > 0.0001:
				t = clampf(-rel_start.dot(rel_move) / rel_len_sq, 0.0, 1.0)
			if (rel_start + rel_move * t).length() > reach:
				continue
			var point := ((a._prev_pos + a_move * t) + (b._prev_pos + b_move * t)) * 0.5
			_clash(a, b, point)
			if a.is_queued_for_deletion():
				break

static func _is_hostile_pair(a: Bullet, b: Bullet) -> bool:
	if a.shooter == b.shooter:
		return false
	if is_instance_valid(a.shooter) and is_instance_valid(b.shooter) \
			and a.shooter is Player and b.shooter is Player:
		return (a.shooter as Player).team_id != (b.shooter as Player).team_id
	return true

func _clash_radius() -> float:
	var radius := 6.0
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		radius = (collision_shape.shape as CircleShape2D).radius
	return radius * maxf(scale.x, scale.y)

func _clash_strength() -> float:
	return maxf(damage, 0.0) * maxf(scale.x, 0.1)

static func _clash(a: Bullet, b: Bullet, point: Vector2) -> void:
	var sa := a._clash_strength()
	var sb := b._clash_strength()
	var strong := a if sa >= sb else b
	var weak := b if strong == a else a
	var s_strong := maxf(sa, sb)
	var s_weak := minf(sa, sb)
	if s_strong <= 0.0 or s_weak / s_strong >= CLASH_SIMILAR_RATIO:
		# Ähnlich stark: beide heben sich am Treffpunkt auf.
		a.global_position = point
		b.global_position = point
		a._explode_and_destroy()
		b._explode_and_destroy()
		return
	# Deutlich stärker: der schwächere vergeht, der stärkere fliegt mit der
	# Differenz weiter. Schaden und Größe teilen sich die Abnahme.
	weak.global_position = point
	weak._explode_and_destroy()
	var keep := maxf((s_strong - s_weak) / s_strong, CLASH_MIN_KEEP)
	var factor := sqrt(keep)
	strong.damage *= factor
	strong.scale *= factor

func _is_pierceable_terrain(body: Object) -> bool:
	if body == null or not is_instance_valid(body) or not (body is Node):
		return false
	var node := body as Node
	if node.is_in_group("map_border"):
		return false
	if _is_destructible_body(node):
		return true
	# Wippe: zählt wie feste Wand.
	if node.get_parent() is Seesaw:
		return true
	return node is StaticBody2D and node.is_in_group("solid")

# Zerstörbare Hindernisse: Tiles, Ranken und Kisten. Sie kosten pro Tile nur
# halb so viel wie feste Wand. Fässer, Fragezeichen-Blöcke und Türme sind
# bewusst nicht durchschießbar.
static func _is_destructible_body(node: Node) -> bool:
	return node.has_method("hit_tile") or node.has_method("hit_crate")

# Löst den Treffer an einem durchschossenen Hindernis aus.
func _hit_pierced_body(node: Node, hit_pos: Vector2, hit_velocity: Vector2) -> void:
	if node.has_method("hit_tile"):
		node.hit_tile(damage)
	elif node.has_method("hit_crate"):
		node.hit_crate(self)
	elif node.get_parent() is Seesaw:
		(node.get_parent() as Seesaw).apply_projectile_hit(hit_pos, hit_velocity, damage)

# Tastet ab dem Einschlagpunkt in Flugrichtung durch das Gelände, bis wieder
# freier Raum kommt. Gezählt wird die Dicke der Wand, nicht der schräge Weg
# hindurch: ein diagonaler Schuss kostet so viel wie ein gerader. Feste Wand
# kostet pro Tile doppelt so viel wie zerstörbare Blöcke. Reicht der Rest,
# wird das Projektil hinter die Wand gesetzt; zerstörbare Blöcke auf dem Weg
# bekommen je einen Treffer ab.
# Nur auf dem Host; Clients folgen über die Positions-Snapshots.
func _try_pierce_terrain(collision: KinematicCollision2D) -> bool:
	if wall_pierce_left <= 0.0 or is_replica:
		return false
	var dir := velocity.normalized()
	if dir == Vector2.ZERO:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = TERRAIN_LAYER
	query.exclude = [get_rid()]
	# Von der Projektilmitte aus abtasten statt vom Kontaktpunkt: Der liegt je
	# nach Richtung knapp vor oder auf der Wand, die Mitte ist eindeutig.
	var radius := 6.0
	if is_instance_valid(collision_shape) and collision_shape.shape is CircleShape2D:
		radius = (collision_shape.shape as CircleShape2D).radius * maxf(scale.x, scale.y)
	var entry := global_position
	var entry_slack := radius + WALL_PIERCE_ENTRY_SLACK
	var hit_pos := collision.get_position()
	var hit_velocity := velocity
	# Schräg durch ein Tile ist der Weg länger, die Wand aber nicht dicker.
	# Deshalb wird der Weg auf die Hauptachse projiziert.
	var thickness_per_px := maxf(absf(dir.x), absf(dir.y))
	var max_dist := wall_pierce_left * WALL_PIERCE_DESTRUCTIBLE_PX / maxf(thickness_per_px, 0.01) \
			+ WALL_PIERCE_STEP
	var cost := 0.0
	var dist := 0.0
	var exit_dist := -1.0
	var entered := false
	var passed: Array = []
	while dist <= max_dist + entry_slack:
		query.position = entry + dir * (dist + 0.5)
		var hits := space.intersect_point(query, 8)
		if hits.is_empty():
			if entered:
				exit_dist = dist
				break
			# Noch nicht in der Wand: von der Mitte bis zur Wand ist erst Luft.
			if dist > entry_slack:
				return false
			dist += WALL_PIERCE_STEP
			continue
		var solid := false
		for hit in hits:
			var body = hit.get("collider")
			if not _is_pierceable_terrain(body):
				return false
			if not passed.has(body):
				passed.append(body)
			if not _is_destructible_body(body as Node):
				solid = true
		entered = true
		cost += WALL_PIERCE_STEP * thickness_per_px \
				/ (WALL_PIERCE_SOLID_PX if solid else WALL_PIERCE_DESTRUCTIBLE_PX)
		if cost > wall_pierce_left + WALL_PIERCE_TOLERANCE:
			return false
		dist += WALL_PIERCE_STEP
	# Hinter der Wand muss wieder freier Raum gefunden worden sein.
	if not entered or exit_dist < 0.0:
		return false

	# Hinter der Wand muss der ganze Projektilkörper Platz haben.
	var exit_pos := entry + dir * (exit_dist + radius + 1.0)
	var shape_query := PhysicsShapeQueryParameters2D.new()
	shape_query.shape = collision_shape.shape
	shape_query.transform = Transform2D(rotation, scale, 0.0, exit_pos)
	shape_query.collision_mask = TERRAIN_LAYER
	shape_query.exclude = [get_rid()]
	if not space.intersect_shape(shape_query, 1).is_empty():
		return false

	wall_pierce_left = maxf(0.0, wall_pierce_left - cost)
	global_position = exit_pos
	# Erst nach dem Versetzen auslösen: Ein explodierendes Fass trifft das
	# Projektil sonst noch an seiner alten Stelle.
	for body in passed:
		if is_instance_valid(body):
			_hit_pierced_body(body as Node, hit_pos, hit_velocity)
	return true

func _explode_and_destroy() -> void:
	if explosion_radius > 0.0:
		_trigger_aoe_explosion()
	_spawn_impact_effects()
	queue_free()

func _spawn_impact_effects() -> void:
	if not is_instance_valid(shooter):
		return
	var impact_pos := global_position

	if poison_impact_cloud and shooter.has_method("spawn_poison_cloud"):
		shooter.spawn_poison_cloud(impact_pos)
	if frost_nova and shooter.has_method("spawn_frost_nova"):
		shooter.spawn_frost_nova(impact_pos)
	if lightning_zone and shooter.has_method("spawn_lightning_zone"):
		shooter.spawn_lightning_zone(impact_pos)
	if fire_impact_zone and shooter.has_method("spawn_fire_zone"):
		shooter.spawn_fire_zone(impact_pos)
	if cluster_bomblets and shooter.has_method("spawn_cluster_bomblets"):
		shooter.spawn_cluster_bomblets(impact_pos)

func _trigger_aoe_explosion() -> void:
	# Optik, Ton und Wackeln auch für Clients (NetFx).
	var fx_args := NetFx.ring_args(global_position, Color(1.0, 0.6, 0.1, 0.8),
		0.0, maxf(1.5, explosion_radius / 6.0), 0.25, 0.25)
	fx_args["shake"] = clampf(explosion_radius / 180.0, 0.12, 0.45)
	NetFx.emit(get_parent(), "ring", NetFx.with_sound(fx_args, "explosion", 0.2, 0.0))
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2 | 16 # Players + towers
	
	Seesaw.blast_all(get_tree(), global_position, explosion_radius * 1.3, clampf(explosion_radius / 60.0, 0.4, 1.2))
	var results = space_state.intersect_shape(query, 8)
	for res in results:
		var body = res.collider
		var dist = global_position.distance_to(body.global_position)
		var falloff = clampf(1.0 - (dist / explosion_radius), 0.3, 1.0)
		if body.has_method("take_tower_damage"):
			body.take_tower_damage(damage * 0.8 * falloff, shooter)
		elif body is CharacterBody2D and body.has_method("take_damage"):
			var knock = (body.global_position - global_position).normalized() * EXPLOSION_KNOCKBACK_FORCE
			_deal_damage(body, damage * 0.8 * falloff, knock)

# Treffer an einem Ziel mit take_damage(). Splitter aus der Heldenfähigkeit
# markieren den Schützen kurz, damit der Schaden als Fähigkeitsschaden zählt.
func _deal_damage(body, amount: float, knockback: Vector2) -> void:
	var tag := from_ability and is_instance_valid(shooter) and shooter is Player
	if tag:
		shooter.dealing_ability_damage = true
	body.take_damage(amount, knockback, shooter)
	if tag and is_instance_valid(shooter):
		shooter.dealing_ability_damage = false
