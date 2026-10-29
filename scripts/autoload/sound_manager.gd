extends Node

# Zentrales Sound-System.
# Alle Effekte stammen aus CC0-Paketen (Kenney, OpenGameArt) und wurden
# einheitlich nachbearbeitet (siehe assets/audio/CREDITS.md). Pro Schlüssel sind mehrere
# Varianten möglich; es wird zufällig gewählt, ohne dieselbe Datei zweimal
# hintereinander zu spielen. Die Grundlautstärke steht hier in der Tabelle,
# das volume_db der Aufrufer wirkt nur noch als Offset.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE: int = 24
const BUS_SFX := "SFX"
const BUS_UI := "UI"
const BUS_MUSIC := "Music"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_FADE_SECONDS: float = 1.6
const PACK_DIR := "res://assets/audio/packs/"

# Austauschbare Effekt-Sets zum Vergleichen (Optionen -> Audio -> Soundpaket).
# "retro" ist das bisherige Set in SFX_DIR. Jedes Paket liefert dieselben
# Dateinamen wie SOUND_TABLE; fehlt eine Datei, wird die Retro-Datei genommen.
# Gebaut mit tools/build_sound_packs.py, Quellen in assets/audio/CREDITS.md.
const DEFAULT_SOUND_PACK := "arena"
const RETRO_PACK := "retro"
const SOUND_PACKS: Array[Dictionary] = [
	{"id": "retro", "label": "Retro (bisher)", "dir": SFX_DIR},
	{"id": "foley", "label": "Handgemacht (Foley)", "dir": PACK_DIR + "foley/"},
	{"id": "scifi", "label": "Modernes Sci-Fi", "dir": PACK_DIR + "scifi/"},
	{"id": "natur", "label": "Kräftig & echt", "dir": PACK_DIR + "natur/"},
	{"id": "magie", "label": "Magie & Zauber", "dir": PACK_DIR + "magie/"},
	{"id": "werkstatt", "label": "Werkstatt & Metall", "dir": PACK_DIR + "werkstatt/"},
	# Standard-Set, im Soundboard von Jochen zusammengestellt: Basis "Arena mit
	# Ansager", einzelne Tasten mit Sounds aus anderen Paketen ("swap").
	{"id": "arena", "label": "Arena", "dir": PACK_DIR + "arena/", "swap": {
		"bounce": {"pack": "arena", "src": "hit"},
		"explosion_big": {"pack": "arena", "src": "hit"},
		"slash": {"pack": "werkstatt", "src": "slash"},
		"fuse": {"pack": "scifi", "src": "fuse"},
		"heal": {"pack": "magie", "src": "heal"},
		"death": {"pack": "magie", "src": "death"},
		"mystery": {"pack": "foley", "src": "mystery"},
		"countdown_go": {"pack": "magie", "src": "countdown_go"},
		"round_end": {"pack": "magie", "src": "round_end"},
		"draft_start": {"pack": "foley", "src": "draft_start"},
		"card_pick": {"pack": "foley", "src": "card_pick"},
		"confirm": {"pack": "foley", "src": "confirm"},
	}},
	{"id": "weich", "label": "Weich & verspielt", "dir": PACK_DIR + "weich/"},
]
# Eigene Mischung aus dem Soundboard: mix.json ordnet jedem Sound-Schlüssel
# Paket und Quell-Taste zu ({"shoot": {"pack": "foley", "src": "shoot"}}). Nur sichtbar, wenn die Datei existiert.
const MIX_ID := "mix"
const MIX_FILE := PACK_DIR + "mix.json"

# Hintergrundmusik je Tileset-Thema (siehe LevelGenerator.TILESET_THEMES).
# Bewusst leise: die Musik soll nur Stimmung geben und Effekte nicht überdecken.
const MUSIC_TABLE: Dictionary = {
	"storybook": {"file": "music_storybook.ogg", "vol": -12.0},
	"frost": {"file": "music_frost.ogg", "vol": -11.0},
	"neon": {"file": "music_neon.ogg", "vol": -12.0},
	"wool": {"file": "music_wool.ogg", "vol": -12.0},
	"platine": {"file": "music_platine.ogg", "vol": -13.0},
}

