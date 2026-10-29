class_name BallGate
extends StaticBody2D

## Kettensperre, die Kugeln auf einer Schräge zurückhält (Map Kugellawine).
## Eine senkrecht gespannte Kette zwischen zwei Bolzen. Sie ist bewusst ein
## fester Körper statt einer Gliederkette: Ein Dutzend schwerer Kugeln würde
## eine Kette aus leichten Gelenkgliedern dehnen und zittern lassen.
##
## Sie reißt, wenn sie genug Treffer abbekommt (Projektile, Nahkampf,
## Explosionen) oder spätestens release_time Sekunden nach Rundenbeginn.
## Kurz vorher blinkt sie rot. Host entscheidet, Clients folgen per Snapshot.

signal released

const WIDTH: float = 10.0
const LINK_LENGTH: float = ChainLink.LENGTH
const MAX_HEALTH: float = 60.0
const WARN_TIME: float = 1.6

var net_id: int = 0
var object_type: String = "ball_gate"
var is_replica: bool = false
var height_px: float = 90.0
var release_time: float = 7.0
var tint: Color = Color(0.66, 0.70, 0.76, 1.0)
var health: float = MAX_HEALTH

var _open: bool = false
var _elapsed: float = 0.0
var _warn: bool = false
var _links: Node2D = null
var _shape: CollisionShape2D = null

func _ready() -> void:
	add_to_group("ball_gate")
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(WIDTH, height_px)
	_shape.shape = rect
	_shape.position = Vector2(0.0, height_px * 0.5)
	add_child(_shape)
	_build_visual()

## Ursprung = oberer Bolzen; die Kette hängt height_px nach unten.
func _build_visual() -> void:
	_links = Node2D.new()
	add_child(_links)
	var count := maxi(2, int(round(height_px / LINK_LENGTH)))
	var step := height_px / float(count)
	var dark := Color(tint.r * 0.38, tint.g * 0.38, tint.b * 0.42, 1.0)
	for i in range(count):
		var y := step * (float(i) + 0.5)
		var link := Line2D.new()
		if i % 2 == 0:
			var pts := PackedVector2Array()
			for k in range(13):
				var a := TAU * float(k) / 12.0
				pts.append(Vector2(sin(a) * 4.6, -cos(a) * (step * 0.5 + 2.0)))
			link.points = pts
			link.width = 3.2
			link.default_color = tint
		else:
			link.points = PackedVector2Array([Vector2(0.0, -step * 0.5 - 2.0), Vector2(0.0, step * 0.5 + 2.0)])
			link.width = 4.6
			link.default_color = dark
			link.begin_cap_mode = Line2D.LINE_CAP_ROUND
			link.end_cap_mode = Line2D.LINE_CAP_ROUND
		link.position = Vector2(0.0, y)
		_links.add_child(link)
	for y in [0.0, height_px]:
		var bolt := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(8):
			var a := TAU * float(i) / 8.0 + PI / 8.0
			pts.append(Vector2(cos(a), sin(a)) * 7.0)
		bolt.polygon = pts
		bolt.color = dark
		bolt.position = Vector2(0.0, y)
		add_child(bolt)

func _physics_process(delta: float) -> void:
	if _open:
		return
	if _warn:
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.025)
		_links.modulate = Color(1.0 + pulse, 0.55 + 0.45 * (1.0 - pulse), 0.5, 1.0)
	if is_replica:
		return
	if not _round_running():
		return
	_elapsed += delta
	if not _warn and _elapsed >= release_time - WARN_TIME:
		_warn = true
		SoundManager.play_sound("warning", 0.05, -4.0)
	if _elapsed >= release_time:
		release()

func _round_running() -> bool:
	if Global.current_state != Global.GameState.PLAYING:
		return false
	var scene := get_tree().current_scene
	return scene == null or scene.get("countdown_active") != true

## Projektile und Nahkampf (gleiche Schnittstelle wie zerstörbare Kacheln).
func hit_tile(amount: float = 20.0) -> void:
	if is_replica or _open:
		return
	health -= maxf(1.0, amount)
	play_network_fx("hit")
	NetFx.send("mobj", NetFx.mobj_args(self, "hit"))
	if health <= 0.0:
		release()

# Treffer-Blitz und Ton; auf Clients vom Host ausgelöst.
func play_network_fx(_method: String) -> void:
	if _open:
		return
	var tw := _links.create_tween()
	tw.tween_property(_links, "modulate", Color(1.8, 1.2, 0.7), 0.05)
	tw.tween_property(_links, "modulate", Color.WHITE, 0.12)
	SoundManager.play_sound("hit", 0.18, -6.0)

func apply_blast(blast_position: Vector2, radius: float, _force: float = 520.0, _attacker: Node = null) -> void:
	if is_replica or _open:
		return
	var center := global_position + Vector2(0.0, height_px * 0.5)
	if blast_position.distance_to(center) <= radius:
		hit_tile(35.0)

func release() -> void:
	if _open:
		return
	_open = true
	_warn = false
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	SoundManager.play_sound("bounce", 0.2, -1.0)
	released.emit()
	# Die Glieder fallen auseinander und verblassen.
	var i := 0
	for raw in _links.get_children():
		var link := raw as Node2D
		var side := -1.0 if i % 2 == 0 else 1.0
		var tw := link.create_tween()
		tw.tween_property(link, "position", link.position + Vector2(side * (10.0 + float(i % 3) * 8.0), 60.0 + float(i) * 6.0), 0.55) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(link, "rotation", side * 1.6, 0.55)
		tw.parallel().tween_property(link, "modulate:a", 0.0, 0.55)
		i += 1
	_links.modulate = Color.WHITE

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"type": object_type,
		"pos": global_position,
		"open": _open,
		"warn": _warn,
	}

func apply_network_state(data: Dictionary) -> void:
	if not is_replica:
		return
	if bool(data.get("open", false)):
		release()
		return
	var warn := bool(data.get("warn", false))
	if warn and not _warn:
		SoundManager.play_sound("warning", 0.05, -4.0)
	_warn = warn
	if not _warn:
		_links.modulate = Color.WHITE
