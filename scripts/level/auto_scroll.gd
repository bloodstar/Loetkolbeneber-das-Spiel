class_name AutoScroll
extends Node2D

## Autoscroll-Strecke: Ein Bildfenster fester Breite wandert mit eigener
## Geschwindigkeit über die Karte, alle müssen mithalten. Die hintere Kante
## ist eine rote Energiewand (Schaden und Schub nach vorn, wer dort an einer
## Wand klemmt, wird zerquetscht), die vordere Kante bremst nur.
##
## Effektfelder auf der Strecke (Layout-Key "scroll_fields"):
##   "turbo"   das Fenster scrollt TURBO_TIME Sekunden lang TURBO_MULT-mal so schnell
##   "reverse" die Scrollrichtung dreht sich um
## Ein Feld löst aus, sobald ein Spieler es berührt, und lädt danach
## FIELD_COOLDOWN Sekunden nach. Am Kartenende dreht die Richtung von selbst.
##
## Funktioniert in der Seitenansicht und in der Arena (Draufsicht): Die
## Strecke läuft immer entlang x. Der Host simuliert, Clients bekommen den
## Zustand im Snapshot (Schlüssel "scroll") und sagen die Bewegung voraus.

const DEFAULT_WINDOW_TILES: float = 40.0
const EDGE_MARGIN: float = 18.0
const EDGE_DAMAGE: float = 30.0
# Wer weit hinter der Kante hängt oder dort gegen eine Wand gedrückt wird.
const CRUSH_DAMAGE: float = 95.0
const CRUSH_DEPTH: float = 70.0
const PUSH_SPEED: float = 360.0
const LEAD_PUSH_SPEED: float = 160.0
const FIELD_COOLDOWN: float = 9.0
const TURBO_MULT: float = 1.8
const TURBO_TIME: float = 5.0
const SUDDEN_DEATH_MULT: float = 1.35
const PLASMA_INTERVAL: float = 0.3

const KIND_COLORS: Dictionary = {
	"turbo": Color(1.0, 0.72, 0.18),
	"reverse": Color(0.78, 0.42, 1.0),
}

## Aktive Strecke der laufenden Runde (null ohne Autoscroll).
static var current: AutoScroll = null

var base_speed: float = 70.0
var start_delay: float = 2.0
var window_w: float = DEFAULT_WINDOW_TILES * 36.0
var center_x: float = 0.0
var dir: float = 1.0
var turbo_timer: float = 0.0
var running: bool = false
var sudden: bool = false
var is_replica: bool = false
var map_px: Vector2 = Vector2.ZERO
var fields: Array[Dictionary] = []

var _delay_left: float = 0.0
var _time: float = 0.0
var _flash: float = 0.0
var _net_center: float = 0.0
var _net_age: float = 0.0
var _net_seen: bool = false
var _plasma_cd: Dictionary = {}

## cfg: speed (px/s), delay (s nach dem Countdown), window (Kacheln), dir
## (1 = nach rechts), start (Kachel der hinteren Fensterkante, optional).
## field_entries: [x, y, Höhe, Art] in Kacheln, ein Feld ist eine Kachel breit.
func setup(cfg: Dictionary, field_entries: Array, map_size: Vector2, tile: float) -> void:
	map_px = map_size
	base_speed = float(cfg.get("speed", 70.0))
	start_delay = float(cfg.get("delay", 2.0))
	window_w = minf(float(cfg.get("window", DEFAULT_WINDOW_TILES)) * tile, map_size.x)
	dir = 1.0 if float(cfg.get("dir", 1.0)) >= 0.0 else -1.0
	var half := window_w * 0.5
	if cfg.has("start"):
		center_x = clampf(float(cfg["start"]) * tile + half, half, map_size.x - half)
	else:
		center_x = half if dir > 0.0 else map_size.x - half
	_net_center = center_x
	fields.clear()
	for e in field_entries:
		if not (e is Array) or e.size() < 4:
			continue
		var kind := str(e[3])
		if not KIND_COLORS.has(kind):
			continue
		fields.append({
			"rect": Rect2(float(e[0]) * tile, float(e[1]) * tile, tile, float(e[2]) * tile),
			"kind": kind,
			"cd": 0.0,
		})
	z_index = 30
	current = self

