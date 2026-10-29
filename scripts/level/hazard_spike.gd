class_name HazardSpike
extends Area2D

func _ready() -> void:
	add_to_group("hazard_spike")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("take_damage"):
		body.take_damage(25.0, Vector2(0, -350.0))
		NetFx.emit(get_parent(), "sound", {"snd": ["hit", 0.2, 0.0]})
