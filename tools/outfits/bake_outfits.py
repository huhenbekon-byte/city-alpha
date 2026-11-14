"""Запекание формы персонажей из раскладок одежды (вид спереди/сзади, рукава, штанины) в развёртку тела.

Раскладка — картинка с деталями на сером фоне. Для каждой детали задана примерная рамка; скрипт сам
уточняет её по фону. Потом для каждого пикселя развёртки тела (uvmap.py) берётся точка на теле:
  торс  — плоская проекция переда/спины куртки,
  рукава — развёртка вдоль руки (T-поза): длина рукава → высота картинки рукава,
  ноги  — плоская проекция переда/спины штанов,
  обувь — бесшовный кусок кожи с ботинка, повтор по развёртке.
Результат: models/character/outfit_<имя>_top.png и _bottom.png (RGBA, прозрачно там, где не одежда).

Запуск из корня проекта:  python3 tools/outfits/bake_outfits.py <папка с раскладками> [имя ...]
"""
import sys, os, numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
from uvmap import load_body, rasterize

SIZE = 1024
OUT = 'models/character'

# Примерные рамки (x0, y0, x1, y1) на картинке 784×1168. legs: [левая, правая] или одна на обе.
SHEETS = {
    'militia': dict(front=(12, 300, 382, 560), back=(386, 300, 748, 560),
                    sleeve=[(418, 610, 518, 755), (628, 610, 732, 755)],
                    legs_front=[(32, 758, 122, 1045), (128, 758, 218, 1045)],
                    legs_back=[(234, 758, 322, 1045), (322, 758, 402, 1045)],
                    shoe=(500, 1062, 545, 1105)),
    'tracksuit': dict(front=(12, 268, 388, 562), back=(398, 268, 772, 562),
                      legs_front=(70, 600, 315, 985), legs_back=(452, 600, 712, 985),
                      shoe=(300, 1100, 360, 1150)),
    'doctor': dict(light=True, front=(12, 290, 288, 568), back=(288, 290, 548, 568),
                   sleeve=[(552, 322, 648, 555), (660, 322, 752, 555)],
                   legs_front=[(86, 785, 204, 1085), (208, 785, 300, 1085)],
                   legs_back=[(300, 785, 410, 1085), (300, 785, 410, 1085)],
                   shoe=(560, 1040, 620, 1090)),
    'fire': dict(front=(8, 286, 268, 562), back=(268, 286, 528, 562),
                 sleeve=[(542, 282, 628, 540), (636, 282, 724, 540)],
                 legs_front=(8, 582, 254, 955), legs_back=(258, 582, 504, 955),
                 shoe=(70, 1050, 130, 1110)),
    'leader': dict(front=(6, 210, 218, 455), back=(218, 210, 428, 455),
                   sleeve=[(596, 200, 668, 445), (676, 200, 744, 445)],
                   legs_front=(6, 660, 128, 955), legs_back=(298, 660, 398, 955),
                   shoe=(40, 1050, 100, 1110)),
    'passerby': dict(front=(4, 210, 268, 458), back=(266, 210, 524, 458),
                     sleeve=[(646, 258, 724, 455), (646, 258, 724, 455)],
                     legs_front=(8, 690, 252, 965), legs_back=(252, 690, 502, 965),
                     shoe=(40, 1030, 100, 1080)),
    'bomber': dict(front=(72, 210, 392, 465), back=(388, 210, 704, 465),
                   sleeve=[(2, 225, 78, 465), (702, 225, 778, 465)],
                   legs_front=(88, 636, 374, 995), legs_back=(376, 636, 662, 995),
                   shoe=(470, 1070, 530, 1120)),
    'kgb': dict(front=(8, 360, 268, 575), back=(286, 360, 528, 575),
                sleeve=[(548, 366, 642, 560), (672, 366, 748, 560)],
                legs_front=(12, 590, 138, 945), legs_back=(298, 590, 378, 945),
                shoe=(640, 1060, 700, 1100)),
}


def refine(img, box, pad=6):
    """Уточнить рамку детали по фону (фон — серый, цвет берём по краю рамки)."""
    x0, y0, x1, y1 = box
    a = np.asarray(img.crop((max(0, x0 - pad), max(0, y0 - pad), x1 + pad, y1 + pad))).astype(float)
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(border, 0)
    fg = np.abs(a - bg).sum(2) > 40
    rows = np.where(fg.sum(1) > max(3, fg.shape[1] * 0.04))[0]
    cols = np.where(fg.sum(0) > max(3, fg.shape[0] * 0.04))[0]
    if len(rows) < 5 or len(cols) < 5:
        return img.crop(box)
    ox, oy = max(0, x0 - pad), max(0, y0 - pad)
    return img.crop((ox + cols[0], oy + rows[0], ox + cols[-1] + 1, oy + rows[-1] + 1))


