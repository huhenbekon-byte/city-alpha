extends RefCounted
## Модель машины из примитивов, склеенная в один меш (мало draw calls —
## важно для телефона). Общая для ездящих и припаркованных машин.
## Перед машины смотрит в +Z — так устроен VehicleBody3D в Godot.

const BodyMesh := preload("res://scripts/body_mesh.gd")
const WHEEL_RADIUS := 0.31
const WHEEL_X := 0.72
const WHEEL_Z := 1.28

static var _shared := {}


## Коллизия кузова. kind: "car", "bus", "truck".
static func add_collision(body: CollisionObject3D, kind := "car") -> void:
    match kind:
        "moto":
            _shape(body, Vector3(0.6, 0.8, 2.0), Vector3(0, 0.75, 0))
        "bus":
            _shape(body, Vector3(2.5, 2.7, 10.0), Vector3(0, 1.85, 0))
        "truck":
            _shape(body, Vector3(2.4, 2.4, 2.4), Vector3(0, 1.75, 3.6))
            _shape(body, Vector3(2.5, 2.8, 6.4), Vector3(0, 2.1, -1.1))
        _:
            _shape(body, Vector3(1.62, 0.6, 4.0), Vector3(0, 0.68, 0))
            _shape(body, Vector3(1.44, 0.44, 1.7), Vector3(0, 1.2, -0.15))


## Кузов без колёс (для ездящей машины). tail — материал стоп-сигналов.
static func body_mesh(paint: Color, tail: Material, kind := "car") -> ArrayMesh:
    match kind:
        "moto":
            return _merge(_moto_parts(paint, tail))
        "bus":
            return _merge(_bus_parts(paint, tail))
        "truck":
            return _merge(_truck_parts(paint, tail))
    return _merge(_body_parts(paint, tail))


static func wheel_radius(kind: String) -> float:
    if kind == "moto":
        return 0.33
    return WHEEL_RADIUS if kind == "car" else 0.5


## Где колёса: [[позиция крепления, передняя?], ...].
static func wheel_spots(kind: String) -> Array:
    var out := []
    match kind:
        "moto":   # физически 4 колеса рядом (так мотоцикл не падает), выглядят как 2 широких
            for x: float in [0.09, -0.09]:
                out.append([Vector3(x, 0.4, 0.72), true])
                out.append([Vector3(x, 0.4, -0.72), false])
        "bus":
            for x: float in [1.05, -1.05]:
                out.append([Vector3(x, 0.62, 3.6), true])
                out.append([Vector3(x, 0.62, -3.4), false])
        "truck":
            for x: float in [1.0, -1.0]:
                out.append([Vector3(x, 0.62, 3.4), true])
                out.append([Vector3(x, 0.62, -1.8), false])
                out.append([Vector3(x, 0.62, -3.2), false])
        _:
            for x: float in [WHEEL_X, -WHEEL_X]:
                out.append([Vector3(x, 0.42, WHEEL_Z), true])
                out.append([Vector3(x, 0.42, -WHEEL_Z), false])
    return out


## Колесо: ось вдоль X, центр в начале координат. Один общий меш на всех.
static func wheel_mesh() -> ArrayMesh:
    if not _shared.has("wheel_mesh"):
        _shared["wheel_mesh"] = _merge(_wheel_parts(Transform3D()))
    return _shared["wheel_mesh"]


## Целая машина с колёсами — для припаркованных (MultiMesh).
static func parked_mesh(paint: Color, model_id := "") -> ArrayMesh:
    if has_model(model_id):
        var mm := model_mesh(model_id, paint)
        if mm:
            return mm
    var tail := _mat("tail_static", Color(0.55, 0.04, 0.04), 0.3, 0.0, 0.3)
    if tail.albedo_texture == null and _textured(tail, "car_taillight"):
        tail.albedo_color = Color(1, 1, 1)
    var parts := _body_parts(paint, tail)
    for x: float in [WHEEL_X, -WHEEL_X]:
        for z: float in [WHEEL_Z, -WHEEL_Z]:
            parts.append_array(_wheel_parts(Transform3D(Basis(), Vector3(x, WHEEL_RADIUS, z))))
    return _merge(parts)


## Ночью фары и задние фонари всех машин светятся ярче (0 — день, 1 — ночь).
static func set_night(k: float) -> void:
    _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6).emission_energy_multiplier = lerpf(0.6, 4.0, k)
    _mat("tail_static", Color(0.55, 0.04, 0.04), 0.3, 0.0, 0.3).emission_energy_multiplier = lerpf(0.3, 1.6, k)


## Отдельный материал стоп-сигналов: у каждой ездящей машины свой.
static func make_tail_material() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    _textured(m, "car_taillight")
    m.albedo_color = Color(1, 1, 1) if m.albedo_texture else Color(0.55, 0.04, 0.04)
    m.roughness = 0.3
    m.emission_enabled = true
    m.emission = Color(1.0, 0.08, 0.05)
    m.emission_energy_multiplier = 0.3
    return m


# ---------------------------------------------------------------- детали

