class_name VoxelPig
extends Node3D

# Einfaches Voxel-Schwein für den Arena-Modus. Gebaut aus Quadern, Maße in
# Pixel-Einheiten der 2D-Welt (1 Tile = 36). Blickrichtung ist +X im
# lokalen Raum; ArenaView3D dreht das Schwein zur Zielrichtung.

var fur: Color = Color(0.91, 0.60, 0.67)
var pants: Color = Color(0.25, 0.35, 0.8)
var accent: Color = Color(1, 1, 1)

var _body_root: Node3D
var _legs: Array[MeshInstance3D] = []
var _wand: MeshInstance3D
var _wand_tip: MeshInstance3D
var _mats: Array[StandardMaterial3D] = []
var _bob_time: float = 0.0
var _flash: float = 0.0

func build(p_fur: Color, p_pants: Color, p_accent: Color, scale_mult: float = 1.0) -> void:
	fur = p_fur
	pants = p_pants
	accent = p_accent
	for c in get_children():
		c.queue_free()
	_legs.clear()
	_mats.clear()
	_body_root = Node3D.new()
	add_child(_body_root)
	var dark := fur.darkened(0.25)
	var snout := fur.lightened(0.3).lerp(Color(1.0, 0.66, 0.72), 0.3)
	# Beine (vier kleine Stummel)
	for lx in [-6.0, 6.0]:
		for lz in [-6.0, 6.0]:
			var leg := _box(Vector3(6, 8, 6), Vector3(lx, 4, lz), dark, self)
			_legs.append(leg)
	# Hose + Körper
	_box(Vector3(22, 8, 20), Vector3(0, 12, 0), pants, _body_root)
	_box(Vector3(22, 12, 20), Vector3(0, 22, 0), fur, _body_root)
	# Kopf, Rüssel, Nasenlöcher, Augen, Ohren
	_box(Vector3(18, 16, 18), Vector3(4, 36, 0), fur, _body_root)
	_box(Vector3(5, 8, 10), Vector3(15, 33, 0), snout, _body_root)
	_box(Vector3(1.2, 2.2, 2.2), Vector3(17.7, 33.5, -2.4), dark.darkened(0.4), _body_root)
	_box(Vector3(1.2, 2.2, 2.2), Vector3(17.7, 33.5, 2.4), dark.darkened(0.4), _body_root)
	_box(Vector3(1.5, 4, 3.4), Vector3(13.4, 39, -5), Color(0.08, 0.08, 0.1), _body_root)
	_box(Vector3(1.5, 4, 3.4), Vector3(13.4, 39, 5), Color(0.08, 0.08, 0.1), _body_root)
	_box(Vector3(6, 4, 6), Vector3(0, 46, -7), dark, _body_root)
	_box(Vector3(6, 4, 6), Vector3(0, 46, 7), dark, _body_root)
	# Ringelschwanz und Team-Band
	_box(Vector3(4, 4, 4), Vector3(-13, 22, 0), dark, _body_root)
	_box(Vector3(23, 2.5, 21), Vector3(0, 28.5, 0), accent, _body_root)
	# Zauberstab (Lötkolben) seitlich
	_wand = _box(Vector3(16, 2.4, 2.4), Vector3(10, 24, 13), Color(0.3, 0.22, 0.16), _body_root)
	_wand_tip = _box(Vector3(4, 4, 4), Vector3(19, 24, 13), accent.lightened(0.3), _body_root)
	var tip_mat := _wand_tip.material_override as StandardMaterial3D
	tip_mat.emission_enabled = true
	tip_mat.emission = accent
	tip_mat.emission_energy_multiplier = 1.6
	scale = Vector3.ONE * scale_mult

func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	# Silhouette durch Mauern: Stencil-X-Ray in Teamfarbe (Godot 4.5+).
	mat.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	mat.stencil_color = Color(accent.r, accent.g, accent.b, 0.55)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	_mats.append(mat)
	return mi

## Pro Frame: Laufanimation (Beine/Wippen), Treffer-Blitz, Transparenz.
func animate(delta: float, moving: bool, airborne: bool, alpha: float) -> void:
	if moving and not airborne:
		_bob_time += delta * 14.0
	else:
		_bob_time = lerpf(_bob_time, round(_bob_time / PI) * PI, minf(1.0, delta * 10.0))
	var swing := sin(_bob_time)
	for i in range(_legs.size()):
		var sgn := 1.0 if (i % 3 == 0) else -1.0
		_legs[i].position.y = 4.0 + maxf(0.0, swing * sgn) * 3.0
	if _body_root:
		_body_root.position.y = absf(sin(_bob_time)) * 1.6
		if airborne:
			_body_root.rotation.z = 0.12
		else:
			_body_root.rotation.z = lerpf(_body_root.rotation.z, 0.0, minf(1.0, delta * 12.0))
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	for m in _mats:
		var want_alpha := clampf(alpha, 0.0, 1.0)
		if want_alpha < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = want_alpha

func flash() -> void:
	_flash = 0.12
