class_name PigModular
extends "res://scripts/pig_variant_base.gd"

## Baukasten-Schwein (Spielfigur, Lobby-Vorschau und Demo).
##
## Körperform, Augen, Schnauze, Nase, Ohren, Haare, Oberteil, Unterteil und
## Schwanz sind unabhängig wählbar. Die komplette Animation (Idle, Laufen,
## Springen, Fallen, Landen, Treffer, Staub, Blut, Outfits) kommt unverändert
## aus PigVariantBase/PigCharacter.
##
## Koordinatensystem beim Zeichnen (lokal, vor Zoom und Spiegelung):
##   x = 0 ist die Körpermitte, +x zeigt nach rechts.
##   y wächst nach unten. Kopfmitte ≈ −8, Bauchmitte ≈ +2, Hufunterkante ≈ +17.1.
##   1 Einheit = 1 Pixel bei Zoom 1; die Demo zeigt die Figur 7-fach vergrößert.
## Zeichenreihenfolge (hinten → vorne): Outfit hinten, Schwanz, Beine, Körper,
## Unterteil, Oberteil, Ohren, Kopf, Haare, Gesicht, Outfit vorne.

# Bausteine: jede ID wählt einen Zweig in der jeweiligen _draw_*-Funktion.
## Körperform, siehe _body_spec(): original, mascot, comic, boar, slim.
var body_style: String = "original"
## Augen: round, big, happy, sleepy, angry, button.
var eye_style: String = "round"
## Rüssel (die Nasenscheibe): round, wide, small, long, heart, chubby, boar.
var snout_style: String = "round"
## Nasenlöcher auf dem Rüssel: dots, wide, slits, button, none.
var nose_style: String = "dots"
## Ohren: floppy, round, pointy, tall, bat, small, none.
var ear_style: String = "floppy"
## Frisur: tuft, mane, mohawk, bangs, curl, none.
var hair_style: String = "tuft"
## Unterteil: shorts, pants, long_skirt, mini_skirt.
var bottom_style: String = "shorts"
## Oberteil: none, muscle, bikini, robe.
var top_style: String = "none"
## Schwanzform, siehe _tail_centerline(): curly, spiral, straight, droopy, bushy, short.
var tail_style: String = "curly"
## Seite des Schwanzes: −1 = links, +1 = rechts (vor der Spiegelung durch die Blickrichtung).
var tail_side: float = -1.0
var tail_visible: bool = true
## Stoff-Farbe des Oberteils.
var top_color: Color = Color(0.86, 0.32, 0.38, 1.0)
## Haarfarbe; Alpha 0 = automatisch aus dem Fell abgeleitet.
var hair_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var belt_visible: bool = true
## Höhe des Gürtels in Zeichenkoordinaten (Schnalle ist 0.7 größer).
var belt_width: float = 2.7
## Größenfaktor der Augen (1 = Standard der Körperform). Multipliziert BodySpec.eye_scale.
var eye_size: float = 1.0
## Größenfaktor des Rüssels samt Nasenlöchern und Mund. Multipliziert BodySpec.snout_scale.
var snout_size: float = 1.0
## Wie weit alle Unterteile unter der Körperform-Vorgabe (BodySpec.bottom_top)
## sitzen. Größer = tieferer Bund, mehr Bauch sichtbar.
var waist_offset: float = 1.0

## Proportionsdaten einer Körperform. Alle Maße sind lokale Zeichenkoordinaten;
## die Füße liegen bei y ≈ 17.1. Die Werte unten sind die Form "original".
class BodySpec extends RefCounted:
	## Mittelpunkt des Kopfes (y) und seine Halbachsen (Breite rx, Höhe ry).
	var head_y: float = -8.2
	var head_rx: float = 10.6
	var head_ry: float = 9.8
	## Mittelpunkt des Rumpfs (y) und seine Halbachsen.
	var body_y: float = 1.7
	var body_rx: float = 10.7
	var body_ry: float = 9.9
	## Umrissfarbe = Fell um diesen Anteil abgedunkelt (0 = gleich, 1 = schwarz).
	var line_darken: float = 0.42
	## Strichstärke der Hauptumrisse; Details nutzen Bruchteile davon.
	var line_width: float = 1.2
	## Halbachsen der Beinellipse.
	var leg_rx: float = 2.7
	var leg_ry: float = 4.1
	## Faktor auf den seitlichen Beinabstand aus der Animation (±5.4).
	var leg_x: float = 1.0
	## Halbachsen der Hufe.
	var hoof_rx: float = 2.7
	var hoof_ry: float = 1.7
	## Breite des Hosen-/Rockbunds.
	var bottom_width: float = 21.4
	## Oberkante des Bunds (y) vor waist_offset.
	var bottom_top: float = 4.3
	## Unterkante des Hüftteils der Hose (y), darunter beginnen die Hosenbeine.
	var bottom_bottom: float = 12.3
	## Größenfaktoren der Gesichtsteile für diese Körperform.
	var ear_scale: float = 1.0
	var eye_scale: float = 1.0
	var snout_scale: float = 1.0
	var tusk_scale: float = 1.0
	## Höhe des Halses für Klassen-Outfits (Schal o. ä.).
	var neck_y: float = -0.6

# --- Teile-Katalog ---
# Gemeinsame Liste für Lobby-Editor und Speichern/Netzwerk. Jeder Eintrag ist
# [id, Anzeigename]; der erste Eintrag ist der Standard.
const PART_OPTIONS: Dictionary = {
	"body": [
		["original", "Original – ausgewogen"], ["mascot", "Maskottchen – rund & knuffig"],
		["comic", "Comic – breit & grafisch"], ["boar", "Keiler – breit & wild"],
		["slim", "Schlank – schmal & groß"],
	],
	"eyes": [
		["round", "Rund – normal"], ["big", "Groß – süß"], ["happy", "Glücklich – knuffig"],
		["sleepy", "Schläfrig – entspannt"], ["angry", "Wild – mit Brauen"], ["button", "Knopf – comic"],
	],
	"snout": [
		["round", "Rund – normal"], ["wide", "Breit – keilig"], ["small", "Klein – süß"],
		["long", "Lang – schnüffelnd"], ["heart", "Herz – süß"], ["chubby", "Pausback – knuffig"],
		["boar", "Kantig – wild"],
	],
	"nose": [
		["dots", "Punkte – normal"], ["wide", "Breite Nüstern"], ["slits", "Schlitze – wild"],
		["button", "Knopf – knuffig"], ["none", "Ohne"],
	],
	"ears": [
		["floppy", "Schlapp – normal"], ["round", "Rund – süß"], ["pointy", "Spitz – frech"],
		["tall", "Lang – elegant"], ["bat", "Fledermaus – wild"], ["small", "Klein – keilig"],
		["none", "Ohne"],
	],
	"hair": [
		["tuft", "Büschel – normal"], ["mane", "Mähne – wild"], ["mohawk", "Irokese – punk"],
		["bangs", "Pony – süß"], ["curl", "Locke – elegant"], ["none", "Glatze"],
	],
	"bottom": [
		["shorts", "Kurze Hose"], ["pants", "Lange Hose"], ["long_skirt", "Langer Rock"],
		["mini_skirt", "Minirock"],
	],
	"top": [
		["none", "Ohne Oberteil"], ["muscle", "Muscle Shirt"], ["bikini", "Bikini Top"],
		["robe", "Kleid / Robe"],
	],
	"tail": [
		["curly", "Ringel – normal"], ["spiral", "Spirale – verspielt"], ["straight", "Keck nach oben"],
		["droopy", "Hängend – gemütlich"], ["bushy", "Quaste – wild"], ["short", "Stummel – knuffig"],
	],
}
## Regler-Grenzen für Größen und Gürtel (Lobby-Slider und Normalisierung).
const SIZE_MIN: float = 0.6
const SIZE_MAX: float = 1.5
const BELT_WIDTH_MIN: float = 1.0
const BELT_WIDTH_MAX: float = 4.5
const DEFAULT_TOP_COLOR: Color = Color(0.86, 0.32, 0.38, 1.0)

