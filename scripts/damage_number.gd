class_name DamageNumber
extends Node2D

## Aufsteigende Schadenszahl über einer Figur (Testraum). Liegt in der Welt,
## damit sie in der Seitenansicht und in der Arena an der Figur klebt.
## Treffer derselben Salve und kleine Dauerschaden-Ticks auf dasselbe Ziel werden über
## add_amount in dieselbe Zahl gerechnet.

const LIFETIME: float = 0.9
const RISE: float = 46.0
const MERGE_WINDOW: float = 0.3
const VOLLEY_WINDOW: float = 0.05
const TICK_MAX: float = 2.5

var amount: float = 0.0
var kind: String = "hit"
var color: Color = Color.WHITE
var age: float = 0.0
var _drift: float = 0.0
var _ticks: bool = false
var stack: int = 0
var _font: Font = null

func setup(value: float, hit_kind: String, at: Vector2) -> void:
	amount = value
	kind = hit_kind
	_ticks = value < TICK_MAX
	global_position = at
	_drift = randf_range(-14.0, 14.0)
	z_index = 120
	z_as_relative = false
	_refresh_color()

# Zusammengefasst werden nur Treffer derselben Salve (Mehrfachschuss,
# Splitter) und kleine Dauerschaden-Ticks (Gift, Brand, Lava).
func can_merge(hit_kind: String, value: float) -> bool:
	if kind != hit_kind or kind != "hit":
		return false
	if age < VOLLEY_WINDOW:
		return true
	return value < TICK_MAX and _ticks and age < MERGE_WINDOW

func add_amount(value: float) -> void:
	amount += value
	age = 0.0
	_refresh_color()
	queue_redraw()

func _ready() -> void:
	_font = UiTheme.FONT_BOLD

func _refresh_color() -> void:
	match kind:
		"block":
			color = UiTheme.INFO
		"immune":
			color = UiTheme.TEXT_MUTED
		"heal":
			color = UiTheme.SUCCESS
		_:
			# Große Treffer werden gelb bis orange.
			if amount >= 40.0:
				color = Color(1.0, 0.55, 0.25)
			elif amount >= 18.0:
				color = UiTheme.GOLD
			else:
				color = Color.WHITE

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	queue_redraw()

func _text() -> String:
	match kind:
		"block":
			return "BLOCK"
		"immune":
			return "IMMUN"
		"heal":
			return "+%s" % _fmt(amount)
	return _fmt(amount)

static func _fmt(v: float) -> String:
	if v < 10.0:
		return "%.1f" % v
	return str(int(round(v)))

func _draw() -> void:
	if _font == null:
		return
	var t := clampf(age / LIFETIME, 0.0, 1.0)
	# Kurzer Pop beim Erscheinen, dann ruhig nach oben und ausblenden.
	var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - age / 0.12)
	var size := int((16.0 + clampf(amount, 0.0, 60.0) * 0.18) * pop) if kind == "hit" else int(14.0 * pop)
	var offset := Vector2(_drift * t, -RISE * (1.0 - pow(1.0 - t, 2.0)))
	var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
	var text := _text()
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := offset + Vector2(-width * 0.5, 0.0)
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85 * alpha))
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
