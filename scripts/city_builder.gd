extends Node3D
## Генератор района в духе российского спального микрорайона:
## панельные девятиэтажки, хрущёвки, башни, дворы с детскими площадками,
## гаражи, ларьки, остановка, фонари, берёзы, припаркованные машины.
## Всё строится из примитивов. Мелочи (балконы, деревья, фонари, машины)
## рисуются через MultiMesh — один draw call на вид объекта.

const CarModel := preload("res://scripts/car_model.gd")
const FactionData := preload("res://scripts/faction_data.gd")
## Карта — три острова в море, между ними мосты:
##   Казань (большой, в центре) —длинный мост на запад— Пятигорск;  Казань —короткий мост на юг— село Бусаево.
## Казань: мэрия, милиция, больница, ОПГ «Солнечные» и «Кавказ», автосалон, вокзал.
const FACTION_BLOCKS := {Vector2i(0, -1): "mayor", Vector2i(1, 0): "police", Vector2i(-1, 0): "hospital"}
## Районы ОПГ Казани: база — гараж.
const GANG_BLOCKS := {Vector2i(-3, 3): "solnce", Vector2i(3, -3): "kavkaz"}
## Пятигорск — остров на западе: милиция, больница, КГБ, ОПГ «Тяп-Ляп» и «Универсам», рынок, вокзал.
const PY_ORG := Vector3(-1100.0, 0.0, 0.0)
const PY_GRID := 2
const PY_FACTION_BLOCKS := {Vector2i(1, 0): "police_p", Vector2i(-1, 0): "hospital_p", Vector2i(0, -1): "kgb"}
const PY_GANG_BLOCKS := {Vector2i(-2, 2): "tyap", Vector2i(2, -2): "universam"}
## Море между Казанью и Пятигорском: RIVER_X1 — западный берег Казани, RIVER_X0 — восточный берег Пятигорска.
const RIVER_X0 := -800.0
const RIVER_X1 := -520.0
## Острова: прямоугольники суши (x, z, ширина, глубина). Вокруг — море и гранитная набережная.
const ISLAND_KAZAN := Rect2(-520.0, -500.0, 1040.0, 930.0)
const ISLAND_PYAT := Rect2(-1400.0, -330.0, 600.0, 630.0)
const ISLAND_VILLAGE := Rect2(-160.0, 470.0, 410.0, 350.0)
const VILLAGE_BRIDGE := Vector2(430.0, 470.0)   # мост в село: от берега Казани до берега села (по z, на x = 43)

const BLOCK := 72.0      # размер квартала, м
const ROAD := 14.0       # ширина дороги, м
const PITCH := BLOCK + ROAD
const GRID := 4          # кварталы Казани от -GRID до GRID (9x9)
const OUT := (GRID - 2) * PITCH   # насколько окраины отодвинуты из-за роста города
const NORTH := -(OUT - PITCH)     # вокзал и автошкола отодвинуты на север вместе с краем города
const SIDE_H := 0.08     # высота тротуара (низкая — персонаж и машина заезжают)
const WALK := 4.0        # ширина тротуара
const FLOOR_H := 2.8     # высота этажа
const CELL := 3.0        # шаг окон по фасаду

const PARKED_COLORS := [
    Color(0.92, 0.92, 0.90), Color(0.45, 0.06, 0.10), Color(0.12, 0.30, 0.22),
    Color(0.15, 0.20, 0.40), Color(0.10, 0.10, 0.11), Color(0.62, 0.64, 0.66),
]

var rng := RandomNumberGenerator.new()

var _defs := {}      # вид объекта -> меш, материал, дальность, тень
var _batches := {}   # "вид|кусок" -> трансформы и цвета
var _occupied: Array[Rect2] = []
var _c := Vector3.ZERO   # центр текущего квартала
var _city_org := Vector3.ZERO   # центр строящегося города
var _city_id := "kazan"         # "kazan" или "pyat"
var _cur_grid := GRID
var _mx := 1.0           # зеркалирование шаблона квартала
var _mz := 1.0

var _panel_mats: Array[StandardMaterial3D] = []
var _brick_mats: Array[StandardMaterial3D] = []
var _tower_mats: Array[StandardMaterial3D] = []   # высотки-«свечки» (если есть текстура)
var _stalin_mats: Array[StandardMaterial3D] = []  # жёлтые сталинки (Пятигорск и центр Казани)
var _m := {}

# --- данные для мини-карты и работ (читают main.gd, minimap.gd, job_courier.gd)
var extent := (GRID + 0.5) * PITCH + ROAD * 0.5   # половина размера города
var block_rects: Array[Rect2] = []
var map_land: Array[Rect2] = [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]   # острова (для мини-карты)
var map_roads: Array[Rect2] = []      # дороги городов, мосты и трассы (для мини-карты)
var building_rects: Array[Rect2] = []
var pickups: Array[Dictionary] = []   # {"pos": Vector3, "name": String} — ларьки, магазины
var dropoffs: Array[Vector3] = []     # точки у подъездов
var entrances: Array[Dictionary] = []  # двери подъездов: {"pos", "out"} — можно зайти
var podezd := {}                       # интерьер подъезда: {"spawn", "exit", "flat"}
var lamp_mat: StandardMaterial3D      # фонари: ярче ночью
var pool_mat: StandardMaterial3D = null   # пятна света под фонарями
var cone_mat: StandardMaterial3D = null
var lamp_positions: Array[Vector3] = []  # где висят плафоны (для света ночью)
var road_lines: Array[float] = []     # координаты осей дорог (для трафика)
var market := Vector3.ZERO            # вход в рынок Пятигорска (одежда, прочее)
var autosalon := Vector3.ZERO         # автосалон Казани (машины)
var city_hall := Vector3.ZERO         # мэрия (паспорт)
var driving_school := Vector3.ZERO    # автошкола
var atms: Array[Vector3] = []         # банкоматы (где стоять)
var fuel_pumps: Array[Vector3] = []   # колонки АЗС (где встать машиной)
var gas_shops: Array[Vector3] = []    # магазины при АЗС (вход пешком — бизнес)
var service_stations: Array[Vector3] = []   # СТО: куда заехать на машине
## Погода: насколько мокро (0..1) и сколько снега (0..1). Задаёт main.gd через set_weather().
var _wet := 0.0
var _snow := 0.0
var kpz_cell := Vector3.ZERO          # камера КПЗ в отделе милиции (куда сажают задержанных)
var bus_stops: Array[Vector3] = []    # точки остановки автобуса на полосе
var bus_depot := Vector3.ZERO         # где взять автобус
var warehouse_pick := Vector3.ZERO    # грузчик: где брать коробки
var warehouse_drop := Vector3.ZERO    # грузчик: куда относить
var truck_depot := Vector3.ZERO       # дальнобойщик: где взять фуру
var truck_drops: Array[Vector3] = []  # дальнобойщик: куда возить
var forest_trees: Array[Vector3] = [] # лесоруб: деревья под рубку
var log_pile := Vector3.ZERO          # лесоруб: куда носить брёвна
## Фракции: id -> {"door", "marker", "spawn", "out_yaw", "name"} — вход, метка автопарка, где появляется машина.
var faction_sites := {}
## Интерьеры: id -> {"spawn", "exit", "hr", "desk"} — комнаты стоят далеко за городом.
var interiors := {}
## Жильё: {"pos" — где стоять у двери, "kind" ("flat"/"house"), "price", "addr", "label" (Label3D)}.
var homes: Array[Dictionary] = []
## Интерьеры жилья: "flat"/"house" -> {"spawn", "exit", "fridge", "bed"}.
var home_interiors := {}
const STREETS := ["ул. Баумана", "ул. Ленина", "ул. Декабристов", "ул. Гагарина", "ул. Чистопольская",
        "пр. Победы", "ул. Пушкина", "ул. Мира", "ул. Строителей", "ул. Космонавтов", "ул. Садовая"]
## Лозунги на крышах — как на домах Казани 80-х.
const SLOGANS := ["СЛАВА ТРУДУ!", "МИРУ — МИР!", "СЛАВА СОВЕТСКОМУ НАРОДУ!", "ПЯТИЛЕТКУ — ДОСРОЧНО!",
        "НАРОД И ПАРТИЯ ЕДИНЫ", "ТРУД, МИР, МАЙ!"]
var _street_nums := {}
var _fb := Basis()                 # поворот квартала фракции (фасад смотрит к площади)
var _ff := Vector3(0, 0, 1)


func _ready() -> void:
    rng.seed = 1977
    _make_materials()
    _define_batches()
    _build_ground()
    for i in range(-GRID, GRID + 1):
        for j in range(-GRID, GRID + 1):
            _build_block(i, j)
    _build_road_marks()
    _build_road_signs()
    # Пятигорск за рекой
    _city_org = PY_ORG
    _city_id = "pyat"
    _cur_grid = PY_GRID
    var py_lines: Array[float] = []
    for k: int in range(-PY_GRID - 1, PY_GRID + 1):
        py_lines.append((k + 0.5) * PITCH)
    var py_ext := (PY_GRID + 0.5) * PITCH + ROAD * 0.5
    _flat(PY_ORG, Vector2(py_ext * 2.0, py_ext * 2.0), _m["asphalt"], 0.004)
    map_roads.append(Rect2(PY_ORG.x - py_ext, PY_ORG.z - py_ext, py_ext * 2.0, py_ext * 2.0))
    for i in range(-PY_GRID, PY_GRID + 1):
        for j in range(-PY_GRID, PY_GRID + 1):
            _build_block(i, j)
    _road_marks_at(PY_ORG, PY_GRID, py_lines)
    _city_org = Vector3.ZERO
    _city_id = "kazan"
    _cur_grid = GRID
    _build_sea_and_bridges()
    _build_outskirts()
    _build_interiors()
    _build_cottages()
    _build_village()
    _build_billboards()
    _service(Vector3(243 + OUT, 0, -14), Vector3(0, 0, 1))
    _service(Vector3(-248 - OUT, 0, -48), Vector3(0, 0, 1))
    _shore_life()
    _build_home_interiors()
    _build_podezd()
    _build_decals()
    _build_horizon()
    _flush_batches()


# ================================================================ кварталы

func _build_block(i: int, j: int) -> void:
    _c = _city_org + Vector3(i * PITCH, 0.0, j * PITCH)
    var kazan := _city_id == "kazan"
    var is_center := i == 0 and j == 0
    _mx = 1.0 if is_center or rng.randf() < 0.5 else -1.0
    _mz = 1.0 if is_center or rng.randf() < 0.5 else -1.0

    _solid(Vector3(BLOCK, SIDE_H, BLOCK), _c + Vector3(0, SIDE_H * 0.5, 0), _m["sidewalk"])
    block_rects.append(Rect2(_c.x - BLOCK * 0.5, _c.z - BLOCK * 0.5, BLOCK, BLOCK))
    var inner := BLOCK - WALK * 2.0
    _flat(_c, Vector2(inner, inner), _m["paving"] if is_center else _m["grass"], SIDE_H + 0.004)

    var fkey := Vector2i(i, j)
    var fblocks: Dictionary = FACTION_BLOCKS if kazan else PY_FACTION_BLOCKS
    var gblocks: Dictionary = GANG_BLOCKS if kazan else PY_GANG_BLOCKS
    if is_center:
        if kazan:
            _tpl_square()
        else:
            _tpl_square_py()
    elif fblocks.has(fkey):
        _mx = 1.0
        _mz = 1.0
        _tpl_faction(fblocks[fkey], Vector2(-i, -j))
    elif gblocks.has(fkey):
        _mx = 1.0
        _mz = 1.0
        _tpl_gang(gblocks[fkey], Vector2(-i, -j))
    elif kazan and i == GRID and j == GRID:
        _mx = 1.0
        _mz = 1.0
        _tpl_industrial()
    else:
        match rng.randi() % 4:
            0:
                _tpl_two_panels()
            1:
                _tpl_corner()
            2:
                _tpl_khrushchevki()
            _:
                _tpl_towers()

    if not is_center:
        _block_bus_stop()
    _edge_lamps_and_trees()
    _scatter_trees(5 if is_center else 14)


## Центральная площадь: стела, клумбы, ларьки, остановка. Здесь появляется игрок.
func _tpl_square() -> void:
    var mon := _p(0, -12)
    _solid(Vector3(4.0, 1.0, 4.0), mon + Vector3(0, 0.5, 0), _m["granite"])
    _solid(Vector3(1.4, 10.0, 0.9), mon + Vector3(0, 6.0, 0), _m["granite"])
    _occupy(mon, 7.0, 7.0)

    for x: float in [-12.0, 12.0]:
        for z: float in [-12.0, 4.0]:
            var bed := _p(x, z)
            _solid(Vector3(4.0, 0.4, 4.0), bed + Vector3(0, 0.2, 0), _m["granite"])
            _deco(Vector3(3.6, 0.42, 3.6), bed + Vector3(0, 0.21, 0), _m["flowers"])
            for k in 6:
                var off := Vector3(rng.randf_range(-1.2, 1.2), 0.55, rng.randf_range(-1.2, 1.2))
                var col := Color(0.85, 0.15, 0.2) if rng.randf() < 0.5 else Color(0.95, 0.75, 0.2)
                if _has_foliage_tex:
                    col = Color(1, 1, 1)   # с текстурой — зелёные кустики среди цветов
                _put("bush", bed + off, 0.0, col, Vector3(0.6, 0.5, 0.6))
            _occupy(bed, 5.0, 5.0)

    for x: float in [-4.0, 4.0]:
        _bench(_p(x, -6.5), Vector3(0, 0, -1))
    _bench(_p(-6.5, -12), Vector3(1, 0, 0))
    _bench(_p(6.5, -12), Vector3(-1, 0, 0))

    _kiosk(_p(-27, -27), Vector3(0, 0, 1), "ПИРОЖКИ", Color(0.85, 0.55, 0.15))
    _kiosk(_p(27, -27), Vector3(0, 0, 1), "ПРОДУКТЫ", Color(0.20, 0.50, 0.75))
    _kiosk(_p(-27, 10), Vector3(1, 0, 0), "ЦВЕТЫ", Color(0.30, 0.60, 0.30))
    _kiosk(_p(27, 10), Vector3(-1, 0, 0), "ПЕЧАТЬ", Color(0.70, 0.20, 0.20))
    _kiosk(_p(-27, -9), Vector3(1, 0, 0), "КОФЕ", Color(0.45, 0.30, 0.20))
    _autosalon(_p(0, 29))
    _kiosk(_p(27, -9), Vector3(-1, 0, 0), "КВАС", Color(0.75, 0.45, 0.10))
    _kiosk(_p(-27, 22), Vector3(1, 0, 0), "ГАЗЕТЫ", Color(0.90, 0.50, 0.10), false)
    driving_school = _p(-27, 22) + Vector3(2.8, 0, 0)   # если отдельного здания нет
    _kiosk(_p(27, 22), Vector3(-1, 0, 0), "ВИДЕОСАЛОН", Color(0.25, 0.20, 0.45), false)
    _atm(_p(-7, -29), Vector3(0, 0, 1))
    _atm(_p(7, -29), Vector3(0, 0, 1))
    _bus_stop(_p(21, 31), Vector3(0, 0, 1))
    bus_depot = _p(21, 29)
    bus_spawn = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(14, 0.9, 46.5))
    bus_stops.append(Vector3(21, 0, 39.5))

    _occupy(_p(0, 20), 40.0, 6.0)   # стоянка у автосалона: сюда доставляют купленные машины
    _occupy(_p(0, 14), 10.0, 6.0)   # точка появления игрока


## Две длинные панельки, двор между ними.
func _tpl_two_panels() -> void:
    var floors := 9 if rng.randf() < 0.7 else 12
    _building(_p(0, -21), 54.0, 12.0, floors, true, "panel", _d(0, 1))
    _building(_p(0, 21), 54.0, 12.0, floors, true, "panel", _d(0, -1))
    _playground(_p(-9, 0))
    _parking(_p(10, -11.5), true, 6)
    _parking(_p(10, 11.5), true, 6)


## Панельки буквой «Г» + хрущёвка, гаражи.
func _tpl_corner() -> void:
    _building(_p(-3, -24), 54.0, 12.0, 9, true, "panel", _d(0, 1))
    _building(_p(24, 9), 42.0, 12.0, 9, false, "panel", _d(-1, 0))
    _building(_p(-12, 20), 36.0, 11.0, 5, true, "brick", _d(0, -1))
    _playground(_p(-4, -4))
    _garages(_p(-27, -1), 6, false, _d(1, 0))
    _parking(_p(11, 6), false, 5)


## Три хрущёвки и ряд гаражей.
func _tpl_khrushchevki() -> void:
    for z: float in [-22.0, 0.0, 22.0]:
        _building(_p(-7, z), 42.0, 11.0, 5, true, "brick", _d(0, 1))
    _garages(_p(26, 0), 10, false, _d(-1, 0))
    for z: float in [-11.0, 11.0]:
        _bench(_p(-14, z), _d(0, 1))
        _bench(_p(0, z), _d(0, 1))


## Две башни, универсам, большая парковка.
func _tpl_towers() -> void:
    _building(_p(-14, -14), 18.0, 18.0, 16, true, "tower", _d(0, 1))
    _building(_p(14, 15), 18.0, 18.0, 14, true, "tower", _d(0, -1))
    _shop(_p(14, -21), 26.0, 12.0, _d(0, -1), "УНИВЕРСАМ")
    _playground(_p(2, -1))
    _parking(_p(-14, 14), true, 7)
    _parking(_p(-14, 22), true, 7)
    _kiosk(_p(-28, -28), _d(0, -1), "АПТЕКА", Color(0.25, 0.65, 0.45))


# ================================================================ здания

## center — середина основания; along_x — длинная сторона вдоль X;
## entrance — направление фасада с подъездами (или ZERO).
func _building(center: Vector3, length: float, depth: float, floors: int,
        along_x: bool, style: String, entrance: Vector3) -> void:
    var sx := length if along_x else depth
    var sz := depth if along_x else length
    var h := floors * FLOOR_H
    var base := Vector3(center.x, 0.0, center.z)
    var mat: Material
    if style == "brick":
        mat = _brick_mats[rng.randi() % _brick_mats.size()]
    elif style == "tower" and not _tower_mats.is_empty():
        mat = _tower_mats[rng.randi() % _tower_mats.size()]
    else:
        mat = _panel_mats[rng.randi() % _panel_mats.size()]
    # Сталинки: в Пятигорске — почти все невысокие дома, в Казани — часть кирпичных.
    # Выбор по координатам, а не rng: планировка города не меняется.
    if not _stalin_mats.is_empty() and style != "tower" and floors <= 9:
        var hh := int(absf(base.x * 3.0 + base.z * 5.0))
        var pyat := _city_id == "pyat"
        if (pyat and (style == "brick" or hh % 2 == 0)) or (not pyat and style == "brick" and hh % 3 == 0):
            mat = _stalin_mats[hh % _stalin_mats.size()]

    # Панельки и высотки — готовые модели серии 1ЛГ-600А (models/houses), если есть.
    _model_kind = ""
    var use_model := not _stalin_mats.has(mat) and _house_model(base, sx, sz, h, floors, style, entrance)
    if use_model:
        _collider(Vector3(sx, h, sz), base + Vector3(0, h * 0.5, 0))
    else:
        _solid(Vector3(sx, h, sz), base + Vector3(0, h * 0.5, 0), mat)
    _deco(Vector3(sx + 0.2, 0.7, sz + 0.2), base + Vector3(0, 0.35, 0), _m["plinth"])
    if not use_model:
        _deco(Vector3(sx + 0.3, 0.45, sz + 0.3), base + Vector3(0, h + 0.2, 0), _m["roof"])
    _occupy(base, sx, sz)
    building_rects.append(Rect2(base.x - sx * 0.5, base.z - sz * 0.5, sx, sz))
    for wn: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
        var half := (sx if absf(wn.x) > 0.5 else sz) * 0.5
        _wall_spots.append([base + wn * half, wn, h, floors <= 5])

    # Балконы
    var every := 3 if style == "brick" else 2
    var faces: Array[Vector3] = []
    if style == "tower":
        faces = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    elif along_x:
        faces = [Vector3(0, 0, 1), Vector3(0, 0, -1)]
    else:
        faces = [Vector3(1, 0, 0), Vector3(-1, 0, 0)]
    for n: Vector3 in faces:
        var facade_x := absf(n.z) > 0.5          # фасад тянется вдоль X
        var half := (sx if facade_x else sz) * 0.5
        var mid := base.x if facade_x else base.z
        var out := (sz if facade_x else sx) * 0.5 + 0.5
        var k0 := int(ceil((mid - half + 1.5) / CELL - 0.5))
        var k1 := int(floor((mid + half - 1.5) / CELL - 0.5))
        for k: int in range(k0, k1 + 1):
            if posmod(k, every) != 0:
                continue
            var u := (k + 0.5) * CELL
            for f: int in range(1, floors):
                var y := f * FLOOR_H + 0.52
                var pos := Vector3(u, y, base.z + n.z * out) if facade_x else Vector3(base.x + n.x * out, y, u)
                var br := rng.randf()   # rng тратим всегда — чтобы планировка города не менялась
                if not use_model:       # у моделей свои балконы и лоджии
                    _balcony(pos, n, br)

    # Лозунг на крыше: красные буквы на металлической раме (у части высоких домов)
    if floors >= 9 and int(absf(base.x * 3.0 + base.z * 5.0)) % 4 == 1:
        var long_x := sx >= sz
        var lfront := Vector3(0, 0, 1) if long_x else Vector3(1, 0, 0)
        var text: String = SLOGANS[int(absf(base.x + base.z * 2.0)) % SLOGANS.size()]
        var lw := minf((sx if long_x else sz) - 4.0, text.length() * 1.6)
        var ly := h + 0.45 + 1.5
        for t: float in [-0.45, 0.0, 0.45]:
            var post := base + (Vector3(lw * t, 0, 0) if long_x else Vector3(0, 0, lw * t))
            _deco(Vector3(0.12, 3.0, 0.12), post + Vector3(0, h + 0.45 + 1.5, 0), _m["metal"])
        _deco(Vector3(lw, 0.1, 0.1) if long_x else Vector3(0.1, 0.1, lw), base + Vector3(0, ly + 1.4, 0), _m["metal"])
        var sl := Label3D.new()
        sl.text = text
        sl.font_size = 220
        sl.pixel_size = 0.012
        sl.modulate = Color(0.85, 0.08, 0.06)
        sl.outline_size = 0
        sl.position = base + Vector3(0, ly, 0)
        sl.rotation.y = 0.0 if long_x else PI * 0.5
        sl.visibility_range_end = 380.0
        add_child(sl)

    # Советская мозаика на глухом торце (у каждого третьего высокого панельного дома)
    if style == "panel" and not use_model and floors >= 9 and int(absf(base.x * 7.0 + base.z * 13.0)) % 3 == 0:
        var en := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
        if int(absf(base.x + base.z)) % 2 == 0:
            en = -en
        var wall_w := sz if along_x else sx
        var mw := minf(wall_w - 1.6, 14.0)
        _mosaic(base + en * ((sx if along_x else sz) * 0.5 + 0.06) + Vector3(0, h * 0.58, 0), en, mw)

    # Подъезды: двери, козырьки, лавочки, машинные отделения лифтов на крыше
    if entrance == Vector3.ZERO:
        return
    var e_x := absf(entrance.z) > 0.5
    var flen := sx if e_x else sz
    var e_out := (sz if e_x else sx) * 0.5
    var axis := Vector3(1, 0, 0) if e_x else Vector3(0, 0, 1)
    var yaw := 0.0 if e_x else PI * 0.5
    var count := maxi(1, int(flen / 14.0))
    var own_doors := _model_kind == "khrush" or _model_kind == "dester"   # у моделей свои двери подъездов
    var rng_count := count                     # rng тратим как раньше — чтобы планировка города не менялась
    var rng_saved := rng.state
    var us: Array = []
    if _model_kind == "khrush":
        count = 4
    if _model_kind == "dester":
        us = _model_doors.duplicate()
        count = us.size()
    # водосточные трубы по углам фасада
    for side: float in [-1.0, 1.0]:
        _put("drainpipe", base + axis * (side * (flen * 0.5 - 0.35)) + entrance * (e_out + 0.12) + Vector3(0, h * 0.5, 0),
                0.0, Color.WHITE, Vector3(1.0, h, 1.0))
    for e: int in range(count):
        var u: float = float(us[e]) if not us.is_empty() else -flen * 0.5 + flen * (e + 0.5) / count
        var p := base + axis * u + entrance * e_out
        if not own_doors:
            _put("door", p + Vector3(0, 1.1, 0) + entrance * 0.06, yaw)
        entrances.append({"pos": p + entrance * 0.9 + Vector3(0, SIDE_H, 0), "out": p + entrance * 1.6 + Vector3(0, SIDE_H, 0)})
        dropoffs.append(p + entrance * 2.5 + Vector3(0, SIDE_H, 0))
        if not own_doors:
            _put("canopy", p + Vector3(0, 2.55, 0) + entrance * 0.65, yaw)
        var path_c := p + entrance * 3.2
        _flat(path_c, Vector2(1.8, 5.0) if e_x else Vector2(5.0, 1.8), _m["path"], SIDE_H + 0.007)
        if style != "brick":
            _put("roof_box", base + axis * u + Vector3(0, h + 1.4, 0), yaw)
        if rng.randf() < 0.6:
            _bench(p + entrance * 1.6 + axis * 2.4 + Vector3(0, SIDE_H, 0), entrance)
        if e == 0:   # одна квартира на продажу в каждом доме — у первого подъезда
            var price := 35000 if style == "brick" else (75000 if style == "tower" else (60000 if floors >= 12 else 50000))
            _add_home(p + entrance * 1.7 + Vector3(0, SIDE_H, 0), p + entrance * 0.9 + Vector3(0, 3.3, 0), "flat", price)
    if count != rng_count:
        rng.state = rng_saved
        for i in rng_count:
            rng.randf()


## Готовая модель панельки: высотка — целиком, длинный дом — из секций по ~28 м, 5-этажка — целиком.
## Модель растягивается точно под размер дома (коллизия и подъезды остаются прежними).
var _model_kind := ""   # какая модель встала на место дома (у хрущёвки свои подъезды)
var _model_doors: Array = []   # где у модели нарисованы/сделаны двери подъездов (смещение вдоль фасада)


func _house_model(base: Vector3, sx: float, sz: float, h: float, floors: int, style: String, entrance := Vector3.ZERO) -> bool:
    var along_x := sx >= sz
    var flen := sx if along_x else sz
    var fdep := sz if along_x else sx
    var yaw := 0.0 if along_x else PI * 0.5
    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    if style == "tower" and _props_ok.has("lg_tower"):
        _put("hs_lg_tower", base, yaw, Color.WHITE, Vector3(flen / 18.71, h / 45.83, fdep / 17.88))
        return true
    # 10-этажка с синей мозаикой (фасад-картинка на коробке) — у части высоких панелек, секциями по ~21 м.
    # Фасад смотрит к подъездам, двери подъездов — там, где они нарисованы (2 на секцию).
    var alt2 := (int(absf(base.x) * 0.53 + absf(base.z) * 0.29) % 2) == 0
    if style == "panel" and floors >= 9 and alt2 and entrance != Vector3.ZERO and _props_ok.has("dester"):
        var nd := maxi(1, roundi(flen / 21.0))
        var sg := flen / nd
        var dyaw := atan2(entrance.x, entrance.z)
        var right := Basis(Vector3.UP, dyaw) * Vector3(1, 0, 0)   # «вправо» по картинке фасада
        var sgn := 1.0 if right.dot(axis) > 0.0 else -1.0
        _model_doors.clear()
        for i in nd:
            var cu := -flen * 0.5 + sg * (i + 0.5)
            _put("hs_dester", base + axis * cu, dyaw, Color.WHITE, Vector3(sg, h, fdep))
            for f: float in [0.075, 0.33]:
                _model_doors.append(cu + sgn * (f - 0.5) * sg)
        _model_kind = "dester"
        return true
    if style == "panel" and floors >= 9 and _props_ok.has("lg_section"):
        var n := maxi(1, roundi(flen / 28.08))
        var seg := flen / n
        for i in n:
            var c := base + axis * (-flen * 0.5 + seg * (i + 0.5))
            _put("hs_lg_section", c, yaw, Color.WHITE, Vector3(seg / 28.08, h / 29.63, fdep / 11.88))
        return true
    # хрущёвка (5 этажей, 4 подъезда с козырьками, балконы, красный цоколь) — у части кирпичных пятиэтажек.
    # Выбор по координатам, а не rng: планировка города не меняется. Подъезды модели — к входу дома.
    var alt := (int(absf(base.x) * 0.37 + absf(base.z) * 0.61) % 2) == 0
    if floors == 5 and (style == "brick" or style == "panel") and alt and entrance != Vector3.ZERO and _props_ok.has("khrush"):
        _put("hs_khrush", base, atan2(-entrance.x, -entrance.z), Color.WHITE, Vector3(flen / 42.74, h / 13.31, fdep / 13.1))
        _model_kind = "khrush"
        return true
    if style == "panel" and floors <= 6 and _props_ok.has("lg_five"):
        _put("hs_lg_five", base, yaw, Color.WHITE, Vector3(flen / 49.68, h / 13.2, fdep / 11.88))
        return true
    return false


func _shop(center: Vector3, length: float, depth: float, front: Vector3, text: String) -> void:
    var along_x := absf(front.z) > 0.5
    var sx := length if along_x else depth
    var sz := depth if along_x else length
    var base := Vector3(center.x, 0.0, center.z)
    var out := (sz if along_x else sx) * 0.5
    var yaw := 0.0 if along_x else PI * 0.5
    _solid(Vector3(sx, 4.2, sz), base + Vector3(0, 2.1, 0), _m["plaster"])
    _deco(Vector3(sx + 0.3, 0.3, sz + 0.3), base + Vector3(0, 4.3, 0), _m["roof"])
    _deco(Vector3(length - 2.0, 2.6, 0.08), base + front * (out + 0.04) + Vector3(0, 1.6, 0), _m["vitrine"], yaw)
    _deco(Vector3(length * 0.6, 1.0, 0.12), base + front * (out + 0.1) + Vector3(0, 3.6, 0), _m["sign"], yaw)
    _label(text, base + front * (out + 0.17) + Vector3(0, 3.6, 0), front, 120, Color(0.8, 0.1, 0.1))
    _occupy(base, sx + 2.0, sz + 2.0)
    building_rects.append(Rect2(base.x - sx * 0.5, base.z - sz * 0.5, sx, sz))
    pickups.append({"pos": base + front * (out + 3.0), "name": text})
    var side := Vector3(front.z, 0.0, -front.x)
    _atm(base + front * (out + 0.5) + side * (length * 0.5 - 1.5) + Vector3(0, SIDE_H, 0), front)


func _garages(center: Vector3, count: int, along_x: bool, facing: Vector3) -> void:
    var flen := count * 3.2
    var size := Vector3(flen, 2.5, 6.0) if along_x else Vector3(6.0, 2.5, flen)
    var base := Vector3(center.x, 0.0, center.z)
    _solid(size, base + Vector3(0, 1.25, 0), _m["garage"])
    _deco(size + Vector3(0.3, -2.4, 0.3), base + Vector3(0, 2.55, 0), _m["roof"])
    _flat(base + facing * 6.0, Vector2(flen, 6.0) if along_x else Vector2(6.0, flen),
            _m["yard_asphalt"], SIDE_H + 0.008)
    _occupy(base, size.x, size.z)
    building_rects.append(Rect2(base.x - size.x * 0.5, base.z - size.z * 0.5, size.x, size.z))
    _occupy(base + facing * 6.0, size.x, size.z)
    _wall_spots.append([base - facing * 3.0, -facing, 2.5, true])

    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    var yaw := 0.0 if along_x else PI * 0.5
    var colors := [Color(0.45, 0.25, 0.15), Color(0.20, 0.35, 0.25), Color(0.25, 0.32, 0.45),
            Color(0.50, 0.50, 0.48), Color(0.55, 0.40, 0.20)]
    for g: int in range(count):
        var u := -flen * 0.5 + 3.2 * (g + 0.5)
        var col: Color = colors[rng.randi() % colors.size()]
        _put("garage_door", base + axis * u + facing * 3.03 + Vector3(0, 1.1, 0), yaw, col)


func _kiosk(p: Vector3, facing: Vector3, text: String, col: Color, is_pickup := true) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    _solid(Vector3(3.2, 2.6, 2.4), p + Vector3(0, 1.3, 0), _tinted("kiosk_siding", col.lightened(0.15), 2.0), yaw)
    _deco(Vector3(2.6, 1.2, 0.05), p + b * Vector3(0, 1.35, 1.21), _m["vitrine"], yaw)
    _deco(Vector3(3.2, 1.0, 0.05), p + b * Vector3(0, 1.3, -1.21), _m["shutter"], yaw)
    _deco(Vector3(3.6, 0.1, 1.0), p + b * Vector3(0, 2.3, 1.6), _tinted("awning", col, 1.5), yaw)
    _deco(Vector3(3.2, 0.55, 0.08), p + b * Vector3(0, 2.95, 1.1), _m["sign"], yaw)
    _label(text, p + b * Vector3(0, 2.95, 1.16), facing, 64, col.darkened(0.3))
    _occupy(p, 4.0, 4.0)
    building_rects.append(Rect2(p.x - 1.6, p.z - 1.6, 3.2, 3.2))
    if is_pickup:
        pickups.append({"pos": p + facing * 2.8, "name": text})


