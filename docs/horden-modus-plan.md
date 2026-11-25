# Horden-Modus „Schweinehatz“ – grober Plan

Koop-Überlebensmodus in der Arena (Draufsicht). Alle Eber spielen zusammen
(allein oder bis zu 6, Bots als Mitspieler), es gibt kein PvP. Ziel: 10 Minuten
gegen immer größere Horden von Schweinejägern überleben und am Ende den
Endboss besiegen.

## Ablauf einer Runde

- Lobby → Modus **Horde (Koop)**. Spielart ist automatisch Arena, Spielerzahl 1–6.
- Große offene Karte „Wildnis“ (110 × 80 Kacheln) mit Felsen, Ruinen, Kisten und Hecken.
- Gegner kommen in Wellen vom Bildrand, die Dichte steigt mit der Zeit.
- Besiegte Gegner lassen **XP-Kristalle** fallen (blau/grün/rot je nach Wert).
  XP ist gemeinsam fürs Team, Kristalle fliegen in der Nähe zum Eber (Magnet).
- **Stufenaufstieg** → Spiel pausiert, jeder Eber wählt eine Karte aus dem
  normalen Draft (gleiche Karten, gleiche Ansicht).
- **Bosse** bei 3:00, 6:00 und 9:00: ein Held mit sehr viel Leben (skaliert mit
  Spielerzahl). Bei 10:00 kommt der Endboss. Bosse lassen eine Truhe fallen →
  sofort eine Bonus-Karte für alle.
- Wer fällt, steht nach 12 s wieder auf, solange ein Teamkollege lebt.
  Sind alle gleichzeitig tot, ist die Jagd verloren.
- Endbildschirm: überlebte Zeit, Stufe, Kills, pro Spieler Schaden und Kills.

## Gegner (alles, was Schweine jagt oder frisst)

| Gegner | Größe | Verhalten |
|---|---|---|
| Fuchs | klein | schnell, schwach, kommt in Rudeln |
| Wolf | mittel | Rudeljäger, umkreist und beißt |
| Alphawolf | groß | Elite-Wolf, heult und macht nahe Wölfe schneller |
| Steinadler | klein, fliegt | fliegt über Mauern, kreist und stößt herab |
| Krokodil | groß, flach | langsam, schnappt mit einem schnellen Ausfallsprung zu |
| Braunbär | sehr groß | langsamer Panzer, viel Leben, harter Prankenhieb |
| Metzger | mittel | wirft Hackbeile aus der Distanz |
| Jäger | mittel | hält Abstand und schießt mit der Flinte |

Dazu zufällige **Riesen** (jede Art, 1,6-fache Größe, 4-faches Leben, goldener
Schimmer, großer Kristall). Gegner skalieren über die Zeit mit Leben und Schaden.

## Bosse

Bosse sind Helden aus dem Kader (Ignis, Volt, Nova, Klinge, Bastion, …) als
riesiges Voxel-Schwein mit Klassen-Outfit und Boss-Lebensbalken oben.
Fernkampf-Helden schießen Fächer und gezielte Salven, Nahkämpfer stürmen auf
den nächsten Eber zu und schlagen mit einer Druckwelle auf.

## Technik

- Neuer Match-Modus `horde` in `Global` (Team 1 für alle, Arena erzwungen).
- `scripts/horde/`: `HordeDirector` (Host: Zeit, Wellen, XP, Stufen, Bosse,
  Wiederbelebung, Ende), `HordeEnemy` (leichter CharacterBody2D auf der
  Turm-Ebene: Kugeln, Explosionen, Nahkampf und Fähigkeiten treffen ihn ohne
  Sonderfälle), `HordeDefs` (Gegner-Tabelle, Kurven), `HordeHud`,
  `HordeVoxels` (Voxel-Modelle), `HordeBotController` (Bots als Mitspieler).
- Wegfindung: Fluss-Feld (BFS von den Ebern aus) über das Arena-Raster, alle
  0,4 s neu. Gegner weichen einander weich aus (Raster-Hash), keine Physik
  zwischen Gegnern.
