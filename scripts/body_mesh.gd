extends RefCounted
## Плавные формы для персонажей и машин без внешних 3D-файлов.
##   loft()    — «тело вращения»: кольца разного размера снизу вверх (туловище, руки, ноги, обувь);
##   extrude() — профиль сбоку, вытянутый в ширину (кузов машины, кабина, крыша).
## Готовые части человека — в PARTS (размеры в метрах, как у игрока).

## [y, полуширина по X, полуглубина по Z, сдвиг по Z]
const PARTS := {
    "torso": [[-0.02, 0.001, 0.001], [0.0, 0.155, 0.11], [0.08, 0.15, 0.105], [0.2, 0.165, 0.115],
            [0.32, 0.19, 0.125], [0.42, 0.205, 0.12], [0.5, 0.19, 0.11], [0.55, 0.13, 0.09],
            [0.59, 0.06, 0.06], [0.6, 0.001, 0.001]],
    "pelvis": [[-0.14, 0.001, 0.001], [-0.12, 0.12, 0.09], [-0.05, 0.175, 0.12], [0.05, 0.17, 0.115],
            [0.1, 0.15, 0.105], [0.11, 0.001, 0.001]],
    "thigh": [[-0.49, 0.001, 0.001], [-0.47, 0.06, 0.062], [-0.35, 0.068, 0.072], [-0.15, 0.088, 0.092],
            [0.0, 0.095, 0.1], [0.03, 0.001, 0.001]],
    "calf": [[-0.44, 0.001, 0.001], [-0.42, 0.042, 0.045], [-0.3, 0.05, 0.052], [-0.1, 0.07, 0.078, 0.012],
            [0.0, 0.065, 0.068], [0.02, 0.001, 0.001]],
    "shoe": [[0.0, 0.001, 0.001], [0.01, 0.05, 0.035], [0.08, 0.056, 0.05], [0.2, 0.052, 0.042],
            [0.27, 0.04, 0.028], [0.29, 0.001, 0.001]],
    "upper_arm": [[-0.3, 0.001, 0.001], [-0.28, 0.052, 0.055], [-0.12, 0.065, 0.07], [0.0, 0.072, 0.075],
            [0.03, 0.001, 0.001]],
    "forearm": [[-0.26, 0.001, 0.001], [-0.24, 0.04, 0.042], [-0.08, 0.056, 0.06], [0.0, 0.055, 0.058],
            [0.02, 0.001, 0.001]],
    "hand": [[-0.43, 0.001, 0.001], [-0.4, 0.04, 0.018], [-0.33, 0.048, 0.022], [-0.27, 0.04, 0.025],
            [-0.25, 0.001, 0.001]],
    "hair": [[0.0, 0.128, 0.135, 0.01], [0.06, 0.132, 0.14, 0.01], [0.13, 0.11, 0.12, 0.01],
            [0.18, 0.06, 0.07, 0.01], [0.2, 0.001, 0.001, 0.01]],
}

static var _cache := {}


## Готовая часть тела (кэшируется).
static func part(part_name: String) -> ArrayMesh:
    if not _cache.has(part_name):
        _cache[part_name] = loft(PARTS[part_name], 16)
    return _cache[part_name]


## Тело вращения по кольцам [y, rx, rz, dz]. Сглаженные нормали.
static func loft(rings: Array, seg := 14) -> ArrayMesh:
    var sorted := rings.duplicate()
    sorted.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
    var pts := []
    for r: Array in sorted:
        var ring := []
        var dz: float = r[3] if r.size() > 3 else 0.0
        for i in seg:
            var a := TAU * float(i) / float(seg)
            ring.append(Vector3(sin(a) * float(r[1]), float(r[0]), cos(a) * float(r[2]) + dz))
        pts.append(ring)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for k in pts.size() - 1:
        var ra: Array = pts[k]
        var rb: Array = pts[k + 1]
        for i in seg:
            var j := (i + 1) % seg
            var mid: Vector3 = (ra[i] + rb[j]) * 0.5
            var out := Vector3(mid.x, 0.0, mid.z)
            _tri(st, ra[i], rb[i], rb[j], out)
            _tri(st, ra[i], rb[j], ra[j], out)
    st.index()
    st.generate_normals()
    return st.commit()


## Профиль сбоку (z — вперёд, y — вверх), вытянутый по X. Полуширина: hw_low внизу,
## к верху (от y_from до y_to) сужается до hw_high. Плоские грани — как у кузова.
static func extrude(profile: PackedVector2Array, hw_low: float, hw_high: float, y_from: float, y_to: float) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var n := profile.size()
    var c := Vector2.ZERO
    for p: Vector2 in profile:
        c += p
    c /= float(n)
    var right := []
    var left := []
    for p: Vector2 in profile:
        var k := clampf((p.y - y_from) / maxf(0.001, y_to - y_from), 0.0, 1.0)
        var hw := lerpf(hw_low, hw_high, k)
        right.append(Vector3(hw, p.y, p.x))
        left.append(Vector3(-hw, p.y, p.x))
    # боковины
    var tris := Geometry2D.triangulate_polygon(profile)
    for t in range(0, tris.size(), 3):
        _tri(st, right[tris[t]], right[tris[t + 1]], right[tris[t + 2]], Vector3.RIGHT)
        _tri(st, left[tris[t]], left[tris[t + 1]], left[tris[t + 2]], Vector3.LEFT)
    # обод по контуру
    for i in n:
        var j := (i + 1) % n
        var mid2 := (profile[i] + profile[j]) * 0.5
        var out := Vector3(0.0, mid2.y - c.y, mid2.x - c.x)
        _tri(st, right[i], right[j], left[j], out)
        _tri(st, right[i], left[j], left[i], out)
    st.generate_normals()
    return st.commit()


## Треугольник лицом наружу (out): в Godot лицевая сторона — обход по часовой стрелке.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
    if (c - a).cross(b - a).dot(out) < 0.0:
        var t := b
        b = c
        c = t
    st.add_vertex(a)
    st.add_vertex(b)
    st.add_vertex(c)
