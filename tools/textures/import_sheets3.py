"""Текстуры из трёх листов-сеток 3×3 (картинки из нейросети автора игры):

  city3.jpg — вокзал, медная кровля, стена метро с «М», рельсы, двери вокзала и ДК, вывеска «МИЛИЦИЯ»,
              киоски «ПРОКАТ» и «СПРАВКИ»
  dk.jpg    — афиши «КОНЦЕРТ» и «КИНО», занавес, доски сцены, лакированное дерево, пожарный щит,
              кожа боксёрской груши, картина «Берёзы», растяжка «С НОВЫМ ГОДОМ!»
  azs.jpg   — будка АЗС спереди и сбоку, витрина, полоса «БЕНЗИН», бетон с пятнами масла, табло цен,
              профлист, пожарный стенд с песком, служебная дверь

Предметы на фоне (киоски, табло, стенд, растяжка) вырезаются с прозрачностью: фон заливкой от краёв.
Запуск из корня проекта:  python3 tools/textures/import_sheets3.py <папка с city3.jpg, dk.jpg, azs.jpg>
"""
import os
import sys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

OUT = 'textures/sheet3'

# имя: (лист, рамка x0, y0, x1, y1, размер, вырезать фон)
ITEMS = {
    'vokzal_window':  ('city3', (104, 100, 238, 306), (128, 192), False),
    'roof_copper':    ('city3', (347, 4, 677, 335), (256, 256), False),
    'metro_wall':     ('city3', (690, 4, 1020, 335), (256, 256), False),
    'rail_track':     ('city3', (4, 347, 335, 677), (256, 256), False),
    'door_station':   ('city3', (369, 350, 639, 677), (256, 320), False),
    'door_dk':        ('city3', (714, 347, 994, 676), (256, 320), False),
    'sign_militia':   ('city3', (8, 803, 456, 908), (512, 128), False),
    'kiosk_prokat':   ('city3', (470, 756, 674, 1008), (192, 256), True),
    'kiosk_spravki':  ('city3', (710, 693, 997, 1019), (256, 288), True),
    'poster_concert': ('dk', (34, 2, 306, 338), (192, 240), False),
    'poster_cinema':  ('dk', (384, 2, 639, 338), (192, 256), False),
    'curtain':        ('dk', (690, 4, 1020, 335), (256, 256), False),
    'stage_floor':    ('dk', (4, 347, 335, 677), (256, 256), False),
    'wood_lacquer':   ('dk', (347, 347, 677, 677), (256, 256), False),
    'fire_board':     ('dk', (690, 347, 1020, 677), (256, 256), False),
    'leather_bag':    ('dk', (4, 690, 335, 1020), (256, 256), False),
    'painting_birch': ('dk', (385, 728, 640, 983), (256, 256), False),
    'banner_newyear': ('dk', (692, 712, 1016, 972), (256, 208), True),
    'azs_front':      ('azs', (7, 38, 334, 300), (320, 256), False),
    'azs_side':       ('azs', (349, 38, 676, 300), (320, 256), False),
    'gas_floor':      ('azs', (347, 347, 677, 677), (256, 256), False),
    'price_board':    ('azs', (722, 353, 986, 679), (192, 240), True),
    'corrugated_blue': ('azs', (4, 690, 335, 1020), (256, 256), False),
    'fire_stand':     ('azs', (416, 690, 608, 1017), (128, 224), True),
    'door_service':   ('azs', (721, 691, 987, 1021), (192, 240), True),
}


def key_background(im):
    """Фон вокруг предмета (однотонный, соединён с краем картинки) → прозрачный."""
    a = np.asarray(im).astype(float)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, 0)
    near = np.abs(a - bg).max(2) < 22
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = np.isin(lab, list(border))
    alpha = (~mask).astype(float)
    alpha = ndimage.gaussian_filter(alpha, 0.7)
    return Image.fromarray(np.dstack([a, alpha * 255]).clip(0, 255).astype(np.uint8), 'RGBA')


def main():
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    sheets = {}
    for name, (sheet, box, size, cut) in ITEMS.items():
        if sheet not in sheets:
            sheets[sheet] = Image.open(os.path.join(src, sheet + '.jpg')).convert('RGB')
        im = sheets[sheet].crop(box)
        if name == 'rail_track':          # рельсы в игре идут вдоль X
            im = im.transpose(Image.ROTATE_90)
        if cut:
            im = key_background(im)
        im = im.resize(size, Image.LANCZOS)
        if im.mode == 'RGB':
            im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=50, threshold=2))
        im.save(os.path.join(OUT, name + '.png'), optimize=True)
        print('  ', name, im.size, im.mode)
    print('готово')


if __name__ == '__main__':
    main()
