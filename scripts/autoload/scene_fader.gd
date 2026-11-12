extends CanvasLayer
# Weiche Überblendungen zwischen den Spielphasen (Menü, Lobby, Draft, Runde,
# Siegerbildschirm). Das Spiel läuft komplett in einer Szene, deshalb wird
# nichts verzögert: Beim Phasenwechsel wird das letzte Bild eingefroren und
# über die neue Phase ausgeblendet. Spiel-Logik und Netzwerk-Timing bleiben
# dadurch unverändert.
#
# Auslöser: Global.state_changed (Setter von Global.current_state).
# Manuell: SceneFader.crossfade() oder SceneFader.fade_from_black().

const CROSSFADE_TIME := 0.35
const BLACK_FADE_TIME := 0.5
# Beim Rundenstart kurz über Schwarz: das neue Level taucht aus dem Dunkeln auf.
const ROUND_START_DIP := 0.18

var _snapshot: TextureRect
var _black: ColorRect
var _tween: Tween
# Zählt Überblendungen hoch, damit ein älterer, noch wartender Start verfällt.
var _token: int = 0

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

	_snapshot = TextureRect.new()
	_snapshot.name = "Snapshot"
	_snapshot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	_snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_snapshot.visible = false
	add_child(_snapshot)

	_black = ColorRect.new()
	_black.name = "Black"
	_black.color = Color(0.0, 0.0, 0.0, 1.0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)

	Global.state_changed.connect(_on_state_changed)
	# Spielstart: aus Schwarz einblenden.
	fade_from_black()

func _enabled() -> bool:
	# Bot-Test mit hoher Spielgeschwindigkeit: keine Überblendungen.
	if Global.has_method("is_bot_test_active") and Global.is_bot_test_active():
		return false
	return true

func _on_state_changed(_old_state: int, new_state: int) -> void:
	if not _enabled():
		_reset()
		return
	if new_state == Global.GameState.PLAYING:
		crossfade(ROUND_START_DIP)
	else:
		crossfade()

# Friert das aktuelle Bild ein und blendet es aus. dip > 0 legt zusätzlich
# einen kurzen schwarzen Schleier dazwischen.
func crossfade(dip: float = 0.0) -> void:
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		fade_from_black()
		return
	_kill_tween()
	_snapshot.texture = ImageTexture.create_from_image(image)
	_snapshot.modulate.a = 1.0
	_snapshot.visible = true
	_black.visible = dip > 0.0
	_black.modulate.a = 0.0
	if not await _settle():
		return
	_tween = _new_tween()
	if dip > 0.0:
		_tween.tween_property(_black, "modulate:a", 1.0, dip * 0.5)
		_tween.tween_callback(func(): _snapshot.visible = false)
		_tween.tween_property(_black, "modulate:a", 0.0, CROSSFADE_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_snapshot, "modulate:a", 0.0, CROSSFADE_TIME) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_reset)

func fade_from_black(duration: float = BLACK_FADE_TIME) -> void:
	_kill_tween()
	_snapshot.visible = false
	_black.visible = true
	_black.modulate.a = 1.0
	if not await _settle():
		return
	_tween = _new_tween()
	_tween.tween_property(_black, "modulate:a", 0.0, duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_reset)

# Nach einem Phasenwechsel baut das Spiel oft Level oder Lobby auf, der
# nächste Frame dauert dann lange. Die Blende startet erst danach, sonst wäre
# sie in diesem einen langen Frame schon vorbei. false = inzwischen überholt.
func _settle() -> bool:
	_token += 1
	var my_token := _token
	for i in range(2):
		await get_tree().process_frame
	return my_token == _token

func _new_tween() -> Tween:
	# Unabhängig von Pause und Kill-Cam-Zeitlupe.
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.set_ignore_time_scale(true)
	return t

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func _reset() -> void:
	_token += 1
	_kill_tween()
	_snapshot.visible = false
	_snapshot.texture = null
	_black.visible = false
