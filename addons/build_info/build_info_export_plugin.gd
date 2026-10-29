@tool
extends EditorExportPlugin

# Legt beim Export eine build_info.json direkt ins .pck. Die Datei existiert
# nur im exportierten Spiel, nie im Projektordner.
const BUILD_INFO_PATH := "res://build_info.json"

func _get_name() -> String:
	return "BuildInfo"

func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	var now := Time.get_datetime_dict_from_system()
	var info := {
		"build_id": "%04d%02d%02d-%02d%02d%02d" % [now.year, now.month, now.day, now.hour, now.minute, now.second],
		"built_at": "%02d.%02d.%04d %02d:%02d" % [now.day, now.month, now.year, now.hour, now.minute],
		"commit": _git(["rev-parse", "--short", "HEAD"]),
		"dirty": not _git(["status", "--porcelain"]).is_empty(),
		"debug": is_debug,
	}
	add_file(BUILD_INFO_PATH, JSON.stringify(info, "\t").to_utf8_buffer(), false)

func _git(args: PackedStringArray) -> String:
	var output: Array = []
	var full_args := PackedStringArray(["-C", ProjectSettings.globalize_path("res://")])
	full_args.append_array(args)
	if OS.execute("git", full_args, output) != 0 or output.is_empty():
		return ""
	return str(output[0]).strip_edges()
