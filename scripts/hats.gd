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
##   platok           — бабушкин платок в цветочек (жители города)

## Закрывает ли убор макушку (тогда волосы прячем, чтобы не торчали).
static func covers_hair(kind: String) -> bool:
    return kind in ["petushok", "ondatra", "fire_helmet", "med_cap", "platok"]


static func build(kind: String, col := Color(0, 0, 0, 0)) -> Node3D:
    var root := Node3D.new()
    root.name = "Hat"
    match kind:
        "militia":
            _peaked(root, Color(0.72, 0.07, 0.06), Color(0.22, 0.25, 0.31), false)
        "militia_officer":
            _peaked(root, Color(0.72, 0.07, 0.06), Color(0.18, 0.21, 0.27), true)
        "kgb":   # как на листе формы: тёмно-синяя тулья, чёрный околыш, красный кант, золотой шнур и звезда
            _peaked(root, Color(0.06, 0.065, 0.085), Color(0.13, 0.15, 0.24), true, Color(0.78, 0.08, 0.07))
        "fedora":
            _fedora(root, col if col.a > 0.0 else Color(0.22, 0.22, 0.24))
        "petushok":
            _petushok(root, col if col.a > 0.0 else Color(0.15, 0.3, 0.75))
            root.set_meta("snug", true)   # вязаная — плотно по голове (place_hat в outfits.gd)
        "kepka":
            _kepka(root, col if col.a > 0.0 else Color(0.30, 0.28, 0.26))
        "ondatra":
            _ondatra(root, col if col.a > 0.0 else Color(0.34, 0.24, 0.17))
        "fire_helmet":
            _helmet(root, col if col.a > 0.0 else Color(0.75, 0.10, 0.07))
        "med_cap":
            _med_cap(root)
        "platok":
            _platok(root, col if col.a > 0.0 else Color(0.62, 0.18, 0.16))
            root.set_meta("snug", true)
    return root


# ---------------------------------------------------------------- фуражки

static func _peaked(root: Node3D, band_col: Color, crown_col: Color, officer: bool, piping := Color(0, 0, 0, 0)) -> void:
    _part(root, _cyl(0.114, 0.112, 0.048), band_col, Vector3.ZERO, Vector3.ONE)                     # околыш
    _part(root, _cyl(0.15, 0.116, 0.05), crown_col, Vector3(0, 0.049, -0.005), Vector3(1.0, 1.0, 1.1))  # тулья
    _part(root, _cyl(0.148, 0.15, 0.012), crown_col.darkened(0.1), Vector3(0, 0.08, -0.005), Vector3(1.0, 1.0, 1.1))
    if piping.a <= 0.0:
        _part(root, _cyl(0.15, 0.15, 0.008), band_col.darkened(0.15), Vector3(0, 0.025, -0.005), Vector3(1.0, 1.0, 1.1))  # кант
    if piping.a > 0.0:   # кант — тонкие кольца по краю тульи и по верху околыша
        for pp: Array in [[0.147, 0.153, Vector3(0, 0.085, -0.005), Vector3(1.0, 1.0, 1.1)], [0.112, 0.117, Vector3(0, 0.022, 0.0), Vector3.ONE]]:
            var t := TorusMesh.new()
            t.inner_radius = pp[0]
            t.outer_radius = pp[1]
            t.rings = 32
            t.ring_segments = 6
            _part(root, t, piping, pp[2], pp[3])
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
    # вязаная шапка 80-х: плотный купол, отворот с полосками, сверху «гребешок» и помпон
    var stripe := Color(0.95, 0.95, 0.93) if c.v < 0.7 else Color(0.1, 0.1, 0.12)
    _knit_part(root, _cyl(0.121, 0.118, 0.062), c, Vector3(0, 0.004, -0.004), Vector3(1.0, 1.0, 1.08), 40.0)  # отворот
    for y: float in [-0.006, 0.016]:
        _knit_part(root, _cyl(0.1225, 0.1225, 0.008), stripe, Vector3(0, y, -0.004), Vector3(1.0, 1.0, 1.08), 40.0)
    var dome := SphereMesh.new()
    dome.radius = 0.118
    dome.height = 0.236
    dome.is_hemisphere = true
    dome.radial_segments = 24
    dome.rings = 8
    _knit_part(root, dome, c, Vector3(0, 0.03, -0.006), Vector3(1.0, 0.8, 1.08), 40.0)                    # купол
    var crest := SphereMesh.new()
    crest.radius = 0.1
    crest.height = 0.2
    crest.radial_segments = 20
    crest.rings = 8
    _knit_part(root, crest, c, Vector3(0, 0.095, -0.02), Vector3(0.3, 0.42, 0.95), 24.0)                   # гребешок
    var pom := SphereMesh.new()
    pom.radius = 0.032
    pom.height = 0.064
    _knit_part(root, pom, stripe, Vector3(0, 0.15, -0.045), Vector3.ONE, 8.0)                                # помпон


## Вязка: вертикальные «косички» (полосы светлее/темнее), общая картинка на все шапки.
static var _knit_tex: ImageTexture = null


