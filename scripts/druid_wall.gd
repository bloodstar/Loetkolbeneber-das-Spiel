class_name DruidWall
extends StaticBody2D

# Rankenwand des Druiden (Fähigkeit "Wurzelwall"). Eine feste Wand quer zur
# Zielrichtung: blockt Bewegung und Kugeln aller Spieler, man kann darauf
# stehen. Kugeln und Nahkampf beschädigen sie (hit_tile); nach Ablauf der
# Dauer oder bei 0 HP zerfällt sie.
#
# Seitenansicht: lokale x-Achse = Länge der Wand, y = Dicke. Zielt man eher
# waagerecht, steht die Wand senkrecht auf dem Boden.
# Arena: Grundriss in der 2D-Ebene, Höhe ARENA_HEIGHT (Physik-Bänder 0..2);
# ArenaView3D zeigt sie als 3D-Block.
#
# Der Host simuliert Lebensdauer, Schaden und Berührungen (Elementarwand,
# Lebensborke). Clients bekommen Lage und Zustand über den Snapshot
# (main.gd "dwalls") und haben nur Kollision + Optik.

const TOUCH_INTERVAL: float = 0.1
# Abstand, ab dem ein Spieler die Wand "berührt" (zusätzlich zur Körperbox).
const TOUCH_MARGIN: float = 6.0
const FADE_IN: float = 0.18
const FADE_OUT: float = 0.45
const ARENA_HEIGHT: float = 108.0
const HIT_FLASH_TIME: float = 0.12

static var _next_net_id: int = 1

var net_id: int = 0
var is_replica: bool = false
var owner_player: Player = null
var owner_index: int = 0
var owner_team: int = -1

var length: float = 108.0
var thickness: float = 22.0
var duration: float = 5.0
var max_hp: float = 150.0
var hp: float = 150.0
# Evolutionen
var elemental: bool = false
var element_interval: float = 0.6
var heal_per_sec: float = 0.0

var _age: float = 0.0
var _touch_timer: float = 0.0
var _element_cooldowns: Dictionary = {}  # Spieler-Instanz-ID -> Restzeit
var _broken: bool = false
var _hit_flash: float = 0.0
var _anim_time: float = 0.0
var _healing_now: bool = false
var _shape: RectangleShape2D = null
# Farbe des Elements (aus den Waffeneffekten des Besitzers) für die Optik.
var element_color: Color = Color(0, 0, 0, 0)
# Nur Optik (Clients): verbleibende Sekunden laut Host.
var _left: float = 5.0

func _ready() -> void:
	add_to_group("solid")
	add_to_group("druid_wall")
	add_to_group("round_effect")
	if not is_replica:
		net_id = _next_net_id
		_next_net_id += 1
	collision_layer = ArenaMode.band_mask_range(0.0, ARENA_HEIGHT) if ArenaMode.active else 1
	collision_mask = 0
	var col := CollisionShape2D.new()
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(length, thickness)
	col.shape = _shape
	add_child(col)
	z_index = 1
	queue_redraw()

func setup(owner: Player, wall_length: float, wall_thickness: float, wall_duration: float, wall_hp: float) -> void:
	owner_player = owner
	owner_index = owner.player_index
	owner_team = owner.team_id
	length = wall_length
	thickness = wall_thickness
	duration = wall_duration
	max_hp = wall_hp
	hp = wall_hp

func remaining_time() -> float:
	return maxf(0.0, duration - _age)

func _physics_process(delta: float) -> void:
	if is_replica:
		return
	_age += delta
	if _age >= duration:
		crumble(false)
		return
	_touch_timer -= delta
	for key in _element_cooldowns.keys():
		_element_cooldowns[key] = float(_element_cooldowns[key]) - delta
	if _touch_timer <= 0.0:
		_touch_timer = TOUCH_INTERVAL
		_check_touches()

func _process(delta: float) -> void:
	_anim_time += delta
	_hit_flash = maxf(0.0, _hit_flash - delta)
	if is_replica:
		_age += delta
		_left = maxf(0.0, _left - delta)
	else:
		_left = remaining_time()
	queue_redraw()

# --- Berührungen (nur Host) ---

