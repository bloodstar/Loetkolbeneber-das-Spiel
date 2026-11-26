class_name LevelPreviewRenderer
extends Node

# Rendert Vorschaubilder der Maps direkt aus dem LevelGenerator. Jede Map wird
# einmal in einem unsichtbaren SubViewport gebaut, abfotografiert und wieder
# gelöscht. Neue Einträge in Global.MAP_PLAYABLE bekommen so automatisch ein
# Bild, ohne dass jemand Screenshots pflegen muss.

signal preview_ready(map_id: String, texture: Texture2D)

const LEVEL_SCENE: PackedScene = preload("res://scenes/level/procedural_level.tscn")
# 16:9, groß genug für die Vollbild-Ansicht; die Kacheln skalieren herunter.
const RENDER_SIZE: Vector2i = Vector2i(960, 540)
# Etwas Rand um die Map, damit Gummiwand und Kanten sichtbar bleiben.
const FRAME_MARGIN_TILES: float = 1.0
const BACKGROUND_COLOR: Color = Color(0.05, 0.06, 0.09, 1.0)

# Über Lobby-Neuaufbauten hinweg behalten; Maps ändern sich zur Laufzeit nicht.
static var _cache: Dictionary = {}

var _queue: Array[String] = []
var _busy: bool = false
var _viewport: SubViewport = null
var _camera: Camera2D = null

static func get_cached(map_id: String) -> Texture2D:
	return _cache.get(map_id, null) as Texture2D

static func has_cached(map_id: String) -> bool:
	return _cache.has(map_id)

# Reiht fehlende Vorschauen ein. Bereits gerenderte Maps werden übersprungen;
# die Lobby holt sie direkt über get_cached().
func request(map_ids: Array) -> void:
	for raw_id in map_ids:
		var map_id := str(raw_id)
		if _cache.has(map_id) or _queue.has(map_id):
			continue
		_queue.append(map_id)
	if not _busy and not _queue.is_empty():
		_render_queue()

# Eine angeklickte Map zuerst rendern, damit die Großansicht nicht wartet.
func prioritize(map_id: String) -> void:
	if _cache.has(map_id):
		return
	_queue.erase(map_id)
	_queue.push_front(map_id)
	if not _busy:
		_render_queue()

func is_busy() -> bool:
	return _busy

func _render_queue() -> void:
	_busy = true
	_ensure_viewport()
	while not _queue.is_empty():
		var map_id: String = _queue.pop_front()
		if _cache.has(map_id):
			continue
		var texture := await _render_map(map_id)
		if not is_inside_tree():
			break
		if texture != null:
			_cache[map_id] = texture
			preview_ready.emit(map_id, texture)
	_release_viewport()
	_busy = false

func _ensure_viewport() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "LevelPreviewViewport"
	_viewport.size = RENDER_SIZE
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_2d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# Eigene 2D-Welt mit abgeschalteter Physik: Kisten fallen nicht, Fässer
	# explodieren nicht und nichts berührt die echte Spielwelt.
	_viewport.world_2d = World2D.new()
	PhysicsServer2D.space_set_active(_viewport.world_2d.space, false)
	add_child(_viewport)

	var background := ColorRect.new()
	background.color = BACKGROUND_COLOR
	background.size = Vector2(RENDER_SIZE)
	var background_layer := CanvasLayer.new()
	background_layer.layer = -100
	background_layer.add_child(background)
	_viewport.add_child(background_layer)

	_camera = Camera2D.new()
	_viewport.add_child(_camera)
	_camera.make_current()

func _release_viewport() -> void:
	if _viewport == null:
		return
	_viewport.queue_free()
	_viewport = null
	_camera = null

func _preview_seed(map_id: String) -> int:
	# Fester Seed pro Map: Die Vorschau sieht bei jedem Öffnen gleich aus.
	return maxi(1, absi(hash("preview:" + map_id)) % 1000000)

func _render_map(map_id: String) -> Texture2D:
	# Arena- und Horden-Karten: Draufsicht direkt aus dem Zeichenraster malen.
	# Kein LevelGenerator, damit ArenaMode (statisch) unberührt bleibt.
	if ArenaMaps.is_arena_map(map_id):
		return render_arena_map(map_id)
	var level := LEVEL_SCENE.instantiate() as LevelGenerator
	if level == null:
		return null
	_viewport.add_child(level)
	level.generate_level(_preview_seed(map_id), map_id)

	var map_size: Vector2 = level.get_map_pixel_size()
	var margin: float = FRAME_MARGIN_TILES * LevelGenerator.TILE_SIZE
	var frame_size := map_size + Vector2(margin, margin) * 2.0
	var zoom := minf(float(RENDER_SIZE.x) / frame_size.x, float(RENDER_SIZE.y) / frame_size.y)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.position = map_size * 0.5

	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Zwei Frames: Im ersten werden Kamera und neue Knoten übernommen, der
	# zweite liefert das fertige Bild.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = null
	if _viewport != null:
		image = _viewport.get_texture().get_image()
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if is_instance_valid(level):
		level.get_parent().remove_child(level)
		level.queue_free()
	if image == null or image.is_empty():
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# --- Arena-Vorschau (Draufsicht) ---

