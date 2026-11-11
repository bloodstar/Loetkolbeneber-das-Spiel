class_name SideLevels
extends RefCounted

# Seitenansicht-Level aus dem Karteneditor.
#  - Überschreibungen: geänderter Bauplan eines eingebauten Levels. Das Spiel
#    nimmt ihn statt des Eintrags in LevelGenerator.LAYOUTS. Zurücksetzen
#    löscht nur die Datei, das Original im Code bleibt unverändert.
#  - Eigene Level: neue Level mit eigenem Bauplan. Profil (Theme, Größe,
#    Objekte) kommt vom Level, auf dem sie aufbauen ("based_on").
# Gespeichert als JSON unter user://side_levels/<id>.json.
# Online schickt der Host vor jeder Runde den Bauplan mit (send_side_level).

const DIR: String = "user://side_levels"
const CUSTOM_PREFIX: String = "side_custom_"
# Zufällige Zusätze aus dem Profil, die "extras": false abschaltet.
const EXTRA_KEYS: Array[String] = ["random_platforms", "destructibles", "ice_patches"]

static var overrides: Dictionary = {} # map_id -> {"layout": {...}, "extras": bool}
static var custom: Dictionary = {}    # id -> {"name", "description", "based_on", "layout", "extras"}
# Online-Client: Baupläne vom Host. Wert {} = eingebauter Bauplan.
static var remote: Dictionary = {}
## Editor-Test: Solange gesetzt, spielt jede Runde dieses Level.
static var test_map_id: String = ""
static var _loaded: bool = false
static var _profile_cache: Dictionary = {}

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		return
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + f))
		if not (parsed is Dictionary):
			continue
		var data: Dictionary = parsed
		var id := str(data.get("id", f.get_basename()))
		if id.begins_with(CUSTOM_PREFIX):
			if LevelGenerator.MAP_PROFILES.has(str(data.get("based_on", ""))):
				custom[id] = data
		elif LevelGenerator.MAP_PROFILES.has(id):
			overrides[id] = data

static func has(map_id: String) -> bool:
	_ensure()
	return LevelGenerator.MAP_PROFILES.has(map_id) or custom.has(map_id)

static func is_custom(map_id: String) -> bool:
	_ensure()
	return custom.has(map_id)

static func has_override(map_id: String) -> bool:
	_ensure()
	return overrides.has(map_id)

static func custom_ids() -> Array[String]:
	_ensure()
	var ids: Array[String] = []
	for id in custom.keys():
		ids.append(str(id))
	ids.sort()
	return ids

static func custom_name(map_id: String) -> String:
	_ensure()
	return str(custom.get(map_id, {}).get("name", map_id))

## Eintrag mit Bauplan und Schalter für ein Level (Online: vom Host).
static func _entry(map_id: String) -> Dictionary:
	_ensure()
	if Global.network_mode and remote.has(map_id):
		return remote[map_id]
	if custom.has(map_id):
		return custom[map_id]
	return overrides.get(map_id, {})

## Profil eines Levels: eingebaut, oder bei eigenen Leveln eine Kopie des
## Basis-Levels. "extras": false schaltet zufällige Zusatzplattformen,
## Blöcke und Eisflächen ab.
static func profile(map_id: String) -> Dictionary:
	if _profile_cache.has(map_id):
		return _profile_cache[map_id]
	_ensure()
	var entry := _entry(map_id)
	var base_id := str(entry.get("based_on", map_id))
	var p: Dictionary = LevelGenerator.MAP_PROFILES.get(base_id, LevelGenerator.MAP_PROFILES.get(map_id, {}))
	if not entry.is_empty():
		p = p.duplicate()
		if map_id.begins_with(CUSTOM_PREFIX):
			p["layout"] = map_id
		if not bool(entry.get("extras", true)):
			for k in EXTRA_KEYS:
				p[k] = 0
	_profile_cache[map_id] = p
	return p

## Bauplan eines Levels (Überschreibung, eigenes Level oder eingebaut).
static func layout(map_id: String) -> Dictionary:
	var entry := _entry(map_id)
	if entry.has("layout"):
		return entry["layout"]
	var p := profile(map_id)
	return LevelGenerator.LAYOUTS.get(str(p.get("layout", map_id)), {})

static func builtin_layout(map_id: String) -> Dictionary:
	var p: Dictionary = LevelGenerator.MAP_PROFILES.get(map_id, {})
	return LevelGenerator.LAYOUTS.get(str(p.get("layout", map_id)), {})

static func extras_enabled(map_id: String) -> bool:
	return bool(_entry(map_id).get("extras", true))

static func make_custom_id(level_name: String) -> String:
	return CUSTOM_PREFIX + ArenaMaps.make_custom_id(level_name).trim_prefix(ArenaMaps.CUSTOM_PREFIX)

## Speichert Überschreibung (eingebautes Level) oder eigenes Level.
static func save(map_id: String, data: Dictionary) -> Error:
	_ensure()
	data = data.duplicate(true)
	data["id"] = map_id
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + "/" + map_id + ".json", FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if map_id.begins_with(CUSTOM_PREFIX):
		custom[map_id] = data
	else:
		overrides[map_id] = data
	_profile_cache.clear()
	return OK

## Eingebautes Level: Überschreibung entfernen. Eigenes Level: löschen.
static func remove(map_id: String) -> void:
	_ensure()
	custom.erase(map_id)
	overrides.erase(map_id)
	DirAccess.remove_absolute(DIR + "/" + map_id + ".json")
	_profile_cache.clear()

## Host → Client: Bauplan für diese Runde. "" = eingebauter Bauplan.
static func entry_json(map_id: String) -> String:
	_ensure()
	if custom.has(map_id):
		return JSON.stringify(custom[map_id])
	if overrides.has(map_id):
		return JSON.stringify(overrides[map_id])
	return ""

static func register_remote(map_id: String, json_text: String) -> void:
	var data := {}
	if not json_text.is_empty():
		var parsed = JSON.parse_string(json_text)
		if parsed is Dictionary:
			data = parsed
			if map_id.begins_with(CUSTOM_PREFIX) and not LevelGenerator.MAP_PROFILES.has(str(data.get("based_on", ""))):
				return
	remote[map_id] = data
	_profile_cache.erase(map_id)
	if map_id.begins_with(CUSTOM_PREFIX) and not data.is_empty():
		# Damit has() und Namen auch auf dem Client funktionieren.
		_ensure()
		if not custom.has(map_id):
			custom[map_id] = data

static func clear_cache() -> void:
	_profile_cache.clear()
