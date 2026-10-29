class_name HUD
extends CanvasLayer

# Wird ausgelöst, wenn im Game-Over-Banner "Nochmal" geklickt wird. Der Main-Node
# räumt daraufhin in-place auf, ohne die Szene neu zu laden.
signal restart_requested
# Host-Verbesserung: Match mit erhöhtem Ziel weiterführen.
signal continue_requested

const RadarChartScript = preload("res://scripts/ui/radar_chart.gd")

@onready var player_boxes: HBoxContainer = $Top/PlayerBoxes
@onready var score_label: Label = $Top/Center_Box/ScoreLabel
@onready var sudden_death_label: Label = $Top/Center_Box/SuddenDeathLabel
@onready var ping_label: Label = $Top/Center_Box/PingLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_vbox: VBoxContainer = $GameOverPanel/VBox
@onready var winner_label: Label = $GameOverPanel/VBox/WinnerLabel
@onready var continue_btn: Button = $GameOverPanel/VBox/ContinueBtn
@onready var restart_btn: Button = $GameOverPanel/VBox/RestartBtn

@onready var countdown_label: Label = $CountdownLabel

# player_index -> { name, hp, shield, ammo, ability, cards }
var boxes: Dictionary = {}
var tracked_players: Array[Player] = []

# Fortschrittsbalken bis zum Match-Sieg; der aktuelle Punktestand steht
# direkt rechts neben jedem Balken.
var _score_bars: GridContainer = null
var _score_bar_rows: Array[Dictionary] = []

# Eigene Upgrade-Karten: dauerhafte Icon-Leiste unten links + Tab-Overlay.
var _upgrade_bar: PanelContainer = null
var _upgrade_flow: HFlowContainer = null
var _upgrade_title: Label = null
var _tab_overlay: Control = null
# Eigene Ebene über der Kartenwahl (CardDraftUI liegt auf Layer 10), damit
# Tab auch während der Upgrade-Phase sichtbar ist.
var _tab_layer: CanvasLayer = null
# Die Punkteübersicht oben rechts (Center_Box) wandert während der Kartenwahl
# auf diese Ebene über dem Draft-Hintergrund und danach zurück in die Top-Leiste.
var _score_layer: CanvasLayer = null
var _score_holder: HBoxContainer = null
var _score_box_index: int = -1
# Übersicht aller Spieler nach Match-Ende (Button im Game-Over-Panel).
var _overview: Control = null
var _tab_scroll: ScrollContainer = null
var _overview_scroll: ScrollContainer = null
var _overview_content: VBoxContainer = null
var _overview_tabs: HBoxContainer = null
var _overview_button: Button = null
var _tab_content: VBoxContainer = null
var _tab_refresh_timer: float = 0.0
# Ohne Blind Pick lassen sich im Tab-Overlay auch andere Spieler ansehen.
var _tab_player_tabs: HBoxContainer = null
var _tab_view_slot: int = -1
var _tab_player_tabs_key: String = ""

# Level Modifier UI
var _modifier_container: VBoxContainer = null
var _event_label: Label = null
var _event_timer: float = 0.0
var _stamp_overlay: Control = null

const TAB_REFRESH_INTERVAL: float = 0.35
const HUD_RELOAD_RING_SIZE: float = 14.0
const HUD_RELOAD_COLOR: Color = Color(0.35, 0.86, 1.0, 0.96)
const MAX_UPGRADE_ICONS: int = 16

func _ready() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false
	restart_btn.pressed.connect(_on_restart_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)

	Global.scores_changed.connect(_on_scores_changed)
	Global.match_over.connect(_on_match_over)
	Global.scoring_config_changed.connect(_on_scoring_config_changed)
	Global.match_target_changed.connect(_on_match_target_changed)
	Global.card_selected.connect(_on_card_selected)
	NetworkManager.ping_updated.connect(_update_ping)

	_build_upgrade_bar()
	_build_tab_overlay()
	_build_score_bars()
	_build_modifier_ui()
	_update_ping()
	_update_score()

# Mausrad scrollt das offene Stats-Fenster. Das Tab-Overlay ignoriert die Maus
# (Klicks sollen ins Spiel bzw. die Kartenwahl durchgehen), daher von Hand.
const STATS_WHEEL_STEP: int = 70

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _tab_overlay != null and _tab_overlay.visible:
		if key.keycode >= KEY_1 and key.keycode <= KEY_9 and _can_browse_tab_players():
			var slots: Array[int] = Global.get_active_player_indices()
			var idx := int(key.keycode - KEY_1)
			if idx < slots.size():
				_select_tab_player(slots[idx])
			get_viewport().set_input_as_handled()
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var target: ScrollContainer = null
	if _overview != null and _overview.visible:
		target = _overview_scroll
	elif _tab_overlay != null and _tab_overlay.visible:
		target = _tab_scroll
	if target == null:
		return
	var dir := -1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1
	target.scroll_vertical += dir * STATS_WHEEL_STEP
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_update_reload_indicators()
	_sync_score_box_layer()
	if _event_timer > 0.0:
		_event_timer -= delta
		if _event_timer <= 0.0 and _event_label != null:
			_event_label.visible = false

	if _overview != null and _overview.visible and not game_over_panel.visible:
		_overview.visible = false
	if _tab_overlay == null:
		return
	var wants_overlay := Input.is_physical_key_pressed(KEY_TAB) and _can_show_tab_overlay()
	if wants_overlay:
		if not _tab_overlay.visible:
			_tab_view_slot = _tab_target_slot()
			_refresh_tab_overlay()
			_tab_overlay.visible = true
			_tab_refresh_timer = 0.0
			_refresh_hover_under_overlay()
		_tab_refresh_timer -= delta
		if _tab_refresh_timer <= 0.0:
			_refresh_tab_overlay()
			_tab_refresh_timer = TAB_REFRESH_INTERVAL
	elif _tab_overlay.visible:
		_tab_overlay.visible = false

# Baut pro aktivem Spieler eine kompakte Statusbox. Wird vom Main-Node nach dem
# Spawnen aufgerufen und unterstützt 2 bis 6 Spieler.
func setup_players(players: Array) -> void:
	for child in player_boxes.get_children():
		player_boxes.remove_child(child)
		child.queue_free()
	boxes.clear()
	tracked_players.clear()

	for p in players:
		if not is_instance_valid(p):
			continue
		tracked_players.append(p)
		var ui := _build_box(p.player_index)
		_connect_player(p, ui)

	update_all()
	_update_ping()
	_refresh_upgrade_bar()

func _build_box(index: int) -> Dictionary:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(150, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	player_boxes.add_child(box)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 12)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100.0
	hp_bar.value = 100.0
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.2, 0.75, 0.25, 1.0)
	hp_style.set_corner_radius_all(4)
	hp_bar.add_theme_stylebox_override("fill", hp_style)
	box.add_child(hp_bar)

	var shield_bar := ProgressBar.new()
	shield_bar.custom_minimum_size = Vector2(0, 6)
	shield_bar.show_percentage = false
	shield_bar.max_value = 1.0
	shield_bar.visible = false
	var shield_style := StyleBoxFlat.new()
	shield_style.bg_color = Color(0.2, 0.6, 1.0, 1.0)
	shield_style.set_corner_radius_all(3)
	shield_bar.add_theme_stylebox_override("fill", shield_style)
	box.add_child(shield_bar)

	# Munitionszeile: Text plus Nachlade-Kreis wie am Spieler. Während des
	# Nachladens ersetzt der Kreis die Zahlen und zeigt den Fortschritt.
	# Munition, Fähigkeit, Block und Nahkampf bleiben in der Übersicht
	# ausgeblendet; die Anzeigen am Spieler und im Tab-Bogen zeigen sie.
	var ammo_row := HBoxContainer.new()
	ammo_row.add_theme_constant_override("separation", 4)
	ammo_row.visible = false
	box.add_child(ammo_row)

	var ammo_label := Label.new()
	ammo_label.add_theme_font_size_override("font_size", 11)
	ammo_row.add_child(ammo_label)

	var ammo_ring := Control.new()
	ammo_ring.custom_minimum_size = Vector2(HUD_RELOAD_RING_SIZE, HUD_RELOAD_RING_SIZE)
	ammo_ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_ring.visible = false
	ammo_row.add_child(ammo_ring)

	var ability_label := Label.new()
	ability_label.add_theme_font_size_override("font_size", 11)
	ability_label.visible = false
	box.add_child(ability_label)

	var block_label := Label.new()
	block_label.add_theme_font_size_override("font_size", 11)
	block_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	block_label.text = "Block [Q]: BEREIT"
	block_label.visible = false
	box.add_child(block_label)

	var melee_label := Label.new()
	melee_label.add_theme_font_size_override("font_size", 11)
	melee_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.42, 1.0))
	melee_label.visible = false
	box.add_child(melee_label)

	var cards_label := Label.new()
	cards_label.add_theme_font_size_override("font_size", 10)
	cards_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	box.add_child(cards_label)

	var ui := {
		"box": box,
		"name": name_label,
		"hp": hp_bar,
		"shield": shield_bar,
		"ammo": ammo_label,
		"ammo_ring": ammo_ring,
		"ability": ability_label,
		"block": block_label,
		"melee": melee_label,
		"cards": cards_label,
	}
	boxes[index] = ui
	return ui

