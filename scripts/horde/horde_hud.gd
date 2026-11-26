class_name HordeHud
extends CanvasLayer

# Anzeige im Horden-Modus: Zeit, Stufe und XP-Balken, Kills, Boss-Leiste,
# Hinweise, eigener Wiederbelebungs-Countdown und der Endbildschirm.

signal again_requested
signal menu_requested

var director: HordeDirector = null
var _root: Control
var _plate: PanelContainer
var _time_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _kills_label: Label
var _boss_box: VBoxContainer
var _boss_label: Label
var _boss_bar: ProgressBar
var _next_boss_label: Label
var _notice_label: Label
var _notice_t: float = 0.0
var _respawn_label: Label
var _end_panel: PanelContainer
var _end_title: Label
var _end_stats: Label
var _end_table: GridContainer
var _again_btn: Button

func _ready() -> void:
	layer = 12
	# Läuft auch bei pausiertem Baum, damit die Anzeige während der Kartenwahl
	# ausgeblendet werden kann.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var plate := PanelContainer.new()
	_plate = plate
	plate.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plate.position = Vector2(-280, 52)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel", UiTheme.box(Color(0.01, 0.03, 0.05, 0.55), Color.TRANSPARENT, 0, 10, 20, 6))
	_root.add_child(plate)
	var top := VBoxContainer.new()
	top.custom_minimum_size = Vector2(520, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 2)
	plate.add_child(top)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	top.add_child(row)
	_level_label = _label("STUFE 1", UiTheme.FS_L, UiTheme.CYAN_LIGHT)
	row.add_child(_level_label)
	_time_label = _label("0:00", UiTheme.FS_H2, UiTheme.TEXT)
	_time_label.add_theme_font_override("font", UiTheme.FONT_DISPLAY)
	row.add_child(_time_label)
	_kills_label = _label("0 erlegt", UiTheme.FS_L, UiTheme.GOLD)
	row.add_child(_kills_label)

	_xp_bar = _bar(Color(0.35, 0.75, 1.0), Vector2(520, 12))
	top.add_child(_xp_bar)
	_next_boss_label = _label("", UiTheme.FS_S, UiTheme.TEXT_MUTED)
	_next_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_next_boss_label)

	_boss_box = VBoxContainer.new()
	_boss_box.visible = false
	_boss_box.add_theme_constant_override("separation", 1)
	top.add_child(_boss_box)
	_boss_label = _label("BOSS", UiTheme.FS_M, UiTheme.DANGER)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_label)
	_boss_bar = _bar(Color(0.95, 0.25, 0.25), Vector2(520, 16))
	_boss_box.add_child(_boss_bar)

	_notice_label = _label("", UiTheme.FS_XL, UiTheme.TEXT)
	_notice_label.set_anchors_preset(Control.PRESET_CENTER)
	_notice_label.position = Vector2(-400, -190)
	_notice_label.custom_minimum_size = Vector2(800, 0)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_constant_override("outline_size", 6)
	_notice_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_root.add_child(_notice_label)

	_respawn_label = _label("", UiTheme.FS_XL, UiTheme.DANGER)
	_respawn_label.set_anchors_preset(Control.PRESET_CENTER)
	_respawn_label.position = Vector2(-400, 80)
	_respawn_label.custom_minimum_size = Vector2(800, 0)
	_respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_respawn_label.add_theme_constant_override("outline_size", 6)
	_respawn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_root.add_child(_respawn_label)

	_build_end_panel()

func bind(d: HordeDirector) -> void:
	director = d
	d.notice.connect(show_notice)
	d.run_over.connect(_on_run_over)

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.02, 0.04, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(color: Color, min_size: Vector2) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = min_size
	b.max_value = 1.0
	b.step = 0.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_stylebox_override("background", UiTheme.box(Color(0.02, 0.04, 0.06, 0.8), UiTheme.with_alpha(color, 0.5), 1, 4, 0, 0))
	b.add_theme_stylebox_override("fill", UiTheme.box(color, Color.TRANSPARENT, 0, 4, 0, 0))
	return b

func show_notice(text: String, color: Color) -> void:
	_notice_label.text = text
	_notice_label.add_theme_color_override("font_color", color)
	_notice_t = 3.0
	_notice_label.modulate.a = 1.0

