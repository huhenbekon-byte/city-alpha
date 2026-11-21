"""Новая форма фракций с листов автора (1248×832, детали на тёмном фоне): переносит одежду на готовые
образы outfit_<имя>.png (лицо и кожа остаются как были), для мужской и женской модели.

Листы: kgb.jpg (1536×1024), fire.jpg, medic.jpg (белый халат + синяя куртка «Скорая помощь»), militia.jpg, opg.jpg (чёрный
спортивный костюм «ОПГ»), avtoritet.jpg (костюм «Авторитет ОПГ»). Рамки деталей — BOXES ниже (вручную).
Фон тёмный и почти как ткань, поэтому детали вырезаются по рамке как есть, без поиска фона.

Запуск из корня проекта:  python3 tools/outfits/new_uniforms.py <папка с листами>
"""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'models'))
import bake_outfits as BO
import human_textures as HT
from uvmap import load_body, rasterize

BOXES = {
    'fire': dict(src='fire', base='fire', front=(10, 30, 405, 410), back=(415, 30, 760, 410),
                 sleeve=(1050, 10, 1238, 418), legs_front=(22, 432, 302, 790), legs_back=(330, 432, 600, 790)),
    'doctor': dict(src='medic', base='doctor', front=(5, 5, 360, 432), back=(372, 5, 695, 432),
                   legs_front=(15, 440, 270, 830), legs_back=(278, 440, 545, 830)),
    'ambulance': dict(src='medic', base='doctor', front=(700, 5, 965, 440), back=(968, 5, 1245, 440),
                      legs_front=(15, 440, 270, 830), legs_back=(278, 440, 545, 830)),
    'militia': dict(src='militia', base='militia', front=(5, 35, 410, 425), back=(418, 35, 762, 425),
                    sleeve=(1060, 10, 1240, 420), legs_front=(30, 435, 305, 830), legs_back=(320, 435, 595, 830)),
    'opg': dict(src='opg', base='tracksuit', front=(5, 20, 405, 412), back=(410, 20, 745, 412),
                legs_front=(15, 425, 310, 832), legs_back=(318, 425, 600, 832)),
    # у КГБ спина нарисована без рукавов — рамку расширяем, чтобы средняя часть (без «рукавов») была спиной
    'kgb': dict(src='kgb', base='kgb', front=(8, 5, 515, 472), back=(400, 5, 900, 472),
                sleeve=[(868, 10, 1040, 610), (1068, 10, 1232, 610)], legs_front=(8, 492, 318, 1020), legs_back=(330, 492, 610, 1020)),
    'avtoritet': dict(src='avtoritet', base='leader', front=(5, 5, 410, 420), back=(418, 5, 745, 420),
                      legs_front=(40, 425, 300, 832), legs_back=(330, 425, 600, 832)),
}
# чужие логотипы на листе ОПГ закрашиваем тканью (в игре — без брендов)
ERASE = {'opg': [(236, 128, 296, 170), (228, 530, 272, 570)]}


def crop(img, box):
    return np.asarray(img.crop(box).convert('RGB')).astype(float)


def erase(img, boxes):
    a = np.asarray(img).astype(float).copy()
    for x0, y0, x1, y1 in boxes:
        reg = a[y0:y1, x0:x1]
        lum = reg.mean(2)
        dark = np.median(reg[lum < np.percentile(lum, 40)], 0)
        reg[lum > 45] = dark
    return Image.fromarray(a.astype(np.uint8))


def run(src, female, only=None):
    HT.MODEL = 'human_f.gltf' if female else 'human.gltf'
    J = HT.joints()
    pos, nor, uv, idx = load_body(os.path.join(HT.CH, HT.MODEL), 'Body')
    P, N, M = rasterize(pos, nor, uv, idx, HT.W, HT.H)
    Mk = HT.masks(P, N, M, J)
    BO.piece = crop                                  # рамки точные — без уточнения по фону
    BO.legs_image = lambda img, spec: crop(img, spec)
    pre = 'outfit_f_' if female else 'outfit_'
    for name, b in BOXES.items():
        if only and name not in only:
            continue
        img = Image.open(os.path.join(src, b['src'] + '.jpg')).convert('RGB')
        if name in ERASE:
            img = erase(img, ERASE[name])
        cfg = dict(front=b['front'], back=b['back'], legs_front=b['legs_front'], legs_back=b['legs_back'], shoe=(0, 0, 8, 8))
        if 'sleeve' in b:
            cfg['sleeve'] = b['sleeve'] if isinstance(b['sleeve'], list) else [b['sleeve'], b['sleeve']]
        BO.SHEETS = {name: cfg}
        base = np.asarray(Image.open(os.path.join(HT.CH, pre + b['base'] + '.png')).convert('RGB')).astype(float)
        body = base.copy()
        HT.clothes(img, name, P, N, Mk, J, body)
        body[Mk['shoes']] = base[Mk['shoes']]        # обувь — прежняя
        out = np.zeros((HT.H, HT.W, 4)); out[..., :3] = HT.grow(body, M); out[..., 3] = 255
        HT.save_rgba(out[..., :3], pre + name + '.png')
        print('готово:', pre + name)


if __name__ == '__main__':
    only = sys.argv[2:] or None      # можно перепечь только некоторые: ... <папка> kgb
    run(sys.argv[1], False, only)
    run(sys.argv[1], True, only)
