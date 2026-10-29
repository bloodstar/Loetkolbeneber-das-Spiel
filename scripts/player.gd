class_name Player
extends CharacterBody2D

signal died(player_index: int)
signal health_changed(current: float, max_h: float, shield: float, max_s: float)
signal ammo_changed(current: int, max_a: int)
signal ability_cooldown_updated(current: float, max_c: float)
signal block_state_changed(is_blocking: bool, cooldown: float, max_cooldown: float)

@export var player_index: int = 1
@export var team_id: int = 0
@export var is_bot: bool = false
# Charakteranpassung: Zauberstabspitze und Farbe des Basis-Schusses.
var wand_tip_shape: String = "orb"
var wand_tip_color: Color = Color(0.6, 0.85, 1.0, 1.0)
var shot_color: Color = Color(1.0, 1.0, 1.0, 1.0)

# GrundgrÃƒÂ¶ÃƒÅ¸e der Spielfigur. Karten mit body_size_mult/giant_growth wirken
# zusÃƒÂ¤tzlich auf diesen Wert.
const BASE_CHARACTER_SCALE: float = 1.7
const GRAVITY: float = 980.0
# Treffer nehmen kurz Bewegungskontrolle weg, damit der Rückstoß nicht sofort
# von Eingabe und Reibung geschluckt wird.
const KNOCKBACK_CONTROL_SCALE: float = 0.25
# Einweg-Plattformen: So lange ignoriert die Figur nach "Runter" den Steg,
# auf dem sie stand. Reicht, um sicher unter die Stegkante zu fallen.
const ONE_WAY_DROP_TIME: float = 0.3
const KNOCKBACK_TIMER_MIN: float = 0.07
const KNOCKBACK_TIMER_MAX: float = 0.18
const KNOCKBACK_TIMER_FORCE_DIVISOR: float = 2600.0
# Tiefschnee bremst die Lauffichtigkeit, ohne die Sprungphysik zu verändern.
const DEEP_SNOW_SPEED_MULT: float = 0.52

# Eigener Flächenschaden (z. B. durch die eigene Explosivwaffe oder ein selbst
# ausgelöstes TNT-Fass) gilt als freundliches Feuer und wird halbiert.
const FRIENDLY_FIRE_DAMAGE_MULT: float = 0.5
const MAX_SELF_DAMAGE_REDUCTION: float = 0.9

# Tank-Karten addieren ihre Prozentwerte. Die Obergrenzen verhindern, dass
# gestapelte Rüstung Schaden vollständig negiert oder Reflexion unendlich wird.
const MAX_ARMOR_PERCENT: float = 0.75
const MAX_DAMAGE_REFLECT_PERCENT: float = 0.60
# Unterhalb dieses Lebensanteils greift der Reflexionsbonus der Rache-Karten.
const REFLECT_LOW_HP_THRESHOLD: float = 0.35
const MAX_REFLECT_HEAL_PERCENT: float = 1.0

# Vergiftete Charaktere bekommen einen dezenten Grünton und aufsteigende
# Giftbläschen. Der Tick-Sound bleibt bewusst im Hintergrund.
const POISON_TINT: Color = Color(0.62, 1.18, 0.68, 1.0)
const POISON_TICK_VOLUME_DB: float = -10.0

# Klinge: Klingensturm. Radius und Impuls bestimmen spürbar, ob die Fähigkeit
# trifft; die Visualisierung nutzt denselben Radius.
const BLADE_STORM_RADIUS: float = 145.0
const BLADE_STORM_DAMAGE_MULT: float = 1.2
const BLADE_STORM_KNOCKBACK: float = 540.0
const BLADE_STORM_INVULN: float = 0.5

# Werte der übrigen Heldenfähigkeiten. Global.get_hero_ability_details() liest
# dieselben Konstanten, damit die Beschreibungen im Menü stimmen.
const ROCKET_LEAP_SPEED: float = 950.0
const ROCKET_LEAP_DURATION: float = 0.32
const ROCKET_IMPACT_RADIUS: float = 140.0
const ROCKET_IMPACT_DAMAGE: float = 35.0
const ROCKET_IMPACT_KNOCKBACK: float = 550.0
const FLASH_BLINK_DISTANCE: float = 260.0
const FLASH_BLINK_RADIUS: float = 120.0
const FLASH_BLINK_DAMAGE: float = 20.0
const FLASH_BLINK_KNOCKBACK: float = 300.0
const FLASH_BLINK_FREEZE: float = 1.2
const FREEZE_SPEED_MULT: float = 0.6
const SPORE_CLOUD_RADIUS: float = 45.0
const SPORE_CLOUD_DURATION: float = 3.5
const SPORE_CLOUD_DPS: float = 9.0
const SINGULARITY_DISTANCE: float = 220.0
const SINGULARITY_DURATION: float = 2.08
const SINGULARITY_PULL_RADIUS: float = 250.0
const SINGULARITY_PULL_FORCE: float = 2600.0
# Bremst Bewegung weg vom Kern, damit Gegner nicht einfach hindurchfliegen.
const SINGULARITY_OUTWARD_DAMPING: float = 10.0
# Innerhalb dieses Radius werden Gegner im Kern festgehalten.
const SINGULARITY_HOLD_RADIUS: float = 40.0
# Gezogene Gegner verlieren kurz einen Teil ihrer Laufkontrolle, damit der
# Sog nicht einfach weggelaufen werden kann.
const SINGULARITY_CONTROL_LOCK: float = 0.2
# Ignis-Passive "Afterburner": Feuerspur während des Dashs.
const AFTERBURNER_ZONE_INTERVAL: float = 0.05
const AFTERBURNER_ZONE_RADIUS: float = 32.0
const AFTERBURNER_ZONE_DURATION: float = 2.0
const AFTERBURNER_BURN_STACKS: int = 2
const AFTERBURNER_BURN_DAMAGE: float = 5.0
const BURN_TICK_INTERVAL: float = 0.6
const HEAL_FIELD_DURATION: float = 4.0
const HEAL_FIELD_TICK_INTERVAL: float = 0.5
const HEAL_FIELD_TICK_HEAL: float = 8.0
const HEAL_FIELD_TICK_SHIELD: float = 10.0
const SHADOW_STEP_DISTANCE: float = 260.0
const SHADOW_STEP_RADIUS: float = 120.0
const SHADOW_STEP_DAMAGE_MULT: float = 1.1
const SHADOW_STEP_KNOCKBACK: float = 320.0
const SHADOW_STEP_INVULN: float = 0.9

# Fähigkeits-Evolutionen aus den Klassenkarten. Die Werte gelten vor den
# Fähigkeits-Multiplikatoren (ability_damage_mult usw.).
const IGNIS_NAPALM_RADIUS: float = 90.0
const IGNIS_NAPALM_DURATION: float = 3.5
const SPORE_CORROSIVE_INTERVAL: float = 0.8
const SPORE_CORROSIVE_STACKS: int = 3
const SPORE_SYMBIOSIS_HPS: float = 6.0
const NOVA_BINARY_OFFSET: float = 110.0
const NOVA_IMPLOSION_RADIUS: float = 160.0
const NOVA_IMPLOSION_DAMAGE: float = 30.0
const NOVA_IMPLOSION_KNOCKBACK: float = 620.0
const BLADE_ECHO_DELAY: float = 0.45
const BLADE_ECHO_DAMAGE_MULT: float = 0.6
const BLADE_BLOODLUST_HEAL: float = 0.35
const BASTION_BULWARK_REDUCTION: float = 0.30
const BASTION_PULSE_RADIUS: float = 130.0
const BASTION_PULSE_DAMAGE: float = 7.0
const BASTION_PULSE_KNOCKBACK: float = 220.0
const PHANTOM_CUT_WIDTH: float = 55.0
const PHANTOM_MARK_STUN: float = 0.7
const POISON_TICK_INTERVAL: float = 0.8
const SHIELD_REGEN_PER_SEC: float = 15.0
# Lebensregeneration startet sofort, auch direkt nach einem Treffer. Der Schild
# lädt erst nach SHIELD_REGEN_DELAY ohne Schaden; Karten können die Pause bis
# auf SHIELD_REGEN_DELAY_MIN verkürzen.
const SHIELD_REGEN_DELAY: float = 3.0
const SHIELD_REGEN_DELAY_MIN: float = 0.5
const HP_REGEN_DELAY: float = 0.0

# Nodes
@onready var sprite: PigCharacter = $Sprite2D
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var muzzle: Marker2D = $WeaponPivot/Muzzle
@onready var wand: MagicWand = $WeaponPivot/Wand
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var ghost_timer: Timer = $GhostTimer

# Core Stats (Derived from Hero + Cards)
var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false
var max_shield: float = 0.0
var current_shield: float = 0.0
# Prozentuale Schadensreduktion und zurückgeworfener Schadensanteil.
var armor_percent: float = 0.0
var damage_reflect_percent: float = 0.0
var reflect_low_hp_bonus: float = 0.0
var reflect_heal_percent: float = 0.0
var move_speed: float = 300.0
var jump_force: float = -470.0
var gravity_mult: float = 1.0
# Sturmwind: seitliche Drift in px/s, vom Host gesetzt.
var wind_push: float = 0.0
var max_jumps: int = 1
var jumps_remaining: int = 1

# Bullet Stats
var bullet_damage: float = 22.0
var bullet_speed: float = 650.0
var bullet_size: float = 1.0
var projectile_gravity_mult: float = 1.0
var knockback_mult: float = 1.0
var knockback_timer: float = 0.0
var fire_rate_cooldown: float = 0.22
var fire_timer: float = 0.0
var max_ammo: int = 3
var current_ammo: int = 3
var reload_time: float = 1.2
var reload_timer: float = 0.0
var is_reloading: bool = false
var bounces: int = 0
var homing: float = 0.0
var explosion_radius: float = 0.0
var poison_stacks: int = 0
var freeze_duration: float = 0.0
var lifesteal_percent: float = 0.0
var multishot: int = 0
var spread_angle: float = 0.0
var piercing: int = 0
var kamikaze: bool = false
var ricochet_bonus: float = 0.0
# Abpraller-Ausbaukarten (Gummiwand, Splitterkugeln, Gummipuffer).
var border_bounce: bool = false
var bounce_split: bool = false
var self_damage_reduction: float = 0.0

# Dash
var dash_speed: float = 750.0
var dash_duration: float = 0.22
var dash_cooldown: float = 1.8
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var is_invulnerable: bool = false

# Ability
var ability_name: String = ""
var ability_max_cooldown: float = 6.0
var ability_timer: float = 0.0
var shield_dome_node: Sprite2D = null

# --- Standard-Block (Taste Q), fÃƒÂ¼r alle Spieler gleich ---
# Kurzer Schutz: verhindert Schaden vollstÃƒÂ¤ndig und reflektiert Projektile.
const BLOCK_BASE_DURATION: float = 0.5
const BLOCK_BASE_COOLDOWN: float = 4.0
var is_blocking: bool = false
var block_timer: float = 0.0
var block_duration: float = BLOCK_BASE_DURATION
var block_cooldown: float = BLOCK_BASE_COOLDOWN
var block_cooldown_timer: float = 0.0
var block_reflect_damage_add: float = 0.0
var block_knockback_radius: float = 0.0
var block_knockback_force: float = 0.0
var block_bomb: bool = false
var block_bomb_damage: float = 0.0
var block_heal_zone: bool = false
var block_reflect: bool = true
var block_heal_pos: Vector2 = Vector2.ZERO
var block_heal_timer: float = 0.0
var block_heal_tick: float = 0.0
var block_cd_display_tenths: int = -1
# Minenleger: jeder Block lässt eine Mine fallen (siehe BlockMine).
const BLOCK_MINE_BASE_DAMAGE: float = 50.0
const BLOCK_MINE_BASE_RADIUS_TILES: float = 2.0
const BLOCK_MINE_TILE: float = 36.0
const BLOCK_MINE_MAX_ACTIVE: int = 8
var block_mine: bool = false
var block_mine_damage: float = BLOCK_MINE_BASE_DAMAGE
var block_mine_radius: float = BLOCK_MINE_BASE_RADIUS_TILES * BLOCK_MINE_TILE
var block_mine_instant: bool = false

# --- Nahkampfwaffe (Taste E) ---
# Werte kommen aus Global.MELEE_WEAPON_DATA, gewählt im Charakter-Tab.
const MELEE_SWING_SCRIPT = preload("res://scripts/melee_swing_effect.gd")
# Ungefährer Körperradius; die Reichweite zählt ab dem Rand beider Eber.
const MELEE_BODY_RADIUS: float = 11.0
# Halbe Breite des Lötkolben-Stichs.
const MELEE_THRUST_HALF_WIDTH: float = 16.0
# Ungefährer Radius des Piñata-Lamas (Kollision 28×34) für Nahkampftreffer.
const PINATA_HIT_RADIUS: float = 16.0
# Leichter Aufwärtsanteil, damit getroffene Eber abheben statt zu rutschen.
const MELEE_KNOCKBACK_LIFT: float = 0.25
# So lange nach einem Hammertreffer zählt ein Wandaufprall als Betäubung.
const MELEE_WALL_STUN_WINDOW: float = 0.45
var melee_weapon: String = "iron"
var melee_cooldown: float = 1.0
var melee_cooldown_timer: float = 0.0
# Zähler + Richtung des letzten Schlags; Clients spielen die Animation ab,
# sobald sich der Zähler im Snapshot erhöht.
var melee_swing_seq: int = 0
var melee_swing_dir: Vector2 = Vector2.RIGHT
var _last_net_melee_seq: int = -1
# Spieler-Effekte, die der Host an Clients schicken darf (siehe _net_player_fx).
const NET_PLAYER_FX: Array[String] = ["_flash_hit", "_heal_flash", "_flash_powerup", "_pulse_block_shield"]
const HEAL_FLASH_NET_GAP: float = 0.15
var _last_heal_flash_net_ms: int = -100000
# Client: Funken des Raketensprungs etwa im Physik-Takt des Hosts.
var _net_spark_timer: float = 0.0
var melee_wall_stun_timer: float = 0.0
var melee_wall_stun_duration: float = 0.0
# Nahkampf-Kartenwerte (in apply_stats aus den Karten summiert).
const MELEE_ECHO_DELAY: float = 0.28
const MELEE_ECHO_POWER: float = 0.6
const MELEE_EXECUTE_THRESHOLD: float = 0.35
const MELEE_CHAIN_RADIUS: float = 220.0
const MELEE_CHAIN_DAMAGE_MULT: float = 0.5
const MELEE_OBJECT_SLACK: float = 18.0

# Stellvertreter für hit_crate/hit_barrel, die ein Projektil mit shooter,
# velocity und damage erwarten.
class MeleeHitProxy extends Node2D:
	var shooter = null
	var velocity: Vector2 = Vector2.ZERO
	var damage: float = 0.0
var melee_damage_mult: float = 1.0
# Während true zählt verursachter Schaden als Fähigkeitsschaden (Statistik).
var dealing_ability_damage: bool = false
var melee_range_bonus: float = 0.0
# Faktor auf die gesamte Reichweite (Map-Modifier Brawl), nicht aus Karten.
var melee_range_mult: float = 1.0
var melee_knockback_mult: float = 1.0
var melee_arc_bonus: float = 0.0
var melee_freeze: float = 0.0
var melee_poison_stacks: int = 0
var melee_stun: float = 0.0
var melee_burn_stacks: int = 0
var melee_lifesteal: float = 0.0
var melee_wall_stun_bonus: float = 0.0
var melee_execute_bonus: float = 0.0
var melee_chain_lightning: bool = false
var melee_echo: bool = false
var melee_parry: bool = false
var melee_echo_timer: float = 0.0
var melee_echo_dir: Vector2 = Vector2.RIGHT

# Rocket Leap (Ignis)
var is_leaping: bool = false
var leap_timer: float = 0.0
var leap_dir: Vector2 = Vector2.ZERO

# ZusÃƒÂ¤tzliche FÃƒÂ¤higkeits-ZustÃƒÂ¤nde fÃƒÂ¼r die neuen Klassen.
var ability_invuln_timer: float = 0.0            # Klinge (Klingensturm) / Phantom (Schattensprung)
var heal_field_timer: float = 0.0                # Bastion
var heal_field_tick: float = 0.0                 # Bastion
var gravity_wells: Array = []                    # Nova: aktive SingularitÃƒÂ¤ten
# Fähigkeits-Karten: Multiplikatoren und freigeschaltete Evolutionen.
var ability_damage_mult: float = 1.0
var ability_radius_mult: float = 1.0
var ability_duration_mult: float = 1.0
var ability_range_mult: float = 1.0
var ability_evolutions: Array[String] = []
var heal_field_pos: Vector2 = Vector2.ZERO       # Bastion: Ort des Heilfelds
var blade_echo_timer: float = 0.0                # Klinge: verzögerter Echowirbel

# Status Effects
var poison_ticks_left: int = 0
var poison_tick_timer: float = 0.0
var poison_damage_per_tick: float = 4.0
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var burn_ticks_left: int = 0
var burn_tick_timer: float = 0.0
var burn_damage_per_tick: float = 5.0
var shield_regen_timer: float = 0.0
var shield_regen_mult: float = 1.0
var shield_regen_delay: float = SHIELD_REGEN_DELAY
var hp_regen: float = 0.0
var hp_regen_always: float = 0.0
var hp_regen_timer: float = 0.0

