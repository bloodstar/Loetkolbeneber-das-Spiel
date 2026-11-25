class_name VoxelBoar
extends Node3D

## Entwurf: Eber aus echten Voxeln (gleich große Würfel) statt aus frei
## skalierten Quadern. Jedes Körperteil ist ein eigenes Voxel-Gitter mit
## eigenem Drehpunkt, wird zu EINEM Mesh mit Vertex-Farben zusammengefügt
## (verdeckte Flächen fallen weg) und bekommt Voxel-Ambient-Occlusion, damit
## Kanten und Fugen ohne Texturen plastisch wirken.
##
## Baukasten: build(spec) nimmt ein Dictionary wie die Teile von PigModular.
## Jeder Schlüssel ist austauschbar und hat einen Standardwert (default_spec()).
##   body    normal | slim | strong        Rumpf, Beinlänge, Schultern
##   head    normal | big                   Kopfgröße
##   snout   normal | short | long | wide   Rüssel
##   ears    up | flop | pointy | small     Ohren
##   tusks   none | small | big             Hauer
##   mane    bool                           Borstenkamm über Kopf und Rücken
##   tail    curly | straight | tuft        Schwanz
##   gender  male | female                  Körperbau (weiblich: Taille, Hüfte,
##                                          Oberweite mit Ausschnitt, Wimpern)
##   bottom  shorts | pants | skirt | none  Hose oder Minirock
##   top     none | muscle | robe | tank    Oberteil (tank = Top mit Ausschnitt)
##   outfit  Helden-ID (ignis, volt, ...)   feste Klassen-Kopfbedeckung
##   fur, pants, accent, tip, top_color     Farben
##
## Koordinaten: 1 Voxel = VOX Pixel der 2D-Welt. +X ist vorn (Blick-
## richtung, wie VoxelPig), +Y oben, Z seitlich. Füße stehen auf y = 0.
## Die API (animate/flash/recoil) entspricht VoxelPig, damit die Figur im
## Arena-Modus direkt austauschbar ist.

const VOX: float = 1.55
const HIT_FLASH_TIME: float = 0.14

const PRESETS: Dictionary = {
	"Grundkörper": {},
	"Schlank": {"body": "slim", "snout": "long", "ears": "pointy", "tusks": "small", "tail": "straight", "bottom": "pants"},
	"Kräftig": {"body": "strong", "head": "big", "snout": "wide", "ears": "flop", "tusks": "small", "top": "muscle"},
	"Keiler": {"body": "strong", "snout": "long", "ears": "small", "tusks": "big", "mane": true, "tail": "tuft",
		"fur": Color(0.47, 0.33, 0.25), "pants": Color(0.3, 0.27, 0.2)},
	"Frischling": {"body": "slim", "head": "big", "snout": "short", "ears": "up", "tusks": "none", "bottom": "shorts",
		"fur": Color(0.93, 0.68, 0.72)},
}

var spec: Dictionary = {}
var _pose: Node3D            # Stauchen/Strecken, Neigung (Drehpunkt am Boden)
var _body: Node3D            # Rumpf, wippt beim Laufen
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Node3D
var _iron: Node3D
var _lids: Node3D
var _mat: StandardMaterial3D
var _mats: Array[StandardMaterial3D] = []
var _base_emission: Array = []
var _glow_mats: Dictionary = {}
var _last_alpha: float = 1.0
## Silhouette durch Mauern zeigen (Arena). Vor build() setzen.
var xray: bool = false
## Zielwinkel nach oben (Bogenmaß, + = hoch). Dreht Lötkolben-Arm mit.
var aim_pitch: float = 0.0
var _bound_spec: Dictionary = {}
var _spec_timer: float = 0.0
var _last_state: Dictionary = {}
var _head_y: float = 0.0
var _hip_y: float = 0.0

var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _time: float = 0.0
var _flash: float = 0.0
var _recoil: float = 0.0
var _squash: float = 0.0
var _squash_vel: float = 0.0
var _lean: Vector2 = Vector2.ZERO
var _blink: float = 2.0
var _was_airborne: bool = false

static func default_spec() -> Dictionary:
	return {
		"gender": "male", "body": "normal", "head": "normal", "snout": "normal", "ears": "up", "tusks": "small",
		"mane": false, "tail": "curly", "bottom": "shorts", "top": "none", "outfit": "",
		"fur": Color(0.91, 0.60, 0.67), "pants": Color(0.25, 0.35, 0.8),
		"accent": Color(1.0, 0.85, 0.3), "tip": Color(0.6, 0.85, 1.0), "top_color": Color(0.9, 0.9, 0.92),
	}

static func preset_spec(preset_name: String, overrides: Dictionary = {}) -> Dictionary:
	var s := default_spec()
	s.merge(PRESETS.get(preset_name, {}), true)
	s.merge(overrides, true)
	return s

## Übersetzt die 2D-Baukasten-Teile (PigModular) und das Aussehen eines
## Spielers in eine Voxel-Spec. So bestimmt die Lobby-Auswahl weiter, wie der
## Eber aussieht, ohne dass es eigene Voxel-Einstellungen braucht.
static func spec_from_look(look: Dictionary, parts: Dictionary) -> Dictionary:
	var s := default_spec()
	if look.has("fur"):
		s["fur"] = look["fur"]
	if look.has("pants"):
		s["pants"] = look["pants"]
	if look.has("wand_tip_color"):
		s["tip"] = look["wand_tip_color"]
	match str(look.get("tusk_shape", "small")):
		"none": s["tusks"] = "none"
		"long", "double", "saber": s["tusks"] = "big"
		_: s["tusks"] = "small"
	match str(parts.get("body", "original")):
		"slim": s["body"] = "slim"
		"comic", "boar": s["body"] = "strong"
		"mascot": s["head"] = "big"
	match str(parts.get("snout", "round")):
		"wide", "chubby", "boar": s["snout"] = "wide"
		"small", "heart": s["snout"] = "short"
		"long": s["snout"] = "long"
	match str(parts.get("ears", "floppy")):
		"floppy": s["ears"] = "flop"
		"pointy", "bat": s["ears"] = "pointy"
		"round", "small", "none": s["ears"] = "small"
		_: s["ears"] = "up"
	var hair := str(parts.get("hair", "tuft"))
	s["mane"] = hair == "mane" or hair == "mohawk" or str(parts.get("body", "")) == "boar"
	match str(parts.get("tail", "curly")):
		"straight", "droopy", "short": s["tail"] = "straight"
		"bushy": s["tail"] = "tuft"
		_: s["tail"] = "curly"
	match str(parts.get("bottom", "shorts")):
		"pants", "long_skirt": s["bottom"] = "pants"
		"mini_skirt": s["bottom"] = "skirt"
		_: s["bottom"] = "shorts"
	s["gender"] = "female" if str(parts.get("gender", "male")) == "female" else "male"
	match str(parts.get("top", "none")):
		"muscle", "bikini": s["top"] = "muscle"
		"robe": s["top"] = "robe"
		_: s["top"] = "none"
	var tc = parts.get("top_color", null)
	if tc is Color:
		s["top_color"] = tc
	return s

