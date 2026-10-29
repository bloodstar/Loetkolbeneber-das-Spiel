class_name HeroSelectDialog
extends CanvasLayer

signal heroes_chosen

@onready var p1_grid: HBoxContainer = $Panel/VBox/P1_Section/HeroGrid
@onready var p2_grid: HBoxContainer = $Panel/VBox/P2_Section/HeroGrid
@onready var start_btn: Button = $Panel/VBox/StartBtn

var p1_selected_button: Button = null
var p2_selected_button: Button = null

func _ready() -> void:
	visible = false
	start_btn.pressed.connect(_on_start_pressed)
	_build_hero_buttons()

func open_dialog() -> void:
	visible = true
	_refresh_selection_highlight()
	get_tree().paused = true

func _build_hero_buttons() -> void:
	# Alle aktuell registrierten Helden (Titan wurde entfernt, Block ist universal).
	var hero_keys: Array = Global.heroes.keys()
	
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
	btn.custom_minimum_size = Vector2(150, 190)
	# Held an den Button binden, damit die Auswahl eindeutig ist.
	btn.set_meta("hero_id", hero.id)
	
	# Eine Lobby-Basis-HP-Einstellung überschreibt den Heldenwert bereits vor
	# allen Kartenboni; die Heldenvorschau zeigt deshalb den effektiven Wert.
	var shown_hp: int = Global.get_effective_base_hp(hero)
	var text_content = "%s\n[%s]\nHP: %d | Spd: %d\nMun: %d | Feuer: %.2fs | Reload: %.1fs\nPassive: %s\nActive: %s" % [
		hero.name.to_upper(),
		hero.role,
		shown_hp,
		int(hero.base_speed),
		hero.base_ammo,
		hero.base_fire_rate_cooldown,
		hero.base_reload_time,
		hero.passive_desc,
		hero.ability_name
	]
	btn.text = text_content
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.tooltip_text = "%s (%.1fs Cooldown)\n%s\n%s" % [
		hero.ability_name, hero.ability_cooldown, hero.ability_desc,
		Global.get_hero_ability_details(hero),
	]
	
	btn.pressed.connect(func():
		_select_hero(btn, p_idx)
	)
	return btn

func _select_hero(button: Button, p_idx: int) -> void:
	var hero_id: String = button.get_meta("hero_id", "")
	if hero_id.is_empty():
		return
	
	SoundManager.play_sound("click")
	
	if p_idx == 1:
		Global.p1_hero_id = hero_id
		p1_selected_button = button
	else:
		Global.p2_hero_id = hero_id
		p2_selected_button = button
	
	_refresh_selection_highlight()
	print("P%d ausgewählt: %s" % [p_idx, Global.get_hero(hero_id).name])

func _refresh_selection_highlight() -> void:
	_highlight_grid(p1_grid, Global.p1_hero_id, 1)
	_highlight_grid(p2_grid, Global.p2_hero_id, 2)

func _highlight_grid(grid: HBoxContainer, hero_id: String, p_idx: int) -> void:
	for child in grid.get_children():
		var btn := child as Button
		if btn == null:
			continue
		var is_selected: bool = btn.get_meta("hero_id", "") == hero_id
		btn.modulate = Color(1.0, 1.0, 0.8, 1.0) if is_selected else Color(1.0, 1.0, 1.0, 0.8)
		if is_selected:
			if p_idx == 1:
				p1_selected_button = btn
			else:
				p2_selected_button = btn

func _on_start_pressed() -> void:
	# Die Logik ist korrekt, aber wir stellen sicher, dass das Signal emittiert wird.
	SoundManager.play_sound("confirm")
	visible = false
	get_tree().paused = false
	heroes_chosen.emit()
