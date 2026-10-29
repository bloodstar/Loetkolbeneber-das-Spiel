class_name CardData
extends Resource

@export var id: String = ""
# Balance-Version der Karte. Bei JEDER Änderung an Werten oder Wirkung um 1
# erhöhen. Statistiken werden pro Version getrennt ausgewertet, damit alte
# Messwerte einer generften/gebufften Karte die neue Fassung nicht verfälschen.
@export var version: int = 1
@export var title: String = ""
@export var description: String = ""
@export var rarity: String = "Common" # Common, Uncommon, Rare, Epic, Legendary
# Draft-Pool (Haupt-Tag): Offensive, Defensive, Bewegung oder Nahkampf.
@export var pool: String = ""
# Sub-Tags für Filter und Diagramme, z. B. ["Bounce", "Unique"]. Leer = werden
# beim Registrieren aus den Werten der Karte abgeleitet (CardDatabase).
@export var sub_tags: Array[String] = []
@export var color: Color = Color(0.8, 0.8, 0.8)
# Leer = für alle Helden verfügbar. Sonst nur für diesen Helden (z. B. "ignis").
@export var hero_id: String = ""
# Optional: Karte erscheint nur, wenn der Spieler diese Mechanik bereits hat.
# Unterstützt: "dash", "ability", "block", "jump", "shield", "poison",
# "frost", "fire", "lightning", "tower", "drone" und "bounce".
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
@export var hp_regen_add: float = 0.0 # Zusätzliche HP pro Sekunde (startet sofort, keine Pause nach Schaden)
@export var hp_regen_always_add: float = 0.0 # Zusätzliche HP pro Sekunde, auch während Schaden
# --- Tank / Rüstung ---
# Additive prozentuale Schadensreduktion. 0.05 = 5 % weniger eingehender Schaden.
@export var armor_percent_add: float = 0.0
# Additive Schadensreflexion. 0.10 = 10 % des erlittenen Schadens gehen zurück.
@export var damage_reflect_percent_add: float = 0.0
# Zusätzliche Reflexion, solange der Spieler unter 35 % seines Maximallebens ist.
@export var reflect_low_hp_bonus_add: float = 0.0
# Anteil des tatsächlich zurückgeworfenen Schadens, der den Tank heilt (0.5 = 50 %).
@export var reflect_heal_percent_add: float = 0.0
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
# Abpraller-Ausbau: Kugeln prallen zusätzlich an der Kartengrenze ab (kostet keinen Abpraller).
@export var border_bounce: bool = false
# Abpraller-Ausbau: Kugeln teilen sich bei jedem Abprall in zwei kleinere mit je 60 % Schaden.
@export var bounce_split: bool = false
# Additive Verringerung des Selbstschadens durch eigene Kugeln/Explosionen (0.5 = 50 % weniger).
@export var self_damage_reduction_add: float = 0.0
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
@export var shield_regen_delay_add: float = 0.0 # Sekunden auf die Schild-Pause nach Schaden (<0 = startet früher)

# --- Standard-Block (universell, Taste Q) ---
@export var block_duration_add: float = 0.0 # Zusätzliche Sekunden Blockdauer
@export var block_cooldown_mult: float = 1.0 # <1.0 = kürzerer Block-Cooldown
@export var block_reflect_damage_add: float = 0.0 # Reflektierte Projektile: +Schaden (0.5 = +50%)
@export var block_knockback_radius_add: float = 0.0 # Rückstoß-Radius beim Blocken
@export var block_knockback_force_add: float = 0.0 # Stärke des Rückstoßes
@export var block_bomb: bool = false # Blockbombe beim Aktivieren
@export var block_bomb_damage: float = 0.0
@export var block_heal_zone: bool = false # Heilzone am Block-Standort
# Minenleger: Blocken legt eine für Gegner unsichtbare Mine (siehe BlockMine).
@export var block_mine: bool = false
@export var mine_damage_add: float = 0.0 # Zusätzlicher Minenschaden
@export var mine_radius_add: float = 0.0 # Zusätzlicher Explosionsradius der Minen in Feldern (1 Feld = 36 px)
@export var mine_instant: bool = false # Minen explodieren sofort, sobald ein Gegner darüberläuft

