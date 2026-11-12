extends RefCounted
## Каталог одежды и внешности. Первый вариант в каждом разделе — стартовый
## (бесплатный, уже есть у игрока). Цена 0 — бесплатно.

const SLOTS := [
    {"id": "jacket", "name": "Верх", "items": [
        ["майка «СССР»", Color(1.0, 1.0, 1.0), 0, "cloth_red_cotton", "short,print"],
        ["майка красная", Color(1.0, 1.0, 1.0), 400, "cloth_red_cotton", "short"],
        ["футболка белая", Color(0.95, 0.95, 0.93), 400, "cloth_knit", "short"],
        ["бирюзовая куртка", Color(0.09, 0.42, 0.52), 1000],
        ["кожанка коричневая", Color(1.0, 1.0, 1.0), 4000, "cloth_leather_brown"],
        ["кожанка чёрная", Color(1.0, 1.0, 1.0), 4000, "cloth_leather_black"],
        ["чёрная кожаная", Color(0.08, 0.08, 0.09), 2500, "cloth_leather"],
        ["красная", Color(0.65, 0.10, 0.10), 1500],
        ["хаки", Color(0.33, 0.36, 0.22), 1200],
        ["белая", Color(0.92, 0.92, 0.90), 2000],
        ["жёлтая", Color(0.90, 0.70, 0.10), 1800],
        ["спортивная синяя", Color(0.10, 0.20, 0.60), 3000, "cloth_tracksuit"],
        ["свитер вязаный", Color(0.75, 0.75, 0.75), 1600, "cloth_sweater"],
        ["кожанка потёртая", Color(0.85, 0.85, 0.85), 3500, "cloth_leather2"],
        ["олимпийка синяя", Color(1.0, 1.0, 1.0), 2200, "cloth_nylon_blue"],
        ["ватник", Color(1.0, 1.0, 1.0), 900, "cloth_quilted_navy"],
        ["болоньевая куртка", Color(1.0, 1.0, 1.0), 1700, "cloth_bolonya_green"],
        ["свитер серый", Color(1.0, 1.0, 1.0), 1300, "cloth_wool_gray"],
        ["плащ бежевый", Color(1.0, 1.0, 1.0), 2600, "cloth_gabardine"],
        ["вельветовый пиджак", Color(1.0, 1.0, 1.0), 2400, "cloth_corduroy"],
        ["рубашка в клетку", Color(1.0, 1.0, 1.0), 800, "cloth_check_blue", "short"],
        ["рубашка белая", Color(1.0, 1.0, 1.0), 700, "cloth_cotton_white", "short"],
    ]},
    {"id": "pants", "name": "Штаны", "items": [
        ["джинсы", Color(1.0, 1.0, 1.0), 0, "cloth_denim_blue"],
        ["тёмные джинсы", Color(0.17, 0.24, 0.38), 600],
        ["чёрные", Color(0.08, 0.08, 0.09), 800],
        ["серые спортивные", Color(0.45, 0.46, 0.48), 900, "cloth_tracksuit"],
        ["бежевые", Color(0.70, 0.60, 0.45), 1100],
        ["камуфляж", Color(0.30, 0.33, 0.22), 1500],
        ["джинсы потёртые", Color(0.95, 0.95, 0.95), 1200, "cloth_jeans"],
        ["варёнки", Color(1.0, 1.0, 1.0), 1600, "cloth_acidwash"],
        ["трико", Color(1.0, 1.0, 1.0), 500, "cloth_jersey_gray"],
        ["брюки чёрные", Color(1.0, 1.0, 1.0), 1400, "cloth_wool_black"],
        ["брюки коричневые", Color(1.0, 1.0, 1.0), 1300, "cloth_trousers_brown"],
    ]},
    {"id": "shoes", "name": "Обувь", "items": [
        ["ботинки коричневые", Color(1.0, 1.0, 1.0), 0, "cloth_leather_brown"],
        ["ботинки чёрные", Color(1.0, 1.0, 1.0), 1500, "cloth_leather_black"],
        ["кроссовки белые", Color(0.96, 0.96, 0.96), 700],
        ["кроссовки чёрные", Color(0.10, 0.10, 0.10), 900],
        ["кроссовки красные", Color(0.80, 0.12, 0.12), 1400],
        ["кроссовки синие", Color(0.15, 0.35, 0.80), 1400],
        ["кроссовки золотые", Color(0.85, 0.68, 0.25), 6000],
        ["кеды белые", Color(1.0, 1.0, 1.0), 600, "cloth_canvas_white"],
        ["сапоги резиновые", Color(1.0, 1.0, 1.0), 500, "cloth_rubber_black"],
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


## Цвет значка вещи в магазине (у тканей со своим цветом — цвет ткани).
static func swatch(item: Array) -> Color:
    var c: Color = item[1]
    var tex := String(item[3]) if item.size() > 3 else ""
    if c.r > 0.97 and c.g > 0.97:
        if tex.contains("red"):
            return Color(0.75, 0.12, 0.12)
        if tex.contains("denim"):
            return Color(0.25, 0.36, 0.52)
        if tex.contains("brown"):
            return Color(0.36, 0.25, 0.18)
        if tex.contains("black"):
            return Color(0.13, 0.13, 0.14)
        var sw := {"cloth_nylon_blue": Color(0.10, 0.30, 0.75), "cloth_quilted_navy": Color(0.12, 0.14, 0.22),
                "cloth_bolonya_green": Color(0.20, 0.30, 0.20), "cloth_wool_gray": Color(0.55, 0.55, 0.55),
                "cloth_gabardine": Color(0.75, 0.65, 0.48), "cloth_corduroy": Color(0.45, 0.30, 0.18),
                "cloth_check_blue": Color(0.45, 0.55, 0.75), "cloth_cotton_white": Color(0.93, 0.93, 0.93),
                "cloth_acidwash": Color(0.65, 0.75, 0.85), "cloth_jersey_gray": Color(0.55, 0.55, 0.57),
                "cloth_trousers_brown": Color(0.25, 0.20, 0.16), "cloth_canvas_white": Color(0.95, 0.95, 0.95)}
        if sw.has(tex):
            return sw[tex]
    return c


## Фасон верха: 5-й элемент вещи — "short" (короткий рукав), "print" (принт СССР).
static func jacket_style(look: Dictionary) -> String:
    var items: Array = SLOTS[0]["items"]
    var item: Array = items[clampi(int(look.get("jacket", 0)), 0, items.size() - 1)]
    return String(item[4]) if item.size() > 4 else ""


## Текстуры для персонажа: {"jacket": "cloth_leather", ...} и фасон в "jacket_style".
static func textures(look: Dictionary) -> Dictionary:
    var out := {}
    for slot: Dictionary in SLOTS:
        var items: Array = slot["items"]
        var i := clampi(int(look.get(slot["id"], 0)), 0, items.size() - 1)
        var item: Array = items[i]
        out[slot["id"]] = item[3] if item.size() > 3 else DEFAULT_TEX.get(slot["id"], "")
    out["jacket_style"] = jacket_style(look)
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
