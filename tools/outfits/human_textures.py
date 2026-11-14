"""Текстуры реалистичного персонажа (models/character/human.gltf, развёртка 2048×1024,
своя раскладка островов без наложений — см. tools/models/human_build.py):

  human_mask.png    — R куртка, G штаны, B обувь, A волосы (для перекраски волос)
  human_sleeve.png  — где предплечья (короткий рукав)
  human_skin.png    — кожа и лицо по умолчанию (лицо прохожего)
  human_lampas/tape/vest.png, human_print_ussr.png, human_badge_<фракция>.png — перенос со старой модели
  outfit_<имя>.png  — образ целиком: лицо и волосы с раскладки + одежда (куртка, штаны, обувь)

Запуск из корня проекта:  python3 tools/outfits/human_textures.py <папка с раскладками>
"""
import sys, os, glob
import numpy as np
from PIL import Image, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'models'))
import bake_outfits as BO
from uvmap import load_body, rasterize
from gltfio import Gltf

W, H = 2048, 1024
CH = 'models/character'

# головы на раскладках: (перед, затылок). Нет лица на раскладке — берём лицо другого образа.
HEADS = {
    'militia': ((50, 6, 158, 152), (198, 6, 304, 152)),
    'doctor': ((32, 0, 196, 238), (238, 0, 352, 232)),
    'leader': ((12, 0, 112, 136), (328, 0, 430, 132)),
    'passerby': ((32, 0, 142, 142), (172, 0, 268, 138)),
    'bomber': ((14, 0, 142, 212), None),
    'kgb': ((20, 0, 162, 160), (168, 0, 292, 160)),
}
# зрачки на вырезке лица (x левого, x правого, y) — размечены вручную, автопоиск — запасной вариант
EYES = {'militia': (25, 74, 57.5), 'doctor': (57, 116, 105), 'leader': (32, 64, 59), 'passerby': (35, 72, 68),
        'bomber': (41.5, 86.5, 81.5), 'kgb': (42.5, 111, 57.5)}
# ---- женщины (models/character/human_f.gltf): одежда — 7 панелей листа (f_<образ>.jpg, вырезаны из общего
# листа), лица — лист faces.jpg (7 рядов: лицо спереди и затылок). Рамки — в координатах панели/листа.
SHEETS_F = {
    'militia': dict(front=(7, 50, 195, 205), back=(185, 50, 347, 205), legs_front=(5, 205, 103, 378),
                    legs_back=(5, 205, 103, 378), shoe=(266, 302, 296, 345)),
    'doctor': dict(light=True, front=(10, 50, 200, 222), back=(185, 50, 342, 222), legs_front=(8, 222, 100, 378),
                   legs_back=(8, 222, 100, 378), shoe=(283, 318, 300, 360)),
    'fire': dict(front=(3, 42, 200, 203), back=(183, 42, 347, 203), legs_front=(4, 205, 110, 378),
                 legs_back=(4, 205, 110, 378), shoe=(205, 318, 250, 360)),
    'kgb': dict(front=(2, 50, 183, 200), back=(178, 50, 347, 200), legs_front=(5, 205, 98, 378),
                legs_back=(5, 205, 98, 378), shoe=(282, 305, 305, 365)),
    'tracksuit': dict(front=(10, 50, 180, 192), back=(183, 50, 347, 192), legs_front=(5, 192, 163, 378),
                      legs_back=(5, 192, 163, 378), shoe=(200, 315, 260, 340)),
    'leader': dict(front=(5, 52, 177, 195), back=(180, 55, 347, 195), legs_front=(5, 198, 155, 378),
                   legs_back=(5, 198, 155, 378), shoe=(190, 314, 255, 340)),
    'passerby': dict(front=(5, 58, 180, 192), back=(5, 58, 180, 192), legs_front=(5, 195, 100, 378),
                     legs_back=(105, 195, 200, 378), shoe=(222, 312, 285, 338)),
}
HEADS_F = {
    'militia': ((85, 18, 172, 140), (248, 22, 332, 130)),
    'doctor': ((75, 243, 163, 355), (248, 245, 332, 345)),
    'fire': ((78, 437, 158, 545), (255, 443, 330, 540)),
    'kgb': ((70, 628, 168, 735), (243, 630, 338, 733)),
    'tracksuit': ((82, 812, 152, 915), None),       # сзади — хвост в профиль, затылок берём цветом волос
    'leader': ((75, 1005, 158, 1105), (243, 1008, 325, 1105)),
    'passerby': ((60, 1198, 175, 1300), (235, 1198, 335, 1300)),
}
_EF = {'militia': (112.5, 145, 77.5), 'doctor': (102.5, 137, 299), 'fire': (102.5, 135, 495), 'kgb': (102, 131, 683),
       'tracksuit': (102.5, 133, 866), 'leader': (102.5, 132.5, 1065), 'passerby': (102.5, 132.5, 1255)}
