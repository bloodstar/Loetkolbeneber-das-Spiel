extends Node

# Spieleinstellungen: Fenstermodus, Grafikstufe, Lautstärken und Tastenbelegung.
# Alles landet in user://settings.cfg und wird beim Start angewendet.
# Dieses Autoload steht in project.godot hinter Global und SoundManager,
# damit die Standard-Tastenbelegung und die Audio-Busse schon existieren.
#
# Außerdem übernimmt es beim ersten Start nach der Umbenennung von
# "BattleBalls" in "Lötkolbeneber" die alten Spieldaten (Rundenstatistik,
# Kartenstatistik, Loadouts, Charakter), weil Godot den user://-Ordner nach
# dem Projektnamen benennt. Der alte Ordner bleibt als Sicherung unverändert.

signal settings_changed

const SETTINGS_PATH: String = "user://settings.cfg"
const LEGACY_USER_DIR_NAME: String = "BattleBalls"
const MIGRATION_MARKER: String = "user://.migrated_from_battleballs"

const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "borderless"]
const WINDOW_MODE_LABELS: Dictionary = {
	"windowed": "Fenster",
	"fullscreen": "Vollbild",
	"borderless": "Vollbild-Fenster (randlos)",
}

# --- Grafikstufen ---
# Eine Stufe setzt alle Qualitätswerte auf einmal. Ändert man danach einen
# Einzelwert, steht die Stufe auf "custom" (Eigene). FPS-Limit, VSync und
# FPS-Anzeige gehören nicht zur Stufe und bleiben, wie sie sind.
const GRAPHICS_PRESETS: Array[String] = ["low", "medium", "high", "custom"]
const GRAPHICS_PRESET_LABELS: Dictionary = {
	"low": "Niedrig",
	"medium": "Mittel",
	"high": "Hoch",
	"custom": "Eigene",
}
const GRAPHICS_KEYS: Array[String] = [
	"msaa", "render_scale", "shadows", "contact_shadows", "effects", "glow", "horde_limit",
]
const GRAPHICS_PRESET_VALUES: Dictionary = {
	"low": {
		"msaa": 0, "render_scale": 0.67, "shadows": 0, "contact_shadows": false,
		"effects": 0, "glow": false, "horde_limit": 90,
	},
	"medium": {
		"msaa": 1, "render_scale": 0.85, "shadows": 1, "contact_shadows": true,
		"effects": 1, "glow": true, "horde_limit": 150,
	},
	"high": {
		"msaa": 2, "render_scale": 1.0, "shadows": 2, "contact_shadows": true,
		"effects": 2, "glow": true, "horde_limit": 230,
	},
}
# Kantenglättung: Index -> Viewport.MSAA_*
const MSAA_LABELS: Array[String] = ["Aus", "2x", "4x"]
const MSAA_VALUES: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]
# Render-Auflösung der 3D-Arena (2D-Grafik bleibt immer scharf).
const RENDER_SCALES: Array[float] = [0.5, 0.67, 0.75, 0.85, 1.0]
const SHADOW_LABELS: Array[String] = ["Aus", "Hart", "Weich"]
const EFFECT_LABELS: Array[String] = ["Wenig", "Mittel", "Voll"]
const EFFECT_SCALES: Array[float] = [0.35, 0.65, 1.0]
# Höchstzahl gleichzeitiger Gegner im Horden-Modus (der Modus nimmt das
# Minimum aus diesem Wert und seiner eigenen Obergrenze; online zählt der Host).
const HORDE_LIMITS: Array[int] = [60, 90, 120, 150, 190, 230]
const FPS_LIMITS: Array[int] = [30, 60, 90, 120, 144, 0]

# Lautstärken linear 0..1. "effects" steuert die Busse SFX und UI gemeinsam.
const VOLUME_KEYS: Array[String] = ["master", "effects", "music"]
const DEFAULT_VOLUMES: Dictionary = {"master": 0.8, "effects": 1.0, "music": 0.8}

# Belegbare Aktionen in Anzeige-Reihenfolge. Die Standardwerte setzt
# Global._setup_default_inputs(); hier wird nur überschrieben.
const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"group": "Spieler"},
	{"action": "p1_left", "label": "Links"},
	{"action": "p1_right", "label": "Rechts"},
	{"action": "p1_up", "label": "Hoch / Zielen"},
	{"action": "p1_down", "label": "Runter / Durchfallen"},
	{"action": "p1_jump", "label": "Springen"},
	{"action": "p1_shoot", "label": "Schießen"},
	{"action": "p1_dash", "label": "Dash"},
	{"action": "p1_block", "label": "Barriere"},
	{"action": "p1_reload", "label": "Nachladen"},
	{"action": "p1_melee", "label": "Nahkampf"},
	{"action": "p1_ability", "label": "Fähigkeit"},
	{"group": "Allgemein"},
	{"action": "restart_game", "label": "Neustart (nur lokal)"},
]

