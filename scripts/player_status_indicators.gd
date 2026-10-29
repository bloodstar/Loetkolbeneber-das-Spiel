extends Node2D

## Zeichnet die Statusanzeige direkt um den Charakter:
## - oben: Munitionsstriche oder ein Nachlade-Kreis
## - unten: Lebensbalken (mit blauem Schild-Overlay) sowie Symbole für Block, Schild, Dash und Fähigkeit
##
## Der Node ist ein Kind des Players und übernimmt dessen Skalierung, damit die
## Anzeige bei Karten mit Größenänderungen mitwächst.

const TOP_Y: float = -31.0
const HEALTH_Y: float = 22.0
const HEALTH_WIDTH: float = 28.0
const HEALTH_HEIGHT: float = 2.4
const ICON_Y: float = 30.0
const ICON_RADIUS: float = 3.2
const ICON_SPACING: float = 8.0

const PANEL_COLOR: Color = Color(0.015, 0.02, 0.035, 0.66)
const PANEL_BORDER: Color = Color(0.92, 0.96, 1.0, 0.16)
const AMMO_COLOR: Color = Color(1.0, 0.80, 0.28, 0.96)
const AMMO_EMPTY: Color = Color(0.22, 0.24, 0.30, 0.82)
const RELOAD_COLOR: Color = Color(0.35, 0.86, 1.0, 0.96)
const HEALTH_LOW: Color = Color(0.95, 0.23, 0.20, 0.98)
const HEALTH_HIGH: Color = Color(0.35, 0.94, 0.45, 0.98)
const SHIELD_COLOR: Color = Color(0.30, 0.78, 1.0, 0.96)
const SHIELD_OVERLAY_COLOR: Color = Color(0.25, 0.55, 1.0, 0.72)
const BLOCK_COLOR: Color = Color(0.55, 0.85, 1.0, 0.96)
const BLOCK_ACTIVE_COLOR: Color = Color(0.92, 0.98, 1.0, 1.0)
const DASH_COLOR: Color = Color(0.42, 0.88, 1.0, 0.96)
const ABILITY_COLOR: Color = Color(1.0, 0.82, 0.36, 0.96)
const READY_GLOW: Color = Color(1.0, 1.0, 1.0, 0.20)
const COOLDOWN_OVERLAY: Color = Color(0.01, 0.015, 0.03, 0.52)

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
	_draw_weapon_status()
	_draw_health_bar()
	_draw_status_icons()

func _draw_weapon_status() -> void:
	if player.is_reloading:
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

func _draw_status_icons() -> void:
	var icons: Array[String] = ["block"]
	if player.max_shield > 0.0:
		icons.append("shield")
	icons.append("dash")
	icons.append("ability")
	var start_x: float = -ICON_SPACING * float(icons.size() - 1) * 0.5
	for i in range(icons.size()):
		var center := Vector2(start_x + float(i) * ICON_SPACING, ICON_Y)
		match icons[i]:
			"block":
				_draw_block_icon(center)
			"shield":
				_draw_shield_icon(center)
			"dash":
				_draw_dash_icon(center)
			"ability":
				_draw_ability_icon(center)

func _draw_icon_background(center: Vector2, ready: bool) -> void:
	draw_circle(center, ICON_RADIUS + 0.6, PANEL_COLOR)
	draw_arc(center, ICON_RADIUS + 0.6, 0.0, TAU, 22, PANEL_BORDER, 0.45, true)
	if ready:
		draw_arc(center, ICON_RADIUS + 1.15, 0.0, TAU, 24, READY_GLOW, 0.55, true)

# Block (Taste Q): Wappen-Symbol. Während des Blocks hell, danach läuft die
# Abklingzeit als dunkler Kreissektor ab.
func _draw_block_icon(center: Vector2) -> void:
	var cooldown: float = maxf(0.0, player.block_cooldown_timer)
	var duration: float = maxf(0.001, player.block_cooldown)
	var active: bool = player.is_blocking
	var ready: bool = cooldown <= 0.0 and not active
	_draw_icon_background(center, ready or active)
	var color: Color = BLOCK_COLOR
	if active:
		color = BLOCK_ACTIVE_COLOR
	elif not ready:
		color = Color(0.34, 0.48, 0.60, 0.62)
	var points := PackedVector2Array([
		center + Vector2(-2.5, -2.2),
		center + Vector2(0.0, -3.2),
		center + Vector2(2.5, -2.2),
		center + Vector2(2.5, 0.7),
		center + Vector2(0.0, 3.2),
		center + Vector2(-2.5, 0.7),
	])
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.55 if active else 0.30))
	points.append(points[0])
	draw_polyline(points, color, 0.8, true)
	if active:
		draw_arc(center, ICON_RADIUS + 1.15, 0.0, TAU, 24, BLOCK_ACTIVE_COLOR, 0.7, true)
	elif not ready:
		_draw_cooldown_overlay(center, ICON_RADIUS + 0.6, cooldown / duration)

