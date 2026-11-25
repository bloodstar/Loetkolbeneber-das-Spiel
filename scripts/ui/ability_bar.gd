class_name AbilityBar
extends PanelContainer

## Fähigkeitenleiste eines lokal gespielten Ebers im HUD (ersetzt seit
## 2026-11-25 die kleinen Symbole unter dem Charakter):
## links die Tasten-Fähigkeiten (Fähigkeit, Dash, Barriere, Ulti) mit
## Abklingzeit, rechts Status-Felder (Schild, aktive Powerups, Gift,
## Zeitstopp). Jedes Feld hat einen Tooltip beim Überfahren mit der Maus.
##
## Alle gelesenen Werte (ability_timer, dash_cd, block_cd, ult, shield,
## Powerup-Timer, poison, tfrz) kommen online per Snapshot, daher funktioniert
## die Leiste auch auf Clients. Die HUD legt eine Leiste pro lokalem Spieler an.

const SlotScript = preload("res://scripts/ui/ability_bar_slot.gd")

const SLOT_SIZE: float = 46.0
const STATUS_SIZE: float = 34.0
const TOOLTIP_REFRESH: float = 0.2

const ABILITY_COLOR: Color = Color(1.0, 0.82, 0.36, 1.0)
const DASH_COLOR: Color = Color(0.42, 0.88, 1.0, 1.0)
const BLOCK_COLOR: Color = Color(0.62, 0.88, 1.0, 1.0)
const ULT_COLOR: Color = Color(1.0, 0.42, 0.85, 1.0)
const SHIELD_COLOR: Color = Color(0.30, 0.70, 1.0, 1.0)
const POISON_COLOR: Color = Color(0.45, 0.95, 0.30, 1.0)
const TIME_COLOR: Color = Color(0.70, 0.62, 1.0, 1.0)

# Powerups in Anzeige-Reihenfolge: [Art, Timer-Feld am Player].
const POWERUP_FIELDS: Array = [
	["invulnerability", "powerup_invuln_timer"],
	["damage", "powerup_damage_timer"],
	["rapid_fire", "powerup_rapid_fire_timer"],
	["auto_attack", "powerup_auto_attack_timer"],
	["multishot", "powerup_multishot_timer"],
	["undying", "powerup_undying_timer"],
	["revenge", "powerup_revenge_timer"],
	["invisible", "powerup_invisible_timer"],
	["overcharge", "overcharge_timer"],
]

var player: Player = null
var _name_label: Label = null
var _ability_row: HBoxContainer = null
var _status_row: HBoxContainer = null
var _slots: Dictionary = {}          # kind -> AbilityBarSlot (Tasten-Felder)
var _status_slots: Dictionary = {}   # kind -> AbilityBarSlot (Status-Felder)
var _status_max: Dictionary = {}     # kind -> größte gesehene Restdauer
var _tooltip_timer: float = 0.0
# Tastentexte nur bei Änderung der Belegung neu holen.
var _key_cache: Dictionary = {}   # suffix -> [kurz, lang]

func setup(p: Player, show_name: bool) -> void:
	player = p
	name = "AbilityBar_%d" % p.player_index
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.78)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(p.player_index))
	var tint: Color = hero.color_tint if hero != null else Color(0.5, 0.6, 0.7)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.55)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", UiTheme.FS_XS)
	_name_label.add_theme_color_override("font_color", tint)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.visible = show_name
	_name_label.text = "P%d · %s" % [p.player_index, hero.name if hero != null else ""]
	vbox.add_child(_name_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(row)

	_ability_row = HBoxContainer.new()
	_ability_row.add_theme_constant_override("separation", 4)
	_ability_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_ability_row)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 3)
	_status_row.alignment = BoxContainer.ALIGNMENT_END
	_status_row.size_flags_vertical = Control.SIZE_SHRINK_END
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_status_row)

	for entry in [["ability", ABILITY_COLOR, "ability"], ["dash", DASH_COLOR, "dash"], ["block", BLOCK_COLOR, "block"], ["ult", ULT_COLOR, "ult"]]:
		var slot: AbilityBarSlot = SlotScript.new(str(entry[0]), SLOT_SIZE, false)
		slot.accent = entry[1]
		slot.set_meta("action_suffix", entry[2])
		_ability_row.add_child(slot)
		_slots[entry[0]] = slot
	_refresh_keys()
	if not GameSettings.settings_changed.is_connected(_refresh_keys):
		GameSettings.settings_changed.connect(_refresh_keys)
	refresh(0.0, true)

func _refresh_keys() -> void:
	if not is_instance_valid(player):
		return
	# Online spielt jeder mit der eigenen Belegung (p1_*); lokal hat Spieler 2
	# die p2_*-Tasten (siehe Player._act).
	var prefix := "p1_" if Global.network_mode or player.player_index == 1 else "p2_"
	for suffix in ["ability", "dash", "block", "ult"]:
		var text: String = GameSettings.get_binding_text(prefix + suffix)
		_key_cache[suffix] = [_short_key(text), text]
	for kind in _slots.keys():
		var slot: AbilityBarSlot = _slots[kind]
		slot.key_text = _key_for(str(slot.get_meta("action_suffix")))

