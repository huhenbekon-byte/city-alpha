extends RefCounted
## Иконки интерфейса, нарисованные кодом (без картинок):
## Icons.draw(ci, "wallet", центр, размер, цвет). ci — любой Control/CanvasItem.
## Плюс скруглённые плашки: Icons.panel(ci, rect, цвет, радиус, обводка, цвет обводки).

const GOLD := Color(1.0, 0.76, 0.18)


static func panel(ci: CanvasItem, rect: Rect2, col: Color, radius := 14, border := 0, border_col := Color.BLACK) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = col
    sb.set_corner_radius_all(radius)
    sb.anti_aliasing = true
    if border > 0:
        sb.set_border_width_all(border)
        sb.border_color = border_col
    sb.draw(ci.get_canvas_item(), rect)


static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, col := Color.WHITE, outline := Color(0, 0, 0, 0)) -> void:
    var o := outline.a > 0.0
    match kind:
        "wallet":
            var r := Rect2(c - Vector2(s * 0.5, s * 0.36), Vector2(s, s * 0.72))
            var flap := Rect2(c - Vector2(s * 0.42, s * 0.48), Vector2(s * 0.8, s * 0.3))
            var clasp := Rect2(c + Vector2(s * 0.18, -s * 0.12), Vector2(s * 0.34, s * 0.24))
            if o:
                panel(ci, flap.grow(s * 0.08), outline, int(s * 0.18))
                panel(ci, r.grow(s * 0.08), outline, int(s * 0.2))
            panel(ci, flap, col, int(s * 0.14))
            panel(ci, r, col, int(s * 0.16), int(maxf(2.0, s * 0.06)), outline if o else col.darkened(0.5))
            panel(ci, clasp, col, int(s * 0.1), int(maxf(2.0, s * 0.06)), outline if o else col.darkened(0.5))
        "grid":
            var q := s * 0.38
            for dx: float in [-1.0, 1.0]:
                for dy: float in [-1.0, 1.0]:
                    var p := c + Vector2(dx, dy) * (q * 0.62) - Vector2(q, q) * 0.5
                    panel(ci, Rect2(p, Vector2(q, q)), col, int(q * 0.3))
        "crown":
            var w := s * 0.9
            var h := s * 0.55
            var top := c.y - h * 0.55
            var base := c.y + h * 0.3
            ci.draw_colored_polygon(PackedVector2Array([
                Vector2(c.x - w * 0.5, base), Vector2(c.x - w * 0.5, top + h * 0.15),
                Vector2(c.x - w * 0.22, top + h * 0.5), Vector2(c.x, top),
                Vector2(c.x + w * 0.22, top + h * 0.5), Vector2(c.x + w * 0.5, top + h * 0.15),
                Vector2(c.x + w * 0.5, base)]), col)
            panel(ci, Rect2(c.x - w * 0.5, base + s * 0.08, w, s * 0.12), col, int(s * 0.05))
        "user":
            ci.draw_circle(c - Vector2(0, s * 0.15), s * 0.2, col)
            var pts := PackedVector2Array()
            for k in 17:
                var a := PI + PI * float(k) / 16.0
                pts.append(c + Vector2(cos(a) * s * 0.36, s * 0.42 + sin(a) * s * 0.3))
            ci.draw_colored_polygon(pts, col)
        "briefcase":
            var r := Rect2(c - Vector2(s * 0.48, s * 0.26), Vector2(s * 0.96, s * 0.6))
            panel(ci, Rect2(c - Vector2(s * 0.2, s * 0.42), Vector2(s * 0.4, s * 0.24)), Color(0, 0, 0, 0), int(s * 0.08), int(maxf(2.0, s * 0.07)), col)
            panel(ci, r, col, int(s * 0.1))
            ci.draw_rect(Rect2(c.x - s * 0.08, c.y - s * 0.02, s * 0.16, s * 0.12), Color(0.15, 0.15, 0.17))
        "phone":
            var r := Rect2(c - Vector2(s * 0.27, s * 0.46), Vector2(s * 0.54, s * 0.92))
            panel(ci, r, Color(0, 0, 0, 0), int(s * 0.1), int(maxf(2.0, s * 0.08)), col)
            ci.draw_circle(c + Vector2(0, s * 0.32), s * 0.05, col)
        "house":
            ci.draw_colored_polygon(PackedVector2Array([
                c + Vector2(-s * 0.5, -s * 0.02), c + Vector2(0, -s * 0.48), c + Vector2(s * 0.5, -s * 0.02)]), col)
            ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.06), Vector2(s * 0.68, s * 0.5)), col)
            ci.draw_rect(Rect2(c + Vector2(-s * 0.09, s * 0.16), Vector2(s * 0.18, s * 0.28)), Color(0.15, 0.15, 0.17))
        "people":
            for k: float in [-1.0, 1.0]:
                ci.draw_circle(c + Vector2(k * s * 0.32, -s * 0.12), s * 0.12, col)
                _half_disc(ci, c + Vector2(k * s * 0.32, s * 0.3), s * 0.2, col)
            ci.draw_circle(c + Vector2(0, -s * 0.18), s * 0.15, col)
            _half_disc(ci, c + Vector2(0, s * 0.34), s * 0.26, col)
        "card":
            var r := Rect2(c - Vector2(s * 0.5, s * 0.32), Vector2(s, s * 0.64))
            panel(ci, r, col, int(s * 0.1))
            ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.12), Vector2(s, s * 0.12)), Color(0.15, 0.15, 0.17))
        "chart":
            for k in 3:
                var hh := s * (0.35 + 0.25 * k)
                panel(ci, Rect2(c.x - s * 0.45 + k * s * 0.33, c.y + s * 0.45 - hh, s * 0.24, hh), col, int(s * 0.05))


static func _half_disc(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
    var pts := PackedVector2Array()
    for k in 13:
        var a := PI + PI * float(k) / 12.0
        pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.9))
    ci.draw_colored_polygon(pts, col)
