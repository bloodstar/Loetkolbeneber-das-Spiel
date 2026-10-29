extends Node

## Headless-Prüfung der Level-Layouts.
##
## Aufruf (im Projektordner):
##   godot --headless res://tools/level_check.tscn
##   godot --headless res://tools/level_check.tscn -- --seeds=20 --maps=grasarena,eisgrotte
##
## Für jede Map und mehrere Seeds wird das Level erzeugt und geprüft:
##  - Erreichbarkeit: Vom Boden aus werden Sprünge des schwächsten Helden
##    (Sprungkraft 490, Tempo 270, kein Doppelsprung) simuliert. Jede
##    Standfläche, die so nicht erreichbar ist, wird gemeldet.
##  - Sprungfedern: Über einer Feder muss die Flugbahn frei sein.
##  - Wippen, Ketten- und Bewegungsplattformen: Ihr Schwenk- bzw. Fahrbereich
##    darf nicht von festen Kacheln oder Objekten blockiert werden.
##  - Drehbalken: Im Schwenkkreis plus Spielerhöhe liegt nichts Festes.
##    Erreichbar sein muss der Balken in waagrechter Stellung.
##  - Kopfraum: Standflächen mit weniger als zwei Kacheln Luft darüber.
## Einweg-Stege tragen nur von oben. Pyramiden- und Dachschrägen werden als
## Polygone geprüft (begehbar), Kistenketten zählen als Hindernis.
## Der Exit-Code ist die Anzahl der Levels mit Problemen (0 = alles ok).

const TILE := 36.0
const GRAVITY := 980.0
const JUMP_V := -490.0
const RUN_SPEED := 270.0
const DT := 1.0 / 60.0
const MAX_SIM_TIME := 2.6
const HALF := Vector2(9.0, 11.0)
const BODY_OFFSET := Vector2(0.0, 1.0)
const PAD_FORCE := -750.0
const TRAMPOLINE_FORCE := -690.0
const MIN_HEADROOM_PX := 72.0

# Strategien: [Startrichtung, Umschaltzeit, Richtung danach, springen?]
const STRATEGIES: Array = [
	[0.0, 9.0, 0.0, true],
	[1.0, 9.0, 1.0, true], [-1.0, 9.0, -1.0, true],
	[0.0, 0.12, 1.0, true], [0.0, 0.12, -1.0, true],
	[0.0, 0.28, 1.0, true], [0.0, 0.28, -1.0, true],
	[0.0, 0.45, 1.0, true], [0.0, 0.45, -1.0, true],
	[1.0, 0.3, 0.0, true], [-1.0, 0.3, 0.0, true],
	[1.0, 0.3, -1.0, true], [-1.0, 0.3, 1.0, true],
	[1.0, 9.0, 1.0, false], [-1.0, 9.0, -1.0, false],
	# Kurze Sprünge: Sprungtaste nach 0,12 s losgelassen (halbiert vy).
	[1.0, 9.0, 1.0, true, 0.12], [-1.0, 9.0, -1.0, true, 0.12],
]

