"""Звуки «Города Альфа»: интерфейс, город, транспорт, люди, природа.

Все звуки синтезированы с нуля и пропущены через фильтры: верх срезан,
чтобы ничего не пищало. Запуск:  python3 gen_sfx.py <папка sounds/>
"""
import os
import sys

import numpy as np

import audiolib as A
from audiolib import lp, hp, bp, noise, t_, osc_f, perc, adsr, brown, pink, sine

SR = A.SR
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(5)


def buf(sec):
    return np.zeros(int(sec * SR))


def put(dst, at, src, gain=1.0):
    i = int(at * SR)
    m = min(len(src), len(dst) - i)
    if m > 0:
        dst[i:i + m] += src[:m] * gain
    return dst


def make_loop(x, fade=0.3):
    f = int(fade * SR)
    out = np.copy(x[:-f])
    r = np.linspace(0, 1, f)
    out[:f] = x[:f] * r + x[-f:] * (1 - r)
    return out


def finish(x, peak, top=6500, fin=0.002, fout=0.02, keep_start=False):
    x = lp(x, top)
    x = hp(x, 35)
    x = A.norm(x, peak)
    if not keep_start:
        x = A.fade_edges(x, fin, fout)
    return x


# ================================================================ интерфейс

def click():
    n = int(0.07 * SR)
    t = t_(n)
    x = bp(noise(n), 1200, 3200) * np.exp(-t * 500) * 0.5 + osc_f(np.full(n, 480.0) * (1 + 0.3 * np.exp(-t * 200)), 'sine') * np.exp(-t * 80)
    return finish(x, 0.45, 4000)


def marimba(f, length, vel=1.0):
    n = int(length * SR)
    t = t_(n)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 6) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 40) \
        + 0.15 * np.sin(2 * np.pi * f * 10 * t) * np.exp(-t * 120)
    return x * np.minimum(1, t / 0.001) * vel


def notify():
    x = buf(0.8)
    put(x, 0.0, marimba(392.0, 0.7, 0.8))
    put(x, 0.11, marimba(523.25, 0.65, 1.0))
    x = A.reverb(x, 0.4, 0.2, 3500, 0.3)
    return finish(x, 0.55, 4000)


def error():
    x = buf(0.36)
    for at, f in ((0.0, 233.0), (0.15, 175.0)):
        n = int(0.14 * SR)
        s = lp(A.sq(f, n) * 0.6 + A.saw(f, n) * 0.4, 800) * adsr(n, 0.005, 0.08, 0.6, 0.03)
        put(x, at, s)
    return finish(x, 0.55, 3000)


def clink(base, vel=1.0):
    n = int(0.35 * SR)
    t = t_(n)
    x = np.zeros(n)
    for k, (p, d) in enumerate(((1.0, 18), (2.32, 28), (3.73, 45))):
        x += np.sin(2 * np.pi * base * p * t + k) * np.exp(-t * d) / (1 + k * 0.7)
    return x * np.minimum(1, t / 0.0008) * vel


def coin():
    x = buf(0.55)
    put(x, 0.0, clink(1180, 1.0))
    put(x, 0.075, clink(1320, 0.7))
    put(x, 0.17, clink(1240, 0.45))
    put(x, 0.0, lp(noise(800), 500) * np.exp(-t_(800) * 60), 0.3)
    x = A.reverb(x, 0.3, 0.15, 4000, 0.3)
    return finish(x, 0.5, 4500)


def cash():
    """Советский кассовый аппарат: трещотка рычага, звонок, ящик."""
    x = buf(1.2)
    for k in range(9):
        n = int(0.02 * SR)
        put(x, k * 0.028, bp(noise(n), 700, 2600) * np.exp(-t_(n) * 260), 0.5 + 0.03 * k)
    n = int(0.9 * SR)
    t = t_(n)
    ring = np.zeros(n)
    for p, d, g in ((1.0, 3.0, 1.0), (2.0, 5.0, 0.4), (2.76, 7.0, 0.35), (4.1, 12.0, 0.15)):
        ring += np.sin(2 * np.pi * 980 * p * t) * np.exp(-t * d) * g
    ring *= 1 + 0.2 * np.sin(2 * np.pi * 14 * t) * np.exp(-t * 3)
    put(x, 0.27, ring, 0.45)
    n = int(0.25 * SR)
    put(x, 0.4, (lp(noise(n), 400) * 0.6 + np.sin(2 * np.pi * 105 * t_(n))) * np.exp(-t_(n) * 22), 0.6)
    x = A.reverb(x, 0.3, 0.15, 4000, 0.3)
    return finish(x, 0.6, 5000)


