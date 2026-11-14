extends Node3D
## Трамвай в Казани: кольцо по середине проспектов вокруг центра (оси дорог x/z = ±129),
## рельсы в асфальте, контактный провод на столбах, 4 остановки. Два вагона в стиле
## чешской «Татры»: красный низ, кремовый верх. Вагон тормозит перед машинами и игроком,
## а машины трафика — перед вагоном (точки вагона добавляются в препятствия трафика).

const L := 129.0             # половина стороны кольца (ось дороги)
const R := 7.0               # радиус поворота на перекрёстке
const CRUISE := 10.0         # м/с (~36 км/ч)
const DWELL := 8.0           # стоянка на остановке, с
const LEN := 14.0            # длина вагона
const WIDTH := 2.5
const GAUGE := 1.524         # советская колея
const STOP_NAMES := ["ул. Баумана", "пл. Свободы", "Кремлёвская", "ул. Пушкина"]

var traffic = null           # для торможения перед машинами
var obstacles: Array = []    # игрок и его машины
var focus := Vector3.ZERO

var stops: Array = []        # [{"name", "s", "pos" (на оси), "sign" (на тротуаре), "side"}]
var cars: Array = []         # [{"body", "s", "speed", "wait", "stop_i", "marks"}]
var _pts := PackedVector3Array()
var _cum := PackedFloat32Array()
var total := 0.0
var _mats := {}


func _ready() -> void:
    _build_path()
    _build_stops()
    _build_track()
    for i in 2:
        _spawn_car(total * (0.25 + 0.5 * i))


# ---------------------------------------------------------------- путь

func _build_path() -> void:
    # по часовой стрелке (вид сверху): север x+ , восток z+, юг x-, запад z-
    var corners := [Vector2(L, -L), Vector2(L, L), Vector2(-L, L), Vector2(-L, -L)]
    var pts: Array[Vector3] = []
    for i in 4:
        var c: Vector2 = corners[i]
        var prev: Vector2 = corners[(i + 3) % 4]
        var nxt: Vector2 = corners[(i + 1) % 4]
        var din := (c - prev).normalized()
        var dout := (nxt - c).normalized()
        var a := c - din * R
        var b := c + dout * R
        # дуга от a к b вокруг центра c - din*R + dout*R
        var ctr := c - din * R + dout * R
        var a0 := atan2(a.y - ctr.y, a.x - ctr.x)
        var a1 := atan2(b.y - ctr.y, b.x - ctr.x)
        var da := wrapf(a1 - a0, -PI, PI)
        for k in 9:
            var ang := a0 + da * k / 8.0
            pts.append(Vector3(ctr.x + cos(ang) * R, 0.0, ctr.y + sin(ang) * R))
    pts.append(pts[0])
    _pts = PackedVector3Array(pts)
    _cum.resize(_pts.size())
    _cum[0] = 0.0
    for i in range(1, _pts.size()):
        _cum[i] = _cum[i - 1] + _pts[i].distance_to(_pts[i - 1])
    total = _cum[_cum.size() - 1]


## Точка и направление на кольце по пройденному пути s.
func sample(s: float) -> Array:
    s = fposmod(s, total)
    var lo := 0
    var hi := _cum.size() - 1
    while hi - lo > 1:
        var mid := (lo + hi) / 2
        if _cum[mid] <= s:
            lo = mid
        else:
            hi = mid
    var seg := _cum[hi] - _cum[lo]
    var t := (s - _cum[lo]) / maxf(seg, 0.001)
    var p := _pts[lo].lerp(_pts[hi], t)
    var d := (_pts[hi] - _pts[lo]).normalized()
    return [p, d]


func _s_of(p: Vector3) -> float:
    var best := 0.0
    var bd := INF
    for i in range(_pts.size() - 1):
        var a := _pts[i]
        var b := _pts[i + 1]
        var ab := b - a
        var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
        var q := a + ab * t
        var dd := q.distance_to(p)
        if dd < bd:
            bd = dd
            best = _cum[i] + ab.length() * t
    return best


# ---------------------------------------------------------------- остановки, рельсы, провода