# files: Varianten | vol: Grundlautstärke in dB | bus | max: gleichzeitige Stimmen
# gap: Mindestabstand in Sekunden zwischen zwei Starts desselben Schlüssels
const SOUND_TABLE: Dictionary = {
	# Kampf
	"shoot": {"files": ["shoot_1", "shoot_2", "shoot_3"], "vol": -7.0, "max": 4, "gap": 0.03},
	"hit": {"files": ["hit_1", "hit_2", "hit_3", "hit_4"], "vol": -6.0, "max": 4, "gap": 0.03},
	"bounce": {"files": ["bounce_1", "bounce_2"], "vol": -8.0, "max": 3, "gap": 0.04},
	"explosion": {"files": ["explosion"], "vol": -4.0, "max": 3, "gap": 0.05},
	"explosion_big": {"files": ["explosion_big"], "vol": -2.0, "max": 2, "gap": 0.1},
	"shield": {"files": ["shield"], "vol": -6.0, "max": 2, "gap": 0.05},
	"poison": {"files": ["poison"], "vol": -6.0, "max": 2, "gap": 0.08},
	"death": {"files": ["death"], "vol": -3.0, "max": 2, "gap": 0.05},
	# Bewegung & Fähigkeiten
	"jump": {"files": ["jump_1", "jump_2"], "vol": -10.0, "max": 3, "gap": 0.04},
	"jump_air": {"files": ["jump_air"], "vol": -10.0, "max": 3, "gap": 0.04},
	"spring": {"files": ["spring"], "vol": -6.0, "max": 2, "gap": 0.05},
	"dash": {"files": ["dash"], "vol": -8.0, "max": 3, "gap": 0.05},
	"slash": {"files": ["slash"], "vol": -6.0, "max": 2, "gap": 0.05},
	"teleport": {"files": ["teleport"], "vol": -6.0, "max": 2, "gap": 0.05},
	"heal": {"files": ["heal"], "vol": -7.0, "max": 2, "gap": 0.1},
	"reload": {"files": ["reload"], "vol": -12.0, "max": 2, "gap": 0.05, "bus": BUS_UI},
	"reload_done": {"files": ["reload_done"], "vol": -10.0, "max": 2, "gap": 0.05, "bus": BUS_UI},
	# Level-Objekte & Ereignisse
	"coin": {"files": ["coin_1", "coin_2"], "vol": -6.0, "max": 3, "gap": 0.04},
	"mystery": {"files": ["mystery"], "vol": -5.0, "max": 1, "gap": 0.2},
	"warning": {"files": ["warning"], "vol": -7.0, "max": 2, "gap": 0.15},
	"fuse": {"files": ["fuse"], "vol": -8.0, "max": 2, "gap": 0.08},
	"laser_small": {"files": ["laser_charge"], "vol": -6.0, "max": 2, "gap": 0.1},
	"laser_large": {"files": ["laser_blast"], "vol": -3.0, "max": 2, "gap": 0.1},
	"sudden_death": {"files": ["sudden_death"], "vol": -4.0, "max": 1, "gap": 1.0},
	# Rundenablauf & Menüs
	"countdown": {"files": ["countdown"], "vol": -4.0, "max": 1, "gap": 0.2, "bus": BUS_UI},
	"countdown_go": {"files": ["countdown_go"], "vol": -3.0, "max": 1, "gap": 0.2, "bus": BUS_UI},
	"round_end": {"files": ["round_end"], "vol": -4.0, "max": 1, "gap": 0.5, "bus": BUS_UI},
	"draft_start": {"files": ["draft_start"], "vol": -5.0, "max": 1, "gap": 0.3, "bus": BUS_UI},
	"card_pick": {"files": ["card_pick"], "vol": -5.0, "max": 1, "gap": 0.1, "bus": BUS_UI},
	"match_win": {"files": ["match_win"], "vol": -3.0, "max": 1, "gap": 1.0, "bus": BUS_UI},
	"click": {"files": ["ui_click"], "vol": -6.0, "max": 3, "gap": 0.02, "bus": BUS_UI},
	"confirm": {"files": ["ui_confirm"], "vol": -6.0, "max": 2, "gap": 0.05, "bus": BUS_UI},
}

