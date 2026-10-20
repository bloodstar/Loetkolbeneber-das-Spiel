class_name MainGame
extends Node2D

@export var player_scene: PackedScene = preload("res://scenes/player/player.tscn")

@onready var level_generator: LevelGenerator = $ProceduralLevel
@onready var camera: DynamicCamera = $DynamicCamera
@onready var hud: HUD = $HUD
@onready var card_draft_ui: CardDraftUI = $CardDraftUI
@onready var hero_select_dialog: HeroSelectDialog = $HeroSelectDialog
@onready var sudden_death_timer: Timer = $SuddenDeathTimer
@onready var lava_overlay: ColorRect = $LavaOverlay
@onready var game_manager: Node = $GameManager # Neuer Game Manager Node

var p1: Player = null
var p2: Player = null
var is_sudden_death: bool = false
var lava_y_pos: float = 900.0
var wins_to_start: int = 3 # Standardmäßig 3 Siege
var p1_hero_id: String = ""
var p2_hero_id: String = ""

func _ready() -> void:
	print("--- MAIN.GD: _ready() wurde ausgeführt. Starte Setup-Phase. ---")
	# Wire signals
	Global.round_ended.connect(_on_round_ended)
	Global.card_selected.connect(_on_card_selected)
	card_draft_ui.draft_sequence_finished.connect(_on_draft_sequence_finished)
	hero_select_dialog.heroes_chosen.connect(_start_setup_phase) # Startet jetzt mit der Setup-Phase
	sudden_death_timer.timeout.connect(_start_sudden_death)
	
	lava_overlay.visible = false
	# Starte direkt die Setup-Phase, um sicherzustellen, dass das Menü initialisiert wird.
	_start_setup_phase()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_bot") and not event.is_echo():
		Global.toggle_bot()
		# If in middle of round, update p2's bot status
		if p2 and is_instance_valid(p2):
			p2.is_bot = Global.is_bot_enabled
			_update_p2_bot_controller()
	
	if event.is_action_pressed("restart_game") and not event.is_echo():
		Global.reset_match()
		# Startet den gesamten Setup-Prozess neu
		_start_setup_phase()
	
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_H:
		# Öffnet Dialog, falls nicht bereits in der Setup-Phase
		if not hero_select_dialog.is_visible():
			hero_select_dialog.open_dialog()

# --- Setup Phase Management ---

func _start_setup_phase() -> void:
	# 1. Setze die gewünschte Anzahl an Siegen (Muss von der UI/Global gesetzt werden)
	# Hier müsste die Logik zur Übernahme der Sieg-Anzahl von der UI kommen.
	# Wir setzen einen Standardwert, der von der UI überschrieben werden sollte.
	wins_to_start = 3 
	
	# 2. Starte die Hero Selection
	hero_select_dialog.open_dialog()

func _start_fresh_round() -> void:
	# 1. Level regenerieren
	level_generator.generate_level()
	
	# 2. Reset Sudden Death
	is_sudden_death = false
	lava_overlay.visible = false
	lava_y_pos = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE)
	lava_overlay.position.y = lava_y_pos
	sudden_death_timer.start(38.0)
	hud.set_sudden_death(false)
	
	_spawn_players()

func _spawn_players() -> void:
	# Clean up any lingering players
	if p1 and is_instance_valid(p1):
		p1.queue_free()
	if p2 and is_instance_valid(p2):
		p2.queue_free()
	
	# Spawn P1
	p1 = player_scene.instantiate()
	p1.player_index = 1
	p1.is_bot = false
	add_child(p1)
	p1.global_position = level_generator.p1_spawn_pos
	p1.died.connect(_on_player_died)
	
	# Spawn P2
	p2 = player_scene.instantiate()
	p2.player_index = 2
	p2.is_bot = Global.is_bot_enabled
	add_child(p2)
	p2.global_position = level_generator.p2_spawn_pos
	p2.died.connect(_on_player_died)
	
	# Cross-reference opponents
	p1.opponent = p2
	p2.opponent = p1
	
	_update_p2_bot_controller()
	
	# Connect Camera
	camera.targets.clear()
	camera.add_target(p1)
	camera.add_target(p2)
	
	# Connect HUD
	hud.connect_player_signals(p1, p2)
	hud.update_all()

func _update_p2_bot_controller() -> void:
	if not p2 or not is_instance_valid(p2):
		return
	
	var existing_ai = p2.get_node_or_null("AIController")
	if p2.is_bot:
		if not existing_ai:
			var ai = AIController.new()
			ai.name = "AIController"
			p2.add_child(ai)
	else:
		if existing_ai:
			existing_ai.queue_free()

func _process(delta: float) -> void:
	if is_sudden_death:
		# Lava rises steadily
		lava_y_pos -= 35.0 * delta
		lava_overlay.position.y = lava_y_pos
		lava_overlay.size.y = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE) - lava_y_pos + 100.0
		
		# Check if players touch lava
		if p1 and is_instance_valid(p1) and p1.global_position.y > lava_y_pos:
			p1.take_damage(40.0 * delta, Vector2(0, -100.0))
		if p2 and is_instance_valid(p2) and p2.global_position.y > lava_y_pos:
			p2.take_damage(40.0 * delta, Vector2(0, -100.0))

func _start_sudden_death() -> void:
	is_sudden_death = true
	lava_overlay.visible = true
	lava_overlay.position.x = 0
	lava_overlay.size.x = (level_generator.MAP_WIDTH * level_generator.TILE_SIZE)
	lava_y_pos = (level_generator.MAP_HEIGHT * level_generator.TILE_SIZE)
	hud.set_sudden_death(true)
	SoundManager.play_sound("explosion", 0.1, 2.0)

func _on_player_died(dead_player_index: int) -> void:
	camera.shake(0.55)
	var winner_index = 2 if dead_player_index == 1 else 1
	Global.award_round(winner_index)

func _on_round_ended(loser_index: int) -> void:
	# All losers draft sequentially and publicly
	card_draft_ui.start_draft_sequence([loser_index])

func _on_card_selected(_p_idx: int, _card: CardData) -> void:
	pass

func _on_draft_sequence_finished() -> void:
	# Advance to next round with freshly generated Mario stage!
	_start_fresh_round()