var window_mode: String = "windowed"
var graphics_preset: String = "high"
var graphics: Dictionary = (GRAPHICS_PRESET_VALUES["high"] as Dictionary).duplicate()
var max_fps: int = 0
var vsync: bool = true
var show_fps: bool = false
var _fps_layer: CanvasLayer = null
var _fps_label: Label = null
var volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
# Effekt-Set, siehe SoundManager.SOUND_PACKS. Gilt nur auf diesem Rechner.
var sound_pack: String = "arena"
# action -> serialisiertes Event (siehe _event_to_dict)
var bindings: Dictionary = {}
# Solange das Optionsmenü in einer Runde offen ist, ignorieren lokale
# Spieler ihre Eingaben (online läuft die Runde dabei weiter).
var gameplay_input_blocked: bool = false

var _default_events: Dictionary = {}

func _init() -> void:
	# Läuft vor dem _ready() aller Autoloads, also bevor Global, CardStats
	# und RoundStats ihre Dateien lesen.
	_migrate_legacy_user_data()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_bindings()
	load_settings()
	apply_all()

# --- Laden / Speichern ---

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_pick_default_preset()
		return
	var mode := str(cfg.get_value("display", "window_mode", window_mode))
	if WINDOW_MODES.has(mode):
		window_mode = mode
	_load_graphics(cfg)
	for key in VOLUME_KEYS:
		volumes[key] = clampf(float(cfg.get_value("audio", key, DEFAULT_VOLUMES[key])), 0.0, 1.0)
	# Neuer Schlüssel, damit alle einmal auf das neue Standard-Set "Arena" wechseln.
	var pack := str(cfg.get_value("audio", "sound_set", sound_pack))
	if SoundManager.has_sound_pack(pack):
		sound_pack = pack
	bindings.clear()
	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			var data = cfg.get_value("controls", action)
			if data is Dictionary and _default_events.has(action):
				bindings[action] = data

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("graphics", "preset", graphics_preset)
	for key in GRAPHICS_KEYS:
		cfg.set_value("graphics", key, graphics[key])
	cfg.set_value("graphics", "max_fps", max_fps)
	cfg.set_value("graphics", "vsync", vsync)
	cfg.set_value("graphics", "show_fps", show_fps)
	for key in VOLUME_KEYS:
		cfg.set_value("audio", key, volumes[key])
	cfg.set_value("audio", "sound_set", sound_pack)
	for action in bindings.keys():
		cfg.set_value("controls", action, bindings[action])
	var err := cfg.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Einstellungen konnten nicht gespeichert werden (%s)." % error_string(err))

func apply_all() -> void:
	apply_window_mode()
	apply_graphics()
	apply_volumes()
	SoundManager.set_sound_pack(sound_pack)
	_apply_bindings()

# --- Grafik ---

func set_window_mode(mode: String) -> void:
	if not WINDOW_MODES.has(mode):
		return
	window_mode = mode
	apply_window_mode()
	save_settings()
	settings_changed.emit()

func apply_window_mode() -> void:
	# Im Editor eingebettete Spielfenster lassen sich nicht umschalten.
	if DisplayServer.get_name() == "headless":
		return
	match window_mode:
		"fullscreen":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"borderless":
			# In Godot 4 ist WINDOW_MODE_FULLSCREEN ein randloses Vollbild-Fenster.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_:
			var was_fullscreen := DisplayServer.window_get_mode() in [
				DisplayServer.WINDOW_MODE_FULLSCREEN,
				DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
			]
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			if was_fullscreen:
				_center_window()

# --- Grafikstufen ---

func _load_graphics(cfg: ConfigFile) -> void:
	if not cfg.has_section_key("graphics", "preset"):
		_pick_default_preset()
		return
	var preset := str(cfg.get_value("graphics", "preset", graphics_preset))
	if not GRAPHICS_PRESETS.has(preset):
		preset = "high"
	graphics_preset = preset
	var base: Dictionary = GRAPHICS_PRESET_VALUES.get(preset, GRAPHICS_PRESET_VALUES["high"])
	for key in GRAPHICS_KEYS:
		graphics[key] = _sanitize_graphics_value(key, cfg.get_value("graphics", key, base[key]))
	var fps := int(cfg.get_value("graphics", "max_fps", max_fps))
	max_fps = fps if FPS_LIMITS.has(fps) else 0
	vsync = bool(cfg.get_value("graphics", "vsync", vsync))
	show_fps = bool(cfg.get_value("graphics", "show_fps", show_fps))

