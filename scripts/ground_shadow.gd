class_name GroundShadow
extends Node2D

## Weicher Schatten auf dem Boden unter einer Figur (Seitenansicht).
## Sucht per Strahl die nächste feste Fläche unter dem Besitzer; je höher
## die Figur darüber schwebt, desto kleiner und blasser der Schatten. Das
## erdet die Figuren und macht Sprünge besser lesbar.

const MAX_DROP: float = 300.0
const BASE_RADIUS: Vector2 = Vector2(19.0, 4.5)

var body: CollisionObject2D = null
# Abstand vom Mittelpunkt der Figur zu ihren Füßen (unskaliert).
var foot_offset: float = 16.0
var _strength: float = 0.0

func _init() -> void:
	top_level = true
	z_index = 9
	z_as_relative = false

func _physics_process(_delta: float) -> void:
	if body == null or not is_instance_valid(body) or not body.is_visible_in_tree():
		_set_strength(0.0)
		return
	var from := body.global_position
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, MAX_DROP), 1)
	query.exclude = [body.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		_set_strength(0.0)
		return
	var feet := from.y + foot_offset * body.scale.y
	var drop := maxf(0.0, float(hit["position"].y) - feet)
	global_position = hit["position"]
	var k := 1.0 - clampf(drop / MAX_DROP, 0.0, 1.0)
	scale = Vector2.ONE * absf(body.scale.x) / 1.7 * lerpf(0.55, 1.0, k)
	var alpha := 1.0
	if body is CanvasItem:
		alpha = (body as CanvasItem).modulate.a
	_set_strength(k * k * alpha)

func _set_strength(value: float) -> void:
	if is_equal_approx(value, _strength):
		return
	_strength = value
	visible = value > 0.02
	modulate.a = value
	queue_redraw()

func _draw() -> void:
	# Drei Ellipsen übereinander ergeben einen weichen Rand ohne Textur.
	for i in range(3):
		var f := 1.0 - float(i) * 0.24
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(BASE_RADIUS.x * f, BASE_RADIUS.y * f))
		draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.02, 0.06, 0.13))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
