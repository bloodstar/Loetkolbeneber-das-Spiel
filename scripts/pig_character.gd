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
const LAND_DURATION: float = 0.18
const DUST_DURATION: float = 0.42
# Squash & Stretch und Neigung drehen bzw. stauchen um die Füße.
const FOOT_PIVOT: Vector2 = Vector2(0.0, 16.0)
# Die Figur ist im Spiel nur wenige Pixel groß. Die weiche Kante der
# antialiasten Linien würde sie dort verwischen; Kanten glättet stattdessen
# MSAA (Projekteinstellung rendering/anti_aliasing/quality/msaa_2d).
const LINE_AA: bool = false

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
# Festes Klassen-Outfit (Held-ID, z. B. "phantom"). Leer = kein Outfit.
var outfit_id: String = ""
# Hauerform aus der Charakteranpassung (Global.TUSK_SHAPES).
var tusk_shape: String = "small"
# Teamfarbe für das Klassen-Outfit. Alpha 0 = keine Teams, dann trägt das
# Outfit seine festen Klassenfarben.
var team_color: Color = Color(0.0, 0.0, 0.0, 0.0)

var _time: float = 0.0
var _move_energy: float = 0.0
var _air_energy: float = 0.0
var _run_phase: float = 0.0
var _motion_velocity: Vector2 = Vector2.ZERO
var _hit_timer: float = 0.0
var _hit_direction: Vector2 = Vector2.ZERO
var _hit_strength: float = 1.0
var _blood_particles: Array[Dictionary] = []
var _air_rise: float = 0.0
var _was_on_floor: bool = true
var _air_time: float = 0.0
var _last_air_vy: float = 0.0
var _land_timer: float = 0.0
var _land_strength: float = 0.0
var _prev_step_sign: float = 0.0
var _dust: Array[Dictionary] = []

func _ready() -> void:
	queue_redraw()

func setup(p_fur: Color, p_eye: Color, p_pants: Color) -> void:
	fur_color = p_fur
	eye_color = p_eye
	pants_color = p_pants
	queue_redraw()

func set_tusk_shape(p_shape: String) -> void:
	if tusk_shape == p_shape:
		return
	tusk_shape = p_shape
	queue_redraw()

func set_outfit(p_outfit_id: String) -> void:
	if outfit_id == p_outfit_id:
		return
	outfit_id = p_outfit_id
	queue_redraw()

func set_team_color(p_color: Color) -> void:
	if team_color == p_color:
		return
	team_color = p_color
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
	_update_dust(delta)
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

	# Sprung und Landung: Richtung in der Luft (steigen/fallen) und ein
	# kurzes Stauchen beim Aufkommen, abhängig von der Fallgeschwindigkeit.
	if follow_parent_motion:
		if on_floor:
			if not _was_on_floor and _air_time > 0.12 and _last_air_vy > 160.0:
				_land_strength = clampf(_last_air_vy / 700.0, 0.35, 1.0)
				_land_timer = LAND_DURATION
				_spawn_dust(Vector2(-5.4, 16.5), -1.0)
				_spawn_dust(Vector2(5.4, 16.5), 1.0)
			_air_time = 0.0
		else:
			_air_time += delta
			_last_air_vy = _motion_velocity.y
	_was_on_floor = on_floor
	var target_rise := 0.0 if on_floor else clampf(-_motion_velocity.y / 520.0, -1.0, 1.0)
	_air_rise = move_toward(_air_rise, target_rise, delta * 9.0)
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)

	# Kleine Staubwolke bei jedem Schritt.
	var step_sign := signf(sin(_run_phase))
	if on_floor and _move_energy > 0.45 and step_sign != 0.0 and step_sign != _prev_step_sign:
		var facing := -1.0 if flip_h else 1.0
		_spawn_dust(Vector2(-5.4 * step_sign * facing, 16.5), -facing)
	_prev_step_sign = step_sign

func _spawn_dust(local_pos: Vector2, direction: float) -> void:
	if not animate:
		return
	_dust.append({
		"pos": local_pos,
		"vel": Vector2(direction * 14.0, -6.0),
		"life": DUST_DURATION,
	})
	while _dust.size() > 10:
		_dust.remove_at(0)

