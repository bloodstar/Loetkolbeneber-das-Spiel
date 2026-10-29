class_name PhysicsImpact
extends RefCounted

## Kontaktschaden schwerer Physikobjekte (Kisten, Fässer, Kugeln) an Spielern.
## Gezählt wird, wie schnell sich das Objekt vor dem Physikschritt auf den
## Spieler zubewegt hat, abzüglich der Fluchtbewegung des Spielers. Wer auf
## einem Objekt steht, darauf landet oder dagegen läuft, nimmt so keinen
## Schaden: Das Objekt bewegt sich dabei nicht auf ihn zu.
##
## Die Objekte rufen check_players() in ihrem _physics_process auf, bevor sie
## ihre Geschwindigkeit für den nächsten Schritt merken. get_colliding_bodies()
## liefert dann die Kontakte des letzten Schritts, velocity_before die
## Geschwindigkeit davor. Das erfasst auch Kontakte, für die body_entered
## nicht feuert (bereits bestehender Kontakt, volle Kontaktliste).

const MIN_SPEED: float = 170.0
const SPEED_OFFSET: float = 140.0
const SPEED_PER_DAMAGE: float = 11.0
const MIN_DAMAGE: float = 5.0
const MAX_KNOCKBACK: float = 640.0
const COOLDOWN: float = 0.6

static func tick_cooldowns(cooldowns: Dictionary, delta: float) -> void:
	for key in cooldowns.keys():
		var left := float(cooldowns[key]) - delta
		if left <= 0.0:
			cooldowns.erase(key)
		else:
			cooldowns[key] = left

## Schaden = (Annäherung - 140) / 11 * damage_mult, mindestens 5, höchstens
## max_damage. Liefert die Zahl der getroffenen Spieler.
static func check_players(body: RigidBody2D, velocity_before: Vector2, cooldowns: Dictionary,
		damage_mult: float, max_damage: float, knockback_mult: float, source: Node) -> int:
	if not body.contact_monitor:
		return 0
	var hits := 0
	for other in body.get_colliding_bodies():
		var player := other as Player
		if player == null or player.current_health <= 0.0 or player.is_invulnerable:
			continue
		var key := player.get_instance_id()
		if cooldowns.has(key):
			continue
		var offset := player.global_position - body.global_position
		if offset.length_squared() < 0.01:
			continue
		var dir := offset.normalized()
		# Wer obendrauf steht, wird mitgetragen (Wippe schleudert die Kiste
		# hoch, Kugel rollt unter den Füßen): kein Schaden.
		if dir.y < -0.7 and player.is_on_floor():
			continue
		var approach := velocity_before.dot(dir)
		if approach < MIN_SPEED:
			continue
		var closing := approach - maxf(0.0, player.velocity.dot(dir))
		if closing < MIN_SPEED:
			continue
		cooldowns[key] = COOLDOWN
		var damage := clampf((closing - SPEED_OFFSET) / SPEED_PER_DAMAGE * damage_mult, MIN_DAMAGE, max_damage)
		var push := dir * minf(closing * 0.55 * knockback_mult, MAX_KNOCKBACK) + Vector2(0.0, -150.0)
		var src: Node = source if is_instance_valid(source) else null
		player.take_damage(damage, push, src)
		SoundManager.play_sound("hit", 0.28, 1.0)
		hits += 1
	return hits
