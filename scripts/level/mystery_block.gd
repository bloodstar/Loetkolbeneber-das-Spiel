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
	SoundManager.play_sound("confirm", 0.2, 2.0)
	
	# Bump animation
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", -8.0, 0.08)
	tw.tween_property(sprite, "position:y", 0.0, 0.12)
	tw.parallel().tween_property(sprite, "modulate", Color(0.6, 0.6, 0.6), 0.12)
	
	# Reward instigator or spawn buff
	if instigator and instigator.has_method("heal"):
		instigator.heal(30)
	elif instigator and instigator.get("shooter") and instigator.shooter.has_method("heal"):
		instigator.shooter.heal(30)
