class_name ArenaGrid
extends RefCounted

# Höhenraster einer Arena. Jede Zelle hat eine Bodenhöhe (später Rampen) und
# eine Liste massiver Blöcke [unten, oben] in Pixeln. So lassen sich Mauern,
# niedrige Deckung, Stege (Block mit Luft darunter) und Rampen beschreiben.

var width: int = 0
var height: int = 0
var tile: float = 36.0
# Vector2i -> Array von Vector2(bottom, top)
var blocks: Dictionary = {}
# Rampen: Vector2i -> Dictionary {"lo", "hi", "dir": Vector2i, "s0", "len"}.
# Eine Rampe ist eine Reihe von Zellen in Steigrichtung dir. s0 ist die
# Position der Zelle in der Reihe (0 = unteres Ende), len die Länge. Die
# Höhe steigt von lo bis hi und erreicht hi eine halbe Kachel vor dem Ende,
# damit man oben sauber auf die anschließende Fläche tritt.
var ramps: Dictionary = {}
# Geländeblöcke (Erhöhungen): Vector2i -> true. Sie werden mit Bodentextur
# oben und Felswand an den Seiten gezeichnet statt als Mauer.
var terrain: Dictionary = {}
# Stege (Holz, Luft darunter): Vector2i -> true. Nur für die Darstellung.
var stege: Dictionary = {}
# Zerstörbare Blöcke: Vector2i -> tile_id. Brechen sie, verschwindet der Block.
var destructible: Dictionary = {}
# Schräge Wände: Strecken mit Dicke, frei gedreht. Jede als Dictionary
# {"a": Vector2, "b": Vector2, "thick": float, "bottom": float, "top": float}
# in Pixeln. Für Bots und Spawns zusätzlich grob ins Raster übertragen.
var segments: Array = []
var segment_cells: Dictionary = {} # Vector2i -> höchste Oberkante

func setup(w: int, h: int, tile_size: float) -> void:
	width = w
	height = h
	tile = tile_size
	blocks.clear()
	ramps.clear()
	terrain.clear()
	stege.clear()
	destructible.clear()
	segments.clear()
	segment_cells.clear()

func add_segment(a: Vector2, b: Vector2, thick: float, bottom: float, top: float) -> void:
	segments.append({"a": a, "b": b, "thick": thick, "bottom": bottom, "top": top})
	var pad := thick * 0.5 + tile * 0.2
	var c0 := cell_of(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(pad, pad))
	var c1 := cell_of(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(pad, pad))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var center := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * tile
			var d := center.distance_to(Geometry2D.get_closest_point_to_segment(center, a, b))
			if d <= thick * 0.5 + tile * 0.3:
				segment_cells[Vector2i(cx, cy)] = maxf(float(segment_cells.get(Vector2i(cx, cy), 0.0)), top)

## true, wenn das Fußrechteck (Mitte pos, Halbmaß half) die Wand berührt.
static func footprint_hits_segment(pos: Vector2, half: Vector2, seg: Dictionary) -> bool:
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	var closest := Geometry2D.get_closest_point_to_segment(pos, a, b)
	var reach := float(seg["thick"]) * 0.5 + minf(half.x, half.y)
	return pos.distance_to(closest) <= reach

func add_block(cell: Vector2i, bottom: float, top: float) -> void:
	if not blocks.has(cell):
		blocks[cell] = []
	(blocks[cell] as Array).append(Vector2(bottom, top))

func clear_cell(cell: Vector2i) -> void:
	blocks.erase(cell)

func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / tile)), int(floor(pos.y / tile)))

func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

## Bodenhöhe der Zelle an pos (Rampen steigen linear an).
func base_floor(cell: Vector2i, pos: Vector2) -> float:
	if not ramps.has(cell):
		return 0.0
	var r: Dictionary = ramps[cell]
	var d: Vector2i = r["dir"]
	var local := (pos - Vector2(cell) * tile) / tile
	var t := 0.0
	if d.x > 0:
		t = local.x
	elif d.x < 0:
		t = 1.0 - local.x
	elif d.y > 0:
		t = local.y
	else:
		t = 1.0 - local.y
	return ramp_height(r, float(r["s0"]) + clampf(t, 0.0, 1.0))

