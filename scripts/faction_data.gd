extends RefCounted
## Фракции: государственные (type "state") и ОПГ (type "gang").
## Ранги, зарплаты (у ОПГ — доля из общака), машины автопарка.

## Ранги (номер = индекс + 1). Лимит — сколько человек может быть на ранге (для онлайна).
const RANKS := ["Новенький", "Начинающий", "Знающий", "Помощник", "Заместитель", "Лидер"]
const RANK_TAGS := ["", "", "", "", "СС", "Л/СС"]
const RANK_LIMITS := [115, 115, 115, 115, 2, 1]
## Зарплата за каждую получку (раз в 3 игровых часа) по рангам.
const SALARY := [400, 550, 700, 900, 1200, 1600]
## Сколько получек «стажа» нужно для повышения с ранга 1, 2, 3.
## Заместителя и лидера назначает лидер (будет в онлайне).
const PROMOTE_AFTER := [3, 5, 8]

## Ранги ОПГ: Авторитета (СС) и Вора в Законе (Л/СС) назначают, остальные — за стаж.
const GANG_RANKS := ["Пешка", "Шнырь", "Фраер", "Барыга", "Авторитет", "Вор в Законе"]
const GANG_LIMITS := [100, 100, 100, 100, 2, 1]
const GANG_SALARY := [300, 450, 600, 800, 1100, 1500]

