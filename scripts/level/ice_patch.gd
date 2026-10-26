class_name IcePatch
extends Area2D

# Eisfläche: rein sensorisch. Der Spieler bleibt auf der darunterliegenden
# Plattform stehen, rutscht aber wegen der geänderten Beschleunigung/Reibung.

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
	
	# Dezentes Schimmern, damit Eisflächen gut erkennbar sind.
	var tw = create_tween().set_loops()
	tw.tween_property(sprite, "modulate:a", 0.65, 1.1)
	tw.tween_property(sprite, "modulate:a", 0.95, 1.1)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("add_ice_source"):
		body.add_ice_source(self)

func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("remove_ice_source"):
		body.remove_ice_source(self)
