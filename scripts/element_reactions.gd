class_name ElementReactions
extends RefCounted

# Reaktionen der Synergie-Matrix (Element-System, Entwurf 2026-11-25).
#
# Zwei Ebenen:
# - Welt-Reaktionen: Ein Element-Treffer auf ein Ziel, das schon einen anderen
#   Status trägt, oder ein Element, das auf eine fremde Fläche trifft. Das löst
#   auch zwischen verschiedenen Spielern aus (Lobby-Regel
#   Global.element_reactions_enabled).
# - Eigener Build: Wer die Kombination selbst hat (Player.element_combos),
#   bekommt den Kombi-Effekt immer, auch wenn die Lobby-Regel aus ist.
#
# Alles läuft nur auf dem Host bzw. lokal. Clients sehen die Folgen über
# Snapshot (Leben, Status), NetFx (Ringe, Blitze, Töne) und die Zonen-RPCs.
#
# Ziele sind Player oder HordeEnemy. Beide haben dieselben Statusfelder
# (poison_ticks_left, burn_ticks_left, freeze_timer, stun_timer) und Methoden
# (take_damage, apply_*). Der Reaktionszustand pro Ziel liegt als Meta "elem".

# Jede Reaktion löst pro Ziel höchstens so oft aus (Millisekunden).
const ICD_MS: int = 1500

# Gasbrand: Feuer auf ein vergiftetes Ziel zündet das restliche Gift.
const GAS_BURST_MULT: float = 1.5
const GAS_BURST_MIN: float = 8.0
const GAS_BURST_RADIUS: float = 60.0
# Gasexplosion: Feuer trifft eine Giftwolke.
const GAS_EXPLOSION_DAMAGE: float = 25.0
const GAS_EXPLOSION_BURN: int = 2
const GAS_EXPLOSION_KNOCKBACK: float = 260.0
# Thermoschock: Feuer auf Verlangsamte oder Frost auf Brennende.
const THERMO_DAMAGE: float = 10.0
const THERMO_DAMAGE_COMBO: float = 17.0
const DAMPF_BURN_CHILL: float = 0.5
# Dampfwolke: Feuer trifft Eis oder umgekehrt.
const STEAM_DURATION: float = 3.0
const STEAM_DAMAGE: float = 2.0
# Plasma: Blitz auf Brennende schleudert Funken.
const SPARK_COUNT: int = 3
const SPARK_RADIUS: float = 120.0
const SPARK_BURN: int = 2
const PLASMA_DURATION: float = 2.0
# Giftreif: Gift und Kälte.
const GIFTREIF_POISON_CHILL: float = 0.4
const BRITTLE_TICK_MULT: float = 0.6 # Gift tickt 40 % schneller
const RIME_DURATION: float = 5.0
# Neurotoxin: Blitz auf Vergiftete.
const NERVE_STUN_MAX: float = 0.5
const TOXIC_STORM_DURATION: float = 4.0
# Supraleiter: Blitz auf Verlangsamte.
const SUPER_MS: int = 3000
const SUPER_MULT: float = 1.2
const SUPER_MS_COMBO: int = 5000
const SUPER_MULT_COMBO: float = 1.3
const SUPER_ICE_DURATION: float = 2.0
# Lauffeuer (rein Feuer).
const WILDFIRE_MAX_STACK_MULT: int = 3
const WILDFIRE_SPREAD_TICKS: int = 2 # Brand-Tick alle 0,6 s -> Überspringen alle 1,2 s
const WILDFIRE_SPREAD_RADIUS: float = 80.0
const WILDFIRE_ZONE_DURATION_MULT: float = 1.5
# Seuche (rein Gift).
const PLAGUE_MAX_TICKS: int = 14
const PLAGUE_BONUS_FROM: int = 6
const PLAGUE_BONUS_MAX: int = 4
const PLAGUE_CLOUD_RADIUS_MULT: float = 1.4
# Permafrost (rein Frost).
const PERMA_HITS: int = 3
const PERMA_WINDOW_MS: int = 2000
const PERMA_FREEZE: float = 0.7
const PERMA_IMMUNE_MS: int = 3700
const SHATTER_MULT: float = 1.5
const PERMA_TRAIL_DURATION_MULT: float = 2.0
# Hochspannung (rein Blitz).
const CHARGE_MAX: int = 5
const DISCHARGE_DAMAGE: float = 20.0
const DISCHARGE_STUN: float = 0.4
const DISCHARGE_RADIUS: float = 90.0
const DISCHARGE_COOLDOWN_MS: int = 2000
const HIGH_VOLTAGE_ZONE_MULT: float = 1.4