- XP-Kristalle und Gegnergeschosse sind reine Daten im Director (kein Node pro Stück).
- Online: Host simuliert alles. Snapshot-Schlüssel `horde` mit Gegnern
  (kompakte Arrays), Kristallen, Geschossen, Zeit, XP, Stufe, Boss. Stufenaufstiege
  laufen über den vorhandenen Netzwerk-Draft.

## Erster Schuss (dieser PR)

Lobby-Modus, Karte, 8 Gegnerarten + Riesen, XP + Stufen mit Kartenwahl,
4 Bosse (3/6/9/10 min), Wiederbelebung, Bots als Mitspieler, HUD,
Endbildschirm, Online-Sync.

## Ideen für später

- **Schweinestall** als Basis in der Mitte, die mitverteidigt werden muss.
- **Trüffel** als Währung zwischen Läufen: dauerhafte kleine Boni (Meta-Fortschritt).
- **Ereignisse**: Treibjagd (Jäger-Linie zieht über die Karte), Wolfsnacht
  (dunkel, nur Lichtkegel), Schlachtfest (Metzger-Welle mit Fleischwolf-Boss).
- **Evolution von Karten** über Kombination, wie die vorhandenen Evolutionen,
  aber erst ab Stufe X.
- **Wiederbeleben per Hand**: Teamkollege stellt sich 3 s auf den Gefallenen.
- **Fallen und Futter** auf der Karte: Bärenfalle, Eicheln (Heilung), Schlammloch (Tempo).
- **Schwierigkeitsstufen** in der Lobby (Frischling / Keiler / Wildsau) und
  einstellbare Laufzeit.
- Weitere Gegner: Luchs (springt aus dem Gebüsch), Python (umschlingt und hält
  fest), Hyänenrudel, Löwe, Tiger, Geier (fressen Gefallene), Koch mit Bratpfanne.
- Bosse mit ihrem echten Helden-Kit (Fähigkeit, Dash, Ulti) statt Boss-Muster.

## Stand 2026-11-25: Gebiete, Treibjagd, Leistung

- **Gebiete:** Nach jedem besiegten Boss (außer dem Endboss) fliegen alle Kristalle und die Truhe per Magnet zu den Ebern, nach 4,5 s geht es auf die nächste Karte (`HordeDefs.STAGE_MAPS`): Wildnis → Dürresteppe → Treibjagd → Burgruinen. Karten werden in `ArenaMaps.HORDE_MAP_SPECS` aus festen Seeds erzeugt. Clients folgen über den Snapshot-Schlüssel `stg`.
- **Treibjagd:** lange Strecke (240 × 44). Eine Feuerwalze (`scroll_x`, Snapshot `sx`) schiebt von links nach Osten, wer dahinter steht, nimmt Schaden. Bots bleiben davor.
- **Level-Modifier:** pro Gebiet nach Lobby-Auswahl und -Rate, nur `HordeDefs.MODIFIERS` (Arena-Modifier ohne Sturmzone). `_horde_reapply_cards` legt die Modifier nach jedem Stufenaufstieg wieder drauf.
- **Powerups:** alle ~28 s ein Powerup in der Nähe eines Ebers, höchstens 4 gleichzeitig, nur aktive Powerups aus der Lobby.
- **Kein Sudden Death** im Horden-Modus (Timer wird nie gestartet, `_start_sudden_death` bricht ab).
- **Spawns:** `find_free_spot` legt jeden Gegner und Boss auf eine freie Stelle; steckt einer trotzdem in einer Mauer, holt `_grid_move` ihn heraus.
- **Leistung:** Messung im Container (2 Bots, 10 Minuten): kein Speicherleck, Knotenzahl folgt der Gegnerzahl. Kosten wachsen mit den Gegnern (45 am Anfang, 150/230 ab Minute 5–8). Optimiert: Fluss-Richtung je Zelle zwischengespeichert, Sichtlinie 0,2–0,3 s, Ausweichen jeden zweiten Frame, Gegner weit weg denken jeden dritten Frame, 3D-Modelle außerhalb des Bildes ausgeblendet, echte Gegner-Schatten nur bei Grafik Hoch. Ergebnis bei 150 Gegnern: Gegner-Skripte etwa 30 % günstiger, Draw Calls 373 → 87.
