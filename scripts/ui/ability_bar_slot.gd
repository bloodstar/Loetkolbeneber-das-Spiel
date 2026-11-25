class_name AbilityBarSlot
extends Control

## Ein Feld der Fähigkeitenleiste (siehe ability_bar.gd), im Stil einer
## MMO-Zauberleiste: quadratisches Symbol, Taste oben links, Abklingzeit als
## dunkle Abdeckung, die von unten nach oben wieder aufgefüllt wird, Restzeit
## als Zahl in der Mitte. Status-Felder (Schild, Powerups, Gift ...) laufen
## andersherum ab: der helle Teil schrumpft mit der Restdauer.
##
## Die Werte setzt AbilityBar jeden Frame, das Feld zeichnet nur.

const BG_COLOR: Color = Color(0.035, 0.045, 0.07, 0.92)
const BORDER_COLOR: Color = Color(0.55, 0.62, 0.72, 0.55)
const COOLDOWN_COLOR: Color = Color(0.0, 0.0, 0.02, 0.68)
const TEXT_SHADOW: Color = Color(0.0, 0.0, 0.0, 0.9)

# Symbolart, siehe _draw_symbol().
var kind: String = ""
var accent: Color = Color.WHITE
var key_text: String = ""
# Abklingzeit: 1 = gerade benutzt, 0 = bereit.
var cooldown_ratio: float = 0.0
var cooldown_left: float = 0.0
# Status-Felder: 1 = volle Dauer, 0 = gleich vorbei. -1 = keine Dauer.
var status_ratio: float = -1.0
var center_text: String = ""
var corner_text: String = ""
var is_status: bool = false
var is_ready: bool = true
var is_active: bool = false
var is_disabled: bool = false
var charges: int = 0
var charges_max: int = 0

func _init(slot_kind: String = "", slot_size: float = 46.0, status: bool = false) -> void:
	kind = slot_kind
	is_status = status
	custom_minimum_size = Vector2(slot_size, slot_size)
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_PASS

func set_tooltip_if_changed(text: String) -> void:
	if tooltip_text != text:
		tooltip_text = text

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var corner: float = maxf(3.0, size.x * 0.1)
	_draw_round_rect(rect, BG_COLOR, corner)
	# Leichter Farbschimmer im Hintergrund, damit man Felder auch ohne
	# genaues Hinsehen auseinanderhält.
	_draw_round_rect(rect.grow(-2.0), Color(accent.r, accent.g, accent.b, 0.10 if is_ready or is_status else 0.05), corner - 1.0)

	var dim: bool = is_disabled or (not is_status and not is_ready and not is_active)
	var icon_color: Color = accent
	if dim:
		icon_color = Color(accent.r * 0.55, accent.g * 0.55, accent.b * 0.55, 0.85)
	_draw_symbol(rect.get_center(), size.x * 0.30, icon_color)

	if not is_status and cooldown_ratio > 0.0 and not is_active:
		_draw_cooldown_fill(rect, cooldown_ratio)
	elif is_status and status_ratio >= 0.0:
		_draw_status_drain(rect, status_ratio)

	# Rahmen: bereit = Akzentfarbe, aktiv = hell pulsierend, sonst grau.
	var border: Color = BORDER_COLOR
	var width: float = 1.5
	if is_active:
		var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.012)
		border = Color(1.0, 1.0, 1.0, 0.65 + 0.35 * pulse)
		width = 2.5
	elif is_status:
		border = Color(accent.r, accent.g, accent.b, 0.75)
	elif is_ready and not is_disabled:
		border = Color(accent.r, accent.g, accent.b, 0.95)
		width = 2.0
	_draw_round_rect_outline(rect.grow(-width * 0.5), border, width, corner)

	var font: Font = get_theme_default_font()
	if font == null:
		return
	if key_text != "":
		var key_size: int = 11 if size.x >= 40.0 else 9
		_draw_text(font, Vector2(4.0, 3.0 + float(key_size)), key_text, key_size, Color(0.95, 0.97, 1.0, 0.95), HORIZONTAL_ALIGNMENT_LEFT, size.x - 6.0)
	if center_text != "":
		var big: int = 17 if size.x >= 40.0 else 12
		var y: float = size.y * 0.5 + float(big) * 0.36
		if is_status:
			# Restdauer bei Status-Feldern unten, das Symbol bleibt sichtbar.
			big = 11 if size.x >= 34.0 else 9
			y = size.y - 3.0
		_draw_text(font, Vector2(0.0, y), center_text, big, Color(1.0, 0.98, 0.86, 1.0), HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if corner_text != "":
		_draw_text(font, Vector2(0.0, size.y - 4.0), corner_text, 11, Color(1.0, 1.0, 1.0, 0.95), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 4.0)
	if charges_max > 1:
		for i in range(charges_max):
			var dot := Vector2(6.0 + float(i) * 6.0, size.y - 6.0)
			draw_circle(dot, 2.2, accent if i < charges else Color(0.18, 0.22, 0.28, 0.95))

# Abklingzeit wie in einer Zauberleiste: dunkle Abdeckung von oben, die mit
# der Zeit schrumpft. Die helle Kante zeigt den Füllstand.
func _draw_cooldown_fill(rect: Rect2, ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	var inner := rect.grow(-2.0)
	var cover_h: float = inner.size.y * r
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, cover_h)), COOLDOWN_COLOR, true)
	var edge_y: float = inner.position.y + cover_h
	draw_rect(Rect2(Vector2(inner.position.x, edge_y - 1.0), Vector2(inner.size.x, 2.0)), Color(accent.r, accent.g, accent.b, 0.95), true)
	# Bereits aufgeladener Teil leicht in der Akzentfarbe hinterlegt.
	draw_rect(Rect2(Vector2(inner.position.x, edge_y + 1.0), Vector2(inner.size.x, maxf(0.0, inner.end.y - edge_y - 1.0))), Color(accent.r, accent.g, accent.b, 0.12), true)

