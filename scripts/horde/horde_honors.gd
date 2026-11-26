class_name HordeHonors
extends RefCounted

# Ehrungen am Ende einer Jagd (Horden-Modus).
#
# Der Host wählt sie in HordeDirector._build_final_report aus slot_stats
# (Kills, Schaden, Tode) und detail_stats (Bossschaden, Riesen, Serien,
# Kristalle, ...). Die Liste ({"id", "slot", "value", "v2"}) geht mit dem
# Endstand ("fin") an die Clients; Texte baut jeder Rechner selbst
# (describe(), gleiche Form wie MatchHonors.describe für die Kacheln).

const MAX_HONORS: int = 8
const MAX_FUN_HONORS: int = 2

# Reihenfolge = Priorität bei der Auswahl.
const DEFS: Dictionary = {
	"mvp": {"title": "MVP der Jagd", "icon": "★", "color": Color(1.0, 0.82, 0.30), "flavor": "Bester Jagdwert: Kills, Schaden, Bosse, Riesen und Hilfe fürs Team, abzüglich Tode"},
	"boss_kill": {"title": "Bossbezwinger", "icon": "♛", "color": Color(1.0, 0.70, 0.25), "flavor": "Die meisten Bosse erlegt (letzter Treffer)"},
	"boss": {"title": "Bossjäger", "icon": "☠", "color": Color(1.0, 0.40, 0.35), "flavor": "Meister Schaden an Bossen"},
	"damage": {"title": "Schadenskönig", "icon": "✸", "color": Color(1.0, 0.45, 0.30), "flavor": "Meister Schaden an der Horde"},
	"kills": {"title": "Schlächter", "icon": "⚔", "color": Color(0.95, 0.30, 0.30), "flavor": "Die meisten Gegner erlegt"},
	"streak": {"title": "Amokläufer", "icon": "⚡", "color": Color(1.0, 0.62, 0.20), "flavor": "Die meisten Kills in einem Leben"},
	"giants": {"title": "Riesentöter", "icon": "▲", "color": Color(0.95, 0.80, 0.40), "flavor": "Die meisten Riesen erlegt"},
	"survivor": {"title": "Unkaputtbar", "icon": "☘", "color": Color(0.55, 0.95, 0.45), "flavor": "Am längsten am Stück überlebt"},
	"collector": {"title": "Kristallsammler", "icon": "◆", "color": Color(0.45, 0.80, 1.0), "flavor": "Die meisten Erfahrungskristalle eingesammelt"},
	"medic": {"title": "Sanitäter", "icon": "♥", "color": Color(0.45, 1.0, 0.55), "flavor": "Meiste Heilung"},
	"ability": {"title": "Fähigkeiten-Ass", "icon": "✦", "color": Color(0.55, 0.75, 1.0), "flavor": "Meister Fähigkeitsschaden"},
	"melee": {"title": "Nahkampf-Metzger", "icon": "⚒", "color": Color(0.95, 0.65, 0.45), "flavor": "Meister Nahkampfschaden"},
	"wall": {"title": "Bollwerk", "icon": "⛨", "color": Color(0.45, 0.70, 1.0), "flavor": "Meister Schaden abgeblockt"},
	"eagles": {"title": "Adlerauge", "icon": "➶", "color": Color(0.70, 0.90, 1.0), "flavor": "Die meisten Adler vom Himmel geholt"},
	"glutton": {"title": "Vielfraß", "icon": "●", "color": Color(0.85, 0.65, 0.35), "flavor": "Die meisten Eicheln gefuttert", "fun": true},
	"unlucky": {"title": "Größter Pechvogel", "icon": "☂", "color": Color(0.70, 0.72, 0.80), "flavor": "Am häufigsten gefallen", "fun": true},
	"sponge": {"title": "Kugelfang", "icon": "◉", "color": Color(0.70, 0.60, 0.55), "flavor": "Am meisten Schaden eingesteckt", "fun": true},
}

# Mindestwerte, damit niemand für einen Adler geehrt wird.
const MIN_VALUES: Dictionary = {
	"boss_kill": 1.0, "boss": 300.0, "damage": 1.0, "kills": 10.0, "streak": 30.0,
	"giants": 2.0, "survivor": 90.0, "collector": 30.0, "medic": 100.0,
	"ability": 300.0, "melee": 300.0, "wall": 150.0, "eagles": 8.0,
	"glutton": 3.0, "unlucky": 2.0, "sponge": 200.0,
}

## Jagdwert für den MVP (auch im Endbildschirm als Spalte).
static func hunt_score(d: HordeDirector, slot: int) -> float:
	var s: Dictionary = d.slot_stats.get(slot, d.slot_stats.get(str(slot), {}))
	return float(s.get("kills", 0)) \
		+ float(s.get("damage", 0.0)) / 60.0 \
		+ d.report_value(slot, "boss_dmg") / 30.0 \
		+ d.report_value(slot, "giants") * 2.0 \
		+ d.report_value(slot, "bosses") * 15.0 \
		+ d.report_value(slot, "healing_done") / 40.0 \
		+ d.report_value(slot, "damage_blocked") / 80.0 \
		- float(s.get("deaths", 0)) * 4.0

