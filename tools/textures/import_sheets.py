"""Текстуры города из листов-раскладок (картинки из нейросети автора игры, 3 листа):

  city1.jpg    — 13 клеток на белом: панели фасада, балкон, подъезд, газон, земля, кора берёзы, витрина,
                 плитка, красный металл, пустырь
  city2.jpg    — 18 клеток: листва, камыши, кусты, колонка АЗС, вывески, кора тополя, тропинка,
                 бетонная плита, вода, профлист, асфальт двора
  interior.jpg — 9 клеток: обои, паркет, линолеум, стена больницы, кафель, деревянные панели, ковёр,
                 потолок, терраццо

Клетки вырезаются по рамкам (BOXES), органические текстуры делаются бесшовными (смешивание со сдвигом
на полкартинки), фасады собираются из одного модуля «панель с окном» в сетку 4×4 (как ждёт city_builder).

Запуск из корня проекта:  python3 tools/textures/import_sheets.py <папка с city1.jpg, city2.jpg, interior.jpg>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter

OUT = 'textures'

BOXES = {
    'city1': [(26, 20, 278, 255), (311, 21, 556, 254), (592, 20, 828, 254), (900, 19, 1078, 255),
              (1140, 19, 1384, 255), (26, 268, 278, 502), (312, 267, 556, 503), (588, 267, 832, 502),
              (864, 266, 1109, 503), (1141, 267, 1383, 502), (312, 515, 556, 752), (588, 516, 832, 752),
              (864, 515, 1109, 752)],
    'city2': [(17, 17, 240, 254), (246, 17, 471, 254), (477, 17, 700, 254), (708, 17, 930, 254),
              (937, 17, 1162, 255), (1168, 17, 1392, 254), (17, 264, 240, 504), (245, 264, 470, 503),
              (476, 265, 701, 503), (707, 264, 930, 503), (937, 264, 1162, 504), (1167, 264, 1392, 504),
              (16, 515, 241, 752), (246, 515, 471, 752), (476, 515, 701, 752), (707, 515, 933, 751),
              (937, 515, 1161, 752), (1168, 515, 1392, 752)],
    'interior': [(x0, y0, x1, y1) for (y0, y1) in [(0, 255), (257, 511), (513, 768)]
                 for (x0, x1) in [(0, 468), (470, 938), (940, 1408)]],
}


def tile(sheets, name, i, inset=3):
    x0, y0, x1, y1 = BOXES[name][i]
    return np.asarray(sheets[name].crop((x0 + inset, y0 + inset, x1 - inset, y1 - inset))).astype(float)


def smooth(t):
    t = np.clip(t, 0, 1)
    return t * t * (3 - 2 * t)


def seamless(a, f=0.3, axes=(0, 1)):
    """Края картинки берутся из её же середины (сдвиг на полкартинки) — стык не виден при повторе."""
    h, w = a.shape[:2]
    r = a
    wy = np.ones(h)
    wx = np.ones(w)
    if 0 in axes:
        r = np.roll(r, h // 2, 0)
        k = np.minimum(np.arange(h), h - 1 - np.arange(h))
        wy = smooth(k / (f * h))
    if 1 in axes:
        r = np.roll(r, w // 2, 1)
        k = np.minimum(np.arange(w), w - 1 - np.arange(w))
        wx = smooth(k / (f * w))
    wgt = np.minimum.outer(wy, wx)[..., None]
    return a * wgt + r * (1 - wgt)


def to_img(a, size=None, sharpen=True):
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    if size:
        im = im.resize(size, Image.LANCZOS)
        if sharpen:
            im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=60, threshold=2))
    return im


def save(im, path):
    full = os.path.join(OUT, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    im.convert('RGB').save(full, optimize=True)
    print('  ', path, im.size)


def facade(module, win, name, rng, jitter=0.04):
    """Сетка 4×4 модулей (4 окна × 4 этажа) + маска окон для ночи."""
    m = to_img(module, (256, 256))
    a = np.asarray(m).astype(float)
    out = np.zeros((1024, 1024, 3))
    for r in range(4):
        for c in range(4):
            b = a[:, ::-1] if rng.random() < 0.5 else a
            out[r * 256:(r + 1) * 256, c * 256:(c + 1) * 256] = b * (1 + rng.uniform(-jitter, jitter))
    save(to_img(out), name + '.png')
    glow = np.zeros((512, 512), np.uint8)
    x0, y0, x1, y1 = [int(v * 128) for v in win]
    for r in range(4):
        for c in range(4):
            glow[r * 128 + y0:r * 128 + y1, c * 128 + x0:c * 128 + x1] = 255
    save(Image.fromarray(glow).convert('RGB'), name + '_glow.png')


def period(a, axis, lo=12, hi=None):
    """Шаг повторяющегося рисунка (плитка, доски, паркет) по оси — по автокорреляции яркости."""
    g = a.mean(2)
    prof = g.mean(1 - axis)
    prof = prof - prof.mean()
    n = len(prof)
    hi = hi or n // 2
    ac = np.array([np.dot(prof[:-k], prof[k:]) / (n - k) for k in range(lo, hi)])
    return lo + int(np.argmax(ac))


def periodic(a, axes=(0, 1), lo=12):
    """Обрезать до целого числа периодов рисунка — повтор без шва и без «двоения»."""
    for ax in axes:
        p = period(a, ax, lo)
        n = a.shape[ax] // p
        a = a[:n * p] if ax == 0 else a[:, :n * p]
    return a


def key_black(a, lo=14, hi=40):
    """Предмет на чёрном фоне → (rgb, альфа)."""
    al = smooth((a.max(2) - lo) / (hi - lo))
    return a, al


def foliage(sheets, items, base_col, name, rng, n=46, size=512):
    """Плотная листва: десятки веток с листьями вразброс поверх тёмной зелени, бесшовно."""
    out = np.ones((size, size, 3)) * np.array(base_col, float)
    clusters = []
    for nm, i in items:
        rgb, al = key_black(tile(sheets, nm, i, 6))
        ys, xs = np.nonzero(al > 0.5)
        rgb, al = rgb[ys.min():ys.max(), xs.min():xs.max()], al[ys.min():ys.max(), xs.min():xs.max()]
        clusters.append((rgb, al))
    for _ in range(n):
        rgb, al = clusters[rng.integers(len(clusters))]
        s = rng.uniform(0.9, 1.4)
        ang = rng.uniform(0, 360)
        im = Image.fromarray(np.dstack([rgb, al * 255]).clip(0, 255).astype(np.uint8), 'RGBA')
        im = im.resize((max(8, int(im.width * s)), max(8, int(im.height * s))), Image.LANCZOS).rotate(ang, expand=True)
        p = np.asarray(im).astype(float)
        sh = 0.75 + 0.35 * rng.random()
        y, x = rng.integers(size), rng.integers(size)
        ph, pw = p.shape[:2]
        for dy in (0, -size):
            for dx in (0, -size):
                yy, xx = y + dy, x + dx
                ys0, xs0 = max(yy, 0), max(xx, 0)
                ys1, xs1 = min(yy + ph, size), min(xx + pw, size)
                if ys1 <= ys0 or xs1 <= xs0:
                    continue
                sub = p[ys0 - yy:ys1 - yy, xs0 - xx:xs1 - xx]
                a = sub[..., 3:4] / 255
                out[ys0:ys1, xs0:xs1] = out[ys0:ys1, xs0:xs1] * (1 - a) + sub[..., :3] * sh * a
    save(to_img(out), name + '.png')


def main():
    src = sys.argv[1]
    sheets = {k: Image.open(os.path.join(src, k + '.jpg')).convert('RGB') for k in BOXES}
    rng = np.random.default_rng(7)
    print('фасады:')
    # серая панель: от шва до шва (шов слева и сверху), окно — доли модуля
    grey = np.asarray(sheets['city1'].crop((26 + 29, 20 + 23, 26 + 223, 20 + 216))).astype(float)
    facade(grey, (0.23, 0.15, 0.78, 0.72), 'facade_panel', rng)
    # белая панель с жёлтой плиткой: швы только по горизонтали — по ширине делаем бесшовно
    white = np.asarray(sheets['city1'].crop((311 + 20, 21 + 22, 311 + 225, 21 + 217))).astype(float)
    white = seamless(white, 0.12, axes=(1,))
    facade(white, (0.24, 0.15, 0.76, 0.71), 'facade_tower', rng)
    save(to_img(tile(sheets, 'city1', 5), (512, 512)), 'concrete_panel.png')            # глухая панель — цоколь
    print('земля:')
    save(to_img(seamless(tile(sheets, 'city1', 6)), (512, 512)), 'ground_grass.png')
    save(to_img(seamless(tile(sheets, 'city1', 7)), (512, 512)), 'ground_soil.png')
    save(to_img(seamless(tile(sheets, 'city1', 12)), (512, 512)), 'ground_wasteland.png')
    save(to_img(seamless(tile(sheets, 'city2', 11)), (512, 512)), 'ground_sand.png')
    yard = seamless(tile(sheets, 'city2', 17))
    yard = yard.mean((0, 1)) + (yard - yard.mean((0, 1))) * 0.6      # спокойнее: ямы не бросаются в глаза повтором
    save(to_img(yard, (512, 512)), 'ground_asphalt_yard.png')
    print('деревья:')
    save(to_img(seamless(tile(sheets, 'city1', 8), 0.25, axes=(0,)), (256, 512)), 'bark_birch.png')
    save(to_img(seamless(tile(sheets, 'city2', 12)), (512, 512)), 'bark_tree.png')
    foliage(sheets, [('city2', 0)], (38, 58, 24), 'foliage_birch', rng)
    foliage(sheets, [('city2', 1)], (26, 44, 20), 'foliage_tree', rng)
    foliage(sheets, [('city2', 3), ('city2', 6)], (40, 50, 28), 'foliage_bush', rng)
    print('улица:')
    save(to_img(tile(sheets, 'city1', 9), (512, 512)), 'vitrine.png')
    save(to_img(periodic(tile(sheets, 'city1', 10, 6)), (512, 512)), 'plaster.png')
    save(to_img(seamless(tile(sheets, 'city1', 11)), (256, 256)), 'paint_red.png')
    save(to_img(seamless(tile(sheets, 'city2', 16), 0.1, axes=(0,)), (512, 512)), 'corrugated.png')
    pump, al = key_black(tile(sheets, 'city2', 4, 4))
    ys, xs = np.nonzero(al > 0.5)
    body = pump[ys.min():ys.max(), xs.min():xs.min() + int((xs.max() - xs.min()) * 0.72)]   # без шланга
    save(to_img(body, (128, 256)), 'fuel_pump.png')
    print('интерьеры:')
    it = lambda i, ax=(0, 1), f=0.2: seamless(tile(sheets, 'interior', i), f, ax)
    save(to_img(it(0), (256, 256)), 'wallpaper_floral.png')
    save(to_img(seamless(periodic(tile(sheets, 'interior', 5, 4), (1,), 40), 0.25, (0,)), (256, 256)), 'wallpaper_stripes.png')
    save(to_img(it(7), (256, 256)), 'ceiling.png')
    save(to_img(periodic(tile(sheets, 'interior', 1, 4), lo=40), (512, 512)), 'org/parquet.png')
    save(to_img(it(2, f=0.1), (512, 512)), 'org/linoleum.png')
    save(to_img(seamless(tile(sheets, 'interior', 3), 0.2, (1,)), (512, 512)), 'org/wall_hospital.png')
    save(to_img(periodic(tile(sheets, 'interior', 4, 4)), (512, 512)), 'org/tiles_white.png')
    save(to_img(seamless(periodic(tile(sheets, 'interior', 5, 4), (1,), 40), 0.25, (0,)), (512, 512)), 'org/wood_panel.png')
    save(to_img(tile(sheets, 'interior', 6, 2), (512, 320)), 'org/carpet_wall.png')
    print('готово')


if __name__ == '__main__':
    main()
