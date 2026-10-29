"""Komponiert ruhige Chiptune-Loops fuer die vier Tilesets.
Alles wird hier synthetisiert (keine fremden Samples), Ergebnis: nahtlose OGG-Loops."""
import numpy as np, subprocess, sys

SR = 44100
OUT = sys.argv[1]
NOTE = {n: i for i, n in enumerate(['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'])}

def hz(midi): return 440.0 * 2 ** ((midi - 69) / 12)

def chord(root, kind, octave=3):
    base = 12 * (octave + 1) + NOTE[root]
    iv = {'maj': [0, 4, 7], 'min': [0, 3, 7], 'maj7': [0, 4, 7, 11], 'min7': [0, 3, 7, 10], 'sus2': [0, 2, 7], 'add9': [0, 4, 7, 14]}[kind]
    return [base + i for i in iv]

# ---------- Oszillatoren ----------
def osc(kind, f, n, duty=0.5, vib=0.0, vib_rate=5.0):
    t = np.arange(n) / SR
    ph_inc = f * (1 + vib * np.sin(2 * np.pi * vib_rate * t) * np.clip(t / 0.25, 0, 1)) / SR
    ph = np.cumsum(ph_inc) % 1.0
    if kind == 'tri': return 4 * np.abs(ph - 0.5) - 1
    if kind == 'sine': return np.sin(2 * np.pi * ph)
    if kind == 'pulse': return np.where(ph < duty, 1.0, -1.0) * 0.8
    if kind == 'bell':  # weiche Glocke: Grundton + leiser hoher Teilton
        return np.sin(2 * np.pi * ph) + 0.35 * np.sin(2 * np.pi * ((ph * 3.01) % 1)) * np.exp(-t * 6)
    raise ValueError(kind)

def env(n, a, d, s, r_total):
    a_n, d_n = max(1, int(a * SR)), max(1, int(d * SR))
    e = np.full(n, s, dtype=np.float64)
    e[:a_n] = np.linspace(0, 1, a_n)[:min(a_n, n)] if n >= a_n else np.linspace(0, 1, n)
    if n > a_n:
        k = min(d_n, n - a_n); e[a_n:a_n + k] = np.linspace(1, s, d_n)[:k]
    r_n = max(1, int(r_total * SR)); r_n = min(r_n, n)
    e[-r_n:] *= np.linspace(1, 0, r_n) ** 2
    return e

class Track:
    def __init__(self, length):
        self.buf = np.zeros(length)
    def note(self, start_s, dur_s, midi, kind='pulse', vol=0.3, duty=0.5, adsr=(0.01, 0.1, 0.6, 0.08), vib=0.0, tail=0.0):
        n = int((dur_s + tail) * SR); i = int(start_s * SR)
        if i >= len(self.buf): return
        n = min(n, len(self.buf) - i)
        sig = osc(kind, hz(midi), n, duty, vib) * env(n, *adsr[:3], adsr[3] + tail) * vol
        self.buf[i:i + n] += sig
    def noise(self, start_s, dur_s, vol=0.05, decay=40.0):
        n = int(dur_s * SR); i = int(start_s * SR)
        if i >= len(self.buf): return
        n = min(n, len(self.buf) - i)
        t = np.arange(n) / SR
        self.buf[i:i + n] += np.random.uniform(-1, 1, n) * np.exp(-t * decay) * vol
    def kick(self, start_s, vol=0.4):
        n = int(0.18 * SR); i = int(start_s * SR)
        if i >= len(self.buf): return
        n = min(n, len(self.buf) - i)
        t = np.arange(n) / SR
        f = 110 * np.exp(-t * 25) + 45
        self.buf[i:i + n] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18) * vol

def ff(sig, af):
    p = subprocess.run(['ffmpeg', '-v', 'error', '-f', 'f64le', '-ar', str(SR), '-ac', '1', '-i', '-', '-af', af, '-f', 'f64le', '-'],
                       input=sig.astype(np.float64).tobytes(), capture_output=True, check=True)
    out = np.frombuffer(p.stdout, dtype=np.float64)
    res = np.zeros(len(sig)); res[:min(len(sig), len(out))] = out[:len(sig)]
    return res