const LIST := [
    {"id": "mayor", "emblem": "mayor", "city": "kazan", "name": "Мэрия Казани", "title": "МЭРИЯ", "color": Color(0.85, 0.68, 0.25),
        "wall": Color(0.90, 0.84, 0.72), "vehicles": [
            {"name": "Служебная", "kind": "car", "paint": Color(0.08, 0.08, 0.09), "rank": 1, "speed": 140.0, "force": 5600.0, "model": "vaz2106"},
            {"name": "Автобус мэрии", "kind": "bus", "paint": Color(0.92, 0.92, 0.90), "livery": "МЭРИЯ", "livery_col": Color(0.15, 0.25, 0.55), "rank": 2, "speed": 90.0, "force": 18000.0},
            {"name": "«Волга» мэрии", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 3, "speed": 165.0, "force": 7200.0, "model": "volga"},
            {"name": "Представительская", "kind": "car", "paint": Color(0.10, 0.14, 0.28), "rank": 5, "speed": 170.0, "force": 7400.0, "model": "suv"},
        ]},
    {"id": "police", "emblem": "police", "city": "kazan", "name": "Главная милиция", "title": "ГЛАВНАЯ МИЛИЦИЯ", "color": Color(0.20, 0.35, 0.75),
        "wall": Color(0.70, 0.76, 0.84), "vehicles": [
            {"name": "ППС «Копейка»", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "lights": true, "rank": 1, "speed": 140.0, "force": 5600.0, "model": "vaz2101_mil"},
            {"name": "ППС «Нива»", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "livery": "МИЛИЦИЯ", "livery_col": Color(0.10, 0.22, 0.65), "lights": true, "rank": 2, "speed": 135.0, "force": 6400.0, "model": "niva"},
            {"name": "ДПС", "kind": "car", "paint": Color(0.93, 0.93, 0.92), "livery": "ДПС", "livery_col": Color(0.15, 0.30, 0.70), "lights": true, "rank": 3, "speed": 170.0, "force": 7000.0, "model": "cop"},
            {"name": "Автозак", "kind": "truck", "paint": Color(0.40, 0.45, 0.55), "livery": "МИЛИЦИЯ", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "rank": 3, "speed": 100.0, "force": 22000.0},
            {"name": "Оперативный УАЗ", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "livery": "МИЛИЦИЯ", "livery_col": Color(0.10, 0.22, 0.65), "lights": true, "rank": 4, "speed": 115.0, "force": 5200.0, "model": "uaz452"},
            {"name": "Волга ГАИ", "kind": "car", "paint": Color(0.93, 0.93, 0.92), "livery": "МИЛИЦИЯ", "livery_col": Color(0.15, 0.30, 0.70), "lights": true, "rank": 5, "speed": 165.0, "force": 7200.0, "model": "volga"},
            {"name": "Волга начальника", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 6, "speed": 170.0, "force": 7600.0, "model": "volga"},
        ]},
    {"id": "hospital", "emblem": "hospital", "city": "kazan", "name": "Главная больница", "title": "ГЛАВНАЯ БОЛЬНИЦА", "color": Color(0.85, 0.15, 0.15),
        "wall": Color(0.86, 0.93, 0.90), "vehicles": [
            {"name": "Скорая помощь", "kind": "car", "paint": Color(0.95, 0.95, 0.93), "livery": "СКОРАЯ", "livery_col": Color(0.85, 0.12, 0.12), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 1, "speed": 120.0, "force": 4800.0, "model": "uaz452"},
            {"name": "Служебная", "kind": "car", "paint": Color(0.95, 0.95, 0.93), "livery": "МЕДСЛУЖБА", "livery_col": Color(0.85, 0.12, 0.12), "rank": 3, "speed": 140.0, "force": 5600.0, "model": "hatch"},
            {"name": "Главврач", "kind": "car", "paint": Color(0.08, 0.08, 0.09), "rank": 5, "speed": 170.0, "force": 7400.0, "model": "sedan"},
        ]},
    {"id": "fire", "emblem": "fire", "city": "kazan", "name": "Главная пожарная часть", "title": "ПОЖАРНАЯ ЧАСТЬ №1", "color": Color(0.85, 0.20, 0.10),
        "wall": Color(0.92, 0.84, 0.78), "vehicles": [
            {"name": "Пожарная машина", "kind": "truck", "paint": Color(0.78, 0.10, 0.08), "livery": "ПОЖАРНАЯ", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 1, "speed": 100.0, "force": 24000.0},
            {"name": "Командирская", "kind": "car", "paint": Color(0.78, 0.10, 0.08), "livery": "МЧС", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 3, "speed": 150.0, "force": 6000.0, "model": "suv"},
        ]},
    {"id": "kgb", "emblem": "kgb", "city": "kazan", "name": "КГБ", "title": "КГБ", "color": Color(0.30, 0.32, 0.30),
        "wall": Color(0.48, 0.40, 0.32), "vehicles": [
            {"name": "Оперативная", "kind": "car", "paint": Color(0.08, 0.08, 0.09), "rank": 1, "speed": 160.0, "force": 6400.0, "model": "vaz2106"},
            {"name": "Наружка", "kind": "car", "paint": Color(0.35, 0.37, 0.38), "rank": 2, "speed": 160.0, "force": 6400.0, "model": "sedan"},
            {"name": "Чёрная «Волга»", "kind": "car", "paint": Color(0.04, 0.04, 0.05), "rank": 3, "speed": 170.0, "force": 7400.0, "model": "volga"},
            {"name": "Спецгруппа", "kind": "bus", "paint": Color(0.18, 0.20, 0.22), "rank": 4, "speed": 95.0, "force": 19000.0},
            {"name": "Руководство", "kind": "car", "paint": Color(0.06, 0.06, 0.07), "rank": 5, "speed": 180.0, "force": 7800.0, "model": "suv"},
        ]},
    {"id": "tyap", "emblem": "tyap", "type": "gang", "city": "kazan", "name": "ОПГ «Тяп-Ляп»", "title": "ТЯП-ЛЯП", "color": Color(0.20, 0.65, 0.30),
        "wall": Color(0.45, 0.47, 0.45), "vehicles": [
            {"name": "Классика", "kind": "car", "paint": Color(0.15, 0.35, 0.18), "rank": 1, "speed": 115.0, "force": 4600.0, "model": "vaz2106"},
            {"name": "Девятка тонированная", "kind": "car", "paint": Color(0.08, 0.09, 0.08), "rank": 2, "speed": 140.0, "force": 5600.0, "model": "hatch"},
            {"name": "Седан бригадира", "kind": "car", "paint": Color(0.10, 0.25, 0.12), "rank": 4, "speed": 165.0, "force": 7000.0, "model": "sedan"},
            {"name": "Чёрный седан", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 5, "speed": 180.0, "force": 7800.0, "model": "coupe"},
        ]},
    {"id": "universam", "emblem": "universam", "type": "gang", "city": "kazan", "name": "Универсамское ОПГ", "title": "УНИВЕРСАМ", "color": Color(0.25, 0.45, 0.90),
        "wall": Color(0.45, 0.46, 0.50), "vehicles": [
            {"name": "Классика", "kind": "car", "paint": Color(0.20, 0.30, 0.55), "rank": 1, "speed": 115.0, "force": 4600.0, "model": "vaz2106"},
            {"name": "Девятка тонированная", "kind": "car", "paint": Color(0.08, 0.08, 0.10), "rank": 2, "speed": 140.0, "force": 5600.0, "model": "hatch"},
            {"name": "Микроавтобус", "kind": "car", "paint": Color(0.30, 0.32, 0.36), "rank": 3, "speed": 110.0, "force": 4400.0, "model": "uaz452"},
            {"name": "Чёрный седан", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 5, "speed": 180.0, "force": 7800.0, "model": "coupe"},
        ]},
    {"id": "solnce", "emblem": "solnce", "type": "gang", "city": "pyat", "name": "Солнечные ОПГ", "title": "СОЛНЕЧНЫЕ", "color": Color(0.95, 0.75, 0.15),
        "wall": Color(0.50, 0.47, 0.42), "vehicles": [
            {"name": "Классика", "kind": "car", "paint": Color(0.75, 0.60, 0.15), "rank": 1, "speed": 115.0, "force": 4600.0, "model": "vaz2106"},
            {"name": "Девятка тонированная", "kind": "car", "paint": Color(0.08, 0.08, 0.08), "rank": 2, "speed": 140.0, "force": 5600.0, "model": "hatch"},
            {"name": "Седан бригадира", "kind": "car", "paint": Color(0.55, 0.40, 0.10), "rank": 4, "speed": 165.0, "force": 7000.0, "model": "sedan"},
            {"name": "Чёрный седан", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 5, "speed": 180.0, "force": 7800.0, "model": "coupe"},
        ]},
    {"id": "kavkaz", "emblem": "kavkaz", "type": "gang", "city": "pyat", "name": "Кавказское ОПГ", "title": "КАВКАЗ", "color": Color(0.80, 0.15, 0.15),
        "wall": Color(0.48, 0.44, 0.42), "vehicles": [
            {"name": "Классика", "kind": "car", "paint": Color(0.55, 0.12, 0.12), "rank": 1, "speed": 115.0, "force": 4600.0, "model": "vaz2106"},
            {"name": "Девятка тонированная", "kind": "car", "paint": Color(0.06, 0.06, 0.06), "rank": 2, "speed": 140.0, "force": 5600.0, "model": "hatch"},
            {"name": "Седан бригадира", "kind": "car", "paint": Color(0.92, 0.92, 0.90), "rank": 4, "speed": 165.0, "force": 7000.0, "model": "sedan"},
            {"name": "Чёрный седан", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 5, "speed": 180.0, "force": 7800.0, "model": "coupe"},
        ]},
    {"id": "police_p", "base": "police", "emblem": "police", "city": "pyat", "name": "Милиция Пятигорска", "title": "МИЛИЦИЯ ПЯТИГОРСКА",
        "color": Color(0.25, 0.45, 0.85), "wall": Color(0.74, 0.78, 0.84), "vehicles": [
            {"name": "ППС «Копейка»", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "lights": true, "rank": 1, "speed": 140.0, "force": 5600.0, "model": "vaz2101_mil"},
            {"name": "ППС «Нива»", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "livery": "МИЛИЦИЯ", "livery_col": Color(0.10, 0.22, 0.65), "lights": true, "rank": 2, "speed": 135.0, "force": 6400.0, "model": "niva"},
            {"name": "ДПС", "kind": "car", "paint": Color(0.93, 0.93, 0.92), "livery": "ДПС", "livery_col": Color(0.15, 0.30, 0.70), "lights": true, "rank": 3, "speed": 170.0, "force": 7000.0, "model": "cop"},
            {"name": "Автозак", "kind": "truck", "paint": Color(0.40, 0.45, 0.55), "livery": "МИЛИЦИЯ", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "rank": 3, "speed": 100.0, "force": 22000.0},
            {"name": "Оперативный УАЗ", "kind": "car", "paint": Color(0.95, 0.78, 0.12), "livery": "МИЛИЦИЯ", "livery_col": Color(0.10, 0.22, 0.65), "lights": true, "rank": 4, "speed": 115.0, "force": 5200.0, "model": "uaz452"},
            {"name": "Волга ГАИ", "kind": "car", "paint": Color(0.93, 0.93, 0.92), "livery": "МИЛИЦИЯ", "livery_col": Color(0.15, 0.30, 0.70), "lights": true, "rank": 5, "speed": 165.0, "force": 7200.0, "model": "volga"},
            {"name": "Волга начальника", "kind": "car", "paint": Color(0.05, 0.05, 0.06), "rank": 6, "speed": 170.0, "force": 7600.0, "model": "volga"},
        ]},
    {"id": "hospital_p", "base": "hospital", "emblem": "hospital", "city": "pyat", "name": "Больница Пятигорска", "title": "БОЛЬНИЦА ПЯТИГОРСКА",
        "color": Color(0.85, 0.20, 0.20), "wall": Color(0.88, 0.92, 0.86), "vehicles": [
            {"name": "Скорая помощь", "kind": "car", "paint": Color(0.95, 0.95, 0.93), "livery": "СКОРАЯ", "livery_col": Color(0.85, 0.12, 0.12), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 1, "speed": 120.0, "force": 4800.0, "model": "uaz452"},
            {"name": "Главврач", "kind": "car", "paint": Color(0.08, 0.08, 0.09), "rank": 5, "speed": 170.0, "force": 7400.0, "model": "sedan"},
        ]},
    {"id": "fire_p", "base": "fire", "emblem": "fire", "city": "pyat", "name": "Пожарная часть Пятигорска", "title": "ПОЖАРНАЯ ЧАСТЬ №2",
        "color": Color(0.85, 0.25, 0.10), "wall": Color(0.90, 0.82, 0.76), "vehicles": [
            {"name": "Пожарная машина", "kind": "truck", "paint": Color(0.78, 0.10, 0.08), "livery": "ПОЖАРНАЯ", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 1, "speed": 100.0, "force": 24000.0},
            {"name": "Командирская", "kind": "car", "paint": Color(0.78, 0.10, 0.08), "livery": "МЧС", "livery_col": Color(0.95, 0.95, 0.95), "lights": true, "light_b": Color(0.2, 0.4, 1.0), "rank": 3, "speed": 150.0, "force": 6000.0, "model": "suv"},
        ]},
]