func _bus_stop(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    if _props_ok.has("bus_stop"):
        # готовая модель советского павильона: стенки, крыша, лавка и обрывки афиш
        var ground := Vector3(p.x, SIDE_H, p.z)
        _put("pr_bus_stop", ground, yaw)
        _collider(Vector3(3.6, 2.4, 0.12), ground + b * Vector3(0, 1.2, -0.84), yaw)
        for sx: float in [-1.78, 1.78]:
            _collider(Vector3(0.1, 2.4, 1.7), ground + b * Vector3(sx, 1.2, 0.0), yaw)
        _collider(Vector3(3.0, 0.47, 0.38), ground + b * Vector3(0, 0.235, -0.53), yaw)
        benches.append([ground + b * Vector3(0, 0, -0.5), facing.normalized()])
    else:
        _deco(Vector3(4.2, 0.12, 1.9), p + b * Vector3(0, 2.6, 0.1), _m["blue"], yaw)
        _solid(Vector3(4.0, 2.4, 0.06), p + b * Vector3(0, 1.3, -0.75), _m["glass"], yaw)
        for sx: float in [-2.0, 2.0]:
            _solid(Vector3(0.06, 2.4, 1.4), p + b * Vector3(sx, 1.3, -0.1), _m["glass"], yaw)
        _bench(p + b * Vector3(0, 0, -0.4), facing)
    _soda(p + b * Vector3(3.1, 0, -0.3), facing)
    _solid(Vector3(0.08, 2.8, 0.08), p + b * Vector3(2.7, 1.4, 0.8), _m["metal"], yaw)
    if _signs_ok:
        _sign_plate("bus_stop", p + b * Vector3(2.7, 2.55, 0.83), yaw)
    else:
        _deco(Vector3(0.6, 0.6, 0.04), p + b * Vector3(2.7, 2.6, 0.8), _m["yellow"], yaw)
        _label("А", p + b * Vector3(2.7, 2.6, 0.83), facing, 64, Color(0.1, 0.1, 0.1))
    _label("ОСТАНОВКА", p + b * Vector3(0, 2.6, 1.07), facing, 40, Color(1, 1, 1))
    _occupy(p, 5.0, 3.0)


# ================================================================ двор

func _playground(c: Vector3) -> void:
    _occupy(c, 11.0, 9.0)
    # резиновое покрытие: красное или зелёное (по положению — без случайных чисел)
    var floor_mat: Material = _m["rubber_red"] if int(absf(c.x + c.z)) % 2 == 0 else _m["rubber_green"]
    _flat(c, Vector2(11.0, 9.0), floor_mat, SIDE_H + 0.01)
    # домик
    _solid(Vector3(1.6, 1.4, 1.6), c + Vector3(-3.6, 0.7, 2.2), _m["playhouse"])
    _deco(Vector3(1.9, 0.15, 1.9), c + Vector3(-3.6, 1.48, 2.2), _m["red"])
    # песочница
    _deco(Vector3(3.0, 0.25, 3.0), c + Vector3(-3, 0.125, -2), _m["sandbox"])
    _deco(Vector3(2.7, 0.26, 2.7), c + Vector3(-3, 0.13, -2), _m["sand"])
    # качели
    var s := c + Vector3(2.5, 0, -2)
    for dx: float in [-1.2, 1.2]:
        _solid(Vector3(0.1, 2.4, 0.1), s + Vector3(dx, 1.2, 0), _m["blue"])
    _deco(Vector3(2.6, 0.1, 0.1), s + Vector3(0, 2.4, 0), _m["blue"])
    _deco(Vector3(0.6, 0.05, 0.35), s + Vector3(0, 0.5, 0), _m["wood"])
    for dx: float in [-0.25, 0.25]:
        _deco(Vector3(0.02, 1.85, 0.02), s + Vector3(dx, 1.43, 0), _m["pipe"])
    # горка
    var g := c + Vector3(1.5, 0, 2.0)
    _deco(Vector3(1.2, 0.1, 1.2), g + Vector3(0, 1.5, 0), _m["red"])
    for px: float in [-0.55, 0.55]:
        for pz: float in [-0.55, 0.55]:
            _solid(Vector3(0.08, 1.5, 0.08), g + Vector3(px, 0.75, pz), _m["pipe"])
    var slide := _deco(Vector3(0.7, 0.06, 2.63), g + Vector3(0, 0.78, 1.7), _m["slide"])
    slide.rotation.x = 0.583
    _solid(Vector3(0.6, 1.6, 0.06), g + Vector3(0, 0.8, -0.65), _m["yellow"])
    # лавочки
    _bench(c + Vector3(-4.5, 0, 3.5), Vector3(0, 0, -1))
    _bench(c + Vector3(-2.0, 0, 3.5), Vector3(0, 0, -1))
    if _signs_ok:
        _sign_post(c + Vector3(5.8, 0, 4.8), 0.0, ["children"])


func _parking(center: Vector3, along_x: bool, slots: int) -> void:
    var flen := slots * 2.7
    _flat(center, Vector2(flen, 6.0) if along_x else Vector2(6.0, flen), _m["yard_asphalt"], SIDE_H + 0.008)
    _occupy(center, flen if along_x else 6.0, 6.0 if along_x else flen)
    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    var yaw := 0.0 if along_x else PI * 0.5
    if _signs_ok:
        _sign_post(center + axis * (flen * 0.5 + 0.8), yaw, ["parking"])
    for s: int in range(slots):
        if rng.randf() < 0.65:
            var flip := PI if rng.randf() < 0.5 else 0.0
            _parked_car(center + axis * (-flen * 0.5 + 2.7 * (s + 0.5)), yaw + flip)


func _parked_car(p: Vector3, yaw: float) -> void:
    var body := StaticBody3D.new()
    body.position = Vector3(p.x, SIDE_H, p.z)
    body.rotation.y = yaw
    add_child(body)
    CarModel.add_collision(body)
    _put("car%d" % (rng.randi() % PARKED_COLORS.size()), body.position, yaw)


## Лавки: [середина сиденья на земле, куда смотрит] — на них можно сесть.
var benches: Array = []


func _bench(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    var base := Vector3(p.x, SIDE_H, p.z)
    benches.append([base, facing.normalized()])
    _put("bench_seat", base + Vector3(0, 0.45, 0), yaw)
    _put("bench_back", base + b * Vector3(0, 0.7, -0.2), yaw)
    _put("bench_leg", base + b * Vector3(-0.75, 0.225, 0), yaw)
    _put("bench_leg", base + b * Vector3(0.75, 0.225, 0), yaw)


## Материал коры/листвы. vc — цвет экземпляра (оттенок кроны) умножается на текстуру.
func _nature(tex_name: String, fallback: Color, meters: float, vc: bool) -> StandardMaterial3D:
    var m := _vc_mat(0.9) if vc else _mat(fallback, 0.9)
    var t := _tex_mip("res://textures/%s.png" % tex_name)
    if t:
        _ground_tex(m, t, Color.WHITE, meters)
        _has_foliage_tex = _has_foliage_tex or vc
    return m


var _has_foliage_tex := false


var _props_ok := {}      # какие готовые модели есть: "bus_stop", "gas_station", "militia"
var _nature_keys := {}   # "birch" -> ["nt_birch1", ...]


## Меш готового дерева из models/nature (null — модели нет, тогда дерево из кода).
func _nature_mesh(model: String, folder := "nature") -> Mesh:
    var path := "res://models/%s/%s.gltf" % [folder, model]
    if not ResourceLoader.exists(path):
        return null
    var ps = load(path)
    if not (ps is PackedScene):
        return null
    var root: Node = (ps as PackedScene).instantiate()
    var found: Mesh = null
    for n: Node in root.find_children("*", "MeshInstance3D", true, false):
        found = (n as MeshInstance3D).mesh
        break
    root.free()
    return found


func _nature_key(kind: String) -> String:
    var keys: Array = _nature_keys.get(kind, [])
    if keys.is_empty():
        return ""
    return String(keys[rng.randi() % keys.size()])


## Ель: ствол и конус хвои (для леса за городом).
func _pine(p: Vector3) -> void:
    var s := rng.randf_range(0.8, 1.3)
    var base := Vector3(p.x, 0.0, p.z)
    var nk := _nature_key("pine")
    if nk != "":
        _put(nk, base, rng.randf() * TAU, Color.WHITE, Vector3.ONE * 3.2 * s)
        _occupy(base, 1.5, 1.5)
        return
    _put("pine_trunk", base + Vector3(0, 1.5 * s, 0), 0.0, Color.WHITE, Vector3(s, s, s))
    _put("pine_crown", base + Vector3(0, 5.2 * s, 0), rng.randf() * TAU,
            Color(1, 1, 1).lerp(Color(0.8, 0.9, 0.8), rng.randf()), Vector3(s, s, s))
    _occupy(base, 1.5, 1.5)


func _tree(p: Vector3) -> void:
    var s := rng.randf_range(0.85, 1.2)
    var sc := Vector3(s, s, s)
    var base := Vector3(p.x, SIDE_H, p.z)
    var nk := _nature_key("birch" if rng.randf() < 0.55 else "tree")
    if nk != "":
        _put(nk, base, rng.randf() * TAU, Color.WHITE, Vector3.ONE * (3.0 if nk.contains("birch") else 3.4) * s)
        _occupy(base, 1.5, 1.5)
        return
    if rng.randf() < 0.55:  # берёза
        _put("birch", base + Vector3(0, 2.75 * s, 0), 0.0, Color.WHITE, sc)
        var bk := rng.randf()
        var bcol := Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.75), bk) if _has_foliage_tex \
                else Color(0.42, 0.62, 0.25).lerp(Color(0.55, 0.70, 0.30), bk)
        _put("birch_crown", base + Vector3(0, 5.6 * s, 0), rng.randf() * TAU, bcol, sc)
    else:                   # тополь / липа
        _put("trunk", base + Vector3(0, 1.3 * s, 0), 0.0, Color.WHITE, sc)
        var ck := rng.randf()
        var ccol := Color(0.9, 0.9, 0.9).lerp(Color(1.0, 1.05, 0.85), ck) if _has_foliage_tex \
                else Color(0.22, 0.42, 0.18).lerp(Color(0.35, 0.52, 0.22), ck)
        _put("crown", base + Vector3(0, 3.9 * s, 0), rng.randf() * TAU, ccol, sc)
    _occupy(base, 1.5, 1.5)


func _scatter_trees(n: int) -> void:
    for k in n:
        var p := _c + Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))
        if _is_free(p, 2.0):
            _tree(p)


func _edge_lamps_and_trees() -> void:
    var h := BLOCK * 0.5
    for t: float in [-24.0, 0.0, 24.0]:
        _lamp(_c + Vector3(t, SIDE_H, -h + 0.8), Vector3(0, 0, -1))
        _lamp(_c + Vector3(t, SIDE_H, h - 0.8), Vector3(0, 0, 1))
        _lamp(_c + Vector3(-h + 0.8, SIDE_H, t), Vector3(-1, 0, 0))
        _lamp(_c + Vector3(h - 0.8, SIDE_H, t), Vector3(1, 0, 0))
    for t: float in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
        for p: Vector3 in [Vector3(t, 0, -h + 6), Vector3(t, 0, h - 6), Vector3(-h + 6, 0, t), Vector3(h - 6, 0, t)]:
            var w := _c + p
            if _is_free(w, 1.5):
                _tree(w)


func _lamp(base: Vector3, toward: Vector3) -> void:
    var yaw := 0.0 if absf(toward.x) < 0.5 else PI * 0.5
    _put("pole", base + Vector3(0, 3.5, 0))
    _put("lamp_arm", base + Vector3(0, 6.9, 0) + toward * 0.75, yaw)
    _put("lamp_head", base + Vector3(0, 6.85, 0) + toward * 1.45, yaw)
    lamp_positions.append(base + Vector3(0, 6.6, 0) + toward * 1.45)
    var lp := base + toward * 1.45
    _put("light_pool", Vector3(lp.x, base.y + 0.05, lp.z))
    _put("light_cone", lp + Vector3(0, 3.4, 0))


# ================================================================ земля и дороги

func _build_ground() -> void:
    var body := StaticBody3D.new()
    add_child(body)
    var shape := BoxShape3D.new()
    shape.size = Vector3(6000, 2, 6000)
    var col := CollisionShape3D.new()
    col.shape = shape
    col.position = Vector3(-300, -1.0, 0)
    body.add_child(col)
    for isl: Rect2 in [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]:
        _flat(Vector3(isl.get_center().x, 0, isl.get_center().y), isl.size, _m["wasteland"], 0.0)
    var roads := ((GRID + 0.5) * PITCH + ROAD * 0.5) * 2.0
    _flat(Vector3.ZERO, Vector2(roads, roads), _m["asphalt"], 0.004)
    map_roads.append(Rect2(-roads * 0.5, -roads * 0.5, roads, roads))


## Пунктир по центру дорог и зебры у каждого перекрёстка.
func _build_road_marks() -> void:
    var lines: Array[float] = []
    for k: int in range(-GRID - 1, GRID + 1):
        lines.append((k + 0.5) * PITCH)
    road_lines = lines
    _road_marks_at(Vector3.ZERO, GRID, lines)


func _road_marks_at(org: Vector3, grid: int, lines: Array[float]) -> void:
    var extent := (grid + 0.5) * PITCH
    for r: float in lines:
        var t := -extent
        while t <= extent:
            if _dist_to_lines(t, lines) > ROAD * 0.5 + 5.0:
                _put("dash", org + Vector3(r, 0.012, t))
                _put("dash", org + Vector3(t, 0.012, r), PI * 0.5)
            t += 5.0

    var arms: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for rx: float in lines:
        for rz: float in lines:
            for dir: Vector3 in arms:
                var cpos := Vector3(rx, 0.012, rz) + dir * (ROAD * 0.5 + 2.2)
                if absf(cpos.x) > extent or absf(cpos.z) > extent:
                    continue
                var across := Vector3(-dir.z, 0, dir.x)
                var yaw := 0.0 if absf(dir.x) < 0.5 else PI * 0.5
                for s: int in range(-5, 6):
                    _put("zebra", org + cpos + across * (s * 1.15), yaw)


func _dist_to_lines(t: float, lines: Array[float]) -> float:
    var best := INF
    for l: float in lines:
        best = minf(best, absf(t - l))
    return best


# ================================================================ материалы

func _make_materials() -> void:
    # Фасады: картинки из textures/, если есть, иначе рисуем кодом.
    # Процедурные текстуры строим всегда: они расходуют случайные числа, и от этого
    # зависит планировка кварталов — так город не «переедет» у старых сохранений.
    var gen_panel := _facade_textures(false)
    var gen_brick := _facade_textures(true)
    var panel_tex := _facade_from_files("facade_panel")
    var brick_tex := _facade_from_files("facade_brick")
    var panel_tints: Array = [Color(0.93, 0.93, 0.91), Color(0.86, 0.87, 0.88), Color(0.90, 0.88, 0.82),
            Color(0.80, 0.86, 0.90), Color(0.92, 0.86, 0.78)]
    var brick_tints: Array = [Color(0.78, 0.45, 0.36), Color(0.86, 0.74, 0.58), Color(0.90, 0.88, 0.82)]
    if panel_tex.is_empty():
        panel_tex = gen_panel
    else:   # настоящая фотография — оттенки почти белые, чтобы не испортить цвет
        panel_tints = [Color(0.86, 0.86, 0.86), Color(0.80, 0.81, 0.84), Color(0.88, 0.84, 0.78), Color(0.78, 0.83, 0.88)]
    if brick_tex.is_empty():
        brick_tex = gen_brick
    else:
        brick_tints = [Color(0.92, 0.92, 0.92), Color(0.95, 0.82, 0.74), Color(0.85, 0.83, 0.80)]
    for col: Color in panel_tints:
        _panel_mats.append(_facade_mat(col, panel_tex))
    for col: Color in brick_tints:
        _brick_mats.append(_facade_mat(col, brick_tex))
    var tower_tex := _facade_from_files("facade_tower")
    if not tower_tex.is_empty():
        for col: Color in [Color(0.84, 0.84, 0.84), Color(0.86, 0.82, 0.76), Color(0.78, 0.81, 0.86)]:
            _tower_mats.append(_facade_mat(col, tower_tex))
    var stalin := _tex_mip("res://textures/facade_stalin.png")
    if stalin:
        for col: Color in [Color(0.95, 0.95, 0.95), Color(0.98, 0.90, 0.84), Color(0.90, 0.92, 0.86)]:
            _stalin_mats.append(_facade_mat(col, [stalin]))

    _m["asphalt"] = _mat(Color(0.19, 0.19, 0.20), 0.95)
    _m["wasteland"] = _mat(Color(0.30, 0.34, 0.22), 1.0)
    _m["sidewalk"] = _mat(Color(0.46, 0.45, 0.44), 0.95)
    _m["grass"] = _mat(Color(0.33, 0.45, 0.22), 1.0)
    _m["paving"] = _mat(Color(0.50, 0.47, 0.43), 0.9)
    _m["soil"] = _mat(Color(0.30, 0.22, 0.15), 1.0)
    _m["yard_asphalt"] = _mat(Color(0.27, 0.27, 0.28), 0.95)
    _m["roof"] = _mat(Color(0.30, 0.30, 0.32), 0.9)
    _m["plinth"] = _mat(Color(0.55, 0.54, 0.52), 0.95)
    _m["concrete"] = _mat(Color(0.72, 0.71, 0.68), 0.9)
    _m["metal"] = _mat(Color(0.25, 0.27, 0.28), 0.5)
    _m["garage"] = _mat(Color(0.52, 0.52, 0.50), 0.85)
    _m["wood"] = _mat(Color(0.55, 0.36, 0.20), 0.8)
    _m["sand"] = _mat(Color(0.86, 0.78, 0.58), 1.0)
    _m["red"] = _mat(Color(0.80, 0.15, 0.12), 0.6)
    _m["yellow"] = _mat(Color(0.95, 0.75, 0.15), 0.6)
    _m["blue"] = _mat(Color(0.20, 0.45, 0.80), 0.6)
    _m["white"] = _mat(Color(0.95, 0.95, 0.93), 0.7)
    # Земля: асфальт и плитка из textures/ (по миру, без растяжения)
    var asphalt := _tex_mip("res://textures/ground_asphalt.png")
    if asphalt:
        _ground_tex(_m["asphalt"], asphalt, Color(0.80, 0.80, 0.82), 7.0)
        _ground_tex(_m["yard_asphalt"], asphalt, Color(1.0, 1.0, 1.0), 7.0)
    var tiles := _tex_mip("res://textures/ground_tiles.png")
    if tiles:
        _ground_tex(_m["sidewalk"], tiles, Color(0.68, 0.68, 0.68), 2.4)
        _ground_tex(_m["paving"], tiles, Color(0.80, 0.74, 0.66), 2.4)
    # Остальные поверхности из textures/ (если файла нет — остаётся просто цвет)
    var surfaces := [
        ["grass", "ground_grass", Color(0.9, 0.95, 0.85), 4.0],
        ["soil", "ground_soil", Color(1, 1, 1), 1.5],
        ["sand", "ground_sand", Color(1, 1, 1), 1.5],
        ["roof", "roof_gravel", Color(0.9, 0.9, 0.9), 4.0],
        ["garage", "metal_wall", Color(1, 1, 1), 3.0],
        ["wood", "wood_planks", Color(1, 1, 1), 1.2],
        ["concrete", "concrete", Color(0.85, 0.85, 0.85), 3.0],
        ["plinth", "concrete_panel", Color(0.75, 0.75, 0.75), 2.4],
        ["wasteland", "ground_wasteland", Color(0.95, 0.95, 0.9), 6.0],
    ]
    for sf: Array in surfaces:
        var t := _tex_mip("res://textures/%s.png" % sf[1])
        if t:
            _ground_tex(_m[sf[0]], t, sf[2], sf[3])

    # Новые поверхности: [имя, файл, цвет-запаска, оттенок с текстурой, метров на повтор]
    var extra := [
        ["vitrine", "vitrine", Color(0.18, 0.26, 0.32), Color(1, 1, 1), 3.0],
        ["plaster", "plaster", Color(0.80, 0.76, 0.68), Color(0.92, 0.90, 0.86), 3.0],
        ["shutter", "shutter", Color(0.60, 0.60, 0.62), Color(0.85, 0.85, 0.85), 2.5],
        ["granite", "granite", Color(0.30, 0.30, 0.32), Color(1, 1, 1), 1.5],
        ["sign", "sign_panel", Color(0.95, 0.95, 0.93), Color(1, 1, 1), 3.0],
        ["rubber_red", "rubber_red", Color(0.60, 0.20, 0.15), Color(1, 1, 1), 2.0],
        ["rubber_green", "rubber_green", Color(0.25, 0.50, 0.30), Color(1, 1, 1), 2.0],
        ["slide", "slide_plastic", Color(0.95, 0.75, 0.15), Color(1, 1, 1), 1.2],
        ["sandbox", "sandbox_boards", Color(0.30, 0.55, 0.30), Color(1, 1, 1), 1.0],
        ["pipe", "pipe_metal", Color(0.60, 0.62, 0.64), Color(1, 1, 1), 1.0],
        ["playhouse", "playhouse_planks", Color(0.80, 0.50, 0.20), Color(1, 1, 1), 1.5],
        ["path", "yard_path", Color(0.62, 0.62, 0.60), Color(0.85, 0.85, 0.85), 3.0],
        ["flowers", "flowers", Color(0.55, 0.25, 0.20), Color(1, 1, 1), 2.0],
        ["leaves", "ground_leaves", Color(0.50, 0.38, 0.18), Color(0.9, 0.9, 0.9), 4.0],
        ["gravel", "gravel", Color(0.50, 0.50, 0.50), Color(0.9, 0.9, 0.9), 2.0],
    ]
    for ex: Array in extra:
        _m[ex[0]] = _mat(ex[2], 0.85)
        var t := _tex_mip("res://textures/%s.png" % ex[1])
        if t:
            _ground_tex(_m[ex[0]], t, ex[3], ex[4])
    _m["vitrine"].metallic = 0.2
    _m["vitrine"].roughness = 0.25
    # Покраска: металл фонарей, площадки
    for pm: Array in [["metal", "painted_metal", Color(0.36, 0.38, 0.40), 1.5],
            ["red", "paint_red", Color(1, 1, 1), 1.0], ["yellow", "paint_yellow", Color(1, 1, 1), 1.0],
            ["blue", "paint_blue", Color(1, 1, 1), 1.0]]:
        var t := _tex_mip("res://textures/%s.png" % pm[1])
        if t:
            _ground_tex(_m[pm[0]], t, pm[2], pm[3])
    var glass := _mat(Color(0.18, 0.26, 0.32), 0.1)
    glass.metallic = 0.5
    var gt := _tex_mip("res://textures/mat_glass_dirty.png")
    if gt:
        _ground_tex(glass, gt, Color(0.42, 0.50, 0.58), 2.0)
        glass.roughness = 0.15
    _m["glass"] = glass
    var paint := _tex_mip("res://textures/mat_road_paint.png")
    if paint:
        _ground_tex(_m["white"], paint, Color(0.95, 0.95, 0.93), 1.2)


## Загрузить картинку с мипмапами (без них текстура «рябит» вдали). null — файла нет.
var _tex_cache := {}


func _tex_mip(path: String) -> Texture2D:
    if _tex_cache.has(path):
        return _tex_cache[path]
    var result: Texture2D = null
    if ResourceLoader.exists(path):
        var t: Texture2D = load(path)
        var img := t.get_image()
        if img == null:
            result = t
        else:
            if img.is_compressed():
                img.decompress()
            img.generate_mipmaps()
            result = ImageTexture.create_from_image(img)
    _tex_cache[path] = result
    return result


## Атлас фасада и маска ночных окон из textures/<name>.png и <name>_glow.png.
func _facade_from_files(name_base: String) -> Array:
    var albedo := _tex_mip("res://textures/%s.png" % name_base)
    var glow := _tex_mip("res://textures/%s_glow.png" % name_base)
    if albedo == null or glow == null:
        return []
    return [albedo, glow]


var _tinted_cache := {}


## Материал из серой текстуры, перекрашенной в цвет (одна обшивка — ларьки любых цветов).
func _tinted(tex_name: String, col: Color, meters: float) -> StandardMaterial3D:
    var key := "%s|%s" % [tex_name, col.to_html()]
    if _tinted_cache.has(key):
        return _tinted_cache[key]
    var m := _mat(col, 0.7)
    var t := _tex_mip("res://textures/%s.png" % tex_name)
    if t:
        _ground_tex(m, t, col, meters)
    _tinted_cache[key] = m
    return m


## Текстура земли по миру: один повтор на meters метров.
func _ground_tex(m: StandardMaterial3D, tex: Texture2D, tint: Color, meters: float) -> void:
    m.albedo_texture = tex
    m.albedo_color = tint
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3.ONE / meters
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Текстура фасада: атлас 4x4 ячейки (каждая 3 x 2.8 м — панель со швами
## или кирпич + окно) и маска свечения окон для ночи: часть окон «горит».
func _facade_textures(brick: bool) -> Array:
    const C := 64
    const N := 4
    var cell := Image.create_empty(C, C, false, Image.FORMAT_RGBA8)
    cell.fill(Color(0.96, 0.96, 0.96))
    var line := Color(0.78, 0.78, 0.78)
    if brick:
        for y in range(0, C, 4):
            cell.fill_rect(Rect2i(0, y, C, 1), line)
            var off := 0 if y % 8 == 0 else 4
            for x in range(off, C, 8):
                cell.fill_rect(Rect2i(x, y, 1, 4), line)
    else:
        cell.fill_rect(Rect2i(0, 0, C, 1), Color(0.7, 0.7, 0.7))
        cell.fill_rect(Rect2i(0, 0, 1, C), Color(0.7, 0.7, 0.7))
    cell.fill_rect(Rect2i(15, 14, 34, 34), Color(1, 1, 1))            # рама
    cell.fill_rect(Rect2i(17, 16, 30, 30), Color(0.20, 0.27, 0.34))   # стекло
    cell.fill_rect(Rect2i(31, 16, 2, 30), Color(1, 1, 1))             # импост
    cell.fill_rect(Rect2i(17, 28, 14, 2), Color(1, 1, 1))             # форточка
    cell.fill_rect(Rect2i(13, 48, 38, 2), Color(0.65, 0.65, 0.65))    # отлив

    var albedo := Image.create_empty(C * N, C * N, false, Image.FORMAT_RGBA8)
    var glow := Image.create_empty(C * N, C * N, false, Image.FORMAT_RGBA8)
    glow.fill(Color(0, 0, 0))
    for cx in N:
        for cy in N:
            albedo.blit_rect(cell, Rect2i(0, 0, C, C), Vector2i(cx * C, cy * C))
            if rng.randf() < 0.45:
                var warm := Color(1.0, 0.82, 0.5) if rng.randf() < 0.75 else Color(0.75, 0.85, 1.0)
                warm = warm * rng.randf_range(0.6, 1.0)
                glow.fill_rect(Rect2i(cx * C + 17, cy * C + 16, 30, 30), warm)
    albedo.generate_mipmaps()
    glow.generate_mipmaps()
    return [ImageTexture.create_from_image(albedo), ImageTexture.create_from_image(glow)]


func _facade_mat(col: Color, tex: Array) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.metallic_specular = 0.2   # без белых бликов от фонарей
    m.albedo_texture = tex[0]
    m.emission_enabled = false   # окна не светятся: ночью город освещают фонари
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(1.0 / (CELL * 4.0), 1.0 / (FLOOR_H * 4.0), 1.0 / (CELL * 4.0))
    m.roughness = 0.9
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m


## 0 — день, 1 — ночь: светятся окна.
## Окна ночью не светятся (город освещают фонари), а стены темнеют.
var _night_base := {}   # материал -> его дневной цвет
var _night_k := -1.0


func set_night(k: float) -> void:
    if absf(k - _night_k) < 0.02:
        return
    _night_k = k
    var lk := clampf((k - 0.3) / 0.5, 0.0, 1.0)   # фонари зажигаются в сумерках
    if pool_mat:
        pool_mat.albedo_color = Color(1.0, 0.78, 0.42) * (0.75 * lk)
    if cone_mat:
        cone_mat.albedo_color = Color(1.0, 0.82, 0.5) * (0.10 * lk)
    if _night_base.is_empty():
        var mats: Array = _panel_mats + _brick_mats + _tower_mats + _stalin_mats
        for m in _m.values():
            mats.append(m)
        for m in _tinted_cache.values():
            mats.append(m)
        for m in mats:
            if m is StandardMaterial3D and not _night_base.has(m) and m != lamp_mat:
                _night_base[m] = m.albedo_color
    var dim := lerpf(1.0, 0.5, k)
    var wet_mats := [_m.get("asphalt"), _m.get("yard_asphalt"), _m.get("sidewalk"), _m.get("paving")]
    var snow_mats := [_m.get("grass"), _m.get("roof"), _m.get("wasteland"), _m.get("sidewalk"), _m.get("paving"), _m.get("leaves")]
    for m: StandardMaterial3D in _night_base:
        var c: Color = _night_base[m]
        if m in snow_mats and _snow > 0.0:
            c = c.lerp(Color(0.93, 0.95, 1.0), _snow * 0.85)
        var wd := 1.0
        if m in wet_mats:
            wd = lerpf(1.0, 0.62, _wet)
            m.roughness = lerpf(0.9, 0.3, _wet)
        m.albedo_color = Color(c.r * dim * wd, c.g * dim * wd, c.b * dim * wd, c.a)


## Дождь (мокрый тёмный асфальт с бликами) и снег (белые газоны и крыши).
func set_weather(wet: float, snow: float) -> void:
    if absf(wet - _wet) < 0.01 and absf(snow - _snow) < 0.01:
        return
    _wet = wet
    _snow = snow
    if _puddle_mat:
        _puddle_mat.albedo_color.a = lerpf(0.0, 0.95, wet)
    var k := _night_k
    _night_k = -1.0
    set_night(maxf(k, 0.0))


## Виды мелких объектов: меш, материал, дальность видимости (м), тень.
## Мелочь пропадает вдали и не отбрасывает тени — это сильно ускоряет телефон.
func _define_batches() -> void:
    # Балконы: бетонная плита + ограждение (решётка, профлист или вагонка; цвет — у каждого свой)
    _batch("bal_slab", _box_mesh(Vector3(2.6, 0.14, 1.05)), _tinted("balcony_slab", Color(0.85, 0.85, 0.85), 1.5), 220.0)
    _batch("bal_rail", _box_mesh(Vector3(2.5, 0.86, 0.95)), _fit_mat("balcony_rail", Vector3(2.5, 0.86, 0.95), Color(0.62, 0.62, 0.62)), 200.0)
    _batch("bal_sheet", _box_mesh(Vector3(2.5, 0.86, 0.95)), _tiled_vc_mat("corrugated", 1.2, Color(0.65, 0.68, 0.70)), 200.0)
    _batch("bal_boards", _box_mesh(Vector3(2.5, 0.86, 0.95)), _tiled_vc_mat("balcony_boards", 1.5, Color(0.74, 0.73, 0.70)), 200.0)
    _batch("door", _box_mesh(Vector3(1.4, 2.2, 0.12)), _fit_mat("door_entrance" if ResourceLoader.exists("res://textures/door_entrance.png") else "door_old", Vector3(1.4, 2.2, 0.12), Color(0.32, 0.22, 0.15)), 90.0)
    var pipe := _mat(Color(0.45, 0.46, 0.47), 0.6)
    var pipe_tex := _tex_mip("res://textures/drainpipe.png")
    if pipe_tex:
        pipe.albedo_color = Color.WHITE
        pipe.albedo_texture = pipe_tex
        pipe.uv1_triplanar = true
        pipe.uv1_scale = Vector3(1.0 / 0.17, -9.0, 1.0 / 0.17)   # 9 хомутов по высоте трубы
        pipe.uv1_offset = Vector3(0.5, 0.5, 0.5)
    _batch("drainpipe", _cyl_mesh(0.08, 0.08, 1.0, 8), pipe, 140.0)
    _batch("canopy", _box_mesh(Vector3(2.4, 0.14, 1.3)), _m["concrete"], 110.0)
    _batch("roof_box", _box_mesh(Vector3(3.5, 2.4, 3.0)), _m["concrete"], 250.0)
    _batch("dash", _box_mesh(Vector3(0.18, 0.02, 2.5)), _m["white"], 90.0)
    _batch("zebra", _box_mesh(Vector3(0.55, 0.02, 3.4)), _m["white"], 90.0)
    var pole_mat := _m["metal"] as Material
    if _tex_mip("res://textures/lamp_post.png") != null:
        pole_mat = _fit_mat("lamp_post", Vector3(0.2, 1.4, 0.2), Color(0.36, 0.38, 0.40))
    _batch("pole", _cyl_mesh(0.07, 0.09, 7.0, 6), pole_mat, 150.0)
    _batch("lamp_arm", _box_mesh(Vector3(0.08, 0.08, 1.6)), _m["metal"], 150.0)
    var lamp := _mat(Color(1.0, 0.96, 0.85), 0.3)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.92, 0.75)
    lamp.emission_energy_multiplier = 0.8
    lamp_mat = lamp
    _batch("lamp_head", _box_mesh(Vector3(0.3, 0.12, 0.55)), lamp, 150.0)
    # Ночной свет фонарей без настоящих источников: светлое пятно на земле и лёгкий конус
    var grad := Gradient.new()
    grad.set_color(0, Color(1, 1, 1, 1))
    grad.set_color(1, Color(1, 1, 1, 0))
    grad.add_point(0.45, Color(1, 1, 1, 0.55))
    var gt := GradientTexture2D.new()
    gt.gradient = grad
    gt.fill = GradientTexture2D.FILL_RADIAL
    gt.fill_from = Vector2(0.5, 0.5)
    gt.fill_to = Vector2(1.0, 0.5)
    gt.width = 128
    gt.height = 128
    pool_mat = StandardMaterial3D.new()
    pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    pool_mat.albedo_texture = gt
    pool_mat.albedo_color = Color(0, 0, 0, 1)
    pool_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    pool_mat.set("disable_fog", true)
    var pm := PlaneMesh.new()
    pm.size = Vector2(13.0, 13.0)
    _batch("light_pool", pm, pool_mat, 120.0)
    var cg := Gradient.new()
    cg.set_color(0, Color(1, 1, 1, 0.0))
    cg.set_color(1, Color(1, 1, 1, 1.0))
    var ct := GradientTexture2D.new()
    ct.gradient = cg
    ct.fill_from = Vector2(0.5, 1.0)
    ct.fill_to = Vector2(0.5, 0.0)
    ct.width = 8
    ct.height = 64
    cone_mat = pool_mat.duplicate()
    cone_mat.albedo_texture = ct
    cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var beam := CylinderMesh.new()
    beam.top_radius = 0.18
    beam.bottom_radius = 2.6
    beam.height = 6.4
    beam.radial_segments = 12
    beam.rings = 1
    beam.cap_top = false
    beam.cap_bottom = false
    _batch("light_cone", beam, cone_mat, 90.0)
    _batch("trunk", _cyl_mesh(0.12, 0.18, 2.6, 6), _nature("bark_tree", Color(0.36, 0.25, 0.17), 1.0, false), 180.0)
    _batch("birch", _cyl_mesh(0.09, 0.13, 5.5, 6), _nature("bark_birch", Color(0.92, 0.90, 0.86), 1.0, false), 180.0)
    _batch("crown", _sphere_mesh(2.0, 3.4), _nature("foliage_tree", Color.WHITE, 2.5, true), 200.0, true)
    _batch("birch_crown", _sphere_mesh(1.3, 4.0), _nature("foliage_birch", Color.WHITE, 2.0, true), 200.0, true)
    _batch("bush", _sphere_mesh(0.7, 1.0), _nature("foliage_bush", Color.WHITE, 1.2, true), 80.0)
    # Готовые модели: остановочный павильон и бензоколонка (models/props)
    for pk: String in ["bus_stop", "gas_station", "militia"]:
        var prm := _nature_mesh(pk, "props")
        if prm:
            _batch("pr_" + pk, prm, null, 180.0, true)
            _props_ok[pk] = true
    for hk: String in ["lg_section", "lg_tower", "lg_five", "khrush", "dester", "house3f"]:
        var hm := _nature_mesh(hk, "houses")
        if hm:
            _batch("hs_" + hk, hm, null, 900.0, true)
            _props_ok[hk] = true
            if hm.get_surface_count() > 0 and hm.surface_get_material(0) is StandardMaterial3D:
                _m["house_" + hk] = hm.surface_get_material(0)   # темнеет ночью вместе с городом
    # Готовые деревья Quaternius (models/nature): по 3 варианта берёзы, лиственного дерева и ели
    for kind: String in ["birch", "tree", "pine", "bush"]:
        var found: Array[String] = []
        for i in range(1, 4):
            var mesh := _nature_mesh("%s%d" % [kind, i])
            if mesh:
                var nk := "nt_%s%d" % [kind, i]
                _batch(nk, mesh, null, 90.0 if kind == "bush" else 220.0, kind != "bush")
                found.append(nk)
        _nature_keys[kind] = found
    _batch("pine_trunk", _cyl_mesh(0.14, 0.2, 3.0, 6), _nature("bark_tree", Color(0.36, 0.25, 0.17), 1.0, false), 200.0)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.05
    cone.bottom_radius = 2.0
    cone.height = 6.5
    cone.radial_segments = 8
    cone.rings = 1
    _batch("pine_crown", cone, _nature("foliage_pine", Color.WHITE, 2.0, true), 220.0, true)
    var bench_mat := _m["wood"] as Material
    if _tex_mip("res://textures/bench_planks.png") != null:
        bench_mat = _fit_mat("bench_planks", Vector3(1.8, 0.35, 0.45), Color(0.45, 0.30, 0.2))
    _batch("bench_seat", _box_mesh(Vector3(1.8, 0.07, 0.45)), bench_mat, 70.0)
    _batch("bench_back", _box_mesh(Vector3(1.8, 0.35, 0.06)), bench_mat, 70.0)
    _batch("bench_leg", _box_mesh(Vector3(0.07, 0.45, 0.45)), _m["metal"], 70.0)
    # Ворота гаражей: серая текстура, цвет даёт каждый гараж свой (через цвет экземпляра).
    var door_mat := _vc_mat(0.7)
    var door_tex := _tex_mip("res://textures/garage_door.png")
    if door_tex:
        door_mat.albedo_texture = door_tex
        door_mat.uv1_triplanar = true   # по координатам самой створки: одна картинка на ворота
        door_mat.uv1_scale = Vector3(1.0 / 2.6, -1.0 / 2.1, 1.0 / 2.6)
        door_mat.uv1_offset = Vector3(0.5, 0.5, 0.5)
    _batch("garage_door", _box_mesh(Vector3(2.6, 2.1, 0.06)), door_mat, 140.0)
    for i in PARKED_COLORS.size():
        _batch("car%d" % i, CarModel.parked_mesh(PARKED_COLORS[i], ["vaz2106", "hatch", "sedan", "vaz2106", "suv"][i % 5]), null, 160.0, true)
    _define_sign_batches()


