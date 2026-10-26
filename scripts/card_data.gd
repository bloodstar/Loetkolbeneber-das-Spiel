class_name CardData
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var description: String = ""
@export var rarity: String = "Common" # Common, Uncommon, Rare, Epic, Legendary
# Draft-Pool: Kern, Offensive, Defensive, Bewegung oder Chaos.
@export var pool: String = ""
@export var color: Color = Color(0.8, 0.8, 0.8)
# Leer = für alle Helden verfügbar. Sonst nur für diesen Helden (z. B. "ignis").
@export var hero_id: String = ""
# Optional: Karte erscheint nur, wenn der Spieler diese Mechanik bereits hat.
# Unterstützt: "dash", "ability", "block", "jump", "shield", "poison",
# "frost", "fire", "lightning", "tower" und "drone".
@export var required_mechanic: String = ""

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
@export var hp_regen_always_add: float = 0.0 # Zusätzliche HP pro Sekunde, auch während Schaden
# --- Tank / Rüstung ---
# Additive prozentuale Schadensreduktion. 0.05 = 5 % weniger eingehender Schaden.
@export var armor_percent_add: float = 0.0
# Additive Schadensreflexion. 0.10 = 10 % des erlittenen Schadens gehen zurück.
@export var damage_reflect_percent_add: float = 0.0
@export var body_size_mult: float = 1.0 # <1.0 = kleinere Spielfigur
@export var move_speed_mult: float = 1.0
@export var jump_force_mult: float = 1.0
@export var gravity_mult: float = 1.0 # <1.0 = geringere Schwerkraft, längere Luftzeit

# Bullet Modifiers
@export var damage_mult: float = 1.0
@export var bullet_speed_mult: float = 1.0
@export var bullet_size_mult: float = 1.0
@export var projectile_gravity_mult: float = 1.0 # >1.0 = stärkerer Bogen, <1.0 = flachere Flugbahn
@export var knockback_mult: float = 1.0 # >1.0 = stärkerer Rückstoß bei eigenen Treffern
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
@export var tower_max_health_add: int = 0
@export var tower_fire_rate_mult: float = 1.0 # <1.0 = kürzeres Feuerintervall
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
# Schutzdrohne: kreist um den Spieler und fängt gegnerische Projektile ab.
@export var blocker_drone_count_add: int = 0
@export var blocker_drone_heal: bool = false

# Klassen-/Fähigkeits-Modifikatoren
@export var ability_cooldown_mult: float = 1.0 # <1.0 = schnellere Ability
@export var shield_regen_mult: float = 1.0 # Multiplikator auf die Schild-Regeneration

# --- Standard-Block (universell, Taste Q) ---
@export var block_duration_add: float = 0.0 # Zusätzliche Sekunden Blockdauer
@export var block_cooldown_mult: float = 1.0 # <1.0 = kürzerer Block-Cooldown
@export var block_reflect_damage_add: float = 0.0 # Reflektierte Projektile: +Schaden (0.5 = +50%)
@export var block_knockback_radius_add: float = 0.0 # Rückstoß-Radius beim Blocken
@export var block_knockback_force_add: float = 0.0 # Stärke des Rückstoßes
@export var block_bomb: bool = false # Blockbombe beim Aktivieren
@export var block_bomb_damage: float = 0.0
@export var block_heal_zone: bool = false # Heilzone am Block-Standort
