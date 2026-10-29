# Audio-Credits & Lizenzen

Alle Soundeffekte in `assets/audio/sfx/` stammen von **Kenney (www.kenney.nl)** und
stehen unter **CC0 1.0 (Public Domain)**. Sie dürfen frei verwendet, verändert und
verbreitet werden, auch kommerziell. Eine Namensnennung ist nicht nötig, wir
nennen Kenney trotzdem gern. Lizenztext: https://creativecommons.org/publicdomain/zero/1.0/

## Quellen

| Paket | Autor | Lizenz | Bezogen über |
| :--- | :--- | :--- | :--- |
| Retro-Soundeffekte (Teilmenge, „sounds“) | Kenney | CC0 1.0 | Python-Paket `arcade` 3.3.2 (PyPI), Ordner `arcade/resources/assets/sounds/`; beiliegende `License.txt`: „Everything in this package is licensed CC0“, `readme.txt`: „These assets are a subset of what is available from Kenney.nl“ |
| UI Audio | Kenney | CC0 1.0 | https://github.com/Calinou/kenney-ui-audio (Original: https://kenney.nl/assets/ui-audio), beiliegende `LICENSE.txt`: „License (Creative Commons Zero, CC0)“ |

## Bearbeitung

Alle Dateien wurden einheitlich nachbearbeitet, damit sie wie ein Set klingen:
Mono 44,1 kHz, Stille getrimmt, Hochpass 90 Hz, sanfter Tiefpass (5–8 kHz),
ein kleiner gemeinsamer Raumhall (außer UI-Klicks), RMS-Lautheitsangleich und
Spitzenbegrenzung. Einige Sounds sind tonhöhenverschoben, gekürzt oder aus zwei
Quellen gemischt (siehe Tabelle).

## Dateien

| Datei | Quelle(n) | Bearbeitung |
| :--- | :--- | :--- |
| shoot_1.wav | Retro `laser1.wav` | gekürzt |
| shoot_2.wav | Retro `laser3.wav` | +2 Halbtöne, gekürzt |
| shoot_3.wav | Retro `laser5.wav` | +1 Halbton, gekürzt |
| hit_1…hit_4.wav | Retro `hit1`–`hit4.wav` | – |
| bounce_1.wav / bounce_2.wav | Retro `error5.wav` | höher gepitcht |
| explosion.wav | Retro `explosion2.wav` | – |
| explosion_big.wav | Retro `explosion1.wav` + `explosion2.wav` | gemischt, Schicht tiefer |
| jump_1.wav / jump_2.wav | Retro `jump3.wav` / `jump4.wav` | – |
| jump_air.wav | Retro `jump3.wav` | +4 Halbtöne |
| spring.wav | Retro `jump1.wav` | tiefer |
| dash.wav | Retro `fall3.wav` | höher, gekürzt |
| slash.wav | Retro `fall1.wav` | höher, gekürzt |
| shield.wav | Retro `phaseJump1.wav` | leicht höher |
| teleport.wav | Retro `phaseJump1.wav` + `fall2.wav` | gemischt, höher |
| poison.wav | Retro `hurt2.wav` | tiefer |
| heal.wav | Retro `upgrade1.wav` | – |
| death.wav | Retro `hit2.wav` + `lose4.wav` | gemischt |
| coin_1.wav / coin_2.wav | Retro `coin1.wav` / `coin3.wav` | – |
| mystery.wav | Retro `secret2.wav` | – |
| warning.wav | Retro `error2.wav` | tiefer |
| fuse.wav | Retro `error1.wav` | höher |
| laser_charge.wav | Retro `laser4.wav` | tiefer |
| laser_blast.wav | Retro `laser4.wav` + `explosion1.wav` | gemischt, tiefer |
| countdown.wav | Retro `coin5.wav` | tiefer |
| countdown_go.wav | Retro `coin4.wav` | tiefer |
| round_end.wav | Retro `secret4.wav` | – |
| sudden_death.wav | Retro `gameover2.wav` | – |
| draft_start.wav | Retro `upgrade3.wav` | tiefer |
| card_pick.wav | Retro `upgrade2.wav` | – |
| match_win.wav | Retro `upgrade5.wav` + `coin2.wav` | gemischt |
| ui_confirm.wav | Retro `coin2.wav` | tiefer |
| ui_click.wav | UI Audio `click2.wav` | – |
| reload.wav | UI Audio `click4.wav` | – |
| reload_done.wav | UI Audio `rollover2.wav` | höher |

