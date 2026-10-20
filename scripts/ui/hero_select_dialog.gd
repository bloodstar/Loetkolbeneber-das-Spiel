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
	
	# NEU: Signal-Verbindung für die Hervorhebung
	btn.pressed.connect(func():
		SoundManager.play_sound("click")
		_highlight_selection(btn, p_idx)
	)
	return btn

func _highlight_selection(button: Button, p_idx: int) -> void:
	# 1. Alle Buttons im Dialog deaktivieren/entfärben
	var all_buttons = get_node("Panel/VBox/P1_Section/HeroGrid").get_children() + get_node("Panel/VBox/P2_Section/HeroGrid").get_children()
	for btn in all_buttons:
		btn.modulate = Color(1.0, 1.0, 1.0, 0.8)
		
	# 2. Den geklickten Button hervorheben
	button.modulate = Color(1.0, 1.0, 0.8, 1.0) # Leicht gelb/aktiv
	
	# 3. Globalen Zustand setzen
	var hero: HeroData = Global.get_hero(Global.p1_hero_id if p_idx == 1 else Global.p2_hero_id)
	if p_idx == 1:
		Global.p1_hero_id = hero.id
	else:
		Global.p2_hero_id = hero.id
	
	# Visuelle Bestätigung (optional: einen kleinen Pop-up-Text)
	print("P%d ausgewählt: %s" % [p_idx, hero.name])


func _on_start_pressed() -> void:
	# Die Logik ist korrekt, aber wir stellen sicher, dass das Signal emittiert wird.
	SoundManager.play_sound("confirm")
	visible = false
	get_tree().paused = false
	heroes_chosen.emit()