# ================================================================ помощники

## Позиция в квартале с учётом зеркалирования; y = уровень тротуара.
func _p(x: float, z: float) -> Vector3:
    return _c + Vector3(x * _mx, SIDE_H, z * _mz)


## Направление в квартале с учётом зеркалирования.
func _d(x: float, z: float) -> Vector3:
    return Vector3(x * _mx, 0.0, z * _mz)


func _occupy(center: Vector3, sx: float, sz: float) -> void:
    _occupied.append(Rect2(center.x - sx * 0.5, center.z - sz * 0.5, sx, sz))


func _is_free(p: Vector3, margin: float) -> bool:
    var q := Vector2(p.x, p.z)
    for r: Rect2 in _occupied:
        if r.grow(margin).has_point(q):
            return false
    return true


func _batch(key: String, mesh: Mesh, mat: Material, range_end: float, shadow := false) -> void:
    _defs[key] = {"mesh": mesh, "mat": mat, "range": range_end, "shadow": shadow}


## Объекты раскладываются по кускам размером с квартал: тогда камера рисует
## только те куски, что попали в кадр, а не весь город сразу.
func _put(key: String, pos: Vector3, yaw := 0.0, col := Color.WHITE, scl := Vector3.ONE) -> void:
    var cx := int(floor(pos.x / PITCH + 0.5))
    var cz := int(floor(pos.z / PITCH + 0.5))
    var ck := "%s|%d|%d" % [key, cx, cz]
    if not _batches.has(ck):
        _batches[ck] = {"key": key, "x": [], "c": []}
    var b: Dictionary = _batches[ck]
    var xs: Array = b["x"]
    var cs: Array = b["c"]
    xs.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scl), pos))
    cs.append(col)


## Через что нельзя пройти: стволы, фонари, столбы знаков, лавочки, припаркованные машины.
const SOLID_KEYS := ["trunk", "birch", "pine_trunk", "pole", "sign_pole", "bench_seat", "bench_back"]
var _shape_cache := {}


func _batch_colliders(key: String, mesh: Mesh, xs: Array) -> void:
    if mesh == null:
        return
    var aabb := mesh.get_aabb()
    var body := StaticBody3D.new()
    add_child(body)
    for x: Transform3D in xs:
        var scl := x.basis.get_scale()
        if key.begins_with("nt_"):   # дерево: только ствол
            var trunk := Vector3(0.12, 1.0, 0.12) * scl.x
            var tk := "trunk|%.2f" % trunk.x
            if not _shape_cache.has(tk):
                var ts := BoxShape3D.new()
                ts.size = trunk
                _shape_cache[tk] = ts
            var tcs := CollisionShape3D.new()
            tcs.shape = _shape_cache[tk]
            tcs.position = x.origin + Vector3(0, trunk.y * 0.5, 0)
            body.add_child(tcs)
            continue
        var size := aabb.size * scl
        if key.begins_with("car"):
            size = Vector3(size.x * 0.95, size.y * 0.85, size.z * 0.95)
        elif not key.begins_with("bench"):
            size = Vector3(maxf(size.x * 0.5, 0.12), size.y, maxf(size.z * 0.5, 0.12))   # круглые стволы и столбы — уже коробки
        var sk := "%.2f|%.2f|%.2f" % [size.x, size.y, size.z]
        if not _shape_cache.has(sk):
            var bs := BoxShape3D.new()
            bs.size = size
            _shape_cache[sk] = bs
        var cs := CollisionShape3D.new()
        cs.shape = _shape_cache[sk]
        var rot := x.basis.orthonormalized()
        cs.transform = Transform3D(rot, x.origin + x.basis * aabb.get_center())
        body.add_child(cs)


## Невидимая коробка-препятствие (для мебели из мелких деталей).
func _collider(size: Vector3, center: Vector3, yaw := 0.0) -> void:
    var body := StaticBody3D.new()
    body.position = center
    body.rotation.y = yaw
    var bs := BoxShape3D.new()
    bs.size = size
    var cs := CollisionShape3D.new()
    cs.shape = bs
    body.add_child(cs)
    add_child(body)


func _flush_batches() -> void:
    for ck: String in _batches:
        var b: Dictionary = _batches[ck]
        var d: Dictionary = _defs[b["key"]]
        var bkey := String(b["key"])
        var is_car := bkey.begins_with("car") and bkey.substr(3).is_valid_int()
        var is_tree := bkey.begins_with("nt_") and not bkey.contains("bush")
        if bkey in SOLID_KEYS or is_car or is_tree:
            _batch_colliders(bkey, d["mesh"], b["x"])
        var xs: Array = b["x"]
        var cs: Array = b["c"]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = d["mesh"]
        mm.instance_count = xs.size()
        for i in xs.size():
            mm.set_instance_transform(i, xs[i])
            mm.set_instance_color(i, cs[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.multimesh = mm
        if d["mat"] != null:
            mmi.material_override = d["mat"]
        mmi.visibility_range_end = d["range"]
        var shadow: bool = d["shadow"]
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
                else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mmi)


## Твёрдый ящик с коллизией. center — центр ящика.
func _solid(size: Vector3, center: Vector3, mat: Material, yaw := 0.0) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.position = center
    body.rotation.y = yaw
    add_child(body)
    var mi := MeshInstance3D.new()
    mi.mesh = _box_mesh(size)
    mi.material_override = mat
    body.add_child(mi)
    var shape := BoxShape3D.new()
    shape.size = size
    var col := CollisionShape3D.new()
    col.shape = shape
    body.add_child(col)
    return body


## Декоративный ящик без коллизии.
func _deco(size: Vector3, center: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = _box_mesh(size)
    mi.material_override = mat
    mi.position = center
    mi.rotation.y = yaw
    add_child(mi)
    return mi


func _flat(center: Vector3, size: Vector2, mat: Material, y: float) -> void:
    var mi := MeshInstance3D.new()
    var pm := PlaneMesh.new()
    pm.size = size
    mi.mesh = pm
    mi.material_override = mat
    mi.position = Vector3(center.x, y, center.z)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


func _label(text: String, pos: Vector3, facing: Vector3, font_size: int, col: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = font_size
    l.pixel_size = 0.005
    l.modulate = col
    l.outline_size = 0
    l.double_sided = false
    l.position = pos
    l.rotation.y = atan2(facing.x, facing.z)
    add_child(l)


func _mat(col: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = rough
    m.metallic_specular = 0.25
    return m


func _vc_mat(rough: float) -> StandardMaterial3D:
    var m := _mat(Color.WHITE, rough)
    m.vertex_color_use_as_albedo = true
    return m


func _box_mesh(s: Vector3) -> BoxMesh:
    var m := BoxMesh.new()
    m.size = s
    return m


func _cyl_mesh(top: float, bottom: float, h: float, seg: int) -> CylinderMesh:
    var m := CylinderMesh.new()
    m.top_radius = top
    m.bottom_radius = bottom
    m.height = h
    m.radial_segments = seg
    m.rings = 1
    return m


func _sphere_mesh(r: float, h: float) -> SphereMesh:
    var m := SphereMesh.new()
    m.radius = r
    m.height = h
    m.radial_segments = 12
    m.rings = 6
    return m


# ================================================================ службы, промзона, пригород

var bus_spawn := Transform3D()     # где появляется рабочий автобус
var truck_spawn := Transform3D()   # где появляется рабочая фура


func _atm(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    var base := Vector3(p.x, SIDE_H, p.z)
    _solid(Vector3(0.9, 1.9, 0.6), base + Vector3(0, 0.95, 0), _tinted("painted_metal", Color(0.35, 0.52, 0.90), 1.0), yaw)
    var screen := _mat(Color(0.3, 0.6, 1.0), 0.2)
    screen.emission_enabled = true
    screen.emission = Color(0.3, 0.6, 1.0)
    screen.emission_energy_multiplier = 0.8
    _deco(Vector3(0.5, 0.35, 0.03), base + b * Vector3(0, 1.35, 0.31), screen, yaw)
    _label("БАНКОМАТ", base + b * Vector3(0, 1.75, 0.32), facing, 28, Color(1, 1, 1))
    atms.append(base + facing * 1.1)
    _occupy(base, 1.5, 1.5)


## Остановка на случайной стороне квартала (для маршрута автобуса).
func _block_bus_stop() -> void:
    var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    var n: Vector3 = dirs[rng.randi() % dirs.size()]
    var a := Vector3(-n.z, 0.0, n.x)
    var h := BLOCK * 0.5
    var stop_pos := _c + n * (h - 2.0) + a * 12.0 + Vector3(0, SIDE_H, 0)
    if not _is_free(stop_pos, 0.5):
        return
    _bus_stop(stop_pos, n)
    if _city_id == "kazan":   # маршрут автобуса — только по Казани
        bus_stops.append(_c + n * (h + ROAD * 0.5 - 3.5) + a * 12.0)


## Промзона: склад (грузчик), стоянка фур (дальнобойщик), АЗС.
func _tpl_industrial() -> void:
    var inner := BLOCK - WALK * 2.0
    _flat(_c, Vector2(inner, inner), _m["yard_asphalt"], SIDE_H + 0.006)

    var wh := _p(-6, -16)
    _solid(Vector3(34, 9, 16), Vector3(wh.x, 4.5, wh.z), _tinted("warehouse_wall", Color(1, 1, 1), 4.0) if _tex_mip("res://textures/warehouse_wall.png") != null else _m["garage"])
    _deco(Vector3(34.4, 0.4, 16.4), Vector3(wh.x, 9.2, wh.z), _m["roof"])
    _deco(Vector3(5, 4.5, 0.15), Vector3(wh.x, 2.25, wh.z + 8.05), _fit_mat("warehouse_gate", Vector3(5, 4.5, 0.15), Color(0.6, 0.6, 0.62)))
    var dock := _p(-6, -3)
    _flat(dock, Vector2(20.0, 10.0), _fit_plane("floor_industrial", Vector2(4.0, 2.0), Color(0.5, 0.5, 0.5)), SIDE_H + 0.009)
    _label("СКЛАД", Vector3(wh.x, 7.0, wh.z + 8.1), Vector3(0, 0, 1), 160, Color(0.95, 0.95, 0.95))
    building_rects.append(Rect2(wh.x - 17.0, wh.z - 8.0, 34.0, 16.0))
    _occupy(wh, 34.0, 16.0)
    warehouse_drop = _p(-6, -6)
    var box_mat := _fit_mat("box_cardboard", Vector3(0.8, 0.8, 0.8), Color(0.72, 0.55, 0.35))
    var pallet := _fit_mat("pallet", Vector3(2.8, 0.15, 1.2), Color(0.6, 0.45, 0.3))
    _solid(Vector3(2.8, 0.15, 1.2), _p(-1.6, -7) + Vector3(0, 0.075, 0), pallet)
    for k in 3:
        _solid(Vector3(0.8, 0.8, 0.8), _p(-2.5 + k * 0.9, -7) + Vector3(0, 0.55, 0), box_mat)
    _solid(Vector3(0.8, 0.8, 0.8), _p(-2.05, -7) + Vector3(0, 1.35, 0), box_mat)

    # Фура, из которой грузчик носит коробки на склад.
    var tr := _p(-6, 8)
    _solid(Vector3(2.5, 2.7, 6.5), tr + Vector3(0, 1.9, 0), _fit_mat("cargo_side", Vector3(2.5, 2.7, 6.5), Color(0.92, 0.92, 0.92)))
    var cab := _fit_mat("truck_front", Vector3(2.4, 2.4, 2.4), Color(0.2, 0.35, 0.7))
    cab.albedo_color = Color(0.55, 0.7, 1.0) if cab.albedo_texture != null else cab.albedo_color
    _solid(Vector3(2.4, 2.4, 2.4), tr + Vector3(0, 1.6, 4.6), cab)
    _occupy(tr + Vector3(0, 0, 2), 4.0, 11.0)
    building_rects.append(Rect2(tr.x - 1.25, tr.z - 3.25, 2.5, 9.0))
    warehouse_pick = _p(-6, 3.5)

    # Стоянка дальнобойщиков
    var dep := _p(14, 0)
    _solid(Vector3(0.15, 3.0, 0.15), dep + Vector3(-2.0, 1.5, 0), _m["metal"])
    _solid(Vector3(0.15, 3.0, 0.15), dep + Vector3(2.0, 1.5, 0), _m["metal"])
    _deco(Vector3(4.6, 1.0, 0.1), dep + Vector3(0, 3.2, 0), _m["blue"])
    _label("ДАЛЬНОБОЙЩИКИ", dep + Vector3(0, 3.2, 0.06), Vector3(0, 0, 1), 44, Color(1, 1, 1))
    truck_depot = dep + Vector3(0, 0, 2.0)
    var ts := _p(22, 8)
    truck_spawn = Transform3D(Basis(), Vector3(ts.x, 0.9, ts.z))
    _occupy(_p(18, 6), 16.0, 20.0)

    _gas_station(_p(14, 24), true)
    if _signs_ok:
        _sign_post(_p(30, 12), 0.0, ["stop"])          # выезд фур на дорогу
        _sign_post(_p(-26, -4), 0.0, ["no_entry"])     # служебный проезд склада


## АЗС: навес, две колонки, магазинчик.
func _gas_station(c: Vector3, along_x: bool) -> void:
    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    var perp := Vector3(-axis.z, 0, axis.x)
    var y := c.y
    _flat(c, Vector2(30, 24) if along_x else Vector2(24, 30), _m["yard_asphalt"], y + 0.012)
    if _props_ok.has("gas_station"):
        _gas_station_model(c, along_x)
        _occupy(c, 30.0, 30.0)
        return
    var red := _mat(Color(0.80, 0.12, 0.10), 0.5)
    var csz := Vector3(14.1, 0.75, 9.1) if along_x else Vector3(9.1, 0.75, 14.1)
    _deco(csz, Vector3(c.x, y + 5.12, c.z), _fit_mat("canopy_band", csz, Color(0.92, 0.92, 0.92)))
    for sx: float in [-6.0, 6.0]:
        for sz: float in [-4.0, 4.0]:
            var post := c + axis * sx + perp * sz
            _solid(Vector3(0.35, 5.0, 0.35), Vector3(post.x, y + 2.5, post.z), _m["white"])
    for k: float in [-3.0, 3.0]:
        var pump := c + axis * k
        var pyaw := 0.0 if along_x else PI * 0.5
        _solid(Vector3(0.8, 1.6, 0.6), Vector3(pump.x, y + 0.8, pump.z), _fit_mat("fuel_pump", Vector3(0.8, 1.6, 0.6), Color(0.8, 0.12, 0.1)), pyaw)
        fuel_pumps.append(Vector3(pump.x, y, pump.z))
    for s: float in [-1.0, 1.0]:
        _label("АЗС", Vector3(c.x, y + 5.2, c.z) + perp * (4.62 * s), perp * s, 120, Color(0.85, 0.1, 0.1))
    var shop := c - perp * 9.5
    gas_shops.append(Vector3(shop.x, y, shop.z) + perp * 4.2)
    _solid(Vector3(8, 3.5, 5) if along_x else Vector3(5, 3.5, 8), Vector3(shop.x, y + 1.75, shop.z), _m["plaster"])
    _label("МАГАЗИН", Vector3(shop.x, y + 2.8, shop.z) + perp * (2.56 if along_x else 2.56), perp, 48, Color(0.2, 0.2, 0.2))
    building_rects.append(Rect2(shop.x - 4.0, shop.z - 4.0, 8.0, 8.0))
    _occupy(c, 30.0, 30.0)


## Готовая советская АЗС целиком (models/props/gas_station): навес на 6 столбах, три островка,
## колонки и будка «БЕНЗИН». Машины заезжают между островками вдоль дороги.
func _gas_station_model(c: Vector3, along_x: bool) -> void:
    var yaw := 0.0 if along_x else PI * 0.5   # островки модели идут вдоль её оси x
    var b := Basis(Vector3.UP, yaw)
    var g := Vector3(c.x, c.y, c.z)
    _put("pr_gas_station", g, yaw)
    for px: float in [-3.6, 3.45]:
        for pz: float in [-3.55, 3.47, 10.92]:
            _collider(Vector3(0.45, 5.0, 0.45), g + b * Vector3(px, 2.6, pz), yaw)
    for pump: Vector3 in [Vector3(1.61, 0, 3.58), Vector3(-1.73, 0, 10.95)]:
        _collider(Vector3(1.0, 2.1, 0.9), g + b * (pump + Vector3(0, 1.05, 0)), yaw)
        fuel_pumps.append(g + b * pump)
    # будка: вход и вывеска со стороны -x модели
    var kiosk := g + b * Vector3(-0.17, 0, -9.77)
    _collider(Vector3(3.45, 3.5, 5.0), kiosk + Vector3(0, 1.75, 0), yaw)
    gas_shops.append(g + b * Vector3(-2.9, 0, -9.8))
    building_rects.append(Rect2(kiosk.x - 2.6, kiosk.z - 2.6, 5.2, 5.2))


## За городом: две АЗС на трассах, лес с лесопилкой, точки для дальнобоя.
func _build_outskirts() -> void:
    _gas_station(Vector3(-248 - OUT, 0, 115), false)
    _gas_station(Vector3(0, 0, -248 - OUT), true)

    var fc := Vector3(-270 - OUT, 0, -270 - OUT)
    for k in 10:
        var p := fc + Vector3(rng.randf_range(-26, 26), 0, rng.randf_range(-26, 26))
        if _is_free(p, 3.0):
            _tree(p)
            forest_trees.append(p)
    for k in 90:
        var p := fc + Vector3(rng.randf_range(-36, 36), 0, rng.randf_range(-36, 36))
        if _is_free(p, 2.0):
            if rng.randf() < 0.6:
                _pine(p)
            else:
                _tree(p)
    _flat(fc, Vector2(84, 84), _m["leaves"], 0.01)
    _flat(Vector3(-226 - OUT, 0, -222 - OUT), Vector2(22, 18), _m["gravel"], 0.015)

    log_pile = Vector3(-226 - OUT, 0, -226 - OUT)
    var logs := _fit_mat("logs_side", Vector3(4.0, 1.4, 2.6), Color(0.45, 0.3, 0.18))
    _solid(Vector3(4.0, 1.4, 2.6), log_pile + Vector3(0, 0.7, -0.3), logs)
    var shed: Material = _tinted("shed_wall", Color(1, 1, 1), 3.0) if _tex_mip("res://textures/shed_wall.png") != null else _m["wood"]
    _solid(Vector3(6.0, 3.6, 4.0), log_pile + Vector3(-6.5, 1.8, -3.0), shed)
    _deco(Vector3(6.6, 0.3, 4.6), log_pile + Vector3(-6.5, 3.75, -3.0), _tinted("roof_slate", Color(1, 1, 1), 2.0))
    _solid(Vector3(0.15, 3.0, 0.15), log_pile + Vector3(3.0, 1.5, 0), _m["metal"])
    _deco(Vector3(3.6, 0.9, 0.1), log_pile + Vector3(3.0, 3.2, 0), _m["wood"])
    _label("ЛЕСОПИЛКА", log_pile + Vector3(3.0, 3.2, 0.06), Vector3(0, 0, 1), 40, Color(1, 1, 1))
    log_pile += Vector3(0, 0, 3.0)

    _build_station(STATION_C, "kazan", "КАЗАНЬ", ISLAND_KAZAN.position.x + 20.0, ISLAND_KAZAN.end.x - 20.0)
    _build_driving_school()
    # вокзал Пятигорска — к северу от города, такой же, как в Казани (без кассы и такси)
    _build_station(PY_ORG + Vector3(0, 0, -((PY_GRID + 0.5) * PITCH + ROAD * 0.5) - 37.0), "pyat", "ПЯТИГОРСК",
            ISLAND_PYAT.position.x + 20.0, ISLAND_PYAT.end.x - 20.0)

    truck_drops = [Vector3(-248 - OUT, 0, 90), Vector3(22, 0, -248 - OUT), Vector3(-226 - OUT, 0, -214 - OUT),
            Vector3(-215 - OUT, 0, 215 + OUT), Vector3(215 + OUT, 0, -215 - OUT), PY_ORG + Vector3(0, 0, 215)]


## Автосалон в Казани: стеклянный павильон, вывеска, три машины на витрине. Вход смотрит на площадь (-Z).
func _autosalon(c: Vector3) -> void:
    var base := Vector3(c.x, SIDE_H, c.z)
    _solid(Vector3(16, 4.4, 6), base + Vector3(0, 2.2, 0.5), _m["plaster"])
    _deco(Vector3(15, 3.4, 0.06), base + Vector3(0, 1.9, -2.53), _m["vitrine"])
    _deco(Vector3(16.4, 1.4, 0.15), base + Vector3(0, 5.1, -2.55), _m["sign"])
    _label("АВТОСАЛОН", base + Vector3(0, 5.1, -2.65), Vector3(0, 0, -1), 150, Color(0.15, 0.30, 0.70))
    _label("«ЖИГУЛИ» · «ВОЛГА» · «НИВА»", base + Vector3(0, 4.15, -2.6), Vector3(0, 0, -1), 46, Color(0.1, 0.1, 0.12))
    # подиумы с машинами перед павильоном
    var models := ["vaz2106", "volga"]
    var cols := [Color(0.65, 0.06, 0.08), Color(0.08, 0.08, 0.09)]
    for k in 2:
        var pp := base + Vector3(-13.5 + k * 27.0, 0, 0.5)
        _deco(Vector3(5.6, 0.25, 5.6), pp + Vector3(0, 0.12, 0), _m["granite"])
        var mesh := CarModel.parked_mesh(cols[k], models[k])
        if mesh:
            var body := StaticBody3D.new()
            body.position = pp + Vector3(0, 0.25, 0)
            body.rotation.y = PI + (0.5 if k == 0 else -0.5)
            add_child(body)
            CarModel.add_collision(body)
            var mi := MeshInstance3D.new()
            mi.mesh = mesh
            body.add_child(mi)
    building_rects.append(Rect2(base.x - 8.0, base.z - 2.5, 16.0, 6.0))
    _occupy(base + Vector3(0, 0, 0.5), 34.0, 8.0)
    autosalon = base + Vector3(0, 0, -4.6)


## Павильон «ОБЩИЙ РЫНОК»: вход смотрит на площадь (-Z).
func _market(c: Vector3) -> void:
    var base := Vector3(c.x, SIDE_H, c.z)
    _solid(Vector3(14, 3.6, 5), base + Vector3(0, 1.8, 0), _m["plaster"])
    _deco(Vector3(12, 2.2, 0.06), base + Vector3(0, 1.4, -2.53), _m["vitrine"])
    _deco(Vector3(14, 0.12, 2.0), base + Vector3(0, 3.0, -3.4), _tinted("awning", Color(1.0, 0.78, 0.25), 2.0))  # навес
    _deco(Vector3(14.4, 1.4, 0.15), base + Vector3(0, 4.4, -2.55), _m["sign"])
    _label("РЫНОК", base + Vector3(0, 4.4, -2.65), Vector3(0, 0, -1), 150, Color(0.85, 0.55, 0.05))
    building_rects.append(Rect2(base.x - 7.0, base.z - 2.5, 14.0, 5.0))
    _occupy(base, 16.0, 8.0)
    market = base + Vector3(0, 0, -4.6)


# ================================================================ дорожные знаки

const SIGN_TYPES := ["main_road", "give_way", "stop", "crosswalk", "speed60", "no_entry",
        "parking", "bus_stop", "children"]
var _signs_ok := false


## Партии MultiMesh для знаков (вызывается из _define_batches). Знак — картинка
## с прозрачным фоном на квадрате, сзади серая «спинка», стойка — тонкая труба.
func _define_sign_batches() -> void:
    for t: String in SIGN_TYPES:
        var tex := _tex_mip("res://textures/sign_%s.png" % t)
        if tex == null:
            return
        var m := StandardMaterial3D.new()
        m.albedo_texture = tex
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.5
        m.roughness = 0.5
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        var q := QuadMesh.new()
        q.size = Vector2(0.7, 0.7)
        _batch("sign_" + t, q, m, 110.0)
    var back := QuadMesh.new()
    back.size = Vector2(0.6, 0.6)
    _batch("sign_back", back, _m["metal"], 110.0)
    _batch("sign_pole", _cyl_mesh(0.035, 0.035, 2.9, 6), _m["metal"], 110.0)
    _signs_ok = true


## Табличка знака лицом по yaw (без стойки).
func _sign_plate(kind: String, pos: Vector3, yaw: float) -> void:
    var fwd := Vector3(sin(yaw), 0, cos(yaw))
    _put("sign_" + kind, pos + fwd * 0.02, yaw)
    _put("sign_back", pos - fwd * 0.005, yaw + PI)


## Стойка с одним-двумя знаками (сверху вниз), смотрят по yaw.
func _sign_post(base: Vector3, yaw: float, kinds: Array) -> void:
    var b := Vector3(base.x, SIDE_H, base.z)
    _put("sign_pole", b + Vector3(0, 1.45, 0))
    for i in kinds.size():
        _sign_plate(String(kinds[i]), b + Vector3(0, 2.55 - i * 0.78, 0), yaw)


## У каждого перекрёстка: «Главная дорога» (на дорогах вдоль X) или «Уступи дорогу»
## (вдоль Z) и «Пешеходный переход» у зебры. На каждом квартале — «60».
func _build_road_signs() -> void:
    if not _signs_ok:
        return
    var lim := (GRID + 0.5) * PITCH
    var arms: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for rx: float in road_lines:
        for rz: float in road_lines:
            var inter := Vector3(rx, 0, rz)
            for d: Vector3 in arms:
                var side := Vector3(d.z, 0, -d.x)   # справа по ходу машин, едущих к перекрёстку
                var p := inter + d * (ROAD * 0.5 + 4.6) + side * (ROAD * 0.5 + 1.2)
                if absf(p.x) > lim or absf(p.z) > lim:
                    continue
                var top := "main_road" if absf(d.x) > 0.5 else "give_way"
                _sign_post(p, atan2(d.x, d.z), [top, "crosswalk"])
    # «Ограничение 60» — по одному на сторону квартала
    var h := BLOCK * 0.5
    for i in range(-GRID, GRID + 1):
        for j in range(-GRID, GRID + 1):
            var c := Vector3(i * PITCH, 0, j * PITCH)
            for n: Vector3 in arms:
                var dir := Vector3(n.z, 0, -n.x)    # куда едут машины у этой стороны
                var p := c + n * (h - 0.9) - dir * 18.0
                if _is_free(p, 0.3):
                    _sign_post(p, atan2(-dir.x, -dir.z), ["speed60"])


# ================================================================ фракции

## Точка в квартале фракции: x — вдоль фасада, z — от фасада к дороге (+z — к площади).
func _fp(x: float, z: float) -> Vector3:
    return _c + _fb * Vector3(x, 0.0, z) + Vector3(0, SIDE_H, 0)


## Размер прямоугольника по миру с учётом поворота квартала.
func _fsz(sx: float, sz: float) -> Vector2:
    return Vector2(sz, sx) if absf(_ff.x) > 0.5 else Vector2(sx, sz)


func _focc(center: Vector3, sx: float, sz: float, is_building := false) -> void:
    var r := _fsz(sx, sz)
    _occupy(center, r.x, r.y)
    if is_building:
        building_rects.append(Rect2(center.x - r.x * 0.5, center.z - r.y * 0.5, r.x, r.y))


## Поворачивает квартал фасадом к площади, возвращает угол.
func _face_center(to_center: Vector2) -> float:
    var front := Vector3(signf(to_center.x), 0, 0) if absf(to_center.x) > absf(to_center.y) \
            else Vector3(0, 0, signf(to_center.y))
    _ff = front
    var yaw := atan2(front.x, front.z)
    _fb = Basis(Vector3.UP, yaw)
    return yaw


## Красный круг на земле и надпись над ним.
func _red_marker(mk: Vector3, text: String) -> void:
    var ring := MeshInstance3D.new()
    ring.mesh = _cyl_mesh(1.5, 1.5, 0.05, 24)
    var red_glow := _mat(Color(0.9, 0.08, 0.06), 0.5)
    red_glow.emission_enabled = true
    red_glow.emission = Color(1.0, 0.1, 0.05)
    red_glow.emission_energy_multiplier = 1.2
    ring.material_override = red_glow
    ring.position = mk + Vector3(0, 0.03, 0)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)
    var ml := Label3D.new()
    ml.text = text
    ml.font_size = 56
    ml.pixel_size = 0.006
    ml.outline_size = 12
    ml.modulate = Color(1.0, 0.35, 0.3)
    ml.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    ml.position = mk + Vector3(0, 2.4, 0)
    ml.visibility_range_end = 60.0
    add_child(ml)


## Здание фракции, крыльцо с вывеской, стоянка и красная метка «АВТОПАРК».
func _tpl_faction(fid: String, to_center: Vector2) -> void:
    var f: Dictionary = FactionData.get_faction(fid)
    var fk := FactionData.base(fid)   # у отделений Пятигорска — как у главных
    var yaw := _face_center(to_center)
    var front := _ff
    var accent: Color = f["color"]
    var wall: Material = _tinted("plaster", f["wall"], 3.0)
    # фасад из модулей «стена + окно» (картинки textures/org/*_window.png): 11 x 3 по фасаду, 5 x 3 по торцу
    var module := String({"mayor": "mayor_window", "police": "police_window", "hospital": "hospital_window",
            "kgb": "kgb_window"}.get(fk, ""))
    var has_module := module != "" and _org_tex(module) != null
    if has_module:
        wall = _module_mat(module, Vector3(34.0, 11.0, 16.0), Vector3(11.0, 3.0, 5.0))
    elif fk == "fire" and _org_tex("fire_brick") != null:
        wall = _tinted("org/fire_brick", Color(1, 1, 1), 2.0)
    if not _defs.has("fwin"):
        _batch("fwin", _box_mesh(Vector3(1.5, 1.9, 0.12)), _m["vitrine"], 260.0)

    # Корпус: 34 x 16 м, 3 этажа. Фасад — на z = -4.
    const BW := 34.0
    const BD := 16.0
    const BH := 11.0
    var bc := _fp(0, -12)
    var base := Vector3(bc.x, 0.0, bc.z)
    _solid(Vector3(BW, BH, BD), base + Vector3(0, BH * 0.5, 0), wall, yaw)
    var plinth: Material = _m["granite"] if fk == "kgb" or fk == "mayor" else _m["plinth"]
    if fk == "kgb" and _org_tex("kgb_granite") != null:
        plinth = _tinted("org/kgb_granite", Color(0.85, 0.85, 0.85), 2.0)
    _deco(Vector3(BW + 0.2, 0.9, BD + 0.2), base + Vector3(0, 0.45, 0), plinth, yaw)
    _deco(Vector3(BW + 0.4, 0.5, BD + 0.4), base + Vector3(0, BH + 0.25, 0), _m["roof"], yaw)
    _deco(Vector3(BW + 0.12, 0.5, BD + 0.12), base + Vector3(0, BH - 0.9, 0), _tinted("plaster", accent, 3.0), yaw)
    _focc(base, BW + 2.0, BD + 2.0)
    _focc(base, BW, BD, true)

    # Окна по всем сторонам (кроме двери и ворот пожарной части); с модулями окна уже на текстуре
    for fl: int in (0 if has_module else 3):
        var wy := 2.1 + fl * 3.3
        for k: int in 11:
            var x := -15.0 + k * 3.0
            var skip := fl == 0 and (absf(x) < 4.0 or (fk == "fire" and x > 3.0))
            if not skip:
                _put("fwin", _fp(x, -4.0) + Vector3(0, wy - SIDE_H, 0), yaw)
            _put("fwin", _fp(x, -20.0) + Vector3(0, wy - SIDE_H, 0), yaw)
        for k: int in 4:
            var z := -17.0 + k * 3.4
            for sx: float in [-17.0, 17.0]:
                _put("fwin", _fp(sx, z) + Vector3(0, wy - SIDE_H, 0), yaw + PI * 0.5)

    # Крыльцо, колонны, козырёк, дверь
    _deco(Vector3(10.0, 0.3, 4.0), _fp(0, -2.0) + Vector3(0, 0.15 - SIDE_H, 0), _m["granite"], yaw)
    _deco(Vector3(10.6, 0.3, 4.6), _fp(0, -1.8) + Vector3(0, 3.7, 0), _m["concrete"], yaw)
    for cx: float in [-4.6, 4.6]:
        var col_mat: Material = _fit_mat("pilaster", Vector3(0.5, 3.6, 0.5), Color(0.9, 0.88, 0.84))
        if fk == "fire":
            col_mat = _m["concrete"]
        elif fk == "kgb":
            col_mat = plinth
        _solid(Vector3(0.5, 3.6, 0.5), _fp(cx, 0.0) + Vector3(0, 1.8, 0), col_mat, yaw)
    var gdoor: Material = _m["glass"]
    if ResourceLoader.exists("res://textures/door_glass.png"):
        var gd := _fit_mat("door_glass", Vector3(2.8, 2.9, 0.1), Color(0.2, 0.25, 0.3))
        gd.roughness = 0.25
        gd.metallic = 0.3
        gdoor = gd
    _deco(Vector3(2.8, 2.9, 0.1), _fp(0, -3.98) + Vector3(0, 1.5, 0), gdoor, yaw)
    if fk == "police" and _props_ok.has("militia"):
        # постовые милиционеры со свистком у входа
        for sx: float in [-3.2, 3.2]:
            var gp := _fp(sx, -2.4)
            gp.y = SIDE_H
            _put("pr_militia", gp, atan2(_ff.x, _ff.z))
            _collider(Vector3(0.6, 1.8, 0.5), gp + Vector3(0, 0.9, 0))
    _deco(Vector3(3.1, 0.15, 0.14), _fp(0, -3.95) + Vector3(0, 3.0, 0), _m["metal"], yaw)
    _deco(Vector3(16.0, 1.5, 0.15), _fp(0, -3.95) + Vector3(0, 5.0, 0), _m["sign"], yaw)
    var title: String = f["title"]
    _label(title, _fp(0, -3.86) + Vector3(0, 5.0, 0), front, 150 if title.length() < 10 else (120 if title.length() < 15 else 86), accent.darkened(0.2))
    _emblem(String(f.get("emblem", "")), _fp(-6.6, -3.84) + Vector3(0, 5.0, 0), front, 1.3)
    _emblem(String(f.get("emblem", "")), _fp(6.6, -3.84) + Vector3(0, 5.0, 0), front, 1.3)
    _flat(_fp(0, 0), _fsz(40.0, 8.0), _m["paving"], SIDE_H + 0.006)
    _focc(_fp(0, 0), 40.0, 8.0)

    # Особенности каждой фракции
    match fk:
        "mayor":
            for fx: float in [-8.0, 8.0]:
                var fp := _fp(fx, 1.5)
                _deco(Vector3(0.12, 9.0, 0.12), fp + Vector3(0, 4.5, 0), _m["metal"])
                var flag := _fit_mat("flag_ussr", Vector3(2.2, 1.35, 0.04), Color(0.80, 0.08, 0.06))
                if fx < 0.0:
                    flag = flag.duplicate()
                    flag.uv1_scale.x = -flag.uv1_scale.x   # древко слева от полотнища — герб у древка
                _deco(Vector3(2.2, 1.35, 0.04), fp + Vector3(0, 8.15, 0) + _fb * Vector3(1.15 * signf(fx), 0, 0), flag, yaw)
        "police":
            _deco(Vector3(BW + 0.1, 0.45, 0.05), _fp(0, -3.96) + Vector3(0, 3.3, 0), _mat(Color(0.12, 0.25, 0.65), 0.6), yaw)
        "hospital":
            if ResourceLoader.exists("res://textures/obj_red_cross.png"):
                var cross := _fit_mat("obj_red_cross", Vector3(3.4, 3.4, 0.12), Color.WHITE)
                for cx: float in [11.0, -11.0]:
                    _deco(Vector3(3.4, 3.4, 0.12), _fp(cx, -3.95) + Vector3(0, 7.6, 0), cross, yaw)
            else:
                _deco(Vector3(3.4, 3.4, 0.08), _fp(11.0, -3.95) + Vector3(0, 7.6, 0), _m["white"], yaw)
                var red := _mat(Color(0.85, 0.08, 0.08), 0.6)
                _deco(Vector3(2.8, 0.85, 0.12), _fp(11.0, -3.92) + Vector3(0, 7.6, 0), red, yaw)
                _deco(Vector3(0.85, 2.8, 0.12), _fp(11.0, -3.92) + Vector3(0, 7.6, 0), red, yaw)
                _deco(Vector3(3.4, 3.4, 0.08), _fp(-11.0, -3.95) + Vector3(0, 7.6, 0), _m["white"], yaw)
                _deco(Vector3(2.8, 0.85, 0.12), _fp(-11.0, -3.92) + Vector3(0, 7.6, 0), red, yaw)
                _deco(Vector3(0.85, 2.8, 0.12), _fp(-11.0, -3.92) + Vector3(0, 7.6, 0), red, yaw)
        "fire":
            var gate := _fit_mat("org/fire_gate", Vector3(3.64, 4.2, 0.08), Color(0.80, 0.12, 0.08))
            for gx: float in [6.5, 10.5, 14.5]:
                if _org_tex("fire_gate") != null:
                    _deco(Vector3(3.64, 4.2, 0.08), _fp(gx, -3.96) + Vector3(0, 2.1 - SIDE_H, 0), gate, yaw)
                else:
                    _put("garage_door", _fp(gx, -3.95) + Vector3(0, 2.1 - SIDE_H, 0), yaw, Color(0.80, 0.12, 0.08), Vector3(1.4, 2.0, 1.0))
            var tw := _fp(-12.0, -25.0)
            _solid(Vector3(4.0, 18.0, 4.0), Vector3(tw.x, 9.0, tw.z), _tinted("plaster", Color(0.75, 0.35, 0.25), 3.0), yaw)
            _deco(Vector3(4.4, 0.5, 4.4), Vector3(tw.x, 18.25, tw.z), _m["roof"], yaw)
            _focc(tw, 5.0, 5.0)
            _focc(tw, 4.0, 4.0, true)
        "kgb":
            for cx: float in [-12.0, -8.0, 8.0, 12.0]:
                _deco(Vector3(0.7, BH - 1.2, 0.3), _fp(cx, -3.9) + Vector3(0, (BH - 1.2) * 0.5, 0), plinth, yaw)

    # Стоянка служебных машин и выезд к дороге
    _flat(_fp(0, 13), _fsz(44.0, 18.0), _m["yard_asphalt"], SIDE_H + 0.008)
    _flat(_fp(2, 27.5), _fsz(9.0, 9.0), _m["yard_asphalt"], SIDE_H + 0.007)
    var line: Material = _m["white"]
    for k: int in 11:
        var lx := -20.0 + k * 4.0
        _flat(_fp(lx, 6.5), _fsz(0.15, 5.0), line, SIDE_H + 0.012)
        _flat(_fp(lx, 19.5), _fsz(0.15, 5.0), line, SIDE_H + 0.012)
    _focc(_fp(0, 13), 46.0, 20.0)
    _focc(_fp(2, 27.5), 9.0, 9.0)
    if _signs_ok:
        _sign_post(_fp(-23.0, 20.0), yaw, ["parking"])

    # Красная метка автопарка
    var mk := _fp(-27.0, 8.0)
    _flat(mk, _fsz(6.0, 6.0), _m["paving"], SIDE_H + 0.007)
    _red_marker(mk, "АВТОПАРК\n" + String(f["name"]))
    _focc(mk, 6.0, 6.0)

    faction_sites[fid] = {"name": f["name"], "door": _fp(0, -2.0), "marker": mk,
            "spawn": Transform3D(_fb, _fp(2.0, 13.0) + Vector3(0, 0.8, 0)),
            "out": _fp(0, 1.5), "out_yaw": yaw + PI}
    if fk == "mayor":
        city_hall = _fp(0, -2.0)


## Простые интерьеры зданий фракций. Стоят далеко за городом, вход — телепорт.
func _build_interiors() -> void:
    const W := 24.0
    const D := 16.0
    const H := 4.4
    for k in FactionData.LIST.size():
        var f: Dictionary = FactionData.LIST[k]
        var fid: String = f["id"]
        var fk := FactionData.base(fid)
        var accent: Color = f["color"]
        var o := Vector3(2000.0 + k * 80.0, SIDE_H, 2000.0)
        if String(f.get("type", "state")) == "gang":
            _gang_interior(f, o)
            continue
        var wall: Material = _tinted("plaster", Color(f["wall"]).lightened(0.25), 3.0)
        var floor_mat: Material
        match fk:
            "mayor":
                floor_mat = _m["wood"]
            "hospital":
                floor_mat = _tinted("ground_tiles", Color(0.92, 0.96, 0.96), 2.0)
            "kgb":
                floor_mat = _tinted("concrete", Color(0.35, 0.22, 0.18), 3.0)
            _:
                floor_mat = _tinted("ground_tiles", Color(0.75, 0.75, 0.75), 2.0)
        # Свои текстуры пола и стен (textures/org), если есть
        var org_ok := _org_tex("parquet") != null
        if org_ok:
            match fk:
                "mayor":
                    floor_mat = _tinted("org/parquet", Color(1, 1, 1), 1.6)
                    wall = _tinted("org/wood_panel", Color(1, 1, 1), 2.0)
                "kgb":
                    floor_mat = _tinted("org/parquet", Color(0.55, 0.45, 0.40), 1.6)
                    wall = _tinted("org/wood_panel", Color(0.75, 0.70, 0.68), 2.0)
                "hospital":
                    floor_mat = _tinted("org/tiles_white", Color(1, 1, 1), 2.0)
                    wall = _wall_mat("wall_hospital", H, 2.0)
                _:
                    floor_mat = _tinted("org/linoleum", Color(1, 1, 1), 2.5)
                    wall = _wall_mat("wall_office", H, 3.0)
        _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, -0.2, 0), floor_mat)
        _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, H + 0.2, 0), _ceiling_mat())
        _solid(Vector3(0.4, H, D), o + Vector3(-W * 0.5, H * 0.5, 0), wall)
        _solid(Vector3(0.4, H, D), o + Vector3(W * 0.5, H * 0.5, 0), wall)
        _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, -D * 0.5), wall)
        _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, D * 0.5), wall)
        # плинтус-полоса цвета фракции (на однотонных стенах)
        for zz: float in ([] if org_ok else [-D * 0.5 + 0.21, D * 0.5 - 0.21]):
            _deco(Vector3(W - 0.5, 0.5, 0.02), o + Vector3(0, 0.25, zz), _tinted("plaster", accent, 3.0))
        # свет: лампы на потолке и два источника
        var lamp := _mat(Color(1, 1, 0.95), 0.3)
        lamp.emission_enabled = true
        lamp.emission = Color(1.0, 0.97, 0.9)
        lamp.emission_energy_multiplier = 1.5
        for lx: float in [-6.0, 0.0, 6.0]:
            for lz: float in [-4.0, 3.0]:
                _deco(Vector3(1.6, 0.06, 0.6), o + Vector3(lx, H - 0.03, lz), lamp)
        for lx: float in [-6.0, 6.0]:
            var ol := OmniLight3D.new()
            ol.position = o + Vector3(lx, H - 0.6, 0)
            ol.omni_range = 14.0
            ol.omni_attenuation = 1.2
            ol.light_energy = 1.3
            ol.light_color = Color(1.0, 0.95, 0.85)
            ol.shadow_enabled = false
            add_child(ol)

        # дверь «ВЫХОД» на задней стене (+z)
        _deco(Vector3(2.4, 2.8, 0.08), o + Vector3(0, 1.4, D * 0.5 - 0.22), _fit_mat("door_office", Vector3(2.4, 2.8, 0.08), Color(0.30, 0.20, 0.13)))
        _label("ВЫХОД", o + Vector3(0, 3.2, D * 0.5 - 0.25), Vector3(0, 0, -1), 64, Color(0.3, 0.9, 0.4))
        # вывеска фракции на дальней стене
        _deco(Vector3(9.0, 1.4, 0.06), o + Vector3(0, 3.1, -D * 0.5 + 0.23), _m["sign"])
        _label(String(f["title"]), o + Vector3(0, 3.1, -D * 0.5 + 0.28), Vector3(0, 0, 1), 110 if String(f["title"]).length() < 15 else 76, accent.darkened(0.2))
        if fk != "hospital":   # у больницы на стене уже красный крест
            _emblem(String(f.get("emblem", "")), o + Vector3(0, 1.6, -D * 0.5 + 0.26), Vector3(0, 0, 1), 1.1)

        # отдел кадров (слева) и стойка (справа)
        var desk_mat: Material = _mat(Color(0.35, 0.24, 0.16), 0.6) if fk != "kgb" else _mat(Color(0.15, 0.12, 0.10), 0.5)
        if _org_tex("desk_front") != null:
            desk_mat = _fit_mat("org/desk_front", Vector3(1.7, 1.05, 0.9), Color(0.35, 0.24, 0.16))
        # доска объявлений
        _deco(Vector3(0.04, 1.0, 1.4), o + Vector3(-W * 0.5 + 0.23, 1.9, -5.6),
                _fit_mat("org/cork_board", Vector3(0.04, 1.0, 1.4), Color(0.70, 0.55, 0.35)))
        for side: float in [-1.0, 1.0]:
            _solid(Vector3(3.4, 1.05, 0.9), o + Vector3(7.0 * side, 0.525, -5.2), desk_mat)
            _f_chair(o + Vector3(7.0 * side, 0, -6.6), 0.0)   # стул за стойкой
            _deco(Vector3(0.42, 0.36, 0.4), o + Vector3(7.0 * side - 0.8, 1.23, -5.3), _fm("monitor"), PI)
            _deco(Vector3(0.3, 0.01, 0.22), o + Vector3(7.0 * side + 0.6, 1.06, -5.2), _fm("papers"))
            _deco(Vector3(0.2, 0.08, 0.16), o + Vector3(7.0 * side + 0.1, 1.09, -5.0), _fm("phone"), PI)
        # общая обстановка: цветы по углам, кулер, часы над выходом, батареи
        for cx: float in [-W * 0.5 + 0.6, W * 0.5 - 0.6]:
            _f_plant(o + Vector3(cx, 0, D * 0.5 - 0.6), true)
        _f_plant(o + Vector3(-W * 0.5 + 0.6, 0, -D * 0.5 + 0.6), true)
        _f_cooler(o + Vector3(-W * 0.5 + 0.5, 0, 4.8), PI * 0.5)
        _f_clock(o + Vector3(0, 3.6, D * 0.5 - 0.22), PI)
        for rx: float in [-5.0, 5.0]:
            _f_radiator(o + Vector3(rx, 0, D * 0.5 - 0.3), PI, 1.6)
        _deco(Vector3(4.6, 0.9, 0.06), o + Vector3(-7.0, 2.4, -D * 0.5 + 0.23), _m["sign"])
        _label("ОТДЕЛ КАДРОВ", o + Vector3(-7.0, 2.4, -D * 0.5 + 0.28), Vector3(0, 0, 1), 64, Color(0.15, 0.15, 0.18))
        var desk_name := "ПАСПОРТНЫЙ СТОЛ"
        match fk:
            "police":
                desk_name = "ДЕЖУРНАЯ ЧАСТЬ"
            "hospital":
                desk_name = "РЕГИСТРАТУРА"
            "fire":
                desk_name = "ДИСПЕТЧЕРСКАЯ"
            "kgb":
                desk_name = "ПРИЁМНАЯ"
        _deco(Vector3(4.6, 0.9, 0.06), o + Vector3(7.0, 2.4, -D * 0.5 + 0.23), _m["sign"])
        _label(desk_name, o + Vector3(7.0, 2.4, -D * 0.5 + 0.28), Vector3(0, 0, 1), 56, Color(0.15, 0.15, 0.18))
        # лавочки для посетителей
        for bz: float in [-1.0, 2.5]:
            _bench(o + Vector3(-W * 0.5 + 1.0, 0, bz), Vector3(1, 0, 0))

        # обстановка по фракции
        match fk:
            "mayor":
                var carpet := _plane_mat("carpet_runner", Vector2(1.0, 5.0), Color(0.55, 0.08, 0.10))
                _flat(o + Vector3(0, 0, 0), Vector2(2.6, D - 1.0), carpet, SIDE_H + 0.01)
                for fx: float in [-2.5, 2.5]:
                    _deco(Vector3(0.08, 3.0, 0.08), o + Vector3(fx, 1.5, -D * 0.5 + 0.6), _m["metal"])
                    _deco(Vector3(1.2, 0.75, 0.03), o + Vector3(fx + 0.65, 2.6, -D * 0.5 + 0.6), _fit_mat("flag_ussr", Vector3(1.2, 0.75, 0.03), Color(0.80, 0.08, 0.06)))
                for px: float in [-10.5, 10.5]:
                    _deco(Vector3(0.8, 1.2, 0.8), o + Vector3(px, 0.6, 6.5), _m["concrete"])
                    _put("bush", o + Vector3(px, 1.5, 6.5), 0.0, Color.WHITE, Vector3(0.8, 0.9, 0.8))
                # кабинет мэра: стол с лампой, книжные шкафы, картина
                _f_desk(o + Vector3(0, 0, -4.6), PI, true)
                for bx: float in [-1.4, 1.4]:
                    _f_bookshelf(o + Vector3(bx + (4.0 if bx > 0 else -4.0), 0, -D * 0.5 + 0.45), 0.0, 1.2, 2.2)
                _f_picture(o + Vector3(W * 0.5 - 0.22, 2.3, 2.0), -PI * 0.5, 1.6, 1.0)
            "police":
                # камера (КПЗ) с решёткой у правой стены
                if _org_tex("kpz_bars") != null:
                    _solid(Vector3(0.1, H, 5.4), o + Vector3(8.6, H * 0.5, 2.86), _fit_mat("org/kpz_bars", Vector3(0.1, H, 2.0), Color(0.5, 0.5, 0.5)))
                else:
                    for bz in 15:
                        _solid(Vector3(0.06, H, 0.06), o + Vector3(8.6, H * 0.5, 0.2 + bz * 0.38), _m["metal"])
                _solid(Vector3(3.2, 0.5, 0.8), o + Vector3(10.6, 0.25, 4.9), _m["wood"])
                # стенки камеры, чтобы из неё нельзя было выйти
                _solid(Vector3(3.6, H, 0.2), o + Vector3(10.4, H * 0.5, 0.06), wall)
                _solid(Vector3(3.6, H, 0.2), o + Vector3(10.4, H * 0.5, 5.66), wall)
                if fid == "police":   # общая КПЗ — в Главной милиции
                    kpz_cell = o + Vector3(10.4, 0.3, 2.8)
                # стол дежурного и доска «Их разыскивает милиция»
                _f_desk(o + Vector3(3.0, 0, 0.5), -PI * 0.5)
                _f_desk(o + Vector3(3.0, 0, -2.0), -PI * 0.5)
                _f_bookshelf(o + Vector3(W * 0.5 - 0.45, 0, -3.5), -PI * 0.5, 1.4, 2.0)
                _deco(Vector3(1.6, 1.1, 0.04), o + Vector3(-2.5, 1.9, -D * 0.5 + 0.24), _fit_mat("org/cork_board", Vector3(1.6, 1.1, 0.04), Color(0.7, 0.55, 0.35)))
                for pk in 6:
                    _deco(Vector3(0.22, 0.3, 0.01), o + Vector3(-3.05 + (pk % 3) * 0.55, 2.15 - (pk / 3) * 0.45, -D * 0.5 + 0.265), _fm("paper"))
                _label("ИХ РАЗЫСКИВАЕТ МИЛИЦИЯ", o + Vector3(-2.5, 2.6, -D * 0.5 + 0.27), Vector3(0, 0, 1), 28, Color(0.75, 0.1, 0.1))
                _label("КПЗ", o + Vector3(8.5, 3.4, 3.0), Vector3(-1, 0, 0), 64, Color(0.9, 0.9, 0.9))
                if not org_ok:
                    _deco(Vector3(W - 0.5, 0.35, 0.03), o + Vector3(0, 1.2, -D * 0.5 + 0.22), _mat(Color(0.12, 0.25, 0.65), 0.6))
            "hospital":
                for bz: float in [-1.5, 1.5, 4.5]:
                    _f_hospital_bed(o + Vector3(10.6, 0, bz), 0.0)
                    _solid(Vector3(0.05, 1.8, 1.4), o + Vector3(9.3, 0.9, bz + 1.4), _tinted("mat_teal_fabric", Color(1, 1, 1), 0.8))
                # шкаф с лекарствами и кабинет врача
                _solid(Vector3(1.2, 1.9, 0.45), o + Vector3(3.0, 0.95, -D * 0.5 + 0.45), _fm("med_cabinet"))
                for mk in (0 if ResourceLoader.exists("res://textures/obj_med_cabinet.png") else 8):
                    _deco(Vector3(0.08, 0.14, 0.08), o + Vector3(2.6 + (mk % 4) * 0.25, 1.05 + (mk / 4) * 0.45, -D * 0.5 + 0.55), _book_mat([Color(0.9, 0.9, 0.9), Color(0.5, 0.3, 0.15), Color(0.2, 0.5, 0.8)][mk % 3]))
                _f_desk(o + Vector3(-3.0, 0, 0.5), PI * 0.5)
                var red := _mat(Color(0.85, 0.08, 0.08), 0.6)
                _deco(Vector3(1.6, 0.5, 0.04), o + Vector3(0, 1.2, -D * 0.5 + 0.25), red)
                _deco(Vector3(0.5, 1.6, 0.04), o + Vector3(0, 1.2, -D * 0.5 + 0.25), red)
            "fire":
                var lred := _mat(Color(0.75, 0.10, 0.08), 0.5)
                if _org_tex("lockers") != null:
                    _solid(Vector3(0.6, 2.0, 7.2), o + Vector3(W * 0.5 - 0.55, 1.0, 0.15), _fit_mat("org/lockers", Vector3(0.6, 2.0, 2.4), lred.albedo_color))
                else:
                    for bz in 10:
                        _solid(Vector3(0.6, 2.0, 0.6), o + Vector3(W * 0.5 - 0.55, 1.0, -3.0 + bz * 0.7), lred)
                _deco(Vector3(0.12, H, 0.12), o + Vector3(4.0, H * 0.5, 3.0), _m["pipe"])
                _flat(o + Vector3(4.0, 0, 3.0), Vector2(1.6, 1.6), _m["rubber_red"], SIDE_H + 0.01)
                # каски на шкафчиках и катушки с рукавами
                for hz in 6:
                    _mdeco(_sphere_mesh(0.16, 0.18), o + Vector3(W * 0.5 - 0.55, 2.1, -2.6 + hz * 1.1), _fm("red"))
                for rz: float in [-3.5, -1.5]:
                    var reel := MeshInstance3D.new()
                    reel.mesh = _cyl_mesh(0.45, 0.45, 0.35, 16)
                    reel.material_override = _fm("red")
                    reel.position = o + Vector3(-3.0, 0.5, rz)
                    _collider(Vector3(0.35, 0.9, 0.9), reel.position)
                    reel.rotation.z = PI * 0.5
                    add_child(reel)
                _f_desk(o + Vector3(-3.0, 0, 2.5), PI * 0.5)
                if not org_ok:
                    _deco(Vector3(W - 0.5, 0.35, 0.03), o + Vector3(0, 1.2, -D * 0.5 + 0.22), lred)
            "kgb":
                for bz in 6:
                    _solid(Vector3(0.7, 1.9, 0.9), o + Vector3(W * 0.5 - 0.6, 0.95, -4.0 + bz * 1.2),
                            _fit_mat("org/file_cabinet", Vector3(0.7, 1.9, 0.9), Color(0.45, 0.46, 0.45)))
                _flat(o + Vector3(0, 0, 0), Vector2(6.0, 4.0), _plane_mat("carpet_wall", Vector2(1, 1), Color(0.35, 0.08, 0.08)), SIDE_H + 0.01)
                # кабинет: стол с зелёной лампой, книги, сейф
                _f_desk(o + Vector3(0, 0, -0.6), PI, true)
                _f_chair(o + Vector3(-0.6, 0, 1.0), PI)
                _f_chair(o + Vector3(0.6, 0, 1.0), PI)
                _f_bookshelf(o + Vector3(-4.5, 0, -D * 0.5 + 0.45), 0.0, 1.4, 2.4)
                _f_bookshelf(o + Vector3(4.5, 0, -D * 0.5 + 0.45), 0.0, 1.4, 2.4)
                _solid(Vector3(0.8, 1.0, 0.7), o + Vector3(-W * 0.5 + 0.7, 0.5, -6.0), _fit_mat("org/safe_door", Vector3(0.8, 1.0, 0.7), Color(0.4, 0.43, 0.4)))

        _interior_extras(fk, o, W, D, H)
        interiors[fid] = {"spawn": o + Vector3(0, 0.3, D * 0.5 - 3.6), "exit": o + Vector3(0, 0, D * 0.5 - 1.3),
                "hr": o + Vector3(-7.0, 0, -4.0), "desk": o + Vector3(7.0, 0, -4.0)}



