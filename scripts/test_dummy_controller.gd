class_name TestDummyController
extends Node

## Steuerung des Testraum-Dummys, wenn er nicht als voller Bot läuft:
## Er bleibt stehen, zielt immer auf dich und schießt (oder schlägt in
## Reichweite) mit seiner normalen Feuerrate. Fähigkeiten nutzt er nicht.

var player: Player = null
var fire: bool = true
const AIM_TURN_RATE: float = 10.0
# Großzügig, damit er auch quer über kleine Karten feuert.
const MAX_SHOT_RANGE: float = 1600.0

func _ready() -> void:
	if player == null:
		player = get_parent() as Player

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead:
		return
	if not player.control_enabled or player.stun_timer > 0.0:
		return
	# Nicht wegrutschen: Laufeingabe immer 0 (Rückstoß wirkt trotzdem).
	if ArenaMode.active:
		ArenaMotion.apply_planar(player, Vector2.ZERO)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, 1400.0 * delta)
	var target := _target()
	if target == null:
		return
	var goal := _aim_point(target.global_position)
	var desired := (goal - player.global_position).normalized()
	player.aim_direction = player.aim_direction.lerp(desired, clampf(AIM_TURN_RATE * delta, 0.0, 1.0)).normalized()
	if not fire:
		return
	var dist := player.global_position.distance_to(target.global_position)
	if player.is_melee:
		if player.melee_cooldown_timer <= 0.0 and dist < player.get_melee_reach():
			player.attack()
	elif dist < MAX_SHOT_RANGE and _line_clear(target):
		player.attack()

# Nur bei freier Schusslinie feuern, sonst ballert er in die Wand vor sich.
func _line_clear(target: Player) -> bool:
	if ArenaMode.active:
		return ArenaBot.has_line_of_sight(player, target)
	var ray := PhysicsRayQueryParameters2D.create(player.global_position, target.global_position, 1)
	ray.exclude = [player.get_rid(), target.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _target() -> Player:
	var best: Player = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or p == player or not is_instance_valid(p) or p.is_dead:
			continue
		if p.team_id == player.team_id:
			continue
		var d := player.global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return best

# Wie AIController: um den Kugelfall nach oben vorhalten.
func _aim_point(goal: Vector2) -> Vector2:
	if ArenaMode.active:
		return goal
	var speed: float = maxf(player.bullet_speed, 1.0)
	var gravity: float = Bullet.BULLET_GRAVITY * maxf(0.0, player.projectile_gravity_mult)
	if gravity <= 0.0:
		return goal
	if goal.y < player.global_position.y - 72.0:
		gravity *= Bullet.BULLET_RISE_GRAVITY_MULT
	var aim_point := goal
	for i in range(2):
		var t: float = minf(player.global_position.distance_to(aim_point) / speed, 1.5)
		aim_point = goal + Vector2(0.0, -0.5 * gravity * t * t)
	return aim_point