## Spec für einen Spieler-Slot: Aussehen + Baukasten aus Global, Klassen-
## Outfit nach Held, Akzent (Gürtelschnalle, Ring) in Teamfarbe.
static func spec_for_player(index: int, accent: Color, hero_id: String) -> Dictionary:
	var s := spec_from_look(Global.get_pig_appearance(index), Global.get_pig_parts(index))
	s["outfit"] = hero_id
	# Flocke als Bot ist immer die Eismagierin; Menschen wählen den Körperbau selbst.
	if hero_id == "flocke" and Global.is_bot_slot(index):
		s["gender"] = "female"
		if str(s.get("top", "none")) == "none":
			s["top"] = "robe"
			s["top_color"] = Color(0.55, 0.82, 0.98)
	s["accent"] = accent
	return s

# ---------------------------------------------------------------------------
# Voxel-Gitter: Vector3i -> [Color, Leuchtkraft]
# ---------------------------------------------------------------------------

class Grid extends RefCounted:
	var cells: Dictionary = {}
	func put(p: Vector3i, c: Color, glow: float = 0.0) -> void:
		cells[p] = [c, glow]
	func has(p: Vector3i) -> bool:
		return cells.has(p)
	func erase(p: Vector3i) -> void:
		cells.erase(p)
	## Quader von a bis b (beide inklusive).
	func fill(a: Vector3i, b: Vector3i, c: Variant, glow: float = 0.0) -> void:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
				for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
					var p := Vector3i(x, y, z)
					put(p, _col(c, p), glow)
	## Ellipsoid um center (Voxel-Mittelpunkte zählen), Radien r.
	func ellipsoid(center: Vector3, r: Vector3, c: Variant) -> void:
		for x in range(floori(center.x - r.x), ceili(center.x + r.x) + 1):
			for y in range(floori(center.y - r.y), ceili(center.y + r.y) + 1):
				for z in range(floori(center.z - r.z), ceili(center.z + r.z) + 1):
					var d := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5) - center) / r
					if d.length_squared() <= 1.0:
						var p := Vector3i(x, y, z)
						put(p, _col(c, p))
	## Abgerundeter Quader: Ecken werden weggeschnitten (Superellipse).
	func rounded(center: Vector3, half: Vector3, c: Variant, power: float = 4.0) -> void:
		for x in range(floori(center.x - half.x), ceili(center.x + half.x) + 1):
			for y in range(floori(center.y - half.y), ceili(center.y + half.y) + 1):
				for z in range(floori(center.z - half.z), ceili(center.z + half.z) + 1):
					var d := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5) - center) / half
					if pow(absf(d.x), power) + pow(absf(d.y), power) + pow(absf(d.z), power) <= 1.0:
						var p := Vector3i(x, y, z)
						put(p, _col(c, p))
	## Quader mit runden Kanten (Radius r in Voxeln): flache Seiten, weiche
	## Kanten. Wirkt ruhiger als Ellipsoide, die überall Treppen bilden.
	func round_box(center: Vector3, half: Vector3, r: float, c: Variant) -> void:
		var inner := (half - Vector3(r, r, r)).max(Vector3.ZERO)
		for x in range(floori(center.x - half.x), ceili(center.x + half.x) + 1):
			for y in range(floori(center.y - half.y), ceili(center.y + half.y) + 1):
				for z in range(floori(center.z - half.z), ceili(center.z + half.z) + 1):
					var q := (Vector3(x, y, z) + Vector3(0.5, 0.5, 0.5) - center).abs() - inner
					if q.max(Vector3.ZERO).length() <= r + 0.05 and q.x <= r and q.y <= r and q.z <= r:
						var p := Vector3i(x, y, z)
						put(p, _col(c, p))
	## Färbt vorhandene Voxel um, wenn die Bedingung zutrifft.
	func recolor(cond: Callable, c: Variant) -> void:
		for p in cells.keys():
			if cond.call(p):
				cells[p] = [_col(c, p), cells[p][1]]
	## Vorderste belegte x-Position in Zeile (y, z), sonst -999.
	func front_x(y: int, z: int) -> int:
		var best := -999
		for p in cells.keys():
			if p.y == y and p.z == z and p.x > best:
				best = p.x
		return best
	func top_y(x: int, z: int) -> int:
		var best := -999
		for p in cells.keys():
			if p.x == x and p.z == z and p.y > best:
				best = p.y
		return best
	func _col(c: Variant, p: Vector3i) -> Color:
		if c is Callable:
			return c.call(p)
		return c

# ---------------------------------------------------------------------------
# Aufbau
# ---------------------------------------------------------------------------

