class_name MainMenu
extends CanvasLayer

# Wird ausgelöst, wenn der Spieler im Menü auf "Spiel starten" klickt.
signal start_requested
# Online-Wünsche: Der Main-Node baut die Verbindung auf und öffnet die Lobby.
signal host_requested(port: int)
signal join_requested(address: String, port: int, as_spectator: bool)
signal network_cancel_requested

@onready var main_box: VBoxContainer = $Panel/VBox
@onready var start_btn: Button = $Panel/VBox/StartBtn
@onready var online_btn: Button = $Panel/VBox/OnlineBtn
@onready var quit_btn: Button = $Panel/VBox/QuitBtn
var hero_stats_btn: Button = null
var hero_stats_panel: PanelContainer = null
var hero_stats_grid: GridContainer = null

@onready var network_panel: PanelContainer = $Panel/NetworkPanel
@onready var host_port_spin: SpinBox = $Panel/NetworkPanel/Margin/VBox/HostRow/HostPortSpin
@onready var host_btn: Button = $Panel/NetworkPanel/Margin/VBox/HostRow/HostBtn
@onready var join_ip_edit: LineEdit = $Panel/NetworkPanel/Margin/VBox/JoinIPEdit
@onready var join_spectator_check: CheckBox = $Panel/NetworkPanel/Margin/VBox/JoinSpectatorCheck
@onready var join_port_spin: SpinBox = $Panel/NetworkPanel/Margin/VBox/JoinRow/JoinPortSpin
@onready var join_btn: Button = $Panel/NetworkPanel/Margin/VBox/JoinRow/JoinBtn
@onready var net_status: Label = $Panel/NetworkPanel/Margin/VBox/NetStatus
@onready var net_back_btn: Button = $Panel/NetworkPanel/Margin/VBox/NetBackBtn

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	online_btn.pressed.connect(_on_online_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	net_back_btn.pressed.connect(_on_net_back_pressed)
	network_panel.visible = false
	main_box.visible = true
	_build_hero_stats_ui()

func open_menu(message: String = "") -> void:
	visible = true
	get_tree().paused = true
	main_box.visible = true
	network_panel.visible = false
	if hero_stats_panel != null:
		hero_stats_panel.visible = false
	_set_network_buttons_enabled(true)
	if not message.is_empty():
		_show_network_panel(message)

func close_menu() -> void:
	visible = false
	get_tree().paused = false
	network_panel.visible = false
	main_box.visible = true
	if hero_stats_panel != null:
		hero_stats_panel.visible = false

func _build_hero_stats_ui() -> void:
	hero_stats_btn = Button.new()
	hero_stats_btn.text = "HELDEN-STATS"
	hero_stats_btn.custom_minimum_size = Vector2(300, 44)
	hero_stats_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero_stats_btn.add_theme_font_size_override("font_size", 18)
	hero_stats_btn.pressed.connect(_on_hero_stats_pressed)
	main_box.add_child(hero_stats_btn)
	main_box.move_child(hero_stats_btn, quit_btn.get_index())

	hero_stats_panel = PanelContainer.new()
	hero_stats_panel.visible = false
	hero_stats_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_stats_panel.offset_left = 60.0
	hero_stats_panel.offset_top = 40.0
	hero_stats_panel.offset_right = -60.0
	hero_stats_panel.offset_bottom = -40.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.045, 0.055, 0.085, 0.995)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.25, 0.55, 0.9, 0.75)
	panel_style.set_corner_radius_all(14)
	hero_stats_panel.add_theme_stylebox_override("panel", panel_style)
	$Panel.add_child(hero_stats_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	hero_stats_panel.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	body.add_child(header)

	var title := Label.new()
	title.text = "HELDEN-STATS"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.45, 0.82, 1.0, 1.0))
	header.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "HP, Tempo, Fähigkeiten und Passivwerte aller Charaktere"
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.58, 0.64, 0.74, 1.0))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(subtitle)

	var close_btn := Button.new()
	close_btn.text = "SCHLIESSEN"
	close_btn.custom_minimum_size = Vector2(160, 38)
	close_btn.pressed.connect(_close_hero_stats)
	header.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	hero_stats_grid = GridContainer.new()
	hero_stats_grid.columns = 2
	hero_stats_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_stats_grid.add_theme_constant_override("h_separation", 16)
	hero_stats_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(hero_stats_grid)