var gen: LevelGenerator
var map_w := 44
var map_h := 25
var solid_cells: Dictionary = {}      # Vector2i -> true (feste Kacheln + Spezialkacheln)
var extra_rects: Array[Rect2] = []    # Mystery-Blöcke, Wippen, Kettenplattformen, Kisten ...
var extra_names: Array[String] = []
var pad_rects: Array[Rect2] = []
var oneway_cells: Dictionary = {}     # Einweg-Stege (Teilmenge von solid_cells)
var shape_polys: Array = []           # Kollisionspolygone (Pyramiden, Dächer) in Pixeln
var obstacle_rects: Array[Rect2] = [] # Kettenglieder und Kettenkisten: nur Hindernis
var trampoline_cells: Dictionary = {}
var print_ascii := false
var _last_unreached: Dictionary = {}

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := 12
	var maps: Array = []
	for a in args:
		if a == "--ascii":
			print_ascii = true
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--maps="):
			maps = Array(a.substr(7).split(","))
	if maps.is_empty():
		maps = Array(Global.MAP_PLAYABLE)
	gen = load("res://scenes/level/procedural_level.tscn").instantiate()
	add_child(gen)
	var bad_levels := 0
	var summary: Dictionary = {}
	for map_id in maps:
		var map_issues: Dictionary = {}
		for s in range(seeds):
			var level_seed := 1000 + s * 7919
			gen.generate_level(level_seed, str(map_id), [] as Array[String])
			var issues := check_current_level()
			if print_ascii and (s == 0 or not issues.is_empty()):
				_print_ascii("%s seed %d" % [map_id, level_seed])
				for issue in issues:
					print("  ! " + issue)
			if not issues.is_empty():
				bad_levels += 1
			for issue in issues:
				map_issues[issue] = int(map_issues.get(issue, 0)) + 1
		summary[map_id] = map_issues
		var total := 0
		for k in map_issues:
			total += int(map_issues[k])
		print("=== %s: %d Problem(e) in %d Seeds ===" % [map_id, total, seeds])
		var keys := map_issues.keys()
		keys.sort()
		for k in keys:
			print("  [%2dx] %s" % [map_issues[k], k])
	print("LEVEL_CHECK_DONE bad_levels=%d" % bad_levels)
	get_tree().quit(bad_levels)

# --- Level einlesen ---------------------------------------------------------

func _read_level() -> void:
	map_w = gen.get_map_width()
	map_h = gen.get_map_height()
	solid_cells.clear()
	extra_rects.clear()
	extra_names.clear()
	pad_rects.clear()
	trampoline_cells.clear()
	oneway_cells.clear()
	shape_polys.clear()
	obstacle_rects.clear()
	for c in gen._solid_cells.keys():
		solid_cells[c] = true
	for c in gen._oneway_cells.keys():
		oneway_cells[c] = true
	for c in gen._special_cells.keys():
		solid_cells[c] = true
	for child in gen.get_children():
		if child is JumpPad:
			# Area 18x12, mit Faktor 2 skaliert, Unterkante auf der Standfläche.
			pad_rects.append(Rect2(child.position.x - 18.0, child.position.y - 24.0, 36.0, 24.0))
		elif child is TrampolineGround:
			trampoline_cells[Vector2i(int(floor(child.position.x / TILE)), int(floor(child.position.y / TILE)))] = true
		elif child.is_in_group("mystery_block"):
			extra_rects.append(Rect2(child.position - Vector2(18, 18), Vector2(36, 36)))
			extra_names.append("Herz-Block")
		elif child is Seesaw:
			var w: float = child.plank_width
			extra_rects.append(Rect2(child.position.x - w * 0.5, child.position.y - 7.0, w, 14.0))
			extra_names.append("Wippe")
		elif child is ChainPlatform:
			var w2: float = child.platform_width
			var py: float = child.position.y + child.chain_length
			extra_rects.append(Rect2(child.position.x - w2 * 0.5, py - 7.0, w2, 14.0))
			extra_names.append("Kettenplattform")
		elif child is CrateChain:
			for link in child.get_children():
				if link is ChainLink:
					obstacle_rects.append(Rect2(link.position - Vector2(10, 10), Vector2(20, 20)))
		elif child is StaticBody2D and _has_polygon(child):
			for col in child.get_children():
				if col is CollisionPolygon2D:
					shape_polys.append(col.polygon)
		elif child is PhysicsCrate and child.has_meta("chain_crate"):
			var cs: float = 36.0 * child.crate_size
			obstacle_rects.append(Rect2(child.position - Vector2(cs, cs) * 0.5, Vector2(cs, cs)))
		elif child is PhysicsCrate:
			var s: float = 36.0 * child.crate_size
			extra_rects.append(Rect2(child.position - Vector2(s, s) * 0.5, Vector2(s, s)))
			extra_names.append("Kiste")
		elif child is RotatingPlatform:
			# Drehbalken: Als Standfläche zählt die waagrechte Stellung.
			for r in child.get_stand_rects():
				extra_rects.append(r)
				extra_names.append("Drehbalken")
		elif child.has_method("get_path_rect"):
			# Bewegungsplattform: Für die Erreichbarkeit zählt jede Position
			# entlang der Bahn. Wir nehmen Start, Mitte und Ende als Flächen.
			for p in child.get_sample_rects():
				extra_rects.append(p)
				extra_names.append("Bewegungsplattform")

