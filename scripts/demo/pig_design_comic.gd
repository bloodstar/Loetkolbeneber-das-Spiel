extends "res://scripts/pig_variant_base.gd"

## Variante B – "Comic": dicke Konturen, flächige Farben, große Miene.
## Ziel: grafischer, auf kleine Distanz sofort lesbarer Look.

func _draw_character(s) -> void:
	var head := Vector2(s.head_x, -10.2 + s.head_bob)
	var body := Vector2(s.lean_x * 0.5, 3.2 + s.body_bob)
	var line := fur_color.darkened(0.62)
	line.a = 1.0
	var fur := fur_color
	var fur_dark: Color = s.fur_dark
	var snout: Color = s.snout_color
	var snout_line: Color = s.snout_outline
	var bold := 2.0

	# Kräftiger Ringelschwanz.
	var tail_wag: float = sin(_run_phase * 2.0 + 0.8) * 1.2 * s.run + sin(_time * 2.0) * 0.35 * s.idle
	draw_arc(
		Vector2(-11.4 + s.lean_x * 0.5, 2.4 + s.body_bob + tail_wag * 0.2),
		3.9,
		-PI * 0.9 + tail_wag * 0.03,
		PI * 0.8 + tail_wag * 0.03,
		16,
		line,
		2.2,
		LINE_AA
	)

	var outfit_head := head
	var outfit_neck := Vector2((s.head_x + s.lean_x * 0.55) * 0.5, 0.8 + (s.head_bob + s.body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(s.run, s.air))

	# Stämmige Beine, große dunkle Hufe.
	_draw_ellipse(Vector2(s.left_leg_x * 0.95, s.left_leg_y + 0.5), 3.2, 3.5, fur_dark, line, 1.4)
	_draw_ellipse(Vector2(s.right_leg_x * 0.95, s.right_leg_y + 0.5), 3.2, 3.5, fur_dark, line, 1.4)
	_draw_ellipse(Vector2(s.left_leg_x * 0.95, s.left_leg_y + 3.1), 3.2, 1.8, s.hoof_color, line, 1.3)
	_draw_ellipse(Vector2(s.right_leg_x * 0.95, s.right_leg_y + 3.1), 3.2, 1.8, s.hoof_color, line, 1.3)

	# Breiter Körper mit heller Bauchfläche. Die Bauchfläche bleibt ohne
	# Kontur, sonst entsteht unter dem Kinn eine harte Querlinie.
	_draw_ellipse(body, 11.8, 9.6, fur, line, bold)
	_draw_ellipse(
		Vector2(body.x, body.y - 2.2),
		7.4,
		5.2,
		fur.lightened(0.24),
		Color(0.0, 0.0, 0.0, 0.0),
		0.0
	)

	_draw_shorts(s.body_bob, line, s.belt_color, s.buckle_color, s.lean_x * 0.5, s.step * 1.1 * s.run, 23.4, 5.6, 12.7, 1.8)

	# Breiter Kopf.
	_draw_ellipse(head, 11.4, 10.0, fur, line, bold)

	# Große, spitz zulaufende Ohren.
	for side: float in [-1.0, 1.0]:
		var base := head + Vector2(7.6 * side, -5.4)
		var outer := PackedVector2Array([
			base + Vector2(-2.8 * side, 2.0),
			base + Vector2(3.8 * side, -6.6),
			base + Vector2(5.8 * side, 0.4),
		])
		draw_colored_polygon(outer, fur_dark)
		outer.append(outer[0])
		draw_polyline(outer, line, 1.6, LINE_AA)
		var inner := PackedVector2Array([
			base + Vector2(-1.4 * side, 1.3),
			base + Vector2(2.6 * side, -4.4),
			base + Vector2(3.9 * side, 0.3),
		])
		draw_colored_polygon(inner, snout)

	# Frecher Haarbüschel.
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-2.8, -8.0),
		head + Vector2(-1.2, -11.2),
		head + Vector2(0.2, -9.4),
		head + Vector2(2.2, -11.6),
		head + Vector2(3.0, -7.8),
	]), fur_dark)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

	# Großer Rüssel mit kräftigen Nüstern.
	var snout_center := head + Vector2(0.0, 4.6)
	_draw_ellipse(snout_center, 7.2, 4.6, snout, snout_line, bold * 0.8)
	draw_circle(snout_center + Vector2(-2.6, 0.1), 1.2, snout_line)
	draw_circle(snout_center + Vector2(2.6, 0.1), 1.2, snout_line)

	var left_eye := head + Vector2(-4.9, -3.0)
	var right_eye := head + Vector2(4.9, -3.0)
	if s.hurt:
		_draw_hurt_eyes(left_eye, right_eye, 2.4, line)
		_draw_ellipse(
			head + Vector2(0.0, 8.4),
			2.6,
			1.8,
			Color(0.22, 0.06, 0.08, 1.0),
			line,
			0.8
		)
	else:
		for eye: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(eye, 2.8, 3.2, Color(0.99, 0.97, 0.94, 1.0), line, 1.0)
			var iris := eye + Vector2(0.1, 0.25)
			draw_circle(iris, 1.75, eye_color)
			draw_circle(iris + Vector2(0.05, 0.2), 1.3, Color(0.04, 0.03, 0.05, 1.0))
			draw_circle(iris + Vector2(-0.55, -0.7), 0.62, Color(1.0, 1.0, 1.0, 0.97))
		# Breiter Mund.
		draw_polyline(PackedVector2Array([
			head + Vector2(-3.0, 8.6),
			head + Vector2(0.0, 9.7),
			head + Vector2(3.0, 8.6),
		]), line, 1.1, LINE_AA)

	# Selbstbewusste Brauen.
	draw_line(
		head + Vector2(-6.8, -6.2),
		head + Vector2(-3.0, -5.2),
		line,
		1.7,
		LINE_AA
	)
	draw_line(
		head + Vector2(6.8, -6.2),
		head + Vector2(3.0, -5.2),
		line,
		1.7,
		LINE_AA
	)

	_draw_tusks(Vector2(s.head_x, s.head_bob - 1.0), s.tusk_color)

	var blush := Color(1.0, 0.42, 0.52, 0.22)
	draw_circle(head + Vector2(-8.6, 2.6), 2.0, blush)
	draw_circle(head + Vector2(8.6, 2.6), 2.0, blush)
