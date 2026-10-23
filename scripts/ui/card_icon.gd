class_name CardIcon
extends Control

# Kleines, prozedural gezeichnetes Karten-Icon. Jedes Icon läuft mit vier
# Frames, damit die Karten im Draft und in der Auflösung lebendig wirken.
# Die Form wird aus den Effektfeldern der Karte abgeleitet, nicht aus dem Titel.

const FRAME_COUNT: int = 4
const FRAME_TIME: float = 0.16

var card: CardData = null
var frame: int = 0
var animate: bool = true
var _timer: float = 0.0
var _kind: String = "spark"
var _blocker_drone: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(40, 40)
	set_process(true)
	queue_redraw()

func setup(p_card: CardData, icon_size: float = 40.0, p_animate: bool = true) -> void:
	card = p_card
	custom_minimum_size = Vector2(icon_size, icon_size)
	animate = p_animate
	_kind = _resolve_kind(card)
	_blocker_drone = card != null and (card.blocker_drone_count_add > 0 or card.blocker_drone_heal)
	frame = 0
	_timer = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if not animate or card == null or not is_visible_in_tree():
		return
	_timer += delta
	if _timer >= FRAME_TIME:
		_timer = fmod(_timer, FRAME_TIME)
		frame = (frame + 1) % FRAME_COUNT
		queue_redraw()

func _resolve_kind(c: CardData) -> String:
	if c == null:
		return "spark"
	if c.kamikaze:
		return "bomb"
	if c.tower_enabled or c.tower_auto_spawn or c.tower_follow:
		return "tower"
	if c.drone_count_add > 0 or c.drone_guardian \
			or c.blocker_drone_count_add > 0 or c.blocker_drone_heal:
		return "drone"
	if c.chain_lightning or c.lightning_shot or c.lightning_zone:
		return "lightning"
	if c.poison_impact_cloud or c.poison_trail or c.poison_stacks_add > 0 or c.poison_damage_mult > 1.0:
		return "poison"
	if c.fire_shot or c.fire_impact_zone or c.fire_trail:
		return "fire"
	if c.freeze_duration_add > 0.0 or c.frost_nova or c.frost_trail:
		return "frost"
	if c.block_bomb:
		return "bomb"
	if c.block_heal_zone:
		return "health"
	if _has_block_effect(c):
		return "block"
	if c.lifesteal_percent_add > 0.0:
		return "leech"
	if c.explosion_radius_add > 0.0 or c.cluster_bomblets:
		return "explosion"
	if c.homing_strength_add > 0.0:
		return "homing"
	if c.bounces_add > 0:
		return "bounce"
	if c.piercing_add > 0:
		return "pierce"
	if c.multishot_add > 0:
		return "multishot"
	if c.shield_max_add > 0 or c.shield_regen_mult > 1.0:
		return "shield"
	if c.max_hp_mult > 1.0 or c.max_hp_flat > 0 or c.hp_regen_add > 0.0:
		return "health"
	if c.giant_growth > 0.0:
		return "giant"
	if c.move_speed_mult > 1.0 or c.extra_jumps_add > 0 or c.jump_force_mult > 1.0 or c.body_size_mult < 1.0 or c.gravity_mult < 1.0:
		return "mobility"
	if c.damage_mult > 1.0:
		return "damage"
	if c.fire_rate_mult < 1.0 or c.reload_speed_mult > 1.0 or c.max_ammo_add > 0:
		return "rapid"
	if c.dash_cooldown_mult < 1.0:
		return "dash"
	if c.ability_cooldown_mult < 1.0:
		return "ability"
	return "spark"

func _has_block_effect(c: CardData) -> bool:
	return c.block_duration_add > 0.0 \
		or c.block_cooldown_mult < 1.0 \
		or c.block_reflect_damage_add > 0.0 \
		or c.block_knockback_radius_add > 0.0 \
		or c.block_knockback_force_add > 0.0 \
		or c.block_bomb \
		or c.block_heal_zone

func _alpha(color: Color, alpha: float) -> Color:
	var result := color
	result.a = alpha
	return result