EYES_F = {k: (v[0] - HEADS_F[k][0][0], v[1] - HEADS_F[k][0][0], v[2] - HEADS_F[k][0][1]) for k, v in _EF.items()}
MODEL = 'human.gltf'
RAW_HEAD = False

FACE_OF = {'militia': 'militia', 'tracksuit': 'bomber', 'doctor': 'doctor', 'fire': 'militia', 'leader': 'leader',
           'passerby': 'passerby', 'bomber': 'bomber', 'kgb': 'kgb'}


def joints():
    G = Gltf(os.path.join(CH, MODEL)); Wd = G.world()
    J = {n['name']: Wd[i][:3, 3] for i, n in enumerate(G.g['nodes'])}
    J['eye_l'], J['eye_r'] = [np.array(e) for e in G.g['asset']['extras']['eyes']]
    return J


def blur(a, r):
    return BO._blur(a, r)


def masks(P, N, M, J):
    X, Y, Z = P[..., 0], P[..., 1], P[..., 2]
    sh = J['upperarm_l'][0]
    wrist = J['hand_l'][0] - 0.012
    neck = J['neck_01'][1] + 0.005
    waist = J['pelvis'][1] + 0.075
    ankle = J['foot_l'][1] + 0.045
    arms = (np.abs(X) > sh * 0.92) & (Y > J['spine_02'][1])
    head = M & ~arms & (Y > neck - 0.035)
    jacket = M & ((arms & (np.abs(X) < wrist)) | (~arms & (Y >= waist) & (Y < neck - 0.035 + 0.03 * (np.abs(X) > 0.07))))
    pants = M & ~arms & (Y < waist) & (Y > ankle)
    shoes = M & (Y <= ankle)
    forearm = arms & (np.abs(X) > sh + 0.45 * (J['lowerarm_l'][0] - sh))
    top_y = Y[M].max()
    eye_y = J['eye_l'][1]
    # волосы: макушка и затылок выше линии лба/ушей
    hair = head & ((Y > eye_y + 0.045) | ((N[..., 2] < -0.2) & (Y > eye_y - 0.03)))
    return dict(jacket=jacket, pants=pants, shoes=shoes, head=head, arms=arms, forearm=forearm, hair=hair)


def save_rgba(arr, name):
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA' if arr.shape[2] == 4 else 'RGB').save(os.path.join(CH, name), optimize=True)


def grow(arr, m, n=6):
    """Расширить цвет за края развёртки (чтобы на швах не было щелей)."""
    a = arr.copy(); mm = m.copy()
    for r in (1, 2, 4, 8, 16)[:n]:
        w = mm.astype(float)
        num = np.stack([blur(a[..., c] * w, r) for c in range(a.shape[2])], -1)
        den = blur(w, r)[..., None]
        ok = (den[..., 0] > 0.01) & ~mm
        a[ok] = num[ok] / den[ok]; mm = mm | ok
    return a


