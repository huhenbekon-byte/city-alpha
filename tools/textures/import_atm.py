"""Банкомат «Гострудсберкассы СССР» из листа-раскладки автора (вид спереди, бока, зад).

Запуск из корня проекта:  python3 tools/textures/import_atm.py <atm_sheet.jpg>
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

FRONT = (8, 50, 473, 980)       # вид спереди
SCREEN = (114, 142, 366, 354)   # экран
SIDE = (483, 51, 746, 485)      # бок (две панели)
REAR = (757, 563, 1014, 982)    # зад с дверцей


def main():
    im = Image.open(sys.argv[1]).convert('RGB')
    sharp = lambda i: i.filter(ImageFilter.UnsharpMask(radius=1.2, percent=50, threshold=2))
    front = im.crop(FRONT)
    sharp(front.resize((256, 512), Image.LANCZOS)).save('textures/atm_front.png', optimize=True)
    # экран отдельной картинкой: в игре он «светится» (материал без теней)
    sharp(im.crop(SCREEN).resize((256, 216), Image.LANCZOS)).save('textures/atm_screen.png', optimize=True)
    side = im.crop(SIDE)
    tall = Image.new('RGB', (side.width, side.height * 2))
    tall.paste(side, (0, 0))
    tall.paste(side.transpose(Image.FLIP_LEFT_RIGHT), (0, side.height))
    sharp(tall.resize((128, 512), Image.LANCZOS)).save('textures/atm_side.png', optimize=True)
    sharp(im.crop(REAR).resize((256, 512), Image.LANCZOS)).save('textures/atm_rear.png', optimize=True)
    print('готово')


if __name__ == '__main__':
    main()
