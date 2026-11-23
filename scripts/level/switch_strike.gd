class_name SwitchStrike
extends Node2D

## Map-Effekt auf Knopfdruck: Beim Einschalten des Kanals feuert ein
## Orbitallaser entlang der Linie point_a -> point_b (derselbe Strahl wie beim
## Modifier, 1,8 s Warnung, dann Schaden). Am Boden markieren zwei Peilmarken
## in Kanalfarbe die Bahn, damit man weiß, wohin der Knopf zielt.
## Nur der Host feuert; Clients sehen den Strahl über NetFx "laser".

var network = null
var is_replica: bool = false
var point_a: Vector2 = Vector2.ZERO
var point_b: Vector2 = Vector2(0.0, 400.0)
var channels: Array = [0]
var powered: bool = false
var damage: float = 45.0
var _color: Color = Color.WHITE

func _ready() -> void:
	add_to_group("switch_strike")
	z_index = 2
	_color = SwitchNetwork.channel_color(int(channels[0]) if not channels.is_empty() else 0)

func set_powered(on: bool) -> void:
	var rising := on and not powered
	powered = on
	if not rising or is_replica:
		return
	var main := get_tree().current_scene
	if main == null:
		return
	var players: Array[Player] = []
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player:
			players.append(p)
	var laser := OrbitalLaser.new()
	laser.damage = damage
	laser.setup(point_a, point_b, players)
	laser.add_to_group("round_effect")
	main.add_child(laser)
	NetFx.send("laser", {"a": point_a, "b": point_b})

func _draw() -> void:
	var dir := (point_b - point_a).normalized()
	var side := dir.orthogonal()
	for end in [point_a, point_b]:
		var c := Color(_color.r, _color.g, _color.b, 0.55)
		draw_line(end - side * 10.0, end + side * 10.0, c, 3.0)
		draw_circle(end, 3.0, c)
	# Gepunktete Peillinie, sehr dezent.
	var length := point_a.distance_to(point_b)
	var d := 0.0
	while d < length:
		draw_line(point_a + dir * d, point_a + dir * minf(d + 6.0, length), Color(_color.r, _color.g, _color.b, 0.12), 2.0)
		d += 22.0

func distance_to(pos: Vector2) -> float:
	return pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, point_a, point_b))

func bot_value(bot: Node2D, enemy: Node2D) -> float:
	var value := 0.0
	if distance_to(enemy.global_position) < 70.0:
		value += 2.5
	if distance_to(bot.global_position) < 90.0:
		value -= 3.0
	return value