## Standard-Teile (entspricht dem klassischen Spielschwein).
static func default_parts() -> Dictionary:
	var parts := {}
	for key in PART_OPTIONS.keys():
		parts[key] = str(PART_OPTIONS[key][0][0])
	parts["tail_side"] = -1.0
	parts["tail_visible"] = true
	parts["belt"] = true
	parts["belt_width"] = 2.7
	parts["eye_size"] = 1.0
	parts["snout_size"] = 1.0
	parts["hair_color"] = Color(0.0, 0.0, 0.0, 0.0)
	parts["top_color"] = DEFAULT_TOP_COLOR
	return parts

## Prüft ein Teile-Dictionary (aus Datei, Netzwerk oder UI): unbekannte IDs
## fallen auf den Standard zurück, Zahlen werden begrenzt, Farben dürfen als
## Color oder als [r, g, b, a]-Array (JSON) kommen.
static func normalize_parts(raw: Dictionary) -> Dictionary:
	var parts := default_parts()
	for key in PART_OPTIONS.keys():
		var wanted := str(raw.get(key, parts[key]))
		for entry in PART_OPTIONS[key]:
			if str(entry[0]) == wanted:
				parts[key] = wanted
				break
	parts["tail_side"] = -1.0 if float(raw.get("tail_side", -1.0)) < 0.0 else 1.0
	parts["tail_visible"] = bool(raw.get("tail_visible", true))
	parts["belt"] = bool(raw.get("belt", true))
	parts["belt_width"] = clampf(float(raw.get("belt_width", 2.7)), BELT_WIDTH_MIN, BELT_WIDTH_MAX)
	parts["eye_size"] = clampf(float(raw.get("eye_size", 1.0)), SIZE_MIN, SIZE_MAX)
	parts["snout_size"] = clampf(float(raw.get("snout_size", 1.0)), SIZE_MIN, SIZE_MAX)
	parts["hair_color"] = _part_color(raw.get("hair_color"), parts["hair_color"])
	parts["top_color"] = _part_color(raw.get("top_color"), parts["top_color"])
	return parts

## Für JSON: Farben als [r, g, b, a]-Arrays.
static func parts_to_json(parts: Dictionary) -> Dictionary:
	var out := parts.duplicate()
	for key in ["hair_color", "top_color"]:
		var c: Color = parts.get(key, Color(0, 0, 0, 0))
		out[key] = [c.r, c.g, c.b, c.a]
	return out

static func _part_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return fallback

## Würfelt alle Teile neu; Farben (hair_color, top_color) bleiben aus `keep`.
static func random_parts(keep: Dictionary) -> Dictionary:
	var parts := normalize_parts(keep)
	for key in PART_OPTIONS.keys():
		var list: Array = PART_OPTIONS[key]
		parts[key] = str(list[randi() % list.size()][0])
	parts["tail_side"] = -1.0 if randf() < 0.5 else 1.0
	parts["tail_visible"] = randf() < 0.9
	parts["belt"] = randf() < 0.7
	parts["belt_width"] = snappedf(randf_range(BELT_WIDTH_MIN, BELT_WIDTH_MAX), 0.1)
	parts["eye_size"] = snappedf(randf_range(0.8, 1.25), 0.05)
	parts["snout_size"] = snappedf(randf_range(0.8, 1.25), 0.05)
	return parts

## Übernimmt ein (normalisiertes) Teile-Dictionary inklusive Farben.
func apply_parts(parts: Dictionary) -> void:
	var clean := normalize_parts(parts)
	apply_preset(clean)
	hair_color = clean["hair_color"]
	top_color = clean["top_color"]
	queue_redraw()

## Aktuelle Teile als Dictionary (Gegenstück zu apply_parts).
func get_parts() -> Dictionary:
	return normalize_parts({
		"body": body_style, "eyes": eye_style, "snout": snout_style, "nose": nose_style,
		"ears": ear_style, "hair": hair_style, "bottom": bottom_style, "top": top_style,
		"tail": tail_style, "tail_side": tail_side, "tail_visible": tail_visible,
		"belt": belt_visible, "belt_width": belt_width, "eye_size": eye_size,
		"snout_size": snout_size, "hair_color": hair_color, "top_color": top_color,
	})

func apply_preset(preset: Dictionary) -> void:
	body_style = str(preset.get("body", "original"))
	eye_style = str(preset.get("eyes", "round"))
	snout_style = str(preset.get("snout", "round"))
	nose_style = str(preset.get("nose", "dots"))
	ear_style = str(preset.get("ears", "floppy"))
	hair_style = str(preset.get("hair", "tuft"))
	bottom_style = str(preset.get("bottom", "shorts"))
	top_style = str(preset.get("top", "none"))
	tail_style = str(preset.get("tail", "curly"))
	tail_side = float(preset.get("tail_side", -1.0))
	tail_visible = bool(preset.get("tail_visible", true))
	belt_visible = bool(preset.get("belt", true))
	belt_width = float(preset.get("belt_width", 2.7))
	eye_size = float(preset.get("eye_size", 1.0))
	snout_size = float(preset.get("snout_size", 1.0))
	queue_redraw()