static func _body_parts(paint: Color, tail: Material) -> Array:
    var body := _mat("paint_" + paint.to_html(), paint, 0.35, 0.3)
    var dark := _mat("dark", Color(0.07, 0.07, 0.08), 0.7)
    var glass := _mat("glass", Color(0.09, 0.12, 0.16), 0.05, 0.6)
    var chrome := _mat("chrome", Color(0.72, 0.72, 0.75), 0.25, 0.9)
    var plate := _mat("plate", Color(0.95, 0.95, 0.95), 0.6)
    var head := _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6)
    # Текстуры из textures/car_*.png (если есть): краска с блёстками, пластик, стекло,
    # фары, решётка, фонари, номера, швы дверей.
    if body.albedo_texture == null:
        _textured(body, "car_paint", 1.2)
    if dark.albedo_texture == null:
        _textured(dark, "car_plastic", 2.0)
    if glass.albedo_texture == null and _textured(glass, "car_glass", 0.8):
        glass.albedo_color = Color(1, 1, 1)
    if head.albedo_texture == null and _textured(head, "car_headlight"):
        head.albedo_color = Color(1, 1, 1)
    if plate.albedo_texture == null and _textured(plate, "car_plate"):
        plate.albedo_color = Color(1, 1, 1)
    var grille := _mat("grille", Color(0.6, 0.6, 0.62), 0.3, 0.6)
    var detailed := _textured(grille, "car_grille") or grille.albedo_texture != null
    var side := _mat("car_side", Color(0, 0, 0), 0.6)
    if side.albedo_texture == null and _textured(side, "car_side"):
        side.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        side.uv1_scale = Vector3(2, 1, 1)   # две двери на бок
        side.albedo_color = Color(0, 0, 0, 0.85)

    var p := []
    # Кузов из профиля сбоку: капот, лобовое, крыша, заднее стекло, багажник.
    if not _shared.has("car_shell"):
        _shared["car_shell"] = BodyMesh.extrude(PackedVector2Array([
                Vector2(2.0, 0.40), Vector2(2.0, 0.88), Vector2(1.88, 0.94), Vector2(0.95, 0.99),
                Vector2(-1.25, 0.99), Vector2(-1.9, 0.96), Vector2(-2.0, 0.90), Vector2(-2.0, 0.40)]),
                0.81, 0.77, 0.86, 0.99)
        _shared["car_cabin"] = BodyMesh.extrude(PackedVector2Array([
                Vector2(0.97, 0.96), Vector2(0.30, 1.40), Vector2(-0.75, 1.43), Vector2(-1.30, 0.96)]),
                0.76, 0.64, 0.96, 1.43)
        _shared["car_roof"] = BodyMesh.extrude(PackedVector2Array([
                Vector2(0.34, 1.375), Vector2(0.26, 1.455), Vector2(-0.78, 1.48), Vector2(-0.82, 1.40)]),
                0.665, 0.65, 1.37, 1.48)
    p.append([_shared["car_shell"], Transform3D(), body])
    p.append([_shared["car_cabin"], Transform3D(), glass])
    p.append([_shared["car_roof"], Transform3D(), body])
    _bx(p, Vector3(1.64, 0.07, 4.02), Vector3(0, 0.6, 0), dark)      # молдинг
    for sx: float in [-1.0, 1.0]:
        _slant(p, Vector2(0.97, 0.96), Vector2(0.30, 1.40), 0.70 * sx, body)    # стойка A вдоль лобового
        _bx(p, Vector3(0.05, 0.44, 0.1), Vector3(0.70 * sx, 1.18, -0.15), body)  # стойка B
        _slant(p, Vector2(-0.75, 1.43), Vector2(-1.30, 0.96), 0.70 * sx, body)  # стойка C вдоль заднего
        _bx(p, Vector3(0.12, 0.10, 0.07), Vector3(0.84 * sx, 1.05, 0.62), dark)   # зеркала
    if detailed:   # плоские «наклейки» с картинками
        _qd(p, Vector2(0.86, 0.22), Vector3(0, 0.82, 2.004), 0.0, grille)
        for sx: float in [-1.0, 1.0]:
            _qd(p, Vector2(0.28, 0.22), Vector3(0.60 * sx, 0.82, 2.006), 0.0, head)
            _qd(p, Vector2(0.34, 0.22), Vector3(0.58 * sx, 0.82, -2.006), PI, tail)
            _qd(p, Vector2(3.9, 0.56), Vector3(0.812 * sx, 0.70, 0), PI * 0.5 * sx, side)
        for sz: float in [-1.0, 1.0]:
            _bx(p, Vector3(1.68, 0.16, 0.14), Vector3(0, 0.46, 2.02 * sz), chrome)
            _qd(p, Vector2(0.52, 0.13), Vector3(0, 0.46, 2.092 * sz), 0.0 if sz > 0.0 else PI, plate)
    else:
        _bx(p, Vector3(0.7, 0.14, 0.03), Vector3(0, 0.8, 2.005), dark)   # решётка
        for sx: float in [-1.0, 1.0]:
            _bx(p, Vector3(0.30, 0.14, 0.03), Vector3(0.55 * sx, 0.80, 2.005), head)  # фары
            _bx(p, Vector3(0.36, 0.13, 0.03), Vector3(0.54 * sx, 0.82, -2.005), tail) # фонари
        for sz: float in [-1.0, 1.0]:
            _bx(p, Vector3(1.68, 0.16, 0.14), Vector3(0, 0.46, 2.02 * sz), chrome)    # бампер
            _bx(p, Vector3(0.50, 0.11, 0.02), Vector3(0, 0.46, 2.10 * sz), plate)     # номер
    return p


