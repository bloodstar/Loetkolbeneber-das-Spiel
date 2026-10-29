class_name MagicWand
extends Node2D

## Lötkolben, den jedes Schwein einhändig führt: Gummigriff mit Kabel,
## Hitzeschutzhülse aus Stahl und eine Kupferspitze, deren vorderes Ende
## glüht. Form der Spitze und Glutfarbe stammen aus der Charakteranpassung
## und werden ohne Textur gezeichnet, damit sie sich im Spiel und in der
## Lobby sofort aktualisieren. Klassenname und Formschlüssel bleiben aus
## Kompatibilitätsgründen (Speicherstände, Netzwerk) unverändert:
## orb = Kegel, star = Meißel, crystal = Messer, flame = Huf, ball = Kugel,
## diamond = Diamant, spark = Stern, blaze = Flamme.

const SHAPES: Array[String] = ["orb", "star", "crystal", "flame", "ball", "diamond", "spark", "blaze"]
# Wie beim Schwein: keine weichen Linienkanten, damit der kleine Kolben
# im Spiel scharf bleibt.
const LINE_AA: bool = false
const TIP_CENTER: Vector2 = Vector2(21.5, 0.0)
const TIP_END_X: float = 23.2
const SLEEVE_END_X: float = 15.0
const GRIP_OUTLINE: Color = Color(0.07, 0.07, 0.09, 1.0)
const GRIP: Color = Color(0.16, 0.17, 0.20, 1.0)
const GRIP_HIGHLIGHT: Color = Color(0.34, 0.36, 0.42, 1.0)
const CABLE: Color = Color(0.10, 0.10, 0.12, 1.0)
const STEEL_OUTLINE: Color = Color(0.20, 0.22, 0.26, 1.0)
const STEEL: Color = Color(0.72, 0.75, 0.80, 1.0)
const STEEL_HIGHLIGHT: Color = Color(0.93, 0.95, 0.98, 1.0)
const COPPER_OUTLINE: Color = Color(0.35, 0.18, 0.08, 1.0)
const COPPER: Color = Color(0.78, 0.45, 0.22, 1.0)

var tip_shape: String = "orb"
var tip_color: Color = Color(0.6, 0.85, 1.0, 1.0)
var flip_v: bool = false
# Teamfarbe des Gummigriffs. Alpha 0 = keine Teams, dann bleibt er schwarz.
var grip_color: Color = Color(0.0, 0.0, 0.0, 0.0)

func _ready() -> void:
	queue_redraw()

func setup(shape: String, color: Color) -> void:
	tip_shape = shape if SHAPES.has(shape) else "orb"
	tip_color = color
	queue_redraw()

func set_grip_color(color: Color) -> void:
	if grip_color == color:
		return
	grip_color = color
	queue_redraw()

func set_flip_v(value: bool) -> void:
	if flip_v == value:
		return
	flip_v = value
	queue_redraw()

func _draw() -> void:
	if flip_v:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, -1.0))
	_draw_cable()
	_draw_grip()
	_draw_sleeve()
	_draw_tip()
	if flip_v:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_cable() -> void:
	# Kurzes Kabelstück, das hinten aus dem Griff hängt.
	draw_polyline(PackedVector2Array([
		Vector2(-5.6, 0.4),
		Vector2(-8.4, 1.6),
		Vector2(-10.2, 3.8),
		Vector2(-10.8, 6.0),
	]), CABLE, 1.4, LINE_AA)

func _draw_grip() -> void:
	# Gummigriff mit Rillen; der Ring vorne zeigt die Glutfarbe. In Team-Modi
	# ist der Gummi in der Teamfarbe eingefärbt.
	var team_tinted := grip_color.a > 0.0
	var grip_fill := grip_color.darkened(0.1) if team_tinted else GRIP
	var grip_highlight := grip_color.lightened(0.35) if team_tinted else GRIP_HIGHLIGHT
	var grip := PackedVector2Array([
		Vector2(-6.0, -2.0),
		Vector2(5.8, -2.6),
		Vector2(7.6, -1.8),
		Vector2(7.6, 1.8),
		Vector2(5.8, 2.6),
		Vector2(-6.0, 2.0),
	])
	draw_colored_polygon(grip, grip_fill)
	var outline := PackedVector2Array(grip)
	outline.append(grip[0])
	draw_polyline(outline, GRIP_OUTLINE, 0.7, LINE_AA)
	draw_line(Vector2(-5.0, -1.0), Vector2(5.4, -1.5), grip_highlight, 0.6, LINE_AA)
	for x in [-3.6, -1.6, 0.4, 2.4]:
		draw_line(Vector2(x, -1.9), Vector2(x, 1.9), GRIP_OUTLINE, 0.45, LINE_AA)
	draw_rect(Rect2(4.4, -2.5, 1.3, 5.0), tip_color.darkened(0.1), true)

