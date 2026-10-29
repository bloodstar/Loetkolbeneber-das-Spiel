class_name BallSpawner
extends Node2D

## Lässt in festen Abständen Kugeln an den Startpunkten einer Kugelbahn
## erscheinen (Map Kugelbahn). Nur der Host spawnt; die Kugeln sind normale
## Map-Objekte mit Netzwerk-ID und kommen per Snapshot zu den Clients.
## Alle Startpunkte bekommen gleichzeitig dieselbe Kugel (gespiegelte Bahnen
## bleiben fair).

const MAX_BALLS: int = 44
const BALL_LIFETIME: float = 32.0

var points: Array = []      # Spawnpunkte in Pixeln (Raum des LevelGenerators)
var directions: Array = []  # Anfangsrichtung je Punkt (-1 links, 1 rechts)
var interval: float = 5.0
var first_delay: float = 1.0
var big_chance: float = 0.25
var small_chance: float = 0.3
# Mit jeder Kugel fallen bis zu so viele kleine (0,5 Kacheln) hinterher.
var extra_small: int = 2

var _timer: float = 0.0
var _started: bool = false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_timer = first_delay
	_build_visual()

func _build_visual() -> void:
	# Kleiner Trichter über jedem Startpunkt.
	for raw in points:
		var p: Vector2 = raw
		var funnel := Polygon2D.new()
		funnel.polygon = PackedVector2Array([
			Vector2(-30.0, -76.0), Vector2(30.0, -76.0), Vector2(14.0, -40.0), Vector2(-14.0, -40.0),
		])
		funnel.color = Color(0.2, 0.2, 0.24, 0.85)
		funnel.position = p
		funnel.z_index = 2
		add_child(funnel)
		var rim := Line2D.new()
		rim.points = PackedVector2Array([Vector2(-30.0, -76.0), Vector2(30.0, -76.0)])
		rim.width = 3.0
		rim.default_color = Color(1.0, 0.8, 0.35, 0.9)
		rim.position = p
		rim.z_index = 2
		add_child(rim)

func _physics_process(delta: float) -> void:
	if Global.network_mode and not Global.is_local_host():
		return
	if Global.current_state != Global.GameState.PLAYING:
		return
	var scene := get_tree().current_scene
	if scene != null and scene.get("countdown_active") == true:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval
	var level := get_parent() as LevelGenerator
	if level == null:
		return
	var free_slots := MAX_BALLS - level.get_ball_count()
	if free_slots < points.size():
		return
	var mat := RollingBall.random_material(_rng)
	var size := RollingBall.random_size(_rng, big_chance, small_chance)
	var extras := mini(_rng.randi_range(0, extra_small), int(free_slots / points.size()) - 1)
	var extra_mats: Array[String] = []
	for k in range(extras):
		extra_mats.append(RollingBall.random_material(_rng))
	for i in range(points.size()):
		var dir := float(directions[i]) if i < directions.size() else 0.0
		var p: Vector2 = points[i]
		var ball := level.spawn_ball(p, mat, size, Vector2(dir * 60.0, 40.0))
		ball.lifetime = BALL_LIFETIME
		# Kleine Kugeln direkt davor (in Rollrichtung versetzt, nicht
		# übereinander, damit nichts über den Kartenrand ragt).
		var offset := RollingBall.radius_for(size) + RollingBall.radius_for(0.5) + 2.0
		for k in range(extras):
			var q := p + Vector2(dir if dir != 0.0 else 1.0, 0.0) * offset
			var small := level.spawn_ball(q, extra_mats[k], 0.5, Vector2(dir * 60.0, 40.0))
			small.lifetime = BALL_LIFETIME
			offset += RollingBall.radius_for(0.5) * 2.0 + 2.0
