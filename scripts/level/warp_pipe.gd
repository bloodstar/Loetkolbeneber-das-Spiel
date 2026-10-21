class_name WarpPipe
extends Area2D

@export var target_pipe: WarpPipe
var can_warp: bool = true
var warp_cooldown: float = 1.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not can_warp:
		warp_cooldown -= delta
		if warp_cooldown <= 0.0:
			can_warp = true

func _on_body_entered(body: Node2D) -> void:
	if not can_warp or target_pipe == null:
		return
	if body is CharacterBody2D:
		can_warp = false
		target_pipe.can_warp = false
		warp_cooldown = 1.2
		target_pipe.warp_cooldown = 1.2
		SoundManager.play_sound("dash", 0.3, -4.0)
		body.global_position = target_pipe.global_position + Vector2(0, -28)
		body.velocity = Vector2(0, -250)
		
		# Visual puff effect on both pipes
		_flash_pipe()
		target_pipe._flash_pipe()

func _flash_pipe() -> void:
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color(2.0, 2.0, 2.0), 0.1)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