def sample(arr, u, v):
    """Билинейная выборка arr (H,W,3) в точках u,v ∈ [0,1]."""
    h, w = arr.shape[:2]
    x = np.clip(u, 0, 1) * (w - 1); y = np.clip(v, 0, 1) * (h - 1)
    x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
    x1 = np.minimum(x0 + 1, w - 1); y1 = np.minimum(y0 + 1, h - 1)
    fx = (x - x0)[:, None]; fy = (y - y0)[:, None]
    return (arr[y0, x0] * (1 - fx) * (1 - fy) + arr[y0, x1] * fx * (1 - fy) +
            arr[y1, x0] * (1 - fx) * fy + arr[y1, x1] * fx * fy)


LIGHT = False
BG = np.array([200.0, 200.0, 200.0])   # цвет фона раскладки (уточняется в bake по краю картинки)


def fill_bg(arr, bg_thresh=45):
    """Фон вокруг детали (серый) заменить ближайшим цветом ткани — чтобы по краям не было серых полос."""
    a = arr.copy()
    lum = a.mean(2); sat = a.max(2) - a.min(2)
    if LIGHT:   # светлая одежда (халат врача) — фоном считаем только близкое к цвету фона
        fg = ~((np.abs(lum - BG.mean()) < 16) & (sat < 14))
    else:       # фон и светлые тени вокруг детали: серое и светлое
        fg = ~((sat < 20) & (lum > 105)) & (np.abs(a - BG).sum(2) > bg_thresh)
    if fg.mean() < 0.05:
        return a
    # убрать ореол (тень и сглаживание) по краю детали
    fg = np.asarray(Image.fromarray((fg * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))) > 0
    # заливка дыр: размытие только по ткани (с весами), всё дальше и дальше от краёв
    for r in (2, 4, 8, 16, 32, 64, 128):
        if fg.all():
            break
        w = fg.astype(float)
        num = np.stack([np.asarray(Image.fromarray(a[..., c] * w).filter(ImageFilter.BoxBlur(r)) if False else
                        _blur(a[..., c] * w, r)) for c in range(3)], -1)
        den = _blur(w, r)[..., None]
        ok = den[..., 0] > 0.01
        new = ~fg & ok
        a[new] = num[new] / den[new]
        fg = fg | ok
    return np.clip(a, 0, 255)


def _blur(x, r):
    """Box-размытие float-массива (интегральное изображение)."""
    k = 2 * r + 1
    p = np.pad(x, r, mode='edge')
    c = p.cumsum(0); c = np.vstack([np.zeros((1, c.shape[1])), c]); v = (c[k:] - c[:-k]) / k
    c = v.cumsum(1); c = np.hstack([np.zeros((c.shape[0], 1)), c]); return (c[:, k:] - c[:, :-k]) / k


def piece(img, box):
    return fill_bg(np.asarray(refine(img, box).convert('RGB')).astype(float))


def legs_image(img, spec):
    if isinstance(spec, tuple):
        return piece(img, spec)
    l, r = piece(img, spec[0]), piece(img, spec[1])
    h = max(l.shape[0], r.shape[0])
    l = np.asarray(Image.fromarray(l.astype(np.uint8)).resize((l.shape[1], h))).astype(float)
    r = np.asarray(Image.fromarray(r.astype(np.uint8)).resize((r.shape[1], h))).astype(float)
    return np.concatenate([l, r], 1)