func _draw() -> void:
	if card == null:
		return
	var s := minf(size.x, size.y)
	if s < 4.0:
		return

	var col := card.color
	var c := size * 0.5
	var bob := 0.0
	var pulse := 1.0
	match frame:
		1:
			bob = -0.025
			pulse = 1.06
		3:
			bob = 0.025
			pulse = 0.94
	c.y += bob * s

	# Weicher Hintergrund und ein dezenter Ring in der Effektfarbe.
	draw_circle(c, s * 0.46, _alpha(col, 0.10))
	draw_arc(c, s * 0.44, 0.0, TAU, 28, _alpha(col, 0.26), maxf(1.0, s * 0.02), true)

	match _kind:
		"health":
			_draw_heart(c, s, col, pulse)
		"leech":
			_draw_heart(c, s, col, pulse)
			draw_circle(c + Vector2(0.20, 0.23) * s, 0.055 * s, Color(0.95, 0.25, 0.35))
		"damage":
			_draw_damage(c, s, col)
		"rapid":
			_draw_chevvies(c, s, col, true)
		"projectile":
			_draw_projectile(c, s, col)
		"multishot":
			_draw_multishot(c, s, col)
		"bounce":
			_draw_bounce(c, s, col)
		"homing":
			_draw_homing(c, s, col)
		"pierce":
			_draw_pierce(c, s, col)
		"explosion":
			_draw_explosion(c, s, col)
		"poison":
			_draw_poison(c, s, col)
		"frost":
			_draw_frost(c, s, col)
		"lightning":
			_draw_lightning(c, s, col)
		"fire":
			_draw_fire(c, s, col)
		"shield":
			_draw_shield(c, s, col, false)
		"block":
			_draw_shield(c, s, col, true)
		"mobility":
			_draw_mobility(c, s, col)
		"dash":
			_draw_chevvies(c, s, col, false)
		"giant":
			_draw_giant(c, s, col, pulse)
		"tower":
			_draw_tower(c, s, col)
		"drone":
			_draw_drone(c, s, col)
		"bomb":
			_draw_bomb(c, s, col, pulse)
		"ability":
			_draw_ability(c, s, col)
		_:
			_draw_spark(c, s, col)

func _draw_heart(c: Vector2, s: float, col: Color, pulse: float) -> void:
	var r := 0.115 * s * pulse
	var top := c + Vector2(0.0, -0.07) * s
	draw_circle(top + Vector2(-0.105, 0.0) * s, r, col)
	draw_circle(top + Vector2(0.105, 0.0) * s, r, col)
	var points := PackedVector2Array([
		top + Vector2(-0.215, 0.01) * s,
		top + Vector2(0.215, 0.01) * s,
		c + Vector2(0.0, 0.27) * s,
	])
	draw_colored_polygon(points, col)
	draw_circle(top + Vector2(-0.14, -0.07) * s, r * 0.30, _alpha(Color.WHITE, 0.55))

func _draw_damage(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.8, s * 0.07)
	draw_line(c + Vector2(-0.18, 0.20) * s, c + Vector2(0.17, -0.19) * s, col, w, true)
	draw_line(c + Vector2(0.02, 0.20) * s, c + Vector2(0.21, 0.01) * s, _alpha(col, 0.65), w * 0.8, true)
	draw_line(c + Vector2(-0.20, 0.02) * s, c + Vector2(-0.02, -0.18) * s, _alpha(col, 0.65), w * 0.8, true)
	draw_circle(c + Vector2(0.18, -0.20) * s, 0.05 * s, Color.WHITE)

func _draw_chevvies(c: Vector2, s: float, col: Color, vertical: bool) -> void:
	var w := maxf(1.6, s * 0.055)
	for i in range(3):
		var offset := -0.20 + float((frame + i) % 4) * 0.10
		if vertical:
			var x := -0.18 + i * 0.18
			draw_line(c + Vector2(x, -0.16 + offset) * s, c + Vector2(x, offset) * s, col, w, true)
			draw_line(c + Vector2(x - 0.06, offset - 0.06) * s, c + Vector2(x, offset) * s, col, w, true)
			draw_line(c + Vector2(x, offset) * s, c + Vector2(x + 0.06, offset - 0.06) * s, col, w, true)
		else:
			var y := -0.14 + i * 0.14
			draw_line(c + Vector2(offset, y) * s, c + Vector2(offset + 0.12, y) * s, col, w, true)
			draw_line(c + Vector2(offset + 0.06, y - 0.06) * s, c + Vector2(offset + 0.12, y) * s, col, w, true)
			draw_line(c + Vector2(offset + 0.06, y + 0.06) * s, c + Vector2(offset + 0.12, y) * s, col, w, true)

