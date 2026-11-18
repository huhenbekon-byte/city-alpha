extends Control
## Пожарный радар: зелёный экран с бегущим лучом. Верх экрана — куда смотрит камера.
## Очаг ближе RANGE метров — точка на экране, дальше — стрелка на краю и расстояние.
## main.gd задаёт from/to и включает (visible) только на вызове «пожар», пока очаг не найден.

const RANGE := 160.0

var from := Vector3.ZERO
var to := Vector3.ZERO
var title := "ПОЖАР"
var _t := 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(170, 196)
    size = custom_minimum_size


func _process(delta: float) -> void:
    if visible:
        _t += delta
        queue_redraw()


func _draw() -> void:
    var r := 76.0
    var c := Vector2(size.x * 0.5, r + 6.0)
    var green := Color(0.35, 1.0, 0.45)
    draw_circle(c, r + 4.0, Color(0.05, 0.08, 0.05, 0.92))
    draw_arc(c, r + 4.0, 0.0, TAU, 48, Color(0.62, 0.48, 0.2), 3.0, true)
    for k in [0.33, 0.66, 1.0]:
        draw_arc(c, r * k, 0.0, TAU, 40, Color(green, 0.28), 1.5, true)
    draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(green, 0.2), 1.0)
    draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(green, 0.2), 1.0)
    # бегущий луч со «шлейфом»
    var a := fmod(_t * 2.4, TAU)
    for i in 10:
        var aa := a - i * 0.07
        draw_line(c, c + Vector2(cos(aa), sin(aa)) * r, Color(green, 0.5 * (1.0 - i / 10.0)), 3.0 - i * 0.2, true)
    # куда очаг относительно взгляда камеры
    var cam := get_viewport().get_camera_3d()
    var fwd := Vector3(0, 0, -1)
    if cam:
        fwd = -cam.global_basis.z
    fwd.y = 0.0
    fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3(0, 0, -1)
    var right := Vector3(-fwd.z, 0, fwd.x)
    var rel := to - from
    rel.y = 0.0
    var dist := rel.length()
    var v := Vector2(rel.dot(right), -rel.dot(fwd))
    var font := ThemeDB.fallback_font
    var pulse := 0.6 + 0.4 * sin(_t * 8.0)
    if dist < RANGE:
        var p := c + v / RANGE * r
        draw_circle(p, 7.0 + 3.0 * pulse, Color(1.0, 0.45, 0.1, 0.35))
        draw_circle(p, 5.0, Color(1.0, 0.55, 0.15))
    else:
        var dir := v.normalized()
        var tip := c + dir * (r - 2.0)
        var side := Vector2(-dir.y, dir.x)
        draw_colored_polygon(PackedVector2Array([tip, tip - dir * 16.0 + side * 9.0, tip - dir * 16.0 - side * 9.0]),
                Color(1.0, 0.55, 0.15, 0.7 + 0.3 * pulse))
    draw_circle(c, 4.0, Color(0.9, 0.95, 0.9))   # мы
    var label := "%s · %d м" % [title, int(dist)]
    var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
    draw_string_outline(font, Vector2(c.x - w * 0.5, size.y - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.9))
    draw_string(font, Vector2(c.x - w * 0.5, size.y - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1.0, 0.75, 0.35))
