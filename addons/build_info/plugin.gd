@tool
extends EditorPlugin

var _export_plugin: EditorExportPlugin = null
var _zip_plugin: EditorExportPlugin = null

func _enter_tree() -> void:
	_export_plugin = preload("res://addons/build_info/build_info_export_plugin.gd").new()
	add_export_plugin(_export_plugin)
	_zip_plugin = preload("res://addons/build_info/release_zip_export_plugin.gd").new()
	add_export_plugin(_zip_plugin)

func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	if _zip_plugin != null:
		remove_export_plugin(_zip_plugin)
		_zip_plugin = null