def bugle(f, length, vel=1.0):
    n = int(length * SR)
    t = t_(n)
    fr = np.full(n, f) * (1 - 0.03 * np.exp(-t * 40)) * (1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1))
    s = osc_f(fr, 'saw')
    e = np.exp(-t * 6)
    s = lp(s, 900) * (1 - 0.5 * e) + lp(s, 2800) * (0.5 + 0.5 * e)
    return s * adsr(n, 0.015, 0.2, 0.85, 0.05) * vel


def levelup():
    """Пионерский горн: соль-до-ми-соль."""
    x = buf(1.6)
    for at, f, d in ((0.0, 392.0, 0.12), (0.13, 523.25, 0.12), (0.26, 659.25, 0.12), (0.39, 784.0, 0.8)):
        put(x, at, bugle(f, d))
    for k in range(12):
        n = int(0.08 * SR)
        put(x, 0.39 + k * 0.05, bp(noise(n), 1500, 6000) * np.exp(-t_(n) * 40), 0.08)
    x = A.reverb(x, 0.6, 0.3, 3500, 0.8)
    return finish(x, 0.7, 4500)


def phone():
    """Звонок дискового телефона: молоточек бьёт по двум чашкам."""
    x = buf(1.5)
    for k in range(int(0.95 * 22)):
        f = 760.0 if k % 2 == 0 else 905.0
        n = int(0.12 * SR)
        t = t_(n)
        s = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.1 * t) * np.exp(-t * 30)) * np.exp(-t * 20)
        put(x, k / 22.0, s, 0.5)
    x = A.reverb(x, 0.3, 0.15, 3500, 0.4)
    return finish(x, 0.5, 3600)


def radio_tune():
    n = int(0.55 * SR)
    t = t_(n)
    hiss = bp(noise(n), 400, 3200) * 0.4
    whistle = osc_f(900 - 650 * t / 0.55, 'sine') * 0.25
    crack = np.zeros(n)
    idx = rng.integers(0, n, 40)
    crack[idx] = rng.standard_normal(40)
    x = (hiss + whistle + lp(crack, 2500) * 0.8) * np.sin(np.pi * t / 0.55) ** 0.7
    return finish(x, 0.4, 3500)


# ================================================================ люди

def step(seed):
    r = np.random.default_rng(seed)
    x = buf(0.16)
    for at, v in ((0.0, 1.0), (0.032 + r.random() * 0.01, 0.45)):
        n = int(0.09 * SR)
        t = t_(n)
        s = lp(r.standard_normal(n), 1300 + r.random() * 400) * np.exp(-t * 70) + np.sin(2 * np.pi * (85 + r.random() * 20) * t) * np.exp(-t * 60) * 0.5
        put(x, at, s * np.minimum(1, t / 0.002), v)
    return finish(x, 0.8, 3000)


def hit():
    n = int(0.28 * SR)
    t = t_(n)
    x = lp(noise(n), 900) * np.exp(-t * 35) * 0.8 + osc_f(110 * (1 + 0.6 * np.exp(-t * 50)), 'sine') * np.exp(-t * 22) \
        + bp(noise(n), 1500, 3000) * np.exp(-t * 250) * 0.25
    return finish(x, 0.85, 3500)


def swing():
    n = int(0.3 * SR)
    t = t_(n)
    x = hp(A.sweep_lp(noise(n), 350, 1500, 12), 250) * np.sin(np.pi * t / 0.3) ** 2
    return finish(x, 0.45, 3000)