func _connect_player(player: Player, ui: Dictionary) -> void:
	player.health_changed.connect(func(cur_h, max_h, cur_s, max_s):
		ui["hp"].max_value = maxf(max_h, 1.0)
		ui["hp"].value = cur_h
		ui["shield"].max_value = maxf(max_s, 1.0)
		ui["shield"].value = cur_s
		ui["shield"].visible = max_s > 0.0
	)
	player.ammo_changed.connect(func(_cur, _max_a):
		_update_ammo_row(ui, player)
	)
	ui["ammo_ring"].draw.connect(_draw_hud_reload_ring.bind(ui["ammo_ring"], player))
	player.ability_cooldown_updated.connect(func(cur, _max_c):
		if cur <= 0.0:
			ui["ability"].text = "%s: BEREIT!" % player.ability_name
		else:
			ui["ability"].text = "%s: %.1fs" % [player.ability_name, cur]
	)
	player.block_state_changed.connect(func(active, cur, _max_c):
		ui["block"].text = _block_text(active, cur)
	)

func update_all() -> void:
	for p in tracked_players:
		if not is_instance_valid(p):
			continue
		var ui: Dictionary = boxes.get(p.player_index, {})
		if ui.is_empty():
			continue
		var hero: HeroData = Global.get_hero(Global.get_player_hero_id(p.player_index))
		var tag := ""
		if Global.is_team_mode():
			var member := "DU" if (Global.network_mode and p.player_index == Global.local_player_index) else ("BOT" if Global.is_bot_slot(p.player_index) else "P%d" % p.player_index)
			tag = "[%s·%s] " % [Global.get_team_name(p.team_id), member]
		elif Global.network_mode and p.player_index == Global.local_player_index:
			tag = "[DU] "
		elif Global.is_bot_slot(p.player_index):
			tag = "[BOT] "
		else:
			tag = "[P%d] " % p.player_index
		ui["name"].text = "%s%s" % [tag, hero.name]
		if Global.is_team_mode():
			ui["name"].add_theme_color_override("font_color", Global.get_team_color(p.team_id))
		else:
			ui["name"].add_theme_color_override("font_color", hero.color_tint)
		_update_ammo_row(ui, p)
		if p.ability_timer <= 0.0:
			ui["ability"].text = "%s: BEREIT!" % p.ability_name
		else:
			ui["ability"].text = "%s: %.1fs" % [p.ability_name, p.ability_timer]
		ui["block"].text = _block_text(p.is_blocking, p.block_cooldown_timer)
		ui["melee"].text = _melee_text(p)
		ui["cards"].text = "Upgrades: %d" % Global.get_player_cards(p.player_index).size()
	_update_score()

func _ammo_text(current: int, maximum: int, reloading: bool) -> String:
	if reloading:
		return "Munition:"
	return "Munition: %d / %d" % [current, maximum]

func _update_ammo_row(ui: Dictionary, p: Player) -> void:
	ui["ammo"].text = _ammo_text(p.current_ammo, p.max_ammo, p.is_reloading)
	var ring: Control = ui["ammo_ring"]
	ring.visible = p.is_reloading
	if ring.visible:
		ring.queue_redraw()

# Hält Text und Nachlade-Kreis jeden Frame aktuell. Clients bekommen
# is_reloading/reload_timer per Sync, ohne dass ammo_changed feuert.
func _update_reload_indicators() -> void:
	for p in tracked_players:
		if not is_instance_valid(p):
			continue
		var ui: Dictionary = boxes.get(p.player_index, {})
		if ui.is_empty():
			continue
		var ring: Control = ui["ammo_ring"]
		if ring.visible != p.is_reloading or p.is_reloading:
			_update_ammo_row(ui, p)

# Gleiche Optik wie der Nachlade-Kreis über dem Charakter
# (player_status_indicators.gd), nur in HUD-Größe.
func _draw_hud_reload_ring(ring: Control, p: Player) -> void:
	if not is_instance_valid(p):
		return
	var center: Vector2 = ring.size * 0.5
	var radius: float = HUD_RELOAD_RING_SIZE * 0.5 - 2.5
	ring.draw_circle(center, radius + 2.0, Color(0.015, 0.02, 0.035, 0.66))
	ring.draw_arc(center, radius, 0.0, TAU, 32, Color(0.92, 0.96, 1.0, 0.16), 2.0, true)
	var duration: float = maxf(0.001, p.reload_time)
	var remaining: float = clampf(p.reload_timer / duration, 0.0, 1.0)
	if remaining > 0.0:
		ring.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * remaining, 32, HUD_RELOAD_COLOR, 2.6, true)
	ring.draw_circle(center, 2.0, HUD_RELOAD_COLOR)

func _block_text(active: bool, cooldown: float) -> String:
	if active:
		return "Block [Q]: AKTIV"
	if cooldown <= 0.0:
		return "Block [Q]: BEREIT"
	return "Block [Q]: %.1fs" % cooldown

func _melee_text(p: Player) -> String:
	var label := Global.get_melee_weapon_label(Global.get_melee_weapon(p.player_index))
	if p.powerup_auto_attack_timer > 0.0:
		label += " (AUTO %ds)" % ceili(p.powerup_auto_attack_timer)
	if p.melee_cooldown_timer <= 0.0:
		return "%s [E]: BEREIT" % label
	return "%s [E]: %.1fs" % [label, p.melee_cooldown_timer]

func _update_score() -> void:
	# Die aktuellen Punkte stehen direkt neben jedem Fortschrittsbalken.
	# Darüber bleibt nur das Match-Ziel als kleine Orientierung.
	var target_prefix := "Team-Ziel" if Global.is_team_mode() else "Ziel"
	score_label.text = "%s: %d Punkte" % [target_prefix, Global.points_to_win]
	_update_score_bars()

# Baut die Fortschrittsbalken einmalig auf. Die Zeilen werden anschließend nur
# noch aktualisiert, weil update_all() während des Matches jeden Frame läuft.
func _build_score_bars() -> void:
	if _score_bars != null:
		return
	_score_bars = GridContainer.new()
	_score_bars.name = "ScoreBars"
	_score_bars.columns = 2
	_score_bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_bars.add_theme_constant_override("h_separation", 8)
	_score_bars.add_theme_constant_override("v_separation", 2)
	_score_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center_box := score_label.get_parent()
	center_box.add_child(_score_bars)
	center_box.move_child(_score_bars, score_label.get_index() + 1)

	for i in range(Global.MAX_PLAYERS):
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(34, 0)
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_label)

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(72, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.05, 0.06, 0.09, 0.9)
		background.set_corner_radius_all(3)
		background.set_border_width_all(1)
		background.border_color = Color(1.0, 1.0, 1.0, 0.14)
		bar.add_theme_stylebox_override("background", background)

		var fill := StyleBoxFlat.new()
		fill.bg_color = Color.WHITE
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)

		row.add_child(bar)

		# Der aktuelle Punktestand steht direkt rechts neben dem Balken.
		var points_label := Label.new()
		points_label.name = "Points"
		points_label.custom_minimum_size = Vector2(30, 0)
		points_label.add_theme_font_size_override("font_size", 10)
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		points_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		points_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(points_label)

		_score_bars.add_child(row)
		_score_bar_rows.append({
			"row": row,
			"label": name_label,
			"bar": bar,
			"fill": fill,
			"points": points_label,
		})

