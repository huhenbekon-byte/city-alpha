extends Node3D
## Генератор района в духе российского спального микрорайона:
## панельные девятиэтажки, хрущёвки, башни, дворы с детскими площадками,
## гаражи, ларьки, остановка, фонари, берёзы, припаркованные машины.
## Всё строится из примитивов. Мелочи (балконы, деревья, фонари, машины)
## рисуются через MultiMesh — один draw call на вид объекта.

const CarModel := preload("res://scripts/car_model.gd")
const FactionData := preload("res://scripts/faction_data.gd")
## Кварталы со зданиями фракций (вокруг площади). ОПГ — позже.
const FACTION_BLOCKS := {Vector2i(0, -1): "mayor", Vector2i(1, 0): "police", Vector2i(-1, 0): "hospital",
        Vector2i(0, 1): "fire", Vector2i(-1, -1): "kgb"}
## Районы ОПГ на окраинах: база — гараж.
const GANG_BLOCKS := {Vector2i(-2, 2): "tyap", Vector2i(2, -2): "universam", Vector2i(-2, -2): "solnce",
        Vector2i(2, 0): "kavkaz"}

const BLOCK := 72.0      # размер квартала, м
const ROAD := 14.0       # ширина дороги, м
const PITCH := BLOCK + ROAD
const GRID := 2          # кварталы от -GRID до GRID (5x5)
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
var _mx := 1.0           # зеркалирование шаблона квартала
var _mz := 1.0

var _panel_mats: Array[StandardMaterial3D] = []
var _brick_mats: Array[StandardMaterial3D] = []
var _tower_mats: Array[StandardMaterial3D] = []   # высотки-«свечки» (если есть текстура)
var _m := {}

# --- данные для мини-карты и работ (читают main.gd, minimap.gd, job_courier.gd)
var extent := (GRID + 0.5) * PITCH + ROAD * 0.5   # половина размера города
var block_rects: Array[Rect2] = []
var building_rects: Array[Rect2] = []
var pickups: Array[Dictionary] = []   # {"pos": Vector3, "name": String} — ларьки, магазины
var dropoffs: Array[Vector3] = []     # точки у подъездов
var lamp_mat: StandardMaterial3D      # фонари: ярче ночью
var lamp_positions: Array[Vector3] = []  # где висят плафоны (для света ночью)
var road_lines: Array[float] = []     # координаты осей дорог (для трафика)
var market := Vector3.ZERO            # вход в Общий рынок (машины, одежда, прочее)
var city_hall := Vector3.ZERO         # мэрия (паспорт)
var driving_school := Vector3.ZERO    # автошкола
var atms: Array[Vector3] = []         # банкоматы (где стоять)
var fuel_pumps: Array[Vector3] = []   # колонки АЗС (где встать машиной)
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
const STREETS := ["ул. Ленина", "ул. Гагарина", "ул. Мира", "ул. Советская", "ул. Пушкина",
        "пр. Победы", "ул. Строителей", "ул. Садовая", "ул. Космонавтов"]
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
    _build_outskirts()
    _build_interiors()
    _build_cottages()
    _build_home_interiors()
    _flush_batches()


# ================================================================ кварталы

