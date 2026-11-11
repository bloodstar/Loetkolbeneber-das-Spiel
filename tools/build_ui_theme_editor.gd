@tool
extends EditorScript

## Im Godot-Editor: Skript öffnen, dann Datei → Ausführen (Strg+Umschalt+X).
## Erzeugt res://assets/ui/ui_theme.tres neu aus scripts/ui/ui_theme.gd.

func _run() -> void:
	var theme: Theme = UiTheme.build()
	var err := ResourceSaver.save(theme, UiTheme.THEME_PATH)
	print("UI-Theme gespeichert: ", UiTheme.THEME_PATH, " (", error_string(err), ")")
	EditorInterface.get_resource_filesystem().scan()
