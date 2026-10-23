class_name HUD
extends CanvasLayer

# Wird ausgelöst, wenn im Game-Over-Banner "Nochmal" geklickt wird. Der Main-Node
# räumt daraufhin in-place auf, ohne die Szene neu zu laden.
signal restart_requested

@onready var player_boxes: HBoxContainer = $Top/PlayerBoxes
@onready var score_label: Label = $Top/Center_Box/ScoreLabel
@onready var sudden_death_label: Label = $Top/Center_Box/SuddenDeathLabel
@onready var ping_label: Label = $Top/Center_Box/PingLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_vbox: VBoxContainer = $GameOverPanel/VBox
@onready var winner_label: Label = $GameOverPanel/VBox/WinnerLabel
@onready var restart_btn: Button = $GameOverPanel/VBox/RestartBtn

@onready var countdown_label: Label = $CountdownLabel

# player_index -> { name, hp, shield, ammo, ability, cards }
var boxes: Dictionary = {}
var tracked_players: Array[Player] = []

# Eigene Upgrade-Karten: dauerhafte Icon-Leiste unten links + Tab-Overlay.
var _upgrade_bar: PanelContainer = null
var _upgrade_flow: HFlowContainer = null
var _upgrade_title: Label = null
var _tab_overlay: Control = null
var _tab_content: VBoxContainer = null
var _tab_refresh_timer: float = 0.0

const TAB_REFRESH_INTERVAL: float = 0.35
const MAX_UPGRADE_ICONS: int = 16

func _ready() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false
	restart_btn.pressed.connect(_on_restart_pressed)

	Global.scores_changed.connect(_on_scores_changed)
	Global.match_over.connect(_on_match_over)
	Global.scoring_config_changed.connect(_on_scoring_config_changed)
	Global.card_selected.connect(_on_card_selected)
	NetworkManager.ping_updated.connect(_update_ping)

	_build_upgrade_bar()
	_build_tab_overlay()
	_update_ping()
	_update_score()

func _process(delta: float) -> void:
	if _tab_overlay == null:
		return
	var wants_overlay := Input.is_physical_key_pressed(KEY_TAB) and _can_show_tab_overlay()
	if wants_overlay:
		if not _tab_overlay.visible:
			_refresh_tab_overlay()
			_tab_overlay.visible = true
			_tab_refresh_timer = 0.0
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

	var ammo_label := Label.new()
	ammo_label.add_theme_font_size_override("font_size", 11)
	box.add_child(ammo_label)

	var ability_label := Label.new()
	ability_label.add_theme_font_size_override("font_size", 11)
	box.add_child(ability_label)

	var block_label := Label.new()
	block_label.add_theme_font_size_override("font_size", 11)
	block_label.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	block_label.text = "Block [Q]: BEREIT"
	box.add_child(block_label)

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
		"ability": ability_label,
		"block": block_label,
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
	player.ammo_changed.connect(func(cur, max_a):
		ui["ammo"].text = _ammo_text(cur, max_a, player.is_reloading)
	)
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
		ui["name"].text = "%s%s (%s)" % [tag, hero.name, hero.role]
		if Global.is_team_mode():
			ui["name"].add_theme_color_override("font_color", Global.get_team_color(p.team_id))
		else:
			ui["name"].add_theme_color_override("font_color", hero.color_tint)
		ui["ammo"].text = _ammo_text(p.current_ammo, p.max_ammo, p.is_reloading)
		if p.ability_timer <= 0.0:
			ui["ability"].text = "%s: BEREIT!" % p.ability_name
		else:
			ui["ability"].text = "%s: %.1fs" % [p.ability_name, p.ability_timer]
		ui["block"].text = _block_text(p.is_blocking, p.block_cooldown_timer)
		ui["cards"].text = "Upgrades: %d" % Global.get_player_cards(p.player_index).size()
	_update_score()

func _ammo_text(current: int, maximum: int, reloading: bool) -> String:
	if reloading:
		return "Munition: NACHLADEN (%d / %d)" % [current, maximum]
	return "Munition: %d / %d" % [current, maximum]

func _block_text(active: bool, cooldown: float) -> String:
	if active:
		return "Block [Q]: AKTIV"
	if cooldown <= 0.0:
		return "Block [Q]: BEREIT"
	return "Block [Q]: %.1fs" % cooldown

func _update_score() -> void:
	var parts: Array[String] = []
	if Global.is_team_mode():
		for team in range(1, Global.get_team_count() + 1):
			parts.append("%s %d" % [Global.get_team_name(team), Global.get_team_score(team)])
		score_label.text = "   ".join(parts) + "\n(Team-Ziel: %d Punkte)" % Global.points_to_win
		return
	for i in range(Global.player_count):
		var label := "P%d" % (i + 1)
		if Global.is_bot_slot(i + 1):
			label = "BOT%d" % (i + 1)
		parts.append("%s %d" % [label, Global.player_scores[i]])
	score_label.text = "   ".join(parts) + "\n(Ziel: %d Punkte)" % Global.points_to_win

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
	add_child(_tab_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.02, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 560)
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

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(scroll)

	_tab_content = VBoxContainer.new()
	_tab_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_content.add_theme_constant_override("separation", 10)
	_tab_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_tab_content)

