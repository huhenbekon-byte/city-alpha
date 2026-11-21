extends Control
## Паспорт гражданина СССР — раскрытая красная книжка: слева обложка с гербом, справа страница с данными.
## main.gd: var p = PassportScript.new(); p.data = {...}; hud_parent.add_child(p). Закрывается касанием.

const Ui := preload("res://scripts/ussr_ui.gd")

var data := {}          # name, sex, city, lic, med, gun, faction, family, level, number
var _t := 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    Sfx.play("click")


func _gui_input(e: InputEvent) -> void:
    if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
        if _t > 0.3:
            Sfx.play("click")
            if get_parent() is CanvasLayer:
                get_parent().queue_free()
            else:
                queue_free()
        accept_event()


func _process(delta: float) -> void:
    _t += delta
    queue_redraw()


func _draw() -> void:
    var vp := size
    draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.62))
    var k := clampf(_t / 0.25, 0.0, 1.0)            # раскрывается
    var h := minf(vp.y * 0.82, 560.0)
    var w := h * 0.72
    var c := vp * 0.5
    var font := Ui.font()
    # левая половина — обложка (изнутри тёмно-красная) с гербом
    var left := Rect2(c.x - w * k, c.y - h * 0.5, w * k, h)
    draw_rect(left.grow(6), Color(0.25, 0.04, 0.03))
    draw_rect(left, Color(0.5, 0.07, 0.05))
    if k > 0.9:
        var ec := left.get_center() + Vector2(0, -h * 0.12)
        _emblem(ec, w * 0.24)
        _text(font, "СОЮЗ СОВЕТСКИХ", Vector2(left.get_center().x, c.y + h * 0.16), 22, Ui.GOLD)
        _text(font, "СОЦИАЛИСТИЧЕСКИХ", Vector2(left.get_center().x, c.y + h * 0.16 + 28), 22, Ui.GOLD)
        _text(font, "РЕСПУБЛИК", Vector2(left.get_center().x, c.y + h * 0.16 + 56), 22, Ui.GOLD)
        _text(font, "ПАСПОРТ", Vector2(left.get_center().x, c.y + h * 0.4), 34, Ui.GOLD)
    # правая — страница с данными
    var right := Rect2(c.x, c.y - h * 0.5, w * k, h)
    draw_rect(right.grow(6), Color(0.25, 0.04, 0.03))
    draw_rect(right, Color(0.93, 0.89, 0.8))
    # защитная сетка (бледные волны)
    for i in 28:
        var y := right.position.y + 10.0 + i * (h - 20.0) / 28.0
        var pts := PackedVector2Array()
        for j in 21:
            var x := right.position.x + j * right.size.x / 20.0
            pts.append(Vector2(x, y + sin(j * 0.9 + i) * 3.0))
        draw_polyline(pts, Color(0.75, 0.55, 0.5, 0.18), 1.0)
    draw_line(Vector2(c.x, c.y - h * 0.5), Vector2(c.x, c.y + h * 0.5), Color(0.2, 0.03, 0.02), 3.0)
    if k < 0.95:
        return
    var x0 := right.position.x + 22.0
    var y := right.position.y + 34.0
    var fullname := String(data.get("name", "")).replace("_", " ")
    var parts := fullname.split(" ")
    var surname := parts[1] if parts.size() > 1 else fullname
    var first := parts[0] if parts.size() > 0 else ""
    # фото 3×4 в левом верхнем углу страницы
    var ph := Rect2(right.end.x - 22.0 - w * 0.3, y - 10.0, w * 0.3, w * 0.4)
    draw_rect(ph, Color(0.82, 0.8, 0.76))
    draw_rect(ph, Color(0.4, 0.35, 0.3), false, 2.0)
    var hc := ph.get_center() + Vector2(0, -ph.size.y * 0.12)
    draw_circle(hc, ph.size.x * 0.2, Color(0.35, 0.33, 0.32))
    draw_colored_polygon(PackedVector2Array([ph.position + Vector2(ph.size.x * 0.12, ph.size.y), hc + Vector2(-ph.size.x * 0.3, ph.size.y * 0.28),
            hc + Vector2(ph.size.x * 0.3, ph.size.y * 0.28), ph.end - Vector2(ph.size.x * 0.12, 0)]), Color(0.35, 0.33, 0.32))
    # печать поверх уголка фото
    draw_arc(ph.end - Vector2(6, 6), 30.0, 0.0, TAU, 32, Color(0.25, 0.3, 0.7, 0.55), 3.0)
    draw_arc(ph.end - Vector2(6, 6), 22.0, 0.0, TAU, 32, Color(0.25, 0.3, 0.7, 0.45), 1.5)
    if fullname == "":
        _field(font, x0, y, "Паспорт не получен", "паспортный стол в мэрии")
        return
    _field(font, x0, y, "Фамилия", surname)
    y += 56.0
    _field(font, x0, y, "Имя", first)
    y += 56.0
    _field(font, x0, y, "Пол", "жен." if bool(data.get("female", false)) else "муж.")
    y += 56.0
    var fw := right.size.x - 44.0
    _field(font, x0, y, "Прописка", "г. %s" % String(data.get("city", "Казань")), fw)
    y += 56.0
    var lic: Array = data.get("lic", [])
    _field(font, x0, y, "Водительские права", ", ".join(lic) if not lic.is_empty() else "нет", fw)
    y += 56.0
    _field(font, x0, y, "Медкарта · Оружие", "%s · %s" % ["есть" if data.get("med", false) else "нет",
            "разрешение" if data.get("gun", false) else "нет"], fw)
    y += 56.0
    var org := String(data.get("faction", ""))
    _field(font, x0, y, "Место работы", org if org != "" else "не трудоустроен", fw)
    y += 56.0
    var fam := String(data.get("family", ""))
    if fam != "":
        _field(font, x0, y, "Семья", fam, fw)
        y += 56.0
    draw_string(font, Vector2(x0, right.end.y - 18.0), "серия %s" % String(data.get("number", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
            Color(0.6, 0.1, 0.08))
    draw_string(font, Vector2(right.end.x - 170.0, right.end.y - 18.0), "коснись — закрыть", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
            Color(0.35, 0.3, 0.25))


func _field(font: Font, x: float, y: float, label: String, value: String, width := 0.0) -> void:
    draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.45, 0.38, 0.32))
    draw_string(font, Vector2(x, y + 26.0), value, HORIZONTAL_ALIGNMENT_LEFT, width if width > 0.0 else -1.0, 24, Color(0.12, 0.1, 0.25))
    draw_line(Vector2(x, y + 32.0), Vector2(x + (width if width > 0.0 else 180.0), y + 32.0), Color(0.5, 0.42, 0.35, 0.5), 1.0)