# ---------------------------------------------------------------- лицо
def find_eyes(face):
    """Тёмные пятна глаз в верхней половине лица → (xл, xп, y) в пикселях, или None."""
    h, w = face.shape[:2]
    g = face.mean(2)
    band = g[int(h * 0.28):int(h * 0.62), int(w * 0.12):int(w * 0.88)]
    b = blur(band, 2)
    hw = b.shape[1] // 2
    out = []
    for part, ox in ((b[:, :hw - int(w * 0.05)], 0), (b[:, hw + int(w * 0.05):], hw + int(w * 0.05))):
        iy, ix = np.unravel_index(np.argmin(part), part.shape)
        out.append((ix + ox + int(w * 0.12), iy + int(h * 0.28)))
    (xl, yl), (xr, yr) = out
    if abs(yl - yr) > h * 0.06 or not (w * 0.2 < xr - xl < w * 0.6):
        return None
    return xl, xr, (yl + yr) / 2


def head_layer(sheet_img, name, P, N, Mk, J):
    """Лицо и волосы раскладки на голове персонажа → (rgb, вес)."""
    fbox, bbox = HEADS[name]
    # женский лист лиц: зрачки размечены по рамке листа — режем без подгонки рамки по фону
    front = BO.fill_bg(np.asarray(sheet_img.crop(fbox)).astype(float)) if RAW_HEAD else BO.piece(sheet_img, fbox)
    h, w = front.shape[:2]
    e = EYES.get(name) or find_eyes(front)
    if e is None:
        e = (w * 0.33, w * 0.67, h * 0.45)
    exl, exr, ey = e
    ipd_m = J['eye_l'][0] - J['eye_r'][0]
    s = (exr - exl) / ipd_m                         # пикселей на метр
    cx = (exl + exr) / 2
    eye_y = (J['eye_l'][1] + J['eye_r'][1]) / 2
    sel = Mk['head']
    X, Y, Z = P[..., 0][sel], P[..., 1][sel], P[..., 2][sel]
    nz = N[..., 2][sel]
    u = (cx + X * s) / (w - 1); v = (ey - (Y - eye_y) * s) / (h - 1)
    col_f = BO.sample(front, u, v)
    if bbox:
        back = BO.fill_bg(np.asarray(sheet_img.crop(bbox)).astype(float)) if RAW_HEAD else BO.piece(sheet_img, bbox)
        hb, wb = back.shape[:2]
        top = Y.max()
        sb = wb / ((J['eye_l'][0] - J['eye_r'][0]) * 2.55)      # ширина затылка ≈ 2.55 межзрачковых
        ub = (wb / 2 - X * sb) / (wb - 1); vb = ((top - Y) * sb) / (hb - 1)
        col_b = BO.sample(back, ub, vb)
    else:                                            # затылка нет — цвет волос с макушки лица
        hair_c = np.median(front[:max(3, int(h * 0.08)), int(w * 0.3):int(w * 0.7)].reshape(-1, 3), 0)
        col_b = np.tile(hair_c, (len(X), 1)) * (0.92 + 0.08 * np.random.rand(len(X), 1))
    wf = np.clip((nz + 0.15) / 0.5, 0, 1)
    wf = wf * np.clip(v / 0.05, 0, 1)                # выше кадра раскладки — макушка с затылка
    skin = np.median(col_f[(np.abs(X) > 0.022) & (np.abs(X) < 0.045) & (Y < eye_y - 0.03) & (Y > eye_y - 0.07)
                           & (nz > 0.4)].reshape(-1, 3), 0) * 0.97
    col = col_f * wf[:, None] + col_b * (1 - wf[:, None])
    # шея: фото годится только спереди, по бокам проекция тянется полосами — плавно уходим
    # в кожу лица, чуть темнее (шея в тени подбородка)
    chin = eye_y - 0.105
    wn = np.where(Y < chin, np.clip((Y - (chin - 0.06)) / 0.06, 0, 1) * np.clip((nz - 0.2) / 0.4, 0, 1), 1.0)
    col = col * wn[:, None] + (skin * 0.86)[None, :] * (1 - wn[:, None])
    rgb = np.zeros(P.shape); rgb[sel] = col
    if RAW_HEAD:   # глазные яблоки: белок, радужка цвета глаз с фото, зрачок (проекция фото на шар даёт кожу)
        iris_c = BO.sample(front, np.array([exl / (w - 1), exr / (w - 1)]), np.array([ey / (h - 1)] * 2)).mean(0)
        for ec in (J['eye_l'], J['eye_r']):
            d = P - ec
            r = np.linalg.norm(d, axis=-1)
            eye = Mk['head'] & (r < 0.016)
            # от центра видимой части глаза в плоскости лица (центр шара чуть выше разреза век)
            rxy = np.hypot(d[eye][:, 0], d[eye][:, 1] + 0.0035)
            c = np.where(rxy[:, None] < 0.0026, np.array([18.0, 14, 12]),
                         np.where(rxy[:, None] < 0.0066, iris_c * 0.8, np.array([200.0, 190, 182])))
            rgb[eye] = c
    weight = np.zeros(P.shape[:2]); weight[sel] = 1
    return rgb, weight, skin


