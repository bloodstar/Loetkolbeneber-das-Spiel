class_name DeepSnow
extends Area2D

## Tiefschnee: bremst Spieler aus, solange sie auf dem Feld stehen. Die Fläche
## ist ein Sensor; die darunterliegende Kachel bleibt der feste Boden.

@export var overlay_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if overlay_texture:
		sprite.texture = overlay_texture
		var width := maxf(1.0, float(overlay_texture.get_width()))
		sprite.scale = Vector2.ONE * (36.0 / width)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("add_deep_snow_source"):
		body.add_deep_snow_source(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("remove_deep_snow_source"):
		body.remove_deep_snow_source(self)
