extends StaticBody2D

## Trefferkörper eines Hebels (LevelSwitch). Kugeln und Nahkampf rufen
## hit_tile() am getroffenen Körper auf; der leitet an den Schalter weiter.

var owner_switch: Node = null

func hit_tile(amount: float = 0.0) -> void:
	if owner_switch != null and is_instance_valid(owner_switch):
		owner_switch.hit_tile(amount)
