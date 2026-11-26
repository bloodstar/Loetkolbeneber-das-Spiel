extends Node

## Laufzeit-Test der Challenge-Runden mit Bots (ChallengeDirector).
## Aufruf: godot --headless res://tools/challenge_runtime_test.tscn [-- race hill ...]
## Jede Challenge läuft mit 4 Bots im Zeitraffer, bis sie entschieden ist oder
## das Zeitlimit abläuft. Geprüft: Aufbau (Tore, Ecken, Zone, Flagge, Münzen),
## Wertung, Wiedereinstieg und dass am Ende ein Sieger feststeht.

const SPEED: float = 4.0
var failures: Array[String] = []
var main: Node

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   " + msg)
	else:
		print("  FAIL " + msg)
		failures.append(msg)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _ready() -> void:
	var ids: Array = ChallengeDefs.ORDER.duplicate()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		ids = args
	Global.set_player_count(4)
	for i in range(1, 5):
		Global.set_player_kind(i, Global.PlayerKind.BOT)
	main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	add_child(main)
	await _wait(0.3)
	var seed := 777
	for id in ids:
		seed += 101
		await _run(str(id), seed)
	print("")
	if failures.is_empty():
		print("ALLE CHALLENGE-TESTS GRÜN")
	else:
		print("%d FEHLER:" % failures.size())
		for f in failures:
			print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)

func _run(id: String, seed: int) -> void:
	print("== %s ==" % id)
	Global.reset_match()
	main._start_fresh_round(seed, "", id)
	await get_tree().physics_frame
	var d: ChallengeDirector = main.challenge_director
	_check(d != null and d.kind == id, "Director läuft (Karte %s)" % main.match_map_id)
	if d == null:
		return
	match id:
		"race":
			_check(d.checkpoints.size() == 4, "4 Tore")
		"ballpit":
			_check(d.pens.size() == 6 and d.pen_of.size() == 4, "6 Ecken, 4 vergeben")
		"hill":
			_check(d.zone_center != Vector2.INF, "Zone gesetzt bei %s" % str(d.zone_center))
		"lava":
			_check(d.flag_pos != Vector2.INF, "Flagge gesetzt bei %s" % str(d.flag_pos))
	# Countdown überspringen.
	main.countdown_remaining = 0.01
	await _wait(0.2)
	_check(d.running, "gestartet nach dem Countdown")
	_check(main.sudden_death_timer.is_stopped(), "kein Sudden Death")
	if id == "coins":
		_check(d.coins.size() >= 5, "Münzen liegen (%d)" % d.coins.size())
	if id == "ballpit":
		_check(get_tree().get_nodes_in_group("challenge_ball").size() >= 20, "Bälle gespawnt")
	# Zeitraffer bis zum Ende.
	Engine.time_scale = SPEED
	Engine.physics_ticks_per_second = int(60 * SPEED)
	Engine.max_physics_steps_per_frame = 40
	# Abbruch nach reichlich Echtzeit, falls die Physik nicht mitkommt.
	var limit := float(d.def.get("time", 60.0)) / SPEED * 4.0 + 10.0
	var real := 0.0
	var killed_once := false
	while is_instance_valid(d) and not d.finished and real < limit:
		await _wait(0.5)
		real += 0.5
		var t := float(d.def.get("time", 60.0)) - d.time_left
		# Einmal einen Spieler sterben lassen: Wiedereinstieg prüfen.
		if not killed_once and t > 8.0 and ChallengeDefs.respawn_delay(id) >= 0.0:
			var victim: Player = main.get_player(2)
			if victim != null and is_instance_valid(victim) and not victim.is_dead:
				killed_once = true
				victim.take_damage(99999.0, Vector2.ZERO)
				await _wait(0.05)
				_check(Global.current_state == Global.GameState.PLAYING, "Runde läuft nach Tod weiter")
				await _wait(3.0 / SPEED + 0.2)
				var back: Player = main.get_player(2)
				_check(back != null and is_instance_valid(back) and not back.is_dead and back.current_health > 0.0, "Spieler 2 ist wieder da")
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	var vals := []
	if is_instance_valid(d):
		for team in d.scores.keys():
			vals.append("%s=%s" % [d.team_label(int(team)), d.value_text(int(team))])
		print("  Wertung: " + ", ".join(vals))
		print("  Spielzeit %.0f s, entschieden: %s, Sieger: %d" % [float(d.def.get("time", 60.0)) - d.time_left, str(d.finished), d.winner_slot])
	var decided: bool = (is_instance_valid(d) and d.finished) or Global.current_state != Global.GameState.PLAYING
	_check(decided, "Challenge entschieden")
	_check(Global.current_state != Global.GameState.PLAYING, "Runde beendet (Draft/Matchende)")
	main.card_draft_ui.close_draft()
	get_tree().paused = false
	Global.current_state = Global.GameState.PLAYING
