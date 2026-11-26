class_name VoxelSprite
extends Node2D

## Voxel-Eber für die Seitenansicht (und 2D-Vorschauen).
##
## Rendert einen VoxelBoar in einem kleinen eigenen SubViewport (eigene
## 3D-Welt, transparenter Hintergrund) und zeichnet das Bild als 2D-Textur.
## Dadurch bleibt die 2D-Zeichenreihenfolge erhalten: Schüsse, Schilde und
## Effekte liegen wie bisher vor oder hinter der Figur.
##
## Hängt als Kind am PigCharacter-Knoten (der selbst nichts mehr zeichnet,
## voxel_mode = true). Damit erbt die Figur dessen Position, Skalierung
## (Spawn-Animation) und modulate; self_modulate (Powerup-Leuchten, Gift)
## wird jeden Frame übernommen.
##
## Lokale Einheiten = Einheiten des PigCharacter (Füße bei y = FEET_Y).

const FEET_Y: float = 17.0
## Sichtbarer Ausschnitt in lokalen Einheiten (quadratisch, Mitte über den Füßen).
const VIEW_SIZE: float = 72.0
const VIEW_CENTER_Y: float = 20.0      # 3D-Höhe der Bildmitte über den Füßen
## Bildauflösung: Pixel je lokaler Einheit (Spieler-Skalierung 1.7 × Zoom).
const PX_PER_UNIT: float = 4.0
## Eber-Größe relativ zu den lokalen Einheiten (2D-Schwein ≈ 36 hoch).
const BOAR_SCALE: float = 0.74
## Drehung zur Kamera, damit das Gesicht sichtbar ist (reines Profil zeigt es kaum).
const YAW_TOWARD_CAMERA: float = 45.0

var boar: VoxelBoar
var player: Player                 # optional: Zustand kommt dann vom Spieler
var facing_left: bool = false
var moving: bool = false
var airborne: bool = false
## Bildauflösung (vor dem Einhängen setzen), z. B. höher für die Lobby-Vorschau.
var px_per_unit: float = PX_PER_UNIT
## Zielwinkel ohne Spieler (+ = hoch), z. B. Hauptmenü.
var aim_pitch: float = 0.0
## Zusätzliche Drehung um die Hochachse (Bogenmaß), z. B. wenn die
## Lobby-Vorschau mit der Maus gedreht wird. 0 = normale Dreiviertel-Ansicht.
var user_yaw: float = 0.0
var _pending_spec: Dictionary = {}

var _vp: SubViewport
var _cam: Camera3D

func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	var px := int(VIEW_SIZE * px_per_unit)
	_vp.size = Vector2i(px, px)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.76, 0.95)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 1.25
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = VIEW_SIZE / BOAR_SCALE
	_cam.near = 1.0
	_cam.far = 1000.0
	# Leicht von oben, wie die Seitenansicht-Kamera der Mockups.
	var dir := Vector3(0.0, 0.18, 1.0).normalized()
	var center := Vector3(0.0, VIEW_CENTER_Y / BOAR_SCALE, 0.0)
	_cam.position = center + dir * 400.0
	_vp.add_child(_cam)
	_cam.look_at(center, Vector3.UP)
	_cam.current = true
	boar = VoxelBoar.new()
	_vp.add_child(boar)
	if not _pending_spec.is_empty():
		boar.build(_pending_spec)

## Ohne Spieler (Lobby-Vorschau, Menü): Figur direkt aus einer Spec bauen.
func build_spec(spec: Dictionary) -> void:
	if spec == _pending_spec and boar != null and boar.get_child_count() > 0:
		return
	_pending_spec = spec
	if boar != null:
		boar.build(spec)

func _process(delta: float) -> void:
	if boar == null:
		return
	var parent_pig := get_parent() as PigCharacter
	if parent_pig != null:
		self_modulate = parent_pig.self_modulate
		facing_left = parent_pig.flip_h
	if player != null and is_instance_valid(player):
		boar.sync_with_player(player, delta)
		# Laufen/Luft wie das 2D-Schwein bestimmen (funktioniert auch auf
		# Netzwerk-Replicas, die kein is_on_floor() haben).
		if parent_pig != null:
			moving = parent_pig._move_energy > 0.15
			airborne = parent_pig._air_energy > 0.5
		else:
			moving = absf(player.velocity.x) > 30.0
			airborne = not player.is_on_floor()
		var aim := player.aim_direction
		if aim.length_squared() > 0.001:
			# Zielwinkel relativ zur Blickrichtung, + = nach oben
			boar.aim_pitch = clampf(atan2(-aim.y, absf(aim.x)), -1.2, 1.2)
	else:
		boar.aim_pitch = aim_pitch
	boar.rotation.y = deg_to_rad(180.0 + YAW_TOWARD_CAMERA if facing_left else -YAW_TOWARD_CAMERA) + user_yaw
	boar.animate(delta, moving, airborne, 1.0, Vector2.ZERO, 0.0, player.velocity.y if player != null and is_instance_valid(player) else 0.0)
	queue_redraw()

func _draw() -> void:
	if _vp == null:
		return
	var half := VIEW_SIZE * 0.5
	# 3D-Bildmitte liegt VIEW_CENTER_Y über den Füßen (2D: y nach unten).
	var top := FEET_Y - VIEW_CENTER_Y - half
	draw_texture_rect(_vp.get_texture(), Rect2(Vector2(-half, top), Vector2(VIEW_SIZE, VIEW_SIZE)), false)

## Momentaufnahme als statische Textur (für Dash-Geister).
func snapshot_texture() -> Texture2D:
	if _vp == null:
		return null
	return ImageTexture.create_from_image(_vp.get_texture().get_image())
