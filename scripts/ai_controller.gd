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

# Lava-Flucht: Kommt steigende Lava näher als LAVA_ALERT_DISTANCE, klettert
# der Bot Ebene für Ebene nach oben, statt dem Gegner hinterherzulaufen.
const LAVA_ALERT_DISTANCE: float = 520.0
const BODY_FOOT_OFFSET: float = 12.0
var _climb_route: Dictionary = {}
var _climb_replan_timer: float = 0.0
var _climb_airborne: bool = false

# Heiße Kartoffel: Ist der Bot das Ziel, schießt er auf den Teufel, um ihn
# weiterzugeben. Sonst hält er das Feuer zurück, wenn der Teufel in der
# Schusslinie schwebt, damit er ihn nicht aus Versehen übernimmt.
const DEVIL_PASS_RANGE: float = 560.0
const DEVIL_LINE_MARGIN: float = 34.0
var _devil: Dictionary = {}
var _devil_aim: Vector2 = Vector2.INF

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
	# Unsichtbare Gegner (Powerup) werden nicht anvisiert.
	if not target or not is_instance_valid(target) or target.current_health <= 0.0 or target.is_invisible():
		target = _find_nearest_opponent()

	if not target or not is_instance_valid(target):
		return

	_update_devil_aim()
	_handle_aim(delta)
	_handle_navigation(delta)
	_handle_combat(delta)

func _find_nearest_opponent() -> Player:
	var best: Player = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p == player or not is_instance_valid(p) or p.current_health <= 0.0 or p.is_invisible():
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
	var goal: Vector2 = _devil_aim if _devil_aim != Vector2.INF else target.global_position
	var to_target = (_drop_compensated_aim_point(goal) - player.global_position).normalized()
	# Add slight noisy deviation
	var noise = Vector2(randf_range(-aim_spread, aim_spread), randf_range(-aim_spread, aim_spread))
	var desired_aim = (to_target + noise).normalized()
	player.aim_direction = player.aim_direction.lerp(desired_aim, reaction_speed * delta).normalized()

# Projektile fallen unter Schwerkraft. Der Bot zielt deshalb um den erwarteten
# Fall über das Ziel; die Flugzeit wird aus Entfernung und Schussgeschwindigkeit
# geschätzt und einmal nachgerechnet, weil der höhere Zielpunkt weiter weg liegt.
func _drop_compensated_aim_point(goal: Vector2) -> Vector2:
	var aim_point: Vector2 = goal
	var speed: float = maxf(player.bullet_speed, 1.0)
	var gravity: float = Bullet.BULLET_GRAVITY * maxf(0.0, player.projectile_gravity_mult)
	if gravity <= 0.0:
		return aim_point
	# Steht das Ziel klar höher, steigt die Kugel fast den ganzen Flug und
	# wird dabei stärker gebremst (Bullet.BULLET_RISE_GRAVITY_MULT).
	if goal.y < player.global_position.y - 72.0:
		gravity *= Bullet.BULLET_RISE_GRAVITY_MULT
	for i in range(2):
		var t: float = minf(player.global_position.distance_to(aim_point) / speed, 1.5)
		aim_point = goal + Vector2(0.0, -0.5 * gravity * t * t)
	return aim_point

func _devil_state() -> Dictionary:
	var main := player.get_parent()
	var manager = main.get("modifier_manager") if main != null else null
	if manager == null or not manager.has_method("get_devil_state"):
		return {}
	return manager.call("get_devil_state")

func _update_devil_aim() -> void:
	_devil_aim = Vector2.INF
	_devil = _devil_state()
	if _devil.is_empty() or bool(_devil["angry"]) or int(_devil["target_slot"]) != player.player_index:
		return
	var pos: Vector2 = _devil["pos"]
	if player.global_position.distance_to(pos) > DEVIL_PASS_RANGE:
		return
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, pos, 1)
	ray.exclude = [player.get_rid()]
	if not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	_devil_aim = pos

# true, wenn ein Schuss auf den Gegner den Teufel streifen und ihn so zum
# eigenen (wütenden) Ziel machen würde.
func _devil_in_line_of_fire() -> bool:
	if _devil.is_empty() or _devil_aim != Vector2.INF or bool(_devil["angry"]) \
			or int(_devil["target_slot"]) == player.player_index:
		return false
	var pos: Vector2 = _devil["pos"]
	var closest := Geometry2D.get_closest_point_to_segment(pos, player.global_position, target.global_position)
	return closest.distance_to(pos) < DEVIL_LINE_MARGIN

func _handle_navigation(_delta: float) -> void:
	# Während des kurzen Rückstoßfensters nicht sofort gegensteuern, damit
	# Treffer auch bei Bots sichtbar und spürbar bleiben.
	if player.knockback_timer > 0.0:
		return

	if _handle_lava_escape(_delta):
		return
	if _handle_zone_escape():
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
		# Gegner deutlich tiefer: durch einen Einweg-Steg nach unten fallen.
		elif dist_y > 90.0 and absf(dist_x) < 260.0 and randf() < 0.04 and player.drop_through():
			jump_cooldown = 0.5
		# Random unpredictable platform hops
		elif randf() < 0.015:
			player.jump()
			jump_cooldown = 0.6