func build(p_spec: Dictionary) -> void:
	spec = default_spec()
	spec.merge(p_spec, true)
	for ch in get_children():
		ch.queue_free()
	_legs.clear()
	_arms.clear()
	_ears.clear()
	_mats.clear()
	_base_emission.clear()
	_glow_mats.clear()
	_last_alpha = 1.0
	_mat = _new_material()
	_pose = Node3D.new()
	add_child(_pose)
	_body = Node3D.new()
	_pose.add_child(_body)

	var fur: Color = spec["fur"]
	var body: String = spec["body"]
	# Grundmaße je Körperbau (in Voxeln)
	var leg_len := 6
	var leg_w := 4
	var hip_half := 3          # Abstand Beinmitte von der Mitte
	var torso_r := Vector3(5.5, 6.0, 6.5)
	var shoulder := 7.0
	match body:
		"slim":
			leg_len = 8; leg_w = 3; hip_half = 3
			torso_r = Vector3(4.5, 6.5, 5.0); shoulder = 5.5
		"strong":
			leg_len = 5; leg_w = 5; hip_half = 4
			torso_r = Vector3(7.0, 6.5, 8.5); shoulder = 9.0
	# Weiblicher Körperbau: schmalere Schultern und Brust, breitere Hüfte (unten).
	var female: bool = str(spec.get("gender", "male")) == "female"
	if female:
		shoulder -= 1.0
		torso_r.z -= 1.0
	_hip_y = float(leg_len) * VOX

	# Beine (Drehpunkt Hüfte)
	for sz in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0, leg_len, sz * hip_half) * VOX
		_pose.add_child(hip)
		var g := Grid.new()
		var lo := -leg_w / 2
		g.fill(Vector3i(lo, -leg_len, lo), Vector3i(lo + leg_w - 1, -1, lo + leg_w - 1), _shade_fn(fur.darkened(0.08)))
		# Huf: unten dunkel, leicht nach vorn verlängert
		g.fill(Vector3i(lo, -leg_len, lo), Vector3i(lo + leg_w, -leg_len + 1, lo + leg_w - 1), _shade_fn(fur.darkened(0.6)))
		if spec["bottom"] == "pants":
			g.fill(Vector3i(lo, -leg_len + 2, lo), Vector3i(lo + leg_w - 1, -1, lo + leg_w - 1), _shade_fn(spec["pants"]))
		elif spec["bottom"] == "shorts":
			g.fill(Vector3i(lo, -2, lo), Vector3i(lo + leg_w - 1, -1, lo + leg_w - 1), _shade_fn(spec["pants"]))
		_add_mesh(g, hip, Vector3(0.5, 0, 0.5) * 0.0)
		_legs.append(hip)

	# Rumpf (lokal: y = 0 an der Hüfte)
	var torso := Grid.new()
	var tc := Vector3(0.0, torso_r.y - 0.5, 0.0)
	torso.round_box(tc, torso_r, 3.2, _fur_fn(fur, true))
	var bust_y := int(round(torso_r.y * 1.15))
	if female:
		_add_female_shape(torso, torso_r, bust_y, fur)
	# Hose bis knapp unter die Mitte, Gürtel in Akzentfarbe
	var belt_y := int(round(torso_r.y * 0.55))
	if spec["bottom"] != "none":
		torso.recolor(func(p: Vector3i) -> bool: return p.y < belt_y, _shade_fn(spec["pants"]))
		torso.recolor(func(p: Vector3i) -> bool: return p.y == belt_y, _shade_fn(Color(0.18, 0.14, 0.12)))
		var bx := torso.front_x(belt_y, 0)
		torso.put(Vector3i(bx, belt_y, 0), spec["accent"])
		torso.put(Vector3i(bx, belt_y, -1), spec["accent"])
	if spec["bottom"] == "skirt":
		_add_skirt(torso, torso_r, female)
	var top: String = spec["top"]
	if female and top == "none":
		top = "tank" # Weiblich immer mit Oberteil
	if female:
		_add_female_top(torso, torso_r, top, belt_y, bust_y)
	else:
		match top:
			"muscle":
				var tcol: Color = spec["top_color"]
				torso.recolor(func(p: Vector3i) -> bool: return p.y > belt_y and p.y < int(torso_r.y * 1.75) and absi(p.z) < int(torso_r.z * 0.75), _shade_fn(tcol))
			"robe":
				var rcol: Color = spec["top_color"]
				torso.recolor(func(p: Vector3i) -> bool: return p.y >= 0, _shade_fn(rcol))
	if spec["mane"]:
		_add_mane(torso, int(torso_r.x), int(torso_r.y * 2.0))
	_add_mesh(torso, _body, Vector3.ZERO, Vector3(0, leg_len, 0))

	# Schwanz (hinten am Rumpf)
	_tail = Node3D.new()
	_tail.position = Vector3(-torso_r.x + 0.5, leg_len + torso_r.y * 0.9, 0) * VOX
	_body.add_child(_tail)
	_add_mesh(_build_tail(fur), _tail)

	# Arme (Drehpunkt Schulter); rechter Arm hält den Lötkolben
	var sh_y := float(leg_len) + torso_r.y * 1.45
	for sz in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(0.5, sh_y, sz * shoulder) * VOX
		_body.add_child(arm)
		var ag := Grid.new()
		var aw := 3 if body != "strong" else 4
		ag.fill(Vector3i(-1, -5, -1), Vector3i(aw - 2, 0, aw - 2), _shade_fn(fur.darkened(0.06)))
		ag.fill(Vector3i(-1, -6, -1), Vector3i(aw - 2, -6, aw - 2), _shade_fn(fur.darkened(0.55)))
		if spec["top"] == "robe":
			ag.fill(Vector3i(-1, -3, -1), Vector3i(aw - 2, 0, aw - 2), _shade_fn(spec["top_color"]))
		_add_mesh(ag, arm)
		_arms.append(arm)
		if sz == 1:
			_iron = Node3D.new()
			_iron.position = Vector3(0.5, -5.5, 0.5) * VOX
			arm.add_child(_iron)
			_add_mesh(_build_iron(), _iron)

	# Kopf (Drehpunkt Hals)
	_head_y = float(leg_len) + torso_r.y * 1.75
	if female:
		_head_y += 1.0 # etwas mehr Hals: Ausschnitt bleibt unter dem Rüssel sichtbar
	_head = Node3D.new()
	_head.position = Vector3(1.0, _head_y, 0) * VOX
	_body.add_child(_head)
	_build_head(fur)
	scale = Vector3.ONE