func _check_touches() -> void:
	var owner_ok := is_instance_valid(owner_player) and not owner_player.is_dead
	_healing_now = false
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p) or p.is_dead or p.current_health <= 0.0 or not p.visible:
			continue
		if not touches(p):
			continue
		if p == owner_player:
			if heal_per_sec > 0.0 and p.current_health < p.max_health:
				p.heal(heal_per_sec * TOUCH_INTERVAL)
				_healing_now = true
			continue
		if not elemental or not owner_ok or p.team_id == owner_team:
			continue
		var pid := p.get_instance_id()
		if float(_element_cooldowns.get(pid, 0.0)) > 0.0:
			continue
		_element_cooldowns[pid] = element_interval
		owner_player.apply_druid_wall_elements(p, global_position)

## Berührt Spieler p die Wand? Prüft die Körperbox im Koordinatensystem der Wand.
func touches(p: Player) -> bool:
	var center: Vector2 = p.global_position
	var half := Vector2(16.0, 24.0)
	var cs = p.get("collision_shape")
	if cs is CollisionShape2D and is_instance_valid(cs) and cs.shape is RectangleShape2D:
		center = cs.global_position
		half = (cs.shape as RectangleShape2D).size * 0.5 * cs.global_scale.abs()
	if ArenaMode.active and p.arena_z > ARENA_HEIGHT + TOUCH_MARGIN:
		return false
	var local := to_local(center)
	# Achsparallele Körperbox auf die Achsen der gedrehten Wand projiziert.
	var c := absf(cos(rotation))
	var sn := absf(sin(rotation))
	var hx := c * half.x + sn * half.y + TOUCH_MARGIN
	var hy := sn * half.x + c * half.y + TOUCH_MARGIN
	return absf(local.x) <= length * 0.5 + hx and absf(local.y) <= thickness * 0.5 + hy

## Schiebt Spieler, die beim Aufbau in der Wand stecken, zur nächsten Seite hinaus.
func push_out_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or not is_instance_valid(p) or p.is_dead:
			continue
		var local := to_local(p.global_position)
		var body_r := 18.0 * maxf(p.scale.x, 0.3) / Player.BASE_CHARACTER_SCALE
		if absf(local.x) > length * 0.5 + body_r * 0.5 or absf(local.y) > thickness * 0.5 + body_r:
			continue
		var side := 1.0 if local.y >= 0.0 else -1.0
		# Lokale y-Achse zeigt von der Zielrichtung weg: Der Besitzer bleibt
		# immer auf seiner Seite (hinter der Wand).
		if p == owner_player:
			side = 1.0
		var out_local := Vector2(local.x, side * (thickness * 0.5 + body_r + 2.0))
		p.global_position = to_global(out_local)

# --- Schaden ---

# Wird von Kugeln (Bullet._handle_collision) und Nahkampf aufgerufen.
func hit_tile(amount: float = 0.0) -> void:
	if is_replica or _broken:
		return
	hp -= maxf(amount, 0.0)
	_hit_flash = HIT_FLASH_TIME
	if hp <= 0.0:
		crumble(true)

## Wand zerfällt. destroyed = durch Schaden (lauter), sonst Zeitablauf.
func crumble(destroyed: bool) -> void:
	if _broken:
		return
	_broken = true
	if get_parent() != null:
		NetFx.emit(get_parent(), "ring", NetFx.with_sound(NetFx.ring_args(global_position,
			Color(0.45, 0.75, 0.3, 0.8), 1.0, maxf(length, 40.0) / 16.0, 0.2, 0.35),
			"hit" if destroyed else "poison", 0.2, -4.0 if destroyed else -10.0))
	queue_free()

# Ohne Effekt entfernen (älteste Wand, wenn das Limit erreicht ist).
func discard() -> void:
	crumble(false)

# --- Netzwerk ---

func get_network_state() -> Dictionary:
	return {
		"id": net_id,
		"pos": global_position,
		"rot": rotation,
		"len": length,
		"th": thickness,
		"hp": clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0),
		"left": remaining_time(),
		"el": element_color,
		"heal": _healing_now,
		"hv": heal_per_sec > 0.0,
	}

func apply_network_state(data: Dictionary) -> void:
	global_position = data.get("pos", global_position)
	rotation = float(data.get("rot", rotation))
	var new_len := float(data.get("len", length))
	var new_th := float(data.get("th", thickness))
	if not is_equal_approx(new_len, length) or not is_equal_approx(new_th, thickness):
		length = new_len
		thickness = new_th
		if _shape != null:
			_shape.size = Vector2(length, thickness)
	var new_hp := float(data.get("hp", 1.0))
	if new_hp < hp / maxf(max_hp, 1.0) - 0.001:
		_hit_flash = HIT_FLASH_TIME
	max_hp = 1.0
	hp = new_hp
	_left = float(data.get("left", _left))
	var el = data.get("el", element_color)
	if el is Color:
		element_color = el
	_healing_now = bool(data.get("heal", false))
	heal_per_sec = 1.0 if bool(data.get("hv", false)) else 0.0

