class_name RubberWall
extends Area2D

# Gummiwand außerhalb der Karte. Wer hineingerät, nimmt Schaden und wird mit
# Nachdruck zurück in Richtung Kartenmitte geschleudert.

@export var inner_rect: Rect2 = Rect2()
@export var damage: float = 10.0
@export var push_force: float = 950.0
@export var damage_interval: float = 0.45
@export var safe_margin: float = 240.0

var _damage_timers: Dictionary = {}

func _ready() -> void:
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if inner_rect.size == Vector2.ZERO:
		return
	var center := inner_rect.get_center()
	for body in get_overlapping_bodies():
		if not (body is CharacterBody2D) or not body.has_method("take_damage"):
			continue
		var to_center: Vector2 = center - body.global_position
		if to_center.length_squared() < 1.0:
			continue
		var dir := to_center.normalized()
		
		# Direkte Rückführung + Geschwindigkeit: wirkt auch gegen gehaltene
		# Eingaben in Richtung Kartenrand.
		body.global_position += dir * push_force * 0.65 * delta
		body.velocity = body.velocity.lerp(dir * push_force, 0.6)
		
		var id := body.get_instance_id()
		var t := float(_damage_timers.get(id, 0.0)) - delta
		if t <= 0.0:
			body.take_damage(damage, dir * 140.0)
			_damage_timers[id] = damage_interval
			SoundManager.play_sound("bounce", 0.15, -2.0)
			if not is_instance_valid(body):
				continue
		else:
			_damage_timers[id] = t
		
		# Sicherheitsnetz: nicht beliebig weit aus der Karte entkommen.
		var safe := inner_rect.grow(safe_margin)
		if not safe.has_point(body.global_position):
			body.global_position = body.global_position.clamp(safe.position, safe.end)

func _on_body_exited(body: Node2D) -> void:
	if body:
		_damage_timers.erase(body.get_instance_id())
