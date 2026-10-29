class_name CardMechanics
extends RefCounted

## Liefert Erklärungen für Kartenmechaniken. Wird von Draft, Lobby und HUD
## verwendet, damit Karten mit Gift, Frost, Feuer usw. beim Hovern verständlich
## bleiben und nicht nur als Zahlenwerte erscheinen.

const OWN_TOOLTIP_META := "own_tooltip"

# Anzeigename der Mechaniken aus CardData.required_mechanic (Begriffe wie im Glossar).
const MECHANIC_NAMES := {
	"bounce": "Abpraller",
	"shield": "Schild",
	"poison": "Gift",
	"frost": "Frost",
	"fire": "Feuer",
	"lightning": "Blitz",
	"tower": "Turm",
	"drone": "Drohnen",
	"mine": "Minen",
}
const UNLOCK_COLOR := Color(1.0, 0.72, 0.35)
const MAX_PROVIDER_NAMES := 4
const HERO_ICON_PATH := "res://assets/ui/hero_%s.svg"

static var _hero_icon_cache: Dictionary = {}

static func tooltip(card: CardData, include_meta: bool = false, extra: String = "") -> String:
	if card == null:
		return ""
	var lines: Array[String] = [card.title]
	if include_meta:
		lines.append("%s · %s" % [card.rarity, card.pool])
	lines.append(format_description(card.description))

	if is_evolution(card):
		var parent := CardDatabase.get_card(card.parent_card_id)
		var parent_title := parent.title if parent != null else card.parent_card_id
		var branch := card.evolution_branch if not card.evolution_branch.is_empty() else "?"
		lines.append("")
		lines.append("EVOLUTION: Ausbau von %s (Zweig %s)." % [parent_title, branch])

	var conditions := unlock_conditions(card)
	if not conditions.is_empty():
		lines.append("")
		lines.append("FREISCHALTUNG (erscheint erst, wenn erfüllt)")
		for condition in conditions:
			lines.append("• " + _wrap_line(condition))

	var evolutions := get_evolutions(card)
	if not evolutions.is_empty():
		lines.append("")
		lines.append("EVOLUTIONEN (nur ein Zweig wählbar)")
		for evo in evolutions:
			var evo_branch := evo.evolution_branch if not evo.evolution_branch.is_empty() else "?"
			lines.append("• Zweig %s: %s (%s)" % [evo_branch, evo.title, evo.rarity])
			for desc_line in format_description(evo.description).split("\n"):
				lines.append("   " + _wrap_line(desc_line))
			var next_titles := PackedStringArray()
			for next_evo in get_evolutions(evo):
				next_titles.append(next_evo.title)
			if not next_titles.is_empty():
				lines.append("   Danach: " + ", ".join(next_titles))

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
	# Teile mit eigenem Tooltip (z. B. Evolutionszeilen) behalten ihren Text.
	if node.has_meta(OWN_TOOLTIP_META):
		return
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
	if card.border_bounce:
		notes.append("GUMMIWAND: Deine Kugeln prallen am Kartenrand ab, statt hinauszufliegen. Das kostet keinen Abpraller; die Kugel fliegt, bis ihre Flugzeit abläuft.")
	if card.bounce_split:
		notes.append("ZELLTEILUNG: Bei jedem Abprall (auch am Kartenrand mit Gummiwand) teilt sich die Kugel in zwei kleinere mit je 60% Schaden. Höchstens 3 Teilungen pro Schuss, also maximal 8 Teile.")
	if card.self_damage_reduction_add > 0.0:
		notes.append("SELBSTSCHADEN: Eigene Kugeln (z. B. zurückfallende Schüsse oder Abpraller), Explosionen und Flächen treffen dich ohnehin nur mit halbem Schaden. Diese Karte verringert den Rest weiter (höchstens 90%).")
	if card.piercing_add > 0:
		notes.append("DURCHSCHLAG: Projektile durchdringen Gegner und treffen dahinterliegende Ziele. Jeder Durchschlag verbraucht sich beim Treffer. Zusätzlich fliegt das Projektil pro Punkt durch 0,5 Tile feste Wand oder 1 Tile zerstörbare Blöcke; Blöcke auf dem Weg bekommen dabei einen Treffer ab. Der Kartenrand hält.")
	if card.homing_strength_add > 0.0:
		notes.append("ZIELSUCHE: Projektile lenken automatisch zum Gegner. Weit entfernt nur leicht, in der Nähe des Gegners (unter ca. 4 Tiles) deutlich stärker.")
	if card.multishot_add > 0 or card.spread_angle_deg > 0.0:
		notes.append("MEHRSCHUSS: Zusätzliche Projektile werden mit Streuung abgefeuert. Jedes Projektil verursacht den angezeigten Schaden.")
	if card.lifesteal_percent_add > 0.0:
		notes.append("LEBENSRAUB: Ein Anteil des verursachten Schadens wird als Leben zurückgewonnen.")
	if card.shield_max_add > 0 or card.shield_regen_mult > 1.0 or card.shield_regen_delay_add < 0.0:
		notes.append("SCHILD: Schild absorbiert Schaden, bevor Leben verloren geht. Schild-Regeneration baut ihn nach 3 s ohne Schaden wieder auf (Karten können die Pause verkürzen). Schild-Verbesserungen erscheinen erst ab 25 Schild. Auf der Lebensleiste über dem Spieler wird aktiver Schild als blaues Overlay angezeigt.")
	if card.armor_percent_add > 0.0:
		notes.append("RÜSTUNG: Reduziert eingehenden Schaden prozentual, bevor Schild und Leben getroffen werden. Mehrere Rüstungskarten addieren sich, maximal 75 %.")
	if card.damage_reflect_percent_add > 0.0:
		notes.append("REFLEXION: Ein Anteil des tatsächlich erlittenen Schadens wird an den angreifenden Spieler zurückgeworfen. Mehrere Reflexionskarten addieren sich, maximal 60 %.")
	if card.reflect_low_hp_bonus_add > 0.0:
		notes.append("RACHE: Unter 35 % Leben steigt deine Schadensreflexion zusätzlich (Gesamtgrenze 60 %).")
	if card.reflect_heal_percent_add > 0.0:
		notes.append("BLUTSPIEGEL: Ein Anteil des Schadens, den deine Reflexion beim Angreifer anrichtet, heilt dich.")
	if has_melee_effect(card):
		notes.append("NAHKAMPF (E): Schlag mit der im Charakter-Tab gewählten Nahkampfwaffe. Nahkampfkarten wirken nur auf diesen Schlag, nicht auf Schüsse. Reichweite zählt in Feldern (36 px) ab deinem Körperrand.")
	if card.melee_freeze_add > 0.0:
		notes.append("NAHKAMPF-FROST: Getroffene Gegner werden für die angegebene Dauer um 40% verlangsamt.")
	if card.melee_poison_stacks_add > 0:
		notes.append("NAHKAMPF-GIFT: Jeder Treffer gibt Giftstapel; jeder Stapel verursacht alle 0,8 s einen Schadens-Tick.")
	if card.melee_burn_stacks_add > 0:
		notes.append("NAHKAMPF-FEUER: Getroffene Gegner brennen über mehrere Ticks.")
	if card.melee_stun_add > 0.0 or card.melee_chain_lightning:
		notes.append("NAHKAMPF-ELEKTRO: Betäubte Gegner können sich kurz weder bewegen noch angreifen. Der Blitz springt auf den nächsten weiteren Gegner in ca. 6 Feldern.")
	if card.melee_wall_stun_add > 0.0:
		notes.append("WANDKLATSCHER: Fliegt ein getroffener Gegner innerhalb von 0,45 s gegen Wand oder Decke, ist er betäubt. Stapelt mit der Betäubung des Hammers.")
	if card.melee_parry:
		notes.append("PARADE: Ist der Nahkampfschlag bereit, löst er automatisch aus, sobald ein gegnerisches Projektil in Reichweite auf dich zufliegt. Projektile im Schlagbereich werden wie beim Block zurückgeworfen.")
	if _has_block_effect(card):
		notes.append("BLOCK (Q): Blockt kurzzeitig Schaden, reflektiert Projektile und hat einen eigenen Cooldown.")
	if card.block_mine or card.mine_damage_add > 0.0 or card.mine_radius_add > 0.0 or card.mine_instant:
		notes.append("MINEN: Jeder Block lässt eine Mine fallen, die auf dem Boden darunter liegen bleibt (auf Plattformen und Wippen fährt sie mit). Gegner sehen sie nicht, am selben Bildschirm ist sie nur schwach zu erkennen. Nach 2 s ist sie scharf; läuft ein Gegner darüber, blinkt sie und explodiert 1,5 s später (Sofortzünder: sofort). Höchstens 8 Minen pro Spieler, die älteste verschwindet. Minen treffen nur Gegner.")
	if card.dash_cooldown_mult < 1.0:
		notes.append("DASH (Shift): Kurzer Ausweichsprung mit Unverwundbarkeit. Der Cooldown beginnt sofort.")
	if card.ability_cooldown_mult < 1.0:
		notes.append("HELDENFÄHIGKEIT (Rechtsklick): Aktive Fähigkeit deines Helden mit eigenem Cooldown.")
	if CardDatabase.is_powerup_card(card):
		notes.append("POWERUPS: Gilt für eingesammelte Powerups. Schutz, Schaden, Dauerfeuer, Auto-Angriff, Multishot, Rache und Unsichtbar halten länger, das Unsterblichkeits-Fenster wird länger, Heilung heilt mehr. Mehrere Powerup-Karten addieren sich. Sammelreichweite zieht Powerups im angegebenen Umkreis (1 Feld = 36 px) zu dir. Welche Powerups erscheinen, legt der Host im Lobby-Reiter „Powerups“ fest.")
	if _has_ability_effect(card):
		notes.append("FÄHIGKEITS-UPGRADE: Verstärkt die Heldenfähigkeit (Rechtsklick) deiner Klasse. Evolutionen geben ihr einen neuen Effekt; pro Fähigkeit kannst du nur einen Evolutionszweig wählen.")
	if card.tower_enabled or card.tower_auto_spawn or card.tower_follow \
			or card.tower_max_health_add > 0 or card.tower_fire_rate_mult < 1.0:
		notes.append("TURM: Ein Turm kämpft automatisch für dich. Türme haben 100 Grundleben, verlieren 5% ihres Maximallebens pro Sekunde (höchstens 20 s Lebensdauer), können zerstört werden und greifen Gegner in Reichweite an.")
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
	if card.knockback_mult > 1.0:
		notes.append("RÜCKSTOSS: Treffer schleudern Gegner weiter zurück und nehmen ihnen kurz Bewegungskontrolle. Der Bonus wirkt auf Projektile, Explosionen und Fähigkeiten.")
	if card.giant_growth > 0.0 or card.body_size_mult < 1.0:
		notes.append("GRÖSSE: Ändert die Trefferfläche deiner Spielfigur.")
	if card.kamikaze:
		notes.append("KAMIKAZE: Beim K.O. explodiert die Figur und verursacht Flächenschaden.")
	if card.hp_regen_always_add > 0.0:
		notes.append("REGENERATION: Heilt kontinuierlich, auch während du Schaden nimmst.")
	if card.hp_regen_add > 0.0:
		notes.append("REGENERATION: Heilt kontinuierlich, auch direkt nach Treffern.")
	if card.fire_rate_mult < 1.0 or card.reload_speed_mult > 1.0 or card.max_ammo_add > 0:
		notes.append("WAFFE: Jeder Schuss verbraucht Munition. Ist das Magazin leer, wird automatisch nachgeladen. Feuerrate, Nachladegeschwindigkeit und Magazingröße bestimmen den Rhythmus.")
	return notes

