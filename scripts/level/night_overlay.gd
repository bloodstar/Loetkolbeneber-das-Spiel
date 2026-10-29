class_name NightOverlay
extends Node2D

# Nacht-Modifier: verdunkelt die Welt und lässt nur einen weichen Lichtkreis
# um den eigenen Spieler frei. Rein visuell und lokal: Jeder Client sieht nur
# seine eigene Umgebung, die Spielsimulation bleibt beim Host unverändert.

const MAX_LIGHTS: int = 6
# Sichtradius als Anteil der Bildschirmhöhe (unabhängig vom Kamera-Zoom).
const VISION_SCREEN_FRACTION: float = 0.3
const EDGE_SOFTNESS: float = 0.35
const NIGHT_COLOR: Color = Color(0.01, 0.015, 0.05, 0.96)
const FADE_SPEED: float = 1.5

const SHADER_CODE := """
shader_type canvas_item;

uniform vec2 lights[6];
uniform int light_count = 0;
uniform float radius = 300.0;
uniform float softness = 0.35;
uniform vec4 night_color : source_color = vec4(0.0, 0.0, 0.0, 0.95);
uniform float strength = 1.0;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	float vis = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i < light_count) {
			float d = distance(world_pos, lights[i]);
			vis = max(vis, 1.0 - smoothstep(radius * (1.0 - softness), radius, d));
		}
	}
	COLOR = vec4(night_color.rgb, night_color.a * (1.0 - vis) * strength);
}
"""

var _main_ref: Node = null
var _material: ShaderMaterial = null
var _strength: float = 0.0
var _time: float = 0.0
var _world_rect: Rect2 = Rect2()

func setup(main_node: Node) -> void:
	_main_ref = main_node

func _ready() -> void:
	# Weltkoordinaten direkt im Shader nutzen und über allem Spielgeschehen
	# liegen; das HUD liegt auf einem eigenen CanvasLayer darüber.
	top_level = true
	global_position = Vector2.ZERO
	z_as_relative = false
	z_index = 1000
	add_to_group("round_effect")

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("softness", EDGE_SOFTNESS)
	_material.set_shader_parameter("night_color", NIGHT_COLOR)
	material = _material

func _process(delta: float) -> void:
	_time += delta
	var vp := get_viewport()
	if vp == null:
		return
	var vis_rect := vp.get_visible_rect()
	_world_rect = vp.get_canvas_transform().affine_inverse() * vis_rect

	var lights := _collect_light_positions()
	var target := 1.0 if not lights.is_empty() else 0.0
	_strength = move_toward(_strength, target, FADE_SPEED * delta)
	visible = _strength > 0.001

	var padded := PackedVector2Array(lights)
	while padded.size() < MAX_LIGHTS:
		padded.append(Vector2(-100000.0, -100000.0))
	# Leichtes "Fackel-Atmen", damit der Lichtkreis nicht statisch wirkt.
	var flicker := 1.0 + sin(_time * 2.3) * 0.015 + sin(_time * 5.7) * 0.008
	_material.set_shader_parameter("lights", padded)
	_material.set_shader_parameter("light_count", lights.size())
	_material.set_shader_parameter("radius", _world_rect.size.y * VISION_SCREEN_FRACTION * flicker)
	_material.set_shader_parameter("strength", _strength)
	queue_redraw()

func _draw() -> void:
	draw_rect(_world_rect.grow(64.0), Color.WHITE)

# Netzwerk: nur der eigene Slot. Lokal: alle menschlichen Spieler am Bildschirm.
# Zuschauer und tote Spieler sehen die ganze Arena.
func _collect_light_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if Global.is_spectator or _main_ref == null:
		return result
	var players = _main_ref.get("players")
	if not players is Array:
		return result
	for p in players:
		if not is_instance_valid(p) or p.is_dead or p.current_health <= 0.0:
			continue
		var is_local := false
		if Global.network_mode:
			is_local = p.player_index == Global.local_player_index
		else:
			is_local = not p.is_bot
		if is_local and result.size() < MAX_LIGHTS:
			result.append(p.global_position)
	return result