# Status mit Restdauer: der abgelaufene Teil wird von oben abgedunkelt.
func _draw_status_drain(rect: Rect2, ratio: float) -> void:
	var r: float = clampf(ratio, 0.0, 1.0)
	var inner := rect.grow(-2.0)
	var cover_h: float = inner.size.y * (1.0 - r)
	if cover_h <= 0.0:
		return
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, cover_h)), Color(0.0, 0.0, 0.02, 0.55), true)
	draw_rect(Rect2(Vector2(inner.position.x, inner.position.y + cover_h - 0.5), Vector2(inner.size.x, 1.0)), Color(accent.r, accent.g, accent.b, 0.85), true)

func _draw_text(font: Font, pos: Vector2, text: String, font_size: int, color: Color, align: HorizontalAlignment, width: float) -> void:
	draw_string_outline(font, pos, text, align, width, font_size, 3, TEXT_SHADOW)
	draw_string(font, pos, text, align, width, font_size, color)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)

func _draw_round_rect_outline(rect: Rect2, color: Color, width: float, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(ceilf(width)))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, rect)

# --- Symbole (Vektor, skaliert mit dem Feld) ---

func _draw_symbol(c: Vector2, s: float, color: Color) -> void:
	var fill := Color(color.r, color.g, color.b, 0.32)
	var w: float = maxf(1.5, s * 0.16)
	match kind:
		"ability":
			_poly(c, s, [Vector2(0, -1), Vector2(0.25, -0.25), Vector2(1, 0), Vector2(0.25, 0.25), Vector2(0, 1), Vector2(-0.25, 0.25), Vector2(-1, 0), Vector2(-0.25, -0.25)], color, fill, w)
		"dash":
			draw_polyline(_pts(c, s, [Vector2(-0.85, -0.7), Vector2(-0.1, 0), Vector2(-0.85, 0.7)]), color, w * 1.3, true)
			draw_polyline(_pts(c, s, [Vector2(0.05, -0.7), Vector2(0.8, 0), Vector2(0.05, 0.7)]), color, w * 1.3, true)
		"block", "invulnerability":
			_poly(c, s, [Vector2(-0.78, -0.7), Vector2(0, -1), Vector2(0.78, -0.7), Vector2(0.78, 0.2), Vector2(0, 1), Vector2(-0.78, 0.2)], color, fill, w)
		"ult":
			_poly(c, s, [Vector2(-0.95, 0.7), Vector2(-0.95, -0.55), Vector2(-0.45, 0), Vector2(0, -0.9), Vector2(0.45, 0), Vector2(0.95, -0.55), Vector2(0.95, 0.7)], color, fill, w)
		"shield":
			draw_circle(c, s * 0.82, fill)
			draw_arc(c, s * 0.82, 0.0, TAU, 32, color, w, true)
			draw_arc(c + Vector2(-0.22, -0.22) * s, s * 0.34, PI, PI * 1.5, 10, Color(1, 1, 1, 0.55), w * 0.8, true)
		"damage":
			# Schwert nach oben
			_poly(c, s, [Vector2(0, -1), Vector2(0.18, -0.75), Vector2(0.18, 0.35), Vector2(-0.18, 0.35), Vector2(-0.18, -0.75)], color, fill, w)
			draw_line(c + Vector2(-0.55, 0.4) * s, c + Vector2(0.55, 0.4) * s, color, w, true)
			draw_line(c + Vector2(0, 0.45) * s, c + Vector2(0, 0.95) * s, color, w * 1.2, true)
		"rapid_fire":
			for i in range(3):
				var x: float = -0.6 + 0.6 * float(i)
				_poly(c, s, [Vector2(x - 0.16, 0.8), Vector2(x - 0.16, -0.35), Vector2(x, -0.75), Vector2(x + 0.16, -0.35), Vector2(x + 0.16, 0.8)], color, fill, w * 0.8)
		"multishot":
			for a in [-0.55, 0.0, 0.55]:
				var dir := Vector2(sin(a), -cos(a))
				draw_line(c + Vector2(0, 0.8) * s, c + (Vector2(0, 0.8) + dir * 1.6) * s, color, w, true)
				draw_circle(c + (Vector2(0, 0.8) + dir * 1.6) * s, w * 1.1, color)
		"auto_attack":
			draw_arc(c, s * 0.75, -PI * 0.1, PI * 1.45, 24, color, w, true)
			var tip := c + Vector2(cos(-PI * 0.1), sin(-PI * 0.1)) * s * 0.75
			draw_line(tip, tip + Vector2(-0.4, -0.2) * s, color, w, true)
			draw_line(tip, tip + Vector2(0.05, 0.42) * s, color, w, true)
		"undying":
			# Ankh-artiges Kreuz
			draw_arc(c + Vector2(0, -0.5) * s, s * 0.32, 0.0, TAU, 20, color, w, true)
			draw_line(c + Vector2(0, -0.18) * s, c + Vector2(0, 1.0) * s, color, w * 1.2, true)
			draw_line(c + Vector2(-0.6, 0.1) * s, c + Vector2(0.6, 0.1) * s, color, w * 1.2, true)
		"revenge":
			var spikes := PackedVector2Array()
			for i in range(16):
				var ang: float = TAU * float(i) / 16.0 - PI * 0.5
				var rad: float = 1.0 if i % 2 == 0 else 0.45
				spikes.append(c + Vector2(cos(ang), sin(ang)) * rad * s)
			draw_colored_polygon(spikes, fill)
			spikes.append(spikes[0])
			draw_polyline(spikes, color, w * 0.8, true)
		"invisible":
			draw_arc(c, s * 0.8, PI * 0.15, PI * 0.85, 16, color, w, true)
			draw_arc(c, s * 0.8, PI * 1.15, PI * 1.85, 16, color, w, true)
			draw_circle(c, s * 0.25, color)
		"overcharge":
			_poly(c, s, [Vector2(0.2, -1), Vector2(-0.6, 0.15), Vector2(-0.05, 0.15), Vector2(-0.25, 1), Vector2(0.6, -0.2), Vector2(0.05, -0.2)], color, fill, w)
		"poison":
			_poly(c, s, [Vector2(0, -1), Vector2(0.55, -0.05), Vector2(0.6, 0.35), Vector2(0.3, 0.8), Vector2(0, 0.9), Vector2(-0.3, 0.8), Vector2(-0.6, 0.35), Vector2(-0.55, -0.05)], color, fill, w)
		"time_frozen":
			_poly(c, s, [Vector2(-0.7, -0.9), Vector2(0.7, -0.9), Vector2(0, 0), Vector2(0.7, 0.9), Vector2(-0.7, 0.9), Vector2(0, 0)], color, fill, w)
		_:
			draw_circle(c, s * 0.7, fill)
			draw_arc(c, s * 0.7, 0.0, TAU, 24, color, w, true)

func _pts(c: Vector2, s: float, unit: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in unit:
		out.append(c + (p as Vector2) * s)
	return out

func _poly(c: Vector2, s: float, unit: Array, color: Color, fill: Color, w: float) -> void:
	var points := _pts(c, s, unit)
	if Geometry2D.triangulate_polygon(points).size() > 0:
		draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, color, w, true)
