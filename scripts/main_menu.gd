class_name MainMenu
extends CanvasLayer

# Wird ausgelöst, wenn der Spieler im Menü auf "Spiel starten" klickt.
signal start_requested
# Online-Wünsche: Der Main-Node baut die Verbindung auf und öffnet die Lobby.
signal host_requested(port: int)
signal join_requested(address: String, port: int, as_spectator: bool)
signal network_cancel_requested
# Online über Epic Online Services (Lobby-Code statt IP).
signal host_online_requested
signal join_online_requested(code: String, as_spectator: bool)
signal options_requested

@onready var main_box: VBoxContainer = $Panel/VBox
@onready var start_btn: Button = $Panel/VBox/StartBtn
@onready var online_btn: Button = $Panel/VBox/OnlineBtn
@onready var quit_btn: Button = $Panel/VBox/QuitBtn
var hero_stats_btn: Button = null
var hero_stats_panel: PanelContainer = null
var hero_stats_grid: GridContainer = null
var options_btn: Button = null
var wiki_btn: Button = null

# Das Wiki (aus README.md gebaut, siehe tools/build_wiki.py) liegt im PCK.
# Der Browser kann dort nicht lesen, darum wird es vor dem Öffnen nach
# user:// kopiert. Eine wiki.html im Ordner der Exe hat Vorrang.
const WIKI_SOURCE: String = "res://docs/wiki.html"
const WIKI_COPY: String = "user://wiki.html"
const WIKI_FILE_NAME: String = "wiki.html"

@onready var network_panel: PanelContainer = $Panel/NetworkPanel
@onready var host_port_spin: SpinBox = $Panel/NetworkPanel/Margin/VBox/HostRow/HostPortSpin
@onready var host_btn: Button = $Panel/NetworkPanel/Margin/VBox/HostRow/HostBtn
@onready var join_ip_edit: LineEdit = $Panel/NetworkPanel/Margin/VBox/JoinIPEdit
@onready var join_spectator_check: CheckBox = $Panel/NetworkPanel/Margin/VBox/JoinSpectatorCheck
@onready var join_port_spin: SpinBox = $Panel/NetworkPanel/Margin/VBox/JoinRow/JoinPortSpin
@onready var join_btn: Button = $Panel/NetworkPanel/Margin/VBox/JoinRow/JoinBtn
@onready var net_status: Label = $Panel/NetworkPanel/Margin/VBox/NetStatus
@onready var net_back_btn: Button = $Panel/NetworkPanel/Margin/VBox/NetBackBtn
var epic_host_btn: Button = null
var epic_code_edit: LineEdit = null
var epic_join_btn: Button = null
var epic_hint: Label = null

func _ready() -> void:
	start_btn.pressed.connect(_on_start_pressed)
	online_btn.pressed.connect(_on_online_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	net_back_btn.pressed.connect(_on_net_back_pressed)
	network_panel.visible = false
	main_box.visible = true
	_build_epic_section()
	_build_hero_stats_ui()
	_build_wiki_button()
	_build_options_button()
	_build_version_label()
	_style_menu_buttons()
	main_box.child_entered_tree.connect(_on_menu_child_added)
	var backdrop := get_node_or_null("Panel/Backdrop") as MainMenuBackdrop
	if backdrop != null:
		backdrop.frame_target = main_box

func _build_options_button() -> void:
	options_btn = Button.new()
	options_btn.name = "OptionsBtn"
	options_btn.text = "OPTIONEN"
	options_btn.custom_minimum_size = Vector2(360, 56)
	options_btn.pressed.connect(_on_options_pressed)
	main_box.add_child(options_btn)
	main_box.move_child(options_btn, quit_btn.get_index())

func _on_options_pressed() -> void:
	SoundManager.play_sound("click")
	options_requested.emit()

func _build_wiki_button() -> void:
	wiki_btn = Button.new()
	wiki_btn.name = "WikiBtn"
	wiki_btn.text = "WIKI"
	wiki_btn.tooltip_text = "Anleitung mit allen Funktionen im Browser öffnen."
	wiki_btn.custom_minimum_size = Vector2(360, 56)
	wiki_btn.pressed.connect(_on_wiki_pressed)
	main_box.add_child(wiki_btn)
	main_box.move_child(wiki_btn, quit_btn.get_index())

func _on_wiki_pressed() -> void:
	SoundManager.play_sound("click")
	# 1. wiki.html neben der Exe (nur im Export): lässt sich ohne Neuexport austauschen.
	if OS.has_feature("template"):
		var beside_exe := OS.get_executable_path().get_base_dir().path_join(WIKI_FILE_NAME)
		if FileAccess.file_exists(beside_exe):
			OS.shell_open(beside_exe)
			return
	# 2. Eingebaute Kopie aus dem PCK. Der Browser kann res:// nicht lesen, darum
	# wird sie bei jedem Klick frisch nach user:// geschrieben (nie eine alte Kopie öffnen).
	var html := FileAccess.get_file_as_string(WIKI_SOURCE)
	if html.is_empty():
		_show_wiki_error("Das Wiki ist in diesem Build nicht enthalten.\nLege %s in den Ordner der Exe." % WIKI_FILE_NAME)
		return
	var file := FileAccess.open(WIKI_COPY, FileAccess.WRITE)
	if file == null:
		_show_wiki_error("Das Wiki konnte nicht nach %s geschrieben werden (%s)." % [ProjectSettings.globalize_path(WIKI_COPY), error_string(FileAccess.get_open_error())])
		return
	file.store_string(html)
	file.close()
	OS.shell_open(ProjectSettings.globalize_path(WIKI_COPY))

func _show_wiki_error(text: String) -> void:
	push_warning(text)
	var dialog := AcceptDialog.new()
	dialog.title = "Wiki"
	dialog.dialog_text = text
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

# Platinen-Look für alle Knöpfe der Menüspalte, auch für später ergänzte.
func _style_menu_buttons() -> void:
	for child in main_box.get_children():
		var button := child as Button
		if button != null:
			WorkshopStyle.style_button(button, button == start_btn, 22 if button == start_btn else 20)

func _on_menu_child_added(node: Node) -> void:
	var button := node as Button
	if button != null:
		WorkshopStyle.style_button(button, false, 20)
		button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 56.0)