func _process(delta: float) -> void:
	refresh(delta)

func refresh(delta: float, force_tooltips: bool = false) -> void:
	if not is_instance_valid(player):
		return
	_tooltip_timer -= delta
	var update_tips: bool = force_tooltips or _tooltip_timer <= 0.0
	if update_tips:
		_tooltip_timer = TOOLTIP_REFRESH
	var dead: bool = player.is_dead or player.current_health <= 0.0
	modulate.a = 0.55 if dead else 1.0
	_update_ability_slots(update_tips)
	_update_status_slots(update_tips)

# --- Tasten-Fähigkeiten ---

func _key_for(suffix: String) -> String:
	return str((_key_cache.get(suffix, ["", ""]) as Array)[0])

func _key_long(suffix: String) -> String:
	return str((_key_cache.get(suffix, ["", ""]) as Array)[1])

func _short_key(text: String) -> String:
	match text:
		"Linksklick":
			return "LMB"
		"Rechtsklick":
			return "RMB"
		"Mausrad-Klick":
			return "MMB"
		"Maustaste 4":
			return "M4"
		"Maustaste 5":
			return "M5"
		"Umschalt":
			return "Shift"
		"Leertaste":
			return "Spc"
		"Pfeil links":
			return "<-"
		"Pfeil rechts":
			return "->"
		"Pfeil hoch":
			return "Hoch"
		"Pfeil runter":
			return "Runt"
	if text.length() > 5:
		return text.substr(0, 4)
	return text

func _update_ability_slots(update_tips: bool) -> void:
	var hero: HeroData = Global.get_hero(Global.get_player_hero_id(player.player_index))

	var ability: AbilityBarSlot = _slots["ability"]
	_set_cooldown(ability, player.ability_timer, player.ability_max_cooldown)
	ability.accent = hero.color_tint.lerp(ABILITY_COLOR, 0.45) if hero != null else ABILITY_COLOR

	var dash: AbilityBarSlot = _slots["dash"]
	dash.charges = player.dash_charges
	dash.charges_max = player.dash_charges_max
	if player.dash_charges > 0:
		# Mit Ladungen übrig ist der Dash bereit; die Füllung zeigt dann nur
		# die nächste Ladung an, ohne das Feld abzudunkeln.
		_set_cooldown(dash, 0.0, player.dash_cooldown)
		if player.dash_charges < player.dash_charges_max and player.dash_cooldown_timer > 0.0:
			dash.center_text = ""
	else:
		_set_cooldown(dash, player.dash_cooldown_timer, player.dash_cooldown)

	var block: AbilityBarSlot = _slots["block"]
	block.is_active = player.is_blocking
	_set_cooldown(block, player.block_cooldown_timer, player.block_cooldown)
	if player.is_blocking:
		block.center_text = ""
		block.is_ready = true

	var ult: AbilityBarSlot = _slots["ult"]
	ult.visible = player.has_ult()
	if ult.visible:
		_set_cooldown(ult, player.ult_timer, player.ult_max_cooldown)

	for kind in _slots.keys():
		var slot: AbilityBarSlot = _slots[kind]
		if update_tips:
			slot.set_tooltip_if_changed(_ability_tooltip(str(kind), hero))
		slot.queue_redraw()

func _set_cooldown(slot: AbilityBarSlot, remaining: float, total: float) -> void:
	var left: float = maxf(0.0, remaining)
	slot.cooldown_left = left
	slot.cooldown_ratio = clampf(left / maxf(0.001, total), 0.0, 1.0) if left > 0.0 else 0.0
	slot.is_ready = left <= 0.0
	slot.center_text = _format_cooldown(left) if left > 0.0 else ""

static func _format_cooldown(seconds: float) -> String:
	if seconds >= 10.0:
		return "%d" % ceili(seconds)
	# Aufrunden, damit kurz vor Ablauf nicht "0,0" dasteht.
	return ("%.1f" % (ceilf(seconds * 10.0) / 10.0)).replace(".", ",")

static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return ("%.1f" % value).replace(".", ",")

func _state_line(left: float) -> String:
	if left <= 0.0:
		return "Bereit"
	return "Bereit in %s s" % _num(snappedf(left, 0.1))