static func _moto_parts(paint: Color, tail: Material) -> Array:
    var body := _mat("paint_" + paint.to_html(), paint, 0.3, 0.4)
    var dark := _mat("dark", Color(0.07, 0.07, 0.08), 0.7)
    var chrome := _mat("chrome", Color(0.72, 0.72, 0.75), 0.25, 0.9)
    var head := _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6)
    var p := []
    _bx(p, Vector3(0.14, 0.14, 1.3), Vector3(0, 0.55, 0.0), dark)       # рама
    _bx(p, Vector3(0.32, 0.26, 0.55), Vector3(0, 0.88, 0.22), body)     # бак
    _bx(p, Vector3(0.28, 0.12, 0.7), Vector3(0, 0.86, -0.3), dark)      # сиденье
    _bx(p, Vector3(0.24, 0.2, 0.4), Vector3(0, 0.72, -0.68), body)      # хвост
    _bx(p, Vector3(0.36, 0.3, 0.4), Vector3(0, 0.5, -0.05), chrome)     # мотор
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.04, 0.6, 0.04), Vector3(0.1 * sx, 0.68, 0.66), chrome)   # вилка
    _bx(p, Vector3(0.7, 0.04, 0.04), Vector3(0, 1.05, 0.58), dark)      # руль
    _bx(p, Vector3(0.18, 0.16, 0.08), Vector3(0, 0.92, 0.78), head)     # фара
    _bx(p, Vector3(0.14, 0.08, 0.04), Vector3(0, 0.78, -0.89), tail)    # фонарь
    _bx(p, Vector3(0.08, 0.08, 0.5), Vector3(0.18, 0.42, -0.5), chrome) # выхлоп
    return p


# ---------------------------------------------------------------- мопед «Вятка» (прокат у вокзала)
## Мотороллер в духе «Вятки ВП-150»: обтекаемый кузов, широкий щит для ног, круглая фара на руле.
## Двухцветный: основной цвет + кремовые щит, крылья и полоса. Вперёд +Z, земля y=0.
const SCOOTER_R := 0.22          # маленькие колёса
const SCOOTER_Z := 0.62          # колёса спереди/сзади от центра
const SCOOTER_SEAT := Vector3(0, 0.84, -0.40)   # где сидит водитель (таз)


static func _ell(parts: Array, r: Vector3, pos: Vector3, mat: Material, tilt := 0.0, segs := 16) -> void:
    var m := SphereMesh.new()
    m.radius = 1.0
    m.height = 2.0
    m.radial_segments = segs
    m.rings = maxi(segs / 2, 6)
    var b := Basis(Vector3.RIGHT, tilt) * Basis.from_scale(r)
    parts.append([m, Transform3D(b, pos), mat])


static func _cyl(parts: Array, r: float, a: Vector3, b: Vector3, mat: Material, segs := 12) -> void:
    var d := b - a
    var m := CylinderMesh.new()
    m.top_radius = r
    m.bottom_radius = r
    m.height = d.length()
    m.radial_segments = segs
    m.rings = 1
    var y := d.normalized()
    var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
    var z := x.cross(y)
    parts.append([m, Transform3D(Basis(x, y, z), (a + b) * 0.5), mat])