def seamless_tile(img, box, size=128):
    a = fill_bg(np.asarray(img.crop(box).convert('RGB')).astype(float))
    a = np.asarray(Image.fromarray(a.astype(np.uint8)).resize((size, size), Image.LANCZOS)).astype(float)
    sh = np.roll(np.roll(a, size // 2, 0), size // 2, 1)
    t = np.abs(np.linspace(-1, 1, size))
    w = np.clip(np.maximum(t[None, :], t[:, None]) * 1.4 - 0.4, 0, 1)[..., None]
    return a * (1 - w) + sh * w


def bake(name, src_dir, P, N, M, mask):
    global BG, LIGHT
    img = Image.open(os.path.join(src_dir, name + '.jpg')).convert('RGB')
    a = np.asarray(img).astype(float)
    BG = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3), a[:, :4].reshape(-1, 3), a[:, -4:].reshape(-1, 3)]), 0)
    cfg = SHEETS[name]
    LIGHT = bool(cfg.get('light'))
    front = piece(img, cfg['front']); back = piece(img, cfg['back'])
    jm = M & (mask[..., 0] > 0.5)
    pm = M & (mask[..., 1] > 0.5)
    sm = M & (mask[..., 2] > 0.5)
    X, Y, Z = P[..., 0], P[..., 1], P[..., 2]
    XS = 0.205                                  # плечо: дальше по X — рукав
    top = np.zeros((SIZE, SIZE, 4))
    bot = np.zeros((SIZE, SIZE, 4))

    # --- торс: центральная часть переда/спины без рукавов
    tor = jm & (np.abs(X) <= XS)
    ty0, ty1 = np.percentile(Y[tor], 1), np.percentile(Y[tor], 99.5)

    def body_band(arr):
        w = arr.shape[1]
        return arr[:, int(w * 0.17):int(w * 0.83)]

    fb, bb = body_band(front), body_band(back)
    for arr, side in ((fb, N[..., 2] >= 0), (bb, N[..., 2] < 0)):
        sel = tor & side
        u = (X[sel] + XS) / (2 * XS)
        if arr is bb:
            u = 1 - u
        v = (ty1 - Y[sel]) / (ty1 - ty0)
        top[sel, :3] = sample(arr, u, v); top[sel, 3] = 255

    # --- рукава: вдоль руки (T-поза)
    arm = jm & (np.abs(X) > XS)
    if arm.any():
        ax = np.abs(X[arm]); xa, xb = XS, np.percentile(ax, 99.5)
        sleeves = cfg.get('sleeve')
        for sgn, k in ((-1, 0), (1, 1)):
            sel = arm & (np.sign(X) == sgn)
            if not sel.any():
                continue
            if sleeves:
                sl = piece(img, sleeves[k])
            else:                                  # рукав — край переда куртки
                w = front.shape[1]
                sl = front[:, :int(w * 0.17)] if k == 0 else front[:, int(w * 0.83):][:, ::-1]
            ys, zs, xs = Y[sel], Z[sel], np.abs(X[sel])
            # центр и радиус руки по срезам
            bins = np.linspace(xa, xb, 24)
            bi = np.clip(np.digitize(xs, bins) - 1, 0, 22)
            yc = np.zeros(23); r = np.zeros(23)
            for b in range(23):
                yy = ys[bi == b]
                if len(yy) > 5:
                    yc[b] = (yy.max() + yy.min()) / 2; r[b] = max(0.02, (yy.max() - yy.min()) / 2)
            ok = r > 0
            yc = np.interp(np.arange(23), np.where(ok)[0], yc[ok]); r = np.interp(np.arange(23), np.where(ok)[0], r[ok])
            v = (xs - xa) / (xb - xa)
            u = 0.5 + (ys - yc[bi]) / (2 * r[bi]) * 0.95
            u = np.where(N[sel][:, 2] >= 0, u, 1 - u) if k == 0 else np.where(N[sel][:, 2] >= 0, 1 - u, u)
            top[sel, :3] = sample(sl, u, v); top[sel, 3] = 255

    # --- штаны: перед/зад по ногам
    lf = legs_image(img, cfg['legs_front']); lb = legs_image(img, cfg['legs_back'])
    legs = pm
    py0, py1 = np.percentile(Y[legs], 0.5), np.percentile(Y[legs], 99.5)
    px = np.percentile(np.abs(X[legs]), 99.5)
    for arr, side, flip in ((lf, N[..., 2] >= 0, False), (lb, N[..., 2] < 0, True)):
        sel = legs & side
        u = (X[sel] + px) / (2 * px)
        if flip:
            u = 1 - u
        v = (py1 - Y[sel]) / (py1 - py0)
        bot[sel, :3] = sample(arr, u, v); bot[sel, 3] = 255
    # пояс куртки, заходящий на штаны (красная полоса в маске) — тоже штаны внизу
    # --- обувь: бесшовная кожа с ботинка
    tile = seamless_tile(img, cfg['shoe'])
    ys_, xs_ = np.where(sm)
    tu = (xs_ * 8 / SIZE) % 1.0; tv = (ys_ * 8 / SIZE) % 1.0
    bot[ys_, xs_, :3] = sample(tile, tu, tv); bot[ys_, xs_, 3] = 255

    # расширить края на 4 пикселя — чтобы на швах развёртки не было тёмных щелей (мипмапы)
    for arr in (top, bot):
        rgb = Image.fromarray(arr[..., :3].astype(np.uint8)); al = arr[..., 3] > 0
        for _ in range(4):
            grown = np.asarray(rgb.filter(ImageFilter.MaxFilter(3))).astype(float)
            ring = ~al & (np.asarray(Image.fromarray((al * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0)
            arr[ring, :3] = grown[ring]; arr[ring, 3] = 0; al = al | ring
            rgb = Image.fromarray(arr[..., :3].astype(np.uint8))
    return top, bot


def save(arr, path, size=1024):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')
    if size != SIZE:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)


def main():
    src = sys.argv[1]
    names = sys.argv[2:] or list(SHEETS)
    pos, nor, uv, idx = load_body()
    P, N, M = rasterize(pos, nor, uv, idx, SIZE)
    mask = np.asarray(Image.open(os.path.join(OUT, 'body_mask.png')).convert('RGB')).astype(float) / 255
    for n in names:
        top, bot = bake(n, src, P, N, M, mask)
        save(top, os.path.join(OUT, 'outfit_%s_top.png' % n))
        save(bot, os.path.join(OUT, 'outfit_%s_bottom.png' % n))
        print('готово:', n)


if __name__ == '__main__':
    main()
