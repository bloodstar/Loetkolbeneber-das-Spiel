class_name ChallengeHud
extends CanvasLayer

# Anzeige einer Challenge-Runde: großes Banner beim Start (Name + Ziel), oben
# in der Mitte Name, Restzeit und Wertung pro Spieler bzw. Team, kurze
# Hinweise (z. B. "Runde 2/3") und der eigene Wiedereinstiegs-Countdown.

const BANNER_TIME: float = 4.5

var director: ChallengeDirector = null
var _root: Control
var _plate: PanelContainer
var _title: Label
var _time_label: Label
var _standings: RichTextLabel
var _banner: VBoxContainer
var _banner_title: Label
var _banner_goal: Label
var _banner_t: float = BANNER_TIME
var _flash_label: Label
var _flash_t: float = 0.0
var _respawn_label: Label

func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_plate = PanelContainer.new()
	_plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_plate.position = Vector2(-230, 50)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_theme_stylebox_override("panel", UiTheme.box(Color(0.01, 0.03, 0.05, 0.6), Color.TRANSPARENT, 0, 10, 16, 6))
	_root.add_child(_plate)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(460, 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 1)
	_plate.add_child(col)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_title = _label("CHALLENGE", UiTheme.FS_L, UiTheme.GOLD)
	row.add_child(_title)
	_time_label = _label("0:00", UiTheme.FS_H2, UiTheme.TEXT)
	_time_label.add_theme_font_override("font", UiTheme.FONT_DISPLAY)
	row.add_child(_time_label)
	_standings = RichTextLabel.new()
	_standings.bbcode_enabled = true
	_standings.fit_content = true
	_standings.scroll_active = false
	_standings.custom_minimum_size = Vector2(460, 0)
	_standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_standings.add_theme_font_size_override("normal_font_size", UiTheme.FS_M)
	_standings.add_theme_constant_override("outline_size", 4)
	_standings.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.9))
	col.add_child(_standings)

	_banner = VBoxContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-450, -230)
	_banner.custom_minimum_size = Vector2(900, 0)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)
	var kicker := _label("CHALLENGE-RUNDE", UiTheme.FS_L, UiTheme.CYAN_LIGHT)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(kicker)
	_banner_title = _label("", UiTheme.FS_H1 + 14, UiTheme.GOLD)
	_banner_title.add_theme_font_override("font", UiTheme.FONT_DISPLAY)
	_banner_title.add_theme_constant_override("outline_size", 8)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_title)
	_banner_goal = _label("", UiTheme.FS_XL, UiTheme.TEXT)
	_banner_goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_child(_banner_goal)

	_flash_label = _label("", UiTheme.FS_XL, UiTheme.GOLD)
	_flash_label.set_anchors_preset(Control.PRESET_CENTER)
	_flash_label.position = Vector2(-400, -150)
	_flash_label.custom_minimum_size = Vector2(800, 0)
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_flash_label)

	_respawn_label = _label("", UiTheme.FS_XL, UiTheme.DANGER)
	_respawn_label.set_anchors_preset(Control.PRESET_CENTER)
	_respawn_label.position = Vector2(-400, 80)
	_respawn_label.custom_minimum_size = Vector2(800, 0)
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_respawn_label)

func bind(d: ChallengeDirector) -> void:
	director = d
	var color: Color = d.def.get("color", UiTheme.GOLD)
	_title.text = ChallengeDefs.display_name(d.kind).to_upper()
	_title.add_theme_color_override("font_color", color)
	_banner_title.text = ChallengeDefs.display_name(d.kind).to_upper()
	_banner_title.add_theme_color_override("font_color", color)
	_banner_goal.text = str(d.def.get("goal", ""))
	_banner_t = BANNER_TIME

func flash(text: String) -> void:
	_flash_label.text = text
	_flash_t = 2.2

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _process(delta: float) -> void:
	if director == null or not is_instance_valid(director):
		return
	var paused := get_tree().paused
	_root.visible = not paused and Global.current_state == Global.GameState.PLAYING
	if not _root.visible:
		return
	# Banner bleibt während des Countdowns und blendet danach aus.
	if director.running:
		_banner_t -= delta
	_banner.visible = _banner_t > 0.0
	_banner.modulate.a = clampf(_banner_t / 0.8, 0.0, 1.0)
	_flash_t -= delta
	_flash_label.visible = _flash_t > 0.0
	_flash_label.modulate.a = clampf(_flash_t / 0.5, 0.0, 1.0)

	var t := int(ceil(director.time_left))
	_time_label.text = "%d:%02d" % [t / 60, t % 60]
	_time_label.add_theme_color_override("font_color", UiTheme.DANGER if director.time_left < 10.0 else UiTheme.TEXT)
	_standings.text = _standings_text()

	var own := Global.local_player_index if Global.network_mode else 1
	var left := director.replica_respawn_left(own)
	_respawn_label.text = "Wieder dabei in %d s" % int(ceil(left)) if left > 0.0 else ""

func _standings_text() -> String:
	var teams: Array = director.scores.keys()
	teams.sort_custom(func(a, b): return float(director.scores[a]) > float(director.scores[b]))
	var lines: PackedStringArray = []
	var line: PackedStringArray = []
	# Rennen hat lange Werte (Runde und Tor): zwei pro Zeile.
	var per_line := 2 if director.kind == "race" else 3
	for team in teams:
		var c := director.color_for_team(int(team)).to_html(false)
		line.append("[color=#%s]%s[/color] %s" % [c, director.team_label(int(team)), director.value_text(int(team))])
		if line.size() >= per_line:
			lines.append("    ".join(line))
			line.clear()
	if not line.is_empty():
		lines.append("    ".join(line))
	return "[center]%s[/center]" % "\n".join(lines)