func _body_spec() -> BodySpec:
	var b := BodySpec.new()
	match body_style:
		"mascot":
			b.head_y = -9.4
			b.head_rx = 11.2
			b.head_ry = 10.4
			b.body_y = 2.4
			b.body_rx = 11.4
			b.body_ry = 10.4
			b.line_darken = 0.34
			b.line_width = 1.4
			b.leg_rx = 3.1
			b.leg_ry = 3.7
			b.hoof_rx = 3.1
			b.hoof_ry = 1.7
			b.bottom_width = 22.4
			b.bottom_top = 3.6
			b.bottom_bottom = 12.9
			b.eye_scale = 1.15
			b.snout_scale = 1.12
			b.tusk_scale = 0.95
			b.neck_y = -1.8
		"comic":
			b.head_y = -10.2
			b.head_rx = 11.4
			b.head_ry = 10.0
			b.body_y = 3.2
			b.body_rx = 11.8
			b.body_ry = 9.6
			b.line_darken = 0.62
			b.line_width = 2.0
			b.leg_rx = 3.2
			b.leg_ry = 3.5
			b.hoof_rx = 3.2
			b.hoof_ry = 1.8
			b.bottom_width = 23.4
			b.bottom_top = 5.6
			b.bottom_bottom = 12.7
			b.tusk_scale = 1.05
			b.neck_y = 0.8
		"boar":
			b.head_y = -8.8
			b.head_rx = 11.8
			b.head_ry = 9.6
			b.body_y = 2.0
			b.body_rx = 13.2
			b.body_ry = 10.2
			b.line_darken = 0.5
			b.line_width = 1.5
			b.leg_rx = 3.6
			b.leg_ry = 4.6
			b.hoof_rx = 3.6
			b.hoof_ry = 2.1
			b.bottom_width = 25.2
			b.bottom_top = 4.0
			b.bottom_bottom = 12.5
			b.ear_scale = 0.9
			b.eye_scale = 0.8
			b.snout_scale = 1.15
			b.tusk_scale = 1.15
			b.neck_y = -1.2
		"slim":
			b.head_y = -9.8
			b.head_rx = 9.8
			b.head_ry = 9.0
			b.body_y = 1.4
			b.body_rx = 8.8
			b.body_ry = 11.0
			b.line_darken = 0.48
			b.line_width = 0.9
			b.leg_rx = 2.4
			b.leg_ry = 4.0
			b.hoof_rx = 2.4
			b.hoof_ry = 1.4
			b.bottom_width = 17.8
			b.bottom_top = 3.4
			b.bottom_bottom = 12.0
			b.eye_scale = 0.9
			b.snout_scale = 0.85
			b.tusk_scale = 0.85
			b.neck_y = -1.0
	return b

