extends RefCounted
## Объёмные детали формы поверх нарисованной одежды: погоны, ремень с пряжкой и кобурой, отложной воротник,
## лацканы, портупея, золотая цепь, пожарный пояс с карабином. Детали строятся по поверхности тела (меряем
## вершины модели в позе покоя), крепятся к костям (BoneAttachment3D) и двигаются вместе с персонажем;
## сужение фигуры (outfits.gd apply_build — масштаб костей) действует и на них.
## Всё из одного материала с цветом в вершинах: 1–4 вызова отрисовки на персонажа.
## Выключено на слабой графике (enabled = false) — тогда остаётся только рисунок формы.

const OutfitsScript := preload("res://scripts/outfits.gd")

static var enabled := true
static var _bodies := {}          # меш тела → вершины и суставы (замер один раз на модель)
static var _mat: StandardMaterial3D = null
static var _meshes := {}          # (тело, образ, звание) → {кость: ArrayMesh} — одни и те же для всех персонажей

const GOLD := Color(0.95, 0.74, 0.24)
const SILVER := Color(0.78, 0.8, 0.82)
const LEATHER := Color(0.07, 0.065, 0.06)
const RED := Color(0.78, 0.08, 0.07)

## Что надето на ком: ключ образа (outfits.gd TOP) → детали.
const KIT := {
    "militia": {"cloth": Color(0.12, 0.14, 0.22), "pipe": RED, "items": ["epaulets", "collar", "belt", "holster"]},
    "kgb": {"cloth": Color(0.11, 0.12, 0.19), "pipe": RED, "items": ["epaulets", "collar", "lapels", "belt", "holster"]},
    "fire": {"cloth": Color(0.08, 0.08, 0.09), "items": ["fire_belt"]},
    "doctor": {"cloth": Color(0.92, 0.93, 0.94), "items": ["collar", "lapels"]},
    "ambulance": {"cloth": Color(0.1, 0.25, 0.72), "items": ["collar"]},
    "opg": {"cloth": Color(0.06, 0.06, 0.07), "items": ["chain_thin"]},
    "avtoritet": {"cloth": Color(0.05, 0.05, 0.055), "items": ["collar", "lapels", "chain", "belt_gold"]},
}


## Надеть детали на модель персонажа. rank — звёзды на погонах и портупея у старших.
static func apply(model: Node3D, jacket: String, pants: String, female: bool, rank := 2) -> void:
    if model == null:
        return
    for old: Node in model.find_children("Gear_*", "", true, false):
        old.get_parent().remove_child(old)
        old.queue_free()
    if not enabled:
        return
    var key := String((OutfitsScript.TOP_F if female else OutfitsScript.TOP).get(jacket, ""))
    if jacket.begins_with("uni_opg"):
        key = "opg"
    if not KIT.has(key):
        return
    var sks := model.find_children("*", "Skeleton3D", true, false)
    if sks.is_empty():
        return
    var sk := sks[0] as Skeleton3D
    var body := _body(sk)
    if body.is_empty():
        return
    var ck := "%s|%s|%d" % [str(_body_key(sk)), key, rank if key in ["militia", "kgb"] else 0]
    if not _meshes.has(ck):
        _meshes[ck] = _build(body, key, rank)
    if _mat == null:
        _mat = StandardMaterial3D.new()
        _mat.vertex_color_use_as_albedo = true
        _mat.roughness = 0.55
        _mat.metallic_specular = 0.6
        _mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var meshes: Dictionary = _meshes[ck]
    for bone: String in meshes:
        var i := sk.find_bone(bone)
        if i < 0:
            continue
        var ba := BoneAttachment3D.new()
        ba.name = "Gear_" + bone
        ba.bone_name = bone
        sk.add_child(ba)
        var mi := MeshInstance3D.new()
        mi.mesh = meshes[bone]
        mi.material_override = _mat
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mi.transform = sk.get_bone_global_rest(i).affine_inverse()   # детали построены в пространстве скелета
        ba.add_child(mi)


