extends Node3D
## Генератор района в духе российского спального микрорайона:
## панельные девятиэтажки, хрущёвки, башни, дворы с детскими площадками,
## гаражи, ларьки, остановка, фонари, берёзы, припаркованные машины.
## Всё строится из примитивов. Мелочи (балконы, деревья, фонари, машины)
## рисуются через MultiMesh — один draw call на вид объекта.

const CarModel := preload("res://scripts/car_model.gd")

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

var _batches := {}
var _occupied: Array[Rect2] = []
var _c := Vector3.ZERO   # центр текущего квартала
var _mx := 1.0           # зеркалирование шаблона квартала
var _mz := 1.0

var _panel_mats: Array[StandardMaterial3D] = []
var _brick_mats: Array[StandardMaterial3D] = []
var _m := {}


func _ready() -> void:
    rng.seed = 1977
    _make_materials()
    _define_batches()
    _build_ground()
    for i in range(-GRID, GRID + 1):
        for j in range(-GRID, GRID + 1):
            _build_block(i, j)
    _build_road_marks()
    _flush_batches()


# ================================================================ кварталы

func _build_block(i: int, j: int) -> void:
    _c = Vector3(i * PITCH, 0.0, j * PITCH)
    var is_center := i == 0 and j == 0
    _mx = 1.0 if is_center or rng.randf() < 0.5 else -1.0
    _mz = 1.0 if is_center or rng.randf() < 0.5 else -1.0

    _solid(Vector3(BLOCK, SIDE_H, BLOCK), _c + Vector3(0, SIDE_H * 0.5, 0), _m["sidewalk"])
    var inner := BLOCK - WALK * 2.0
    _flat(_c, Vector2(inner, inner), _m["paving"] if is_center else _m["grass"], SIDE_H + 0.004)

    if is_center:
        _tpl_square()
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

    _edge_lamps_and_trees()
    _scatter_trees(5 if is_center else 14)


## Центральная площадь: стела, клумбы, ларьки, остановка. Здесь появляется игрок.
func _tpl_square() -> void:
    var mon := _p(0, -12)
    _solid(Vector3(4.0, 1.0, 4.0), mon + Vector3(0, 0.5, 0), _m["concrete"])
    _solid(Vector3(1.4, 10.0, 0.9), mon + Vector3(0, 6.0, 0), _m["white"])
    _occupy(mon, 7.0, 7.0)

    for x: float in [-12.0, 12.0]:
        for z: float in [-12.0, 4.0]:
            var bed := _p(x, z)
            _deco(Vector3(4.0, 0.4, 4.0), bed + Vector3(0, 0.2, 0), _m["concrete"])
            _deco(Vector3(3.6, 0.42, 3.6), bed + Vector3(0, 0.21, 0), _m["soil"])
            for k in 6:
                var off := Vector3(rng.randf_range(-1.2, 1.2), 0.55, rng.randf_range(-1.2, 1.2))
                var col := Color(0.85, 0.15, 0.2) if rng.randf() < 0.5 else Color(0.95, 0.75, 0.2)
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
    _bus_stop(_p(21, 31), Vector3(0, 0, 1))

    _occupy(_p(0, 24), 28.0, 8.0)   # здесь стоят машины игрока (main.gd)
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
    else:
        mat = _panel_mats[rng.randi() % _panel_mats.size()]

    _solid(Vector3(sx, h, sz), base + Vector3(0, h * 0.5, 0), mat)
    _deco(Vector3(sx + 0.2, 0.7, sz + 0.2), base + Vector3(0, 0.35, 0), _m["plinth"])
    _deco(Vector3(sx + 0.3, 0.45, sz + 0.3), base + Vector3(0, h + 0.2, 0), _m["roof"])
    _occupy(base, sx, sz)

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
                var col := Color(0.80, 0.88, 0.94) if rng.randf() < 0.35 else Color(0.90, 0.89, 0.86)
                _put("balcony", pos, 0.0 if facade_x else PI * 0.5, col)

    # Подъезды: двери, козырьки, лавочки, машинные отделения лифтов на крыше
    if entrance == Vector3.ZERO:
        return
    var e_x := absf(entrance.z) > 0.5
    var flen := sx if e_x else sz
    var e_out := (sz if e_x else sx) * 0.5
    var axis := Vector3(1, 0, 0) if e_x else Vector3(0, 0, 1)
    var yaw := 0.0 if e_x else PI * 0.5
    var count := maxi(1, int(flen / 14.0))
    for e: int in range(count):
        var u := -flen * 0.5 + flen * (e + 0.5) / count
        var p := base + axis * u + entrance * e_out
        _put("door", p + Vector3(0, 1.1, 0) + entrance * 0.06, yaw)
        _put("canopy", p + Vector3(0, 2.55, 0) + entrance * 0.65, yaw)
        if style != "brick":
            _put("roof_box", base + axis * u + Vector3(0, h + 1.4, 0), yaw)
        if rng.randf() < 0.6:
            _bench(p + entrance * 1.6 + axis * 2.4 + Vector3(0, SIDE_H, 0), entrance)


