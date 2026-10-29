"""Baut alternative SFX-Pakete fuer DopDop aus CC0-Quellen.

Aufruf: python3 build_sound_packs.py <quellordner> <zielordner> <referenzordner>
  quellordner:  entpackte Kenney- und OpenGameArt-Pakete (beliebig verschachtelt)
  zielordner:   assets/audio/packs/  (je Paket ein Unterordner)
  referenzordner: assets/audio/sfx/  (aktuelles Set; daraus kommt die Ziel-Lautheit je Datei)

Kette je Datei (wie beim Retro-Set): Mono 44,1 kHz, Stille trimmen, optional
Tonhoehe/Kuerzen/Schichten, Hochpass 90 Hz, sanfter Tiefpass, kleiner Raum,
RMS-Angleich an die gleichnamige Datei im aktuellen Set, Spitze auf -1 dBFS.
"""
import os, sys, subprocess, wave, json
import numpy as np

SR = 44100

# Datei -> Liste von Schichten. Schicht: (quelle, halbtoene, gain_db, start_s, max_s)
# Zusaetzlich je Datei optional "len" (Gesamtlaenge max) ueber RECIPE_LEN.
PACKS = {
    "foley": {
        "label": "Handgemacht (Foley)",
        "lp": 11000,
        "files": {
            "shoot_1": [("pluck_001", 5, 0, 0, 0.3)],
            "shoot_2": [("pluck_002", 5, 0, 0, 0.3)],
            "shoot_3": [("pluck_001", 7, 0, 0, 0.3)],
            "hit_1": [("impactPunch_medium_000", 0, 0, 0, 0.3)],
            "hit_2": [("impactPunch_medium_001", 0, 0, 0, 0.3)],
            "hit_3": [("impactPunch_medium_002", 0, 0, 0, 0.3)],
            "hit_4": [("impactPunch_medium_003", 0, 0, 0, 0.3)],
            "bounce_1": [("impactPlate_light_000", 2, 0, 0, 0.25)],
            "bounce_2": [("impactPlate_light_001", 2, 0, 0, 0.25)],
            "explosion": [("explosionCrunch_000", -2, 0, 0, 1.0), ("impactWood_heavy_000", -3, -4, 0, 0.5)],
            "explosion_big": [("lowFrequency_explosion_000", 0, 0, 0, 1.6), ("explosionCrunch_002", -3, -3, 0, 1.2)],
            "shield": [("impactMetal_medium_000", 0, 0, 0, 0.4)],
            "poison": [("slime_000", 0, 0, 0, 0.35)],
            "death": [("impactPunch_heavy_000", -2, 0, 0, 0.6), ("impactSoft_heavy_000", -4, -3, 0, 0.6)],
            "jump_1": [("cloth1", 2, 0, 0, 0.3)],
            "jump_2": [("cloth3", 2, 0, 0, 0.3)],
            "jump_air": [("cloth2", 5, 0, 0, 0.28)],
            "spring": [("impactTin_medium_000", -2, 0, 0, 0.4)],
            "dash": [("cloth4", 3, 0, 0, 0.38)],
            "slash": [("knifeSlice", 0, 0, 0, 0.4)],
            "teleport": [("forceField_001", 3, 0, 0, 0.4)],
            "heal": [("glass_003", 0, 0, 0, 0.8)],
            "reload": [("metalClick", 0, 0, 0, 0.12)],
            "reload_done": [("metalLatch", 0, 0, 0, 0.2)],
            "coin_1": [("chips-collide-1", 0, 0, 0, 0.3)],
            "coin_2": [("chips-collide-3", 0, 0, 0, 0.4)],
            "mystery": [("question_002", 0, 0, 0, 0.9), ("impactWood_medium_000", 0, -6, 0, 0.3)],
            "warning": [("error_006", 0, 0, 0, 0.45)],
            "fuse": [("scratch_001", 0, 0, 0, 0.2)],
            "laser_charge": [("forceField_000", -5, 0, 0, 0.6)],
            "laser_blast": [("laserLarge_000", -3, 0, 0, 0.8), ("lowFrequency_explosion_001", 0, -2, 0, 1.6)],
            "countdown": [("impactBell_heavy_001", 5, 0, 0, 0.35)],
            "countdown_go": [("impactBell_heavy_000", 7, 0, 0, 0.6), ("confirmation_003", 0, -4, 0, 0.5)],
            "round_end": [("impactBell_heavy_002", 0, 0, 0, 1.0)],
            "sudden_death": [("impactBell_heavy_003", -7, 0, 0, 1.4), ("lowFrequency_explosion_001", -3, -6, 0, 1.2)],
            "draft_start": [("card-shuffle", 0, 0, 0, 1.0)],
            "card_pick": [("card-place-1", 0, 0, 0, 0.5)],
            "match_win": [("confirmation_004", 0, 0, 0, 0.8), ("impactBell_heavy_004", 5, -3, 0, 1.0)],
            "ui_click": [("click_002", 0, 0, 0, 0.1)],
            "ui_confirm": [("confirmation_001", 0, 0, 0, 0.5)],
        },
    },
    "scifi": {
        "label": "Modernes Sci-Fi",
        "lp": 12000,
        "files": {
            "shoot_1": [("laserSmall_000", 0, 0, 0, 0.3)],
            "shoot_2": [("laserSmall_001", 0, 0, 0, 0.3)],
            "shoot_3": [("laserSmall_002", 0, 0, 0, 0.3)],
            "hit_1": [("impactMetal_000", 0, 0, 0, 0.3)],
            "hit_2": [("impactMetal_001", 0, 0, 0, 0.3)],
            "hit_3": [("impactMetal_002", 0, 0, 0, 0.3)],
            "hit_4": [("impactMetal_003", 0, 0, 0, 0.3)],
            "bounce_1": [("forceField_002", 4, 0, 0, 0.18)],
            "bounce_2": [("forceField_003", 4, 0, 0, 0.18)],
            "explosion": [("explosionCrunch_001", 0, 0, 0, 1.0)],
            "explosion_big": [("explosionCrunch_003", -2, 0, 0, 1.4), ("lowFrequency_explosion_000", 0, -2, 0, 1.6)],
            "shield": [("forceField_000", 0, 0, 0, 0.4)],
            "poison": [("slime_001", 0, 0, 0, 0.35)],
            "death": [("explosionCrunch_004", -3, 0, 0, 0.8), ("glitch_002", 0, -4, 0, 0.5)],
            "jump_1": [("thrusterFire_000", 3, 0, 0, 0.25)],
            "jump_2": [("thrusterFire_001", 3, 0, 0, 0.25)],
            "jump_air": [("thrusterFire_002", 6, 0, 0, 0.22)],
            "spring": [("maximize_004", 0, 0, 0, 0.35)],
            "dash": [("thrusterFire_003", 4, 0, 0, 0.35)],
            "slash": [("laserSmall_004", -4, 0, 0, 0.35)],
            "teleport": [("maximize_008", 0, 0, 0, 0.45), ("forceField_001", 5, -6, 0, 0.3)],
            "heal": [("confirmation_002", 0, 0, 0, 0.8)],
            "reload": [("switch_002", 0, 0, 0, 0.12)],
            "reload_done": [("toggle_002", 0, 0, 0, 0.15)],
            "coin_1": [("select_006", 0, 0, 0, 0.3)],
            "coin_2": [("select_007", 0, 0, 0, 0.4)],
            "mystery": [("question_003", 0, 0, 0, 0.9)],
            "warning": [("error_005", 0, 0, 0, 0.45)],
            "fuse": [("computerNoise_001", 4, 0, 0, 0.18)],
            "laser_charge": [("forceField_004", -3, 0, 0, 0.6)],
            "laser_blast": [("laserLarge_003", -2, 0, 0, 0.9), ("lowFrequency_explosion_001", 0, -2, 0, 1.6)],
            "countdown": [("select_001", 0, 0, 0, 0.3)],
            "countdown_go": [("confirmation_004", 0, 0, 0, 0.6)],
            "round_end": [("bong_001", 0, 0, 0, 1.0)],
            "sudden_death": [("spaceEngineLow_000", 0, 0, 0, 1.1), ("error_008", -5, -2, 0, 0.8)],
            "draft_start": [("open_002", 0, 0, 0, 0.8)],
            "card_pick": [("select_003", 0, 0, 0, 0.4)],
            "match_win": [("maximize_005", 0, 0, 0, 0.8), ("confirmation_003", 0, -2, 0.15, 0.8)],
            "ui_click": [("click_004", 0, 0, 0, 0.1)],
            "ui_confirm": [("confirmation_001", 0, 0, 0, 0.5)],
        },
    },
    "natur": {
        "label": "Kräftig & echt",
        "lp": 12000,
        "files": {
            "shoot_1": [("shot_01@bang", 0, 0, 0, 0.3)],
            "shoot_2": [("shot_02@bang", 0, 0, 0, 0.3)],
            "shoot_3": [("shot_03@bang", 0, 0, 0, 0.3)],
            "hit_1": [("bfh1_hit_01", 0, 0, 0, 0.3)],
            "hit_2": [("bfh1_hit_03", 0, 0, 0, 0.3)],
            "hit_3": [("bfh1_hit_06", 0, 0, 0, 0.3)],
            "hit_4": [("bfh1_hit_08", 0, 0, 0, 0.3)],
            "bounce_1": [("spring_04", 0, 0, 0, 0.25)],
            "bounce_2": [("spring_06", 0, 0, 0, 0.28)],
            "explosion": [("cannon_02", 0, 0, 0, 1.0)],
            "explosion_big": [("bang_03", 0, 0, 0, 1.4), ("fw_06", -3, -4, 0, 1.0)],
            "shield": [("sfx100v2_metal_hit_01", 0, 0, 0, 0.4)],
            "poison": [("slime_02", 0, 0, 0, 0.35)],
            "death": [("bfh1_hit_02", 0, 0, 0, 0.6), ("slime_03", -3, -3, 0, 0.5)],
            "jump_1": [("sfx100v2_air_03", 0, 0, 0, 0.25)],
            "jump_2": [("sfx100v2_air_03", 2, 0, 0, 0.25)],
            "jump_air": [("sfx100v2_air_03", 5, 0, 0, 0.22)],
            "spring": [("spring_01", 0, 0, 0, 0.6)],
            "dash": [("sfx100v2_air_02", 0, 0, 0, 0.4)],
            "slash": [("sfx100v2_air_01", 3, 0, 0, 0.3)],
            "teleport": [("teleport_01", 0, 0, 0, 0.4)],
            "heal": [("bell_01", 0, 0, 0, 0.8)],
            "reload": [("switch_01@100", 0, 0, 0, 0.12)],
            "reload_done": [("key_open_01", 0, 0, 0, 0.2)],
            "coin_1": [("bell_02", 0, 0, 0, 0.3)],
            "coin_2": [("sfx100v2_items_01", 0, 0, 0, 0.4)],
            "mystery": [("wooded_box_open", 0, 0, 0, 0.9)],
            "warning": [("beep_03", -3, 0, 0, 0.45)],
            "fuse": [("fw_loop", 0, 0, 0.5, 0.3)],
            "laser_charge": [("misc_03@scifi", 0, 0, 0, 0.8)],
            "laser_blast": [("explosion_02@scifi", 0, 0, 0, 1.0), ("rocket_01", 0, -3, 0, 1.2)],
            "countdown": [("bell_02", -5, 0, 0, 0.3)],
            "countdown_go": [("gong_02", 5, 0, 0, 0.6)],
            "round_end": [("gong_01", 0, 0, 0, 1.0)],
            "sudden_death": [("sfx100v2_thunder_01", 0, 0, 0.6, 1.8)],
            "draft_start": [("paper_03", 0, 0, 0, 0.8)],
            "card_pick": [("paper_01", 0, 0, 0, 0.4)],
            "match_win": [("fw_02", 0, 0, 0, 1.2), ("bell_03", 0, -4, 0, 0.9)],
            "ui_click": [("switch_02@100", 0, 0, 0, 0.1)],
            "ui_confirm": [("sfx100v2_switch_02", 0, 0, 0, 0.2), ("bell_02", 3, -6, 0.03, 0.3)],
        },
    },
    "magie": {
        "label": "Magie & Zauber",
        "lp": 12000,
        "files": {
            "shoot_1": [("spell_01", 0, 0, 0, 0.35)],
            "shoot_2": [("spell_02", 0, 0, 0, 0.35)],
            "shoot_3": [("magic1", 0, 0, 0, 0.35)],
            "hit_1": [("spell_fire_01", 0, 0, 0, 0.3)],
            "hit_2": [("spell_fire_02", 0, 0, 0, 0.3)],
            "hit_3": [("spell_fire_03", 0, 0, 0, 0.3)],
            "hit_4": [("spell_fire_04", 0, 0, 0, 0.3)],
            "bounce_1": [("item_gem_01", 0, 0, 0, 0.25)],
            "bounce_2": [("item_gem_02", 0, 0, 0, 0.25)],
            "explosion": [("spell_fire_05", 0, 0, 0, 1.0)],
            "explosion_big": [("spell_fire_06", -2, 0, 0, 1.4), ("lowFrequency_explosion_000", 0, -6, 0, 1.4)],
            "shield": [("freeze", 0, 0, 0, 0.45)],
            "poison": [("creature_slime_01", 0, 0, 0, 0.35)],
            "death": [("creature_die_01", 0, 0, 0, 0.8)],
            "jump_1": [("swish-2", 0, 0, 0, 0.25)],
            "jump_2": [("swish-5", 0, 0, 0, 0.25)],
            "jump_air": [("swish-9", 3, 0, 0, 0.22)],
            "spring": [("Cure8", 3, 0, 0, 0.35)],
            "dash": [("swing2", 0, 0, 0, 0.35)],
            "slash": [("blade_02", 0, 0, 0, 0.4)],
            "teleport": [("teleport", 0, 0, 0, 0.6)],
            "heal": [("Cure2", 0, 0, 0, 0.8)],
            "reload": [("book_01", 0, 0, 0, 0.15)],
            "reload_done": [("item_gem_03", 0, 0, 0, 0.2)],
            "coin_1": [("item_coins_01", 0, 0, 0, 0.35)],
            "coin_2": [("item_coins_02", 0, 0, 0, 0.4)],
            "mystery": [("magical_6_0", 0, 0, 0, 0.9)],
            "warning": [("magical_1_0", 2, 0, 0, 0.5)],
            "fuse": [("spell_fire_07", 0, 0, 0, 0.25)],
            "laser_charge": [("magical_4", 0, 0, 0, 0.8)],
            "laser_blast": [("magical_3", 0, 0, 0, 1.2), ("spell_fire_06", 0, -4, 0, 1.0)],
            "countdown": [("item_gem_04", 0, 0, 0, 0.3)],
            "countdown_go": [("Cure5", 0, 0, 0, 0.7)],
            "round_end": [("magical_2", 0, 0, 0, 1.0)],
            "sudden_death": [("magical_1_0", -5, 0, 0, 1.5)],
            "draft_start": [("book_02", 0, 0, 0, 0.6), ("magical_7_0", 0, -6, 0, 0.8)],
            "card_pick": [("book_03", 0, 0, 0, 0.4)],
            "match_win": [("magical_5", 0, 0, 0, 1.4)],
            "ui_click": [("interface1", 0, 0, 0, 0.1)],
            "ui_confirm": [("Cure1", 0, 0, 0, 0.4)],
        },
    },
    "werkstatt": {
        "label": "Werkstatt & Metall",
        "lp": 12000,
        "files": {
            "shoot_1": [("dull_metal_collision_04_44k_32bit_stereo", 0, 0, 0, 0.25)],
            "shoot_2": [("dull_metal_collision_09_44k_32bit_stereo", 0, 0, 0, 0.25)],
            "shoot_3": [("dull_metal_collision_14_44k_32bit_stereo", 0, 0, 0, 0.25)],
            "hit_1": [("impactPlate_medium_000", 0, 0, 0, 0.3)],
            "hit_2": [("impactPlate_medium_001", 0, 0, 0, 0.3)],
            "hit_3": [("impactPlate_medium_002", 0, 0, 0, 0.3)],
            "hit_4": [("impactPlate_medium_003", 0, 0, 0, 0.3)],
            "bounce_1": [("wobble_04_44k_32bit_stereo", 0, 0, 0, 0.25)],
            "bounce_2": [("wobble_06_44k_32bit_stereo", 0, 0, 0, 0.25)],
            "explosion": [("impactMining_000", 0, 0, 0, 0.6), ("explosionCrunch_001", 0, -4, 0, 1.0)],
            "explosion_big": [("rapid_clangs_01_44k_32bit_stereo", 0, -3, 0, 0.8), ("lowFrequency_explosion_001", 0, 0, 0, 1.5)],
            "shield": [("dull_metal_collision_10_44k_32bit_stereo", 0, 0, 0, 0.45)],
            "poison": [("thrusterFire_004", 0, 0, 0, 0.3)],
            "death": [("dull_metal_collision_13_44k_32bit_stereo", 0, 0, 0, 0.6), ("impactMetal_heavy_000", -2, -3, 0, 0.6)],
            "jump_1": [("swish-3", 0, 0, 0, 0.25), ("impactTin_medium_001", 3, -8, 0, 0.2)],
            "jump_2": [("swish-6", 0, 0, 0, 0.25), ("impactTin_medium_002", 3, -8, 0, 0.2)],
            "jump_air": [("swish-11", 3, 0, 0, 0.22)],
            "spring": [("wobble_08_44k_32bit_stereo", 0, 0, 0, 0.6)],
            "dash": [("metal_grit_02_44k_32bit_stereo", 0, 0, 0, 0.35)],
            "slash": [("drawKnife1", 0, 0, 0, 0.4)],
            "teleport": [("doorOpen_000", 0, 0, 0, 0.45)],
            "heal": [("jingles_STEEL00", 0, 0, 0, 0.7)],
            "reload": [("lock_01", 0, 0, 0, 0.15)],
            "reload_done": [("lock_02", 0, 0, 0, 0.25)],
            "coin_1": [("coin2", 0, 0, 0, 0.35)],
            "coin_2": [("coin3", 0, 0, 0, 0.4)],
            "mystery": [("dull_metal_collision_12_44k_32bit_stereo", 0, 0, 0, 0.5), ("jingles_STEEL09", 0, -4, 0, 0.6)],
            "warning": [("rapid_clangs_01_44k_32bit_stereo", 0, 0, 0, 0.4)],
            "fuse": [("metal_grit_01_44k_32bit_stereo", 4, 0, 0, 0.2)],
            "laser_charge": [("engineCircular_000", 0, 0, 0, 0.7)],
            "laser_blast": [("thrusterFire_000", -3, 0, 0, 1.0), ("impactMining_002", 0, -2, 0, 0.6)],
            "countdown": [("dull_metal_collision_06_44k_32bit_stereo", 5, 0, 0, 0.3)],
            "countdown_go": [("jingles_STEEL04", 0, 0, 0, 0.7)],
            "round_end": [("jingles_STEEL01", 0, 0, 0, 1.2)],
            "sudden_death": [("jingles_STEEL03", -5, 0, 0, 1.6)],
            "draft_start": [("chain_02", 0, 0, 0, 0.8)],
            "card_pick": [("metal_02@rpg80", 0, 0, 0, 0.4)],
            "match_win": [("jingles_STEEL07", 0, 0, 0, 1.3)],
            "ui_click": [("switch_005", 0, 0, 0, 0.1)],
            "ui_confirm": [("jingles_STEEL16", 0, 0, 0, 0.45)],
        },
    },
    "arena": {
        "label": "Arena mit Ansager",
        "lp": 12000,
        "files": {
            "shoot_1": [("swish-1", 0, 0, 0, 0.25), ("impactGeneric_light_000", 0, -6, 0, 0.2)],
            "shoot_2": [("swish-4", 0, 0, 0, 0.25), ("impactGeneric_light_001", 0, -6, 0, 0.2)],
            "shoot_3": [("swish-8", 0, 0, 0, 0.25), ("impactGeneric_light_002", 0, -6, 0, 0.2)],
            "hit_1": [("impactPunch_heavy_001", 0, 0, 0, 0.3)],
            "hit_2": [("impactPunch_heavy_002", 0, 0, 0, 0.3)],
            "hit_3": [("impactPunch_heavy_003", 0, 0, 0, 0.3)],
            "hit_4": [("impactPunch_heavy_004", 0, 0, 0, 0.3)],
            "bounce_1": [("impactGeneric_light_003", 3, 0, 0, 0.25)],
            "bounce_2": [("impactGeneric_light_004", 3, 0, 0, 0.25)],
            "explosion": [("bang_07", 0, 0, 0, 1.0)],
            "explosion_big": [("cannon_01", 0, 0, 0, 1.4), ("lowFrequency_explosion_000", 0, -3, 0, 1.4)],
            "shield": [("impactMetal_heavy_001", 0, 0, 0, 0.45)],
            "poison": [("slime_04@water", 0, 0, 0, 0.35)],
            "death": [("impactPunch_heavy_000", -2, 0, 0, 0.6), ("impactSoft_heavy_002", -3, -3, 0, 0.6)],
            "jump_1": [("swish-12", 0, 0, 0, 0.25)],
            "jump_2": [("swish-13", 0, 0, 0, 0.25)],
            "jump_air": [("swish-10", 4, 0, 0, 0.22)],
            "spring": [("spring_02", 0, 0, 0, 0.6)],
            "dash": [("swing3", 0, 0, 0, 0.4)],
            "slash": [("swing", 0, 0, 0, 0.4)],
            "teleport": [("forceField_003", 2, 0, 0, 0.45)],
            "heal": [("jingles_HIT03", 0, 0, 0, 0.8)],
            "reload": [("metal-small1", 0, 0, 0, 0.15)],
            "reload_done": [("metal-small2", 0, 0, 0, 0.25)],
            "coin_1": [("coin", 0, 0, 0, 0.35)],
            "coin_2": [("coin2", 2, 0, 0, 0.4)],
            "mystery": [("jingles_HIT09", 0, 0, 0, 0.8)],
            "warning": [("jingles_HIT00", 0, 0, 0, 0.4)],
            "fuse": [("scratch_002", 0, 0, 0, 0.2)],
            "laser_charge": [("forceField_004", -4, 0, 0, 0.7)],
            "laser_blast": [("laserLarge_004", -2, 0, 0, 1.0), ("bang_03", 0, -3, 0, 1.0)],
            "countdown": [("jingles_HIT12", 0, 0, 0, 0.3)],
            "countdown_go": [("fight@fighter", 0, 0, 0, 1.0)],
            "round_end": [("Excellent - ArenaCombatAnnouncerPack", 0, 0, 0, 1.4)],
            "sudden_death": [("Sudden Death - ArenaCombatAnnouncerPack", 0, 0, 0, 1.8)],
            "draft_start": [("prepare_yourself@fighter", 0, 0, 0, 1.6)],
            "card_pick": [("playcard", 0, 0, 0, 0.4)],
            "match_win": [("winner@fighter", 0, 0, 0, 1.6)],
            "ui_click": [("tap", 0, 0, 0, 0.1)],
            "ui_confirm": [("jingles_HIT07", 0, 0, 0, 0.4)],
        },
    },
    "weich": {
        "label": "Weich & verspielt",
        "lp": 10000,
        "files": {
            "shoot_1": [("bubble_01", 0, 0, 0, 0.25)],
            "shoot_2": [("bubble_02", 0, 0, 0, 0.25)],
            "shoot_3": [("bubble_03", 0, 0, 0, 0.25)],
            "hit_1": [("impactSoft_medium_000", 0, 0, 0, 0.3)],
            "hit_2": [("impactSoft_medium_001", 0, 0, 0, 0.3)],
            "hit_3": [("impactSoft_medium_002", 0, 0, 0, 0.3)],
            "hit_4": [("impactSoft_medium_003", 0, 0, 0, 0.3)],
            "bounce_1": [("spring_03", 0, 0, 0, 0.25)],
            "bounce_2": [("spring_08", 0, 0, 0, 0.25)],
            "explosion": [("impactSoft_heavy_003", -3, 0, 0, 0.6), ("splash_02@water", 0, -4, 0, 0.8)],
            "explosion_big": [("impactSoft_heavy_004", -5, 0, 0, 0.8), ("splash_04@water", -2, -2, 0, 1.2)],
            "shield": [("bubble3", 0, 0, 0, 0.4)],
            "poison": [("slime_05", 0, 0, 0, 0.35)],
            "death": [("impactSoft_heavy_001", -3, 0, 0, 0.6), ("jingles_PIZZI06", 0, -4, 0, 0.6)],
            "jump_1": [("impactSoft_medium_004", 7, 0, 0, 0.2)],
            "jump_2": [("impactSoft_medium_004", 9, 0, 0, 0.2)],
            "jump_air": [("spring_05", 5, 0, 0, 0.25)],
            "spring": [("spring_09", 0, 0, 0, 0.5)],
            "dash": [("cloth", 0, 0, 0, 0.35)],
            "slash": [("swish-7", 2, 0, 0, 0.3)],
            "teleport": [("splash_03@water", 6, 0, 0, 0.3)],
            "heal": [("jingles_PIZZI10", 0, 0, 0, 0.7)],
            "reload": [("wood-small", 0, 0, 0, 0.15)],
            "reload_done": [("jingles_PIZZI16", 0, 0, 0, 0.3)],
            "coin_1": [("jingles_PIZZI04", 0, 0, 0, 0.35)],
            "coin_2": [("jingles_PIZZI09", 0, 0, 0, 0.4)],
            "mystery": [("jingles_PIZZI13", 0, 0, 0, 0.8)],
            "warning": [("jingles_PIZZI15", 0, 0, 0, 0.6)],
            "fuse": [("scratch_004", 0, 0, 0, 0.2)],
            "laser_charge": [("loop_bubbles_1", 0, 0, 0, 0.6)],
            "laser_blast": [("splash_01@water", 0, 0, 0, 1.0), ("impactSoft_heavy_000", -4, -2, 0, 0.6)],
            "countdown": [("jingles_PIZZI08", 0, 0, 0, 0.3)],
            "countdown_go": [("jingles_PIZZI05", 0, 0, 0, 0.5)],
            "round_end": [("jingles_PIZZI07", 0, 0, 0, 1.1)],
            "sudden_death": [("jingles_PIZZI12", -5, 0, 0, 1.2)],
            "draft_start": [("shuffle", 0, 0, 0, 0.9)],
            "card_pick": [("draw", 0, 0, 0, 0.4)],
            "match_win": [("jingles_PIZZI03", 0, 0, 0, 1.0)],
            "ui_click": [("tick_002", 0, 0, 0, 0.1)],
            "ui_confirm": [("jingles_PIZZI00", 0, 0, 0, 0.35)],
        },
    },
}

