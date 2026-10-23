class_name CardMechanics
extends RefCounted

## Liefert Erklärungen für Kartenmechaniken. Wird von Draft, Lobby und HUD
## verwendet, damit Karten mit Gift, Frost, Feuer usw. beim Hovern verständlich
## bleiben und nicht nur als Zahlenwerte erscheinen.

static func tooltip(card: CardData, include_meta: bool = false, extra: String = "") -> String:
	if card == null:
		return ""
	var lines: Array[String] = [card.title]
	if include_meta:
		lines.append("%s · %s" % [card.rarity, card.pool])
	lines.append(card.description)

	if is_evolution(card):
		var parent := CardDatabase.get_card(card.parent_card_id)
		var parent_title := parent.title if parent != null else card.parent_card_id
		var branch := card.evolution_branch if not card.evolution_branch.is_empty() else "?"
		lines.append("")
		lines.append("EVOLUTION: Ausbau von %s (Zweig %s)." % [parent_title, branch])

	var notes := mechanic_notes(card)
	if not notes.is_empty():
		lines.append("")
		lines.append("MECHANIK")
		for note in notes:
			lines.append("• " + _wrap_line(note))

	if not extra.is_empty():
		lines.append("")
		lines.append(extra)

	var packed := PackedStringArray()
	for line in lines:
		packed.append(line)
	return "\n".join(packed)

static func apply_tooltip(root: Control, card: CardData, include_meta: bool = false, extra: String = "") -> void:
	if root == null or card == null:
		return
	var text := tooltip(card, include_meta, extra)
	_apply_tooltip_recursive(root, text)

static func _apply_tooltip_recursive(node: Node, text: String) -> void:
	if node is Control:
		node.tooltip_text = text
	for child in node.get_children():
		_apply_tooltip_recursive(child, text)

