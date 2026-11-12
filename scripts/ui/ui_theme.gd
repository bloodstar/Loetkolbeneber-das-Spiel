class_name UiTheme
extends RefCounted

## Zentrales UI-Theme von Lötkolbeneber ("Neon-Platine").
##
## Hier stehen alle Schriften, Schriftgrößen-Stufen und Farben der Oberfläche.
## build() baut daraus das Projekt-Theme (res://assets/ui/ui_theme.tres, in
## project.godot unter gui/theme/custom eingetragen). Nach einer Änderung in
## dieser Datei das Theme neu erzeugen:
##   Godot-Editor: tools/build_ui_theme_editor.gd öffnen → Datei → Ausführen
##   Kommandozeile: godot --headless --path . --script res://tools/build_ui_theme.gd
##
## Code, der eigene Größen oder Farben setzt, nimmt die Konstanten von hier
## (z. B. UiTheme.FS_S, UiTheme.TEXT_MUTED) statt eigener Zahlenwerte.

const THEME_PATH := "res://assets/ui/ui_theme.tres"

# --- Schriften ---------------------------------------------------------------
# Exo 2 für Text (gut lesbar, leicht technisch), Orbitron für Titel. Beide OFL.
const FONT_BODY: FontVariation = preload("res://assets/fonts/font_body.tres")
const FONT_BOLD: FontVariation = preload("res://assets/fonts/font_bold.tres")
const FONT_DISPLAY: FontVariation = preload("res://assets/fonts/font_display.tres")

# --- Schriftgrößen-Stufen (px bei 1600x900) ------------------------------------
const FS_XXS: int = 10      # Mini-Infos über Spielern, Tag-Zeilen
const FS_XS: int = 11       # Fußnoten, Meta-Zeilen
const FS_S: int = 13        # Hinweise, Beschreibungen
const FS_M: int = 15        # kompakter Fließtext, Listen
const FS_BODY: int = 16     # Standardtext (Theme-Default)
const FS_L: int = 18        # Abschnitts-Überschriften, wichtige Werte
const FS_XL: int = 22       # große Knöpfe, Banner-Text
const FS_H2: int = 28       # Fenster-Titel
const FS_H1: int = 34       # Bildschirm-Titel
const FS_DISPLAY: int = 60  # Riesen-Symbole
const FS_HERO: int = 96     # Logo / Countdown-Ziffern

# --- Farben -------------------------------------------------------------------
# Leiterbahn-Türkis als Grundfarbe, Lötspitzen-Pink als Akzent.
const CYAN: Color = Color(0.1, 0.85, 0.8, 1.0)
const CYAN_LIGHT: Color = Color(0.75, 1.0, 0.97, 1.0)
const CYAN_DIM: Color = Color(0.1, 0.85, 0.8, 0.45)
const ACCENT: Color = Color(1.0, 0.35, 0.7, 1.0)
const ACCENT_LIGHT: Color = Color(1.0, 0.72, 0.88, 1.0)

const BG: Color = Color(0.02, 0.035, 0.05, 1.0)
const PLATE: Color = Color(0.02, 0.05, 0.06, 0.85)
const PLATE_SOLID: Color = Color(0.03, 0.06, 0.08, 0.97)
const PLATE_HOVER: Color = Color(0.04, 0.12, 0.13, 0.92)
const FIELD: Color = Color(0.01, 0.025, 0.035, 0.95)

const TEXT: Color = Color(0.86, 0.94, 0.95, 1.0)
const TEXT_SOFT: Color = Color(0.72, 0.8, 0.86, 1.0)
const TEXT_MUTED: Color = Color(0.55, 0.63, 0.7, 1.0)
const TEXT_DIM: Color = Color(0.5, 0.66, 0.68, 1.0)
const TEXT_DISABLED: Color = Color(0.36, 0.44, 0.47, 1.0)

const GOLD: Color = Color(1.0, 0.83, 0.38, 1.0)
const DANGER: Color = Color(1.0, 0.45, 0.42, 1.0)
const SUCCESS: Color = Color(0.45, 0.95, 0.6, 1.0)
const INFO: Color = Color(0.5, 0.85, 1.0, 1.0)

# --- Bausteine ----------------------------------------------------------------