func _shop(center: Vector3, length: float, depth: float, front: Vector3, text: String) -> void:
    var along_x := absf(front.z) > 0.5
    var sx := length if along_x else depth
    var sz := depth if along_x else length
    var base := Vector3(center.x, 0.0, center.z)
    var out := (sz if along_x else sx) * 0.5
    var yaw := 0.0 if along_x else PI * 0.5
    _solid(Vector3(sx, 4.2, sz), base + Vector3(0, 2.1, 0), _m["concrete"])
    _deco(Vector3(sx + 0.3, 0.3, sz + 0.3), base + Vector3(0, 4.3, 0), _m["roof"])
    _deco(Vector3(length - 2.0, 2.6, 0.08), base + front * (out + 0.04) + Vector3(0, 1.6, 0), _m["glass"], yaw)
    _deco(Vector3(length * 0.6, 1.0, 0.12), base + front * (out + 0.1) + Vector3(0, 3.6, 0), _m["white"], yaw)
    _label(text, base + front * (out + 0.17) + Vector3(0, 3.6, 0), front, 120, Color(0.8, 0.1, 0.1))
    _occupy(base, sx + 2.0, sz + 2.0)


func _garages(center: Vector3, count: int, along_x: bool, facing: Vector3) -> void:
    var flen := count * 3.2
    var size := Vector3(flen, 2.5, 6.0) if along_x else Vector3(6.0, 2.5, flen)
    var base := Vector3(center.x, 0.0, center.z)
    _solid(size, base + Vector3(0, 1.25, 0), _m["garage"])
    _deco(size + Vector3(0.3, -2.4, 0.3), base + Vector3(0, 2.55, 0), _m["roof"])
    _flat(base + facing * 6.0, Vector2(flen, 6.0) if along_x else Vector2(6.0, flen),
            _m["yard_asphalt"], SIDE_H + 0.008)
    _occupy(base, size.x, size.z)
    _occupy(base + facing * 6.0, size.x, size.z)

    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    var yaw := 0.0 if along_x else PI * 0.5
    var colors := [Color(0.45, 0.25, 0.15), Color(0.20, 0.35, 0.25), Color(0.25, 0.32, 0.45),
            Color(0.50, 0.50, 0.48), Color(0.55, 0.40, 0.20)]
    for g: int in range(count):
        var u := -flen * 0.5 + 3.2 * (g + 0.5)
        var col: Color = colors[rng.randi() % colors.size()]
        _put("garage_door", base + axis * u + facing * 3.03 + Vector3(0, 1.1, 0), yaw, col)


