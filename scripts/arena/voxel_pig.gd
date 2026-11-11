class_name VoxelPig
extends Node3D

# Voxel-Schwein für den Arena-Modus. Gebaut aus Quadern, Maße in
# Pixel-Einheiten der 2D-Welt (1 Tile = 36). Blickrichtung ist +X im
# lokalen Raum; ArenaView3D dreht das Schwein zur Zielrichtung.
#
# Die Kamera schaut von schräg oben. Deshalb sitzt alles, was die Figur
# erkennbar macht, auf Kopf und Rücken: großer Kopf, Ohren, Rüssel,
# Klassen-Kopfbedeckung (wie die Outfits der Seitenansicht), Lötkolben.

const HIT_FLASH_TIME: float = 0.14

var fur: Color = Color(0.91, 0.60, 0.67)
var pants: Color = Color(0.25, 0.35, 0.8)
var accent: Color = Color(1, 1, 1)
var tip_color: Color = Color(0.6, 0.85, 1.0)
var hero_id: String = ""

var _pose: Node3D            # Stauchen/Strecken, Neigung (Drehpunkt am Boden)
var _body: Node3D            # Rumpf + Kopf (wippt beim Laufen)
var _head: Node3D
var _legs: Array[Node3D] = []
var _ears: Array[Node3D] = []
var _tail: Node3D
var _iron: Node3D
var _lids: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _base_emission: Array = []
var _mat_cache: Dictionary = {}

var _walk_phase: float = 0.0
var _walk_amount: float = 0.0
var _time: float = 0.0
var _flash: float = 0.0
var _recoil: float = 0.0
var _squash: float = 0.0     # >0 gestaucht (Landung), <0 gestreckt (Absprung)
var _squash_vel: float = 0.0
var _lean: Vector2 = Vector2.ZERO
var _blink: float = 2.0
var _was_airborne: bool = false
var _last_alpha: float = 1.0