# --- Temporäre Powerup-Effekte aus Kisten und Random-Spawns ---
var powerup_invuln_timer: float = 0.0
var powerup_damage_timer: float = 0.0
var powerup_damage_mult: float = 1.0
var powerup_rapid_fire_timer: float = 0.0
# Auto-Angriff: kürzere Nahkampf-Abklingzeit, schlägt selbst nach Gegnern in Reichweite.
const POWERUP_AUTO_ATTACK_DURATION: float = 8.0
const POWERUP_AUTO_ATTACK_COOLDOWN_MULT: float = 0.5
var powerup_auto_attack_timer: float = 0.0
# Multishot: jeder Schuss feuert zusätzlich zwei Projektile im Fächer.
const POWERUP_MULTISHOT_DURATION: float = 8.0
const POWERUP_MULTISHOT_EXTRA: int = 2
const POWERUP_MULTISHOT_SPREAD_DEG: float = 20.0
var powerup_multishot_timer: float = 0.0
# Unsterblichkeit: Wer innerhalb des Fensters stirbt, liegt kurz am Boden
# (unverwundbar, ohne Steuerung) und steht dann mit halbem Leben wieder auf.
# Wird beim tödlichen Treffer verbraucht.
const POWERUP_UNDYING_WINDOW: float = 10.0
const POWERUP_REVIVE_DELAY: float = 2.0
const POWERUP_REVIVE_HEALTH_PERCENT: float = 0.5
const POWERUP_REVIVE_INVULN: float = 1.0
var powerup_undying_timer: float = 0.0
var revive_timer: float = 0.0 # >0 = liegt gerade am Boden und wird wiederbelebt
# Rache: 100 % Dornenschaden über die normale Schadensreflexion (über dem Kartendeckel).
const POWERUP_REVENGE_DURATION: float = 5.0
const POWERUP_REVENGE_REFLECT: float = 1.0
var powerup_revenge_timer: float = 0.0
# Unsichtbar: Gegner sehen den Charakter (samt Lebensleiste) nicht mehr.
# Schüsse und Effekte bleiben sichtbar. Online sieht das eigene Team ihn
# schwach, am geteilten Bildschirm gegen menschliche Gegner nur ganz schwach.
const POWERUP_INVISIBLE_DURATION: float = 6.0
const INVISIBLE_ALLY_ALPHA: float = 0.35
const INVISIBLE_SHARED_SCREEN_ALPHA: float = 0.1
const INVISIBLE_FADE_TIME: float = 0.5 # am Ende langsam wieder einblenden
var powerup_invisible_timer: float = 0.0
# Powerup-Karten: Wirkung (Dauer bzw. Heilmenge) und zusätzliche Sammelreichweite in px.
const POWERUP_PICKUP_TILE: float = 36.0
var powerup_strength_mult: float = 1.0
var powerup_pickup_range: float = 0.0
# Sternen-Schimmer wie bei Mario: Solange ein Powerup läuft, blinkt der Körper
# in dessen Farbe. Mehrere Effekte wechseln sich ab. Läuft über self_modulate
# (zusammen mit dem Gift-Grün), damit Treffer-/Heilblitze (modulate) und
# Teamfarben unangetastet bleiben.
const POWERUP_GLOW_COLORS: Dictionary = {
	"invulnerability": Color(0.45, 0.78, 1.0, 1.0),
	"damage": Color(1.0, 0.45, 0.25, 1.0),
	"rapid_fire": Color(1.0, 0.86, 0.3, 1.0),
	"auto_attack": Color(0.85, 0.45, 1.0, 1.0),
	"multishot": Color(0.3, 1.0, 0.85, 1.0),
	"undying": Color(1.0, 0.96, 0.62, 1.0),
	"revenge": Color(0.95, 0.12, 0.3, 1.0),
	"invisible": Color(0.72, 0.74, 0.9, 1.0),
}
const POWERUP_GLOW_SLOT_TIME: float = 0.28 # Sekunden pro Farbe bei mehreren Effekten
const POWERUP_GLOW_PULSE_HZ: float = 7.0
const POWERUP_GLOW_BOOST: float = 1.6 # >1 lässt die Farbe leuchten statt nur einzufärben
const POWERUP_GLOW_ENDING_TIME: float = 1.0 # letzte Sekunde: hektisches An/Aus-Flackern
var _powerup_glow_time: float = 0.0
var _powerup_glow_active: bool = false
var _powerup_aura_back: Node2D = null
var _powerup_aura_front: Node2D = null

# Letzte Schadensquelle für Kill-Credit. Der Timer verhindert, dass ein lange
# zurückliegender Treffer einen späteren Umgebungstod gutschreibt.
var last_damage_source: Player = null
var last_damage_timer: float = 0.0

# Countdown: Eingaben sind erst nach dem Start-Countdown erlaubt.
var control_enabled: bool = true

# --- Talentbaum-Effekte ---
var tower_enabled: bool = false
var tower_auto_spawn: bool = false
var tower_follow: bool = false
var tower_max_health: float = Companion.BASE_MAX_HEALTH
var tower_fire_rate_mult: float = 1.0
var tower_spawn_timer: float = 5.0
var towers: Array[Companion] = []

var poison_impact_cloud: bool = false
var poison_trail: bool = false
var poison_trail_timer: float = 0.0

var lightning_shot: bool = false
var chain_lightning: bool = false
var lightning_zone: bool = false

var frost_nova: bool = false
var frost_trail: bool = false
var frost_trail_timer: float = 0.0

var cluster_bomblets: bool = false

var fire_shot: bool = false
var fire_impact_zone: bool = false
var fire_trail: bool = false
var fire_trail_timer: float = 0.0
var afterburner_timer: float = 0.0               # Ignis: Feuerspur beim Dash

var drone_count: int = 0
var drone_guardian: bool = false
var blocker_drone_count: int = 0
var blocker_drone_heal: bool = false
var drones: Array[Companion] = []

# EisflÃƒÂ¤chen: Quellen werden gezÃƒÂ¤hlt, damit angrenzende Eis-Tiles kein Flackern
# verursachen. Bewegungsbeschleunigung und Reibung werden auf Eis reduziert.
var ice_sources: Dictionary = {}
var on_ice: bool = false
# Tiefschnee und externe Booster werden getrennt gezählt/verarbeitet, damit
# mehrere überlappende Sensorflächen keinen Zustand vorzeitig beenden.
var deep_snow_sources: Dictionary = {}
var on_deep_snow: bool = false
var speed_boost_timer: float = 0.0
var speed_boost_direction: float = 0.0
var speed_boost_speed: float = 0.0

# Opponent reference for AI / Homing
var opponent: Player = null
var aim_direction: Vector2 = Vector2.RIGHT

# Laufender Treffer-Blitz; wird bei schnellen Folge-Treffern neu gestartet,
# damit sich mehrere Tweens nicht gegenseitig überlagern.
var _hit_flash_tween: Tween = null
# Rundenstart-Intro: Portal, Auftauch-Animation und anschließendes Aufblinken.
var _spawn_intro_tween: Tween = null
var _poison_bubbles: PoisonBubbleEffect = null

# --- Netzwerk ---
# Replica: wird auf dem Client nur aus Snapshots dargestellt, keine eigene Physik.
var is_replica: bool = false
# Remote: wird auf dem Host von der Eingabe des Clients gesteuert.
var is_remote: bool = false
var net_target_pos: Vector2 = Vector2.ZERO
# Letzter bekannter Snapshot-Lebenswert, um auf Clients ebenfalls eine
# Trefferanimation auszulösen, wenn die HP sinken.
var _last_network_health: float = -1.0
var remote_input: Dictionary = {
	"move_x": 0.0,
	"jump": false,
	"jump_release": false,
	"shoot": false,
	"dash": false,
	"ability": false,
	"block": false,
	"reload": false,
	"melee": false,
	"drop": false,
	"aim": Vector2.RIGHT,
}
# Einweg-Stege, durch die die Figur gerade hindurchfällt (Kollisionsausnahme).
var _drop_through_bodies: Array = []
var _drop_through_timer: float = 0.0

var bullet_scene = preload("res://scenes/player/bullet.tscn")
const EFFECT_CIRCLE_TEXTURE: Texture2D = preload("res://assets/projectiles/effect_circle.png")
const PORTAL_SPAWN_EFFECT_SCRIPT = preload("res://scripts/portal_spawn_effect.gd")
const POISON_BUBBLE_EFFECT_SCRIPT = preload("res://scripts/poison_bubbles.gd")
const POWERUP_AURA_SCRIPT = preload("res://scripts/powerup_aura.gd")

func _ready() -> void:
	ghost_timer.timeout.connect(_spawn_ghost_trail)
	
	# Schildwabe fÃƒÂ¼r den universellen Block.
	shield_dome_node = Sprite2D.new()
	shield_dome_node.texture = EFFECT_CIRCLE_TEXTURE
	shield_dome_node.modulate = Color(0.3, 0.8, 1.0, 0.7)
	shield_dome_node.scale = Vector2(4.5, 4.5)
	shield_dome_node.visible = false
	add_child(shield_dome_node)

	_poison_bubbles = POISON_BUBBLE_EFFECT_SCRIPT.new()
	add_child(_poison_bubbles)

	# Powerup-Auren: Energieaura hinter dem Körper (erstes Kind = wird zuerst
	# gezeichnet), Blase/Heiligenschein/Stacheln davor.
	_powerup_aura_back = POWERUP_AURA_SCRIPT.new()
	add_child(_powerup_aura_back)
	move_child(_powerup_aura_back, 0)
	_powerup_aura_front = POWERUP_AURA_SCRIPT.new()
	_powerup_aura_front.set("front", true)
	add_child(_powerup_aura_front)
	
	if not Global.pig_appearance_changed.is_connected(_on_pig_appearance_changed):
		Global.pig_appearance_changed.connect(_on_pig_appearance_changed)

	apply_stats()
	
	if is_replica:
		collision_layer = 0
		collision_mask = 0
		set_physics_process(false)
		sprite.use_parent_floor_state = false

func _process(delta: float) -> void:
	_update_powerup_glow(delta)
	_update_powerup_aura()
	_update_body_alpha()
	if not is_replica or not visible:
		return
	if global_position.distance_to(net_target_pos) > 250.0:
		global_position = net_target_pos
	else:
		global_position = global_position.lerp(net_target_pos, clampf(20.0 * delta, 0.0, 1.0))
	if is_leaping:
		_net_spark_timer -= delta
		if _net_spark_timer <= 0.0:
			_net_spark_timer = 1.0 / 60.0
			_spawn_fire_sparks()

func apply_stats() -> void:
	var hero_id: String = Global.get_player_hero_id(player_index)
	var hero: HeroData = Global.get_hero(hero_id)
	var card_list: Array = Global.get_player_cards(player_index)
	
	_apply_pig_appearance()
	
	ability_name = hero.ability_name
	ability_max_cooldown = hero.ability_cooldown
	
	# Basis-HP: Der Lobby-Prozent-Faktor skaliert den Heldenwert, damit die
	# Klassenunterschiede (z. B. Bastion 125 vs. Volt 85) erhalten bleiben.
	var base_hp: int = Global.get_effective_base_hp(hero)
	var base_shield = hero.base_shield
	var hp_mult = 1.0
	var hp_flat = 0
	var spd_mult = 1.0
	var jmp_mult = 1.0
	var grav_mult = 1.0
	var extra_jumps_total = hero.extra_jumps
	
	var dmg_mult = 1.0
	var b_spd_mult = 1.0
	var b_size_mult = 1.0
	var b_grav_mult = 1.0
	var kb_mult = 1.0
	var fr_mult = 1.0
	var ammo_add = 0
	var dash_cd_mult = 1.0
	var ability_cd_mult = 1.0
	var reload_mult = 1.0
	var shield_regen_stack = 1.0
	var shield_delay_add = 0.0
	var hp_regen_total = 0.0
	var hp_regen_always_total = 0.0
	var armor_total = 0.0
	var damage_reflect_total = 0.0
	var reflect_low_hp_total = 0.0
	var reflect_heal_total = 0.0

	# Block-Modifikatoren aus Karten.
	var block_dur_add = 0.0
	var block_cd_mult = 1.0
	var block_kb_radius = 0.0
	var block_kb_force = 0.0
	var block_bomb_enabled = false
	var block_bomb_dmg = 0.0
	var block_heal_enabled = false
	var block_reflect_dmg_add = 0.0
	var mine_enabled := false
	var mine_dmg_add := 0.0
	var mine_radius_tiles_add := 0.0
	var mine_instant_enabled := false
	var m_dmg_mult := 1.0
	var m_range_add := 0.0
	var m_cd_mult := 1.0
	var m_kb_mult := 1.0
	var m_arc_add := 0.0
	var m_freeze := 0.0
	var m_poison := 0
	var m_stun := 0.0
	var m_burn := 0
	var m_lifesteal := 0.0
	var m_wall_stun := 0.0
	var m_execute := 0.0
	var m_chain := false
	var m_echo := false
	var m_parry := false
	var size_mult = BASE_CHARACTER_SCALE
	var poison_dmg_mult = 1.0
	var tower_health_add = 0
	var tower_fire_rate_mult_stack = 1.0
	var ab_dmg_mult = 1.0
	var ab_radius_mult = 1.0
	var ab_duration_mult = 1.0
	var ab_range_mult = 1.0
	var pw_strength_add := 0.0
	var pw_range_tiles := 0.0
	ability_evolutions.clear()
	
	bounces = 0
	homing = 0.0
	explosion_radius = 0.0
	poison_stacks = 2 if hero.id == "spore" else 0
	freeze_duration = 0.0
	lifesteal_percent = 0.0
	multishot = 0
	spread_angle = 0.0
	piercing = 0
	kamikaze = false
	ricochet_bonus = 0.0
	border_bounce = false
	bounce_split = false
	self_damage_reduction = 0.0
	knockback_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_direction = 0.0
	speed_boost_speed = 0.0

	# Talentbaum-Flags zurÃƒÂ¼cksetzen
	tower_enabled = false
	tower_auto_spawn = false
	tower_follow = false
	poison_impact_cloud = false
	poison_trail = false
	lightning_shot = false
	chain_lightning = false
	lightning_zone = false
	frost_nova = false
	frost_trail = false
	cluster_bomblets = false
	fire_shot = false
	fire_impact_zone = false
	fire_trail = false
	drone_count = 0
	drone_guardian = false
	blocker_drone_count = 0
	blocker_drone_heal = false
	
	# Stack Cards
	for c in card_list:
		hp_mult *= c.max_hp_mult
		hp_flat += c.max_hp_flat
		spd_mult *= c.move_speed_mult
		jmp_mult *= c.jump_force_mult
		grav_mult *= c.gravity_mult
		dmg_mult *= c.damage_mult
		b_spd_mult *= c.bullet_speed_mult
		b_size_mult *= c.bullet_size_mult
		b_grav_mult *= c.projectile_gravity_mult
		kb_mult *= c.knockback_mult
		fr_mult *= c.fire_rate_mult
		ammo_add += c.max_ammo_add
		reload_mult *= c.reload_speed_mult
		dash_cd_mult *= c.dash_cooldown_mult
		ability_cd_mult *= c.ability_cooldown_mult
		ab_dmg_mult *= c.ability_damage_mult
		ab_radius_mult *= c.ability_radius_mult
		ab_duration_mult *= c.ability_duration_mult
		ab_range_mult *= c.ability_range_mult
		if not c.ability_evolution.is_empty() and not ability_evolutions.has(c.ability_evolution):
			ability_evolutions.append(c.ability_evolution)
		shield_regen_stack *= c.shield_regen_mult
		shield_delay_add += c.shield_regen_delay_add
		extra_jumps_total += c.extra_jumps_add

		# Standard-Block verbessern.
		block_dur_add += c.block_duration_add
		block_cd_mult *= c.block_cooldown_mult
		block_kb_radius += c.block_knockback_radius_add
		block_kb_force += c.block_knockback_force_add
		block_reflect_dmg_add += c.block_reflect_damage_add
		if c.block_bomb:
			block_bomb_enabled = true
		block_bomb_dmg = maxf(block_bomb_dmg, c.block_bomb_damage)
		if c.block_heal_zone:
			block_heal_enabled = true
		if c.block_mine:
			mine_enabled = true
		mine_dmg_add += c.mine_damage_add
		mine_radius_tiles_add += c.mine_radius_add
		if c.mine_instant:
			mine_instant_enabled = true
		m_dmg_mult *= c.melee_damage_mult
		m_range_add += c.melee_range_add
		m_cd_mult *= c.melee_cooldown_mult
		m_kb_mult *= c.melee_knockback_mult
		m_arc_add += c.melee_arc_add
		m_freeze += c.melee_freeze_add
		m_poison += c.melee_poison_stacks_add
		m_stun += c.melee_stun_add
		m_burn += c.melee_burn_stacks_add
		m_lifesteal += c.melee_lifesteal_add
		m_wall_stun += c.melee_wall_stun_add
		m_execute += c.melee_execute_bonus_add
		m_chain = m_chain or c.melee_chain_lightning
		m_echo = m_echo or c.melee_echo
		m_parry = m_parry or c.melee_parry
		base_shield += c.shield_max_add
		hp_regen_total += c.hp_regen_add
		hp_regen_always_total += c.hp_regen_always_add
		armor_total += c.armor_percent_add
		damage_reflect_total += c.damage_reflect_percent_add
		reflect_low_hp_total += c.reflect_low_hp_bonus_add
		reflect_heal_total += c.reflect_heal_percent_add
		bounces += c.bounces_add
		homing += c.homing_strength_add
		explosion_radius += c.explosion_radius_add
		poison_stacks += c.poison_stacks_add
		poison_dmg_mult *= c.poison_damage_mult
		freeze_duration += c.freeze_duration_add
		lifesteal_percent += c.lifesteal_percent_add
		multishot += c.multishot_add
		spread_angle += c.spread_angle_deg
		piercing += c.piercing_add
		size_mult *= c.body_size_mult
		size_mult *= 1.0 + c.giant_growth
		if c.kamikaze:
			kamikaze = true
		if c.id == "ricochet_frenzy":
			ricochet_bonus += 0.20
		border_bounce = border_bounce or c.border_bounce
		bounce_split = bounce_split or c.bounce_split
		self_damage_reduction += c.self_damage_reduction_add
		pw_strength_add += c.powerup_strength_add
		pw_range_tiles += c.powerup_pickup_range_add

		# Talentbaum-Effekte
		if c.tower_enabled:
			tower_enabled = true
		if c.tower_auto_spawn:
			tower_auto_spawn = true
		if c.tower_follow:
			tower_follow = true
		tower_health_add += c.tower_max_health_add
		tower_fire_rate_mult_stack *= c.tower_fire_rate_mult
		if c.poison_impact_cloud:
			poison_impact_cloud = true
		if c.poison_trail:
			poison_trail = true
		if c.lightning_shot:
			lightning_shot = true
		if c.chain_lightning:
			chain_lightning = true
		if c.lightning_zone:
			lightning_zone = true
		if c.frost_nova:
			frost_nova = true
		if c.frost_trail:
			frost_trail = true
		if c.cluster_bomblets:
			cluster_bomblets = true
		if c.fire_shot:
			fire_shot = true
		if c.fire_impact_zone:
			fire_impact_zone = true
		if c.fire_trail:
			fire_trail = true
		drone_count += c.drone_count_add
		if c.drone_guardian:
			drone_guardian = true
		blocker_drone_count += c.blocker_drone_count_add
		if c.blocker_drone_heal:
			blocker_drone_heal = true
	
	max_health = (base_hp + hp_flat) * hp_mult
	current_health = max_health
	armor_percent = clampf(armor_total, 0.0, MAX_ARMOR_PERCENT)
	damage_reflect_percent = clampf(damage_reflect_total, 0.0, MAX_DAMAGE_REFLECT_PERCENT)
	reflect_low_hp_bonus = maxf(0.0, reflect_low_hp_total)
	reflect_heal_percent = clampf(reflect_heal_total, 0.0, MAX_REFLECT_HEAL_PERCENT)
	tower_max_health = Companion.BASE_MAX_HEALTH + float(tower_health_add)
	tower_fire_rate_mult = maxf(0.25, tower_fire_rate_mult_stack)
	max_shield = base_shield
	current_shield = max_shield
	move_speed = hero.base_speed * spd_mult
	jump_force = hero.base_jump_force * jmp_mult
	gravity_mult = grav_mult
	max_jumps = 1 + extra_jumps_total
	jumps_remaining = max_jumps
	
	bullet_damage = Global.base_damage * dmg_mult
	bullet_speed = 650.0 * b_spd_mult
	bullet_size = 1.0 * b_size_mult
	projectile_gravity_mult = maxf(0.0, b_grav_mult)
	knockback_mult = maxf(0.1, kb_mult)
	fire_rate_cooldown = maxf(0.08, hero.base_fire_rate_cooldown * fr_mult)
	max_ammo = maxi(1, hero.base_ammo + ammo_add)
	current_ammo = max_ammo
	dash_cooldown = maxf(0.5, 1.8 * dash_cd_mult)
	ability_max_cooldown = maxf(1.0, hero.ability_cooldown * ability_cd_mult)
	ability_damage_mult = clampf(ab_dmg_mult, 0.25, 4.0)
	ability_radius_mult = clampf(ab_radius_mult, 0.5, 2.5)
	ability_duration_mult = clampf(ab_duration_mult, 0.5, 3.0)
	ability_range_mult = clampf(ab_range_mult, 0.5, 2.5)
	powerup_strength_mult = 1.0 + clampf(pw_strength_add, 0.0, 3.0)
	powerup_pickup_range = clampf(pw_range_tiles, 0.0, 10.0) * POWERUP_PICKUP_TILE
	blade_echo_timer = 0.0
	reload_time = hero.base_reload_time / maxf(0.1, reload_mult)
	shield_regen_mult = shield_regen_stack
	shield_regen_delay = maxf(SHIELD_REGEN_DELAY_MIN, SHIELD_REGEN_DELAY + shield_delay_add)
	shield_regen_timer = 0.0
	# Bastion-Passive "Aurora": doppelte Schild-Regeneration.
	if hero.id == "bastion":
		shield_regen_mult *= 2.0
	hp_regen = hp_regen_total
	hp_regen_always = hp_regen_always_total

	# Universeller Block: Basiswerte plus Kartenboni. Dauer und Cooldown sind
	# gedeckelt, damit gestapelte Block-Karten nicht zu dauerhafter ImmunitÃƒÂ¤t fÃƒÂ¼hren.
	block_duration = clampf(BLOCK_BASE_DURATION + block_dur_add, 0.2, 1.5)
	block_cooldown = maxf(2.5, BLOCK_BASE_COOLDOWN * block_cd_mult)
	block_reflect_damage_add = block_reflect_dmg_add
	block_knockback_radius = block_kb_radius
	block_knockback_force = block_kb_force
	block_bomb = block_bomb_enabled
	block_bomb_damage = block_bomb_dmg if block_bomb_dmg > 0.0 else 30.0
	block_heal_zone = block_heal_enabled
	block_mine = mine_enabled
	block_mine_damage = BLOCK_MINE_BASE_DAMAGE + mine_dmg_add
	block_mine_radius = (BLOCK_MINE_BASE_RADIUS_TILES + mine_radius_tiles_add) * BLOCK_MINE_TILE
	block_mine_instant = mine_instant_enabled
	# Der Standard-Block reflektiert immer Projektile.
	block_reflect = true
	is_blocking = false
	block_timer = 0.0
	block_cooldown_timer = 0.0
	block_heal_timer = 0.0
	if shield_dome_node:
		shield_dome_node.visible = false
	var melee_data := Global.get_melee_weapon_data(Global.get_melee_weapon(player_index))
	melee_weapon = Global.get_melee_weapon(player_index)
	# Gedeckelt, damit gestapelte Karten den Nahkampf nicht zum Dauerfeuer machen.
	melee_cooldown = maxf(0.3, float(melee_data["cooldown"]) * m_cd_mult)
	melee_cooldown_timer = 0.0
	melee_wall_stun_timer = 0.0
	melee_damage_mult = m_dmg_mult
	melee_range_bonus = clampf(m_range_add, 0.0, 3.0)
	melee_range_mult = 1.0
	melee_knockback_mult = m_kb_mult
	melee_arc_bonus = clampf(m_arc_add, 0.0, 180.0)
	melee_freeze = minf(m_freeze, 3.0)
	melee_poison_stacks = m_poison
	melee_stun = minf(m_stun, 1.0)
	melee_burn_stacks = m_burn
	melee_lifesteal = clampf(m_lifesteal, 0.0, 0.6)
	melee_wall_stun_bonus = minf(m_wall_stun, 1.5)
	melee_execute_bonus = m_execute
	melee_chain_lightning = m_chain
	melee_echo = m_echo
	melee_parry = m_parry
	melee_echo_timer = 0.0
	hp_regen_timer = 0.0
	powerup_invuln_timer = 0.0
	powerup_damage_timer = 0.0
	powerup_damage_mult = 1.0
	powerup_rapid_fire_timer = 0.0
	powerup_auto_attack_timer = 0.0
	powerup_multishot_timer = 0.0
	powerup_undying_timer = 0.0
	powerup_revenge_timer = 0.0
	powerup_invisible_timer = 0.0
	revive_timer = 0.0
	_set_revive_visual(false)
	poison_damage_per_tick = 4.0 * poison_dmg_mult

	tower_spawn_timer = 5.0
	poison_trail_timer = 0.0
	frost_trail_timer = 0.0
	fire_trail_timer = 0.0
	
	scale = Vector2(size_mult, size_mult)

	_clear_drones()
	_spawn_drones()
	
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("ability_cooldown_updated", 0.0, ability_max_cooldown)
	emit_signal("block_state_changed", false, 0.0, block_cooldown)

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_update_drop_through(delta)
	
	# Rocket Leap state (Ignis)
	if is_leaping:
		leap_timer -= delta
		velocity = leap_dir * ROCKET_LEAP_SPEED
		_spawn_fire_sparks()
		var coll = move_and_collide(velocity * delta)
		if coll or leap_timer <= 0.0:
			is_leaping = false
			is_invulnerable = _has_temporary_invulnerability()
			_trigger_rocket_impact()
		return
	
	if is_dashing:
		velocity = dash_dir * dash_speed
		move_and_slide()
		return
	
	# Universeller Block: Schildwabe anzeigen und Projektile reflektieren.
	if is_blocking and shield_dome_node:
		shield_dome_node.visible = true
		shield_dome_node.rotation += delta * 8.0
		if block_reflect:
			for b in get_tree().get_nodes_in_group("bullet"):
				if is_instance_valid(b) and b.shooter != self and global_position.distance_to(b.global_position) < 60.0:
					if is_instance_valid(b.shooter) and b.shooter is Player and b.shooter.team_id == team_id:
						continue
					b.shooter = self
					b.target_enemy = _valid_opponent()
					b.velocity = -b.velocity * 1.3
					# Konterblitz-Karte: reflektierte Projektile werden stÃƒÂ¤rker.
					b.damage *= 1.0 + block_reflect_damage_add
					b.modulate = Color(0.75, 0.5, 1.0)
					_fx("sound", {"snd": ["bounce", 0.3, 3.0]})
	elif shield_dome_node:
		shield_dome_node.visible = false
	
	# Gravity & Movement
	if not is_on_floor():
		var grav := GRAVITY * gravity_mult
		# Wall sliding
		if is_on_wall() and velocity.y > 0 and (Input.is_action_pressed(_act("left")) or Input.is_action_pressed(_act("right"))):
			velocity.y = minf(velocity.y + (grav * 0.4) * delta, 150.0)
		else:
			velocity.y += grav * delta
	else:
		jumps_remaining = max_jumps
	
	# Input Handling. WÃƒÂ¤hrend des Start-Countdowns oder eines BetÃƒÂ¤ubungs-Effekts
	# werden keine Bewegungs-/Angriffseingaben verarbeitet.
	if control_enabled and stun_timer <= 0.0:
		if is_remote and not is_bot:
			_handle_remote_input(delta)
		elif not is_bot:
			# Offenes Optionsmenü (online läuft die Runde weiter): keine Eingaben.
			if GameSettings.gameplay_input_blocked:
				_apply_disabled_input()
			else:
				_handle_player_input(delta)
	else:
		_apply_disabled_input()
		remote_input.jump = false
		remote_input.jump_release = false
		remote_input.dash = false
		remote_input.ability = false
		remote_input.block = false
		remote_input.shoot = false
		remote_input.reload = false
		remote_input.melee = false
		remote_input.drop = false
	
	# Wind als Versatz nur für diese Bewegung, damit die Lauf-Bremse ihn nicht
	# sofort wegdämpft. Gegen den Wind läuft man langsamer, mit ihm schneller.
	if wind_push != 0.0:
		var own_x := velocity.x
		velocity.x += wind_push
		move_and_slide()
		if is_on_wall():
			velocity.x = 0.0
		else:
			velocity.x = own_x
	else:
		move_and_slide()
	_check_melee_wall_stun()
	
	# Aim pivot rotation
	weapon_pivot.rotation = aim_direction.angle()
	if abs(weapon_pivot.rotation) > PI / 2.0:
		wand.set_flip_v(true)
		sprite.flip_h = true
	else:
		wand.set_flip_v(false)
		sprite.flip_h = false