func _has_polygon(node: Node) -> bool:
	for col in node.get_children():
		if col is CollisionPolygon2D:
			return true
	return false

# --- Kollisionen ------------------------------------------------------------

## vy/prev_bottom: Einweg-Stege tragen nur, wenn der Körper von oben kommt
## (fallend und vorher über der Oberkante). horizontal = Seitwärtsschritt.
func _hit(r: Rect2, vy: float = 1.0, prev_bottom: float = -INF, horizontal: bool = false) -> Variant:
	var x0 := int(floor(r.position.x / TILE))
	var x1 := int(floor((r.end.x - 0.001) / TILE))
	var y0 := int(floor(r.position.y / TILE))
	var y1 := int(floor((r.end.y - 0.001) / TILE))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell := Vector2i(x, y)
			if not solid_cells.has(cell):
				continue
			if oneway_cells.has(cell):
				var top := y * TILE
				if horizontal or vy <= 0.0 or prev_bottom > top + 2.0:
					continue
				return Rect2(x * TILE, top, TILE, 12.0)
			return Rect2(x * TILE, y * TILE, TILE, TILE)
	for e in extra_rects:
		if e.intersects(r):
			return e
	for o in obstacle_rects:
		if o.intersects(r):
			return o
	if not shape_polys.is_empty():
		for sx in [r.position.x, r.get_center().x, r.end.x]:
			for sy in [r.position.y, r.get_center().y, r.end.y]:
				var p := Vector2(sx, sy)
				if _in_shape(p):
					return _shape_rect_at(p)
	return null

func _in_shape(p: Vector2) -> bool:
	for poly in shape_polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false

# Ausdehnung des Polygons um einen Kontaktpunkt (für das Zurücksetzen).
func _shape_rect_at(p: Vector2) -> Rect2:
	var top := p.y
	while top > p.y - 72.0 and _in_shape(Vector2(p.x, top - 1.0)):
		top -= 1.0
	var bottom := p.y
	while bottom < p.y + 72.0 and _in_shape(Vector2(p.x, bottom + 1.0)):
		bottom += 1.0
	var left := p.x
	while left > p.x - 72.0 and _in_shape(Vector2(left - 1.0, p.y)):
		left -= 1.0
	var right := p.x
	while right < p.x + 72.0 and _in_shape(Vector2(right + 1.0, p.y)):
		right += 1.0
	return Rect2(left, top, right - left + 1.0, bottom - top + 1.0)

func _box(pos: Vector2) -> Rect2:
	return Rect2(pos + BODY_OFFSET - HALF, HALF * 2.0)

func _on_pad(pos: Vector2) -> bool:
	var b := _box(pos)
	for p in pad_rects:
		if p.intersects(b):
			return true
	return false

