class_name SpecialTile
extends StaticBody2D

# Zerstörbare Tiles und Ranken.
# - DESTRUCTIBLE: bricht nach mehreren Treffern dauerhaft.
# - STRONG_VINE: stabile Rankenplattform, bricht nur durch Beschuss und wächst nach.
# - WEAK_VINE: bricht beim Darübergehen und wächst nach kurzer Zeit nach.

signal broken(tile_id: int)
signal regrown(tile_id: int)

enum Kind { DESTRUCTIBLE, STRONG_VINE, WEAK_VINE }

# Ranken-Effekte bewusst leiser als Waffen und Treffer.
const VINE_EFFECT_VOLUME_DB: float = -6.0

@export var tile_id: int = 0
@export var kind: int = Kind.DESTRUCTIBLE
@export var tile_texture: Texture2D
@export var destructible_health: int = 3
@export var regrow_time: float = 0.0

var health: int = 3
var is_broken: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var step_sensor: Area2D = $StepSensor
@onready var step_shape: CollisionShape2D = $StepSensor/CollisionShape2D

var regrow_timer: Timer
var grace_timer: Timer
var step_timer: Timer
var _base_sprite_scale: Vector2 = Vector2(2.0, 2.0)

func _ready() -> void:
	if tile_texture:
		sprite.texture = tile_texture
		var width := maxf(1.0, float(tile_texture.get_width()))
		_base_sprite_scale = Vector2.ONE * (36.0 / width)
		sprite.scale = _base_sprite_scale
		if width >= 36.0:
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	
	# Timer zuerst anlegen, damit das Step-Signal sie sicher verwenden kann.
	regrow_timer = Timer.new()
	regrow_timer.one_shot = true
	regrow_timer.timeout.connect(_on_regrow_timeout)
	add_child(regrow_timer)
	
	grace_timer = Timer.new()
	grace_timer.one_shot = true
	add_child(grace_timer)
	
	step_timer = Timer.new()
	step_timer.one_shot = true
	step_timer.timeout.connect(_on_step_delay_timeout)
	add_child(step_timer)
	
	match kind:
		Kind.DESTRUCTIBLE:
			health = maxi(1, destructible_health)
			regrow_time = 0.0
			step_sensor.monitoring = false
		Kind.STRONG_VINE:
			health = 1
			regrow_time = maxf(regrow_time, 7.0)
			step_sensor.monitoring = false
		Kind.WEAK_VINE:
			health = 1
			regrow_time = maxf(regrow_time, 4.0)
			step_sensor.body_entered.connect(_on_step_body_entered)

func hit_tile(_amount: float = 0.0) -> void:
	if is_broken:
		return
	health -= 1
	if health <= 0:
		break_tile()
	else:
		_flash_hit()

func _flash_hit() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(2.0, 1.4, 1.0), 0.06)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func _on_step_body_entered(body: Node2D) -> void:
	if is_broken or kind != Kind.WEAK_VINE:
		return
	if grace_timer and grace_timer.time_left > 0.0:
		return
	if step_timer and step_timer.time_left > 0.0:
		return
	if body is CharacterBody2D:
		# Kurze Verzögerung, damit der Spieler noch auf das Tile treten kann.
		step_timer.start(0.10)

func _on_step_delay_timeout() -> void:
	if not is_broken and kind == Kind.WEAK_VINE:
		break_tile()

func break_tile(from_network: bool = false, start_regrow: bool = true) -> void:
	if is_broken:
		return
	is_broken = true
	collision_shape.set_deferred("disabled", true)
	step_shape.set_deferred("disabled", true)
	_animate_break()
	if start_regrow and regrow_time > 0.0:
		regrow_timer.start(regrow_time)
	if not from_network:
		broken.emit(tile_id)

func _animate_break() -> void:
	if kind == Kind.WEAK_VINE:
		SoundManager.play_sound("poison", 0.15, VINE_EFFECT_VOLUME_DB)
	else:
		SoundManager.play_sound("bounce", 0.15, VINE_EFFECT_VOLUME_DB)
	sprite.scale = _base_sprite_scale
	var tw = create_tween()
	tw.tween_property(sprite, "scale", _base_sprite_scale * Vector2(1.25, 0.15), 0.12)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	tw.tween_callback(func(): sprite.visible = false)

func _on_regrow_timeout() -> void:
	regrow_tile(false)

func regrow_tile(from_network: bool = false) -> void:
	if not is_broken:
		return
	# Nicht direkt unter einem Spieler nachwachsen. Dann kurz warten.
	if kind == Kind.WEAK_VINE:
		for player in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(player) and player is Node2D:
				if player.global_position.distance_to(global_position) < 42.0:
					regrow_timer.start(0.8)
					return
	is_broken = false
	sprite.visible = true
	sprite.modulate = Color.WHITE
	sprite.scale = _base_sprite_scale * Vector2(0.1, 1.0)
	var tw = create_tween()
	tw.tween_property(sprite, "scale", _base_sprite_scale, 0.18)
	collision_shape.set_deferred("disabled", false)
	step_shape.set_deferred("disabled", false)
	if kind == Kind.WEAK_VINE:
		grace_timer.start(0.9)
	if not from_network:
		regrown.emit(tile_id)

# Wird auf dem Client angewendet, wenn der Host ein Tile zerstört/nachwachsen lässt.
func apply_network_break() -> void:
	break_tile(true, false)

func apply_network_regrow() -> void:
	regrow_tile(true)
