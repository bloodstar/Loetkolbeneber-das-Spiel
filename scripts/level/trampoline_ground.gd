class_name TrampolineGround
extends Area2D

## Flauschiger Trampolinboden. Er sitzt auf einer normalen Kachel und schleudert
## Spieler beim Landen nach oben. Die Fläche bleibt begehbar, weil sie nur ein
## Sensor ist.

@export var overlay_texture: Texture2D
@export var bounce_force: float = -690.0

@onready var sprite: Sprite2D = $Sprite2D

var _bounce_cooldowns: Dictionary = {}

func _ready() -> void:
	if overlay_texture:
		sprite.texture = overlay_texture
		var width := maxf(1.0, float(overlay_texture.get_width()))
		sprite.scale = Vector2.ONE * (36.0 / width)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_to_group("net_fx_static")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	for key in _bounce_cooldowns.keys():
		_bounce_cooldowns[key] = maxf(0.0, float(_bounce_cooldowns[key]) - delta)

func _on_body_exited(body: Node2D) -> void:
	if body:
		_bounce_cooldowns.erase(body.get_instance_id())

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or not body.has_method("apply_trampoline_bounce"):
		return
	if body.velocity.y < -35.0:
		return
	var id := body.get_instance_id()
	if float(_bounce_cooldowns.get(id, 0.0)) > 0.0:
		return
	_bounce_cooldowns[id] = 0.18
	body.apply_trampoline_bounce(bounce_force)
	_play_bounce()
	NetFx.send("static", NetFx.static_args(self, "bounce"))

# Client: Der Host meldet einen Sprung auf dem Trampolin.
func play_network_fx(_method: String) -> void:
	_play_bounce()

func _play_bounce() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(sprite.scale.x * 1.12, sprite.scale.y * 0.72), 0.07)
	tween.tween_property(sprite, "scale", sprite.scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