static func _build(body: Dictionary, key: String, rank: int) -> Dictionary:
    var kit: Dictionary = KIT[key]
    var items: Array = (kit["items"] as Array).duplicate()
    if key in ["militia", "kgb"] and rank >= 5:
        items.append("portupea")
    var groups := {}   # кость → SurfaceTool
    for it: String in items:
        match it:
            "epaulets":
                _epaulets(groups, body, kit, rank)
            "collar":
                _collar(groups, body, kit["cloth"])
            "lapels":
                _lapels(groups, body, kit["cloth"])
            "belt":
                _belt(groups, body, LEATHER, 0.04, GOLD if key == "kgb" else SILVER)
            "belt_gold":
                _belt(groups, body, LEATHER, 0.032, GOLD)
            "holster":
                _holster(groups, body)
            "fire_belt":
                _belt(groups, body, Color(0.1, 0.1, 0.1), 0.065, SILVER)
                _carabiner(groups, body)
            "chain":
                _chain(groups, body, 0.011, 0.09)
            "chain_thin":
                _chain(groups, body, 0.007, 0.06)
            "portupea":
                _portupea(groups, body)
    var out := {}
    for bone: String in groups:
        var st: SurfaceTool = groups[bone]
        st.generate_normals()
        out[bone] = st.commit()
    return out


# ---------------------------------------------------------------- замер тела

static func _body_mesh(sk: Skeleton3D) -> MeshInstance3D:
    var mi: MeshInstance3D = null
    for n: Node in sk.find_children("*", "MeshInstance3D", true, false):
        if n is MeshInstance3D and (n as MeshInstance3D).mesh and (mi == null or String(n.name) == "Body"):
            mi = n
    return mi


static func _body_key(sk: Skeleton3D) -> int:
    var mi := _body_mesh(sk)
    return mi.mesh.get_rid().get_id() if mi else 0


static func _body(sk: Skeleton3D) -> Dictionary:
    var mi := _body_mesh(sk)
    if mi == null:
        return {}
    var key := mi.mesh.get_rid().get_id()
    if _bodies.has(key):
        return _bodies[key]
    var v: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var xf := mi.transform
    var pts := PackedVector3Array()
    pts.resize(v.size())
    for k in v.size():
        pts[k] = xf * v[k]
    var J := {}
    for n: String in ["pelvis", "spine_01", "spine_03", "neck_01", "upperarm_l", "clavicle_l"]:
        var i := sk.find_bone(n)
        J[n] = sk.get_bone_global_rest(i).origin if i >= 0 else Vector3.ZERO
    var bins := {}   # вершины по сантиметрам высоты — чтобы не перебирать все 15 000 на каждый замер
    for p: Vector3 in pts:
        var bi := int(floor(p.y * 100.0))
        if not bins.has(bi):
            bins[bi] = []
        (bins[bi] as Array).append(p)   # Array — по ссылке (PackedVector3Array скопировался бы)
    for bi: int in bins:
        bins[bi] = PackedVector3Array(bins[bi])
    var d := {"v": pts, "J": J, "bins": bins}
    _bodies[key] = d
    return d


## Точка на поверхности тела в направлении ang (0 — вперёд, +X — влево) на высоте y, от оси туловища.
## Вершины в полосе высот [y0, y1].
static func _band(b: Dictionary, y0: float, y1: float) -> PackedVector3Array:
    var out := PackedVector3Array()
    var bins: Dictionary = b["bins"]
    for bi in range(int(floor(y0 * 100.0)), int(floor(y1 * 100.0)) + 1):
        if bins.has(bi):
            out.append_array(bins[bi])
    return out