def skin_base(P, N, M, Mk, skin_rgb):
    """Кожа всего тела: ровный тон с лёгкой неоднородностью и затенением снизу."""
    rng = np.random.default_rng(3)
    noise = blur(rng.standard_normal(P.shape[:2]), 3) * 0.05 + blur(rng.standard_normal(P.shape[:2]), 12) * 0.08
    shade = 0.93 + 0.07 * np.clip(N[..., 1], -1, 1)
    out = np.ones(P.shape) * skin_rgb[None, None, :] * (1 + noise)[..., None] * shade[..., None]
    return np.clip(out, 0, 255)


# ---------------------------------------------------------------- одежда
def clothes(sheet_img, name, P, N, Mk, J, out):
    cfg = BO.SHEETS[name]
    BO.LIGHT = bool(cfg.get('light'))
    a = np.asarray(sheet_img).astype(float)
    BO.BG = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3)]), 0)
    X, Y, Z = P[..., 0], P[..., 1], P[..., 2]
    XS = J['upperarm_l'][0] * 0.92
    front = BO.piece(sheet_img, cfg['front']); back = BO.piece(sheet_img, cfg['back'])
    jm = Mk['jacket']
    tor = jm & ~Mk['arms']
    ty0, ty1 = np.percentile(Y[tor], 0.5), np.percentile(Y[tor], 99.8)
    band = lambda arr: arr[:, int(arr.shape[1] * 0.17):int(arr.shape[1] * 0.83)]
    fb, bb = band(front), band(back)
    xr = np.percentile(np.abs(X[tor]), 99.5)
    for arr, side, flip in ((fb, N[..., 2] >= 0, False), (bb, N[..., 2] < 0, True)):
        sel = tor & side
        u = (X[sel] + xr) / (2 * xr)
        if flip:
            u = 1 - u
        out[sel] = BO.sample(arr, u, (ty1 - Y[sel]) / (ty1 - ty0))
    arm = jm & Mk['arms']
    xa, xb = XS, np.percentile(np.abs(X[arm]), 99.7)
    for sgn, k in ((1, 0), (-1, 1)):
        sel = arm & (np.sign(X) == sgn)
        if cfg.get('sleeve'):
            sl = BO.piece(sheet_img, cfg['sleeve'][k])
        else:
            w = front.shape[1]
            sl = front[:, :int(w * 0.17)] if k == 0 else front[:, int(w * 0.83):][:, ::-1]
        ys, xs = Y[sel], np.abs(X[sel])
        bins = np.linspace(xa, xb, 25); bi = np.clip(np.digitize(xs, bins) - 1, 0, 23)
        yc = np.zeros(24); r = np.zeros(24)
        for b in range(24):
            yy = ys[bi == b]
            if len(yy) > 5:
                yc[b] = (yy.max() + yy.min()) / 2; r[b] = max(0.015, (yy.max() - yy.min()) / 2)
        ok = r > 0
        yc = np.interp(np.arange(24), np.where(ok)[0], yc[ok]); r = np.interp(np.arange(24), np.where(ok)[0], r[ok])
        v = (xs - xa) / (xb - xa)
        u = 0.5 + (ys - yc[bi]) / (2 * r[bi]) * 0.95
        nzs = N[..., 2][sel]
        u = np.where(nzs >= 0, u, 1 - u) if k == 0 else np.where(nzs >= 0, 1 - u, u)
        out[sel] = BO.sample(sl, u, v)
    lf = BO.legs_image(sheet_img, cfg['legs_front']); lb = BO.legs_image(sheet_img, cfg['legs_back'])
    legs = Mk['pants']
    py0, py1 = np.percentile(Y[legs], 0.3), np.percentile(Y[legs], 99.8)
    px = np.percentile(np.abs(X[legs]), 99.5)
    for arr, side, flip in ((lf, N[..., 2] >= 0, False), (lb, N[..., 2] < 0, True)):
        sel = legs & side
        u = (X[sel] + px) / (2 * px)
        if flip:
            u = 1 - u
        out[sel] = BO.sample(arr, u, (py1 - Y[sel]) / (py1 - py0))
    tile = BO.seamless_tile(sheet_img, cfg['shoe'])
    ys_, xs_ = np.where(Mk['shoes'])
    out[ys_, xs_] = BO.sample(tile, (xs_ * 16 / W) % 1.0, (ys_ * 8 / H) % 1.0)


