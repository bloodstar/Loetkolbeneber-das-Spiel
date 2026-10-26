class_name PortalSpawnEffect
extends Node2D

## Kurzlebiger Portal-Effekt beim Rundenstart. Der Effekt wird direkt am
## eigenen Charakter erzeugt und liegt hinter der Spielfigur, damit diese
## sichtbar aus dem Portal hervorkommt.

@export var duration: float = 1.45
@export var portal_color: Color = Color(0.55, 0.35, 1.0)

var _time: float = 0.0
var _active: bool = false

func _ready() -> void:
	visible = false
	set_process(false)

func start() -> void:
	_time = 0.0
	_active = true
	visible = true
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if not _active:
		return
	_time += delta
	if _time >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var t := clampf(_time / maxf(duration, 0.001), 0.0, 1.0)
	var open := clampf(t / 0.16, 0.0, 1.0)
	var close := clampf((1.0 - t) / 0.28, 0.0, 1.0)
	var alpha := open * close
	if alpha <= 0.001:
		return

	var pulse := 0.92 + 0.08 * sin(t * 30.0)
	var ring_radius := lerpf(9.0, 25.0, open) * pulse
	var center := Vector2(0.0, -24.0)

	# Magiekreis auf dem Boden.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 32.0, _with_alpha(portal_color, 0.10 * alpha))
	draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 40, _with_alpha(portal_color.lightened(0.2), 0.55 * alpha), 2.5, true)
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36, _with_alpha(Color(0.35, 0.85, 1.0), 0.35 * alpha), 1.5, true)

	# Aufrechter Portalring, passend zur Portal-Optik der Warp-Röhren.
	draw_set_transform(center, 0.0, Vector2(1.0, 1.18))
	draw_circle(Vector2.ZERO, ring_radius * 1.22, _with_alpha(portal_color, 0.10 * alpha))
	draw_circle(Vector2.ZERO, ring_radius * 0.95, _with_alpha(Color(0.02, 0.01, 0.06), 0.92 * alpha))
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 56, _with_alpha(portal_color.lightened(0.22), alpha), 3.0, true)
	draw_arc(Vector2.ZERO, ring_radius * 0.8, 0.0, TAU, 56, _with_alpha(Color(0.4, 0.92, 1.0), 0.8 * alpha), 1.5, true)

	# Wirbel im Inneren.
	for i in range(3):
		var swirl_radius := ring_radius * (0.65 - float(i) * 0.12)
		var start_angle := _time * (2.4 + float(i) * 0.6) + float(i) * TAU / 3.0
		var swirl_color := _with_alpha(Color(0.55, 0.92, 1.0), (0.70 - float(i) * 0.16) * alpha)
		draw_arc(Vector2.ZERO, swirl_radius, start_angle, start_angle + 1.6, 30, swirl_color, 1.8, true)

	# Funken am Rand.
	for i in range(9):
		var angle := -_time * 2.2 + float(i) * TAU / 9.0
		var spark_radius := ring_radius * (0.95 + 0.12 * sin(_time * 3.0 + float(i) * 1.7))
		var spark := Vector2(cos(angle) * spark_radius, sin(angle) * spark_radius)
		var twinkle := 0.5 + 0.5 * sin(_time * 7.0 + float(i) * 2.1)
		draw_circle(spark, 1.2 + twinkle * 1.2, _with_alpha(portal_color.lightened(0.45), twinkle * 0.9 * alpha))

	# Kurzer Öffnungsblitz in der Portalmitte.
	var flash := clampf(1.0 - t / 0.18, 0.0, 1.0)
	if flash > 0.0:
		draw_circle(Vector2.ZERO, ring_radius * 1.35, _with_alpha(Color(1.0, 1.0, 1.0), flash * 0.55))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
