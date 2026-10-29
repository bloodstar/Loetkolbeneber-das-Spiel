class_name HeroData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var role: String = "Skirmisher"
@export var description: String = ""
@export var passive_desc: String = ""
@export var ability_name: String = ""
@export var ability_desc: String = ""
@export var ability_cooldown: float = 6.0

@export var base_hp: int = 100
@export var base_shield: int = 0
@export var base_speed: float = 300.0
@export var base_jump_force: float = -460.0
@export var extra_jumps: int = 0

# Waffenbasiswerte. Die Munition wird pro Klasse angepasst; Karten addieren
# Munition bzw. multiplizieren das Feuerintervall und die Nachladezeit.
@export var base_ammo: int = 3
@export var base_fire_rate_cooldown: float = 0.22
@export var base_reload_time: float = 1.2

@export var color_tint: Color = Color.WHITE
@export var sprite_tile_name: String = "tile_0000.png"

# Versionierung für die Statistik (wie bei Karten): version zählt Basiswerte
# und Passiv, ability_version die aktive Fähigkeit (Konstanten in player.gd
# plus ability_cooldown). Wird etwas davon im Balancing geändert, die passende
# Zahl in Global._setup_heroes um 1 erhöhen.
@export var version: int = 1
@export var ability_version: int = 1

# Präfixe der Fähigkeitskonstanten in player.gd je Held. Evolutionen aus
# Klassenkarten (IGNIS_NAPALM_* usw.) gehören zu den Karten, nicht hierher.
const ABILITY_CONSTANT_PREFIXES: Dictionary = {
	"ignis": ["ROCKET_"],
	"volt": ["FLASH_BLINK_", "FREEZE_SPEED_MULT"],
	"spore": ["SPORE_CLOUD_"],
	"nova": ["SINGULARITY_"],
	"klinge": ["BLADE_STORM_"],
	"bastion": ["HEAL_FIELD_"],
	"phantom": ["SHADOW_STEP_"],
}
# Werte, die nichts an der Spielstärke ändern oder zur Fähigkeit gehören.
const _FINGERPRINT_IGNORED: Array[String] = [
	"id", "name", "role", "description", "ability_name", "ability_desc",
	"ability_cooldown", "color_tint", "sprite_tile_name", "version", "ability_version",
]

# Fingerabdruck der Basiswerte und des Passivs. Ändert er sich ohne neue
# version, warnt die Statistik.
func get_balance_fingerprint() -> String:
	var parts: PackedStringArray = []
	for prop in get_property_list():
		if not (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name.is_empty() or _FINGERPRINT_IGNORED.has(prop_name):
			continue
		parts.append("%s=%s" % [prop_name, var_to_str(get(prop_name))])
	parts.sort()
	return ";".join(parts).md5_text().substr(0, 8)

# Fingerabdruck der aktiven Fähigkeit aus Abklingzeit und player.gd-Konstanten.
func get_ability_fingerprint() -> String:
	var parts: PackedStringArray = ["ability_cooldown=%s" % var_to_str(ability_cooldown)]
	var player_script: Script = load("res://scripts/player.gd")
	var constants: Dictionary = player_script.get_script_constant_map()
	for const_name in constants.keys():
		for prefix in ABILITY_CONSTANT_PREFIXES.get(id, []):
			if str(const_name).begins_with(prefix):
				parts.append("%s=%s" % [const_name, var_to_str(constants[const_name])])
				break
	parts.sort()
	return ";".join(parts).md5_text().substr(0, 8)

# Eindeutiger Schlüssel für Auswertungen, z. B. "ignis@v2/a1".
func get_versioned_id() -> String:
	return "%s@v%d/a%d" % [id, version, ability_version]