func build(p_fur: Color, p_pants: Color, p_accent: Color, scale_mult: float = 1.0, p_hero_id: String = "", p_tip: Color = Color(0, 0, 0, 0)) -> void:
	fur = p_fur
	pants = p_pants
	accent = p_accent
	hero_id = p_hero_id
	tip_color = p_tip if p_tip.a > 0.0 else p_accent
	for c in get_children():
		c.queue_free()
	_legs.clear()
	_ears.clear()
	_lids.clear()
	_mats.clear()
	_base_emission.clear()
	_mat_cache.clear()
	_pose = Node3D.new()
	add_child(_pose)
	_body = Node3D.new()
	_pose.add_child(_body)
	var dark := fur.darkened(0.22)
	var light := fur.lightened(0.12)
	var snout := fur.lightened(0.28).lerp(Color(1.0, 0.68, 0.74), 0.35)
	var hoof := fur.darkened(0.55)
	var ink := Color(0.09, 0.08, 0.12)
	# Beine: Drehpunkt an der Hüfte, damit sie beim Laufen schwingen.
	for lx in [-6.0, 6.5]:
		for lz in [-6.0, 6.0]:
			var hip := Node3D.new()
			hip.position = Vector3(lx, 9.0, lz)
			_pose.add_child(hip)
			_box(Vector3(6, 6, 6), Vector3(0, -3.5, 0), dark, hip)
			_box(Vector3(6.4, 3, 6.4), Vector3(0, -7.5, 0), hoof, hip)
			_legs.append(hip)
	# Rumpf: Hose unten, Fell oben, heller Bauchfleck, Gürtel in Teamfarbe.
	_box(Vector3(21, 7, 19), Vector3(-1, 10.5, 0), pants, _body)
	_box(Vector3(21, 9, 19), Vector3(-1, 18.5, 0), fur, _body)
	_box(Vector3(17, 2, 15), Vector3(-1, 23.5, 0), light, _body)
	_box(Vector3(21.6, 2.4, 19.6), Vector3(-1, 14.2, 0), accent, _body)
	_box(Vector3(3, 3, 3), Vector3(9.9, 14.2, 0), Color(1.0, 0.85, 0.3), _body)
	# Ringelschwanz
	_tail = Node3D.new()
	_tail.position = Vector3(-11.5, 17.0, 0.0)
	_body.add_child(_tail)
	_box(Vector3(3, 3, 3), Vector3(-1.5, 0, 0), dark, _tail)
	_box(Vector3(3, 3, 3), Vector3(-3.5, 2.5, 1.5), dark, _tail)
	_box(Vector3(3, 3, 3), Vector3(-2.0, 5.0, -0.5), snout, _tail)
	# Kopf: groß und leicht nach vorn versetzt (Chibi-Proportion).
	_head = Node3D.new()
	_head.position = Vector3(4.0, 24.0, 0.0)
	_body.add_child(_head)
	_box(Vector3(19, 15, 21), Vector3(0, 7.5, 0), fur, _head)
	_box(Vector3(15, 2, 17), Vector3(0, 16.0, 0), light, _head)
	# Wangen
	_box(Vector3(2, 4, 3), Vector3(8.8, 4.5, -8.2), snout, _head)
	_box(Vector3(2, 4, 3), Vector3(8.8, 4.5, 8.2), snout, _head)
	# Rüssel mit Nasenlöchern
	_box(Vector3(5, 7, 11), Vector3(11.5, 5.0, 0), snout, _head)
	_box(Vector3(1.2, 2.6, 2.2), Vector3(14.0, 5.4, -2.6), dark.darkened(0.45), _head)
	_box(Vector3(1.2, 2.6, 2.2), Vector3(14.0, 5.4, 2.6), dark.darkened(0.45), _head)
	# Hauer
	_box(Vector3(2, 3.4, 2), Vector3(10.6, 2.2, -6.6), Color(0.98, 0.95, 0.84), _head)
	_box(Vector3(2, 3.4, 2), Vector3(10.6, 2.2, 6.6), Color(0.98, 0.95, 0.84), _head)
	# Augen: Weiß, Pupille, Glanzpunkt; Lid zum Blinzeln
	for sz in [-1.0, 1.0]:
		_box(Vector3(1.4, 6, 5), Vector3(9.3, 11.0, 5.4 * sz), Color(1, 1, 1), _head)
		_box(Vector3(1.6, 4, 3), Vector3(9.5, 10.4, 4.8 * sz), ink, _head)
		_box(Vector3(1.8, 1.4, 1.4), Vector3(9.6, 11.8, 5.6 * sz), Color(1, 1, 1), _head)
		var lid := _box(Vector3(1.9, 6.2, 5.2), Vector3(9.5, 11.0, 5.4 * sz), dark, _head)
		lid.visible = false
		_lids.append(lid)
		# Braue (gibt dem Gesicht Charakter, von oben sichtbar)
		_box(Vector3(2.4, 1.6, 6), Vector3(9.4, 14.8, 5.4 * sz), dark.darkened(0.2), _head)
	# Ohren: Drehpunkt am Ansatz, wackeln beim Laufen
	for sz in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.position = Vector3(-2.0, 15.0, 8.0 * sz)
		_head.add_child(ear)
		_box(Vector3(6, 5, 5), Vector3(0, 2.5, 0), dark, ear)
		_box(Vector3(4, 4, 4), Vector3(-0.5, 6.5, 0.8 * sz), dark, ear)
		_box(Vector3(1.2, 4, 3), Vector3(3.0, 3.0, 0), snout, ear)
		_ears.append(ear)
	# Stummelarme und Lötkolben (rechte Seite, zeigt in Blickrichtung)
	_box(Vector3(5, 5, 4), Vector3(8.5, 17.0, -10.5), dark, _body)
	_iron = Node3D.new()
	_iron.position = Vector3(8.5, 17.5, 11.5)
	_body.add_child(_iron)
	_box(Vector3(5, 5, 4), Vector3(0, -0.5, -1.0), dark, _iron)
	_box(Vector3(9, 4, 4), Vector3(1.5, 0.5, 1.6), Color(0.13, 0.13, 0.16), _iron)
	_box(Vector3(2, 4.8, 4.8), Vector3(6.5, 0.5, 1.6), accent, _iron)
	_box(Vector3(9, 2, 2), Vector3(12.0, 0.5, 1.6), Color(0.78, 0.8, 0.86), _iron)
	var tip := _box(Vector3(4, 3, 3), Vector3(18.0, 0.5, 1.6), tip_color.lightened(0.35), _iron, tip_color, 2.2)
	tip.name = "Tip"
	_build_outfit()
	scale = Vector3.ONE * scale_mult