## Дресс-код: ткани верха, низа и обуви + лампасы, светоотражайка, жилет, шеврон.
## "from" — с какого ранга вариант (берётся последний подходящий).
const UNIFORMS := {
    "police": [
        {"from": 1, "jacket": "uni_militia", "pants": "uni_navy", "shoes": "cloth_leather_black", "badge": true},
        {"from": 2, "jacket": "uni_militia", "pants": "uni_navy", "shoes": "cloth_leather_black", "badge": true, "vest": true, "tape": true},
        {"from": 5, "jacket": "uni_shirt", "pants": "uni_navy", "shoes": "cloth_leather_black", "badge": true, "short": true},
    ],
    "kgb": [{"from": 1, "jacket": "uni_kgb", "pants": "uni_kgb", "shoes": "cloth_leather_black", "badge": true}],
    "mayor": [{"from": 1, "jacket": "uni_mayor", "pants": "uni_mayor", "shoes": "cloth_leather_black", "badge": true}],
    "hospital": [
        {"from": 1, "jacket": "uni_scrubs", "pants": "uni_scrubs", "shoes": "cloth_canvas_white", "badge": true, "short": true},
        {"from": 3, "jacket": "uni_doctor", "pants": "uni_scrubs", "shoes": "cloth_canvas_white", "badge": true},
    ],
    "fire": [{"from": 1, "jacket": "uni_canvas", "pants": "uni_canvas", "shoes": "cloth_rubber_black", "badge": true, "tape": true}],
    "tyap": [
        {"from": 1, "jacket": "ts_green", "pants": "ts_green", "shoes": "cloth_sneaker", "lampas": true},
        {"from": 5, "jacket": "cloth_leather_black", "pants": "ts_green", "shoes": "cloth_leather_black", "lampas": true},
    ],
    "universam": [
        {"from": 1, "jacket": "ts_blue", "pants": "ts_blue", "shoes": "cloth_sneaker", "lampas": true},
        {"from": 5, "jacket": "cloth_leather_black", "pants": "ts_blue", "shoes": "cloth_leather_black", "lampas": true},
    ],
    "solnce": [
        {"from": 1, "jacket": "ts_yellow", "pants": "cloth_wool_black", "shoes": "cloth_sneaker", "lampas": true},
        {"from": 5, "jacket": "cloth_leather_brown", "pants": "cloth_wool_black", "shoes": "cloth_leather_brown"},
    ],
    "kavkaz": [
        {"from": 1, "jacket": "velour", "pants": "cloth_wool_black", "shoes": "cloth_leather_black"},
        {"from": 5, "jacket": "cloth_leather_black", "pants": "cloth_wool_black", "shoes": "cloth_leather_black"},
    ],
}


