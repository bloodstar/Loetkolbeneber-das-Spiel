extends "res://scripts/pig_variant_base.gd"
## Variante D – "Slim": schlanker, größerer Körper, lange Beine, dünne
## Konturen, mandelförmige Augen und lange, zurückgelegte Ohren.
## Ziel: eleganter, erwachsener Indie-Protagonist.

func _draw_character(s) -> void:
	var head := Vector2(s.head_x, -9.8 + s.head_bob)
	var body := Vector2(s.lean_x * 0.5, 1.4 + s.body_bob)
	var line := fur_color.darkened(0.48)
	line.a = 1.0
	var fur := fur_color
	var fur_dark: Color = s.fur_dark
	var snout: Color = s.snout_color
	var snout_line: Color = s.snout_outline

	# Feiner Ringelschwanz.
	var tail_wag: float = sin(_run_phase * 2.0 + 0.8) * 1.1 * s.run + sin(_time * 2.0) * 0.3 * s.idle
	draw_arc(
		Vector2(-9.6 + s.lean_x * 0.5, 1.4 + s.body_bob + tail_wag * 0.2),
		3.2,
		-PI * 0.9 + tail_wag * 0.03,
		PI * 0.8 + tail_wag * 0.03,
		14,
		line,
		1.0,
		LINE_AA
	)
	draw_arc(
		Vector2(-10.4 + s.lean_x * 0.5, -0.2 + s.body_bob + tail_wag * 0.2),
		1.6,
		PI * 0.4,
		PI * 2.1,
		10,
		fur_dark,
		0.8,
		LINE_AA
	)

	var outfit_head := head
	var outfit_neck := Vector2((s.head_x + s.lean_x * 0.55) * 0.5, -1.0 + (s.head_bob + s.body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(s.run, s.air))

	# Lange, schmale Beine.
	_draw_ellipse(Vector2(s.left_leg_x * 0.9, s.left_leg_y + 0.8), 2.4, 4.0, fur_dark, line, 0.8)
	_draw_ellipse(Vector2(s.right_leg_x * 0.9, s.right_leg_y + 0.8), 2.4, 4.0, fur_dark, line, 0.8)
	_draw_ellipse(Vector2(s.left_leg_x * 0.9, s.left_leg_y + 3.5), 2.4, 1.4, s.hoof_color, line, 0.7)
	_draw_ellipse(Vector2(s.right_leg_x * 0.9, s.right_leg_y + 3.5), 2.4, 1.4, s.hoof_color, line, 0.7)

	# Schlanker, hoher Körper.
	_draw_ellipse(body, 8.8, 11.0, fur, line, 0.9)
	var belly := fur.lightened(0.12)
	belly.a = 0.4
	_draw_ellipse(Vector2(body.x, body.y - 2.0), 5.2, 5.4, belly, Color(0.0, 0.0, 0.0, 0.0), 0.0)

	_draw_shorts(s.body_bob, line, s.belt_color, s.buckle_color, s.lean_x * 0.5, s.step * 1.1 * s.run, 17.8, 3.4, 12.0, 0.8)

	# Kopf.
	_draw_ellipse(head, 9.8, 9.0, fur, line, 0.9)

	# Lange, zurückgelegte Ohren.
	for side: float in [-1.0, 1.0]:
		var base := head + Vector2(7.2 * side, -5.8)
		var outer := PackedVector2Array([
			base + Vector2(-2.0 * side, 1.6),
			base + Vector2(3.2 * side, -6.4),
			base + Vector2(4.9 * side, 0.5),
		])
		draw_colored_polygon(outer, fur_dark)
		outer.append(outer[0])
		draw_polyline(outer, line, 0.9, LINE_AA)
		var inner := PackedVector2Array([
			base + Vector2(-0.9 * side, 1.1),
			base + Vector2(2.4 * side, -5.4),
			base + Vector2(3.3 * side, 0.3),
		])
		draw_colored_polygon(inner, snout)

	# Einzelne, geschwungene Haarspitze.
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-1.8, -8.0),
		head + Vector2(-0.2, -10.8),
		head + Vector2(2.2, -9.8),
		head + Vector2(0.8, -8.8),
	]), fur_dark)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

	# Schmales Rüsselchen.
	var snout_center := Vector2(head.x, -5.8 + s.head_bob)
	_draw_ellipse(snout_center, 5.4, 3.2, snout, snout_line, 0.8)
	draw_circle(snout_center + Vector2(-1.8, 0.1), 0.7, snout_line)
	draw_circle(snout_center + Vector2(1.8, 0.1), 0.7, snout_line)

	# Mandelförmige Augen.
	var left_eye := Vector2(-4.2 + s.head_x, -12.0 + s.head_bob)
	var right_eye := Vector2(4.2 + s.head_x, -12.0 + s.head_bob)
	if s.hurt:
		_draw_hurt_eyes(left_eye, right_eye, 2.1, line)
		_draw_ellipse(
			Vector2(head.x, -1.2 + s.head_bob),
			1.9,
			1.3,
			Color(0.22, 0.06, 0.08, 1.0),
			line,
			0.6
		)
	else:
		for eye: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(eye, 2.5, 2.1, Color(0.99, 0.97, 0.94, 1.0), line, 0.7)
			var iris := eye + Vector2(0.15, 0.1)
			draw_circle(iris, 1.5, eye_color)
			draw_circle(iris + Vector2(0.0, 0.12), 0.75, Color(0.04, 0.03, 0.05, 1.0))
			draw_circle(iris + Vector2(-0.45, -0.45), 0.48, Color(1.0, 1.0, 1.0, 0.95))
		# Feiner Mund.
		draw_arc(
			Vector2(head.x, -2.6 + s.head_bob),
			1.5,
			PI * 0.25,
			PI * 0.75,
			8,
			line,
			0.7,
			LINE_AA
		)

	_draw_tusks(Vector2(s.head_x, s.head_bob + 0.2), s.tusk_color)

	var blush := Color(1.0, 0.42, 0.52, 0.16)
	draw_circle(Vector2(-7.4 + s.head_x, -6.6 + s.head_bob), 1.6, blush)
	draw_circle(Vector2(7.4 + s.head_x, -6.6 + s.head_bob), 1.6, blush)