static func mechanic_notes(card: CardData) -> Array[String]:
	var notes: Array[String] = []
	if card == null:
		return notes

	if card.poison_stacks_add > 0 or card.poison_damage_mult > 1.0 \
			or card.poison_impact_cloud or card.poison_trail:
		notes.append("GIFT: Jeder Giftstapel verursacht alle 0,8 s einen Schadens-Tick. Mehr Stapel halten länger; höherer Giftschaden verstärkt jeden Tick.")
	if card.freeze_duration_add > 0.0 or card.frost_nova or card.frost_trail:
		notes.append("FROST: Getroffene Gegner werden für die angegebene Dauer um 40% verlangsamt. Eisnova und Eisbahn erzeugen zusätzliche Kälteflächen.")
	if card.fire_shot or card.fire_impact_zone or card.fire_trail:
		notes.append("FEUER: Entzündete Gegner brennen über mehrere Ticks. Feuerflächen entzünden Gegner beim Betreten.")
	if card.lightning_shot or card.chain_lightning or card.lightning_zone:
		notes.append("BLITZ: Blitzschüsse betäuben kurz. Kettenblitz springt auf nahe Gegner über; Blitzzonen betäuben beim Betreten.")
	if card.explosion_radius_add > 0.0 or card.cluster_bomblets:
		notes.append("EXPLOSION: Flächenschaden um den Einschlag. Ein größerer Radius trifft mehr Gegner.")
	if card.bounces_add > 0:
		notes.append("ABPRALLER: Projektile prallen von Wänden ab. Jeder Abpraller erlaubt einen weiteren Treffer.")
	if card.piercing_add > 0:
		notes.append("DURCHSCHLAG: Projektile durchdringen Gegner und treffen dahinterliegende Ziele. Jeder Durchschlag verbraucht sich beim Treffer.")
	if card.homing_strength_add > 0.0:
		notes.append("ZIELSUCHE: Projektile lenken automatisch in Richtung des nächsten Gegners.")
	if card.multishot_add > 0 or card.spread_angle_deg > 0.0:
		notes.append("MEHRSCHUSS: Zusätzliche Projektile werden mit Streuung abgefeuert. Jedes Projektil verursacht den angezeigten Schaden.")
	if card.lifesteal_percent_add > 0.0:
		notes.append("LEBENSRAUB: Ein Anteil des verursachten Schadens wird als Leben zurückgewonnen.")
	if card.shield_max_add > 0 or card.shield_regen_mult > 1.0:
		notes.append("SCHILD: Schild absorbiert Schaden, bevor Leben verloren geht. Schild-Regeneration baut ihn nach 3,5 s ohne Schaden wieder auf.")
	if _has_block_effect(card):
		notes.append("BLOCK (Q): Blockt kurzzeitig Schaden, reflektiert Projektile und hat einen eigenen Cooldown.")
	if card.dash_cooldown_mult < 1.0:
		notes.append("DASH (Shift): Kurzer Ausweichsprung mit Unverwundbarkeit. Der Cooldown beginnt sofort.")
	if card.ability_cooldown_mult < 1.0:
		notes.append("HELDENFÄHIGKEIT (Rechtsklick/E): Aktive Fähigkeit deines Helden mit eigenem Cooldown.")
	if card.tower_enabled or card.tower_auto_spawn or card.tower_follow:
		notes.append("TURM: Ein Turm kämpft automatisch für dich. Türme können Ziele beschießen und ggf. bewegt werden.")
	if card.drone_count_add > 0 or card.drone_guardian:
		notes.append("WÄCHTERDROHNE: Eine Drohne umkreist dich und beschießt automatisch Gegner. Regenerationsdrohnen heilen dich zusätzlich über Zeit.")
	if card.blocker_drone_count_add > 0 or card.blocker_drone_heal:
		var blocker_note := "SCHUTZDROHNE: Kreist um dich, schießt nicht und fängt gegnerische Projektile ab."
		if card.blocker_drone_heal:
			blocker_note += " Jeder abgefangene Schuss heilt dich um den geblockten Schaden."
		notes.append(blocker_note)
	if card.extra_jumps_add > 0 or card.jump_force_mult > 1.0:
		notes.append("SPRUNG: Zusätzliche Luft-Sprünge erlauben weitere Richtungswechsel in der Luft.")
	if card.gravity_mult < 1.0:
		notes.append("SCHWERKRAFT: Du fällst langsamer und bleibst länger in der Luft.")
	if card.projectile_gravity_mult > 1.0:
		notes.append("BALLISTIK: Deine Projektile fallen stärker und beschreiben eine deutliche Kurve. Mörser treffen auch Ziele hinter Deckung.")
	elif card.projectile_gravity_mult < 1.0:
		notes.append("BALLISTIK: Deine Projektile fallen langsamer und fliegen flacher. Das erleichtert direkte Treffer auf Distanz.")
	if card.giant_growth > 0.0 or card.body_size_mult < 1.0:
		notes.append("GRÖSSE: Ändert die Trefferfläche deiner Spielfigur.")
	if card.kamikaze:
		notes.append("KAMIKAZE: Beim K.O. explodiert die Figur und verursacht Flächenschaden.")
	if card.hp_regen_add > 0.0:
		notes.append("REGENERATION: Heilt nach 3 s ohne Schaden kontinuierlich.")
	if card.fire_rate_mult < 1.0 or card.reload_speed_mult > 1.0 or card.max_ammo_add > 0:
		notes.append("WAFFE: Jeder Schuss verbraucht Munition. Ist das Magazin leer, wird automatisch nachgeladen. Feuerrate, Nachladegeschwindigkeit und Magazingröße bestimmen den Rhythmus.")
	return notes

static func _has_block_effect(card: CardData) -> bool:
	return card.block_duration_add > 0.0 \
		or card.block_cooldown_mult < 1.0 \
		or card.block_reflect_damage_add > 0.0 \
		or card.block_knockback_radius_add > 0.0 \
		or card.block_knockback_force_add > 0.0 \
		or card.block_bomb \
		or card.block_heal_zone

static func is_evolution(card: CardData) -> bool:
	return card != null and not card.parent_card_id.is_empty()

## Baut das deutlich sichtbare EVOLUTION-Band, das auf Ausbaukarten liegt.
## Gibt null zurück, wenn die Karte keine Evolution ist.
static func make_evolution_banner(card: CardData, font_size: int = 11) -> Control:
	if not is_evolution(card):
		return null
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.36, 0.18, 0.55, 0.96)
	style.set_corner_radius_all(5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.55, 1.0, 0.95)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	banner.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = "EVOLUTION"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 1.0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(label)
	return banner

# Bricht lange Mechaniktexte um, damit Godots Standard-Tooltip nicht über den
# Bildschirmrand hinauswächst. Fortsetzungszeilen bleiben eingerückt.
static func _wrap_line(text: String, max_length: int = 92) -> String:
	var words := text.split(" ", false)
	if words.is_empty():
		return text
	var result := ""
	var current := ""
	for word in words:
		if current.is_empty():
			current = word
		elif current.length() + 1 + word.length() <= max_length:
			current += " " + word
		else:
			result += current + "\n  "
			current = word
	return result + current