## Kopfbedeckung je Klasse, angelehnt an die Outfits der Seitenansicht.
func _build_outfit() -> void:
	var top := 16.5   # Oberkante Kopf (lokal im Kopf)
	match hero_id:
		"ignis":
			# Schweißerbrille auf der Stirn
			_box(Vector3(19.6, 3, 21.6), Vector3(0, 13.5, 0), Color(0.2, 0.17, 0.15), _head)
			for sz in [-1.0, 1.0]:
				_box(Vector3(3, 5, 6), Vector3(9.0, 15.5, 5.2 * sz), Color(0.3, 0.26, 0.22), _head)
				_box(Vector3(1.2, 3.4, 4.2), Vector3(10.6, 15.5, 5.2 * sz), Color(1.0, 0.6, 0.15), _head, Color(1.0, 0.5, 0.1), 1.4)
		"volt":
			# Gelbe Kappe mit Schirm und Blitz
			var yellow := Color(1.0, 0.84, 0.15)
			_box(Vector3(17, 5, 19), Vector3(-1, top + 2.0, 0), yellow, _head)
			_box(Vector3(8, 1.6, 15), Vector3(10.5, top + 0.6, 0), yellow.darkened(0.2), _head)
			_box(Vector3(5, 1.2, 2.4), Vector3(-1, top + 4.9, 1.0), Color(0.15, 0.15, 0.2), _head)
			_box(Vector3(5, 1.2, 2.4), Vector3(1.5, top + 4.9, -1.2), Color(0.15, 0.15, 0.2), _head)
		"spore":
			# Pilzhut: breite Krempe, Kuppel, helle Punkte
			var green := Color(0.36, 0.72, 0.3)
			_box(Vector3(25, 4, 27), Vector3(0, top + 1.5, 0), green, _head)
			_box(Vector3(19, 4, 21), Vector3(0, top + 5.0, 0), green.lightened(0.08), _head)
			_box(Vector3(11, 3, 13), Vector3(0, top + 8.0, 0), green.lightened(0.16), _head)
			for d in [Vector3(7, 3.6, 8), Vector3(-8, 3.6, -6), Vector3(4, 7.1, -6), Vector3(-5, 7.1, 6), Vector3(0, 9.6, 0)]:
				_box(Vector3(4, 0.8, 4), Vector3(d.x, top + d.y, d.z), Color(0.95, 0.98, 0.88), _head)
		"nova":
			# Zauberhut: Krempe und gestufter Kegel mit Stern
			var violet := Color(0.45, 0.3, 0.8)
			_box(Vector3(25, 2, 27), Vector3(0, top + 0.8, 0), violet.darkened(0.15), _head)
			_box(Vector3(15, 6, 17), Vector3(0, top + 4.5, 0), violet, _head)
			_box(Vector3(10, 6, 11), Vector3(-1, top + 10.0, 0), violet.lightened(0.06), _head)
			_box(Vector3(6, 5, 6), Vector3(-3, top + 15.0, 0), violet.lightened(0.12), _head)
			_box(Vector3(15.6, 2, 17.6), Vector3(0, top + 2.8, 0), Color(1.0, 0.85, 0.3), _head)
			_box(Vector3(3, 3, 3), Vector3(-5, top + 18.5, 0), Color(1.0, 0.9, 0.5), _head, Color(1.0, 0.85, 0.4), 1.6)
		"klinge":
			# Rotes Halstuch mit wehendem Ende
			var red := accent if Global.is_team_mode() else Color(0.85, 0.15, 0.2)
			_box(Vector3(20, 4, 22), Vector3(0, 1.0, 0), red, _head)
			_box(Vector3(8, 3, 4), Vector3(-12, 1.5, 4), red.darkened(0.12), _head)
			_box(Vector3(6, 3, 4), Vector3(-17, 0.0, 6), red.darkened(0.2), _head)
		"bastion":
			# Bauhelm mit Stirnlampe
			var teal := Color(0.15, 0.7, 0.68)
			_box(Vector3(22, 2, 24), Vector3(0.5, top + 0.6, 0), teal.darkened(0.15), _head)
			_box(Vector3(18, 5, 20), Vector3(-0.5, top + 3.6, 0), teal, _head)
			_box(Vector3(18.4, 1.6, 4), Vector3(-0.5, top + 6.6, 0), teal.lightened(0.2), _head)
			_box(Vector3(3, 4, 5), Vector3(9.5, top + 3.4, 0), Color(1.0, 0.97, 0.75), _head, Color(1.0, 0.95, 0.6), 2.0)
		"phantom":
			# Ninja-Stirnband mit Bändern
			var cloth := accent if Global.is_team_mode() else Color(0.16, 0.14, 0.24)
			_box(Vector3(19.8, 3, 21.8), Vector3(0, 15.2, 0), cloth, _head)
			_box(Vector3(8, 2.4, 3), Vector3(-13, 15.0, 3), cloth, _head)
			_box(Vector3(8, 2.4, 3), Vector3(-15, 12.5, -2), cloth.lightened(0.1), _head)