# ---------- Melodie ----------
def scale_notes(key, mode, lo, hi):
    steps = {'major': [0, 2, 4, 5, 7, 9, 11], 'minor': [0, 2, 3, 5, 7, 8, 10], 'dorian': [0, 2, 3, 5, 7, 9, 10],
             'penta': [0, 2, 4, 7, 9], 'minpenta': [0, 3, 5, 7, 10]}[mode]
    return [m for m in range(lo, hi + 1) if (m - NOTE[key]) % 12 in steps]

RHYTHMS = [
    [(0, 1.5), (1.5, 0.5), (2, 2)],
    [(0, 1), (1, 1), (2, 1.5), (3.5, 0.5)],
    [(0, 2), (2, 1), (3, 1)],
    [(0, 3), (3, 1)],
    [(0, 1), (1.5, 0.5), (2, 2)],
    [(0, 4)],
]

def make_phrase(rng, chords, scale, center, rhythms):
    """4 Takte Melodie: betonte Zaehlzeiten auf Akkordtoene, sonst Schritte."""
    phrase, cur = [], center
    for bar, ch in enumerate(chords):
        r = rhythms[rng.integers(len(rhythms))] if bar < 3 else rhythms[-1 if rng.random() < 0.6 else 3]
        for beat, dur in r:
            if beat in (0, 2):
                cands = [m for m in scale if (m % 12) in [c % 12 for c in ch] and abs(m - cur) <= 7]
            else:
                cands = [m for m in scale if 0 < abs(m - cur) <= 3]
            cands = cands or scale
            weights = np.array([1.0 / (1 + abs(m - cur)) + (0.6 if abs(m - center) < 6 else 0) for m in cands])
            cur = cands[rng.choice(len(cands), p=weights / weights.sum())]
            phrase.append((bar * 4 + beat, dur, cur))
    return phrase

def vary(rng, phrase, scale):
    out = []
    for b, d, m in phrase:
        if rng.random() < 0.25 and b % 4 not in (0,):
            idx = scale.index(m) if m in scale else 0
            m = scale[max(0, min(len(scale) - 1, idx + rng.choice([-1, 1])))]
        out.append((b, d, m))
    return out

# ---------- Stuecke ----------
def compose(cfg):
    rng = np.random.default_rng(cfg['seed']); np.random.seed(cfg['seed'])
    bpm, bars = cfg['bpm'], 32
    beat = 60.0 / bpm
    loop_len = bars * 4 * beat
    tail = 4 * beat * 2
    L = int((loop_len + tail) * SR)
    prog_a, prog_b = cfg['prog_a'], cfg['prog_b']
    scale = scale_notes(cfg['key'], cfg['mode'], cfg['mel_lo'], cfg['mel_hi'])
    center = (cfg['mel_lo'] + cfg['mel_hi']) // 2
    chords_a = [chord(*c) for c in prog_a]; chords_b = [chord(*c) for c in prog_b]
    pa = make_phrase(rng, chords_a, scale, center, cfg.get('rhythms', RHYTHMS))
    pb = make_phrase(rng, chords_b, scale, center + 2, cfg.get('rhythms', RHYTHMS))
    # Form: Intro(A ohne Melodie) A A' B A'' B' A  (8 x 4 Takte)
    form = [('a', None), ('a', pa), ('a', vary(rng, pa, scale)), ('b', pb), ('a', vary(rng, pa, scale)), ('b', vary(rng, pb, scale)), ('a', pa), ('a', None)]
    tr = {k: Track(L) for k in ['bass', 'harm', 'arp', 'lead', 'drums', 'pad']}
    for sec, (part, mel) in enumerate(form):
        chs = chords_a if part == 'a' else chords_b
        t0 = sec * 16 * beat
        for bi, ch in enumerate(chs):
            tb = t0 + bi * 4 * beat
            cfg['bass'](tr['bass'], tb, beat, ch, sec)
            cfg['harm'](tr, tb, beat, ch, sec)
        if mel:
            for b, d, m in mel:
                cfg['lead'](tr['lead'], t0 + b * beat, d * beat, m)
        if cfg.get('drums'):
            for bi in range(4):
                cfg['drums'](tr['drums'], t0 + bi * 4 * beat, beat, sec)
    mixl = np.zeros(L); mixr = np.zeros(L)
    for name, (af, vol, pan) in cfg['mix'].items():
        sig = ff(tr[name].buf, af) * vol if af else tr[name].buf * vol
        mixl += sig * (1 - pan) ; mixr += sig * (1 + pan)
    # gemeinsamer weicher Raum, links/rechts leicht verschieden -> Breite
    room = cfg.get('room', '0.8:0.6:180|340:0.25|0.15')
    rl = ff(mixl, f'aecho={room}')
    rr = ff(mixr, 'aecho=' + room.replace('180|340', '210|390'))
    n = int(loop_len * SR)
    out = np.stack([rl, rr], axis=1)
    loop = out[:n].copy()
    loop[:len(out) - n] += out[n:]  # Nachhall des Endes in den Anfang falten -> nahtlos
    rms = np.sqrt(np.mean(loop ** 2))
    loop *= 10 ** (-21 / 20) / rms
    pk = np.max(np.abs(loop))
    if pk > 0.7: loop *= 0.7 / pk
    return loop

