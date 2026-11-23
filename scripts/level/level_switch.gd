class_name LevelSwitch
extends Node2D

## Schalter in einer Map. Zwei Bauformen:
##  "lever" Hebel an Wand oder Säule. Wird durch Schüsse, Nahkampf und
##          Explosionen umgelegt. Spieler laufen hindurch (Kollisionsebene der
##          Türme: Kugeln und Schläge treffen, Körper nicht).
##  "plate" Bodenplatte. Gedrückt, solange ein Spieler, eine Kiste oder eine
##          Kugel darauf steht, und noch `duration` Sekunden danach.
## Zwei Betriebsarten:
##  "timed"  An für `duration` Sekunden, dann aus. Während er an ist, lässt er
##           sich nicht erneut auslösen (wie Zeitschalter in Zelda).
##  "toggle" Ein Treffer schaltet an, ein weiterer Treffer schaltet wieder aus.
##           Spätestens nach `duration` Sekunden fällt er von selbst zurück.
## Nach dem Ausschalten ist der Schalter `cooldown` Sekunden gesperrt (rote
## Lampe), damit niemand eine Tür im Dauerfeuer flattern lässt.
##
## Lesbarkeit: Kanalfarbe auf Schalter und Ziel, Ring mit Restzeit, in der
## letzten 1,5 s tickt der Schalter hörbar. Host entscheidet, Clients folgen
## per Snapshot.

const TILE_SIZE: float = 36.0
const LEVER_HALF: Vector2 = Vector2(14.0, 17.0)
const PLATE_HALF_W: float = 26.0
const PLATE_H: float = 8.0
const WARN_TIME: float = 1.5
## Mindestzeit zwischen An und Aus im Toggle-Betrieb (ein Schrotschuss soll
## nicht an- und gleich wieder ausschalten).
const TOGGLE_LOCK: float = 0.6
const BLAST_HIT_RADIUS: float = 18.0

var net_id: int = 0
var object_type: String = "level_switch"
var is_replica: bool = false
var network = null

var kind: String = "lever"
var mode: String = "timed"
var channel: int = 0
var duration: float = 6.0
var cooldown: float = 3.0
## Hebel: Richtung, in die er von der Wand absteht (nur Optik).
var facing: float = 1.0

var is_on: bool = false
var remaining: float = 0.0
var cooldown_left: float = 0.0
var pressed: bool = false

var _since_on: float = 0.0
var _tick_timer: float = 0.0
var _flash: float = 0.0
var _body: StaticBody2D = null
var _area: Area2D = null
var _color: Color = Color.WHITE

func _ready() -> void:
	add_to_group("level_switch")
	z_index = 3
	_color = SwitchNetwork.channel_color(channel)
	if kind == "plate":
		_build_plate()
	else:
		_build_lever()

func _build_lever() -> void:
	_body = _HitProxy.new()
	_body.name = "Hitbox"
	# Ebene der Türme: Kugeln (Maske 19) und Nahkampf (1 | 16) treffen ihn,
	# Spieler (Maske 7) laufen hindurch.
	_body.collision_layer = Companion.TOWER_COLLISION_LAYER
	_body.collision_mask = 0
	_body.set("owner_switch", self)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = LEVER_HALF * 2.0
	col.shape = rect
	_body.add_child(col)
	add_child(_body)

func _build_plate() -> void:
	_area = Area2D.new()
	_area.collision_layer = 0
	# Spieler (2) und bewegliche Objekte auf Ebene 1 (Kisten, Kugeln).
	_area.collision_mask = 1 | 2
	_area.monitorable = false
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PLATE_HALF_W * 2.0 - 6.0, 16.0)
	col.shape = rect
	col.position = Vector2(0.0, -10.0)
	_area.add_child(col)
	add_child(_area)

# --- Auslösen (nur Host) -----------------------------------------------------

func _round_running() -> bool:
	if Global.current_state != Global.GameState.PLAYING:
		return false
	var scene := get_tree().current_scene
	return scene == null or scene.get("countdown_active") != true

func is_ready() -> bool:
	return not is_on and cooldown_left <= 0.0

