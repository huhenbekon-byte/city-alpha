"""Общие кирпичики синтеза для музыки и звуков игры (numpy + scipy, без сэмплов).

Всё оригинальное: инструменты собираются из осцилляторов, шума и фильтров.
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

SR = 32000
rng = np.random.default_rng(11)


def set_rate(sr):
    global SR
    SR = sr


def mf(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def nm(s):
    """'A4' / 'C#5' / 'Bb3' → MIDI."""
    base = NOTE[s[0]]
    i = 1
    while i < len(s) and s[i] in '#b':
        base += 1 if s[i] == '#' else -1
        i += 1
    return base + 12 * (int(s[i:]) + 1)


def mel(text):
    """'E4:1 C5:.5 r:1 | ...' → [(начало в долях, midi или None, длительность)]."""
    out = []
    t = 0.0
    for tok in text.replace('|', ' ').split():
        n, d = tok.split(':')
        d = float(d)
        out.append((t, None if n == 'r' else nm(n), d))
        t += d
    return out


# ---------------------------------------------------------------- фильтры

def _sos(kind, fc, order=2):
    if isinstance(fc, (list, tuple)):
        w = [min(f, SR * 0.45) / (SR / 2) for f in fc]
    else:
        w = min(fc, SR * 0.45) / (SR / 2)
    return butter(order, w, kind, output='sos')


def lp(x, fc, order=2):
    return sosfilt(_sos('low', fc, order), x)


def hp(x, fc, order=2):
    return sosfilt(_sos('high', fc, order), x)


def bp(x, lo, hi, order=2):
    return sosfilt(_sos('band', [lo, hi], order), x)


def sweep_lp(x, f_start, f_end, steps=24):
    """Фильтр с движущейся частотой среза (кусочно, с перекрытием)."""
    n = len(x)
    y = np.zeros(n)
    seg = max(1, n // steps)
    for k in range(steps + 1):
        a = k * seg
        if a >= n:
            break
        b = min(n, a + seg * 2)
        f = f_start * (f_end / f_start) ** (k / steps)
        part = lp(x[max(0, a - seg):b], f)[a - max(0, a - seg):]
        w = np.ones(b - a)
        ramp = min(seg, b - a)
        w[:ramp] = np.linspace(0, 1, ramp) if k > 0 else 1
        if b < n:
            w[-ramp:] *= np.linspace(1, 0, ramp)
        y[a:b] += part[:b - a] * w
    return y


# ---------------------------------------------------------------- генераторы

def t_(n):
    return np.arange(n) / SR


def sine(f, n, ph=0.0):
    return np.sin(2 * np.pi * f * t_(n) + ph)


def saw(f, n, ph=0.0):
    return 2.0 * ((t_(n) * f + ph) % 1.0) - 1.0


def sq(f, n, duty=0.5):
    return np.where((t_(n) * f) % 1.0 < duty, 1.0, -1.0)


def osc_f(freq, kind='sine'):
    """Осциллятор с переменной частотой (массив)."""
    ph = np.cumsum(freq) / SR
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    if kind == 'saw':
        return 2.0 * (ph % 1.0) - 1.0
    if kind == 'sq':
        return np.where(ph % 1.0 < 0.5, 1.0, -1.0)
    if kind == 'tri':
        return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0
    raise ValueError(kind)


def noise(n):
    return rng.standard_normal(n)


def brown(n):
    x = np.cumsum(rng.standard_normal(n))
    x = hp(x, 20)
    return x / (np.max(np.abs(x)) + 1e-9)


def pink(n):
    # приблизительно: сумма нескольких отфильтрованных белых шумов
    w = rng.standard_normal(n)
    return lp(w, 300) * 2.2 + lp(w, 1500) * 0.9 + lp(w, 6000) * 0.4 + w * 0.1


def adsr(n, a=0.005, d=0.1, s=0.7, r=0.05):
    t = t_(n)
    length = n / SR
    e = np.where(t < a, t / max(a, 1e-5), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-5)))
    rel = np.clip((length - t) / max(r, 1e-5), 0, 1)
    return e * rel


def perc(n, a=0.002, decay=0.2):
    t = t_(n)
    return np.minimum(1, t / max(a, 1e-5)) * np.exp(-t / max(decay, 1e-5))


def fade_edges(x, fin=0.003, fout=0.01):
    n = len(x)
    a = min(n, int(fin * SR))
    b = min(n, int(fout * SR))
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


# ---------------------------------------------------------------- пространство

def reverb(x, size=0.6, mix=0.25, damp=3500, tail=1.0):
    """Простой ревербератор Шрёдера: параллельные гребёнки + последовательные all-pass."""
    combs = [0.0297, 0.0371, 0.0411, 0.0437, 0.0503, 0.0571]
    pad_n = int(tail * SR)
    src = np.concatenate([x, np.zeros(pad_n)])
    wet = np.zeros(len(src))
    g = 0.70 + 0.25 * size
    for d in combs:
        k = int(d * SR * (0.6 + 0.8 * size))
        a = np.zeros(k + 1)
        a[0] = 1.0
        a[k] = -g
        wet += lfilter([1.0], a, src)
    wet = lp(wet, damp)
    for d, gg in ((0.0050, 0.7), (0.0017, 0.7)):
        k = int(d * SR)
        b = np.zeros(k + 1)
        b[0] = -gg
        b[k] = 1.0
        a = np.zeros(k + 1)
        a[0] = 1.0
        a[k] = -gg
        wet = lfilter(b, a, wet)
    wet = hp(wet, 120)
    wet /= (np.max(np.abs(wet)) + 1e-9)
    wet *= np.max(np.abs(x)) + 1e-9
    return src * (1 - mix * 0.5) + wet * mix


def echo(x, delay_s, fb=0.35, mix=0.3, damp=3000):
    d = int(delay_s * SR)
    y = np.copy(x)
    tap = np.copy(x)
    for k in range(1, 6):
        tap = lp(tap, damp)
        if d * k >= len(x):
            break
        y[d * k:] += tap[:-d * k] * (fb ** k) * mix / fb
    return y


# ---------------------------------------------------------------- вывод

def norm(x, peak=0.9):
    x = x - np.mean(x)
    return x / (np.max(np.abs(x)) + 1e-9) * peak


def write_wav(path, x, sr=None):
    sr = sr or SR
    raw = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(raw.tobytes())


def write_ogg(path, x, q=2):
    tmp = path[:-4] + '.tmp.wav'
    write_wav(tmp, x)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-c:a', 'libvorbis', '-q:a', str(q), path], check=True)
    os.remove(tmp)
