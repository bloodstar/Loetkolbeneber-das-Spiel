class_name SpaceDirector
extends Node

## Regie der Weltraum-Maps (Profil "space"): hält eine Anzahl treibender
## Asteroiden und Weltraumquallen im Spiel. Neue kommen vom Kartenrand
## herein; auf Autoscroll-Strecken vor dem Fenster, sodass sie den Spielern
## entgegentreiben. Läuft nur auf dem Host (bzw. offline), die Objekte
## selbst gehen als Map-Objekte über den Snapshot an die Clients.
##
## cfg: asteroids (gleichzeitig), big (Anteil große), loot (Anteil kleine
## mit Powerup-Kern), monsters (gleichzeitig), monster_delay (s bis zum
## ersten/nächsten Monster), drift [min, max] px/s.

const SPAWN_INTERVAL: float = 0.8
const SAFE_SPAWN_DISTANCE: float = 220.0

var asteroid_target: int = 8
var big_share: float = 0.3
var loot_share: float = 0.45
var monster_target: int = 2
var monster_delay: float = 10.0
var drift_min: float = 40.0
var drift_max: float = 110.0

var _lg: LevelGenerator = null
var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _monster_timer: float = 0.0
var _initial_done: bool = false

func setup(lg: LevelGenerator, cfg: Dictionary, level_seed: int) -> void:
	_lg = lg
	asteroid_target = int(cfg.get("asteroids", asteroid_target))
	big_share = float(cfg.get("big", big_share))
	loot_share = float(cfg.get("loot", loot_share))
	monster_target = int(cfg.get("monsters", monster_target))
	monster_delay = float(cfg.get("monster_delay", monster_delay))
	var drift: Array = cfg.get("drift", [drift_min, drift_max])
	if drift.size() >= 2:
		drift_min = float(drift[0])
		drift_max = float(drift[1])
	_rng.seed = hash([level_seed, "space"])
	_monster_timer = monster_delay

func _is_host() -> bool:
	return not Global.network_mode or Global.is_local_host()

func _physics_process(delta: float) -> void:
	if _lg == null or not is_instance_valid(_lg) or not _is_host():
		return
	if Global.current_state != Global.GameState.PLAYING:
		return
	if not _initial_done:
		_initial_done = true
		_spawn_initial()
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
		if _count("asteroid") < asteroid_target:
			_spawn_asteroid_at_edge()
	if monster_target > 0 and _count("space_monster") < monster_target:
		_monster_timer -= delta
		if _monster_timer <= 0.0:
			_monster_timer = monster_delay
			var pos := _edge_point(80.0)
			_lg.spawn_space_monster(pos)

func _count(group: String) -> int:
	var n := 0
	for node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			n += 1
	return n

func _map_size() -> Vector2:
	return Vector2(float(LevelGenerator.map_w), float(LevelGenerator.map_h)) * LevelGenerator.TILE_SIZE

func _random_size() -> int:
	var r := _rng.randf()
	if r < big_share:
		return 3
	if r < big_share + (1.0 - big_share) * 0.5:
		return 2
	return 1

## Startbelegung: über die Karte (bzw. das Startfenster und davor) verteilt,
## nicht auf Spielern und nicht in Stationen.
func _spawn_initial() -> void:
	var size := _map_size()
	var area := Rect2(Vector2.ZERO, size)
	var scroll := _lg.auto_scroll
	if scroll != null and is_instance_valid(scroll):
		var lo := minf(scroll.left_edge(), scroll.left_edge() + scroll.dir * scroll.window_w)
		var hi := maxf(scroll.right_edge(), scroll.right_edge() + scroll.dir * scroll.window_w)
		area = Rect2(Vector2(maxf(0.0, lo), 0.0), Vector2(minf(size.x, hi) - maxf(0.0, lo), size.y))
	var placed := 0
	var attempts := 0
	while placed < asteroid_target and attempts < asteroid_target * 30:
		attempts += 1
		var pos := Vector2(_rng.randf_range(area.position.x + 60.0, area.end.x - 60.0),
			_rng.randf_range(60.0, size.y - 60.0))
		var s := _random_size()
		if not _is_free(pos, Asteroid.radius_for(s) + 20.0):
			continue
		_lg.spawn_asteroid(pos, s, _random_drift(), s == 1 and _rng.randf() < loot_share)
		placed += 1

func _random_drift() -> Vector2:
	return Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(drift_min, drift_max)

func _is_free(pos: Vector2, radius: float) -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and (node as Node2D).global_position.distance_to(pos) < SAFE_SPAWN_DISTANCE + radius:
			return false
	for i in range(2):
		var p := _lg.p1_spawn_pos if i == 0 else _lg.p2_spawn_pos
		if p.distance_to(pos) < SAFE_SPAWN_DISTANCE + radius:
			return false
	for node in get_tree().get_nodes_in_group("space_hazard"):
		if node is Node2D and (node as Node2D).global_position.distance_to(pos) < radius + 60.0:
			return false
	var space := _lg.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	query.shape = shape
	query.transform = Transform2D(0.0, pos)
	query.collision_mask = 1
	return space.intersect_shape(query, 1).is_empty()

## Punkt knapp außerhalb des Kartenrands (Autoscroll: vor dem Fenster).
func _edge_point(margin: float) -> Vector2:
	var size := _map_size()
	var scroll := _lg.auto_scroll
	if scroll != null and is_instance_valid(scroll):
		var x := scroll.leading_edge() + scroll.dir * (margin + _rng.randf_range(0.0, 200.0))
		x = clampf(x, -margin, size.x + margin)
		return Vector2(x, _rng.randf_range(60.0, size.y - 60.0))
	match _rng.randi() % 4:
		0:
			return Vector2(-margin, _rng.randf_range(60.0, size.y - 60.0))
		1:
			return Vector2(size.x + margin, _rng.randf_range(60.0, size.y - 60.0))
		2:
			return Vector2(_rng.randf_range(60.0, size.x - 60.0), -margin)
		_:
			return Vector2(_rng.randf_range(60.0, size.x - 60.0), size.y + margin)

func _spawn_asteroid_at_edge() -> void:
	var size := _map_size()
	var s := _random_size()
	var pos := _edge_point(Asteroid.radius_for(s) + 40.0)
	if not _is_free(pos, Asteroid.radius_for(s) + 10.0):
		return
	# Richtung ungefähr zur Kartenmitte (bzw. dem Fenster entgegen).
	var goal := size * 0.5
	var scroll := _lg.auto_scroll
	if scroll != null and is_instance_valid(scroll):
		goal = Vector2(scroll.center_x, _rng.randf_range(size.y * 0.2, size.y * 0.8))
	else:
		goal += Vector2(_rng.randf_range(-size.x * 0.3, size.x * 0.3), _rng.randf_range(-size.y * 0.3, size.y * 0.3))
	var vel := (goal - pos).normalized() * _rng.randf_range(drift_min, drift_max)
	_lg.spawn_asteroid(pos, s, vel, s == 1 and _rng.randf() < loot_share)
