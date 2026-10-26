class_name PigCharacter
extends Node2D

## Prozedural gezeichnetes Schwein/Eber. Fell-, Augen- und Hosenfarbe sind
## unabhängig voneinander einstellbar, damit jeder Spieler seinen Charakter
## in der Lobby anpassen kann. Die Figur wird komplett im Code gezeichnet und
## benötigt keine Sprite-Textur.

const HIT_DURATION: float = 0.32
const BLOOD_DURATION: float = 0.5
const BLOOD_GRAVITY: float = 240.0
# DOT-Ticks laufen mit der Mindeststärke 0.35; erst echte Treffer sollen
# sichtbare Blutspritzer auslösen.
const BLOOD_MIN_STRENGTH: float = 0.4
const RUN_CADENCE_MIN: float = 7.0
const RUN_CADENCE_MAX: float = 21.0
const RUN_SPEED_FOR_FULL_ENERGY: float = 260.0

@export var fur_color: Color = Color(0.91, 0.60, 0.67, 1.0)
@export var eye_color: Color = Color(0.18, 0.14, 0.20, 1.0)
@export var pants_color: Color = Color(0.24, 0.36, 0.56, 1.0)

# Wird vom Player gesetzt, damit die Figur in Blickrichtung schaut.
var flip_h: bool = false
# Vorschauen im Menü dürfen animiert sein, Ghost-Trails dagegen nicht.
var animate: bool = true
# Wenn false, wird die Laufanimation ignoriert (z. B. in der UI-Vorschau).
var follow_parent_motion: bool = true
# Replicas bewegen sich ohne move_and_slide(); dort ist is_on_floor() nicht
# verlässlich und wird durch die vertikale Snapshot-Geschwindigkeit ersetzt.
var use_parent_floor_state: bool = true

var _time: float = 0.0
var _move_energy: float = 0.0
var _air_energy: float = 0.0
var _run_phase: float = 0.0
var _motion_velocity: Vector2 = Vector2.ZERO
var _hit_timer: float = 0.0
var _hit_direction: Vector2 = Vector2.ZERO
var _hit_strength: float = 1.0
var _blood_particles: Array[Dictionary] = []

func _ready() -> void:
	queue_redraw()

func setup(p_fur: Color, p_eye: Color, p_pants: Color) -> void:
	fur_color = p_fur
	eye_color = p_eye
	pants_color = p_pants
	queue_redraw()