func _act(suffix: String) -> String:
	return "p1_" + suffix if player_index == 1 else "p2_" + suffix

func _knockback_control_scale() -> float:
	return KNOCKBACK_CONTROL_SCALE if knockback_timer > 0.0 else 1.0

func _current_ground_speed() -> float:
	var current_spd := move_speed
	if freeze_timer > 0.0:
		current_spd *= FREEZE_SPEED_MULT
	if on_deep_snow:
		current_spd *= DEEP_SNOW_SPEED_MULT
	return current_spd

# Gemeinsame horizontale Bewegung für lokale Spieler, Remote-Eingaben und die
# Eingabesperre. Booster überstimmen für ihre kurze Dauer die normale Steuerung.
func _apply_horizontal_movement(input_x: float) -> void:
	if speed_boost_timer > 0.0 and speed_boost_speed > 0.0:
		velocity.x = speed_boost_direction * speed_boost_speed
		return
	var current_spd := _current_ground_speed()
	var accel_factor := 0.06 if on_ice else 0.25
	var decel_factor := 0.015 if on_ice else 0.2
	var kb_control := _knockback_control_scale()
	if input_x != 0.0:
		velocity.x = move_toward(velocity.x, input_x * current_spd, current_spd * accel_factor * kb_control)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_spd * decel_factor * kb_control)

func _apply_disabled_input() -> void:
	_apply_horizontal_movement(0.0)

func _handle_player_input(_delta: float) -> void:
	# Move X – auf Eis wird deutlich langsamer beschleunigt und gebremst,
	# Tiefschnee senkt zusätzlich die maximale Geschwindigkeit.
	var input_x = Input.get_axis(_act("left"), _act("right"))
	_apply_horizontal_movement(input_x)
	
	# Jump
	if Input.is_action_just_pressed(_act("jump")):
		jump()

	# Runter: durch einen Einweg-Steg fallen.
	if Input.is_action_just_pressed(_act("down")):
		drop_through()
	
	# Cut jump short on release
	if Input.is_action_just_released(_act("jump")) and velocity.y < 0:
		velocity.y *= 0.5
	
	# Aim
	if player_index == 1:
		aim_direction = (get_global_mouse_position() - global_position).normalized()
	else:
		# P2 keyboard aim fallback
		var aim_x = Input.get_axis("p2_left", "p2_right")
		var aim_y = Input.get_axis("p2_up", "p2_down")
		if Vector2(aim_x, aim_y).length_squared() > 0.1:
			aim_direction = Vector2(aim_x, aim_y).normalized()
	
	# Dash
	if Input.is_action_just_pressed(_act("dash")):
		dash()
	
	# Shoot
	if Input.is_action_pressed(_act("shoot")):
		shoot()
	
	# Standard-Block (Q) Ã¢â‚¬â€œ fÃƒÂ¼r alle Spieler gleich.
	if Input.is_action_just_pressed(_act("block")):
		start_block()

	# Manuelles Nachladen (P1: R, P2: L).
	if Input.is_action_just_pressed(_act("reload")):
		manual_reload()

	# Nahkampfwaffe (P1: E, P2: K).
	if Input.is_action_just_pressed(_act("melee")):
		melee_attack()

	# KlassenfÃƒÂ¤higkeit (Rechtsklick / E / F).
	var ability_pressed = Input.is_action_just_pressed(_act("ability"))
	if ability_pressed:
		use_ability()

# --- Netzwerk-Eingabe / Replikation ---

func set_remote_input(data: Dictionary) -> void:
	remote_input.move_x = clampf(float(data.get("move_x", 0.0)), -1.0, 1.0)
	remote_input.shoot = bool(data.get("shoot", false))
	var aim_value = data.get("aim", Vector2.RIGHT)
	if aim_value is Vector2 and aim_value.length_squared() > 0.001:
		remote_input.aim = aim_value.normalized()
	if bool(data.get("jump", false)):
		remote_input.jump = true
	if bool(data.get("jump_release", false)):
		remote_input.jump_release = true
	if bool(data.get("dash", false)):
		remote_input.dash = true
	if bool(data.get("ability", false)):
		remote_input.ability = true
	if bool(data.get("block", false)):
		remote_input.block = true
	if bool(data.get("reload", false)):
		remote_input.reload = true
	if bool(data.get("melee", false)):
		remote_input.melee = true
	if bool(data.get("drop", false)):
		remote_input.drop = true

# EisflÃƒÂ¤chen melden sich hier an/ab. Mehrere Quellen gleichzeitig (z. B. zwei
# angrenzende Eis-Tiles) werden gezÃƒÂ¤hlt.
func add_ice_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	ice_sources[source.get_instance_id()] = true
	on_ice = true

func remove_ice_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	ice_sources.erase(source.get_instance_id())
	on_ice = not ice_sources.is_empty()

# Tiefschnee meldet sich wie Eis als Sensor an/ab. Die Verlangsamung wirkt
# additiv zur Kartenbewegung, überschreibt aber keine Boost-/Trefferimpulse.
func add_deep_snow_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	deep_snow_sources[source.get_instance_id()] = true
	on_deep_snow = true

func remove_deep_snow_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	deep_snow_sources.erase(source.get_instance_id())
	on_deep_snow = not deep_snow_sources.is_empty()

func apply_speed_boost(direction: float, boost_speed: float, duration: float = 0.26) -> void:
	var dir_sign := signf(direction)
	if dir_sign == 0.0:
		dir_sign = 1.0
	speed_boost_direction = dir_sign
	speed_boost_speed = maxf(boost_speed, move_speed * 1.6)
	speed_boost_timer = maxf(speed_boost_timer, maxf(0.05, duration))
	velocity.x = speed_boost_direction * speed_boost_speed

func apply_trampoline_bounce(force: float) -> void:
	velocity.y = force
	jumps_remaining = max_jumps
	_fx("sound", {"snd": ["spring", 0.18, -1.0]})

func _handle_remote_input(_delta: float) -> void:
	_apply_horizontal_movement(remote_input.move_x)
	
	if remote_input.jump:
		remote_input.jump = false
		jump()
	
	if remote_input.jump_release:
		remote_input.jump_release = false
		if velocity.y < 0.0:
			velocity.y *= 0.5

	if remote_input.drop:
		remote_input.drop = false
		drop_through()
	
	aim_direction = remote_input.aim
	
	if remote_input.dash:
		remote_input.dash = false
		dash()
	
	if remote_input.shoot:
		shoot()
	
	if remote_input.block:
		remote_input.block = false
		start_block()

	if remote_input.reload:
		remote_input.reload = false
		manual_reload()

	if remote_input.melee:
		remote_input.melee = false
		melee_attack()

	if remote_input.ability:
		remote_input.ability = false
		use_ability()

# Wird auf dem Client pro Snapshot aufgerufen. Es wird keine Physik simuliert.
func apply_network_state(data: Dictionary) -> void:
	if data.is_empty():
		visible = false
		_last_network_health = -1.0
		return
	
	visible = true
	net_target_pos = data.get("pos", net_target_pos)
	if global_position.distance_to(net_target_pos) > 250.0:
		global_position = net_target_pos
	
	velocity = data.get("vel", Vector2.ZERO)
	if data.get("fur") is Color and data.get("eyes") is Color and data.get("pants") is Color:
		sprite.setup(data["fur"], data["eyes"], data["pants"])
	if data.has("tusks"):
		sprite.set_tusk_shape(str(data["tusks"]))
	wand_tip_shape = str(data.get("wand_shape", wand_tip_shape))
	if data.get("wand_tip") is Color:
		wand_tip_color = data["wand_tip"]
	if data.get("shot") is Color:
		shot_color = data["shot"]
	_apply_wand_appearance()
	max_health = float(data.get("max_hp", max_health))
	armor_percent = clampf(float(data.get("armor", armor_percent)), 0.0, MAX_ARMOR_PERCENT)
	damage_reflect_percent = clampf(float(data.get("reflect", damage_reflect_percent)), 0.0, MAX_DAMAGE_REFLECT_PERCENT)

	# Die Trefferanimation kommt vom Host über NetFx ("pfx").
	var next_health := float(data.get("hp", current_health))
	_last_network_health = next_health
	current_health = next_health
	poison_ticks_left = int(data.get("poison", poison_ticks_left))
	max_shield = float(data.get("max_shield", max_shield))
	current_shield = float(data.get("shield", current_shield))
	max_ammo = int(data.get("max_ammo", max_ammo))
	current_ammo = int(data.get("ammo", current_ammo))
	ability_timer = float(data.get("ability", ability_timer))
	ability_max_cooldown = float(data.get("ability_max", ability_max_cooldown))
	is_reloading = bool(data.get("reload", is_reloading))
	reload_timer = float(data.get("reload_timer", reload_timer))
	reload_time = float(data.get("reload_time", reload_time))
	dash_cooldown_timer = float(data.get("dash_cd", dash_cooldown_timer))
	dash_cooldown = float(data.get("dash_cd_max", dash_cooldown))
	is_blocking = bool(data.get("blocking", is_blocking))
	block_cooldown_timer = float(data.get("block_cd", block_cooldown_timer))
	block_cooldown = float(data.get("block_cd_max", block_cooldown))
	melee_cooldown_timer = float(data.get("melee_cd", melee_cooldown_timer))
	melee_cooldown = float(data.get("melee_cd_max", melee_cooldown))
	# Neuer Nahkampfschlag seit dem letzten Snapshot: Animation nachspielen.
	# Der erste Snapshot übernimmt nur den Zähler.
	var net_melee_seq := int(data.get("melee_seq", _last_net_melee_seq))
	if _last_net_melee_seq >= 0 and net_melee_seq != _last_net_melee_seq:
		var swing_dir = data.get("melee_aim", aim_direction)
		if swing_dir is Vector2 and swing_dir.length_squared() > 0.001:
			melee_swing_dir = swing_dir.normalized()
		_play_melee_swing(Global.get_melee_weapon(player_index), melee_swing_dir)
	_last_net_melee_seq = net_melee_seq
	# Dash und Raketensprung laufen nur auf dem Host. Clients spielen
	# Geisterspur, Dash-Ton und Funken anhand der Zustände nach.
	var net_dash := bool(data.get("dash", false))
	if net_dash and not is_dashing:
		SoundManager.play_sound("dash", 0.12, 0.0)
		ghost_timer.start(0.04)
	is_dashing = net_dash
	is_leaping = bool(data.get("leap", false))
	powerup_invuln_timer = float(data.get("powerup_invuln", powerup_invuln_timer))
	powerup_damage_timer = float(data.get("powerup_damage", powerup_damage_timer))
	powerup_damage_mult = float(data.get("powerup_damage_mult", powerup_damage_mult))
	powerup_rapid_fire_timer = float(data.get("powerup_rapid", powerup_rapid_fire_timer))
	powerup_auto_attack_timer = float(data.get("powerup_auto", powerup_auto_attack_timer))
	powerup_multishot_timer = float(data.get("powerup_multi", powerup_multishot_timer))
	powerup_undying_timer = float(data.get("powerup_undying", powerup_undying_timer))
	powerup_revenge_timer = float(data.get("powerup_revenge", powerup_revenge_timer))
	powerup_invisible_timer = float(data.get("powerup_invis", powerup_invisible_timer))
	var net_revive := float(data.get("revive", 0.0))
	if (net_revive > 0.0) != (revive_timer > 0.0):
		_set_revive_visual(net_revive > 0.0)
	revive_timer = net_revive
	melee_range_mult = float(data.get("melee_rmult", melee_range_mult))
	if powerup_invuln_timer > 0.0:
		is_invulnerable = true
	elif not is_dashing and not is_leaping and ability_invuln_timer <= 0.0:
		is_invulnerable = false
	
	var aim_value = data.get("aim", aim_direction)
	if aim_value is Vector2 and aim_value.length_squared() > 0.001:
		aim_direction = aim_value.normalized()
	
	weapon_pivot.rotation = aim_direction.angle()
	if abs(weapon_pivot.rotation) > PI / 2.0:
		wand.set_flip_v(true)
		sprite.flip_h = true
	else:
		wand.set_flip_v(false)
		sprite.flip_h = false
	
	if shield_dome_node:
		shield_dome_node.visible = is_blocking
		if is_blocking:
			shield_dome_node.modulate = _block_dome_color()

	_refresh_poison_visual()
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	emit_signal("ammo_changed", current_ammo, max_ammo)
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	emit_signal("block_state_changed", is_blocking, block_cooldown_timer, block_cooldown)

