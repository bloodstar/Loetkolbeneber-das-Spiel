extends Node2D

## Zeichnet die Statusanzeige direkt um den Charakter:
## - oben: Munitionsstriche oder ein Nachlade-Kreis
## - unten: Lebensbalken (mit blauem Schild-Overlay)
## Die Symbole für Barriere, Schild, Dash, Fähigkeit und Ulti stehen seit
## 2026-11-25 in der Fähigkeitenleiste im HUD (scripts/ui/ability_bar.gd).
##
## Der Node ist ein Kind des Players und übernimmt dessen Skalierung, damit die
## Anzeige bei Karten mit Größenänderungen mitwächst.

const TOP_Y: float = -31.0
const HEALTH_Y: float = 22.0
const HEALTH_WIDTH: float = 28.0
const HEALTH_HEIGHT: float = 2.4

const PANEL_COLOR: Color = Color(0.015, 0.02, 0.035, 0.66)
const PANEL_BORDER: Color = Color(0.92, 0.96, 1.0, 0.16)
const AMMO_COLOR: Color = Color(1.0, 0.80, 0.28, 0.96)
const AMMO_EMPTY: Color = Color(0.22, 0.24, 0.30, 0.82)
const RELOAD_COLOR: Color = Color(0.35, 0.86, 1.0, 0.96)
const HEALTH_LOW: Color = Color(0.95, 0.23, 0.20, 0.98)
const HEALTH_HIGH: Color = Color(0.35, 0.94, 0.45, 0.98)
const SHIELD_COLOR: Color = Color(0.30, 0.78, 1.0, 0.96)
const SHIELD_OVERLAY_COLOR: Color = Color(0.25, 0.55, 1.0, 0.72)
const MELEE_COLOR: Color = Color(1.0, 0.72, 0.42, 0.96)

var player: Player = null

func _ready() -> void:
	player = get_parent() as Player
	z_index = 10

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(player):
		return
	# Arena: auf Plattformen und im Sprung mit der Voxel-Figur nach oben
	# wandern (Versatz in Weltkoordinaten, der Node erbt die Player-Skalierung).
	var lift := player.arena_lift()
	if lift != Vector2.ZERO:
		var sc := global_scale
		draw_set_transform(Vector2(lift.x / maxf(absf(sc.x), 0.01), lift.y / maxf(absf(sc.y), 0.01)))
	_draw_weapon_status()
	_draw_health_bar()
	_draw_vampire_orbs()

# Fernkampf-Vampir: Blutkugeln im Vorrat kreisen um ihn.
func _draw_vampire_orbs() -> void:
	var n: int = player.vampire_orbs
	if n <= 0:
		return
	var t := float(Time.get_ticks_msec()) / 1000.0
	for i in range(n):
		var c: Vector2 = player.vampire_orb_offset(i)
		var pulse := 0.5 + 0.5 * sin(t * 6.0 + float(i))
		draw_circle(c, 5.5 + pulse, Color(0.9, 0.05, 0.12, 0.18))
		draw_circle(c, 3.6, Color(0.25, 0.0, 0.03, 0.9))
		draw_circle(c, 3.0, Color(0.80, 0.04, 0.10, 1.0))
		draw_circle(c + Vector2(-1.0, -1.1), 0.9, Color(1.0, 0.75, 0.75, 0.9))

func _draw_weapon_status() -> void:
	if player.is_melee:
		_draw_melee_bar()
	elif player.is_reloading:
		_draw_reload_ring()
	else:
		_draw_ammo_pips()

func _draw_ammo_pips() -> void:
	var count: int = maxi(0, player.max_ammo)
	if count <= 0:
		return
	var pip_width: float = 2.2
	var pip_height: float = 2.6
	var gap: float = 1.0
	var total_width: float = float(count) * pip_width + float(count - 1) * gap
	var start_x: float = -total_width * 0.5
	var panel := Rect2(start_x - 1.3, TOP_Y - 1.2, total_width + 2.6, pip_height + 2.4)
	draw_rect(panel, PANEL_COLOR, true)
	draw_rect(panel, PANEL_BORDER, false, 0.45, true)
	var filled: int = clampi(player.current_ammo, 0, count)
	for i in range(count):
		var pip := Rect2(start_x + float(i) * (pip_width + gap), TOP_Y, pip_width, pip_height)
		var color: Color = AMMO_COLOR if i < filled else AMMO_EMPTY
		draw_rect(pip, color, true)
		if i < filled:
			draw_rect(Rect2(pip.position, Vector2(pip.size.x, 0.55)), Color(1.0, 1.0, 1.0, 0.30), true)