## Alte Dateien

Die früheren Sounds in `assets/sfx/` (überwiegend Kenney Sci-Fi, Impact und
Interface Sounds) werden vom Spiel nicht mehr geladen und können gelöscht werden.

## Hintergrundmusik

Die vier Musik-Loops in `assets/audio/music/` wurden für dieses Spiel neu
komponiert und vollständig synthetisiert (keine fremden Samples oder Melodien),
mit `tools/compose_music.py`. Sie gehören zum Projekt und unterliegen keinen
Lizenzauflagen Dritter.

| Datei | Tileset | Stimmung |
| :--- | :--- | :--- |
| music_storybook.ogg | Storybook | F-Dur, 84 BPM, verspielte Flöten-Melodie über Zupf-Arpeggio |
| music_frost.ogg | Frost | D-dorisch, 70 BPM, Glocken-Arpeggios und Flächen, ohne Schlagzeug |
| music_neon.ogg | Neon | a-Moll, 96 BPM, weicher Synthwave mit Pulsbass |
| music_wool.ogg | Wool | G-Pentatonik, 74 BPM, gemütliche Spieluhr |


## Alternative Soundpakete (Test, Oktober 2026)

Zum Vergleichen gibt es drei weitere, weniger nach 8-Bit klingende Effekt-Sets in
`assets/audio/packs/<paket>/`. Umschalten im Spiel unter **Optionen → Audio →
Soundpaket**; die Wahl gilt nur auf dem eigenen PC. Alle Quellen stehen unter
**CC0 1.0**. Gebaut mit `tools/build_sound_packs.py` (gleiche Kette wie oben:
Mono, Hochpass 90 Hz, Tiefpass 11–12 kHz, kleiner Raum außer UI, Lautheit an die
gleichnamige Retro-Datei angeglichen).

| Paket | Quellen | Bezogen über |
| :--- | :--- | :--- |
| Kenney Impact Sounds, Sci-Fi Sounds, Interface Sounds, RPG Audio, Casino Audio | Kenney | kenney.nl/assets/…, beiliegende `License.txt`: „License: (Creative Commons Zero, CC0)“ |
| 100 CC0 SFX, 100 CC0 SFX #2, 75 CC0 breaking/falling/hit SFX, 50 CC0 Sci-Fi SFX, 40 CC0 water/splash/slime SFX, 25 CC0 bang/firework SFX | rubberduck | opengameart.org/content/… (Lizenz auf der Seite: CC0) |

### Handgemacht (Foley) (`foley`)

