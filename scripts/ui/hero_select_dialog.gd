class_name HeroSelectDialog
extends CanvasLayer

signal heroes_chosen

@onready var p1_grid: HBoxContainer = $Panel/VBox/P1_Section/HeroGrid
@onready var p2_grid: HBoxContainer = $Panel/VBox/P2_Section/HeroGrid
@onready var start_btn: Button = $Panel/VBox/StartBtn

func _ready() -> void:
	visible = false
	start_btn.pressed.connect(_on_start_pressed)
	_build_hero_buttons()

func open_dialog() -> void:
	visible = true
	get_tree().paused = true

func _build_hero_buttons() -> void:
	var hero_keys = ["ignis", "titan", "volt", "spore"]
	
	# P1
	for k in hero_keys:
		var hero: HeroData = Global.get_hero(k)
		var btn = _create_hero_card(hero, 1)
		p1_grid.add_child(btn)
	
	# P2
	for k in hero_keys:
		var hero: HeroData = Global.get_hero(k)
		var btn = _create_hero_card(hero, 2)
		p2_grid.add_child(btn)

func _create_hero_card(hero: HeroData, p_idx: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(210, 160)
	
	var text_content = "%s\n[%s]\nHP: %d | Spd: %d\nPassive: %s\nActive: %s" % [
		hero.name.to_upper(),
		hero.role,
		hero.base_hp,
		int(hero.base_speed),
		hero.passive_desc,
		hero.ability_name
	]
	btn.text = text_content
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	btn.pressed.connect(func():
		SoundManager.play_sound("click")
		if p_idx == 1:
			Global.p1_hero_id = hero.id
		else:
			Global.p2_hero_id = hero.id
		_highlight_selection()
	)
	return btn

func _highlight_selection() -> void:
	# Visual update on buttons if needed
	pass

func _on_start_pressed() -> void:
	SoundManager.play_sound("confirm")
	visible = false
	get_tree().paused = false
	heroes_chosen.emit()