# Ältere Schlüssel, die noch im Code vorkommen können.
const ALIASES: Dictionary = {
	"shoot_alt": "shoot",
	"shoot_heavy": "shoot",
	"shoot_retro": "shoot",
}

var sounds: Dictionary = {}           # key -> Array[AudioStream]
var sound_pack: String = DEFAULT_SOUND_PACK
var _mix: Dictionary = {}             # key -> {pack, src}, nur für MIX_ID
var audio_players: Array[AudioStreamPlayer] = []
var _player_key: Dictionary = {}      # AudioStreamPlayer -> key
var _player_started: Dictionary = {}  # AudioStreamPlayer -> Startzeit (ms)
var _last_start: Dictionary = {}      # key -> Startzeit (ms)
var _last_variant: Dictionary = {}    # key -> zuletzt gespielter Index

var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0             # Index des gerade hörbaren Players
var _music_theme: String = ""
var _music_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		audio_players.append(player)
	for key in SOUND_TABLE.keys():
		_load_sound(key)
	# Zwei Player für weiche Überblendungen zwischen Themen.
	for i in range(2):
		var music := AudioStreamPlayer.new()
		music.bus = BUS_MUSIC
		music.volume_db = -80.0
		add_child(music)
		_music_players.append(music)

func _setup_buses() -> void:
	for bus_name in [BUS_SFX, BUS_UI, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	# Limiter auf Master: verhindert Übersteuern, wenn sechs Spieler gleichzeitig feuern.
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for i in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, i) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		limiter.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, limiter)

func _load_sound(key: String) -> void:
	var pack_dir := get_sound_pack_dir(sound_pack)
	var src_key := key
	var pick: Dictionary = {}
	if sound_pack == MIX_ID:
		pick = _mix.get(key, {"pack": RETRO_PACK})
	else:
		pick = _get_pack_swap(sound_pack).get(key, {})
	if not pick.is_empty():
		pack_dir = get_sound_pack_dir(str(pick.get("pack", RETRO_PACK)))
		# Die Mischung darf einem Feld auch den Sound einer anderen Taste geben.
		var src := str(pick.get("src", key))
		if SOUND_TABLE.has(src):
			src_key = src
	var streams: Array = []
	for file_name in SOUND_TABLE[src_key]["files"]:
		var path: String = pack_dir + file_name + ".wav"
		if not ResourceLoader.exists(path):
			path = SFX_DIR + file_name + ".wav"
		if ResourceLoader.exists(path):
			streams.append(load(path))
	if streams.is_empty():
		sounds.erase(key)
	else:
		sounds[key] = streams

func has_sound_pack(pack_id: String) -> bool:
	if pack_id == MIX_ID:
		return has_mix()
	for pack in SOUND_PACKS:
		if str(pack["id"]) == pack_id:
			return true
	return false

func has_mix() -> bool:
	return FileAccess.file_exists(MIX_FILE)

# Alle wählbaren Pakete fürs Optionsmenü, inklusive eigener Mischung.
func get_sound_pack_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = SOUND_PACKS.duplicate()
	if has_mix():
		list.append({"id": MIX_ID, "label": "Eigene Mischung", "dir": ""})
	return list

func _get_pack_swap(pack_id: String) -> Dictionary:
	for pack in SOUND_PACKS:
		if str(pack["id"]) == pack_id:
			return pack.get("swap", {})
	return {}

func get_sound_pack_dir(pack_id: String) -> String:
	for pack in SOUND_PACKS:
		if str(pack["id"]) == pack_id:
			return str(pack["dir"])
	return SFX_DIR