## Erster Start: Auf Grafik im Prozessor (z. B. Intel Iris Xe) mit "Mittel"
## beginnen, auf einer eigenen Grafikkarte mit "Hoch".
func _pick_default_preset() -> void:
	var preset := "high"
	if DisplayServer.get_name() != "headless":
		var adapter_type := RenderingServer.get_video_adapter_type()
		var adapter_name := RenderingServer.get_video_adapter_name().to_lower()
		if adapter_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU \
				or adapter_type == RenderingDevice.DEVICE_TYPE_CPU \
				or adapter_name.contains("intel") or adapter_name.contains("uhd") \
				or adapter_name.contains("llvmpipe"):
			preset = "medium"
	graphics_preset = preset
	graphics = (GRAPHICS_PRESET_VALUES[preset] as Dictionary).duplicate()

func _sanitize_graphics_value(key: String, value: Variant) -> Variant:
	match key:
		"msaa":
			return clampi(int(value), 0, MSAA_VALUES.size() - 1)
		"render_scale":
			var wanted := float(value)
			var best: float = RENDER_SCALES[RENDER_SCALES.size() - 1]
			for option in RENDER_SCALES:
				if absf(option - wanted) < absf(best - wanted):
					best = option
			return best
		"shadows":
			return clampi(int(value), 0, SHADOW_LABELS.size() - 1)
		"effects":
			return clampi(int(value), 0, EFFECT_SCALES.size() - 1)
		"contact_shadows", "glow":
			return bool(value)
		"horde_limit":
			var n := int(value)
			return n if HORDE_LIMITS.has(n) else HORDE_LIMITS[HORDE_LIMITS.size() - 1]
	return value

func set_graphics_preset(preset: String) -> void:
	if not GRAPHICS_PRESETS.has(preset):
		return
	graphics_preset = preset
	if GRAPHICS_PRESET_VALUES.has(preset):
		graphics = (GRAPHICS_PRESET_VALUES[preset] as Dictionary).duplicate()
	apply_graphics()
	save_settings()
	settings_changed.emit()

## Einzelwert ändern. Passt das Ergebnis genau zu einer Stufe, wird sie
## wieder angezeigt, sonst steht die Stufe auf "Eigene".
func set_graphics_value(key: String, value: Variant) -> void:
	if not GRAPHICS_KEYS.has(key):
		return
	graphics[key] = _sanitize_graphics_value(key, value)
	graphics_preset = _matching_preset()
	apply_graphics()
	save_settings()
	settings_changed.emit()

func _matching_preset() -> String:
	for preset in ["low", "medium", "high"]:
		if GRAPHICS_PRESET_VALUES[preset] == graphics:
			return preset
	return "custom"

func get_graphics_value(key: String) -> Variant:
	return graphics.get(key, GRAPHICS_PRESET_VALUES["high"][key])

func set_max_fps(fps: int) -> void:
	max_fps = fps if FPS_LIMITS.has(fps) else 0
	apply_graphics()
	save_settings()
	settings_changed.emit()

func set_vsync(enabled: bool) -> void:
	vsync = enabled
	apply_graphics()
	save_settings()
	settings_changed.emit()

func set_show_fps(enabled: bool) -> void:
	show_fps = enabled
	_update_fps_counter()
	save_settings()
	settings_changed.emit()

## Faktor 0..1 für die Menge an Funken, Splittern, Blut und Staub.
func effects_scale() -> float:
	return EFFECT_SCALES[clampi(int(get_graphics_value("effects")), 0, EFFECT_SCALES.size() - 1)]

## Anzahl für Partikel-Schleifen: nie unter `minimum`.
func scaled_count(full_count: int, minimum: int = 1) -> int:
	return maxi(minimum, int(round(float(full_count) * effects_scale())))

func glow_enabled() -> bool:
	return bool(get_graphics_value("glow"))

## 0 = aus, 1 = hart, 2 = weich (Sonnenschatten in der Arena).
func shadow_quality() -> int:
	return int(get_graphics_value("shadows"))

func contact_shadows_enabled() -> bool:
	return bool(get_graphics_value("contact_shadows"))