func _draw_projectile(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.6, s * 0.055)
	var shift := float(frame) * 0.02 * s
	draw_line(c + Vector2(-0.30, 0.0) * s + Vector2(shift, 0.0), c + Vector2(-0.02, 0.0) * s + Vector2(shift, 0.0), _alpha(col, 0.40), w, true)
	draw_circle(c + Vector2(0.10, 0.0) * s + Vector2(shift, 0.0), 0.12 * s, col)
	draw_circle(c + Vector2(0.06, -0.04) * s + Vector2(shift, 0.0), 0.04 * s, _alpha(Color.WHITE, 0.75))
	draw_line(c + Vector2(0.24, 0.0) * s + Vector2(shift, 0.0), c + Vector2(0.34, 0.0) * s + Vector2(shift, 0.0), col, w * 0.8, true)

func _draw_multishot(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.05)
	var bob := float(frame % 2) * 0.03 * s
	for x in [-0.20, 0.0, 0.20]:
		draw_circle(c + Vector2(x, -0.14) * s + Vector2(0.0, bob), 0.06 * s, col)
		draw_line(c + Vector2(x, 0.02) * s + Vector2(0.0, bob), c + Vector2(x, 0.22) * s + Vector2(0.0, bob), _alpha(col, 0.85), w, true)

func _draw_bounce(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.6, s * 0.055)
	draw_circle(c + Vector2(-0.18, 0.14) * s, 0.09 * s, col)
	var points := PackedVector2Array([
		c + Vector2(-0.18, 0.14) * s,
		c + Vector2(-0.04, -0.04) * s,
		c + Vector2(0.10, 0.10) * s,
		c + Vector2(0.24, -0.08) * s,
	])
	draw_polyline(points, _alpha(col, 0.85), w, true)
	draw_line(c + Vector2(0.24, -0.08) * s, c + Vector2(0.15, -0.06) * s, col, w, true)
	draw_line(c + Vector2(0.24, -0.08) * s, c + Vector2(0.22, 0.01) * s, col, w, true)

func _draw_homing(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.05)
	draw_arc(c, 0.23 * s, 0.0, TAU, 24, _alpha(col, 0.45), w, true)
	draw_arc(c, 0.12 * s, 0.0, TAU, 20, _alpha(col, 0.75), w, true)
	var angle := float(frame) * TAU / 4.0
	var dot := c + Vector2(cos(angle), sin(angle)) * 0.27 * s
	draw_line(c, dot, _alpha(col, 0.35), w * 0.7, true)
	draw_circle(dot, 0.065 * s, col)

func _draw_pierce(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.7, s * 0.06)
	draw_rect(Rect2(c + Vector2(-0.08, -0.16) * s, Vector2(0.16, 0.32) * s), _alpha(col, 0.22))
	draw_rect(Rect2(c + Vector2(-0.08, -0.16) * s, Vector2(0.16, 0.32) * s), _alpha(col, 0.65), false, maxf(1.0, s * 0.025))
	draw_line(c + Vector2(-0.31, 0.0) * s, c + Vector2(0.30, 0.0) * s, col, w, true)
	draw_line(c + Vector2(0.30, 0.0) * s, c + Vector2(0.20, -0.08) * s, col, w, true)
	draw_line(c + Vector2(0.30, 0.0) * s, c + Vector2(0.20, 0.08) * s, col, w, true)

func _draw_explosion(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.6, s * 0.055)
	var radius := (0.10 + float(frame) * 0.05) * s
	draw_arc(c, radius, 0.0, TAU, 24, _alpha(col, 0.95 - float(frame) * 0.16), w, true)
	draw_circle(c, 0.07 * s, col)
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + float(frame) * 0.08
		var inner := c + Vector2(cos(angle), sin(angle)) * (0.16 + float(frame) * 0.03) * s
		var outer := c + Vector2(cos(angle), sin(angle)) * (0.25 + float(frame) * 0.04) * s
		draw_line(inner, outer, _alpha(col, 0.8 - float(frame) * 0.12), w * 0.7, true)

func _draw_poison(c: Vector2, s: float, col: Color) -> void:
	draw_circle(c + Vector2(-0.02, 0.13) * s, 0.14 * s, col)
	draw_circle(c + Vector2(-0.06, 0.10) * s, 0.045 * s, _alpha(Color.WHITE, 0.45))
	for i in range(3):
		var rise := fmod(float(frame) + float(i) * 1.35, 4.0)
		var bubble := c + Vector2(-0.18 + float(i) * 0.17, 0.02 - rise * 0.07) * s
		draw_circle(bubble, (0.035 + float(i) * 0.008) * s, _alpha(col.lightened(0.25), 0.85))