## Simuliert eine Bewegung. Liefert die Landeposition (Fußpunkt) oder null.
func _simulate(start: Vector2, strat: Array, start_vy: float) -> Variant:
	var pos := start
	var vy := start_vy
	var t := 0.0
	var airborne := false
	var pad_used := false
	var cut_time: float = float(strat[4]) if strat.size() > 4 else -1.0
	var cut_done := false
	while t < MAX_SIM_TIME:
		var dir: float = strat[0] if t < float(strat[1]) else strat[2]
		if cut_time >= 0.0 and not cut_done and t >= cut_time and vy < 0.0:
			vy *= 0.5
			cut_done = true
		if not pad_used and _on_pad(pos):
			vy = PAD_FORCE
			pad_used = true
		vy += GRAVITY * DT
		# Horizontal
		var dx := dir * RUN_SPEED * DT
		if dx != 0.0:
			pos.x += dx
			var h = _hit(_box(pos), 0.0, -INF, true)
			if h != null:
				var hr: Rect2 = h
				if dx > 0.0:
					pos.x = hr.position.x - HALF.x - BODY_OFFSET.x - 0.01
				else:
					pos.x = hr.end.x + HALF.x - BODY_OFFSET.x + 0.01
		if pos.x < 0.0 or pos.x > map_w * TILE:
			return null
		# Vertikal
		var prev_bottom := _box(pos).end.y
		pos.y += vy * DT
		var v = _hit(_box(pos), vy, prev_bottom)
		if v != null:
			var vr: Rect2 = v
			if vy > 0.0:
				pos.y = vr.position.y - HALF.y - BODY_OFFSET.y - 0.01
				if airborne:
					return Vector2(pos.x, vr.position.y)
				vy = 0.0
			else:
				pos.y = vr.end.y + HALF.y - BODY_OFFSET.y + 0.01
				vy = 0.0
		else:
			if vy > 30.0 or vy < -1.0:
				airborne = true
		if pos.y > map_h * TILE:
			return null
		t += DT
	return null

# --- Standflächen -----------------------------------------------------------

# Knoten: Vector2i(Spalte, Oberkante in Pixel)
func _collect_nodes() -> Dictionary:
	var nodes: Dictionary = {}
	for c in solid_cells.keys():
		var cell: Vector2i = c
		if solid_cells.has(Vector2i(cell.x, cell.y - 1)):
			continue
		var top := cell.y * TILE
		if _can_stand(Vector2((cell.x + 0.5) * TILE, top)):
			nodes[Vector2i(cell.x, int(round(top)))] = "Kachel"
	for i in range(extra_rects.size()):
		var r := extra_rects[i]
		var cx0 := int(floor(r.position.x / TILE))
		var cx1 := int(floor((r.end.x - 0.001) / TILE))
		for cx in range(cx0, cx1 + 1):
			var x := clampf((cx + 0.5) * TILE, r.position.x + 4.0, r.end.x - 4.0)
			if _can_stand(Vector2(x, r.position.y)):
				nodes[Vector2i(cx, int(round(r.position.y)))] = extra_names[i]
	# Oberkanten von Pyramiden und Dächern, spaltenweise abgetastet.
	if not shape_polys.is_empty():
		for cx in range(map_w):
			var px := (cx + 0.5) * TILE
			var y := 1.0
			while y < map_h * TILE:
				if _in_shape(Vector2(px, y)) and not _in_shape(Vector2(px, y - 1.0)):
					# Schmale Probe: Auf der Schräge steckt eine Ecke der
					# Körperbox sonst schon im Polygon.
					if _hit(Rect2(px - 2.0, y - 24.0, 4.0, 22.0)) == null:
						nodes[Vector2i(cx, int(round(y)))] = "Schräge"
				y += 1.0
	return nodes

func _feet_to_center(foot: Vector2) -> Vector2:
	return Vector2(foot.x, foot.y - HALF.y - BODY_OFFSET.y - 0.02)

func _can_stand(foot: Vector2) -> bool:
	return _hit(_box(_feet_to_center(foot))) == null

func _node_foot(n: Vector2i, nodes: Dictionary) -> Vector2:
	var x := (n.x + 0.5) * TILE
	# Bei schmalen Objekten (Kisten) mittig auf dem Objekt stehen.
	if str(nodes[n]) != "Kachel":
		for r in extra_rects:
			if absf(r.position.y - n.y) < 0.6 and x >= r.position.x - TILE and x <= r.end.x + TILE:
				x = clampf(x, r.position.x + 4.0, r.end.x - 4.0)
				break
	return Vector2(x, float(n.y))