# Pakete, deren Quellnamen doppelt vorkommen: Kuerzel -> Ordnerteil
TAGS = {"bang": "25-CC0-bang", "100": "100-CC0-SFX", "scifi": "sci-fi-sfx", "water": "water-splash-slime",
        "rpg80": "80-CC0-RPG", "fighter": "voiceover-pack-fighter"}
UI_FILES = {"ui_click", "ui_confirm", "reload", "reload_done"}


def index_sources(root):
    idx = {}
    for d, _, files in os.walk(root):
        for f in files:
            if f.lower().endswith((".ogg", ".wav")) and not f.startswith(("Preview", "._")):
                idx.setdefault(os.path.splitext(f)[0], []).append(os.path.join(d, f))
    return idx


def resolve(idx, name):
    base, _, tag = name.partition("@")
    cands = idx.get(base, [])
    if tag:
        cands = [c for c in cands if TAGS[tag] in c]
    if len(cands) != 1:
        raise SystemExit(f"Quelle {name!r} nicht eindeutig: {cands}")
    return cands[0]


def decode(path, semitones):
    rate = SR * (2 ** (semitones / 12.0))
    af = f"asetrate={rate:.1f},aresample={SR}" if semitones else f"aresample={SR}"
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-ac", "1", "-af", af, "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def trim_lead(x, thr_db=-45.0):
    a = np.abs(x)
    if a.max() <= 0:
        return x
    idx = np.where(a > a.max() * 10 ** (thr_db / 20))[0]
    start = max(0, idx[0] - int(0.002 * SR))
    end = min(len(x), idx[-1] + int(0.01 * SR))
    return x[start:end]


