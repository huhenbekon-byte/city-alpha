extends RefCounted
## Головные уборы из простых фигур. Начало координат — низ околыша на лбу
## (у персонажа: кость «Head» + (0, 0.16, 0.008)), вперёд — +Z.
##   militia          — фуражка милиции (красный околыш)
##   militia_officer  — офицерская фуражка: золотой шнур и большая кокарда
##   kgb              — фуражка КГБ (васильковый околыш)
##   fedora           — шляпа (оперативники КГБ, мэрия)
##   petushok         — вязаная шапка-«петушок» с помпоном (скорлупа и супера ОПГ)
##   kepka            — кепка-восьмиклинка (молодые ОПГ, опера угрозыска)
##   ondatra          — ондатровая шапка (старшие ОПГ, начальство)
##   fire_helmet      — пожарная каска с гребнем
##   med_cap          — белая медицинская шапочка с красным крестом

## Закрывает ли убор макушку (тогда волосы прячем, чтобы не торчали).
static func covers_hair(kind: String) -> bool:
    return kind in ["petushok", "ondatra", "fire_helmet", "med_cap"]


static func build(kind: String, col := Color(0, 0, 0, 0)) -> Node3D:
    var root := Node3D.new()
    root.name = "Hat"
    match kind:
        "militia":
            _peaked(root, Color(0.72, 0.07, 0.06), Color(0.22, 0.25, 0.31), false)
        "militia_officer":
            _peaked(root, Color(0.72, 0.07, 0.06), Color(0.18, 0.21, 0.27), true)
        "kgb":
            _peaked(root, Color(0.22, 0.42, 0.85), Color(0.26, 0.29, 0.26), true)
        "fedora":
            _fedora(root, col if col.a > 0.0 else Color(0.22, 0.22, 0.24))
        "petushok":
            _petushok(root, col if col.a > 0.0 else Color(0.15, 0.3, 0.75))
        "kepka":
            _kepka(root, col if col.a > 0.0 else Color(0.30, 0.28, 0.26))
        "ondatra":
            _ondatra(root, col if col.a > 0.0 else Color(0.34, 0.24, 0.17))
        "fire_helmet":
            _helmet(root, col if col.a > 0.0 else Color(0.75, 0.10, 0.07))
        "med_cap":
            _med_cap(root)
    return root


# ---------------------------------------------------------------- фуражки

static func _peaked(root: Node3D, band_col: Color, crown_col: Color, officer: bool) -> void:
    _part(root, _cyl(0.114, 0.112, 0.048), band_col, Vector3.ZERO, Vector3.ONE)                     # околыш
    _part(root, _cyl(0.15, 0.116, 0.05), crown_col, Vector3(0, 0.049, -0.005), Vector3(1.0, 1.0, 1.1))  # тулья
    _part(root, _cyl(0.148, 0.15, 0.012), crown_col.darkened(0.1), Vector3(0, 0.08, -0.005), Vector3(1.0, 1.0, 1.1))
    _part(root, _cyl(0.15, 0.15, 0.008), band_col.darkened(0.15), Vector3(0, 0.025, -0.005), Vector3(1.0, 1.0, 1.1))  # кант
    var v := _part(root, _cyl(0.1, 0.1, 0.01), Color(0.03, 0.03, 0.035), Vector3(0, -0.018, 0.085), Vector3(1.0, 1.0, 0.55))
    v.rotation.x = deg_to_rad(18.0)                                                                       # козырёк
    var gold := Color(0.95, 0.75, 0.2)
    var badge := SphereMesh.new()
    badge.radius = 0.02 if officer else 0.014
    badge.height = badge.radius * 2.0
    _part(root, badge, gold, Vector3(0, 0.006, 0.113), Vector3(1.0, 1.0, 0.4))                           # кокарда
    if officer:   # золотой шнур над козырьком
        var cord := BoxMesh.new()
        cord.size = Vector3(0.17, 0.008, 0.008)
        _part(root, cord, gold, Vector3(0, -0.012, 0.114), Vector3.ONE)
        for sx: float in [-1.0, 1.0]:
            var btn := SphereMesh.new()
            btn.radius = 0.007
            btn.height = 0.014
            _part(root, btn, gold, Vector3(sx * 0.088, -0.012, 0.09), Vector3.ONE)


static func _fedora(root: Node3D, c: Color) -> void:
    _part(root, _cyl(0.13, 0.215, 0.012), c.darkened(0.05), Vector3(0, 0.0, 0.0), Vector3(1.0, 1.0, 1.1))      # поля
    _part(root, _cyl(0.105, 0.122, 0.11), c, Vector3(0, 0.06, -0.004), Vector3(1.0, 1.0, 1.12))             # тулья
    _part(root, _cyl(0.123, 0.124, 0.03), Color(0.06, 0.06, 0.06), Vector3(0, 0.022, -0.004), Vector3(1.0, 1.0, 1.12))  # лента
    var dent := BoxMesh.new()                                                                               # залом сверху
    dent.size = Vector3(0.03, 0.02, 0.17)
    _part(root, dent, c.darkened(0.25), Vector3(0, 0.112, -0.004), Vector3.ONE)