func _build_block(i: int, j: int) -> void:
    _c = Vector3(i * PITCH, 0.0, j * PITCH)
    var is_center := i == 0 and j == 0
    _mx = 1.0 if is_center or rng.randf() < 0.5 else -1.0
    _mz = 1.0 if is_center or rng.randf() < 0.5 else -1.0

    _solid(Vector3(BLOCK, SIDE_H, BLOCK), _c + Vector3(0, SIDE_H * 0.5, 0), _m["sidewalk"])
    block_rects.append(Rect2(_c.x - BLOCK * 0.5, _c.z - BLOCK * 0.5, BLOCK, BLOCK))
    var inner := BLOCK - WALK * 2.0
    _flat(_c, Vector2(inner, inner), _m["paving"] if is_center else _m["grass"], SIDE_H + 0.004)

    var fkey := Vector2i(i, j)
    if is_center:
        _tpl_square()
    elif FACTION_BLOCKS.has(fkey):
        _mx = 1.0
        _mz = 1.0
        _tpl_faction(FACTION_BLOCKS[fkey], Vector2(-i, -j))
    elif GANG_BLOCKS.has(fkey):
        _mx = 1.0
        _mz = 1.0
        _tpl_gang(GANG_BLOCKS[fkey], Vector2(-i, -j))
    elif i == GRID and j == GRID:
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
            _deco(Vector3(4.0, 0.4, 4.0), bed + Vector3(0, 0.2, 0), _m["granite"])
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

    _kiosk(_p(-27, -27), Vector3(0, 0, 1), "ШАУРМА", Color(0.85, 0.55, 0.15))
    _kiosk(_p(27, -27), Vector3(0, 0, 1), "ПРОДУКТЫ", Color(0.20, 0.50, 0.75))
    _kiosk(_p(-27, 10), Vector3(1, 0, 0), "ЦВЕТЫ", Color(0.30, 0.60, 0.30))
    _kiosk(_p(27, 10), Vector3(-1, 0, 0), "ПЕЧАТЬ", Color(0.70, 0.20, 0.20))
    _kiosk(_p(-27, -9), Vector3(1, 0, 0), "КОФЕ", Color(0.45, 0.30, 0.20))
    _market(_p(0, 29))
    _kiosk(_p(27, -9), Vector3(-1, 0, 0), "КВАС", Color(0.75, 0.45, 0.10))
    _kiosk(_p(-27, 22), Vector3(1, 0, 0), "АВТОШКОЛА", Color(0.90, 0.50, 0.10), false)
    driving_school = _p(-27, 22) + Vector3(2.8, 0, 0)
    _atm(_p(-7, -29), Vector3(0, 0, 1))
    _atm(_p(7, -29), Vector3(0, 0, 1))
    _bus_stop(_p(21, 31), Vector3(0, 0, 1))
    bus_depot = _p(21, 29)
    bus_spawn = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(14, 0.9, 46.5))
    bus_stops.append(Vector3(21, 0, 39.5))

    _occupy(_p(0, 20), 40.0, 6.0)   # стоянка у рынка: сюда доставляют купленные машины
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

    _solid(Vector3(sx, h, sz), base + Vector3(0, h * 0.5, 0), mat)
    _deco(Vector3(sx + 0.2, 0.7, sz + 0.2), base + Vector3(0, 0.35, 0), _m["plinth"])
    _deco(Vector3(sx + 0.3, 0.45, sz + 0.3), base + Vector3(0, h + 0.2, 0), _m["roof"])
    _occupy(base, sx, sz)
    building_rects.append(Rect2(base.x - sx * 0.5, base.z - sz * 0.5, sx, sz))

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
                _balcony(pos, n, rng.randf())

    # Подъезды: двери, козырьки, лавочки, машинные отделения лифтов на крыше
    if entrance == Vector3.ZERO:
        return
    var e_x := absf(entrance.z) > 0.5
    var flen := sx if e_x else sz
    var e_out := (sz if e_x else sx) * 0.5
    var axis := Vector3(1, 0, 0) if e_x else Vector3(0, 0, 1)
    var yaw := 0.0 if e_x else PI * 0.5
    var count := maxi(1, int(flen / 14.0))
    # водосточные трубы по углам фасада
    for side: float in [-1.0, 1.0]:
        _put("drainpipe", base + axis * (side * (flen * 0.5 - 0.35)) + entrance * (e_out + 0.12) + Vector3(0, h * 0.5, 0),
                0.0, Color.WHITE, Vector3(1.0, h, 1.0))
    for e: int in range(count):
        var u := -flen * 0.5 + flen * (e + 0.5) / count
        var p := base + axis * u + entrance * e_out
        _put("door", p + Vector3(0, 1.1, 0) + entrance * 0.06, yaw)
        dropoffs.append(p + entrance * 2.5 + Vector3(0, SIDE_H, 0))
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
    _deco(Vector3(4.2, 0.12, 1.9), p + b * Vector3(0, 2.6, 0.1), _m["blue"], yaw)
    _solid(Vector3(4.0, 2.4, 0.06), p + b * Vector3(0, 1.3, -0.75), _m["glass"], yaw)
    for sx: float in [-2.0, 2.0]:
        _deco(Vector3(0.06, 2.4, 1.4), p + b * Vector3(sx, 1.3, -0.1), _m["glass"], yaw)
    _bench(p + b * Vector3(0, 0, -0.4), facing)
    _deco(Vector3(0.08, 2.8, 0.08), p + b * Vector3(2.7, 1.4, 0.8), _m["metal"], yaw)
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
    _deco(Vector3(1.6, 1.4, 1.6), c + Vector3(-3.6, 0.7, 2.2), _m["playhouse"])
    _deco(Vector3(1.9, 0.15, 1.9), c + Vector3(-3.6, 1.48, 2.2), _m["red"])
    # песочница
    _deco(Vector3(3.0, 0.25, 3.0), c + Vector3(-3, 0.125, -2), _m["sandbox"])
    _deco(Vector3(2.7, 0.26, 2.7), c + Vector3(-3, 0.13, -2), _m["sand"])
    # качели
    var s := c + Vector3(2.5, 0, -2)
    for dx: float in [-1.2, 1.2]:
        _deco(Vector3(0.1, 2.4, 0.1), s + Vector3(dx, 1.2, 0), _m["blue"])
    _deco(Vector3(2.6, 0.1, 0.1), s + Vector3(0, 2.4, 0), _m["blue"])
    _deco(Vector3(0.6, 0.05, 0.35), s + Vector3(0, 0.5, 0), _m["wood"])
    for dx: float in [-0.25, 0.25]:
        _deco(Vector3(0.02, 1.85, 0.02), s + Vector3(dx, 1.43, 0), _m["pipe"])
    # горка
    var g := c + Vector3(1.5, 0, 2.0)
    _deco(Vector3(1.2, 0.1, 1.2), g + Vector3(0, 1.5, 0), _m["red"])
    for px: float in [-0.55, 0.55]:
        for pz: float in [-0.55, 0.55]:
            _deco(Vector3(0.08, 1.5, 0.08), g + Vector3(px, 0.75, pz), _m["pipe"])
    var slide := _deco(Vector3(0.7, 0.06, 2.63), g + Vector3(0, 0.78, 1.7), _m["slide"])
    slide.rotation.x = 0.583
    _deco(Vector3(0.6, 1.6, 0.06), g + Vector3(0, 0.8, -0.65), _m["yellow"])
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


