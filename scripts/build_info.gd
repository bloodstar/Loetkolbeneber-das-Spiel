class_name BuildInfo
extends RefCounted

# Liest die beim Export erzeugte res://build_info.json (siehe addons/build_info).
# Im Editor gibt es die Datei nicht, dann gilt die Version als "DEV".

const BUILD_INFO_PATH := "res://build_info.json"

static var _info: Dictionary = {}
static var _loaded: bool = false

static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(BUILD_INFO_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BUILD_INFO_PATH))
	if parsed is Dictionary:
		_info = parsed

static func is_exported_build() -> bool:
	_load()
	return not _info.is_empty()

# Eindeutige Kennung zum Vergleich Host <-> Client.
static func get_build_id() -> String:
	_load()
	return str(_info.get("build_id", "DEV"))

# Anzeige-Text, z. B. "Build 26.10.2026 09:15 · 6d31757*".
static func get_display_text() -> String:
	_load()
	if _info.is_empty():
		return _get_dev_text()
	var text := "Build %s" % str(_info.get("built_at", get_build_id()))
	var commit := str(_info.get("commit", ""))
	if not commit.is_empty():
		text += "  ·  %s%s" % [commit, "*" if bool(_info.get("dirty", false)) else ""]
	if bool(_info.get("debug", false)):
		text += "  ·  debug"
	return text

# Im Editor: neueste gespeicherte Skript-/Szenen-Datei, damit man sieht,
# ob die letzte Änderung im laufenden Spiel angekommen ist.
static func _get_dev_text() -> String:
	var newest := {"time": 0, "path": ""}
	for dir in ["res://scripts", "res://scenes"]:
		_scan_newest(dir, newest)
	var text := "DEV-Build"
	if int(newest.time) > 0:
		var bias_sec := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
		var t := Time.get_datetime_dict_from_unix_time(int(newest.time) + bias_sec)
		text += "  ·  letzte Änderung %02d.%02d. %02d:%02d:%02d (%s)" % [
			t.day, t.month, t.hour, t.minute, t.second, str(newest.path).get_file(),
		]
	var output: Array = []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "--short", "HEAD"], output) == 0 and not output.is_empty():
		text += "  ·  %s" % str(output[0]).strip_edges()
	return text

static func _scan_newest(dir_path: String, newest: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_newest(dir_path.path_join(sub), newest)
	for file in dir.get_files():
		if not (file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres")):
			continue
		var path := dir_path.path_join(file)
		var modified := FileAccess.get_modified_time(path)
		if modified > int(newest.time):
			newest.time = modified
			newest.path = path