# ================================================================ ОПГ

## Район ОПГ: жилой дом (или универсам), ряд гаражей, база-гараж с вывеской,
## стоянка и красная метка автопарка.
func _tpl_gang(gid: String, to_center: Vector2) -> void:
    var f: Dictionary = FactionData.get_faction(gid)
    var yaw := _face_center(to_center)
    var accent: Color = f["color"]
    var along := absf(_ff.z) > 0.5

    if gid == "universam":
        _shop(_fp(0, -20), 34.0, 14.0, _ff, "УНИВЕРСАМ")
    elif rng.randf() < 0.5:
        _building(_fp(0, -20), 54.0, 12.0, 9, along, "panel", _ff)
    else:
        _building(_fp(0, -20), 42.0, 11.0, 5, along, "brick", _ff)

    # База — большой гараж
    var gc := _fp(-10, 4)
    var base := Vector3(gc.x, 0.0, gc.z)
    var wall := _tinted("corrugated" if ResourceLoader.exists("res://textures/corrugated.png") else "metal_wall",
            Color(f["wall"]).lightened(0.3), 1.5)
    if _org_tex("gang_wall") != null:
        wall = _tinted("org/gang_wall", Color(1, 1, 1), 4.0)
    _solid(Vector3(16.0, 4.5, 10.0), base + Vector3(0, 2.25, 0), wall, yaw)
    _deco(Vector3(16.4, 0.3, 10.4), base + Vector3(0, 4.6, 0), _m["roof"], yaw)
    _deco(Vector3(16.1, 0.5, 10.1), base + Vector3(0, 0.25, 0), _m["plinth"], yaw)
    _focc(gc, 18.0, 12.0)
    _focc(gc, 16.0, 10.0, true)
    if _org_tex("gang_gate") != null:
        _deco(Vector3(5.2, 4.0, 0.08), _fp(-13, 9.04) + Vector3(0, 2.0, 0) - Vector3(0, SIDE_H, 0),
                _fit_mat("org/gang_gate", Vector3(5.2, 4.0, 0.08), Color(0.4, 0.35, 0.3)), yaw)
    else:
        _put("garage_door", _fp(-13, 9.03) + Vector3(0, 2.05 - SIDE_H, 0), yaw, accent.darkened(0.45), Vector3(2.0, 1.9, 1.0))
    _deco(Vector3(1.2, 2.3, 0.08), _fp(-4.5, 9.03) + Vector3(0, 1.15, 0), _fit_mat("door_steel", Vector3(1.2, 2.3, 0.08), Color(0.22, 0.20, 0.18)), yaw)
    _deco(Vector3(0.5, 0.2, 0.3), _fp(-4.5, 9.15) + Vector3(0, 2.5, 0), lamp_mat, yaw)
    # «граффити» с названием на стене
    _label(String(f["title"]), _fp(-10, 9.08) + Vector3(0, 3.55, 0), _ff, 120, accent)
    _emblem(String(f.get("emblem", "")), _fp(-4.5, 9.1) + Vector3(0, 3.5, 0), _ff, 1.2)
    _label(String(f["title"]), base + _fb * Vector3(0, 0, -5.06) + Vector3(0, 2.4, 0), -_ff, 140, accent)
    # обычные гаражи рядом
    _garages(_fp(14, 3), 5, along, _ff)

    # Стоянка и выезд к дороге
    _flat(_fp(0, 17), _fsz(46.0, 12.0), _m["yard_asphalt"], SIDE_H + 0.008)
    _flat(_fp(6, 27.5), _fsz(9.0, 9.0), _m["yard_asphalt"], SIDE_H + 0.007)
    _focc(_fp(0, 17), 48.0, 14.0)
    _focc(_fp(6, 27.5), 9.0, 9.0)
    var mk := _fp(-24.0, 17.0)
    _red_marker(mk, "АВТОПАРК\n" + String(f["name"]))
    _focc(mk, 5.0, 5.0)

    faction_sites[gid] = {"name": f["name"], "door": _fp(-4.5, 10.8), "marker": mk,
            "spawn": Transform3D(_fb, _fp(6.0, 17.0) + Vector3(0, 0.8, 0)),
            "out": _fp(-4.5, 14.0), "out_yaw": yaw + PI}


## Интерьер базы ОПГ: гараж с подъёмником, диваном «смотрящего», общаком, ковром на стене.
func _gang_interior(f: Dictionary, o: Vector3) -> void:
    const W := 20.0
    const D := 14.0
    const H := 4.6
    var gid: String = f["id"]
    var accent: Color = f["color"]
    var wall := _tinted("metal_wall", Color(f["wall"]).lightened(0.1), 3.0)
    var floor_mat := _tinted("concrete", Color(0.55, 0.55, 0.55), 3.0)
    if _org_tex("garage_floor") != null:
        floor_mat = _tinted("org/garage_floor", Color(1, 1, 1), 3.0)
        wall = _tinted("org/garage_brick", Color(1, 1, 1), 2.5)
    _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, -0.2, 0), floor_mat)
    _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, H + 0.2, 0), _m["concrete"])
    _solid(Vector3(0.4, H, D), o + Vector3(-W * 0.5, H * 0.5, 0), wall)
    _solid(Vector3(0.4, H, D), o + Vector3(W * 0.5, H * 0.5, 0), wall)
    _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, -D * 0.5), wall)
    _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, D * 0.5), wall)
    # тусклые лампы
    var lamp := _mat(Color(1, 0.95, 0.8), 0.3)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.85, 0.6)
    lamp.emission_energy_multiplier = 1.4
    for lx: float in [-5.0, 5.0]:
        _deco(Vector3(0.02, 0.8, 0.02), o + Vector3(lx, H - 0.4, 0), _m["metal"])
        _deco(Vector3(0.4, 0.2, 0.4), o + Vector3(lx, H - 0.9, 0), lamp)
        var ol := OmniLight3D.new()
        ol.position = o + Vector3(lx, H - 1.2, 0)
        ol.omni_range = 12.0
        ol.omni_attenuation = 1.3
        ol.light_energy = 1.1
        ol.light_color = Color(1.0, 0.85, 0.6)
        ol.shadow_enabled = false
        add_child(ol)
    # выход
    _deco(Vector3(1.4, 2.4, 0.08), o + Vector3(0, 1.2, D * 0.5 - 0.22), _fit_mat("door_steel", Vector3(1.4, 2.4, 0.08), Color(0.22, 0.20, 0.18)))
    _label("ВЫХОД", o + Vector3(0, 2.9, D * 0.5 - 0.25), Vector3(0, 0, -1), 64, Color(0.3, 0.9, 0.4))
    # название ОПГ «краской» на дальней стене
    _label(String(f["title"]), o + Vector3(0, 3.0, -D * 0.5 + 0.23), Vector3(0, 0, 1), 170, accent)
    _emblem(String(f.get("emblem", "")), o + Vector3(0, 1.5, -D * 0.5 + 0.24), Vector3(0, 0, 1), 1.2)
    # уголок смотрящего: ковёр на стене, диван, стол
    _deco(Vector3(0.03, 2.0, 3.2), o + Vector3(-W * 0.5 + 0.23, 2.0, -3.0), _fit_mat("org/carpet_wall", Vector3(0.03, 2.0, 3.2), Color(0.55, 0.12, 0.10)))
    var sofa := _fit_mat("org/sofa", Vector3(1.0, 1.0, 3.0), Color(0.25, 0.15, 0.10))
    _deco(Vector3(0.04, 1.0, 1.4), o + Vector3(W * 0.5 - 0.23, 2.0, -1.5), _fit_mat("org/cork_board", Vector3(0.04, 1.0, 1.4), Color(0.70, 0.55, 0.35)))
    _solid(Vector3(1.0, 0.5, 3.0), o + Vector3(-W * 0.5 + 1.0, 0.25, -3.0), sofa)
    _deco(Vector3(0.3, 0.6, 3.0), o + Vector3(-W * 0.5 + 0.6, 0.75, -3.0), sofa)
    _solid(Vector3(1.2, 0.75, 1.8), o + Vector3(-W * 0.5 + 2.8, 0.375, -3.0), _m["wood"])
    _label("СМОТРЯЩИЙ", o + Vector3(-W * 0.5 + 0.3, 3.4, -3.0), Vector3(1, 0, 0), 56, Color(0.95, 0.95, 0.9))
    # общак
    var safe := _fit_mat("org/safe_door", Vector3(0.9, 1.1, 0.8), Color(0.40, 0.43, 0.40))
    _solid(Vector3(0.9, 1.1, 0.8), o + Vector3(-W * 0.5 + 0.8, 0.55, 3.5), safe)
    _label("ОБЩАК", o + Vector3(-W * 0.5 + 1.26, 0.8, 3.5), Vector3(1, 0, 0), 40, Color(1.0, 0.8, 0.3))
    # подъёмник с машиной
    for px: float in [3.2, 7.8]:
        _solid(Vector3(0.3, 3.0, 0.3), o + Vector3(px, 1.5, -2.0), _m["blue"])
    _parked_car(o + Vector3(5.5, 0, -2.0), 0.0)
    # верстак и покрышки
    _solid(Vector3(0.8, 0.95, 3.5), o + Vector3(W * 0.5 - 0.6, 0.475, 3.0), _m["wood"])
    _deco(Vector3(0.05, 1.2, 3.0), o + Vector3(W * 0.5 - 0.23, 1.8, 3.0), _m["metal"])
    for tz: float in [-5.8, -4.9]:
        _f_tires(o + Vector3(W * 0.5 - 0.7, 0, tz))
    _f_tires(o + Vector3(W * 0.5 - 1.5, 0, -5.8))
    # столик с картами и стулья
    _f_table(o + Vector3(-2.0, 0, 2.5), 0.0, 1.2, 1.2)
    for ci in 4:
        var ca := ci * PI * 0.5
        _f_chair(o + Vector3(-2.0, 0, 2.5) + Vector3(sin(ca), 0, cos(ca)) * 0.85, ca + PI)
    _deco(Vector3(1.1, 0.01, 1.1), o + Vector3(-2.0, 0.755, 2.5), _fm("cards"))
    # ящики, бочки, телевизор, кресло
    _f_crates(o + Vector3(-W * 0.5 + 1.2, 0, 5.6), 0.1, 4)
    _f_crates(o + Vector3(-W * 0.5 + 2.6, 0, 5.8), -0.1, 2)
    _f_barrel(o + Vector3(W * 0.5 - 0.6, 0, 5.8))
    _f_barrel(o + Vector3(W * 0.5 - 1.3, 0, 6.0))
    _f_tv(o + Vector3(-W * 0.5 + 2.8, 0, -5.9), 0.0)
    _f_armchair(o + Vector3(-W * 0.5 + 4.8, 0, -3.0), -PI * 0.5)
    _gang_gym(o, W, D, accent)
    interiors[gid] = {"spawn": o + Vector3(0, 0.3, D * 0.5 - 3.6), "exit": o + Vector3(0, 0, D * 0.5 - 1.3),
            "hr": o + Vector3(-W * 0.5 + 2.6, 0, -1.2), "desk": o + Vector3(0, 0, 0)}



# ================================================================ детали интерьеров фракций

## Стенд с надписью: доска на стене, заголовок и «листки».
func _stand(p: Vector3, n: Vector3, w: float, h: float, title: String, sheets: int, board_col: Color) -> void:
    var yaw := atan2(n.x, n.z)
    _deco(Vector3(w, h, 0.04), p, _mat(board_col, 0.7), yaw)
    _label(title, p + n * 0.03 + Vector3(0, h * 0.5 - 0.14, 0), n, 34, Color(0.95, 0.85, 0.3) if board_col.v < 0.5 else Color(0.6, 0.08, 0.06))
    var side := Vector3(n.z, 0, -n.x)
    for k in sheets:
        var cols := mini(sheets, 4)
        var cx := (float(k % cols) - (cols - 1) * 0.5) * (w / (cols + 0.5))
        var cy := -0.08 - float(k / cols) * 0.42
        _deco(Vector3(w / (cols + 1.2), 0.32, 0.01), p + n * 0.025 + side * cx + Vector3(0, cy, 0), _fm("paper"), yaw)


