extends "res://scripts/pig_variant_base.gd"
## Variante A – "Mascot": rund, weich, große Augen, kurze Beine.
## Ziel: freundlicher Maskottchen-Look, der auch klein gut lesbar ist.

func _draw_character(s) -> void:
	var head := Vector2(s.head_x, -9.4 + s.head_bob)
	var body := Vector2(s.lean_x * 0.5, 2.4 + s.body_bob)
	var line := fur_color.darkened(0.34)
	line.a = 1.0
	var fur := fur_color
	var fur_dark: Color = s.fur_dark
	var snout: Color = s.snout_color
	var snout_line: Color = s.snout_outline

	# Ringelschwanz hinter dem Körper.
	var tail_wag: float = sin(_run_phase * 2.0 + 0.8) * 1.2 * s.run + sin(_time * 2.0) * 0.35 * s.idle
	draw_arc(
		Vector2(-10.8 + s.lean_x * 0.5, 1.4 + s.body_bob + tail_wag * 0.2),
		4.2,
		-PI * 0.9 + tail_wag * 0.03,
		PI * 0.8 + tail_wag * 0.03,
		16,
		line,
		1.8,
		LINE_AA
	)
	draw_arc(
		Vector2(-11.8 + s.lean_x * 0.5, -0.4 + s.body_bob + tail_wag * 0.2),
		2.1,
		PI * 0.35,
		PI * 2.1,
		12,
		fur_dark,
		1.4,
		LINE_AA
	)

	var outfit_head := head
	var outfit_neck := Vector2((s.head_x + s.lean_x * 0.55) * 0.5, -1.8 + (s.head_bob + s.body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(s.run, s.air))

	# Kurze, stämmige Beine mit großen Hufen.
	_draw_ellipse(Vector2(s.left_leg_x * 0.95, s.left_leg_y + 0.6), 3.1, 3.7, fur_dark, line, 1.0)
	_draw_ellipse(Vector2(s.right_leg_x * 0.95, s.right_leg_y + 0.6), 3.1, 3.7, fur_dark, line, 1.0)
	_draw_ellipse(Vector2(s.left_leg_x * 0.95, s.left_leg_y + 3.2), 3.1, 1.7, s.hoof_color, line, 0.9)
	_draw_ellipse(Vector2(s.right_leg_x * 0.95, s.right_leg_y + 3.2), 3.1, 1.7, s.hoof_color, line, 0.9)

	# Runder Körper mit weichem Bauchlicht.
	_draw_ellipse(body, 11.4, 10.4, fur, line, 1.4)
	var belly := fur.lightened(0.14)
	belly.a = 0.5
	_draw_ellipse(Vector2(body.x, body.y - 1.4), 7.0, 5.6, belly, Color(0.0, 0.0, 0.0, 0.0), 0.0)

	_draw_shorts(s.body_bob, line, s.belt_color, s.buckle_color, s.lean_x * 0.5, s.step * 1.1 * s.run, 22.4, 3.6, 12.9, 1.2)

	# Großer, runder Kopf.
	_draw_ellipse(head, 11.2, 10.4, fur, line, 1.4)

	# Große, weiche Ohren mit rosa Innenohr.
	for side: float in [-1.0, 1.0]:
		var base := head + Vector2(7.6 * side, -5.8)
		var outer := PackedVector2Array([
			base + Vector2(-2.6 * side, 1.4),
			base + Vector2(3.2 * side, -5.0),
			base + Vector2(5.4 * side, 0.6),
			base + Vector2(2.0 * side, 2.4),
		])
		draw_colored_polygon(outer, fur_dark)
		outer.append(outer[0])
		draw_polyline(outer, line, 1.2, LINE_AA)
		var inner := PackedVector2Array([
			base + Vector2(-1.2 * side, 1.0),
			base + Vector2(2.4 * side, -3.2),
			base + Vector2(3.6 * side, 0.2),
			base + Vector2(1.6 * side, 1.3),
		])
		draw_colored_polygon(inner, snout)

	# Weicher Haarbüschel.
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-2.6, -8.2),
		head + Vector2(-1.4, -10.6),
		head + Vector2(0.2, -9.2),
		head + Vector2(1.6, -11.0),
		head + Vector2(2.8, -8.0),
	]), fur_dark)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

	# Großer Rüssel mit weichen Nüstern.
	var snout_center := Vector2(head.x, -5.0 + s.head_bob)
	_draw_ellipse(snout_center, 6.6, 4.4, snout, snout_line, 1.0)
	draw_circle(snout_center + Vector2(-2.2, 0.0), 0.95, snout_line)
	draw_circle(snout_center + Vector2(2.2, 0.0), 0.95, snout_line)

	# Große Kulleraugen mit zwei Glanzpunkten.
	var left_eye := Vector2(-4.6 + s.head_x, -11.9 + s.head_bob)
	var right_eye := Vector2(4.6 + s.head_x, -11.9 + s.head_bob)
	if s.hurt:
		_draw_hurt_eyes(left_eye, right_eye, 2.5, line)
		_draw_ellipse(
			Vector2(head.x, -0.4 + s.head_bob),
			2.4,
			1.7,
			Color(0.22, 0.06, 0.08, 1.0),
			line,
			0.6
		)
	else:
		for eye: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(eye, 3.0, 3.4, Color(0.99, 0.97, 0.94, 1.0), line, 0.7)
			var iris := eye + Vector2(0.1, 0.3)
			draw_circle(iris, 1.9, eye_color)
			draw_circle(iris + Vector2(0.05, 0.2), 1.05, Color(0.05, 0.04, 0.06, 1.0))
			draw_circle(iris + Vector2(-0.62, -0.78), 0.62, Color(1.0, 1.0, 1.0, 0.97))
			draw_circle(iris + Vector2(0.55, 0.62), 0.28, Color(1.0, 1.0, 1.0, 0.8))
		# Kleiner Mund unter dem Rüssel.
		draw_arc(
			Vector2(head.x, -1.2 + s.head_bob),
			1.9,
			PI * 0.22,
			PI * 0.78,
			10,
			line,
			0.9,
			LINE_AA
		)

	_draw_tusks(Vector2(s.head_x, s.head_bob + 0.4), s.tusk_color)

	# Wangenrouge.
	var blush := Color(1.0, 0.42, 0.52, 0.28)
	draw_circle(Vector2(-8.2 + s.head_x, -6.6 + s.head_bob), 2.2, blush)
	draw_circle(Vector2(8.2 + s.head_x, -6.6 + s.head_bob), 2.2, blush)