func _draw_frost(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.05)
	var base_angle := float(frame) * PI / 8.0
	for i in range(6):
		var dir := Vector2.RIGHT.rotated(base_angle + float(i) * TAU / 6.0)
		draw_line(c, c + dir * 0.26 * s, col, w, true)
		var branch_point := c + dir * 0.15 * s
		draw_line(branch_point, branch_point + dir.rotated(0.7) * 0.08 * s, _alpha(col, 0.8), w * 0.65, true)
		draw_line(branch_point, branch_point + dir.rotated(-0.7) * 0.08 * s, _alpha(col, 0.8), w * 0.65, true)

func _draw_lightning(c: Vector2, s: float, col: Color) -> void:
	var shift := (0.02 if frame % 2 == 0 else -0.02) * s
	var points := PackedVector2Array([
		c + Vector2(-0.05, -0.30) * s + Vector2(shift, 0.0),
		c + Vector2(0.13, -0.30) * s + Vector2(shift, 0.0),
		c + Vector2(0.02, -0.04) * s + Vector2(shift, 0.0),
		c + Vector2(0.17, -0.04) * s + Vector2(shift, 0.0),
		c + Vector2(-0.13, 0.30) * s + Vector2(shift, 0.0),
		c + Vector2(-0.02, 0.05) * s + Vector2(shift, 0.0),
		c + Vector2(-0.18, 0.05) * s + Vector2(shift, 0.0),
	])
	draw_colored_polygon(points, col)

func _draw_fire(c: Vector2, s: float, col: Color) -> void:
	var wobble: float = [-0.03, 0.02, -0.01, 0.03][frame]
	var points := PackedVector2Array([
		c + Vector2(-0.13, 0.24) * s,
		c + Vector2(0.13, 0.24) * s,
		c + Vector2(0.11, 0.03) * s,
		c + Vector2(0.03, -0.10) * s,
		c + Vector2(wobble, -0.29) * s,
		c + Vector2(-0.06, -0.08) * s,
		c + Vector2(-0.13, 0.05) * s,
	])
	draw_colored_polygon(points, col)
	var inner := PackedVector2Array([
		c + Vector2(-0.05, 0.20) * s,
		c + Vector2(0.06, 0.20) * s,
		c + Vector2(0.03, 0.02) * s,
		c + Vector2(-0.02, -0.09) * s,
		c + Vector2(-0.06, 0.03) * s,
	])
	draw_colored_polygon(inner, _alpha(Color.WHITE, 0.45))

func _draw_shield(c: Vector2, s: float, col: Color, square: bool) -> void:
	var w := maxf(1.7, s * 0.06)
	if square:
		var rect := Rect2(c + Vector2(-0.21, -0.21) * s, Vector2(0.42, 0.42) * s)
		draw_rect(rect, _alpha(col, 0.18))
		draw_rect(rect, col, false, w)
		draw_line(c + Vector2(-0.14, 0.0) * s, c + Vector2(0.14, 0.0) * s, _alpha(col, 0.8), w * 0.7, true)
	else:
		var points := PackedVector2Array([
			c + Vector2(-0.19, -0.23) * s,
			c + Vector2(0.19, -0.23) * s,
			c + Vector2(0.23, -0.08) * s,
			c + Vector2(0.0, 0.29) * s,
			c + Vector2(-0.23, -0.08) * s,
			c + Vector2(-0.19, -0.23) * s,
		])
		draw_colored_polygon(PackedVector2Array([
			points[0], points[1], points[2], points[3], points[4],
		]), _alpha(col, 0.20))
		draw_polyline(points, col, w, true)
		draw_line(c + Vector2(0.0, -0.13) * s, c + Vector2(0.0, 0.14) * s, _alpha(col, 0.75), w * 0.75, true)

func _draw_mobility(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.6, s * 0.055)
	var bob: float = [-0.03, -0.06, -0.03, 0.0][frame] * s
	draw_line(c + Vector2(0.0, 0.23) * s + Vector2(0.0, bob), c + Vector2(0.0, -0.22) * s + Vector2(0.0, bob), col, w, true)
	draw_line(c + Vector2(0.0, -0.22) * s + Vector2(0.0, bob), c + Vector2(-0.11, -0.10) * s + Vector2(0.0, bob), col, w, true)
	draw_line(c + Vector2(0.0, -0.22) * s + Vector2(0.0, bob), c + Vector2(0.11, -0.10) * s + Vector2(0.0, bob), col, w, true)
	draw_line(c + Vector2(-0.29, -0.10) * s, c + Vector2(-0.18, -0.10) * s, _alpha(col, 0.55), w * 0.7, true)
	draw_line(c + Vector2(-0.29, 0.06) * s, c + Vector2(-0.18, 0.06) * s, _alpha(col, 0.55), w * 0.7, true)
	draw_line(c + Vector2(0.18, -0.10) * s, c + Vector2(0.29, -0.10) * s, _alpha(col, 0.55), w * 0.7, true)
	draw_line(c + Vector2(0.18, 0.06) * s, c + Vector2(0.29, 0.06) * s, _alpha(col, 0.55), w * 0.7, true)