# ---------- Instrumente je Thema ----------
def storybook():
    def bass(t, tb, beat, ch, sec):
        r = ch[0] - 12
        for k, m in enumerate([r, r + 7, r + 12 if sec % 2 else r + 7, r + 7]):
            t.note(tb + k * beat, beat * 0.9, m, 'tri', 0.45, adsr=(0.005, 0.15, 0.5, 0.05))
    def harm(tr, tb, beat, ch, sec):
        if sec == 0 or sec == 7:
            for m in ch: tr['pad'].note(tb, beat * 4, m + 12, 'tri', 0.08, adsr=(0.6, 0.5, 0.7, 0.6))
        for k in range(8):
            if k % 2 == 1 or sec in (0, 7):
                m = ch[(k // 2) % len(ch)] + 12
                tr['arp'].note(tb + k * beat / 2, beat * 0.35, m, 'pulse', 0.10, duty=0.25, adsr=(0.003, 0.12, 0.2, 0.05))
    def lead(t, ts, d, m):
        t.note(ts, d * 0.92, m, 'pulse', 0.16, duty=0.5, vib=0.004, adsr=(0.04, 0.2, 0.7, 0.12), tail=0.1)
    def drums(t, tb, beat, sec):
        if sec in (0, 7): return
        for k in range(8): t.noise(tb + k * beat / 2, 0.06, 0.035 if k % 2 else 0.02, 70)
    return dict(seed=11, bpm=84, key='F', mode='major', mel_lo=65, mel_hi=81,
                prog_a=[('F', 'maj'), ('D', 'min'), ('A#', 'maj'), ('C', 'maj')],
                prog_b=[('A#', 'maj'), ('C', 'maj'), ('A', 'min'), ('D', 'min')],
                bass=bass, harm=harm, lead=lead, drums=drums,
                mix={'bass': ('lowpass=f=900', 1.0, 0.0), 'arp': ('lowpass=f=2600', 1.0, -0.3), 'pad': ('lowpass=f=1800', 1.0, 0.2),
                     'lead': ('lowpass=f=3200', 1.0, 0.15), 'drums': ('highpass=f=5000', 1.0, 0.0), 'harm': (None, 0, 0)})

def frost():
    def bass(t, tb, beat, ch, sec):
        t.note(tb, beat * 3.8, ch[0] - 12, 'sine', 0.42, adsr=(0.3, 0.8, 0.6, 0.6))
    def harm(tr, tb, beat, ch, sec):
        for m in ch: tr['pad'].note(tb, beat * 4, m + 12, 'tri', 0.06, adsr=(1.0, 0.5, 0.8, 0.9))
        pat = [0, 1, 2, 1, 2, 0, 1, 2] if sec % 2 else [0, 2, 1, 2, 0, 2, 1, 0]
        for k in range(8):
            if sec in (0, 7) and k % 2: continue
            tr['arp'].note(tb + k * beat / 2, beat * 0.4, ch[pat[k] % len(ch)] + 24, 'bell', 0.08, adsr=(0.002, 0.3, 0.0, 0.05), tail=0.9)
    def lead(t, ts, d, m):
        t.note(ts, d * 0.9, m, 'sine', 0.15, vib=0.003, adsr=(0.15, 0.3, 0.6, 0.3), tail=0.3)
    return dict(seed=23, bpm=70, key='D', mode='dorian', mel_lo=69, mel_hi=84,
                prog_a=[('D', 'min7'), ('A#', 'maj7'), ('F', 'maj7'), ('C', 'sus2')],
                prog_b=[('G', 'min7'), ('D', 'min7'), ('A#', 'maj7'), ('A', 'min')],
                rhythms=[[(0, 3), (3, 1)], [(0, 2), (2, 2)], [(0, 4)], [(0, 1.5), (1.5, 2.5)], [(0, 4)], [(0, 4)]],
                bass=bass, harm=harm, lead=lead, drums=None,
                room='0.8:0.7:240|470:0.35|0.22',
                mix={'bass': ('lowpass=f=500', 1.0, 0.0), 'arp': ('lowpass=f=4500', 1.0, 0.35), 'pad': ('lowpass=f=1500', 1.0, -0.25),
                     'lead': ('lowpass=f=2500', 0.9, -0.1), 'drums': (None, 0, 0), 'harm': (None, 0, 0)})

def neon():
    def bass(t, tb, beat, ch, sec):
        r = ch[0] - 12
        for k in range(8):
            m = r + (12 if k in (3, 7) else 0)
            t.note(tb + k * beat / 2, beat * 0.42, m, 'pulse', 0.30, duty=0.5, adsr=(0.004, 0.08, 0.5, 0.04))
    def harm(tr, tb, beat, ch, sec):
        for m in ch: tr['pad'].note(tb, beat * 4, m + 12, 'pulse', 0.045, duty=0.3, adsr=(0.4, 0.6, 0.7, 0.6))
        if sec in (0, 7): return
        for k in range(16):
            m = ch[k % len(ch)] + (24 if (k // 4) % 2 else 12)
            tr['arp'].note(tb + k * beat / 4, beat * 0.2, m, 'pulse', 0.05, duty=0.125, adsr=(0.002, 0.06, 0.1, 0.03))
    def lead(t, ts, d, m):
        t.note(ts, d * 0.9, m, 'pulse', 0.12, duty=0.35, vib=0.005, adsr=(0.03, 0.25, 0.6, 0.15), tail=0.15)
    def drums(t, tb, beat, sec):
        if sec in (0, 7): return
        for k in range(4): t.kick(tb + k * beat, 0.28)
        for k in range(8):
            if k % 2: t.noise(tb + k * beat / 2, 0.05, 0.03, 90)
        t.noise(tb + beat, 0.15, 0.03, 22); t.noise(tb + 3 * beat, 0.15, 0.03, 22)
    return dict(seed=37, bpm=96, key='A', mode='minor', mel_lo=69, mel_hi=84,
                prog_a=[('A', 'min'), ('F', 'maj'), ('C', 'maj'), ('G', 'maj')],
                prog_b=[('D', 'min'), ('A', 'min'), ('F', 'maj'), ('E', 'min')],
                bass=bass, harm=harm, lead=lead, drums=drums,
                mix={'bass': ('lowpass=f=700', 1.0, 0.0), 'arp': ('lowpass=f=3000', 1.0, 0.4), 'pad': ('lowpass=f=1400', 1.0, -0.3),
                     'lead': ('lowpass=f=2400', 1.0, -0.1), 'drums': ('lowpass=f=6000', 1.0, 0.0), 'harm': (None, 0, 0)})

def wool():
    def bass(t, tb, beat, ch, sec):
        r = ch[0] - 12
        t.note(tb, beat * 1.8, r, 'tri', 0.45, adsr=(0.01, 0.3, 0.5, 0.1))
        t.note(tb + 2 * beat, beat * 1.8, r + 7, 'tri', 0.38, adsr=(0.01, 0.3, 0.5, 0.1))
    def harm(tr, tb, beat, ch, sec):
        # Spieluhr: Triangle-Plinks im Wechsel
        pat = [0, 2, 1, 2, 3 % len(ch), 2, 1, 2]
        for k in range(8):
            if sec in (0, 7) and k % 2: continue
            tr['arp'].note(tb + k * beat / 2, beat * 0.45, ch[pat[k] % len(ch)] + 24, 'tri', 0.09, adsr=(0.002, 0.25, 0.0, 0.05), tail=0.4)
    def lead(t, ts, d, m):
        t.note(ts, d * 0.85, m, 'tri', 0.22, vib=0.006, vib_rate=4.5, adsr=(0.05, 0.25, 0.6, 0.15), tail=0.12) if False else \
        t.note(ts, d * 0.85, m, 'tri', 0.22, vib=0.006, adsr=(0.05, 0.25, 0.6, 0.15), tail=0.12)
    def drums(t, tb, beat, sec):
        if sec in (0, 7): return
        t.noise(tb + beat, 0.2, 0.025, 14); t.noise(tb + 3 * beat, 0.2, 0.025, 14)
    return dict(seed=53, bpm=74, key='G', mode='penta', mel_lo=67, mel_hi=83,
                prog_a=[('G', 'add9'), ('E', 'min7'), ('C', 'maj7'), ('D', 'sus2')],
                prog_b=[('C', 'maj7'), ('G', 'maj'), ('A', 'min7'), ('D', 'maj')],
                bass=bass, harm=harm, lead=lead, drums=drums,
                mix={'bass': ('lowpass=f=800', 1.0, 0.0), 'arp': ('lowpass=f=3500', 1.0, -0.35), 'pad': (None, 0, 0),
                     'lead': ('lowpass=f=2800', 1.0, 0.2), 'drums': ('lowpass=f=3000,highpass=f=800', 1.0, 0.1), 'harm': (None, 0, 0)})

def platine():
    # Ruhige Platinen-Schleife: weicher Sinusbass, leises 16tel-"Datenrauschen"
    # als Puls-Arpeggio, warme Flaechen und nur angedeutete Hi-Hats.
    def bass(t, tb, beat, ch, sec):
        r = ch[0] - 12
        t.note(tb, beat * 2.6, r, 'sine', 0.40, adsr=(0.02, 0.5, 0.6, 0.3))
        t.note(tb + 3 * beat, beat * 0.9, r + 7, 'sine', 0.30, adsr=(0.02, 0.2, 0.5, 0.2))
    def harm(tr, tb, beat, ch, sec):
        for m in ch: tr['pad'].note(tb, beat * 4, m + 12, 'tri', 0.055, adsr=(0.8, 0.6, 0.75, 0.8))
        pat = [0, 2, 1, 2, 0, 1, 2, 1, 0, 2, 1, 2, 1, 0, 2, 1]
        for k in range(16):
            if sec in (0, 7) and k % 4: continue
            if k % 4 == 3 and sec % 2: continue
            m = ch[pat[k] % len(ch)] + 24
            tr['arp'].note(tb + k * beat / 4, beat * 0.18, m, 'pulse', 0.035, duty=0.2, adsr=(0.002, 0.07, 0.0, 0.03))
    def lead(t, ts, d, m):
        t.note(ts, d * 0.9, m, 'bell', 0.09, adsr=(0.004, 0.4, 0.2, 0.2), tail=0.6)
    def drums(t, tb, beat, sec):
        if sec in (0, 7): return
        for k in range(8):
            if k % 2: t.noise(tb + k * beat / 2, 0.04, 0.018, 110)
        if sec in (3, 5): t.kick(tb, 0.12)
    return dict(seed=71, bpm=82, key='E', mode='dorian', mel_lo=71, mel_hi=86,
                prog_a=[('E', 'min7'), ('C', 'maj7'), ('G', 'maj7'), ('D', 'sus2')],
                prog_b=[('A', 'min7'), ('E', 'min7'), ('C', 'maj7'), ('B', 'min')],
                rhythms=[[(0, 2), (2, 2)], [(0, 3), (3, 1)], [(0, 4)], [(0, 1.5), (1.5, 2.5)], [(0, 4)]],
                bass=bass, harm=harm, lead=lead, drums=drums,
                room='0.8:0.65:220|410:0.3|0.2',
                mix={'bass': ('lowpass=f=600', 1.0, 0.0), 'arp': ('lowpass=f=2400', 1.0, 0.35), 'pad': ('lowpass=f=1300', 1.0, -0.3),
                     'lead': ('lowpass=f=3500', 0.9, -0.1), 'drums': ('highpass=f=6000', 1.0, 0.0), 'harm': (None, 0, 0)})

# Optional: nur bestimmte Stuecke erzeugen, z. B. "python compose_music.py out platine"
ONLY = sys.argv[2].split(',') if len(sys.argv) > 2 else None
for name, fn in [('storybook', storybook), ('frost', frost), ('neon', neon), ('wool', wool), ('platine', platine)]:
    if ONLY and name not in ONLY:
        continue
    loop = compose(fn())
    raw = (np.clip(loop, -1, 1) * 32767).astype('<i2').tobytes()
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 's16le', '-ar', str(SR), '-ac', '2', '-i', '-', '-c:a', 'libvorbis', '-q:a', '5',
                    f'{OUT}/music_{name}.ogg'], input=raw, check=True)
    print(name, f'{len(loop) / SR:.1f}s')
