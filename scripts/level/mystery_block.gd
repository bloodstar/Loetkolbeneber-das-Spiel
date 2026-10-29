class_name MysteryBlock
extends StaticBody2D

var is_used: bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var base_pos: Vector2 = position

func _ready() -> void:
	pass

func hit_block(instigator: Node2D = null) -> void:
	if is_used:
		return
	is_used = true
	_play_used_visual()

	# Reward instigator or spawn buff
	if is_instance_valid(instigator):
		if instigator.has_method("heal"):
			instigator.heal(30)
		elif instigator.get("shooter") and is_instance_valid(instigator.shooter) and instigator.shooter.has_method("heal"):
			instigator.shooter.heal(30)

# Client: Der Host meldet den Block im Snapshot als benutzt.
func apply_used_from_network() -> void:
	if is_used:
		return
	is_used = true
	_play_used_visual()

func _play_used_visual() -> void:
	SoundManager.play_sound("mystery", 0.05, 0.0)
	# Bump animation
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", -8.0, 0.08)
	tw.tween_property(sprite, "position:y", 0.0, 0.12)
	tw.parallel().tween_property(sprite, "modulate", Color(0.6, 0.6, 0.6), 0.12)