# Schild (Karten mit Max-Schild): Blase, der Ring zeigt die Schildfüllung.
func _draw_shield_icon(center: Vector2) -> void:
	var ratio: float = 0.0
	if player.max_shield > 0.0:
		ratio = clampf(player.current_shield / player.max_shield, 0.0, 1.0)
	_draw_icon_background(center, ratio > 0.0)
	var color: Color = SHIELD_COLOR if ratio > 0.0 else Color(0.30, 0.48, 0.62, 0.48)
	draw_circle(center, 2.4, Color(color.r, color.g, color.b, 0.22 if ratio <= 0.0 else 0.32))
	draw_arc(center, 2.4, 0.0, TAU, 20, color, 0.8, true)
	draw_arc(center + Vector2(-0.7, -0.7), 1.0, PI, PI * 1.5, 8, Color(1.0, 1.0, 1.0, 0.45), 0.5, true)
	if ratio > 0.0:
		draw_arc(center, ICON_RADIUS + 0.2, -PI * 0.5, -PI * 0.5 + TAU * ratio, 20, SHIELD_COLOR, 0.7, true)

func _draw_dash_icon(center: Vector2) -> void:
	var cooldown: float = maxf(0.0, player.dash_cooldown_timer)
	var duration: float = maxf(0.001, player.dash_cooldown)
	var ready: bool = cooldown <= 0.0
	_draw_icon_background(center, ready)
	var color: Color = DASH_COLOR if ready else Color(0.34, 0.52, 0.64, 0.62)
	var first := PackedVector2Array([
		center + Vector2(-2.6, -2.1),
		center + Vector2(-0.3, 0.0),
		center + Vector2(-2.6, 2.1),
	])
	var second := PackedVector2Array([
		center + Vector2(0.4, -2.1),
		center + Vector2(2.7, 0.0),
		center + Vector2(0.4, 2.1),
	])
	draw_polyline(first, color, 0.9, true)
	draw_polyline(second, color, 0.9, true)
	if not ready:
		_draw_cooldown_overlay(center, ICON_RADIUS + 0.6, cooldown / duration)

func _draw_ability_icon(center: Vector2) -> void:
	var cooldown: float = maxf(0.0, player.ability_timer)
	var duration: float = maxf(0.001, player.ability_max_cooldown)
	var ready: bool = cooldown <= 0.0
	_draw_icon_background(center, ready)
	var color: Color = ABILITY_COLOR if ready else Color(0.66, 0.56, 0.34, 0.62)
	var points := PackedVector2Array([
		center + Vector2(0.0, -3.3),
		center + Vector2(0.8, -0.8),
		center + Vector2(3.2, 0.0),
		center + Vector2(0.8, 0.8),
		center + Vector2(0.0, 3.3),
		center + Vector2(-0.8, 0.8),
		center + Vector2(-3.2, 0.0),
		center + Vector2(-0.8, -0.8),
	])
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.30))
	points.append(points[0])
	draw_polyline(points, color, 0.8, true)
	if not ready:
		_draw_cooldown_overlay(center, ICON_RADIUS + 0.6, cooldown / duration)

func _draw_cooldown_overlay(center: Vector2, radius: float, remaining_ratio: float) -> void:
	var ratio: float = clampf(remaining_ratio, 0.0, 1.0)
	if ratio <= 0.0:
		return
	var points := PackedVector2Array()
	points.append(center)
	var segments: int = maxi(4, int(ceil(28.0 * ratio)))
	for i in range(segments + 1):
		var angle: float = -PI * 0.5 + TAU * ratio * float(i) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, COOLDOWN_OVERLAY)
	draw_arc(center, radius + 0.25, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28, Color(1.0, 1.0, 1.0, 0.20), 0.45, true)