static func _surf(b: Dictionary, y: float, ang: float, out := 0.0, dy := 0.012, maxr := 0.3) -> Vector3:
    var v := _band(b, y - dy, y + dy)
    var dir := Vector2(sin(ang), cos(ang))
    var best := 0.0
    var cz := 0.0
    var cn := 0
    for p: Vector3 in v:
        if absf(p.y - y) > dy or absf(p.x) > 0.3:
            continue
        cz += p.z
        cn += 1
    cz = cz / maxf(1.0, cn)
    for p: Vector3 in v:
        if absf(p.y - y) > dy or absf(p.x) > 0.3:
            continue
        var q := Vector2(p.x, p.z - cz)
        var l := q.length()
        if l < 0.001:
            continue
        if q.dot(dir) / l > 0.985 and l > best and l < maxr:
            best = l
    if best == 0.0:
        best = 0.12
    return Vector3(dir.x * (best + out), y, cz + dir.y * (best + out))


## Спереди: z поверхности в точке (x, y).
static func _front(b: Dictionary, x: float, y: float, out := 0.0, back := false) -> Vector3:
    var v := _band(b, y - 0.014, y + 0.014)
    var z := -1e9 if not back else 1e9
    for p: Vector3 in v:
        if absf(p.x - x) < 0.014 and absf(p.y - y) < 0.014:
            z = maxf(z, p.z) if not back else minf(z, p.z)
    if absf(z) > 1e8:
        z = 0.1 if not back else -0.08
    return Vector3(x, y, z + (out if not back else -out))


## Сверху: y поверхности над точкой (x, z) — плечи.
static func _top(b: Dictionary, x: float, z: float, out := 0.0) -> Vector3:
    var ymax: float = (b["J"]["neck_01"] as Vector3).y + 0.025   # выше — уже шея и голова
    var v := _band(b, 1.0, ymax)
    var y := -1e9
    for p: Vector3 in v:
        if absf(p.x - x) < 0.012 and absf(p.z - z) < 0.035 and p.y < ymax:
            y = maxf(y, p.y)
    return Vector3(x, y + out, z)


static func _st(groups: Dictionary, bone: String) -> SurfaceTool:
    if not groups.has(bone):
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        groups[bone] = st
    return groups[bone]


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
    # лицом наружу от тела (иначе освещение «изнутри» — деталь тёмная): ось туловища чуть ниже точки
    var n := (c - a).cross(b - a)
    var out := a - Vector3(0, a.y - 0.15, 0.01)
    if n.dot(out) > 0.0:
        var t := b
        b = c
        c = t
    st.set_color(col)
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
    _tri(st, a, b, c, col)
    _tri(st, a, c, d, col)


## Коробка: центр, оси (полуразмеры уже в осях).
static func _box(st: SurfaceTool, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, col: Color) -> void:
    var p := func(sx: float, sy: float, sz: float) -> Vector3: return c + ax * sx + ay * sy + az * sz
    var faces := [[[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]], [[-1, -1, 1], [-1, 1, 1], [-1, 1, -1], [-1, -1, -1]],
        [[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]], [[-1, -1, 1], [-1, -1, -1], [1, -1, -1], [1, -1, 1]],
        [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]], [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]]]
    for f: Array in faces:
        var q: Array = []
        for s: Array in f:
            q.append(p.call(float(s[0]), float(s[1]), float(s[2])))
        _quad(st, q[0], q[1], q[2], q[3], col)


## Лента по точкам: ширина — в сторону side[i], с толщиной (две стороны и кромки).
static func _ribbon(st: SurfaceTool, pts: Array, side: Array, nor: Array, hw: float, th: float, col: Color, closed := false) -> void:
    var n := pts.size()
    var last := n if closed else n - 1
    for i in last:
        var j := (i + 1) % n
        var a0: Vector3 = pts[i] - side[i] * hw
        var a1: Vector3 = pts[i] + side[i] * hw
        var b0: Vector3 = pts[j] - side[j] * hw
        var b1: Vector3 = pts[j] + side[j] * hw
        var ta: Vector3 = nor[i] * th
        var tb: Vector3 = nor[j] * th
        _quad(st, a0 + ta, b0 + tb, b1 + tb, a1 + ta, col)                  # лицо
        _quad(st, a1 + ta, b1 + tb, b1, a1, col.darkened(0.25))             # кромки
        _quad(st, b0 + tb, a0 + ta, a0, b0, col.darkened(0.25))