func _exit_tree() -> void:
	if current == self:
		current = null

## Startet die Strecke (Ende des Rundencountdowns). Sie läuft nach
## start_delay Sekunden los.
func start() -> void:
	running = true
	_delay_left = start_delay

func half_width() -> float:
	return window_w * 0.5

func left_edge() -> float:
	return center_x - window_w * 0.5

func right_edge() -> float:
	return center_x + window_w * 0.5

## x der hinteren (gefährlichen) Kante.
func trailing_edge() -> float:
	return left_edge() if dir > 0.0 else right_edge()

func leading_edge() -> float:
	return right_edge() if dir > 0.0 else left_edge()

func current_speed() -> float:
	if not running or _delay_left > 0.0:
		return 0.0
	var v := base_speed
	if turbo_timer > 0.0:
		v *= TURBO_MULT
	if sudden:
		v *= SUDDEN_DEATH_MULT
	return v

## Position relativ zur Fenstermitte in Fahrtrichtung (positiv = vorn).
func relative_x(x: float) -> float:
	return (x - center_x) * dir

## Zoom, bei dem die Seitenansicht-Kamera Fensterbreite und Kartenhöhe zeigt.
func camera_zoom(screen: Vector2) -> float:
	return minf(screen.y / (map_px.y + 110.0), screen.x / (window_w + 90.0))

func _physics_process(delta: float) -> void:
	_time += delta
	_flash = maxf(0.0, _flash - delta)
	for f in fields:
		f["cd"] = maxf(0.0, float(f["cd"]) - delta)
	if is_replica:
		_net_age += delta
		var predicted := _net_center + dir * current_speed() * _net_age
		center_x = lerpf(center_x, predicted, clampf(delta * 10.0, 0.0, 1.0))
		return
	if not running:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
	turbo_timer = maxf(0.0, turbo_timer - delta)
	center_x += dir * current_speed() * delta
	var half := window_w * 0.5
	if dir > 0.0 and center_x >= map_px.x - half:
		center_x = map_px.x - half
		_reverse()
	elif dir < 0.0 and center_x <= half:
		center_x = half
		_reverse()
	_check_fields()
	_enforce_edges(delta)

func _process(_delta: float) -> void:
	queue_redraw()

func _alive_players() -> Array[Player]:
	var result: Array[Player] = []
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p) or not p.visible or p.is_replica:
			continue
		if p.is_dead or p.current_health <= 0.0:
			continue
		result.append(p)
	return result

func _reverse() -> void:
	dir = -dir
	_flash = 1.2
	SoundManager.play_sound("warning", 0.1, -2.0)

func _check_fields() -> void:
	var players := _alive_players()
	for f in fields:
		if float(f["cd"]) > 0.0:
			continue
		var rect: Rect2 = (f["rect"] as Rect2).grow(10.0)
		for p in players:
			if rect.has_point(p.global_position):
				_trigger(f)
				break

func _trigger(f: Dictionary) -> void:
	f["cd"] = FIELD_COOLDOWN
	match str(f["kind"]):
		"turbo":
			turbo_timer = TURBO_TIME
			SoundManager.play_sound("spring", 0.1, -2.0)
		"reverse":
			_reverse()