func _draw_giant(c: Vector2, s: float, col: Color, pulse: float) -> void:
	draw_circle(c, 0.15 * s * pulse, col)
	var w := maxf(1.5, s * 0.05)
	for i in range(4):
		var dir := Vector2.RIGHT.rotated(float(i) * TAU / 4.0 + PI / 4.0)
		draw_line(c + dir * 0.20 * s, c + dir * 0.31 * s, col, w, true)
		draw_line(c + dir * 0.31 * s, c + dir.rotated(0.5) * 0.26 * s, col, w, true)
		draw_line(c + dir * 0.31 * s, c + dir.rotated(-0.5) * 0.26 * s, col, w, true)

func _draw_tower(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.5, s * 0.05)
	draw_rect(Rect2(c + Vector2(-0.13, 0.03) * s, Vector2(0.26, 0.23) * s), col)
	draw_line(c + Vector2(0.0, 0.03) * s, c + Vector2(0.0, -0.15) * s, col, w * 1.2, true)
	var angle := (float(frame) - 1.5) * 0.24
	var dir := Vector2.RIGHT.rotated(angle)
	draw_line(c + Vector2(0.0, -0.15) * s, c + Vector2(0.0, -0.15) * s + dir * 0.19 * s, col, w * 1.3, true)
	draw_circle(c + Vector2(0.0, -0.15) * s, 0.06 * s, col)

func _draw_drone(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.4, s * 0.045)
	draw_circle(c, 0.12 * s, col)
	draw_arc(c, 0.23 * s, 0.0, TAU, 24, _alpha(col, 0.40), w, true)
	if _blocker_drone:
		# Schutzdrohnen erhalten einen zweiten, unterbrochenen Schutzring.
		for i in range(4):
			var start := float(i) * TAU / 4.0 + float(frame) * PI / 16.0
			draw_arc(c, 0.32 * s, start, start + TAU / 6.0, 10, _alpha(col, 0.85), w * 1.15, true)
	var angle := float(frame) * TAU / 4.0
	var dot := c + Vector2(cos(angle), sin(angle)) * 0.24 * s
	draw_circle(dot, 0.055 * s, Color.WHITE)
	draw_line(c + Vector2(-0.05, -0.04) * s, c + Vector2(-0.15, -0.12) * s, _alpha(col, 0.8), w, true)
	draw_line(c + Vector2(0.05, -0.04) * s, c + Vector2(0.15, -0.12) * s, _alpha(col, 0.8), w, true)

func _draw_bomb(c: Vector2, s: float, col: Color, pulse: float) -> void:
	var w := maxf(1.5, s * 0.05)
	draw_circle(c + Vector2(0.0, 0.06) * s, 0.19 * s * pulse, col)
	draw_line(c + Vector2(0.10, -0.11) * s, c + Vector2(0.20, -0.24) * s, _alpha(col, 0.9), w, true)
	var spark := (0.035 + float(frame % 2) * 0.015) * s
	draw_circle(c + Vector2(0.21, -0.25) * s, spark, Color(1.0, 0.85, 0.3))
	draw_circle(c + Vector2(-0.06, 0.0) * s, 0.04 * s, _alpha(Color.WHITE, 0.55))

func _draw_ability(c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.6, s * 0.055)
	var sweep := -PI / 2.0 + float(frame + 1) * TAU / 4.0
	draw_arc(c, 0.23 * s, -PI / 2.0, sweep, 24, col, w, true)
	draw_circle(c, 0.065 * s, col)
	for i in range(4):
		var angle := float(i) * TAU / 4.0 + float(frame) * PI / 8.0
		draw_circle(c + Vector2(cos(angle), sin(angle)) * 0.12 * s, 0.025 * s, _alpha(col, 0.8))

func _draw_spark(c: Vector2, s: float, col: Color) -> void:
	var base_angle := float(frame) * PI / 8.0
	var points := PackedVector2Array()
	for i in range(8):
		var angle := base_angle + float(i) * TAU / 8.0
		var radius := 0.27 if i % 2 == 0 else 0.10
		points.append(c + Vector2(cos(angle), sin(angle)) * radius * s)
	draw_colored_polygon(points, col)