func _bench(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    var base := Vector3(p.x, SIDE_H, p.z)
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


## Ель: ствол и конус хвои (для леса за городом).
func _pine(p: Vector3) -> void:
    var s := rng.randf_range(0.8, 1.3)
    var base := Vector3(p.x, 0.0, p.z)
    _put("pine_trunk", base + Vector3(0, 1.5 * s, 0), 0.0, Color.WHITE, Vector3(s, s, s))
    _put("pine_crown", base + Vector3(0, 5.2 * s, 0), rng.randf() * TAU,
            Color(1, 1, 1).lerp(Color(0.8, 0.9, 0.8), rng.randf()), Vector3(s, s, s))
    _occupy(base, 1.5, 1.5)


func _tree(p: Vector3) -> void:
    var s := rng.randf_range(0.85, 1.2)
    var sc := Vector3(s, s, s)
    var base := Vector3(p.x, SIDE_H, p.z)
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


# ================================================================ земля и дороги

func _build_ground() -> void:
    var body := StaticBody3D.new()
    add_child(body)
    var shape := BoxShape3D.new()
    shape.size = Vector3(1200, 2, 1200)
    var col := CollisionShape3D.new()
    col.shape = shape
    col.position.y = -1.0
    body.add_child(col)
    _flat(Vector3.ZERO, Vector2(1200, 1200), _m["wasteland"], 0.0)
    var roads := ((GRID + 0.5) * PITCH + ROAD * 0.5) * 2.0
    _flat(Vector3.ZERO, Vector2(roads, roads), _m["asphalt"], 0.004)


## Пунктир по центру дорог и зебры у каждого перекрёстка.
func _build_road_marks() -> void:
    var extent := (GRID + 0.5) * PITCH
    var lines: Array[float] = []
    for k: int in range(-GRID - 1, GRID + 1):
        lines.append((k + 0.5) * PITCH)

    road_lines = lines
    for r: float in lines:
        var t := -extent
        while t <= extent:
            if _dist_to_lines(t, lines) > ROAD * 0.5 + 5.0:
                _put("dash", Vector3(r, 0.012, t))
                _put("dash", Vector3(t, 0.012, r), PI * 0.5)
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
                    _put("zebra", cpos + across * (s * 1.15), yaw)


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
    _m["glass"] = glass


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
    if _night_base.is_empty():
        var mats: Array = _panel_mats + _brick_mats + _tower_mats
        for m in _m.values():
            mats.append(m)
        for m in _tinted_cache.values():
            mats.append(m)
        for m in mats:
            if m is StandardMaterial3D and not _night_base.has(m) and m != lamp_mat:
                _night_base[m] = m.albedo_color
    var dim := lerpf(1.0, 0.5, k)
    for m: StandardMaterial3D in _night_base:
        var c: Color = _night_base[m]
        m.albedo_color = Color(c.r * dim, c.g * dim, c.b * dim, c.a)


## Виды мелких объектов: меш, материал, дальность видимости (м), тень.
## Мелочь пропадает вдали и не отбрасывает тени — это сильно ускоряет телефон.
func _define_batches() -> void:
    # Балконы: бетонная плита + ограждение (решётка, профлист или вагонка; цвет — у каждого свой)
    _batch("bal_slab", _box_mesh(Vector3(2.6, 0.14, 1.05)), _tinted("balcony_slab", Color(0.85, 0.85, 0.85), 1.5), 220.0)
    _batch("bal_rail", _box_mesh(Vector3(2.5, 0.86, 0.95)), _fit_mat("balcony_rail", Vector3(2.5, 0.86, 0.95), Color(0.62, 0.62, 0.62)), 200.0)
    _batch("bal_sheet", _box_mesh(Vector3(2.5, 0.86, 0.95)), _tiled_vc_mat("corrugated", 1.2, Color(0.65, 0.68, 0.70)), 200.0)
    _batch("bal_boards", _box_mesh(Vector3(2.5, 0.86, 0.95)), _tiled_vc_mat("balcony_boards", 1.5, Color(0.74, 0.73, 0.70)), 200.0)
    _batch("door", _box_mesh(Vector3(1.4, 2.2, 0.12)), _fit_mat("door_old", Vector3(1.4, 2.2, 0.12), Color(0.32, 0.22, 0.15)), 90.0)
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
    _batch("pole", _cyl_mesh(0.07, 0.09, 7.0, 6), _m["metal"], 150.0)
    _batch("lamp_arm", _box_mesh(Vector3(0.08, 0.08, 1.6)), _m["metal"], 150.0)
    var lamp := _mat(Color(1.0, 0.96, 0.85), 0.3)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.92, 0.75)
    lamp.emission_energy_multiplier = 0.8
    lamp_mat = lamp
    _batch("lamp_head", _box_mesh(Vector3(0.3, 0.12, 0.55)), lamp, 150.0)
    _batch("trunk", _cyl_mesh(0.12, 0.18, 2.6, 6), _nature("bark_tree", Color(0.36, 0.25, 0.17), 1.0, false), 180.0)
    _batch("birch", _cyl_mesh(0.09, 0.13, 5.5, 6), _nature("bark_birch", Color(0.92, 0.90, 0.86), 1.0, false), 180.0)
    _batch("crown", _sphere_mesh(2.0, 3.4), _nature("foliage_tree", Color.WHITE, 2.5, true), 200.0, true)
    _batch("birch_crown", _sphere_mesh(1.3, 4.0), _nature("foliage_birch", Color.WHITE, 2.0, true), 200.0, true)
    _batch("bush", _sphere_mesh(0.7, 1.0), _nature("foliage_bush", Color.WHITE, 1.2, true), 80.0)
    _batch("pine_trunk", _cyl_mesh(0.14, 0.2, 3.0, 6), _nature("bark_tree", Color(0.36, 0.25, 0.17), 1.0, false), 200.0)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.05
    cone.bottom_radius = 2.0
    cone.height = 6.5
    cone.radial_segments = 8
    cone.rings = 1
    _batch("pine_crown", cone, _nature("foliage_pine", Color.WHITE, 2.0, true), 220.0, true)
    _batch("bench_seat", _box_mesh(Vector3(1.8, 0.07, 0.45)), _m["wood"], 70.0)
    _batch("bench_back", _box_mesh(Vector3(1.8, 0.35, 0.06)), _m["wood"], 70.0)
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
        _batch("car%d" % i, CarModel.parked_mesh(PARKED_COLORS[i]), null, 160.0, true)
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