static func _scooter_parts(paint: Color, tail: Material) -> Array:
    var body := _mat("scoot_" + paint.to_html(), paint, 0.28, 0.25)
    var cream := _mat("scoot_cream", Color(0.93, 0.89, 0.78), 0.32, 0.15)
    var dark := _mat("dark", Color(0.07, 0.07, 0.08), 0.7)
    var rubber := _mat("scoot_rubber", Color(0.12, 0.12, 0.12), 0.9)
    var seat := _mat("scoot_seat", Color(0.28, 0.16, 0.10), 0.55)
    var chrome := _mat("chrome", Color(0.72, 0.72, 0.75), 0.25, 0.9)
    var head := _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6)
    var p := []
    # задний обтекатель над мотором — главный «пузатый» объём
    _ell(p, Vector3(0.27, 0.25, 0.50), Vector3(0, 0.52, -0.38), body, 0.08, 20)
    _ell(p, Vector3(0.25, 0.16, 0.46), Vector3(0, 0.40, -0.36), body, 0.0, 16)
    # хромированная полоса по бортам обтекателя и решётка вентиляции
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.02, 0.025, 0.46), Vector3(0.266 * sx, 0.52, -0.38), chrome)
        for k in 3:
            _bx(p, Vector3(0.012, 0.012, 0.14), Vector3(0.262 * sx, 0.44 - k * 0.035, -0.50), chrome)
    # сиденье: длинное, двухместное, коричневое с кантом
    _ell(p, Vector3(0.17, 0.07, 0.42), Vector3(0, 0.78, -0.30), seat, 0.0, 14)
    _bx(p, Vector3(0.30, 0.04, 0.70), Vector3(0, 0.735, -0.30), dark)
    _bx(p, Vector3(0.36, 0.03, 0.06), Vector3(0, 0.80, -0.78), chrome)   # поручень пассажира
    # пол-площадка для ног
    _bx(p, Vector3(0.36, 0.07, 0.62), Vector3(0, 0.27, 0.12), body)
    for i in 5:
        _bx(p, Vector3(0.30, 0.012, 0.03), Vector3(0, 0.31, -0.10 + i * 0.11), rubber)   # резиновые полосы
    # щит для ног (выгнутый), кремовый, с хромированной окантовкой
    _ell(p, Vector3(0.30, 0.42, 0.06), Vector3(0, 0.62, 0.45), cream, -0.22, 20)
    _ell(p, Vector3(0.315, 0.435, 0.05), Vector3(0, 0.62, 0.42), body, -0.22, 20)   # изнанка щита и кант
    # переднее крыло над колесом
    _ell(p, Vector3(0.085, 0.10, 0.25), Vector3(0, SCOOTER_R + 0.09, SCOOTER_Z + 0.02), cream, 0.0, 14)
    # рулевая колонка и «голова» руля с фарой
    _cyl(p, 0.045, Vector3(0, 0.30, SCOOTER_Z - 0.04), Vector3(0, 1.00, 0.50), body)
    _ell(p, Vector3(0.18, 0.09, 0.12), Vector3(0, 1.02, 0.50), body, 0.0, 14)
    _cyl(p, 0.075, Vector3(0, 1.03, 0.56), Vector3(0, 1.03, 0.63), chrome, 16)    # ободок фары
    _cyl(p, 0.062, Vector3(0, 1.03, 0.62), Vector3(0, 1.03, 0.635), head, 16)     # фара
    _cyl(p, 0.016, Vector3(-0.36, 1.02, 0.47), Vector3(0.36, 1.02, 0.47), chrome) # руль
    for sx: float in [-1.0, 1.0]:
        _cyl(p, 0.022, Vector3(0.28 * sx, 1.02, 0.47), Vector3(0.40 * sx, 1.02, 0.47), rubber)   # ручки
        _cyl(p, 0.008, Vector3(0.22 * sx, 1.04, 0.47), Vector3(0.27 * sx, 1.15, 0.45), chrome)   # зеркала
        _ell(p, Vector3(0.045, 0.032, 0.012), Vector3(0.28 * sx, 1.17, 0.45), chrome)
    # задний фонарь и номер
    _ell(p, Vector3(0.06, 0.04, 0.03), Vector3(0, 0.62, -0.87), tail, 0.0, 10)
    _bx(p, Vector3(0.18, 0.10, 0.01), Vector3(0, 0.48, -0.86), _mat("plate_w", Color(0.92, 0.92, 0.9), 0.6))
    # выхлоп справа снизу, подножка
    _cyl(p, 0.035, Vector3(0.16, 0.20, -0.30), Vector3(0.16, 0.24, -0.70), chrome)
    return p


## Готовая модель мотороллера (models/cars/vespa.gltf): узлы Body, Wheel_F, Wheel_R, материал Paint красится.
## Нет файла — мопед строится из простых фигур (_scooter_parts).
const VESPA_PATH := "res://models/cars/vespa.gltf"


static func _vespa() -> Dictionary:
    if _shared.has("vespa"):
        return _shared["vespa"]
    var out := {}
    if ResourceLoader.exists(VESPA_PATH):
        var ps = load(VESPA_PATH)
        if ps is PackedScene:
            var root: Node = (ps as PackedScene).instantiate()
            for n: Node in root.find_children("*", "MeshInstance3D", true, false):
                var mi := n as MeshInstance3D
                out[String(mi.name)] = mi.mesh
                out[String(mi.name) + "_pos"] = _rel(mi, root).origin
            root.free()
    if not (out.has("Body") and out.has("Wheel_F") and out.has("Wheel_R")):
        out = {}
    _shared["vespa"] = out
    return out


## Кузов мотороллера нужного цвета: копия меша, у поверхности Paint — свой материал.
static func _vespa_body(paint: Color) -> ArrayMesh:
    var key := "vespa_body_" + paint.to_html()
    if _shared.has(key):
        return _shared[key]
    var src: Mesh = _vespa()["Body"]
    var out := ArrayMesh.new()
    for i in src.get_surface_count():
        out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
        var m := src.surface_get_material(i)
        if _role(m) == "Paint":
            m = paint_material(m, paint)
        out.surface_set_material(i, m)
    _shared[key] = out
    return out