func _kiosk(p: Vector3, facing: Vector3, text: String, col: Color) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    _solid(Vector3(3.2, 2.6, 2.4), p + Vector3(0, 1.3, 0), _mat(col, 0.6), yaw)
    _deco(Vector3(2.6, 1.2, 0.05), p + b * Vector3(0, 1.35, 1.21), _m["glass"], yaw)
    _deco(Vector3(3.6, 0.1, 1.0), p + b * Vector3(0, 2.3, 1.6), _mat(col.darkened(0.25), 0.6), yaw)
    _deco(Vector3(3.2, 0.55, 0.08), p + b * Vector3(0, 2.95, 1.1), _m["white"], yaw)
    _label(text, p + b * Vector3(0, 2.95, 1.16), facing, 64, col.darkened(0.3))
    _occupy(p, 4.0, 4.0)


func _bus_stop(p: Vector3, facing: Vector3) -> void:
    var yaw := atan2(facing.x, facing.z)
    var b := Basis(Vector3.UP, yaw)
    _deco(Vector3(4.2, 0.12, 1.9), p + b * Vector3(0, 2.6, 0.1), _m["blue"], yaw)
    _solid(Vector3(4.0, 2.4, 0.06), p + b * Vector3(0, 1.3, -0.75), _m["glass"], yaw)
    for sx: float in [-2.0, 2.0]:
        _deco(Vector3(0.06, 2.4, 1.4), p + b * Vector3(sx, 1.3, -0.1), _m["glass"], yaw)
    _bench(p + b * Vector3(0, 0, -0.4), facing)
    _deco(Vector3(0.08, 2.8, 0.08), p + b * Vector3(2.7, 1.4, 0.8), _m["metal"], yaw)
    _deco(Vector3(0.6, 0.6, 0.04), p + b * Vector3(2.7, 2.6, 0.8), _m["yellow"], yaw)
    _label("А", p + b * Vector3(2.7, 2.6, 0.83), facing, 64, Color(0.1, 0.1, 0.1))
    _label("ОСТАНОВКА", p + b * Vector3(0, 2.6, 1.07), facing, 40, Color(1, 1, 1))
    _occupy(p, 5.0, 3.0)


# ================================================================ двор

func _playground(c: Vector3) -> void:
    _occupy(c, 11.0, 9.0)
    # песочница
    _deco(Vector3(3.0, 0.25, 3.0), c + Vector3(-3, 0.125, -2), _m["wood"])
    _deco(Vector3(2.7, 0.26, 2.7), c + Vector3(-3, 0.13, -2), _m["sand"])
    # качели
    var s := c + Vector3(2.5, 0, -2)
    for dx: float in [-1.2, 1.2]:
        _deco(Vector3(0.1, 2.4, 0.1), s + Vector3(dx, 1.2, 0), _m["blue"])
    _deco(Vector3(2.6, 0.1, 0.1), s + Vector3(0, 2.4, 0), _m["blue"])
    _deco(Vector3(0.6, 0.05, 0.35), s + Vector3(0, 0.5, 0), _m["wood"])
    for dx: float in [-0.25, 0.25]:
        _deco(Vector3(0.02, 1.85, 0.02), s + Vector3(dx, 1.43, 0), _m["metal"])
    # горка
    var g := c + Vector3(1.5, 0, 2.0)
    _deco(Vector3(1.2, 0.1, 1.2), g + Vector3(0, 1.5, 0), _m["red"])
    for px: float in [-0.55, 0.55]:
        for pz: float in [-0.55, 0.55]:
            _deco(Vector3(0.08, 1.5, 0.08), g + Vector3(px, 0.75, pz), _m["metal"])
    var slide := _deco(Vector3(0.7, 0.06, 2.63), g + Vector3(0, 0.78, 1.7), _m["yellow"])
    slide.rotation.x = 0.583
    _deco(Vector3(0.6, 1.6, 0.06), g + Vector3(0, 0.8, -0.65), _m["yellow"])
    # лавочки
    _bench(c + Vector3(-4.5, 0, 3.5), Vector3(0, 0, -1))
    _bench(c + Vector3(-2.0, 0, 3.5), Vector3(0, 0, -1))