func _load_mix() -> void:
	_mix.clear()
	var file := FileAccess.open(MIX_FILE, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		for key in data.keys():
			var value = data[key]
			# Alt: {key: "paket"}, neu: {key: {"pack": "paket", "src": "taste"}}
			if value is Dictionary:
				_mix[str(key)] = {"pack": str(value.get("pack", RETRO_PACK)), "src": str(value.get("src", key))}
			else:
				_mix[str(key)] = {"pack": str(value), "src": str(key)}

# Lädt alle Effekte aus einem anderen Paket. Schon laufende Sounds spielen
# mit ihrem alten Stream zu Ende.
func set_sound_pack(pack_id: String) -> void:
	if not has_sound_pack(pack_id):
		pack_id = DEFAULT_SOUND_PACK
	if pack_id == sound_pack and pack_id != MIX_ID and not sounds.is_empty():
		return
	sound_pack = pack_id
	if pack_id == MIX_ID:
		_load_mix()
	_last_variant.clear()
	for key in SOUND_TABLE.keys():
		_load_sound(key)

# Startet die Musik für ein Tileset-Thema. Läuft sie schon, passiert nichts;
# ein anderes Thema wird weich übergeblendet.
func play_music(theme_id: String) -> void:
	if theme_id == _music_theme and _music_players[_music_active].playing:
		return
	if not MUSIC_TABLE.has(theme_id):
		stop_music()
		return
	var cfg: Dictionary = MUSIC_TABLE[theme_id]
	var path: String = MUSIC_DIR + str(cfg["file"])
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music_theme = theme_id
	var old := _music_players[_music_active]
	_music_active = 1 - _music_active
	var new_player := _music_players[_music_active]
	new_player.stream = stream
	new_player.volume_db = -40.0
	new_player.play()
	_fade_music(old, new_player, float(cfg.get("vol", -12.0)))

# Blendet die Musik aus (z. B. beim Zurückkehren ins Hauptmenü).
func stop_music() -> void:
	_music_theme = ""
	_fade_music(_music_players[_music_active], null, 0.0)

func _fade_music(out_player: AudioStreamPlayer, in_player: AudioStreamPlayer, in_db: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if out_player != null and out_player.playing:
		_music_tween.tween_property(out_player, "volume_db", -40.0, MUSIC_FADE_SECONDS)
	if in_player != null:
		_music_tween.tween_property(in_player, "volume_db", in_db, MUSIC_FADE_SECONDS)
	_music_tween.chain().tween_callback(func():
		if out_player != null and out_player != in_player:
			out_player.stop()
	)

# Lautstärke einer Gruppe ("Master", "SFX", "UI", "Music") linear 0..1 setzen.
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))

func play_sound(key: String, pitch_range: float = 0.1, volume_db: float = 0.0) -> void:
	key = ALIASES.get(key, key)
	if not sounds.has(key):
		return
	var cfg: Dictionary = SOUND_TABLE[key]
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(key, -100000)) < int(float(cfg.get("gap", 0.0)) * 1000.0):
		return
	var player := _acquire_player(key, int(cfg.get("max", 4)))
	if player == null:
		return
	_last_start[key] = now
	player.stream = _pick_variant(key)
	player.bus = cfg.get("bus", BUS_SFX)
	player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	player.volume_db = float(cfg.get("vol", 0.0)) + volume_db
	_player_key[player] = key
	_player_started[player] = now
	player.play()

func _pick_variant(key: String) -> AudioStream:
	var streams: Array = sounds[key]
	if streams.size() == 1:
		return streams[0]
	var idx := randi() % streams.size()
	if idx == int(_last_variant.get(key, -1)):
		idx = (idx + 1) % streams.size()
	_last_variant[key] = idx
	return streams[idx]

# Freie Stimme holen. Ist das Limit für diesen Schlüssel erreicht oder der Pool
# voll, wird die älteste passende Stimme neu verwendet.
func _acquire_player(key: String, max_voices: int) -> AudioStreamPlayer:
	var same_key: Array[AudioStreamPlayer] = []
	var free_player: AudioStreamPlayer = null
	for player in audio_players:
		if player.playing:
			if _player_key.get(player, "") == key:
				same_key.append(player)
		elif free_player == null:
			free_player = player
	if same_key.size() >= max_voices:
		return _oldest(same_key)
	if free_player != null:
		return free_player
	return _oldest(audio_players)

func _oldest(players: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	var best: AudioStreamPlayer = null
	var best_time := 0
	for player in players:
		var t := int(_player_started.get(player, 0))
		if best == null or t < best_time:
			best = player
			best_time = t
	return best

# Stoppt alle laufenden Effekte und gibt die Stream-Referenzen frei.
# Wird u. a. beim Verlassen einer Partie und in Tests genutzt.
func stop_all_sounds() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
	_player_key.clear()
	_player_started.clear()
