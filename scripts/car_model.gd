extends RefCounted
## Модель машины из примитивов, склеенная в один меш (мало draw calls —
## важно для телефона). Общая для ездящих и припаркованных машин.
## Перед машины смотрит в +Z — так устроен VehicleBody3D в Godot.

const WHEEL_RADIUS := 0.31
const WHEEL_X := 0.72
const WHEEL_Z := 1.28

static var _shared := {}


## Коллизия кузова. kind: "car", "bus", "truck".
static func add_collision(body: CollisionObject3D, kind := "car") -> void:
    match kind:
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
        "bus":
            return _merge(_bus_parts(paint, tail))
        "truck":
            return _merge(_truck_parts(paint, tail))
    return _merge(_body_parts(paint, tail))


static func wheel_radius(kind: String) -> float:
    return WHEEL_RADIUS if kind == "car" else 0.5


## Где колёса: [[позиция крепления, передняя?], ...].
static func wheel_spots(kind: String) -> Array:
    var out := []
    match kind:
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
static func parked_mesh(paint: Color) -> ArrayMesh:
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
    _bx(p, Vector3(1.62, 0.6, 4.0), Vector3(0, 0.68, 0), body)       # низ кузова
    _bx(p, Vector3(1.64, 0.07, 4.02), Vector3(0, 0.6, 0), dark)      # молдинг
    _bx(p, Vector3(1.44, 0.42, 1.7), Vector3(0, 1.19, -0.15), glass) # стёкла
    _bx(p, Vector3(1.48, 0.07, 1.8), Vector3(0, 1.435, -0.15), body) # крыша
    for sx: float in [-1.0, 1.0]:
        _bx(p, Vector3(0.06, 0.42, 0.10), Vector3(0.71 * sx, 1.19, 0.68), body)   # стойка A
        _bx(p, Vector3(0.06, 0.42, 0.12), Vector3(0.71 * sx, 1.19, -0.10), body)  # стойка B
        _bx(p, Vector3(0.06, 0.42, 0.12), Vector3(0.71 * sx, 1.19, -0.98), body)  # стойка C
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