static func _knit_part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, scl: Vector3, ribs: float) -> MeshInstance3D:
    if _knit_tex == null:
        var img := Image.create(32, 8, false, Image.FORMAT_RGB8)
        for x in 32:
            var k := 0.82 + 0.18 * (0.5 + 0.5 * sin(x / 32.0 * TAU * 2.0))
            for y in 8:
                var n := k * (0.96 + 0.04 * ((x * 7 + y * 13) % 5) / 4.0)
                img.set_pixel(x, y, Color(n, n, n))
        _knit_tex = ImageTexture.create_from_image(img)
    var mi := _part(parent, mesh, col, pos, scl)
    var m := mi.material_override as StandardMaterial3D
    m.albedo_texture = _knit_tex
    m.uv1_scale = Vector3(ribs / 2.0, 1, 1)
    m.roughness = 0.95
    return mi


static func _kepka(root: Node3D, c: Color) -> void:
    _part(root, _cyl(0.118, 0.116, 0.035), c.darkened(0.08), Vector3(0, 0.0, -0.004), Vector3(1.0, 1.0, 1.08))
    var crown := SphereMesh.new()
    crown.radius = 0.135
    crown.height = 0.27
    var cm := _part(root, crown, c, Vector3(0, 0.03, 0.012), Vector3(1.0, 0.36, 1.12))                       # плоский верх
    (cm.material_override as StandardMaterial3D).roughness = 0.95       # сукно, не блестит
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


## Пожарная каска (как у советских пожарных): гладкий купол по голове, низкий гребень, белая полоса,
## номер «01» спереди, чёрный кожаный назатыльник сзади и тёмное забрало.
static func _helmet(root: Node3D, c: Color) -> void:
    var dome := SphereMesh.new()
    dome.radius = 0.13
    dome.height = 0.26
    dome.is_hemisphere = true
    dome.radial_segments = 28
    dome.rings = 10
    var d := _part(root, dome, c, Vector3(0, -0.012, -0.008), Vector3(1.0, 0.86, 1.13))
    (d.material_override as StandardMaterial3D).roughness = 0.3            # лакированная
    var crest := SphereMesh.new()                                                                           # гребень
    crest.radius = 0.12
    crest.height = 0.24
    crest.is_hemisphere = true
    _part(root, crest, c.lightened(0.08), Vector3(0, 0.0, -0.008), Vector3(0.14, 0.97, 1.16))
    var white := Color(0.95, 0.95, 0.95) if c.v < 0.9 or c.s > 0.2 else Color(0.75, 0.1, 0.07)
    _part(root, _cyl(0.1305, 0.1325, 0.016), white, Vector3(0, 0.03, -0.008), Vector3(1.0, 1.0, 1.13))  # полоса
    _part(root, _cyl(0.137, 0.137, 0.01), c.darkened(0.25), Vector3(0, -0.012, -0.008), Vector3(1.0, 1.0, 1.13))  # кромка
    for k in 7:   # назатыльник: чёрная кожа полукругом сзади, от уха до уха
        var ang := deg_to_rad(95.0 + k * 28.3)
        var seg := BoxMesh.new()
        seg.size = Vector3(0.07, 0.085, 0.008)
        var fp := _part(root, seg, Color(0.06, 0.06, 0.065), Vector3(sin(ang) * 0.138, -0.055, cos(ang) * 0.152 - 0.008), Vector3.ONE)
        fp.rotation = Vector3(deg_to_rad(-8.0) * -cos(ang), ang, 0)
        (fp.material_override as StandardMaterial3D).roughness = 0.6
    var visor := BoxMesh.new()                                                                              # забрало
    visor.size = Vector3(0.2, 0.075, 0.006)
    var v := _part(root, visor, Color(0.15, 0.17, 0.2, 0.55), Vector3(0, -0.005, 0.15), Vector3.ONE)
    v.rotation.x = deg_to_rad(-12.0)
    var vm := v.material_override as StandardMaterial3D
    vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    vm.roughness = 0.1
    var num := Label3D.new()                                                                                # «01»
    num.text = "01"
    num.font_size = 48
    num.pixel_size = 0.0012
    num.outline_size = 0
    num.modulate = Color(0.97, 0.97, 0.95)
    num.position = Vector3(0, 0.075, 0.128)
    num.rotation.x = deg_to_rad(-28.0)
    num.double_sided = false
    root.add_child(num)


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

## Платок: облегает голову, узел под подбородком.
static func _platok(root: Node3D, c: Color) -> void:
    var cap := SphereMesh.new()
    cap.radius = 0.135
    cap.height = 0.27
    _part(root, cap, c, Vector3(0, 0.0, -0.012), Vector3(1.04, 0.95, 1.12))
    _part(root, _cyl(0.13, 0.142, 0.13), c.darkened(0.06), Vector3(0, -0.06, -0.03), Vector3(1.04, 1.0, 1.0))     # по бокам головы
    var knot := SphereMesh.new()
    knot.radius = 0.03
    knot.height = 0.06
    _part(root, knot, c.darkened(0.12), Vector3(0, -0.2, 0.07), Vector3.ONE)
    for k in 6:   # белые «цветочки»
        var dot := SphereMesh.new()
        dot.radius = 0.016
        dot.height = 0.032
        var a := float(k) / 6.0 * TAU
        _part(root, dot, Color(0.95, 0.92, 0.8), Vector3(sin(a) * 0.11, 0.06 + 0.03 * cos(a * 2.0), cos(a) * 0.12), Vector3(1, 0.4, 1))


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
