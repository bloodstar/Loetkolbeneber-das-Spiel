class_name JumpPad
extends Area2D

@export var launch_force: float = -750.0

@onready var sprite: Sprite2D = $Sprite2D
var is_bouncing: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("apply_jump_pad_boost"):
		body.apply_jump_pad_boost(launch_force)
		_trigger_animation()

func _trigger_animation() -> void:
	if is_bouncing:
		return
	is_bouncing = true
	SoundManager.play_sound("spring", 0.2, -2.0)
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.4, 0.6), 0.08)
	tween.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.12)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_callback(func(): is_bouncing = false)