func _draw_character(s) -> void:
	var b := _body_spec()
	# Spieler-Regler wirken auf die Gesichtsmaße der Körperform.
	b.eye_scale *= eye_size
	b.snout_scale *= snout_size
	var head_x: float = s.head_x
	var head_bob: float = s.head_bob
	var body_bob: float = s.body_bob
	var lean_x: float = s.lean_x
	var run: float = s.run
	var air: float = s.air
	var step: float = s.step

	var head := Vector2(head_x, b.head_y + head_bob)
	var body := Vector2(lean_x * 0.5, b.body_y + body_bob)
	var line := fur_color.darkened(b.line_darken)
	line.a = 1.0
	var fur := fur_color
	var fur_dark: Color = s.fur_dark
	var snout: Color = s.snout_color
	var snout_line: Color = s.snout_outline
	var hoof: Color = s.hoof_color
	var belt: Color = s.belt_color
	var buckle: Color = s.buckle_color
	var tusk: Color = s.tusk_color

	var outfit_head := head
	var outfit_neck := Vector2((head_x + lean_x * 0.55) * 0.5, b.neck_y + (head_bob + body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(run, air))

	_draw_tail(s, b, body, line, fur_dark)

	# Beine und Hufe liegen hinter dem Körper.
	_draw_leg(s, b, s.left_leg_x, s.left_leg_y, line, fur_dark, hoof)
	_draw_leg(s, b, s.right_leg_x, s.right_leg_y, line, fur_dark, hoof)

	# Körper.
	_draw_ellipse(body, b.body_rx, b.body_ry, fur, line, b.line_width)

	# Unterteil (Hose, kurze Hose, Rock, Minirock).
	_draw_bottom(s, b, line, belt, buckle)

	# Oberteil liegt über dem Unterteil, aber hinter dem Kopf: Ausschnitt,
	# Träger und Schultern verschwinden so natürlich unter dem Kinn.
	_draw_top(s, b, head, line, belt, buckle)

	# Ohren liegen hinter dem Kopf.
	_draw_ears(b, head, line, fur_dark, snout)

	# Kopf.
	_draw_ellipse(head, b.head_rx, b.head_ry, fur, line, b.line_width)

	# Haare liegen auf dem Kopf.
	var hair := hair_color if hair_color.a > 0.0 else fur_dark
	_draw_hair(b, head, line, hair)

	# Gesicht.
	_draw_face(s, b, head, line, snout, snout_line, tusk)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

func _draw_leg(
	_s,
	b: BodySpec,
	leg_x: float,
	leg_y: float,
	line: Color,
	fur_dark: Color,
	hoof: Color
) -> void:
	var lx := leg_x * b.leg_x
	_draw_ellipse(Vector2(lx, leg_y), b.leg_rx, b.leg_ry, fur_dark, line, b.line_width * 0.6)
	var hoof_y := leg_y + 4.9 - b.hoof_ry
	_draw_ellipse(Vector2(lx, hoof_y), b.hoof_rx, b.hoof_ry, hoof, line, b.line_width * 0.55)

# --- Schwanz ---

## Anzahl Stützpunkte der Schwanz-Mittellinie. Viele kurze Segmente ergeben
## eine glatte, gleichmäßig dünner werdende Form ohne Perlenkette.
const TAIL_SAMPLES: int = 40
## Gesamtgröße aller Schwanzformen.
const TAIL_SCALE: float = 1.35

func _draw_tail(s, b: BodySpec, body: Vector2, line: Color, fur_dark: Color) -> void:
	if not tail_visible or tail_style == "none":
		return
	var side := -1.0 if tail_side < 0.0 else 1.0
	# Der Ansatz liegt etwas im Körper, damit kein Spalt zum Rumpf entsteht.
	var root := Vector2(side * (b.body_rx * 0.86 - 1.0), body.y + b.body_ry * 0.12)
	# Wedeln: im Stand ruhig, beim Laufen im Schrittakt, in der Luft angehoben.
	var wag: float = sin(_time * 2.6) * 0.10 * s.idle + sin(_run_phase * 2.0 + 0.8) * 0.28 * s.run
	wag -= s.air * 0.18
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	for i in TAIL_SAMPLES:
		var t := float(i) / float(TAIL_SAMPLES - 1)
		var local := _tail_centerline(tail_style, t) * TAIL_SCALE
		# Die Biegung wächst zur Spitze hin, der Ansatz bleibt am Körper.
		local = local.rotated(-wag * t)
		points.append(root + Vector2(local.x * side, local.y))
		widths.append(_tail_width(tail_style, t) * TAIL_SCALE)
	_draw_tube(points, widths, line, fur_dark, 0.4)

## Mittellinie des Schwanzes für t = 0 (Ansatz) bis 1 (Spitze). +x zeigt vom
## Körper weg, −y nach oben.
func _tail_centerline(style: String, t: float) -> Vector2:
	match style:
		"spiral":
			# Enge Spirale mit fast zwei Windungen.
			return _tail_curl(t, Vector2(4.0, -0.6), 2.6, 0.7, 1.8)
		"straight":
			# Keck nach oben, leicht gebogen.
			return Vector2(5.4 * t, -1.2 * t - 3.2 * t * t)
		"droopy":
			# Erst waagerecht, dann hängend.
			return Vector2(4.6 * t - 0.6 * t * t * t, 0.4 * t + 4.4 * t * t)
		"bushy":
			# Langer Schwanz mit S-Schwung und Quaste an der Spitze.
			return Vector2(6.4 * t, -0.6 * t - 2.6 * t * t + sin(t * PI * 1.4) * 0.9)
		"short":
			# Kurzer, frecher Stummel mit kleinem Häkchen.
			return Vector2(3.8 * t, -0.4 * t - 2.0 * t * t * t)
		_:
			# Ringel: etwas mehr als eine Windung, Radius nimmt nach innen ab.
			return _tail_curl(t, Vector2(3.8, -0.4), 2.3, 1.0, 1.25)

## Locke: kurzer gerader Ansatz aus dem Körper, dann eine Spirale um
## `center`, deren Radius von `r_start` auf `r_end` schrumpft.
func _tail_curl(t: float, center: Vector2, r_start: float, r_end: float, turns: float) -> Vector2:
	var lead := 0.15
	var start := center + Vector2(-r_start, 0.0)
	if t < lead:
		return start * (t / lead)
	var u := (t - lead) / (1.0 - lead)
	var a := PI + u * TAU * turns
	return center + Vector2(cos(a), sin(a)) * lerpf(r_start, r_end, u)

## Breite des Schwanzes an Stelle t. Jede Form läuft in genau einer Spitze aus.
func _tail_width(style: String, t: float) -> float:
	match style:
		"spiral":
			return lerpf(1.2, 0.1, pow(t, 0.8))
		"bushy":
			# Dünner Schwanz, der zur Quaste aufgeht und spitz endet.
			var tuft := sin(clampf((t - 0.55) / 0.45, 0.0, 1.0) * PI)
			return lerpf(1.3, 0.5, t) * (1.0 - t * t * t) + tuft * 2.0
		"short":
			return lerpf(1.9, 0.25, pow(t, 1.4))
		_:
			return lerpf(1.4, 0.12, pow(t, 0.85))

## Zeichnet eine Röhre mit variabler Breite entlang dichter Stützpunkte: erst
## alles in Umrissfarbe mit Zuschlag, dann die Füllung darüber. So entstehen
## keine Triangulationsfehler bei engen Locken und keine Nähte zwischen
## den Segmenten.
func _draw_tube(
	points: PackedVector2Array,
	widths: PackedFloat32Array,
	outline: Color,
	fill: Color,
	outline_width: float
) -> void:
	if points.size() < 2:
		return
	for pass_index in 2:
		var extra := outline_width * 2.0 if pass_index == 0 else 0.0
		var color := outline if pass_index == 0 else fill
		for i in points.size() - 1:
			var w := (widths[i] + widths[i + 1]) * 0.5 + extra
			draw_line(points[i], points[i + 1], color, maxf(0.05, w))
		for i in points.size():
			var r := widths[i] * 0.5 + extra * 0.5
			if r > 0.05:
				draw_circle(points[i], r, color)

## Glättet einen groben Linienzug (Catmull-Rom) und zeichnet ihn als zur
## Spitze dünner werdende Röhre. Wird von der Locken-Frisur genutzt.
func _draw_tapered_tube(points: PackedVector2Array, width: float, outline: Color, fill: Color) -> void:
	if points.size() < 2:
		return
	var smooth := PackedVector2Array()
	var subdivisions := 6
	for i in points.size() - 1:
		var p0 := points[maxi(0, i - 1)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(points.size() - 1, i + 2)]
		for j in subdivisions:
			var u := float(j) / float(subdivisions)
			var u2 := u * u
			var u3 := u2 * u
			smooth.append(0.5 * (
				2.0 * p1
				+ (p2 - p0) * u
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3
			))
	smooth.append(points[points.size() - 1])
	var widths := PackedFloat32Array()
	for i in smooth.size():
		var t := float(i) / float(smooth.size() - 1)
		widths.append(lerpf(width, 0.15, t))
	_draw_tube(smooth, widths, outline, fill, 0.5)

# --- Unterteil ---

## Wie weit der Bund unter BodySpec.bottom_top liegt: waist_offset für alle
## Unterteile, beim Bikini zusätzlich BIKINI_WAIST_EXTRA, damit zwischen
## Körbchen und Gürtel Bauch frei bleibt.
const BIKINI_WAIST_EXTRA: float = 1.5

func _waist_drop() -> float:
	return waist_offset + (BIKINI_WAIST_EXTRA if top_style == "bikini" else 0.0)

## Unterster Punkt des Bauchs (y) – Säume müssen tiefer liegen, sonst
## schaut der Bauch unter Rock oder Hose hervor.
func _belly_bottom(s, b: BodySpec) -> float:
	return b.body_y + b.body_ry + s.body_bob

func _draw_bottom(s, b: BodySpec, line: Color, belt: Color, buckle: Color) -> void:
	match bottom_style:
		"pants":
			_draw_long_pants(s, b, line, belt, buckle)
		"long_skirt":
			# Saum knapp über den Hufen (Knöchel), 35 % ausgestellt.
			_draw_skirt(s, b, line, belt, buckle, 16.0, 1.35)
		"mini_skirt":
			# Saum knapp unter dem Bauch, 24 % ausgestellt.
			_draw_skirt(s, b, line, belt, buckle, _belly_bottom(s, b) + 1.2, 1.24)
		_:
			_draw_long_pants(s, b, line, belt, buckle, true)

func _draw_belt(
	x_off: float,
	half: float,
	top_y: float,
	line: Color,
	belt: Color,
	buckle: Color,
	line_width: float
) -> void:
	if not belt_visible:
		return
	var belt_rect := Rect2(-half + x_off, top_y - 0.3, half * 2.0, belt_width)
	draw_rect(belt_rect, belt, true)
	draw_rect(belt_rect, line, false, line_width)
	# Die Schnalle wächst mit dem Gürtel, bleibt aber etwas höher als er.
	var buckle_size := belt_width + 0.7
	var buckle_rect := Rect2(x_off - buckle_size * 0.5, top_y - 0.65, buckle_size, buckle_size)
	draw_rect(buckle_rect, buckle, true)
	draw_rect(buckle_rect, line, false, line_width * 0.7)

## Lange Hose; mit `short` endet das Hosenbein knapp unter der Hüfte und
## gibt die Unterschenkel frei (kurze Hose).
func _draw_long_pants(s, b: BodySpec, line: Color, belt: Color, buckle: Color, short: bool = false) -> void:
	var x_off: float = s.lean_x * 0.5
	var half := b.bottom_width * 0.5
	var top_y: float = b.bottom_top + _waist_drop() + s.body_bob
	var hip_y: float = b.bottom_bottom + _waist_drop() * 0.7 + s.body_bob
	if short:
		# Kurze Hose: Hüftteil endet knapp unter dem Bauch, die kurzen
		# Hosenbeine (siehe _draw_pant_leg) lassen die Unterschenkel frei.
		# Bei tiefem Bund (Bikini) bleibt unter dem Gürtel mindestens 2.5 Stoff.
		hip_y = maxf(_belly_bottom(s, b) + 0.2, top_y + belt_width + 2.5)
	var hip_rect := Rect2(-half + x_off, top_y, half * 2.0, hip_y - top_y)
	if short:
		# Kurze Hose: seitlich endet sie höher (dort ist der Bauch schon rund
		# zu Ende), in der Mitte reicht sie mit einem Bogen bis unter den
		# Bauch. Die Hosenbeine sitzen hinter dem Hüftteil an der Seitenkante.
		var side_y := hip_y - 1.6
		_draw_pant_leg(s.left_leg_x, s.left_leg_y, b, x_off, side_y, line, true)
		_draw_pant_leg(s.right_leg_x, s.right_leg_y, b, x_off, side_y, line, true)
		var hip := PackedVector2Array([
			Vector2(-half + x_off, top_y),
			Vector2(half + x_off, top_y),
			Vector2(half + x_off, side_y),
		])
		_bezier(hip, hip[2], Vector2(x_off, hip_y + 1.6), Vector2(-half + x_off, side_y), 12)
		draw_colored_polygon(hip, pants_color)
		hip.append(hip[0])
		draw_polyline(hip, line, b.line_width, LINE_AA)
	else:
		draw_rect(hip_rect, pants_color, true)
		draw_rect(hip_rect, line, false, b.line_width)
	if not short:
		_draw_pant_leg(s.left_leg_x, s.left_leg_y, b, x_off, hip_y, line)
		_draw_pant_leg(s.right_leg_x, s.right_leg_y, b, x_off, hip_y, line)
	_draw_belt(x_off, half, top_y, line, belt, buckle, b.line_width)
	draw_line(
		Vector2(x_off, top_y + (belt_width if belt_visible else 0.0) - 0.5),
		Vector2(x_off, hip_y - 0.6),
		line,
		b.line_width * 0.7,
		LINE_AA
	)

func _draw_pant_leg(
	leg_x: float,
	leg_y: float,
	b: BodySpec,
	x_off: float,
	hip_y: float,
	line: Color,
	short: bool = false
) -> void:
	var lx := leg_x * b.leg_x + x_off
	var half := b.leg_rx * 1.2
	var top := hip_y - 0.8
	var bottom := leg_y + b.leg_ry * 0.82
	if short:
		# Kurzes Hosenbein: endet 1.4 unter seinem Ansatz.
		bottom = minf(bottom, hip_y + 1.4)
	var leg_rect := Rect2(lx - half, top, half * 2.0, maxf(2.0, bottom - top))
	draw_rect(leg_rect, pants_color, true)
	draw_rect(leg_rect, line, false, b.line_width)
	if short:
		return
	var cuff := Rect2(lx - half, bottom - 1.1, half * 2.0, 1.1)
	draw_rect(cuff, line, true)

func _draw_skirt(
	s,
	b: BodySpec,
	line: Color,
	belt: Color,
	buckle: Color,
	hem_y: float,
	flare: float
) -> void:
	var x_off: float = s.lean_x * 0.5
	var top_y: float = b.bottom_top + _waist_drop() + s.body_bob
	var half := b.bottom_width * 0.5
	var hem_half := half * flare
	var poly := PackedVector2Array([
		Vector2(-half + x_off, top_y),
		Vector2(half + x_off, top_y),
		Vector2(hem_half + x_off, hem_y),
		Vector2(x_off, hem_y + 0.8),
		Vector2(-hem_half + x_off, hem_y),
	])
	draw_colored_polygon(poly, pants_color)
	poly.append(poly[0])
	draw_polyline(poly, line, b.line_width, LINE_AA)
	_draw_belt(x_off, half, top_y, line, belt, buckle, b.line_width)
	if not belt_visible:
		top_y -= 1.5
	for f: float in [-0.45, 0.45]:
		draw_line(
			Vector2(x_off + half * f, top_y + 2.0),
			Vector2(x_off + hem_half * f, hem_y - 0.5),
			line,
			b.line_width * 0.65,
			LINE_AA
		)

# --- Oberteil ---

## Oberteile werden vor dem Kopf gezeichnet. Alles oberhalb des Kinns
## (Ausschnitt, Träger) liegt damit verdeckt hinter dem Kopf.
func _draw_top(s, b: BodySpec, head: Vector2, line: Color, belt: Color, buckle: Color) -> void:
	match top_style:
		"muscle":
			_draw_muscle_shirt(s, b, head, line)
		"bikini":
			_draw_bikini_top(s, b, head, line)
		"robe":
			_draw_robe(s, b, head, line, belt, buckle)

## Halbe Körperbreite auf Höhe y (Körper-Ellipse), damit Kleidung innerhalb
## des Umrisses bleibt.
func _body_half_width(b: BodySpec, body_y: float, y: float) -> float:
	var d := (y - body_y) / b.body_ry
	return b.body_rx * sqrt(maxf(0.0, 1.0 - d * d))

## Quadratische Bézierkurve von a nach c mit Kontrollpunkt b (ohne Startpunkt).
func _bezier(points: PackedVector2Array, a: Vector2, ctrl: Vector2, c: Vector2, steps: int) -> void:
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		points.append(a.lerp(ctrl, t).lerp(ctrl.lerp(c, t), t))

func _draw_muscle_shirt(s, b: BodySpec, head: Vector2, line: Color) -> void:
	var x_off: float = s.lean_x * 0.5
	var body_y: float = b.body_y + s.body_bob
	var k := b.body_rx / 10.7
	# Oberkante liegt unter dem Kopf, sichtbar sind Schultern und Armlöcher.
	var top_y := head.y + b.head_ry - 3.4
	# Das Shirt hängt locker über den Hosenbund.
	var waist_y: float = b.bottom_top + s.body_bob + 2.4
	var arm_y := head.y + b.head_ry + 1.8
	var strap_in := 2.3 * k
	var strap_out := 4.4 * k
	var arm_x := _body_half_width(b, body_y, arm_y) * 0.93
	var waist_x := _body_half_width(b, body_y, waist_y) * 0.95
	var poly := PackedVector2Array()
	poly.append(Vector2(x_off - strap_out, top_y))
	poly.append(Vector2(x_off - strap_in, top_y))
	_bezier(poly, Vector2(x_off - strap_in, top_y), Vector2(x_off, top_y + 4.0), Vector2(x_off + strap_in, top_y), 6)
	poly.append(Vector2(x_off + strap_out, top_y))
	# Tiefes Armloch rechts.
	_bezier(poly, Vector2(x_off + strap_out, top_y), Vector2(x_off + strap_out + 0.6, arm_y), Vector2(x_off + arm_x, arm_y), 6)
	poly.append(Vector2(x_off + waist_x, waist_y))
	_bezier(poly, Vector2(x_off + waist_x, waist_y), Vector2(x_off, waist_y + 0.9), Vector2(x_off - waist_x, waist_y), 6)
	poly.append(Vector2(x_off - arm_x, arm_y))
	_bezier(poly, Vector2(x_off - arm_x, arm_y), Vector2(x_off - strap_out - 0.6, arm_y), Vector2(x_off - strap_out, top_y), 6)
	poly.remove_at(poly.size() - 1)
	draw_colored_polygon(poly, top_color)
	poly.append(poly[0])
	draw_polyline(poly, line, b.line_width, LINE_AA)
	# Saum und leichter Glanz auf der Brust.
	draw_line(
		Vector2(x_off - waist_x * 0.92, waist_y - 1.0),
		Vector2(x_off + waist_x * 0.92, waist_y - 1.0),
		top_color.darkened(0.25),
		b.line_width * 0.5,
		LINE_AA
	)
	draw_line(
		Vector2(x_off - arm_x * 0.55, arm_y + 0.6),
		Vector2(x_off - arm_x * 0.35, arm_y + 2.0),
		top_color.lightened(0.35),
		b.line_width * 0.6,
		LINE_AA
	)

func _draw_bikini_top(s, b: BodySpec, head: Vector2, line: Color) -> void:
	var x_off: float = s.lean_x * 0.5
	var body_y: float = b.body_y + s.body_bob
	var k := b.body_rx / 10.7
	# Unterkante der Körbchen hängt am Körper, nicht am Bund: Ein tieferer
	# Bund (waist_offset) vergrößert also den freien Bauch darunter.
	var cup_bottom: float = b.bottom_top + s.body_bob - 0.4
	var cup_w := 2.7 * k
	# Die Körbchen sitzen seitlich unter den Backen: Dort ist zwischen Kopf
	# und Bund am meisten Brust sichtbar.
	var spread := 5.5 * k
	var string_color := top_color.darkened(0.3)
	var string_w := maxf(0.45, b.line_width * 0.45)
	var ring := Vector2(x_off, cup_bottom - 1.1)

	# Rückenband: läuft vom einen Körperrand zum anderen hinter den Körbchen.
	var band_y := cup_bottom - 0.9
	var band_x := _body_half_width(b, body_y, band_y) * 0.97
	var band := PackedVector2Array([Vector2(x_off - band_x, band_y - 0.4)])
	_bezier(band, band[0], Vector2(x_off, band_y + 0.6), Vector2(x_off + band_x, band_y - 0.4), 10)
	draw_polyline(band, line, string_w + 0.5, LINE_AA)
	draw_polyline(band, string_color, string_w, LINE_AA)

	for side: float in [-1.0, 1.0]:
		var cx := x_off + side * spread
		var chin := _head_bottom(b, head, cx)
		var cup_top := clampf(chin + 0.1, cup_bottom - 4.0, cup_bottom - 1.6)
		var h := cup_bottom - cup_top
		var apex := Vector2(cx - side * 0.3, cup_top)
		var outer := Vector2(cx + side * cup_w, cup_bottom - 0.5)
		var inner := Vector2(cx - side * cup_w, cup_bottom - 0.3)
		# Neckholder-Band zum Nacken (endet hinter dem Kopf).
		var neck := Vector2(x_off + side * 2.0, head.y + b.head_ry - 4.0)
		draw_line(apex, neck, line, string_w + 0.5, LINE_AA)
		draw_line(apex, neck, string_color, string_w, LINE_AA)
		# Steg von der Körbcheninnenseite zum Mittelring.
		var inner_top := inner.lerp(apex, 0.45)
		draw_line(inner_top, ring, line, string_w + 0.5, LINE_AA)
		draw_line(inner_top, ring, string_color, string_w, LINE_AA)
		# Körbchen: gewölbtes Dreieck mit runder Unterkante.
		var cup := PackedVector2Array([apex])
		_bezier(cup, apex, Vector2(cx + side * cup_w * 0.95, cup_top + h * 0.35), outer, 6)
		_bezier(cup, outer, Vector2(cx, cup_bottom + 1.0), inner, 8)
		_bezier(cup, inner, Vector2(cx - side * cup_w * 0.75, cup_top + h * 0.45), apex, 6)
		cup.remove_at(cup.size() - 1)
		draw_colored_polygon(cup, top_color)
		cup.append(cup[0])
		draw_polyline(cup, line, b.line_width * 0.75, LINE_AA)
		# Glanzlicht.
		var shine := PackedVector2Array([Vector2(cx + side * cup_w * 0.1, cup_top + h * 0.35)])
		_bezier(shine, shine[0], Vector2(cx + side * cup_w * 0.6, cup_bottom - h * 0.3), Vector2(cx + side * cup_w * 0.3, cup_bottom - 0.3), 5)
		draw_polyline(shine, top_color.lightened(0.45), b.line_width * 0.45, LINE_AA)

	# Kleiner goldener Ring zwischen den Körbchen.
	draw_circle(ring, 0.7 * k + 0.3, line)
	draw_circle(ring, 0.7 * k, Color(1.0, 0.82, 0.35, 1.0))

## Unterkante der Kopf-Ellipse an Position x.
func _head_bottom(b: BodySpec, head: Vector2, x: float) -> float:
	var d := (x - head.x) / b.head_rx
	return head.y + b.head_ry * sqrt(maxf(0.0, 1.0 - d * d))

func _draw_robe(s, b: BodySpec, head: Vector2, line: Color, belt: Color, _buckle: Color) -> void:
	var neck_y := head.y + b.head_ry - 1.0
	var hem_y := 16.0
	var x_off: float = s.lean_x * 0.5
	var shoulder_half := b.body_rx * 0.9
	var waist_half := b.body_rx * 0.85
	var hem_half := b.body_rx * 1.35
	var poly := PackedVector2Array([
		Vector2(-shoulder_half + x_off, neck_y),
		Vector2(-shoulder_half * 0.35 + x_off, neck_y),
		Vector2(x_off, neck_y + 2.2),
		Vector2(shoulder_half * 0.35 + x_off, neck_y),
		Vector2(shoulder_half + x_off, neck_y),
		Vector2(hem_half + x_off, hem_y),
		Vector2(x_off, hem_y + 0.8),
		Vector2(-hem_half + x_off, hem_y),
	])
	draw_colored_polygon(poly, top_color)
	poly.append(poly[0])
	draw_polyline(poly, line, b.line_width, LINE_AA)
	var belt_y: float = b.bottom_top + s.body_bob - 0.3
	var fold_y := belt_y
	if belt_visible:
		var belt_rect := Rect2(-waist_half + x_off, belt_y, waist_half * 2.0, belt_width * 0.85)
		draw_rect(belt_rect, belt, true)
		draw_rect(belt_rect, line, false, b.line_width)
		fold_y += belt_width * 0.85
	for f: float in [-0.5, 0.0, 0.5]:
		draw_line(
			Vector2(x_off + waist_half * f * 0.8, fold_y),
			Vector2(x_off + hem_half * f, hem_y - 0.5),
			line,
			b.line_width * 0.55,
			LINE_AA
		)

# --- Ohren ---

func _draw_ears(b: BodySpec, head: Vector2, line: Color, fur_dark: Color, snout: Color) -> void:
	if ear_style == "none":
		return
	for side: float in [-1.0, 1.0]:
		var base := head + Vector2(b.head_rx * 0.72 * side, -b.head_ry * 0.58)
		if ear_style == "round":
			var center := base + Vector2(2.2 * side, -0.6) * b.ear_scale
			_draw_ellipse(center, 3.6 * b.ear_scale, 4.0 * b.ear_scale, fur_dark, line, b.line_width * 0.8)
			_draw_ellipse(
				center,
				2.2 * b.ear_scale,
				2.6 * b.ear_scale,
				snout,
				Color(0.0, 0.0, 0.0, 0.0),
				0.0
			)
			continue
		var outer := _ear_points(ear_style, base, side, b.ear_scale)
		if outer.is_empty():
			continue
		draw_colored_polygon(outer, fur_dark)
		outer.append(outer[0])
		draw_polyline(outer, line, b.line_width * 0.8, LINE_AA)
		var inner := _ear_inner_points(ear_style, base, side, b.ear_scale)
		if inner.size() >= 3:
			draw_colored_polygon(inner, snout)

func _ear_points(style: String, base: Vector2, side: float, scale: float) -> PackedVector2Array:
	match style:
		"pointy":
			return PackedVector2Array([
				base + Vector2(-2.8 * side, 2.0) * scale,
				base + Vector2(3.8 * side, -6.6) * scale,
				base + Vector2(5.8 * side, 0.4) * scale,
			])
		"tall":
			return PackedVector2Array([
				base + Vector2(-1.8 * side, 1.6) * scale,
				base + Vector2(2.8 * side, -8.2) * scale,
				base + Vector2(4.6 * side, 0.5) * scale,
			])
		"bat":
			return PackedVector2Array([
				base + Vector2(-2.2 * side, 1.8) * scale,
				base + Vector2(7.2 * side, -2.2) * scale,
				base + Vector2(4.0 * side, 3.2) * scale,
			])
		"small":
			return PackedVector2Array([
				base + Vector2(-1.6 * side, 1.2) * scale,
				base + Vector2(2.2 * side, -3.4) * scale,
				base + Vector2(3.4 * side, 0.4) * scale,
			])
		_:
			return PackedVector2Array([
				base + Vector2(-2.6 * side, 1.4) * scale,
				base + Vector2(3.2 * side, -5.0) * scale,
				base + Vector2(5.4 * side, 0.6) * scale,
				base + Vector2(2.0 * side, 2.4) * scale,
			])

func _ear_inner_points(style: String, base: Vector2, side: float, scale: float) -> PackedVector2Array:
	match style:
		"pointy":
			return PackedVector2Array([
				base + Vector2(-1.4 * side, 1.3) * scale,
				base + Vector2(2.6 * side, -4.4) * scale,
				base + Vector2(3.9 * side, 0.3) * scale,
			])
		"tall":
			return PackedVector2Array([
				base + Vector2(-0.9 * side, 1.1) * scale,
				base + Vector2(2.4 * side, -5.8) * scale,
				base + Vector2(3.4 * side, 0.3) * scale,
			])
		"bat":
			return PackedVector2Array([
				base + Vector2(-0.9 * side, 1.2) * scale,
				base + Vector2(4.6 * side, -1.4) * scale,
				base + Vector2(2.6 * side, 2.0) * scale,
			])
		"small":
			return PackedVector2Array([
				base + Vector2(-0.8 * side, 0.9) * scale,
				base + Vector2(1.5 * side, -2.2) * scale,
				base + Vector2(2.3 * side, 0.3) * scale,
			])
		_:
			return PackedVector2Array([
				base + Vector2(-1.2 * side, 1.0) * scale,
				base + Vector2(2.4 * side, -3.2) * scale,
				base + Vector2(3.6 * side, 0.2) * scale,
				base + Vector2(1.6 * side, 1.3) * scale,
			])

# --- Haare ---

func _draw_hair(b: BodySpec, head: Vector2, line: Color, fur_dark: Color) -> void:
	var mane := fur_dark.darkened(0.16)
	match hair_style:
		"mane":
			for i in range(9):
				var angle := lerpf(-2.85, -0.25, float(i) / 8.0)
				var reach := 1.35 if i % 2 == 0 else 1.6
				var base := head + Vector2(
					cos(angle) * b.head_rx * 0.95,
					sin(angle) * b.head_ry * 0.95
				)
				var tip := head + Vector2(
					cos(angle) * b.head_rx * reach,
					sin(angle) * b.head_ry * reach
				)
				var tangent := Vector2(
					-sin(angle) * b.head_rx * 0.95,
					cos(angle) * b.head_ry * 0.95
				).normalized() * 1.5
				var spike := PackedVector2Array([base - tangent, tip, base + tangent])
				draw_colored_polygon(spike, mane)
				spike.append(spike[0])
				draw_polyline(spike, line, 0.8, LINE_AA)
		"mohawk":
			for i in range(5):
				var x := lerpf(-0.42, 0.42, float(i) / 4.0) * b.head_rx
				var height := (0.36 if i % 2 == 0 else 0.52) * b.head_ry
				var base := head + Vector2(x, -b.head_ry * 0.84)
				var tip := head + Vector2(x + 0.5, -b.head_ry - height)
				var spike := PackedVector2Array([
					base + Vector2(-1.1, 0.4),
					tip,
					base + Vector2(1.1, 0.4),
				])
				draw_colored_polygon(spike, fur_dark)
				spike.append(spike[0])
				draw_polyline(spike, line, 0.8, LINE_AA)
		"bangs":
			_draw_bangs(b, head, line, fur_dark)
		"curl":
			var curl := PackedVector2Array([
				head + Vector2(-1.2, -b.head_ry * 0.92),
				head + Vector2(0.2, -b.head_ry * 1.10),
				head + Vector2(1.8, -b.head_ry * 1.00),
				head + Vector2(2.6, -b.head_ry * 0.86),
				head + Vector2(2.0, -b.head_ry * 0.78),
				head + Vector2(1.4, -b.head_ry * 0.84),
			])
			_draw_tapered_tube(curl, 2.0, line, fur_dark)
		"none":
			pass
		_:
			draw_colored_polygon(PackedVector2Array([
				head + Vector2(-2.6, -0.82 * b.head_ry),
				head + Vector2(-1.2, -1.12 * b.head_ry),
				head + Vector2(0.2, -0.94 * b.head_ry),
				head + Vector2(1.6, -1.18 * b.head_ry),
				head + Vector2(2.8, -0.80 * b.head_ry),
			]), fur_dark)

## Pony: Haarkappe über dem Oberkopf mit fünf runden Strähnen, die in die
## Stirn fallen.
##   CAP_REACH    – Radius der Kappe relativ zum Kopf (>1 = steht etwas über)
##   CAP_FROM/TO  – Winkelbereich der Kappe (Grad, 270 = oben), bestimmt wie
##                  weit sie seitlich herunterreicht
##   ROOT_Y       – Höhe, an der die Strähnen ansetzen (Anteil von head_ry über der Mitte)
##   TIP_Y        – Höhe der Strähnenspitzen (kleiner = tiefer in die Stirn)
##   STRANDS      – Anzahl der Strähnen
func _draw_bangs(b: BodySpec, head: Vector2, line: Color, hair: Color) -> void:
	const CAP_REACH := 1.05
	const CAP_FROM := 196.0
	const CAP_TO := 344.0
	const ROOT_Y := 0.66
	const TIP_Y := 0.46
	const STRANDS := 5
	var poly := PackedVector2Array()
	# Außenkante: Bogen über den Oberkopf von links nach rechts.
	for i in 17:
		var a := deg_to_rad(lerpf(CAP_FROM, CAP_TO, float(i) / 16.0))
		poly.append(head + Vector2(cos(a) * b.head_rx * CAP_REACH, sin(a) * b.head_ry * CAP_REACH))
	# Innenkante: von rechts nach links Strähne für Strähne, jede mit runder
	# Spitze. Die äußeren Strähnen sind kürzer und folgen der Kopfrundung.
	var right_end := poly[poly.size() - 1]
	var left_end := poly[0]
	var span := b.head_rx * 0.86
	var prev := right_end
	for i in STRANDS:
		var t0 := float(i) / float(STRANDS)
		var t1 := float(i + 1) / float(STRANDS)
		var x0 := lerpf(span, -span, t0)
		var x1 := lerpf(span, -span, t1)
		var mid := (x0 + x1) * 0.5
		# Mitte am längsten, außen kürzer.
		var edge := absf(mid) / span
		var tip_y := head.y - b.head_ry * lerpf(TIP_Y - 0.06, TIP_Y + 0.16, edge * edge)
		var start := prev
		# Wurzel zwischen zwei Strähnen; liegt außen höher (Kopfrundung).
		var finish := Vector2(head.x + x1, head.y - b.head_ry * (ROOT_Y + 0.2 * pow(absf(x1) / span, 2.0)))
		if i == STRANDS - 1:
			finish = left_end
		# Rund geschwungene Strähne: über einen tiefen Kontrollpunkt zur nächsten Wurzel.
		_bezier(poly, start, Vector2(head.x + mid, tip_y + b.head_ry * 0.12), finish, 8)
		prev = finish
	poly.remove_at(poly.size() - 1)
	draw_colored_polygon(poly, hair)
	poly.append(poly[0])
	draw_polyline(poly, line, b.line_width * 0.8, LINE_AA)
	# Strähnenlinien und Glanz.
	var strand_line := hair.darkened(0.3)
	for i in range(1, STRANDS):
		var x := lerpf(span, -span, float(i) / float(STRANDS))
		var root := Vector2(head.x + x * 0.6, head.y - b.head_ry * 0.92)
		var end := Vector2(head.x + x, head.y - b.head_ry * (ROOT_Y + 0.2 * pow(absf(x) / span, 2.0)) - 0.4)
		draw_line(root, end, strand_line, b.line_width * 0.45, LINE_AA)
	draw_arc(head + Vector2(-b.head_rx * 0.15, -b.head_ry * 0.1), b.head_ry * 0.8, deg_to_rad(235.0), deg_to_rad(265.0), 8, hair.lightened(0.35), b.line_width * 0.6, LINE_AA)

# --- Gesicht ---

func _draw_face(s, b: BodySpec, head: Vector2, line: Color, snout: Color, snout_line: Color, tusk: Color) -> void:
	var center := head + Vector2(0.0, b.head_ry * 0.4)
	var snout_rx := 5.9 * b.snout_scale
	var snout_ry := 3.9 * b.snout_scale
	match snout_style:
		"wide":
			snout_rx = 7.2 * b.snout_scale
			snout_ry = 4.2 * b.snout_scale
		"small":
			snout_rx = 4.8 * b.snout_scale
			snout_ry = 3.2 * b.snout_scale
		"long":
			snout_rx = 6.2 * b.snout_scale
			snout_ry = 4.8 * b.snout_scale
		"heart":
			snout_rx = 5.7 * b.snout_scale
			snout_ry = 4.5 * b.snout_scale
		"chubby":
			snout_rx = 6.9 * b.snout_scale
			snout_ry = 5.1 * b.snout_scale
		"boar":
			snout_rx = 6.6 * b.snout_scale
			snout_ry = 4.0 * b.snout_scale
	if snout_style == "boar":
		# Kantige Keiler-Scheibe mit abgeschrägten Ecken.
		var rx := snout_rx
		var ry := snout_ry
		_draw_closed_polygon(PackedVector2Array([
			center + Vector2(-rx, -ry * 0.55),
			center + Vector2(-rx * 0.62, -ry),
			center + Vector2(rx * 0.62, -ry),
			center + Vector2(rx, -ry * 0.55),
			center + Vector2(rx, ry * 0.55),
			center + Vector2(rx * 0.62, ry),
			center + Vector2(-rx * 0.62, ry),
			center + Vector2(-rx, ry * 0.55),
		]), snout, snout_line, b.line_width)
	elif snout_style == "heart":
		center.y += snout_ry * 0.12
		_draw_closed_polygon(
			_soft_heart_points(center, snout_rx, snout_ry, 48),
			snout,
			snout_line,
			b.line_width * 0.9
		)
	else:
		_draw_ellipse(center, snout_rx, snout_ry, snout, snout_line, b.line_width * 0.8)

	# Beim Herz-Rüssel sitzen die Nasenlöcher in den beiden Bögen.
	var nose_center := center + Vector2(0.0, -snout_ry * 0.2) if snout_style == "heart" else center
	_draw_nose(nose_center, snout_rx, snout_ry, snout, snout_line, b)
	_draw_eyes(s, b, head, line)
	_draw_mouth(s, b, center, snout_ry, line)
	if tusk_shape != "":
		_draw_tusks_scaled(head + Vector2(0.0, b.head_ry * 0.82), b.tusk_scale, tusk)

	var blush := Color(1.0, 0.42, 0.52, 0.22)
	draw_circle(head + Vector2(-b.head_rx * 0.74, b.head_ry * 0.24), b.head_rx * 0.2, blush)
	draw_circle(head + Vector2(b.head_rx * 0.74, b.head_ry * 0.24), b.head_rx * 0.2, blush)

func _draw_nose(
	center: Vector2,
	rx: float,
	ry: float,
	snout: Color,
	snout_line: Color,
	b: BodySpec
) -> void:
	var scale := b.snout_scale
	match nose_style:
		"wide":
			_draw_ellipse(center + Vector2(-rx * 0.34, ry * 0.05), 1.5 * scale, 0.9 * scale, snout_line, Color(0.0, 0.0, 0.0, 0.0), 0.0)
			_draw_ellipse(center + Vector2(rx * 0.34, ry * 0.05), 1.5 * scale, 0.9 * scale, snout_line, Color(0.0, 0.0, 0.0, 0.0), 0.0)
		"slits":
			draw_line(center + Vector2(-rx * 0.34, -ry * 0.22), center + Vector2(-rx * 0.34, ry * 0.28), snout_line, 0.8 * scale, LINE_AA)
			draw_line(center + Vector2(rx * 0.34, -ry * 0.22), center + Vector2(rx * 0.34, ry * 0.28), snout_line, 0.8