func _lava_y() -> float:
	var main := player.get_parent()
	if main == null or not main.has_method("get_lava_surface_y"):
		return INF
	return float(main.call("get_lava_surface_y"))

# Liefert true, solange der Bot vor der Lava flieht (Navigation übernommen).
func _handle_lava_escape(delta: float) -> bool:
	var lava_y := _lava_y()
	if lava_y == INF or lava_y - player.global_position.y > LAVA_ALERT_DISTANCE:
		_climb_route = {}
		_climb_airborne = false
		return false
	var main := player.get_parent()
	var level = main.get("level_generator") if main != null else null
	if level == null or not level.has_method("find_climb_route"):
		return false

	# Heldengröße skaliert den Körper (18 x 22 px Grundmaß).
	var feet := player.global_position + Vector2(0.0, BODY_FOOT_OFFSET * player.scale.y)
	var speed := player.move_speed
	_climb_replan_timer -= delta
	if player.is_on_floor():
		_climb_airborne = false
		if _climb_route.is_empty() or _climb_replan_timer <= 0.0:
			_climb_route = level.call("find_climb_route", feet)
			_climb_replan_timer = 0.35
		if _climb_route.is_empty():
			# Kein Weg nach oben bekannt (z. B. schon auf dem Gipfel): normal
			# weiterkämpfen, aber nicht nach unten Richtung Lava laufen.
			return false
		var takeoff_x := float(_climb_route["takeoff_x"])
		var dx := takeoff_x - player.global_position.x
		if bool(_climb_route.get("pad", false)):
			player.velocity.x = move_toward(player.velocity.x, signf(dx) * speed, speed * 0.25)
			return true
		if absf(dx) > 8.0:
			player.velocity.x = move_toward(player.velocity.x, clampf(dx / 30.0, -1.0, 1.0) * speed, speed * 0.3)
		else:
			player.velocity.x = 0.0
			player.jump()
			_climb_airborne = true
		return true

	# In der Luft: erst steigen, bis die Füße über der Zielkante sind, dann
	# auf die Plattform hinübersteuern.
	if _climb_route.is_empty():
		return true
	var land_y := float(_climb_route["land_y"])
	var target_x := float(_climb_route["land_x"])
	if bool(_climb_route.get("pad", false)):
		# Erst im Schacht steigen, kurz vor dem Scheitel zur Landefläche.
		if player.velocity.y < -220.0:
			target_x = float(_climb_route["takeoff_x"])
	elif feet.y > land_y - 2.0 and _climb_route.has("edge_x"):
		# Noch unter der Kante: nur so weit hinüber, dass der Kopf nicht von
		# unten gegen die Plattform stößt.
		var dir := float(_climb_route["dir"])
		var safe_x := float(_climb_route["edge_x"]) + dir * (9.0 * player.scale.x + 4.0)
		if (player.global_position.x - safe_x) * dir < 0.0:
			target_x = safe_x
		else:
			target_x = player.global_position.x if absf(player.global_position.x - safe_x) < 4.0 else safe_x
	var ax := target_x - player.global_position.x
	player.velocity.x = move_toward(player.velocity.x, clampf(ax / 24.0, -1.0, 1.0) * speed, speed * 0.35)
	return true

const ZONE_SAFE_MARGIN: float = 30.0

func _zone_state() -> Dictionary:
	var main := player.get_parent()
	var manager = main.get("modifier_manager") if main != null else null
	if manager == null or not manager.has_method("get_zone_state"):
		return {}
	return manager.call("get_zone_state")

# Modifier "Zone": Außerhalb oder knapp am Rand läuft der Bot zur Kreismitte
# statt zum Gegner. Schießen läuft in _handle_combat weiter.
func _handle_zone_escape() -> bool:
	var zone := _zone_state()
	if zone.is_empty():
		return false
	var center: Vector2 = zone["center"]
	var radius := float(zone["radius"])
	if player.global_position.distance_to(center) < radius - ZONE_SAFE_MARGIN:
		return false
	var speed := player.move_speed
	var dx := center.x - player.global_position.x
	var move_input := signf(dx) if absf(dx) > 12.0 else 0.0
	move_input = _avoid_ground_hazards(move_input)
	player.velocity.x = move_toward(player.velocity.x, move_input * speed, speed * 0.25)
	if jump_cooldown <= 0.0 and (player.is_on_wall() or center.y < player.global_position.y - 60.0):
		player.jump()
		jump_cooldown = 0.45
	return true

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
		var shot_dist: float = dist
		if _devil_aim != Vector2.INF:
			shot_dist = player.global_position.distance_to(_devil_aim)
		if shot_dist < 650.0 and not _devil_in_line_of_fire():
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
		# Minenleger: auch ohne Druck ab und zu blocken, um Minen zu legen.
		elif player.block_mine and player.is_on_floor() and randf() < 0.35:
			player.start_block()
	
	# Nahkampf: zuschlagen, sobald der Gegner in Reichweite der Waffe ist.
	if Global.melee_enabled and player.melee_cooldown_timer <= 0.0 and dist < player.get_melee_reach() and randf() < 0.35:
		player.melee_attack()

	# Ability Usage
	if player.ability_timer <= 0.0:
		if dist < 220.0 or player.current_health < player.max_health * 0.6:
			player.use_ability()