func _ability_tooltip(kind: String, hero: HeroData) -> String:
	var slot: AbilityBarSlot = _slots[kind]
	var key: String = _key_long(str(slot.get_meta("action_suffix")))
	var lines: Array[String] = []
	match kind:
		"ability":
			lines.append("%s  [%s]" % [player.ability_name if player.ability_name != "" else "Fähigkeit", key])
			if hero != null and hero.ability_desc != "":
				lines.append(hero.ability_desc)
			lines.append("Abklingzeit: %s s" % _num(player.ability_max_cooldown))
			lines.append(_state_line(player.ability_timer))
		"dash":
			var dash_name: String = hero.dash_name if hero != null and hero.dash_name != "" else "Dash"
			lines.append("%s  [%s]" % [dash_name, key])
			if hero != null and hero.dash_desc != "":
				lines.append(hero.dash_desc)
			lines.append("Abklingzeit: %s s" % _num(player.dash_cooldown))
			if player.dash_charges_max > 1:
				lines.append("Ladungen: %d / %d" % [player.dash_charges, player.dash_charges_max])
			lines.append("Bereit" if player.dash_charges > 0 else _state_line(player.dash_cooldown_timer))
		"block":
			lines.append("Barriere  [%s]" % key)
			lines.append("%s s kein Schaden, gegnerische Projektile werden zurückgeworfen. Hält %d Treffer aus, dann zerbricht sie." % [_num(player.block_duration), player.block_max_hits])
			lines.append("Abklingzeit: %s s" % _num(player.block_cooldown))
			lines.append("AKTIV" if player.is_blocking else _state_line(player.block_cooldown_timer))
		"ult":
			lines.append("%s  [%s]" % [player.ult_name if player.ult_name != "" else "Ulti", key])
			if hero != null and hero.ult_desc != "":
				lines.append(hero.ult_desc)
			lines.append("Abklingzeit: %s s" % _num(player.ult_max_cooldown))
			lines.append(_state_line(player.ult_timer))
	return "\n".join(lines)

# --- Status ---

func _update_status_slots(update_tips: bool) -> void:
	var wanted: Array = []   # [kind, accent, ratio, center_text, tooltip]
	if player.max_shield > 0.0 or player.current_shield > 0.0:
		var cap: float = maxf(player.max_shield, player.current_shield)
		var ratio: float = clampf(player.current_shield / maxf(1.0, cap), 0.0, 1.0)
		var tip := "Schild: %d / %d\nFängt Schaden ab, bevor das Leben sinkt. Lädt sich %s s nach dem letzten Treffer wieder auf." % [roundi(player.current_shield), roundi(player.max_shield), _num(player.shield_regen_delay)]
		wanted.append(["shield", SHIELD_COLOR, ratio, "%d" % roundi(player.current_shield), tip])
	for field in POWERUP_FIELDS:
		var kind: String = field[0]
		var left: float = float(player.get(field[1]))
		if left <= 0.0:
			_status_max.erase(kind)
			continue
		var top: float = maxf(float(_status_max.get(kind, 0.0)), left)
		_status_max[kind] = top
		var color: Color = Player.POWERUP_GLOW_COLORS.get(kind, Color.WHITE)
		wanted.append([kind, color, left / maxf(0.001, top), _format_cooldown(left), _powerup_tooltip(kind, left)])
	if player.poison_ticks_left > 0:
		wanted.append(["poison", POISON_COLOR, -1.0, "", "Vergiftet\nVerliert in kurzen Abständen Leben (%d Ticks übrig)." % player.poison_ticks_left])
	if player.time_frozen_timer > 0.0:
		var tf: float = player.time_frozen_timer
		var tf_top: float = maxf(float(_status_max.get("time_frozen", 0.0)), tf)
		_status_max["time_frozen"] = tf_top
		wanted.append(["time_frozen", TIME_COLOR, tf / maxf(0.001, tf_top), _format_cooldown(tf), "Zeitstopp\nIn der Zeit eingefroren: keine Bewegung, keine Angriffe. Noch %s s." % _num(snappedf(tf, 0.1))])
	else:
		_status_max.erase("time_frozen")

	var keep: Dictionary = {}
	for i in range(wanted.size()):
		var w: Array = wanted[i]
		var kind: String = w[0]
		keep[kind] = true
		var slot: AbilityBarSlot = _status_slots.get(kind, null)
		if slot == null:
			slot = SlotScript.new(kind, STATUS_SIZE, true)
			_status_row.add_child(slot)
			_status_slots[kind] = slot
			update_tips = true
		if slot.get_index() != i:
			_status_row.move_child(slot, i)
		slot.accent = w[1]
		slot.status_ratio = w[2]
		slot.center_text = w[3]
		if update_tips:
			slot.set_tooltip_if_changed(w[4])
		slot.queue_redraw()
	for kind in _status_slots.keys():
		if not keep.has(kind):
			var old: AbilityBarSlot = _status_slots[kind]
			_status_slots.erase(kind)
			old.queue_free()
	_status_row.visible = not _status_slots.is_empty()

func _powerup_tooltip(kind: String, left: float) -> String:
	var title: String = kind
	var desc: String = ""
	if kind == "overcharge":
		title = player.ult_name if player.ult_name != "" else "Überladung"
		desc = "Ulti aktiv."
	elif Global.POWERUP_INFO.has(kind):
		var info: Dictionary = Global.POWERUP_INFO[kind]
		title = str(info.get("name", kind))
		desc = str(info.get("description", ""))
	var lines: Array[String] = ["Powerup: %s" % title if kind != "overcharge" else title]
	if desc != "":
		lines.append(desc)
	lines.append("Noch %s s" % _num(snappedf(left, 0.1)))
	return "\n".join(lines)