# ---------------------------------------------------------------- перенос старых наклеек (лампасы, шевроны...)
def old_to_new_map(P, M, J):
    """Для каждого пикселя новой развёртки — пиксель старой (Quaternius) с тем же местом на теле."""
    from scipy.spatial import cKDTree
    import json
    Q = Gltf(os.path.join(CH, 'character.gltf')); QW = Q.world()
    QJ = {Q.g['nodes'][j]['name']: QW[j][:3, 3] for j in Q.g['skins'][0]['joints']}
    pos, nor, uv, idx = load_body(os.path.join(CH, 'character.gltf'))
    OP, ON, OM = rasterize(pos, nor, uv, idx, 1024)
    tree = cKDTree(OP[OM])
    oidx = np.argwhere(OM)
    sel = np.argwhere(M)
    p = P[M].copy()
    q = p.copy()
    # руки: вдоль руки по суставам, поперёк — как есть
    arm = (np.abs(p[:, 0]) > J['upperarm_l'][0] * 0.92) & (p[:, 1] > J['spine_02'][1])
    names = ['upperarm_l', 'lowerarm_l', 'hand_l', 'middle_01_l', 'middle_04_leaf_l']
    nx = [J[n][0] for n in names]; ox = [QJ[n][0] for n in names]
    ax = np.abs(p[arm, 0])
    q[arm, 0] = np.sign(p[arm, 0]) * np.interp(ax, nx, ox)
    q[arm, 1] = QJ['upperarm_l'][1] + (p[arm, 1] - J['upperarm_l'][1]) * 1.2
    q[arm, 2] = QJ['upperarm_l'][2] + (p[arm, 2] - J['upperarm_l'][2]) * 1.2
    # туловище и ноги: высота по суставам, ширина — пропорционально
    body = ~arm
    hn = ['ball_l', 'foot_l', 'calf_l', 'thigh_l', 'pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head']
    ny = [J[n][1] for n in hn] + [P[M][:, 1].max()]; oy = [QJ[n][1] for n in hn] + [OP[OM][:, 1].max()]
    q[body, 1] = np.interp(p[body, 1], ny, oy)
    legs = body & (p[:, 1] < J['pelvis'][1])
    q[legs, 0] = np.sign(p[legs, 0]) * (QJ['thigh_l'][0] + (np.abs(p[legs, 0]) - J['thigh_l'][0]) * 1.1)
    tors = body & ~legs
    q[tors, 0] = p[tors, 0] * (QJ['upperarm_l'][0] / J['upperarm_l'][0])
    q[body, 2] = p[body, 2] * 1.1
    d, k = tree.query(q, k=1)
    return sel, oidx[k]