## Projektile und Nahkampf (gleiche Schnittstelle wie zerstörbare Kacheln).
func hit_tile(_amount: float = 0.0) -> void:
	if is_replica or kind != "lever" or not _round_running():
		return
	if is_on:
		if mode == "toggle" and _since_on >= TOGGLE_LOCK:
			_switch_off()
		return
	if cooldown_left > 0.0:
		# Gesperrt: kurz rot aufblitzen, damit der Treffer nicht verpufft wirkt.
		_flash = 0.25
		NetFx.send("mobj", NetFx.mobj_args(self, "denied"))
		return
	_switch_on()

func apply_blast(blast_position: Vector2, radius: float, _strength: float = 1.0) -> void:
	if kind != "lever":
		return
	if blast_position.distance_to(global_position) <= radius + BLAST_HIT_RADIUS:
		hit_tile(30.0)

func _switch_on() -> void:
	is_on = true
	remaining = duration
	_since_on = 0.0
	_tick_timer = 0.0
	play_network_fx("on")
	NetFx.send("mobj", NetFx.mobj_args(self, "on"))
	if network != null:
		network.on_switch_changed(channel)

func _switch_off() -> void:
	is_on = false
	remaining = 0.0
	cooldown_left = cooldown
	play_network_fx("off")
	NetFx.send("mobj", NetFx.mobj_args(self, "off"))
	if network != null:
		network.on_switch_changed(channel)

func _physics_process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if is_replica:
		# Clients zählen die Ringanzeige weich weiter; der Snapshot korrigiert.
		if is_on:
			remaining = maxf(0.0, remaining - delta)
		elif cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		queue_redraw()
		return
	if kind == "plate":
		pressed = _round_running() and _plate_has_weight()
	if is_on:
		_since_on += delta
		if kind == "plate" and pressed:
			remaining = duration
		else:
			remaining -= delta
			if remaining <= WARN_TIME:
				_tick_timer -= delta
				if _tick_timer <= 0.0:
					_tick_timer = 0.5
					play_network_fx("tick")
					NetFx.send("mobj", NetFx.mobj_args(self, "tick"))
		if remaining <= 0.0:
			_switch_off()
	else:
		if cooldown_left > 0.0:
			cooldown_left = maxf(0.0, cooldown_left - delta)
		elif kind == "plate" and pressed:
			_switch_on()
	queue_redraw()

func _plate_has_weight() -> bool:
	if _area == null:
		return false
	for body in _area.get_overlapping_bodies():
		if body is Player:
			if (body as Player).current_health > 0.0:
				return true
		elif body is RigidBody2D:
			return true
	return false

## Neue Runde / Neuaufbau: alles zurück.
func reset_state() -> void:
	is_on = false
	remaining = 0.0
	cooldown_left = 0.0

# --- Optik und Ton -----------------------------------------------------------

func play_network_fx(method: String) -> void:
	match method:
		"on":
			SoundManager.play_sound("click", 0.05, 0.0)
			SoundManager.play_sound("confirm", 0.08, -8.0)
			_flash = 0.3
		"off":
			SoundManager.play_sound("click", 0.05, -4.0)
		"tick":
			SoundManager.play_sound("click", 0.02, -10.0)
		"denied":
			_flash = 0.25
			SoundManager.play_sound("hit", 0.1, -12.0)
	queue_redraw()

func _draw() -> void:
	if kind == "plate":
		_draw_plate()
	else:
		_draw_lever()

func _draw_lever() -> void:
	var plate := Rect2(-LEVER_HALF, LEVER_HALF * 2.0)
	draw_rect(plate, Color(0.1, 0.11, 0.14, 0.95))
	var rim := _color if cooldown_left <= 0.0 or is_on else Color(0.85, 0.2, 0.2)
	if _flash > 0.0 and not is_on and cooldown_left > 0.0:
		rim = Color(1.0, 0.4, 0.4)
	draw_rect(plate, Color(rim.r, rim.g, rim.b, 0.9), false, 2.5)
	# Schlitz und Hebel: aus = nach links gekippt, an = nach rechts.
	var pivot := Vector2(0.0, 8.0)
	draw_line(Vector2(-7.0, pivot.y + 1.0), Vector2(7.0, pivot.y + 1.0), Color(0.0, 0.0, 0.0, 0.8), 4.0)
	var angle := deg_to_rad(35.0) if is_on else deg_to_rad(-35.0)
	angle *= facing
	var tip := pivot + Vector2(0.0, -20.0).rotated(angle)
	draw_line(pivot, tip, Color(0.78, 0.8, 0.85), 3.5)
	var knob := _color if is_on else _color.darkened(0.45)
	if _flash > 0.0 and is_on:
		knob = knob.lightened(0.5)
	draw_circle(tip, 5.0, knob)
	draw_circle(pivot, 3.0, Color(0.35, 0.37, 0.42))
	_draw_timer_ring(Vector2.ZERO, 23.0)