const ARENA_CRATE: Color = Color(0.85, 0.55, 0.22)
const ARENA_BRIDGE: Color = Color(0.62, 0.42, 0.22)
const ARENA_SPAWN: Color = Color(0.25, 0.85, 0.95)

static func _map_color(data: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = data.get(key, null)
	if v is Color:
		return v
	if v is String and Color.html_is_valid(str(v)):
		return Color.html(str(v))
	return fallback

## Malt eine Arena-Karte von oben: eine Kachel = ein Block, Höhe über die
## Helligkeit, Kisten, Stege, Rampen und Spawns farbig. Ergebnis 16:9.
static func render_arena_map(map_id: String) -> Texture2D:
	var data := ArenaMaps.get_map(map_id)
	var rows: Array = data.get("rows", [])
	if rows.is_empty():
		return null
	var h := rows.size()
	var w := 0
	for r in rows:
		w = maxi(w, str(r).length())
	if w <= 0:
		return null
	var floor_c := _map_color(data, "floor", Color(0.3, 0.42, 0.26))
	var wall_c := _map_color(data, "wall", Color(0.5, 0.5, 0.54))
	var top_c := _map_color(data, "top", floor_c.lightened(0.1))
	var cliff_c := _map_color(data, "cliff", wall_c.darkened(0.15))
	var cell := maxi(1, mini(int(floor(float(RENDER_SIZE.x - 24) / float(w))), int(floor(float(RENDER_SIZE.y - 24) / float(h)))))
	var origin := Vector2i((RENDER_SIZE.x - w * cell) / 2, (RENDER_SIZE.y - h * cell) / 2)
	var image := Image.create(RENDER_SIZE.x, RENDER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(BACKGROUND_COLOR)
	var border := cell >= 4
	for y in range(h):
		var row := str(rows[y])
		for x in range(w):
			var ch := row[x] if x < row.length() else "."
			var col := floor_c
			var raised := true
			match ch:
				"c":
					col = wall_c.lightened(0.28)
				"H":
					col = wall_c.lightened(0.08)
				"#":
					col = wall_c.darkened(0.25)
				"x":
					col = ARENA_CRATE
				"p":
					col = top_c.lightened(0.06)
				"P":
					col = top_c.lightened(0.16)
				"T":
					col = top_c.lightened(0.26)
				"=":
					col = ARENA_BRIDGE
				">", "<", "^", "v":
					col = cliff_c.lightened(0.2)
				_:
					raised = false
					if (x + y) % 2 == 0:
						col = floor_c.darkened(0.06)
			var rect := Rect2i(origin + Vector2i(x, y) * cell, Vector2i(cell, cell))
			image.fill_rect(rect, col)
			if border and raised:
				var edge := col.darkened(0.35)
				image.fill_rect(Rect2i(rect.position + Vector2i(0, cell - 1), Vector2i(cell, 1)), edge)
				image.fill_rect(Rect2i(rect.position + Vector2i(cell - 1, 0), Vector2i(1, cell)), edge)
			if ch == "S":
				var dot := maxi(1, cell / 2)
				image.fill_rect(Rect2i(rect.position + Vector2i((cell - dot) / 2, (cell - dot) / 2), Vector2i(dot, dot)), ARENA_SPAWN)
	# Schräge Wände als dicke Linien (Eckpunkte in Kachel-Koordinaten).
	var thick := maxi(1, cell / 2)
	for raw in data.get("walls", []):
		var wall: Array = raw if raw is Array else []
		if wall.size() < 4:
			continue
		var a := Vector2(float(wall[0]), float(wall[1])) * cell + Vector2(origin)
		var b := Vector2(float(wall[2]), float(wall[3])) * cell + Vector2(origin)
		var steps := maxi(1, int(a.distance_to(b)))
		var line_c := wall_c.darkened(0.2)
		for i in range(steps + 1):
			var pt := a.lerp(b, float(i) / float(steps))
			var px := Vector2i(int(pt.x) - thick / 2, int(pt.y) - thick / 2)
			image.fill_rect(Rect2i(px, Vector2i(thick, thick)).intersection(Rect2i(Vector2i.ZERO, RENDER_SIZE)), line_c)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