static func has_melee_effect(card: CardData) -> bool:
	return card.melee_damage_mult != 1.0 \
		or card.melee_range_add > 0.0 \
		or card.melee_cooldown_mult != 1.0 \
		or card.melee_knockback_mult != 1.0 \
		or card.melee_arc_add > 0.0 \
		or card.melee_freeze_add > 0.0 \
		or card.melee_poison_stacks_add > 0 \
		or card.melee_stun_add > 0.0 \
		or card.melee_burn_stacks_add > 0 \
		or card.melee_lifesteal_add > 0.0 \
		or card.melee_wall_stun_add > 0.0 \
		or card.melee_execute_bonus_add > 0.0 \
		or card.melee_chain_lightning \
		or card.melee_echo \
		or card.melee_parry

static func _has_block_effect(card: CardData) -> bool:
	return card.block_duration_add > 0.0 \
		or card.block_cooldown_mult < 1.0 \
		or card.block_reflect_damage_add > 0.0 \
		or card.block_knockback_radius_add > 0.0 \
		or card.block_knockback_force_add > 0.0 \
		or card.block_bomb \
		or card.block_heal_zone \
		or card.block_mine \
		or card.mine_damage_add > 0.0 \
		or card.mine_radius_add > 0.0 \
		or card.mine_instant