static func box(fill: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 6, margin_h: float = 10.0, margin_v: float = 5.0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(width)
	b.set_corner_radius_all(radius)
	b.content_margin_left = margin_h
	b.content_margin_right = margin_h
	b.content_margin_top = margin_v
	b.content_margin_bottom = margin_v
	b.anti_aliasing = true
	return b

static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## Leuchtender Fenster-Rahmen (Optionen, Statistik, Dialoge).
static func panel_box() -> StyleBoxFlat:
	var b := box(PLATE_SOLID, with_alpha(CYAN, 0.75), 2, 18, -1.0, -1.0)
	b.shadow_color = with_alpha(CYAN, 0.18)
	b.shadow_size = 22
	return b

# --- Theme bauen ----------------------------------------------------------------

static func build() -> Theme:
	var t := Theme.new()
	t.default_font = FONT_BODY
	t.default_font_size = FS_BODY
	_label(t)
	_buttons(t)
	_inputs(t)
	_containers(t)
	_lists(t)
	_ranges(t)
	_popups(t)
	_variations(t)
	return t

static func _label(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 1.0))
	t.set_constant("line_spacing", "Label", 2)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", FONT_BODY)
	t.set_font("bold_font", "RichTextLabel", FONT_BOLD)
	t.set_font("bold_italics_font", "RichTextLabel", FONT_BOLD)
	t.set_font("italics_font", "RichTextLabel", FONT_BODY)
	t.set_color("font_color", "LinkButton", INFO)
	t.set_color("font_hover_color", "LinkButton", CYAN_LIGHT)

static func _button_styles(t: Theme, type: StringName, line: Color, hover_line: Color, text: Color) -> void:
	var normal := box(PLATE, line, 2, 6, 12.0, 5.0)
	var hover := box(PLATE_HOVER, hover_line, 2, 6, 12.0, 5.0)
	hover.shadow_color = with_alpha(hover_line, 0.3)
	hover.shadow_size = 8
	var pressed := box(with_alpha(line, 0.25), hover_line, 2, 6, 12.0, 5.0)
	var disabled := box(Color(0.02, 0.04, 0.05, 0.6), Color(0.2, 0.3, 0.32, 0.5), 1, 6, 12.0, 5.0)
	var focus := box(Color.TRANSPARENT, CYAN_LIGHT, 1, 7, 12.0, 5.0)
	focus.draw_center = false
	focus.expand_margin_left = 2
	focus.expand_margin_right = 2
	focus.expand_margin_top = 2
	focus.expand_margin_bottom = 2
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("hover_pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, focus)
	t.set_font("font", type, FONT_BOLD)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, Color.WHITE)
	t.set_color("font_hover_pressed_color", type, Color.WHITE)
	t.set_color("font_focus_color", type, text)
	t.set_color("font_disabled_color", type, TEXT_DISABLED)
	t.set_color("icon_normal_color", type, Color.WHITE)
	t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.4))
	t.set_constant("h_separation", type, 6)

static func _buttons(t: Theme) -> void:
	_button_styles(t, &"Button", with_alpha(CYAN, 0.55), CYAN, TEXT)
	_button_styles(t, &"OptionButton", with_alpha(CYAN, 0.4), CYAN, TEXT)
	t.set_font("font", "OptionButton", FONT_BODY)
	t.set_constant("arrow_margin", "OptionButton", 8)
	_button_styles(t, &"MenuButton", with_alpha(CYAN, 0.0), with_alpha(CYAN, 0.6), TEXT)
	t.set_stylebox("normal", "MenuButton", box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 6, 8.0, 4.0))
	# Häkchen und Schalter: kein Kasten, nur Text und Symbol.
	for type: StringName in [&"CheckBox", &"CheckButton"]:
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 4
		empty.content_margin_right = 4
		empty.content_margin_top = 2
		empty.content_margin_bottom = 2
		for s in ["normal", "pressed", "hover", "hover_pressed", "disabled"]:
			t.set_stylebox(s, type, empty)
		var focus := box(Color.TRANSPARENT, with_alpha(CYAN_LIGHT, 0.7), 1, 4, 4.0, 2.0)
		focus.draw_center = false
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, CYAN_LIGHT)
		t.set_color("font_hover_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, TEXT_DISABLED)
		t.set_constant("h_separation", type, 8)

static func _field_styles(t: Theme, type: StringName) -> void:
	t.set_stylebox("normal", type, box(FIELD, with_alpha(CYAN, 0.28), 1, 5, 8.0, 4.0))
	t.set_stylebox("focus", type, box(Color.TRANSPARENT, CYAN, 1, 5, 8.0, 4.0))
	t.set_stylebox("read_only", type, box(Color(0.02, 0.04, 0.05, 0.6), Color(0.2, 0.3, 0.32, 0.4), 1, 5, 8.0, 4.0))
	t.set_color("font_color", type, TEXT)
	t.set_color("font_placeholder_color", type, with_alpha(TEXT_MUTED, 0.75))
	t.set_color("font_readonly_color", type, TEXT_MUTED)
	t.set_color("font_selected_color", type, Color.WHITE)
	t.set_color("selection_color", type, with_alpha(CYAN, 0.35))
	t.set_color("caret_color", type, CYAN_LIGHT)

static func _inputs(t: Theme) -> void:
	_field_styles(t, &"LineEdit")
	_field_styles(t, &"TextEdit")
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))