func _build_head(fur: Color) -> void:
	var big: bool = spec["head"] == "big"
	var hr := Vector3(6.0, 6.0, 7.0) if not big else Vector3(7.0, 6.8, 8.0)
	var hc := Vector3(0.5, hr.y - 0.5, 0.0)
	var g := Grid.new()
	g.round_box(hc, hr, 2.6, _fur_fn(fur, false))
	var front := int(hc.x + hr.x) - 1
	# Rüssel: abgerundeter Block nach vorn
	var sn_len := 4
	var sn_h := 3.0
	var sn_w := 3.5
	match spec["snout"]:
		"short":
			sn_len = 2
		"long":
			sn_len = 6; sn_h = 2.6; sn_w = 3.0
		"wide":
			sn_len = 4; sn_h = 3.4; sn_w = 4.6
	var snout_col := fur.lightened(0.18).lerp(Color(1.0, 0.66, 0.72), 0.3)
	if spec["mane"]:
		snout_col = fur.lightened(0.25)
	var sy := hr.y * 0.62
	var sc := Vector3(front + sn_len * 0.5 + 0.5, sy, 0.0)
	g.round_box(sc, Vector3(sn_len * 0.5 + 1.0, sn_h, sn_w), 1.3, _shade_fn(snout_col))
	# Rüsselscheibe vorn etwas dunkler, Nasenlöcher
	var disc_x := int(sc.x + sn_len * 0.5 + 0.5)
	for p in g.cells.keys():
		if p.x == disc_x:
			g.cells[p] = [snout_col.darkened(0.1), 0.0]
	var ny := int(sy)
	var nz := 1 if sn_w < 4.0 else 2
	for z in [-nz - 1, nz]:
		var p := Vector3i(disc_x, ny, z)
		if g.has(p):
			g.put(p, fur.darkened(0.7))
	# Hauer: von der Rüsselseite nach oben gebogen
	var tusk := Color(0.97, 0.93, 0.8)
	var tz := int(sn_w)
	var tx := disc_x - 1
	var ty := int(sy - sn_h) + 1
	match spec["tusks"]:
		"small":
			for sz in [-1, 1]:
				var zz: int = tz if sz > 0 else -tz - 1
				g.put(Vector3i(tx, ty, zz), tusk)
				g.put(Vector3i(tx, ty + 1, zz), tusk)
		"big":
			for sz in [-1, 1]:
				var zz: int = tz if sz > 0 else -tz - 1
				g.put(Vector3i(tx - 1, ty, zz), tusk)
				g.put(Vector3i(tx, ty, zz), tusk)
				g.put(Vector3i(tx, ty + 1, zz), tusk)
				g.put(Vector3i(tx + 1, ty + 2, zz), tusk)
				g.put(Vector3i(tx + 1, ty + 3, zz), tusk.darkened(0.05))
				g.put(Vector3i(tx, ty + 4, zz), tusk.darkened(0.08))
	# Augen: weiß mit Pupille in Blickrichtung, sitzen in der Kopffront
	var ey := int(hr.y * 1.15)
	var eye_z: Array = [2, 3] if not big else [2, 3, 4]
	var lids := Grid.new()
	var ink := Color(0.08, 0.07, 0.1)
	for sz in [-1, 1]:
		for dz in eye_z:
			var z: int = dz * sz if sz > 0 else -dz - 1
			for dy in [0, 1, 2]:
				var y: int = ey + dy
				var fx := g.front_x(y, z)
				if fx == -999:
					continue
				var inner: bool = dz == eye_z[0]
				var c := Color(1, 1, 1)
				if inner and dy < 2:
					c = ink
				elif dy == 2 and dz == eye_z[eye_z.size() - 1]:
					c = Color(0.92, 0.92, 0.96)
				g.put(Vector3i(fx, y, z), c)
				lids.put(Vector3i(fx + 1, y, z), fur.darkened(0.15))
		# Braue: eine Reihe über dem Auge, steht 1 Voxel vor. Weiblich: Wimpern
		# statt Braue, außen nach oben geschwungen.
		var lashes: bool = str(spec.get("gender", "male")) == "female"
		for dz in eye_z:
			var z2: int = dz * sz if sz > 0 else -dz - 1
			var fx2 := g.front_x(ey + 3, z2)
			if fx2 == -999:
				continue
			if lashes:
				# Nur am äußeren Augenrand, schräg nach oben-außen: wirkt wie
				# Wimpern und nicht wie eine finstere Braue.
				if dz == eye_z[eye_z.size() - 1]:
					var zo: int = z2 + sz
					g.put(Vector3i(fx2 + 1, ey + 2, zo), ink)
					g.put(Vector3i(fx2 + 1, ey + 3, zo), ink)
					g.put(Vector3i(fx2 + 1, ey + 3, z2), ink)
			else:
				var tilt: int = 1 if (spec["mane"] or spec["body"] == "strong") and dz == eye_z[0] else 0
				g.put(Vector3i(fx2 + 1, ey + 3 - tilt, z2), fur.darkened(0.45))
	# Wangen: rosa Flecken neben dem Rüssel
	for sz in [-1, 1]:
		var cz: int = int(sn_w) + 1 if sz > 0 else -int(sn_w) - 2
		var cfx := g.front_x(int(sy), cz)
		if cfx != -999 and not spec["mane"]:
			g.put(Vector3i(cfx, int(sy), cz), Color(1.0, 0.55, 0.62))
	if spec["mane"]:
		_add_mane(g, int(hr.x), int(hc.y + hr.y))
	_add_mesh(g, _head)
	_lids = Node3D.new()
	_head.add_child(_lids)
	_add_mesh(lids, _lids)
	_lids.visible = false
	# Ohren
	var ear_y := hc.y + hr.y - 1.5
	for sz in [-1, 1]:
		var ear := Node3D.new()
		ear.position = Vector3(-1.5, ear_y, sz * (hr.z - 2.0)) * VOX
		_head.add_child(ear)
		_add_mesh(_build_ear(fur, sz), ear)
		_ears.append(ear)
	# Klassen-Kopfbedeckung als eigenes, austauschbares Teil
	if String(spec["outfit"]) != "":
		var hat := Node3D.new()
		hat.name = "Outfit"
		_head.add_child(hat)
		_add_mesh(_build_outfit(String(spec["outfit"]), hr, hc), hat)

# --- Weiblicher Körperbau ---

## Breitere Hüfte unten am Rumpf und eine runde Oberweite vorn auf Brusthöhe.
## Comic-Proportionen: zwei weiche Rundungen, die zu einer Form verschmelzen.
func _add_female_shape(torso: Grid, torso_r: Vector3, bust_y: int, fur: Color) -> void:
	var fur_fn := _fur_fn(fur, true)
	torso.round_box(Vector3(0.0, torso_r.y * 0.35, 0.0), Vector3(torso_r.x + 0.3, torso_r.y * 0.42, torso_r.z + 2.0), 2.4, fur_fn)
	# Oberweite: eine weiche Wölbung über die ganze Brustbreite, die Mitte
	# (Dekolleté) zeichnet _add_female_top als feine Linie.
	torso.round_box(Vector3(torso_r.x, float(bust_y) + 0.3, 0.0), Vector3(2.3, 2.0, 3.6), 1.7, fur_fn)

## Oberteil für den weiblichen Körperbau mit rundem Ausschnitt (Dekolleté).
## tank = Top, muscle/bikini = kurzes Top, robe = Kleid bis zum Rumpfende.
func _add_female_top(torso: Grid, torso_r: Vector3, top: String, belt_y: int, bust_y: int) -> void:
	if top == "none":
		return
	var col: Color = spec["top_color"]
	var neck_top := int(torso_r.y * 1.75)
	var low := belt_y + 1
	if top == "bikini":
		low = bust_y - 2
	elif top == "robe":
		low = 0
	var front := int(torso_r.x) - 3
	# Ausschnitt: vorn ein U, in der Mitte am tiefsten, außen wie Träger höher.
	var in_neckline := func(p: Vector3i) -> bool:
		if p.x < front:
			return false
		var zc := absf(float(p.z) + 0.5)
		return float(p.y) > float(bust_y) + 1.0 + zc * 0.6
	torso.recolor(func(p: Vector3i) -> bool:
		if p.y < low or p.y >= neck_top:
			return false
		if top == "bikini" and p.y > bust_y + 2:
			return false
		return not in_neckline.call(p), _shade_fn(col))
	# Saum unter der Brust etwas dunkler, sitzt das Top weich auf.
	var hem := col.darkened(0.18)
	if top != "robe":
		for p in torso.cells.keys():
			if p.y == low and p.x >= front:
				torso.cells[p] = [hem, 0.0]
	# Dekolleté: kurze, weiche Linie in der Mitte, vom Ausschnitt in die Wölbung.
	for z in [0, -1]:
		for y in [bust_y + 1, bust_y + 2]:
			var fx := torso.front_x(y, z)
			if fx >= int(torso_r.x):
				var c: Color = torso.cells[Vector3i(fx, y, z)][0]
				torso.cells[Vector3i(fx, y, z)] = [c.darkened(0.1), 0.0]

