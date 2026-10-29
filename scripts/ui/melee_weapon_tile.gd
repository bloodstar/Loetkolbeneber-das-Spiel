extends Button

## Kachel für eine Nahkampfwaffe im Charakter-Tab: Icon, Name darunter und
## beim Überfahren ein Tooltip im Stil eines Rollenspiel-Gegenstands.

const MeleeWeaponIconScript = preload("res://scripts/ui/melee_weapon_icon.gd")
const ICON_SIZE: float = 58.0
const TILE_WIDTH: float = 64.0
const QUALITY_COLOR: Color = Color(1.0, 0.5, 0.0) # Wie legendäre Gegenstände.
const USE_COLOR: Color = Color(0.12, 1.0, 0.0)
const FLAVOR_COLOR: Color = Color(1.0, 0.82, 0.0)

var weapon_id: String = "iron"
# Untypisiert, weil weapon/selected/... aus dem Icon-Skript kommen.
var _icon = null
var _name_label: Label = null
var _is_selected: bool = false

func _init(id: String = "iron") -> void:
	weapon_id = Global.normalize_melee_weapon(id)

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(TILE_WIDTH, ICON_SIZE + 22.0)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	# Nicht leer, sonst ruft Godot _make_custom_tooltip nicht auf.
	tooltip_text = "%s\n%s" % [
		Global.get_melee_weapon_label(weapon_id), Global.get_melee_weapon_stats_text(weapon_id)
	]

	_icon = MeleeWeaponIconScript.new()
	_icon.weapon = weapon_id
	_icon.position = Vector2((TILE_WIDTH - ICON_SIZE) * 0.5, 2.0)
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	add_child(_icon)

	_name_label = Label.new()
	_name_label.text = Global.get_melee_weapon_label(weapon_id)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-8.0, ICON_SIZE + 4.0)
	_name_label.size = Vector2(TILE_WIDTH + 16.0, 16.0)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)

	mouse_entered.connect(func(): _icon.hovered = true)
	mouse_exited.connect(func(): _icon.hovered = false)
	_refresh()

func set_selected(value: bool) -> void:
	_is_selected = value
	_refresh()

func set_locked(value: bool) -> void:
	disabled = value
	_refresh()

func _refresh() -> void:
	if _icon == null:
		return
	_icon.selected = _is_selected
	_icon.dimmed = disabled and not _is_selected
	var color := Color(1.0, 0.86, 0.4) if _is_selected else Color(0.72, 0.76, 0.84)
	if disabled:
		color = color.darkened(0.35)
	_name_label.add_theme_color_override("font_color", color)

func _make_custom_tooltip(_for_text: String) -> Object:
	var data := Global.get_melee_weapon_data(weapon_id)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.09, 0.94)
	style.border_color = Color(0.62, 0.64, 0.70, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	panel.add_child(box)

	_tooltip_line(box, Global.get_melee_weapon_label(weapon_id), QUALITY_COLOR, 16)
	var slot_row := HBoxContainer.new()
	box.add_child(slot_row)
	var slot_left := _tooltip_line(slot_row, "Nahkampfwaffe", Color.WHITE, 13)
	slot_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_left.custom_minimum_size = Vector2(150, 0)
	_tooltip_line(slot_row, "Taste E", Color.WHITE, 13).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var arc := float(data["arc_deg"])
	var arc_text := "Stich" if arc <= 0.0 else ("Rundumschlag 360°" if arc >= 360.0 else "Hieb im %d°-Bogen" % int(arc))
	var tiles := int(data["range_tiles"])
	var damage_row := HBoxContainer.new()
	box.add_child(damage_row)
	var damage_left := _tooltip_line(damage_row, "%d Schaden" % int(data["damage"]), Color.WHITE, 13)
	damage_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_line(damage_row, "Abklingzeit %s s" % _decimal(float(data["cooldown"])), Color.WHITE, 13) \
		.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tooltip_line(box, arc_text, Color.WHITE, 13)
	_tooltip_line(box, "Reichweite: %d %s" % [tiles, "Feld" if tiles == 1 else "Felder"], Color.WHITE, 13)
	_tooltip_line(box, "Rückstoß: %s" % _knockback_text(float(data["knockback"])), Color.WHITE, 13)
	if float(data["wall_stun"]) > 0.0:
		_tooltip_line(box, "Treffer: Wer gegen eine Wand fliegt, ist %s s betäubt." % _decimal(float(data["wall_stun"])),
			USE_COLOR, 13)
	var flavor := _tooltip_line(box, "„%s“" % str(data["desc"]), FLAVOR_COLOR, 12)
	flavor.custom_minimum_size = Vector2(240, 0)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _is_selected:
		_tooltip_line(box, "Ausgerüstet", USE_COLOR, 12)
	elif disabled:
		_tooltip_line(box, "Gerade nicht wählbar", Color(1.0, 0.3, 0.25), 12)
	return panel

func _tooltip_line(parent: Control, text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label

func _decimal(value: float) -> String:
	return ("%.1f" % value).replace(".", ",")

func _knockback_text(knockback: float) -> String:
	if knockback >= 800.0:
		return "sehr stark"
	if knockback >= 550.0:
		return "stark"
	if knockback >= 350.0:
		return "mittel"
	return "schwach"