func _parking(center: Vector3, along_x: bool, slots: int) -> void:
    var flen := slots * 2.7
    _flat(center, Vector2(flen, 6.0) if along_x else Vector2(6.0, flen), _m["yard_asphalt"], SIDE_H + 0.008)
    _occupy(center, flen if along_x else 6.0, 6.0 if along_x else flen)
    var axis := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
    var yaw := 0.0 if along_x else PI * 0.5
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


func _tree(p: Vector3) -> void:
    var s := rng.randf_range(0.85, 1.2)
    var sc := Vector3(s, s, s)
    var base := Vector3(p.x, SIDE_H, p.z)
    if rng.randf() < 0.55:  # берёза
        _put("birch", base + Vector3(0, 2.75 * s, 0), 0.0, Color.WHITE, sc)
        _put("birch_crown", base + Vector3(0, 5.6 * s, 0), rng.randf() * TAU,
                Color(0.42, 0.62, 0.25).lerp(Color(0.55, 0.70, 0.30), rng.randf()), sc)
    else:                   # тополь / липа
        _put("trunk", base + Vector3(0, 1.3 * s, 0), 0.0, Color.WHITE, sc)
        _put("crown", base + Vector3(0, 3.9 * s, 0), rng.randf() * TAU,
                Color(0.22, 0.42, 0.18).lerp(Color(0.35, 0.52, 0.22), rng.randf()), sc)
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
    var panel_tex := _facade_texture(false)
    var brick_tex := _facade_texture(true)
    for col: Color in [Color(0.93, 0.93, 0.91), Color(0.86, 0.87, 0.88), Color(0.90, 0.88, 0.82),
            Color(0.80, 0.86, 0.90), Color(0.92, 0.86, 0.78)]:
        _panel_mats.append(_facade_mat(col, panel_tex))
    for col: Color in [Color(0.78, 0.45, 0.36), Color(0.86, 0.74, 0.58), Color(0.90, 0.88, 0.82)]:
        _brick_mats.append(_facade_mat(col, brick_tex))

    _m["asphalt"] = _mat(Color(0.19, 0.19, 0.20), 0.95)
    _m["wasteland"] = _mat(Color(0.30, 0.34, 0.22), 1.0)
    _m["sidewalk"] = _mat(Color(0.58, 0.57, 0.55), 0.95)
    _m["grass"] = _mat(Color(0.33, 0.45, 0.22), 1.0)
    _m["paving"] = _mat(Color(0.70, 0.66, 0.60), 0.9)
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
    var glass := _mat(Color(0.18, 0.26, 0.32), 0.1)
    glass.metallic = 0.5
    _m["glass"] = glass


## Текстура одной «ячейки» фасада 3 x 2.8 м: панель со швами или кирпич + окно.
func _facade_texture(brick: bool) -> ImageTexture:
    var img := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.96, 0.96, 0.96))
    var line := Color(0.78, 0.78, 0.78)
    if brick:
        for y in range(0, 64, 4):
            img.fill_rect(Rect2i(0, y, 64, 1), line)
            var off := 0 if y % 8 == 0 else 4
            for x in range(off, 64, 8):
                img.fill_rect(Rect2i(x, y, 1, 4), line)
    else:
        img.fill_rect(Rect2i(0, 0, 64, 1), Color(0.7, 0.7, 0.7))
        img.fill_rect(Rect2i(0, 0, 1, 64), Color(0.7, 0.7, 0.7))
    img.fill_rect(Rect2i(15, 14, 34, 34), Color(1, 1, 1))            # рама
    img.fill_rect(Rect2i(17, 16, 30, 30), Color(0.20, 0.27, 0.34))   # стекло
    img.fill_rect(Rect2i(31, 16, 2, 30), Color(1, 1, 1))             # импост
    img.fill_rect(Rect2i(17, 28, 14, 2), Color(1, 1, 1))             # форточка
    img.fill_rect(Rect2i(13, 48, 38, 2), Color(0.65, 0.65, 0.65))    # отлив
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