func _update_score_bars() -> void:
	if _score_bars == null:
		return
	var target := maxi(1, Global.points_to_win)
	if Global.is_team_mode():
		var team_count := Global.get_team_count()
		for i in range(_score_bar_rows.size()):
			var data: Dictionary = _score_bar_rows[i]
			var row: HBoxContainer = data["row"]
			if i >= team_count:
				row.visible = false
				continue
			var team := i + 1
			row.visible = true
			_update_score_bar_row(
				data,
				Global.get_team_name(team),
				Global.get_team_color(team),
				Global.get_team_score(team),
				target
			)
		_score_bars.visible = team_count > 0
		return

	for i in range(_score_bar_rows.size()):
		var data: Dictionary = _score_bar_rows[i]
		var row: HBoxContainer = data["row"]
		if i >= Global.player_count:
			row.visible = false
			continue
		var slot := i + 1
		var label := "P%d" % slot
		if Global.is_bot_slot(slot):
			label = "BOT%d" % slot
		var hero := Global.get_hero(Global.get_player_hero_id(slot))
		row.visible = true
		_update_score_bar_row(data, label, hero.color_tint, Global.player_scores[i], target)
	_score_bars.visible = Global.player_count > 0

func _update_score_bar_row(data: Dictionary, label_text: String, color: Color, score: int, target: int) -> void:
	var label: Label = data["label"]
	label.text = label_text
	label.add_theme_color_override("font_color", color)

	var bar: ProgressBar = data["bar"]
	bar.max_value = float(target)
	bar.value = float(clampi(score, 0, target))
	bar.tooltip_text = "%s: %d / %d Punkte" % [label_text, score, target]

	var fill: StyleBoxFlat = data["fill"]
	fill.bg_color = color

	var points: Label = data["points"]
	points.text = str(score)
	points.tooltip_text = bar.tooltip_text
	points.add_theme_color_override("font_color", color)

func _update_ping() -> void:
	if ping_label == null:
		return
	if not NetworkManager.is_network_active():
		ping_label.visible = false
		return
	ping_label.visible = true
	var prefix := "ZUSCHAUER · " if Global.is_spectator else ""
	ping_label.text = prefix + NetworkManager.get_ping_summary()
	ping_label.add_theme_color_override("font_color", NetworkManager.get_ping_color())

func _update_cards_count() -> void:
	for p in tracked_players:
		if not is_instance_valid(p):
			continue
		var ui: Dictionary = boxes.get(p.player_index, {})
		if not ui.is_empty():
			ui["cards"].text = "Upgrades: %d" % Global.get_player_cards(p.player_index).size()

func _on_scores_changed(_scores: Array) -> void:
	_update_score()
	_update_cards_count()
	_refresh_upgrade_bar()
	if _tab_overlay != null and _tab_overlay.visible:
		_refresh_tab_overlay()

func _on_scoring_config_changed() -> void:
	_update_score()

func _on_match_target_changed(_points: int) -> void:
	_update_score()

# --- Eigene Upgrade-Karten -------------------------------------------------

func _on_card_selected(player_index: int, _card: CardData) -> void:
	if player_index == Global.local_player_index:
		_refresh_upgrade_bar()
		if _tab_overlay != null and _tab_overlay.visible:
			_refresh_tab_overlay()

func _local_player() -> Player:
	for p in tracked_players:
		if is_instance_valid(p) and p.player_index == Global.local_player_index:
			return p
	return null

func _clear_ui_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_upgrade_bar() -> void:
	_upgrade_bar = PanelContainer.new()
	_upgrade_bar.name = "UpgradeBar"
	_upgrade_bar.anchor_left = 0.0
	_upgrade_bar.anchor_top = 1.0
	_upgrade_bar.anchor_right = 0.0
	_upgrade_bar.anchor_bottom = 1.0
	_upgrade_bar.offset_left = 18.0
	_upgrade_bar.offset_top = -108.0
	_upgrade_bar.offset_right = 640.0
	_upgrade_bar.offset_bottom = -14.0
	_upgrade_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_upgrade_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_bar.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.55, 0.70, 0.65)
	_upgrade_bar.add_theme_stylebox_override("panel", style)
	add_child(_upgrade_bar)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_bar.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	_upgrade_title = Label.new()
	_upgrade_title.add_theme_font_size_override("font_size", 11)
	_upgrade_title.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 1.0))
	_upgrade_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_upgrade_title)

	_upgrade_flow = HFlowContainer.new()
	_upgrade_flow.add_theme_constant_override("h_separation", 4)
	_upgrade_flow.add_theme_constant_override("v_separation", 4)
	_upgrade_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_upgrade_flow)

func _refresh_upgrade_bar() -> void:
	if _upgrade_bar == null or _upgrade_flow == null:
		return
	var p := _local_player()
	if p == null or Global.is_spectator:
		_upgrade_bar.visible = false
		return
	_upgrade_bar.visible = true
	_clear_ui_children(_upgrade_flow)

	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(p.player_index))
	var hero_name := hero.name if hero != null else "Spieler %d" % p.player_index
	var cards := Global.get_player_cards(p.player_index)
	_upgrade_title.text = "UPGRADES · %s (%d) · TAB HALTEN FÜR DETAILS" % [hero_name.to_upper(), cards.size()]
	_upgrade_title.add_theme_color_override("font_color", hero.color_tint if hero != null else Color(0.72, 0.82, 0.92, 1.0))

	var shown := mini(cards.size(), MAX_UPGRADE_ICONS)
	for i in range(shown):
		var card: CardData = cards[i]
		var holder := PanelContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.10, 0.14, 0.92)
		style.set_corner_radius_all(5)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = CardDatabase.get_rarity_color(card.rarity)
		holder.add_theme_stylebox_override("panel", style)
		var icon := CardIcon.new()
		icon.setup(card, 26.0, false)
		holder.add_child(icon)
		CardMechanics.apply_tooltip(holder, card, true)
		_upgrade_flow.add_child(holder)

	if cards.size() > shown:
		var more := Label.new()
		more.text = "+%d" % (cards.size() - shown)
		more.add_theme_font_size_override("font_size", 12)
		more.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 1.0))
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_upgrade_flow.add_child(more)

func _build_tab_overlay() -> void:
	_tab_overlay = Control.new()
	_tab_overlay.name = "CharacterOverlay"
	_tab_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tab_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_overlay.visible = false
	_tab_layer = CanvasLayer.new()
	_tab_layer.name = "CharacterOverlayLayer"
	_tab_layer.layer = 20
	add_child(_tab_layer)
	_tab_layer.add_child(_tab_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.78)
	# Fängt die Maus ab, damit darunterliegende Draft-Karten keine Tooltips zeigen.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 760)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.35, 0.70, 0.90, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(outer)

	_tab_player_tabs = HBoxContainer.new()
	_tab_player_tabs.add_theme_constant_override("separation", 6)
	_tab_player_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_player_tabs.visible = false
	outer.add_child(_tab_player_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(scroll)
	_tab_scroll = scroll

	_tab_content = VBoxContainer.new()
	_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_content.add_theme_constant_override("separation", 10)
	_tab_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_tab_content)

# Ein schon offener Tooltip einer Draft-Karte verschwindet erst, wenn die GUI
# den Hover neu auswertet; eine Maus-Bewegung ohne Versatz löst das sofort aus.
func _refresh_hover_under_overlay() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = get_viewport().get_mouse_position()
	motion.global_position = motion.position
	Input.parse_input_event(motion)

func _can_show_tab_overlay() -> bool:
	if Global.is_spectator or Global.local_player_index < 1:
		return false
	if game_over_panel.visible or GameSettings.gameplay_input_blocked:
		return false
	return Global.current_state == Global.GameState.PLAYING or _is_draft_active()

# Hebt die Punkteübersicht über die Kartenwahl (Layer 10), solange der Draft
# offen ist. Position und Größe entsprechen der Top-Leiste.
func _sync_score_box_layer() -> void:
	var center_box := score_label.get_parent() as Control
	if center_box == null:
		return
	var draft := _draft_ui()
	var wants_layer := draft != null and draft.visible
	if wants_layer:
		if _score_holder != null and center_box.get_parent() == _score_holder:
			return
		if _score_layer == null:
			_score_layer = CanvasLayer.new()
			_score_layer.name = "DraftScoreLayer"
			_score_layer.layer = 11
			add_child(_score_layer)
			_score_holder = HBoxContainer.new()
			_score_holder.name = "DraftScoreHolder"
			_score_holder.anchor_left = 1.0
			_score_holder.anchor_right = 1.0
			_score_holder.offset_left = -20.0 - center_box.custom_minimum_size.x
			_score_holder.offset_right = -20.0
			_score_holder.offset_top = 12.0
			_score_holder.offset_bottom = 118.0
			_score_holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_score_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_score_layer.add_child(_score_holder)
		_score_box_index = center_box.get_index()
		center_box.reparent(_score_holder, false)
	elif _score_holder != null and center_box.get_parent() == _score_holder:
		var top: Control = $Top
		center_box.reparent(top, false)
		if _score_box_index >= 0:
			top.move_child(center_box, mini(_score_box_index, top.get_child_count() - 1))