func jump() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if is_on_floor():
		velocity.y = jump_force
		_fx("sound", {"snd": ["jump", 0.08, 0.0], "x": player_index})
	elif is_on_wall():
		# Wall Jump
		var normal = get_wall_normal()
		velocity.y = jump_force * 0.95
		velocity.x = normal.x * move_speed * 1.1
		_fx("sound", {"snd": ["jump", 0.08, 0.0], "x": player_index})
	elif jumps_remaining > 0:
		jumps_remaining -= 1
		velocity.y = jump_force * 0.9
		_fx("sound", {"snd": ["jump_air", 0.08, 0.0], "x": player_index})

## Lässt die Figur durch den Einweg-Steg fallen, auf dem sie steht. Liefert
## false, wenn sie nicht auf einem solchen Steg steht.
func drop_through() -> bool:
	if not control_enabled or stun_timer > 0.0 or not is_on_floor():
		return false
	var found := false
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var body := col.get_collider() as Node
		if body == null or not body.is_in_group("one_way_platform"):
			continue
		if col.get_normal().y > -0.5:
			continue
		if not _drop_through_bodies.has(body):
			add_collision_exception_with(body)
			_drop_through_bodies.append(body)
		found = true
	if found:
		_drop_through_timer = ONE_WAY_DROP_TIME
		velocity.y = maxf(velocity.y, 80.0)
		position.y += 2.0
	return found

func _update_drop_through(delta: float) -> void:
	if _drop_through_bodies.is_empty():
		return
	_drop_through_timer -= delta
	if _drop_through_timer > 0.0:
		return
	for body in _drop_through_bodies:
		if is_instance_valid(body):
			remove_collision_exception_with(body)
	_drop_through_bodies.clear()

func apply_jump_pad_boost(force: float) -> void:
	velocity.y = force
	jumps_remaining = max_jumps

func dash() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if dash_cooldown_timer > 0.0 or is_dashing:
		return
	is_dashing = true
	is_invulnerable = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	SoundManager.play_sound("dash", 0.12, 0.0)
	
	# Dash in aim or movement direction
	if velocity.x != 0:
		dash_dir = Vector2(signf(velocity.x), 0.0)
	else:
		dash_dir = aim_direction.normalized()
	
	ghost_timer.start(0.04)
	
	# Ignis Passive: Afterburner – Funken und eine brennende Spur während des Dashs.
	var hero_id: String = Global.get_player_hero_id(player_index)
	if hero_id == "ignis":
		afterburner_timer = 0.0
		if opponent and is_instance_valid(opponent):
			_spawn_fire_sparks()

# Kurzlebige visuelle Effekte werden an Main gehängt. Die Gruppe erlaubt es,
# beim Rundenstart auch diese Effekte zuverlässig zu entfernen.
func _add_round_effect(node: Node) -> void:
	node.add_to_group("round_effect")
	get_parent().add_child(node)

# Optik und Ton, die online auch alle Clients sehen (siehe NetFx).
func _fx(fx: String, args: Dictionary = {}) -> void:
	NetFx.emit(get_parent(), fx, args)

# Ton nur für den Besitzer dieses Ebers (z. B. Nachladen), online auch für
# einen Client-Spieler.
func _owner_sound(key: String, pitch_range: float, volume_db: float) -> void:
	if _is_local_human():
		SoundManager.play_sound(key, pitch_range, volume_db)
	elif is_remote:
		NetFx.send("sound", {"snd": [key, pitch_range, volume_db], "o": player_index})

# Host: Blitz-Effekt dieses Ebers auch auf Clients abspielen. Clients rufen
# dieselbe Funktion über play_network_player_fx() auf.
func _net_player_fx(method: String, params: Array = [], extra: Dictionary = {}) -> void:
	if is_replica or not Global.network_mode or not NetworkManager.is_host:
		return
	var args := {"s": player_index, "m": method, "a": params}
	args.merge(extra)
	NetFx.send("pfx", args)

func play_network_player_fx(method: String, params) -> void:
	if not is_replica or not NET_PLAYER_FX.has(method) or not (params is Array):
		return
	callv(method, params)

func _spawn_ghost_trail() -> void:
	if not is_dashing:
		ghost_timer.stop()
		return
	var ghost := PigModular.new()
	ghost.setup(sprite.fur_color, sprite.eye_color, sprite.pants_color)
	if sprite is PigModular:
		ghost.apply_parts((sprite as PigModular).get_parts())
	ghost.set_outfit(sprite.outfit_id)
	ghost.set_team_color(sprite.team_color)
	ghost.set_tusk_shape(sprite.tusk_shape)
	ghost.animate = false
	ghost.follow_parent_motion = false
	ghost.scale = sprite.scale * scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_add_round_effect(ghost)
	ghost.global_position = sprite.global_position
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)

func _apply_pig_appearance() -> void:
	if sprite == null:
		return
	var look := Global.get_pig_appearance(player_index)
	sprite.setup(look["fur"], look["eyes"], look["pants"])
	# Das Klassen-Outfit folgt dem Helden; die Helden-IDs werden mit der
	# Lobby an alle Clients synchronisiert.
	sprite.set_outfit(Global.get_player_hero_id(player_index))
	# In Team-Modi tragen Outfit und Lötkolbengriff die Teamfarbe, damit man
	# Mitspieler und Gegner sofort unterscheidet. team_id kommt aus dem
	# synchronisierten Spielmodus und ist auf Host und Clients gleich.
	sprite.set_team_color(_team_tint())
	sprite.set_tusk_shape(str(look.get("tusk_shape", "small")))
	# Baukasten-Teile (Körperform, Gesicht, Kleidung, Schwanz) kommen auf allen
	# Rechnern aus Global; Clients erhalten sie per Lobby-Sync.
	if sprite is PigModular:
		(sprite as PigModular).apply_parts(Global.get_pig_parts(player_index))
	wand_tip_shape = str(look["wand_tip_shape"])
	wand_tip_color = look["wand_tip_color"]
	shot_color = look["shot_color"]
	_apply_wand_appearance()

func _apply_wand_appearance() -> void:
	if wand != null and is_instance_valid(wand):
		wand.setup(wand_tip_shape, wand_tip_color)
		wand.set_grip_color(_team_tint())

# Teamfarbe für Outfit und Griff; transparent, wenn ohne Teams gespielt wird.
func _team_tint() -> Color:
	if not Global.is_team_mode():
		return Color(0.0, 0.0, 0.0, 0.0)
	return Global.get_team_color(team_id)

func _on_pig_appearance_changed(changed_index: int) -> void:
	if changed_index == player_index:
		_apply_pig_appearance()

func get_pig_colors() -> Dictionary:
	if sprite == null:
		return {}
	return {
		"fur": sprite.fur_color,
		"eyes": sprite.eye_color,
		"pants": sprite.pants_color,
		"tusk_shape": sprite.tusk_shape,
		"wand_tip_shape": wand_tip_shape,
		"wand_tip_color": wand_tip_color,
		"shot_color": shot_color,
	}

func shoot() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	var rapid_fire := powerup_rapid_fire_timer > 0.0
	if is_reloading and not rapid_fire:
		return
	if fire_timer > 0.0:
		return
	if current_ammo <= 0 and not rapid_fire:
		start_reload()
		return
	
	fire_timer = minf(0.09, fire_rate_cooldown) if rapid_fire else fire_rate_cooldown
	if not rapid_fire:
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, max_ammo)
	
	# Recoil Kickback
	var effective_damage := bullet_damage * powerup_damage_mult
	velocity -= aim_direction * (80.0 + effective_damage * 1.5)
	
	# Fire Projectiles (Base + Multishot)
	var total_bullets = 1 + multishot
	var spread_deg := spread_angle
	# Multishot-Powerup: zwei Projektile mehr, Fächer etwas breiter.
	if powerup_multishot_timer > 0.0:
		total_bullets += POWERUP_MULTISHOT_EXTRA
		spread_deg += POWERUP_MULTISHOT_SPREAD_DEG
	var base_angle = aim_direction.angle()
	var step_angle = deg_to_rad(spread_deg) / maxf(1.0, float(total_bullets - 1)) if total_bullets > 1 else 0.0
	var start_angle = base_angle - (deg_to_rad(spread_deg) / 2.0)
	
	for i in range(total_bullets):
		var angle = start_angle + (step_angle * i) if total_bullets > 1 else base_angle
		var dir = Vector2.from_angle(angle)
		_spawn_bullet(dir)
	
	_fx("sound", {"snd": ["shoot", 0.2, 0.0], "x": player_index})
	
	if current_ammo <= 0 and not rapid_fire:
		start_reload()

func _spawn_bullet(dir: Vector2) -> Bullet:
	var b: Bullet = bullet_scene.instantiate()
	b.global_position = muzzle.global_position
	b.velocity = dir * bullet_speed
	b.shooter = self
	b.target_enemy = _valid_opponent()
	b.damage = bullet_damage * powerup_damage_mult
	b.projectile_gravity_mult = projectile_gravity_mult
	b.bounces_left = bounces
	b.homing_strength = homing
	b.explosion_radius = explosion_radius
	b.poison_stacks = poison_stacks
	b.poison_damage = poison_damage_per_tick
	b.freeze_duration = freeze_duration
	b.lifesteal_percent = lifesteal_percent
	b.piercing_left = piercing
	b.wall_pierce_left = float(piercing)
	b.ricochet_bonus = ricochet_bonus
	b.border_bounce = border_bounce
	b.split_on_bounce = bounce_split
	b.can_hit_shooter = true
	b.stun_duration = 0.1 if lightning_shot else 0.0
	b.poison_impact_cloud = poison_impact_cloud
	b.frost_nova = frost_nova
	b.chain_lightning = chain_lightning
	b.lightning_zone = lightning_zone
	b.cluster_bomblets = cluster_bomblets
	b.fire_shot = fire_shot
	b.fire_impact_zone = fire_impact_zone
	b.burn_stacks = 3 if fire_shot else 0
	b.burn_damage = burn_damage_per_tick
	b.scale = Vector2(bullet_size, bullet_size)
	Global.add_match_stat(player_index, "shots_fired", 1.0)
	
	# Konfigurierbare Basis-Schussfarbe aus der Charakteranpassung.
	b.modulate = shot_color
	
	get_parent().add_child(b)
	return b

# Nur der Spieler, der an diesem Rechner spielt, hört seine eigenen Nachlade-Klicks.
func _is_local_human() -> bool:
	return not is_bot and not is_remote and not is_replica

func start_reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	reload_timer = reload_time
	# Der letzte Schuss wurde bereits signalisiert, bevor der Nachladezustand
	# aktiv war. Ein zweites Signal aktualisiert die HUD-Anzeige auf "NACHLADEN".
	emit_signal("ammo_changed", current_ammo, max_ammo)
	_owner_sound("reload", 0.05, 0.0)

# Manuelles Nachladen per Taste. Ein volles Magazin wird nicht nachgeladen.
func manual_reload() -> void:
	if not control_enabled or stun_timer > 0.0 or is_reloading:
		return
	if current_ammo >= max_ammo:
		return
	start_reload()

func use_ability() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if ability_timer > 0.0:
		return
	ability_timer = ability_max_cooldown
	emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	var hero_id: String = Global.get_player_hero_id(player_index)
	match hero_id:
		"ignis":
			# Rocket Leap: Explosiver Katapultflug mit AOE-Einschlag
			_fx("sound", {"snd": ["explosion", 0.2, 1.0]})
			is_leaping = true
			is_invulnerable = true
			leap_timer = ROCKET_LEAP_DURATION * ability_range_mult
			leap_dir = aim_direction.normalized()
			if leap_dir.length_squared() < 0.1:
				leap_dir = Vector2.UP
		"volt":
			# Flash Blink: Blitz-Teleport mit Schockwelle & BetÃƒÂ¤ubung
			_perform_flash_blink()
		"spore":
			# Toxic Gas Cloud: GroÃƒÅ¸e Giftwolke + 4 Sporen-Nadeln
			_fx("sound", {"snd": ["poison", 0.3, 0.0]})
			_spawn_spore_cloud()
		"nova":
			# SingularitÃƒÂ¤t: Gravitationskern, der Gegner heranzieht und schÃƒÂ¤digt
			_spawn_singularity()
		"klinge":
			# Klingensturm: Rundumschlag mit RÃƒÂ¼ckstoÃƒÅ¸ und kurzer Unverwundbarkeit
			_blade_storm()
		"bastion":
			# Heilfeld: Heilt ÃƒÂ¼ber Zeit und baut Schild auf
			_deploy_heal_field()
		"phantom":
			# Schattensprung: Teleport mit Treffer und kurzer Unverwundbarkeit
			_shadow_step()

	# Turm-Talent: Die SpezialfÃƒÂ¤higkeit platziert zusÃƒÂ¤tzlich einen Turm.
	if tower_enabled:
		_spawn_tower()

# ============================================================
# Nahkampfwaffe (Taste E)
# ============================================================

# Läuft nur dort, wo der Eber simuliert wird (Offline, Host). Clients sehen
# den Schlag über melee_seq im Snapshot.
# aim_override (Auto-Angriff) zielt auf einen Gegner statt auf den Zeiger.
func melee_attack(aim_override: Vector2 = Vector2.ZERO) -> void:
	if not control_enabled or stun_timer > 0.0 or is_replica or not Global.melee_enabled:
		return
	if melee_cooldown_timer > 0.0:
		return
	melee_cooldown_timer = melee_cooldown
	if powerup_auto_attack_timer > 0.0:
		melee_cooldown_timer *= POWERUP_AUTO_ATTACK_COOLDOWN_MULT
	var dir := aim_direction.normalized()
	if aim_override.length_squared() > 0.01:
		dir = aim_override.normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	melee_swing_dir = dir
	melee_swing_seq += 1
	_play_melee_swing(melee_weapon, dir)
	_melee_strike(dir, 1.0)
	if melee_echo:
		melee_echo_timer = MELEE_ECHO_DELAY
		melee_echo_dir = dir

# Ein einzelner Schlag. power skaliert Schaden und Rückstoß (Nachschlag < 1.0).
func _melee_strike(dir: Vector2, power: float) -> void:
	var data := Global.get_melee_weapon_data(melee_weapon)
	var base_damage := float(data["damage"]) * melee_damage_mult * powerup_damage_mult * power
	var knockback := float(data["knockback"]) * melee_knockback_mult * power
	var wall_stun := float(data["wall_stun"]) + melee_wall_stun_bonus
	var thrust := float(data["arc_deg"]) <= 0.0
	if melee_parry:
		_melee_parry(dir)
	_melee_hit_objects(dir, base_damage, knockback)
	_melee_hit_pinatas(dir, base_damage, knockback)
	var targets := _melee_targets(dir)
	var dealt := 0.0
	for p in targets:
		# Stich stößt in Stichrichtung, Bögen und Flegel radial vom Eber weg.
		var push: Vector2 = dir if thrust else (p.global_position - global_position).normalized()
		if push.length_squared() < 0.01:
			push = dir
		push = (push + Vector2(0.0, -MELEE_KNOCKBACK_LIFT)).normalized()
		var damage := base_damage
		# Gnadenstoß: Mehrschaden gegen angeschlagene Gegner.
		if melee_execute_bonus > 0.0 and p.max_health > 0.0 \
				and p.current_health / p.max_health <= MELEE_EXECUTE_THRESHOLD:
			damage *= 1.0 + melee_execute_bonus
		var was_blocking: bool = p.is_blocking
		var before: float = p.current_health + p.current_shield
		p.take_damage(damage, push * knockback, self)
		dealt += maxf(0.0, before - (maxf(p.current_health, 0.0) + p.current_shield))
		var landed: bool = not was_blocking and not p.is_invulnerable and p.current_health > 0.0
		if landed:
			if wall_stun > 0.0:
				p.melee_wall_stun_timer = MELEE_WALL_STUN_WINDOW
				p.melee_wall_stun_duration = wall_stun
			if melee_freeze > 0.0:
				p.apply_freeze(melee_freeze)
			if melee_poison_stacks > 0:
				p.apply_poison(melee_poison_stacks, poison_damage_per_tick)
			if melee_burn_stacks > 0:
				p.apply_burn(melee_burn_stacks, burn_damage_per_tick)
			if melee_stun > 0.0:
				p.apply_stun(melee_stun)
		_spawn_blade_hit_spark(p.global_position)
	if melee_chain_lightning and not targets.is_empty():
		dealt += _melee_chain_lightning(targets, base_damage * MELEE_CHAIN_DAMAGE_MULT)
	# Match-Statistik: tatsächlich angekommener Nahkampfschaden (inkl. Kettenblitz).
	if dealt > 0.0:
		Global.add_match_stat(player_index, "melee_damage", dealt)
	if not targets.is_empty():
		Global.add_match_stat(player_index, "melee_hits", float(targets.size()))
	if dealt > 0.0 and melee_lifesteal > 0.0:
		heal(dealt * melee_lifesteal)
	if not targets.is_empty():
		_fx("sound", {"snd": ["hit", 0.15, 0.0], "shake": clampf(base_damage * 0.006, 0.08, 0.3)})

# Hochspannung: vom ersten Treffer springt ein Blitz auf den nächsten weiteren Gegner.
func _melee_chain_lightning(hit_targets: Array, damage: float) -> float:
	var origin: Node2D = hit_targets[0]
	if not is_instance_valid(origin):
		return 0.0
	var best: Player = null
	var best_dist := MELEE_CHAIN_RADIUS
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Player) or p == self or hit_targets.has(p) or not is_instance_valid(p):
			continue
		if p.team_id == team_id or p.current_health <= 0.0 or not p.visible:
			continue
		var d: float = origin.global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	if best == null:
		return 0.0
	var before := best.current_health + best.current_shield
	best.take_damage(damage, Vector2.ZERO, self)
	best.apply_stun(maxf(0.15, melee_stun))
	_spawn_lightning_arc(origin.global_position, best.global_position)
	return maxf(0.0, before - (maxf(best.current_health, 0.0) + best.current_shield))