func _process(delta: float) -> void:
	if director == null or not is_instance_valid(director):
		return
	# Während der Kartenwahl (Baum pausiert) nichts über das Draft-Fenster legen.
	var paused := get_tree().paused
	_plate.visible = not paused
	_notice_label.visible = not paused
	_respawn_label.visible = not paused
	if paused:
		return
	_time_label.text = HordeDefs.format_time(director.run_time)
	# Angehaltene Uhr während des Bosskampfs gedimmt und blinkend.
	if director.timer_paused():
		_time_label.modulate = Color(1.0, 0.55, 0.45, 0.55 + 0.35 * absf(sin(Time.get_ticks_msec() * 0.004)))
	else:
		_time_label.modulate = Color.WHITE
	_level_label.text = "STUFE %d" % director.level
	_kills_label.text = "%d erlegt" % director.kills
	_xp_bar.value = clampf(float(director.xp) / maxf(1.0, float(director.xp_next)), 0.0, 1.0)
	var nb := director.replica_next_boss_in()
	if nb > 0.0:
		var final := director.boss_index >= HordeDefs.BOSS_TIMES.size() - 1 and not director.is_replica
		_next_boss_label.text = ("Endboss in %s" if final else "Nächster Boss in %s") % HordeDefs.format_time(nb)
	else:
		_next_boss_label.text = ""
	var info := director.boss_info
	_boss_box.visible = not info.is_empty()
	if not info.is_empty():
		var hp := director.boss_health_ratio()
		_boss_bar.value = maxf(0.0, hp)
		_boss_label.text = ("ENDBOSS " if bool(info.get("final", false)) else "BOSS ") + str(info.get("name", "")).to_upper()
	if _notice_t > 0.0:
		_notice_t -= delta
		_notice_label.modulate.a = clampf(_notice_t / 0.6, 0.0, 1.0)
	var slot := Global.local_player_index if Global.network_mode else 1
	var left := director.replica_respawn_left(slot)
	if left > 0.0 and director.over == 0 and not Global.is_spectator:
		_respawn_label.text = "Du stehst in %d s wieder auf" % int(ceil(left))
	else:
		_respawn_label.text = ""

func _build_end_panel() -> void:
	_end_panel = PanelContainer.new()
	_end_panel.visible = false
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.custom_minimum_size = Vector2(620, 0)
	_end_panel.position = Vector2(-310, -200)
	_end_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PLATE_SOLID, UiTheme.CYAN_DIM, 2, 10, 24, 18))
	_root.add_child(_end_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_end_panel.add_child(v)
	_end_title = _label("", UiTheme.FS_H1, UiTheme.GOLD)
	_end_title.add_theme_font_override("font", UiTheme.FONT_DISPLAY)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_title)
	_end_stats = _label("", UiTheme.FS_L, UiTheme.TEXT)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_stats)
	_end_table = GridContainer.new()
	_end_table.columns = 4
	_end_table.add_theme_constant_override("h_separation", 26)
	_end_table.add_theme_constant_override("v_separation", 4)
	var center := CenterContainer.new()
	center.add_child(_end_table)
	v.add_child(center)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	v.add_child(buttons)
	_again_btn = Button.new()
	_again_btn.text = "NOCHMAL JAGEN"
	_again_btn.custom_minimum_size = Vector2(200, 44)
	_again_btn.pressed.connect(func(): again_requested.emit())
	buttons.add_child(_again_btn)
	var menu_btn := Button.new()
	menu_btn.text = "HAUPTMENÜ"
	menu_btn.custom_minimum_size = Vector2(200, 44)
	menu_btn.pressed.connect(func(): menu_requested.emit())
	buttons.add_child(menu_btn)

func _on_run_over(victory: bool) -> void:
	_end_panel.visible = true
	_end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_title.text = "ÜBERLEBT!" if victory else "DIE JAGD IST VORBEI"
	_end_title.add_theme_color_override("font_color", UiTheme.GOLD if victory else UiTheme.DANGER)
	_end_stats.text = "Zeit %s   ·   Stufe %d   ·   %d erlegt" % [HordeDefs.format_time(director.run_time), director.level, director.kills]
	for c in _end_table.get_children():
		c.queue_free()
	for h in ["EBER", "ERLEGT", "SCHADEN", "GEFALLEN"]:
		_end_table.add_child(_label(h, UiTheme.FS_S, UiTheme.TEXT_MUTED))
	for slot in Global.get_active_player_indices():
		var s: Dictionary = director.slot_stats.get(slot, director.slot_stats.get(str(slot), {}))
		_end_table.add_child(_label(Global.get_player_name(slot), UiTheme.FS_M, UiTheme.TEXT))
		_end_table.add_child(_label(str(int(s.get("kills", 0))), UiTheme.FS_M, UiTheme.GOLD))
		_end_table.add_child(_label(str(int(s.get("damage", 0.0))), UiTheme.FS_M, UiTheme.TEXT))
		_end_table.add_child(_label(str(int(s.get("deaths", 0))), UiTheme.FS_M, UiTheme.TEXT_SOFT))
	# Online entscheidet nur der Host über eine neue Jagd.
	_again_btn.visible = not Global.network_mode or NetworkManager.is_host