func _draft_ui() -> CardDraftUI:
	return get_parent().get_node_or_null("CardDraftUI") as CardDraftUI

func _is_draft_active() -> bool:
	if Global.current_state == Global.GameState.CARD_DRAFT:
		return true
	var draft := _draft_ui()
	return draft != null and draft.visible

# Online zeigt Tab immer die eigenen Werte, lokal die des gerade wählenden
# Spielers, weil sich dort alle einen Bildschirm teilen.
func _tab_target_slot() -> int:
	if Global.network_mode:
		return Global.local_player_index
	var draft := _draft_ui()
	if draft != null and draft.visible:
		return draft.current_drafter
	return Global.local_player_index

# Während der Kartenwahl ist die Spielfigur meist schon entfernt (Tod). Ein
# nicht eingehängter Player rechnet über apply_stats() dieselben Werte aus
# Held + Karten aus, die er nächste Runde haben wird. Drohnen bekommen dabei
# Netzwerk-IDs, deshalb wird der Zähler danach zurückgesetzt.
func _create_stat_preview(slot: int) -> Player:
	if slot < 1 or Global.get_hero(Global.get_player_hero_id(slot)) == null:
		return null
	var saved_companion_id := Companion._next_net_id
	var preview := Player.new()
	preview.player_index = slot
	preview.apply_stats()
	Companion._next_net_id = saved_companion_id
	return preview

func _add_tab_heading(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(label)
	return label

func _add_stat_cell(grid: GridContainer, caption: String, value: String, value_color: Color = Color.WHITE) -> void:
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.add_theme_font_size_override("font_size", 11)
	caption_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(caption_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", value_color)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(value_label)

func _create_tab_card(card: CardData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.17, 0.96)
	style.set_corner_radius_all(8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CardDatabase.get_rarity_color(card.rarity)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var icon := CardIcon.new()
	icon.setup(card, 40.0, false)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_box)

	var title := Label.new()
	title.text = card.title
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", card.color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title)

	var meta := Label.new()
	meta.text = "%s · %s" % [card.rarity, card.pool]
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", CardDatabase.get_rarity_color(card.rarity))
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(meta)

	var evolution_banner := CardMechanics.make_evolution_banner(card, 9)
	if evolution_banner != null:
		text_box.add_child(evolution_banner)

	var unlock_label := CardMechanics.make_unlock_label(card, 9, false)
	if unlock_label != null:
		text_box.add_child(unlock_label)

	var description := Label.new()
	description.text = CardMechanics.format_description(card.description)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color(0.70, 0.74, 0.82, 1.0))
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(description)
	CardMechanics.apply_tooltip(panel, card, true)
	return panel

func _refresh_tab_overlay() -> void:
	if _tab_content == null:
		return
	var keep_scroll := _tab_scroll.scroll_vertical if _tab_scroll != null else 0
	_clear_ui_children(_tab_content)
	var slot := _tab_target_slot()
	if _can_browse_tab_players() and Global.get_active_player_indices().has(_tab_view_slot):
		slot = _tab_view_slot
	_tab_view_slot = slot
	_rebuild_tab_player_tabs(slot)
	var preview: Player = null
	var p: Player = _tracked_player(slot)
	# Kartenwahl oder tot (Figur entfernt): Werte aus Held + Karten berechnen.
	if _is_draft_active() or p == null:
		preview = _create_stat_preview(slot)
		p = preview
	if p == null:
		return
	_fill_tab_overlay(p, preview != null)
	if preview != null:
		preview.free()
	# Der Inhalt wird alle 0,35 s neu gebaut; Scrollposition beibehalten.
	if _tab_scroll != null:
		_tab_scroll.set_deferred("scroll_vertical", keep_scroll)

# Blind Pick hält die Karten der anderen online geheim; dann bleibt Tab beim
# eigenen Bogen. Sonst zeigt eine Leiste alle Spieler zum Umschalten.
func _can_browse_tab_players() -> bool:
	return not (Global.blind_pick_enabled and Global.network_mode)

func _tracked_player(slot: int) -> Player:
	for p in tracked_players:
		if is_instance_valid(p) and p.player_index == slot:
			return p
	return null

func _select_tab_player(slot: int) -> void:
	if slot == _tab_view_slot:
		return
	SoundManager.play_sound("click")
	_tab_view_slot = slot
	if _tab_scroll != null:
		_tab_scroll.scroll_vertical = 0
	_refresh_tab_overlay()
	_tab_refresh_timer = TAB_REFRESH_INTERVAL

# Die Knöpfe werden nur bei geänderter Auswahl neu gebaut, sonst ginge ein
# Klick zwischen zwei Aktualisierungen (alle 0,35 s) verloren.
func _rebuild_tab_player_tabs(selected: int) -> void:
	if _tab_player_tabs == null:
		return
	var slots: Array[int] = Global.get_active_player_indices()
	if not _can_browse_tab_players() or slots.size() < 2:
		_tab_player_tabs.visible = false
		_tab_player_tabs_key = ""
		return
	var key := "%d|%s" % [selected, str(slots)]
	_tab_player_tabs.visible = true
	if key == _tab_player_tabs_key:
		return
	_tab_player_tabs_key = key
	_clear_ui_children(_tab_player_tabs)
	for i in slots.size():
		var s_idx: int = slots[i]
		var hero: HeroData = Global.get_hero(Global.get_player_hero_id(s_idx))
		var btn := Button.new()
		btn.text = "%d  %s" % [i + 1, _player_display_name(s_idx)]
		btn.toggle_mode = true
		btn.button_pressed = (s_idx == selected)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		if hero != null:
			btn.add_theme_color_override("font_color", hero.color_tint)
		btn.pressed.connect(_select_tab_player.bind(s_idx), CONNECT_DEFERRED)
		_tab_player_tabs.add_child(btn)
	var hint := Label.new()
	hint.text = "Taste 1-%d oder Klick: Spieler wechseln" % slots.size()
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_player_tabs.add_child(hint)

func _fill_tab_overlay(p: Player, is_preview: bool, for_overview: bool = false) -> void:
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(p.player_index))
	var hero_name := hero.name if hero != null else "Spieler %d" % p.player_index
	var hero_color := hero.color_tint if hero != null else Color(0.55, 0.85, 1.0)

	var title := Label.new()
	title.text = "CHARAKTERBOGEN · %s" % hero_name.to_upper()
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", hero_color)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(title)

	var subtitle := Label.new()
	var role_text := hero.role if hero != null else ""
	subtitle.text = "%s  ·  TAB loslassen zum Schließen" % role_text
	if not for_overview and p.player_index != Global.local_player_index and _can_browse_tab_players():
		title.text = "CHARAKTERBOGEN · %s" % _player_display_name(p.player_index).to_upper()
	if for_overview:
		title.text = "%s · %s" % [_player_display_name(p.player_index).to_upper(), "%d Punkte" % Global.player_scores[p.player_index - 1]]
		subtitle.text = "%s  ·  Endstand mit allen Karten" % role_text
	elif is_preview:
		subtitle.text = "%s  ·  Werte für die nächste Runde  ·  TAB loslassen zum Schließen" % role_text
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(subtitle)

	_add_tab_heading("ATTRIBUTE", Color(0.45, 0.90, 1.0))
	var stats_grid := GridContainer.new()
	stats_grid.columns = 4
	stats_grid.add_theme_constant_override("h_separation", 14)
	stats_grid.add_theme_constant_override("v_separation", 4)
	stats_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(stats_grid)

	_add_stat_cell(stats_grid, "LEBEN", "%d / %d" % [int(round(p.current_health)), int(round(p.max_health))], Color(0.45, 0.95, 0.50))
	_add_stat_cell(stats_grid, "SCHILD", "%d / %d" % [int(round(p.current_shield)), int(round(p.max_shield))], Color(0.35, 0.70, 1.0))
	_add_stat_cell(stats_grid, "RÜSTUNG", "%.0f %%" % (p.armor_percent * 100.0), Color(0.62, 0.86, 0.62))
	_add_stat_cell(stats_grid, "REFLEXION", "%.0f %%" % (p.damage_reflect_percent * 100.0), Color(0.82, 0.68, 1.0))
	_add_stat_cell(stats_grid, "SCHADEN", "%.1f" % p.bullet_damage, Color(1.0, 0.65, 0.35))
	_add_stat_cell(stats_grid, "FEUERRATE", "%.2f / s" % (1.0 / maxf(0.01, p.fire_rate_cooldown)), Color(1.0, 0.82, 0.35))
	_add_stat_cell(stats_grid, "TEMPO", "%d" % int(round(p.move_speed)), Color(0.55, 0.90, 1.0))
	_add_stat_cell(stats_grid, "MUNITION", "%d / %d" % [p.current_ammo, p.max_ammo], Color(0.85, 0.85, 0.90))
	_add_stat_cell(stats_grid, "NACHLADEN", "%.2f s" % p.reload_time, Color(0.85, 0.85, 0.90))
	_add_stat_cell(stats_grid, "SPRÜNGE", "%d" % p.max_jumps, Color(0.70, 0.85, 1.0))
	_add_stat_cell(stats_grid, "BLOCK", "%s · %.1f s / %.1f s" % ["AKTIV" if p.is_blocking else "BEREIT", p.block_cooldown, p.block_duration], Color(0.55, 0.85, 1.0))
	var melee_id := Global.get_melee_weapon(p.player_index)
	var melee_data := Global.get_melee_weapon_data(melee_id)
	if Global.melee_enabled:
		_add_stat_cell(stats_grid, "NAHKAMPF", "%s · %d · %.1f s" % [Global.get_melee_weapon_label(melee_id), int(round(float(melee_data["damage"]) * p.melee_damage_mult)), p.melee_cooldown], Color(1.0, 0.72, 0.42))
	_add_stat_cell(stats_grid, "FÄHIGKEIT", "%s (%.1f s)" % [p.ability_name, p.ability_max_cooldown], hero_color)
	_add_stat_cell(stats_grid, "KILLS", "%d" % int(Global.get_match_stat(p.player_index, "kills")), Color(0.85, 0.90, 1.0))
	_add_stat_cell(stats_grid, "TODE", "%d" % int(Global.get_match_stat(p.player_index, "deaths")), Color(0.95, 0.55, 0.55))
	_add_stat_cell(stats_grid, "SCHADEN GESAMT", "%d" % int(Global.get_match_stat(p.player_index, "damage_dealt")), Color(1.0, 0.65, 0.35))
	_add_stat_cell(stats_grid, "HEILUNG", "%d" % int(Global.get_match_stat(p.player_index, "healing_done")), Color(0.45, 0.95, 0.50))

	_add_modifier_totals(p)

	var cards := Global.get_player_cards(p.player_index)
	_add_tab_heading("KARTENVERTEILUNG", Color(0.55, 0.85, 1.0))
	_tab_content.add_child(RadarChartScript.build_card_charts(cards, 4, Vector2(225, 190)))

	_add_tab_heading("UPGRADE-KARTEN (%d)" % cards.size(), Color(1.0, 0.72, 0.30))
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "Noch keine Upgrade-Karten gesammelt."
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tab_content.add_child(empty)
		return

	var card_grid := GridContainer.new()
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 10)
	card_grid.add_theme_constant_override("v_separation", 8)
	card_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(card_grid)
	for card in cards:
		card_grid.add_child(_create_tab_card(card))