## Für den Horden-Modus: höchstens so viele Gegner gleichzeitig.
func horde_enemy_limit() -> int:
	return int(get_graphics_value("horde_limit"))

func apply_graphics() -> void:
	Engine.max_fps = max_fps
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var root := get_tree().root if is_inside_tree() else null
	if root != null:
		var msaa: int = MSAA_VALUES[clampi(int(get_graphics_value("msaa")), 0, MSAA_VALUES.size() - 1)]
		# Der Kompatibilitäts-Renderer (OpenGL) kann kein 2D-MSAA.
		if RenderingServer.get_current_rendering_method() != "gl_compatibility":
			root.msaa_2d = msaa as Viewport.MSAA
		root.msaa_3d = msaa as Viewport.MSAA
		var scale := float(get_graphics_value("render_scale"))
		root.scaling_3d_scale = scale
		# FSR 1 schärft beim Hochskalieren nach; bei 100 % reicht bilinear.
		root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
		root.fsr_sharpness = 0.3
	var shadows := shadow_quality()
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows >= 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if shadows >= 2 else RenderingServer.SHADOW_QUALITY_HARD)
	_update_fps_counter()

func _update_fps_counter() -> void:
	if not show_fps:
		if _fps_layer != null:
			_fps_layer.visible = false
		return
	if _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 127
		_fps_layer.name = "FpsCounter"
		_fps_label = Label.new()
		_fps_label.position = Vector2(8, 4)
		_fps_label.add_theme_font_size_override("font_size", 18)
		_fps_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
		_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_layer.add_child(_fps_label)
		add_child(_fps_layer)
	_fps_layer.visible = true

func _process(_delta: float) -> void:
	if show_fps and _fps_label != null:
		_fps_label.text = "%d FPS" % int(Engine.get_frames_per_second())

func _center_window() -> void:
	var screen := DisplayServer.window_get_current_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	var size := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 1600)),
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 900))
	)
	size.x = mini(size.x, screen_rect.size.x)
	size.y = mini(size.y, screen_rect.size.y)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen_rect.position + (screen_rect.size - size) / 2)

# --- Audio ---

func get_volume(key: String) -> float:
	return float(volumes.get(key, 1.0))

func set_volume(key: String, linear: float, save: bool = true) -> void:
	if not VOLUME_KEYS.has(key):
		return
	volumes[key] = clampf(linear, 0.0, 1.0)
	apply_volumes()
	if save:
		save_settings()
	settings_changed.emit()

func set_sound_pack(pack_id: String) -> void:
	if not SoundManager.has_sound_pack(pack_id):
		return
	sound_pack = pack_id
	SoundManager.set_sound_pack(pack_id)
	save_settings()
	settings_changed.emit()

func apply_volumes() -> void:
	SoundManager.set_bus_volume("Master", maxf(0.0001, get_volume("master")))
	SoundManager.set_bus_volume(SoundManager.BUS_SFX, maxf(0.0001, get_volume("effects")))
	SoundManager.set_bus_volume(SoundManager.BUS_UI, maxf(0.0001, get_volume("effects")))
	SoundManager.set_bus_volume(SoundManager.BUS_MUSIC, maxf(0.0001, get_volume("music")))
	# Bei 0 % den Bus ganz stummschalten, linear_to_db(0) ist -inf.
	for bus_name in ["Master", SoundManager.BUS_SFX, SoundManager.BUS_UI, SoundManager.BUS_MUSIC]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		var key := "master"
		if bus_name == SoundManager.BUS_MUSIC:
			key = "music"
		elif bus_name != "Master":
			key = "effects"
		AudioServer.set_bus_mute(idx, get_volume(key) <= 0.001)

# --- Tastenbelegung ---

func get_binding_text(action: String) -> String:
	if not InputMap.has_action(action):
		return "—"
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	return event_to_text(events[0])

func event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		var label := DisplayServer.keyboard_get_label_from_physical(code) if key_event.physical_keycode != KEY_NONE else code
		var text := OS.get_keycode_string(label)
		if text.is_empty():
			text = OS.get_keycode_string(code)
		return _translate_key_name(text)
	if event is InputEventMouseButton:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "Linksklick"
			MOUSE_BUTTON_RIGHT:
				return "Rechtsklick"
			MOUSE_BUTTON_MIDDLE:
				return "Mausrad-Klick"
			MOUSE_BUTTON_XBUTTON1:
				return "Maustaste 4"
			MOUSE_BUTTON_XBUTTON2:
				return "Maustaste 5"
			_:
				return "Maustaste %d" % int((event as InputEventMouseButton).button_index)
	return event.as_text()