func _build_version_label() -> void:
	var version_label := Label.new()
	version_label.name = "VersionLabel"
	version_label.text = BuildInfo.get_display_text()
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78, 0.9))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	$Panel.add_child(version_label)

func open_menu(message: String = "") -> void:
	SoundManager.stop_music()
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
	hero_stats_btn.text = "HELDEN"
	hero_stats_btn.custom_minimum_size = Vector2(360, 56)
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
	ability.text = "Aktiv: %s (%.1fs Cooldown) — %s\n%s" % [hero.ability_name, hero.ability_cooldown, hero.ability_desc, Global.get_hero_ability_details(hero)]
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
	_refresh_epic_section(enabled)
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

# --- Epic-Online (Lobby-Code) ---

# Wird per Code oben ins Online-Panel eingefügt, damit die Szene unverändert bleibt.
func _build_epic_section() -> void:
	var vbox := $Panel/NetworkPanel/Margin/VBox as VBoxContainer
	var header := Label.new()
	header.text = "Übers Internet (Epic, mit Code)"
	header.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55, 1))
	header.add_theme_font_size_override("font_size", 17)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	epic_host_btn = Button.new()
	epic_host_btn.text = "Online hosten"
	epic_host_btn.custom_minimum_size = Vector2(0, 42)
	epic_host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	epic_host_btn.pressed.connect(_on_epic_host_pressed)
	epic_code_edit = LineEdit.new()
	epic_code_edit.placeholder_text = "Code, z. B. K7QX2M"
	epic_code_edit.max_length = 8
	epic_code_edit.custom_minimum_size = Vector2(170, 40)
	epic_code_edit.text_submitted.connect(func(_t: String): _on_epic_join_pressed())
	epic_join_btn = Button.new()
	epic_join_btn.text = "Mit Code beitreten"
	epic_join_btn.custom_minimum_size = Vector2(0, 42)
	epic_join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	epic_join_btn.pressed.connect(_on_epic_join_pressed)
	row.add_child(epic_host_btn)
	row.add_child(epic_code_edit)
	row.add_child(epic_join_btn)
	epic_hint = Label.new()
	epic_hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	epic_hint.add_theme_font_size_override("font_size", 12)
	epic_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sep := HSeparator.new()
	# Direkt unter Titel und Info einfügen, vor dem LAN-Teil.
	var insert_at := 0
	var host_header := vbox.get_node_or_null("HostHeader")
	if host_header != null:
		insert_at = host_header.get_index()
	for node in [header, row, epic_hint, sep]:
		vbox.add_child(node)
		vbox.move_child(node, insert_at)
		insert_at += 1
	_refresh_epic_section(true)

func _refresh_epic_section(enabled: bool) -> void:
	if epic_host_btn == null:
		return
	var problem := NetworkManager.get_online_setup_problem()
	var online_ready := problem.is_empty()
	# Fortschritt der Epic-Verbindung live in der Statuszeile zeigen.
	var epic := NetworkManager.get_node_or_null("EpicOnline")
	if epic != null and not epic.status_changed.is_connected(_on_epic_status):
		epic.status_changed.connect(_on_epic_status)
	epic_host_btn.disabled = not (enabled and online_ready)
	epic_join_btn.disabled = not (enabled and online_ready)
	epic_code_edit.editable = enabled and online_ready
	if online_ready:
		epic_hint.text = "Host klickt \"Online hosten\" und schickt den Code (steht oben in der Lobby). Kein Portfreigeben nötig."
	else:
		epic_hint.text = "Nicht verfügbar: " + problem

func _on_epic_host_pressed() -> void:
	SoundManager.play_sound("confirm")
	net_status.text = "Erstelle Online-Spiel über Epic ..."
	_set_network_buttons_enabled(false)
	host_online_requested.emit()

func _on_epic_join_pressed() -> void:
	var code := epic_code_edit.text.strip_edges().to_upper()
	if code.is_empty():
		net_status.text = "Bitte den Code vom Host eingeben."
		return
	SoundManager.play_sound("confirm")
	net_status.text = "Suche Spiel %s über Epic ..." % code
	_set_network_buttons_enabled(false)
	join_online_requested.emit(code, join_spectator_check.button_pressed)

func _on_epic_status(text: String) -> void:
	if network_panel.visible:
		net_status.text = text