# Summen aller Karten-Modifier, die nicht schon oben unter ATTRIBUTE stehen.
# Gezeigt wird nur, was vom Grundwert abweicht, damit die Liste kurz bleibt.
func _add_modifier_totals(p: Player) -> void:
	var rows: Array = []
	var shot := Color(1.0, 0.65, 0.35)
	var effect := Color(0.75, 0.95, 0.55)
	var ability := Color(0.82, 0.68, 1.0)
	var defense := Color(0.55, 0.85, 1.0)
	if p.explosion_radius > 0.0:
		rows.append(["EXPLOSIONSRADIUS", "%d px" % int(round(p.explosion_radius)), shot])
	if p.multishot > 0:
		rows.append(["MEHRFACHSCHUSS", "+%d Projektile" % p.multishot, shot])
	if p.spread_angle > 0.0:
		rows.append(["STREUUNG", "%.0f°" % p.spread_angle, shot])
	if p.bounces > 0:
		rows.append(["ABPRALLER", "%d" % p.bounces, shot])
	if p.border_bounce:
		rows.append(["GUMMIWAND", "AN", shot])
	if p.bounce_split:
		rows.append(["ZELLTEILUNG", "2 x 60 %", shot])
	if p.self_damage_reduction > 0.0:
		rows.append(["SELBSTSCHADEN", "-%.0f %%" % (minf(p.self_damage_reduction, Player.MAX_SELF_DAMAGE_REDUCTION) * 100.0), defense])
	if p.piercing > 0:
		rows.append(["DURCHSCHLAG", "%d" % p.piercing, shot])
	if p.homing > 0.0:
		rows.append(["ZIELSUCHE", "%.2f" % p.homing, shot])
	if not is_equal_approx(p.bullet_speed, 650.0):
		rows.append(["GESCHOSSTEMPO", "%d" % int(round(p.bullet_speed)), shot])
	if not is_equal_approx(p.bullet_size, 1.0):
		rows.append(["GESCHOSSGRÖSSE", "x%.2f" % p.bullet_size, shot])
	if not is_equal_approx(p.projectile_gravity_mult, 1.0):
		rows.append(["GESCHOSS-FALL", "x%.2f" % p.projectile_gravity_mult, shot])
	if not is_equal_approx(p.knockback_mult, 1.0):
		rows.append(["RÜCKSTOSS", "x%.2f" % p.knockback_mult, shot])
	var melee := Color(1.0, 0.72, 0.42)
	if not is_equal_approx(p.melee_damage_mult, 1.0):
		rows.append(["NAHKAMPF-SCHADEN", "x%.2f" % p.melee_damage_mult, melee])
	if p.melee_range_bonus > 0.0:
		rows.append(["NAHKAMPF-REICHWEITE", "+%.2f Felder" % p.melee_range_bonus, melee])
	if p.melee_arc_bonus > 0.0:
		rows.append(["NAHKAMPF-BOGEN", "+%.0f°" % p.melee_arc_bonus, melee])
	if not is_equal_approx(p.melee_knockback_mult, 1.0):
		rows.append(["NAHKAMPF-RÜCKSTOSS", "x%.2f" % p.melee_knockback_mult, melee])
	if p.melee_freeze > 0.0:
		rows.append(["NAHKAMPF-FROST", "%.1f s" % p.melee_freeze, melee])
	if p.melee_poison_stacks > 0:
		rows.append(["NAHKAMPF-GIFT", "%d Stapel" % p.melee_poison_stacks, melee])
	if p.melee_burn_stacks > 0:
		rows.append(["NAHKAMPF-BRAND", "%d Stapel" % p.melee_burn_stacks, melee])
	if p.melee_stun > 0.0:
		rows.append(["NAHKAMPF-BETÄUBUNG", "%.2f s" % p.melee_stun, melee])
	if p.melee_wall_stun_bonus > 0.0:
		rows.append(["WANDKLATSCHER", "+%.1f s" % p.melee_wall_stun_bonus, melee])
	if p.melee_lifesteal > 0.0:
		rows.append(["NAHKAMPF-LEBENSRAUB", "%.0f %%" % (p.melee_lifesteal * 100.0), melee])
	if p.melee_execute_bonus > 0.0:
		rows.append(["GNADENSTOSS", "+%.0f %%" % (p.melee_execute_bonus * 100.0), melee])
	if p.melee_chain_lightning:
		rows.append(["NAHKAMPF-KETTENBLITZ", "AN", melee])
	if p.melee_echo:
		rows.append(["NACHSCHLAG", "AN", melee])
	if p.melee_parry:
		rows.append(["PARADE", "AN", melee])
	if p.lifesteal_percent > 0.0:
		rows.append(["LEBENSRAUB", "%.0f %%" % (p.lifesteal_percent * 100.0), effect])
	if p.poison_stacks > 0:
		rows.append(["GIFT", "%d Stapel · %.1f / Tick" % [p.poison_stacks, p.poison_damage_per_tick], effect])
	if p.freeze_duration > 0.0:
		rows.append(["EINFRIEREN", "%.1f s" % p.freeze_duration, effect])
	if p.max_shield > 0.0 and not is_equal_approx(p.shield_regen_delay, Player.SHIELD_REGEN_DELAY):
		rows.append(["SCHILD-PAUSE", "%.1f s" % p.shield_regen_delay, defense])
	if p.max_shield > 0.0 and not is_equal_approx(p.shield_regen_mult, 1.0):
		rows.append(["SCHILD-AUFLADUNG", "%.0f / s" % (Player.SHIELD_REGEN_PER_SEC * p.shield_regen_mult), defense])
	if p.hp_regen > 0.0:
		rows.append(["LEBENSREGENERATION", "%.1f / s" % p.hp_regen, effect])
	if p.hp_regen_always > 0.0:
		rows.append(["DAUERHEILUNG", "%.1f / s" % p.hp_regen_always, effect])
	if p.reflect_low_hp_bonus > 0.0:
		rows.append(["REFLEXION BEI WENIG HP", "+%.0f %%" % (p.reflect_low_hp_bonus * 100.0), defense])
	if p.reflect_heal_percent > 0.0:
		rows.append(["HEILUNG DURCH REFLEXION", "%.0f %%" % (p.reflect_heal_percent * 100.0), defense])
	if p.block_reflect_damage_add > 0.0:
		rows.append(["BLOCK-REFLEXSCHADEN", "+%.0f" % p.block_reflect_damage_add, defense])
	if p.block_knockback_radius > 0.0:
		rows.append(["BLOCK-STOSSRADIUS", "%d px" % int(round(p.block_knockback_radius)), defense])
	if p.block_mine:
		rows.append(["MINEN", "%.0f Schaden · %.0f Felder%s" % [p.block_mine_damage,
			p.block_mine_radius / Player.BLOCK_MINE_TILE, " · sofort" if p.block_mine_instant else ""], defense])
	if not is_equal_approx(p.dash_cooldown, 1.8):
		rows.append(["DASH-ABKLINGZEIT", "%.2f s" % p.dash_cooldown, defense])
	if not is_equal_approx(p.ability_damage_mult, 1.0):
		rows.append(["FÄHIGKEIT SCHADEN", "x%.2f" % p.ability_damage_mult, ability])
	if not is_equal_approx(p.ability_radius_mult, 1.0):
		rows.append(["FÄHIGKEIT RADIUS", "x%.2f" % p.ability_radius_mult, ability])
	if not is_equal_approx(p.ability_duration_mult, 1.0):
		rows.append(["FÄHIGKEIT DAUER", "x%.2f" % p.ability_duration_mult, ability])
	if not is_equal_approx(p.ability_range_mult, 1.0):
		rows.append(["FÄHIGKEIT REICHWEITE", "x%.2f" % p.ability_range_mult, ability])
	if not is_equal_approx(p.powerup_strength_mult, 1.0):
		rows.append(["POWERUP-WIRKUNG", "x%.2f" % p.powerup_strength_mult, effect])
	if p.powerup_pickup_range > 0.0:
		rows.append(["POWERUP-SAMMELREICHWEITE", "+%.0f Felder" % (p.powerup_pickup_range / Player.POWERUP_PICKUP_TILE), effect])
	if p.drone_count > 0:
		rows.append(["DROHNEN", "%d" % p.drone_count, ability])
	if p.blocker_drone_count > 0:
		rows.append(["SCHUTZDROHNEN", "%d" % p.blocker_drone_count, ability])
	if p.tower_enabled:
		rows.append(["TURM", "%d HP · Feuerrate x%.2f" % [int(round(p.tower_max_health)), p.tower_fire_rate_mult], ability])

	_add_tab_heading("KARTEN-BONI (SUMMEN)", Color(0.75, 0.95, 0.55))
	if rows.is_empty():
		var none := Label.new()
		none.text = "Noch keine Boni über die Grundwerte hinaus."
		none.add_theme_font_size_override("font_size", 12)
		none.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tab_content.add_child(none)
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_content.add_child(grid)
	for row in rows:
		_add_stat_cell(grid, row[0], row[1], row[2])