# Parade: gegnerische Projektile im Schlagbereich fliegen zurück wie beim Block.
func _melee_parry(dir: Vector2) -> void:
	var reach := _melee_reach_px()
	var half_arc := deg_to_rad(_melee_arc_deg()) * 0.5
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.shooter == self:
			continue
		if is_instance_valid(b.shooter) and b.shooter is Player and b.shooter.team_id == team_id:
			continue
		var to_b: Vector2 = b.global_position - global_position
		if to_b.length() > reach:
			continue
		if half_arc < PI and absf(dir.angle_to(to_b)) > maxf(half_arc, deg_to_rad(30.0)):
			continue
		b.shooter = self
		b.target_enemy = _valid_opponent()
		b.velocity = dir * maxf(b.velocity.length(), bullet_speed) * 1.2
		b.modulate = Color(1.0, 0.75, 0.4)
		_fx("sound", {"snd": ["bounce", 0.3, 3.0]})

# Parade (automatisch): Richtung zum nächsten gegnerischen Projektil, das in
# Schlagreichweite ist und auf den Eber zufliegt. ZERO = nichts zu parieren.
func _melee_parry_target_dir() -> Vector2:
	var reach := _melee_reach_px()
	var best_dir := Vector2.ZERO
	var best_dist := INF
	for b in get_tree().get_nodes_in_group("bullet"):
		if not is_instance_valid(b) or b.shooter == self:
			continue
		if is_instance_valid(b.shooter) and b.shooter is Player and b.shooter.team_id == team_id:
			continue
		var to_b: Vector2 = b.global_position - global_position
		var dist := to_b.length()
		if dist > reach or dist >= best_dist:
			continue
		# Nur Projektile, die sich nähern (wegfliegende ignorieren).
		if b.velocity.dot(-to_b) <= 0.0:
			continue
		best_dist = dist
		best_dir = to_b
	return best_dir

# Kisten, Fässer, zerstörbare Blöcke, Ranken, Herz-Blöcke und gegnerische
# Türme im Schlagbereich bekommen einen Treffer wie von einem Projektil.
func _melee_hit_objects(dir: Vector2, damage: float, knockback: float) -> void:
	var reach := _melee_reach_px()
	var arc_deg := _melee_arc_deg()
	var half_arc := deg_to_rad(arc_deg) * 0.5
	var thrust := arc_deg <= 0.0
	var thrust_half_width := _melee_thrust_half_width()
	var space := get_world_2d().direct_space_state
	var circle := CircleShape2D.new()
	# Halbes Feld Zuschlag, damit Objekte am Rand der Reichweite noch zählen.
	circle.radius = reach + MELEE_OBJECT_SLACK
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1 | Companion.TOWER_COLLISION_LAYER
	query.exclude = [get_rid()]
	var proxy := MeleeHitProxy.new()
	proxy.shooter = self
	proxy.velocity = dir * 600.0
	proxy.damage = damage
	var done: Array = []
	for hit in space.intersect_shape(query, 64):
		var obj = hit.get("collider")
		if obj == null or not is_instance_valid(obj) or done.has(obj):
			continue
		if not (obj.has_method("hit_tile") or obj.has_method("hit_crate") or obj.has_method("hit_barrel") \
				or obj.has_method("hit_block") or obj.has_method("take_tower_damage")):
			continue
		var to_obj: Vector2 = obj.global_position - global_position
		if thrust:
			var along := to_obj.dot(dir)
			if along < -MELEE_OBJECT_SLACK or along > reach + MELEE_OBJECT_SLACK \
					or absf(to_obj.cross(dir)) > thrust_half_width + MELEE_OBJECT_SLACK:
				continue
		else:
			if to_obj.length() > reach + MELEE_OBJECT_SLACK:
				continue
			if half_arc < PI and to_obj.length() > MELEE_OBJECT_SLACK * 2.0:
				var slack := atan2(MELEE_OBJECT_SLACK, maxf(1.0, to_obj.length()))
				if absf(dir.angle_to(to_obj)) > half_arc + slack:
					continue
		# Nur das vorderste Objekt: Was hinter einer Wand oder einem anderen
		# Block liegt, wird nicht getroffen.
		var ray := PhysicsRayQueryParameters2D.create(global_position, obj.global_position, 1)
		ray.exclude = [get_rid(), obj.get_rid()]
		if not space.intersect_ray(ray).is_empty():
			continue
		done.append(obj)
		if obj.has_method("hit_tile"):
			obj.hit_tile(damage)
		elif obj.has_method("hit_crate"):
			obj.hit_crate(proxy)
			if obj is RigidBody2D:
				obj.apply_impulse(to_obj.normalized() * knockback * 0.25 + Vector2(0.0, -60.0), Vector2.ZERO)
		elif obj.has_method("hit_barrel"):
			proxy.velocity = to_obj.normalized() * 600.0
			obj.hit_barrel(proxy)
			if obj is RigidBody2D:
				obj.apply_impulse(to_obj.normalized() * knockback * 0.25, Vector2.ZERO)
		elif obj.has_method("hit_block"):
			obj.hit_block(self)
		elif obj.has_method("take_tower_damage"):
			obj.take_tower_damage(damage, self)
		_spawn_blade_hit_spark(obj.global_position)
	proxy.free()

# Reichweite des Schlags ab dem eigenen Mittelpunkt (ohne Zielradius).
func _melee_reach_px() -> float:
	var data := Global.get_melee_weapon_data(melee_weapon)
	return MELEE_BODY_RADIUS * scale.x \
		+ (float(data["range_tiles"]) + melee_range_bonus) * melee_range_mult * Global.MELEE_TILE_SIZE \
		* _melee_size_factor()

# Größere Eber (Karten, Mini-Chaos) schlagen weiter, kleinere kürzer.
# 1.0 bei normaler Größe (BASE_CHARACTER_SCALE).
func _melee_size_factor() -> float:
	return maxf(0.1, scale.x / BASE_CHARACTER_SCALE)

func _melee_thrust_half_width() -> float:
	return (MELEE_THRUST_HALF_WIDTH + melee_arc_bonus * 0.4) * _melee_size_factor()

# Voller Schlagbogen in Grad; 0 = Stich.
func _melee_arc_deg() -> float:
	var arc := float(Global.get_melee_weapon_data(melee_weapon)["arc_deg"])
	if arc <= 0.0:
		return 0.0
	return minf(360.0, arc + melee_arc_bonus)

# Alle gegnerischen Eber, die Reichweite und Winkel der Waffe treffen und
# nicht hinter einer Wand stehen.
func _melee_targets(dir: Vector2) -> Array:
	var result: Array = []
	var arc_deg := _melee_arc_deg()
	var half_arc := deg_to_rad(arc_deg) * 0.5
	var thrust := arc_deg <= 0.0
	# Breiter Schwung verbreitert beim Stich den Stoßkanal.
	var thrust_half_width := _melee_thrust_half_width()
	var own_radius := MELEE_BODY_RADIUS * scale.x
	var own_reach := _melee_reach_px()
	var space := get_world_2d().direct_space_state
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p) or p.current_health <= 0.0 or not p.visible:
			continue
		if p.team_id == team_id:
			continue
		var target_radius: float = MELEE_BODY_RADIUS * p.scale.x
		if not _melee_zone_contains(dir, p.global_position - global_position, target_radius,
				own_reach, half_arc, thrust, thrust_half_width, own_radius):
			continue
		# Wände blockieren den Schlag.
		var query := PhysicsRayQueryParameters2D.create(global_position, p.global_position, 1)
		query.exclude = [get_rid(), p.get_rid()]
		if not space.intersect_ray(query).is_empty():
			continue
		result.append(p)
	return result

# Liegt ein Ziel (Abstand to_target, Radius target_radius) in der Schlagfläche?
func _melee_zone_contains(dir: Vector2, to_target: Vector2, target_radius: float, own_reach: float,
		half_arc: float, thrust: bool, thrust_half_width: float, own_radius: float) -> bool:
	var reach := own_reach + target_radius
	if thrust:
		# Gerader Stich: entlang der Zielrichtung, schmaler Streifen.
		var along := to_target.dot(dir)
		var side := absf(to_target.cross(dir))
		return along >= -target_radius and along <= reach and side <= thrust_half_width + target_radius
	if to_target.length() > reach:
		return false
	# Sehr nahe Ziele zählen immer, sonst entscheidet der Winkel.
	if half_arc < PI and to_target.length() > own_radius + target_radius:
		# Der Körperradius verbreitert den Winkel etwas, damit Treffer am
		# Bogenrand nicht vom Mittelpunkt abhängen.
		var slack := atan2(target_radius, maxf(1.0, to_target.length()))
		if absf(dir.angle_to(to_target)) > half_arc + slack:
			return false
	return true

# Piñata-Lama (Modifier): bekommt Nahkampfschaden wie von einem Schuss,
# zählt damit auch für die Extrakarte. Wände blockieren wie bei Ebern.
func _melee_hit_pinatas(dir: Vector2, damage: float, knockback: float) -> void:
	var arc_deg := _melee_arc_deg()
	var thrust := arc_deg <= 0.0
	var own_reach := _melee_reach_px()
	var own_radius := MELEE_BODY_RADIUS * scale.x
	var space := get_world_2d().direct_space_state
	for lama in get_tree().get_nodes_in_group("pinata"):
		if not is_instance_valid(lama) or not lama.visible or not lama.has_method("take_damage"):
			continue
		var center: Vector2 = lama.get_hit_center() if lama.has_method("get_hit_center") else lama.global_position
		var to_target := center - global_position
		if not _melee_zone_contains(dir, to_target, PINATA_HIT_RADIUS, own_reach,
				deg_to_rad(arc_deg) * 0.5, thrust, _melee_thrust_half_width(), own_radius):
			continue
		var query := PhysicsRayQueryParameters2D.create(global_position, center, 1)
		query.exclude = [get_rid(), lama.get_rid()]
		if not space.intersect_ray(query).is_empty():
			continue
		var push: Vector2 = dir if thrust else to_target.normalized()
		if push.length_squared() < 0.01:
			push = dir
		push = (push + Vector2(0.0, -MELEE_KNOCKBACK_LIFT)).normalized()
		lama.take_damage(damage, push * knockback, self)
		_spawn_blade_hit_spark(center)

# Reichweite bis zum Mittelpunkt eines Gegners (für Bots).
func get_melee_reach() -> float:
	return _melee_reach_px() + MELEE_BODY_RADIUS * scale.x

# Auto-Angriff-Powerup: nächster Gegner in Reichweite mit freier Sicht.
# Bogen und Zeiger spielen keine Rolle, geschlagen wird in seine Richtung.
func _melee_auto_target_dir() -> Vector2:
	var best_dir := Vector2.ZERO
	var best_dist := INF
	var own_reach := _melee_reach_px()
	var space := get_world_2d().direct_space_state
	for p in get_tree().get_nodes_in_group("player"):
		# Auto-Angriff zielt nicht auf Unsichtbare (Powerup).
		if p == self or not is_instance_valid(p) or p.current_health <= 0.0 or not p.visible or p.is_invisible():
			continue
		if p.team_id == team_id:
			continue
		var to_target: Vector2 = p.global_position - global_position
		var dist := to_target.length()
		if dist > own_reach + MELEE_BODY_RADIUS * p.scale.x or dist >= best_dist:
			continue
		var query := PhysicsRayQueryParameters2D.create(global_position, p.global_position, 1)
		query.exclude = [get_rid(), p.get_rid()]
		if not space.intersect_ray(query).is_empty():
			continue
		best_dist = dist
		best_dir = to_target
	return best_dir

func _play_melee_swing(weapon_id: String, dir: Vector2) -> void:
	if not is_inside_tree():
		return
	var fx = MELEE_SWING_SCRIPT.new()
	fx.weapon = Global.normalize_melee_weapon(weapon_id)
	fx.direction = dir
	fx.reach = _melee_reach_px()
	fx.arc_deg = _melee_arc_deg()
	fx.thrust_half_width = _melee_thrust_half_width()
	fx.glow_color = wand_tip_color
	fx.follow = self
	_add_round_effect(fx)
	fx.global_position = global_position
	SoundManager.play_sound("slash", 0.15, -2.0 if weapon_id == "hammer" else 0.0)
	# Der gehaltene Lötkolben verschwindet, solange die Waffe schwingt.
	if wand != null and is_instance_valid(wand):
		wand.visible = false
		var tw := create_tween()
		tw.tween_interval(fx.duration)
		tw.tween_callback(func():
			if is_instance_valid(wand):
				wand.visible = true
		)

# Hammer: Wer kurz nach dem Treffer gegen eine Wand oder Decke prallt, ist betäubt.
func _check_melee_wall_stun() -> void:
	if melee_wall_stun_timer <= 0.0:
		return
	if not (is_on_wall() or is_on_ceiling()):
		return
	melee_wall_stun_timer = 0.0
	apply_stun(melee_wall_stun_duration)
	velocity.x *= -0.15
	_fx("sound", {"snd": ["bounce", 0.1, -3.0], "shake": 0.2})
	_spawn_blade_hit_spark(global_position)

# ============================================================
# Standard-Block (Taste Q)
# ============================================================

func start_block() -> void:
	if not control_enabled or stun_timer > 0.0:
		return
	if is_blocking or block_cooldown_timer > 0.0:
		return

	is_blocking = true
	block_timer = block_duration
	block_cooldown_timer = 0.0
	block_cd_display_tenths = -1
	if shield_dome_node:
		shield_dome_node.modulate = _block_dome_color()
		shield_dome_node.visible = true
	_fx("sound", {"snd": ["shield", 0.2, 0.0]})
	_trigger_block_effects()
	emit_signal("block_state_changed", true, block_cooldown_timer, block_cooldown)

func _end_block() -> void:
	is_blocking = false
	block_timer = 0.0
	# Der Cooldown beginnt erst nach dem Block, nicht schon beim Aktivieren.
	block_cooldown_timer = block_cooldown
	block_cd_display_tenths = -1
	if shield_dome_node:
		shield_dome_node.visible = false
	emit_signal("block_state_changed", false, block_cooldown_timer, block_cooldown)

# Karten-Effekte, die beim Aktivieren des Blocks ausgelÃƒÂ¶st werden.
func _trigger_block_effects() -> void:
	if block_knockback_radius > 0.0 and block_knockback_force > 0.0:
		for p in _opponents_within(global_position, block_knockback_radius):
			var dir: Vector2 = (p.global_position - global_position).normalized()
			p.apply_knockback(dir * block_knockback_force)
	if block_bomb:
		_spawn_block_bomb()
	if block_heal_zone:
		_spawn_block_heal_zone()
	if block_mine:
		_spawn_block_mine()

# Minenleger: Mine fällt vom Spieler zu Boden. Nur der Host simuliert sie,
# Clients bekommen sie über den Snapshot.
func _spawn_block_mine() -> void:
	if is_replica or get_parent() == null:
		return
	var own: Array = []
	for m in get_tree().get_nodes_in_group("block_mine"):
		if is_instance_valid(m) and not m.is_queued_for_deletion() and m.owner_player == self:
			own.append(m)
	# Älteste Minen verschwinden, damit niemand das Feld zupflastert.
	while own.size() >= BLOCK_MINE_MAX_ACTIVE:
		own.pop_front().discard()
	var mine := BlockMine.new()
	mine.setup(self, block_mine_damage, block_mine_radius, block_mine_instant)
	mine.position = global_position
	get_parent().add_child(mine)
	mine.global_position = global_position

func _spawn_block_bomb() -> void:
	_fx("ring", NetFx.with_sound(NetFx.ring_args(global_position, Color(1.0, 0.55, 0.15, 0.9),
		1.0, 7.0, 0.25, 0.3), "explosion", 0.2, 1.0))
	Seesaw.blast_all(get_tree(), global_position, 130.0, 1.0)
	for p in _opponents_within(global_position, 130.0):
		var dir: Vector2 = (p.global_position - global_position).normalized()
		p.take_damage(block_bomb_damage, dir * 480.0, self)

func _spawn_block_heal_zone() -> void:
	block_heal_pos = global_position
	block_heal_timer = 2.5
	block_heal_tick = 0.0
	# Radius entspricht der Heilreichweite (110) im Block-Heil-Tick.
	spawn_effect_zone(EffectZone.Kind.HEAL, block_heal_pos, 110.0, block_heal_timer, {"visual_only": true})

# Wird auch von Rückstoß-Karten genutzt; ein aktiver Block dämpft den Stoß.
func apply_knockback(force: Vector2) -> void:
	if is_blocking:
		force *= 0.2
	if force.length_squared() > 1.0:
		var control_time := clampf(
			force.length() / KNOCKBACK_TIMER_FORCE_DIVISOR,
			KNOCKBACK_TIMER_MIN,
			KNOCKBACK_TIMER_MAX
		)
		knockback_timer = maxf(knockback_timer, control_time)
	velocity += force

func _block_dome_color() -> Color:
	if block_reflect_damage_add > 0.0:
		return Color(0.75, 0.45, 1.0, 0.75)
	if block_bomb:
		return Color(1.0, 0.55, 0.2, 0.75)
	if block_knockback_radius > 0.0:
		return Color(0.4, 0.9, 1.0, 0.75)
	return Color(0.3, 0.8, 1.0, 0.7)

# shake > 0: Clients wackeln mit der Kamera wie der Host.
func _pulse_block_shield(shake: float = 0.0) -> void:
	_net_player_fx("_pulse_block_shield", [], {"shake": shake})
	SoundManager.play_sound("bounce", 0.2, 2.0)
	if shield_dome_node:
		var base_color := _block_dome_color()
		var tw := create_tween()
		tw.tween_property(shield_dome_node, "modulate", Color(2.0, 2.0, 2.0, 0.95), 0.05)
		tw.tween_property(shield_dome_node, "modulate", base_color, 0.1)

# Liefert nur einen gÃƒÂ¼ltigen, lebenden Gegner. Verhindert Zuweisungen an
# bereits freigegebene Player-Objekte (z. B. nach einem Tod).
func _valid_opponent() -> Player:
	if is_instance_valid(opponent) and opponent.current_health > 0.0 and opponent.team_id != team_id:
		return opponent
	return null

func _trigger_rocket_impact() -> void:
	var radius := ROCKET_IMPACT_RADIUS * ability_radius_mult
	_fx("ring", NetFx.with_sound(NetFx.ring_args(global_position, Color(1.0, 0.4, 0.1, 0.9),
		1.0, 9.0 * ability_radius_mult, 0.3, 0.3), "explosion", 0.2, -2.0))
	Seesaw.blast_all(get_tree(), global_position, radius, 1.4)

	if opponent and is_instance_valid(opponent):
		for p in _opponents_within(global_position, radius):
			var dist = global_position.distance_to(p.global_position)
			var falloff = 1.0 - (dist / radius)
			_ability_hit(p, ROCKET_IMPACT_DAMAGE * ability_damage_mult * falloff, (p.global_position - global_position).normalized() * ROCKET_IMPACT_KNOCKBACK)

	# Evolution "Napalm-Landung": große Feuerfläche am Einschlagsort.
	if _has_ability_evolution("ignis_napalm"):
		spawn_effect_zone(EffectZone.Kind.FIRE, global_position, IGNIS_NAPALM_RADIUS * ability_radius_mult, IGNIS_NAPALM_DURATION * ability_duration_mult, {
			"tick_interval": 0.45,
			"burn_stacks": 2,
			"burn_damage": burn_damage_per_tick * ability_damage_mult,
		})
	# Evolution "Splitterlandung": Splitterbomben fliegen in alle Richtungen.
	if _has_ability_evolution("ignis_splitter"):
		spawn_cluster_bomblets(global_position, true)