static func _has_ability_effect(card: CardData) -> bool:
	return card.ability_damage_mult != 1.0 \
		or card.ability_radius_mult != 1.0 \
		or card.ability_duration_mult != 1.0 \
		or card.ability_range_mult != 1.0 \
		or not card.ability_evolution.is_empty()

## Alle Bedingungen, unter denen die Karte im Draft angeboten wird
## (siehe CardDatabase.is_card_available_for_player). Leer = immer verfügbar.
static func unlock_conditions(card: CardData) -> Array[String]:
	var result: Array[String] = []
	if card == null:
		return result
	if not card.hero_id.is_empty():
		result.append("Nur für Klasse %s." % Global.get_hero(card.hero_id).name)
	if is_evolution(card):
		var parent := CardDatabase.get_card(card.parent_card_id)
		var parent_title := parent.title if parent != null else card.parent_card_id
		result.append("%s im Deck." % parent_title)
		if not card.evolution_branch.is_empty():
			result.append("Kein anderer Zweig dieses Talentbaums gewählt.")
	var mechanic_text := _mechanic_condition(card.required_mechanic)
	if not mechanic_text.is_empty():
		result.append(mechanic_text)
	if CardDatabase.is_powerup_card(card):
		result.append("Mindestens ein Powerup ist in der Lobby aktiv.")
	if card.hero_id.is_empty() and card.ability_damage_mult > 1.0:
		for hero_id in CardDatabase.ABILITY_DAMAGE_UNLOCK_CARDS:
			var unlock := CardDatabase.get_card(CardDatabase.ABILITY_DAMAGE_UNLOCK_CARDS[hero_id])
			result.append("%s: erst mit %s im Deck." % [Global.get_hero(hero_id).name,
				unlock.title if unlock != null else CardDatabase.ABILITY_DAMAGE_UNLOCK_CARDS[hero_id]])
	return result