func _update_dust(delta: float) -> void:
	# Staub bleibt in der Welt liegen, statt mit der Figur mitzuwandern.
	var world_scale := maxf(0.01, absf(get_global_transform().get_scale().x))
	for i in range(_dust.size() - 1, -1, -1):
		var puff: Dictionary = _dust[i]
		var life := float(puff["life"]) - delta
		if life <= 0.0:
			_dust.remove_at(i)
			continue
		var velocity: Vector2 = puff["vel"]
		velocity *= 0.9
		var position: Vector2 = puff["pos"]
		position += velocity * delta - _motion_velocity * delta / world_scale
		puff["life"] = life
		puff["vel"] = velocity
		puff["pos"] = position
		_dust[i] = puff

func _draw_dust() -> void:
	for puff in _dust:
		var t := 1.0 - float(puff["life"]) / DUST_DURATION
		var position: Vector2 = puff["pos"]
		draw_circle(position, 1.2 + t * 2.4, Color(0.86, 0.82, 0.74, 0.45 * (1.0 - t)))

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
	var body_bob := sin(_time * 2.2) * 0.45 * idle + sin(_run_phase * 2.0) * 1.5 * run
	var head_bob := body_bob + sin(_run_phase * 2.0 + 0.35) * 0.75 * run

	# Vorwärtsneigung relativ zur Blickrichtung. Rückwärtslaufen lehnt die
	# Figur entsprechend nach hinten.
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
	# Neigung in Laufrichtung (Weltrichtung, unabhängig von der Blickrichtung).
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

	draw_set_transform(draw_origin, tilt, draw_scale)

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
		LINE_AA
	)
	draw_arc(Vector2(-12.2 + lean_x * 0.5, -1.0 + body_bob + tail_wag * 0.2), 1.8, PI * 0.35, PI * 2.15, 10, fur_dark, 1.2, LINE_AA)

	var outfit_head := Vector2(head_x, -8.2 + head_bob)
	var outfit_neck := Vector2((head_x + lean_x * 0.55) * 0.5, -0.6 + (head_bob + body_bob) * 0.5)
	if outfit_id != "":
		_draw_outfit_back(outfit_head, outfit_neck, maxf(run, air))

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
	# Beim Fallen klappen die Ohren nach oben, beim Steigen legen sie sich an.
	var ear_lift := air * (maxf(0.0, -rise) * 2.4 - maxf(0.0, rise) * 0.9)
	_draw_ear(Vector2(-7.9 + head_x, -14.5 + head_bob + ear_flap), -1.0, fur_dark, snout_color, outline, ear_lift)
	_draw_ear(Vector2(7.9 + head_x, -14.5 + head_bob - ear_flap), 1.0, fur_dark, snout_color, outline, ear_lift)

	# Kleiner Eberbüschel auf dem Kopf.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2.4 + head_x, -16.9 + head_bob),
		Vector2(0.0 + head_x, -20.4 + head_bob),
		Vector2(2.8 + head_x, -16.7 + head_bob),
	]), fur_dark)

	if outfit_id != "":
		_draw_outfit_front(outfit_head, outfit_neck)

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

	# Eberhauer in der gewählten Form.
	_draw_tusks(Vector2(head_x, head_bob), tusk_color)

	# Wangenrouge.
	draw_circle(Vector2(-7.8 + head_x, -6.0 + head_bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))
	draw_circle(Vector2(7.8 + head_x, -6.0 + head_bob), 1.9, Color(1.0, 0.42, 0.52, 0.20))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_dust()
	_draw_blood_particles()

# --- Klassen-Outfits ---
# Jede Klasse trägt ein festes Accessoire. Es sitzt nur an Kopf und Hals,
# damit Fell, Augen, Hose und Lötkolben (Charakter-Tab) unverändert frei
# anpassbar bleiben. Die Farben sind fest und gehören zur Klasse; in
# Team-Modi wird der Stoff stattdessen in der Teamfarbe gezeichnet.

# Stofffarbe des Outfits: ohne Teams die Klassenfarbe, sonst die Teamfarbe.
# shade > 0 dunkelt ab (Schatten, Umrisse), shade < 0 hellt auf (Glanz).
func _cloth(base: Color, shade: float = 0.0) -> Color:
	if team_color.a <= 0.0:
		return base
	var tinted := team_color.darkened(shade) if shade >= 0.0 else team_color.lightened(-shade)
	tinted.a = base.a
	return tinted