## Minirock: ausgestellter Ring unter der Hüfte, Beine bleiben frei.
func _add_skirt(torso: Grid, torso_r: Vector3, female: bool) -> void:
	var col: Color = spec["pants"]
	var shade := _shade_fn(col)
	var rz := torso_r.z + (1.5 if female else 0.0)
	for y in range(-3, 0):
		var flare := 0.8 + float(-y) * 0.45
		var rx := torso_r.x + flare
		var zr := rz + flare
		for x in range(floori(-rx), ceili(rx) + 1):
			for z in range(floori(-zr), ceili(zr) + 1):
				var d := Vector2((float(x) + 0.5) / rx, (float(z) + 0.5) / zr)
				if d.length_squared() <= 1.0:
					var p := Vector3i(x, y, z)
					torso.put(p, col.darkened(0.12) if y == -3 else shade.call(p))

func _build_ear(fur: Color, sz: int) -> Grid:
	var g := Grid.new()
	var dark := fur.darkened(0.12)
	var inner := fur.lerp(Color(1.0, 0.6, 0.68), 0.55)
	var rows: Array = []   # [breite z, höhe y]
	match spec["ears"]:
		"up":
			rows = [4, 4, 3, 2, 1]
		"pointy":
			rows = [3, 3, 2, 2, 1, 1]
		"small":
			rows = [3, 2, 1]
		"flop":
			rows = [4, 4, 4, 3]
	for i in range(rows.size()):
		var w: int = rows[i]
		for j in range(w):
			var z: int = j * sz if sz > 0 else -j - 1
			g.put(Vector3i(0, i, z), dark)
			g.put(Vector3i(-1, i, z), dark)
			if j > 0 and j < w - 1 and i < rows.size() - 1:
				g.put(Vector3i(1, i, z), inner)
	if spec["ears"] == "flop":
		# Schlappohr: hängt nach vorn-außen, dafür Teil drehen (siehe animate)
		pass
	return g

func _build_tail(fur: Color) -> Grid:
	var g := Grid.new()
	var c := fur.darkened(0.1)
	match spec["tail"]:
		"curly":
			for p in [Vector3i(-1, 0, 0), Vector3i(-2, 1, 0), Vector3i(-2, 2, 1), Vector3i(-1, 3, 1), Vector3i(-1, 3, 0), Vector3i(-2, 3, -1)]:
				g.put(p, c)
		"straight":
			for i in range(4):
				g.put(Vector3i(-1 - i, -i / 2, 0), c)
		"tuft":
			g.put(Vector3i(-1, 0, 0), c)
			g.put(Vector3i(-2, -1, 0), c)
			g.put(Vector3i(-2, -2, 0), c)
			g.fill(Vector3i(-3, -5, -1), Vector3i(-2, -3, 0), fur.darkened(0.55))
	return g

func _build_iron() -> Grid:
	var g := Grid.new()
	var accent: Color = spec["accent"]
	var tip: Color = spec["tip"]
	# Griff schwarz, Ring in Akzentfarbe, Metallschaft, glühende Spitze
	g.fill(Vector3i(-1, 0, 0), Vector3i(3, 1, 1), Color(0.14, 0.13, 0.16))
	g.fill(Vector3i(4, -1, -1), Vector3i(4, 2, 2), accent)
	g.fill(Vector3i(5, 0, 0), Vector3i(9, 0, 0), Color(0.78, 0.8, 0.86))
	g.fill(Vector3i(5, 1, 0), Vector3i(8, 1, 0), Color(0.62, 0.64, 0.7))
	g.fill(Vector3i(10, 0, 0), Vector3i(11, 1, 1), tip.lightened(0.3), 2.2)
	g.put(Vector3i(12, 0, 0), tip.lightened(0.5), 3.0)
	return g

## Borstenkamm: gezackte dunkle Reihe in der Mitte von vorn nach hinten.
func _add_mane(g: Grid, half_x: int, top: int) -> void:
	var bristle := Color(0.2, 0.15, 0.12)
	for x in range(-half_x - 1, half_x - 1):
		var ty := g.top_y(x, 0)
		if ty == -999:
			continue
		var h := 1 + (1 if (x % 2 == 0) else 0)
		for dy in range(1, h + 1):
			g.put(Vector3i(x, ty + dy, 0), bristle)
			if dy == 1:
				g.put(Vector3i(x, ty + dy, -1), bristle.lightened(0.1))
	if top < 0:
		pass

