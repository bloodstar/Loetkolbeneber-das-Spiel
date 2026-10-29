extends PigCharacter

## Demo-Basis für alternative Pig-Designs.
##
## Übernimmt die komplette Animation (Laufen, Springen, Treffer, Staub, Blut,
## Outfits) von PigCharacter und ersetzt nur das Zeichnen. Die Zustands-
## berechnung ist bewusst aus PigCharacter._draw() übernommen, damit die
## Varianten exakt dieselben Bewegungen zeigen, ohne die Spieldatei
## anzufassen.
##
## Eine Variante überschreibt nur _draw_character(state) und zeichnet damit
## Körper, Kopf, Gesicht und Kleidung in lokalen Koordinaten (Füße bei y≈17).

## Animations-Zustand eines Frames, den die Varianten zum Zeichnen brauchen.
class State extends RefCounted:
	var run: float = 0.0
	var idle: float = 1.0
	var air: float = 0.0
	var step: float = 0.0
	var body_bob: float = 0.0
	var head_bob: float = 0.0
	var lean_x: float = 0.0
	var head_x: float = 0.0
	var rise: float = 0.0
	var left_leg_x: float = 0.0
	var right_leg_x: float = 0.0
	var left_leg_y: float = 0.0
	var right_leg_y: float = 0.0
	var hurt: bool = false
	var facing: float = 1.0
	var outline: Color = Color.BLACK
	var fur_dark: Color = Color.BLACK
	var snout_color: Color = Color.BLACK
	var snout_outline: Color = Color.BLACK
	var hoof_color: Color = Color.BLACK
	var belt_color: Color = Color.BLACK
	var buckle_color: Color = Color.BLACK
	var tusk_color: Color = Color.BLACK

func _draw() -> void:
	var run := _move_energy
	var idle := 1.0 - run
	var air := _air_energy
	var step := sin(_run_phase)

	# Der Körper federt im Laufrhythmus, der Kopf läuft leicht versetzt nach.
	var body_bob := sin(_time * 2.2) * 0.45 * idle + sin(_run_phase * 2.0) * 1.5 * run
	var head_bob := body_bob + sin(_run_phase * 2.0 + 0.35) * 0.75 * run

	# Vorwärtsneigung relativ zur Blickrichtung.
	var facing := -1.0 if flip_h else 1.0
	var lean := clampf(_motion_velocity.x * facing / RUN_SPEED_FOR_FULL_ENERGY, -1.0, 1.0)
	var lean_x := lean * 1.2 * run
	var head_x := lean * 1.9 * run

	# In der Luft: beim Steigen Beine anziehen, beim Fallen leicht spreizen.
	var rise := _air_rise
	var tuck := air * (1.4 + 1.8 * maxf(0.0, rise))
	var spread := air * (0.2 + 1.4 * maxf(0.0, -rise))
	var left_leg_x := -5.4 + step * 3.3 * run - spread
	var right_leg_x := 5.4 - step * 3.3 * run + spread
	var left_lift := maxf(0.0, step) * 3.0 * run + tuck
	var right_lift := maxf(0.0, -step) * 3.0 * run + tuck
	var left_leg_y := 12.2 + body_bob - left_lift
	var right_leg_y := 12.2 + body_bob - right_lift

	# Trefferanimation: Zurückweichen, Zittern und Stauchen.
	var hurt_ratio := clampf(_hit_timer / HIT_DURATION, 0.0, 1.0)
	var hurt := hurt_ratio > 0.0
	var flinch := hurt_ratio * hurt_ratio * _hit_strength
	var hit_progress := 1.0 - hurt_ratio
	var recoil_x := _hit_direction.x * flinch * 2.6
	var recoil_y := _hit_direction.y * flinch * 1.6
	var hit_shake_x := sin(hit_progress * 52.0) * 1.7 * hurt_ratio * _hit_strength
	var hit_shake_y := cos(hit_progress * 41.0) * 0.9 * hurt_ratio * _hit_strength
	var hit_offset := Vector2(recoil_x + hit_shake_x, recoil_y + hit_shake_y)
	var squash := flinch * 0.08
	# Squash & Stretch: beim Absprung gestreckt, bei der Landung gestaucht.
	var stretch := air * rise * 0.09
	var land := 0.0
	if _land_timer > 0.0:
		var land_ratio := _land_timer / LAND_DURATION
		land = land_ratio * land_ratio * 0.16 * _land_strength
	var draw_scale := Vector2(
		facing * (1.0 + squash - stretch * 0.6 + land * 0.8),
		1.0 - squash * 0.85 + stretch - land
	)
	var tilt := clampf(_motion_velocity.x / RUN_SPEED_FOR_FULL_ENERGY, -1.0, 1.0) * (0.07 * run + 0.05 * air)
	var body_xf := Transform2D(tilt, draw_scale, 0.0, Vector2.ZERO)
	var draw_origin := hit_offset + FOOT_PIVOT - body_xf.basis_xform(FOOT_PIVOT)

	var outline := fur_color.darkened(0.42)
	outline.a = 1.0
	var fur_dark := fur_color.darkened(0.18)
	var snout_color := fur_color.lightened(0.32).lerp(Color(1.0, 0.66, 0.72, 1.0), 0.34)
	var snout_outline := fur_color.darkened(0.35)
	var hoof_color := Color(0.28, 0.20, 0.20, 1.0)
	var belt_color := pants_color.darkened(0.35)
	var buckle_color := Color(1.0, 0.80, 0.28, 1.0)
	var tusk_color := Color(0.98, 0.95, 0.82, 1.0)

	var state := State.new()
	state.run = run
	state.idle = idle
	state.air = air
	state.step = step
	state.body_bob = body_bob
	state.head_bob = head_bob
	state.lean_x = lean_x
	state.head_x = head_x
	state.rise = rise
	state.left_leg_x = left_leg_x
	state.right_leg_x = right_leg_x
	state.left_leg_y = left_leg_y
	state.right_leg_y = right_leg_y
	state.hurt = hurt
	state.facing = facing
	state.outline = outline
	state.fur_dark = fur_dark
	state.snout_color = snout_color
	state.snout_outline = snout_outline
	state.hoof_color = hoof_color
	state.belt_color = belt_color
	state.buckle_color = buckle_color
	state.tusk_color = tusk_color

	draw_set_transform(draw_origin, tilt, draw_scale)
	_draw_character(state)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_dust()
	_draw_blood_particles()

