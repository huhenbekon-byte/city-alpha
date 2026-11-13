"""Новые радиостанции и саундтреки «Города Альфа» — оригинальные композиции,
синтезированные с нуля (гитара Карплуса-Стронга, баян, духовые, кларнет, драм-машина).

Запуск:  python3 gen_music.py <папка music/>
Каждый трек — бесшовная петля (хвосты эффектов заворачиваются в начало).
"""
import os
import sys

import numpy as np
from scipy.signal import lfilter

import audiolib as A
from audiolib import mf, mel, nm, lp, hp, bp, noise, t_, adsr, perc, osc_f, saw, sq, sine

SR = A.SR
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(23)


# ================================================================ дорожка

class Track:
    def __init__(self, bpm, bars, bpb=4):
        self.beat = 60.0 / bpm
        self.bpb = bpb
        self.n = int(round(bars * bpb * self.beat * SR))
        self.buses = {}

    def add(self, bus, at_beats, sig, gain=1.0):
        i = int(round(at_beats * self.beat * SR)) % self.n
        b = self.buses.setdefault(bus, np.zeros(self.n))
        sig = sig * gain
        while len(sig):
            m = min(len(sig), self.n - i)
            b[i:i + m] += sig[:m]
            sig = sig[m:]
            i = 0

    def bus(self, name):
        return self.buses.get(name, np.zeros(self.n))

    def melody(self, bus, bar, notes, inst, gain=1.0, shift=0):
        for at, m, d in notes:
            if m is not None:
                self.add(bus, bar * self.bpb + at, inst(m + shift, d * self.beat), gain)


def loop_fx(x, fn):
    """Эффект для петли: считаем на двух копиях подряд и берём вторую — шва нет."""
    n = len(x)
    y = fn(np.concatenate([x, x]))
    return y[n:2 * n]


def master(mix, name, rms_db=-15.0):
    mix = loop_fx(mix, lambda s: hp(lp(s, 12000), 32))
    mix -= np.mean(mix)
    rms = np.sqrt(np.mean(mix ** 2)) + 1e-9
    mix *= (10 ** (rms_db / 20)) / rms
    mix = np.tanh(mix / 0.85) * 0.85          # мягкий лимитер
    mix *= min(1.0, 0.95 / (np.max(np.abs(mix)) + 1e-9))
    A.write_ogg(os.path.join(OUT, name + '.ogg'), mix, 2)
    print(name, round(len(mix) / SR, 1), 's')


# ================================================================ инструменты

def ks(note, length, decay=1.8, bright=0.55, mute=0.0):
    """Струна Карплуса-Стронга с дробной задержкой (точный строй)."""
    f = mf(note)
    n = int(length * SR) + int(0.05 * SR)
    L = SR / f
    N = int(L - 0.6)
    d = L - 0.5 - N
    c = (1 - d) / (1 + d)
    g = np.exp(-1.0 / (f * decay))
    exc = np.zeros(n)
    burst = lp(noise(N + 2), 700 + bright * 7000)
    exc[:N + 2] = burst / (np.max(np.abs(burst)) + 1e-9)
    a = np.zeros(N + 3)
    a[0] = 1.0
    a[1] = c
    a[N] -= g * 0.5 * c
    a[N + 1] -= g * 0.5 * (1 + c)
    a[N + 2] -= g * 0.5
    y = lfilter([1.0, c], a, exc)
    if mute > 0:
        y *= np.exp(-t_(n) / mute)
    y *= np.clip((n / SR - t_(n)) / 0.04, 0, 1)
    return y * 0.35


def guitar(note, length, **kw):
    y = ks(note, length, **kw)
    return hp(y + lp(y, 260) * 0.5, 70)


def strum(notes, length, down=True, spread=0.011, vel=1.0, decay=1.6, bright=0.5, mute=0.0):
    order = notes if down else list(reversed(notes))
    n = int(length * SR) + int(0.05 * SR)
    out = np.zeros(n + int(spread * SR * len(notes)) + 10)
    for k, m in enumerate(order):
        s = guitar(m, length, decay=decay, bright=bright, mute=mute) * (1.0 - 0.06 * k if down else 0.8)
        i = int(k * spread * SR)
        out[i:i + len(s)] += s
    return out[:n] * vel


def power_chord(root, length, mute=0.0):
    x = sum(ks(m, length, decay=3.0, bright=0.8, mute=mute) for m in (root, root + 7, root + 12))
    x = np.tanh(hp(x, 120) * 9.0)
    x = bp(x, 110, 3800)
    return x * 0.22 * np.clip((length + 0.05 - t_(len(x))) / 0.04, 0, 1)


def reed(note, length, vel=1.0, bright=2600):
    """Баян / аккордеон: два голоса с «мюзет»-расстройкой."""
    n = int(length * SR) + int(0.06 * SR)
    t = t_(n)
    f = mf(note)
    trem = 1 + 0.002 * np.sin(2 * np.pi * 5.2 * t)
    x = osc_f(np.full(n, f * 0.9975) * trem, 'saw') + osc_f(np.full(n, f * 1.0025) * trem, 'saw') \
        + 0.6 * osc_f(np.full(n, f * 0.5) * trem, 'sq')
    x = bp(x, 180, bright)
    return x * adsr(n, 0.025, 0.25, 0.85, 0.07) * 0.11 * vel