## Höhe einer Rampe an Position s (in Kacheln ab dem unteren Ende).
static func ramp_height(r: Dictionary, s: float) -> float:
	var run := maxf(0.5, float(r["len"]) - 0.5)
	return lerpf(float(r["lo"]), float(r["hi"]), clampf(s / run, 0.0, 1.0))

## Niedrigste und höchste Bodenhöhe einer Rampenzelle.
func ramp_span(cell: Vector2i) -> Vector2:
	if not ramps.has(cell):
		return Vector2.ZERO
	var r: Dictionary = ramps[cell]
	var s0 := float(r["s0"])
	return Vector2(ramp_height(r, s0), ramp_height(r, s0 + 1.0))

## Höchste Standfläche unter einem Körper in Höhe z. Berücksichtigt alle
## Zellen unter der Fußfläche (Rechteck mit Halbmaß half), damit man auf
## Kanten stehen bleibt. Flächen höher als z + step zählen nicht.
## ramp_step (>= 0) erlaubt auf Rampen größere Stufen: Von der Seite tritt
## man so auf den unteren Teil einer Rampe, statt in ihr zu stecken.
func support_height(pos: Vector2, z: float, half: Vector2, step: float, ramp_step: float = -1.0) -> float:
	var best := 0.0
	var rstep := step if ramp_step < 0.0 else ramp_step
	var c0 := cell_of(pos - half)
	var c1 := cell_of(pos + half)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var cell := Vector2i(cx, cy)
			var f := base_floor(cell, pos)
			if f <= z + rstep:
				best = maxf(best, f)
			for b in blocks.get(cell, []):
				var top: float = (b as Vector2).y
				if top <= z + step:
					best = maxf(best, top)
	for seg in segments:
		var seg_top: float = seg["top"]
		if seg_top <= z + step and seg_top > best and footprint_hits_segment(pos, half, seg):
			best = seg_top
	return best

## Höchste Oberkante an einer Stelle (für Spawns, Bots und Sicht).
func top_at(cell: Vector2i) -> float:
	var top := float(segment_cells.get(cell, 0.0))
	for b in blocks.get(cell, []):
		top = maxf(top, (b as Vector2).y)
	return top

## Standhöhe einer Zelle für die Bot-Wegsuche (Rampen: oberes Ende der Zelle).
func stand_height(cell: Vector2i) -> float:
	return maxf(top_at(cell), ramp_span(cell).y)

## Höhe, auf der man steht, wenn man von Höhe z aus in die Zelle läuft oder
## springt (höchstens reach höher). -1, wenn nicht erreichbar. Stege mit
## genug Luft darunter lassen den Boden darunter begehbar.
func reach_height(cell: Vector2i, z: float, reach: float) -> float:
	if not in_bounds(cell):
		return -1.0
	var seg_top := float(segment_cells.get(cell, 0.0))
	var cands: Array[float] = [maxf(ramp_span(cell).y, seg_top)]
	for b in blocks.get(cell, []):
		cands.append((b as Vector2).y)
	var best := -1.0
	for s in cands:
		if s > z + reach or s <= best:
			continue
		var free := true
		for b in blocks.get(cell, []):
			var span: Vector2 = b
			if span.x < s + ArenaMode.BODY_H and span.y > s + 0.5:
				free = false
				break
		if free:
			best = s
	return best

## Tiefste Unterkante eines Blocks über einem Körper in Höhe z (Decke, z. B.
## Steg). INF, wenn nichts darüber liegt.
func ceiling_height(pos: Vector2, z: float, half: Vector2) -> float:
	var best := INF
	var c0 := cell_of(pos - half)
	var c1 := cell_of(pos + half)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			for b in blocks.get(Vector2i(cx, cy), []):
				var span: Vector2 = b
				if span.x > z + ArenaMode.FOOT_CLEAR:
					best = minf(best, span.x)
	return best

func is_free_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and not blocks.has(cell) and not segment_cells.has(cell)
