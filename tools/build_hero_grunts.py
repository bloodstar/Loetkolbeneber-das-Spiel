#!/usr/bin/env python3
"""Baut die Grunz-Sounds der Heldenauswahl (assets/audio/sfx/grunt_<held>.wav).

Quelle: "Pig SFX Pack" von Vinrax (CC-BY 3.0),
https://opengameart.org/content/pig-sfx-pack . Die Originale liegen unter
tools/audio_sources/pig_vinrax/ (Ordner hat .gdignore, wird nicht exportiert).

Jede Klasse bekommt ein eigenes Grunzen: andere Quelle, Tonhöhe und eine kleine
Klassen-Würze aus den vorhandenen Spiel-Sounds (Feuer, Strom, Hall, ...).
Danach läuft dieselbe Kette wie bei allen anderen SFX: Mono 44,1 kHz,
Stille trimmen, Hochpass 90 Hz, Tiefpass 7 kHz, kleiner Raum, RMS-Angleich.

Aufruf (im Projektordner):  python3 tools/build_hero_grunts.py
Braucht ffmpeg und numpy.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "audio_sources", "pig_vinrax")
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = 44100
TARGET_RMS = 0.11
PEAK_LIMIT = 0.85

# held -> (quelle, tonhöhe, extra-filter für das Grunzen, [(würze-datei, tonhöhe, dB, versatz s)])
RECIPES = {
    # Feuer: kräftiges Grunzen, darunter ein Zisch-Funken.
    "ignis": ("pig_idle3", 1.0, "", [("fuse", 0.8, -12.0, 0.05)]),
    # Strom: höher, mit schnellem Zittern und einem Lade-Sirren.
    "volt": ("pig_idle2", 1.18, "tremolo=f=32:d=0.55", [("laser_charge", 1.3, -16.0, 0.0)]),
    # Pilz: gemütliches Doppel-Grunzen, etwas tiefer, Blubbern dahinter.
    "spore": ("pig_idle4", 0.9, "", [("poison", 1.0, -15.0, 0.3)]),
    # Magier: hell, mit Funkel-Teleport und Echo.
    "nova": ("pig_idle3", 1.28, "aecho=0.8:0.6:90:0.35", [("teleport", 1.2, -15.0, 0.08)]),
    # Klinge: scharfes Quieken plus Klingenhieb.
    "klinge": ("pig_hit1", 1.05, "", [("slash", 1.1, -10.0, 0.0)]),
    # Bastion: tiefes, schweres Grunzen mit Metall-Klang.
    "bastion": ("pig_idle3", 0.7, "bass=g=5:f=140", [("shield", 0.6, -13.0, 0.12)]),
    # Phantom: leises, verhalltes Grunzen mit Wusch.
    "phantom": ("pig_idle2", 1.08, "aecho=0.8:0.7:120|240:0.4|0.25", [("dash", 0.8, -12.0, 0.0)]),
    # Druide: weiches Doppel-Grunzen mit Heil-Glitzern.
    "druid": ("pig_idle4", 0.96, "", [("heal", 1.0, -16.0, 0.25)]),
    # Vampir: tiefes Quieken mit unheimlichem Hall.
    "vampire": ("pig_hit2", 0.84, "aecho=0.8:0.75:160|320:0.45|0.3", []),
    # Blutritter: grimmiges, tiefes Quieken mit Hieb.
    "vampire_melee": ("pig_hit1", 0.78, "bass=g=3:f=160", [("slash", 0.85, -11.0, 0.05)]),
    # Zeitschläger: Grunzen, dann dasselbe rückwärts (Zeit spult zurück).
    "zeitschlaeger": ("pig_idle3", 1.05, "REVERSE", [("countdown", 1.6, -18.0, 0.0)]),
}


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)


def read_wav(path):
    with wave.open(path) as w:
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    return data


def write_wav(path, data):
    pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def pitched(src, pitch, extra, out):
    chain = [
        "aformat=channel_layouts=mono",
        "asetrate=%d,aresample=%d" % (int(RATE * pitch), RATE),
        "silenceremove=start_periods=1:start_threshold=-45dB",
        "areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
    ]
    if extra and extra != "REVERSE":
        chain.append(extra)
    ffmpeg(["-i", src, "-af", ",".join(chain), "-ar", str(RATE), "-ac", "1", out])


def build(hero, recipe, tmp):
    src_name, pitch, extra, spices = recipe
    base = os.path.join(tmp, hero + "_base.wav")
    pitched(os.path.join(SRC, src_name + ".mp3"), pitch, extra, base)
    voice = read_wav(base)
    voice /= max(1e-4, np.abs(voice).max())
    if extra == "REVERSE":
        gap = np.zeros(int(RATE * 0.06), dtype=np.float32)
        voice = np.concatenate([voice, gap, voice[::-1] * 0.8])
    mix = voice.copy()
    for spice_name, spice_pitch, db, offset in spices:
        sp_path = os.path.join(tmp, "%s_%s.wav" % (hero, spice_name))
        pitched(os.path.join(SFX, spice_name + ".wav"), spice_pitch, "", sp_path)
        sp = read_wav(sp_path)
        sp /= max(1e-4, np.abs(sp).max())
        sp *= 10.0 ** (db / 20.0)
        start = int(offset * RATE)
        end = start + len(sp)
        if end > len(mix):
            mix = np.concatenate([mix, np.zeros(end - len(mix), dtype=np.float32)])
        mix[start:end] += sp
    raw = os.path.join(tmp, hero + "_mix.wav")
    write_wav(raw, mix / max(1e-4, np.abs(mix).max()))
    # Gemeinsame Kette wie bei den anderen SFX, kurzes Ausblenden am Ende.
    dur = len(mix) / RATE
    final_chain = ",".join([
        "highpass=f=90",
        "lowpass=f=7000",
        "aecho=0.9:0.5:28|46:0.12|0.08",
        "afade=t=out:st=%.3f:d=0.08" % max(0.0, dur - 0.08),
    ])
    shaped = os.path.join(tmp, hero + "_shaped.wav")
    ffmpeg(["-i", raw, "-af", final_chain, "-ar", str(RATE), "-ac", "1", shaped])
    data = read_wav(shaped)
    # RMS über den lauten Teil, damit kurze Grunzer nicht zu leise werden.
    frame = 1024
    frames = [data[i:i + frame] for i in range(0, len(data), frame)]
    loud = sorted((float(np.sqrt(np.mean(f ** 2))) for f in frames if len(f)), reverse=True)
    top = loud[: max(1, len(loud) // 3)]
    rms = float(np.mean(top))
    data *= TARGET_RMS / max(1e-4, rms)
    peak = float(np.abs(data).max())
    if peak > PEAK_LIMIT:
        data *= PEAK_LIMIT / peak
    out = os.path.join(SFX, "grunt_%s.wav" % hero)
    write_wav(out, data)
    print("%-14s %.2fs  peak %.2f" % (hero, len(data) / RATE, float(np.abs(data).max())))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        for hero, recipe in RECIPES.items():
            build(hero, recipe, tmp)


if __name__ == "__main__":
    main()
