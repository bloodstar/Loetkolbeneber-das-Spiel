extends CanvasLayer

# Verweis auf das Hauptspiel-Root-Node
var main_game_root: Node = null

# @onready var start_btn: Button = $StartButton # Angenommen, dieser Button existiert
# @onready var credits_btn: Button = $CreditsButton # Angenommen, dieser Button existiert

func _ready() -> void:
	# Verbindungen
	# start_btn.pressed.connect(_on_start_button_pressed)
	# credits_btn.pressed.connect(_on_credits_button_pressed)
	
	# NEU: Versuche, das Hauptspiel-Root-Node zu finden, da es die Logik enthält.
	# Wir suchen nach dem Node mit dem Namen "Main"
	main_game_root = get_tree().get_root().find_node("Main", true, false)
	if main_game_root == null:
		print("WARNUNG: MainGame Root Node nicht gefunden! Der Spielstart wird fehlschlagen.")

func _on_new_game_button_pressed() -> void:
	if main_game_root and main_game_root.has_method("start_setup_phase"):
		# Ruft die zentrale Setup-Funktion aus main.gd auf
		main_game_root.call("start_setup_phase")
	else:
		print("FEHLER: Konnte die Setup-Phase nicht starten. Ist main.gd korrekt im Main-Root platziert?")

# Platzhalter für andere Funktionen, falls sie existieren
# func _on_start_button_pressed() -> void:
# 	pass
# func _on_credits_button_pressed() -> void:
# 	pass
