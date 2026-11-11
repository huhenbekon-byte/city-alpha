extends RefCounted
## Модель машины из примитивов, склеенная в один меш (мало draw calls —
## важно для телефона). Общая для ездящих и припаркованных машин.
## Перед машины смотрит в +Z — так устроен VehicleBody3D в Godot.

const WHEEL_RADIUS := 0.31
const WHEEL_X := 0.72
const WHEEL_Z := 1.28

static var _shared := {}


## Коллизия кузова (низ + салон).
static func add_collision(body: CollisionObject3D) -> void:
    _shape(body, Vector3(1.62, 0.6, 4.0), Vector3(0, 0.68, 0))
    _shape(body, Vector3(1.44, 0.44, 1.7), Vector3(0, 1.2, -0.15))


## Кузов без колёс (для ездящей машины). tail — материал стоп-сигналов.
static func body_mesh(paint: Color, tail: Material) -> ArrayMesh:
    return _merge(_body_parts(paint, tail))


## Колесо: ось вдоль X, центр в начале координат. Один общий меш на всех.
static func wheel_mesh() -> ArrayMesh:
    if not _shared.has("wheel_mesh"):
        _shared["wheel_mesh"] = _merge(_wheel_parts(Transform3D()))
    return _shared["wheel_mesh"]


## Целая машина с колёсами — для припаркованных (MultiMesh).
static func parked_mesh(paint: Color) -> ArrayMesh:
    var tail := _mat("tail_static", Color(0.55, 0.04, 0.04), 0.3, 0.0, 0.3)
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
    m.albedo_color = Color(0.55, 0.04, 0.04)
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

    var p := []
    _bx(p, Vector3(1.62, 0.6, 4.0), Vector3(0, 0.68, 0), body)       # низ кузова
    _bx(p, Vector3(1.64, 0.07, 4.02), Vector3(0, 0.6, 0), dark)      # молдинг
    _bx(p, Vector3(1.44, 0.42, 1.7), Vector3(0, 1.19, -0.15), glass) # стёкла
    _bx(p, Vector3(1.48, 0.07, 1.8), Vector3(0, 1.435, -0.15), body) # крыша
    _bx(p, Vector3(0.7, 0.14, 0.03), Vector3(0, 0.8, 2.005), dark)   # решётка
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.06, 0.42, 0.10), Vector3(0.71 * sx, 1.19, 0.68), body)   # стойка A
        _bx(p, Vector3(0.06, 0.42, 0.12), Vector3(0.71 * sx, 1.19, -0.10), body)  # стойка B
        _bx(p, Vector3(0.06, 0.42, 0.12), Vector3(0.71 * sx, 1.19, -0.98), body)  # стойка C
        _bx(p, Vector3(0.30, 0.14, 0.03), Vector3(0.55 * sx, 0.80, 2.005), head)  # фары
        _bx(p, Vector3(0.36, 0.13, 0.03), Vector3(0.54 * sx, 0.82, -2.005), tail) # фонари
        _bx(p, Vector3(0.12, 0.10, 0.07), Vector3(0.84 * sx, 1.05, 0.62), dark)   # зеркала
    for sz: float in [-1.0, 1.0]:
        _bx(p, Vector3(1.68, 0.16, 0.14), Vector3(0, 0.46, 2.02 * sz), chrome)    # бампер
        _bx(p, Vector3(0.50, 0.11, 0.02), Vector3(0, 0.46, 2.10 * sz), plate)     # номер
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

    return [[tm, axle, tire], [rm, axle, rim], [spoke, xf, tire]]


# ---------------------------------------------------------------- помощники

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