func _flush_batches() -> void:
    for ck: String in _batches:
        var b: Dictionary = _batches[ck]
        var d: Dictionary = _defs[b["key"]]
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
    bus_stops.append(_c + n * (h + ROAD * 0.5 - 3.5) + a * 12.0)


## Промзона: склад (грузчик), стоянка фур (дальнобойщик), АЗС.
func _tpl_industrial() -> void:
    var inner := BLOCK - WALK * 2.0
    _flat(_c, Vector2(inner, inner), _m["yard_asphalt"], SIDE_H + 0.006)

    var wh := _p(-6, -16)
    _solid(Vector3(34, 9, 16), Vector3(wh.x, 4.5, wh.z), _m["garage"])
    _deco(Vector3(34.4, 0.4, 16.4), Vector3(wh.x, 9.2, wh.z), _m["roof"])
    _deco(Vector3(5, 4.5, 0.15), Vector3(wh.x, 2.25, wh.z + 8.05), _m["shutter"])
    _label("СКЛАД", Vector3(wh.x, 7.0, wh.z + 8.1), Vector3(0, 0, 1), 160, Color(0.95, 0.95, 0.95))
    building_rects.append(Rect2(wh.x - 17.0, wh.z - 8.0, 34.0, 16.0))
    _occupy(wh, 34.0, 16.0)
    warehouse_drop = _p(-6, -6)
    for k in 3:
        _deco(Vector3(0.8, 0.8, 0.8), _p(-2.5 + k * 0.9, -7) + Vector3(0, 0.4, 0), _m["wood"])

    # Фура, из которой грузчик носит коробки на склад.
    var tr := _p(-6, 8)
    _solid(Vector3(2.5, 2.7, 6.5), tr + Vector3(0, 1.9, 0), _m["white"])
    _solid(Vector3(2.4, 2.4, 2.4), tr + Vector3(0, 1.6, 4.6), _m["blue"])
    _occupy(tr + Vector3(0, 0, 2), 4.0, 11.0)
    building_rects.append(Rect2(tr.x - 1.25, tr.z - 3.25, 2.5, 9.0))
    warehouse_pick = _p(-6, 3.5)

    # Стоянка дальнобойщиков
    var dep := _p(14, 0)
    _deco(Vector3(0.15, 3.0, 0.15), dep + Vector3(-2.0, 1.5, 0), _m["metal"])
    _deco(Vector3(0.15, 3.0, 0.15), dep + Vector3(2.0, 1.5, 0), _m["metal"])
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
    var red := _mat(Color(0.80, 0.12, 0.10), 0.5)
    _deco(Vector3(14, 0.5, 9) if along_x else Vector3(9, 0.5, 14), Vector3(c.x, y + 5.2, c.z), _m["white"])
    _deco(Vector3(14.1, 0.25, 9.1) if along_x else Vector3(9.1, 0.25, 14.1), Vector3(c.x, y + 5.0, c.z), red)
    for sx: float in [-6.0, 6.0]:
        for sz: float in [-4.0, 4.0]:
            var post := c + axis * sx + perp * sz
            _solid(Vector3(0.35, 5.0, 0.35), Vector3(post.x, y + 2.5, post.z), _m["white"])
    for k: float in [-3.0, 3.0]:
        var pump := c + axis * k
        _solid(Vector3(0.8, 1.6, 0.6), Vector3(pump.x, y + 0.8, pump.z), red)
        fuel_pumps.append(Vector3(pump.x, y, pump.z))
    for s: float in [-1.0, 1.0]:
        _label("АЗС", Vector3(c.x, y + 5.2, c.z) + perp * (4.62 * s), perp * s, 120, Color(0.85, 0.1, 0.1))
    var shop := c - perp * 9.5
    _solid(Vector3(8, 3.5, 5) if along_x else Vector3(5, 3.5, 8), Vector3(shop.x, y + 1.75, shop.z), _m["plaster"])
    _label("МАГАЗИН", Vector3(shop.x, y + 2.8, shop.z) + perp * (2.56 if along_x else 2.56), perp, 48, Color(0.2, 0.2, 0.2))
    building_rects.append(Rect2(shop.x - 4.0, shop.z - 4.0, 8.0, 8.0))
    _occupy(c, 30.0, 30.0)


