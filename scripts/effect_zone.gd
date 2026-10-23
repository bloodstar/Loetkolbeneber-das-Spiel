class_name EffectZone
extends Node2D

# Boden-/Flächeneffekt für Gift, Feuer, Eis und Blitz.
# Der Host simuliert Schaden und Status. Auf dem Client existiert die Zone nur
# als visuelle Replik.

enum Kind {
	POISON,
	FIRE,
	ICE,
	LIGHTNING
}

var kind: Kind = Kind.POISON
var owner_player: Player = null
var target: Player = null
var radius: float = 45.0
var duration: float = 3.0
var tick_interval: float = 0.55
var damage: float = 0.0
var poison_stacks: int = 2
var poison_damage: float = 4.0
var burn_stacks: int = 3
var burn_damage: float = 5.0
var freeze_duration: float = 1.2
var stun_duration: float = 0.25
var is_replica: bool = false

var _elapsed: float = 0.0
var _tick_timer: float = 0.0

func _ready() -> void:
	z_index = -2
	add_to_group("effect_zone")
	queue_redraw()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	modulate.a = clampf(1.0 - maxf(0.0, _elapsed - duration + 0.45) / 0.45, 0.0, 1.0)

	if is_replica:
		if _elapsed >= duration:
			queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()

	if _elapsed >= duration:
		queue_free()

func _apply_tick() -> void:
	if not is_instance_valid(target) or target.current_health <= 0.0:
		return
	if global_position.distance_to(target.global_position) > radius + 12.0:
		return

	match kind:
		Kind.POISON:
			target.apply_poison(poison_stacks, poison_damage)
		Kind.FIRE:
			target.apply_burn(burn_stacks, burn_damage)
		Kind.ICE:
			target.apply_freeze(freeze_duration)
		Kind.LIGHTNING:
			if damage > 0.0:
				target.take_damage(damage, Vector2.ZERO, owner_player)
			target.apply_stun(stun_duration)

func _draw() -> void:
	var fill := Color(0.8, 0.8, 0.8, 0.22)
	var rim := Color(0.9, 0.9, 0.9, 0.65)
	match kind:
		Kind.POISON:
			fill = Color(0.25, 0.95, 0.20, 0.20)
			rim = Color(0.35, 1.0, 0.25, 0.65)
		Kind.FIRE:
			fill = Color(1.0, 0.35, 0.05, 0.22)
			rim = Color(1.0, 0.55, 0.10, 0.70)
		Kind.ICE:
			fill = Color(0.35, 0.75, 1.0, 0.20)
			rim = Color(0.60, 0.90, 1.0, 0.65)
		Kind.LIGHTNING:
			fill = Color(1.0, 0.85, 0.15, 0.18)
			rim = Color(1.0, 0.95, 0.35, 0.75)

	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, rim, 2.0)