func _perform_flash_blink() -> void:
	var start_pos = global_position
	var target_pos = _free_teleport_target(start_pos, _clamp_to_map(global_position + (aim_direction.normalized() * FLASH_BLINK_DISTANCE * ability_range_mult)))
	var radius := FLASH_BLINK_RADIUS * ability_radius_mult

	_fx("zap", NetFx.with_sound(NetFx.zap_args(start_pos, target_pos, Color(1.0, 1.0, 0.3, 0.9),
		4.0, 0.2, 2, 15.0), "teleport", 0.1, 0.0))

	global_position = target_pos
	velocity = Vector2.ZERO

	_fx("ring", NetFx.ring_args(target_pos, Color(1.0, 1.0, 0.2, 0.9),
		1.0, 7.0 * ability_radius_mult, 0.25, 0.25))

	Seesaw.blast_all(get_tree(), target_pos, radius, 1.0)
	var chain := _has_ability_evolution("volt_chain")
	for p in _opponents_within(target_pos, radius):
		_ability_hit(p, FLASH_BLINK_DAMAGE * ability_damage_mult, (p.global_position - target_pos).normalized() * FLASH_BLINK_KNOCKBACK)
		p.apply_freeze(FLASH_BLINK_FREEZE * ability_duration_mult)
		# Evolution "Kettenblink": jeder Treffer springt als Kettenblitz weiter.
		if chain:
			dealing_ability_damage = true
			trigger_chain_lightning(p, target_pos)
			dealing_ability_damage = false
	# Evolution "Gewitterspur": Start- und Zielpunkt werden zu Blitzzonen.
	if _has_ability_evolution("volt_storm"):
		spawn_lightning_zone(start_pos, true)
		spawn_lightning_zone(target_pos, true)

func _spawn_fire_sparks() -> void:
	var spark = Sprite2D.new()
	spark.texture = EFFECT_CIRCLE_TEXTURE
	spark.modulate = Color(1.0, 0.4, 0.1, 0.8)
	_add_round_effect(spark)
	spark.global_position = global_position
	var tw = spark.create_tween()
	tw.tween_property(spark, "scale", Vector2(2.0, 2.0), 0.3)
	tw.parallel().tween_property(spark, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spark.queue_free)

func _spawn_spore_cloud() -> void:
	var radius := SPORE_CLOUD_RADIUS * ability_radius_mult
	var duration := SPORE_CLOUD_DURATION * ability_duration_mult
	var dps := SPORE_CLOUD_DPS * ability_damage_mult
	var corrosive := _has_ability_evolution("spore_corrosive")
	var symbiosis := _has_ability_evolution("spore_symbiosis")
	var cloud = Area2D.new()
	cloud.collision_layer = 4
	cloud.collision_mask = 2
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	cloud.add_child(col)

	_add_round_effect(cloud)
	cloud.global_position = global_position
	# Wolken-Optik als Zone, damit sie auch auf Clients erscheint.
	spawn_effect_zone(EffectZone.Kind.POISON, global_position, radius, duration, {"visual_only": true})

	# Schaden pro Sekunde statt pro Frame, damit er nicht von der Bildrate abhängt.
	# progress[1] zählt bis zum nächsten Gift-Tick von "Ätzender Nebel".
	var progress := [0.0, 0.0]
	var t = cloud.create_tween()
	t.tween_method(func(val: float):
		var dt: float = (val - progress[0]) * duration
		progress[0] = val
		if dt <= 0.0:
			return
		var poison_now := false
		if corrosive:
			progress[1] -= dt
			if progress[1] <= 0.0:
				progress[1] = SPORE_CORROSIVE_INTERVAL
				poison_now = true
		for p in _opponents_within(cloud.global_position, radius):
			_ability_hit(p, dps * dt, Vector2.ZERO)
			if poison_now:
				p.apply_poison(SPORE_CORROSIVE_STACKS, poison_damage_per_tick * ability_damage_mult)
		# Evolution "Symbiose": Spore heilt sich in der eigenen Wolke.
		if symbiosis and current_health > 0.0 and global_position.distance_to(cloud.global_position) <= radius:
			heal(SPORE_SYMBIOSIS_HPS * dt)
	, 0.0, 1.0, duration)
	t.tween_callback(cloud.queue_free)

# Liefert alle lebenden Gegner im Umkreis. Wichtig fÃƒÂ¼r FFA-Runden mit bis zu 6
# Spielern, damit FlÃƒÂ¤chenfÃƒÂ¤higkeiten nicht nur den ersten Gegner treffen.
func _opponents_within(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p) or p.current_health <= 0.0:
			continue
		if p.team_id == team_id:
			continue
		if pos.distance_to(p.global_position) <= radius:
			result.append(p)
	return result

# --- Nova: SingularitÃƒÂ¤t ---
func _spawn_singularity() -> void:
	_fx("sound", {"snd": ["explosion", 0.2, 2.0]})
	var aim := aim_direction.normalized()
	var center := _clamp_to_map(global_position + aim * SINGULARITY_DISTANCE * ability_range_mult)
	# Evolution "Doppelstern": zwei Singularitäten nebeneinander statt einer.
	if _has_ability_evolution("nova_binary"):
		var side := aim.orthogonal()
		if side.length_squared() < 0.01:
			side = Vector2.RIGHT
		_add_gravity_well(_clamp_to_map(center + side * NOVA_BINARY_OFFSET))
		_add_gravity_well(_clamp_to_map(center - side * NOVA_BINARY_OFFSET))
	else:
		_add_gravity_well(center)

func _add_gravity_well(center: Vector2) -> void:
	var duration := SINGULARITY_DURATION * ability_duration_mult
	# Schwarzes Loch als reine Optik-Zone, damit es auch Clients sehen.
	spawn_effect_zone(EffectZone.Kind.VOID, center, 60.0 * ability_radius_mult, duration, {"visual_only": true})
	gravity_wells.append({"pos": center, "time": duration, "tick": 0.0})

# --- Klinge: Klingensturm ---
func _blade_storm() -> void:
	is_invulnerable = true
	ability_invuln_timer = maxf(ability_invuln_timer, BLADE_STORM_INVULN * ability_duration_mult)
	_blade_storm_strike(1.0)
	# Evolution "Echowirbel": ein zweiter, schwächerer Wirbel folgt kurz danach.
	if _has_ability_evolution("klinge_echo"):
		blade_echo_timer = BLADE_ECHO_DELAY

# Ein einzelner Wirbel. power skaliert Schaden und Rückstoß (Echowirbel < 1.0).
func _blade_storm_strike(power: float) -> void:
	_fx("blade_storm", {
		"p": global_position,
		"r": BLADE_STORM_RADIUS,
		"rm": ability_radius_mult,
		"snd": ["slash", 0.15, 0.0],
		"shake": 0.22 * power,
	})
	Seesaw.blast_all(get_tree(), global_position, BLADE_STORM_RADIUS * ability_radius_mult, 0.8 * power)

	var hit_any := false
	var dealt := 0.0
	for p in _opponents_within(global_position, BLADE_STORM_RADIUS * ability_radius_mult):
		hit_any = true
		var dir: Vector2 = p.global_position - global_position
		if dir.length_squared() < 1.0:
			dir = aim_direction if aim_direction.length_squared() > 0.01 else Vector2.RIGHT
		var before: float = p.current_health + p.current_shield
		_ability_hit(
			p,
			bullet_damage * BLADE_STORM_DAMAGE_MULT * ability_damage_mult * power,
			dir.normalized() * BLADE_STORM_KNOCKBACK * power
		)
		dealt += maxf(0.0, before - (p.current_health + p.current_shield))
		_spawn_blade_hit_spark(p.global_position)
	# Evolution "Blutrausch": heilt um einen Teil des tatsächlich verursachten Schadens.
	if dealt > 0.0 and _has_ability_evolution("klinge_bloodlust"):
		heal(dealt * BLADE_BLOODLUST_HEAL)
	# Auch ohne Treffer bleibt der Wirbel sichtbar; ein leiser Bounce-Ton
	# bestätigt, dass die Fähigkeit ausgelöst wurde.
	if not hit_any:
		_fx("sound", {"snd": ["bounce", 0.15, 4.0]})

func _spawn_blade_hit_spark(pos: Vector2) -> void:
	_fx("ring", NetFx.ring_args(pos, Color(1.0, 0.8, 0.9, 0.95), 0.7, 3.6, 0.2, 0.2, 8, true))

# --- Bastion: Heilfeld ---
func _deploy_heal_field() -> void:
	_fx("sound", {"snd": ["heal", 0.05, 0.0]})
	var duration := HEAL_FIELD_DURATION * ability_duration_mult
	heal_field_timer = duration
	heal_field_tick = 0.0
	heal_field_pos = global_position
	spawn_effect_zone(EffectZone.Kind.HEAL, global_position, 55.0 * ability_radius_mult, duration, {"visual_only": true})

# --- Phantom: Schattensprung ---
func _shadow_step() -> void:
	var start := global_position
	var target := _free_teleport_target(start, _clamp_to_map(global_position + aim_direction.normalized() * SHADOW_STEP_DISTANCE * ability_range_mult))
	var radius := SHADOW_STEP_RADIUS * ability_radius_mult
	_fx("zap", NetFx.with_sound(NetFx.zap_args(start, target, Color(0.45, 0.45, 0.65, 0.7),
		6.0, 0.25), "teleport", 0.06, -1.0))
	global_position = target
	velocity = Vector2.ZERO
	is_invulnerable = true
	ability_invuln_timer = maxf(ability_invuln_timer, SHADOW_STEP_INVULN * ability_duration_mult)

	Seesaw.blast_all(get_tree(), target, radius, 0.7)
	var victims := _opponents_within(target, radius)
	# Evolution "Schattenschnitt": trifft auch alle Gegner entlang der Sprungbahn.
	if _has_ability_evolution("phantom_cut"):
		var cut_width := PHANTOM_CUT_WIDTH * ability_radius_mult
		var mid := start.lerp(target, 0.5)
		for p in _opponents_within(mid, start.distance_to(target) * 0.5 + cut_width):
			if victims.has(p):
				continue
			var closest := Geometry2D.get_closest_point_to_segment(p.global_position, start, target)
			if closest.distance_to(p.global_position) <= cut_width:
				victims.append(p)
	var stun := _has_ability_evolution("phantom_mark")
	for p in victims:
		_ability_hit(p, bullet_damage * SHADOW_STEP_DAMAGE_MULT * ability_damage_mult, (p.global_position - target).normalized() * SHADOW_STEP_KNOCKBACK)
		# Evolution "Lähmendes Mal": getroffene Gegner werden betäubt.
		if stun:
			p.apply_stun(PHANTOM_MARK_STUN * ability_duration_mult)

# Treffer der Heldenfähigkeit: zählt zusätzlich als "ability_damage", damit die
# Statistik den Anteil der Fähigkeit am eigenen Schaden zeigen kann.
func _ability_hit(target, amount: float, knockback: Vector2) -> void:
	dealing_ability_damage = true
	target.take_damage(amount, knockback, self)
	dealing_ability_damage = false

func _has_ability_evolution(evolution_id: String) -> bool:
	return ability_evolutions.has(evolution_id)

# --- Nova-Evolution "Implosion": die Singularität kollabiert am Ende ---
func _nova_implosion(pos: Vector2) -> void:
	var radius := NOVA_IMPLOSION_RADIUS * ability_radius_mult
	_fx("ring", NetFx.with_sound(NetFx.ring_args(pos, Color(0.85, 0.65, 1.0, 0.9),
		1.0, radius / 8.0, 0.25, 0.3), "explosion", 0.25, 0.0))
	Seesaw.blast_all(get_tree(), pos, radius, 1.2)
	for p in _opponents_within(pos, radius):
		var dir: Vector2 = p.global_position - pos
		if dir.length_squared() < 1.0:
			dir = Vector2.UP
		_ability_hit(p, NOVA_IMPLOSION_DAMAGE * ability_damage_mult, dir.normalized() * NOVA_IMPLOSION_KNOCKBACK)

# --- Bastion-Evolution "Pulsfeld": Schadenspuls am Ort des Heilfelds ---
func _bastion_pulse() -> void:
	var radius := BASTION_PULSE_RADIUS * ability_radius_mult
	_fx("ring", NetFx.ring_args(heal_field_pos, Color(0.3, 0.95, 0.7, 0.55),
		1.0, radius / 8.0, 0.3, 0.35))
	Seesaw.blast_all(get_tree(), heal_field_pos, radius, 0.8)
	for p in _opponents_within(heal_field_pos, radius):
		var dir: Vector2 = p.global_position - heal_field_pos
		if dir.length_squared() < 1.0:
			dir = Vector2.UP
		_ability_hit(p, BASTION_PULSE_DAMAGE * ability_damage_mult, dir.normalized() * BASTION_PULSE_KNOCKBACK)

# Begrenzt eine Weltposition auf den spielbaren Kartenbereich.
func _clamp_to_map(pos: Vector2) -> Vector2:
	var map_w := float(LevelGenerator.map_w) * LevelGenerator.TILE_SIZE
	var map_h := float(LevelGenerator.map_h) * LevelGenerator.TILE_SIZE
	return Vector2(clampf(pos.x, 60.0, map_w - 60.0), clampf(pos.y, 60.0, map_h - 60.0))

# Teleportziele dürfen nicht in festem Gelände liegen (Hausdach, Pyramide,
# Wände, Kisten). Vom Ziel aus geht es in kleinen Schritten zurück Richtung
# Start, bis die Spielerform frei ist. Einwegstege zählen nicht als Hindernis.
const TELEPORT_PROBE_STEP: float = 6.0
const TELEPORT_PROBE_INSET: float = 2.0

func _free_teleport_target(start: Vector2, target: Vector2) -> Vector2:
	if collision_shape == null or not (collision_shape.shape is RectangleShape2D):
		return target
	var probe := RectangleShape2D.new()
	var body_size: Vector2 = (collision_shape.shape as RectangleShape2D).size
	probe.size = Vector2(maxf(2.0, body_size.x - TELEPORT_PROBE_INSET * 2.0), maxf(2.0, body_size.y - TELEPORT_PROBE_INSET * 2.0))
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = probe
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var shape_xf := collision_shape.global_transform
	var offset := shape_xf.origin - global_position
	var space := get_world_2d().direct_space_state
	var steps := maxi(1, int(ceil(start.distance_to(target) / TELEPORT_PROBE_STEP)))
	for i in range(steps + 1):
		var p := target.lerp(start, float(i) / float(steps))
		shape_xf.origin = p + offset
		query.transform = shape_xf
		if not _teleport_probe_blocked(space.intersect_shape(query, 8)):
			return p
	return start

func _teleport_probe_blocked(hits: Array) -> bool:
	for hit in hits:
		var collider = hit.get("collider")
		if collider is Node and (collider as Node).is_in_group("one_way_platform"):
			continue
		return true
	return false

func _flash_effect() -> void:
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color(3.0, 3.0, 1.0), 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO, source = null, is_reflected: bool = false) -> void:
	# In Team-Modi gibt es kein Freundschaftsfeuer. Das gilt auch für
	# Flächenfähigkeiten und Explosionen, deren Quelle ein Spieler ist.
	if is_instance_valid(source) and source is Player and source != self and source.team_id == team_id:
		return
	# Selbstschaden durch eigene Waffen, Explosionen oder TNT wird halbiert.
	if is_instance_valid(source) and source is Player and source == self:
		amount *= FRIENDLY_FIRE_DAMAGE_MULT
		# Gummipuffer-Karte: eigener Schaden zusätzlich verringert.
		amount *= 1.0 - clampf(self_damage_reduction, 0.0, MAX_SELF_DAMAGE_REDUCTION)
	# Dash, Sprung und kurze FÃƒÂ¤higkeits-Unverwundbarkeit negieren Schaden komplett.
	if is_invulnerable:
		_fx("sound", {"snd": ["bounce", 0.2, 2.0]})
		return

	# Universeller Block verhindert Schaden vollstÃƒÂ¤ndig; Projektile werden in
	# der Physik-Schleife reflektiert.
	if is_blocking:
		Global.add_match_stat(player_index, "damage_blocked", amount)
		Global.add_match_stat(player_index, "blocked_hits", 1.0)
		Global.shake_camera(0.16)
		_pulse_block_shield(0.16)
		return
	
	shield_regen_timer = shield_regen_delay
	hp_regen_timer = HP_REGEN_DELAY
	# Die Schadensquelle kann inzwischen freigegeben sein (z. B. ein bereits
	# zerstörter Schütze oder eine alte Flächeneffekt-Zone). Deshalb erst
	# validieren und dann als Kill-Credit übernehmen.
	if is_instance_valid(source) and source != self and source is Player:
		last_damage_source = source
		last_damage_timer = 8.0
		# Rückstoß-Karten des Angreifers verstärken alle von ihm verursachten
		# Treffer, nicht nur direkte Projektile.
		knockback *= maxf(0.1, source.knockback_mult)

	# Rüstung reduziert den eingehenden Schaden vor Schild und Leben. Der Wert
	# wird additiv aus allen Tank-Karten gebildet und in apply_stats gedeckelt.
	var mitigated_amount := amount * (1.0 - clampf(armor_percent, 0.0, MAX_ARMOR_PERCENT))
	# Bastion-Evolution "Schutzkuppel": weniger Schaden, solange das Heilfeld läuft.
	if heal_field_timer > 0.0 and _has_ability_evolution("bastion_bulwark"):
		mitigated_amount *= 1.0 - BASTION_BULWARK_REDUCTION
	var effective_damage := minf(mitigated_amount, current_shield + maxf(current_health, 0.0))
	var damage_source_index := 0
	if is_instance_valid(source) and source is Player and source != self:
		damage_source_index = source.player_index
	
	# Shield absorption
	if current_shield > 0.0:
		if current_shield >= mitigated_amount:
			current_shield -= mitigated_amount
			mitigated_amount = 0.0
		else:
			mitigated_amount -= current_shield
			current_shield = 0.0
	
	current_health -= mitigated_amount
	apply_knockback(knockback)

	if effective_damage > 0.0:
		Global.add_match_stat(player_index, "damage_taken", effective_damage)
		if damage_source_index > 0:
			Global.add_match_stat(damage_source_index, "damage_dealt", effective_damage)
			if source.dealing_ability_damage:
				Global.add_match_stat(damage_source_index, "ability_damage", effective_damage)
		Global.shake_camera(clampf(effective_damage * 0.008, 0.06, 0.45))

	# Schadensreflexion geht nur an gegnerische Spieler zurück. Reflektierter
	# Schaden darf nicht erneut reflektiert werden, sonst entsteht eine Schleife.
	var reflect_share := get_current_reflect_percent()
	if not is_reflected and effective_damage > 0.0 and reflect_share > 0.0 \
			and is_instance_valid(source) and source is Player and source != self \
			and not source.is_dead and source.current_health > 0.0:
		var reflected_damage := effective_damage * reflect_share
		var attacker: Player = source
		var attacker_pool_before := attacker.current_health + attacker.current_shield
		attacker.take_damage(reflected_damage, Vector2.ZERO, self, true)
		# Blutspiegel & Co.: Der Tank heilt sich um einen Anteil dessen, was
		# beim Angreifer nach Rüstung/Block tatsächlich angekommen ist.
		if reflect_heal_percent > 0.0 and current_health > 0.0 and is_instance_valid(attacker):
			var landed := attacker_pool_before - (maxf(attacker.current_health, 0.0) + attacker.current_shield)
			if landed > 0.0:
				heal(landed * reflect_heal_percent)
	
	var hit_strength := clampf(effective_damage / 18.0, 0.35, 1.0)
	_flash_hit(knockback, hit_strength, clampf(effective_damage * 0.008, 0.06, 0.45) if effective_damage > 0.0 else 0.0)
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	
	if current_health <= 0.0:
		if _try_powerup_revive():
			return
		_die()