func _draw_plate() -> void:
	var h := 3.0 if (is_on or pressed) else PLATE_H
	var base := Rect2(Vector2(-PLATE_HALF_W - 3.0, -3.0), Vector2(PLATE_HALF_W * 2.0 + 6.0, 3.0))
	draw_rect(base, Color(0.12, 0.12, 0.15, 1.0))
	var top := Rect2(Vector2(-PLATE_HALF_W, -3.0 - h), Vector2(PLATE_HALF_W * 2.0, h))
	var col := _color if is_on else _color.darkened(0.5)
	if cooldown_left > 0.0 and not is_on:
		col = Color(0.6, 0.18, 0.18)
	draw_rect(top, col)
	draw_line(top.position + Vector2(2.0, 1.0), top.position + Vector2(top.size.x - 2.0, 1.0), col.lightened(0.4), 1.5)
	# Restzeit als Balken über der Platte.
	if is_on and not pressed and duration > 0.0:
		var f := clampf(remaining / duration, 0.0, 1.0)
		var bar_col := _color if remaining > WARN_TIME or fmod(remaining, 0.5) > 0.25 else Color(1.0, 0.3, 0.3)
		draw_rect(Rect2(Vector2(-PLATE_HALF_W, -18.0), Vector2(PLATE_HALF_W * 2.0 * f, 4.0)), bar_col)
	elif cooldown_left > 0.0 and cooldown > 0.0:
		var f2 := 1.0 - clampf(cooldown_left / cooldown, 0.0, 1.0)
		draw_rect(Rect2(Vector2(-PLATE_HALF_W, -18.0), Vector2(PLATE_HALF_W * 2.0 * f2, 3.0)), Color(0.85, 0.2, 0.2, 0.8))

## Ring um den Hebel: läuft während der Restzeit leer, in der Sperre füllt
## er sich rot wieder auf.
func _draw_timer_ring(center: Vector2, radius: float) -> void:
	if is_on and duration > 0.0:
		var f := clampf(remaining / duration, 0.0, 1.0)
		var col := _color
		if remaining <= WARN_TIME and fmod(remaining, 0.5) < 0.25:
			col = Color(1.0, 0.3, 0.3)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Color(col.r, col.g, col.b, 0.9), 3.5)
	elif cooldown_left > 0.0 and cooldown > 0.0:
		var f2 := 1.0 - clampf(cooldown_left / cooldown, 0.0, 1.0)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * f2, 40, Color(0.85, 0.2, 0.2, 0.6), 2.0)
	else:
		# Bereit: dezenter Ring in Kanalfarbe.
		var pulse := 0.25 + 0.15 * sin(float(Time.get_ticks_msec()) / 300.0)
		draw_arc(center, radius, 0.0, TAU, 40, Color(_color.r, _color.g, _color.b, pulse), 2.0)

# --- Netzwerk ------------------------------------------------------------------

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"on": is_on,
		"r": snappedf(remaining, 0.05),
		"cd": snappedf(cooldown_left, 0.05),
		"p": pressed,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	is_on = bool(data.get("on", is_on))
	remaining = float(data.get("r", remaining))
	cooldown_left = float(data.get("cd", cooldown_left))
	pressed = bool(data.get("p", pressed))
	queue_redraw()

# --- Bots ------------------------------------------------------------------------

## Punkt, auf den ein Bot schießt (Hebel) bzw. zu dem er läuft (Platte).
func get_aim_point() -> Vector2:
	return global_position if kind == "lever" else global_position + Vector2(0.0, -12.0)

func get_hitbox_rid() -> RID:
	return _body.get_rid() if _body != null else RID()

func bot_value(bot: Node2D, enemy: Node2D) -> float:
	if network == null or not is_ready():
		return 0.0
	return float(network.bot_value_for(self, bot, enemy))

# Trefferkörper des Hebels: leitet Schüsse und Schläge an den Schalter weiter.
const _HitProxy = preload("res://scripts/level/level_switch_hitbox.gd")