func _interior_extras(fk: String, o: Vector3, W: float, D: float, H: float) -> void:
    var red := _fm("red")
    match fk:
        "mayor":
            # зал заседаний: длинный стол, стулья, графины с водой
            _f_table(o + Vector3(6.5, 0, 2.2), 0.0, 1.4, 5.0)
            for k in 4:
                for sx: float in [-1.0, 1.0]:
                    _f_chair(o + Vector3(6.5 + sx * 1.05, 0, 0.4 + k * 1.2), -sx * PI * 0.5)
            for gz: float in [1.0, 3.4]:
                _mdeco(_cyl_mesh(0.05, 0.07, 0.26, 10), o + Vector3(6.5, 0.9, gz), _mat(Color(0.75, 0.88, 0.9, 0.6), 0.05))
            # стенд «План пятилетки — досрочно!» с диаграммой
            var sp := o + Vector3(-2.0, 2.3, D * 0.5 - 0.24)
            _deco(Vector3(3.2, 1.6, 0.04), sp, _mat(Color(0.75, 0.08, 0.07), 0.7))
            _label("ПЛАН ПЯТИЛЕТКИ — ДОСРОЧНО!", sp + Vector3(0, 0.62, -0.03), Vector3(0, 0, -1), 30, Color(1.0, 0.85, 0.3))
            for b in 5:
                var bh := 0.25 + b * 0.18
                _deco(Vector3(0.36, bh, 0.02), sp + Vector3(1.1 - b * 0.55, -0.6 + bh * 0.5, -0.03), _mat(Color(0.98, 0.85, 0.3), 0.5))
            # красная «вертушка» на столе мэра и вымпелы
            _deco(Vector3(0.22, 0.1, 0.18), o + Vector3(0.5, 0.83, -4.6), red)
            for vx: float in [-10.0, -9.2]:
                var pen := MeshInstance3D.new()
                pen.mesh = _cyl_mesh(0.0, 0.25, 0.6, 3)
                pen.material_override = red
                pen.position = o + Vector3(vx, 2.6, -D * 0.5 + 0.25)
                pen.rotation = Vector3(PI, 0, 0)
                add_child(pen)
            _label("ПЕРЕДОВИК", o + Vector3(-9.6, 3.05, -D * 0.5 + 0.27), Vector3(0, 0, 1), 24, Color(1, 0.85, 0.3))
        "police":
            # оружейная пирамида с автоматами (за решёткой) и рация на столе дежурного
            var rp := o + Vector3(-7.5, 0, D * 0.5 - 0.5)
            _solid(Vector3(2.2, 1.5, 0.4), rp + Vector3(0, 0.75, 0), _fm("wood_dark"))
            for k in 5:
                _deco(Vector3(0.07, 0.9, 0.06), rp + Vector3(-0.8 + k * 0.4, 1.9, -0.05), _fm("black"))
                _deco(Vector3(0.05, 0.25, 0.12), rp + Vector3(-0.8 + k * 0.4, 1.7, -0.12), _fm("black"))
            for bk in 7:
                _deco(Vector3(0.03, 1.6, 0.03), rp + Vector3(-1.05 + bk * 0.35, 1.6, -0.25), _m["metal"])
            _label("ОРУЖЕЙНАЯ", rp + Vector3(0, 2.7, -0.28), Vector3(0, 0, -1), 36, Color(0.9, 0.9, 0.9))
            _deco(Vector3(0.2, 0.12, 0.14), o + Vector3(3.1, 0.84, 0.9), _fm("black"), PI * 0.5)
            _deco(Vector3(0.012, 0.3, 0.012), o + Vector3(3.15, 1.05, 0.95), _fm("black"))
            # доска почёта
            _stand(o + Vector3(6.5, 2.2, D * 0.5 - 0.24), Vector3(0, 0, -1), 2.6, 1.4, "ДОСКА ПОЧЁТА", 8, Color(0.75, 0.08, 0.07))
        "kgb":
            # комната допроса: стол, два стула, яркая лампа
            var ip := o + Vector3(-6.5, 0, 3.0)
            _f_table(ip, 0.0, 1.2, 0.8, 0.75, _m["metal"])
            _f_chair(ip + Vector3(0, 0, -0.75), 0.0, _m["metal"])
            _f_chair(ip + Vector3(0, 0, 0.75), PI, _m["metal"])
            _deco(Vector3(0.02, 1.4, 0.02), ip + Vector3(0, 3.7, 0), _m["metal"])
            _mdeco(_cyl_mesh(0.08, 0.3, 0.25, 14), ip + Vector3(0, 2.9, 0), _fm("black"))
            var bulb := _mat(Color(1, 1, 0.9), 0.2)
            bulb.emission_enabled = true
            bulb.emission = Color(1, 0.95, 0.8)
            bulb.emission_energy_multiplier = 3.0
            _mdeco(_sphere_mesh(0.09, 0.18), ip + Vector3(0, 2.76, 0), bulb)
            var sl := SpotLight3D.new()
            sl.position = ip + Vector3(0, 2.8, 0)
            sl.rotation.x = -PI * 0.5
            sl.spot_range = 4.0
            sl.spot_angle = 30.0
            sl.light_energy = 2.5
            add_child(sl)
            # катушечный магнитофон на тумбе
            var mp := o + Vector3(-9.2, 0, 3.0)
            _solid(Vector3(0.7, 0.8, 0.5), mp + Vector3(0, 0.4, 0), _fm("wood_dark"))
            _deco(Vector3(0.5, 0.18, 0.4), mp + Vector3(0, 0.89, 0), _fm("beige"))
            for rx: float in [-0.13, 0.13]:
                var reel := MeshInstance3D.new()
                reel.mesh = _cyl_mesh(0.1, 0.1, 0.02, 16)
                reel.material_override = _fm("black")
                reel.position = mp + Vector3(rx, 0.99, 0)
                add_child(reel)
            # портрет и папки «Секретно»
            var pp := o + Vector3(-W * 0.5 + 0.24, 2.4, -1.0)
            _deco(Vector3(0.04, 1.3, 1.0), pp, _fm("lacquer"))
            _deco(Vector3(0.02, 1.1, 0.8), pp + Vector3(0.025, 0, 0), _mat(Color(0.35, 0.33, 0.30), 0.8))
            _label("Ф. Э. ДЗЕРЖИНСКИЙ", pp + Vector3(0.05, -0.8, 0), Vector3(1, 0, 0), 26, Color(0.95, 0.85, 0.3))
            for fk2 in 4:
                _deco(Vector3(0.3, 0.03, 0.22), o + Vector3(-0.3, 0.79 + fk2 * 0.03, -0.6), _mat(Color(0.75, 0.6, 0.35), 0.8))
            _label("СЕКРЕТНО", o + Vector3(-0.3, 0.92, -0.6), Vector3(0, 1, 0), 18, Color(0.8, 0.1, 0.1))
        "hospital":
            # каталка, весы, капельницы, плакаты
            var gp := o + Vector3(4.5, 0, 4.5)
            _solid(Vector3(0.7, 0.08, 2.0), gp + Vector3(0, 0.85, 0), _fm("white"))
            for cx: float in [-0.3, 0.3]:
                for cz: float in [-0.9, 0.9]:
                    _deco(Vector3(0.04, 0.82, 0.04), gp + Vector3(cx, 0.41, cz), _fm("chrome"))
            var wp := o + Vector3(-6.0, 0, 5.5)
            _solid(Vector3(0.5, 0.08, 0.5), wp + Vector3(0, 0.04, 0), _fm("white"))
            _deco(Vector3(0.05, 1.6, 0.05), wp + Vector3(0, 0.85, -0.2), _fm("chrome"))
            _deco(Vector3(0.3, 0.2, 0.05), wp + Vector3(0, 1.65, -0.2), _fm("white"))
            for bz: float in [-1.5, 1.5, 4.5]:
                var dp := o + Vector3(11.6, 0, bz - 0.7)
                _deco(Vector3(0.03, 1.9, 0.03), dp + Vector3(0, 0.95, 0), _fm("chrome"))
                _deco(Vector3(0.12, 0.2, 0.06), dp + Vector3(0, 1.8, 0), _mat(Color(0.85, 0.92, 0.95, 0.7), 0.1))
            _stand(o + Vector3(-W * 0.5 + 0.24, 2.2, -1.0), Vector3(1, 0, 0), 1.8, 1.2, "ГРИПП ОПАСЕН!", 3, Color(0.92, 0.92, 0.9))
            _stand(o + Vector3(-W * 0.5 + 0.24, 2.2, 1.4), Vector3(1, 0, 0), 1.8, 1.2, "МОЙТЕ РУКИ!", 2, Color(0.92, 0.92, 0.9))
        "fire":
            # пожарный щит: топор, багор, ведро-конус, лом; огнетушители; ящик с песком; колокол тревоги
            var sp := o + Vector3(-W * 0.5 + 0.24, 1.6, -2.5)
            _deco(Vector3(0.04, 1.5, 2.2), sp, red)
            _label("ПОЖАРНЫЙ ЩИТ", sp + Vector3(0.04, 0.6, 0), Vector3(1, 0, 0), 28, Color(1, 1, 1))
            _deco(Vector3(0.06, 0.06, 1.8), sp + Vector3(0.06, 0.25, 0), _m["wood"])                 # багор
            _deco(Vector3(0.06, 0.5, 0.06), sp + Vector3(0.06, -0.2, -0.6), _m["wood"])              # топор
            _deco(Vector3(0.06, 0.12, 0.25), sp + Vector3(0.06, 0.02, -0.6), _m["metal"])
            var cone := MeshInstance3D.new()
            cone.mesh = _cyl_mesh(0.0, 0.15, 0.35, 12)
            cone.material_override = red
            cone.position = sp + Vector3(0.18, -0.25, 0.5)
            cone.rotation.x = PI
            add_child(cone)
            for ex in 3:
                var ext := o + Vector3(-1.4 + ex * 0.45, 0, D * 0.5 - 0.5)
                _mdeco(_cyl_mesh(0.09, 0.09, 0.55, 12), ext + Vector3(0, 0.3, 0), red)
                _mdeco(_cyl_mesh(0.03, 0.05, 0.1, 8), ext + Vector3(0, 0.62, 0), _fm("black"))
            var sb := o + Vector3(-W * 0.5 + 0.8, 0, 1.2)
            _solid(Vector3(0.9, 0.7, 0.6), sb + Vector3(0, 0.35, 0), red)
            _label("ПЕСОК", sb + Vector3(0.46, 0.4, 0), Vector3(1, 0, 0), 30, Color(1, 1, 1))
            var bell := MeshInstance3D.new()
            bell.mesh = _cyl_mesh(0.06, 0.22, 0.28, 16)
            bell.material_override = _mat(Color(0.85, 0.65, 0.2), 0.3)
            bell.position = o + Vector3(3.5, 3.0, D * 0.5 - 0.35)
            add_child(bell)
            _stand(o + Vector3(7.0, 2.2, D * 0.5 - 0.24), Vector3(0, 0, -1), 2.6, 1.3, "БОЕВОЙ РАСЧЁТ", 6, Color(0.15, 0.15, 0.17))


## «Качалка» в гараже ОПГ: штанга на стойках, скамья, гантели, груша, магнитофон и плакат.
func _gang_gym(o: Vector3, W: float, D: float, accent: Color) -> void:
    var gp := o + Vector3(3.0, 0, 3.8)
    var steel := _fm("chrome")
    _solid(Vector3(0.35, 0.45, 1.3), gp + Vector3(0, 0.225, 0), _fm("upholstery"))             # скамья
    for sx: float in [-0.45, 0.45]:
        _deco(Vector3(0.06, 1.1, 0.06), gp + Vector3(sx, 0.55, -0.55), steel)                   # стойки
    _deco(Vector3(1.6, 0.03, 0.03), gp + Vector3(0, 1.1, -0.55), steel)                          # гриф
    for sx: float in [-0.7, 0.7]:
        var pl := MeshInstance3D.new()
        pl.mesh = _cyl_mesh(0.2, 0.2, 0.05, 16)
        pl.material_override = _fm("black")
        pl.position = gp + Vector3(sx, 1.1, -0.55)
        pl.rotation.z = PI * 0.5
        add_child(pl)
    for dk in 4:   # гантели на полу
        _deco(Vector3(0.3, 0.04, 0.04), gp + Vector3(1.3, 0.08, -0.6 + dk * 0.3), steel)
        for sx: float in [-0.13, 0.13]:
            _mdeco(_sphere_mesh(0.06, 0.12), gp + Vector3(1.3 + sx, 0.08, -0.6 + dk * 0.3), _fm("black"))
    # груша на цепи
    var bp := o + Vector3(6.5, 0, 4.5)
    _deco(Vector3(0.02, 1.4, 0.02), bp + Vector3(0, 3.9, 0), _m["metal"])
    _mdeco(_cyl_mesh(0.2, 0.2, 1.0, 14), bp + Vector3(0, 2.7, 0), _mat(Color(0.45, 0.12, 0.08), 0.6))
    _collider(Vector3(0.4, 1.0, 0.4), bp + Vector3(0, 2.7, 0))
    # магнитофон «Электроника» на ящике и плакаты
    var tp := o + Vector3(-W * 0.5 + 1.0, 0, 0.8)
    _solid(Vector3(0.6, 0.5, 0.5), tp + Vector3(0, 0.25, 0), _m["wood"])
    _deco(Vector3(0.55, 0.2, 0.16), tp + Vector3(0, 0.6, 0), _fm("black"))
    for sx: float in [-0.17, 0.17]:
        _mdeco(_cyl_mesh(0.06, 0.06, 0.02, 12), tp + Vector3(sx, 0.6, 0.085), _fm("chrome"))
    _label("ЭЛЕКТРОНИКА", tp + Vector3(0, 0.75, 0.09), Vector3(0, 0, 1), 16, Color(0.9, 0.9, 0.9))
    _label("КАЧАЛКА", o + Vector3(4.5, 3.4, D * 0.5 - 0.25), Vector3(0, 0, -1), 80, accent.lightened(0.2))
    _stand(o + Vector3(1.5, 2.1, D * 0.5 - 0.24), Vector3(0, 0, -1), 1.6, 1.1, "ПАЦАНЫ, НЕ КУРИТЬ!", 2, Color(0.92, 0.92, 0.9))


# ================================================================ балконы и «подогнанные» текстуры

## Балкон: pos — центр (как раньше), n — наружу от стены, r — случайное число (вид и цвет).
func _balcony(pos: Vector3, n: Vector3, r: float) -> void:
    var yaw := atan2(n.x, n.z)
    _put("bal_slab", pos + Vector3(0, -0.46, 0), yaw)
    var k := int(r * 1000.0) % 3
    if r < 0.35:
        var sheet_cols := [Color(0.62, 0.72, 0.80), Color(0.65, 0.75, 0.62), Color(0.90, 0.86, 0.74)]
        _put("bal_sheet", pos + Vector3(0, 0.0, 0), yaw, sheet_cols[k])
    elif r < 0.6:
        var board_cols := [Color(0.95, 0.92, 0.82), Color(0.75, 0.85, 0.78), Color(0.78, 0.84, 0.92)]
        _put("bal_boards", pos + Vector3(0, 0.0, 0), yaw, board_cols[k])
    else:
        _put("bal_rail", pos + Vector3(0, 0.0, 0), yaw)


## Картинка целиком на ящик размера size (решётка, дверь, колонна). Нет файла — просто цвет.
func _fit_mat(tex_name: String, size: Vector3, fallback: Color) -> StandardMaterial3D:
    var m := _mat(fallback, 0.75)
    var t := _tex_mip("res://textures/%s.png" % tex_name)
    if t:
        m.albedo_color = Color.WHITE
        m.albedo_texture = t
        m.uv1_triplanar = true   # по координатам самого ящика
        m.uv1_scale = Vector3(1.0 / size.x, -1.0 / size.y, 1.0 / size.z)
        m.uv1_offset = Vector3(0.5, 0.5, 0.5)
    return m


## Повторяющаяся текстура по миру, цвет даёт экземпляр (MultiMesh).
func _tiled_vc_mat(tex_name: String, meters: float, fallback: Color) -> StandardMaterial3D:
    var m := _vc_mat(0.8)
    m.metallic_specular = 0.25
    var t := _tex_mip("res://textures/%s.png" % tex_name)
    if t:
        _ground_tex(m, t, Color.WHITE, meters)
    else:
        m.albedo_color = fallback
    return m



## Эмблема организации (картинка из textures/emblems) плоской табличкой на стене.
func _emblem(id: String, pos: Vector3, facing: Vector3, size: float) -> void:
    var t := _tex_mip("res://textures/emblems/%s.png" % id)
    if t == null:
        return
    var sp := Sprite3D.new()
    sp.texture = t
    sp.pixel_size = size / float(t.get_width())
    sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
    sp.shaded = true
    sp.double_sided = false
    sp.position = pos
    sp.rotation.y = atan2(facing.x, facing.z)
    sp.visibility_range_end = 120.0
    add_child(sp)



# ================================================================ текстуры организаций (textures/org)

func _org_tex(tex_name: String) -> Texture2D:
    return _tex_mip("res://textures/org/%s.png" % tex_name)


## Фасад из одинаковых модулей «стена + окно»: counts — сколько модулей по X, Y, Z ящика size.
func _module_mat(tex_name: String, size: Vector3, counts: Vector3) -> StandardMaterial3D:
    var m := _mat(Color.WHITE, 0.85)
    m.albedo_texture = _org_tex(tex_name)
    m.uv1_triplanar = true   # по координатам самого здания: модули ровно по краям
    m.uv1_scale = Vector3(counts.x / size.x, -counts.y / size.y, counts.z / size.z)
    m.uv1_offset = Vector3(0.5, 0.5, 0.5)
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m


## Стена в два цвета (низ/верх): картинка на всю высоту стены h, по длине повтор каждые tile м.
func _wall_mat(tex_name: String, h: float, tile: float) -> StandardMaterial3D:
    var m := _mat(Color(0.85, 0.85, 0.82), 0.85)
    var t := _org_tex(tex_name)
    if t:
        m.albedo_color = Color.WHITE
        m.albedo_texture = t
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(1.0 / tile, -1.0 / h, 1.0 / tile)
        m.uv1_offset = Vector3(0.0, 0.5, 0.0)
    return m


## Материал для плоскости (_flat): картинка целиком, rep — повторы по ширине и длине.
func _plane_mat(tex_name: String, rep: Vector2, fallback: Color) -> StandardMaterial3D:
    var m := _mat(fallback, 0.9)
    var t := _org_tex(tex_name)
    if t:
        m.albedo_color = Color.WHITE
        m.albedo_texture = t
        m.uv1_scale = Vector3(rep.x, rep.y, 1.0)
    return m



# ================================================================ жильё

func _address(p: Vector3, flat: bool) -> String:
    var bi := int(floor(p.x / PITCH + 0.5)) + 7
    var bj := int(floor(p.z / PITCH + 0.5)) + 3
    var street: String = STREETS[absi(bi * 3 + bj * 5) % STREETS.size()]
    var num := int(_street_nums.get(street, 0)) + 1
    _street_nums[street] = num
    if flat:
        return "%s, д. %d, кв. %d" % [street, num * 2 + 1, (homes.size() * 37) % 140 + 1]
    return "%s, д. %d" % [street, num * 2]


func _add_home(pos: Vector3, label_pos: Vector3, kind: String, price: int) -> void:
    var l := Label3D.new()
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.font_size = 40
    l.pixel_size = 0.006
    l.outline_size = 10
    l.position = label_pos
    l.visibility_range_end = 35.0
    add_child(l)
    homes.append({"pos": pos, "kind": kind, "price": price, "addr": _address(pos, kind == "flat"), "label": l})


## Частный сектор за восточной окраиной: дорога и 9 домов с участками.
func _build_cottages() -> void:
    var rx := 262.0 + OUT
    _flat(Vector3((222.0 + OUT + rx) * 0.5, 0, 0), Vector2(rx - 222.0 - OUT + 10.0, 10.0), _m["asphalt"], 0.006)
    _map_rect(Vector3((222.0 + OUT + rx) * 0.5, 0, 0), Vector2(rx - 222.0 - OUT + 10.0, 10.0))
    _flat(Vector3(rx, 0, 0), Vector2(10.0, 190.0), _m["asphalt"], 0.007)
    _map_rect(Vector3(rx, 0, 0), Vector2(10.0, 190.0))
    for z: float in [-90.0, -50.0, -10.0, 30.0, 70.0]:
        _lamp(Vector3(rx + 5.6, 0, z + 20.0), Vector3(-1, 0, 0))
    var spots := []
    for z: float in [-70.0, -35.0, 35.0, 70.0]:
        spots.append([Vector3(rx - 17.0, 0, z), Vector3(1, 0, 0)])
    for z: float in [-70.0, -35.0, 0.0, 35.0, 70.0]:
        spots.append([Vector3(rx + 17.0, 0, z), Vector3(-1, 0, 0)])
    var walls := [Color(0.85, 0.78, 0.62), Color(0.72, 0.80, 0.70), Color(0.88, 0.86, 0.80), Color(0.70, 0.55, 0.42),
            Color(0.75, 0.82, 0.88)]
    var roofs := [Color(0.55, 0.18, 0.12), Color(0.25, 0.32, 0.25), Color(0.30, 0.30, 0.34)]
    for k in spots.size():
        var c: Vector3 = spots[k][0]
        var f: Vector3 = spots[k][1]
        _cottage(c, f, walls[k % walls.size()], roofs[k % roofs.size()], 120000 + (k % 3) * 30000)


func _cottage(c: Vector3, front: Vector3, wall_col: Color, roof_col: Color, price: int, log_house := false) -> void:
    var yaw := atan2(front.x, front.z)
    var b := Basis(Vector3.UP, yaw)
    _flat(c, Vector2(24.0, 24.0) if absf(front.x) < 0.5 else Vector2(24.0, 24.0), _m["grass"], 0.01)
    var hc := c + b * Vector3(0, 0, -3.0)
    var wall := _tinted("plaster", wall_col, 3.0)
    if (log_house or int(absf(c.z)) % 2 == 1) and _tex_mip("res://textures/log_wall.png") != null:
        wall = _tinted("log_wall", wall_col.lightened(0.35), 2.5)   # бревенчатый дом
    _solid(Vector3(10.0, 3.4, 8.0), hc + Vector3(0, 1.7, 0), wall, yaw)
    _deco(Vector3(10.3, 0.5, 8.3), hc + Vector3(0, 0.25, 0), _m["plinth"], yaw)
    # двускатная крыша: два наклонных ската
    var roof := _tinted("roof_gravel", roof_col, 2.0)
    if _tex_mip("res://textures/roof_tiles.png") != null:
        roof = _tinted("roof_tiles", roof_col.lightened(0.55), 1.6) if roof_col.r > 0.4 or roof_col.g > 0.3 \
                else _tinted("roof_slate", Color(0.95, 0.95, 0.95), 1.8)
    for side: float in [-1.0, 1.0]:
        var slab := _deco(Vector3(11.0, 0.2, 5.2), hc + b * Vector3(0, 0, 2.15 * side) + Vector3(0, 4.55, 0), roof, yaw)
        slab.rotate_object_local(Vector3.RIGHT, 0.5 * side)
    # фронтоны ступеньками (треугольник под скатами)
    for gx: float in [-4.95, 4.95]:
        for st: int in 3:
            _deco(Vector3(0.2, 0.62, 7.2 - st * 2.6), hc + b * Vector3(gx, 0, 0) + Vector3(0, 3.7 + st * 0.62, 0), wall, yaw)
    _deco(Vector3(0.7, 2.0, 0.7), hc + b * Vector3(3.0, 0, -1.5) + Vector3(0, 5.2, 0), _m["plinth"], yaw)
    # дверь, окна, крыльцо
    _deco(Vector3(1.2, 2.2, 0.08), hc + b * Vector3(0, 0, 4.02) + Vector3(0, 1.1, 0),
            _fit_mat("door_old", Vector3(1.2, 2.2, 0.08), Color(0.35, 0.24, 0.15)), yaw)
    for wx: float in [-3.2, 3.2]:
        _deco(Vector3(1.4, 1.3, 0.08), hc + b * Vector3(wx, 0, 4.02) + Vector3(0, 1.8, 0), _m["vitrine"], yaw)
    _deco(Vector3(3.0, 0.25, 1.6), hc + b * Vector3(0, 0, 4.8) + Vector3(0, 0.12, 0), _m["concrete"], yaw)
    _flat(c + b * Vector3(0, 0, 8.0), Vector2(1.6, 7.0) if absf(front.x) < 0.5 else Vector2(7.0, 1.6), _m["path"], 0.012)
    # забор по трём сторонам (спереди — калитка)
    var fence: Material = _m["wood"]
    if _tex_mip("res://textures/fence_green.png") != null:
        fence = _tinted("fence_green", Color(1, 1, 1), 2.0)
    _solid(Vector3(24.0, 1.2, 0.08), c + b * Vector3(0, 0, -12.0) + Vector3(0, 0.6, 0), fence, yaw)
    for sx: float in [-12.0, 12.0]:
        _solid(Vector3(0.08, 1.2, 24.0), c + b * Vector3(sx, 0, 0) + Vector3(0, 0.6, 0), fence, yaw)
    for sx: float in [-7.0, 7.0]:
        _solid(Vector3(10.0, 1.2, 0.08), c + b * Vector3(sx, 0, 12.0) + Vector3(0, 0.6, 0), fence, yaw)
    _tree(c + b * Vector3(-8.0, 0, -9.0))
    _tree(c + b * Vector3(8.5, 0, 7.0))
    _occupy(c, 24.0, 24.0)
    building_rects.append(Rect2(hc.x - (5.0 if absf(front.x) < 0.5 else 4.0), hc.z - (4.0 if absf(front.x) < 0.5 else 5.0),
            10.0 if absf(front.x) < 0.5 else 8.0, 8.0 if absf(front.x) < 0.5 else 10.0))
    _add_home(hc + b * Vector3(0, 0, 5.8), hc + b * Vector3(0, 0, 4.6) + Vector3(0, 3.0, 0), "house", price)


## Квартира и частный дом внутри: диван, кровать, кухня с холодильником, телевизор, ковёр.
func _build_home_interiors() -> void:
    home_interiors["flat"] = _home_room(Vector3(2000.0, SIDE_H, 2700.0), 12.0, 9.0, Color(0.86, 0.80, 0.66))
    home_interiors["house"] = _home_room(Vector3(2100.0, SIDE_H, 2700.0), 16.0, 11.0, Color(0.80, 0.86, 0.80))


func _home_room(o: Vector3, w: float, d: float, wall_col: Color) -> Dictionary:
    const H := 3.0
    var wall := _tinted("plaster", wall_col, 2.0)
    if _tex_mip("res://textures/wallpaper_floral.png") != null:
        wall = _tinted("wallpaper_floral" if w < 14.0 else "wallpaper_stripes", Color(1, 1, 1), 1.2)
    var floor_mat: Material = _tinted("org/parquet", Color(1, 1, 1), 1.6) if _org_tex("parquet") != null else _m["wood"]
    _solid(Vector3(w + 1.0, 0.4, d + 1.0), o + Vector3(0, -0.2, 0), floor_mat)
    _solid(Vector3(w + 1.0, 0.4, d + 1.0), o + Vector3(0, H + 0.2, 0), _ceiling_mat())
    _solid(Vector3(0.4, H, d), o + Vector3(-w * 0.5, H * 0.5, 0), wall)
    _solid(Vector3(0.4, H, d), o + Vector3(w * 0.5, H * 0.5, 0), wall)
    _solid(Vector3(w, H, 0.4), o + Vector3(0, H * 0.5, -d * 0.5), wall)
    _solid(Vector3(w, H, 0.4), o + Vector3(0, H * 0.5, d * 0.5), wall)
    var ol := OmniLight3D.new()
    ol.position = o + Vector3(0, H - 0.5, 0)
    ol.omni_range = maxf(w, d)
    ol.omni_attenuation = 1.0
    ol.light_energy = 1.2
    ol.light_color = Color(1.0, 0.9, 0.75)
    add_child(ol)
    var lamp := _mat(Color(1, 0.95, 0.85), 0.3)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.9, 0.7)
    lamp.emission_energy_multiplier = 1.5
    _deco(Vector3(0.7, 0.25, 0.7), o + Vector3(0, H - 0.15, 0), lamp)
    # дверь
    _deco(Vector3(1.1, 2.2, 0.06), o + Vector3(0, 1.1, d * 0.5 - 0.22), _fit_mat("door_apartment" if ResourceLoader.exists("res://textures/door_apartment.png") else "door_old", Vector3(1.1, 2.2, 0.06), Color(0.35, 0.24, 0.15)))
    _label("ВЫХОД", o + Vector3(0, 2.5, d * 0.5 - 0.25), Vector3(0, 0, -1), 48, Color(0.3, 0.9, 0.4))
    # окно с «улицей» за ним
    var sky := _mat(Color(0.6, 0.75, 0.9), 0.5)
    sky.emission_enabled = true
    sky.emission = Color(0.55, 0.7, 0.9)
    sky.emission_energy_multiplier = 0.6
    var view := _tex_mip("res://textures/window_view.png")
    if view:
        sky.albedo_color = Color.WHITE
        sky.albedo_texture = view
        sky.emission = Color(1, 1, 1)
        sky.emission_texture = view
        sky.uv1_triplanar = true
        sky.uv1_scale = Vector3(1.0 / 2.4, -1.0 / 1.4, 1.0)
        sky.uv1_offset = Vector3(0.5, 0.5, 0.5)
    _deco(Vector3(2.4, 1.4, 0.05), o + Vector3(-1.5, 1.7, -d * 0.5 + 0.23), sky)
    _deco(Vector3(2.6, 0.1, 0.25), o + Vector3(-1.5, 0.95, -d * 0.5 + 0.3), _m["white"])
    # ковёр на стене, диван, столик, телевизор
    _deco(Vector3(0.03, 1.6, 2.4), o + Vector3(-w * 0.5 + 0.23, 1.7, -0.5), _fit_mat("org/carpet_wall", Vector3(0.03, 1.6, 2.4), Color(0.55, 0.12, 0.1)))
    var sofa := _fit_mat("org/sofa", Vector3(1.0, 1.0, 2.6), Color(0.35, 0.22, 0.14))
    _solid(Vector3(0.9, 0.45, 2.6), o + Vector3(-w * 0.5 + 0.7, 0.225, -0.5), sofa)
    _deco(Vector3(0.25, 0.55, 2.6), o + Vector3(-w * 0.5 + 0.35, 0.72, -0.5), sofa)
    _solid(Vector3(0.8, 0.45, 1.2), o + Vector3(-w * 0.5 + 2.2, 0.225, -0.5), _m["wood"])
    _solid(Vector3(0.5, 0.6, 1.6), o + Vector3(-1.0 + w * 0.5 - 4.0, 0.3, -0.5), _m["wood"])
    _deco(Vector3(0.5, 0.9, 1.2), o + Vector3(-1.0 + w * 0.5 - 4.0, 1.05, -0.5), _fit_mat("tv", Vector3(0.5, 0.9, 1.2), Color(0.05, 0.05, 0.06)))
    # кровать
    _solid(Vector3(1.6, 0.55, 2.1), o + Vector3(w * 0.5 - 1.1, 0.275, -d * 0.5 + 1.5),
            _fit_mat("org/bed_sheet", Vector3(1.6, 0.55, 2.1), Color(0.95, 0.95, 0.95)))
    # кухня: столешница и холодильник
    _solid(Vector3(0.7, 0.9, 2.6), o + Vector3(w * 0.5 - 0.55, 0.45, d * 0.5 - 2.6), _fit_mat("kitchen_cabinet", Vector3(0.7, 0.9, 1.3), Color(0.6, 0.5, 0.4)))
    _solid(Vector3(0.8, 1.9, 0.8), o + Vector3(w * 0.5 - 0.6, 0.95, d * 0.5 - 0.8), _fit_mat("fridge", Vector3(0.8, 1.9, 0.8), Color(0.93, 0.93, 0.92)))
    _deco(Vector3(0.45, 0.03, 0.5), o + Vector3(w * 0.5 - 0.55, 0.915, d * 0.5 - 2.0), _fm("chrome"))   # мойка
    _f_stove(o + Vector3(w * 0.5 - 0.55, 0, d * 0.5 - 4.25), -PI * 0.5)
    # кухонный стол с табуретками
    _f_table(o + Vector3(w * 0.5 - 2.4, 0, d * 0.5 - 2.4), 0.0, 0.9, 0.9, 0.75, _fm("wood_light"))
    _f_chair(o + Vector3(w * 0.5 - 3.2, 0, d * 0.5 - 2.4), PI * 0.5, _fm("wood_light"))
    _f_chair(o + Vector3(w * 0.5 - 2.4, 0, d * 0.5 - 1.6), PI, _fm("wood_light"))
    # «стенка», люстра, ковёр, шторы, батарея
    _f_stenka(o + Vector3(1.9, 0, -d * 0.5 + 0.45), 0.0, 3.0)
    _f_chandelier(o + Vector3(-1.5, 0, -0.5), H)
    _f_chandelier(o + Vector3(w * 0.5 - 2.4, 0, d * 0.5 - 2.4), H)
    _flat(o + Vector3(-w * 0.5 + 2.4, 0, -0.5), Vector2(2.6, 3.4), _plane_mat("carpet_wall", Vector2(1, 1), Color(0.5, 0.1, 0.1)), o.y + 0.01)
    _f_curtains(o + Vector3(-1.5, 0.9, -d * 0.5 + 0.28), 0.0, 2.4, 1.5)
    _f_radiator(o + Vector3(-1.5, 0, -d * 0.5 + 0.3), 0.0, 1.6)
    # кресло, тумбочка с лампой, шкаф, цветы, часы, картина
    _f_armchair(o + Vector3(-w * 0.5 + 2.4, 0, 1.6), PI * 0.5 + 0.4)
    _solid(Vector3(0.45, 0.5, 0.45), o + Vector3(w * 0.5 - 2.25, 0.25, -d * 0.5 + 0.6), _fm("wood_dark"))
    _mdeco(_cyl_mesh(0.03, 0.06, 0.3, 8), o + Vector3(w * 0.5 - 2.25, 0.65, -d * 0.5 + 0.6), _fm("chrome"))
    _mdeco(_cyl_mesh(0.08, 0.16, 0.18, 10), o + Vector3(w * 0.5 - 2.25, 0.86, -d * 0.5 + 0.6), _fm("lampshade"))
    _solid(Vector3(0.6, 2.1, 1.3), o + Vector3(w * 0.5 - 0.5, 1.05, -0.85), _fm("lacquer"))
    _deco(Vector3(0.01, 1.9, 0.01), o + Vector3(w * 0.5 - 0.8, 1.05, -0.85), _fm("black"))
    _f_plant(o + Vector3(-w * 0.5 + 0.5, 0, d * 0.5 - 0.6), true)
    _f_plant(o + Vector3(-3.6, 0.0, -d * 0.5 + 0.5))
    _f_clock(o + Vector3(1.9, 2.6, -d * 0.5 + 0.22), 0.0)
    _f_picture(o + Vector3(-w * 0.5 + 0.22, 1.9, 2.4), PI * 0.5, 1.0, 0.6)
    return {"spawn": o + Vector3(0, 0.3, d * 0.5 - 2.6), "exit": o + Vector3(0, 0, d * 0.5 - 1.0),
            "fridge": o + Vector3(w * 0.5 - 1.6, 0, d * 0.5 - 1.2), "bed": o + Vector3(w * 0.5 - 2.3, 0, -d * 0.5 + 1.6)}



## СТО: навес с подъёмником, площадка; заезжать на машине (точка «СТО»).
func _service(c: Vector3, front: Vector3) -> void:
    var yaw := atan2(front.x, front.z)
    var b := Basis(Vector3.UP, yaw)
    _flat(c, Vector2(22.0, 16.0) if absf(front.x) < 0.5 else Vector2(16.0, 22.0), _m["yard_asphalt"], 0.012)
    var wall := _tinted("corrugated" if ResourceLoader.exists("res://textures/corrugated.png") else "metal_wall", Color(0.75, 0.78, 0.82), 1.5)
    _solid(Vector3(14.0, 4.5, 0.3), c + b * Vector3(0, 0, -6.0) + Vector3(0, 2.25, 0), wall, yaw)
    for sx: float in [-7.0, 7.0]:
        _solid(Vector3(0.3, 4.5, 6.0), c + b * Vector3(sx, 0, -3.0) + Vector3(0, 2.25, 0), wall, yaw)
    _deco(Vector3(14.6, 0.3, 6.6), c + b * Vector3(0, 0, -3.0) + Vector3(0, 4.6, 0), _m["roof"], yaw)
    _deco(Vector3(8.0, 1.3, 0.15), c + b * Vector3(0, 0, 0.2) + Vector3(0, 5.2, 0), _m["sign"], yaw)
    _label("СТО · РЕМОНТ · ТЮНИНГ", c + b * Vector3(0, 0, 0.3) + Vector3(0, 5.2, 0), front, 90, Color(0.15, 0.3, 0.75))
    for sx: float in [-2.2, 2.2]:
        _solid(Vector3(0.3, 3.0, 0.3), c + b * Vector3(sx, 0, -3.0) + Vector3(0, 1.5, 0), _m["blue"], yaw)
    for tz: float in [-5.0, -4.0]:
        _f_tires(c + b * Vector3(6.0, 0, tz))
    _f_barrel(c + b * Vector3(-6.0, 0, -5.0))
    _f_barrel(c + b * Vector3(-5.3, 0, -5.2))
    _occupy(c, 22.0, 16.0)
    var bc := c + b * Vector3(0, 0, -3.0)
    building_rects.append(Rect2(bc.x - (7.0 if absf(front.x) < 0.5 else 3.0), bc.z - (3.0 if absf(front.x) < 0.5 else 7.0),
            14.0 if absf(front.x) < 0.5 else 6.0, 6.0 if absf(front.x) < 0.5 else 14.0))
    service_stations.append(c + b * Vector3(0, 0, -2.0))