static func uniform(id: String, rank: int) -> Dictionary:
    var out := {}
    for u: Dictionary in UNIFORMS.get(base(id), []):
        if rank >= int(u["from"]):
            out = u
    return out


static func get_faction(id: String) -> Dictionary:
    for f: Dictionary in LIST:
        if f["id"] == id:
            return f
    return {}


## Вид фракции: у городских отделений («police_p») — как у главной («police»).
static func base(id: String) -> String:
    return String(get_faction(id).get("base", id))


## Город фракции: "kazan" или "pyat".
static func city(id: String) -> String:
    return String(get_faction(id).get("city", "kazan"))


static func is_gang(id: String) -> bool:
    return String(get_faction(id).get("type", "state")) == "gang"


static func ranks(id: String) -> Array:
    return GANG_RANKS if is_gang(id) else RANKS


static func limits(id: String) -> Array:
    return GANG_LIMITS if is_gang(id) else RANK_LIMITS


static func salary(id: String, rank: int) -> int:
    var list: Array = GANG_SALARY if is_gang(id) else SALARY
    return int(list[clampi(rank, 1, list.size()) - 1])


## «Заместитель (СС)», «Пешка» и т. п.
static func rank_name(rank: int, id := "") -> String:
    var names := ranks(id)
    var i := clampi(rank, 1, names.size()) - 1
    var tag: String = RANK_TAGS[i]
    return String(names[i]) + (" (%s)" % tag if tag != "" else "")
