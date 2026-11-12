class_name NetEntity
extends RefCounted

# Kleine Gemeinsamkeit für Fähigkeits-Objekte, die der Host simuliert und
# Clients über den Snapshot ("ents" in main.gd) nachbauen: Köder, Kugelblitz
# und künftige Objekte neuer Helden. Jedes Objekt liegt in der Gruppe
# GROUP, hat net_id, is_replica, get_network_state() (mit "id" und "k"),
# apply_network_state() und remove_replica().

const GROUP: String = "net_entity"

static var _next_id: int = 1

static func next_id() -> int:
	var id := _next_id
	_next_id += 1
	return id

# Baut auf dem Client das passende Objekt für einen Snapshot-Eintrag.
static func create_replica(kind: String) -> Node2D:
	match kind:
		"decoy":
			return PhantomDecoy.new()
		"orb":
			return BallLightning.new()
	return null