# ================================================================ потолки, плоскости, реклама, декали

func _ceiling_mat() -> Material:
    if _tex_mip("res://textures/ceiling.png") != null:
        return _tinted("ceiling", Color(1, 1, 1), 2.0)
    return _m["white"]


## Картинка на плоскость (PlaneMesh): rep — повторы по X и Z.
func _fit_plane(tex_name: String, rep: Vector2, fallback: Color) -> StandardMaterial3D:
    var m := _mat(fallback, 0.85)
    var t := _tex_mip("res://textures/%s.png" % tex_name)
    if t:
        m.albedo_color = Color.WHITE
        m.albedo_texture = t
        m.uv1_scale = Vector3(rep.x, rep.y, 1.0)
    return m


## Рекламные щиты вдоль окружной дороги (вымышленные бренды).
func _build_billboards() -> void:
    var ads := ["ad_juice", "ad_mobile", "ad_cars", "ad_bank", "ad_food", "ad_energy"]
    var k := 0
    var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for n: Vector3 in dirs:
        var tangent := Vector3(-n.z, 0, n.x)
        for t: float in [-110.0, 110.0]:
            var pos := n * (232.0 + OUT) + tangent * t
            _billboard(pos, -n, String(ads[k % ads.size()]))
            k += 1


func _billboard(pos: Vector3, facing: Vector3, ad: String) -> void:
    var t := _tex_mip("res://textures/ads/%s.png" % ad)
    if t == null:
        return
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    for sx: float in [-2.2, 2.2]:
        _solid(Vector3(0.3, 4.5, 0.3), pos + b * Vector3(sx, 0, -0.2) + Vector3(0, 2.25, 0), _m["metal"], yaw)
    _deco(Vector3(7.0, 3.8, 0.25), pos + b * Vector3(0, 0, -0.2) + Vector3(0, 6.2, 0), _tinted("mat_rust_panel", Color(0.9, 0.9, 0.9), 2.0), yaw)
    var m := _mat(Color.WHITE, 0.6)
    m.albedo_texture = t
    m.emission_enabled = true          # щит слегка подсвечен — виден и ночью
    m.emission_texture = t
    m.emission_energy_multiplier = 0.35
    var q := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(6.6, 3.4)
    q.mesh = qm
    q.material_override = m
    q.position = pos + b * Vector3(0, 0, -0.06) + Vector3(0, 6.2, 0)
    q.rotation.y = yaw
    q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    q.visibility_range_end = 300.0
    add_child(q)
    _occupy(pos, 8.0, 3.0)


var _puddle_mat: StandardMaterial3D = null
var _drng := RandomNumberGenerator.new()


func _decal_mat(dname: String) -> StandardMaterial3D:
    var t := _tex_mip("res://textures/decals/%s.png" % dname)
    if t == null:
        return null
    var m := StandardMaterial3D.new()
    m.albedo_texture = t
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.roughness = 0.9
    m.metallic_specular = 0.2
    return m


## Грязь, люки, лужи, мусор на дорогах и тротуарах; подтёки, граффити и объявления на стенах.
func _build_decals() -> void:
    if _decal_mat("manhole") == null:
        return
    _drng.seed = 4242
    var plane := PlaneMesh.new()
    plane.size = Vector2.ONE
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    for dn: String in ["manhole", "drain", "crack", "oil", "puddle", "patch", "litter", "leaves"]:
        var m := _decal_mat(dn)
        if dn == "puddle":
            m.roughness = 0.05
            m.metallic = 0.3
            m.albedo_color.a = 0.0
            _puddle_mat = m
        _batch("dec_" + dn, plane, m, 120.0 if dn != "litter" else 60.0)
    for dn: String in ["graffiti_green", "graffiti_blue", "graffiti_yellow", "graffiti_red", "posters", "dirt_streak", "rust_streak"]:
        _batch("dec_" + dn, quad, _decal_mat(dn), 160.0)

    # дороги: люки по оси, заплатки, трещины, пятна масла, лужи; решётки ливнёвки у бордюра (Казань и Пятигорск)
    var py_lines: Array[float] = []
    for k: int in range(-PY_GRID - 1, PY_GRID + 1):
        py_lines.append((k + 0.5) * PITCH)
    for cdef: Array in [[Vector3.ZERO, extent - ROAD, road_lines], [PY_ORG, (PY_GRID + 0.5) * PITCH - ROAD * 0.5, py_lines]]:
        _road_decals(cdef[0], cdef[1], cdef[2])
    _decals_rest()


func _road_decals(org: Vector3, ext: float, lines: Array) -> void:
    for t: float in lines:
        for along_x: bool in [true, false]:
            var steps := int(ext * 2.0 / 18.0)
            for k in steps:
                var u := -ext + 9.0 + k * 18.0 + _drng.randf_range(-4.0, 4.0)
                if absf(fposmod(u, PITCH) - PITCH * 0.5) < ROAD:   # не на перекрёстке
                    continue
                var r := _drng.randf()
                var across := _drng.randf_range(-4.5, 4.5)
                var p := Vector3(u, 0.0, t + across) if along_x else Vector3(t + across, 0.0, u)
                var yaw := _drng.randf() * TAU
                if r < 0.12:
                    var mp := Vector3(u, 0, t) if along_x else Vector3(t, 0, u)
                    _put("dec_manhole", org + mp + Vector3(0, 0.014, 0), yaw, Color.WHITE, Vector3(0.9, 1, 0.9))
                elif r < 0.24:
                    _put("dec_patch", org + p + Vector3(0, 0.012, 0), yaw, Color.WHITE, Vector3(2.2, 1, 2.2))
                elif r < 0.38:
                    _put("dec_crack", org + p + Vector3(0, 0.013, 0), yaw, Color.WHITE, Vector3(2.5, 1, 2.5))
                elif r < 0.50:
                    _put("dec_oil", org + p + Vector3(0, 0.013, 0), yaw, Color.WHITE, Vector3(1.6, 1, 1.6))
                elif r < 0.66:
                    _put("dec_puddle", org + p + Vector3(0, 0.015, 0), yaw, Color.WHITE, Vector3(2.8, 1, 2.0))
                elif r < 0.78:
                    var side := 1.0 if _drng.randf() < 0.5 else -1.0
                    var dp := Vector3(u, 0, t + 6.4 * side) if along_x else Vector3(t + 6.4 * side, 0, u)
                    _put("dec_drain", org + dp + Vector3(0, 0.014, 0), 0.0 if along_x else PI * 0.5, Color.WHITE, Vector3(0.9, 1, 0.5))


func _decals_rest() -> void:
    # тротуары и дворы у подъездов: мусор и листья
    for p: Vector3 in dropoffs:
        var r := _drng.randf()
        var off := Vector3(_drng.randf_range(-2.5, 2.5), 0, _drng.randf_range(-2.5, 2.5))
        if r < 0.3:
            _put("dec_litter", p + off + Vector3(0, 0.02, 0), _drng.randf() * TAU, Color.WHITE, Vector3(1.4, 1, 1.4))
        elif r < 0.65:
            _put("dec_leaves", p + off + Vector3(0, 0.02, 0), _drng.randf() * TAU, Color.WHITE, Vector3(2.2, 1, 2.2))
    for p: Vector3 in forest_trees:
        _put("dec_leaves", p + Vector3(1.5, 0.03, 0.5), _drng.randf() * TAU, Color.WHITE, Vector3(3.0, 1, 3.0))
    # стены: подтёки от крыш, граффити и объявления у подъездов
    for w: Array in _wall_spots:
        var pos: Vector3 = w[0]
        var n: Vector3 = w[1]
        var h: float = w[2]
        var low: bool = w[3]
        var yaw := atan2(n.x, n.z)
        var r := _drng.randf()
        if r < 0.55:
            var slen := minf(h * 0.4, _drng.randf_range(2.5, 6.0))
            var kind := "dec_rust_streak" if _drng.randf() < 0.35 else "dec_dirt_streak"
            _put(kind, pos + n * 0.03 + Vector3(_drng.randf_range(-1, 1) * absf(n.z), h - slen * 0.5 - 0.3, _drng.randf_range(-1, 1) * absf(n.x)),
                    yaw, Color.WHITE, Vector3(_drng.randf_range(1.0, 1.8), slen, 1))
        if low and _drng.randf() < 0.45:
            var g: String = ["dec_graffiti_green", "dec_graffiti_blue", "dec_graffiti_yellow", "dec_graffiti_red"][_drng.randi() % 4]
            var side := Vector3(-n.z, 0, n.x) * _drng.randf_range(-4.0, 4.0)
            _put(g, pos + n * 0.035 + side + Vector3(0, 1.5, 0), yaw, Color.WHITE, Vector3(3.2, 1.6, 1))
        elif _drng.randf() < 0.3:
            var side := Vector3(-n.z, 0, n.x) * _drng.randf_range(2.0, 4.0)
            _put("dec_posters", pos + n * 0.035 + side + Vector3(0, 1.5, 0), yaw, Color.WHITE, Vector3(1.2, 1.2, 1))
        if low and _drng.randf() < 0.22:
            _tag(pos, n)


## Надпись баллончиком на стене: «пацанские» метки районов, как в Казани конца 80-х.
## В Казани — «Солнечные» и «Кавказ», в Пятигорске — «Тяп-Ляп» и «Универсам»; плюс «Цой жив», «Кино»...
const TAGS_KAZAN := ["СОЛНЕЧНЫЕ", "КАВКАЗ", "СОЛНЕЧНЫЕ — СИЛА", "ЦОЙ ЖИВ", "КИНО", "АЙДА!", "ЗДЕСЬ БЫЛ ВАСЯ"]
const TAGS_PYAT := ["ТЯП-ЛЯП", "УНИВЕРСАМ", "УНИВЕРСАМ — НАШ РАЙОН", "ЦОЙ ЖИВ", "ТЯП-ЛЯП РУЛИТ", "АЙДА!", "КИНО"]
const TAG_COLORS := [Color(0.85, 0.12, 0.10), Color(0.10, 0.35, 0.85), Color(0.95, 0.95, 0.95), Color(0.10, 0.10, 0.10),
        Color(0.15, 0.6, 0.2)]


func _tag(pos: Vector3, n: Vector3) -> void:
    var tags: Array = TAGS_PYAT if pos.x < RIVER_X0 else TAGS_KAZAN
    var l := Label3D.new()
    l.text = tags[_drng.randi() % tags.size()]
    l.font_size = _drng.randi_range(90, 140)
    l.pixel_size = 0.009
    l.outline_size = 0
    l.modulate = TAG_COLORS[_drng.randi() % TAG_COLORS.size()]
    l.modulate.a = 0.9
    l.double_sided = false
    l.shaded = false
    l.visibility_range_end = 70.0
    var side := Vector3(-n.z, 0, n.x) * _drng.randf_range(-5.0, 5.0)
    l.position = pos + n * 0.04 + side + Vector3(0, _drng.randf_range(1.0, 2.0), 0)
    l.rotation = Vector3(0, atan2(n.x, n.z), _drng.randf_range(-0.12, 0.12))
    add_child(l)


## Места на стенах для декалей: [точка у основания стены, наружу, высота, низкий ли дом].
var _wall_spots: Array = []


# ================================================================ мебель и мелочи для интерьеров

var _fmat := {}


## Материалы мебели (создаются один раз).
func _fm(key: String) -> Material:
    if _fmat.has(key):
        return _fmat[key]
    var m: StandardMaterial3D
    match key:
        "wood_dark":
            m = _tinted("mat_wood_table", Color(0.9, 0.85, 0.8), 1.0) if ResourceLoader.exists("res://textures/mat_wood_table.png") else _tinted("wood_planks", Color(0.50, 0.33, 0.22), 1.0)
        "wood_light":
            m = _tinted("wood_planks", Color(1.0, 0.90, 0.75), 1.0)
        "lacquer":   # полированная «стенка»
            m = _mat(Color(0.32, 0.17, 0.09), 0.25)
            var t := _tex_mip("res://textures/mat_lacquer.png")
            if t == null:
                t = _tex_mip("res://textures/wood_planks.png")
            if t:
                _ground_tex(m, t, Color(1, 1, 1) if ResourceLoader.exists("res://textures/mat_lacquer.png") else Color(0.55, 0.32, 0.20), 0.8)
                m.roughness = 0.22
        "chrome":
            m = _tinted("mat_chrome", Color(1, 1, 1), 0.5) if ResourceLoader.exists("res://textures/mat_chrome.png") else _mat(Color(0.75, 0.76, 0.78), 0.2)
            m.metallic = 0.6
            m.roughness = 0.3
        "black":
            m = _tinted("mat_plastic_black", Color(1, 1, 1), 0.4) if ResourceLoader.exists("res://textures/mat_plastic_black.png") else _mat(Color(0.05, 0.05, 0.05), 0.5)
            m.roughness = 0.55
        "beige":
            m = _tinted("mat_plastic_beige", Color(1, 1, 1), 0.4) if ResourceLoader.exists("res://textures/mat_plastic_beige.png") else _mat(Color(0.80, 0.76, 0.66), 0.6)
        "white":
            m = _tinted("mat_enamel", Color(1, 1, 1), 0.7) if ResourceLoader.exists("res://textures/mat_enamel.png") else _mat(Color(0.93, 0.93, 0.92), 0.3)
            m.roughness = 0.3
        "paper":
            m = _mat(Color(0.96, 0.95, 0.90), 0.9)
        "screen":
            m = _mat(Color(0.05, 0.12, 0.10), 0.2)
            m.emission_enabled = true
            m.emission = Color(0.20, 0.75, 0.45)
            m.emission_energy_multiplier = 0.6
        "lampshade":
            m = _mat(Color(1.0, 0.90, 0.65), 0.6)
            m.emission_enabled = true
            m.emission = Color(1.0, 0.85, 0.55)
            m.emission_energy_multiplier = 1.2
            var lt := _tex_mip("res://textures/mat_lampshade.png")
            if lt:
                m.albedo_color = Color.WHITE
                m.albedo_texture = lt
                m.emission = Color(1, 1, 1)
                m.emission_texture = lt
        "green_glass":
            m = _mat(Color(0.10, 0.45, 0.20), 0.2)
            m.emission_enabled = true
            m.emission = Color(0.20, 0.60, 0.25)
            m.emission_energy_multiplier = 0.5
        "radiator":
            m = _obj_mat("obj_radiator", Vector3(0.3, 0.62, 0.09), Color(0.90, 0.90, 0.88), true)
        "curtain":
            m = _tinted("cloth_gabardine", Color(1.0, 0.92, 0.80), 0.8)
        "armchair":
            m = _tinted("cloth_corduroy", Color(1, 1, 1), 0.6)
        "upholstery":
            m = _tinted("cloth_quilted_navy", Color(0.9, 0.9, 0.9), 0.8)
        "pot":
            m = _tinted("mat_terracotta", Color(1, 1, 1), 0.5) if ResourceLoader.exists("res://textures/mat_terracotta.png") else _mat(Color(0.62, 0.30, 0.18), 0.8)
        "soil":
            m = _tinted("mat_soil", Color(1, 1, 1), 0.4) if ResourceLoader.exists("res://textures/mat_soil.png") else _mat(Color(0.20, 0.13, 0.08), 1.0)
        "red":
            m = _mat(Color(0.75, 0.08, 0.06), 0.5)
        "barrel":
            m = _mat(Color(0.15, 0.30, 0.55), 0.5)
            var t2 := _tex_mip("res://textures/obj_barrel.png")
            if t2:
                m.albedo_color = Color.WHITE
                m.albedo_texture = t2   # цилиндр сам оборачивает картинку вокруг
            else:
                t2 = _tex_mip("res://textures/painted_metal.png")
                if t2:
                    _ground_tex(m, t2, Color(0.35, 0.50, 0.85), 1.0)
        "tires":
            m = _fit_mat("tires", Vector3(0.75, 1.2, 0.75), Color(0.07, 0.07, 0.07))
            m.roughness = 0.9
        "box":
            m = _fit_mat("box_cardboard", Vector3(0.6, 0.6, 0.6), Color(0.72, 0.55, 0.35))
        "pallet":
            m = _fit_mat("pallet", Vector3(1.2, 0.15, 1.0), Color(0.6, 0.45, 0.3))
        "tv":
            m = _fit_mat("tv", Vector3(0.5, 0.55, 0.6), Color(0.05, 0.05, 0.06))
        "monitor":
            m = _obj_mat("obj_monitor", Vector3(0.42, 0.36, 0.4), Color(0.80, 0.76, 0.66))
        "keyboard":
            m = _obj_mat("obj_keyboard", Vector3(0.45, 0.025, 0.16), Color(0.80, 0.76, 0.66))
        "phone":
            m = _obj_mat("obj_phone", Vector3(0.2, 0.08, 0.16), Color(0.75, 0.08, 0.06), true)
        "papers":
            m = _obj_mat("obj_papers", Vector3(0.3, 0.01, 0.22), Color(0.96, 0.95, 0.90))
        "stove":
            m = _obj_mat("obj_stove", Vector3(0.6, 0.85, 0.6), Color(0.93, 0.93, 0.92))
        "med_cabinet":
            m = _obj_mat("obj_med_cabinet", Vector3(1.2, 1.9, 0.45), Color(0.93, 0.93, 0.92))
        "cooler":
            m = _obj_mat("obj_cooler", Vector3(0.4, 1.45, 0.4), Color(0.85, 0.88, 0.9), true)
        "cards":
            m = _obj_mat("obj_cards", Vector3(0.9, 0.01, 0.9), Color(0.1, 0.4, 0.15))
        "picture":
            m = _fit_mat("window_view", Vector3(0.05, 0.55, 1.0), Color(0.5, 0.6, 0.7))
        "posters":
            m = _fit_mat("decals/posters", Vector3(0.05, 1.0, 1.4), Color(0.9, 0.9, 0.85))
        _:
            m = _mat(Color(0.5, 0.5, 0.5), 0.7)
    _fmat[key] = m
    return m


## Точка p + поворот yaw + смещение l (в осях предмета).
func _at(p: Vector3, yaw: float, l: Vector3) -> Vector3:
    return p + Basis(Vector3.UP, yaw) * l


## Цилиндр/шар как украшение (без столкновений).
func _mdeco(mesh: Mesh, center: Vector3, mat: Material, yaw := 0.0) -> void:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = center
    mi.rotation.y = yaw
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


## Стул: сиденье, спинка, 4 ножки. Спинка сзади (-Z предмета), сидят лицом в +Z.
func _f_chair(p: Vector3, yaw: float, mat: Material = null) -> void:
    var m: Material = mat if mat else _fm("wood_dark")
    _solid(Vector3(0.46, 0.05, 0.46), _at(p, yaw, Vector3(0, 0.45, 0)), m, yaw)
    _collider(Vector3(0.46, 0.45, 0.46), _at(p, yaw, Vector3(0, 0.225, 0)), yaw)
    _deco(Vector3(0.46, 0.5, 0.04), _at(p, yaw, Vector3(0, 0.72, -0.21)), m, yaw)
    for lx: float in [-0.2, 0.2]:
        for lz: float in [-0.2, 0.2]:
            _deco(Vector3(0.04, 0.43, 0.04), _at(p, yaw, Vector3(lx, 0.215, lz)), m, yaw)


## Стол на четырёх ножках.
func _f_table(p: Vector3, yaw: float, w: float, d: float, h := 0.75, mat: Material = null) -> void:
    var m: Material = mat if mat else _fm("wood_dark")
    _solid(Vector3(w, 0.05, d), _at(p, yaw, Vector3(0, h - 0.025, 0)), m, yaw)
    _collider(Vector3(w, h - 0.05, d), _at(p, yaw, Vector3(0, (h - 0.05) * 0.5, 0)), yaw)
    for lx: float in [-w * 0.5 + 0.06, w * 0.5 - 0.06]:
        for lz: float in [-d * 0.5 + 0.06, d * 0.5 - 0.06]:
            _deco(Vector3(0.05, h - 0.05, 0.05), _at(p, yaw, Vector3(lx, (h - 0.05) * 0.5, lz)), m, yaw)


## Конторский стол: тумба с ящиками, монитор-«ящик», клавиатура, бумаги, лампа, стул.
func _f_desk(p: Vector3, yaw: float, green_lamp := false) -> void:
    var wood := _fm("wood_dark")
    _solid(Vector3(1.5, 0.05, 0.75), _at(p, yaw, Vector3(0, 0.75, 0)), wood, yaw)
    _collider(Vector3(1.5, 0.72, 0.75), _at(p, yaw, Vector3(0, 0.36, 0)), yaw)
    _deco(Vector3(0.45, 0.72, 0.7), _at(p, yaw, Vector3(0.48, 0.36, 0)), wood, yaw)
    for dy: float in [0.18, 0.4, 0.62]:
        _deco(Vector3(0.12, 0.02, 0.02), _at(p, yaw, Vector3(0.48, dy, 0.36)), _fm("chrome"), yaw)
    _deco(Vector3(0.05, 0.72, 0.7), _at(p, yaw, Vector3(-0.7, 0.36, 0)), wood, yaw)
    _deco(Vector3(1.4, 0.4, 0.03), _at(p, yaw, Vector3(0, 0.5, -0.33)), wood, yaw)
    if green_lamp:
        _mdeco(_cyl_mesh(0.07, 0.07, 0.3, 8), _at(p, yaw, Vector3(-0.5, 0.92, -0.15)), _fm("chrome"))
        _deco(Vector3(0.38, 0.1, 0.14), _at(p, yaw, Vector3(-0.5, 1.1, -0.1)), _fm("green_glass"), yaw)
        _deco(Vector3(0.5, 0.01, 0.35), _at(p, yaw, Vector3(0.15, 0.78, 0.05)), _fm("papers"), yaw)
    else:
        # монитор
        _deco(Vector3(0.42, 0.36, 0.4), _at(p, yaw, Vector3(-0.25, 0.97, -0.12)), _fm("monitor"), yaw)
        _deco(Vector3(0.45, 0.025, 0.16), _at(p, yaw, Vector3(-0.2, 0.79, 0.2)), _fm("keyboard"), yaw)
        _deco(Vector3(0.3, 0.01, 0.22), _at(p, yaw, Vector3(0.35, 0.78, 0.05)), _fm("papers"), yaw)
        # телефон
        _deco(Vector3(0.2, 0.08, 0.16), _at(p, yaw, Vector3(0.55, 0.81, -0.15)), _fm("phone"), yaw)
    _f_chair(_at(p, yaw, Vector3(0, 0, 0.75)), yaw + PI)


## Книжный шкаф с книгами разных цветов.
func _f_bookshelf(p: Vector3, yaw: float, w := 1.2, h := 2.0) -> void:
    var wood := _fm("wood_dark")
    _collider(Vector3(w + 0.04, h, 0.4), _at(p, yaw, Vector3(0, h * 0.5, 0)), yaw)
    _solid(Vector3(w, h, 0.05), _at(p, yaw, Vector3(0, h * 0.5, -0.17)), wood, yaw)
    for sx: float in [-w * 0.5, w * 0.5]:
        _deco(Vector3(0.04, h, 0.38), _at(p, yaw, Vector3(sx, h * 0.5, 0)), wood, yaw)
    var shelves := int(h / 0.4)
    var cols := [Color(0.55, 0.10, 0.10), Color(0.12, 0.25, 0.50), Color(0.20, 0.40, 0.20), Color(0.70, 0.60, 0.40),
            Color(0.25, 0.20, 0.15), Color(0.80, 0.80, 0.75)]
    for s in shelves + 1:
        var y := 0.03 + s * (h - 0.06) / float(shelves)
        _deco(Vector3(w, 0.03, 0.38), _at(p, yaw, Vector3(0, y, 0)), wood, yaw)
        if s == shelves:
            break
        if ResourceLoader.exists("res://textures/obj_books.png"):
            _deco(Vector3(w - 0.08, 0.3, 0.24), _at(p, yaw, Vector3(0, y + 0.165, 0.0)), _books_mat(w - 0.08), yaw)
            continue
        var x := -w * 0.5 + 0.06
        while x < w * 0.5 - 0.1:
            var bw := _drng.randf_range(0.04, 0.09)
            var bh := _drng.randf_range(0.22, 0.32)
            _deco(Vector3(bw, bh, 0.24), _at(p, yaw, Vector3(x + bw * 0.5, y + 0.015 + bh * 0.5, 0.0)),
                    _book_mat(cols[_drng.randi() % cols.size()]), yaw)
            x += bw + 0.005
            if _drng.randf() < 0.08:
                x += 0.15


var _book_mats := {}


func _book_mat(c: Color) -> Material:
    var k := c.to_html()
    if not _book_mats.has(k):
        _book_mats[k] = _mat(c, 0.7)
    return _book_mats[k]


## Советская «стенка»: тумбы внизу, стекло с посудой, книги и антресоли.
func _f_stenka(p: Vector3, yaw: float, w := 3.0) -> void:
    var lac := _fm("lacquer")
    const H := 2.3
    _solid(Vector3(w, H, 0.5), _at(p, yaw, Vector3(0, H * 0.5, -0.05)), lac, yaw)
    var sec := w / 3.0
    for i in 3:
        var x := -w * 0.5 + sec * (i + 0.5)
        # ручки нижних дверок
        _deco(Vector3(0.02, 0.12, 0.02), _at(p, yaw, Vector3(x - 0.05, 0.55, 0.21)), _fm("chrome"), yaw)
        _deco(Vector3(0.02, 0.12, 0.02), _at(p, yaw, Vector3(x + 0.05, 0.55, 0.21)), _fm("chrome"), yaw)
        _deco(Vector3(sec - 0.08, 0.01, 0.01), _at(p, yaw, Vector3(x, 0.85, 0.205)), _fm("black"), yaw)
        if i == 1:
            # ниша с сервизом за стеклом
            _deco(Vector3(sec - 0.12, 0.8, 0.01), _at(p, yaw, Vector3(x, 1.35, 0.215)), _m["glass"], yaw)
            for k in 4:
                _mdeco(_cyl_mesh(0.04, 0.03, 0.09, 8), _at(p, yaw, Vector3(x - 0.27 + k * 0.18, 1.05, 0.18)), _fm("white"))
                _mdeco(_cyl_mesh(0.09, 0.09, 0.012, 12), _at(p, yaw, Vector3(x - 0.27 + k * 0.18, 1.45, 0.17)), _fm("white"))
        else:
            # полка с книгами
            if ResourceLoader.exists("res://textures/obj_books.png"):
                _deco(Vector3(sec - 0.16, 0.28, 0.05), _at(p, yaw, Vector3(x, 1.15, 0.21)), _books_mat(sec - 0.16), yaw)
                _deco(Vector3(sec - 0.08, 0.01, 0.01), _at(p, yaw, Vector3(x, 1.85, 0.205)), _fm("black"), yaw)
                continue
            var bx := x - sec * 0.5 + 0.08
            while bx < x + sec * 0.5 - 0.1:
                var bw := _drng.randf_range(0.04, 0.08)
                var bh := _drng.randf_range(0.2, 0.28)
                _deco(Vector3(bw, bh, 0.05), _at(p, yaw, Vector3(bx + bw * 0.5, 1.0 + bh * 0.5, 0.21)),
                        _book_mat([Color(0.55, 0.10, 0.10), Color(0.12, 0.25, 0.50), Color(0.70, 0.60, 0.40), Color(0.20, 0.35, 0.20)][_drng.randi() % 4]), yaw)
                bx += bw + 0.005
        _deco(Vector3(sec - 0.08, 0.01, 0.01), _at(p, yaw, Vector3(x, 1.85, 0.205)), _fm("black"), yaw)


## Диван с подлокотниками и подушками; сидят лицом в +Z.
func _f_sofa(p: Vector3, yaw: float, length := 2.2, mat: Material = null) -> void:
    var m: Material = mat if mat else _fm("upholstery")
    _solid(Vector3(length, 0.42, 0.9), _at(p, yaw, Vector3(0, 0.21, 0)), m, yaw)
    _deco(Vector3(length, 0.55, 0.22), _at(p, yaw, Vector3(0, 0.68, -0.34)), m, yaw)
    for sx: float in [-1.0, 1.0]:
        _deco(Vector3(0.18, 0.62, 0.9), _at(p, yaw, Vector3(sx * (length * 0.5 - 0.09), 0.31, 0)), m, yaw)
    var n := 2 if length < 1.8 else 3
    var cw := (length - 0.4) / n
    for i in n:
        _deco(Vector3(cw - 0.03, 0.12, 0.62), _at(p, yaw, Vector3(-length * 0.5 + 0.2 + cw * (i + 0.5), 0.48, 0.08)), m, yaw)


func _f_armchair(p: Vector3, yaw: float) -> void:
    _f_sofa(p, yaw, 0.95, _fm("armchair"))


## Батарея отопления из секций.
func _f_radiator(p: Vector3, yaw: float, length := 1.4) -> void:
    if ResourceLoader.exists("res://textures/obj_radiator.png"):
        var m := _obj_mat("obj_radiator", Vector3(0.3, 0.62, 0.09), Color(0.9, 0.9, 0.88), true)
        m.uv1_scale = Vector3(1.0 / 0.3, -1.0 / 0.62, 1.0 / 0.09)
        _deco(Vector3(length, 0.62, 0.09), _at(p, yaw, Vector3(0, 0.45, 0)), m, yaw)
        _collider(Vector3(length, 0.62, 0.12), _at(p, yaw, Vector3(0, 0.45, 0)), yaw)
        return
    var n := int(length / 0.09)
    for i in n:
        _deco(Vector3(0.06, 0.55, 0.09), _at(p, yaw, Vector3(-length * 0.5 + 0.045 + i * 0.09, 0.45, 0)), _fm("radiator"), yaw)


## Цветок в горшке.
func _f_plant(p: Vector3, big := false) -> void:
    var k := 1.4 if big else 1.0
    _collider(Vector3(0.4, 1.0, 0.4) * k, p + Vector3(0, 0.5 * k, 0))
    _mdeco(_cyl_mesh(0.2 * k, 0.15 * k, 0.4 * k, 10), p + Vector3(0, 0.2 * k, 0), _fm("pot"))
    _mdeco(_cyl_mesh(0.19 * k, 0.19 * k, 0.02, 10), p + Vector3(0, 0.4 * k, 0), _fm("soil"))
    _put("bush", p + Vector3(0, 0.75 * k, 0), _drng.randf() * TAU, Color(0.8, 1.0, 0.8), Vector3(0.45, 0.6, 0.45) * k)


## Люстра под потолком (h — высота потолка от пола).
func _f_chandelier(p: Vector3, h: float) -> void:
    _deco(Vector3(0.02, 0.5, 0.02), p + Vector3(0, h - 0.25, 0), _fm("chrome"))
    _mdeco(_cyl_mesh(0.18, 0.38, 0.3, 12), p + Vector3(0, h - 0.62, 0), _fm("lampshade"))


## Шторы по бокам окна шириной w, верх окна на высоте top.
func _f_curtains(c: Vector3, yaw: float, w: float, top: float) -> void:
    for sx: float in [-1.0, 1.0]:
        _deco(Vector3(0.5, top + 0.2, 0.06), _at(c, yaw, Vector3(sx * (w * 0.5 + 0.1), (top + 0.2) * 0.5 + 0.05, 0)), _fm("curtain"), yaw)
    _deco(Vector3(w + 1.4, 0.04, 0.04), _at(c, yaw, Vector3(0, top + 0.3, 0)), _fm("chrome"), yaw)


## Настенные часы и картина.
func _f_clock(p: Vector3, yaw: float) -> void:
    var cyl := _cyl_mesh(0.18, 0.18, 0.04, 16)
    var mi := MeshInstance3D.new()
    mi.mesh = cyl
    mi.material_override = _fm("white")
    mi.position = p
    mi.rotation = Vector3(PI * 0.5, yaw, 0)
    add_child(mi)
    _deco(Vector3(0.02, 0.13, 0.01), _at(p, yaw, Vector3(0, 0.05, 0.025)), _fm("black"), yaw)
    _deco(Vector3(0.1, 0.02, 0.01), _at(p, yaw, Vector3(0.04, 0, 0.025)), _fm("black"), yaw)


func _f_picture(p: Vector3, yaw: float, w := 1.0, h := 0.6) -> void:
    _deco(Vector3(w + 0.08, h + 0.08, 0.03), p, _fm("wood_dark"), yaw)
    var m := _fmat.get("picture_m") as StandardMaterial3D
    if m == null:
        m = _mat(Color(0.5, 0.6, 0.7), 0.6)
        var t := _tex_mip("res://textures/window_view.png")
        if t:
            m.albedo_color = Color(1.0, 0.95, 0.85)
            m.albedo_texture = t
        _fmat["picture_m"] = m
    var mi := MeshInstance3D.new()
    var qm := QuadMesh.new()
    qm.size = Vector2(w, h)
    mi.mesh = qm
    mi.material_override = m
    mi.position = _at(p, yaw, Vector3(0, 0, 0.02))
    mi.rotation.y = yaw
    add_child(mi)


## Кухня: плита с конфорками и мойка (ставятся в ряд).
func _f_stove(p: Vector3, yaw: float) -> void:
    _solid(Vector3(0.6, 0.85, 0.6), _at(p, yaw, Vector3(0, 0.425, 0)), _fm("stove"), yaw)
    _deco(Vector3(0.6, 0.02, 0.6), _at(p, yaw, Vector3(0, 0.86, 0)), _fm("black"), yaw)
    for bx: float in [-0.14, 0.14]:
        for bz: float in [-0.14, 0.14]:
            _mdeco(_cyl_mesh(0.08, 0.08, 0.02, 12), _at(p, yaw, Vector3(bx, 0.88, bz)), _fm("chrome"))
    _mdeco(_cyl_mesh(0.08, 0.1, 0.18, 10), _at(p, yaw, Vector3(0.14, 0.98, 0.14)), _fm("red"))   # чайник


## Больничная кровать: железная рама, матрас, капельница.
func _f_hospital_bed(p: Vector3, yaw: float) -> void:
    var c := _fm("white")
    _solid(Vector3(0.95, 0.12, 2.0), _at(p, yaw, Vector3(0, 0.55, 0)), _fit_mat("org/bed_sheet", Vector3(0.95, 0.12, 2.0), Color(0.95, 0.95, 0.95)), yaw)
    _deco(Vector3(0.9, 0.06, 1.95), _at(p, yaw, Vector3(0, 0.46, 0)), c, yaw)
    for lx: float in [-0.43, 0.43]:
        for lz: float in [-0.95, 0.95]:
            _deco(Vector3(0.04, 0.5, 0.04), _at(p, yaw, Vector3(lx, 0.25, lz)), c, yaw)
    _deco(Vector3(0.95, 0.5, 0.04), _at(p, yaw, Vector3(0, 0.85, -0.98)), c, yaw)
    _deco(Vector3(0.6, 0.12, 0.35), _at(p, yaw, Vector3(0, 0.66, -0.75)), _fm("paper"), yaw)   # подушка
    # капельница
    var s := _at(p, yaw, Vector3(0.65, 0, -0.7))
    _deco(Vector3(0.025, 1.8, 0.025), s + Vector3(0, 0.9, 0), _fm("chrome"))
    _deco(Vector3(0.3, 0.02, 0.02), s + Vector3(0, 1.78, 0), _fm("chrome"))
    _deco(Vector3(0.1, 0.18, 0.04), s + Vector3(0.1, 1.62, 0), _m["glass"])


## Ящики на поддоне.
func _f_crates(p: Vector3, yaw: float, n := 3) -> void:
    _deco(Vector3(1.2, 0.14, 1.0), _at(p, yaw, Vector3(0, 0.07, 0)), _fm("pallet"), yaw)
    var spots := [Vector3(-0.3, 0, -0.2), Vector3(0.3, 0, -0.2), Vector3(-0.3, 0, 0.25), Vector3(0.0, 0.6, 0.0)]
    for i in mini(n, spots.size()):
        var sp: Vector3 = spots[i]
        _solid(Vector3(0.55, 0.55, 0.45), _at(p, yaw, sp + Vector3(0, 0.42, 0)), _fm("box"), yaw + _drng.randf_range(-0.15, 0.15))


