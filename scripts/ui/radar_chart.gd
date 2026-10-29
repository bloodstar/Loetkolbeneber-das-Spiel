extends Control

# Netzdiagramm (Radar) für Kartenverteilungen. Jede Achse zeigt eine Anzahl;
# skaliert wird auf den größten Wert im Diagramm. Wird ohne class_name per
# preload benutzt (Charakterbogen im HUD, Kartenpool-Übersicht in der Lobby).

const POOL_COLORS: Dictionary = {
	"Offensive": Color(1.0, 0.55, 0.30),
	"Defensive": Color(0.40, 0.85, 0.55),
	"Bewegung": Color(0.45, 0.80, 1.0),
	"Nahkampf": Color(1.0, 0.78, 0.35),
}
const MAIN_TAG_COLOR := Color(0.55, 0.85, 1.0)
const RARITY_CHART_COLOR := Color(1.0, 0.72, 0.30)
const GRID_COLOR := Color(0.55, 0.62, 0.75, 0.22)
const LABEL_COLOR := Color(0.72, 0.78, 0.88, 1.0)
const LABEL_FONT_SIZE := 10
const TITLE_FONT_SIZE := 12

var chart_title: String = ""
var axis_labels: Array[String] = []
var values: Array[float] = []
var fill_color: Color = MAIN_TAG_COLOR
# Optional eigene Farbe pro Achsenbeschriftung (z. B. Seltenheitsfarben).
var label_colors: Array[Color] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(220, 200)

func setup(p_title: String, p_labels: Array[String], p_values: Array[float], p_color: Color, p_label_colors: Array[Color] = []) -> void:
	chart_title = p_title
	axis_labels = p_labels
	values = p_values
	fill_color = p_color
	label_colors = p_label_colors
	queue_redraw()

func _draw() -> void:
	var font := get_theme_default_font()
	var title_height := 18.0
	var total := 0.0
	for v in values:
		total += v
	draw_string(font, Vector2(0, 13), "%s (%d)" % [chart_title, int(total)], HORIZONTAL_ALIGNMENT_CENTER, size.x, TITLE_FONT_SIZE, fill_color)

	var count := axis_labels.size()
	if count < 3:
		return
	var center := Vector2(size.x * 0.5, title_height + (size.y - title_height) * 0.5)
	# Platz für die Beschriftungen rundherum lassen.
	var radius := minf(size.x * 0.5 - 46.0, (size.y - title_height) * 0.5 - 16.0)
	if radius < 10.0:
		return
	var max_value := 1.0
	for v in values:
		max_value = maxf(max_value, v)

	var dirs: Array[Vector2] = []
	for i in range(count):
		var angle := -PI * 0.5 + TAU * float(i) / float(count)
		dirs.append(Vector2(cos(angle), sin(angle)))

	# Gitterringe und Achsen.
	for ring in range(1, 5):
		var ring_points := PackedVector2Array()
		for d in dirs:
			ring_points.append(center + d * radius * float(ring) / 4.0)
		ring_points.append(ring_points[0])
		draw_polyline(ring_points, GRID_COLOR, 1.0, true)
	for d in dirs:
		draw_line(center, center + d * radius, GRID_COLOR, 1.0, true)

	# Werte-Fläche.
	var points := PackedVector2Array()
	for i in range(count):
		var v: float = values[i] if i < values.size() else 0.0
		points.append(center + dirs[i] * radius * clampf(v / max_value, 0.0, 1.0))
	if total > 0.0:
		var fill := fill_color
		fill.a = 0.28
		# Eine Fläche mit Nullwerten ist oft kein gültiges Polygon; dann nur
		# die Umrisslinie zeichnen.
		if Geometry2D.triangulate_polygon(points).size() > 0:
			draw_colored_polygon(points, fill)
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, fill_color, 2.0, true)
		for point in points:
			draw_circle(point, 2.5, fill_color)

	# Beschriftungen mit Anzahl.
	for i in range(count):
		var v: float = values[i] if i < values.size() else 0.0
		var text := "%s %d" % [axis_labels[i], int(v)]
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var anchor := center + dirs[i] * (radius + 6.0)
		var pos := anchor
		if dirs[i].x > 0.25:
			pos.x = anchor.x
		elif dirs[i].x < -0.25:
			pos.x = anchor.x - text_size.x
		else:
			pos.x = anchor.x - text_size.x * 0.5
		if dirs[i].y > 0.25:
			pos.y = anchor.y + text_size.y * 0.75
		elif dirs[i].y < -0.25:
			pos.y = anchor.y - 2.0
		else:
			pos.y = anchor.y + text_size.y * 0.35
		pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - text_size.x))
		var color := LABEL_COLOR
		if i < label_colors.size():
			color = label_colors[i]
		if v <= 0.0:
			color.a *= 0.45
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, color)

# Baut alle Verteilungs-Diagramme für eine Kartenliste: Haupt-Tags, je Haupt-Tag
# die Sub-Tags seiner Karten und die Seltenheiten.
static func build_card_charts(cards: Array, columns: int = 4, chart_size: Vector2 = Vector2(220, 200)) -> GridContainer:
	var script: GDScript = load("res://scripts/ui/radar_chart.gd")
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var pool_counts: Dictionary = {}
	var rarity_counts: Dictionary = {}
	for card in cards:
		if card == null:
			continue
		pool_counts[card.pool] = int(pool_counts.get(card.pool, 0)) + 1
		rarity_counts[card.rarity] = int(rarity_counts.get(card.rarity, 0)) + 1

	var main_labels: Array[String] = []
	var main_values: Array[float] = []
	var main_colors: Array[Color] = []
	for pool in Global.CARD_POOLS:
		main_labels.append(pool)
		main_values.append(float(pool_counts.get(pool, 0)))
		main_colors.append(POOL_COLORS.get(pool, LABEL_COLOR))
	var main_chart: Control = script.new()
	main_chart.custom_minimum_size = chart_size
	main_chart.setup("Haupt-Tags", main_labels, main_values, MAIN_TAG_COLOR, main_colors)
	grid.add_child(main_chart)

	for pool in Global.CARD_POOLS:
		var labels: Array[String] = CardDatabase.get_sub_tags_for_pool(pool)
		var sub_values: Array[float] = []
		for tag in labels:
			var n := 0
			for card in cards:
				if card != null and card.pool == pool and card.sub_tags.has(tag):
					n += 1
			sub_values.append(float(n))
		var chart: Control = script.new()
		chart.custom_minimum_size = chart_size
		chart.setup(pool, labels, sub_values, POOL_COLORS.get(pool, MAIN_TAG_COLOR))
		grid.add_child(chart)

	var rarity_labels: Array[String] = []
	var rarity_values: Array[float] = []
	var rarity_colors: Array[Color] = []
	for rarity in Global.RARITY_ORDER:
		rarity_labels.append(rarity)
		rarity_values.append(float(rarity_counts.get(rarity, 0)))
		rarity_colors.append(CardDatabase.get_rarity_color(rarity))
	var rarity_chart: Control = script.new()
	rarity_chart.custom_minimum_size = chart_size
	rarity_chart.setup("Seltenheit", rarity_labels, rarity_values, RARITY_CHART_COLOR, rarity_colors)
	grid.add_child(rarity_chart)
	return grid