def eat():
    x = buf(1.0)
    for at in (0.0, 0.32, 0.62):
        n = int(0.24 * SR)
        t = t_(n)
        grains = np.zeros(n)
        idx = rng.integers(0, n // 2, 70)
        grains[idx] = rng.standard_normal(70)
        s = bp(grains, 500, 2400) * 1.8 + bp(noise(n), 300, 1500) * 0.25
        put(x, at, s * np.exp(-t * 10))
    return finish(x, 0.6, 3200)


def drink():
    x = buf(1.05)
    for at in (0.05, 0.38, 0.7):
        n = int(0.22 * SR)
        t = t_(n)
        g = osc_f(170 + 230 * (1 - np.exp(-t * 25)), 'sine') * np.exp(-t * 18) * 0.7 + lp(noise(n), 500) * np.exp(-t * 28) * 0.4
        put(x, at, g)
        for k in range(3):
            m = int(0.04 * SR)
            put(x, at + 0.06 + k * 0.035, np.sin(2 * np.pi * (380 + 90 * k) * t_(m)) * np.exp(-t_(m) * 70), 0.25)
    return finish(x, 0.6, 2500)


def heal():
    n = int(1.1 * SR)
    t = t_(n)
    x = np.zeros(n)
    for k, f in enumerate((261.63, 329.63, 392.0, 523.25)):
        e = np.clip((t - k * 0.06) / 0.15, 0, 1) * np.exp(-np.maximum(t - k * 0.06, 0) * 2.2)
        x += (np.sin(2 * np.pi * f * t) + 0.2 * np.sin(4 * np.pi * f * t)) * e
    x = A.reverb(x, 0.5, 0.25, 3000, 0.5)
    return finish(x, 0.55, 3000)


# ================================================================ оружие

def gunshot(heavy=False):
    L = 1.8 if heavy else 1.4
    n = int(0.6 * SR)
    t = t_(n)
    crack = hp(noise(n), 900) * np.exp(-t * (140 if heavy else 190))
    body = lp(noise(n), 1600) * np.exp(-t * (18 if heavy else 28))
    boom = osc_f((48 if heavy else 62) + 90 * np.exp(-t * 35), 'sine') * np.exp(-t * (7 if heavy else 11))
    s = np.tanh((crack * 0.9 + body * 0.9 + boom * (1.3 if heavy else 0.9)) * 2.2)
    x = buf(L)
    put(x, 0, s)
    for d, g in ((0.13, 0.28), (0.29, 0.16), (0.47, 0.08)):      # эхо от домов
        put(x, d, lp(s, 1400), g)
    x = A.reverb(x, 0.8, 0.3, 3000, 0.8)
    return finish(x, 0.92, 7000, 0.0005, 0.08)


# ================================================================ транспорт

def horn():
    """Гудок «Жигулей»: два тона, бархатный, без визга."""
    n = int(0.55 * SR)
    t = t_(n)
    x = np.zeros(n)
    for f in (405.0, 505.0):
        fr = np.full(n, f) * (1 + 0.002 * np.sin(2 * np.pi * 30 * t))
        x += osc_f(fr, 'saw') * 0.6 + osc_f(fr, 'sq') * 0.3
    x = bp(x, 250, 2200) + lp(x, 600) * 0.4
    x *= adsr(n, 0.012, 0.05, 0.9, 0.04)
    return finish(x, 0.75, 2600)


def train_horn():
    """Тифон тепловоза: низкое трезвучие с раскатом по вокзалу."""
    n = int(2.0 * SR)
    t = t_(n)
    x = np.zeros(n)
    for f in (196.0, 247.0, 294.0):
        fr = np.full(n, f) * (1 + 0.003 * np.sin(2 * np.pi * 4.5 * t)) * (1 - 0.02 * np.exp(-t * 6))
        x += osc_f(fr, 'saw')
    x = lp(x, 1500) * adsr(n, 0.15, 0.4, 0.85, 0.35)
    x = A.reverb(x, 0.95, 0.4, 2500, 1.8)
    return finish(x, 0.85, 3000, 0.02, 0.2)


def vibraphone(f, length, vel=1.0):
    n = int(length * SR)
    t = t_(n)
    x = (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 12)) * np.exp(-t * 1.6)
    return x * (1 + 0.25 * np.sin(2 * np.pi * 5 * t)) * np.minimum(1, t / 0.002) * vel


def station():
    """Вокзальный сигнал перед объявлением: «динь-дон-дин» на виброфоне."""
    x = buf(3.2)
    for k, f in enumerate((392.0, 329.63, 261.63)):
        put(x, k * 0.45, vibraphone(f, 2.4))
    x = A.reverb(x, 0.9, 0.4, 3000, 1.5)
    return finish(x, 0.7, 3500, 0.002, 0.3)


