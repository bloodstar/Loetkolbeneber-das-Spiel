extends "res://scripts/pig_variant_base.gd"

## Variante C – "Keiler": breiter Körper, Borstenmähne, breite Rüsselscheibe,
## schmale Augen und ein gerader Schwanz mit Quaste.
## Ziel: rauer, kampfbetonter Eber statt niedlichem Schwein.

func _draw_character(s) -> void:
	var head := Vector2(s.head_x, -8.8 + s.head_bob)
	var body := Vector2(s.lean_x * 0.5, 2.0 + s.body_bob)
	var line := fur_color.darkened(0.5)
	line.a = 1.0
	var fur := fur_color
	var fur_dark: Color = s.fur_dark
	var snout: Color = s.snout_color
	var snout_line: Color = s.snout_outline

	# Gerader Schwanz mit Quaste. Der Ansatz liegt am Körperrand, damit die
	# Linie nicht hinter dem Bauch abreißt.
	var tail_wag: float = sin(_run_phase * 2.0 + 0.8) * 0.9 * s.run + sin(_time * 2.0) * 0.25 * s.idle
	var tail_root := Vector2(-12.4 + s.lean_x * 0.5, 2.2 + s.body_bob)
	var tail_tip := tail_root + Vector2(-2.8, -1.2 + tail_wag * 0.5)
	draw_line(tail_root, tail_tip, line, 2.0, LINE_AA)
	# Quaste als kompakte Borstenspitze.
	draw_colored_polygon(PackedVector2Array([
		tail_tip + Vector2(0.5, -0.7),
		tail_tip + Vector2(-2.2, -1.2),
		tail_tip + Vector2(-0.2, 0.8),
	]), fur_dark)

	var outfit_head := head
	var outfit_neck := Vector2((s.head_x + s.lean_x * 0.55) * 0.5, -1.2 + (s.head_bob + s.body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(s.run, s.air))

	# Borstenmähne: unregelmäßige Spitzen vom Hinterkopf bis zur Stirn.
	var mane: Color = fur_dark.darkened(0.16)
	for i in range(9):
		var angle := lerpf(-2.85, -0.25, float(i) / 8.0)
		var reach := 13.6 if i % 2 == 0 else 16.0
		var base := head + Vector2(cos(angle) * 11.4, sin(angle) * 9.4)
		var tip := head + Vector2(cos(angle) * reach, sin(angle) * (reach * 0.85))
		var tangent := Vector2(-sin(angle) * 11.4, cos(angle) * 9.4).normalized() * 1.5
		var spike := PackedVector2Array([base - tangent, tip, base + tangent])
		draw_colored_polygon(spike, mane)
		spike.append(spike[0])
		draw_polyline(spike, line, 0.9, LINE_AA)

	# Kräftige Beine.
	_draw_ellipse(Vector2(s.left_leg_x * 0.98, s.left_leg_y + 0.3), 3.6, 4.6, fur_dark, line, 1.3)
	_draw_ellipse(Vector2(s.right_leg_x * 0.98, s.right_leg_y + 0.3), 3.6, 4.6, fur_dark, line, 1.3)
	_draw_ellipse(Vector2(s.left_leg_x * 0.98, s.left_leg_y + 2.9), 3.6, 2.1, s.hoof_color, line, 1.2)
	_draw_ellipse(Vector2(s.right_leg_x * 0.98, s.right_leg_y + 2.9), 3.6, 2.1, s.hoof_color, line, 1.2)

	# Breiter, tief sitzender Körper.
	_draw_ellipse(body, 13.2, 10.2, fur, line, 1.5)
	_draw_shorts(s.body_bob, line, s.belt_color, s.buckle_color, s.lean_x * 0.5, s.step * 1.0 * s.run, 25.2, 4.0, 12.5, 1.4)

	# Kopf.
	_draw_ellipse(head, 11.8, 9.6, fur, line, 1.5)

	# Kleine, nach hinten gekämmte Ohren.
	for side: float in [-1.0, 1.0]:
		var base := head + Vector2(7.8 * side, -5.2)
		var outer := PackedVector2Array([
			base + Vector2(-2.8 * side, 1.6),
			base + Vector2(5.2 * side, -5.6),
			base + Vector2(6.0 * side, 0.4),
		])
		draw_colored_polygon(outer, fur_dark)
		outer.append(outer[0])
		draw_polyline(outer, line, 1.3, LINE_AA)
		var inner := PackedVector2Array([
			base + Vector2(-1.4 * side, 1.0),
			base + Vector2(3.8 * side, -3.4),
			base + Vector2(4.2 * side, 0.2),
		])
		draw_colored_polygon(inner, snout)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

	# Breite Rüsselscheibe mit kräftiger Mittellinie.
	var snout_center := head + Vector2(0.4, 3.8)
	_draw_ellipse(snout_center, 7.4, 4.4, snout, snout_line, 1.2)
	draw_line(
		snout_center + Vector2(-4.8, -1.2),
		snout_center + Vector2(4.8, -1.2),
		snout_line,
		0.7,
		LINE_AA
	)
	draw_circle(snout_center + Vector2(-2.6, 0.4), 1.1, snout_line)
	draw_circle(snout_center + Vector2(2.6, 0.4), 1.1, snout_line)

	# Schmale, wachsame Augen mit kräftigen Brauen.
	var left_eye := head + Vector2(-4.8, -2.6)
	var right_eye := head + Vector2(4.8, -2.6)
	if s.hurt:
		_draw_hurt_eyes(left_eye, right_eye, 2.0, line)
		_draw_ellipse(
			head + Vector2(0.0, 8.2),
			2.2,
			1.5,
			Color(0.22, 0.06, 0.08, 1.0),
			line,
			0.7
		)
	else:
		for eye: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(eye, 2.0, 1.8, Color(0.99, 0.97, 0.94, 1.0), line, 0.8)
			var iris := eye + Vector2(0.1, 0.15)
			draw_circle(iris, 1.15, eye_color)
			draw_circle(iris + Vector2(0.0, 0.12), 0.6, Color(0.04, 0.03, 0.05, 1.0))
			draw_circle(iris + Vector2(-0.4, -0.45), 0.32, Color(1.0, 1.0, 1.0, 0.9))
		draw_line(
			head + Vector2(-7.0, -5.4),
			head + Vector2(-3.0, -4.4),
			line,
			1.7,
			LINE_AA
		)
		draw_line(
			head + Vector2(7.0, -5.4),
			head + Vector2(3.0, -4.4),
			line,
			1.7,
			LINE_AA
		)

	_draw_tusks(Vector2(s.head_x, s.head_bob + 0.4), s.tusk_color)

	var blush := Color(1.0, 0.36, 0.42, 0.16)
	draw_circle(head + Vector2(-8.6, 2.4), 1.8, blush)
	draw_circle(head + Vector2(8.6, 2.4), 1.8, blush)
