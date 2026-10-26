class_name AIController
extends Node

@export var player: Player
var target: Player = null

# AI Parameters
var reaction_speed: float = 8.0
var aim_spread: float = 0.08
var combat_range: float = 300.0
var jump_cooldown: float = 0.0
var hazard_jump_cooldown: float = 0.0
var dash_decision_timer: float = 0.0
var shoot_decision_timer: float = 0.0
var block_decision_timer: float = 0.0

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
	if hazard_jump_cooldown > 0.0:
		hazard_jump_cooldown -= delta
	if dash_decision_timer > 0.0:
		dash_decision_timer -= delta
	if shoot_decision_timer > 0.0:
		shoot_decision_timer -= delta
	if block_decision_timer > 0.0:
		block_decision_timer -= delta
	
	# Ziel wählen: der nächstgelegene lebende Gegner (FFA-tauglich).
	if not target or not is_instance_valid(target) or target.current_health <= 0.0:
		target = _find_nearest_opponent()

	if not target or not is_instance_valid(target):
		return

	_handle_aim(delta)
	_handle_navigation(delta)
	_handle_combat(delta)

func _find_nearest_opponent() -> Player:
	var best: Player = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p == player or not is_instance_valid(p) or p.current_health <= 0.0:
			continue
		if p.team_id == player.team_id:
			continue
		var d: float = player.global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	if best:
		player.opponent = best
	return best

func _handle_aim(delta: float) -> void:
	var to_target = (target.global_position - player.global_position).normalized()
	# Add slight noisy deviation
	var noise = Vector2(randf_range(-aim_spread, aim_spread), randf_range(-aim_spread, aim_spread))
	var desired_aim = (to_target + noise).normalized()
	player.aim_direction = player.aim_direction.lerp(desired_aim, reaction_speed * delta).normalized()

func _handle_navigation(_delta: float) -> void:
	# Während des kurzen Rückstoßfensters nicht sofort gegensteuern, damit
	# Treffer auch bei Bots sichtbar und spürbar bleiben.
	if player.knockback_timer > 0.0:
		return

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
	
	# Stacheln früh erkennen und überspringen bzw. rechtzeitig abdrehen.
	move_input = _avoid_ground_hazards(move_input)
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

# Sucht den nächsten Bodenstachel in Laufrichtung. Die KI springt rechtzeitig
# darüber; falls das nicht mehr möglich ist, weicht sie zurück.
func _avoid_ground_hazards(move_input: float) -> float:
	var facing := signf(move_input)
	if facing == 0.0:
		facing = signf(target.global_position.x - player.global_position.x)
	if facing == 0.0:
		facing = 1.0

	var nearest_dist := 130.0
	var nearest_found := false
	for hazard in get_tree().get_nodes_in_group("hazard_spike"):
		if not is_instance_valid(hazard):
			continue
		var hazard_node := hazard as Node2D
		if hazard_node == null:
			continue
		var diff: Vector2 = hazard_node.global_position - player.global_position
		# Nur Hindernisse auf derselben Ebene berücksichtigen.
		if absf(diff.y) > 70.0:
			continue
		# Stacheln hinter dem Spieler ignorieren, direkt darunter aber erkennen.
		if absf(diff.x) > 18.0 and signf(diff.x) != facing:
			continue
		var dist_x := absf(diff.x)
		if dist_x < nearest_dist:
			nearest_dist = dist_x
			nearest_found = true

	if not nearest_found:
		return move_input

	if player.is_on_floor() and hazard_jump_cooldown <= 0.0 and nearest_dist < 115.0:
		player.jump()
		hazard_jump_cooldown = 0.7
		# Bei einem bereits fast erreichten Stachel zusätzlich vom Hindernis
		# wegspringen, statt weiter hineinzulaufen.
		if nearest_dist < 48.0:
			return -facing
		return move_input

	# Kein Sprung mehr möglich: von einem sehr nahen Stachel weggehen.
	if nearest_dist < 48.0 and player.is_on_floor():
		return -facing

	return move_input

func _handle_combat(_delta: float) -> void:
	var dist = player.global_position.distance_to(target.global_position)
	
	# Shooting
	if shoot_decision_timer <= 0.0:
		# Schnellere Klassen sollen ihre höhere Feuerrate auch als Bots nutzen.
		shoot_decision_timer = maxf(0.06, player.fire_rate_cooldown * randf_range(1.0, 2.0))
		if dist < 650.0:
			player.shoot()
	
	# Defensive Dash
	if dash_decision_timer <= 0.0:
		dash_decision_timer = randf_range(1.5, 3.0)
		if dist < 150.0 or (player.current_health < player.max_health * 0.5 and randf() < 0.6):
			player.dash()

	# Standard-Block: bei Druck oder niedriger HP gelegentlich hochhalten.
	if block_decision_timer <= 0.0:
		block_decision_timer = randf_range(0.8, 1.6)
		if dist < 380.0 and (player.current_health < player.max_health * 0.7 or randf() < 0.30):
			player.start_block()
	
	# Ability Usage
	if player.ability_timer <= 0.0:
		if dist < 220.0 or player.current_health < player.max_health * 0.6:
			player.use_ability()