## Бочка из-под масла.
func _f_barrel(p: Vector3) -> void:
    _mdeco(_cyl_mesh(0.29, 0.29, 0.88, 14), p + Vector3(0, 0.44, 0), _fm("barrel"))
    _collider(Vector3(0.52, 0.88, 0.52), p + Vector3(0, 0.44, 0))


## Стопка покрышек.
func _f_tires(p: Vector3) -> void:
    _solid(Vector3(0.75, 1.2, 0.75), p + Vector3(0, 0.6, 0), _fm("tires"))


## Старый телевизор на тумбочке.
func _f_tv(p: Vector3, yaw: float) -> void:
    _solid(Vector3(0.8, 0.5, 0.45), _at(p, yaw, Vector3(0, 0.25, 0)), _fm("wood_dark"), yaw)
    _deco(Vector3(0.6, 0.5, 0.45), _at(p, yaw, Vector3(0, 0.75, 0)), _fm("tv"), yaw)
    _collider(Vector3(0.8, 1.0, 0.45), _at(p, yaw, Vector3(0, 0.5, 0)), yaw)
    _deco(Vector3(0.44, 0.34, 0.01), _at(p, yaw, Vector3(-0.04, 0.76, 0.226)), _fm("screen"), yaw)


## Кулер с водой.
func _f_cooler(p: Vector3, yaw: float) -> void:
    if ResourceLoader.exists("res://textures/obj_cooler.png"):
        _solid(Vector3(0.36, 1.0, 0.36), _at(p, yaw, Vector3(0, 0.5, 0)), _fm("white"), yaw)
        _deco(Vector3(0.4, 1.45, 0.02), _at(p, yaw, Vector3(0, 0.725, 0.19)), _fm("cooler"), yaw)
        return
    _solid(Vector3(0.32, 1.0, 0.32), _at(p, yaw, Vector3(0, 0.5, 0)), _fm("white"), yaw)
    var w := _mat(Color(0.55, 0.75, 0.95), 0.1)
    w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    w.albedo_color.a = 0.6
    _mdeco(_cyl_mesh(0.14, 0.14, 0.42, 12), _at(p, yaw, Vector3(0, 1.21, 0)), w)


## Картинка на предмет (как _fit_mat), с прозрачностью по альфе, если cut.
func _obj_mat(tex_name: String, size: Vector3, fallback: Color, cut := false) -> StandardMaterial3D:
    var m := _fit_mat(tex_name, size, fallback)
    if cut and m.albedo_texture != null:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.5
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


## Полка корешков: картинка повторяется по ширине (≈0.26 м на повтор).
func _books_mat(w: float) -> StandardMaterial3D:
    var key := "books|%.2f" % w
    if _fmat.has(key):
        return _fmat[key]
    var m := _fit_mat("obj_books", Vector3(w, 0.3, 0.24), Color(0.5, 0.2, 0.15))
    m.uv1_scale = Vector3(maxf(1.0, roundf(w / 0.26)) / w, -1.0 / 0.3, 1.0 / 0.24)
    _fmat[key] = m
    return m


# ================================================================ горизонт: далёкий город кольцом вокруг камеры

var _horizon: MeshInstance3D = null
var _mountains: MeshInstance3D = null
const HORIZON_REPEAT := 10.0


func _build_horizon() -> void:
    var t := _tex_mip("res://textures/horizon.png")
    if t == null:
        return
    var cyl := CylinderMesh.new()
    cyl.top_radius = 1.0
    cyl.bottom_radius = 1.0
    cyl.height = 1.0
    cyl.radial_segments = 64
    cyl.rings = 1
    cyl.cap_top = false
    cyl.cap_bottom = false
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.albedo_texture = t
    m.albedo_color = Color(0.95, 0.97, 1.0)
    m.uv1_scale = Vector3(HORIZON_REPEAT, 1.0, 1.0)
    _m["horizon"] = m
    _horizon = MeshInstance3D.new()
    _horizon.mesh = cyl
    _horizon.material_override = m
    _horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _horizon.extra_cull_margin = 16384.0
    add_child(_horizon)
    var mt := _tex_mip("res://textures/mountains.png")
    if mt:
        var mm := StandardMaterial3D.new()
        mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mm.cull_mode = BaseMaterial3D.CULL_DISABLED
        mm.albedo_texture = mt
        mm.uv1_scale = Vector3(5.0, 1.0, 1.0)
        mm.render_priority = -1
        _m["mountains"] = mm
        _mountains = MeshInstance3D.new()
        _mountains.mesh = cyl
        _mountains.material_override = mm
        _mountains.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _mountains.extra_cull_margin = 16384.0
        _mountains.visible = false
        add_child(_mountains)


## Кольцо всегда чуть ближе дальности прорисовки: ближние дома закрывают его, а дальше — «город».
func update_horizon(cam_pos: Vector3, far: float) -> void:
    if _mountains != null:   # горы Кавказа видны из Пятигорска и с моста
        _mountains.visible = cam_pos.x < RIVER_X1 + 60.0
        if _mountains.visible:
            var mr := far * 0.985
            var mh := mr * 0.22
            _mountains.scale = Vector3(mr, mh, mr)
            _mountains.position = Vector3(cam_pos.x, mh * 0.5 - 6.0, cam_pos.z)
    if _horizon == null:
        return
    var r := far * 0.96
    var h := r * 0.14
    _horizon.scale = Vector3(r, h, r)
    _horizon.position = Vector3(cam_pos.x, h * 0.5 - 4.0, cam_pos.z)



# ================================================================ подъезд (один на все дома, вход — телепорт)

## Тамбур с почтовыми ящиками, лестница на площадку с квартирами, окно, батарея,
## стены «в два цвета» — как в настоящем подъезде панельки.
func _build_podezd() -> void:
    const W := 8.0
    const D := 10.0
    const H := 4.4
    var o := Vector3(2200.0, SIDE_H, 2700.0)
    var low := _tinted("plaster", Color(0.40, 0.58, 0.50), 2.0)    # зелёная панель снизу
    var up := _tinted("plaster", Color(0.93, 0.92, 0.86), 2.0)     # побелка сверху
    var floor_mat := _tinted("ground_tiles", Color(0.78, 0.62, 0.50), 1.2)
    var conc := _tinted("concrete", Color(0.75, 0.74, 0.72), 2.0)
    _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, -0.2, 0), floor_mat)
    _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, H + 0.2, 0), up)
    _solid(Vector3(0.4, H, D), o + Vector3(-W * 0.5, H * 0.5, 0), up)
    _solid(Vector3(0.4, H, D), o + Vector3(W * 0.5, H * 0.5, 0), up)
    _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, -D * 0.5), up)
    _solid(Vector3(W, H, 0.4), o + Vector3(0, H * 0.5, D * 0.5), up)
    # нижняя панель стен (на площадке — выше, от её пола)
    for sx: float in [-1.0, 1.0]:
        _deco(Vector3(0.02, 1.5, 5.0), o + Vector3(sx * (W * 0.5 - 0.21), 0.75, 2.5), low)
        _deco(Vector3(0.02, 1.5, 4.5), o + Vector3(sx * (W * 0.5 - 0.21), 1.75, -2.75), low)
    _deco(Vector3(W - 0.4, 1.5, 0.02), o + Vector3(0, 0.75, D * 0.5 - 0.21), low)
    _deco(Vector3(W - 0.4, 1.5, 0.02), o + Vector3(0, 1.75, -D * 0.5 + 0.21), low)
    # площадка первого этажа (на 1 м выше тамбура) и лестница к ней
    const LH := 1.0
    _solid(Vector3(W, LH, 4.5), o + Vector3(0, LH * 0.5, -2.75), floor_mat)
    _deco(Vector3(W, 0.06, 0.3), o + Vector3(0, LH - 0.03, -0.5), conc)
    for i in 6:
        var hgt := (i + 1) * LH / 6.0
        _deco(Vector3(3.0, hgt, 0.34), o + Vector3(0, hgt * 0.5, 1.5 - (i + 0.5) * 0.3333), conc)
    # невидимый пандус под ступеньками — по нему персонаж поднимается
    var ang := atan2(LH, 2.0)
    var ramp := StaticBody3D.new()
    var rs := BoxShape3D.new()
    rs.size = Vector3(3.0, 0.2, sqrt(LH * LH + 4.0))
    var rcs := CollisionShape3D.new()
    rcs.shape = rs
    ramp.add_child(rcs)
    ramp.rotation.x = ang
    ramp.position = o + Vector3(0, LH * 0.5, 0.5) - Vector3(0, cos(ang), sin(ang)) * 0.1
    add_child(ramp)
    # перила: стойки, поручень и ограждение площадки
    var rail := _tinted("painted_metal", Color(0.35, 0.22, 0.15), 1.0)
    for sx: float in [-1.55, 1.55]:
        for k in 4:
            var zz := 1.4 - k * 0.6
            var base_y := clampf((1.5 - zz) / 2.0, 0.0, 1.0) * LH
            _deco(Vector3(0.04, 0.95, 0.04), o + Vector3(sx, base_y + 0.475, zz), rail)
        var hr := MeshInstance3D.new()
        hr.mesh = _box_mesh(Vector3(0.07, 0.05, sqrt(LH * LH + 4.0)))
        hr.material_override = _fm("wood_dark")
        hr.rotation.x = ang
        hr.position = o + Vector3(sx, LH * 0.5 + 0.95, 0.5)
        add_child(hr)
        _collider(Vector3(0.1, 1.0, 2.0), o + Vector3(sx, LH * 0.5 + 0.5, 0.5))
    for side: float in [-1.0, 1.0]:
        var cx := side * (W * 0.5 + 1.55) * 0.5
        var seg := W * 0.5 - 1.55
        _solid(Vector3(seg, 0.05, 0.07), o + Vector3(cx, LH + 0.95, -0.5), _fm("wood_dark"))
        _collider(Vector3(seg, 1.0, 0.1), o + Vector3(cx, LH + 0.5, -0.5))
        for k in 4:
            _deco(Vector3(0.04, 0.95, 0.04), o + Vector3(side * (1.55 + (k + 0.5) * seg / 4.0), LH + 0.475, -0.5), rail)
    # двери квартир на площадке
    var door_a := _fit_mat("door_apartment", Vector3(1.0, 2.1, 0.06), Color(0.35, 0.24, 0.15))
    var door_b := _fit_mat("door_old", Vector3(1.0, 2.1, 0.06), Color(0.35, 0.24, 0.15))
    var door_c := _fit_mat("door_steel", Vector3(1.0, 2.1, 0.06), Color(0.3, 0.32, 0.3))
    _deco(Vector3(1.0, 2.1, 0.06), o + Vector3(2.2, LH + 1.05, -D * 0.5 + 0.23), door_a)
    _deco(Vector3(1.0, 2.1, 0.06), o + Vector3(-2.2, LH + 1.05, -D * 0.5 + 0.23), door_b)
    _deco(Vector3(0.06, 2.1, 1.0), o + Vector3(-W * 0.5 + 0.23, LH + 1.05, -2.6), door_c)
    _deco(Vector3(0.06, 2.1, 1.0), o + Vector3(W * 0.5 - 0.23, LH + 1.05, -2.6), door_b)
    for nx: float in [2.2, -2.2]:
        _label("%d" % (12 if nx > 0 else 11), o + Vector3(nx, LH + 2.3, -D * 0.5 + 0.27), Vector3(0, 0, 1), 36, Color(0.9, 0.85, 0.6))
    # окно на площадке (вид во двор) и батарея под ним
    var view := _mat(Color(0.6, 0.75, 0.9), 0.5)
    view.emission_enabled = true
    view.emission = Color(0.55, 0.7, 0.9)
    view.emission_energy_multiplier = 0.6
    var vt := _tex_mip("res://textures/window_view.png")
    if vt:
        view.albedo_color = Color.WHITE
        view.albedo_texture = vt
        view.emission = Color(1, 1, 1)
        view.emission_texture = vt
        view.uv1_triplanar = true
        view.uv1_scale = Vector3(1.0 / 1.8, -1.0 / 1.1, 1.0)
        view.uv1_offset = Vector3(0.5, 0.5, 0.5)
    _deco(Vector3(1.8, 1.1, 0.05), o + Vector3(0, LH + 2.0, -D * 0.5 + 0.22), view)
    _deco(Vector3(2.0, 0.08, 0.3), o + Vector3(0, LH + 1.42, -D * 0.5 + 0.3), _m["white"])
    _f_radiator(o + Vector3(0, LH, -D * 0.5 + 0.32), 0.0, 1.4)
    # почтовые ящики в тамбуре
    var boxes := _tinted("painted_metal", Color(0.30, 0.42, 0.75), 0.6)
    _solid(Vector3(0.25, 0.9, 2.0), o + Vector3(W * 0.5 - 0.33, 1.45, 3.0), boxes)
    for r in 3:
        _deco(Vector3(0.02, 0.02, 2.0), o + Vector3(W * 0.5 - 0.45, 1.15 + r * 0.3, 3.0), _fm("black"))
    for c in 5:
        _deco(Vector3(0.02, 0.9, 0.02), o + Vector3(W * 0.5 - 0.45, 1.45, 2.2 + c * 0.4), _fm("black"))
    # объявления и надписи на стенах
    var posters := _decal_mat("posters")
    if posters:
        var pq := MeshInstance3D.new()
        var qm := QuadMesh.new()
        qm.size = Vector2(1.2, 0.9)
        pq.mesh = qm
        pq.material_override = posters
        pq.position = o + Vector3(W * 0.5 - 0.22, 1.5, 1.2)
        pq.rotation.y = -PI * 0.5
        add_child(pq)
    var graf := _decal_mat("graffiti_red")
    if graf:
        var gq := MeshInstance3D.new()
        var gm := QuadMesh.new()
        gm.size = Vector2(1.8, 1.0)
        gq.mesh = gm
        gq.material_override = graf
        gq.position = o + Vector3(-W * 0.5 + 0.22, 1.1, 2.6)
        gq.rotation.y = PI * 0.5
        add_child(gq)
    # лампочка под потолком
    for lz: float in [2.5, -2.8]:
        _deco(Vector3(0.02, 0.4, 0.02), o + Vector3(0, H - 0.2, lz), _fm("black"))
        var bulb := _mat(Color(1, 0.95, 0.8), 0.3)
        bulb.emission_enabled = true
        bulb.emission = Color(1.0, 0.85, 0.6)
        bulb.emission_energy_multiplier = 2.0
        _mdeco(_sphere_mesh(0.08, 0.16), o + Vector3(0, H - 0.45, lz), bulb)
        var ol := OmniLight3D.new()
        ol.position = o + Vector3(0, H - 0.6, lz)
        ol.omni_range = 7.0
        ol.omni_attenuation = 1.2
        ol.light_energy = 1.0
        ol.light_color = Color(1.0, 0.85, 0.6)
        ol.shadow_enabled = false
        add_child(ol)
    # дверь на улицу
    _deco(Vector3(1.4, 2.2, 0.08), o + Vector3(0, 1.1, D * 0.5 - 0.22),
            _fit_mat("door_entrance" if ResourceLoader.exists("res://textures/door_entrance.png") else "door_old", Vector3(1.4, 2.2, 0.08), Color(0.3, 0.2, 0.15)))
    _label("ВЫХОД", o + Vector3(0, 2.5, D * 0.5 - 0.25), Vector3(0, 0, -1), 44, Color(0.3, 0.9, 0.4))
    podezd = {"spawn": o + Vector3(0, 0.3, D * 0.5 - 1.6), "exit": o + Vector3(0, 0, D * 0.5 - 0.9),
            "flat": o + Vector3(2.2, LH, -D * 0.5 + 0.9)}



# ================================================================ мозаика и автоматы с газировкой

var _mosaic_mat: StandardMaterial3D = null


func _mosaic(center: Vector3, normal: Vector3, width: float) -> void:
    if _mosaic_mat == null:
        var t := _tex_mip("res://textures/mosaic_cosmos.png")
        if t == null:
            return
        _mosaic_mat = _mat(Color.WHITE, 0.6)
        _mosaic_mat.albedo_texture = t
        _m["mosaic"] = _mosaic_mat   # ночью темнеет вместе с домами
    var q := QuadMesh.new()
    q.size = Vector2(width, width / 1.5)
    var mi := MeshInstance3D.new()
    mi.mesh = q
    mi.material_override = _mosaic_mat
    mi.position = center
    mi.rotation.y = atan2(normal.x, normal.z)
    mi.visibility_range_end = 400.0
    add_child(mi)
    # рамка из бетона вокруг панно
    var frame := _tinted("concrete", Color(0.8, 0.8, 0.78), 2.0)
    var b := Basis(Vector3.UP, atan2(normal.x, normal.z))
    var hh := width / 1.5
    for sy: float in [-1.0, 1.0]:
        _deco(Vector3(width + 0.5, 0.25, 0.12), center + Vector3(0, sy * (hh * 0.5 + 0.12), 0) - normal * 0.02, frame, mi.rotation.y)
    for sx: float in [-1.0, 1.0]:
        _deco(Vector3(0.25, hh + 0.5, 0.12), center + b * Vector3(sx * (width * 0.5 + 0.12), 0, 0) - normal * 0.02, frame, mi.rotation.y)


var soda_spots: Array[Vector3] = []   # автоматы с газировкой (точка, где стоять)
var _soda_mat: StandardMaterial3D = null


func _soda(p: Vector3, facing: Vector3) -> void:
    if _soda_mat == null:
        _soda_mat = _fit_mat("obj_soda", Vector3(0.8, 1.6, 0.6), Color(0.8, 0.1, 0.08))
        _soda_mat.roughness = 0.45
    var yaw := atan2(facing.x, facing.z)
    var base := Vector3(p.x, SIDE_H, p.z)
    _solid(Vector3(0.8, 1.6, 0.6), base + Vector3(0, 0.8, 0), _soda_mat, yaw)
    soda_spots.append(base + facing * 1.0)



# ================================================================ село Бусаево (к югу от города)

const VILLAGE_X := 43.0          # главная улица продолжает городскую дорогу x = 43
const VILLAGE_Z0 := 222.0 + OUT  # от края города
const VILLAGE_CROSS := 440.0 + OUT   # поперечная улица
var village_center := Vector3(VILLAGE_X, 0, VILLAGE_CROSS)
var village_park := Vector3.ZERO


func _build_village() -> void:
    var x := VILLAGE_X
    var road: Material = _m["asphalt"]
    var dirt: Material = _m["gravel"] if _m.has("gravel") else road
    # дорога с моста (асфальт), дальше по селу — грунтовка
    var vz0 := VILLAGE_BRIDGE.y + BRIDGE_RAMP
    _flat(Vector3(x, 0, (vz0 + 330.0 + OUT) * 0.5), Vector2(10.0, 330.0 + OUT - vz0), road, 0.006)
    _map_rect(Vector3(x, 0, (vz0 + 330.0 + OUT) * 0.5), Vector2(10.0, 330.0 + OUT - vz0))
    _flat(Vector3(x, 0, 455.0 + OUT), Vector2(8.0, 250.0), dirt, 0.007)
    _map_rect(Vector3(x, 0, 455.0 + OUT), Vector2(8.0, 250.0))
    _flat(Vector3(45.0, 0, VILLAGE_CROSS), Vector2(270.0, 8.0), dirt, 0.008)
    _map_rect(Vector3(45.0, 0, VILLAGE_CROSS), Vector2(270.0, 8.0))
    # въездной знак
    var sign_p := Vector3(x + 7.0, 0, 334.0 + OUT)
    _solid(Vector3(0.12, 2.6, 0.12), sign_p + Vector3(-1.4, 1.3, 0), _m["metal"])
    _solid(Vector3(0.12, 2.6, 0.12), sign_p + Vector3(1.4, 1.3, 0), _m["metal"])
    _deco(Vector3(3.4, 1.0, 0.08), sign_p + Vector3(0, 2.6, 0), _m["blue"])
    _label("БУСАЕВО", sign_p + Vector3(0, 2.6, -0.06), Vector3(0, 0, -1), 96, Color(1, 1, 1))
    _label("БУСАЕВО", sign_p + Vector3(0, 2.6, 0.06), Vector3(0, 0, 1), 96, Color(1, 1, 1))
    # фонари вдоль дороги и улиц
    for z: float in [250.0, 290.0, 330.0, 370.0, 410.0, 470.0, 510.0, 550.0]:
        var lp := Vector3(x - 6.0, 0, z + OUT)
        if on_land(lp) and absf(lp.z - (VILLAGE_BRIDGE.x + VILLAGE_BRIDGE.y) * 0.5) > 40.0:
            _lamp(lp, Vector3(1, 0, 0))
    for lx: float in [-60.0, -20.0, 100.0, 140.0]:
        _lamp(Vector3(lx, 0, VILLAGE_CROSS + 5.0), Vector3(0, 0, -1))
    # дома: вдоль главной улицы и поперечной
    var walls := [Color(0.70, 0.52, 0.38), Color(0.62, 0.72, 0.82), Color(0.82, 0.76, 0.58), Color(0.66, 0.78, 0.62),
            Color(0.85, 0.80, 0.72)]
    var roofs := [Color(0.25, 0.32, 0.25), Color(0.55, 0.18, 0.12), Color(0.30, 0.30, 0.34)]
    var spots := []
    for z: float in [355.0, 395.0, 485.0, 525.0, 565.0]:
        spots.append([Vector3(x - 17.0, 0, z + OUT), Vector3(1, 0, 0)])
    for z: float in [485.0, 525.0, 565.0]:
        spots.append([Vector3(x + 17.0, 0, z + OUT), Vector3(-1, 0, 0)])
    for hx: float in [-75.0, -40.0, 125.0, 160.0]:
        spots.append([Vector3(hx, 0, VILLAGE_CROSS - 17.0), Vector3(0, 0, 1)])
        spots.append([Vector3(hx, 0, VILLAGE_CROSS + 17.0), Vector3(0, 0, -1)])
    for k in spots.size():
        var hc: Vector3 = spots[k][0]
        var hf: Vector3 = spots[k][1]
        _cottage(hc, hf, walls[k % walls.size()], roofs[k % roofs.size()], 40000 + (k % 4) * 10000, k % 3 != 2)
    _village_park(Vector3(x + 33.0, 0, 380.0 + OUT))
    # трёхэтажные панельные дома на въезде в село (совхозные), подъездами к дороге
    for hp: Array in [[Vector3(x + 17.5, 0, 322.0 + OUT), -PI * 0.5], [Vector3(x - 17.5, 0, 320.0 + OUT), PI * 0.5]]:
        _village_flat_house(hp[0], float(hp[1]))
    # сельпо и колодец на перекрёстке
    _kiosk(Vector3(x + 13.0, 0, VILLAGE_CROSS - 12.0), Vector3(-1, 0, 0), "СЕЛЬПО", Color(0.55, 0.40, 0.25))
    _well(Vector3(x - 11.0, 0, VILLAGE_CROSS + 11.0))
    _bus_stop(Vector3(x + 7.5, SIDE_H, 342.0 + OUT), Vector3(-1, 0, 0))
    # пожарная часть села: свой квартал к западу от главной улицы, подъезд — грунтовка от улицы
    var fz := 545.0 + OUT
    _flat(Vector3((x - 4.0 - 44.0) * 0.5, 0, fz), Vector2(x - 4.0 + 44.0, 8.0), dirt, 0.008)
    _c = Vector3(-80.0, 0, fz)
    _solid(Vector3(BLOCK, SIDE_H, BLOCK), _c + Vector3(0, SIDE_H * 0.5, 0), _m["sidewalk"])
    _flat(_c, Vector2(BLOCK - WALK * 2.0, BLOCK - WALK * 2.0), _m["grass"], SIDE_H + 0.004)
    _mx = 1.0
    _mz = 1.0
    _tpl_faction("fire", Vector2(1, 0))


## Трёхэтажка (models/houses/house3f): 17×19 м, крыльца с двух сторон. Нет модели — ничего не ставим.
func _village_flat_house(c: Vector3, yaw: float) -> void:
    if not _props_ok.has("house3f"):
        return
    _put("hs_house3f", c, yaw)
    var turned := absf(sin(yaw)) > 0.5
    var size := Vector3(12.1, 10.0, 17.4) if turned else Vector3(17.4, 10.0, 12.1)
    _collider(size, c + Vector3(0, 5.0, 0))
    _occupy(c, size.x + 7.0, size.z + 7.0)
    building_rects.append(Rect2(c.x - size.x * 0.5, c.z - size.z * 0.5, size.x, size.z))


## Колодец-журавль попроще: сруб и крыша.
func _well(p: Vector3) -> void:
    var logs: Material = _tinted("log_wall", Color(1, 1, 1), 1.5) if _tex_mip("res://textures/log_wall.png") != null else _m["wood"]
    _solid(Vector3(1.4, 0.9, 1.4), p + Vector3(0, 0.45, 0), logs)
    for sx: float in [-0.6, 0.6]:
        _deco(Vector3(0.12, 1.6, 0.12), p + Vector3(sx, 1.7, 0), _m["wood"])
    var roof := _tinted("roof_slate", Color(0.9, 0.9, 0.9), 1.5)
    for side: float in [-1.0, 1.0]:
        var slab := _deco(Vector3(1.8, 0.08, 1.0), p + Vector3(0, 2.6, 0.4 * side), roof)
        slab.rotate_object_local(Vector3.RIGHT, 0.6 * side)
    _occupy(p, 3.0, 3.0)


## Парк: газон, дорожки крест-накрест, обелиск со звездой, клумбы, лавочки, берёзы, фонари.
func _village_park(c: Vector3) -> void:
    village_park = c
    const PW := 46.0
    const PD := 60.0
    _flat(c, Vector2(PW, PD), _m["grass"], 0.012)
    _flat(c, Vector2(3.0, PD), _m["path"], 0.016)
    _flat(c, Vector2(PW, 3.0), _m["path"], 0.017)
    _flat(c, Vector2(12.0, 12.0), _m["paving"], 0.018)
    # обелиск с красной звездой
    _solid(Vector3(2.4, 0.6, 2.4), c + Vector3(0, 0.3, 0), _m["granite"])
    _solid(Vector3(1.0, 6.0, 1.0), c + Vector3(0, 3.6, 0), _tinted("concrete", Color(0.92, 0.92, 0.9), 2.0))
    var star := _mat(Color(0.85, 0.08, 0.06), 0.4)
    star.emission_enabled = true
    star.emission = Color(0.6, 0.05, 0.03)
    star.emission_energy_multiplier = 0.8
    for k in 5:
        var arm := MeshInstance3D.new()
        arm.mesh = _box_mesh(Vector3(0.22, 0.75, 0.12))
        arm.material_override = star
        arm.position = c + Vector3(0, 7.15, 0) + Vector3(sin(k * TAU / 5.0), cos(k * TAU / 5.0), 0) * 0.3
        arm.rotation.z = -k * TAU / 5.0
        add_child(arm)
    # клумбы вокруг обелиска
    for k in 4:
        var a := k * TAU / 4.0 + PI * 0.25
        var fb := c + Vector3(cos(a), 0, sin(a)) * 4.2
        _deco(Vector3(2.2, 0.3, 2.2), fb + Vector3(0, 0.15, 0), _m["granite"])
        _deco(Vector3(1.9, 0.32, 1.9), fb + Vector3(0, 0.16, 0), _m["flowers"])
    # лавочки вдоль дорожек
    for z: float in [-20.0, -10.0, 10.0, 20.0]:
        _bench(c + Vector3(3.0, 0, z), Vector3(-1, 0, 0))
        _bench(c + Vector3(-3.0, 0, z), Vector3(1, 0, 0))
    for lx: float in [-14.0, 14.0]:
        _lamp(c + Vector3(lx, 0, 2.5), Vector3(0, 0, -1))
    _lamp(c + Vector3(2.5, 0, -24.0), Vector3(-1, 0, 0))
    _lamp(c + Vector3(-2.5, 0, 24.0), Vector3(1, 0, 0))
    _occupy(c, 12.0, 12.0)
    # берёзы и ели по краям
    for k in 26:
        var tp := c + Vector3(rng.randf_range(-PW * 0.5 + 2.0, PW * 0.5 - 2.0), 0, rng.randf_range(-PD * 0.5 + 2.0, PD * 0.5 - 2.0))
        if absf(tp.x - c.x) < 4.0 or absf(tp.z - c.z) < 4.0:
            continue
        if _is_free(tp, 3.0):
            _tree(tp)
    _playground(c + Vector3(13.0, 0, -17.0))
    _label("ПАРК ИМЕНИ ГАГАРИНА", c + Vector3(0, 3.0, PD * 0.5), Vector3(0, 0, 1), 60, Color(1.0, 0.85, 0.3))



# ================================================================ река, мост и Пятигорск

const BRIDGE_Z := 43.0       # мост продолжает улицу z = 43 обоих городов
var py_center := PY_ORG
var bridge_center := Vector3((RIVER_X0 + RIVER_X1) * 0.5, 1.2, BRIDGE_Z)
var village_bridge := Vector3(43.0, 1.2, 450.0)
var cottages_center := Vector3(262.0 + OUT, 0, 0)


func _build_sea_and_bridges() -> void:
    _build_sea()
    for isl: Rect2 in [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]:
        _coast(isl)
    # Мост Дружбы: Казань — Пятигорск (длинный, над морем)
    var kazan_edge := -((GRID + 0.5) * PITCH + ROAD * 0.5)
    var py_edge := PY_ORG.x + (PY_GRID + 0.5) * PITCH + ROAD * 0.5
    _bridge(Vector3(RIVER_X1, 0, BRIDGE_Z), Vector3(RIVER_X0, 0, BRIDGE_Z), "МОСТ ДРУЖБЫ")
    _land_road(Vector3(kazan_edge, 0, BRIDGE_Z), Vector3(RIVER_X1 + BRIDGE_RAMP, 0, BRIDGE_Z))
    _land_road(Vector3(RIVER_X0 - BRIDGE_RAMP, 0, BRIDGE_Z), Vector3(py_edge, 0, BRIDGE_Z))
    for lx: float in [kazan_edge - 30.0, kazan_edge - 70.0, py_edge + 25.0]:
        _lamp(Vector3(lx, 0, BRIDGE_Z + 8.5), Vector3(0, 0, -1))
    _city_sign(Vector3(kazan_edge - 12.0, 0, BRIDGE_Z + 10.0), "КАЗАНЬ", Vector3(-1, 0, 0))
    _city_sign(Vector3(py_edge + 12.0, 0, BRIDGE_Z - 10.0), "ПЯТИГОРСК", Vector3(1, 0, 0))
    # мост в Бусаево (короткий, на юг по улице x = 43)
    var south_edge := (GRID + 0.5) * PITCH + ROAD * 0.5
    _bridge(Vector3(VILLAGE_X, 0, VILLAGE_BRIDGE.x), Vector3(VILLAGE_X, 0, VILLAGE_BRIDGE.y), "МОСТ В БУСАЕВО", 10.0)
    _land_road(Vector3(VILLAGE_X, 0, south_edge), Vector3(VILLAGE_X, 0, VILLAGE_BRIDGE.x - BRIDGE_RAMP), 10.0)


## Суша ли в точке (на каком-нибудь острове).
static func on_land(p: Vector3) -> bool:
    for isl: Rect2 in [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]:
        if isl.has_point(Vector2(p.x, p.z)):
            return true
    return false


## Море: вода везде, кроме островов. Мир делится по краям островов на клетки, вода — в клетках без суши.
func _build_sea() -> void:
    var water := ShaderMaterial.new()
    water.shader = load("res://shaders/water.gdshader")
    water.set_shader_parameter("deep", Color(0.07, 0.20, 0.30))
    water.set_shader_parameter("shallow", Color(0.16, 0.34, 0.44))
    const W := 3000.0
    var xs := [-W - 300.0, W - 300.0]
    var zs := [-W, W]
    var isles := [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]
    for isl: Rect2 in isles:
        xs.append_array([isl.position.x, isl.end.x])
        zs.append_array([isl.position.y, isl.end.y])
    xs.sort()
    zs.sort()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_normal(Vector3.UP)
    for a in xs.size() - 1:
        for b in zs.size() - 1:
            var x0: float = xs[a]
            var x1: float = xs[a + 1]
            var z0: float = zs[b]
            var z1: float = zs[b + 1]
            if x1 - x0 < 0.5 or z1 - z0 < 0.5:
                continue
            var mid := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
            var land := false
            for isl: Rect2 in isles:
                if isl.has_point(mid):
                    land = true
            if land:
                continue
            for v: Vector3 in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1),
                    Vector3(x0, 0, z0), Vector3(x1, 0, z1), Vector3(x0, 0, z1)]:
                st.add_vertex(v)
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    mi.material_override = water
    mi.position.y = 0.05
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


## Набережная по краю острова: песок, гранитный парапет с решёткой (в море не упасть). Проёмы — под мосты.
func _coast(isl: Rect2) -> void:
    var par := _tinted("granite_red", Color(0.92, 0.92, 0.92), 2.6)
    var gaps: Array[Vector2] = [Vector2(RIVER_X1, BRIDGE_Z), Vector2(RIVER_X0, BRIDGE_Z),
            Vector2(VILLAGE_X, VILLAGE_BRIDGE.x), Vector2(VILLAGE_X, VILLAGE_BRIDGE.y)]
    var corners := [isl.position, Vector2(isl.end.x, isl.position.y), isl.end, Vector2(isl.position.x, isl.end.y)]
    for k in 4:
        var a: Vector2 = corners[k]
        var b: Vector2 = corners[(k + 1) % 4]
        var along := (b - a).normalized()
        var inward := Vector2(-along.y, along.x)
        if not isl.has_point(a.lerp(b, 0.5) + inward * 2.0):
            inward = -inward
        # отрезки между проёмами
        var cuts: Array[float] = []
        for g: Vector2 in gaps:
            var t := (g - a).dot(along)
            if t > 0.0 and t < a.distance_to(b) and absf((g - a).dot(inward)) < 1.0:
                cuts.append(t)
        cuts.sort()
        var segs := []
        var t0 := 0.0
        for t: float in cuts:
            segs.append([t0, t - 9.0])
            t0 = t + 9.0
        segs.append([t0, a.distance_to(b)])
        var n3 := Vector3(inward.x, 0, inward.y)
        var yaw := atan2(along.x, along.y) + PI * 0.5
        for sg: Array in segs:
            var s0: float = sg[0]
            var s1: float = sg[1]
            if s1 - s0 < 1.0:
                continue
            var mid2 := a + along * (s0 + s1) * 0.5
            var mid := Vector3(mid2.x, 0, mid2.y)
            var L := s1 - s0
            _solid(Vector3(L, 0.8, 0.6), mid + Vector3(0, 0.4, 0) + n3 * 0.3, par, yaw)
            _collider(Vector3(L, 2.0, 0.6), mid + Vector3(0, 1.0, 0) + n3 * 0.3, yaw)
            _deco(Vector3(L, 0.08, 0.75), mid + Vector3(0, 0.84, 0) + n3 * 0.3, _m["granite"], yaw)
            _iron_rail(mid + Vector3(0, 0.88, 0) + n3 * 0.3, L, 0.9, n3)
        # набережная: плитка вдоль парапета
        var full := Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5) + n3 * 5.6
        var sz := Vector2(a.distance_to(b), 10.0) if absf(along.x) > 0.5 else Vector2(10.0, a.distance_to(b))
        _flat(full, sz, _m["paving"], 0.008)