# Reflexionsanteil inklusive Rache-Bonus bei niedrigem Leben, gedeckelt.
func get_current_reflect_percent() -> float:
	# Rache-Powerup: voller Dornenschaden, unabhängig von Karten.
	if powerup_revenge_timer > 0.0:
		return POWERUP_REVENGE_REFLECT
	var share := damage_reflect_percent
	if reflect_low_hp_bonus > 0.0 and max_health > 0.0 \
			and current_health > 0.0 and current_health / max_health <= REFLECT_LOW_HP_THRESHOLD:
		share += reflect_low_hp_bonus
	return clampf(share, 0.0, MAX_DAMAGE_REFLECT_PERCENT)

# shake > 0: Clients wackeln mit der Kamera wie der Host.
func _flash_hit(knockback: Vector2 = Vector2.ZERO, strength: float = 1.0, shake: float = 0.0) -> void:
	_net_player_fx("_flash_hit", [knockback, strength], {"shake": shake})
	if not is_instance_valid(sprite):
		return
	# Prozedurale Trefferanimation: Stauchen, Zittern, geschlossene Augen und
	# kleine Blutspritzer.
	sprite.play_hit(knockback, strength)
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(sprite, "modulate", Color(2.2, 0.42, 0.42), 0.05)
	_hit_flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.16)

func heal(amount: float) -> void:
	var before := current_health
	current_health = minf(current_health + amount, max_health)
	var healed := current_health - before
	if healed > 0.0:
		Global.add_match_stat(player_index, "healing_done", healed)
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	# Dauerheilung (Symbiose, Heilfeld) ruft heal() sehr oft auf; online wird
	# der Blitz deshalb höchstens alle HEAL_FLASH_NET_GAP Sekunden geschickt.
	var now := Time.get_ticks_msec()
	if now - _last_heal_flash_net_ms >= int(HEAL_FLASH_NET_GAP * 1000.0):
		_last_heal_flash_net_ms = now
		_net_player_fx("_heal_flash")
	_heal_flash()

func _heal_flash() -> void:
	if not is_instance_valid(sprite):
		return
	var tw = create_tween()
	tw.tween_property(sprite, "modulate", Color.GREEN, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func apply_powerup(kind: String) -> void:
	if current_health <= 0.0:
		return
	match kind:
		# Powerup-Karten verlängern die Dauer bzw. erhöhen die Heilung.
		"heal":
			heal(35.0 * powerup_strength_mult)
			_flash_powerup(Color(0.45, 1.0, 0.55, 1.0))
		"invulnerability":
			powerup_invuln_timer = maxf(powerup_invuln_timer, 3.0 * powerup_strength_mult)
			is_invulnerable = true
			_flash_powerup(Color(0.45, 0.78, 1.0, 1.0))
		"damage":
			powerup_damage_timer = maxf(powerup_damage_timer, 6.0 * powerup_strength_mult)
			powerup_damage_mult = maxf(powerup_damage_mult, 1.65)
			_flash_powerup(Color(1.0, 0.45, 0.25, 1.0))
		"rapid_fire":
			powerup_rapid_fire_timer = maxf(powerup_rapid_fire_timer, 5.0 * powerup_strength_mult)
			is_reloading = false
			reload_timer = 0.0
			current_ammo = maxi(current_ammo, 1)
			emit_signal("ammo_changed", current_ammo, max_ammo)
			_flash_powerup(Color(1.0, 0.86, 0.3, 1.0))
		"auto_attack":
			powerup_auto_attack_timer = maxf(powerup_auto_attack_timer, POWERUP_AUTO_ATTACK_DURATION * powerup_strength_mult)
			# Eine laufende Abklingzeit wird sofort mit verkürzt.
			melee_cooldown_timer = minf(melee_cooldown_timer, melee_cooldown * POWERUP_AUTO_ATTACK_COOLDOWN_MULT)
			_flash_powerup(Color(0.85, 0.45, 1.0, 1.0))
		"multishot":
			powerup_multishot_timer = maxf(powerup_multishot_timer, POWERUP_MULTISHOT_DURATION * powerup_strength_mult)
			_flash_powerup(POWERUP_GLOW_COLORS["multishot"])
		"undying":
			powerup_undying_timer = maxf(powerup_undying_timer, POWERUP_UNDYING_WINDOW * powerup_strength_mult)
			_flash_powerup(POWERUP_GLOW_COLORS["undying"])
		"revenge":
			powerup_revenge_timer = maxf(powerup_revenge_timer, POWERUP_REVENGE_DURATION * powerup_strength_mult)
			_flash_powerup(POWERUP_GLOW_COLORS["revenge"])
		"invisible":
			powerup_invisible_timer = maxf(powerup_invisible_timer, POWERUP_INVISIBLE_DURATION * powerup_strength_mult)

# Unsterblichkeit: statt zu sterben kurz am Boden liegen. Nur der Host (bzw.
# offline) entscheidet; der Zustand kommt per Snapshot ("revive") zu Clients.
func _try_powerup_revive() -> bool:
	if is_replica or is_dead or revive_timer > 0.0 or powerup_undying_timer <= 0.0:
		return false
	powerup_undying_timer = 0.0
	revive_timer = POWERUP_REVIVE_DELAY
	current_health = 0.0
	current_shield = 0.0
	poison_ticks_left = 0
	burn_ticks_left = 0
	is_blocking = false
	is_invulnerable = true
	apply_stun(POWERUP_REVIVE_DELAY)
	_set_revive_visual(true)
	# Todes-Effekte lösen auch beim Scheintod aus (wie in _die()).
	if kamikaze:
		_trigger_kamikaze()
	_fx("sound", {"snd": ["death", 0.08, 2.0]})
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
	return true

func _finish_powerup_revive() -> void:
	revive_timer = 0.0
	stun_timer = 0.0
	current_health = maxf(1.0, max_health * POWERUP_REVIVE_HEALTH_PERCENT)
	# Kurzer Schutz nach dem Aufstehen, damit man nicht sofort wieder fällt.
	powerup_invuln_timer = maxf(powerup_invuln_timer, POWERUP_REVIVE_INVULN)
	is_invulnerable = true
	_set_revive_visual(false)
	_flash_powerup(POWERUP_GLOW_COLORS["undying"])
	_fx("sound", {"snd": ["teleport", 0.1, 0.0]})
	emit_signal("health_changed", current_health, max_health, current_shield, max_shield)

func is_reviving() -> bool:
	return revive_timer > 0.0

# Liegt der Spieler am Boden, wird er halb durchsichtig und kippt zur Seite.
func _set_revive_visual(downed: bool) -> void:
	if is_instance_valid(sprite):
		sprite.rotation = deg_to_rad(90.0) if downed else 0.0

func is_invisible() -> bool:
	return powerup_invisible_timer > 0.0

# Deckkraft des ganzen Charakters (inkl. Waffe und Lebensleiste): halb
# durchsichtig beim Wiederbeleben, je nach Betrachter fast weg bei Unsichtbar.
func _update_body_alpha() -> void:
	var alpha := 0.4 if revive_timer > 0.0 else 1.0
	if powerup_invisible_timer > 0.0:
		var hidden_alpha := _invisible_viewer_alpha()
		var fade := clampf(powerup_invisible_timer / INVISIBLE_FADE_TIME, 0.0, 1.0)
		alpha = minf(alpha, lerpf(1.0, hidden_alpha, fade))
	if not is_equal_approx(modulate.a, alpha):
		modulate.a = alpha

func _invisible_viewer_alpha() -> float:
	if Global.network_mode:
		# Online sieht jeder Rechner nur Unsichtbare aus dem eigenen Team.
		if Global.get_team_for_slot(Global.local_player_index) == team_id:
			return INVISIBLE_ALLY_ALPHA
		return 0.0
	# Geteilter Bildschirm: gegen menschliche Gegner nur ein Hauch, damit man
	# sich selbst noch findet. Gegen Bots reicht die normale Ally-Sicht.
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p != self and is_instance_valid(p) and not p.is_bot and p.team_id != team_id:
			return INVISIBLE_SHARED_SCREEN_ALPHA
	return INVISIBLE_ALLY_ALPHA

func _flash_powerup(flash_color: Color) -> void:
	_net_player_fx("_flash_powerup", [flash_color])
	if not is_instance_valid(sprite):
		return
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", flash_color, 0.08)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func apply_poison(stacks: int, damage_per_tick: float = 4.0) -> void:
	# StÃƒÂ¤rkeres Gift ÃƒÂ¼berschreibt schwÃƒÂ¤cheres, schwÃƒÂ¤cheres Gift verlÃƒÂ¤ngert nur.
	poison_damage_per_tick = maxf(poison_damage_per_tick, damage_per_tick)
	poison_ticks_left = maxi(poison_ticks_left, stacks)
	_refresh_poison_visual()

func is_poisoned() -> bool:
	return poison_ticks_left > 0

func _refresh_poison_visual() -> void:
	var poisoned := is_poisoned() and not is_dead
	if _poison_bubbles != null and is_instance_valid(_poison_bubbles):
		_poison_bubbles.set_emitting(poisoned)
	if is_instance_valid(sprite):
		# self_modulate bleibt vom Treffer-/Heilblitz (modulate) unberührt.
		sprite.self_modulate = _base_body_tint()

func _base_body_tint() -> Color:
	return POISON_TINT if is_poisoned() and not is_dead else Color.WHITE

# Aktive Powerups als [Art, Farbe, Restzeit]. Die Timer kommen online per
# Snapshot mit, daher schimmern und leuchten auch Replikas auf allen Rechnern.
func _active_powerup_effects() -> Array:
	var effects: Array = []
	for entry in [
		["invulnerability", powerup_invuln_timer],
		["multishot", powerup_multishot_timer],
		["undying", powerup_undying_timer],
		["revenge", powerup_revenge_timer],
		["invisible", powerup_invisible_timer],
		["damage", powerup_damage_timer],
		["rapid_fire", powerup_rapid_fire_timer],
		["auto_attack", powerup_auto_attack_timer],
	]:
		if float(entry[1]) > 0.0:
			effects.append([entry[0], POWERUP_GLOW_COLORS[entry[0]], entry[1]])
	return effects

# Aktive Powerups als [Farbe, Restzeit] für den Körper-Schimmer.
func _active_powerup_glows() -> Array:
	var glows: Array = []
	for effect in _active_powerup_effects():
		glows.append([effect[1], effect[2]])
	return glows

func _update_powerup_aura() -> void:
	if _powerup_aura_back == null:
		return
	var effects: Array = [] if is_dead or current_health <= 0.0 else _active_powerup_effects()
	_powerup_aura_back.call("set_effects", effects)
	_powerup_aura_front.call("set_effects", effects)

func _update_powerup_glow(delta: float) -> void:
	if not is_instance_valid(sprite):
		return
	var glows: Array = [] if is_dead or current_health <= 0.0 else _active_powerup_glows()
	if glows.is_empty():
		if _powerup_glow_active:
			_powerup_glow_active = false
			_powerup_glow_time = 0.0
			sprite.self_modulate = _base_body_tint()
		return
	_powerup_glow_active = true
	_powerup_glow_time += delta
	var slot := int(_powerup_glow_time / POWERUP_GLOW_SLOT_TIME) % glows.size()
	var glow_color: Color = glows[slot][0]
	var remaining: float = glows[slot][1]
	var strength: float
	if remaining < POWERUP_GLOW_ENDING_TIME:
		# Kurz vor Ablauf hart an/aus, wie der auslaufende Stern.
		strength = 0.85 if int(_powerup_glow_time * 12.0) % 2 == 0 else 0.0
	else:
		var pulse := 0.5 + 0.5 * sin(_powerup_glow_time * TAU * POWERUP_GLOW_PULSE_HZ)
		strength = 0.3 + 0.55 * pulse
	var lit := Color(glow_color.r * POWERUP_GLOW_BOOST, glow_color.g * POWERUP_GLOW_BOOST,
			glow_color.b * POWERUP_GLOW_BOOST, 1.0)
	sprite.self_modulate = _base_body_tint() * Color.WHITE.lerp(lit, strength)

func apply_freeze(duration: float) -> void:
	freeze_timer = maxf(freeze_timer, duration)

func apply_stun(duration: float) -> void:
	stun_timer = maxf(stun_timer, duration)

func apply_burn(stacks: int, damage_per_tick: float = 5.0) -> void:
	burn_ticks_left = maxi(burn_ticks_left, stacks)
	burn_damage_per_tick = maxf(burn_damage_per_tick, damage_per_tick)

# Rundenstart: Der eigene Charakter erscheint aus einem Portal und wächst
# dabei sichtbar aus der Portalmitte heraus.
func play_spawn_intro() -> void:
	if not is_instance_valid(sprite) or not is_instance_valid(weapon_pivot):
		return
	if _spawn_intro_tween != null and _spawn_intro_tween.is_valid():
		_spawn_intro_tween.kill()

	var hero_color := Color(0.55, 0.35, 1.0)
	var hero := Global.get_hero(Global.get_player_hero_id(player_index))
	if hero != null:
		hero_color = hero.color_tint
	_spawn_portal_effect(hero_color)

	var sprite_scale := sprite.scale
	var sprite_position := sprite.position
	var weapon_scale := weapon_pivot.scale
	sprite.scale = sprite_scale * 0.16
	sprite.position = sprite_position + Vector2(0.0, 18.0)
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	weapon_pivot.scale = weapon_scale * 0.16
	weapon_pivot.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var indicators := get_node_or_null("StatusIndicators") as CanvasItem
	if indicators != null:
		indicators.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var delay := 0.08
	_spawn_intro_tween = create_tween()
	_spawn_intro_tween.set_parallel(true)
	_spawn_intro_tween.tween_property(sprite, "scale", sprite_scale, 0.48).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_intro_tween.tween_property(sprite, "position", sprite_position, 0.48).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spawn_intro_tween.tween_property(sprite, "modulate:a", 1.0, 0.28).set_delay(delay)
	_spawn_intro_tween.tween_property(weapon_pivot, "scale", weapon_scale, 0.48).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_intro_tween.tween_property(weapon_pivot, "modulate:a", 1.0, 0.28).set_delay(delay)
	if indicators != null:
		_spawn_intro_tween.tween_property(indicators, "modulate:a", 1.0, 0.25).set_delay(0.25)
	_spawn_intro_tween.chain().tween_callback(flash_intro)

func _spawn_portal_effect(portal_color: Color) -> void:
	var portal = PORTAL_SPAWN_EFFECT_SCRIPT.new()
	portal.portal_color = portal_color
	add_child(portal)
	portal.top_level = true
	portal.global_position = global_position + Vector2(0.0, 6.0)
	portal.show_behind_parent = true
	portal.add_to_group("portal_spawn_effect")
	portal.add_to_group("round_effect")
	portal.start()

# Kurzes Aufblinken des eigenen Charakters beim Rundenstart.
func flash_intro() -> void:
	if not is_instance_valid(sprite):
		return
	var tw = create_tween()
	for i in range(3):
		tw.tween_property(sprite, "modulate", Color(2.2, 2.2, 0.8, 0.35), 0.10)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.10)

# --- Talentbaum: TÃƒÂ¼rme und Drohnen ---

func _clear_drones() -> void:
	for drone in drones:
		if is_instance_valid(drone):
			drone.queue_free()
	drones.clear()

func _spawn_drones() -> void:
	for i in range(drone_count):
		var drone := Companion.new()
		drone.mode = Companion.Mode.DRONE
		drone.owner_player = self
		drone.target_enemy = _valid_opponent()
		drone.support = drone_guardian
		drone.is_replica = is_replica
		drone.orbit_radius = 48.0 + float(i) * 16.0
		drone.orbit_speed = 1.5 + float(i) * 0.25
		add_child(drone)
		drones.append(drone)

	# Schutzdrohnen bilden einen eigenen, weiter außen liegenden Ring. Sie
	# schießen nicht, sondern fangen Projektile ab.
	for i in range(blocker_drone_count):
		var blocker := Companion.new()
		blocker.mode = Companion.Mode.DRONE
		blocker.owner_player = self
		blocker.is_replica = is_replica
		blocker.blocks_projectiles = true
		blocker.block_heals_owner = blocker_drone_heal
		blocker.orbit_radius = 66.0 + float(i) * 16.0
		blocker.orbit_speed = 1.7 + float(i) * 0.22
		add_child(blocker)
		drones.append(blocker)

func _spawn_tower() -> void:
	if is_replica:
		return
	var valid_towers: Array[Companion] = []
	for tower in towers:
		if is_instance_valid(tower):
			valid_towers.append(tower)
	towers = valid_towers
	if towers.size() >= 8:
		return

	var tower := Companion.new()
	tower.mode = Companion.Mode.TOWER
	tower.owner_player = self
	tower.target_enemy = _valid_opponent()
	tower.follow_owner = tower_follow
	tower.max_health = tower_max_health
	tower.fire_interval = Companion.BASE_FIRE_INTERVAL * tower_fire_rate_mult
	tower.damage_mult = Companion.BASE_DAMAGE_MULT
	tower.is_replica = false
	get_parent().add_child(tower)
	tower.global_position = global_position
	towers.append(tower)

# --- Talentbaum: FlÃƒÂ¤cheneffekte ---

func spawn_effect_zone(kind: int, pos: Vector2, radius: float, duration: float, params: Dictionary = {}) -> void:
	if is_replica:
		return
	# Feuer brennt wie Benzin auf dem Boden darunter; Treffer- und Optikfläche
	# wandern gemeinsam dorthin.
	var fire_hit := {}
	if kind == EffectZone.Kind.FIRE:
		fire_hit = EffectZone.floor_hit(get_world_2d().direct_space_state, pos)
		# Kein Boden darunter (Abgrund): das Feuer fällt ins Leere.
		if fire_hit.is_empty():
			return
		pos = fire_hit["position"]
	var visual_only := bool(params.get("visual_only", false))
	var zone := EffectZone.new()
	zone.kind = kind
	zone.visual_only = visual_only
	zone.owner_player = self
	zone.target = null if visual_only else _valid_opponent()
	zone.radius = radius
	zone.duration = duration
	zone.tick_interval = float(params.get("tick_interval", 0.55))
	zone.damage = float(params.get("damage", 0.0))
	zone.poison_stacks = int(params.get("poison_stacks", 2))
	zone.poison_damage = float(params.get("poison_damage", 4.0))
	zone.burn_stacks = int(params.get("burn_stacks", 3))
	zone.burn_damage = float(params.get("burn_damage", 5.0))
	zone.freeze_duration = float(params.get("freeze_duration", 1.2))
	zone.stun_duration = float(params.get("stun_duration", 0.25))
	zone.from_ability = bool(params.get("from_ability", false))
	get_parent().add_child(zone)
	zone.global_position = pos
	# Auf Plattformen und Wippen fährt das Feuer mit.
	if kind == EffectZone.Kind.FIRE:
		zone.setup_fire_host(fire_hit)

	if Global.network_mode and NetworkManager.is_host:
		var net_data := {
			"kind": kind,
			"pos": pos,
			"radius": radius,
			"duration": duration,
			"tick_interval": zone.tick_interval,
			"damage": zone.damage,
			"poison_stacks": zone.poison_stacks,
			"poison_damage": zone.poison_damage,
			"burn_stacks": zone.burn_stacks,
			"burn_damage": zone.burn_damage,
			"freeze_duration": zone.freeze_duration,
			"stun_duration": zone.stun_duration,
			"owner_index": player_index,
		}
		if kind == EffectZone.Kind.FIRE:
			net_data.merge(zone.fire_network_data())
		NetworkManager.send_zone_spawn(net_data)