## Kurzform der Mechanik-Bedingung für die Kartenansicht, z. B. "BENÖTIGT: ABPRALLER".
## Klasse und Talentbaum haben schon eigene Badges und fehlen hier.
static func unlock_short_text(card: CardData) -> String:
	if card == null or not _mechanic_has_condition(card.required_mechanic):
		return ""
	var mechanic := card.required_mechanic
	if mechanic == "shield":
		return "BENÖTIGT: %d SCHILD" % CardDatabase.SHIELD_UPGRADE_MIN
	return "BENÖTIGT: %s" % str(MECHANIC_NAMES.get(mechanic, mechanic)).to_upper()

## Label mit unlock_short_text, oder null wenn die Karte keine Mechanik-Bedingung hat.
static func make_unlock_label(card: CardData, font_size: int = 11, centered: bool = true) -> Label:
	var text := unlock_short_text(card)
	if text.is_empty():
		return null
	var label := Label.new()
	label.text = text
	if centered:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UNLOCK_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Klassen-Icon (assets/ui/hero_<id>.svg), gecacht. null ohne Klasse oder Datei.
static func get_hero_icon(hero_id: String) -> Texture2D:
	if hero_id.is_empty():
		return null
	if _hero_icon_cache.has(hero_id):
		return _hero_icon_cache[hero_id]
	var path := HERO_ICON_PATH % hero_id
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_hero_icon_cache[hero_id] = texture
	return texture

## Zentrierte Zeile "[Icon] KLASSE: NAME" in der Klassenfarbe, oder null ohne Klasse.
static func make_class_badge(card: CardData, font_size: int = 12) -> Control:
	if card == null or card.hero_id.is_empty():
		return null
	var hero: HeroData = Global.get_hero(card.hero_id)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var texture := get_hero_icon(card.hero_id)
	if texture != null:
		var icon := TextureRect.new()
		var icon_size := float(font_size) * 1.9
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var label := Label.new()
	label.text = "KLASSE: %s" % hero.name.to_upper()
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", hero.color_tint)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return row

static func _mechanic_has_condition(mechanic: String) -> bool:
	return not mechanic.is_empty() and not CardDatabase.ALWAYS_AVAILABLE_MECHANICS.has(mechanic)

static func _mechanic_condition(mechanic: String) -> String:
	if not _mechanic_has_condition(mechanic):
		return ""
	if mechanic == "shield":
		return "Mindestens %d Schild (Held + Karten)." % CardDatabase.SHIELD_UPGRADE_MIN
	var mechanic_name := str(MECHANIC_NAMES.get(mechanic, mechanic))
	var text := "Eine %s-Karte im Deck" % mechanic_name
	if CardDatabase.HERO_MECHANICS.has(mechanic):
		text += " oder Klasse %s" % Global.get_hero(CardDatabase.HERO_MECHANICS[mechanic]).name
	var names := PackedStringArray()
	var providers := CardDatabase.get_mechanic_providers(mechanic)
	for provider in providers:
		if names.size() >= MAX_PROVIDER_NAMES:
			break
		names.append(provider.title)
	if not names.is_empty():
		var more := ", …" if providers.size() > names.size() else ""
		text += " (z. B. %s%s)" % [", ".join(names), more]
	return text + "."