## За городом: две АЗС на трассах, лес с лесопилкой, точки для дальнобоя.
func _build_outskirts() -> void:
    _gas_station(Vector3(-248, 0, 0), false)
    _gas_station(Vector3(0, 0, -248), true)

    var fc := Vector3(-270, 0, -270)
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
    _flat(Vector3(-226, 0, -222), Vector2(22, 18), _m["gravel"], 0.015)

    log_pile = Vector3(-226, 0, -226)
    for k in 4:
        _deco(Vector3(4.0, 0.5, 0.5), log_pile + Vector3(0, 0.25 + (k % 2) * 0.5, -1.2 + k * 0.6), _m["wood"])
    _deco(Vector3(0.15, 3.0, 0.15), log_pile + Vector3(3.0, 1.5, 0), _m["metal"])
    _deco(Vector3(3.6, 0.9, 0.1), log_pile + Vector3(3.0, 3.2, 0), _m["wood"])
    _label("ЛЕСОПИЛКА", log_pile + Vector3(3.0, 3.2, 0.06), Vector3(0, 0, 1), 40, Color(1, 1, 1))
    log_pile += Vector3(0, 0, 3.0)

    truck_drops = [Vector3(-248, 0, -22), Vector3(22, 0, -248), Vector3(-226, 0, -214),
            Vector3(-215, 0, 215), Vector3(215, 0, -215)]


## Павильон «ОБЩИЙ РЫНОК»: вход смотрит на площадь (-Z).
func _market(c: Vector3) -> void:
    var base := Vector3(c.x, SIDE_H, c.z)
    _solid(Vector3(14, 3.6, 5), base + Vector3(0, 1.8, 0), _m["plaster"])
    _deco(Vector3(12, 2.2, 0.06), base + Vector3(0, 1.4, -2.53), _m["vitrine"])
    _deco(Vector3(14, 0.12, 2.0), base + Vector3(0, 3.0, -3.4), _tinted("awning", Color(1.0, 0.78, 0.25), 2.0))  # навес
    _deco(Vector3(14.4, 1.4, 0.15), base + Vector3(0, 4.4, -2.55), _m["sign"])
    _label("ОБЩИЙ РЫНОК", base + Vector3(0, 4.4, -2.65), Vector3(0, 0, -1), 150, Color(0.85, 0.55, 0.05))
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
    var yaw := _face_center(to_center)
    var front := _ff
    var accent: Color = f["color"]
    var wall: Material = _tinted("plaster", f["wall"], 3.0)
    # фасад из модулей «стена + окно» (картинки textures/org/*_window.png): 11 x 3 по фасаду, 5 x 3 по торцу
    var module := String({"mayor": "mayor_window", "police": "police_window", "hospital": "hospital_window",
            "kgb": "kgb_window"}.get(fid, ""))
    var has_module := module != "" and _org_tex(module) != null
    if has_module:
        wall = _module_mat(module, Vector3(34.0, 11.0, 16.0), Vector3(11.0, 3.0, 5.0))
    elif fid == "fire" and _org_tex("fire_brick") != null:
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
    var plinth: Material = _m["granite"] if fid == "kgb" or fid == "mayor" else _m["plinth"]
    if fid == "kgb" and _org_tex("kgb_granite") != null:
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
            var skip := fl == 0 and (absf(x) < 4.0 or (fid == "fire" and x > 3.0))
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
        if fid == "fire":
            col_mat = _m["concrete"]
        elif fid == "kgb":
            col_mat = plinth
        _solid(Vector3(0.5, 3.6, 0.5), _fp(cx, 0.0) + Vector3(0, 1.8, 0), col_mat, yaw)
    _deco(Vector3(2.8, 2.9, 0.1), _fp(0, -3.98) + Vector3(0, 1.5, 0), _m["glass"], yaw)
    _deco(Vector3(3.1, 0.15, 0.14), _fp(0, -3.95) + Vector3(0, 3.0, 0), _m["metal"], yaw)
    _deco(Vector3(16.0, 1.5, 0.15), _fp(0, -3.95) + Vector3(0, 5.0, 0), _m["sign"], yaw)
    var title: String = f["title"]
    _label(title, _fp(0, -3.86) + Vector3(0, 5.0, 0), front, 150 if title.length() < 10 else 120, accent.darkened(0.2))
    _emblem(String(f.get("emblem", "")), _fp(-6.6, -3.84) + Vector3(0, 5.0, 0), front, 1.3)
    _emblem(String(f.get("emblem", "")), _fp(6.6, -3.84) + Vector3(0, 5.0, 0), front, 1.3)
    _flat(_fp(0, 0), _fsz(40.0, 8.0), _m["paving"], SIDE_H + 0.006)
    _focc(_fp(0, 0), 40.0, 8.0)

    # Особенности каждой фракции
    match fid:
        "mayor":
            for fx: float in [-8.0, 8.0]:
                var fp := _fp(fx, 1.5)
                _deco(Vector3(0.12, 9.0, 0.12), fp + Vector3(0, 4.5, 0), _m["metal"])
                var stripes := [Color(0.95, 0.95, 0.95), Color(0.10, 0.30, 0.75), Color(0.80, 0.12, 0.12)]
                for k in 3:
                    _deco(Vector3(2.2, 0.45, 0.04), fp + Vector3(0, 8.6 - k * 0.45, 0) + _fb * Vector3(1.15 * signf(fx), 0, 0),
                            _mat(stripes[k], 0.8), yaw)
        "police":
            _deco(Vector3(BW + 0.1, 0.45, 0.05), _fp(0, -3.96) + Vector3(0, 3.3, 0), _mat(Color(0.12, 0.25, 0.65), 0.6), yaw)
        "hospital":
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
    var line := _mat(Color(0.9, 0.9, 0.85), 0.8)
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
    if fid == "mayor":
        city_hall = _fp(0, -2.0)


