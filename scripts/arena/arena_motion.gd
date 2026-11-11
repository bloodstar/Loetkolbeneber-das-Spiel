class_name ArenaMotion
extends RefCounted

# Bewegung im Arena-Modus. Player.gd ruft diese Funktionen nur auf, wenn
# ArenaMode.active ist. velocity bleibt die 2D-Bodengeschwindigkeit (x und y
# sind jetzt beide horizontal), die Höhe läuft über player.arena_z/arena_vz.

# Fußfläche relativ zur Kollisionsbox (etwas kleiner, damit man an Kanten
# nicht an Nachbarzellen "hängen" bleibt).
const FOOT_SCALE: float = 0.7

static func foot_half(p: Player) -> Vector2:
	var half := Vector2(9, 11)
	if p.collision_shape and p.collision_shape.shape is RectangleShape2D:
		half = (p.collision_shape.shape as RectangleShape2D).size * 0.5
	return half * absf(p.scale.x) * FOOT_SCALE

## Schwerkraft auf die Höhe, Landen, Herunterfallen von Kanten und die
## passende Kollisionsmaske für die Höhen-Schichten.
static func vertical_step(p: Player, delta: float) -> void:
	var grid := ArenaMode.grid
	var pos := p.global_position
	var half := foot_half(p)
	var support := 0.0
	if grid:
		support = grid.support_height(pos, p.arena_z, half, ArenaMode.STEP_UP, ArenaMode.RAMP_SIDE_STEP)
	if p.arena_grounded:
		# Kleine Absätze (Rampe abwärts) bleiben am Boden, höhere Kanten: fallen.
		if support < p.arena_z - ArenaMode.STEP_UP:
			# Über die Kante gelaufen: fallen.
			p.arena_grounded = false
			p.arena_vz = 0.0
		else:
			p.arena_z = support
			p.jumps_remaining = p.max_jumps
	if not p.arena_grounded:
		var grav := Player.GRAVITY * ArenaMode.Z_GRAVITY_MULT * p.gravity_mult
		# Standfläche aus der Höhe VOR dem Schritt: Auch bei schnellem Fall
		# wird eine durchquerte Oberkante sicher als Landung erkannt.
		if grid:
			support = grid.support_height(pos, maxf(p.arena_z, 0.0), half, 2.0)
		p.arena_vz -= grav * delta
		p.arena_z += p.arena_vz * delta
		# Decke (Steg darüber): Kopf stößt an.
		if grid and p.arena_vz > 0.0:
			var ceil_z := grid.ceiling_height(pos, p.arena_z - p.arena_vz * delta, half)
			if p.arena_z + ArenaMode.BODY_H > ceil_z:
				p.arena_z = maxf(support, ceil_z - ArenaMode.BODY_H)
				p.arena_vz = 0.0
		if p.arena_z <= support and p.arena_vz <= 0.0:
			p.arena_z = support
			p.arena_vz = 0.0
			p.arena_grounded = true
			p.jumps_remaining = p.max_jumps
	update_masks(p)

static func update_masks(p: Player) -> void:
	p.collision_mask = ArenaMode.with_bands(p.collision_mask, ArenaMode.body_band_mask(p.arena_z))

## Sprung: am Boden voll, in der Luft mit Luftsprüngen (Karten) etwas schwächer.
static func jump(p: Player) -> void:
	if p.arena_grounded:
		p.arena_vz = -p.jump_force
		p.arena_grounded = false
		p._fx("sound", {"snd": ["jump", 0.08, 0.0], "x": p.player_index})
	elif p.jumps_remaining > 0:
		p.jumps_remaining -= 1
		p.arena_vz = -p.jump_force * 0.9
		p._fx("sound", {"snd": ["jump_air", 0.08, 0.0], "x": p.player_index})

## Sprungtaste losgelassen: Sprung abkürzen (wie in der Seitenansicht).
static func cut_jump(p: Player) -> void:
	if p.arena_vz > 0.0:
		p.arena_vz *= 0.5

## Laufen in 8 Richtungen. Gleiche Beschleunigung/Bremse wie die
## Seitenansicht, nur auf beiden Achsen.
static func apply_planar(p: Player, input: Vector2) -> void:
	if input.length() > 1.0:
		input = input.normalized()
	var spd := p._current_ground_speed()
	var accel := 0.25
	var decel := 0.2
	if not p.arena_grounded:
		accel = 0.18
		decel = 0.06
	var kb := p._knockback_control_scale()
	if input != Vector2.ZERO:
		p.velocity = p.velocity.move_toward(input * spd, spd * accel * kb)
	else:
		p.velocity = p.velocity.move_toward(Vector2.ZERO, spd * decel * kb)

static func input_vector(p: Player) -> Vector2:
	return Vector2(
		Input.get_axis(p._act("left"), p._act("right")),
		Input.get_axis(p._act("up"), p._act("down"))
	)

## Abschusshöhe für Kugeln dieses Spielers.
static func muzzle_height(p: Player) -> float:
	return p.arena_z + ArenaMode.MUZZLE_H * clampf(absf(p.scale.x) / Player.BASE_CHARACTER_SCALE, 0.5, 2.0)