# --- Hilfen ---

static func world_enabled() -> bool:
	return Global.element_reactions_enabled

static func _authoritative() -> bool:
	return not (Global.network_mode and NetworkManager.is_client)

static func has_combo(src, combo: String) -> bool:
	return src is Player and is_instance_valid(src) and (src as Player).element_combos.has(combo)

static func _allowed(src, combo: String) -> bool:
	return world_enabled() or has_combo(src, combo)

static func state(t: Object) -> Dictionary:
	if not t.has_meta("elem"):
		t.set_meta("elem", {})
	return t.get_meta("elem")

static func _now() -> int:
	return Time.get_ticks_msec()

static func _ready(t: Object, key: String, ms: int = ICD_MS) -> bool:
	var st := state(t)
	var icd: Dictionary = st.get("icd", {})
	var now := _now()
	if now < int(icd.get(key, 0)):
		return false
	icd[key] = now + ms
	st["icd"] = icd
	return true

static func _alive(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t is HordeEnemy:
		return (t as HordeEnemy).is_alive()
	return float(t.get("current_health")) > 0.0

static func _fx_parent(t: Node) -> Node:
	return t.get_parent() if t != null and is_instance_valid(t) else null

static func _ring(at: Node, pos: Vector2, color: Color, radius: float, snd: String = "", vol: float = -4.0) -> void:
	var args := NetFx.ring_args(pos, color, 0.6, maxf(1.0, radius / 8.0), 0.22, 0.32, 3, true)
	if not snd.is_empty():
		args = NetFx.with_sound(args, snd, 0.15, vol)
	NetFx.emit(_fx_parent(at), "ring", args)

static func _zap(at: Node, a: Vector2, b: Vector2, color: Color) -> void:
	NetFx.emit(_fx_parent(at), "zap", NetFx.zap_args(a, b, color, 3.0, 0.2, 7, 12.0))

# Gegner der Quelle im Umkreis (Spieler anderer Teams und Horden-Gegner).
static func _enemies_near(src, pos: Vector2, radius: float, exclude = null) -> Array:
	var result: Array = []
	if src is Player and is_instance_valid(src):
		for e in (src as Player)._opponents_within(pos, radius):
			if e != exclude:
				result.append(e)
	return result

static func _hit(target, amount: float, src, knockback: Vector2 = Vector2.ZERO) -> void:
	if _alive(target) and amount > 0.0:
		target.take_damage(amount, knockback, src if is_instance_valid(src) else null)

static func _clear_poison(t) -> void:
	t.poison_ticks_left = 0
	if t is Player:
		(t as Player)._refresh_poison_visual()

# --- Treffer am Ziel ---

# Wird von apply_burn/apply_poison/apply_freeze/apply_stun aufgerufen, BEVOR der
# neue Status gesetzt wird, und nur wenn eine Quelle mitkommt (Element-Treffer).
# Rückgabe true = den neuen Status nicht setzen (er wurde von der Reaktion verbraucht).
static func on_element(target, element: String, src, amount: float = 0.0) -> bool:
	if not _authoritative() or not _alive(target) or src == null or not is_instance_valid(src) or src == target:
		return false
	if src is Player and (src as Player).is_replica:
		return false
	var st := state(target)
	match element:
		ElementSystem.FIRE:
			st["burn_src"] = src
			if target.poison_ticks_left > 0 and _allowed(src, "gasbrand") and _ready(target, "gas"):
				_gas_burst(target, src)
			if target.freeze_timer > 0.0 and _allowed(src, "dampf") and _ready(target, "thermo"):
				_thermo_shock(target, src)
				return true
			if has_combo(src, "dampf"):
				target.freeze_timer = maxf(target.freeze_timer, DAMPF_BURN_CHILL)
		ElementSystem.POISON:
			st["poison_src"] = src
			if has_combo(src, "giftreif"):
				target.freeze_timer = maxf(target.freeze_timer, GIFTREIF_POISON_CHILL)
		ElementSystem.FROST:
			st["frost_src"] = src
			if target.burn_ticks_left > 0 and _allowed(src, "dampf") and _ready(target, "thermo"):
				_thermo_shock(target, src)
				return true
			if has_combo(src, "permafrost"):
				_permafrost_hit(target, src, st)
		ElementSystem.LIGHTNING:
			if target.burn_ticks_left > 0 and _allowed(src, "plasma") and _ready(target, "plasma"):
				_spark_burst(target, src)
			if target.poison_ticks_left > 0 and _allowed(src, "neurotoxin") and _ready(target, "nerve"):
				target.stun_timer = maxf(target.stun_timer, minf(NERVE_STUN_MAX, maxf(amount, 0.1) * 2.0))
				_hit(target, float(target.poison_damage_per_tick), src)
				_ring(target, target.global_position, Color(0.7, 1.0, 0.3, 0.8), 26.0, "zap", -6.0)
			if target.freeze_timer > 0.0 and _allowed(src, "supraleiter") and _ready(target, "super"):
				var combo := has_combo(src, "supraleiter")
				st["vuln_until"] = _now() + (SUPER_MS_COMBO if combo else SUPER_MS)
				st["vuln_mult"] = SUPER_MULT_COMBO if combo else SUPER_MULT
				_ring(target, target.global_position, Color(0.6, 0.9, 1.0, 0.9), 30.0, "zap", -5.0)
			if has_combo(src, "hochspannung"):
				_charge_hit(target, src, st)
	return false

static func _gas_burst(target, src) -> void:
	var dmg := maxf(GAS_BURST_MIN, float(target.poison_ticks_left) * float(target.poison_damage_per_tick) * GAS_BURST_MULT)
	var pos: Vector2 = target.global_position
	_clear_poison(target)
	_ring(target, pos, Color(1.0, 0.6, 0.15, 0.9), GAS_BURST_RADIUS, "explosion", -6.0)
	_hit(target, dmg, src)
	for e in _enemies_near(src, pos, GAS_BURST_RADIUS, target):
		_hit(e, dmg * 0.5, src)

static func _thermo_shock(target, src) -> void:
	var dmg := THERMO_DAMAGE_COMBO if has_combo(src, "dampf") else THERMO_DAMAGE
	target.freeze_timer = 0.0
	target.burn_ticks_left = 0
	_ring(target, target.global_position, Color(0.92, 0.96, 1.0, 0.85), 34.0, "hit", -3.0)
	_hit(target, dmg, src)

static func _spark_burst(target, src) -> void:
	var pos: Vector2 = target.global_position
	var near := _enemies_near(src, pos, SPARK_RADIUS, target)
	var burn_dmg := 5.0
	if src is Player:
		burn_dmg = (src as Player).burn_damage_per_tick
	var n := 0
	for e in near:
		if n >= SPARK_COUNT:
			break
		e.apply_burn(SPARK_BURN, burn_dmg)
		_zap(target, pos, e.global_position, Color(1.0, 0.55, 0.2, 0.95))
		n += 1
	if n == 0:
		target.burn_ticks_left += SPARK_BURN
	_ring(target, pos, Color(1.0, 0.7, 0.3, 0.8), 22.0, "zap", -6.0)

static func _permafrost_hit(target, src, st: Dictionary) -> void:
	var now := _now()
	if now < int(st.get("freeze_immune_until", 0)):
		return
	var hits: Array = st.get("frost_hits", [])
	hits.append(now)
	while not hits.is_empty() and now - int(hits[0]) > PERMA_WINDOW_MS:
		hits.remove_at(0)
	st["frost_hits"] = hits
	if hits.size() < PERMA_HITS:
		return
	st["frost_hits"] = []
	st["freeze_immune_until"] = now + PERMA_IMMUNE_MS
	st["shatter"] = true
	target.apply_stun(PERMA_FREEZE)
	target.freeze_timer = maxf(target.freeze_timer, PERMA_FREEZE + 0.5)
	_ring(target, target.global_position, Color(0.7, 0.95, 1.0, 0.95), 30.0, "hit", -2.0)

static func _charge_hit(target, src, st: Dictionary) -> void:
	var now := _now()
	if now < int(st.get("charge_cd", 0)):
		return
	var charge := int(st.get("charge", 0)) + 1
	if charge < CHARGE_MAX:
		st["charge"] = charge
		return
	st["charge"] = 0
	st["charge_cd"] = now + DISCHARGE_COOLDOWN_MS
	var pos: Vector2 = target.global_position
	_ring(target, pos, Color(1.0, 0.95, 0.4, 0.95), DISCHARGE_RADIUS, "zap", -1.0)
	var victims := _enemies_near(src, pos, DISCHARGE_RADIUS, target)
	victims.append(target)
	for e in victims:
		_hit(e, DISCHARGE_DAMAGE, src)
		if _alive(e):
			e.stun_timer = maxf(e.stun_timer, DISCHARGE_STUN)
		if e != target:
			_zap(target, pos, e.global_position, Color(1.0, 1.0, 0.6, 0.95))

# Schaden, den ein Ziel gerade zusätzlich nimmt (Supraleiter, Zersplittern,
# Eissplitter-Karte). Aus Player.take_damage und HordeEnemy.take_damage.
static func damage_taken_mult(target, src) -> float:
	if not target.has_meta("elem") and not (src is Player):
		return 1.0
	var m := 1.0
	var st := state(target)
	if _now() < int(st.get("vuln_until", 0)):
		m *= float(st.get("vuln_mult", 1.0))
	if bool(st.get("shatter", false)) and src != null and is_instance_valid(src) and src != target:
		st["shatter"] = false
		m *= SHATTER_MULT
		_ring(target, target.global_position, Color(0.8, 0.97, 1.0, 0.95), 26.0, "hit", -2.0)
	if src is Player and is_instance_valid(src) and (src as Player).chill_damage_bonus > 0.0 \
			and float(target.get("freeze_timer")) > 0.0:
		m *= 1.0 + (src as Player).chill_damage_bonus
	return m

# --- Status-Ticks ---

# Gift-Tick-Intervall: Spröde (vergiftet + verlangsamt) tickt schneller.
static func poison_tick_interval(target, base: float) -> float:
	if float(target.freeze_timer) > 0.0:
		var src = state(target).get("poison_src", null) if target.has_meta("elem") else null
		if world_enabled() or has_combo(src, "giftreif"):
			return base * BRITTLE_TICK_MULT
	return base

# Seuche: ab 6 Stapeln tickt jeder weitere Stapel 1 Schaden stärker.
static func poison_tick_bonus(target) -> float:
	if not target.has_meta("elem"):
		return 0.0
	if not has_combo(state(target).get("poison_src", null), "seuche"):
		return 0.0
	return float(clampi(int(target.poison_ticks_left) - PLAGUE_BONUS_FROM, 0, PLAGUE_BONUS_MAX))

# Neue Stapel: Seuche und Lauffeuer addieren statt nur den Höchstwert zu nehmen.
static func stacked_poison_ticks(current: int, added: int, src) -> int:
	if has_combo(src, "seuche"):
		return mini(current + added, PLAGUE_MAX_TICKS)
	return maxi(current, added)

static func stacked_burn_ticks(current: int, added: int, src) -> int:
	if has_combo(src, "lauffeuer"):
		return mini(current + added, maxi(added * WILDFIRE_MAX_STACK_MULT, 9))
	return maxi(current, added)

# Lauffeuer: alle 1,2 s springt der Brand auf einen Gegner in der Nähe über.
static func on_burn_tick(target) -> void:
	if not _authoritative() or not target.has_meta("elem"):
		return
	var st := state(target)
	var src = st.get("burn_src", null)
	if not has_combo(src, "lauffeuer"):
		return
	var n := int(st.get("spread_n", 0)) + 1
	st["spread_n"] = n
	if n % WILDFIRE_SPREAD_TICKS != 0:
		return
	var pos: Vector2 = target.global_position
	for e in _enemies_near(src, pos, WILDFIRE_SPREAD_RADIUS, target):
		if int(e.burn_ticks_left) <= 0:
			e.apply_burn(2, (src as Player).burn_damage_per_tick, src)
			_zap(target, pos, e.global_position, Color(1.0, 0.5, 0.1, 0.9))
			break

# Seuche: Vergiftete platzen beim Tod zu einer Giftwolke.
static func on_death(target) -> void:
	if not _authoritative() or target == null or not target.has_meta("elem"):
		return
	if int(target.get("poison_ticks_left")) <= 0:
		return
	var src = state(target).get("poison_src", null)
	if has_combo(src, "seuche") and _alive(src):
		(src as Player).spawn_poison_cloud(target.global_position)

# --- Flächen ---

static func zone_element(kind: int) -> String:
	match kind:
		EffectZone.Kind.FIRE:
			return ElementSystem.FIRE
		EffectZone.Kind.POISON:
			return ElementSystem.POISON
		EffectZone.Kind.ICE:
			return ElementSystem.FROST
		EffectZone.Kind.LIGHTNING:
			return ElementSystem.LIGHTNING
	return ""

static func _reactive(z) -> bool:
	return z is EffectZone and is_instance_valid(z) and not z.is_replica and not z.visual_only \
		and not z.is_queued_for_deletion() and not z.has_meta("reacted") and not zone_element(z.kind).is_empty()

# Host: neue Zone wurde gesetzt. Trifft sie eine andere Fläche, reagieren beide.
static func on_zone_spawned(zone: EffectZone) -> void:
	if not _authoritative() or not _reactive(zone):
		return
	for node in zone.get_tree().get_nodes_in_group("effect_zone"):
		var other := node as EffectZone
		if other == zone or not _reactive(other):
			continue
		if zone.global_position.distance_to(other.global_position) > zone.radius + other.radius * 0.8:
			continue
		var src = zone.owner_player
		if react_zone(zone_element(zone.kind), other, src, zone.global_position):
			return
		if react_zone(zone_element(other.kind), zone, other.owner_player, other.global_position):
			return

# Host: ein Element-Geschoss schlägt ein. Liegt der Punkt in einer Fläche, reagiert sie.
static func on_impact(pos: Vector2, impact_elements: Array, src, tree: SceneTree) -> void:
	if not _authoritative() or impact_elements.is_empty() or tree == null:
		return
	for node in tree.get_nodes_in_group("effect_zone"):
		var z := node as EffectZone
		if not _reactive(z) or pos.distance_to(z.global_position) > z.radius + 6.0:
			continue
		for el in impact_elements:
			if react_zone(str(el), z, src, pos):
				break

# Element `element` trifft die Fläche `zone`. true = es gab eine Reaktion.
static func react_zone(element: String, zone: EffectZone, src, _at: Vector2) -> bool:
	if element.is_empty() or zone == null or not is_instance_valid(zone):
		return false
	var owner: Player = src as Player if src is Player and is_instance_valid(src) else zone.owner_player
	if owner == null or not is_instance_valid(owner):
		return false
	var pos := zone.global_position
	var k: int = zone.kind
	var fire := element == ElementSystem.FIRE
	var frost := element == ElementSystem.FROST
	var bolt := element == ElementSystem.LIGHTNING
	if fire and k == EffectZone.Kind.POISON:
		if not _allowed(owner, "gasbrand"):
			return false
		zone.set_meta("reacted", true)
		_ring(zone, pos, Color(1.0, 0.55, 0.12, 0.95), zone.radius * 1.2, "explosion", 0.0)
		for e in _enemies_near(owner, pos, zone.radius * 1.1):
			var push: Vector2 = (e.global_position - pos).normalized() * GAS_EXPLOSION_KNOCKBACK
			_hit(e, GAS_EXPLOSION_DAMAGE, owner, push)
			if _alive(e):
				e.apply_burn(GAS_EXPLOSION_BURN, owner.burn_damage_per_tick)
		Seesaw.blast_all(zone.get_tree(), pos, zone.radius * 1.2, 1.0)
		zone.end_zone()
		owner.spawn_fire_zone(pos)
		return true
	if (fire and k == EffectZone.Kind.ICE) or (frost and k == EffectZone.Kind.FIRE):
		if not _allowed(owner, "dampf"):
			return false
		zone.set_meta("reacted", true)
		zone.end_zone()
		_ring(zone, pos, Color(0.95, 0.97, 1.0, 0.7), zone.radius, "hit", -6.0)
		owner.spawn_effect_zone(EffectZone.Kind.STEAM, pos, maxf(40.0, zone.radius * 1.2), STEAM_DURATION, {
			"tick_interval": 0.5,
			"damage": STEAM_DAMAGE,
		})
		return true
	if bolt and k == EffectZone.Kind.FIRE:
		if not _allowed(owner, "plasma"):
			return false
		zone.set_meta("reacted", true)
		zone.end_zone()
		_ring(zone, pos, Color(0.95, 0.4, 1.0, 0.85), zone.radius, "zap", -3.0)
		owner.spawn_effect_zone(EffectZone.Kind.PLASMA, pos, zone.radius, PLASMA_DURATION, {
			"tick_interval": 0.25,
			"burn_stacks": 1,
			"burn_damage": owner.burn_damage_per_tick,
			"stun_duration": 0.1,
			"damage": 1.0,
		})
		return true
	if frost and k == EffectZone.Kind.POISON:
		if not _allowed(owner, "giftreif"):
			return false
		zone.set_meta("reacted", true)
		zone.end_zone()
		_ring(zone, pos, Color(0.7, 1.0, 0.85, 0.75), zone.radius, "hit", -6.0)
		owner.spawn_effect_zone(EffectZone.Kind.RIME, pos, zone.radius, RIME_DURATION, {
			"tick_interval": 0.5,
			"poison_stacks": 1,
			"poison_damage": owner.poison_damage_per_tick,
			"freeze_duration": 0.8,
		})
		return true
	if bolt and k == EffectZone.Kind.POISON:
		if not _allowed(owner, "neurotoxin"):
			return false
		zone.set_meta("reacted", true)
		zone.end_zone()
		_ring(zone, pos, Color(0.8, 1.0, 0.3, 0.85), zone.radius, "zap", -3.0)
		owner.spawn_effect_zone(EffectZone.Kind.TOXIC_STORM, pos, zone.radius, TOXIC_STORM_DURATION, {
			"tick_interval": 1.2,
			"damage": 3.0,
			"stun_duration": 0.15,
			"poison_stacks": 1,
			"poison_damage": owner.poison_damage_per_tick,
		})
		return true
	if bolt and k == EffectZone.Kind.ICE:
		if not _allowed(owner, "supraleiter"):
			return false
		_electrify_ice(zone, owner)
		return true
	return false

# Supraleiter: Die ganze zusammenhängende Eisfläche (Eisbahn) wird elektrisch.
static func _electrify_ice(start: EffectZone, owner: Player) -> void:
	var queue: Array = [start]
	var seen: Array = []
	while not queue.is_empty() and seen.size() < 14:
		var z: EffectZone = queue.pop_front()
		if seen.has(z):
			continue
		seen.append(z)
		z.set_meta("reacted", true)
		for node in z.get_tree().get_nodes_in_group("effect_zone"):
			var o := node as EffectZone
			if o != null and o.kind == EffectZone.Kind.ICE and _reactive(o) and not seen.has(o) \
					and o.global_position.distance_to(z.global_position) <= o.radius + z.radius + 6.0:
				queue.append(o)
	for z in seen:
		owner.spawn_effect_zone(EffectZone.Kind.LIGHTNING, z.global_position, z.radius, SUPER_ICE_DURATION, {
			"tick_interval": 0.3,
			"damage": 0.0,
			"stun_duration": 0.2,
			"no_react": true,
		})
	_ring(start, start.global_position, Color(0.6, 0.9, 1.0, 0.8), start.radius * 1.5, "zap", -2.0)