static func _containers(t: Theme) -> void:
	# Panel/PanelContainer: ruhige dunkle Fläche ohne Rand. Fenster mit
	# Leuchtrand nutzen die Variante "NeonPanel".
	t.set_stylebox("panel", "Panel", box(PLATE_SOLID, Color.TRANSPARENT, 0, 8, 0.0, 0.0))
	t.set_stylebox("panel", "PanelContainer", box(PLATE_SOLID, Color.TRANSPARENT, 0, 8, 0.0, 0.0))

	# Reiter: aktiver Reiter mit türkiser Oberkante, inaktive gedimmt.
	var tab_sel := box(PLATE_HOVER, Color.TRANSPARENT, 0, 5, 14.0, 6.0)
	tab_sel.border_width_top = 2
	tab_sel.border_color = CYAN
	tab_sel.corner_radius_bottom_left = 0
	tab_sel.corner_radius_bottom_right = 0
	var tab_unsel := box(Color(0.02, 0.05, 0.06, 0.55), Color.TRANSPARENT, 0, 5, 14.0, 6.0)
	tab_unsel.corner_radius_bottom_left = 0
	tab_unsel.corner_radius_bottom_right = 0
	var tab_hover := tab_unsel.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color(0.04, 0.1, 0.11, 0.8)
	var tab_disabled := tab_unsel.duplicate() as StyleBoxFlat
	tab_disabled.bg_color = Color(0.02, 0.03, 0.04, 0.4)
	var tab_focus := box(Color.TRANSPARENT, with_alpha(CYAN_LIGHT, 0.7), 1, 5, 14.0, 6.0)
	tab_focus.draw_center = false
	var tab_panel := box(Color(0.02, 0.045, 0.055, 0.9), with_alpha(CYAN, 0.25), 1, 6, 10.0, 10.0)
	tab_panel.border_width_top = 1
	tab_panel.corner_radius_top_left = 0
	for type: StringName in [&"TabContainer", &"TabBar"]:
		t.set_stylebox("tab_selected", type, tab_sel)
		t.set_stylebox("tab_unselected", type, tab_unsel)
		t.set_stylebox("tab_hovered", type, tab_hover)
		t.set_stylebox("tab_disabled", type, tab_disabled)
		t.set_stylebox("tab_focus", type, tab_focus)
		t.set_font("font", type, FONT_BOLD)
		t.set_font_size("font_size", type, FS_M)
		t.set_color("font_selected_color", type, CYAN_LIGHT)
		t.set_color("font_unselected_color", type, TEXT_MUTED)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_color("font_disabled_color", type, TEXT_DISABLED)
		t.set_constant("h_separation", type, 4)
	t.set_stylebox("panel", "TabContainer", tab_panel)
	t.set_stylebox("tabbar_background", "TabContainer", StyleBoxEmpty.new())

	var sep_line := StyleBoxLine.new()
	sep_line.color = with_alpha(CYAN, 0.25)
	sep_line.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep_line)
	var vsep_line := sep_line.duplicate() as StyleBoxLine
	vsep_line.vertical = true
	t.set_stylebox("separator", "VSeparator", vsep_line)

	# Scrollbalken: schmal und dezent, der Griff leuchtet beim Drüberfahren.
	for type: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox("scroll", type, box(Color(0.0, 0.0, 0.0, 0.25), Color.TRANSPARENT, 0, 4, 3.0, 3.0))
		t.set_stylebox("scroll_focus", type, box(Color(0.0, 0.0, 0.0, 0.25), Color.TRANSPARENT, 0, 4, 3.0, 3.0))
		t.set_stylebox("grabber", type, box(with_alpha(CYAN, 0.35), Color.TRANSPARENT, 0, 4, 3.0, 3.0))
		t.set_stylebox("grabber_highlight", type, box(with_alpha(CYAN, 0.6), Color.TRANSPARENT, 0, 4, 3.0, 3.0))
		t.set_stylebox("grabber_pressed", type, box(CYAN, Color.TRANSPARENT, 0, 4, 3.0, 3.0))

