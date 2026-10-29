"""Wertet das Runden-Protokoll von RoundStats (round_stats.jsonl) aus.

Pro Karte und Version (z. B. "heavy_bullets@v2") werden Siegquote, Kills,
Tode, Schadens-/Heilanteil, Nahkampfschaden und Pickrate berechnet und mit den anderen Karten
derselben Seltenheit verglichen. Karten, die deutlich besser abschneiden,
bekommen einen Vorschlag für die nächsthöhere Seltenheit. Zusätzlich gibt es
eine Tabelle pro Nahkampfwaffe und Version (z. B. "hammer@v2": Runden,
Siegquote, Nahkampfschaden pro Runde) und eine pro Held mit Helden- und
Fähigkeitsversion (z. B. "nova@v1/a2"). Ältere Zeilen ohne Versionsangabe
zählen als Version 1.

Dieselbe Rechnung zeigt das Spiel unter Optionen -> STATISTIK
(scripts/balance_report.gd). Änderungen bitte in beiden Dateien nachziehen.

Aufruf:
    python tools/analyze_round_stats.py [pfad/zu/round_stats.jsonl]
        [--min-rounds 20] [--humans-only] [--csv balance.csv]
"""

import argparse
import csv
import json
import os
import sys
from collections import defaultdict

RARITY_ORDER = ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
PROMOTION_GAP = 0.10


def default_log_path():
    appdata = os.environ.get("APPDATA", os.path.expanduser("~"))
    # Seit der Umbenennung liegt das Protokoll unter "Lötkolbeneber"; ältere
    # Installationen haben nur den alten Ordner "BattleBalls".
    for folder in ("Lötkolbeneber", "BattleBalls"):
        path = os.path.join(appdata, "Godot", "app_userdata", folder, "round_stats.jsonl")
        if os.path.exists(path):
            return path
    return os.path.join(appdata, "Godot", "app_userdata", "Lötkolbeneber", "round_stats.jsonl")


def smoothed_rate(wins, rounds):
    # Laplace-Glättung, damit wenige Runden keine 0 % / 100 % erzeugen.
    return (wins + 2) / (rounds + 4)


def new_card_entry():
    return {
        "rarity": "",
        "rounds": 0,
        "wins": 0,
        "kills": 0.0,
        "deaths": 0.0,
        "damage_share": 0.0,
        "healing_share": 0.0,
        "melee_damage": 0.0,
        "fingerprints": set(),
        "offers": 0,
        "picks": 0,
    }