def clarinet(note, length, vel=1.0):
    n = int(length * SR) + int(0.06 * SR)
    t = t_(n)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) / 0.2, 0, 1)
    f = np.full(n, mf(note)) * vib * (1 - 0.015 * np.exp(-t * 40))
    x = osc_f(f, 'sq') * 0.7 + osc_f(f, 'tri') * 0.5
    x = lp(x, 2000) + bp(noise(n), 1500, 4000) * 0.03
    return x * adsr(n, 0.035, 0.3, 0.9, 0.06) * 0.16 * vel


def brass(notes, length, vel=1.0, bright=2600):
    """Медная группа: «сочный» выдув с ярким началом и мягким звуком потом."""
    n = int(length * SR) + int(0.06 * SR)
    t = t_(n)
    x = np.zeros(n)
    for m in notes:
        f = mf(m) * (1 - 0.02 * np.exp(-t * 30))
        x += osc_f(f * 0.998, 'saw') + osc_f(f * 1.003, 'saw')
    e = np.exp(-t * 6)
    x = lp(x, 650) * (1 - 0.6 * e) + lp(x, bright) * (0.4 + 0.6 * e)
    return x * adsr(n, 0.02, 0.25, 0.8, 0.06) * 0.07 * vel


def trumpet(note, length, vel=1.0):
    n = int(length * SR) + int(0.06 * SR)
    t = t_(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.2) / 0.2, 0, 1)
    f = np.full(n, mf(note)) * vib * (1 - 0.03 * np.exp(-t * 35))
    x = osc_f(f, 'saw')
    e = np.exp(-t * 5)
    x = lp(x, 900) * (1 - 0.5 * e) + lp(x, 2800) * (0.5 + 0.5 * e)
    return x * adsr(n, 0.018, 0.2, 0.85, 0.05) * 0.13 * vel


def tuba(note, length, vel=1.0):
    n = int(length * SR) + int(0.05 * SR)
    f = mf(note)
    x = lp(saw(f, n), 380) + sine(f, n) * 0.6
    return x * adsr(n, 0.015, 0.15, 0.55, 0.05) * 0.32 * vel


def strings(notes, length, vel=1.0, bright=2400):
    n = int(length * SR) + int(0.3 * SR)
    t = t_(n)
    x = np.zeros(n)
    for m in notes:
        for k, det in enumerate((-0.08, 0.0, 0.08)):
            vib = 1 + 0.004 * np.sin(2 * np.pi * (5.0 + k * 0.4) * t + k)
            x += osc_f(np.full(n, mf(m + det)) * vib, 'saw')
    x = lp(x, bright)
    return x * adsr(n, 0.3, 0.5, 0.9, 0.3) * 0.035 * vel


def pad(notes, length, bright=1800, vel=1.0):
    n = int(length * SR) + int(0.4 * SR)
    x = np.zeros(n)
    for m in notes:
        for det in (-0.1, 0.0, 0.1):
            x += saw(mf(m + det), n, rng.random())
    x = lp(x, bright)
    return x * adsr(n, 0.5, 1.0, 0.9, 0.4) * 0.045 * vel


def epiano(notes, length, vel=1.0):
    n = int(length * SR) + int(0.1 * SR)
    t = t_(n)
    x = np.zeros(n)
    for m in notes:
        f = mf(m)
        x += (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 7)
              + 0.08 * np.sin(2 * np.pi * f * 7 * t) * np.exp(-t * 30)) * np.exp(-t * 1.4)
    x *= 1 + 0.12 * np.sin(2 * np.pi * 4.2 * t)
    return x * adsr(n, 0.003, 1.0, 1.0, 0.1) * 0.15 * vel


def lead(note, length, vel=1.0, bright=2400, vib=True):
    n = int(length * SR) + int(0.06 * SR)
    t = t_(n)
    v = 1 + (0.005 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1) if vib else 0)
    f = np.full(n, mf(note)) * v
    x = osc_f(f, 'saw') * 0.6 + osc_f(f * 1.004, 'sq') * 0.35
    x = lp(x, bright)
    return x * adsr(n, 0.01, 0.3, 0.8, 0.06) * 0.12 * vel


def bell(note, length, vel=1.0):
    """Мягкие «колокольчики» (челеста) — без писка: верхние призвуки срезаны."""
    n = int(length * SR) + int(0.1 * SR)
    t = t_(n)
    f = mf(note)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.5) + 0.25 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t * 8)
    return lp(x, 3200) * np.minimum(1, t / 0.002) * 0.12 * vel


def bass(note, length, bright=700, kind='saw', vel=1.0):
    n = int(length * SR) + int(0.03 * SR)
    f = mf(note)
    x = (saw(f, n) if kind == 'saw' else sq(f, n)) * 0.7 + sine(f, n)
    x = lp(x, bright)
    return x * adsr(n, 0.004, 0.2, 0.7, 0.03) * 0.3 * vel


def upright(note, length, vel=1.0):
    y = ks(note, max(length, 0.5), decay=0.9, bright=0.25)
    y = lp(y, 900) + lp(y, 180) * 0.8
    return y * 1.5 * vel


# --- ударные

def kick(punch=1.0, length=0.35, low=48, vel=1.0):
    n = int(length * SR)
    t = t_(n)
    f = low + 120 * np.exp(-t * 32) * punch
    x = osc_f(f, 'sine') * np.exp(-t * 8) + lp(noise(n), 2500) * np.exp(-t * 300) * 0.25
    return x * vel