func _can_show_tab_overlay() -> bool:
	if Global.is_spectator or Global.local_player_index < 1:
		return false
	if game_over_panel.visible:
		return false
	return Global.current_state == Global.GameState.PLAYING

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

	var description := Label.new()
	description.text = card.description
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
	_clear_ui_children(_tab_content)
	var p := _local_player()
	if p == null:
		return

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
	_add_stat_cell(stats_grid, "SCHADEN", "%.1f" % p.bullet_damage, Color(1.0, 0.65, 0.35))
	_add_stat_cell(stats_grid, "FEUERRATE", "%.2f / s" % (1.0 / maxf(0.01, p.fire_rate_cooldown)), Color(1.0, 0.82, 0.35))
	_add_stat_cell(stats_grid, "TEMPO", "%d" % int(round(p.move_speed)), Color(0.55, 0.90, 1.0))
	_add_stat_cell(stats_grid, "MUNITION", "%d / %d" % [p.current_ammo, p.max_ammo], Color(0.85, 0.85, 0.90))
	_add_stat_cell(stats_grid, "NACHLADEN", "%.2f s" % p.reload_time, Color(0.85, 0.85, 0.90))
	_add_stat_cell(stats_grid, "SPRÜNGE", "%d" % p.max_jumps, Color(0.70, 0.85, 1.0))
	_add_stat_cell(stats_grid, "BLOCK", "%s · %.1f s / %.1f s" % ["AKTIV" if p.is_blocking else "BEREIT", p.block_cooldown, p.block_duration], Color(0.55, 0.85, 1.0))
	_add_stat_cell(stats_grid, "FÄHIGKEIT", "%s (%.1f s)" % [p.ability_name, p.ability_max_cooldown], hero_color)
	_add_stat_cell(stats_grid, "KILLS", "%d" % int(Global.get_match_stat(p.player_index, "kills")), Color(0.85, 0.90, 1.0))
	_add_stat_cell(stats_grid, "TODE", "%d" % int(Global.get_match_stat(p.player_index, "deaths")), Color(0.95, 0.55, 0.55))
	_add_stat_cell(stats_grid, "SCHADEN GESAMT", "%d" % int(Global.get_match_stat(p.player_index, "damage_dealt")), Color(1.0, 0.65, 0.35))
	_add_stat_cell(stats_grid, "HEILUNG", "%d" % int(Global.get_match_stat(p.player_index, "healing_done")), Color(0.45, 0.95, 0.50))

	var cards := Global.get_player_cards(p.player_index)
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

func set_sudden_death(active: bool) -> void:
	sudden_death_label.visible = active

func reset_for_round() -> void:
	game_over_panel.visible = false
	sudden_death_label.visible = false
	countdown_label.visible = false
	if _tab_overlay != null:
		_tab_overlay.visible = false
	restart_btn.text = "HAUPTMENÜ" if Global.network_mode else "NOCHMAL"
	_refresh_upgrade_bar()

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

func _on_match_over(winner_idx: int) -> void:
	game_over_panel.visible = true
	if _tab_overlay != null:
		_tab_overlay.visible = false
	if _upgrade_bar != null:
		_upgrade_bar.visible = false
	game_over_panel.offset_left = -540.0
	game_over_panel.offset_top = -320.0
	game_over_panel.offset_right = 540.0
	game_over_panel.offset_bottom = 320.0
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(winner_idx))
	var kind := ""
	if Global.is_team_mode():
		var team := Global.get_team_for_slot(winner_idx)
		winner_label.text = "🏆 TEAM %s GEWINNT DAS MATCH! 🏆" % Global.get_team_name(team)
	elif Global.is_bot_slot(winner_idx):
		kind = "BOT"
	elif Global.network_mode and winner_idx == Global.local_player_index:
		kind = "DU"
	else:
		kind = "SPIELER %d" % winner_idx
	if not Global.is_team_mode():
		winner_label.text = "🏆 %s (%s) GEWINNT DAS MATCH! 🏆" % [hero.name.to_upper(), kind]
	_build_match_stats()
	restart_btn.text = "HAUPTMENÜ" if Global.network_mode else "NOCHMAL"
	SoundManager.play_sound("confirm")

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
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	block.add_child(grid)

	var headers := ["Spieler", "Punkte", "Kills", "Tode", "Schaden", "Block", "Heilung", "Treffer", "Runden"]
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
	if Global.is_bot_slot(slot):
		kind = "BOT%d" % slot
	elif Global.network_mode and slot == Global.local_player_index:
		kind = "DU"
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
	var lines: Array[String] = []
	lines.append("★ Bester Spieler: %s" % _leader_text(mvp_index, "gesamtwert"))
	lines.append("Meister Schaden: %s" % _leader_text(damage_leader, "damage_dealt"))
	lines.append("Meiste blockierte Treffer: %s (%d Treffer · %d Schaden)" % [
		_leader_text(block_leader, "blocked_hits"),
		int(Global.get_match_stat(block_leader, "blocked_hits")),
		int(Global.get_match_stat(block_leader, "damage_blocked")),
	])
	lines.append("Meiste Heilung: %s" % _leader_text(heal_leader, "healing_done"))
	return "\n".join(lines)

func _leader_text(slot: int, key: String) -> String:
	if slot <= 0:
		return "—"
	var value := ""
	if key == "damage_dealt":
		value = " · %d Schaden" % int(Global.get_match_stat(slot, key))
	elif key == "healing_done":
		value = " · %d HP" % int(Global.get_match_stat(slot, key))
	elif key == "blocked_hits":
		value = ""
	elif key == "gesamtwert":
		value = " · %d Punkte" % Global.player_scores[slot - 1]
	return _player_display_name(slot) + value

func _on_restart_pressed() -> void:
	SoundManager.play_sound("click")
	restart_requested.emit()