## Колесо мотороллера: шина, хромированный колпак. Ось вдоль X. У модели — своё переднее/заднее.
static func scooter_wheel_mesh(front := true) -> Mesh:
    var v := _vespa()
    if not v.is_empty():
        return v["Wheel_F" if front else "Wheel_R"]
    if _shared.has("scooter_wheel"):
        return _shared["scooter_wheel"]
    var tire := _mat("tire", Color(0.08, 0.08, 0.08), 0.9)
    var chrome := _mat("chrome", Color(0.72, 0.72, 0.75), 0.25, 0.9)
    var p := []
    var ax := Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)
    var tm := CylinderMesh.new()
    tm.top_radius = SCOOTER_R
    tm.bottom_radius = SCOOTER_R
    tm.height = 0.11
    tm.radial_segments = 18
    tm.rings = 1
    p.append([tm, ax, tire])
    var rm := CylinderMesh.new()
    rm.top_radius = 0.12
    rm.bottom_radius = 0.12
    rm.height = 0.12
    rm.radial_segments = 14
    rm.rings = 1
    p.append([rm, ax, chrome])
    var sp := BoxMesh.new()      # тёмная полоса — видно вращение
    sp.size = Vector3(0.125, 0.03, 0.2)
    p.append([sp, Transform3D(), tire])
    var m := _merge(p)
    _shared["scooter_wheel"] = m
    return m


## Кузов мопеда без колёс (для ездящего).
static func scooter_mesh(paint: Color, tail: Material) -> ArrayMesh:
    if not _vespa().is_empty():
        return _vespa_body(paint)
    return _merge(_scooter_parts(paint, tail))


## Стоящий мопед целиком (с колёсами) — для витрины проката.
static func scooter_parked_mesh(paint: Color) -> ArrayMesh:
    var v := _vespa()
    if not v.is_empty():
        var vp := []
        var body := _vespa_body(paint)
        for nm: String in ["Body", "Wheel_F", "Wheel_R"]:
            var msh: Mesh = body if nm == "Body" else v[nm]
            for si in msh.get_surface_count():
                var one := ArrayMesh.new()
                one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, msh.surface_get_arrays(si))
                vp.append([one, Transform3D(Basis(), v[nm + "_pos"]), msh.surface_get_material(si)])
        return _merge(vp)
    var tail := _mat("tail_static", Color(0.55, 0.04, 0.04), 0.3, 0.0, 0.3)
    var parts := _scooter_parts(paint, tail)
    var wm := scooter_wheel_mesh()
    # колесо — готовый меш с двумя материалами: добавляем его поверхности по отдельности
    for z: float in [SCOOTER_Z, -SCOOTER_Z]:
        for si in wm.get_surface_count():
            var one := ArrayMesh.new()
            one.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, wm.surface_get_arrays(si))
            parts.append([one, Transform3D(Basis(), Vector3(0, SCOOTER_R, z)), wm.surface_get_material(si)])
    return _merge(parts)


## Общий материал стёкол (чтобы машина могла заменить его на тонировку).
static func glass_material() -> StandardMaterial3D:
    return _mat("glass", Color(0.09, 0.12, 0.16), 0.05, 0.6)


static func rim_material() -> StandardMaterial3D:
    return _mat("rim", Color(0.70, 0.70, 0.72), 0.3, 0.8)


static func _bus_parts(paint: Color, tail: Material) -> Array:
    var body := _mat("paint_" + paint.to_html(), paint, 0.4, 0.2)
    var dark := _mat("dark", Color(0.07, 0.07, 0.08), 0.7)
    var glass := _mat("glass", Color(0.09, 0.12, 0.16), 0.05, 0.6)
    var head := _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6)
    var p := []
    _bx(p, Vector3(2.5, 2.7, 10.0), Vector3(0, 1.85, 0), body)
    _bx(p, Vector3(2.52, 0.9, 8.6), Vector3(0, 2.4, -0.4), glass)      # окна по бокам
    _bx(p, Vector3(2.2, 1.1, 0.04), Vector3(0, 2.3, 5.01), glass)      # лобовое
    _bx(p, Vector3(2.52, 0.12, 10.02), Vector3(0, 1.3, 0), dark)       # полоса
    _bx(p, Vector3(0.04, 2.0, 1.1), Vector3(-1.26, 1.5, 3.8), glass)   # двери справа по ходу
    _bx(p, Vector3(0.04, 2.0, 1.1), Vector3(-1.26, 1.5, -0.5), glass)
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.35, 0.2, 0.03), Vector3(0.85 * sx, 0.9, 5.01), head)
        _bx(p, Vector3(0.3, 0.3, 0.03), Vector3(0.95 * sx, 1.0, -5.01), tail)
    _bx(p, Vector3(2.0, 0.4, 0.05), Vector3(0, 3.0, 5.01), dark)        # табло маршрута
    # Рабочий жёлтый автобус — с картинками: борта с окнами, двери, перед
    var yellow := paint.r > 0.8 and paint.g > 0.6 and paint.b < 0.4
    if yellow and _tex("bus_side") != null:
        var side := _mat("bus_side", Color.WHITE, 0.6)
        if side.albedo_texture == null:
            _textured(side, "bus_side")
            side.uv1_scale = Vector3(3, 1, 1)
        var door := _mat("bus_door", Color.WHITE, 0.4)
        if door.albedo_texture == null:
            _textured(door, "bus_door")
        var front := _mat("bus_front", Color.WHITE, 0.5)
        if front.albedo_texture == null:
            _textured(front, "bus_front")
        for sx: float in [-1.0, 1.0]:
            _qd(p, Vector2(9.6, 2.5), Vector3(1.275 * sx, 1.85, 0), PI * 0.5 * sx, side)
        for dz: float in [3.8, -0.5]:
            _qd(p, Vector2(1.2, 2.3), Vector3(-1.285, 1.55, dz), -PI * 0.5, door)
        _qd(p, Vector2(2.5, 2.7), Vector3(0, 1.85, 5.03), 0.0, front)
    return p