## Kopfbedeckungen je Klasse (wie in der Seitenansicht, nur Kopf/Hals).
func _build_outfit(hero: String, hr: Vector3, hc: Vector3) -> Grid:
	var g := Grid.new()
	var top := int(hc.y + hr.y)                  # erste freie Reihe über dem Kopf
	var fx := int(hc.x + hr.x)                   # Vorderkante Kopf
	var zr := int(hr.z)
	var xr := int(hr.x)
	var cx := int(hc.x)
	match hero:
		"ignis":
			# Schweißerbrille auf der Stirn: Band rundum, zwei Gläser vorn
			var band := Color(0.22, 0.18, 0.15)
			var y := top - 3
			for p in _ring(cx, xr + 1, zr + 1):
				g.put(Vector3i(p.x, y, p.y), band)
			for sz in [-1, 1]:
				var z0: int = 1 if sz > 0 else -4
				g.fill(Vector3i(fx, y - 1, z0), Vector3i(fx, y + 1, z0 + 2), Color(0.32, 0.28, 0.24))
				g.fill(Vector3i(fx + 1, y - 1, z0 + 1), Vector3i(fx + 1, y, z0 + 2), Color(1.0, 0.6, 0.15), 1.6)
		"volt":
			var yellow := Color(1.0, 0.84, 0.15)
			g.rounded(Vector3(hc.x - 0.5, top + 1.0, 0), Vector3(xr - 0.5, 2.5, zr - 0.5), yellow, 3.0)
			g.fill(Vector3i(fx - 2, top - 1, -zr + 2), Vector3i(fx + 3, top - 1, zr - 3), yellow.darkened(0.22))
			# Blitz vorn auf der Kappe
			for p in [Vector3i(fx - 1, top + 2, 0), Vector3i(fx - 1, top + 1, -1), Vector3i(fx - 1, top + 1, 0), Vector3i(fx - 1, top, -1)]:
				g.put(p + Vector3i(0, 0, 0), Color(0.15, 0.15, 0.22))
		"spore":
			var green := Color(0.36, 0.72, 0.3)
			var dot := Color(0.96, 0.98, 0.88)
			var cap_col := func(p: Vector3i) -> Color: return dot if (posmod(p.x * 3 + p.z * 5 + p.y * 7, 11) == 0 and p.y > top) else green.lightened(0.04 * (p.y - top))
			g.ellipsoid(Vector3(hc.x, top + 1.5, 0), Vector3(xr + 3.0, 4.0, zr + 3.0), cap_col)
			g.fill(Vector3i(cx - xr - 3, top - 1, -zr - 3), Vector3i(cx + xr + 2, top - 1, zr + 2), green.darkened(0.12))
			for p in g.cells.keys():
				if p.y < top - 1:
					g.erase(p)
		"nova":
			var violet := Color(0.45, 0.3, 0.8)
			g.fill(Vector3i(cx - xr - 2, top - 1, -zr - 2), Vector3i(cx + xr + 1, top - 1, zr + 1), violet.darkened(0.15))
			var levels := [[xr, zr, 0], [xr - 2, zr - 2, 0], [xr - 3, zr - 3, -1], [xr - 4, zr - 4, -2], [2, 2, -3], [1, 1, -4]]
			var y := top
			for l in levels:
				var lx: int = l[0]
				var lz: int = l[1]
				var off: int = l[2]
				g.fill(Vector3i(cx - lx + off, y, -lz), Vector3i(cx + lx - 1 + off, y + 1, lz - 1), violet.lightened(0.03 * (y - top)))
				y += 2
			g.fill(Vector3i(cx - xr, top, -zr), Vector3i(cx + xr - 1, top, zr - 1), Color(1.0, 0.85, 0.3))
			g.put(Vector3i(cx - 5, y, 0), Color(1.0, 0.92, 0.5), 1.8)
		"klinge":
			var red := Color(0.85, 0.15, 0.2)
			for p in _ring(cx, xr + 1, zr + 1):
				g.put(Vector3i(p.x, -1, p.y), red)
				g.put(Vector3i(p.x, 0, p.y), red.darkened(0.08))
			g.fill(Vector3i(fx - 1, -3, -1), Vector3i(fx, -2, 0), red)
			g.fill(Vector3i(cx - xr - 4, -1, 2), Vector3i(cx - xr - 1, 0, 3), red.darkened(0.15))
			g.fill(Vector3i(cx - xr - 6, -3, 3), Vector3i(cx - xr - 4, -2, 4), red.darkened(0.22))
		"bastion":
			var teal := Color(0.15, 0.7, 0.68)
			g.fill(Vector3i(cx - xr - 1, top - 1, -zr - 1), Vector3i(cx + xr + 1, top - 1, zr), teal.darkened(0.18))
			g.rounded(Vector3(hc.x, top + 1.5, -0.5), Vector3(xr, 3.0, zr), teal, 3.0)
			g.fill(Vector3i(cx - xr + 1, top + 3, -1), Vector3i(cx + xr - 1, top + 4, 0), teal.lightened(0.2))
			g.fill(Vector3i(fx, top, -1), Vector3i(fx + 1, top + 2, 0), Color(1.0, 0.97, 0.75), 2.2)
		"phantom":
			var cloth := Color(0.16, 0.14, 0.24)
			var y2 := top - 3
			for p in _ring(cx, xr + 1, zr + 1):
				g.put(Vector3i(p.x, y2, p.y), cloth)
				g.put(Vector3i(p.x, y2 + 1, p.y), cloth)
			g.put(Vector3i(fx + 1, y2, 0), Color(0.75, 0.75, 0.82))
			g.fill(Vector3i(cx - xr - 5, y2 - 1, 1), Vector3i(cx - xr - 2, y2, 1), cloth.lightened(0.12))
			g.fill(Vector3i(cx - xr - 4, y2 - 3, -2), Vector3i(cx - xr - 2, y2 - 2, -2), cloth.lightened(0.06))
		"druid", "druide":
			# Blätterkranz mit kleiner Blüte
			var leaf := Color(0.3, 0.62, 0.25)
			var y3 := top - 1
			var i := 0
			for p in _ring(cx, xr, zr):
				g.put(Vector3i(p.x, y3 + (i % 2), p.y), leaf.lightened(0.1 * (i % 3)))
				i += 1
			g.fill(Vector3i(fx - 2, y3 + 1, 2), Vector3i(fx - 1, y3 + 2, 3), Color(1.0, 0.55, 0.75))
		"vampire":
			# Zylinder mit blutrotem Band (wie VoxelPig und Seitenansicht)
			var felt := Color(0.1, 0.08, 0.12)
			g.fill(Vector3i(cx - xr - 2, top - 1, -zr - 2), Vector3i(cx + xr + 1, top - 1, zr + 1), felt)
			g.fill(Vector3i(cx - xr + 1, top, -zr + 1), Vector3i(cx + xr - 2, top + 7, zr - 2), felt.lightened(0.04))
			g.fill(Vector3i(cx - xr + 1, top, -zr + 1), Vector3i(cx + xr - 2, top + 1, zr - 2), Color(0.74, 0.06, 0.14))
		"vampire_melee":
			# Blutroter Kragen mit goldener Spange
			var collar := Color(0.62, 0.06, 0.14)
			for p in _ring(cx, xr + 1, zr + 1):
				g.put(Vector3i(p.x, -1, p.y), collar)
				g.put(Vector3i(p.x, 0, p.y), collar.darkened(0.15))
			g.fill(Vector3i(fx, -1, -1), Vector3i(fx + 1, 0, 0), Color(0.95, 0.8, 0.35))
		"zeitschlaeger":
			# Wecker als Hut: Messinggehäuse, Zifferblatt vorn, zwei Glocken
			var brass := Color(0.86, 0.66, 0.26)
			g.fill(Vector3i(cx - 2, top, -3), Vector3i(cx + 1, top + 7, 2), brass)
			g.fill(Vector3i(cx + 2, top + 1, -2), Vector3i(cx + 2, top + 6, 1), Color(0.98, 0.96, 0.88))
			g.fill(Vector3i(cx + 3, top + 3, -1), Vector3i(cx + 3, top + 5, -1), Color(0.15, 0.1, 0.06))
			g.fill(Vector3i(cx + 3, top + 3, 0), Vector3i(cx + 3, top + 3, 0), Color(0.15, 0.1, 0.06))
			g.fill(Vector3i(cx - 2, top + 8, -5), Vector3i(cx, top + 9, -3), brass.lightened(0.15))
			g.fill(Vector3i(cx - 2, top + 8, 2), Vector3i(cx, top + 9, 4), brass.lightened(0.15))
		"flocke":
			# Türkiser Strickschal mit Streifen und wehendem Ende, dazu ein
			# Eiskristall-Diadem zwischen den Ohren.
			var wool := Color(0.2, 0.75, 0.78)
			var stripe := Color(0.93, 0.97, 1.0)
			for p in _ring(cx, xr + 1, zr + 1):
				g.put(Vector3i(p.x, -1, p.y), wool if posmod(p.x + p.y, 4) != 0 else stripe)
				g.put(Vector3i(p.x, 0, p.y), wool.darkened(0.1))
			g.fill(Vector3i(cx - xr - 3, -2, 2), Vector3i(cx - xr - 1, 0, 3), wool)
			g.fill(Vector3i(cx - xr - 4, -4, 3), Vector3i(cx - xr - 3, -3, 4), wool.darkened(0.08))
			g.fill(Vector3i(cx - xr - 4, -5, 3), Vector3i(cx - xr - 3, -5, 4), stripe)
			# Diadem: silbernes Band vorn auf der Stirn, drei leuchtende Zacken.
			var silver := Color(0.82, 0.88, 0.95)
			var ice := Color(0.7, 0.93, 1.0)
			g.fill(Vector3i(fx - 3, top - 1, -3), Vector3i(fx - 2, top - 1, 2), silver)
			g.put(Vector3i(fx - 2, top, -1), ice, 1.2)
			g.put(Vector3i(fx - 2, top, 0), ice, 1.2)
			g.put(Vector3i(fx - 2, top + 1, -1), ice.lightened(0.2), 1.4)
			g.put(Vector3i(fx - 2, top + 1, 0), ice.lightened(0.2), 1.4)
			g.put(Vector3i(fx - 2, top + 2, -1), Color(0.95, 1.0, 1.0), 1.6)
			g.put(Vector3i(fx - 2, top, -3), ice, 1.0)
			g.put(Vector3i(fx - 2, top, 2), ice, 1.0)
	return g

