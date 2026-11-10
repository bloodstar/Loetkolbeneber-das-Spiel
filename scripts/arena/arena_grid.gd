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
# Vector2i -> Dictionary {"from": float, "to": float, "dir": Vector2i}
var ramps: Dictionary = {}
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
	return lerpf(float(r["from"]), float(r["to"]), clampf(t, 0.0, 1.0))

## Höchste Standfläche unter einem Körper in Höhe z. Berücksichtigt alle
## Zellen unter der Fußfläche (Rechteck mit Halbmaß half), damit man auf
## Kanten stehen bleibt. Flächen höher als z + step zählen nicht.
func support_height(pos: Vector2, z: float, half: Vector2, step: float) -> float:
	var best := 0.0
	var c0 := cell_of(pos - half)
	var c1 := cell_of(pos + half)
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			var cell := Vector2i(cx, cy)
			var f := base_floor(cell, pos)
			if f <= z + step:
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

func is_free_cell(cell: Vector2i) -> bool:
	return in_bounds(cell) and not blocks.has(cell) and not segment_cells.has(cell)