static func is_evolution(card: CardData) -> bool:
	return card != null and not card.parent_card_id.is_empty()

## Direkte Ausbaukarten (Evolutionen), die auf dieser Karte aufbauen, nach Zweig sortiert.
static func get_evolutions(card: CardData) -> Array[CardData]:
	var result: Array[CardData] = []
	if card == null or card.id.is_empty():
		return result
	for other in CardDatabase.all_cards:
		if other.parent_card_id == card.id:
			result.append(other)
	result.sort_custom(func(a: CardData, b: CardData): return a.evolution_branch < b.evolution_branch)
	return result

## Kompakte Liste der Evolutionen auf einer Karte. Jede Zeile hat beim Hovern
## einen eigenen Tooltip mit allen Details dieser Evolution.
## Gibt null zurück, wenn die Karte keine Evolutionen hat.
static func make_evolutions_preview(card: CardData, font_size: int = 11) -> Control:
	var evolutions := get_evolutions(card)
	if evolutions.is_empty():
		return null
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)

	var header := Label.new()
	header.text = "EVOLUTIONEN"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", font_size - 1)
	header.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	for evo in evolutions:
		var row := PanelContainer.new()
		# PASS statt IGNORE, damit die Zeile ihren eigenen Tooltip zeigt.
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.12, 0.32, 0.92)
		style.set_corner_radius_all(4)
		style.border_width_left = 3
		style.border_color = CardDatabase.get_rarity_color(evo.rarity)
		style.content_margin_left = 6
		style.content_margin_right = 4
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		row.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		var branch := evo.evolution_branch if not evo.evolution_branch.is_empty() else "•"
		label.text = "%s · %s" % [branch, evo.title]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 1.0))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)

		row.tooltip_text = tooltip(evo, true)
		row.set_meta(OWN_TOOLTIP_META, true)
		box.add_child(row)
	return box

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

# Kartenbeschreibung für die Anzeige: Stehen mehrere Werte in einer Zeile
# ("+20% Schaden, -10% Tempo"), bekommt jeder Wert eine eigene Zeile. Fließtext
# mit Kommas bleibt unverändert, damit nur echte Wertelisten umgebrochen werden.
static func format_description(text: String) -> String:
	if text.is_empty():
		return text
	# "...Satzende. +20% Wolkenschaden." -> Wert in eine neue Zeile.
	var sentence_break := RegEx.new()
	sentence_break.compile("([.!?]) ([+\\-−]\\d)")
	var source := sentence_break.sub(text, "$1\n$2", true)
	var out := PackedStringArray()
	for raw_line in source.split("\n"):
		out.append(_split_stat_line(raw_line))
	return "\n".join(out)

static func _split_stat_line(line: String) -> String:
	var prefix := ""
	var body := line.strip_edges()
	var colon := body.find(": ")
	if colon > 0:
		prefix = body.substr(0, colon + 1)
		body = body.substr(colon + 2)
	# "+60px Explosionsradius und +15% Schaden" zählt wie eine Kommaliste.
	var und_break := RegEx.new()
	und_break.compile(" und (?=[+\\-−]\\d)")
	body = und_break.sub(body, ", ", true)
	var segments := _split_outside_parens(body)
	if segments.size() < 2:
		return line
	for segment in segments:
		if not _is_stat_segment(segment):
			return line
	var lines := PackedStringArray()
	if not prefix.is_empty():
		lines.append(prefix)
	for segment in segments:
		lines.append(segment.trim_suffix("."))
	return "\n".join(lines)

# Trennt an ", ", aber nicht innerhalb von Klammern.
static func _split_outside_parens(text: String) -> PackedStringArray:
	var parts := PackedStringArray()
	var depth := 0
	var current := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "(":
			depth += 1
		elif ch == ")":
			depth = maxi(depth - 1, 0)
		if ch == "," and depth == 0 and i + 1 < text.length() and text[i + 1] == " ":
			parts.append(current.strip_edges())
			current = ""
			i += 2
			continue
		current += ch
		i += 1
	parts.append(current.strip_edges())
	return parts

# Ein Wert ist kurz, kein ganzer Satz und beginnt mit +/- oder enthält eine Zahl.
static func _is_stat_segment(segment: String) -> bool:
	var core := segment.trim_suffix(".")
	if core.is_empty():
		return false
	if core.contains(". ") or core.contains("! ") or core.contains("? "):
		return false
	if core.split(" ", false).size() > 8:
		return false
	var first := core[0]
	if first == "+" or first == "-" or first == "−":
		return true
	for ch in core:
		if ch >= "0" and ch <= "9":
			return true
	return false

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