def whistle():
    """Милицейский свисток: два коротких сигнала с трелью шарика."""
    x = buf(0.9)
    for at, ln in ((0.0, 0.28), (0.4, 0.42)):
        n = int(ln * SR)
        t = t_(n)
        fr = 2150 * (1 + 0.035 * np.sin(2 * np.pi * 27 * t))
        s = osc_f(fr, 'sine') * (0.65 + 0.35 * np.sin(2 * np.pi * 27 * t)) + bp(noise(n), 1800, 4000) * 0.12
        put(x, at, s * adsr(n, 0.02, 0.1, 0.9, 0.04))
    x = A.reverb(x, 0.6, 0.25, 3000, 0.5)
    return finish(x, 0.45, 4200)


def car_door():
    x = buf(0.55)
    n = int(0.02 * SR)
    put(x, 0.0, bp(noise(n), 1800, 3800) * np.exp(-t_(n) * 350), 0.3)
    n = int(0.45 * SR)
    t = t_(n)
    thunk = osc_f(85 * (1 + 0.4 * np.exp(-t * 40)), 'sine') * np.exp(-t * 18) + lp(noise(n), 700) * np.exp(-t * 26) * 0.8 \
        + (np.sin(2 * np.pi * 240 * t) + 0.6 * np.sin(2 * np.pi * 390 * t)) * np.exp(-t * 14) * 0.15
    put(x, 0.015, thunk)
    return finish(x, 0.8, 3000)


def engine_start(scooter=False):
    """Стартер крутит («вжу-вжу-вжу»), мотор схватывает и встаёт на холостые."""
    L = 2.0
    x = buf(L)
    crank = 0.7 if not scooter else 0.45
    n = int(crank * SR)
    t = t_(n)
    rate = 6.5 if not scooter else 9.0
    cyc = 0.5 + 0.5 * np.sin(2 * np.pi * rate * t) ** 2
    whine = lp(osc_f(np.full(n, 150.0 if not scooter else 210.0) * (0.9 + 0.1 * cyc), 'saw'), 800) * 0.4
    put(x, 0, (whine + lp(noise(n), 300) * 0.5) * cyc * np.minimum(1, t / 0.03))
    m = int((L - crank) * SR)
    t = t_(m)
    base = 26.0 if not scooter else 42.0
    f = base + base * 1.6 * np.exp(-((t - 0.25) / 0.18) ** 2) * (t < 0.6) + base * 0.6 * np.exp(-t * 3)
    fire = osc_f(f, 'saw') * 0.6 + osc_f(f * 2, 'sq') * 0.25 + osc_f(f * 0.5, 'sine') * 0.5
    fire *= 1 + 0.25 * rng.standard_normal(m).cumsum() / np.sqrt(np.arange(1, m + 1))
    fire = lp(fire, 520 if not scooter else 900)
    env = np.minimum(1, t / 0.04) * (0.55 + 0.45 * np.exp(-t * 2.5)) * np.clip((L - crank - t) / 0.35, 0, 1)
    put(x, crank, fire * env)
    return finish(x, 0.8, 3000)


def lock():
    """Центральный замок: два щелчка и короткий «пик» сигнализации."""
    x = buf(0.5)
    for at in (0.0, 0.045):
        n = int(0.05 * SR)
        t = t_(n)
        put(x, at, (bp(noise(n), 900, 3000) * np.exp(-t * 160) + np.sin(2 * np.pi * 160 * t) * np.exp(-t * 60) * 0.6), 0.8)
    n = int(0.09 * SR)
    t = t_(n)
    beep = lp(A.sq(880.0, n) * 0.5 + np.sin(2 * np.pi * 880 * t), 2200) * adsr(n, 0.005, 0.05, 0.8, 0.02)
    put(x, 0.16, beep, 0.35)
    return finish(x, 0.7, 3500)


# ================================================================ дом

def door():
    """Дверь подъезда: скрип пружины и тяжёлый хлопок с гулом лестницы."""
    x = buf(1.3)
    n = int(0.42 * SR)
    t = t_(n)
    fr = 38 + 22 * np.sin(np.pi * t / 0.42)
    stick = osc_f(fr, 'saw')
    creak = bp(stick, 500, 1700) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * np.sin(np.pi * t / 0.42)
    put(x, 0.0, creak, 0.35)
    n = int(0.7 * SR)
    t = t_(n)
    slam = lp(noise(n), 320) * np.exp(-t * 22) * 1.3 + osc_f(70 * (1 + 0.5 * np.exp(-t * 40)), 'sine') * np.exp(-t * 14)
    for p, g in ((180, 0.2), (410, 0.14), (690, 0.08)):
        slam += np.sin(2 * np.pi * p * t) * np.exp(-t * 8) * g
    put(x, 0.48, slam)
    x = A.reverb(x, 0.7, 0.35, 2500, 0.8)
    return finish(x, 0.85, 3500)