static func _lists(t: Theme) -> void:
	var list_panel := box(FIELD, with_alpha(CYAN, 0.25), 1, 6, 4.0, 4.0)
	var sel := box(with_alpha(CYAN, 0.22), Color.TRANSPARENT, 0, 4, 4.0, 2.0)
	var hov := box(with_alpha(CYAN, 0.1), Color.TRANSPARENT, 0, 4, 4.0, 2.0)
	for type: StringName in [&"ItemList", &"Tree"]:
		t.set_stylebox("panel", type, list_panel)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_stylebox("selected", type, sel)
		t.set_stylebox("selected_focus", type, sel)
		t.set_stylebox("hovered", type, hov)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_selected_color", type, Color.WHITE)
		t.set_color("font_hovered_color", type, Color.WHITE)
		t.set_color("guide_color", type, with_alpha(CYAN, 0.12))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("title_button_normal", "Tree", box(PLATE_HOVER, Color.TRANSPARENT, 0, 0, 6.0, 4.0))
	t.set_stylebox("title_button_hover", "Tree", box(with_alpha(CYAN, 0.2), Color.TRANSPARENT, 0, 0, 6.0, 4.0))
	t.set_stylebox("title_button_pressed", "Tree", box(with_alpha(CYAN, 0.3), Color.TRANSPARENT, 0, 0, 6.0, 4.0))
	t.set_color("title_button_color", "Tree", CYAN_LIGHT)
	t.set_font("title_button_font", "Tree", FONT_BOLD)