## Простые интерьеры зданий фракций. Стоят далеко за городом, вход — телепорт.
func _build_interiors() -> void:
    const W := 24.0
    const D := 16.0
    const H := 4.4
    for k in FactionData.LIST.size():
        var f: Dictionary = FactionData.LIST[k]
        var fid: String = f["id"]
        var accent: Color = f["color"]
        var o := Vector3(2000.0 + k * 80.0, SIDE_H, 2000.0)
        if String(f.get("type", "state")) == "gang":
            _gang_interior(f, o)
            continue
        var wall: Material = _tinted("plaster", Color(f["wall"]).lightened(0.25), 3.0)
        var floor_mat: Material
        match fid:
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
            match fid:
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
        _solid(Vector3(W + 1.0, 0.4, D + 1.0), o + Vector3(0, H + 0.2, 0), _m["white"])
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
        _deco(Vector3(2.4, 2.8, 0.08), o + Vector3(0, 1.4, D * 0.5 - 0.22), _mat(Color(0.30, 0.20, 0.13), 0.6))
        _label("ВЫХОД", o + Vector3(0, 3.2, D * 0.5 - 0.25), Vector3(0, 0, -1), 64, Color(0.3, 0.9, 0.4))
        # вывеска фракции на дальней стене
        _deco(Vector3(9.0, 1.4, 0.06), o + Vector3(0, 3.1, -D * 0.5 + 0.23), _m["sign"])
        _label(String(f["title"]), o + Vector3(0, 3.1, -D * 0.5 + 0.28), Vector3(0, 0, 1), 110, accent.darkened(0.2))
        if fid != "hospital":   # у больницы на стене уже красный крест
            _emblem(String(f.get("emblem", "")), o + Vector3(0, 1.6, -D * 0.5 + 0.26), Vector3(0, 0, 1), 1.1)

        # отдел кадров (слева) и стойка (справа)
        var desk_mat: Material = _mat(Color(0.35, 0.24, 0.16), 0.6) if fid != "kgb" else _mat(Color(0.15, 0.12, 0.10), 0.5)
        if _org_tex("desk_front") != null:
            desk_mat = _fit_mat("org/desk_front", Vector3(1.7, 1.05, 0.9), Color(0.35, 0.24, 0.16))
        # доска объявлений
        _deco(Vector3(0.04, 1.0, 1.4), o + Vector3(-W * 0.5 + 0.23, 1.9, -5.6),
                _fit_mat("org/cork_board", Vector3(0.04, 1.0, 1.4), Color(0.70, 0.55, 0.35)))
        for side: float in [-1.0, 1.0]:
            _solid(Vector3(3.4, 1.05, 0.9), o + Vector3(7.0 * side, 0.525, -5.2), desk_mat)
            _deco(Vector3(0.6, 0.9, 0.6), o + Vector3(7.0 * side, 0.45, -6.6), _m["metal"])   # стул за стойкой
        _deco(Vector3(4.6, 0.9, 0.06), o + Vector3(-7.0, 2.4, -D * 0.5 + 0.23), _m["sign"])
        _label("ОТДЕЛ КАДРОВ", o + Vector3(-7.0, 2.4, -D * 0.5 + 0.28), Vector3(0, 0, 1), 64, Color(0.15, 0.15, 0.18))
        var desk_name := "ПАСПОРТНЫЙ СТОЛ"
        match fid:
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
        match fid:
            "mayor":
                var carpet := _plane_mat("carpet_runner", Vector2(1.0, 5.0), Color(0.55, 0.08, 0.10))
                _flat(o + Vector3(0, 0, 0), Vector2(2.6, D - 1.0), carpet, SIDE_H + 0.01)
                for fx: float in [-2.5, 2.5]:
                    _deco(Vector3(0.08, 3.0, 0.08), o + Vector3(fx, 1.5, -D * 0.5 + 0.6), _m["metal"])
                    var cols := [Color(0.95, 0.95, 0.95), Color(0.10, 0.30, 0.75), Color(0.80, 0.12, 0.12)]
                    for c in 3:
                        _deco(Vector3(1.2, 0.3, 0.03), o + Vector3(fx + 0.65, 2.75 - c * 0.3, -D * 0.5 + 0.6), _mat(cols[c], 0.8))
                for px: float in [-10.5, 10.5]:
                    _deco(Vector3(0.8, 1.2, 0.8), o + Vector3(px, 0.6, 6.5), _m["concrete"])
                    _put("bush", o + Vector3(px, 1.5, 6.5), 0.0, Color.WHITE, Vector3(0.8, 0.9, 0.8))
            "police":
                # камера (КПЗ) с решёткой у правой стены
                if _org_tex("kpz_bars") != null:
                    _solid(Vector3(0.1, H, 5.4), o + Vector3(8.6, H * 0.5, 2.86), _fit_mat("org/kpz_bars", Vector3(0.1, H, 2.0), Color(0.5, 0.5, 0.5)))
                else:
                    for bz in 15:
                        _solid(Vector3(0.06, H, 0.06), o + Vector3(8.6, H * 0.5, 0.2 + bz * 0.38), _m["metal"])
                _solid(Vector3(3.2, 0.5, 0.8), o + Vector3(10.6, 0.25, 5.8), _m["wood"])
                _label("КПЗ", o + Vector3(8.5, 3.4, 3.0), Vector3(-1, 0, 0), 64, Color(0.9, 0.9, 0.9))
                if not org_ok:
                    _deco(Vector3(W - 0.5, 0.35, 0.03), o + Vector3(0, 1.2, -D * 0.5 + 0.22), _mat(Color(0.12, 0.25, 0.65), 0.6))
            "hospital":
                var bed := _fit_mat("org/bed_sheet", Vector3(1.0, 0.6, 2.1), Color(0.95, 0.95, 0.95))
                for bz: float in [-1.5, 1.5, 4.5]:
                    _solid(Vector3(1.0, 0.6, 2.1), o + Vector3(10.6, 0.3, bz), bed)
                    _deco(Vector3(0.05, 1.8, 1.4), o + Vector3(9.3, 0.9, bz + 1.4), _mat(Color(0.55, 0.80, 0.80), 0.9))
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
                if not org_ok:
                    _deco(Vector3(W - 0.5, 0.35, 0.03), o + Vector3(0, 1.2, -D * 0.5 + 0.22), lred)
            "kgb":
                for bz in 6:
                    _solid(Vector3(0.7, 1.9, 0.9), o + Vector3(W * 0.5 - 0.6, 0.95, -4.0 + bz * 1.2),
                            _fit_mat("org/file_cabinet", Vector3(0.7, 1.9, 0.9), Color(0.45, 0.46, 0.45)))
                _flat(o + Vector3(0, 0, 0), Vector2(6.0, 4.0), _plane_mat("carpet_wall", Vector2(1, 1), Color(0.35, 0.08, 0.08)), SIDE_H + 0.01)

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
    _deco(Vector3(1.2, 2.3, 0.08), _fp(-4.5, 9.03) + Vector3(0, 1.15, 0), _mat(Color(0.22, 0.20, 0.18), 0.6), yaw)
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
    _deco(Vector3(1.4, 2.4, 0.08), o + Vector3(0, 1.2, D * 0.5 - 0.22), _mat(Color(0.22, 0.20, 0.18), 0.6))
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
    var tire := _mat(Color(0.07, 0.07, 0.07), 0.9)
    for tz: float in [-5.8, -4.9]:
        _solid(Vector3(0.75, 1.2, 0.75), o + Vector3(W * 0.5 - 0.7, 0.6, tz), tire)
    # столик с картами и стулья
    _solid(Vector3(1.2, 0.75, 1.2), o + Vector3(-2.0, 0.375, 2.5), _m["wood"])
    for cx: float in [-3.1, -0.9]:
        _deco(Vector3(0.5, 0.5, 0.5), o + Vector3(cx, 0.25, 2.5), _m["metal"])
    interiors[gid] = {"spawn": o + Vector3(0, 0.3, D * 0.5 - 3.6), "exit": o + Vector3(0, 0, D * 0.5 - 1.3),
            "hr": o + Vector3(-W * 0.5 + 2.6, 0, -1.2), "desk": o + Vector3(0, 0, 0)}



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
    var rx := 262.0
    _flat(Vector3((222.0 + rx) * 0.5, 0, 0), Vector2(rx - 222.0 + 10.0, 10.0), _m["asphalt"], 0.006)
    _flat(Vector3(rx, 0, 0), Vector2(10.0, 190.0), _m["asphalt"], 0.007)
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