func remove_replica() -> void:
	queue_free()

# --- Darstellung ---

## Deckkraft für Ein-/Ausblenden (auch von ArenaView3D genutzt).
func visual_alpha() -> float:
	var a := 1.0
	if _age < FADE_IN:
		a = _age / FADE_IN
	if _left < FADE_OUT:
		a = minf(a, 0.35 + 0.65 * _left / FADE_OUT)
	return clampf(a, 0.0, 1.0)

## Grundfarbe der Wand (Rinde), mit Element- und Heiltönung.
func base_color() -> Color:
	var bark := Color(0.42, 0.29, 0.17)
	if element_color.a > 0.0:
		bark = bark.lerp(Color(element_color.r, element_color.g, element_color.b), 0.35)
	if _hit_flash > 0.0:
		bark = bark.lerp(Color(1, 1, 1), 0.5 * _hit_flash / HIT_FLASH_TIME)
	return bark

func hp_fraction() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)

func _draw() -> void:
	# In der Arena zeigt ArenaView3D den Block; die 2D-Ebene liegt auf dem Boden.
	if ArenaMode.active:
		return
	var alpha := visual_alpha()
	var half := Vector2(length, thickness) * 0.5
	var bark := base_color()
	bark.a = alpha
	var dark := bark.darkened(0.45)
	var rect := Rect2(-half, half * 2.0)
	draw_rect(rect, bark, true)
	# Holzmaserung längs der Wand.
	for i in range(3):
		var y := -half.y + thickness * (0.25 + 0.25 * float(i))
		draw_line(Vector2(-half.x + 3.0, y), Vector2(half.x - 3.0, y), Color(dark.r, dark.g, dark.b, alpha * 0.55), 1.5)
	draw_rect(rect, Color(dark.r, dark.g, dark.b, alpha), false, 2.0)
	# Ranken mit Blättern, die sich um die Wand winden.
	var vine := Color(0.28, 0.62, 0.22, alpha)
	var leaf := Color(0.42, 0.82, 0.30, alpha)
	var pts := PackedVector2Array()
	var steps := maxi(6, int(length / 8.0))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(-half.x + 2.0, half.x - 2.0, t)
		pts.append(Vector2(x, sin(t * TAU * length / 70.0 + 0.6) * half.y * 0.7))
	draw_polyline(pts, vine, 2.2, true)
	for i in range(1, steps, 2):
		var p := pts[i]
		var sway := sin(_anim_time * 2.4 + float(i)) * 1.2
		var dir := 1.0 if i % 4 == 1 else -1.0
		var tip := p + Vector2(3.0 + sway, dir * (5.0 + absf(sway)))
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(4.5, dir * 1.5), tip, p + Vector2(0.5, dir * 3.5)]), leaf)
	# Risse bei wenig Leben.
	var frac := hp_fraction()
	if frac < 0.66:
		var crack := Color(0.1, 0.06, 0.03, alpha)
		draw_polyline(PackedVector2Array([Vector2(-half.x * 0.3, -half.y), Vector2(-half.x * 0.2, 0.0), Vector2(-half.x * 0.35, half.y)]), crack, 1.5)
	if frac < 0.33:
		var crack2 := Color(0.1, 0.06, 0.03, alpha)
		draw_polyline(PackedVector2Array([Vector2(half.x * 0.4, -half.y), Vector2(half.x * 0.25, -half.y * 0.2), Vector2(half.x * 0.45, half.y)]), crack2, 1.5)
	# Elementarwand: glimmender Rand in der Elementfarbe.
	if element_color.a > 0.0:
		var glow := element_color
		glow.a = alpha * (0.45 + 0.25 * sin(_anim_time * 5.0))
		draw_rect(rect.grow(2.0), glow, false, 2.5)
	# Lebensborke: sanft pulsierender grüner Schimmer, heller beim Heilen.
	if heal_per_sec > 0.0:
		var pulse := 0.2 + 0.15 * sin(_anim_time * 3.0) + (0.3 if _healing_now else 0.0)
		draw_rect(rect.grow(4.0), Color(0.5, 1.0, 0.55, alpha * pulse), false, 3.0)