func set_sudden_death(active: bool) -> void:
	sudden_death_label.visible = active

func reset_for_round() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false
	if _tab_overlay != null:
		_tab_overlay.visible = false
	if _overview != null:
		_overview.visible = false
	if _modifier_container != null:
		for c in _modifier_container.get_children():
			_modifier_container.remove_child(c)
			c.queue_free()
		_modifier_container.visible = false
	if _event_label != null:
		_event_label.text = ""
		_event_label.visible = false
	_event_timer = 0.0
	restart_btn.text = "HAUPTMENÜ" if Global.network_mode else "NOCHMAL"
	_refresh_upgrade_bar()

func _build_modifier_ui() -> void:
	if _modifier_container != null:
		return

	_modifier_container = VBoxContainer.new()
	_modifier_container.name = "ModifierBadges"
	_modifier_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_modifier_container.anchor_left = 1.0
	_modifier_container.anchor_right = 1.0
	_modifier_container.offset_left = -42.0
	_modifier_container.offset_right = -18.0
	_modifier_container.offset_top = 132.0
	_modifier_container.offset_bottom = 420.0
	_modifier_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_modifier_container.grow_vertical = Control.GROW_DIRECTION_END
	_modifier_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	_modifier_container.add_theme_constant_override("separation", 2)
	_modifier_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modifier_container.visible = false
	add_child(_modifier_container)

	var center_box := score_label.get_parent()
	if center_box != null:
		_event_label = Label.new()
		_event_label.name = "ModifierEventLabel"
		_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_event_label.add_theme_font_size_override("font_size", 20)
		_event_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_event_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		_event_label.add_theme_constant_override("outline_size", 4)
		_event_label.visible = false
		_event_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center_box.add_child(_event_label)

func show_level_modifiers(mod_details: Array[Dictionary]) -> void:
	if _modifier_container == null:
		return
	for c in _modifier_container.get_children():
		_modifier_container.remove_child(c)
		c.queue_free()

	if mod_details.is_empty():
		_modifier_container.visible = false
		return

	_modifier_container.visible = true
	# Nur das Icon, ohne Rahmen und Titel, halb so groß wie zuvor.
	for mod in mod_details:
		var icon_label := Label.new()
		icon_label.text = str(mod.get("icon", "?"))
		icon_label.custom_minimum_size = Vector2(24.0, 24.0)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 20)
		icon_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		icon_label.add_theme_constant_override("outline_size", 3)
		icon_label.tooltip_text = str(mod.get("description", ""))
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_modifier_container.add_child(icon_label)

# Einstiegspunkt: Wird von modifier_manager.modifiers_rolled verbunden.
# Aktualisiert die Dauerleiste oben UND spielt die Stempel-Animation.
func on_modifiers_revealed(mod_details: Array[Dictionary]) -> void:
	show_level_modifiers(mod_details)
	show_modifier_stamp_reveal(mod_details)