# Nahkampfhelden: kurzer Balken, der sich bis zum nächsten Schlag füllt.
func _draw_melee_bar() -> void:
	var width: float = 14.0
	var height: float = 2.6
	var panel := Rect2(-width * 0.5 - 1.3, TOP_Y - 1.2, width + 2.6, height + 2.4)
	draw_rect(panel, PANEL_COLOR, true)
	draw_rect(panel, PANEL_BORDER, false, 0.45, true)
	var duration: float = maxf(0.001, player.melee_cooldown)
	var ratio: float = 1.0 - clampf(player.melee_cooldown_timer / duration, 0.0, 1.0)
	var color: Color = MELEE_COLOR if ratio >= 1.0 else Color(0.70, 0.52, 0.34, 0.9)
	draw_rect(Rect2(-width * 0.5, TOP_Y, width * ratio, height), color, true)

func _draw_reload_ring() -> void:
	var center := Vector2(0.0, TOP_Y + 1.3)
	var radius: float = 4.3
	draw_circle(center, radius + 1.4, PANEL_COLOR)
	draw_arc(center, radius, 0.0, TAU, 28, Color(0.92, 0.96, 1.0, 0.16), 1.1, true)
	var duration: float = maxf(0.001, player.reload_time)
	var remaining: float = clampf(player.reload_timer / duration, 0.0, 1.0)
	if remaining > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * remaining, 28, RELOAD_COLOR, 1.45, true)
	draw_circle(center, 1.1, RELOAD_COLOR)

func _draw_health_bar() -> void:
	var ratio: float = clampf(player.current_health / maxf(1.0, player.max_health), 0.0, 1.0)
	var background := Rect2(-HEALTH_WIDTH * 0.5 - 1.0, HEALTH_Y - 1.0, HEALTH_WIDTH + 2.0, HEALTH_HEIGHT + 2.0)
	draw_rect(background, PANEL_COLOR, true)
	draw_rect(background, PANEL_BORDER, false, 0.45, true)
	var color: Color = HEALTH_LOW.lerp(HEALTH_HIGH, smoothstep(0.15, 0.85, ratio))
	var fill := Rect2(-HEALTH_WIDTH * 0.5, HEALTH_Y, HEALTH_WIDTH * ratio, HEALTH_HEIGHT)
	if fill.size.x > 0.0:
		draw_rect(fill, color, true)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 0.55)), Color(1.0, 1.0, 1.0, 0.24), true)
	_draw_shield_overlay()

# Aktiver Schild als blaues Overlay über dem Lebensbalken. Die Breite ist
# relativ zum Maximalleben (50 Schild bei 100 Max HP = halber Balken) und wird
# auf die Balkenbreite gedeckelt. current_shield wird an alle Clients
# synchronisiert, daher sehen alle Spieler das Overlay.
func _draw_shield_overlay() -> void:
	if player.current_shield <= 0.0:
		return
	var ratio: float = clampf(player.current_shield / maxf(1.0, player.max_health), 0.0, 1.0)
	var overlay := Rect2(-HEALTH_WIDTH * 0.5, HEALTH_Y, HEALTH_WIDTH * ratio, HEALTH_HEIGHT)
	if overlay.size.x <= 0.0:
		return
	draw_rect(overlay, SHIELD_OVERLAY_COLOR, true)
	draw_rect(Rect2(overlay.position, Vector2(overlay.size.x, 0.55)), Color(0.85, 0.95, 1.0, 0.45), true)
	draw_rect(Rect2(overlay.end.x - 0.45, HEALTH_Y - 0.5, 0.45, HEALTH_HEIGHT + 1.0), SHIELD_COLOR, true)
	# Blutschild des Blutritters: Schild über 100 % Max-HP als zweite,
	# blutrote Lage darüber (bis 200 %).
	var extra: float = clampf((player.current_shield - player.max_health) / maxf(1.0, player.max_health), 0.0, 1.0)
	if extra > 0.0:
		var top := Rect2(-HEALTH_WIDTH * 0.5, HEALTH_Y, HEALTH_WIDTH * extra, HEALTH_HEIGHT)
		draw_rect(top, Color(0.85, 0.08, 0.20, 0.85), true)
		draw_rect(Rect2(top.end.x - 0.45, HEALTH_Y - 0.5, 0.45, HEALTH_HEIGHT + 1.0), Color(1.0, 0.55, 0.6, 1.0), true)