static func _petushok(root: Node3D, c: Color) -> void:
    var stripe := Color(0.95, 0.95, 0.93) if c.v < 0.7 else Color(0.1, 0.1, 0.12)
    _part(root, _cyl(0.122, 0.121, 0.055), c, Vector3(0, 0.0, -0.004), Vector3(1.0, 1.0, 1.08))             # отворот
    _part(root, _cyl(0.124, 0.124, 0.014), stripe, Vector3(0, 0.012, -0.004), Vector3(1.0, 1.0, 1.08))       # полоска
    var cone := _cyl(0.03, 0.118, 0.17)
    var top := _part(root, cone, c, Vector3(0, 0.11, -0.03), Vector3(1.0, 1.0, 1.05))
    top.rotation.x = deg_to_rad(-14.0)                                                                       # «гребень» назад
    _part(root, _cyl(0.07, 0.085, 0.02), stripe, Vector3(0, 0.1, -0.026), Vector3(1.0, 1.0, 1.05))
    var pom := SphereMesh.new()
    pom.radius = 0.035
    pom.height = 0.07
    _part(root, pom, stripe, Vector3(0, 0.2, -0.055), Vector3.ONE)


static func _kepka(root: Node3D, c: Color) -> void:
    _part(root, _cyl(0.118, 0.116, 0.035), c.darkened(0.08), Vector3(0, 0.0, -0.004), Vector3(1.0, 1.0, 1.08))
    var crown := SphereMesh.new()
    crown.radius = 0.135
    crown.height = 0.27
    _part(root, crown, c, Vector3(0, 0.03, 0.012), Vector3(1.0, 0.36, 1.12))                                 # плоский верх
    var btn := SphereMesh.new()
    btn.radius = 0.012
    btn.height = 0.024
    _part(root, btn, c.darkened(0.2), Vector3(0, 0.077, 0.012), Vector3.ONE)
    var v := _part(root, _cyl(0.09, 0.09, 0.01), c.darkened(0.15), Vector3(0, -0.006, 0.1), Vector3(1.0, 1.0, 0.6))
    v.rotation.x = deg_to_rad(12.0)


static func _ondatra(root: Node3D, c: Color) -> void:
    _part(root, _cyl(0.142, 0.138, 0.13), c, Vector3(0, 0.045, -0.004), Vector3(1.0, 1.0, 1.08))            # меховой «столбик»
    var top := SphereMesh.new()
    top.radius = 0.14
    top.height = 0.28
    _part(root, top, c.lightened(0.06), Vector3(0, 0.108, -0.004), Vector3(1.0, 0.25, 1.08))
    _part(root, _cyl(0.146, 0.146, 0.02), c.darkened(0.15), Vector3(0, 0.0, -0.004), Vector3(1.0, 1.0, 1.08))   # отворот


static func _helmet(root: Node3D, c: Color) -> void:
    var dome := SphereMesh.new()
    dome.radius = 0.15
    dome.height = 0.3
    dome.is_hemisphere = true
    _part(root, dome, c, Vector3(0, 0.005, -0.006), Vector3(1.0, 0.95, 1.1))
    var crest := BoxMesh.new()                                                                              # гребень
    crest.size = Vector3(0.03, 0.04, 0.3)
    var cr := _part(root, crest, c.lightened(0.15), Vector3(0, 0.135, -0.01), Vector3.ONE)
    cr.rotation.x = deg_to_rad(-4.0)
    _part(root, _cyl(0.175, 0.175, 0.012), c.darkened(0.2), Vector3(0, 0.0, -0.01), Vector3(1.0, 1.0, 1.15))  # поля
    var badge := SphereMesh.new()
    badge.radius = 0.02
    badge.height = 0.04
    _part(root, badge, Color(0.95, 0.75, 0.2), Vector3(0, 0.06, 0.155), Vector3(1.0, 1.0, 0.4))


static func _med_cap(root: Node3D) -> void:
    var white := Color(0.96, 0.97, 0.97)
    _part(root, _cyl(0.124, 0.12, 0.085), white, Vector3(0, 0.03, -0.004), Vector3(1.0, 1.0, 1.08))
    var top := SphereMesh.new()
    top.radius = 0.124
    top.height = 0.248
    _part(root, top, white, Vector3(0, 0.072, -0.004), Vector3(1.0, 0.18, 1.08))
    var red := Color(0.85, 0.08, 0.08)
    for sz: Vector3 in [Vector3(0.05, 0.014, 0.006), Vector3(0.014, 0.05, 0.006)]:
        var b := BoxMesh.new()
        b.size = sz
        _part(root, b, red, Vector3(0, 0.035, 0.132), Vector3.ONE)


# ---------------------------------------------------------------- помощники

static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
    var m := CylinderMesh.new()
    m.top_radius = top
    m.bottom_radius = bottom
    m.height = h
    m.radial_segments = 20
    m.rings = 1
    return m


static func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, scl: Vector3) -> MeshInstance3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = 0.35 if col.v < 0.1 else 0.75
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = m
    mi.position = pos
    mi.scale = scl
    parent.add_child(mi)
    return mi