func _mat(c: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
    var key := "%s|%s|%s" % [c, rough, metal]
    if not _mats.has(key):
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.roughness = rough
        m.metallic = metal
        _mats[key] = m
    return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, yaw := 0.0, shadow := false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    mi.rotation.y = yaw
    if not shadow:
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _build_stops() -> void:
    var mids := [Vector3(L, 0, 0), Vector3(0, 0, L), Vector3(-L, 0, 0), Vector3(0, 0, -L)]
    for i in 4:
        var p: Vector3 = mids[i]
        var s := _s_of(p) - LEN * 0.25
        var sd: Array = sample(s)
        var dir: Vector3 = sd[1]
        var right := Vector3(-dir.z, 0, dir.x)   # справа по ходу (двери справа)
        var sign_p: Vector3 = p + right * 8.6
        stops.append({"name": String(STOP_NAMES[i]), "s": s, "pos": p, "sign": sign_p, "side": right})
        _stop_sign(sign_p, right)


func _stop_sign(p: Vector3, facing_road: Vector3) -> void:
    var root := Node3D.new()
    root.position = p
    add_child(root)
    _box(root, Vector3(0.08, 2.6, 0.08), Vector3(0, 1.3, 0), _mat(Color(0.3, 0.32, 0.34), 0.5, 0.5))
    var plate := _box(root, Vector3(0.62, 0.62, 0.04), Vector3(0, 2.4, 0), _mat(Color(0.95, 0.95, 0.92)), atan2(facing_road.x, facing_road.z))
    plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for side: float in [1.0, -1.0]:
        var l := Label3D.new()
        l.text = "Т"
        l.font_size = 120
        l.pixel_size = 0.004
        l.modulate = Color(0.1, 0.1, 0.12)
        l.outline_size = 0
        l.position = Vector3(0, 2.4, 0) - facing_road * 0.03 * side * -1.0
        l.rotation.y = atan2(facing_road.x, facing_road.z) + (0.0 if side > 0 else PI)
        root.add_child(l)
    var name_l := Label3D.new()
    name_l.text = "ТРАМВАЙ №1"
    name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_l.font_size = 40
    name_l.pixel_size = 0.005
    name_l.outline_size = 8
    name_l.modulate = Color(1.0, 0.9, 0.5)
    name_l.position = Vector3(0, 3.0, 0)
    name_l.visibility_range_end = 40.0
    root.add_child(name_l)
    # лавочка-навес: простая скамья
    _box(root, Vector3(1.6, 0.08, 0.45), Vector3(0, 0.45, 0) + facing_road * -0.9, _mat(Color(0.45, 0.3, 0.18)))


func _build_track() -> void:
    var steel := _mat(Color(0.55, 0.55, 0.56), 0.35, 0.8)
    var bed := _mat(Color(0.33, 0.33, 0.34), 0.95)
    var wire := _mat(Color(0.12, 0.12, 0.12), 0.6, 0.4)
    var pole := _mat(Color(0.35, 0.38, 0.36), 0.6, 0.3)
    for i in range(_pts.size() - 1):
        var a := _pts[i]
        var b := _pts[i + 1]
        var d := b - a
        var ln := d.length()
        if ln < 0.01:
            continue
        var yaw := atan2(d.x, d.z)
        var mid := (a + b) * 0.5
        var right := Vector3(d.z, 0, -d.x).normalized()
        _box(self, Vector3(2.4, 0.012, ln + 0.3), mid + Vector3(0, 0.014, 0), bed, yaw)
        for side: float in [-0.5, 0.5]:
            _box(self, Vector3(0.07, 0.03, ln + 0.08), mid + right * GAUGE * side + Vector3(0, 0.03, 0), steel, yaw)
        _box(self, Vector3(0.025, 0.025, ln + 0.05), mid + Vector3(0, 6.0, 0), wire, yaw)
    # столбы контактной сети: на тротуаре слева по ходу, через ~22 м, не на перекрёстках
    var s := 6.0
    while s < total:
        var sd: Array = sample(s)
        var p: Vector3 = sd[0]
        var dir: Vector3 = sd[1]
        var near_cross := false
        for c: float in [-129.0, -43.0, 43.0, 129.0]:
            if absf(p.x - c) < 11.0 and absf(p.z) <= L + 1.0 and (absf(dir.z) > 0.5):
                near_cross = true
            if absf(p.z - c) < 11.0 and absf(p.x) <= L + 1.0 and (absf(dir.x) > 0.5):
                near_cross = true
        var stop_near := false
        for st: Dictionary in stops:
            if p.distance_to(st["pos"]) < 9.0:
                stop_near = true
        if not near_cross and not stop_near:
            var left := Vector3(dir.z, 0, -dir.x)
            var pp := p + left * 8.4
            _box(self, Vector3(0.18, 6.6, 0.18), pp + Vector3(0, 3.3, 0), pole, 0.0, true)
            var arm_len := 8.4
            _box(self, Vector3(0.06, 0.06, arm_len), (pp + p) * 0.5 + Vector3(0, 6.3, 0), wire, atan2(left.x, left.z))
        s += 21.5


# ---------------------------------------------------------------- вагон

func _spawn_car(s0: float) -> void:
    var body := AnimatableBody3D.new()
    body.sync_to_physics = false
    add_child(body)
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(WIDTH, 3.0, LEN)
    cs.shape = bs
    cs.position = Vector3(0, 1.75, 0)
    body.add_child(cs)
    _tram_mesh(body)
    var marks: Array = []
    for z: float in [LEN * 0.45, 0.0, -LEN * 0.45]:
        var m := Node3D.new()
        m.position = Vector3(0, 0, z)
        body.add_child(m)
        marks.append(m)
    cars.append({"body": body, "s": s0, "speed": 0.0, "wait": 0.0, "stop_i": -1, "marks": marks})
    if traffic != null:
        for m in marks:
            traffic.obstacles.append(m)


func _tram_mesh(body: Node3D) -> void:
    var red := _mat(Color(0.75, 0.1, 0.08), 0.45)
    var cream := _mat(Color(0.93, 0.89, 0.76), 0.5)
    var glass := _mat(Color(0.15, 0.2, 0.24), 0.08, 0.3)
    var dark := _mat(Color(0.08, 0.08, 0.09), 0.8)
    var grey := _mat(Color(0.55, 0.56, 0.58), 0.5, 0.5)
    var lamp := StandardMaterial3D.new()
    lamp.albedo_color = Color(1.0, 0.95, 0.8)
    lamp.emission_enabled = true
    lamp.emission = Color(1.0, 0.92, 0.7)
    lamp.emission_energy_multiplier = 2.0
    var half := LEN * 0.5
    _box(body, Vector3(WIDTH, 1.05, LEN - 1.0), Vector3(0, 0.95, 0), red, 0.0, true)          # низ кузова
    _box(body, Vector3(WIDTH - 0.04, 1.1, LEN - 1.1), Vector3(0, 2.0, 0), glass, 0.0, true)    # оконный пояс
    for zi in range(-6, 7, 2):
        _box(body, Vector3(WIDTH + 0.02, 1.1, 0.12), Vector3(0, 2.0, float(zi)), cream)        # стойки окон
    _box(body, Vector3(WIDTH, 0.55, LEN - 1.0), Vector3(0, 2.8, 0), cream, 0.0, true)          # верх
    _box(body, Vector3(WIDTH - 0.3, 0.25, LEN - 1.6), Vector3(0, 3.18, 0), _mat(Color(0.7, 0.7, 0.68), 0.6), 0.0, true)   # крыша
    for zs: float in [1.0, -1.0]:
        # скруглённые торцы (кабины): клин из двух коробок
        var cab := zs * (half - 0.55)
        _box(body, Vector3(WIDTH - 0.25, 1.05, 0.9), Vector3(0, 0.95, cab), red)
        _box(body, Vector3(WIDTH - 0.35, 1.1, 0.8), Vector3(0, 2.0, cab + zs * 0.02), glass)
        _box(body, Vector3(WIDTH - 0.3, 0.55, 0.85), Vector3(0, 2.8, cab), cream)
        _box(body, Vector3(1.1, 0.3, 0.05), Vector3(0, 2.85, zs * (half - 0.1)), dark)            # табло маршрута
        var num := Label3D.new()
        num.text = "1"
        num.font_size = 64
        num.pixel_size = 0.005
        num.modulate = Color(1.0, 0.85, 0.3)
        num.position = Vector3(0, 2.85, zs * (half - 0.07))
        num.rotation.y = 0.0 if zs > 0 else PI
        body.add_child(num)
        for x: float in [-0.75, 0.75]:
            _box(body, Vector3(0.22, 0.16, 0.05), Vector3(x, 0.75, zs * (half - 0.08)), lamp if zs > 0 else _mat(Color(0.8, 0.1, 0.05), 0.3))
        _box(body, Vector3(WIDTH - 0.3, 0.15, 0.15), Vector3(0, 0.38, zs * (half - 0.1)), grey)   # бампер
    # двери справа по ходу (x < 0 — правый борт при движении к +z)
    for z: float in [half - 2.0, 0.0, -half + 2.0]:
        _box(body, Vector3(0.05, 1.95, 1.2), Vector3(-WIDTH * 0.5 - 0.01, 1.4, z), _mat(Color(0.55, 0.08, 0.06), 0.5))
        _box(body, Vector3(0.06, 1.0, 0.5), Vector3(-WIDTH * 0.5 - 0.02, 1.85, z), glass)
    # тележки и колёса
    for z: float in [half - 3.2, -half + 3.2]:
        _box(body, Vector3(WIDTH - 0.5, 0.45, 2.4), Vector3(0, 0.32, z), dark)
    # пантограф
    var pz := 1.0
    _box(body, Vector3(1.2, 0.08, 0.5), Vector3(0, 3.38, pz), grey)
    for k: float in [-1.0, 1.0]:
        var arm := _box(body, Vector3(0.05, 1.6, 0.05), Vector3(0, 4.05, pz + 0.35 * k), grey)
        arm.rotation.x = 0.45 * k
    _box(body, Vector3(1.5, 0.05, 0.12), Vector3(0, 4.82, pz), grey)


func _physics_process(delta: float) -> void:
    for c: Dictionary in cars:
        var s: float = c["s"]
        var speed: float = c["speed"]
        var sd: Array = sample(s)
        var pos: Vector3 = sd[0]
        var dir: Vector3 = sd[1]
        # стоим на остановке
        if float(c["wait"]) > 0.0:
            c["wait"] = float(c["wait"]) - delta
            speed = 0.0
        else:
            var want := CRUISE
            # следующая остановка: плавно тормозим
            var to_stop := INF
            var next_i := -1
            for i in stops.size():
                var ds := fposmod(float(stops[i]["s"]) - s, total)
                if ds < to_stop and i != int(c["stop_i"]):
                    to_stop = ds
                    next_i = i
            if to_stop < 30.0:
                want = minf(want, maxf(1.5, sqrt(2.0 * 1.2 * to_stop)))
            if to_stop < 0.6:
                c["wait"] = DWELL
                c["stop_i"] = next_i
                speed = 0.0
                want = 0.0
            # повороты медленнее
            var ahead: Array = sample(s + 10.0)
            if (ahead[1] as Vector3).dot(dir) < 0.95:
                want = minf(want, 4.5)
            if _blocked(pos, dir):
                want = 0.0
            speed = move_toward(speed, want, (3.0 if want < speed else 1.2) * delta)
            if float(c["wait"]) <= 0.0 and int(c["stop_i"]) >= 0:
                var st: Dictionary = stops[int(c["stop_i"])]
                if fposmod(s - float(st["s"]), total) > 20.0:
                    c["stop_i"] = -1   # отъехали — следующую остановку снова «видим»
        s = fposmod(s + speed * delta, total)
        c["s"] = s
        c["speed"] = speed
        var body: AnimatableBody3D = c["body"]
        # кузов по хорде между тележками — плавно на поворотах
        var f: Array = sample(s + LEN * 0.3)
        var r: Array = sample(s - LEN * 0.3)
        var fp: Vector3 = f[0]
        var rp: Vector3 = r[0]
        var fwd := (fp - rp).normalized()
        body.global_transform = Transform3D(Basis(Vector3.UP, atan2(fwd.x, fwd.z)), (fp + rp) * 0.5)
        body.visible = body.global_position.distance_to(focus) < 260.0


func _blocked(pos: Vector3, dir: Vector3) -> bool:
    var right := Vector3(dir.z, 0, -dir.x)
    var check := func(o: Vector3) -> bool:
        var rel := o - pos
        var ahead := rel.dot(dir)
        return ahead > LEN * 0.5 and ahead < LEN * 0.5 + 9.0 and absf(rel.dot(right)) < 2.2
    for o in obstacles:
        if not is_instance_valid(o) or not o.visible:
            continue
        var par: Node = (o as Node).get_parent()
        if par != null and par.get_parent() == self:
            continue   # свои точки вагонов
        if check.call((o as Node3D).global_position):
            return true
    if traffic != null:
        for a: Dictionary in traffic._agents:
            if check.call(a["pos"]):
                return true
    for c2: Dictionary in cars:
        var b: Node3D = c2["body"]
        var rel := b.global_position - pos
        if rel.dot(dir) > LEN * 0.6 and rel.dot(dir) < LEN + 12.0 and absf(rel.dot(right)) < 2.0:
            return true
    return false


# ---------------------------------------------------------------- для main.gd

## Вагон, стоящий сейчас на остановке i (или null).
func car_at_stop(i: int):
    for c: Dictionary in cars:
        if int(c["stop_i"]) == i and float(c["wait"]) > 0.0:
            return c
    return null


## Через сколько секунд (примерно) придёт ближайший вагон к остановке i.
func eta(i: int) -> float:
    var best := INF
    for c: Dictionary in cars:
        var ds := fposmod(float(stops[i]["s"]) - float(c["s"]), total)
        best = minf(best, ds / CRUISE + DWELL * 0.5)
    return best


func hold(c: Dictionary, secs: float) -> void:
    c["wait"] = maxf(float(c["wait"]), secs)