## Wird von jeder Variante überschrieben.
func _draw_character(_state) -> void:
	pass

## Kurze Hose mit Gürtel, Hosenbeinen und Naht. Breite und Höhe sind frei
## wählbar, damit die Varianten unterschiedliche Proportionen nutzen können.
func _draw_shorts(
	bob: float,
	outline: Color,
	belt_color: Color,
	buckle_color: Color,
	x_offset: float,
	leg_step: float,
	width: float,
	top: float,
	bottom: float,
	line_width: float = 1.0
) -> void:
	var half := width * 0.5
	var top_y := top + bob
	var bottom_y := bottom + bob
	var pants_rect := Rect2(-half + x_offset, top_y, width, bottom_y - top_y)
	draw_rect(pants_rect, pants_color, true)
	draw_rect(pants_rect, outline, false, line_width)

	var leg_width := half - 1.9
	var left_leg := Rect2(-half + 0.7 + x_offset + leg_step, bottom_y - 0.8, leg_width, 3.9)
	var right_leg := Rect2(half - 0.7 - leg_width + x_offset - leg_step, bottom_y - 0.8, leg_width, 3.9)
	draw_rect(left_leg, pants_color, true)
	draw_rect(right_leg, pants_color, true)
	draw_rect(left_leg, outline, false, line_width)
	draw_rect(right_leg, outline, false, line_width)

	var belt := Rect2(-half + x_offset, top_y - 0.3, width, 2.7)
	draw_rect(belt, belt_color, true)
	draw_rect(belt, outline, false, line_width)
	var buckle := Rect2(-1.7 + x_offset, top_y - 0.7, 3.4, 3.4)
	draw_rect(buckle, buckle_color, true)
	draw_rect(buckle, outline, false, line_width * 0.7)

	draw_line(Vector2(x_offset, top_y + 2.2), Vector2(x_offset, bottom_y - 0.6), outline, line_width * 0.8, LINE_AA)

## Zwei geschlossene Augen für den Treffermoment.
func _draw_hurt_eyes(left: Vector2, right: Vector2, radius: float, line: Color) -> void:
	for pos: Vector2 in [left, right]:
		draw_arc(pos + Vector2(0.0, 0.35), radius, PI * 0.18, PI * 0.82, 10, line, 1.4, LINE_AA)