func _enforce_edges(delta: float) -> void:
	var trailing := trailing_edge()
	var leading := leading_edge()
	for key in _plasma_cd.keys():
		_plasma_cd[key] = float(_plasma_cd[key]) - delta
	for p in _alive_players():
		var x := p.global_position.x
		# > 0: im Randstreifen oder schon hinter der Kante.
		var depth := (trailing + dir * EDGE_MARGIN - x) * dir
		if depth > 0.0:
			if p.velocity.x * dir < 0.0:
				p.interrupt_rush()
			if p.velocity.x * dir < PUSH_SPEED:
				p.velocity.x = dir * PUSH_SPEED
			var dmg := EDGE_DAMAGE
			if depth > CRUSH_DEPTH or (p.is_on_wall() and not ArenaMode.active):
				dmg = CRUSH_DAMAGE
			p.take_damage(dmg * delta, Vector2.ZERO)
			var key := p.get_instance_id()
			if float(_plasma_cd.get(key, 0.0)) <= 0.0:
				_plasma_cd[key] = PLASMA_INTERVAL
				NetFx.emit(get_parent(), "plasma", NetFx.with_sound(
					{"p": Vector2(trailing, p.global_position.y), "d": Vector2(dir, 0.0)}, "bounce", 0.2, -8.0))
			continue
		var over := (x - (leading - dir * EDGE_MARGIN)) * dir
		if over > 0.0:
			if p.velocity.x * dir > 0.0:
				p.interrupt_rush()
			if p.velocity.x * dir > -LEAD_PUSH_SPEED:
				p.velocity.x = -dir * maxf(LEAD_PUSH_SPEED, over * 4.0)

# --- Netzwerk ------------------------------------------------------------

func get_network_state() -> Dictionary:
	var cds: Array = []
	for f in fields:
		cds.append(snappedf(float(f["cd"]), 0.01))
	return {
		"c": center_x,
		"d": dir,
		"t": turbo_timer,
		"r": running,
		"w": _delay_left,
		"s": sudden,
		"f": cds,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	_net_center = float(data.get("c", center_x))
	_net_age = 0.0
	var new_dir := float(data.get("d", dir))
	if new_dir != dir:
		dir = new_dir
		_flash = 1.2
		SoundManager.play_sound("warning", 0.1, -2.0)
	var new_turbo := float(data.get("t", 0.0))
	if new_turbo > turbo_timer + 1.0:
		SoundManager.play_sound("spring", 0.1, -2.0)
	turbo_timer = new_turbo
	running = bool(data.get("r", running))
	_delay_left = float(data.get("w", 0.0))
	sudden = bool(data.get("s", false))
	var cds = data.get("f", [])
	if cds is Array:
		for i in range(mini(cds.size(), fields.size())):
			fields[i]["cd"] = float(cds[i])
	if not _net_seen:
		_net_seen = true
		center_x = _net_center

# --- Darstellung ---------------------------------------------------------

func _draw() -> void:
	var top := -400.0
	var height := map_px.y + 800.0
	var left := left_edge()
	var right := right_edge()
	# Außerhalb des Fensters abdunkeln.
	var shade := Color(0.0, 0.0, 0.0, 0.5)
	draw_rect(Rect2(left - 3000.0, top, 3000.0, height), shade)
	draw_rect(Rect2(right, top, 3000.0, height), shade)

	for f in fields:
		_draw_field(f)

	_draw_trailing_wall(trailing_edge(), top, height)
	_draw_leading_line(leading_edge(), top, height)

	var font := ThemeDB.fallback_font
	var label_y := maxf(40.0, 60.0)
	if running and _delay_left > 0.0:
		_draw_center_text(font, "GLEICH GEHT'S LOS", label_y, Color(1.0, 1.0, 1.0, 0.85))
	elif turbo_timer > 0.0:
		var a := 0.65 + 0.35 * sin(_time * 12.0)
		_draw_center_text(font, "TURBO", label_y, Color(1.0, 0.75, 0.2, a))
	if _flash > 0.0:
		var a := clampf(_flash / 1.2, 0.0, 1.0)
		_draw_center_text(font, "RICHTUNG GEDREHT", label_y + 44.0, Color(0.85, 0.55, 1.0, a))
		var c := Vector2(center_x, map_px.y * 0.42)
		_draw_chevron(c, dir, 70.0, Color(0.85, 0.55, 1.0, a * 0.8), 9.0)
		_draw_chevron(c + Vector2(dir * 50.0, 0.0), dir, 70.0, Color(0.85, 0.55, 1.0, a * 0.5), 9.0)

func _draw_center_text(font: Font, text: String, y: float, color: Color) -> void:
	var size := 34
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center_x - w * 0.5, y)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_trailing_wall(x: float, top: float, height: float) -> void:
	var pulse := 0.75 + 0.25 * sin(_time * 7.0)
	var red := Color(1.0, 0.18, 0.22)
	# Glühender Streifen hinter der Kante.
	for i in range(5):
		var w := 14.0 + float(i) * 12.0
		var rx := x - w if dir > 0.0 else x
		draw_rect(Rect2(rx, top, w, height), Color(red.r, red.g, red.b, 0.05 * pulse))
	draw_line(Vector2(x, top), Vector2(x, top + height), Color(1.0, 0.55, 0.5, pulse), 5.0)
	draw_line(Vector2(x, top), Vector2(x, top + height), Color(red.r, red.g, red.b, 0.35 * pulse), 16.0)
	# Wandernde Pfeile zeigen die Fahrtrichtung.
	var spacing := 90.0
	var shift := fposmod(_time * 120.0, spacing)
	var y := top + shift
	while y < top + height:
		_draw_chevron(Vector2(x + dir * 16.0, y), dir, 14.0, Color(1.0, 0.45, 0.4, 0.7 * pulse), 3.0)
		y += spacing

