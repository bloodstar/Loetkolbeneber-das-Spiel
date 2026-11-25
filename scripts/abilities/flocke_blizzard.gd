class_name FlockeBlizzard
extends Node2D

## Flockes Ulti: Schneesturm am Zielpunkt (nur Host/Offline). Schadet allen
## Gegnern im Radius, verlangsamt sie stark und lässt jeden einfrieren, der
## lange genug am Stück darin steht. Die Optik ist eine eigene EffectZone
## (Kind.BLIZZARD, visual_only), damit sie auch auf Clients erscheint.

var owner_player: Player
var radius: float = 120.0
var duration: float = 5.0
var tick_damage: float = 2.5
var _elapsed: float = 0.0
var _tick: float = 0.0
## Instanz-ID des Gegners -> Sekunden am Stück im Sturm.
var _inside: Dictionary = {}

func setup(p_owner: Player, p_radius: float, p_duration: float, p_tick_damage: float) -> void:
	owner_player = p_owner
	radius = p_radius
	duration = p_duration
	tick_damage = p_tick_damage

func _ready() -> void:
	add_to_group("round_effect")

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration or owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = Player.FLOCKE_BLIZZARD_TICK
	var seen := {}
	for e in owner_player._opponents_within(global_position, radius):
		var id: int = e.get_instance_id()
		seen[id] = true
		owner_player._ability_hit(e, tick_damage, Vector2.ZERO)
		if not is_instance_valid(e):
			continue
		e.apply_freeze(Player.FLOCKE_BLIZZARD_CHILL, owner_player)
		var t: float = float(_inside.get(id, 0.0)) + Player.FLOCKE_BLIZZARD_TICK
		if t >= Player.FLOCKE_BLIZZARD_FREEZE_AFTER:
			# Eingefroren: kurz bewegungsunfähig, danach eine Pause, bevor es
			# erneut zählt.
			e.apply_stun(Player.FLOCKE_BLIZZARD_FREEZE)
			e.freeze_timer = maxf(float(e.freeze_timer), Player.FLOCKE_BLIZZARD_FREEZE + 0.6)
			NetFx.emit(get_parent(), "ring", NetFx.ring_args(e.global_position, Color(0.85, 0.97, 1.0, 0.95),
					1.0, 4.0, 0.15, 0.3, 3, true))
			t = -1.0
		_inside[id] = t
	for id in _inside.keys():
		if not seen.has(id):
			_inside.erase(id)

## Wie lange ein Gegner schon im Sturm steht (Tests, Bots).
func time_inside(target: Node) -> float:
	return float(_inside.get(target.get_instance_id(), 0.0))