func _landing_node(foot: Vector2, nodes: Dictionary) -> Variant:
	var k := Vector2i(int(floor(foot.x / TILE)), int(round(foot.y)))
	if nodes.has(k):
		return k
	for dx in [-1, 1]:
		var k2 := Vector2i(k.x + dx, k.y)
		if nodes.has(k2):
			return k2
	# Landung auf einer Schräge: Knoten derselben Spalte in der Nähe.
	for dy in range(-20, 21):
		var k3 := Vector2i(k.x, k.y + dy)
		if nodes.has(k3) and str(nodes[k3]) == "Schräge":
			return k3
	return null

# --- Prüfung ----------------------------------------------------------------

func check_current_level() -> Array[String]:
	_read_level()
	var issues: Array[String] = []
	var nodes := _collect_nodes()

	# Erreichbarkeit per BFS ab dem Boden.
	var ground_top := int(round((map_h - 2) * TILE))
	var reached: Dictionary = {}
	var queue: Array[Vector2i] = []
	for n in nodes.keys():
		if n.y == ground_top:
			reached[n] = true
			queue.append(n)
	while not queue.is_empty():
		var n: Vector2i = queue.pop_back()
		# Laufen auf derselben Höhe; auf Schrägen auch bergauf/bergab.
		for dx in [-1, 1]:
			var nb := Vector2i(n.x + dx, n.y)
			if nodes.has(nb) and not reached.has(nb):
				reached[nb] = true
				queue.append(nb)
			if str(nodes[n]) == "Schräge":
				for dy in range(-30, 31):
					var slope_nb := Vector2i(n.x + dx, n.y + dy)
					if nodes.has(slope_nb) and not reached.has(slope_nb):
						reached[slope_nb] = true
						queue.append(slope_nb)
		var foot := _node_foot(n, nodes)
		var start := _feet_to_center(foot)
		# Auf Schrägen den Startpunkt anheben, bis die Körperbox frei ist.
		var lift := 0
		while lift < 30 and _hit(_box(start)) != null:
			start.y -= 1.0
			lift += 1
		var cell := Vector2i(n.x, int(floor((n.y + 1) / TILE)))
		var base_vy := JUMP_V
		if trampoline_cells.has(cell):
			base_vy = TRAMPOLINE_FORCE
		for strat in STRATEGIES:
			var vy: float = base_vy if bool(strat[3]) else 0.0
			var land = _simulate(start, strat, vy)
			if land == null:
				continue
			var ln = _landing_node(land, nodes)
			if ln != null and not reached.has(ln):
				reached[ln] = true
				queue.append(ln)

	# Unerreichbare Flächen zu Segmenten zusammenfassen.
	var unreached: Array = []
	_last_unreached.clear()
	for n in nodes.keys():
		# Herz-Blöcke werden von unten angesprungen, ihre Oberseite muss
		# nicht erreichbar sein.
		if not reached.has(n) and str(nodes[n]) != "Herz-Block":
			unreached.append(n)
			_last_unreached[n] = true
	unreached.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var seg_start := -1
	var last: Vector2i = Vector2i(-99, -99)
	for i in range(unreached.size() + 1):
		var n: Vector2i = unreached[i] if i < unreached.size() else Vector2i(-99, -99)
		if i > 0 and (n.y != last.y or n.x != last.x + 1):
			issues.append("Unerreichbar: %s Reihe %d, Spalten %d-%d" % [nodes[last], int(last.y / TILE), seg_start, last.x])
			seg_start = n.x
		elif i == 0:
			seg_start = n.x
		last = n

	# Sprungfedern: Die komplette Flugbahn (ganze Sprunghöhe, Feder ±1 Kachel
	# breit) muss frei sein. Jede Plattform, Kiste oder bewegliche Plattform
	# darüber gilt als Fehler.
	for p in pad_rects:
		var foot := Vector2(p.get_center().x, p.end.y)
		var apex := (PAD_FORCE * PAD_FORCE) / (2.0 * GRAVITY)
		var probe := Rect2(foot.x - TILE * 1.5 + 1.0, foot.y - apex - HALF.y * 2.0, TILE * 3.0 - 2.0, apex + HALF.y * 2.0 - p.size.y - 1.0)
		var h = _hit(probe)
		if h != null:
			var hr: Rect2 = h
			issues.append("Sprungfeder unter Hindernis: Spalte %d Reihe %d (Hindernis %d px darüber)" % [int(p.position.x / TILE), int(p.position.y / TILE), int(foot.y - hr.end.y)])

	# Wippen / Kettenplattformen / Bewegungsplattformen: Schwenkbereich frei.
	for child in gen.get_children():
		if child is RotatingPlatform:
			var rotor_blockers := _rotor_blockers(child)
			if not rotor_blockers.is_empty():
				issues.append("Drehbalken bei Spalte %d blockiert durch %s" % [int(child.position.x / TILE), ", ".join(rotor_blockers)])
			continue
		var zone := Rect2()
		var label := ""
		var own := Rect2()
		if child is Seesaw:
			var w: float = child.plank_width
			var sweep: float = sin(child.max_angle) * w * 0.5
			zone = Rect2(child.position.x - w * 0.5 - 8.0, child.position.y - sweep - 60.0, w + 16.0, sweep * 2.0 + 60.0)
			label = "Wippe"
			own = Rect2(child.position.x - w * 0.5, child.position.y - 7.0, w, 14.0)
		elif child is ChainPlatform:
			var w2: float = child.platform_width
			var swing: float = child.chain_length * 0.35
			var py: float = child.position.y + child.chain_length
			zone = Rect2(child.position.x - w2 * 0.5 - swing, child.position.y, w2 + swing * 2.0, child.chain_length + 7.0)
			zone = zone.merge(Rect2(child.position.x - w2 * 0.5 - swing, py - 60.0, w2 + swing * 2.0, 67.0))
			label = "Kettenplattform"
			own = Rect2(child.position.x - w2 * 0.5, py - 7.0, w2, 14.0)
		elif child.has_method("get_path_rect"):
			zone = child.get_path_rect()
			label = "Bewegungsplattform"
		else:
			continue
		var blockers := _blockers_in(zone, own, child)
		if not blockers.is_empty():
			issues.append("%s bei Spalte %d blockiert durch %s" % [label, int(child.position.x / TILE), ", ".join(blockers)])

	# Kopfraum über festen Standflächen.
	for c in solid_cells.keys():
		var cell: Vector2i = c
		if solid_cells.has(Vector2i(cell.x, cell.y - 1)):
			continue
		if cell.y >= map_h - 2:
			continue
		for dy in range(1, 3):
			var above := Vector2i(cell.x, cell.y - dy)
			if solid_cells.has(above):
				issues.append("Zu wenig Kopfraum: Reihe %d Spalte %d" % [cell.y, cell.x])
				break
	return issues