func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, emission: Color = Color(0, 0, 0, 0), energy: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	# Gleiche Farbe = gleiches Material: weniger Materialien pro Figur.
	var key := "%s|%s|%.2f" % [color.to_html(), emission.to_html(), energy]
	var mat: StandardMaterial3D = _mat_cache.get(key, null)
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		mat.metallic_specular = 0.25
		if emission.a > 0.0:
			mat.emission_enabled = true
			mat.emission = emission
			mat.emission_energy_multiplier = energy
		# Silhouette durch Mauern: Stencil-X-Ray in Teamfarbe (Godot 4.5+).
		mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		mat.stencil_color = Color(accent.r, accent.g, accent.b, 0.55)
		_mat_cache[key] = mat
		_mats.append(mat)
		_base_emission.append([mat.emission_enabled, mat.emission, mat.emission_energy_multiplier])
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

## Pro Frame. `planar` ist die Laufgeschwindigkeit in Weltkoordinaten (2D),
## `facing` der Blickwinkel (rotation.y), damit sich die Figur in
## Laufrichtung neigt, auch wenn sie woandershin zielt.
func animate(delta: float, moving: bool, airborne: bool, alpha: float, planar: Vector2 = Vector2.ZERO, facing: float = 0.0, vertical_speed: float = 0.0) -> void:
	if _pose == null:
		return
	_time += delta
	var speed := planar.length()
	var want := 1.0 if (moving and not airborne) else 0.0
	_walk_amount = move_toward(_walk_amount, want, delta * 7.0)
	if moving and not airborne:
		_walk_phase += delta * clampf(speed / 16.0, 8.0, 20.0)
	var swing := sin(_walk_phase)
	# Beine: diagonal gegengleich schwingen, in der Luft angezogen.
	for i in range(_legs.size()):
		var sgn := 1.0 if (i == 0 or i == 3) else -1.0
		var target := swing * sgn * 0.75 * _walk_amount
		if airborne:
			target = 0.5 if i < 2 else -0.5
		_legs[i].rotation.z = lerp_angle(_legs[i].rotation.z, target, minf(1.0, delta * 18.0))
	# Landen und Abspringen: Feder mit Nachschwingen.
	if airborne and not _was_airborne:
		_squash = -0.22
	elif not airborne and _was_airborne:
		_squash = 0.3
		_squash_vel = 0.0
	_was_airborne = airborne
	_squash_vel += (-_squash * 260.0 - _squash_vel * 17.0) * delta
	_squash += _squash_vel * delta
	var stretch := clampf(-_squash + (clampf(absf(vertical_speed) / 900.0, 0.0, 0.14) if airborne else 0.0), -0.35, 0.3)
	var breathe := sin(_time * 2.4) * 0.012 * (1.0 - _walk_amount)
	_pose.scale = Vector3(1.0 - stretch * 0.5, 1.0 + stretch + breathe, 1.0 - stretch * 0.5)
	# Rumpf wippt im Takt der Schritte.
	_body.position.y = absf(swing) * 1.8 * _walk_amount
	# Neigung in Laufrichtung (lokal: x vorwärts, z seitwärts).
	var local := Vector2.ZERO
	if speed > 20.0:
		var dir := planar / speed
		var c := cos(facing)
		var s := sin(facing)
		# Welt (x, z=y2d) -> lokal: Drehung um -facing um die Y-Achse.
		local = Vector2(dir.x * c - dir.y * s, dir.x * s + dir.y * c) * clampf(speed / 260.0, 0.0, 1.0)
	_lean = _lean.lerp(local, minf(1.0, delta * 9.0))
	# Rückstoß kippt die Figur kurz nach hinten und zieht den Lötkolben zurück.
	_recoil = maxf(0.0, _recoil - delta * 6.5)
	var kick := _recoil * _recoil
	_pose.rotation.z = -_lean.x * 0.16 + kick * 0.2
	_pose.rotation.x = _lean.y * 0.14
	if airborne:
		_pose.rotation.z += 0.1
	_pose.position.x = -kick * 3.0
	if _iron:
		_iron.position.x = 8.5 - kick * 5.0
		_iron.rotation.z = kick * 0.5 + sin(_time * 2.4) * 0.03
	# Kopf nickt gegen den Schritt, Ohren und Schwanz wackeln.
	if _head:
		_head.rotation.z = -swing * 0.05 * _walk_amount - kick * 0.25 + sin(_time * 1.7) * 0.015
		_head.position.y = 24.0 + absf(cos(_walk_phase)) * 0.8 * _walk_amount
	for i in range(_ears.size()):
		var side := -1.0 if i == 0 else 1.0
		var flop := (0.12 + absf(swing) * 0.22 * _walk_amount + clampf(-_squash_vel * 0.02, -0.3, 0.5)) * side
		_ears[i].rotation.x = lerp_angle(_ears[i].rotation.x, flop, minf(1.0, delta * 14.0))
	if _tail:
		_tail.rotation.y = sin(_time * 9.0) * (0.25 + 0.3 * _walk_amount)
	# Blinzeln
	_blink -= delta
	var closed := _blink < 0.11
	for lid in _lids:
		lid.visible = closed
	if _blink <= 0.0:
		_blink = randf_range(1.8, 4.5)
	# Treffer: kurz weiß aufleuchten.
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		var k := _flash / HIT_FLASH_TIME
		for i in range(_mats.size()):
			_mats[i].emission_enabled = true
			_mats[i].emission = Color(1, 1, 1)
			_mats[i].emission_energy_multiplier = k * 1.6
		if _flash == 0.0:
			_restore_emission()
	var want_alpha := clampf(alpha, 0.0, 1.0)
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

## Treffer erhalten.
func flash() -> void:
	_flash = HIT_FLASH_TIME
	_squash = maxf(_squash, 0.12)

## Schuss abgegeben.
func recoil(strength: float = 1.0) -> void:
	_recoil = clampf(strength, 0.3, 1.4)