def read_lines(path):
    with open(path, encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                print(f"Warnung: Zeile {line_number} ist kein gültiges JSON und wird übersprungen.", file=sys.stderr)


def new_weapon_entry():
    return {"rounds": 0, "wins": 0, "melee_damage": 0.0, "melee_share": 0.0, "kills": 0.0, "fingerprints": set()}


def new_hero_entry():
    return {
        "rounds": 0,
        "wins": 0,
        "kills": 0.0,
        "deaths": 0.0,
        "damage_share": 0.0,
        "healing_share": 0.0,
        "fingerprints": set(),
        # Fähigkeitsschaden gibt es erst ab Schema 3; nur diese Runden zählen.
        "ability_rounds": 0,
        "ability_damage": 0.0,
        "ability_share": 0.0,
    }


def collect(path, humans_only):
    cards = defaultdict(new_card_entry)
    weapons = defaultdict(new_weapon_entry)
    heroes = defaultdict(new_hero_entry)
    round_count = 0
    draft_count = 0
    for data in read_lines(path):
        kind = data.get("type")
        if kind == "round":
            round_count += 1
            for player in data.get("players", []):
                if humans_only and player.get("kind") == "bot":
                    continue
                stats = player.get("stats", {})
                won = bool(player.get("won_round", False))
                # Ältere Protokolle kennen noch keine Nahkampfwaffe.
                weapon_id = player.get("melee_weapon")
                if weapon_id:
                    weapon = weapons[f"{weapon_id}@v{int(player.get('melee_version', 1))}"]
                    if player.get("melee_fingerprint"):
                        weapon["fingerprints"].add(str(player["melee_fingerprint"]))
                    weapon["rounds"] += 1
                    weapon["wins"] += 1 if won else 0
                    weapon["melee_damage"] += float(stats.get("melee_damage", 0.0))
                    weapon["melee_share"] += float(stats.get("melee_share", 0.0))
                    weapon["kills"] += float(stats.get("kills", 0.0))
                hero_id = player.get("hero_id")
                if hero_id:
                    hero = heroes[
                        f"{hero_id}@v{int(player.get('hero_version', 1))}/a{int(player.get('ability_version', 1))}"
                    ]
                    hero["rounds"] += 1
                    hero["wins"] += 1 if won else 0
                    hero["kills"] += float(stats.get("kills", 0.0))
                    hero["deaths"] += float(stats.get("deaths", 0.0))
                    hero["damage_share"] += float(stats.get("damage_share", 0.0))
                    hero["healing_share"] += float(stats.get("healing_share", 0.0))
                    if "ability_damage" in stats:
                        hero["ability_rounds"] += 1
                        hero["ability_damage"] += float(stats.get("ability_damage", 0.0))
                        hero["ability_share"] += float(stats.get("ability_share", 0.0))
                    if player.get("hero_fingerprint"):
                        hero["fingerprints"].add(
                            f"{player['hero_fingerprint']}/{player.get('ability_fingerprint', '')}"
                        )
                for card in player.get("cards", []):
                    key = f"{card.get('id', '?')}@v{int(card.get('version', 1))}"
                    entry = cards[key]
                    entry["rarity"] = card.get("rarity", entry["rarity"])
                    entry["rounds"] += 1
                    entry["wins"] += 1 if won else 0
                    entry["kills"] += float(stats.get("kills", 0.0))
                    entry["deaths"] += float(stats.get("deaths", 0.0))
                    entry["damage_share"] += float(stats.get("damage_share", 0.0))
                    entry["healing_share"] += float(stats.get("healing_share", 0.0))
                    entry["melee_damage"] += float(stats.get("melee_damage", 0.0))
                    fingerprint = str(card.get("fingerprint", ""))
                    if fingerprint:
                        entry["fingerprints"].add(fingerprint)
        elif kind == "draft":
            draft_count += 1
            if humans_only and data.get("kind") == "bot":
                continue
            for card in data.get("offered", []):
                key = f"{card.get('id', '?')}@v{int(card.get('version', 1))}"
                entry = cards[key]
                if not entry["rarity"]:
                    entry["rarity"] = card.get("rarity", "")
                entry["offers"] += 1
                if card.get("picked"):
                    entry["picks"] += 1
                fingerprint = str(card.get("fingerprint", ""))
                if fingerprint:
                    entry["fingerprints"].add(fingerprint)
    return cards, weapons, heroes, round_count, draft_count


def analyze(cards, min_rounds):
    rarity_totals = defaultdict(lambda: {"wins": 0, "rounds": 0})
    for entry in cards.values():
        totals = rarity_totals[entry["rarity"]]
        totals["wins"] += entry["wins"]
        totals["rounds"] += entry["rounds"]

    rows = []
    for key, entry in cards.items():
        rounds = entry["rounds"]
        totals = rarity_totals[entry["rarity"]]
        peer_wins = totals["wins"] - entry["wins"]
        peer_rounds = totals["rounds"] - rounds
        win_rate = smoothed_rate(entry["wins"], rounds)
        if peer_rounds > 0:
            peer_rate = smoothed_rate(peer_wins, peer_rounds)
            gap = win_rate - peer_rate
        else:
            peer_rate = 0.0
            gap = 0.0
        suggestion = ""
        rarity = entry["rarity"]
        if (
            rounds >= min_rounds
            and peer_rounds >= min_rounds
            and gap >= PROMOTION_GAP
            and rarity in RARITY_ORDER
            and rarity != "Legendary"
        ):
            suggestion = "-> " + RARITY_ORDER[RARITY_ORDER.index(rarity) + 1]
        per_round = rounds if rounds > 0 else 1
        rows.append({
            "card": key,
            "rarity": rarity,
            "rounds": rounds,
            "wins": entry["wins"],
            "win_rate": round(win_rate, 3),
            "peer_rate": round(peer_rate, 3),
            "gap": round(gap, 3),
            "kills_per_round": round(entry["kills"] / per_round, 3),
            "deaths_per_round": round(entry["deaths"] / per_round, 3),
            "damage_share": round(entry["damage_share"] / per_round, 3),
            "healing_share": round(entry["healing_share"] / per_round, 3),
            "melee_per_round": round(entry["melee_damage"] / per_round, 1),
            "offers": entry["offers"],
            "picks": entry["picks"],
            "pick_rate": round(entry["picks"] / entry["offers"], 3) if entry["offers"] else 0.0,
            "fingerprints": len(entry["fingerprints"]),
            "suggestion": suggestion,
        })
    rows.sort(key=lambda row: (row["suggestion"] == "", -row["gap"], row["card"]))
    return rows


COLUMNS = [
    ("card", "Karte"),
    ("rarity", "Seltenheit"),
    ("rounds", "Runden"),
    ("wins", "Siege"),
    ("win_rate", "Siegq."),
    ("peer_rate", "Vergl."),
    ("gap", "Diff"),
    ("kills_per_round", "Kills/R"),
    ("deaths_per_round", "Tode/R"),
    ("damage_share", "Schaden%"),
    ("healing_share", "Heilung%"),
    ("melee_per_round", "Nahk./R"),
    ("offers", "Angeb."),
    ("picks", "Picks"),
    ("pick_rate", "Pickq."),
    ("suggestion", "Vorschlag"),
]


def print_table(rows):
    widths = []
    for key, header in COLUMNS:
        width = len(header)
        for row in rows:
            width = max(width, len(str(row[key])))
        widths.append(width)
    print("  ".join(header.ljust(width) for (_, header), width in zip(COLUMNS, widths)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        cells = []
        for (key, _), width in zip(COLUMNS, widths):
            value = row[key]
            text = str(value)
            cells.append(text.rjust(width) if isinstance(value, (int, float)) else text.ljust(width))
        print("  ".join(cells))


def print_weapons(weapons):
    if not weapons:
        print("Keine Nahkampf-Daten vorhanden (ältere Protokolle).")
        return
    print("Nahkampfwaffen:")
    header = f"{'Waffe':<12}  {'Runden':>6}  {'Siegq.':>6}  {'Nahk./R':>8}  {'Nahk.%':>6}  {'Kills/R':>7}"
    print(header)
    print("-" * len(header))
    for weapon_id, entry in sorted(weapons.items()):
        rounds = entry["rounds"] or 1
        print(
            f"{weapon_id:<12}  {entry['rounds']:>6}  {smoothed_rate(entry['wins'], entry['rounds']):>6.0%}  "
            f"{entry['melee_damage'] / rounds:>8.1f}  {entry['melee_share'] / rounds:>6.0%}  {entry['kills'] / rounds:>7.2f}"
        )


def print_heroes(heroes):
    if not heroes:
        print("Keine Helden-Daten vorhanden.")
        return
    print("Helden (vX = Basiswerte/Passiv, aX = Fähigkeit):")
    header = (
        f"{'Held':<20}  {'Runden':>6}  {'Siegq.':>6}  {'Kills/R':>7}  {'Tode/R':>6}  "
        f"{'Schaden%':>8}  {'Heilung%':>8}  {'Fähigk./R':>9}  {'Fähigk.%':>8}"
    )
    print(header)
    print("-" * len(header))
    for hero_id, entry in sorted(heroes.items()):
        rounds = entry["rounds"] or 1
        print(
            f"{hero_id:<20}  {entry['rounds']:>6}  {smoothed_rate(entry['wins'], entry['rounds']):>6.0%}  "
            f"{entry['kills'] / rounds:>7.2f}  {entry['deaths'] / rounds:>6.2f}  "
            f"{entry['damage_share'] / rounds:>8.0%}  {entry['healing_share'] / rounds:>8.0%}  "
            + (
                f"{entry['ability_damage'] / entry['ability_rounds']:>9.1f}  {entry['ability_share'] / entry['ability_rounds']:>8.0%}"
                if entry["ability_rounds"]
                else f"{'-':>9}  {'-':>8}"
            )
        )


def write_csv(rows, path):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()) if rows else [c for c, _ in COLUMNS], delimiter=";")
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description="Balance-Auswertung des Runden-Protokolls (round_stats.jsonl).")
    parser.add_argument("path", nargs="?", default=default_log_path(), help="Pfad zur round_stats.jsonl")
    parser.add_argument("--min-rounds", type=int, default=20, help="Mindestanzahl Runden für einen Aufstiegsvorschlag (Standard: 20)")
    parser.add_argument("--humans-only", action="store_true", help="Bots ignorieren")
    parser.add_argument("--csv", help="Ergebnis zusätzlich als CSV (Trennzeichen ';') speichern")
    args = parser.parse_args()

    if not os.path.isfile(args.path):
        print(f"Datei nicht gefunden: {args.path}", file=sys.stderr)
        return 1

    cards, weapons, heroes, round_count, draft_count = collect(args.path, args.humans_only)
    print(f"Datei: {args.path}")
    print(f"Runden: {round_count}, Drafts: {draft_count}, Karten(-Versionen): {len(cards)}")
    if args.humans_only:
        print("Nur menschliche Spieler werden ausgewertet.")
    print()

    rows = analyze(cards, args.min_rounds)
    if not rows:
        print("Keine Kartendaten vorhanden.")
    else:
        print_table(rows)

    print()
    print_weapons(weapons)
    print()
    print_heroes(heroes)

    suggestions = [row for row in rows if row["suggestion"]]
    print()
    if suggestions:
        print(f"{len(suggestions)} Aufstiegsvorschläge (mind. {args.min_rounds} Runden, Abstand >= {PROMOTION_GAP:.0%}):")
        for row in suggestions:
            print(f"  {row['card']}: {row['rarity']} {row['suggestion']} (Siegquote {row['win_rate']:.0%} vs. {row['peer_rate']:.0%})")
    else:
        print(f"Keine Aufstiegsvorschläge (mind. {args.min_rounds} Runden, Abstand >= {PROMOTION_GAP:.0%}).")

    changed = [row["card"] for row in rows if row["fingerprints"] > 1]
    for card in changed:
        print(f"Warnung: {card} – Werte ohne neue Version geändert (mehrere Fingerabdrücke).")
    for key, entry in sorted(list(weapons.items()) + list(heroes.items())):
        if len(entry["fingerprints"]) > 1:
            print(f"Warnung: {key} – Werte ohne neue Version geändert (mehrere Fingerabdrücke).")

    if args.csv:
        write_csv(rows, args.csv)
        print(f"CSV gespeichert: {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