# --- Nahkampfwaffe (universell, Taste E) ---
# Unabhängig von den Schusswerten; wirkt auf jede gewählte Nahkampfwaffe.
@export var melee_damage_mult: float = 1.0 # Nahkampfschaden
@export var melee_range_add: float = 0.0 # Zusätzliche Reichweite in Feldern (1 Feld = 36 px)
@export var melee_cooldown_mult: float = 1.0 # <1.0 = kürzere Nahkampf-Abklingzeit
@export var melee_knockback_mult: float = 1.0 # Rückstoß der Nahkampftreffer
@export var melee_arc_add: float = 0.0 # Grad zusätzlicher Schlagbogen (Stich: breiterer Stoß)
@export var melee_freeze_add: float = 0.0 # Sekunden Frost pro Nahkampftreffer
@export var melee_poison_stacks_add: int = 0 # Giftstapel pro Nahkampftreffer
@export var melee_stun_add: float = 0.0 # Sekunden Betäubung pro Nahkampftreffer (Elektro)
@export var melee_burn_stacks_add: int = 0 # Brandstapel pro Nahkampftreffer
@export var melee_lifesteal_add: float = 0.0 # Anteil des Nahkampfschadens als Heilung
@export var melee_wall_stun_add: float = 0.0 # Sekunden Betäubung, wenn ein getroffener Gegner gegen eine Wand prallt
@export var melee_execute_bonus_add: float = 0.0 # Mehrschaden gegen Gegner unter 35 % Leben (0.6 = +60 %)
@export var melee_chain_lightning: bool = false # Treffer springt als Blitz auf einen weiteren Gegner
@export var melee_echo: bool = false # Zweiter, schwächerer Schlag kurz danach
@export var melee_parry: bool = false # Schlag wirft gegnerische Projektile im Bogen zurück

# --- Heldenfähigkeit (Klassenkarten) ---
# Multiplikatoren auf die aktive Fähigkeit des Helden (Rechtsklick).
@export var ability_damage_mult: float = 1.0 # Schaden bzw. Heil-/Schildstärke der Fähigkeit
@export var ability_radius_mult: float = 1.0 # Wirkungsradius der Fähigkeit
@export var ability_duration_mult: float = 1.0 # Dauer von Wolke, Feld, Singularität, Frost, Betäubung, Unverwundbarkeit
@export var ability_range_mult: float = 1.0 # Teleport-, Sprung- bzw. Wurfweite
# Schaltet einen Evolutionseffekt der Fähigkeit frei, z. B. "ignis_napalm".
# Die Effekte selbst sind in player.gd hinterlegt.
@export var ability_evolution: String = ""

# --- Pickup-Powerups ---
# Additiv: 0.25 = Powerups wirken 25 % stärker (Dauer bzw. Heilmenge).
@export var powerup_strength_add: float = 0.0
# Zusätzliche Sammelreichweite für Powerups in Feldern (1 Feld = 36 px).
@export var powerup_pickup_range_add: float = 0.0

# Werte, die nichts an der Spielstärke ändern bzw. separat protokolliert werden.
const _FINGERPRINT_IGNORED: Array[String] = [
	"id", "title", "description", "rarity", "color", "version", "pool", "sub_tags",
]

# Automatischer Fingerabdruck aller Balance-Werte. Ändert sich ein Wert, ohne
# dass version erhöht wurde, ist das in der Statistik trotzdem erkennbar.
func get_balance_fingerprint() -> String:
	# Nur Werte abweichend vom Standard zählen. So bleibt der Fingerabdruck
	# stabil, wenn CardData später ein neues Feld mit Standardwert bekommt.
	var defaults: Resource = get_script().new()
	var parts: PackedStringArray = []
	for prop in get_property_list():
		if not (int(prop.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var prop_name := str(prop.get("name", ""))
		if prop_name.is_empty() or _FINGERPRINT_IGNORED.has(prop_name):
			continue
		var value: Variant = get(prop_name)
		if value == defaults.get(prop_name):
			continue
		parts.append("%s=%s" % [prop_name, var_to_str(value)])
	parts.sort()
	return ";".join(parts).md5_text().substr(0, 8)

# Eindeutiger Schlüssel für Auswertungen, z. B. "heavy_bullets@v2".
func get_versioned_id() -> String:
	return "%s@v%d" % [id, version]