static func _ranges(t: Theme) -> void:
	# Regler: dünne Schiene, gefüllter Teil türkis.
	var track := box(Color(0.0, 0.0, 0.0, 0.45), with_alpha(CYAN, 0.2), 1, 3, 0.0, 2.0)
	var fill := box(with_alpha(CYAN, 0.75), Color.TRANSPARENT, 0, 3, 0.0, 2.0)
	var fill_hl := box(CYAN, Color.TRANSPARENT, 0, 3, 0.0, 2.0)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hl)
	var vtrack := box(Color(0.0, 0.0, 0.0, 0.45), with_alpha(CYAN, 0.2), 1, 3, 2.0, 0.0)
	t.set_stylebox("slider", "VSlider", vtrack)
	t.set_stylebox("grabber_area", "VSlider", box(with_alpha(CYAN, 0.75), Color.TRANSPARENT, 0, 3, 2.0, 0.0))
	t.set_stylebox("grabber_area_highlight", "VSlider", box(CYAN, Color.TRANSPARENT, 0, 3, 2.0, 0.0))

	t.set_stylebox("background", "ProgressBar", box(Color(0.0, 0.0, 0.0, 0.5), with_alpha(CYAN, 0.25), 1, 4, 0.0, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(with_alpha(CYAN, 0.8), Color.TRANSPARENT, 0, 4, 0.0, 0.0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", FS_S)

static func _popups(t: Theme) -> void:
	var pop := box(PLATE_SOLID, with_alpha(CYAN, 0.55), 1, 6, 6.0, 6.0)
	pop.shadow_color = Color(0, 0, 0, 0.5)
	pop.shadow_size = 8
	t.set_stylebox("panel", "PopupMenu", pop)
	t.set_stylebox("hover", "PopupMenu", box(with_alpha(CYAN, 0.2), Color.TRANSPARENT, 0, 4, 6.0, 2.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", TEXT_DISABLED)
	t.set_color("font_separator_color", "PopupMenu", CYAN)
	t.set_constant("v_separation", "PopupMenu", 6)
	var popup_sep := StyleBoxLine.new()
	popup_sep.color = with_alpha(CYAN, 0.25)
	t.set_stylebox("separator", "PopupMenu", popup_sep)
	t.set_stylebox("labeled_separator_left", "PopupMenu", popup_sep)
	t.set_stylebox("labeled_separator_right", "PopupMenu", popup_sep)
	t.set_stylebox("panel", "PopupPanel", pop)

	var tip := box(Color(0.015, 0.035, 0.045, 0.97), with_alpha(CYAN, 0.6), 1, 6, 10.0, 7.0)
	tip.shadow_color = Color(0, 0, 0, 0.45)
	tip.shadow_size = 6
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FS_M)

	var win := box(PLATE_SOLID, with_alpha(CYAN, 0.75), 2, 10, 12.0, 12.0)
	win.expand_margin_top = 30
	win.shadow_color = with_alpha(CYAN, 0.15)
	win.shadow_size = 16
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_color("title_color", "Window", CYAN_LIGHT)
	t.set_font("title_font", "Window", FONT_BOLD)
	t.set_stylebox("panel", "AcceptDialog", box(PLATE_SOLID, Color.TRANSPARENT, 0, 0, 12.0, 12.0))

static func _variations(t: Theme) -> void:
	# Titel in Orbitron mit leichtem Leuchten.
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", FONT_DISPLAY)
	t.set_font_size("font_size", "TitleLabel", FS_H1)
	t.set_color("font_color", "TitleLabel", CYAN_LIGHT)
	# Dezenter Schlagschatten, damit eigene Titelfarben (z. B. Orange) sauber bleiben.
	t.set_color("font_shadow_color", "TitleLabel", Color(0.0, 0.0, 0.0, 0.6))
	t.set_constant("shadow_offset_x", "TitleLabel", 0)
	t.set_constant("shadow_offset_y", "TitleLabel", 2)
	t.set_constant("shadow_outline_size", "TitleLabel", 2)

	t.set_type_variation("HeroTitleLabel", "TitleLabel")
	t.set_font_size("font_size", "HeroTitleLabel", FS_HERO)
	# Logo: Neon-Leuchten statt Schlagschatten.
	t.set_color("font_shadow_color", "HeroTitleLabel", with_alpha(CYAN, 0.45))
	t.set_constant("shadow_offset_y", "HeroTitleLabel", 0)
	t.set_color("font_outline_color", "HeroTitleLabel", Color(0.02, 0.2, 0.2, 1.0))
	t.set_constant("outline_size", "HeroTitleLabel", 8)
	t.set_constant("shadow_outline_size", "HeroTitleLabel", 28)

	# Abschnitts-Überschrift (fett, türkis).
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", FONT_BOLD)
	t.set_font_size("font_size", "HeadingLabel", FS_L)
	t.set_color("font_color", "HeadingLabel", CYAN)

	# Hinweistext (klein, gedämpft).
	t.set_type_variation("HintLabel", "Label")
	t.set_font_size("font_size", "HintLabel", FS_S)
	t.set_color("font_color", "HintLabel", TEXT_MUTED)

	# Hauptknopf: glüht pink wie eine Lötspitze.
	t.set_type_variation("PrimaryButton", "Button")
	var p_normal := box(PLATE, ACCENT, 2, 6, 12.0, 5.0)
	var p_hover := box(PLATE_HOVER, ACCENT_LIGHT, 2, 6, 12.0, 5.0)
	p_hover.shadow_color = with_alpha(ACCENT, 0.35)
	p_hover.shadow_size = 10
	var p_pressed := box(with_alpha(ACCENT, 0.25), ACCENT_LIGHT, 2, 6, 12.0, 5.0)
	t.set_stylebox("normal", "PrimaryButton", p_normal)
	t.set_stylebox("hover", "PrimaryButton", p_hover)
	t.set_stylebox("pressed", "PrimaryButton", p_pressed)
	t.set_stylebox("hover_pressed", "PrimaryButton", p_pressed)
	t.set_color("font_color", "PrimaryButton", ACCENT_LIGHT)
	t.set_color("font_focus_color", "PrimaryButton", ACCENT_LIGHT)

	# Fenster mit Leuchtrand.
	t.set_type_variation("NeonPanel", "PanelContainer")
	t.set_stylebox("panel", "NeonPanel", panel_box())