| Datei | Quelle(n) |
| :--- | :--- |
| shoot_1.wav | Kenney Interface Sounds `pluck_001.ogg` (+5 HT) |
| shoot_2.wav | Kenney Interface Sounds `pluck_002.ogg` (+5 HT) |
| shoot_3.wav | Kenney Interface Sounds `pluck_001.ogg` (+7 HT) |
| hit_1.wav | Kenney Impact Sounds `impactPunch_medium_000.ogg` |
| hit_2.wav | Kenney Impact Sounds `impactPunch_medium_001.ogg` |
| hit_3.wav | Kenney Impact Sounds `impactPunch_medium_002.ogg` |
| hit_4.wav | Kenney Impact Sounds `impactPunch_medium_003.ogg` |
| bounce_1.wav | Kenney Impact Sounds `impactPlate_light_000.ogg` (+2 HT) |
| bounce_2.wav | Kenney Impact Sounds `impactPlate_light_001.ogg` (+2 HT) |
| explosion.wav | Kenney Sci-Fi Sounds `explosionCrunch_000.ogg` (-2 HT) + Kenney Impact Sounds `impactWood_heavy_000.ogg` (-3 HT) |
| explosion_big.wav | Kenney Sci-Fi Sounds `lowFrequency_explosion_000.ogg` + Kenney Sci-Fi Sounds `explosionCrunch_002.ogg` (-3 HT) |
| shield.wav | Kenney Impact Sounds `impactMetal_medium_000.ogg` |
| poison.wav | Kenney Sci-Fi Sounds `slime_000.ogg` |
| death.wav | Kenney Impact Sounds `impactPunch_heavy_000.ogg` (-2 HT) + Kenney Impact Sounds `impactSoft_heavy_000.ogg` (-4 HT) |
| jump_1.wav | Kenney RPG Audio `cloth1.ogg` (+2 HT) |
| jump_2.wav | Kenney RPG Audio `cloth3.ogg` (+2 HT) |
| jump_air.wav | Kenney RPG Audio `cloth2.ogg` (+5 HT) |
| spring.wav | Kenney Impact Sounds `impactTin_medium_000.ogg` (-2 HT) |
| dash.wav | Kenney RPG Audio `cloth4.ogg` (+3 HT) |
| slash.wav | Kenney RPG Audio `knifeSlice.ogg` |
| teleport.wav | Kenney Sci-Fi Sounds `forceField_001.ogg` (+3 HT) |
| heal.wav | Kenney Interface Sounds `glass_003.ogg` |
| reload.wav | Kenney RPG Audio `metalClick.ogg` |
| reload_done.wav | Kenney RPG Audio `metalLatch.ogg` |
| coin_1.wav | Kenney Casino Audio `chips-collide-1.ogg` |
| coin_2.wav | Kenney Casino Audio `chips-collide-3.ogg` |
| mystery.wav | Kenney Interface Sounds `question_002.ogg` + Kenney Impact Sounds `impactWood_medium_000.ogg` |
| warning.wav | Kenney Interface Sounds `error_006.ogg` |
| fuse.wav | Kenney Interface Sounds `scratch_001.ogg` |
| laser_charge.wav | Kenney Sci-Fi Sounds `forceField_000.ogg` (-5 HT) |
| laser_blast.wav | Kenney Sci-Fi Sounds `laserLarge_000.ogg` (-3 HT) + Kenney Sci-Fi Sounds `lowFrequency_explosion_001.ogg` |
| countdown.wav | Kenney Impact Sounds `impactBell_heavy_001.ogg` (+5 HT) |
| countdown_go.wav | Kenney Impact Sounds `impactBell_heavy_000.ogg` (+7 HT) + Kenney Interface Sounds `confirmation_003.ogg` |
| round_end.wav | Kenney Impact Sounds `impactBell_heavy_002.ogg` |
| sudden_death.wav | Kenney Impact Sounds `impactBell_heavy_003.ogg` (-7 HT) + Kenney Sci-Fi Sounds `lowFrequency_explosion_001.ogg` (-3 HT) |
| draft_start.wav | Kenney Casino Audio `card-shuffle.ogg` |
| card_pick.wav | Kenney Casino Audio `card-place-1.ogg` |
| match_win.wav | Kenney Interface Sounds `confirmation_004.ogg` + Kenney Impact Sounds `impactBell_heavy_004.ogg` (+5 HT) |
| ui_click.wav | Kenney Interface Sounds `click_002.ogg` |
| ui_confirm.wav | Kenney Interface Sounds `confirmation_001.ogg` |

### Modernes Sci-Fi (`scifi`)