func _cottage(c: Vector3, front: Vector3, wall_col: Color, roof_col: Color, price: int) -> void:
    var yaw := atan2(front.x, front.z)
    var b := Basis(Vector3.UP, yaw)
    _flat(c, Vector2(24.0, 24.0) if absf(front.x) < 0.5 else Vector2(24.0, 24.0), _m["grass"], 0.01)
    var hc := c + b * Vector3(0, 0, -3.0)
    var wall := _tinted("plaster", wall_col, 3.0)
    _solid(Vector3(10.0, 3.4, 8.0), hc + Vector3(0, 1.7, 0), wall, yaw)
    _deco(Vector3(10.3, 0.5, 8.3), hc + Vector3(0, 0.25, 0), _m["plinth"], yaw)
    # двускатная крыша: два наклонных ската
    var roof := _tinted("roof_gravel", roof_col, 2.0)
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
    _deco(Vector3(24.0, 1.2, 0.08), c + b * Vector3(0, 0, -12.0) + Vector3(0, 0.6, 0), fence, yaw)
    for sx: float in [-12.0, 12.0]:
        _deco(Vector3(0.08, 1.2, 24.0), c + b * Vector3(sx, 0, 0) + Vector3(0, 0.6, 0), fence, yaw)
    for sx: float in [-7.0, 7.0]:
        _deco(Vector3(10.0, 1.2, 0.08), c + b * Vector3(sx, 0, 12.0) + Vector3(0, 0.6, 0), fence, yaw)
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
    var floor_mat: Material = _tinted("org/parquet", Color(1, 1, 1), 1.6) if _org_tex("parquet") != null else _m["wood"]
    _solid(Vector3(w + 1.0, 0.4, d + 1.0), o + Vector3(0, -0.2, 0), floor_mat)
    _solid(Vector3(w + 1.0, 0.4, d + 1.0), o + Vector3(0, H + 0.2, 0), _m["white"])
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
    _deco(Vector3(1.1, 2.2, 0.06), o + Vector3(0, 1.1, d * 0.5 - 0.22), _fit_mat("door_old", Vector3(1.1, 2.2, 0.06), Color(0.35, 0.24, 0.15)))
    _label("ВЫХОД", o + Vector3(0, 2.5, d * 0.5 - 0.25), Vector3(0, 0, -1), 48, Color(0.3, 0.9, 0.4))
    # окно с «улицей» за ним
    var sky := _mat(Color(0.6, 0.75, 0.9), 0.5)
    sky.emission_enabled = true
    sky.emission = Color(0.55, 0.7, 0.9)
    sky.emission_energy_multiplier = 0.6
    _deco(Vector3(2.4, 1.4, 0.05), o + Vector3(-1.5, 1.7, -d * 0.5 + 0.23), sky)
    _deco(Vector3(2.6, 0.1, 0.25), o + Vector3(-1.5, 0.95, -d * 0.5 + 0.3), _m["white"])
    # ковёр на стене, диван, столик, телевизор
    _deco(Vector3(0.03, 1.6, 2.4), o + Vector3(-w * 0.5 + 0.23, 1.7, -0.5), _fit_mat("org/carpet_wall", Vector3(0.03, 1.6, 2.4), Color(0.55, 0.12, 0.1)))
    var sofa := _fit_mat("org/sofa", Vector3(1.0, 1.0, 2.6), Color(0.35, 0.22, 0.14))
    _solid(Vector3(0.9, 0.45, 2.6), o + Vector3(-w * 0.5 + 0.7, 0.225, -0.5), sofa)
    _deco(Vector3(0.25, 0.55, 2.6), o + Vector3(-w * 0.5 + 0.35, 0.72, -0.5), sofa)
    _solid(Vector3(0.8, 0.45, 1.2), o + Vector3(-w * 0.5 + 2.2, 0.225, -0.5), _m["wood"])
    _solid(Vector3(0.5, 0.6, 1.6), o + Vector3(-1.0 + w * 0.5 - 4.0, 0.3, -0.5), _m["wood"])
    _deco(Vector3(0.12, 0.8, 1.3), o + Vector3(-1.0 + w * 0.5 - 4.0, 1.0, -0.5), _mat(Color(0.05, 0.05, 0.06), 0.3))
    # кровать
    _solid(Vector3(1.6, 0.55, 2.1), o + Vector3(w * 0.5 - 1.1, 0.275, -d * 0.5 + 1.5),
            _fit_mat("org/bed_sheet", Vector3(1.6, 0.55, 2.1), Color(0.95, 0.95, 0.95)))
    # кухня: столешница и холодильник
    _solid(Vector3(0.7, 0.9, 2.6), o + Vector3(w * 0.5 - 0.55, 0.45, d * 0.5 - 2.6), _fit_mat("org/desk_front", Vector3(0.7, 0.9, 1.3), Color(0.6, 0.5, 0.4)))
    _solid(Vector3(0.8, 1.9, 0.8), o + Vector3(w * 0.5 - 0.6, 0.95, d * 0.5 - 0.8), _mat(Color(0.93, 0.93, 0.92), 0.3))
    _label("ХОЛОДИЛЬНИК", o + Vector3(w * 0.5 - 1.02, 1.6, d * 0.5 - 0.8), Vector3(-1, 0, 0), 28, Color(0.2, 0.2, 0.25))
    return {"spawn": o + Vector3(0, 0.3, d * 0.5 - 2.6), "exit": o + Vector3(0, 0, d * 0.5 - 1.0),
            "fridge": o + Vector3(w * 0.5 - 1.6, 0, d * 0.5 - 1.2), "bed": o + Vector3(w * 0.5 - 2.3, 0, -d * 0.5 + 1.6)}