static func _truck_parts(paint: Color, tail: Material) -> Array:
    var body := _mat("paint_" + paint.to_html(), paint, 0.4, 0.3)
    var dark := _mat("dark", Color(0.07, 0.07, 0.08), 0.7)
    var glass := _mat("glass", Color(0.09, 0.12, 0.16), 0.05, 0.6)
    var head := _mat("head", Color(1.0, 0.96, 0.85), 0.2, 0.0, 0.6)
    var cargo := _mat("cargo", Color(0.85, 0.85, 0.82), 0.8)
    var p := []
    _bx(p, Vector3(2.4, 2.4, 2.4), Vector3(0, 1.75, 3.6), body)        # кабина
    _bx(p, Vector3(2.2, 0.9, 0.04), Vector3(0, 2.3, 4.81), glass)
    _bx(p, Vector3(2.42, 0.8, 1.6), Vector3(0, 2.3, 3.7), glass)
    _bx(p, Vector3(1.4, 0.4, 9.0), Vector3(0, 0.75, 0.0), dark)         # рама
    _bx(p, Vector3(2.5, 2.8, 6.4), Vector3(0, 2.1, -1.1), cargo)       # фургон
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.35, 0.2, 0.03), Vector3(0.8 * sx, 1.0, 4.81), head)
        _bx(p, Vector3(0.3, 0.25, 0.03), Vector3(0.95 * sx, 0.9, -4.31), tail)
    # Картинки: кабина спереди (в цвет машины), борта и двери фургона
    if _tex("truck_front") != null:
        var cab := _mat("truck_front_" + paint.to_html(), paint.lightened(0.45), 0.5)
        if cab.albedo_texture == null:
            _textured(cab, "truck_front")
        var side := _mat("cargo_side", Color.WHITE, 0.6)
        if side.albedo_texture == null:
            _textured(side, "cargo_side")
            side.uv1_scale = Vector3(2, 1, 1)
        var rear := _mat("cargo_rear", Color.WHITE, 0.6)
        if rear.albedo_texture == null:
            _textured(rear, "cargo_rear")
        _qd(p, Vector2(2.4, 2.4), Vector3(0, 1.75, 4.83), 0.0, cab)
        for sx: float in [-1.0, 1.0]:
            _qd(p, Vector2(6.4, 2.8), Vector3(1.258 * sx, 2.1, -1.1), PI * 0.5 * sx, side)
        _qd(p, Vector2(2.5, 2.8), Vector3(0, 2.1, -4.32), PI, rear)
    return p


static func _wheel_parts(xf: Transform3D) -> Array:
    var tire := _mat("tire", Color(0.08, 0.08, 0.08), 0.9)
    var rim := _mat("rim", Color(0.70, 0.70, 0.72), 0.3, 0.8)
    var axle := xf * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3.ZERO)

    var tm := CylinderMesh.new()
    tm.top_radius = WHEEL_RADIUS
    tm.bottom_radius = WHEEL_RADIUS
    tm.height = 0.2
    tm.radial_segments = 16
    tm.rings = 1
    var rm := CylinderMesh.new()
    rm.top_radius = 0.17
    rm.bottom_radius = 0.17
    rm.height = 0.21
    rm.radial_segments = 12
    rm.rings = 1
    var spoke := BoxMesh.new()  # тёмная полоса на диске — видно, что колесо крутится
    spoke.size = Vector3(0.215, 0.05, 0.3)

    var parts := [[tm, axle, tire], [rm, axle, rim], [spoke, xf, tire]]
    # Диск колеса с картинки: две плоские «наклейки» по бокам
    var disc := _mat("wheel_disc", Color(1, 1, 1), 0.6)
    if disc.albedo_texture != null or _textured(disc, "car_wheel"):
        disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        disc.alpha_scissor_threshold = 0.5
        var q := QuadMesh.new()
        q.size = Vector2.ONE * WHEEL_RADIUS * 2.0
        for sx: float in [-1.0, 1.0]:
            parts.append([q, xf * Transform3D(Basis(Vector3.UP, PI * 0.5 * sx), Vector3(0.102 * sx, 0, 0)), disc])
    return parts


# ---------------------------------------------------------------- помощники

static func _qd(parts: Array, size: Vector2, pos: Vector3, yaw: float, mat: Material) -> void:
    var q := QuadMesh.new()
    q.size = size
    parts.append([q, Transform3D(Basis(Vector3.UP, yaw), pos), mat])


