class_name HordeBotController
extends Node

# Bot als Mitspieler im Horden-Modus: hält Abstand zur Horde, zielt auf den
# nächsten Gegner, sammelt Kristalle in der Nähe ein und bleibt beim Team.
# Ersetzt den AIController, solange der Horden-Modus läuft.

const KEEP_DIST: float = 210.0
const TEAM_LEASH: float = 520.0

var player: Player = null
var _shoot_t: float = 0.0
var _dash_t: float = 0.0
var _ability_t: float = 0.0
var _strafe: float = 1.0
var _strafe_t: float = 0.0

func _ready() -> void:
	player = get_parent() as Player

func _physics_process(delta: float) -> void:
	var d := HordeDirector.current
	if player == null or not is_instance_valid(player) or d == null or not d.running:
		return
	if not player.control_enabled or player.stun_timer > 0.0 or player.is_dead:
		return
	_shoot_t -= delta
	_dash_t -= delta
	_ability_t -= delta
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.6)
		_strafe = -_strafe
	var pos := player.global_position
	var target := _nearest_enemy(pos)
	var dir := Vector2.ZERO
	# Druck der Horde: gewichteter Fluchtvektor weg von nahen Gegnern.
	var threat := Vector2.ZERO
	var close := 0
	for node in player.get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var e := node as HordeEnemy
		if e == null or e.is_dead:
			continue
		var to: Vector2 = pos - e.global_position
		var dist := to.length()
		var reach := KEEP_DIST * (0.55 if player.is_melee else 1.0) + e.radius
		if dist < reach and dist > 0.1:
			threat += to / dist * (reach - dist) / reach * (3.0 if e.is_boss else 1.0)
			close += 1
	if threat != Vector2.ZERO:
		dir = threat.normalized() + threat.normalized().orthogonal() * _strafe * 0.35
	elif target != null:
		var to_t := target.global_position - pos
		if player.is_melee:
			dir = to_t.normalized()
		elif to_t.length() > 420.0:
			dir = to_t.normalized() * 0.6
		else:
			dir = to_t.normalized().orthogonal() * _strafe * 0.5
	# Kristalle in der Nähe mitnehmen, wenn es ruhig ist.
	if close == 0:
		var gem := _nearest_gem(d, pos, 320.0)
		if gem != Vector2.INF:
			dir = (gem - pos).normalized()
	# Beim Team bleiben.
	var mate := _nearest_mate(pos)
	if mate != null and pos.distance_to(mate.global_position) > TEAM_LEASH:
		dir = (dir * 0.3 + (mate.global_position - pos).normalized()).normalized()
	dir = _avoid_walls(pos, dir)
	ArenaMotion.apply_planar(player, dir)
	if target == null:
		return
	var to_target := target.global_position - pos
	player.aim_direction = player.aim_direction.lerp(to_target.normalized(), clampf(10.0 * delta, 0.0, 1.0)).normalized()
	var dist_t := to_target.length()
	if player.is_melee:
		if player.melee_cooldown_timer <= 0.0 and dist_t < player.get_melee_reach() + target.radius:
			player.attack()
	elif _shoot_t <= 0.0 and dist_t < 640.0:
		_shoot_t = maxf(0.06, player.fire_rate_cooldown * randf_range(1.0, 1.4))
		player.attack()
	if _dash_t <= 0.0 and close >= 3:
		_dash_t = randf_range(1.5, 3.0)
		player.dash()
	if player.arena_grounded and close >= 2 and randf() < 0.02:
		player.jump()
	if _ability_t <= 0.0 and player.ability_timer <= 0.0 and dist_t < 300.0:
		_ability_t = 1.0
		player.use_ability(target.global_position)
	if player.has_ult() and player.ult_timer <= 0.0 and (close >= 5 or target.is_boss) and randf() < 0.1:
		if player.has_targeted_ult():
			player.use_ultimate(target.global_position)
		else:
			player.use_ultimate()

func _nearest_enemy(pos: Vector2) -> HordeEnemy:
	var best: HordeEnemy = null
	var best_d := INF
	for node in player.get_tree().get_nodes_in_group(HordeEnemy.GROUP):
		var e := node as HordeEnemy
		if e == null or e.is_dead:
			continue
		var dd := pos.distance_squared_to(e.global_position)
		# Bosse etwas bevorzugen, damit sie nicht ewig leben.
		if e.is_boss:
			dd *= 0.6
		if dd < best_d:
			best_d = dd
			best = e
	return best

func _nearest_mate(pos: Vector2) -> Player:
	var best: Player = null
	var best_d := INF
	for node in player.get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or p == player or p.is_dead or p.is_bot:
			continue
		var dd := pos.distance_squared_to(p.global_position)
		if dd < best_d:
			best_d = dd
			best = p
	return best

func _nearest_gem(d: HordeDirector, pos: Vector2, max_dist: float) -> Vector2:
	var best := Vector2.INF
	var best_d := max_dist * max_dist
	for g in d._gems:
		var gp: Vector2 = g["pos"]
		var dd := pos.distance_squared_to(gp)
		if dd < best_d:
			best_d = dd
			best = gp
	return best

func _avoid_walls(pos: Vector2, dir: Vector2) -> Vector2:
	var grid := ArenaMode.grid
	if grid == null or dir == Vector2.ZERO:
		return dir
	var ahead := grid.cell_of(pos + dir.normalized() * 40.0)
	if grid.is_free_cell(ahead):
		return dir
	for a in [0.7, -0.7, 1.4, -1.4, 2.2, -2.2]:
		var alt := dir.rotated(a)
		if grid.is_free_cell(grid.cell_of(pos + alt.normalized() * 40.0)):
			return alt
	return dir