func _draw_outfit_back(head: Vector2, neck: Vector2, run: float) -> void:
	match outfit_id:
		"phantom":
			var knot := head + Vector2(-7.6, -6.6)
			var band := _cloth(Color(0.13, 0.13, 0.20, 1.0), 0.15)
			var band_outline := _cloth(Color(0.04, 0.04, 0.08, 1.0), 0.65)
			_draw_ribbon(knot, 12.5, 0.0, run, band, band_outline, 1.8)
			_draw_ribbon(knot + Vector2(0.0, 0.6), 10.0, 1.7, run, band, band_outline, 1.6)
		"klinge":
			var knot := neck + Vector2(-8.0, 1.7)
			var scarf_outline := _cloth(Color(0.40, 0.04, 0.10, 1.0), 0.6)
			_draw_ribbon(knot, 13.0, 0.4, run, _cloth(Color(0.84, 0.12, 0.24, 1.0)), scarf_outline, 2.3)
			_draw_ribbon(knot + Vector2(0.0, 0.8), 10.0, 2.1, run, _cloth(Color(0.72, 0.08, 0.20, 1.0), 0.15), scarf_outline, 2.0)

func _draw_outfit_front(head: Vector2, neck: Vector2) -> void:
	match outfit_id:
		"ignis":
			_draw_welding_goggles(head)
		"volt":
			_draw_volt_cap(head)
		"spore":
			_draw_mushroom_cap(head)
		"nova":
			_draw_wizard_hat(head)
		"klinge":
			_draw_scarf(neck)
		"bastion":
			_draw_hard_hat(head)
		"phantom":
			_draw_ninja_band(head)

# Wehendes Stoffband nach hinten. Im Stand hängt es schlaff herunter, beim
# Laufen weht es fast waagerecht hinter der Figur her.
func _draw_ribbon(start: Vector2, length: float, phase: float, run: float, fill: Color, outline: Color, width: float) -> void:
	var points := PackedVector2Array()
	var drop := lerpf(3.6, 1.0, run)
	var flutter := _time * (4.0 + 8.0 * run) + phase
	for i in range(8):
		var t := float(i) / 7.0
		var wave := sin(flutter - t * 4.2) * t * (0.6 + 0.9 * run)
		points.append(start + Vector2(-t * length, t * drop + wave))
	draw_polyline(points, outline, width + 1.0, LINE_AA)
	draw_polyline(points, fill, width, LINE_AA)

