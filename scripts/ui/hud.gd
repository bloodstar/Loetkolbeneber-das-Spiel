class_name HUD
extends CanvasLayer

# Player 1 UI
@onready var p1_name_label: Label = $Top/P1_Box/NameLabel
@onready var p1_hp_bar: ProgressBar = $Top/P1_Box/HPBar
@onready var p1_shield_bar: ProgressBar = $Top/P1_Box/ShieldBar
@onready var p1_ammo_label: Label = $Top/P1_Box/AmmoLabel
@onready var p1_ability_label: Label = $Top/P1_Box/AbilityLabel
@onready var p1_cards_label: Label = $Top/P1_Box/CardsLabel

# Player 2 UI
@onready var p2_name_label: Label = $Top/P2_Box/NameLabel
@onready var p2_hp_bar: ProgressBar = $Top/P2_Box/HPBar
@onready var p2_shield_bar: ProgressBar = $Top/P2_Box/ShieldBar
@onready var p2_ammo_label: Label = $Top/P2_Box/AmmoLabel
@onready var p2_ability_label: Label = $Top/P2_Box/AbilityLabel
@onready var p2_cards_label: Label = $Top/P2_Box/CardsLabel

# Center UI
@onready var score_label: Label = $Top/Center_Box/ScoreLabel
@onready var sudden_death_label: Label = $Top/Center_Box/SuddenDeathLabel

# Game Over Banner
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var winner_label: Label = $GameOverPanel/VBox/WinnerLabel
@onready var restart_btn: Button = $GameOverPanel/VBox/RestartBtn

# Start-Countdown
@onready var countdown_label: Label = $CountdownLabel

func _ready() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false
	restart_btn.pressed.connect(_on_restart_pressed)
	
	Global.score_changed.connect(_on_score_changed)
	Global.match_over.connect(_on_match_over)
	Global.bot_mode_toggled.connect(_on_bot_mode_toggled)
	Global.score_to_win_changed.connect(_on_score_to_win_changed)
	
	update_all()

func update_all() -> void:
	var h1 = Global.get_hero(Global.p1_hero_id)
	var h2 = Global.get_hero(Global.p2_hero_id)
	
	p1_name_label.text = "P1: %s (%s)" % [h1.name, h1.role]
	var p2_tag = "[BOT]" if Global.is_bot_enabled else "[P2]"
	p2_name_label.text = "%s %s (%s)" % [p2_tag, h2.name, h2.role]
	restart_btn.text = "HAUPTMENÜ" if Global.network_mode else "NOCHMAL"
	
	_on_score_changed(Global.p1_score, Global.p2_score)
	_update_cards_count()

func _on_score_to_win_changed(_wins: int) -> void:
	_on_score_changed(Global.p1_score, Global.p2_score)

func _update_cards_count() -> void:
	p1_cards_label.text = "Upgrades: %d" % Global.p1_cards.size()
	p2_cards_label.text = "Upgrades: %d" % Global.p2_cards.size()

func connect_player_signals(p1: Player, p2: Player) -> void:
	if p1:
		p1.health_changed.connect(func(cur_h, max_h, cur_s, max_s):
			p1_hp_bar.max_value = max_h
			p1_hp_bar.value = cur_h
			p1_shield_bar.max_value = maxf(max_s, 1.0)
			p1_shield_bar.value = cur_s
			p1_shield_bar.visible = (max_s > 0.0)
		)
		p1.ammo_changed.connect(func(cur, max_a):
			p1_ammo_label.text = "Munition: %d / %d" % [cur, max_a]
		)
		p1.ability_cooldown_updated.connect(func(cur, max_c):
			if cur <= 0.0:
				p1_ability_label.text = "[RMB / E / Q] %s: BEREIT!" % p1.ability_name
			else:
				p1_ability_label.text = "%s: %.1fs" % [p1.ability_name, cur]
		)
	
	if p2:
		p2.health_changed.connect(func(cur_h, max_h, cur_s, max_s):
			p2_hp_bar.max_value = max_h
			p2_hp_bar.value = cur_h
			p2_shield_bar.max_value = maxf(max_s, 1.0)
			p2_shield_bar.value = cur_s
			p2_shield_bar.visible = (max_s > 0.0)
		)
		p2.ammo_changed.connect(func(cur, max_a):
			p2_ammo_label.text = "Munition: %d / %d" % [cur, max_a]
		)
		p2.ability_cooldown_updated.connect(func(cur, max_c):
			if cur <= 0.0:
				p2_ability_label.text = "%s: BEREIT!" % p2.ability_name
			else:
				p2_ability_label.text = "%s: %.1fs" % [p2.ability_name, cur]
		)

func _on_score_changed(s1: int, s2: int) -> void:
	score_label.text = "P1  [ %d  :  %d ]  P2\n(Ziel: %d Siege)" % [s1, s2, Global.score_to_win]
	_update_cards_count()

func set_sudden_death(active: bool) -> void:
	sudden_death_label.visible = active

func reset_for_round() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false

func show_countdown_number(value: int) -> void:
	countdown_label.text = str(value)
	countdown_label.modulate = Color(1.0, 0.75, 0.2, 1.0)
	countdown_label.visible = true

func show_countdown_go() -> void:
	countdown_label.text = "LOS!"
	countdown_label.modulate = Color(0.45, 1.0, 0.45, 1.0)
	countdown_label.visible = true

func hide_countdown() -> void:
	countdown_label.visible = false

func _on_bot_mode_toggled(enabled: bool) -> void:
	# Die Bot-Steuerung wird nur noch in der Lobby gewählt. Hier wird lediglich
	# die Anzeige aktualisiert, falls sich der Zustand vor dem Rundenstart ändert.
	var h2 = Global.get_hero(Global.p2_hero_id)
	var p2_tag = "[BOT]" if enabled else "[P2]"
	p2_name_label.text = "%s %s (%s)" % [p2_tag, h2.name, h2.role]

func _on_match_over(winner_idx: int) -> void:
	game_over_panel.visible = true
	var winner_str = "SPIELER 1" if winner_idx == 1 else ("BOT" if Global.is_bot_enabled else "SPIELER 2")
	winner_label.text = "🏆 %s GEWINNT DAS MATCH! 🏆" % winner_str
	if Global.network_mode:
		restart_btn.text = "HAUPTMENÜ"
	SoundManager.play_sound("confirm")

func _on_restart_pressed() -> void:
	SoundManager.play_sound("click")
	if Global.network_mode:
		# Online-Partie beenden: Verbindung schließen und sauber ins Menü zurück.
		NetworkManager.disconnect_peer()
		Global.network_mode = false
		Global.remote_connected = false
		Global.set_local_player(1)
		Global.current_state = Global.GameState.MENU
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	Global.reset_match()
	get_tree().reload_current_scene()
