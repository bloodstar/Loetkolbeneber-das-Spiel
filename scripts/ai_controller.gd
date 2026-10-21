class_name AIController
extends Node

@export var player: Player
var target: Player = null

# AI Parameters
var reaction_speed: float = 8.0
var aim_spread: float = 0.08
var combat_range: float = 300.0
var jump_cooldown: float = 0.0
var dash_decision_timer: float = 0.0
var shoot_decision_timer: float = 0.0

func _ready() -> void:
	if not player:
		player = get_parent() as Player

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player) or not player.is_bot:
		return
	# Während des Start-Countdowns oder eines Betäubungs-Effekts nicht eingreifen.
	if not player.control_enabled or player.stun_timer > 0.0:
		return
	
	if jump_cooldown > 0.0:
		jump_cooldown -= delta
	if dash_decision_timer > 0.0:
		dash_decision_timer -= delta
	if shoot_decision_timer > 0.0:
		shoot_decision_timer -= delta
	
	# Find target (Player 1)
	if not target or not is_instance_valid(target):
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p != player:
				target = p
				player.opponent = p
				break
	
	if not target or not is_instance_valid(target):
		return
	
	_handle_aim(delta)
	_handle_navigation(delta)
	_handle_combat(delta)

func _handle_aim(delta: float) -> void:
	var to_target = (target.global_position - player.global_position).normalized()
	# Add slight noisy deviation
	var noise = Vector2(randf_range(-aim_spread, aim_spread), randf_range(-aim_spread, aim_spread))
	var desired_aim = (to_target + noise).normalized()
	player.aim_direction = player.aim_direction.lerp(desired_aim, reaction_speed * delta).normalized()

func _handle_navigation(_delta: float) -> void:
	var diff = target.global_position - player.global_position
	var dist_x = diff.x
	var dist_y = diff.y
	var current_spd = player.move_speed
	
	# Horizontal pursuit / spacing
	var move_input = 0.0
	if abs(dist_x) > combat_range:
		move_input = signf(dist_x)
	elif abs(dist_x) < 80.0 and player.current_health < player.max_health * 0.4:
		# Low health kite away
		move_input = -signf(dist_x)
	else:
		# Strafe / reposition
		move_input = signf(dist_x) * 0.7
	
	player.velocity.x = move_toward(player.velocity.x, move_input * current_spd, current_spd * 0.2)
	
	# Jumping logic
	if jump_cooldown <= 0.0:
		# Jump over walls
		if player.is_on_wall():
			player.jump()
			jump_cooldown = 0.4
		# Jump towards higher opponent
		elif dist_y < -60.0 and randf() < 0.05:
			player.jump()
			jump_cooldown = 0.5
		# Random unpredictable platform hops
		elif randf() < 0.015:
			player.jump()
			jump_cooldown = 0.6

func _handle_combat(_delta: float) -> void:
	var dist = player.global_position.distance_to(target.global_position)
	
	# Shooting
	if shoot_decision_timer <= 0.0:
		shoot_decision_timer = randf_range(0.15, 0.45)
		if dist < 650.0:
			player.shoot()
	
	# Defensive Dash
	if dash_decision_timer <= 0.0:
		dash_decision_timer = randf_range(1.5, 3.0)
		if dist < 150.0 or (player.current_health < player.max_health * 0.5 and randf() < 0.6):
			player.dash()
	
	# Ability Usage
	if player.ability_timer <= 0.0:
		if dist < 220.0 or player.current_health < player.max_health * 0.6:
			player.use_ability()
