class_name ArenaBot
extends RefCounted

# Bot-Navigation für den Arena-Modus (Draufsicht). AIController ruft das statt
# der Plattform-Navigation auf. Zielen, Schießen, Blocken und Fähigkeiten
# bleiben im AIController. Wege laufen über eine Breitensuche im Höhenraster;
# niedrige Deckung (eine Schicht) gilt als begehbar und wird übersprungen.

const PREFERRED_MIN: float = 190.0
const PREFERRED_MAX: float = 360.0
const REPATH_INTERVAL: float = 0.4
const ZONE_SAFE_MARGIN: float = 60.0
const JUMPABLE_TOP: float = 40.0

static func navigate(ai: AIController, delta: float) -> void:
	var p := ai.player
	var target := ai.target
	var st: Dictionary = ai.get_meta("arena_bot", {})
	st["repath"] = float(st.get("repath", 0.0)) - delta
	st["strafe_t"] = float(st.get("strafe_t", 0.0)) - delta
	if float(st["strafe_t"]) <= 0.0:
		st["strafe_t"] = randf_range(0.6, 1.6)
		st["strafe"] = 1.0 if randf() < 0.5 else -1.0

	var goal := ai.target_pos()
	var mode := "fight"
	# Nahkämpfer gehen auf Schlagdistanz, statt Abstand zu halten.
	var pref_max := PREFERRED_MAX
	var pref_min := PREFERRED_MIN
	if p.is_melee:
		pref_max = p.get_melee_reach() * 0.8
		pref_min = 0.0
	var zone := ai._zone_state()
	if not zone.is_empty():
		var center: Vector2 = zone["center"]
		if p.global_position.distance_to(center) > float(zone["radius"]) - ZONE_SAFE_MARGIN:
			goal = center
			mode = "zone"

	var to_goal := goal - p.global_position
	var dist := to_goal.length()
	var sees := has_line_of_sight(p, target)
	var dir := Vector2.ZERO
	if mode == "zone" or not sees or dist > pref_max:
		dir = _path_direction(p, goal, st)
	elif dist < pref_min or (not p.is_melee and p.current_health < p.max_health * 0.35):
		dir = -to_goal.normalized()
		dir += to_goal.orthogonal().normalized() * float(st.get("strafe", 1.0)) * 0.6
	else:
		dir = to_goal.orthogonal().normalized() * float(st.get("strafe", 1.0))
		dir += to_goal.normalized() * 0.15
	dir = _avoid_walls(p, dir)
	ArenaMotion.apply_planar(p, dir.normalized() if dir != Vector2.ZERO else Vector2.ZERO)

	# Springen: über niedrige Deckung, gegen Wände, und ab und zu zum Ausweichen.
	if ai.jump_cooldown <= 0.0 and p.arena_grounded:
		var ahead := p.global_position + dir.normalized() * 30.0
		var cell := ArenaMode.grid.cell_of(ahead) if ArenaMode.grid else Vector2i.ZERO
		var top := ArenaMode.grid.top_at(cell) if ArenaMode.grid else 0.0
		if (top > p.arena_z + 2.0 and top <= p.arena_z + JUMPABLE_TOP) or randf() < 0.01 or _bullet_incoming(p):
			p.jump()
			ai.jump_cooldown = 0.5
	ai.set_meta("arena_bot", st)

## Sichtlinie in Schusshöhe (Mauern und Deckung der eigenen Höhe blocken).
static func has_line_of_sight(p: Player, target: Node2D) -> bool:
	var mask := ArenaMode.point_band_mask(ArenaMotion.muzzle_height(p))
	var ray := PhysicsRayQueryParameters2D.create(p.global_position, target.global_position, mask)
	ray.exclude = [p.get_rid()]
	var hit := p.get_world_2d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == target

static func _bullet_incoming(p: Player) -> bool:
	for b in p.get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.shooter == p:
			continue
		var rel: Vector2 = p.global_position - b.global_position
		if rel.length() < 120.0 and b.velocity.dot(rel) > 0.0:
			return randf() < 0.25
	return false

static func _path_direction(p: Player, goal: Vector2, st: Dictionary) -> Vector2:
	var grid := ArenaMode.grid
	if grid == null:
		return (goal - p.global_position).normalized()
	var start := grid.cell_of(p.global_position)
	var end := grid.cell_of(goal)
	if float(st.get("repath", 0.0)) <= 0.0 or st.get("goal_cell", Vector2i(-99, -99)) != end:
		st["repath"] = REPATH_INTERVAL
		st["goal_cell"] = end
		st["path"] = _bfs(start, end, p.arena_z)
	var path: Array = st.get("path", [])
	# Bereits erreichte Wegpunkte überspringen.
	while path.size() > 1 and (grid.cell_of(p.global_position) == path[0] \
			or p.global_position.distance_to((Vector2(path[0]) + Vector2(0.5, 0.5)) * grid.tile) < grid.tile * 0.45):
		path.remove_at(0)
	if path.is_empty():
		return (goal - p.global_position).normalized()
	var wp := (Vector2(path[0]) + Vector2(0.5, 0.5)) * grid.tile
	return (wp - p.global_position).normalized()

static func _bfs(start: Vector2i, end: Vector2i, z: float) -> Array:
	var grid := ArenaMode.grid
	if not grid.in_bounds(start) or not grid.in_bounds(end):
		return []
	# Pro Zelle die Standhöhe, mit der sie erreicht wurde (Rampen, Stufen,
	# Stege: unter einem Steg durch oder oben drüber).
	var came := {start: start}
	var height := {start: z}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var found := false
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == end:
			found = true
			break
		var hz: float = height[c]
		for d in dirs:
			var n: Vector2i = c + d
			if came.has(n):
				continue
			var nz := grid.reach_height(n, hz, JUMPABLE_TOP)
			if nz < 0.0:
				continue
			# Diagonal nur, wenn beide Nachbarn frei sind (keine Ecken schneiden).
			if d.x != 0 and d.y != 0 and (grid.reach_height(c + Vector2i(d.x, 0), hz, JUMPABLE_TOP) < 0.0 \
					or grid.reach_height(c + Vector2i(0, d.y), hz, JUMPABLE_TOP) < 0.0):
				continue
			came[n] = c
			height[n] = nz
			queue.append(n)
	if not found:
		return []
	var path: Array = []
	var cur := end
	while cur != start:
		path.push_front(cur)
		cur = came[cur]
	return path

## Leichtes Abstoßen von hohen Wänden, damit Bots nicht an Ecken kleben.
static func _avoid_walls(p: Player, dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return dir
	var space := p.get_world_2d().direct_space_state
	var mask := ArenaMode.body_band_mask(p.arena_z + ArenaMode.BAND_H) # nur Hindernisse über Sprunghöhe
	var result := dir.normalized()
	for ang in [-0.6, 0.6]:
		var probe := result.rotated(ang) * 34.0
		var ray := PhysicsRayQueryParameters2D.create(p.global_position, p.global_position + probe, mask)
		ray.exclude = [p.get_rid()]
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			result -= probe.normalized() * 0.5
	return result
