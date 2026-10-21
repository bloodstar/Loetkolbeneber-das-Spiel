class_name Bullet
extends CharacterBody2D

var shooter: Node2D = null
var target_enemy: Node2D = null

var damage: float = 20.0
var max_lifetime: float = 4.0
var lifetime: float = 0.0

var bounces_left: int = 0
var homing_strength: float = 0.0
var explosion_radius: float = 0.0
var poison_stacks: int = 0
var poison_damage: float = 4.0
var freeze_duration: float = 0.0
var lifesteal_percent: float = 0.0
var piercing_left: int = 0
var ricochet_bonus: float = 0.0

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

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	if net_id == 0:
		net_id = _next_net_id
		_next_net_id += 1
	
	if is_replica:
		collision_layer = 0
		collision_mask = 0
		collision_shape.disabled = true
		set_physics_process(false)
		return
	
	add_to_group("bullet")
	# Ignore shooter collision initially
	if shooter:
		add_collision_exception_with(shooter)

func _process(delta: float) -> void:
	if not is_replica:
		return
	if global_position.distance_to(net_target_pos) > 300.0:
		global_position = net_target_pos
	else:
		global_position = global_position.lerp(net_target_pos, clampf(25.0 * delta, 0.0, 1.0))
	rotation = lerp_angle(rotation, net_target_rotation, clampf(20.0 * delta, 0.0, 1.0))

# Wird auf dem Client pro Snapshot aufgerufen (keine Kollisionen/Physik).
func apply_network_state(data: Dictionary) -> void:
	net_target_pos = data.get("pos", net_target_pos)
	net_target_rotation = float(data.get("rot", net_target_rotation))
	velocity = data.get("vel", Vector2.ZERO)
	var s := float(data.get("scale", 1.0))
	scale = Vector2(s, s)
	var col = data.get("color", Color.WHITE)
	if col is Color:
		modulate = col

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= max_lifetime:
		_explode_and_destroy()
		return
	
	# Homing steering
	if homing_strength > 0.0 and target_enemy and is_instance_valid(target_enemy):
		var desired_dir = (target_enemy.global_position - global_position).normalized()
		var current_dir = velocity.normalized()
		var new_dir = current_dir.lerp(desired_dir, homing_strength * delta * 5.0).normalized()
		velocity = new_dir * velocity.length()
		rotation = velocity.angle()
	else:
		rotation = velocity.angle()
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		_handle_collision(collision)

func _handle_collision(collision: KinematicCollision2D) -> void:
	var collider = collision.get_collider()
	
	# Treffer auf zerstörbare Tiles und Ranken
	if collider.has_method("hit_tile"):
		collider.hit_tile(damage)
		_explode_and_destroy()
		return
	
	# Hit mystery block
	if collider.has_method("hit_block"):
		collider.hit_block(self)
		_explode_and_destroy()
		return
	
	# Hit a player
	if collider is CharacterBody2D and collider != shooter:
		if collider.has_method("take_damage"):
			var knockback = velocity.normalized() * (150.0 + damage * 2.0)
			collider.take_damage(damage, knockback)
			
			if poison_stacks > 0 and collider.has_method("apply_poison"):
				collider.apply_poison(poison_stacks, poison_damage)
			if freeze_duration > 0 and collider.has_method("apply_freeze"):
				collider.apply_freeze(freeze_duration)
			if stun_duration > 0.0 and collider.has_method("apply_stun"):
				collider.apply_stun(stun_duration)
			if burn_stacks > 0 and collider.has_method("apply_burn"):
				collider.apply_burn(burn_stacks, burn_damage)
			if chain_lightning and shooter and is_instance_valid(shooter) and shooter.has_method("trigger_chain_lightning"):
				shooter.trigger_chain_lightning(collider, global_position)
			if lifesteal_percent > 0.0 and shooter and is_instance_valid(shooter) and shooter.has_method("heal"):
				shooter.heal(damage * lifesteal_percent)
			
			SoundManager.play_sound("hit", 0.2, 2.0)
		
		if piercing_left > 0:
			piercing_left -= 1
			add_collision_exception_with(collider)
			return
		else:
			_explode_and_destroy()
			return
	
	# Hit wall / static geometry
	if bounces_left > 0:
		bounces_left -= 1
		velocity = velocity.bounce(collision.get_normal())
		if ricochet_bonus > 0.0:
			damage *= (1.0 + ricochet_bonus)
		SoundManager.play_sound("bounce", 0.2, -6.0)
	else:
		_explode_and_destroy()

func _explode_and_destroy() -> void:
	if explosion_radius > 0.0:
		_trigger_aoe_explosion()
	_spawn_impact_effects()
	queue_free()

func _spawn_impact_effects() -> void:
	if not shooter or not is_instance_valid(shooter):
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
	SoundManager.play_sound("explosion", 0.2, 0.0)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 2 # Players layer
	
	var results = space_state.intersect_shape(query, 8)
	for res in results:
		var body = res.collider
		if body is CharacterBody2D and body.has_method("take_damage"):
			var dist = global_position.distance_to(body.global_position)
			var falloff = clampf(1.0 - (dist / explosion_radius), 0.3, 1.0)
			var knock = (body.global_position - global_position).normalized() * 300.0
			body.take_damage(damage * 0.8 * falloff, knock)
	
	# Visual ring explosion
	var ring = Sprite2D.new()
	ring.texture = load("res://assets/projectiles/tile_0000.png")
	ring.modulate = Color(1.0, 0.6, 0.1, 0.8)
	get_parent().add_child(ring)
	ring.global_position = global_position
	ring.scale = Vector2.ZERO
	var tween = ring.create_tween()
	var target_scale = maxf(1.5, explosion_radius / 6.0)
	tween.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.25)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	tween.tween_callback(ring.queue_free)