def transfer(src_path, sel, osrc, mask=None):
    old = np.asarray(Image.open(src_path).convert('RGBA')).astype(float)
    out = np.zeros((H, W, 4))
    out[sel[:, 0], sel[:, 1]] = old[osrc[:, 0], osrc[:, 1]]
    return out


def main():
    global HEADS, EYES, FACE_OF, MODEL, RAW_HEAD
    src = sys.argv[1]
    female = len(sys.argv) > 2 and sys.argv[2] == 'female'
    out_name = (lambda f: f.replace('human_', 'human_f_').replace('outfit_', 'outfit_f_')) if female else (lambda f: f)
    if female:
        MODEL = 'human_f.gltf'
        RAW_HEAD = True
        HEADS, EYES, FACE_OF = HEADS_F, EYES_F, {k: k for k in SHEETS_F}
        BO.SHEETS = SHEETS_F
    J = joints()
    pos, nor, uv, idx = load_body(os.path.join(CH, MODEL), 'Body')
    P, N, M = rasterize(pos, nor, uv, idx, W, H)
    Mk = masks(P, N, M, J)

    # маска одежды и рукавов
    mask = np.zeros((H, W, 4))
    for c, k in enumerate(('jacket', 'pants', 'shoes', 'hair')):
        mask[..., c] = blur(Mk[k].astype(float), 1) * 255
    save_rgba(grow(mask, M), out_name('human_mask.png'))
    sl = np.zeros((H, W, 3)); sl[..., 0] = blur(Mk['forearm'].astype(float), 1) * 255
    save_rgba(sl, out_name('human_sleeve.png'))

    pre = 'f_' if female else ''
    sheets = {n: Image.open(os.path.join(src, pre + n + '.jpg')).convert('RGB') for n in BO.SHEETS}
    face_img = Image.open(os.path.join(src, 'faces.jpg')).convert('RGB') if female else None
    faces = {}
    for n in HEADS:
        img = face_img if female else sheets[n]
        BO.LIGHT = False
        a = np.asarray(img).astype(float)
        BO.BG = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3)]), 0)
        faces[n] = head_layer(img, n, P, N, Mk, J)
        print('лицо:', n)

    def full_skin(face_name):
        rgb, wgt, skin = faces[face_name]
        base = skin_base(P, N, M, Mk, skin)
        base = base * (1 - wgt[..., None]) + rgb * wgt[..., None]
        return base

    # кожа по умолчанию (лицо прохожего)
    sk = full_skin('passerby')
    out = np.zeros((H, W, 4)); out[..., :3] = grow(sk, M); out[..., 3] = 255
    save_rgba(out[..., :3], out_name('human_skin.png'))

    # образы целиком
    for n in BO.SHEETS:
        body = full_skin(FACE_OF[n])
        clothes(sheets[n], n, P, N, Mk, J, body)
        out = np.zeros((H, W, 4)); out[..., :3] = grow(body, M); out[..., 3] = 255
        save_rgba(out[..., :3], out_name('outfit_%s.png' % n))
        print('образ:', n)
    if female:
        print('готово')
        return

    # наклейки со старой модели
    sel, osrc = old_to_new_map(P, M, J)
    for f in ['body_lampas.png', 'body_tape.png', 'body_vest.png', 'print_ussr.png'] + \
             [os.path.basename(x) for x in glob.glob(os.path.join(CH, 'body_badge_*.png'))]:
        t = transfer(os.path.join(CH, f), sel, osrc)
        name = 'human_' + f.replace('body_', '')
        save_rgba(t, name)
    print('готово')


if __name__ == '__main__':
    main()