func _translate_key_name(text: String) -> String:
	const NAMES := {
		"Space": "Leertaste", "Shift": "Umschalt", "Ctrl": "Strg", "Escape": "Esc",
		"Enter": "Enter", "Left": "Pfeil links", "Right": "Pfeil rechts",
		"Up": "Pfeil hoch", "Down": "Pfeil runter", "Period": ".", "Comma": ",",
		"Slash": "/", "Minus": "-", "Tab": "Tab", "Backspace": "Rücktaste",
	}
	return str(NAMES.get(text, text))

# Belegt eine Aktion neu. Erlaubt sind Tastatur- und Maustasten; die Taste
# ersetzt alle bisherigen Belegungen dieser Aktion.
func set_binding(action: String, event: InputEvent) -> bool:
	if not _default_events.has(action):
		return false
	var data := _event_to_dict(event)
	if data.is_empty():
		return false
	bindings[action] = data
	_apply_binding(action, data)
	save_settings()
	settings_changed.emit()
	return true

func reset_bindings() -> void:
	bindings.clear()
	for action in _default_events.keys():
		_restore_default(action)
	save_settings()
	settings_changed.emit()

# Liefert die übrigen belegbaren Aktionen, die schon auf derselben Taste liegen.
func find_conflicts(action: String, event: InputEvent) -> Array[String]:
	var result: Array[String] = []
	var data := _event_to_dict(event)
	if data.is_empty():
		return result
	for other in _default_events.keys():
		if other == action or not InputMap.has_action(other):
			continue
		for ev in InputMap.action_get_events(other):
			if _event_to_dict(ev) == data:
				result.append(other)
				break
	return result

func get_action_label(action: String) -> String:
	for entry in REBINDABLE_ACTIONS:
		if str(entry.get("action", "")) == action:
			return str(entry["label"])
	return action

func _capture_default_bindings() -> void:
	_default_events.clear()
	for entry in REBINDABLE_ACTIONS:
		var action := str(entry.get("action", ""))
		if action.is_empty() or not InputMap.has_action(action):
			continue
		var copies: Array[InputEvent] = []
		for ev in InputMap.action_get_events(action):
			copies.append(ev.duplicate())
		_default_events[action] = copies

func _apply_bindings() -> void:
	for action in bindings.keys():
		_apply_binding(action, bindings[action])

func _apply_binding(action: String, data: Dictionary) -> void:
	var event := _dict_to_event(data)
	if event == null or not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

func _restore_default(action: String) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	for ev in _default_events.get(action, []):
		InputMap.action_add_event(action, ev.duplicate())

func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		if code == KEY_NONE:
			return {}
		return {"type": "key", "code": int(code)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": int((event as InputEventMouseButton).button_index)}
	return {}

func _dict_to_event(data: Dictionary) -> InputEvent:
	match str(data.get("type", "")):
		"key":
			var key_event := InputEventKey.new()
			key_event.physical_keycode = int(data.get("code", 0)) as Key
			return key_event
		"mouse":
			var mouse_event := InputEventMouseButton.new()
			mouse_event.button_index = int(data.get("button", 1)) as MouseButton
			return mouse_event
	return null

# --- Datenübernahme nach der Umbenennung ---

func _migrate_legacy_user_data() -> void:
	var new_dir := OS.get_user_data_dir()
	var old_dir := new_dir.get_base_dir().path_join(LEGACY_USER_DIR_NAME)
	if new_dir.get_file() == LEGACY_USER_DIR_NAME or not DirAccess.dir_exists_absolute(old_dir):
		return
	DirAccess.make_dir_recursive_absolute(new_dir)
	if FileAccess.file_exists(MIGRATION_MARKER):
		return
	var dir := DirAccess.open(old_dir)
	if dir == null:
		return
	var copied := 0
	for file_name in dir.get_files():
		var target := new_dir.path_join(file_name)
		if FileAccess.file_exists(target):
			continue
		if DirAccess.copy_absolute(old_dir.path_join(file_name), target) == OK:
			copied += 1
	var marker := FileAccess.open(MIGRATION_MARKER, FileAccess.WRITE)
	if marker != null:
		marker.store_line("Daten aus %s übernommen (%d Dateien)." % [old_dir, copied])
		marker.close()
	print("GameSettings: %d Dateien aus %s übernommen." % [copied, old_dir])