## Alles, was in den Schwenkkreis des Drehbalkens (plus Spielerhöhe) ragt.
func _rotor_blockers(rotor: RotatingPlatform) -> Array[String]:
	var found: Dictionary = {}
	var c := rotor.position
	var reach := rotor.get_sweep_radius() + RotatingPlatform.CLEARANCE
	var in_circle := func(r: Rect2) -> bool:
		var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		return nearest.distance_to(c) < reach
	for raw in solid_cells.keys():
		var cell: Vector2i = raw
		if in_circle.call(Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))):
			found["Kacheln"] = true
			break
	var own := rotor.get_stand_rects()
	for i in range(extra_rects.size()):
		var r := extra_rects[i]
		if extra_names[i] == "Drehbalken" and own.any(func(o: Rect2) -> bool: return o.is_equal_approx(r)):
			continue
		if in_circle.call(r):
			found[extra_names[i]] = true
	for o in obstacle_rects:
		if in_circle.call(o):
			found["Kette"] = true
	for p in pad_rects:
		if in_circle.call(p):
			found["Sprungfeder"] = true
	for poly in shape_polys:
		var pts: PackedVector2Array = poly
		for k in range(pts.size()):
			var q := Geometry2D.get_closest_point_to_segment(c, pts[k], pts[(k + 1) % pts.size()])
			if q.distance_to(c) < reach:
				found["Schräge"] = true
				break
	var out: Array[String] = []
	for k in found.keys():
		out.append(str(k))
	return out