func _text(font: Font, s: String, at: Vector2, fs: int, col: Color) -> void:
    var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
    draw_string(font, Vector2(at.x - tw * 0.5, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Герб: золотой земной шар, колосья по бокам, звезда сверху (простые фигуры).
func _emblem(c: Vector2, r: float) -> void:
    var gold := Ui.GOLD
    draw_circle(c, r * 0.62, gold.darkened(0.15))
    draw_circle(c, r * 0.55, Color(0.5, 0.07, 0.05))
    for i in 5:   # параллели и меридианы
        var yy := c.y - r * 0.44 + i * r * 0.22
        var hw := sqrt(maxf(0.0, pow(r * 0.55, 2) - pow(yy - c.y, 2)))
        draw_line(Vector2(c.x - hw, yy), Vector2(c.x + hw, yy), gold, 1.5)
    draw_arc(c, r * 0.55, 0.0, TAU, 40, gold, 2.0)
    draw_line(c - Vector2(0, r * 0.55), c + Vector2(0, r * 0.55), gold, 1.5)
    for side: float in [-1.0, 1.0]:   # колосья
        for j in 7:
            var a := deg_to_rad(-20.0 + j * 22.0)
            var p := c + Vector2(side * absf(cos(a)) * r * 0.95, -sin(a) * r * 0.95 + r * 0.25)
            draw_circle(p, r * 0.1, gold)
    # звезда
    var sc := c + Vector2(0, -r * 1.05)
    var pts := PackedVector2Array()
    for i in 10:
        var a := -PI * 0.5 + i * PI / 5.0
        var rr := r * (0.22 if i % 2 == 0 else 0.09)
        pts.append(sc + Vector2(cos(a), sin(a)) * rr)
    draw_colored_polygon(pts, Color(0.85, 0.12, 0.08))
    draw_polyline(pts + PackedVector2Array([pts[0]]), gold, 1.5)
    # лента внизу
    draw_rect(Rect2(c.x - r * 0.7, c.y + r * 0.72, r * 1.4, r * 0.16), Color(0.85, 0.12, 0.08))
