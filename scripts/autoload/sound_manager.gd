extends Node

var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Create pool of AudioStreamPlayers
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)
	
	_load_sound("shoot", "res://assets/sfx/laserSmall_000.ogg")
	_load_sound("shoot_alt", "res://assets/sfx/laserSmall_001.ogg")
	_load_sound("shoot_heavy", "res://assets/sfx/laserLarge_000.ogg")
	_load_sound("shoot_retro", "res://assets/sfx/laserRetro_000.ogg")
	_load_sound("shield", "res://assets/sfx/forceField_001.ogg")
	_load_sound("explosion", "res://assets/sfx/explosionCrunch_000.ogg")
	_load_sound("poison", "res://assets/sfx/slime_001.ogg")
	_load_sound("hit", "res://assets/sfx/impactPunch_heavy_000.ogg")
	_load_sound("bounce", "res://assets/sfx/impactMetal_light_000.ogg")
	_load_sound("click", "res://assets/sfx/click_001.ogg")
	_load_sound("confirm", "res://assets/sfx/confirmation_001.ogg")
	_load_sound("spring", "res://assets/sfx/glass_001.ogg")
	_load_sound("coin", "res://assets/sfx/glass_001.ogg")
	_load_sound("death", "res://assets/sfx/death_001.ogg")

func _load_sound(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		sounds[key] = load(path)

func play_sound(key: String, pitch_range: float = 0.1, volume_db: float = 0.0) -> void:
	if not sounds.has(key):
		return
	for player in audio_players:
		if not player.playing:
			player.stream = sounds[key]
			player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
			player.volume_db = volume_db
			player.play()
			return

# Stoppt alle laufenden Effekte und gibt die Stream-Referenzen frei.
# Wird u. a. beim Verlassen einer Partie und in Tests genutzt.
func stop_all_sounds() -> void:
	for player in audio_players:
		player.stop()
		player.stream = null