func _draw_leading_line(x: float, top: float, height: float) -> void:
	var col := Color(0.4, 0.95, 1.0, 0.35)
	var y := top
	while y < top + height:
		draw_line(Vector2(x, y), Vector2(x, y + 22.0), col, 3.0)
		y += 40.0

func _draw_field(f: Dictionary) -> void:
	var rect: Rect2 = f["rect"]
	var kind := str(f["kind"])
	var base: Color = KIND_COLORS.get(kind, Color.WHITE)
	var cd := float(f["cd"])
	var ready := cd <= 0.0
	var pulse := 0.7 + 0.3 * sin(_time * 5.0 + rect.position.x * 0.01)
	var alpha := pulse if ready else 0.3
	draw_rect(rect, Color(base.r, base.g, base.b, 0.16 * alpha))
	draw_rect(rect.grow(6.0), Color(base.r, base.g, base.b, 0.07 * alpha))
	draw_rect(rect, Color(base.r, base.g, base.b, 0.9 * alpha), false, 3.0)
	var cx := rect.get_center().x
	var step := 30.0
	var count := maxi(1, int(rect.size.y / step))
	for i in range(count):
		var cy := rect.position.y + step * (float(i) + 0.5) * rect.size.y / (step * float(count))
		var c := Color(base.r, base.g, base.b, alpha)
		if kind == "turbo":
			_draw_chevron(Vector2(cx - dir * 5.0, cy), dir, 8.0, c, 3.0)
			_draw_chevron(Vector2(cx + dir * 5.0, cy), dir, 8.0, c, 3.0)
		else:
			_draw_chevron(Vector2(cx - 6.0, cy - 5.0), -1.0, 7.0, c, 2.5)
			_draw_chevron(Vector2(cx + 6.0, cy + 5.0), 1.0, 7.0, c, 2.5)
	if not ready:
		var p := 1.0 - cd / FIELD_COOLDOWN
		draw_rect(Rect2(rect.position.x, rect.end.y + 4.0, rect.size.x * p, 4.0), Color(base.r, base.g, base.b, 0.8))

func _draw_chevron(at: Vector2, facing: float, size: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array([
		at + Vector2(-facing * size * 0.6, -size),
		at + Vector2(facing * size * 0.6, 0.0),
		at + Vector2(-facing * size * 0.6, size),
	])
	draw_polyline(pts, color, width, true)