# ================================================================ природа и город

def pigeon():
    x = buf(1.6)
    for at, ln in ((0.0, 0.45), (0.55, 0.75)):
        n = int(ln * SR)
        t = t_(n)
        f = 330 - 50 * t / ln + 25 * np.sin(np.pi * t / ln)
        s = osc_f(f, 'sine') + 0.35 * osc_f(f * 2, 'sine')
        s *= 0.55 + 0.45 * np.sin(2 * np.pi * 34 * t)
        put(x, at, bp(s, 200, 1200) * np.sin(np.pi * t / ln) ** 1.5)
    return finish(x, 0.6, 1800)


def sparrow():
    x = buf(0.6)
    for k in range(3):
        n = int(0.06 * SR)
        t = t_(n)
        f = 2600 + 700 * np.sin(np.pi * t / 0.06)
        put(x, k * 0.13 + rng.random() * 0.03, osc_f(f, 'sine') * np.sin(np.pi * t / 0.06) ** 2, 1 - 0.2 * k)
    return finish(x, 0.3, 4000)


def crow():
    x = buf(1.1)
    for at in (0.0, 0.45):
        n = int(0.3 * SR)
        t = t_(n)
        f = 540 * (1 - 0.15 * t / 0.3) * (1 + 0.02 * rng.standard_normal(n).cumsum() / np.sqrt(np.arange(1, n + 1)))
        s = osc_f(f, 'saw') + noise(n) * 0.3
        s = bp(s, 650, 1700) + bp(s, 1900, 2600) * 0.4
        put(x, at, s * np.sin(np.pi * np.minimum(1, t / 0.3)) ** 0.6)
    x = A.reverb(x, 0.6, 0.3, 2500, 0.6)
    return finish(x, 0.5, 2800)


def dog():
    """Собака лает где-то во дворах — далеко, приглушённо."""
    x = buf(1.6)
    for at in (0.0, 0.32):
        n = int(0.16 * SR)
        t = t_(n)
        f = 430 * (1 - 0.25 * t / 0.16)
        s = osc_f(f, 'saw') + noise(n) * 0.4
        s = bp(s, 400, 1500) * np.sin(np.pi * t / 0.16) ** 0.5
        put(x, at, s)
    x = lp(x, 1400)
    x = A.reverb(x, 0.9, 0.55, 1800, 1.0)
    return finish(x, 0.5, 1600)


def crickets():
    L = 4.3
    x = buf(L + 0.3)
    for base, per, gain in ((3150.0, 0.47, 1.0), (3420.0, 0.61, 0.7)):
        at = rng.random() * 0.2
        while at < L:
            for k in range(3):
                n = int(0.018 * SR)
                t = t_(n)
                put(x, at + k * 0.03, np.sin(2 * np.pi * base * t) * np.sin(np.pi * t / 0.018) ** 2, gain)
            at += per * (0.9 + 0.2 * rng.random())
    x = make_loop(x, 0.3)
    return A.norm(lp(x, 4200), 0.3)


def rumble():
    """Гул города: низкий шум и проезжающие вдалеке машины."""
    L = 8.0
    n = int((L + 0.6) * SR)
    t = t_(n)
    x = lp(brown(n), 320) * 0.8
    traffic = bp(noise(n), 110, 650)
    sw = np.zeros(n)
    for c in (1.2, 3.6, 5.1, 7.3):
        sw += np.exp(-((t - c) / 0.9) ** 2)
    x += traffic * (0.15 + 0.5 * sw) * 0.35
    x = make_loop(x, 0.6)
    return A.norm(x, 0.7)


def rain():
    L = 6.0
    n = int((L + 0.4) * SR)
    x = bp(pink(n), 350, 5500) * 0.5 + lp(noise(n), 900) * 0.25
    drops = np.zeros(n)
    idx = rng.integers(0, n, int(L * 45))
    drops[idx] = rng.standard_normal(len(idx))
    x += bp(drops, 1200, 3500) * 0.9
    x = make_loop(x, 0.4)
    return A.norm(lp(x, 5500), 0.6)