func _facade_mat(col: Color, tex: Texture2D) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.albedo_texture = tex
    m.uv1_triplanar = true
    m.uv1_world_triplanar = true
    m.uv1_scale = Vector3(1.0 / CELL, 1.0 / FLOOR_H, 1.0 / CELL)
    m.roughness = 0.9
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    return m


func _define_batches() -> void:
    _batch("balcony", _box_mesh(Vector3(2.5, 1.05, 1.0)), _vc_mat(0.85))
    _batch("door", _box_mesh(Vector3(1.4, 2.2, 0.12)), _mat(Color(0.32, 0.22, 0.15), 0.7))
    _batch("canopy", _box_mesh(Vector3(2.4, 0.14, 1.3)), _m["concrete"])
    _batch("roof_box", _box_mesh(Vector3(3.5, 2.4, 3.0)), _m["concrete"])
    _batch("dash", _box_mesh(Vector3(0.18, 0.02, 2.5)), _m["white"])
    _batch("zebra", _box_mesh(Vector3(0.55, 0.02, 3.4)), _m["white"])
    _batch("pole", _cyl_mesh(0.07, 0.09, 7.0, 8), _m["metal"])
    _batch("lamp_arm", _box_mesh(Vector3(0.08, 0.08, 1.6)), _m["metal"])
    var lamp := _mat(Color(1.0, 0.96, 0.85), 0.3)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.92, 0.75)
    lamp.emission_energy_multiplier = 0.8
    _batch("lamp_head", _box_mesh(Vector3(0.3, 0.12, 0.55)), lamp)
    _batch("trunk", _cyl_mesh(0.12, 0.18, 2.6, 7), _mat(Color(0.36, 0.25, 0.17), 0.9))
    _batch("birch", _cyl_mesh(0.09, 0.13, 5.5, 7), _mat(Color(0.92, 0.90, 0.86), 0.8))
    _batch("crown", _sphere_mesh(2.0, 3.4), _vc_mat(0.9))
    _batch("birch_crown", _sphere_mesh(1.3, 4.0), _vc_mat(0.9))
    _batch("bush", _sphere_mesh(0.7, 1.0), _vc_mat(0.9))
    _batch("bench_seat", _box_mesh(Vector3(1.8, 0.07, 0.45)), _m["wood"])
    _batch("bench_back", _box_mesh(Vector3(1.8, 0.35, 0.06)), _m["wood"])
    _batch("bench_leg", _box_mesh(Vector3(0.07, 0.45, 0.45)), _m["metal"])
    _batch("garage_door", _box_mesh(Vector3(2.6, 2.1, 0.06)), _vc_mat(0.7))
    for i in PARKED_COLORS.size():
        _batch("car%d" % i, CarModel.parked_mesh(PARKED_COLORS[i]), null)


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


func _batch(key: String, mesh: Mesh, mat: Material) -> void:
    _batches[key] = {"mesh": mesh, "mat": mat, "x": [], "c": []}


func _put(key: String, pos: Vector3, yaw := 0.0, col := Color.WHITE, scl := Vector3.ONE) -> void:
    var b: Dictionary = _batches[key]
    var basis := Basis(Vector3.UP, yaw) * Basis.from_scale(scl)
    var xs: Array = b["x"]
    var cs: Array = b["c"]
    xs.append(Transform3D(basis, pos))
    cs.append(col)


func _flush_batches() -> void:
    for key: String in _batches:
        var b: Dictionary = _batches[key]
        var xs: Array = b["x"]
        var cs: Array = b["c"]
        if xs.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = true
        mm.mesh = b["mesh"]
        mm.instance_count = xs.size()
        for i in xs.size():
            mm.set_instance_transform(i, xs[i])
            mm.set_instance_color(i, cs[i])
        var mmi := MultiMeshInstance3D.new()
        mmi.name = "MM_" + key
        mmi.multimesh = mm
        if b["mat"] != null:
            mmi.material_override = b["mat"]
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