# ---------------------------------------------------------------- детали

## Ремень вокруг талии с пряжкой спереди.
static func _belt(groups: Dictionary, b: Dictionary, col: Color, h: float, buckle: Color) -> void:
    var J: Dictionary = b["J"]
    var y: float = J["pelvis"].y + 0.07
    var st := _st(groups, "pelvis")
    var pts := []
    var side := []
    var nor := []
    for k in 28:
        var a := k * TAU / 28.0
        var p := _surf(b, y, a, 0.011)
        pts.append(p)
        side.append(Vector3.UP)
        nor.append(Vector3(sin(a), 0, cos(a)))
    _ribbon(st, pts, side, nor, h * 0.5, 0.004, col, true)
    var f: Vector3 = _surf(b, y, 0.0, 0.016)
    _box(st, f, Vector3(0.026, 0, 0), Vector3(0, h * 0.5 + 0.004, 0), Vector3(0, 0, 0.004), buckle)
    _box(st, f + Vector3(0, 0, 0.004), Vector3(0.016, 0, 0), Vector3(0, h * 0.5 - 0.004, 0), Vector3(0, 0, 0.002), col)


## Кобура на правом боку (у персонажа справа = -X), чуть сзади.
static func _holster(groups: Dictionary, b: Dictionary) -> void:
    var J: Dictionary = b["J"]
    var y: float = J["pelvis"].y + 0.03
    var a := deg_to_rad(-112.0)
    var p := _surf(b, y, a, 0.028)
    var out := Vector3(sin(a), 0, cos(a))
    var along := Vector3(cos(a), 0, -sin(a))
    var st := _st(groups, "pelvis")
    _box(st, p + Vector3(0, -0.035, 0), along * 0.032, Vector3(0, 0.07, 0), out * 0.02, Color(0.2, 0.12, 0.07))
    _box(st, p + Vector3(0, 0.03, 0) + out * 0.004, along * 0.034, Vector3(0, 0.022, 0), out * 0.022, Color(0.16, 0.1, 0.06))  # клапан
    _box(st, p + Vector3(0, 0.03, 0) + out * 0.027, along * 0.006, Vector3(0, 0.006, 0), out * 0.002, GOLD)                    # кнопка


## Погоны: на плечах от воротника к плечу, кант по краю, звёзды по званию.
static func _epaulets(groups: Dictionary, b: Dictionary, kit: Dictionary, rank: int) -> void:
    var J: Dictionary = b["J"]
    var sh: Vector3 = J["upperarm_l"]
    var cloth: Color = kit["cloth"]
    var pipe: Color = kit.get("pipe", GOLD)
    var stars: int = [1, 2, 3, 1, 2, 3][clampi(rank, 1, 6) - 1]
    var big := rank >= 4
    for sgn: float in [1.0, -1.0]:
        var st := _st(groups, "clavicle_l" if sgn > 0.0 else "clavicle_r")
        var x0 := 0.075
        var x1 := sh.x + 0.03
        var pts := []
        var side := []
        var nor := []
        for k in 6:
            var x := lerpf(x0, x1, k / 5.0)
            var p := _top(b, x * sgn, sh.z + 0.005, 0.009)
            pts.append(p)
            side.append(Vector3(0, 0, 1))
        for k in 6:
            var t: Vector3 = (pts[mini(k + 1, 5)] - pts[maxi(k - 1, 0)]).normalized()
            nor.append(t.cross(Vector3(0, 0, 1)).normalized() * (-1.0 if sgn > 0.0 else 1.0))
            if nor[k].y < 0.0:
                nor[k] = -nor[k]
        _ribbon(st, pts, side, nor, 0.032, 0.006, pipe)                            # кант (нижний слой шире)
        var inner := []
        for k in 6:
            inner.append(pts[k] + nor[k] * 0.0065)
        _ribbon(st, inner, side, nor, 0.026, 0.002, cloth)
        # пуговица у воротника
        _box(st, inner[0] + nor[0] * 0.004 + (pts[1] - pts[0]).normalized() * 0.01, Vector3(0.006, 0, 0), Vector3(0, 0.003, 0), Vector3(0, 0, 0.006), GOLD)
        # звёзды вдоль погона
        for s in stars:
            var t := 0.45 + s * 0.16 if stars > 1 else 0.6
            var kf := t * 5.0
            var i0 := int(kf)
            var c: Vector3 = (inner[i0] as Vector3).lerp(inner[mini(i0 + 1, 5)], kf - i0) + nor[i0] * 0.004
            var r := 0.009 if big else 0.006
            _star(st, c, nor[i0], Vector3(0, 0, 1), r, GOLD)


