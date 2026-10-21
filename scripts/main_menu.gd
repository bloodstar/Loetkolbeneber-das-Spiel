class_name MainMenu
extends CanvasLayer

# Wird ausgelöst, wenn der Spieler im Menü auf "Spiel starten" klickt.
signal start_requested
# Online-Wünsche: Der Main-Node baut die Verbindung auf und öffnet die Lobby.
signal host_requested(port: int)
signal join_requested(address: String, port: int)
signal network_cancel_requested

@onready var main_box: VBoxContainer = $Panel/VBox
@onready var start_btn: Button = $Panel/VBox/StartBtn
@onready var online_btn: Button = $Panel/VBox/OnlineBtn
@onready var quit_btn: Button = $Panel/VBox/QuitBtn

@onready var network_panel: PanelContainer = $Panel/NetworkPanel
@onready var host_port_spin: SpinBox = $Panel/NetworkPanel/Margin/VBox/HostRow/HostPortSpin
@onready var host_btn: Button = $Panel/NetworkPanel/Margin/VBox/HostRow/HostBtn
@onready var join_ip_edit: LineEdit = $Panel/NetworkPanel/Margin/VBox/JoinIPEdit
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

func open_menu(message: String = "") -> void:
	visible = true
	get_tree().paused = true
	main_box.visible = true
	network_panel.visible = false
	_set_network_buttons_enabled(true)
	if not message.is_empty():
		_show_network_panel(message)

func close_menu() -> void:
	visible = false
	get_tree().paused = false
	network_panel.visible = false
	main_box.visible = true

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
	SoundManager.play_sound("confirm")
	net_status.text = "Verbinde zu %s:%d ..." % [address, int(join_port_spin.value)]
	_set_network_buttons_enabled(false)
	join_requested.emit(address, int(join_port_spin.value))

func _on_net_back_pressed() -> void:
	SoundManager.play_sound("click")
	network_cancel_requested.emit()
	hide_network_panel()
	_set_network_buttons_enabled(true)