func _draw_sleeve() -> void:
	# Hitzeschutzhülse aus Stahl, verjüngt sich zur Spitze hin.
	var sleeve := PackedVector2Array([
		Vector2(7.6, -1.3),
		Vector2(SLEEVE_END_X, -0.9),
		Vector2(SLEEVE_END_X, 0.9),
		Vector2(7.6, 1.3),
	])
	draw_colored_polygon(sleeve, STEEL)
	var outline := PackedVector2Array(sleeve)
	outline.append(sleeve[0])
	draw_polyline(outline, STEEL_OUTLINE, 0.45, LINE_AA)
	draw_line(Vector2(8.2, -0.6), Vector2(14.6, -0.4), STEEL_HIGHLIGHT, 0.4, LINE_AA)

func _draw_tip() -> void:
	var hot := tip_color.lightened(0.25)
	var core := tip_color.lightened(0.75)
	# Weicher Hitzeschein um das glühende Ende.
	draw_circle(TIP_CENTER, 7.4, Color(tip_color.r, tip_color.g, tip_color.b, 0.05))
	draw_circle(TIP_CENTER, 5.0, Color(tip_color.r, tip_color.g, tip_color.b, 0.10))
	draw_circle(TIP_CENTER, 3.2, Color(tip_color.r, tip_color.g, tip_color.b, 0.16))

	var points := _tip_points()
	draw_colored_polygon(points, COPPER)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, COPPER_OUTLINE, 0.4, LINE_AA)

	# Vorderes Drittel glüht in der gewählten Farbe.
	var glow := PackedVector2Array([Vector2(19.5, -0.7)])
	for point in points:
		if point.x > 19.5:
			glow.append(point)
	glow.append(Vector2(19.5, 0.7))
	if glow.size() >= 3:
		draw_colored_polygon(glow, hot)
	draw_circle(Vector2(TIP_END_X - 0.7, 0.0), 0.55, core)
	if tip_shape == "diamond":
		# Facetten des Diamanten.
		var facet := Color(1.0, 1.0, 1.0, 0.55)
		draw_line(Vector2(20.0, -1.9), Vector2(21.0, 0.0), facet, 0.3, LINE_AA)
		draw_line(Vector2(21.0, 0.0), Vector2(20.0, 1.9), facet, 0.3, LINE_AA)
		draw_line(Vector2(21.6, -1.9), Vector2(21.0, 0.0), facet, 0.3, LINE_AA)
		draw_line(Vector2(21.0, 0.0), Vector2(21.6, 1.9), facet, 0.3, LINE_AA)

func _tip_points() -> PackedVector2Array:
	var s := SLEEVE_END_X
	match tip_shape:
		"star":
			# Meißelspitze: flach mit gerader Stirnfläche.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(21.0, -0.8), Vector2(TIP_END_X, -0.45),
				Vector2(TIP_END_X, 0.45), Vector2(21.0, 0.8), Vector2(s, 0.9),
			])
		"crystal":
			# Messerspitze: einseitig angeschliffene Klinge.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(19.0, -0.9), Vector2(TIP_END_X + 0.3, 0.5),
				Vector2(19.0, 0.9), Vector2(s, 0.9),
			])
		"flame":
			# Hufspitze: schräg abgeschnitten.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(20.5, -0.9), Vector2(TIP_END_X - 0.4, -0.2),
				Vector2(21.8, 0.9), Vector2(s, 0.9),
			])
		"ball":
			# Kugelspitze: runder Kopf am Ende des Schafts.
			var ball := PackedVector2Array([Vector2(s, -0.9), Vector2(19.6, -0.6)])
			for i in range(11):
				var angle := lerpf(-2.3, 2.3, float(i) / 10.0)
				ball.append(Vector2(21.4, 0.0) + Vector2(cos(angle), sin(angle)) * 1.75)
			ball.append(Vector2(19.6, 0.6))
			ball.append(Vector2(s, 0.9))
			return ball
		"diamond":
			# Diamantspitze: geschliffener Edelstein.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(19.2, -0.6), Vector2(20.0, -1.9), Vector2(21.6, -1.9),
				Vector2(TIP_END_X + 0.2, 0.0), Vector2(21.6, 1.9), Vector2(20.0, 1.9),
				Vector2(19.2, 0.6), Vector2(s, 0.9),
			])
		"spark":
			# Sternspitze: vierzackiger Stern.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(20.0, -0.5), Vector2(20.7, -0.5), Vector2(21.4, -2.3),
				Vector2(22.0, -0.6), Vector2(TIP_END_X + 0.4, 0.0), Vector2(22.0, 0.6),
				Vector2(21.4, 2.3), Vector2(20.7, 0.5), Vector2(20.0, 0.5), Vector2(s, 0.9),
			])
		"blaze":
			# Flammenspitze: züngelnde Flamme.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(19.5, -0.9), Vector2(20.6, -1.8), Vector2(21.3, -0.8),
				Vector2(22.3, -1.4), Vector2(TIP_END_X + 0.2, 0.0), Vector2(22.2, 0.9),
				Vector2(20.6, 1.2), Vector2(s, 0.9),
			])
		_:
			# Kegelspitze (Standard): fein zulaufend.
			return PackedVector2Array([
				Vector2(s, -0.9), Vector2(22.6, -0.15), Vector2(TIP_END_X, 0.0),
				Vector2(22.6, 0.15), Vector2(s, 0.9),
			])