static func compute(d: HordeDirector) -> Array:
	var slots: Array[int] = Global.get_active_player_indices()
	if slots.is_empty():
		return []
	var stat := func(slot: int, key: String) -> float:
		var s: Dictionary = d.slot_stats.get(slot, d.slot_stats.get(str(slot), {}))
		return float(s.get(key, 0.0))
	var rep := func(key: String) -> Callable:
		return func(slot: int) -> float: return d.report_value(slot, key)

	var candidates: Array = []
	# MVP erst ab zwei Ebern, solo wäre es nur ein Selbstlob.
	if slots.size() >= 2:
		candidates.append_array(_leader("mvp", slots, func(slot: int) -> float: return hunt_score(d, slot), -INF))
	# Bossbezwinger: bei Gleichstand entscheidet der Bossschaden.
	candidates.append_array(_leader("boss_kill", slots, func(slot: int) -> float: return d.report_value(slot, "bosses") + minf(d.report_value(slot, "boss_dmg"), 999999.0) / 1000000.0))
	candidates.append_array(_leader("boss", slots, rep.call("boss_dmg")))
	candidates.append_array(_leader("damage", slots, func(slot: int) -> float: return stat.call(slot, "damage")))
	candidates.append_array(_leader("kills", slots, func(slot: int) -> float: return stat.call(slot, "kills")))
	candidates.append_array(_leader("streak", slots, rep.call("best_streak")))
	candidates.append_array(_leader("giants", slots, rep.call("giants")))
	candidates.append_array(_leader("survivor", slots, rep.call("best_life")))
	candidates.append_array(_leader("collector", slots, rep.call("xp")))
	candidates.append_array(_leader("medic", slots, rep.call("healing_done")))
	candidates.append_array(_leader("ability", slots, rep.call("ability_damage")))
	candidates.append_array(_leader("melee", slots, rep.call("melee_damage")))
	candidates.append_array(_leader("wall", slots, rep.call("damage_blocked")))
	candidates.append_array(_leader("eagles", slots, rep.call("eagles")))
	candidates.append_array(_leader("glutton", slots, rep.call("food")))
	candidates.append_array(_leader("unlucky", slots, func(slot: int) -> float: return stat.call(slot, "deaths")))
	candidates.append_array(_leader("sponge", slots, rep.call("damage_taken")))
	return _select(candidates, slots.size())

static func _leader(id: String, slots: Array[int], value_of: Callable, min_value: float = NAN) -> Array:
	var best_slot := 0
	var best := -INF
	for slot in slots:
		var value := float(value_of.call(slot))
		if value > best:
			best = value
			best_slot = slot
	var needed := float(MIN_VALUES.get(id, 0.0)) if is_nan(min_value) else min_value
	if best_slot <= 0 or best < needed:
		return []
	return [{"id": id, "slot": best_slot, "value": snappedf(best, 0.1)}]

# Höchstens MAX_HONORS, pro Eber begrenzt, damit nicht einer alles abräumt
# (solo bekommt der eine Eber alle).
static func _select(candidates: Array, player_count: int) -> Array:
	var per_player_cap := maxi(2, ceili(float(MAX_HONORS) / float(maxi(1, player_count))))
	var per_player := {}
	var result: Array = []
	var fun_count := 0
	for honor in candidates:
		if result.size() >= MAX_HONORS:
			break
		var id := str(honor["id"])
		var fun := bool(DEFS[id].get("fun", false))
		if fun and fun_count >= MAX_FUN_HONORS:
			continue
		var slot := int(honor["slot"])
		if id != "mvp":
			if int(per_player.get(slot, 0)) >= per_player_cap:
				continue
			per_player[slot] = int(per_player.get(slot, 0)) + 1
		if fun:
			fun_count += 1
		result.append(honor)
	return result

## Titel, Symbol, Farbe und Werte-Text (gleiche Form wie MatchHonors.describe).
static func describe(honor: Dictionary, d: HordeDirector) -> Dictionary:
	var id := str(honor.get("id", ""))
	var def: Dictionary = DEFS.get(id, {"title": id, "icon": "★", "color": Color.WHITE, "flavor": ""})
	var slot := int(honor.get("slot", 0))
	var value := float(honor.get("value", 0.0))
	var s: Dictionary = {}
	if d != null:
		s = d.slot_stats.get(slot, d.slot_stats.get(str(slot), {}))
	var detail := ""
	match id:
		"mvp":
			detail = "Jagdwert %d · %d Kills" % [int(round(value)), int(s.get("kills", 0))]
		"boss_kill":
			detail = "%d Boss%s erlegt" % [int(value), "" if int(value) == 1 else "e"]
		"boss":
			detail = "%d Schaden an Bossen" % int(value)
		"damage":
			detail = "%d Schaden" % int(value)
		"kills":
			detail = "%d Gegner erlegt" % int(value)
		"streak":
			detail = "%d Kills ohne zu fallen" % int(value)
		"giants":
			detail = "%d Riesen erlegt" % int(value)
		"survivor":
			detail = "%s am Stück überlebt" % HordeDefs.format_time(value)
		"collector":
			detail = "%d Erfahrung eingesammelt" % int(value)
		"medic":
			detail = "%d HP geheilt" % int(value)
		"ability":
			detail = "%d Fähigkeitsschaden" % int(value)
		"melee":
			detail = "%d Schaden mit %s" % [int(value), Global.get_melee_weapon_label(Global.get_melee_weapon(slot))]
		"wall":
			detail = "%d Schaden abgeblockt" % int(value)
		"eagles":
			detail = "%d Adler erlegt" % int(value)
		"glutton":
			detail = "%d Eicheln gefuttert" % int(value)
		"unlucky":
			detail = "%d× gefallen" % int(value)
		"sponge":
			detail = "%d Schaden eingesteckt" % int(value)
	return {
		"title": str(def["title"]),
		"icon": str(def["icon"]),
		"color": def["color"],
		"flavor": str(def.get("flavor", "")),
		"detail": detail,
		"fun": bool(def.get("fun", false)),
	}