def thunder():
    L = 5.0
    n = int(L * SR)
    t = t_(n)
    crack = hp(noise(n), 400) * np.exp(-np.maximum(t - 0.08, 0) * 9) * (t > 0.08) * 0.5
    roll = lp(brown(n), 220) * 1.6 + bp(noise(n), 70, 450) * 0.5
    amp = np.zeros(n)
    for c, w, g in ((0.3, 0.35, 1.0), (1.1, 0.5, 0.8), (2.0, 0.7, 0.6), (3.0, 0.9, 0.35)):
        amp += np.exp(-((t - c) / w) ** 2) * g
    x = lp(crack, 2500) + roll * amp
    x = A.reverb(x, 0.9, 0.35, 1500, 1.0)
    return finish(x, 0.9, 2800, 0.01, 0.5)


def siren():
    """Сирена милиции: плавный вой вверх-вниз (СГУ), бесшовная петля."""
    L = 2.4
    n = int(L * SR)
    t = t_(n)
    f = 780 - 260 * np.cos(2 * np.pi * t / L)
    # подгоняем фазу, чтобы за петлю укладывалось целое число периодов
    total = np.sum(f) / SR
    f *= round(total) / total
    s = osc_f(f, 'saw') * 0.5 + osc_f(f, 'sq') * 0.3 + osc_f(f, 'sine')
    s = lp(s, 2200)
    return A.norm(s, 0.6)



def firework():
    """Салют: свист взлетающей ракеты, хлопок и треск рассыпающихся искр."""
    L = 3.2
    x = buf(L)
    n = int(0.9 * SR)
    t = t_(n)
    f = 900 + 900 * t / 0.9
    wh = bp(noise(n), 700, 2600) * 0.25 + osc_f(f, 'sine') * 0.08
    put(x, 0.0, wh * np.minimum(1, t * 6) * (1 - t / 0.9) ** 0.5)
    n = int(2.2 * SR)
    t = t_(n)
    bang = lp(noise(n), 900) * np.exp(-t * 7) * 1.4 + lp(brown(n), 160) * np.exp(-t * 3) * 2.0
    put(x, 0.95, bang)
    for k in range(70):
        at = 1.05 + rng.uniform(0, 1.6)
        m = int(0.03 * SR)
        put(x, at, hp(noise(m), 1500) * np.exp(-t_(m) * 120), rng.uniform(0.05, 0.18))
    x = A.reverb(x, 0.8, 0.3, 2500, 0.8)
    return finish(x, 0.85, 5000, 0.01, 0.3)


def beep():
    """Светофор старта гонки: короткий электронный «пик»."""
    n = int(0.22 * SR)
    t = t_(n)
    s = sine(880, n) * 0.6 + osc_f(np.full(n, 880.0), 'sq') * 0.12
    return finish(s * np.exp(-t * 6) * np.minimum(1, t * 200), 0.6, 4000)


SOUNDS = {
    'click': click, 'notify': notify, 'error': error, 'coin': coin, 'cash': cash, 'levelup': levelup,
    'phone': phone, 'radio_tune': radio_tune,
    'step': lambda: step(1), 'step2': lambda: step(2), 'step3': lambda: step(3),
    'hit': hit, 'swing': swing, 'eat': eat, 'drink': drink, 'heal': heal,
    'shot': lambda: gunshot(False), 'shot_heavy': lambda: gunshot(True),
    'horn': horn, 'train_horn': train_horn, 'station': station, 'whistle': whistle,
    'car_door': car_door, 'lock': lock, 'engine_start': lambda: engine_start(False), 'scooter_start': lambda: engine_start(True),
    'door': door, 'pigeon': pigeon, 'sparrow': sparrow, 'crow': crow, 'dog': dog,
    'crickets': crickets, 'rumble': rumble, 'rain': rain, 'thunder': thunder, 'siren': siren,
    'firework': firework, 'beep': beep,
}

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[2:]
    for name, fn in SOUNDS.items():
        if only and name not in only:
            continue
        x = fn()
        A.write_wav(os.path.join(OUT, name + '.wav'), x)
        print(name, round(len(x) / SR, 2), 's')