| Datei | Quelle(n) |
| :--- | :--- |
| shoot_1.wav | Kenney Sci-Fi Sounds `laserSmall_000.ogg` |
| shoot_2.wav | Kenney Sci-Fi Sounds `laserSmall_001.ogg` |
| shoot_3.wav | Kenney Sci-Fi Sounds `laserSmall_002.ogg` |
| hit_1.wav | Kenney Sci-Fi Sounds `impactMetal_000.ogg` |
| hit_2.wav | Kenney Sci-Fi Sounds `impactMetal_001.ogg` |
| hit_3.wav | Kenney Sci-Fi Sounds `impactMetal_002.ogg` |
| hit_4.wav | Kenney Sci-Fi Sounds `impactMetal_003.ogg` |
| bounce_1.wav | Kenney Sci-Fi Sounds `forceField_002.ogg` (+4 HT) |
| bounce_2.wav | Kenney Sci-Fi Sounds `forceField_003.ogg` (+4 HT) |
| explosion.wav | Kenney Sci-Fi Sounds `explosionCrunch_001.ogg` |
| explosion_big.wav | Kenney Sci-Fi Sounds `explosionCrunch_003.ogg` (-2 HT) + Kenney Sci-Fi Sounds `lowFrequency_explosion_000.ogg` |
| shield.wav | Kenney Sci-Fi Sounds `forceField_000.ogg` |
| poison.wav | Kenney Sci-Fi Sounds `slime_001.ogg` |
| death.wav | Kenney Sci-Fi Sounds `explosionCrunch_004.ogg` (-3 HT) + Kenney Interface Sounds `glitch_002.ogg` |
| jump_1.wav | Kenney Sci-Fi Sounds `thrusterFire_000.ogg` (+3 HT) |
| jump_2.wav | Kenney Sci-Fi Sounds `thrusterFire_001.ogg` (+3 HT) |
| jump_air.wav | Kenney Sci-Fi Sounds `thrusterFire_002.ogg` (+6 HT) |
| spring.wav | Kenney Interface Sounds `maximize_004.ogg` |
| dash.wav | Kenney Sci-Fi Sounds `thrusterFire_003.ogg` (+4 HT) |
| slash.wav | Kenney Sci-Fi Sounds `laserSmall_004.ogg` (-4 HT) |
| teleport.wav | Kenney Interface Sounds `maximize_008.ogg` + Kenney Sci-Fi Sounds `forceField_001.ogg` (+5 HT) |
| heal.wav | Kenney Interface Sounds `confirmation_002.ogg` |
| reload.wav | Kenney Interface Sounds `switch_002.ogg` |
| reload_done.wav | Kenney Interface Sounds `toggle_002.ogg` |
| coin_1.wav | Kenney Interface Sounds `select_006.ogg` |
| coin_2.wav | Kenney Interface Sounds `select_007.ogg` |
| mystery.wav | Kenney Interface Sounds `question_003.ogg` |
| warning.wav | Kenney Interface Sounds `error_005.ogg` |
| fuse.wav | Kenney Sci-Fi Sounds `computerNoise_001.ogg` (+4 HT) |
| laser_charge.wav | Kenney Sci-Fi Sounds `forceField_004.ogg` (-3 HT) |
| laser_blast.wav | Kenney Sci-Fi Sounds `laserLarge_003.ogg` (-2 HT) + Kenney Sci-Fi Sounds `lowFrequency_explosion_001.ogg` |
| countdown.wav | Kenney Interface Sounds `select_001.ogg` |
| countdown_go.wav | Kenney Interface Sounds `confirmation_004.ogg` |
| round_end.wav | Kenney Interface Sounds `bong_001.ogg` |
| sudden_death.wav | Kenney Sci-Fi Sounds `spaceEngineLow_000.ogg` + Kenney Interface Sounds `error_008.ogg` (-5 HT) |
| draft_start.wav | Kenney Interface Sounds `open_002.ogg` |
| card_pick.wav | Kenney Interface Sounds `select_003.ogg` |
| match_win.wav | Kenney Interface Sounds `maximize_005.ogg` + Kenney Interface Sounds `confirmation_003.ogg` |
| ui_click.wav | Kenney Interface Sounds `click_004.ogg` |
| ui_confirm.wav | Kenney Interface Sounds `confirmation_001.ogg` |

### Kräftig & echt (`natur`)

