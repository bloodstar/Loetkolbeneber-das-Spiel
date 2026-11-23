class_name SwitchNetwork
extends RefCounted

## Verdrahtung zwischen Schaltern (LevelSwitch) und dem, was sie steuern
## (SwitchGate, SwitchLaser, SwitchStrike). Jede Verbindung ist ein Kanal
## (Zahl). Ein Kanal ist an, solange mindestens ein Schalter auf ihm an ist.
## Ziele hören auf einen oder mehrere Kanäle (ein Ziel genau auf der
## Spiegelachse hört auf beide Seiten).
##
## Nur der Host schaltet. Clients bekommen den Zustand jedes Schalters und
## jedes Ziels über die normalen Snapshots der beweglichen Map-Objekte.

## Gespiegelte Kopien in symmetrischen Maps bekommen Kanal + MIRROR_OFFSET,
## damit jede Seite ihre eigenen Schalter hat.
const MIRROR_OFFSET: int = 100

## Farbe pro Kanal: Schalter und Ziele desselben Kanals tragen dieselbe
## Farbe, damit Spieler sehen, was zusammengehört. Die gespiegelte Seite
## nutzt dieselbe Farbe wie das Original.
const CHANNEL_COLORS: Array[Color] = [
	Color(1.0, 0.78, 0.2),   # 0 Bernstein
	Color(0.3, 0.9, 1.0),    # 1 Cyan
	Color(1.0, 0.35, 0.75),  # 2 Magenta
	Color(0.55, 1.0, 0.35),  # 3 Lindgrün
	Color(1.0, 0.5, 0.2),    # 4 Orange
	Color(0.65, 0.5, 1.0),   # 5 Violett
	Color(1.0, 1.0, 1.0),    # 6 Weiß
	Color(0.35, 0.6, 1.0),   # 7 Blau
]

var _switches: Array = []
var _targets: Array = []

static func channel_color(channel: int) -> Color:
	var base := posmod(channel, MIRROR_OFFSET)
	return CHANNEL_COLORS[base % CHANNEL_COLORS.size()]

func clear() -> void:
	_switches.clear()
	_targets.clear()

func add_switch(sw: Node) -> void:
	_switches.append(sw)
	sw.set("network", self)

func add_target(target: Node) -> void:
	_targets.append(target)
	target.set("network", self)

func get_switches() -> Array:
	return _switches.filter(func(s): return is_instance_valid(s))

func is_channel_on(channel: int) -> bool:
	for sw in _switches:
		if is_instance_valid(sw) and int(sw.channel) == channel and bool(sw.is_on):
			return true
	return false

## Ein Schalter hat umgeschaltet: alle betroffenen Ziele neu bewerten.
func on_switch_changed(channel: int) -> void:
	for t in _targets:
		if not is_instance_valid(t):
			continue
		var chans: Array = t.get("channels")
		if chans.has(channel):
			t.call("set_powered", _any_on(chans))

func _any_on(chans: Array) -> bool:
	for c in chans:
		if is_channel_on(int(c)):
			return true
	return false

## Ziele, die ein Schalter auf diesem Kanal beeinflusst.
func targets_for(channel: int) -> Array:
	var out: Array = []
	for t in _targets:
		if is_instance_valid(t) and (t.get("channels") as Array).has(channel):
			out.append(t)
	return out

## Für Bots: Was brächte es, den Schalter jetzt einzuschalten? Positiv =
## schadet dem Gegner oder öffnet den Weg, negativ = gefährdet den Bot.
## Zählt nur Ziele, deren Zustand sich dadurch wirklich ändert.
func bot_value_for(sw: Node, bot: Node2D, enemy: Node2D) -> float:
	if bool(sw.is_on):
		return 0.0
	var total := 0.0
	for t in targets_for(int(sw.channel)):
		if bool(t.get("powered")):
			continue # schon von einem anderen Schalter an
		total += float(t.call("bot_value", bot, enemy))
	return total
