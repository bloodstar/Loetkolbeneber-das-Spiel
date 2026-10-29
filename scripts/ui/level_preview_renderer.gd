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