## Ring aus (x, z)-Positionen um einen Kopf mit Halbachsen xr, zr.
func _ring(cx: int, xr: int, zr: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(cx - xr, cx + xr + 1):
		for z in range(-zr - 1, zr + 1):
			var d := Vector2((x + 0.5 - cx) / float(xr), (z + 0.5) / float(zr))
			var l := d.length()
			if l <= 1.08 and l >= 0.78:
				out.append(Vector2i(x, z))
	return out

# Farbfunktionen: leichtes Rauschen pro Voxel, damit Flächen lebendig wirken.
func _shade_fn(base: Color) -> Callable:
	return func(p: Vector3i) -> Color:
		var n := float(posmod(p.x * 73856093 ^ p.y * 19349663 ^ p.z * 83492791, 7)) / 6.0
		return base.darkened(0.035 * n) if n < 0.5 else base.lightened(0.03 * (n - 0.5))

func _fur_fn(fur: Color, belly: bool) -> Callable:
	var shade := _shade_fn(fur)
	var light := _shade_fn(fur.lightened(0.14))
	return func(p: Vector3i) -> Color:
		if belly and p.x >= 2 and absi(p.z) <= 3:
			return light.call(p)
		return shade.call(p)

# ---------------------------------------------------------------------------
# Meshing mit Voxel-AO
# ---------------------------------------------------------------------------

const DIRS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
const AO_CURVE: Array[float] = [0.62, 0.77, 0.9, 1.0]

func _add_mesh(g: Grid, parent: Node3D, _unused: Vector3 = Vector3.ZERO, offset_vox: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	# Normale Voxel landen in einer Fläche mit Vertex-Farben; leuchtende
	# Voxel (Lötspitze, Lampe) je Farbe in einer eigenen Fläche mit Emission.
	var surfaces: Dictionary = {}   # Schlüssel -> [verts, normals, colors, idx, material]
	for p in g.cells.keys():
		var cell: Array = g.cells[p]
		var col: Color = cell[0]
		var glow: float = cell[1]
		var key := "" if glow <= 0.0 else "%s|%.2f" % [col.to_html(), glow]
		if not surfaces.has(key):
			surfaces[key] = [PackedVector3Array(), PackedVector3Array(), PackedColorArray(), PackedInt32Array(), _mat if key == "" else _glow_material(col, glow)]
		var surf: Array = surfaces[key]
		var verts: PackedVector3Array = surf[0]
		var normals: PackedVector3Array = surf[1]
		var colors: PackedColorArray = surf[2]
		var idx: PackedInt32Array = surf[3]
		for d in DIRS:
			if g.has(p + d):
				continue
			# Zwei Tangenten der Fläche
			var u: Vector3i
			var w: Vector3i
			if d.x != 0:
				u = Vector3i(0, 1, 0); w = Vector3i(0, 0, 1)
			elif d.y != 0:
				u = Vector3i(0, 0, 1); w = Vector3i(1, 0, 0)
			else:
				u = Vector3i(1, 0, 0); w = Vector3i(0, 1, 0)
			var center := Vector3(p) + Vector3(0.5, 0.5, 0.5) + Vector3(d) * 0.5
			var corners: Array[Vector3] = []
			var ao: Array[float] = []
			for cs in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
				corners.append(center + (Vector3(u) * cs.x + Vector3(w) * cs.y) * 0.5)
				var s1 := g.has(p + d + u * cs.x)
				var s2 := g.has(p + d + w * cs.y)
				var cn := g.has(p + d + u * cs.x + w * cs.y)
				var level := 0 if (s1 and s2) else 3 - int(s1) - int(s2) - int(cn)
				ao.append(AO_CURVE[level] if glow <= 0.0 else 1.0)
			var base := verts.size()
			var n := Vector3(d)
			for i in range(4):
				verts.append((corners[i] + offset_vox) * VOX)
				normals.append(n)
				colors.append(Color(col.r * ao[i], col.g * ao[i], col.b * ao[i]))
			# Diagonale nach AO wählen, Wicklung passend zur Normalen
			var flip := ao[0] + ao[2] < ao[1] + ao[3]
			var tri: Array[int]
			if flip:
				tri = [0, 1, 3, 1, 2, 3]
			else:
				tri = [0, 1, 2, 0, 2, 3]
			var e1 := corners[tri[1]] - corners[tri[0]]
			var e2 := corners[tri[2]] - corners[tri[0]]
			var ccw := e1.cross(e2).dot(n) > 0.0
			for k in range(0, 6, 3):
				if ccw:
					idx.append(base + tri[k]); idx.append(base + tri[k + 2]); idx.append(base + tri[k + 1])
				else:
					idx.append(base + tri[k]); idx.append(base + tri[k + 1]); idx.append(base + tri[k + 2])
		surf[0] = verts; surf[1] = normals; surf[2] = colors; surf[3] = idx
	var mesh := ArrayMesh.new()
	for key in surfaces.keys():
		var surf: Array = surfaces[key]
		var verts: PackedVector3Array = surf[0]
		if verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = surf[1]
		arrays[Mesh.ARRAY_COLOR] = surf[2]
		arrays[Mesh.ARRAY_INDEX] = surf[3]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surf[4])
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi

func _new_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.82
	m.metallic_specular = 0.3
	# Silhouette hinter Mauern (Arena): Stencil-X-Ray in Team-/Akzentfarbe.
	if xray:
		var acc: Color = spec.get("accent", Color(1, 1, 1))
		m.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		m.stencil_color = Color(acc.r, acc.g, acc.b, 0.55)
	_mats.append(m)
	_base_emission.append([false, Color(0, 0, 0), 0.0])
	return m

func _glow_material(col: Color, glow: float) -> StandardMaterial3D:
	var key := "%s|%.2f" % [col.to_html(), glow]
	if _glow_mats.has(key):
		return _glow_mats[key]
	var m := _new_material()
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = glow
	_base_emission[_base_emission.size() - 1] = [true, col, glow]
	_glow_mats[key] = m
	return m

# ---------------------------------------------------------------------------
# Animation (gleiche Signatur wie VoxelPig)
# ---------------------------------------------------------------------------

## Fester Laufschritt für Standbilder (0..1 = ein Doppelschritt).
func pose_walk(phase: float) -> void:
	_walk_amount = 1.0
	_walk_phase = phase * TAU
	animate(0.0, true, false, 1.0)

func animate(delta: float, moving: bool, airborne: bool, _alpha: float, planar: Vector2 = Vector2.ZERO, facing: float = 0.0, vertical_speed: float = 0.0) -> void:
	if _pose == null:
		return
	_time += delta
	var speed := planar.length()
	if delta > 0.0:
		var want := 1.0 if (moving and not airborne) else 0.0
		_walk_amount = move_toward(_walk_amount, want, delta * 7.0)
		if moving and not airborne:
			_walk_phase += delta * clampf(speed / 16.0, 8.0, 20.0)
	var swing := sin(_walk_phase)
	for i in range(_legs.size()):
		var sgn := 1.0 if i == 0 else -1.0
		var target := swing * sgn * 0.7 * _walk_amount
		if airborne:
			target = 0.45 * sgn
		_legs[i].rotation.z = target if delta == 0.0 else lerp_angle(_legs[i].rotation.z, target, minf(1.0, delta * 18.0))
	for i in range(_arms.size()):
		var sgn2 := -1.0 if i == 0 else 1.0
		var a := swing * sgn2 * 0.55 * _walk_amount
		if i == 1:
			a = a * 0.4 + 0.9 + aim_pitch   # Lötkolben-Arm zeigt in Zielrichtung
		_arms[i].rotation.z = a
		_arms[i].rotation.x = (0.12 if i == 0 else -0.12)
	if airborne and not _was_airborne:
		_squash = -0.22
	elif not airborne and _was_airborne:
		_squash = 0.22
		_squash_vel = 0.0
	_was_airborne = airborne
	_squash_vel += (-_squash * 260.0 - _squash_vel * 17.0) * delta
	_squash += _squash_vel * delta
	var stretch := clampf(-_squash + (clampf(absf(vertical_speed) / 1400.0, 0.0, 0.08) if airborne else 0.0), -0.25, 0.2)
	var breathe := sin(_time * 2.4) * 0.012 * (1.0 - _walk_amount)
	_pose.scale = Vector3(1.0 - stretch * 0.5, 1.0 + stretch + breathe, 1.0 - stretch * 0.5)
	_body.position.y = absf(cos(_walk_phase)) * 1.2 * VOX * _walk_amount
	var local := Vector2.ZERO
	if speed > 20.0:
		var dir := planar / speed
		var c := cos(facing)
		var s := sin(facing)
		local = Vector2(dir.x * c - dir.y * s, dir.x * s + dir.y * c) * clampf(speed / 260.0, 0.0, 1.0)
	_lean = _lean.lerp(local, minf(1.0, delta * 9.0))
	_recoil = maxf(0.0, _recoil - delta * 6.5)
	var kick := _recoil * _recoil
	_pose.rotation.z = -_lean.x * 0.16 + kick * 0.2 - 0.06 * _walk_amount
	_pose.rotation.x = _lean.y * 0.14
	if _iron:
		_iron.rotation.z = -0.9 + kick * 0.4
	if _head:
		_head.rotation.z = -swing * 0.04 * _walk_amount - kick * 0.2 + sin(_time * 1.7) * 0.015
	var flop: bool = spec.get("ears", "up") == "flop"
	for i in range(_ears.size()):
		var side := -1.0 if i == 0 else 1.0
		var base := (1.25 if flop else 0.12) * side
		_ears[i].rotation.x = base + (absf(swing) * 0.18 * _walk_amount) * side
		_ears[i].rotation.z = 0.45 if flop else -0.15
	if _tail:
		_tail.rotation.y = sin(_time * 9.0) * (0.25 + 0.3 * _walk_amount)
	if delta > 0.0:
		_blink -= delta
		_lids.visible = _blink < 0.11
		if _blink <= 0.0:
			_blink = randf_range(1.8, 4.5)
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		var k := _flash / HIT_FLASH_TIME
		for m in _mats:
			m.emission_enabled = true
			m.emission = Color(1, 1, 1)
			m.emission_energy_multiplier = k * 1.6
		if _flash == 0.0:
			_restore_emission()
	var want_alpha := clampf(_alpha, 0.0, 1.0)
	if not is_equal_approx(want_alpha, _last_alpha):
		_last_alpha = want_alpha
		for m in _mats:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if want_alpha < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = want_alpha

func _restore_emission() -> void:
	for i in range(_mats.size()):
		var e: Array = _base_emission[i]
		_mats[i].emission_enabled = e[0]
		_mats[i].emission = e[1]
		_mats[i].emission_energy_multiplier = e[2]

## Spieler-Anbindung: baut die Figur aus Lobby-Aussehen + Baukasten und
## baut neu, wenn sich etwas ändert (Held, Teile, Teamfarbe). Liest Schuss
## und Treffer aus dem Spielerzustand ab, damit es auch auf Clients läuft,
## die nur Snapshots bekommen.
func sync_with_player(p: Player, delta: float) -> void:
	_spec_timer -= delta
	if _spec_timer <= 0.0 or _pose == null:
		_spec_timer = 0.5
		var s := spec_for_player(p.player_index, Global.get_team_color(p.team_id), Global.get_player_hero_id(p.player_index))
		if s != _bound_spec or _pose == null:
			_bound_spec = s
			build(s)
	var pool: float = p.current_health + p.current_shield
	if not _last_state.is_empty():
		if pool < float(_last_state["pool"]) - 0.5:
			flash()
		if p.current_ammo < int(_last_state["ammo"]) or p.fire_timer > float(_last_state["fire"]) + 0.01:
			recoil(1.0)
	_last_state = {"pool": pool, "ammo": p.current_ammo, "fire": p.fire_timer}

func flash() -> void:
	_flash = HIT_FLASH_TIME
	_squash = maxf(_squash, 0.12)

func recoil(strength: float = 1.0) -> void:
	_recoil = clampf(strength, 0.3, 1.4)