| Datei | Quelle(n) |
| :--- | :--- |
| shoot_1.wav | OGA 25 CC0 bang/firework `shot_01.ogg` |
| shoot_2.wav | OGA 25 CC0 bang/firework `shot_02.ogg` |
| shoot_3.wav | OGA 25 CC0 bang/firework `shot_03.ogg` |
| hit_1.wav | OGA 75 CC0 breaking/falling/hit `bfh1_hit_01.ogg` |
| hit_2.wav | OGA 75 CC0 breaking/falling/hit `bfh1_hit_03.ogg` |
| hit_3.wav | OGA 75 CC0 breaking/falling/hit `bfh1_hit_06.ogg` |
| hit_4.wav | OGA 75 CC0 breaking/falling/hit `bfh1_hit_08.ogg` |
| bounce_1.wav | OGA 100 CC0 SFX `spring_04.ogg` |
| bounce_2.wav | OGA 100 CC0 SFX `spring_06.ogg` |
| explosion.wav | OGA 25 CC0 bang/firework `cannon_02.ogg` |
| explosion_big.wav | OGA 25 CC0 bang/firework `bang_03.ogg` + OGA 25 CC0 bang/firework `fw_06.ogg` (-3 HT) |
| shield.wav | OGA 100 CC0 SFX #2 `sfx100v2_metal_hit_01.ogg` |
| poison.wav | OGA 40 CC0 water/splash/slime `slime_02.ogg` |
| death.wav | OGA 75 CC0 breaking/falling/hit `bfh1_hit_02.ogg` + OGA 40 CC0 water/splash/slime `slime_03.ogg` (-3 HT) |
| jump_1.wav | OGA 100 CC0 SFX #2 `sfx100v2_air_03.ogg` |
| jump_2.wav | OGA 100 CC0 SFX #2 `sfx100v2_air_03.ogg` (+2 HT) |
| jump_air.wav | OGA 100 CC0 SFX #2 `sfx100v2_air_03.ogg` (+5 HT) |
| spring.wav | OGA 100 CC0 SFX `spring_01.ogg` |
| dash.wav | OGA 100 CC0 SFX #2 `sfx100v2_air_02.ogg` |
| slash.wav | OGA 100 CC0 SFX #2 `sfx100v2_air_01.ogg` (+3 HT) |
| teleport.wav | OGA 50 CC0 Sci-Fi SFX `teleport_01.ogg` |
| heal.wav | OGA 100 CC0 SFX `bell_01.ogg` |
| reload.wav | OGA 100 CC0 SFX `switch_01.ogg` |
| reload_done.wav | OGA 100 CC0 SFX `key_open_01.ogg` |
| coin_1.wav | OGA 100 CC0 SFX `bell_02.ogg` |
| coin_2.wav | OGA 100 CC0 SFX #2 `sfx100v2_items_01.ogg` |
| mystery.wav | OGA 100 CC0 SFX `wooded_box_open.ogg` |
| warning.wav | OGA 50 CC0 Sci-Fi SFX `beep_03.ogg` (-3 HT) |
| fuse.wav | OGA 25 CC0 bang/firework `fw_loop.ogg` |
| laser_charge.wav | OGA 50 CC0 Sci-Fi SFX `misc_03.ogg` |
| laser_blast.wav | OGA 50 CC0 Sci-Fi SFX `explosion_02.ogg` + OGA 50 CC0 Sci-Fi SFX `rocket_01.ogg` |
| countdown.wav | OGA 100 CC0 SFX `bell_02.ogg` (-5 HT) |
| countdown_go.wav | OGA 100 CC0 SFX `gong_02.ogg` (+5 HT) |
| round_end.wav | OGA 100 CC0 SFX `gong_01.ogg` |
| sudden_death.wav | OGA 100 CC0 SFX #2 `sfx100v2_thunder_01.ogg` |
| draft_start.wav | OGA 100 CC0 SFX `paper_03.ogg` |
| card_pick.wav | OGA 100 CC0 SFX `paper_01.ogg` |
| match_win.wav | OGA 25 CC0 bang/firework `fw_02.ogg` + OGA 100 CC0 SFX `bell_03.ogg` |
| ui_click.wav | OGA 100 CC0 SFX `switch_02.ogg` |
| ui_confirm.wav | OGA 100 CC0 SFX #2 `sfx100v2_switch_02.ogg` + OGA 100 CC0 SFX `bell_02.ogg` (+3 HT) |