# Streifen, der dem Kopfoval folgt (Stirnband, Brillenband).
func _head_band_points(head: Vector2, dy_top: float, dy_bottom: float, sag: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var top_hw := 10.6 * sqrt(maxf(0.0, 1.0 - pow(dy_top / 9.8, 2.0))) + 0.3
	var bottom_hw := 10.6 * sqrt(maxf(0.0, 1.0 - pow(dy_bottom / 9.8, 2.0))) + 0.3
	for i in range(9):
		var u := lerpf(-1.0, 1.0, float(i) / 8.0)
		var bend := sag * (1.0 - u * u)
		top.append(head + Vector2(u * top_hw, dy_top + bend))
		bottom.append(head + Vector2(u * bottom_hw, dy_bottom + bend))
	bottom.reverse()
	top.append_array(bottom)
	return top

func _draw_closed_polygon(points: PackedVector2Array, fill: Color, outline: Color, width: float) -> void:
	draw_colored_polygon(points, fill)
	var line := PackedVector2Array(points)
	line.append(points[0])
	draw_polyline(line, outline, width, LINE_AA)

# Obere Hälfte eines Ovals als Kappe/Helm/Hut.
func _dome_points(center: Vector2, radius_x: float, radius_y: float, sag: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(17):
		var angle := PI + PI * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	for i in range(1, 8):
		var u := 1.0 - 2.0 * float(i) / 8.0
		points.append(center + Vector2(u * radius_x, sag * (1.0 - u * u)))
	return points

# Phantom: Ninja-Stirnband mit Metallplatte und Knoten am Hinterkopf.
func _draw_ninja_band(head: Vector2) -> void:
	var band := _cloth(Color(0.13, 0.13, 0.20, 1.0), 0.15)
	var band_outline := _cloth(Color(0.04, 0.04, 0.08, 1.0), 0.65)
	_draw_closed_polygon(_head_band_points(head, -8.0, -5.8, 0.6), band, band_outline, 0.7)
	var plate := Rect2(head + Vector2(-2.7, -7.5), Vector2(5.4, 2.5))
	draw_rect(plate, Color(0.78, 0.80, 0.86, 1.0), true)
	draw_rect(plate, band_outline, false, 0.5)
	draw_line(plate.position + Vector2(0.4, 0.35), plate.position + Vector2(plate.size.x - 0.4, 0.35), Color(1.0, 1.0, 1.0, 0.7), 0.4)
	draw_arc(head + Vector2(0.0, -6.2), 0.7, 0.0, PI * 1.5, 8, Color(0.30, 0.32, 0.40, 1.0), 0.45, LINE_AA)
	_draw_ellipse(head + Vector2(-7.6, -6.6), 1.6, 1.4, band, band_outline, 0.6)

# Ignis: Schweißerbrille auf der Stirn.
func _draw_welding_goggles(head: Vector2) -> void:
	var brass := _cloth(Color(0.86, 0.58, 0.22, 1.0))
	var brass_dark := _cloth(Color(0.40, 0.24, 0.08, 1.0), 0.6)
	_draw_closed_polygon(_head_band_points(head, -8.0, -6.6, 0.5), _cloth(Color(0.36, 0.22, 0.14, 1.0), 0.2), _cloth(Color(0.18, 0.10, 0.06, 1.0), 0.65), 0.6)
	draw_line(head + Vector2(-1.0, -7.4), head + Vector2(1.0, -7.4), brass, 1.0, LINE_AA)
	for side: float in [-1.0, 1.0]:
		var lens := head + Vector2(3.5 * side, -7.5)
		_draw_ellipse(lens, 2.7, 2.4, brass, brass_dark, 0.6)
		_draw_ellipse(lens, 1.8, 1.6, Color(0.30, 0.09, 0.04, 1.0), brass_dark, 0.0)
		draw_circle(lens + Vector2(0.0, 0.4), 0.9, Color(1.0, 0.42, 0.10, 0.45))
		draw_circle(lens + Vector2(-0.6, -0.6), 0.5, Color(1.0, 0.85, 0.6, 0.9))

# Volt: Kappe mit Blitz und Schirm nach vorne.
func _draw_volt_cap(head: Vector2) -> void:
	var cap := _cloth(Color(1.0, 0.84, 0.18, 1.0))
	var cap_dark := _cloth(Color(0.86, 0.62, 0.06, 1.0), 0.2)
	var cap_outline := _cloth(Color(0.45, 0.30, 0.04, 1.0), 0.6)
	_draw_closed_polygon(PackedVector2Array([
		head + Vector2(3.0, -7.9),
		head + Vector2(14.6, -7.4),
		head + Vector2(14.2, -5.9),
		head + Vector2(3.0, -6.2),
	]), cap_dark, cap_outline, 0.7)
	_draw_closed_polygon(_dome_points(head + Vector2(0.4, -7.2), 9.9, 5.8, 0.6), cap, cap_outline, 0.8)
	var bolt := PackedVector2Array()
	for p: Vector2 in [Vector2(0.8, -3.4), Vector2(-1.6, 0.5), Vector2(0.0, 0.5), Vector2(-0.8, 3.0), Vector2(1.9, -0.9), Vector2(0.3, -0.9)]:
		bolt.append(head + Vector2(1.0, -10.0) + p * 0.68)
	_draw_closed_polygon(bolt, Color(0.15, 0.20, 0.48, 1.0), Color(0.06, 0.08, 0.22, 1.0), 0.4)
	draw_circle(head + Vector2(0.4, -12.9), 0.9, cap_dark)

# Spore: Giftpilz-Hut mit Tupfen, aus dem ab und zu Sporen aufsteigen.
func _draw_mushroom_cap(head: Vector2) -> void:
	var cap := _cloth(Color(0.42, 0.74, 0.22, 1.0))
	var cap_outline := _cloth(Color(0.16, 0.34, 0.08, 1.0), 0.6)
	var spot := Color(0.93, 0.98, 0.72, 1.0)
	_draw_ellipse(head + Vector2(0.0, -7.2), 12.2, 1.8, Color(0.92, 0.88, 0.70, 1.0), cap_outline, 0.6)
	_draw_closed_polygon(_dome_points(head + Vector2(0.0, -7.6), 12.6, 7.0, 0.5), cap, cap_outline, 0.9)
	draw_circle(head + Vector2(-5.6, -10.2), 1.6, spot)
	draw_circle(head + Vector2(0.6, -12.4), 1.9, spot)
	draw_circle(head + Vector2(6.0, -9.8), 1.4, spot)
	draw_circle(head + Vector2(-1.6, -8.9), 0.9, spot)
	draw_circle(head + Vector2(9.4, -8.4), 0.8, spot)
	for i in range(2):
		var rise := fmod(_time * 3.2 + float(i) * 3.5, 7.0)
		var fade := 1.0 - rise / 7.0
		var pos := head + Vector2(-3.0 + float(i) * 6.5 + sin(_time * 2.0 + float(i)) * 1.2, -15.0 - rise)
		draw_circle(pos, 0.7, Color(0.62, 0.95, 0.35, 0.75 * fade))

# Nova: Zaubererhut mit Stern; um die Spitze kreist ein kleiner Planet.
func _draw_wizard_hat(head: Vector2) -> void:
	var hat := _cloth(Color(0.38, 0.24, 0.76, 1.0))
	var hat_outline := _cloth(Color(0.14, 0.07, 0.32, 1.0), 0.65)
	var gold := Color(0.98, 0.80, 0.30, 1.0)
	_draw_ellipse(head + Vector2(0.0, -7.8), 12.2, 2.3, _cloth(Color(0.29, 0.17, 0.62, 1.0), 0.2), hat_outline, 0.7)
	var wobble := sin(_time * 2.4) * 0.6
	var tip := head + Vector2(-6.4, -18.2 + wobble)
	_draw_closed_polygon(PackedVector2Array([
		head + Vector2(-7.0, -8.4),
		head + Vector2(7.0, -8.4),
		head + Vector2(5.4, -12.6),
		head + Vector2(2.6, -16.0),
		head + Vector2(-1.4, -18.0 + wobble * 0.5),
		tip,
		head + Vector2(-3.6, -15.4 + wobble * 0.3),
		head + Vector2(-5.0, -12.0),
	]), hat, hat_outline, 0.8)
	_draw_closed_polygon(PackedVector2Array([
		head + Vector2(-7.0, -8.4),
		head + Vector2(7.0, -8.4),
		head + Vector2(6.3, -10.2),
		head + Vector2(-6.4, -10.2),
	]), gold, hat_outline, 0.5)
	var star := PackedVector2Array()
	var star_center := head + Vector2(0.8, -13.0)
	for i in range(10):
		var radius := 1.9 if i % 2 == 0 else 0.8
		var angle := -PI * 0.5 + PI * float(i) / 5.0
		star.append(star_center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(star, gold)
	var orbit := _time * 2.6
	var planet := tip + Vector2(cos(orbit) * 3.4, sin(orbit) * 1.5)
	draw_circle(planet, 1.0, Color(0.70, 0.92, 1.0, 1.0))
	draw_circle(planet + Vector2(-0.3, -0.3), 0.4, Color(1.0, 1.0, 1.0, 0.9))

# Klinge: roter Kampfschal um den Hals; die Enden wehen hinterher.
func _draw_scarf(neck: Vector2) -> void:
	var scarf := _cloth(Color(0.84, 0.12, 0.24, 1.0))
	var scarf_outline := _cloth(Color(0.40, 0.04, 0.10, 1.0), 0.6)
	_draw_closed_polygon(PackedVector2Array([
		neck + Vector2(-9.4, 0.3),
		neck + Vector2(0.0, 1.0),
		neck + Vector2(9.4, 0.3),
		neck + Vector2(9.8, 2.6),
		neck + Vector2(0.0, 3.6),
		neck + Vector2(-9.8, 2.6),
	]), scarf, scarf_outline, 0.7)
	draw_line(neck + Vector2(-8.6, 1.6), neck + Vector2(8.6, 1.6), _cloth(Color(1.0, 0.55, 0.60, 0.55), -0.45), 0.5, LINE_AA)
	_draw_ellipse(neck + Vector2(-8.0, 1.7), 1.9, 1.6, scarf, scarf_outline, 0.6)

# Bastion: Bauhelm mit Stirnlampe.
func _draw_hard_hat(head: Vector2) -> void:
	var helmet := _cloth(Color(0.24, 0.74, 0.60, 1.0))
	var helmet_light := _cloth(Color(0.52, 0.92, 0.80, 1.0), -0.4)
	var helmet_outline := _cloth(Color(0.07, 0.30, 0.24, 1.0), 0.65)
	_draw_closed_polygon(_dome_points(head + Vector2(0.0, -7.0), 10.0, 6.4, 0.4), helmet, helmet_outline, 0.8)
	_draw_ellipse(head + Vector2(0.0, -12.2), 1.5, 2.4, helmet_light, helmet_outline, 0.5)
	_draw_ellipse(head + Vector2(0.0, -6.9), 12.4, 1.6, helmet.darkened(0.15), helmet_outline, 0.7)
	draw_circle(head + Vector2(0.0, -8.9), 2.6, Color(1.0, 0.95, 0.55, 0.22))
	draw_rect(Rect2(head + Vector2(-1.8, -10.2), Vector2(3.6, 2.4)), Color(0.22, 0.24, 0.27, 1.0), true)
	draw_circle(head + Vector2(0.0, -9.0), 1.0, Color(1.0, 0.95, 0.60, 1.0))

# Hauerformen für die rechte Seite; die linke wird gespiegelt.
func _tusk_points(shape: String) -> Array[PackedVector2Array]:
	match shape:
		"long":
			return [PackedVector2Array([Vector2(5.4, -3.5), Vector2(9.4, -0.2), Vector2(5.0, -1.2)])]
		"saber":
			return [PackedVector2Array([
				Vector2(4.8, -1.3), Vector2(6.6, -2.2), Vector2(7.9, -4.3),
				Vector2(8.8, -7.6), Vector2(7.0, -5.0), Vector2(5.5, -3.2),
			])]
		"double":
			return [
				PackedVector2Array([Vector2(5.3, -3.3), Vector2(7.5, -1.6), Vector2(5.0, -1.3)]),
				PackedVector2Array([Vector2(3.4, -1.8), Vector2(4.7, 0.5), Vector2(2.9, -0.6)]),
			]
		"stub":
			return [PackedVector2Array([Vector2(5.4, -3.0), Vector2(6.7, -2.2), Vector2(6.4, -1.4), Vector2(5.2, -1.3)])]
		_:
			return [PackedVector2Array([Vector2(5.3, -3.3), Vector2(7.5, -1.6), Vector2(5.0, -1.3)])]

func _draw_tusks(offset: Vector2, fill: Color) -> void:
	var edge := fill.darkened(0.45)
	for points in _tusk_points(tusk_shape):
		for side: float in [-1.0, 1.0]:
			var mirrored := PackedVector2Array()
			for point in points:
				mirrored.append(Vector2(point.x * side, point.y) + offset)
			draw_colored_polygon(mirrored, fill)
			mirrored.append(mirrored[0])
			draw_polyline(mirrored, edge, 0.35, LINE_AA)

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
			draw_line(position - tail, position, blood_dark, maxf(0.7, size * 0.8), LINE_AA)
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
	draw_line(Vector2(x_offset, top + 2.2), Vector2(x_offset, bottom - 0.6), outline, 0.8, LINE_AA)

func _draw_ear(base: Vector2, direction: float, outer: Color, inner: Color, outline: Color, tip_lift: float = 0.0) -> void:
	var outer_points := PackedVector2Array([
		base + Vector2(-2.2 * direction, 1.6),
		base + Vector2(4.4 * direction, -4.2 - tip_lift),
		base + Vector2(5.0 * direction, 2.7),
	])
	draw_colored_polygon(outer_points, outer)
	outer_points.append(outer_points[0])
	draw_polyline(outer_points, outline, 1.0, LINE_AA)

	var inner_points := PackedVector2Array([
		base + Vector2(-0.8 * direction, 1.0),
		base + Vector2(3.2 * direction, -2.4 - tip_lift * 0.7),
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
		LINE_AA
	)

func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, fill: Color, outline: Color, outline_width: float) -> void:
	var points := _ellipse_points(center, radius_x, radius_y, 24)
	draw_colored_polygon(points, fill)
	if outline_width > 0.0 and outline.a > 0.0:
		var line_points := PackedVector2Array(points)
		line_points.append(points[0])
		draw_polyline(line_points, outline, outline_width, LINE_AA)

func _ellipse_points(center: Vector2, radius_x: float, radius_y: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points