## Текстура из textures/<name>.png с мипмапами (null — файла нет).
static func _tex(tex_name: String) -> Texture2D:
    var key := "tex_" + tex_name
    if not _shared.has(key):
        var path := "res://textures/%s.png" % tex_name
        var t: Texture2D = null
        if ResourceLoader.exists(path):
            t = load(path)
            var img := t.get_image()
            if img:
                if img.is_compressed():
                    img.decompress()
                img.generate_mipmaps()
                t = ImageTexture.create_from_image(img)
        _shared[key] = t
    return _shared[key]


## Наложить текстуру на материал. triplanar > 0 — по координатам машины (повтор на 1/triplanar м).
static func _textured(m: StandardMaterial3D, tex_name: String, triplanar := 0.0) -> bool:
    var t := _tex(tex_name)
    if t == null:
        return false
    m.albedo_texture = t
    if triplanar > 0.0:
        m.uv1_triplanar = true
        m.uv1_scale = Vector3.ONE * triplanar
    return true


## Тонкая стойка между двумя точками профиля (z, y) на боковой стороне x.
static func _slant(parts: Array, a: Vector2, b: Vector2, x: float, mat: Material) -> void:
    var d := b - a
    var L := d.length()
    var m := BoxMesh.new()
    m.size = Vector3(0.05, 0.06, L)
    # локальная ось Z детали — вдоль отрезка: (0, -sin t, cos t) = (0, dy, dz) / L
    var t := atan2(-d.y / L, d.x / L)
    var mid := (a + b) * 0.5
    parts.append([m, Transform3D(Basis(Vector3.RIGHT, t), Vector3(x, mid.y, mid.x)), mat])


static func _bx(parts: Array, size: Vector3, pos: Vector3, mat: Material) -> void:
    var m := BoxMesh.new()
    m.size = size
    parts.append([m, Transform3D(Basis(), pos), mat])


## Склеивает детали в один ArrayMesh: по одной поверхности на материал.
static func _merge(parts: Array) -> ArrayMesh:
    var tools := {}
    for part: Array in parts:
        var mat: Material = part[2]
        if not tools.has(mat):
            var st_new := SurfaceTool.new()
            st_new.begin(Mesh.PRIMITIVE_TRIANGLES)
            st_new.set_material(mat)
            tools[mat] = st_new
        var st: SurfaceTool = tools[mat]
        st.append_from(part[0], 0, part[1])
    var out := ArrayMesh.new()
    for mat: Material in tools:
        var st: SurfaceTool = tools[mat]
        st.commit(out)
    return out


