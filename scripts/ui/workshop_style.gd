class_name WorkshopStyle
extends RefCounted

# Gemeinsamer Platinen-Look für Hauptmenü und Optionen: dunkle Flächen mit
# leuchtendem Leiterbahn-Türkis, der Hauptknopf glüht pink wie eine Lötspitze.

# Farben kommen aus dem zentralen Theme (scripts/ui/ui_theme.gd).
const CYAN: Color = UiTheme.CYAN
const CYAN_LIGHT: Color = UiTheme.CYAN_LIGHT
const ACCENT: Color = UiTheme.ACCENT
const ACCENT_LIGHT: Color = UiTheme.ACCENT_LIGHT
const PLATE: Color = UiTheme.PLATE
const PLATE_HOVER: Color = UiTheme.PLATE_HOVER
const TEXT: Color = UiTheme.TEXT
const TEXT_DIM: Color = UiTheme.TEXT_DIM

static func neon_box(fill: Color, border: Color, width: int, radius: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box

static func style_button(button: Button, primary: bool = false, font_size: int = UiTheme.FS_XL) -> void:
	var line := ACCENT if primary else Color(CYAN.r, CYAN.g, CYAN.b, 0.6)
	var normal := neon_box(PLATE, line, 3 if primary else 2)
	var hovered := neon_box(PLATE_HOVER, ACCENT_LIGHT if primary else CYAN, 3)
	hovered.shadow_color = Color(line.r, line.g, line.b, 0.35)
	hovered.shadow_size = 10
	var pressed := neon_box(Color(line.r, line.g, line.b, 0.25), line, 3)
	var disabled := neon_box(PLATE.darkened(0.4), Color(0.2, 0.3, 0.32, 0.6), 2)
	var focus := neon_box(Color.TRANSPARENT, CYAN_LIGHT, 1)
	focus.draw_center = false
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hovered)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", focus)
	var text_color := ACCENT_LIGHT if primary else TEXT
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", text_color)
	button.add_theme_color_override("font_disabled_color", TEXT_DIM.darkened(0.3))
	button.add_theme_font_size_override("font_size", font_size)

static func panel_box() -> StyleBoxFlat:
	return UiTheme.panel_box()
