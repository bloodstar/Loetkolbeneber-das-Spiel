@tool
extends EditorExportPlugin

# Packt nach jedem Export alle Dateien aus dem Export-Ordner (EXE, Epic-DLLs,
# ggf. .pck) in eine ZIP daneben, z. B. Export/Loetkolbeneber.zip. Diese ZIP
# kann man direkt an Mitspieler schicken.
# Godot kopiert die DLLs erst nach _export_end, deshalb wird kurz gewartet.

const ZIP_DELAY_SEC := 1.5

var _export_path: String = ""

func _get_name() -> String:
	return "ReleaseZip"

func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	# Nur bei "Projekt exportieren" (EXE), nicht bei "PCK/ZIP exportieren".
	_export_path = path if path.get_extension().to_lower() == "exe" else ""

func _export_end() -> void:
	if _export_path.is_empty():
		return
	var exe_path := _export_path
	_export_path = ""
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(ZIP_DELAY_SEC).timeout.connect(_make_zip.bind(exe_path))

func _make_zip(exe_path: String) -> void:
	var abs_exe := exe_path
	if abs_exe.begins_with("res://"):
		abs_exe = ProjectSettings.globalize_path(abs_exe)
	elif abs_exe.is_relative_path():
		abs_exe = ProjectSettings.globalize_path("res://" + abs_exe)
	var dir_path := abs_exe.get_base_dir()
	var folder_name := dir_path.get_file()
	var zip_path := dir_path.get_base_dir().path_join(folder_name + ".zip")
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("ReleaseZip: Export-Ordner nicht gefunden: " + dir_path)
		return
	var zip := ZIPPacker.new()
	if zip.open(zip_path) != OK:
		push_warning("ReleaseZip: ZIP konnte nicht erstellt werden: " + zip_path)
		return
	var count := _add_dir(zip, dir_path, folder_name)
	zip.close()
	print("ReleaseZip: %d Dateien gepackt -> %s" % [count, zip_path])

func _add_dir(zip: ZIPPacker, dir_path: String, zip_prefix: String) -> int:
	var count := 0
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.get_extension().to_lower() in ["zip", "pdb", "tmp"]:
			continue
		var bytes := FileAccess.get_file_as_bytes(dir_path.path_join(file_name))
		zip.start_file(zip_prefix.path_join(file_name))
		zip.write_file(bytes)
		zip.close_file()
		count += 1
	for sub in DirAccess.get_directories_at(dir_path):
		count += _add_dir(zip, dir_path.path_join(sub), zip_prefix.path_join(sub))
	return count
