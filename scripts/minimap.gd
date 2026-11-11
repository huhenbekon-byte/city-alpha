extends Control
## Круглая мини-карта (по концепту): светлая карта, север сверху, игрок в центре —
## стрелка-капля. Кольцо вокруг: серое слева, красное справа.
## Всё, что выходит за круг, обрезается (Geometry2D.intersect_polygons).

const METERS := 200.0       # сколько метров помещается в диаметр карты
const RING := 12.0          # толщина кольца, px

var city = null                # city_builder.gd
var focus := Vector3.ZERO      # где игрок
var heading := Vector3(0, 0, -1)
var has_target := false
var target := Vector3.ZERO
var target_color := Color(1, 0.8, 0.1)
var cars: Array = []
var has_gps := false
var gps_target := Vector3.ZERO
var points: Array = []   # [[Vector3, Color], ...] — банкоматы, АЗС, работы

var _circle := PackedVector2Array()
var _clip := Rect2()


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var c := size * 0.5
    var R := minf(size.x, size.y) * 0.5 - RING
    var s := (R * 2.0) / METERS
    _circle = PackedVector2Array()
    for k in 40:
        var a := TAU * float(k) / 40.0
        _circle.append(c + Vector2(cos(a), sin(a)) * R)
    _clip = Rect2(c - Vector2(R, R), Vector2(R, R) * 2.0)

    draw_circle(c, R, Color(0.95, 0.95, 0.94))            # пустырь
    if city:
        var ext: float = city.extent
        _wrect(Rect2(-ext, -ext, ext * 2.0, ext * 2.0), Color(0.80, 0.80, 0.82), c, s)  # дороги
        for r: Rect2 in city.block_rects:
            _wrect(r, Color(0.93, 0.95, 0.91), c, s)
        for r: Rect2 in city.building_rects:
            _wrect(r, Color(0.70, 0.71, 0.74), c, s)

    for pt: Array in points:
        var pp := _to_map(pt[0], c, s)
        if pp.distance_to(c) < R - 5.0:
            draw_circle(pp, 4.5, pt[1])
            draw_arc(pp, 4.5, 0.0, TAU, 12, Color(0, 0, 0, 0.8), 1.5, true)

    for car in cars:
        if not car.visible:
            continue
        var cp := _to_map(car.global_position, c, s)
        if cp.distance_to(c) < R - 4.0:
            draw_circle(cp, 3.5, Color(0.3, 0.55, 1.0))

    if has_gps:
        var gp := _to_map(gps_target, c, s)
        if gp.distance_to(c) > R - 10.0:
            gp = c + (gp - c).normalized() * (R - 10.0)
        draw_circle(gp, 9.0, Color(0.75, 0.45, 1.0))
        draw_arc(gp, 9.0, 0.0, TAU, 20, Color(1, 1, 1), 2.5, true)

    if has_target:
        var tp := _to_map(target, c, s)
        if tp.distance_to(c) > R - 10.0:   # далеко — прижимаем к краю
            tp = c + (tp - c).normalized() * (R - 10.0)
        draw_circle(tp, 8.0, target_color)
        draw_arc(tp, 8.0, 0.0, TAU, 20, Color(0, 0, 0, 0.9), 2.0, true)

    # Игрок — капля, остриём в сторону взгляда.
    var dir := Vector2(heading.x, heading.z)
    dir = Vector2(0, -1) if dir.length() < 0.01 else dir.normalized()
    var side := Vector2(-dir.y, dir.x)
    var tip := c + dir * 15.0
    var back := c - dir * 3.0
    var drop := PackedVector2Array([tip])
    for k in 13:
        var t := PI * float(k) / 12.0
        drop.append(back + (side * cos(t) - dir * sin(t)) * 9.0)
    draw_colored_polygon(drop, Color(1, 1, 1))
    drop.append(tip)
    draw_polyline(drop, Color(0, 0, 0), 3.0, true)

    # Кольцо: серая левая половина, красная правая.
    var rr := R + RING * 0.5
    draw_arc(c, rr, PI * 0.5, PI * 1.5, 48, Color(0.55, 0.55, 0.58), RING, true)
    draw_arc(c, rr, -PI * 0.5, PI * 0.5, 48, Color(0.95, 0.05, 0.05), RING, true)
    draw_arc(c, R + RING, 0.0, TAU, 96, Color(0, 0, 0, 0.8), 1.5, true)
    draw_arc(c, R, 0.0, TAU, 96, Color(0, 0, 0, 0.6), 1.5, true)


func _to_map(w: Vector3, c: Vector2, s: float) -> Vector2:
    return c + (Vector2(w.x, w.z) - Vector2(focus.x, focus.z)) * s


## Прямоугольник мира, обрезанный по кругу карты.
func _wrect(r: Rect2, col: Color, c: Vector2, s: float) -> void:
    var rr := Rect2(c + (r.position - Vector2(focus.x, focus.z)) * s, r.size * s)
    if not rr.intersects(_clip):
        return
    if _clip.encloses(rr) and _inside(rr):
        draw_rect(rr, col)
        return
    var poly := PackedVector2Array([rr.position, Vector2(rr.end.x, rr.position.y), rr.end,
            Vector2(rr.position.x, rr.end.y)])
    for part: PackedVector2Array in Geometry2D.intersect_polygons(poly, _circle):
        draw_colored_polygon(part, col)


## Все 4 угла внутри круга — резать не нужно.
func _inside(rr: Rect2) -> bool:
    var c := size * 0.5
    var R := minf(size.x, size.y) * 0.5 - RING
    for p: Vector2 in [rr.position, rr.end, Vector2(rr.end.x, rr.position.y), Vector2(rr.position.x, rr.end.y)]:
        if p.distance_to(c) > R:
            return false
    return true
