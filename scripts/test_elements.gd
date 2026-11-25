extends Node2D

## Test für das Element-System: Slots, Karte "Element" mit Unter-Draft,
## Grundkarten, Element-Bedingungen, Kombinationen und Welt-Reaktionen.
## Start: godot --headless --path . scenes/test_elements.tscn

var _failed: int = 0

func _check(cond: bool, text: String) -> void:
	if cond:
		print("[OK] ", text)
	else:
		_failed += 1
		printerr("[FAIL] ", text)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _zones(kind: int) -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group("effect_zone"):
		var z := node as EffectZone
		if z != null and z.kind == kind and not z.is_queued_for_deletion():
			result.append(z)
	return result

func _clear_zones() -> void:
	for node in get_tree().get_nodes_in_group("effect_zone"):
		node.queue_free()

func _reset_target(p: Player) -> void:
	p.max_health = 5000.0
	p.current_health = 5000.0
	p.current_shield = 0.0
	p.poison_ticks_left = 0
	p.burn_ticks_left = 0
	p.freeze_timer = 0.0
	p.stun_timer = 0.0
	p.is_invulnerable = false
	if p.has_meta("elem"):
		p.remove_meta("elem")

func _ready() -> void:
	CardStats.set_persistence_enabled(false)
	CardStats.auto_evaluation_enabled = false
	Global.lobby_autosave_enabled = false
	get_tree().create_timer(60.0, true).timeout.connect(func():
		printerr("[TEST] TIMEOUT")
		get_tree().quit(1)
	)

	# --- Daten ---
	_check(ElementSystem.elements_for("ignis", []) == ["fire"], "Ignis hat Feuer als Grundelement")
	_check(ElementSystem.free_slots("ignis", []) == 1 and ElementSystem.free_slots("nova", []) == 2, "Klassen mit Element haben einen freien Slot, andere zwei")
	_check(ElementSystem.combo_for("poison", "fire") == "gasbrand" and ElementSystem.combo_for("frost", "frost") == "permafrost", "Matrix-Felder stimmen")
	_check(ElementSystem.elements_for("nova", ["element_frost", "element_frost_rein"]) == ["frost", "frost"], "Reine Elementkarte zählt als zweites Frost")

	var pick := CardDatabase.get_card(ElementSystem.PICK_CARD_ID)
	_check(pick != null and pick.element_pick, "Karte Element existiert")
	_check(CardDatabase.is_card_available_for_player(pick, "nova", []), "Element verfügbar mit freiem Slot")
	_check(not CardDatabase.is_card_available_for_player(pick, "nova", ["element_fire", "element_poison"]), "Element weg, wenn beide Slots voll sind")
	var ignis_offer := CardDatabase.get_element_offer("ignis", [])
	var ignis_ids: Array = []
	for c in ignis_offer:
		ignis_ids.append(c.id)
	_check(ignis_ids.has("element_fire_rein") and not ignis_ids.has("element_fire") and ignis_offer.size() == 4, "Unter-Draft für Ignis: Feuer als reine Form")

	var leaked := false
	for i in 150:
		for c in CardDatabase.get_draft_offer(6, [], "nova", []):
			if CardDatabase.is_element_card(c) or c.element_core:
				leaked = true
	_check(not leaked, "Normale Angebote enthalten keine Element- oder Grundkarten")
	_check(CardDatabase.get_card("feuersturm").element_core and CardDatabase.get_card("nk_giftzahn").element_core, "Grundkarten (Schuss und Nahkampf) sind markiert")
	var spores := CardDatabase.get_card("toxic_spores")
	_check(spores.required_element == "poison", "Toxic Spores verlangt Gift")
	_check(not CardDatabase.is_card_available_for_player(spores, "nova", []), "Toxic Spores ohne Gift nicht verfügbar")
	_check(CardDatabase.is_card_available_for_player(spores, "nova", ["element_poison"]), "Toxic Spores mit Element Gift verfügbar")
	_check(CardDatabase.is_card_available_for_player(spores, "spore", []), "Toxic Spores für Spore (Grundelement)")
	for id in ["frost_eissplitter", "frost_tiefkuehlung", "frostschuss_splitternova", "frostschuss_gletscherhaut", "frost_kaeltepanzer"]:
		_check(CardDatabase.get_card(id) != null, "Frost-Karte %s existiert" % id)
	_check(not CardDatabase.is_card_available_for_player(CardDatabase.get_card("frost_eissplitter"), "nova", []), "Eissplitter braucht Frost")

	# --- Match: Nova (1) gegen Klinge (2) ---
	Global.set_match_mode(Global.MATCH_MODE_FFA)
	Global.set_player_count(2)
	Global.set_player_hero(1, "nova")
	Global.set_player_hero(2, "klinge")
	Global.reset_match()
	Global.set_element_reactions_enabled(true)
	var main = load("res://scenes/main.tscn").instantiate()
	main.skip_menu = true
	main.kill_cam_enabled = false
	add_child(main)
	await _wait(0.3)
	var p1: Player = main.get_player(1)
	var p2: Player = main.get_player(2)
	_check(p1 != null and p2 != null, "Beide Spieler sind gespawnt")
	if p1 == null or p2 == null:
		get_tree().quit(1)
		return
	for p in [p1, p2]:
		p.is_bot = false
		p.control_enabled = false
		var ai = p.get_node_or_null("AIController")
		if ai:
			ai.queue_free()

	# Draft: "Element" öffnet den Unter-Draft, Element gibt Grundkarte mit.
	var draft: CardDraftUI = main.card_draft_ui
	draft.network_mode = false
	draft.current_drafter = 1
	draft.picks_total = 1
	draft.picks_remaining = 1
	draft.picked_this_draft.clear()
	var base_offer: Array[CardData] = [CardDatabase.get_card("schnellfeuer")]
	draft.offered_cards = draft._with_element_pick(base_offer)
	_check(draft.offered_cards.size() == 2 and draft.offered_cards[1].element_pick, "Element liegt zusätzlich im Angebot")
	draft._commit_pick(pick)
	_check(draft.picks_remaining == 1 and draft._is_element_subdraft() and draft.offered_cards.size() == 4, "Element öffnet den Unter-Draft, ohne den Pick zu verbrauchen")
	_check(draft._element_footer(CardDatabase.get_card("element_fire")) == "ERSTES ELEMENT", "Fußzeile: erstes Element")
	draft._commit_pick(CardDatabase.get_card("element_frost"))
	_check(Global.player_has_card(1, "element_frost") and Global.player_has_card(1, "frostschuss"), "Element Frost gibt Frostschuss mit")
	_check(draft.picks_remaining == 0, "Element-Wahl verbraucht den Pick")
	draft.close_draft()
	get_tree().paused = false
	_check(Global.get_player_elements(1) == ["frost"], "Spieler 1 hat Frost")
	Global.add_card_to_player(2, CardDatabase.get_card("element_fire"))
	_check(Global.player_has_card(2, "nk_gluehende_spitze"), "Nahkämpfer bekommt die Nahkampf-Grundkarte")

	# Kombination im eigenen Build.
	Global.add_card_to_player(1, CardDatabase.get_card("element_fire"))
	p1.apply_stats()
	_check(p1.element_combos == ["dampf"], "Frost + Feuer ergibt Dampf (%s)" % str(p1.element_combos))
	_check(draft._element_footer(CardDatabase.get_card("element_poison_rein")) != "", "Fußzeile für Kombination")

	p1.global_position = Vector2(400, 300)
	p2.global_position = Vector2(440, 300)
	p1.max_health = 5000.0
	p1.current_health = 5000.0

	# Gasbrand am Ziel: Feuer auf Vergiftete zündet das Gift.
	_reset_target(p2)
	p2.apply_poison(6, 4.0)
	var hp := p2.current_health
	p2.apply_burn(3, 5.0, p1)
	_check(p2.poison_ticks_left == 0 and p2.current_health < hp, "Gasbrand: Gift explodiert (%.0f Schaden)" % (hp - p2.current_health))

	# Thermoschock: Feuer auf Verlangsamte.
	_reset_target(p2)
	p2.apply_freeze(2.0)
	hp = p2.current_health
	p2.apply_burn(3, 5.0, p1)
	_check(p2.freeze_timer <= 0.0 and p2.burn_ticks_left == 0 and p2.current_health < hp, "Thermoschock beendet beide Status und macht Schaden")

	# Supraleiter: Blitz auf Verlangsamte.
	_reset_target(p2)
	p2.apply_freeze(2.0)
	p2.apply_stun(0.1, p1)
	_check(ElementReactions.damage_taken_mult(p2, p1) > 1.1, "Supraleiter macht verwundbarer")

	# Neurotoxin: Blitz auf Vergiftete verdoppelt die Betäubung.
	_reset_target(p2)
	p2.apply_poison(4, 4.0)
	p2.apply_stun(0.1, p1)
	_check(p2.stun_timer >= 0.19, "Neurotoxin verdoppelt die Betäubung (%.2f s)" % p2.stun_timer)

	# Lobby-Regel aus: fremde Reaktionen bleiben aus, eigene Kombination wirkt.
	Global.set_element_reactions_enabled(false)
	_reset_target(p2)
	p2.apply_poison(6, 4.0)
	p2.apply_burn(3, 5.0, p1) # p1 hat Dampf, nicht Gasbrand
	_check(p2.poison_ticks_left > 0, "Ohne Welt-Reaktionen kein Gasbrand für fremde Kombination")
	_reset_target(p2)
	p2.apply_freeze(2.0)
	p2.apply_burn(3, 5.0, p1)
	_check(p2.freeze_timer <= 0.0, "Eigene Kombination (Dampf) wirkt auch ohne Welt-Reaktionen")
	Global.set_element_reactions_enabled(true)

	# Flächen: Feuer trifft Giftwolke = Gasexplosion.
	_clear_zones()
	await _wait(0.05)
	_reset_target(p2)
	# Feuer rastet auf den Boden ein: erst den Brand legen, dann die Wolke genau
	# dorthin, wo er wirklich liegt. Das Ziel steht mitten drin.
	p1.spawn_fire_zone(p2.global_position)
	var fire_zones := _zones(EffectZone.Kind.FIRE)
	var gas_pos: Vector2 = fire_zones[0].global_position if not fire_zones.is_empty() else p2.global_position
	p2.global_position = gas_pos
	hp = p2.current_health
	p1.spawn_poison_cloud(gas_pos)
	await _wait(0.05)
	_check(_zones(EffectZone.Kind.POISON).is_empty(), "Gasexplosion verbraucht die Giftwolke")
	_check(p2.current_health <= hp - ElementReactions.GAS_EXPLOSION_DAMAGE * 0.5, "Gasexplosion trifft den Gegner")

	# Feuer trifft Eis = Dampf.
	_clear_zones()
	await _wait(0.05)
	p1.spawn_fire_zone(Vector2(600, 300))
	var steam_fire := _zones(EffectZone.Kind.FIRE)
	p1.spawn_frost_nova(steam_fire[0].global_position if not steam_fire.is_empty() else Vector2(600, 300))
	await _wait(0.05)
	_check(_zones(EffectZone.Kind.STEAM).size() == 1, "Feuer auf Eis ergibt eine Dampfwolke")

	# Blitz trifft Giftwolke = Giftgewitter.
	_clear_zones()
	await _wait(0.05)
	p1.spawn_poison_cloud(Vector2(800, 300))
	p1.spawn_lightning_zone(Vector2(800, 300))
	await _wait(0.05)
	_check(_zones(EffectZone.Kind.TOXIC_STORM).size() == 1, "Blitz in der Giftwolke ergibt ein Giftgewitter")

	# Geschoss-Einschlag in der Wolke.
	_clear_zones()
	await _wait(0.05)
	p1.spawn_poison_cloud(Vector2(1000, 300))
	ElementReactions.on_impact(Vector2(1000, 300), ["frost"], p1, get_tree())
	await _wait(0.05)
	_check(_zones(EffectZone.Kind.RIME).size() == 1, "Frost-Einschlag in der Giftwolke ergibt Giftreif")
	_clear_zones()

	# Reine Formen.
	Global.get_player_cards(1).clear()
	Global.add_card_to_player(1, CardDatabase.get_card("element_frost"))
	Global.add_card_to_player(1, CardDatabase.get_card("element_frost_rein"))
	p1.apply_stats()
	_check(p1.element_combos == ["permafrost"], "Frost doppelt ergibt Permafrost")
	_reset_target(p2)
	for i in 3:
		p2.apply_freeze(0.8, p1)
	_check(p2.stun_timer >= 0.6, "Permafrost friert nach 3 Treffern ein")
	hp = p2.current_health
	p2.take_damage(20.0, Vector2.ZERO, p1)
	_check(hp - p2.current_health >= 29.0, "Zersplittern: nächster Treffer +50 %% (%.0f)" % (hp - p2.current_health))

	Global.get_player_cards(1).clear()
	Global.add_card_to_player(1, CardDatabase.get_card("element_lightning"))
	Global.add_card_to_player(1, CardDatabase.get_card("element_lightning_rein"))
	p1.apply_stats()
	_reset_target(p2)
	hp = p2.current_health
	for i in ElementReactions.CHARGE_MAX:
		p2.apply_stun(0.05, p1)
	_check(p2.current_health <= hp - ElementReactions.DISCHARGE_DAMAGE + 0.5 and p2.stun_timer >= 0.35, "Hochspannung entlädt sich bei 5 Ladungen")

	Global.get_player_cards(1).clear()
	Global.add_card_to_player(1, CardDatabase.get_card("element_poison"))
	Global.add_card_to_player(1, CardDatabase.get_card("element_poison_rein"))
	p1.apply_stats()
	_reset_target(p2)
	p2.apply_poison(5, 4.0, p1)
	p2.apply_poison(5, 4.0, p1)
	_check(p2.poison_ticks_left == 10, "Seuche: Giftstapel addieren sich (%d)" % p2.poison_ticks_left)

	Global.get_player_cards(1).clear()
	Global.add_card_to_player(1, CardDatabase.get_card("element_fire"))
	Global.add_card_to_player(1, CardDatabase.get_card("element_fire_rein"))
	p1.apply_stats()
	_reset_target(p2)
	p2.apply_burn(3, 5.0, p1)
	p2.apply_burn(3, 5.0, p1)
	_check(p2.burn_ticks_left == 6, "Lauffeuer: Brand stapelt sich (%d)" % p2.burn_ticks_left)

	# Frost-Karten.
	Global.get_player_cards(1).clear()
	Global.add_card_to_player(1, CardDatabase.get_card("element_frost"))
	Global.add_card_to_player(1, CardDatabase.get_card("frost_tiefkuehlung"))
	Global.add_card_to_player(1, CardDatabase.get_card("frost_eissplitter"))
	p1.apply_stats()
	_reset_target(p2)
	p2.freeze_speed_mult = Player.FREEZE_SPEED_MULT
	p2.apply_freeze(1.0, p1)
	_check(absf(p2.freeze_speed_mult - 0.5) < 0.01, "Tiefkühlung: Getroffene laufen mit 50 % Tempo")
	_check(absf(ElementReactions.damage_taken_mult(p2, p1) - 1.15) < 0.01, "Eissplitter: +15 % gegen Verlangsamte")

	print("[TEST] fertig, Fehler: %d" % _failed)
	get_tree().quit(1 if _failed > 0 else 0)