def snare(tone=185, length=0.25, bright=1.0, vel=1.0):
    n = int(length * SR)
    t = t_(n)
    nz = bp(noise(n), 1200, 7000) * np.exp(-t * 16) * 0.55 * bright
    body = osc_f(tone * (1 + 0.4 * np.exp(-t * 60)), 'sine') * np.exp(-t * 22) * 0.6
    return (nz + body) * vel


def gated_snare(vel=1.0):
    x = snare(190, 0.45, 1.2)
    tail = A.reverb(x, 0.8, 0.9, 5000, 0.1)[:len(x)]
    g = np.clip((0.28 - t_(len(x))) / 0.02, 0, 1)
    return (x + tail * 0.8) * g * vel


def clap(vel=1.0):
    n = int(0.25 * SR)
    t = t_(n)
    e = np.zeros(n)
    for off in (0.0, 0.011, 0.023):
        e += (t >= off) * np.exp(-np.maximum(t - off, 0) * 70)
    e += np.exp(-t * 14) * 0.45
    return bp(noise(n), 900, 3800) * e * 0.7 * vel


def hat(open_=False, vel=1.0):
    n = int((0.28 if open_ else 0.05) * SR)
    t = t_(n)
    x = bp(noise(n), 6000, 11000) * np.exp(-t * (11 if open_ else 75))
    return x * 0.35 * vel


def shaker(vel=1.0):
    n = int(0.07 * SR)
    t = t_(n)
    return bp(noise(n), 3500, 8000) * np.sin(np.pi * np.minimum(1, t / 0.07)) * 0.18 * vel


def brush(vel=1.0):
    n = int(0.18 * SR)
    t = t_(n)
    return bp(noise(n), 1500, 6000) * np.minimum(1, t / 0.01) * np.exp(-t * 14) * 0.25 * vel


def tom(f=110, vel=1.0, length=0.5):
    n = int(length * SR)
    t = t_(n)
    x = osc_f(f * (1 + 0.5 * np.exp(-t * 25)), 'sine') * np.exp(-t * 6)
    return (x + lp(noise(n), 1200) * np.exp(-t * 40) * 0.3) * vel


def crash(vel=1.0):
    n = int(1.6 * SR)
    t = t_(n)
    return bp(noise(n), 3000, 10000) * np.exp(-t * 2.5) * np.minimum(1, t / 0.002) * 0.22 * vel


def dum(vel=1.0):
    n = int(0.35 * SR)
    t = t_(n)
    return (osc_f(85 * (1 + 0.3 * np.exp(-t * 30)), 'sine') * np.exp(-t * 9) + lp(noise(n), 600) * np.exp(-t * 30) * 0.3) * vel


def tek(vel=1.0):
    n = int(0.12 * SR)
    t = t_(n)
    return (bp(noise(n), 1800, 6000) * np.exp(-t * 45) * 0.5 + sine(640, n) * np.exp(-t * 35) * 0.3) * vel


def bass_drum(vel=1.0):
    return kick(0.4, 0.6, 42, vel) + lp(noise(int(0.6 * SR)), 300) * np.exp(-t_(int(0.6 * SR)) * 12) * 0.25 * vel


def riser(length):
    n = int(length * SR)
    t = t_(n)
    x = A.sweep_lp(noise(n), 300, 6000)
    return x * (t / length) ** 2 * 0.25


# ================================================================ аккорды

CH = {
    'Am': [45, 52, 57, 60, 64], 'Dm': [50, 57, 62, 65], 'E7': [40, 47, 50, 56, 59, 64], 'A7': [45, 52, 55, 61, 64],
    'G': [43, 47, 50, 55, 59, 67], 'C': [48, 52, 55, 60, 64], 'F': [41, 48, 53, 57, 60, 65], 'E': [40, 47, 52, 56, 59, 64],
    'Em': [40, 47, 52, 55, 59, 64], 'D': [50, 57, 62, 66],
}
BASS_ALT = {'Am': (45, 40), 'Dm': (50, 45), 'E7': (40, 47), 'A7': (45, 40), 'G': (43, 50), 'C': (48, 43), 'F': (41, 48), 'E': (40, 47)}


def triad(root, kind='M'):
    return [root, root + (3 if kind == 'm' else 4), root + 7]


# ================================================================ 1. Дворовая гитара

