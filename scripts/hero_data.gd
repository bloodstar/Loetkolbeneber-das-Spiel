class_name HeroData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var role: String = "Skirmisher"
@export var description: String = ""
@export var passive_desc: String = ""
@export var ability_name: String = ""
@export var ability_desc: String = ""
@export var ability_cooldown: float = 6.0

@export var base_hp: int = 100
@export var base_shield: int = 0
@export var base_speed: float = 300.0
@export var base_jump_force: float = -460.0
@export var extra_jumps: int = 0

@export var color_tint: Color = Color.WHITE
@export var sprite_tile_name: String = "tile_0000.png"