static func _mat(key: String, col: Color, rough: float, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
    if _shared.has(key):
        return _shared[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = rough
    m.metallic = metal
    if emit > 0.0:
        m.emission_enabled = true
        m.emission = col
        m.emission_energy_multiplier = emit
    _shared[key] = m
    return m


static func _shape(body: CollisionObject3D, size: Vector3, pos: Vector3) -> void:
    var s := BoxShape3D.new()
    s.size = size
    var c := CollisionShape3D.new()
    c.shape = s
    c.position = pos
    body.add_child(c)


# ================================================================ готовые 3D-модели машин (models/cars)
## Конвертированы из бесплатных моделей: вперёд +Z, земля y=0, узлы Body, Wheel_FL/FR/RL/RR,
## метки Side (борт для надписей), Roof (крыша для мигалки), PlateF/PlateR (номера).
## Материалы с ролями: Paint (красится), Glass (тонировка), Tail (стоп-сигналы), Rim / M_Grey (диски).
const MODELS := {
    "vaz2106": "res://models/cars/vaz2106.gltf",   # ВАЗ-2106 (бесплатная модель с CGTrader)
    # Советские машины с Sketchfab (CC-BY 4.0, авторы — в models/cars/LICENSE.txt).
    # Старые ключи (sedan, hatch, suv...) теперь ведут на советские модели — так
    # они сразу появились в трафике, у фракций и на рынке.
    "vaz2101": "res://models/cars/vaz2101.gltf",   # ВАЗ-2101 «Копейка»
    "vaz2108": "res://models/cars/vaz2108.gltf",   # ВАЗ-2108 «Восьмёрка»
    "moskvich": "res://models/cars/moskvich.gltf", # Москвич-412
    "uaz469": "res://models/cars/uaz469.gltf",     # УАЗ-469
    "gaz53": "res://models/cars/gaz53.gltf",       # ГАЗ-53 (грузовик)
    "zil130": "res://models/cars/zil130.gltf",     # ЗИЛ-130 (грузовик)
    "laz695": "res://models/cars/laz695.gltf",     # ЛАЗ-695 (автобус)
    "izh": "res://models/cars/izh.gltf",           # ИЖ Планета-2 (мотоцикл, без отдельных колёс)
    "sedan": "res://models/cars/moskvich.gltf",
    "hatch": "res://models/cars/vaz2108.gltf",
    "sport": "res://models/cars/vaz2108.gltf",
    "coupe": "res://models/cars/vaz2101.gltf",
    "suv": "res://models/cars/uaz469.gltf",
    "taxi": "res://models/cars/vaz2101.gltf",
    "cop": "res://models/cars/vaz2101_mil.gltf",
    "uaz452": "res://models/cars/uaz452.gltf",     # УАЗ-452 «буханка» (OpenGameArt, красится под службы)
    "uaz452n": "res://models/cars/uaz452n.gltf",   # УАЗ-452 «буханка» хаки (Sketchfab, CC-BY)
    "vaz2101_mil": "res://models/cars/vaz2101_mil.gltf",   # ВАЗ-2101 «Милиция» (раскраска в модели)
    "niva": "res://models/cars/niva.gltf",         # ВАЗ-2121 «Нива»
    "volga": "res://models/cars/volga.gltf",       # ГАЗ-3102 «Волга»
    "uaz_gas": "res://models/cars/uaz_gas.gltf",   # УАЗ-452 «Аварийная газовая служба 04»
}

static var _model_scenes := {}
static var _model_infos := {}
static var _model_meshes := {}


static func has_model(id: String) -> bool:
    return id != "" and MODELS.has(id) and ResourceLoader.exists(MODELS[id])


static func model_instance(id: String) -> Node3D:
    if not has_model(id):
        return null
    if not _model_scenes.has(id):
        _model_scenes[id] = load(MODELS[id])
    var ps: PackedScene = _model_scenes[id]
    if ps == null:
        return null
    var root := ps.instantiate() as Node3D
    # У некоторых моделей (ВАЗ-2106) часть граней смотрит внутрь: заднее стекло и детали
    # пропадали. Рисуем материалы с двух сторон.
    for n: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        if mi.mesh == null:
            continue
        for i in mi.mesh.get_surface_count():
            var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
            if m:
                m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return root


## Положение узла относительно корня модели (модель ещё не в дереве сцены).
static func _rel(n: Node3D, root: Node) -> Transform3D:
    var t := n.transform
    var p := n.get_parent()
    while p != null and p != root:
        if p is Node3D:
            t = (p as Node3D).transform * t
        p = p.get_parent()
    return t


## {"wheels": {"Wheel_FL": Vector3, ...}, "radius", "side": Vector3, "roof": Vector3, "plates": {...}}
static func model_info(id: String) -> Dictionary:
    if _model_infos.has(id):
        return _model_infos[id]
    var info := {}
    var root := model_instance(id)
    if root:
        var wheels := {}
        var plates := {}
        var radius := WHEEL_RADIUS
        for n: Node in root.find_children("*", "Node3D", true, false):
            var nm := String(n.name)
            var pos := _rel(n as Node3D, root).origin
            if nm.begins_with("Wheel_"):
                wheels[nm] = pos
                if n is MeshInstance3D and (n as MeshInstance3D).mesh:
                    radius = (n as MeshInstance3D).mesh.get_aabb().size.y * 0.5
            elif nm == "Side":
                info["side"] = pos
            elif nm == "Roof":
                info["roof"] = pos
            elif nm.begins_with("Plate"):
                plates[nm] = pos
        if wheels.size() == 4:
            info["wheels"] = wheels
            info["radius"] = radius
            info["plates"] = plates
        root.free()
    _model_infos[id] = info
    return info


## Свой материал «Paint» в нужный цвет (для текстурной модели — оттенок поверх текстуры).
static func paint_material(src: Material, paint: Color) -> StandardMaterial3D:
    var m: StandardMaterial3D
    if src is StandardMaterial3D:
        m = (src as StandardMaterial3D).duplicate()
    else:
        m = StandardMaterial3D.new()
    m.albedo_color = paint if m.albedo_texture == null else paint.lightened(0.1)
    m.roughness = 0.35
    m.metallic_specular = 0.6
    return m


static func _role(mat: Material) -> String:
    return String(mat.resource_name) if mat else ""


## Неподвижная машина целиком (для припаркованных и машин-ботов): один меш, колёса на месте.
static func model_mesh(id: String, paint: Color) -> ArrayMesh:
    var key := id + paint.to_html()
    if _model_meshes.has(key):
        return _model_meshes[key]
    var root := model_instance(id)
    if root == null:
        return null
    var groups := {}   # материал -> SurfaceTool
    var paint_mat: StandardMaterial3D = null
    for n: Node in root.find_children("*", "MeshInstance3D", true, false):
        var mi := n as MeshInstance3D
        if mi.mesh == null:
            continue
        var xf := _rel(mi, root)
        for s in mi.mesh.get_surface_count():
            var mat := mi.mesh.surface_get_material(s)
            if _role(mat) == "Paint":
                if paint_mat == null:
                    paint_mat = paint_material(mat, paint)
                mat = paint_mat
            if not groups.has(mat):
                var st := SurfaceTool.new()
                st.begin(Mesh.PRIMITIVE_TRIANGLES)
                st.set_material(mat)
                groups[mat] = st
            (groups[mat] as SurfaceTool).append_from(mi.mesh, s, xf)
    var out := ArrayMesh.new()
    for mat in groups:
        (groups[mat] as SurfaceTool).commit(out)
    root.free()
    _model_meshes[key] = out
    return out
