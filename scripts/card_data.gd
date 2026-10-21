class_name CardData
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var rarity: String = "Common" # Common, Uncommon, Rare, Epic, Legendary
@export var color: Color = Color(0.8, 0.8, 0.8)
# Leer = für alle Helden verfügbar. Sonst nur für diesen Helden (z. B. "ignis").
@export var hero_id: String = ""

# --- Talentbaum ---
# Grundkarten haben kein parent_card_id. Ausbaukarten erscheinen nur, wenn der
# Spieler die Grundkarte bereits besitzt. family_id gruppiert die Zweige.
@export var parent_card_id: String = ""
@export var family_id: String = ""
@export var evolution_branch: String = "" # "A" oder "B"

# Stat Modifiers
@export var max_hp_mult: float = 1.0
@export var max_hp_flat: int = 0
@export var hp_regen_add: float = 0.0 # Zusätzliche HP pro Sekunde nach 3s ohne Schaden
@export var body_size_mult: float = 1.0 # <1.0 = kleinere Spielfigur
@export var move_speed_mult: float = 1.0
@export var jump_force_mult: float = 1.0

# Bullet Modifiers
@export var damage_mult: float = 1.0
@export var bullet_speed_mult: float = 1.0
@export var bullet_size_mult: float = 1.0
@export var fire_rate_mult: float = 1.0 # Multiplier on shoot cooldown (e.g. 0.8 is 20% faster)
@export var max_ammo_add: int = 0
@export var reload_speed_mult: float = 1.0

# Special Modifiers
@export var bounces_add: int = 0
@export var homing_strength_add: float = 0.0
@export var explosion_radius_add: float = 0.0
@export var poison_stacks_add: int = 0
@export var poison_damage_mult: float = 1.0 # Multiplikator auf den Gift-Schaden pro Tick
@export var freeze_duration_add: float = 0.0
@export var lifesteal_percent_add: float = 0.0
@export var extra_jumps_add: int = 0
@export var shield_max_add: int = 0
@export var dash_cooldown_mult: float = 1.0
@export var multishot_add: int = 0
@export var spread_angle_deg: float = 0.0
@export var piercing_add: int = 0
@export var kamikaze: bool = false
@export var giant_growth: float = 0.0 # Scale player size up or down

# --- Talentbaum-Effekte ---
# Turm
@export var tower_enabled: bool = false
@export var tower_auto_spawn: bool = false
@export var tower_follow: bool = false
# Giftschuss
@export var poison_impact_cloud: bool = false
@export var poison_trail: bool = false
# Blitzschuss
@export var lightning_shot: bool = false
@export var chain_lightning: bool = false
@export var lightning_zone: bool = false
# Frostschuss
@export var frost_nova: bool = false
@export var frost_trail: bool = false
# Explosivschuss
@export var cluster_bomblets: bool = false
# Feuersturm
@export var fire_shot: bool = false
@export var fire_impact_zone: bool = false
@export var fire_trail: bool = false
# Wächterdrohne
@export var drone_count_add: int = 0
@export var drone_guardian: bool = false

# Klassen-/Fähigkeits-Modifikatoren
@export var ability_cooldown_mult: float = 1.0 # <1.0 = schnellere Ability
@export var barrier_duration_add: float = 0.0 # Zusätzliche Sekunden für Titan-Barriere
@export var shield_regen_mult: float = 1.0 # Multiplikator auf die Schild-Regeneration