static func _star(st: SurfaceTool, c: Vector3, n: Vector3, up: Vector3, r: float, col: Color) -> void:
    var right := up.cross(n).normalized()
    var pts := []
    for i in 10:
        var a := -PI * 0.5 + i * PI / 5.0
        var rr := r if i % 2 == 0 else r * 0.42
        pts.append(c + (right * cos(a) + up * -sin(a)) * rr)
    for i in 10:
        _tri(st, c + n * 0.0015, pts[i], pts[(i + 1) % 10], col)


## Отложной воротник: лежит на плечах вокруг шеи, спереди открыт.
static func _collar(groups: Dictionary, b: Dictionary, col: Color) -> void:
    var J: Dictionary = b["J"]
    var yn: float = J["neck_01"].y - 0.005
    var st := _st(groups, "spine_03")
    var inner := []
    var outer := []
    for k in 15:
        var a := deg_to_rad(lerpf(32.0, 328.0, k / 14.0))
        var p0 := _surf(b, yn, a, 0.008, 0.01, 0.085)
        var p1 := _surf(b, yn - 0.045, a, 0.016, 0.01, 0.125)
        if cos(a) > 0.3:   # спереди концы воротника опускаются на грудь
            p1.y -= 0.02 * cos(a)
        inner.append(p0)
        outer.append(p1)
    for k in 14:
        _quad(st, inner[k], inner[k + 1], outer[k + 1], outer[k], col.lightened(0.04))
    # стойка (внутренняя часть воротника)
    for k in 14:
        var up0: Vector3 = inner[k] + Vector3(0, 0.022, 0)
        var up1: Vector3 = inner[k + 1] + Vector3(0, 0.022, 0)
        _quad(st, inner[k], up0, up1, inner[k + 1], col.darkened(0.1))
        _quad(st, up0, outer[k] + Vector3(0, 0.004, 0), outer[k + 1] + Vector3(0, 0.004, 0), up1, col)


## Лацканы пиджака/кителя: два треугольника с вырезом «V» на груди.
static func _lapels(groups: Dictionary, b: Dictionary, col: Color) -> void:
    var J: Dictionary = b["J"]
    var yn: float = J["neck_01"].y
    var st := _st(groups, "spine_03")
    for sgn: float in [1.0, -1.0]:
        var a := _front(b, 0.03 * sgn, yn - 0.06, 0.02)
        var bb := _front(b, 0.085 * sgn, yn - 0.075, 0.022)
        var c := _front(b, 0.1 * sgn, yn - 0.12, 0.024)
        var d := _front(b, 0.045 * sgn, yn - 0.24, 0.026)
        var shade := col.lightened(0.06) if col.v < 0.5 else col.darkened(0.06)
        _quad(st, a, bb, c, d, shade)
        # кромка (толщина)
        for e: Array in [[a, bb], [bb, c], [c, d], [d, a]]:
            var p0: Vector3 = e[0]
            var p1: Vector3 = e[1]
            _quad(st, p0, p1, p1 - Vector3(0, 0, 0.004), p0 - Vector3(0, 0, 0.004), col.darkened(0.3))


