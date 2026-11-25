extends Node

## Leistungstest Horden-Modus auf dem echten Rechner (mit Grafik).
## Zwei Bots, unverwundbar und still, Gegner werden um sie herum aufgefüllt.
## Misst für 0 / 75 / 150 / 230 Gegner je 8 s: FPS, mittlere und schlechteste
## Frame-Zeit, Draw Calls. Ergebnis in der Konsole und in
## user://horde_perf.txt. Aufruf: godot --path . res://tools/horde_perf_test.tscn

const STEPS: Array[int] = [0, 75, 150, 230]
const SETTLE: float = 4.0
const MEASURE: float = 8.0

var main: Node
var _step: int = -1
var _phase_t: float = 0.0
var _measuring: bool = false
var _frame_ms: Array[float] = []
var _draws: Array[float] = []
var _last_us: int = 0
var _out: PackedStringArray = PackedStringArray()

func _ready() -> void:
	Global.set_match_mode(Global.MATCH_MODE_HORDE)
	Global.set_player_count(2)
	Global.set_bot_test_mode(true)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	main._start_fresh_round(4242)
	Global.current_state = Global.GameState.PLAYING
	await get_tree().create_timer(5.0).timeout
	_log("Grafikstufe: %s, Renderer: %s, GPU: %s" % [GameSettings.graphics_preset,
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), RenderingServer.get_video_adapter_name()])
	_log("Fenster: %s, max_fps: %d, vsync: %d" % [str(get_viewport().get_visible_rect().size), Engine.max_fps, DisplayServer.window_get_vsync_mode()])
	_next_step()

func _log(t: String) -> void:
	print("PERF " + t)
	_out.append(t)

func _next_step() -> void:
	_step += 1
	if _step >= STEPS.size():
		var f := FileAccess.open("user://horde_perf.txt", FileAccess.WRITE)
		if f:
			f.store_string("\n".join(_out))
		_log("fertig, Datei: " + ProjectSettings.globalize_path("user://horde_perf.txt"))
		get_tree().quit()
		return
	_phase_t = 0.0
	_measuring = false
	_frame_ms.clear()
	_draws.clear()

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := float(now - _last_us) / 1000.0
	_last_us = now
	if _step < 0 or main == null or main.horde_director == null:
		return
	var d: HordeDirector = main.horde_director
	for p in main.players:
		if is_instance_valid(p):
			p.max_health = 100000.0
			p.current_health = 100000.0
			p.control_enabled = false
	var want: int = STEPS[_step]
	var have := get_tree().get_nodes_in_group(HordeEnemy.GROUP).size()
	var tries := 0
	while have < want and tries < 30:
		tries += 1
		var c: Vector2 = main.players[0].global_position
		var e = d.spawn_enemy(HordeDefs.pick_kind(400.0, d._rng), c + Vector2.from_angle(randf() * TAU) * randf_range(200.0, 900.0))
		if e != null:
			have += 1
	if have > want:
		for node in get_tree().get_nodes_in_group(HordeEnemy.GROUP):
			if have <= want:
				break
			node.is_dead = true
			node.queue_free()
			have -= 1
	_phase_t += delta
	if not _measuring:
		if _phase_t >= SETTLE:
			_measuring = true
			_phase_t = 0.0
		return
	_frame_ms.append(dt)
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _phase_t >= MEASURE:
		var sorted := _frame_ms.duplicate()
		sorted.sort()
		var sum := 0.0
		for v in _frame_ms:
			sum += v
		var avg := sum / maxf(1, _frame_ms.size())
		var p99: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
		var dsum := 0.0
		for v in _draws:
			dsum += v
		_log("Gegner %3d: %5.1f FPS, Frame %5.1f ms (99%%: %5.1f ms, max %5.1f ms), Draw Calls %4.0f, Physik %4.1f ms" % [
			have, 1000.0 / maxf(0.01, avg), avg, p99, sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0,
			dsum / maxf(1, _draws.size()), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
		_next_step()
