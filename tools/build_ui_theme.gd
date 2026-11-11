extends SceneTree

## Erzeugt res://assets/ui/ui_theme.tres aus scripts/ui/ui_theme.gd.
##   godot --headless --path . --script res://tools/build_ui_theme.gd

func _init() -> void:
	var theme: Theme = UiTheme.build()
	var err := ResourceSaver.save(theme, UiTheme.THEME_PATH)
	print("UI-Theme gespeichert: ", UiTheme.THEME_PATH, " (", error_string(err), ")")
	quit(0 if err == OK else 1)