## Золотая цепь на шее: звенья вокруг шеи, спереди провисает на грудь.
static func _chain(groups: Dictionary, b: Dictionary, size: float, sag: float) -> void:
    var J: Dictionary = b["J"]
    var y0: float = J["neck_01"].y - 0.035
    var st := _st(groups, "spine_03")
    var n := 34
    var pts := []
    for k in n:
        var a := k * TAU / n
        var drop := sag * pow(maxf(0.0, cos(a)), 1.6)
        var p := _surf(b, y0, a, 0.011, 0.012, 0.105)
        if drop > 0.004:
            p = _front(b, p.x * 0.8, y0 - drop, 0.012)
        pts.append(p)
    for k in n:
        var p: Vector3 = pts[k]
        var q: Vector3 = pts[(k + 1) % n]
        var t := (q - p).normalized()
        var out := Vector3(p.x, 0, p.z - 0.01).normalized()
        var side := t.cross(out).normalized()
        if k % 2 == 0:
            _box(st, (p + q) * 0.5, t * size, out * size * 0.35, side * size * 0.7, GOLD)
        else:
            _box(st, (p + q) * 0.5, t * size, side * size * 0.35, out * size * 0.7, GOLD.darkened(0.12))


## Портупея: кожаный ремень через правое плечо по груди и спине (старшие офицеры).
static func _portupea(groups: Dictionary, b: Dictionary) -> void:
    var J: Dictionary = b["J"]
    var yw: float = J["pelvis"].y + 0.09
    var sh: Vector3 = J["upperarm_l"]
    var st := _st(groups, "spine_03")
    var pts := []
    var side := []
    var nor := []
    # спереди: от левого бока у ремня к правому плечу (у персонажа справа = -X)
    for k in 10:
        var t := k / 9.0
        var x := lerpf(0.13, -0.11, t)
        var y := lerpf(yw, sh.y + 0.01, t)
        pts.append(_front(b, x, y, 0.026))
        nor.append(Vector3(0, 0, 1))
    pts.append(_top(b, -0.11, 0.0, 0.012))
    nor.append(Vector3.UP)
    for k in 10:
        var t := k / 9.0
        var x := lerpf(-0.11, 0.13, t)
        var y := lerpf(sh.y + 0.01, yw, t)
        pts.append(_front(b, x, y, 0.015, true))
        nor.append(Vector3(0, 0, -1))
    pts = _smooth(pts, 2)
    for k in pts.size():
        var tg: Vector3 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
        side.append(tg.cross(nor[k]).normalized())
    _ribbon(st, pts, side, nor, 0.013, 0.003, Color(0.34, 0.2, 0.1))
    # пряжка у плеча
    _box(st, pts[8] + nor[8] * 0.004, side[8] * 0.016, (pts[9] - pts[7]).normalized() * 0.012, nor[8] * 0.003, GOLD)


## Сгладить ломаную (неровности замера поверхности): концы на месте.
static func _smooth(pts: Array, passes: int) -> Array:
    var p := pts.duplicate()
    for _i in passes:
        var q := p.duplicate()
        for k in range(1, p.size() - 1):
            q[k] = (p[k - 1] + p[k] * 2.0 + p[k + 1]) * 0.25
        p = q
    return p


## Карабин пожарного на поясе слева.
static func _carabiner(groups: Dictionary, b: Dictionary) -> void:
    var J: Dictionary = b["J"]
    var y: float = J["pelvis"].y + 0.05
    var a := deg_to_rad(60.0)
    var p := _surf(b, y, a, 0.012)
    var out := Vector3(sin(a), 0, cos(a))
    var along := Vector3(cos(a), 0, -sin(a))
    var st := _st(groups, "pelvis")
    _box(st, p + Vector3(0, -0.04, 0), along * 0.016, Vector3(0, 0.03, 0), out * 0.004, SILVER)
    _box(st, p + Vector3(0, -0.04, 0) + out * 0.002, along * 0.008, Vector3(0, 0.022, 0), out * 0.004, Color(0.1, 0.1, 0.1))
