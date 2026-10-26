# Tilesets und Art Direction

Die Battle-Balls-Arenen verwenden seit der Theme-Umstellung vier
nicht-pixelige Tileset-Familien. Layout und Material sind getrennt: Die
`MAP_PROFILES` in `scripts/level_generator.gd` bestimmen weiterhin nur
Plattformen, Objekte und Mengen. Das jeweilige Theme liefert Materialien,
Deko, Portal-Farben, Hintergrund und additive Spezialflächen.

Alle finalen Kacheln sind **36 × 36 px**, mit 4× Supersampling gerendert und
mit linearem Filter plus Mipmaps importiert. Im Spiel werden sie über
`TILE_SIZE / texture.get_width()` dynamisch skaliert.

## Umgesetzte Themes

| Theme | Ordner | Einsatz | Additive Mechanik |
| --- | --- | --- | --- |
| Storybook | `assets/tilesets/storybook/` | Grasarena, Wüstenruine, Weite Wiese, Kistenfestung | Ranken-Brücken |
| Neon | `assets/tilesets/neon/` | Neonfabrik | Teleporter, Speed-Booster |
| Wool | `assets/tilesets/wool/` | Wolkeninsel | Flauschiger Trampolinboden |
| Frost | `assets/tilesets/frost/` | Eisgrotte | Glatteis, Tiefschnee |

Jedes Theme enthält Boden-, Füll-, Plattform-, Destructible-, Deko- und
Portal-Materialien. Frost ergänzt Eis- und Schnee-Overlays, Wool die
Trampolin-Overlays und Storybook die Ranken-Texturen.

### Hintergründe

Die Hintergründe werden nicht als PNG importiert, sondern prozedural von
`scripts/level/theme_backdrop.gd` gezeichnet:

- Storybook: Wald, Wüste, Wiese und Abenddämmerung mit Bäumen, Hügeln,
  Sonne/Mond und Partikeln.
- Neon: Grid, Leuchtrahmen, Ringe und industrielle Rohre.
- Wool: Wolken, weiche Hügel und Pastelllicht.
- Frost: Höhle, Eiszapfen, Polarlicht und Bodennebel.

## Mechaniken

- **Glatteis:** vorhandene Eisflächen verändern die Reibung; im Frost-Theme
  wird das Overlay aus dem Theme geladen.
- **Tiefschnee:** `deep_snow.gd` bremst Spieler auf `0.52` der normalen
  Bodengeschwindigkeit.
- **Trampolinboden:** `trampoline_ground.gd` schleudert landende Spieler mit
  `-690` nach oben und stellt ihre Sprünge wieder her.
- **Speed-Booster:** `speed_booster.gd` beschleunigt für `0.26 s` auf `680`
  in Pfeilrichtung.
- **Teleporter:** die vorhandenen Warp-Pipes übernehmen die Portal-Farben des
  Themes.
- **Ranken:** Storybook-Ranken nutzen die bestehenden Strong-/Weak-Vine-
  Bridges und bleiben zerstörbar bzw. regenerierbar.

Die Mechaniken sind additiv: Sie liegen als Sensoren auf bereits vorhandenen
Standflächen und verändern keine Plattformpositionen. Spawns und bewegliche
Objekte meiden die belegten Felder.

## Generierung und Prüfung

Die finalen Tilesets werden mit Pillow erzeugt:

```powershell
python tools/generate_tilesets.py
python tools/generate_tilesets.py --preview
```

`--preview` legt zusätzlich einen Kontaktbogen im Temp-Verzeichnis ab.

Nach Änderungen an den PNGs importiert Godot die Assets neu:

```powershell
& "C:\Users\joche\Desktop\Godot_v4.6-stable_win64_console.exe" --headless --path . --editor --quit
```

Der Headless-Integrationstest prüft Theme-Zuordnung, geladene Texturen,
Hintergründe, Mechanik-Platzierung und Player-Zustände:

```powershell
& "C:\Users\joche\Desktop\Godot_v4.6-stable_win64_console.exe" --headless --path . scenes\test_scene.tscn
```

## Gestaltungsregeln

1. **Eine Materialfamilie pro Map.** Boden, Plattformen und Destructibles
   bleiben innerhalb eines Themes konsistent.
2. **Maximal 2–3 Varianten pro Material.** Variation entsteht über Deko,
   Hintergrund und Licht, nicht über fremde Kacheln.
3. **Klare Top-/Side-/Fill-Sprache.** Oben Lichtkante, Seiten dunkler,
   Füllung ruhig.
4. **Kontur nur, wo sie hilft.** Storybook arbeitet weicher, Neon und Frost
   kontrastreicher.
5. **Hintergrund trennt sich vom Gameplay.** Die Arena bleibt auch im Getümmel
   silhouettenklar.
6. **Akzentfarbe pro Map.** Basismaterialien bleiben gleich; Licht, Portal und
   Hintergrund variieren.

## Konzept-Sheets

Die Dateien `00_overview.png` bis `04_paper_cutout.png` dokumentieren die
ursprüngliche Art-Direction-Recherche. Sie sind historische Mockups und kein
Bestandteil der finalen Spiel-Assets. `generate_concepts.py` kann sie neu
erzeugen. Der Ordner enthält eine `.gdignore`, damit Godot die Konzept-PNGs
nicht importiert.