def fade_out(x, max_s):
    n = min(len(x), int(max_s * SR))
    x = x[:n].copy()
    f = min(n, int(0.04 * SR))
    if f > 0:
        x[-f:] *= np.linspace(1, 0, f) ** 2
    return x


def ffilter(x, chain):
    p = subprocess.run(["ffmpeg", "-v", "quiet", "-f", "f64le", "-ar", str(SR), "-ac", "1", "-i", "-",
                        "-af", chain, "-f", "f64le", "-"], input=x.astype(np.float64).tobytes(),
                       capture_output=True, check=True)
    return np.frombuffer(p.stdout, dtype=np.float64)


def act_rms_db(x):
    a = np.abs(x)
    act = x[a > a.max() * 0.05]
    return 20 * np.log10(np.sqrt((act ** 2).mean()) + 1e-12)


def ref_levels(ref_dir):
    out = {}
    for f in os.listdir(ref_dir):
        if f.endswith(".wav"):
            w = wave.open(os.path.join(ref_dir, f))
            x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0
            out[f[:-4]] = act_rms_db(x)
    return out


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())


def build(src_root, out_root, ref_dir):
    idx = index_sources(src_root)
    refs = ref_levels(ref_dir)
    manifest = {}
    for pack_id, pack in PACKS.items():
        out_dir = os.path.join(out_root, pack_id)
        os.makedirs(out_dir, exist_ok=True)
        manifest[pack_id] = {"label": pack["label"], "files": {}}
        for name, layers in pack["files"].items():
            mix = np.zeros(1)
            used = []
            for src, semi, gain, start, max_s in layers:
                path = resolve(idx, src)
                used.append((os.path.relpath(path, src_root), semi, gain))
                x = decode(path, semi)
                x = x[int(start * SR):]
                x = trim_lead(x)
                x = fade_out(x, max_s)
                x = x / (np.abs(x).max() + 1e-12) * 10 ** (gain / 20)
                if len(x) > len(mix):
                    mix = np.pad(mix, (0, len(x) - len(mix)))
                mix[:len(x)] += x
            chain = f"highpass=f=90,lowpass=f={pack['lp']}"
            if name not in UI_FILES:
                chain += ",aecho=0.9:0.6:19|31:0.12|0.07"
            tail = np.zeros(int(0.06 * SR))
            y = ffilter(np.concatenate([mix, tail]), chain)
            y = trim_lead(y, -55.0)
            target = refs.get(name, -16.0)
            y = y * 10 ** ((target - act_rms_db(y)) / 20)
            peak = np.abs(y).max()
            if peak > 10 ** (-1 / 20):
                y = y / peak * 10 ** (-1 / 20)
            write_wav(os.path.join(out_dir, name + ".wav"), y)
            manifest[pack_id]["files"][name] = used
    with open(os.path.join(out_root, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    build(*sys.argv[1:4])