func spawn_network_zone(data: Dictionary) -> void:
	var zone := EffectZone.new()
	zone.is_replica = true
	zone.kind = int(data.get("kind", EffectZone.Kind.POISON))
	zone.radius = float(data.get("radius", 40.0))
	zone.duration = float(data.get("duration", 2.0))
	zone.tick_interval = float(data.get("tick_interval", 0.55))
	get_parent().add_child(zone)
	zone.global_position = data.get("pos", global_position)
	if zone.kind == EffectZone.Kind.FIRE:
		zone.apply_fire_network_data(data)

func spawn_poison_cloud(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.POISON, pos, 52.0, 3.2, {
		"tick_interval": 0.55,
		"poison_stacks": 1,
		"poison_damage": poison_damage_per_tick,
	})

func spawn_fire_zone(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.FIRE, pos, 56.0, 3.0, {
		"tick_interval": 0.5,
		"burn_stacks": 1,
		"burn_damage": burn_damage_per_tick,
	})

func spawn_frost_nova(pos: Vector2) -> void:
	spawn_effect_zone(EffectZone.Kind.ICE, pos, 66.0, 0.9, {
		"tick_interval": 0.2,
		"freeze_duration": 1.4,
	})

func spawn_lightning_zone(pos: Vector2, from_ability: bool = false) -> void:
	# Zonen aus der Heldenfähigkeit wachsen mit Fähigkeitsgröße und -schaden.
	var size_mult := ability_radius_mult if from_ability else 1.0
	var dmg_mult := ability_damage_mult if from_ability else 1.0
	spawn_effect_zone(EffectZone.Kind.LIGHTNING, pos, 52.0 * size_mult, 4.0, {
		"from_ability": from_ability,
		"tick_interval": 0.45,
		"damage": 2.5 * dmg_mult,
		"stun_duration": 0.25,
	})

func _spawn_trail_zone(kind: int) -> void:
	var behind_x := -signf(velocity.x) * 18.0
	var pos := global_position + Vector2(behind_x, 10.0)
	match kind:
		EffectZone.Kind.POISON:
			spawn_effect_zone(kind, pos, 30.0, 2.2, {
				"tick_interval": 0.45,
				"poison_stacks": 1,
				"poison_damage": poison_damage_per_tick,
			})
		EffectZone.Kind.FIRE:
			spawn_effect_zone(kind, pos, 32.0, 2.0, {
				"tick_interval": 0.45,
				"burn_stacks": 1,
				"burn_damage": burn_damage_per_tick,
			})
		EffectZone.Kind.ICE:
			spawn_effect_zone(kind, pos, 30.0, 2.5, {
				"tick_interval": 0.3,
				"freeze_duration": 1.0,
			})

func trigger_chain_lightning(primary: Node2D, from_position: Vector2) -> void:
	# primary kann auch ein Nicht-Spieler sein (z. B. das Pinata-Lama).
	if is_replica:
		return
	var chain_target: Player = null
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p != self and p != primary and is_instance_valid(p) and p.team_id != team_id and p.current_health > 0.0:
			chain_target = p
			break
	if chain_target == null and is_instance_valid(primary) and primary is Player and (primary as Player).current_health > 0.0:
		# Im 1-gegen-1 springt der Kettenblitz auf das PrimÃƒÂ¤rziel zurÃƒÂ¼ck.
		chain_target = primary as Player
	if chain_target == null:
		return

	# Kettenblitze aus der Fähigkeit (Volt "Kettenblink") skalieren mit Fähigkeitsschaden.
	var chain_damage := bullet_damage * 0.45
	if dealing_ability_damage:
		chain_damage *= ability_damage_mult
	chain_target.take_damage(chain_damage, Vector2.ZERO, self)
	chain_target.apply_stun(0.1)
	_spawn_lightning_arc(from_position, chain_target.global_position)

func _spawn_lightning_arc(from_pos: Vector2, to_pos: Vector2) -> void:
	_fx("zap", NetFx.zap_args(from_pos, to_pos, Color(1.0, 0.95, 0.3, 0.95), 3.0, 0.18, 7, 14.0))

# from_ability: Splitter aus der Heldenfähigkeit (zählt als Fähigkeitsschaden).
func spawn_cluster_bomblets(pos: Vector2, from_ability: bool = false) -> void:
	if is_replica:
		return
	# Splitter aus der Fähigkeit (Ignis "Splitterlandung") skalieren mit Fähigkeitsgröße und -schaden.
	var size_mult := ability_radius_mult if from_ability else 1.0
	var dmg_mult := ability_damage_mult if from_ability else 1.0
	for i in range(4):
		var dir := Vector2.from_angle((TAU / 4.0) * float(i) + randf_range(-0.25, 0.25))
		var b: Bullet = bullet_scene.instantiate()
		b.shooter = self
		b.target_enemy = _valid_opponent()
		b.damage = bullet_damage * 0.40 * dmg_mult
		b.from_ability = from_ability
		b.projectile_gravity_mult = projectile_gravity_mult
		b.velocity = dir * bullet_speed * 0.65
		b.bounces_left = 1
		b.explosion_radius = 18.0 * size_mult
		b.max_lifetime = 1.4
		b.scale = Vector2(0.7, 0.7)
		b.modulate = Color(1.0, 0.65, 0.15)
		get_parent().add_child(b)
		b.global_position = pos + dir * 2.0

func _die() -> void:
	# Mehrere Treffer im selben Frame dürfen nur einen Tod auslösen.
	if is_dead:
		return
	is_dead = true
	_refresh_poison_visual()
	if kamikaze:
		_trigger_kamikaze()
	SoundManager.play_sound("death", 0.08, -1.0)
	Global.shake_camera(0.5)
	emit_signal("died", player_index)
	queue_free()

func _trigger_kamikaze() -> void:
	_fx("sound", {"snd": ["explosion", 0.2, 0.0]})
	Seesaw.blast_all(get_tree(), global_position, 160.0, 1.5)
	for p in _opponents_within(global_position, 160.0):
		var dist = global_position.distance_to(p.global_position)
		var falloff = 1.0 - (dist / 160.0)
		p.take_damage(65.0 * falloff, (p.global_position - global_position).normalized() * 500.0, self)

# Gummiwand: Dash und Raketensprung enden bei Kontakt, sonst überschreiben sie
# jeden Frame den Rückstoß und man rutscht durch. Der Sprung zündet seinen
# Einschlag an der Wand wie bei jedem anderen Aufprall.
func interrupt_rush() -> void:
	if is_dashing:
		is_dashing = false
		dash_timer = 0.0
		is_invulnerable = _has_temporary_invulnerability()
	if is_leaping:
		is_leaping = false
		leap_timer = 0.0
		is_invulnerable = _has_temporary_invulnerability()
		_trigger_rocket_impact()

func _has_temporary_invulnerability() -> bool:
	return is_dashing or is_leaping or ability_invuln_timer > 0.0 or powerup_invuln_timer > 0.0 \
		or revive_timer > 0.0

func _handle_timers(delta: float) -> void:
	if last_damage_timer > 0.0:
		last_damage_timer -= delta
		if last_damage_timer <= 0.0:
			last_damage_source = null

	if fire_timer > 0.0:
		fire_timer -= delta
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
			_owner_sound("reload_done", 0.04, 0.0)
			emit_signal("ammo_changed", current_ammo, max_ammo)
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if is_dashing:
		dash_timer -= delta
		if Global.get_player_hero_id(player_index) == "ignis":
			afterburner_timer -= delta
			if afterburner_timer <= 0.0:
				afterburner_timer = AFTERBURNER_ZONE_INTERVAL
				spawn_effect_zone(EffectZone.Kind.FIRE, global_position, AFTERBURNER_ZONE_RADIUS, AFTERBURNER_ZONE_DURATION, {
					"tick_interval": 0.45,
					"burn_stacks": AFTERBURNER_BURN_STACKS,
					"burn_damage": AFTERBURNER_BURN_DAMAGE,
				})
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = _has_temporary_invulnerability()
	
	if ability_timer > 0.0:
		ability_timer -= delta
		if ability_timer <= 0.0:
			ability_timer = 0.0
			emit_signal("ability_cooldown_updated", 0.0, ability_max_cooldown)
		else:
			emit_signal("ability_cooldown_updated", ability_timer, ability_max_cooldown)
	
	# Standard-Block: Dauer und Cooldown verwalten.
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0.0:
			_end_block()
	if block_cooldown_timer > 0.0:
		block_cooldown_timer = maxf(0.0, block_cooldown_timer - delta)
	if melee_cooldown_timer > 0.0:
		melee_cooldown_timer = maxf(0.0, melee_cooldown_timer - delta)
	if melee_wall_stun_timer > 0.0:
		melee_wall_stun_timer = maxf(0.0, melee_wall_stun_timer - delta)
	# Nachschlag-Karte: zweiter, schwächerer Schlag in dieselbe Richtung.
	if melee_echo_timer > 0.0:
		melee_echo_timer -= delta
		if melee_echo_timer <= 0.0 and current_health > 0.0:
			melee_echo_timer = 0.0
			melee_swing_dir = melee_echo_dir
			melee_swing_seq += 1
			_play_melee_swing(melee_weapon, melee_echo_dir)
			_melee_strike(melee_echo_dir, MELEE_ECHO_POWER)
	# HUD nur ~10x pro Sekunde aktualisieren, nicht jeden Frame.
	var block_tenths := int(ceil(block_cooldown_timer * 10.0))
	if block_tenths != block_cd_display_tenths:
		block_cd_display_tenths = block_tenths
		emit_signal("block_state_changed", is_blocking, block_cooldown_timer, block_cooldown)

	# Heilzone aus dem Block-Kartenpfad.
	if block_heal_timer > 0.0:
		block_heal_timer -= delta
		block_heal_tick -= delta
		if block_heal_tick <= 0.0:
			block_heal_tick = 0.5
			if global_position.distance_to(block_heal_pos) <= 110.0:
				heal(6.0)

	# Kurze Unverwundbarkeit durch Klingensturm / Schattensprung.
	if ability_invuln_timer > 0.0:
		ability_invuln_timer -= delta
		if ability_invuln_timer <= 0.0 and not is_dashing and not is_leaping:
			is_invulnerable = _has_temporary_invulnerability()

	if powerup_invuln_timer > 0.0:
		powerup_invuln_timer = maxf(0.0, powerup_invuln_timer - delta)
		if powerup_invuln_timer <= 0.0:
			is_invulnerable = _has_temporary_invulnerability()

	if powerup_damage_timer > 0.0:
		powerup_damage_timer = maxf(0.0, powerup_damage_timer - delta)
		if powerup_damage_timer <= 0.0:
			powerup_damage_mult = 1.0

	if powerup_rapid_fire_timer > 0.0:
		powerup_rapid_fire_timer = maxf(0.0, powerup_rapid_fire_timer - delta)

	if powerup_multishot_timer > 0.0:
		powerup_multishot_timer = maxf(0.0, powerup_multishot_timer - delta)

	if powerup_undying_timer > 0.0:
		powerup_undying_timer = maxf(0.0, powerup_undying_timer - delta)

	if powerup_revenge_timer > 0.0:
		powerup_revenge_timer = maxf(0.0, powerup_revenge_timer - delta)

	if powerup_invisible_timer > 0.0:
		powerup_invisible_timer = maxf(0.0, powerup_invisible_timer - delta)

	if revive_timer > 0.0:
		revive_timer = maxf(0.0, revive_timer - delta)
		if revive_timer <= 0.0 and not is_replica and not is_dead:
			_finish_powerup_revive()

	if powerup_auto_attack_timer > 0.0:
		powerup_auto_attack_timer = maxf(0.0, powerup_auto_attack_timer - delta)
		if not is_replica and Global.melee_enabled and melee_cooldown_timer <= 0.0 \
				and control_enabled and current_health > 0.0 and is_inside_tree():
			var auto_dir := _melee_auto_target_dir()
			if auto_dir != Vector2.ZERO:
				melee_attack(auto_dir)

	# Parade: bereiter Nahkampfschlag löst von selbst aus, sobald ein
	# gegnerisches Projektil auf den Eber zufliegt und in Reichweite ist.
	if melee_parry and not is_replica and Global.melee_enabled and melee_cooldown_timer <= 0.0 \
			and control_enabled and current_health > 0.0 and is_inside_tree():
		var parry_dir := _melee_parry_target_dir()
		if parry_dir != Vector2.ZERO:
			melee_attack(parry_dir)

	# Klinge-Evolution "Echowirbel": verzögerter zweiter Wirbel.
	if blade_echo_timer > 0.0:
		blade_echo_timer -= delta
		if blade_echo_timer <= 0.0 and current_health > 0.0:
			_blade_storm_strike(BLADE_ECHO_DAMAGE_MULT)

	# Bastion-Heilfeld: heilt und lÃƒÂ¤dt Schild ÃƒÂ¼ber einige Sekunden auf.
	if heal_field_timer > 0.0:
		heal_field_timer -= delta
		heal_field_tick -= delta
		if heal_field_tick <= 0.0:
			heal_field_tick = HEAL_FIELD_TICK_INTERVAL
			heal(HEAL_FIELD_TICK_HEAL * ability_damage_mult)
			if max_shield > 0.0 and current_shield < max_shield:
				current_shield = minf(current_shield + HEAL_FIELD_TICK_SHIELD * ability_damage_mult, max_shield)
				emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
			# Bastion-Evolution "Pulsfeld": jeder Heil-Tick stößt Gegner am Feld zurück.
			if _has_ability_evolution("bastion_pulse"):
				_bastion_pulse()

	# Nova-SingularitÃƒÂ¤ten: ziehen Gegner heran und schÃƒÂ¤digen sie.
	if not gravity_wells.is_empty():
		for i in range(gravity_wells.size() - 1, -1, -1):
			var well: Dictionary = gravity_wells[i]
			well["time"] = float(well["time"]) - delta
			well["tick"] = float(well["tick"]) - delta
			var well_pos: Vector2 = well["pos"]
			for p in _opponents_within(well_pos, SINGULARITY_PULL_RADIUS * ability_radius_mult):
				var to_center: Vector2 = well_pos - p.global_position
				p.knockback_timer = maxf(p.knockback_timer, SINGULARITY_CONTROL_LOCK)
				if to_center.length() <= SINGULARITY_HOLD_RADIUS:
					p.velocity = p.velocity.lerp(Vector2.ZERO, minf(1.0, SINGULARITY_OUTWARD_DAMPING * delta))
					continue
				var pull_dir := to_center.normalized()
				var outward: float = p.velocity.dot(-pull_dir)
				if outward > 0.0:
					p.velocity += pull_dir * outward * minf(1.0, SINGULARITY_OUTWARD_DAMPING * delta)
				p.velocity += pull_dir * SINGULARITY_PULL_FORCE * delta
			# Die Singularität zieht nur heran und verursacht selbst keinen Schaden.
			if float(well["time"]) <= 0.0:
				if _has_ability_evolution("nova_implosion"):
					_nova_implosion(well_pos)
				gravity_wells.remove_at(i)
	
	if freeze_timer > 0.0:
		freeze_timer -= delta

	if stun_timer > 0.0:
		stun_timer -= delta

	if knockback_timer > 0.0:
		knockback_timer = maxf(0.0, knockback_timer - delta)

	if speed_boost_timer > 0.0:
		speed_boost_timer = maxf(0.0, speed_boost_timer - delta)
		if speed_boost_timer <= 0.0:
			# Sanft ausrollen statt abrupt auf die normale Steuerung zu springen.
			if absf(velocity.x) > move_speed:
				velocity.x = move_speed * signf(velocity.x)
			speed_boost_speed = 0.0
			speed_boost_direction = 0.0
	
	# Poison ticks
	if poison_ticks_left > 0:
		poison_tick_timer += delta
		if poison_tick_timer >= POISON_TICK_INTERVAL:
			poison_tick_timer = 0.0
			poison_ticks_left -= 1
			take_damage(poison_damage_per_tick)
			_fx("sound", {"snd": ["poison", 0.2, POISON_TICK_VOLUME_DB]})
			_refresh_poison_visual()

	# Brennschaden
	if burn_ticks_left > 0:
		burn_tick_timer += delta
		if burn_tick_timer >= BURN_TICK_INTERVAL:
			burn_tick_timer = 0.0
			burn_ticks_left -= 1
			take_damage(burn_damage_per_tick)

	# Turm-Talent: automatisch neue TÃƒÂ¼rme erzeugen.
	if tower_enabled and tower_auto_spawn:
		tower_spawn_timer -= delta
		if tower_spawn_timer <= 0.0:
			tower_spawn_timer = 5.0
			_spawn_tower()

	# Spuren nur beim Bewegen auf dem Boden erzeugen.
	var moving_on_ground := is_on_floor() and absf(velocity.x) > 35.0
	if poison_trail:
		if moving_on_ground:
			poison_trail_timer -= delta
			if poison_trail_timer <= 0.0:
				poison_trail_timer = 0.55
				_spawn_trail_zone(EffectZone.Kind.POISON)
		else:
			poison_trail_timer = minf(poison_trail_timer, 0.1)

	if fire_trail:
		if moving_on_ground:
			fire_trail_timer -= delta
			if fire_trail_timer <= 0.0:
				fire_trail_timer = 0.50
				_spawn_trail_zone(EffectZone.Kind.FIRE)
		else:
			fire_trail_timer = minf(fire_trail_timer, 0.1)

	if frost_trail:
		if moving_on_ground:
			frost_trail_timer -= delta
			if frost_trail_timer <= 0.0:
				frost_trail_timer = 0.70
				_spawn_trail_zone(EffectZone.Kind.ICE)
		else:
			frost_trail_timer = minf(frost_trail_timer, 0.1)
	
	_update_health_regeneration(delta)
	
	# Shield passive regeneration
	if shield_regen_timer > 0.0:
		shield_regen_timer -= delta
	elif current_shield < max_shield:
		current_shield = minf(current_shield + (SHIELD_REGEN_PER_SEC * shield_regen_mult * delta), max_shield)
		emit_signal("health_changed", current_health, max_health, current_shield, max_shield)

func _update_health_regeneration(delta: float) -> void:
	# Beide Pools heilen ohne Pause nach Schaden (HP_REGEN_DELAY = 0) und
	# werden getrennt addiert.
	var healing := hp_regen_always
	if hp_regen_timer > 0.0:
		hp_regen_timer = maxf(0.0, hp_regen_timer - delta)
	else:
		healing += hp_regen
	if healing > 0.0 and current_health > 0.0 and current_health < max_health:
		current_health = minf(current_health + healing * delta, max_health)
		emit_signal("health_changed", current_health, max_health, current_shield, max_shield)