func _blockers_in(zone: Rect2, own: Rect2, obj: Node) -> Array[String]:
	var found: Dictionary = {}
	var x0 := int(floor(zone.position.x / TILE))
	var x1 := int(floor((zone.end.x - 0.001) / TILE))
	var y0 := int(floor(zone.position.y / TILE))
	var y1 := int(floor((zone.end.y - 0.001) / TILE))
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if solid_cells.has(Vector2i(x, y)):
				found["Kacheln"] = true
	for i in range(extra_rects.size()):
		var r := extra_rects[i]
		if own.size != Vector2.ZERO and r.is_equal_approx(own):
			continue
		if extra_names[i] == "Kiste" and obj is Seesaw:
			continue
		if extra_names[i] == "Bewegungsplattform" and obj.has_method("get_path_rect"):
			continue
		if r.intersects(zone):
			found[extra_names[i]] = true
	var out: Array[String] = []
	for k in found.keys():
		out.append(str(k))
	return out

func _print_ascii(title: String) -> void:
	var grid: Array = []
	for y in range(map_h):
		var row := []
		row.resize(map_w)
		row.fill(".")
		grid.append(row)
	var put := func(x: int, y: int, ch: String) -> void:
		if x >= 0 and x < map_w and y >= 0 and y < map_h:
			grid[y][x] = ch
	for c in gen._solid_cells.keys():
		put.call(c.x, c.y, "=" if gen._oneway_cells.has(c) else "#")
	for poly in shape_polys:
		for y in range(map_h):
			for x in range(map_w):
				if Geometry2D.is_point_in_polygon(Vector2((x + 0.5) * TILE, (y + 0.5) * TILE), poly):
					put.call(x, y, "/")
	for o in obstacle_rects:
		put.call(int(floor(o.get_center().x / TILE)), int(floor(o.get_center().y / TILE)), "o")
	for c in gen._special_cells.keys():
		put.call(c.x, c.y, "v")
	for i in range(extra_rects.size()):
		var r := extra_rects[i]
		var ch: String = {"Herz-Block": "B", "Wippe": "S", "Kettenplattform": "C", "Kiste": "K", "Bewegungsplattform": "M"}.get(extra_names[i], "?")
		for x in range(int(floor(r.position.x / TILE)), int(floor((r.end.x - 0.001) / TILE)) + 1):
			put.call(x, int(floor((r.get_center().y) / TILE)), ch)
	for p in pad_rects:
		put.call(int(floor(p.get_center().x / TILE)), int(floor(p.get_center().y / TILE)), "^")
	for c in trampoline_cells.keys():
		put.call(c.x, c.y, "T")
	for n in _last_unreached.keys():
		put.call(n.x, int(floor((n.y - 1) / TILE)), "!")
	print("--- %s (%dx%d) ---" % [title, map_w, map_h])
	var header := "    "
	for x in range(map_w):
		header += str(x % 10)
	print(header)
	for y in range(map_h):
		print("%3d %s" % [y, "".join(grid[y])])