## Набережные: фонари и лавочки вдоль парапета (лицом к морю), полоса деревьев за ними.
func _shore_life() -> void:
    var gaps: Array[Vector2] = [Vector2(RIVER_X1, BRIDGE_Z), Vector2(RIVER_X0, BRIDGE_Z),
            Vector2(VILLAGE_X, VILLAGE_BRIDGE.x), Vector2(VILLAGE_X, VILLAGE_BRIDGE.y)]
    for isl: Rect2 in [ISLAND_KAZAN, ISLAND_PYAT, ISLAND_VILLAGE]:
        var corners := [isl.position, Vector2(isl.end.x, isl.position.y), isl.end, Vector2(isl.position.x, isl.end.y)]
        for k in 4:
            var a: Vector2 = corners[k]
            var b: Vector2 = corners[(k + 1) % 4]
            var L := a.distance_to(b)
            var along := (b - a).normalized()
            var inward := Vector2(-along.y, along.x)
            if not isl.has_point(a.lerp(b, 0.5) + inward * 2.0):
                inward = -inward
            var n3 := Vector3(inward.x, 0, inward.y)
            var t := 25.0
            while t < L - 25.0:
                var q := a + along * t
                var near_gap := false
                for g: Vector2 in gaps:
                    if g.distance_to(q) < 32.0:
                        near_gap = true
                var p := Vector3(q.x, 0, q.y)
                if not near_gap:
                    if int(t / 25.0) % 2 == 0:
                        if _is_free(p + n3 * 3.0, 1.0):
                            _lamp(p + n3 * 3.0, -n3)
                    elif _is_free(p + n3 * 2.4, 1.0):
                        _bench(p + n3 * 2.4 + Vector3(0, SIDE_H, 0), -n3)
                    for row: float in [17.0, 26.0]:
                        var tp := p + n3 * (row + rng.randf_range(-2.0, 2.0)) + Vector3(along.x, 0, along.y) * rng.randf_range(-5.0, 5.0)
                        if rng.randf() < 0.65 and _is_free(tp, 3.0) and on_land(tp):
                            _tree(tp)
                t += 25.0


const BRIDGE_RAMP := 20.0
const BRIDGE_DECK := 1.2


## Мост от берега a до берега b (по прямой вдоль X или Z): настил на высоте 1.2 м, пандусы на суше,
## перила, гранитные столбики, опоры в воде, фонари, название.
func _bridge(a: Vector3, b: Vector3, title: String, width := 14.0) -> void:
    var d := (b - a).normalized()
    var n := Vector3(-d.z, 0, d.x)
    var L := a.distance_to(b)
    var mid := (a + b) * 0.5
    var yaw := atan2(-d.z, d.x)          # локальная X детали — вдоль моста
    _map_strip(a - d * BRIDGE_RAMP, b + d * BRIDGE_RAMP, width)
    var road: Material = _m["asphalt"]
    var par := _tinted("granite_red", Color(0.92, 0.92, 0.92), 2.6)
    var conc := _tinted("concrete", Color(0.78, 0.77, 0.74), 2.0)
    _solid(Vector3(L, 0.3, width), mid + Vector3(0, BRIDGE_DECK - 0.15, 0), road, yaw)
    _deco(Vector3(L, 0.6, width + 0.4), mid + Vector3(0, BRIDGE_DECK - 0.6, 0), par, yaw)
    var ang := atan2(BRIDGE_DECK, BRIDGE_RAMP)
    var rlen := sqrt(BRIDGE_RAMP * BRIDGE_RAMP + BRIDGE_DECK * BRIDGE_DECK)
    for side: float in [-1.0, 1.0]:      # -1 — со стороны a, 1 — со стороны b
        var edge := a if side < 0.0 else b
        var rc := edge + d * side * BRIDGE_RAMP * 0.5
        var ramp := StaticBody3D.new()
        var rs := BoxShape3D.new()
        rs.size = Vector3(rlen, 0.3, width)
        var cs := CollisionShape3D.new()
        cs.shape = rs
        ramp.add_child(cs)
        var mi := MeshInstance3D.new()
        mi.mesh = _box_mesh(rs.size)
        mi.material_override = road
        ramp.add_child(mi)
        ramp.rotation = Vector3(0, yaw, -ang * side)
        ramp.position = rc + Vector3(0, BRIDGE_DECK * 0.5 - 0.15, 0)
        add_child(ramp)
    var hw := width * 0.5 + 0.1
    for sgn: float in [-1.0, 1.0]:
        var rp := mid + n * hw * sgn
        _collider(Vector3(L, 1.1, 0.2), rp + Vector3(0, BRIDGE_DECK + 0.55, 0), yaw)
        _iron_rail(rp + Vector3(0, BRIDGE_DECK, 0), L, 1.0, n)
        _deco(Vector3(L, 0.08, 0.22), rp + Vector3(0, BRIDGE_DECK + 1.02, 0), _m["granite"], yaw)
        var k := 6.0
        while k < L:
            _deco(Vector3(0.45, 1.25, 0.45), a + d * k + n * hw * sgn + Vector3(0, BRIDGE_DECK + 0.62, 0), par)
            k += 6.0
    var pk := 20.0
    while pk < L - 10.0:   # опоры
        _deco(Vector3(3.0, BRIDGE_DECK + 2.0, width - 4.0), a + d * pk + Vector3(0, BRIDGE_DECK * 0.5 - 1.3, 0), conc, yaw)
        pk += 40.0
    var lk := 10.0
    while lk < L:
        _lamp(a + d * lk - n * (hw + 0.2) + Vector3(0, BRIDGE_DECK, 0), n)
        lk += 60.0
    var t := 4.0
    while t < L - 2.0:
        _put("dash", a + d * t + Vector3(0, BRIDGE_DECK + 0.012, 0), yaw + PI * 0.5)
        t += 5.0
    _label(title, mid + n * (hw + 0.05) + Vector3(0, BRIDGE_DECK + 1.4, 0), n, 64, Color(1.0, 0.85, 0.3))


func _map_rect(center: Vector3, sz: Vector2) -> void:
    map_roads.append(Rect2(center.x - sz.x * 0.5, center.z - sz.y * 0.5, sz.x, sz.y))


## Полоса дороги на мини-карте от a до b (вдоль X или Z).
func _map_strip(a: Vector3, b: Vector3, width: float) -> void:
    var x0 := minf(a.x, b.x)
    var z0 := minf(a.z, b.z)
    var along_x := absf(b.x - a.x) > absf(b.z - a.z)
    if along_x:
        map_roads.append(Rect2(x0, a.z - width * 0.5, absf(b.x - a.x), width))
    else:
        map_roads.append(Rect2(a.x - width * 0.5, z0, width, absf(b.z - a.z)))


## Дорога по суше от a до b (по прямой вдоль X или Z) с пунктиром.
func _land_road(a: Vector3, b: Vector3, width := ROAD) -> void:
    var d := b - a
    var L := d.length()
    if L < 1.0:
        return
    var along_x := absf(d.x) > absf(d.z)
    _flat((a + b) * 0.5, Vector2(L, width) if along_x else Vector2(width, L), _m["asphalt"], 0.005)
    _map_strip(a, b, width)
    var t := 2.0
    while t < L - 2.0:
        _put("dash", a + d.normalized() * t + Vector3(0, 0.012, 0), PI * 0.5 if along_x else 0.0)
        t += 5.0


## Чугунная решётка со звёздами: плоскость с вырезом по альфе, повторяется по длине.
## base — середина низа, normal — куда «смотрит» решётка (поперёк её длины).
func _iron_rail(base: Vector3, length: float, height: float, normal: Vector3) -> void:
    var t := _tex_mip("res://textures/railing_stars.png")
    if t == null:
        return
    if not _m.has("iron_rail"):
        var m := StandardMaterial3D.new()
        m.albedo_texture = t
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        m.alpha_scissor_threshold = 0.5
        m.cull_mode = BaseMaterial3D.CULL_DISABLED
        m.metallic = 0.6
        m.roughness = 0.45
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        _m["iron_rail"] = m
    var tile_w := height * float(t.get_width()) / float(t.get_height())
    var q := QuadMesh.new()
    q.size = Vector2(length, height)
    var mat: StandardMaterial3D = (_m["iron_rail"] as StandardMaterial3D).duplicate()
    mat.uv1_scale = Vector3(length / tile_w, 1.0, 1.0)
    var mi := MeshInstance3D.new()
    mi.mesh = q
    mi.material_override = mat
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = base + Vector3(0, height * 0.5, 0)
    mi.rotation.y = atan2(normal.x, normal.z)
    add_child(mi)


func _city_sign(p: Vector3, text: String, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    for sx: float in [-2.2, 2.2]:
        _solid(Vector3(0.15, 3.2, 0.15), p + b * Vector3(sx, 0, 0) + Vector3(0, 1.6, 0), _m["metal"], yaw)
    _deco(Vector3(5.2, 1.3, 0.1), p + Vector3(0, 3.2, 0), _m["blue"], yaw)
    _label(text, p + Vector3(0, 3.2, 0) + facing * 0.07, facing, 110, Color(1, 1, 1))
    _label(text, p + Vector3(0, 3.2, 0) - facing * 0.07, -facing, 110, Color(1, 1, 1))


## Центр Пятигорска: стела со звездой, клумбы, ларьки, банкомат, остановка.
func _tpl_square_py() -> void:
    py_center = _c
    var mon := _p(0, 0)
    _solid(Vector3(5.0, 1.0, 5.0), mon + Vector3(0, 0.5, 0), _m["granite"])
    _solid(Vector3(1.2, 12.0, 1.2), mon + Vector3(0, 7.0, 0), _tinted("concrete", Color(0.92, 0.9, 0.86), 2.0))
    var star := _mat(Color(0.85, 0.08, 0.06), 0.4)
    star.emission_enabled = true
    star.emission = Color(0.6, 0.05, 0.03)
    star.emission_energy_multiplier = 0.8
    for k in 5:
        var arm := MeshInstance3D.new()
        arm.mesh = _box_mesh(Vector3(0.3, 1.0, 0.15))
        arm.material_override = star
        arm.position = mon + Vector3(0, 13.6, 0) + Vector3(sin(k * TAU / 5.0), cos(k * TAU / 5.0), 0) * 0.4
        arm.rotation.z = -k * TAU / 5.0
        add_child(arm)
    _occupy(mon, 8.0, 8.0)
    for x: float in [-14.0, 14.0]:
        for z: float in [-14.0, 14.0]:
            var bed := _p(x, z)
            _solid(Vector3(4.0, 0.4, 4.0), bed + Vector3(0, 0.2, 0), _m["granite"])
            _deco(Vector3(3.6, 0.42, 3.6), bed + Vector3(0, 0.21, 0), _m["flowers"])
            _occupy(bed, 5.0, 5.0)
    for x: float in [-5.0, 5.0]:
        _bench(_p(x, -7.0), Vector3(0, 0, 1))
        _bench(_p(x, 7.0), Vector3(0, 0, -1))
    _kiosk(_p(-27, -27), Vector3(0, 0, 1), "ЧЕБУРЕКИ", Color(0.80, 0.45, 0.15))
    _kiosk(_p(27, -27), Vector3(0, 0, 1), "ПРОДУКТЫ", Color(0.20, 0.50, 0.75))
    _kiosk(_p(-27, 27), Vector3(0, 0, -1), "КВАС", Color(0.75, 0.45, 0.10))
    _atm(_p(27, 22), Vector3(-1, 0, 0))
    _market(_p(0, 22))
    _bus_stop(_p(0, 31), Vector3(0, 0, 1))
    _label("ПЯТИГОРСК", mon + Vector3(0, 2.0, 2.6), Vector3(0, 0, 1), 120, Color(1.0, 0.85, 0.3))


# ================================================================ вокзал и автошкола (север Казани)

const STATION_C := Vector3(200, 0, -345 + NORTH)   # середина здания вокзала
const SCHOOL_C := Vector3(45, 0, -322 + NORTH)     # здание автошколы
var station_spawn := Vector3(200, 0.4, -320)   # здесь игрок появляется после входа в игру
var peter_pos := Vector3(200, 0, -331)         # Петер, помощник новичков
var exam_route: Array[Vector3] = []            # маршрут экзамена от автошколы
var rail_stops := {}          # id -> {name, board, arrive, track_z, platform_x} — станции электрички
var galya_pos := Vector3.ZERO # тётя Галя в кассе вокзала
var kassa_point := Vector3.ZERO
var taxi_driver_pos := Vector3.ZERO
var gena_pos := Vector3.ZERO      # Геннадий, прокат мопедов у вокзала
var scooter_point := Vector3.ZERO
var scooter_slots: Array = []     # [позиция, yaw] — где стоят мопеды проката
var taxi_point := Vector3.ZERO
var passengers: Array = []    # [позиция, куда смотрит, "stand"/"sit"]
var exam_spawn := Transform3D()


## Вокзал «КАЗАНЬ» в духе сталинского ампира: центральный зал с колоннадой и часовой башней со
## шпилем и звездой, два крыла, площадь с клумбами и лавочками, перрон под навесом, пути и поезд.
## Вокзал (Казань и Пятигорск): здание с часовой башней, площадь, перрон под навесом, пути.
## Касса с тётей Галей, такси, прокат и пассажиры — только в Казани (main = true).
func _build_station(c: Vector3, id: String, title: String, rail_x0: float, rail_x1: float) -> void:
    var main := id == "kazan"
    var front := Vector3(0, 0, 1)
    var fz := c.z + 8.0                       # фасад центрального зала
    var wall: Material = _stalin_mats[0] if not _stalin_mats.is_empty() else _m["plaster"]
    var wing: Material = _stalin_mats[1] if _stalin_mats.size() > 1 else wall
    var white: Material = _m["white"]
    var cream := _mat(Color(0.93, 0.88, 0.74), 0.8)
    var roof := _mat(Color(0.32, 0.42, 0.38), 0.6)     # зелёная медь
    var gold := _mat(Color(0.95, 0.75, 0.25), 0.35)
    gold.metallic = 0.7
    # площадь
    _flat(Vector3(c.x, 0, c.z + 22.5), Vector2(96, 29), _m["paving"], 0.02)
    _flat(Vector3(c.x, 0, c.z - 1.0), Vector2(110, 22), _m["paving"], 0.018)
    # центральный зал
    _solid(Vector3(32, 14, 16), c + Vector3(0, 7, 0), wall)
    _deco(Vector3(33, 0.8, 17), c + Vector3(0, 14.4, 0), cream)          # карниз
    _deco(Vector3(31, 1.2, 15), c + Vector3(0, 15.4, 0), roof)
    _deco(Vector3(32.4, 1.0, 16.4), c + Vector3(0, 0.5, 0), _m["granite"])  # цоколь
    # колоннада: 8 белых колонн, антаблемент и фронтон
    for k in 8:
        var x := c.x - 10.5 + k * 3.0
        var cp := Vector3(x, 0, fz + 3.2)
        _solid(Vector3(1.1, 10.0, 1.1), cp + Vector3(0, 5.0, 0), white)
        _deco(Vector3(1.6, 0.5, 1.6), cp + Vector3(0, 0.25, 0), cream)
        _deco(Vector3(1.6, 0.5, 1.6), cp + Vector3(0, 9.75, 0), cream)
    _deco(Vector3(26, 1.6, 4.6), Vector3(c.x, 10.8, fz + 2.6), cream)       # антаблемент
    _deco(Vector3(26, 0.5, 5.0), Vector3(c.x, 11.85, fz + 2.6), white)
    _deco(Vector3(24, 0.4, 4.6), Vector3(c.x, 0.2, fz + 2.6), _m["granite"])  # ступени
    _deco(Vector3(25, 0.2, 5.4), Vector3(c.x, 0.05, fz + 2.9), _m["granite"])
    # фронтон-треугольник из трёх ступеней и герб
    for t in 3:
        _deco(Vector3(18.0 - t * 6.0, 1.0, 1.0), Vector3(c.x, 12.6 + t, fz + 4.4), cream)
    _emblem_disc(Vector3(c.x, 13.2, fz + 5.0), front)
    # двери и окна первого этажа за колоннами
    for k in 3:
        _deco(Vector3(2.4, 4.2, 0.12), Vector3(c.x - 6.0 + k * 6.0, 2.3, fz + 0.06), _m["vitrine"])
    _label("ВОКЗАЛ", Vector3(c.x, 10.8, fz + 4.95), front, 360, Color(0.95, 0.78, 0.25))
    # часовая башня со шпилем и звездой
    _solid(Vector3(8, 9, 8), Vector3(c.x, 20.5, c.z + 2.0), wall)
    _deco(Vector3(9, 0.8, 9), Vector3(c.x, 25.4, c.z + 2.0), cream)
    _deco(Vector3(6.4, 4.0, 6.4), Vector3(c.x, 27.8, c.z + 2.0), white)
    var spire := CylinderMesh.new()
    spire.top_radius = 0.05
    spire.bottom_radius = 2.6
    spire.height = 9.0
    spire.radial_segments = 8
    var smi := MeshInstance3D.new()
    smi.mesh = spire
    smi.material_override = roof
    smi.position = Vector3(c.x, 34.3, c.z + 2.0)
    add_child(smi)
    _star(Vector3(c.x, 39.4, c.z + 2.0), front, 1.3, _m["red"])
    for side: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
        _clock(Vector3(c.x, 21.5, c.z + 2.0) + side * 4.05, side)
    _label(title, Vector3(c.x, 18.0, c.z + 6.06), front, 200 if title.length() <= 7 else 150, Color(0.95, 0.95, 0.9))
    # крылья
    for sx: float in [-1.0, 1.0]:
        var wc := c + Vector3(sx * 27.0, 0, 1.0)
        _solid(Vector3(22, 10, 14), wc + Vector3(0, 5, 0), wing)
        _deco(Vector3(22.6, 0.6, 14.6), wc + Vector3(0, 10.3, 0), cream)
        _deco(Vector3(21.5, 0.9, 13.5), wc + Vector3(0, 11.0, 0), roof)
        _deco(Vector3(22.4, 0.9, 14.4), wc + Vector3(0, 0.45, 0), _m["granite"])
        for k in 4:   # пилястры
            _deco(Vector3(0.8, 9.6, 0.3), wc + Vector3(-8.25 + k * 5.5, 4.8, 7.12), white)
        _deco(Vector3(2.2, 3.2, 0.12), wc + Vector3(0, 1.7, 7.06), _m["vitrine"])
    _label(sx_text(-1.0), Vector3(c.x - 27.0, 8.6, c.z + 8.12), front, 110, Color(0.25, 0.22, 0.2))
    _label(sx_text(1.0), Vector3(c.x + 27.0, 8.6, c.z + 8.12), front, 110, Color(0.25, 0.22, 0.2))
    building_rects.append(Rect2(c.x - 38.0, c.z - 8.0, 76.0, 16.0))
    _occupy(c, 80.0, 24.0)
    # площадь: клумбы, лавочки, фонари, флаги
    for sx: float in [-1.0, 1.0]:
        var bed := Vector3(c.x + sx * 18.0, 0, c.z + 24)
        _deco(Vector3(10.0, 0.45, 5.0), bed + Vector3(0, 0.22, 0), _m["granite"])
        _deco(Vector3(9.4, 0.5, 4.4), bed + Vector3(0, 0.25, 0), _m["flowers"])
        _bench(bed + Vector3(0, SIDE_H, 3.6), Vector3(0, 0, 1))
        _bench(bed + Vector3(sx * -6.6, SIDE_H, 0), Vector3(-sx, 0, 0))
        for lz: float in [c.z + 18, c.z + 32]:
            _lamp(Vector3(c.x + sx * 30.0, 0, lz), Vector3(-sx, 0, 0))
    _city_sign(Vector3(c.x + 44.0, 0, c.z + 34), "ВОКЗАЛ", Vector3(0, 0, 1))
    if main:
        station_spawn = Vector3(c.x, 0.4, c.z + 32)
        peter_pos = Vector3(c.x + 2.5, 0.02, c.z + 18)
    # перрон под навесом
    var pz := c.z - 13.0
    _solid(Vector3(150, 0.9, 6), Vector3(c.x, 0.45, pz), _m["granite"])
    _deco(Vector3(150, 0.05, 0.4), Vector3(c.x, 0.92, pz - 2.7), _m["yellow"])   # линия у края
    for k in 13:
        var px := c.x - 60.0 + k * 10.0
        _solid(Vector3(0.3, 4.0, 0.3), Vector3(px, 2.9, pz + 1.5), _m["metal"])
    _deco(Vector3(126, 0.25, 5.0), Vector3(c.x, 5.0, pz), roof)
    building_rects.append(Rect2(c.x - 75.0, pz - 3.0, 150.0, 6.0))
    # пути: шпалы и рельсы, далеко в обе стороны
    var rail := _mat(Color(0.45, 0.43, 0.4), 0.4)
    rail.metallic = 0.8
    var sleeper := _mat(Color(0.28, 0.22, 0.17), 0.9)
    _batch("sleeper", _box_mesh(Vector3(0.25, 0.1, 2.6)), sleeper, 160.0)
    for tz: float in [pz - 6.0, pz - 11.0]:
        _flat(Vector3((rail_x0 + rail_x1) * 0.5, 0, tz), Vector2(rail_x1 - rail_x0, 3.4), _m["gravel"], 0.02)
        for rx: float in [-0.76, 0.76]:
            _deco(Vector3(rail_x1 - rail_x0, 0.15, 0.1), Vector3((rail_x0 + rail_x1) * 0.5, 0.2, tz + rx), rail)
        var sx0 := rail_x0
        while sx0 < rail_x1:
            _put("sleeper", Vector3(sx0, 0.07, tz))
            sx0 += 1.6
    # электричка ходит по расписанию (scripts/train.gd, создаёт main.gd)
    rail_stops[id] = {"name": title.capitalize(), "board": Vector3(c.x, 0.9, pz - 1.6), "arrive": Vector3(c.x + 6.0, 1.0, pz),
            "track_z": pz - 6.0, "platform_x": c.x}
    if main:
        _station_life(c)
    else:
        # билетный автомат на перроне (кассы нет)
        var ap := Vector3(c.x - 5.0, 0.9, pz + 1.2)
        _solid(Vector3(0.8, 1.7, 0.5), ap + Vector3(0, 0.85, 0), _m["red"])
        _deco(Vector3(0.6, 0.4, 0.05), ap + Vector3(0, 1.3, 0.27), _m["vitrine"])


func sx_text(sx: float) -> String:
    return "КАССЫ" if sx < 0.0 else "ЗАЛ ОЖИДАНИЯ"


func _clock(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var face := CylinderMesh.new()
    face.top_radius = 1.8
    face.bottom_radius = 1.8
    face.height = 0.12
    face.radial_segments = 24
    var mi := MeshInstance3D.new()
    mi.mesh = face
    mi.material_override = _m["white"]
    mi.position = p
    mi.rotation = Vector3(PI * 0.5, yaw, 0)
    add_child(mi)
    var b := Basis(Vector3.UP, yaw)
    _deco(Vector3(0.14, 1.2, 0.06), p + b * Vector3(0, 0.5, 0.1), _m["metal"], yaw)            # минутная
    _deco(Vector3(0.8, 0.16, 0.06), p + b * Vector3(0.32, 0, 0.1), _m["metal"], yaw)            # часовая


func _star(p: Vector3, facing: Vector3, r: float, mat: Material) -> void:
    for k in 5:   # пять лучей
        var a := k * TAU / 5.0
        var arm := MeshInstance3D.new()
        var bm := PrismMesh.new()
        bm.size = Vector3(r * 0.55, r, 0.25)
        arm.mesh = bm
        arm.material_override = mat
        arm.position = p + Basis(Vector3.UP, atan2(facing.x, facing.z)) * Vector3(sin(a) * r * 0.5, cos(a) * r * 0.5, 0)
        arm.rotation = Vector3(0, atan2(facing.x, facing.z), -a)
        add_child(arm)


func _emblem_disc(p: Vector3, facing: Vector3) -> void:
    var d := CylinderMesh.new()
    d.top_radius = 1.4
    d.bottom_radius = 1.4
    d.height = 0.15
    d.radial_segments = 20
    var mi := MeshInstance3D.new()
    mi.mesh = d
    mi.material_override = _m["red"]
    mi.position = p
    mi.rotation = Vector3(PI * 0.5, atan2(facing.x, facing.z), 0)
    add_child(mi)
    _star(p + facing * 0.12, facing, 1.0, _mat(Color(0.95, 0.78, 0.25), 0.4))


## Автошкола ДОСААФ: двухэтажное здание с вывеской и учебные машины, рядом автодром с конусами.
func _build_driving_school() -> void:
    var c := SCHOOL_C
    var front := Vector3(0, 0, 1)
    var wall := _mat(Color(0.86, 0.80, 0.68), 0.85)
    if not _stalin_mats.is_empty():
        wall = _stalin_mats[2 % _stalin_mats.size()]
    _flat(Vector3(c.x, 0, c.z + 8.0), Vector2(30, 8), _m["paving"], 0.02)
    _solid(Vector3(24, 7.6, 11), c + Vector3(0, 3.8, 0), wall)
    _deco(Vector3(24.6, 0.6, 11.6), c + Vector3(0, 7.9, 0), _m["white"])
    _deco(Vector3(24.4, 0.8, 11.4), c + Vector3(0, 0.4, 0), _m["granite"])
    _deco(Vector3(23.6, 0.5, 10.6), c + Vector3(0, 8.4, 0), _m["roof"])
    # вход с козырьком и колоннами
    var fz := c.z + 5.5
    _deco(Vector3(2.6, 3.0, 0.12), Vector3(c.x, 1.55, fz + 0.06), _m["vitrine"])
    _deco(Vector3(6.0, 0.3, 3.0), Vector3(c.x, 3.4, fz + 1.5), _m["white"])
    for sx: float in [-2.6, 2.6]:
        _solid(Vector3(0.4, 3.3, 0.4), Vector3(c.x + sx, 1.65, fz + 2.8), _m["white"])
    # большая вывеска на крыше и табличка
    var sign_c := Vector3(c.x, 9.8, fz - 0.5)
    _deco(Vector3(16, 2.0, 0.2), sign_c, _m["sign"])
    _label("АВТОШКОЛА", sign_c + front * 0.12, front, 260, Color(0.85, 0.12, 0.08))
    _label("ДОСААФ · ПРАВА КАТЕГОРИЙ A, B, C", Vector3(c.x, 6.2, fz + 0.08), front, 70, Color(0.15, 0.2, 0.35))
    # дорожные знаки у входа
    for sx: float in [-9.0, 9.0]:
        _deco(Vector3(2.2, 1.5, 0.1), Vector3(c.x + sx, 2.6, fz + 0.1), _m["white"])
        _label("П" if sx < 0 else "У", Vector3(c.x + sx, 2.6, fz + 0.17), front, 160, Color(0.85, 0.12, 0.08))
    building_rects.append(Rect2(c.x - 12.0, c.z - 5.5, 24.0, 11.0))
    _occupy(c, 26.0, 14.0)
    driving_school = Vector3(c.x, 0, fz + 2.2)
    # учебные машины у входа (без случайных чисел — планировка города не меняется)
    for k in 2:
        var body := StaticBody3D.new()
        body.position = Vector3(c.x - 10.0 + k * 20.0, SIDE_H, fz + 5.0)
        body.rotation.y = 0.0 if k == 0 else PI
        add_child(body)
        CarModel.add_collision(body)
        _put("car%d" % (k + 1), body.position, body.rotation.y)
    # автодром: асфальт, разметка, конусы «змейкой»
    var ac := Vector3(58, 0, -346 + NORTH)
    _flat(ac, Vector2(56, 22), _m["yard_asphalt"], 0.015)
    for k in 7:
        _deco(Vector3(0.35, 0.6, 0.35), ac + Vector3(-18.0 + k * 6.0, 0.3, (1.5 if k % 2 == 0 else -1.5)), _m["red"])
    for sx: float in [-27.5, 27.5]:
        _deco(Vector3(0.25, 0.05, 22), ac + Vector3(sx, 0.03, 0), _m["white"])
    _deco(Vector3(56, 0.05, 0.25), ac + Vector3(0, 0.03, -10.9), _m["white"])
    _deco(Vector3(56, 0.05, 0.25), ac + Vector3(0, 0.03, 10.9), _m["white"])
    # экзамен: старт на автодроме, змейка, выезд на внешнее кольцо Казани и обратно
    exam_spawn = Transform3D(Basis(Vector3.UP, PI * 0.5), ac + Vector3(-24.0, 0.7, 4.5))
    exam_route = [ac + Vector3(-12, 0, 4.5), ac + Vector3(20, 0, 4.5), Vector3(95, 0, -320 + NORTH),
            Vector3(43, 0, -301 + NORTH), Vector3(43, 0, -240 + NORTH), Vector3(-43, 0, -215 + NORTH), Vector3(-43, 0, -290 + NORTH),
            Vector3(10, 0, -301 + NORTH), ac + Vector3(-10, 0, 0)]


## Касса с тётей Галей, буфет, такси и пассажиры с чемоданами на площади вокзала.
func _station_life(c: Vector3) -> void:
    # касса: стеклянная будка у крыла «КАССЫ»
    var bp := Vector3(c.x - 28.0, 0, c.z + 15)
    var booth := _mat(Color(0.32, 0.45, 0.55), 0.5)
    _solid(Vector3(3.0, 2.8, 0.12), bp + Vector3(0, 1.4, -1.3), booth)
    for sx: float in [-1.5, 1.5]:
        _solid(Vector3(0.12, 2.8, 2.6), bp + Vector3(sx, 1.4, 0), booth)
    _deco(Vector3(3.3, 0.18, 2.9), bp + Vector3(0, 2.9, 0), _m["roof"])
    _solid(Vector3(3.0, 1.0, 0.12), bp + Vector3(0, 0.5, 1.3), booth)          # стойка
    _deco(Vector3(3.0, 0.06, 0.4), bp + Vector3(0, 1.03, 1.35), _m["white"])
    var win := StandardMaterial3D.new()
    win.albedo_color = Color(0.75, 0.88, 0.95, 0.22)
    win.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    win.roughness = 0.05
    win.metallic = 0.3
    _deco(Vector3(2.9, 1.5, 0.04), bp + Vector3(0, 1.85, 1.3), win)      # окошко
    _deco(Vector3(0.1, 1.5, 0.06), bp + Vector3(0, 1.85, 1.31), booth)   # переплёт
    _deco(Vector3(3.0, 0.5, 0.08), bp + Vector3(0, 3.25, 1.3), _m["sign"])
    _label("КАССА", bp + Vector3(0, 3.25, 1.36), Vector3(0, 0, 1), 80, Color(0.85, 0.12, 0.08))
    _deco(Vector3(0.45, 0.72, 0.45), bp + Vector3(0, 0.36, -0.55), _m["wood"])   # высокий табурет кассира
    galya_pos = bp + Vector3(0, 0.27, -0.25)
    kassa_point = bp + Vector3(0, 0, 2.6)
    building_rects.append(Rect2(bp.x - 1.5, bp.z - 1.3, 3.0, 2.6))
    # буфет: пирожки, беляши, чай
    _kiosk(Vector3(c.x + 28.0, 0, c.z + 15), Vector3(0, 0, 1), "БУФЕТ", Color(0.75, 0.35, 0.15))
    # такси: две жёлтые «Волги» и таксист
    for k in 2:
        var tp := Vector3(c.x + 56.0, SIDE_H, c.z + 19 + k * 7.0)
        var body := StaticBody3D.new()
        body.position = tp
        body.rotation.y = PI
        add_child(body)
        CarModel.add_collision(body)
        var mesh := CarModel.parked_mesh(Color(0.95, 0.78, 0.15), "volga")
        if mesh == null:
            mesh = CarModel.parked_mesh(Color(0.95, 0.78, 0.15), "vaz2106")
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        body.add_child(mi)
        var chk := MeshInstance3D.new()
        var cb := BoxMesh.new()
        cb.size = Vector3(0.7, 0.22, 0.3)
        chk.mesh = cb
        chk.material_override = _m["yellow"]
        chk.position = Vector3(0, 1.55, 0)
        body.add_child(chk)
        var tl := Label3D.new()
        tl.text = "ТАКСИ"
        tl.font_size = 40
        tl.pixel_size = 0.005
        tl.modulate = Color(0.1, 0.1, 0.1)
        tl.outline_size = 0
        tl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
        tl.position = Vector3(0, 1.56, 0)
        body.add_child(tl)
    taxi_driver_pos = Vector3(c.x + 52.0, SIDE_H, c.z + 22.5)
    taxi_point = taxi_driver_pos + Vector3(-1.5, 0, 0)
    _city_sign(Vector3(c.x + 56.0, 0, c.z + 13.5), "ТАКСИ", Vector3(0, 0, 1))
    _scooter_rent(Vector3(c.x - 41.0, 0.02, c.z + 20))
    # пассажиры: на перроне с чемоданами и на лавочках
    var pz := c.z - 13.0
    for px: float in [-42.0, -21.0, -6.0, 14.0, 33.0, 47.0]:
        passengers.append([Vector3(c.x + px, 0.9, pz - 0.5 + absf(px) * 0.02), Vector3(0, 0, -1), "stand"])
    passengers.append([Vector3(c.x - 18.0, SIDE_H, c.z + 27.6 + 0.29), Vector3(0, 0, 1), "sit"])
    passengers.append([Vector3(c.x + 18.0, SIDE_H, c.z + 27.6 + 0.29), Vector3(0, 0, 1), "sit"])
    passengers.append([Vector3(c.x - 6.0, SIDE_H, c.z + 21), Vector3(0.6, 0, 0.8), "stand"])


## Прокат мопедов «Вятка»: полосатый навес, вывеска, ценник, мопеды в ряд. Продавец — Геннадий.
func _scooter_rent(rp: Vector3) -> void:
    var red := _mat(Color(0.78, 0.12, 0.10), 0.6)
    var white := _mat(Color(0.95, 0.94, 0.90), 0.6)
    var post: Material = _m["metal"]
    # навес 8×3.4 м на четырёх столбах, полосы красные и белые
    for sx: float in [-3.9, 3.9]:
        for sz: float in [-1.6, 1.6]:
            _solid(Vector3(0.1, 2.7, 0.1), rp + Vector3(sx, 1.35, sz), post)
    for i in 8:
        _deco(Vector3(1.0, 0.08, 3.6), rp + Vector3(-3.5 + i * 1.0, 2.74 + (i % 2) * 0.01, 0), red if i % 2 == 0 else white)
    for i in 8:   # фестоны по переднему краю
        _deco(Vector3(1.0, 0.28, 0.03), rp + Vector3(-3.5 + i * 1.0, 2.58, 1.82), white if i % 2 == 0 else red)
    # вывеска над навесом
    _deco(Vector3(6.4, 0.7, 0.1), rp + Vector3(0, 3.2, 1.6), _m["sign"])
    _label("ПРОКАТ МОПЕДОВ «ВЯТКА»", rp + Vector3(0, 3.2, 1.66), Vector3(0, 0, 1), 64, Color(0.85, 0.12, 0.08))
    # стойка с ценником сбоку
    var bp := rp + Vector3(4.6, 0, 0.6)
    _solid(Vector3(0.9, 1.0, 0.6), bp + Vector3(0, 0.5, 0), _m["wood"])
    _deco(Vector3(1.0, 0.05, 0.7), bp + Vector3(0, 1.02, 0), white)
    _deco(Vector3(0.06, 1.0, 0.06), bp + Vector3(0.38, 1.5, -0.2), post)
    _deco(Vector3(0.9, 0.6, 0.04), bp + Vector3(0, 1.75, -0.2), white)
    _label("20 минут — 150 ₽\nНовичкам —\nбесплатно!", bp + Vector3(0, 1.75, -0.17), Vector3(0, 0, 1), 34, Color(0.1, 0.1, 0.12))
    building_rects.append(Rect2(bp.x - 0.45, bp.z - 0.3, 0.9, 0.6))
    gena_pos = bp + Vector3(0, 0, -0.9)
    scooter_point = bp + Vector3(0, 0, 1.4)
    scooter_slots.clear()
    for i in 4:
        scooter_slots.append([rp + Vector3(-2.7 + i * 1.8, 0.0, -0.2), 0.0])