# Zeigt jeden aktiven Modifier als animierten Stempel auf dem Bildschirm.
# Badges fliegen von der Mitte raus, "stempeln" mit einem Bounce-Effekt und
# verschwinden nach ~2 Sekunden automatisch wieder.
func show_modifier_stamp_reveal(mod_details: Array[Dictionary]) -> void:
	if mod_details.is_empty():
		return

	# Altes Overlay entfernen (z.B. bei schnell aufeinanderfolgenden Runden)
	if is_instance_valid(_stamp_overlay):
		_stamp_overlay.queue_free()

	_stamp_overlay = Control.new()
	_stamp_overlay.name = "StampOverlay"
	_stamp_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stamp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp_overlay)
	_stamp_overlay.move_to_front()

	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size if vp != null else Vector2(1280.0, 720.0)
	var cx := vp_size.x * 0.5
	var cy := vp_size.y * 0.5

	# ── Dunkler Hintergrund ───────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamp_overlay.add_child(bg)
	bg.create_tween().tween_property(bg, "color", Color(0.04, 0.04, 0.09, 0.78), 0.22)

	# ── Titel ─────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "── RUNDEN-MODIFIER ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 0.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 5)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = cy - 190.0
	title.offset_bottom = cy - 135.0
	_stamp_overlay.add_child(title)
	title.create_tween().tween_property(title, "theme_override_colors/font_color", Color(1.0, 0.85, 0.25, 1.0), 0.28)

	# ── Badge-Layout ──────────────────────────────────────────────────────
	const BADGE_W: float = 280.0
	const BADGE_H: float = 250.0
	const GAP: float    = 24.0
	var count   := mod_details.size()
	var total_w := float(count) * BADGE_W + float(count - 1) * GAP
	var start_x := cx - total_w * 0.5

	for i in range(count):
		var mod: Dictionary = mod_details[i]
		var col: Color = mod.get("color", Color.WHITE)
		var bx := start_x + float(i) * (BADGE_W + GAP)
		var by := cy - BADGE_H * 0.5

		# ── Badge-Container ───────────────────────────────────────────
		var badge := Control.new()
		badge.position = Vector2(bx, by)
		badge.custom_minimum_size = Vector2(BADGE_W, BADGE_H)
		badge.size           = Vector2(BADGE_W, BADGE_H)
		badge.pivot_offset   = Vector2(BADGE_W * 0.5, BADGE_H * 0.5)
		badge.scale          = Vector2(2.2, 2.2)
		# Abwechselnd leicht nach links / rechts geneigt für mehr Leben
		badge.rotation       = deg_to_rad(-20.0 if i % 2 == 0 else 20.0)
		badge.modulate.a     = 0.0
		_stamp_overlay.add_child(badge)

		# Hintergrundpanel mit Farbe des Modifiers
		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r * 0.09 + 0.03, col.g * 0.09 + 0.03, col.b * 0.09 + 0.03, 0.97)
		sb.border_color = col
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(12)
		sb.content_margin_left   = 18
		sb.content_margin_right  = 18
		sb.content_margin_top    = 14
		sb.content_margin_bottom = 14
		panel.add_theme_stylebox_override("panel", sb)
		badge.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		panel.add_child(vbox)

		var icon_l := Label.new()
		icon_l.text = mod.get("icon", "⚡")
		icon_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_l.add_theme_font_size_override("font_size", 60)
		vbox.add_child(icon_l)

		var name_l := Label.new()
		name_l.text = mod.get("title", "?").to_upper()
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_font_size_override("font_size", 26)
		name_l.add_theme_color_override("font_color", col.lightened(0.15))
		vbox.add_child(name_l)

		var sep := HSeparator.new()
		sep.add_theme_color_override("color", col.darkened(0.3))
		sep.add_theme_constant_override("separation", 5)
		vbox.add_child(sep)

		var desc_l := Label.new()
		desc_l.text = mod.get("description", "")
		desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_l.add_theme_font_size_override("font_size", 16)
		desc_l.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82, 0.92))
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_l.custom_minimum_size = Vector2(BADGE_W - 40.0, 0.0)
		vbox.add_child(desc_l)

		# ── Stempel-Animation ─────────────────────────────────────────
		var delay := 0.20 + float(i) * 0.40
		var final_rot := deg_to_rad(randf_range(-4.0, 4.0))  # leicht zufällig verdreht

		var tw := badge.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func():
			SoundManager.play_sound("click", 0.55, randf_range(-1.5, 0.8))
			# Kurzer weißer Aufleuchter beim Aufprall
			var flash := ColorRect.new()
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.color = Color(1.0, 1.0, 1.0, 0.45)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_child(flash)
			var ftw := flash.create_tween()
			ftw.tween_property(flash, "color:a", 0.0, 0.22)
			ftw.tween_callback(flash.queue_free)
		)
		# Stamp-in: Scale von 2.8x auf 1.0x mit Bounce-Ease (Überschwinger)
		tw.parallel().tween_property(badge, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(badge, "modulate:a", 1.0, 0.14)
		tw.parallel().tween_property(badge, "rotation", final_rot, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		# Kleines Nachwippen
		tw.tween_property(badge, "rotation", final_rot - deg_to_rad(3.0), 0.07)
		tw.tween_property(badge, "rotation", final_rot, 0.09)

	# ── Automatisch ausblenden ────────────────────────────────────────────
	var hold_time := 0.20 + float(count - 1) * 0.40 + 0.26 + 2.3
	var out_tw := _stamp_overlay.create_tween()
	out_tw.tween_interval(hold_time)
	out_tw.tween_property(_stamp_overlay, "modulate:a", 0.0, 0.45)
	out_tw.tween_callback(func():
		if is_instance_valid(_stamp_overlay):
			_stamp_overlay.queue_free()
		_stamp_overlay = null
	)

func show_modifier_event(text: String, color: Color = Color.WHITE, duration: float = 3.0) -> void:
	if _event_label == null:
		return
	_event_label.text = text
	_event_label.add_theme_color_override("font_color", color)
	_event_label.visible = true
	_event_timer = duration

func show_wind_notice(active: bool, dir: float) -> void:
	if not active:
		if _event_label != null and _event_label.text.begins_with("🌪️"):
			_event_label.visible = false
		return
	var arrow := ">>> (nach rechts)" if dir > 0 else "<<< (nach links)"
	show_modifier_event("🌪️ STURMWIND %s!" % arrow, Color(0.4, 0.85, 1.0), 3.6)

func update_bounty_notice(slot: int, count: int) -> void:
	var name_str := "P%d" % slot
	show_modifier_event("🪙 %s sammelt Beutemünze #%d!" % [name_str, count], Color(1.0, 0.85, 0.2), 2.5)

func update_pinata_notice(slot: int, total_dmg: float) -> void:
	var name_str := "P%d" % slot
	show_modifier_event("🦙 %s führt am Piñata-Lama (%d Schaden)!" % [name_str, int(total_dmg)], Color(1.0, 0.4, 0.8), 2.0)

func show_devil_notice(slot: int, angry: bool) -> void:
	var name_str := Global.get_player_name(slot)
	if angry:
		show_modifier_event("😡 Der Teufel ist wütend auf %s! (5 s)" % name_str, Color(1.0, 0.35, 0.1), 2.5)
	else:
		show_modifier_event("😈 Der Teufel jagt jetzt %s!" % name_str, Color(1.0, 0.45, 0.35), 2.0)

func show_countdown_number(value: int) -> void:
	SoundManager.play_sound("countdown", 0.0, 0.0)
	countdown_label.text = str(value)
	countdown_label.modulate = Color(1.0, 0.75, 0.2, 1.0)
	countdown_label.visible = true

func show_countdown_go() -> void:
	SoundManager.play_sound("countdown_go", 0.0, 0.0)
	countdown_label.text = "LOS!"
	countdown_label.modulate = Color(0.45, 1.0, 0.45, 1.0)
	countdown_label.visible = true

func hide_countdown() -> void:
	countdown_label.visible = false

func _on_match_over(winner_idx: int) -> void:
	game_over_panel.visible = true
	if _modifier_container != null:
		_modifier_container.visible = false
	if _tab_overlay != null:
		_tab_overlay.visible = false
	if _upgrade_bar != null:
		_upgrade_bar.visible = false
	game_over_panel.offset_left = -540.0
	game_over_panel.offset_top = -320.0
	game_over_panel.offset_right = 540.0
	game_over_panel.offset_bottom = 320.0
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(winner_idx)) if winner_idx > 0 else null
	var kind := ""
	if winner_idx <= 0 or hero == null:
		winner_label.text = "⚖ UNENTSCHIEDEN ⚖"
	elif Global.is_team_mode():
		var team := Global.get_team_for_slot(winner_idx)
		winner_label.text = "🏆 TEAM %s GEWINNT DAS MATCH! 🏆" % Global.get_team_name(team)
	elif Global.is_bot_slot(winner_idx):
		kind = "BOT"
	elif Global.network_mode and winner_idx == Global.local_player_index:
		kind = "DU"
	else:
		kind = "SPIELER %d" % winner_idx
	if winner_idx > 0 and hero != null and not Global.is_team_mode():
		winner_label.text = "🏆 %s (%s) GEWINNT DAS MATCH! 🏆" % [hero.name.to_upper(), kind]
	if Global.match_end_reason == "early":
		winner_label.text += "\nMatch vorzeitig beendet · Wertung nach Punkten"
	elif Global.match_end_reason == "tiebreak":
		winner_label.text += "\nIm Stechen entschieden"
	_build_match_stats()
	_ensure_overview_button()
	restart_btn.text = "HAUPTMENÜ" if Global.network_mode else "NOCHMAL"
	# Nur der Host darf das Match verlängern. Clients sehen den Button
	# deaktiviert und warten auf die nächste Runde des Hosts.
	var can_continue := not Global.network_mode or NetworkManager.is_host
	continue_btn.disabled = not can_continue
	continue_btn.text = "WEITERSPIELEN (+30 % ZIEL)" if can_continue else "WARTE AUF HOST ..."
	# Ein abgebrochenes Match wird nicht verlängert.
	continue_btn.visible = Global.match_end_reason != "early"
	SoundManager.play_sound("match_win", 0.0, 0.0)

func lock_continue(text: String) -> void:
	continue_btn.disabled = true
	continue_btn.text = text

# Ansage fürs Stechen: wer gegen wen um den Matchsieg kämpft.
func show_tiebreak_notice(slots: Array, duration: float = 3.0) -> void:
	var names: Array[String] = []
	if Global.is_team_mode():
		for slot in slots:
			var team_name := "TEAM %s" % Global.get_team_name(Global.get_team_for_slot(int(slot)))
			if not names.has(team_name):
				names.append(team_name)
	else:
		for slot in slots:
			names.append(_player_display_name(int(slot)))
	show_modifier_event("STECHEN! %s" % " vs ".join(names), Color(1.0, 0.82, 0.35, 1.0), duration)

func _build_match_stats() -> void:
	for child in game_over_vbox.get_children():
		if child.has_meta("match_stats_block"):
			game_over_vbox.remove_child(child)
			child.queue_free()

	var block := VBoxContainer.new()
	block.set_meta("match_stats_block", true)
	block.add_theme_constant_override("separation", 8)
	game_over_vbox.add_child(block)
	game_over_vbox.move_child(block, winner_label.get_index() + 1)

	var heading := Label.new()
	heading.text = "MATCH-STATISTIK"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	block.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 10
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	block.add_child(grid)

	var headers := ["Spieler", "Punkte", "Kills", "Tode", "Schaden", "Nahkampf", "Block", "Heilung", "Treffer", "Runden"]
	for text in headers:
		var header := Label.new()
		header.text = text
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.62, 0.68, 0.78, 1.0))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if text != "Spieler" else HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(header)

	var mvp_index := Global.get_match_mvp_index()
	var all_stats := Global.get_match_stats()
	for slot in Global.get_active_player_indices():
		var hero: HeroData = Global.get_hero(Global.get_player_hero_id(slot))
		var stats: Dictionary = all_stats[slot - 1]
		var display := _player_display_name(slot)
		if slot == mvp_index:
			display = "★ " + display
		var name_label := Label.new()
		name_label.text = display
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", hero.color_tint)
		grid.add_child(name_label)

		var values := [
			str(Global.player_scores[slot - 1]),
			str(int(stats.get("kills", 0.0))),
			str(int(stats.get("deaths", 0.0))),
			str(int(stats.get("damage_dealt", 0.0))),
			# Gewählte Waffe und davon verursachter Schaden.
			"%s · %d" % [Global.get_melee_weapon_label(Global.get_melee_weapon(slot)), int(stats.get("melee_damage", 0.0))],
			str(int(stats.get("damage_blocked", 0.0))),
			str(int(stats.get("healing_done", 0.0))),
			_format_accuracy(stats),
			str(int(stats.get("rounds_won", 0.0))),
		]
		for text in values:
			var value_label := Label.new()
			value_label.text = text
			value_label.add_theme_font_size_override("font_size", 12)
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if slot == mvp_index:
				value_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35, 1.0))
			grid.add_child(value_label)

	var summary := Label.new()
	summary.text = _match_summary_text(mvp_index)
	summary.add_theme_font_size_override("font_size", 13)
	summary.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52, 1.0))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(summary)

