extends Control
## Мини-карта: север сверху, игрок (красная стрелка) в центре.
## Кварталы, дома, машины (синие точки) и цель задания. Если цель далеко,
## её точка прижимается к краю карты — видно, в какую сторону ехать.

const METERS := 220.0   # сколько метров помещается по ширине карты

var city = null                # city_builder.gd
var focus := Vector3.ZERO      # где игрок
var heading := Vector3(0, 0, -1)
var has_target := false
var target := Vector3.ZERO
var target_color := Color(1, 0.8, 0.1)
var cars: Array = []


func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
    var c := size * 0.5
    var s := size.x / METERS
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.26, 0.17, 0.92))
    if city:
        var ext: float = city.extent
        _wrect(Rect2(-ext, -ext, ext * 2.0, ext * 2.0), Color(0.30, 0.30, 0.33), c, s)
        for r: Rect2 in city.block_rects:
            _wrect(r, Color(0.42, 0.50, 0.36), c, s)
        for r: Rect2 in city.building_rects:
            _wrect(r, Color(0.86, 0.85, 0.80), c, s)

    for car in cars:
        draw_circle(_to_map(car.global_position, c, s), 3.5, Color(0.3, 0.6, 1.0))

    if has_target:
        var tp := _to_map(target, c, s)
        tp.x = clampf(tp.x, 10.0, size.x - 10.0)
        tp.y = clampf(tp.y, 10.0, size.y - 10.0)
        draw_circle(tp, 8.0, target_color)
        draw_arc(tp, 8.0, 0.0, TAU, 20, Color(0, 0, 0, 0.9), 2.0, true)

    var dir := Vector2(heading.x, heading.z)
    dir = Vector2(0, -1) if dir.length() < 0.01 else dir.normalized()
    var side := Vector2(-dir.y, dir.x)
    draw_colored_polygon(PackedVector2Array([
        c + dir * 11.0, c - dir * 7.0 + side * 7.0, c - dir * 3.0, c - dir * 7.0 - side * 7.0
    ]), Color(1.0, 0.3, 0.2))
    draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.85), false, 3.0)


func _to_map(w: Vector3, c: Vector2, s: float) -> Vector2:
    return c + (Vector2(w.x, w.z) - Vector2(focus.x, focus.z)) * s


func _wrect(r: Rect2, col: Color, c: Vector2, s: float) -> void:
    var rr := Rect2(c + (r.position - Vector2(focus.x, focus.z)) * s, r.size * s)
    if rr.intersects(Rect2(Vector2.ZERO, size)):
        draw_rect(rr, col)
