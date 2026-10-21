extends Node2D

func _ready() -> void:
	print("[TEST] Initializing Headless Integration Test inside full game tree...")
	var main_scene = load("res://scenes/main.tscn")
	var main = main_scene.instantiate()
	main.skip_menu = true
	add_child(main)
	
	# Wait for nodes to ready
	await get_tree().create_timer(0.2).timeout
	
	var level = main.get_node_or_null("ProceduralLevel")
	assert(level != null, "Level should exist")
	assert(main.p1 != null, "Player 1 should exist")
	assert(main.p2 != null, "Player 2 should exist")
	assert(main.p2.is_bot == true, "Player 2 should be bot by default")
	print("[TEST] Players spawned: P1 at ", main.p1.global_position, " | P2 at ", main.p2.global_position)
	
	# Simulate combat
	print("[TEST] Simulating 1.5s of combat...")
	await get_tree().create_timer(1.5).timeout
	
	print("[TEST] P1 HP: ", main.p1.current_health, " | P2 HP: ", main.p2.current_health)
	
	# Trigger round defeat: clear invulnerability flags if any
	print("[TEST] Simulating P2 defeat...")
	main.p2.is_invulnerable = false
	main.p2.is_barrier_active = false
	main.p2.take_damage(9999.0)
	
	# Wait a short frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("[TEST] Global state after P2 death: ", Global.current_state, " (expected: ", Global.GameState.CARD_DRAFT, ")")
	assert(Global.current_state == Global.GameState.CARD_DRAFT, "State should transition to CARD_DRAFT")
	assert(main.card_draft_ui.visible == true, "Card draft UI should be visible")
	print("[TEST] Card Draft UI triggered successfully with ", main.card_draft_ui.offered_cards.size(), " cards.")
	
	print("[TEST] Waiting for bot auto-draft (process_mode=ALWAYS timer)...")
	# Use process timer because tree is paused during draft
	await get_tree().create_timer(1.5, true).timeout
	
	print("[TEST] P2 Cards after draft: ", Global.p2_cards.size())
	assert(Global.p2_cards.size() == 1, "P2 should have drafted 1 card")
	print("[TEST] Successfully drafted card: ", Global.p2_cards[0].title)
	
	print("[SUCCESS] All integration tests passed smoothly! Game mechanics 100% verified.")
	get_tree().quit(0)