func _player_display_name(slot: int) -> String:
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(slot))
	var kind := "P%d" % slot
	var custom_name := Global.get_custom_player_name(slot)
	if Global.is_bot_slot(slot):
		kind = "BOT%d" % slot
	elif Global.network_mode and slot == Global.local_player_index:
		kind = "%s (DU)" % custom_name if not custom_name.is_empty() else "DU"
	elif not custom_name.is_empty():
		kind = custom_name
	var prefix := ""
	if Global.is_team_mode():
		prefix = "[%s] " % Global.get_team_name(Global.get_team_for_slot(slot))
	return "%s%s · %s" % [prefix, kind, hero.name]

func _format_accuracy(stats: Dictionary) -> String:
	var shots := float(stats.get("shots_fired", 0.0))
	var hits := float(stats.get("shots_hit", 0.0))
	if shots <= 0.0:
		return "0%"
	return "%d%%" % int(round(hits / shots * 100.0))

func _match_summary_text(mvp_index: int) -> String:
	var damage_leader := Global.get_match_stat_leader("damage_dealt")
	var block_leader := Global.get_match_stat_leader("blocked_hits")
	var heal_leader := Global.get_match_stat_leader("healing_done")
	var melee_leader := Global.get_match_stat_leader("melee_damage")
	var lines: Array[String] = []
	lines.append("★ Bester Spieler: %s" % _leader_text(mvp_index, "gesamtwert"))
	lines.append("Meister Schaden: %s" % _leader_text(damage_leader, "damage_dealt"))
	lines.append("Meiste blockierte Treffer: %s (%d Treffer · %d Schaden)" % [
		_leader_text(block_leader, "blocked_hits"),
		int(Global.get_match_stat(block_leader, "blocked_hits")),
		int(Global.get_match_stat(block_leader, "damage_blocked")),
	])
	lines.append("Meiste Heilung: %s" % _leader_text(heal_leader, "healing_done"))
	if melee_leader > 0 and Global.get_match_stat(melee_leader, "melee_damage") > 0.0:
		lines.append("Meister Nahkampf: %s" % _leader_text(melee_leader, "melee_damage"))
	return "\n".join(lines)

func _leader_text(slot: int, key: String) -> String:
	if slot <= 0:
		return "—"
	var value := ""
	if key == "damage_dealt":
		value = " · %d Schaden" % int(Global.get_match_stat(slot, key))
	elif key == "healing_done":
		value = " · %d HP" % int(Global.get_match_stat(slot, key))
	elif key == "melee_damage":
		value = " · %d Schaden mit %s" % [int(Global.get_match_stat(slot, key)), Global.get_melee_weapon_label(Global.get_melee_weapon(slot))]
	elif key == "blocked_hits":
		value = ""
	elif key == "gesamtwert":
		value = " · %d Punkte" % Global.player_scores[slot - 1]
	return _player_display_name(slot) + value

func _on_restart_pressed() -> void:
	if _overview != null:
		_overview.visible = false
	SoundManager.play_sound("click")
	restart_requested.emit()

func _on_continue_pressed() -> void:
	if continue_btn.disabled:
		return
	if _overview != null:
		_overview.visible = false
	SoundManager.play_sound("click")
	continue_requested.emit()

# --- Übersicht aller Spieler nach Match-Ende ---

func _ensure_overview_button() -> void:
	if _overview_button == null:
		_overview_button = Button.new()
		_overview_button.text = "ALLE SPIELER, KARTEN & STATS"
		_overview_button.custom_minimum_size = Vector2(320, 44)
		_overview_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_overview_button.add_theme_font_size_override("font_size", 18)
		_overview_button.pressed.connect(func():
			SoundManager.play_sound("click")
			_show_match_overview(Global.local_player_index)
		)
		game_over_vbox.add_child(_overview_button)
	game_over_vbox.move_child(_overview_button, continue_btn.get_index())

func _build_overview() -> void:
	_overview = Control.new()
	_overview.name = "MatchOverview"
	_overview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overview.mouse_filter = Control.MOUSE_FILTER_STOP
	_overview.visible = false
	_tab_layer.add_child(_overview)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overview.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 820)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.13, 0.98)
	style.set_corner_radius_all(14)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(1.0, 0.72, 0.30, 0.85)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "MATCH-ÜBERSICHT · ALLE SPIELER"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
	header.add_child(title)
	var close := Button.new()
	close.text = "SCHLIESSEN"
	close.custom_minimum_size = Vector2(150, 36)
	close.pressed.connect(func():
		SoundManager.play_sound("click")
		_overview.visible = false
	)
	header.add_child(close)

	_overview_tabs = HBoxContainer.new()
	_overview_tabs.add_theme_constant_override("separation", 6)
	outer.add_child(_overview_tabs)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_overview_scroll = scroll

	_overview_content = VBoxContainer.new()
	_overview_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overview_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_overview_content)

func _show_match_overview(slot: int) -> void:
	if _overview == null:
		_build_overview()
	var slots: Array = Global.get_active_player_indices()
	if slots.is_empty():
		return
	if not slots.has(slot):
		slot = slots[0]

	_clear_ui_children(_overview_tabs)
	for s_idx in slots:
		var hero: HeroData = Global.get_hero(Global.get_player_hero_id(s_idx))
		var btn := Button.new()
		btn.text = _player_display_name(s_idx)
		btn.toggle_mode = true
		btn.button_pressed = (s_idx == slot)
		btn.add_theme_font_size_override("font_size", 13)
		if hero != null:
			btn.add_theme_color_override("font_color", hero.color_tint)
		var target: int = s_idx
		btn.pressed.connect(func():
			SoundManager.play_sound("click")
			_show_match_overview.call_deferred(target)
		)
		_overview_tabs.add_child(btn)

	_clear_ui_children(_overview_content)
	var preview := _create_stat_preview(slot)
	if preview != null:
		# _fill_tab_overlay schreibt in _tab_content; kurz umlenken.
		var saved_content := _tab_content
		_tab_content = _overview_content
		_fill_tab_overlay(preview, true, true)
		_tab_content = saved_content
		preview.free()
	_overview.visible = true
