class_name ElementSystem
extends RefCounted

# Element-System: Jeder Eber hat höchstens MAX_SLOTS Element-Slots. Klassen mit
# Grundelement (Ignis, Volt, Spore, Flocke) belegen Slot 1 schon ab Start. Die
# übrigen Slots füllt nur die Karte "Element" im Draft (Unter-Draft mit den vier
# Elementkarten). Zwei verschiedene Elemente ergeben eine Kombination, zweimal
# dasselbe Element die reine Form. Siehe Entwurf "Element-System mit
# Synergie-Matrix" (2026-11-25).
#
# Alles hier ist rein aus Held + Kartenliste abgeleitet. Die Kartenliste ist auf
# allen Rechnern gleich (Draft-Picks laufen über den Host), deshalb braucht das
# System kein eigenes Netzwerkfeld.

const MAX_SLOTS: int = 2

const FIRE := "fire"
const POISON := "poison"
const FROST := "frost"
const LIGHTNING := "lightning"
const ELEMENTS: Array[String] = [FIRE, POISON, FROST, LIGHTNING]

const NAMES := {
	FIRE: "Feuer",
	POISON: "Gift",
	FROST: "Frost",
	LIGHTNING: "Blitz",
}
const COLORS := {
	FIRE: Color(1.0, 0.45, 0.12),
	POISON: Color(0.45, 0.92, 0.25),
	FROST: Color(0.45, 0.85, 1.0),
	LIGHTNING: Color(1.0, 0.9, 0.25),
}

# Grundelement der Klassen. Diese Klassen haben Slot 1 von Anfang an belegt.
const HERO_ELEMENTS := {
	"ignis": FIRE,
	"volt": LIGHTNING,
	"spore": POISON,
	"flocke": FROST,
}

# Grundkarte, die die erste Elementkarte eines Elements mitbringt. Fernkämpfer
# bekommen die Schusskarte, Nahkämpfer das Gegenstück aus dem Nahkampf-Pool.
const CORE_RANGED := {
	FIRE: "feuersturm",
	POISON: "giftschuss",
	FROST: "frostschuss",
	LIGHTNING: "blitzschuss",
}
const CORE_MELEE := {
	FIRE: "nk_gluehende_spitze",
	POISON: "nk_giftzahn",
	FROST: "nk_frostklinge",
	LIGHTNING: "nk_elektroschocker",
}

# Karten-IDs: "element_<id>" (erstes Mal) und "element_<id>_rein" (reine Form).
const PICK_CARD_ID := "element_wahl"

# Kombinationen (Matrix). Schlüssel = beide Elemente alphabetisch mit "+".
const COMBOS := {
	"fire+poison": "gasbrand",
	"fire+frost": "dampf",
	"fire+lightning": "plasma",
	"frost+poison": "giftreif",
	"lightning+poison": "neurotoxin",
	"frost+lightning": "supraleiter",
	"fire+fire": "lauffeuer",
	"poison+poison": "seuche",
	"frost+frost": "permafrost",
	"lightning+lightning": "hochspannung",
}

const COMBO_NAMES := {
	"gasbrand": "Gasbrand",
	"dampf": "Dampf",
	"plasma": "Plasma",
	"giftreif": "Giftreif",
	"neurotoxin": "Neurotoxin",
	"supraleiter": "Supraleiter",
	"lauffeuer": "Lauffeuer",
	"seuche": "Seuche",
	"permafrost": "Permafrost",
	"hochspannung": "Hochspannung",
}

# Kurztext für Elementkarten und Tooltips: was die Kombination im eigenen Build tut.
const COMBO_DESCRIPTIONS := {
	"gasbrand": "Deine Giftwolken brennen zusätzlich. Feuer auf Vergiftete lässt das Gift explodieren.",
	"dampf": "Dein Brand verlangsamt kurz. Thermoschock (Feuer auf Verlangsamte oder Frost auf Brennende) wird stärker.",
	"plasma": "Kettenblitze entzünden. Blitz auf Brennende schleudert Funken auf Gegner in der Nähe.",
	"giftreif": "Dein Gift verlangsamt kurz. Vergiftete und verlangsamte Ziele erleiden das Gift 40 % schneller.",
	"neurotoxin": "Kettenblitze übertragen Gift. Blitz auf Vergiftete verdoppelt die Betäubung.",
	"supraleiter": "Blitz auf Verlangsamte macht sie 5 s lang 30 % verwundbarer (sonst 3 s, 20 %).",
	"lauffeuer": "Brand stapelt sich bis dreifach und springt alle 1,2 s auf einen Gegner in der Nähe über.",
	"seuche": "Giftstapel addieren sich, ab 6 Stapeln tickt jeder weitere stärker. Vergiftete platzen beim Tod zu einer Giftwolke.",
	"permafrost": "3 Frost-Treffer in 2 s frieren ein (0,7 s). Der nächste Treffer zersplittert das Eis: +50 % Schaden.",
	"hochspannung": "Treffer laden Gegner auf. Bei 5 Ladungen entlädt sich der Strom: 20 Schaden und 0,4 s Betäubung im Umkreis.",
}

static func card_id_for(element: String, pure: bool) -> String:
	return "element_%s%s" % [element, "_rein" if pure else ""]

static func element_name(element: String) -> String:
	return str(NAMES.get(element, element))

static func element_color(element: String) -> Color:
	return COLORS.get(element, Color(0.8, 0.8, 0.8))

static func hero_element(hero_id: String) -> String:
	return str(HERO_ELEMENTS.get(hero_id, ""))

# Elemente eines Spielers: Grundelement der Klasse plus jede Elementkarte. Eine
# reine Elementkarte zählt wie eine zweite Karte desselben Elements.
static func elements_for(hero_id: String, owned_ids: Array) -> Array[String]:
	var result: Array[String] = []
	var innate := hero_element(hero_id)
	if not innate.is_empty():
		result.append(innate)
	for raw_id in owned_ids:
		var id := str(raw_id)
		if not id.begins_with("element_") or id == PICK_CARD_ID:
			continue
		var el := id.trim_prefix("element_").trim_suffix("_rein")
		if ELEMENTS.has(el):
			result.append(el)
	return result

static func free_slots(hero_id: String, owned_ids: Array) -> int:
	return maxi(0, MAX_SLOTS - elements_for(hero_id, owned_ids).size())

static func combo_for(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return str(COMBOS.get("%s+%s" % [pair[0], pair[1]], ""))

# Alle aktiven Kombinationen (bei 2 Slots höchstens eine).
static func combos_of(elements: Array) -> Array[String]:
	var result: Array[String] = []
	for i in elements.size():
		for j in range(i + 1, elements.size()):
			var c := combo_for(str(elements[i]), str(elements[j]))
			if not c.is_empty() and not result.has(c):
				result.append(c)
	return result

# Was ergibt die Wahl von `element` mit den vorhandenen Elementen? Leer = erstes Element.
static func preview_combo(current: Array, element: String) -> String:
	if current.is_empty():
		return ""
	return combo_for(str(current[0]), element)

static func core_card_for(element: String, melee: bool) -> String:
	return str((CORE_MELEE if melee else CORE_RANGED).get(element, ""))
