class_name SpaceMotion
extends RefCounted

## Schwerelosigkeit (Weltraum-Maps, Profil "zero_g"): keine Schwerkraft,
## Steuerung in alle Richtungen mit Düsen (WASD bzw. Pfeiltasten). Man
## treibt weiter, bis man bremst oder irgendwo anstößt. Springen ist ein
## Schubstoß in Laufrichtung (ohne Eingabe in Zielrichtung). Schübe laden
## bei Kontakt mit einer Fläche sofort und sonst mit der Zeit nach, die
## Anzahl ist wie in der Seitenansicht 1 + Extrasprünge.

# Zielgeschwindigkeit der Düsen relativ zum Lauftempo.
const THRUST_SPEED_MULT: float = 1.0
# Beschleunigung in Lauftempo pro Sekunde.
const THRUST_ACCEL: float = 2.6
# Bremsen, wenn man schneller ist als die Düsen (Schub, Rückstoß).
const OVERSPEED_DECEL: float = 0.9
# Ohne Eingabe: sehr leichtes Abbremsen, man treibt lange weiter.
const DRIFT_DECEL: float = 0.3
const BOOST_MULT: float = 0.8
const BOOST_RECHARGE: float = 1.1
const MAX_SPEED_MULT: float = 2.6

static func apply_thrust(p: Player, input: Vector2, delta: float) -> void:
	if input.length() > 1.0:
		input = input.normalized()
	var spd := p._current_ground_speed()
	var kb := p._knockback_control_scale()
	var target := input * spd * THRUST_SPEED_MULT
	if input == Vector2.ZERO:
		p.velocity = p.velocity.move_toward(Vector2.ZERO, spd * DRIFT_DECEL * delta * kb)
	elif p.velocity.length() > target.length() and p.velocity.dot(target) > 0.0:
		# Schneller als die Düsen in dieselbe Richtung: langsam abbauen, aber
		# sofort lenken können.
		var along := p.velocity.project(target.normalized())
		var side := p.velocity - along
		along = along.move_toward(target, spd * OVERSPEED_DECEL * delta * kb)
		side = side.move_toward(Vector2.ZERO, spd * THRUST_ACCEL * delta * kb)
		p.velocity = along + side
	else:
		p.velocity = p.velocity.move_toward(target, spd * THRUST_ACCEL * delta * kb)
	var cap := spd * MAX_SPEED_MULT
	if p.velocity.length() > cap:
		p.velocity = p.velocity.normalized() * cap

## Pro Physikschritt statt der Schwerkraft: Schübe nachladen.
static func step(p: Player, delta: float) -> void:
	if p.is_on_floor() or p.is_on_wall() or p.is_on_ceiling():
		p.jumps_remaining = p.max_jumps
		p.set_meta("space_boost_t", 0.0)
		return
	if p.jumps_remaining >= p.max_jumps:
		return
	var t := float(p.get_meta("space_boost_t", 0.0)) + delta
	if t >= BOOST_RECHARGE:
		t = 0.0
		p.jumps_remaining += 1
	p.set_meta("space_boost_t", t)

## Sprungtaste: Schubstoß. Richtung = Eingabe, sonst Zielrichtung.
static func boost(p: Player, input: Vector2) -> void:
	if p.jumps_remaining <= 0:
		return
	p.jumps_remaining -= 1
	var dir := input.normalized() if input.length() > 0.2 else p.aim_direction.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	var power := absf(p.jump_force) * BOOST_MULT
	# Gegen die bisherige Bewegung wirkt der Stoß voll, sonst addiert er sich.
	var along := p.velocity.dot(dir)
	if along < 0.0:
		p.velocity -= dir * along
	p.velocity += dir * power
	var cap := p._current_ground_speed() * MAX_SPEED_MULT
	if p.velocity.length() > cap:
		p.velocity = p.velocity.normalized() * cap
	p._fx("sound", {"snd": ["jump_air", 0.1, -2.0], "x": p.player_index})