# Löst die kurze Trefferanimation aus. Die Richtung ist die Weltrichtung des
# Rückstoßes; dadurch kippt und zuckt die Figur passend zur Schadensquelle.
func play_hit(direction: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	_hit_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.ZERO
	_hit_strength = clampf(strength, 0.25, 1.0)
	_hit_timer = HIT_DURATION
	_spawn_blood_particles()
	queue_redraw()

func _process(delta: float) -> void:
	if not animate:
		return

	_time += delta
	_update_motion(delta)
	_update_blood_particles(delta)
	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
	queue_redraw()

func _update_motion(delta: float) -> void:
	_motion_velocity = Vector2.ZERO
	var on_floor := true
	if follow_parent_motion:
		var parent := get_parent()
		if parent is CharacterBody2D:
			_motion_velocity = parent.velocity
			if use_parent_floor_state:
				on_floor = parent.is_on_floor()
			else:
				on_floor = absf(parent.velocity.y) < 12.0

	var horizontal_speed := absf(_motion_velocity.x)
	var target_energy := 0.0
	if horizontal_speed > 12.0:
		target_energy = clampf(horizontal_speed / RUN_SPEED_FOR_FULL_ENERGY, 0.0, 1.0)
	_move_energy = move_toward(_move_energy, target_energy, delta * 8.0)

	var target_air := 0.0 if on_floor or not follow_parent_motion else 1.0
	_air_energy = move_toward(_air_energy, target_air, delta * 10.0)

	if _move_energy > 0.01:
		var cadence := clampf(
			RUN_CADENCE_MIN + horizontal_speed / 32.0,
			RUN_CADENCE_MIN,
			RUN_CADENCE_MAX
		)
		_run_phase = fmod(_run_phase + delta * cadence * _move_energy, TAU)

func _spawn_blood_particles() -> void:
	if not animate or _hit_strength < BLOOD_MIN_STRENGTH:
		return
	var count := 5 + int(round(_hit_strength * 4.0))
	var hit_angle := _hit_direction.angle() if _hit_direction.length_squared() > 0.001 else 0.0
	for i in range(count):
		var phase := float(i) * 2.399963
		var angle := TAU * float(i) / float(count) + sin(phase) * 0.24 + hit_angle * 0.12
		var speed := (32.0 + 58.0 * _hit_strength) * (0.78 + 0.22 * absf(cos(phase * 1.7)))
		var origin_radius := 5.5 + 2.0 * absf(sin(phase))
		var origin := Vector2(
			cos(angle) * origin_radius,
			-7.0 + sin(angle) * origin_radius * 0.9
		)
		var life := BLOOD_DURATION * (0.74 + 0.26 * absf(sin(phase * 1.3)))
		var size := 0.85 + 0.8 * absf(cos(phase * 2.1))
		var velocity := Vector2(cos(angle), sin(angle)) * speed
		velocity.y -= 22.0
		velocity += _hit_direction * (14.0 * _hit_strength)
		_blood_particles.append({
			"pos": origin,
			"vel": velocity,
			"life": life,
			"max_life": life,
			"size": size,
		})
	while _blood_particles.size() > 28:
		_blood_particles.remove_at(0)

func _update_blood_particles(delta: float) -> void:
	for i in range(_blood_particles.size() - 1, -1, -1):
		var particle: Dictionary = _blood_particles[i]
		var life := float(particle["life"]) - delta
		if life <= 0.0:
			_blood_particles.remove_at(i)
			continue
		var velocity: Vector2 = particle["vel"]
		velocity.y += BLOOD_GRAVITY * delta
		var position: Vector2 = particle["pos"]
		position += velocity * delta
		particle["life"] = life
		particle["vel"] = velocity
		particle["pos"] = position
		_blood_particles[i] = particle

func _draw() -> void:
	var run := _move_energy
	var idle := 1.0 - run
	var air := _air_energy
	var step := sin(_run_phase)

	# Der Körper federt im Laufrhythmus, der Kopf läuft leicht versetzt nach.
	var body_bob := sin(_time * 2.2) * 0.45 * idle + sin(_run_phase * 2.0) * 1.15 * run
	var head_bob := body_bob + sin(_run_phase * 2.0 + 0.35) * 0.75 * run

	# Vorwärtsneigung relativ zur Blickrichtung. Rückwärtslaufen lehnt die
	# Figur entsprechend nach hinten.
	var facing := -1.0 if flip_h else 1.0
	var lean := clampf(_motion_velocity.x * facing / RUN_SPEED_FOR_FULL_ENERGY, -1.0, 1.0)
	var lean_x := lean * 1.2 * run
	var head_x := lean * 1.9 * run

	var left_leg_x := -5.4 + step * 2.6 * run + air * 0.8
	var right_leg_x := 5.4 - step * 2.6 * run - air * 0.8
	var left_lift := maxf(0.0, step) * 2.4 * run + air * 2.0
	var right_lift := maxf(0.0, -step) * 2.4 * run + air * 2.0
	var left_leg_y := 12.2 + body_bob - left_lift
	var right_leg_y := 12.2 + body_bob - right_lift

	# Trefferanimation: kurzes Zurückweichen, Zittern und Stauchen. Bei
	# starkem Schaden ist die Bewegung deutlicher als bei kleinen DOT-Ticks.
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
	var draw_scale := Vector2(facing * (1.0 + squash), 1.0 - squash * 0.85)

	var outline := fur_color.darkened(0.42)
	outline.a = 1.0
	var fur_dark := fur_color.darkened(0.18)
	var snout_color := fur_color.lightened(0.32).lerp(Color(1.0, 0.66, 0.72, 1.0), 0.34)
	var snout_outline := fur_color.darkened(0.35)
	var hoof_color := Color(0.28, 0.20, 0.20, 1.0)
	var belt_color := pants_color.darkened(0.35)
	var buckle_color := Color(1.0, 0.80, 0.28, 1.0)
	var tusk_color := Color(0.98, 0.95, 0.82, 1.0)

	draw_set_transform(hit_offset, 0.0, draw_scale)

	# Ringelschwanz hinter dem Körper.
	var tail_wag := sin(_run_phase * 2.0 + 0.8) * 1.2 * run + sin(_time * 2.0) * 0.35 * idle
	draw_arc(
		Vector2(-11.0 + lean_x * 0.5, 0.5 + body_bob + tail_wag * 0.2),
		3.6,
		-PI * 0.85 + tail_wag * 0.03,
		PI * 0.85 + tail_wag * 0.03,
		14,
		outline,
		1.5,
		true
	)
	draw_arc(Vector2(-12.2 + lean_x * 0.5, -1.0 + body_bob + tail_wag * 0.2), 1.8, PI * 0.35, PI * 2.15, 10, fur_dark, 1.2, true)

	# Beine und Hufe (hinter der Hose). Das vordere Bein hebt beim Laufen ab.
	_draw_ellipse(Vector2(left_leg_x, left_leg_y), 2.7, 4.1, fur_dark, outline, 0.7)
	_draw_ellipse(Vector2(right_leg_x, right_leg_y), 2.7, 4.1, fur_dark, outline, 0.7)
	_draw_ellipse(Vector2(left_leg_x, left_leg_y + 3.2), 2.7, 1.7, hoof_color, outline, 0.6)
	_draw_ellipse(Vector2(right_leg_x, right_leg_y + 3.2), 2.7, 1.7, hoof_color, outline, 0.6)

	# Körper und Kopf als zwei überlappende, weiche Kugeln.
	_draw_ellipse(Vector2(lean_x * 0.55, 1.7 + body_bob), 10.7, 9.9, fur_color, outline, 1.2)
	_draw_ellipse(Vector2(head_x, -8.2 + head_bob), 10.6, 9.8, fur_color, outline, 1.2)

	# Kurze Hose mit Gürtel und zwei Hosenbeinen.
	_draw_pants(body_bob, outline, belt_color, buckle_color, lean_x * 0.5, step * 1.1 * run)

	# Ohren liegen hinter dem Kopf und flattern leicht im Laufrhythmus.
	var ear_flap := sin(_run_phase * 2.0 + 0.9) * 0.7 * run
	_draw_ear(Vector2(-7.9 + head_x, -14.5 + head_bob + ear_flap), -1.0, fur_dark, snout_color, outline)
	_draw_ear(Vector2(7.9 + head_x, -14.5 + head_bob - ear_flap), 1.0, fur_dark, snout_color, outline)

	# Kleiner Eberbüschel auf dem Kopf.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.4 + head_x, -16.9 + head_bob),
		Vector2(0.0 + head_x, -20.4 + head_bob),
		Vector2(2.8 + head_x, -16.7 + head_bob),
	]), fur_dark)

	# Rüssel.
	var snout_center := Vector2(head_x, -4.7 + head_bob)
	_draw_ellipse(snout_center, 5.9, 3.9, snout_color, snout_outline, 0.8)
	draw_circle(snout_center + Vector2(-2.0, 0.0), 0.85, snout_outline)
	draw_circle(snout_center + Vector2(2.0, 0.0), 0.85, snout_outline)

	# Augen mit einstellbarer Irisfarbe. Im Treffermoment schließen sie sich
	# kurz; gleichzeitig spritzen kleine Blutpartikel um die Figur.
	if hurt:
		_draw_closed_eye(Vector2(-4.2 + head_x, -10.5 + head_bob), outline)
		_draw_closed_eye(Vector2(4.2 + head_x, -10.5 + head_bob), outline)
		_draw_ellipse(
			Vector2(head_x, 0.6 + head_bob),
			2.1,
			1.4,
			Color(0.22, 0.06, 0.08, 1.0),
			outline,
			0.5
		)
	else:
		_draw_eye(Vector2(-4.2 + head_x, -10.5 + head_bob), outline)
		_draw_eye(Vector2(4.2 + head_x, -10.5 + head_bob), outline)

	# Kleine Eberhauer.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.3 + head_x, -3.3 + head_bob),
		Vector2(-7.5 + head_x, -1.6 + head_bob),
		Vector2(-5.0 + head_x, -1.3 + head_bob),
	]), tusk_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.3 + head_x, -3.3 + head_bob),
		Vector2(7.5 + head_x, -1.6 + head_bob),
		Vector2(5.0 + head_x, -1.3 + head_bob),
	]), tusk_color)

	# Wangenrouge.
	draw_circle(Vector2(-7.8 + head_x, -6.0 + head_bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))
	draw_circle(Vector2(7.8 + head_x, -6.0 + head_bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_blood_particles()

func _draw_blood_particles() -> void:
	for particle in _blood_particles:
		var life := float(particle["life"])
		var max_life := maxf(0.001, float(particle["max_life"]))
		var fade := clampf(life / max_life, 0.0, 1.0)
		var position: Vector2 = particle["pos"]
		var velocity: Vector2 = particle["vel"]
		var size := float(particle["size"])
		var blood := Color(0.74, 0.05, 0.10, 0.92 * fade)
		var blood_dark := Color(0.42, 0.02, 0.05, 0.85 * fade)
		if velocity.length_squared() > 25.0:
			var tail := velocity.normalized() * (size * 2.1)
			draw_line(position - tail, position, blood_dark, maxf(0.7, size * 0.8), true)
		draw_circle(position, size, blood)
		draw_circle(
			position + Vector2(-size * 0.28, -size * 0.28),
			maxf(0.35, size * 0.33),
			Color(1.0, 0.42, 0.46, 0.55 * fade)
		)

func _draw_pants(
	bob: float,
	outline: Color,
	belt_color: Color,
	buckle_color: Color,
	x_offset: float = 0.0,
	leg_step: float = 0.0
) -> void:
	var top := 4.3 + bob
	var bottom := 12.3 + bob
	var pants_rect := Rect2(-10.2 + x_offset, top, 20.4, bottom - top)
	draw_rect(pants_rect, pants_color, true)
	draw_rect(pants_rect, outline, false, 1.0)

	# Zwei Hosenbeine, die den Laufschritt leicht mitgehen.
	var left_leg := Rect2(-9.5 + x_offset + leg_step, bottom - 0.8, 8.3, 3.9)
	var right_leg := Rect2(1.2 + x_offset - leg_step, bottom - 0.8, 8.3, 3.9)
	draw_rect(left_leg, pants_color, true)
	draw_rect(right_leg, pants_color, true)
	draw_rect(left_leg, outline, false, 1.0)
	draw_rect(right_leg, outline, false, 1.0)

	# Gürtel.
	var belt := Rect2(-10.2 + x_offset, top - 0.3, 20.4, 2.7)
	draw_rect(belt, belt_color, true)
	draw_rect(belt, outline, false, 1.0)
	draw_rect(Rect2(-1.7 + x_offset, top - 0.7, 3.4, 3.4), buckle_color, true)
	draw_rect(Rect2(-1.7 + x_offset, top - 0.7, 3.4, 3.4), outline, false, 0.7)

	# Kleine Naht in der Mitte.
	draw_line(Vector2(x_offset, top + 2.2), Vector2(x_offset, bottom - 0.6), outline, 0.8, true)

func _draw_ear(base: Vector2, direction: float, outer: Color, inner: Color, outline: Color) -> void:
	var outer_points := PackedVector2Array([
		base + Vector2(-2.2 * direction, 1.6),
		base + Vector2(4.4 * direction, -4.2),
		base + Vector2(5.0 * direction, 2.7),
	])
	draw_colored_polygon(outer_points, outer)
	outer_points.append(outer_points[0])
	draw_polyline(outer_points, outline, 1.0, true)

	var inner_points := PackedVector2Array([
		base + Vector2(-0.8 * direction, 1.0),
		base + Vector2(3.2 * direction, -2.4),
		base + Vector2(3.5 * direction, 1.7),
	])
	draw_colored_polygon(inner_points, inner)

func _draw_eye(pos: Vector2, outline: Color) -> void:
	_draw_ellipse(pos, 2.35, 2.7, Color(0.98, 0.96, 0.93, 1.0), outline, 0.6)
	var iris := pos + Vector2(0.15, 0.25)
	draw_circle(iris, 1.45, eye_color)
	draw_circle(iris + Vector2(0.05, 0.15), 0.72, Color(0.05, 0.04, 0.06, 1.0))
	draw_circle(iris + Vector2(-0.45, -0.58), 0.42, Color(1.0, 1.0, 1.0, 0.95))

func _draw_closed_eye(pos: Vector2, outline: Color) -> void:
	draw_arc(
		pos + Vector2(0.0, 0.35),
		2.05,
		PI * 0.18,
		PI * 0.82,
		10,
		outline,
		1.4,
		true
	)

func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, fill: Color, outline: Color, outline_width: float) -> void:
	var points := _ellipse_points(center, radius_x, radius_y, 24)
	draw_colored_polygon(points, fill)
	if outline_width > 0.0 and outline.a > 0.0:
		var line_points := PackedVector2Array(points)
		line_points.append(points[0])
		draw_polyline(line_points, outline, outline_width, true)

func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
