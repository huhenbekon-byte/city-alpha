extends RefCounted
## Каталог одежды и внешности. Первый вариант в каждом разделе — стартовый
## (бесплатный, уже есть у игрока). Цена 0 — бесплатно.

const SLOTS := [
    {"id": "jacket", "name": "Куртка", "items": [
        ["бирюзовая", Color(0.09, 0.42, 0.52), 0],
        ["чёрная кожаная", Color(0.08, 0.08, 0.09), 2500, "cloth_leather"],
        ["красная", Color(0.65, 0.10, 0.10), 1500],
        ["хаки", Color(0.33, 0.36, 0.22), 1200],
        ["белая", Color(0.92, 0.92, 0.90), 2000],
        ["жёлтая", Color(0.90, 0.70, 0.10), 1800],
        ["спортивная синяя", Color(0.10, 0.20, 0.60), 3000, "cloth_tracksuit"],
    ]},
    {"id": "pants", "name": "Штаны", "items": [
        ["джинсы", Color(0.17, 0.24, 0.38), 0],
        ["чёрные", Color(0.08, 0.08, 0.09), 800],
        ["серые спортивные", Color(0.45, 0.46, 0.48), 900, "cloth_tracksuit"],
        ["бежевые", Color(0.70, 0.60, 0.45), 1100],
        ["камуфляж", Color(0.30, 0.33, 0.22), 1500],
    ]},
    {"id": "shoes", "name": "Кроссовки", "items": [
        ["белые", Color(0.96, 0.96, 0.96), 0],
        ["чёрные", Color(0.10, 0.10, 0.10), 900],
        ["красные", Color(0.80, 0.12, 0.12), 1400],
        ["синие", Color(0.15, 0.35, 0.80), 1400],
        ["золотые", Color(0.85, 0.68, 0.25), 6000],
    ]},
    {"id": "hair", "name": "Волосы", "items": [
        ["тёмные", Color(0.16, 0.11, 0.08), 0],
        ["русые", Color(0.45, 0.33, 0.20), 300],
        ["рыжие", Color(0.65, 0.28, 0.10), 500],
        ["блонд", Color(0.85, 0.75, 0.45), 500],
        ["седые", Color(0.70, 0.70, 0.70), 400],
        ["синие", Color(0.15, 0.30, 0.75), 900],
    ]},
    {"id": "skin", "name": "Кожа", "items": [
        ["светлая", Color(0.87, 0.68, 0.55), 0],
        ["бледная", Color(0.95, 0.80, 0.70), 0],
        ["смуглая", Color(0.70, 0.50, 0.35), 0],
        ["тёмная", Color(0.45, 0.30, 0.20), 0],
    ]},
]


static func default_look() -> Dictionary:
    var d := {}
    for slot: Dictionary in SLOTS:
        d[slot["id"]] = 0
    return d


## Ткань по умолчанию для каждого раздела (у вещи может быть своя — 4-й элемент).
const DEFAULT_TEX := {"jacket": "cloth_nylon", "pants": "cloth_denim", "shoes": "cloth_sneaker",
        "hair": "hair", "skin": "skin"}


## Текстуры для персонажа: {"jacket": "cloth_leather", ...}.
static func textures(look: Dictionary) -> Dictionary:
    var out := {}
    for slot: Dictionary in SLOTS:
        var items: Array = slot["items"]
        var i := clampi(int(look.get(slot["id"], 0)), 0, items.size() - 1)
        var item: Array = items[i]
        out[slot["id"]] = item[3] if item.size() > 3 else DEFAULT_TEX.get(slot["id"], "")
    return out


## Цвета для персонажа по выбранным номерам: {"jacket": Color, ...}.
static func colors(look: Dictionary) -> Dictionary:
    var out := {}
    for slot: Dictionary in SLOTS:
        var items: Array = slot["items"]
        var i := clampi(int(look.get(slot["id"], 0)), 0, items.size() - 1)
        var item: Array = items[i]
        out[slot["id"]] = item[1]
    return out