func _on_hero_stats_pressed() -> void:
	SoundManager.play_sound("click")
	_refresh_hero_stats()
	main_box.visible = false
	hero_stats_panel.visible = true

func _close_hero_stats() -> void:
	SoundManager.play_sound("click")
	hero_stats_panel.visible = false
	main_box.visible = true

func _refresh_hero_stats() -> void:
	if hero_stats_grid == null:
		return
	for child in hero_stats_grid.get_children():
		hero_stats_grid.remove_child(child)
		child.queue_free()
	for hero_key in Global.heroes.keys():
		hero_stats_grid.add_child(_build_hero_stats_card(Global.get_hero(hero_key)))

func _build_hero_stats_card(hero: HeroData) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.125, 0.98)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(hero.color_tint.r, hero.color_tint.g, hero.color_tint.b, 0.75)
	style.set_corner_radius_all(9)
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var title := Label.new()
	title.text = "%s  ·  %s" % [hero.name.to_upper(), hero.role]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", hero.color_tint)
	box.add_child(title)

	var effective_hp := Global.get_effective_base_hp(hero)
	var stats := Label.new()
	stats.text = "HP %d (Basis %d)  ·  Schild %d  ·  Tempo %d  ·  Sprung %d  ·  Extra-Sprünge %d  ·  Schuss %d\nMunition %d  ·  Feuerintervall %.2fs  ·  Nachladen %.1fs" % [
		effective_hp, hero.base_hp, hero.base_shield, int(hero.base_speed),
		int(absf(hero.base_jump_force)), hero.extra_jumps, int(Global.base_damage),
		hero.base_ammo, hero.base_fire_rate_cooldown, hero.base_reload_time,
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1.0))
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)

	var ability := Label.new()
	ability.text = "Aktiv: %s (%.1fs Cooldown) — %s" % [hero.ability_name, hero.ability_cooldown, hero.ability_desc]
	ability.add_theme_font_size_override("font_size", 12)
	ability.add_theme_color_override("font_color", Color(0.52, 0.8, 1.0, 1.0))
	ability.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ability)

	var passive := Label.new()
	passive.text = "Passiv: %s" % hero.passive_desc
	passive.add_theme_font_size_override("font_size", 12)
	passive.add_theme_color_override("font_color", Color(0.95, 0.78, 0.46, 1.0))
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(passive)

	var description := Label.new()
	description.text = hero.description
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color(0.56, 0.6, 0.7, 1.0))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	return card

func _on_start_pressed() -> void:
	SoundManager.play_sound("confirm")
	close_menu()
	start_requested.emit()

func _on_online_pressed() -> void:
	SoundManager.play_sound("click")
	_show_network_panel("")

func _on_quit_pressed() -> void:
	SoundManager.play_sound("click")
	get_tree().quit()

# --- Online-Panel ---

func _show_network_panel(message: String) -> void:
	main_box.visible = false
	network_panel.visible = true
	net_status.text = message
	_set_network_buttons_enabled(true)

func hide_network_panel() -> void:
	network_panel.visible = false
	main_box.visible = true

func set_network_status(text: String, enable_buttons: bool = false) -> void:
	net_status.text = text
	if enable_buttons:
		_set_network_buttons_enabled(true)

func _set_network_buttons_enabled(enabled: bool) -> void:
	host_btn.disabled = not enabled
	join_btn.disabled = not enabled
	join_spectator_check.disabled = not enabled
	net_back_btn.disabled = false

func _on_host_pressed() -> void:
	SoundManager.play_sound("confirm")
	net_status.text = "Starte Host auf Port %d ..." % int(host_port_spin.value)
	_set_network_buttons_enabled(false)
	host_requested.emit(int(host_port_spin.value))

func _on_join_pressed() -> void:
	var address := join_ip_edit.text.strip_edges()
	if address.is_empty():
		net_status.text = "Bitte die IP-Adresse des Hosts eingeben."
		return
	var as_spectator := join_spectator_check.button_pressed
	SoundManager.play_sound("confirm")
	net_status.text = "Verbinde zu %s:%d ..." % [address, int(join_port_spin.value)]
	_set_network_buttons_enabled(false)
	join_requested.emit(address, int(join_port_spin.value), as_spectator)

func _on_net_back_pressed() -> void:
	SoundManager.play_sound("click")
	network_cancel_requested.emit()
	hide_network_panel()
	_set_network_buttons_enabled(true)