def track_dvor():
    """Дворовая песня под гитару и баян: Am, «восьмёрка» на семиструнке, щётки."""
    T = Track(100, 32)
    prog_a = ['Am', 'Am', 'Dm', 'Am', 'E7', 'E7', 'Am', 'A7']
    prog_b = ['Dm', 'G', 'C', 'Am', 'Dm', 'Am', 'E7', 'Am']
    mel_a = mel('E4:1 A4:1 B4:1 C5:1 | B4:1.5 A4:.5 E4:2 | D4:1 F4:1 A4:1 D5:1 | C5:1.5 B4:.5 A4:2 |'
                'G#4:1 B4:1 D5:1 E5:1 | D5:1.5 C5:.5 B4:2 | C5:1 B4:1 A4:1 E4:1 | A4:3 r:1')
    mel_b = mel('F5:1.5 E5:.5 D5:1 A4:1 | B4:1.5 C5:.5 D5:2 | E5:1.5 D5:.5 C5:1 G4:1 | A4:1 C5:1 E5:2 |'
                'F5:1 E5:1 D5:1 F5:1 | E5:1.5 C5:.5 A4:2 | B4:1 C5:1 D5:1 G#4:1 | A4:3 r:1')
    bars_a = [m for m in mel_a]
    for bar in range(32):
        sec = (bar // 8) % 2
        name = (prog_a if sec == 0 else prog_b)[bar % 8]
        ch = CH[name]
        root, alt = BASS_ALT[name]
        b0 = bar * 4
        T.add('gtr', b0, guitar(root, T.beat * 1.9, decay=1.2, bright=0.4), 1.1)
        T.add('gtr', b0 + 2, guitar(alt, T.beat * 1.9, decay=1.2, bright=0.4), 1.0)
        for at, down, v in ((1, True, 0.8), (1.5, False, 0.45), (3, True, 0.8), (3.5, False, 0.45)):
            T.add('gtr', b0 + at, strum(ch[1:], T.beat * 0.55, down, vel=v, decay=1.0, bright=0.45), 0.9)
        T.add('bass', b0, upright(root - 12, T.beat * 1.8), 0.9)
        T.add('bass', b0 + 2, upright(alt - 12, T.beat * 1.8), 0.8)
        if bar >= 2:
            for b in range(4):
                T.add('drums', b0 + b, brush(0.9 if b % 2 else 0.5))
                T.add('drums', b0 + b + 0.5, shaker(0.6))
            T.add('drums', b0, kick(0.3, 0.3, 50, 0.45))
            T.add('drums', b0 + 2, kick(0.3, 0.3, 50, 0.35))
        # мелодия: баян, во втором проходе — с терцией ниже
        if bar >= 2:
            notes = mel_a if sec == 0 else mel_b
            ph = [x for x in notes if bar % 8 * 4 <= x[0] < bar % 8 * 4 + 4]
            for at, m, d in ph:
                if m is None:
                    continue
                T.add('reed', b0 + at - bar % 8 * 4, reed(m, d * T.beat * 0.95), 1.0)
                if bar >= 16:
                    T.add('reed', b0 + at - bar % 8 * 4, reed(m - (3 if (m % 12) in (0, 5, 7) else 4), d * T.beat * 0.95, 0.6), 1.0)
    _ = bars_a
    gtr = loop_fx(T.bus('gtr'), lambda s: A.reverb(s, 0.4, 0.18, 4000, 0.6))
    reedb = loop_fx(T.bus('reed'), lambda s: A.reverb(s, 0.55, 0.28, 3500, 0.8))
    mix = gtr + reedb + T.bus('bass') + T.bus('drums') * 0.8
    master(mix, 'radio_dvor')


# ================================================================ 2. Рок 80-х

def track_rock():
    """Ленинградский рок 80-х: чистая гитара с хорусом, бас восьмыми, перегруз в припеве."""
    T = Track(136, 32)
    prog = ['Em', 'C', 'G', 'D']
    riff = {'Em': [64, 71, 67, 71, 76, 71, 67, 71], 'C': [64, 72, 67, 72, 76, 72, 67, 72],
            'G': [62, 71, 67, 71, 74, 71, 67, 71], 'D': [62, 69, 66, 69, 74, 69, 66, 69]}
    bass_root = {'Em': 40, 'C': 36, 'G': 43, 'D': 38}
    pc_root = {'Em': 40, 'C': 48, 'G': 43, 'D': 50}
    chorus = mel('B4:1 B4:.5 A4:.5 G4:1 E4:1 | G4:1.5 A4:.5 B4:2 | D5:1 B4:.5 A4:.5 G4:1 B4:1 | A4:3 r:1 |'
                 'E5:1 D5:.5 B4:.5 G4:1 B4:1 | C5:1.5 B4:.5 G4:2 | B4:1 A4:.5 G4:.5 D4:1 G4:1 | F#4:2 A4:2')
    verse = mel('E4:1.5 E4:.5 G4:1 E4:1 | E4:1.5 D4:.5 E4:2 | D4:1 G4:1 B4:1 A4:1 | A4:2 F#4:2')
    for bar in range(32):
        name = prog[bar % 4]
        b0 = bar * 4
        sect = 'intro' if bar < 4 else 'verse' if bar < 12 else 'chorus' if bar < 20 else 'verse2' if bar < 28 else 'chorus'
        # чистая гитара — во всех частях, кроме припева потише
        for i, m in enumerate(riff[name]):
            T.add('clean', b0 + i * 0.5, guitar(m, T.beat * 0.9, decay=1.4, bright=0.6), 0.75 if sect == 'chorus' else 1.0)
        if bar >= 2:
            for i in range(8):
                T.add('bass', b0 + i * 0.5, bass(bass_root[name], T.beat * 0.45, 650, 'saw'), 1.0 if i % 2 == 0 else 0.8)
        if bar >= 4:
            T.add('drums', b0, kick(1.0, 0.3))
            T.add('drums', b0 + 2, kick(1.0, 0.3))
            T.add('drums', b0 + 2.5, kick(0.8, 0.25), 0.7)
            T.add('drums', b0 + 1, snare(190, 0.25), 0.8)
            T.add('drums', b0 + 3, snare(190, 0.25), 0.8)
            for i in range(8):
                T.add('drums', b0 + i * 0.5, hat(sect == 'chorus' and i % 2 == 1), 0.6)
            if bar % 4 == 0 and sect == 'chorus':
                T.add('drums', b0, crash(), 0.8)
            if bar % 8 == 3:
                for k, f in enumerate((180, 150, 120, 95)):
                    T.add('drums', b0 + 3 + k * 0.25, tom(f, 0.6, 0.3))
        if sect == 'chorus':
            r = pc_root[name]
            T.add('dist', b0, power_chord(r, T.beat * 1.5), 1.0)
            for k in range(4):
                T.add('dist', b0 + 2 + k * 0.5, power_chord(r, T.beat * 0.45, mute=0.06), 0.8)
            ph = [x for x in chorus if (bar - 12) % 8 * 4 <= x[0] < (bar - 12) % 8 * 4 + 4]
            for at, m, d in ph:
                if m is not None:
                    T.add('lead', b0 + at - (bar - 12) % 8 * 4, lead(m + 12, d * T.beat * 0.95, 1.0, 2600), 0.9)
        if sect == 'verse2':
            ph = [x for x in verse if bar % 4 * 4 <= x[0] < bar % 4 * 4 + 4]
            for at, m, d in ph:
                if m is not None:
                    T.add('lead', b0 + at - bar % 4 * 4, lead(m + 12, d * T.beat * 0.95, 0.8, 1800), 1.0)
    clean = T.bus('clean')
    d = int(0.012 * SR)
    chorus_fx = clean + np.roll(clean, d) * 0.6     # «хорус» — копия с задержкой
    clean = loop_fx(chorus_fx, lambda s: A.echo(s, T.beat * 0.75, 0.35, 0.3, 2500))
    lead_b = loop_fx(T.bus('lead'), lambda s: A.reverb(A.echo(s, T.beat * 0.75, 0.3, 0.3, 2500), 0.6, 0.3, 4000, 0.8))
    drums = loop_fx(T.bus('drums'), lambda s: A.reverb(s, 0.3, 0.15, 5000, 0.4))
    mix = clean * 0.8 + T.bus('dist') * 0.9 + lead_b + T.bus('bass') + drums * 0.85
    master(mix, 'radio_rock')


# ================================================================ 3. Дискотека 80-х

def track_disco():
    """Синти-поп конца 80-х: драм-машина, октавный бас, «струнный» синтезатор, грустная мелодия."""
    T = Track(122, 32)
    prog_a = [('Am', 57, 'm'), ('Dm', 50, 'm'), ('G', 55, 'M'), ('C', 48, 'M'), ('Am', 57, 'm'), ('Dm', 50, 'm'), ('E', 52, 'M'), ('Am', 57, 'm')]
    prog_b = [('F', 53, 'M'), ('G', 55, 'M'), ('Em', 52, 'm'), ('Am', 57, 'm'), ('F', 53, 'M'), ('G', 55, 'M'), ('E', 52, 'M'), ('E', 52, 'M')]
    mel_a = mel('A4:.5 C5:.5 E5:1 E5:.5 D5:.5 C5:1 | D5:.5 E5:.5 F5:1 E5:.5 D5:.5 A4:1 | B4:.5 C5:.5 D5:1 D5:.5 C5:.5 B4:1 |'
                'C5:.5 B4:.5 C5:1 G4:2 | A4:.5 C5:.5 E5:1 A5:1 G5:.5 E5:.5 | F5:1.5 E5:.5 D5:1 C5:1 |'
                'B4:1 C5:.5 D5:.5 E5:1 G#4:1 | A4:3 r:1')
    mel_b = mel('C5:1 A4:1 C5:.5 D5:.5 F5:1 | D5:1 B4:1 D5:.5 E5:.5 G5:1 | E5:1.5 D5:.5 B4:1 G4:1 | A4:1 C5:1 E5:2 |'
                'F5:1 E5:1 D5:1 C5:1 | D5:1 C5:1 B4:1 G4:1 | G#4:1 B4:1 E5:1 D5:1 | B4:2 G#4:2')
    for bar in range(32):
        sec = 'intro' if bar < 4 else 'a' if bar < 12 else 'b' if bar < 20 else 'a' if bar < 28 else 'outro'
        prog = prog_b if sec == 'b' else prog_a
        name, root, kind = prog[bar % 8]
        b0 = bar * 4
        T.add('str', b0, strings([m + 12 for m in triad(root, kind)], T.beat * 4, 0.9, 2200))
        for i in range(8):
            T.add('bass', b0 + i * 0.5, bass(root - 24 + (12 if i % 2 else 0), T.beat * 0.42, 1100, 'sq'), 0.85)
        for i in range(8):
            T.add('arp', b0 + i * 0.5, bell(triad(root, kind)[i % 3] + 24, T.beat * 0.5, 0.8))
        if sec != 'intro' or bar >= 2:
            for b in range(4):
                T.add('drums', b0 + b, kick(0.9, 0.3), 0.95)
            T.add('drums', b0 + 1, gated_snare(), 0.6)
            T.add('drums', b0 + 3, gated_snare(), 0.6)
            T.add('drums', b0 + 1, clap(), 0.35)
            T.add('drums', b0 + 3, clap(), 0.35)
            for i in range(8):
                T.add('drums', b0 + i * 0.5 + 0.0, hat(i % 2 == 1), 0.4 if i % 2 else 0.25)
        if bar % 8 == 0 and bar > 0:
            T.add('drums', b0, crash(), 0.6)
        if sec in ('a', 'b'):
            notes = mel_a if sec == 'a' else mel_b
            k = bar % 8
            ph = [x for x in notes if k * 4 <= x[0] < k * 4 + 4]
            for at, m, d in ph:
                if m is not None:
                    T.add('lead', b0 + at - k * 4, lead(m, d * T.beat * 0.92, 1.0, 2300), 1.0)
                    if bar >= 20:
                        T.add('lead', b0 + at - k * 4, lead(m - 12, d * T.beat * 0.92, 0.5, 1500), 1.0)
    lead_b = loop_fx(T.bus('lead'), lambda s: A.reverb(A.echo(s, T.beat * 0.75, 0.35, 0.35, 2500), 0.7, 0.3, 4000, 1.0))
    music = loop_fx(T.bus('str') + T.bus('arp') * 0.7, lambda s: A.reverb(s, 0.7, 0.3, 4000, 1.0))
    mix = music + lead_b + T.bus('bass') + T.bus('drums') * 0.9
    master(mix, 'radio_disco')


# ================================================================ 4. Духовой оркестр

def track_march():
    """Духовой оркестр в парке: марш си-бемоль мажор, туба, валторны на слабую долю, малый барабан."""
    T = Track(116, 32)
    prog_a = ['Bb', 'Bb', 'F7', 'F7', 'F7', 'F7', 'Bb', 'Bb']
    prog_b = ['Eb', 'Eb', 'Bb', 'Bb', 'C7', 'F7', 'Bb', 'F7']
    voic = {'Bb': [58, 62, 65], 'F7': [57, 60, 63, 65], 'Eb': [55, 58, 63], 'C7': [55, 58, 60, 64]}
    bassn = {'Bb': (34, 41), 'F7': (41, 36), 'Eb': (39, 46), 'C7': (36, 43)}
    mel_a = mel('F4:.5 Bb4:.5 D5:1 D5:.75 C5:.25 Bb4:1 | F5:1.5 D5:.5 Bb4:2 | C5:.5 D5:.5 Eb5:1 Eb5:.75 D5:.25 C5:1 |'
                'A4:1.5 Bb4:.5 C5:2 | Eb5:.5 D5:.5 C5:1 A4:.75 Bb4:.25 C5:1 | F5:1.5 Eb5:.5 C5:2 |'
                'D5:.5 C5:.5 Bb4:1 F4:1 D5:1 | Bb4:3 r:1')
    mel_b = mel('G4:1.5 Bb4:.5 Eb5:2 | D5:1 C5:1 Bb4:1 G4:1 | F4:1.5 Bb4:.5 D5:2 | C5:1 Bb4:1 A4:1 Bb4:1 |'
                'E5:1.5 D5:.5 C5:1 Bb4:1 | A4:1 C5:1 Eb5:1 C5:1 | Bb4:1 D5:1 F5:1 D5:1 | C5:2 A4:1 F4:1')
    scale = [nm(x) % 12 for x in ('Bb4', 'C5', 'D5', 'Eb5', 'F5', 'G5', 'A5')]

    def third_below(m):
        pc = m % 12
        if pc not in scale:
            return m - 4
        i = scale.index(pc)
        tgt = scale[(i - 2) % 7]
        d = (pc - tgt) % 12
        return m - d

    for bar in range(32):
        sec = (bar // 8) % 2
        name = (prog_a if sec == 0 else prog_b)[bar % 8]
        b0 = bar * 4
        r, f5 = bassn[name]
        for b in range(4):
            T.add('tuba', b0 + b, tuba(r if b % 2 == 0 else f5, T.beat * 0.6), 1.0)
            T.add('horn', b0 + b + 0.5, brass(voic[name], T.beat * 0.32, 0.8, 1800), 1.0)
        T.add('drums', b0, bass_drum(), 0.8)
        T.add('drums', b0 + 2, bass_drum(), 0.7)
        T.add('drums', b0, crash(0.5 if bar % 8 == 0 else 0.25), 0.7)
        T.add('drums', b0 + 2, crash(0.2), 0.6)
        for i in range(8):
            if i in (1, 3, 5, 7) or (i == 6 and bar % 2):
                T.add('drums', b0 + i * 0.5, snare(210, 0.18, 1.1), 0.5 if i % 2 else 0.35)
        if bar % 8 == 7:   # дробь перед новой фразой
            for k in range(16):
                T.add('drums', b0 + 2 + k * 0.125, snare(220, 0.1, 1.2), 0.18 + 0.02 * k)
        notes = mel_a if sec == 0 else mel_b
        k = bar % 8
        for at, m, d in [x for x in notes if k * 4 <= x[0] < k * 4 + 4]:
            if m is None:
                continue
            T.add('tpt', b0 + at - k * 4, trumpet(m, d * T.beat * 0.9), 1.0)
            if bar >= 8:
                T.add('tpt', b0 + at - k * 4, trumpet(third_below(m), d * T.beat * 0.9, 0.6), 1.0)
            if bar >= 16:
                T.add('tpt', b0 + at - k * 4, brass([m - 12], d * T.beat * 0.9, 0.9, 1500), 1.0)
    band = loop_fx(T.bus('tpt') + T.bus('horn') + T.bus('tuba'), lambda s: A.reverb(s, 0.8, 0.3, 3500, 1.2))
    drums = loop_fx(T.bus('drums'), lambda s: A.reverb(s, 0.8, 0.25, 4000, 1.2))
    master(band + drums * 0.8, 'radio_march')


# ================================================================ 5. Ресторан «Кавказ»

def track_kavkaz():
    """Ресторанный ансамбль: размер 6/8, кларнет и аккордеон, доули-барабан, ре минор."""
    T = Track(352, 48, bpb=6)      # «доля» здесь — восьмая
    prog = ['Dm', 'Dm', 'Gm', 'Gm', 'A7', 'A7', 'Dm', 'Dm']
    voic = {'Dm': [62, 65, 69], 'Gm': [62, 67, 70], 'A7': [61, 64, 67, 69]}
    bassn = {'Dm': (38, 45), 'Gm': (43, 38), 'A7': (45, 40)}
    ph_a = mel('A4:2 Bb4:1 A4:1 G4:1 F4:1 | E4:1 F4:1 G4:1 A4:3 | Bb4:2 C5:1 Bb4:1 A4:1 G4:1 | A4:1 Bb4:1 A4:1 G4:3 |'
               'C#5:2 D5:1 E5:1 D5:1 C#5:1 | Bb4:1 A4:1 G4:1 A4:3 | F4:1 G4:1 A4:1 Bb4:1 A4:1 G4:1 | F4:1 E4:1 C#4:1 D4:3')
    ph_b = mel('D5:1 E5:1 F5:1 E5:1 D5:1 C#5:1 | D5:3 A4:3 | G5:1 F5:1 E5:1 D5:1 C5:1 Bb4:1 | A4:3 G4:3 |'
               'E5:1 F5:1 E5:1 D5:1 C#5:1 Bb4:1 | A4:3 E5:3 | F5:1 E5:1 D5:1 C#5:1 D5:1 E5:1 | D5:6')
    plan = [('a', 'reed'), ('b', 'reed'), ('a', 'clar'), ('b', 'clar'), ('a', 'both'), ('b', 'both')]
    for bar in range(48):
        name = prog[bar % 8]
        b0 = bar * 6
        r, f5 = bassn[name]
        T.add('bass', b0, upright(r - 12 + 12, T.beat * 2.5), 1.0)
        T.add('bass', b0 + 3, upright(f5 - 12 + 12, T.beat * 2.5), 0.9)
        for at in (1, 2, 4, 5):
            T.add('acc', b0 + at, reed(voic[name][0], T.beat * 0.7, 0.4) + reed(voic[name][1], T.beat * 0.7, 0.4) + reed(voic[name][2], T.beat * 0.7, 0.4), 1.0)
        T.add('drums', b0, dum(), 1.0)
        T.add('drums', b0 + 2, tek(), 0.7)
        T.add('drums', b0 + 3, dum(), 0.8)
        T.add('drums', b0 + 5, tek(), 0.7)
        T.add('drums', b0 + 1, tek(), 0.25)
        T.add('drums', b0 + 4, tek(), 0.25)
        sec, who = plan[bar // 8]
        notes = ph_a if sec == 'a' else ph_b
        k = bar % 8
        for at, m, d in [x for x in notes if k * 6 <= x[0] < k * 6 + 6]:
            if m is None:
                continue
            dur = d * T.beat * 0.92
            if who in ('reed', 'both'):
                T.add('lead', b0 + at - k * 6, reed(m - (12 if who == 'both' else 0), dur, 1.2, 3000), 1.0)
            if who in ('clar', 'both'):
                T.add('lead', b0 + at - k * 6, clarinet(m, dur), 1.0)
    lead_b = loop_fx(T.bus('lead'), lambda s: A.reverb(s, 0.6, 0.3, 3500, 0.9))
    acc = loop_fx(T.bus('acc'), lambda s: A.reverb(s, 0.5, 0.2, 3000, 0.6))
    mix = lead_b + acc * 0.7 + T.bus('bass') + T.bus('drums') * 0.9
    master(mix, 'radio_kavkaz')


# ================================================================ 6. Новая тема меню

def track_menu2():
    """«Город Альфа»: зимняя синтезаторная баллада 80-х — пэды, электропиано, гулкий малый."""
    T = Track(84, 24)
    prog_a = [(48, 'm'), (44, 'M'), (51, 'M'), (46, 'M')]                       # Cm Ab Eb Bb
    prog_b = [(44, 'M'), (46, 'M'), (55, 'm'), (48, 'm'), (44, 'M'), (46, 'M'), (55, 'M'), (55, 'M')]   # Ab Bb Gm Cm Ab Bb G G
    mel_a = mel('G4:1.5 Eb4:.5 C5:2 | C5:1 Bb4:.5 Ab4:.5 G4:1 Eb4:1 | Bb4:1.5 G4:.5 Eb5:2 | D5:1 C5:.5 Bb4:.5 F4:2 |'
                'G4:1.5 Eb4:.5 C5:1 D5:1 | Eb5:1.5 D5:.5 C5:1 Ab4:1 | G4:1 Bb4:1 Eb5:1 D5:1 | D5:3 r:1')
    mel_b = mel('Eb5:2 C5:1 Ab4:1 | F5:2 D5:1 Bb4:1 | G5:1.5 F5:.5 D5:1 Bb4:1 | C5:3 G4:1 |'
                'Ab4:1 C5:1 Eb5:1 F5:1 | F5:1.5 Eb5:.5 D5:2 | B4:1 D5:1 G5:1 F5:1 | D5:2 B4:2')
    for bar in range(24):
        if bar < 4 or bar >= 20:
            root, kind = prog_a[bar % 4]
            sec = 'pad'
        elif bar < 12:
            root, kind = prog_a[bar % 4]
            sec = 'a'
        else:
            root, kind = prog_b[(bar - 12) % 8]
            sec = 'b'
        b0 = bar * 4
        ch = triad(root + 12, kind)
        T.add('pad', b0, pad(ch + [ch[0] + 12], T.beat * 4, 1600), 1.0)
        for i in range(8):
            T.add('keys', b0 + i * 0.5, epiano([ch[[0, 1, 2, 1, 0, 2, 1, 2][i]] + 12], T.beat * 1.2, 0.5 if i % 2 else 0.7))
        if sec != 'pad':
            T.add('bass', b0, bass(root - 12, T.beat * 2.8, 450, 'saw'), 1.0)
            T.add('bass', b0 + 3, bass(root - 12, T.beat * 0.9, 450, 'saw'), 0.8)
            T.add('drums', b0, kick(0.8, 0.4), 0.8)
            T.add('drums', b0 + 2.5, kick(0.7, 0.35), 0.5)
            T.add('drums', b0 + 1, gated_snare(), 0.55)
            T.add('drums', b0 + 3, gated_snare(), 0.55)
            for i in range(8):
                T.add('drums', b0 + i * 0.5, hat(False), 0.25)
            notes = mel_a if sec == 'a' else mel_b
            k = (bar - 4) % 8 if sec == 'a' else (bar - 12) % 8
            for at, m, d in [x for x in notes if k * 4 <= x[0] < k * 4 + 4]:
                if m is not None:
                    T.add('lead', b0 + at - k * 4, lead(m, d * T.beat * 0.95, 0.9, 1900), 1.0)
                    if sec == 'b':
                        T.add('lead', b0 + at - k * 4, strings([m - 12], d * T.beat, 1.4, 2000), 1.0)
        if bar in (3, 11, 19):
            T.add('fx', b0, riser(T.beat * 4), 0.5)
    music = loop_fx(T.bus('pad') + T.bus('keys') + T.bus('fx'), lambda s: A.reverb(s, 0.85, 0.35, 3500, 1.5))
    lead_b = loop_fx(T.bus('lead'), lambda s: A.reverb(A.echo(s, T.beat * 0.75, 0.35, 0.35, 2200), 0.85, 0.35, 3500, 1.5))
    drums = loop_fx(T.bus('drums'), lambda s: A.reverb(s, 0.6, 0.2, 4000, 0.8))
    mix = music + lead_b + T.bus('bass') + drums * 0.8
    master(mix, 'menu2')


# ================================================================ 7. Саундтрек погони

def track_chase():
    """Погоня / розыск: остинато баса шестнадцатыми, тамы, стаккато струнных, медь на акцентах."""
    T = Track(140, 24)
    prog = [(50, 'm'), (50, 'm'), (46, 'M'), (46, 'M'), (48, 'M'), (48, 'M'), (45, 'M'), (45, 'M')]   # Dm Bb C A
    for bar in range(24):
        root, kind = prog[bar % 8]
        b0 = bar * 4
        pat = [0, 0, 12, 0, 0, 12, 0, 10, 0, 0, 12, 0, 3, 5, 7, 10]
        for i, iv in enumerate(pat):
            T.add('bass', b0 + i * 0.25, bass(root - 24 + iv, T.beat * 0.22, 900, 'saw'), 1.0 if i % 4 == 0 else 0.75)
        for at, f, v in ((0, 90, 1.0), (0.75, 90, 0.7), (1.5, 120, 0.8), (2, 90, 1.0), (3, 150, 0.7), (3.5, 120, 0.8)):
            T.add('drums', b0 + at, tom(f, v, 0.45))
        T.add('drums', b0, kick(1.0, 0.35), 0.8)
        T.add('drums', b0 + 1, snare(180, 0.25), 0.6)
        T.add('drums', b0 + 3, snare(180, 0.25), 0.6)
        for i in range(16):
            T.add('drums', b0 + i * 0.25, hat(False), 0.25 if i % 2 else 0.4)
        ch = triad(root + 12, kind)
        for at in (0, 0.75, 1.5, 2.5, 3.0, 3.25):
            T.add('str', b0 + at, strings(ch, T.beat * 0.2, 1.8, 3000), 1.0)
        if bar % 4 == 0:
            T.add('brass', b0, brass(triad(root, kind), T.beat * 1.5, 1.4, 2200), 1.0)
            T.add('drums', b0, crash(), 0.7)
        if bar % 8 == 7:
            T.add('fx', b0, riser(T.beat * 4), 0.7)
        if bar >= 8:
            line = [root + 12, root + 15 if kind == 'm' else root + 16, root + 19, root + 17]
            T.add('lead', b0, trumpet(line[bar % 4] - 12, T.beat * 3.6, 0.9), 1.0)
    orch = loop_fx(T.bus('str') + T.bus('brass') + T.bus('lead') + T.bus('fx'), lambda s: A.reverb(s, 0.7, 0.3, 4000, 1.0))
    drums = loop_fx(T.bus('drums'), lambda s: A.reverb(s, 0.5, 0.2, 4000, 0.6))
    master(orch + T.bus('bass') + drums, 'score_chase', -14.0)


TRACKS = {'dvor': track_dvor, 'rock': track_rock, 'disco': track_disco, 'march': track_march,
          'kavkaz': track_kavkaz, 'menu2': track_menu2, 'chase': track_chase}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:]
    for k, f in TRACKS.items():
        if not only or k in only:
            f()
